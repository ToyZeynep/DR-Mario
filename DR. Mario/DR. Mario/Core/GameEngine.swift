//
//  GameEngine.swift
//  DR. Mario
//
//  Port of com.rummuscan.core.GameEngine.
//
//  Network'ten tamamen bağımsız, deterministic çekirdek motor.
//
//  FAZ MAKİNESİ: Kapsül kilitlendikten sonra temizleme ve düşme ANINDA olmaz;
//  oyuncunun izleyebilmesi için adım adım ilerler:
//    CONTROL -> (kilitlendi) -> CLEAR_FLASH -> GRAVITY -> CLEAR_FLASH -> ... -> CONTROL
//  Animasyon tamamen tick sayaçlarıyla yürüdüğü için determinizm korunur.
//

import Foundation

final class GameEngine {

    /// Motorun o anki fazı. Renderer bunu okuyup animasyonu doğru gösterebilir.
    enum Phase {
        case control     // oyuncu kapsülü kontrol ediyor
        case clearFlash  // eşleşen hücreler yanıp sönüyor, henüz silinmedi
        case gravity     // havada kalan kapsül yarıları adım adım düşüyor
    }

    // Animasyon süreleri (tick cinsinden, 60 tick = 1 saniye)
    private static let clearFlashTicks = 18 // ~0.3 sn eşleşme vurgusu
    private static let gravityStepTicks = 7 // her 1 satır düşüş ~0.12 sn

    let board: Board
    private var rng: SeededRandom
    let spawnCol: Int
    private let gravityTickInterval: Int // kaç tick'te bir kapsül 1 satır düşer

    private(set) var currentCapsule: Capsule?
    private var nextColorsStorage: (CapsuleColor, CapsuleColor)
    private var ticksSinceLastFall = 0
    private(set) var state: GameState = .running

    private(set) var phase: Phase = .control
    private var phaseTimer = 0
    /// CLEAR_FLASH fazında vurgulanan (henüz silinmemiş) hücreler; renderer okuyabilir.
    private(set) var flashingCells: Set<Coord> = []
    /// Devam eden cascade boyunca biriken patlama sayısı (saldırı hesabı için).
    private var cascadePatlamaCount = 0
    /// Aynı kilitlenmeden başlayan cascade içinde kaçıncı zincir adımındayız (bilgi amaçlı).
    private(set) var chainStep = 0
    private(set) var score = 0
    /// Skor kuralı: puanı yalnızca patlayan virüsler getirir ve aynı hamlede patlayan
    /// her virüs bir öncekinden 100 fazla verir (100 / 200 / 300 / 400 ...).
    private var scoreRules = ScoreRules()

    // Bu cascade'de üretilen, rakibe gönderilecek garbage miktarı.
    // Dışarıdaki (network/CPU) katman bunu okuyup sıfırlamalı: drainOutgoingGarbage()
    private var outgoingGarbage = 0

    convenience init(seed: UInt64, virusCount: Int, gravityTickInterval: Int) {
        self.init(seed: seed, virusCount: virusCount, gravityTickInterval: gravityTickInterval,
                  virusFillHeight: Board.defaultHeight / 2)
    }

    /// - Parameter virusFillHeight: Virüslerin yerleşebileceği, board'un ALTTAN itibaren kaç
    ///   satırlık kısmı (gerçek Dr. Mario'da bu, level ile artar).
    init(seed: UInt64, virusCount: Int, gravityTickInterval: Int, virusFillHeight: Int) {
        self.board = Board()
        self.rng = SeededRandom(seed: seed)
        self.gravityTickInterval = gravityTickInterval
        self.spawnCol = board.width / 2 - 1

        let keepTopRowsClear = max(4, board.height - virusFillHeight)
        board.fillWithViruses(virusTarget: virusCount, rng: &rng, keepTopRowsClear: keepTopRowsClear)
        self.nextColorsStorage = (CapsuleColor.random(&rng), CapsuleColor.random(&rng))
        spawnNextCapsule()
    }

    var nextColors: (CapsuleColor, CapsuleColor) { nextColorsStorage }
    /// Aynı hamlede şu ana kadar patlayan virüs sayısı (HUD'da zincir göstermek isterseniz).
    var virusesThisMove: Int { scoreRules.virusesThisMove }
    /// Son patlamanın getirdiği puan (ekranda "+600" göstermek için).
    var lastScoreGain: Int { scoreRules.lastGain }

