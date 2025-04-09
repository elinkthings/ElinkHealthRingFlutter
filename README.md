# elink_health_ring

##[中文](README_CN.md)

Elink Health Ring Flutter library.

## Prerequisites

1. Have obtained the Elink Bluetooth communication protocol
2. Have a smart device that supports the Elink Bluetooth module
3. Have Flutter development and debugging knowledge

## Android

1. Add in android/build.gradle file```maven { url 'https://jitpack.io' }```
```
    allprojects {
        repositories {
            google()
            mavenCentral()
            //add
            maven { url 'https://jitpack.io' }
        }
    }
```

2. Set in android/app/build.gradle file```minSdkVersion 21```
```
    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId "com.elinkthings.elink_health_ring_example"
        // You can update the following values to match your application needs.
        // For more information, see: https://docs.flutter.dev/deployment/android#reviewing-the-gradle-build-configuration.
        minSdkVersion 21 //flutter.minSdkVersion
        targetSdkVersion flutter.targetSdkVersion
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }
```

3. To use the flutter_blue_plus library, you need to add relevant permissions in the android/app/src/main/AndroidManifest.xml file
```
    <manifest xmlns:android="http://schemas.android.com/apk/res/android">
        <!-- Tell Google Play Store that your app uses Bluetooth LE
             Set android:required="true" if bluetooth is necessary -->
        <uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />

        <!-- New Bluetooth permissions in Android 12
        https://developer.android.com/about/versions/12/features/bluetooth-permissions -->
        <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
        <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

        <!-- legacy for Android 11 or lower -->
        <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
        <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
        <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>
    
        <!-- legacy for Android 9 or lower -->
        <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />
    <manifest xmlns:android="http://schemas.android.com/apk/res/android">
```

## iOS
1. To use the flutter_blue_plus library, you need to add relevant permissions in the ios/Runner/Info.plist file
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>NSBluetoothAlwaysUsageDescription</key>
        <string>This app always needs Bluetooth to function</string>
        <key>NSBluetoothPeripheralUsageDescription</key>
        <string>This app needs Bluetooth Peripheral to function</string>
        <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
        <string>This app always needs location and when in use to function</string>
        <key>NSLocationAlwaysUsageDescription</key>
        <string>This app always needs location to function</string>
        <key>NSLocationWhenInUseUsageDescription</key>
        <string>This app needs location when in use to function</string>
    </dict>
</plist>
```

## Flutter
### Health Ring Instructions
#### General instructions
```dart
  import 'package:elink_health_ring/utils/elink_health_ring_cmd_utils.dart';
  import 'package:ailink/utils/ble_common_util.dart';
  
  final elinkHealthRingCmdUtils = ElinkHealthRingCmdUtils(bleData.macArr, cid: bleData.cidArr); //macArr and cidArr are obtained from the broadcast
  BluetoothCharacteristic? _dataA7Characteristic; //Get after connecting the device ElinkBleCommonUtils.elinkWriteAndNotifyUuid
  BluetoothCharacteristic? _dataA6Characteristic; //Get after connecting the device ElinkBleCommonUtils.elinkWriteUuid

  Future<void> _sendA6Data(List<int> data) async {
    _dataA6Characteristic?.write(data, withoutResponse: true);
  }
    
  Future<void> _sendA7Data(List<int> data) async {
    _dataA7Characteristic?.write(data, withoutResponse: true);
  }
  
  //Each time you receive an A7 data command, you need to reply to the command to the device, otherwise the device cannot be used normally.
  final data = elinkHealthRingCmdUtils.replyDevice();
  _sendA7Data(data);
  
  //Get sensor version
  final data = elinkHealthRingCmdUtils.getJFSensorInfo();
  _sendA7Data(data);
  
  //Get device state
  final data = elinkHealthRingCmdUtils.getDeviceState();
  _sendA7Data(data);

  //Sync Unix time
  final data = elinkHealthRingCmdUtils.syncUnixTime(syncTime!);
  _sendA6Data(data);
  
  //Sync BLE time
  final data = elinkHealthRingCmdUtils.syncBleTime(syncTime!);
  _sendA6Data(data);
