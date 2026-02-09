# 🏃 Treadmill Monitor - Guia Rápido

## O que foi criado?

Uma aplicação Flutter completa que monitora esteiras via Bluetooth, com duas telas principais:

### 1️⃣ Tela de Seleção de Dispositivos
- Escaneia todos os dispositivos Bluetooth disponíveis
- Exibe uma lista de dispositivos encontrados
- Permite conectar-se a uma esteira com um toque

### 2️⃣ Tela de Dados da Esteira
Mostra em **tempo real**:
- 📊 **Velocidade** (km/h) - em destaque
- 📈 **Inclinação** (%)
- ⏱️ **Tempo** (hh:mm:ss)
- 🔥 **Calorias** queimadas
- 📍 **Distância** (km)
- ❤️ **Frequência Cardíaca** (bpm)
- ▶️ **Status** (em execução ou parado)

---

## 📂 Estrutura de Arquivos Criada

```
lib/
├── main.dart                          ← Arquivo principal (modificado)
│
├── models/
│   └── treadmill_data.dart           ← Modelo de dados
│
├── services/
│   └── bluetooth_service.dart         ← Gerenciador Bluetooth/FTMS
│
└── screens/
    ├── device_selection_screen.dart   ← Seleção de dispositivos
    └── treadmill_data_screen.dart     ← Visualização de dados
```

---

## 🔧 Como Usar

### Pré-requisitos
- Flutter 3.10.7+
- Esteira com Bluetooth ativado
- Permissões de Bluetooth habilitadas no dispositivo

### Execução
```bash
cd /home/s873339533/dev/pessoal/treadmill
flutter run
```

### Fluxo de Uso
1. **Abra o app** → Tela de seleção de dispositivos
2. **Ative Bluetooth** (se não estiver)
3. **Escaneie** → Toque em "Escanear Novamente" se necessário
4. **Selecione** sua esteira da lista
5. **Aguarde** a conexão estabelecer-se
6. **Veja** os dados atualizarem em tempo real!
7. **Desconecte** usando o botão ou ícone de voltar

---

## 🎯 Principais Componentes

### `BluetoothService` (Singleton)
Responsável por:
- Varrer dispositivos Bluetooth
- Conectar/desconectar
- Descobrir serviço FTMS
- Decodificar dados
- Transmitir via Stream

**Uso:**
```dart
BluetoothService service = BluetoothService();

// Escanear
List<BluetoothDevice> devices = await service.scanForDevices();

// Conectar
bool connected = await service.connectToDevice(device);

// Ouvir dados
service.treadmillDataStream.listen((TreadmillData data) {
  print('Velocidade: ${data.speed}');
});
```

### `TreadmillData`
Modelo com campos:
- `speed` - Velocidade em km/h
- `incline` - Inclinação em %
- `time` - Tempo em segundos
- `calories` - Calorias queimadas
- `distance` - Distância em metros
- `heartRate` - Frequência cardíaca
- `isRunning` - Se está em execução

---

## 🔄 Fluxo de Dados

```
┌─────────────────────┐
│  Dispositivo        │
│  (Esteira)          │
└──────────┬──────────┘
           │ FTMS Data (Bluetooth)
           ▼
┌─────────────────────┐
│ BluetoothService    │
│ • Decode FTMS       │
│ • Stream broadcast  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ TreadmillDataScreen │
│ • StreamBuilder     │
│ • UI em tempo real  │
└─────────────────────┘
```

---

## 📊 Decodificação FTMS

O protocolo FTMS (Fitness Training Machine Service) é um padrão Bluetooth para máquinas de exercício.

**UUID do Serviço**: `0x181E`
**UUID da Característica**: `00002AD1-0000-1000-8000-00805F9B34FB` (Treadmill Data)

O `BluetoothService` decodifica automaticamente os bytes FTMS:
- Byte 0: Flags (indicam quais dados estão presentes)
- Bytes seguintes: Dados conforme flags (little-endian)

Unidades:
- Velocidade: 0.01 km/h por unidade (lê 2 bytes)
- Inclinação: 0.1% por unidade (lê 2 bytes signed)
- Distância: 1 metro por unidade (lê 3 bytes)
- Tempo: 1 segundo por unidade (lê 2 bytes)
- Calorias: 1 kcal por unidade (lê 2 bytes)
- Freq. cardíaca: valor direto (lê 1 byte)

---

## 🎨 Interface

### Cores Utilizadas
- 🔵 Azul → Velocidade
- 🟠 Laranja → Inclinação
- 🟣 Roxo → Tempo
- 🔴 Vermelho → Calorias
- 🟢 Verde/Teal → Distância
- 💗 Rosa → Frequência cardíaca

### Layout Responsivo
- Card grande para velocidade (métrica principal)
- Cards médios para inclinação
- Grid 2x2 para outras métricas
- Indicadores visuais de status

---

## ⚙️ Configurações Necessárias

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Para conectar à sua esteira Bluetooth</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Para descobrir dispositivos locais</string>
```

---

## 🐛 Solução de Problemas

| Problema | Solução |
|----------|---------|
| Nenhum dispositivo encontrado | Ligue a esteira, ative modo pareamento, ative Bluetooth do phone |
| Conexão falha | Tente novamente, verifique distância, reinicie esteira |
| Dados não atualizam | Verifique se esteira está transmitindo, desconecte/reconecte |
| Bluetooth desativado | Ative Bluetooth nas configurações do dispositivo |

---

## 📝 Dependências Utilizadas

```yaml
flutter_blue_plus: ^2.1.0      # Bluetooth LE
flutter_ftms: ^1.4.0           # Fitness Training Machine Service
cupertino_icons: ^1.0.8        # Ícones iOS
```

---

## 🚀 Próximas Melhorias

- [ ] Gráficos de histórico
- [ ] Controle remoto de velocidade/inclinação
- [ ] Salvamento de sessões
- [ ] Integração com Google Fit / Apple Health
- [ ] Modo escuro
- [ ] Notificações de alertas
- [ ] Múltiplas esteiras

---

## 📄 Documentação Completa

- `USAGE_GUIDE.md` - Guia detalhado de uso
- `PROJECT_STRUCTURE.md` - Estrutura técnica do projeto

---

**Desenvolvido com ❤️ em Flutter**
**Data: 9 de fevereiro de 2026**
