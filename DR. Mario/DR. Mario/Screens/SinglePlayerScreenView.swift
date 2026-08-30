//
//  SinglePlayerScreenView.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.SinglePlayerScreen.
//
//  NES Dr. Mario oyun ekranı: yeşil dama zemin, ortada ilaç şişesi, solda TOP/SCORE panosu ile
//  kalan virüsleri gösteren büyüteç, sağda Dr.MARIO logosu, sıradaki hapı tutan doktor kutusu ve
//  LEVEL/SPEED/VIRUS panosu.
//
//  NOT (dokunmatik kontroller): Java sürümü tek bir input-processor üzerinden manuel çoklu-
//  parmak polling'i yapıyordu (bkz. TouchControls.swift'in başındaki not). Burada her buton
//  kendi DragGesture'ına sahip ayrı bir overlay view'dür; bu doğal olarak eşzamanlı çoklu
//  dokunuşu destekler.
//

import SwiftUI

struct SinglePlayerScreenView: View {
    @EnvironmentObject private var coordinator: GameCoordinator
    let mode: GameMode
    let level: Int
    let speed: Speed
    let music: MusicType

    @StateObject private var session: SinglePlayerSession

    // Şişenin cam tonları (doğrudan ui/bottle_frame.png'den örneklendi): tabanın içini
    // doldurmak için kullanılır, böylece tahtanın altında ölü siyah alan kalmaz.
    private static let glassTop = Color(hex: 0xc8eefa)
    private static let glassBottom = Color(hex: 0xa6d5eb)
    private static let glassEdge = Color(hex: 0x8ec7e2)
    private static let lensGlass = Color(hex: 0x3070d8)
    private static let allColors: [CapsuleColor] = [.red, .yellow, .blue]
    /// Text alanının kağıdın kenarına yapışmaması için bırakılan pay.
    private static let textPad: CGFloat = 2

    // NOT: kare-başı zamanlama alanları (accumulator/blinkTimer/gameOverTimer/topScore/
    // lastTimestamp) burada DEĞİL, session (SinglePlayerSession) üzerinde tutuluyor - bkz.
    // oradaki not. rotateHeld ise gerçek bir kullanıcı-etkileşimi geri çağrısından (DragGesture)
    // değiştiği için sıradan @State olarak kalabilir.
    @State private var rotateHeld = false

    init(mode: GameMode, level: Int, speed: Speed, music: MusicType) {
        self.mode = mode
        self.level = level
        self.speed = speed
        self.music = music
        _session = StateObject(wrappedValue: SinglePlayerSession(level: level, speed: speed))
    }

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.height / GameConfig.worldHeight
            let worldW = geo.size.width / scale
            let ox = GameConfig.contentX(worldW)
            let _ = session.controls.layout(ox: ox, worldW: worldW)

