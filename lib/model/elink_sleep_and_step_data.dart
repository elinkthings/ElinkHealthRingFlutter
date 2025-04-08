import 'package:elink_health_ring/utils/elink_health_ring_config.dart';

class ElinkSleepAndStepData {
  final int time;
  final ElinkSleepState sleepState;
  final int steps;

  ElinkSleepAndStepData(this.time, this.sleepState, this.steps);

  @override
  String toString() {
    return 'ElinkSleepAndStepData('
        'time: ${DateTime.fromMillisecondsSinceEpoch(time)}, '
        'sleepState: $sleepState, '
        'steps: $steps)';
  }
}
