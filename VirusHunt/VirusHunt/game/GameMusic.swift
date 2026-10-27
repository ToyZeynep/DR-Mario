//
//  GameMusic.swift
//  VirusHunt
//
//  com.rummuscan.game.GameMusic (VirusHunt Android sürümünden birebir): hangi ekranda hangi
//  parçanın çalacağını bilir ve aynı anda tek parça çalar. Parçalar Android'deki özgün 8-bit
//  ezgiler (assets/music/*.ogg -> iOS'ta GameAssets/music/*.m4a).
//

import Foundation

final class GameMusic {

    enum Track {
        case TITLE, MENU, FEVER, CHILL, CLEAR, GAME_OVER

        var path: String {
            switch self {
            case .TITLE: return "music/title.ogg"
            case .MENU: return "music/menu.ogg"
            case .FEVER: return "music/fever.ogg"
            case .CHILL: return "music/chill.ogg"
            case .CLEAR: return "music/clear.ogg"
            case .GAME_OVER: return "music/gameover.ogg"
            }
        }

        var looping: Bool { return self != .GAME_OVER }
    }

    private static let PREFS_NAME = "virushunt-settings"
    private static let KEY_MUSIC_TYPE = "musicType"
    private static let KEY_MUSIC_ON = "musicOn"
    private static let VOLUME: Float = 0.6

    typealias Opener = (Track) -> Music?

    private static var instance: GameMusic?

    private let opener: Opener
    private var music: Music?
    private var current: Track?
    private var paused = false
    private var enabled: Bool
    private var wanted: Track?

    private init(_ opener: @escaping Opener, _ enabled: Bool) {
        self.opener = opener
        self.enabled = enabled
    }

    // ---- Yaşam döngüsü ----

    static func initialize() { initialize(openAsset) }

    static func initialize(_ opener: @escaping Opener) {
        shutdown()
        instance = GameMusic(opener, loadEnabled())
    }

    static func shutdown() {
        instance?.release()
        instance = nil
    }

    // ---- Ekranların kullandığı çağrılar ----

    static func onScreen(_ screen: Screen?) {
        guard instance != nil, let screen = screen else { return }
        let type = (screen as? SinglePlayerScreen)?.getMusic() ?? musicType()
        enterScreen(Swift.type(of: screen), type)
    }

    static func enterScreen(_ screenClass: AnyObject.Type, _ type: MusicType?) {
        setPaused(false)
        play(trackFor(screenClass, type))
    }

    static func play(_ track: Track?) {
        instance?.switchTo(track)
    }

    static func playGameTrack(_ type: MusicType?) {
        play(gameTrack(type))
    }

    /// won == nil: beraberlik.
    static func playResult(_ type: MusicType?, _ won: Bool?) {
        play(resultTrack(type, won))
    }

    static func stop() { play(nil) }

    static func setPaused(_ value: Bool) {
        instance?.pause(value)
    }

    // ---- Kurallar ----

    private static func same(_ a: AnyObject.Type, _ b: AnyObject.Type) -> Bool {
        return ObjectIdentifier(a) == ObjectIdentifier(b)
    }

    static func trackFor(_ screenClass: AnyObject.Type, _ type: MusicType?) -> Track? {
        if same(screenClass, TitleScreen.self) || same(screenClass, AccountSetupScreen.self) { return .TITLE }
        if isGameScreen(screenClass) || same(screenClass, LevelSelectScreen.self) { return gameTrack(type) }
        return .MENU
    }

    static func isGameScreen(_ screenClass: AnyObject.Type) -> Bool {
        return same(screenClass, SinglePlayerScreen.self) || same(screenClass, VsScreen.self) || same(screenClass, OnlineVsScreen.self)
    }

    static func gameTrack(_ type: MusicType?) -> Track? {
        if type == .FEVER { return .FEVER }
        if type == .CHILL { return .CHILL }
        return nil
    }

    static func resultTrack(_ type: MusicType?, _ won: Bool?) -> Track? {
        guard gameTrack(type) != nil, let won = won else { return nil }
        return won ? .CLEAR : .GAME_OVER
    }

    static func parseType(_ name: String?) -> MusicType {
        if let n = name, let t = MusicType.valueOf(n) { return t }
        return .FEVER
    }

    // ---- Saklanan seçim ----

    static func musicType() -> MusicType {
        return parseType(Gdx.app.getPreferences(PREFS_NAME).getString(KEY_MUSIC_TYPE))
    }

    static func setMusicType(_ type: MusicType?) {
        guard let type = type else { return }
        let p = Gdx.app.getPreferences(PREFS_NAME)
        p.putString(KEY_MUSIC_TYPE, type.name())
        p.flush()
    }

    static func isEnabled() -> Bool {
        return instance?.enabled ?? loadEnabled()
    }

    static func setEnabled(_ on: Bool) {
        let p = Gdx.app.getPreferences(PREFS_NAME)
        p.putBoolean(KEY_MUSIC_ON, on)
        p.flush()
        instance?.applyEnabled(on)
    }

    private static func loadEnabled() -> Bool {
        return Gdx.app.getPreferences(PREFS_NAME).getBoolean(KEY_MUSIC_ON, true)
    }

    // ---- Çalma ----

    private func switchTo(_ track: Track?) {
        wanted = track
        if !enabled {
            release()
            return
        }
        if let t = track, t == current, let m = music, paused || m.isPlaying() {
            return // aynı parça zaten çalıyor (ya da duraklatılmış bekliyor)
        }
        release()
        guard let track = track else { return }
        current = track
        music = opener(track)
        guard let m = music else { return }
        m.setLooping(track.looping)
        m.setVolume(GameMusic.VOLUME)
        m.play()
    }

    private func applyEnabled(_ on: Bool) {
        if enabled == on { return }
        enabled = on
        let resume: Track? = (wanted != nil && wanted!.looping) ? wanted : nil
        switchTo(on ? resume : nil)
        wanted = resume
    }

    private func pause(_ value: Bool) {
        if paused == value { return }
        paused = value
        guard let m = music else { return }
        if value { m.pause() } else { m.play() }
    }

    private static func openAsset(_ track: Track) -> Music? {
        let file = Gdx.files.internal(track.path)
        if !file.exists() {
            log(track.path + " bulunamadı")
            return nil
        }
        do {
            return try Gdx.audio.newMusic(file)
        } catch {
            log(track.path + " açılamadı: \(error)")
            return nil
        }
    }

    private func release() {
        let old = music
        music = nil
        current = nil
        paused = false
        old?.dispose()
    }

    private static func log(_ message: String) {
        Gdx.app.error("GameMusic", message)
    }
}