            ZStack {
                TimelineView(.animation) { timeline in
                    // tick() BİLEREK burada, Canvas'ın KENDİ çizim kapanışının İÇİNDE
                    // çağrılıyor. Canvas'ın (context, size) kapanışı TimelineView(.animation)
                    // tarafından her ekran karesinde çalıştırılması GARANTİ edilen tek yer;
                    // bunu bir üst seviyeye (TimelineView'ın kendi içerik kapanışına) ya da ayrı
                    // bir .onChange(of: timeline.date) modifiye ediciye taşımak, SwiftUI'nin o
                    // sarmalayıcı kapanışı her karede yeniden çalıştırmayı garanti etmemesi
                    // yüzünden karelerin bir kısmını atlayıp "birikmiş" delta'yı tek seferde
                    // işleyebiliyordu (oyuncu hiçbir şey göremiyor, sonra tahta aniden doluyordu).
                    Canvas { context, _ in
                        tick(timeline.date)
                        context.scaleBy(x: scale, y: scale)
                        draw(context, ox: ox, worldW: worldW)
                    }
                }

                // Kontrol butonları HER ZAMAN mevcut (Java sürümü de controls.draw'ı running
                // durumundan bağımsız her karede çiziyordu); her butonun kendi callback'i
                // session.engine.state == .running değilken kendini no-op yapar. Oyun bitince
                // ekranın herhangi bir yerine dokunmak (butonların üstü dâhil) başlığa döner -
                // dismissGameOverIfAllowed() zaten yalnızca gameOverTimer birikmişken (yani
                // running değilken) devreye girdiği için running kontrolüne gerek yok.
                controlOverlays(ox: ox, scale: scale)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { dismissGameOverIfAllowed() })
            .focusable()
            .focusEffectDisabled()
            .onAppear {
                switch music {
                case .fever: MusicPlayer.shared.play(ChiptuneThemes.fever, name: "fever")
                case .chill: MusicPlayer.shared.play(ChiptuneThemes.chill, name: "chill")
                case .off: MusicPlayer.shared.stop()
                }
            }
            .onKeyPress(.leftArrow) { session.engine.moveLeft(); return .handled }
            .onKeyPress(.rightArrow) { session.engine.moveRight(); return .handled }
            .onKeyPress(.downArrow) { session.engine.softDrop(); return .handled }
            .onKeyPress(.upArrow) { session.input.triggerRotateCW(); return .handled }
            .onKeyPress(.space) {
                if session.engine.state == .running { session.input.triggerHardDrop() } else { dismissGameOverIfAllowed() }
                return .handled
            }
            .onKeyPress(.return) {
                if session.engine.state != .running { dismissGameOverIfAllowed() }
                return .handled
            }
            .onKeyPress(.escape) {
                if session.engine.state == .running { goToTitle() } else { dismissGameOverIfAllowed() }
                return .handled
            }
        }
        .ignoresSafeArea()
    }

    // ---- Döngü ----

    /// Her ekran karesinde bir kez çağrılır (bkz. body'deki not). Motoru sabit adımlarla
    /// ilerletir, dokunmatik DAS/ARR'ı ve buton basma animasyonunu günceller. Geri dönüş
    /// değeri o karede motorun RUNNING olup olmadığıdır (overlay seçimi için).
    @discardableResult
    private func tick(_ date: Date) -> Bool {
        let delta: Double
        if let last = session.lastTimestamp {
            delta = min(0.25, date.timeIntervalSince(last))
        } else {
            delta = 0
        }
        session.lastTimestamp = date
        session.blinkTimer += delta

        let running = session.engine.state == .running
        if running {
            session.input.update(delta: delta)

            // Sabit adımlı simülasyon: cihaz FPS'i ne olursa olsun engine hep aynı DT ile ilerler.
            session.accumulator += delta
            while session.accumulator >= GameConfig.tickDT {
                session.engine.tick()
                session.accumulator -= GameConfig.tickDT
            }
            if session.engine.score > session.topScore { session.topScore = session.engine.score }
        } else {
            if session.gameOverTimer == 0 { session.topScore = ScoreStore.reportScore(session.engine.score) }
            session.gameOverTimer += delta
            session.controls.releaseAll()
        }
        session.controls.update(delta: delta)
        return running
    }

    // ---- Dokunmatik kontroller (overlay) ----

    @ViewBuilder
    private func controlOverlays(ox: CGFloat, scale: CGFloat) -> some View {
        moveButton(TouchControls.left, scale: scale,
                  onDown: { guard session.engine.state == .running else { return }; session.input.setLeftHeld(true); session.controls.setPressed(TouchControls.left, true) },
                  onUp: { session.input.setLeftHeld(false); session.controls.setPressed(TouchControls.left, false) })
        moveButton(TouchControls.right, scale: scale,
                  onDown: { guard session.engine.state == .running else { return }; session.input.setRightHeld(true); session.controls.setPressed(TouchControls.right, true) },
                  onUp: { session.input.setRightHeld(false); session.controls.setPressed(TouchControls.right, false) })
        moveButton(TouchControls.down, scale: scale,
                  onDown: { guard session.engine.state == .running else { return }; session.input.setDownHeld(true); session.controls.setPressed(TouchControls.down, true) },
                  onUp: { session.input.setDownHeld(false); session.controls.setPressed(TouchControls.down, false) })

        let rotRect = NesUI.screenRect(fromNES: session.controls.hitArea(TouchControls.rotate), scale: scale)
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: rotRect.width, height: rotRect.height)
            .position(x: rotRect.midX, y: rotRect.midY)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard session.engine.state == .running else { return }
                    if !rotateHeld {
                        rotateHeld = true
                        session.input.triggerRotateCW()
                    }
                    session.controls.setPressed(TouchControls.rotate, true)
                }
                .onEnded { _ in
                    rotateHeld = false
                    session.controls.setPressed(TouchControls.rotate, false)
                })
    }

    private func moveButton(_ index: Int, scale: CGFloat, onDown: @escaping () -> Void, onUp: @escaping () -> Void) -> some View {
        let r = NesUI.screenRect(fromNES: session.controls.hitArea(index), scale: scale)
        return Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: r.width, height: r.height)
            .position(x: r.midX, y: r.midY)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in onDown() }
                .onEnded { _ in onUp() })
    }

    private func dismissGameOverIfAllowed() {
        guard session.gameOverTimer >= 0.6 else { return }
        goToTitle()
    }

    private func goToTitle() {
        coordinator.route = .title
    }

    // ---- Çizim ----

    private func draw(_ context: GraphicsContext, ox: CGFloat, worldW: CGFloat) {
        let running = session.engine.state == .running

        // 1) Zemin + şişe (tahtanın altında kalan her şey)
        NesUI.checkerboard(context, worldWidth: worldW, worldHeight: GameConfig.worldHeight, cell: 8,
                           a: NesUI.checkGreenA, b: NesUI.checkGreenB)
        drawBottle(context, ox: ox)

        // 2) Tahta (virüsler + haplar + patlama efektleri)
        session.boardRenderer.setOrigin(x: ox + GameConfig.boardX, y: GameConfig.boardY)
        session.boardRenderer.render(context, board: session.engine.board,
                                     falling: running ? session.engine.currentCapsule : nil,
                                     flashingCells: session.engine.flashingCells,
                                     flashProgress: session.engine.phaseProgress)

        // 3) HUD panelleri + dokunmatik butonlar
        drawScorePanel(context, ox: ox)
        drawLensPanel(context, ox: ox)
        drawLogo(context, ox: ox)
        drawDoctorPanel(context, ox: ox)
        drawLevelPanel(context, ox: ox)
        session.controls.draw(context)
        if !running { drawGameOverOverlay(context, ox: ox) }
    }

    /// Şişe dört dikey dilim hâlinde çizilir (dip / gövde / omuz / boyun); her dilim kendi
    /// yüksekliğine ölçeklenir ama genişlik hepsinde aynıdır, yani siluet yatayda hiç
    /// bozulmaz. Her dilimde önce iç boşluk boyanır, sonra cam görselinin o dilimi çizilir.
    private func drawBottle(_ context: GraphicsContext, ox: CGFloat) {
        let fx = ox + GameConfig.bottleFrameX
        let fw = GameConfig.bottleFrameW

        let floorY = GameConfig.bottleFrameY
        let bodyY = GameConfig.boardY
        let shoulderY = bodyY + GameConfig.bottleBodyH
        let neckY = shoulderY + GameConfig.bottleShoulderH

        // 1) İç boşluk: gövde ve yukarısı siyah, taban ise cam rengi (kalın cam dip).
        fillSliceInterior(context, x: fx, y: floorY, w: fw, h: GameConfig.bottleFloorH,
                          imgTop: GameConfig.bottleSeamFloor, imgBottom: GameConfig.bottleImgH,
                          bottom: SinglePlayerScreenView.glassTop, top: SinglePlayerScreenView.glassBottom, extendDown: 4)
        NesUI.rect(context, x: ox + GameConfig.boardX, y: GameConfig.boardY - 2.5,
                  w: GameConfig.boardPixelWidth, h: 2.5, color: SinglePlayerScreenView.glassTop)
        fillSliceInterior(context, x: fx, y: bodyY, w: fw, h: GameConfig.bottleBodyH,
                          imgTop: GameConfig.bottleSeamBody, imgBottom: GameConfig.bottleSeamFloor,
                          bottom: NesUI.black, top: NesUI.black, extendDown: 0)
        fillSliceInterior(context, x: fx, y: shoulderY, w: fw, h: GameConfig.bottleShoulderH,
                          imgTop: GameConfig.bottleSeamNeck, imgBottom: GameConfig.bottleSeamBody,
                          bottom: NesUI.black, top: NesUI.black, extendDown: 0)
        fillSliceInterior(context, x: fx, y: neckY, w: fw, h: GameConfig.bottleNeckH,
                          imgTop: 0, imgBottom: GameConfig.bottleSeamNeck,
                          bottom: NesUI.black, top: NesUI.black, extendDown: 0)

        // 2) Cam görseli, dilim dilim.
        if session.assets.hasBottleFrame {
            NesUI.image(context, session.assets.bottleFloorSlice, x: fx, y: floorY, w: fw, h: GameConfig.bottleFloorH)
            NesUI.image(context, session.assets.bottleBodySlice, x: fx, y: bodyY, w: fw, h: GameConfig.bottleBodyH)
            NesUI.image(context, session.assets.bottleShoulderSlice, x: fx, y: shoulderY, w: fw, h: GameConfig.bottleShoulderH)
            NesUI.image(context, session.assets.bottleNeckSlice, x: fx, y: neckY, w: fw, h: GameConfig.bottleNeckH)
        }

        // 3) Oyun alanı camın ÜSTÜNE çizilir.
        let bx = ox + GameConfig.boardX
        NesUI.rect(context, x: bx, y: GameConfig.boardY, w: GameConfig.boardPixelWidth, h: GameConfig.boardPixelHeight, color: NesUI.black)
        // Tabanın üst yüzeyi: haplar boşlukta durmasın diye ince bir cam çizgisi.
        NesUI.rect(context, x: bx, y: GameConfig.boardY - 1, w: GameConfig.boardPixelWidth, h: 1, color: SinglePlayerScreenView.glassEdge)
    }

    /// Bir dilimin iç boşluğunu satır satır boyar. Renk alttan üste bottom -> top geçişlidir.
    private func fillSliceInterior(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                   imgTop: CGFloat, imgBottom: CGFloat, bottom: Color, top: Color, extendDown: CGFloat) {
        guard let spans = session.assets.bottleInterior else { return }
        let rows = Int(ceil(h))
        for i in 0..<rows {
            let t = min(1, (CGFloat(i) + 0.5) / h) // 0 = dilimin altı
            let imgY = imgBottom - t * (imgBottom - imgTop) // görselde ÜSTTEN sayılır
            let sample = Int(((GameConfig.bottleImgH - 1 - imgY) / (GameConfig.bottleImgH - 1) * CGFloat(Assets.bottleSamples - 1)).rounded())
            guard let span = spans[max(0, min(Assets.bottleSamples - 1, sample))] else { continue }
            let color = bottom.lerp(to: top, t: t)
            NesUI.rect(context, x: x + span.left * w, y: y + CGFloat(i) - extendDown,
                      w: (span.right - span.left) * w, h: 1 + extendDown, color: color)
        }
    }

    // ---- HUD: not defteri panolarının kağıt alanı ----

    private func paperLeft(_ x: CGFloat, _ w: CGFloat) -> CGFloat { x + w * GameConfig.paperLeft }
    private func paperRight(_ x: CGFloat, _ w: CGFloat) -> CGFloat { x + w * GameConfig.paperRight }
    private func paperBottom(_ y: CGFloat, _ h: CGFloat) -> CGFloat { y + h * GameConfig.paperBottom }
    private func paperHeight(_ h: CGFloat) -> CGFloat { h * (GameConfig.paperTop - GameConfig.paperBottom) }

    /// Kağıdı rows eşit satıra böler; index. satırdaki yazının taban çizgisi.
    private func rowBaseline(_ y: CGFloat, _ h: CGFloat, _ rows: Int, _ index: Int) -> CGFloat {
        let ph = paperHeight(h)
        let rowH = ph / CGFloat(rows)
        return paperBottom(y, h) + ph - CGFloat(index + 1) * rowH + (rowH - CGFloat(PixelFont.glyphH)) / 2
    }

    // ---- HUD: sol üst pano (TOP / SCORE) ----

    private func drawScorePanel(_ context: GraphicsContext, ox: CGFloat) {
        let x = ox + GameConfig.scorePanelX, y = GameConfig.scorePanelY
        let w = GameConfig.scorePanelW, h = GameConfig.scorePanelH
        drawClipboard(context, x: x, y: y, w: w, h: h)

        // Dört satır da en uzun satıra (7 haneli skor) göre kağıtta ortalanır.
        let blockW = NesUI.textWidth("0000000", scale: 1, spacing: 2)
        let tx = paperLeft(x, w) + (paperRight(x, w) - paperLeft(x, w) - blockW) / 2

        NesUI.text(context, "TOP", x: tx, y: rowBaseline(y, h, 4, 0), scale: 1, spacing: 2, color: NesUI.black)
        NesUI.text(context, digits(session.topScore, 7), x: tx, y: rowBaseline(y, h, 4, 1), scale: 1, spacing: 2, color: NesUI.black)
        NesUI.text(context, "SCORE", x: tx, y: rowBaseline(y, h, 4, 2), scale: 1, spacing: 2, color: NesUI.black)
        NesUI.text(context, digits(session.engine.score, 7), x: tx, y: rowBaseline(y, h, 4, 3), scale: 1, spacing: 2, color: NesUI.black)
    }

    // ---- HUD: sol alt büyüteç (tahtada kalan virüs renkleri) ----

    private func drawLensPanel(_ context: GraphicsContext, ox: CGFloat) {
        let x = ox + GameConfig.lensPanelX, y = GameConfig.lensPanelY
        let w = GameConfig.lensPanelW, h = GameConfig.lensPanelH

        let lensCx = x + w * GameConfig.lensCenterX
        let lensCy = y + h * GameConfig.lensCenterY
        let lensRx = w * GameConfig.lensRadiusX
        let lensRy = h * GameConfig.lensRadiusY

        // Mavi dolgu deliğin biraz dışına taşar; taşan kısım büyütecin metal halkasının
        // altında kalır, böylece cam ile halka arasında boşluk çizgisi oluşmaz.
        NesUI.ellipse(context, centerX: lensCx, centerY: lensCy, rx: lensRx * 1.08, ry: lensRy * 1.14, color: SinglePlayerScreenView.lensGlass)
        NesUI.image(context, session.assets.microscopeBg, x: x, y: y, w: w, h: h)

        // Sadece tahtada hâlâ o renkten virüs kalmışsa gösterilir; konumlar orijinaldeki üçgen diziliş.
        let size = min(lensRx, lensRy) * 0.78
        let offsets: [(CGFloat, CGFloat)] = [
            (-lensRx * 0.45, lensRy * 0.32),   // kırmızı: sol üst
            (lensRx * 0.42, lensRy * 0.34),    // sarı: sağ üst
            (-lensRx * 0.02, -lensRy * 0.42),  // mavi: alt orta
        ]
        for i in 0..<SinglePlayerScreenView.allColors.count {
            let c = SinglePlayerScreenView.allColors[i]
            guard session.engine.board.hasVirusOfColor(c) else { continue }
            let tex = session.assets.virusFor(c)
            NesUI.image(context, tex, x: lensCx + offsets[i].0 - size / 2, y: lensCy + offsets[i].1 - size / 2, w: size, h: size)
        }
    }

    // ---- HUD: sağ üst Dr.MARIO logosu ----

    private func drawLogo(_ context: GraphicsContext, ox: CGFloat) {
        NesUI.textCenteredOutlined(context, "Dr.MARIO", centerX: ox + GameConfig.logoCenterX, y: GameConfig.logoY,
                                  scale: GameConfig.logoScale, spacing: 1, color: NesUI.yellow, outline: NesUI.darkBrown)
    }

    // ---- HUD: doktor + sıradaki hap ----

    private func drawDoctorPanel(_ context: GraphicsContext, ox: CGFloat) {
        let x = ox + GameConfig.doctorPanelX, y = GameConfig.doctorPanelY
        let w = GameConfig.doctorPanelW, h = GameConfig.doctorPanelH
        NesUI.roundRectBorder(context, x: x, y: y, w: w, h: h, r: 4, t: 2, border: NesUI.yellow, fill: NesUI.black)

        let dh = h - 10
        NesUI.image(context, session.assets.doctor, x: x + 8, y: y + 5, w: dh * 0.57, h: dh)

        // Sıradaki hap doktorun elinin üstünde durur (tahtadakiyle aynı çizim).
        let next = session.engine.nextColors
        let cw = GameConfig.cellW, ch = GameConfig.cellH
        let px = x + w - 8 - cw * 2
        let py = y + h - 12 - ch
        session.boardRenderer.drawPreviewHalf(context, x: px, y: py, w: cw, h: ch, color: next.0, leftHalf: true)
        session.boardRenderer.drawPreviewHalf(context, x: px + cw, y: py, w: cw, h: ch, color: next.1, leftHalf: false)
    }

    // ---- HUD: sağ alt pano (LEVEL / SPEED / VIRUS) ----

    private func drawLevelPanel(_ context: GraphicsContext, ox: CGFloat) {
        let x = ox + GameConfig.levelPanelX, y = GameConfig.levelPanelY
        let w = GameConfig.levelPanelW, h = GameConfig.levelPanelH
        drawClipboard(context, x: x, y: y, w: w, h: h)

        drawStatLine(context, x: x, y: y, w: w, h: h, row: 0, label: "LEVEL", value: digits(level, 2))
        drawStatLine(context, x: x, y: y, w: w, h: h, row: 1, label: "SPEED", value: speed.label)
        drawStatLine(context, x: x, y: y, w: w, h: h, row: 2, label: "VIRUS", value: digits(session.engine.board.virusCount, 2))
    }

    /// Etiket kağıdın soluna, değer sağına yaslanır; ikisi de kağıdın dışına çıkamaz.
    private func drawStatLine(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, row: Int, label: String, value: String) {
        let baseline = rowBaseline(y, h, 3, row)
        NesUI.text(context, label, x: paperLeft(x, w) + SinglePlayerScreenView.textPad, y: baseline, scale: 1, spacing: 2, color: NesUI.black)
        let vw = NesUI.textWidth(value, scale: 1, spacing: 2)
        NesUI.text(context, value, x: paperRight(x, w) - SinglePlayerScreenView.textPad - vw, y: baseline, scale: 1, spacing: 2, color: NesUI.black)
    }

    /// Not defteri panosu: görsel varsa o, yoksa kağıt renginde bir kutu.
    private func drawClipboard(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        if let panel = session.assets.notepadPanel {
            NesUI.image(context, panel, x: x, y: y, w: w, h: h)
        } else {
            NesUI.roundRectBorder(context, x: x, y: y, w: w, h: h, r: 3, t: 2, border: NesUI.yellow, fill: Color(hex: 0xd8e0f8))
        }
    }

    // ---- Oyun sonu ----

    private func drawGameOverOverlay(_ context: GraphicsContext, ox: CGFloat) {
        let won = session.engine.state == .won
        let cx = ox + GameConfig.contentWidth / 2
        let w: CGFloat = 136, h: CGFloat = 48
        let x = cx - w / 2
        let y = GameConfig.boardY + GameConfig.boardPixelHeight / 2 - h / 2

        NesUI.roundRectBorder(context, x: x, y: y, w: w, h: h, r: 6, t: 2, border: won ? NesUI.yellow : NesUI.red, fill: NesUI.black)
        NesUI.textCentered(context, won ? "STAGE CLEAR" : "GAME OVER", centerX: cx, y: y + h - 18, scale: 1, spacing: 3,
                          color: won ? NesUI.yellow : NesUI.white)
        if Int(session.blinkTimer * 2) % 2 == 0 {
            NesUI.textCentered(context, "PRESS START", centerX: cx, y: y + 10, scale: 1, spacing: 3, color: NesUI.white)
        }
    }

    private func digits(_ value: Int, _ count: Int) -> String {
        let s = String(max(0, value))
        if s.count >= count { return s }
        return String(repeating: "0", count: count - s.count) + s
    }
}
