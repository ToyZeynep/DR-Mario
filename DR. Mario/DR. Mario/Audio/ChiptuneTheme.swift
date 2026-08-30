//
//  ChiptuneTheme.swift
//  DR. Mario
//
//  Kodla üretilen, tamamen özgün (NES'in gerçek Dr. Mario müziğiyle hiçbir ilgisi olmayan)
//  basit iki kanallı (melodi + bas) chiptune temaları. Notalar bir dizi (isim, süre) çifti
//  olarak tanımlanır; frekans hesaplaması standart eşit tamperaman (A4 = 440 Hz) ile yapılır.
//

import Foundation

/// Tek bir nota: nil frekans = es (sessizlik). Süre "beat" cinsindendir (tempo ile çarpılır).
struct ChiptuneNote {
    let frequency: Double?
    let beats: Double

    static func rest(_ beats: Double) -> ChiptuneNote { ChiptuneNote(frequency: nil, beats: beats) }

    /// "C5", "D#4", "A3" gibi bir nota adını frekansa çevirir (bilimsel perde notasyonu).
    static func note(_ name: String, _ beats: Double) -> ChiptuneNote {
        ChiptuneNote(frequency: ChiptuneNote.frequency(for: name), beats: beats)
    }

    private static let pitchClasses: [String: Int] = [
        "C": 0, "C#": 1, "DB": 1, "D": 2, "D#": 3, "EB": 3, "E": 4, "F": 5,
        "F#": 6, "GB": 6, "G": 7, "G#": 8, "AB": 8, "A": 9, "A#": 10, "BB": 10, "B": 11,
    ]

    private static func frequency(for name: String) -> Double {
        let upper = name.uppercased()
        var idx = upper.index(after: upper.startIndex)
        if idx < upper.endIndex, upper[idx] == "#" || upper[idx] == "B" {
            idx = upper.index(after: idx)
        }
        let pitchName = String(upper[upper.startIndex..<idx])
        let octave = Int(upper[idx...]) ?? 4
        guard let pitchClass = pitchClasses[pitchName] else { return 440 }
        let midi = (octave + 1) * 12 + pitchClass
        return 440.0 * pow(2.0, Double(midi - 69) / 12.0)
    }
}

/// İki basit kanal: bir melodi (lead) ve bir bas hattı. İkisi de aynı toplam uzunlukta
/// olacak şekilde (aynı sayıda "bar") yazılmalı; ChiptuneRenderer ikisini karıştırır.
struct ChiptuneTheme {
    let tempoBPM: Double
    let lead: [ChiptuneNote]
    let bass: [ChiptuneNote]
}

enum ChiptuneThemes {
    /// Giriş ekranı: canlı, majör, dört ölçülük bir cümlenin tekrarı.
    static let title = ChiptuneTheme(
        tempoBPM: 140,
        lead: [
            .note("C5", 1), .note("E5", 1), .note("G5", 1), .note("C6", 1),
            .note("B5", 1), .note("G5", 1), .note("E5", 1), .note("D5", 1),
            .note("F5", 1), .note("A5", 1), .note("C6", 1), .note("A5", 1),
            .note("G5", 1), .note("E5", 1), .note("D5", 1), .rest(1),
        ],
        bass: [
            .note("C3", 4),
            .note("G2", 4),
            .note("F2", 4),
            .note("G2", 4),
        ]
    )

    /// Seçim ekranı: daha sakin, minör tonlu bir cümle.
    static let levelSelect = ChiptuneTheme(
        tempoBPM: 100,
        lead: [
            .note("A4", 1), .note("C5", 1), .note("E5", 1), .note("D5", 1),
            .note("C5", 1), .note("B4", 1), .note("A4", 1), .note("G4", 1),
            .note("F4", 1), .note("A4", 1), .note("C5", 1), .note("B4", 1),
            .note("A4", 1), .note("G4", 1), .note("F4", 1), .rest(1),
        ],
        bass: [
            .note("A2", 4),
            .note("F2", 4),
            .note("C3", 4),
            .note("E2", 4),
        ]
    )

    /// Oyun içi FEVER hızı: hızlı, itici, sekizinci notalarla.
    static let fever = ChiptuneTheme(
        tempoBPM: 160,
        lead: [
            .note("E5", 0.5), .note("G5", 0.5), .note("A5", 0.5), .note("B5", 0.5),
            .note("A5", 0.5), .note("G5", 0.5), .note("E5", 0.5), .note("D5", 0.5),
            .note("E5", 0.5), .note("G5", 0.5), .note("B5", 0.5), .note("D6", 0.5),
            .note("B5", 0.5), .note("G5", 0.5), .note("E5", 0.5), .rest(0.5),
        ],
        bass: [
            .note("E2", 1), .note("E2", 1), .note("A2", 1), .note("A2", 1),
            .note("E2", 1), .note("E2", 1), .note("B2", 1), .note("B2", 1),
        ]
    )

    /// Oyun içi CHILL hızı: yavaş, geniş, uzun notalarla.
    static let chill = ChiptuneTheme(
        tempoBPM: 80,
        lead: [
            .note("C4", 2), .note("E4", 2),
            .note("G4", 2), .note("E4", 2),
            .note("F4", 2), .note("A4", 2),
            .note("G4", 2), .rest(2),
        ],
        bass: [
            .note("C3", 4),
            .note("F3", 4),
        ]
    )
}
