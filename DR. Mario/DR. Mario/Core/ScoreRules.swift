//
//  ScoreRules.swift
//  DR. Mario
//
//  Port of com.rummuscan.core.ScoreRules.
//
//  Skor kuralları.
//
//  Kural: puanı yalnızca patlayan VİRÜSLER getirir. Aynı hamlede patlayan virüsler
//  sırayla artan puan verir - birincisi 100, ikincisi 200, üçüncüsü 300, dördüncüsü
//  400... Patlamada hiç virüs yoksa (sadece hap yarımları temizlendiyse) puan yoktur.
//
//  Tek hamlede n virüs patlarsa toplam 100 * n * (n+1) / 2 eder:
//    1 virüs -> 100      3 virüs -> 600
//    2 virüs -> 300      4 virüs -> 1000
//
//  "Hamle" ne demek? Sayaç beginMove() çağrılana kadar artmaya devam eder.
//  GameEngine bu çağrıyı kapsül KİLİTLENDİĞİNDE yapar; yani bir hapın tetiklediği
//  zincirin (cascade) tamamı tek hamle sayılır.
//
//  DETERMİNİZM: Sınıf tamamen tam sayı aritmetiği kullanır, rastgelelik veya zaman
//  içermez; online vs modundaki determinizm kuralını bozmaz.
//

import Foundation

struct ScoreRules {
    /// Bir hamledeki ilk virüsün puanı; sonrakiler bunun katları olarak artar.
    static let virusBase = 100

    private(set) var virusesThisMove = 0
    private(set) var lastGain = 0

    /// Yeni hamle: artan puan sayacı sıfırlanır.
    mutating func beginMove() {
        virusesThisMove = 0
        lastGain = 0
    }

    /// Bir temizleme adımında patlayan virüs sayısını puana çevirir.
    /// - Parameter virusesCleared: o adımda yok edilen virüs sayısı (hap yarımları sayılmaz)
    /// - Returns: kazanılan puan; virusesCleared 0 ise 0
    @discardableResult
    mutating func award(_ virusesCleared: Int) -> Int {
        var gained = 0
        for _ in 0..<virusesCleared {
            virusesThisMove += 1
            gained += ScoreRules.virusBase * virusesThisMove
        }
        lastGain = gained
        return gained
    }

    /// Tek hamlede n virüs patlarsa kazanılacak toplam puan (test / önizleme için).
    static func totalFor(_ n: Int) -> Int {
        virusBase * n * (n + 1) / 2
    }
}
