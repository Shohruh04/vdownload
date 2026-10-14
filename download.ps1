param([switch]$Check, [switch]$Preview, [ValidateRange(0,3)][int]$PreviewSelection = 0)

$ErrorActionPreference = 'Stop'
$downloader = $null
$localBin = Join-Path $env:USERPROFILE '.local\bin'
$toolsDir = $null
$outputDir = Join-Path $env:USERPROFILE 'Downloads'
try {
    $downloadsSetting = Get-ItemPropertyValue -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name '{374DE290-123F-4565-9164-39C4925E467B}'
    if ($downloadsSetting) { $outputDir = [Environment]::ExpandEnvironmentVariables($downloadsSetting) }
} catch { }
$node = $null
$env:Path = $localBin + ';' + $env:Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
$completedDownloads = 0
$status = 'Ready'
$statusColor = 'Green'
$uiWidth = 72
$menuTop = 0
$lastMenuWidth = 0

function Find-Executable([string]$Name, [string[]]$Fallbacks) {
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    foreach ($candidate in $Fallbacks) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return (Get-Item -LiteralPath $candidate).FullName }
    }
    throw "Missing $Name. Install the dependencies listed in README.md, then reopen your terminal."
}

function Update-Layout {
    $windowWidth = 80
    try { if ([Console]::WindowWidth -gt 0) { $windowWidth = [Console]::WindowWidth } } catch { }
    $script:uiWidth = [Math]::Max(18, [Math]::Min(76, $windowWidth - 4))
}

function Fit-Text([string]$Text, [int]$Width) {
    if ($Text.Length -gt $Width) { return $Text.Substring(0, [Math]::Max(0, $Width - 1)) + '…' }
    return $Text.PadRight($Width)
}

function Write-Line([string]$Text = '', [string]$Color = 'Gray', [switch]$Selected) {
    Write-Host '  ' -NoNewline
    $content = Fit-Text $Text $uiWidth
    if ($Selected) { Write-Host $content -ForegroundColor White -BackgroundColor DarkCyan }
    else { Write-Host $content -ForegroundColor $Color }
}

function Write-Header {
    Write-Line '◆ V DOWNLOAD' 'Cyan'
    Write-Line 'YouTube · Instagram · Facebook · X / Twitter' 'DarkGray'
    Write-Line ('─' * $uiWidth) 'DarkGray'
}

function Show-Menu([int]$SelectedIndex = 0, [switch]$Reset) {
    Update-Layout
    if (-not $Preview) {
        if ($Reset -or $lastMenuWidth -ne $uiWidth) {
            Clear-Host
            $script:menuTop = [Console]::CursorTop
        } else {
            try { [Console]::SetCursorPosition(0, $menuTop) } catch { Clear-Host; $script:menuTop = [Console]::CursorTop }
        }
        $script:lastMenuWidth = $uiWidth
    }
    Write-Line
    Write-Header
    Write-Line
    $items = @(
        @{ Title = 'Video'; Detail = 'Best quality + audio' },
        @{ Title = 'MP3 audio'; Detail = '192 kbps' },
        @{ Title = 'Open downloads'; Detail = '' },
        @{ Title = 'Exit'; Detail = '' }
    )
    for ($index = 0; $index -lt $items.Count; $index++) {
        $selected = $index -eq $SelectedIndex
        $marker = '  '
        if ($selected) { $marker = '› ' }
        $text = $marker + $items[$index].Title.PadRight(19) + $items[$index].Detail
        Write-Line $text 'Gray' -Selected:$selected
    }
    Write-Line
    Write-Line ('Save to  ' + $outputDir) 'DarkGray'
    $statusText = '● ' + $status
    if ($completedDownloads -gt 0) { $statusText += ' · ' + $completedDownloads + ' saved this session' }
    Write-Line $statusText $statusColor
    Write-Line
    Write-Line '↑/↓ Navigate · Enter Select · Esc Exit' 'DarkGray'
}

