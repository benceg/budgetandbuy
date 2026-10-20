import CloudKit
import SwiftUI
import UIKit

/// SwiftUI has no hook for accepting iCloud share invitations, so the app
/// installs a scene delegate to receive them.
final class AppDelegate: NSObject, UIApplicationDelegate {
    // Runs on background launches too, so an arrival that woke the app is delivered.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { await StoreArrivalMonitor.shared.refresh() }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    // Tapping an invitation while the app isn't running.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            PersistenceController.shared.acceptShare(metadata)
        }
    }

    // Tapping an invitation while the app is running.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        PersistenceController.shared.acceptShare(metadata)
    }
}

extension EnvironmentValues {
    @Entry var persistence: PersistenceController? = nil
}

extension UIApplication {
    /// The view controller to present UIKit sheets from, above any SwiftUI sheet.
    var topViewController: UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
