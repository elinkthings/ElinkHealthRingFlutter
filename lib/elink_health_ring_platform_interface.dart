import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'elink_health_ring_method_channel.dart';

abstract class ElinkHealthRingPlatform extends PlatformInterface {
  /// Constructs a ElinkHealthRingPlatform.
  ElinkHealthRingPlatform() : super(token: _token);

  static final Object _token = Object();

  static ElinkHealthRingPlatform _instance = MethodChannelElinkHealthRing();

  /// The default instance of [ElinkHealthRingPlatform] to use.
  ///
  /// Defaults to [MethodChannelElinkHealthRing].
  static ElinkHealthRingPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ElinkHealthRingPlatform] when
  /// they register themselves.
  static set instance(ElinkHealthRingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
