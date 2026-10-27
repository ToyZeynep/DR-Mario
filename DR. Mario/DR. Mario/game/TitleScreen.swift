//
//  TitleScreen.swift
//  DR. Mario
//
//  com.rummuscan.game.TitleScreen (VirusHunt Android sürümünden birebir): yeşil dama zemin, dev
//  iki renkli kapsül logosu ve altında siyah menü paneli. Seçili satırı kırmızı kalp gösterir.
//

import Foundation

final class TitleScreen: Screen {

    private static let CAPSULE_X: Float = 20, CAPSULE_Y: Float = 120, CAPSULE_W: Float = 216, CAPSULE_H: Float = 70
    private static let SUBTITLE_Y: Float = 100, SUBTITLE_SCALE: Float = 1.5, SUBTITLE_SPACING: Float = 3
    private static let PANEL_X: Float = 16, PANEL_Y: Float = 24, PANEL_W: Float = 224, PANEL_H: Float = 64
    private static let MENU_CENTER_X: Float = 132
    private static let MENU_TOP_BASELINE: Float = 70
    private static let MENU_LINE_STEP: Float = 14
    private static let MENU_SCALE: Float = 1
    private static let FEEDBACK_Y: Float = 208, FEEDBACK_RIGHT: Float = 250
    private static let HELP_LEFT: Float = 6
    private static let MENU_SPACING: Float = 3

    private let game: Game

    private let batch = SpriteBatch()
    private let ui: NesUi
    private let assets = Assets()

    private let camera = OrthographicCamera()
    private let viewport: ExtendViewport

    private let modes = GameMode.allCases
    private func rowCount() -> Int { return modes.count + 1 }
    private func rowLabel(_ i: Int) -> String { return i < modes.count ? modes[i].menuLabel() : Txt.MENU_SETTINGS.s() }
    private var selected = 0
    private var blinkTimer: Float = 0
    private var comingSoonTimer: Float = 0
    private var switchingAway = false

    init(_ game: Game) {
        self.game = game
        ui = NesUi(batch)
        viewport = ExtendViewport(GameConfig.CONTENT_WIDTH, GameConfig.WORLD_HEIGHT, camera)
    }

    func show() {}

    func render(_ delta: Float) {
        blinkTimer += delta
        if comingSoonTimer > 0 { comingSoonTimer -= delta }

        handleInput()
        if switchingAway { return }

        Gdx.gl.glClearColor(0, 0, 0, 1)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT)

        camera.update()
        batch.setProjectionMatrix(camera.combined)

        let worldW = viewport.getWorldWidth()
        let ox = GameConfig.contentX(worldW)

