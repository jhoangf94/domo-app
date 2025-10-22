
import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control Domótico BT',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.cyan,
        colorScheme: ColorScheme.dark().copyWith(
          primary: Colors.cyan,
          secondary: Colors.cyanAccent,
        ),
      ),
      home: const BluetoothController(),
    );
  }
}

class BluetoothController extends StatefulWidget {
  const BluetoothController({super.key});

  @override
  BluetoothControllerState createState() => BluetoothControllerState();
}

class BluetoothControllerState extends State<BluetoothController> {
  final _bluetoothClassicPlugin = BluetoothClassic();
  bool isConnecting = false;
  bool _isConnected = false;
  String? deviceName;

  List<Device> _devicesList = [];
  Device? _device;
  StreamSubscription<int>? _connectionStatusSubscription;

  @override
  void initState() {
    super.initState();
    _getPairedDevices();
    _connectionStatusSubscription = _bluetoothClassicPlugin.onDeviceStatusChanged().listen((status) {
      setState(() {
        _isConnected = status == 1;
      });
    });
  }

  @override
  void dispose() {
    _connectionStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _getPairedDevices() async {
    List<Device> devices = [];
    try {
      devices = await _bluetoothClassicPlugin.getPairedDevices();
    } catch (e) {
      developer.log('Error getting paired devices: $e');
    }

    setState(() {
      _devicesList = devices;
    });
  }

  void _connect(Device device) async {
    setState(() {
      isConnecting = true;
    });

    if (_device != null) {
      await _bluetoothClassicPlugin.disconnect();
    }

    try {
      await _bluetoothClassicPlugin.connect(device.address, "00001101-0000-1000-8000-00805f9b34fb");
      deviceName = device.name;
      setState(() {
        _device = device;
        isConnecting = false;
      });
    } catch (e) {
      setState(() {
        isConnecting = false;
      });
      developer.log('Error connecting to device: $e');
    }
  }

  void _sendCommand(String command) async {
    if (_isConnected) {
      await _bluetoothClassicPlugin.write("$command\n");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Domótico BT'),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              _isConnected ? LucideIcons.bluetoothConnected : LucideIcons.bluetoothOff,
              color: _isConnected ? Colors.green : Colors.red,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- sección de conectividad ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        _isConnected
                            ? "Conectado a $deviceName"
                            : isConnecting
                                ? "Conectando..."
                                : "Desconectado",
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.search),
                        label: const Text('Buscar Dispositivos'),
                        onPressed: () => _showDevicesDialog(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- controles de iluminación ---
              Text("Controles de Iluminación",
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              LightControl(
                roomName: 'Sala de Estar (L1)',
                onCommand: _sendCommand,
                label: 'L1',
              ),
              LightControl(
                roomName: 'Cocina (L2)',
                onCommand: _sendCommand,
                label: 'L2',
              ),
              LightControl(
                roomName: 'Dormitorio Principal (L3)',
                onCommand: _sendCommand,
                label: 'L3',
              ),
              LightControl(
                roomName: 'Baño (L4)',
                onCommand: _sendCommand,
                label: 'L4',
              ),
              const SizedBox(height: 20),
              // --- control de puerta ---
              Text("Control de Puerta",
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.doorOpen),
                        label: const Text('ABRIR PUERTA'),
                        onPressed: () => _sendCommand('P:180'),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.doorClosed),
                        label: const Text('CERRAR PUERTA'),
                        onPressed: () => _sendCommand('P:0'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDevicesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Dispositivos Bluetooth"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: _devicesList.length,
              itemBuilder: (context, index) {
                Device device = _devicesList[index];
                return ListTile(
                  title: Text(device.name ?? "Dispositivo Desconocido"),
                  subtitle: Text(device.address),
                  onTap: () {
                    _connect(device);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class LightControl extends StatefulWidget {
  final String roomName;
  final Function(String) onCommand;
  final String label;

  const LightControl({
    super.key,
    required this.roomName,
    required this.onCommand,
    required this.label,
  });

  @override
  LightControlState createState() => LightControlState();
}

class LightControlState extends State<LightControl> {
  bool _isOn = false;
  double _intensity = 50.0;

  void _onSwitchChanged(bool value) {
    setState(() {
      _isOn = value;
    });
    if (!_isOn) {
      widget.onCommand('${widget.label}:0');
    } else {
      _onSliderChanged(_intensity);
    }
  }

  void _onSliderChanged(double value) {
    setState(() {
      _intensity = value;
    });
    int pwmValue = (_intensity * 2.55).round();
    widget.onCommand('${widget.label}:$pwmValue');
    if (!_isOn && _intensity > 0) {
      setState(() {
        _isOn = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.roomName, style: const TextStyle(fontSize: 18)),
                Switch(
                  value: _isOn,
                  onChanged: _onSwitchChanged,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(LucideIcons.lightbulb),
                Expanded(
                  child: Slider(
                    value: _intensity,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: _intensity.round().toString(),
                    onChanged: (value) {
                      _onSliderChanged(value);
                    },
                  ),
                ),
                Text('${_intensity.round()}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
