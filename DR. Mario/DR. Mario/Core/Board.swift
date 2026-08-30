//
//  Board.swift
//  DR. Mario
//
//  Port of com.rummuscan.core.Board.
//
//  Dr. Mario tahtası. row=0 en üst satır, row=(height-1) en alt satır.
//  Tüm koordinatlar (col, row) şeklinde, sol-üst köşe (0,0).
//

import Foundation

final class Board {
    static let defaultWidth = 8
    static let defaultHeight = 16
    private static let minMatchLength = 4

    let width: Int
    let height: Int
    private var grid: [[Cell]] // grid[row][col]
    private(set) var virusCount = 0

    init(width: Int = Board.defaultWidth, height: Int = Board.defaultHeight) {
        self.width = width
        self.height = height
        self.grid = Array(repeating: Array(repeating: Cell.empty, count: width), count: height)
    }

    /// Mikroskop panelinde bir rengin hâlâ gösterilip gösterilmeyeceğini belirlemek için:
    /// tahtada bu renkten en az bir virüs kaldı mı?
    func hasVirusOfColor(_ color: CapsuleColor) -> Bool {
        for r in 0..<height {
            for c in 0..<width {
                let cell = grid[r][c]
                if cell.type == .virus && cell.color == color { return true }
            }
        }
        return false
    }

    func isInBounds(col: Int, row: Int) -> Bool {
        col >= 0 && col < width && row >= 0 && row < height
    }

    func getCell(col: Int, row: Int) -> Cell {
        grid[row][col]
    }

    func isEmpty(col: Int, row: Int) -> Bool {
        isInBounds(col: col, row: row) && grid[row][col].isEmpty
    }

    fileprivate func setCell(col: Int, row: Int, cell: Cell) {
        let previous = grid[row][col]
        if previous.type == .virus { virusCount -= 1 }
        grid[row][col] = cell
        if cell.type == .virus { virusCount += 1 }
    }

    /// Belirli bir seviye/virüs sayısı hedefine göre tahtayı rastgele virüslerle doldurur.
    /// Deterministic olması için dışarıdan seed'li rng alır.
    /// Spawn alanının (üst birkaç satır) boş bırakılması garanti edilir.
    func fillWithViruses(virusTarget: Int, rng: inout SeededRandom, keepTopRowsClear: Int) {
        var placed = 0
        var attempts = 0
        let maxAttempts = virusTarget * 200
        while placed < virusTarget && attempts < maxAttempts {
            attempts += 1
            let row = keepTopRowsClear + rng.nextInt(height - keepTopRowsClear)
            let col = rng.nextInt(width)
            if !isEmpty(col: col, row: row) { continue }
            let color = CapsuleColor.random(&rng)
            // Aynı renkten yatayda/dikeyde 3'lü oluşmasını engelle (spawn anında otomatik patlama olmasın)
            if wouldCreateInitialMatch(col: col, row: row, color: color) { continue }
            setCell(col: col, row: row, cell: Cell(type: .virus, color: color))
            placed += 1
        }
    }

    private func wouldCreateInitialMatch(col: Int, row: Int, color: CapsuleColor) -> Bool {
        var horizontal = 1
        var c = col - 1
        while c >= 0 && sameColor(col: c, row: row, color: color) { horizontal += 1; c -= 1 }
        c = col + 1
        while c < width && sameColor(col: c, row: row, color: color) { horizontal += 1; c += 1 }
        if horizontal >= 3 { return true }

        var vertical = 1
        var r = row - 1
        while r >= 0 && sameColor(col: col, row: r, color: color) { vertical += 1; r -= 1 }
        r = row + 1
        while r < height && sameColor(col: col, row: r, color: color) { vertical += 1; r += 1 }
        return vertical >= 3
    }

    private func sameColor(col: Int, row: Int, color: CapsuleColor) -> Bool {
        isInBounds(col: col, row: row) && !grid[row][col].isEmpty && grid[row][col].color == color
    }

    /// Kapsülün her iki hücresini de yerleştirir (yer değiştirmez, sadece koyar).
    /// Geçerlilik kontrolü çağıran taraf (GameEngine) tarafından yapılmalı.
    func lockCapsule(_ capsule: Capsule) {
        let c1 = capsule.cellA
        let c2 = capsule.cellB
        let aToB = capsule.orientation
        setCell(col: c1.col, row: c1.row, cell: Cell(type: .capsuleHalf, color: capsule.colorA, link: aToB))
        setCell(col: c2.col, row: c2.row, cell: Cell(type: .capsuleHalf, color: capsule.colorB, link: aToB.opposite()))
    }

