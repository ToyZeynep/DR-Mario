//
//  OnlineVsScreen.swift
//  DR. Mario
//
//  com.rummuscan.game.OnlineVsScreen (VirusHunt Android sürümünden birebir): VsScreen ile görsel
//  olarak aynı; sağdaki motoru rakibin gerçek olaylarını ağdan alıp yeniden oynatan
//  RemoteEngineDriver yönetir. Kendi motoruma uygulanan her şey (tuşlar + aldığım cezalar) tick
//  numarasıyla MatchSync'e kuyruklanır. Maçın bitişine SUNUCU karar verir.
//

import Foundation

final class OnlineVsScreen: Screen {

    private let game: Game

    private let match: MatchInfo
    private let myEngine: GameEngine
    private let myInput: TouchInputHandler
    private let sync: MatchSync
    private let remoteDriver: RemoteEngineDriver

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
    private var resultReported = false
    private var endHandled = false
    private var resultMusicStopped = false
    private let rivalLabel: String
    private let speed: Speed

    private static let MAX_POINTERS = 8
    private let tapCatcher = TapCatcher(OnlineVsScreen.MAX_POINTERS)

    /// match: sunucudan gelen ORTAK ayarlar (level/speed/seed iki tarafta birebir aynı).
    init(_ game: Game, _ match: MatchInfo) {
        self.game = game
        self.match = match
        ui = NesUi(batch)

        speed = Speed.valueOf(match.speed) ?? .MED
        let virusCount = GameConfig.virusCountForLevel(match.level)
        myEngine = GameEngine(match.seed, virusCount, speed.tickInterval)
        let remoteEngine = GameEngine(match.seed, virusCount, speed.tickInterval)

        myInput = TouchInputHandler(myEngine)

        let client = OnlineClient(OnlineConfig.SERVER_BASE_URL)
        sync = MatchSync(client, match.matchId, match.slot)
        remoteDriver = RemoteEngineDriver(remoteEngine, sync)
        let name = match.opponentName
        rivalLabel = name.jlength > 6 ? name.jprefix(6) : name

        assets = Assets()
        renderer = VsBoardsRenderer(ui, batch, assets)

        viewport = ExtendViewport(GameConfig.CONTENT_WIDTH, GameConfig.WORLD_HEIGHT, camera)

        // TouchInputHandler.ActionListener: motora uygulanan HER hamleyi gönderim kuyruğuna ekler.
        myInput.setActionListener { [unowned self] action in
            self.sync.queue(TimedAction(self.myEngine.getTickCount(), action))
        }
    }

    func show() {
        Gdx.input.setInputProcessor(tapCatcher)
        OnlineHub.get()?.setInMatch(true)
    }

