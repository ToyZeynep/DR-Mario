//
//  Services.swift
//  VirusHunt
//
//  com.rummuscan.core.net: Ads, Analytics, Feedback, ReviewPrompt (VirusHunt Android sürümünden
//  birebir; platform kısımları iOS'ta platform/ klasöründe).
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - Ads

/// Reklam kuralları (platformdan bağımsız):
///  - Ödüllü: tek kişilik oyunda "oyun bitti" ekranında, oyun başına bir kez "reklam izle, devam et".
///  - Geçiş: yalnızca bir oyun bitip menüye dönülürken; INTERSTITIAL_EVERY oyunda bir ve en az
///    COOLDOWN_MS arayla. Maç sırasında ve online VS'te hiç gösterilmez.
enum Ads {
    protocol Platform: AnyObject {
        func isRewardedReady() -> Bool
        /// onRewarded: ödül kazanıldı; onClosed: reklam kapandı (her zaman).
        func showRewarded(_ onRewarded: @escaping () -> Void, _ onClosed: @escaping () -> Void)
        func showInterstitial()
        func isPrivacyOptionsRequired() -> Bool
        func showPrivacyOptions()
    }

    static let INTERSTITIAL_EVERY = 3
    static let COOLDOWN_MS: Int64 = 120_000

    private static var platform: Platform?
    private static var gamesSinceInterstitial = 0
    private static var lastFullScreenAt: Int64 = 0

    static func setPlatform(_ p: Platform?) { platform = p }

    static func canOfferContinue() -> Bool { return platform != nil }

    static func showRewarded(_ onRewarded: @escaping () -> Void, _ onClosed: @escaping () -> Void) {
        guard let p = platform else {
            onClosed()
            return
        }
        lastFullScreenAt = currentTimeMillis()
        p.showRewarded(onRewarded, onClosed)
    }

    static func isPrivacyOptionsRequired() -> Bool { return platform?.isPrivacyOptionsRequired() ?? false }

    static func showPrivacyOptions() { platform?.showPrivacyOptions() }

    static func onGameFinished() {
        guard let p = platform else { return }
        gamesSinceInterstitial += 1
        let now = currentTimeMillis()
        if gamesSinceInterstitial < INTERSTITIAL_EVERY || now - lastFullScreenAt < COOLDOWN_MS { return }
        gamesSinceInterstitial = 0
        lastFullScreenAt = now
        p.showInterstitial()
    }
}

// MARK: - Analytics

/// Rummuscan'ın kendi sunucusuna (rummuscan.online) KVKK uyumlu analiz. Android sürümüyle aynı
/// protokol ve aynı uygulama anahtarı; panelde platform "ios" olarak görünür.
enum Analytics {
    struct Device {
        let platform: String
        let brand: String
        let model: String
        let osVersion: String
        let appVersion: String
        let versionCode: Int64
        /// Cihazın uygulamaya özel kimliği (iOS: identifierForVendor); sunucuya özeti gider.
        let deviceKey: String?
    }

    private static let ENDPOINT = "https://rummuscan.online/api/v1/collect"
    static let APP = "virushunt"
    static let KEY = "rs_X3lOtCeTpz35EoDPbC20nn06"
    private static let PREFS = "rummuscan_analytics"
    private static let SESSION_GAP_MS: Int64 = 30 * 60 * 1000
    private static let MAX_QUEUE = 300
    private static let FLUSH_AT = 25
    private static let AD_CONSENT_ENDPOINT = "https://rummuscan.online/api/v1/ad-consent"

    private static var deviceInfo: Device?
    private static var prefs: Preferences!
    private static var queue: [[String: Any]] = []
    private static var backgroundSince: Int64 = 0
    private static var sending = false