```
- <span style="color:red">**⚠️ WARNING:** The syncTime parameter of elinkHealthRingCmdUtils.syncUnixTime(syncTime) and elinkHealthRingCmdUtils.syncBleTime(syncTime) must use the same value</span>

#### Physical examination and automatic monitoring instructions
```dart
  //Get automatic monitoring status
  final data = elinkHealthRingCmdUtils.getAutoCheckState();
  _sendA7Data(data);

  //Enable automatic monitoring
  final data = elinkHealthRingCmdUtils.openAutoCheck();
  _sendA7Data(data);
  
  //Turn off automatic monitoring
  final data = elinkHealthRingCmdUtils.closeAutoCheck();
  _sendA7Data(data);

  //Get automatic monitoring time
  final data = elinkHealthRingCmdUtils.getCheckupDuration();
  _sendA7Data(data);

  //Set the automatic monitoring time
  final duration = 30;//Unit: Minutes
  final data = elinkHealthRingCmdUtils.setCheckupDuration(duration);
  _sendA7Data(data);
  
  //Query automatic monitoring type
  final data = elinkHealthRingCmdUtils.getCheckupType();
  _sendA7Data(data);

  //Set the automatic monitoring type
  final checkupType = index == 0 ? ElinkCheckupType.fast : ElinkCheckupType.complex;
  final data = elinkHealthRingCmdUtils.setCheckupType(checkupType);
  _sendA7Data(data);

  //Start the physical examination
  final data = elinkHealthRingCmdUtils.startCheckup();
  _sendA7Data(data);

  //End of physical examination
  final data = elinkHealthRingCmdUtils.stopCheckup();
  _sendA7Data(data);

  //Obtaining automatic monitoring historical data
  final data = elinkHealthRingCmdUtils.getCheckupHistory();
  _sendA7Data(data);

  //Get the next piece of automatic monitoring history data
  final data = elinkHealthRingCmdUtils.getNextCheckupHistory();
  _sendA7Data(data);
  
  //Get the automatic monitoring history data end
  final data = elinkHealthRingCmdUtils.getCheckupHistoryOver();
  _sendA7Data(data);
  
  //Delete automatic monitoring history data
  final data = elinkHealthRingCmdUtils.deleteCheckupHistory();
  _sendA7Data(data);
```
#### Sleep and step count instructions
```dart
  //Get sleep and step monitoring time
  final data = elinkHealthRingCmdUtils.getSleepAndStepDuration();
  _sendA7Data(data);

  //Get sleep and step monitoring time
  final duration = 5; //单位分钟
  final data = elinkHealthRingCmdUtils.setSleepAndStepDuration(duration);
  _sendA7Data(data);

  //Get sleep detection status
  final data = elinkHealthRingCmdUtils.getSleepCheckState();
  _sendA7Data(data);
  
  //Turn on sleep detection
  final data = elinkHealthRingCmdUtils.openSleepCheck();
  _sendA7Data(data);
  
  //Turn off sleep detection
  final data = elinkHealthRingCmdUtils.closeSleepCheck();
  _sendA7Data(data);
  
  //Get the step detection status
  final data = elinkHealthRingCmdUtils.getStepCheckState();
  _sendA7Data(data);
  
  //Turn on step detection
  final data = elinkHealthRingCmdUtils.openStepCheck();
  _sendA7Data(data);
  
  //Turn off step detection
  final data = elinkHealthRingCmdUtils.closeStepCheck();
  _sendA7Data(data);

  //Get sleep and step history data
  final data = elinkHealthRingCmdUtils.getSleepAndStepHistory();
  _sendA7Data(data);
  
  //Get the next page of sleep and step history data
  final data = elinkHealthRingCmdUtils.getNextSleepAndStepHistory();
  _sendA7Data(data);
  
  //Get sleep and step history data ended
  final data = elinkHealthRingCmdUtils.getSleepAndStepHistoryOver();
  _sendA7Data(data);

  //Delete sleep and step history data
  final data = elinkHealthRingCmdUtils.deleteSleepAndStepHistory();
  _sendA7Data(data);
