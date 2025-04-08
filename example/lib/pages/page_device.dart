import 'dart:async';

import 'package:ailink/ailink.dart';
import 'package:ailink/impl/elink_common_data_parse_callback.dart';
import 'package:ailink/utils/ble_common_util.dart';
import 'package:ailink/utils/common_extensions.dart';
import 'package:ailink/utils/elink_cmd_utils.dart';
import 'package:ailink/utils/elink_common_cmd_utils.dart';
import 'package:ailink/utils/elink_common_data_parse_utils.dart';
import 'package:elink_health_ring/utils/elink_health_ring_checkup_callback.dart';
import 'package:elink_health_ring/utils/elink_health_ring_cmd_utils.dart';
import 'package:elink_health_ring/utils/elink_health_ring_common_callback.dart';
import 'package:elink_health_ring/utils/elink_health_ring_data_parse_utils.dart';
import 'package:elink_health_ring/utils/elink_health_ring_config.dart';
import 'package:elink_health_ring/utils/elink_health_ring_sleep_step_callback.dart';
import 'package:elink_health_ring/utils/jf_ota_utils.dart';
import 'package:elink_health_ring/utils/log_utils.dart';
import 'package:elink_health_ring_example/model/connect_device_model.dart';
import 'package:elink_health_ring_example/model/log_info.dart';
import 'package:elink_health_ring_example/utils/constants.dart';
import 'package:elink_health_ring_example/utils/extensions.dart';
import 'package:elink_health_ring_example/widgets/dialog_utils.dart';
import 'package:elink_health_ring_example/widgets/widget_ble_state.dart';
import 'package:elink_health_ring_example/widgets/widget_operate_btn.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class PageDevice extends StatefulWidget {
  const PageDevice({super.key});

  @override
  State<PageDevice> createState() => _PageDeviceState();
}

class _PageDeviceState extends State<PageDevice> {
  final logList = <LogInfo>[];
  bool _isReplyHandShake = false;
  bool _isCheckHandShake = false;

  final ScrollController _controller = ScrollController();

  BluetoothDevice? _bluetoothDevice;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _onReceiveDataSubscription;
  StreamSubscription<List<int>>? _onReceiveDataSubscription1;

  BluetoothCharacteristic? _dataA7Characteristic;
  BluetoothCharacteristic? _dataA6Characteristic;

  late ElinkCommonDataParseUtils _elinkCommonDataParseUtils;
  late ElinkHealthRingCmdUtils _elinkHealthRingCmdUtils;
  late ElinkHealthRingDataParseUtils _elinkHealthRingDataParseUtils;
  late JFOTAUtils _jfotaUtils;

  DateTime? syncTime;

