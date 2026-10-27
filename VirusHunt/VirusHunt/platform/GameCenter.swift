//
//  GameCenter.swift
//  VirusHunt
//
//  iOS hesap servisi: Android'deki Play Games'in yerini Game Center alır. Oyun tarafı bunu
//  "doğrulanmış platform hesabı" (AccountPrefs.MODE_PGS) olarak görür; sunucuya kind "gc" ile
//  Game Center kimlik doğrulama imzası gider (rummuscan.online/virushunt-vs/login.php).
//

import UIKit
import GameKit

final class GameCenterAccountService: AccountService {
    weak var controller: GameViewController?

    private var authResolved = false
    private var waiting: [(Bool) -> Void] = []

    func isPlayGamesAvailable() -> Bool { return true }
    func playGamesUnavailableReason() -> String { return "pgs_unavailable" }

    func signInWithPlayGames(_ callback: SignInCallback) {
        authenticate { [weak self] ok in
            guard ok else {
                Gdx.app.postRunnable { callback.onFailed("sign_in_cancelled") }
                return
            }
            self?.fetchSignature(callback)
        }
    }

    func signInAsGuest(_ callback: SignInCallback) {
        let id = AccountPrefs.guestId()
        callback.onSignedIn(Credentials(kind: "guest", secret: id, displayName: GuestAccountService.guestName(id)))
    }

    func submitRating(_ rating: Int) {}
    func unlockAchievement(_ achievement: Achievement) {}
    func hasNativeLeaderboardUi() -> Bool { return false }
    func showNativeLeaderboard() {}

    // ---- Game Center ----

    /// authenticateHandler yalnızca bir kez kurulur; Game Center giriş ekranı gerekiyorsa gösterilir.
    fileprivate func authenticate(_ done: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            let player = GKLocalPlayer.local
            if player.isAuthenticated { done(true); return }
            if self.authResolved { done(false); return } // kullanıcı daha önce vazgeçti; iOS ekranı tekrar açmaz
            self.waiting.append(done)
            if self.waiting.count > 1 { return }
            player.authenticateHandler = { [weak self] viewController, error in
                if let error = error { print("GameCenter auth error: \(error.localizedDescription)") }
                guard let self = self else { return }
                if let vc = viewController {
                    MainActor.assumeIsolated { self.controller?.topPresenter().present(vc, animated: true) }
                    return
                }
                self.authResolved = true
                let ok = GKLocalPlayer.local.isAuthenticated
                let callbacks = self.waiting
                self.waiting.removeAll()
                callbacks.forEach { $0(ok) }
            }
        }
    }

    private func fetchSignature(_ callback: SignInCallback) {
        let player = GKLocalPlayer.local
        player.fetchItems(forIdentityVerificationSignature: { url, signature, salt, timestamp, error in
            guard error == nil, let url = url, let signature = signature, let salt = salt else {
                print("GameCenter signature error: \(error?.localizedDescription ?? "no data")")
                Gdx.app.postRunnable { callback.onFailed("sign_in_cancelled") }
                return
            }
            let extra = "\"playerId\":" + OnlineClient.q(player.teamPlayerID)
                + ",\"publicKeyUrl\":" + OnlineClient.q(url.absoluteString)
                + ",\"signature\":" + OnlineClient.q(signature.base64EncodedString())
                + ",\"salt\":" + OnlineClient.q(salt.base64EncodedString())
                + ",\"timestamp\":\(timestamp)"
            let credentials = Credentials(kind: "gc", secret: "", displayName: player.alias, extraJson: extra)
            Gdx.app.postRunnable { callback.onSignedIn(credentials) }
        })
    }
}

#if DEBUG
extension GameCenterAccountService {
    /// Geliştirme: "-vhGCTest" ile açılınca Game Center imzasını alıp sunucuya dryRun olarak gönderir
    /// (hesap açılmaz, veritabanı değişmez); sonuç konsola yazılır.
    func runSelfTestIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-vhGCTest") else { return }
        print("GCTEST start")
        authenticate { ok in
            print("GCTEST authenticated=\(ok) alias=\(GKLocalPlayer.local.alias)")
            guard ok else { return }
            self.signInWithPlayGames(SignIn(signedIn: { c in
                let body = "{\"kind\":\"gc\",\"name\":" + OnlineClient.q(c.displayName) + "," + c.extraJson + ",\"dryRun\":true}"
                var req = URLRequest(url: URL(string: "https://rummuscan.online/virushunt-vs/login.php")!)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = body.data(using: .utf8)
                URLSession.shared.dataTask(with: req) { data, resp, err in
                    let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                    print("GCTEST server \(code): \(data.flatMap { String(data: $0, encoding: .utf8) } ?? err?.localizedDescription ?? "")")
                }.resume()
            }, failed: { print("GCTEST sign-in failed: \($0)") }))
        }
    }
}
#endif
