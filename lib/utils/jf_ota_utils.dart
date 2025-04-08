import 'dart:typed_data';

import 'package:ailink/utils/common_extensions.dart';
import 'package:ailink/utils/elink_cmd_utils.dart';
import 'package:elink_health_ring/utils/elink_health_ring_config.dart';
import 'package:elink_health_ring/utils/log_utils.dart';

enum JFOTAErrorType {
  startOtaFail, //进入OTA失败
  checkFail, //校验失败
  writeError, //写入错误
  eraseError, //擦除错误
}

/// 戒指芯片(惊帆)OTA
class JFOTAUtils {
  static const _cmdCodePageWriteOnly97 = 0x97;
  static const _cmdCodeAllErase98 = 0x98;
  static const _cmdCodePagesReadChecksum81 = 0x81;
  static const _cmdAckCmdDoneA4 = 0xA4;
  static const _cmdAckPagesCsTrueA5 = 0xA5;
  static const _cmdAckPagesCsFailA6 = 0xA6;

  int _address = 0;
  int _startOtaCount = 0;

  Uint8List? _fileData;

  Function(JFOTAErrorType type)? _onFailure;
  Function()? _onSuccess;
  Function(int progress)? _onProgressChanged;

  static JFOTAUtils? _instance;
  List<int> _mac;
  List<int> _cid;

  JFOTAUtils._(this._mac, this._cid);

  factory JFOTAUtils(
    List<int> mac, {
    List<int> cid = ElinkHealthRingConfig.cidHealthRing,
  }) {
    _instance ??= JFOTAUtils._(mac, cid);
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
    Function(JFOTAErrorType type)? onFailure,
    Function()? onSuccess,
    Function(int progress)? onProgressChanged,
  }) {
    _onFailure = onFailure;
    _onSuccess = onSuccess;
    _onProgressChanged = onProgressChanged;
  }

  Future<List<int>> _getElinkA7Data(List<int> data) {
    return ElinkCmdUtils.getElinkA7Data(_cid, _mac!, data);
  }

  void startOTA() {
    _getElinkA7Data([0x07, 0x01]);
  }

  void endOTA() {
    _getElinkA7Data([0x07, 0x02]);
  }

  void eraseAll(int size) {
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
    _getElinkA7Data(payload);
  }

  void _pageWrite(List<int> data, int address) {
    if (data.length != 128) return;
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
    _getElinkA7Data(payload);
  }

  void _pageReadChecksum(int pageChecksum, int address) {
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
    _getElinkA7Data(payload);
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
    _pageWrite(payload, _address);
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
    _pageReadChecksum(sum, _address);
  }

  void parseReceiveData(Uint8List payload) {
    if (payload[0] != 0x07) {
      return;
    }

    switch (payload[1]) {
      case 0x01:
        if (payload[2] == 0x00) {
          logD('parseReceiveData 进入OTA成功');
          _startOtaCount = 0;
          if (_fileData == null) return;
          eraseAll(_fileData!.length);
        } else {
          logD('parseReceiveData 进入OTA失败');
          if (_startOtaCount < 3) {
            startOTA();
          } else {
            _startOtaCount = 0;
            _otaFailure(JFOTAErrorType.startOtaFail);
          }
        }
        break;
      case 0x02:
        if (payload[2] == 0x00) {
          _startOtaCount = 0;
          logD('parseReceiveData 退出OTA成功');
        } else {
          endOTA();
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
          endOTA();
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
            endOTA();
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
    endOTA();
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
