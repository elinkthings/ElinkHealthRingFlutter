import 'dart:typed_data';

import 'package:ailink/utils/elink_cmd_utils.dart';
import 'package:elink_health_ring/utils/elink_health_ring_base_utils.dart';
import 'package:elink_health_ring/utils/elink_health_ring_config.dart';

class ElinkHealthRingCmdUtils extends ElinkHealthRingBaseUtils {
  static ElinkHealthRingCmdUtils? _instance;

  ElinkHealthRingCmdUtils._();

  factory ElinkHealthRingCmdUtils(
    List<int> mac, {
    List<int> cid = ElinkHealthRingConfig.cidHealthRing,
  }) {
    _instance ??= ElinkHealthRingCmdUtils._();
    _instance?.initialize(mac, cid: cid);
    return _instance!;
  }

  Future<List<int>> replyDevice() {
    return getElinkA7Data([0x88, 0x00]);
  }

  Future<List<int>> startCheckup() {
    return getElinkA7Data([0x02, 0x01]);
  }

  Future<List<int>> stopCheckup() {
    return getElinkA7Data([0x02, 0x00]);
  }

  Future<List<int>> getCheckupDuration() {
    return getElinkA7Data([0x04, 0x00]);
  }

  Future<List<int>> setCheckupDuration(int duration) {
    final durationList = ElinkCmdUtils.intToBytes(duration, length: 2, littleEndian: false);
    return getElinkA7Data([0x04, 0x01, ...durationList]);
  }

  Future<List<int>> getCheckupHistory() {
    final cmd = List<int>.filled(6, 0);
    cmd[0] = 0x05;
    cmd[1] = 0x00;
    return getElinkA7Data(cmd);
  }

  Future<List<int>> getNextCheckupHistory() {
    final cmd = List<int>.filled(6, 0);
    cmd[0] = 0x05;
    cmd[1] = 0x01;
    return getElinkA7Data(cmd);
  }

  Future<List<int>> getCheckupHistoryOver() {
    final cmd = List<int>.filled(6, 0);
    cmd[0] = 0x05;
    cmd[1] = 0x02;
    return getElinkA7Data(cmd);
  }

  Future<List<int>> deleteCheckupHistory() {
    final cmd = List<int>.filled(6, 0);
    cmd[0] = 0x05;
    cmd[1] = 0x03;
    return getElinkA7Data(cmd);
  }

  List<int> syncBleTime(DateTime now) {
    final year = now.year - 2000;
    final month = now.month;
    final day = now.day;
    final hour = now.hour;
    final minute = now.minute;
    final second = now.second;
    // final dayOfWeek = now.weekday; // 1 表示星期一，7 表示星期天
    final payload = [0x1B, 0x01, year, month, day, hour, minute, second /*, dayOfWeek*/];
    return ElinkCmdUtils.getElinkA6Data(payload);
  }

  List<int> getTime() {
    return ElinkCmdUtils.getElinkA6Data([0x1C]);
  }

  List<int> syncUnixTime(DateTime now) {
    final unixTimestamp = now.millisecondsSinceEpoch ~/ 1000; // 转换为秒
    final bytes = Uint8List(4);
    bytes[0] = unixTimestamp & 0xFF;
    bytes[1] = (unixTimestamp >> 8) & 0xFF;
    bytes[2] = (unixTimestamp >> 16) & 0xFF;
    bytes[3] = (unixTimestamp >> 24) & 0xFF;
    final payload = [0x45, ...bytes];
    return ElinkCmdUtils.getElinkA6Data(payload);
  }

  List<int> getUnixTime() {
    return ElinkCmdUtils.getElinkA6Data([0x44]);
  }

  Future<List<int>> getDeviceState() {
    final cmd = List<int>.filled(5, 0);
    cmd[0] = 0x06;
    cmd[1] = 0x01;
    return getElinkA7Data(cmd);
  }

  Future<List<int>> getAutoCheckState() {
    final cmd = List<int>.filled(3, 0);
    cmd[0] = 0x09;
    cmd[1] = 0x00;
    return getElinkA7Data(cmd);
  }

  Future<List<int>> openAutoCheck() {
    return getElinkA7Data([0x09, 0x01, 0x00]);
  }

  Future<List<int>> closeAutoCheck() {
    return getElinkA7Data([0x09, 0x01, 0x01]);
  }

  Future<List<int>> getJFSensorInfo() {
    return getElinkA7Data([0x08, 0x01]);
  }

  Future<List<int>> getCheckupType() {
    return getElinkA7Data([0x0B, 0x00, 0x00]);
  }

  Future<List<int>> setCheckupType(ElinkCheckupType type) {
    final int rriSize;
    switch (type) {
      case ElinkCheckupType.complex:
        rriSize = 72;
        break;
      case ElinkCheckupType.fast:
        rriSize = 30;
        break;
    }
    return getElinkA7Data([0x0B, 0x01, rriSize]);
  }

  Future<List<int>> setSleepAndStepDuration(int duration) {
    final durationList = ElinkCmdUtils.intToBytes(duration, length: 2, littleEndian: false);
    return getElinkA7Data([0x10, 0x01, ...durationList]);
  }

  Future<List<int>> getSleepAndStepDuration() {
    final cmd = List.filled(4, 0);
    cmd[0] = 0x10;
    return getElinkA7Data(cmd);
  }

  Future<List<int>> getSleepAndStepHistory() {
    final cmd = List<int>.filled(6, 0);
    cmd[0] = 0x11;
    cmd[1] = 0x00;
    return getElinkA7Data(cmd);
  }

  Future<List<int>> getNextSleepAndStepHistory() {
    final cmd = List<int>.filled(6, 0);
    cmd[0] = 0x11;
    cmd[1] = 0x01;
    return getElinkA7Data(cmd);
  }

  Future<List<int>> getSleepAndStepHistoryOver() {
    final cmd = List<int>.filled(6, 0);
    cmd[0] = 0x11;
    cmd[1] = 0x02;
    return getElinkA7Data(cmd);
  }

  Future<List<int>> deleteSleepAndStepHistory() {
    final cmd = List<int>.filled(6, 0);
    cmd[0] = 0x11;
    cmd[1] = 0x03;
    return getElinkA7Data(cmd);
  }

  Future<List<int>> getSleepCheckState() {
    final cmd = List<int>.filled(3, 0);
    cmd[0] = 0x14;
    return getElinkA7Data(cmd);
  }

  Future<List<int>> openSleepCheck() {
    return getElinkA7Data([0x14, 0x01, 0x00]);
  }

  Future<List<int>> closeSleepCheck() {
    return getElinkA7Data([0x14, 0x01, 0x01]);
  }

  Future<List<int>> getStepCheckState() {
    final cmd = List<int>.filled(3, 0);
    cmd[0] = 0x15;
    return getElinkA7Data(cmd);
  }

  Future<List<int>> openStepCheck() {
    return getElinkA7Data([0x15, 0x01, 0x00]);
  }

  Future<List<int>> closeStepCheck() {
    return getElinkA7Data([0x15, 0x01, 0x01]);
  }
}
