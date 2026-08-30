//
//  LevelSelectScreenView.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.LevelSelectScreen.
//
//  NES Dr. Mario'nun "1 PLAYER GAME" ayar ekranı: turuncu/pembe dama zemin, süslü çerçeveli
//  siyah panel ve içinde üç ayar satırı:
//    VIRUS LEVEL - 0..20 arası cetvel + üstünde turuncu ok + sağda yeşil çerçeveli sayı kutusu
//    SPEED      - LOW / MED / HI, seçilinin üstünde turuncu ok
//    MUSIC TYPE - FEVER / CHILL / OFF, seçili olan turuncu kutu içinde
//
//  Kontrol: YUKARI/AŞAĞI satır değiştirir, SOL/SAĞ değeri değiştirir, ENTER/SPACE oyunu başlatır,
//  ESC giriş ekranına döner. Dokunmatikte cetvele/seçeneklere doğrudan dokunulur, altta
//  START kutusu oyunu başlatır.
//

import SwiftUI

struct LevelSelectScreenView: View {
    @EnvironmentObject private var coordinator: GameCoordinator
    let mode: GameMode

    private enum Row { case level, speed, music }

    // ---- Yerleşim (NES içerik alanı: 256x224) ----
    private static let panelX: CGFloat = 14, panelY: CGFloat = 26, panelW: CGFloat = 228, panelH: CGFloat = 188
    private static let titleY: CGFloat = 190

    private static let labelX: CGFloat = 26
    private static let labelH: CGFloat = 15
    private static let levelLabelY: CGFloat = 162
    private static let speedLabelY: CGFloat = 104
    private static let musicLabelY: CGFloat = 58

    private static let rulerX: CGFloat = 54, rulerW: CGFloat = 132, rulerLineY: CGFloat = 136
    private static let levelBoxX: CGFloat = 194, levelBoxY: CGFloat = 128, levelBoxW: CGFloat = 34, levelBoxH: CGFloat = 20

    private static let speedRowY: CGFloat = 84
    private static let speedXs: [CGFloat] = [62, 112, 166]

    private static let musicRowY: CGFloat = 38
    private static let musicXs: [CGFloat] = [44, 104, 170]

    private static let startX: CGFloat = 100, startY: CGFloat = 5, startW: CGFloat = 56, startH: CGFloat = 17

    private static let txt: CGFloat = 1
    private static let sp: CGFloat = 3

    private let speeds = Speed.allCases
    private let musics = MusicType.allCases

    @State private var level = 0
    @State private var speedIndex = 1 // MED
    @State private var musicIndex = 0 // FEVER
    @State private var row: Row = .level
    @FocusState private var focused: Bool

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.height / GameConfig.worldHeight
            let worldW = geo.size.width / scale
            let ox = GameConfig.contentX(worldW)

