import 'package:flutter/foundation.dart';

logD(dynamic msg) {
  if (kDebugMode) {
    debugPrint(msg);
  }
}