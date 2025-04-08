import 'package:elink_health_ring/utils/elink_health_ring_config.dart';

class ElinkHealthRingStatus {
  final ElinkHealthRingHistoryState state;
  final int batteryLevel;
  final bool isCharging;
  final ElinkWearingStatus wearingStatus;

  ElinkHealthRingStatus(
    this.state,
    this.batteryLevel,
    this.isCharging,
    this.wearingStatus,
  );

  bool get isWearing => wearingStatus == ElinkWearingStatus.wearing;

  @override
  String toString() {
    return 'ElinkRingDeviceStatus(state: $state, batteryLevel: $batteryLevel, '
        'isCharging: $isCharging, isWearing: $isWearing)';
  }
}
