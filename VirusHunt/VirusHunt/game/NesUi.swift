//
//  NesUi.swift
//  VirusHunt
//
//  com.rummuscan.game.NesUi (VirusHunt Android sürümünden birebir): NES çağı arayüz parçaları
//  (dama zemin, paneller, kalp imleci, oklar, dev kapsül logosu, dokunmatik buton şekilleri,
//  piksel font metinleri). Her şey tek bir 1x1 beyaz doku üzerinden SpriteBatch ile çizilir.
//

import Foundation

final class NesUi {

    // ---- NES paleti ----
    static let BLACK        = Color(0x000000ff)
    static let WHITE        = Color(0xfcfcfcff)
    static let YELLOW       = Color(0xfcd800ff)
    static let ORANGE       = Color(0xf87800ff)
    static let LIGHT_ORANGE = Color(0xfca044ff)
    static let PINK         = Color(0xf878a8ff)
    static let RED          = Color(0xd82800ff)
    static let GREEN        = Color(0x00e800ff)
    static let CYAN         = Color(0x3cbcfcff)
    static let GRAY         = Color(0xbcbcbcff)
    static let DARK_BROWN   = Color(0x503000ff)

    static let CHECK_GREEN_A = Color(0x4ca818ff)
    static let CHECK_GREEN_B = Color(0x1c7400ff)
    static let CHECK_ORANGE  = Color(0xf89838ff)
    static let CHECK_PINK    = Color(0xd8506cff)

    static let PILL_BLUE = Color(0x3c50e8ff)
    static let PILL_RED  = Color(0xe85068ff)

    private let batch: SpriteBatch
    private let white: Texture?

    private var tmp = Color()

    init(_ batch: SpriteBatch) {
        self.batch = batch
        let pm = Pixmap(1, 1, .RGBA8888)
        pm.setColor(Color.WHITE)
        pm.fill()
        white = Texture.from(pm)
        pm.dispose()
    }

    func whiteTexture() -> Texture? { return white }

    // ---- Temel şekiller ----

    func rect(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ color: Color) {
        batch.setColor(color)
        batch.draw(white, x, y, w, h)
        batch.setColor(Color.WHITE)
    }

    /// İçi boş dikdörtgen (kalınlık t, içe doğru çizilir).
    func frame(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ t: Float, _ color: Color) {
        rect(x, y, w, t, color)
        rect(x, y + h - t, w, t, color)
        rect(x, y + t, t, h - 2 * t, color)
        rect(x + w - t, y + t, t, h - 2 * t, color)
    }

    /// Köşeleri yuvarlatılmış dikdörtgen (köşeler satır satır daire denklemiyle).
    func roundRect(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ r0: Float, _ color: Color) {
        let r = max(0, min(r0, min(w, h) / 2))
        rect(x, y + r, w, h - 2 * r, color)
        let rows = Int(r.rounded(.up))
        for i in 0..<rows {
            let dy = r - Float(i) - 0.5
            let dx = r - max(0, r * r - dy * dy).squareRoot()
            rect(x + dx, y + Float(i), w - 2 * dx, 1, color)            // alt köşeler
            rect(x + dx, y + h - 1 - Float(i), w - 2 * dx, 1, color)    // üst köşeler
        }
    }

    func roundRectBorder(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ r: Float, _ t: Float, _ border: Color, _ fill: Color) {
        roundRect(x, y, w, h, r, border)
        roundRect(x + t, y + t, w - 2 * t, h - 2 * t, max(0, r - t), fill)
    }

    /// Dolu elips - satır satır dikdörtgenlerle.
    func ellipse(_ centerX: Float, _ centerY: Float, _ rx: Float, _ ry: Float, _ color: Color) {
        let rows = Int((ry * 2).rounded(.up))
        for i in 0..<max(0, rows) {
            let y = centerY - ry + Float(i)
            let dy = (y + 0.5 - centerY) / ry
            let k = 1 - dy * dy
            if k <= 0 { continue }
            let halfW = rx * k.squareRoot()
            rect(centerX - halfW, y, halfW * 2, 1, color)
        }
    }

    // ---- Zemin ----

    func checkerboard(_ worldWidth: Float, _ worldHeight: Float, _ cell: Float, _ a: Color, _ b: Color) {
        let cols = Int((worldWidth / cell).rounded(.up)) + 1
        let rows = Int((worldHeight / cell).rounded(.up)) + 1
        rect(0, 0, worldWidth, worldHeight, a)
        for row in 0..<rows {
            var col = row % 2
            while col < cols {
                let x = Float(col) * cell
                let y = Float(row) * cell
                rect(x, y, min(cell, worldWidth - x), min(cell, worldHeight - y), b)
                col += 2
            }
        }
    }

    // ---- Menü süsleri ----

