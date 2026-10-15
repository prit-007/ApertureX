import Flutter
import ImageIO
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Region decodes (#16) run off the main thread; a single serial queue
  /// bounds peak memory to one in-flight band and keeps decode latency off
  /// the UI thread.
  private static let roiQueue = DispatchQueue(
    label: "aperturex.roi_decode", qos: .userInitiated)

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerRoiChannel(pluginRegistry: engineBridge.pluginRegistry)
  }

  /// Registers `aperturex/roi_decode` with a CGImageSource-backed `decodeBand`
  /// — the iOS half of #16's native region decoders. The contract matches
  /// `MainActivity.kt` (Android): `decodeBand {jpeg,x,y,width,height}` →
  /// `{width,height,rgba}`; every failure is a `FlutterError` so Dart falls
  /// back to the in-process Rust decoder exactly as on Android.
  private func registerRoiChannel(pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "aperturex.roi_decode") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "aperturex/roi_decode",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "decodeBand" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let jpeg = args["jpeg"] as? FlutterStandardTypedData,
        let x = args["x"] as? Int,
        let y = args["y"] as? Int,
        let width = args["width"] as? Int,
        let height = args["height"] as? Int,
        x >= 0, y >= 0, width > 0, height > 0
      else {
        result(FlutterError(code: "bad_args", message: "invalid band arguments", details: nil))
        return
      }
      AppDelegate.roiQueue.async {
        do {
          let band = try AppDelegate.regionDecode(
            data: jpeg.data, x: x, y: y, width: width, height: height)
          DispatchQueue.main.async {
            result([
              "width": band.width,
              "height": band.height,
              "rgba": FlutterStandardTypedData(bytes: band.rgba),
            ])
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "decode_failed", message: "\(error)", details: nil))
          }
        }
      }
    }
  }

  /// Decodes the region `(x, y, width, height)` — top-left origin, tightly
  /// packed RGBA8 — without materialising the full frame.
  ///
  /// ImageIO inflates JPEG MCUs lazily: a `CGImageSourceCreateImageAtIndex`
  /// proxy with `kCGImageSourceShouldCacheImmediately: false` only decodes the
  /// tiles the crop + draw actually touches, so peak memory stays band-sized
  /// even for a >100 MP source. The crop rect is in image space (origin
  /// upper-left, per `CGImage.cropping(to:)`), and no thumbnail transform is
  /// applied: ROI bands are the raw stored pixel grid — EXIF rotation is a
  /// geometry edit the viewport owns. The draw flips the context's default
  /// bottom-up CTM so buffer row 0 is the top row, matching Android's
  /// `BitmapRegionDecoder` byte-for-byte (a flip here would put a hard seam
  /// between the proxy and the overlay).
  private static func regionDecode(
    data: Data, x: Int, y: Int, width: Int, height: Int
  ) throws -> (width: Int, height: Int, rgba: Data) {
    let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary)
    else {
      throw RoiDecodeError.badSource
    }
    guard
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let fullW = properties[kCGImagePropertyPixelWidth] as? Int,
      let fullH = properties[kCGImagePropertyPixelHeight] as? Int
    else {
      throw RoiDecodeError.badProperties
    }
    guard x + width <= fullW, y + height <= fullH else {
      throw RoiDecodeError.outOfBounds
    }

    let imageOptions: [CFString: Any] = [kCGImageSourceShouldCacheImmediately: false]
    guard let image = CGImageSourceCreateImageAtIndex(source, 0, imageOptions as CFDictionary)
    else {
      throw RoiDecodeError.decodeFailed
    }
    let rect = CGRect(x: x, y: y, width: width, height: height)
    guard let crop = image.cropping(to: rect) else {
      throw RoiDecodeError.cropFailed
    }

    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    guard
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
        data: &rgba,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        // premultipliedLast + byteOrder32Big = R,G,B,A in memory — the same
        // layout Android's ARGB_8888 copyPixelsToBuffer produces.
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      )
    else {
      throw RoiDecodeError.noContext
    }
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.draw(crop, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    return (width, height, Data(rgba))
  }
}

private enum RoiDecodeError: Error {
  case badSource
  case badProperties
  case outOfBounds
  case decodeFailed
  case cropFailed
  case noContext
}
