//
//  DebugShots.swift
//  VirusHunt
//
//  YALNIZCA GELİŞTİRME DERLEMESİ: simülatörde ekran görüntüsü için doğrudan bir ekranla açılış
//  (Android'deki lwjgl3 ShotDirector'ın küçük karşılığı). Ağ kapalıdır, sunucuya hiçbir şey gitmez.
//
//    xcrun simctl launch booted com.zeynep.virushunt -vhShot single
//
//  Ekranlar: setup, title, level, cpu-level, single, cpu, settings, help, lobby
//

#if DEBUG
import Foundation

enum DebugShots {
    static func requested() -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-vhShot"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// Oyun oluşturulmadan önce: ağı kapat, gerekiyorsa hesap tercihini ayarla.
    static func prepare(_ shot: String) {
        Gdx.net.interceptor = { _ in nil }
        if shot == "setup" { AccountPrefs.reset() } else { AccountPrefs.setMode(AccountPrefs.MODE_GUEST) }
    }

    /// create() sonrası: istenen ekrana geç.
    static func apply(_ shot: String, _ game: Game) {
        switch shot {
        case "level": game.setScreen(LevelSelectScreen(game, .SINGLE))
        case "cpu-level": game.setScreen(LevelSelectScreen(game, .CPU_VS))
        case "single": game.setScreen(SinglePlayerScreen(game, .SINGLE, 8, .MED, .FEVER))
        case "cpu": game.setScreen(VsScreen(game, 6, .MED, .HARD))
        case "settings": game.setScreen(SettingsScreen(game))
        case "help": game.setScreen(HelpScreen(game))
        case "lobby": game.setScreen(OnlineLobbyScreen(game, 5, .MED))
        default: break
        }
    }
}
#endif
