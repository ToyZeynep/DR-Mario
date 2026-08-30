//
//  SinglePlayerSession.swift
//  DR. Mario
//
//  SinglePlayerScreen.java'daki alanların (engine/input/assets/boardRenderer/controls) bir
//  arada tutulduğu, view'ın yeniden çizilmelerinden (TimelineView her karede Canvas'ı
//  yeniden çalıştırır) ETKİLENMEMESİ gereken referans tipli nesneler. @StateObject ile
//  bir kere oluşturulur, ekran süresince aynı örnek kalır.
//

import Foundation

final class SinglePlayerSession: ObservableObject {
    let engine: GameEngine
    let input: TouchInputHandler
    let assets = Assets()
    let boardRenderer: BoardRenderer
    let controls = TouchControls()

    // ---- Kare başı zamanlama durumu ----
    //
    // Bunlar bilerek @State/@Published DEĞİL: TimelineView'ın Canvas'ı her karede yeniden
    // çalıştırdığı tetikleyici (bkz. SinglePlayerScreenView.body) SwiftUI'nin normal
    // state-diffing döngüsünün DIŞINDadır; bu alanları @State yapmak ".onChange(of:)"
    // güvenilirliğine bel bağlamak anlamına geliyordu ve pratikte karelerin bir kısmını
    // atlayıp arada sırada "birikmiş" delta'yı tek seferde işleyebiliyordu (oyuncu hiçbir şey
    // görmüyor, sonra tahta aniden doluyor gibi). Düz bir sınıf alanı olarak tutulunca
    // tick() render kapanışının İÇİNDEN çağrılabiliyor, her karede garanti çalışıyor.
    var accumulator: Double = 0
    var blinkTimer: Double = 0
    var gameOverTimer: Double = 0
    var topScore: Int = ScoreStore.getTopScore()
    var lastTimestamp: Date?

    init(level: Int, speed: Speed) {
        // Tek oyunculukta seed önemsiz, gerçek rastgele üretilebilir.
        let seed = UInt64.random(in: UInt64.min...UInt64.max)
        let e = GameEngine(seed: seed, virusCount: GameConfig.virusCountForLevel(level), gravityTickInterval: speed.tickInterval)
        engine = e
        input = TouchInputHandler(engine: e)
        boardRenderer = BoardRenderer(assets: assets, originX: GameConfig.boardX, originY: GameConfig.boardY,
                                      cellW: GameConfig.cellW, cellH: GameConfig.cellH)
    }
}
