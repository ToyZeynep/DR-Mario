//
//  ChiptuneRenderer.swift
//  DR. Mario
//
//  Bir ChiptuneTheme'i (lead + bass nota dizileri) tek seferde bir PCM örnek dizisine
//  ("render" edilmiş bir döngü turu) çevirir. Gerçek zamanlı bir ses render callback'i
//  YAZMIYORUZ (bu, ses thread'inde güvenli olmayan işler yapma riskini taşır); bunun
//  yerine tüm döngü tek seferde, ana thread'de, düz bir [Float] tampon olarak üretilir ve
//  AVAudioPlayerNode buffer'ı .loops seçeneğiyle tekrar tekrar çalar.
//

import Foundation
import AVFoundation

enum ChiptuneRenderer {
    static let sampleRate: Double = 44100
    /// MusicPlayer'ın engine bağlantısında da AYNEN kullandığı format - ikisi
    /// eşleşmezse AVAudioEngine sessizce (ya da hatayla) hiç ses çıkarmayabilir.
    static let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

    static func render(_ theme: ChiptuneTheme) -> AVAudioPCMBuffer? {
        let beatDuration = 60.0 / theme.tempoBPM
        let leadSamples = renderVoice(theme.lead, beatDuration: beatDuration, amplitude: 0.16, dutyCycle: 0.5)
        let bassSamples = renderVoice(theme.bass, beatDuration: beatDuration, amplitude: 0.12, dutyCycle: 0.25)

        let frameCount = max(leadSamples.count, bassSamples.count)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount))
        else { return nil }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let channelData = buffer.floatChannelData else { return nil }

        for i in 0..<frameCount {
            let lead = i < leadSamples.count ? leadSamples[i] : 0
            let bass = i < bassSamples.count ? bassSamples[i] : 0
            let mixed = max(-1, min(1, lead + bass))
            channelData[0][i] = mixed
            channelData[1][i] = mixed
        }

        return buffer
    }

    /// Tek bir sesi (nota dizisini) kare dalga olarak örnekler. Tık sesini önlemek için
    /// her notanın başında/sonunda birkaç milisaniyelik doğrusal fade uygulanır.
    private static func renderVoice(_ notes: [ChiptuneNote], beatDuration: Double, amplitude: Float, dutyCycle: Double) -> [Float] {
        var samples: [Float] = []
        let fadeSamples = Int(0.006 * sampleRate) // ~6ms

        for note in notes {
            let noteFrames = Int(note.beats * beatDuration * sampleRate)
            guard noteFrames > 0 else { continue }

            guard let freq = note.frequency else {
                samples.append(contentsOf: [Float](repeating: 0, count: noteFrames))
                continue
            }

            let period = sampleRate / freq
            for i in 0..<noteFrames {
                let phase = (Double(i).truncatingRemainder(dividingBy: period)) / period
                var value: Float = phase < dutyCycle ? 1 : -1
                value *= amplitude

                // Nota başı/sonu fade: tık sesini önler.
                if i < fadeSamples {
                    value *= Float(i) / Float(fadeSamples)
                } else if i > noteFrames - fadeSamples {
                    value *= Float(noteFrames - i) / Float(fadeSamples)
                }
                samples.append(value)
            }
        }
        return samples
    }
}
