//
//  Capsule.swift
//  DR. Mario
//
//  Port of com.rummuscan.core.Capsule.
//
//  Pivot hücre (pivotCol, pivotRow) her zaman kapsülün "ana" yarısıdır (colorA).
//  İkinci hücre (colorB), orientation'ın offset'i kadar kaymış konumdadır.
//  Bu sayede 4 rotasyon durumu (0/90/180/270) desteklenir.
//

import Foundation

final class Capsule {
    private(set) var pivotCol: Int
    private(set) var pivotRow: Int
    private(set) var orientation: Orientation
    let colorA: CapsuleColor // pivot rengi
    let colorB: CapsuleColor // ikinci hücre rengi

    init(pivotCol: Int, pivotRow: Int, orientation: Orientation = .right, colorA: CapsuleColor, colorB: CapsuleColor) {
        self.pivotCol = pivotCol
        self.pivotRow = pivotRow
        self.orientation = orientation
        self.colorA = colorA
        self.colorB = colorB
    }

    var cellA: (col: Int, row: Int) { (pivotCol, pivotRow) }

    var cellB: (col: Int, row: Int) {
        (pivotCol + orientation.offsetCol, pivotRow + orientation.offsetRow)
    }

    /// Board'a bakmadan pozisyonu günceller; geçerlilik kontrolü GameEngine'de yapılır.
    func setPosition(col: Int, row: Int) {
        pivotCol = col
        pivotRow = row
    }

    func setOrientation(_ o: Orientation) {
        orientation = o
    }

    /// Hem pivot hem ikinci hücrenin board sınırları içinde ve boş olup olmadığını kontrol eder.
    func fitsAt(_ board: Board, col: Int, row: Int, orientation o: Orientation) -> Bool {
        isFree(board, col, row) && isFree(board, col + o.offsetCol, row + o.offsetRow)
    }

    private func isFree(_ board: Board, _ col: Int, _ row: Int) -> Bool {
        board.isInBounds(col: col, row: row) && board.isEmpty(col: col, row: row)
    }
}
