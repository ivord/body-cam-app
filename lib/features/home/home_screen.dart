import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/onvif_service.dart';
import '../devices/device.dart';
import '../devices/device_repository.dart';
import '../live/live_screen.dart';
import '../settings/nvr_settings_screen.dart';

/// Home: pick a stored NVR and start live. NVR config lives in NVR Settings.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedId;
  bool _revealPass = false;
  bool _busy = false;
  String _phoneIp = '…';

  @override
  void initState() {
    super.initState();
    _loadPhoneIp();
    _restoreSelection();
  }

  Future<void> _loadPhoneIp() async {
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final ip = ifaces.expand((i) => i.addresses).firstOrNull?.address;
      if (mounted) setState(() => _phoneIp = ip ?? 'unknown');
    } catch (_) {
      if (mounted) setState(() => _phoneIp = 'unknown');
    }
  }

  Future<void> _restoreSelection() async {
    final last = await ref.read(deviceRepoProvider).loadLastViewed();
    if (last != null && mounted) setState(() => _selectedId = last.deviceId);
  }

  Device? _selected(List<Device> devices) {
    if (devices.isEmpty) return null;
    return devices.firstWhere(
      (d) => d.id == _selectedId,
      orElse: () => devices.first,
    );
  }

  Future<void> _startLive(Device device) async {
    setState(() => _busy = true);
    var channels = device.channels;
    try {
      final resolved =
          await ref.read(onvifServiceProvider).fetchChannels(device);
      if (resolved.isNotEmpty) {
        channels = resolved;
      } else if ((device.manualChannels ?? 0) > 1) {
        channels = [
          for (var i = 1; i <= device.manualChannels!; i++)
            CameraChannel(channel: i, name: 'Channel $i'),
        ];
      }
    } catch (_) {
      if (channels.isEmpty && (device.manualChannels ?? 0) > 1) {
        channels = [
          for (var i = 1; i <= device.manualChannels!; i++)
            CameraChannel(channel: i, name: 'Channel $i'),
        ];
      }
    }
    if (channels.isNotEmpty) {
      await ref
          .read(devicesProvider.notifier)
          .upsert(device.copyWith(channels: channels));
    }

    final last = await ref.read(deviceRepoProvider).loadLastViewed();
    final channel = (last != null &&
            last.deviceId == device.id &&
            channels.any((c) => c.channel == last.channel))
        ? last.channel
        : (channels.isNotEmpty ? channels.first.channel : 1);

    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveScreen(deviceId: device.id, channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    final selected = _selected(devices);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NVR Viewer'),
        actions: [
          IconButton(
            tooltip: 'NVR Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NvrSettingsScreen()),
            ),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _info('This phone', _phoneIp),
            const Divider(height: 32),
            if (devices.isEmpty)
              _emptyState(context)
            else ...[
              DropdownButtonFormField<String>(
                initialValue: selected?.id,
                decoration: const InputDecoration(
                  labelText: 'NVR',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final d in devices)
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
                onChanged: (v) => setState(() => _selectedId = v),
              ),
              const SizedBox(height: 16),
              if (selected != null) ...[
                _info('Host / IP', selected.host),
                _info('Username', selected.user),
                _passwordRow(selected.pass),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _startLive(selected),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Start live'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Column(
        children: [
          const Text('No NVR yet. Add one in settings.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NvrSettingsScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add NVR'),
          ),
        ],
      );

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 96, child: Text('$label :')),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _passwordRow(String pass) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const SizedBox(width: 96, child: Text('Password :')),
            Expanded(
              child: Text(
                _revealPass ? pass : '•' * (pass.isEmpty ? 0 : 8),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: Icon(_revealPass ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _revealPass = !_revealPass),
            ),
          ],
        ),
      );
}
