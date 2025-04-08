import 'dart:typed_data';

import 'package:ailink/ailink.dart';
import 'package:ailink/utils/common_extensions.dart';
import 'package:ailink/utils/elink_cmd_utils.dart';
import 'package:elink_health_ring/model/elink_checkup_history_data.dart';
import 'package:elink_health_ring/model/elink_chekup_realtime_data.dart';
import 'package:elink_health_ring/model/elink_health_ring_status.dart';
import 'package:elink_health_ring/model/elink_sleep_and_step_data.dart';
import 'package:elink_health_ring/utils/elink_health_ring_base_utils.dart';
import 'package:elink_health_ring/utils/elink_health_ring_checkup_callback.dart';
import 'package:elink_health_ring/utils/elink_health_ring_common_callback.dart';
import 'package:elink_health_ring/utils/elink_health_ring_config.dart';
import 'package:elink_health_ring/utils/elink_health_ring_sleep_step_callback.dart';
import 'package:elink_health_ring/utils/extensions.dart';
import 'package:elink_health_ring/utils/jf_ota_utils.dart';

import 'log_utils.dart';

class ElinkHealthRingDataParseUtils extends ElinkHealthRingBaseUtils {
  static ElinkHealthRingDataParseUtils? _instance;

  ElinkHealthRingDataParseUtils._();

  factory ElinkHealthRingDataParseUtils(
    List<int> mac, {
    List<int> cid = ElinkHealthRingConfig.cidHealthRing,
  }) {
    _instance ??= ElinkHealthRingDataParseUtils._();
    _instance?.initialize(mac, cid: cid);
    return _instance!;
  }

  ElinkHealthRingCommonCallback? _commonCallback;
  ElinkHealthRingCheckupCallback? _checkupCallback;
  ElinkHealthRingSleepStepCallback? _sleepStepCallback;
  JFOTAUtils? _jfotaUtils;

  void setCallback({
    ElinkHealthRingCommonCallback? commonCallback,
    ElinkHealthRingCheckupCallback? checkupCallback,
    ElinkHealthRingSleepStepCallback? sleepStepCallback,
    JFOTAUtils? jfotaUtils,
  }) {
    _commonCallback = commonCallback;
    _checkupCallback = checkupCallback;
    _sleepStepCallback = sleepStepCallback;
    _jfotaUtils = jfotaUtils;
  }

  Future<void> parseElinkData(List<int> data) async {
    logD('parseElinkData: ${data.toHex()}');
    if (ElinkCmdUtils.checkElinkCmdSum(data)) {
      logD('parseElinkData checkElinkCmdSum: ${data.toHex()}');
      if (ElinkCmdUtils.isElinkA6Data(data)) {
        logD('parseElinkData isElinkA6Data: ${data.toHex()}');
        final payload = ElinkCmdUtils.formatA6Data(data);
        _parseData(Uint8List.fromList(payload));
      } else if (ElinkCmdUtils.isElinkA7Data(data)) {
        logD('parseElinkData isElinkA7Data: ${data.toHex()}');
        final cid = data.sublist(1, 3);
        logD('parseElinkData isElinkA7Data: ${cid.toHex()}');
        if (ElinkHealthRingConfig.isCidHealthRing(cid)) {
          if (getMac() == null) return;
          final decrypted = await Ailink().mcuDecrypt(Uint8List.fromList(getMac()!), Uint8List.fromList(data));
          logD('parseElinkData isElinkA7Data isCidHealthRing: ${cid.toHex()}');
          _parseData(decrypted);
        }
      }
    }
  }

