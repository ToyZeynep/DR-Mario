import Foundation

func boardStr(_ b: Board) -> String {
    var sb = ""
    for r in 0..<b.getHeight() { for c in 0..<b.getWidth() {
        let cell = b.getCell(c, r)
        sb += cell.debugString
        sb += cell.link == nil ? "-" : String(cell.link!.rawValue)
    } }
    return sb
}
func st(_ s: GameState) -> String { switch s { case .RUNNING: return "RUNNING"; case .WON: return "WON"; case .LOST: return "LOST" } }

let r = JavaRandom(42)
var rs = "rng"
for _ in 0..<20 { rs += " \(r.nextInt(7)),\(r.nextInt(8)),\(r.nextBoolean()),\(String(format: "%.12f", r.nextDouble())),\(r.nextLong())" }
print(rs)
let ds = Difficulty.allCases
for seed in 1...12 {
    let d = ds[seed % 3]
    let s = Int64(seed) * 7919 - 3
    let left = GameEngine(s, 8 + seed * 3, 20 + seed % 3 * 5)
    let right = GameEngine(s, 8 + seed * 3, 20 + seed % 3 * 5)
    let al = AiController(left, d, s ^ 99)
    let ar = AiController(right, ds[(seed + 1) % 3], s ^ 77)
    for t in 0..<6000 {
        al.update(); ar.update()
        left.tick(); right.tick()
        let g1 = left.drainOutgoingGarbage()
        let g2 = right.drainOutgoingGarbage()
        if g1.count > 0 { right.receiveGarbage(g1) }
        if g2.count > 0 { left.receiveGarbage(g2) }
        if t % 500 == 0 || left.getState() != .RUNNING || right.getState() != .RUNNING {
            print("\(seed) \(t) \(st(left.getState())) \(left.getScore()) \(left.getTickCount()) \(boardStr(left.getBoard()).javaHashCode) | \(st(right.getState())) \(right.getScore()) \(boardStr(right.getBoard()).javaHashCode)")
        }
        if VsOutcome.of(left.getState(), right.getState()).isDecided() { break }
    }
    print("\(seed) final \(boardStr(left.getBoard()))")
}
