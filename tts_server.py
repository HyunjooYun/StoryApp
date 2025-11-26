import os
import asyncio
import logging
from concurrent.futures import Future
from datetime import datetime
from pathlib import Path
from threading import Lock
from typing import Set

from dotenv import load_dotenv
from fastapi import FastAPI, WebSocket
import azure.cognitiveservices.speech as speechsdk
from starlette.websockets import WebSocketDisconnect, WebSocketState

load_dotenv()

AZURE_TTS_KEY = os.getenv("AZURE_TTS_KEY")
AZURE_TTS_REGION = os.getenv("AZURE_TTS_REGION")

app = FastAPI()

logger = logging.getLogger("tts_server")
if not logger.handlers:
    logger.setLevel(logging.INFO)

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(logging.Formatter("[%(levelname)s] %(message)s"))
    logger.addHandler(console_handler)

    log_dir = Path(__file__).resolve().parent / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"tts_server_{datetime.now():%Y%m%d}.log"
    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setFormatter(
        logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    )
    logger.addHandler(file_handler)

    logger.propagate = False



class _NullAudioOutputStream(speechsdk.audio.PushAudioOutputStreamCallback):
    """Sink that discards all audio data to avoid using the default speaker."""

    def write(self, audio_buffer: memoryview) -> int:  # type: ignore[override]
        return len(audio_buffer)

    def close(self) -> None:  # type: ignore[override]
        pass


@app.websocket("/ws/tts")
async def tts_ws(websocket: WebSocket):
    """
    C 구조용 WebSocket TTS 서버:
    - 클라이언트(Flutter)에서 JSON으로 {text, voice, speaking_rate}를 받는다.
    - Azure Speech SDK로 viseme 이벤트만 받아서 WebSocket으로 흘려보낸다.
    - 오디오는 파일로 저장하지 않고, default speaker도 사용하지 않는다.
    """
    await websocket.accept()

    pending_viseme_futures: Set[Future] = set()
    pending_viseme_lock = Lock()
    loop = asyncio.get_running_loop()

    async def _drain_pending_visemes() -> None:
        while True:
            with pending_viseme_lock:
                if not pending_viseme_futures:
                    break
                futures_snapshot = list(pending_viseme_futures)
            await asyncio.gather(
                *(asyncio.wrap_future(fut, loop=loop) for fut in futures_snapshot),
                return_exceptions=True,
            )

    try:
        # 1) Flutter에서 요청 파라미터 받기
        data = await websocket.receive_json()
        text = data.get("text", "")
        voice = data.get("voice", "ko-KR-HyunsuNeural")
        speaking_rate = float(data.get("speaking_rate", 1.0))

        logger.info(
            "Received TTS request | voice=%s speaking_rate=%.2f chars=%d",
            voice,
            speaking_rate,
            len(text),
        )

        if not text:
            try:
                await websocket.send_json({"type": "error", "message": "text is empty"})
            except WebSocketDisconnect:
                logger.info("Client disconnected before empty-text notice")
            await websocket.close()
            return

        # 2) Azure Speech 설정
        speech_config = speechsdk.SpeechConfig(
            subscription=AZURE_TTS_KEY,
            region=AZURE_TTS_REGION,
        )
        speech_config.speech_synthesis_voice_name = voice

        # viseme 이벤트 활성화
        if hasattr(
            speechsdk.PropertyId, "SpeechServiceResponse_RequestViseme"
        ):
            speech_config.set_property(
                speechsdk.PropertyId.SpeechServiceResponse_RequestViseme,
                "true",
            )
        else:
            # Fallback for SDK builds without the enum constant.
            speech_config.set_property_by_name(
                "speechserviceconnection_requestviseme", "true"
            )

        # 오디오는 스피커/파일로 출력하지 않고 바로 폐기한다.
        null_stream = speechsdk.audio.PushAudioOutputStream(_NullAudioOutputStream())
        audio_config = speechsdk.audio.AudioOutputConfig(stream=null_stream)

        # 명시적으로 기본 스피커 출력 비활성화 (일부 SDK 버전 대응)
        if hasattr(
            speechsdk.PropertyId, "SpeechServiceResponse_EnableDefaultOutput"
        ):
            speech_config.set_property(
                speechsdk.PropertyId.SpeechServiceResponse_EnableDefaultOutput,
                "false",
            )

        synthesizer = speechsdk.SpeechSynthesizer(
            speech_config=speech_config,
            audio_config=audio_config,
        )

        # speaking_rate를 SSML의 prosody rate로 변환
        # (너가 사용하는 REST 쪽 로직에 맞게 나중에 조정해도 됨)
        if abs(speaking_rate - 1.0) < 0.05:
            rate_str = "0%"
        else:
            rate_percent = int((speaking_rate - 1.0) * 100)
            rate_str = f"{rate_percent}%"

        ssml = f"""
<speak version='1.0' xml:lang='ko-KR'>
  <voice name='{voice}'>
    <prosody rate='{rate_str}'>
      {text}
    </prosody>
  </voice>
</speak>
""".strip()

        async def _send_viseme(payload: dict) -> None:
            try:
                if websocket.application_state == WebSocketState.DISCONNECTED:
                    logger.info(
                        "Skipping viseme send; websocket already disconnected",
                    )
                    return
                await websocket.send_json(payload)
            except WebSocketDisconnect:
                logger.info("Client disconnected before viseme delivery")
            except RuntimeError as exc:
                message = str(exc)
                if "Cannot call \"send\" once a close message has been sent" in message:
                    logger.debug("Viseme send skipped after close signal")
                else:  # pragma: no cover - unexpected runtime error
                    logger.exception("Failed to send viseme payload: %s", exc)
            except Exception as exc:  # pragma: no cover - defensive logging
                logger.exception("Failed to send viseme payload: %s", exc)

        # 3) viseme 콜백: viseme_id + audio_offset_ms 를 Flutter로 송신
        def viseme_callback(evt: speechsdk.SpeechSynthesisVisemeEventArgs):
            audio_offset_ms = int(evt.audio_offset / 10000)  # 100ns → ms
            logger.info(
                "Viseme event | viseme_id=%s offset_ms=%d",
                evt.viseme_id,
                audio_offset_ms,
            )
            payload = {
                "type": "viseme",
                "viseme_id": evt.viseme_id,
                "audio_offset_ms": audio_offset_ms,
            }
            future = asyncio.run_coroutine_threadsafe(_send_viseme(payload), loop)

            def _cleanup(fut: Future) -> None:
                with pending_viseme_lock:
                    pending_viseme_futures.discard(fut)

            with pending_viseme_lock:
                pending_viseme_futures.add(future)
            future.add_done_callback(_cleanup)

        synthesizer.viseme_received.connect(viseme_callback)

        # 4) 실제 합성 실행 (오디오는 폐기, viseme 이벤트만 사용)
        result = synthesizer.speak_ssml_async(ssml).get()

        await _drain_pending_visemes()

        if result.reason != speechsdk.ResultReason.SynthesizingAudioCompleted:
            try:
                await websocket.send_json(
                    {
                        "type": "error",
                        "message": f"TTS failed: {result.reason}",
                    }
                )
            except WebSocketDisconnect:
                logger.info("Client disconnected before error delivery")
            logger.error("Synthesis failed | reason=%s", result.reason)
        else:
            try:
                # 모든 viseme 전송이 끝났음을 알림
                await websocket.send_json({"type": "done"})
                logger.info("Synthesis completed successfully")
            except WebSocketDisconnect:
                logger.info("Client disconnected before completion")
    except WebSocketDisconnect:
        logger.info("Client disconnected")
    except Exception as e:
        logger.exception("TTS websocket error: %s", e)
        try:
            await websocket.send_json({"type": "error", "message": str(e)})
        except WebSocketDisconnect:
            logger.debug("Client disconnected while sending error message")
    finally:
        await _drain_pending_visemes()
        try:
            await websocket.close()
        except Exception:
            pass




