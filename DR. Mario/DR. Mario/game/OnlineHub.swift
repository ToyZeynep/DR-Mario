//
//  OnlineHub.swift
//  DR. Mario
//
//  com.rummuscan.game.OnlineHub (VirusHunt Android sürümünden birebir): uygulama açıkken HER
//  ekranda çalışan online merkez - sessiz giriş, ~4 sn nabız (oyuncu online listesinde görünür),
//  davet pencereleri (gelen / giden / bilgi; pencere açıkken arkadaki ekran durur), uygulama
//  arka plana alınınca sunucuya "ayrıldım".
//

import Foundation

final class OnlineHub {

    private static weak var instance: OnlineHub?

    static func get() -> OnlineHub? { return instance }

    private enum Mode { case NONE, INCOMING, WAITING, NOTICE, STARTING }

    private static let HEARTBEAT_IDLE: Float = 4
    private static let HEARTBEAT_FAST: Float = 1
    private static let INVITE_TIMEOUT: Float = 30
    private static let START_DELAY: Float = 1.4
    private static let BOX_W: Float = 220, BTN_H: Float = 18

    private unowned let game: Game
    private let client = OnlineClient(OnlineConfig.SERVER_BASE_URL)

    // ---- Oturum ----
    private var loginInFlight = false
    private var loginErrorText: String?
    static let LOGIN_RETRY_DELAYS: [Float] = [5, 10, 20, 40, 60]
    private var loginRetries = 0
    private var loginRetryTimer: Float = -1

    // ---- Nabız ----
    private var lobbyState: OnlineClient.LobbyState?
    private var lobbyVisible = false
    private var queueing = false
    private var level = 5
    private var speed = Speed.MED
    private var searchText = ""
    private var inMatch = false
    private var paused = false
    private var heartbeatTimer: Float = 99
    private var heartbeatInFlight = false
    private var heartbeatGeneration = 0
    private var requestInFlight = false

    // ---- Pencere ----
    private var mode = Mode.NONE
    private var incoming: OnlineClient.Invite?
    private var incomingAge: Float = 0
    private var myInviteId = 0
    private var myInviteName: String?
    private var myInviteLevel = 0
    private var myInviteSpeed: Speed?
    private var waitAge: Float = 0
    private var acceptedWithoutMatch = 0
    private var noticeLine1: String?, noticeLine2: String?
    private var pendingMatch: MatchInfo?
    private var startTimer: Float = 0
    private var blink: Float = 0
    private var clock: Float = 0
    private var incomingExpiresAt: Float = -1
    private var waitExpiresAt: Float = -1
    private var handledIncoming = Set<Int>()
    private var startedMatches = Set<Int>()

    // ---- Çizim / girdi ----
    private var batch: SpriteBatch?
    private var ui: NesUi?
    private let camera = OrthographicCamera()
    private let viewport: ExtendViewport
    private var snapshot: Texture?
    private var snapshotRegion: TextureRegion?
    private var releaseFrame = false
    private var savedInput: InputProcessor?
    private let modalInput = TapCatcher(4, consume: true)

    init(_ game: Game) {
        self.game = game
        viewport = ExtendViewport(GameConfig.CONTENT_WIDTH, GameConfig.WORLD_HEIGHT, camera)
        OnlineHub.instance = self
    }

    // =====================================================================================
    // Oturum
    // =====================================================================================

    /// Hatırlanan hesapla sessizce giriş (hesap seçilmediyse hiçbir şey yapmaz).
    func autoLogin() {
        loginRetries = 0
        attemptLogin()
    }

