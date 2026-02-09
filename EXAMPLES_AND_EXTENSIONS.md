# 🚀 Exemplos de Uso e Extensões

Este arquivo contém exemplos de como usar e estender a aplicação Treadmill Monitor.

---

## 📚 Exemplos Básicos

### Usando o BluetoothService Diretamente

```dart
import 'package:treadmill/services/bluetooth_service.dart';
import 'package:treadmill/models/treadmill_data.dart';

void main() {
  final bluetoothService = BluetoothService();
  
  // Escanear dispositivos
  var devices = await bluetoothService.scanForDevices();
  
  for (var device in devices) {
    print('Dispositivo: ${device.platformName}');
    print('MAC: ${device.remoteId}');
  }
}
```

### Conectar e Escutar Dados

```dart
// Conectar ao dispositivo
bool connected = await bluetoothService.connectToDevice(devices[0]);

if (connected) {
  // Escutar dados em tempo real
  bluetoothService.treadmillDataStream.listen((TreadmillData data) {
    print('Velocidade: ${data.speed} km/h');
    print('Inclinação: ${data.incline}%');
    print('Calorias: ${data.calories}');
    print('Distância: ${data.distance / 1000} km');
    print('Tempo: ${_formatSeconds(data.time)}');
    print('Frequência Cardíaca: ${data.heartRate} bpm');
    print('Status: ${data.isRunning ? 'Executando' : 'Parado'}');
  });
}
```

---

## 🎨 Personalizações de UI

### Adicionar Gráfico de Velocidade

```dart
import 'package:fl_chart/fl_chart.dart';

class SpeedChart extends StatefulWidget {
  final BluetoothService bluetoothService;
  
  const SpeedChart({required this.bluetoothService});
  
  @override
  State<SpeedChart> createState() => _SpeedChartState();
}

class _SpeedChartState extends State<SpeedChart> {
  final List<FlSpot> speedPoints = [];
  int secondsElapsed = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeChart();
  }
  
  void _initializeChart() {
    bluetoothService.treadmillDataStream.listen((data) {
      setState(() {
        speedPoints.add(FlSpot(secondsElapsed.toDouble(), data.speed));
        secondsElapsed++;
        
        // Manter apenas últimos 60 segundos
        if (speedPoints.length > 60) {
          speedPoints.removeAt(0);
        }
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        spots: speedPoints,
        titlesData: FlTitlesData(show: true),
      ),
    );
  }
}
```

### Theme Personalizado

```dart
final customTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
);
```

---

## 🔧 Extensões do BluetoothService

### Adicionar Suporte a Controle Remoto

```dart
extension TreadmillControl on BluetoothService {
  Future<bool> setSpeed(double speedKmh) async {
    try {
      // UUID da característica de velocidade (exemplo)
      final characteristic = await _findCharacteristic(
        '00002AD6-0000-1000-8000-00805F9B34FB'
      );
      
      // Converter para formato FTMS (0.01 km/h)
      int speedValue = (speedKmh * 100).toInt();
      List<int> bytes = [
        speedValue & 0xFF,
        (speedValue >> 8) & 0xFF,
      ];
      
      await characteristic?.write(bytes);
      return true;
    } catch (e) {
      print('Erro ao definir velocidade: $e');
      return false;
    }
  }
  
  Future<bool> setIncline(double inclinePercent) async {
    try {
      final characteristic = await _findCharacteristic(
        '00002AD7-0000-1000-8000-00805F9B34FB'
      );
      
      // Converter para formato FTMS (0.1%)
      int inclineValue = (inclinePercent * 10).toInt();
      List<int> bytes = [
        inclineValue & 0xFF,
        (inclineValue >> 8) & 0xFF,
      ];
      
      await characteristic?.write(bytes);
      return true;
    } catch (e) {
      print('Erro ao definir inclinação: $e');
      return false;
    }
  }
}
```

---

## 📊 Análise de Dados

### Calculadora de Métricas

