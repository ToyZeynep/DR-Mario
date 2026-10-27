//
//  TouchControls.swift
//  VirusHunt
//
//  com.rummuscan.game.TouchControls + VsBoardsRenderer (VirusHunt Android sürümünden birebir).
//

import Foundation

/// Oyun ekranının dokunmatik kontrolleri: solda sol/sağ/aşağı okları, sağda döndürme tuşu.
/// Her butonun ÇİZİM alanı (daire) ile DOKUNMA alanı (dikdörtgen) ayrıdır.
final class TouchControls {

    static let LEFT = 0, RIGHT = 1, DOWN = 2, ROTATE = 3
    private static let COUNT = 4

    private static let SHADOW      = Color(0, 0, 0, 0.38)
    private static let CONTOUR     = Color(0.02, 0.04, 0.07, 0.75)
    private static let BODY_BOTTOM = Color(0.07, 0.09, 0.15, 0.94)
    private static let BODY_TOP    = Color(0.36, 0.43, 0.56, 0.90)
    private static let RIM         = Color(1, 1, 1, 1)
    private static let GLOSS       = Color(1, 1, 1, 0.20)
    private static let ICON        = Color(1, 1, 1, 1)
    private static let ICON_SHADOW = Color(0, 0, 0, 0.45)
    private static let MOVE_ACCENT = Color(0x3cbcfcff)
    private static let ROT_ACCENT  = Color(0xf878d8ff)

    private static let PRESS_SPEED: Float = 16

    private var cx = [Float](repeating: 0, count: COUNT)
    private var cy = [Float](repeating: 0, count: COUNT)
    private var radius = [Float](repeating: 0, count: COUNT)
    private var hit = [Rectangle](repeating: Rectangle(), count: COUNT)
    private var pressed = [Bool](repeating: false, count: COUNT)
    private var anim = [Float](repeating: 0, count: COUNT)

    private var tintA = Color()
    private var tintB = Color()

    init() {}

    func hitArea(_ button: Int) -> Rectangle { return hit[button] }

    func centerX(_ button: Int) -> Float { return cx[button] }
    func centerY(_ button: Int) -> Float { return cy[button] }
    func radius(_ button: Int) -> Float { return radius[button] }

    func setPressed(_ button: Int, _ value: Bool) { pressed[button] = value }

    func releaseAll() {
        for i in 0..<TouchControls.COUNT { pressed[i] = false }
    }

    func update(_ delta: Float) {
        for i in 0..<TouchControls.COUNT {
            let target: Float = pressed[i] ? 1 : 0
            let k = min(1, delta * TouchControls.PRESS_SPEED)
            anim[i] += (target - anim[i]) * k
        }
    }

    // ---- Yerleşim ----

    private var rotateMinX: Float = 0

    private static let MIN_SIDE_ZONE: Float = 40
    private static let MAX_SIDE_ZONE: Float = 100

    /// Tek oyunculu ekran: butonlar HUD panolarının dışında kalan kenar boşluğuna yerleşir.
    func layout(_ ox: Float, _ worldW: Float) {
        rotateMinX = ox + SinglePlayerScreen.PAUSE_BTN_CX + SinglePlayerScreen.PAUSE_BTN_R + 2
        let leftZone = ox + GameConfig.LENS_PANEL_X - 2
        let rightZone = worldW - (ox + GameConfig.LEVEL_PANEL_X + GameConfig.LEVEL_PANEL_W) - 2
        let bottomZone = ox + GameConfig.BOTTLE_FRAME_X - 4
        layout(leftZone, rightZone, bottomZone, worldW)
    }

    /// VS ekranları (CPU / online): serbest şerit ekran kenarıyla ŞİŞE arasındaki boşluk.
    func layoutVs(_ ox: Float, _ worldW: Float) {
        rotateMinX = 0
        let side = VsBoardsRenderer.sideZoneWidth(ox)
        layout(side, side, side, worldW)
    }

