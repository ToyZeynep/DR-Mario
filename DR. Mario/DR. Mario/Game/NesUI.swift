//
//  NesUI.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.NesUi.
//
//  NES (Dr. Mario, 1990) arayüzünü kodla çizmek için ortak parça kütüphanesi:
//  dama tahtası zemin, köşeleri kırpılmış siyah paneller, süslü çift çerçeve, kalp imleci,
//  üçgen seçim oku, dev kapsül logosu ve piksel font metinleri.
//
//  TEK Y-FLIP NOKTASI: libGDX/OpenGL y-up'tır (orijin sol-alt), SwiftUI Canvas ise y-down'dır
//  (orijin sol-üst). Bu yüzden burada TEK bir alt seviye çizim fonksiyonu olan `rect(...)`
//  NES y-up koordinatını Canvas y-down noktasına çevirir; bu dosyadaki (ve PixelFont/
//  BoardRenderer/TouchControls'daki) diğer TÜM fonksiyonlar Java'daki algoritmayla birebir
//  aynı şekilde, sadece bu `rect()`'i çağırarak yazılmıştır - flip mantığı hiçbir yerde
//  tekrarlanmaz.
//

import SwiftUI

enum NesUI {
    // ---- NES paleti ----
    static let black        = Color(hex: 0x000000)
    static let white        = Color(hex: 0xfcfcfc)
    static let yellow       = Color(hex: 0xfcd800)
    static let orange       = Color(hex: 0xf87800)
    static let lightOrange  = Color(hex: 0xfca044)
    static let pink         = Color(hex: 0xf878a8)
    static let red          = Color(hex: 0xd82800)
    static let green        = Color(hex: 0x00e800)
    static let cyan         = Color(hex: 0x3cbcfc)
    static let gray         = Color(hex: 0xbcbcbc)
    static let darkBrown    = Color(hex: 0x503000)

    /// Giriş ve oyun ekranının yeşil dama zemini.
    static let checkGreenA = Color(hex: 0x4ca818)
    static let checkGreenB = Color(hex: 0x1c7400)
    /// Ayar ekranının turuncu/pembe dama zemini.
    static let checkOrange = Color(hex: 0xf89838)
    static let checkPink   = Color(hex: 0xd8506c)

    /// Logo kapsülünün iki yarısı.
    static let pillBlue = Color(hex: 0x3c50e8)
    static let pillRed  = Color(hex: 0xe85068)

    // ---- Temel şekiller ----

    /// TEK Y-FLIP NOKTASI: (x, y) NES y-up koordinatındadır (sol-alt orijin); burada
    /// Canvas'ın y-down noktasına çevrilir. worldHeight = GameConfig.worldHeight (224).
    static func rect(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: Color) {
        guard w > 0, h > 0 else { return }
        let canvasY = GameConfig.worldHeight - y - h
        context.fill(Path(CGRect(x: x, y: canvasY, width: w, height: h)), with: .color(color))
    }

    /// İçi boş dikdörtgen (kalınlık t, içe doğru çizilir).
    static func frame(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, t: CGFloat, color: Color) {
        rect(context, x: x, y: y, w: w, h: t, color: color)
        rect(context, x: x, y: y + h - t, w: w, h: t, color: color)
        rect(context, x: x, y: y + t, w: t, h: h - 2 * t, color: color)
        rect(context, x: x + w - t, y: y + t, w: t, h: h - 2 * t, color: color)
    }

    /// Köşeleri yuvarlatılmış dikdörtgen. Köşeler satır satır (daire denklemiyle) hesaplanır.
    static func roundRect(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r radiusIn: CGFloat, color: Color) {
        let r = max(0, min(radiusIn, min(w, h) / 2))
        rect(context, x: x, y: y + r, w: w, h: h - 2 * r, color: color)
        let rows = Int(ceil(r))
        for i in 0..<rows {
            let dy = r - CGFloat(i) - 0.5
            let dx = r - sqrt(max(0, r * r - dy * dy))
            rect(context, x: x + dx, y: y + CGFloat(i), w: w - 2 * dx, h: 1, color: color)             // alt köşeler
            rect(context, x: x + dx, y: y + h - 1 - CGFloat(i), w: w - 2 * dx, h: 1, color: color)     // üst köşeler
        }
    }

