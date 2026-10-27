//
//  Account.swift
//  VirusHunt
//
//  com.rummuscan.core.net: AccountPrefs, AccountService, GuestAccountService, Achievement,
//  OnlineSession, PlayerProfile, Rank, MatchInfo (VirusHunt Android sürümünden birebir).
//

import Foundation

/// Cihazda saklanan hesap tercihleri: seçilen giriş yolu (Play Games / misafir) ve misafir kimliği.
enum AccountPrefs {
    static let MODE_PGS = "pgs"
    static let MODE_GUEST = "guest"

    private static let PREFS = "virushunt-account"
    private static let KEY_MODE = "mode"
    private static let KEY_GUEST_ID = "guestId"

    private static func prefs() -> Preferences { return Gdx.app.getPreferences(PREFS) }

    /// "pgs", "guest" ya da henüz seçilmediyse "".
    static func mode() -> String { return prefs().getString(KEY_MODE, "") }

    static func setMode(_ mode: String?) {
        let p = prefs()
        p.putString(KEY_MODE, mode ?? "")
        p.flush()
    }

    /// Cihaza bağlı misafir kimliği; ilk çağrıda üretilir.
    static func guestId() -> String {
        let p = prefs()
        if let id = p.getString(KEY_GUEST_ID), !id.isEmpty { return id }
        let id = UUID().uuidString.lowercased()
        p.putString(KEY_GUEST_ID, id)
        p.flush()
        return id
    }

    /// Hesap silindikten sonra: tercih ve misafir kimliği sıfırlanır.
    static func reset() {
        let p = prefs()
        p.remove(KEY_MODE)
        p.remove(KEY_GUEST_ID)
        p.flush()
    }
}

/// Google Play Games'e yansıtılan başarımlar (iOS'ta karşılığı yok; misafir hesapta no-op).
enum Achievement {
    case FIRST_ONLINE_WIN, ONLINE_WINS_10, ONLINE_WINS_50, REACH_GOLD, REACH_DIAMOND
}

/// login.php'ye gidecek kimlik kanıtı.
struct Credentials {
    /// "pgs" (Play Games) ya da "guest".
    let kind: String
    /// pgs: server auth code; guest: cihaza bağlı kalıcı UUID.
    let secret: String
    let displayName: String
}

protocol SignInCallback {
    func onSignedIn(_ credentials: Credentials)
    func onFailed(_ message: String)
}

struct SignIn: SignInCallback {
    var signedIn: (Credentials) -> Void
    var failed: (String) -> Void
    func onSignedIn(_ credentials: Credentials) { signedIn(credentials) }
    func onFailed(_ message: String) { failed(message) }
}

/// Oyuncu hesabının platforma özgü kısmı (Android: Play Games; iOS/masaüstü: misafir).
protocol AccountService: AnyObject {
    func isPlayGamesAvailable() -> Bool
    /// "pgs_not_configured" ya da "pgs_unavailable".
    func playGamesUnavailableReason() -> String
    func signInWithPlayGames(_ callback: SignInCallback)
    func signInAsGuest(_ callback: SignInCallback)
    func submitRating(_ rating: Int)
    func unlockAchievement(_ achievement: Achievement)
    func hasNativeLeaderboardUi() -> Bool
    func showNativeLeaderboard()
}

/// Play Games olmayan platformlar için hesap servisi: yalnızca misafir girişi. Ad, kimlikten
/// türeyen sabit bir "GUEST-1234"tür.
final class GuestAccountService: AccountService {
    func isPlayGamesAvailable() -> Bool { return false }
    func playGamesUnavailableReason() -> String { return "pgs_unavailable" }

    func signInWithPlayGames(_ callback: SignInCallback) {
        Gdx.app.postRunnable { callback.onFailed("pgs_unavailable") }
    }

    func signInAsGuest(_ callback: SignInCallback) {
        let id = AccountPrefs.guestId()
        callback.onSignedIn(Credentials(kind: "guest", secret: id, displayName: GuestAccountService.guestName(id)))
    }

    /// UUID'nin hash'inden 0000-9999 arası sabit bir numara (Java String.hashCode ile aynı).
    static func guestName(_ uuid: String) -> String {
        let n = floorMod(Int(uuid.javaHashCode), 10000)
        return "GUEST-" + String(format: "%04d", n)
    }

