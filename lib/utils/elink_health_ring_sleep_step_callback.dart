import 'package:elink_health_ring/model/elink_sleep_and_step_data.dart';
import 'package:flutter/cupertino.dart';

class ElinkHealthRingSleepStepCallback {
  final ValueChanged<int>? onGetCheckDuration;
  final OnGetSleepAndStepHistory? onGetSleepAndStepHistory;
  final VoidCallback? onNotifySleepAndStepHistoryGenerated;
  final ValueChanged<bool>? onGetSleepCheckState;
  final ValueChanged<bool>? onGetStepCheckState;

  ElinkHealthRingSleepStepCallback({
    this.onGetCheckDuration,
    this.onGetSleepAndStepHistory,
    this.onNotifySleepAndStepHistoryGenerated,
    this.onGetSleepCheckState,
    this.onGetStepCheckState,
  });
}

typedef OnGetSleepAndStepHistory =
    Function(List<ElinkSleepAndStepData>, int, int);
