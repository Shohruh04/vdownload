# V DOWNLOAD

A compact Windows terminal app for downloading videos and MP3 audio from **YouTube, Instagram, Facebook, and X / Twitter**. Choose an option with the arrow keys, press Enter, and paste your link.

Built on [yt-dlp](https://github.com/yt-dlp/yt-dlp) and [FFmpeg](https://ffmpeg.org/).

```text
  ◆ V DOWNLOAD
  YouTube · Instagram · Facebook · X / Twitter
  ─────────────────────────────────────────────

  › Video              Best quality + audio
    MP3 audio          192 kbps
    Open downloads
    Exit

  Save to  Your Downloads folder
  ● Ready

  ↑/↓ Navigate · Enter Select · Esc Exit
```

## Features

- Compact English interface with a highlighted arrow-key menu.
- Download the best available video quality with audio.
- Extract audio as MP3 at 192 kbps.
- Live download progress, speed, and estimated time remaining.
- Save files to your Windows Downloads folder, including redirected folders.
- Open Downloads directly from the menu.
- Readable error messages and a return to the menu after each download.
- No website, server, or account registration for the app.

## Requirements

- Windows 10 or 11 with Windows PowerShell 5.1 or later.
- [Python](https://www.python.org/downloads/windows/) with **yt-dlp** and its recommended dependencies.
- [FFmpeg and ffprobe](https://ffmpeg.org/download.html), together in the same directory.
- [Node.js](https://nodejs.org/) for yt-dlp's JavaScript support.

Install or update yt-dlp using the Python installation you want to use:

```powershell
python -m pip install --upgrade "yt-dlp[default]"
```

Make the dependency executables available in PATH. V DOWNLOAD also looks in your user-local bin directory and standard per-user Python installation directories. It does not bundle or install third-party dependencies.

## Quick start

1. Download this repository as a ZIP and extract it, or clone it:

   ```powershell
   git clone https://github.com/Shohruh04/vdownload.git
   ```

2. Double-click **vdownload.cmd** inside the extracted folder.
3. Choose **Video** or **MP3 audio** with **↑ / ↓**, then press **Enter**.
4. Paste your video link and press **Enter** to download.

The video container depends on the available source formats. MP3 mode always produces an `.mp3` file.

## Install the command and desktop launcher

Double-click **install.cmd**. It copies the app to `%USERPROFILE%\.local\share\vdownload`, creates a **VDownload.cmd** desktop launcher, and adds `%USERPROFILE%\.local\bin` to your user PATH if needed. Administrator permissions are not required.

Reopen your terminal and run:

```cmd
vdownload
```

If your terminal still has an old PATH, use the desktop launcher or this command:

```cmd
"%USERPROFILE%\.local\bin\vdownload.cmd"
```

## Controls

| Key | Action |
| --- | --- |
| ↑ / ↓ | Move the selection |
| Enter | Select an option |
| Esc | Exit from the main menu |
| Empty link + Enter | Return without downloading |
| Enter after a download | Return to the menu |

The selected format stays selected when you return. Each link downloads individually; YouTube playlist expansion is disabled.

## Troubleshooting

**Missing dependency:** install the named executable and make it available in PATH, then reopen the terminal. Keep FFmpeg and ffprobe together.

**Download failed:** check the error shown above the message. Platform support depends on the specific URL and current yt-dlp extractors. Private, deleted, region-restricted, or login-required videos may fail. This version does not import browser cookies or account sessions, and it deliberately ignores existing yt-dlp configuration files.

**Site changes:** update yt-dlp with the pip command above. FFmpeg can be updated separately from a Windows build provider linked by the FFmpeg project.

**Use a real terminal:** the arrow-key menu requires interactive keyboard input. It cannot be controlled through piped standard input.

## Local checks

```cmd
vdownload -Check
vdownload -Preview
```

`-Check` verifies dependency discovery. `-Preview` prints the interface without reading keys or downloading anything.

The app has been tested with an Instagram reel in both modes: video at 1080 × 1920 and MP3 at 192 kbps. Both outputs had matching durations and passed a full FFmpeg decode. This does not establish that every URL on every platform works.