    private func attemptLogin() {
        loginRetryTimer = -1
        if OnlineSession.isSignedIn() || loginInFlight || AccountPrefs.mode().isEmpty { return }
        loginInFlight = true
        loginErrorText = nil
        AccountLogin.login(AccountPrefs.mode(), client, AccountLogin.Callback(onSuccess: { [weak self] in
            guard let self = self else { return }
            self.loginInFlight = false
            self.loginRetries = 0
            self.heartbeatTimer = 99
        }, onFailure: { [weak self] message, transientError in
            guard let self = self else { return }
            self.loginInFlight = false
            self.loginErrorText = message
            self.loginRetryTimer = OnlineHub.nextLoginRetryDelay(transientError, self.loginRetries)
            if self.loginRetryTimer >= 0 { self.loginRetries += 1 }
        }))
    }

    static func nextLoginRetryDelay(_ transientError: Bool, _ retriesSoFar: Int) -> Float {
        if !transientError || retriesSoFar < 0 || retriesSoFar >= LOGIN_RETRY_DELAYS.count { return -1 }
        return LOGIN_RETRY_DELAYS[retriesSoFar]
    }

    func isLoggingIn() -> Bool { return loginInFlight }
    func loginError() -> String? { return loginErrorText }

    // =====================================================================================
    // Ekranların kullandığı durum
    // =====================================================================================

    func state() -> OnlineClient.LobbyState? { return lobbyState }

    func setLobbyVisible(_ visible: Bool, _ level: Int, _ speed: Speed) {
        lobbyVisible = visible
        self.level = level
        self.speed = speed
        if !visible { queueing = false }
        heartbeatTimer = 99
    }

    func isQueueing() -> Bool { return queueing }

    func refreshNow() {
        if !OnlineSession.isSignedIn() { autoLogin(); return }
        heartbeatTimer = 99
    }

    func setQueueing(_ q: Bool) {
        queueing = q
        heartbeatTimer = 99
    }

    func search() -> String { return searchText }

    func setSearch(_ text: String?) {
        searchText = OnlineHub.normalize(text)
        heartbeatTimer = 99
    }

    func setInMatch(_ value: Bool) {
        inMatch = value
        if !value { heartbeatTimer = 99 }
    }

    func isModalActive() -> Bool { return mode != .NONE }

    /// Sunucu adları A-Z 0-9 boşluk ve tireye indirger; arama da öyle (Türkçe harfler dahil).
    static func normalize(_ s: String?) -> String {
        guard let s = s else { return "" }
        var out: [UInt16] = []
        for u in s.utf16 {
            if out.count >= 12 { break }
            var c = u
            switch Character(Unicode.Scalar(u) ?? " ") {
            case "ı", "İ", "i": c = UInt16(UInt8(ascii: "I"))
            case "ş", "Ş": c = UInt16(UInt8(ascii: "S"))
            case "ğ", "Ğ": c = UInt16(UInt8(ascii: "G"))
            case "ü", "Ü": c = UInt16(UInt8(ascii: "U"))
            case "ö", "Ö": c = UInt16(UInt8(ascii: "O"))
            case "ç", "Ç": c = UInt16(UInt8(ascii: "C"))
            default: c = javaToUpper(c)
            }
            let isAZ = c >= 65 && c <= 90, is09 = c >= 48 && c <= 57
            if isAZ || is09 || c == 32 || c == 45 { out.append(c) }
        }
        return String(decoding: out, as: UTF16.self).jtrim()
    }

    // =====================================================================================
    // Davet
    // =====================================================================================

    func invite(_ target: PlayerProfile, _ level: Int, _ speed: Speed) {
        if mode != .NONE || requestInFlight || !OnlineSession.isSignedIn() { return }
        requestInFlight = true
        queueing = false
        myInviteId = 0
        myInviteName = target.name
        myInviteLevel = level
        myInviteSpeed = speed
        waitAge = 0
        waitExpiresAt = clock + OnlineHub.INVITE_TIMEOUT
        open(.WAITING)
        client.invite(target.id, level, speed.name(), ClientCallback(onResult: { [weak self] r in
            guard let self = self else { return }
            self.requestInFlight = false
            if let m = r.match { self.startMatch(m); return } // karşılıklı davet: maç hemen kuruldu
            self.myInviteId = r.inviteId
            self.waitExpiresAt = self.clock + (r.expiresIn >= 0 ? Float(r.expiresIn) : OnlineHub.INVITE_TIMEOUT)
            self.heartbeatTimer = 99
        }, onError: { [weak self] message in
            guard let self = self else { return }
            self.requestInFlight = false
            self.notice(OnlineHub.inviteErrorText(message), nil)
        }))
    }

