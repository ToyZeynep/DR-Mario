//
//  Basics.swift
//  VirusHunt
//
//  com.rummuscan.core: CapsuleColor, CellType, Cell, Orientation, GameState, VsOutcome,
//  InputAction, ScoreRules (VirusHunt Android sürümünden birebir).
//

import Foundation

/// Bir tahta hücresinin konumu (Java'daki int[]{col, row}).
struct Coord: Hashable {
    let col: Int
    let row: Int
    init(_ col: Int, _ row: Int) { self.col = col; self.row = row }
}

/// Oyundaki 3 klasik kapsül/virüs rengi. Ordinal değerleri deterministic RNG hesaplamalarında
/// (seed'den renk üretirken) ve online VS'te ceza paketinin metninde ("3:02") sabit kalmalı,
/// bu yüzden sırasını değiştirme.
enum CapsuleColor: Int, CaseIterable {
    case RED = 0
    case YELLOW = 1
    case BLUE = 2

    var ordinal: Int { return rawValue }

    static func random(_ rng: JavaRandom) -> CapsuleColor {
        return allCases[rng.nextInt(allCases.count)]
    }
}

enum CellType {
    case EMPTY
    case VIRUS          // temizlenmesi gereken hedef
    case CAPSULE_HALF   // yerleşmiş kapsül yarısı (bağımsız, tek başına renk eşleşmesine girer)
}

/// Kapsülün 4 rotasyon durumu. "Pivot" hücre colorA'nın bulunduğu hücredir; ikinci hücre
/// (colorB) pivot'a göre bu offset kadar kayar. Saat yönünde sıra: RIGHT -> DOWN -> LEFT -> UP.
enum Orientation: Int, CaseIterable {
    case RIGHT = 0   // ikinci hücre pivot'un sağında
    case DOWN = 1    // ikinci hücre pivot'un altında
    case LEFT = 2    // ikinci hücre pivot'un solunda
    case UP = 3      // ikinci hücre pivot'un üstünde

    var offsetCol: Int {
        switch self { case .RIGHT: return 1; case .LEFT: return -1; default: return 0 }
    }
    var offsetRow: Int {
        switch self { case .DOWN: return 1; case .UP: return -1; default: return 0 }
    }

    /// Saat yönünde bir sonraki durum (RIGHT->DOWN->LEFT->UP->RIGHT).
    func next() -> Orientation { return Orientation(rawValue: (rawValue + 1) % 4)! }
    /// Saat yönünün tersinde bir sonraki durum (RIGHT->UP->LEFT->DOWN->RIGHT).
    func previous() -> Orientation { return Orientation(rawValue: (rawValue + 3) % 4)! }
    func isHorizontal() -> Bool { return self == .RIGHT || self == .LEFT }
    /// Tam ters yön (180°).
    func opposite() -> Orientation { return next().next() }
}

struct Cell {
    static let EMPTY = Cell(.EMPTY, nil)

    let type: CellType
    let color: CapsuleColor? // type == EMPTY ise nil
    /// type == CAPSULE_HALF ise bu hücreden orijinal eşine (partner) doğru yön; aksi halde nil.
    let link: Orientation?

    init(_ type: CellType, _ color: CapsuleColor?, _ link: Orientation? = nil) {
        self.type = type
        self.color = color
        self.link = link
    }

    func isEmpty() -> Bool { return type == .EMPTY }

    func matchesColor(_ other: Cell) -> Bool {
        return !isEmpty() && !other.isEmpty() && color == other.color
    }

    var debugString: String {
        if isEmpty() { return "." }
        let c = color == .RED ? "R" : color == .YELLOW ? "Y" : "B"
        return type == .VIRUS ? c.lowercased() : c
    }
}

enum GameState {
    case RUNNING
    case WON   // tüm virüsler temizlendi
    case LOST  // spawn alanı bloklandı (board doldu)
}

/// İki motorlu (VS) bir maçın sonucu - CPU VS ve online VS aynı kuralı kullanır.
enum VsOutcome {
    case UNDECIDED
    case LEFT_WINS
    case RIGHT_WINS
    case DRAW

    static func of(_ left: GameState, _ right: GameState) -> VsOutcome {
        let leftWins = left == .WON || right == .LOST
        let rightWins = right == .WON || left == .LOST
        if leftWins && rightWins { return .DRAW }
        if leftWins { return .LEFT_WINS }
        if rightWins { return .RIGHT_WINS }
        return .UNDECIDED
    }

    func isDecided() -> Bool { return self != .UNDECIDED }
}

/// Online VS'te bir oyuncunun motoruna olan biten her şeyin, isimle (network üzerinden
/// taşınabilir) sabit listesi. Sunucuya rawValue (Java'daki name()) olarak gider.
enum InputAction: String, CaseIterable {
    case MOVE_LEFT, MOVE_RIGHT, ROTATE_CW, SOFT_DROP, HARD_DROP, GARBAGE

    func name() -> String { return rawValue }

    /// Tuş hamlelerini motora uygular. GARBAGE için payload gerekir - bkz. TimedAction.applyTo.
    func applyTo(_ engine: GameEngine) {
        switch self {
        case .MOVE_LEFT: engine.moveLeft()
        case .MOVE_RIGHT: engine.moveRight()
        case .ROTATE_CW: engine.rotateCW()
        case .SOFT_DROP: engine.softDrop()
        case .HARD_DROP: engine.hardDrop()
        case .GARBAGE: preconditionFailure("GARBAGE için TimedAction.applyTo kullanın (payload gerekir)")
        }
    }
}

/// Skor kuralı: puanı yalnızca patlayan VİRÜSLER getirir; aynı hamlede patlayan virüsler
/// sırayla 100, 200, 300, 400... puan verir. Tamamen tam sayı aritmetiği (determinizm).
final class ScoreRules {
    static let VIRUS_BASE = 100

    private var virusesThisMove = 0
    private var lastGain = 0

    func beginMove() {
        virusesThisMove = 0
        lastGain = 0
    }

    func award(_ virusesCleared: Int) -> Int {
        var gained = 0
        for _ in 0..<max(0, virusesCleared) {
            virusesThisMove += 1
            gained += ScoreRules.VIRUS_BASE * virusesThisMove
        }
        lastGain = gained
        return gained
    }

    func getVirusesThisMove() -> Int { return virusesThisMove }
    func getLastGain() -> Int { return lastGain }

    static func totalFor(_ n: Int) -> Int { return VIRUS_BASE * n * (n + 1) / 2 }
}
