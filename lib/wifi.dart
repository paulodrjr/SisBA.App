/*import 'dart:async';
import 'package:wifi_flutter/wifi_flutter.dart';

Future<List<WifiNetwork>> scanWifiNetworks() async {
  List<WifiNetwork> networks = [];

  try {
    Iterable<WifiNetwork> networks = await WifiFlutter.wifiNetworks;
  } catch (e) {
    print('Error retrieving Wi-Fi networks: $e');
  }

  return networks;
}*/