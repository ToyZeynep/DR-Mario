//
//  Difficulty.swift
//  DR. Mario
//
//  Port of com.rummuscan.core.ai.Difficulty.
//
//  Zorluk arttıkça CPU daha hızlı karar verir (reactionDelayTicks düşer),
//  hamlelerini daha hızlı uygular (actionSpacingTicks düşer) ve daha az
//  hata yapar (mistakeProbability düşer).
//

import Foundation

enum Difficulty {
    case easy
    case medium
    case hard

    /// Yeni kapsül spawn olduktan sonra ilk hamleyi uygulamadan önceki "düşünme" gecikmesi (tick).
    var reactionDelayTicks: Int {
        switch self {
        case .easy: return 15
        case .medium: return 8
        case .hard: return 3
        }
    }

    /// Planlanan hamleler arasındaki bekleme (tick) — çok hızlı/insan-dışı hareket olmasın diye.
    var actionSpacingTicks: Int {
        switch self {
        case .easy: return 6
        case .medium: return 3
        case .hard: return 1
        }
    }

    /// En iyi hamle yerine bilerek 2./3./4. en iyi hamlenin seçilme olasılığı (0-1).
    var mistakeProbability: Double {
        switch self {
        case .easy: return 0.35
        case .medium: return 0.15
        case .hard: return 0.03
        }
    }
}
