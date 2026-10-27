//
//  OnlineLobbyScreen.swift
//  DR. Mario
//
//  com.rummuscan.game.OnlineLobbyScreen (VirusHunt Android sürümünden birebir): online VS lobisi.
//  Solda kendi kartım, sağda oyunu o an açık olan herkes (Android ve iPhone oyuncuları birlikte);
//  bir oyuncuya dokunmak davet gönderir, HIZLI EŞLEŞME kuyruğa sokar.
//

import Foundation

final class OnlineLobbyScreen: Screen {

    private static let TITLE_Y: Float = 206
    private static let CARD_X: Float = 6, CARD_Y: Float = 34, CARD_W: Float = 100, CARD_H: Float = 166
    private static let LIST_X: Float = 112, LIST_Y: Float = 34, LIST_W: Float = 138, LIST_H: Float = 166
    private static let ROW_H: Float = 13
    private static let VISIBLE_ROWS = 9
    private static let BTN_Y: Float = 8, BTN_H: Float = 18

    private let game: Game
    private let level: Int
    private let speed: Speed
    private let hub: OnlineHub? = OnlineHub.get()

    private let batch = SpriteBatch()
    private let ui: NesUi
    private let camera = OrthographicCamera()
    private let viewport: ExtendViewport

    private var toastText: String?
    private var toastTimer: Float = 0
    private var blinkTimer: Float = 0
    private var scroll = 0
    private var refreshFlash: Float = 0
    private var switchingAway = false

    private let tapCatcher: TapDragInput

    init(_ game: Game, _ level: Int, _ speed: Speed) {
        self.game = game
        self.level = level
        self.speed = speed
        ui = NesUi(batch)
        viewport = ExtendViewport(GameConfig.CONTENT_WIDTH, GameConfig.WORLD_HEIGHT, camera)
        tapCatcher = TapDragInput(viewport, OnlineLobbyScreen.ROW_H)
    }

    func show() {
        if AccountPrefs.mode().isEmpty {
            // Hesap seçilmemiş (ilk açılışta çevrimdışı devam edildi): önce hesap seçimi.
            switchingAway = true
            let g = game, lvl = level, spd = speed
            game.setScreen(AccountSetupScreen(game, { OnlineLobbyScreen(g, lvl, spd) }))
            dispose()
            return
        }
        Gdx.input.setInputProcessor(tapCatcher)
        hub?.setLobbyVisible(true, level, speed)
        if !OnlineSession.isSignedIn() { hub?.autoLogin() }
    }

    private func toast(_ text: String) {
        toastText = text
        toastTimer = 3
    }

    // ---- Döngü ----

    func render(_ delta: Float) {
        if switchingAway { return }
        blinkTimer += delta
        if toastTimer > 0 { toastTimer -= delta }
        if refreshFlash > 0 { refreshFlash -= delta }

        handleInput()
        if switchingAway { return }
        tapCatcher.tapCount = 0

        Gdx.gl.glClearColor(0, 0, 0, 1)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT)
        camera.update()
        batch.setProjectionMatrix(camera.combined)

        let worldW = viewport.getWorldWidth()
        let ox = GameConfig.contentX(worldW)

        batch.begin()
        ui.checkerboard(worldW, Float(GameConfig.WORLD_HEIGHT), 8, NesUi.CHECK_GREEN_A, NesUi.CHECK_GREEN_B)
        let cx = ox + Float(GameConfig.CONTENT_WIDTH) / 2
        ui.textCenteredOutlined(Txt.MENU_ONLINE.s(), cx, OnlineLobbyScreen.TITLE_Y, 1.5, 3, NesUi.YELLOW, NesUi.BLACK)

