import 'dart:async';
import 'dart:convert'; // Necesario para codificar a bytes
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
      debugShowCheckedModeBanner: false,
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

  // --- NUEVA CLASE: Debouncer para comandos ---
  // Esta clase asegura que las llamadas rápidas a _sendCommand se retrasen
  // ligeramente para darle tiempo al Arduino de estabilizarse.
  Timer? _debounceTimer;

  // Función proxy que aplica el debouncer antes de llamar a _sendCommand
  void _sendDebouncedCommand(String command) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    // Retardo de 100ms. Suficiente para que el Arduino "respire" entre comandos
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _sendCommand(command);
    });
  }

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
    _debounceTimer?.cancel(); // Limpiar el timer al salir
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
      _isConnected = false;
    });

    if (_device != null) {
      await _bluetoothClassicPlugin.disconnect();
    }

    try {
      // Intenta conectar usando el UUID estándar de Serial Port Profile (SPP)
      await _bluetoothClassicPlugin.connect(device.address, "00001101-0000-1000-8000-00805f9b34fb");
      deviceName = device.name;
      setState(() {
        _device = device;
        isConnecting = false;
        _isConnected = true;
      });
    } catch (e) {
      setState(() {
        isConnecting = false;
      });
      developer.log('Error connecting to device: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo conectar al dispositivo. Asegúrese de que esté encendido y dentro del alcance."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _disconnect() async {
    await _bluetoothClassicPlugin.disconnect();
    setState(() {
      _isConnected = false;
      _device = null; // Limpiar el dispositivo actual
      deviceName = null;
    });
  }

  // Función de envío de bajo nivel (llamada por _sendDebouncedCommand)
  void _sendCommand(String command) async {
    if (_isConnected) {
      // El comando completo incluye el salto de línea para el Arduino: "L1:255\n"
      String fullCommand = "$command\n"; 
      
      try {
        await _bluetoothClassicPlugin.writeBytes(utf8.encode(fullCommand));
        // Retardo de 50ms (se mantiene) para asegurar que el buffer se limpie en el Arduino
        await Future.delayed(const Duration(milliseconds: 50)); 
      } catch (e) {
        developer.log('Error al enviar comando: $e');
      }
    }
  }
  // --- FIN DE _sendCommand ---

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
                            ? "Conectado a ${deviceName ?? 'Dispositivo'}"
                            : isConnecting
                                ? "Conectando..."
                                : "Desconectado",
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      if (!_isConnected)
                        ElevatedButton.icon(
                          icon: const Icon(LucideIcons.search),
                          label: const Text('Buscar Dispositivos'),
                          onPressed: isConnecting ? null : () => _showDevicesDialog(),
                        )
                      else
                        ElevatedButton.icon(
                          icon: const Icon(LucideIcons.bluetoothOff),
                          label: const Text('Desconectar'),
                          onPressed: _disconnect,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                // CAMBIO: Usar el debouncer para el envío
                onCommand: _sendDebouncedCommand,
                label: 'L1',
                isEnabled: _isConnected,
              ),
              LightControl(
                roomName: 'Cocina (L2)',
                // CAMBIO: Usar el debouncer para el envío
                onCommand: _sendDebouncedCommand,
                label: 'L2',
                isEnabled: _isConnected,
              ),
              LightControl(
                roomName: 'Dormitorio Principal (L3)',
                // CAMBIO: Usar el debouncer para el envío
                onCommand: _sendDebouncedCommand,
                label: 'L3',
                isEnabled: _isConnected,
              ),
              LightControl(
                roomName: 'Segundo Dormitorio (L4)',
                // CAMBIO: Usar el debouncer para el envío
                onCommand: _sendDebouncedCommand,
                label: 'L4',
                isEnabled: _isConnected,
              ),
              const SizedBox(height: 20),
              // --- control de puerta ---
              Text("Control de Puerta",
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.doorOpen),
                        // CAMBIO: Usar el debouncer para el envío
                        label: const Text('ABRIR PUERTA'),
                        onPressed: _isConnected ? () => _sendDebouncedCommand('P:180') : null,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.doorClosed),
                        // CAMBIO: Usar el debouncer para el envío
                        label: const Text('CERRAR PUERTA'),
                        onPressed: _isConnected ? () => _sendDebouncedCommand('P:0') : null,
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
    // Recargar dispositivos emparejados justo antes de mostrar el diálogo
    _getPairedDevices(); 

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Dispositivos Bluetooth"),
          content: SizedBox(
            width: double.maxFinite,
            child: _devicesList.isEmpty
                ? const Center(child: Text("No se encontraron dispositivos emparejados."))
                : ListView.builder(
                    shrinkWrap: true,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

class LightControl extends StatefulWidget {
  // Nota: El tipo de onCommand ha cambiado a Function(String) para ajustarse al debouncer
  final Function(String) onCommand;
  final String roomName;
  final String label;
  final bool isEnabled;

  const LightControl({
    super.key,
    required this.roomName,
    required this.onCommand,
    required this.label,
    this.isEnabled = false,
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
    // Si se apaga, enviar 0 PWM
    if (!value) {
      widget.onCommand('${widget.label}:0');
    } else {
      // Si se enciende, enviar la última intensidad conocida (o 50% si nunca se movió)
      _sendIntensityCommand(_intensity);
    }
  }

  // Función que ahora solo es llamada por onChangeEnd
  void _onSliderCommandEnd(double value) {
    // Actualiza el estado final y envía el comando
    setState(() {
      _intensity = value;
    });
    _sendIntensityCommand(value);

    // Si el slider se mueve de 0 a un valor > 0, encender el switch
    if (!_isOn && _intensity > 0) {
      setState(() {
        _isOn = true;
      });
    }
  }

  void _sendIntensityCommand(double intensity) {
    // Conversión de 0-100 a 0-255 (PWM)
    int pwmValue = (intensity * 2.55).round();
    widget.onCommand('${widget.label}:$pwmValue');
  }


  @override
  Widget build(BuildContext context) {
    return Card(
      child: Opacity(
        opacity: widget.isEnabled ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(widget.roomName, style: const TextStyle(fontSize: 18)),
                  ),
                  Switch(
                    value: _isOn,
                    onChanged: widget.isEnabled ? _onSwitchChanged : null,
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
                      onChanged: widget.isEnabled ? (value) {
                        // Solo actualizar la UI, no enviar el comando
                        setState(() {
                          _intensity = value;
                        });
                      } : null,
                      // El comando se envía SOLO cuando el usuario suelta el slider.
                      onChangeEnd: widget.isEnabled ? _onSliderCommandEnd : null, 
                    ),
                  ),
                  Text('${_intensity.round()}%'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
