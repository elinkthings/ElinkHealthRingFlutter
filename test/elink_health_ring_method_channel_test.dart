import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elink_health_ring/elink_health_ring_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelElinkHealthRing platform = MethodChannelElinkHealthRing();
  const MethodChannel channel = MethodChannel('elink_health_ring');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
