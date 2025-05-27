//
//  PieceType.swift
//  DR. Mario
//
//  Created by Zeynep Toy on 27.05.2025.
//


import SwiftUI
import Foundation

// MARK: - Game Models

enum PieceType {
    case empty
    case virus
    case pill
}

struct GamePiece {
    let type: PieceType
    let color: GameColor?
    
    static var empty: GamePiece {
        GamePiece(type: .empty, color: nil)
    }
    
    static func virus(color: GameColor) -> GamePiece {
        GamePiece(type: .virus, color: color)
    }
    
    static func pill(color: GameColor) -> GamePiece {
        GamePiece(type: .pill, color: color)
    }
}

enum GameColor: String, CaseIterable {
    case red, blue, yellow
    
    var swiftUIColor: Color {
        switch self {
        case .red: return .red
        case .blue: return .blue
        case .yellow: return .yellow
        }
    }
}

enum Orientation: CaseIterable {
    case horizontal      // ●●
    case vertical        // ●
                        // ●
    case horizontalFlip  // ●●
    case verticalFlip    // ●
                        // ●
    
    var next: Orientation {
        switch self {
        case .horizontal: return .vertical
        case .vertical: return .horizontalFlip
        case .horizontalFlip: return .verticalFlip
        case .verticalFlip: return .horizontal
        }
    }
}

struct FallingPill {
    var leftColor: GameColor
    var rightColor: GameColor
    var row: Int
    var col: Int
    var orientation: Orientation
    
    static func random() -> FallingPill {
        FallingPill(
            leftColor: GameColor.allCases.randomElement()!,
            rightColor: GameColor.allCases.randomElement()!,
            row: 0,
            col: 3,
            orientation: .horizontal
        )
    }
}

// MARK: - Game Logic

class DrMarioGame: ObservableObject {
    static let boardWidth = 8
    static let boardHeight = 16
    
    @Published var board: [[GamePiece]]
    @Published var currentPill: FallingPill?
    @Published var score = 0
    @Published var isRunning = false
    @Published var gameOver = false
    @Published var virusCount = 0
    
    private var gameTimer: Timer?
    
    init() {
        self.board = Array(repeating: Array(repeating: .empty, count: Self.boardWidth), count: Self.boardHeight)
        initializeGame()
    }
    
    func initializeGame() {
        // Boş tahta oluştur
        board = Array(repeating: Array(repeating: .empty, count: Self.boardWidth), count: Self.boardHeight)
        
        // Rastgele virüsler yerleştir
        let targetVirusCount = 12
        var placedViruses = 0
        
        while placedViruses < targetVirusCount {
            let row = Int.random(in: 8..<Self.boardHeight)
            let col = Int.random(in: 0..<Self.boardWidth)
            
            if board[row][col].type == .empty {
                let color = GameColor.allCases.randomElement()!
                board[row][col] = .virus(color: color)
                placedViruses += 1
            }
        }
        
        virusCount = targetVirusCount
        currentPill = FallingPill.random()
        score = 0
        gameOver = false
    }
    
