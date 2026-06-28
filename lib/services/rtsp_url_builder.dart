/// Builds Dahua RTSP URLs. Dahua NVR/IPC pattern:
///   rtsp://user:pass@host:554/cam/realmonitor?channel=N&subtype=S
/// subtype 0 = main stream (HD, high bitrate), 1 = substream (low bitrate).
/// Prefer ONVIF GetStreamUri when available; this is the fallback / default.
library;

class RtspUrlBuilder {
  static String build({
    required String host,
    required String user,
    required String pass,
    int channel = 1,
    bool mainStream = false,
    int port = 554,
  }) {
    final cred = (user.isEmpty && pass.isEmpty)
        ? ''
        : '${Uri.encodeComponent(user)}:${Uri.encodeComponent(pass)}@';
    final subtype = mainStream ? 0 : 1;
    return 'rtsp://$cred$host:$port/cam/realmonitor?channel=$channel&subtype=$subtype';
  }

  /// Injects credentials into a URL returned by ONVIF GetStreamUri (which is
  /// usually credential-less). Returns the url unchanged if it already has auth.
  static String withCreds(String url, String user, String pass) {
    if (user.isEmpty && pass.isEmpty) return url;
    final uri = Uri.parse(url);
    if (uri.userInfo.isNotEmpty) return url;
    return uri
        .replace(
          userInfo:
              '${Uri.encodeComponent(user)}:${Uri.encodeComponent(pass)}',
        )
        .toString();
  }
}
