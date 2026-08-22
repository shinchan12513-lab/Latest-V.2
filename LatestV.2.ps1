# ==============================================================================
# CONFIGURATION & KEY VERIFICATION
# ==============================================================================
$GITHUB_USER  = "shinchan12513-lab"
$REPO_NAME    = "Keys"
$BRANCH       = "main"
$FILE_PATH    = "allowed_keys.json"
$GITHUB_TOKEN = "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"

# ปรับขนาดหน้าต่างให้เล็กกะทัดรัด และเปลี่ยน Title เป็น Develop By NITROPRIME STORE
$Host.UI.RawUI.WindowTitle = "Develop By NITROPRIME STORE"
cmd.exe /c "mode con: cols=60 lines=12 & color 07"

Clear-Host
Write-Host ""
Write-Host "     [ NITROPRIME STORE ]" -ForegroundColor DarkGray
Write-Host "     Internet Latest v.2"
Write-Host ""

$inputKey = Read-Host "     Key"

if ([string]::IsNullOrWhiteSpace($inputKey)) {
    Write-Host "`n     [X] Key cannot be empty!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    exit
}

$inputKey = $inputKey.Trim()

# บังคับใช้ TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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
    Write-Host "`n     [X] Connection failed!" -ForegroundColor Red
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
    Write-Host "`n     [X] Invalid Key!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    exit
}

# Timer Logic (1 Hour)
$currentTime = Get-Date

if ([string]::IsNullOrEmpty($matchedKeyObj.FirstUsed)) {
    Write-Host "`n     [+] Activation Success" -ForegroundColor Green
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
    Start-Sleep -Seconds 3
} else {
    $firstUsedTime = [DateTime]::Parse($matchedKeyObj.FirstUsed)
    $diffSeconds = ($currentTime - $firstUsedTime).TotalSeconds

    if ($diffSeconds -gt 3600) {
        Write-Host "`n     [X] Key has expired!" -ForegroundColor Red
        Start-Sleep -Seconds 3
        exit
    } else {
        Write-Host "`n     [+] Activation Success" -ForegroundColor Green
        Start-Sleep -Seconds 2
    }
}

# ==============================================================================
# MAIN MENU
# ==============================================================================
while ($true) {
    $Host.UI.RawUI.WindowTitle = "Develop By NITROPRIME STORE"
    cmd.exe /c "mode con: cols=60 lines=12 & color 07"
    Clear-Host
    Write-Host ""
    Write-Host "     [+] : Install by F"
    Write-Host ""
    
    $choice = Read-Host "     [+] "
    
    if ($choice -eq 'f' -or $choice -eq 'F') {
        Clear-Host
        $scriptHeaders = @{ "Authorization" = "Bearer $GITHUB_TOKEN" }
        $scriptContent = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/shinchan12513-lab/NewValue/refs/heads/main/NewValue.ps1" -Headers $scriptHeaders
        Invoke-Expression $scriptContent
        
        Read-Host '     Press Enter to return'
    }
}