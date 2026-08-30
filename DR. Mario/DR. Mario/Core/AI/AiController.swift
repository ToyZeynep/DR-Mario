//
//  AiController.swift
//  DR. Mario
//
//  Port of com.rummuscan.core.ai.AiController.
//
//  GameEngine'i dışarıdan, tıpkı bir insan oyuncu gibi input API'si (moveLeft/
//  moveRight/rotateCW/hardDrop) üzerinden yönetir. Motorun içine hiçbir özel
//  erişimi yoktur — bu sayede online modda "rakip AI" yerine gerçek bir insan
//  oynatılsa bile mimari değişmez.
//
//  Kullanım: her engine.tick() çağrısından hemen önce (ya da sonra, tutarlı
//  olduğu sürece fark etmez) ai.update() de çağrılmalı.
//
//  NOT: Bu sınıf şu an hiçbir ekrandan kullanılmıyor (CPU VS modu henüz oynanabilir
//  değil, bkz. GameMode) — kaynak paritesi için birebir taşındı.

import Foundation

final class AiController {

    private let engine: GameEngine
    private let difficulty: Difficulty
    private var decisionRng: SeededRandom

    private var lastSeenCapsule: Capsule? // referans karşılaştırması: yeni kapsül geldi mi?
    private var plan: [ActionType]?
    private var ticksUntilNextAction = 0

    init(engine: GameEngine, difficulty: Difficulty, decisionSeed: UInt64) {
        self.engine = engine
        self.difficulty = difficulty
        self.decisionRng = SeededRandom(seed: decisionSeed)
    }

    /// Her engine tick'inde bir kez çağrılmalı.
    func update() {
        guard engine.state == .running else { return }
        // Temizleme/düşme animasyonu sürerken motor input kabul etmiyor, AI da beklesin.
        guard engine.phase == .control else { return }

        guard let current = engine.currentCapsule else { return }

        if current !== lastSeenCapsule {
            lastSeenCapsule = current
            plan = computePlan(current)
            ticksUntilNextAction = difficulty.reactionDelayTicks
            return
        }

        guard plan != nil, !plan!.isEmpty else { return }

        if ticksUntilNextAction > 0 {
            ticksUntilNextAction -= 1
            return
        }

        let action = plan!.removeFirst()
        execute(action)
        ticksUntilNextAction = difficulty.actionSpacingTicks
    }

    // ---- Planlama ----

    private enum ActionType { case rotateCW, moveLeft, moveRight, hardDrop }

    private struct Candidate {
        let col: Int
        let orientation: Orientation
        let score: Double
    }

    private func computePlan(_ capsule: Capsule) -> [ActionType] {
        let board = engine.board
        let colorA = capsule.colorA
        let colorB = capsule.colorB

        var candidates: [Candidate] = []
        for orientation in Orientation.allCases {
            for col in 0..<board.width {
                guard let row = findLandingRow(board: board, probe: capsule, col: col, orientation: orientation) else {
                    continue // bu sütun/orientation'da hiç yer yok
                }

                let sim = board.copy()
                let placed = Capsule(pivotCol: col, pivotRow: row, orientation: orientation, colorA: colorA, colorB: colorB)
                sim.lockCapsule(placed)
                sim.applyGravityFully() // yerleşen yarılar havada kalmışsa önce düşsün

                // Kilitlenen kapsülün her iki yarısının, aynı renkte kaç komşusu var?
                // Bu, henüz eşleşme tamamlanmasa bile "doğru yöne" ilerlemeyi ödüllendirir.
                let a = placed.cellA
                let b = placed.cellB
                let colorAffinity = countSameColorNeighbors(sim, col: a.col, row: a.row, color: colorA)
                    + countSameColorNeighbors(sim, col: b.col, row: b.row, color: colorB)

                let result = sim.resolveCascade()

                let score = evaluate(result, sim, colorAffinity: colorAffinity)
                candidates.append(Candidate(col: col, orientation: orientation, score: score))
            }
        }

        if candidates.isEmpty {
            return [] // yerleşecek yer yok, board zaten kaybedecek durumda
        }

        candidates.sort { $0.score > $1.score }

        var chosen = candidates[0]
        if candidates.count > 1 && decisionRng.nextDouble() < difficulty.mistakeProbability {
            let range = min(3, candidates.count - 1)
            chosen = candidates[1 + decisionRng.nextInt(range)]
        }

        return buildActionList(capsule, target: chosen)
    }

