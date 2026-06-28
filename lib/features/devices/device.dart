/// A discovered or manually-added NVR/camera, plus its channels.
library;

class CameraChannel {
  final int channel; // 1-based Dahua channel index
  final String name;
  final String? onvifToken; // ONVIF profile token, if discovered
  final String? mainStreamUri; // ONVIF GetStreamUri result (no creds)
  final String? subStreamUri;

  const CameraChannel({
    required this.channel,
    required this.name,
    this.onvifToken,
    this.mainStreamUri,
    this.subStreamUri,
  });

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'name': name,
        'onvifToken': onvifToken,
        'mainStreamUri': mainStreamUri,
        'subStreamUri': subStreamUri,
      };

  factory CameraChannel.fromJson(Map<String, dynamic> j) => CameraChannel(
        channel: j['channel'] as int,
        name: j['name'] as String,
        onvifToken: j['onvifToken'] as String?,
        mainStreamUri: j['mainStreamUri'] as String?,
        subStreamUri: j['subStreamUri'] as String?,
      );
}

class Device {
  final String id; // host as stable id
  final String name;
  final String host;
  final String user;
  final String pass;
  final int onvifPort;
  final List<CameraChannel> channels;

  /// Fallback channel count used to build channels by RTSP index when ONVIF
  /// returns none (Dahua ONVIF often disabled).
  final int? manualChannels;

  const Device({
    required this.id,
    required this.name,
    required this.host,
    required this.user,
    required this.pass,
    this.onvifPort = 80,
    this.channels = const [],
    this.manualChannels,
  });

  Device copyWith({
    String? name,
    List<CameraChannel>? channels,
    int? manualChannels,
  }) =>
      Device(
        id: id,
        name: name ?? this.name,
        host: host,
        user: user,
        pass: pass,
        onvifPort: onvifPort,
        channels: channels ?? this.channels,
        manualChannels: manualChannels ?? this.manualChannels,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'user': user,
        'pass': pass,
        'onvifPort': onvifPort,
        'channels': channels.map((c) => c.toJson()).toList(),
        'manualChannels': manualChannels,
      };

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        id: j['id'] as String,
        name: j['name'] as String,
        host: j['host'] as String,
        user: j['user'] as String,
        pass: j['pass'] as String,
        onvifPort: (j['onvifPort'] as int?) ?? 80,
        channels: ((j['channels'] as List?) ?? [])
            .map((e) => CameraChannel.fromJson(e as Map<String, dynamic>))
            .toList(),
        manualChannels: j['manualChannels'] as int?,
      );
}
