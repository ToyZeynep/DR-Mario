//
//  TitleScreenView.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.TitleScreen.
//
//  NES Dr. Mario giriş ekranının kodla çizilmiş karşılığı: yeşil dama zemin, dev iki renkli
//  kapsül logosu ve altında siyah menü paneli. NES'teki "1 PLAYER GAME / 2 PLAYER GAME"
//  satırlarının yerini GameMode seçenekleri alır; seçili satırı soldaki kırmızı kalp
//  gösterir (orijinaldeki gibi), panelin solunda doktor, sağında virüs sprite'ı durur.
//
//  Kontrol: YUKARI/AŞAĞI ile seçim, ENTER/SPACE ile onay; dokunmatikte doğrudan
//  satıra dokunmak seçip onaylar.
//

import SwiftUI

/// Kare-başı zamanlama durumu, SinglePlayerSession'daki aynı gerekçeyle düz sınıf alanları
/// olarak tutulur (bkz. oradaki not): TimelineView'ın içerik kapanışının içinden her karede
/// güvenle mutasyona uğrayabilsin diye.
private final class TitleScreenTiming: ObservableObject {
    var blinkTimer: Double = 0
    var comingSoonTimer: Double = 0
    var lastTimestamp: Date?
}

struct TitleScreenView: View {
    @EnvironmentObject private var coordinator: GameCoordinator

    // ---- Yerleşim (NES içerik alanı: 256x224) ----
    private static let capsuleX: CGFloat = 20, capsuleY: CGFloat = 120, capsuleW: CGFloat = 216, capsuleH: CGFloat = 70
    private static let panelX: CGFloat = 16, panelY: CGFloat = 24, panelW: CGFloat = 224, panelH: CGFloat = 64
    private static let menuCenterX: CGFloat = 132
    private static let menuTopBaseline: CGFloat = 68 // ilk satırın alt kenarı
    private static let menuLineStep: CGFloat = 16
    private static let menuScale: CGFloat = 1
    private static let menuSpacing: CGFloat = 3 // 5px glyph + 3px = NES'in 8px ilerlemesi

    private let modes = GameMode.allCases
    private let assets = Assets()

    @State private var selected = 0
    // Kare-başı zamanlama (blinkTimer/comingSoonTimer/lastTimestamp) bilerek @State DEĞİL,
    // bkz. SinglePlayerSession'daki not: TimelineView'ın içerik kapanışının İÇİNDE her karede
    // güvenilir biçimde mutasyona uğraması gerekiyor, ayrı bir .onChange(of:) yerine.
    @StateObject private var timing = TitleScreenTiming()
    @FocusState private var focused: Bool

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.height / GameConfig.worldHeight
            let worldW = geo.size.width / scale
            let ox = GameConfig.contentX(worldW)

