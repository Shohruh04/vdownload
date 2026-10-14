$ErrorActionPreference = 'Stop'

try {
    $appDir = Join-Path $env:USERPROFILE '.local\share\vdownload'
    $binDir = Join-Path $env:USERPROFILE '.local\bin'
    New-Item -ItemType Directory -Path $appDir, $binDir -Force | Out-Null
    foreach ($name in @('download.ps1', 'vdownload.cmd', 'README.md')) {
        $source = Join-Path $PSScriptRoot $name
        $destination = Join-Path $appDir $name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing application file: $name" }
        if ([IO.Path]::GetFullPath($source) -ne [IO.Path]::GetFullPath($destination)) {
            Copy-Item -LiteralPath $source -Destination $destination -Force
        }
    }

    $launcher = @'
@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.local\share\vdownload\download.ps1" %*
if errorlevel 1 pause
'@
    $launcher = ($launcher -replace '\r?\n', "`r`n") + "`r`n"
    [IO.File]::WriteAllText((Join-Path $binDir 'vdownload.cmd'), $launcher, [Text.Encoding]::ASCII)
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ($desktop -and (Test-Path -LiteralPath $desktop)) {
        [IO.File]::WriteAllText((Join-Path $desktop 'VDownload.cmd'), $launcher, [Text.Encoding]::ASCII)
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $hasBin = $false
    foreach ($entry in @($userPath -split ';')) {
        if ([Environment]::ExpandEnvironmentVariables($entry).Trim().TrimEnd('\') -eq $binDir.TrimEnd('\')) { $hasBin = $true; break }
    }
    if (-not $hasBin) {
        $newPath = $binDir
        if (-not [string]::IsNullOrWhiteSpace($userPath)) { $newPath = $userPath.TrimEnd(';') + ';' + $binDir }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    }
    $env:Path = $binDir + ';' + $env:Path
    Write-Host 'V DOWNLOAD installed.' -ForegroundColor Cyan
    Write-Host 'Open VDownload.cmd on your desktop, or run vdownload in a new terminal.'
    Write-Host ('Application files: ' + $appDir)
    Write-Host 'Dependencies: yt-dlp, FFmpeg + ffprobe, and Node.js.'
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
