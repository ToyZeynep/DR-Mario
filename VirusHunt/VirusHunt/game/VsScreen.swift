//
//  VsScreen.swift
//  VirusHunt
//
//  com.rummuscan.game.VsScreen (VirusHunt Android sürümünden birebir): CPU VS - iki şişe yan yana,
//  oyuncu solda, AiController sağda; aradaki ceza (garbage) alışverişi. Görsel yerleşim
//  VsBoardsRenderer'da (online VS de aynısını kullanır). İki motor AYNI seed ile kurulur.
//

import Foundation

final class VsScreen: Screen {

    private let game: Game

    private let playerEngine: GameEngine
    private let cpuEngine: GameEngine
    private let ai: AiController
    private let playerInput: TouchInputHandler
    private let assets: Assets
    private let renderer: VsBoardsRenderer

    private let batch = SpriteBatch()
    private let ui: NesUi

    private let camera = OrthographicCamera()
    private let viewport: ExtendViewport

    private let controls = TouchControls()

    private var accumulator: Float = 0
    private var blinkTimer: Float = 0
    private var gameOverTimer: Float = 0
    private var switchingAway = false

    private var paused = false

    private var continueUsed = false
    private var adShowing = false
    private var adUnavailableTimer: Float = 0
    private let continueOverlay: ContinueOverlay

    private static let MAX_POINTERS = 8
    private let tapCatcher = TapCatcher(VsScreen.MAX_POINTERS)

    init(_ game: Game, _ level: Int, _ speed: Speed, _ difficulty: Difficulty) {
        self.game = game
        ui = NesUi(batch)
        continueOverlay = ContinueOverlay(ui)

        let seed = Int64(bitPattern: DispatchTime.now().uptimeNanoseconds)
        let virusCount = GameConfig.virusCountForLevel(level)
        playerEngine = GameEngine(seed, virusCount, speed.tickInterval)
        cpuEngine = GameEngine(seed, virusCount, speed.tickInterval)
        ai = AiController(cpuEngine, difficulty, Int64(bitPattern: DispatchTime.now().uptimeNanoseconds))
        playerInput = TouchInputHandler(playerEngine)

        assets = Assets()
        renderer = VsBoardsRenderer(ui, batch, assets)

        viewport = ExtendViewport(GameConfig.CONTENT_WIDTH, GameConfig.WORLD_HEIGHT, camera)
    }

    func show() {
        Gdx.input.setInputProcessor(tapCatcher)
    }

