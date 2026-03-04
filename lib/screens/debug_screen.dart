import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
      _addLog('Conectando ao dispositivo...', LogType.info);
      await widget.device.connect(
        timeout: const Duration(seconds: 10),
        license: fbp.License.free,
      );

      _addLog('Descobrindo serviços...', LogType.info);

      final services = await widget.device.discoverServices();
      _addLog('Serviços encontrados: ${services.length}', LogType.data);

      for (var service in services) {
        final uuid = service.uuid.toString().toUpperCase();
        _addLog(
          '  📦 Serviço: $uuid (${service.characteristics.length} características)',
          LogType.data,
        );

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
      _addLog('Conectando ao dispositivo para testar FTMS...', LogType.info);
      await widget.device.connect(
        timeout: const Duration(seconds: 10),
        license: fbp.License.free,
      );

      _addLog('Testando notificações FTMS...', LogType.info);

      final services = await widget.device.discoverServices();

      // Procurar serviço FTMS (0x181E ou 0x1826)
      for (var service in services) {
        if (service.uuid.toString().toLowerCase().contains('181e') ||
            service.uuid.toString().toLowerCase().contains('1826')) {
          _addLog('✅ Serviço FTMS encontrado!', LogType.success);

          for (var characteristic in service.characteristics) {
            final uuid = characteristic.uuid.toString().toLowerCase();

            // Treadmill Data (0x2AD1 ou 0x2ACD)
            if (uuid.contains('2ad1') || uuid.contains('2acd')) {
              _addLog(
                '✅ Característica Treadmill Data encontrada!',
                LogType.success,
              );

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

  Future<void> _testAllNotifications() async {
    try {
      _addLog('Conectando ao dispositivo para monitorar tudo...', LogType.info);
      await widget.device.connect(
        timeout: const Duration(seconds: 10),
        license: fbp.License.free,
      );

      _addLog(
        'Buscando e testando notify/indicate em TODOS os serviços...',
        LogType.info,
      );

      final services = await widget.device.discoverServices();
      int subscribed = 0;

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          final props = characteristic.properties;

          if (props.notify || props.indicate) {
            try {
              await characteristic.setNotifyValue(true);
              subscribed++;
              _addLog(
                '✅ Inscrito na Característica: ${characteristic.uuid.toString().substring(4, 8).toUpperCase()}',
                LogType.success,
              );

              characteristic.onValueReceived.listen((value) {
                _addLog(
                  '[${characteristic.uuid.toString().substring(4, 8).toUpperCase()}] '
                  'BYTES (${value.length}): '
                  '${value.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}',
                  LogType.data,
                );
              });
            } catch (e) {
              _addLog(
                '❌ Falha ao inscrever em ${characteristic.uuid.toString().substring(4, 8).toUpperCase()}: $e',
                LogType.error,
              );
            }
          }
        }
      }
      _addLog('Monitorando $subscribed características ativas.', LogType.info);
    } catch (e) {
      _addLog('ERRO ao monitorar todas as notificações: $e', LogType.error);
    }
  }

  void _decodeManualFTMS(List<int> value) {
    try {
      if (value.length < 2) {
        _addLog('  ⚠️ Valor curto. Tamanho: ${value.length}', LogType.warning);
        return;
      }

      StringBuffer decoded = StringBuffer('\n  📊 Decodificação FTMS:\n');

      var byteData = ByteData.sublistView(Uint8List.fromList(value));
      int flags = byteData.getUint16(0, Endian.little);
      decoded.write(
        '  Flags: 0x${flags.toRadixString(16).padLeft(4, '0').toUpperCase()}\n',
      );

      int offset = 2;

      // Speed (Bit 0)
      if ((flags & 0x0001) == 0) {
        if (offset + 2 <= value.length) {
          int speed = byteData.getUint16(offset, Endian.little);
          decoded.write(
            '  Velocidade: ${speed * 0.01} km/h (raw: 0x${speed.toRadixString(16).padLeft(4, '0').toUpperCase()})\n',
          );
        }
        offset += 2;
      }

      // Average Speed (Bit 1)
      if ((flags & 0x0002) != 0) {
        offset += 2;
      }

      // Distance (Bit 2)
      if ((flags & 0x0004) != 0) {
        if (offset + 3 <= value.length) {
          int distance =
              byteData.getUint8(offset) |
              (byteData.getUint8(offset + 1) << 8) |
              (byteData.getUint8(offset + 2) << 16);
          decoded.write(
            '  Distância: $distance m (raw: 0x${distance.toRadixString(16).padLeft(6, '0').toUpperCase()})\n',
          );
        }
        offset += 3;
      }

      // Inclination (Bit 3)
      if ((flags & 0x0008) != 0) {
        if (offset + 4 <= value.length) {
          int incline = byteData.getInt16(offset, Endian.little);
          int ramp = byteData.getInt16(offset + 2, Endian.little);
          double percentValue = incline * 0.1;
          double panelLevel = percentValue * 15.0 / 100.0;
          decoded.write(
            '  Inclinação: Nível ${panelLevel.toStringAsFixed(1)}/15 (${percentValue.toStringAsFixed(2)}%) (raw: 0x${incline.toRadixString(16).padLeft(4, '0').toUpperCase()})\n',
          );
          decoded.write(
            '  Ramp Angle: ${ramp * 0.1}° (raw: 0x${ramp.toRadixString(16).padLeft(4, '0').toUpperCase()})\n',
          );
        }
        offset += 4;
      }

      // Elevation Gain (Bit 4)
      if ((flags & 0x0010) != 0) {
        offset += 4;
      }

      // Instantaneous Pace (Bit 5)
      if ((flags & 0x0020) != 0) {
        offset += 2;
      }

      // Average Pace (Bit 6)
      if ((flags & 0x0040) != 0) {
        offset += 2;
      }

      // Expended Energy (Bit 7)
      if ((flags & 0x0080) != 0) {
        if (offset + 5 <= value.length) {
          int kcal = byteData.getUint16(offset, Endian.little);
          int kcalPerHour = byteData.getUint16(offset + 2, Endian.little);
          int kcalPerMin = byteData.getUint8(offset + 4);
          decoded.write(
            '  Calorias Totais: $kcal kcal (Hora: $kcalPerHour, Min: $kcalPerMin)\n',
          );
        }
        offset += 5;
      }

      // Heart Rate (Bit 8)
      if ((flags & 0x0100) != 0) {
        if (offset + 1 <= value.length) {
          int hr = byteData.getUint8(offset);
          decoded.write(
            '  Freq. Cardíaca: $hr bpm (raw: 0x${hr.toRadixString(16).padLeft(2, '0').toUpperCase()})\n',
          );
        }
        offset += 1;
      }

      // METs (Bit 9)
      if ((flags & 0x0200) != 0) {
        if (offset + 1 <= value.length) {
          int mets = byteData.getUint8(offset);
          decoded.write(
            '  METs: ${(mets * 0.1).toStringAsFixed(1)} (raw: 0x${mets.toRadixString(16).padLeft(2, '0').toUpperCase()})\n',
          );
        }
        offset += 1;
      }

      // Elapsed Time (Bit 10)
      if ((flags & 0x0400) != 0) {
        if (offset + 2 <= value.length) {
          int time = byteData.getUint16(offset, Endian.little);
          decoded.write(
            '  Tempo: $time s (raw: 0x${time.toRadixString(16).padLeft(4, '0').toUpperCase()})\n',
          );
        }
        offset += 2;
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
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nenhum log para exportar')));
      return;
    }

    try {
      final logLines = _logs.map((log) {
        return '[${log.timestamp.toString().split('.')[0]}] ${log.type.name.toUpperCase()}: ${log.message}';
      }).toList();

      final logString = logLines.join('\n');

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/treadmill_debug_log_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(logString);

      await Share.shareXFiles([XFile(file.path)], text: 'Treadmill Debug Logs');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao exportar logs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                  ElevatedButton.icon(
                    onPressed: _testAllNotifications,
                    icon: const Icon(Icons.monitor_heart),
                    label: const Text('Monitorar Tudo'),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(_isMonitoring ? '🟢 Monitorando' : '🔴 Parado'),
                    backgroundColor: _isMonitoring
                        ? Colors.green[100]
                        : Colors.red[100],
                  ),
                  const SizedBox(width: 8),
                  Chip(label: Text('${_logs.length} logs')),
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
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
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
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
            style: const TextStyle(fontSize: 13, fontFamily: 'Courier'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _logController.close();
    // Usa cancelSubscriptions() em vez de dispose() para não destruir o singleton
    _bluetoothService.cancelSubscriptions();
    super.dispose();
  }
}

enum LogType { info, error, warning, success, data, debug }

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
