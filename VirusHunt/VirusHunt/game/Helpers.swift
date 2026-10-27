//
//  Helpers.swift
//  VirusHunt
//
//  com.rummuscan.game: Assets, GameMode, MusicType, Speed, ScoreStore, TouchInputHandler,
//  TapDragInput, AccountLogin, ContinueOverlay, OnlineConfig (VirusHunt Android sürümünden birebir).
//

import Foundation

/// Tüm görselleri (GameAssets/ altındaki PNG'ler) merkezi olarak yükler; dosya yoksa alan nil kalır.
final class Assets {
    let virusRed: Texture?, virusYellow: Texture?, virusBlue: Texture?
    let pillRed: Texture?, pillYellow: Texture?, pillBlue: Texture?
    let bottleFrame: Texture?
    let notepadPanel: Texture?
    let doctor: Texture?
    let microscopeBg: Texture?

    /// Şişenin İÇ boşluğunun satır satır ölçülmüş genişliği (indeks 0 = şişenin EN ALTI).
    /// Her eleman (solKenar, sağKenar), 0..1; o yükseklikte iç boşluk yoksa nil.
    let bottleInterior: [(Float, Float)?]?

    static let BOTTLE_SAMPLES = 256

    /// Dokular bir kez yüklenip ekranlar arasında paylaşılır (Java'da her ekran kendi kopyasını
    /// yüklüyordu; sonuç aynı, iOS'ta ekran geçişleri daha hızlı).
    private static var cache: [String: Texture] = [:]
    private static var interiorCache: [(Float, Float)?]??

    init() {
        virusRed = Assets.load("viruses/virus_red.png")
        virusYellow = Assets.load("viruses/virus_yellow.png")
        virusBlue = Assets.load("viruses/virus_blue.png")

        pillRed = Assets.load("pills/pill_red.png")
        pillYellow = Assets.load("pills/pill_yellow.png")
        pillBlue = Assets.load("pills/pill_blue.png")

        bottleFrame = Assets.load("ui/bottle_frame.png")
        notepadPanel = Assets.load("ui/notepad_panel.png")
        doctor = Assets.load("ui/doctor.png")
        microscopeBg = Assets.load("ui/microscope_bg.png")

        if let c = Assets.interiorCache {
            bottleInterior = c
        } else {
            let m = Assets.measureBottleInterior("ui/bottle_frame.png")
            Assets.interiorCache = .some(m)
            bottleInterior = m
        }
    }

    /// Şişe görselinin iç boşluğunu piksellerden ölçer (bkz. Java yorumu).
    private static func measureBottleInterior(_ internalPath: String) -> [(Float, Float)?]? {
        let file = Gdx.files.internal(internalPath)
        if !file.exists() { return nil }
        guard let pm = Pixmap(file) else { return nil }
        let w = pm.getWidth(), h = pm.getHeight()
        var spans = [(Float, Float)?](repeating: nil, count: BOTTLE_SAMPLES)
        for i in 0..<BOTTLE_SAMPLES {
            let y = h - 1 - javaRound(Float(i) * (Float(h) - 1) / Float(BOTTLE_SAMPLES - 1))

            var outerLeft = -1, outerRight = -1
            for x in 0..<w where isOpaque(pm, x, y) { outerLeft = x; break }
            for x in stride(from: w - 1, through: 0, by: -1) where isOpaque(pm, x, y) { outerRight = x; break }
            if outerLeft < 0 || outerRight - outerLeft < 2 { continue }

            var innerLeft = -1, innerRight = -1
            for x in outerLeft...outerRight where !isOpaque(pm, x, y) { innerLeft = x; break }
            for x in stride(from: outerRight, through: outerLeft, by: -1) where !isOpaque(pm, x, y) { innerRight = x; break }
            if innerLeft < 0 || innerRight < innerLeft { continue }

            spans[i] = ((Float(innerLeft) - 1) / Float(w), (Float(innerRight) + 2) / Float(w))
        }
        pm.dispose()
        return spans
    }