""" 예전 코드
import azure.cognitiveservices.speech as speechsdk
from fastapi import FastAPI, WebSocket
from dotenv import load_dotenv
import os
import asyncio

load_dotenv()
app = FastAPI()

AZURE_TTS_KEY = os.getenv("AZURE_TTS_KEY")
AZURE_TTS_REGION = os.getenv("AZURE_TTS_REGION")

@app.websocket("/ws/tts")
async def tts_ws(websocket: WebSocket):
    await websocket.accept()
    try:
        data = await websocket.receive_json()
        text = data.get("text", "")
        voice = data.get("voice", "ko-KR-SeoHyeonNeural")
        speech_config = speechsdk.SpeechConfig(subscription=AZURE_TTS_KEY, region=AZURE_TTS_REGION)
        audio_config = speechsdk.audio.AudioOutputConfig(filename="output.wav")
        synthesizer = speechsdk.SpeechSynthesizer(speech_config, audio_config)

        # 실시간 viseme 이벤트 전송
        def viseme_callback(evt):
            audio_offset_ms = int(evt.audio_offset / 10000)  # 100-ns → ms
            async def send_viseme():
                await websocket.send_json({
                    "type": "viseme",
                    "viseme_id": evt.viseme_id,
                    "audio_offset": audio_offset_ms
                })
            loop = asyncio.get_event_loop()
            asyncio.run_coroutine_threadsafe(send_viseme(), loop)
        synthesizer.viseme_received.connect(viseme_callback)

        result = synthesizer.speak_text_async(text).get()

        # TTS 완료 후 오디오 파일 경로 전송
        await websocket.send_json({"type": "audio", "path": "output.wav"})
        await websocket.send_json({"type": "done"})
    except Exception as e:
        await websocket.send_json({"type": "error", "message": str(e)})
    finally:
        await websocket.close()

        """