    static func initialize(_ d: Device?) {
        guard let d = d, deviceInfo == nil else { return }
        deviceInfo = d
        prefs = Gdx.app.getPreferences(PREFS)
        if let data = prefs.getString("queue", "[]").data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            queue = arr
        } else {
            queue = []
        }
        enqueue("app_open", "app_open")
    }

    static func screen(_ name: String) { enqueue("screen_view", name) }

    static func event(_ name: String) { enqueue("event", name) }

    static func onPause() {
        if deviceInfo == nil { return }
        backgroundSince = currentTimeMillis()
        flush()
    }

    static func onResume() {
        if deviceInfo == nil { return }
        if backgroundSince != 0 && currentTimeMillis() - backgroundSince > SESSION_GAP_MS {
            enqueue("app_open", "app_open")
            flush()
        }
    }

    private static func enqueue(_ type: String, _ name: String?) {
        guard deviceInfo != nil, let name = name else { return }
        queue.append(["type": type, "name": name.jlength > 64 ? name.jprefix(64) : name, "ts": currentTimeMillis()])
        while queue.count > MAX_QUEUE { queue.removeFirst() }
        save()
        if queue.count >= FLUSH_AT { flush() }
    }

    private static func flush() {
        guard let device = deviceInfo, !sending, !queue.isEmpty else { return }
        let count = queue.count

        var body: [String: Any] = [
            "app": APP, "key": KEY, "install_id": installId(),
            "platform": device.platform, "app_version": device.appVersion, "os_version": device.osVersion,
            "device_brand": device.brand, "device_model": device.model,
            "language": Locale.current.languageCode ?? "en",
            "events": queue,
        ]
        let previous = previousInstallId()
        if let p = previous { body["previous_id"] = p }

        let req = HttpRequest(method: "POST", url: ENDPOINT, timeoutMs: 10_000,
                              headers: ["Content-Type": "application/json"], content: jsonString(body))
        sending = true
        Gdx.net.sendHttpRequest(req, HttpListener(onResponse: { response in
            let code = response.getStatusCode()
            // 2xx: gönderildi; 4xx (429 hariç): veri hatalı, tekrar denenmez
            let drop = (code >= 200 && code < 300) || (code >= 400 && code < 500 && code != 429)
            Gdx.app.postRunnable {
                if drop {
                    var i = 0
                    while i < count && !queue.isEmpty { queue.removeFirst(); i += 1 }
                    save()
                }
                if code >= 200 && code < 300 && previous != nil {
                    prefs.remove("install_id")
                    prefs.flush()
                }
                sending = false
            }
        }, onFailed: { _ in
            Gdx.app.postRunnable { sending = false }
        }, onCancelled: {
            Gdx.app.postRunnable { sending = false }
        }))
    }

    /// AB/BK/İsviçre reklam onayı (UMP) sonucu, anonim istatistik için.
    /// result: "consent_all" | "consent_custom" | "rejected" | "undecided"
    static func adConsent(_ source: String, _ result: String, _ country: String?, _ purposes: String?, _ packageName: String) {
        guard let device = deviceInfo else { return }
        var body: [String: Any] = [
            "app": APP, "key": KEY, "install_id": installId(), "package": packageName,
            "platform": device.platform, "app_version": device.appVersion, "version_code": device.versionCode,
            "country": country ?? "", "source": source, "result": result,
        ]
        if let p = purposes, !p.isEmpty { body["purposes"] = p }
        let req = HttpRequest(method: "POST", url: AD_CONSENT_ENDPOINT, timeoutMs: 10_000,
                              headers: ["Content-Type": "application/json"], content: jsonString(body))
        Gdx.net.sendHttpRequest(req, HttpListener(onResponse: { _ in }))
    }

    static func device() -> Device? { return deviceInfo }

    private static var deviceId: String?

    static func installId() -> String {
        if deviceId == nil {
            let derived = deviceInfo.flatMap { deviceIdFrom(APP, $0.deviceKey) }
            deviceId = derived ?? randomInstallId()
        }
        return deviceId!
    }

    /// "d-" + SHA-256("rummuscan:" + uygulama + ":" + cihazKimliği)'nin ilk 32 hex karakteri.
    static func deviceIdFrom(_ app: String, _ key: String?) -> String? {
        guard let key = key, !key.isEmpty, key != "9774d56d682e549c" else { return nil }
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data(("rummuscan:" + app + ":" + key).utf8))
        return "d-" + digest.prefix(16).map { String(format: "%02x", $0) }.joined()
        #else
        return nil
        #endif
    }

    static func previousInstallId() -> String? {
        guard let old = prefs.getString("install_id") else { return nil }
        return old != installId() ? old : nil
    }

    private static func randomInstallId() -> String {
        if let id = prefs.getString("install_id") { return id }
        let id = UUID().uuidString.lowercased()
        prefs.putString("install_id", id)
        prefs.flush()
        return id
    }

    private static func save() {
        prefs.putString("queue", jsonString(queue))
        prefs.flush()
    }
}