    private static func isOpaque(_ pm: Pixmap, _ x: Int, _ y: Int) -> Bool {
        return (pm.getPixel(x, y) & 0xff) > 40
    }

    /// Mipmap'li yükleme (NES ölçeğine küçültmede kırpışma olmasın).
    private static func load(_ internalPath: String) -> Texture? {
        if let t = cache[internalPath] { return t }
        let file = Gdx.files.internal(internalPath)
        if !file.exists() { return nil }
        guard let texture = Texture.load(file, true) else { return nil }
        texture.setFilter(.mipMapLinearLinear, .linear)
        cache[internalPath] = texture
        return texture
    }

    func virusFor(_ color: CapsuleColor) -> Texture? {
        switch color {
        case .RED: return virusRed
        case .YELLOW: return virusYellow
        default: return virusBlue
        }
    }

    func pillFor(_ color: CapsuleColor) -> Texture? {
        switch color {
        case .RED: return pillRed
        case .YELLOW: return pillYellow
        default: return pillBlue
        }
    }

    func dispose() {}
}

/// Giriş ekranındaki oyun modu seçenekleri.
enum GameMode: CaseIterable {
    case SINGLE, ONLINE_VS, CPU_VS

    private var menuText: Txt {
        switch self { case .SINGLE: return .MENU_SINGLE; case .ONLINE_VS: return .MENU_ONLINE; case .CPU_VS: return .MENU_CPU }
    }
    private var settingsText: Txt {
        switch self { case .SINGLE: return .SET_TITLE_SINGLE; case .ONLINE_VS: return .SET_TITLE_ONLINE; case .CPU_VS: return .SET_TITLE_CPU }
    }
    /// Oynanışı hazır mı?
    var playable: Bool { return true }

    func menuLabel() -> String { return menuText.s() }
    func settingsTitle() -> String { return settingsText.s() }
}

/// Ayar ekranındaki MUSIC TYPE seçeneği (FEVER / CHILL / OFF).
enum MusicType: CaseIterable {
    case FEVER, CHILL, OFF

    func name() -> String {
        switch self { case .FEVER: return "FEVER"; case .CHILL: return "CHILL"; case .OFF: return "OFF" }
    }

    static func valueOf(_ s: String) -> MusicType? { return allCases.first { $0.name() == s } }

    func label() -> String { return self == .OFF ? Txt.MUSIC_OFF.s() : name() }
    var ordinal: Int { return MusicType.allCases.firstIndex(of: self)! }
}

/// Düşme hızı kademeleri. Sunucuya name() gider (LOW/MED/HI).
enum Speed: CaseIterable {
    case LOW, MED, HI

    func name() -> String {
        switch self { case .LOW: return "LOW"; case .MED: return "MED"; case .HI: return "HI" }
    }

    static func valueOf(_ s: String?) -> Speed? { return allCases.first { $0.name() == s } }

    /// Yerçekimi tick aralığı: küçüldükçe hap daha hızlı düşer.
    var tickInterval: Int {
        switch self { case .LOW: return GameConfig.SPEED_LOW; case .MED: return GameConfig.SPEED_MEDIUM; case .HI: return GameConfig.SPEED_HIGH }
    }

    func label() -> String {
        switch self { case .LOW: return Txt.SPEED_LOW.s(); case .MED: return Txt.SPEED_MED.s(); case .HI: return Txt.SPEED_HI.s() }
    }

    func hudLabel() -> String {
        switch self { case .LOW: return Txt.HUD_SPEED_LOW.s(); case .MED: return Txt.HUD_SPEED_MED.s(); case .HI: return Txt.HUD_SPEED_HI.s() }
    }

    var ordinal: Int { return Speed.allCases.firstIndex(of: self)! }
}

/// Cihaza kalıcı olarak kaydedilen en yüksek skor (TOP).
enum ScoreStore {
    private static let PREFS_NAME = "virushunt-scores"
    private static let KEY_TOP_SCORE = "topScore"

    static func getTopScore() -> Int { return prefs().getInteger(KEY_TOP_SCORE, 0) }