    /// Köşeleri kırpılmış çerçeve: dış hat border rengiyle, içi fill rengiyle doldurulur.
    static func roundRectBorder(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                r: CGFloat, t: CGFloat, border: Color, fill: Color) {
        roundRect(context, x: x, y: y, w: w, h: h, r: r, color: border)
        roundRect(context, x: x + t, y: y + t, w: w - 2 * t, h: h - 2 * t, r: max(0, r - t), color: fill)
    }

    /// Dolu elips (büyütecin mavi lensi gibi) - satır satır dikdörtgenlerle.
    static func ellipse(_ context: GraphicsContext, centerX: CGFloat, centerY: CGFloat, rx: CGFloat, ry: CGFloat, color: Color) {
        let rows = Int(ceil(ry * 2))
        for i in 0..<rows {
            let y = centerY - ry + CGFloat(i)
            let dy = (y + 0.5 - centerY) / ry
            let k = 1 - dy * dy
            if k <= 0 { continue }
            let halfW = rx * sqrt(k)
            rect(context, x: centerX - halfW, y: y, w: halfW * 2, h: 1, color: color)
        }
    }

    // ---- Zemin ----

    /// Ekranı baştan sona dama tahtasıyla kaplar (cell = kare kenarı).
    static func checkerboard(_ context: GraphicsContext, worldWidth: CGFloat, worldHeight: CGFloat, cell: CGFloat, a: Color, b: Color) {
        let cols = Int(ceil(worldWidth / cell)) + 1
        let rows = Int(ceil(worldHeight / cell)) + 1
        rect(context, x: 0, y: 0, w: worldWidth, h: worldHeight, color: a)
        for row in 0..<rows {
            var col = row % 2
            while col < cols {
                let x = CGFloat(col) * cell
                let y = CGFloat(row) * cell
                rect(context, x: x, y: y, w: min(cell, worldWidth - x), h: min(cell, worldHeight - y), color: b)
                col += 2
            }
        }
    }

    // ---- Menü süsleri ----

    /// Dr. Mario menüsündeki kırmızı kalp imleci (5x5 piksel, scale ile büyür).
    static func heart(_ context: GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat, color: Color) {
        let rows = [
            ".#.#.",
            "#####",
            "#####",
            ".###.",
            "..#..",
        ]
        drawBitmap(context, rows: rows, x: x, y: y, scale: scale, color: color)
    }

    /// Aşağı bakan seçim üçgeni (ayar ekranındaki turuncu ok): tepe noktası altta.
    static func triangleDown(_ context: GraphicsContext, centerX: CGFloat, bottomY: CGFloat, size: CGFloat, color: Color) {
        var i: CGFloat = 0
        while i < size {
            let w = 2 + i * 2
            rect(context, x: centerX - w / 2, y: bottomY + i, w: w, h: 1, color: color)
            i += 1
        }
    }

    /// Yukarı bakan seçim üçgeni: tepe noktası üstte.
    static func triangleUp(_ context: GraphicsContext, centerX: CGFloat, bottomY: CGFloat, size: CGFloat, color: Color) {
        var i: CGFloat = 0
        while i < size {
            let w = size * 2 - i * 2
            rect(context, x: centerX - w / 2, y: bottomY + i, w: w, h: 1, color: color)
            i += 1
        }
    }

    /// Sağa bakan küçük ok (klavye ile seçili satırı işaretler).
    static func triangleRight(_ context: GraphicsContext, leftX: CGFloat, centerY: CGFloat, size: CGFloat, color: Color) {
        var i: CGFloat = 0
        while i < size {
            let h = size * 2 - i * 2
            rect(context, x: leftX + i, y: centerY - h / 2, w: 1, h: h, color: color)
            i += 1
        }
    }

