class ElinkCheckupHistoryData {
  final int heartRate; //心率
  final int spo; //血氧饱和度
  final int bk; //微循环
  final int sbp; //收缩压(高压)
  final int dbp; //舒张压(低压)
  final int rr; //呼吸率
  final int sdann;
  final int rmssd;
  final int nn50;
  final int pnn50;
  final int time;
  final String rri;

  ElinkCheckupHistoryData(
    this.heartRate,
    this.spo,
    this.bk,
    this.sbp,
    this.dbp,
    this.rr,
    this.sdann,
    this.rmssd,
    this.nn50,
    this.pnn50,
    this.time,
    this.rri,
  );

  @override
  String toString() {
    return 'ElinkCheckupHistoryData('
        'heartRate: $heartRate, '
        'spo: $spo%, '
        'bk: $bk, '
        'sbp: $sbp mmHg, '
        'dbp: $dbp mmHg, '
        'rr: $rr, '
        'sdann: $sdann, '
        'rmssd: $rmssd, '
        'nn50: $nn50, '
        'pnn50: $pnn50, '
        'time: ${DateTime.fromMillisecondsSinceEpoch(time)}, '
        'rri: $rri)';
  }
}
