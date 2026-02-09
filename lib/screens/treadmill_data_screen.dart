import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../models/treadmill_data.dart';
import '../services/bluetooth_service.dart';

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

  @override
  void initState() {
    super.initState();
    _bluetoothService = BluetoothService();
    _dataStream = _bluetoothService.treadmillDataStream;
    // Solicita permissão de controle para a esteira assim que a tela abre
    _bluetoothService.requestControl();
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
    if (newSpeed > 20.0) newSpeed = 20.0; // Limite de segurança exemplo
    _bluetoothService.setTargetSpeed(newSpeed);
  }

  void _adjustIncline(double delta) {
    double newIncline = _lastData.incline + delta;
    // Arredondar para evitar dízimas flutuantes estranhas na UI antes do update
    newIncline = (newIncline * 10).round() / 10;
    if (newIncline < 0) newIncline = 0;
    if (newIncline > 15) newIncline = 15; // Limite exemplo
    _bluetoothService.setTargetIncline(newIncline);
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
              // Adiciona novo ponto de velocidade ao gráfico
              // Usa o tempo como eixo X e a velocidade como eixo Y
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
                    // Status de conexão
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
                    // Inclinação
                    _buildDataCard(
                      title: 'Inclinação',
                      value: _lastData.incline.toStringAsFixed(1),
                      unit: '%',
                      icon: Icons.trending_up,
                      color: Colors.orange,
                      onIncrease: () => _adjustIncline(1.0),
                      onDecrease: () => _adjustIncline(-1.0),
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
                    const SizedBox(height: 16),
                    // Status de execução
                    _buildStatusCard(
                      status: _lastData.isRunning ? 'Em Execução' : 'Parado',
                      isRunning: _lastData.isRunning,
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

  @override
  void dispose() {
    _bluetoothService.dispose();
    super.dispose();
  }
}
