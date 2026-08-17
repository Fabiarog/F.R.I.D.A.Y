"""
F.R.I.D.A.Y. — Hub Central Server v4.2
FastAPI + WebSocket assíncrono + Telemetria em tempo real + MQTT opcional

Endpoints:
  GET  /            → Info do hub (para auto-discovery mobile)
  GET  /api/info    → JSON com metadata do hub
  WS   /ws          → Canal bidirecional de comandos e telemetria
  GET  /docs        → Swagger UI (desenvolvimento)

Protocolo WebSocket (JSON):
  Cliente → Servidor: { "action": "string", ...params }
  Servidor → Cliente: { "type": "telemetry"|"response"|"event", ...data }
"""

import asyncio
import json
import logging
import platform
import socket
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

import psutil
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware

from commands.system import SystemCommands
from commands.media import MediaCommands

# ──────────────────────────────────────────────────────────────────────────────
# Configuração de logging
# ──────────────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("friday.server")

# ──────────────────────────────────────────────────────────────────────────────
# Constantes
# ──────────────────────────────────────────────────────────────────────────────
HUB_VERSION   = "4.2.0"
TELEMETRY_HZ  = 2.0        # Frequência de broadcast de telemetria (segundos)
MQTT_ENABLED  = False       # Defina True e configure MQTT_HOST para ativar
MQTT_HOST     = "localhost"
MQTT_PORT     = 1883
MQTT_TOPIC_PREFIX = "friday/telemetry"

# ──────────────────────────────────────────────────────────────────────────────
# GPU: tenta pynvml (NVIDIA), fallback para dados mock
# ──────────────────────────────────────────────────────────────────────────────
try:
    import pynvml
    pynvml.nvmlInit()
    GPU_HANDLE = pynvml.nvmlDeviceGetHandleByIndex(0)
    GPU_NAME   = pynvml.nvmlDeviceGetName(GPU_HANDLE)
    GPU_AVAILABLE = True
    logger.info(f"GPU NVIDIA detectada: {GPU_NAME}")
except Exception:
    GPU_AVAILABLE = False
    GPU_NAME = "N/A"
    logger.warning("pynvml não disponível — telemetria de GPU desativada.")

# ──────────────────────────────────────────────────────────────────────────────
# MQTT (opcional)
# ──────────────────────────────────────────────────────────────────────────────
mqtt_client = None
if MQTT_ENABLED:
    try:
        import paho.mqtt.client as mqtt_lib
        mqtt_client = mqtt_lib.Client(client_id="friday_hub")
        mqtt_client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
        mqtt_client.loop_start()
        logger.info(f"MQTT conectado em {MQTT_HOST}:{MQTT_PORT}")
    except Exception as e:
        logger.warning(f"MQTT indisponível: {e}")
        mqtt_client = None


# ──────────────────────────────────────────────────────────────────────────────
# WebSocket Connection Manager
# ──────────────────────────────────────────────────────────────────────────────
class ConnectionManager:
    """Gerencia múltiplas conexões WebSocket simultâneas."""

    def __init__(self):
        self._connections: list[WebSocket] = []
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket):
        await ws.accept()
        async with self._lock:
            self._connections.append(ws)
        logger.info(f"[WS] Nova conexão. Total: {len(self._connections)}")

    async def disconnect(self, ws: WebSocket):
        async with self._lock:
            try:
                self._connections.remove(ws)
            except ValueError:
                pass
        logger.info(f"[WS] Desconectado. Total: {len(self._connections)}")

    async def broadcast(self, data: dict):
        """Envia JSON para todos os clientes conectados."""
        dead = []
        async with self._lock:
            connections = list(self._connections)
        for ws in connections:
            try:
                await ws.send_json(data)
            except Exception:
                dead.append(ws)
        for ws in dead:
            await self.disconnect(ws)

    async def send_to(self, ws: WebSocket, data: dict):
        """Envia JSON para um cliente específico."""
        try:
            await ws.send_json(data)
        except Exception:
            await self.disconnect(ws)

    @property
    def count(self) -> int:
        return len(self._connections)


