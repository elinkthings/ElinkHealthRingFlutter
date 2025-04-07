import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'elink_health_ring_platform_interface.dart';

/// An implementation of [ElinkHealthRingPlatform] that uses method channels.
class MethodChannelElinkHealthRing extends ElinkHealthRingPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('elink_health_ring');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
