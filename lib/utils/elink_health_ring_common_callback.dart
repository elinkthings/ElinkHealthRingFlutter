import 'package:elink_health_ring/model/elink_health_ring_status.dart';
import 'package:flutter/cupertino.dart';

class ElinkHealthRingCommonCallback {
  final ValueChanged<ElinkHealthRingStatus>? onDeviceStatusChanged;
  final ValueChanged<String>? onGetSensorVersion;
  final ValueChanged<bool>? onSetUnixTimeResult;
  final ValueChanged<bool>? onSyncBleTimeResult;

  ElinkHealthRingCommonCallback({
    this.onDeviceStatusChanged,
    this.onGetSensorVersion,
    this.onSetUnixTimeResult,
    this.onSyncBleTimeResult,
  });
}
