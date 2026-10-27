//
//  LevelSelectScreen.swift
//  VirusHunt
//
//  com.rummuscan.game.LevelSelectScreen (VirusHunt Android sürümünden birebir): turuncu/pembe dama
//  zemin üstünde VIRUS LEVEL (0..20 cetvel), SPEED (LOW/MED/HI) ve MUSIC TYPE / CPU LEVEL satırları.
//

import Foundation

final class LevelSelectScreen: Screen {

    private enum Row: Int, CaseIterable { case LEVEL, SPEED, MUSIC }

    private static let DESIGN_PANEL_X: Float = 14, DESIGN_PANEL_Y: Float = 26
    private static let DESIGN_PANEL_W: Float = 228, DESIGN_PANEL_H: Float = 188

    static let PANEL_H: Float = Float(GameConfig.WORLD_HEIGHT) - 8
    static let SCALE: Float = PANEL_H / DESIGN_PANEL_H
    static let PANEL_W: Float = DESIGN_PANEL_W * SCALE
    static let PANEL_Y: Float = 4
    static let PANEL_X: Float = (Float(GameConfig.CONTENT_WIDTH) - PANEL_W) / 2

    private static func sx(_ designX: Float) -> Float { return PANEL_X + (designX - DESIGN_PANEL_X) * SCALE }
    private static func sy(_ designY: Float) -> Float { return PANEL_Y + (designY - DESIGN_PANEL_Y) * SCALE }

    static let CORNER_BTN_W: Float = 56 * SCALE, CORNER_BTN_H: Float = 17 * SCALE
    static let CORNER_BTN_Y: Float = PANEL_Y + PANEL_H - CORNER_BTN_H - 2 * SCALE
    static let START_X: Float = PANEL_X + PANEL_W - CORNER_BTN_W - 8 * SCALE
    static let BACK_X: Float = PANEL_X + 8 * SCALE

    static let TITLE_SCALE: Float = 1.5 * SCALE
    static let TITLE_SPACING: Float = 3 * SCALE
    static let TITLE_Y: Float = 180

    private static let LABEL_X: Float = sx(26)
    static let LABEL_H: Float = 15 * SCALE
    static let LEVEL_LABEL_Y: Float = sy(162)
    private static let SPEED_LABEL_Y: Float = sy(104)
    private static let MUSIC_LABEL_Y: Float = sy(58)

    private static let RULER_X: Float = sx(54), RULER_W: Float = 132 * SCALE, RULER_LINE_Y: Float = sy(136)
    private static let LEVEL_BOX_X: Float = sx(194), LEVEL_BOX_Y: Float = sy(128)
    private static let LEVEL_BOX_W: Float = 34 * SCALE, LEVEL_BOX_H: Float = 20 * SCALE

    private static let SPEED_ROW_Y: Float = sy(84)
    private static let SPEED_X0: Float = sx(62), SPEED_STEP_MIN: Float = 50 * SCALE

    private static let MUSIC_ROW_Y: Float = sy(38)
    private static let MUSIC_X0: Float = sx(44), MUSIC_STEP_MIN: Float = 60 * SCALE

    private static let TXT: Float = 1 * SCALE
    private static let SP: Float = 3 * SCALE

    private let game: Game
    private let mode: GameMode

    private let batch = SpriteBatch()
    private let ui: NesUi

    private let camera = OrthographicCamera()
    private let viewport: ExtendViewport

    private let speeds = Speed.allCases
    private let musics = MusicType.allCases
    private let difficulties = Difficulty.allCases
    private let isCpuVs: Bool
    private let isOnlineVs: Bool

    private var level = 0
    private var speedIndex = 1  // MED
    private var musicIndex = GameMusic.musicType().ordinal
    private var difficultyIndex = 1 // MEDIUM
    private var row = Row.LEVEL
    private var switchingAway = false
    private var draggingRuler = false

    convenience init(_ game: Game) { self.init(game, .SINGLE) }

    init(_ game: Game, _ mode: GameMode) {
        self.game = game
        self.mode = mode
        isCpuVs = mode == .CPU_VS
        isOnlineVs = mode == .ONLINE_VS
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

        let worldW = viewport.getWorldWidth()
        let ox = GameConfig.contentX(worldW)

        batch.begin()
        ui.checkerboard(worldW, Float(GameConfig.WORLD_HEIGHT), 8, NesUi.CHECK_ORANGE, NesUi.CHECK_PINK)
        drawPanelFrame(ox)
        ui.textCentered(mode.settingsTitle(), ox + Float(GameConfig.CONTENT_WIDTH) / 2, LevelSelectScreen.TITLE_Y,
                        LevelSelectScreen.TITLE_SCALE, LevelSelectScreen.TITLE_SPACING, NesUi.WHITE)
        drawVirusLevelRow(ox)
        drawSpeedRow(ox)
        drawThirdRow(ox)
        drawBackButton(ox)
        drawStartButton(ox)
        batch.end()
    }

