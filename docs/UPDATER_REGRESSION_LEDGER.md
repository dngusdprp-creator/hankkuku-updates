# 한꾸꾸 자동 업데이트 장애·회귀 방지 장부

> **상태:** OPEN / 2026-11-12 KST 기준. 업데이트 엔진 자동설치 E2E **미통과**. 개발자 PC 설치본 v0.14.22, GitHub 최신 공개 v0.14.23. 이 문서는 릴리스 성공 보고서가 아닌 **다음 패치 전 반드시 읽을 실패·검증 계약**이다.
>
> **공개 저장소 주의:** 계정명, 로컬 사용자 폴더, 토큰, 개인키, Google Drive 데이터, 음성 원문을 커밋하지 않는다.

## 작업 불변 원칙

1. **시작 전 필독:** 이 파일과 연결된 OPEN Issue를 읽고, 기존 실패 사례 전부에 대한 회귀 검증을 먼저 실행한다. 실패한 경로의 기존 코드를 수정·재사용하고, 이유 없이 또 다른 FIX를 덧붙이지 않는다.
2. **증거 구분:** `소스 확인` / `합성 시험 PASS` / `Windows 실환경 PASS` / `사용자 PC 실증 PASS`를 구분한다. 합성 PASS는 실환경 설치 PASS가 아니다.
3. **최소 수정:** 실제 설치본과 소스 SHA를 검증한 뒤 최소 변경. R26 서명, R71/R76/R78, 원복, AppId, 설치 경로, 사용자 데이터 보존 조건을 완화하지 않는다.
4. **전체 경로 검사:** 수정 전에 *생산자→기록 파일→파서→Worker→Inno→재시작→원복*을 순서대로 검사한다. 같은 버그를 개별 증상마다 고치지 않는다.
5. **실제 입력 재현:** 테스트는 실제 수집한 R164/R166/R167/R170/R171/R174/R175 기록 구조를 기반으로 만든다. 개인 파일 경로·계정 정보는 마스킹한다.
6. **실패 시 중단:** 실패한 가드의 의미를 기록하고 실제 불일치 값을 특정한다. 증빙 수정/재설치/재배포/버전 증가로 우회하지 않는다. 사용자가 반복 명령을 수행하기 전에 내부 재현·정적 검사·패키지 자체 검사를 마친다.
7. **배포 승인 게이트:** 서명 자산만 PASS했다고 사용자 PC 전환을 승인하지 않는다. 개발자 PC 실제 원클릭 설치, 재시작, 데이터 보존, 실패/복구를 검증한다. 사용자 PC 구버전은 별도 부트스트랩 계획이 필요하다.
8. **결과 영수증:** 작업마다 기준 SHA, 수정 파일, 새 SHA, 실행 방식, 실패 원인 코드, 테스트 범위, 운영 영향, 롤백 방법, 성공/미검증 항목을 Issue에 남긴다. 임의로 PASS를 만들지 않는다.

## 확인된 장애 장부

