//
//  SeededRandom.swift
//  DR. Mario
//
//  Swift'in stdlib'inde seed'li, deterministic bir PRNG bulunmuyor (java.util.Random'ın
//  karşılığı yok). GameEngine'in determinism kuralı (aynı seed + aynı input sırası ->
//  aynı board durumu) için burada basit bir splitmix64 tabanlı üreteç tanımlanıyor.
//  java.util.Random ile bit-bit aynı diziyi ÜRETMEZ; önemli olan Swift tarafının
//  KENDİ İÇİNDE deterministic olması (aynı seed -> aynı sonuç), Java ile senkron
//  bir online mod bu portta hedeflenmiyor.
//

import Foundation

struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        // 0 seed splitmix64'ü dejenere edebileceği için sabit bir tuzla karıştırılıyor.
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    private mutating func nextUInt64() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// java.util.Random.nextInt(bound) ile aynı sözleşme: [0, bound) aralığında.
    mutating func nextInt(_ bound: Int) -> Int {
        precondition(bound > 0)
        return Int(nextUInt64() % UInt64(bound))
    }

    /// [0, 1) aralığında double.
    mutating func nextDouble() -> Double {
        let value = nextUInt64() >> 11 // 53 bitlik mantissa
        return Double(value) * (1.0 / Double(1 << 53))
    }
}