    func submitRating(_ rating: Int) {}
    func unlockAchievement(_ achievement: Achievement) {}
    func hasNativeLeaderboardUi() -> Bool { return false }
    func showNativeLeaderboard() {}
}

/// Uygulama ömrü boyunca tek olan online oturum.
enum OnlineSession {
    private static var accountsService: AccountService = GuestAccountService()
    private static var tokenValue: String?
    private static var meValue: PlayerProfile?

    static func initialize(_ service: AccountService?) {
        accountsService = service ?? GuestAccountService()
    }

    static func accounts() -> AccountService { return accountsService }

    static func isSignedIn() -> Bool { return tokenValue != nil && meValue != nil }
    static func token() -> String? { return tokenValue }
    static func me() -> PlayerProfile? { return meValue }

    static func signedIn(_ sessionToken: String, _ profile: PlayerProfile?) {
        tokenValue = sessionToken
        meValue = profile
    }

    static func updateProfile(_ profile: PlayerProfile?) {
        if let p = profile { meValue = p }
    }

    static func signOut() {
        tokenValue = nil
        meValue = nil
    }
}

/// Sunucunun bir oyuncu için gönderdiği bilgiler.
struct PlayerProfile {
    let id: Int
    /// Ekranda görünen ad (sunucu A-Z0-9 ve boşluğa indirger, en çok 12 karakter).
    let name: String
    let rating: Int
    let wins: Int
    let losses: Int
    /// Dünya sıralamasındaki yeri (1 = en iyi); bilinmiyorsa 0.
    let worldRank: Int
    /// Google Play Games hesabı mı (true) yoksa cihaza bağlı misafir mi (false).
    let verified: Bool
    /// "lobby", "queue" ya da "in_match".
    let state: String

    init(_ id: Int, _ name: String, _ rating: Int, _ wins: Int, _ losses: Int, _ worldRank: Int, _ verified: Bool, _ state: String? = "lobby") {
        self.id = id
        self.name = name
        self.rating = rating
        self.wins = wins
        self.losses = losses
        self.worldRank = worldRank
        self.verified = verified
        self.state = state ?? "lobby"
    }

    func inMatch() -> Bool { return state == "in_match" }
    func searching() -> Bool { return state == "queue" }
    func rank() -> Rank { return Rank.fromRating(rating) }
    func games() -> Int { return wins + losses }
}

/// Online VS rütbe kademeleri; sunucu yalnızca puan gönderir, kademe burada hesaplanır.
enum Rank: Int, CaseIterable {
    case BRONZE, SILVER, GOLD, PLATINUM, DIAMOND, MASTER

    static let START_RATING = 1000
    /// Online maçta galibiyette kazanılan / mağlubiyette kaybedilen sabit puan.
    static let MATCH_POINTS = 20

    var minRating: Int {
        switch self {
        case .BRONZE: return 0
        case .SILVER: return 1100
        case .GOLD: return 1250
        case .PLATINUM: return 1400
        case .DIAMOND: return 1600
        case .MASTER: return 1800
        }
    }

    private var text: Txt {
        switch self {
        case .BRONZE: return .RANK_BRONZE
        case .SILVER: return .RANK_SILVER
        case .GOLD: return .RANK_GOLD
        case .PLATINUM: return .RANK_PLATINUM
        case .DIAMOND: return .RANK_DIAMOND
        case .MASTER: return .RANK_MASTER
        }
    }

    func label() -> String { return text.s() }

    static func fromRating(_ rating: Int) -> Rank {
        var result = Rank.BRONZE
        for r in Rank.allCases where rating >= r.minRating { result = r }
        return result
    }

    /// Bir üst kademe; MASTER'da nil.
    func next() -> Rank? { return Rank(rawValue: rawValue + 1) }
    var ordinal: Int { return rawValue }
}

/// Eşleşme kurulduğunda sunucudan gelen bilgiler.
struct MatchInfo {
    let matchId: Int
    /// Bu istemcinin slotu: 0 ya da 1.
    let slot: Int
    /// İki motorun da aynı virüs/hap dizisini üretmesi için ortak seed.
    let seed: Int64
    let level: Int
    let speed: String
    let opponentName: String
    let opponentRating: Int
}
