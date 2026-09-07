$Host.UI.RawUI.WindowTitle = "Develop By NITROPRIME STORE"
cmd.exe /c "mode con: cols=60 lines=15 & color 07"

Clear-Host
Write-Host ""
Write-Host "     [ NITROPRIME STORE ]" -ForegroundColor DarkGray
Write-Host "     Internet Latest v.2"
Write-Host ""

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

$inputKey = Read-Host "     Key"

if ([string]::IsNullOrWhiteSpace($inputKey)) {
    Write-Host "`n     [X] Key cannot be empty!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    exit
}

$inputKey = $inputKey.Trim()
$customHeaders = @{ "Content-Type" = "application/json" }

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

$body = @{ key = $inputKey; hwid = $userHwid } | ConvertTo-Json

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
    Start-Sleep -Seconds 5
    exit
}

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
    Write-Host "     [+] [F] Install Program"
    Write-Host ""
    
    $choice = Read-Host "     [+] :"
    
    if ($choice -eq 'f' -or $choice -eq 'F') {
        Clear-Host
        try {
            $tokenBody = @{ action = "get_token"; key = $inputKey; hwid = $userHwid } | ConvertTo-Json
            $tokenResponse = Invoke-RestMethod -Uri $workerUrl -Method Post -Body $tokenBody -Headers $customHeaders

            if (-not $tokenResponse.success) {
                Write-Host "`n     [X] Failed to get token: $($tokenResponse.message)" -ForegroundColor Red
                Read-Host '     Press Enter to return'
                continue
            }

            $sessionToken = $tokenResponse.token
            $scriptBody = @{ action = "get_script"; token = $sessionToken; hwid = $userHwid; key = $inputKey } | ConvertTo-Json
            $scriptResponse = Invoke-RestMethod -Uri $workerUrl -Method Post -Body $scriptBody -Headers $customHeaders
            
            if ($scriptResponse.success) {
                if ($scriptResponse.encrypted) {
                    # 💡 ฟังก์ชันถอดรหัส AES-GCM ให้ตรงกับฝั่ง Cloudflare Worker (.NET Core / PowerShell 7+)
                    function Decrypt-Payload-GCM($encDataHex, $ivHex, $hwid) {
                        # แปลง HWID เป็น Key 32 ไบต์
                        $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($hwid.PadRight(32, '0').Substring(0, 32))
                        
                        # แปลง IV จาก Hex เป็น Byte Array (12 ไบต์สำหรับ GCM)
                        $ivBytes = New-Object byte[] ($ivHex.Length / 2)
                        for ($i = 0; $i -lt $ivHex.Length; $i += 2) {
                            $ivBytes[$i / 2] = [Convert]::ToByte($ivHex.Substring($i, 2), 16)
                        }

                        # แปลงข้อมูล Encrypted จาก Hex เป็น Byte Array
                        $fullCipher = New-Object byte[] ($encDataHex.Length / 2)
                        for ($i = 0; $i -lt $encDataHex.Length; $i += 2) {
                            $fullCipher[$i / 2] = [Convert]::ToByte($encDataHex.Substring($i, 2), 16)
                        }

                        # แยก Auth Tag ออกจากท้ายข้อมูล (AES-GCM ของ Web Crypto API จะพ่วง Tag 16 ไบต์สุดท้ายมาด้วย)
                        $tagSize = 16
                        $cipherTextSize = $fullCipher.Length - $tagSize
                        
                        $cipherBytes = New-Object byte[] $cipherTextSize
                        $tagBytes = New-Object byte[] $tagSize
                        
                        [System.Array]::Copy($fullCipher, 0, $cipherBytes, 0, $cipherTextSize)
                        [System.Array]::Copy($fullCipher, $cipherTextSize, $tagBytes, 0, $tagSize)

                        $plainBytes = New-Object byte[] $cipherTextSize

                        # ใช้ AesGcm ในการถอดรหัส
                        $aesGcm = [System.Security.Cryptography.AesGcm]::new($keyBytes)
                        $aesGcm.Decrypt($ivBytes, $cipherBytes, $tagBytes, $plainBytes)

                        return [System.Text.Encoding]::UTF8.GetString($plainBytes)
                    }

                    $decryptedScript = Decrypt-Payload-GCM $scriptResponse.data $scriptResponse.iv $userHwid
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
                    $errBody = $reader.ReadToEnd()
                    Write-Host "     [X] Server says: $errBody" -ForegroundColor Yellow
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