| ID | 단계 | 확정 관찰·근거 | 원인 / 재발 방지 테스트 | 상태 |
|---|---|---|---|---|
| HKK-U-001 | v0.14.19 업데이트 조회 | GitHub API HTTP 415 | `qt_r23_update.py` GitHub Release JSON 요청의 `Accept: application/octet-stream` 부적합. JSON 요청/바이너리 다운로드 각각 적절한 헤더 검증 | v0.14.21 이후 조회 수정, 구버전 최초 전환 미해결 |
| HKK-U-002 | v0.14.21 임장노트 | 지역 ID 14 음성 2개·보고서 1297자 조회, GUI 갱신 문제 | 선택된 아파트 상세 상태에서 전체 보고서 새로고침이 상세 내용을 유지하는 분기. R164 수정 실사용 확인 | v0.14.22 반영 |
| HKK-U-003 | R161 | `Dir` PowerShell 기본 alias 충돌, `System32` 경로 탐색 | 내장 별칭과 동명 함수 금지. PowerShell 5.1 스크립트 파서 검증 및 실제 호출 smoke | 수정 |
| HKK-U-004 | R171 FIX1~FIX3 | 따옴표 없는 SHA PowerShell 문법 오류; Python 경로 괄호 누락; `python -I`에서 local import 실패 | 실제 PowerShell 5.1 AST/파서 검증, `python -I -B` 실제 실행 경로 테스트, main·test·runner를 동일 패키지로 검증 | 수정 |
| HKK-U-005 | R171 기록 | R167 결과 `R167_BACKUP` 키가 경로와 상태로 2회 출력 | 생산자 스키마가 키 중복을 사용. 고유 키/반복 키를 명시적으로 구분, 실제 기록에 대한 순서·개수·중복 테스트 | FIX1 후 보완 |
| HKK-U-006 | R171 FIX4~FIX7 | R167 백업 경로·3개 SHA가 빈 문자열. R164 SHA 영문 대소문자 차이 | 결과 파일 생성 결함. 빈 값을 승인으로 처리하지 않고 기존 백업·설치 해시·Inno 기록·R26 서명으로 독립 대조. 해시 정규화 비교 | R171 FIX7 운영 PASS |
| HKK-U-007 | R171 FIX5~FIX6 | `R166_UPLOAD_START`/ `PASS` 정상 반복 5회가 일반 중복으로 차단 | R166 진행 이벤트는 5개 자산별 정확한 10개 이벤트로 검증; 다른 중복 고유 키는 차단 | FIX6 회귀 PASS |
| HKK-U-008 | v0.14.22 설치 신뢰 | R71 없음, R76 GUI SHA 불일치 | 실제 설치 후 새 R71·R78 신뢰 연결 필요. R171 FIX7 + 독립 R170 `PASS_SIGNED_01422_BASELINE` | **개발자 PC 실증 PASS** |
| HKK-U-009 | v0.14.22→0.14.23 원클릭 | R174 Worker `BLOCKED / WorkerBlocked_REGISTRY_ROOT_APPID_NOT_MATCHED`; R175 HKCU 64/32 동일 설치 경로, Inno 정보 존재, `UninstallString`의 실제 제거 파일은 `unins001.exe` | **소스 확정:** `hkk_r81_real_inno.registry_entries()`가 `'unins000.exe' in uninstall`을 강제하고 `is_inno=False`로 판정; `hkk_r79_worker.check_registry()`→`hkk_r77_identity.registry_match()`가 거부. 반드시 실제 Inno 제거기 이름·정확한 설치 루트·파일 존재·HKCU AppId·레지스트리 고유성을 검사하도록 수정 | **OPEN / 가장 먼저 해결** |
| HKK-U-010 | v0.14.22→v0.14.23 | 0.14.23 R26 서명·GitHub 공개 PASS. Stage 6개 존재. 실제 설치는 R174에서 차단 | 배포 PASS≠원클릭 E2E PASS. 다시 업로드·신규 버전 생성하지 말고 Worker registry 소스 수정 및 격리 회귀 시험 | OPEN |
| HKK-U-011 | 사용자 PC v0.14.19 | 초기 HTTP 415 구버전 자체에 잔존, 최초 자동 전환 미실증 | 기존 사용자 DB/Google Drive·레이아웃 보존을 전제로 최초 전환 계약 별도 설계. 사용자에게 직접 ZIP/PowerShell을 요구하는 방식은 원칙적으로 지양 | OPEN |
| HKK-U-012 | R177 후보 Worker 격리 빌드 | R177 소스14/14·설치본 0.14.22·stage 0.14.23 모두 PASS 후 `DIR_MISSING_OR_REPARSE__release_candidates`로 BLOCKED | **소스 확정:** R177이 `Path.home()/Documents/한꾸꾸...` 경로를 하드코딩하여, 이미 정상 작동한 R172의 Windows `MyDocuments`+R171/R172 영수증 기반 프로젝트 발견 방식을 재사용하지 않음. 실제 사용자 문서 루트/프로젝트명이 다른지 Windows 재확인 필요. FIX1: R172 탐색 재사용 + 고유 1개/비링크/증빙 PASS 조건을 파이썬에서도 이중 검증. 프로젝트명 변경·공백·결측·위조 영수증·링크 테스트 10/10 PASS, 기존 R177 10/10 PASS | **FIX1 오프라인 PASS / Windows 후보 빌드 미검증** |

## R175 — 확정된 차단의 코드 체인

