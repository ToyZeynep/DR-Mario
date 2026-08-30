//
//  CellType.swift
//  DR. Mario
//
//  Port of com.rummuscan.core.CellType.
//

import Foundation

enum CellType: Equatable {
    case empty
    case virus         // temizlenmesi gereken hedef (garbage/attack de virüs olarak eklenir)
    case capsuleHalf   // yerleşmiş kapsül yarısı (bağımsız, tek başına renk eşleşmesine girer)
}