    func layout(_ leftZone: Float, _ rightZone: Float, _ bottomZone: Float, _ worldW: Float) {
        let LEFT = TouchControls.LEFT, RIGHT = TouchControls.RIGHT, DOWN = TouchControls.DOWN, ROTATE = TouchControls.ROTATE
        if min(leftZone, rightZone) >= TouchControls.MIN_SIDE_ZONE {
            // Yan şeritler yeterli: klasik "T" dizilişi, tamamen kenar boşluğunda.
            let zone = min(leftZone, TouchControls.MAX_SIDE_ZONE)
            let d = TouchControls.clamp(zone / 2.5 - 1.6, 14, 30)
            let r = d / 2
            let padCx = zone / 2
            let rowY: Float = 90

            let split = rowY - 1.10 * d
            let top = rowY + 1.55 * d
            let outer = min(1.6 * d, padCx)
            let downCy = rowY - 2.2 * d

            placeBox(LEFT, padCx - 0.75 * d, rowY, r, padCx - outer, split, padCx, top)
            placeBox(RIGHT, padCx + 0.75 * d, rowY, r, padCx, split, padCx + outer, top)
            placeBox(DOWN, padCx, downCy, r, padCx - outer, downCy - 1.6 * d, padCx + outer, split)

            let rzone = min(rightZone, TouchControls.MAX_SIDE_ZONE)
            let rd = TouchControls.clamp(rzone / 2.2, 24, 40)
            let rotCx = worldW - rzone / 2, rotCy: Float = 55
            placeBox(ROTATE, rotCx, rotCy, rd / 2,
                     max(rotCx - 1.1 * rd, worldW - rzone), rotCy - 1.3 * rd, worldW, rotCy + 1.3 * rd)
        } else {
            // Dar ekran (4:3 / 16:10 tablet): butonlar şişenin solundaki boşluğun ALT kısmına iner.
            let zone = bottomZone
            let d: Float = 20, r = d / 2
            let mid = zone / 2
            let rowY: Float = 34, downCy: Float = 13
            let split = (rowY + downCy) / 2
            let top = rowY + 1.2 * d
            let outer = min(1.6 * d, mid)

            placeBox(LEFT, mid - 0.75 * d, rowY, r, mid - outer, split, mid, top)
            placeBox(RIGHT, mid + 0.75 * d, rowY, r, mid, split, mid + outer, top)
            placeBox(DOWN, mid, downCy, r, mid - outer, 0, mid + outer, split)

            let space = worldW - rotateMinX
            let rd = TouchControls.clamp(space - 8, 20, 30)
            let rotCx = rotateMinX + space / 2, rotCy: Float = 30
            placeBox(ROTATE, rotCx, rotCy, rd / 2, rotateMinX, 0, worldW, rotCy + 1.7 * rd)
        }
        applySafeInsets(worldW)
        clampHitAreas(worldW)
    }

    /// iOS: çentikli ekranlarda okları ve döndürme tuşunu güvenli alanın içine kaydırır.
    private func applySafeInsets(_ worldW: Float) {
        let g = Gdx.graphics
        let scale = worldW / Float(max(1, g.width))
        let left = g.safeInsetLeft * scale, right = g.safeInsetRight * scale
        // Daireler içeri kayar; dokunma alanları ekran kenarına kadar uzamaya devam eder.
        for i in [TouchControls.LEFT, TouchControls.DOWN] {
            cx[i] += left
            hit[i].width += left
        }
        cx[TouchControls.RIGHT] += left
        hit[TouchControls.RIGHT].x += left
        cx[TouchControls.ROTATE] -= right
        hit[TouchControls.ROTATE].x -= right
        hit[TouchControls.ROTATE].width += right
    }

    private func placeBox(_ i: Int, _ centerX: Float, _ centerY: Float, _ r: Float,
                          _ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float) {
        cx[i] = centerX
        cy[i] = centerY
        radius[i] = r
        hit[i].set(x1, y1, x2 - x1, y2 - y1)
    }

    private func clampHitAreas(_ worldW: Float) {
        for i in 0..<TouchControls.COUNT {
            let r = hit[i]
            let x1 = max(0, r.x)
            let y1 = max(0, r.y)
            let x2 = min(worldW, r.x + r.width)
            let y2 = min(Float(GameConfig.WORLD_HEIGHT), r.y + r.height)
            hit[i].set(x1, y1, max(0, x2 - x1), max(0, y2 - y1))
        }
    }