    /// CLEAR_FLASH fazının 0(yeni başladı)-1(bitmek üzere) arası ilerlemesi; renderer bunu
    /// baloncuk patlaması animasyonunu (büyüme/solma) yürütmek için kullanır. Diğer fazlarda 0
    /// döner. Tamamen phaseTimer'dan türetildiği için determinizmi etkilemez, sadece görseldir.
    var phaseProgress: Float {
        guard phase == .clearFlash else { return 0 }
        return 1 - Float(phaseTimer) / Float(GameEngine.clearFlashTicks)
    }

    /// Sabit adımlı ana güncelleme. Saniyede 60 kez çağrılmalı.
    func tick() {
        guard state == .running else { return }

        switch phase {
        case .control: tickControl()
        case .clearFlash: tickClearFlash()
        case .gravity: tickGravity()
        }
    }

    private func tickControl() {
        ticksSinceLastFall += 1
        if ticksSinceLastFall >= gravityTickInterval {
            ticksSinceLastFall = 0
            if !tryMove(dCol: 0, dRow: 1) {
                lockCapsule()
            }
        }
    }

    private func tickClearFlash() {
        phaseTimer -= 1
        if phaseTimer > 0 { return }

        // Vurgulama süresi bitti: hücreleri gerçekten sil ve düşme fazına geç.
        board.clearGroups([flashingCells])
        flashingCells = []

        phase = .gravity
        phaseTimer = GameEngine.gravityStepTicks
    }

    private func tickGravity() {
        phaseTimer -= 1
        if phaseTimer > 0 { return }

        // Tek bir satırlık düşüş uygula — oyuncu her adımı ayrı ayrı görsün.
        if board.applyGravityStep() {
            phaseTimer = GameEngine.gravityStepTicks
            return
        }

        // Düşecek bir şey kalmadı: yeni eşleşme oluştu mu (zincir devam ediyor mu)?
        if startClearIfMatches() { return }

        // Cascade tamamen bitti: saldırı hesabını yap ve kontrolü oyuncuya geri ver.
        finishCascade()
    }

    // ---- Input API (GameEngine dışından, InputHandler tarafından çağrılır) ----
    // NOT: Animasyon fazlarında (CLEAR_FLASH/GRAVITY) input kabul edilmez.

    func moveLeft() { if phase == .control { _ = tryMove(dCol: -1, dRow: 0) } }
    func moveRight() { if phase == .control { _ = tryMove(dCol: 1, dRow: 0) } }

    /// Soft drop: bir satır aşağı zorla indirir, gravity tick'ini sıfırlar.
    func softDrop() {
        guard phase == .control else { return }
        if tryMove(dCol: 0, dRow: 1) { ticksSinceLastFall = 0 }
    }

    /// Hard drop: kapsül düşebildiği en alt noktaya iner ve hemen kilitlenir.
    func hardDrop() {
        guard state == .running, phase == .control else { return }
        while tryMove(dCol: 0, dRow: 1) { /* devam */ }
        lockCapsule()
    }

    func rotateCW() { rotate(clockwise: true) }
    func rotateCCW() { rotate(clockwise: false) }

    // ---- Saldırı mekaniği ----

    /// Rakipten gelen garbage'ı board'a ekler.
    func receiveGarbage(_ count: Int) {
        guard state == .running, count > 0 else { return }
        board.insertGarbage(count: count, rng: &rng)
        checkLossCondition()
    }

    /// Bu cascade'de üretilen giden garbage miktarını okur ve sıfırlar.
    func drainOutgoingGarbage() -> Int {
        let value = outgoingGarbage
        outgoingGarbage = 0
        return value
    }

    // ---- İç mantık ----

    @discardableResult
    private func tryMove(dCol: Int, dRow: Int) -> Bool {
        guard state == .running, let capsule = currentCapsule else { return false }
        let newCol = capsule.pivotCol + dCol
        let newRow = capsule.pivotRow + dRow
        guard capsule.fitsAt(board, col: newCol, row: newRow, orientation: capsule.orientation) else {
            return false
        }
        capsule.setPosition(col: newCol, row: newRow)
        return true
    }

    /// Köşe etrafında dönüş modeli (gerçek Dr. Mario'daki gibi): kapsülün iki yarısından
    /// biri olduğu hücrede SABİT kalır, diğer yarı o sabit hücrenin bitişiğine geçer.
    /// Saat yönünde sıra: RIGHT -> DOWN -> LEFT -> UP -> RIGHT.
    ///
    /// Hedef durum sığmazsa 1 sola / 1 sağa / 1 yukarı kaydırarak (wall-kick) denenir.
    private func rotate(clockwise: Bool) {
        guard state == .running, phase == .control, let capsule = currentCapsule else { return }

        let from = capsule.orientation
        let target = clockwise ? from.next() : from.previous()

        let shift = pivotShift(from: from, to: target)
        let col = capsule.pivotCol + shift.0
        let row = capsule.pivotRow + shift.1

        // Wall-kick denemeleri: önce hedef konumda, sonra sağa/sola, sonra aşağı/yukarı kaydırarak.
        let kicks: [(Int, Int)] = [(0, 0), (-1, 0), (1, 0), (0, 1), (0, -1)]
        for kick in kicks {
            let testCol = col + kick.0
            let testRow = row + kick.1
            if capsule.fitsAt(board, col: testCol, row: testRow, orientation: target) {
                capsule.setPosition(col: testCol, row: testRow)
                capsule.setOrientation(target)
                return
            }
        }
        // Hiçbiri olmuyorsa rotasyon iptal (klasik Dr. Mario davranışı)
    }