    private func respond(_ inviteId: Int, _ action: String) {
        if requestInFlight { return }
        requestInFlight = true
        client.respond(inviteId, action, ClientCallback(onResult: { [weak self] match in
            guard let self = self else { return }
            self.requestInFlight = false
            if let m = match { self.startMatch(m) }
            self.heartbeatTimer = 99
        }, onError: { [weak self] message in
            guard let self = self else { return }
            self.requestInFlight = false
            if action == "accept" {
                let name = self.incoming?.otherName ?? ""
                if message == OnlineClient.ERR_SENDER_LEFT { self.notice(OnlineHub.clip(name, 12) + Txt.LEFT_GAME.s(), nil) }
                else { self.notice(Txt.INVITE_INVALID.s(), nil) }
            }
            self.heartbeatTimer = 99
        }))
    }

    private static func inviteErrorText(_ code: String?) -> String {
        if code == OnlineClient.ERR_TARGET_BUSY { return Txt.TARGET_BUSY.s() }
        if code == OnlineClient.ERR_TARGET_OFFLINE { return Txt.TARGET_OFFLINE.s() }
        if code == OnlineClient.ERR_SESSION_INVALID { return Txt.NETWORK_ERROR.s() }
        if OnlineClient.isTransient(code) { return AccountLogin.describe(code) }
        return code != nil ? clip(code!.uppercased(), 30) : Txt.INVITE_FAILED.s()
    }

    // =====================================================================================
    // Döngü (VirusHuntGame.render her karede çağırır)
    // =====================================================================================

    func update(_ delta: Float) {
        blink += delta
        clock += delta
        if paused { return }
        if mode == .INCOMING { incomingAge += delta }
        if mode == .WAITING { waitAge += delta }
        if mode == .WAITING && waitAge > OnlineHub.INVITE_TIMEOUT + 10 { notice(OnlineHub.clip(myInviteName, 12) + Txt.NO_REPLY.s(), nil) }
        if mode == .INCOMING && incomingAge > OnlineHub.INVITE_TIMEOUT + 10 {
            if let inc = incoming { handledIncoming.insert(inc.id) }
            notice(Txt.INVITE_TIMEOUT.s(), nil)
        }
        if mode == .STARTING {
            startTimer -= delta
            if startTimer <= 0, let m = pendingMatch { startMatch(m); return }
        }
        if loginRetryTimer >= 0 && !loginInFlight && !OnlineSession.isSignedIn() {
            loginRetryTimer -= delta
            if loginRetryTimer < 0 { attemptLogin() }
        }
        if !OnlineSession.isSignedIn() || inMatch || mode == .STARTING { return }
        heartbeatTimer += delta
        let fast = lobbyVisible || queueing || mode == .INCOMING || mode == .WAITING
        if heartbeatTimer >= (fast ? OnlineHub.HEARTBEAT_FAST : OnlineHub.HEARTBEAT_IDLE) && !heartbeatInFlight {
            heartbeatTimer = 0
            heartbeat()
        }
    }

    private func heartbeat() {
        Gdx.app.debug("OnlineHub", "nabız gönder (maçta=\(inMatch))")
        heartbeatInFlight = true
        let gen = heartbeatGeneration
        client.heartbeat(queueing, level, speed.name(), lobbyVisible, searchText, ClientCallback(onResult: { [weak self] s in
            guard let self = self else { return }
            self.heartbeatInFlight = false
            if gen != self.heartbeatGeneration || self.inMatch || self.paused { return } // eskimiş cevap
            self.onState(s)
        }, onError: { [weak self] message in
            guard let self = self else { return }
            self.heartbeatInFlight = false
            Gdx.app.debug("OnlineHub", "nabız hatası: \(message ?? "-")")
            if message == OnlineClient.ERR_SESSION_INVALID {
                OnlineSession.signOut()
                self.autoLogin()
            }
        }))
    }

