import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/treadmill_data.dart';
import '../services/bluetooth_service.dart';
import '../services/galaxy_watch_service.dart';
import '../services/wear_companion_service.dart';

class TreadmillDataScreen extends StatefulWidget {
  final fbp.BluetoothDevice device;

  const TreadmillDataScreen({super.key, required this.device});

  @override
  State<TreadmillDataScreen> createState() => _TreadmillDataScreenState();
}

class _TreadmillDataScreenState extends State<TreadmillDataScreen> {
  late BluetoothService _bluetoothService;
  late Stream<TreadmillData> _dataStream;
  TreadmillData _lastData = TreadmillData();
  final List<FlSpot> _speedDataPoints = [];
  bool _controlAvailable = false;

  // --- Galaxy Watch (Wear OS Companion App) ---
  final WearCompanionService _wearService = WearCompanionService();
  StreamSubscription<WearSensorData>? _wearDataSubscription;
  StreamSubscription<WearConnectionState>? _wearStateSubscription;
  WearConnectionState _wearState = WearConnectionState.disconnected;
  WearSensorData _lastWearData = WearSensorData();
  bool _watchSectionExpanded = true;

  // --- Log da sessão ---
  final List<String> _sessionLog = [];
  final DateTime _sessionStart = DateTime.now();
  bool _isLogging = true;
  StreamSubscription<List<int>>? _rawBytesSubscription;