  void _parseData(Uint8List payload) {
    logD('ElinkHealthRing parseData: ${payload.toHex()}');
    final cmd = payload[0];
    switch (cmd) {
      case 0x02: //设置体检模式
        final state = payload[1];
        final status = payload[2] == 0x00; //true: 成功; false: 失败
        if (state == 0x01) {
          _checkupCallback?.onStartCheckup?.call(status);
        } else {
          _checkupCallback?.onStopCheckup?.call(status);
        }
        break;
      case 0x03: //体检数据
        final type = payload[3];
        final realData = payload.sublist(4);
        if (type == 0x01) {
          //实时包
          _parseRealtimePackets(realData);
        } else if (type == 0x02) {
          //体检包
          _parseCheckupPackets(realData);
        }
        break;
      case 0x04: //获取监测周期
        _parseSetDurationResult(payload.sublist(1));
        break;
      case 0x05: //历史数据
        _parseHistory(payload.sublist(1));
        break;
      case 0x06: //设备状态
        _parseDeviceStatus(payload.sublist(1));
        break;
      case 0x07:
        if (getMac() == null) return;
        _jfotaUtils?.parseReceiveData(payload);
        break;
      case 0x08:  //惊帆传感器信息
        _parseJFSensorInfo(payload.sublist(1));
        break;
      case 0x09:
        _parseAutoCheckState(payload.sublist(1));
        break;
      case 0x0B:
        _parseCheckupType(payload.sublist(1));
        break;
      case 0x0C:
        _parseNotifyHistory(payload.sublist(1));
        break;
      case 0x10:
        _parseSleepAndCheckDurationResult(payload.sublist(1));
        break;
      case 0x11: //睡眠和步数历史数据
        _parseSleepAndStepHistory(payload.sublist(1));
        break;
      case 0x12:
        _parseNotifySleepAndStepHistory(payload.sublist(1));
        break;
      case 0x14:
        _parseSleepCheckState(payload.sublist(1));
        break;
      case 0x15:
        _parseStepCheckState(payload.sublist(1));
        break;
      case 0x1B: //同步时间结果
        _parseSetBleTimeResult(payload.sublist(1));
        break;
      case 0x45: //设置unix时间
        _parseSetUnixTimeResult(payload.sublist(1));
        break;
      default:
        break;
    }
  }

  /// 解析实时包
  void _parseRealtimePackets(Uint8List payload) {
    logD('实时包: ${payload.toHex()}');
    if (payload.length == 88 && payload[0] == 0xFF) {
      final heartRate = payload[65] & 0xFF;
      final bloodOxygen = payload[66] & 0xFF;
      final heartList = payload.sublist(1, 65).map((e) {
        if (e >= 128) {
          return e - 128;
        } else {
          return e + 128;
        }
      }).toList();
      final rr = payload[75] * 10;
      final rri = payload.sublist(80, 86).where((e) => e != 0).map((e) => (2500 / 250 * e).toInt()).toList();
      logD('心率: $heartRate, 血氧: $bloodOxygen, 心电图: ${heartList.toString()}, rr: $rr, rri: $rri');
      _checkupCallback?.onGetRealtimeData?.call(ElinkCheckupRealtimeData(heartRate, bloodOxygen, heartList, rr, rri));
    }
  }

  /// 解析体检包
  void _parseCheckupPackets(Uint8List payload) {
    logD('体检包: ${payload.toHex()}');
    if (payload.length == 168) {
      _checkupCallback?.onGetCheckupPackets?.call(payload);
    }
  }

  void _parseDeviceStatus(Uint8List payload) {
    if (payload.length == 13) {
      // 0x00 历史时间未就绪(未获取unix时间) 0x01 历史时间正在处理中(已获取unix时间,在处理历史数据) 0x02 历史时间已就绪(此状态才可获取设备历史记录)
      final timeState = payload[0];
      final ElinkHealthRingHistoryState historyState = switch (timeState) {
        0x01 => ElinkHealthRingHistoryState.processing,
        0x02 => ElinkHealthRingHistoryState.ready,
        _ => ElinkHealthRingHistoryState.notReady,
      };
      final batteryValue = payload[1];
      final batteryLevel = batteryValue & 0x7F; // 获取电量，通过与0x7F进行按位与操作
      final isCharging = (batteryValue & 0x80) != 0; // 判断充电状态，通过与0x80进行按位与操作，如果结果不为0，则表示正在充电
      final wearingState = payload[2]; //0x00: 无功能; 0x01: 静置状态; 0x02: 非静置状态
      final ElinkWearingStatus wearingStatus = switch (wearingState) {
        0x00 => ElinkWearingStatus.unsupported,
        0x02 => ElinkWearingStatus.wearing,
        _ => ElinkWearingStatus.notWearing,
      };
      _commonCallback?.onDeviceStatusChanged?.call(ElinkHealthRingStatus(historyState, batteryLevel, isCharging, wearingStatus));
    }
  }

  void _parseSetDurationResult(Uint8List payload) {
    final result = payload[0] == 0x02;
    if (result) {
      final duration = _getTimeFromBytes(payload.sublist(1));
      logD('监测周期: $duration');
      _checkupCallback?.onGetCheckupDuration?.call(duration);
    }
  }

  void _parseSetUnixTimeResult(Uint8List payload) {
    if (payload.length == 1) {
      final result = payload[0] == 0;
      _commonCallback?.onSetUnixTimeResult?.call(result);
    }
  }

