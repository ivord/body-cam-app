import 'package:easy_onvif/onvif.dart';
import 'package:easy_onvif/probe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../features/devices/device.dart';

final onvifServiceProvider = Provider((_) => OnvifService());

/// Thin wrapper over easy_onvif: LAN discovery + channel/stream resolution.
/// Keeps all ONVIF SOAP details out of the rest of the app.
class OnvifService {
  /// WS-Discovery over UDP multicast. Returns reachable ONVIF hosts on the LAN.
  /// iOS needs the Multicast Networking entitlement for this; manual-IP add is
  /// the fallback when it returns nothing.
  Future<List<DiscoveredHost>> discover() async {
    final probe = MulticastProbe(
      timeout: AppConfig.discoveryTimeout.inSeconds,
    );
    await probe.probe();
    final seen = <String>{};
    final hosts = <DiscoveredHost>[];
    for (final m in probe.onvifDevices) {
      if (m.xAddrs.isEmpty) continue;
      final host = Uri.tryParse(m.xAddr)?.host;
      if (host == null || host.isEmpty || !seen.add(host)) continue;
      hosts.add(DiscoveredHost(
        host: host,
        name: m.name.isNotEmpty ? m.name : (m.hardware.isNotEmpty ? m.hardware : host),
      ));
    }
    return hosts;
  }

  /// Connect with creds and resolve channels. Each ONVIF media profile becomes
  /// a stream; profiles are grouped into channels by parsing Dahua profile
  /// names (e.g. "MediaProfile_Channel2_SubStream"). Falls back to nothing if
  /// grouping fails — caller then uses RtspUrlBuilder by channel index.
  Future<List<CameraChannel>> fetchChannels(Device d) async {
    final onvif = await Onvif.connect(
      host: '${d.host}:${d.onvifPort}',
      username: d.user,
      password: d.pass,
    );
    final profiles = await onvif.media.getProfiles();

    final byChannel = <int, _ChannelBuild>{};
    for (final p in profiles) {
      final ch = _channelFromName(p.name) ?? 1;
      final isSub = _isSubStream(p.name);
      String? uri;
      try {
        uri = await onvif.media.getStreamUri(p.token);
      } catch (_) {
        uri = null; // some firmware refuses GetStreamUri; URL builder covers it
      }
      final b = byChannel.putIfAbsent(ch, () => _ChannelBuild(ch));
      if (isSub) {
        b.subToken ??= p.token;
        b.subUri ??= uri;
      } else {
        b.mainToken ??= p.token;
        b.mainUri ??= uri;
        b.name ??= p.name;
      }
    }

    final channels = byChannel.values.map((b) => b.toChannel()).toList()
      ..sort((a, b) => a.channel.compareTo(b.channel));
    return channels;
  }

  static int? _channelFromName(String name) {
    final m = RegExp(r'[Cc]hannel[_ ]?(\d+)').firstMatch(name);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  static bool _isSubStream(String name) {
    final n = name.toLowerCase();
    return n.contains('sub') || n.contains('subtype1') || n.contains('_2');
  }
}

class DiscoveredHost {
  final String host;
  final String name;
  const DiscoveredHost({required this.host, required this.name});
}

class _ChannelBuild {
  _ChannelBuild(this.channel);
  final int channel;
  String? name;
  String? mainToken;
  String? subToken;
  String? mainUri;
  String? subUri;

  CameraChannel toChannel() => CameraChannel(
        channel: channel,
        name: name ?? 'Channel $channel',
        onvifToken: subToken ?? mainToken,
        mainStreamUri: mainUri,
        subStreamUri: subUri,
      );
}
