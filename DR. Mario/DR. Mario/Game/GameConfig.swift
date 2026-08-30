//
//  GameConfig.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.GameConfig.
//
//  Tüm ekranlar NES'in 256x224 çözünürlüğünde tasarlanır (yatay/landscape).
//  ExtendViewport mantığı: YÜKSEKLİK her cihazda tam olarak worldHeight birimdir,
//  GENİŞLİK ise cihazın en/boy oranına göre 256'nın üzerine taşar. NES'e ait 256
//  birimlik "içerik" alanı ekranda yatayda ortalanır (bkz. contentX), taşan kenarlar
//  dama zeminiyle doldurulur ve dokunmatik butonlara yer açar.
//

import CoreGraphics

enum GameConfig {
    static let tickDT: Double = 1.0 / 60.0 // sabit adım: saniyede 60 tick

    /// NES ekran yüksekliği; viewport bunu sabit tutar.
    static let worldHeight: CGFloat = 224
    /// NES ekran genişliği; ekranda ortalanan tasarım alanı.
    static let contentWidth: CGFloat = 256

    /// İçerik alanının sol kenarının dünya koordinatındaki yeri.
    static func contentX(_ worldWidth: CGFloat) -> CGFloat {
        (worldWidth - contentWidth) / 2
    }

    /// Bir hücrenin (virüs / hap yarısı) boyutu.
    ///
    /// NES'te hücre 8x8'di. Burada hücre ENİNE daha geniştir (13x10): şişe görselinin
    /// gövdesi 8x16'lık tahtaya göre epey "tombul" olduğu için, kare hücreyle tahta
    /// şişenin içinde ince bir şerit gibi kalıyor, haplar cam duvarlara değmiyordu.
    /// Hücre enine büyütülünce tahta şişenin iç boşluğunu TAM olarak dolduruyor
    /// (bkz. bottleFrameW) ve haplar iki yandan cama dayanıyor.
    ///
    /// Yükseklik 10'da kalmak zorunda: 16 satır * 10 = 160 birim tahta, şişenin
    /// omuz/boyun payıyla birlikte 224 birimlik ekranı zaten tam dolduruyor.
    static let cellW: CGFloat = 13
    static let cellH: CGFloat = 10
    static let boardPixelWidth: CGFloat = CGFloat(Board.defaultWidth) * cellW   // 104
    static let boardPixelHeight: CGFloat = CGFloat(Board.defaultHeight) * cellH // 160

    // ---- Oyun ekranı yerleşimi (içerik alanına göre, 0..256 / 0..224) ----

    /// Şişenin İÇİ (oyun tahtası) - yatayda ortalı.
    static let boardX: CGFloat = (contentWidth - boardPixelWidth) / 2 // 76
    static let boardY: CGFloat = 15

    // ---- Şişe çerçevesinin geometrisi (dikey dilimli çizim) ----
    //
    // ui/bottle_frame.png (640x1152) tek parça olarak ölçeklenirse bir sorun çıkıyor:
    // görselin gövdesi 8x16'lık tahtaya göre çok tombul. Tahtayı iç boşluğa oturtmak
    // için ya şişe yatayda eziliyor, ya haplar duvara değmiyor, ya da üst/alt köşedeki
    // haplar camın kıvrımının altında kalıyordu.
    //
    // Çözüm: şişe DÖRT DİKEY DİLİM hâlinde çiziliyor ve her dilim kendi yüksekliğine
    // ölçekleniyor - genişlik hepsinde aynı, yani şişenin silueti yatayda hiç bozulmuyor:
    //
    //   boyun  (görselin 0..180 px'i)  - düz boru, dikeyde kısaltmak şekli bozmaz
    //   omuz   (180..322)              - boyundan gövdeye geçiş
    //   gövde  (322..1076)             - düz duvar; tam olarak tahtanın yüksekliğine gerilir
    //   taban  (1076..1152)            - şişenin dibi; DOĞAL boyunda çizilir ki alt köşeler
    //                                    yuvarlaklığını korusun

    static let bottleImgW: CGFloat = 640
    static let bottleImgH: CGFloat = 1152
    /// Boyun / omuz sınırı (px, görselin üstünden).
    static let bottleSeamNeck: CGFloat = 180
    /// Omuz / gövde sınırı: buradan aşağısı sabit en kesitli düz duvar.
    static let bottleSeamBody: CGFloat = 322
    /// Gövde / taban sınırı, yani tahtanın ALT kenarı.
    static let bottleSeamFloor: CGFloat = 1076