    private func onState(_ s: OnlineClient.LobbyState) {
        OnlineSession.updateProfile(s.me)
        lobbyState = s
        if let m = s.match {
            if startedMatches.contains(m.matchId) { return }
            if mode == .WAITING {
                noticeLine1 = OnlineHub.clip(myInviteName, 12) + " " + Txt.STATUS_ACCEPTED.s()
                noticeLine2 = Txt.MATCH_STARTING.s()
                pendingMatch = m
                startTimer = OnlineHub.START_DELAY
                mode = .STARTING
            } else if mode != .STARTING {
                startMatch(m)
            }
            return
        }

        // Gelen davet
        if let inc = s.incoming, !handledIncoming.contains(inc.id) {
            if mode == .NONE || (mode == .INCOMING && incoming != nil && incoming!.id != inc.id) {
                incoming = inc
                incomingAge = 0
                incomingExpiresAt = clock + (inc.expiresIn >= 0 ? Float(inc.expiresIn) : OnlineHub.INVITE_TIMEOUT)
                open(.INCOMING)
            } else if mode == .INCOMING, let cur = incoming, cur.id == inc.id {
                incomingExpiresAt = synced(incomingExpiresAt, inc.expiresIn)
            }
        } else if mode == .INCOMING, let cur = incoming, !requestInFlight, (s.incoming == nil || s.incoming!.id != cur.id) {
            // Gösterdiğim davet kapandı: gönderen iptal etti / oyundan çıktı / süresi doldu.
            handledIncoming.insert(cur.id)
            let c = (s.incomingClosed != nil && s.incomingClosed!.id == cur.id) ? s.incomingClosed : nil
            let name = OnlineHub.clip(cur.otherName, 12)
            let status = c?.status ?? ""
            if status == "cancelled" { notice(name + Txt.CANCELLED_INVITE.s(), nil) }
            else if status == "sender_left" { notice(name + Txt.LEFT_GAME.s(), nil) }
            else if status == "expired" { notice(Txt.INVITE_TIMEOUT.s(), nil) }
            else { notice(Txt.INVITE_INVALID.s(), nil) }
        }

        // Giden davetin geri sayımı sunucu süresine eşitlenir.
        if mode == .WAITING && myInviteId != 0, let out = s.outgoing, out.id == myInviteId, out.status == "pending" {
            waitExpiresAt = synced(waitExpiresAt, out.expiresIn)
        }

        // Kabul edildi göründüğü hâlde maç gelmiyorsa bekleme bitsin.
        if mode == .WAITING && myInviteId != 0, let out = s.outgoing, out.id == myInviteId, out.status == "accepted" {
            acceptedWithoutMatch += 1
            if acceptedWithoutMatch >= 3 { notice(Txt.INVITE_INVALID.s(), nil) }
        } else {
            acceptedWithoutMatch = 0
        }

        // Gönderdiğim davetin sonucu
        if mode == .WAITING && myInviteId != 0, let out = s.outgoing, out.id == myInviteId,
           out.status != "pending", out.status != "accepted" {
            let name = OnlineHub.clip(myInviteName, 12)
            switch out.status {
            case "declined": notice(name + " " + Txt.STATUS_DECLINED.s(), nil)
            case "expired": notice(name + Txt.NO_REPLY.s(), nil)
            case "receiver_left": notice(name + Txt.LEFT_GAME.s(), nil)
            default: notice(Txt.INVITE_INVALID.s(), nil)
            }
        }
    }

