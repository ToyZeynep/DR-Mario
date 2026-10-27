//
//  OnlineClient.swift
//  VirusHunt
//
//  com.rummuscan.core.net.OnlineClient + TimedAction + MatchSync + RemoteEngineDriver
//  (VirusHunt Android sürümünden birebir). Android ile AYNI sunucuya (server/*.php) ve aynı
//  protokolle konuşur: iPhone ve Android oyuncuları aynı lobide görünür ve birbiriyle oynar.
//
//  Tüm geri çağrılar Gdx.app.postRunnable ile ana (render) thread'ine taşınmış olarak tetiklenir.
//

import Foundation

struct ClientCallback<T> {
    var onResult: (T) -> Void
    var onError: (String?) -> Void
}

final class OnlineClient {

    static let ERR_SESSION_INVALID = "session_invalid"
    static let ERR_TARGET_OFFLINE = "target_offline"
    static let ERR_TARGET_BUSY = "target_busy"
    static let ERR_INVITE_INVALID = "invite_invalid"
    static let ERR_SENDER_LEFT = "sender_left"
    /// Cevap geldi ama oyun sunucusunun beklenen cevabı değil (bakım sayfası, 502, 5xx...). Geçicidir.
    static let ERR_BAD_RESPONSE = "bad_response"
    /// İstek sunucuya hiç ulaşamadı. Geçicidir.
    static let ERR_NETWORK = "network_error"

    static func isTransient(_ code: String?) -> Bool {
        return code == ERR_BAD_RESPONSE || code == ERR_NETWORK
    }

    struct LoginResult {
        let session: String
        let me: PlayerProfile?
    }

    struct LobbyState {
        let me: PlayerProfile?
        let players: [PlayerProfile]
        let incoming: Invite?
        let outgoing: Invite?
        let match: MatchInfo?
        let incomingClosed: Invite?
    }

    struct Invite {
        let id: Int
        let otherName: String
        let otherRating: Int
        let level: Int
        let speed: String
        /// pending / accepted / declined / cancelled / expired / sender_left / receiver_left
        let status: String
        /// Sunucu saatine göre kalan süre (sn); bilinmiyorsa -1.
        let expiresIn: Int
    }

    struct Leaderboard {
        let top: [PlayerProfile]
        let me: PlayerProfile?
    }

    struct SyncResponse {
        let events: [TimedAction]
        let lastId: Int
        let opponentTick: Int
        let ended: Bool
        let winnerSlot: Int
        let reason: String?
        let ratingDelta: Int
        let me: PlayerProfile?
    }

    struct SyncCallback {
        var onSync: (SyncResponse) -> Void
        var onMatchNotFound: () -> Void
        var onError: (String?) -> Void
    }

    struct InviteResult {
        let inviteId: Int
        let match: MatchInfo?
        let expiresIn: Int
    }

    private static let TIMEOUT_MS = 8000

    private let baseUrl: String

    init(_ baseUrl: String) {
        self.baseUrl = baseUrl.hasSuffix("/") ? baseUrl : baseUrl + "/"
    }

    // ---- Hesap / lobi ----

    func login(_ c: Credentials, _ linkGuestId: String?, _ cb: ClientCallback<LoginResult>) {
        let body = "{\"kind\":" + OnlineClient.q(c.kind) + ",\"secret\":" + OnlineClient.q(c.secret) + ",\"name\":" + OnlineClient.q(c.displayName)
            + (c.extraJson.isEmpty ? "" : "," + c.extraJson)
            + (linkGuestId != nil ? ",\"linkGuest\":" + OnlineClient.q(linkGuestId) : "") + "}"
        post("login.php", body, { v in
            let r = LoginResult(session: try v.getString("session"), me: OnlineClient.parseProfile(v.get("me")))
            Gdx.app.postRunnable { cb.onResult(r) }
        }, { m in Gdx.app.postRunnable { cb.onError(m) } })
    }