    func render(_ delta: Float) {
        blinkTimer += delta

        let worldW = viewport.getWorldWidth()
        let ox = GameConfig.contentX(worldW)
        controls.layoutVs(ox, worldW)
        renderer.placePauseAboveRotate(controls)

        let remoteEngine = remoteDriver.getEngine()
        var running = matchRunning()
        if running {
            sync.update(delta, myEngine.getTickCount())
            remoteDriver.update(delta)

            if !paused {
                handleInput()
                if switchingAway { return }
                myInput.update(delta)

                accumulator += delta
                while accumulator >= GameConfig.TICK_DT {
                    myEngine.tick()
                    _ = myEngine.drainOutgoingGarbage()
                    accumulator -= GameConfig.TICK_DT
                }
            } else {
                controls.releaseAll()
                handlePauseInput(ox)
                if switchingAway { return }
            }

            let fromRemote = remoteEngine.drainOutgoingGarbage()
            if fromRemote.count > 0 {
                myEngine.receiveGarbage(fromRemote)
                sync.queue(TimedAction.garbage(myEngine.getTickCount(), fromRemote))
            }

            if !resultReported && myEngine.getState() != .RUNNING {
                resultReported = true
                sync.reportResult(myEngine.getState() == .WON ? MatchSync.RESULT_WON : MatchSync.RESULT_LOST)
            }
            running = matchRunning()
        } else {
            gameOverTimer += delta
            controls.releaseAll()
            remoteDriver.update(delta)
            _ = remoteEngine.drainOutgoingGarbage()
            if !endHandled && sync.isEnded() {
                endHandled = true
                let winner = sync.getWinnerSlot()
                GameMusic.playResult(GameMusic.musicType(), winner < 0 ? nil : (winner == match.slot))
                onMatchEnded()
            } else if !endHandled && !resultMusicStopped {
                resultMusicStopped = true
                GameMusic.stop()
            }
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

        renderer.drawSide(ox, true, Txt.YOU.s(), myEngine, running && !paused)
        renderer.drawSide(ox, false, rivalLabel, remoteEngine, running)
        renderer.drawVsLabel(ox)

        if running {
            controls.draw(ui)
            renderer.drawPauseButton(ox)
        }
        if paused && running { renderer.drawPauseOverlay(ox) }
        if sync.isEnded() {
            let winner = sync.getWinnerSlot()
            let iWon = winner == match.slot
            let reason = sync.getEndReason()
            let rivalLeft = iWon && (reason == MatchSync.RESULT_FORFEIT || reason == "TIMEOUT")
            let rp = sync.getRatingDelta()
            var note: String? = rivalLeft ? Txt.RIVAL_LEFT.s() : nil
            if rp != 0 { note = (note != nil ? note! + "  " : "") + (rp > 0 ? "+" : "") + String(rp) + " " + Txt.RP.s() }
            renderer.drawResultOverlay(ox, winner < 0, iWon, blinkTimer, note)
        } else if !running {
            drawConnectionLostOverlay(ox)
        }
        batch.end()
    }

    private func matchRunning() -> Bool {
        return !sync.isEnded() && !sync.isConnectionLost()
    }

    private func drawConnectionLostOverlay(_ ox: Float) {
        let cx = ox + Float(GameConfig.CONTENT_WIDTH) / 2
        let w: Float = 160, h: Float = 48
        let x = cx - w / 2
        let y = Float(GameConfig.WORLD_HEIGHT) / 2 - h / 2

        ui.roundRectBorder(x, y, w, h, 6, 2, NesUi.RED, NesUi.BLACK)
        ui.textCentered(Txt.CONNECTION_LOST.s(), cx, y + h - 18, 1, 2, NesUi.RED)
        if Int(blinkTimer * 2) % 2 == 0 {
            ui.textCentered(Txt.PRESS_START.s(), cx, y + 10, 1, 3, NesUi.WHITE)
        }
    }

    // ---- Girdi (yalnızca kendi tahtam) ----

    private func handleInput() {
        let left = Gdx.input.isKeyPressed(Input.Keys.LEFT) || isTouchingButton(controls.hitArea(TouchControls.LEFT))
        let right = Gdx.input.isKeyPressed(Input.Keys.RIGHT) || isTouchingButton(controls.hitArea(TouchControls.RIGHT))
        let down = Gdx.input.isKeyPressed(Input.Keys.DOWN) || isTouchingButton(controls.hitArea(TouchControls.DOWN))

        myInput.setLeftHeld(left)
        myInput.setRightHeld(right)
        myInput.setDownHeld(down)

        controls.setPressed(TouchControls.LEFT, left)
        controls.setPressed(TouchControls.RIGHT, right)
        controls.setPressed(TouchControls.DOWN, down)
        let rotateHeld = Gdx.input.isKeyPressed(Input.Keys.UP) || isTouchingButton(controls.hitArea(TouchControls.ROTATE))
        controls.setPressed(TouchControls.ROTATE, rotateHeld)

        if Gdx.input.isKeyJustPressed(Input.Keys.UP) || justTouchedButton(controls.hitArea(TouchControls.ROTATE)) {
            myInput.triggerRotateCW()
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.SPACE) {
            myInput.triggerHardDrop()
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK)
            || justTouchedButton(renderer.pauseButtonBounds(GameConfig.contentX(viewport.getWorldWidth()))) {
            paused = true
            controls.releaseAll()
            myInput.setLeftHeld(false)
            myInput.setRightHeld(false)
            myInput.setDownHeld(false)
        }
    }

    private func handleGameOverInput() {
        if gameOverTimer < 0.6 { return }
        if tapCatcher.tapCount > 0 || Gdx.input.isKeyJustPressed(Input.Keys.ENTER)
            || Gdx.input.isKeyJustPressed(Input.Keys.SPACE) || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)
            || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
            goToTitle()
        }
    }

    /// Maç sürerken menüye dönmek = maçı terk etmek; sunucu rakibi hükmen galip sayar.
    private func quitMatch() {
        sync.forfeit()
        goToTitle()
    }

    /// Sunucu sonucu kesinleştirdi (puan/başarımlar - misafir hesapta no-op).
    private func onMatchEnded() {
        guard let me = OnlineSession.me() else { return }
        let accounts = OnlineSession.accounts()
        accounts.submitRating(me.rating)
        let iWon = sync.getWinnerSlot() == match.slot
        if iWon {
            ReviewPrompt.onPositiveMoment()
            if me.wins >= 1 { accounts.unlockAchievement(.FIRST_ONLINE_WIN) }
            if me.wins >= 10 { accounts.unlockAchievement(.ONLINE_WINS_10) }
            if me.wins >= 50 { accounts.unlockAchievement(.ONLINE_WINS_50) }
        }
        let rank = me.rank()
        if rank.ordinal >= Rank.GOLD.ordinal { accounts.unlockAchievement(.REACH_GOLD) }
        if rank.ordinal >= Rank.DIAMOND.ordinal { accounts.unlockAchievement(.REACH_DIAMOND) }
    }

    /// Maç bitince lobiye dönülür (aynı level/speed tercihiyle).
    private func goToTitle() {
        switchingAway = true
        Gdx.input.setInputProcessor(nil)
        game.setScreen(OnlineLobbyScreen(game, match.level, speed))
        dispose()
    }

    private func isTouchingButton(_ bounds: Rectangle) -> Bool {
        for p in 0..<OnlineVsScreen.MAX_POINTERS {
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

    private func handlePauseInput(_ ox: Float) {
        if Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) || Gdx.input.isKeyJustPressed(Input.Keys.BACK) {
            paused = false
            return
        }
        if Gdx.input.isKeyJustPressed(Input.Keys.ENTER) {
            quitMatch()
            return
        }
        if justTouchedButton(renderer.pauseOverlayResumeBounds(ox)) {
            paused = false
        } else if justTouchedButton(renderer.pauseOverlayMenuBounds(ox)) {
            quitMatch()
        }
    }

    func resize(_ width: Int, _ height: Int) { viewport.update(width, height, true) }
    func pause() {}
    func resume() {}

    func hide() {
        if Gdx.input.getInputProcessor() === tapCatcher { Gdx.input.setInputProcessor(nil) }
    }

    func dispose() {
        OnlineHub.get()?.setInMatch(false)
        batch.dispose()
        ui.dispose()
        assets.dispose()
    }
}