function Get-NextSelection([int]$Current, [ConsoleKey]$Key) {
    switch ($Key) {
        UpArrow { return ($Current + 3) % 4 }
        DownArrow { return ($Current + 1) % 4 }
        Home { return 0 }
        End { return 3 }
        default { return $Current }
    }
}

function Read-MenuSelection([int]$InitialIndex) {
    $selected = $InitialIndex
    try {
        [Console]::CursorVisible = $false
        Show-Menu $selected -Reset
        while ($true) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::Escape) { return 3 }
            if ($key.Key -eq [ConsoleKey]::Enter) { return $selected }
            $next = Get-NextSelection $selected $key.Key
            if ($key.Key -eq [ConsoleKey]::Tab) {
                $direction = 1
                if ($key.Modifiers -band [ConsoleModifiers]::Shift) { $direction = 3 }
                $next = ($selected + $direction) % 4
            }
            if ($next -ne $selected) { $selected = $next; Show-Menu $selected }
        }
    } finally { [Console]::CursorVisible = $true }
}

function Show-DownloadScreen([string]$Mode) {
    Update-Layout
    Clear-Host
    Write-Line
    Write-Header
    Write-Line
    if ($Mode -eq 'mp3') { Write-Line 'MP3 audio · 192 kbps' 'Cyan' }
    else { Write-Line 'Video · Best available quality + audio' 'Cyan' }
    Write-Line ('Save to  ' + $outputDir) 'DarkGray'
    Write-Line
    Write-Line 'Paste a link and press Enter.' 'White'
    Write-Line 'Leave empty to return.' 'DarkGray'
    Write-Host ''
}

function Get-VideoUri([string]$Link) {
    $videoUri = $null
    if (-not [Uri]::TryCreate($Link, [UriKind]::Absolute, [ref]$videoUri) -or $videoUri.Scheme -notin @('http', 'https')) {
        throw 'Enter a complete link starting with https:// or http://.'
    }
    foreach ($domain in @('youtube.com', 'youtu.be', 'instagram.com', 'facebook.com', 'fb.watch', 'fb.com', 'x.com', 'twitter.com')) {
        if ($videoUri.DnsSafeHost -eq $domain -or $videoUri.DnsSafeHost.EndsWith('.' + $domain, [StringComparison]::OrdinalIgnoreCase)) {
            return $videoUri
        }
    }
    throw 'Use a YouTube, Instagram, Facebook, or X / Twitter video link.'
}

function Get-DownloadArguments([string]$Mode, [Uri]$VideoUri) {
    $downloadArgs = @('--ignore-config', '--js-runtimes', ('node:' + $node), '--ffmpeg-location', $toolsDir,
        '--no-playlist', '--windows-filenames', '-P', $outputDir,
        '-o', '%(title).180B [%(id)s].%(ext)s', '--quiet', '--progress', '--progress-delta', '0.5',
        '--progress-template', 'download:  %(progress._percent_str)s | %(progress._speed_str)s | ETA %(progress._eta_str)s',
        '--progress-template', 'postprocess:  Processing file...',
        '--print', 'after_move:  Saved: %(filepath)s')
    if ($Mode -eq 'mp3') { $downloadArgs += @('-x', '--audio-format', 'mp3', '--audio-quality', '192K') }
    return $downloadArgs + @('--', $VideoUri.AbsoluteUri)
}

function Wait-ForMenu {
    Write-Host ''
    Write-Host '  Enter  Back to menu' -ForegroundColor DarkGray
    do { $key = [Console]::ReadKey($true) } while ($key.Key -notin @([ConsoleKey]::Enter, [ConsoleKey]::Escape))
}

