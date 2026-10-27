//
//  VirusHuntGame.swift
//  VirusHunt
//
//  com.rummuscan.virushunt.VirusHuntGame (VirusHunt Android sürümünden birebir): "Virüs Avı:
//  Kapsül" oyununun ana sınıfı.
//
//  Ekran akışı: (ilk açılışta AccountSetupScreen, bir kez) -> TitleScreen -> LevelSelectScreen ->
//  SinglePlayerScreen / VsScreen / OnlineLobbyScreen -> OnlineVsScreen. OnlineHub her ekranın
//  üstünde çalışır; GameMusic her ekran değişiminde o ekranın parçasını çalar.
//
//  Pil: iOS'ta çizim saniyede en fazla 60 kare (MTKView.preferredFramesPerSecond); Android'deki
//  FrameLimiter'ın karşılığı.
//

import Foundation

final class VirusHuntGame: Game {
    private let accounts: AccountService?
    private let analyticsDevice: Analytics.Device?
    private var hub: OnlineHub?

    init(_ accounts: AccountService? = nil, _ analyticsDevice: Analytics.Device? = nil) {
        self.accounts = accounts
        self.analyticsDevice = analyticsDevice
    }

    override func create() {
        Lang.set(Lang.detect()) // cihaz dili (bkz. core/i18n)
        Analytics.initialize(analyticsDevice)
        OnlineSession.initialize(accounts)
        ReviewPrompt.onLaunch()
        hub = OnlineHub(self)
        GameMusic.initialize() // setScreen'den önce: ilk ekran müziğiyle açılır
        if AccountPrefs.mode().isEmpty {
            // İlk açılış: hesap burada bir kez seçilir.
            setScreen(AccountSetupScreen(self))
        } else {
            setScreen(TitleScreen(self))
            hub?.autoLogin()
        }
    }

    override func render() {
        let delta = Gdx.graphics.getDeltaTime()
        hub?.update(delta)
        if !(hub?.renderOverlay(delta, { super.render() }) ?? false) { super.render() }
    }

    override func resize(_ width: Int, _ height: Int) {
        super.resize(width, height)
        hub?.resize(width, height)
    }

    override func setScreen(_ newScreen: Screen?) {
        super.setScreen(newScreen)
        GameMusic.onScreen(newScreen) // her ekranın müziği tek yerden seçilir
        if let s = newScreen { Analytics.screen(String(describing: type(of: s))) }
    }

    override func pause() {
        super.pause()
        hub?.onPause()
        Analytics.onPause()
    }

    override func resume() {
        super.resume()
        hub?.onResume()
        Analytics.onResume()
    }

    override func dispose() {
        super.dispose()
        hub?.dispose()
        GameMusic.shutdown()
    }
}