  void _parseSetBleTimeResult(Uint8List payload) {
    if (payload.length == 1) {
      final result = payload[0] == 0;
      _commonCallback?.onSyncBleTimeResult?.call(result);
    }
  }

  final _historyPayloadLength = 91;

  void _parseHistory(Uint8List payload) {
    // logD('_parseHistory: ${payload.toHex()}');
    if (payload.length < 10) return;
    int index = 0;
    final count = payload[index++] & 0xFF;
    final currentIndex = payload[index++] & 0xFF;
    final total = _bytesToInt32(payload.sublist(index, index += 4));
    final sentCount = _bytesToInt32(payload.sublist(index, index += 4));
    logD('总帧: $count, 当前帧: $currentIndex, 历史数据总量: $total, 已发送数据量: $sentCount');
    final historyPayload = payload.sublist(index);
    final historySize = (historyPayload.length / _historyPayloadLength);
    final histories = <ElinkCheckupHistoryData>[];
    for (var i = 0; i < historySize; i++) {
      final historyData = _parseHistoryData(historyPayload.sublist(i * _historyPayloadLength, (i + 1) * _historyPayloadLength));
      if (historyData != null) {
        histories.add(historyData);
      }
    }
    _checkupCallback?.onGetCheckupHistory?.call(histories, total, sentCount);
  }

  ElinkCheckupHistoryData? _parseHistoryData(Uint8List payload) {
    if (payload.length != _historyPayloadLength) return null;
    // logD('历史数据: ${payload.toHex()}, 数据部分长度: ${payload.sublist(4).length}');
    final historyTime = _bytesToInt32(payload.sublist(0, 4));
    final dataPayload = payload.sublist(4);
    // logD('数据部分: ${dataPayload.toHex()}');
    final heartRate = dataPayload[0] & 0xFF;
    final bloodOxygen = dataPayload[1] & 0xFF;
    final bk = dataPayload[2] & 0xFF;
    final sbp = dataPayload[6] & 0xFF;
    final dbp = dataPayload[7] & 0xFF;
    final rr = (dataPayload[10] & 0xFF) * 10;
    final sdann = dataPayload[11] & 0xFF;
    final rmssd = dataPayload[12] & 0xFF;
    final nn50 = dataPayload[13] & 0xFF;
    final pnn50 = dataPayload[14] & 0xFF;
    final rri = dataPayload.sublist(_historyPayloadLength - 72).map((e) => (2500 / 250 * e).toString()).join(","); //rri总共72个byte
    logD('历史记录时间: ${DateTime.fromMillisecondsSinceEpoch(historyTime * 1000)}, 心率: $heartRate, 血氧: $bloodOxygen, 微循环: $bk, 收缩压: $sbp, 舒张压: $dbp, rr: $rr, sdnn: $sdann, rmssd: $rmssd, nn50: $nn50, pnn50: $pnn50, rri: $rri');
    return ElinkCheckupHistoryData(heartRate, bloodOxygen, bk, sbp, dbp, rr, sdann, rmssd, nn50, pnn50, historyTime * 1000, rri);
  }

  void _parseAutoCheckState(Uint8List payload) {
    if (payload.length == 2) {
      if (payload[0] == 0) { //查询
        _setAutoCheckState(payload[1]);
      } else if (payload[0] == 1) { //设置
        _setAutoCheckState(payload[1]);
      }
    }
  }

  void _setAutoCheckState(int state) {
    _checkupCallback?.onGetAutoCheckupStatus?.call(state == 0);
  }

  void _parseCheckupType(Uint8List payload) {
    if (payload.length == 2) {
      if (payload[0] == 0) { //查询
        _setCheckupType(payload[1]);
      } else if (payload[0] == 1) { //设置
        _setCheckupType(payload[1]);
      }
    }
  }

  void _parseNotifyHistory(Uint8List payload) {
    if (payload[0] == 0) { //设备通知有历史数据
      _checkupCallback?.onNotifyCheckupHistoryGenerated?.call();
    }
  }

  void _setCheckupType(int state) {
    final checkupType =  state == 0x1E ? ElinkCheckupType.fast : ElinkCheckupType.complex;
    _checkupCallback?.onGetCheckupType?.call(checkupType);
  }

  void _parseJFSensorInfo(Uint8List payload) {
    logD('_parseJFSensorInfo: ${payload.toHex()}');
    if (payload.length >= 5 && payload[0] == 0x6A && payload[1] == 0x66 && payload[2] == 0x68) {
      final jfVersion = "${payload[3].toIntStr()}${payload[4].toIntStr()}";
      logD('_parseJFSensorInfo: $jfVersion');
      _commonCallback?.onGetSensorVersion?.call(jfVersion);
    }
  }