        batch.begin()
        ui.checkerboard(worldW, Float(GameConfig.WORLD_HEIGHT), 8, NesUi.CHECK_GREEN_A, NesUi.CHECK_GREEN_B)
        drawLogo(ox)
        drawMenuPanel(ox)
        batch.end()
    }

    private func drawLogo(_ ox: Float) {
        ui.capsule(ox + TitleScreen.CAPSULE_X, TitleScreen.CAPSULE_Y, TitleScreen.CAPSULE_W, TitleScreen.CAPSULE_H,
                   NesUi.PILL_BLUE, NesUi.PILL_RED, NesUi.BLACK)

        let centerX = ox + TitleScreen.CAPSULE_X + TitleScreen.CAPSULE_W / 2

        let scale: Float = 3, spacing: Float = 6
        let textY = TitleScreen.CAPSULE_Y + (TitleScreen.CAPSULE_H - PixelFont.height(scale)) / 2
        ui.textCenteredOutlined(Txt.TITLE_MAIN.s(), centerX, textY, scale, spacing, NesUi.YELLOW, NesUi.DARK_BROWN)

        ui.textCenteredOutlined(Txt.TITLE_SUB.s(), centerX, TitleScreen.SUBTITLE_Y, TitleScreen.SUBTITLE_SCALE, TitleScreen.SUBTITLE_SPACING,
                                NesUi.WHITE, NesUi.DARK_BROWN)
    }

    private func drawMenuPanel(_ ox: Float) {
        ui.roundRect(ox + TitleScreen.PANEL_X, TitleScreen.PANEL_Y, TitleScreen.PANEL_W, TitleScreen.PANEL_H, 8, NesUi.BLACK)

        if let doctor = assets.doctor {
            batch.draw(doctor, ox + 26, TitleScreen.PANEL_Y + 8, 26, 46)
        }
        if let virus = assets.virusBlue {
            batch.draw(virus, ox + 198, TitleScreen.PANEL_Y + 16, 30, 30)
        }

        let blockX = ox + TitleScreen.MENU_CENTER_X - widestMenuWidth() / 2
        for i in 0..<rowCount() {
            let y = TitleScreen.MENU_TOP_BASELINE - Float(i) * TitleScreen.MENU_LINE_STEP
            ui.text(rowLabel(i), blockX, y, TitleScreen.MENU_SCALE, TitleScreen.MENU_SPACING, NesUi.WHITE)
            if i == selected {
                ui.heart(blockX - 14, y, 1.6, NesUi.RED)
            }
        }

        ui.text(Txt.HOW_TO_PLAY.s(), ox + TitleScreen.HELP_LEFT, TitleScreen.FEEDBACK_Y, 1, 1, NesUi.YELLOW)

        if Feedback.isAvailable() {
            let fb = Txt.FEEDBACK.s()
            ui.text(fb, ox + TitleScreen.FEEDBACK_RIGHT - ui.textWidth(fb, 1, 1), TitleScreen.FEEDBACK_Y, 1, 1, NesUi.WHITE)
        }

        if comingSoonTimer > 0 && Int(blinkTimer * 4) % 2 == 0 {
            ui.textCentered(Txt.COMING_SOON.s(), ox + Float(GameConfig.CONTENT_WIDTH) / 2, 10, 1, 3, NesUi.YELLOW)
        }
    }

    // ---- Girdi ----

    private func widestMenuWidth() -> Float {
        var m: Float = 0
        for i in 0..<rowCount() {
            m = max(m, PixelFont.width(rowLabel(i), TitleScreen.MENU_SCALE, TitleScreen.MENU_SPACING))
        }
        return m
    }

    private func handleInput() {
        if Gdx.input.isKeyJustPressed(Input.Keys.UP) || Gdx.input.isKeyJustPressed(Input.Keys.W) {
            selected = (selected + rowCount() - 1) % rowCount()
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.DOWN) || Gdx.input.isKeyJustPressed(Input.Keys.S) {
            selected = (selected + 1) % rowCount()
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.ENTER) || Gdx.input.isKeyJustPressed(Input.Keys.SPACE) {
            confirm()
            return
        }

        if !Gdx.input.justTouched() { return }
        var touch = Vector3(Float(Gdx.input.getX()), Float(Gdx.input.getY()), 0)
        viewport.unproject(&touch)
        let ox = GameConfig.contentX(viewport.getWorldWidth())
        let hw = ui.textWidth(Txt.HOW_TO_PLAY.s(), 1, 1)
        if Rectangle(ox + TitleScreen.HELP_LEFT - 6, TitleScreen.FEEDBACK_Y - 6, hw + 12, 20).contains(touch.x, touch.y) {
            switchingAway = true
            game.setScreen(HelpScreen(game))
            dispose()
            return
        }
        if Feedback.isAvailable() {
            let w = ui.textWidth(Txt.FEEDBACK.s(), 1, 1)
            let fb = Rectangle(ox + TitleScreen.FEEDBACK_RIGHT - w - 6, TitleScreen.FEEDBACK_Y - 6, w + 12, 20)
            if fb.contains(touch.x, touch.y) {
                Feedback.open()
                return
            }
        }
        for i in 0..<rowCount() {
            let y = TitleScreen.MENU_TOP_BASELINE - Float(i) * TitleScreen.MENU_LINE_STEP
            let row = Rectangle(ox + TitleScreen.PANEL_X, y - 5, TitleScreen.PANEL_W, TitleScreen.MENU_LINE_STEP)
            if row.contains(touch.x, touch.y) {
                selected = i
                confirm()
                return
            }
        }
    }

    private func confirm() {
        if selected >= modes.count {
            switchingAway = true
            game.setScreen(SettingsScreen(game))
            dispose()
            return
        }
        let mode = modes[selected]
        if !mode.playable {
            comingSoonTimer = 1.8
            return
        }
        switchingAway = true
        game.setScreen(LevelSelectScreen(game, mode))
        dispose()
    }

    func resize(_ width: Int, _ height: Int) { viewport.update(width, height, true) }
    func pause() {}
    func resume() {}
    func hide() {}

    func dispose() {
        batch.dispose()
        ui.dispose()
        assets.dispose()
    }
}
