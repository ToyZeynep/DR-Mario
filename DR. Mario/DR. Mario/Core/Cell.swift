//
//  Cell.swift
//  DR. Mario
//
//  Port of com.rummuscan.core.Cell.
//

import Foundation

struct Cell {
    static let empty = Cell(type: .empty, color: nil, link: nil)

    let type: CellType
    let color: CapsuleColor? // type == .empty ise nil
    /// type == .capsuleHalf ise bu hücreden orijinal eşine (partner) doğru yön; aksi halde nil.
    /// Renderer bunu kapsülün hangi ucunun yuvarlak (dışa bakan), hangi ucunun düz (eşe bakan)
    /// çizileceğine karar vermek için kullanır (bkz. BoardRenderer).
    let link: Orientation?

    init(type: CellType, color: CapsuleColor?, link: Orientation? = nil) {
        self.type = type
        self.color = color
        self.link = link
    }

    var isEmpty: Bool { type == .empty }

    func matchesColor(_ other: Cell) -> Bool {
        !isEmpty && !other.isEmpty && color == other.color
    }
}
