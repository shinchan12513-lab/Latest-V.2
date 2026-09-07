$Host.UI.RawUI.WindowTitle = "Develop By NITROPRIME STORE"
cmd.exe /c "mode con: cols=60 lines=15 & color 07"

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
$secretKey = "aaDADd313441DASdddddddd"

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
    cmd.exe /c "mode con: cols=60 lines=15 & color 07"
    Clear-Host
    Write-Host ""
    Write-Host "     [+] [F] Install Script"
    Write-Host "     [+] [R] Rekey / Reset HWID"
    Write-Host "     [+] [E] Exit"
    Write-Host ""
    
    $choice = Read-Host "     [+] Select option"
    
    if ($choice -eq 'f' -or $choice -eq 'F') {
        Clear-Host
        
        try {
            # ขั้นตอนที่ 1: ขอ Session Token ชั่วคราวก่อน
            $tokenBody = @{
                action = "get_token"
                key    = $inputKey
                hwid   = $userHwid
            } | ConvertTo-Json

            $tokenResponse = Invoke-RestMethod -Uri $workerUrl -Method Post -Body $tokenBody -Headers $customHeaders

            if (-not $tokenResponse.success) {
                Write-Host "`n     [X] Failed to get token: $($tokenResponse.message)" -ForegroundColor Red
                Read-Host '     Press Enter to return'
                continue
            }

            $sessionToken = $tokenResponse.token

            # ขั้นตอนที่ 2: ใช้ Token ที่ได้ขอสคริปต์ที่เข้ารหัสมา
            $scriptBody = @{
                action = "get_script"
                token  = $sessionToken
                hwid   = $userHwid
                key    = $inputKey
            } | ConvertTo-Json
            
            $scriptResponse = Invoke-RestMethod -Uri $workerUrl -Method Post -Body $scriptBody -Headers $customHeaders
            
            if ($scriptResponse.success) {
                if ($scriptResponse.encrypted) {
                    # ฟังก์ชันถอดรหัส AES-GCM ฝั่ง PowerShell
                    function Decrypt-Payload($encDataHex, $ivHex, $hwid) {
                        $aes = [System.Security.Cryptography.AesGcm]::new(
                            [System.Text.Encoding]::UTF8.GetBytes($hwid.PadRight(32, '0').Substring(0, 32))
                        )
                        $iv = [byte[]]($ivHex -split '(.{2})' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })
                        $cipherBytes = [byte[]]($encDataHex -split '(.{2})' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })
                        
                        $tagSize = 16
                        $actualCipher = $cipherBytes[0 .. ($cipherBytes.Length - $tagSize - 1)]
                        $tag = $cipherBytes[($cipherBytes.Length - $tagSize) .. ($cipherBytes.Length - 1)]
                        
                        $plainBytes = New-Object byte[] $actualCipher.Length
                        $aes.Decrypt($iv, $actualCipher, $tag, $plainBytes)
                        return [System.Text.Encoding]::UTF8.GetString($plainBytes)
                    }

                    # ทำการถอดรหัสสคริปต์
                    $decryptedScript = Decrypt-Payload $scriptResponse.data $scriptResponse.iv $userHwid
                    
                    # รันสคริปต์ที่ถอดรหัสแล้ว
                    Invoke-Expression $decryptedScript
                } else {
                    Invoke-Expression $scriptResponse.script
                }
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
    elseif ($choice -eq 'r' -or $choice -eq 'R') {
        Clear-Host
        Write-Host "`n     [~] Requesting Rekey / Reset..." -ForegroundColor Yellow
        try {
            $rekeyBody = @{
                action = "rekey"
                key    = $inputKey
                hwid   = $userHwid
            } | ConvertTo-Json

            $rekeyResponse = Invoke-RestMethod -Uri $workerUrl -Method Post -Body $rekeyBody -Headers $customHeaders

            if ($rekeyResponse.success) {
                Write-Host "`n     [+] $($rekeyResponse.message)" -ForegroundColor Green
            } else {
                Write-Host "`n     [X] $($rekeyResponse.message)" -ForegroundColor Red
            }
        } catch {
            Write-Host "`n     [X] Failed to execute rekey request." -ForegroundColor Red
        }
        Read-Host '     Press Enter to return'
    }
    elseif ($choice -eq 'e' -or $choice -eq 'E') {
        exit
    }
}