    /// Giriş ekranındaki dev kapsül: yatay, uçları yuvarlatılmış, sol yarısı mavi sağ yarısı
    /// kırmızı, üstünde beyaz parlama çizgileri ve etrafında koyu kenarlık.
    static func capsule(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                        left: Color, right: Color, outline: Color) {
        drawCapsuleBody(context, x: x - 2, y: y - 2, w: w + 4, h: h + 4, left: outline, right: outline, highlight: false)
        drawCapsuleBody(context, x: x, y: y, w: w, h: h, left: left, right: right, highlight: true)
    }

    private static func drawCapsuleBody(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                        left: Color, right: Color, highlight: Bool) {
        let r = h / 2
        let midX = x + w / 2
        let rows = Int(h)
        for i in 0..<rows {
            let dy = abs(CGFloat(i) + 0.5 - r)
            let dx = sqrt(max(0, r * r - dy * dy))
            let rowLeft = x + r - dx
            let rowRight = x + w - r + dx
            rect(context, x: rowLeft, y: y + CGFloat(i), w: midX - rowLeft, h: 1, color: left)
            rect(context, x: midX, y: y + CGFloat(i), w: rowRight - midX, h: 1, color: right)
        }
        guard highlight else { return }

        // Her yarının üst kısmındaki beyaz parlama (orijinal logodaki ışık yansıması).
        let glowH = max(2, h * 0.09)
        let glowY = y + h * 0.74
        rect(context, x: x + w * 0.09, y: glowY, w: w * 0.33, h: glowH, color: white)
        rect(context, x: x + w * 0.56, y: glowY, w: w * 0.33, h: glowH, color: white)
    }

    // ---- Modern dokunmatik kontroller için ek şekiller ----

    /// Dolu daire.
    static func circle(_ context: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, color: Color) {
        ellipse(context, centerX: cx, centerY: cy, rx: r, ry: r, color: color)
    }

    /// Dikey gradyanlı dolu daire: altta bottom, üstte top rengi.
    static func circleGradient(_ context: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, bottom: Color, top: Color) {
        let rows = Int(ceil(r * 2))
        for i in 0..<rows {
            let y = cy - r + CGFloat(i)
            let dy = (y + 0.5 - cy) / r
            let k = 1 - dy * dy
            if k <= 0 { continue }
            let halfW = r * sqrt(k)
            let t = (y + 0.5 - (cy - r)) / (2 * r) // 0 = en alt, 1 = en üst
            let color = bottom.lerp(to: top, t: max(0, min(1, t)))
            rect(context, x: cx - halfW, y: y, w: halfW * 2, h: 1, color: color)
        }
    }

    /// İçi boş halka (kalınlık içe doğru).
    static func ring(_ context: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, thickness: CGFloat, color: Color) {
        let inner = max(0, r - thickness)
        let rows = Int(ceil(r * 2))
        for i in 0..<rows {
            let y = cy - r + CGFloat(i)
            let dy = y + 0.5 - cy
            let ko = 1 - (dy / r) * (dy / r)
            if ko <= 0 { continue }
            let ho = r * sqrt(ko)

            var hi: CGFloat = 0
            if inner > 0 && abs(dy) < inner {
                let ki = 1 - (dy / inner) * (dy / inner)
                if ki > 0 { hi = inner * sqrt(ki) }
            }
            if hi <= 0 {
                rect(context, x: cx - ho, y: y, w: ho * 2, h: 1, color: color)
            } else {
                rect(context, x: cx - ho, y: y, w: ho - hi, h: 1, color: color)
                rect(context, x: cx + hi, y: y, w: ho - hi, h: 1, color: color)
            }
        }
    }

    /// Daire yayı (döndürme ikonundaki kavisli ok gövdesi). Açılar DERECE cinsindendir ve
    /// startDeg > endDeg verilirse yay saat yönünde çizilir.
    static func arc(_ context: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, thickness: CGFloat,
                    startDeg: CGFloat, endDeg: CGFloat, color: Color) {
        let sweep = abs(endDeg - startDeg)
        let steps = max(12, Int(sweep * r / 26))
        for i in 0...steps {
            let a = (startDeg + (endDeg - startDeg) * CGFloat(i) / CGFloat(steps)) * .pi / 180
            let px = cx + cos(a) * r
            let py = cy + sin(a) * r
            rect(context, x: px - thickness / 2, y: py - thickness / 2, w: thickness, h: thickness, color: color)
        }
    }

