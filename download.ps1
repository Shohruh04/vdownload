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
$videoQuality = 'best'

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

function Start-MenuRender([switch]$Reset) {
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
}

function Show-Menu([int]$SelectedIndex = 0, [switch]$Reset) {
    Start-MenuRender -Reset:$Reset
    Write-Line
    Write-Header
    Write-Line
    $items = @(
        @{ Title = 'Video'; Detail = (Get-QualityLabel $videoQuality) },
        @{ Title = 'MP3 audio'; Detail = 'Best audio quality' },
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

function Get-QualityLabel([string]$Quality) {
    switch ($Quality) {
        low { return 'Low · 480p target' }
        normal { return 'Normal · 720p target' }
        default { return 'Best · Highest available' }
    }
}

function Show-QualityMenu([int]$SelectedIndex = 2, [switch]$Reset) {
    Start-MenuRender -Reset:$Reset
    Write-Line
    Write-Header
    Write-Line
    Write-Line 'VIDEO QUALITY' 'White'
    $qualities = @('low', 'normal', 'best')
    for ($index = 0; $index -lt $qualities.Count; $index++) {
        $marker = '  '
        if ($index -eq $SelectedIndex) { $marker = '› ' }
        Write-Line ($marker + (Get-QualityLabel $qualities[$index])) 'Gray' -Selected:($index -eq $SelectedIndex)
    }
    Write-Line
    Write-Line 'Preferred source resolution; no resizing.' 'DarkGray'
    Write-Line '↑/↓ Navigate · Enter Select · Esc Back' 'DarkGray'
}

function Get-NextSelection([int]$Current, [ConsoleKey]$Key, [int]$Count = 4) {
    switch ($Key) {
        UpArrow { return ($Current + $Count - 1) % $Count }
        DownArrow { return ($Current + 1) % $Count }
        Home { return 0 }
        End { return $Count - 1 }
        default { return $Current }
    }
}

function Read-MenuSelection([int]$InitialIndex, [switch]$Quality) {
    $selected = $InitialIndex
    $count = 4
    if ($Quality) { $count = 3 }
    try {
        [Console]::CursorVisible = $false
        if ($Quality) { Show-QualityMenu $selected -Reset }
        else { Show-Menu $selected -Reset }
        while ($true) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::Escape) {
                if ($Quality) { return -1 }
                return 3
            }
            if ($key.Key -eq [ConsoleKey]::Enter) { return $selected }
            $next = Get-NextSelection $selected $key.Key $count
            if ($key.Key -eq [ConsoleKey]::Tab) {
                $direction = 1
                if ($key.Modifiers -band [ConsoleModifiers]::Shift) { $direction = $count - 1 }
                $next = ($selected + $direction) % $count
            }
            if ($next -ne $selected) {
                $selected = $next
                if ($Quality) { Show-QualityMenu $selected }
                else { Show-Menu $selected }
            }
        }
    } finally { [Console]::CursorVisible = $true }
}

function Show-DownloadScreen([string]$Mode, [string]$Quality = 'best') {
    Update-Layout
    Clear-Host
    Write-Line
    Write-Header
    Write-Line
    if ($Mode -eq 'mp3') { Write-Line 'MP3 audio · Best audio quality' 'Cyan' }
    else { Write-Line ('Video · ' + (Get-QualityLabel $Quality)) 'Cyan' }
    Write-Line ('Save to  ' + $outputDir) 'DarkGray'
    Write-Line
    Write-Line 'Paste a link and press Enter.' 'White'
    Write-Line 'Esc Back · Empty Enter Back' 'DarkGray'
    Write-Host ''
}