try {
    $pythonFallbacks = @((Join-Path $localBin 'yt-dlp.exe'))
    $pythonRoot = Join-Path $env:LOCALAPPDATA 'Programs\Python'
    foreach ($pythonInstall in @(Get-ChildItem -LiteralPath $pythonRoot -Directory -Filter 'Python*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
        $pythonFallbacks += Join-Path $pythonInstall.FullName 'Scripts\yt-dlp.exe'
    }
    $downloader = Find-Executable 'yt-dlp.exe' $pythonFallbacks
    $ffmpeg = Find-Executable 'ffmpeg.exe' @((Join-Path $localBin 'ffmpeg.exe'))
    $toolsDir = Split-Path $ffmpeg -Parent
    $nodeFallbacks = @((Join-Path $localBin 'node.exe'))
    if ($env:ProgramFiles) { $nodeFallbacks += Join-Path $env:ProgramFiles 'nodejs\node.exe' }
    if ($env:NVM_SYMLINK) { $nodeFallbacks += Join-Path $env:NVM_SYMLINK 'node.exe' }
    $node = Find-Executable 'node.exe' $nodeFallbacks
    foreach ($dependency in @($downloader, (Join-Path $toolsDir 'ffmpeg.exe'), (Join-Path $toolsDir 'ffprobe.exe'), $node)) {
        if (-not (Test-Path -LiteralPath $dependency -PathType Leaf)) { throw "Required component not found: $dependency" }
    }
    if ($Check) {
        [pscustomobject]@{ Downloader = $downloader; FFmpeg = $toolsDir; Node = $node; Downloads = $outputDir } | ConvertTo-Json
        return
    }
    if ($Preview) { Show-Menu $PreviewSelection; return }
    if ([Console]::IsInputRedirected) { throw 'Open VDownload in a terminal window to use the arrow-key menu.' }
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    $Host.UI.RawUI.WindowTitle = 'V DOWNLOAD'
    $selectedIndex = 0
    while ($true) {
        $selectedIndex = Read-MenuSelection $selectedIndex
        if ($selectedIndex -eq 3) { break }
        if ($selectedIndex -eq 2) {
            Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $outputDir + '"')
            continue
        }
        $mode = 'video'
        if ($selectedIndex -eq 1) { $mode = 'mp3' }
        Show-DownloadScreen $mode
        $link = (Read-Host '  › Link').Trim().Trim('"').Trim()
        if ([string]::IsNullOrWhiteSpace($link)) { continue }
        try {
            $videoUri = Get-VideoUri $link
            $downloadArgs = Get-DownloadArguments $mode $videoUri
            Write-Host ''
            Write-Host '  ● Fetching video and downloading...' -ForegroundColor Cyan
            Write-Host ''
            & $downloader @downloadArgs
            $downloadExit = $LASTEXITCODE
            Write-Host ''
            if ($downloadExit -eq 0) {
                $completedDownloads++
                $status = 'File saved'
                $statusColor = 'Green'
                Write-Host '  ✓ Download complete' -ForegroundColor Green
                Write-Host ('  Folder: ' + $outputDir)
            } else {
                $status = 'Download failed'
                $statusColor = 'Yellow'
                Write-Host '  Download failed. See the error above.' -ForegroundColor Yellow
                Write-Host '  Some videos require login or are unavailable.'
            }
        } catch {
            $status = 'Check the link and try again'
            $statusColor = 'Yellow'
            Write-Host ''
            Write-Host ('  ' + $_.Exception.Message) -ForegroundColor Yellow
        }
        Wait-ForMenu
    }
    Clear-Host
    Write-Host '  V DOWNLOAD · See you next time.' -ForegroundColor Cyan
} catch {
    if ($Check -or $Preview -or [Console]::IsInputRedirected) { throw }
    Write-Host ('  ' + $_.Exception.Message) -ForegroundColor Red
    Read-Host 'Press Enter to close' | Out-Null
} finally {
    if (-not $Check -and -not $Preview) { try { [Console]::CursorVisible = $true } catch { } }
}