    /// Yatayda/dikeyde 4+ aynı renk bloğu bulur. Virüs + kapsül yarısı fark etmeksizin
    /// renk aynıysa eşleşir (klasik Dr. Mario kuralı).
    ///
    /// Bulunan hücreler, birbirine komşu (4 yönlü) olanlar aynı "patlama" grubunda
    /// sayılacak şekilde bağlı bileşenlere (connected components) ayrılır. Bu,
    /// saldırı mekaniğinde "tek hamlede kaç ayrı patlama oldu" sayısını hesaplamak
    /// için gerekli (bkz. GameEngine.lockAndResolve).
    func findMatchGroups() -> [Set<Coord>] {
        var matched: Set<Coord> = []

        // Yatay taramalar
        for row in 0..<height {
            var runStart = 0
            var col = 1
            while col <= width {
                let sameAsRunStart = col < width && grid[row][col].matchesColor(grid[row][runStart])
                if !sameAsRunStart {
                    let runLength = col - runStart
                    if runLength >= Board.minMatchLength {
                        for k in runStart..<col { matched.insert(Coord(col: k, row: row)) }
                    }
                    runStart = col
                }
                col += 1
            }
        }

        // Dikey taramalar
        for col in 0..<width {
            var runStart = 0
            var row = 1
            while row <= height {
                let sameAsRunStart = row < height && grid[row][col].matchesColor(grid[runStart][col])
                if !sameAsRunStart {
                    let runLength = row - runStart
                    if runLength >= Board.minMatchLength {
                        for k in runStart..<row { matched.insert(Coord(col: col, row: k)) }
                    }
                    runStart = row
                }
                row += 1
            }
        }

        return groupByAdjacency(matched)
    }

    /// Eşleşen hücreleri, birbirine komşu olanlar aynı grupta olacak şekilde ayırır (BFS).
    private func groupByAdjacency(_ matched: Set<Coord>) -> [Set<Coord>] {
        var groups: [Set<Coord>] = []
        var visited: Set<Coord> = []

        for start in matched {
            if visited.contains(start) { continue }

            var group: Set<Coord> = []
            var queue: [Coord] = [start]
            visited.insert(start)

            while !queue.isEmpty {
                let cell = queue.removeFirst()
                group.insert(cell)
                let neighbors = [
                    Coord(col: cell.col - 1, row: cell.row), Coord(col: cell.col + 1, row: cell.row),
                    Coord(col: cell.col, row: cell.row - 1), Coord(col: cell.col, row: cell.row + 1),
                ]
                for n in neighbors where matched.contains(n) && !visited.contains(n) {
                    visited.insert(n)
                    queue.append(n)
                }
            }
            groups.append(group)
        }
        return groups
    }

    /// Verilen gruplardaki tümündeki hücreleri boşaltır. Döndürülen değer temizlenen hücre sayısıdır.
    @discardableResult
    func clearGroups(_ groups: [Set<Coord>]) -> Int {
        var count = 0
        for group in groups {
            for cell in group {
                setCell(col: cell.col, row: cell.row, cell: Cell.empty)
                count += 1
            }
        }
        return count
    }

    /// Tek bir gravity ADIMI uygular: havada kalan her kapsül yarısı 1 satır aşağı iner.
    ///
    /// ÖNEMLİ: Virüsler ASLA düşmez, oyun başındaki yerlerinde sabit kalır (klasik
    /// Dr. Mario davranışı). Sadece CAPSULE_HALF tipindeki hücreler düşer; bir kapsül
    /// yarısı altında virüs, başka bir kapsül yarısı veya zemin varsa durur.
    ///
    /// Hâlâ eşiyle BAĞLI olan iki yarı tek parça gibi davranır: yatay bir kapsülün bir yarısı
    /// destekleniyorsa diğer yarısı boşlukta olsa bile kapsül düşmez (klasik Dr. Mario davranışı).
    /// Yalnızca eşi patlayıp kopmuş (link'i artık karşılıklı olmayan) tekil yarılar kendi başına
    /// düşer.
    ///
    /// - Returns: bu adımda en az bir hücre hareket ettiyse true.
    @discardableResult
    func applyGravityStep() -> Bool {
        var moved = false
        // Alttan üste doğru tarıyoruz ki bir yığın aynı adımda topluca 1 satır kaysın.
        var row = height - 2
        while row >= 0 {
            for col in 0..<width {
                let cell = grid[row][col]
                if cell.type != .capsuleHalf { continue }

                let partner = partnerOf(col: col, row: row, cell: cell) // nil -> tekil yarı
                guard canGroupFall(col: col, row: row, partner: partner) else { continue }

                let partnerCell = partner.map { grid[$0.row][$0.col] }
                setCell(col: col, row: row, cell: Cell.empty)
                if let p = partner { setCell(col: p.col, row: p.row, cell: Cell.empty) }
                setCell(col: col, row: row + 1, cell: cell)
                if let p = partner, let pc = partnerCell { setCell(col: p.col, row: p.row + 1, cell: pc) }
                moved = true
            }
            row -= 1
        }
        return moved
    }

