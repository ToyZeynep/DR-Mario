//
//  AiController.swift
//  VirusHunt
//
//  com.rummuscan.core.ai.AiController + Difficulty (VirusHunt Android sürümünden birebir).
//
//  GameEngine'i dışarıdan, tıpkı bir insan oyuncu gibi input API'si üzerinden yönetir. Her yeni
//  hap için bir HEDEF (sütun + yön) seçilir; sonra hap her hamle adımında "önce yönü tuttur, sonra
//  sütunu tuttur" mantığıyla hedefe SÜRÜLÜR. Düşüşün nasıl biteceğini zorluk belirler.
//

import Foundation

enum Difficulty: CaseIterable {
    case EASY, MEDIUM, HARD

    /// Kapsül hedefe getirildikten SONRA CPU'nun düşüşü nasıl bitirdiği.
    enum DropStyle { case NONE, SOFT, HARD }

    private struct Params {
        let text: Txt
        let reactionDelayTicks: Int
        let actionSpacingTicks: Int
        let mistakeProbability: Double
        let mistakeRange: Int
        let placementErrorProbability: Double
        let lookaheadWeight: Double
        let lookaheadCandidates: Int
        let multiClearWeight: Double
        let virusFocus: Double
        let dropStyle: DropStyle
    }

    //    etiket  tepki  hamle  karar hatası  ıskalama  lookahead  çoklu   virüs  düşürme
    private var p: Params {
        switch self {
        case .EASY:   return Params(text: .DIFF_EASY, reactionDelayTicks: 30, actionSpacingTicks: 12, mistakeProbability: 0.55, mistakeRange: 10,
                                    placementErrorProbability: 0.25, lookaheadWeight: 0.0, lookaheadCandidates: 0, multiClearWeight: 0.0, virusFocus: 0.35, dropStyle: .NONE)
        case .MEDIUM: return Params(text: .DIFF_MED, reactionDelayTicks: 12, actionSpacingTicks: 5, mistakeProbability: 0.16, mistakeRange: 4,
                                    placementErrorProbability: 0.08, lookaheadWeight: 0.35, lookaheadCandidates: 4, multiClearWeight: 30.0, virusFocus: 1.0, dropStyle: .SOFT)
        // HARD'ın tepki/hamle gecikmesi bilerek SIFIR değil (bkz. Java yorumu).
        case .HARD:   return Params(text: .DIFF_HARD, reactionDelayTicks: 6, actionSpacingTicks: 1, mistakeProbability: 0.015, mistakeRange: 2,
                                    placementErrorProbability: 0.0, lookaheadWeight: 0.85, lookaheadCandidates: 8, multiClearWeight: 70.0, virusFocus: 1.25, dropStyle: .HARD)
        }
    }

    func label() -> String { return p.text.s() }
    var reactionDelayTicks: Int { return p.reactionDelayTicks }
    var actionSpacingTicks: Int { return p.actionSpacingTicks }
    var mistakeProbability: Double { return p.mistakeProbability }
    var mistakeRange: Int { return p.mistakeRange }
    var placementErrorProbability: Double { return p.placementErrorProbability }
    var lookaheadWeight: Double { return p.lookaheadWeight }
    var lookaheadCandidates: Int { return p.lookaheadCandidates }
    var multiClearWeight: Double { return p.multiClearWeight }
    var virusFocus: Double { return p.virusFocus }
    var dropStyle: DropStyle { return p.dropStyle }

    func softDropIntervalTicks() -> Int { return max(1, actionSpacingTicks) }

    var ordinal: Int { return Difficulty.allCases.firstIndex(of: self)! }
    func name() -> String {
        switch self { case .EASY: return "EASY"; case .MEDIUM: return "MEDIUM"; case .HARD: return "HARD" }
    }
}

final class AiController {

    private let engine: GameEngine
    private let difficulty: Difficulty
    private let decisionRng: JavaRandom

    private weak var lastSeenCapsule: Capsule?
    private var target: Target?
    private var ticksUntilNextAction = 0

    /// AI'nın motora uyguladığı her hamleyi dinlemek için (testler); ekranlarda nil.
    var listener: ((InputAction) -> Void)?

    init(_ engine: GameEngine, _ difficulty: Difficulty, _ decisionSeed: Int64) {
        self.engine = engine
        self.difficulty = difficulty
        decisionRng = JavaRandom(decisionSeed)
    }

    func setActionListener(_ l: ((InputAction) -> Void)?) { listener = l }

    private func apply(_ action: InputAction) {
        action.applyTo(engine)
        listener?(action)
    }

