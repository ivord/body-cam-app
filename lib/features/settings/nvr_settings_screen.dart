import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../devices/device.dart';
import '../devices/device_repository.dart';
import 'nvr_edit_screen.dart';

/// Manage stored NVRs: add / edit / delete.
class NvrSettingsScreen extends ConsumerWidget {
  const NvrSettingsScreen({super.key});

  void _edit(BuildContext context, {Device? device}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NvrEditScreen(device: device)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('NVR Settings')),
      body: Column(
        children: [
          Expanded(
            child: devices.isEmpty
                ? Center(
                    child: Text('No NVRs. Tap “Add NVR”.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                        child: Text('STORED NVRs',
                            style: monoText(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.6,
                              color: AppColors.textTertiary,
                            )),
                      ),
                      for (final d in devices) ...[
                        _row(context, ref, d),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: TealButton(
              icon: Icons.add,
              label: 'Add NVR',
              onPressed: () => _edit(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Device d) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _edit(context, device: d),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        border: Border.all(color: AppColors.borderStrong),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.dvr, color: AppColors.teal, size: 20),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(d.host, style: monoText(fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => ref.read(devicesProvider.notifier).remove(d.id),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF180F12),
                  border: Border.all(color: const Color(0xFF2A1D22)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline,
                    color: AppColors.deleteRed, size: 18),
              ),
            ),
          ],
        ),
      );
}
