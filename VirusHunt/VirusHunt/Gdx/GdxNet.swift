//
//  GdxNet.swift
//  VirusHunt
//
//  Gdx.net (HTTP), libGDX JsonValue ve Gdx.audio (Music) karşılıkları.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - HTTP

struct HttpRequest {
    var method = "POST"
    var url = ""
    var timeoutMs = 10_000
    var headers: [String: String] = [:]
    var content = ""
}

struct HttpResponse {
    let statusCode: Int
    let body: String?

    func getStatusCode() -> Int { return statusCode }
    func getResultAsString() -> String? { return body }
}

/// Net.HttpResponseListener. libGDX'teki gibi geri çağrılar ARKA PLAN thread'inde gelir;
/// oyun kodu sonucu Gdx.app.postRunnable ile render thread'ine taşır.
protocol HttpResponseListener {
    func handleHttpResponse(_ response: HttpResponse)
    func failed(_ error: Error)
    func cancelled()
}

/// Kapanışlarla kurulan dinleyici (Java'daki anonim sınıfların yerine).
struct HttpListener: HttpResponseListener {
    var onResponse: (HttpResponse) -> Void
    var onFailed: (Error) -> Void = { _ in }
    var onCancelled: () -> Void = {}

    func handleHttpResponse(_ response: HttpResponse) { onResponse(response) }
    func failed(_ error: Error) { onFailed(error) }
    func cancelled() { onCancelled() }
}

final class Net {
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }()

    /// Bağlantıyı açan platform kodu (iOS: UIApplication.open).
    var uriOpener: ((URL) -> Void)?

    /// Testler için: verilirse istek ağa gitmez, cevabı bu üretir (nil = bağlantı hatası).
    var interceptor: ((HttpRequest) -> HttpResponse?)?

    func sendHttpRequest(_ req: HttpRequest, _ listener: HttpResponseListener) {
        if let intercept = interceptor {
            if let r = intercept(req) { listener.handleHttpResponse(r) } else { listener.failed(URLError(.notConnectedToInternet)) }
            return
        }
        guard let url = URL(string: req.url) else {
            listener.failed(URLError(.badURL))
            return
        }
        var r = URLRequest(url: url)
        r.httpMethod = req.method
        r.timeoutInterval = TimeInterval(req.timeoutMs) / 1000
        for (k, v) in req.headers { r.setValue(v, forHTTPHeaderField: k) }
        if !req.content.isEmpty { r.httpBody = req.content.data(using: .utf8) }
        session.dataTask(with: r) { data, response, error in
            if let error = error {
                if (error as? URLError)?.code == .cancelled { listener.cancelled() } else { listener.failed(error) }
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = data.flatMap { String(data: $0, encoding: .utf8) }
            listener.handleHttpResponse(HttpResponse(statusCode: status, body: body))
        }.resume()
    }

    @discardableResult
    func openURI(_ uri: String) -> Bool {
        guard let url = URL(string: uri), let opener = uriOpener else { return false }
        opener(url)
        return true
    }
}

// MARK: - JSON

struct JsonError: Error, CustomStringConvertible {
    let description: String
}

/// libGDX JsonValue'nun okunan kısmı. Nesne alanları ada göre, diziler sırayla erişilir.
final class JsonValue {
    enum ValueType { case object, array, string, number, boolean, null }

    let type: ValueType
    private let raw: Any?
    private var fields: [String: JsonValue] = [:]
    private(set) var items: [JsonValue] = []

    init(any: Any?) {
        switch any {
        case let d as [String: Any]:
            type = .object
            raw = nil
            for (k, v) in d { fields[k] = JsonValue(any: v) }
        case let a as [Any]:
            type = .array
            raw = nil
            items = a.map { JsonValue(any: $0) }
        case let s as String:
            type = .string; raw = s
        case let n as NSNumber:
            #if canImport(ObjectiveC)
            type = CFGetTypeID(n) == CFBooleanGetTypeID() ? .boolean : .number
            #else
            type = .number
            #endif
            raw = n
        case let b as Bool:
            type = .boolean; raw = b
        default:
            type = .null; raw = nil
        }
    }

    /// Ayrıştırılamazsa nil (bkz. OnlineClient.parse).
    static func parse(_ text: String) -> JsonValue? {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        return JsonValue(any: obj)
    }

    func isObject() -> Bool { return type == .object }
    func isArray() -> Bool { return type == .array }
    func isString() -> Bool { return type == .string }
    func isNull() -> Bool { return type == .null }

    func has(_ name: String) -> Bool { return fields[name] != nil }
    func get(_ name: String) -> JsonValue? { return fields[name] }

    var size: Int { return type == .array ? items.count : fields.count }

    func asString() -> String? {
        switch raw {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        default: return type == .null ? nil : nil
        }
    }

    func asInt() throws -> Int {
        if let n = raw as? NSNumber { return n.intValue }
        if let s = raw as? String, let v = Int(s) { return v }
        if let b = raw as? Bool { return b ? 1 : 0 }
        throw JsonError(description: "sayı değil")
    }

    func asLong() throws -> Int64 {
        if let n = raw as? NSNumber { return n.int64Value }
        if let s = raw as? String, let v = Int64(s) { return v }
        throw JsonError(description: "sayı değil")
    }

    func asBoolean() throws -> Bool {
        if let b = raw as? Bool { return b }
        if let n = raw as? NSNumber { return n.boolValue }
        if let s = raw as? String { return s.lowercased() == "true" }
        throw JsonError(description: "mantıksal değil")
    }

    // ---- Alan okuyucular (libGDX imzaları) ----

    func getString(_ name: String) throws -> String {
        guard let v = fields[name] else { throw JsonError(description: "alan yok: \(name)") }
        if v.type == .null { throw JsonError(description: "alan boş: \(name)") }
        guard let s = v.asString() else { throw JsonError(description: "metin değil: \(name)") }
        return s
    }

    func getString(_ name: String, _ def: String) -> String {
        guard let v = fields[name], v.type != .null, let s = v.asString() else { return def }
        return s
    }

    func getInt(_ name: String) throws -> Int {
        guard let v = fields[name] else { throw JsonError(description: "alan yok: \(name)") }
        return try v.asInt()
    }

    func getInt(_ name: String, _ def: Int) -> Int {
        guard let v = fields[name], v.type != .null else { return def }
        return (try? v.asInt()) ?? def
    }

    func getBoolean(_ name: String, _ def: Bool) -> Bool {
        guard let v = fields[name], v.type != .null else { return def }
        return (try? v.asBoolean()) ?? def
    }
}

/// JSON üretimi için: Swift sözlükleri/dizileri -> metin (alan sırası korunmaz, sunucu umursamaz).
func jsonString(_ obj: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []),
          let s = String(data: data, encoding: .utf8) else { return "{}" }
    return s
}

// MARK: - Audio

/// com.badlogic.gdx.audio.Music: platformun çalıcısı (iOS: AVAudioPlayer).
protocol Music: AnyObject {
    func play()
    func pause()
    func stop()
    func isPlaying() -> Bool
    func setLooping(_ looping: Bool)
    func isLooping() -> Bool
    func setVolume(_ volume: Float)
    func getVolume() -> Float
    func setOnCompletionListener(_ listener: ((Music) -> Void)?)
    func dispose()
}

final class Audio {
    /// Platform atar; atanmamışsa müzik yok.
    var musicFactory: ((FileHandle) throws -> Music)?

    func newMusic(_ file: FileHandle) throws -> Music {
        guard let f = musicFactory else { throw JsonError(description: "ses yok") }
        return try f(file)
    }
}
