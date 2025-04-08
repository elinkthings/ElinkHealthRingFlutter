# elink_health_ring

##[English](README.md)

Elink健康戒指Flutter库.

## 必备条件

1. 已获取Elink蓝牙通讯协议
2. 拥有支持Elink蓝牙模块的智能设备
3. 具备Flutter开发和调试知识

## Android

1. 在android/build.gradle文件中添加```maven { url 'https://jitpack.io' }```
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

2. 在android/app/build.gradle文件中设置```minSdkVersion 21```
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

3. 使用flutter_blue_plus库, 需要在android/app/src/main/AndroidManifest.xml文件中添加相关权限
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
1. 使用flutter_blue_plus库, 需要在ios/Runner/Info.plist文件中添加相关权限
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
### 健康戒指指令
#### 通用指令
```dart
  import 'package:elink_health_ring/utils/elink_health_ring_cmd_utils.dart';
  import 'package:ailink/utils/ble_common_util.dart';
  
  final elinkHealthRingCmdUtils = ElinkHealthRingCmdUtils(bleData.macArr, cid: bleData.cidArr); //macArr和cidArr从广播中获取
  BluetoothCharacteristic? _dataA7Characteristic; //连接设备后获取 ElinkBleCommonUtils.elinkWriteAndNotifyUuid
  BluetoothCharacteristic? _dataA6Characteristic; //连接设备后获取 ElinkBleCommonUtils.elinkWriteUuid

  Future<void> _sendA6Data(List<int> data) async {
    _dataA6Characteristic?.write(data, withoutResponse: true);
  }
    
  Future<void> _sendA7Data(List<int> data) async {
    _dataA7Characteristic?.write(data, withoutResponse: true);
  }
  
  //每收到一条A7数据指令都需要回复该指令给设备，不然设备无法正常使用
  final data = elinkHealthRingCmdUtils.replyDevice();
  _sendA7Data(data);
  
  //获取传感器版本
  final data = elinkHealthRingCmdUtils.getJFSensorInfo();
  _sendA7Data(data);
  
  //获取设备状态
  final data = elinkHealthRingCmdUtils.getDeviceState();
  _sendA7Data(data);

  //同步unix时间
  final data = elinkHealthRingCmdUtils.syncUnixTime(syncTime!);
  _sendA6Data(data);
  
  //同步ble时间
  final data = elinkHealthRingCmdUtils.syncBleTime(syncTime!);
  _sendA6Data(data);
```
-  <font color="#FF0000">elinkHealthRingCmdUtils.syncUnixTime(syncTime)elinkHealthRingCmdUtils.syncBleTime(syncTime)的入参syncTime须使用同一个值</font>

