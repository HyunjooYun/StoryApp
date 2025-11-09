# StoryApp

## 소개
StoryApp은 한국 및 다문화 가정 아동을 위한 **다국어 동화구연 앱**입니다.  
AI 기반 스크립트 생성, 번역, TTS(음성합성), 2D 캐릭터 애니메이션을 통합하여  
한국어, 영어, 중국어, 베트남어, 일본어, 독일어로 동화를 쉽고 재미있게 들려줍니다.

## 주요 기능
- 연령별/언어별 동화 스크립트 자동 생성 및 번역
- Azure TTS 기반 아동 목소리 합성 (언어/성별/연령 프리셋)
- 2D 캐릭터 립싱크 및 표정 동기화(예정)
- Flutter 기반 모바일 UI (홈, 설정, 동화 선택, 읽기 화면)
- 오프라인 재생, 자막, 진행률 표시 등

## 주요 시나리오/사용법 예시
1. 앱 실행 → 홈 화면에서 동화 듣기/설정 선택
2. 동화 선택 → 연령/언어/캐릭터 선택 → 미리듣기
3. 동화 읽기 화면에서 오디오, 자막, 캐릭터 애니메이션 동기화 감상

## 폴더 구조
- `lib/` : Flutter 앱 소스 (screens, services, models, providers)
- `assets/` : 이미지, 폰트, 동화 텍스트, 오디오, TTS 설정(json)
- `android/` : 안드로이드 빌드 관련 파일
- `test_*.dart` : 테스트/샘플 코드

## 데이터/설정 파일 예시
- `assets/voice_config.json` : 언어/연령/성별별 TTS 파라미터
	```json
	{
		"languages": {
			"독일어": {
				"xmlLang": "de-DE",
				"ageRules": [
					{ "max": 200, "rate": "1.0", "pitch": "0%", "model": { "male": "de-DE-ConradNeural", "female": "de-DE-GiselaNeural" } }
				]
			}
		}
	}
	```
- `.env` : Azure TTS API 키 등 환경변수
- `assets/txt/` : 동화 원문 텍스트 파일

## 설치 및 실행
1. Flutter 3.x 이상 설치
2. `pubspec.yaml`의 의존성 설치  
	 ```
	 flutter pub get
	 ```
3. `.env` 파일에 Azure TTS API 키 등 환경변수 입력
4. 에뮬레이터 또는 디바이스에서 실행  
	 ```
	 flutter run
	 ```

## 구조/아키텍처
```
[Flutter App]
	├─ UI/State (Provider)
	├─ Player (audioplayers)
	├─ TTS Service (Azure API)
	└─ Resource 관리 (voice_config.json, assets)
```

## 기술 스택
- Flutter/Dart, Provider, audioplayers, flutter_tts, http, path_provider, flutter_dotenv
- Azure Speech TTS API, FastAPI(백엔드, 선택)
- 2D 캐릭터/이미지: Flame, Rive, PNG 스프라이트

## 개발/테스트 환경
- 권장 Flutter 3.x, Dart 3.x, Android Studio/VSCode
- Android 10+ 실기기(갤럭시 탭 등) 및 에뮬레이터 테스트

## 환경설정
- `assets/voice_config.json`에서 언어/연령/성별별 TTS 파라미터 관리
- 폰트: `assets/fonts/KoPubWorld Dotum *.ttf` 필요 (README 참고)

## FAQ/트러블슈팅
- **TTS가 동작하지 않아요:** .env 파일의 AZURE_TTS_KEY, AZURE_TTS_REGION, AZURE_TTS_ENDPOINT를 확인하세요.
- **폰트가 깨져 보여요:** KoPubWorld Dotum 폰트 파일이 assets/fonts/에 있는지 확인하세요.
- **오디오가 재생되지 않아요:** 기기 저장공간 권한, 오디오 파일 경로, assets 등록 여부를 확인하세요.

## 라이선스/저작권
- 동화 텍스트, 폰트, 이미지 등은 각 출처 및 라이선스 준수 필요
- 오픈소스 라이브러리 사용 (pubspec.yaml 참고)

## 문의/기여
- 문의: 프로젝트 오너(HyunjooYun) 또는 이슈 등록
- 기여: PR/이슈 환영, 상세 구조 및 코드 설명은 StoryApp development plan.md 참고