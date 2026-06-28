import 'package:flutter_test/flutter_test.dart';
import 'package:nvr_viewer/features/devices/device_repository.dart';

void main() {
  test('parses deviceId|channel', () {
    final r = DeviceRepository.parseLastViewed('192.168.1.10|3');
    expect(r?.deviceId, '192.168.1.10');
    expect(r?.channel, 3);
  });

  test('null/garbage returns null', () {
    expect(DeviceRepository.parseLastViewed(null), isNull);
    expect(DeviceRepository.parseLastViewed(''), isNull);
    expect(DeviceRepository.parseLastViewed('nopipe'), isNull);
    expect(DeviceRepository.parseLastViewed('host|abc'), isNull);
  });
}
