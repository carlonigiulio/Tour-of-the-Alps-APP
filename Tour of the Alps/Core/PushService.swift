import Foundation
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

/// Firebase Cloud Messaging, driven entirely by **topics** — the app never sends its
/// device token anywhere, so the backend needs no device registry: it publishes to a
/// topic and Firebase fans it out.
///
/// Two topics are used:
/// - `all` — every install, for race-wide announcements.
/// - `lang_en` / `lang_it` / `lang_de` — so the server can send copy already written in
///   the reader's language, the same way every API response is localized.
@MainActor
final class PushService: NSObject {
    static let shared = PushService()

    /// Remembers which language topic we last joined, so a device that switches language
    /// leaves the old one instead of receiving every announcement twice.
    private static let lastLanguageTopicKey = "push.lastLanguageTopic"

    private(set) var fcmToken: String?

    /// Set by `RootView` once the interface exists. A tap that arrives before then is
    /// queued by the router itself, so a cold start still lands on the right screen.
    weak var router: AppRouter?

    static let globalTopic = "all"
    static func languageTopic(for language: Language) -> String { "lang_\(language.rawValue)" }

    func configure() {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    /// Asks for permission and, if granted, registers with APNs. Firebase only issues an
    /// FCM token once APNs has handed back a device token.
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Joins the global topic plus the one matching the device language, leaving a
    /// previously joined language topic if the language changed since last launch.
    func subscribeToTopics() async {
        let messaging = Messaging.messaging()
        let wanted = Self.languageTopic(for: .current)
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: Self.lastLanguageTopicKey)

        if let previous, previous != wanted {
            try? await messaging.unsubscribe(fromTopic: previous)
        }

        do {
            try await messaging.subscribe(toTopic: Self.globalTopic)
            try await messaging.subscribe(toTopic: wanted)
            defaults.set(wanted, forKey: Self.lastLanguageTopicKey)
        } catch {
            // Subscription is retried on the next launch; nothing user-facing to show.
            #if DEBUG
            print("[Push] subscribe failed: \(error.localizedDescription)")
            #endif
        }
    }
}

extension PushService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken token: String?) {
        Task { @MainActor in
            self.fcmToken = token
            #if DEBUG
            print("[Push] FCM token: \(token ?? "nil")")
            #endif
            // Topic subscriptions only stick once a token exists, so (re)apply them here
            // as well as at launch — this is what makes the very first run work.
            await self.subscribeToTopics()
        }
    }
}

/// These handlers are deliberately **not** `nonisolated`: they inherit `@MainActor` from
/// the class. UIKit invokes its completion once the async method returns, and does so on
/// whatever context the continuation resumed on — off the main thread that aborts with
/// "Call must be made on main thread".
extension PushService: UNUserNotificationCenterDelegate {
    /// Show banners even while the app is open — race news is time-sensitive.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    /// Tapping a notification routes to the content it points at, via the `link` value in
    /// the FCM data payload (`tota://post/22`). Notifications without a link just open
    /// the app, which is the correct behaviour for a general announcement.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let raw = (info["link"] ?? info["deep_link"] ?? info["url"]) as? String else { return }
        router?.handle(urlString: raw)
    }
}

/// UIKit app delegate, needed because APNs registration callbacks have no SwiftUI
/// equivalent. Attached via `@UIApplicationDelegateAdaptor`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MainActor.assumeIsolated { PushService.shared.configure() }
        return true
    }

    /// Hands the APNs token to Firebase. Without this the SDK cannot mint an FCM token,
    /// and topic subscriptions silently never take effect.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[Push] APNs registration failed: \(error.localizedDescription)")
        #endif
    }
}