- **운영 관찰:** `R174_WORKER_EXIT=7`, `R174_BLOCK_CAUSE=WorkerBlocked_REGISTRY_ROOT_APPID_NOT_MATCHED`.
- **운영 관찰:** `R175_INSTALL_PATH_MATCH=True`, `R175_INNO_APP_PATH_PRESENT=True`, `R175_DISPLAY_NAME_PRESENT=True`, 제거 파일명 `unins001.exe`, `R175_WORKER_INNO_CHECK=False` (Registry64/32 모두).
- **소스 확인:** `hkk_r81_real_inno.py` `registry_entries()` 내 `'unins000.exe' in uninstall` 조건. `hkk_r79_worker.py` `check_registry()`는 `legacy.registry_match()` 결과를 요구. `hkk_r77_identity.py`는 `entry.is_inno is True`를 요구.
- **수정 검증 필수:** `unins000.exe`와 `unins001.exe` 및 정상 Inno `uninsNNN.exe` 허용 여부를 테스트하되, 단순 부분 문자열 허용 금지. 레지스트리 `UninstallString`의 **실제 exe 경로**를 엄격히 파싱하고 예상 설치 루트 안의 존재하는 제거기 파일인지 검증한다. `unins000.exe.bak`, `evil_unins001.exe`, 외부 경로, 쉘 명령 삽입, 모호한 HKLM/HKCU, 서로 다른 Registry32/64 기록, 링크/정션, 제거기 없음 등을 **거부**한다. AppId, 설치 루트, 신뢰 해시, R26 서명, R71/R78 경로는 유지.
- **중요:** 이 문서는 아직 패치 완료를 뜻하지 않는다. Worker는 frozen 바이너리이므로 소스 수정 후 신뢰 가능 빌드·서명·배포 경로도 필요하며, 구형 Worker의 자기갱신 차단을 우회할 부트스트랩 방안을 별도 검증해야 한다.

## 다음 작업 승인 기준 (PASS 없으면 사용자 PC 배포 금지)

- [ ] 현재 Worker의 R175 정확한 차단을 코드 단위로 재현하고 오류 원인 분리 PASS
- [ ] Win32 Registry64/32·Inno `unins000`/`001` 및 변조/외부 경로 거부 회귀 PASS
- [ ] 이전 R159/R161/R164/R166/R167/R171 실패 전체 회귀 PASS
- [ ] 설치 소유권·R71/R78/R26 서명·기존 설치 GUI/worker SHA PASS
- [ ] 개발자 PC에서 GUI 버튼 → stage 다운로드 → **Worker preflight PASS** → 실제 설치 → GUI 재시작 → v0.14.23 증명 PASS
- [ ] 임장노트 지역 ID 14·음성 2건·보고서 표시 및 사용자 데이터 변경 없음 실증 PASS
- [ ] 강제 종료/실패 시 롤백 및 재시작 복구 E2E 실증 PASS
- [ ] v0.14.19 사용자 PC 최초 전환의 검증된 별도 안전 경로 확보

## 적용 방식

이 장부는 릴리스 준비·수정 전 가장 먼저 확인할 체크리스트다. 미래 채팅 모델의 자동 읽기를 보장하지 않으므로 관련 Issue의 상단에도 링크를 남기고, 새 패치 요청 시 명시적으로 이 파일을 기준으로 작업한다. 문제가 재발하면 새 FAIL 사례와 재현 입력을 추가하고 기존 항목을 삭제하지 않는다.


## R176 소스 수정 후보 (2026-11-12, Windows 적용 전)
- **상태:** ISOLATED_SOURCE_CANDIDATE / **운영 적용 NO**, 실제 자동설치 E2E **NOT_TESTED**. Issue #3 미종결.
- **원인 재현:** R175 HKCU(64/32) `unins001.exe`, 기존 `hkk_r81_real_inno.py` `'unins000.exe' in uninstall` 고정 검사로 R174 Worker exit 7.
- **추가 예방:** `hkk_r100_windows_guard.py`의 경쟁 제거기 감지도 `unins000/001` 고정 → 정규식 `unins[0-9]{3,}\\.exe`로 확장. 업데이트 후 `unins002.exe` 등을 놓치지 않음.
- **변경 파일 2개 (원본→후보 SHA256):**
  - `hkk_r81_real_inno.py`: `a85b7eeb6616890ad86f8dca0ddbd654b598a0bce17a7b4d443d91f799a7e863` → `07990bef18ead68f9ca0fa0ae0c247623042bc6eb8651bffead5c3993d074c5c`
  - `hkk_r100_windows_guard.py`: `e1c7d6d10eb2bfd6bbf896c76eecc3a5edab46531bf8ab06b4f893c34056469c` → `453977bd3d6bc2239460d5327d429aa726e82cfb10548597cdb0574ba52a8a4e`.
