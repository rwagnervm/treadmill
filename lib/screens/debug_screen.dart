import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../services/bluetooth_service.dart';
import '../models/treadmill_data.dart';

class DebugScreen extends StatefulWidget {
  final fbp.BluetoothDevice device;

  const DebugScreen({super.key, required this.device});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  late BluetoothService _bluetoothService;
  final List<DebugLog> _logs = [];
  late Stream<TreadmillData> _dataStream;
  bool _isMonitoring = false;

  // Streams para logs de debug
  late StreamController<DebugLog> _logController;

  @override
  void initState() {
    super.initState();
    _bluetoothService = BluetoothService();
    _dataStream = _bluetoothService.treadmillDataStream;
    _logController = StreamController<DebugLog>.broadcast();

    _addLog('Debug iniciado para ${widget.device.platformName}', LogType.info);
    _addLog('MAC: ${widget.device.remoteId}', LogType.info);
    
    _startMonitoring();
  }

  void _startMonitoring() {
    setState(() => _isMonitoring = true);
    
    _addLog('Iniciando monitoramento...', LogType.info);
    
    // Monitorar dados FTMS decodificados
    _dataStream.listen(
      (data) {
        _addLog(
          'TreadmillData recebido: '
          'vel=${data.speed}, incl=${data.incline}, '
          'tempo=${data.time}, cal=${data.calories}, '
          'dist=${data.distance}, fc=${data.heartRate}, '
          'running=${data.isRunning}',
          LogType.data,
        );
      },
      onError: (error) {
        _addLog('ERRO no stream: $error', LogType.error);
      },
    );

    // Monitorar bytes brutos
    _bluetoothService.rawBytesStream.listen(
      (bytes) {
        final hexString = bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ');
        _addLog('RAW BYTES (${bytes.length}): $hexString', LogType.data);
        
        // Tentar decodificar
        _decodeManualFTMS(bytes);
      },
      onError: (error) {
        _addLog('ERRO ao receber bytes brutos: $error', LogType.error);
      },
    );

    _addLog('StreamListener ativado para dados FTMS', LogType.info);
  }

  void _addLog(String message, LogType type) {
    final log = DebugLog(
      message: message,
      timestamp: DateTime.now(),
      type: type,
    );
    
    setState(() {
      _logs.add(log);
      // Manter apenas os últimos 500 logs para não consumir muita memória
      if (_logs.length > 500) {
        _logs.removeAt(0);
      }
    });

    _logController.add(log);
  }

  Future<void> _discoverServices() async {
    try {
      _addLog('Descobrindo serviços...', LogType.info);
      
      final services = await widget.device.discoverServices();
      _addLog('Serviços encontrados: ${services.length}', LogType.data);

      for (var service in services) {
        final uuid = service.uuid.toString().toUpperCase();
        _addLog('  📦 Serviço: $uuid (${service.characteristics.length} características)', LogType.data);

        for (var characteristic in service.characteristics) {
          final charUuid = characteristic.uuid.toString().toUpperCase();
          final props = characteristic.properties;
          
          _addLog(
            '    ├─ Characteristic: $charUuid\n'
            '    │  Read: ${props.read}, Write: ${props.write}, '
            'Notify: ${props.notify}, Indicate: ${props.indicate}',
            LogType.data,
          );
        }
      }
    } catch (e) {
      _addLog('ERRO ao descobrir serviços: $e', LogType.error);
    }
  }

  Future<void> _testFTMSNotifications() async {
    try {
      _addLog('Testando notificações FTMS...', LogType.info);
      
      final services = await widget.device.discoverServices();
      
      // Procurar serviço FTMS (0x181E)
      for (var service in services) {
        if (service.uuid.toString().toLowerCase().contains('181e')) {
          _addLog('✅ Serviço FTMS encontrado!', LogType.success);
          
          for (var characteristic in service.characteristics) {
            final uuid = characteristic.uuid.toString().toLowerCase();
            
            // Treadmill Data (0x2AD1)
            if (uuid.contains('2ad1')) {
              _addLog('✅ Característica Treadmill Data encontrada!', LogType.success);
              
              // Tentar habilitar notificações
              try {
                await characteristic.setNotifyValue(true);
                _addLog('✅ Notificações habilitadas!', LogType.success);
                
                // Escutar valores
                characteristic.onValueReceived.listen(
                  (value) {
                    _addLog(
                      'RAW BYTES recebidos (${value.length} bytes): '
                      '${value.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}',
                      LogType.data,
                    );
                    
                    // Tentar decodificar manualmente
                    _decodeManualFTMS(value);
                  },
                  onError: (error) {
                    _addLog('ERRO ao receber valores: $error', LogType.error);
                  },
                );
              } catch (e) {
                _addLog('❌ Erro ao habilitar notificações: $e', LogType.error);
              }
            }
          }
        }
      }
    } catch (e) {
      _addLog('ERRO ao testar FTMS: $e', LogType.error);
    }
  }

