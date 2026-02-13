# 🐛 Tela de Debug Bluetooth - Resumo Rápido

## Novidade: Debug Screen Implementada! 

Uma nova tela de debug foi adicionada ao aplicativo para ajudar a diagnosticar problemas de comunicação Bluetooth com a esteira.

### 🚀 Como Usar

1. **Escaneie por dispositivos** na tela inicial
2. Clique no **ícone de bug 🐛** no canto superior direito (aparece após encontrar um dispositivo)
3. A tela de debug abrirá mostrando:
   - ✅ Todos os serviços Bluetooth do dispositivo
   - ✅ Bytes brutos recebidos em tempo real
   - ✅ Decodificação automática dos dados FTMS
   - ✅ Histórico completo de eventos

### 📊 O Que Você Pode Ver

Ao clicar em "Testar FTMS":
- Todos os bytes recebidos da esteira (em hexadecimal)
- Decodificação automática de:
  - Velocidade (km/h)
  - Inclinação (%)
  - Distância (metros)
  - Tempo (segundos)
  - Calorias (kcal)
  - Frequência cardíaca (bpm)
  - Status (correndo/parado)

### 🔧 Funcionalidades

| Botão | O que faz |
|-------|-----------|
| 🔍 Descobrir Serviços | Lista todos os serviços BLE do dispositivo |
| 📢 Testar FTMS | Habilita notificações e recebe dados FTMS |
| 🗑️ Limpar | Remove todos os logs |
| 📥 Download | Prepara logs para exportar |

### ❌ Se Não Estiver Recebendo Dados

1. **Procure por "RAW BYTES"** nos logs:
   - ✅ Se aparecer: A esteira está enviando dados (possivelmente formato diferente)
   - ❌ Se não aparecer: A esteira não está enviando nada

2. **Verifique se "Testar FTMS" foi bem-sucedido**:
   - ✅ "✅ Notificações habilitadas!" = Tudo certo
   - ❌ "❌ Erro ao habilitar" = Problema de compatibilidade

3. **Verifique a esteira**:
   - Está ligada?
   - Está em modo Bluetooth?
   - Está funcionando (movimento/treino)?

### 📋 Exemplo de Log Bem-Sucedido

```
[12:30:45] INFO: Testar FTMS iniciado
[12:30:45] SUCCESS: ✅ Serviço FTMS encontrado!
[12:30:45] SUCCESS: ✅ Característica Treadmill Data encontrada!
[12:30:45] SUCCESS: ✅ Notificações habilitadas!
[12:30:46] DATA: RAW BYTES (19): 01 E8 03 1E 00 04 00...
[12:30:46] DEBUG: Velocidade: 10.00 km/h
[12:30:47] DATA: RAW BYTES (19): 01 F0 03 1E 00 04 00...
[12:30:47] DEBUG: Velocidade: 10.16 km/h
```

### 📚 Documentação Completa

Para um guia detalhado, veja: [`DEBUG_GUIDE.md`](./DEBUG_GUIDE.md)

### 🆘 Precisando de Ajuda?

1. Abra a tela de debug
2. Reproduza o problema
3. Clique em "Download" para exportar os logs
4. Compartilhe os logs com o desenvolvedor incluindo:
   - Modelo da esteira
   - Marca da esteira
   - Logs do debug
   - Sistema operacional (Android/iOS)

---

**Nota**: A tela de debug é uma ferramenta para diagnóstico. Se tudo está funcionando bem, você não precisa usá-la. Mas se houver problemas, ela ajudará a identificar exatamente o que está acontecendo! 🎯