- **변경 방식:** 정확한 Inno 제거 EXE 경로·설치 루트·존재/MZ·비정션·두 Registry 뷰 일치·HKCU 등록 검사. 권한/서명 검증 해제 없음; 기존 12개 신뢰 모듈 바이트 동일.
- **검증:** synthetic fake Windows registry, 실제 R175 입력, 정상 `unins000/001/002`, 경로 끝 역슬래시, 위조 파일·외부 경로·명령 주입·HKLM·WOW64 불일치 거부, R79 체크 연결, R100 경쟁 프로세스 → **22/22 PASS**; 14/14 Python 문법 PASS; ZIP 내부 해시 검사 PASS.
- **ZIP 이름/해시:** `HKK_R176_REGISTRY_INNO_WORKER_SOURCE_FIX_READONLY.zip`, SHA256 `0e072ce86b9f5fe4060566ea6df77c65cc98fa98291c418c9270680e60bfa024`. 이 파일은 채팅 작업 공간 산출물로, GitHub Release에 게시한 것이 아님.
- **다음 필수:** 개발자 PC에서 ZIP 내 R176 읽기 전용 스크립트로 **실제 Registry64/32와 R171 signed baseline 및 R173 staged 0.14.23** 기반 소스 preflight 검증. PASS 후 별도 frozen Worker 후보 빌드/안전 이전 경로 설계. 운영 Worker는 이 단계에서 여전히 `68ff565f...`이며 교체하지 않음.
- **주의:** PowerShell 5.1 실제 구동은 미검증. Windows 코드가 새로운 BLOCKED를 보고하면 사유를 GitHub에 기록하고 새 FIX 번호부터 만들지 않는다.

## R177 최초 실패 → FIX1 경로 발견 회귀 (2026-11-12 KST)
- **Windows 사용자 관찰:** `R177_SOURCE_PIN=PASS_14`, `R177_ORIGINAL_INSTALLED=PASS_01422`, `R177_STAGE_ASSETS=PASS_01423` 이후 `R177_RESULT=BLOCKED`, `R177_REASON=DIR_MISSING_OR_REPARSE__release_candidates`, `R177_STAGE_BLOCKED_EXIT_1`. Worker 빌드, 사전검사, 설치 모두 미실행.
- **코드에서 확인한 원인:** 기존 R177 `BUILD_R177_PATCHED_WORKER.py`가 `Path.home()/'Documents'/'한꾸꾸_부동 산_분석_시스템_V0.3'`로 프로젝트명을 고정. 반면 실전 PASS했던 R172의 `HKK_R172_RUN.ps1`는 `[Environment]::GetFolderPath('MyDocuments')`에서 `R165.../R171_RESULT.txt` 근거로 프로젝트를 정확히 하나 발견. **실제 Windows 경로가 무엇인지 로그만으로 확정 불가**, 그러나 고정 경로 가정과 R172 계약 불일치는 소스에서 확정.
- **원천 개선:** R177 FIX1은 R172의 Windows 문서 경로 탐색 + `R171_RESULT.txt`/`R172_RESULT.txt` 근거를 재사용. 0개/2개 이상이면 BLOCKED, 링크/정션과 서명 성공 증빙 누락 거부. Python은 외부 `--project`를 필수로 받고 다시 증빙 검사, `Path.home()/Documents/고정이름` 제거. 설치 경로·R26/R71/R78·old/new SHA 검증은 그대로 유지.
- **시험:** 기존 10/10 + FIX1 신규 10/10 PASS (로컬 격리, Windows 실증 아님). ZIP 내 원본 R176 SHA `0e072ce86b9f5fe4060566ea6df77c65cc98fa98291c418c9270680e60bfa024` 변경 없음.
- **패키지:** `HKK_R177_FIX1_PROJECT_DISCOVERY_ONECLICK.zip`, SHA256 `08c849e3a1aab67996dec5bdb73f9073ba875edeaff49b315220b1e72ff16e9e`, 64,371 bytes. 소스/실행기 무결성 핀 포함.
- **현재:** Windows 실행/실제 후보 Worker 빌드/GUI 버튼 E2E/원복 여전히 NOT_TESTED. 기존 운영 프로그램/데이터/서명/레지스트리 NO_CHANGE. 개발자 Windows 실행 영수증 확인 전 ISSUE #3 CLOSE 금지.
- **재발 방지 불변 규칙:** Windows 사용자의 프로젝트/문서 경로 하드코딩 금지. 이미 검증된 프로젝트 디스커버리 경로 재사용, 서명/설치 증빙으로 고유 소스 선택, 실제 Windows 진입 전에 renamed/redirected 문서 경로의 격리 시험. 매번 ZIP+SHA+원클릭 PowerShell 명령을 함께 제공.