    /// Üç köşesi verilen dolu üçgen (yön bağımsız - ok uçları için).
    static func filledTriangle(_ context: GraphicsContext, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat,
                               x3: CGFloat, y3: CGFloat, color: Color) {
        let minY = min(y1, min(y2, y3))
        let maxY = max(y1, max(y2, y3))
        let rows = Int(ceil(maxY - minY))
        let verts = [(x1, y1), (x2, y2), (x3, y3)]
        for i in 0..<rows {
            let y = minY + CGFloat(i) + 0.5
            var lo = CGFloat.greatestFiniteMagnitude
            var hi = -CGFloat.greatestFiniteMagnitude
            for e in 0..<3 {
                let a = verts[e]
                let b = verts[(e + 1) % 3]
                if (a.1 <= y && b.1 > y) || (b.1 <= y && a.1 > y) {
                    let x = a.0 + (y - a.1) / (b.1 - a.1) * (b.0 - a.0)
                    if x < lo { lo = x }
                    if x > hi { hi = x }
                }
            }
            if hi > lo { rect(context, x: lo, y: minY + CGFloat(i), w: hi - lo, h: 1, color: color) }
        }
    }

    static let dirLeft = 0, dirRight = 1, dirDown = 2, dirUp = 3

    /// Kalın piksel chevron ("<", ">", "v", "^"). Ok butonlarının ikonu; tepe noktası
    /// dir yönünde, kolları geriye doğru 45 derece açılır.
    static func chevron(_ context: GraphicsContext, cx: CGFloat, cy: CGFloat, size: CGFloat, thickness: CGFloat,
                        dir: Int, color: Color) {
        let half = size / 2
        let steps = Int(ceil(size))
        for i in 0...steps {
            let d = size * CGFloat(i) / CGFloat(steps) // tepeden kollara doğru ilerleme
            var px: CGFloat, py: CGFloat, qx: CGFloat, qy: CGFloat
            switch dir {
            case dirLeft:
                px = cx - half + d; py = cy + d; qx = px; qy = cy - d
            case dirRight:
                px = cx + half - d; py = cy + d; qx = px; qy = cy - d
            case dirUp:
                py = cy + half - d; px = cx + d; qy = py; qx = cx - d
            default: // dirDown
                py = cy - half + d; px = cx + d; qy = py; qx = cx - d
            }
            rect(context, x: px - thickness / 2, y: py - thickness / 2, w: thickness, h: thickness, color: color)
            rect(context, x: qx - thickness / 2, y: qy - thickness / 2, w: thickness, h: thickness, color: color)
        }
    }

    /// Kenarlıksız küçük kapsül (döndürme butonunun ortasındaki minik hap).
    static func smallCapsule(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, left: Color, right: Color) {
        drawCapsuleBody(context, x: x, y: y, w: w, h: h, left: left, right: right, highlight: false)
    }

    // ---- Metin (PixelFont sarmalayıcıları) ----

    static func text(_ context: GraphicsContext, _ s: String, x: CGFloat, y: CGFloat, scale: CGFloat, color: Color) {
        PixelFont.draw(context, text: s, x: x, y: y, scale: scale, color: color)
    }

    static func text(_ context: GraphicsContext, _ s: String, x: CGFloat, y: CGFloat, scale: CGFloat, spacing: CGFloat, color: Color) {
        PixelFont.draw(context, text: s, x: x, y: y, scale: scale, spacing: spacing, color: color)
    }

    static func textCentered(_ context: GraphicsContext, _ s: String, centerX: CGFloat, y: CGFloat, scale: CGFloat, color: Color) {
        PixelFont.drawCentered(context, text: s, centerX: centerX, y: y, scale: scale, color: color)
    }

    static func textCentered(_ context: GraphicsContext, _ s: String, centerX: CGFloat, y: CGFloat, scale: CGFloat, spacing: CGFloat, color: Color) {
        PixelFont.drawCentered(context, text: s, centerX: centerX, y: y, scale: scale, spacing: spacing, color: color)
    }

