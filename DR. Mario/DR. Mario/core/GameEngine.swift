//
//  GameEngine.swift
//  DR. Mario
//
//  com.rummuscan.core.GameEngine (VirusHunt Android sürümünden birebir).
//
//  Network'ten tamamen bağımsız, deterministic çekirdek motor. Single player, CPU vs ve Online vs
//  modlarının hepsi bu sınıfı kullanır.
//
//  DETERMINISM KURALI: tüm rastgelelik seed'li JavaRandom'dan gelir (Android'deki java.util.Random
//  ile aynı dizi). Aynı seed + aynı input sırası + aynı tick sayısı -> her cihazda aynı board.
//  Online VS'te iPhone ile Android aynı maçı bu sayede oynayabilir.
//
//  FAZ MAKİNESİ: CONTROL -> (kilitlendi) -> CLEAR_FLASH -> GRAVITY -> CLEAR_FLASH -> ... -> CONTROL
//  CEZA SIRASI: ... -> (cascade bitti) -> GARBAGE_FALL -> (hepsi indi) -> [eşleşme varsa cascade] -> CONTROL
//

import Foundation

final class GameEngine {

    enum Phase {
        case CONTROL      // oyuncu kapsülü kontrol ediyor
        case CLEAR_FLASH  // eşleşen hücreler yanıp sönüyor, henüz silinmedi
        case GRAVITY      // havada kalan kapsül yarıları adım adım düşüyor
        case GARBAGE_FALL // rakipten gelen ceza hapları tepeden iniyor
    }

    // Animasyon süreleri (tick cinsinden, 60 tick = 1 saniye)
    private static let CLEAR_FLASH_TICKS = 18
    private static let GRAVITY_STEP_TICKS = 7

    private let board: Board
    private let rng: JavaRandom
    /// Garbage için AYRI bir RNG (ana rng'nin hap renk akışını bozmasın diye).
    private let garbageRng: JavaRandom
    private let spawnCol: Int
    private let gravityTickInterval: Int

    private var currentCapsule: Capsule?
    private var nextColors: [CapsuleColor]
    private var ticksSinceLastFall = 0
    private var garbageFallTimer = 0
    private var pendingGarbage: [GarbageAttack] = []
    private var tickCount = 0
    private var state = GameState.RUNNING

    private var phase = Phase.CONTROL
    private var phaseTimer = 0
    private var flashingCells: [Coord] = []
    private var cascadePatlamaCount = 0
    private var cascadeColors = Set<CapsuleColor>()
    private var chainStep = 0
    private var score = 0
    private let scoreRules = ScoreRules()

    private var outgoingGarbage = 0
    private var outgoingGarbageColors = Set<CapsuleColor>()

    /// Bir saldırı paketi: kaç garbage hücresi ve hangi renk(ler)den seçilecekleri.
    struct GarbageAttack {
        let count: Int
        let colors: [CapsuleColor]

        static func of(_ count: Int, _ colors: CapsuleColor...) -> GarbageAttack {
            return GarbageAttack(count: count, colors: colors)
        }
    }

    convenience init(_ seed: Int64, _ virusCount: Int, _ gravityTickInterval: Int) {
        self.init(seed, virusCount, gravityTickInterval, Board.DEFAULT_HEIGHT / 2)
    }

    /// virusFillHeight: virüslerin yerleşebileceği, board'un ALTTAN itibaren kaç satırlık kısmı.
    init(_ seed: Int64, _ virusCount: Int, _ gravityTickInterval: Int, _ virusFillHeight: Int) {
        board = Board()
        rng = JavaRandom(seed)
        garbageRng = JavaRandom(seed ^ Int64(bitPattern: 0x9E3779B97F4A7C15))
        self.gravityTickInterval = gravityTickInterval
        spawnCol = board.getWidth() / 2 - 1

        let keepTopRowsClear = max(4, board.getHeight() - virusFillHeight)
        board.fillWithViruses(virusCount, rng, keepTopRowsClear)
        let a = CapsuleColor.random(rng)
        let b = CapsuleColor.random(rng)
        nextColors = [a, b]
        spawnNextCapsule()
    }

