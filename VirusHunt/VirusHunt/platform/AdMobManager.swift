import AppTrackingTransparency
import Combine
import GoogleMobileAds
import SwiftUI
import UserMessagingPlatform

struct AdMobConfiguration {
    var bannerUnitID: String?
    var interstitialUnitID: String?
    var rewardedUnitID: String?
    var interstitialCooldown: TimeInterval = 90
    var isChildDirected = false
    var maxAdContentRating: GADMaxAdContentRating?
    var nativeUnitID: String?
    var appOpenUnitID: String?
    var appOpenMinBackgroundDuration: TimeInterval = 4 * 60 * 60
    var appOpenMaxPerDay = 1
}

@MainActor
final class AdMobManager: ObservableObject {
    static let shared = AdMobManager()

    @Published private(set) var isStarted = false
    @Published private(set) var isRewardedReady = false
    @Published private(set) var isPrivacyOptionsRequired = false
    @Published private(set) var isPresentingFullScreenAd = false

    private var configuration = AdMobConfiguration()
    private var isGatheringConsent = false
    private var lastInterstitialDate: Date?
    private var interstitialSlot: AdSlot<InterstitialAd>?
    private var rewardedSlot: AdSlot<RewardedAd>?
    private var appOpenSlot: AdSlot<AppOpenAd>?
    private var backgroundedAt: Date?
    private let presenter = FullScreenPresenter()

    private init() {}

    var bannerUnitID: String? {
        configuration.bannerUnitID.map { Self.unitID($0, test: "ca-app-pub-3940256099942544/2435281174") }
    }

    var nativeUnitID: String? {
        configuration.nativeUnitID.map { Self.unitID($0, test: "ca-app-pub-3940256099942544/3986624511") }
    }

