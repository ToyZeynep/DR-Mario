//
//  TouchControls.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.TouchControls.
//
//  Oyun ekranının dokunmatik kontrolleri: solda sol/sağ/aşağı okları, sağda döndürme tuşu.
//  Yuvarlak, "cam" görünümlü butonlar: dikey gradyanlı gövde, ince beyaz iç kenar, dışında
//  renkli ince ışıma halkası, üstte parlama ve kalın piksel chevron ikonlar. Basılıyken buton
//  hafifçe küçülür, gövdesi vurgu rengine boyanır ve halkası parlar; bu geçiş update(delta:)
//  ile yumuşatılır.
//
//  NOT: Java sürümünde her butonun ÇİZİM alanı (daire) ile DOKUNMA alanı (dikdörtgen) ayrıydı
//  ve libGDX'in tek input-processor'ünde manuel çoklu-parmak takibi (polling) gerekiyordu.
//  SwiftUI'da bunun yerine her buton kendi DragGesture'ına sahip ayrı bir overlay view'dür
//  (bkz. SinglePlayerScreenView) — bu, aynı anda birden fazla dokunuşu bedavaya getirir.
//  Bu dosya sadece ÇİZİM ve YERLEŞİM (hit-rect hesaplama) mantığını birebir taşır; hit-rect'ler
//  overlay view'ların konumlandırılması için kullanılır.
//

import SwiftUI

final class TouchControls {
    static let left = 0, right = 1, down = 2, rotate = 3
    private static let count = 4

