abstract class DialogOtaListener {
  void onOtaSuccess();

  void onOtaFailure(int code, String msg);

  void onOtaProgress(double progress);
}