    func heartbeat(_ queue: Bool, _ level: Int, _ speed: String, _ withList: Bool, _ search: String?, _ cb: ClientCallback<LobbyState>) {
        let body = "{\"session\":" + OnlineClient.q(OnlineSession.token()) + ",\"queue\":" + (queue ? "1" : "0")
            + ",\"level\":\(level),\"speed\":" + OnlineClient.q(speed) + ",\"v\":2"
            + ",\"list\":" + (withList ? "1" : "0")
            + ((search != nil && !search!.isEmpty) ? ",\"q\":" + OnlineClient.q(search) : "") + "}"
        post("heartbeat.php", body, { v in
            var players: [PlayerProfile] = []
            if let arr = v.get("players") {
                for p in arr.items { if let pp = OnlineClient.parseProfile(p) { players.append(pp) } }
            }
            let s = LobbyState(me: OnlineClient.parseProfile(v.get("me")), players: players,
                               incoming: try OnlineClient.parseInvite(v.get("incoming")),
                               outgoing: try OnlineClient.parseInvite(v.get("outgoing")),
                               match: try OnlineClient.parseMatch(v.get("match")),
                               incomingClosed: try OnlineClient.parseInvite(v.get("incomingClosed")))
            Gdx.app.postRunnable { cb.onResult(s) }
        }, { m in Gdx.app.postRunnable { cb.onError(m) } })
    }

    /// Oyun kapanıyor / arka plana alındı: sunucu beni çevrimdışı yapar. Cevap beklenmez.
    func leave() {
        if OnlineSession.token() == nil { return }
        let body = "{\"session\":" + OnlineClient.q(OnlineSession.token()) + ",\"leave\":1,\"level\":0,\"speed\":\"MED\"}"
        post("heartbeat.php", body, { _ in }, { _ in })
    }

    /// Hesabı ve tüm verilerini sunucudan siler; oturum geçersiz olur.
    func deleteAccount(_ cb: ClientCallback<Bool>) {
        let body = "{\"session\":" + OnlineClient.q(OnlineSession.token()) + "}"
        post("delete_account.php", body, { v in
            // Açık onay olmadan "silindi" sayılmaz.
            if !v.getBoolean("ok", false) { throw JsonError(description: "delete_account: ok alanı yok") }
            Gdx.app.postRunnable { cb.onResult(true) }
        }, { m in Gdx.app.postRunnable { cb.onError(m) } })
    }

    func invite(_ toPlayerId: Int, _ level: Int, _ speed: String, _ cb: ClientCallback<InviteResult>) {
        let body = "{\"session\":" + OnlineClient.q(OnlineSession.token()) + ",\"toId\":\(toPlayerId)"
            + ",\"level\":\(level),\"speed\":" + OnlineClient.q(speed) + "}"
        post("invite.php", body, { v in
            let r = InviteResult(inviteId: v.getInt("inviteId", 0), match: try OnlineClient.parseMatch(v.get("match")),
                                 expiresIn: v.getInt("expiresIn", -1))
            Gdx.app.postRunnable { cb.onResult(r) }
        }, { m in Gdx.app.postRunnable { cb.onError(m) } })
    }

    /// action: accept | decline | cancel
    func respond(_ inviteId: Int, _ action: String, _ cb: ClientCallback<MatchInfo?>) {
        let body = "{\"session\":" + OnlineClient.q(OnlineSession.token()) + ",\"inviteId\":\(inviteId),\"action\":" + OnlineClient.q(action) + "}"
        post("respond.php", body, { v in
            let m = try OnlineClient.parseMatch(v.get("match"))
            Gdx.app.postRunnable { cb.onResult(m) }
        }, { m in Gdx.app.postRunnable { cb.onError(m) } })
    }

    func leaderboard(_ cb: ClientCallback<Leaderboard>) {
        let body = "{\"session\":" + OnlineClient.q(OnlineSession.token()) + "}"
        post("leaderboard.php", body, { v in
            var top: [PlayerProfile] = []
            if let arr = v.get("players") {
                for p in arr.items { if let pp = OnlineClient.parseProfile(p) { top.append(pp) } }
            }
            let lb = Leaderboard(top: top, me: OnlineClient.parseProfile(v.get("me")))
            Gdx.app.postRunnable { cb.onResult(lb) }
        }, { m in Gdx.app.postRunnable { cb.onError(m) } })
    }

    // ---- Maç ----

