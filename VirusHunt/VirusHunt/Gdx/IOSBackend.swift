//
//  IOSBackend.swift
//  VirusHunt
//
//  libGDX'in iOS arka ucu: Metal ile SpriteBatch çizimi, UIKit dokunuşları (çoklu parmak, her
//  parmağa libGDX gibi 0'dan başlayan bir "pointer" numarası), donanım klavyesi, kare döngüsü
//  (saniyede en fazla 60), AVAudioPlayer müzik, PNG çözme, metin girişi penceresi.
//

#if os(iOS)
import UIKit
import MetalKit
import AVFoundation

// MARK: - Metal arka ucu

final class MetalBackend: RenderBackend {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let blendPipeline: MTLRenderPipelineState
    private let opaquePipeline: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private let whiteTexture: Texture

    private enum Cmd {
        case draw(start: Int, count: Int, texture: MTLTexture, projection: [Float], blending: Bool)
        case clear(Float, Float, Float, Float)
    }

    private var vertices: [Float] = []
    private var commands: [Cmd] = []
    private var vertexBuffers: [MTLBuffer?] = [nil, nil, nil]
    private var bufferIndex = 0
    private let inFlight = DispatchSemaphore(value: 3)

    /// Kare görüntüsü alınırken (OnlineHub) çizim yüzeyinin piksel boyu.
    var drawableSize = CGSize(width: 1, height: 1)
    let pixelFormat: MTLPixelFormat = .bgra8Unorm

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VIn { float2 pos [[attribute(0)]]; float2 uv [[attribute(1)]]; float4 color [[attribute(2)]]; };
    struct VOut { float4 pos [[position]]; float2 uv; float4 color; };
    vertex VOut v_main(VIn in [[stage_in]], constant float4x4 &proj [[buffer(1)]]) {
        VOut o;
        o.pos = proj * float4(in.pos, 0.0, 1.0);
        o.uv = in.uv;
        o.color = in.color;
        return o;
    }
    fragment float4 f_main(VOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler s [[sampler(0)]]) {
        return tex.sample(s, in.uv) * in.color;
    }
    """

    init?(device: MTLDevice) {
        self.device = device
        guard let q = device.makeCommandQueue() else { return nil }
        queue = q
        guard let library = try? device.makeLibrary(source: MetalBackend.shaderSource, options: nil),
              let vfn = library.makeFunction(name: "v_main"), let ffn = library.makeFunction(name: "f_main") else { return nil }

        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float2; vd.attributes[0].offset = 0; vd.attributes[0].bufferIndex = 0
        vd.attributes[1].format = .float2; vd.attributes[1].offset = 8; vd.attributes[1].bufferIndex = 0
        vd.attributes[2].format = .float4; vd.attributes[2].offset = 16; vd.attributes[2].bufferIndex = 0
        vd.layouts[0].stride = 32

        func pipeline(_ blend: Bool) -> MTLRenderPipelineState? {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = vfn
            d.fragmentFunction = ffn
            d.vertexDescriptor = vd
            let ca = d.colorAttachments[0]!
            ca.pixelFormat = .bgra8Unorm
            if blend {
                // Renkler alfa ile önceden çarpılmış: libGDX'in SRC_ALPHA / ONE_MINUS_SRC_ALPHA'sının karşılığı.
                ca.isBlendingEnabled = true
                ca.rgbBlendOperation = .add
                ca.alphaBlendOperation = .add
                ca.sourceRGBBlendFactor = .one
                ca.sourceAlphaBlendFactor = .one
                ca.destinationRGBBlendFactor = .oneMinusSourceAlpha
                ca.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            return try? device.makeRenderPipelineState(descriptor: d)
        }
        guard let bp = pipeline(true), let op = pipeline(false) else { return nil }
        blendPipeline = bp
        opaquePipeline = op

        let sd = MTLSamplerDescriptor()
        sd.minFilter = .linear
        sd.magFilter = .linear
        sd.mipFilter = .linear
        sd.sAddressMode = .clampToEdge
        sd.tAddressMode = .clampToEdge
        guard let s = device.makeSamplerState(descriptor: sd) else { return nil }
        sampler = s

        // Tam ekran temizleme dörtgeni için 1x1 beyaz.
        let wd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        guard let wt = device.makeTexture(descriptor: wd) else { return nil }
        var px: [UInt8] = [255, 255, 255, 255]
        wt.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &px, bytesPerRow: 4)
        whiteTexture = Texture(handle: wt, width: 1, height: 1)
    }

    // ---- RenderBackend ----

    func makeTexture(pixels: [UInt8], width: Int, height: Int, mipmaps: Bool) -> AnyObject? {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: mipmaps)
        d.usage = [.shaderRead]
        guard let tex = device.makeTexture(descriptor: d) else { return nil }
        pixels.withUnsafeBytes { raw in
            tex.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: raw.baseAddress!, bytesPerRow: width * 4)
        }
        if mipmaps && tex.mipmapLevelCount > 1, let cb = queue.makeCommandBuffer(), let blit = cb.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: tex)
            blit.endEncoding()
            cb.commit()
        }
        return tex
    }

    func loadTexture(url: URL, mipmaps: Bool) -> (AnyObject, Int, Int)? {
        guard let (px, w, h) = ImageDecoder.decodePremultiplied(url),
              let tex = makeTexture(pixels: px, width: w, height: h, mipmaps: mipmaps) else { return nil }
        return (tex, w, h)
    }

    func submit(vertices v: [Float], texture: Texture, projection: Matrix4, blending: Bool) {
        guard let tex = texture.handle as? MTLTexture else { return }
        let start = vertices.count / 8
        vertices.append(contentsOf: v)
        commands.append(.draw(start: start, count: v.count / 8, texture: tex, projection: projection.m, blending: blending))
    }

    func clear(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {
        commands.append(.clear(r, g, b, a))
    }

    /// Bu kareye şimdiye kadar çizilenleri ayrı bir dokuya çizer ve o dokuyu döndürür.
    func captureFrame() -> Texture? {
        let w = max(1, Int(drawableSize.width)), h = max(1, Int(drawableSize.height))
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: w, height: h, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .private
        guard let target = device.makeTexture(descriptor: d), let cb = queue.makeCommandBuffer() else { return nil }
        let rp = MTLRenderPassDescriptor()
        rp.colorAttachments[0].texture = target
        rp.colorAttachments[0].loadAction = .clear
        rp.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        rp.colorAttachments[0].storeAction = .store
        let buffer = vertices.isEmpty ? nil : device.makeBuffer(bytes: vertices, length: vertices.count * 4, options: .storageModeShared)
        encode(cb, rp, buffer)
        cb.commit()
        vertices.removeAll(keepingCapacity: true)
        commands.removeAll(keepingCapacity: true)
        return Texture(handle: target, width: w, height: h, fromFramebuffer: true)
    }

    // ---- Kare ----

    /// Kare sonunda: biriken komutları ekrana çizer.
    @MainActor func present(in view: MTKView) {
        inFlight.wait()
        guard let drawable = view.currentDrawable, let rp = view.currentRenderPassDescriptor,
              let cb = queue.makeCommandBuffer() else {
            vertices.removeAll(keepingCapacity: true)
            commands.removeAll(keepingCapacity: true)
            inFlight.signal()
            return
        }
        rp.colorAttachments[0].loadAction = .clear
        rp.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        var buffer: MTLBuffer?
        let bytes = vertices.count * 4
        if bytes > 0 {
            bufferIndex = (bufferIndex + 1) % vertexBuffers.count
            if let b = vertexBuffers[bufferIndex], b.length >= bytes {
                buffer = b
            } else {
                buffer = device.makeBuffer(length: max(bytes, 1 << 20) * 2, options: .storageModeShared)
                vertexBuffers[bufferIndex] = buffer
            }
            vertices.withUnsafeBytes { raw in
                buffer?.contents().copyMemory(from: raw.baseAddress!, byteCount: bytes)
            }
        }
        encode(cb, rp, buffer)
        cb.present(drawable)
        cb.addCompletedHandler { [weak self] _ in self?.inFlight.signal() }
        cb.commit()
        vertices.removeAll(keepingCapacity: true)
        commands.removeAll(keepingCapacity: true)
    }

    private func encode(_ cb: MTLCommandBuffer, _ rp: MTLRenderPassDescriptor, _ buffer: MTLBuffer?) {
        guard let enc = cb.makeRenderCommandEncoder(descriptor: rp) else { return }
        enc.setFragmentSamplerState(sampler, index: 0)
        if let b = buffer { enc.setVertexBuffer(b, offset: 0, index: 0) }
        for c in commands {
            switch c {
            case let .draw(start, count, texture, projection, blending):
                guard buffer != nil else { continue }
                enc.setRenderPipelineState(blending ? blendPipeline : opaquePipeline)
                var proj = projection
                enc.setVertexBytes(&proj, length: 64, index: 1)
                enc.setFragmentTexture(texture, index: 0)
                enc.drawPrimitives(type: .triangle, vertexStart: start, vertexCount: count)
            case let .clear(r, g, b, a):
                // Tam ekran dörtgen (birim izdüşümle doğrudan NDC'de).
                var quad: [Float] = [
                    -1, -1, 0, 0, r, g, b, a,   -1, 1, 0, 0, r, g, b, a,   1, 1, 0, 0, r, g, b, a,
                    -1, -1, 0, 0, r, g, b, a,   1, 1, 0, 0, r, g, b, a,    1, -1, 0, 0, r, g, b, a,
                ]
                var ident: [Float] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
                enc.setRenderPipelineState(opaquePipeline)
                enc.setVertexBytes(&quad, length: quad.count * 4, index: 0)
                enc.setVertexBytes(&ident, length: 64, index: 1)
                enc.setFragmentTexture(whiteTexture.handle as? MTLTexture, index: 0)
                enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                if let b = buffer { enc.setVertexBuffer(b, offset: 0, index: 0) }
            }
        }
        enc.endEncoding()
    }
}

// MARK: - PNG çözme

enum ImageDecoder {
    /// RGBA8, alfa ile önceden çarpılmış, satır 0 = görselin üstü.
    static func decodePremultiplied(_ url: URL) -> ([UInt8], Int, Int)? {
        guard let image = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
        let w = image.width, h = image.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ok: Bool = px.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? (px, w, h) : nil
    }

    /// Pixmap için: önceden çarpılmamış RGBA8.
    static func decodeStraight(_ url: URL) -> ([UInt8], Int, Int)? {
        guard var (px, w, h) = decodePremultiplied(url) else { return nil }
        for i in stride(from: 0, to: px.count, by: 4) {
            let a = Int(px[i + 3])
            if a > 0 && a < 255 {
                px[i] = UInt8(min(255, Int(px[i]) * 255 / a))
                px[i + 1] = UInt8(min(255, Int(px[i + 1]) * 255 / a))
                px[i + 2] = UInt8(min(255, Int(px[i + 2]) * 255 / a))
            }
        }
        return (px, w, h)
    }
}

// MARK: - Müzik

/// com.badlogic.gdx.audio.Music: AVAudioPlayer. Uygulama arka plana alınınca çalanlar durur,
/// öne gelince kaldığı yerden sürer (libGDX'in Android'deki davranışı).
final class IOSMusic: NSObject, Music, AVAudioPlayerDelegate {
    private static var live = NSHashTable<IOSMusic>.weakObjects()
    private let player: AVAudioPlayer
    private var looping = false
    private var volume: Float = 1
    private var resumeAfterPause = false
    private var completion: ((Music) -> Void)?

    init(_ url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        super.init()
        player.delegate = self
        player.prepareToPlay()
        IOSMusic.live.add(self)
    }

    func play() { player.play() }
    func pause() { player.pause() }
    func stop() { player.stop(); player.currentTime = 0 }
    func isPlaying() -> Bool { return player.isPlaying }
    func setLooping(_ looping: Bool) { self.looping = looping; player.numberOfLoops = looping ? -1 : 0 }
    func isLooping() -> Bool { return looping }
    func setVolume(_ volume: Float) { self.volume = volume; player.volume = volume }
    func getVolume() -> Float { return volume }
    func setOnCompletionListener(_ listener: ((Music) -> Void)?) { completion = listener }

    func dispose() {
        player.stop()
        IOSMusic.live.remove(self)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let c = completion { Gdx.app.postRunnable { c(self) } }
    }

    static func pauseAll() {
        for m in live.allObjects {
            m.resumeAfterPause = m.player.isPlaying
            if m.resumeAfterPause { m.player.pause() }
        }
    }

    static func resumeAll() {
        for m in live.allObjects where m.resumeAfterPause {
            m.resumeAfterPause = false
            m.player.play()
        }
    }
}

// MARK: - Oyun görünümü

/// Oyunun çizildiği MTKView: dokunuşlar ve donanım klavyesi libGDX olaylarına çevrilir.
final class GameView: MTKView {
    private var pointers: [ObjectIdentifier: Int] = [:]

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
    }

    override var canBecomeFirstResponder: Bool { return true }

    private func pointer(for t: UITouch, create: Bool) -> Int? {
        let id = ObjectIdentifier(t)
        if let p = pointers[id] { return p }
        guard create else { return nil }
        var p = 0
        let used = Set(pointers.values)
        while used.contains(p) { p += 1 }
        pointers[id] = p
        return p
    }

    private func xy(_ t: UITouch) -> (Int, Int) {
        let l = t.location(in: self)
        return (Int(l.x), Int(l.y))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let p = pointer(for: t, create: true) else { continue }
            let (x, y) = xy(t)
            Gdx.input.post(.touchDown(x: x, y: y, pointer: p))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let p = pointer(for: t, create: false) else { continue }
            let (x, y) = xy(t)
            Gdx.input.post(.touchDragged(x: x, y: y, pointer: p))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let p = pointer(for: t, create: false) else { continue }
            let (x, y) = xy(t)
            pointers.removeValue(forKey: ObjectIdentifier(t))
            Gdx.input.post(.touchUp(x: x, y: y, pointer: p))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // ---- Donanım klavyesi (iPad klavyesi / Mac'te çalışırken) ----

    private static func gdxKey(_ key: UIKey) -> Int? {
        switch key.keyCode {
        case .keyboardUpArrow: return Input.Keys.UP
        case .keyboardDownArrow: return Input.Keys.DOWN
        case .keyboardLeftArrow: return Input.Keys.LEFT
        case .keyboardRightArrow: return Input.Keys.RIGHT
        case .keyboardReturnOrEnter, .keypadEnter: return Input.Keys.ENTER
        case .keyboardSpacebar: return Input.Keys.SPACE
        case .keyboardEscape: return Input.Keys.ESCAPE
        case .keyboardW: return Input.Keys.W
        case .keyboardS: return Input.Keys.S
        case .keyboardA: return Input.Keys.A
        case .keyboardD: return Input.Keys.D
        case .keyboardF: return Input.Keys.F
        case .keyboardL: return Input.Keys.L
        case .keyboardR: return Input.Keys.R
        default: return nil
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for p in presses {
            if let k = p.key, let g = GameView.gdxKey(k) { Gdx.input.post(.keyDown(g)); handled = true }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for p in presses {
            if let k = p.key, let g = GameView.gdxKey(k) { Gdx.input.post(.keyUp(g)); handled = true }
        }
        if !handled { super.pressesEnded(presses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        pressesEnded(presses, with: event)
    }
}

/// Oyunu barındıran ekran: kare döngüsü, yaşam döngüsü, platform servisleri.
final class GameViewController: UIViewController, MTKViewDelegate {
    private var gameView: GameView!
    private var backend: MetalBackend!
    private var game: Game?
    private let makeGame: () -> Game
    private var lastTime: CFTimeInterval = 0
    private var lastSize = (0, 0)
    private var paused = false

    init(_ makeGame: @escaping () -> Game) {
        self.makeGame = makeGame
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    override func loadView() {
        guard let device = MTLCreateSystemDefaultDevice(), let b = MetalBackend(device: device) else {
            view = UIView()
            view.backgroundColor = .black
            return
        }
        backend = b
        Renderer.backend = b
        PixmapDecoder.decode = { ImageDecoder.decodeStraight($0) }
        let v = GameView(frame: UIScreen.main.bounds, device: device)
        v.colorPixelFormat = b.pixelFormat
        v.framebufferOnly = true
        v.preferredFramesPerSecond = 60 // pil: en fazla 60 FPS (Android FrameLimiter'ın karşılığı)
        v.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        v.delegate = self
        gameView = v
        view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        installPlatformHooks()
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        gameView?.becomeFirstResponder()
    }

    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }
    /// Ekranın kenarındaki sistem hareketleri oyunun dokunuşunu çalmasın (ilk kaydırma oyuna gider).
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { return .all }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .landscape }

    private func installPlatformHooks() {
        Gdx.net.uriOpener = { url in
            DispatchQueue.main.async { MainActor.assumeIsolated { UIApplication.shared.open(url) } }
        }
        Gdx.audio.musicFactory = { file in
            guard let url = file.url else { throw JsonError(description: "yok: \(file.path)") }
            return try IOSMusic(url)
        }
        Gdx.input.textInputPresenter = { [weak self] listener, title, text, hint in
            DispatchQueue.main.async { MainActor.assumeIsolated {
                let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
                alert.addTextField { tf in
                    tf.text = text
                    tf.placeholder = hint
                    tf.autocapitalizationType = .allCharacters
                    tf.autocorrectionType = .no
                    tf.returnKeyType = .search
                }
                alert.addAction(UIAlertAction(title: IOSStrings.cancel(), style: .cancel) { _ in
                    Gdx.app.postRunnable { listener.canceled() }
                })
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    let value = alert.textFields?.first?.text ?? ""
                    // libGDX'te input() render thread'i DIŞINDA gelir; oyun kodu postRunnable ile taşır.
                    listener.input(value)
                })
                self?.topPresenter().present(alert, animated: true)
            } }
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Üstte açık olan pencere (reklam, onay formu) varsa onun üstünden sun.
    func topPresenter() -> UIViewController {
        var vc: UIViewController = self
        while let p = vc.presentedViewController { vc = p }
        return vc
    }

    // ---- Yaşam döngüsü ----

    @objc private func appWillResignActive() {
        guard !paused else { return }
        paused = true
        Gdx.input.releaseAll()
        game?.pause()
        IOSMusic.pauseAll()
        gameView?.isPaused = true
    }

    @objc private func appDidBecomeActive() {
        guard paused else { return }
        paused = false
        lastTime = 0
        try? AVAudioSession.sharedInstance().setActive(true)
        IOSMusic.resumeAll()
        game?.resume()
        gameView?.isPaused = false
    }

    // ---- MTKViewDelegate ----

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        backend?.drawableSize = size
    }

    func draw(in view: MTKView) {
        guard let backend = backend else { return }
        let g = Gdx.graphics
        g.width = max(1, Int(view.bounds.width))
        g.height = max(1, Int(view.bounds.height))
        g.safeInsetLeft = Float(view.safeAreaInsets.left)
        g.safeInsetRight = Float(view.safeAreaInsets.right)
        g.backBufferWidth = max(1, Int(view.drawableSize.width))
        g.backBufferHeight = max(1, Int(view.drawableSize.height))
        backend.drawableSize = view.drawableSize

        let now = CACurrentMediaTime()
        g.deltaTime = lastTime == 0 ? 0 : Float(now - lastTime)
        lastTime = now

        Gdx.app.runPending()
        Gdx.input.processEvents()

        if game == nil {
            #if DEBUG
            let shot = DebugShots.requested()
            if let s = shot { DebugShots.prepare(s) }
            #endif
            let created = makeGame()
            game = created
            lastSize = (g.width, g.height)
            created.create()
            created.resize(g.width, g.height)
            #if DEBUG
            if let s = shot { DebugShots.apply(s, created) }
            #endif
        } else if lastSize != (g.width, g.height) {
            lastSize = (g.width, g.height)
            game?.resize(g.width, g.height)
        }
        game?.render()
        backend.present(in: view)
    }
}

/// Sistem pencerelerindeki kısa metinler (oyunun kendi metinleri Txt'te).
enum IOSStrings {
    static func cancel() -> String {
        switch Lang.current() {
        case .TR: return "Vazgeç"
        case .DE: return "Abbrechen"
        case .ES: return "Cancelar"
        case .FR: return "Annuler"
        case .PT: return "Cancelar"
        case .IT: return "Annulla"
        case .RU: return "Отмена"
        default: return "Cancel"
        }
    }
}
#endif
