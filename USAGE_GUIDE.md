# Treadmill Monitor 🏃

Um aplicativo Flutter para monitorar em tempo real os dados de sua esteira através da conexão Bluetooth (FTMS - Fitness Training Machine Service).

## ✨ Funcionalidades

- **Seleção de Dispositivos**: Interface intuitiva para conectar-se a esteiras via Bluetooth
- **Visualização em Tempo Real**: Monitore dados em tempo real:
  - 📊 Velocidade (km/h)
  - 📈 Inclinação (%)
  - ⏱️ Tempo decorrido
  - 🔥 Calorias queimadas
  - 📍 Distância percorrida (km)
  - ❤️ Frequência cardíaca (bpm)
  - ▶️ Status de execução

## 🚀 Como Usar

### 1. Selecionar Esteira
- Abra o aplicativo
- A tela inicial mostrará uma lista de dispositivos Bluetooth disponíveis
- Certifique-se de que sua esteira está ligada e em modo de pareamento
- Toque no dispositivo desejado para conectar

### 2. Visualizar Dados
- Após conectado, a tela de dados será exibida
- Os dados serão atualizados em tempo real conforme sua esteira transmite informações
- A interface mostra os principais dados em destaque, com outros dados adicionais abaixo

### 3. Desconectar
- Toque no ícone ❌ no canto superior direito da AppBar
- Ou use o botão "Desconectar" na parte inferior da tela

## 📦 Dependências

- `flutter_blue_plus`: ^2.1.0 - Biblioteca Bluetooth para Flutter
- `flutter_ftms`: ^1.4.0 - Suporte para o protocolo FTMS

## 🛠️ Instalação

```bash
flutter pub get
flutter run
```

## 📋 Requisitos de Sistema

- Flutter 3.10.7+
- Dart 3.10.7+
- Dispositivo com Bluetooth 4.0+
- Esteira compatível com FTMS (Bluetooth Low Energy)

## 📝 Notas Técnicas

### FTMS (Fitness Training Machine Service)
Este app utiliza o padrão FTMS (UUID: 0x181E), que é a especificação padrão para máquinas de exercício Bluetooth. A characterística de dados é:

- **Treadmill Data**: UUID `00002AD1-0000-1000-8000-00805F9B34FB`

Os dados são decodificados de acordo com a especificação FTMS, que inclui:
- Flags indicando quais dados estão presentes
- Velocidade instantânea (2 bytes, 0.01 km/h)
- Inclinação (2 bytes signed, 0.1%)
- Distância (3 bytes, 1 metro)
- Tempo (2 bytes, 1 segundo)
- Calorias (2 bytes, 1 kcal)
- Frequência cardíaca (1 byte)
- Status de execução

## ⚙️ Configuração de Permissões

### Android
O arquivo `android/app/src/main/AndroidManifest.xml` deve incluir:
```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### iOS
O arquivo `ios/Runner/Info.plist` deve incluir:
```xml
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Este aplicativo precisa acessar o Bluetooth para conectar à sua esteira.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Este aplicativo precisa acessar a rede local.</string>
```

## 🎨 Design

- Interface moderna com Material Design 3
- Layouts responsivos
- Cores intuitivas para diferentes métricas
- Indicadores visuais de status de conexão

## 🔄 Fluxo da Aplicação

```
Tela de Seleção de Dispositivos
    ↓
Escaneia dispositivos Bluetooth
    ↓
Exibe lista de dispositivos
    ↓
Usuário seleciona dispositivo
    ↓
Conecta ao dispositivo
    ↓
Descobre serviços FTMS
    ↓
Subscreve a notificações de dados
    ↓
Tela de Dados da Esteira
    ↓
Recebe e processa dados em tempo real
    ↓
Atualiza UI com dados atuais
```

## 🐛 Solução de Problemas

**Nenhum dispositivo encontrado?**
- Certifique-se de que sua esteira está ligada
- Verifique se está em modo de pareamento
- Reinicie a esteira
- Ative o Bluetooth do dispositivo

**Conexão cai frequentemente?**
- Verifique a distância até a esteira (próximo a 10 metros)
- Tente desconectar e conectar novamente
- Reinicie a esteira e o aplicativo

**Dados não são atualizados?**
- Certifique-se de que a esteira está funcionando
- Verifique se a esteira está transmitindo dados FTMS
- Tente desconectar e conectar novamente

## 📄 Licença

Este projeto está aberto para uso pessoal e educacional.

---

Desenvolvido com ❤️ usando Flutter
