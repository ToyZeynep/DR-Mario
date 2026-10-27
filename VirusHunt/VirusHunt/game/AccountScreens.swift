//
//  AccountScreens.swift
//  VirusHunt
//
//  com.rummuscan.game.AccountScreen + AccountSetupScreen (VirusHunt Android sürümünden birebir).
//
//  iOS FARKI: Play Games'in yerini Game Center alır (platform/GameCenter.swift); metinler "GAME CENTER"
//  der, akış aynıdır.
//

import Foundation

/// HESAP ekranı: profil, lider tablosu, hesabı silme.
final class AccountScreen: Screen {

    enum Return { case SETTINGS, LOBBY }

    private enum State { case IDLE, BUSY, CONFIRM_DELETE }

    private static let TITLE_Y: Float = 206
    private static let PANEL_X: Float = 16, PANEL_Y: Float = 34, PANEL_W: Float = 224, PANEL_H: Float = 166
    private static let BTN_H: Float = 18

    private let game: Game
    private let returnTo: Return
    private let level: Int
    private let speed: Speed
    private let client = OnlineClient(OnlineConfig.SERVER_BASE_URL)

    private let batch = SpriteBatch()
    private let ui: NesUi
    private let camera = OrthographicCamera()
    private let viewport: ExtendViewport

    private var state = State.IDLE
    private var toastText: String?
    private var toastTimer: Float = 0
    private var blinkTimer: Float = 0
    private var switchingAway = false

    private let tapCatcher = TapCatcher(4)

    convenience init(_ game: Game, _ returnTo: Return) { self.init(game, returnTo, 5, .MED) }

    init(_ game: Game, _ returnTo: Return, _ level: Int, _ speed: Speed) {
        self.game = game
        self.returnTo = returnTo
        self.level = level
        self.speed = speed
        ui = NesUi(batch)
        viewport = ExtendViewport(GameConfig.CONTENT_WIDTH, GameConfig.WORLD_HEIGHT, camera)
    }

    func show() {
        Gdx.input.setInputProcessor(tapCatcher)
        if !OnlineSession.isSignedIn() { OnlineHub.get()?.autoLogin() }
    }

    private func deleteAccount() {
        state = .BUSY
        client.deleteAccount(ClientCallback(onResult: { [weak self] _ in
            guard let self = self else { return }
            if !self.switchingAway { self.afterDelete() }
        }, onError: { [weak self] message in
            guard let self = self, !self.switchingAway else { return }
            if message == OnlineClient.ERR_SESSION_INVALID {
                self.afterDelete() // sunucuda zaten yok: yerelde de temizle
            } else {
                self.toast(AccountLogin.describe(message))
                self.state = .IDLE
            }
        }))
    }

    private func afterDelete() {
        OnlineSession.signOut()
        AccountPrefs.reset()
        switchingAway = true
        Gdx.input.setInputProcessor(nil)
        game.setScreen(AccountSetupScreen(game))
        dispose()
    }

    private func toast(_ text: String) {
        toastText = text
        toastTimer = 3
    }

    // ---- Çizim ----

    func render(_ delta: Float) {
        if switchingAway { return }
        blinkTimer += delta
        if toastTimer > 0 { toastTimer -= delta }
        handleInput()
        if switchingAway { return }
        tapCatcher.tapCount = 0

        Gdx.gl.glClearColor(0, 0, 0, 1)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT)
        camera.update()
        batch.setProjectionMatrix(camera.combined)

        let S = AccountScreen.self
        let worldW = viewport.getWorldWidth()
        let ox = GameConfig.contentX(worldW)
        let cx = ox + Float(GameConfig.CONTENT_WIDTH) / 2

        batch.begin()
        ui.checkerboard(worldW, Float(GameConfig.WORLD_HEIGHT), 8, NesUi.CHECK_GREEN_A, NesUi.CHECK_GREEN_B)
        ui.textCenteredOutlined(Txt.ACCOUNT_TITLE.s(), cx, S.TITLE_Y, 1.5, 3, NesUi.YELLOW, NesUi.BLACK)

        let x = ox + S.PANEL_X, y = S.PANEL_Y
        ui.roundRectBorder(x, y, S.PANEL_W, S.PANEL_H, 6, 2, NesUi.WHITE, NesUi.BLACK)
        let top = y + S.PANEL_H

