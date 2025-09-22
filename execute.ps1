$TestListFile = "C:\Users\sj122\Desktop\EventAgent\testlist.txt"   # 실제 테스트 수행할 목폭 파일로 수정해서 사용
$ModulePath    = "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1"
$TempDir       = "C:\AtomicRedTeam\temp"    
$MarkerDir     = "C:\AtomicRedTeam\markers" 
$LogDir        = "C:\AtomicRedTeam\logs"
$TimeoutPerTestSeconds = 600               
$RemoveTempScriptAfterRun = $true          

# 임시/마커/로그 폴더 생성
foreach ($dir in @($TempDir, $MarkerDir, $LogDir)) {
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
}

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
        [string]$tempDir,
        [string]$logDir
    )

    $scriptPath = Join-Path $tempDir ("atomic_run_{0}.ps1" -f $testId)
    $logPath    = Join-Path $logDir ("atomic_{0}.log" -f $testId)

    $content = @"
`$ErrorActionPreference = 'Stop'
try {
    Import-Module "$modulePath" -Force

    # 사전요건 체크
    try {
        Invoke-AtomicTest "$testId" -GetPrereqs -ErrorAction Stop *>&1 | Out-File -FilePath "$logPath" -Encoding UTF8
    } catch {
        Add-Content -Path "$markerPath" -Value "DONE $testId SKIPPED (Prereq Fail) $(Get-Date -Format s)"
        `$_.Exception.Message | Out-File -FilePath "$logPath" -Encoding UTF8 -Append
        exit 2
    }

    
    # 테스트 실행
    try {
        `$output = Invoke-AtomicTest "$testId" -ErrorAction Stop *>&1
        `$output | Out-File -FilePath "$logPath" -Encoding UTF8 -Append

        `$outputString = `$output | Out-String
        `$isFailed = `$false
        `$failReason = "Check Log" # 실패 원인을 저장할 변수 

        # "Exit code: " 패턴을 먼저 검사
        if (`$outputString -match "Exit code: (-?\d+)") {
            `$exitCodeValue = `$matches[1]
            if (`$exitCodeValue -ne '0') {
                `$isFailed = `$true
                `$failReason = "ExitCode: $exitCodeValue" 
            }
        }
        # Exit code가 없었을 경우, 다른 실패 키워드를 검사
        elseif (`$outputString -match "FAIL|Error|Exception|Failed") {
            `$isFailed = `$true
            # $failReason은 기본값 "Check Log"를 그대로 사용
        }

        # 마커를 기록
        if (`$isFailed) {
            
            Add-Content -Path "$markerPath" -Value "DONE $testId FAILED ($failReason) $(Get-Date -Format s)"
            exit 1
        } else {
            Add-Content -Path "$markerPath" -Value "DONE $testId SUCCESS $(Get-Date -Format s)"
            exit 0
        }

    } catch {
        Add-Content -Path "$markerPath" -Value "DONE $testId FAILED (Execution Error) $(Get-Date -Format s) Message:`$(`$_.Exception.Message)"
        `$_.Exception.Message | Out-File -FilePath "$logPath" -Encoding UTF8 -Append
        exit 1
    }
   
} catch {
    Add-Content -Path "$markerPath" -Value "DONE $testId ERROR (Script Error) $(Get-Date -Format s) Message:`$(`$_.Exception.Message)"
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

    if (Test-Path $markerFile) { Remove-Item $markerFile -Force -ErrorAction SilentlyContinue }

    $tempScript = Create-TempScript -testId $testId -markerPath $markerFile -modulePath $ModulePath -tempDir $TempDir -logDir $LogDir

    Write-Host "[$idx/$($tests.Count)] 테스트 $testId 실행 -> 임시 스크립트: $tempScript"

    # 관리자 권한 PowerShell에서 실행
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$tempScript") -Verb RunAs -PassThru

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

    # Exit code 기준 마커 읽어서 상태 출력
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

Write-Host "모든 테스트 완료. 마커는 $MarkerDir, 로그는 $LogDir 에 있습니다."
