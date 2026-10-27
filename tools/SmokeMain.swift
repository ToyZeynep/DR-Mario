import Foundation

// ---- Sahte sunucu ----
final class FakeServer {
    var heartbeats = 0
    var invited = false
    var matchTick = 0
    var myResult: String?
    var syncCount = 0
    var log: [String] = []

    func handle(_ req: HttpRequest) -> HttpResponse? {
        let path = (req.url as NSString).lastPathComponent
        log.append(path)
        guard let body = try? JSONSerialization.jsonObject(with: req.content.data(using: .utf8)!) as? [String: Any] else {
            return HttpResponse(statusCode: 400, body: "{\"error\":\"bad\"}")
        }
        let me: [String: Any] = ["id": 1, "name": "GUEST-4242", "rating": 1000, "wins": 3, "losses": 2, "worldRank": 0, "verified": false, "state": "lobby"]
        switch path {
        case "login.php":
            precondition(body["kind"] as? String == "guest")
            return ok(["session": "SESSION-1", "me": me])
        case "heartbeat.php":
            if body["leave"] != nil { return ok(["ok": true]) }
            heartbeats += 1
            var players: [[String: Any]] = []
            for i in 0..<14 {
                players.append(["id": 10 + i, "name": "ANDROID\(i)", "rating": 980 + i * 70, "wins": i, "losses": 1, "worldRank": i + 1,
                                "verified": i % 2 == 0, "state": i == 3 ? "in_match" : (i == 5 ? "queue" : "lobby")])
            }
            var resp: [String: Any] = ["me": me, "players": players]
            if invited && heartbeats > 3 {
                resp["match"] = ["matchId": 77, "slot": 0, "seed": "9876543210123", "level": 2, "speed": "HI",
                                 "opponentName": "ANDROID0", "opponentRating": 980]
            } else if invited {
                resp["outgoing"] = ["id": 55, "otherName": "ANDROID0", "otherRating": 980, "level": 2, "speed": "HI", "status": "pending", "expiresIn": 25]
            }
            return ok(resp)
        case "invite.php":
            invited = true
            heartbeats = 0
            return ok(["inviteId": 55, "expiresIn": 30])
        case "respond.php":
            return ok(["match": NSNull()])
        case "leaderboard.php":
            var top: [[String: Any]] = []
            for i in 0..<30 { top.append(["id": 100 + i, "name": "TOP\(i)", "rating": 2000 - i * 30, "wins": 50 - i, "losses": i, "worldRank": i + 1, "verified": true]) }
            return ok(["players": top, "me": me])
        case "sync.php":
            syncCount += 1
            let tick = body["tick"] as? Int ?? 0
            if let r = body["result"] as? String { myResult = r }
            var resp: [String: Any] = ["events": [], "lastId": syncCount, "opponentTick": max(0, tick - 3), "status": "running"]
            if myResult != nil {
                resp["status"] = "ended"; resp["winnerSlot"] = myResult == "WON" ? 0 : 1; resp["reason"] = myResult; resp["ratingDelta"] = myResult == "WON" ? 20 : -20
                resp["me"] = me
            } else if syncCount % 7 == 0 {
                resp["events"] = [["tick": max(0, tick - 4), "action": "MOVE_LEFT"], ["tick": max(0, tick - 3), "action": "HARD_DROP"],
                                  ["tick": max(0, tick - 3), "action": "GARBAGE", "data": "2:01"], ["tick": tick, "action": "FUTURE_ACTION"]]
            }
            return ok(resp)
        case "delete_account.php":
            return ok(["ok": true])
        default:
            return HttpResponse(statusCode: 404, body: "<html>not found</html>")
        }
    }

    private func ok(_ obj: [String: Any]) -> HttpResponse {
        return HttpResponse(statusCode: 200, body: jsonString(obj))
    }
}

// ---- Sürücü ----
let server = FakeServer()
Gdx.net.interceptor = { server.handle($0) }
Gdx.graphics.width = 844; Gdx.graphics.height = 390
Gdx.graphics.backBufferWidth = 2532; Gdx.graphics.backBufferHeight = 1170
Gdx.graphics.deltaTime = 1.0 / 60.0
for key in UserDefaults.standard.dictionaryRepresentation().keys { UserDefaults.standard.removeObject(forKey: key) }

let game = VirusHuntGame(nil, Analytics.Device(platform: "ios", brand: "Apple", model: "Test", osVersion: "18", appVersion: "1.15", versionCode: 19, deviceKey: "ABC"))
var frames = 0
func frame(_ n: Int = 1) {
    for _ in 0..<n {
        Gdx.app.runPending()
        Gdx.input.processEvents()
        game.render()
        frames += 1
    }
}
let scale = Float(Gdx.graphics.height) / 224
let worldW = Float(Gdx.graphics.width) / scale
let ox = (worldW - 256) / 2
func tap(_ wx: Float, _ wy: Float, pointer: Int = 0) {
    let sx = Int(wx * scale), sy = Int(Float(Gdx.graphics.height) - wy * scale)
    Gdx.input.post(.touchDown(x: sx, y: sy, pointer: pointer))
    frame()
    Gdx.input.post(.touchUp(x: sx, y: sy, pointer: pointer))
    frame()
}
func key(_ k: Int) { Gdx.input.post(.keyDown(k)); frame(); Gdx.input.post(.keyUp(k)); frame() }
func screen() -> String { return game.getScreen().map { String(describing: type(of: $0)) } ?? "nil" }
func expect(_ name: String, _ line: Int = #line) {
    if screen() != name { print("BEKLENMEYEN EKRAN (satır \(line)): \(screen()) != \(name)"); exit(1) }
    print("  ✓ \(name)")
}
func playUntilOver(_ maxFrames: Int, _ name: String) {
    var n = 0
    while screen() == name && n < maxFrames {
        if n % 20 == 0 { Gdx.input.post(.keyDown(Input.Keys.SPACE)) }
        if n % 20 == 1 { Gdx.input.post(.keyUp(Input.Keys.SPACE)) }
        if n % 33 == 0 { tap(ox + 30, 90, pointer: 1) }     // sol tuş bölgesi
        if n % 47 == 0 { tap(worldW - 20, 55, pointer: 2) } // döndürme
        frame(); n += 1
    }
}

