//
//  Speed.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.Speed.
//
//  Düşme hızı kademeleri. Etiketler NES'teki gibi LOW / MED / HI'dır ve hem ayar
//  ekranında hem oyun içi panelde aynı metin kullanılır.
//

import Foundation

enum Speed: CaseIterable {
    case low
    case med
    case hi

    var label: String {
        switch self {
        case .low: return "LOW"
        case .med: return "MED"
        case .hi: return "HI"
        }
    }

    /// Yerçekimi tick aralığı: küçüldükçe hap daha hızlı düşer.
    var tickInterval: Int {
        switch self {
        case .low: return GameConfig.speedLow
        case .med: return GameConfig.speedMedium
        case .hi: return GameConfig.speedHigh
        }
    }
}
