//
//  Coord.swift
//  DR. Mario
//
//  Java tarafında hücre koordinatları int[]{col, row} olarak taşınıyor ve eşitlik/hash
//  için elle üretilmiş bir anahtar (row * 1000 + col) kullanılıyordu. Swift'te bunun
//  karşılığı doğrudan Hashable bir struct: Set<Coord> / [Coord: ...] için ekstra bir
//  anahtar fonksiyonuna gerek kalmıyor.
//

import Foundation

struct Coord: Hashable {
    let col: Int
    let row: Int
}