    func render(_ delta: Float) {
        blinkTimer += delta

        let worldW = viewport.getWorldWidth()
        let ox = GameConfig.contentX(worldW)
        controls.layoutVs(ox, worldW)
        renderer.placePauseAboveRotate(controls)

        var running = matchRunning()
        GameMusic.setPaused(running && paused)
        if running && !paused {
            handleInput()
            if switchingAway { return }
            playerInput.update(delta)

            accumulator += delta
            while accumulator >= GameConfig.TICK_DT && matchRunning() {
                playerEngine.tick()
                ai.update()
                cpuEngine.tick()

                let fromPlayer = playerEngine.drainOutgoingGarbage()
                if fromPlayer.count > 0 { cpuEngine.receiveGarbage(fromPlayer) }
                let fromCpu = cpuEngine.drainOutgoingGarbage()
                if fromCpu.count > 0 { playerEngine.receiveGarbage(fromCpu) }

                accumulator -= GameConfig.TICK_DT
            }
            running = matchRunning()
        } else if running {
            controls.releaseAll()
            handlePauseInput(ox)
            if switchingAway { return }
        } else {
            if gameOverTimer == 0 {
                let result = outcome()
                GameMusic.playResult(GameMusic.musicType(), result == .DRAW ? nil : (result == .LEFT_WINS))
                if result == .LEFT_WINS { ReviewPrompt.onPositiveMoment() }
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

        renderer.drawSide(ox, true, Txt.YOU.s(), playerEngine, running && !paused)
        renderer.drawSide(ox, false, Txt.CPU.s(), cpuEngine, running && !paused)
        renderer.drawVsLabel(ox)

        if running {
            controls.draw(ui)
            renderer.drawPauseButton(ox)
        }
        if paused { renderer.drawPauseOverlay(ox) }
        if !running {
            if offersContinue() {
                continueOverlay.draw(ox + Float(GameConfig.CONTENT_WIDTH) / 2, renderer.resultCenterY(), Txt.YOU_LOSE.s(), NesUi.RED,
                                     adShowing, adUnavailableTimer > 0, blinkTimer)
            } else {
                let result = outcome()
                renderer.drawResultOverlay(ox, result == .DRAW, result == .LEFT_WINS, blinkTimer)
            }
        }
        batch.end()
    }

    private func outcome() -> VsOutcome {
        return VsOutcome.of(playerEngine.getState(), cpuEngine.getState())
    }

    private func matchRunning() -> Bool { return !outcome().isDecided() }

    // ---- Girdi (yalnızca oyuncunun tahtası) ----

    private func handleInput() {
        let left = Gdx.input.isKeyPressed(Input.Keys.LEFT) || isTouchingButton(controls.hitArea(TouchControls.LEFT))
        let right = Gdx.input.isKeyPressed(Input.Keys.RIGHT) || isTouchingButton(controls.hitArea(TouchControls.RIGHT))
        let down = Gdx.input.isKeyPressed(Input.Keys.DOWN) || isTouchingButton(controls.hitArea(TouchControls.DOWN))

        playerInput.setLeftHeld(left)
        playerInput.setRightHeld(right)
        playerInput.setDownHeld(down)

        controls.setPressed(TouchControls.LEFT, left)
        controls.setPressed(TouchControls.RIGHT, right)
        controls.setPressed(TouchControls.DOWN, down)
        let rotateHeld = Gdx.input.isKeyPressed(Input.Keys.UP) || isTouchingButton(controls.hitArea(TouchControls.ROTATE))
        controls.setPressed(TouchControls.ROTATE, rotateHeld)

        if Gdx.input.isKeyJustPressed(Input.Keys.UP) || justTouchedButton(controls.hitArea(TouchControls.ROTATE)) {
            playerInput.triggerRotateCW()
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.SPACE) {
            playerInput.triggerHardDrop()
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK)
            || justTouchedButton(renderer.pauseButtonBounds(GameConfig.contentX(viewport.getWorldWidth()))) {
            paused = true
        }
    }

    private func handleGameOverInput() {
        if adShowing || gameOverTimer < 0.6 { return }
        if offersContinue() {
            let cx = GameConfig.contentX(viewport.getWorldWidth()) + Float(GameConfig.CONTENT_WIDTH) / 2
            if justTouchedButton(continueOverlay.continueBounds(cx, renderer.resultCenterY())) {
                startRewardedContinue()
            } else if justTouchedButton(continueOverlay.menuBounds(cx, renderer.resultCenterY()))
                        || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
                Ads.onGameFinished()
                goToTitle()
            }
            return
        }
        if tapCatcher.tapCount > 0 || Gdx.input.isKeyJustPressed(Input.Keys.ENTER)
            || Gdx.input.isKeyJustPressed(Input.Keys.SPACE) || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)
            || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
            Ads.onGameFinished()
            goToTitle()
        }
    }

    private func offersContinue() -> Bool {
        return !continueUsed && playerEngine.getState() == .LOST && cpuEngine.getState() == .RUNNING && Ads.canOfferContinue()
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
            self.playerEngine.revive()
            self.gameOverTimer = 0
            self.accumulator = 0
            if self.matchRunning() { GameMusic.playGameTrack(GameMusic.musicType()) }
        })
    }

    private func goToTitle() {
        switchingAway = true
        Gdx.input.setInputProcessor(nil)
        game.setScreen(TitleScreen(game))
        dispose()
    }

    private func isTouchingButton(_ bounds: Rectangle) -> Bool {
        for p in 0..<VsScreen.MAX_POINTERS {
            if !Gdx.input.isTouched(p) { continue }
            let touch = unproject(Gdx.input.getX(p), Gdx.input.getY(p))
            if bounds.contains(touch.x, touch.y) { return true }
        }
        return false
    }

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

    private func handlePauseInput(_ ox: Float) {
        if Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
            paused = false
            return
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.ENTER) {
            goToTitle()
            return
        }
        if justTouchedButton(renderer.pauseOverlayResumeBounds(ox)) {
            paused = false
        } else if justTouchedButton(renderer.pauseOverlayMenuBounds(ox)) {
            goToTitle()
        }
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
        assets.dispose()
    }
}
