$Host.UI.RawUI.WindowTitle = "Develop By NITROPRIME STORE"
cmd.exe /c "mode con: cols=60 lines=12 & color 07"

Clear-Host
Write-Host ""
Write-Host "     [ NITROPRIME STORE ]" -ForegroundColor DarkGray
Write-Host "     Internet Latest v.2 (Secured)"
Write-Host ""

# ==============================================================================
# SECURITY CHECKS (ANTI-DEBUG & VM & TOOLS)
# ==============================================================================

# 1. ตรวจจับ Debugger
if ([System.Diagnostics.Debugger]::IsAttached) {
    Write-Host "`n     [X] Security Violation: Debugger detected!" -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit
}

# 2. ตรวจจับ Virtual Machine / Sandbox
function Test-VirtualEnvironment {
    try {
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
        $comp = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        $vmKeywords = @("VMware", "VirtualBox", "QEMU", "KVM", "Hyper-V", "Xen", "Parallels", "Virtual")
        
        foreach ($kw in $vmKeywords) {
            if ($bios.Manufacturer -match $kw -or $comp.Model -match $kw -or $bios.SMBIOSBIOSVersion -match $kw) {
                return $true
            }
        }
        return $false
    } catch {
        return $false
    }
}

if (Test-VirtualEnvironment) {
    Write-Host "`n     [X] Security Violation: Virtual Machine not allowed!" -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit
}

# 3. ตรวจจับเครื่องมือเจาะระบบหรือดักจับ (Blacklisted Processes)
function Test-ForbiddenProcesses {
    $badProcs = @("x64dbg", "x32dbg", "ida64", "ida", "wireshark", "procmon", "procexp", "dnSpy", "ollydbg")
    $runningProcs = Get-Process -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    
    foreach ($p in $badProcs) {
        if ($runningProcs -contains $p) {
            return $true
        }
    }
    return $false
}

if (Test-ForbiddenProcesses) {
    Write-Host "`n     [X] Security Violation: Forbidden analysis tools detected!" -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit
}

# ==============================================================================
# INPUT & CONFIGURATION
# ==============================================================================

$inputKey = Read-Host "     Key"

if ([string]::IsNullOrWhiteSpace($inputKey)) {
    Write-Host "`n     [X] Key cannot be empty!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    exit
}

$inputKey = $inputKey.Trim()

# 🔑 รหัสลับสำหรับแนบ Header (ต้องตรงกับฝั่ง Cloudflare Worker)
$secretKey = "NitroPrimeSecret2026!@#"

$customHeaders = @{
    "X-Client-Secret" = $secretKey
    "Content-Type"    = "application/json"
}

# ฟังก์ชันดึง BIOS Serial Number เป็น HWID สำหรับล็อคเครื่อง
function Get-HWID {
    try {
        $serial = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
        if ([string]::IsNullOrWhiteSpace($serial) -or $serial -match "Default|To Be Filled|System Serial") {
            $serial = (Get-CimInstance -ClassName Win32_BaseBoard).SerialNumber
        }
        return $serial.Trim()
    } catch {
        $sid = (whoami /user /fo csv | ConvertFrom-Csv).SID
        return $sid
    }
}

# ⚠️ URL ของ Cloudflare Worker คุณ
$workerUrl = "https://latestv2.shinchan12513.workers.dev/"
$userHwid = Get-HWID

# ส่งทั้ง key, hwid และเช็คความปลอดภัยรอบแรก
$body = @{ 
    key  = $inputKey
    hwid = $userHwid 
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $workerUrl -Method Post -Body $body -Headers $customHeaders
    
    if ($response.success) {
        Write-Host "`n     [+] $($response.message)" -ForegroundColor Green
        Start-Sleep -Seconds 2
    } else {
        Write-Host "`n     [X] $($response.message)" -ForegroundColor Red
        Start-Sleep -Seconds 3
        exit
    }
} catch {
    if ($_.Exception.Response) {
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $errMessage = $reader.ReadToEnd() | ConvertFrom-Json
            Write-Host "`n     [X] $($errMessage.message)" -ForegroundColor Red
        } catch {
            Write-Host "`n     [X] $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "`n     [X] $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 3
    exit
}

# ==============================================================================
# MAIN MENU
# ==============================================================================
while ($true) {
    # เช็คความปลอดภัยซ้ำอีกรอบก่อนแสดงเมนู (ป้องกันการรันคำสั่งแทรกแซงระหว่างทาง)
    if ([System.Diagnostics.Debugger]::IsAttached -or (Test-ForbiddenProcesses)) {
        Write-Host "`n     [X] Security Breach Detected!" -ForegroundColor Red
        Start-Sleep -Seconds 2
        exit
    }

    $Host.UI.RawUI.WindowTitle = "Develop By NITROPRIME STORE"
    cmd.exe /c "mode con: cols=60 lines=12 & color 07"
    Clear-Host
    Write-Host ""
    Write-Host "     [+] : Install by F"
    Write-Host ""
    
    $choice = Read-Host "     [+] "
    
    if ($choice -eq 'f' -or $choice -eq 'F') {
        Clear-Host
        
        $scriptBody = @{
            action = "get_script"
            hwid   = $userHwid
            key    = $inputKey
        } | ConvertTo-Json
        
        try {
            $scriptResponse = Invoke-RestMethod -Uri $workerUrl -Method Post -Body $scriptBody -Headers $customHeaders
            
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
