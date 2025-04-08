import 'dart:async';
import 'dart:typed_data';

import 'package:ailink/impl/elink_common_data_parse_callback.dart';
import 'package:ailink/utils/ble_common_util.dart';
import 'package:ailink/utils/common_extensions.dart';
import 'package:ailink/utils/elink_cmd_utils.dart';
import 'package:ailink/utils/elink_common_cmd_utils.dart';
import 'package:ailink/utils/elink_common_data_parse_utils.dart';
import 'package:elink_health_ring/utils/elink_health_ring_checkup_callback.dart';
import 'package:elink_health_ring/utils/elink_health_ring_cmd_utils.dart';
import 'package:elink_health_ring/utils/elink_health_ring_commom_callback.dart';
import 'package:elink_health_ring/utils/elink_health_ring_data_parse_utils.dart';
import 'package:elink_health_ring/utils/elink_health_ring_sleep_step_callback.dart';
import 'package:elink_health_ring_example/model/connect_device_model.dart';
import 'package:elink_health_ring_example/model/log_info.dart';
import 'package:elink_health_ring_example/utils/extensions.dart';
import 'package:elink_health_ring_example/widgets/widget_ble_state.dart';
import 'package:elink_health_ring_example/widgets/widget_operate_btn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class PageDevice extends StatefulWidget {
  const PageDevice({super.key});

  @override
  State<PageDevice> createState() => _PageDeviceState();
}

class _PageDeviceState extends State<PageDevice> {
  final logList = <LogInfo>[];
  int _checkupDuration = 30;
  int _sleepAndStepCheckDuration = 5;

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
    _elinkHealthRingCmdUtils = ElinkHealthRingCmdUtils(bleData.macArr, cid: bleData.cidArr);
    _elinkHealthRingDataParseUtils = ElinkHealthRingDataParseUtils(bleData.macArr, cid: bleData.cidArr);
    _elinkHealthRingDataParseUtils.setCallback(
      commonCallback: ElinkHealthRingCommomCallback(
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
          _addLog('onGetCheckupHistory: total: $total, count: $sentCount, list: ${list.join(',')}');
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
          _addLog('onGetSleepAndStepHistory: total: $total, count: $sentCount, list: ${list.join(',')}');
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
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
                    onPressed: () async {
                      if (_dataA6Characteristic != null) {
                        _getBmVersion(_dataA6Characteristic!);
                      }
                    },
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
                    title: 'SyncUnitTime',
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
                      final data = await _elinkHealthRingCmdUtils.getCheckupDuration();
                      await _sendA7Data(data);
                    },
                    title: 'CheckupDuration',
                  ),
                  DropdownButton<int>(
                    value: _checkupDuration,
                    items: [15, 30, 45, 60].map((e) {
                      return DropdownMenuItem<int>(
                        value: e,
                        child: Text(
                          '${e}mins',
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    }).toList(),
                    onChanged: (duration) {
                      setState(() {
                        _checkupDuration = duration!;
                      });
                      _elinkHealthRingCmdUtils.setCheckupDuration(duration!).then((value) {
                        _sendA7Data(value);
                      });
                    },
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
                  DropdownButton<int>(
                    value: _sleepAndStepCheckDuration,
                    items: [5, 10, 15, 20].map((e) {
                      return DropdownMenuItem<int>(
                        value: e,
                        child: Text(
                          '${e}mins',
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    }).toList(),
                    onChanged: (duration) {
                      setState(() {
                        _sleepAndStepCheckDuration = duration!;
                      });
                      _elinkHealthRingCmdUtils.setSleepAndStepDuration(duration!).then((value) {
                        _sendA7Data(value);
                      });
                    },
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
            _elinkCommonDataParseUtils.parseElinkCommonData(data);
            await _elinkHealthRingDataParseUtils.parseElinkData(Uint8List.fromList(data));
          });
          _dataA6Characteristic = characteristic;
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

  Future<void> _getBmVersion(BluetoothCharacteristic characteristic) async {
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

  @override
  void dispose() {
    _bluetoothDevice?.disconnect();
    _bluetoothDevice = null;
    _dataA6Characteristic = null;
    _dataA6Characteristic = null;
    _controller.dispose();
    _onReceiveDataSubscription?.cancel();
    _onReceiveDataSubscription1?.cancel();
    _connectionStateSubscription?.cancel();
    super.dispose();
  }
}