```dart
class TreadmillMetrics {
  final TreadmillData data;
  
  TreadmillMetrics(this.data);
  
  // Ritmo em minutos por km
  double get pace {
    if (data.distance == 0) return 0;
    return (data.time * 60) / (data.distance / 1000);
  }
  
  // Velocidade média
  double get averageSpeed {
    if (data.time == 0) return 0;
    return (data.distance / 1000) / (data.time / 3600);
  }
  
  // Calorias por minuto
  double get caloriesPerMinute {
    if (data.time == 0) return 0;
    return (data.calories * 60) / data.time;
  }
  
  // Equivalente em corrida (METs)
  double get mets {
    return (data.speed * 0.0276) + 3.5;
  }
  
  // Zona de frequência cardíaca (% máxima)
  double get heartRateZone {
    const maxHeartRate = 220;
    final age = 30; // Assumir idade
    final maxHR = maxHeartRate - age;
    return (data.heartRate / maxHR) * 100;
  }
}

// Uso
void main() {
  final data = TreadmillData(
    speed: 10.5,
    distance: 5000,
    time: 1800, // 30 minutos
    calories: 300,
    heartRate: 145,
  );
  
  final metrics = TreadmillMetrics(data);
  
  print('Ritmo: ${metrics.pace.toStringAsFixed(2)} min/km');
  print('Velocidade média: ${metrics.averageSpeed.toStringAsFixed(2)} km/h');
  print('Calorias/min: ${metrics.caloriesPerMinute.toStringAsFixed(2)}');
  print('METs: ${metrics.mets.toStringAsFixed(2)}');
  print('Zona FC: ${metrics.heartRateZone.toStringAsFixed(1)}%');
}
```

---

## 💾 Persistência de Dados

### Salvar Sessão em Local Storage

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SessionManager {
  static const String _sessionKey = 'treadmill_session';
  
  static Future<void> saveSession(TreadmillData data) async {
    final prefs = await SharedPreferences.getInstance();
    
    final sessionData = {
      'speed': data.speed,
      'incline': data.incline,
      'time': data.time,
      'calories': data.calories,
      'distance': data.distance,
      'heartRate': data.heartRate,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await prefs.setString(_sessionKey, jsonEncode(sessionData));
  }
  
  static Future<TreadmillData?> loadLastSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_sessionKey);
    
    if (jsonString == null) return null;
    
    final data = jsonDecode(jsonString);
    return TreadmillData(
      speed: data['speed'],
      incline: data['incline'],
      time: data['time'],
      calories: data['calories'],
      distance: data['distance'],
      heartRate: data['heartRate'],
    );
  }
}
```

---

## 📱 Integração com Google Fit

```dart
import 'package:health/health.dart';

class FitIntegration {
  final Health health = Health();
  
  Future<void> sendToGoogleFit(TreadmillData data) async {
    final now = DateTime.now();
    
    final workout = HealthDataPoint(
      value: data.distance,
      type: HealthDataType.WORKOUT,
      unit: HealthDataUnit.KILOMETER,
      dateFrom: now,
      dateTo: now,
      workoutActivityType: WorkoutActivityType.RUNNING,
    );
    
    await health.writeHealthData(
      value: data.distance,
      type: HealthDataType.DISTANCE_DELTA,
      unit: HealthDataUnit.METER,
      dateFrom: now,
      dateTo: now,
    );
    
    await health.writeHealthData(
      value: data.calories,
      type: HealthDataType.ACTIVE_ENERGY_BURNED,
      unit: HealthDataUnit.KILOCALORIE,
      dateFrom: now,
      dateTo: now,
    );
  }
}
```

---

## 🔔 Notificações

### Alertas de Frequência Cardíaca Alta

```dart
class HeartRateMonitor {
  final BluetoothService bluetoothService;
  final int maxHeartRate = 180;
  
  HeartRateMonitor(this.bluetoothService);
  
  void startMonitoring() {
    bluetoothService.treadmillDataStream.listen((data) {
      if (data.heartRate > maxHeartRate) {
        _showAlert(
          'Frequência cardíaca alta!',
          'Sua FC está em ${data.heartRate} bpm. Considere diminuir a intensidade.',
        );
      }
    });
  }
  