        if let me = OnlineSession.me() {
            drawProfile(me, cx, top)
            button(leaderboardBounds(ox), Txt.LEADERBOARD.s(), NesUi.CYAN)
            button(deleteBounds(ox), Txt.BTN_DELETE.s(), NesUi.RED)
        } else {
            let hub = OnlineHub.get()
            if hub == nil || hub!.isLoggingIn() || hub!.loginError() == nil {
                ui.textCentered(Txt.CONNECTING.s() + dots(), cx, top - 60, 1, 2, NesUi.WHITE)
            } else {
                ui.textCentered(hub!.loginError()!, cx, top - 52, 1, 1, NesUi.RED)
                button(retryBounds(ox), Txt.RETRY.s(), NesUi.GREEN)
            }
        }
        button(backBounds(ox), Txt.BACK.s(), NesUi.WHITE)

        if state == .BUSY { ui.textCentered(Txt.DELETING.s() + dots(), cx, y + 3, 1, 1, NesUi.YELLOW) }
        if state == .CONFIRM_DELETE { drawConfirm(ox) }
        if toastTimer > 0, let t = toastText {
            ui.textCenteredOutlined(t, cx, 8, 1, 2, NesUi.YELLOW, NesUi.BLACK)
        }
        batch.end()
    }

    private func drawProfile(_ me: PlayerProfile, _ cx: Float, _ top: Float) {
        if me.verified {
            ui.textCentered(Txt.STATUS_SIGNED_IN.s(), cx, top - 16, 1, 2, NesUi.WHITE)
            ui.textCentered(me.name + "  (" + Txt.PLAY_GAMES.s() + ")", cx, top - 30, 1, 2, NesUi.GREEN)
        } else {
            ui.textCentered(Txt.STATUS_GUEST.s(), cx, top - 16, 1, 2, NesUi.WHITE)
            ui.textCentered(me.name, cx, top - 30, 1, 2, NesUi.CYAN)
        }
        ui.textCentered(me.rank().label() + "  \(me.rating) " + Txt.RP.s(), cx, top - 46, 1, 2, NesUi.YELLOW)
        ui.textCentered(Txt.WINS.s() + ": \(me.wins)    " + Txt.LOSSES.s() + ": \(me.losses)", cx, top - 60, 1, 1, NesUi.WHITE)
        let ranking = me.verified
            ? Txt.MY_RANKING.s() + ": " + (me.worldRank > 0 ? Txt.WORLD_NO.s() + String(me.worldRank) : Txt.UNRANKED.s())
            : Txt.GUESTS_NOT_RANKED.s()
        ui.textCentered(ranking, cx, top - 74, 1, 1, me.verified ? NesUi.CYAN : NesUi.GRAY)
    }

    private func drawConfirm(_ ox: Float) {
        let box = confirmBounds(ox)
        ui.roundRectBorder(box.x, box.y, box.width, box.height, 6, 2, NesUi.RED, NesUi.BLACK)
        let cx = box.x + box.width / 2
        ui.textCentered(Txt.CONFIRM_DELETE_1.s(), cx, box.y + box.height - 16, 1, 1, NesUi.WHITE)
        ui.textCentered(Txt.CONFIRM_DELETE_2.s(), cx, box.y + box.height - 28, 1, 1, NesUi.RED)
        button(yesBounds(ox), Txt.YES_DELETE.s(), NesUi.RED)
        button(noBounds(ox), Txt.NO_KEEP.s(), NesUi.GREEN)
    }

    private func button(_ r: Rectangle, _ label: String, _ color: Color) {
        ui.roundRectBorder(r.x, r.y, r.width, r.height, 4, 1, color, NesUi.BLACK)
        ui.textCentered(label, r.x + r.width / 2, r.y + 5, 1, 1, NesUi.WHITE)
    }

    // ---- Geometri ----

    private func leaderboardBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 28, 66, 200, AccountScreen.BTN_H) }
    private func retryBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 88, 90, 80, AccountScreen.BTN_H) }
    private func deleteBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 28, 42, 96, AccountScreen.BTN_H) }
    private func backBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 172, 42, 56, AccountScreen.BTN_H) }
    private func confirmBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 20, 70, 216, 70) }
    private func yesBounds(_ ox: Float) -> Rectangle { let c = confirmBounds(ox); return Rectangle(c.x + 12, c.y + 8, 90, AccountScreen.BTN_H) }
    private func noBounds(_ ox: Float) -> Rectangle { let c = confirmBounds(ox); return Rectangle(c.x + c.width - 82, c.y + 8, 70, AccountScreen.BTN_H) }

    // ---- Girdi ----

    private func handleInput() {
        if Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
            if state == .CONFIRM_DELETE { state = .IDLE } else if state == .IDLE { back() }
            return
        }
        let ox = GameConfig.contentX(viewport.getWorldWidth())
        for t in 0..<tapCatcher.tapCount {
            var v = Vector3(Float(tapCatcher.tapX[t]), Float(tapCatcher.tapY[t]), 0)
            viewport.unproject(&v)
            if tap(ox, v.x, v.y) { return }
        }
    }

    private func tap(_ ox: Float, _ x: Float, _ y: Float) -> Bool {
        if state == .CONFIRM_DELETE {
            if yesBounds(ox).contains(x, y) { deleteAccount() } else if noBounds(ox).contains(x, y) { state = .IDLE }
            return false
        }
        if state != .IDLE { return false }
        if backBounds(ox).contains(x, y) { back(); return true }
        if !OnlineSession.isSignedIn() {
            if retryBounds(ox).contains(x, y) { OnlineHub.get()?.autoLogin() }
            return false
        }
        if leaderboardBounds(ox).contains(x, y) {
            switchingAway = true
            Gdx.input.setInputProcessor(nil)
            game.setScreen(LeaderboardScreen(game, .ACCOUNT, level, speed))
            dispose()
            return true
        }
        if deleteBounds(ox).contains(x, y) { state = .CONFIRM_DELETE }
        return false
    }

    private func back() {
        switchingAway = true
        Gdx.input.setInputProcessor(nil)
        game.setScreen(returnTo == .LOBBY ? OnlineLobbyScreen(game, level, speed) : SettingsScreen(game))
        dispose()
    }

    private func dots() -> String { return String(repeating: ".", count: Int(blinkTimer * 2) % 4) }

    func resize(_ width: Int, _ height: Int) { viewport.update(width, height, true) }
    func pause() {}
    func resume() {}

    func hide() {
        if Gdx.input.getInputProcessor() === tapCatcher { Gdx.input.setInputProcessor(nil) }
    }

    func dispose() {
        batch.dispose()
        ui.dispose()
    }
}