// MARK: - Feedback

/// Uygulama içi geri bildirim: metin rummuscan.online/api/v1/feedback'e gider (admin paneli).
enum Feedback {
    protocol Platform: AnyObject {
        func open()
    }

    private static let ENDPOINT = "https://rummuscan.online/api/v1/feedback"
    private static var platform: Platform?

    static func setPlatform(_ p: Platform?) { platform = p }
    static func isAvailable() -> Bool { return platform != nil }
    static func open() { platform?.open() }

    static func send(_ text: String, _ rating: Int, _ email: String?, _ cb: ((Bool) -> Void)?) {
        guard let d = Analytics.device() else {
            if let cb = cb { Gdx.app.postRunnable { cb(false) } }
            return
        }
        var body: [String: Any] = [
            "app": Analytics.APP, "key": Analytics.KEY, "install_id": Analytics.installId(),
            "platform": d.platform, "text": text, "app_version": d.appVersion,
            "os_version": d.osVersion, "device_brand": d.brand, "device_model": d.model,
            "language": Locale.current.languageCode ?? "en",
        ]
        if rating >= 1 && rating <= 5 { body["rating"] = rating }
        if let e = email, !e.jtrim().isEmpty { body["email"] = e.jtrim() }
        if d.versionCode > 0 { body["version_code"] = d.versionCode }

        let req = HttpRequest(method: "POST", url: ENDPOINT, timeoutMs: 10_000,
                              headers: ["Content-Type": "application/json"], content: jsonString(body))
        func done(_ ok: Bool) { if let cb = cb { Gdx.app.postRunnable { cb(ok) } } }
        Gdx.net.sendHttpRequest(req, HttpListener(onResponse: { response in
            let code = response.getStatusCode()
            done(code >= 200 && code < 300)
        }, onFailed: { _ in done(false) }, onCancelled: { done(false) }))
    }
}

// MARK: - ReviewPrompt

/// Uygulama içi değerlendirme penceresi, uygulama ömründe BİR KEZ: en az MIN_LAUNCHES. açılış ve
/// ilk açılıştan en az MIN_DAYS gün sonra, olumlu bir anda (bölüm geçildi, maç kazanıldı).
enum ReviewPrompt {
    protocol Platform: AnyObject {
        func request()
    }

    static let MIN_LAUNCHES = 4
    static let MIN_DAYS: Int64 = 3

    private static let PREFS = "virushunt-review"
    private static let KEY_FIRST_OPEN = "firstOpen"
    private static let KEY_LAUNCHES = "launches"
    private static let KEY_ASKED = "asked"

    private static var platform: Platform?

    static func setPlatform(_ p: Platform?) { platform = p }

    static func onLaunch() {
        let p = Gdx.app.getPreferences(PREFS)
        if !p.contains(KEY_FIRST_OPEN) { p.putLong(KEY_FIRST_OPEN, currentTimeMillis()) }
        p.putInteger(KEY_LAUNCHES, p.getInteger(KEY_LAUNCHES, 0) + 1)
        p.flush()
    }

    static func onPositiveMoment() {
        guard let platform = platform else { return }
        let p = Gdx.app.getPreferences(PREFS)
        if p.getBoolean(KEY_ASKED, false) { return }
        if p.getInteger(KEY_LAUNCHES, 0) < MIN_LAUNCHES { return }
        let first = p.getLong(KEY_FIRST_OPEN, currentTimeMillis())
        if currentTimeMillis() - first < MIN_DAYS * 24 * 60 * 60 * 1000 { return }
        p.putBoolean(KEY_ASKED, true)
        p.flush()
        platform.request()
    }
}
