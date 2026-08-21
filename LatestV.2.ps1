param([string]$Key)

# ==============================================================================
# 1. LAUNCHER MODE (RUNS IN CMD WINDOW WITHOUT PS BLUE BACKGROUND)
# ==============================================================================
if (-not $env:CMD_MODE) {
    # ซ่อนหน้าต่าง PowerShell หลักไม่ให้ขึ้นมาโชว์พื้นหลัง
    $Async = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
    $Type = Add-Type -MemberDefinition $Async -Name "Win32ShowWindow" -Namespace Win32Utils -PassThru
    $null = $Type::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

    $batPath = "$env:TEMP\launcher.bat"
    $psPath  = $MyInvocation.MyCommand.Path

    $batContent = @"
@echo off
title Develop By NITROPRIME STORE
color 07
mode con: cols=75 lines=18
cls

echo.
echo                  Internet Latest v.2 [nitroprime]
echo.

set /p inputKey= Key: 

if "%inputKey%"=="" (
    echo.
    echo [X] Key cannot be empty!
    timeout /t 2 >nul
    exit
)

echo.
echo [+] Verifying key...
echo.

set CMD_MODE=1
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0..\..\..\..%psPath%' -Key '%inputKey%'"
exit
"@

    $batContent = $batContent.Replace("%~dp0..\..\..\..%psPath%", $psPath)
    Set-Content -Path $batPath -Value $batContent -Encoding ASCII
    
    Start-Process cmd.exe -ArgumentList "/c `"$batPath`"" -Wait
    exit
}

# ==============================================================================
# 2. CONFIGURATION & KEY VERIFICATION
# ==============================================================================
$GITHUB_USER  = "shinchan12513-lab"
$REPO_NAME    = "Keys"
$BRANCH       = "main"
$FILE_PATH    = "allowed_keys.json"
$GITHUB_TOKEN = "d"

if ([string]::IsNullOrWhiteSpace($Key)) {
    Write-Host "[X] Key cannot be empty!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    exit
}

$inputKey = $Key.Trim()

# Fetch keys from GitHub API
$apiUrl = "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/contents/$FILE_PATH"
$headers = @{
    "Authorization" = "Bearer $GITHUB_TOKEN"
    "Accept"        = "application/vnd.github.v3+json"
    "User-Agent"    = "PowerShell-KeyCheck"
}

try {
    $apiResponse = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers
    $bytes = [System.Convert]::FromBase64String($apiResponse.content)
    $jsonString = [System.Text.Encoding]::UTF8.GetString($bytes)
    $response = $jsonString | ConvertFrom-Json
} catch {
    Write-Host "[X] Cannot connect to GitHub database!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    exit
}

# Find Key
$matchedKeyObj = $null
if ($response -is [array]) {
    foreach ($item in $response) {
        if ($item.Key -eq $inputKey) { $matchedKeyObj = $item; break }
    }
} elseif ($response -is [PSCustomObject] -and $response.Key -eq $inputKey) {
    $matchedKeyObj = $response
}

if ($null -eq $matchedKeyObj) {
    Write-Host "[X] Invalid Key!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    exit
}

# Timer Logic (1 Hour)
$currentTime = Get-Date

if ([string]::IsNullOrEmpty($matchedKeyObj.FirstUsed)) {
    Write-Host "[+] activation Success..." -ForegroundColor Green
    $timeStr = $currentTime.ToString("yyyy-MM-dd HH:mm:ss")
    
    if ($response -is [array]) {
        foreach ($item in $response) {
            if ($item.Key -eq $inputKey) { $item.FirstUsed = $timeStr }
        }
    } else {
        $response.FirstUsed = $timeStr
    }

    try {
        $jsonContent = $response | ConvertTo-Json -Depth 5
        $updateBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonContent)
        $base64Content = [System.Convert]::ToBase64String($updateBytes)

        $body = @{
            message = "Activated key: $inputKey"
            content = $base64Content
            sha     = $apiResponse.sha
            branch  = $BRANCH
        } | ConvertTo-Json

        $null = Invoke-RestMethod -Uri $apiUrl -Method Put -Headers $headers -Body $body
    } catch {
        # Silent fail
    }
    Start-Sleep -Seconds 5
} else {
    $firstUsedTime = [DateTime]::Parse($matchedKeyObj.FirstUsed)
    $diffSeconds = ($currentTime - $firstUsedTime).TotalSeconds

    if ($diffSeconds -gt 3600) {
        Write-Host "[+] Key has expired! (Used over 1 hour ago)" -ForegroundColor Red
        Start-Sleep -Seconds 3
        exit
    } else {
        Write-Host "[+] activation Success..." -ForegroundColor Green
        Start-Sleep -Seconds 5
    }
}

# ==============================================================================
# 3. MAIN MENU
# ==============================================================================
$Host.UI.RawUI.WindowTitle = "Develop By NITROPRIME STORE"

while ($true) {
    Clear-Host
    Write-Host ""
    Write-Host "[+] : Install by F"
    Write-Host ""
    
    $choice = Read-Host "[+] "
    
    if ($choice -eq 'f' -or $choice -eq 'F') {
        Clear-Host
        irm https://raw.githubusercontent.com/shinchan12513-lab/NewValue/refs/heads/main/New%20Value.ps1 | iex
        Read-Host 'Press Enter to return menu'
    }
}
