//
//  PixelFont.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.PixelFont.
//
//  NES tarzı, koda gömülü piksel font (5x7 glyph + 2px harf aralığı = 7px ilerleme).
//  Harici bir .fnt/.png dosyasına ihtiyaç duymaz; her glyph aşağıdaki tabloda ASCII resim
//  olarak tanımlıdır ('#' = dolu piksel). Aynı satırdaki ardışık dolu pikseller tek bir
//  dikdörtgende birleştirilir (NesUI.rect üzerinden), böylece tipik bir metin birkaç
//  fill çağrısına iner.
//
//  Koordinat sistemi: verilen (x, y) glyph kutusunun SOL-ALT köşesidir (NES y-up); metin
//  yukarı doğru GLYPH_H * scale kadar yer kaplar. Gerçek y-flip NesUI.rect içinde olur.
//

import CoreGraphics
import SwiftUI

enum PixelFont {
    static let glyphW = 5
    static let glyphH = 7
    /// İki glyph kutusu arasındaki boşluk (scale ile çarpılır). NES fontu 8px ilerlerdi; 5+2=7 buna yakın.
    static let tracking: CGFloat = 2

    private static let font: [String] = [
        "SPACE ..... ..... ..... ..... ..... ..... .....",
        "A .###. #...# #...# ##### #...# #...# #...#",
        "B ####. #...# #...# ####. #...# #...# ####.",
        "C .###. #...# #.... #.... #.... #...# .###.",
        "D ####. #...# #...# #...# #...# #...# ####.",
        "E ##### #.... #.... ####. #.... #.... #####",
        "F ##### #.... #.... ####. #.... #.... #....",
        "G .###. #...# #.... #.### #...# #...# .###.",
        "H #...# #...# #...# ##### #...# #...# #...#",
        "I ##### ..#.. ..#.. ..#.. ..#.. ..#.. #####",
        "J ..### ...#. ...#. ...#. ...#. #..#. .##..",
        "K #...# #..#. #.#.. ##... #.#.. #..#. #...#",
        "L #.... #.... #.... #.... #.... #.... #####",
        "M #...# ##.## #.#.# #.#.# #...# #...# #...#",
        "N #...# ##..# ##..# #.#.# #..## #..## #...#",
        "O .###. #...# #...# #...# #...# #...# .###.",
        "P ####. #...# #...# ####. #.... #.... #....",
        "Q .###. #...# #...# #...# #.#.# #..#. .##.#",
        "R ####. #...# #...# ####. #.#.. #..#. #...#",
        "S .#### #.... #.... .###. ....# ....# ####.",
        "T ##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#..",
        "U #...# #...# #...# #...# #...# #...# .###.",
        "V #...# #...# #...# #...# #...# .#.#. ..#..",
        "W #...# #...# #...# #.#.# #.#.# ##.## #...#",
        "X #...# #...# .#.#. ..#.. .#.#. #...# #...#",
        "Y #...# #...# .#.#. ..#.. ..#.. ..#.. ..#..",
        "Z ##### ....# ...#. ..#.. .#... #.... #####",
        "0 .###. #..## #..## #.#.# ##..# ##..# .###.",
        "1 ..#.. .##.. ..#.. ..#.. ..#.. ..#.. .###.",
        "2 .###. #...# ....# ...#. ..#.. .#... #####",
        "3 ##### ...#. ..##. ....# ....# #...# .###.",
        "4 ...#. ..##. .#.#. #..#. ##### ...#. ...#.",
        "5 ##### #.... ####. ....# ....# #...# .###.",
        "6 ..##. .#... #.... ####. #...# #...# .###.",
        "7 ##### ....# ...#. ..#.. .#... .#... .#...",
        "8 .###. #...# #...# .###. #...# #...# .###.",
        "9 .###. #...# #...# .#### ....# ...#. .##..",
        "a ..... ..... .###. ....# .#### #...# .####",
        "b #.... #.... ####. #...# #...# #...# ####.",
        "c ..... ..... .###. #.... #.... #.... .###.",
        "d ....# ....# .#### #...# #...# #...# .####",
        "e ..... ..... .###. #...# ##### #.... .###.",
        "f ..##. .#..# .#... ###.. .#... .#... .#...",
        "g ..... .#### #...# #...# .#### ....# .###.",
        "h #.... #.... ####. #...# #...# #...# #...#",
        "i ..#.. ..... .##.. ..#.. ..#.. ..#.. .###.",
        "j ...#. ..... ...#. ...#. ...#. #..#. .##..",
        "k #.... #.... #..#. #.#.. ##... #.#.. #..#.",
        "l .##.. ..#.. ..#.. ..#.. ..#.. ..#.. .###.",
        "m ..... ..... ##.#. #.#.# #.#.# #.#.# #.#.#",
        "n ..... ..... ####. #...# #...# #...# #...#",
        "o ..... ..... .###. #...# #...# #...# .###.",
        "p ..... ####. #...# #...# ####. #.... #....",
        "q ..... .#### #...# #...# .#### ....# ....#",
        "r ..... ..... #.##. ##..# #.... #.... #....",
        "s ..... ..... .#### #.... .###. ....# ####.",
        "t .#... .#... ###.. .#... .#... .#..# ..##.",
        "u ..... ..... #...# #...# #...# #..## .##.#",
        "v ..... ..... #...# #...# #...# .#.#. ..#..",
        "w ..... ..... #...# #.#.# #.#.# #.#.# .#.#.",
        "x ..... ..... #...# .#.#. ..#.. .#.#. #...#",
        "y ..... #...# #...# #...# .#### ....# .###.",
        "z ..... ..... ##### ...#. ..#.. .#... #####",
        "DOT ..... ..... ..... ..... ..... .##.. .##..",
        "COMMA ..... ..... ..... ..... .##.. .##.. .#...",
        "COLON ..... .##.. .##.. ..... .##.. .##.. .....",
        "DASH ..... ..... ..... ##### ..... ..... .....",
        "UNDER ..... ..... ..... ..... ..... ..... #####",
        "SLASH ....# ....# ...#. ..#.. .#... #.... #....",
        "BANG ..#.. ..#.. ..#.. ..#.. ..#.. ..... ..#..",
        "QUEST .###. #...# ....# ...#. ..#.. ..... ..#..",
        "LPAREN ...#. ..#.. .#... .#... .#... ..#.. ...#.",
        "RPAREN .#... ..#.. ...#. ...#. ...#. ..#.. .#...",
        "PLUS ..... ..#.. ..#.. ##### ..#.. ..#.. .....",
        "EQ ..... ..... ##### ..... ##### ..... .....",
        "LT ...#. ..#.. .#... #.... .#... ..#.. ...#.",
        "GT .#... ..#.. ...#. ....# ...#. ..#.. .#...",
        "STAR ..... #.#.# .###. ##### .###. #.#.# .....",
        "PCT ##..# ##..# ...#. ..#.. .#... #..## #..##",
        "QUOTE ..#.. ..#.. ..... ..... ..... ..... .....",
        "COPY .###. #...# #.##. #.#.. #.##. #...# .###.",
    ]

