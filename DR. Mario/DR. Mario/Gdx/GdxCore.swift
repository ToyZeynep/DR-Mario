//
//  GdxCore.swift
//  DR. Mario
//
//  libGDX'in uygulama iskeletinin (Game / Screen / Gdx.app / Gdx.input / Preferences / Gdx.files)
//  Swift karşılığı. Oyun kodu Android sürümünden (HasanDagasan/VirusHunt) satır satır
//  çevrildiği için çağrılar Java'dakiyle aynı adları taşır.
//
//  Platform kısmı (Metal çizim, UIKit dokunuşları, ekran döngüsü) Gdx/IOSBackend.swift'tedir;
//  bu dosya platformdan bağımsızdır.
//

import Foundation

// MARK: - Screen / Game

protocol Screen: AnyObject {
    func show()
    func render(_ delta: Float)
    func resize(_ width: Int, _ height: Int)
    func pause()
    func resume()
    func hide()
    func dispose()
}

/// com.badlogic.gdx.Game
class Game {
    private(set) var screen: Screen?

    func getScreen() -> Screen? { return screen }

    func create() {}

    func setScreen(_ newScreen: Screen?) {
        screen?.hide()
        screen = newScreen
        if let s = screen {
            s.show()
            s.resize(Gdx.graphics.getWidth(), Gdx.graphics.getHeight())
        }
    }

    func render() {
        screen?.render(Gdx.graphics.getDeltaTime())
    }

    func resize(_ width: Int, _ height: Int) { screen?.resize(width, height) }
    func pause() { screen?.pause() }
    func resume() { screen?.resume() }
    func dispose() { screen?.hide() }
}

// MARK: - Input

protocol InputProcessor: AnyObject {
    func keyDown(_ keycode: Int) -> Bool
    func keyUp(_ keycode: Int) -> Bool
    func touchDown(_ screenX: Int, _ screenY: Int, _ pointer: Int, _ button: Int) -> Bool
    func touchUp(_ screenX: Int, _ screenY: Int, _ pointer: Int, _ button: Int) -> Bool
    func touchDragged(_ screenX: Int, _ screenY: Int, _ pointer: Int) -> Bool
    func scrolled(_ amountX: Float, _ amountY: Float) -> Bool
}

/// com.badlogic.gdx.InputAdapter. Java'daki anonim alt sınıflar (new InputAdapter() { ... })
/// için kapanış (closure) alanları da var.
class InputAdapter: InputProcessor {
    var onTouchDown: ((Int, Int, Int, Int) -> Bool)?

    init() {}

    init(touchDown: @escaping (Int, Int, Int, Int) -> Bool) {
        onTouchDown = touchDown
    }

    func keyDown(_ keycode: Int) -> Bool { return false }
    func keyUp(_ keycode: Int) -> Bool { return false }
    func touchDown(_ screenX: Int, _ screenY: Int, _ pointer: Int, _ button: Int) -> Bool {
        return onTouchDown?(screenX, screenY, pointer, button) ?? false
    }
    func touchUp(_ screenX: Int, _ screenY: Int, _ pointer: Int, _ button: Int) -> Bool { return false }
    func touchDragged(_ screenX: Int, _ screenY: Int, _ pointer: Int) -> Bool { return false }
    func scrolled(_ amountX: Float, _ amountY: Float) -> Bool { return false }
}

protocol TextInputListener: AnyObject {
    func input(_ text: String)
    func canceled()
}

/// com.badlogic.gdx.Input (yalnızca oyunun kullandığı kısım).
final class Input {
    /// libGDX (Android) tuş kodları.
    enum Keys {
        static let BACK = 4
        static let UP = 19
        static let DOWN = 20
        static let LEFT = 21
        static let RIGHT = 22
        static let A = 29
        static let D = 32
        static let F = 34
        static let L = 40
        static let R = 46
        static let S = 47
        static let W = 51
        static let SPACE = 62
        static let ENTER = 66
        static let ESCAPE = 111
    }

    enum Event {
        case touchDown(x: Int, y: Int, pointer: Int)
        case touchUp(x: Int, y: Int, pointer: Int)
        case touchDragged(x: Int, y: Int, pointer: Int)
        case keyDown(Int)
        case keyUp(Int)
    }

    static let maxPointers = 20

    private var processor: InputProcessor?
    private var queue: [Event] = []
    private let lock = NSLock()