    private static func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float { return max(lo, min(hi, v)) }

    // ---- Çizim ----

    func draw(_ ui: NesUi) {
        drawBody(ui, TouchControls.LEFT, TouchControls.MOVE_ACCENT)
        drawBody(ui, TouchControls.RIGHT, TouchControls.MOVE_ACCENT)
        drawBody(ui, TouchControls.DOWN, TouchControls.MOVE_ACCENT)
        drawBody(ui, TouchControls.ROTATE, TouchControls.ROT_ACCENT)

        drawChevron(ui, TouchControls.LEFT, NesUi.DIR_LEFT)
        drawChevron(ui, TouchControls.RIGHT, NesUi.DIR_RIGHT)
        drawChevron(ui, TouchControls.DOWN, NesUi.DIR_DOWN)
        drawRotateIcon(ui)
    }

    private func drawBody(_ ui: NesUi, _ i: Int, _ accent: Color) {
        let a = anim[i]
        let r = radius[i] * (1 - 0.05 * a)
        let x = cx[i], y = cy[i]

        ui.circle(x, y - 2, r + 2.5, TouchControls.SHADOW)
        ui.circle(x, y, r + 1.6, TouchControls.CONTOUR)
        ui.circleGradient(x, y, r, TouchControls.BODY_BOTTOM, TouchControls.BODY_TOP)

        if a > 0.01 {
            tintA.set(accent); tintA.a = 0.18 * a
            tintB.set(accent); tintB.a = 0.85 * a
            ui.circleGradient(x, y, r, tintA, tintB)
        }

        tintA.set(TouchControls.RIM)
        tintA.lerp(accent, a)
        tintA.a = 0.55 + 0.45 * a
        ui.ring(x, y, r, 1.5, tintA)

        ui.ellipse(x, y + r * 0.46, r * 0.52, r * 0.16, TouchControls.GLOSS)
    }

    private func drawChevron(_ ui: NesUi, _ i: Int, _ dir: Int) {
        let r = radius[i] * (1 - 0.05 * anim[i])
        let size = r * 0.55
        let thickness = max(2, r * 0.26)
        var x = cx[i], y = cy[i]
        if dir == NesUi.DIR_LEFT { x += size * 0.14 }
        else if dir == NesUi.DIR_RIGHT { x -= size * 0.14 }
        else if dir == NesUi.DIR_DOWN { y += size * 0.14 }
        ui.chevron(x, y, size, thickness, dir, TouchControls.ICON)
    }

    private func drawRotateIcon(_ ui: NesUi) {
        let R = TouchControls.ROTATE
        let r = radius[R] * (1 - 0.05 * anim[R])
        let x = cx[R], y = cy[R]

        let ar = r * 0.52
        let t = max(1.8, r * 0.14)
        let startDeg: Float = 50, endDeg: Float = -230

        ui.arc(x, y, ar, t, startDeg, endDeg, TouchControls.ICON)

        let end = Double(toRadians(endDeg))
        let ex = x + Float(cos(end)) * ar
        let ey = y + Float(sin(end)) * ar
        let tx = Float(sin(end)), ty = -Float(cos(end))
        let nx = -ty, ny = tx
        let hs = t * 1.55
        ui.filledTriangle(
            ex + tx * hs * 1.9, ey + ty * hs * 1.9,
            ex + nx * hs, ey + ny * hs,
            ex - nx * hs, ey - ny * hs, TouchControls.ICON)
    }
}

/// İki şişeli VS ekranının TÜM görsel yerleşimi (CPU VS ve online VS paylaşır).
/// "left"/"right" hep "BEN"/"RAKİP" anlamındadır.
final class VsBoardsRenderer {

    private static let CELL_W = 11, CELL_H = 10
    private static let BOARD_W = Board.DEFAULT_WIDTH * CELL_W
    private static let BOARD_H = Board.DEFAULT_HEIGHT * CELL_H
    private static let BODY_H = Board.BODY_ROWS * CELL_H