manager = ConnectionManager()


# ──────────────────────────────────────────────────────────────────────────────
# Coleta de Telemetria
# ──────────────────────────────────────────────────────────────────────────────
def collect_telemetry() -> dict:
    """Coleta snapshot completo de métricas do sistema."""
    # CPU
    cpu_pct  = psutil.cpu_percent(interval=None)
    cpu_freq = psutil.cpu_freq()
    cpu_ghz  = round(cpu_freq.current / 1000, 2) if cpu_freq else 0.0

    # RAM
    ram = psutil.virtual_memory()

    # Disco
    disk = psutil.disk_usage("/")

    # Rede
    net_io = psutil.net_io_counters()

    # Temperatura (Windows — pode retornar vazio)
    temps: dict[str, float] = {}
    try:
        all_temps = psutil.sensors_temperatures()
        if all_temps:
            for sensor, readings in all_temps.items():
                if readings:
                    temps[sensor] = readings[0].current
    except AttributeError:
        pass  # Windows frequentemente não suporta sensors_temperatures

    # GPU (NVIDIA via pynvml)
    gpu_data: dict[str, Any] = {"available": GPU_AVAILABLE, "name": GPU_NAME}
    if GPU_AVAILABLE:
        try:
            util  = pynvml.nvmlDeviceGetUtilizationRates(GPU_HANDLE)
            mem   = pynvml.nvmlDeviceGetMemoryInfo(GPU_HANDLE)
            temp  = pynvml.nvmlDeviceGetTemperature(GPU_HANDLE, pynvml.NVML_TEMPERATURE_GPU)
            gpu_data.update({
                "load_pct":   util.gpu,
                "vram_used":  round(mem.used  / 1024**3, 1),
                "vram_total": round(mem.total / 1024**3, 1),
                "temp_c":     temp,
            })
        except Exception:
            gpu_data["available"] = False

    return {
        "type": "telemetry",
        "timestamp": time.time(),
        "cpu": {
            "pct":   cpu_pct,
            "ghz":   cpu_ghz,
            "cores": psutil.cpu_count(logical=False),
            "threads": psutil.cpu_count(logical=True),
        },
        "ram": {
            "pct":      ram.percent,
            "used_gb":  round(ram.used  / 1024**3, 1),
            "total_gb": round(ram.total / 1024**3, 1),
        },
        "disk": {
            "pct":      disk.percent,
            "free_gb":  round(disk.free  / 1024**3, 1),
            "total_gb": round(disk.total / 1024**3, 1),
        },
        "net": {
            "bytes_sent": net_io.bytes_sent,
            "bytes_recv": net_io.bytes_recv,
        },
        "gpu":   gpu_data,
        "temps": temps,
        "clients_connected": manager.count,
    }


# ──────────────────────────────────────────────────────────────────────────────
# Loop de Broadcast de Telemetria
# ──────────────────────────────────────────────────────────────────────────────
async def telemetry_broadcast_loop():
    """Tarefa em background: coleta e distribui telemetria periodicamente."""
    logger.info("[Telemetry] Loop iniciado.")
    while True:
        try:
            data = collect_telemetry()

            # Broadcast WebSocket → todos os clientes
            if manager.count > 0:
                await manager.broadcast(data)

            # Publish MQTT → Home Assistant
            if mqtt_client and MQTT_ENABLED:
                for key, val in data.items():
                    if isinstance(val, (int, float, str)):
                        mqtt_client.publish(
                            f"{MQTT_TOPIC_PREFIX}/{key}",
                            payload=str(val),
                            retain=True,
                        )
                    elif isinstance(val, dict):
                        mqtt_client.publish(
                            f"{MQTT_TOPIC_PREFIX}/{key}",
                            payload=json.dumps(val),
                            retain=True,
                        )

        except Exception as e:
            logger.error(f"[Telemetry] Erro: {e}")

        await asyncio.sleep(TELEMETRY_HZ)