    /// Köşe etrafında dönüş modelinde, sabit kalmayan yarı bazı geçişlerde pivot
    /// (colorA'nın hücresi) olduğundan, pivot da onunla birlikte kayar.
    private func pivotShift(from: Orientation, to: Orientation) -> (Int, Int) {
        if from == .down && to == .left { return (1, 1) }
        if from == .left && to == .up { return (-1, 1) }
        if from == .up && to == .left { return (1, -1) }
        if from == .left && to == .down { return (-1, -1) }
        return (0, 0)
    }

    /// Kapsülü board'a sabitler ve cascade sürecini başlatır.
    private func lockCapsule() {
        guard let capsule = currentCapsule else { return }
        board.lockCapsule(capsule)
        currentCapsule = nil
        cascadePatlamaCount = 0
        chainStep = 0

        // Klasik Dr. Mario kuralı: kilitlenen kapsülün bir ucu boşluğun üstünde kalsa
        // bile DÜŞMEZ, olduğu yerde asılı kalır. Sadece eşi patlayınca gravity'ye tabi olur.
        if startClearIfMatches() { return }

        advanceToNextCapsule()
    }

    /// Yeni kapsül üretir ve kontrolü oyuncuya geri verir (kayıp kontrolüyle birlikte).
    private func advanceToNextCapsule() {
        phase = .control
        ticksSinceLastFall = 0
        spawnNextCapsule()
        checkLossCondition()
    }

    /// Board'da eşleşme varsa CLEAR_FLASH fazını başlatır ve true döner.
    /// Patlama sayısı (saldırı hesabı için) ve skor burada işlenir.
    @discardableResult
    private func startClearIfMatches() -> Bool {
        let groups = board.findMatchGroups()
        if groups.isEmpty { return false }

        cascadePatlamaCount += groups.count
        chainStep += 1

        var flashing: Set<Coord> = []
        var virusesCleared = 0
        for group in groups {
            for cell in group {
                if flashing.contains(cell) { continue } // aynı hücre tekrar geldi
                flashing.insert(cell)
                if board.getCell(col: cell.col, row: cell.row).type == .virus { virusesCleared += 1 }
            }
        }
        flashingCells = flashing

        // Puan sadece virüslerden gelir; temizlenen hap yarımları puan getirmez.
        // Aynı hamledeki virüsler sırayla 100, 200, 300, 400 ... puan verir.
        score += scoreRules.award(virusesCleared)

        phase = .clearFlash
        phaseTimer = GameEngine.clearFlashTicks
        return true
    }

    /// Cascade bitti: saldırı hesabı, kazanma kontrolü, yeni kapsül.
    private func finishCascade() {
        // Saldırı kuralı: 1 patlamada gönderim yok; 2 patlamada 2, 3 patlamada 3,
        // 4 ve üzeri patlamada 4 virüs (üst sınır 4).
        if cascadePatlamaCount >= 2 {
            outgoingGarbage += min(cascadePatlamaCount, 4)
        }
        cascadePatlamaCount = 0

        if board.virusCount == 0 {
            state = .won
            return
        }

        advanceToNextCapsule()
    }

    private func spawnNextCapsule() {
        // YENİ İLAÇ = YENİ HAMLE: artan puan sayacı (100/200/300...) burada sıfırlanır.
        scoreRules.beginMove()

        let a = nextColorsStorage.0
        let b = nextColorsStorage.1
        nextColorsStorage = (CapsuleColor.random(&rng), CapsuleColor.random(&rng))

        let capsule = Capsule(pivotCol: spawnCol, pivotRow: 0, orientation: .right, colorA: a, colorB: b)
        currentCapsule = capsule
        if !capsule.fitsAt(board, col: spawnCol, row: 0, orientation: .right) {
            state = .lost
        }
    }

    private func checkLossCondition() {
        if state == .running && board.isSpawnAreaBlocked(spawnCol: spawnCol) {
            state = .lost
        }
    }
}