    /// Gövdedeki iç boşluğun (cam duvarların arası) genişlik oranı: 36..603 px.
    private static let bottleInteriorRatio: CGFloat = 568.0 / bottleImgW
    /// Boyun/omuz/taban dilimleri dikeyde bu oranda kısaltılır.
    private static let bottleEndSquash: CGFloat = 0.75

    /// Şişenin çizim genişliği: iç boşluğu TAM olarak tahta kadar olsun diye seçilir.
    static let bottleFrameW: CGFloat = boardPixelWidth / bottleInteriorRatio // ~117
    /// Görselin bir pikselinin kaç birime denk geldiği (yatayda, yani doğal ölçek).
    private static let bottlePx: CGFloat = bottleFrameW / bottleImgW

    static let bottleNeckH: CGFloat = bottleSeamNeck * bottlePx * bottleEndSquash
    static let bottleShoulderH: CGFloat = (bottleSeamBody - bottleSeamNeck) * bottlePx * bottleEndSquash
    /// Gövde tam olarak tahtayı kaplar.
    static let bottleBodyH: CGFloat = boardPixelHeight
    /// Taban DOĞAL boyunda çizilir: alt köşelerin yuvarlaklığı korunsun.
    static let bottleFloorH: CGFloat = (bottleImgH - bottleSeamFloor) * bottlePx // ~13.9

    static let bottleFrameH: CGFloat = bottleNeckH + bottleShoulderH + bottleBodyH + bottleFloorH // ~218
    static let bottleFrameX: CGFloat = boardX - (bottleFrameW - boardPixelWidth) / 2 // ~69
    static let bottleFrameY: CGFloat = boardY - bottleFloorH // ~1.1

    // ---- HUD panelleri ----

    /// Sol üst pano: TOP / SCORE.
    static let scorePanelX: CGFloat = 1, scorePanelY: CGFloat = 162, scorePanelW: CGFloat = 66, scorePanelH: CGFloat = 58
    /// Sol alt büyüteç: tahtada kalan virüs renkleri.
    static let lensPanelX: CGFloat = -18, lensPanelY: CGFloat = 80, lensPanelW: CGFloat = 86, lensPanelH: CGFloat = 78
    /// Sağ üst: küçük Dr.MARIO logosu.
    static let logoCenterX: CGFloat = 216, logoY: CGFloat = 198, logoScale: CGFloat = 1.7
    /// Sağ orta: doktor + sıradaki hap.
    static let doctorPanelX: CGFloat = 189, doctorPanelY: CGFloat = 126, doctorPanelW: CGFloat = 66, doctorPanelH: CGFloat = 58
    /// Sağ alt pano: LEVEL / SPEED / VIRUS.
    static let levelPanelX: CGFloat = 189, levelPanelY: CGFloat = 60, levelPanelW: CGFloat = 66, levelPanelH: CGFloat = 54

    // ---- ui/notepad_panel.png içindeki kağıdın yeri ----
    //
    // Görsel 672x224; sarı çerçevenin içindeki açık mavi kağıt yatayda 33..639,
    // dikeyde (üstten) 48..195 pikselleri arasında.

    static let paperLeft: CGFloat = 33.0 / 672.0
    static let paperRight: CGFloat = 639.0 / 672.0
    static let paperBottom: CGFloat = (224.0 - 196.0) / 224.0
    static let paperTop: CGFloat = (224.0 - 48.0) / 224.0

    // ---- ui/microscope_bg.png içindeki merceğin yeri ----
    //
    // Görsel 672x224; camın (halkanın içindeki delik) merkezi 440,101 ve
    // yarıçapları 180x67 piksel.

    static let lensCenterX: CGFloat = 440.0 / 672.0
    static let lensCenterY: CGFloat = (224.0 - 101.0) / 224.0
    static let lensRadiusX: CGFloat = 180.0 / 672.0
    static let lensRadiusY: CGFloat = 67.0 / 224.0

    // ---- Oyun kuralları ----

    // Level hızları (gravity tick interval - ne kadar küçükse o kadar hızlı düşer)
    static let speedLow = 45
    static let speedMedium = 30
    static let speedHigh = 18

    static let defaultVirusCount = 20

    // Seviye seçim ekranı: klasik Dr. Mario'daki gibi 0-20 arası seviye, seviye başına 4 virüs artışı.
    static let minLevel = 0
    static let maxLevel = 20
    static let virusesPerLevel = 4

    static func virusCountForLevel(_ level: Int) -> Int {
        let count = (level + 1) * virusesPerLevel
        let cap = Board.defaultWidth * Board.defaultHeight / 2 // tahtanın yarısını asla geçmesin
        return min(count, cap)
    }
}
