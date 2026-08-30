//
//  BoardRenderer.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.BoardRenderer.
//
//  Şişenin içini (virüsler + haplar) çizer.
//
//  Virüsler assets/viruses/*.png sprite'larıyla çizilir. Haplar ise NES'teki gibi kodla çizilir:
//  her yarım hap, hücreyi kaplayan siyah hatlı ve DIŞ köşeleri yuvarlatılmış bir gövdedir; eşine
//  bakan kenar düz bırakılır, böylece iki yarı birleşince tek bir kapsül görünür. Eşi patlayıp
//  gitmişse (tekil yarım) dört köşesi de yuvarlanır.
//

import SwiftUI

final class BoardRenderer {

    /// NES paletindeki hap renkleri.
    private static let red = Color(hex: 0xf83800)
    private static let yellow = Color(hex: 0xf8b800)
    private static let blue = Color(hex: 0x4878f8)
    private static let outline = Color(hex: 0x000000)
    private static let gleam = Color(hex: 0xfcfcfc)

    private let assets: Assets
    private var originX: CGFloat
    private var originY: CGFloat
    private let cellW: CGFloat
    private let cellH: CGFloat
    private var boardHeightCells = 0

    init(assets: Assets, originX: CGFloat, originY: CGFloat, cellW: CGFloat, cellH: CGFloat) {
        self.assets = assets
        self.originX = originX
        self.originY = originY
        self.cellW = cellW
        self.cellH = cellH
    }

    /// Tahtanın sol-alt köşesi. İçerik alanı ekranda ortalandığı için bu değer her karede
    /// güncellenebilir.
    func setOrigin(x: CGFloat, y: CGFloat) {
        originX = x
        originY = y
    }

    /// - Parameters:
    ///   - flashingCells: CLEAR_FLASH fazında patlamak üzere olan hücreler
    ///   - flashProgress: 0 (patlama yeni başladı) - 1 (patlama bitmek üzere) arası ilerleme;
    ///     CLEAR_FLASH fazında değilken 0 gönderilmeli.
    func render(_ context: GraphicsContext, board: Board, falling: Capsule?, flashingCells: Set<Coord>, flashProgress: Float) {
        boardHeightCells = board.height

        for row in 0..<board.height {
            for col in 0..<board.width {
                let cell = board.getCell(col: col, row: row)
                if cell.isEmpty { continue }
                let progress: Float = flashingCells.contains(Coord(col: col, row: row)) ? flashProgress : -1
                drawCell(context, board: board, col: col, row: row, cell: cell, flashProgress: progress)
            }
        }

        if let falling {
            let a = falling.cellA
            drawHalf(context, col: a.col, row: a.row, color: falling.colorA, link: falling.orientation, alpha: 1)
            let b = falling.cellB
            drawHalf(context, col: b.col, row: b.row, color: falling.colorB, link: falling.orientation.opposite(), alpha: 1)
        }

        if !flashingCells.isEmpty { drawPopEffects(context, flashingCells: flashingCells, progress: flashProgress) }
    }

    private func cellX(_ col: Int) -> CGFloat { originX + CGFloat(col) * cellW }
    private func cellY(_ row: Int) -> CGFloat { originY + CGFloat(boardHeightCells - 1 - row) * cellH }

    private func drawCell(_ context: GraphicsContext, board: Board, col: Int, row: Int, cell: Cell, flashProgress: Float) {
        let alpha: CGFloat = flashProgress < 0 ? 1 : CGFloat(1 - flashProgress * 0.6)

        if cell.type == .virus {
            drawVirus(context, x: cellX(col), y: cellY(row), color: cell.color!, alpha: alpha)
            return
        }
        drawHalf(context, col: col, row: row, color: cell.color!, link: resolveJoinedLink(board, col: col, row: row, cell: cell), alpha: alpha)
    }

    private func drawVirus(_ context: GraphicsContext, x: CGFloat, y: CGFloat, color: CapsuleColor, alpha: CGFloat) {
        if let tex = assets.virusFor(color) {
            NesUI.image(context, tex, x: x, y: y, w: cellW, h: cellH, alpha: alpha)
            return
        }
        // Görsel yoksa: gövde + iki göz şeklinde basit bir virüs.
        NesUI.roundRect(context, x: x + 1, y: y + 1, w: cellW - 2, h: cellH - 2, r: 2, color: withAlpha(colorFor(color), alpha))
        NesUI.rect(context, x: x + 2, y: y + cellH - 4, w: 1.5, h: 1.5, color: withAlpha(BoardRenderer.outline, alpha))
        NesUI.rect(context, x: x + cellW - 3.5, y: y + cellH - 4, w: 1.5, h: 1.5, color: withAlpha(BoardRenderer.outline, alpha))
    }

    /// Bir yarım hap. link bu hücrenin eşine hangi yönde baktığını söyler; o kenar düz
    /// kalır (iki yarı birleşsin diye), diğer köşeler yuvarlanır. link nil ise eşi yok: tekil,
    /// dört köşesi de yuvarlak bir hap çizilir.
    private func drawHalf(_ context: GraphicsContext, col: Int, row: Int, color: CapsuleColor, link: Orientation?, alpha: CGFloat) {
        drawHalfAt(context, x: cellX(col), y: cellY(row), w: cellW, h: cellH, color: color, link: link, alpha: alpha)
    }

