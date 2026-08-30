//
//  Assets.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.Assets.
//
//  Tüm görselleri Assets.xcassets'ten merkezi olarak yükler. Bir imageset eksikse
//  (var olan bir yapımcı iş akışı: önce kod, sonra görsel) o alan nil kalır ve renderer
//  bunun yerine geometrik şekillerle (eski davranış) çizmeye devam eder.
//

import SwiftUI
import CoreGraphics
import ImageIO

#if canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage
#endif

final class Assets {
    let virusRed: Image?, virusYellow: Image?, virusBlue: Image?
    let pillRed: Image?, pillYellow: Image?, pillBlue: Image?
    let notepadPanel: Image?
    let doctor: Image?
    let microscopeBg: Image?

    /// bottle_frame.png'nin dört dikey dilimi (boyun/omuz/gövde/taban), GameConfig'teki
    /// piksel sınırlarından önceden kırpılmış. drawBottle bunları düz birer görsel gibi
    /// hedef dikdörtgene gerer (libGDX'in batch.draw(tex, ..., srcY, srcH,...) karşılığı).
    let bottleNeckSlice: Image?
    let bottleShoulderSlice: Image?
    let bottleBodySlice: Image?
    let bottleFloorSlice: Image?
    /// bottle_frame.png tam görseli var mı? (dilimler başarıyla kırpıldıysa true)
    var hasBottleFrame: Bool { bottleBodySlice != nil }

    /// Şişenin İÇ boşluğunun satır satır ölçülmüş genişliği (bkz. measureBottleInterior).
    /// Dizinin uzunluğu bottleSamples, indeks 0 = şişenin EN ALTI, son indeks = en üstü
    /// (ağzın ucu). Her eleman (sol, sağ) olup 0..1 aralığında, çerçeve genişliğine göre
    /// normalize edilmiştir; o yükseklikte iç boşluk yoksa nil olur.
    let bottleInterior: [(left: CGFloat, right: CGFloat)?]?

    static let bottleSamples = 256

    init() {
        virusRed = Assets.loadImage("virus_red")
        virusYellow = Assets.loadImage("virus_yellow")
        virusBlue = Assets.loadImage("virus_blue")

        pillRed = Assets.loadImage("pill_red")
        pillYellow = Assets.loadImage("pill_yellow")
        pillBlue = Assets.loadImage("pill_blue")

        notepadPanel = Assets.loadImage("notepad_panel")
        doctor = Assets.loadImage("doctor")
        microscopeBg = Assets.loadImage("microscope_bg")

        let bottleCG = Assets.loadCGImage("bottle_frame")
        if let cg = bottleCG {
            let h = CGFloat(cg.height)
            bottleFloorSlice = Assets.slice(cg, top: GameConfig.bottleSeamFloor, bottom: GameConfig.bottleImgH)
            bottleBodySlice = Assets.slice(cg, top: GameConfig.bottleSeamBody, bottom: GameConfig.bottleSeamFloor)
            bottleShoulderSlice = Assets.slice(cg, top: GameConfig.bottleSeamNeck, bottom: GameConfig.bottleSeamBody)
            bottleNeckSlice = Assets.slice(cg, top: 0, bottom: GameConfig.bottleSeamNeck)
            bottleInterior = Assets.measureBottleInterior(cg, imageHeight: h)
        } else {
            bottleFloorSlice = nil
            bottleBodySlice = nil
            bottleShoulderSlice = nil
            bottleNeckSlice = nil
            bottleInterior = nil
        }
    }

    func virusFor(_ color: CapsuleColor) -> Image? {
        switch color {
        case .red: return virusRed
        case .yellow: return virusYellow
        case .blue: return virusBlue
        }
    }

    func pillFor(_ color: CapsuleColor) -> Image? {
        switch color {
        case .red: return pillRed
        case .yellow: return pillYellow
        case .blue: return pillBlue
        }
    }

    // ---- Yükleme yardımcıları ----

    private static func loadPlatformImage(_ name: String) -> PlatformImage? {
        PlatformImage(named: name)
    }

    private static func loadImage(_ name: String) -> Image? {
        guard let cg = loadCGImage(name) else { return nil }
        return Image(decorative: cg, scale: 1)
    }

    private static func loadCGImage(_ name: String) -> CGImage? {
        guard let platformImage = loadPlatformImage(name) else { return nil }
        #if canImport(UIKit)
        return platformImage.cgImage
        #elseif canImport(AppKit)
        var rect = CGRect(origin: .zero, size: platformImage.size)
        return platformImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #endif
    }

    /// Görselin [top, bottom) piksel aralığını (üstten sayılır) kırpar ve SwiftUI Image'a çevirir.
    private static func slice(_ cgImage: CGImage, top: CGFloat, bottom: CGFloat) -> Image? {
        let rect = CGRect(x: 0, y: top, width: CGFloat(cgImage.width), height: bottom - top)
        guard let cropped = cgImage.cropping(to: rect) else { return nil }
        return Image(decorative: cropped, scale: 1)
    }

    /// Şişenin iç boşluğunu piksellerden ölçer: her örnek satırında soldan ilk, sağdan son
    /// OPAK piksel şişenin dış hattıdır; bu ikisinin arasında kalan ilk/son SAYDAM piksel de iç
    /// boşluğun kenarlarıdır. Boğaz bölgesinde iki ayrı duvar olduğu için bu ölçüm orada da doğru
    /// çalışır (iki duvarın arası = boğazın içi).
    ///
    /// Kenarlar 1 piksel dışa taşırılır ki dolgu ile cam duvar arasında ince bir boşluk çizgisi
    /// kalmasın.
    private static func measureBottleInterior(_ cgImage: CGImage, imageHeight: CGFloat) -> [(left: CGFloat, right: CGFloat)?]? {
        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else { return nil }

        // Bilinen bir formata (RGBA8888, alpha son bayt) yeniden çiz; buffer'ı TEPEDEN
        // BAŞLAYACAK şekilde (Pixmap/PNG'nin doğal sırasıyla aynı) doldurmak için CTM flip edilir.
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = buffer.withUnsafeMutableBytes({ ptr -> CGContext? in
            CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8,
                      bytesPerRow: w * 4, space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        func isOpaque(_ x: Int, _ y: Int) -> Bool {
            let offset = y * w * 4 + x * 4
            return buffer[offset + 3] > 40 // RGBA, son bayt alpha
        }

        var spans = [(left: CGFloat, right: CGFloat)?](repeating: nil, count: bottleSamples)
        for i in 0..<bottleSamples {
            // i = 0 -> görselin en alt satırı, i = son -> en üst satırı
            let y = h - 1 - Int((Double(i) * Double(h - 1) / Double(bottleSamples - 1)).rounded())

            var outerLeft = -1, outerRight = -1
            for x in 0..<w where isOpaque(x, y) { outerLeft = x; break }
            var x = w - 1
            while x >= 0 { if isOpaque(x, y) { outerRight = x; break }; x -= 1 }
            if outerLeft < 0 || outerRight - outerLeft < 2 { continue }

            var innerLeft = -1, innerRight = -1
            for xi in outerLeft...outerRight where !isOpaque(xi, y) { innerLeft = xi; break }
            x = outerRight
            while x >= outerLeft { if !isOpaque(x, y) { innerRight = x; break }; x -= 1 }
            if innerLeft < 0 || innerRight < innerLeft { continue }

            spans[i] = (CGFloat(innerLeft - 1) / CGFloat(w), CGFloat(innerRight + 2) / CGFloat(w))
        }
        return spans
    }
}