    func startGame() {
        isRunning = true
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.dropPill()
        }
    }
    
    func pauseGame() {
        isRunning = false
        gameTimer?.invalidate()
        gameTimer = nil
    }
    
    func restartGame() {
        pauseGame()
        initializeGame()
        startGame()
    }
    
    func dropPill() {
        guard let pill = currentPill, !gameOver else { return }
        
        let newRow = pill.row + 1
        
        // Çarpışma kontrolü
        if newRow >= Self.boardHeight - 1 || isCollision(pill: pill, newRow: newRow) {
            placePillOnBoard()
            return
        }
        
        currentPill?.row = newRow
    }
    
    private func isCollision(pill: FallingPill, newRow: Int) -> Bool {
        if newRow >= Self.boardHeight {
            return true
        }
        
        // Sol parça kontrolü (her zaman var)
        if board[newRow][pill.col].type != .empty {
            return true
        }
        
        // Sağ parça kontrolü
        switch pill.orientation {
        case .horizontal, .horizontalFlip:
            // Yatay modlar: sağ tarafa bak
            if pill.col + 1 >= Self.boardWidth || board[newRow][pill.col + 1].type != .empty {
                return true
            }
        case .vertical, .verticalFlip:
            // Dikey modlar: alt tarafa bak
            if newRow + 1 >= Self.boardHeight || board[newRow + 1][pill.col].type != .empty {
                return true
            }
        }
        
        return false
    }
    
    private func placePillOnBoard() {
        guard let pill = currentPill else { return }
        
        // Parçaları yönelime göre yerleştir
        switch pill.orientation {
        case .horizontal:
            // Normal yatay: Sol-Sağ
            board[pill.row][pill.col] = .pill(color: pill.leftColor)
            if pill.col + 1 < Self.boardWidth {
                board[pill.row][pill.col + 1] = .pill(color: pill.rightColor)
            }
            
        case .vertical:
            // Normal dikey: Üst-Alt
            board[pill.row][pill.col] = .pill(color: pill.leftColor)
            if pill.row + 1 < Self.boardHeight {
                board[pill.row + 1][pill.col] = .pill(color: pill.rightColor)
            }
            
        case .horizontalFlip:
            // Ters yatay: Sağ-Sol
            board[pill.row][pill.col] = .pill(color: pill.rightColor)
            if pill.col + 1 < Self.boardWidth {
                board[pill.row][pill.col + 1] = .pill(color: pill.leftColor)
            }
            
        case .verticalFlip:
            // Ters dikey: Alt-Üst
            board[pill.row][pill.col] = .pill(color: pill.rightColor)
            if pill.row + 1 < Self.boardHeight {
                board[pill.row + 1][pill.col] = .pill(color: pill.leftColor)
            }
        }
        
        // Eşleşmeleri kontrol et
        checkMatches()
        
        // Yeni hap oluştur
        currentPill = FallingPill.random()
        
        // Oyun bitti mi kontrol et
        checkGameOver()
    }
    
    private func checkMatches() {
        var toRemove: Set<String> = []
        
        // Yatay kontrol
        for row in 0..<Self.boardHeight {
            var count = 1
            var currentColor = board[row][0].color
            
            for col in 1..<Self.boardWidth {
                if board[row][col].color == currentColor && currentColor != nil {
                    count += 1
                } else {
                    if count >= 4 && currentColor != nil {
                        for i in (col - count)..<col {
                            toRemove.insert("\(row)-\(i)")
                        }
                    }
                    count = 1
                    currentColor = board[row][col].color
                }
            }
            
            if count >= 4 && currentColor != nil {
                for i in (Self.boardWidth - count)..<Self.boardWidth {
                    toRemove.insert("\(row)-\(i)")
                }
            }
        }
        
        // Dikey kontrol
        for col in 0..<Self.boardWidth {
            var count = 1
            var currentColor = board[0][col].color
            
            for row in 1..<Self.boardHeight {
                if board[row][col].color == currentColor && currentColor != nil {
                    count += 1
                } else {
                    if count >= 4 && currentColor != nil {
                        for i in (row - count)..<row {
                            toRemove.insert("\(i)-\(col)")
                        }
                    }
                    count = 1
                    currentColor = board[row][col].color
                }
            }
            
            if count >= 4 && currentColor != nil {
                for i in (Self.boardHeight - count)..<Self.boardHeight {
                    toRemove.insert("\(i)-\(col)")
                }
            }
        }
        
        // Eşleşenleri sil
        if !toRemove.isEmpty {
            for position in toRemove {
                let components = position.split(separator: "-")
                let row = Int(components[0])!
                let col = Int(components[1])!
                
                // Virüs silindiyse sayacı azalt
                if board[row][col].type == .virus {
                    virusCount -= 1
                }
                
                board[row][col] = .empty
            }
            
            score += toRemove.count * 100
            
            // Yerçekimi uygula
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.applyGravity()
            }
        }
    }
    
    private func applyGravity() {
        var hasChanges = false
        
        // Her sütun için yerçekimi uygula
        for col in 0..<Self.boardWidth {
            // Alttan üste doğru kontrol et
            for row in (1..<Self.boardHeight).reversed() {
                if board[row][col].type == .pill {
                    // Bu hap düşebilir mi kontrol et
                    var targetRow = row
                    
                    // Mümkün olduğunca aşağı in
                    while targetRow + 1 < Self.boardHeight &&
                          board[targetRow + 1][col].type == .empty {
                        targetRow += 1
                    }
                    
                    // Eğer hareket edecekse
                    if targetRow != row {
                        board[targetRow][col] = board[row][col]
                        board[row][col] = .empty
                        hasChanges = true
                    }
                }
            }
        }
        
        // Eğer değişiklik olduysa tekrar kontrol et
        if hasChanges {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.checkMatches()
            }
        }
    }
    
    private func checkGameOver() {
        if virusCount == 0 {
            // Kazandı!
            gameOver = true
            pauseGame()
        }
    }
    
    // MARK: - Input Handling
    
    func moveLeft() {
        guard let pill = currentPill, isRunning, !gameOver else { return }
        
        if pill.col > 0 && !wouldCollideAfterMove(pill: pill, newCol: pill.col - 1) {
            currentPill?.col = pill.col - 1
        }
    }
    
    func moveRight() {
        guard let pill = currentPill, isRunning, !gameOver else { return }
        
        let maxCol: Int
        switch pill.orientation {
        case .horizontal, .horizontalFlip:
            maxCol = Self.boardWidth - 2 // Yatay modlar için
        case .vertical, .verticalFlip:
            maxCol = Self.boardWidth - 1 // Dikey modlar için
        }
        
        if pill.col < maxCol && !wouldCollideAfterMove(pill: pill, newCol: pill.col + 1) {
            currentPill?.col = pill.col + 1
        }
    }
    
    func rotatePill() {
        guard var pill = currentPill, isRunning, !gameOver else { return }
        
        pill.orientation = pill.orientation.next
        
        // Rotasyon sonrası çarpışma kontrolü
        if !wouldCollideAfterRotation(pill: pill) {
            currentPill = pill
        }
    }
    
    func fastDrop() {
        guard isRunning, !gameOver else { return }
        dropPill()
    }
    
    private func wouldCollideAfterMove(pill: FallingPill, newCol: Int) -> Bool {
        if newCol < 0 || newCol >= Self.boardWidth {
            return true
        }
        
        // Yatay modlar için sağ sınır kontrolü
        switch pill.orientation {
        case .horizontal, .horizontalFlip:
            if newCol + 1 >= Self.boardWidth {
                return true
            }
        case .vertical, .verticalFlip:
            break // Dikey modlar için ekstra kontrol yok
        }
        
        if pill.row >= Self.boardHeight {
            return false
        }
        
        // Ana parça kontrolü
        if board[pill.row][newCol].type != .empty {
            return true
        }
        
        // İkinci parça kontrolü
        switch pill.orientation {
        case .horizontal, .horizontalFlip:
            // Yatay: sağ parça kontrolü
            if board[pill.row][newCol + 1].type != .empty {
                return true
            }
        case .vertical, .verticalFlip:
            // Dikey: alt parça kontrolü
            if pill.row + 1 < Self.boardHeight && board[pill.row + 1][newCol].type != .empty {
                return true
            }
        }
        
        return false
    }
    
    private func wouldCollideAfterRotation(pill: FallingPill) -> Bool {
        // Ana hücre her zaman kontrol edilmeli
        if pill.row >= Self.boardHeight || board[pill.row][pill.col].type != .empty {
            return true
        }
        
        switch pill.orientation {
        case .horizontal, .horizontalFlip:
            // Yatay modlara geçerken sağ kontrol
            if pill.col + 1 >= Self.boardWidth {
                return true // Sağ sınır kontrolü
            }
            if board[pill.row][pill.col + 1].type != .empty {
                return true // Sağ hücre dolu mu?
            }
            
        case .vertical, .verticalFlip:
            // Dikey modlara geçerken alt kontrol
            if pill.row + 1 >= Self.boardHeight {
                return true // Alt sınır kontrolü
            }
            if board[pill.row + 1][pill.col].type != .empty {
                return true // Alt hücre dolu mu?
            }
        }
        
        return false
    }
}

