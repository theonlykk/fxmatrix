# desktop_sync.ps1
#
# Pushes current repo sources into both MT5 terminal compile folders on
# the desktop. Unlike deploy.ps1 (VPS), there is no git pull here - the
# desktop repo at d:\fxmatrix IS the working copy Cursor/Khalid edit
# directly, so this script only handles the repo -> terminal copy step.
#
# File list is derived dynamically from git ls-files under ea/ — no
# hand-maintained manifest. Re-run safe any time ea/ changes.
#
# Two destinations (MQL5 resolves #include relative to the compiling
# file's folder, so both need the same header set):
#   - Experts: production .mq5 EAs + all shared .mqh headers
#   - Scripts: test/harness .mq5 scripts + the same .mqh headers
#
# Deliberate exclusions (not synced — see $Exclude* below):
#   - ea/archive/**  deprecated Phase-1 ref implementations
#   - V1 stack files  separate legacy product (FXMatrix.mq5 tree)
#
# Usage: run before opening MetaEditor after ea/ changes.
# Safe anytime regardless of account state — never touches charts.

$repoRoot     = "d:\fxmatrix"
$repo         = Join-Path $repoRoot "ea"
$terminalRoot = "C:\Users\Khalid Khan\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5"
$expertsDest  = Join-Path $terminalRoot "Experts"
$scriptsDest  = Join-Path $terminalRoot "Scripts"

# V1 legacy stack — not part of V2 terminal compile workflow; never synced here.
$ExcludeV1Files = @(
    "CarryEngine.mqh",
    "ExecutionEngine.mqh",
    "FXMatrix.mq5",
    "Globals.mqh",
    "LayerStruct.mqh",
    "MathEngine.mqh",
    "StateEngine.mqh",
    "TelemetryEngine.mqh"
)

# Path prefixes under ea/ to skip (forward slashes as returned by git ls-files).
$ExcludePathPrefixes = @(
    "archive/"
)

# .mq5 files routed to Scripts (remainder go to Experts).
$ScriptsMq5Patterns = @(
    "*_tests.mq5",
    "*_test.mq5"
)

function Get-GitTrackedEaSources {
    $raw = git -C $repoRoot ls-files "ea/" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: git ls-files failed in $repoRoot" -ForegroundColor Red
        exit 1
    }

    $files = @()
    foreach ($line in $raw) {
        if ($line -notmatch '\.(mq5|mqh)$') { continue }
        if ($line -notmatch '^ea/(.+)$') { continue }
        $rel = $Matches[1]

        $skip = $false
        foreach ($prefix in $ExcludePathPrefixes) {
            if ($rel -like "$prefix*") { $skip = $true; break }
        }
        if ($skip) { continue }

        $leaf = Split-Path $rel -Leaf
        if ($ExcludeV1Files -contains $leaf) { continue }

        $files += $rel
    }
    return ($files | Sort-Object -Unique)
}

function Test-ScriptsMq5 {
    param([string]$RelativePath)
    $leaf = Split-Path $RelativePath -Leaf
    foreach ($pat in $ScriptsMq5Patterns) {
        if ($leaf -like $pat) { return $true }
    }
    return $false
}

