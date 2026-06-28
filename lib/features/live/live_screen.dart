import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/config.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text('${device.name} · ${_ch.name}'),
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
          TextButton(
            onPressed: _toggleHd,
            child: Text(
              _hd ? 'HD' : 'SD',
              style: TextStyle(
                color: _hd ? Colors.amber : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Swipe left/right to switch cameras (multi-cam NVR).
          GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -250) _switch(1);
              if (v > 250) _switch(-1);
            },
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Video(controller: _controller),
            ),
          ),
          const SizedBox(height: 16),
          TalkControls(
            host: device.host,
            onvifPort: device.onvifPort,
            user: device.user,
            pass: device.pass,
            profileToken: _ch.onvifToken,
          ),
        ],
      ),
    );
  }
}
