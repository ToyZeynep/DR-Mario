//
//  PixelFont.swift
//  VirusHunt
//
//  com.rummuscan.game.PixelFont (VirusHunt Android sürümünden birebir): NES tarzı, koda gömülü
//  piksel font (5x7 glyph + 2px harf aralığı). Glyph tabloları PixelFontData.swift'te.
//  (x, y) glyph kutusunun SOL-ALT köşesidir. Metinler Java'daki gibi UTF-16 birimi başına bir
//  karakter olarak işlenir (oyunun tüm metinleri BMP içinde).
//

import Foundation

enum PixelFont {
    static let GLYPH_W = 5
    static let GLYPH_H = 7
    static let TRACKING = 2

    /// UTF-16 birimi -> 7 satır, her satır 5 bitlik maske (bit 4 = en sol piksel).
    private static let GLYPHS: [UInt16: [Int]] = {
        var map: [UInt16: [Int]] = [:]
        for entry in PixelFontData.FONT {
            let parts = entry.split(separator: " ").map(String.init)
            let c = resolveChar(parts[0])
            var rows = [Int](repeating: 0, count: GLYPH_H)
            for r in 0..<GLYPH_H {
                var mask = 0
                let row = Array(parts[r + 1])
                for col in 0..<GLYPH_W where row[col] == "#" { mask |= 1 << (GLYPH_W - 1 - col) }
                rows[r] = mask
            }
            precondition(map[c] == nil, "Glyph iki kez tanımlı: \(parts[0])")
            map[c] = rows
        }
        for table in [PixelFontData.CYRILLIC_ALIASES, PixelFontData.GREEK_ALIASES] {
            for alias in table {
                guard let target = alias.1.utf16.first, let rows = map[target] else {
                    preconditionFailure("Takma ad hedefi yok: \(alias.1)")
                }
                let key = alias.0.utf16.first!
                precondition(map[key] == nil, "Glyph iki kez tanımlı: \(alias.0)")
                map[key] = rows
            }
        }
        return map
    }()

    private static func resolveChar(_ name: String) -> UInt16 {
        if name.utf16.count == 1 { return name.utf16.first! }
        for pair in PixelFontData.NAMED where pair.0 == name { return pair.1.utf16.first! }
        preconditionFailure("Bilinmeyen glyph adi: \(name)")
    }

    /// Önce kendisi, yoksa büyük harf hâli; yoksa nil.
    private static func lookup(_ c: UInt16) -> [Int]? {
        if let rows = GLYPHS[c] { return rows }
        return GLYPHS[javaToUpper(c)]
    }

    static func rowsOf(_ c: UInt16) -> [Int]? { return lookup(c) }

    static func hasGlyph(_ c: UInt16) -> Bool { return lookup(c) != nil }

    static func advance(_ scale: Float) -> Float { return advance(scale, Float(TRACKING) * scale) }

    static func advance(_ scale: Float, _ spacing: Float) -> Float { return Float(GLYPH_W) * scale + spacing }

    static func width(_ text: String, _ scale: Float) -> Float { return width(text, scale, Float(TRACKING) * scale) }

    static func width(_ text: String, _ scale: Float, _ spacing: Float) -> Float {
        let n = text.utf16.count
        if n == 0 { return 0 }
        return Float(n) * advance(scale, spacing) - spacing
    }

    static func height(_ scale: Float) -> Float { return Float(GLYPH_H) * scale }

    static func draw(_ batch: SpriteBatch, _ white: Texture?, _ text: String, _ x: Float, _ y: Float, _ scale: Float, _ color: Color) {
        draw(batch, white, text, x, y, scale, Float(TRACKING) * scale, color)
    }

    static func draw(_ batch: SpriteBatch, _ white: Texture?, _ text: String, _ x: Float, _ y: Float,
                     _ scale: Float, _ spacing: Float, _ color: Color) {
        batch.setColor(color)
        var penX = x
        for c in text.utf16 {
            drawGlyph(batch, white, c, penX, y, scale)
            penX += advance(scale, spacing)
        }
        batch.setColor(Color.WHITE)
    }

    static func drawCentered(_ batch: SpriteBatch, _ white: Texture?, _ text: String, _ centerX: Float, _ y: Float, _ scale: Float, _ color: Color) {
        drawCentered(batch, white, text, centerX, y, scale, Float(TRACKING) * scale, color)
    }

    static func drawCentered(_ batch: SpriteBatch, _ white: Texture?, _ text: String, _ centerX: Float, _ y: Float,
                             _ scale: Float, _ spacing: Float, _ color: Color) {
        draw(batch, white, text, centerX - width(text, scale, spacing) / 2, y, scale, spacing, color)
    }

    /// Önce 8 yöne kaydırılmış kenarlık rengiyle, sonra üstüne asıl renkle çizer.
    static func drawOutlined(_ batch: SpriteBatch, _ white: Texture?, _ text: String, _ x: Float, _ y: Float,
                             _ scale: Float, _ spacing: Float, _ color: Color, _ outline: Color) {
        let o = scale
        for dx in -1...1 {
            for dy in -1...1 {
                if dx == 0 && dy == 0 { continue }
                draw(batch, white, text, x + Float(dx) * o, y + Float(dy) * o, scale, spacing, outline)
            }
        }
        draw(batch, white, text, x, y, scale, spacing, color)
    }

    static func drawCenteredOutlined(_ batch: SpriteBatch, _ white: Texture?, _ text: String, _ centerX: Float, _ y: Float,
                                     _ scale: Float, _ spacing: Float, _ color: Color, _ outline: Color) {
        drawOutlined(batch, white, text, centerX - width(text, scale, spacing) / 2, y, scale, spacing, color, outline)
    }

    private static func drawGlyph(_ batch: SpriteBatch, _ white: Texture?, _ c: UInt16, _ x: Float, _ y: Float, _ scale: Float) {
        guard let rows = lookup(c) else { return } // tanımsız karakter: boşluk gibi davran

        for r in 0..<GLYPH_H {
            let mask = rows[r]
            if mask == 0 { continue }
            let rowY = y + Float(GLYPH_H - 1 - r) * scale
            var col = 0
            while col < GLYPH_W {
                if (mask & (1 << (GLYPH_W - 1 - col))) == 0 { col += 1; continue }
                let start = col
                while col < GLYPH_W && (mask & (1 << (GLYPH_W - 1 - col))) != 0 { col += 1 }
                batch.draw(white, x + Float(start) * scale, rowY, Float(col - start) * scale, scale)
            }
        }
    }
}