    func heart(_ x: Float, _ y: Float, _ scale: Float, _ color: Color) {
        let rows = [
            ".#.#.",
            "#####",
            "#####",
            ".###.",
            "..#..",
        ]
        drawBitmap(rows, x, y, scale, color)
    }

    func triangleDown(_ centerX: Float, _ bottomY: Float, _ size: Float, _ color: Color) {
        var i: Float = 0
        while i < size {
            let w = 2 + i * 2
            rect(centerX - w / 2, bottomY + i, w, 1, color)
            i += 1
        }
    }

    func triangleUp(_ centerX: Float, _ bottomY: Float, _ size: Float, _ color: Color) {
        var i: Float = 0
        while i < size {
            let w = size * 2 - i * 2
            rect(centerX - w / 2, bottomY + i, w, 1, color)
            i += 1
        }
    }

    func triangleRight(_ leftX: Float, _ centerY: Float, _ size: Float, _ color: Color) {
        var i: Float = 0
        while i < size {
            let h = size * 2 - i * 2
            rect(leftX + i, centerY - h / 2, 1, h, color)
            i += 1
        }
    }

    /// Giriş ekranındaki dev kapsül.
    func capsule(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ left: Color, _ right: Color, _ outline: Color) {
        drawCapsuleBody(x - 2, y - 2, w + 4, h + 4, outline, outline, false)
        drawCapsuleBody(x, y, w, h, left, right, true)
    }

    private func drawCapsuleBody(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ left: Color, _ right: Color, _ highlight: Bool) {
        let r = h / 2
        let midX = x + w / 2
        var i: Float = 0
        while i < h {
            let dy = abs(i + 0.5 - r)
            let dx = max(0, r * r - dy * dy).squareRoot()
            let rowLeft = x + r - dx
            let rowRight = x + w - r + dx
            rect(rowLeft, y + i, midX - rowLeft, 1, left)
            rect(midX, y + i, rowRight - midX, 1, right)
            i += 1
        }
        if !highlight { return }

        let glowH = max(2, h * 0.09)
        let glowY = y + h * 0.74
        rect(x + w * 0.09, glowY, w * 0.33, glowH, NesUi.WHITE)
        rect(x + w * 0.56, glowY, w * 0.33, glowH, NesUi.WHITE)
    }

    // ---- Dokunmatik kontroller için ek şekiller ----

    func circle(_ cx: Float, _ cy: Float, _ r: Float, _ color: Color) {
        ellipse(cx, cy, r, r, color)
    }

    func circleGradient(_ cx: Float, _ cy: Float, _ r: Float, _ bottom: Color, _ top: Color) {
        let rows = Int((r * 2).rounded(.up))
        for i in 0..<max(0, rows) {
            let y = cy - r + Float(i)
            let dy = (y + 0.5 - cy) / r
            let k = 1 - dy * dy
            if k <= 0 { continue }
            let halfW = r * k.squareRoot()
            let t = (y + 0.5 - (cy - r)) / (2 * r)
            tmp.set(bottom)
            tmp.lerp(top, max(0, min(1, t)))
            rect(cx - halfW, y, halfW * 2, 1, tmp)
        }
    }

    func ring(_ cx: Float, _ cy: Float, _ r: Float, _ thickness: Float, _ color: Color) {
        let inner = max(0, r - thickness)
        let rows = Int((r * 2).rounded(.up))
        for i in 0..<max(0, rows) {
            let y = cy - r + Float(i)
            let dy = y + 0.5 - cy
            let ko = 1 - (dy / r) * (dy / r)
            if ko <= 0 { continue }
            let ho = r * ko.squareRoot()

            var hi: Float = 0
            if inner > 0 && abs(dy) < inner {
                let ki = 1 - (dy / inner) * (dy / inner)
                if ki > 0 { hi = inner * ki.squareRoot() }
            }
            if hi <= 0 {
                rect(cx - ho, y, ho * 2, 1, color)
            } else {
                rect(cx - ho, y, ho - hi, 1, color)
                rect(cx + hi, y, ho - hi, 1, color)
            }
        }
    }

    /// Daire yayı; açılar DERECE.
    func arc(_ cx: Float, _ cy: Float, _ r: Float, _ thickness: Float, _ startDeg: Float, _ endDeg: Float, _ color: Color) {
        let sweep = abs(endDeg - startDeg)
        let steps = Int(max(12, sweep * r / 26))
        for i in 0...steps {
            let a = toRadians(startDeg + (endDeg - startDeg) * Float(i) / Float(steps))
            let px = cx + cos(a) * r
            let py = cy + sin(a) * r
            rect(px - thickness / 2, py - thickness / 2, thickness, thickness, color)
        }
    }

