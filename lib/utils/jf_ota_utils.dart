import 'dart:typed_data';
import 'dart:ui';

import 'package:ailink/utils/common_extensions.dart';
import 'package:elink_health_ring/utils/elink_health_ring_base_utils.dart';
import 'package:elink_health_ring/utils/elink_health_ring_config.dart';
import 'package:elink_health_ring/utils/log_utils.dart';

enum JFOTAErrorType {
  startOtaFail, //进入OTA失败
  checkFail, //校验失败
  writeError, //写入错误
  eraseError, //擦除错误
  dataError, //数据错误,
  endOtaFail, //退出OTA失败
}

/// 戒指芯片(惊帆)OTA
class JFOTAUtils extends ElinkHealthRingBaseUtils {
  static const _cmdCodePageWriteOnly97 = 0x97;
  static const _cmdCodeAllErase98 = 0x98;
  static const _cmdCodePagesReadChecksum81 = 0x81;
  static const _cmdAckCmdDoneA4 = 0xA4;
  static const _cmdAckPagesCsTrueA5 = 0xA5;
  static const _cmdAckPagesCsFailA6 = 0xA6;

  int _address = 0;

  Uint8List? _fileData;

  Function(int)? _onStartSuccess;
  Function(List<int>, int)? _onOtaPageWrite;
  Function(int, int)? _onOtaPageReadChecksum;
  Function(JFOTAErrorType type)? _onFailure;
  VoidCallback? _onSuccess;
  Function(int progress)? _onProgressChanged;

  static JFOTAUtils? _instance;

  JFOTAUtils._();

  factory JFOTAUtils(
    List<int> mac, {
    List<int> cid = ElinkHealthRingConfig.cidHealthRing,
  }) {
    _instance ??= JFOTAUtils._();
    _instance?.initialize(mac, cid: cid);
    return _instance!;
  }

  void setFileData(Uint8List fileData) {
    _address = 0;
    _reverseFileData(fileData);
  }

  void _reverseFileData(Uint8List fileData) {
    final p = ByteData.sublistView(Uint8List.fromList(fileData), 0x1c);

    final mutableData = ByteData.sublistView(Uint8List(fileData.length - 0x1c), 0);

    for (int i = 0; i < (fileData.length - 0x1c) ~/ 4; i++) {
      final value = p.getUint32(i * 4, Endian.big);
      mutableData.setUint32(i * 4, value, Endian.little);
    }

    logD('_fileData1: ${fileData.length}');
    _fileData = mutableData.buffer.asUint8List();
    logD('_fileData2: ${_fileData?.length}');
  }

  void setListener({
    Function(int)? onStartSuccess,
    Function(List<int>, int)? onOtaPageWrite,
    Function(int, int)? onOtaPageReadChecksum,
    Function(JFOTAErrorType type)? onFailure,
    VoidCallback? onSuccess,
    Function(int progress)? onProgressChanged,
  }) {
    _onStartSuccess = onStartSuccess;
    _onOtaPageWrite = onOtaPageWrite;
    _onOtaPageReadChecksum = onOtaPageReadChecksum;
    _onFailure = onFailure;
    _onSuccess = onSuccess;
    _onProgressChanged = onProgressChanged;
  }

  Future<List<int>> startOTA() {
    _address = 0;
    return getElinkA7Data([0x07, 0x01]);
  }

  Future<List<int>> endOTA() => getElinkA7Data([0x07, 0x02]);

  Future<List<int>> eraseAll(int size) {
    final payload = List<int>.empty(growable: true);
    payload.addAll([
      0x07,
      0x03,
      0x55,
      0xAA,
      _cmdCodeAllErase98,
      0x04,
      0x00,
      0x00,
      size >> 8,
      size
    ]);
    final crc = checksum(payload.sublist(4, payload.length));
    payload.add(crc);
    return getElinkA7Data(payload);
  }

  Future<List<int>> pageWrite(List<int> data, int address) {
    if (data.length != 128) {
      _otaFailure(JFOTAErrorType.dataError);
      return Future.value([]);
    }
    final payload = List<int>.empty(growable: true);
    payload.addAll([
      0x07,
      0x03,
      0x55,
      0xAA,
      _cmdCodePageWriteOnly97,
      130,
      address >> 8,
      address,
      ...data
    ]);
    final crc = checksum(payload.sublist(4, payload.length));
    payload.add(crc);
    return getElinkA7Data(payload);
  }

  Future<List<int>> pageReadChecksum(int pageChecksum, int address) {
    final payload = List<int>.empty(growable: true);
    payload.addAll([
      0x07,
      0x03,
      0x55,
      0xAA,
      _cmdCodePagesReadChecksum81,
      0x04,
      address >> 8,
      address,
      0x01,
      pageChecksum
    ]);
    final crc = checksum(payload.sublist(4, payload.length));
    payload.add(crc);
    return getElinkA7Data(payload);
  }

