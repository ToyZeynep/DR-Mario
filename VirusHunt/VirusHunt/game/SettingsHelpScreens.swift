//
//  SettingsHelpScreens.swift
//  VirusHunt
//
//  com.rummuscan.game.SettingsScreen + HelpScreen (VirusHunt Android sürümünden birebir).
//

import Foundation

/// AYARLAR: hesap, müzik aç/kapa, (AB/BK'de) reklam gizliliği, geri.
final class SettingsScreen: Screen {

    private enum Row: Int, CaseIterable { case ACCOUNT, MUSIC, AD_PRIVACY, BACK }

    private static let TITLE_Y: Float = 206
    private static let PANEL_X: Float = 16, PANEL_Y: Float = 34, PANEL_W: Float = 224, PANEL_H: Float = 166
    private static let FIRST_ROW_Y: Float = 160, ROW_STEP: Float = 34
    private static let ROW_X: Float = 40, ROW_W: Float = 176, BTN_H: Float = 20
    private static let OPT_W: Float = 44, OPT_GAP: Float = 8
    private static let BACK_W: Float = 64, BACK_Y: Float = 44

    private let game: Game
    private let batch = SpriteBatch()
    private let ui: NesUi
    private let camera = OrthographicCamera()
    private let viewport: ExtendViewport

    private var row = Row.ACCOUNT
    private var switchingAway = false

    init(_ game: Game) {
        self.game = game
        ui = NesUi(batch)
        viewport = ExtendViewport(GameConfig.CONTENT_WIDTH, GameConfig.WORLD_HEIGHT, camera)
    }

    func show() {}

    func render(_ delta: Float) {
        handleInput()
        if switchingAway { return }

        Gdx.gl.glClearColor(0, 0, 0, 1)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT)
        camera.update()
        batch.setProjectionMatrix(camera.combined)

        let S = SettingsScreen.self
        let worldW = viewport.getWorldWidth()
        let ox = GameConfig.contentX(worldW)
        let cx = ox + Float(GameConfig.CONTENT_WIDTH) / 2

        batch.begin()
        ui.checkerboard(worldW, Float(GameConfig.WORLD_HEIGHT), 8, NesUi.CHECK_GREEN_A, NesUi.CHECK_GREEN_B)
        ui.textCenteredOutlined(Txt.MENU_SETTINGS.s(), cx, S.TITLE_Y, 1.5, 3, NesUi.YELLOW, NesUi.BLACK)
        ui.roundRectBorder(ox + S.PANEL_X, S.PANEL_Y, S.PANEL_W, S.PANEL_H, 6, 2, NesUi.WHITE, NesUi.BLACK)

        button(accountBounds(ox), Txt.MENU_ACCOUNT.s(), NesUi.CYAN)

        let my = S.rowY(.MUSIC)
        ui.text(Txt.SETTING_MUSIC.s(), ox + S.ROW_X, my + 6, 1, 2, NesUi.WHITE)
        let on = GameMusic.isEnabled()
        option(onBounds(ox), Txt.SETTING_ON.s(), on)
        option(offBounds(ox), Txt.SETTING_OFF.s(), !on)

        if SettingsScreen.showAdPrivacy() { button(adPrivacyBounds(ox), Txt.AD_PRIVACY.s(), NesUi.GRAY) }

        button(backBounds(ox), Txt.BACK.s(), NesUi.WHITE)

