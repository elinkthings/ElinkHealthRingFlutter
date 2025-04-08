import 'dart:typed_data';

import 'package:elink_health_ring/model/elink_checkup_history_data.dart';
import 'package:elink_health_ring/model/elink_chekup_realtime_data.dart';
import 'package:elink_health_ring/utils/elink_health_ring_config.dart';
import 'package:flutter/material.dart';

class ElinkHealthRingCheckupCallback {
  final ValueChanged<bool>? onStartCheckup;
  final ValueChanged<bool>? onStopCheckup;
  final ValueChanged<ElinkCheckupRealtimeData>? onGetRealtimeData;
  final ValueChanged<Uint8List>? onGetCheckupPackets;
  final ValueChanged<int>? onGetCheckupDuration;
  final OnGetCheckupHistory? onGetCheckupHistory;
  final ValueChanged<bool>? onGetAutoCheckupStatus;
  final ValueChanged<ElinkCheckupType>? onGetCheckupType;
  final VoidCallback? onNotifyCheckupHistoryGenerated;

  ElinkHealthRingCheckupCallback({
    this.onStartCheckup,
    this.onStopCheckup,
    this.onGetRealtimeData,
    this.onGetCheckupPackets,
    this.onGetCheckupDuration,
    this.onGetCheckupHistory,
    this.onGetAutoCheckupStatus,
    this.onGetCheckupType,
    this.onNotifyCheckupHistoryGenerated,
  });
}

typedef OnGetCheckupHistory = Function(List<ElinkCheckupHistoryData>, int, int);