    func filledTriangle(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float, _ x3: Float, _ y3: Float, _ color: Color) {
        let minY = min(y1, min(y2, y3))
        let maxY = max(y1, max(y2, y3))
        let rows = Int((maxY - minY).rounded(.up))
        for i in 0..<max(0, rows) {
            let y = minY + Float(i) + 0.5
            var lo = Float.greatestFiniteMagnitude, hi = -Float.greatestFiniteMagnitude
            for e in 0..<3 {
                let ax = e == 0 ? x1 : (e == 1 ? x2 : x3)
                let ay = e == 0 ? y1 : (e == 1 ? y2 : y3)
                let bx = e == 0 ? x2 : (e == 1 ? x3 : x1)
                let by = e == 0 ? y2 : (e == 1 ? y3 : y1)
                if (ay <= y && by > y) || (by <= y && ay > y) {
                    let x = ax + (y - ay) / (by - ay) * (bx - ax)
                    if x < lo { lo = x }
                    if x > hi { hi = x }
                }
            }
            if hi > lo { rect(lo, minY + Float(i), hi - lo, 1, color) }
        }
    }

    static let DIR_LEFT = 0, DIR_RIGHT = 1, DIR_DOWN = 2, DIR_UP = 3

    /// Kalın piksel chevron ("<", ">", "v", "^").
    func chevron(_ cx: Float, _ cy: Float, _ size: Float, _ thickness: Float, _ dir: Int, _ color: Color) {
        let half = size / 2
        let steps = Int(size.rounded(.up))
        for i in 0...max(0, steps) {
            let d = size * Float(i) / Float(steps)
            var px: Float, py: Float, qx: Float, qy: Float
            switch dir {
            case NesUi.DIR_LEFT:
                px = cx - half + d; py = cy + d; qx = px; qy = cy - d
            case NesUi.DIR_RIGHT:
                px = cx + half - d; py = cy + d; qx = px; qy = cy - d
            case NesUi.DIR_UP:
                py = cy + half - d; px = cx + d; qy = py; qx = cx - d
            default: // DIR_DOWN
                py = cy - half + d; px = cx + d; qy = py; qx = cx - d
            }
            rect(px - thickness / 2, py - thickness / 2, thickness, thickness, color)
            rect(qx - thickness / 2, qy - thickness / 2, thickness, thickness, color)
        }
    }

    func smallCapsule(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ left: Color, _ right: Color) {
        drawCapsuleBody(x, y, w, h, left, right, false)
    }

    // ---- Metin (PixelFont sarmalayıcıları) ----

    func text(_ s: String, _ x: Float, _ y: Float, _ scale: Float, _ color: Color) {
        PixelFont.draw(batch, white, s, x, y, scale, color)
    }

    func text(_ s: String, _ x: Float, _ y: Float, _ scale: Float, _ spacing: Float, _ color: Color) {
        PixelFont.draw(batch, white, s, x, y, scale, spacing, color)
    }

    func textCentered(_ s: String, _ centerX: Float, _ y: Float, _ scale: Float, _ color: Color) {
        PixelFont.drawCentered(batch, white, s, centerX, y, scale, color)
    }

    func textCentered(_ s: String, _ centerX: Float, _ y: Float, _ scale: Float, _ spacing: Float, _ color: Color) {
        PixelFont.drawCentered(batch, white, s, centerX, y, scale, spacing, color)
    }

    func textOutlined(_ s: String, _ x: Float, _ y: Float, _ scale: Float, _ spacing: Float, _ color: Color, _ outline: Color) {
        PixelFont.drawOutlined(batch, white, s, x, y, scale, spacing, color, outline)
    }

    func textCenteredOutlined(_ s: String, _ centerX: Float, _ y: Float, _ scale: Float, _ spacing: Float, _ color: Color, _ outline: Color) {
        PixelFont.drawCenteredOutlined(batch, white, s, centerX, y, scale, spacing, color, outline)
    }

    func textWidth(_ s: String, _ scale: Float) -> Float { return PixelFont.width(s, scale) }

    func textWidth(_ s: String, _ scale: Float, _ spacing: Float) -> Float { return PixelFont.width(s, scale, spacing) }

    // ---- Yardımcı ----

    /// ASCII resimden ('#' dolu) küçük bir bitmap çizer; satır 0 en üsttedir.
    private func drawBitmap(_ rows: [String], _ x: Float, _ y: Float, _ scale: Float, _ color: Color) {
        let h = rows.count
        for r in 0..<h {
            let row = Array(rows[r])
            let rowY = y + Float(h - 1 - r) * scale
            var col = 0
            while col < row.count {
                if row[col] != "#" { col += 1; continue }
                let start = col
                while col < row.count && row[col] == "#" { col += 1 }
                rect(x + Float(start) * scale, rowY, Float(col - start) * scale, scale, color)
            }
        }
    }

    func dispose() {}
}
