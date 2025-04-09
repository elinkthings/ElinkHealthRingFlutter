import 'dart:typed_data';

import 'package:ailink/utils/common_extensions.dart';
import 'package:ailink/utils/elink_cmd_utils.dart';
import 'package:elink_health_ring/utils/log_utils.dart';
import 'package:elink_health_ring/utils/ota/dialog_ota_config.dart';
import 'package:elink_health_ring/utils/ota/dialog_ota_listener.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DialogOtaManager {
  static DialogOtaManager? _instance;

  DialogOtaManager._() {
    FlutterBluePlus.events.onCharacteristicWritten.listen((event) {
      // logD('DialogOtaManager onCharacteristicWritten: ${event.characteristic.uuid.str} ${event.value.toHex()}');
      _onWriteDataOk(event.value, event.characteristic);
    });
    FlutterBluePlus.events.onCharacteristicReceived.listen((event) {
      if (event.characteristic.serviceUuid.str.toUpperCase().equal(DialogOtaConfig.serviceUuid)) {
        _onNotifyData(event.value);
      }
      // logD('DialogOtaManager onCharacteristicReceived: ${event.characteristic.uuid.str} ${event.value.toHex()}');
    });
    FlutterBluePlus.events.onDescriptorWritten.listen((event) {
      // logD('DialogOtaManager onDescriptorWritten: ${event.descriptor.characteristicUuid.str} ${event.value.toHex()}');
      if (event.descriptor.characteristicUuid.str.toUpperCase().equal(DialogOtaConfig.servStatusCharaUuid)) {
        _isCharaNotify = true;
      }
    });
  }

  factory DialogOtaManager() => _instance ??= DialogOtaManager._();

  BluetoothCharacteristic? _otaMemDevChara;
  BluetoothCharacteristic? _otaGpioMapChara;
  BluetoothCharacteristic? _otaPatchLenChara;
  BluetoothCharacteristic? _otaPatchDataChara;
  BluetoothCharacteristic? _otaServStatusChara;

  DialogOtaListener? _otaListener;
  Uint8List? _fileData;
  static const _fileChunkSize = 20;
  static const _fileBlockSize = 240;
  bool _isCharaNotify = false;

  /// 1,第几组(每组240byte);2,第几小组(240中的小组);3,内容(20byte)
  List<List<List<int>>>? blocks;

  int _numberOfBlocks = 0;

  static const memoryTypeExternalSpi = 0x13;
  static const int imageBank = 0;
  static const List<int> _endSignal = [0x00, 0x00, 0x00, 0xfe];
  static const List<int> _rebootSignal = [0x00, 0x00, 0x00, 0xfd];

  int _misoGpio = 0x05;
  int _mosiGpio = 0X06;
  int _csGpio = 0x03;
  int _sckGpio = 0x00;

  int get _fileSize => _fileData?.length ?? 0;

  void setServices(List<BluetoothService> services) {
    final otaService = services.where((element) => element.uuid.str.equal(DialogOtaConfig.serviceUuid)).firstOrNull;
    // logD('DialogOtaManager otaService characteristics: ${otaService?.characteristics.map((e) => e.uuid).join(',')}');
    otaService?.characteristics.forEach((characteristic) async {
      switch (characteristic.uuid.str.toUpperCase()) {
        case DialogOtaConfig.memDevCharaUuid:
          _otaMemDevChara = characteristic;
          break;
        case DialogOtaConfig.gpioMapCharaUuid:
          _otaGpioMapChara = characteristic;
          break;
        case DialogOtaConfig.patchLenCharaUuid:
          _otaPatchLenChara = characteristic;
          break;
        case DialogOtaConfig.patchDataCharaUuid:
          _otaPatchDataChara = characteristic;
          break;
        case DialogOtaConfig.servStatusCharaUuid:
          _otaServStatusChara = characteristic;
          final notifyResult = await characteristic.setNotifyValue(true);
          // logD('DialogOtaManager otaServStatusChara notifyResult: $notifyResult');
          break;
      }
    });
  }

  int _getCrc(Uint8List fileData) {
    int crcCode = 0;
    for (int i = 0; i < fileData.length; i++) {
      final value = fileData[i];
      crcCode = crcCode ^ value;
    }
    return crcCode & 0xFF;
  }

  void _initBlocksSuota() {
    blocks = List.generate(_numberOfBlocks, (_) => []);
    int byteOffset = 0;
    // Loop through all the bytes and split them into pieces the size of the default chunk size
    for (int i = 0; i < _numberOfBlocks; i++) {
      int blockSize = _fileBlockSize;
      if (i + 1 == _numberOfBlocks) {
        blockSize = _fileSize % _fileBlockSize;
      }
      final numberOfChunksInBlock = (blockSize / _fileChunkSize).ceil();
      int chunkNumber = 0;
      blocks![i] = List.generate(numberOfChunksInBlock, (_) => []);
      for (int j = 0; j < blockSize; j += _fileChunkSize) {
        // Default chunk size
        int chunkSize = _fileChunkSize;
        // Last chunk of all
        if (byteOffset + _fileChunkSize > _fileSize) {
          chunkSize = _fileSize - byteOffset;
        }
        // Last chunk in block
        else if (j + _fileChunkSize > blockSize) {
          chunkSize = _fileBlockSize % _fileChunkSize;
        }

        final chunk = _fileData!.sublist(byteOffset, byteOffset + chunkSize);
        blocks![i][chunkNumber] = chunk;
        byteOffset += chunkSize;
        chunkNumber++;
      }
    }
  }

  void setDataAndStart({
    required Uint8List fileData,
    DialogOtaType type = DialogOtaType.type585,
    DialogOtaListener? listener,
  }) {
    // logD('DialogOtaManager setDataAndStart: ${fileData.length}, $type');
    _reset();
    final crc = _getCrc(fileData);
    _fileData = Uint8List.fromList([...fileData, crc]);
    _numberOfBlocks = (_fileSize / _fileBlockSize).ceil();
    _otaListener = listener;
    _initOtaType(type);
    _initBlocksSuota();
    _setOtaMemDev();
  }

  void _reset() {
    // logD('DialogOtaManager _reset');
    _endSignalSent = false;
    _lastBlock = false;
    _preparedForLastBlock = false;
    _blockCounter = 0;
    _chunkCounter = -1;
    _hasError = false;
    _step = -1;
    _gpioMapPrereq = 0;
    _lastBlockSent = false;
  }

  void _initOtaType(DialogOtaType type) {
    // logD('DialogOtaManager _initOtaType: $type');
    switch (type) {
      case DialogOtaType.type531:
        _misoGpio = 0x03;
        _mosiGpio = 0X00;
        _csGpio = 0x01;
        _sckGpio = 0x04;
        break;
      case DialogOtaType.type580:
      case DialogOtaType.type585:
        _misoGpio = 0x05;
        _mosiGpio = 0X06;
        _csGpio = 0x03;
        _sckGpio = 0x00;
        break;
    }
  }

  ///写入OTA的升级包头//第一步
  void _setOtaMemDev() async {
    // logD('DialogOtaManager _setOtaMemDev');
    if (_isCharaNotify) {
      int memType = (memoryTypeExternalSpi << 24) | imageBank;
      final data = ElinkCmdUtils.intToBytes(memType);
      await _otaMemDevChara?.write(
        data,
        withoutResponse:
            _otaMemDevChara?.properties.writeWithoutResponse ?? false,
      );
    }
  }

  /// 0x05060300 when
  /// mem_type:        "External SPI" (0x13)
  /// MISO GPIO:       P0_5 (0x05)
  /// MOSI GPIO:       P0_6 (0x06)
  /// CS GPIO:         P0_3 (0x03)
  /// SCK GPIO:        P0_0 (0x00)
  /// image_bank:      "Oldest" (value: 0)
  int get _getMemParamsSPI =>
      (_misoGpio << 24) | (_mosiGpio << 16) | (_csGpio << 8) | _sckGpio;

  /// 写入OTA的升级包索引//第二步
  void _setOtaGpioMap() async {
    // logD('DialogOtaManager _setOtaGpioMap');
    final memInfoData = _getMemParamsSPI;
    final data = ElinkCmdUtils.intToBytes(memInfoData);
    await _otaGpioMapChara?.write(
      data,
      withoutResponse:
          _otaGpioMapChara?.properties.writeWithoutResponse ?? false,
    );
  }

  bool _endSignalSent = false;

  /// 发送OTA升级结束
  void _sendEndSignal() async {
    // logD('DialogOtaManager _sendEndSignal');
    if (_endSignalSent) return;
    _endSignalSent = true;
    await _otaMemDevChara?.write(
      _endSignal,
      withoutResponse:
          _otaMemDevChara?.properties.writeWithoutResponse ?? false,
    );
  }

  /// 发送重启指令
  void _reboot() async {
    // logD('DialogOtaManager _reboot');
    await _otaMemDevChara?.write(_rebootSignal);
  }

  /// 是否为最后一块
  bool _lastBlock = false;
  bool _preparedForLastBlock = false;

  /// 设置OTA升级包的文件大小和数据块信息//第三步
  void _setPatchLength() async {
    int blockSize = _fileBlockSize;
    if (_lastBlock) {
      blockSize = _fileSize % _fileBlockSize;
      _preparedForLastBlock = true;
    }
    // logD('DialogOtaManager _setPatchLength: $_fileSize, $blockSize');
    await _otaPatchLenChara?.write([blockSize & 0xFF]);
  }

  List<List<int>> _getBlock(int index) {
    return blocks == null ? [] : blocks![index];
  }

  int _blockCounter = 0;
  int _chunkCounter = -1;

  /// 最后一块是否已发送
  bool _lastBlockSent = false;

  /// 发送OTA升级包的数据块
  void _sendBlock() async {
    final progress = ((_blockCounter + 1) / _numberOfBlocks) * 100;
    if (!_lastBlockSent) {
      final block = _getBlock(_blockCounter);

      int i = ++_chunkCounter;
      bool lastChunk = false;
      if (_chunkCounter == block.length - 1) {
        _chunkCounter = -1;
        lastChunk = true;
      }
      final chunk = block[i];
      await _otaPatchDataChara?.write(
        chunk,
        withoutResponse:
            _otaPatchDataChara?.properties.writeWithoutResponse ?? false,
      );

      if (lastChunk) {
        if (!_lastBlock) {
          _blockCounter++;
        } else {
          _lastBlockSent = true;
        }
        if (_blockCounter + 1 == _numberOfBlocks) {
          _lastBlock = true;
        }
      }
    }
    _otaListener?.onOtaProgress(progress);
  }

  /// 错误后是否停止
  bool _hasError = false;

  /// OTA升级完成
  void _onSuccess() {
    // logD('DialogOtaManager _onSuccess');
    _otaListener?.onOtaSuccess();
    _reboot();
  }

  void _onError(int errorCode) {
    // logD('DialogOtaManager _onError: $errorCode');
    if (!_hasError) {
      final error = DialogOtaConfig.errorMap[errorCode];
      _otaListener?.onOtaFailure(errorCode, error ?? "unknown error");
      _hasError = true;
    }
  }

  int _step = -1;

  void _processMemDevValue(int memDevValue) {
    // logD('DialogOtaManager _processMemDevValue: $_step, $memDevValue');
    if (_step == 2) {
      if (memDevValue == 0x1) {
        _doStep(step: 3);
      } else {
        _onError(0);
      }
    }
  }

  int _gpioMapPrereq = 0;

  void _doStep({
    required int step,
    int error = -1,
    int memDevValue = -1,
  }) async {
    // logD('DialogOtaManager _doStep: $step, $error, $memDevValue');
    if (error != -1) {
      _onError(error);
    }
    if (memDevValue != -1) {
      _processMemDevValue(memDevValue);
    }
    if (step > 0) {
      _step = step;
    }
    switch (step) {
      case 0:
        _step = -1;
        break;
      case 1:
        await _otaServStatusChara?.setNotifyValue(true);
        break;
      case 2: // Init mem type
        _setOtaMemDev();
        break;
      case 3:
        // Set mem_type for SPOTA_GPIO_MAP_UUID
        // After setting SPOTAR_MEM_DEV and SPOTAR_IMG_STARTED notification is received,
        // we must set the GPIO map.
        // The order of the callbacks is unpredictable, so the notification may be
        // received before the write response.
        // We don't have a GATT operation queue, so the SPOTA_GPIO_MAP write will fail if
        // the SPOTAR_MEM_DEV hasn't finished yet.
        // Since this call is synchronized, we can wait for both broadcast intents from
        // the callbacks before proceeding.
        // The order of the callbacks doesn't matter with this implementation.
        if (++_gpioMapPrereq == 2) {
          _setOtaGpioMap();
        }
        break;
      case 4: // Set SPOTA_PATCH_LEN_UUID
        _setPatchLength();
        break;
      case 5:
        // Send a block containing blocks of 20 bytes until the patch length (default 240)
        // has been reached
        // Wait for response and repeat this action
        if (!_lastBlock) {
          _sendBlock();
        } else {
          if (!_preparedForLastBlock) {
            _setPatchLength();
          } else if (!_lastBlockSent) {
            _sendBlock();
          } else if (!_endSignalSent) {
            _sendEndSignal();
          } else if (error == -1) {
            _onSuccess();
          }
        }
        break;
    }
  }

  void _onWriteDataOk(List<int> value, BluetoothCharacteristic characteristic) {
    switch (characteristic.characteristicUuid.str.toUpperCase()) {
      case DialogOtaConfig.memDevCharaUuid:
        // logD('DialogOtaManager _onWriteDataOk memDevCharaUuid: ${value.toHex()}');
        _doStep(step: 3);
        break;
      case DialogOtaConfig.gpioMapCharaUuid:
        _doStep(step: 4);
        break;
      case DialogOtaConfig.patchLenCharaUuid:
        _doStep(step: 5);
        break;
      case DialogOtaConfig.patchDataCharaUuid:
        if (_chunkCounter != -1 && !_hasError) {
          _sendBlock();
        }
        break;
      case DialogOtaConfig.servStatusCharaUuid:
        break;
    }
  }

  void _onNotifyData(List<int> values) {
    final value = values.firstOrNull ?? -1;
    int step = -1;
    int error = -1;
    int memDevValue = -1;

    if (value == 0x10) {
      // Set memtype callback
      step = 3;
    } else if (value == 0x02) {
      // Successfully sent a block, send the next one
      step = 5;
    } else if (value == 0x03 || value == 0x01) {
      memDevValue = value;
    } else {
      error = value;
    }
    if (step >= 0 || error >= 0 || memDevValue >= 0) {
      _doStep(step: step, error: error, memDevValue: memDevValue);
    }
  }
}
