//
//  CapsuleColor.swift
//  DR. Mario
//
//  Port of com.rummuscan.core.CapsuleColor.
//

import Foundation

/// Dr. Mario'daki 3 klasik renk. Ordinal değerleri deterministic RNG
/// hesaplamalarında (seed'den renk üretirken) sabit kalmalı, bu yüzden
/// sırasını değiştirme.
enum CapsuleColor: Int, CaseIterable, Equatable {
    case red
    case yellow
    case blue

    static func random(_ rng: inout SeededRandom) -> CapsuleColor {
        let values = CapsuleColor.allCases
        return values[rng.nextInt(values.count)]
    }
}