            ZStack {
                TimelineView(.animation) { timeline in
                    // tick() BİLEREK Canvas'ın KENDİ çizim kapanışının İÇİNDE çağrılıyor - bkz.
                    // SinglePlayerScreenView'daki aynı notun gerekçesi: TimelineView'ın kendi
                    // içerik kapanışına (ya da ayrı bir .onChange(of:)'a) taşımak, o sarmalayıcının
                    // her karede yeniden çalıştırılmasını garanti etmiyor.
                    Canvas { context, _ in
                        tick(timeline.date)
                        context.scaleBy(x: scale, y: scale)
                        NesUI.checkerboard(context, worldWidth: worldW, worldHeight: GameConfig.worldHeight, cell: 8,
                                           a: NesUI.checkGreenA, b: NesUI.checkGreenB)
                        drawLogo(context, ox: ox)
                        drawMenuPanel(context, ox: ox)
                    }
                }

                // Menü satırlarına dokunma alanları (NES y-up -> view y-down dönüşümüyle).
                ForEach(0..<modes.count, id: \.self) { i in
                    let y = TitleScreenView.menuTopBaseline - CGFloat(i) * TitleScreenView.menuLineStep
                    let rowRect = CGRect(x: ox + TitleScreenView.panelX, y: y - 5, width: TitleScreenView.panelW, height: TitleScreenView.menuLineStep)
                    let screenRect = NesUI.screenRect(fromNES: rowRect, scale: scale)
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: screenRect.width, height: screenRect.height)
                        .position(x: screenRect.midX, y: screenRect.midY)
                        .onTapGesture {
                            selected = i
                            confirm()
                        }
                }
            }
            .contentShape(Rectangle())
            .focusable()
            .focused($focused)
            .onAppear {
                focused = true
                MusicPlayer.shared.play(ChiptuneThemes.title, name: "title")
            }
            .onKeyPress(.upArrow) { selected = (selected + modes.count - 1) % modes.count; return .handled }
            .onKeyPress(.downArrow) { selected = (selected + 1) % modes.count; return .handled }
            .onKeyPress(.return) { confirm(); return .handled }
            .onKeyPress(.space) { confirm(); return .handled }
        }
        .ignoresSafeArea()
    }

    @discardableResult
    private func tick(_ date: Date) -> Bool {
        let delta: Double
        if let last = timing.lastTimestamp {
            delta = min(0.25, date.timeIntervalSince(last))
        } else {
            delta = 0
        }
        timing.lastTimestamp = date
        timing.blinkTimer += delta
        if timing.comingSoonTimer > 0 { timing.comingSoonTimer -= delta }
        return true
    }

    /// Dev kapsül + üstündeki sarı "Dr. MARIO" yazısı ve küçük TM işareti.
    private func drawLogo(_ context: GraphicsContext, ox: CGFloat) {
        NesUI.capsule(context, x: ox + TitleScreenView.capsuleX, y: TitleScreenView.capsuleY,
                     w: TitleScreenView.capsuleW, h: TitleScreenView.capsuleH,
                     left: NesUI.pillBlue, right: NesUI.pillRed, outline: NesUI.black)

        let scale: CGFloat = 3, spacing: CGFloat = 6
        let textY = TitleScreenView.capsuleY + (TitleScreenView.capsuleH - PixelFont.height(scale: scale)) / 2
        NesUI.textCenteredOutlined(context, "Dr. MARIO", centerX: ox + TitleScreenView.capsuleX + TitleScreenView.capsuleW / 2,
                                   y: textY, scale: scale, spacing: spacing, color: NesUI.yellow, outline: NesUI.darkBrown)

        NesUI.text(context, "TM", x: ox + TitleScreenView.capsuleX + TitleScreenView.capsuleW - 16,
                  y: TitleScreenView.capsuleY + TitleScreenView.capsuleH - 12, scale: 1, spacing: 1, color: NesUI.white)
    }

    private func drawMenuPanel(_ context: GraphicsContext, ox: CGFloat) {
        NesUI.roundRect(context, x: ox + TitleScreenView.panelX, y: TitleScreenView.panelY,
                        w: TitleScreenView.panelW, h: TitleScreenView.panelH, r: 8, color: NesUI.black)

        // Panelin solunda doktor, sağında virüs (orijinal ekrandaki gibi).
        NesUI.image(context, assets.doctor, x: ox + 26, y: TitleScreenView.panelY + 8, w: 26, h: 46)
        NesUI.image(context, assets.virusBlue, x: ox + 198, y: TitleScreenView.panelY + 16, w: 30, h: 30)

        // Satırlar orijinaldeki gibi ortak bir sol kenardan hizalanır; kalp imleci de
        // o kenarın solunda sabit bir sütunda durur.
        let blockX = ox + TitleScreenView.menuCenterX - widestMenuWidth() / 2
        for i in 0..<modes.count {
            let y = TitleScreenView.menuTopBaseline - CGFloat(i) * TitleScreenView.menuLineStep
            NesUI.text(context, modes[i].menuLabel, x: blockX, y: y, scale: TitleScreenView.menuScale,
                      spacing: TitleScreenView.menuSpacing, color: NesUI.white)
            if i == selected {
                NesUI.heart(context, x: blockX - 14, y: y, scale: 1.6, color: NesUI.red)
            }
        }

        // Henüz oynanışı olmayan modlar seçilip onaylanınca yanıp sönen uyarı.
        if timing.comingSoonTimer > 0 && Int(timing.blinkTimer * 4) % 2 == 0 {
            NesUI.textCentered(context, "COMING SOON", centerX: ox + GameConfig.contentWidth / 2, y: 10,
                              scale: 1, spacing: 3, color: NesUI.yellow)
        }
    }

    private func widestMenuWidth() -> CGFloat {
        var max_: CGFloat = 0
        for m in modes {
            max_ = max(max_, PixelFont.width(m.menuLabel, scale: TitleScreenView.menuScale, spacing: TitleScreenView.menuSpacing))
        }
        return max_
    }

    private func confirm() {
        let mode = modes[selected]
        guard mode.playable else {
            timing.comingSoonTimer = 1.8
            return
        }
        coordinator.route = .levelSelect(mode)
    }
}