        let sel = selectedBounds(ox)
        ui.triangleRight(ox + S.ROW_X - 12, sel.y + sel.height / 2, 4, NesUi.LIGHT_ORANGE)
        batch.end()
    }

    private func button(_ r: Rectangle, _ label: String, _ border: Color) {
        ui.roundRectBorder(r.x, r.y, r.width, r.height, 4, 1, border, NesUi.BLACK)
        ui.textCentered(label, r.x + r.width / 2, r.y + (r.height - 7) / 2, 1, 2, NesUi.WHITE)
    }

    private func option(_ r: Rectangle, _ label: String, _ selected: Bool) {
        ui.roundRectBorder(r.x, r.y, r.width, r.height, 4, 1, selected ? NesUi.LIGHT_ORANGE : NesUi.GRAY, NesUi.BLACK)
        ui.textCentered(label, r.x + r.width / 2, r.y + (r.height - 7) / 2, 1, 1, selected ? NesUi.WHITE : NesUi.GRAY)
    }

    // ---- Geometri ----

    private static func rowY(_ r: Row) -> Float { return FIRST_ROW_Y - Float(r.rawValue) * ROW_STEP }

    private func accountBounds(_ ox: Float) -> Rectangle {
        return Rectangle(ox + SettingsScreen.ROW_X, SettingsScreen.rowY(.ACCOUNT), SettingsScreen.ROW_W, SettingsScreen.BTN_H)
    }

    private func adPrivacyBounds(_ ox: Float) -> Rectangle {
        return Rectangle(ox + SettingsScreen.ROW_X, SettingsScreen.rowY(.AD_PRIVACY), SettingsScreen.ROW_W, SettingsScreen.BTN_H)
    }

    private static func showAdPrivacy() -> Bool { return Ads.isPrivacyOptionsRequired() }

    private func offBounds(_ ox: Float) -> Rectangle {
        let S = SettingsScreen.self
        return Rectangle(ox + S.ROW_X + S.ROW_W - S.OPT_W, S.rowY(.MUSIC), S.OPT_W, S.BTN_H)
    }

    private func onBounds(_ ox: Float) -> Rectangle {
        let S = SettingsScreen.self
        return Rectangle(ox + S.ROW_X + S.ROW_W - 2 * S.OPT_W - S.OPT_GAP, S.rowY(.MUSIC), S.OPT_W, S.BTN_H)
    }

    private func backBounds(_ ox: Float) -> Rectangle {
        let S = SettingsScreen.self
        return Rectangle(ox + (Float(GameConfig.CONTENT_WIDTH) - S.BACK_W) / 2, S.BACK_Y, S.BACK_W, S.BTN_H)
    }

    private func selectedBounds(_ ox: Float) -> Rectangle {
        switch row {
        case .ACCOUNT: return accountBounds(ox)
        case .MUSIC: return onBounds(ox)
        case .AD_PRIVACY: return adPrivacyBounds(ox)
        default: return backBounds(ox)
        }
    }

    // ---- Girdi ----

    private func handleInput() {
        if Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
            back()
            return
        }
        let rows = Row.allCases
        if Gdx.input.isKeyJustPressed(Input.Keys.UP) || Gdx.input.isKeyJustPressed(Input.Keys.W) {
            row = rows[(row.rawValue + rows.count - 1) % rows.count]
            if row == .AD_PRIVACY && !SettingsScreen.showAdPrivacy() { row = .MUSIC }
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.DOWN) || Gdx.input.isKeyJustPressed(Input.Keys.S) {
            row = rows[(row.rawValue + 1) % rows.count]
            if row == .AD_PRIVACY && !SettingsScreen.showAdPrivacy() { row = .BACK }
        }
        if row == .MUSIC {
            if Gdx.input.isKeyJustPressed(Input.Keys.LEFT) { GameMusic.setEnabled(true) }
            if Gdx.input.isKeyJustPressed(Input.Keys.RIGHT) { GameMusic.setEnabled(false) }
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.ENTER) || Gdx.input.isKeyJustPressed(Input.Keys.SPACE) {
            activate(row)
            return
        }

        if !Gdx.input.justTouched() { return }
        var v = Vector3(Float(Gdx.input.getX()), Float(Gdx.input.getY()), 0)
        viewport.unproject(&v)
        let ox = GameConfig.contentX(viewport.getWorldWidth())
        if SettingsScreen.grow(accountBounds(ox)).contains(v.x, v.y) {
            row = .ACCOUNT
            activate(row)
        } else if SettingsScreen.grow(onBounds(ox)).contains(v.x, v.y) {
            row = .MUSIC
            GameMusic.setEnabled(true)
        } else if SettingsScreen.grow(offBounds(ox)).contains(v.x, v.y) {
            row = .MUSIC
            GameMusic.setEnabled(false)
        } else if SettingsScreen.showAdPrivacy() && SettingsScreen.grow(adPrivacyBounds(ox)).contains(v.x, v.y) {
            row = .AD_PRIVACY
            activate(row)
        } else if SettingsScreen.grow(backBounds(ox)).contains(v.x, v.y) {
            back()
        }
    }

    private static func grow(_ r: Rectangle) -> Rectangle {
        return Rectangle(r.x - 3, r.y - 4, r.width + 6, r.height + 8)
    }

    private func activate(_ r: Row) {
        switch r {
        case .ACCOUNT:
            switchingAway = true
            game.setScreen(AccountScreen(game, .SETTINGS))
            dispose()
        case .MUSIC:
            GameMusic.setEnabled(!GameMusic.isEnabled())
        case .AD_PRIVACY:
            Ads.showPrivacyOptions()
        default:
            back()
        }
    }

    private func back() {
        switchingAway = true
        game.setScreen(TitleScreen(game))
        dispose()
    }

    func resize(_ width: Int, _ height: Int) { viewport.update(width, height, true) }
    func pause() {}
    func resume() {}
    func hide() {}

    func dispose() {
        batch.dispose()
        ui.dispose()
    }
}

