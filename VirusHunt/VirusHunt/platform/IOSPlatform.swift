//
//  IOSPlatform.swift
//  VirusHunt
//
//  Android başlatıcısındaki platform parçalarının (AndroidLauncher, AndroidAds, AndroidFeedback,
//  AndroidReview) iOS karşılıkları ve uygulamanın giriş noktası.
//
//   - Hesap: iOS'ta Play Games yok -> GuestAccountService (masaüstü sürümdeki gibi). Misafir hesapla
//     aynı sunucuda online oynanır; Android oyuncularıyla aynı lobi.
//   - Reklam: AdMob + UMP (AB/BK onayı), kurallar core/net/Services.swift (Ads) ile aynı.
//   - Geri bildirim: yerel pencere -> rummuscan.online/api/v1/feedback.
//   - Değerlendirme: App Store'un kendi penceresi (StoreKit), ReviewPrompt kurallarıyla.
//

#if os(iOS)
import UIKit
import StoreKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

// MARK: - Uygulama girişi

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let gameCenter = GameCenterAccountService()
        let controller = GameViewController {
            VirusHuntGame(gameCenter, IOSPlatform.analyticsDevice())
        }
        gameCenter.controller = controller
        #if DEBUG
        gameCenter.runSelfTestIfRequested()
        #endif
        IOSPlatform.install(controller)
        window.rootViewController = controller
        window.backgroundColor = .black
        window.makeKeyAndVisible()
        self.window = window
    }
}

enum IOSPlatform {
    /// AndroidLauncher.onCreate'teki Feedback/ReviewPrompt/Ads kurulumunun karşılığı.
    static func install(_ controller: GameViewController) {
        Feedback.setPlatform(IOSFeedback(controller))
        ReviewPrompt.setPlatform(IOSReview(controller))
        Ads.setPlatform(IOSAds.make(controller))
    }

    /// Analiz için cihaz bilgisi (KVKK: marka/model/sürüm; kişisel veri yok).
    @MainActor static func analyticsDevice() -> Analytics.Device {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let code = Int64(info["CFBundleVersion"] as? String ?? "") ?? 0
        return Analytics.Device(platform: "ios", brand: "Apple", model: hardwareModel(),
                                osVersion: UIDevice.current.systemVersion, appVersion: version, versionCode: code,
                                deviceKey: UIDevice.current.identifierForVendor?.uuidString)
    }

    /// "iPhone15,2" gibi donanım kimliği.
    @MainActor private static func hardwareModel() -> String {
        var info = utsname()
        uname(&info)
        let model = withUnsafePointer(to: &info.machine) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return model.isEmpty ? UIDevice.current.model : model
    }
}

// MARK: - Değerlendirme

/// App Store değerlendirme penceresi; ne zaman isteneceği ReviewPrompt'ta.
final class IOSReview: ReviewPrompt.Platform {
    private weak var controller: UIViewController?

    init(_ controller: UIViewController) { self.controller = controller }

    func request() {
        // Sonuç ekranı otursun diye kısa bir gecikme (Android'deki gibi).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            MainActor.assumeIsolated {
                guard let scene = self?.controller?.view.window?.windowScene else { return }
                AppStore.requestReview(in: scene)
            }
        }
    }
}

// MARK: - Geri bildirim

/// Ana ekrandaki "GERİ BİLDİRİM": puan (5 yıldız), mesaj, isteğe bağlı e-posta.
final class IOSFeedback: Feedback.Platform {
    private weak var controller: GameViewController?

    init(_ controller: GameViewController) { self.controller = controller }

    func open() {
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let c = self?.controller else { return }
                let vc = FeedbackViewController()
                vc.modalPresentationStyle = .formSheet
                c.topPresenter().present(vc, animated: true)
            }
        }
    }
}

private final class FeedbackViewController: UIViewController, UITextViewDelegate {
    private var stars = 0
    private var starButtons: [UIButton] = []
    private let message = UITextView()
    private let placeholder = UILabel()
    private let email = UITextField()
    private let errorLabel = UILabel()
    private let sendButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let S = FeedbackStrings.get

        let title = UILabel()
        title.text = S("title")
        title.font = .preferredFont(forTextStyle: .headline)
        title.textAlignment = .center

