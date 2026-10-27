//
//  Renderers.swift
//  VirusHunt
//
//  com.rummuscan.game.BoardRenderer + BottleRenderer (VirusHunt Android sürümünden birebir).
//

import Foundation

/// Şişenin içini (virüsler + haplar) çizer. Virüsler sprite, haplar NES'teki gibi kodla çizilir.
final class BoardRenderer {

    private static let RED = Color(0xf83800ff)
    private static let YELLOW = Color(0xf8b800ff)
    private static let BLUE = Color(0x4878f8ff)
    private static let OUTLINE = Color(0x000000ff)
    private static let GLEAM = Color(0xfcfcfcff)

    private let ui: NesUi
    private let batch: SpriteBatch
    private let assets: Assets
    private let cellW: Int, cellH: Int
    private var originX: Float, originY: Float
    private var boardHeightCells = 0

    private var tint = Color()

    init(_ ui: NesUi, _ batch: SpriteBatch, _ assets: Assets, _ originX: Float, _ originY: Float, _ cellW: Int, _ cellH: Int) {
        self.ui = ui
        self.batch = batch
        self.assets = assets
        self.originX = originX
        self.originY = originY
        self.cellW = cellW
        self.cellH = cellH
    }

    func setOrigin(_ originX: Float, _ originY: Float) {
        self.originX = originX
        self.originY = originY
    }

    func render(_ board: Board, _ falling: Capsule?, _ flashingCells: [Coord], _ flashProgress: Float) {
        boardHeightCells = board.getHeight()

        let flashKeys = Set(flashingCells)

        for row in 0..<board.getHeight() {
            for col in 0..<board.getWidth() {
                let cell = board.getCell(col, row)
                if cell.isEmpty() { continue }
                let progress: Float = flashKeys.contains(Coord(col, row)) ? flashProgress : -1
                drawCell(board, col, row, cell, progress)
            }
        }

        if let f = falling {
            drawHalf(f.getCellA().col, f.getCellA().row, f.getColorA(), f.getOrientation(), 1)
            drawHalf(f.getCellB().col, f.getCellB().row, f.getColorB(), f.getOrientation().opposite(), 1)
        }

        if !flashKeys.isEmpty { drawPopEffects(flashingCells, flashProgress) }
    }

    private func cellX(_ col: Int) -> Float { return originX + Float(col * cellW) }

    private func cellY(_ row: Int) -> Float { return originY + Float((boardHeightCells - 1 - row) * cellH) }

    private func drawCell(_ board: Board, _ col: Int, _ row: Int, _ cell: Cell, _ flashProgress: Float) {
        let alpha: Float = flashProgress < 0 ? 1 : (1 - flashProgress * 0.6)
        guard let color = cell.color else { return }

        if cell.type == .VIRUS {
            drawVirus(cellX(col), cellY(row), color, alpha)
            return
        }
        drawHalf(col, row, color, resolveJoinedLink(board, col, row, cell), alpha)
    }

    private func drawVirus(_ x: Float, _ y: Float, _ color: CapsuleColor, _ alpha: Float) {
        if let tex = assets.virusFor(color) {
            batch.setColor(1, 1, 1, alpha)
            batch.draw(tex, x, y, Float(cellW), Float(cellH))
            batch.setColor(Color.WHITE)
            return
        }
        let cw = Float(cellW), ch = Float(cellH)
        ui.roundRect(x + 1, y + 1, cw - 2, ch - 2, 2, withAlpha(colorFor(color), alpha))
        ui.rect(x + 2, y + ch - 4, 1.5, 1.5, withAlpha(BoardRenderer.OUTLINE, alpha))
        ui.rect(x + cw - 3.5, y + ch - 4, 1.5, 1.5, withAlpha(BoardRenderer.OUTLINE, alpha))
    }

    private func drawHalf(_ col: Int, _ row: Int, _ color: CapsuleColor, _ link: Orientation?, _ alpha: Float) {
        drawHalfAt(cellX(col), cellY(row), Float(cellW), Float(cellH), color, link, alpha)
    }

    private func drawHalfAt(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ color: CapsuleColor, _ link: Orientation?, _ alpha: Float) {
        let r = min(w, h) * 0.38
        halfShape(x, y, w, h, link, r, withAlpha(BoardRenderer.OUTLINE, alpha))
        halfShape(x + 1, y + 1, w - 2, h - 2, link, r - 1, withAlpha(colorFor(color), alpha))

        let gx: Float, gy: Float
        if link == .LEFT {          // bu hücre çiftin SAĞI -> parlama sağ üstte
            gx = x + w - 4; gy = y + h - 3
        } else if link == .UP {     // çiftin ALTI -> parlama sol altta
            gx = x + 2; gy = y + 2
        } else {                    // RIGHT / DOWN / tekil -> sol üst
            gx = x + 2; gy = y + h - 3
        }
        ui.rect(gx, gy, 2, 1, withAlpha(BoardRenderer.GLEAM, alpha))
    }