    private func startMatch(_ info: MatchInfo) {
        Gdx.app.debug("OnlineHub", "maç başlat \(info.matchId)")
        if startedMatches.contains(info.matchId) { return }
        startedMatches.insert(info.matchId)
        close()
        releaseFrame = false
        disposeSnapshot()
        queueing = false
        inMatch = true
        heartbeatGeneration += 1
        let current = game.getScreen()
        if savedInput != nil && Gdx.input.getInputProcessor() === modalInput { Gdx.input.setInputProcessor(nil) }
        savedInput = nil
        game.setScreen(OnlineVsScreen(game, info))
        current?.dispose()
    }

    // =====================================================================================
    // Uygulama yaşam döngüsü
    // =====================================================================================

    func onPause() {
        paused = true
        heartbeatGeneration += 1
        if OnlineSession.isSignedIn() && !inMatch { client.leave() }
        if mode == .INCOMING, let inc = incoming { handledIncoming.insert(inc.id) }
        if mode == .INCOMING || mode == .WAITING { close() }
        queueing = false
    }

    func onResume() {
        paused = false
        heartbeatTimer = 99
        if !OnlineSession.isSignedIn() { autoLogin() }
    }

    // =====================================================================================
    // Pencere
    // =====================================================================================

    private func open(_ m: Mode) {
        if mode == .NONE {
            savedInput = Gdx.input.getInputProcessor()
            Gdx.input.setInputProcessor(modalInput)
            modalInput.tapCount = 0
        }
        mode = m
    }

    private func notice(_ line1: String?, _ line2: String?) {
        noticeLine1 = line1
        noticeLine2 = line2
        open(.NOTICE)
    }

    private func close() {
        if mode == .NONE { return }
        mode = .NONE
        if Gdx.input.getInputProcessor() === modalInput { Gdx.input.setInputProcessor(savedInput) }
        savedInput = nil
        modalInput.tapCount = 0
        // Kapatan dokunuş bu karede arkadaki ekrana da "yeni dokunuş" görünmesin.
        releaseFrame = true
    }