        if OnlineSession.isSignedIn() {
            drawCard(ox)
            drawList(ox)
            drawButtons(ox)
        } else {
            drawStatus(ox, cx)
        }
        if toastTimer > 0, let t = toastText {
            ui.textCenteredOutlined(t, cx, 28, 1, 2, NesUi.YELLOW, NesUi.BLACK)
        }
        batch.end()
    }

    private func drawStatus(_ ox: Float, _ cx: Float) {
        let provider = AccountPrefs.mode() == AccountPrefs.MODE_PGS ? Txt.PLAY_GAMES.s() : Txt.GUEST.s()
        ui.textCentered(Txt.ACCOUNT_PREFIX.s() + provider, cx, 150, 1, 2, NesUi.WHITE)
        if let hub = hub, !hub.isLoggingIn(), let err = hub.loginError() {
            ui.textCentered(err, cx, 118, 1, 2, NesUi.RED)
            button(retryBounds(ox), Txt.RETRY.s(), NesUi.GREEN)
        } else {
            ui.textCentered(Txt.CONNECTING.s() + OnlineLobbyScreen.dotsFor(blinkTimer), cx, 118, 1, 2, NesUi.WHITE)
        }
        button(backBounds(ox), Txt.BACK.s(), NesUi.RED)
    }

    /// Sol kart: kendi profilim.
    private func drawCard(_ ox: Float) {
        let S = OnlineLobbyScreen.self
        let x = ox + S.CARD_X, y = S.CARD_Y
        ui.roundRectBorder(x, y, S.CARD_W, S.CARD_H, 6, 2, NesUi.WHITE, NesUi.BLACK)
        let cx = x + S.CARD_W / 2
        var ty = y + S.CARD_H - 16
        guard let me = OnlineSession.me() else {
            ui.textCentered("...", cx, ty, 1, 2, NesUi.GRAY)
            return
        }
        ui.textCentered(OnlineLobbyScreen.clip(me.name, 12), cx, ty, 1, 2, NesUi.YELLOW)
        ty -= 14
        let rank = me.rank()
        ui.textCentered(rank.label(), cx, ty, 1, 2, OnlineLobbyScreen.rankColor(rank))
        ty -= 12
        ui.textCentered("\(me.rating) " + Txt.RP.s(), cx, ty, 1, 2, NesUi.WHITE)
        ty -= 14
        ui.textCentered(Txt.WINS.s() + " \(me.wins)", cx, ty, 1, 1, NesUi.GREEN)
        ty -= 10
        ui.textCentered(Txt.LOSSES.s() + " \(me.losses)", cx, ty, 1, 1, NesUi.RED)
        ty -= 14
        ui.textCentered(me.worldRank > 0 ? Txt.WORLD_NO.s() + String(me.worldRank) : Txt.UNRANKED.s(), cx, ty, 1, 1, NesUi.CYAN)
        ty -= 14
        if let next = rank.next() {
            ui.textCentered(Txt.NEXT_RANK.s() + next.label(), cx, ty, 1, 1, NesUi.GRAY)
            ty -= 10
            ui.textCentered("+\(max(0, next.minRating - me.rating)) " + Txt.RP.s(), cx, ty, 1, 1, NesUi.GRAY)
        } else {
            ui.textCentered(Txt.TOP_RANK.s(), cx, ty, 1, 1, NesUi.GRAY)
            ty -= 10
        }
        ty -= 12
        ui.textCentered(me.verified ? Txt.PLAY_GAMES.s() : Txt.GUEST.s(), cx, ty, 1, 1, me.verified ? NesUi.GREEN : NesUi.GRAY)
        ty -= 10
        ui.textCentered(Txt.LV.s() + "\(level)  " + speed.label(), cx, ty, 1, 1, NesUi.GRAY)
        button(refreshBounds(ox), refreshFlash > 0 ? "..." : Txt.REFRESH.s(), refreshFlash > 0 ? NesUi.YELLOW : NesUi.CYAN)
    }

    /// Sağ liste: oyunu açık olan oyuncular puana göre; üstte arama satırı.
    private func drawList(_ ox: Float) {
        let S = OnlineLobbyScreen.self
        let x = ox + S.LIST_X, y = S.LIST_Y
        ui.roundRectBorder(x, y, S.LIST_W, S.LIST_H, 6, 2, NesUi.WHITE, NesUi.BLACK)
        let list = players()
        let header = Txt.PLAYERS_ONLINE.s() + String(list.count)
        ui.textCentered(header, x + S.LIST_W / 2, y + S.LIST_H - 14, 1, 2, NesUi.CYAN)

        let sb = searchBounds(ox)
        ui.roundRectBorder(sb.x, sb.y, sb.width, sb.height, 3, 1, NesUi.GRAY, NesUi.BLACK)
        let q = hub?.search() ?? ""
        if q.isEmpty {
            ui.text(Txt.SEARCH.s() + "...", sb.x + 4, sb.y + 3, 1, 1, NesUi.GRAY)
        } else {
            ui.text(OnlineLobbyScreen.clip(q, 16), sb.x + 4, sb.y + 3, 1, 1, NesUi.WHITE)
            ui.text("X", sb.x + sb.width - 9, sb.y + 3, 1, 1, NesUi.RED)
        }

        if list.isEmpty {
            let my = y + (S.LIST_H - 30) / 2
            if !q.isEmpty {
                ui.textCentered(Txt.NO_RESULTS.s(), x + S.LIST_W / 2, my, 1, 1, NesUi.GRAY)
            } else {
                ui.textCentered(Txt.NOBODY_HERE.s(), x + S.LIST_W / 2, my, 1, 2, NesUi.GRAY)
                ui.textCentered(Txt.TRY_QUICK_MATCH.s(), x + S.LIST_W / 2, my - 12, 1, 1, NesUi.GRAY)
            }
            return
        }
        let maxScroll = max(0, list.count - S.VISIBLE_ROWS)
        scroll = max(0, min(scroll, maxScroll))
        var i = 0
        while i < S.VISIBLE_ROWS && scroll + i < list.count {
            let p = list[scroll + i]
            let row = rowBounds(ox, i)
            if p.searching() && Int(blinkTimer * 2) % 2 == 0 { ui.rect(row.x + 1, row.y + 5, 2, 2, NesUi.GREEN) }
            let name = OnlineLobbyScreen.clip(p.name, 10)
            ui.text(name, row.x + 4, row.y + 3, 1, 1, p.inMatch() ? NesUi.GRAY : NesUi.WHITE)
            let r = p.rank()
            let right = p.inMatch() ? Txt.IN_MATCH.s() : (r.label() + " \(p.rating)")
            let avail = row.width - 4 - ui.textWidth(name, 1, 1) - 6 - 4
            let scale = fitScale(right, avail)
            let rw = ui.textWidth(right, scale, scale)
            let rightColor = p.inMatch() ? NesUi.GRAY : OnlineLobbyScreen.rankColor(r)
            ui.text(right, row.x + row.width - 4 - rw, row.y + 3 + (1 - scale) * 3.5, scale, scale, rightColor)
            i += 1
        }
        if maxScroll > 0 {
            if scroll > 0 { ui.triangleUp(x + S.LIST_W - 8, rowBounds(ox, 0).y + S.ROW_H - 6, 4, NesUi.WHITE) }
            if scroll < maxScroll { ui.triangleDown(x + S.LIST_W - 8, y + 4, 5, NesUi.WHITE) }
        }
    }

    private func drawButtons(_ ox: Float) {
        let queueing = hub?.isQueueing() ?? false
        let quick = queueing ? Txt.SEARCHING.s() + OnlineLobbyScreen.dotsFor(blinkTimer) : Txt.QUICK_MATCH.s()
        button(quickBounds(ox), quick, queueing ? NesUi.YELLOW : NesUi.GREEN)
        button(leaderboardBounds(ox), Txt.LEADERBOARD.s(), NesUi.CYAN)
        button(backBounds(ox), Txt.BACK.s(), NesUi.RED)
    }

    private func button(_ r: Rectangle, _ label: String, _ color: Color) {
        ui.roundRectBorder(r.x, r.y, r.width, r.height, 4, 1, color, NesUi.BLACK)
        ui.textCentered(label, r.x + r.width / 2, r.y + 5, 1, 1, NesUi.WHITE)
    }

    private static func rankColor(_ r: Rank) -> Color {
        switch r {
        case .SILVER: return NesUi.GRAY
        case .GOLD: return NesUi.YELLOW
        case .PLATINUM: return NesUi.CYAN
        case .DIAMOND: return NesUi.PINK
        case .MASTER: return NesUi.RED
        default: return NesUi.LIGHT_ORANGE
        }
    }

    // ---- Geometri ----

    private func searchBounds(_ ox: Float) -> Rectangle {
        let S = OnlineLobbyScreen.self
        return Rectangle(ox + S.LIST_X + 4, S.LIST_Y + S.LIST_H - 36, S.LIST_W - 8, 13)
    }
    private func searchClearBounds(_ ox: Float) -> Rectangle {
        let s = searchBounds(ox)
        return Rectangle(s.x + s.width - 16, s.y - 2, 18, s.height + 4)
    }
    private func rowBounds(_ ox: Float, _ i: Int) -> Rectangle {
        let S = OnlineLobbyScreen.self
        let top = S.LIST_Y + S.LIST_H - 40
        return Rectangle(ox + S.LIST_X + 2, top - Float(i + 1) * S.ROW_H, S.LIST_W - 4, S.ROW_H)
    }
    private func refreshBounds(_ ox: Float) -> Rectangle {
        let S = OnlineLobbyScreen.self
        return Rectangle(ox + S.CARD_X + 8, S.CARD_Y + 8, S.CARD_W - 16, S.BTN_H)
    }

    private func fitScale(_ s: String, _ avail: Float) -> Float {
        let w = ui.textWidth(s, 1, 1)
        return w <= avail ? 1 : max(0.7, avail / w)
    }

    private func quickBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 6, OnlineLobbyScreen.BTN_Y, 96, OnlineLobbyScreen.BTN_H) }
    private func leaderboardBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 112, OnlineLobbyScreen.BTN_Y, 84, OnlineLobbyScreen.BTN_H) }
    private func backBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 204, OnlineLobbyScreen.BTN_Y, 46, OnlineLobbyScreen.BTN_H) }
    private func retryBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 88, 80, 80, OnlineLobbyScreen.BTN_H) }

    /// Sunucudan gelen liste; yazılan arama bir sonraki nabzı beklemeden yerelde de süzülür.
    private func players() -> [PlayerProfile] {
        guard let hub = hub, let s = hub.state() else { return [] }
        let q = hub.search()
        return s.players.filter { q.isEmpty || OnlineHub.normalize($0.name).contains(q) }
    }

    // ---- Girdi ----

    private func handleInput() {
        if Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
            back()
            return
        }
        let ox = GameConfig.contentX(viewport.getWorldWidth())
        if OnlineSession.isSignedIn() {
            if Gdx.input.isKeyJustPressed(Input.Keys.UP) { scroll -= 1 }
            if Gdx.input.isKeyJustPressed(Input.Keys.DOWN) { scroll += 1 }
            scroll += tapCatcher.takeScroll()
            scroll = max(0, min(scroll, max(0, players().count - OnlineLobbyScreen.VISIBLE_ROWS)))
            if Gdx.input.isKeyJustPressed(Input.Keys.L) { openLeaderboard(); return }
            if Gdx.input.isKeyJustPressed(Input.Keys.F) { openSearch(); return }
            if Gdx.input.isKeyJustPressed(Input.Keys.R) { hub?.refreshNow(); refreshFlash = 0.8 }
        }
        for t in 0..<tapCatcher.tapCount {
            var v = Vector3(Float(tapCatcher.tapX[t]), Float(tapCatcher.tapY[t]), 0)
            viewport.unproject(&v)
            if tap(ox, v.x, v.y) { return }
        }
    }

    /// true dönerse ekran değişti.
    private func tap(_ ox: Float, _ x: Float, _ y: Float) -> Bool {
        let S = OnlineLobbyScreen.self
        if backBounds(ox).contains(x, y) { back(); return true }
        guard let hub = hub else { return false }
        if !OnlineSession.isSignedIn() {
            if retryBounds(ox).contains(x, y) { hub.autoLogin() }
            return false
        }
        if leaderboardBounds(ox).contains(x, y) { openLeaderboard(); return true }
        if refreshBounds(ox).contains(x, y) {
            hub.refreshNow()
            refreshFlash = 0.8
            return false
        }
        if quickBounds(ox).contains(x, y) {
            hub.setQueueing(!hub.isQueueing())
            return false
        }
        if !hub.search().isEmpty && searchClearBounds(ox).contains(x, y) {
            hub.setSearch("")
            scroll = 0
            return false
        }
        if searchBounds(ox).contains(x, y) { openSearch(); return false }

        let list = players()
        let listRect = Rectangle(ox + S.LIST_X, S.LIST_Y, S.LIST_W, S.LIST_H)
        if listRect.contains(x, y) {
            let maxScroll = max(0, list.count - S.VISIBLE_ROWS)
            if maxScroll > 0 && y < S.LIST_Y + 12 { scroll += 1; return false }
            var i = 0
            while i < S.VISIBLE_ROWS && scroll + i < list.count {
                if rowBounds(ox, i).contains(x, y) {
                    let target = list[scroll + i]
                    if target.inMatch() { toast(Txt.PLAYER_BUSY.s()) } else { hub.invite(target, level, speed) }
                    return false
                }
                i += 1
            }
            if maxScroll > 0 && y > rowBounds(ox, 0).y + S.ROW_H - 4 { scroll -= 1 }
        }
        return false
    }

    private final class SearchListener: TextInputListener {
        weak var screen: OnlineLobbyScreen?
        init(_ s: OnlineLobbyScreen) { screen = s }
        func input(_ text: String) {
            Gdx.app.postRunnable { [weak self] in
                guard let s = self?.screen else { return }
                s.hub?.setSearch(text)
                s.scroll = 0
            }
        }
        func canceled() {}
    }

    /// Arama: sistemin metin kutusu.
    private func openSearch() {
        Gdx.input.getTextInput(SearchListener(self), Txt.SEARCH.s(), hub?.search() ?? "", Txt.SEARCH_HINT.s())
    }

    private func openLeaderboard() {
        switchingAway = true
        Gdx.input.setInputProcessor(nil)
        game.setScreen(LeaderboardScreen(game, level, speed))
        dispose()
    }

    private func back() {
        switchingAway = true
        Gdx.input.setInputProcessor(nil)
        game.setScreen(TitleScreen(game))
        dispose()
    }

    // ---- Yardımcılar ----

    private static func clip(_ s: String?, _ max: Int) -> String { return LeaderboardScreen.clip(s, max) }

    private static func dotsFor(_ t: Float) -> String { return String(repeating: ".", count: Int(t * 2) % 4) }

    func resize(_ width: Int, _ height: Int) { viewport.update(width, height, true) }
    func pause() {}
    func resume() {}

    func hide() {
        if Gdx.input.getInputProcessor() === tapCatcher { Gdx.input.setInputProcessor(nil) }
    }

    func dispose() {
        hub?.setLobbyVisible(false, level, speed)
        batch.dispose()
        ui.dispose()
    }
}
