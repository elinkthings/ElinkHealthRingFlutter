import 'package:ailink/utils/elink_cmd_utils.dart';
import 'package:elink_health_ring/utils/elink_health_ring_config.dart';

abstract class ElinkHealthRingBaseUtils {
  List<int>? _mac;
  List<int> _cid = ElinkHealthRingConfig.cidHealthRing;

  void initialize(List<int> mac, {required List<int> cid}) {
    _cid = cid;
    _mac = mac;
  }

  List<int>? getMac() => _mac;

  List<int> getCid() => _cid;

  Future<List<int>> getElinkA7Data(List<int> payload) {
    if (_mac == null) return Future.value([]);
    return ElinkCmdUtils.getElinkA7Data(_cid, _mac!, payload);
  }
}
