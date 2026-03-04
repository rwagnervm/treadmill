import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

/// Dados recebidos do Galaxy Watch (ou qualquer wearable BLE).
class WatchData {
  final int heartRate;
  final int stepsPerMinute; // cadência de passos
  final DateTime timestamp;

  WatchData({
    this.heartRate = 0,
    this.stepsPerMinute = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'WatchData(hr: $heartRate bpm, spm: $stepsPerMinute, ts: $timestamp)';
}

/// Serviço para conexão com Galaxy Watch via BLE.
///
/// Utiliza os serviços padrão BLE GATT:
/// - Heart Rate Service (0x180D) / Heart Rate Measurement (0x2A37)
/// - Running Speed and Cadence (0x1814) / RSC Measurement (0x2A53)
///
/// Nota: O Galaxy Watch pode não expor esses serviços nativamente.
/// Nesse caso, instale um app como "Heart Rate Monitor" ou "BLE Heart Rate"
/// no relógio para broadcast dos dados via BLE standard.
class GalaxyWatchService {
  static final GalaxyWatchService _instance = GalaxyWatchService._internal();
  factory GalaxyWatchService() => _instance;
  GalaxyWatchService._internal();

  // UUIDs padrão BLE
  static const String _heartRateServiceUuid =
      '0000180d-0000-1000-8000-00805f9b34fb';
  static const String _heartRateMeasurementUuid =
      '00002a37-0000-1000-8000-00805f9b34fb';
  static const String _rscServiceUuid =
      '00001814-0000-1000-8000-00805f9b34fb';
  static const String _rscMeasurementUuid =
      '00002a53-0000-1000-8000-00805f9b34fb';

  fbp.BluetoothDevice? _connectedWatch;
  StreamSubscription? _heartRateSubscription;
  StreamSubscription? _rscSubscription;
  StreamSubscription? _connectionStateSubscription;

  int _lastHeartRate = 0;
  int _lastStepsPerMinute = 0;

  final _watchDataController = StreamController<WatchData>.broadcast();
  final _connectionStateController = StreamController<WatchConnectionState>.broadcast();

  Stream<WatchData> get watchDataStream => _watchDataController.stream;
  Stream<WatchConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  fbp.BluetoothDevice? get connectedWatch => _connectedWatch;
  bool get isConnected => _connectedWatch != null;

  WatchConnectionState _state = WatchConnectionState.disconnected;
  WatchConnectionState get state => _state;

  void _updateState(WatchConnectionState newState) {
    _state = newState;
    _connectionStateController.add(newState);
  }

  /// Escaneia dispositivos BLE que expõem Heart Rate Service.
  Future<List<fbp.ScanResult>> scanForWatches({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    _updateState(WatchConnectionState.scanning);
    final results = <fbp.ScanResult>[];
    final seen = <String>{};

    try {
      // Scan para dispositivos com Heart Rate Service
      await fbp.FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: [
          fbp.Guid(_heartRateServiceUuid),
        ],
      );

      // Coleta resultados
      final completer = Completer<void>();
      StreamSubscription? sub;
      sub = fbp.FlutterBluePlus.scanResults.listen((scanResults) {
        for (var r in scanResults) {
          if (!seen.contains(r.device.remoteId.str)) {
            seen.add(r.device.remoteId.str);
            results.add(r);
          }
        }
      });

      await Future.delayed(timeout);
      await sub.cancel();
      await fbp.FlutterBluePlus.stopScan();

      // Se não achou com filtro HR, faz scan geral e filtra por nome
      if (results.isEmpty) {
        await _scanGeneral(results, seen, timeout);
      }
    } catch (e) {
      print('❌ GalaxyWatch: Erro ao escanear: $e');
    }

    _updateState(results.isEmpty
        ? WatchConnectionState.disconnected
        : WatchConnectionState.scanComplete);
    return results;
  }

  /// Scan geral sem filtro de serviço — útil quando o relógio não anuncia
  /// os UUIDs de serviço no advertising.
  Future<void> _scanGeneral(
    List<fbp.ScanResult> results,
    Set<String> seen,
    Duration timeout,
  ) async {
    print('🔍 GalaxyWatch: Scan geral (sem filtro de serviço)...');
    await fbp.FlutterBluePlus.startScan(timeout: timeout);

    StreamSubscription? sub;
    sub = fbp.FlutterBluePlus.scanResults.listen((scanResults) {
      for (var r in scanResults) {
        final name = r.device.platformName.toLowerCase();
        if (!seen.contains(r.device.remoteId.str) &&
            (name.contains('galaxy') ||
                name.contains('watch') ||
                name.contains('samsung') ||
                name.contains('gear') ||
                name.contains('hr') ||
                name.contains('heart'))) {
          seen.add(r.device.remoteId.str);
          results.add(r);
          print(
              '📱 GalaxyWatch: Encontrado "${r.device.platformName}" (${r.device.remoteId})');
        }
      }
    });

    await Future.delayed(timeout);
    await sub.cancel();
    await fbp.FlutterBluePlus.stopScan();
  }

  /// Conecta ao relógio e inscreve nas características de HR e RSC.
  Future<bool> connectToWatch(fbp.BluetoothDevice device) async {
    _updateState(WatchConnectionState.connecting);
    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        license: fbp.License.free,
      );
      _connectedWatch = device;

      // Monitora desconexão
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == fbp.BluetoothConnectionState.disconnected) {
          print('⚠️ GalaxyWatch: Relógio desconectou');
          _handleDisconnection();
        }
      });

      // Descobrir serviços
      print('🔍 GalaxyWatch: Descobrindo serviços...');
      List<fbp.BluetoothService> services = await device.discoverServices();

      bool foundHR = false;
      bool foundRSC = false;

      for (var service in services) {
        String serviceUuid = service.uuid.toString().toLowerCase();
        print(
            '  📋 Serviço: $serviceUuid (${service.characteristics.length} chars)');

        for (var characteristic in service.characteristics) {
          String charUuid = characteristic.uuid.toString().toLowerCase();

          // Heart Rate Measurement
          if (charUuid == _heartRateMeasurementUuid) {
            print('  ❤️ Heart Rate Measurement encontrado!');
            await _subscribeHeartRate(characteristic);
            foundHR = true;
          }

          // RSC Measurement (steps/cadence)
          if (charUuid == _rscMeasurementUuid) {
            print('  👟 RSC Measurement encontrado!');
            await _subscribeRSC(characteristic);
            foundRSC = true;
          }
        }
      }

      if (!foundHR && !foundRSC) {
        print(
            '⚠️ GalaxyWatch: Nenhum serviço HR ou RSC encontrado. '
            'Instale um app de broadcast no relógio.');
      }

      if (foundHR || foundRSC) {
        _updateState(WatchConnectionState.connected);
        print('✅ GalaxyWatch: Conectado! HR=$foundHR, RSC=$foundRSC');
      } else {
        _updateState(WatchConnectionState.connectedNoData);
        print(
            '⚠️ GalaxyWatch: Conectado mas sem serviços padrão de HR/RSC.');
      }

      return true;
    } catch (e) {
      print('❌ GalaxyWatch: Erro ao conectar: $e');
      _updateState(WatchConnectionState.error);
      return false;
    }
  }

  /// Inscreve na característica de Heart Rate Measurement (0x2A37).
  Future<void> _subscribeHeartRate(
      fbp.BluetoothCharacteristic characteristic) async {
    try {
      _heartRateSubscription =
          characteristic.onValueReceived.listen((value) {
        if (value.isEmpty) return;
        final hr = _decodeHeartRate(value);
        _lastHeartRate = hr;
        _emitWatchData();
      });

      await characteristic.setNotifyValue(true);
      print('✅ GalaxyWatch: Notificações de HR ativadas');
    } catch (e) {
      print('❌ GalaxyWatch: Erro ao subscrever HR: $e');
    }
  }

  /// Inscreve na característica de RSC Measurement (0x2A53).
  Future<void> _subscribeRSC(
      fbp.BluetoothCharacteristic characteristic) async {
    try {
      _rscSubscription =
          characteristic.onValueReceived.listen((value) {
        if (value.isEmpty) return;
        final spm = _decodeRSC(value);
        _lastStepsPerMinute = spm;
        _emitWatchData();
      });

      await characteristic.setNotifyValue(true);
      print('✅ GalaxyWatch: Notificações de RSC ativadas');
    } catch (e) {
      print('❌ GalaxyWatch: Erro ao subscrever RSC: $e');
    }
  }

  /// Decodifica Heart Rate Measurement conforme Bluetooth SIG spec.
  ///
  /// Byte 0 (flags):
  ///   - Bit 0: HR Value Format (0 = UINT8, 1 = UINT16)
  /// Byte 1 (ou 1-2): Heart Rate Value
  int _decodeHeartRate(List<int> value) {
    if (value.isEmpty) return 0;
    int flags = value[0];
    bool is16Bit = (flags & 0x01) != 0;

    if (is16Bit && value.length >= 3) {
      var byteData = ByteData.sublistView(Uint8List.fromList(value));
      return byteData.getUint16(1, Endian.little);
    } else if (value.length >= 2) {
      return value[1];
    }
    return 0;
  }

  /// Decodifica RSC Measurement conforme Bluetooth SIG spec.
  ///
  /// Byte 0 (flags):
  ///   - Bit 0: Instantaneous Stride Length Present
  ///   - Bit 1: Total Distance Present
  ///   - Bit 2: Walking or Running Status
  /// Bytes 1-2: Instantaneous Speed (1/256 m/s)
  /// Byte 3: Instantaneous Cadence (steps/minute)
  int _decodeRSC(List<int> value) {
    if (value.length < 4) return 0;
    // Byte 3: Cadência instantânea em passos por minuto
    return value[3];
  }

  void _emitWatchData() {
    final data = WatchData(
      heartRate: _lastHeartRate,
      stepsPerMinute: _lastStepsPerMinute,
    );
    _watchDataController.add(data);
  }

  void _handleDisconnection() {
    _heartRateSubscription?.cancel();
    _rscSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _connectedWatch = null;
    _lastHeartRate = 0;
    _lastStepsPerMinute = 0;
    _updateState(WatchConnectionState.disconnected);
  }

  /// Desconecta do relógio.
  Future<void> disconnectWatch() async {
    try {
      await _heartRateSubscription?.cancel();
      await _rscSubscription?.cancel();
      await _connectionStateSubscription?.cancel();
      await _connectedWatch?.disconnect();
      _connectedWatch = null;
      _lastHeartRate = 0;
      _lastStepsPerMinute = 0;
      _updateState(WatchConnectionState.disconnected);
      print('✅ GalaxyWatch: Desconectado');
    } catch (e) {
      print('❌ GalaxyWatch: Erro ao desconectar: $e');
    }
  }

  void dispose() {
    _heartRateSubscription?.cancel();
    _rscSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _watchDataController.close();
    _connectionStateController.close();
  }
}

enum WatchConnectionState {
  disconnected,
  scanning,
  scanComplete,
  connecting,
  connected,
  connectedNoData,
  error,
}