game.create(); game.resize(Gdx.graphics.width, Gdx.graphics.height)
frame(5)
print("1) İlk açılış hesap seçimi"); expect("AccountSetupScreen")
tap(ox + 128, 85) // MİSAFİR
frame(10); expect("TitleScreen")
precondition(OnlineSession.isSignedIn(), "giriş yapılmadı")

print("2) Tek oyuncu")
tap(ox + 128, 72); expect("LevelSelectScreen")
tap(ox + LevelSelectScreen.START_X + 10, LevelSelectScreen.CORNER_BTN_Y + 5); expect("SinglePlayerScreen")
frame(60)
tap(ox + SinglePlayerScreen.PAUSE_BTN_CX, SinglePlayerScreen.PAUSE_BTN_CY) // duraklat
frame(10); key(Input.Keys.ESCAPE) // sürdür
playUntilOver(20000, "SinglePlayerScreen")
frame(60); tap(ox + 128, 100); frame(5); expect("TitleScreen")

print("3) CPU VS")
key(Input.Keys.DOWN); key(Input.Keys.DOWN); key(Input.Keys.ENTER); expect("LevelSelectScreen")
key(Input.Keys.DOWN); key(Input.Keys.DOWN); key(Input.Keys.RIGHT) // HARD
key(Input.Keys.ENTER); expect("VsScreen")
playUntilOver(40000, "VsScreen")
frame(60); tap(ox + 128, 100); frame(5); expect("TitleScreen")

print("4) Ayarlar / hesap / lider tablosu / yardım")
key(Input.Keys.UP); key(Input.Keys.ENTER); expect("SettingsScreen")
tap(ox + 40 + 176 - 44 - 8 - 22, 160 - 34 + 10) // MÜZİK AÇIK
tap(ox + 40 + 176 - 22, 160 - 34 + 10) // KAPALI
precondition(!GameMusic.isEnabled())
tap(ox + 128, 170); expect("AccountScreen")
frame(5)
tap(ox + 128, 75); expect("LeaderboardScreen")
frame(5)
for _ in 0..<5 { tap(ox + 128, 60) }
key(Input.Keys.ESCAPE); expect("AccountScreen")
key(Input.Keys.ESCAPE); expect("SettingsScreen")
key(Input.Keys.ESCAPE); expect("TitleScreen")
tap(ox + 20, 211); expect("HelpScreen")
for _ in 0..<10 { tap(ox + 161, 15) }
for _ in 0..<3 { tap(ox + 40, 100) }
for p in HelpText.pages(Lang.current()) { _ = HelpScreen.lines(p) }
tap(ox + 227, 15); expect("TitleScreen")

print("5) Online lobi + davet + maç")
tap(ox + 128, 72 - 14); expect("LevelSelectScreen")
tap(ox + LevelSelectScreen.START_X + 10, LevelSelectScreen.CORNER_BTN_Y + 5); expect("OnlineLobbyScreen")
frame(120)
precondition(OnlineHub.get()?.state()?.players.count == 14, "liste gelmedi")
// liste kaydırma (sürükleme)
let lx = ox + 180
Gdx.input.post(.touchDown(x: Int(lx * scale), y: Int(Float(Gdx.graphics.height) - 60 * scale), pointer: 0)); frame()
for k in 1...10 { Gdx.input.post(.touchDragged(x: Int(lx * scale), y: Int(Float(Gdx.graphics.height) - (60 + Float(k) * 4) * scale), pointer: 0)); frame() }
Gdx.input.post(.touchUp(x: Int(lx * scale), y: Int(Float(Gdx.graphics.height) - 100 * scale), pointer: 0)); frame()
key(Input.Keys.UP); key(Input.Keys.UP); key(Input.Keys.UP); key(Input.Keys.UP); key(Input.Keys.UP)
tap(ox + 112 + 2 + 40, 153) // ilk satır: ANDROID0 (en yüksek puan ilk sırada değil ama sunucu sırasıyla)
frame(30)
print("   hub modal:", OnlineHub.get()!.isModalActive())
frame(400)
expect("OnlineVsScreen")
playUntilOver(40000, "OnlineVsScreen")
print("   sunucuya bildirilen sonuç:", server.myResult ?? "-")
expect("OnlineLobbyScreen")
key(Input.Keys.ESCAPE); expect("TitleScreen")

print("6) Hesap silme")
key(Input.Keys.UP); key(Input.Keys.ENTER); expect("SettingsScreen")
tap(ox + 128, 170); expect("AccountScreen")
tap(ox + 28 + 48, 51); frame(2) // SİL
tap(ox + 20 + 12 + 45, 70 + 8 + 9) // EVET, SİL
frame(10); expect("AccountSetupScreen")
precondition(AccountPrefs.mode().isEmpty)

print("7) Uygulama arka plan / ön plan")
game.pause(); frame(5); game.resume(); frame(5)

print("TAMAM: \(frames) kare, \(server.log.count) istek (\(Set(server.log).sorted().joined(separator: ", ")))")