/// İlk açılışta hesap seçimi (Play Games / misafir), bir kez.
final class AccountSetupScreen: Screen {

    private static let TITLE_Y: Float = 206
    private static let PANEL_X: Float = 16, PANEL_Y: Float = 34, PANEL_W: Float = 224, PANEL_H: Float = 160
    private static let BTN_H: Float = 18

    private let game: Game
    /// Online lobiden açıldıysa giriş sonrası oraya dönülür (nil: başlık ekranı).
    private let afterLogin: (() -> Screen)?
    private let client = OnlineClient(OnlineConfig.SERVER_BASE_URL)

    private let batch = SpriteBatch()
    private let ui: NesUi
    private let camera = OrthographicCamera()
    private let viewport: ExtendViewport

    private var busy = false
    private var busyText = ""
    private var errorText: String?
    private var blinkTimer: Float = 0
    private var switchingAway = false

    private let tapCatcher = TapCatcher(4)

    /// Platform hesabı (Android: Play Games, iOS: Game Center) yoksa düğmesi ve açıklaması gösterilmez.
    private var showPgs: Bool { return OnlineSession.accounts().isPlayGamesAvailable() }

    init(_ game: Game, _ afterLogin: (() -> Screen)? = nil) {
        self.game = game
        self.afterLogin = afterLogin
        ui = NesUi(batch)
        viewport = ExtendViewport(GameConfig.CONTENT_WIDTH, GameConfig.WORLD_HEIGHT, camera)
    }

    func show() { Gdx.input.setInputProcessor(tapCatcher) }

    private func signIn(_ mode: String) {
        if busy { return }
        busy = true
        errorText = nil
        busyText = mode == AccountPrefs.MODE_PGS ? Txt.SIGNING_IN.s() : Txt.CONNECTING.s()
        AccountLogin.login(mode, client, AccountLogin.Callback(onSuccess: { [weak self] in
            guard let self = self else { return }
            self.busy = false
            if !self.switchingAway { self.proceed(true) }
        }, onFailure: { [weak self] message, _ in
            guard let self = self else { return }
            self.busy = false
            self.errorText = message
        }))
    }