/// NASIL OYNANIR: sayfalı yardım metinleri (HelpText) + gizlilik politikası bağlantısı.
final class HelpScreen: Screen {

    static let PRIVACY_URL = "https://legendaryteam.org/virushunt/privacy/"
    static let INVITE_SECONDS = 30

    static let PANEL_X: Float = 8, PANEL_Y: Float = 30, PANEL_W: Float = 240, PANEL_H: Float = 168
    static let TEXT_W: Float = PANEL_W - 12
    static let LINE_H: Float = 11
    private static let TITLE_Y: Float = 206
    private static let BTN_Y: Float = 6, BTN_H: Float = 18

    private let game: Game
    private let pages: [HelpText.Page]
    private var page = 0
    private var switchingAway = false

    private let batch = SpriteBatch()
    private let ui: NesUi
    private let camera = OrthographicCamera()
    private let viewport: ExtendViewport

    private let tapCatcher = TapCatcher(4)

    init(_ game: Game) {
        self.game = game
        pages = HelpText.pages(Lang.current())
        ui = NesUi(batch)
        viewport = ExtendViewport(GameConfig.CONTENT_WIDTH, GameConfig.WORLD_HEIGHT, camera)
    }

    func show() { Gdx.input.setInputProcessor(tapCatcher) }

    /// Sayfanın satırları (yer tutucular doldurulmuş, kutu genişliğine göre bölünmüş).
    static func lines(_ p: HelpText.Page) -> [String] {
        var body = p.body
            .replacingOccurrences(of: "{P}", with: String(Rank.MATCH_POINTS))
            .replacingOccurrences(of: "{T}", with: String(INVITE_SECONDS))
        var ranks = ""
        for r in Rank.allCases { ranks += "\n" + r.label() + "  " + String(r.minRating) + "+ " + Txt.RP.s() }
        body = body.replacingOccurrences(of: "{RANKS}", with: ranks)
        var out: [String] = []
        for para in body.components(separatedBy: "\n") {
            var line = ""
            for word in para.components(separatedBy: " ") {
                if word.isEmpty { continue }
                let candidate = line.isEmpty ? word : line + " " + word
                if !line.isEmpty && PixelFont.width(candidate, 1, 1) > TEXT_W {
                    out.append(line)
                    line = word
                } else {
                    line = candidate
                }
            }
            if !line.isEmpty { out.append(line) }
        }
        return out
    }

    static func maxLines(_ privacyPage: Bool) -> Int {
        let usable = PANEL_H - 14 - (privacyPage ? 26 : 6)
        return Int(usable / LINE_H) + 1
    }

    func render(_ delta: Float) {
        if switchingAway { return }
        handleInput()
        if switchingAway { return }
        tapCatcher.tapCount = 0

        Gdx.gl.glClearColor(0, 0, 0, 1)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT)
        camera.update()
        batch.setProjectionMatrix(camera.combined)
        let S = HelpScreen.self
        let worldW = viewport.getWorldWidth()
        let ox = GameConfig.contentX(worldW)
        let cx = ox + Float(GameConfig.CONTENT_WIDTH) / 2