// MARK: - SwiftUI Views

struct ContentView: View {
    @StateObject private var game = DrMarioGame()
    
    var body: some View {
        VStack(spacing: 16) {
            // Üst bilgi paneli
            HStack {
                VStack(alignment: .leading) {
                    Text("Dr. Mario")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 20) {
                        Text("Skor: \(game.score)")
                            .font(.headline)
                        
                        Text("Virüs: \(game.virusCount)")
                            .font(.headline)
                    }
                }
                
                Spacer()
                
                // Oyun kontrol butonları
                HStack(spacing: 12) {
                    Button(game.isRunning ? "Yeniden" : "Başla") {
                        game.restartGame()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption)
                    
                    Button("Durdur") {
                        game.pauseGame()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .disabled(!game.isRunning)
                }
            }
            .padding(.horizontal)
            
            // Oyun tahtası
            GameBoardView(game: game)
            
            // Alt kontrol paneli
            VStack(spacing: 16) {
                // Döndürme butonu
                Button("↻ Döndür") {
                    game.rotatePill()
                }
                .buttonStyle(.borderedProminent)
                .font(.title2)
                .disabled(!game.isRunning || game.gameOver)
                
                // Hareket kontrolleri
                HStack(spacing: 40) {
                    // Sol ok
                    Button("←") {
                        game.moveLeft()
                    }
                    .buttonStyle(.bordered)
                    .font(.title)
                    .frame(width: 60, height: 60)
                    .disabled(!game.isRunning || game.gameOver)
                    
                    // Aşağı ok (hızlı düşür)
                    Button("↓") {
                        game.fastDrop()
                    }
                    .buttonStyle(.bordered)
                    .font(.title)
                    .frame(width: 60, height: 60)
                    .disabled(!game.isRunning || game.gameOver)
                    
                    // Sağ ok
                    Button("→") {
                        game.moveRight()
                    }
                    .buttonStyle(.bordered)
                    .font(.title)
                    .frame(width: 60, height: 60)
                    .disabled(!game.isRunning || game.gameOver)
                }
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .focusable()
        .onKeyboardInput { key in
            handleKeyInput(key)
        }
    }
    
    private func handleKeyInput(_ key: String) {
        switch key.lowercased() {
        case "a":
            game.moveLeft()
        case "d":
            game.moveRight()
        case "s":
            game.fastDrop()
        case "w":
            game.rotatePill()
        default:
            break
        }
    }
}

struct GameBoardView: View {
    @ObservedObject var game: DrMarioGame
    
    var body: some View {
        VStack(spacing: 1) {
            ForEach(0..<DrMarioGame.boardHeight, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<DrMarioGame.boardWidth, id: \.self) { col in
                        CellView(piece: getPieceAt(row: row, col: col))
                    }
                }
            }
        }
        .padding(4)
        .background(Color.black)
        .cornerRadius(8)
    }
    