    /// Bu yarının hâlâ bağlı olduğu eşi (karşılıklı link şartıyla); yoksa nil.
    private func partnerOf(col: Int, row: Int, cell: Cell) -> (col: Int, row: Int)? {
        guard let link = cell.link else { return nil }
        let pc = col + link.offsetCol
        let pr = row + link.offsetRow
        guard isInBounds(col: pc, row: pr) else { return nil }
        let partner = grid[pr][pc]
        guard partner.type == .capsuleHalf, partner.link == link.opposite() else { return nil }
        return (pc, pr)
    }

    /// Grubun (tek yarı ya da bağlı çift) tamamı 1 satır aşağı inebiliyor mu?
    private func canGroupFall(col: Int, row: Int, partner: (col: Int, row: Int)?) -> Bool {
        guard cellCanFall(col: col, row: row, groupMate: partner) else { return false }
        guard let p = partner else { return true }
        return cellCanFall(col: p.col, row: p.row, groupMate: (col, row))
    }

    /// Bir hücrenin altı boş mu? Grubun diğer üyesinin işgal ettiği yer boş sayılır.
    private func cellCanFall(col: Int, row: Int, groupMate: (col: Int, row: Int)?) -> Bool {
        let below = row + 1
        if below >= height { return false }
        if let mate = groupMate, mate.col == col, mate.row == below { return true }
        return grid[below][col].isEmpty
    }

    /// Hiçbir kapsül yarısı düşemeyecek hale gelene kadar gravity uygular (anında).
    /// Animasyonsuz senaryolar (AI'ın hipotetik simülasyonu, garbage yerleştirme)
    /// bunu kullanır; gerçek oyun akışı ise applyGravityStep()'i tick tick çağırır.
    func applyGravityFully() {
        while applyGravityStep() { /* devam */ }
    }

    /// Spawn alanı (üst 2 satır, ortadaki 2 sütun) doluysa yeni kapsül konamaz -> board full.
    func isSpawnAreaBlocked(spawnCol: Int) -> Bool {
        !isEmpty(col: spawnCol, row: 0) || !isEmpty(col: spawnCol + 1, row: 0)
    }

    /// Rakipten gelen saldırı: rastgele sütunlara tek hücrelik "çöp virüsü" ekler.
    ///
    /// Virüsler düşmediği için (bkz. applyGravityStep), garbage doğrudan hedef
    /// sütunun mevcut yığınının HEMEN ÜSTÜNE yerleştirilir.
    func insertGarbage(count: Int, rng: inout SeededRandom) {
        for _ in 0..<count {
            let col = rng.nextInt(width)
            var landingRow = -1
            var row = height - 1
            while row >= 0 {
                if isEmpty(col: col, row: row) { landingRow = row; break }
                row -= 1
            }
            if landingRow >= 0 {
                setCell(col: col, row: landingRow, cell: Cell(type: .virus, color: CapsuleColor.random(&rng)))
            }
            // Sütun tamamen doluysa bu garbage kaybolur (board zaten dolmak üzere demektir)
        }
    }

    /// Bu board'un bağımsız bir kopyasını döndürür. AI, gerçek board'u bozmadan hipotetik
    /// kapsül yerleşimlerini burada deneyip sonucu değerlendirebilir.
    func copy() -> Board {
        let clone = Board(width: width, height: height)
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

    /// Hiç eşleşme kalmayana kadar temizleme+gravity döngüsünü ANINDA çalıştırır.
    /// Sadece animasyon gerekmeyen yerler kullanır: AI'ın hipotetik değerlendirmesi
    /// (AiController). Gerçek oyun akışı GameEngine'in faz makinesi üzerinden
    /// adım adım (animasyonlu) ilerler.
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

        let virusesCleared = virusesBefore - virusCount
        return CascadeResult(patlamaCount: totalPatlama, virusesCleared: virusesCleared, cellsCleared: totalCells)
    }
}