    @discardableResult
    static func reportScore(_ score: Int) -> Int {
        let p = prefs()
        var top = p.getInteger(KEY_TOP_SCORE, 0)
        if score > top {
            top = score
            p.putInteger(KEY_TOP_SCORE, top)
            p.flush()
        }
        return top
    }

    private static func prefs() -> Preferences { return Gdx.app.getPreferences(PREFS_NAME) }
}

/// Basılı tutunca tekrar hareket (DAS/ARR) mantığı.
final class TouchInputHandler {
    private static let DAS_DELAY: Float = 0.18
    private static let DAS_REPEAT: Float = 0.06

    private let engine: GameEngine

    private var leftHeld = false, rightHeld = false, downHeld = false
    private var leftTimer: Float = 0, rightTimer: Float = 0, downTimer: Float = 0

    /// Online VS ekranı motora uygulanan HER hamleyi dinler; diğer ekranlarda nil.
    private var listener: ((InputAction) -> Void)?

    init(_ engine: GameEngine) { self.engine = engine }

    func setActionListener(_ l: ((InputAction) -> Void)?) { listener = l }

    private func fire(_ action: InputAction) { listener?(action) }

    func setLeftHeld(_ held: Bool) {
        if held && !leftHeld {
            engine.moveLeft()
            fire(.MOVE_LEFT)
            leftTimer = 0
        }
        if !held { leftTimer = 0 }
        leftHeld = held
    }

    func setRightHeld(_ held: Bool) {
        if held && !rightHeld {
            engine.moveRight()
            fire(.MOVE_RIGHT)
            rightTimer = 0
        }
        if !held { rightTimer = 0 }
        rightHeld = held
    }

    func setDownHeld(_ held: Bool) {
        if !held { downTimer = 0 }
        downHeld = held
    }

    func triggerRotateCW() { engine.rotateCW(); fire(.ROTATE_CW) }
    func triggerRotateCCW() { engine.rotateCCW() }
    func triggerHardDrop() { engine.hardDrop(); fire(.HARD_DROP) }

    /// Her render frame'inde çağrılmalı (gerçek delta ile).
    func update(_ delta: Float) {
        if leftHeld {
            leftTimer += delta
            if leftTimer >= TouchInputHandler.DAS_DELAY {
                leftTimer -= TouchInputHandler.DAS_REPEAT
                engine.moveLeft()
                fire(.MOVE_LEFT)
            }
        }
        if rightHeld {
            rightTimer += delta
            if rightTimer >= TouchInputHandler.DAS_DELAY {
                rightTimer -= TouchInputHandler.DAS_REPEAT
                engine.moveRight()
                fire(.MOVE_RIGHT)
            }
        }
        if downHeld {
            downTimer += delta
            if downTimer >= TouchInputHandler.DAS_REPEAT {
                downTimer = 0
                engine.softDrop()
                fire(.SOFT_DROP)
            }
        }
    }
}

/// Liste ekranlarının girdisi: dokunmaları toplar, sürükleme satır satır kaydırmaya çevrilir.
final class TapDragInput: InputAdapter {
    private static let MAX_POINTERS = 4
    private static let DRAG_SLOP: Float = 4

    var tapX = [Int](repeating: 0, count: TapDragInput.MAX_POINTERS)
    var tapY = [Int](repeating: 0, count: TapDragInput.MAX_POINTERS)
    var tapCount = 0

    private let viewport: Viewport
    private let rowH: Float

    private var down = false, dragging = false
    private var downX = 0, downY = 0
    private var startWorldY: Float = 0, lastWorldY: Float = 0, dragAccum: Float = 0
    private var scrollDelta = 0

    init(_ viewport: Viewport, _ rowH: Float) {
        self.viewport = viewport
        self.rowH = rowH
        super.init()
    }

    func takeScroll() -> Int {
        let d = scrollDelta
        scrollDelta = 0
        return d
    }

    private func addTap(_ x: Int, _ y: Int) {
        if tapCount < TapDragInput.MAX_POINTERS {
            tapX[tapCount] = x
            tapY[tapCount] = y
            tapCount += 1
        }
    }

