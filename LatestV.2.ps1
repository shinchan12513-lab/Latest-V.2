$Host.UI.RawUI.WindowTitle = "Develop By NITROPRIME STORE"
cmd.exe /c "mode con: cols=60 lines=12 & color 07"

Clear-Host
Write-Host ""
Write-Host "     [ NITROPRIME STORE ]" -ForegroundColor DarkGray
Write-Host "     Internet Latest v.2"
Write-Host ""

# ==============================================================================
# SECURITY CHECKS (ANTI-DEBUG & VM & TOOLS)
# ==============================================================================

if ([System.Diagnostics.Debugger]::IsAttached) {
    Write-Host "`n     [X] Security Violation: Debugger detected!" -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit
}

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
$secretKey = "ADSAADWADADADAWDA!#!@#%^"

$customHeaders = @{
    "X-Client-Secret" = $secretKey
    "Content-Type"    = "application/json"
}

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

$workerUrl = "https://latestv2.shinchan12513.workers.dev/"
$userHwid = Get-HWID

$body = @{ 
    key  = $inputKey
    hwid = $userHwid 
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $workerUrl -Method Post -Body $body -Headers $customHeaders
    
    if ($response.success) {
        Write-Host "`n     [+] Successfully" -ForegroundColor Green
        Start-Sleep -Seconds 2
    } else {
        Write-Host "`n     [X] $($response.message)" -ForegroundColor Red
        Start-Sleep -Seconds 3
        exit
    }
} catch {
    Write-Host "`n     [X] Connection Error / Server Rejected!" -ForegroundColor Red
    if ($_.Exception.Response) {
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $errBody = $reader.ReadToEnd()
            Write-Host "     [X] Details: $errBody" -ForegroundColor Yellow
        } catch {
            Write-Host "     [X] Message: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "     [X] Message: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 5
    exit
}

# ==============================================================================
# MAIN MENU
# ==============================================================================
while ($true) {
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
            Write-Host "`n     [X] Request Error Details:" -ForegroundColor Red
            if ($_.Exception.Response) {
                try {
                    $stream = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    Write-Host "     [X] Details: $($reader.ReadToEnd())" -ForegroundColor Yellow
                } catch {
                    Write-Host "     [X] Message: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "     [X] Message: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        Read-Host '     Press Enter to return'
    }
}
