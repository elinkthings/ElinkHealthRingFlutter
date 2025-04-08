class ElinkHealthRingConfig {
  static const List<int> cidHealthRing = [0x00, 0x5D];

  static isCidHealthRing(List<int> cid) {
    return cid[0] == cidHealthRing[0] && cid[1] == cidHealthRing[1];
  }
}

enum ElinkCheckupType { fast, complex }

enum ElinkHealthRingHistoryState {
  notReady, //Historical time is not ready (Unix time not obtained)
  processing, //Historical time is being processed (Unix time has been obtained and historical data is being processed)
  ready, //Historical time is ready (only in this state can the device history be obtained)
}

enum ElinkWearingStatus {
  unsupported, //不支持
  notWearing, //未佩戴
  wearing, //佩戴中
}

enum ElinkSleepState {
  awake, //Wide Awake
  rem, //Rapid Eye Movement
  light, //Light sleep
  deep, //Deep sleep
}