    private func worldY(_ x: Int, _ y: Int) -> Float {
        var tmp = Vector3(Float(x), Float(y), 0)
        viewport.unproject(&tmp)
        return tmp.y
    }

    override func touchDown(_ screenX: Int, _ screenY: Int, _ pointer: Int, _ button: Int) -> Bool {
        if pointer != 0 { addTap(screenX, screenY); return false }
        down = true
        dragging = false
        downX = screenX
        downY = screenY
        startWorldY = worldY(screenX, screenY)
        lastWorldY = startWorldY
        dragAccum = 0
        return false
    }

    override func touchDragged(_ screenX: Int, _ screenY: Int, _ pointer: Int) -> Bool {
        if pointer != 0 || !down { return false }
        let wy = worldY(screenX, screenY)
        dragAccum += wy - lastWorldY
        lastWorldY = wy
        if !dragging && abs(wy - startWorldY) > TapDragInput.DRAG_SLOP { dragging = true }
        if dragging {
            while dragAccum >= rowH { scrollDelta += 1; dragAccum -= rowH }
            while dragAccum <= -rowH { scrollDelta -= 1; dragAccum += rowH }
        }
        return false
    }

    override func touchUp(_ screenX: Int, _ screenY: Int, _ pointer: Int, _ button: Int) -> Bool {
        if pointer != 0 || !down { return false }
        if !dragging { addTap(downX, downY) }
        down = false
        dragging = false
        return false
    }

    override func scrolled(_ amountX: Float, _ amountY: Float) -> Bool {
        scrollDelta += amountY > 0 ? 1 : (amountY < 0 ? -1 : 0)
        return false
    }
}

/// Ortak giriş akışı: seçilen yola göre kimlik kanıtı al, sunucuda oturum aç, tercihi kaydet.
enum AccountLogin {
    struct Callback {
        var onSuccess: () -> Void
        /// transientError: sunucuya ulaşılamadı / beklenmeyen cevap (yeniden denenebilir).
        var onFailure: (String, Bool) -> Void
    }

    static func login(_ mode: String, _ client: OnlineClient, _ cb: Callback) {
        let accounts = OnlineSession.accounts()
        let signIn = SignIn(signedIn: { credentials in
            let link = mode == AccountPrefs.MODE_PGS ? AccountPrefs.guestId() : nil
            client.login(credentials, link, ClientCallback(onResult: { r in
                OnlineSession.signedIn(r.session, r.me)
                AccountPrefs.setMode(mode)
                if let me = r.me, me.verified { accounts.submitRating(me.rating) }
                cb.onSuccess()
            }, onError: { message in
                cb.onFailure(describe(message), OnlineClient.isTransient(message))
            }))
        }, failed: { message in
            cb.onFailure(describeSignInFailure(message), isTransientSignInFailure(message))
        })
        if mode == AccountPrefs.MODE_PGS { accounts.signInWithPlayGames(signIn) } else { accounts.signInAsGuest(signIn) }
    }

    static func isTransientSignInFailure(_ code: String?) -> Bool { return code == "server_access_failed" }

    static func describeSignInFailure(_ code: String?) -> String {
        if code == "pgs_not_configured" { return Txt.PGS_NOT_CONFIGURED.s() }
        if code == "pgs_unavailable" { return Txt.PGS_UNAVAILABLE.s() }
        if code == "sign_in_cancelled" { return Txt.PGS_SIGN_IN_FAILED.s() }
        if code == "server_access_failed" { return Txt.PGS_SERVER_ACCESS.s() }
        return describe(code)
    }

    static func describe(_ message: String?) -> String {
        guard let message = message, !message.isEmpty else { return Txt.SIGN_IN_FAILED.s() }
        if message == OnlineClient.ERR_BAD_RESPONSE { return Txt.SERVER_UNAVAILABLE.s() }
        if message == OnlineClient.ERR_NETWORK || message == OnlineClient.ERR_SESSION_INVALID { return Txt.NETWORK_ERROR.s() }
        let m = message.uppercased()
        return m.jlength > 30 ? m.jprefix(30) : m
    }
}