function Read-LinkInput {
    $text = New-Object Text.StringBuilder
    $position = 0
    [Console]::CursorVisible = $true
    Write-Host '  › Link: ' -NoNewline
    $anchorLeft = [Console]::CursorLeft
    $anchorTop = [Console]::CursorTop

    function Update-LinkField {
        $available = [Math]::Max(1, [Console]::WindowWidth - $anchorLeft - 1)
        $start = [Math]::Max(0, $position - $available + 1)
        $visible = $text.ToString().Substring($start, [Math]::Min($available, $text.Length - $start))
        [Console]::SetCursorPosition($anchorLeft, $anchorTop)
        [Console]::Write($visible.PadRight($available))
        [Console]::SetCursorPosition($anchorLeft + $position - $start, $anchorTop)
    }

    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Escape) { [Console]::WriteLine(); return $null }
        if ($key.Key -eq [ConsoleKey]::Enter) { [Console]::WriteLine(); return $text.ToString().Trim().Trim('"').Trim() }
        $paste = ($key.Key -eq [ConsoleKey]::V -and ($key.Modifiers -band [ConsoleModifiers]::Control)) -or
                 ($key.Key -eq [ConsoleKey]::Insert -and ($key.Modifiers -band [ConsoleModifiers]::Shift))
        if ($paste) {
            try {
                $clipboard = Get-Clipboard -Raw -ErrorAction Stop
                if ($clipboard) {
                    $clipboard = [regex]::Replace($clipboard, '[\x00-\x1F\x7F]', '')
                    $text.Insert($position, $clipboard) | Out-Null
                    $position += $clipboard.Length
                }
            } catch { }
            Update-LinkField
            continue
        }
        switch ($key.Key) {
            Backspace {
                if ($position -gt 0) {
                    $start = $position - 1
                    if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                        while ($start -gt 0 -and -not [char]::IsWhiteSpace($text[$start - 1])) { $start-- }
                    }
                    $text.Remove($start, $position - $start) | Out-Null
                    $position = $start
                }
            }
            Delete { if ($position -lt $text.Length) { $text.Remove($position, 1) | Out-Null } }
            LeftArrow { if ($position -gt 0) { $position-- } }
            RightArrow { if ($position -lt $text.Length) { $position++ } }
            Home { $position = 0 }
            End { $position = $text.Length }
            default {
                if (-not [char]::IsControl($key.KeyChar)) {
                    $text.Insert($position, $key.KeyChar) | Out-Null
                    $position++
                }
            }
        }
        Update-LinkField
    }
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

function Get-DownloadArguments([string]$Mode, [Uri]$VideoUri, [string]$Quality = 'best', [string]$Destination = $outputDir) {
    $suffix = ''
    if ($Mode -eq 'video' -and $Quality -eq 'low') { $suffix = ' - Low' }
    if ($Mode -eq 'video' -and $Quality -eq 'normal') { $suffix = ' - Normal' }
    $fallback = 'Video ' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    $titleSource = 'title:(?P<vdownload_title>.+)'
    if ($VideoUri.DnsSafeHost -eq 'instagram.com' -or $VideoUri.DnsSafeHost.EndsWith('.instagram.com')) {
        $titleSource = 'description:(?P<vdownload_title>[^\r\n]+)'
        $fallback = 'Instagram video ' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    }
    $downloadArgs = @('--ignore-config', '--js-runtimes', ('node:' + $node), '--ffmpeg-location', $toolsDir,
        '--no-playlist', '--windows-filenames', '-P', $Destination,
        '--parse-metadata', $titleSource,
        '--replace-in-metadata', 'vdownload_title', '[^\w\s.-]', '',
        '--replace-in-metadata', 'vdownload_title', '\s+', ' ',
        '--replace-in-metadata', 'vdownload_title', '^\s+|\s+$', '',
        '--replace-in-metadata', 'vdownload_title', '^$', $fallback,
        '-o', ('%(autonumber)05d__%(vdownload_title|' + $fallback + ').120B' + $suffix + '.%(ext)s'),
        '--no-overwrites', '--quiet', '--progress', '--progress-delta', '0.5',
        '--progress-template', 'download:  %(progress._percent_str)s | %(progress._speed_str)s | ETA %(progress._eta_str)s',
        '--progress-template', 'postprocess:  Processing file...')
    if ($Mode -eq 'mp3') { $downloadArgs += @('-f', 'bestaudio/best', '-x', '--audio-format', 'mp3', '--audio-quality', '0') }
    elseif ($Quality -eq 'low') { $downloadArgs += @('-S', 'res:480') }
    elseif ($Quality -eq 'normal') { $downloadArgs += @('-S', 'res:720') }
    return $downloadArgs + @('--', $VideoUri.AbsoluteUri)
}