            ZStack {
                Canvas { context, _ in
                    context.scaleBy(x: scale, y: scale)
                    NesUI.checkerboard(context, worldWidth: worldW, worldHeight: GameConfig.worldHeight, cell: 8,
                                       a: NesUI.checkOrange, b: NesUI.checkPink)
                    drawPanelFrame(context, ox: ox)
                    NesUI.textCentered(context, mode.settingsTitle, centerX: ox + GameConfig.contentWidth / 2,
                                      y: LevelSelectScreenView.titleY, scale: 2, spacing: 4, color: NesUI.white)
                    drawVirusLevelRow(context, ox: ox)
                    drawSpeedRow(context, ox: ox)
                    drawMusicRow(context, ox: ox)
                    drawStartButton(context, ox: ox)
                }

                overlayTouchZones(ox: ox, scale: scale)
            }
            .contentShape(Rectangle())
            .focusable()
            .focused($focused)
            .onAppear {
                focused = true
                MusicPlayer.shared.play(ChiptuneThemes.levelSelect, name: "levelSelect")
            }
            .onKeyPress(.escape) { back(); return .handled }
            .onKeyPress(.upArrow) { row = prevRow(); return .handled }
            .onKeyPress(.downArrow) { row = nextRow(); return .handled }
            .onKeyPress(.leftArrow) { changeValue(-1); return .handled }
            .onKeyPress(.rightArrow) { changeValue(1); return .handled }
            .onKeyPress(.return) { startGame(); return .handled }
            .onKeyPress(.space) { startGame(); return .handled }
        }
        .ignoresSafeArea()
    }

    // ---- Dokunma alanları ----

    @ViewBuilder
    private func overlayTouchZones(ox: CGFloat, scale: CGFloat) -> some View {
        tapZone(CGRect(x: ox + LevelSelectScreenView.startX, y: LevelSelectScreenView.startY,
                       width: LevelSelectScreenView.startW, height: LevelSelectScreenView.startH), scale: scale) {
            startGame()
        }

        ForEach(0..<speeds.count, id: \.self) { i in
            let w = NesUI.textWidth(speeds[i].label, scale: LevelSelectScreenView.txt, spacing: LevelSelectScreenView.sp)
            tapZone(CGRect(x: ox + LevelSelectScreenView.speedXs[i] - 6, y: LevelSelectScreenView.speedRowY - 5,
                           width: w + 12, height: 18), scale: scale) {
                row = .speed
                speedIndex = i
            }
        }

        ForEach(0..<musics.count, id: \.self) { i in
            let w = NesUI.textWidth(musics[i].label, scale: LevelSelectScreenView.txt, spacing: LevelSelectScreenView.sp)
            tapZone(CGRect(x: ox + LevelSelectScreenView.musicXs[i] - 6, y: LevelSelectScreenView.musicRowY - 5,
                           width: w + 12, height: 18), scale: scale) {
                row = .music
                musicIndex = i
            }
        }

        // Cetvele dokunmak: en yakın seviyeye atla (konum bilgisi gerektiği için DragGesture kullanılır).
        let rulerScreenRect = NesUI.screenRect(fromNES: CGRect(x: ox + LevelSelectScreenView.rulerX - 6,
                                                               y: LevelSelectScreenView.rulerLineY - 12,
                                                               width: LevelSelectScreenView.rulerW + 12, height: 28), scale: scale)
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: rulerScreenRect.width, height: rulerScreenRect.height)
            .position(x: rulerScreenRect.midX, y: rulerScreenRect.midY)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                row = .level
                let t = (value.location.x - rulerScreenRect.minX - 6 * scale) / (LevelSelectScreenView.rulerW * scale)
                let steps = GameConfig.maxLevel - GameConfig.minLevel
                level = clampInt(Int((t * CGFloat(steps)).rounded()) + GameConfig.minLevel, GameConfig.minLevel, GameConfig.maxLevel)
            })
    }

    private func tapZone(_ nesRect: CGRect, scale: CGFloat, action: @escaping () -> Void) -> some View {
        let r = NesUI.screenRect(fromNES: nesRect, scale: scale)
        return Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: r.width, height: r.height)
            .position(x: r.midX, y: r.midY)
            .onTapGesture(perform: action)
    }

    /// Panelin çok katmanlı NES çerçevesi: sarı dış hat, siyah boşluk, pembe bant, beyaz iç hat.
    private func drawPanelFrame(_ context: GraphicsContext, ox: CGFloat) {
        let x = ox + LevelSelectScreenView.panelX
        NesUI.roundRect(context, x: x, y: LevelSelectScreenView.panelY, w: LevelSelectScreenView.panelW, h: LevelSelectScreenView.panelH, r: 10, color: NesUI.yellow)
        NesUI.roundRect(context, x: x + 1, y: LevelSelectScreenView.panelY + 1, w: LevelSelectScreenView.panelW - 2, h: LevelSelectScreenView.panelH - 2, r: 9, color: NesUI.black)
        NesUI.roundRect(context, x: x + 3, y: LevelSelectScreenView.panelY + 3, w: LevelSelectScreenView.panelW - 6, h: LevelSelectScreenView.panelH - 6, r: 7, color: NesUI.pink)
        NesUI.roundRect(context, x: x + 6, y: LevelSelectScreenView.panelY + 6, w: LevelSelectScreenView.panelW - 12, h: LevelSelectScreenView.panelH - 12, r: 5, color: NesUI.white)
        NesUI.roundRect(context, x: x + 7, y: LevelSelectScreenView.panelY + 7, w: LevelSelectScreenView.panelW - 14, h: LevelSelectScreenView.panelH - 14, r: 4, color: NesUI.black)
    }

    // ---- VIRUS LEVEL ----

    private func drawVirusLevelRow(_ context: GraphicsContext, ox: CGFloat) {
        drawLabelBox(context, ox: ox, label: "VIRUS LEVEL", y: LevelSelectScreenView.levelLabelY, border: NesUI.pink, owner: .level)

        NesUI.text(context, "1P", x: ox + 30, y: LevelSelectScreenView.rulerLineY + 2, scale: LevelSelectScreenView.txt, spacing: LevelSelectScreenView.sp, color: NesUI.white)

        // Cetvel: yatay çizgi + her seviye için altına inen çentik, iki uçta uzun çubuk.
        let x0 = ox + LevelSelectScreenView.rulerX
        NesUI.rect(context, x: x0, y: LevelSelectScreenView.rulerLineY, w: LevelSelectScreenView.rulerW, h: 1, color: NesUI.white)
        let steps = GameConfig.maxLevel - GameConfig.minLevel
        for i in 0...steps {
            let tx = x0 + tickOffset(i)
            let end = (i == 0 || i == steps)
            let len: CGFloat = end ? 9 : 5
            NesUI.rect(context, x: tx, y: LevelSelectScreenView.rulerLineY - len, w: 1, h: len, color: NesUI.white)
        }

        // Seçili seviyeyi gösteren turuncu ok (çizginin üstünde, aşağı bakar).
        let cursorX = x0 + tickOffset(level - GameConfig.minLevel)
        NesUI.triangleDown(context, centerX: cursorX + 0.5, bottomY: LevelSelectScreenView.rulerLineY + 3, size: 5, color: NesUI.lightOrange)

        // Sağdaki yeşil çerçeveli seviye kutusu.
        NesUI.roundRectBorder(context, x: ox + LevelSelectScreenView.levelBoxX, y: LevelSelectScreenView.levelBoxY,
                              w: LevelSelectScreenView.levelBoxW, h: LevelSelectScreenView.levelBoxH, r: 3, t: 1, border: NesUI.green, fill: NesUI.black)
        NesUI.textCentered(context, two(level), centerX: ox + LevelSelectScreenView.levelBoxX + LevelSelectScreenView.levelBoxW / 2,
                          y: LevelSelectScreenView.levelBoxY + 6, scale: 1.5, spacing: 3, color: NesUI.white)
    }

    private func tickOffset(_ index: Int) -> CGFloat {
        let steps = GameConfig.maxLevel - GameConfig.minLevel
        return LevelSelectScreenView.rulerW * CGFloat(index) / CGFloat(steps)
    }

    // ---- SPEED ----

    private func drawSpeedRow(_ context: GraphicsContext, ox: CGFloat) {
        drawLabelBox(context, ox: ox, label: "SPEED", y: LevelSelectScreenView.speedLabelY, border: NesUI.lightOrange, owner: .speed)
        NesUI.text(context, "1P", x: ox + 30, y: LevelSelectScreenView.speedRowY, scale: LevelSelectScreenView.txt, spacing: LevelSelectScreenView.sp, color: NesUI.white)

        for i in 0..<speeds.count {
            NesUI.text(context, speeds[i].label, x: ox + LevelSelectScreenView.speedXs[i], y: LevelSelectScreenView.speedRowY,
                      scale: LevelSelectScreenView.txt, spacing: LevelSelectScreenView.sp, color: NesUI.white)
        }
        let w = NesUI.textWidth(speeds[speedIndex].label, scale: LevelSelectScreenView.txt, spacing: LevelSelectScreenView.sp)
        NesUI.triangleDown(context, centerX: ox + LevelSelectScreenView.speedXs[speedIndex] + w / 2, bottomY: LevelSelectScreenView.speedRowY + 10, size: 5, color: NesUI.lightOrange)
    }

    // ---- MUSIC TYPE ----

    private func drawMusicRow(_ context: GraphicsContext, ox: CGFloat) {
        drawLabelBox(context, ox: ox, label: "MUSIC TYPE", y: LevelSelectScreenView.musicLabelY, border: NesUI.lightOrange, owner: .music)

        for i in 0..<musics.count {
            let w = NesUI.textWidth(musics[i].label, scale: LevelSelectScreenView.txt, spacing: LevelSelectScreenView.sp)
            if i == musicIndex {
                NesUI.roundRectBorder(context, x: ox + LevelSelectScreenView.musicXs[i] - 6, y: LevelSelectScreenView.musicRowY - 5,
                                      w: w + 12, h: 17, r: 4, t: 1, border: NesUI.lightOrange, fill: NesUI.black)
            }
            NesUI.text(context, musics[i].label, x: ox + LevelSelectScreenView.musicXs[i], y: LevelSelectScreenView.musicRowY,
                      scale: LevelSelectScreenView.txt, spacing: LevelSelectScreenView.sp, color: NesUI.white)
        }
    }

    // ---- Ortak parçalar ----

    /// Başlık etiketi: köşeleri kırpılmış renkli çerçeve + siyah zemin + beyaz metin.
    private func drawLabelBox(_ context: GraphicsContext, ox: CGFloat, label: String, y: CGFloat, border: Color, owner: Row) {
        let w = NesUI.textWidth(label, scale: LevelSelectScreenView.txt, spacing: LevelSelectScreenView.sp) + 16
        NesUI.roundRectBorder(context, x: ox + LevelSelectScreenView.labelX, y: y, w: w, h: LevelSelectScreenView.labelH, r: 4, t: 1, border: border, fill: NesUI.black)
        NesUI.text(context, label, x: ox + LevelSelectScreenView.labelX + 8, y: y + 4, scale: LevelSelectScreenView.txt, spacing: LevelSelectScreenView.sp, color: NesUI.white)
        if row == owner {
            NesUI.triangleRight(context, leftX: ox + LevelSelectScreenView.labelX - 8, centerY: y + LevelSelectScreenView.labelH / 2, size: 4, color: NesUI.lightOrange)
        }
    }

    private func drawStartButton(_ context: GraphicsContext, ox: CGFloat) {
        NesUI.roundRectBorder(context, x: ox + LevelSelectScreenView.startX, y: LevelSelectScreenView.startY,
                              w: LevelSelectScreenView.startW, h: LevelSelectScreenView.startH, r: 4, t: 1, border: NesUI.white, fill: NesUI.black)
        NesUI.textCentered(context, "START", centerX: ox + LevelSelectScreenView.startX + LevelSelectScreenView.startW / 2,
                          y: LevelSelectScreenView.startY + 5, scale: LevelSelectScreenView.txt, spacing: LevelSelectScreenView.sp, color: NesUI.yellow)
    }

    private func two(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    // ---- Girdi ----

    private func prevRow() -> Row {
        switch row {
        case .level: return .music
        case .speed: return .level
        case .music: return .speed
        }
    }

    private func nextRow() -> Row {
        switch row {
        case .level: return .speed
        case .speed: return .music
        case .music: return .level
        }
    }

    private func changeValue(_ dir: Int) {
        switch row {
        case .level:
            level = clampInt(level + dir, GameConfig.minLevel, GameConfig.maxLevel)
        case .speed:
            speedIndex = clampInt(speedIndex + dir, 0, speeds.count - 1)
        case .music:
            musicIndex = clampInt(musicIndex + dir, 0, musics.count - 1)
        }
    }

    private func clampInt(_ v: Int, _ lo: Int, _ hi: Int) -> Int {
        max(lo, min(hi, v))
    }

    private func back() {
        coordinator.route = .title
    }

    private func startGame() {
        coordinator.route = .singlePlayer(mode: mode, level: level, speed: speeds[speedIndex], music: musics[musicIndex])
    }
}
