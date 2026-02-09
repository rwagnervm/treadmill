# 📚 Índice de Documentação - Treadmill Monitor

## 🎯 Comece por Aqui

Se é sua primeira vez, leia na seguinte ordem:

1. **[QUICK_START.md](QUICK_START.md)** ⭐ - Guia rápido (5 minutos)
   - O que foi criado
   - Como executar
   - Solução de problemas básicos

2. **[USAGE_GUIDE.md](USAGE_GUIDE.md)** - Guia completo (15 minutos)
   - Como usar a aplicação
   - Configuração de permissões
   - Protocolo FTMS explicado

3. **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Sumário técnico (10 minutos)
   - O que foi entregue
   - Arquivos criados
   - Funcionalidades implementadas
   - Status do projeto

---

## 📖 Documentação Detalhada

### Para Desenvolvedores

- **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)**
  - Estrutura técnica do projeto
  - Descrição de cada componente
  - Fluxo de dados
  - Exemplos de uso básico

- **[ARCHITECTURE_DIAGRAMS.md](ARCHITECTURE_DIAGRAMS.md)**
  - Diagramas de arquitetura
  - Ciclo de vida
  - Fluxo de processamento FTMS
  - Estrutura de diretórios
  - Tratamento de erros

### Para Extensões e Customizações

- **[EXAMPLES_AND_EXTENSIONS.md](EXAMPLES_AND_EXTENSIONS.md)**
  - Exemplos de uso avançado
  - Como adicionar gráficos
  - Integração com Google Fit
  - Análise de dados
  - Persistência de sessões
  - Testes unitários
  - Modo de treino intervalado

---

## 📂 Arquivos do Projeto

### Código Principal

```
lib/
├── main.dart                      - Ponto de entrada
├── models/
│   └── treadmill_data.dart       - Modelo de dados
├── services/
│   └── bluetooth_service.dart    - Lógica Bluetooth
└── screens/
    ├── device_selection_screen.dart  - Tela de seleção
    └── treadmill_data_screen.dart   - Tela de dados
```

### Configuração

```
pubspec.yaml                - Dependências
analysis_options.yaml       - Linting rules
android/                    - Configurações Android
ios/                        - Configurações iOS
```

---

## 🚀 Guia Rápido de Execução

```bash
# 1. Entrar no diretório
cd /home/s873339533/dev/pessoal/treadmill

# 2. Obter dependências
flutter pub get

# 3. Executar no dispositivo/emulador
flutter run

# 4. Analisar código
flutter analyze
```

---

## 🎨 Características Principais

### ✅ Tela de Seleção de Dispositivos
- [x] Escaneia Bluetooth automaticamente
- [x] Lista dispositivos disponíveis
- [x] Tratamento de erros (Bluetooth desativado)
- [x] Botão para escanear novamente

### ✅ Tela de Dados da Esteira
- [x] Mostra velocidade em destaque
- [x] Mostra inclinação
- [x] Mostra tempo, calorias, distância, FC
- [x] Indica status (executando/parado)
- [x] Atualizações em tempo real
- [x] Botão de desconexão

### ✅ Serviço Bluetooth
- [x] Singleton para gerenciar estado
- [x] Scan de dispositivos
- [x] Conexão segura
- [x] Descoberta de serviços FTMS
- [x] Decodificação de dados FTMS
- [x] Stream para transmissão de dados

---

## 📊 Dados Monitorados

| Métrica | Unidade | Tipo | Atualização |
|---------|---------|------|-------------|
| Velocidade | km/h | Double | Real-time |
| Inclinação | % | Double | Real-time |
| Tempo | hh:mm:ss | Int | Real-time |
| Calorias | kcal | Int | Real-time |
| Distância | km | Double | Real-time |
| Frequência Cardíaca | bpm | Int | Real-time |
| Status | On/Off | Bool | Real-time |

---

## 🔧 Dependências

```yaml
flutter_blue_plus: ^2.1.0       # Bluetooth LE
flutter_ftms: ^1.4.0            # Fitness Training Machine Service
cupertino_icons: ^1.0.8         # Ícones
```

