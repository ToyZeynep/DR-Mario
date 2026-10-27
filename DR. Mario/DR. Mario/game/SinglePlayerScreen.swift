//
//  SinglePlayerScreen.swift
//  DR. Mario
//
//  com.rummuscan.game.SinglePlayerScreen (VirusHunt Android sürümünden birebir): yeşil dama zemin,
//  ortada ilaç şişesi, solda TOP/SCORE panosu ile büyüteç, sağda logo, doktor kutusu ve
//  LEVEL/SPEED/VIRUS panosu; kenar boşluklarında dokunmatik tuşlar.
//

import Foundation

final class SinglePlayerScreen: Screen {

    private let game: Game
    private let mode: GameMode
    private let engine: GameEngine
    private let input: TouchInputHandler
    private let assets: Assets
    private let boardRenderer: BoardRenderer

    private let level: Int
    private let speed: Speed
    private let music: MusicType

    private let batch = SpriteBatch()
    private let ui: NesUi

    private let camera = OrthographicCamera()
    private let viewport: ExtendViewport

    private var accumulator: Float = 0
    private var blinkTimer: Float = 0
    private var gameOverTimer: Float = 0
    private var topScore: Int
    private var switchingAway = false
    private var continueUsed = false
    private var adShowing = false
    private var adUnavailableTimer: Float = 0
    private let continueOverlay: ContinueOverlay

    private let controls = TouchControls()
    private let bottleRenderer: BottleRenderer

    private var paused = false
    static let PAUSE_BTN_CX: Float = 222, PAUSE_BTN_CY: Float = 30, PAUSE_BTN_R: Float = 10

    // ---- Çoklu dokunuş ----
    private static let MAX_POINTERS = 8
    private let tapCatcher = TapCatcher(SinglePlayerScreen.MAX_POINTERS)

    init(_ game: Game, _ mode: GameMode, _ level: Int, _ speed: Speed, _ music: MusicType) {
        self.game = game
        self.mode = mode
        self.level = level
        self.speed = speed
        self.music = music
        ui = NesUi(batch)
        continueOverlay = ContinueOverlay(ui)

        // Tek oyunculukta seed önemsiz, gerçek rastgele üretilebilir.
        engine = GameEngine(Int64(bitPattern: DispatchTime.now().uptimeNanoseconds), GameConfig.virusCountForLevel(level), speed.tickInterval)
        input = TouchInputHandler(engine)
        assets = Assets()
        boardRenderer = BoardRenderer(ui, batch, assets, Float(GameConfig.BOARD_X), Float(GameConfig.BOARD_Y), GameConfig.CELL_W, GameConfig.CELL_H)
        bottleRenderer = BottleRenderer(ui, batch, assets)

        topScore = ScoreStore.getTopScore()

        viewport = ExtendViewport(GameConfig.CONTENT_WIDTH, GameConfig.WORLD_HEIGHT, camera)
    }

    func show() {
        Gdx.input.setInputProcessor(tapCatcher)
    }

    func render(_ delta: Float) {
        blinkTimer += delta

        let worldW = viewport.getWorldWidth()
        let ox = GameConfig.contentX(worldW)
        controls.layout(ox, worldW)

        let running = engine.getState() == .RUNNING
        GameMusic.setPaused(running && paused)
        if running && !paused {
            handleInput()
            if switchingAway { return }
            input.update(delta)

            // Sabit adımlı simülasyon.
            accumulator += delta
            while accumulator >= GameConfig.TICK_DT {
                engine.tick()
                accumulator -= GameConfig.TICK_DT
            }
            if engine.getScore() > topScore { topScore = engine.getScore() }
        } else if running {
            controls.releaseAll()
            handlePauseInput(ox)
            if switchingAway { return }
        } else {
            if gameOverTimer == 0 {
                GameMusic.playResult(music, engine.getState() == .WON)
                topScore = ScoreStore.reportScore(engine.getScore())
                if engine.getState() == .WON { ReviewPrompt.onPositiveMoment() }
            }
            gameOverTimer += delta
            if adUnavailableTimer > 0 { adUnavailableTimer -= delta }
            controls.releaseAll()
            handleGameOverInput()
            if switchingAway { return }
        }
        tapCatcher.tapCount = 0
        controls.update(delta)

        Gdx.gl.glClearColor(0, 0, 0, 1)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT)

