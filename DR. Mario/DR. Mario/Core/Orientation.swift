//
//  Orientation.swift
//  DR. Mario
//
//  Port of com.rummuscan.core.Orientation.
//
//  Kapsülün 4 rotasyon durumu. "Pivot" hücre colorA'nın bulunduğu hücredir;
//  ikinci hücre (colorB) pivot'a göre bu offset kadar kayar.
//
//  Saat yönünde sıra: RIGHT -> DOWN -> LEFT -> UP -> RIGHT. Bu, "köşe etrafında
//  dönüş" modelinin (bkz. GameEngine.rotate) parçasıdır: pivot bazı adımlarda
//  kayabilir, bu enum sadece o anki YÖNÜ (ikinci hücrenin pivot'a göre konumunu)
//  temsil eder.
//

import Foundation

enum Orientation: Int, CaseIterable, Equatable {
    case right // ikinci hücre pivot'un sağında
    case down  // ikinci hücre pivot'un altında
    case left  // ikinci hücre pivot'un solunda
    case up    // ikinci hücre pivot'un üstünde

    var offsetCol: Int {
        switch self {
        case .right: return 1
        case .down: return 0
        case .left: return -1
        case .up: return 0
        }
    }

    var offsetRow: Int {
        switch self {
        case .right: return 0
        case .down: return 1
        case .left: return 0
        case .up: return -1
        }
    }

    /// Saat yönünde bir sonraki durum (RIGHT->DOWN->LEFT->UP->RIGHT).
    func next() -> Orientation {
        let all = Orientation.allCases
        return all[(rawValue + 1) % all.count]
    }

    /// Saat yönünün tersinde bir sonraki durum (RIGHT->UP->LEFT->DOWN->RIGHT).
    func previous() -> Orientation {
        let all = Orientation.allCases
        return all[(rawValue + all.count - 1) % all.count]
    }

    var isHorizontal: Bool {
        self == .right || self == .left
    }

    /// Tam ters yön (180°): RIGHT<->LEFT, UP<->DOWN. Kilitlenmiş kapsül yarılarının
    /// birbirine bakan yönünü kaydetmek için kullanılır (bkz. Board.lockCapsule / Cell.link).
    func opposite() -> Orientation {
        next().next()
    }
}
