//
//  GdxGraphics.swift
//  VirusHunt
//
//  libGDX'in 2B çizim API'si (Texture, TextureRegion, Pixmap, SpriteBatch, OrthographicCamera,
//  ExtendViewport, Gdx.gl). Asıl GPU işi platform arka ucundadır (RenderBackend; iOS'ta Metal,
//  bkz. IOSBackend.swift). Koordinatlar libGDX'teki gibi y-yukarı: (0,0) sol-alt.
//

import Foundation

// MARK: - Arka uç

/// Platformun çizim arka ucu. iOS'ta MetalBackend; Linux'taki derleme denetiminde boş arka uç.
protocol RenderBackend: AnyObject {
    /// RGBA8, alfa ile ÖNCEDEN ÇARPILMIŞ pikseller (satır 0 = görselin üstü).
    func makeTexture(pixels: [UInt8], width: Int, height: Int, mipmaps: Bool) -> AnyObject?
    /// PNG dosyasını doku olarak yükler.
    func loadTexture(url: URL, mipmaps: Bool) -> (AnyObject, Int, Int)?
    /// Bir yığın dörtgen: her köşe x, y, u, v, r, g, b, a (renk önceden çarpılmış).
    func submit(vertices: [Float], texture: Texture, projection: Matrix4, blending: Bool)
    func clear(_ r: Float, _ g: Float, _ b: Float, _ a: Float)
    /// Bu karede şimdiye kadar çizilenin görüntüsü (OnlineHub penceresinin arkası).
    func captureFrame() -> Texture?
}

final class NullBackend: RenderBackend {
    func makeTexture(pixels: [UInt8], width: Int, height: Int, mipmaps: Bool) -> AnyObject? { return NSObject() }
    func loadTexture(url: URL, mipmaps: Bool) -> (AnyObject, Int, Int)? { return nil }
    func submit(vertices: [Float], texture: Texture, projection: Matrix4, blending: Bool) {}
    func clear(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {}
    func captureFrame() -> Texture? { return nil }
}

enum Renderer {
    static var backend: RenderBackend = NullBackend()
}

// MARK: - Texture

final class Texture {
    enum TextureFilter { case nearest, linear, mipMapLinearLinear }

    let handle: AnyObject
    let width: Int
    let height: Int
    /// Kare görüntüsünden alınan dokular GL'deki gibi alttan üste okunmuş sayılır
    /// (Java tarafı bunu TextureRegion.flip(false, true) ile düzeltir).
    let fromFramebuffer: Bool

    init(handle: AnyObject, width: Int, height: Int, fromFramebuffer: Bool = false) {
        self.handle = handle
        self.width = width
        self.height = height
        self.fromFramebuffer = fromFramebuffer
    }

    /// new Texture(Gdx.files.internal(path), useMipMaps); dosya yoksa nil.
    static func load(_ file: FileHandle, _ useMipMaps: Bool) -> Texture? {
        guard let url = file.url, let (h, w, hh) = Renderer.backend.loadTexture(url: url, mipmaps: useMipMaps) else { return nil }
        return Texture(handle: h, width: w, height: hh)
    }

    /// new Texture(pixmap)
    static func from(_ pixmap: Pixmap) -> Texture? {
        if let captured = pixmap.captured { return captured }
        guard let h = Renderer.backend.makeTexture(pixels: pixmap.premultiplied(), width: pixmap.width,
                                                   height: pixmap.height, mipmaps: false) else { return nil }
        return Texture(handle: h, width: pixmap.width, height: pixmap.height)
    }

    func setFilter(_ minFilter: TextureFilter, _ magFilter: TextureFilter) { /* arka uç mipmap'li dokuda zaten doğrusal süzer */ }
    func dispose() {}
}

final class TextureRegion {
    let texture: Texture
    var u: Float = 0, v: Float = 0, u2: Float = 1, v2: Float = 1

    init(_ texture: Texture) { self.texture = texture }

    func flip(_ x: Bool, _ y: Bool) {
        if x { swap(&u, &u2) }
        if y { swap(&v, &v2) }
    }
}

// MARK: - Pixmap

/// Yalnızca oyunun kullandığı kısım: dosyadan okuma + piksel sorgusu, 1x1 düz renk, kare görüntüsü.
final class Pixmap {
    enum Format { case RGBA8888 }

    let width: Int
    let height: Int
    /// RGBA8, önceden çarpılmamış.
    private(set) var pixels: [UInt8]
    private var color = Color.WHITE
    fileprivate(set) var captured: Texture?

