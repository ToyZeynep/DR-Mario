//
//  Board.swift
//  DR. Mario
//
//  com.rummuscan.core.Board ve Capsule (VirusHunt Android sürümünden birebir).
//  Oyun tahtası (ilaç şişesi). row=0 en üst satır, row=(height-1) en alt satır.
//

import Foundation

final class Board {
    static let DEFAULT_WIDTH = 8
    /// Şişenin düz gövdesi 16 satırdır; onun üstündeki SHOULDER_ROWS satır şişe görselinin OMUZ
    /// bölgesine denk gelir. Oyun ancak bu en üst satıra ulaşılınca biter.
    static let SHOULDER_ROWS = 1
    static let BODY_ROWS = 16
    static let DEFAULT_HEIGHT = BODY_ROWS + SHOULDER_ROWS
    private static let MIN_MATCH_LENGTH = 4

    /// Ceza parçaları arasındaki sütun mesafesi (bkz. insertGarbage).
    static let GARBAGE_SPACING = 3

    private let width: Int
    private let height: Int
    private var grid: [[Cell]] // grid[row][col]
    private var virusCount = 0

    convenience init() {
        self.init(Board.DEFAULT_WIDTH, Board.DEFAULT_HEIGHT)
    }

    init(_ width: Int, _ height: Int) {
        self.width = width
        self.height = height
        grid = [[Cell]](repeating: [Cell](repeating: Cell.EMPTY, count: width), count: height)
    }

    func getWidth() -> Int { return width }
    func getHeight() -> Int { return height }
    func getVirusCount() -> Int { return virusCount }

    /// Tahtada bu renkten en az bir virüs kaldı mı? (mikroskop paneli)
    func hasVirusOfColor(_ color: CapsuleColor) -> Bool {
        for r in 0..<height {
            for c in 0..<width {
                let cell = grid[r][c]
                if cell.type == .VIRUS && cell.color == color { return true }
            }
        }
        return false
    }

    func isInBounds(_ col: Int, _ row: Int) -> Bool {
        return col >= 0 && col < width && row >= 0 && row < height
    }

    func getCell(_ col: Int, _ row: Int) -> Cell {
        return grid[row][col]
    }

    func isEmpty(_ col: Int, _ row: Int) -> Bool {
        return isInBounds(col, row) && grid[row][col].isEmpty()
    }

    func setCell(_ col: Int, _ row: Int, _ cell: Cell) {
        let previous = grid[row][col]
        if previous.type == .VIRUS { virusCount -= 1 }
        grid[row][col] = cell
        if cell.type == .VIRUS { virusCount += 1 }
    }

    /// Tahtayı seed'li rng ile virüslerle doldurur; üst keepTopRowsClear satır boş kalır.
    func fillWithViruses(_ virusTarget: Int, _ rng: JavaRandom, _ keepTopRowsClear: Int) {
        var placed = 0
        var attempts = 0
        let maxAttempts = virusTarget * 200
        while placed < virusTarget && attempts < maxAttempts {
            attempts += 1
            let row = keepTopRowsClear + rng.nextInt(height - keepTopRowsClear)
            let col = rng.nextInt(width)
            if !isEmpty(col, row) { continue }
            let color = CapsuleColor.random(rng)
            // Aynı renkten yatayda/dikeyde 3'lü oluşmasını engelle
            if wouldCreateInitialMatch(col, row, color) { continue }
            setCell(col, row, Cell(.VIRUS, color))
            placed += 1
        }
    }

    private func wouldCreateInitialMatch(_ col: Int, _ row: Int, _ color: CapsuleColor) -> Bool {
        var horizontal = 1
        var c = col - 1
        while c >= 0 && sameColor(c, row, color) { horizontal += 1; c -= 1 }
        c = col + 1
        while c < width && sameColor(c, row, color) { horizontal += 1; c += 1 }
        if horizontal >= 3 { return true }

        var vertical = 1
        var r = row - 1
        while r >= 0 && sameColor(col, r, color) { vertical += 1; r -= 1 }
        r = row + 1
        while r < height && sameColor(col, r, color) { vertical += 1; r += 1 }
        return vertical >= 3
    }

