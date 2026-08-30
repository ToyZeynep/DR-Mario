//
//  MusicPlayer.swift
//  DR. Mario
//
//  Ekranlar arasında paylaşılan, tek bir AVAudioEngine üzerinden çalışan basit bir müzik
//  oynatıcı. Bir ChiptuneTheme'i render edip döngüsel olarak çalar; başka bir tema
//  istendiğinde ya da stop() çağrıldığında önceki döngü kesilir.
//

import AVFoundation

final class MusicPlayer {
    static let shared = MusicPlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var currentThemeName: String?

    private init() {
        engine.attach(player)
        // Format'ı burada AÇIKÇA ChiptuneRenderer'ın ürettiği buffer'la AYNI vermek şart:
        // nil geçilirse engine, henüz başlamamış donanım çıkışının varsayılan formatını
        // kullanır ve bu, buffer'ın formatıyla uyuşmayıp sessiz kalabiliyordu.
        engine.connect(player, to: engine.mainMixerNode, format: ChiptuneRenderer.audioFormat)

        #if os(iOS) || os(tvOS)
        // .ambient KATEGORİSİ sessiz/açık anahtarına (Ring/Silent switch) uyar ve o anahtar
        // kapalıyken (sessizdeyken) hiç ses çıkarmaz - müziğin "hiç çalmıyor" görünmesinin
        // en olası sebebi buydu. Oyun müziği için .playback kullanılır: sessiz anahtarından
        // bağımsız çalar.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    /// name, aynı tema zaten çalıyorsa gereksiz yeniden başlatmayı önlemek için kullanılan
    /// basit bir kimlik (bkz. çağıran taraf: TitleScreenView/LevelSelectScreenView).
    func play(_ theme: ChiptuneTheme, name: String) {
        guard currentThemeName != name else { return }
        currentThemeName = name

        guard let buffer = ChiptuneRenderer.render(theme) else { return }

        player.stop()
        if !engine.isRunning {
            try? engine.start()
        }
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
    }

    func stop() {
        currentThemeName = nil
        player.stop()
    }
}
