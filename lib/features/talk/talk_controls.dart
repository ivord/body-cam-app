import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
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

class _TalkControlsState extends State<TalkControls>
    with TickerProviderStateMixin {
  bool _active = false; // call open
  bool _muted = false;
  bool _busy = false; // connecting

  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();
  late final _bars = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

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
    _pulse.dispose();
    _bars.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) return _connecting();
    if (_active) return _activeCall();
    return _idle();
  }

  Widget _idle() => Column(
        children: [
          TealButton(icon: Icons.call, label: 'Talk', onPressed: _startTalk),
          const SizedBox(height: 11),
          Text(
            "Say hi to whoever's on camera — they'll hear you live, and you'll hear them back.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      );

  Widget _connecting() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, _) {
                      final t = _pulse.value;
                      return Opacity(
                        opacity: (1 - t).clamp(0, 1),
                        child: Transform.scale(
                          scale: .85 + t * .65,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.teal, width: 2),
                            ),
                            child: const SizedBox(width: 44, height: 44),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.6, color: AppColors.teal),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Connecting your call…',
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.teal)),
          ],
        ),
      );

  Widget _activeCall() {
    final vizColor = _muted ? AppColors.amber : AppColors.teal;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 34,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(5, (i) => _bar(i, vizColor)),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _muted ? "You're muted · they can't hear you" : "You're live — go ahead and talk",
                  style: TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w600, color: vizColor),
                ),
                const SizedBox(height: 2),
                Text('Clear two-way audio · background noise filtered out',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _toggleMute,
                icon: Icon(_muted ? Icons.mic_off : Icons.mic, size: 20),
                label: Text(_muted ? 'Unmute' : 'Mute'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _muted ? AppColors.amber : const Color(0xFFC7D2DD),
                  backgroundColor:
                      _muted ? AppColors.amber.withValues(alpha: .14) : const Color(0xFF161E28),
                  side: BorderSide(
                      color: _muted ? AppColors.amber.withValues(alpha: .4) : const Color(0xFF2A3543)),
                  minimumSize: const Size.fromHeight(58),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TealButton(
                icon: Icons.call_end,
                label: 'End',
                danger: true,
                onPressed: _endTalk,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bar(int i, Color color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: AnimatedBuilder(
          animation: _bars,
          builder: (_, _) {
            final t = (_bars.value + i * .15) % 1.0;
            final scale = .3 + (1 - (2 * t - 1).abs()) * .7;
            return Transform.scale(
              alignment: Alignment.bottomCenter,
              scaleY: scale,
              child: Container(
                width: 4,
                height: 34,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
            );
          },
        ),
      );
}
