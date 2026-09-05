"""Processo de reconhecimento de voz offline da F.R.I.D.A.Y.

Captura o microfone padrão, transcreve com Vosk e escreve eventos JSONL no
stdout. O processo não usa rede e não recebe comandos arbitrários do frontend.
"""

from __future__ import annotations

import argparse
import array
import json
import os
import queue
import signal
import shutil
import sys
import time
import zipfile
from pathlib import Path

import sounddevice as sd
from vosk import KaldiRecognizer, Model, SetLogLevel

sys.stdout.reconfigure(encoding="utf-8")


def emit(event_type: str, **payload: object) -> None:
    print(json.dumps({"type": event_type, **payload}, ensure_ascii=False), flush=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--model")
    parser.add_argument("--device", type=int, default=None)
    parser.add_argument("--list-devices", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args()


def input_devices() -> list[dict[str, object]]:
    default_input = None
    try:
        default_input = int(sd.default.device[0])
    except (TypeError, ValueError, IndexError):
        pass

    all_devices = list(sd.query_devices())
    host_apis = list(sd.query_hostapis())
    devices: list[dict[str, object]] = []
    for index, info in enumerate(all_devices):
        channels = int(info.get("max_input_channels", 0))
        if channels <= 0:
            continue
        host_index = int(info.get("hostapi", -1))
        host_name = str(host_apis[host_index].get("name", "")) if 0 <= host_index < len(host_apis) else ""
        # PortAudio apresenta o mesmo dispositivo várias vezes por backend.
        # O padrão do Windows mais as entradas WASAPI formam uma lista curta e útil.
        if index != default_input and host_name != "Windows WASAPI":
            continue
        name = str(info.get("name", f"Microfone {index}"))
        if index == default_input:
            prefix = name.rstrip()
            richer_name = next(
                (
                    str(candidate.get("name"))
                    for candidate in all_devices
                    if str(candidate.get("name", "")).startswith(prefix)
                    and 0 <= int(candidate.get("hostapi", -1)) < len(host_apis)
                    and str(host_apis[int(candidate.get("hostapi", -1))].get("name", "")) == "Windows WASAPI"
                ),
                None,
            )
            if richer_name:
                name = richer_name
        devices.append(
            {
                "id": index,
                "name": name,
                "channels": channels,
                "sample_rate": int(info.get("default_samplerate", 16000)),
                "is_default": index == default_input,
            }
        )
    return devices


REQUIRED_MODEL_FILES = (
    "final.mdl",
    "Gr.fst",
    "HCLr.fst",
    "mfcc.conf",
    "ivector/final.ie",
    "ivector/online_cmvn.conf",
)


def validate_model(model_path: Path) -> None:
    missing = [name for name in REQUIRED_MODEL_FILES if not (model_path / name).is_file()]
    if missing:
        raise RuntimeError(f"modelo incompleto; arquivo ausente: {missing[0]}")


def prepare_model(model_source: Path) -> Path:
    """Retorna uma pasta íntegra de modelo, extraindo o pacote quando necessário."""
    if model_source.is_dir():
        validate_model(model_source)
        return model_source

    if not model_source.is_file() or model_source.suffix.lower() != ".zip":
        raise RuntimeError(f"modelo de voz não encontrado em {model_source}")

    local_data = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
    cache_parent = local_data / "FridayLocal"
    cached_model = cache_parent / "voice-model-pt-0.3"
    try:
        validate_model(cached_model)
        return cached_model
    except RuntimeError:
        pass

    extracting = cache_parent / "voice-model-pt-0.3-extracting"
    cache_parent.mkdir(parents=True, exist_ok=True)
    if extracting.exists():
        shutil.rmtree(extracting)
    extracting.mkdir()

    with zipfile.ZipFile(model_source) as archive:
        extraction_root = extracting.resolve()
        for member in archive.infolist():
            destination = (extracting / member.filename).resolve()
            if extraction_root != destination and extraction_root not in destination.parents:
                raise RuntimeError("o pacote do modelo contém um caminho inválido")
        archive.extractall(extracting)

    candidates = [extracting, *[path for path in extracting.iterdir() if path.is_dir()]]
    extracted_model = next(
        (candidate for candidate in candidates if (candidate / "final.mdl").is_file()),
        None,
    )
    if extracted_model is None:
        shutil.rmtree(extracting, ignore_errors=True)
        raise RuntimeError("o pacote não contém um modelo de português válido")

    validate_model(extracted_model)
    if cached_model.exists():
        shutil.rmtree(cached_model)
    if extracted_model == extracting:
        extracting.rename(cached_model)
    else:
        extracted_model.rename(cached_model)
        shutil.rmtree(extracting, ignore_errors=True)
    return cached_model


def main() -> int:
    args = parse_args()
    if args.list_devices:
        emit("devices", devices=input_devices())
        return 0

    if not args.model:
        emit("error", message="O caminho do modelo de voz não foi informado.")
        return 2

    model_source = Path(args.model).resolve()
    try:
        model_path = prepare_model(model_source)
    except Exception as error:
        emit("error", message=f"Não foi possível preparar o modelo de voz: {error}")
        return 2

    SetLogLevel(-1)
    try:
        model = Model(str(model_path))
    except Exception as error:
        emit("error", message=f"Não foi possível carregar o modelo de voz: {error}")
        return 3

    if args.self_test:
        emit("ready", message="Modelo de português carregado.")
        return 0

    audio_queue: queue.Queue[bytes] = queue.Queue(maxsize=64)

    def audio_callback(indata: bytes, _frames: int, _time: object, status: object) -> None:
        if status:
            emit("warning", message=str(status))
        try:
            audio_queue.put_nowait(bytes(indata))
        except queue.Full:
            try:
                audio_queue.get_nowait()
                audio_queue.put_nowait(bytes(indata))
            except queue.Empty:
                pass

    try:
        device_info = sd.query_devices(args.device, "input")
        # O modelo acústico Kaldi/Vosk de português foi treinado especificamente a 16000 Hz.
        # Capturar em 16 kHz permite que o Windows (WASAPI) realize a reamostragem nativa
        # com filtro anti-aliasing de alta precisão, evitando a distorção que ocorre ao alimentar 44.1/48 kHz.
        target_sample_rate = 16000
        try:
            sd.check_input_settings(device=args.device, samplerate=target_sample_rate, channels=1, dtype="int16")
            sample_rate = target_sample_rate
        except Exception:
            sample_rate = int(device_info.get("default_samplerate", 16000))

        recognizer = KaldiRecognizer(model, sample_rate)
        recognizer.SetWords(True)
        recognizer.SetPartialWords(True)

        with sd.RawInputStream(
            samplerate=sample_rate,
            blocksize=4000,
            device=args.device,
            dtype="int16",
            channels=1,
            callback=audio_callback,
        ):
            emit(
                "ready",
                message="Ouvindo a palavra Sexta-feira.",
                device=str(device_info.get("name", "Microfone padrão")),
                device_id=args.device,
            )
            last_level_at = 0.0
            last_partial = ""
            last_partial_at = 0.0
            last_speech_at = 0.0
            while True:
                data = audio_queue.get()
                now = time.monotonic()
                samples = array.array("h")
                samples.frombytes(data)
                peak = max((abs(sample) for sample in samples), default=0)

                if now - last_level_at >= 0.10:
                    level = min(100, round((peak / 32767) * 200))
                    emit("level", value=level)
                    last_level_at = now

                if peak > 300:
                    last_speech_at = now

                if recognizer.AcceptWaveform(data):
                    result = json.loads(recognizer.Result())
                    text = str(result.get("text", "")).strip()
                    words = result.get("result", [])
                    last_partial = ""
                    if text:
                        emit("transcript", text=text, words=words)
                else:
                    partial_data = json.loads(recognizer.PartialResult())
                    partial = str(partial_data.get("partial", "")).strip()
                    partial_words = partial_data.get("partial_result", [])
                    if partial and partial != last_partial:
                        emit("partial", text=partial, words=partial_words)
                        last_partial = partial
                        last_partial_at = now

                    # Flush por silêncio: se o usuário parou de falar há mais de 0.7s
                    # e havia fala acumulada, descarrega a instrução completa para evitar cancelamento.
                    if (
                        last_partial
                        and (now - last_speech_at >= 0.75)
                        and (now - last_partial_at >= 0.7)
                    ):
                        flushed = json.loads(recognizer.Result())
                        text = str(flushed.get("text", "")).strip()
                        words = flushed.get("result", [])
                        last_partial = ""
                        if text:
                            emit("transcript", text=text, words=words)
    except KeyboardInterrupt:
        return 0
    except Exception as error:
        emit("error", message=f"Falha no microfone: {error}")
        return 4


if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal.default_int_handler)
    sys.exit(main())
