# AtomicAutoRunner

⚠️ 주의 사항 <br>
일부 테스트는 Windows Server 환경 또는 특정 권한이 필요합니다. <br>
테스트 환경(가상 머신) 구성 시 반드시 Windows Server 이미지로 생성하세요. <br>
전체 AtomicTest 실행 전 5~10개로 트레이스가 제대로 잡히는지 테스트하는 것을 추천합니다.

## 특징

- Atomic Red Team 테스트 자동화 실행
- 관리자 권한 PowerShell에서 개별 테스트 실행
- Exit code 기준 성공/실패/스킵 기록
- 마커 파일로 진행 상태 확인
- 로그 파일로 실행 결과 확인
- 테스트 목록 파일 기반 순차 실행
- 임시 스크립트 자동 생성 및 삭제

## 설치 및 준비

1. **Atomic Red Team 모듈 다운로드**
   - [Invoke-AtomicRedTeam GitHub](https://github.com/redcanaryco/atomic-red-team)에서 다운로드
   - 예시 경로: `C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1`

2. **테스트 목록 파일 준비**
   - 실행할 테스트 ID를 한 줄씩 작성 (예: `T1001.002`)
   - 주석이나 빈 줄은 무시됨
   - 업로드한 'ForderList.txt에'서 실행할 테스트 목록 추출해서 사용

## 실행 방법
1. 초기 실행 PowerShell은 반드시 관리자 권한으로 실행
2. Agent_VM.bat 실행(localhost:16686에서 트레이스 확인)
3. 파워쉘에 Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force 입력
4. execute.ps1 파일을 관리자 권한 PowerShell에서 실행: <br>
<tab> 명령어: & "C:\Users\USERNAME\Desktop\EventAgent\execute.ps1" -> 실제 execute.ps1 저장 경로로 수정
5. 실행화면

<img width="1919" height="1048" alt="스크린샷 2025-09-20 124442" src="https://github.com/user-attachments/assets/7ed92a42-cdda-45a9-9d13-6a69739871f4" />
6. 모든 테스트가 완료되면 마커, 로그 폴더를 확인하여 결과 확인 가능

## 레지스트리 편집 설정
<img width="1656" height="906" alt="스크린샷 2025-09-22 094344" src="https://github.com/user-attachments/assets/65c6732d-5f27-474e-acc3-ae05695fba7b" />
위와 같이 레지스트리 편집이 막혀있을 경우 파워쉘에 <br>
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Force | Out-Null <br>
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableRegistryTools" -Value 0 -Type DWord -Force <br>
입력하여 레지스트리 편집 허용 설정이 필요
