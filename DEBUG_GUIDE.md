# Guia de Debug - Treadmill Bluetooth Monitor

## Visão Geral

A tela de debug foi criada para ajudar a diagnosticar problemas de conexão e comunicação Bluetooth com a esteira. Ela registra todos os dados brutos recebidos via Bluetooth e tenta decodificá-los em tempo real.

## Como Acessar a Tela de Debug

### Opção 1: Via Botão na Tela de Seleção de Dispositivos
1. Escaneie por dispositivos normalmente
2. Procure pelo ícone de **bug** 🐛 no canto superior direito da AppBar
3. Clique no ícone para abrir a tela de debug
4. A tela de debug abre com o primeiro dispositivo encontrado

### Opção 2: Adicionar Atalho Direto
Você pode adicionar um botão direto no menu para ir para a tela de debug sem precisar escanear antes.

## Recursos da Tela de Debug

### Botões de Controle

#### 🔍 Descobrir Serviços
- Descobre todos os serviços Bluetooth do dispositivo
- Lista todas as características de cada serviço com seus UUIDs
- Mostra as propriedades de cada característica (Read, Write, Notify, Indicate)
- **Útil para**: Identificar se o dispositivo oferece o serviço FTMS esperado

#### 📢 Testar FTMS
- Procura especificamente pelo serviço FTMS (0x181E)
- Procura pela característica Treadmill Data (0x2AD1)
- Habilita notificações nessa característica
- Começa a receber e decodificar dados FTMS
- **Útil para**: Verificar se a esteira está enviando dados

#### Status de Monitoramento
- **🟢 Monitorando**: Significa que está escutando eventos Bluetooth
- **🔴 Parado**: Nenhum evento está sendo monitorado
- O contador de logs mostra quantas mensagens foram registradas

### Seções de Log

Cada log mostra:
- **Timestamp**: Hora exata que o evento ocorreu
- **Tipo**: Categoria do evento (INFO, ERROR, WARNING, SUCCESS, DATA, DEBUG)
- **Mensagem**: Descrição detalhada do evento

#### Tipos de Logs

- 🔵 **INFO** (Azul): Eventos informativos normais
- 🔴 **ERROR** (Vermelho): Erros e falhas
- 🟠 **WARNING** (Laranja): Avisos e situações anormais
- 🟢 **SUCCESS** (Verde): Sucesso em operações
- 🔵 **DATA** (Azul claro): Dados recebidos
- 🟣 **DEBUG** (Roxo): Informações de debug detalhadas

## Interpretando os Logs

### Exemplo 1: Serviço FTMS Encontrado

```
[12:34:56] INFO: ✅ Serviço FTMS encontrado!
[12:34:56] SUCCESS: ✅ Característica Treadmill Data encontrada!
[12:34:56] SUCCESS: ✅ Notificações habilitadas!
```

Significa que:
- ✅ O dispositivo suporta FTMS
- ✅ Está enviando dados de esteira
- ✅ Conseguimos ativar as notificações

### Exemplo 2: Bytes Brutos Recebidos

```
[12:34:57] DATA: RAW BYTES (19): 01 E8 03 1E 00 04 00 06 27 00 00 00 FF 00 64 00 50 60 01
```

Significa que:
- Recebemos 19 bytes da esteira
- Cada par de caracteres é um byte em hexadecimal
- Este é o formato bruto que a esteira envia

### Exemplo 3: Decodificação FTMS

```
[12:34:57] DEBUG:
  📊 Decodificação FTMS:
  Flags: 0x01 (Speed )
  Velocidade: 8.88 km/h (raw: 0x03E8)
```

Significa que:
- Flag `0x01` indica que apenas velocidade está presente
- A velocidade é 8.88 km/h
- O valor bruto é 0x03E8 (1000 em decimal × 0.01 = 10.00)

## Troubleshooting

### Problema: "Nenhum serviço encontrado"

**Causa**: O dispositivo pode não ser uma esteira compatível com FTMS

