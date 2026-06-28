import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Add NVR'),
      ),
      body: devices.isEmpty
          ? const Center(child: Text('No NVRs. Tap “Add NVR”.'))
          : ListView(
              children: [
                for (final d in devices)
                  ListTile(
                    leading: const Icon(Icons.dvr),
                    title: Text(d.name),
                    subtitle: Text(d.host),
                    onTap: () => _edit(context, device: d),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          ref.read(devicesProvider.notifier).remove(d.id),
                    ),
                  ),
              ],
            ),
    );
  }
}
