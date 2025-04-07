
import 'elink_health_ring_platform_interface.dart';

class ElinkHealthRing {
  Future<String?> getPlatformVersion() {
    return ElinkHealthRingPlatform.instance.getPlatformVersion();
  }
}