/// Kaybedince çıkan "DEVAM (REKLAM) / MENÜ" kutusu.
final class ContinueOverlay {
    static let W: Float = 136, H: Float = 84, BTN_W: Float = 128, BTN_H: Float = 18
    static let UNAVAILABLE_SECONDS: Float = 2.5

    private let ui: NesUi

    init(_ ui: NesUi) { self.ui = ui }

    private static func boxY(_ centerY: Float) -> Float { return centerY - H / 2 }

    func continueBounds(_ cx: Float, _ centerY: Float) -> Rectangle {
        return Rectangle(cx - ContinueOverlay.BTN_W / 2, ContinueOverlay.boxY(centerY) + 32, ContinueOverlay.BTN_W, ContinueOverlay.BTN_H)
    }

    func menuBounds(_ cx: Float, _ centerY: Float) -> Rectangle {
        return Rectangle(cx - ContinueOverlay.BTN_W / 2, ContinueOverlay.boxY(centerY) + 8, ContinueOverlay.BTN_W, ContinueOverlay.BTN_H)
    }

    func draw(_ cx: Float, _ centerY: Float, _ title: String, _ titleColor: Color, _ waiting: Bool, _ unavailable: Bool, _ blinkTimer: Float) {
        let y = ContinueOverlay.boxY(centerY)
        let W = ContinueOverlay.W, H = ContinueOverlay.H
        ui.roundRectBorder(cx - W / 2, y, W, H, 6, 2, titleColor, NesUi.BLACK)
        ui.textCentered(title, cx, y + H - 18, 1, 3, titleColor)

        let cont = continueBounds(cx, centerY)
        let label: String
        let border: Color
        if waiting {
            label = Int(blinkTimer * 3) % 2 == 0 ? "..." : ""
            border = NesUi.GRAY
        } else if unavailable {
            label = Txt.AD_UNAVAILABLE.s()
            border = NesUi.GRAY
        } else {
            label = Txt.AD_CONTINUE.s()
            border = NesUi.GREEN
        }
        ui.roundRectBorder(cont.x, cont.y, cont.width, cont.height, 4, 1, border, NesUi.BLACK)
        ui.textCentered(label, cont.x + cont.width / 2, cont.y + 5, 1, 2, unavailable ? NesUi.GRAY : NesUi.WHITE)

        let menu = menuBounds(cx, centerY)
        ui.roundRectBorder(menu.x, menu.y, menu.width, menu.height, 4, 1, NesUi.RED, NesUi.BLACK)
        ui.textCentered(Txt.MENU.s(), menu.x + menu.width / 2, menu.y + 5, 1, 2, NesUi.WHITE)
    }
}

/// Online VS sunucusu (Android ile aynı).
enum OnlineConfig {
    static let SERVER_BASE_URL = "https://rummuscan.online/virushunt-vs/"

    static func newClientToken() -> String { return UUID().uuidString.lowercased() }
}

/// Java ekranlarındaki "tapCatcher" anonim InputAdapter'ının karşılığı: bu karede gelen
/// touchDown olaylarının ekran koordinatlarını toplar (hangi parmakla olduğu önemsiz).
final class TapCatcher: InputAdapter {
    let maxPointers: Int
    private let consume: Bool
    var tapX: [Int]
    var tapY: [Int]
    var tapCount = 0

    init(_ maxPointers: Int, consume: Bool = false) {
        self.maxPointers = maxPointers
        self.consume = consume
        tapX = [Int](repeating: 0, count: maxPointers)
        tapY = [Int](repeating: 0, count: maxPointers)
        super.init()
    }

    override func touchDown(_ screenX: Int, _ screenY: Int, _ pointer: Int, _ button: Int) -> Bool {
        if tapCount < maxPointers {
            tapX[tapCount] = screenX
            tapY[tapCount] = screenY
            tapCount += 1
        }
        return consume
    }
}