        camera.update()
        batch.setProjectionMatrix(camera.combined)

        batch.begin()

        ui.checkerboard(worldW, Float(GameConfig.WORLD_HEIGHT), 8, NesUi.CHECK_GREEN_A, NesUi.CHECK_GREEN_B)
        bottleRenderer.render(ox + Float(GameConfig.BOARD_X), Float(GameConfig.BOARD_Y))

        boardRenderer.setOrigin(ox + Float(GameConfig.BOARD_X), Float(GameConfig.BOARD_Y))
        boardRenderer.render(engine.getBoard(),
                             running && !paused ? engine.getCurrentCapsule() : nil,
                             engine.getFlashingCells(),
                             engine.getPhaseProgress())
        bottleRenderer.renderGlassAbove(ox + Float(GameConfig.BOARD_X), Float(GameConfig.BOARD_Y))

        drawScorePanel(ox)
        drawLensPanel(ox)
        drawLogo(ox)
        drawDoctorPanel(ox)
        drawLevelPanel(ox)
        if running {
            controls.draw(ui)
            drawPauseButton(ox)
        }
        if paused { drawPauseOverlay(ox) }
        if !running { drawGameOverOverlay(ox) }
        batch.end()
    }

    // ---- HUD: not defteri panolarının kağıt alanı ----

    private static let TEXT_PAD: Float = 2

    private static func paperLeft(_ x: Float, _ w: Float) -> Float { return x + w * GameConfig.PAPER_LEFT }
    private static func paperRight(_ x: Float, _ w: Float) -> Float { return x + w * GameConfig.PAPER_RIGHT }
    private static func paperBottom(_ y: Float, _ h: Float) -> Float { return y + h * GameConfig.PAPER_BOTTOM }
    private static func paperHeight(_ h: Float) -> Float { return h * (GameConfig.PAPER_TOP - GameConfig.PAPER_BOTTOM) }

    private static func rowBaseline(_ y: Float, _ h: Float, _ rows: Int, _ index: Int) -> Float {
        let ph = paperHeight(h)
        let rowH = ph / Float(rows)
        return paperBottom(y, h) + ph - Float(index + 1) * rowH + (rowH - Float(PixelFont.GLYPH_H)) / 2
    }

    // ---- HUD: sol üst pano (TOP / SCORE) ----

    private func drawScorePanel(_ ox: Float) {
        let x = ox + GameConfig.SCORE_PANEL_X, y = GameConfig.SCORE_PANEL_Y
        let w = GameConfig.SCORE_PANEL_W, h = GameConfig.SCORE_PANEL_H
        drawClipboard(x, y, w, h)

        let blockW = ui.textWidth("0000000", 1, 2)
        let S = SinglePlayerScreen.self
        let tx = S.paperLeft(x, w) + (S.paperRight(x, w) - S.paperLeft(x, w) - blockW) / 2

        ui.text(Txt.TOP.s(), tx, S.rowBaseline(y, h, 4, 0), 1, 2, NesUi.BLACK)
        ui.text(S.digits(topScore, 7), tx, S.rowBaseline(y, h, 4, 1), 1, 2, NesUi.BLACK)
        ui.text(Txt.SCORE.s(), tx, S.rowBaseline(y, h, 4, 2), 1, 2, NesUi.BLACK)
        ui.text(S.digits(engine.getScore(), 7), tx, S.rowBaseline(y, h, 4, 3), 1, 2, NesUi.BLACK)
    }

    // ---- HUD: sol alt büyüteç ----

    private static let ALL_COLORS: [CapsuleColor] = [.RED, .YELLOW, .BLUE]
    private static let LENS_GLASS = Color(0x3070d8ff)

    private func drawLensPanel(_ ox: Float) {
        let x = ox + GameConfig.LENS_PANEL_X, y = GameConfig.LENS_PANEL_Y
        let w = GameConfig.LENS_PANEL_W, h = GameConfig.LENS_PANEL_H

        let lensCx = x + w * GameConfig.LENS_CENTER_X
        let lensCy = y + h * GameConfig.LENS_CENTER_Y
        let lensRx = w * GameConfig.LENS_RADIUS_X
        let lensRy = h * GameConfig.LENS_RADIUS_Y

        ui.ellipse(lensCx, lensCy, lensRx * 1.08, lensRy * 1.14, SinglePlayerScreen.LENS_GLASS)
        if let bg = assets.microscopeBg {
            batch.draw(bg, x, y, w, h)
        }

        let size = min(lensRx, lensRy) * 0.78
        let offsets: [(Float, Float)] = [
            (-lensRx * 0.45, lensRy * 0.32),   // kırmızı: sol üst
            (lensRx * 0.42, lensRy * 0.34),    // sarı: sağ üst
            (-lensRx * 0.02, -lensRy * 0.42),  // mavi: alt orta
        ]
        for i in 0..<SinglePlayerScreen.ALL_COLORS.count {
            let c = SinglePlayerScreen.ALL_COLORS[i]
            if !engine.getBoard().hasVirusOfColor(c) { continue }
            guard let tex = assets.virusFor(c) else { continue }
            batch.draw(tex, lensCx + offsets[i].0 - size / 2, lensCy + offsets[i].1 - size / 2, size, size)
        }
    }

    // ---- HUD: sağ üst logo ----

    private func drawLogo(_ ox: Float) {
        ui.textCenteredOutlined(Txt.TITLE_MAIN.s(), ox + GameConfig.LOGO_CENTER_X, GameConfig.LOGO_Y,
                                GameConfig.LOGO_SCALE, 1, NesUi.YELLOW, NesUi.DARK_BROWN)
    }

    // ---- HUD: doktor + sıradaki hap ----

    private func drawDoctorPanel(_ ox: Float) {
        let x = ox + GameConfig.DOCTOR_PANEL_X, y = GameConfig.DOCTOR_PANEL_Y
        let w = GameConfig.DOCTOR_PANEL_W, h = GameConfig.DOCTOR_PANEL_H
        ui.roundRectBorder(x, y, w, h, 4, 2, NesUi.YELLOW, NesUi.BLACK)

        if let doctor = assets.doctor {
            let dh = h - 10
            batch.draw(doctor, x + 8, y + 5, dh * 0.57, dh)
        }

        let next = engine.getNextColors()
        let cw = Float(GameConfig.CELL_W), ch = Float(GameConfig.CELL_H)
        let px = x + w - 8 - cw * 2
        let py = y + h - 12 - ch
        boardRenderer.drawPreviewHalf(px, py, cw, ch, next[0], true)
        boardRenderer.drawPreviewHalf(px + cw, py, cw, ch, next[1], false)
    }

    // ---- HUD: sağ alt pano (LEVEL / SPEED / VIRUS) ----

    private func drawLevelPanel(_ ox: Float) {
        let x = ox + GameConfig.LEVEL_PANEL_X, y = GameConfig.LEVEL_PANEL_Y
        let w = GameConfig.LEVEL_PANEL_W, h = GameConfig.LEVEL_PANEL_H
        drawClipboard(x, y, w, h)

        drawStatLine(x, y, w, h, 0, Txt.LEVEL.s(), SinglePlayerScreen.digits(level, 2))
        drawStatLine(x, y, w, h, 1, Txt.HUD_SPEED.s(), speed.hudLabel())
        drawStatLine(x, y, w, h, 2, Txt.VIRUS.s(), SinglePlayerScreen.digits(engine.getBoard().getVirusCount(), 2))
    }

    private func drawStatLine(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ row: Int, _ label: String, _ value: String) {
        let S = SinglePlayerScreen.self
        let baseline = S.rowBaseline(y, h, 3, row)
        let left = S.paperLeft(x, w) + S.TEXT_PAD, right = S.paperRight(x, w) - S.TEXT_PAD
        let sp = S.statLineSpacing(label, value, right - left)
        let vw = PixelFont.width(value, 1, sp[1])
        ui.text(label, left, baseline, 1, sp[0], NesUi.BLACK)
        ui.text(value, right - vw, baseline, 1, sp[1], NesUi.BLACK)
    }

    private static let STAT_MIN_GAP: Float = 4

    static func statLineWidth() -> Float {
        let w = GameConfig.LEVEL_PANEL_W
        return w * (GameConfig.PAPER_RIGHT - GameConfig.PAPER_LEFT) - 2 * TEXT_PAD
    }

    static func statLineSpacing(_ label: String, _ value: String, _ available: Float) -> [Float] {
        var ls: Float = 2, vs: Float = 2
        while ls > 0.5 && PixelFont.width(label, 1, ls) + STAT_MIN_GAP + PixelFont.width(value, 1, vs) > available { ls -= 0.5 }
        while vs > 1 && PixelFont.width(label, 1, ls) + STAT_MIN_GAP + PixelFont.width(value, 1, vs) > available { vs -= 0.5 }
        let fits = PixelFont.width(label, 1, ls) + STAT_MIN_GAP + PixelFont.width(value, 1, vs) <= available
        return [ls, vs, fits ? 1 : 0]
    }

    private func drawClipboard(_ x: Float, _ y: Float, _ w: Float, _ h: Float) {
        if let panel = assets.notepadPanel {
            batch.draw(panel, x, y, w, h)
        } else {
            ui.roundRectBorder(x, y, w, h, 3, 2, NesUi.YELLOW, Color(0xd8e0f8ff))
        }
    }

    // ---- Dokunmatik kontroller ----

    private func handleInput() {
        let left = Gdx.input.isKeyPressed(Input.Keys.LEFT) || isTouchingButton(controls.hitArea(TouchControls.LEFT))
        let right = Gdx.input.isKeyPressed(Input.Keys.RIGHT) || isTouchingButton(controls.hitArea(TouchControls.RIGHT))
        let down = Gdx.input.isKeyPressed(Input.Keys.DOWN) || isTouchingButton(controls.hitArea(TouchControls.DOWN))

        input.setLeftHeld(left)
        input.setRightHeld(right)
        input.setDownHeld(down)

        controls.setPressed(TouchControls.LEFT, left)
        controls.setPressed(TouchControls.RIGHT, right)
        controls.setPressed(TouchControls.DOWN, down)
        let rotateHeld = Gdx.input.isKeyPressed(Input.Keys.UP) || isTouchingButton(controls.hitArea(TouchControls.ROTATE))
        controls.setPressed(TouchControls.ROTATE, rotateHeld)

        if Gdx.input.isKeyJustPressed(Input.Keys.UP) || justTouchedButton(controls.hitArea(TouchControls.ROTATE)) {
            input.triggerRotateCW()
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.SPACE) {
            input.triggerHardDrop()
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK)
            || justTouchedButton(pauseButtonBounds(GameConfig.contentX(viewport.getWorldWidth()))) {
            paused = true
        }
    }

    private func pauseButtonBounds(_ ox: Float) -> Rectangle {
        let S = SinglePlayerScreen.self
        return Rectangle(ox + S.PAUSE_BTN_CX - S.PAUSE_BTN_R, S.PAUSE_BTN_CY - S.PAUSE_BTN_R, S.PAUSE_BTN_R * 2, S.PAUSE_BTN_R * 2)
    }

    private func handlePauseInput(_ ox: Float) {
        if Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
            paused = false
            return
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.ENTER) {
            goToTitle()
            return
        }
        if justTouchedButton(pauseOverlayResumeBounds(ox)) {
            paused = false
        } else if justTouchedButton(pauseOverlayMenuBounds(ox)) {
            goToTitle()
        }
    }

    private func handleGameOverInput() {
        if adShowing || gameOverTimer < 0.6 { return }
        let ox = GameConfig.contentX(viewport.getWorldWidth())
        if offersContinue() {
            if justTouchedButton(continueButtonBounds(ox)) {
                startRewardedContinue()
            } else if justTouchedButton(menuButtonBounds(ox)) || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)
                        || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
                finishToTitle()
            }
            return
        }
        if tapCatcher.tapCount > 0 || Gdx.input.isKeyJustPressed(Input.Keys.ENTER)
            || Gdx.input.isKeyJustPressed(Input.Keys.SPACE) || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)
            || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
            finishToTitle()
        }
    }

    private func offersContinue() -> Bool {
        return engine.getState() == .LOST && !continueUsed && Ads.canOfferContinue()
    }

    private func startRewardedContinue() {
        adShowing = true
        var rewarded = false
        Ads.showRewarded({ rewarded = true }, { [weak self] in
            guard let self = self else { return }
            self.adShowing = false
            if self.switchingAway { return }
            if !rewarded {
                self.adUnavailableTimer = ContinueOverlay.UNAVAILABLE_SECONDS
                return
            }
            self.continueUsed = true
            self.engine.revive()
            self.gameOverTimer = 0
            self.accumulator = 0
            if self.engine.getState() == .RUNNING { GameMusic.playGameTrack(self.music) }
        })
    }

    private func finishToTitle() {
        Ads.onGameFinished()
        goToTitle()
    }

    private func goToTitle() {
        switchingAway = true
        Gdx.input.setInputProcessor(nil)
        game.setScreen(TitleScreen(game))
        dispose()
    }

    /// Herhangi bir parmak bu alanı basılı tutuyor mu?
    private func isTouchingButton(_ bounds: Rectangle) -> Bool {
        for p in 0..<SinglePlayerScreen.MAX_POINTERS {
            if !Gdx.input.isTouched(p) { continue }
            let touch = unproject(Gdx.input.getX(p), Gdx.input.getY(p))
            if bounds.contains(touch.x, touch.y) { return true }
        }
        return false
    }

    /// Bu karede bu alana YENİ dokunan bir parmak var mı?
    private func justTouchedButton(_ bounds: Rectangle) -> Bool {
        for i in 0..<tapCatcher.tapCount {
            let touch = unproject(tapCatcher.tapX[i], tapCatcher.tapY[i])
            if bounds.contains(touch.x, touch.y) { return true }
        }
        return false
    }

    private func unproject(_ screenX: Int, _ screenY: Int) -> Vector3 {
        var v = Vector3(Float(screenX), Float(screenY), 0)
        viewport.unproject(&v)
        return v
    }

    // ---- Duraklatma ----

    private func drawPauseButton(_ ox: Float) {
        let S = SinglePlayerScreen.self
        let cx = ox + S.PAUSE_BTN_CX, cy = S.PAUSE_BTN_CY, r = S.PAUSE_BTN_R
        ui.circle(cx, cy, r + 1.5, NesUi.BLACK)
        ui.circleGradient(cx, cy, r, Color(0.10, 0.12, 0.18, 0.92), Color(0.38, 0.44, 0.56, 0.92))
        ui.ring(cx, cy, r, 1.3, NesUi.WHITE)
        let barW = r * 0.24, barH = r * 0.9
        ui.rect(cx - r * 0.32 - barW / 2, cy - barH / 2, barW, barH, NesUi.WHITE)
        ui.rect(cx + r * 0.32 - barW / 2, cy - barH / 2, barW, barH, NesUi.WHITE)
    }

    private static let PAUSE_BOX_W: Float = 140, PAUSE_BOX_H: Float = 76
    private static let PAUSE_OPTION_W: Float = 100, PAUSE_OPTION_H: Float = 18

    private func pauseBoxX(_ ox: Float) -> Float { return ox + Float(GameConfig.CONTENT_WIDTH) / 2 - SinglePlayerScreen.PAUSE_BOX_W / 2 }
    private func pauseBoxY() -> Float { return Float(GameConfig.BOARD_Y) + Float(GameConfig.BOARD_PIXEL_HEIGHT) / 2 - SinglePlayerScreen.PAUSE_BOX_H / 2 }

    private func pauseOverlayResumeBounds(_ ox: Float) -> Rectangle {
        let S = SinglePlayerScreen.self
        let x = pauseBoxX(ox), y = pauseBoxY()
        return Rectangle(x + (S.PAUSE_BOX_W - S.PAUSE_OPTION_W) / 2, y + 34, S.PAUSE_OPTION_W, S.PAUSE_OPTION_H)
    }

    private func pauseOverlayMenuBounds(_ ox: Float) -> Rectangle {
        let S = SinglePlayerScreen.self
        let x = pauseBoxX(ox), y = pauseBoxY()
        return Rectangle(x + (S.PAUSE_BOX_W - S.PAUSE_OPTION_W) / 2, y + 10, S.PAUSE_OPTION_W, S.PAUSE_OPTION_H)
    }

    private func drawPauseOverlay(_ ox: Float) {
        let S = SinglePlayerScreen.self
        let x = pauseBoxX(ox), y = pauseBoxY()
        let cx = x + S.PAUSE_BOX_W / 2

        ui.roundRectBorder(x, y, S.PAUSE_BOX_W, S.PAUSE_BOX_H, 6, 2, NesUi.WHITE, NesUi.BLACK)
        ui.textCentered(Txt.PAUSED.s(), cx, y + S.PAUSE_BOX_H - 16, 1, 3, NesUi.WHITE)

        let resume = pauseOverlayResumeBounds(ox)
        ui.roundRectBorder(resume.x, resume.y, resume.width, resume.height, 4, 1, NesUi.GREEN, NesUi.BLACK)
        ui.textCentered(Txt.RESUME.s(), resume.x + resume.width / 2, resume.y + 5, 1, 2, NesUi.WHITE)

        let menu = pauseOverlayMenuBounds(ox)
        ui.roundRectBorder(menu.x, menu.y, menu.width, menu.height, 4, 1, NesUi.RED, NesUi.BLACK)
        ui.textCentered(Txt.MENU.s(), menu.x + menu.width / 2, menu.y + 5, 1, 2, NesUi.WHITE)
    }

    // ---- Oyun sonu ----

    private static func goCenterY() -> Float { return Float(GameConfig.BOARD_Y) + Float(GameConfig.BOARD_PIXEL_HEIGHT) / 2 }

    private func continueButtonBounds(_ ox: Float) -> Rectangle {
        return continueOverlay.continueBounds(ox + Float(GameConfig.CONTENT_WIDTH) / 2, SinglePlayerScreen.goCenterY())
    }

    private func menuButtonBounds(_ ox: Float) -> Rectangle {
        return continueOverlay.menuBounds(ox + Float(GameConfig.CONTENT_WIDTH) / 2, SinglePlayerScreen.goCenterY())
    }

    private func drawGameOverOverlay(_ ox: Float) {
        if offersContinue() {
            continueOverlay.draw(ox + Float(GameConfig.CONTENT_WIDTH) / 2, SinglePlayerScreen.goCenterY(), Txt.GAME_OVER.s(), NesUi.RED,
                                 adShowing, adUnavailableTimer > 0, blinkTimer)
            return
        }
        let won = engine.getState() == .WON
        let cx = ox + Float(GameConfig.CONTENT_WIDTH) / 2
        let w: Float = 136, h: Float = 48
        let x = cx - w / 2
        let y = Float(GameConfig.BOARD_Y) + Float(GameConfig.BOARD_PIXEL_HEIGHT) / 2 - h / 2

        ui.roundRectBorder(x, y, w, h, 6, 2, won ? NesUi.YELLOW : NesUi.RED, NesUi.BLACK)
        ui.textCentered(won ? Txt.STAGE_CLEAR.s() : Txt.GAME_OVER.s(), cx, y + h - 18, 1, 3, won ? NesUi.YELLOW : NesUi.WHITE)
        if Int(blinkTimer * 2) % 2 == 0 {
            ui.textCentered(Txt.PRESS_START.s(), cx, y + 10, 1, 3, NesUi.WHITE)
        }
    }

    static func digits(_ value: Int, _ count: Int) -> String { return VsBoardsRenderer.digits(value, count) }

    func getMusic() -> MusicType { return music }
    func getMode() -> GameMode { return mode }

    func resize(_ width: Int, _ height: Int) { viewport.update(width, height, true) }
    func pause() {}
    func resume() {}

    func hide() {
        if Gdx.input.getInputProcessor() === tapCatcher { Gdx.input.setInputProcessor(nil) }
    }

    func dispose() {
        batch.dispose()
        ui.dispose()
        assets.dispose()
    }
}
