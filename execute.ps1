$TestListFile = "C:\Users\sj122\Desktop\EventAgent\testlist.txt" # 테스트 ID 목록 파일
$ModulePath    = "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" # AtomicRedTeam 모듈 경로
$TempDir       = "C:\AtomicRedTeam\temp" # 각 테스트 실행 시 임시 스크립트 파일 생성 경로
$MarkerDir     = "C:\AtomicRedTeam\markers" # 각 테스트 결과 저장할 마커 파일 저장 경로
$TimeoutPerTestSeconds = 600 # 각 테스트별 제한시간
$RemoveTempScriptAfterRun = $true # 각 테스트 실행 후 스크립트 삭제여부

# 임시 폴더/마커 폴더 생성
New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
New-Item -Path $MarkerDir -ItemType Directory -Force | Out-Null

# 테스트 목록 읽기
if (-not (Test-Path $TestListFile)) { throw "테스트 목록 파일을 찾을 수 없습니다: $TestListFile" }
if (-not (Test-Path $ModulePath)) { throw "모듈 파일을 찾을 수 없습니다: $ModulePath" }

$tests = Get-Content $TestListFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }
if ($tests.Count -eq 0) { throw "실행할 ID가 없습니다. 파일을 확인하세요." }

# 임시 스크립트 생성 함수

function Create-TempScript {
    param($testId, $markerPath, $modulePath, $tempDir)
    $scriptPath = Join-Path $tempDir ("atomic_run_{0}.ps1" -f $testId)

    $content = @"
`$ErrorActionPreference = 'Stop'
try {
    Import-Module "$modulePath" -Force

    # 사전요건 체크
    try {
        Invoke-AtomicTest "$testId" -GetPrereqs -ErrorAction Stop | Out-Null
        `$pr = 'OK'
    } catch {
        `$pr = 'PREREQ_FAIL'
    }

    if (`$pr -eq 'OK') {
        # 테스트 실행
        Invoke-AtomicTest "$testId" -ErrorAction Stop | Out-Null
        exit 0
    } else {
        # Prereq 실패시 SKIPPED
        exit 2
    }
} catch {
    # 에러 발생시 Exit code 1
    exit 1
}
"@

    $content | Out-File -FilePath $scriptPath # ===============================
# Atomic Red Team 자동화 실행 스크립트
# ===============================

$TestListFile = "C:\Users\sj122\Desktop\EventAgent\testlist.txt"   # 테스트 ID 목록 파일
$ModulePath    = "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" # AtomicRedTeam 모듈
$TempDir       = "C:\AtomicRedTeam\temp"    # 임시 스크립트 경로
$MarkerDir     = "C:\AtomicRedTeam\markers" # 결과 마커 경로
$TimeoutPerTestSeconds = 600               # 테스트 제한 시간 (초)
$RemoveTempScriptAfterRun = $true          # 임시 스크립트 삭제 여부

# 임시/마커 폴더 생성
New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
New-Item -Path $MarkerDir -ItemType Directory -Force | Out-Null

# 테스트 목록 읽기
if (-not (Test-Path $TestListFile)) { throw "테스트 목록 파일을 찾을 수 없습니다: $TestListFile" }
if (-not (Test-Path $ModulePath)) { throw "모듈 파일을 찾을 수 없습니다: $ModulePath" }

$tests = Get-Content $TestListFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }
if ($tests.Count -eq 0) { throw "실행할 테스트 ID가 없습니다. 파일을 확인하세요." }