  final _sleepAndStepHistoryPayloadLength = 9;

  void _parseSleepAndStepHistory(Uint8List payload) {
    if (payload.length < 10) return;
    int index = 0;
    final count = payload[index++] & 0xFF;
    final currentIndex = payload[index++] & 0xFF;
    final total = _bytesToInt32(payload.sublist(index, index += 4));
    final sentCount = _bytesToInt32(payload.sublist(index, index += 4));
    logD('睡眠和步数历史数据 => 总帧: $count, 当前帧: $currentIndex, 历史数据总量: $total, 已发送数据量: $sentCount');
    final historyPayload = payload.sublist(index);
    final historySize = (historyPayload.length / _sleepAndStepHistoryPayloadLength);
    final histories = <ElinkSleepAndStepData>[];
    for (var i = 0; i < historySize; i++) {
      final historyData = _parseSleepAndStepHistoryData(historyPayload.sublist(i * _sleepAndStepHistoryPayloadLength, (i + 1) * _sleepAndStepHistoryPayloadLength));
      if (historyData != null) {
        histories.add(historyData);
      }
    }
    _sleepStepCallback?.onGetSleepAndStepHistory?.call(histories, total, sentCount);
  }

  ElinkSleepAndStepData? _parseSleepAndStepHistoryData(Uint8List payload) {
    if (payload.length != _sleepAndStepHistoryPayloadLength) return null;
    // logD('历史数据: ${payload.toHex()}, 数据部分长度: ${payload.sublist(4).length}');
    final historyTime = _bytesToInt32(payload.sublist(0, 4));
    final state = payload[4]; //0~2: 清醒; 3~4: 快速眼动; 5～6: 浅睡；7: 深睡
    final ElinkSleepState sleepState = switch (state) {
      0x03 || 0x04 => ElinkSleepState.rem,
      0x05 || 0x06 => ElinkSleepState.light,
      0x07 => ElinkSleepState.deep,
      _ => ElinkSleepState.awake,
    };
    final steps = _bytesToInt32(payload.sublist(5, payload.length));
    logD('睡眠和步数历史记录: ${DateTime.fromMillisecondsSinceEpoch(historyTime * 1000)}, 睡眠等级: $sleepState, 步数: $steps');
    return ElinkSleepAndStepData(historyTime * 1000, sleepState, steps);
  }

  void _parseNotifySleepAndStepHistory(Uint8List payload) {
    if (payload[0] == 0) { //设备通知有睡眠和步数历史数据
      _sleepStepCallback?.onNotifySleepAndStepHistoryGenerated?.call();
    }
  }

  void _parseSleepAndCheckDurationResult(Uint8List payload) {
    final result = payload[0] == 0x02;
    if (result) {
      final duration = _getTimeFromBytes(payload.sublist(1));
      logD('_parseSleepAndCheckDurationResult: $duration');
      _sleepStepCallback?.onGetCheckDuration?.call(duration);
    }
  }

  void _parseSleepCheckState(Uint8List payload) {
    if (payload.length == 2) {
      if (payload[0] == 0) { //查询
        _setSleepCheckState(payload[1]);
      } else if (payload[0] == 1) { //设置
        _setSleepCheckState(payload[1]);
      }
    }
  }

  _setSleepCheckState(int state) {
    _sleepStepCallback?.onGetSleepCheckState?.call(state == 0);
  }

  void _parseStepCheckState(Uint8List payload) {
    if (payload.length == 2) {
      if (payload[0] == 0) { //查询
        _setStepCheckState(payload[1]);
      } else if (payload[0] == 1) { //设置
        _setStepCheckState(payload[1]);
      }
    }
  }

  _setStepCheckState(int state) {
    _sleepStepCallback?.onGetStepCheckState?.call(state == 0);
  }

  int _bytesToInt32(Uint8List bytes) {
    if (bytes.length != 4) {
      throw ArgumentError('Input list must contain exactly 4 bytes');
    }

    ByteData byteData = ByteData.sublistView(Uint8List.fromList(bytes));
    int result = byteData.getInt32(0, Endian.little);
    return result;
  }

  int _getTimeFromBytes(Uint8List bytes) {
    if (bytes.length != 2) {
      throw ArgumentError('The input list must contain exactly 2 bytes.');
    }

    // 将高字节和低字节合并成一个16位整数
    int combinedValue = (bytes[0] << 8) | bytes[1];

    // 解释为分钟数
    return combinedValue;
  }
}