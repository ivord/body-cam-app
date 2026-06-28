import AVFoundation
import Flutter

/// iOS two-way-audio backchannel.
///
/// ponytail: stub. The Android path (Backchannel.kt) is the reference impl and
/// is verified first against the real NVR. Porting to iOS is the same shape:
///   AVAudioEngine + kAudioUnitSubType_VoiceProcessingIO (gives AEC+NS) ->
///   PCM16 8kHz -> G.711 u-law -> RTP -> RTSP interleaved TCP backchannel.
/// Until ported, `start` reports UNSUPPORTED so the UI shows a clear message
/// rather than failing silently.
class Backchannel: NSObject {
    init(messenger: FlutterBinaryMessenger) {
        super.init()
        let channel = FlutterMethodChannel(name: "nvr/backchannel", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "start":
                result(FlutterError(code: "UNSUPPORTED",
                                    message: "iOS two-way audio not yet implemented",
                                    details: nil))
            case "stop", "setMuted":
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