#### 体检和自动监测指令
```dart
  //获取自动监测状态
  final data = elinkHealthRingCmdUtils.getAutoCheckState();
  _sendA7Data(data);

  //开启自动监测
  final data = elinkHealthRingCmdUtils.openAutoCheck();
  _sendA7Data(data);
  
  //关闭自动监测
  final data = elinkHealthRingCmdUtils.closeAutoCheck();
  _sendA7Data(data);

  //获自动监测时间
  final data = elinkHealthRingCmdUtils.getCheckupDuration();
  _sendA7Data(data);

  //设置自动监测时间
  final duration = 30;//单位分钟
  final data = elinkHealthRingCmdUtils.setCheckupDuration(duration);
  _sendA7Data(data);
  
  //查询自动监测类型
  final data = elinkHealthRingCmdUtils.getCheckupType();
  _sendA7Data(data);

  //设置自动监测类型
  final checkupType = index == 0 ? ElinkCheckupType.fast : ElinkCheckupType.complex;
  final data = elinkHealthRingCmdUtils.setCheckupType(checkupType);
  _sendA7Data(data);

  //开始体检
  final data = elinkHealthRingCmdUtils.startCheckup();
  _sendA7Data(data);

  //结束体检
  final data = elinkHealthRingCmdUtils.stopCheckup();
  _sendA7Data(data);

  //获取自动监测历史数据
  final data = elinkHealthRingCmdUtils.getCheckupHistory();
  _sendA7Data(data);

  //获取下一条自动监测历史数据
  final data = elinkHealthRingCmdUtils.getNextCheckupHistory();
  _sendA7Data(data);
  
  //获取自动监测历史数据结束
  final data = elinkHealthRingCmdUtils.getCheckupHistoryOver();
  _sendA7Data(data);
  
  //删除自动监测历史数据
  final data = elinkHealthRingCmdUtils.deleteCheckupHistory();
  _sendA7Data(data);
```
#### 睡眠和步数指令
```dart
  //获取睡眠和步数监测时间
  final data = elinkHealthRingCmdUtils.getSleepAndStepDuration();
  _sendA7Data(data);

  //设置睡眠和步数监测时间
  final duration = 5; //单位分钟
  final data = elinkHealthRingCmdUtils.setSleepAndStepDuration(duration);
  _sendA7Data(data);

  //获取睡眠检测状态
  final data = elinkHealthRingCmdUtils.getSleepCheckState();
  _sendA7Data(data);
  
  //开启睡眠检测
  final data = elinkHealthRingCmdUtils.openSleepCheck();
  _sendA7Data(data);
  
  //关闭睡眠检测
  final data = elinkHealthRingCmdUtils.closeSleepCheck();
  _sendA7Data(data);
  
  //获取步数检测状态
  final data = elinkHealthRingCmdUtils.getStepCheckState();
  _sendA7Data(data);
  
  //开启步数检测
  final data = elinkHealthRingCmdUtils.openStepCheck();
  _sendA7Data(data);
  
  //关闭步数检测
  final data = elinkHealthRingCmdUtils.closeStepCheck();
  _sendA7Data(data);

  //获取睡眠和步数历史数据
  final data = elinkHealthRingCmdUtils.getSleepAndStepHistory();
  _sendA7Data(data);
  
  //获取下一页睡眠和步数历史数据
  final data = elinkHealthRingCmdUtils.getNextSleepAndStepHistory();
  _sendA7Data(data);
  
  //获取睡眠和步数历史数据结束
  final data = elinkHealthRingCmdUtils.getSleepAndStepHistoryOver();
  _sendA7Data(data);

  //删除睡眠和步数历史数据
  final data = elinkHealthRingCmdUtils.deleteSleepAndStepHistory();
  _sendA7Data(data);
```
#### 传感器OTA指令
```dart
  import 'package:elink_health_ring/utils/jf_ota_utils.dart';
  JFOTAUtils jfotaUtils = JFOTAUtils(bleData.macArr, cid: bleData.cidArr); //macArr和cidArr从广播中获取

  //设置OTA文件数据和开始OTA
  final Uint8List fileData; 
  _jfotaUtils.setFileData(fileData);
  final startOta = _jfotaUtils.startOTA();
  _sendA7Data(startOta);
  
  //擦除数据
  final data = _jfotaUtils.eraseAll(size);
  _sendA7Data(data);
  
  //写入数据
  final result = _jfotaUtils.pageWrite(data, address);
  _sendA7Data(result);

  //校验数据和
  final data = _jfotaUtils.pageReadChecksum(sum, address);
  _sendA7Data(data);
  
  //结束OTA
  final data = _jfotaUtils.endOTA();
  _sendA7Data(data);
```
- <font color="#FF0000">传感器OTA过程中请勿终端操作，可能会造成设备无法使用</font>

