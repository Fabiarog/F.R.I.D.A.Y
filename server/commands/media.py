"""
F.R.I.D.A.Y. — Media Commands Module
Controle de áudio, volume e teclas de mídia do sistema.
"""
import logging
import subprocess
import platform

logger = logging.getLogger("friday.media")


class MediaCommands:
    """Controlador de áudio e mídia do sistema."""

    # ------------------------------------------------------------------ #
    #  Teclas de Mídia (Cross-Platform via subprocess/powershell)          #
    # ------------------------------------------------------------------ #

    @staticmethod
    def _send_media_key_windows(vk_code: int):
        """Envia tecla virtual via PowerShell (sem pyautogui)."""
        script = f"""
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class KeySend {{
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
    public static void PressKey(byte vk) {{
        keybd_event(vk, 0, 0, 0);
        keybd_event(vk, 0, 2, 0);
    }}
}}
"@
[KeySend]::PressKey({vk_code})
"""
        subprocess.run(["powershell", "-Command", script], capture_output=True, timeout=5)

    # VK codes para teclas de mídia no Windows
    VK_MEDIA_PLAY_PAUSE = 0xB3
    VK_MEDIA_NEXT_TRACK = 0xB0
    VK_MEDIA_PREV_TRACK = 0xB1
    VK_MEDIA_STOP       = 0xB2
    VK_VOLUME_UP        = 0xAF
    VK_VOLUME_DOWN      = 0xAE
    VK_VOLUME_MUTE      = 0xAD

    @staticmethod
    async def play_pause() -> dict:
        """Alterna play/pause na mídia atual."""
        try:
            if platform.system() == "Windows":
                MediaCommands._send_media_key_windows(MediaCommands.VK_MEDIA_PLAY_PAUSE)
            return {"status": "ok", "message": "Play/Pause alternado."}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @staticmethod
    async def next_track() -> dict:
        """Avança para a próxima faixa."""
        try:
            if platform.system() == "Windows":
                MediaCommands._send_media_key_windows(MediaCommands.VK_MEDIA_NEXT_TRACK)
            return {"status": "ok", "message": "Próxima faixa."}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @staticmethod
    async def prev_track() -> dict:
        """Volta para a faixa anterior."""
        try:
            if platform.system() == "Windows":
                MediaCommands._send_media_key_windows(MediaCommands.VK_MEDIA_PREV_TRACK)
            return {"status": "ok", "message": "Faixa anterior."}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @staticmethod
    async def stop_media() -> dict:
        """Para a reprodução de mídia."""
        try:
            if platform.system() == "Windows":
                MediaCommands._send_media_key_windows(MediaCommands.VK_MEDIA_STOP)
            return {"status": "ok", "message": "Mídia parada."}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @staticmethod
    async def volume_up(steps: int = 5) -> dict:
        """Aumenta o volume do sistema."""
        try:
            if platform.system() == "Windows":
                for _ in range(steps):
                    MediaCommands._send_media_key_windows(MediaCommands.VK_VOLUME_UP)
            return {"status": "ok", "message": f"Volume +{steps}."}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @staticmethod
    async def volume_down(steps: int = 5) -> dict:
        """Diminui o volume do sistema."""
        try:
            if platform.system() == "Windows":
                for _ in range(steps):
                    MediaCommands._send_media_key_windows(MediaCommands.VK_VOLUME_DOWN)
            return {"status": "ok", "message": f"Volume -{steps}."}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @staticmethod
    async def mute_toggle() -> dict:
        """Alterna mute do volume mestre."""
        try:
            if platform.system() == "Windows":
                MediaCommands._send_media_key_windows(MediaCommands.VK_VOLUME_MUTE)
            return {"status": "ok", "message": "Mute alternado."}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    @staticmethod
    async def set_volume_percent(level: int) -> dict:
        """
        Define o volume para um nível percentual (0–100) via PowerShell.
        Usa NIRCMD se disponível, senão via WScript puro.
        """
        level = max(0, min(100, level))
        try:
            script = f"""
$vol = [Math]::Round({level} * 655.35)
Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {{
    int f(); int g(); int h(); int i();
    int SetMasterVolumeLevelScalar(float fLevel, System.Guid pguidEventContext);
    int j();
    int GetMasterVolumeLevelScalar(out float pfLevel);
    int k(); int l(); int m(); int n();
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, System.Guid pguidEventContext);
    int GetMute(out bool pbMute);
}}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {{
    int Activate(ref System.Guid id, int clsCtx, int activationParams, out IAudioEndpointVolume aev);
}}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {{
    int f();
    int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
}}
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorComObject {{ }}
public class AudioManager {{
    static IAudioEndpointVolume Vol() {{
        var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
        IMMDevice dev = null;
        Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(0, 1, out dev));
        IAudioEndpointVolume vol = null;
        var iid = typeof(IAudioEndpointVolume).GUID;
        Marshal.ThrowExceptionForHR(dev.Activate(ref iid, 23, 0, out vol));
        return vol;
    }}
    public static float GetVolume() {{
        float outvol = 0;
        Marshal.ThrowExceptionForHR(Vol().GetMasterVolumeLevelScalar(out outvol));
        return outvol;
    }}
    public static void SetVolume(float newVolume) {{
        Marshal.ThrowExceptionForHR(Vol().SetMasterVolumeLevelScalar(newVolume, System.Guid.Empty));
    }}
}}
"@ -ReferencedAssemblies System.Runtime.InteropServices
[AudioManager]::SetVolume({level / 100.0:.2f})
"""
            subprocess.run(["powershell", "-Command", script], capture_output=True, timeout=10)
            return {"status": "ok", "message": f"Volume definido em {level}%."}
        except Exception as e:
            return {"status": "error", "message": str(e)}
