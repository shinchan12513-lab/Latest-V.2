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

# ฟังก์ชันดึง BIOS Serial Number เป็น HWID สำหรับล็อคเครื่อง
function Get-HWID {
    try {
        $serial = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
        if ([string]::IsNullOrWhiteSpace($serial) -or $serial -match "Default|To Be Filled|System Serial") {
            $serial = (Get-CimInstance -ClassName Win32_BaseBoard).SerialNumber
        }
        return $serial.Trim()
    } catch {
        # ระบบสำรอง กรณีดึงฮาร์ดแวร์ไม่ได้ ให้ใช้ SID แทนเพื่อป้องกันสคริปต์พัง
        $sid = (whoami /user /fo csv | ConvertFrom-Csv).SID
        return $sid
    }
}

# ⚠️ URL ของ Cloudflare Worker คุณ
$workerUrl = "https://latestv2.shinchan12513.workers.dev/"
$userHwid = Get-HWID

# ส่งทั้ง key และ hwid ไปเช็คที่ Server
$body = @{ 
    key  = $inputKey
    hwid = $userHwid 
} | ConvertTo-Json

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
        
        # ส่ง action พร้อม hwid ไปด้วย เพื่อความปลอดภัยในตอนกดรับสคริปต์ (แนะนำให้ฝั่ง Worker เช็คซ้ำอีกรอบได้ครับ)
        $scriptBody = @{
            action = "get_script"
            hwid   = $userHwid
            key    = $inputKey
        } | ConvertTo-Json
        
        try {
            $scriptResponse = Invoke-RestMethod -Uri $workerUrl -Method Post -Body $scriptBody -ContentType "application/json"
            
            if ($scriptResponse.success) {
                Invoke-Expression $scriptResponse.script
            } else {
                Write-Host "`n     [X] Server Message: $($scriptResponse.message)" -ForegroundColor Red
            }
        } catch {
            Write-Host "`n     [X] Error Details:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            
            if ($_.Exception.Response) {
                try {
                    $stream = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
                } catch {}
            }
        }
        
        Read-Host '     Press Enter to return'
    }
}