    func start(with configuration: AdMobConfiguration) async {
        guard !isGatheringConsent, !isStarted else { return }
        isGatheringConsent = true
        defer { isGatheringConsent = false }

        self.configuration = configuration
        if let id = configuration.interstitialUnitID {
            let unitID = Self.unitID(id, test: "ca-app-pub-3940256099942544/4411468910")
            interstitialSlot = AdSlot { try await InterstitialAd.load(with: unitID, request: Request()) }
        }
        if let id = configuration.rewardedUnitID {
            let unitID = Self.unitID(id, test: "ca-app-pub-3940256099942544/1712485313")
            rewardedSlot = AdSlot(
                load: { try await RewardedAd.load(with: unitID, request: Request()) },
                onReadyChange: { [weak self] in self?.isRewardedReady = $0 }
            )
        }

        if let id = configuration.appOpenUnitID {
            let unitID = Self.unitID(id, test: "ca-app-pub-3940256099942544/5575463023")
            appOpenSlot = AdSlot { try await AppOpenAd.load(with: unitID, request: Request()) }
        }

        await startSDKIfAllowed()
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: Self.consentParameters)
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            print("AdMob consent error: \(error.localizedDescription)")
        }
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        await requestTrackingIfNeeded()
        await startSDKIfAllowed()
    }

    func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            print("AdMob privacy options error: \(error.localizedDescription)")
        }
        await startSDKIfAllowed()
    }

    func reloadAds() {
        guard isStarted else { return }
        interstitialSlot?.preload()
        rewardedSlot?.preload()
        appOpenSlot?.preload()
    }

    func appDidEnterBackground() {
        backgroundedAt = Date()
        appOpenSlot?.preload()
    }

    @discardableResult
    func appDidBecomeActive() async -> Bool {
        defer { backgroundedAt = nil }
        guard let slot = appOpenSlot, let backgroundedAt,
              Date().timeIntervalSince(backgroundedAt) >= configuration.appOpenMinBackgroundDuration,
              Self.appOpenShownToday < configuration.appOpenMaxPerDay,
              canPresent, !Self.isAnotherScreenPresented else {
            appOpenSlot?.preload()
            return false
        }
        guard let ad = slot.take() else {
            slot.preload()
            return false
        }
        let shown = await present(ad) { ad.present(from: nil) }
        if shown { Self.recordAppOpenShown() }
        slot.preload()
        return shown
    }

    @discardableResult
    func showInterstitial() async -> Bool {
        guard let slot = interstitialSlot else { return false }
        if let last = lastInterstitialDate, Date().timeIntervalSince(last) < configuration.interstitialCooldown {
            return false
        }
        guard canPresent, let ad = slot.take() else {
            slot.preload()
            return false
        }
        let shown = await present(ad) { ad.present(from: nil) }
        if shown { lastInterstitialDate = Date() }
        slot.preload()
        return shown
    }

    func showRewarded() async -> Bool {
        guard canPresent, let slot = rewardedSlot,
              let ad = await slot.take(waitingUpTo: .seconds(5)), canPresent else { return false }
        let reward = RewardFlag()
        let shown = await present(ad) { ad.present(from: nil) { reward.isEarned = true } }
        if shown && !reward.isEarned {
            try? await Task.sleep(for: .milliseconds(500))
        }
        slot.preload()
        return shown && reward.isEarned
    }

    private var canPresent: Bool {
        isStarted && !isPresentingFullScreenAd && UIApplication.shared.applicationState == .active
    }

    private func present(_ ad: FullScreenPresentingAd, show: () -> Void) async -> Bool {
        isPresentingFullScreenAd = true
        defer { isPresentingFullScreenAd = false }
        return await withCheckedContinuation { continuation in
            presenter.begin(ad, continuation: continuation)
            show()
        }
    }

    private func startSDKIfAllowed() async {
        guard !isStarted, ConsentInformation.shared.canRequestAds else { return }
        isStarted = true
        let requestConfiguration = MobileAds.shared.requestConfiguration
        if configuration.isChildDirected {
            requestConfiguration.tagForChildDirectedTreatment = NSNumber(value: true)
        }
        if let rating = configuration.maxAdContentRating {
            requestConfiguration.maxAdContentRating = rating
        }
        _ = await MobileAds.shared.start()
        interstitialSlot?.preload()
        rewardedSlot?.preload()
        appOpenSlot?.preload()
    }

    private static var isAnotherScreenPresented: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController?.presentedViewController != nil
    }

    private static let appOpenDayKey = "AdMobManager.appOpenDay"
    private static let appOpenCountKey = "AdMobManager.appOpenCount"

    private static var todayKey: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private static var appOpenShownToday: Int {
        let defaults = UserDefaults.standard
        return defaults.string(forKey: appOpenDayKey) == todayKey ? defaults.integer(forKey: appOpenCountKey) : 0
    }

    private static func recordAppOpenShown() {
        let defaults = UserDefaults.standard
        let count = appOpenShownToday + 1
        defaults.set(todayKey, forKey: appOpenDayKey)
        defaults.set(count, forKey: appOpenCountKey)
    }

    private func requestTrackingIfNeeded() async {
        guard !configuration.isChildDirected,
              !Self.didDeclineTrackingInConsentForm,
              ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        if UIApplication.shared.applicationState != .active {
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                break
            }
        }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    nonisolated static var didDeclineTrackingInConsentForm: Bool {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: "IABTCF_gdprApplies") == 1 else { return false }
        let purposes = Array(defaults.string(forKey: "IABTCF_PurposeConsents") ?? "")
        return ![1, 3, 4].allSatisfy { purposes.count >= $0 && purposes[$0 - 1] == "1" }
    }

    private static var consentParameters: RequestParameters {
        let parameters = RequestParameters()
        #if DEBUG
        if ProcessInfo.processInfo.environment["DEBUG_EEA"] != nil {
            let debugSettings = DebugSettings()
            debugSettings.geography = .EEA
            parameters.debugSettings = debugSettings
        }
        #endif
        return parameters
    }

    private static func unitID(_ production: String, test: String) -> String {
        #if DEBUG
        return test
        #else
        return production
        #endif
    }
}

@MainActor
private final class AdSlot<Ad> {
    private let load: () async throws -> Ad
    private let onReadyChange: (Bool) -> Void
    private var ad: Ad?
    private var loadedAt = Date.distantPast
    private var loadingTask: Task<Void, Never>?
    private let lifetime: TimeInterval = 55 * 60
    private let maxAttempts = 5

    init(load: @escaping () async throws -> Ad, onReadyChange: @escaping (Bool) -> Void = { _ in }) {
        self.load = load
        self.onReadyChange = onReadyChange
    }

    private var freshAd: Ad? {
        Date().timeIntervalSince(loadedAt) < lifetime ? ad : nil
    }

    func preload() {
        guard freshAd == nil, loadingTask == nil else { return }
        if ad != nil {
            ad = nil
            onReadyChange(false)
        }
        loadingTask = Task { [weak self] in
            await self?.loadWithRetry()
            self?.loadingTask = nil
        }
    }

    func take() -> Ad? {
        let result = freshAd
        ad = nil
        onReadyChange(false)
        return result
    }

    func take(waitingUpTo timeout: Duration) async -> Ad? {
        preload()
        let deadline = ContinuousClock.now + timeout
        while freshAd == nil, loadingTask != nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return take()
    }

