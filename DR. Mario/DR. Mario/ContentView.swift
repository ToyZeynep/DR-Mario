//
//  ContentView.swift
//  DR. Mario
//
//  Created by Zeynep Toy on 27.05.2025.
//
//  Kök view: GameCoordinator'ın route'una göre ilgili ekranı gösterir. libGDX'teki
//  Game.setScreen(TitleScreen -> LevelSelectScreen -> SinglePlayerScreen) akışının
//  SwiftUI karşılığı (bkz. Screens/GameCoordinator.swift).
//

import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = GameCoordinator()

    var body: some View {
        Group {
            switch coordinator.route {
            case .title:
                TitleScreenView()
            case .levelSelect(let mode):
                LevelSelectScreenView(mode: mode)
            case .singlePlayer(let mode, let level, let speed, let music):
                SinglePlayerScreenView(mode: mode, level: level, speed: speed, music: music)
            }
        }
        .environmentObject(coordinator)
        .background(Color.black)
    }
}

#Preview {
    ContentView()
}
