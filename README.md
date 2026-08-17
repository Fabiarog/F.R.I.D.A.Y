# F.R.I.D.A.Y. — Guia de Setup Completo

**Female Replacement Intelligent Digital Assistant Youth — Ecossistema Neural v4.2**

---

## Estrutura do Projeto

```
F.R.I.D.A.Y/
├── index.html              ← HUD Web (abre no browser, conecta ao Hub via WebSocket)
├── start_hub.bat           ← Inicia o servidor Python com um clique
├── package.json            ← Config Tauri (desktop nativo)
│
├── server/                 ← Hub Central Python
│   ├── server.py           ← FastAPI + WebSocket + Telemetria + Comandos
│   ├── requirements.txt    ← Dependências pip
│   └── commands/
│       ├── system.py       ← Gaming mode, shutdown, WoL, launch apps
│       └── media.py        ← Play/pause, volume via virtual keys
│
├── src-tauri/              ← Desktop nativo (Tauri v2)
│   ├── tauri.conf.json     ← Janela sem bordas, 1440×900, transparente
│   ├── Cargo.toml          ← Manifest Rust
│   └── src/main.rs         ← Entry point + system tray
│
└── friday_mobile/          ← App Flutter Android/iOS
    ├── pubspec.yaml
    └── lib/
        ├── main.dart               ← Boot splash + Provider
        ├── theme/neural_theme.dart ← Design system neural
        ├── services/
        │   ├── ws_service.dart     ← WebSocket + reconexão + telemetry stream
        │   └── discovery.dart      ← Auto-discovery de Hubs na LAN
        ├── screens/
        │   ├── home_screen.dart    ← HUD principal mobile
        │   └── settings_screen.dart← Config IP, discovery, WoL
        └── widgets/
            ├── neural_orb.dart     ← Orbe com CustomPainter
            ├── telemetry_panel.dart← Gauges animados
            ├── agent_card.dart     ← Cards de agentes
            └── mode_button.dart    ← Botões de modo
```

---

## 1. Hub Central (Backend Python)

### Requisitos
- **Python 3.11+** → [python.org](https://python.org)

### Iniciar
```batch
:: Opção A — Script automático (Windows)
start_hub.bat

:: Opção B — Manual
cd server
pip install -r requirements.txt
python server.py
```

### Verificar
- **Swagger UI:** http://localhost:8000/docs
- **WebSocket:** ws://localhost:8000/ws
- **Telemetria HTTP:** http://localhost:8000/api/telemetry

### Comandos WebSocket disponíveis
| Action | Parâmetros | Descrição |
|--------|-----------|-----------|
| `get_telemetry` | — | Snapshot de métricas |
| `gaming_mode` | — | Suspende bloatware, otimiza CPU |
| `gaming_mode_off` | — | Retoma todos os processos |
| `silent_mode` | — | Muta áudio |
| `smart_home_mode` | — | Prioriza IoT |
| `launch_app` | `target: string` | Abre aplicativo |
| `kill_app` | `process_name: string` | Encerra processo |
| `shutdown` | `delay: int` | Desliga o PC |
| `sleep` | — | Suspende o PC |
| `restart` | `delay: int` | Reinicia |
| `lock` | — | Bloqueia sessão |
| `wake_on_lan` | `mac: string` | Magic Packet |
| `media_play_pause` | — | Play/Pause |
| `media_next` | — | Próxima faixa |
| `media_prev` | — | Faixa anterior |
| `volume_up` | `steps: int` | Aumenta volume |
| `volume_down` | `steps: int` | Diminui volume |
| `mute_toggle` | — | Mute/Unmute |
| `set_volume` | `level: 0-100` | Define volume exato |
| `ping` | — | Heartbeat |

---

## 2. HUD Web (Desktop no Browser)

Abra `index.html` diretamente no browser.

O HUD automaticamente:
- Tenta conectar em `ws://localhost:8000/ws`
- Usa dados simulados se o Hub estiver offline
- Exibe dados reais de CPU/RAM/GPU quando conectado
- Envia comandos de Gaming Mode / Silent Mode ao Hub

---

## 3. Desktop Nativo (Tauri v2)

### Requisitos
- **Node.js 20+** → [nodejs.org](https://nodejs.org)
- **Rust** → [rustup.rs](https://rustup.rs)
- **Visual C++ Build Tools** → Visual Studio Installer

### Instalar e Executar
```bash
# Na raiz do projeto
npm install
npm run dev    # Dev mode (abre janela nativa)
npm run build  # Gera instalador .exe
```

A janela é **sem bordas e transparente** — mantém a estética HUD. Use o ícone na system tray para minimizar/restaurar.

---

## 4. App Mobile Flutter

### Requisitos
- **Flutter SDK 3.19+** → [flutter.dev](https://flutter.dev/docs/get-started/install)
- **Android Studio** (para emulador ou device físico)

### Instalar e Executar
```bash
cd friday_mobile
flutter pub get
flutter run               # Emulador ou device USB
flutter build apk --release  # Gera APK para instalação
```

### Configurar IP do Hub
1. Abra o app → toque no ícone ⚙ (configurações)
2. **Discovery Automático:** toque em "Varrer Rede" — o app detecta o Hub automaticamente
3. **Manual:** insira o IP e porta do Hub (ex: `192.168.1.10 : 8000`)
4. Toque "Conectar ao Hub"

### Emulador Android
Use `10.0.2.2` como IP (aponta para o host da máquina).

---

## 5. MQTT / Home Assistant (Opcional)

1. Edite `server/server.py`:
```python
MQTT_ENABLED = True
MQTT_HOST    = "192.168.1.X"  # IP do seu broker MQTT / HA
```

2. O Hub publicará métricas nos tópicos:
```
friday/telemetry/cpu
friday/telemetry/ram
friday/telemetry/gpu
friday/telemetry/disk
```

---

## 6. Wake-on-LAN

Para ligar o PC remotamente via celular:

1. **BIOS:** ative "Wake on LAN" / "PCI Wake"
2. **Windows:** Propriedades do adaptador de rede → Avançado → "Wake on Magic Packet = Enabled"
3. **App Mobile:** Configurações → WoL → insira o MAC Address do PC
4. Toque "Enviar Magic Packet"

O celular enviará o comando `wake_on_lan` ao Hub, que transmite o pacote UDP na rede.

---

## 7. VPN (Tailscale — Acesso Remoto)

Para controlar o PC de qualquer lugar:

1. Instale [Tailscale](https://tailscale.com) no PC e no celular
2. Use o IP Tailscale do PC (ex: `100.64.x.x`) nas configurações do app
3. A porta 8000 será acessível pela VPN sem abrir firewall externo

---

## Troubleshooting

| Problema | Solução |
|---------|---------|
| HUD mostra dados simulados | `server.py` não está rodando. Execute `start_hub.bat` |
| Mobile não conecta | Verifique se PC e celular estão na mesma rede Wi-Fi. Confirme o IP com `ipconfig` |
| Erro `pynvml` no servidor | GPU não é NVIDIA. Comente `import pynvml` em `server.py` |
| Tauri não compila | Instale Rust + Visual C++ Build Tools |
| App Flutter não instala | Ative "Fontes desconhecidas" nas configurações do Android |

---

*F.R.I.D.A.Y. Systems © 2026 — Neural Command Interface*