## R177 FIX1 Windows PASS 및 R178 새 Worker 포함 후보 준비 (2026-11-12 KST)
- **R177 개발자 Windows 실증 확정:** `R177_SOURCE_PIN=PASS_14`, `R177_ORIGINAL_INSTALLED=PASS_01422`, `R177_STAGE_ASSETS=PASS_01423`, `R177_PROJECT_DISCOVERY=PASS_R171_R172`, `R177_CANDIDATE_IDENTITY=PASS`, `R177_CANDIDATE_SIGNED_PREFLIGHT=PASS_01422_TO_01423`, `R177_INSTALLED_UNCHANGED=PASS`. Windows 빌드된 Worker SHA256 `93bb1c1bf92ed655ca146b550a24128fb0adc105e5462cba2f1d7e4f2b9d1171`. 서명/설치/GUI 버튼 E2E는 미실행.
- **추가로 발견한 구조상 차단:** R176 `hkk_r81_gui_handoff.handoff_gui()`는 설치된 기존 Worker를 복제하고 `plan.current_worker_sha256`과 비교. `hkk_r81_worker_main.signed_handoff()` 또한 티켓 Worker SHA와 `verified.current_worker_sha256` 일치를 요구. R177 새 Worker를 기존 0.14.22 GUI의 실행 티켓에 강제로 대체하는 방식은 불허된다. 이 보호는 의도된 신뢰 검사이며 해제하지 않는다.
- **기존 공개 0.14.23 재사용 한계:** 공개 Inno/R78은 기존 Worker SHA를 그대로 대상으로 서명했으므로 단순 0.14.23 설치가 이후 uninsNNN 수정 Worker를 영구 배포하는 길은 아님. 공개 태그/자산은 불변 유지.
- **R178 신규 제안/코드:** 검증된 R172 0.14.22 기반 PyInstaller/Inno/R26 서명 준비 소스 최소 재사용, **새 0.14.24 서명 전 설치 후보**를 빌드. 현재 0.14.22 Worker SHA `68ff565f8d0efe46713e119ed1cd33556420e58fc720802466627440a51e0784`은 R96 원복 대상에 남김. 새 Worker SHA `93bb1c1bf92ed655ca146b550a24128fb0adc105e5462cba2f1d7e4f2b9d1171`는 새 Inno 및 R78 목표로 사용. 설치된 0.14.22 GUI/Worker, 데이터·서명·레지스트리 무변경.
- **R178 격리 검증:** 22/22 PASS. 소스/해시/버전/AppId/영수증 검사, R172 소스·Inno 재사용, 신규 Worker/구 원복 Worker 분리, 위조 증거 거부, 링크 거부, 서명 없는 임의 데이터 변조 거부 테스트. 개발자 Windows GUI/Inno 빌드는 아직 미실행.
- **R178 패키지:** `HKK_R178_01424_PATCHED_WORKER_BUILD_ONLY.zip` SHA256 `dcb4e4a3293a0b435395eeb711a82aecace2b30e4e2170163326d41844f8a3b2`; R172 원본 ZIP 보존, R178 실행기·테스트·구조 감사 문서 포함. Windows에서 실행하더라도 설치/서명/릴리스 공개는 하지 않음.
- **해결되지 않은 필수 조건:** 개발자 PC용 독립 **R26 서명 1회 전환 브리지**를 구현·검증해야 기존 GUI/Worker 신뢰 체인을 훼손하지 않고 다음 버전으로 실제 설치 가능. 작업자를 위한 별도 승인과 Windows 재시작/중단 원복 E2E가 필요. 사용자 PC v0.14.19 HTTP 415는 별도 최초 전환. `--preflight PASS`는 실제 설치 성공이 아님.