    private func drawPanelFrame(_ ox: Float) {
        let S = LevelSelectScreen.self
        let x = ox + S.PANEL_X
        let r = 10 * S.SCALE
        ui.roundRect(x, S.PANEL_Y, S.PANEL_W, S.PANEL_H, r, NesUi.YELLOW)
        ui.roundRect(x + 1, S.PANEL_Y + 1, S.PANEL_W - 2, S.PANEL_H - 2, r - 1, NesUi.BLACK)
        ui.roundRect(x + 3, S.PANEL_Y + 3, S.PANEL_W - 6, S.PANEL_H - 6, r - 3, NesUi.PINK)
        ui.roundRect(x + 6, S.PANEL_Y + 6, S.PANEL_W - 12, S.PANEL_H - 12, r - 5, NesUi.WHITE)
        ui.roundRect(x + 7, S.PANEL_Y + 7, S.PANEL_W - 14, S.PANEL_H - 14, r - 6, NesUi.BLACK)
    }

    // ---- VIRUS LEVEL ----

    private func drawVirusLevelRow(_ ox: Float) {
        let S = LevelSelectScreen.self
        drawLabelBox(ox, Txt.VIRUS_LEVEL.s(), S.LEVEL_LABEL_Y, NesUi.PINK, .LEVEL)

        ui.text("1P", ox + S.sx(30), S.RULER_LINE_Y + 2, S.TXT, S.SP, NesUi.WHITE)

        let x0 = ox + S.RULER_X
        ui.rect(x0, S.RULER_LINE_Y, S.RULER_W, 1, NesUi.WHITE)
        let steps = GameConfig.MAX_LEVEL - GameConfig.MIN_LEVEL
        for i in 0...steps {
            let tx = x0 + tickOffset(i)
            let end = (i == 0 || i == steps)
            let len: Float = (end ? 9 : 5) * S.SCALE
            ui.rect(tx, S.RULER_LINE_Y - len, 1, len, NesUi.WHITE)
        }

        let cursorX = x0 + tickOffset(level - GameConfig.MIN_LEVEL)
        ui.triangleDown(cursorX + 0.5, S.RULER_LINE_Y + 3, 5 * S.SCALE, NesUi.LIGHT_ORANGE)

        ui.roundRectBorder(ox + S.LEVEL_BOX_X, S.LEVEL_BOX_Y, S.LEVEL_BOX_W, S.LEVEL_BOX_H, 3 * S.SCALE, 1, NesUi.GREEN, NesUi.BLACK)
        ui.textCentered(LevelSelectScreen.two(level), ox + S.LEVEL_BOX_X + S.LEVEL_BOX_W / 2, S.LEVEL_BOX_Y + 6 * S.SCALE,
                        1.5 * S.SCALE, 3 * S.SCALE, NesUi.WHITE)
    }

    private func tickOffset(_ index: Int) -> Float {
        let steps = GameConfig.MAX_LEVEL - GameConfig.MIN_LEVEL
        return LevelSelectScreen.RULER_W * Float(index) / Float(steps)
    }

    // ---- SPEED ----

    private func drawSpeedRow(_ ox: Float) {
        let S = LevelSelectScreen.self
        drawLabelBox(ox, Txt.SPEED.s(), S.SPEED_LABEL_Y, NesUi.LIGHT_ORANGE, .SPEED)
        ui.text("1P", ox + S.sx(30), S.SPEED_ROW_Y, S.TXT, S.SP, NesUi.WHITE)

        for i in 0..<speeds.count {
            ui.text(speeds[i].label(), ox + speedX(i), S.SPEED_ROW_Y, S.TXT, S.SP, NesUi.WHITE)
        }
        let w = ui.textWidth(speeds[speedIndex].label(), S.TXT, S.SP)
        ui.triangleDown(ox + speedX(speedIndex) + w / 2, S.SPEED_ROW_Y + 10 * S.SCALE, 5 * S.SCALE, NesUi.LIGHT_ORANGE)
    }

    // ---- MUSIC TYPE / CPU LEVEL ----

    private func drawThirdRow(_ ox: Float) {
        let S = LevelSelectScreen.self
        let title = isCpuVs ? Txt.CPU_LEVEL.s() : Txt.MUSIC_TYPE.s()
        let labels = isCpuVs ? difficultyLabels() : musicLabels()
        let selected = isCpuVs ? difficultyIndex : musicIndex

        drawLabelBox(ox, title, S.MUSIC_LABEL_Y, NesUi.LIGHT_ORANGE, .MUSIC)

        for i in 0..<labels.count {
            let w = ui.textWidth(labels[i], S.TXT, S.SP)
            if i == selected {
                ui.roundRectBorder(ox + thirdX(i) - 6 * S.SCALE, S.MUSIC_ROW_Y - 5 * S.SCALE, w + 12 * S.SCALE, 17 * S.SCALE, 4 * S.SCALE, 1,
                                   NesUi.LIGHT_ORANGE, NesUi.BLACK)
            }
            ui.text(labels[i], ox + thirdX(i), S.MUSIC_ROW_Y, S.TXT, S.SP, NesUi.WHITE)
        }
    }

