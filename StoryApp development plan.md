# 다국어 동화구연 프로그램 기획서 (Python + Flutter/Dart)

버전: v0.9 (초안)  
작성일: 2025-11-08 (KST)

---

## 0. 요약 (Executive Summary)
한국 및 다문화 가정의 아동이 한국 전래동화를 다섯 언어(한국어, 영어, 중국어, 베트남어, 일본어)로 쉽고 몰입감 있게 즐길 수 있도록 **생성형 AI 스크립팅 + 번역 + TTS + 2D 캐릭터 립싱크/표정 동기화**를 통합한 크로스플랫폼(안드로이드) 앱을 Flutter로 개발한다. 
백엔드는 Python(FastAPI)로 구성하여 스크립트 생성·번역·음성합성·립싱크 타임라인 산출을 API로 제공한다.

---

## 1. 목표 및 범위
### 1.1 목표
- 연령별 난이도에 맞춘 동화 스크립트 **자동 생성**
- 선택 언어로 **자동 번역** 및 **아동 또래 톤의 TTS**
- **AI 기반 자동 립싱크**(음성→음소/비지메→입모양 타임라인) 및 **표정 동기화**
- 동화 재생 중 **자막, 페이지 전환, 사운드 이펙트** 동시 제어

### 1.2 범위 (MVP)
- 5개 언어 지원 (ko/en/zh/vi/ja)
- 2D 스프라이트 캐릭터 1종(표정 6~8종, 비지메 10~12셋)
- 음성 파일 입력만으로 립싱크 타임라인 자동 산출
- 모바일 앱(Flutter) + Python 백엔드 API

---

## 2. 타깃 사용자 & 페르소나
- **아동 사용자 (4~10세)**: 듣기·보기 중심, 쉬운 UI, 또래 목소리 선호
- **보호자/교사**: 언어/연령/속도/톤 설정, 재생 이력 관리, 로컬/클라우드 보안

---

## 3. 요구사항
### 3.1 기능 요구사항 (FR)
1. 동화 선택/텍스트 업로드 → 연령대 선택 → 스크립트 생성(요약·난이도 조절)
2. 선택 언어로 번역 → 품질 보정(용어 사전/스타일 프롬프트 적용)
3. TTS 합성(아동 톤/속도/피치 프리셋) → 오디오 파일(S16LE wav or mpeg) 생성
4. 오디오→음소(phoneme)/비지메(viseme) 추출 → **입모양 타임라인(JSON)** 생성
5. 스크립트 감정 태깅(문장 단위) → **표정 타임라인(JSON)** 생성
6. Flutter에서 오디오·자막·스프라이트 애니메이션을 **동일 시계**로 재생
7. 프로젝트/동화 단위로 **내보내기(타임라인 JSON + 리소스)**

### 3.2 비기능 요구사항 (NFR)
- **지연 시간**: 타임라인 산출 10s 이내(2~3분 오디오 기준, 비동기 처리)
- **오프라인 재생**: 합성된 오디오/타임라인은 로컬 캐시 후 오프라인 재생 가능
- **보안/개인정보**: 업로드 텍스트/오디오 암호화 저장(REST API는 HTTPS/TLS)
- **확장성**: 언어/캐릭터/표정 세트 수평 확장 가능(플러그인 구조)
- **접근성**: 자막 온/오프, 재생 속도, 색약 모드, 큰 글씨 지원

---

## 4. 시스템 아키텍처
```
[Flutter App]
  ├─ UI/State (Riverpod/Bloc)
  ├─ Player (just_audio)
  ├─ Sprite Engine (Flame or Rive + custom controller)
  └─ REST Client (dio/http)
        ↓ HTTPS
[Python FastAPI]
  ├─ Script Service (LLM promptor)
  ├─ MT Service (Translation)
  ├─ TTS Orchestrator (vendor adapters)
  ├─ Phoneme/Viseme Extractor (rhubarb|MFA|TTS-phoneme)
  ├─ Emotion Tagger (sentence-level)
  ├─ Timeline Composer (viseme & expression JSON)
  └─ Storage (S3/GCS or local + DB)
```

---

## 5. 기술 스택
### 5.1 모바일(Flutter/Dart)
- **상태관리**: Riverpod or Bloc
- **HTTP**: dio
- **오디오**: just_audio (gapless, precise seek)
- **애니메이션**: Flame(스프라이트), Rive(벡터) 중 택1 또는 혼용
- **자막**: WebVTT/SRT 파서 + 커스텀 위젯
- **로컬 저장소**: hive/shared_preferences + path_provider