    /// Sıradaki hap önizlemesi (HUD): tahtadaki hapla birebir aynı çizim.
    func drawPreviewHalf(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ color: CapsuleColor, _ leftHalf: Bool) {
        drawHalfAt(x, y, w, h, color, leftHalf ? .RIGHT : .LEFT, 1)
    }

    private func halfShape(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ link: Orientation?, _ r0: Float, _ color: Color) {
        let r = max(0, min(r0, min(w, h) / 2))
        ui.roundRect(x, y, w, h, r, color)
        guard let link = link else { return }
        switch link {
        case .RIGHT: ui.rect(x + w - r, y, r, h, color)
        case .LEFT: ui.rect(x, y, r, h, color)
        case .UP: ui.rect(x, y + h - r, w, r, color)
        case .DOWN: ui.rect(x, y, w, r, color)
        }
    }

    private func resolveJoinedLink(_ board: Board, _ col: Int, _ row: Int, _ cell: Cell) -> Orientation? {
        guard let link = cell.link else { return nil }
        let pc = col + link.offsetCol
        let pr = row + link.offsetRow
        if !board.isInBounds(pc, pr) { return nil }
        let partner = board.getCell(pc, pr)
        if partner.type != .CAPSULE_HALF { return nil }
        if partner.link != link.opposite() { return nil }
        return link
    }

    // ---- Baloncuk patlaması animasyonu ----

    private static let BUBBLES_PER_CELL = 5

    private func drawPopEffects(_ flashingCells: [Coord], _ progress: Float) {
        for c in flashingCells {
            let cx = cellX(c.col) + Float(cellW) / 2
            let cy = cellY(c.row) + Float(cellH) / 2
            drawBubbleBurst(cx, cy, c.col, c.row, progress)
        }
    }

    private func drawBubbleBurst(_ cx: Float, _ cy: Float, _ col: Int, _ row: Int, _ progress: Float) {
        let seedBase = Int64(row) * 1000 + Int64(col)
        let minCell = Float(min(cellW, cellH))

        for i in 0..<BoardRenderer.BUBBLES_PER_CELL {
            let angle = Double((seedBase * 41 + Int64(i) * 73) % 360) * Double.pi / 180
            let dist = minCell * 0.6 * progress
            let bx = cx + Float(cos(angle)) * dist
            let by = cy + Float(sin(angle)) * dist
            let size = max(minCell * (0.14 + 0.07 * Float((seedBase + Int64(i)) % 3)) * (1 - progress * 0.5), 0.5)
            ui.rect(bx - size / 2, by - size / 2, size, size, withAlpha(BoardRenderer.GLEAM, (1 - progress) * 0.9))
        }
    }

    // ---- Renk yardımcıları ----

    private func colorFor(_ c: CapsuleColor) -> Color {
        switch c {
        case .RED: return BoardRenderer.RED
        case .YELLOW: return BoardRenderer.YELLOW
        default: return BoardRenderer.BLUE
        }
    }

    private func withAlpha(_ base: Color, _ alpha: Float) -> Color {
        tint.set(base)
        tint.a = base.a * alpha
        return tint
    }
}

/// ui/bottle_frame.png'i dört dikey dilim hâlinde çizen ortak parça.
final class BottleRenderer {

    private static let GLASS_TOP    = Color(0xc8eefaff)
    private static let GLASS_BOTTOM = Color(0xa6d5ebff)
    private static let GLASS_EDGE   = Color(0x8ec7e2ff)
    private var fillTint = Color()

    private let ui: NesUi
    private let batch: SpriteBatch
    private let assets: Assets

    init(_ ui: NesUi, _ batch: SpriteBatch, _ assets: Assets) {
        self.ui = ui
        self.batch = batch
        self.assets = assets
    }

    func render(_ boardOriginX: Float, _ boardOriginY: Float) {
        render(boardOriginX, boardOriginY, GameConfig.BOARD_PIXEL_WIDTH, GameConfig.BODY_PIXEL_HEIGHT)
    }

    func renderGlassAbove(_ boardOriginX: Float, _ boardOriginY: Float) {
        renderGlassAbove(boardOriginX, boardOriginY, GameConfig.BOARD_PIXEL_WIDTH, GameConfig.BODY_PIXEL_HEIGHT)
    }