    private func speedX(_ i: Int) -> Float {
        let S = LevelSelectScreen.self
        var maxW: Float = 0
        for s in speeds { maxW = max(maxW, ui.textWidth(s.label(), S.TXT, S.SP)) }
        return S.SPEED_X0 + Float(i) * max(S.SPEED_STEP_MIN, maxW + 12 * S.SCALE)
    }

    private func thirdX(_ i: Int) -> Float {
        let S = LevelSelectScreen.self
        let labels = isCpuVs ? difficultyLabels() : musicLabels()
        var maxW: Float = 0
        for l in labels { maxW = max(maxW, ui.textWidth(l, S.TXT, S.SP)) }
        return S.MUSIC_X0 + Float(i) * max(S.MUSIC_STEP_MIN, maxW + 16 * S.SCALE)
    }

    private func musicLabels() -> [String] { return musics.map { $0.label() } }
    private func difficultyLabels() -> [String] { return difficulties.map { $0.label() } }

    // ---- Ortak parçalar ----

    private func drawLabelBox(_ ox: Float, _ label: String, _ y: Float, _ border: Color, _ owner: Row) {
        let S = LevelSelectScreen.self
        let w = ui.textWidth(label, S.TXT, S.SP) + 16 * S.SCALE
        ui.roundRectBorder(ox + S.LABEL_X, y, w, S.LABEL_H, 4 * S.SCALE, 1, border, NesUi.BLACK)
        ui.text(label, ox + S.LABEL_X + 8 * S.SCALE, y + 4 * S.SCALE, S.TXT, S.SP, NesUi.WHITE)
        if row == owner {
            ui.triangleRight(ox + S.LABEL_X - 8 * S.SCALE, y + S.LABEL_H / 2, 4 * S.SCALE, NesUi.LIGHT_ORANGE)
        }
    }

    private func drawStartButton(_ ox: Float) {
        let S = LevelSelectScreen.self
        ui.roundRectBorder(ox + S.START_X, S.CORNER_BTN_Y, S.CORNER_BTN_W, S.CORNER_BTN_H, 4 * S.SCALE, 1, NesUi.WHITE, NesUi.BLACK)
        ui.textCentered(Txt.START.s(), ox + S.START_X + S.CORNER_BTN_W / 2, S.CORNER_BTN_Y + 5 * S.SCALE, S.TXT, S.SP, NesUi.YELLOW)
    }

    private func drawBackButton(_ ox: Float) {
        let S = LevelSelectScreen.self
        ui.roundRectBorder(ox + S.BACK_X, S.CORNER_BTN_Y, S.CORNER_BTN_W, S.CORNER_BTN_H, 4 * S.SCALE, 1, NesUi.WHITE, NesUi.BLACK)
        ui.textCentered(Txt.BACK.s(), ox + S.BACK_X + S.CORNER_BTN_W / 2, S.CORNER_BTN_Y + 5 * S.SCALE, S.TXT, S.SP, NesUi.YELLOW)
    }

    private static func two(_ value: Int) -> String { return value < 10 ? "0\(value)" : String(value) }

    // ---- Girdi ----

    private func handleInput() {
        if Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
            back()
            return
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.UP) { row = prevRow() }
        if Gdx.input.isKeyJustPressed(Input.Keys.DOWN) { row = nextRow() }
        if Gdx.input.isKeyJustPressed(Input.Keys.LEFT) { changeValue(-1) }
        if Gdx.input.isKeyJustPressed(Input.Keys.RIGHT) { changeValue(1) }
        if Gdx.input.isKeyJustPressed(Input.Keys.ENTER) || Gdx.input.isKeyJustPressed(Input.Keys.SPACE) {
            startGame()
            return
        }

        // Cetvel SÜRÜKLEME: dokunuş cetvelde başladıysa parmak bırakılana kadar imleç onu takip eder.
        if Gdx.input.isTouched() {
            let held = unproject(Gdx.input.getX(), Gdx.input.getY())
            if Gdx.input.justTouched() && rulerBounds().contains(held.x, held.y) {
                draggingRuler = true
            }
            if draggingRuler {
                row = .LEVEL
                level = levelAt(held.x)
                return
            }
        } else {
            draggingRuler = false
        }