  void _showAlert(String title, String message) {
    // Implementar com flutter_local_notifications
    // ou seu sistema de notificações preferido
  }
}
```

---

## 🧪 Testes Unitários

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TreadmillData', () {
    test('deve criar dados com valores padrão', () {
      final data = TreadmillData();
      
      expect(data.speed, 0.0);
      expect(data.incline, 0.0);
      expect(data.time, 0);
      expect(data.calories, 0);
      expect(data.distance, 0.0);
      expect(data.heartRate, 0);
      expect(data.isRunning, false);
    });
    
    test('deve criar dados com valores customizados', () {
      final data = TreadmillData(
        speed: 12.5,
        incline: 5.0,
        time: 600,
        calories: 150,
        distance: 2000,
        heartRate: 140,
        isRunning: true,
      );
      
      expect(data.speed, 12.5);
      expect(data.incline, 5.0);
      expect(data.time, 600);
      expect(data.calories, 150);
      expect(data.distance, 2000);
      expect(data.heartRate, 140);
      expect(data.isRunning, true);
    });
  });
  
  group('BluetoothService', () {
    test('deve ser singleton', () {
      final service1 = BluetoothService();
      final service2 = BluetoothService();
      
      expect(identical(service1, service2), true);
    });
  });
}
```

---

## 🎯 Casos de Uso Avançados

### Modo de Treino Intervalado

```dart
class IntervalTraining {
  final BluetoothService service;
  List<Interval> intervals = [];
  int currentIntervalIndex = 0;
  
  IntervalTraining(this.service);
  
  void addInterval({
    required double targetSpeed,
    required int durationSeconds,
  }) {
    intervals.add(Interval(
      targetSpeed: targetSpeed,
      duration: durationSeconds,
    ));
  }
  
  Future<void> startTraining() async {
    for (int i = 0; i < intervals.length; i++) {
      currentIntervalIndex = i;
      final interval = intervals[i];
      
      // Aqui você chamaria setSpeed se houver suporte
      // await service.setSpeed(interval.targetSpeed);
      
      await Future.delayed(Duration(seconds: interval.duration));
    }
  }
}

class Interval {
  final double targetSpeed;
  final int duration;
  
  Interval({
    required this.targetSpeed,
    required this.duration,
  });
}
```

---

## 🔐 Segurança

### Validação de Dados

```dart
class DataValidator {
  static bool isValidTreadmillData(TreadmillData data) {
    // Velocidade razoável (0-25 km/h)
    if (data.speed < 0 || data.speed > 25) return false;
    
    // Inclinação razoável (-5% a 15%)
    if (data.incline < -5 || data.incline > 15) return false;
    
    // Frequência cardíaca razoável (40-220 bpm)
    if (data.heartRate < 40 || data.heartRate > 220) return false;
    
    // Calorias não devem ser negativas
    if (data.calories < 0) return false;
    
    return true;
  }
}
```

---

## 🚀 Performance

### Otimizar Atualizações de UI

```dart
class OptimizedTreadmillDataScreen extends StatefulWidget {
  @override
  State<OptimizedTreadmillDataScreen> createState() =>
      _OptimizedTreadmillDataScreenState();
}

class _OptimizedTreadmillDataScreenState
    extends State<OptimizedTreadmillDataScreen> {
  late Stream<TreadmillData> _throttledStream;
  
  @override
  void initState() {
    super.initState();
    
    // Atualizar UI apenas a cada 500ms
    _throttledStream = BluetoothService()
        .treadmillDataStream
        .throttleTime(const Duration(milliseconds: 500));
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TreadmillData>(
      stream: _throttledStream,
      builder: (context, snapshot) {
        // UI rebuilds only every 500ms
        return Text('Speed: ${snapshot.data?.speed}');
      },
    );
  }
}
```

---

Esses exemplos fornecem uma base sólida para estender e personalizar a aplicação conforme suas necessidades!