```
#### Sensor OTA Commands
```dart
  import 'package:elink_health_ring/utils/jf_ota_utils.dart';
  JFOTAUtils jfotaUtils = JFOTAUtils(bleData.macArr, cid: bleData.cidArr); //macArr and cidArr are obtained from the broadcast

  //Set OTA file data and start OTA
  final Uint8List fileData; 
  _jfotaUtils.setFileData(fileData);
  final startOta = _jfotaUtils.startOTA();
  _sendA7Data(startOta);
  
  //Wipe Data
  final data = _jfotaUtils.eraseAll(size);
  _sendA7Data(data);
  
  //Writing Data
  final result = _jfotaUtils.pageWrite(data, address);
  _sendA7Data(result);

  //Verify data and
  final data = _jfotaUtils.pageReadChecksum(sum, address);
  _sendA7Data(data);
  
  //End OTA
  final data = _jfotaUtils.endOTA();
  _sendA7Data(data);
```
- <span style="color:red">**⚠️ WARNING:** Do not interrupt the operation during the sensor OTA process, as it may cause the device to become unusable.</span>
#### BLE OTA
```dart
  import 'package:elink_health_ring/utils/ota/dialog_ota_listener.dart';
  import 'package:elink_health_ring/utils/ota/dialog_ota_manager.dart';
  
  final DialogOtaManager _dialogOtaManager = DialogOtaManager();

  //1. After the device is successfully connected and the service is discovered, call _dialogOtaManager.setServices(services);
  _bluetoothDevice?.discoverServices().then((services) {
    _dialogOtaManager.setServices(services);
  }, onError: (error) {
  });
  
  //2. Set OTA file data and start OTA
  final Uint8List fileData;
  _dialogOtaManager.setDataAndStart(fileData, listener: this);

  abstract class DialogOtaListener {
    void onOtaSuccess();  //OTA upgrade completed
    
    void onOtaFailure(int code, String msg);  //OTA upgrade failed code: error code msg: error message
    
    void onOtaProgress(double progress);  //OTA upgrade progress 0-100
  }
```
- <span style="color:red">**⚠️ WARNING:** After the Bluetooth OTA is successful, the device will restart. If you do not receive the device's broadcast, please use the charger to activate the device.</span>

### Health Ring Reporting Instructions
#### General command callback
```dart
  import 'package:elink_health_ring/utils/elink_health_ring_data_parse_utils.dart';
  import 'package:elink_health_ring/utils/elink_health_ring_common_callback.dart';
  
  ElinkHealthRingDataParseUtils elinkHealthRingDataParseUtils = ElinkHealthRingDataParseUtils(bleData.macArr, cid: bleData.cidArr);
  elinkHealthRingDataParseUtils.setCallback(
    commonCallback: ElinkHealthRingCommonCallback(
      onDeviceStatusChanged: (status) { //Device State ElinkHealthRingStatus
      },
      onGetSensorVersion: (version) { //Sensor version
      },
      onSetUnixTimeResult: (result) { //Set the Unix time result, true: success, false: failure
      },
      onSyncBleTimeResult: (result) { //Set the BLE time result, true: success, false: failure
      }
    ),
  );
```
#### Automatic monitoring and physical examination instruction callback
```dart
  elinkHealthRingDataParseUtils.setCallback(
    checkupCallback: ElinkHealthRingCheckupCallback(
      onStartCheckup: (success) { //Start physical examination, true: success, false: failure
      },
      onStopCheckup: (success) { //End physical examination, true: success, false: failure
      },
      onGetRealtimeData: (data) { //Real-time physical examination data ElinkCheckupRealtimeData
      },
      onGetCheckupPackets: (data) { //Physical examination package List<int> 
      },
      onGetCheckupDuration: (duration) { //Automatic monitoring cycle, unit: minutes
      },
      onGetCheckupHistory: (list, total, sentCount) { //Automatic monitoring history, list: List<ElinkCheckupHistoryData>, total: total number of records, sentCount: number of sent records
      },
      onGetAutoCheckupStatus: (open) { //Automatically monitor the switch status, true: on, false: off
      },
      onGetCheckupType: (type) { //Automatic monitoring type，ElinkCheckupType
      },
      onNotifyCheckupHistoryGenerated: () { //Automatic monitoring record generation notification
      },
    ),
  );