  void otaWritePage() {
    if (_fileData == null) return;
    int endAddress = _address + 128;
    if (endAddress > _totalSize) {
      endAddress = _totalSize;
    }
    final payload = List<int>.filled(128, 0xFF);
    final packet = _fileData!.sublist(_address, endAddress);
    payload.setAll(0, packet);
    logD("otaWritePage: 发送: ${payload.length}, ${payload.toHex()} [写地址:0x${_address.toRadixString(16)}]");
    _onOtaPageWrite?.call(payload, _address);
  }

  void otaPageReadChecksum() {
    if (_fileData == null) return;
    int endAddress = _address + 128;
    if (endAddress > _totalSize) {
      endAddress = _totalSize;
    }
    final payload = List<int>.filled(128, 0xFF);
    final packet = _fileData!.sublist(_address, endAddress);
    payload.setAll(0, packet);
    int sum = checksum(payload);
    logD("otaPageReadChecksum 发送: ${payload.length}, ${payload.toHex()} [校验地址:0x${_address.toRadixString(16)} Checksum:0x${sum.toRadixString(16)}]");
    _onOtaPageReadChecksum?.call(sum, _address);
  }

  void parseReceiveData(Uint8List payload) {
    if (payload[0] != 0x07) {
      return;
    }

    switch (payload[1]) {
      case 0x01:
        if (payload[2] == 0x00) {
          logD('parseReceiveData 进入OTA成功');
          if (_fileData == null) {
            _otaFailure(JFOTAErrorType.dataError);
            return;
          }
          _onStartSuccess?.call(_fileData!.length);
        } else {
          logD('parseReceiveData 进入OTA失败');
          _otaFailure(JFOTAErrorType.startOtaFail);
        }
        break;
      case 0x02:
        if (payload[2] == 0x00) {
          logD('parseReceiveData 退出OTA成功');
        } else {
          _otaFailure(JFOTAErrorType.endOtaFail);
          logD('parseReceiveData 退出OTA失败');
        }
        break;
      case 0x03:
        _parseReceiveOtaResult(payload);
        break;
      default:
        break;
    }
  }

  void _parseReceiveOtaResult(Uint8List payload) {
    switch (payload[4]) {
      case _cmdCodeAllErase98:
        if (payload[6] == _cmdAckCmdDoneA4 && payload[5] == 0x01) {
          logD('parseReceiveOtaResult 擦除成功');
          otaWritePage();
        } else {
          logD('parseReceiveOtaResult 擦除失败');
          _otaFailure(JFOTAErrorType.eraseError);
        }
        break;
      case _cmdCodePageWriteOnly97:
        if (payload[6] == _cmdAckCmdDoneA4 && payload[5] == 0x01) {
          final double progress = (_address > _totalSize) ? 1.0 : _address / _totalSize;
          logD('parseReceiveOtaResult 写入成功: $_address, 进度: $progress');
          _onProgressChanged?.call((progress * 100).toInt());
          otaPageReadChecksum();
        } else {
          _otaFailure(JFOTAErrorType.writeError);
          logD('parseReceiveOtaResult 写入错误');
        }
        break;
      case _cmdCodePagesReadChecksum81:
        if (payload[6] == _cmdAckPagesCsFailA6 && payload[5] == 0x01) {
          logD('parseReceiveOtaResult 校验失败');
          _onFailure?.call(JFOTAErrorType.checkFail);
        } else if (payload[6] == _cmdAckPagesCsTrueA5 && payload[5] == 0x01) {
          logD('parseReceiveOtaResult 校验成功: $_address, $_totalSize');
          if (_fileData == null) return;
          _address += 128;
          if (_address < _totalSize) {
            otaWritePage();
          } else {
            logD('parseReceiveOtaResult 升级成功');
            _address = 0;
            _onSuccess?.call();
          }
        } else {
          logD('parseReceiveOtaResult 校验错误');
          _otaFailure(JFOTAErrorType.checkFail);
        }
        break;
      default:
        break;
    }
  }

  _otaFailure(JFOTAErrorType type) {
    _onFailure?.call(type);
  }

  int get _totalSize => _fileData?.length ?? 0;

  int checksum(List<int> bytes) {
    logD('checksum: ${bytes.toHex()}');
    int crc = 0xFF;
    for (int i = 0; i < bytes.length; i++) {
      crc = crc ^ (bytes[i]);
    }
    return crc;
  }

  int sumA7Packet(Uint8List bytes) {
    int sum = 0;
    for (int i = 1; i < bytes.length - 2; i++) {
      sum += bytes[i];
    }
    return sum;
  }
}
