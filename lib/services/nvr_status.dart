import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../features/devices/device_repository.dart';

/// True if a TCP connection to host:port succeeds within [timeout].
Future<bool> isNvrOnline(String host, int port, Duration timeout) async {
  try {
    final s = await Socket.connect(host, port, timeout: timeout);
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

/// Per-NVR reachability, keyed by device id (stable — Device has no `==`, so
/// keying by the object would re-run every rebuild and leak providers).
/// autoDispose so it re-checks fresh each time Home is reopened.
final nvrStatusProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final d = ref.watch(devicesProvider).firstWhere((e) => e.id == id);
  return isNvrOnline(d.host, AppConfig.rtspPort, AppConfig.statusTimeout);
});
