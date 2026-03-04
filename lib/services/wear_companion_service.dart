import 'dart:async';
import 'dart:convert';
import 'package:flutter_wear_os_connectivity/flutter_wear_os_connectivity.dart';
import '../models/treadmill_data.dart';

/// Dados recebidos diretamente do relógio Wear OS nativo.
class WearSensorData {
  final int heartRate;
  final int steps;
  final DateTime timestamp;

  WearSensorData({
    this.heartRate = 0,
    this.steps = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum WearConnectionState {
  disconnected,
  searching,
  connected,
  error,
}

/// Serviço de integração direta (Companion App) via Wearable Data Layer API.
/// Ele escuta mensagens/dados enviados pelo aplicativo nativo do relógio.
class WearCompanionService {
  static final WearCompanionService _instance = WearCompanionService._internal();
  factory WearCompanionService() => _instance;
  WearCompanionService._internal();

  final FlutterWearOsConnectivity _wearOsConnectivity = FlutterWearOsConnectivity();
  
  StreamSubscription<WearDataMessage>? _messageSubscription;
  StreamSubscription<List<WearDataItem>>? _dataItemSubscription;

  int _lastHeartRate = 0;
  int _lastSteps = 0;

  final _sensorDataController = StreamController<WearSensorData>.broadcast();
  final _connectionStateController = StreamController<WearConnectionState>.broadcast();

  Stream<WearSensorData> get sensorDataStream => _sensorDataController.stream;
  Stream<WearConnectionState> get connectionStateStream => _connectionStateController.stream;

  WearConnectionState _state = WearConnectionState.disconnected;
  WearConnectionState get state => _state;

  List<WearDeviceItem> _connectedDevices = [];

  void _updateState(WearConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _connectionStateController.add(newState);
    }
  }

  /// Inicializa e verifica a conectividade com o relógio.
  Future<void> initialize() async {
    _updateState(WearConnectionState.searching);
    try {
      await _wearOsConnectivity.configureWearableAPI();
      
      // Buscar dispositivos conectados
      _connectedDevices = await _wearOsConnectivity.getConnectedDevices();
      
      if (_connectedDevices.isNotEmpty) {
        print('⌚ WearOS: Dispositivos conectados: ${_connectedDevices.map((d) => d.name).join(', ')}');
        _updateState(WearConnectionState.connected);
        _startListening();
      } else {
        print('⌚ WearOS: Nenhum dispositivo pareado/conectado encontrado.');
        _updateState(WearConnectionState.disconnected);
      }
    } catch (e) {
      print('❌ WearOS: Erro ao inicializar conectividade: $e');
      _updateState(WearConnectionState.error);
    }
  }

  /// Começa a escutar mensagens no path "/sensor_data".
  void _startListening() {
    print('⌚ WearOS: Escutando mensagens do relógio...');
    
    // Escutar mensagens curtas (MessageClient)
    _messageSubscription = _wearOsConnectivity.messageReceived().listen((message) {
      if (message.path == '/sensor_data') {
        _handleSensorMessage(message.data);
      }
    });

    // Escutar DataItems sincronizados (DataClient)
    // Opcional, mas util caso o relógio mande como DataItem pra garantir entrega
    _wearOsConnectivity.dataChanged().listen((dataEvents) {
      for (var item in dataEvents) {
        if (item.mapData.containsKey('heart_rate') || item.mapData.containsKey('steps')) {
          final hr = item.mapData['heart_rate'] as int? ?? _lastHeartRate;
          final steps = item.mapData['steps'] as int? ?? _lastSteps;
          
          _lastHeartRate = hr;
          _lastSteps = steps;
          
          _sensorDataController.add(WearSensorData(
            heartRate: _lastHeartRate,
            steps: _lastSteps,
          ));
        }
      }
    });
  }

  /// Processa payload via MessageClient (assumindo JSON UTF-8)
  void _handleSensorMessage(List<int> payload) {
    try {
      final jsonString = utf8.decode(payload);
      final data = jsonDecode(jsonString);
      
      if (data != null && data is Map) {
        if (data.containsKey('heart_rate')) {
          _lastHeartRate = data['heart_rate'] as int;
        }
        if (data.containsKey('steps')) {
          _lastSteps = data['steps'] as int;
        }
        
        _sensorDataController.add(WearSensorData(
          heartRate: _lastHeartRate,
          steps: _lastSteps,
        ));
      }
    } catch (e) {
      print('❌ WearOS: Falha ao decodificar payload de mensagem: $e');
    }
  }

  Future<void> disconnect() async {
    _messageSubscription?.cancel();
    _dataItemSubscription?.cancel();
    _updateState(WearConnectionState.disconnected);
  }

  void dispose() {
    _messageSubscription?.cancel();
    _dataItemSubscription?.cancel();
    _sensorDataController.close();
    _connectionStateController.close();
  }
}
