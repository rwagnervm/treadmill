# 🏗️ Arquitetura e Diagramas

## 📐 Arquitetura Geral da Aplicação

```
┌─────────────────────────────────────────────────────────────────┐
│                        MyApp (main.dart)                        │
│                    MaterialApp com Theme                        │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   DeviceSelectionScreen            │
        │   (Busca e Seleção de Dispositivos)│
        └────────────┬───────────────────────┘
                     │
        Seleciona dispositivo
                     │
                     ▼
        ┌────────────────────────────────────┐
        │   TreadmillDataScreen              │
        │   (Visualização de Dados em RT)    │
        └────────────┬───────────────────────┘
                     │
                     ├─► StreamBuilder
                     │    └─► TreadmillData (Model)
                     │
                     └─► BluetoothService (Singleton)
```

---

## 🔄 Ciclo de Vida da Conexão Bluetooth

```
┌──────────────────────────────────────────────────────────────┐
│                    Aplicação Iniciada                        │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │   DeviceSelectionScreen.init() │
        │   • Verifica Bluetooth         │
        │   • Pronto para escanear       │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │   BluetoothService.scan()      │
        │   • FlutterBluePlus.startScan()│
        │   • Aguarda 2 segundos         │
        │   • Coleta resultados          │
        │   • FlutterBluePlus.stopScan() │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │   Exibe Lista de Dispositivos  │
        └────────────┬───────────────────┘
                     │
        Usuário seleciona dispositivo
                     │
                     ▼
        ┌────────────────────────────────────┐
        │ BluetoothService.connectToDevice() │
        │ • device.connect()                 │
        │ • discoverServices()               │
        │ • Busca FTMS (UUID 0x181E)        │
        │ • Busca característica 0x2AD1      │
        │ • setNotifyValue(true)             │
        └────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │   Navegação para DataScreen    │
        │   • Route.push()               │
        │   • Inicia StreamListener      │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────┐
        │   Recebimento de Dados em Tempo   │
        │   Real (Loop Contínuo)            │
        │                                   │
        │ for each notification:            │
        │   • onValueReceived               │
        │   • _processTreadmillData()       │
        │   • Decode FTMS bytes             │
        │   • _treadmillDataController.add()│
        │   • StreamBuilder rebuild()       │
        │   • UI atualizada                 │
        └────────────┬───────────────────────┘
                     │
        Usuário clica em desconectar
                     │
                     ▼
        ┌────────────────────────────────┐
        │ BluetoothService.disconnect()  │
        │ • Cancel subscription           │
        │ • device.disconnect()           │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │   Volta para SelectionScreen   │
        └────────────────────────────────┘
```

---

## 🎯 Fluxo de Processamento de Dados FTMS

```
┌─────────────────────────────────────────────────────────────┐
│              Esteira envia bytes FTMS (BLE)                 │
│   [Flags, Speed_L, Speed_H, Incl_L, Incl_H, ... , Status]  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │  BluetoothCharacteristic.      │
        │  onValueReceived               │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │ _processTreadmillData()        │
        │                                │
        │ List<int> bytes recebidos      │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │ Criar novo TreadmillData()     │
        │ data = TreadmillData()         │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │ Ler Flags (byte 0)             │
        │ flags = value[0]               │
        └────────────┬───────────────────┘
                     │
        ┌────────────┴────────────┬────────────┬──────────┐
        │                         │            │          │
        ▼                         ▼            ▼          ▼
    Speed?              Incline?          Time?      Calories?
    (flag 0x01)        (flag 0x02)      (flag 0x10) (flag 0x20)
        │                    │                │           │
        ▼                    ▼                ▼           ▼
    2 bytes               2 bytes           2 bytes      2 bytes
    * 0.01             * 0.1 %              * 1s          * 1 kcal
        │                    │                │           │
        └────────────┬────────┴────────┬──────┴─────┬─────┘
                     │                │            │
                     ▼                ▼            ▼
        ┌────────────────────────────────────────────┐
        │ HeartRate? (flag 0x40)                     │
        │ • 1 byte → data.heartRate                  │
        │                                            │
        │ IsRunning? (flag 0x80)                     │
        │ • 1 byte → data.isRunning (0 or 1)        │
        └────────────┬───────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │ _treadmillDataController.add() │
        │ (emit no Stream)                │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │ StreamBuilder ouve evento      │
        │ (rebuild automático)           │
        └────────────┬───────────────────┘
                     │
                     ▼
        ┌────────────────────────────────┐
        │ UI atualizada com novos dados  │
        │ • Velocidade refrescada        │
        │ • Inclinação refrescada        │
        │ • Status atualizado            │
        └────────────────────────────────┘
```

---

## 🏠 Estrutura de Diretórios

