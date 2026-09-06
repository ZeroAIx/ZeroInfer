# ZeroInfer installer for Windows.
#
#   irm https://zeroinfer.vercel.app/install.ps1 | iex
#
# Fetches the latest desktop installer from GitHub Releases and runs it silently
# (per-user - no admin rights needed), then launches the app. This is the same
# .exe the website's Download button hands you; the script just saves you the
# click and always resolves the newest version.

$ErrorActionPreference = 'Stop'

$Repo = 'ZeroAIx/ZeroInfer'
$AppName = 'ZeroInfer'

function Info($msg) { Write-Host ">> $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "!! $msg" -ForegroundColor Yellow }
function Die($msg)  { Write-Host "xx $msg" -ForegroundColor Red; exit 1 }

Info "Installing $AppName"

# --- Python check -------------------------------------------------------------
# ZeroInfer runs models with your own Python. The app shows a friendly screen if
# it's missing, so this is a warning and not a hard stop.
$pythonOk = $false
foreach ($cand in @(@('py', @('-3')), @('python', @()), @('python3', @()))) {
    try {
        $out = & $cand[0] @($cand[1] + @('-c', 'import sys; print("%d.%d" % sys.version_info[:2])')) 2>$null
        if ($LASTEXITCODE -eq 0 -and $out) {
            $parts = "$out".Trim().Split('.')
            if ([int]$parts[0] -eq 3 -and [int]$parts[1] -ge 10) { $pythonOk = $true; break }
        }
    } catch { }
}
if (-not $pythonOk) {
    Warn "Python 3.10+ was not found. ZeroInfer needs it to run models."
    Warn "Get it from https://www.python.org/downloads/ (tick 'Add python.exe to PATH')."
    Warn "Installing anyway - the app will walk you through it on first launch."
}

# --- Resolve the latest release ----------------------------------------------
Info "Looking up the latest release"
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" `
                                 -Headers @{ 'User-Agent' = 'zeroinfer-installer' }
} catch {
    Die "Could not reach GitHub: $($_.Exception.Message)"
}

$asset = $release.assets | Where-Object { $_.name -like '*.exe' } | Select-Object -First 1
if (-not $asset) { Die "The latest release ($($release.tag_name)) has no Windows installer." }

# --- Download + install -------------------------------------------------------
$dest = Join-Path $env:TEMP $asset.name
Info "Downloading $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB)"
try {
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add('User-Agent', 'zeroinfer-installer')
    $wc.DownloadFile($asset.browser_download_url, $dest)
} catch {
    Die "Download failed: $($_.Exception.Message)"
}

Info "Running the installer"
# /S = silent. The build is per-user, so this needs no elevation.
$proc = Start-Process -FilePath $dest -ArgumentList '/S' -Wait -PassThru
Remove-Item $dest -Force -ErrorAction SilentlyContinue

if ($proc.ExitCode -ne 0) { Die "The installer exited with code $($proc.ExitCode)." }

$exe = Join-Path $env:LOCALAPPDATA "Programs\$AppName\$AppName.exe"
if (-not (Test-Path $exe)) {
    Info "$AppName $($release.tag_name) installed. Launch it from the Start menu."
    exit 0
}

Info "$AppName $($release.tag_name) installed. Starting it now."
Start-Process -FilePath $exe