    private func proceed(_ signedIn: Bool) {
        switchingAway = true
        Gdx.input.setInputProcessor(nil)
        game.setScreen(signedIn && afterLogin != nil ? afterLogin!() : TitleScreen(game))
        dispose()
    }

    func render(_ delta: Float) {
        if switchingAway { return }
        blinkTimer += delta
        handleInput()
        if switchingAway { return }
        tapCatcher.tapCount = 0

        Gdx.gl.glClearColor(0, 0, 0, 1)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT)
        camera.update()
        batch.setProjectionMatrix(camera.combined)
        let S = AccountSetupScreen.self
        let worldW = viewport.getWorldWidth()
        let ox = GameConfig.contentX(worldW)
        let cx = ox + Float(GameConfig.CONTENT_WIDTH) / 2

        batch.begin()
        ui.checkerboard(worldW, Float(GameConfig.WORLD_HEIGHT), 8, NesUi.CHECK_GREEN_A, NesUi.CHECK_GREEN_B)
        ui.textCenteredOutlined(Txt.SETUP_TITLE.s(), cx, S.TITLE_Y, 1.5, 3, NesUi.YELLOW, NesUi.BLACK)
        let x = ox + S.PANEL_X, y = S.PANEL_Y
        ui.roundRectBorder(x, y, S.PANEL_W, S.PANEL_H, 6, 2, NesUi.WHITE, NesUi.BLACK)
        let top = y + S.PANEL_H
        if showPgs {
            ui.textCentered(Txt.EXPLAIN_PGS_1.s(), cx, top - 16, 1, 1, NesUi.GREEN)
            ui.textCentered(Txt.EXPLAIN_PGS_2.s(), cx, top - 26, 1, 1, NesUi.GREEN)
        }
        ui.textCentered(Txt.EXPLAIN_GUEST.s(), cx, top - 40, 1, 1, NesUi.CYAN)
        ui.textCentered(Txt.SETUP_ONCE.s(), cx, top - 56, 1, 1, NesUi.GRAY)

        if showPgs { button(pgsBounds(ox), Txt.BTN_PGS_SIGN_IN.s(), NesUi.GREEN) }
        button(guestBounds(ox), Txt.BTN_GUEST.s(), NesUi.CYAN)
        if let err = errorText {
            ui.textCentered(err, cx, y + 30, 1, 1, NesUi.RED)
            button(offlineBounds(ox), Txt.PLAY_OFFLINE.s(), NesUi.WHITE)
        } else if busy {
            ui.textCentered(busyText + dots(), cx, y + 30, 1, 1, NesUi.YELLOW)
        }
        batch.end()
    }

    private func button(_ r: Rectangle, _ label: String, _ color: Color) {
        ui.roundRectBorder(r.x, r.y, r.width, r.height, 4, 1, color, NesUi.BLACK)
        ui.textCentered(label, r.x + r.width / 2, r.y + 5, 1, 1, NesUi.WHITE)
    }

    private func pgsBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 28, 100, 200, AccountSetupScreen.BTN_H) }
    private func guestBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 28, 76, 200, AccountSetupScreen.BTN_H) }
    private func offlineBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 68, 40, 120, AccountSetupScreen.BTN_H) }

    private func handleInput() {
        let ox = GameConfig.contentX(viewport.getWorldWidth())
        for t in 0..<tapCatcher.tapCount {
            var v = Vector3(Float(tapCatcher.tapX[t]), Float(tapCatcher.tapY[t]), 0)
            viewport.unproject(&v)
            if busy { return }
            if showPgs && pgsBounds(ox).contains(v.x, v.y) {
                signIn(AccountPrefs.MODE_PGS)
                return
            }
            if guestBounds(ox).contains(v.x, v.y) { signIn(AccountPrefs.MODE_GUEST); return }
            if errorText != nil && offlineBounds(ox).contains(v.x, v.y) { proceed(false); return }
        }
    }

    private func dots() -> String { return String(repeating: ".", count: Int(blinkTimer * 2) % 4) }

    func resize(_ width: Int, _ height: Int) { viewport.update(width, height, true) }
    func pause() {}
    func resume() {}
    func hide() {
        if Gdx.input.getInputProcessor() === tapCatcher { Gdx.input.setInputProcessor(nil) }
    }

    func dispose() {
        batch.dispose()
        ui.dispose()
    }
}