# ──────────────────────────────────────────────────────────────────────────────
# Processamento de Comandos WebSocket
# ──────────────────────────────────────────────────────────────────────────────
async def process_command(ws: WebSocket, payload: dict) -> dict:
    """
    Roteia ações recebidas via WebSocket para os módulos de comando.
    Retorna um dict de resposta.
    """
    action = payload.get("action", "")
    logger.info(f"[CMD] action={action} payload={payload}")

    # ── Modos de Sistema ─────────────────────────────────────────────────
    if action == "gaming_mode":
        return await SystemCommands.activate_gaming_mode()

    elif action == "gaming_mode_off":
        return await SystemCommands.deactivate_gaming_mode()

    elif action == "silent_mode":
        return await SystemCommands.activate_silent_mode()

    elif action == "smart_home_mode":
        return await SystemCommands.activate_smart_home_mode()

    # ── Telemetria sob demanda ───────────────────────────────────────────
    elif action == "get_telemetry":
        return collect_telemetry()

    # ── Energia ──────────────────────────────────────────────────────────
    elif action == "shutdown":
        delay = int(payload.get("delay", 0))
        return await SystemCommands.shutdown_pc(delay)

    elif action == "sleep":
        return await SystemCommands.sleep_pc()

    elif action == "restart":
        delay = int(payload.get("delay", 5))
        return await SystemCommands.restart_pc(delay)

    elif action == "lock":
        return await SystemCommands.lock_pc()

    # ── Wake-on-LAN ───────────────────────────────────────────────────────
    elif action == "wake_on_lan":
        mac = payload.get("mac", "")
        bcast = payload.get("broadcast", "255.255.255.255")
        if not mac:
            return {"status": "error", "message": "Campo 'mac' obrigatório."}
        return await SystemCommands.wake_on_lan(mac, bcast)

    # ── Aplicações ────────────────────────────────────────────────────────
    elif action == "launch_app":
        target = payload.get("target", "")
        if not target:
            return {"status": "error", "message": "Campo 'target' obrigatório."}
        return await SystemCommands.launch_app(target)

    elif action == "kill_app":
        name = payload.get("process_name", "")
        if not name:
            return {"status": "error", "message": "Campo 'process_name' obrigatório."}
        return await SystemCommands.kill_app(name)

    # ── Mídia ─────────────────────────────────────────────────────────────
    elif action == "media_play_pause":
        return await MediaCommands.play_pause()

    elif action == "media_next":
        return await MediaCommands.next_track()

    elif action == "media_prev":
        return await MediaCommands.prev_track()

    elif action == "media_stop":
        return await MediaCommands.stop_media()

    elif action == "volume_up":
        steps = int(payload.get("steps", 5))
        return await MediaCommands.volume_up(steps)

    elif action == "volume_down":
        steps = int(payload.get("steps", 5))
        return await MediaCommands.volume_down(steps)

    elif action == "mute_toggle":
        return await MediaCommands.mute_toggle()

    elif action == "set_volume":
        level = int(payload.get("level", 50))
        return await MediaCommands.set_volume_percent(level)

    # ── Ping / Heartbeat ──────────────────────────────────────────────────
    elif action == "ping":
        return {"type": "pong", "status": "ok", "timestamp": time.time()}

    else:
        return {"status": "error", "message": f"Ação desconhecida: '{action}'"}


# ──────────────────────────────────────────────────────────────────────────────
# Lifespan (startup / shutdown)
# ──────────────────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Inicia o loop de telemetria junto com o servidor."""
    task = asyncio.create_task(telemetry_broadcast_loop())
    logger.info("=" * 60)
    logger.info("  F.R.I.D.A.Y. Hub Central v4.2 — ONLINE")
    logger.info(f"  Host: {socket.gethostname()}")
    logger.info(f"  IP local: {socket.gethostbyname(socket.gethostname())}")
    logger.info(f"  Endereço WS: ws://<IP_LOCAL>:8000/ws")
    logger.info(f"  Swagger UI: http://localhost:8000/docs")
    logger.info("=" * 60)
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass
    if mqtt_client:
        mqtt_client.loop_stop()
        mqtt_client.disconnect()
    logger.info("[FRIDAY] Hub desligado com segurança.")