    /// Maç sırasında periyodik tek istek: kendi olaylarımı yazar, rakibin yenilerini okur,
    /// "şu tick'teyim" nabzı atar ve varsa maç sonucumu bildirir. cb nil olabilir (son FORFEIT).
    func sync(_ matchId: Int, _ slot: Int, _ tick: Int, _ afterId: Int, _ events: [TimedAction], _ result: String?, _ cb: SyncCallback?) {
        var sb = "{\"session\":" + OnlineClient.q(OnlineSession.token())
            + ",\"matchId\":\(matchId),\"slot\":\(slot)"
            + ",\"tick\":\(tick),\"afterId\":\(afterId)"
        if let r = result { sb += ",\"result\":\"" + r + "\"" }
        sb += ",\"events\":["
        for (i, e) in events.enumerated() {
            if i > 0 { sb += "," }
            sb += "{\"tick\":\(e.tick),\"action\":\"" + e.action.name() + "\""
            if let d = e.data { sb += ",\"data\":\"" + d + "\"" } // sadece rakam ve ':' içerir
            sb += "}"
        }
        sb += "]}"

        guard let cb = cb else {
            post("sync.php", sb, { _ in }, { _ in })
            return
        }
        post("sync.php", sb, { response in
            let parsed = try OnlineClient.parseSync(response, afterId)
            Gdx.app.postRunnable { cb.onSync(parsed) }
        }, { message in
            if let m = message, m.contains("match_not_found") {
                Gdx.app.postRunnable { cb.onMatchNotFound() }
            } else {
                Gdx.app.postRunnable { cb.onError(message) }
            }
        })
    }

    // ---- Ayrıştırma ----

    private static func parseSync(_ response: JsonValue, _ afterId: Int) throws -> SyncResponse {
        var events: [TimedAction] = []
        if let arr = response.get("events") {
            for e in arr.items {
                let data: String? = (e.has("data") && !(e.get("data")!.isNull())) ? (try? e.getString("data")) : nil
                // Bilinmeyen action ismi (ör. ileride eklenip bu sürümün tanımadığı) - atla.
                guard let name = try? e.getString("action"), let action = InputAction(rawValue: name),
                      let tick = try? e.getInt("tick") else { continue }
                events.append(TimedAction(tick, action, data))
            }
        }
        let lastId = response.has("lastId") ? try response.getInt("lastId") : afterId
        let opponentTick = response.getInt("opponentTick", 0)
        let ended = response.getString("status", "running") == "ended"
        let winnerSlot = (response.has("winnerSlot") && !response.get("winnerSlot")!.isNull()) ? try response.getInt("winnerSlot") : -1
        let reason = (response.has("reason") && !response.get("reason")!.isNull()) ? try response.getString("reason") : nil
        let delta = response.getInt("ratingDelta", 0)
        let me = parseProfile(response.get("me"))
        return SyncResponse(events: events, lastId: lastId, opponentTick: opponentTick, ended: ended, winnerSlot: winnerSlot,
                            reason: reason, ratingDelta: delta, me: me)
    }

    static func parseProfile(_ v: JsonValue?) -> PlayerProfile? {
        guard let v = v, !v.isNull() else { return nil }
        return PlayerProfile(v.getInt("id", 0), v.getString("name", "PLAYER"), v.getInt("rating", Rank.START_RATING),
                             v.getInt("wins", 0), v.getInt("losses", 0), v.getInt("worldRank", 0), v.getBoolean("verified", false),
                             v.getString("state", "lobby"))
    }

    private static func parseInvite(_ v: JsonValue?) throws -> Invite? {
        guard let v = v, !v.isNull() else { return nil }
        return Invite(id: try v.getInt("id"), otherName: v.getString("otherName", "?"), otherRating: v.getInt("otherRating", Rank.START_RATING),
                      level: v.getInt("level", 0), speed: v.getString("speed", "MED"), status: v.getString("status", "pending"),
                      expiresIn: v.getInt("expiresIn", -1))
    }

    private static func parseMatch(_ v: JsonValue?) throws -> MatchInfo? {
        guard let v = v, !v.isNull() else { return nil }
        guard let seed = Int64(try v.getString("seed")) else { throw JsonError(description: "seed sayı değil") }
        return MatchInfo(matchId: try v.getInt("matchId"), slot: try v.getInt("slot"), seed: seed,
                         level: try v.getInt("level"), speed: try v.getString("speed"),
                         opponentName: v.getString("opponentName", "RIVAL"),
                         opponentRating: v.getInt("opponentRating", Rank.START_RATING))
    }

    // ---- Ortak yardımcılar ----

