import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/onvif_service.dart';
import '../devices/device.dart';
import '../devices/device_repository.dart';

/// Add or edit one NVR. `device == null` → add; otherwise edit (prefilled).
class NvrEditScreen extends ConsumerStatefulWidget {
  const NvrEditScreen({super.key, this.device});
  final Device? device;

  @override
  ConsumerState<NvrEditScreen> createState() => _NvrEditScreenState();
}

class _NvrEditScreenState extends ConsumerState<NvrEditScreen> {
  late final _name = TextEditingController(text: _initName());
  late final _host = TextEditingController(text: widget.device?.host ?? '');
  late final _user =
      TextEditingController(text: widget.device?.user ?? 'admin');
  late final _pass = TextEditingController(text: widget.device?.pass ?? '');
  late final _port =
      TextEditingController(text: (widget.device?.onvifPort ?? 80).toString());
  late final _channels = TextEditingController(
      text: widget.device?.manualChannels?.toString() ?? '');
  bool _busy = false;

  String _initName() {
    final d = widget.device;
    if (d == null) return '';
    return d.name == d.host ? '' : d.name;
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _user, _pass, _port, _channels]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scan() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final hosts = await ref.read(onvifServiceProvider).discover();
      if (hosts.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No ONVIF devices found. Enter IP.')),
        );
      } else {
        _host.text = hosts.first.host;
        if (_name.text.isEmpty) _name.text = hosts.first.name;
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final host = _host.text.trim();
    if (host.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter the host / IP')));
      return;
    }
    final sameHost = widget.device?.host == host;
    final device = Device(
      id: host,
      name: _name.text.trim().isEmpty ? host : _name.text.trim(),
      host: host,
      user: _user.text.trim(),
      pass: _pass.text,
      onvifPort: int.tryParse(_port.text.trim()) ?? 80,
      // Keep ONVIF-resolved channels only when the host is unchanged.
      channels: sameHost ? (widget.device?.channels ?? const []) : const [],
      manualChannels: int.tryParse(_channels.text.trim()),
    );
    // Host changed → new id; drop the old entry to avoid a dupe.
    if (widget.device != null && widget.device!.id != device.id) {
      await ref.read(devicesProvider.notifier).remove(widget.device!.id);
    }
    await ref.read(devicesProvider.notifier).upsert(device);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device == null ? 'Add NVR' : 'Edit NVR'),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_name, 'Name (optional)'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _field(_host, 'Host / IP')),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.wifi_find),
                  label: const Text('Scan'),
                ),
              ],
            ),
            _field(_user, 'Username'),
            _field(_pass, 'Password', obscure: true),
            _field(_port, 'ONVIF port', number: true),
            _field(_channels, 'Channels (optional, fallback if ONVIF off)',
                number: true),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool obscure = false, bool number = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