    static func textOutlined(_ context: GraphicsContext, _ s: String, x: CGFloat, y: CGFloat, scale: CGFloat,
                             spacing: CGFloat, color: Color, outline: Color) {
        PixelFont.drawOutlined(context, text: s, x: x, y: y, scale: scale, spacing: spacing, color: color, outline: outline)
    }

    static func textCenteredOutlined(_ context: GraphicsContext, _ s: String, centerX: CGFloat, y: CGFloat, scale: CGFloat,
                                     spacing: CGFloat, color: Color, outline: Color) {
        PixelFont.drawCenteredOutlined(context, text: s, centerX: centerX, y: y, scale: scale, spacing: spacing, color: color, outline: outline)
    }

    static func textWidth(_ s: String, scale: CGFloat) -> CGFloat {
        PixelFont.width(s, scale: scale)
    }

    static func textWidth(_ s: String, scale: CGFloat, spacing: CGFloat) -> CGFloat {
        PixelFont.width(s, scale: scale, spacing: spacing)
    }

    // ---- Görsel (Assets) çizimi ----

    /// libGDX'in batch.draw(texture, x, y, w, h) karşılığı: NES y-up koordinatını flip eder.
    static func image(_ context: GraphicsContext, _ image: Image?, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        guard let image, w > 0, h > 0 else { return }
        let canvasY = GameConfig.worldHeight - y - h
        context.draw(image, in: CGRect(x: x, y: canvasY, width: w, height: h))
    }

    /// NES y-up içerik dikdörtgenini (TouchControls hit-rect'leri, dokunma alanları) SwiftUI'nin
    /// y-down view uzayına çevirir; rect()'teki flip formülüyle aynı mantığı kullanır. Overlay
    /// (dokunma alanı) view'larını Canvas ile aynı görsel konuma yerleştirmek için kullanılır.
    static func screenRect(fromNES rect: CGRect, scale: CGFloat) -> CGRect {
        let canvasY = GameConfig.worldHeight - rect.minY - rect.height
        return CGRect(x: rect.minX * scale, y: canvasY * scale, width: rect.width * scale, height: rect.height * scale)
    }

    static func image(_ context: GraphicsContext, _ image: Image?, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, alpha: CGFloat) {
        guard let image, w > 0, h > 0 else { return }
        let canvasY = GameConfig.worldHeight - y - h
        var ctx = context
        ctx.opacity = Double(alpha)
        ctx.draw(image, in: CGRect(x: x, y: canvasY, width: w, height: h))
    }

    // ---- Yardımcı ----

    /// ASCII resimden ('#' dolu) küçük bir bitmap çizer; satır 0 en üsttedir.
    private static func drawBitmap(_ context: GraphicsContext, rows: [String], x: CGFloat, y: CGFloat, scale: CGFloat, color: Color) {
        let h = rows.count
        for r in 0..<h {
            let row = Array(rows[r])
            let rowY = y + CGFloat(h - 1 - r) * scale
            var col = 0
            while col < row.count {
                if row[col] != "#" { col += 1; continue }
                let start = col
                while col < row.count && row[col] == "#" { col += 1 }
                rect(context, x: x + CGFloat(start) * scale, y: rowY, w: CGFloat(col - start) * scale, h: scale, color: color)
            }
        }
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >> 8) & 0xff) / 255.0
        let b = Double(hex & 0xff) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// Basit RGB lineer interpolasyon (NesUi'nin Color.lerp'inin yerine).
    func lerp(to other: Color, t: CGFloat) -> Color {
        let a = self.resolveComponents()
        let b = other.resolveComponents()
        return Color(.sRGB,
                     red: a.r + (b.r - a.r) * Double(t),
                     green: a.g + (b.g - a.g) * Double(t),
                     blue: a.b + (b.b - a.b) * Double(t),
                     opacity: a.a + (b.a - a.a) * Double(t))
    }

    func withAlpha(_ alpha: CGFloat) -> Color {
        opacity(Double(alpha))
    }

    private func resolveComponents() -> (r: Double, g: Double, b: Double, a: Double) {
        let resolved = self.resolve(in: EnvironmentValues())
        return (Double(resolved.red), Double(resolved.green), Double(resolved.blue), Double(resolved.opacity))
    }
}
