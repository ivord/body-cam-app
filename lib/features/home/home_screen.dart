import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/nvr_status.dart';
import '../../services/onvif_service.dart';
import '../devices/device.dart';
import '../devices/device_repository.dart';
import '../live/live_screen.dart';
import '../settings/nvr_settings_screen.dart';

/// Home: list stored NVRs, tap one to start live. NVR config lives in NVR
/// Settings.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _busyId;
  String _phoneIp = '…';

  @override
  void initState() {
    super.initState();
    _loadPhoneIp();
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

  Future<void> _startLive(Device device) async {
    setState(() => _busyId = device.id);
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
    setState(() => _busyId = null);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveScreen(deviceId: device.id, channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    final loaded = ref.watch(devicesLoadedProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2DD4BF), Color(0xFF0E8478)],
                ),
              ),
              child: const Icon(Icons.security, size: 16, color: Color(0xFF04201D)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LGS - Body Camera',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('LOCAL SURVEILLANCE',
                      style: monoText(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.4,
                        color: AppColors.textTertiary,
                      )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'NVR Settings',
            icon: const Icon(Icons.settings),
            color: AppColors.textSecondary,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NvrSettingsScreen()),
            ),
          ),
        ],
      ),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(nvrStatusProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _phoneCard(),
                  const SizedBox(height: 18),
                  _sectionHeader(devices.length),
                  const SizedBox(height: 10),
                  if (devices.isEmpty)
                    _emptyState(context)
                  else
                    for (final d in devices) ...[
                      _deviceCard(d),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 8),
                  _footer(),
                ],
              ),
            ),
    );
  }

  Widget _phoneCard() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                border: Border.all(color: AppColors.borderStrong),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.wifi, color: AppColors.teal, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('THIS DEVICE · LAN',
                      style: monoText(
                        fontSize: 10,
                        letterSpacing: 1.4,
                        color: AppColors.textTertiary,
                      )),
                  const SizedBox(height: 2),
                  Text(_phoneIp,
                      style: monoText(
                        fontSize: 21,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        letterSpacing: .3,
                      )),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: .12),
                border: Border.all(color: AppColors.green.withValues(alpha: .28)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const StatusDot(color: AppColors.green, label: 'ONLINE'),
            ),
          ],
        ),
      );

  Widget _sectionHeader(int count) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('NVR DEVICES',
                style: monoText(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: AppColors.textTertiary,
                )),
            Text(count == 1 ? '1 DEVICE' : '$count DEVICES',
                style: monoText(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _deviceCard(Device d) {
    final busy = _busyId == d.id;
    final status = ref.watch(nvrStatusProvider(d.id));
    final online = status.value ?? false;
    // Offline (or still checking) NVR can't be opened — RTSP pull would just
    // hang. Tap enabled only once the status check confirms it's reachable.
    final tappable = online && _busyId == null;
    return Opacity(
      opacity: online ? 1 : .55,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: tappable ? () => _startLive(d) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                border: Border.all(color: AppColors.borderStrong),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.dvr, color: AppColors.teal, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(d.host, style: monoText(fontSize: 12.5)),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                            color: AppColors.borderStrong, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        d.channels.length > 1
                            ? '${d.channels.length} cameras'
                            : '1 camera',
                        style: monoText(fontSize: 12.5, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppColors.teal),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  status.when(
                    loading: () => const StatusDot(
                        color: AppColors.textTertiary, label: 'Checking…'),
                    error: (_, _) => const StatusDot(
                        color: AppColors.deleteRed, label: 'Offline'),
                    data: (online) => StatusDot(
                      color: online ? AppColors.green : AppColors.deleteRed,
                      label: online ? 'Online' : 'Offline',
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textTertiary, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.borderStrong, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            const Icon(Icons.dvr_outlined, color: AppColors.borderStrong, size: 38),
            const SizedBox(height: 14),
            Text('No NVR yet. Add one to start.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            TealButton(
              icon: Icons.add,
              label: 'Add NVR',
              expand: false,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NvrSettingsScreen()),
              ),
            ),
          ],
        ),
      );

  Widget _footer() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 13, color: Color(0xFF3F4B59)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'LOCAL NETWORK ONLY · NO CLOUD · NO RECORDINGS',
              style: monoText(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF3F4B59),
                letterSpacing: .5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
}
