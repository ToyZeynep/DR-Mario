//
//  GdxMath.swift
//  VirusHunt
//
//  libGDX'in oyunda kullanılan küçük matematik tipleri (Color, Rectangle, Vector3, Matrix4).
//  Oyun kodu HasanDagasan/VirusHunt (Android, libGDX) reposundan satır satır çevrildiği için
//  aynı adlar ve aynı davranış korunur: Java tarafında bir değişiklik olunca Swift'e taşımak
//  kolay olsun.
//

import Foundation

/// libGDX Color: 0..1 aralığında RGBA. Java'daki gibi değiştirilebilir (struct, mutating).
struct Color: Equatable {
    var r: Float
    var g: Float
    var b: Float
    var a: Float

    static let WHITE = Color(1, 1, 1, 1)
    static let BLACK = Color(0, 0, 0, 1)
    static let CLEAR = Color(0, 0, 0, 0)

    init() { r = 0; g = 0; b = 0; a = 0 }

    init(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// new Color(0xRRGGBBAA)
    init(_ rgba8888: UInt32) {
        r = Float((rgba8888 >> 24) & 0xff) / 255
        g = Float((rgba8888 >> 16) & 0xff) / 255
        b = Float((rgba8888 >> 8) & 0xff) / 255
        a = Float(rgba8888 & 0xff) / 255
    }

    mutating func set(_ other: Color) { self = other }

    /// libGDX Color.lerp: her bileşen hedefe t oranında yaklaşır (sonuç 0..1'e kırpılır).
    mutating func lerp(_ target: Color, _ t: Float) {
        r += t * (target.r - r)
        g += t * (target.g - g)
        b += t * (target.b - b)
        a += t * (target.a - a)
        clamp()
    }

    mutating func clamp() {
        r = min(1, max(0, r)); g = min(1, max(0, g)); b = min(1, max(0, b)); a = min(1, max(0, a))
    }
}

/// libGDX Rectangle: sol-alt köşe + boyut. contains() kenarlar dâhil.
struct Rectangle {
    var x: Float = 0
    var y: Float = 0
    var width: Float = 0
    var height: Float = 0

    init() {}

    init(_ x: Float, _ y: Float, _ width: Float, _ height: Float) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    mutating func set(_ x: Float, _ y: Float, _ width: Float, _ height: Float) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    func contains(_ px: Float, _ py: Float) -> Bool {
        return x <= px && x + width >= px && y <= py && y + height >= py
    }
}

struct Vector3 {
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0

    init() {}

    init(_ x: Float, _ y: Float, _ z: Float) {
        self.x = x; self.y = y; self.z = z
    }

    mutating func set(_ x: Float, _ y: Float, _ z: Float) {
        self.x = x; self.y = y; self.z = z
    }
}

/// Yalnızca 2B ortografik izdüşüm: dünya (x0..x1, y0..y1) -> NDC (-1..1). Sütun-öncelikli 4x4.
struct Matrix4 {
    var m: [Float] = [1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1]

    init() {}

    @discardableResult
    mutating func setToOrtho2D(_ x: Float, _ y: Float, _ width: Float, _ height: Float) -> Matrix4 {
        setToOrtho(x, x + width, y, y + height)
        return self
    }

    /// Kısa yol: new Matrix4().setToOrtho2D(...)
    static func ortho2D(_ x: Float, _ y: Float, _ width: Float, _ height: Float) -> Matrix4 {
        var mat = Matrix4()
        mat.setToOrtho2D(x, y, width, height)
        return mat
    }

    mutating func setToOrtho(_ left: Float, _ right: Float, _ bottom: Float, _ top: Float) {
        let sx = 2 / (right - left)
        let sy = 2 / (top - bottom)
        let tx = -(right + left) / (right - left)
        let ty = -(top + bottom) / (top - bottom)
        m = [sx, 0, 0, 0,
             0, sy, 0, 0,
             0, 0, 1, 0,
             tx, ty, 0, 1]
    }
}

// ---- Java Math yardımcıları (float) ----

/// Math.round(float): en yakın tam sayı, .5 yukarı.
@inline(__always) func javaRound(_ v: Float) -> Int { return Int((v + 0.5).rounded(.down)) }
/// Math.floorMod(int, int)
@inline(__always) func floorMod(_ a: Int, _ b: Int) -> Int { let r = a % b; return r < 0 ? r + b : r }
@inline(__always) func toRadians(_ deg: Float) -> Float { return deg * Float.pi / 180 }
/// System.currentTimeMillis()
@inline(__always) func currentTimeMillis() -> Int64 { return Int64(Date().timeIntervalSince1970 * 1000) }

/// Java'daki String.length()/charAt(): UTF-16 birimleri. Oyunun bütün metinleri BMP içinde
/// (tek UTF-16 birimi = tek karakter), bu yüzden glyph aramaları bu birimlerle yapılır.
extension String {
    var jlength: Int { return utf16.count }
    /// Java'daki substring(0, n) (UTF-16 birimiyle).
    func jprefix(_ n: Int) -> String {
        let units = Array(utf16.prefix(n))
        return String(decoding: units, as: UTF16.self)
    }
    func jsubstring(_ from: Int, _ to: Int) -> String {
        let units = Array(utf16)
        let a = max(0, min(from, units.count)), b = max(a, min(to, units.count))
        return String(decoding: units[a..<b], as: UTF16.self)
    }
    func jsubstring(_ from: Int) -> String { return jsubstring(from, jlength) }
    /// Java String.trim(): baştaki/sondaki <= ' ' karakterler.
    func jtrim() -> String {
        var units = Array(utf16)
        while let f = units.first, f <= 0x20 { units.removeFirst() }
        while let l = units.last, l <= 0x20 { units.removeLast() }
        return String(decoding: units, as: UTF16.self)
    }
    /// Java String.hashCode()
    var javaHashCode: Int32 {
        var h: Int32 = 0
        for u in utf16 { h = h &* 31 &+ Int32(u) }
        return h
    }
}

/// Character.toUpperCase(char) karşılığı: tek UTF-16 birimlik büyük hâl yoksa olduğu gibi.
func javaToUpper(_ c: UInt16) -> UInt16 {
    guard let scalar = Unicode.Scalar(c) else { return c }
    let up = String(Character(scalar)).uppercased()
    let units = Array(up.utf16)
    return units.count == 1 ? units[0] : c
}
