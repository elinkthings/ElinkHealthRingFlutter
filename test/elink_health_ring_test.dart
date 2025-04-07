import 'package:flutter_test/flutter_test.dart';
import 'package:elink_health_ring/elink_health_ring.dart';
import 'package:elink_health_ring/elink_health_ring_platform_interface.dart';
import 'package:elink_health_ring/elink_health_ring_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockElinkHealthRingPlatform
    with MockPlatformInterfaceMixin
    implements ElinkHealthRingPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ElinkHealthRingPlatform initialPlatform = ElinkHealthRingPlatform.instance;

  test('$MethodChannelElinkHealthRing is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelElinkHealthRing>());
  });

  test('getPlatformVersion', () async {
    ElinkHealthRing elinkHealthRingPlugin = ElinkHealthRing();
    MockElinkHealthRingPlatform fakePlatform = MockElinkHealthRingPlatform();
    ElinkHealthRingPlatform.instance = fakePlatform;

    expect(await elinkHealthRingPlugin.getPlatformVersion(), '42');
  });
}