    private var touchX = [Int](repeating: 0, count: Input.maxPointers)
    private var touchY = [Int](repeating: 0, count: Input.maxPointers)
    private var touched = [Bool](repeating: false, count: Input.maxPointers)
    private var justTouchedFlag = false
    private var pressedKeys = Set<Int>()
    private var justPressedKeys = Set<Int>()

    /// Metin girişi penceresini platform açar (bkz. IOSBackend).
    var textInputPresenter: ((TextInputListener, String, String, String) -> Void)?

    func setInputProcessor(_ p: InputProcessor?) { processor = p }
    func getInputProcessor() -> InputProcessor? { return processor }

    func isKeyPressed(_ key: Int) -> Bool { return pressedKeys.contains(key) }
    func isKeyJustPressed(_ key: Int) -> Bool { return justPressedKeys.contains(key) }

    func justTouched() -> Bool { return justTouchedFlag }
    func isTouched() -> Bool { return touched.contains(true) }
    func isTouched(_ pointer: Int) -> Bool { return pointer >= 0 && pointer < touched.count && touched[pointer] }
    func getX() -> Int { return touchX[0] }
    func getY() -> Int { return touchY[0] }
    func getX(_ pointer: Int) -> Int { return touchX[pointer] }
    func getY(_ pointer: Int) -> Int { return touchY[pointer] }

    func getTextInput(_ listener: TextInputListener, _ title: String, _ text: String, _ hint: String) {
        if let presenter = textInputPresenter {
            presenter(listener, title, text, hint)
        } else {
            Gdx.app.postRunnable { listener.canceled() }
        }
    }

    // ---- Platform tarafı ----

    /// Dokunma/tuş olayı ekler (UIKit ana thread'inden).
    func post(_ e: Event) {
        lock.lock(); queue.append(e); lock.unlock()
    }

    /// Her karenin başında (render'dan önce) çağrılır: olaylar sırayla işlenir ve dinleyiciye iletilir.
    func processEvents() {
        justTouchedFlag = false
        justPressedKeys.removeAll()
        lock.lock()
        let events = queue
        queue.removeAll()
        lock.unlock()
        for e in events {
            switch e {
            case let .touchDown(x, y, p):
                guard p < Input.maxPointers else { continue }
                touchX[p] = x; touchY[p] = y; touched[p] = true
                justTouchedFlag = true
                _ = processor?.touchDown(x, y, p, 0)
            case let .touchDragged(x, y, p):
                guard p < Input.maxPointers else { continue }
                touchX[p] = x; touchY[p] = y
                _ = processor?.touchDragged(x, y, p)
            case let .touchUp(x, y, p):
                guard p < Input.maxPointers else { continue }
                touchX[p] = x; touchY[p] = y; touched[p] = false
                _ = processor?.touchUp(x, y, p, 0)
            case let .keyDown(k):
                if !pressedKeys.contains(k) { justPressedKeys.insert(k) }
                pressedKeys.insert(k)
                _ = processor?.keyDown(k)
            case let .keyUp(k):
                pressedKeys.remove(k)
                _ = processor?.keyUp(k)
            }
        }
    }

    /// Uygulama arka plana alınınca basılı kalmış her şeyi bırak.
    func releaseAll() {
        for p in 0..<Input.maxPointers where touched[p] {
            post(.touchUp(x: touchX[p], y: touchY[p], pointer: p))
        }
        for k in pressedKeys { post(.keyUp(k)) }
    }
}

// MARK: - Application

enum ApplicationType { case android, desktop, iOS }

final class Application {
    private var runnables: [() -> Void] = []
    private let lock = NSLock()

    func getType() -> ApplicationType { return .iOS }

    /// Bir sonraki karede, render thread'inde (burada ana thread) çalıştırılır.
    func postRunnable(_ r: @escaping () -> Void) {
        lock.lock(); runnables.append(r); lock.unlock()
    }

    /// Platform her karenin başında çağırır.
    func runPending() {
        lock.lock()
        let list = runnables
        runnables.removeAll()
        lock.unlock()
        for r in list { r() }
    }

    func log(_ tag: String, _ message: String) { print("[\(tag)] \(message)") }
    func error(_ tag: String, _ message: String) { print("[\(tag)] HATA: \(message)") }
    func error(_ tag: String, _ message: String, _ error: Error?) {
        print("[\(tag)] HATA: \(message) \(error.map { String(describing: $0) } ?? "")")
    }
    func debug(_ tag: String, _ message: String) {
        #if DEBUG
        print("[\(tag)] \(message)")
        #endif
    }

    private var prefsCache: [String: Preferences] = [:]

