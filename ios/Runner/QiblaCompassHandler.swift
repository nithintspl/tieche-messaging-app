import CoreLocation
import Flutter

final class QiblaCompassHandler: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  static let channelName = "com.tieche.messaging/qibla_compass"
  private static var retainedInstance: QiblaCompassHandler?

  private var eventSink: FlutterEventSink?
  private let locationManager = CLLocationManager()

  static func register(with messenger: FlutterBinaryMessenger) {
    let instance = QiblaCompassHandler()
    retainedInstance = instance

    let eventChannel = FlutterEventChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(instance)

    let methodChannel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "hasCompassSensor":
        result(CLLocationManager.headingAvailable())
      case "setLocation":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    instance.locationManager.delegate = instance
    instance.locationManager.headingFilter = 1.0
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    guard CLLocationManager.headingAvailable() else {
      return FlutterError(
        code: "NO_SENSOR",
        message: "No compass sensor available on this device",
        details: nil
      )
    }
    locationManager.requestWhenInUseAuthorization()
    locationManager.startUpdatingHeading()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    locationManager.stopUpdatingHeading()
    eventSink = nil
    return nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    guard let sink = eventSink else { return }

    let usesTrueNorth = newHeading.trueHeading >= 0
    let heading = usesTrueNorth ? newHeading.trueHeading : newHeading.magneticHeading
    let accuracy = newHeading.headingAccuracy

    DispatchQueue.main.async {
      sink([
        "heading": heading,
        "accuracy": accuracy,
        "isTrueNorth": usesTrueNorth,
      ])
    }
  }

  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
    false
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(FlutterError(
        code: "HEADING_ERROR",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }
}