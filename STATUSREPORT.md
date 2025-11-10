

# StoryApp 개발 현황 보고서 (STATUSREPORT)

## [파일명 변경 안내]
- 기존 StatusReport.md → **STATUSREPORT.md**로 변경 (대문자)
- 앞으로 모든 개발 현황 및 변경 이력은 이 파일에 기록

---


## [최근 업데이트 내역]
- 2025-11-10: StatusReport.md → STATUSREPORT.md로 파일명 변경
- 2025-11-10: 기능별 상세 진행상황, 기술적 의사결정, 구조, 데이터 예시, FAQ, 개발환경 등까지 포함해 더 자세하게 확장
- 2025-11-10: 독일어 TTS(Conrad/Gisela) 지원, voice_config.json/코드 동시 반영
- 2025-11-10: README.md, STATUSREPORT.md 최신화

### [2025-11-10 추가 작업]
- 동화 읽기(story_reading) 화면 TTS 재생 로직 전면 개선: 텍스트 박스 내 모든 문장 순차 재생, 페이지 이동/멈춤 시 즉시 중지, 현재 페이지에만 재생 동작 보장
- Vietnamese TTS 모델 이슈 진단: voice_config.json 및 Azure TTS 서비스 연동 상태 점검, 모델명/리전/API 오류 가능성 안내
- Python 코드 현황 점검: 백엔드/서버 코드 없음, create_icon.py(아이콘 생성용)만 존재


작성일: 2025-11-10

---

## 1. 프로젝트 개요
- **목표:** 다국어(한국어, 영어, 중국어, 베트남어, 일본어, 독일어) 동화구연 앱 개발
- **주요 기능:** AI 스크립트 생성, 번역, TTS, 2D 캐릭터 립싱크/표정, Flutter UI, 오프라인 재생, 자막, 진행률 표시 등

---

## 2. 완료된 주요 작업 및 상세 내역

### 2.1 모델/데이터 구조
- Story, StorySettings 모델 설계 및 업데이트 (progress/status, volume, 캐릭터 이미지/이름 메서드 등)
- voice_config.json: 언어/연령/성별별 TTS 파라미터 관리, 독일어(Conrad/Gisela) 추가
- 동화 텍스트, 오디오, 이미지, 폰트 등 리소스 정리

### 2.2 UI/UX 구현
- 홈 화면: 그라데이션 배경, 캐릭터, 동화 듣기/설정 버튼, 버전 표시
- 설정 화면: 언어 버튼(6개), 연령 드롭다운, 캐릭터 카드, 볼륨/속도 슬라이더, 완료/취소
- 동화 선택 화면: 동화 카드(4개), 진행률, 파일 업로드, 상태 색상
- 동화 읽기 화면: 캐릭터, 텍스트, 페이지네이션, Play/Pause 토글, 자막

### 2.3 서비스/로직
- Provider 구조화, prepareStory/prepareCurrentStory 메서드 구현
- Azure TTS 연동: voice_config.json 기반 rate/pitch 직접 SSML에 적용, 언어/성별별 목소리 지정
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
