//
//  ScoreStore.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.ScoreStore.
//  Cihaza kalıcı olarak kaydedilen en yüksek skor (TOP). libGDX'in Preferences'ı
//  yerine UserDefaults kullanılıyor.
//

import Foundation

enum ScoreStore {
    private static let key = "drmario.topScore"

    static func getTopScore() -> Int {
        UserDefaults.standard.integer(forKey: key)
    }

    /// Verilen skor mevcut rekoru geçiyorsa kaydeder ve yeni rekoru döner.
    @discardableResult
    static func reportScore(_ score: Int) -> Int {
        var top = UserDefaults.standard.integer(forKey: key)
        if score > top {
            top = score
            UserDefaults.standard.set(top, forKey: key)
        }
        return top
    }
}
