import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Injected into Info.plist at build time from .env by
  /// ios/Scripts/inject_maps_api_key.sh, mirroring the manifestPlaceholders
  /// setup in android/app/build.gradle.kts.
  private func googleMapsApiKeyFromInfoPlist() -> String? {
    let key = (Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return (key?.isEmpty ?? true) ? nil : key
  }

  /// Fallback for builds where the injection script did not run. On iOS
  /// flutter_assets is packed inside App.framework, not at the root of the
  /// app bundle, so the path has to go through Frameworks/.
  private func googleMapsApiKeyFromEnv() -> String? {
    let envURL = Bundle.main.bundleURL
      .appendingPathComponent("Frameworks/App.framework/flutter_assets/.env")

    guard let contents = try? String(contentsOf: envURL, encoding: .utf8) else {
      return nil
    }

    return contents
      .split(whereSeparator: \.isNewline)
      .last { $0.trimmingCharacters(in: .whitespaces).hasPrefix("GOOGLE_MAPS_API_KEY=") }?
      .split(separator: "=", maxSplits: 1)
      .last
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = googleMapsApiKeyFromInfoPlist() ?? googleMapsApiKeyFromEnv(), !key.isEmpty {
      GMSServices.provideAPIKey(key)
    } else {
      // Failing silently here means the app hard crashes later, the first time
      // a GoogleMap widget is built, so make the cause obvious instead.
      NSLog(
        "[Ladolce] Google Maps API key missing — map screens will crash. "
          + "Check GOOGLE_MAPS_API_KEY in .env and ios/Scripts/inject_maps_api_key.sh."
      )
      assertionFailure("Google Maps API key missing")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
