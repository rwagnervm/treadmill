import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../models/treadmill_data.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();

  factory BluetoothService() {
    return _instance;
  }

  BluetoothService._internal();

  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _controlPointCharacteristic;
  StreamSubscription? _ftmsSubscription;

  final _treadmillDataController = StreamController<TreadmillData>.broadcast();
  final _rawBytesController = StreamController<List<int>>.broadcast();

  Stream<TreadmillData> get treadmillDataStream =>
      _treadmillDataController.stream;

  Stream<List<int>> get rawBytesStream => _rawBytesController.stream;

  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Obtém lista de dispositivos Bluetooth disponíveis
  Future<List<fbp.BluetoothDevice>> scanForDevices() async {
    try {
      await fbp.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
        withServices: [fbp.Guid("1826")],
      );

      await Future.delayed(const Duration(milliseconds: 2000));

      final allDevices = <fbp.BluetoothDevice>[];
      final seen = <String>{};

      fbp.FlutterBluePlus.scanResults.listen((results) {
        for (fbp.ScanResult r in results) {
          if (!seen.contains(r.device.remoteId.str)) {
            seen.add(r.device.remoteId.str);
            allDevices.add(r.device);
          }
        }
      });

      await fbp.FlutterBluePlus.stopScan();
      return allDevices;
    } catch (e) {
      print('Erro ao scanear dispositivos: $e');
      return [];
    }
  }

  /// Conecta a um dispositivo Bluetooth
  Future<bool> connectToDevice(fbp.BluetoothDevice device) async {
    try {
      await device.connect(
        timeout: const Duration(seconds: 10),
        license: fbp.License.free,
      );
      _connectedDevice = device;

      // Descobrir serviços
      List<fbp.BluetoothService> services = await device.discoverServices();

      // Procurar pelo serviço FTMS (Fitness Training Machine Service)
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          String uuid = characteristic.uuid.toString().toLowerCase();
          // UUID do FTMS Treadmill Data characteristic (0x2ACD)
          if (uuid == '00002acd-0000-1000-8000-00805f9b34fb') {
            _subscribeTreadmillData(characteristic);
          }
          // UUID do FTMS Control Point (0x2AD9)
          else if (uuid == '00002ad9-0000-1000-8000-00805f9b34fb') {
            _controlPointCharacteristic = characteristic;
            // Tenta habilitar indicações para receber confirmação de comandos
            if (characteristic.properties.indicate) {
              await characteristic.setNotifyValue(true).onError((e, s) => true);
            }
          }
        }
      }

      return true;
    } catch (e) {
      print('Erro ao conectar ao dispositivo: $e');
      return false;
    }
  }

  /// Subscreve aos dados da esteira
  void _subscribeTreadmillData(fbp.BluetoothCharacteristic characteristic) {
    _ftmsSubscription = characteristic.onValueReceived.listen((value) {
      // Emitir bytes brutos para debug
      _rawBytesController.add(value);
      // Processar e emitir dados decodificados
      _processTreadmillData(value);
    });

    // Habilitar notificações
    characteristic.setNotifyValue(true).catchError((e) {
      print('Erro ao habilitar notificações: $e');
      return false;
    });
  }

  /// Processa dados recebidos da esteira
  void _processTreadmillData(List<int> value) {
    print('Dados recebidos: $value');
    try {
      if (value.length < 2) return;

      TreadmillData data = TreadmillData();
      var byteData = ByteData.sublistView(Uint8List.fromList(value));

      int flags = byteData.getUint16(0, Endian.little);
      int offset = 2;

      // Flags based on FTMS specification for Treadmill Data (0x2ACD)
      const int totalDistancePresent = 1 << 2;
      const int inclinationPresent = 1 << 3;
      const int expendedEnergyPresent = 1 << 7;
      const int heartRatePresent = 1 << 8;
      const int elapsedTimePresent = 1 << 10;

      // Instantaneous Speed is always present
      if (value.length >= offset + 2) {
        int speed = byteData.getUint16(offset, Endian.little);
        data.speed = speed * 0.01;
        offset += 2;
      }

      // Total Distance
      if ((flags & totalDistancePresent) != 0) {
        if (value.length >= offset + 3) {
          int distance = byteData.getUint8(offset) |
              (byteData.getUint8(offset + 1) << 8) |
              (byteData.getUint8(offset + 2) << 16);
          data.distance = distance.toDouble();
          offset += 3;
        }
      }

      // Inclination and Ramp Angle
      if ((flags & inclinationPresent) != 0) {
        if (value.length >= offset + 4) {
          int incline = byteData.getInt16(offset, Endian.little);
          data.incline = incline * 0.1;
          offset += 2; // Inclination
          offset += 2; // Ramp Angle (skipped)
        }
      }

      // Expended Energy
      if ((flags & expendedEnergyPresent) != 0) {
        if (value.length >= offset + 3) {
          // Total Energy, Energy Per Hour, Energy Per Minute
          int calories = byteData.getUint16(offset, Endian.little);
          data.calories = calories;
          offset += 2; // Total Energy
          offset += 2; // Energy Per Hour (skipped)
          offset += 1; // Energy Per Minute (skipped)
        }
      }

      // Heart Rate
      if ((flags & heartRatePresent) != 0) {
        if (value.length >= offset + 1) {
          data.heartRate = byteData.getUint8(offset);
          offset += 1;
        }
      }

      // Elapsed Time
      if ((flags & elapsedTimePresent) != 0) {
        if (value.length >= offset + 2) {
          data.time = byteData.getUint16(offset, Endian.little);
          offset += 2;
        }
      }

      _treadmillDataController.add(data);
    } catch (e) {
      print('Erro ao processar dados da esteira: $e');
    }
  }

  /// Solicita controle da esteira (necessário em alguns dispositivos antes de enviar comandos)
  Future<void> requestControl() async {
    if (_controlPointCharacteristic == null) return;
    try {
      // Opcode 0x00: Request Control
      await _controlPointCharacteristic!.write([0x00]);
    } catch (e) {
      print('Erro ao solicitar controle: $e');
    }
  }

  /// Define a velocidade alvo (km/h)
  Future<void> setTargetSpeed(double speedKmh) async {
    if (_controlPointCharacteristic == null) {
      print('Control Point não encontrado');
      return;
    }
    try {
      // Opcode 0x02: Set Target Speed
      // Param: UINT16, 0.01 km/h
      int value = (speedKmh * 100).toInt();
      List<int> data = [0x02, value & 0xFF, (value >> 8) & 0xFF];
      await _controlPointCharacteristic!.write(data);
    } catch (e) {
      print('Erro ao definir velocidade: $e');
    }
  }

  /// Define a inclinação alvo (%)
  Future<void> setTargetIncline(double inclinePercent) async {
    if (_controlPointCharacteristic == null) return;
    try {
      // Opcode 0x03: Set Target Inclination
      // Param: SINT16, 0.1 %
      int value = (inclinePercent * 10).toInt();
      List<int> data = [0x03, value & 0xFF, (value >> 8) & 0xFF];
      await _controlPointCharacteristic!.write(data);
    } catch (e) {
      print('Erro ao definir inclinação: $e');
    }
  }

  /// Desconecta do dispositivo
  Future<void> disconnectDevice() async {
    try {
      if (_connectedDevice != null) {
        await _ftmsSubscription?.cancel();
        await _connectedDevice?.disconnect();
        _connectedDevice = null;
        _controlPointCharacteristic = null;
      }
    } catch (e) {
      print('Erro ao desconectar: $e');
    }
  }

  /// Libera recursos
  void dispose() {
    _ftmsSubscription?.cancel();
    _treadmillDataController.close();
    _rawBytesController.close();
  }
}
