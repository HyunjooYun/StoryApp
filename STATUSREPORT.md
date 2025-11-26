

# StoryApp 개발 현황 보고서 (STATUSREPORT)

## [파일명 변경 안내]
- 기존 StatusReport.md → **STATUSREPORT.md**로 변경 (대문자)
- 앞으로 모든 개발 현황 및 변경 이력은 이 파일에 기록

---




## [최근 업데이트 내역]


### 2025-11-27
- Flutter 앱에서 viseme 큐가 비어 있는 문제 재현 후 서버/클라이언트 로그 수집
- FastAPI `tts_server.py`의 viseme 전송 로직을 Future 집합과 락으로 보호하도록 재작성하여 WebSocket 종료 이후에도 이벤트가 누락되지 않도록 수정
- `done` 메시지 전송 전에 대기 중인 viseme 작업을 모두 소모하도록 `_drain_pending_visemes()` 구현, 전송 실패 로그를 정리해 노이즈 제거
- 앱 재실행으로 viseme 이벤트 정상 수신 및 립싱크 이미지 전환 확인(소폭 딜레이는 존재, 추후 튜닝 예정)


### 2025-11-25
- Azure Speech SDK 버전 확인(1.47.0) 및 Conda 기반 환경으로 viseme FastAPI 서버 재구동 작업 수행
- 8000 포트 점유 프로세스(PID 19724) 정리 후 `conda run python -m uvicorn` 조합으로 서버 정상 기동 확인
- Flutter `dart run` 스크립트가 Flutter SDK 타입 의존성으로 실패하는 이슈 파악, `flutter pub run` 필요성 기록
- 최신 코드에서 립싱크 애니메이션 미동작 현상 재확인; 원인 미해결 상태로 남기고 추후 디버깅 예정


### 2025-11-24
- story_reading 화면에 TTS 일시정지/재개 및 viseme 동기화를 다시 붙이려다 위젯 트리/상태 코드가 뒤엉켜 Flutter 빌드 실패 발생
- git restore로 `lib/screens/story_reading_screen.dart`를 마지막 정상 커밋 상태로 복구하여 현재는 안정 버전 유지 (TTS 실행 버튼은 아직 TODO 상태)
- 다음 작업을 위해 `_playCurrentPageTTS()`에 Azure TTS mp3 생성 로직과 viseme 이벤트 스트림 처리 플로우를 다시 설계해야 함
- 작업 재개 전 git 분기/백업을 활용해 실험용 브랜치에서 구현 후 병합하는 일정 필요

### 2025-11-22 ~ 2025-11-23
- story_reading 화면 텍스트 박스 내 문장 TTS 순차 재생 기능 구현
- 멈춤/페이지 이동 시 TTS 즉시 중지 기능 구현
- 페이지 이동 후 실행 버튼 동작 개선 (해당 페이지 텍스트 TTS 재생)
- viseme 이미지 스케일/포지션 캐릭터 박스 기준 자동 조정
- 타이머 기반 임시 립싱크(랜덤 viseme 스와핑) 구현
- Azure TTS REST API 기반 음성 생성 및 mp3 저장
- viseme.md 테이블 기반 viseme 이미지 매핑 구조 정비
- TXT 파일 업로드/변환/적용 기능 개선
- 기타: 코드 정리, lint 경고 일부 수정

### 2025-11-17
- Azure TTS mp3 속도 문제 진단 및 해결: SSML rate 값을 퍼센트(%) 대신 'x-slow', 'slow', 'medium', 'fast', 'x-fast' 등으로 변환하여 자연스러운 속도 구현
- mp3 파일 저장 경로 로그 추가, SSML 파라미터/실제 적용값 로그로 디버깅 용이성 강화
- 동화 읽기(story_reading) 화면의 텍스트 박스 내 실제 보이는 영역 기준으로 동적 페이지네이션 구현 (TextPainter 활용)
- 한 페이지에 보이는 텍스트만 TTS로 재생, 페이지 이동/멈춤 시 TTS 즉시 중지, 실행 버튼을 눌러야만 해당 페이지 TTS 재생
- 페이지네이션/스크립트 동기화 개선: 변환된 스크립트(adaptedScript)가 바로 화면에 반영되도록 구조 점검 및 개선
- TXT 파일 업로드/추가 기능 구현: 사용자가 새로운 텍스트 파일을 업로드하면 동화로 바로 읽고, 연령별/번역/적응 스크립트로 변환하여 story_reading 화면에서 확인 가능
- 기타: 미사용 변수/함수 lint 경고, 코드 정리

### 2025-11-10
- StatusReport.md → STATUSREPORT.md로 파일명 변경
- 기능별 상세 진행상황, 기술적 의사결정, 구조, 데이터 예시, FAQ, 개발환경 등까지 포함해 더 자세하게 확장
- 독일어 TTS(Conrad/Gisela) 지원, voice_config.json/코드 동시 반영
- README.md, STATUSREPORT.md 최신화