    private func sameColor(_ col: Int, _ row: Int, _ color: CapsuleColor) -> Bool {
        return isInBounds(col, row) && !grid[row][col].isEmpty() && grid[row][col].color == color
    }

    /// Kapsülün her iki hücresini de yerleştirir.
    func lockCapsule(_ capsule: Capsule) {
        let c1 = capsule.getCellA()
        let c2 = capsule.getCellB()
        let aToB = capsule.getOrientation()
        setCell(c1.col, c1.row, Cell(.CAPSULE_HALF, capsule.getColorA(), aToB))
        setCell(c2.col, c2.row, Cell(.CAPSULE_HALF, capsule.getColorB(), aToB.opposite()))
    }

    /// Yatayda/dikeyde 4+ aynı renk bloğu bulur; bitişik + aynı renkli hücreler tek grupta.
    func findMatchGroups() -> [[Coord]] {
        var matched = Set<Coord>()
        var order: [Coord] = []

        func addMatch(_ col: Int, _ row: Int) {
            let k = Coord(col, row)
            if matched.insert(k).inserted { order.append(k) }
        }

        // Yatay taramalar
        for row in 0..<height {
            var runStart = 0
            for col in 1...width {
                let sameAsRunStart = col < width && grid[row][col].matchesColor(grid[row][runStart])
                if !sameAsRunStart {
                    let runLength = col - runStart
                    if runLength >= Board.MIN_MATCH_LENGTH {
                        for k in runStart..<col { addMatch(k, row) }
                    }
                    runStart = col
                }
            }
        }

        // Dikey taramalar
        for col in 0..<width {
            var runStart = 0
            for row in 1...height {
                let sameAsRunStart = row < height && grid[row][col].matchesColor(grid[runStart][col])
                if !sameAsRunStart {
                    let runLength = row - runStart
                    if runLength >= Board.MIN_MATCH_LENGTH {
                        for k in runStart..<row { addMatch(col, k) }
                    }
                    runStart = row
                }
            }
        }

        return groupByAdjacency(order, matched)
    }

    /// O anda tahtada bulunan EŞLEŞME SIRALARININ sayısı (yatay ve dikey ayrı ayrı). Saldırı
    /// hesabı "kaç yeme oldu"yu böyle sayar; findMatchGroups ise SİLME için kümeler.
    func countMatchRuns() -> Int {
        var runs = 0
        for row in 0..<height {
            var runStart = 0
            for col in 1...width {
                let same = col < width && grid[row][col].matchesColor(grid[row][runStart])
                if !same {
                    if col - runStart >= Board.MIN_MATCH_LENGTH { runs += 1 }
                    runStart = col
                }
            }
        }
        for col in 0..<width {
            var runStart = 0
            for row in 1...height {
                let same = row < height && grid[row][col].matchesColor(grid[runStart][col])
                if !same {
                    if row - runStart >= Board.MIN_MATCH_LENGTH { runs += 1 }
                    runStart = row
                }
            }
        }
        return runs
    }

    /// Eşleşen hücreleri, birbirine komşu VE AYNI RENKTE olanlar aynı grupta olacak şekilde ayırır (BFS).
    private func groupByAdjacency(_ order: [Coord], _ matched: Set<Coord>) -> [[Coord]] {
        var groups: [[Coord]] = []
        var visited = Set<Coord>()

        for start in order {
            if visited.contains(start) { continue }
            var group: [Coord] = []
            var queue: [Coord] = [start]
            var head = 0
            visited.insert(start)

            while head < queue.count {
                let cell = queue[head]; head += 1
                group.append(cell)
                let color = grid[cell.row][cell.col].color
                let neighbors = [Coord(cell.col - 1, cell.row), Coord(cell.col + 1, cell.row),
                                 Coord(cell.col, cell.row - 1), Coord(cell.col, cell.row + 1)]
                for n in neighbors {
                    if !matched.contains(n) || visited.contains(n) { continue }
                    if grid[n.row][n.col].color != color { continue }
                    visited.insert(n)
                    queue.append(n)
                }
            }
            groups.append(group)
        }
        return groups
    }

