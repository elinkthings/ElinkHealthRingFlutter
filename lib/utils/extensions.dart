extension IntExtension on int {
  String toIntStr() {
    final result = '$this';
    return result.length == 1 ? '0$result' : result;
  }
}
