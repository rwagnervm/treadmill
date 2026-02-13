import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../services/bluetooth_service.dart';
import 'treadmill_data_screen.dart';
import 'debug_screen.dart';

class DeviceSelectionScreen extends StatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  State<DeviceSelectionScreen> createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  late BluetoothService _bluetoothService;
  List<fbp.BluetoothDevice> _devices = [];
  bool _isScanning = false;
  late StreamSubscription<fbp.BluetoothAdapterState> _adapterStateSubscription;

  @override
  void initState() {
    super.initState();
    _bluetoothService = BluetoothService();
    _adapterStateSubscription =
        fbp.FlutterBluePlus.adapterState.listen((fbp.BluetoothAdapterState state) {
      if (state == fbp.BluetoothAdapterState.on) {
        _scanForDevices();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, ative o Bluetooth'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
    _checkBluetoothAndScan();
  }

  Future<void> _checkBluetoothAndScan() async {
    if (await fbp.FlutterBluePlus.adapterState.first == fbp.BluetoothAdapterState.on) {
      _scanForDevices();
    }
  }

  Future<void> _scanForDevices() async {
    if (_isScanning) return;

    setState(() => _isScanning = true);

    try {
      List<fbp.BluetoothDevice> devices =
          await _bluetoothService.scanForDevices();
      setState(() => _devices = devices);

      if (_devices.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum dispositivo encontrado'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao escanear: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToDevice(fbp.BluetoothDevice device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Conectando...'),
            ],
          ),
        ),
      ),
    );

    try {
      bool connected = await _bluetoothService.connectToDevice(device);

      if (mounted) {
        Navigator.pop(context); // Fechar diálogo de carregamento

        if (connected) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TreadmillDataScreen(device: device),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Falha ao conectar ao dispositivo'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fechar diálogo de carregamento
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao conectar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar Esteira'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_devices.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DebugScreen(device: _devices.first),
                  ),
                );
              },
              tooltip: 'Debug Bluetooth',
            ),
        ],
      ),
      body: Column(
        children: [
          // Header com instrução
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Selecione sua esteira Bluetooth',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          // Lista de dispositivos
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bluetooth_disabled,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Procurando dispositivos...'
                              : 'Nenhum dispositivo encontrado',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.directions_run),
                          title: Text(
                            device.platformName.isNotEmpty
                                ? device.platformName
                                : 'Dispositivo desconhecido',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(device.remoteId.str),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () => _connectToDevice(device),
                        ),
                      );
                    },
                  ),
          ),
          // Botão de escanear novamente
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _scanForDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Escanear Novamente'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _adapterStateSubscription.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }
}