    private func post(_ path: String, _ jsonBody: String, _ onOk: @escaping (JsonValue) throws -> Void, _ onFail: @escaping (String?) -> Void) {
        let req = HttpRequest(method: "POST", url: baseUrl + path, timeoutMs: OnlineClient.TIMEOUT_MS,
                              headers: ["Content-Type": "application/json"], content: jsonBody)
        Gdx.net.sendHttpRequest(req, HttpListener(onResponse: { httpResponse in
            let status = httpResponse.getStatusCode()
            let result = httpResponse.getResultAsString()
            let value = OnlineClient.parse(result)
            var error = OnlineClient.errorOf(status, value)
            if error == nil, let value = value {
                do {
                    try onOk(value)
                    return
                } catch {
                    Gdx.app.error("OnlineClient", path + ": beklenmeyen cevap içeriği: " + OnlineClient.preview(result), error)
                }
                error = OnlineClient.ERR_BAD_RESPONSE
            } else if error == OnlineClient.ERR_BAD_RESPONSE {
                Gdx.app.error("OnlineClient", path + ": beklenmeyen cevap (HTTP \(status)): " + OnlineClient.preview(result))
            }
            onFail(error)
        }, onFailed: { t in
            Gdx.app.error("OnlineClient", path + ": istek ulaşmadı", t)
            onFail(OnlineClient.ERR_NETWORK)
        }, onCancelled: {
            onFail(OnlineClient.ERR_NETWORK)
        }))
    }

    static func parse(_ body: String?) -> JsonValue? {
        guard let b = body else { return nil }
        return JsonValue.parse(b)
    }

    /// Cevabın hata kodu/mesajı; başarılıysa nil. Nesne olmayan her cevap ve 5xx -> ERR_BAD_RESPONSE.
    static func errorOf(_ status: Int, _ value: JsonValue?) -> String? {
        guard let value = value, value.isObject(), status < 500 else { return ERR_BAD_RESPONSE }
        if status >= 200 && status < 300 { return nil }
        if let error = value.get("error"), error.isString() { return error.asString() }
        return "HTTP \(status)"
    }

    private static func preview(_ body: String?) -> String {
        guard let body = body else { return "(boş)" }
        let oneLine = body.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ").jtrim()
        return oneLine.jlength > 120 ? oneLine.jprefix(120) + "..." : oneLine
    }

    /// JSON string literal (tırnak + kaçış).
    static func q(_ s: String?) -> String {
        guard let s = s else { return "null" }
        var sb = "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": sb += "\\\""
            case "\\": sb += "\\\\"
            case "\n": sb += "\\n"
            case "\r": sb += "\\r"
            case "\t": sb += "\\t"
            default:
                if u.value < 0x20 { sb += String(format: "\\u%04x", u.value) } else { sb.unicodeScalars.append(u) }
            }
        }
        return sb + "\""
    }
}

/// Bir olayın, GÖNDERENİN kendi motorunda hangi tick'te olduğu bilgisiyle birlikte hâli.
/// GARBAGE için data "adet:renkler" (ör. "3:02" = 3 parça, RED+BLUE paletinden).
struct TimedAction {
    let tick: Int
    let action: InputAction
    let data: String?

    init(_ tick: Int, _ action: InputAction, _ data: String? = nil) {
        self.tick = tick
        self.action = action
        self.data = data
    }

    static func garbage(_ tick: Int, _ attack: GameEngine.GarbageAttack) -> TimedAction {
        var sb = "\(attack.count):"
        for c in attack.colors { sb += String(c.ordinal) }
        return TimedAction(tick, .GARBAGE, sb)
    }

    func applyTo(_ engine: GameEngine) {
        if action != .GARBAGE {
            action.applyTo(engine)
            return
        }
        if let attack = TimedAction.decodeGarbage(data) { engine.receiveGarbage(attack) }
    }

    /// Bozuk/eksik payload'da nil.
    static func decodeGarbage(_ data: String?) -> GameEngine.GarbageAttack? {
        guard let data = data, let colon = data.firstIndex(of: ":") else { return nil }
        guard let count = Int(data[data.startIndex..<colon]) else { return nil }
        var colors: [CapsuleColor] = []
        for ch in data[data.index(after: colon)...] {
            guard let d = ch.wholeNumberValue, let c = CapsuleColor(rawValue: d), ch.isASCII else { return nil }
            colors.append(c)
        }
        return GameEngine.GarbageAttack(count: count, colors: colors)
    }
}

/// Maç boyunca sunucuyla (server/sync.php) tek noktadan konuşan sınıf.
final class MatchSync {
    private static let SYNC_INTERVAL: Float = 0.1
    private static let CONNECTION_LOST_AFTER: Float = 15

    static let RESULT_WON = "WON"
    static let RESULT_LOST = "LOST"
    static let RESULT_FORFEIT = "FORFEIT"

    private let client: OnlineClient
    private let matchId: Int
    private let slot: Int

