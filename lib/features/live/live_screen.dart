import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../services/rtsp_url_builder.dart';
import '../devices/device.dart';
import '../devices/device_repository.dart';
import '../talk/talk_controls.dart';

/// Single-channel live view. Substream by default (bandwidth); HD toggle swaps
/// to main stream. RTSP over TCP + low-latency mpv tuning. Keeps screen awake.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key, required this.deviceId, required this.channel});
  final String deviceId;
  final int channel;

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  bool _hd = AppConfig.defaultMainStream;
  late int _channel = widget.channel; // mutable: in-live channel switching

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _rememberAndOpen();
  }

  void _rememberAndOpen() {
    // Remember this camera so the next session can resume it.
    ref.read(deviceRepoProvider).saveLastViewed(widget.deviceId, _channel);
    _openStream();
  }

  Device get _device =>
      ref.read(devicesProvider).firstWhere((d) => d.id == widget.deviceId);

  CameraChannel get _ch => _device.channels.firstWhere(
        (c) => c.channel == _channel,
        orElse: () => CameraChannel(channel: _channel, name: 'Channel'),
      );

  /// Switch to prev/next NVR channel (wraps). No-op for single-cam devices.
  Future<void> _switch(int delta) async {
    final chans = _device.channels;
    if (chans.length < 2) return;
    final idx = chans.indexWhere((c) => c.channel == _channel);
    final next = chans[(idx + delta) % chans.length];
    setState(() => _channel = next.channel);
    ref.read(deviceRepoProvider).saveLastViewed(widget.deviceId, _channel);
    await _player.open(Media(_streamUrl()));
  }

  String _streamUrl() {
    final d = _device;
    final ch = _ch;
    // Prefer ONVIF-resolved URI when present; else build the Dahua URL.
    final onvifUri = _hd ? ch.mainStreamUri : ch.subStreamUri;
    if (onvifUri != null && onvifUri.isNotEmpty) {
      return RtspUrlBuilder.withCreds(onvifUri, d.user, d.pass);
    }
    return RtspUrlBuilder.build(
      host: d.host,
      user: d.user,
      pass: d.pass,
      channel: _channel,
      mainStream: _hd,
    );
  }

  Future<void> _openStream() async {
    final native = _player.platform;
    if (native is NativePlayer && AppConfig.rtspOverTcp) {
      await native.setProperty('rtsp-transport', 'tcp');
      await native.setProperty('profile', 'low-latency');
      await native.setProperty('cache', 'no');
    }
    await _player.open(Media(_streamUrl()));
  }

  Future<void> _toggleHd() async {
    setState(() => _hd = !_hd);
    await _player.open(Media(_streamUrl()));
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    WakelockPlus.disable();
    // Stop the RTSP pull immediately so the NVR stops serving this view.
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch so a background channel refresh lights up the switcher.
    final device = ref.watch(devicesProvider).firstWhere(
          (d) => d.id == widget.deviceId,
          orElse: () => _device,
        );
    final multiCam = device.channels.length > 1;
    final ch = _ch;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(ch.name, style: monoText(fontSize: 11)),
          ],
        ),
        actions: [
          if (multiCam) ...[
            IconButton(
              tooltip: 'Previous camera',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _switch(-1),
            ),
            IconButton(
              tooltip: 'Next camera',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _switch(1),
            ),
          ],
          _hdSdSegment(),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        children: [
          // Swipe left/right to switch cameras (multi-cam NVR).
          GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -250) _switch(1);
              if (v > 250) _switch(-1);
            },
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Video(controller: _controller),
                ),
                Positioned(
                  top: 11,
                  left: 12,
                  child: _recBadge(ch.name),
                ),
                Positioned(
                  top: 11,
                  right: 12,
                  child: _clockBadge(),
                ),
                Positioned(
                  bottom: 9,
                  left: 12,
                  child: Text(
                    '${device.host} · CH${_pad2(ch.channel)}',
                    style: monoText(fontSize: 10.5, color: const Color(0xFF7B8794)),
                  ),
                ),
                const Positioned(bottom: 9, right: 12, child: _LiveBadge()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _propertyChips(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TalkControls(
                    host: device.host,
                    onvifPort: device.onvifPort,
                    user: device.user,
                    pass: device.pass,
                    profileToken: ch.onvifToken,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hdSdSegment() {
    const segBase = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: BorderRadius.circular(9),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _hd ? _toggleHd : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              color: _hd ? AppColors.surface : AppColors.teal.withValues(alpha: .16),
              child: Text('SD',
                  style: segBase.copyWith(
                      color: _hd ? AppColors.textTertiary : AppColors.teal,
                      fontFamily: monoText().fontFamily)),
            ),
          ),
          InkWell(
            onTap: _hd ? null : _toggleHd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              color: _hd ? AppColors.amber.withValues(alpha: .18) : AppColors.surface,
              child: Text('HD',
                  style: segBase.copyWith(
                      color: _hd ? AppColors.amber : AppColors.textTertiary,
                      fontFamily: monoText().fontFamily)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recBadge(String channelName) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BlinkingDot(),
                const SizedBox(width: 7),
                Text('REC',
                    style: monoText(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(channelName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
              )),
        ],
      );

  Widget _clockBadge() => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _Clock(),
          const SizedBox(height: 2),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _hd
                  ? AppColors.amber.withValues(alpha: .85)
                  : AppColors.teal.withValues(alpha: .85),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(_hd ? 'HD' : 'SD',
                style: monoText(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                  color: _hd ? const Color(0xFF2A1C00) : AppColors.tealOn,
                )),
          ),
        ],
      );

  Widget _propertyChips() {
    Widget chip(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(text,
              style: monoText(fontSize: 11, fontWeight: FontWeight.w600)),
        );
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        chip('H.265'),
        chip('RTSP / TCP'),
        chip(_hd ? 'MAIN STREAM' : 'SUBSTREAM'),
        chip('LOW-LATENCY'),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text('LIVE',
            style: monoText(
                fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green)),
      ],
    );
  }
}

/// Blinking REC dot; isolated so it doesn't rebuild anything else.
class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: .25, end: 1.0).animate(_c),
      child: const DecoratedBox(
        decoration: BoxDecoration(color: AppColors.recRed, shape: BoxShape.circle),
        child: SizedBox(width: 8, height: 8),
      ),
    );
  }
}

/// Live clock, isolated so its 1Hz tick doesn't rebuild the player screen.
class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final time = '${_p(_now.hour)}:${_p(_now.minute)}:${_p(_now.second)}';
    final date = '${_now.year}-${_p(_now.month)}-${_p(_now.day)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(time,
            style: monoText(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        Text(date, style: monoText(fontSize: 10.5, color: const Color(0xFFCDD8E0))),
      ],
    );
  }
}
