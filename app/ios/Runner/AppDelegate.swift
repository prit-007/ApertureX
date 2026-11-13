import CoreVideo
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

  /// Zero-copy preview textures on iOS (spike B). Mirrors the Android
  /// `MainActivity` contract: `create` → CVPixelBuffer + Flutter texture id,
  /// `bind` → pass pixel buffer base address to Rust `bind_window`,
  /// `dispose` → release.
  private static var previewTextures: [Int64: CVPixelBuffer] = [:]
  private static let previewLock = NSLock()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerRoiChannel(pluginRegistry: engineBridge.pluginRegistry)
    registerPreviewTextureChannel(pluginRegistry: engineBridge.pluginRegistry)
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

  /// Registers `aperturex/preview_texture` — the iOS half of spike B's
  /// zero-copy texture delivery. Matches the Android `MainActivity` contract:
  /// `create {width,height}` → texture id; `bind {textureId,handle}` → bind
  /// CVPixelBuffer base address to Rust preview handle;
  /// `frameAvailable {textureId}` → tell the engine a fresh frame was written;
  /// `dispose {textureId}` → release.
  private func registerPreviewTextureChannel(pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "aperturex.preview_texture") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "aperturex/preview_texture",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "create":
        self.handlePreviewTextureCreate(call: call, result: result, registrar: registrar)
      case "bind":
        self.handlePreviewTextureBind(call: call, result: result)
      case "frameAvailable":
        self.handlePreviewTextureFrameAvailable(call: call, result: result, registrar: registrar)
      case "dispose":
        self.handlePreviewTextureDispose(call: call, result: result, registrar: registrar)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handlePreviewTextureCreate(
    call: FlutterMethodCall,
    result: FlutterResult,
    registrar: FlutterPluginRegistrar
  ) {
    guard
      let args = call.arguments as? [String: Any],
      let width = args["width"] as? Int32,
      let height = args["height"] as? Int32,
      width > 0, height > 0
    else {
      result(FlutterError(code: "bad_args", message: "invalid width/height", details: nil))
      return
    }

    var pixelBuffer: CVPixelBuffer?
    // Rust's iOS write path copies tight rows (row_bytes = width * 4) into
    // the base address. Ask CoreVideo for an exactly packed buffer; the bind
    // handler verifies the result, so a padded buffer refuses the bind and
    // Dart keeps the return-frame + shader path instead of shearing frames.
    let attrs: [String: Any] = [
      kCVPixelBufferBytesPerRowAlignmentKey as String: Int(width) * 4,
    ]
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault, Int(width), Int(height),
      kCVPixelFormatType_32RGBA, attrs as CFDictionary, &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pb = pixelBuffer else {
      result(
        FlutterError(code: "alloc_failed", message: "CVPixelBufferCreate failed: \(status)", details: nil)
      )
      return
    }

    // Register as a Flutter texture so the Texture widget can display it.
    // The registry assigns the texture id (it must match what the engine
    // tracks — not a local counter). Rust writes RGBA directly into the
    // pixel buffer memory via `aperturex_bind_window`, so `copyPixelBuffer`
    // always returns the latest content without any Dart↔Rust roundtrip.
    let texture = PreviewTexture(pixelBuffer: pb)
    let textureId = registrar.textures().register(texture)

    AppDelegate.previewLock.lock()
    AppDelegate.previewTextures[textureId] = pb
    AppDelegate.previewLock.unlock()

    result(textureId)
  }

  private func handlePreviewTextureBind(call: FlutterMethodCall, result: FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let textureId = args["textureId"] as? Int64,
      let handle = args["handle"] as? Int64
    else {
      result(FlutterError(code: "bad_args", message: "invalid textureId/handle", details: nil))
      return
    }

    AppDelegate.previewLock.lock()
    guard let pixelBuffer = AppDelegate.previewTextures[textureId] else {
      AppDelegate.previewLock.unlock()
      result(
        FlutterError(code: "not_found", message: "texture \(textureId) not found", details: nil)
      )
      return
    }
    AppDelegate.previewLock.unlock()

    // Rust writes tight rows; a padded bytesPerRow would shear every frame,
    // so refuse the bind and let Dart keep the shader path (graceful
    // degradation, never a stretched preview).
    let pbWidth = CVPixelBufferGetWidth(pixelBuffer)
    let pbStride = CVPixelBufferGetBytesPerRow(pixelBuffer)
    guard pbStride == pbWidth * 4 else {
      result(
        FlutterError(
          code: "padded_buffer",
          message: "bytesPerRow \(pbStride) != width*4 (\(pbWidth * 4))",
          details: nil
        )
      )
      return
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

    guard let base = baseAddress else {
      result(
        FlutterError(code: "no_base_address", message: "pixel buffer has no base address", details: nil)
      )
      return
    }

    let ok = aperturex_bind_window(UInt64(bitPattern: handle), Int64(UInt(bitPattern: base)))
    result(ok)
  }

  /// Notifies the engine that [textureId]'s CVPixelBuffer holds a fresh
  /// frame. Rust writes into the raw base address, which the engine cannot
  /// observe — it only re-samples `copyPixelBuffer` after this registry poke
  /// (Android's SurfaceProducer watches its own buffer queue instead).
  private func handlePreviewTextureFrameAvailable(
    call: FlutterMethodCall,
    result: FlutterResult,
    registrar: FlutterPluginRegistrar
  ) {
    guard
      let args = call.arguments as? [String: Any],
      let textureId = args["textureId"] as? Int64
    else {
      result(FlutterError(code: "bad_args", message: "invalid textureId", details: nil))
      return
    }

    registrar.textures().textureFrameAvailable(textureId)
    result(nil)
  }

  private func handlePreviewTextureDispose(
    call: FlutterMethodCall,
    result: FlutterResult,
    registrar: FlutterPluginRegistrar
  ) {
    guard
      let args = call.arguments as? [String: Any],
      let textureId = args["textureId"] as? Int64
    else {
      result(FlutterError(code: "bad_args", message: "invalid textureId", details: nil))
      return
    }

    registrar.textures().unregisterTexture(textureId)
    AppDelegate.previewLock.lock()
    AppDelegate.previewTextures.removeValue(forKey: textureId)
    AppDelegate.previewLock.unlock()

    result(nil)
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

/// FlutterTexture wrapper that holds a CVPixelBuffer and returns it on each
/// frame request. Rust writes RGBA directly into the pixel buffer memory via
/// `aperturex_bind_window`, so `copyPixelBuffer` always returns the latest
/// content without any Dart↔Rust roundtrip.
private class PreviewTexture: NSObject, FlutterTexture {
  let pixelBuffer: CVPixelBuffer

  init(pixelBuffer: CVPixelBuffer) {
    self.pixelBuffer = pixelBuffer
  }

  // Swift imports `- (CVPixelBufferRef)copyPixelBuffer` as Unmanaged; the
  // engine takes ownership (+1) and releases when it swaps buffers, so this
  // must be passRetained (the same buffer is returned every call).
  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    return Unmanaged.passRetained(pixelBuffer)
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
