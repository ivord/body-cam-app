import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
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
  bool _showPass = false;

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
            _field(_name, 'NAME (OPTIONAL)'),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _field(_host, 'HOST / IP')),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _scan,
                  icon: _busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.teal),
                        )
                      : const Icon(Icons.wifi_find, size: 17),
                  label: Text(_busy ? 'Scanning' : 'Scan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    side: BorderSide(
                        color: _busy
                            ? AppColors.teal.withValues(alpha: .5)
                            : const Color(0xFF1C4742)),
                    backgroundColor: _busy
                        ? AppColors.teal.withValues(alpha: .12)
                        : const Color(0xFF0E1A19),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _field(_user, 'USERNAME'),
            const SizedBox(height: 16),
            _field(
              _pass,
              'PASSWORD',
              obscure: !_showPass,
              suffixIcon: _showPass ? Icons.visibility_off : Icons.visibility,
              onSuffixTap: () => setState(() => _showPass = !_showPass),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field(_port, 'ONVIF PORT', number: true)),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_channels, 'CHANNELS', number: true, hint: 'auto'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Channels is a fallback count used only when ONVIF discovery is off.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TealButton(
              icon: Icons.save,
              label: 'Save',
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool obscure = false,
    bool number = false,
    String? hint,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: monoText(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            )),
        const SizedBox(height: 7),
        TextField(
          controller: c,
          obscureText: obscure,
          keyboardType: number ? TextInputType.number : null,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
            fontFamily: number || obscure ? monoText().fontFamily : null,
          ),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            suffixIcon: suffixIcon == null
                ? null
                : IconButton(
                    icon: Icon(suffixIcon, size: 19, color: AppColors.textSecondary),
                    onPressed: onSuffixTap,
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: AppColors.teal),
            ),
          ),
        ),
      ],
    );
  }
}