  @override
  void initState() {
    super.initState();
    // _addLog('initState');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addLog('addPostFrameCallback');
      _init();
      _connectionStateSubscription =
          _bluetoothDevice?.connectionState.listen((state) {
            if (state.isConnected) {
              _addLog('Connected');
              _bluetoothDevice?.discoverServices().then((services) {
                _addLog('DiscoverServices success: ${services.map((e) => e.serviceUuid).join(',').toUpperCase()}');
                if (services.isNotEmpty) {
                  _setNotify(services);
                }
              }, onError: (error) {
                _addLog('DiscoverServices error');
              });
            } else {
              _dataA6Characteristic = null;
              _dataA7Characteristic = null;
              _isReplyHandShake = false;
              _isCheckHandShake = false;
              _addLog('Disconnected: code(${_bluetoothDevice?.disconnectReason?.code}), desc(${_bluetoothDevice?.disconnectReason?.description})');
            }
          });
      _bluetoothDevice?.connect();
    });

    _elinkCommonDataParseUtils = ElinkCommonDataParseUtils();
    _elinkCommonDataParseUtils.setElinkCommonDataParseCallback(ElinkCommonDataParseCallback((version) {
      _addLog('onGetBmVersion: $version');
    }));
  }

  void _init() {
    final connectDeviceModel = ModalRoute.of(context)?.settings.arguments as ConnectDeviceModel;
    final bleData = connectDeviceModel.bleData;
    _bluetoothDevice = connectDeviceModel.device;
    _jfotaUtils = JFOTAUtils(bleData.macArr, cid: bleData.cidArr);
    _jfotaUtils.setListener(
      onStartSuccess: (size) async {
        final data = await _jfotaUtils.eraseAll(size);
        _sendA7Data(data);
      },
      onOtaPageWrite: (data, address) async {
        final result = await _jfotaUtils.pageWrite(data, address);
        _sendA7Data(result);
      },
      onOtaPageReadChecksum: (sum, address) async {
        final data = await _jfotaUtils.pageReadChecksum(sum, address);
        _sendA7Data(data);
      },
      onFailure: (type) async {
        _addLog('onSensorOtaFailure: $type');
        final data = await _jfotaUtils.endOTA();
        _sendA7Data(data);
      },
      onSuccess: () async {
        _addLog('onSensorOtaSuccess');
        final data = await _jfotaUtils.endOTA();
        _sendA7Data(data);
      },
      onProgressChanged: (progress) {
        _addLog('onSensorOtaProgressChanged: $progress');
      },
    );
    _elinkHealthRingCmdUtils = ElinkHealthRingCmdUtils(bleData.macArr, cid: bleData.cidArr);
    _elinkHealthRingDataParseUtils = ElinkHealthRingDataParseUtils(bleData.macArr, cid: bleData.cidArr);
    _elinkHealthRingDataParseUtils.setCallback(
      commonCallback: ElinkHealthRingCommonCallback(
        onDeviceStatusChanged: (status) {
          _addLog('DeviceStatus: $status');
        },
        onGetSensorVersion: (version) {
          _addLog('SensorVersion: $version');
        },
        onSetUnixTimeResult: (result) {
          _addLog('SyncUnitTimeResult: $result');
        },
        onSyncBleTimeResult: (result) {
          _addLog('SyncBleTimeResult: $result');
        }
      ),
      checkupCallback: ElinkHealthRingCheckupCallback(
        onStartCheckup: (success) {
          _addLog('onStartCheckup: $success');
        },
        onStopCheckup: (success) {
          _addLog('onStopCheckup: $success');
        },
        onGetRealtimeData: (data) {
          _addLog('onGetRealtimeData: $data');
        },
        onGetCheckupPackets: (data) {
          _addLog('onGetCheckupPackets: ${data.toHex()}');
        },
        onGetCheckupDuration: (duration) {
          _addLog('onGetCheckupDuration: ${duration}mins');
        },
        onGetCheckupHistory: (list, total, sentCount) {
          _addLog('onGetCheckupHistory: total: $total, sentCount: $sentCount, list: ${list.join(',')}');
        },
        onGetAutoCheckupStatus: (open) {
          _addLog('onGetAutoCheckupStatus: $open');
        },
        onGetCheckupType: (type) {
          _addLog('onGetCheckupType: $type');
        },
        onNotifyCheckupHistoryGenerated: () {
          _addLog('onNotifyCheckupHistoryGenerated');
        },
      ),
      sleepStepCallback: ElinkHealthRingSleepStepCallback(
        onGetCheckDuration: (duration) {
          _addLog('onGetSleepAndStepCheckDuration: ${duration}mins');
        },
        onGetSleepAndStepHistory: (list, total, sentCount) {
          _addLog('onGetSleepAndStepHistory: total: $total, sentCount: $sentCount, list: ${list.join(',')}');
        },
        onNotifySleepAndStepHistoryGenerated: () {
          _addLog('onNotifySleepAndStepHistoryGenerated');
        },
        onGetSleepCheckState: (open) {
          _addLog('onGetSleepCheckState: $open');
        },
        onGetStepCheckState: (open) {
          _addLog('onGetStepCheckState: $open');
        },
      ),
      jfotaUtils: _jfotaUtils,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _bluetoothDevice?.advName ?? 'Unknown',
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
            StreamBuilder<BluetoothConnectionState>(
              initialData: BluetoothConnectionState.disconnected,
              stream: _bluetoothDevice?.connectionState,
              builder: (context, snapshot) {
                final state = snapshot.data ?? BluetoothConnectionState.disconnected;
                return Text(
                  state.isConnected ? 'Connected' : 'Disconnected',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                );
              },
            )
          ],
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
        ),
        actions: [
          BleStateWidget(
            bluetoothDevice: _bluetoothDevice,
            onPressed: () {
              _bluetoothDevice?.connect();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 220,
            child: SingleChildScrollView(
              physics: ClampingScrollPhysics(),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OperateBtnWidget(
                    onPressed: () => _getBmVersion(),
                    title: 'BmVersion',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getJFSensorInfo();
                      await _sendA7Data(data);
                    },
                    title: 'SensorVersion',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getDeviceState();
                      await _sendA7Data(data);
                    },
                    title: 'DeviceState',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      syncTime ??= DateTime.now();
                      final data = _elinkHealthRingCmdUtils.syncUnixTime(syncTime!);
                      await _sendA6Data(data);
                    },
                    title: 'SyncUnixTime',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      syncTime ??= DateTime.now();
                      final data = _elinkHealthRingCmdUtils.syncBleTime(syncTime!);
                      await _sendA6Data(data);
                    },
                    title: 'SyncBleTime',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getAutoCheckState();
                      await _sendA7Data(data);
                    },
                    title: 'AutoCheckState',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.openAutoCheck();
                      await _sendA7Data(data);
                    },
                    title: 'OpenAutoCheck',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.closeAutoCheck();
                      await _sendA7Data(data);
                    },
                    title: 'CloseAutoCheck',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getCheckupType();
                      await _sendA7Data(data);
                    },
                    title: 'CheckupType',
                  ),
                  OperateBtnWidget(
                    onPressed: () => showListDialog(
                      context: context,
                      dataList: ['Fast', 'Complex'],
                      title: 'SetCheckupType',
                      onSelected: (type, index) async {
                        final checkupType = index == 0 ? ElinkCheckupType.fast : ElinkCheckupType.complex;
                        final data = await _elinkHealthRingCmdUtils.setCheckupType(checkupType);
                        await _sendA7Data(data);
                      },
                    ),
                    title: 'SetCheckupType',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getCheckupDuration();
                      await _sendA7Data(data);
                    },
                    title: 'CheckupDuration',
                  ),
                  OperateBtnWidget(
                    onPressed: () => showListDialog(
                      context: context,
                      dataList: [15, 30, 45, 60],
                      title: 'SetCheckupDuration',
                      unit: 'mins',
                      onSelected: (duration, index) {
                        _elinkHealthRingCmdUtils.setCheckupDuration(duration).then((value) {
                          _sendA7Data(value);
                        });
                      },
                    ),
                    title: 'SetCheckupDuration',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.startCheckup();
                      await _sendA7Data(data);
                    },
                    title: 'StartCheckup',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.stopCheckup();
                      await _sendA7Data(data);
                    },
                    title: 'StopCheckup',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getCheckupHistory();
                      await _sendA7Data(data);
                    },
                    title: 'CheckupHistory',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getNextCheckupHistory();
                      await _sendA7Data(data);
                    },
                    title: 'CheckupNextHistory',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getCheckupHistoryOver();
                      await _sendA7Data(data);
                    },
                    title: 'CheckupHistoryOver',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.deleteCheckupHistory();
                      await _sendA7Data(data);
                    },
                    title: 'DeleteCheckupHistory',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getSleepAndStepDuration();
                      await _sendA7Data(data);
                    },
                    title: 'SleepAndStepDuration',
                  ),
                  OperateBtnWidget(
                    onPressed: () => showListDialog(
                      context: context,
                      dataList: [5, 10, 15, 20],
                      title: 'SetSleepStepDuration',
                      unit: 'mins',
                      onSelected: (duration, index) {
                        _elinkHealthRingCmdUtils.setSleepAndStepDuration(duration).then((value) {
                          _sendA7Data(value);
                        });
                      },
                    ),
                    title: 'SetSleepDuration',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getSleepCheckState();
                      await _sendA7Data(data);
                    },
                    title: 'SleepCheckState',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.openSleepCheck();
                      await _sendA7Data(data);
                    },
                    title: 'OpenSleepCheck',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.closeSleepCheck();
                      await _sendA7Data(data);
                    },
                    title: 'CloseSleepCheck',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getStepCheckState();
                      await _sendA7Data(data);
                    },
                    title: 'StepCheckState',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.openStepCheck();
                      await _sendA7Data(data);
                    },
                    title: 'OpenStepCheck',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.closeStepCheck();
                      await _sendA7Data(data);
                    },
                    title: 'CloseStepCheck',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getSleepAndStepHistory();
                      await _sendA7Data(data);
                    },
                    title: 'SleepHistory',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getNextSleepAndStepHistory();
                      await _sendA7Data(data);
                    },
                    title: 'SleepNextHistory',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.getSleepAndStepHistoryOver();
                      await _sendA7Data(data);
                    },
                    title: 'SleepHistoryOver',
                  ),
                  OperateBtnWidget(
                    onPressed: () async {
                      final data = await _elinkHealthRingCmdUtils.deleteSleepAndStepHistory();
                      await _sendA7Data(data);
                    },
                    title: 'DeleteSleepHistory',
                  ),
                  OperateBtnWidget(
                    onPressed: () => showListDialog(
                      context: context,
                      dataList: [sensroOtaFile1, sensroOtaFile2],
                      title: 'ChooseSensorOtaFile',
                      onSelected: (fileName, index) {
                        loadFile('assets/sensor/$fileName').then((value) async {
                          logD('OTA文件长度: ${value.length}');
                          _jfotaUtils.setFileData(value);
                          final startOta = await _jfotaUtils.startOTA();
                          _sendA7Data(startOta);
                        });
                      },
                    ),
                    title: 'SensorOTA',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: _controller,
              itemBuilder: (context, index) {
                final logInfo = logList[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Text(
                    '${logInfo.time}: \n${logInfo.message}',
                    style: TextStyle(
                      color: index % 2 == 0 ? Colors.black : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) {
                return const Divider(
                  height: 0.5,
                  color: Colors.grey,
                );
              },
              itemCount: logList.length,
            ),
          )
        ],
      ),
    );
  }

  void _setNotify(List<BluetoothService> services) async {
    final service = services.firstWhere((service) => service.serviceUuid.str.equal(ElinkBleCommonUtils.elinkConnectDeviceUuid));
    _addLog('_setNotify characteristics: ${service.characteristics.map((e) => e.uuid).join(',').toUpperCase()}');
    for (var characteristic in service.characteristics) {
      if (characteristic.uuid.str.equal(ElinkBleCommonUtils.elinkNotifyUuid) ||
          characteristic.uuid.str.equal(ElinkBleCommonUtils.elinkWriteAndNotifyUuid)) {
        _addLog('_setNotify characteristics uuid: ${characteristic.uuid}');
        await characteristic.setNotifyValue(true);
        if (characteristic.uuid.str.equal(ElinkBleCommonUtils.elinkWriteAndNotifyUuid)) {
          _onReceiveDataSubscription = characteristic.onValueReceived.listen((data) async {
            _addLog('OnValueReceived [${characteristic.uuid.str}]: ${data.toHex()}, checked: ${ElinkCmdUtils.checkElinkCmdSum(data)}');
            if (ElinkBleCommonUtils.isSetHandShakeCmd(data)) {
              _replyHandShake(data);
            } else if (ElinkBleCommonUtils.isGetHandShakeCmd(data)) {
              Future.delayed(const Duration(milliseconds: 500), () async {
                if (_isCheckHandShake) return;
                final handShakeStatus = await Ailink().checkHandShakeStatus(Uint8List.fromList(data));
                _addLog('handShakeStatus: $handShakeStatus');
                _isCheckHandShake = true;
              });
            } else {
              _elinkCommonDataParseUtils.parseElinkCommonData(data);
              await _elinkHealthRingDataParseUtils.parseElinkData(Uint8List.fromList(data));
            }
          });
          _dataA6Characteristic = characteristic;
          await _setHandShake();
        } else if (characteristic.uuid.str.equal(ElinkBleCommonUtils.elinkNotifyUuid)) {
          _onReceiveDataSubscription1 = characteristic.onValueReceived.listen((data) async {
            _addLog('OnValueReceived [${characteristic.uuid.str}]: ${data.toHex()}, checked: ${ElinkCmdUtils.checkElinkCmdSum(data)}');
            if (ElinkCmdUtils.isElinkA7Data(data)) {
              final replyData = await _elinkHealthRingCmdUtils.replyDevice();
              _sendA7Data(replyData);
            }
            await _elinkHealthRingDataParseUtils.parseElinkData(Uint8List.fromList(data));
          });
        }
      } else if (characteristic.uuid.str.equal(ElinkBleCommonUtils.elinkWriteUuid)) {
        _dataA7Characteristic = characteristic;
      }
    }
  }

  Future<void> _setHandShake() async {
    Uint8List data = (await Ailink().initHandShake()) ?? Uint8List(0);
    _addLog('_setHandShake: ${data.toHex()}');
    await _sendA6Data(data);
  }

  Future<void> _replyHandShake(List<int> data) async {
    if (_isReplyHandShake) return;
    Uint8List replyData = (await Ailink().getHandShakeEncryptData(Uint8List.fromList(data))) ?? Uint8List(0);
    _addLog('_replyHandShake: ${replyData.toHex()}');
    await _sendA6Data(data);
    _isReplyHandShake = true;
  }

  Future<void> _getBmVersion() async {
    final data = ElinkCommonCmdUtils.getElinkBmVersion();
    _addLog('_getBmVersion: ${data.toHex()}');
    await _sendA6Data(data);
  }

  Future<void> _sendA6Data(List<int> data) async {
    await _dataA6Characteristic?.write(data, withoutResponse: true);
  }

  Future<void> _sendA7Data(List<int> data) async {
    await _dataA7Characteristic?.write(data, withoutResponse: true);
  }

  void _addLog(String log) {
    if (mounted) {
      setState(() {
        logList.insert(0, LogInfo(DateTime.now(), log));
      });
    }
  }

  Future<Uint8List> loadFile(String path) async {
    final byteData = await rootBundle.load(path);
    return byteData.buffer.asUint8List();
  }

  @override
  void dispose() {
    _bluetoothDevice?.disconnect();
    _bluetoothDevice = null;
    _dataA6Characteristic = null;
    _dataA6Characteristic = null;
    _isReplyHandShake = false;
    _isCheckHandShake = false;
    _controller.dispose();
    _onReceiveDataSubscription?.cancel();
    _onReceiveDataSubscription1?.cancel();
    _connectionStateSubscription?.cancel();
    super.dispose();
  }
}
