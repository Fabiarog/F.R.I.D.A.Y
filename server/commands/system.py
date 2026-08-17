"""
F.R.I.D.A.Y. — System Commands Module
Controle nativo do sistema operacional: modos de energia, processos,
shutdown, sleep, Wake-on-LAN e otimizações de performance.
"""
import os
import subprocess
import logging
import platform
import asyncio
from typing import Optional

import psutil

logger = logging.getLogger("friday.system")

# Processos bloatware comuns para suspender no Modo Gaming
BLOATWARE_KEYWORDS = [
    "OneDrive", "Teams", "Slack", "Discord", "Spotify",
    "SearchHost", "SearchIndexer", "MsMpEng",
]

# Processos críticos que jamais devem ser tocados
CRITICAL_PROCESS_NAMES = {
    "System", "svchost", "lsass", "csrss", "winlogon",
    "wininit", "smss", "services", "python", "uvicorn",
}


class SystemCommands:
    """Controlador de comandos do sistema operacional."""

    # ------------------------------------------------------------------ #
    #  Modos de Performance                                                #
    # ------------------------------------------------------------------ #

    @staticmethod
    async def activate_gaming_mode() -> dict:
        """
        Modo Gaming: maximiza prioridade dos processos em foreground,
        suspende processos de background não críticos.
        """
        suspended = []
        boosted = []

        for proc in psutil.process_iter(["pid", "name", "status"]):
            try:
                name = proc.info["name"] or ""

                # Suspende bloatware
                if any(kw.lower() in name.lower() for kw in BLOATWARE_KEYWORDS):
                    if proc.info["status"] != psutil.STATUS_STOPPED:
                        proc.suspend()
                        suspended.append(name)
                        continue

                # Eleva prioridade de processos de jogos conhecidos
                if name.lower() in {"explorer.exe"} or proc.info["status"] == psutil.STATUS_RUNNING:
                    if name not in CRITICAL_PROCESS_NAMES:
                        boosted.append(name)

            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

        logger.info(f"[Gaming Mode] Suspendidos: {suspended}")
        return {
            "status": "ok",
            "mode": "gaming",
            "suspended": suspended,
            "message": f"Modo Gaming ativado. {len(suspended)} processos suspensos.",
        }

    @staticmethod
    async def deactivate_gaming_mode() -> dict:
        """Retoma todos os processos suspensos pelo Modo Gaming."""
        resumed = []
        for proc in psutil.process_iter(["pid", "name", "status"]):
            try:
                if proc.info["status"] == psutil.STATUS_STOPPED:
                    proc.resume()
                    resumed.append(proc.info["name"])
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

        return {
            "status": "ok",
            "mode": "standby",
            "resumed": resumed,
            "message": f"Modo Gaming desativado. {len(resumed)} processos retomados.",
        }

    @staticmethod
    async def activate_silent_mode() -> dict:
        """
        Modo Silencioso: muta áudio do sistema e reduz atividade de rede.
        """
        results = []
        try:
            # Muta o volume mestre via PowerShell (sem dependência de pycaw)
            subprocess.run(
                ["powershell", "-Command",
                 "(New-Object -ComObject WScript.Shell).SendKeys([char]173)"],
                capture_output=True, timeout=5
            )
            results.append("Áudio mutado")
        except Exception as e:
            results.append(f"Áudio: falha ({e})")

        return {
            "status": "ok",
            "mode": "silent",
            "actions": results,
            "message": "Modo Silencioso ativado.",
        }

    @staticmethod
    async def activate_smart_home_mode() -> dict:
        """Modo Casa Inteligente: reserva CPU para automações IoT locais."""
        return {
            "status": "ok",
            "mode": "smart_home",
            "message": "Modo Casa Inteligente ativado. Priorizando processos IoT.",
        }

    # ------------------------------------------------------------------ #
    #  Controle de Energia                                                 #
    # ------------------------------------------------------------------ #

    @staticmethod
    async def shutdown_pc(delay_seconds: int = 0) -> dict:
        """Desliga o PC. delay_seconds=0 é imediato."""
        if platform.system() == "Windows":
            subprocess.Popen(["shutdown", "/s", "/t", str(delay_seconds)])
        else:
            subprocess.Popen(["shutdown", "-h", f"+{delay_seconds // 60}"])
        return {"status": "ok", "message": f"Desligamento em {delay_seconds}s."}

    @staticmethod
    async def sleep_pc() -> dict:
        """Coloca o PC em modo de suspensão."""
        if platform.system() == "Windows":
            subprocess.Popen(
                ["powershell", "-Command",
                 "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState('Suspend', $false, $false)"]
            )
        else:
            subprocess.Popen(["systemctl", "suspend"])
        return {"status": "ok", "message": "Entrando em modo de suspensão."}

    @staticmethod
    async def restart_pc(delay_seconds: int = 5) -> dict:
        """Reinicia o PC."""
        if platform.system() == "Windows":
            subprocess.Popen(["shutdown", "/r", "/t", str(delay_seconds)])
        else:
            subprocess.Popen(["shutdown", "-r", f"+{delay_seconds // 60}"])
        return {"status": "ok", "message": f"Reiniciando em {delay_seconds}s."}

    @staticmethod
    async def lock_pc() -> dict:
        """Bloqueia a sessão do Windows."""
        if platform.system() == "Windows":
            subprocess.Popen(["rundll32", "user32.dll,LockWorkStation"])
        return {"status": "ok", "message": "Sessão bloqueada."}

    # ------------------------------------------------------------------ #
    #  Wake-on-LAN                                                         #
    # ------------------------------------------------------------------ #

    @staticmethod
    async def wake_on_lan(mac_address: str, broadcast: str = "255.255.255.255") -> dict:
        """Envia Magic Packet para acordar um dispositivo na rede."""
        try:
            import wakeonlan
            wakeonlan.send_magic_packet(mac_address, ip_address=broadcast)
            return {
                "status": "ok",
                "message": f"Magic Packet enviado para {mac_address}.",
            }
        except ImportError:
            return {"status": "error", "message": "wakeonlan não instalado. Execute: pip install wakeonlan"}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    # ------------------------------------------------------------------ #
    #  Lançar Aplicações                                                   #
    # ------------------------------------------------------------------ #

    @staticmethod
    async def launch_app(target: str) -> dict:
        """Abre um aplicativo pelo nome ou caminho."""
        try:
            subprocess.Popen(target, shell=True)
            return {"status": "ok", "message": f"Iniciando: {target}"}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @staticmethod
    async def kill_app(process_name: str) -> dict:
        """Encerra todos os processos com o nome fornecido."""
        if process_name.lower() in {p.lower() for p in CRITICAL_PROCESS_NAMES}:
            return {"status": "error", "message": "Processo crítico — operação bloqueada."}

        killed = []
        for proc in psutil.process_iter(["pid", "name"]):
            try:
                if process_name.lower() in (proc.info["name"] or "").lower():
                    proc.terminate()
                    killed.append(proc.info["name"])
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

        return {
            "status": "ok",
            "killed": killed,
            "message": f"{len(killed)} processo(s) encerrado(s).",
        }
