# 🏃 Treadmill Monitor

**Monitoramento de esteiras em tempo real via Bluetooth (FTMS)**

---

## 📋 Sobre

O **Treadmill Monitor** é uma aplicação Flutter completa que conecta seu smartphone a esteiras compatíveis com o protocolo **FTMS** (Fitness Training Machine Service). Visualize seus dados de treino em tempo real com uma interface moderna e intuitiva.

## ✨ Funcionalidades

- **Conexão Bluetooth**: Scan e pareamento simplificado com dispositivos BLE.
- **Dados em Tempo Real**:
  - 🏃 Velocidade (km/h)
  - ⛰️ Inclinação (%)
  - ⏱️ Tempo decorrido
  - 🔥 Calorias queimadas
  - 📍 Distância percorrida
  - ❤️ Frequência Cardíaca
- **Interface Moderna**: Design limpo baseado no Material 3.

## 🚀 Começando

1. **Instalação**:
   ```bash
   flutter pub get
   ```

2. **Execução**:
   ```bash
   flutter run
   ```

3. **Primeiros Passos**:
   Consulte o **[QUICK_START.md](QUICK_START.md)** para um guia rápido de 5 minutos.

## 📚 Documentação Completa

- **[USAGE_GUIDE.md](USAGE_GUIDE.md)**: Manual do usuário detalhado.
- **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)**: Estrutura técnica e arquitetura.
- **[DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)**: Índice geral de toda a documentação.

## 🚀 Deploy (CI/CD)

O projeto utiliza **Codemagic** para integração e entrega contínua. O arquivo de configuração principal é o `codemagic.yaml`.

### Workflow: `ios-unsigned`

- **Objetivo**: Gera uma build de release para iOS (`.ipa`) **não assinada**.
- **Utilidade**: Ideal para testes rápidos em simuladores ou para distribuição interna onde a assinatura é feita posteriormente.
- **Processo**:
  1. Instala as dependências do Flutter.
  2. Compila o aplicativo em modo `release` sem exigir assinatura de código (`--no-codesign`).
  3. Empacota o resultado (`Runner.app`) em um arquivo `.ipa` pronto para instalação.

---
**Desenvolvido com ❤️ em Flutter**