    /// Verilen sütun/orientation'da kapsülün inebileceği en alt satırı bulur (nil: hiç yer yok).
    /// 4 orientation'ın hepsiyle çalışır: üstten aşağı tarar, sığmayan ilk satırda durur.
    private func findLandingRow(board: Board, probe: Capsule, col: Int, orientation: Orientation) -> Int? {
        var lastFit: Int? = nil
        var started = false
        for row in 0..<board.height {
            if probe.fitsAt(board, col: col, row: row, orientation: orientation) {
                lastFit = row
                started = true
            } else if started {
                break // yığına çarptı, daha aşağı inemez
            }
        }
        return lastFit
    }

    private func buildActionList(_ capsule: Capsule, target: Candidate) -> [ActionType] {
        var actions: [ActionType] = []

        // Hedef duruma kaç kez saat yönünde dönmek gerekiyor? (RIGHT->UP->DOWN->RIGHT)
        var o = capsule.orientation
        var rotations = 0
        while o != target.orientation && rotations < Orientation.allCases.count {
            o = o.next()
            rotations += 1
        }
        for _ in 0..<rotations {
            actions.append(.rotateCW)
        }

        // NOT: Rotasyon sonrası wall-kick ile pivotCol 1 kayabilir; basitlik için bu
        // durumu ihmal ediyoruz (nadir, sadece kenar sütunlarda olur).
        let currentCol = capsule.pivotCol
        let diff = target.col - currentCol
        let moveAction: ActionType = diff > 0 ? .moveRight : .moveLeft
        for _ in 0..<abs(diff) {
            actions.append(moveAction)
        }

        actions.append(.hardDrop)
        return actions
    }

    private func execute(_ action: ActionType) {
        switch action {
        case .rotateCW: engine.rotateCW()
        case .moveLeft: engine.moveLeft()
        case .moveRight: engine.moveRight()
        case .hardDrop: engine.hardDrop()
        }
    }

    // ---- Heuristik değerlendirme ----

    private func evaluate(_ result: Board.CascadeResult, _ simBoard: Board, colorAffinity: Int) -> Double {
        var score = 0.0

        // Virüs temizlemek her zaman en yüksek öncelik.
        score += Double(result.virusesCleared) * 100.0
        // Zincir/çoklu patlama biraz daha bonus (rakibe garbage gönderme fırsatı da yaratıyor).
        score += Double(result.patlamaCount) * 5.0
        // Henüz eşleşme tamamlanmasa da aynı renkte komşuluk kurmak "doğru yöne" ilerlemektir.
        score += Double(colorAffinity) * 14.0

        let width = simBoard.width
        var heights = [Int](repeating: 0, count: width)
        var aggregateHeight = 0
        var maxHeight = 0
        for col in 0..<width {
            let h = columnHeight(simBoard, col: col)
            heights[col] = h
            aggregateHeight += h
            maxHeight = max(maxHeight, h)
        }

        var bumpiness = 0
        for col in 0..<(width - 1) {
            bumpiness += abs(heights[col] - heights[col + 1])
        }

        let holes = countHoles(simBoard)

        score -= Double(aggregateHeight) * 0.3
        score -= Double(bumpiness) * 0.2
        score -= Double(holes) * 2.0

        // Board'un tepesine çok yaklaşmak (spawn alanını tıkama riski) ağır ceza alsın.
        if maxHeight >= simBoard.height - 2 {
            score -= 50.0
        }

        return score
    }

    /// Verilen hücrenin 4 komşusundan kaçı aynı renkte dolu hücre? (eşleşmeye yaklaşma ölçütü)
    private func countSameColorNeighbors(_ board: Board, col: Int, row: Int, color: CapsuleColor) -> Int {
        let deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        var count = 0
        for d in deltas {
            let nc = col + d.0, nr = row + d.1
            if board.isInBounds(col: nc, row: nr) && !board.isEmpty(col: nc, row: nr)
                && board.getCell(col: nc, row: nr).color == color {
                count += 1
            }
        }
        return count
    }

    private func columnHeight(_ board: Board, col: Int) -> Int {
        for row in 0..<board.height {
            if !board.isEmpty(col: col, row: row) { return board.height - row }
        }
        return 0
    }

    private func countHoles(_ board: Board) -> Int {
        var holes = 0
        for col in 0..<board.width {
            var blockFound = false
            for row in 0..<board.height {
                if !board.isEmpty(col: col, row: row) {
                    blockFound = true
                } else if blockFound {
                    holes += 1
                }
            }
        }
        return holes
    }
}