function Complete-Download([string]$WorkDir) {
    $files = @(Get-ChildItem -LiteralPath $WorkDir -File | Where-Object {
        $_.Name -match '^\d{5,}__' -and $_.Extension -notin @('.part', '.ytdl')
    })
    if ($files.Count -eq 0) { throw 'No completed media file was produced.' }
    foreach ($file in $files) {
        $name = $file.Name -replace '^\d{5,}__', ''
        if ($name -match '^(?i:CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])(?:\.|$)') { $name = '_' + $name }
        $stem = [IO.Path]::GetFileNameWithoutExtension($name)
        $extension = [IO.Path]::GetExtension($name)
        $counter = 1
        while ($true) {
            $candidate = $name
            if ($counter -gt 1) { $candidate = $stem + ' (' + $counter + ')' + $extension }
            $destination = Join-Path $outputDir $candidate
            try { [IO.File]::Move($file.FullName, $destination); break }
            catch [IO.IOException] {
                if (-not (Test-Path -LiteralPath $destination)) { throw }
                $counter++
            }
        }
        Write-Host ('  Saved: ' + $destination)
    }
    if (@(Get-ChildItem -LiteralPath $WorkDir -Force).Count -eq 0) {
        [IO.Directory]::Delete($WorkDir)
    }
}

function Wait-ForMenu {
    Write-Host ''
    Write-Host '  Enter / Esc  Back to menu' -ForegroundColor DarkGray
    do { $key = [Console]::ReadKey($true) } while ($key.Key -notin @([ConsoleKey]::Enter, [ConsoleKey]::Escape))
}

function Get-NativeArguments([string[]]$Arguments) {
    $legacy = $PSVersionTable.PSVersion.Major -le 5
    $passing = Get-Variable PSNativeCommandArgumentPassing -ErrorAction SilentlyContinue
    if ($passing -and $passing.Value -eq 'Legacy') { $legacy = $true }
    foreach ($argument in $Arguments) {
        if ($legacy -and $argument -eq '') { '""' }
        else { $argument }
    }
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
    $qualityIndex = 2
    while ($true) {
        $selectedIndex = Read-MenuSelection $selectedIndex
        if ($selectedIndex -eq 3) { break }
        if ($selectedIndex -eq 2) {
            Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $outputDir + '"')
            continue
        }
        $mode = 'video'
        if ($selectedIndex -eq 1) { $mode = 'mp3' }
        else {
            $qualitySelection = Read-MenuSelection $qualityIndex -Quality
            if ($qualitySelection -lt 0) { continue }
            $qualityIndex = $qualitySelection
            $videoQuality = @('low', 'normal', 'best')[$qualityIndex]
        }
        Show-DownloadScreen $mode $videoQuality
        $link = Read-LinkInput
        if ([string]::IsNullOrWhiteSpace($link)) { continue }
        try {
            $videoUri = Get-VideoUri $link
            $workDir = Join-Path ([IO.Path]::GetTempPath()) ('vdownload-' + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $workDir | Out-Null
            $downloadArgs = Get-DownloadArguments $mode $videoUri $videoQuality $workDir
            Write-Host ''
            Write-Host '  ● Fetching video and downloading...' -ForegroundColor Cyan
            Write-Host ''
            $nativeArgs = @(Get-NativeArguments $downloadArgs)
            & $downloader @nativeArgs
            $downloadExit = $LASTEXITCODE
            Write-Host ''
            if ($downloadExit -eq 0) {
                Complete-Download $workDir
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