    func getPreferences(_ name: String) -> Preferences {
        if let p = prefsCache[name] { return p }
        let p = Preferences(name)
        prefsCache[name] = p
        return p
    }
}

// MARK: - Preferences (UserDefaults)

/// com.badlogic.gdx.Preferences: her tercih dosyası UserDefaults'ta "ad.anahtar" önekiyle tutulur.
final class Preferences {
    private let name: String
    private let defaults = UserDefaults.standard

    init(_ name: String) { self.name = name }

    private func k(_ key: String) -> String { return name + "." + key }

    func contains(_ key: String) -> Bool { return defaults.object(forKey: k(key)) != nil }

    func getString(_ key: String, _ def: String) -> String { return defaults.string(forKey: k(key)) ?? def }
    func getString(_ key: String) -> String? { return defaults.string(forKey: k(key)) }
    func putString(_ key: String, _ value: String) { defaults.set(value, forKey: k(key)) }

    func getInteger(_ key: String, _ def: Int) -> Int {
        return (defaults.object(forKey: k(key)) as? NSNumber)?.intValue ?? def
    }
    func putInteger(_ key: String, _ value: Int) { defaults.set(value, forKey: k(key)) }

    func getLong(_ key: String, _ def: Int64) -> Int64 {
        return (defaults.object(forKey: k(key)) as? NSNumber)?.int64Value ?? def
    }
    func putLong(_ key: String, _ value: Int64) { defaults.set(NSNumber(value: value), forKey: k(key)) }

    func getFloat(_ key: String, _ def: Float) -> Float {
        return (defaults.object(forKey: k(key)) as? NSNumber)?.floatValue ?? def
    }
    func putFloat(_ key: String, _ value: Float) { defaults.set(value, forKey: k(key)) }

    func getBoolean(_ key: String, _ def: Bool) -> Bool {
        return (defaults.object(forKey: k(key)) as? NSNumber)?.boolValue ?? def
    }
    func putBoolean(_ key: String, _ value: Bool) { defaults.set(value, forKey: k(key)) }

    func remove(_ key: String) { defaults.removeObject(forKey: k(key)) }

    func flush() { /* UserDefaults kendisi yazar */ }
}

// MARK: - Files

/// Gdx.files.internal(...): uygulama paketindeki GameAssets klasörü (Android'deki assets/).
struct FileHandle {
    let path: String

    /// Android'deki .ogg müzikler iOS'ta .m4a'ya çevrildi (AVAudioPlayer ogg çalmaz).
    private var iosPath: String {
        if path.hasSuffix(".ogg") { return String(path.dropLast(4)) + ".m4a" }
        return path
    }

    var url: URL? {
        let p = iosPath as NSString
        let ext = p.pathExtension
        let base = (p.deletingPathExtension as NSString)
        let dir = base.deletingLastPathComponent
        let file = base.lastPathComponent
        // Klasör yapısı korunmuşsa (GameAssets/ui/doctor.png) önce o, yoksa düz paket kökü.
        if let u = Bundle.main.url(forResource: file, withExtension: ext, subdirectory: "GameAssets/" + dir) { return u }
        if let u = Bundle.main.url(forResource: file, withExtension: ext, subdirectory: "GameAssets") { return u }
        return Bundle.main.url(forResource: file, withExtension: ext)
    }

    func exists() -> Bool { return url != nil }
}

final class Files {
    func `internal`(_ path: String) -> FileHandle { return FileHandle(path: path) }
}

// MARK: - Graphics bilgisi

final class Graphics {
    /// Ekran boyu (nokta; dokunma koordinatlarıyla aynı birim).
    var width = 1
    var height = 1
    /// Çizim yüzeyinin piksel boyu.
    var backBufferWidth = 1
    var backBufferHeight = 1
    /// Çentik / yuvarlak köşe payı (nokta): ekranın sol ve sağ kenarındaki güvenli alan boşluğu.
    var safeInsetLeft: Float = 0
    var safeInsetRight: Float = 0
    var deltaTime: Float = 0

    func getWidth() -> Int { return width }
    func getHeight() -> Int { return height }
    func getBackBufferWidth() -> Int { return backBufferWidth }
    func getBackBufferHeight() -> Int { return backBufferHeight }
    func getDeltaTime() -> Float { return deltaTime }
}

// MARK: - Gdx

enum Gdx {
    static let app = Application()
    static let input = Input()
    static let graphics = Graphics()
    static let gl = GL20()
    static let net = Net()
    static let files = Files()
    static let audio = Audio()
}
