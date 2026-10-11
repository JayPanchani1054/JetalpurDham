import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps key for the Prasadi places map. Set GOOGLE_MAPS_API_KEY in
    // ios/Flutter/Secrets.xcconfig (see docs/FIREBASE_SETUP.md). The SDK must
    // always be initialised: without a key it would crash when the map opens,
    // with a placeholder it only shows an empty map.
    let configuredKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String
    let mapsKey = (configuredKey?.isEmpty == false && configuredKey?.hasPrefix("$(") == false)
      ? configuredKey!
      : "MISSING_GOOGLE_MAPS_API_KEY"
    GMSServices.provideAPIKey(mapsKey)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