    init(_ width: Int, _ height: Int, _ format: Format) {
        self.width = width
        self.height = height
        pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    /// new Pixmap(Gdx.files.internal(path)); çözülemezse nil.
    init?(_ file: FileHandle) {
        guard let url = file.url, let (px, w, h) = PixmapDecoder.decode(url) else { return nil }
        width = w; height = h; pixels = px
    }

    private init(captured: Texture) {
        width = captured.width; height = captured.height; pixels = []
        self.captured = captured
    }

    func setColor(_ c: Color) { color = c }

    func fill() {
        let r = UInt8(min(255, max(0, color.r * 255).rounded()))
        let g = UInt8(min(255, max(0, color.g * 255).rounded()))
        let b = UInt8(min(255, max(0, color.b * 255).rounded()))
        let a = UInt8(min(255, max(0, color.a * 255).rounded()))
        for i in stride(from: 0, to: pixels.count, by: 4) {
            pixels[i] = r; pixels[i + 1] = g; pixels[i + 2] = b; pixels[i + 3] = a
        }
    }

    func getWidth() -> Int { return width }
    func getHeight() -> Int { return height }

    /// RGBA8888 tamsayısı (en düşük bayt alfa), (0,0) sol-üst.
    func getPixel(_ x: Int, _ y: Int) -> Int {
        guard x >= 0, y >= 0, x < width, y < height else { return 0 }
        let i = (y * width + x) * 4
        return (Int(pixels[i]) << 24) | (Int(pixels[i + 1]) << 16) | (Int(pixels[i + 2]) << 8) | Int(pixels[i + 3])
    }

    func premultiplied() -> [UInt8] {
        var out = pixels
        for i in stride(from: 0, to: out.count, by: 4) {
            let a = Int(out[i + 3])
            out[i] = UInt8(Int(out[i]) * a / 255)
            out[i + 1] = UInt8(Int(out[i + 1]) * a / 255)
            out[i + 2] = UInt8(Int(out[i + 2]) * a / 255)
        }
        return out
    }

    /// Pixmap.createFromFrameBuffer: bu kareye şimdiye kadar çizilenler.
    static func createFromFrameBuffer(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> Pixmap {
        if let tex = Renderer.backend.captureFrame() { return Pixmap(captured: tex) }
        return Pixmap(1, 1, .RGBA8888)
    }

    func dispose() {}
}

/// PNG çözücü: platform (iOS) tarafından atanır.
enum PixmapDecoder {
    static var decode: (URL) -> ([UInt8], Int, Int)? = { _ in nil }
}

// MARK: - GL

final class GL20 {
    static let GL_COLOR_BUFFER_BIT = 0x4000
    private var clearR: Float = 0, clearG: Float = 0, clearB: Float = 0, clearA: Float = 1

    func glClearColor(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {
        clearR = r; clearG = g; clearB = b; clearA = a
    }

    func glClear(_ mask: Int) {
        Renderer.backend.clear(clearR, clearG, clearB, clearA)
    }
}

// MARK: - SpriteBatch

final class SpriteBatch {
    private var vertices: [Float] = []
    private var lastTexture: Texture?
    private var projection = Matrix4()
    private var drawing = false
    private var blending = true
    private var color = Color.WHITE

    init() { vertices.reserveCapacity(8 * 6 * 512) }

    func setProjectionMatrix(_ m: Matrix4) {
        if drawing { flush() }
        projection = m
    }

    func begin() {
        drawing = true
        vertices.removeAll(keepingCapacity: true)
        lastTexture = nil
    }

    func end() {
        flush()
        drawing = false
    }

    func setColor(_ c: Color) { color = c }
    func setColor(_ r: Float, _ g: Float, _ b: Float, _ a: Float) { color = Color(r, g, b, a) }
    func getColor() -> Color { return color }

    func enableBlending() {
        if blending { return }
        flush()
        blending = true
    }

    func disableBlending() {
        if !blending { return }
        flush()
        blending = false
    }

    func flush() {
        guard !vertices.isEmpty, let tex = lastTexture else { return }
        Renderer.backend.submit(vertices: vertices, texture: tex, projection: projection, blending: blending)
        vertices.removeAll(keepingCapacity: true)
    }

    /// draw(texture, x, y, width, height)
    func draw(_ texture: Texture?, _ x: Float, _ y: Float, _ width: Float, _ height: Float) {
        guard let texture = texture else { return }
        quad(texture, x, y, width, height, 0, 1, 1, 0)
    }

    /// draw(texture, x, y, width, height, srcX, srcY, srcWidth, srcHeight, flipX, flipY)
    func draw(_ texture: Texture?, _ x: Float, _ y: Float, _ width: Float, _ height: Float,
              _ srcX: Int, _ srcY: Int, _ srcWidth: Int, _ srcHeight: Int, _ flipX: Bool, _ flipY: Bool) {
        guard let texture = texture else { return }
        let invW = 1 / Float(texture.width), invH = 1 / Float(texture.height)
        var u = Float(srcX) * invW
        var v = Float(srcY + srcHeight) * invH
        var u2 = Float(srcX + srcWidth) * invW
        var v2 = Float(srcY) * invH
        if flipX { swap(&u, &u2) }
        if flipY { swap(&v, &v2) }
        quad(texture, x, y, width, height, u, v, u2, v2)
    }

    /// draw(region, x, y, width, height)
    func draw(_ region: TextureRegion?, _ x: Float, _ y: Float, _ width: Float, _ height: Float) {
        guard let region = region else { return }
        quad(region.texture, x, y, width, height, region.u, region.v2, region.u2, region.v)
    }

    /// (u, v) sol-alt köşenin, (u2, v2) sağ-üst köşenin doku koordinatı (v = 0 görselin üstü).
    private func quad(_ texture: Texture, _ x: Float, _ y: Float, _ w: Float, _ h: Float,
                      _ u: Float, _ v: Float, _ u2: Float, _ v2: Float) {
        if lastTexture !== texture {
            flush()
            lastTexture = texture
        }
        var vb = v, vt = v2
        if texture.fromFramebuffer { vb = 1 - vb; vt = 1 - vt }
        let a = color.a
        let r = color.r * a, g = color.g * a, b = color.b * a
        let x2 = x + w, y2 = y + h
        vertices.append(contentsOf: [
            x, y, u, vb, r, g, b, a,
            x, y2, u, vt, r, g, b, a,
            x2, y2, u2, vt, r, g, b, a,
            x, y, u, vb, r, g, b, a,
            x2, y2, u2, vt, r, g, b, a,
            x2, y, u2, vb, r, g, b, a,
        ])
    }

    func dispose() {}
}

// MARK: - Kamera / görüntü alanı

final class OrthographicCamera {
    var viewportWidth: Float = 1
    var viewportHeight: Float = 1
    var position = Vector3()
    var zoom: Float = 1
    private(set) var combined = Matrix4()

    func update() {
        let hw = viewportWidth * zoom / 2, hh = viewportHeight * zoom / 2
        combined.setToOrtho(position.x - hw, position.x + hw, position.y - hh, position.y + hh)
    }
}

protocol Viewport: AnyObject {
    func update(_ screenWidth: Int, _ screenHeight: Int, _ centerCamera: Bool)
    func getWorldWidth() -> Float
    func getWorldHeight() -> Float
    func unproject(_ v: inout Vector3)
}

/// com.badlogic.gdx.utils.viewport.ExtendViewport (maxWorld sınırsız): en küçük dünya
/// boyu sığdırılır, ekranın uzun kalan ekseninde dünya uzatılır - siyah bant olmaz.
final class ExtendViewport: Viewport {
    private let minWorldWidth: Float
    private let minWorldHeight: Float
    private let camera: OrthographicCamera
    private var worldWidth: Float
    private var worldHeight: Float
    private var screenX = 0, screenY = 0, screenWidth = 1, screenHeight = 1

    init(_ minWorldWidth: Float, _ minWorldHeight: Float, _ camera: OrthographicCamera) {
        self.minWorldWidth = minWorldWidth
        self.minWorldHeight = minWorldHeight
        self.camera = camera
        worldWidth = minWorldWidth
        worldHeight = minWorldHeight
    }

    convenience init(_ minWorldWidth: Int, _ minWorldHeight: Int, _ camera: OrthographicCamera) {
        self.init(Float(minWorldWidth), Float(minWorldHeight), camera)
    }

    func update(_ sw: Int, _ sh: Int, _ centerCamera: Bool) {
        var ww = minWorldWidth, wh = minWorldHeight
        // Scaling.fit
        let targetRatio = Float(sh) / Float(sw)
        let sourceRatio = wh / ww
        let scale = targetRatio > sourceRatio ? Float(sw) / ww : Float(sh) / wh
        var vw = javaRound(ww * scale), vh = javaRound(wh * scale)
        if vw < sw {
            let toViewport = Float(vh) / wh
            let lengthen = Float(sw - vw) / toViewport
            ww += lengthen
            vw += javaRound(lengthen * toViewport)
        } else if vh < sh {
            let toViewport = Float(vw) / ww
            let lengthen = Float(sh - vh) / toViewport
            wh += lengthen
            vh += javaRound(lengthen * toViewport)
        }
        worldWidth = ww
        worldHeight = wh
        screenX = (sw - vw) / 2
        screenY = (sh - vh) / 2
        screenWidth = max(1, vw)
        screenHeight = max(1, vh)
        camera.viewportWidth = ww
        camera.viewportHeight = wh
        if centerCamera { camera.position.set(ww / 2, wh / 2, 0) }
        camera.update()
    }

    func getWorldWidth() -> Float { return worldWidth }
    func getWorldHeight() -> Float { return worldHeight }

    /// Ekran (nokta, y-aşağı) -> dünya (y-yukarı).
    func unproject(_ v: inout Vector3) {
        let x = v.x - Float(screenX)
        let y = Float(Gdx.graphics.getHeight()) - v.y - Float(screenY)
        let ndcX = 2 * x / Float(screenWidth) - 1
        let ndcY = 2 * y / Float(screenHeight) - 1
        v.x = camera.position.x + ndcX * camera.viewportWidth * camera.zoom / 2
        v.y = camera.position.y + ndcY * camera.viewportHeight * camera.zoom / 2
    }
}