    private var outgoing: [TimedAction] = []
    private var incoming: [TimedAction] = []
    private var lastPolledId = 0
    private var opponentTick = 0
    private var myTick = 0

    private var inFlight = false
    private var timer = MatchSync.SYNC_INTERVAL
    private var pendingResult: String?

    private var ended = false
    private var winnerSlot = -1
    private var endReason: String?
    private var ratingDelta = 0

    private var failingFor: Float = 0
    private var matchGone = false
    private var lastError: String?

    init(_ client: OnlineClient, _ matchId: Int, _ slot: Int) {
        self.client = client
        self.matchId = matchId
        self.slot = slot
    }

    func queue(_ action: TimedAction) { outgoing.append(action) }

    func reportResult(_ result: String) {
        if pendingResult == nil { pendingResult = result }
    }

    /// Ekrandan çıkarken: "çekildim" der, cevabı beklemez.
    func forfeit() {
        if ended { return }
        client.sync(matchId, slot, myTick, lastPolledId, outgoing, MatchSync.RESULT_FORFEIT, nil)
        outgoing.removeAll()
    }

    func update(_ delta: Float, _ myTick: Int) {
        self.myTick = myTick
        if ended || matchGone { return }
        timer += delta
        failingFor += delta
        if inFlight || timer < MatchSync.SYNC_INTERVAL { return }
        timer = 0
        send()
    }

    private func send() {
        inFlight = true
        let batch = outgoing
        outgoing.removeAll()
        client.sync(matchId, slot, myTick, lastPolledId, batch, pendingResult, OnlineClient.SyncCallback(
            onSync: { [weak self] r in
                guard let self = self else { return }
                self.inFlight = false
                self.failingFor = 0
                self.lastError = nil
                self.lastPolledId = max(self.lastPolledId, r.lastId)
                self.incoming.append(contentsOf: r.events)
                self.opponentTick = max(self.opponentTick, r.opponentTick)
                if r.ended {
                    self.ended = true
                    self.winnerSlot = r.winnerSlot
                    self.endReason = r.reason
                    self.ratingDelta = r.ratingDelta
                    OnlineSession.updateProfile(r.me)
                    self.pendingResult = nil
                }
            },
            onMatchNotFound: { [weak self] in
                guard let self = self else { return }
                self.inFlight = false
                self.matchGone = true
                self.lastError = "match_not_found"
            },
            onError: { [weak self] message in
                guard let self = self else { return }
                self.inFlight = false
                self.lastError = message
                // Gönderilemeyen olaylar kaybolmasın: kuyruğun başına geri koy.
                self.outgoing.insert(contentsOf: batch, at: 0)
            }))
    }

    func drainIncoming() -> [TimedAction] {
        if incoming.isEmpty { return [] }
        let out = incoming
        incoming.removeAll()
        return out
    }

    func getOpponentTick() -> Int { return opponentTick }
    func isEnded() -> Bool { return ended }
    func getWinnerSlot() -> Int { return winnerSlot }
    func getEndReason() -> String? { return endReason }
    func getRatingDelta() -> Int { return ratingDelta }
    func isConnectionLost() -> Bool { return matchGone || failingFor >= MatchSync.CONNECTION_LOST_AFTER }
    func getLastError() -> String? { return lastError }
}

/// Rakibin tahtasını kendi ekranımızda yeniden oynatır: rakibin olaylarını tick numarasıyla
/// yerel bir GameEngine kopyasına tam doğru anda uygular.
final class RemoteEngineDriver {
    private let remoteEngine: GameEngine
    private let sync: MatchSync
    private var pending: [TimedAction] = []

    init(_ remoteEngine: GameEngine, _ sync: MatchSync) {
        self.remoteEngine = remoteEngine
        self.sync = sync
    }

    func update(_ delta: Float) {
        pending.append(contentsOf: sync.drainIncoming())
        if remoteEngine.getState() != .RUNNING { return }

        applyDueActions()

        let target = sync.getOpponentTick()
        while step(target) {
            // bilinen son tick'e kadar yetiş
        }
        applyDueActions()
    }

    private func step(_ target: Int) -> Bool {
        if remoteEngine.getTickCount() >= target { return false }
        applyDueActions()
        remoteEngine.tick()
        return remoteEngine.getState() == .RUNNING
    }

    private func applyDueActions() {
        let now = remoteEngine.getTickCount()
        while let first = pending.first, first.tick <= now {
            pending.removeFirst().applyTo(remoteEngine)
        }
    }

    func getEngine() -> GameEngine { return remoteEngine }
}