        if !Gdx.input.justTouched() { return }
        let touch = unproject(Gdx.input.getX(), Gdx.input.getY())
        handleTouch(touch.x, touch.y)
    }

    private func unproject(_ screenX: Int, _ screenY: Int) -> Vector3 {
        var v = Vector3(Float(screenX), Float(screenY), 0)
        viewport.unproject(&v)
        return v
    }

    private func rulerBounds() -> Rectangle {
        let S = LevelSelectScreen.self
        let ox = GameConfig.contentX(viewport.getWorldWidth())
        return Rectangle(ox + S.RULER_X - 6 * S.SCALE, S.RULER_LINE_Y - 12 * S.SCALE, S.RULER_W + 12 * S.SCALE, 28 * S.SCALE)
    }

    private func levelAt(_ worldX: Float) -> Int {
        let ox = GameConfig.contentX(viewport.getWorldWidth())
        let steps = GameConfig.MAX_LEVEL - GameConfig.MIN_LEVEL
        let t = (worldX - (ox + LevelSelectScreen.RULER_X)) / LevelSelectScreen.RULER_W
        return LevelSelectScreen.clamp(javaRound(t * Float(steps)) + GameConfig.MIN_LEVEL, GameConfig.MIN_LEVEL, GameConfig.MAX_LEVEL)
    }

    private func handleTouch(_ tx: Float, _ ty: Float) {
        let S = LevelSelectScreen.self
        let ox = GameConfig.contentX(viewport.getWorldWidth())

        if Rectangle(ox + S.START_X, S.CORNER_BTN_Y, S.CORNER_BTN_W, S.CORNER_BTN_H).contains(tx, ty) {
            startGame()
            return
        }
        if Rectangle(ox + S.BACK_X, S.CORNER_BTN_Y, S.CORNER_BTN_W, S.CORNER_BTN_H).contains(tx, ty) {
            back()
            return
        }

        if rulerBounds().contains(tx, ty) {
            row = .LEVEL
            level = levelAt(tx)
            return
        }

        for i in 0..<speeds.count {
            let w = ui.textWidth(speeds[i].label(), S.TXT, S.SP)
            if Rectangle(ox + speedX(i) - 6 * S.SCALE, S.SPEED_ROW_Y - 5 * S.SCALE, w + 12 * S.SCALE, 18 * S.SCALE).contains(tx, ty) {
                row = .SPEED
                speedIndex = i
                return
            }
        }

        let thirdLabels = isCpuVs ? difficultyLabels() : musicLabels()
        for i in 0..<thirdLabels.count {
            let w = ui.textWidth(thirdLabels[i], S.TXT, S.SP)
            if Rectangle(ox + thirdX(i) - 6 * S.SCALE, S.MUSIC_ROW_Y - 5 * S.SCALE, w + 12 * S.SCALE, 18 * S.SCALE).contains(tx, ty) {
                row = .MUSIC
                if isCpuVs { difficultyIndex = i } else { selectMusic(i) }
                return
            }
        }
    }

    private func prevRow() -> Row {
        let rows = Row.allCases
        return rows[(row.rawValue + rows.count - 1) % rows.count]
    }

    private func nextRow() -> Row {
        let rows = Row.allCases
        return rows[(row.rawValue + 1) % rows.count]
    }

    private func changeValue(_ dir: Int) {
        switch row {
        case .LEVEL:
            level = LevelSelectScreen.clamp(level + dir, GameConfig.MIN_LEVEL, GameConfig.MAX_LEVEL)
        case .SPEED:
            speedIndex = LevelSelectScreen.clamp(speedIndex + dir, 0, speeds.count - 1)
        default:
            if isCpuVs {
                difficultyIndex = LevelSelectScreen.clamp(difficultyIndex + dir, 0, difficulties.count - 1)
            } else {
                selectMusic(LevelSelectScreen.clamp(musicIndex + dir, 0, musics.count - 1))
            }
        }
    }

    private static func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { return max(lo, min(hi, v)) }

    /// MÜZİK satırında seçim değişti: seçim saklanır ve seçilen parça hemen çalar.
    private func selectMusic(_ index: Int) {
        if index == musicIndex { return }
        musicIndex = index
        GameMusic.setMusicType(musics[index])
        GameMusic.playGameTrack(musics[index])
    }

    private func back() {
        switchingAway = true
        game.setScreen(TitleScreen(game))
        dispose()
    }

    private func startGame() {
        switchingAway = true
        if isCpuVs {
            game.setScreen(VsScreen(game, level, speeds[speedIndex], difficulties[difficultyIndex]))
        } else if isOnlineVs {
            game.setScreen(OnlineLobbyScreen(game, level, speeds[speedIndex]))
        } else {
            game.setScreen(SinglePlayerScreen(game, mode, level, speeds[speedIndex], musics[musicIndex]))
        }
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