    func getBoard() -> Board { return board }
    func getState() -> GameState { return state }
    func getCurrentCapsule() -> Capsule? { return currentCapsule }
    func getSpawnCol() -> Int { return spawnCol }
    func getPhase() -> Phase { return phase }
    func getTickCount() -> Int { return tickCount }
    func getNextColors() -> [CapsuleColor] { return [nextColors[0], nextColors[1]] }
    func getScore() -> Int { return score }
    func getVirusesThisMove() -> Int { return scoreRules.getVirusesThisMove() }
    func getLastScoreGain() -> Int { return scoreRules.getLastGain() }
    func getChainStep() -> Int { return chainStep }
    func getFlashingCells() -> [Coord] { return flashingCells }
    func getPendingGarbageCount() -> Int { return pendingGarbage.count }

    /// CLEAR_FLASH fazının 0-1 arası ilerlemesi (yalnızca görsel).
    func getPhaseProgress() -> Float {
        if phase != .CLEAR_FLASH { return 0 }
        return 1 - (Float(phaseTimer) / Float(GameEngine.CLEAR_FLASH_TICKS))
    }

    /// Sabit adımlı ana güncelleme. Saniyede 60 kez çağrılmalı.
    func tick() {
        if state != .RUNNING { return }
        tickCount += 1

        switch phase {
        case .CONTROL: tickControl()
        case .CLEAR_FLASH: tickClearFlash()
        case .GRAVITY: tickGravity()
        case .GARBAGE_FALL: tickGarbageFall()
        }
    }

    private func tickControl() {
        ticksSinceLastFall += 1
        if ticksSinceLastFall >= gravityTickInterval {
            ticksSinceLastFall = 0
            if !tryMove(0, 1) {
                lockCapsule()
            }
        }
    }

    private func tickGarbageFall() {
        garbageFallTimer += 1
        if garbageFallTimer < gravityTickInterval { return }
        garbageFallTimer = 0

        if board.applyGravityStep() { return } // en az bir parça hâlâ iniyor

        cascadePatlamaCount = 0
        cascadeColors.removeAll()
        chainStep = 0
        if startClearIfMatches() { return }

        advanceToNextCapsule()
    }

    private func tickClearFlash() {
        phaseTimer -= 1
        if phaseTimer > 0 { return }

        board.clearGroups([flashingCells])
        flashingCells = []

        phase = .GRAVITY
        phaseTimer = GameEngine.GRAVITY_STEP_TICKS
    }

    private func tickGravity() {
        phaseTimer -= 1
        if phaseTimer > 0 { return }

        if board.applyGravityStep() {
            phaseTimer = GameEngine.GRAVITY_STEP_TICKS
            return
        }

        if startClearIfMatches() { return }

        finishCascade()
    }

    // ---- Input API ----

    func moveLeft() { if phase == .CONTROL { _ = tryMove(-1, 0) } }
    func moveRight() { if phase == .CONTROL { _ = tryMove(1, 0) } }

    func softDrop() {
        if phase != .CONTROL { return }
        if tryMove(0, 1) { ticksSinceLastFall = 0 }
    }

    func hardDrop() {
        if state != .RUNNING || phase != .CONTROL { return }
        while tryMove(0, 1) { /* devam */ }
        lockCapsule()
    }

    func rotateCW() { rotate(true) }
    func rotateCCW() { rotate(false) }

    // ---- Saldırı mekaniği ----

    /// Rakipten gelen cezayı SIRAYA alır; tahtaya hemen konmaz.
    func receiveGarbage(_ attack: GarbageAttack) {
        if state != .RUNNING || attack.count <= 0 { return }
        pendingGarbage.append(attack)
    }

    /// Bu cascade'de üretilen giden garbage miktarını + rengini okur ve sıfırlar.
    func drainOutgoingGarbage() -> GarbageAttack {
        let attack = GarbageAttack(count: outgoingGarbage, colors: CapsuleColor.allCases.filter { outgoingGarbageColors.contains($0) })
        outgoingGarbage = 0
        outgoingGarbageColors.removeAll()
        return attack
    }

    // ---- İç mantık ----

    private func tryMove(_ dCol: Int, _ dRow: Int) -> Bool {
        guard state == .RUNNING, let cap = currentCapsule else { return false }
        let newCol = cap.getPivotCol() + dCol
        let newRow = cap.getPivotRow() + dRow
        if !cap.fitsAt(board, newCol, newRow, cap.getOrientation()) {
            return false
        }
        cap.setPosition(newCol, newRow)
        return true
    }

