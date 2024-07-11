import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

/// Example app for wifi_scan plugin.
class MyApp extends StatefulWidget {
  /// Default constructor for [MyApp] widget.
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<WiFiAccessPoint> accessPoints = <WiFiAccessPoint>[];
  String? currentSSID;
  bool isScanning = false;
  bool shouldCheckCan = true;
  String? routerIpAddress;
  final String ssidPrefix = 'BAAD_';

  @override
  void initState() {
    super.initState();
    _getScannedResults();
  }

  Future<void> _getScannedResults() async {
    // Obter resultados do scan
    final results = await WiFiScan.instance.getScannedResults();
    setState(() {
      accessPoints = results;
    });
  }

  Future<void> _scanAndFetchResults(BuildContext context) async {
    if (isScanning) {
      kShowSnackBar(context, "Scan already in progress");
      return;
    }

    if (!await Permission.location.request().isGranted) {
      _showSnackBar(context, "Permissão de localização negada");
      return;
    }

    setState(() {
      isScanning = true;
    });

    try {
      WiFiForIoTPlugin.getSSID().then((value) => currentSSID = value!);
      // Check if "can" startScan
      if (shouldCheckCan) {
        final can = await WiFiScan.instance.canStartScan();
        if (can != CanStartScan.yes) {
          if (mounted) kShowSnackBar(context, "Cannot start scan: $can");
          setState(() {
            isScanning = false;
          });
          return;
        }
      }

      // Call startScan API
      final startResult = await WiFiScan.instance.startScan();
      if (startResult != true) {
        if (mounted) kShowSnackBar(context, "Failed to start scan");
        setState(() {
          isScanning = false;
        });
        return;
      }
      if (mounted) kShowSnackBar(context, "startScan: $startResult");

      // Wait a moment to allow scan to complete
      await Future.delayed(Duration(seconds: 2));

      // Check if "can" get scanned results
      if (shouldCheckCan) {
        final can = await WiFiScan.instance.canGetScannedResults();
        if (can != CanGetScannedResults.yes) {
          if (mounted)
            kShowSnackBar(context, "Cannot get scanned results: $can");
          setState(() {
            accessPoints = <WiFiAccessPoint>[];
            isScanning = false;
          });
          return;
        }
      }

      // Get scanned results
      final results = await WiFiScan.instance.getScannedResults();
      setState(() {
        accessPoints = ssidPrefix != ''
            ? results
                .where(
                    (ap) => ap.ssid.startsWith(ssidPrefix)) // Filtrar por SSID
                .toList()
            : results;
      });
    } catch (e) {
      kShowSnackBar(context, "Error occurred: $e");
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Basico Aroma - Scanner WiFi'),
        ),
        body: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.perm_scan_wifi),
                    label: isScanning
                        ? const Text('Scaneando...')
                        : const Text('Escanear Wi-Fi'),
                    onPressed: isScanning
                        ? null
                        : () async => _scanAndFetchResults(context),
                  ),
                ),
                const Divider(),
                Flexible(
                  child: Center(
                    child: accessPoints.isEmpty
                        ? const Text("NO SCANNED RESULTS")
                        : ListView.separated(
                            itemCount: accessPoints.length,
                            itemBuilder: (context, i) => _AccessPointTile(
                              accessPoint: accessPoints[i],
                              accessPoints: accessPoints,
                              onTap: () => _handleTap(context, accessPoints[i]),
                              parentContext: context,
                            ),
                            separatorBuilder: (context, index) => const Divider(
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, WiFiAccessPoint accessPoint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(accessPoint.ssid.isNotEmpty ? accessPoint.ssid : "**EMPTY**"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfo("BSSID", accessPoint.bssid),
            _buildInfo("Capability", accessPoint.capabilities),
            _buildInfo("Frequency", "${accessPoint.frequency}MHz"),
            _buildInfo("Level", accessPoint.level),
            _buildInfo("Standard", accessPoint.standard),
            _buildInfo(
                "Center Frequency 0", "${accessPoint.centerFrequency0}MHz"),
            _buildInfo(
                "Center Frequency 1", "${accessPoint.centerFrequency1}MHz"),
            _buildInfo("Channel Width", accessPoint.channelWidth),
            _buildInfo("Is Passpoint", accessPoint.isPasspoint),
            _buildInfo(
                "Operator Friendly Name", accessPoint.operatorFriendlyName),
            _buildInfo("Venue Name", accessPoint.venueName),
            _buildInfo("Is 802.11mc Responder", accessPoint.is80211mcResponder),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(String label, dynamic value) => Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey)),
        ),
        child: Row(
          children: [
            Text(
              "$label: ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(child: Text(value.toString()))
          ],
        ),
      );
}

/// Show tile for AccessPoint.
///
/// Can see details when tapped.
class _AccessPointTile extends StatelessWidget {
  final WiFiAccessPoint accessPoint;
  final VoidCallback onTap;
  final BuildContext parentContext;
  final List<WiFiAccessPoint> accessPoints;

  const _AccessPointTile(
      {Key? key,
      required this.accessPoint,
      required this.accessPoints,
      required this.onTap,
      required this.parentContext})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = accessPoint.ssid.isNotEmpty ? accessPoint.ssid : "**EMPTY**";
    final signalIcon = accessPoint.level >= -80
        ? Icons.signal_wifi_4_bar
        : Icons.signal_wifi_0_bar;
    return ListTile(
      visualDensity: VisualDensity.compact,
      leading: Icon(signalIcon),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(accessPoint.capabilities,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              _canConnectWithCurrentSSID().then((value) {
                if (value) _showPasswordDialog(parentContext, accessPoint);
              });
              //_showPasswordDialog(parentContext, accessPoint);
            },
            child: const Text('Configurar'),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showPasswordDialog(BuildContext context, WiFiAccessPoint accessPoint) {
    final TextEditingController passwordController = TextEditingController();

    final info = NetworkInfo();
    
    info.getWifiName().then((value) {
      String? currSSID;

      currSSID = value;    

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Informe a senha da rede ATUAL ($currSSID), à qual o dispositivo deverá se conectar.'),
          content: TextField(
            controller: passwordController,
            decoration: const InputDecoration(
              labelText: 'Senha',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _connectToNetwork(
                    parentContext, accessPoint.ssid, passwordController.text);
              },
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    });
  }

  Future<bool> _canConnectWithCurrentSSID() async {
    final info = NetworkInfo();
    String? currSSID = await info.getWifiName();

    if (currSSID == null) {
      _showErrorDialog(
          parentContext, "Erro", "Não foi possível obter o SSID da rede atual");
      return false;
    }

    //replace "" with "
    currSSID = currSSID.replaceAll("\"", "");

    WiFiAccessPoint? currentAccessPoint;
    //for each access point in accessPoints, if the ssid matches the ssid of the access point we want to connect to, set currentAccessPoint to that access point
    for (int i = 0; i < accessPoints.length; i++) {
      if (accessPoints[i].ssid == currSSID) {
        currentAccessPoint = accessPoints[i];
      }
    }

    if (currentAccessPoint != null && currentAccessPoint.frequency > 3000) {
      _showErrorDialog(
          parentContext,
          "Erro de Frequência",
          "O aparelho está conectado a uma rede de 5GHz. Por favor, conecte a uma rede de 2.4GHz para continuar.");
      return false;
    }

    return true;
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToNetwork(
      BuildContext context, String ssid, String password) async {
    final info = NetworkInfo();
    String? currSSID = await info.getWifiName();

    String json = '{"ssid":"$currSSID","password":"$password"}';

    // Solicitar permissão de localização em tempo de execução
    if (await Permission.location.request().isGranted) {
      // Desconectar do Wi-Fi atual antes de tentar conectar-se a um novo Wi-Fi
      try {
        await WiFiForIoTPlugin.disconnect();
      } catch (e) {
        _showSnackBar(parentContext, 'Erro ao desconectar do Wi-Fi atual: $e');
        return;
      }

      // Connect to Wi-Fi network
      try {
        bool connected = await connect(ssid, "ba%23Aa4");
        
        if (!connected) {
          _showSnackBar(parentContext, 'Erro ao conectar à rede Wi-Fi');
          return;
        }

        // Get the device's IP address after successful connection
        final deviceIpAddress = await WiFiForIoTPlugin.getIP();
        // print(_getRouterIpAddress(deviceIpAddress!));

        // result += "\nRouter IP Address 2: ${_getRouterIpAddress(deviceIpAddress)}";
        _showSnackBar(
            parentContext, "Conectado com sucesso à rede Wi-Fi: $WiFiForIoTPlugin.GetSSID()");

        final http.Response response = await http.post(
          Uri.parse('http://192.168.4.1/Configuracao'),
          body: json,
        );

        if (response.statusCode == 200) {
          _showSnackBar(parentContext, 'Configuração enviada com sucesso!');
          await WiFiForIoTPlugin.disconnect();
          //remove the network from the list of available networks
          accessPoints.removeWhere((element) => element.ssid == ssid);
        } else {
          _showSnackBar(parentContext,
              'Falha ao enviar a configuração. Código de status: ${response.statusCode}');
        }
      } catch (e) {
        _showSnackBar(parentContext, 'Erro ao conectar à rede Wi-Fi: $e');
        return;
      }
    } else {
      _showSnackBar(parentContext, "Permissão de localização negada");
    }
  }

  Future<bool> connect(String ssid, String pwd) async {
    try {
      bool result = await WiFiForIoTPlugin.connect(
        ssid,
        withInternet: false,
        security: NetworkSecurity.WPA,
        password: pwd,
      );
      print("connecting");
      if (result) {
        WiFiForIoTPlugin.forceWifiUsage(true);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      throw Exception(e);
    }
  }
}

void _showSnackBar(BuildContext context, String message) {
  if (context != null && ScaffoldMessenger.of(context).mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// Function to extract router's IP address from device's IP address
String _getRouterIpAddress(String deviceIpAddress) {
  final List<String> parts = deviceIpAddress.split('.');
  // Replace the last part of device's IP address with '1' to get router's IP address
  parts[3] = '1';
  return parts.join('.');
}

/// Show snackbar.
void kShowSnackBar(BuildContext context, String message) {
  if (kDebugMode) print(message);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