        let starRow = UIStackView()
        starRow.axis = .horizontal
        starRow.spacing = 6
        starRow.accessibilityLabel = S("rating")
        for i in 1...5 {
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: "star"), for: .normal)
            b.tintColor = UIColor(red: 1, green: 0.70, blue: 0, alpha: 1)
            b.tag = i
            b.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
            starButtons.append(b)
            starRow.addArrangedSubview(b)
        }

        message.font = .preferredFont(forTextStyle: .body)
        message.layer.borderColor = UIColor.separator.cgColor
        message.layer.borderWidth = 1
        message.layer.cornerRadius = 6
        message.delegate = self
        message.heightAnchor.constraint(equalToConstant: 96).isActive = true
        placeholder.text = S("hint")
        placeholder.textColor = .placeholderText
        placeholder.font = message.font
        placeholder.numberOfLines = 0
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        message.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.leadingAnchor.constraint(equalTo: message.leadingAnchor, constant: 6),
            placeholder.topAnchor.constraint(equalTo: message.topAnchor, constant: 8),
            placeholder.widthAnchor.constraint(equalTo: message.widthAnchor, constant: -12),
        ])

        email.placeholder = S("email_hint")
        email.keyboardType = .emailAddress
        email.autocapitalizationType = .none
        email.autocorrectionType = .no
        email.borderStyle = .roundedRect

        let note = UILabel()
        note.text = S("privacy")
        note.font = .preferredFont(forTextStyle: .footnote)
        note.textColor = .secondaryLabel
        note.numberOfLines = 0

        errorLabel.textColor = .systemRed
        errorLabel.font = .preferredFont(forTextStyle: .footnote)
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let cancel = UIButton(type: .system)
        cancel.setTitle(S("cancel"), for: .normal)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        sendButton.setTitle(S("send"), for: .normal)
        sendButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        let buttons = UIStackView(arrangedSubviews: [cancel, UIView(), sendButton])
        buttons.axis = .horizontal

        let stack = UIStackView(arrangedSubviews: [title, starRow, message, email, note, errorLabel, buttons])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .fill
        starRow.setContentHuggingPriority(.required, for: .horizontal)
        let starWrap = UIStackView(arrangedSubviews: [starRow])
        starWrap.axis = .vertical
        starWrap.alignment = .center
        stack.insertArrangedSubview(starWrap, at: 1)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40),
        ])
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholder.isHidden = !textView.text.isEmpty
    }

    @objc private func starTapped(_ sender: UIButton) {
        stars = sender.tag
        for b in starButtons {
            b.setImage(UIImage(systemName: b.tag <= stars ? "star.fill" : "star"), for: .normal)
        }
    }

    @objc private func cancelTapped() { dismiss(animated: true) }

    private func showError(_ text: String) {
        errorLabel.text = text
        errorLabel.isHidden = false
    }

    @objc private func sendTapped() {
        let S = FeedbackStrings.get
        let text = (message.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count < 3 {
            showError(S("empty"))
            message.becomeFirstResponder()
            return
        }
        let mail = (email.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !mail.isEmpty && mail.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) == nil {
            showError(S("email_invalid"))
            email.becomeFirstResponder()
            return
        }
        errorLabel.isHidden = true
        sendButton.isEnabled = false
        let rating = stars
        // Gönderim oyun (render) thread'inde; sonuç yine arayüz thread'ine döner.
        Gdx.app.postRunnable { [weak self] in
            Feedback.send(text, rating, mail.isEmpty ? nil : mail) { ok in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if ok {
                        let presenter = self.presentingViewController
                        self.dismiss(animated: true) { IOSToast.show(S("thanks"), in: presenter?.view) }
                    } else {
                        self.sendButton.isEnabled = true
                        self.showError(S("failed"))
                    }
                }
            }
        }
    }
}

/// Android Toast'ının karşılığı: ekranın altında birkaç saniye kalan kısa yazı.
@MainActor
enum IOSToast {
    static func show(_ text: String, in view: UIView?) {
        guard let view = view else { return }
        let label = PaddedLabel()
        label.text = text
        label.textColor = .white
        label.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alpha = 0
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
        ])
        UIView.animate(withDuration: 0.2) { label.alpha = 1 }
        UIView.animate(withDuration: 0.3, delay: 3, options: []) { label.alpha = 0 } completion: { _ in label.removeFromSuperview() }
    }

    private final class PaddedLabel: UILabel {
        override func drawText(in rect: CGRect) { super.drawText(in: rect.insetBy(dx: 14, dy: 8)) }
        override var intrinsicContentSize: CGSize {
            let s = super.intrinsicContentSize
            return CGSize(width: s.width + 28, height: s.height + 16)
        }
    }
}

// MARK: - Reklamlar