  void _decodeManualFTMS(List<int> value) {
    try {
      if (value.isEmpty) {
        _addLog('  ⚠️ Valor vazio recebido', LogType.warning);
        return;
      }

      StringBuffer decoded = StringBuffer('\n  📊 Decodificação FTMS:\n');
      
      int flags = value[0];
      decoded.write('  Flags: 0x${flags.toRadixString(16).toUpperCase()} (');
      
      if ((flags & 0x01) != 0) decoded.write('Speed ');
      if ((flags & 0x02) != 0) decoded.write('Incline ');
      if ((flags & 0x04) != 0) decoded.write('Ramp ');
      if ((flags & 0x08) != 0) decoded.write('Distance ');
      if ((flags & 0x10) != 0) decoded.write('Time ');
      if ((flags & 0x20) != 0) decoded.write('Calories ');
      if ((flags & 0x40) != 0) decoded.write('HR ');
      if ((flags & 0x80) != 0) decoded.write('Status');
      
      decoded.write(')\n');

      int offset = 1;

      // Speed
      if ((flags & 0x01) != 0 && offset + 1 < value.length) {
        int speed = value[offset] | (value[offset + 1] << 8);
        double speedKmh = speed * 0.01;
        decoded.write('  Velocidade: $speedKmh km/h (raw: 0x${speed.toRadixString(16).toUpperCase()})\n');
        offset += 2;
      }

      // Incline
      if ((flags & 0x02) != 0 && offset + 1 < value.length) {
        int incline = value[offset] | (value[offset + 1] << 8);
        if (incline & 0x8000 != 0) incline = -(0x10000 - incline);
        double inclinePercent = incline * 0.1;
        decoded.write('  Inclinação: $inclinePercent% (raw: 0x${incline.toRadixString(16).toUpperCase()})\n');
        offset += 2;
      }

      // Ramp Angle
      if ((flags & 0x04) != 0 && offset + 1 < value.length) {
        offset += 2;
      }

      // Distance
      if ((flags & 0x08) != 0 && offset + 2 < value.length) {
        int distance = value[offset] | (value[offset + 1] << 8) | (value[offset + 2] << 16);
        decoded.write('  Distância: $distance m (raw: 0x${distance.toRadixString(16).toUpperCase()})\n');
        offset += 3;
      }

      // Time
      if ((flags & 0x10) != 0 && offset + 1 < value.length) {
        int time = value[offset] | (value[offset + 1] << 8);
        decoded.write('  Tempo: $time s (raw: 0x${time.toRadixString(16).toUpperCase()})\n');
        offset += 2;
      }

      // Calories
      if ((flags & 0x20) != 0 && offset + 1 < value.length) {
        int calories = value[offset] | (value[offset + 1] << 8);
        decoded.write('  Calorias: $calories kcal (raw: 0x${calories.toRadixString(16).toUpperCase()})\n');
        offset += 2;
      }

      // Heart Rate
      if ((flags & 0x40) != 0 && offset < value.length) {
        int hr = value[offset];
        decoded.write('  Freq. Cardíaca: $hr bpm (raw: 0x${hr.toRadixString(16).toUpperCase()})\n');
        offset += 1;
      }

      // Status
      if ((flags & 0x80) != 0 && offset < value.length) {
        int status = value[offset];
        decoded.write('  Status: ${status == 1 ? 'Executando' : 'Parado'} (raw: 0x${status.toRadixString(16).toUpperCase()})\n');
      }

      _addLog(decoded.toString(), LogType.debug);
    } catch (e) {
      _addLog('  ❌ Erro ao decodificar: $e', LogType.error);
    }
  }

  Future<void> _clearLogs() async {
    setState(() => _logs.clear());
    _addLog('Logs limpos', LogType.info);
  }

  Future<void> _exportLogs() async {
    _logs.map((log) {
      return '[${log.timestamp.toString().split('.')[0]}] ${log.type.name.toUpperCase()}: ${log.message}';
    }).toList();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_logs.length} logs prontos para copiar'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Bluetooth Monitor'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: 'Limpar logs',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportLogs,
            tooltip: 'Exportar logs',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Botões de controle
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _discoverServices,
                    icon: const Icon(Icons.search),
                    label: const Text('Descobrir Serviços'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _testFTMSNotifications,
                    icon: const Icon(Icons.notification_add),
                    label: const Text('Testar FTMS'),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(_isMonitoring ? '🟢 Monitorando' : '🔴 Parado'),
                    backgroundColor: _isMonitoring ? Colors.green[100] : Colors.red[100],
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${_logs.length} logs'),
                  ),
                ],
              ),
            ),
          ),
          // Lista de logs
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum log registrado',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Clique em "Descobrir Serviços" ou "Testar FTMS"',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[_logs.length - 1 - index];
                      return _buildLogTile(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(DebugLog log) {
    Color backgroundColor;
    IconData icon;
    
    switch (log.type) {
      case LogType.error:
        backgroundColor = Colors.red[100]!;
        icon = Icons.error;
        break;
      case LogType.warning:
        backgroundColor = Colors.orange[100]!;
        icon = Icons.warning;
        break;
      case LogType.success:
        backgroundColor = Colors.green[100]!;
        icon = Icons.check_circle;
        break;
      case LogType.data:
        backgroundColor = Colors.blue[50]!;
        icon = Icons.data_usage;
        break;
      case LogType.debug:
        backgroundColor = Colors.purple[50]!;
        icon = Icons.bug_report;
        break;
      case LogType.info:
        backgroundColor = Colors.grey[100]!;
        icon = Icons.info;
        break;
    }

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(
                log.timestamp.toString().split('.')[0],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(log.type.name.toUpperCase()),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            log.message,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _logController.close();
    _bluetoothService.dispose();
    super.dispose();
  }
}

enum LogType {
  info,
  error,
  warning,
  success,
  data,
  debug,
}

class DebugLog {
  final String message;
  final DateTime timestamp;
  final LogType type;

  DebugLog({
    required this.message,
    required this.timestamp,
    required this.type,
  });
}