    /// Verilen grupların tümündeki hücreleri boşaltır; temizlenen hücre sayısını döndürür.
    @discardableResult
    func clearGroups(_ groups: [[Coord]]) -> Int {
        var count = 0
        for group in groups {
            for cell in group {
                setCell(cell.col, cell.row, Cell.EMPTY)
                count += 1
            }
        }
        return count
    }

    /// Tek bir gravity ADIMI: havada kalan her kapsül yarısı 1 satır aşağı iner. Virüsler ASLA
    /// düşmez. Hâlâ eşiyle bağlı iki yarı tek parça gibi davranır.
    @discardableResult
    func applyGravityStep() -> Bool {
        var moved = false
        var row = height - 2
        while row >= 0 {
            for col in 0..<width {
                let cell = grid[row][col]
                if cell.type != .CAPSULE_HALF { continue }

                let partner = partnerOf(col, row, cell) // nil -> tekil yarı
                if !canGroupFall(col, row, partner) { continue }

                let partnerCell = partner.map { grid[$0.row][$0.col] }
                setCell(col, row, Cell.EMPTY)
                if let p = partner { setCell(p.col, p.row, Cell.EMPTY) }
                setCell(col, row + 1, cell)
                if let p = partner, let pc = partnerCell { setCell(p.col, p.row + 1, pc) }
                moved = true
            }
            row -= 1
        }
        return moved
    }

    /// Bu yarının hâlâ bağlı olduğu eşi (karşılıklı link şartıyla); yoksa nil.
    private func partnerOf(_ col: Int, _ row: Int, _ cell: Cell) -> Coord? {
        guard let link = cell.link else { return nil }
        let pc = col + link.offsetCol
        let pr = row + link.offsetRow
        if !isInBounds(pc, pr) { return nil }
        let partner = grid[pr][pc]
        if partner.type != .CAPSULE_HALF { return nil }
        if partner.link != link.opposite() { return nil }
        return Coord(pc, pr)
    }

    private func canGroupFall(_ col: Int, _ row: Int, _ partner: Coord?) -> Bool {
        if !cellCanFall(col, row, partner) { return false }
        guard let p = partner else { return true }
        return cellCanFall(p.col, p.row, Coord(col, row))
    }

    private func cellCanFall(_ col: Int, _ row: Int, _ groupMate: Coord?) -> Bool {
        let below = row + 1
        if below >= height { return false }
        if let m = groupMate, m.col == col && m.row == below { return true }
        return grid[below][col].isEmpty()
    }

    /// Hiçbir kapsül yarısı düşemeyecek hale gelene kadar gravity uygular (anında).
    func applyGravityFully() {
        while applyGravityStep() { /* devam */ }
    }

    /// Ödüllü reklamla devam: üstten rows satırı (virüs dahil) tamamen boşaltır.
    func clearTopRows(_ rows: Int) {
        let limit = min(rows, height)
        for r in 0..<limit {
            for c in 0..<width { setCell(c, r, Cell.EMPTY) }
        }
        if limit >= height { return }
        for c in 0..<width {
            let cell = grid[limit][c]
            if cell.type == .CAPSULE_HALF && cell.link == .UP {
                grid[limit][c] = Cell(.CAPSULE_HALF, cell.color)
            }
        }
    }

    /// Şişenin ağzına (row 0) tek bir sütunda bile ulaşıldı mı?
    func isTopRowReached() -> Bool {
        for col in 0..<width {
            if !isEmpty(col, 0) { return true }
        }
        return false
    }

