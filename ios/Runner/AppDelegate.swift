import Flutter
import CoreMotion
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var runStepCounter: RunStepCounter?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "RunStepCounter"
    ) else {
      return
    }
    runStepCounter = RunStepCounter(binaryMessenger: registrar.messenger())
  }
}

final class RunStepCounter {
  private let pedometer = CMPedometer()

  init(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "momentum.app/run_steps",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "queryAppStepCount":
      queryAppStepCount(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func queryAppStepCount(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard CMPedometer.isStepCountingAvailable() else {
      result(nil)
      return
    }

    guard
      let arguments = call.arguments as? [String: Any],
      let milliseconds = arguments["startTimeMillisecondsSinceEpoch"] as? NSNumber
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "startTimeMillisecondsSinceEpoch is required",
          details: nil
        )
      )
      return
    }

    let startDate = Date(
      timeIntervalSince1970: TimeInterval(milliseconds.int64Value) / 1000
    )
    pedometer.queryPedometerData(from: startDate, to: Date()) { data, error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "pedometer_error",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }

        result(data?.numberOfSteps.intValue)
      }
    }
  }
}