```
treadmill/
│
├── 📄 pubspec.yaml                    ← Dependências
├── 📄 analysis_options.yaml           ← Linting rules
├── 📄 README.md                       ← Documentação principal
├── 📄 QUICK_START.md                  ← Guia rápido
├── 📄 USAGE_GUIDE.md                  ← Guia de uso
├── 📄 PROJECT_STRUCTURE.md            ← Estrutura técnica
├── 📄 IMPLEMENTATION_SUMMARY.md       ← Sumário
├── 📄 EXAMPLES_AND_EXTENSIONS.md      ← Exemplos avançados
│
├── lib/
│   │
│   ├── 📝 main.dart                   ← Ponto de entrada
│   │
│   ├── models/
│   │   └── 📝 treadmill_data.dart     ← Modelo de dados
│   │
│   ├── services/
│   │   └── 📝 bluetooth_service.dart  ← Lógica de Bluetooth
│   │       • scanForDevices()
│   │       • connectToDevice()
│   │       • _subscribeTreadmillData()
│   │       • _processTreadmillData()
│   │       • disconnectDevice()
│   │       • dispose()
│   │
│   └── screens/
│       ├── 📝 device_selection_screen.dart  ← Tela 1
│       │   • _scanForDevices()
│       │   • _connectToDevice()
│       │
│       └── 📝 treadmill_data_screen.dart   ← Tela 2
│           • StreamBuilder
│           • _buildMainDataCard()
│           • _buildDataCard()
│           • _buildCompactDataCard()
│           • _buildStatusCard()
│           • _formatTime()
│           • _formatDistance()
│
├── android/                            ← Configurações Android
│   └── app/src/main/AndroidManifest.xml
│
├── ios/                                ← Configurações iOS
│   └── Runner/Info.plist
│
└── test/
    └── widget_test.dart
```

---

## 🔌 Dependências e Integração

```
┌─────────────────────────────────────────────────────────────┐
│                   Projeto Flutter                           │
└────────────────┬────────────────────────────────┬───────────┘
                 │                                │
         ┌───────▼──────────┐        ┌────────────▼────────┐
         │ flutter_blue_plus│        │   flutter_ftms      │
         │   (v2.1.0)       │        │    (v1.4.0)         │
         └───────┬──────────┘        └────────────┬────────┘
                 │                                │
       ┌─────────▼────────────────────────────────▼────────┐
       │         Bluetooth Low Energy (BLE)                │
       └──────────────────┬─────────────────────────────────┘
                          │
       ┌──────────────────▼──────────────────┐
       │  Device (Treadmill with FTMS)      │
       │                                    │
       │  FTMS Service (UUID: 0x181E)       │
       │  └─ Treadmill Data Characteristic  │
       │     (UUID: 0x2AD1)                 │
       │     • Dados enviados periodicamente│
       │     • Notificações habilitadas     │
       └────────────────────────────────────┘
```

---

## 💾 Gerenciamento de Estado

```
┌─────────────────────────────────────────────────────────┐
│              BluetoothService (Singleton)               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  fbp.BluetoothDevice? _connectedDevice                 │
│  └─ Dispositivo Bluetooth conectado                    │
│                                                         │
│  StreamSubscription? _ftmsSubscription                 │
│  └─ Subscrição a notificações do FTMS                 │
│                                                         │
│  StreamController<TreadmillData> _treadmillDataController
│  └─ Controlador broadcast de dados                    │
│                                                         │
│  Stream<TreadmillData> treadmillDataStream             │
│  └─ Stream público para UI                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🎨 Componentização de UI

```
TreadmillDataScreen (StatefulWidget)
│
├── AppBar
│   ├── Título (Nome do dispositivo)
│   └── Botão desconectar
│
├── Scaffold.body
│   │
│   └── StreamBuilder<TreadmillData>
│       │
│       └── SingleChildScrollView
│           │
│           ├── ConnectionStatusCard
│           │   └─ Mostra "Conectado"
│           │
│           ├── MainDataCard (Velocidade)
│           │   ├─ Ícone grande
│           │   ├─ Valor em display grande
│           │   └─ Unidade
│           │
│           ├── DataCard (Inclinação)
│           │   ├─ Ícone
│           │   ├─ Label
│           │   ├─ Valor
│           │   └─ Unidade
│           │
│           ├── Row de CompactDataCards
│           │   ├─ Tempo
│           │   └─ Calorias
│           │
│           ├── Row de CompactDataCards
│           │   ├─ Distância
│           │   └─ Freq. Cardíaca
│           │
│           ├── StatusCard
│           │   ├─ Ícone
│           │   └─ Status (Executando/Parado)
│           │
│           └── DisconnectButton
│               └─ Botão vermelho
```

---

## 📡 Protocolo de Comunicação FTMS

```
Esteira (Servidor GATT)
    │
    ├─► Service UUID: 0x181E (FTMS)
    │   │
    │   ├─► Characteristic: 0x2AD1 (Treadmill Data)
    │   │   Properties: Notify
    │   │   │
    │   │   └─► Valores (formato little-endian):
    │   │       [Flags] [Speed] [Incline] [Distance] [Time] [Calories] [HR] [Status]
    │   │
    │   └─► Characteristic: 0x2AD0 (Features)
    │       └─► Informa capacidades
    │
    └─► Outros serviços (GAP, GATT, etc)

