//
//  MusicType.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.MusicType.
//
//  Ayar ekranındaki MUSIC TYPE seçeneği (NES: FEVER / CHILL / OFF).
//  Seçim oyuna taşınır ve saklanır; ses dosyaları projeye eklendiğinde
//  çalınacak parçayı bu değer belirleyecek. (Kaynak projede de henüz ses
//  dosyası yok; bu port da aynı şekilde kozmetik bir ayar olarak kalıyor.)
//

import Foundation

enum MusicType: CaseIterable {
    case fever
    case chill
    case off

    var label: String {
        switch self {
        case .fever: return "FEVER"
        case .chill: return "CHILL"
        case .off: return "OFF"
        }
    }
}