    private static let BOARD_Y: Float = 13

    private static let EDGE_MARGIN: Float = 2
    private static let DOCTOR_PANEL_GAP: Float = 2
    private static let DOCTOR_PANEL_W: Float = 26, DOCTOR_PANEL_H: Float = 76
    private static let DOCTOR_PANEL_TOP: Float = Float(GameConfig.WORLD_HEIGHT) - 2

    private static let LEFT_BOARD_X: Float = EDGE_MARGIN + DOCTOR_PANEL_W + DOCTOR_PANEL_GAP
    private static let RIGHT_BOARD_X: Float = Float(GameConfig.CONTENT_WIDTH) - LEFT_BOARD_X - Float(BOARD_W)

    private static let LEFT_DOCTOR_PANEL_X: Float = EDGE_MARGIN
    private static let RIGHT_DOCTOR_PANEL_X: Float = Float(GameConfig.CONTENT_WIDTH) - EDGE_MARGIN - DOCTOR_PANEL_W

    private static let LABEL_Y: Float = 216
    private static let VS_LABEL_Y: Float = 185

    static let GAP_CENTER_X: Float = Float(GameConfig.CONTENT_WIDTH) / 2

    static let SIDE_ZONE_MAX_Y: Float = DOCTOR_PANEL_TOP - DOCTOR_PANEL_H

    static func sideZoneWidth(_ ox: Float) -> Float { return ox + LEFT_BOARD_X - 2 }

    private static let PAUSE_BTN_CX: Float = GAP_CENTER_X, PAUSE_BTN_CY: Float = 100, PAUSE_BTN_R: Float = 10
    private static let PAUSE_BOX_W: Float = 140, PAUSE_BOX_H: Float = 76
    private static let PAUSE_OPTION_W: Float = 100, PAUSE_OPTION_H: Float = 18

    private let ui: NesUi
    private let batch: SpriteBatch
    private let assets: Assets
    private let bottleRenderer: BottleRenderer
    private let leftRenderer: BoardRenderer
    private let rightRenderer: BoardRenderer

    init(_ ui: NesUi, _ batch: SpriteBatch, _ assets: Assets) {
        self.ui = ui
        self.batch = batch
        self.assets = assets
        bottleRenderer = BottleRenderer(ui, batch, assets)
        leftRenderer = BoardRenderer(ui, batch, assets, VsBoardsRenderer.LEFT_BOARD_X, VsBoardsRenderer.BOARD_Y, VsBoardsRenderer.CELL_W, VsBoardsRenderer.CELL_H)
        rightRenderer = BoardRenderer(ui, batch, assets, VsBoardsRenderer.RIGHT_BOARD_X, VsBoardsRenderer.BOARD_Y, VsBoardsRenderer.CELL_W, VsBoardsRenderer.CELL_H)
    }

    // ---- Şişeler ----

    func drawSide(_ ox: Float, _ left: Bool, _ label: String, _ engine: GameEngine, _ showFalling: Bool) {
        let boardX = left ? VsBoardsRenderer.LEFT_BOARD_X : VsBoardsRenderer.RIGHT_BOARD_X
        let doctorPanelX = left ? VsBoardsRenderer.LEFT_DOCTOR_PANEL_X : VsBoardsRenderer.RIGHT_DOCTOR_PANEL_X
        let renderer = left ? leftRenderer : rightRenderer
        let x = ox + boardX
        let BW = VsBoardsRenderer.BOARD_W, BH = VsBoardsRenderer.BODY_H, BY = VsBoardsRenderer.BOARD_Y

        bottleRenderer.render(x, BY, BW, BH)

        renderer.setOrigin(x, BY)
        renderer.render(engine.getBoard(),
                        showFalling && engine.getState() == .RUNNING ? engine.getCurrentCapsule() : nil,
                        engine.getFlashingCells(),
                        engine.getPhaseProgress())
        bottleRenderer.renderGlassAbove(x, BY, BW, BH)

        ui.textCentered(label + "  " + VsBoardsRenderer.digits(engine.getScore(), 7), x + Float(BW) / 2, VsBoardsRenderer.LABEL_Y, 1, 2, NesUi.WHITE)

        drawDoctorPanel(ox + doctorPanelX, engine, renderer)
    }

