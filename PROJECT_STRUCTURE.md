# Estrutura do Projeto - Treadmill Monitor

## 📁 Arquivos Criados

```
lib/
├── main.dart                          # Arquivo principal da aplicação
├── models/
│   └── treadmill_data.dart           # Modelo de dados da esteira
├── services/
│   └── bluetooth_service.dart         # Serviço de gerenciamento Bluetooth e FTMS
└── screens/
    ├── device_selection_screen.dart   # Tela para seleção de dispositivo
    └── treadmill_data_screen.dart    # Tela principal com dados da esteira
```

## 🎯 Componentes Principais

### 1. **TreadmillData** (`models/treadmill_data.dart`)
Modelo que representa os dados recebidos da esteira:
- `speed`: Velocidade em km/h
- `incline`: Inclinação em %
- `time`: Tempo em segundos
- `calories`: Calorias queimadas
- `distance`: Distância em metros
- `heart_rate`: Frequência cardíaca em bpm
- `is_running`: Se a esteira está em execução

### 2. **BluetoothService** (`services/bluetooth_service.dart`)
Serviço singleton que gerencia:
- ✅ Varredura de dispositivos Bluetooth
- ✅ Conexão/desconexão de dispositivos
- ✅ Descoberta de serviços FTMS
- ✅ Decodificação de dados FTMS
- ✅ Transmissão de dados via Stream

**Métodos principais:**
- `scanForDevices()`: Escaneia dispositivos disponíveis
- `connectToDevice(device)`: Conecta a um dispositivo
- `treadmillDataStream`: Stream de dados em tempo real
- `disconnectDevice()`: Desconecta
- `dispose()`: Libera recursos

### 3. **DeviceSelectionScreen** (`screens/device_selection_screen.dart`)
Tela inicial que:
- Verifica se Bluetooth está ativado
- Escaneia dispositivos disponíveis
- Exibe lista de dispositivos Bluetooth
- Gerencia conexão ao dispositivo selecionado
- Navega para a tela de dados

### 4. **TreadmillDataScreen** (`screens/treadmill_data_screen.dart`)
Tela principal que:
- Exibe dados em tempo real da esteira
- Mostra velocidade em destaque
- Exibe inclinação, tempo, calorias, distância, frequência cardíaca
- Indica status de execução (em execução/parado)
- Permite desconexão segura

## 🔄 Fluxo de Dados

```
BluetoothService
    ↓
scanForDevices() → List<BluetoothDevice>
    ↓
connectToDevice() → discoverServices()
    ↓
subscribe to characteristic notifications
    ↓
onValueReceived.listen() → processTreadmillData()
    ↓
decode FTMS bytes
    ↓
_treadmillDataController.add(TreadmillData)
    ↓
treadmillDataStream (broadcast)
    ↓
StreamBuilder in TreadmillDataScreen
    ↓
UI atualizada em tempo real
```

## 🎨 Interface do Usuário

### Tela 1: Seleção de Dispositivos
- Header com instrução
- Lista de dispositivos encontrados
- Botão para escanear novamente
- Status de conexão

### Tela 2: Dados da Esteira
- Indicador de conexão (verde)
- Card grande: Velocidade (em destaque)
- Card: Inclinação
- Grid (2x2): Tempo, Calorias, Distância, Frequência Cardíaca
- Status de execução (em execução/parado)
- Botão de desconexão

## 🔐 Tratamento de Erros

- ✅ Bluetooth desativado
- ✅ Nenhum dispositivo encontrado
- ✅ Falha na conexão
- ✅ Dados FTMS inválidos
- ✅ Limites de array na decodificação

## 📊 Decodificação FTMS

O protocolo FTMS (Fitness Training Machine Service) utiliza um formato específico:

**Byte 0**: Flags (quais dados estão presentes)
```
Bit 0: Velocidade instantânea
Bit 1: Inclinação
Bit 2: Ramp Angle
Bit 3: Distância
Bit 4: Tempo
Bit 5: Calorias
Bit 6: Frequência cardíaca
Bit 7: Status de execução
```

**Dados subsequentes**: Conforme indicado pelos flags (little-endian)

## 💡 Exemplos de Uso

### Obter stream de dados:
```dart
BluetoothService service = BluetoothService();
service.treadmillDataStream.listen((TreadmillData data) {
  print('Velocidade: ${data.speed} km/h');
});
```

### Conectar a um dispositivo:
```dart
bool success = await service.connectToDevice(device);
if (success) {
  print('Conectado!');
}
```

## 🚀 Próximas Melhorias Possíveis

- [ ] Gráficos de histórico de dados
- [ ] Controle remoto da esteira (velocidade, inclinação)
- [ ] Salvamento de sessões
- [ ] Estatísticas e análises
- [ ] Integração com Google Fit / Apple Health
- [ ] Modo escuro
- [ ] Suporte a múltiplas esteiras
- [ ] Notificações de alertas (ex: frequência cardíaca alta)

---

**Criado em**: 9 de fevereiro de 2026
