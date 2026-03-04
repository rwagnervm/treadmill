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

  /// Número máximo de níveis de inclinação do painel da esteira
  static const double maxInclineLevels = 15.0;
  /// Percentual FTMS máximo que corresponde ao nível máximo
  static const double maxInclinePercent = 100.0;

  StreamController<TreadmillData> _treadmillDataController = StreamController<TreadmillData>.broadcast();
  StreamController<List<int>> _rawBytesController = StreamController<List<int>>.broadcast();

  Stream<TreadmillData> get treadmillDataStream {
    _ensureControllersOpen();
    return _treadmillDataController.stream;
  }

  Stream<List<int>> get rawBytesStream {
    _ensureControllersOpen();
    return _rawBytesController.stream;
  }

  /// Ensures stream controllers are open; recreates them if they were closed.
  void _ensureControllersOpen() {
    if (_treadmillDataController.isClosed) {
      _treadmillDataController = StreamController<TreadmillData>.broadcast();
    }
    if (_rawBytesController.isClosed) {
      _rawBytesController = StreamController<List<int>>.broadcast();
    }
  }

  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get hasControl => _controlPointCharacteristic != null;

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
      // Ensure controllers are still open before adding data
      _ensureControllersOpen();
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

      // Bit 0: More Data (0 = Instantaneous Speed present)
      if ((flags & 0x0001) == 0) {
        if (value.length >= offset + 2) {
          data.speed = byteData.getUint16(offset, Endian.little) * 0.01;
        }
        offset += 2;
      }

      // Bit 1: Average Speed present
      if ((flags & 0x0002) != 0) {
        offset += 2;
      }

      // Bit 2: Total Distance present
      if ((flags & 0x0004) != 0) {
        if (value.length >= offset + 3) {
          int distance =
              byteData.getUint8(offset) |
              (byteData.getUint8(offset + 1) << 8) |
              (byteData.getUint8(offset + 2) << 16);
          data.distance = distance.toDouble();
        }
        offset += 3;
      }

      // Bit 3: Inclination and Ramp Angle present
      if ((flags & 0x0008) != 0) {
        if (value.length >= offset + 4) {
          // A esteira reporta % via FTMS (0-100%), mas o painel mostra 0-15 níveis.
          // Converte: percent = raw * 0.1, nível = percent * 15 / 100
          double percentValue = byteData.getInt16(offset, Endian.little) * 0.1;
          data.incline = percentValue * maxInclineLevels / maxInclinePercent;
        }
        offset += 4;
      }

      // Bit 4: Elevation Gain present
      if ((flags & 0x0010) != 0) {
        offset += 4;
      }

      // Bit 5: Instantaneous Pace present
      if ((flags & 0x0020) != 0) {
        offset += 2;
      }

      // Bit 6: Average Pace present
      if ((flags & 0x0040) != 0) {
        offset += 2;
      }

      // Bit 7: Expended Energy present
      if ((flags & 0x0080) != 0) {
        if (value.length >= offset + 5) {
          data.calories = byteData.getUint16(offset, Endian.little);
        }
        offset += 5;
      }

      // Bit 8: Heart Rate present
      if ((flags & 0x0100) != 0) {
        if (value.length >= offset + 1) {
          data.heartRate = byteData.getUint8(offset);
        }
        offset += 1;
      }

      // Bit 9: Metabolic Equivalent present
      if ((flags & 0x0200) != 0) {
        offset += 1;
      }

      // Bit 10: Elapsed Time present
      if ((flags & 0x0400) != 0) {
        if (value.length >= offset + 2) {
          data.time = byteData.getUint16(offset, Endian.little);
        }
        offset += 2;
      }

      // Assume it's running if speed is greater than 0
      data.isRunning = data.speed > 0;

      // Assume control is done to avoid unused imports
      _treadmillDataController.add(data);
    } catch (e) {
      print('Erro ao processar dados da esteira: $e');
    }
  }

  /// Solicita controle da esteira (necessário em alguns dispositivos antes de enviar comandos)
  Future<void> requestControl() async {
    if (_controlPointCharacteristic == null) {
      print('⚠️ requestControl: Control Point não disponível');
      return;
    }
    try {
      // Opcode 0x00: Request Control
      await _controlPointCharacteristic!.write([0x00]);
      print('✅ requestControl: Controle solicitado com sucesso');
    } catch (e) {
      print('❌ requestControl: Erro ao solicitar controle: $e');
    }
  }

  /// Define a velocidade alvo (km/h)
  Future<void> setTargetSpeed(double speedKmh) async {
    if (_controlPointCharacteristic == null) {
      print('⚠️ setTargetSpeed: Control Point não encontrado');
      return;
    }
    try {
      // Opcode 0x02: Set Target Speed
      // Param: UINT16, 0.01 km/h
      int value = (speedKmh * 100).toInt();
      List<int> data = [0x02, value & 0xFF, (value >> 8) & 0xFF];
      print('📤 setTargetSpeed: Enviando $speedKmh km/h (raw=$value, bytes=${data.map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")})');
      await _controlPointCharacteristic!.write(data);
      print('✅ setTargetSpeed: Comando enviado com sucesso');
    } catch (e) {
      print('❌ setTargetSpeed: Erro ao definir velocidade: $e');
    }
  }

  /// Define a inclinação alvo (nível 0-15 do painel da esteira)
  /// Converte o nível do painel para percentual FTMS antes de enviar.
  Future<void> setTargetIncline(double inclineLevel) async {
    if (_controlPointCharacteristic == null) {
      print('⚠️ setTargetIncline: Control Point não encontrado');
      return;
    }
    try {
      // Converte nível do painel (0-15) para percentual FTMS (0-100%)
      // Opcode 0x03: Set Target Inclination
      // Param: SINT16, 0.1 %
      double percentValue = inclineLevel * maxInclinePercent / maxInclineLevels;
      int value = (percentValue * 10).round();
      List<int> data = [0x03, value & 0xFF, (value >> 8) & 0xFF];
      print('📤 setTargetIncline: Nível $inclineLevel → ${percentValue.toStringAsFixed(2)}% (raw=$value, bytes=${data.map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")})');
      await _controlPointCharacteristic!.write(data);
      print('✅ setTargetIncline: Comando enviado com sucesso');
    } catch (e) {
      print('❌ setTargetIncline: Erro ao definir inclinação: $e');
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

  /// Cancela as assinaturas de dados sem destruir o singleton.
  /// Use isto nas telas para limpar listeners sem matar os controllers.
  void cancelSubscriptions() {
    _ftmsSubscription?.cancel();
    _ftmsSubscription = null;
  }

  /// Libera recursos completamente. Só chame isto se realmente quiser
  /// encerrar toda a conexão Bluetooth permanentemente.
  void dispose() {
    _ftmsSubscription?.cancel();
    _ftmsSubscription = null;
    if (!_treadmillDataController.isClosed) {
      _treadmillDataController.close();
    }
    if (!_rawBytesController.isClosed) {
      _rawBytesController.close();
    }
  }
}