    /// Köşe etrafında dönüş + wall-kick (bkz. Java sürümündeki ayrıntılı açıklama).
    private func rotate(_ clockwise: Bool) {
        guard state == .RUNNING, phase == .CONTROL, let cap = currentCapsule else { return }

        let from = cap.getOrientation()
        let target = clockwise ? from.next() : from.previous()

        let shift = pivotShift(from, target)
        let col = cap.getPivotCol() + shift.0
        let row = cap.getPivotRow() + shift.1

        let kicks = [(0, 0), (-1, 0), (1, 0), (0, 1), (0, -1)]
        for kick in kicks {
            let testCol = col + kick.0
            let testRow = row + kick.1
            if cap.fitsAt(board, testCol, testRow, target) {
                cap.setPosition(testCol, testRow)
                cap.setOrientation(target)
                return
            }
        }
        // Hiçbiri olmuyorsa rotasyon iptal
    }

    private func pivotShift(_ from: Orientation, _ to: Orientation) -> (Int, Int) {
        if from == .DOWN && to == .LEFT { return (1, 1) }
        if from == .LEFT && to == .UP { return (-1, 1) }
        if from == .UP && to == .LEFT { return (1, -1) }
        if from == .LEFT && to == .DOWN { return (-1, -1) }
        return (0, 0)
    }

    /// Kapsülü board'a sabitler ve cascade sürecini başlatır.
    private func lockCapsule() {
        guard let cap = currentCapsule else { return }
        board.lockCapsule(cap)
        currentCapsule = nil
        cascadePatlamaCount = 0
        cascadeColors.removeAll()
        chainStep = 0

        if startClearIfMatches() { return }

        advanceToNextCapsule()
    }

    private func advanceToNextCapsule() {
        if !pendingGarbage.isEmpty {
            startGarbageTurn(pendingGarbage.removeFirst())
            return
        }
        phase = .CONTROL
        ticksSinceLastFall = 0
        spawnNextCapsule()
        checkLossCondition()
    }

    private func startGarbageTurn(_ attack: GarbageAttack) {
        board.insertGarbage(attack.count, attack.colors, garbageRng)
        currentCapsule = nil
        phase = .GARBAGE_FALL
        garbageFallTimer = 0
        scoreRules.beginMove()
    }

    /// Board'da eşleşme varsa CLEAR_FLASH fazını başlatır ve true döner.
    private func startClearIfMatches() -> Bool {
        let groups = board.findMatchGroups()
        if groups.isEmpty { return false }

        cascadePatlamaCount += board.countMatchRuns()
        chainStep += 1

        flashingCells = []
        var seen = Set<Coord>()
        var virusesCleared = 0
        for group in groups {
            for cell in group {
                if !seen.insert(cell).inserted { continue }
                flashingCells.append(cell)
                let cleared = board.getCell(cell.col, cell.row)
                if let c = cleared.color { cascadeColors.insert(c) }
                if cleared.type == .VIRUS { virusesCleared += 1 }
            }
        }

        score += scoreRules.award(virusesCleared)

        phase = .CLEAR_FLASH
        phaseTimer = GameEngine.CLEAR_FLASH_TICKS
        return true
    }

    /// Cascade bitti: saldırı hesabı, kazanma kontrolü, yeni kapsül.
    private func finishCascade() {
        // 1 patlamada gönderim yok; 2 -> 2, 3 -> 3, 4+ -> 4.
        if cascadePatlamaCount >= 2 {
            outgoingGarbage += min(cascadePatlamaCount, 4)
            outgoingGarbageColors.formUnion(cascadeColors)
        }
        cascadePatlamaCount = 0

        if board.getVirusCount() == 0 {
            state = .WON
            return
        }

        advanceToNextCapsule()
    }

    private func spawnNextCapsule() {
        // YENİ İLAÇ = YENİ HAMLE: artan puan sayacı burada sıfırlanır.
        scoreRules.beginMove()

        let a = nextColors[0]
        let b = nextColors[1]
        let n0 = CapsuleColor.random(rng)
        let n1 = CapsuleColor.random(rng)
        nextColors = [n0, n1]

        currentCapsule = Capsule(spawnCol, 0, .RIGHT, a, b)
    }

    /// Ödüllü reklamla devam (yalnızca tek kişilik): şişenin üst yarısı boşaltılır.
    func revive() {
        if state != .LOST { return }
        board.clearTopRows(board.getHeight() / 2)
        pendingGarbage.removeAll()
        flashingCells = []
        if board.getVirusCount() == 0 {
            state = .WON
            return
        }
        state = .RUNNING
        phase = .CONTROL
        ticksSinceLastFall = 0
        spawnNextCapsule()
    }

    private func checkLossCondition() {
        if state == .RUNNING && board.isTopRowReached() {
            state = .LOST
        }
    }
}
