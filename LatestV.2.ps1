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

# ⚠️ URL ของ Cloudflare Worker คุณ
$workerUrl = "https://latestv2.shinchan12513.workers.dev/"
$body = @{ key = $inputKey } | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $workerUrl -Method Post -Body $body -ContentType "application/json"
    
    if ($response.success) {
        Write-Host "`n     [+] $($response.message)" -ForegroundColor Green
        Start-Sleep -Seconds 2
    } else {
        Write-Host "`n     [X] $($response.message)" -ForegroundColor Red
        Start-Sleep -Seconds 3
        exit
    }
} catch {
    $stream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $errMessage = $reader.ReadToEnd() | ConvertFrom-Json
    
    Write-Host "`n     [X] $($errMessage.message)" -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit
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
        
        # ส่งคำขอไปที่ Cloudflare Worker แบบกำหนด JSON ตรงๆ เพื่อความเสถียร
        $scriptBody = '{"action": "get_script"}'
        
        try {
            $scriptResponse = Invoke-RestMethod -Uri $workerUrl -Method Post -Body $scriptBody -ContentType "application/json"
            
            if ($scriptResponse.success) {
                # รันโค้ดที่ดึงมาจาก Worker โดยตรง
                Invoke-Expression $scriptResponse.script
            } else {
                Write-Host "`n     [X] Failed to load script from server!" -ForegroundColor Red
            }
        } catch {
            Write-Host "`n     [X] Connection error while fetching script!" -ForegroundColor Red
        }
        
        Read-Host '     Press Enter to return'
    }
}