  @override
  void initState() {
    super.initState();
    _bluetoothService = BluetoothService();
    _dataStream = _bluetoothService.treadmillDataStream;
    _controlAvailable = _bluetoothService.hasControl;

    _addLogEntry('SESSION', 'Sessão iniciada - Dispositivo: ${widget.device.platformName} (${widget.device.remoteId})');

    // Gravar bytes brutos no log
    _rawBytesSubscription = _bluetoothService.rawBytesStream.listen((bytes) {
      if (!_isLogging) return;
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      _addLogEntry('RAW', 'BYTES (${bytes.length}): $hex');
    });

    // Wear OS: ouvir estado de conexão
    _wearStateSubscription =
        _wearService.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() => _wearState = state);
      }
    });

    // Wear OS: ouvir dados dos sensores
    _wearDataSubscription = _wearService.sensorDataStream.listen((data) {
      if (mounted) {
        setState(() => _lastWearData = data);
        
        // Sincronizar dados do relógio com a esteira para os charts/logs gerais
        _lastData.heartRate = data.heartRate;
        // opcional: se a esteira não reporta steps, vc pode logar tbm
        
        _logWearData(data);
      }
    });

    // Automáticamente inicializa na abertura
    _wearService.initialize();

    // Solicita permissão de controle para a esteira assim que a tela abre
    _requestControl();
  }

  Future<void> _requestControl() async {
    _addLogEntry('CMD', 'Solicitando controle da esteira...');
    await _bluetoothService.requestControl();
    if (mounted) {
      setState(() {
        _controlAvailable = _bluetoothService.hasControl;
      });
      _addLogEntry('CMD', 'Controle disponível: $_controlAvailable');
    }
  }

  // --- Métodos de log ---
  void _addLogEntry(String tag, String message) {
    final now = DateTime.now();
    final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    _sessionLog.add('[$timestamp] [$tag] $message');
  }

  void _logDataUpdate(TreadmillData data) {
    if (!_isLogging) return;
    _addLogEntry('DATA',
      'vel=${data.speed.toStringAsFixed(1)} km/h | '
      'incl=${data.incline.toStringAsFixed(1)}/15 | '
      'dist=${data.distance.toStringAsFixed(0)} m | '
      'cal=${data.calories} | '
      'fc=${data.heartRate} bpm | '
      'tempo=${data.time} s | '
      'running=${data.isRunning}');
  }

  void _logWearData(WearSensorData data) {
    if (!_isLogging) return;
    _addLogEntry('WEAR',
      'hr=${data.heartRate} bpm | '
      'steps=${data.steps}');
  }

  // --- Wear OS methods ---
  Future<void> _scanForWatch() async {
    _addLogEntry('WEAR', 'Verificando conexão com app do relógio...');
    await _wearService.initialize();
  }

  Future<void> _disconnectWatch() async {
    _addLogEntry('WEAR', 'Desconectando do relógio...');
    await _wearService.disconnect();
    if (mounted) {
      setState(() {
        _lastWearData = WearSensorData();
      });
    }
  }

  Future<void> _exportLog() async {
    if (_sessionLog.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum log para exportar')),
        );
      }
      return;
    }

    try {
      final header = [
        '=== Log de Sessão da Esteira ===' ,
        'Dispositivo: ${widget.device.platformName} (${widget.device.remoteId})',
        'Início: ${_sessionStart.toString().split('.')[0]}',
        'Exportado: ${DateTime.now().toString().split('.')[0]}',
        'Total de entradas: ${_sessionLog.length}',
        '================================',
        '',
      ];

      final logString = [...header, ..._sessionLog].join('\n');

      final directory = await getTemporaryDirectory();
      final fileName = 'treadmill_session_${_sessionStart.millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(logString);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Log da sessão - ${widget.device.platformName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar log: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await _bluetoothService.disconnectDevice();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    double km = meters / 1000;
    return km.toStringAsFixed(2);
  }

  void _adjustSpeed(double delta) {
    double newSpeed = _lastData.speed + delta;
    if (newSpeed < 0.5) newSpeed = 0.5;
    if (newSpeed > 18.0) newSpeed = 18.0;
    _addLogEntry('CMD', 'Ajustar velocidade: ${_lastData.speed.toStringAsFixed(1)} → ${newSpeed.toStringAsFixed(1)} km/h');
    _bluetoothService.setTargetSpeed(newSpeed);
  }

  void _adjustIncline(double delta) {
    double newIncline = _lastData.incline + delta;
    newIncline = (newIncline * 2).round() / 2.0;
    if (newIncline < 0) newIncline = 0.0;
    if (newIncline > 15) newIncline = 15.0;
    _addLogEntry('CMD', 'Ajustar inclinação: ${_lastData.incline.toStringAsFixed(1)} → ${newIncline.toStringAsFixed(1)}/15');
    _bluetoothService.setTargetIncline(newIncline);
  }

  Future<void> _startOrResumeTreadmill() async {
    _addLogEntry('CMD', 'Iniciar esteira');
    await _bluetoothService.requestControl();
    if (_lastData.speed <= 0) {
      await _bluetoothService.setTargetSpeed(1.0);
    }
  }

  Future<void> _stopTreadmill() async {
    _addLogEntry('CMD', 'Parar esteira');
    await _bluetoothService.setTargetSpeed(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _disconnect();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.platformName.isNotEmpty
              ? widget.device.platformName
              : 'Esteira'),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            // Toggle logging
            IconButton(
              icon: Icon(_isLogging ? Icons.fiber_manual_record : Icons.fiber_manual_record_outlined,
                color: _isLogging ? Colors.red : Colors.grey,
              ),
              onPressed: () {
                setState(() => _isLogging = !_isLogging);
                _addLogEntry('SESSION', _isLogging ? 'Gravação retomada' : 'Gravação pausada');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isLogging ? '🔴 Gravando log' : '⏸️ Log pausado'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              tooltip: _isLogging ? 'Pausar log' : 'Retomar log',
            ),
            // Exportar/compartilhar log
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _exportLog,
              tooltip: 'Exportar log da sessão',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _disconnect,
            ),
          ],
        ),
        body: StreamBuilder<TreadmillData>(
          stream: _dataStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _lastData = snapshot.data!;
              // Gravar dados no log
              _logDataUpdate(_lastData);
              // Adiciona novo ponto de velocidade ao gráfico
              _speedDataPoints.add(FlSpot(
                _lastData.time.toDouble(),
                _lastData.speed,
              ));
            }

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status de conexão e controle
                    Card(
                      color: Colors.green.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Conectado',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _controlAvailable ? Colors.blue.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _controlAvailable ? Icons.gamepad : Icons.gamepad_outlined,
                                    size: 16,
                                    color: _controlAvailable ? Colors.blue.shade700 : Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _controlAvailable ? 'Controle Ativo' : 'Sem Controle',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _controlAvailable ? Colors.blue.shade700 : Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Velocidade - Destaque principal
                    _buildMainDataCard(
                      title: 'Velocidade',
                      value: _lastData.speed.toStringAsFixed(2),
                      unit: 'km/h',
                      icon: Icons.speed,
                      color: Colors.blue,
                      onIncrease: () => _adjustSpeed(0.5),
                      onDecrease: () => _adjustSpeed(-0.5),
                    ),
                    const SizedBox(height: 16),
                    // Gráfico de velocidade
                    _buildSpeedChart(),
                    const SizedBox(height: 16),
                    // Inclinação (nível 0-15)
                    _buildDataCard(
                      title: 'Inclinação',
                      value: _lastData.incline.toStringAsFixed(1),
                      unit: '',
                      icon: Icons.trending_up,
                      color: Colors.orange,
                      onIncrease: () => _adjustIncline(0.5),
                      onDecrease: () => _adjustIncline(-0.5),
                    ),
                    const SizedBox(height: 16),
                    // Grid de dados
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactDataCard(
                            title: 'Tempo',
                            value: _formatTime(_lastData.time),
                            icon: Icons.timer,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCompactDataCard(
                            title: 'Calorias',
                            value: _lastData.calories.toString(),
                            icon: Icons.local_fire_department,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactDataCard(
                            title: 'Distância',
                            value: _formatDistance(_lastData.distance),
                            unit: 'km',
                            icon: Icons.map,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCompactDataCard(
                            title: 'Frequência Cardíaca',
                            value: _lastData.heartRate.toString(),
                            unit: 'bpm',
                            icon: Icons.favorite,
                            color: Colors.pink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // ==========================================
                    // Galaxy Watch Section
                    // ==========================================
                    _buildWatchSection(),
                    const SizedBox(height: 16),
                    // Status de execução
                    _buildStatusCard(
                      status: _lastData.isRunning ? 'Em Execução' : 'Parado',
                      isRunning: _lastData.isRunning,
                    ),
                    const SizedBox(height: 24),
                    // Botões de controle (Iniciar/Parar)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _lastData.isRunning ? null : _startOrResumeTreadmill,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Iniciar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _lastData.isRunning ? _stopTreadmill : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Parar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Botão de desconexão
                    ElevatedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.bluetooth_disabled),
                      label: const Text('Desconectar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpeedChart() {
    return SizedBox(
      height: 200,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: const Color(0xff37434d), width: 1),
              ),
              minX: 0,
              // maxX: (_lastData.time > 300) ? _lastData.time.toDouble() : 300, // 5 minutos
              minY: 0,
              maxY: 20, // Velocidade máxima da esteira
              lineBarsData: [
                LineChartBarData(
                  spots: _speedDataPoints,
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withAlpha(77),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainDataCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    VoidCallback? onIncrease,
    VoidCallback? onDecrease,
  }) {
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withAlpha(51), color.withAlpha(13)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (onDecrease != null)
                  IconButton.filledTonal(
                    onPressed: onDecrease,
                    icon: const Icon(Icons.remove),
                    color: color,
                  ),
                const SizedBox(width: 16),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(width: 16),
                if (onIncrease != null)
                  IconButton.filledTonal(
                    onPressed: onIncrease,
                    icon: const Icon(Icons.add),
                    color: color,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    VoidCallback? onIncrease,
    VoidCallback? onDecrease,
  }) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withAlpha(26), color.withAlpha(5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onIncrease != null && onDecrease != null)
              Row(
                children: [
                  IconButton(
                    onPressed: onDecrease,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: color,
                  ),
                  IconButton(
                    onPressed: onIncrease,
                    icon: const Icon(Icons.add_circle_outline),
                    color: color,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDataCard({
    required String title,
    required String value,
    String? unit,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withAlpha(26), color.withAlpha(5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (unit != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    unit,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String status,
    required bool isRunning,
  }) {
    return Card(
      color: isRunning ? Colors.green.shade100 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isRunning ? Icons.play_circle_filled : Icons.pause_circle_filled,
              color: isRunning ? Colors.green : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              status,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isRunning ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Galaxy Watch UI Builders ---

  Widget _buildWatchSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.indigo.shade50,
              Colors.deepPurple.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Header com toggle
            InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              onTap: () {
                setState(() =>
                    _watchSectionExpanded = !_watchSectionExpanded);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _watchConnected
                            ? Colors.green.withAlpha(40)
                            : Colors.indigo.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.watch,
                        color: _watchConnected
                            ? Colors.green
                            : Colors.indigo,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Galaxy Watch',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _watchStatusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: _watchStatusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Indicador de conexão
                    if (_watchConnected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Online',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      _watchSectionExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            // Conteúdo expandido
            if (_watchSectionExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Dados do watch (se conectado)
                    if (_watchConnected) ...[
                      _buildWatchDataRow(),
                      const SizedBox(height: 12),
                      // Botão desconectar / recalibrar
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _disconnectWatch,
                          icon: const Icon(Icons.sync_disabled, size: 18),
                          label: const Text('Parar Sincronização'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ]
                    // Scan/Connect UI
                    else ...[
                      // Botão de scan
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _wearState ==
                                  WearConnectionState.searching
                              ? null
                              : _scanForWatch,
                          icon: _wearState ==
                                  WearConnectionState.searching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.watch, size: 18),
                          label: Text(
                            _wearState ==
                                    WearConnectionState.searching
                                ? 'Buscando conexão...'
                                : 'Conectar ao Companion App',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.indigo.shade700,
                                size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Abra o app do Treadmill no seu Galaxy Watch '
                                'para iniciar a transmissão de Heart Rate e Passos.\n\n'
                                'Eles serão anexados à sessão da sua esteira.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWatchDataRow() {
    return Row(
      children: [
        // Heart Rate card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade50,
                  Colors.pink.shade50,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withAlpha(40),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.favorite,
                  color: Colors.red.shade400,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Freq. Cardíaca',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _lastWearData.heartRate > 0
                          ? _lastWearData.heartRate.toString()
                          : '--',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'bpm',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Steps per minute card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.cyan.shade50,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withAlpha(40),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.directions_walk,
                  color: Colors.blue.shade400,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Passos (Sensors)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _lastWearData.steps > 0
                          ? _lastWearData.steps.toString()
                          : '--',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'passos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool get _watchConnected =>
      _wearState == WearConnectionState.connected;

  String get _watchStatusText {
    switch (_wearState) {
      case WearConnectionState.disconnected:
        return 'Modo Companion Offline';
      case WearConnectionState.searching:
        return 'Procurando Relógio...';
      case WearConnectionState.connected:
        return 'Conectado (Via Data Layer)';
      case WearConnectionState.error:
        return 'Erro de Conexão';
    }
  }

  Color get _watchStatusColor {
    switch (_wearState) {
      case WearConnectionState.disconnected:
        return Colors.grey;
      case WearConnectionState.searching:
        return Colors.indigo;
      case WearConnectionState.connected:
        return Colors.green;
      case WearConnectionState.error:
        return Colors.red;
    }
  }

  @override
  void dispose() {
    _addLogEntry('SESSION', 'Sessão encerrada');
    _rawBytesSubscription?.cancel();
    _wearDataSubscription?.cancel();
    _wearStateSubscription?.cancel();
    // Usa cancelSubscriptions() em vez de dispose() para não destruir o singleton
    _bluetoothService.cancelSubscriptions();
    super.dispose();
  }
}
