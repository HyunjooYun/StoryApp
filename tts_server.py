import os
import asyncio

from dotenv import load_dotenv
from fastapi import FastAPI, WebSocket
import azure.cognitiveservices.speech as speechsdk

load_dotenv()

AZURE_TTS_KEY = os.getenv("AZURE_TTS_KEY")
AZURE_TTS_REGION = os.getenv("AZURE_TTS_REGION")

app = FastAPI()


@app.websocket("/ws/tts")
async def tts_ws(websocket: WebSocket):
    """
    C 구조용 WebSocket TTS 서버:
    - 클라이언트(Flutter)에서 JSON으로 {text, voice, speaking_rate}를 받는다.
    - Azure Speech SDK로 viseme 이벤트만 받아서 WebSocket으로 흘려보낸다.
    - 오디오는 파일로 저장하지 않고, default speaker도 사용하지 않는다.
    """
    await websocket.accept()

    try:
        # 1) Flutter에서 요청 파라미터 받기
        data = await websocket.receive_json()
        text = data.get("text", "")
        voice = data.get("voice", "ko-KR-HyunsuNeural")
        speaking_rate = float(data.get("speaking_rate", 1.0))

        if not text:
            await websocket.send_json({"type": "error", "message": "text is empty"})
            await websocket.close()
            return

        # 2) Azure Speech 설정
        speech_config = speechsdk.SpeechConfig(
            subscription=AZURE_TTS_KEY,
            region=AZURE_TTS_REGION,
        )
        speech_config.speech_synthesis_voice_name = voice

        # viseme 이벤트 활성화
        speech_config.set_property(
            speechsdk.PropertyId.SpeechServiceResponse_RequestViseme, "true"
        )

        # 오디오는 스피커/파일로 출력하지 않음 (C 구조 핵심)
        audio_config = speechsdk.audio.AudioOutputConfig(use_default_speaker=False)

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

        loop = asyncio.get_running_loop()

        # 3) viseme 콜백: viseme_id + audio_offset_ms 를 Flutter로 송신
        def viseme_callback(evt: speechsdk.SpeechSynthesisVisemeEventArgs):
            audio_offset_ms = int(evt.audio_offset / 10000)  # 100ns → ms
            # 비동기로 WebSocket 전송
            asyncio.run_coroutine_threadsafe(
                websocket.send_json(
                    {
                        "type": "viseme",
                        "viseme_id": evt.viseme_id,
                        "audio_offset_ms": audio_offset_ms,
                    }
                ),
                loop,
            )

        synthesizer.viseme_received.connect(viseme_callback)

        # 4) 실제 합성 실행 (오디오는 폐기, viseme 이벤트만 사용)
        result = synthesizer.speak_ssml_async(ssml).get()

        if result.reason != speechsdk.ResultReason.SynthesizingAudioCompleted:
            await websocket.send_json(
                {
                    "type": "error",
                    "message": f"TTS failed: {result.reason}",
                }
            )
        else:
            # 모든 viseme 전송이 끝났음을 알림
            await websocket.send_json({"type": "done"})

    except Exception as e:
        await websocket.send_json({"type": "error", "message": str(e)})
    finally:
        await websocket.close()




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