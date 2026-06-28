/// App-wide defaults. Tuned for low-bandwidth factory LAN use.
library;

class AppConfig {
  /// Default to substream (low bitrate) to save bandwidth. Main stream only on
  /// explicit "HD" tap.
  static const bool defaultMainStream = false;

  /// RTSP over TCP is more reliable on congested factory wifi than UDP.
  /// Toggleable per-stream if lower latency is needed.
  static const bool rtspOverTcp = true;

  static const int rtspPort = 554;
  static const int onvifPort = 80;

  static const Duration discoveryTimeout = Duration(seconds: 4);
  static const Duration connectTimeout = Duration(seconds: 8);
}