    /// Rakipten gelen saldırı: en fazla width FARKLI sütunun TEPESİNE tek hücrelik ceza parçası
    /// koyar (sabit aralıklı "tarak" deseni, başlangıç sütunu rastgele).
    func insertGarbage(_ count: Int, _ palette: [CapsuleColor]?, _ rng: JavaRandom) {
        let n = min(count, width)
        if n <= 0 { return }
        let spacing = n > 1 ? min(Board.GARBAGE_SPACING, (width - 1) / (n - 1)) : Board.GARBAGE_SPACING
        let span = (n - 1) * spacing + 1
        let offset = rng.nextInt(width - span + 1)
        for i in 0..<n {
            let col = offset + i * spacing
            if !isEmpty(col, 0) { continue } // sütunun tepesi doluysa bu ceza kaybolur
            let color: CapsuleColor
            if let p = palette, !p.isEmpty {
                color = p[rng.nextInt(p.count)]
            } else {
                color = CapsuleColor.random(rng)
            }
            setCell(col, 0, Cell(.CAPSULE_HALF, color))
        }
    }

    /// Bağımsız kopya (AI'ın hipotetik denemeleri için).
    func copy() -> Board {
        let clone = Board(width, height)
        clone.grid = grid
        clone.virusCount = virusCount
        return clone
    }

    /// Bir cascade/zincir çözümlemesinin özet sonucu.
    struct CascadeResult {
        let patlamaCount: Int
        let virusesCleared: Int
        let cellsCleared: Int
    }

    /// Hiç eşleşme kalmayana kadar temizleme+gravity döngüsünü ANINDA çalıştırır (AI).
    func resolveCascade() -> CascadeResult {
        var totalPatlama = 0
        var totalCells = 0
        let virusesBefore = virusCount

        while true {
            let groups = findMatchGroups()
            if groups.isEmpty { break }
            totalPatlama += groups.count
            totalCells += clearGroups(groups)
            applyGravityFully()
        }

        return CascadeResult(patlamaCount: totalPatlama, virusesCleared: virusesBefore - virusCount, cellsCleared: totalCells)
    }

    func printDebug() {
        for row in 0..<height {
            print((0..<width).map { grid[row][$0].debugString }.joined(separator: " "))
        }
    }
}

/// Pivot hücre (pivotCol, pivotRow) her zaman kapsülün "ana" yarısıdır (colorA). İkinci hücre
/// (colorB) orientation'ın offset'i kadar kaymış konumdadır.
final class Capsule {
    private var pivotCol: Int
    private var pivotRow: Int
    private var orientation: Orientation
    private let colorA: CapsuleColor
    private let colorB: CapsuleColor

    convenience init(_ pivotCol: Int, _ pivotRow: Int, _ colorA: CapsuleColor, _ colorB: CapsuleColor) {
        self.init(pivotCol, pivotRow, .RIGHT, colorA, colorB)
    }

    init(_ pivotCol: Int, _ pivotRow: Int, _ orientation: Orientation, _ colorA: CapsuleColor, _ colorB: CapsuleColor) {
        self.pivotCol = pivotCol
        self.pivotRow = pivotRow
        self.orientation = orientation
        self.colorA = colorA
        self.colorB = colorB
    }

    func getCellA() -> Coord { return Coord(pivotCol, pivotRow) }
    func getCellB() -> Coord { return Coord(pivotCol + orientation.offsetCol, pivotRow + orientation.offsetRow) }

    func getColorA() -> CapsuleColor { return colorA }
    func getColorB() -> CapsuleColor { return colorB }
    func getOrientation() -> Orientation { return orientation }
    func getPivotCol() -> Int { return pivotCol }
    func getPivotRow() -> Int { return pivotRow }

    func setPosition(_ col: Int, _ row: Int) {
        pivotCol = col
        pivotRow = row
    }

    func setOrientation(_ o: Orientation) {
        orientation = o
    }

    /// Hem pivot hem ikinci hücre tahtada ve boş mu?
    func fitsAt(_ board: Board, _ col: Int, _ row: Int, _ o: Orientation) -> Bool {
        return isFree(board, col, row) && isFree(board, col + o.offsetCol, row + o.offsetRow)
    }

    private func isFree(_ board: Board, _ col: Int, _ row: Int) -> Bool {
        return board.isInBounds(col, row) && board.isEmpty(col, row)
    }
}
