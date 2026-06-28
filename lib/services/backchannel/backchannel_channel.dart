import 'package:flutter/services.dart';

/// Dart side of the native two-way-audio (ONVIF backchannel) module.
///
/// The talk path is native because it couples mic capture, OS acoustic echo
/// cancellation / noise suppression, G.711 encoding and RTP send to the camera
/// over an ONVIF Profile-T backchannel RTSP session — none of which a Flutter
/// package provides. See android/.../Backchannel.kt and ios/.../Backchannel.swift.
class BackchannelChannel {
  static const _ch = MethodChannel('nvr/backchannel');

  /// Open the backchannel and start sending mic audio to the camera.
  /// Throws PlatformException 'UNSUPPORTED' if the NVR firmware has no
  /// backchannel (caught by the UI to show a clear message).
  static Future<void> start({
    required String host,
    required int onvifPort,
    required String user,
    required String pass,
    String? profileToken,
    bool aec = true,
    bool ns = true,
  }) {
    return _ch.invokeMethod('start', {
      'host': host,
      'onvifPort': onvifPort,
      'user': user,
      'pass': pass,
      'profileToken': profileToken,
      'aec': aec,
      'ns': ns,
    });
  }

  static Future<void> stop() => _ch.invokeMethod('stop');

  static Future<void> setMuted(bool muted) =>
      _ch.invokeMethod('setMuted', {'muted': muted});

  /// Outgoing mic level 0..1 for a level meter.
  static const _level = EventChannel('nvr/backchannel/level');
  static Stream<double> micLevel() =>
      _level.receiveBroadcastStream().map((e) => (e as num).toDouble());
}
