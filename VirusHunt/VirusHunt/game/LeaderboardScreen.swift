//
//  LeaderboardScreen.swift
//  VirusHunt
//
//  com.rummuscan.game.LeaderboardScreen (VirusHunt Android sürümünden birebir): dünya sıralaması.
//

import Foundation

final class LeaderboardScreen: Screen {

    enum Return { case LOBBY, ACCOUNT }

    private static let TITLE_Y: Float = 206
    private static let PANEL_X: Float = 24, PANEL_Y: Float = 34, PANEL_W: Float = 208, PANEL_H: Float = 166
    private static let ROW_H: Float = 12
    private static let VISIBLE_ROWS = 11
    private static let BTN_Y: Float = 8, BTN_H: Float = 18

    private let game: Game
    private let returnTo: Return
    private let level: Int
    private let speed: Speed
    private let client = OnlineClient(OnlineConfig.SERVER_BASE_URL)

    private let batch = SpriteBatch()
    private let ui: NesUi
    private let camera = OrthographicCamera()
    private let viewport: ExtendViewport

    private var board: OnlineClient.Leaderboard?
    private var errorText: String?
    private var blinkTimer: Float = 0
    private var scroll = 0
    private var switchingAway = false

    private let tapCatcher: TapDragInput

    convenience init(_ game: Game, _ level: Int, _ speed: Speed) { self.init(game, .LOBBY, level, speed) }

    init(_ game: Game, _ returnTo: Return, _ level: Int, _ speed: Speed) {
        self.game = game
        self.returnTo = returnTo
        self.level = level
        self.speed = speed
        ui = NesUi(batch)
        viewport = ExtendViewport(GameConfig.CONTENT_WIDTH, GameConfig.WORLD_HEIGHT, camera)
        tapCatcher = TapDragInput(viewport, LeaderboardScreen.ROW_H)
    }

    func show() {
        Gdx.input.setInputProcessor(tapCatcher)
        client.leaderboard(ClientCallback(onResult: { [weak self] lb in
            guard let self = self, !self.switchingAway else { return }
            self.board = lb
            OnlineSession.updateProfile(lb.me)
        }, onError: { [weak self] message in
            guard let self = self, !self.switchingAway else { return }
            self.errorText = message != nil ? AccountLogin.describe(message) : Txt.NETWORK_ERROR.s()
        }))
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

        let S = LeaderboardScreen.self
        let worldW = viewport.getWorldWidth()
        let ox = GameConfig.contentX(worldW)
        let cx = ox + Float(GameConfig.CONTENT_WIDTH) / 2

        batch.begin()
        ui.checkerboard(worldW, Float(GameConfig.WORLD_HEIGHT), 8, NesUi.CHECK_GREEN_A, NesUi.CHECK_GREEN_B)
        ui.textCenteredOutlined(Txt.WORLD_RANKING.s(), cx, S.TITLE_Y, 1.5, 3, NesUi.YELLOW, NesUi.BLACK)

        let x = ox + S.PANEL_X, y = S.PANEL_Y
        ui.roundRectBorder(x, y, S.PANEL_W, S.PANEL_H, 6, 2, NesUi.WHITE, NesUi.BLACK)

        if let err = errorText {
            ui.textCentered(err, cx, y + S.PANEL_H / 2, 1, 2, NesUi.RED)
        } else if board == nil {
            ui.textCentered(Txt.LOADING.s() + LeaderboardScreen.dotsFor(blinkTimer), cx, y + S.PANEL_H / 2, 1, 2, NesUi.WHITE)
        } else {
            drawRows(x, y)
        }

        button(backBounds(ox), Txt.BACK.s(), NesUi.RED)
        if OnlineSession.accounts().hasNativeLeaderboardUi() {
            button(nativeBounds(ox), Txt.PLAY_GAMES.s(), NesUi.GREEN)
        }
        if let me = OnlineSession.me(), !me.verified {
            ui.textCentered(Txt.GUESTS_NOT_RANKED.s(), cx, S.PANEL_Y + 16, 1, 1, NesUi.YELLOW)
        }
        batch.end()
    }