    private func getPieceAt(row: Int, col: Int) -> GamePiece {
        // Önce mevcut hapı kontrol et
        if let pill = game.currentPill {
            switch pill.orientation {
            case .horizontal:
                // Normal yatay: Sol-Sağ
                if pill.row == row && pill.col == col {
                    return .pill(color: pill.leftColor)
                } else if pill.row == row && pill.col + 1 == col {
                    return .pill(color: pill.rightColor)
                }
                
            case .vertical:
                // Normal dikey: Üst-Alt
                if pill.row == row && pill.col == col {
                    return .pill(color: pill.leftColor)
                } else if pill.row + 1 == row && pill.col == col {
                    return .pill(color: pill.rightColor)
                }
                
            case .horizontalFlip:
                // Ters yatay: Sağ-Sol
                if pill.row == row && pill.col == col {
                    return .pill(color: pill.rightColor)
                } else if pill.row == row && pill.col + 1 == col {
                    return .pill(color: pill.leftColor)
                }
                
            case .verticalFlip:
                // Ters dikey: Alt-Üst
                if pill.row == row && pill.col == col {
                    return .pill(color: pill.rightColor)
                } else if pill.row + 1 == row && pill.col == col {
                    return .pill(color: pill.leftColor)
                }
            }
        }
        
        // Sonra tahta parçasını döndür
        return game.board[row][col]
    }
}

struct CellView: View {
    let piece: GamePiece
    
    var body: some View {
        Rectangle()
            .fill(backgroundColor)
            .frame(width: 30, height: 30)
            .overlay(
                Text(pieceSymbol)
                    .font(.title3)
            )
            .border(Color.gray, width: 0.5)
    }
    
    private var backgroundColor: Color {
        switch piece.type {
        case .empty:
            return Color.white
        case .virus, .pill:
            return piece.color?.swiftUIColor.opacity(0.8) ?? Color.gray
        }
    }
    
    private var pieceSymbol: String {
        switch piece.type {
        case .empty:
            return ""
        case .virus:
            return "🦠"
        case .pill:
            return "💊"
        }
    }
}

// Keyboard input extension
extension View {
    func onKeyboardInput(_ action: @escaping (String) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .init("KeyboardInput"))) { notification in
            if let key = notification.object as? String {
                action(key)
            }
        }
    }
}

#Preview {
    ContentView()
}