    func render(_ boardOriginX: Float, _ boardOriginY: Float, _ boardPixelWidth: Int, _ bodyPixelHeight: Int) {
        let g = GameConfig.bottleGeometryFor(boardPixelWidth, bodyPixelHeight, boardOriginX, boardOriginY)

        let fx = g.frameX
        let fw = g.frameW

        let floorY = boardOriginY - g.floorH
        let bodyY = boardOriginY
        let shoulderY = bodyY + g.bodyH
        let neckY = shoulderY + g.shoulderH

        // 1) İç boşluk: gövde ve yukarısı siyah, taban ise cam rengi.
        fillSliceInterior(fx, floorY, fw, g.floorH, GameConfig.BOTTLE_SEAM_FLOOR, GameConfig.BOTTLE_IMG_H,
                          BottleRenderer.GLASS_TOP, BottleRenderer.GLASS_BOTTOM, 4)
        ui.rect(boardOriginX, boardOriginY - 2.5, Float(boardPixelWidth), 2.5, BottleRenderer.GLASS_TOP)
        fillSliceInterior(fx, bodyY, fw, g.bodyH, GameConfig.BOTTLE_SEAM_BODY, GameConfig.BOTTLE_SEAM_FLOOR, NesUi.BLACK, NesUi.BLACK, 0)
        fillSliceInterior(fx, shoulderY, fw, g.shoulderH, GameConfig.BOTTLE_SEAM_NECK, GameConfig.BOTTLE_SEAM_BODY, NesUi.BLACK, NesUi.BLACK, 0)
        fillSliceInterior(fx, neckY, fw, g.neckH, 0, GameConfig.BOTTLE_SEAM_NECK, NesUi.BLACK, NesUi.BLACK, 0)

        // 2) Cam görseli, dilim dilim.
        if assets.bottleFrame != nil {
            drawSlice(fx, floorY, fw, g.floorH, GameConfig.BOTTLE_SEAM_FLOOR, GameConfig.BOTTLE_IMG_H)
            drawSlice(fx, bodyY, fw, g.bodyH, GameConfig.BOTTLE_SEAM_BODY, GameConfig.BOTTLE_SEAM_FLOOR)
            drawSlice(fx, shoulderY, fw, g.shoulderH, GameConfig.BOTTLE_SEAM_NECK, GameConfig.BOTTLE_SEAM_BODY)
            drawSlice(fx, neckY, fw, g.neckH, 0, GameConfig.BOTTLE_SEAM_NECK)
        }

        // 3) Oyun alanı camın ÜSTÜNE çizilir.
        ui.rect(boardOriginX, boardOriginY, Float(boardPixelWidth), Float(bodyPixelHeight), NesUi.BLACK)
        ui.rect(boardOriginX, boardOriginY - 1, Float(boardPixelWidth), 1, BottleRenderer.GLASS_EDGE)
    }

    /// Omuz ve boyun cam dilimlerini hücrelerin ÜSTÜNE bir kez daha çizer (tahtadan sonra çağrılır).
    func renderGlassAbove(_ boardOriginX: Float, _ boardOriginY: Float, _ boardPixelWidth: Int, _ bodyPixelHeight: Int) {
        if assets.bottleFrame == nil { return }
        let g = GameConfig.bottleGeometryFor(boardPixelWidth, bodyPixelHeight, boardOriginX, boardOriginY)
        let shoulderY = boardOriginY + g.bodyH
        let neckY = shoulderY + g.shoulderH
        drawSlice(g.frameX, shoulderY, g.frameW, g.shoulderH, GameConfig.BOTTLE_SEAM_NECK, GameConfig.BOTTLE_SEAM_BODY)
        drawSlice(g.frameX, neckY, g.frameW, g.neckH, 0, GameConfig.BOTTLE_SEAM_NECK)
    }

    private func drawSlice(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ imgTop: Float, _ imgBottom: Float) {
        batch.draw(assets.bottleFrame, x, y, w, h,
                   0, javaRound(imgTop), Int(GameConfig.BOTTLE_IMG_W), javaRound(imgBottom - imgTop),
                   false, false)
    }

    private func fillSliceInterior(_ x: Float, _ y: Float, _ w: Float, _ h: Float,
                                   _ imgTop: Float, _ imgBottom: Float, _ bottom: Color, _ top: Color,
                                   _ extendDown: Float) {
        guard let spans = assets.bottleInterior else { return }
        let rows = Int(h.rounded(.up))
        for i in 0..<max(0, rows) {
            let t = min(1, (Float(i) + 0.5) / h)
            let imgY = imgBottom - t * (imgBottom - imgTop)
            let sample = javaRound((GameConfig.BOTTLE_IMG_H - 1 - imgY) / (GameConfig.BOTTLE_IMG_H - 1) * Float(Assets.BOTTLE_SAMPLES - 1))
            guard let span = spans[max(0, min(Assets.BOTTLE_SAMPLES - 1, sample))] else { continue }
            fillTint.set(bottom)
            fillTint.lerp(top, t)
            ui.rect(x + span.0 * w, y + Float(i) - extendDown, (span.1 - span.0) * w, 1 + extendDown, fillTint)
        }
    }
}