    /// Çok karakterli glyph adları -> temsil ettikleri karakter.
    private static let named: [String: Character] = [
        "SPACE": " ", "DOT": ".", "COMMA": ",", "COLON": ":", "DASH": "-",
        "UNDER": "_", "SLASH": "/", "BANG": "!", "QUEST": "?", "LPAREN": "(",
        "RPAREN": ")", "PLUS": "+", "EQ": "=", "LT": "<", "GT": ">",
        "STAR": "*", "PCT": "%", "QUOTE": "'", "COPY": "@",
    ]

    /// char -> 7 satır, her satır 5 bitlik maske (bit 4 = en sol piksel).
    private static let glyphs: [Character: [Int]] = {
        var map: [Character: [Int]] = [:]
        for entry in font {
            let parts = entry.split(separator: " ").map(String.init)
            let c = resolveChar(parts[0])

            var rows = [Int](repeating: 0, count: glyphH)
            for r in 0..<glyphH {
                var mask = 0
                let row = Array(parts[r + 1])
                for col in 0..<glyphW {
                    if row[col] == "#" { mask |= 1 << (glyphW - 1 - col) }
                }
                rows[r] = mask
            }
            map[c] = rows
        }
        return map
    }()

    private static func resolveChar(_ name: String) -> Character {
        if name.count == 1 { return name.first! }
        return named[name]!
    }

    /// Bir karakterin kapladığı yatay ilerleme (glyph + varsayılan harf arası boşluk).
    static func advance(scale: CGFloat) -> CGFloat {
        advance(scale: scale, spacing: tracking * scale)
    }

