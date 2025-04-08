class ElinkCheckupRealtimeData {
  final int heartRate;
  final int bloodOxygen;
  final List<int> heartList;
  final int rr;
  final List<int> rri;

  ElinkCheckupRealtimeData(
    this.heartRate,
    this.bloodOxygen,
    this.heartList,
    this.rr,
    this.rri,
  );

  @override
  String toString() {
    return "ElinkCheckupRealtimeData(heartRate=$heartRate, bloodOxygen=$bloodOxygen, heartList=${heartList.join(",")}, rr=$rr, rri=${rri.join(",")})";
  }
}