        batch.begin()
        ui.checkerboard(worldW, Float(GameConfig.WORLD_HEIGHT), 8, NesUi.CHECK_GREEN_A, NesUi.CHECK_GREEN_B)
        let p = pages[page]
        ui.textCenteredOutlined(p.title, cx, S.TITLE_Y, 1.5, 3, NesUi.YELLOW, NesUi.BLACK)
        ui.roundRectBorder(ox + S.PANEL_X, S.PANEL_Y, S.PANEL_W, S.PANEL_H, 6, 2, NesUi.WHITE, NesUi.BLACK)
        var y = S.PANEL_Y + S.PANEL_H - 14
        for line in HelpScreen.lines(p) {
            ui.text(line, ox + S.PANEL_X + 6, y, 1, 1, NesUi.WHITE)
            y -= S.LINE_H
        }
        if page == HelpText.PRIVACY_PAGE { button(privacyBounds(ox), Txt.PRIVACY_POLICY.s(), NesUi.CYAN) }

        if page > 0 { button(prevBounds(ox), "<", NesUi.WHITE) }
        if page < pages.count - 1 { button(nextBounds(ox), ">", NesUi.WHITE) }
        ui.textCentered("\(page + 1)/\(pages.count)", cx, S.BTN_Y + 5, 1, 1, NesUi.YELLOW)
        button(backBounds(ox), Txt.BACK.s(), NesUi.RED)
        batch.end()
    }

    private func button(_ r: Rectangle, _ label: String, _ color: Color) {
        ui.roundRectBorder(r.x, r.y, r.width, r.height, 4, 1, color, NesUi.BLACK)
        ui.textCentered(label, r.x + r.width / 2, r.y + 5, 1, 1, NesUi.WHITE)
    }

    private func prevBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 82, HelpScreen.BTN_Y, 26, HelpScreen.BTN_H) }
    private func nextBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 148, HelpScreen.BTN_Y, 26, HelpScreen.BTN_H) }
    private func backBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 204, HelpScreen.BTN_Y, 46, HelpScreen.BTN_H) }
    private func privacyBounds(_ ox: Float) -> Rectangle { return Rectangle(ox + 48, HelpScreen.PANEL_Y + 8, 160, HelpScreen.BTN_H) }

    private func handleInput() {
        if Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK) { back(); return }
        if Gdx.input.isKeyJustPressed(Input.Keys.RIGHT) { page = min(pages.count - 1, page + 1) }
        if Gdx.input.isKeyJustPressed(Input.Keys.LEFT) { page = max(0, page - 1) }
        let ox = GameConfig.contentX(viewport.getWorldWidth())
        for t in 0..<tapCatcher.tapCount {
            var v = Vector3(Float(tapCatcher.tapX[t]), Float(tapCatcher.tapY[t]), 0)
            viewport.unproject(&v)
            if backBounds(ox).contains(v.x, v.y) { back(); return }
            if page == HelpText.PRIVACY_PAGE && privacyBounds(ox).contains(v.x, v.y) {
                Gdx.net.openURI(HelpScreen.PRIVACY_URL)
                return
            }
            if prevBounds(ox).contains(v.x, v.y) { page = max(0, page - 1); return }
            if nextBounds(ox).contains(v.x, v.y) { page = min(pages.count - 1, page + 1); return }
            let panel = Rectangle(ox + HelpScreen.PANEL_X, HelpScreen.PANEL_Y, HelpScreen.PANEL_W, HelpScreen.PANEL_H)
            if panel.contains(v.x, v.y) {
                if v.x > panel.x + panel.width / 2 { page = min(pages.count - 1, page + 1) } else { page = max(0, page - 1) }
                return
            }
        }
    }

    private func back() {
        switchingAway = true
        Gdx.input.setInputProcessor(nil)
        game.setScreen(TitleScreen(game))
        dispose()
    }

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