작성일: 2025-11-10

---

## 1. 프로젝트 개요
- **목표:** 다국어(한국어, 영어, 중국어, 베트남어, 일본어, 독일어) 동화구연 앱 개발
- **주요 기능:** AI 스크립트 생성, 번역, TTS, 2D 캐릭터 립싱크/표정, Flutter UI, 오프라인 재생, 자막, 진행률 표시 등

---

## 2. 완료된 주요 작업 및 상세 내역

### 2.1 모델/데이터 구조
- Story, StorySettings 모델 설계 및 업데이트 (progress/status, volume, 캐릭터 이미지/이름 메서드 등)
- adaptedScript 필드: 업로드/변환된 스크립트(연령별, 번역, TXT 파일 등) 저장 및 화면 반영
- TXT 파일 업로드 시 Story 인스턴스 자동 생성 및 adaptedScript에 변환 결과 저장
- voice_config.json: 언어/연령/성별별 TTS 파라미터 관리, 독일어(Conrad/Gisela) 추가
- 동화 텍스트, 오디오, 이미지, 폰트 등 리소스 정리

### 2.2 UI/UX 구현
- 홈 화면: 그라데이션 배경, 캐릭터, 동화 듣기/설정 버튼, 버전 표시
- 설정 화면: 언어 버튼(6개), 연령 드롭다운, 캐릭터 카드, 볼륨/속도 슬라이더, 완료/취소
- 동화 선택 화면: 동화 카드(4개), 진행률, 파일 업로드, 상태 색상
- 동화 읽기 화면: 캐릭터, 텍스트, 페이지네이션, Play/Pause 토글, 자막

### 2.3 서비스/로직
- Provider 구조화, prepareStory/prepareCurrentStory 메서드 구현
- TXT 파일 업로드/추가 → Story/스크립트 변환/적용 전체 파이프라인 구현
- adaptedScript가 있으면 화면/페이지네이션/TTS 모두 변환된 스크립트 기준으로 동작
- Azure TTS 연동: voice_config.json 기반 rate/pitch 직접 SSML에 적용, 언어/성별별 목소리 지정
- SSML rate: 퍼센트(%) 대신 'x-slow', 'slow', 'medium', 'fast', 'x-fast' 등으로 변환하여 자연스러운 속도 구현
- 동화 읽기 화면: TextPainter로 텍스트 박스 크기 기준 동적 페이지네이션, 한 페이지 단위 TTS/동기화
- 오디오 재생, 자막, 진행률 표시 등 동기화

### 2.4 환경설정/자원
- 폰트(assets/fonts/KoPubWorld Dotum), 이미지/오디오/텍스트 리소스, pubspec.yaml 의존성 및 asset 경로 관리

---

## 3. 기술적 의사결정 및 구조
- **TTS:** Azure Speech API 사용, voice_config.json로 언어/연령/성별별 프리셋 관리(확장성/유지보수 용이)
- **UI:** Flutter(Material3), Provider 패턴, 커스텀 위젯 활용
- **오디오/애니메이션:** audioplayers, flutter_tts, 향후 Flame/Rive 연동 고려
- **데이터/설정:** .env(키), voice_config.json(파라미터), pubspec.yaml(의존성)

---

## 4. 이슈/리스크 및 해결방안
- TTS rate/pitch 변환 없이 config 값 그대로 SSML에 적용하도록 개선(자연스러운 음성)
- 독일어 TTS: 남성 Conrad, 여성 Gisela 모델로 지정(voice_config.json/코드 동시 반영)
- 미사용 변수/함수(lint 경고) 존재: 기능에는 영향 없음
- 립싱크/표정 동기화: MVP에서는 미구현, 향후 Rhubarb/MFA/벤더 phoneme 이벤트 연동 예정
- 테스트 기기 다양화 필요(갤럭시 탭, 저사양 디바이스 등)

---

## 5. 진행 중/남은 작업 및 일정
- [ ] 전체 기능 갤럭시 탭 실기기 빌드 및 테스트
- [ ] 버그 수정 및 UI 폴리싱(접근성, 반응형 등)
- [ ] 추가 언어/캐릭터/동화 확장(voice_config.json 및 리소스 구조 확장)
- [ ] 사용자 피드백 반영 및 최종 배포 준비
- [ ] 립싱크/표정 동기화 엔진 연동(2차 목표)

---

## 6. 참고자료/문서
- 상세 기획 및 기술 문서: `StoryApp development plan.md`, `README.md`
- 환경설정: `.env`, `voice_config.json`, `pubspec.yaml`
- 샘플 데이터: `assets/txt/`, `assets/audio/`, `assets/images/`

---

(이 문서는 최신 개발 현황을 요약한 것으로, 추가 요청/변경사항 발생 시 업데이트 예정)
