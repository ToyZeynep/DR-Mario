//
//  GameMode.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.GameMode.
//
//  Giriş ekranındaki oyun modu seçenekleri (NES'teki "1 PLAYER GAME / 2 PLAYER GAME"
//  satırlarının yerini alır).
//
//  ONLINE_VS ve CPU_VS'in oynanış tarafı henüz yok; menü bunları seçilebilir ama
//  "COMING SOON" uyarısıyla gösterir (bkz. TitleScreenView). Oynanış eklendiğinde tek
//  yapılacak şey playable alanını true'ya çekmektir.
//

import Foundation

enum GameMode: CaseIterable {
    case single
    case onlineVs
    case cpuVs

    /// Giriş ekranı menüsünde görünen satır.
    var menuLabel: String {
        switch self {
        case .single: return "SINGLE PLAYER"
        case .onlineVs: return "ONLINE VS"
        case .cpuVs: return "CPU VS"
        }
    }

    /// Ayar ekranının üst başlığı.
    var settingsTitle: String {
        switch self {
        case .single: return "1 PLAYER GAME"
        case .onlineVs: return "ONLINE VS GAME"
        case .cpuVs: return "CPU VS GAME"
        }
    }

    /// Oynanışı hazır mı?
    var playable: Bool {
        self == .single
    }
}