    func drawVsLabel(_ ox: Float) {
        ui.textCentered(Txt.VS.s(), ox + VsBoardsRenderer.GAP_CENTER_X, VsBoardsRenderer.VS_LABEL_Y, 1.6, 3, NesUi.WHITE)
    }

    private func drawDoctorPanel(_ x: Float, _ engine: GameEngine, _ renderer: BoardRenderer) {
        let w = VsBoardsRenderer.DOCTOR_PANEL_W, h = VsBoardsRenderer.DOCTOR_PANEL_H
        let y = VsBoardsRenderer.DOCTOR_PANEL_TOP - h
        ui.roundRectBorder(x, y, w, h, 5, 2, NesUi.YELLOW, NesUi.BLACK)

        var dw = w - 4
        let dh = min(dw / 0.57, h - 30)
        dw = dh * 0.57
        let dx = x + (w - dw) / 2
        let dy = y + 4
        if let doctor = assets.doctor {
            batch.draw(doctor, dx, dy, dw, dh)
        }

        ui.textCenteredOutlined(VsBoardsRenderer.digits(engine.getBoard().getVirusCount(), 2), x + w / 2, dy + dh * 0.4,
                                1.5, 2, NesUi.YELLOW, NesUi.BLACK)

        let next = engine.getNextColors()
        let pcw: Float = 8, pch: Float = 7
        let px = x + (w - pcw * 2) / 2
        let py = y + h - 6 - pch
        renderer.drawPreviewHalf(px, py, pcw, pch, next[0], true)
        renderer.drawPreviewHalf(px + pcw, py, pcw, pch, next[1], false)
    }

    // ---- Duraklatma butonu/kutusu ----

    /// iOS: duraklatma butonu ortadaki boşluk yerine döndürme tuşunun üstünde durur.
    private var pauseCx: Float = -1, pauseCy: Float = 0

    func placePauseAboveRotate(_ controls: TouchControls) {
        let hit = controls.hitArea(TouchControls.ROTATE)
        pauseCx = controls.centerX(TouchControls.ROTATE)
        pauseCy = min(hit.y + hit.height + VsBoardsRenderer.PAUSE_BTN_R + 4,
                      Float(GameConfig.WORLD_HEIGHT) - VsBoardsRenderer.PAUSE_BTN_R - 4)
    }

    private func pauseCenter(_ ox: Float) -> (Float, Float) {
        if pauseCx >= 0 { return (pauseCx, pauseCy) }
        return (ox + VsBoardsRenderer.PAUSE_BTN_CX, VsBoardsRenderer.PAUSE_BTN_CY)
    }

    func pauseButtonBounds(_ ox: Float) -> Rectangle {
        let (cx, cy) = pauseCenter(ox), r = VsBoardsRenderer.PAUSE_BTN_R
        return Rectangle(cx - r, cy - r, r * 2, r * 2)
    }

    func drawPauseButton(_ ox: Float) {
        let (cx, cy) = pauseCenter(ox), r = VsBoardsRenderer.PAUSE_BTN_R
        ui.circle(cx, cy, r + 1.5, NesUi.BLACK)
        ui.circleGradient(cx, cy, r, Color(0.10, 0.12, 0.18, 0.92), Color(0.38, 0.44, 0.56, 0.92))
        ui.ring(cx, cy, r, 1.3, NesUi.WHITE)
        let barW = r * 0.24, barH = r * 0.9
        ui.rect(cx - r * 0.32 - barW / 2, cy - barH / 2, barW, barH, NesUi.WHITE)
        ui.rect(cx + r * 0.32 - barW / 2, cy - barH / 2, barW, barH, NesUi.WHITE)
    }