**Solução**:
1. Clique em "Descobrir Serviços"
2. Procure pelo UUID `0x181E` na lista
3. Se não encontrar, o dispositivo não implementa FTMS
4. Tente com outro dispositivo ou verifique a documentação da esteira

### Problema: "Serviço encontrado mas sem dados recebidos"

**Causa**: A esteira pode estar:
- Desligada ou em standby
- Não está enviando dados
- As notificações estão desabilitadas

**Solução**:
1. Verifique se a esteira está ligada
2. Inicie um treino ou movimento na esteira
3. Clique em "Testar FTMS" novamente
4. Procure por logs com "RAW BYTES"

### Problema: "Bytes recebidos mas não decodificados corretamente"

**Significado dos padrões anormais**:

- **Todos os bytes iguais** (ex: `FF FF FF FF`): Pode ser erro de leitura
- **Sequência muito curta** (< 5 bytes): Pode estar incompleta
- **Valores fora do esperado**: A esteira pode usar um protocolo diferente

**Próximos passos**:
1. Copie os bytes brutos
2. Verifique a documentação da sua esteira
3. Compare com a especificação FTMS oficial

### Problema: Não aparece o ícone de debug

**Causa**: Não foi encontrado nenhum dispositivo Bluetooth

**Solução**:
1. Clique em "Escanear Novamente"
2. Certifique-se que a esteira está no modo Bluetooth
3. Certifique-se que o Bluetooth do telefone está ativado

## Exportar e Compartilhar Logs

Para compartilhar logs de debug com o desenvolvedor:

1. Clique no botão de **Download** 📥 no canto superior direito
2. Os logs serão preparados para copiar
3. Cole em um documento de texto ou email
4. Inclua também as informações:
   - Modelo da esteira
   - Marca
   - Versão do Bluetooth da esteira
   - Sistema operacional do telefone

## Limpar Logs

Clique no botão de **Lixeira** 🗑️ para limpar todos os logs e começar do zero.

> **Nota**: A tela mantém apenas os últimos 500 logs para não consumir muita memória.

## Protocolo FTMS - Referência Rápida

### UUIDs Importantes

| Nome | UUID | Descrição |
|------|------|-----------|
| FTMS Service | 0x181E | Serviço principal de máquinas de fitness |
| Treadmill Data | 0x2AD1 | Característica com dados da esteira (Notify) |
| Machine Status | 0x2ADA | Status da máquina (Notify) |

### Flags de Dados (Byte 0)

| Bit | Flag | Significado |
|-----|------|-------------|
| 0x01 | Speed | Velocidade instantânea presente |
| 0x02 | Incline | Inclinação presente |
| 0x04 | Ramp | Ângulo da rampa presente |
| 0x08 | Distance | Distância total presente |
| 0x10 | Time | Tempo decorrido presente |
| 0x20 | Calories | Calorias presente |
| 0x40 | Heart Rate | Frequência cardíaca presente |
| 0x80 | Status | Status em movimento presente |

### Formato de Dados

- **Speed**: 2 bytes (uint16, little-endian) × 0.01 = km/h
- **Incline**: 2 bytes (int16, little-endian) × 0.1 = %
- **Distance**: 3 bytes (uint24, little-endian) = metros
- **Time**: 2 bytes (uint16, little-endian) = segundos
- **Calories**: 2 bytes (uint16, little-endian) = kcal
- **Heart Rate**: 1 byte (uint8) = bpm
- **Status**: 1 byte (uint8) = 0x00 (parado) ou 0x01 (correndo)

## Dicas Extras

- Deixe a esteira em funcionamento contínuo enquanto observa os logs
- Os dados chegam em tempo real (geralmente a cada 250-500ms)
- Se não houver logs de "RAW BYTES", a esteira não está enviando nada
- O timestamp ajuda a identificar períodos sem dados

## Relatando Problemas

Se encontrar um problema, inclua:

1. **Logs completos** (clique em Download)
2. **Modelo da esteira**
3. **Passos para reproduzir o problema**
4. **Sistema operacional** (Android/iOS) e versão
5. **Versão do app**

Isso ajudará a resolver o problema mais rapidamente! 🚀
