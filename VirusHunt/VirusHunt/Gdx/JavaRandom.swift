//
//  JavaRandom.swift
//  VirusHunt
//
//  java.util.Random'un BİREBİR kopyası (48 bitlik doğrusal eşlik üreteci).
//
//  Neden: online VS'te iki cihaz aynı seed'le aynı virüs/hap dizisini üretmek zorunda (bkz.
//  GameEngine sınıf yorumu). Android oyuncusu java.util.Random kullanıyor; iPhone oyuncusu
//  Swift'in kendi üretecini kullansaydı aynı maçta iki tarafın şişeleri farklı olurdu. Bu sınıf
//  aynı seed için Java ile aynı sayıları üretir.
//

import Foundation

final class JavaRandom {
    private static let multiplier: Int64 = 0x5DEECE66D
    private static let addend: Int64 = 0xB
    private static let mask: Int64 = (1 << 48) - 1

    private var seed: Int64
    private var nextNextGaussian: Double = 0
    private var haveNextNextGaussian = false

    /// Seed verilmezse Java gibi zamandan türetilir (oyunda yalnızca seed'siz kullanılan yerler için).
    convenience init() {
        self.init(Int64(bitPattern: UInt64(DispatchTime.now().uptimeNanoseconds) ^ 0x5DEECE66D_1234))
    }

    init(_ seed: Int64) {
        self.seed = (seed ^ JavaRandom.multiplier) & JavaRandom.mask
    }

    func setSeed(_ seed: Int64) {
        self.seed = (seed ^ JavaRandom.multiplier) & JavaRandom.mask
        haveNextNextGaussian = false
    }

    private func next(_ bits: Int) -> Int32 {
        seed = (seed &* JavaRandom.multiplier &+ JavaRandom.addend) & JavaRandom.mask
        // Java: (int)(seed >>> (48 - bits))
        return Int32(truncatingIfNeeded: Int64(bitPattern: UInt64(bitPattern: seed) >> UInt64(48 - bits)))
    }

    func nextInt() -> Int32 { return next(32) }

    /// Java Random.nextInt(bound)
    func nextInt(_ bound: Int) -> Int {
        precondition(bound > 0, "bound must be positive")
        let b = Int32(bound)
        var r = next(31)
        let m = b &- 1
        if (b & m) == 0 { // ikinin kuvveti
            r = Int32(truncatingIfNeeded: (Int64(b) &* Int64(r)) >> 31)
        } else {
            var u = r
            r = u % b
            while u &- r &+ m < 0 {
                u = next(31)
                r = u % b
            }
        }
        return Int(r)
    }

    func nextLong() -> Int64 {
        return (Int64(next(32)) << 32) &+ Int64(next(32))
    }

    func nextBoolean() -> Bool { return next(1) != 0 }

    func nextFloat() -> Float { return Float(next(24)) / Float(1 << 24) }

    func nextDouble() -> Double {
        let hi = Int64(next(26)) << 27
        let lo = Int64(next(27))
        return Double(hi + lo) * 0x1.0p-53
    }
}