# ===============================
# 임시 스크립트 생성 함수
# ===============================
function Create-TempScript {
    param(
        [string]$testId,
        [string]$markerPath,
        [string]$modulePath,
        [string]$tempDir
    )

    $scriptPath = Join-Path $tempDir ("atomic_run_{0}.ps1" -f $testId)

    $content = @"
`$ErrorActionPreference = 'Stop'
try {
    Import-Module "$modulePath" -Force

    # 사전요건 체크
    try {
        Invoke-AtomicTest "$testId" -GetPrereqs -ErrorAction Stop | Out-Null
        `$pr = 'OK'
    } catch {
        `$pr = 'PREREQ_FAIL'
        Add-Content -Path "$markerPath" -Value "DONE $testId SKIPPED (Prereq Fail) $(Get-Date -Format s)"
        exit 2
    }

    # 테스트 실행
    try {
        Invoke-AtomicTest "$testId" -ErrorAction Stop | Out-Null
        Add-Content -Path "$markerPath" -Value "DONE $testId SUCCESS $(Get-Date -Format s)"
        exit 0
    } catch {
        Add-Content -Path "$markerPath" -Value "DONE $testId FAILED $(Get-Date -Format s) Message:$($_.Exception.Message)"
        exit 1
    }

} catch {
    Add-Content -Path "$markerPath" -Value "DONE $testId ERROR $(Get-Date -Format s) Message:$($_.Exception.Message)"
    exit 1
}
"@

    $content | Out-File -FilePath $scriptPath -Encoding UTF8 -Force
    return $scriptPath
}

# ===============================
# 메인 루프: 테스트 순차 실행
# ===============================
$idx = 0
foreach ($testId in $tests) {
    $idx++
    $markerFile = Join-Path $MarkerDir ("atomic_done_{0}.txt" -f $testId)

    # 기존 마커 삭제
    if (Test-Path $markerFile) { Remove-Item $markerFile -Force -ErrorAction SilentlyContinue }

    # 임시 스크립트 생성
    $tempScript = Create-TempScript -testId $testId -markerPath $markerFile -modulePath $ModulePath -tempDir $TempDir

    Write-Host "[$idx/$($tests.Count)] 테스트 $testId 실행 -> 임시 스크립트: $tempScript"

    # 관리자 권한 PowerShell로 실행
    $arglist = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$tempScript")
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $arglist -Verb RunAs -PassThru

    # 제한 시간 동안 대기
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not $proc.HasExited) {
        Start-Sleep -Seconds 1
        if ($sw.Elapsed.TotalSeconds -gt $TimeoutPerTestSeconds) {
            Write-Warning "타임아웃: 테스트 $testId ($TimeoutPerTestSeconds s)"
            try { $proc.Kill() } catch {}
            break
        }
    }
    $sw.Stop()

    # 마커 파일 내용 읽어서 상태 출력
    if (Test-Path $markerFile) {
        $marker = Get-Content $markerFile -Raw
        Write-Host "완료: $testId -> $marker"
    } else {
        Write-Warning "완료 마커 없음(타임아웃/오류): $testId"
    }

    # 임시 스크립트 삭제
    if ($RemoveTempScriptAfterRun) {
        Remove-Item -Path $tempScript -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 1
}

Write-Host "모든 테스트 완료. 마커는 $MarkerDir 에 있습니다."
-Encoding UTF8 -Force
    return $scriptPath
}

# 메인 루프: 각 테스트 실행
$idx = 0
foreach ($testId in $tests) {
    $idx++
    $markerFile = Join-Path $MarkerDir ("atomic_done_{0}.txt" -f $testId)
    if (Test-Path $markerFile) { Remove-Item $markerFile -Force -ErrorAction SilentlyContinue }

    $tempScript = Create-TempScript -testId $testId -markerPath $markerFile -modulePath $ModulePath -tempDir $TempDir

    Write-Host "[$idx/$($tests.Count)] 테스트 $testId 실행 -> 임시스크립트: $tempScript"

    # 관리자 권한 PowerShell로 실행
    $arglist = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$tempScript")
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $arglist -Verb RunAs -PassThru

    # 타임아웃 대기
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not $proc.HasExited) {
        Start-Sleep -Seconds 1
        if ($sw.Elapsed.TotalSeconds -gt $TimeoutPerTestSeconds) {
            Write-Warning "타임아웃: 테스트 $testId ($TimeoutPerTestSeconds s)"
            try { $proc.Kill() } catch {}
            break
        }
    }
    $sw.Stop()

    # Exit code 기준 결과 처리
    if ($proc.ExitCode -eq 0) {
        $res = "SUCCESS"
    } elseif ($proc.ExitCode -eq 2) {
        $res = "SKIPPED"
    } else {
        $res = "FAILED"
    }

    # 마커 기록
    Add-Content -Path $markerFile -Value "DONE $testId $res $(Get-Date -Format s)"

    if ($RemoveTempScriptAfterRun) {
        Remove-Item -Path $tempScript -ErrorAction SilentlyContinue
    }

    Write-Host "완료: $testId -> $res"
    Start-Sleep -Seconds 1
}

Write-Host "모든 테스트 완료. 마커는 $MarkerDir 에 있습니다."