function Sync-Destination {
    param(
        [string]$Label,
        [string]$Dest,
        [string[]]$Files
    )

    Write-Host ""
    Write-Host "=== $Label ($Dest) ===" -ForegroundColor Cyan

    $localMismatch = $false
    foreach ($f in ($Files | Sort-Object)) {
        $src = Join-Path $repo $f
        $dst = Join-Path $Dest (Split-Path $f -Leaf)

        if (-not (Test-Path $src)) {
            Write-Host "MISSING IN REPO: $f" -ForegroundColor Red
            $localMismatch = $true
            continue
        }

        Copy-Item -Path $src -Destination $dst -Force

        $r = (Get-FileHash $src -Algorithm SHA256).Hash
        $t = (Get-FileHash $dst -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash

        if ($r -ne $t) {
            Write-Host "MISMATCH: $f (repo=$r term=$t)" -ForegroundColor Red
            $localMismatch = $true
        } else {
            Write-Host "OK: $f"
        }
    }

    return $localMismatch
}

Write-Host "Enumerating git-tracked ea/*.mq5 and ea/*.mqh ..." -ForegroundColor Cyan
$tracked = Get-GitTrackedEaSources

$headers   = @($tracked | Where-Object { $_ -like "*.mqh" })
$mq5All    = @($tracked | Where-Object { $_ -like "*.mq5" })
$scriptsMq5 = @($mq5All | Where-Object { Test-ScriptsMq5 $_ })
$expertsMq5 = @($mq5All | Where-Object { -not (Test-ScriptsMq5 $_) })

$expertsFiles = @($expertsMq5 + $headers)
$scriptsFiles = @($scriptsMq5 + $headers)

Write-Host "Tracked sources: $($tracked.Count) total ($($headers.Count) headers, $($mq5All.Count) mq5)"
Write-Host "  Experts: $($expertsMq5.Count) mq5 + $($headers.Count) headers = $($expertsFiles.Count) files"
Write-Host "  Scripts: $($scriptsMq5.Count) mq5 + $($headers.Count) headers = $($scriptsFiles.Count) files"

Write-Host ""
Write-Host "Deliberately excluded from sync:" -ForegroundColor Yellow
Write-Host "  ea/archive/** ($((git -C $repoRoot ls-files 'ea/archive/*.mq5' 'ea/archive/*.mqh' 2>$null | Measure-Object).Count) git-tracked archive files)"
Write-Host "  V1 stack: $($ExcludeV1Files -join ', ')"

$diskMq5  = Get-ChildItem -Path $repo -Filter *.mq5 -File -ErrorAction SilentlyContinue
$diskMqh  = Get-ChildItem -Path $repo -Filter *.mqh -File -ErrorAction SilentlyContinue
$untracked = @()
foreach ($item in ($diskMq5 + $diskMqh)) {
    $rel = $item.Name
    if ($tracked -contains $rel) { continue }
    if ($ExcludeV1Files -contains $rel) { continue }
    $untracked += $rel
}
if ($untracked.Count -gt 0) {
    Write-Host ""
    Write-Host "WARNING: untracked files in ea/ root exist on disk but are NOT synced (not in git):" -ForegroundColor Yellow
    foreach ($u in ($untracked | Sort-Object)) {
        Write-Host "  $u"
    }
}

$mismatch = $false
$mismatch = (Sync-Destination -Label "Experts" -Dest $expertsDest -Files $expertsFiles) -or $mismatch
$mismatch = (Sync-Destination -Label "Scripts" -Dest $scriptsDest -Files $scriptsFiles) -or $mismatch

# Runtime unit tests read fxmatrix_v2_engine.mqh via FileOpen(relative) from MQL5/Files/.
$filesDest = Join-Path $terminalRoot "Files"
New-Item -ItemType Directory -Force -Path $filesDest | Out-Null
$engineSrc = Join-Path $repo "fxmatrix_v2_engine.mqh"
$engineDst = Join-Path $filesDest "fxmatrix_v2_engine.mqh"
Copy-Item -Path $engineSrc -Destination $engineDst -Force
Write-Host ""
Write-Host "=== Files (runtime test reads) ===" -ForegroundColor Cyan
$engineHash = (Get-FileHash $engineSrc -Algorithm SHA256).Hash
$engineDstHash = (Get-FileHash $engineDst -Algorithm SHA256).Hash
if ($engineHash -ne $engineDstHash) {
    Write-Host "MISMATCH: fxmatrix_v2_engine.mqh in Files/" -ForegroundColor Red
    $mismatch = $true
} else {
    Write-Host "OK: fxmatrix_v2_engine.mqh -> Files/"
}

Write-Host ""
if ($mismatch) {
    Write-Host "ERROR - one or more files failed to sync correctly. DO NOT COMPILE." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Done - Experts and Scripts both verified byte-identical to repo. Safe to recompile in MetaEditor." -ForegroundColor Green
}