    /// Her engine tick'inde bir kez çağrılmalı.
    func update() {
        if engine.getState() != .RUNNING { return }
        if engine.getPhase() != .CONTROL { return }

        guard let current = engine.getCurrentCapsule() else { return }

        if current !== lastSeenCapsule {
            lastSeenCapsule = current
            target = computeTarget(current)
            ticksUntilNextAction = difficulty.reactionDelayTicks
            return
        }

        guard let t = target else { return }

        if ticksUntilNextAction > 0 {
            ticksUntilNextAction -= 1
            return
        }

        if !t.reached && steer(current, t) {
            ticksUntilNextAction = difficulty.actionSpacingTicks
            return
        }

        t.reached = true
        applyDropStyle()
    }

    private func steer(_ capsule: Capsule, _ target: Target) -> Bool {
        if capsule.getOrientation() != target.orientation {
            let before = capsule.getOrientation()
            apply(.ROTATE_CW)
            return capsule.getOrientation() != before
        }

        let diff = target.col - capsule.getPivotCol()
        if diff == 0 { return false }

        let before = capsule.getPivotCol()
        apply(diff > 0 ? .MOVE_RIGHT : .MOVE_LEFT)
        return capsule.getPivotCol() != before
    }

    private func applyDropStyle() {
        switch difficulty.dropStyle {
        case .HARD:
            apply(.HARD_DROP)
        case .SOFT:
            apply(.SOFT_DROP)
            ticksUntilNextAction = difficulty.softDropIntervalTicks()
        case .NONE:
            break
        }
    }

    // ---- Planlama ----

    private final class Target {
        let col: Int
        let orientation: Orientation
        var reached = false
        init(_ col: Int, _ orientation: Orientation) { self.col = col; self.orientation = orientation }
    }

    private final class Candidate {
        let col: Int
        let orientation: Orientation
        let score: Double
        let resultBoard: Board
        var finalScore: Double
        init(_ col: Int, _ orientation: Orientation, _ score: Double, _ resultBoard: Board) {
            self.col = col; self.orientation = orientation; self.score = score
            self.resultBoard = resultBoard; finalScore = score
        }
    }

    private func computeTarget(_ capsule: Capsule) -> Target? {
        let board = engine.getBoard()
        var candidates = evaluateCandidates(board, capsule.getColorA(), capsule.getColorB())

        if candidates.isEmpty { return nil }

        if difficulty.lookaheadWeight > 0.0 && difficulty.lookaheadCandidates > 0 {
            applyLookahead(candidates)
        }

        // Java List.sort kararlıdır (TimSort); eşit skorlar sırasını korur.
        candidates = stableSorted(candidates) { $0.finalScore > $1.finalScore }

        var chosen = candidates[0]
        if candidates.count > 1 && decisionRng.nextDouble() < difficulty.mistakeProbability {
            let range = min(difficulty.mistakeRange, candidates.count - 1)
            chosen = candidates[1 + decisionRng.nextInt(range)]
        }

        var col = chosen.col
        if decisionRng.nextDouble() < difficulty.placementErrorProbability {
            col += decisionRng.nextBoolean() ? 1 : -1
            col = max(0, min(board.getWidth() - 1, col))
        }

        return Target(col, chosen.orientation)
    }

    private func evaluateCandidates(_ board: Board, _ colorA: CapsuleColor, _ colorB: CapsuleColor) -> [Candidate] {
        var candidates: [Candidate] = []
        for orientation in Orientation.allCases {
            let probe = Capsule(0, 0, orientation, colorA, colorB)
            for col in 0..<board.getWidth() {
                let row = findLandingRow(board, probe, col, orientation)
                if row < 0 { continue }

                let sim = board.copy()
                let placed = Capsule(col, row, orientation, colorA, colorB)
                sim.lockCapsule(placed)
                sim.applyGravityFully()

                let a = placed.getCellA()
                let b = placed.getCellB()
                let colorAffinity = sameColorNeighborScore(sim, a.col, a.row, colorA)
                    + sameColorNeighborScore(sim, b.col, b.row, colorB)

                let result = sim.resolveCascade()

                let score = evaluate(result, sim, colorAffinity)
                candidates.append(Candidate(col, orientation, score, sim))
            }
        }
        return candidates
    }

    private func applyLookahead(_ candidates: [Candidate]) {
        let next = engine.getNextColors()
        let byScore = stableSorted(candidates) { $0.score > $1.score }

        let limit = min(difficulty.lookaheadCandidates, byScore.count)
        for i in 0..<limit {
            let candidate = byScore[i]
            let secondPly = evaluateCandidates(candidate.resultBoard, next[0], next[1])
            var bestNext = 0.0
            for c in secondPly { bestNext = max(bestNext, c.score) }
            candidate.finalScore = candidate.score + difficulty.lookaheadWeight * bestNext
        }
    }