    /// Harf arası boşluğun elle verildiği hâli (NES'in 8px ilerlemesi için scale=1, spacing=3).
    static func advance(scale: CGFloat, spacing: CGFloat) -> CGFloat {
        CGFloat(glyphW) * scale + spacing
    }

    /// Metnin toplam genişliği (son harften sonraki boşluk sayılmaz).
    static func width(_ text: String, scale: CGFloat) -> CGFloat {
        width(text, scale: scale, spacing: tracking * scale)
    }

    static func width(_ text: String, scale: CGFloat, spacing: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return CGFloat(text.count) * advance(scale: scale, spacing: spacing) - spacing
    }

    static func height(scale: CGFloat) -> CGFloat {
        CGFloat(glyphH) * scale
    }

    /// Metni (x, y) sol-alt köşesinden başlayarak çizer (NES y-up koordinatı).
    static func draw(_ context: GraphicsContext, text: String, x: CGFloat, y: CGFloat, scale: CGFloat, color: Color) {
        draw(context, text: text, x: x, y: y, scale: scale, spacing: tracking * scale, color: color)
    }

    static func draw(_ context: GraphicsContext, text: String, x: CGFloat, y: CGFloat,
                      scale: CGFloat, spacing: CGFloat, color: Color) {
        var penX = x
        for ch in text {
            drawGlyph(context, char: ch, x: penX, y: y, scale: scale, color: color)
            penX += advance(scale: scale, spacing: spacing)
        }
    }

    /// Metni verilen merkez X'e göre ortalar.
    static func drawCentered(_ context: GraphicsContext, text: String, centerX: CGFloat, y: CGFloat,
                              scale: CGFloat, color: Color) {
        drawCentered(context, text: text, centerX: centerX, y: y, scale: scale, spacing: tracking * scale, color: color)
    }

    static func drawCentered(_ context: GraphicsContext, text: String, centerX: CGFloat, y: CGFloat,
                              scale: CGFloat, spacing: CGFloat, color: Color) {
        draw(context, text: text, x: centerX - width(text, scale: scale, spacing: spacing) / 2, y: y,
             scale: scale, spacing: spacing, color: color)
    }

    /// Önce 8 yöne kaydırılmış kenarlık rengiyle, sonra üstüne asıl renkle çizer (NES logo/başlık hissi).
    static func drawOutlined(_ context: GraphicsContext, text: String, x: CGFloat, y: CGFloat,
                              scale: CGFloat, spacing: CGFloat, color: Color, outline: Color) {
        let o = scale
        for dx: CGFloat in [-1, 0, 1] {
            for dy: CGFloat in [-1, 0, 1] {
                if dx == 0 && dy == 0 { continue }
                draw(context, text: text, x: x + dx * o, y: y + dy * o, scale: scale, spacing: spacing, color: outline)
            }
        }
        draw(context, text: text, x: x, y: y, scale: scale, spacing: spacing, color: color)
    }

    static func drawCenteredOutlined(_ context: GraphicsContext, text: String, centerX: CGFloat, y: CGFloat,
                                      scale: CGFloat, spacing: CGFloat, color: Color, outline: Color) {
        drawOutlined(context, text: text, x: centerX - width(text, scale: scale, spacing: spacing) / 2, y: y,
                     scale: scale, spacing: spacing, color: color, outline: outline)
    }

    private static func drawGlyph(_ context: GraphicsContext, char: Character, x: CGFloat, y: CGFloat,
                                   scale: CGFloat, color: Color) {
        let lookupChar = glyphs[char] != nil ? char : Character(char.uppercased())
        guard let rows = glyphs[lookupChar] else { return } // tanımsız karakter: boşluk gibi davran

        for r in 0..<glyphH {
            let mask = rows[r]
            if mask == 0 { continue }
            let rowY = y + CGFloat(glyphH - 1 - r) * scale
            // Ardışık dolu pikselleri tek dikdörtgende birleştir.
            var col = 0
            while col < glyphW {
                if (mask & (1 << (glyphW - 1 - col))) == 0 { col += 1; continue }
                let start = col
                while col < glyphW && (mask & (1 << (glyphW - 1 - col))) != 0 { col += 1 }
                NesUI.rect(context, x: x + CGFloat(start) * scale, y: rowY,
                           w: CGFloat(col - start) * scale, h: scale, color: color)
            }
        }
    }
}