    private func loadWithRetry() async {
        for attempt in 0..<maxAttempts {
            do {
                ad = try await load()
                loadedAt = Date()
                onReadyChange(true)
                return
            } catch {
                print("AdMob load error: \(error.localizedDescription)")
                guard attempt < maxAttempts - 1 else { return }
                try? await Task.sleep(for: .seconds(5 * pow(2, Double(attempt))))
            }
        }
    }
}

private final class RewardFlag {
    var isEarned = false
}

@MainActor
private final class FullScreenPresenter: NSObject, FullScreenContentDelegate {
    private var continuation: CheckedContinuation<Bool, Never>?

    func begin(_ ad: FullScreenPresentingAd, continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
        ad.fullScreenContentDelegate = self
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finish(true)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("AdMob present error: \(error.localizedDescription)")
        finish(false)
    }

    private func finish(_ shown: Bool) {
        continuation?.resume(returning: shown)
        continuation = nil
    }
}

struct AdBanner: View {
    @ObservedObject private var ads = AdMobManager.shared
    @StateObject private var model = BannerModel()

    var body: some View {
        SwiftUI.Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: model.isLoaded ? model.height : 0)
            .overlay(alignment: .top) {
                BannerHost(bannerView: model.bannerView)
                    .frame(height: model.height)
            }
            .clipped()
            .background {
                GeometryReader { proxy in
                    SwiftUI.Color.clear
                        .onAppear { model.update(width: proxy.size.width, unitID: ads.bannerUnitID, isStarted: ads.isStarted) }
                        .onChange(of: proxy.size.width) { model.update(width: $0, unitID: ads.bannerUnitID, isStarted: ads.isStarted) }
                        .onChange(of: ads.isStarted) { model.update(width: proxy.size.width, unitID: ads.bannerUnitID, isStarted: $0) }
                }
            }
            .animation(.easeOut(duration: 0.25), value: model.isLoaded)
    }
}

@MainActor
private final class BannerModel: NSObject, ObservableObject, BannerViewDelegate {
    @Published private(set) var isLoaded = false
    @Published private(set) var height: CGFloat = 0
    let bannerView = BannerView()
    private var retryTask: Task<Void, Never>?
    private var failureCount = 0
    private var needsReload = false

    override init() {
        super.init()
        bannerView.delegate = self
    }

    func update(width: CGFloat, unitID: String?, isStarted: Bool) {
        guard isStarted, width > 0, let unitID else { return }
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        if bannerView.adUnitID != nil, bannerView.adSize.size == adSize.size {
            guard needsReload, !isLoaded else { return }
            needsReload = false
            failureCount = 0
            bannerView.load(Request())
            return
        }
        bannerView.adUnitID = unitID
        bannerView.adSize = adSize
        height = adSize.size.height
        bannerView.load(Request())
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        failureCount = 0
        isLoaded = true
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        isLoaded = false
        guard failureCount < 5 else {
            needsReload = true
            return
        }
        let delay = 15 * pow(2, Double(failureCount))
        failureCount += 1
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            guard self.bannerView.window != nil else {
                self.needsReload = true
                return
            }
            self.bannerView.load(Request())
        }
    }
}

private struct BannerHost: UIViewRepresentable {
    let bannerView: BannerView

    func makeUIView(context: Context) -> BannerView { bannerView }
    func updateUIView(_ bannerView: BannerView, context: Context) {}
}

struct NativeAdStyle {
    var title: SwiftUI.Color = .primary
    var body: SwiftUI.Color = .secondary
    var callToActionBackground: SwiftUI.Color = .accentColor
    var callToActionText: SwiftUI.Color = .white
    var badgeBackground: SwiftUI.Color = .accentColor
    var badgeText: SwiftUI.Color = .white
    var badgeLabel = "Ad"
    var mediaHeight: CGFloat = 150
    var height: CGFloat = 300
}

struct AdNative<Container: View>: View {
    @ObservedObject private var ads = AdMobManager.shared
    @StateObject private var loader = NativeAdLoader()
    private let style: NativeAdStyle
    private let container: (AnyView) -> Container

    init(style: NativeAdStyle = NativeAdStyle(), @ViewBuilder container: @escaping (AnyView) -> Container) {
        self.style = style
        self.container = container
    }