    /// true dönerse arkadaki ekranın render'ı bu karede ÇAĞRILMAZ ve görüntüyü bu sınıf çizer.
    func renderOverlay(_ delta: Float, _ renderScreen: () -> Void) -> Bool {
        if mode == .NONE && !releaseFrame {
            disposeSnapshot()
            return false
        }
        ensureGraphics()
        if snapshot == nil {
            // Pencere bu karede açıldı: arkadaki ekranı son kez çiz ve görüntüsünü al.
            renderScreen()
            captureSnapshot()
        }
        Gdx.gl.glClearColor(0, 0, 0, 1)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT)
        drawSnapshot()
        if mode != .NONE {
            handleModalInput()
            if mode != .NONE { drawModal() }
        } else {
            releaseFrame = false
        }
        return true
    }

    func resize(_ width: Int, _ height: Int) {
        viewport.update(width, height, true)
    }

    private func ensureGraphics() {
        if batch == nil {
            let b = SpriteBatch()
            batch = b
            ui = NesUi(b)
            viewport.update(Gdx.graphics.getWidth(), Gdx.graphics.getHeight(), true)
        }
    }

    private func captureSnapshot() {
        let w = Gdx.graphics.getBackBufferWidth(), h = Gdx.graphics.getBackBufferHeight()
        let pm = Pixmap.createFromFrameBuffer(0, 0, w, h)
        snapshot = Texture.from(pm)
        pm.dispose()
        if let s = snapshot {
            let region = TextureRegion(s)
            region.flip(false, true) // GL alt satırdan okur
            snapshotRegion = region
        }
    }

    private func drawSnapshot() {
        guard let region = snapshotRegion, let batch = batch else { return }
        let m = Matrix4.ortho2D(0, 0, Float(Gdx.graphics.getWidth()), Float(Gdx.graphics.getHeight()))
        batch.setProjectionMatrix(m)
        batch.begin()
        batch.disableBlending()
        batch.draw(region, 0, 0, Float(Gdx.graphics.getWidth()), Float(Gdx.graphics.getHeight()))
        batch.enableBlending()
        batch.end()
    }

    private func disposeSnapshot() {
        if snapshot != nil {
            snapshot?.dispose()
            snapshot = nil
            snapshotRegion = nil
        }
    }

    private func box() -> Rectangle {
        let ox = GameConfig.contentX(viewport.getWorldWidth())
        let h: Float = mode == .INCOMING || mode == .WAITING ? 118 : 74
        return Rectangle(ox + (Float(GameConfig.CONTENT_WIDTH) - OnlineHub.BOX_W) / 2, (Float(GameConfig.WORLD_HEIGHT) - h) / 2, OnlineHub.BOX_W, h)
    }

    private func leftButton() -> Rectangle { let b = box(); return Rectangle(b.x + 14, b.y + 8, 80, OnlineHub.BTN_H) }
    private func rightButton() -> Rectangle { let b = box(); return Rectangle(b.x + b.width - 94, b.y + 8, 80, OnlineHub.BTN_H) }
    private func centerButton(_ w: Float) -> Rectangle { let b = box(); return Rectangle(b.x + (b.width - w) / 2, b.y + 8, w, OnlineHub.BTN_H) }

    private func drawModal() {
        guard let batch = batch, let ui = ui else { return }
        camera.update()
        batch.setProjectionMatrix(camera.combined)
        batch.begin()
        let worldW = viewport.getWorldWidth()
        ui.rect(0, 0, worldW, Float(GameConfig.WORLD_HEIGHT), Color(0, 0, 0, 0.6))
        let b = box()
        let cx = b.x + b.width / 2
        let top = b.y + b.height
        switch mode {
        case .INCOMING:
            guard let inc = incoming else { break }
            ui.roundRectBorder(b.x, b.y, b.width, b.height, 6, 2, NesUi.YELLOW, NesUi.BLACK)
            ui.textCentered(Txt.NEW_INVITE.s(), cx, top - 14, 1, 2, NesUi.CYAN)
            ui.textCentered(OnlineHub.clip(inc.otherName, 12) + Txt.INVITES_YOU.s(), cx, top - 30, 1, 1, NesUi.YELLOW)
            let r = Rank.fromRating(inc.otherRating)
            ui.textCentered(r.label() + "  \(inc.otherRating) " + Txt.RP.s(), cx, top - 42, 1, 1, NesUi.GRAY)
            drawSettings(cx, top - 58, inc.level, Speed.valueOf(inc.speed))
            drawCountdown(b, incomingExpiresAt)
            button(leftButton(), Txt.ACCEPT.s(), NesUi.GREEN)
            button(rightButton(), Txt.DECLINE.s(), NesUi.RED)
        case .WAITING:
            ui.roundRectBorder(b.x, b.y, b.width, b.height, 6, 2, NesUi.CYAN, NesUi.BLACK)
            ui.textCentered(Txt.INVITE_SENT.s(), cx, top - 14, 1, 2, NesUi.CYAN)
            ui.textCentered(OnlineHub.clip(myInviteName, 12), cx, top - 30, 1, 2, NesUi.YELLOW)
            drawSettings(cx, top - 50, myInviteLevel, myInviteSpeed)
            ui.textCentered(Txt.WAITING_REPLY.s() + dots(), cx, top - 80, 1, 1, NesUi.WHITE)
            drawCountdown(b, waitExpiresAt)
            button(centerButton(110), Txt.CANCEL_INVITE.s(), NesUi.YELLOW)
        case .NOTICE:
            ui.roundRectBorder(b.x, b.y, b.width, b.height, 6, 2, NesUi.WHITE, NesUi.BLACK)
            ui.textCentered(noticeLine1 ?? "", cx, top - 22, 1, 1, NesUi.YELLOW)
            if let l2 = noticeLine2 { ui.textCentered(l2, cx, top - 36, 1, 1, NesUi.WHITE) }
            button(centerButton(80), Txt.OK_BTN.s(), NesUi.GREEN)
        case .STARTING:
            ui.roundRectBorder(b.x, b.y, b.width, b.height, 6, 2, NesUi.GREEN, NesUi.BLACK)
            ui.textCentered(noticeLine1 ?? "", cx, top - 26, 1, 1, NesUi.GREEN)
            ui.textCentered((noticeLine2 ?? "") + dots(), cx, top - 44, 1, 1, NesUi.WHITE)
        case .NONE:
            break
        }
        batch.end()
    }

    private func drawSettings(_ cx: Float, _ y: Float, _ lvl: Int, _ spd: Speed?) {
        guard let ui = ui else { return }
        ui.textCentered(Txt.VIRUS_LEVEL.s() + ": \(lvl)", cx, y, 1, 1, NesUi.WHITE)
        ui.textCentered(Txt.SPEED.s() + ": " + (spd?.label() ?? "-"), cx, y - 12, 1, 1, NesUi.WHITE)
    }

    private func synced(_ current: Float, _ expiresIn: Int) -> Float {
        if expiresIn < 0 { return current }
        let target = clock + Float(expiresIn)
        return abs(target - current) > 1.1 ? target : current
    }

    private func drawCountdown(_ b: Rectangle, _ expiresAt: Float) {
        guard let ui = ui else { return }
        let left = max(0, Int((expiresAt - clock).rounded(.up)))
        let t = String(left)
        ui.text(t, b.x + b.width - 8 - ui.textWidth(t, 1, 1), b.y + b.height - 14, 1, 1, NesUi.GRAY)
    }

    private func button(_ r: Rectangle, _ label: String, _ color: Color) {
        guard let ui = ui else { return }
        ui.roundRectBorder(r.x, r.y, r.width, r.height, 4, 1, color, NesUi.BLACK)
        ui.textCentered(label, r.x + r.width / 2, r.y + 5, 1, 1, NesUi.WHITE)
    }

    private func handleModalInput() {
        let enter = Gdx.input.isKeyJustPressed(Input.Keys.ENTER)
        let esc = Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)
        let n = modalInput.tapCount
        modalInput.tapCount = 0
        for i in -1..<n {
            var x: Float = -1, y: Float = -1
            if i >= 0 {
                var v = Vector3(Float(modalInput.tapX[i]), Float(modalInput.tapY[i]), 0)
                viewport.unproject(&v)
                x = v.x
                y = v.y
            }
            switch mode {
            case .INCOMING:
                if requestInFlight { return }
                guard let inc = incoming else { return }
                if (i < 0 && enter) || leftButton().contains(x, y) {
                    handledIncoming.insert(inc.id)
                    respond(inc.id, "accept")
                    return
                }
                if rightButton().contains(x, y) {
                    handledIncoming.insert(inc.id)
                    respond(inc.id, "decline")
                    close()
                    return
                }
            case .WAITING:
                if (i < 0 && esc) || centerButton(110).contains(x, y) {
                    if myInviteId != 0 { respond(myInviteId, "cancel") }
                    close()
                    return
                }
            case .NOTICE:
                if (i < 0 && (enter || esc)) || centerButton(80).contains(x, y) {
                    close()
                    return
                }
            default:
                break
            }
        }
    }

    func dispose() {
        disposeSnapshot()
        batch?.dispose()
        ui?.dispose()
        batch = nil
        ui = nil
        if OnlineHub.instance === self { OnlineHub.instance = nil }
    }

    // ---- Yardımcılar ----

    private func dots() -> String { return String(repeating: ".", count: Int(blink * 2) % 4) }

    static func clip(_ s: String?, _ max: Int) -> String { return LeaderboardScreen.clip(s, max) }
}