### 5.2 백엔드(Python)
- **웹 프레임워크**: FastAPI + Uvicorn
- **비동기 작업**: Celery/RQ + Redis(Queue)
- **연령 기반 스크립트 생성**: OpenAI API
- **LLM/번역**: Azure AI Translator
- **TTS**: Azure Speech
- **음소/립싱크**:
  - 1) **Rhubarb Lip Sync**(CLI) → WAV 입력→phoneme JSON 출력
  - 2) **MFA/Gentle** 등 강제 정렬(forced alignment)
  - 3) **TTS 제공 phoneme/viseme 이벤트** 직접 활용(벤더 지원 시)
- **스토리지/DB**: PostgreSQL + S3 호환(Object Storage)

---

## 6. 데이터 모델 & 파일 포맷
### 6.1 스크립트(문장 단위)
```json
{
  "storyId": "hej-001",
  "ageBand": "7-8",
  "language": "ko",
  "sentences": [
    {"id":"s1","text":"옛날 옛날에…","start":0.00,"end":3.12,
     "emotion":"calm","speaker":"child_female"}
  ]
}
```

### 6.2 비지메 타임라인(JSON)
```json
{
  "audioUrl": "https://.../hej-001_ko.wav",
  "fps": 60,
  "visemes": [
    {"t":0.00,"v":"rest"},
    {"t":0.08,"v":"AI"},
    {"t":0.16,"v":"E"},
    {"t":0.24,"v":"O"}
  ]
}
```
> `v`는 다음 12개셋 예시: `rest, A, E, I, O, U, BMP, FV, L, R, S, TH`

### 6.3 표정 타임라인(JSON)
```json
{
  "expressions": [
    {"t":0.00,"name":"idle","dur":1.0},
    {"t":1.00,"name":"smile_soft","dur":2.5},
    {"t":6.20,"name":"surprise","dur":0.6}
  ]
}
```

### 6.4 자막(WebVTT 예시)
```
WEBVTT

00:00:00.000 --> 00:00:03.120
옛날 옛날에…
```

---

## 7. 핵심 알고리즘/파이프라인
### 7.1 스크립트 생성
1) 원문 텍스트/스토리 ID 입력  
2) 연령대(어휘·문장 길이·문식성 프리셋) → LLM 프롬프트  
3) 문장 단위 시간 예측(초기값: 읽기 속도 wpm 기반) → 후속 정렬 단계에서 보정

### 7.2 번역/스타일
- 용어 사전과 말투 가이드(어린이-친근/존댓말/구어체) 적용
- 문장 ID 유지 → 다국어 자막/표정 타임라인에 공통 키 사용

### 7.3 TTS 합성
- 목소리 프리셋: `child_female_7-8_ko`, `child_male_9-10_en` 등  
- 파라미터: `rate`, `pitch`, `volume`, `style`("cheerful", "narration")

### 7.4 립싱크(음성→비지메)
- 우선순위: **TTS 벤더의 phoneme/viseme 이벤트** > Rhubarb > MFA
- 후처리:
  - 미세 타이밍 보정(attack/decay 30~50ms),
  - 무성 구간 `rest`,
  - frame snapping(60fps 기준),
  - 비지메 지속시간 최소값(예: 80ms) 강제

### 7.5 표정 동기화
- 문장/구 단위 감정 추정("calm, happy, surprise, sad, angry")
- 전이 애니메이션: ease-in-out 150~250ms
- 긴 문장 내 이벤트(감탄사, 의성어)에 미소/놀람 스파이크 삽입

---

## 8. API 설계 (FastAPI)
### 8.1 엔드포인트
- `POST /v1/script/generate`  
  - req: `{storyId|text, ageBand, targetLang}`  
  - res: `script JSON`
- `POST /v1/translate`  
  - req: `{script, targetLang}`  
  - res: `script(JSON, translated)`
- `POST /v1/tts/synthesize`  
  - req: `{scriptId, voicePreset}`  
  - res: `{audioUrl, duration}`
- `POST /v1/lipsync/viseme`  
  - req: `{audioUrl|audioBlob, lang}`  
  - res: `{visemeTimeline}`
- `POST /v1/expression/timeline`  
  - req: `{script}`  
  - res: `{expressionTimeline}`
- `POST /v1/timeline/compose`  
  - req: `{visemeTimeline, expressionTimeline, caption}`  
  - res: `{bundleUrl|zip}`

### 8.2 예시 코드 스니펫 (Python/FastAPI)
```python
from fastapi import FastAPI, UploadFile
app = FastAPI()

@app.post("/v1/lipsync/viseme")
async def lipsync(audio: UploadFile, lang: str):
    # 1) WAV 변환 → 2) rhubarb 실행 → 3) JSON 파싱
    # 4) 후처리(attack/decay, minDur) → 5) 반환
    return {"fps": 60, "visemes": [...]}  # 축약
```

---

## 9. Flutter 앱 설계
### 9.1 네비게이션 흐름
1) 홈(동화 선택/업로드) → 2) 연령/언어 선택 → 3) 미리듣기 → 4) 재생(Scene)