    // ---- Görünüm paleti ----
    private static let shadow      = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.38)
    /// Butonu zeminden ayıran koyu dış kontur.
    private static let contour     = Color(.sRGB, red: 0.02, green: 0.04, blue: 0.07, opacity: 0.75)
    private static let bodyBottom  = Color(.sRGB, red: 0.07, green: 0.09, blue: 0.15, opacity: 0.94)
    private static let bodyTop     = Color(.sRGB, red: 0.36, green: 0.43, blue: 0.56, opacity: 0.90)
    private static let rim         = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)
    private static let gloss       = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.20)
    private static let icon        = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)
    /// Yön tuşlarının vurgu rengi (NES paletindeki camgöbeği).
    private static let moveAccent = Color(hex: 0x3cbcfc)
    /// Döndürme tuşunun vurgu rengi.
    private static let rotAccent  = Color(hex: 0xf878d8)

    private static let pressSpeed: CGFloat = 16

    private var cx = [CGFloat](repeating: 0, count: count)
    private var cy = [CGFloat](repeating: 0, count: count)
    private var radius = [CGFloat](repeating: 0, count: count)
    private(set) var hit = [CGRect](repeating: .zero, count: count)
    private var pressed = [Bool](repeating: false, count: count)
    private var anim = [CGFloat](repeating: 0, count: count)

    /// Bir butonun dokunma dikdörtgeni (içerik/dünya koordinatında).
    func hitArea(_ button: Int) -> CGRect { hit[button] }

    func setPressed(_ button: Int, _ value: Bool) {
        pressed[button] = value
    }

    func releaseAll() {
        for i in 0..<TouchControls.count { pressed[i] = false }
    }

    /// Basma animasyonunu ilerletir; her karede gerçek delta ile çağrılmalı.
    func update(delta: Double) {
        for i in 0..<TouchControls.count {
            let target: CGFloat = pressed[i] ? 1 : 0
            let k = min(1, CGFloat(delta) * TouchControls.pressSpeed)
            anim[i] += (target - anim[i]) * k
        }
    }

    // ---- Yerleşim ----

    /// Butonlar öncelikle HUD panolarının dışında kalan kenar boşluğuna yerleşir (solda yön
    /// tuşları, sağda döndürme). Ekran 4:3'e yakınsa böyle bir şerit kalmaz; o durumda butonlar
    /// içerik alanının alt köşelerine iner.
    func layout(ox: CGFloat, worldW: CGFloat) {
        // Sol şerit: ekranın soluyla büyütecin sol kenarı arası.
        let leftZone = ox + GameConfig.lensPanelX - 2
        // Sağ şerit: LEVEL panosunun sağ kenarıyla ekranın sağı arası.
        let rightZone = worldW - (ox + GameConfig.levelPanelX + GameConfig.levelPanelW) - 2

        if min(leftZone, rightZone) >= 46 {
            // Geniş ekran (16:9 ve üzeri): klasik "T" dizilişi, tamamen kenar boşluğunda.
            let d = clamp(leftZone / 2.5 - 1.6, 18, 30)
            let r = d / 2
            let padCx = leftZone / 2
            let rowY: CGFloat = 100

            place(TouchControls.left, centerX: padCx - 0.75 * d, centerY: rowY, r: r, hitHalfW: 0.75 * d, hitHalfH: 1.10 * d)
            place(TouchControls.right, centerX: padCx + 0.75 * d, centerY: rowY, r: r, hitHalfW: 0.75 * d, hitHalfH: 1.10 * d)
            place(TouchControls.down, centerX: padCx, centerY: rowY - 2.2 * d, r: r,
                  hitHalfW: min(0.95 * d, padCx - 2), hitHalfH: 1.10 * d)

            let rd = clamp(rightZone / 2.2, 30, 40)
            place(TouchControls.rotate, centerX: worldW - rightZone / 2, centerY: 86, r: rd / 2, hitHalfW: 0.95 * rd, hitHalfH: 0.95 * rd)
        } else {
            // Dar ekran (4:3 / 16:10): şişe neredeyse tüm yüksekliği kapladığı için
            // butonlar şişenin solundaki/sağındaki boşluğun ALT kısmına, tek sıra
            // hâlinde (sol - aşağı - sağ) yerleşir.
            let zone = ox + GameConfig.bottleFrameX - 4 // şişeye kadar serbest genişlik
            let d: CGFloat = 20, r = d / 2
            let y: CGFloat = 30
            let hw = min(0.75 * d, zone / 6)
            let mid = zone / 2

            place(TouchControls.left, centerX: mid - 2 * hw, centerY: y, r: r, hitHalfW: hw, hitHalfH: 1.3 * d)
            place(TouchControls.down, centerX: mid, centerY: y, r: r, hitHalfW: hw, hitHalfH: 1.3 * d)
            place(TouchControls.right, centerX: mid + 2 * hw, centerY: y, r: r, hitHalfW: hw, hitHalfH: 1.3 * d)

            let rd: CGFloat = 26
            place(TouchControls.rotate, centerX: worldW - mid, centerY: y, r: rd / 2,
                  hitHalfW: min(rd, zone / 2 - 2), hitHalfH: 1.3 * rd)
        }
        clampHitAreas(worldW: worldW)
    }

    private func place(_ i: Int, centerX: CGFloat, centerY: CGFloat, r: CGFloat, hitHalfW: CGFloat, hitHalfH: CGFloat) {
        cx[i] = centerX
        cy[i] = centerY
        radius[i] = r
        hit[i] = CGRect(x: centerX - hitHalfW, y: centerY - hitHalfH, width: hitHalfW * 2, height: hitHalfH * 2)
    }

    /// Ekran dışına taşan dokunma alanı işe yaramaz; kırpıp içeri alıyoruz.
    private func clampHitAreas(worldW: CGFloat) {
        for i in 0..<TouchControls.count {
            let r = hit[i]
            let x1 = max(0, r.minX)
            let y1 = max(0, r.minY)
            let x2 = min(worldW, r.maxX)
            let y2 = min(GameConfig.worldHeight, r.maxY)
            hit[i] = CGRect(x: x1, y: y1, width: max(0, x2 - x1), height: max(0, y2 - y1))
        }
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        max(lo, min(hi, v))
    }

    // ---- Çizim ----

    func draw(_ context: GraphicsContext) {
        drawBody(context, TouchControls.left, TouchControls.moveAccent)
        drawBody(context, TouchControls.right, TouchControls.moveAccent)
        drawBody(context, TouchControls.down, TouchControls.moveAccent)
        drawBody(context, TouchControls.rotate, TouchControls.rotAccent)

        drawChevron(context, TouchControls.left, NesUI.dirLeft)
        drawChevron(context, TouchControls.right, NesUI.dirRight)
        drawChevron(context, TouchControls.down, NesUI.dirDown)
        drawRotateIcon(context)
    }

    private func drawBody(_ context: GraphicsContext, _ i: Int, _ accent: Color) {
        let a = anim[i]
        let r = radius[i] * (1 - 0.05 * a)
        let x = cx[i], y = cy[i]

        // Zemine düşen yumuşak gölge.
        NesUI.circle(context, cx: x, cy: y - 2, r: r + 2.5, color: TouchControls.shadow)
        // Koyu kontur: butonu yeşil dama zeminden kesin olarak ayırır.
        NesUI.circle(context, cx: x, cy: y, r: r + 1.6, color: TouchControls.contour)
        // Gövde: koyu camdan açık cama dikey gradyan.
        NesUI.circleGradient(context, cx: x, cy: y, r: r, bottom: TouchControls.bodyBottom, top: TouchControls.bodyTop)

        // Basılıyken gövde vurgu rengine boyanır (accent'in kendisi, sadece alpha değişir).
        if a > 0.01 {
            let solidA = accent.opacity(Double(0.18 * a))
            let solidB = accent.opacity(Double(0.85 * a))
            NesUI.circleGradient(context, cx: x, cy: y, r: r, bottom: solidA, top: solidB)
        }

        // Tek net kenar çizgisi: normalde beyaz, basılıyken vurgu rengine kayar.
        let rimColor = TouchControls.rim.lerp(to: accent, t: a).opacity(Double(0.55 + 0.45 * a))
        NesUI.ring(context, cx: x, cy: y, r: r, thickness: 1.5, color: rimColor)

        // Üst parlama.
        NesUI.ellipse(context, centerX: x, centerY: y + r * 0.46, rx: r * 0.52, ry: r * 0.16, color: TouchControls.gloss)
    }

    private func drawChevron(_ context: GraphicsContext, _ i: Int, _ dir: Int) {
        let r = radius[i] * (1 - 0.05 * anim[i])
        // Chevron dikeyde +-size kadar yer kaplar; gövdenin dışına taşmaması için
        // size en fazla yarıçapın yarısı kadar olabilir.
        let size = r * 0.55
        let thickness = max(2, r * 0.26)
        var x = cx[i]
        var y = cy[i]
        // Chevron'un görsel ağırlık merkezi tepe noktasına kayar; hafifçe geri itiyoruz.
        if dir == NesUI.dirLeft { x += size * 0.14 }
        else if dir == NesUI.dirRight { x -= size * 0.14 }
        else if dir == NesUI.dirDown { y += size * 0.14 }
        NesUI.chevron(context, cx: x, cy: y, size: size, thickness: thickness, dir: dir, color: TouchControls.icon)
    }

    /// Sade, ince bir dairesel ok: hapı döndür.
    private func drawRotateIcon(_ context: GraphicsContext) {
        let r = radius[TouchControls.rotate] * (1 - 0.05 * anim[TouchControls.rotate])
        let x = cx[TouchControls.rotate], y = cy[TouchControls.rotate]

        let ar = r * 0.52                    // yay yarıçapı
        let t = max(1.8, r * 0.14)           // yay kalınlığı
        let startDeg: CGFloat = 50, endDeg: CGFloat = -230 // azalan açı = saat yönü

        NesUI.arc(context, cx: x, cy: y, r: ar, thickness: t, startDeg: startDeg, endDeg: endDeg, color: TouchControls.icon)

        // Yayın bittiği noktaya teğet bakan ok ucu.
        let end = endDeg * .pi / 180
        let ex = x + cos(end) * ar
        let ey = y + sin(end) * ar
        let tx = sin(end), ty = -cos(end) // saat yönü teğeti
        let nx = -ty, ny = tx
        let hs = t * 1.55
        NesUI.filledTriangle(context,
            x1: ex + tx * hs * 1.9, y1: ey + ty * hs * 1.9,
            x2: ex + nx * hs, y2: ey + ny * hs,
            x3: ex - nx * hs, y3: ey - ny * hs, color: TouchControls.icon)
    }
}