```
#### Sleep and step count command callbacks
```dart
  elinkHealthRingDataParseUtils.setCallback(
    sleepStepCallback: ElinkHealthRingSleepStepCallback(
      onGetCheckDuration: (duration) { //Sleep and step monitoring cycle, in minutes
      },
      onGetSleepAndStepHistory: (list, total, sentCount) {  //Sleep and step history, list: List<ElinkSleepAndStepData>, total: total number of records, sentCount: number of records sent
      },
      onNotifySleepAndStepHistoryGenerated: () {  //Sleep and step count log generation notifications
      },
      onGetSleepCheckState: (open) {  //Sleep monitoring status, true: on, false: off
      },
      onGetStepCheckState: (open) {  //Step monitoring status, true: on, false: off
      },
    ),
  );
```
#### Sensor OTA callback
```dart
    final _jfotaUtils = JFOTAUtils(bleData.macArr, cid: bleData.cidArr);
    elinkHealthRingDataParseUtils.setCallback(jfotaUtils: _jfotaUtils) //Set JFOTAUtils to process the chip OTA instructions reported by the device

    _jfotaUtils.setListener(
      onStartSuccess: (size) async { //Start chip OTA successfully, clear data automatically
        final data = _jfotaUtils.eraseAll(size);
        _sendA7Data(data);
      },
      onOtaPageWrite: (data, address) async { //Actively write data
        final result = _jfotaUtils.pageWrite(data, address);
        _sendA7Data(result);
      },
      onOtaPageReadChecksum: (sum, address) async { //Verify data and
        final data = _jfotaUtils.pageReadChecksum(sum, address);
        _sendA7Data(data);
      },
      onFailure: (type) async { //OTA failed, automatically terminate OTA
        final data = _jfotaUtils.endOTA();
        _sendA7Data(data);
      },
      onSuccess: () async { //OTA is successful, automatically end OTA
        final data = _jfotaUtils.endOTA();
        _sendA7Data(data);
      },
      onProgressChanged: (progress) { //OTA progress callback
      },
    );
```
### Common Class Description
#### ElinkCheckupHistoryData
```dart
  ElinkCheckupHistoryData(
    this.heartRate, //Heart rate
    this.spo, //Blood oxygen
    this.bk,  //Microcirculation
    this.sbp, //Systolic blood pressure (high pressure)
    this.dbp, //Diastolic blood pressure (low pressure)
    this.rr,  //Respiratory rate
    this.sdann,
    this.rmssd,
    this.nn50,
    this.pnn50,
    this.time,  //时间(毫秒)
    this.rri,
  );
```
#### ElinkCheckupRealtimeData
```dart
  ElinkCheckupRealtimeData(
    this.heartRate, //Heart rate
    this.bloodOxygen, //Blood oxygen
    this.heartList, //Heart rhythm
    this.rr,
    this.rri,
  );
```
#### ElinkHealthRingStatus
```dart
  ElinkHealthRingStatus(
    this.state, //Historical data status
    this.batteryLevel,  //Battery level
    this.isCharging,  //Whether charging
    this.wearingStatus, //Wearing status
  );
```
#### ElinkSleepAndStepData
```dart
  ElinkSleepAndStepData(
    this.time,  //Time (milliseconds)
    this.sleepState,  //Sleep state
    this.steps  //Number of steps
  );
```
#### ElinkCheckupType
```dart
  enum ElinkCheckupType { 
    fast, //Quick physical examination (excluding emotional value)
    complex, //Full physical examination
  }
```
#### ElinkHealthRingHistoryState
```dart
  enum ElinkHealthRingHistoryState {
    notReady, //Historical time is not ready (Unix time not obtained)
    processing, //Historical time is being processed (Unix time obtained, historical data being processed)
    ready, //Historical time is ready (only in this state can the device history be obtained)
  }
```
#### ElinkWearingStatus
```dart
  enum ElinkWearingStatus {
    unsupported, //Not supported
    notWearing, //Not wearing
    wearing, //Wearing
  }
```
#### 
```dart
  enum ElinkSleepState {
    awake, //awake
    rem, //rapid eye movement
    light, //light sleep
    deep, //deep sleep
  }
```

For specific usage, please refer to the example
