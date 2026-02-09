import 'dart:async';
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
  
  Stream<TreadmillData> get treadmillDataStream => _treadmillDataController.stream;

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
      // print('Erro ao scanear dispositivos: $e');
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
          // UUID do FTMS Treadmill Data characteristic (0x2AD1)
          if (uuid == '00002ad1-0000-1000-8000-00805f9b34fb') {
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
      // print('Erro ao conectar ao dispositivo: $e');
      return false;
    }
  }

  /// Subscreve aos dados da esteira
  void _subscribeTreadmillData(fbp.BluetoothCharacteristic characteristic) {
    _ftmsSubscription = characteristic.onValueReceived.listen((value) {
      _processTreadmillData(value);
    });
    
    // Habilitar notificações
    characteristic.setNotifyValue(true).catchError((e) {
      // print('Erro ao habilitar notificações: $e');
      return false;
    });
  }

  /// Processa dados recebidos da esteira
  void _processTreadmillData(List<int> value) {
    try {
      if (value.isEmpty) return;

      TreadmillData data = TreadmillData();

      // Bit 0 indica se há mais dados (More Data Available)
      // Bits 1-7 indicam quais dados estão presentes
      int flags = value[0];

      int offset = 1;

      // Flags para indicar quais dados estão presentes
      const int instantaneousSpeedPresent = 0x01;
      const int inclinationPresent = 0x02;
      const int rampAnglePresent = 0x04;
      const int distancePresent = 0x08;
      const int timePresent = 0x10;
      const int caloriesPresent = 0x20;
      const int heartRatePresent = 0x40;
      const int runningPresent = 0x80;

      // Velocidade instantânea (2 bytes, little-endian, 0.01 km/h)
      if ((flags & instantaneousSpeedPresent) != 0) {
        int speed = value[offset] | (value[offset + 1] << 8);
        data.speed = speed * 0.01;
        offset += 2;
      }

      // Inclinação (2 bytes, signed, little-endian, 0.1%)
      if ((flags & inclinationPresent) != 0) {
        int incline = _bytesToSignedInt16(value[offset], value[offset + 1]);
        data.incline = incline * 0.1;
        offset += 2;
      }

      // Ramp Angle (2 bytes, signed, little-endian, 0.1°)
      if ((flags & rampAnglePresent) != 0) {
        offset += 2;
      }

      // Distância (3 bytes, little-endian, 1 metro)
      if ((flags & distancePresent) != 0) {
        int distance = value[offset] | 
            (value[offset + 1] << 8) | 
            (value[offset + 2] << 16);
        data.distance = distance.toDouble();
        offset += 3;
      }

      // Tempo (2 bytes, little-endian, 1 segundo)
      if ((flags & timePresent) != 0) {
        int time = value[offset] | (value[offset + 1] << 8);
        data.time = time;
        offset += 2;
      }

      // Calorias (2 bytes, little-endian, 1 caloria)
      if ((flags & caloriesPresent) != 0) {
        int calories = value[offset] | (value[offset + 1] << 8);
        data.calories = calories;
        offset += 2;
      }

      // Heart Rate (1 byte)
      if ((flags & heartRatePresent) != 0) {
        data.heartRate = value[offset];
        offset += 1;
      }

      // Running Status
      if ((flags & runningPresent) != 0) {
        data.isRunning = value[offset] == 1;
        offset += 1;
      }

      _treadmillDataController.add(data);
    } catch (e) {
      // print('Erro ao processar dados da esteira: $e');
    }
  }

  /// Solicita controle da esteira (necessário em alguns dispositivos antes de enviar comandos)
  Future<void> requestControl() async {
    if (_controlPointCharacteristic == null) return;
    try {
      // Opcode 0x00: Request Control
      await _controlPointCharacteristic!.write([0x00]);
    } catch (e) {
      // print('Erro ao solicitar controle: $e');
    }
  }

  /// Define a velocidade alvo (km/h)
  Future<void> setTargetSpeed(double speedKmh) async {
    if (_controlPointCharacteristic == null) {
      // print('Control Point não encontrado');
      return;
    }
    try {
      // Opcode 0x02: Set Target Speed
      // Param: UINT16, 0.01 km/h
      int value = (speedKmh * 100).toInt();
      List<int> data = [0x02, value & 0xFF, (value >> 8) & 0xFF];
      await _controlPointCharacteristic!.write(data);
    } catch (e) {
      // print('Erro ao definir velocidade: $e');
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
      // print('Erro ao definir inclinação: $e');
    }
  }

  /// Converte dois bytes em um inteiro signed de 16 bits
  int _bytesToSignedInt16(int lowByte, int highByte) {
    int value = lowByte | (highByte << 8);
    if (value & 0x8000 != 0) {
      value = -(0x10000 - value);
    }
    return value;
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
      // print('Erro ao desconectar: $e');
    }
  }

  /// Libera recursos
  void dispose() {
    _ftmsSubscription?.cancel();
    _treadmillDataController.close();
  }
}
