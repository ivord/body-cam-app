import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'device.dart';

/// Persists devices (incl. credentials) in encrypted secure storage. LAN-only
/// app — nothing leaves the device.
class DeviceRepository {
  static const _key = 'devices_v1';
  static const _lastViewedKey = 'last_viewed_v1';
  final _store = const FlutterSecureStorage();

  Future<List<Device>> load() async {
    final raw = await _store.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> save(List<Device> devices) async {
    await _store.write(
      key: _key,
      value: jsonEncode(devices.map((d) => d.toJson()).toList()),
    );
  }

  /// Remembers the last camera the user watched so the next launch can jump
  /// straight back to it. Stores only "deviceId|channel" — no video.
  Future<void> saveLastViewed(String deviceId, int channel) =>
      _store.write(key: _lastViewedKey, value: '$deviceId|$channel');

  Future<({String deviceId, int channel})?> loadLastViewed() async =>
      parseLastViewed(await _store.read(key: _lastViewedKey));

  /// Pure parser for the "deviceId|channel" marker (host ids never contain '|').
  static ({String deviceId, int channel})? parseLastViewed(String? raw) {
    if (raw == null) return null;
    final i = raw.lastIndexOf('|');
    if (i <= 0) return null;
    final channel = int.tryParse(raw.substring(i + 1));
    if (channel == null) return null;
    return (deviceId: raw.substring(0, i), channel: channel);
  }
}

/// Device list state. Single source of truth for the UI.
class DevicesNotifier extends Notifier<List<Device>> {
  late final DeviceRepository _repo = ref.read(deviceRepoProvider);

  @override
  List<Device> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    state = await _repo.load();
    ref.read(devicesLoadedProvider.notifier).state = true;
  }

  Future<void> upsert(Device d) async {
    state = [
      ...state.where((e) => e.id != d.id),
      d,
    ];
    await _repo.save(state);
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _repo.save(state);
  }
}

final deviceRepoProvider = Provider((_) => DeviceRepository());

final devicesProvider =
    NotifierProvider<DevicesNotifier, List<Device>>(DevicesNotifier.new);

/// Flips to true once the initial secure-storage read resolves, so the UI
/// can tell "no devices saved" apart from "still loading".
final devicesLoadedProvider = StateProvider<bool>((_) => false);