    var body: some View {
        Group {
            if let ad = loader.nativeAd {
                container(AnyView(NativeAdHost(nativeAd: ad, style: style).frame(height: style.height)))
            }
        }
        .onAppear { loader.load(unitID: ads.nativeUnitID, isStarted: ads.isStarted) }
        .onChange(of: ads.isStarted) { loader.load(unitID: ads.nativeUnitID, isStarted: $0) }
    }
}

extension AdNative where Container == AnyView {
    init(style: NativeAdStyle = NativeAdStyle()) {
        self.init(style: style) { $0 }
    }
}

@MainActor
private final class NativeAdLoader: NSObject, ObservableObject, NativeAdLoaderDelegate {
    @Published private(set) var nativeAd: NativeAd?
    private var adLoader: AdLoader?
    private var unitID: String?
    private var loadedAt = Date.distantPast
    private var failureCount = 0

    func load(unitID: String?, isStarted: Bool) {
        guard isStarted, let unitID, adLoader == nil else { return }
        if nativeAd != nil, Date().timeIntervalSince(loadedAt) < 55 * 60 { return }
        self.unitID = unitID
        let loader = AdLoader(adUnitID: unitID, rootViewController: nil, adTypes: [.native], options: nil)
        loader.delegate = self
        adLoader = loader
        loader.load(Request())
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        self.nativeAd = nativeAd
        loadedAt = Date()
        failureCount = 0
        self.adLoader = nil
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("AdMob native load error: \(error.localizedDescription)")
        self.adLoader = nil
        guard failureCount < 3 else { return }
        let delay = 15 * pow(2, Double(failureCount))
        failureCount += 1
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self else { return }
            self.load(unitID: self.unitID, isStarted: true)
        }
    }
}

private struct NativeAdHost: UIViewRepresentable {
    let nativeAd: NativeAd
    let style: NativeAdStyle

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()

        let badge = NativeAdBadgeLabel()
        badge.text = style.badgeLabel
        badge.font = .systemFont(ofSize: 10, weight: .bold)
        badge.textColor = UIColor(style.badgeText)
        badge.backgroundColor = UIColor(style.badgeBackground)
        badge.layer.cornerRadius = 4
        badge.clipsToBounds = true
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let icon = UIImageView()
        icon.contentMode = .scaleAspectFill
        icon.layer.cornerRadius = 10
        icon.clipsToBounds = true

        let headline = UILabel()
        headline.font = .systemFont(ofSize: 15, weight: .semibold)
        headline.textColor = UIColor(style.title)
        headline.numberOfLines = 2

        let advertiser = UILabel()
        advertiser.font = .systemFont(ofSize: 12)
        advertiser.textColor = UIColor(style.body)

        let body = UILabel()
        body.font = .systemFont(ofSize: 13)
        body.textColor = UIColor(style.body)
        body.numberOfLines = 2

        let media = MediaView()
        media.contentMode = .scaleAspectFill
        media.layer.cornerRadius = 12
        media.clipsToBounds = true

        let cta = UIButton(type: .system)
        cta.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        cta.setTitleColor(UIColor(style.callToActionText), for: .normal)
        cta.backgroundColor = UIColor(style.callToActionBackground)
        cta.layer.cornerRadius = 12
        cta.isUserInteractionEnabled = false

        let titles = UIStackView(arrangedSubviews: [headline, advertiser])
        titles.axis = .vertical
        titles.spacing = 2
        let header = UIStackView(arrangedSubviews: [icon, titles])
        header.spacing = 10
        header.alignment = .center
        let badgeRow = UIStackView(arrangedSubviews: [badge, UIView()])
        let stack = UIStackView(arrangedSubviews: [badgeRow, header, body, media, cta])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(10, after: body)

        stack.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: adView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: adView.bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 40),
            icon.heightAnchor.constraint(equalToConstant: 40),
            media.heightAnchor.constraint(equalToConstant: style.mediaHeight),
            cta.heightAnchor.constraint(equalToConstant: 44)
        ])

        adView.iconView = icon
        adView.headlineView = headline
        adView.advertiserView = advertiser
        adView.bodyView = body
        adView.mediaView = media
        adView.callToActionView = cta
        return adView
    }

    func updateUIView(_ adView: NativeAdView, context: Context) {
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        adView.advertiserView?.isHidden = nativeAd.advertiser == nil
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        adView.bodyView?.isHidden = nativeAd.body == nil
        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        adView.iconView?.isHidden = nativeAd.icon == nil
        adView.mediaView?.mediaContent = nativeAd.mediaContent
        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        adView.callToActionView?.isHidden = nativeAd.callToAction == nil
        adView.nativeAd = nativeAd
    }
}

private final class NativeAdBadgeLabel: UILabel {
    private let insets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}