Cliente (Flutter App)
    │
    ├─► FlutterBluePlus.startScan()
    │   └─► Descobre dispositivos
    │
    ├─► device.connect()
    │   └─► Conecta ao GATT server
    │
    ├─► device.discoverServices()
    │   └─► Busca UUID 0x181E
    │
    ├─► characteristic.setNotifyValue(true)
    │   └─► Habilita notificações
    │
    └─► characteristic.onValueReceived.listen()
        └─► Recebe e processa dados
```

---

## 🔐 Tratamento de Erros e Edge Cases

```
Possível Error Path
    │
    ├─► Bluetooth desativado
    │   └─► Mensagem ao usuário
    │
    ├─► Nenhum dispositivo encontrado
    │   └─► UI vazia com instruções
    │
    ├─► Falha na conexão
    │   ├─► Retry automático?
    │   └─► Mensagem de erro
    │
    ├─► Serviço FTMS não encontrado
    │   └─► Dispositivo não compatível
    │
    ├─► Dados FTMS corrompidos
    │   ├─► Validação de flags
    │   ├─► Validação de limites
    │   └─► Log de erro
    │
    ├─► Conexão perdida
    │   ├─► Detecção automática
    │   └─► Reconexão automática?
    │
    └─► Overflow de memória
        └─► Limpeza de streams (dispose)
```

---

## 📊 Fluxo de Dados Tempo Real

```
Tempo: 0ms
    │
    ├─► Esteira envia bytes FTMS
    │   └─ Exemplo: [0x03, 0x64, 0x00, 0x32, 0x00, 0xE8, 0x03, ...]
    │
Tempo: ~50ms
    │
    ├─► BluetoothCharacteristic.onValueReceived dispara
    │   └─ Callback recebe List<int>
    │
Tempo: ~60ms
    │
    ├─► _processTreadmillData(bytes) executado
    │   ├─ Decodifica flags
    │   ├─ Extrai velocidade: (0x0064 * 0.01) = 10.0 km/h
    │   ├─ Extrai inclinação: (0x0032 * 0.1) = 5.0%
    │   └─ Cria TreadmillData objeto
    │
Tempo: ~65ms
    │
    ├─► _treadmillDataController.add(data)
    │   └─ Emite no stream
    │
Tempo: ~66ms
    │
    ├─► StreamBuilder escuta evento
    │   └─ setState() dispara
    │
Tempo: ~67ms
    │
    ├─► Widget.build() executado
    │   ├─ Reconstrói velocidade
    │   ├─ Reconstrói inclinação
    │   ├─ Atualiza outros widgets
    │
Tempo: ~70ms
    │
    └─► Tela atualizada visualmente

Repetição a cada notificação BLE (~20-100ms dependendo da esteira)
```

---

## 🎯 Matriz de Funcionalidades

```
┌──────────────────────┬──────────┬───────────┬─────────────┐
│ Feature              │ Status   │ Tela      │ Componente  │
├──────────────────────┼──────────┼───────────┼─────────────┤
│ Scan BLE             │ ✅       │ Selection │ Service     │
│ Connect Device       │ ✅       │ Selection │ Service     │
│ Discover FTMS        │ ✅       │ Selection │ Service     │
│ Real-time Data       │ ✅       │ Data      │ Service     │
│ Display Velocity     │ ✅       │ Data      │ UI Widget   │
│ Display Incline      │ ✅       │ Data      │ UI Widget   │
│ Display Time         │ ✅       │ Data      │ UI Widget   │
│ Display Calories     │ ✅       │ Data      │ UI Widget   │
│ Display Distance     │ ✅       │ Data      │ UI Widget   │
│ Display Heart Rate   │ ✅       │ Data      │ UI Widget   │
│ Display Status       │ ✅       │ Data      │ UI Widget   │
│ Disconnect           │ ✅       │ Data      │ UI Widget   │
│ Error Handling       │ ✅       │ Both      │ Service+UI  │
│ Responsive Design    │ ✅       │ Both      │ UI Widgets  │
└──────────────────────┴──────────┴───────────┴─────────────┘
```

---

Esta documentação visual ajuda a entender a arquitetura, fluxo de dados e componentes da aplicação Treadmill Monitor.
