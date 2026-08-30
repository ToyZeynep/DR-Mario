//
//  GameCoordinator.swift
//  DR. Mario
//
//  libGDX'in Game.setScreen(...) ile ekranlar arası imperatif geçişinin SwiftUI karşılığı:
//  tek bir "route" yayınlanır, kök view bu route'a göre ilgili ekranı gösterir.
//  Akış aynı: TitleScreenView -> LevelSelectScreenView -> SinglePlayerScreenView.
//

import Foundation

enum Route {
    case title
    case levelSelect(GameMode)
    case singlePlayer(mode: GameMode, level: Int, speed: Speed, music: MusicType)
}

final class GameCoordinator: ObservableObject {
    @Published var route: Route = .title
}