### 9.2 상태/서비스 레이어
- **Repository 패턴**: ScriptRepo, TTSRepo, TimelineRepo
- **State**: `StoryState{ script, audio, visemeTL, exprTL, captions }`

### 9.3 재생 화면(핵심 위젯)
- `JustAudioPlayer`(onPosition stream)
- `SpriteStage`(Flame/Rive)
- `CaptionBar`
- `SyncController` : 오디오 시각→타임라인 샘플→스프라이트 상태 전환

### 9.4 Dart 의사코드
```dart
void onTick(Duration pos) {
  final v = visemeAt(pos);
  final e = expressionAt(pos);
  sprite.setMouth(v);
  sprite.setExpression(e);
}
```

---

## 10. 스프라이트 & 애니메이션 규격
- 해상도: 캐릭터 1024×1024(실사용 512~1024 @ device DPR)
- 비지메 셋(12): `rest, A, E, I, O, U, BMP, FV, L, R, S, TH`
- 표정: `idle, smile_soft, smile_big, surprise, sad, angry, blink`
- 파일명 규칙: `charA_mouth_A.png`, `charA_expr_smile.png`
- 아틀라스: `charA_mouth.atlas.json`, `charA_expr.atlas.json`

---

## 11. 품질/테스트 계획
- **오디오-입모양 오차 측정**: 랜드마크 기반 시각 검증(표본 30 문장, ±80ms 기준)
- **언어별 발음 케이스**: 파열음/파찰음/비음 등 스팟 체크
- **연령대 TTS 자연성 평가**: MOS 라이트 설문(아동/보호자 20명)
- **성능**: 60fps 유지, 드롭 프레임 < 2% (중저가 디바이스 기준)

---

## 12. 보안/개인정보/윤리
- 텍스트/오디오/타임라인에 PII 없음 확인
- 전송·저장 암호화, 로그 마스킹, 키 관리(KMS)
- 아동 음성 합성 사용 가이드 표시(오남용 방지)

---

## 13. 배포/운영
- 모바일: Play Store/TestFlight → 단계적 출시
- 백엔드: 컨테이너(Uvicorn+Gunicorn) + 오브젝트 스토리지 + CDN
- 모니터링: Sentry(앱), Prometheus/Grafana(백엔드)

---

## 14. 로드맵 (12주 예시)
- **W1-2**: 스펙 고도화, 리소스 규격/아틀라스 정의, FastAPI 스캐폴딩
- **W3-4**: 스크립트/번역/TTS 어댑터, 스토리지 연동
- **W5-6**: Rhubarb/MFA 통합, 비지메 후처리, 표정 타이머
- **W7-8**: Flutter 플레이어+스프라이트 엔진, 동기화 컨트롤러
- **W9**: UX 폴리싱(자막/설정), 접근성, 캐시
- **W10**: 테스트·버그픽스, 성능 최적화
- **W11**: 베타 테스트
- **W12**: 스토어 제출

---

## 15. 확장 아이디어
- 실시간 대화형 캐릭터(챗봇)로 확장: 마이크 입력→TTS 응답→동기화 실시간 재생
- BGM/효과음 자동 큐레이션(장면 태그 기반)
- 조정 가능한 감정 강도 슬라이더(미세 표현 제어)

---

## 16. 부록 A — 매핑 테이블(예시)
| Phoneme | Viseme |
|---|---|
| p,b,m | BMP |
| f,v | FV |
| t,d,s,z | S |
| k,g | R |
| l | L |
| r(eng), ɾ(ko) | R |
| a | A |
| e | E |
| i | I |
| o | O |
| u | U |
| θ,ð | TH |

---

## 17. 부록 B — 예시 프롬프트(요약)
- 연령대별 어휘/문장 길이/어투 규칙 목록화 → LLM 시스템 프롬프트로 입력
- 다국어 톤 가이드(존댓말/친근체/의성어 비율) 포함

---

## 18. 리스크 & 대응
- 언어마다 발음-비지메 매핑 차이 → 언어별 튜닝 프로필
- TTS 벤더 변경 시 품질/비용 변동 → 어댑터 인터페이스 고정
- 저사양 기기 프레임 드랍 → 텍스처 아틀라스/스케일드 다운샘플링

---

## 19. 라이선스/저작권
- 전래동화 텍스트 출처/번역 권리 확인
- 폰트/스프라이트/오디오 라이선스 관리(OSS 컴플라이언스)

---

## 20. 마일스톤 산출물 체크리스트
- [ ] 스키마/타임라인 JSON v1 고정
- [ ] TTS 프리셋(연령/성별/언어) 세트 확정
- [ ] 비지메/표정 아틀라스 1차 납품
- [ ] E2E 데모(1개 동화, 5개 언어) 재생 성공