# ──────────────────────────────────────────────────────────────────────────────
# Aplicação FastAPI
# ──────────────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="F.R.I.D.A.Y. Hub Central",
    description="Backend neural para controle multiplataforma do ecossistema F.R.I.D.A.Y.",
    version=HUB_VERSION,
    lifespan=lifespan,
)

# CORS: permite qualquer origem local (mobile na mesma rede)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ──────────────────────────────────────────────────────────────────────────────
# HTTP Endpoints
# ──────────────────────────────────────────────────────────────────────────────
# Caminho para index.html (pasta pai do server/)
_INDEX_HTML = Path(__file__).parent.parent / "index.html"


@app.get("/", tags=["HUD"])
async def root():
    """
    Serve o HUD neural diretamente no browser.
    No celular: abra http://<IP_DO_PC>:8000
    O WebSocket se conecta automaticamente via JS.
    """
    if _INDEX_HTML.exists():
        # Serve o index.html com o WS_URL ajustado para o IP real
        content = _INDEX_HTML.read_text(encoding="utf-8")
        # Substitui localhost pelo IP real para funcionar no celular
        local_ip = socket.gethostbyname(socket.gethostname())
        content = content.replace(
            "ws://localhost:8000/ws",
            f"ws://{local_ip}:8000/ws"
        )
        return HTMLResponse(content=content)
    # Fallback: JSON de discovery
    return HTMLResponse(
        content="<h1>F.R.I.D.A.Y. Hub Online</h1><p>index.html não encontrado.</p>",
        status_code=200,
    )


@app.get("/api/discovery", tags=["Discovery"])
async def discovery():
    """Endpoint de auto-discovery — retorna JSON de identificação do Hub."""
    return {
        "service": "friday_hub",
        "version": HUB_VERSION,
        "hostname": socket.gethostname(),
        "platform": platform.system(),
        "ws_endpoint": "/ws",
    }


@app.get("/api/info", tags=["Discovery"])
async def get_info():
    """Informações detalhadas do Hub (para painel de conexão mobile)."""
    return {
        "service":    "friday_hub",
        "version":    HUB_VERSION,
        "hostname":   socket.gethostname(),
        "platform":   platform.system(),
        "cpu_model":  platform.processor(),
        "gpu_name":   GPU_NAME,
        "mqtt":       MQTT_ENABLED,
        "clients":    manager.count,
        "uptime":     time.time(),
        "ws_endpoint": "ws://<HOST_IP>:8000/ws",
    }


@app.get("/api/telemetry", tags=["Telemetry"])
async def get_telemetry_http():
    """Snapshot de telemetria via HTTP (para polling)."""
    return collect_telemetry()


# ──────────────────────────────────────────────────────────────────────────────
# WebSocket Endpoint Principal
# ──────────────────────────────────────────────────────────────────────────────
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """
    Canal bidirecional principal.
    O servidor PUSH telemetria automaticamente a cada ~2s.
    O cliente PULL comandos enviando JSON: {"action": "...", ...params}
    """
    await manager.connect(websocket)

    # Envia boas-vindas imediatas
    await manager.send_to(websocket, {
        "type": "connected",
        "status": "ok",
        "message": "F.R.I.D.A.Y. Hub conectado. Sistemas online.",
        "version": HUB_VERSION,
    })

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                await manager.send_to(websocket, {
                    "type": "error",
                    "message": "JSON inválido.",
                })
                continue

            response = await process_command(websocket, payload)

            # Sempre envolve em tipo "response" se não vier com "type"
            if "type" not in response:
                response["type"] = "response"

            await manager.send_to(websocket, response)

    except WebSocketDisconnect:
        await manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"[WS] Erro inesperado: {e}")
        await manager.disconnect(websocket)


# ──────────────────────────────────────────────────────────────────────────────
# Entry Point
# ──────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info",
        ws_ping_interval=20,    # mantém conexões mobile vivas
        ws_ping_timeout=30,
    )
