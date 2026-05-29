import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private func googleMapsApiKeyFromEnv() -> String? {
    guard let path = Bundle.main.path(
      forResource: ".env",
      ofType: nil,
      inDirectory: "flutter_assets"
    ),
      let contents = try? String(contentsOfFile: path)
    else {
      return nil
    }

    return contents
      .split(separator: "\n")
      .last { $0.trimmingCharacters(in: .whitespaces).hasPrefix("GOOGLE_MAPS_API_KEY=") }?
      .split(separator: "=", maxSplits: 1)
      .last
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = googleMapsApiKeyFromEnv(), !key.isEmpty {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
