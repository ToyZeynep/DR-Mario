//
//  GameConfig.swift
//  VirusHunt
//
//  com.rummuscan.game.GameConfig (VirusHunt Android sürümünden birebir).
//
//  Tüm ekranlar NES'in 256x224 çözünürlüğünde tasarlanır (yatay). ExtendViewport: YÜKSEKLİK her
//  cihazda 224 birim, GENİŞLİK ekran oranına göre 256'nın üzerine taşar; 256 birimlik içerik
//  alanı yatayda ortalanır (contentX), taşan kenarlar dama zeminiyle dolar.
//

import Foundation

enum GameConfig {
    static let TICK_DT: Float = 1 / 60 // sabit adım: saniyede 60 tick

    static let WORLD_HEIGHT = 224
    static let CONTENT_WIDTH = 256

    static func contentX(_ worldWidth: Float) -> Float {
        return (worldWidth - Float(CONTENT_WIDTH)) / 2
    }

    /// Hücre ENİNE daha geniş (13x10): tahta şişenin iç boşluğunu tam doldursun diye.
    static let CELL_W = 13
    static let CELL_H = 10
    static let BOARD_PIXEL_WIDTH = Board.DEFAULT_WIDTH * CELL_W    // 104
    static let BOARD_PIXEL_HEIGHT = Board.DEFAULT_HEIGHT * CELL_H  // 170

    // ---- Oyun ekranı yerleşimi ----

    static let BOARD_X = (CONTENT_WIDTH - BOARD_PIXEL_WIDTH) / 2 // 76
    static let BOARD_Y = 15

    // ---- Şişe çerçevesinin geometrisi (dikey dilimli çizim; bkz. Java yorumu) ----

    static let BOTTLE_IMG_W: Float = 640
    static let BOTTLE_IMG_H: Float = 1152
    static let BOTTLE_SEAM_NECK: Float = 180
    static let BOTTLE_SEAM_BODY: Float = 322
    static let BOTTLE_SEAM_FLOOR: Float = 1076

    private static let BOTTLE_INTERIOR_RATIO: Float = 568 / BOTTLE_IMG_W
    private static let BOTTLE_NECK_SQUASH: Float = 0.62
    private static let BOTTLE_SHOULDER_SQUASH: Float = 0.75

    static let BOTTLE_FRAME_W: Float = Float(BOARD_PIXEL_WIDTH) / BOTTLE_INTERIOR_RATIO // ~117
    private static let BOTTLE_PX: Float = BOTTLE_FRAME_W / BOTTLE_IMG_W

    static let BOTTLE_NECK_H: Float = BOTTLE_SEAM_NECK * BOTTLE_PX * BOTTLE_NECK_SQUASH
    static let BOTTLE_SHOULDER_H: Float = (BOTTLE_SEAM_BODY - BOTTLE_SEAM_NECK) * BOTTLE_PX * BOTTLE_SHOULDER_SQUASH
    static let BODY_PIXEL_HEIGHT = Board.BODY_ROWS * CELL_H // 160
    static let BOTTLE_BODY_H: Float = Float(BODY_PIXEL_HEIGHT)
    static let BOTTLE_FLOOR_H: Float = (BOTTLE_IMG_H - BOTTLE_SEAM_FLOOR) * BOTTLE_PX // ~13.9

    static let BOTTLE_FRAME_H: Float = BOTTLE_NECK_H + BOTTLE_SHOULDER_H + BOTTLE_BODY_H + BOTTLE_FLOOR_H
    static let BOTTLE_FRAME_X: Float = Float(BOARD_X) - (BOTTLE_FRAME_W - Float(BOARD_PIXEL_WIDTH)) / 2 // ~69
    static let BOTTLE_FRAME_Y: Float = Float(BOARD_Y) - BOTTLE_FLOOR_H

    struct BottleGeometry {
        let frameW: Float, frameH: Float, frameX: Float, frameY: Float
        let neckH: Float, shoulderH: Float, bodyH: Float, floorH: Float
    }

    static func bottleGeometryFor(_ boardPixelWidth: Int, _ boardPixelHeight: Int, _ boardOriginX: Float, _ boardOriginY: Float) -> BottleGeometry {
        let frameW = Float(boardPixelWidth) / BOTTLE_INTERIOR_RATIO
        let bottlePx = frameW / BOTTLE_IMG_W

        let neckH = BOTTLE_SEAM_NECK * bottlePx * BOTTLE_NECK_SQUASH
        let shoulderH = (BOTTLE_SEAM_BODY - BOTTLE_SEAM_NECK) * bottlePx * BOTTLE_SHOULDER_SQUASH
        let bodyH = Float(boardPixelHeight)
        let floorH = (BOTTLE_IMG_H - BOTTLE_SEAM_FLOOR) * bottlePx
        let frameH = neckH + shoulderH + bodyH + floorH
        let frameX = boardOriginX - (frameW - Float(boardPixelWidth)) / 2
        let frameY = boardOriginY - floorH

        return BottleGeometry(frameW: frameW, frameH: frameH, frameX: frameX, frameY: frameY,
                              neckH: neckH, shoulderH: shoulderH, bodyH: bodyH, floorH: floorH)
    }

    // ---- HUD panelleri ----

    static let SCORE_PANEL_X: Float = 1, SCORE_PANEL_Y: Float = 162, SCORE_PANEL_W: Float = 66, SCORE_PANEL_H: Float = 58
    static let LENS_PANEL_X: Float = -18, LENS_PANEL_Y: Float = 42, LENS_PANEL_W: Float = 90, LENS_PANEL_H: Float = 96
    static let LOGO_CENTER_X: Float = 214, LOGO_Y: Float = 198, LOGO_SCALE: Float = 1.6
    static let DOCTOR_PANEL_X: Float = 189, DOCTOR_PANEL_Y: Float = 126, DOCTOR_PANEL_W: Float = 66, DOCTOR_PANEL_H: Float = 58
    static let LEVEL_PANEL_X: Float = 189, LEVEL_PANEL_Y: Float = 60, LEVEL_PANEL_W: Float = 66, LEVEL_PANEL_H: Float = 54

    // ---- ui/notepad_panel.png içindeki kağıdın yeri ----

    static let PAPER_LEFT: Float = 33 / 672
    static let PAPER_RIGHT: Float = 639 / 672
    static let PAPER_BOTTOM: Float = (224 - 196) / 224
    static let PAPER_TOP: Float = (224 - 48) / 224

    // ---- ui/microscope_bg.png içindeki merceğin yeri ----

    static let LENS_CENTER_X: Float = 440 / 672
    static let LENS_CENTER_Y: Float = (224 - 101) / 224
    static let LENS_RADIUS_X: Float = 180 / 672
    static let LENS_RADIUS_Y: Float = 67 / 224

    // ---- Oyun kuralları ----

    static let SPEED_LOW = 45
    static let SPEED_MEDIUM = 30
    static let SPEED_HIGH = 18

    static let DEFAULT_VIRUS_COUNT = 20

    static let MIN_LEVEL = 0
    static let MAX_LEVEL = 20
    static let VIRUSES_PER_LEVEL = 4

    static func virusCountForLevel(_ level: Int) -> Int {
        let count = (level + 1) * VIRUSES_PER_LEVEL
        let cap = Board.DEFAULT_WIDTH * Board.DEFAULT_HEIGHT / 2
        return min(count, cap)
    }
}
