//
//  GameState.swift
//  DR. Mario
//
//  Port of com.rummuscan.core.GameState.
//

import Foundation

enum GameState: Equatable {
    case running
    case won   // tüm virüsler temizlendi
    case lost  // spawn alanı bloklandı (board doldu)
}
