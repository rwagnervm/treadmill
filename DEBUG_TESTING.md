# 🧪 Como Testar a Tela de Debug

## Cenário 1: Testar com Esteira Real

### Passos:

1. **Preparar a esteira**
   - Ligue a esteira
   - Certifique-se que o Bluetooth está ativado
   - Se possível, inicie um treino leve (velocidade mínima)

2. **Abrir o app**
   - Execute `flutter run`
   - Aguarde o app iniciar

3. **Escanear dispositivos**
   - A tela de seleção abrirá automaticamente
   - Seu Bluetooth será ativado e começará a escanear
   - Procure o nome da sua esteira na lista

4. **Acessar a tela de debug**
   - Clique no ícone de bug 🐛 no canto superior direito
   - A tela de debug abrirá

5. **Testar funcionalidades**
   - Clique em "Descobrir Serviços"
   - Procure por um UUID começando com `0000181E`
   - Se encontrar, sua esteira suporta FTMS

6. **Habilitar notificações FTMS**
   - Clique em "Testar FTMS"
   - Procure por mensagens "✅ Notificações habilitadas!"
   - Comece a correr/caminhar na esteira

7. **Observar dados**
   - Procure por logs com "RAW BYTES"
   - Procure por logs com "Velocidade:", "Inclinação:", etc.
   - A velocidade deve mudar conforme você muda o ritmo

### ✅ Sinais de Sucesso:

```
✅ Serviço FTMS encontrado
✅ Característica Treadmill Data encontrada
✅ Notificações habilitadas
✅ RAW BYTES recebidos
✅ Decodificação funcionando
✅ Velocidade, Inclinação, etc. mudando em tempo real
```

### ❌ Se Não Funcionar:

- Serviço não encontrado? → Esteira pode não ter FTMS
- Sem RAW BYTES? → Esteira não está enviando ou não está conectada
- Decodificação errada? → Protocolo pode ser diferente

## Cenário 2: Simular com Dados Hardcoded (Para Desenvolvimento)

Se não tiver uma esteira para testar:

### Opção A: Modificar _processTreadmillData temporariamente

```dart
void _processTreadmillData(List<int> value) {
  print('Dados recebidos: $value');
  try {
    // PARA TESTE: Enviar dados simulados
    TreadmillData data = TreadmillData(
      speed: 8.5,
      incline: 2.5,
      time: DateTime.now().second,
      calories: 150,
      distance: 1250.0,
      heartRate: 120,
      isRunning: true,
    );
    _treadmillDataController.add(data);
    return;
    
    // ... resto do código
  } catch (e) {
    print('Erro ao processar: $e');
  }
}
```

### Opção B: Criar dados de teste em debug_screen.dart

```dart
void _testWithFakeData() {
  _addLog('Iniciando com dados simulados...', LogType.info);
  
  Timer.periodic(Duration(seconds: 1), (timer) {
    var random = Random();
    List<int> fakeBytes = [
      0x01, // Flags: Speed only
      random.nextInt(256),
      random.nextInt(256),
    ];
    
    _addLog(
      'FAKE RAW BYTES: ${fakeBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      LogType.data,
    );
    _decodeManualFTMS(fakeBytes);
  });
}
```

## Cenário 3: Testar Decodificação Manual

### Dados de teste conhecidos:

```dart
// Velocidade 10.00 km/h (0x03E8 em hex = 1000 em decimal × 0.01)
List<int> testData1 = [
  0x01,           // Flags: Speed present
  0xE8, 0x03      // Speed: 1000 (10.00 km/h)
];

// Múltiplos campos
List<int> testData2 = [
  0x01,                                    // Flags: Speed
  0xE8, 0x03,                             // Speed: 10.00 km/h
  // Adicione mais campos conforme necessário
];
```

### Como testar:

1. Adicione um botão de teste em debug_screen.dart:

```dart
ElevatedButton(
  onPressed: () {
    final testBytes = [0x01, 0xE8, 0x03];
    _addLog('Testando decodificação...', LogType.info);
    _decodeManualFTMS(testBytes);
  },
  child: Text('Teste Decodificação'),
)
```

## Cenário 4: Validar Integração Completa

### Fluxo esperado:

```
Tela Inicial
    ↓
Clica em Escanear
    ↓
Descobre "Esteira XYZ"
    ↓
Clica no ícone de bug 🐛
    ↓
DebugScreen abre
    ↓
Clica "Descobrir Serviços"
    ↓
Lista serviços e características
    ↓
Clica "Testar FTMS"
    ↓
Habilita notificações
    ↓
Começa a receber RAW BYTES
    ↓
Decodifica automaticamente
    ↓
Mostra valores interpretados
```

## Checklist de Teste

- [ ] App compila sem erros
- [ ] Flutter analyze passa (apenas warnings de print)
- [ ] Tela de debug abre corretamente
- [ ] Botão "Descobrir Serviços" funciona
- [ ] Lista de serviços exibe corretamente
- [ ] Botão "Testar FTMS" funciona
- [ ] Logs aparecem com timestamps
- [ ] Cores dos logs estão corretas
- [ ] Pode scrollar a lista de logs
- [ ] Botão "Limpar" limpa os logs
- [ ] Botão "Download" funciona
- [ ] Back button fecha a tela
- [ ] Stream de dados FTMS continua funcionando
- [ ] Stream de bytes brutos emite dados

## Problemas Conhecidos / Limitações

1. **Emulador**: Bluetooth nem sempre funciona bem em emuladores. Use um dispositivo real se possível.

2. **Android Permissions**: Certifique-se que as permissões Bluetooth estão no AndroidManifest.xml:
   ```xml
   <uses-permission android:name="android.permission.BLUETOOTH" />
   <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
   <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   ```

3. **iOS**: Certifique-se que o Info.plist tem a permissão de Bluetooth:
   ```xml
   <key>NSBluetoothPeripheralUsageDescription</key>
   <string>This app requires Bluetooth to connect to treadmills</string>
   ```

## Comandos Úteis

```bash
# Executar a aplicação
flutter run

# Rodar apenas a análise
flutter analyze

# Limpar build
flutter clean

# Obter dependências
flutter pub get

# Ver logs em tempo real
flutter logs

# Debugar com hot reload
flutter run --verbose
```

## Enviando Feedback

Se encontrar problemas durante o teste:

1. Abra a tela de debug
2. Reproduza o problema
3. Clique em "Download" para exportar logs
4. Inclua:
   - Logs exportados
   - Versão do app
   - Modelo da esteira
   - Sistema operacional e versão
   - Passos para reproduzir

---

**Dica**: Mantenha os logs sempre visíveis enquanto testa para identificar problemas em tempo real! 🎯