### 健康戒指上报指令
#### 通用指令回调
```dart
  import 'package:elink_health_ring/utils/elink_health_ring_data_parse_utils.dart';
  import 'package:elink_health_ring/utils/elink_health_ring_common_callback.dart';
  
  ElinkHealthRingDataParseUtils elinkHealthRingDataParseUtils = ElinkHealthRingDataParseUtils(bleData.macArr, cid: bleData.cidArr);
  elinkHealthRingDataParseUtils.setCallback(
    commonCallback: ElinkHealthRingCommonCallback(
      onDeviceStatusChanged: (status) { //设备状态 ElinkHealthRingStatus
      },
      onGetSensorVersion: (version) { //传感器版本
      },
      onSetUnixTimeResult: (result) { //设置Unix时间结果，true: 成功，false: 失败
      },
      onSyncBleTimeResult: (result) { //设置ble时间结果，true: 成功，false: 失败
      }
    ),
  );
```
#### 自动监测和体检指令回调
```dart
  elinkHealthRingDataParseUtils.setCallback(
    checkupCallback: ElinkHealthRingCheckupCallback(
      onStartCheckup: (success) { //开始体检，true: 成功，false: 失败
      },
      onStopCheckup: (success) { //结束体检，true: 成功，false: 失败
      },
      onGetRealtimeData: (data) { //体检实时数据 ElinkCheckupRealtimeData
      },
      onGetCheckupPackets: (data) { //体检包 List<int> 
      },
      onGetCheckupDuration: (duration) { //自动监测周期，单位分钟
      },
      onGetCheckupHistory: (list, total, sentCount) { //自动监测历史记录，list: List<ElinkCheckupHistoryData>, total: 总条数, sentCount: 已发送数量
      },
      onGetAutoCheckupStatus: (open) { //自动监测开关状态，true: 开启，false: 关闭
      },
      onGetCheckupType: (type) { //自动监测类型，ElinkCheckupType
      },
      onNotifyCheckupHistoryGenerated: () { //自动监测记录生成通知
      },
    ),
  );
```
#### 睡眠和步数指令回调
```dart
  elinkHealthRingDataParseUtils.setCallback(
    sleepStepCallback: ElinkHealthRingSleepStepCallback(
      onGetCheckDuration: (duration) { //睡眠和步数监测周期，单位分钟
      },
      onGetSleepAndStepHistory: (list, total, sentCount) {  //睡眠和步数历史记录，list: List<ElinkSleepAndStepData>, total: 总条数, sentCount: 已发送数量
      },
      onNotifySleepAndStepHistoryGenerated: () {  //睡眠和步数记录生成通知
      },
      onGetSleepCheckState: (open) {  //睡眠监测状态，true: 开启，false: 关闭
      },
      onGetStepCheckState: (open) {  //步数监测状态，true: 开启，false: 关闭
      },
    ),
  );
```
#### 芯片OTA回调
```dart
    final _jfotaUtils = JFOTAUtils(bleData.macArr, cid: bleData.cidArr);
    elinkHealthRingDataParseUtils.setCallback(jfotaUtils: _jfotaUtils) //设置JFOTAUtils，处理设备上报的芯片OTA指令

    _jfotaUtils.setListener(
      onStartSuccess: (size) async { //开始芯片OTA成功，主动清除数据
        final data = _jfotaUtils.eraseAll(size);
        _sendA7Data(data);
      },
      onOtaPageWrite: (data, address) async { //主动写入数据
        final result = _jfotaUtils.pageWrite(data, address);
        _sendA7Data(result);
      },
      onOtaPageReadChecksum: (sum, address) async { //校验数据和
        final data = _jfotaUtils.pageReadChecksum(sum, address);
        _sendA7Data(data);
      },
      onFailure: (type) async { //OTA失败，主动结束OTA
        final data = _jfotaUtils.endOTA();
        _sendA7Data(data);
      },
      onSuccess: () async { //OTA成功，主动结束OTA
        final data = _jfotaUtils.endOTA();
        _sendA7Data(data);
      },
      onProgressChanged: (progress) { //OTA进度回调
      },
    );
```
### 常用类说明
#### ElinkCheckupHistoryData
```dart
  ElinkCheckupHistoryData(
    this.heartRate, //心率
    this.spo, //血氧
    this.bk,  //微循环
    this.sbp, //收缩压(高压)
    this.dbp, //舒张压(低压)
    this.rr,  //呼吸率
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
    this.heartRate, //心率
    this.bloodOxygen, //血氧
    this.heartList, //心律
    this.rr,
    this.rri,
  );
```
#### ElinkHealthRingStatus
```dart
  ElinkHealthRingStatus(
    this.state, //历史数据状态
    this.batteryLevel,  //电量
    this.isCharging,  //是否在充电
    this.wearingStatus, //佩戴状态
  );
```
#### ElinkSleepAndStepData
```dart
  ElinkSleepAndStepData(
    this.time,  //时间(毫秒)
    this.sleepState,  //睡眠状态
    this.steps  //步数
  );
```
#### ElinkCheckupType
```dart
  enum ElinkCheckupType { 
    fast, //快速体检(不包括情绪值)
    complex, //全面体检
  }
```
#### ElinkHealthRingHistoryState
```dart
  enum ElinkHealthRingHistoryState {
    notReady, //历史时间未就绪(未获取unix时间)
    processing, //历史时间正在处理中(已获取unix时间,在处理历史数据)
    ready, //历史时间已就绪(此状态才可获取设备历史记录)
  }
```
#### ElinkWearingStatus
```dart
  enum ElinkWearingStatus {
    unsupported, //不支持
    notWearing, //未佩戴
    wearing, //佩戴中
  }
```
#### 
```dart
  enum ElinkSleepState {
    awake, //清醒
    rem, //快速眼动
    light, //浅睡
    deep, //深睡
  }
```

具体使用方法，请参照示例