    func pauseBoxX(_ ox: Float) -> Float { return ox + Float(GameConfig.CONTENT_WIDTH) / 2 - VsBoardsRenderer.PAUSE_BOX_W / 2 }
    func pauseBoxY() -> Float { return VsBoardsRenderer.BOARD_Y + Float(VsBoardsRenderer.BOARD_H) / 2 - VsBoardsRenderer.PAUSE_BOX_H / 2 }

    func pauseOverlayResumeBounds(_ ox: Float) -> Rectangle {
        let x = pauseBoxX(ox), y = pauseBoxY()
        return Rectangle(x + (VsBoardsRenderer.PAUSE_BOX_W - VsBoardsRenderer.PAUSE_OPTION_W) / 2, y + 34,
                         VsBoardsRenderer.PAUSE_OPTION_W, VsBoardsRenderer.PAUSE_OPTION_H)
    }

    func pauseOverlayMenuBounds(_ ox: Float) -> Rectangle {
        let x = pauseBoxX(ox), y = pauseBoxY()
        return Rectangle(x + (VsBoardsRenderer.PAUSE_BOX_W - VsBoardsRenderer.PAUSE_OPTION_W) / 2, y + 10,
                         VsBoardsRenderer.PAUSE_OPTION_W, VsBoardsRenderer.PAUSE_OPTION_H)
    }

    func drawPauseOverlay(_ ox: Float) {
        let x = pauseBoxX(ox), y = pauseBoxY()
        let cx = x + VsBoardsRenderer.PAUSE_BOX_W / 2

        ui.roundRectBorder(x, y, VsBoardsRenderer.PAUSE_BOX_W, VsBoardsRenderer.PAUSE_BOX_H, 6, 2, NesUi.WHITE, NesUi.BLACK)
        ui.textCentered(Txt.PAUSED.s(), cx, y + VsBoardsRenderer.PAUSE_BOX_H - 16, 1, 3, NesUi.WHITE)

        let resume = pauseOverlayResumeBounds(ox)
        ui.roundRectBorder(resume.x, resume.y, resume.width, resume.height, 4, 1, NesUi.GREEN, NesUi.BLACK)
        ui.textCentered(Txt.RESUME.s(), resume.x + resume.width / 2, resume.y + 5, 1, 2, NesUi.WHITE)

        let menu = pauseOverlayMenuBounds(ox)
        ui.roundRectBorder(menu.x, menu.y, menu.width, menu.height, 4, 1, NesUi.RED, NesUi.BLACK)
        ui.textCentered(Txt.MENU.s(), menu.x + menu.width / 2, menu.y + 5, 1, 2, NesUi.WHITE)
    }

    // ---- Maç sonu ----

    func resultCenterY() -> Float { return VsBoardsRenderer.BOARD_Y + Float(VsBoardsRenderer.BOARD_H) / 2 }

    func drawResultOverlay(_ ox: Float, _ draw: Bool, _ leftWon: Bool, _ blinkTimer: Float, _ note: String? = nil) {
        let message = draw ? Txt.DRAW.s() : (leftWon ? Txt.YOU_WIN.s() : Txt.YOU_LOSE.s())
        let color = draw ? NesUi.WHITE : (leftWon ? NesUi.YELLOW : NesUi.RED)

        let cx = ox + Float(GameConfig.CONTENT_WIDTH) / 2
        let w: Float = 136, h: Float = note != nil ? 60 : 48
        let x = cx - w / 2
        let y = VsBoardsRenderer.BOARD_Y + Float(VsBoardsRenderer.BOARD_H) / 2 - h / 2

        ui.roundRectBorder(x, y, w, h, 6, 2, color, NesUi.BLACK)
        ui.textCentered(message, cx, y + h - 18, 1, 3, color)
        if let n = note { ui.textCentered(n, cx, y + 22, 1, 2, NesUi.WHITE) }
        if Int(blinkTimer * 2) % 2 == 0 {
            ui.textCentered(Txt.PRESS_START.s(), cx, y + 10, 1, 3, NesUi.WHITE)
        }
    }

    static func digits(_ value: Int, _ count: Int) -> String {
        let s = String(max(0, value))
        if s.count >= count { return s }
        return String(repeating: "0", count: count - s.count) + s
    }
}
