import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nvr_viewer/services/nvr_status.dart';

void main() {
  test('online when a TCP port accepts connections', () async {
    final server = await ServerSocket.bind('127.0.0.1', 0);
    addTearDown(server.close);
    expect(
      await isNvrOnline('127.0.0.1', server.port, const Duration(seconds: 1)),
      isTrue,
    );
  });

  test('offline when nothing is listening', () async {
    // Bind then immediately close to get a port known to be free.
    final probe = await ServerSocket.bind('127.0.0.1', 0);
    final closedPort = probe.port;
    await probe.close();
    expect(
      await isNvrOnline('127.0.0.1', closedPort, const Duration(seconds: 1)),
      isFalse,
    );
  });
}
