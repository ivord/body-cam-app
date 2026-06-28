import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/backchannel/backchannel_channel.dart';

/// Two-way audio control. Tap **Talk** to open a full-duplex conversation, then
/// **Mute/Unmute** the mic without dropping the call. AEC/NS run on the mic
/// natively. Tap **End** to close the backchannel.
class TalkControls extends StatefulWidget {
  const TalkControls({
    super.key,
    required this.host,
    required this.onvifPort,
    required this.user,
    required this.pass,
    this.profileToken,
  });

  final String host;
  final int onvifPort;
  final String user;
  final String pass;
  final String? profileToken;

  @override
  State<TalkControls> createState() => _TalkControlsState();
}

class _TalkControlsState extends State<TalkControls> {
  bool _active = false; // call open
  bool _muted = false;
  bool _busy = false;

  Future<void> _startTalk() async {
    if (_busy || _active) return;
    if (!await Permission.microphone.request().isGranted) {
      _toast('Microphone permission denied');
      return;
    }
    setState(() => _busy = true);
    try {
      await BackchannelChannel.start(
        host: widget.host,
        onvifPort: widget.onvifPort,
        user: widget.user,
        pass: widget.pass,
        profileToken: widget.profileToken,
      );
      setState(() {
        _active = true;
        _muted = false;
      });
    } on PlatformException catch (e) {
      _toast(e.code == 'UNSUPPORTED'
          ? 'This NVR/firmware has no audio backchannel'
          : 'Talk failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endTalk() async {
    if (!_active) return;
    await BackchannelChannel.stop();
    if (mounted) setState(() => _active = false);
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await BackchannelChannel.setMuted(next);
    if (mounted) setState(() => _muted = next);
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  void dispose() {
    if (_active) BackchannelChannel.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) {
      return FilledButton.icon(
        onPressed: _busy ? null : _startTalk,
        icon: Icon(_busy ? Icons.hourglass_top : Icons.call),
        label: const Text('Talk'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _toggleMute,
          icon: Icon(_muted ? Icons.mic_off : Icons.mic),
          label: Text(_muted ? 'Unmute' : 'Mute'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _muted ? Colors.amber : null,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: _endTalk,
          icon: const Icon(Icons.call_end),
          label: const Text('End'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ],
    );
  }
}
