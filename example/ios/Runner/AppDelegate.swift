import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The key comes from ios/Flutter/Secrets.xcconfig, which git ignores.
    // Without a key the Maps SDK throws when the map is created, so a
    // placeholder is used: the map then shows no tiles but the app still runs.
    let configured = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
    let key = configured.isEmpty || configured.hasPrefix("$(") ? "MISSING_API_KEY" : configured
    GMSServices.provideAPIKey(key)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