/// AndroidAds'in karşılığı: ödüllü "devam" ve oyun sonu geçiş reklamı + AB/BK onay penceresi (UMP).
/// Kimlikler: geliştirme derlemesinde Google'ın test reklamları; yayın derlemesinde AdConfig'teki
/// iOS reklam birimleri (boşsa reklamlar kapalı kalır, oyun reklamsız çalışır).
enum AdConfig {
    /// AdMob'daki iOS uygulamasının reklam birimleri (ca-app-pub-XXXX/YYYY). Info.plist'teki
    /// GADApplicationIdentifier da aynı iOS uygulamasının kimliği olmalı.
    static let RELEASE_REWARDED_ID = "ca-app-pub-7359263265391774/1702717957"
    static let RELEASE_INTERSTITIAL_ID = "ca-app-pub-7359263265391774/1020403700"

    static let TEST_REWARDED_ID = "ca-app-pub-3940256099942544/1712485313"
    static let TEST_INTERSTITIAL_ID = "ca-app-pub-3940256099942544/4411468910"

    static var rewardedId: String {
        #if DEBUG
        return TEST_REWARDED_ID
        #else
        return RELEASE_REWARDED_ID
        #endif
    }

    static var interstitialId: String {
        #if DEBUG
        return TEST_INTERSTITIAL_ID
        #else
        return RELEASE_INTERSTITIAL_ID
        #endif
    }
}

#if canImport(GoogleMobileAds) && canImport(UserMessagingPlatform)
extension AdMobConfiguration {
    /// Geçiş reklamı sıklığı oyun tarafında (Ads: 3 oyunda bir, 2 dk arayla); burada ek bekleme yok.
    /// Test kimlikleri DEBUG derlemede AdMobManager tarafından kendiliğinden kullanılır.
    static let virusHunt = AdMobConfiguration(
        interstitialUnitID: AdConfig.RELEASE_INTERSTITIAL_ID,
        rewardedUnitID: AdConfig.RELEASE_REWARDED_ID,
        interstitialCooldown: 0,
        maxAdContentRating: .teen
    )
}

/// Oyunun Ads.Platform'u ile ortak AdMobManager arasındaki köprü: onay (UMP) → ATT → SDK sırası,
/// ön yükleme ve yeniden deneme AdMobManager'da; oyuna özel kurallar ve onay istatistiği burada.
final class IOSAds: Ads.Platform {
    static func make(_ controller: GameViewController) -> Ads.Platform? {
        if AdConfig.RELEASE_REWARDED_ID.isEmpty || AdConfig.RELEASE_INTERSTITIAL_ID.isEmpty { return nil }
        return IOSAds()
    }

    private init() {
        Task { @MainActor in
            let before = ConsentInformation.shared.consentStatus
            await AdMobManager.shared.start(with: .virusHunt)
            if before != .obtained && ConsentInformation.shared.consentStatus == .obtained {
                IOSAds.reportConsent("first_launch")
            }
        }
    }

    // ---- Ads.Platform ----

    func isRewardedReady() -> Bool {
        return MainActor.assumeIsolated { AdMobManager.shared.isRewardedReady }
    }

    func showRewarded(_ onRewarded: @escaping () -> Void, _ onClosed: @escaping () -> Void) {
        Task { @MainActor in
            let earned = await AdMobManager.shared.showRewarded()
            Gdx.app.postRunnable {
                if earned { onRewarded() }
                onClosed()
            }
        }
    }

    func showInterstitial() {
        Task { @MainActor in await AdMobManager.shared.showInterstitial() }
    }

    func isPrivacyOptionsRequired() -> Bool {
        return ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    func showPrivacyOptions() {
        Task { @MainActor in
            await AdMobManager.shared.presentPrivacyOptions()
            IOSAds.reportConsent("privacy_options")
        }
    }

    /// Onay penceresinin sonucu, anonim istatistik (Android'deki reportConsent ile aynı kurallar).
    private static func reportConsent(_ source: String) {
        let obtained = ConsentInformation.shared.consentStatus == .obtained
        let purposes = UserDefaults.standard.string(forKey: "IABTCF_PurposeConsents") ?? ""
        let result: String
        if !obtained { result = "undecided" }
        else if !purposes.contains("1") { result = "rejected" }
        else if !purposes.contains("0") { result = "consent_all" }
        else { result = "consent_custom" }
        let country = (Locale.current.region?.identifier ?? "").uppercased()
        let bundle = Bundle.main.bundleIdentifier ?? ""
        Gdx.app.postRunnable {
            Analytics.adConsent(source, result, country.count == 2 ? country : "", purposes, bundle)
        }
    }
}
#else
/// Reklam SDK'sı eklenmemiş derleme: reklam yok (masaüstü sürümdeki gibi).
enum IOSAds {
    static func make(_ controller: GameViewController) -> Ads.Platform? { return nil }
}
#endif
#endif