    private func drawHalfAt(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                            color: CapsuleColor, link: Orientation?, alpha: CGFloat) {
        // Dış hat + renkli gövde: gövde her kenardan 1px içeride kalır, böylece hücreler
        // arasında ince bir ayrım çizgisi oluşur.
        let r = min(w, h) * 0.38
        halfShape(context, x: x, y: y, w: w, h: h, link: link, r: r, color: withAlpha(BoardRenderer.outline, alpha))
        halfShape(context, x: x + 1, y: y + 1, w: w - 2, h: h - 2, link: link, r: r - 1, color: withAlpha(colorFor(color), alpha))

        // Dış uçta küçük beyaz parlama (NES hapındaki ışık yansıması).
        var gx: CGFloat, gy: CGFloat
        if link == .left {          // bu hücre çiftin SAĞI -> parlama sağ üstte
            gx = x + w - 4; gy = y + h - 3
        } else if link == .up {     // çiftin ALTI -> parlama sol altta
            gx = x + 2; gy = y + 2
        } else {                    // RIGHT / DOWN / tekil -> sol üst
            gx = x + 2; gy = y + h - 3
        }
        NesUI.rect(context, x: gx, y: gy, w: 2, h: 1, color: withAlpha(BoardRenderer.gleam, alpha))
    }

    /// Sıradaki hap önizlemesi (HUD): tahtadaki hapla birebir aynı çizim.
    func drawPreviewHalf(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: CapsuleColor, leftHalf: Bool) {
        drawHalfAt(context, x: x, y: y, w: w, h: h, color: color, link: leftHalf ? .right : .left, alpha: 1)
    }

    /// Dış köşeleri yuvarlak, eşe bakan kenarı düz gövde: önce tamamen yuvarlak bir dikdörtgen,
    /// ardından düz kalması gereken kenardaki yuvarlaklık düz bir şeritle doldurulur.
    private func halfShape(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                          link: Orientation?, r radiusIn: CGFloat, color: Color) {
        let r = max(0, min(radiusIn, min(w, h) / 2))
        NesUI.roundRect(context, x: x, y: y, w: w, h: h, r: r, color: color)
        guard let link else { return }
        switch link {
        case .right: NesUI.rect(context, x: x + w - r, y: y, w: r, h: h, color: color)
        case .left: NesUI.rect(context, x: x, y: y, w: r, h: h, color: color)
        case .up: NesUI.rect(context, x: x, y: y + h - r, w: w, h: r, color: color)
        case .down: NesUI.rect(context, x: x, y: y, w: w, h: r, color: color)
        }
    }

    /// Kilitlenmiş bir capsuleHalf hücrenin görsel olarak "eşleşmiş" sayılıp sayılmayacağını bulur:
    /// link yönündeki komşu da capsuleHalf olmalı VE karşılıklı olarak bu hücreye bakmalı.
    private func resolveJoinedLink(_ board: Board, col: Int, row: Int, cell: Cell) -> Orientation? {
        guard let link = cell.link else { return nil }
        let pc = col + link.offsetCol
        let pr = row + link.offsetRow
        guard board.isInBounds(col: pc, row: pr) else { return nil }
        let partner = board.getCell(col: pc, row: pr)
        guard partner.type == .capsuleHalf, partner.link == link.opposite() else { return nil }
        return link
    }

    // ---- Baloncuk patlaması animasyonu ----

    private static let bubblesPerCell = 5

    private func drawPopEffects(_ context: GraphicsContext, flashingCells: Set<Coord>, progress: Float) {
        for c in flashingCells {
            let cx = cellX(c.col) + cellW / 2
            let cy = cellY(c.row) + cellH / 2
            drawBubbleBurst(context, cx: cx, cy: cy, col: c.col, row: c.row, progress: progress)
        }
    }

    private func drawBubbleBurst(_ context: GraphicsContext, cx: CGFloat, cy: CGFloat, col: Int, row: Int, progress: Float) {
        let seedBase = row * 1000 + col

        // Dışa doğru fırlayan baloncuklar (hücre koordinatından türetilen sabit "rastgele"
        // açılar — engine RNG'sine dokunmaz, sadece görsel çeşitlilik).
        for i in 0..<BoardRenderer.bubblesPerCell {
            let angle = Double((seedBase * 41 + i * 73) % 360) * .pi / 180
            let dist = min(cellW, cellH) * 0.6 * CGFloat(progress)
            let bx = cx + CGFloat(cos(angle)) * dist
            let by = cy + CGFloat(sin(angle)) * dist
            let size = max(min(cellW, cellH) * (0.14 + 0.07 * CGFloat((seedBase + i) % 3)) * CGFloat(1 - progress * 0.5), 0.5)
            NesUI.rect(context, x: bx - size / 2, y: by - size / 2, w: size, h: size,
                       color: withAlpha(BoardRenderer.gleam, CGFloat((1 - progress) * 0.9)))
        }
    }

    // ---- Renk yardımcıları ----

    private func colorFor(_ c: CapsuleColor) -> Color {
        switch c {
        case .red: return BoardRenderer.red
        case .yellow: return BoardRenderer.yellow
        case .blue: return BoardRenderer.blue
        }
    }

    private func withAlpha(_ base: Color, _ alpha: CGFloat) -> Color {
        base.opacity(Double(alpha))
    }
}