    private func findLandingRow(_ board: Board, _ probe: Capsule, _ col: Int, _ orientation: Orientation) -> Int {
        var lastFit = -1
        var started = false
        for row in 0..<board.getHeight() {
            if probe.fitsAt(board, col, row, orientation) {
                lastFit = row
                started = true
            } else if started {
                break
            }
        }
        return lastFit
    }

    // ---- Heuristik değerlendirme ----

    private func evaluate(_ result: Board.CascadeResult, _ simBoard: Board, _ colorAffinity: Double) -> Double {
        var score = 0.0

        score += Double(result.virusesCleared) * 100.0
        score += Double(result.patlamaCount) * 5.0
        if result.patlamaCount >= 2 {
            score += Double(result.patlamaCount - 1) * difficulty.multiClearWeight
        }
        if result.virusesCleared >= 2 {
            score += Double(result.virusesCleared - 1) * difficulty.multiClearWeight * 0.5
        }
        score += colorAffinity * 6.0

        score += virusOutlook(simBoard) * difficulty.virusFocus

        let width = simBoard.getWidth()
        var heights = [Int](repeating: 0, count: width)
        var aggregateHeight = 0
        var maxHeight = 0
        for col in 0..<width {
            let h = columnHeight(simBoard, col)
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

        if maxHeight >= simBoard.getHeight() - 2 {
            score -= 50.0
        }
        let spawn = engine.getSpawnCol()
        var col = spawn
        while col <= spawn + 1 && col < width {
            let free = simBoard.getHeight() - heights[col]
            if free <= 4 { score -= Double(5 - free) * 15.0 }
            col += 1
        }

        return score
    }

    private func sameColorNeighborScore(_ board: Board, _ col: Int, _ row: Int, _ color: CapsuleColor) -> Double {
        let deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        var score = 0.0
        for d in deltas {
            let nc = col + d.0, nr = row + d.1
            if !board.isInBounds(nc, nr) || board.isEmpty(nc, nr) { continue }
            let cell = board.getCell(nc, nr)
            if cell.color == color { score += cell.type == .VIRUS ? 1.6 : 1.0 }
        }
        return score
    }

    private static let RUN_VALUE: [Double] = [0, 0, 7, 20]

    private func virusOutlook(_ board: Board) -> Double {
        let w = board.getWidth(), h = board.getHeight()
        var score = 0.0
        for r in 0..<h {
            for c in 0..<w {
                let v = board.getCell(c, r)
                guard v.type == .VIRUS, let vc = v.color else { continue }
                var best = -1
                for s in (r - 3)...r { best = max(best, AiController.windowCount(board, c, s, 0, 1, vc)) }
                for s in (c - 3)...c { best = max(best, AiController.windowCount(board, s, r, 1, 0, vc)) }
                if best > 0 { score += AiController.RUN_VALUE[min(best, 3)] }
            }
        }
        return score
    }

    private static func windowCount(_ board: Board, _ col: Int, _ row: Int, _ dc: Int, _ dr: Int, _ color: CapsuleColor) -> Int {
        var count = 0
        for k in 0..<4 {
            let cc = col + dc * k, rr = row + dr * k
            if !board.isInBounds(cc, rr) { return -1 }
            let cell = board.getCell(cc, rr)
            if cell.isEmpty() { continue }
            if cell.color != color { return -1 }
            count += 1
        }
        return count
    }

    private func columnHeight(_ board: Board, _ col: Int) -> Int {
        for row in 0..<board.getHeight() {
            if !board.isEmpty(col, row) { return board.getHeight() - row }
        }
        return 0
    }

    private func countHoles(_ board: Board) -> Int {
        var holes = 0
        for col in 0..<board.getWidth() {
            var blockFound = false
            for row in 0..<board.getHeight() {
                if !board.isEmpty(col, row) {
                    blockFound = true
                } else if blockFound {
                    holes += 1
                }
            }
        }
        return holes
    }
}

/// Kararlı sıralama (Java'nın List.sort'u gibi eşit öğelerin sırasını korur).
func stableSorted<T>(_ items: [T], by areInIncreasingOrder: (T, T) -> Bool) -> [T] {
    return items.enumerated().sorted { a, b in
        if areInIncreasingOrder(a.element, b.element) { return true }
        if areInIncreasingOrder(b.element, a.element) { return false }
        return a.offset < b.offset
    }.map { $0.element }
}
