import 'package:elink_health_ring_example/pages/page_device.dart';
import 'package:elink_health_ring_example/pages/page_home.dart';
import 'package:elink_health_ring_example/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(MaterialApp(
    initialRoute: pageHome,
    routes: {
      pageHome: (context) => const HomePage(),
      pageDevice: (context) => const PageDevice(),
    },
  ));
}