---

## 📱 Compatibilidade

- **Flutter**: 3.10.7+
- **Dart**: 3.10.7+
- **Android**: API 21+
- **iOS**: 11.0+
- **Bluetooth**: 4.0+ (BLE)

---

## 🎓 Protocolo FTMS

**Fitness Training Machine Service** (UUID: 0x181E)

### Características Importantes
- **UUID do Serviço**: `0x181E`
- **Treadmill Data Characteristic**: `00002AD1-0000-1000-8000-00805F9B34FB`
- **Propriedade**: Notify (notificações)

### Campos de Dados
- Byte 0: Flags (quais dados estão presentes)
- Velocidade: 2 bytes, factor 0.01 km/h
- Inclinação: 2 bytes signed, factor 0.1%
- Distância: 3 bytes, factor 1 metro
- Tempo: 2 bytes, factor 1 segundo
- Calorias: 2 bytes, factor 1 kcal
- Freq. Cardíaca: 1 byte
- Status: 1 byte

---

## 🐛 Qualidade do Código

- ✅ **Zero erros de compilação**
- ✅ **13 avisos de linting** (não-críticos)
- ✅ **Padrões de desenvolvimento** seguidos
- ✅ **Tratamento de erros** implementado
- ✅ **Limpeza de recursos** (dispose)

---

## 🔍 FAQ

### Como a aplicação recebe dados?
A esteira envia dados via Bluetooth Low Energy no formato FTMS. O serviço BluetoothService subscreve a notificações e decodifica os bytes em um objeto TreadmillData.

### Posso controlar a esteira remotamente?
Não nesta versão. A aplicação é **somente leitura**. Veja [EXAMPLES_AND_EXTENSIONS.md](EXAMPLES_AND_EXTENSIONS.md) para adicionar suporte.

### Como salvar dados de sessões?
Veja exemplos em [EXAMPLES_AND_EXTENSIONS.md](EXAMPLES_AND_EXTENSIONS.md) para integração com SharedPreferences.

### Posso adicionar gráficos?
Sim! Consulte [EXAMPLES_AND_EXTENSIONS.md](EXAMPLES_AND_EXTENSIONS.md) para exemplos com fl_chart.

### A aplicação funciona offline?
Não, precisa de Bluetooth ativo. A esteira deve estar ligada e emparelhada.

---

## 🚀 Próximos Passos

### Curto Prazo
- [ ] Implementar gráficos de dados
- [ ] Salvar histórico de sessões
- [ ] Notificações de alertas

### Médio Prazo
- [ ] Controle remoto da esteira
- [ ] Integração com Google Fit
- [ ] Modo escuro
- [ ] Suporte a múltiplas esteiras

### Longo Prazo
- [ ] App web (Flutter Web)
- [ ] Backend para sincronização
- [ ] Análises avançadas
- [ ] Community features

---

## 📞 Suporte e Contato

Para dúvidas ou problemas:

1. Consulte a documentação relevante acima
2. Verifique [QUICK_START.md](QUICK_START.md) - Solução de Problemas
3. Consulte exemplos em [EXAMPLES_AND_EXTENSIONS.md](EXAMPLES_AND_EXTENSIONS.md)

---

## 📜 Licença

Projeto aberto para uso pessoal e educacional.

---

## 🎉 Obrigado!

Esperamos que você aproveite o Treadmill Monitor!

**Desenvolvido com ❤️ em Flutter**

---

## 📋 Checklist de Leitura

- [ ] Li QUICK_START.md
- [ ] Executei `flutter run` com sucesso
- [ ] Li USAGE_GUIDE.md
- [ ] Entendi a arquitetura em PROJECT_STRUCTURE.md
- [ ] Vi os diagramas em ARCHITECTURE_DIAGRAMS.md
- [ ] Explorei exemplos em EXAMPLES_AND_EXTENSIONS.md

---

**Última atualização**: 9 de fevereiro de 2026

**Versão**: 1.0.0

**Status**: ✅ Completo e Pronto para Uso