    private func drawRows(_ x: Float, _ y: Float) {
        guard let board = board else { return }
        let S = LeaderboardScreen.self
        let top = board.top
        let me = OnlineSession.me()
        let headerY = y + S.PANEL_H - 12
        ui.text(Txt.NO.s(), x + 6, headerY, 1, 1, NesUi.CYAN)
        ui.text(Txt.PLAYER.s(), x + 36, headerY, 1, 1, NesUi.CYAN)
        ui.text(Txt.RANK.s(), x + 118, headerY, 1, 1, NesUi.CYAN)
        ui.text(Txt.RP.s(), x + 172, headerY, 1, 1, NesUi.CYAN)

        let visible = (me != nil && !me!.verified) ? S.VISIBLE_ROWS - 1 : S.VISIBLE_ROWS
        let maxScroll = max(0, top.count - visible)
        scroll = max(0, min(scroll, maxScroll))
        let rowTop = headerY - 4
        var i = 0
        while i < visible && scroll + i < top.count {
            let p = top[scroll + i]
            let ry = rowTop - Float(i + 1) * S.ROW_H
            let isMe = me != nil && p.id == me!.id
            if isMe { ui.rect(x + 2, ry - 2, S.PANEL_W - 4, S.ROW_H, Color(0.2, 0.2, 0.05, 1)) }
            let c = isMe ? NesUi.YELLOW : NesUi.WHITE
            let r = p.rank()
            ui.text(String(p.worldRank), x + 6, ry, 1, 1, c)
            ui.text(LeaderboardScreen.clip(p.name, 12), x + 36, ry, 1, 1, c)
            ui.text(r.label(), x + 118, ry, 1, 1, LeaderboardScreen.rankColor(r))
            ui.text(String(p.rating), x + 172, ry, 1, 1, c)
            i += 1
        }
        if maxScroll > 0 {
            if scroll > 0 { ui.triangleUp(x + S.PANEL_W - 8, y + S.PANEL_H - 12, 5, NesUi.WHITE) }
            if scroll < maxScroll { ui.triangleDown(x + S.PANEL_W - 8, y + 16, 5, NesUi.WHITE) }
        }
        if let mine = board.me ?? me {
            let pos = mine.worldRank > 0 ? Txt.YOU_NO.s() + String(mine.worldRank) : Txt.YOU.s() + ": " + Txt.UNRANKED.s()
            let line = pos + "  " + mine.rank().label() + " " + String(mine.rating)
            ui.textCentered(line, x + S.PANEL_W / 2, y + 4, 1, 1, NesUi.YELLOW)
        }
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

    private func backBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 204, LeaderboardScreen.BTN_Y, 46, LeaderboardScreen.BTN_H) }
    private func nativeBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 6, LeaderboardScreen.BTN_Y, 84, LeaderboardScreen.BTN_H) }

    private func handleInput() {
        if Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
            back()
            return
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.UP) { scroll -= 1 }
        if Gdx.input.isKeyJustPressed(Input.Keys.DOWN) { scroll += 1 }
        scroll += tapCatcher.takeScroll()
        let ox = GameConfig.contentX(viewport.getWorldWidth())
        let S = LeaderboardScreen.self
        for t in 0..<tapCatcher.tapCount {
            var v = Vector3(Float(tapCatcher.tapX[t]), Float(tapCatcher.tapY[t]), 0)
            viewport.unproject(&v)
            if backBounds(ox).contains(v.x, v.y) { back(); return }
            if OnlineSession.accounts().hasNativeLeaderboardUi() && nativeBounds(ox).contains(v.x, v.y) {
                OnlineSession.accounts().showNativeLeaderboard()
                return
            }
            let panel = Rectangle(ox + S.PANEL_X, S.PANEL_Y, S.PANEL_W, S.PANEL_H)
            if panel.contains(v.x, v.y) {
                if v.y > S.PANEL_Y + S.PANEL_H / 2 { scroll -= 1 } else { scroll += 1 }
            }
        }
    }

    private func back() {
        switchingAway = true
        Gdx.input.setInputProcessor(nil)
        game.setScreen(returnTo == .ACCOUNT
                       ? AccountScreen(game, .SETTINGS, level, speed)
                       : OnlineLobbyScreen(game, level, speed))
        dispose()
    }

    static func clip(_ s: String?, _ max: Int) -> String {
        guard let s = s else { return "" }
        return s.jlength <= max ? s : s.jprefix(max)
    }

    private static func dotsFor(_ t: Float) -> String { return String(repeating: ".", count: Int(t * 2) % 4) }

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
