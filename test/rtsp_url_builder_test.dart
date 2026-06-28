import 'package:flutter_test/flutter_test.dart';
import 'package:nvr_viewer/services/rtsp_url_builder.dart';

void main() {
  test('substream by default (bandwidth saving)', () {
    final url = RtspUrlBuilder.build(
      host: '192.168.1.10',
      user: 'admin',
      pass: 'pass',
      channel: 2,
    );
    expect(url, contains('subtype=1'));
    expect(url, contains('channel=2'));
    expect(url, startsWith('rtsp://admin:pass@192.168.1.10:554/'));
  });

  test('mainStream switches to subtype 0', () {
    final url = RtspUrlBuilder.build(
      host: 'h',
      user: 'u',
      pass: 'p',
      mainStream: true,
    );
    expect(url, contains('subtype=0'));
  });

  test('credentials are url-encoded', () {
    final url = RtspUrlBuilder.build(
      host: 'h',
      user: 'a b',
      pass: 'p@ss/word',
    );
    expect(url, contains('a%20b'));
    expect(url, contains('p%40ss%2Fword'));
  });

  test('withCreds injects auth into credential-less ONVIF uri', () {
    final out = RtspUrlBuilder.withCreds(
      'rtsp://192.168.1.10:554/onvif1',
      'admin',
      'pass',
    );
    expect(out, 'rtsp://admin:pass@192.168.1.10:554/onvif1');
  });

  test('withCreds leaves an already-authed uri untouched', () {
    const u = 'rtsp://x:y@192.168.1.10:554/onvif1';
    expect(RtspUrlBuilder.withCreds(u, 'a', 'b'), u);
  });
}
