# deploy_presets.ps1
#
# Copies ea\presets\*.set into the terminal's MQL5\Presets, injecting the
# telemetry API key on the way. deploy.ps1 does NOT copy presets (17e s4) and
# the repo presets deliberately carry TelemetryAPIKey= blank, because
# github.com/theonlykk/fxmatrix is PUBLIC.
#
# The key lives OUTSIDE the repo tree so it cannot be committed by accident.
# This script never writes back into ea\presets.
#
# Run after deploy.ps1 and before the MetaEditor compile.

$ErrorActionPreference = "Stop"

$repo    = "c:\fxmatrix\ea\presets"
$term    = "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Presets"
$keyFile = "c:\fxmatrix-local\telemetry.key"

# --- guards ---------------------------------------------------------------

if (-not (Test-Path $keyFile)) {
    Write-Host "ERROR - key file not found: $keyFile" -ForegroundColor Red
    Write-Host "Create it with the telemetry API key on a single line."
    Write-Host "It MUST live outside c:\fxmatrix so git cannot see it."
    exit 1
}

if ($keyFile -like "c:\fxmatrix\*") {
    Write-Host "ERROR - key file is inside the repo tree. Move it out." -ForegroundColor Red
    exit 1
}

$key = (Get-Content $keyFile -Raw).Trim()

if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Host "ERROR - key file is empty: $keyFile" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $term)) {
    Write-Host "ERROR - terminal presets folder not found: $term" -ForegroundColor Red
    exit 1
}

# --- copy with injection --------------------------------------------------

$written = 0
$skipped = 0
$failed  = $false

Get-ChildItem "$repo\*.set" -File | ForEach-Object {
    $name = $_.Name
    $src  = $_.FullName
    $dst  = Join-Path $term $name

    $text = Get-Content $src -Raw

    if ($text -notmatch 'TelemetryAPIKey=') {
        Write-Host "SKIP: $name (no TelemetryAPIKey line)" -ForegroundColor Yellow
        $skipped++
        return
    }

    if ($text -match 'TelemetryAPIKey=[^\r\n]') {
        # Already populated in the repo - that is a leak, refuse to proceed.
        Write-Host "ERROR: $name has a NON-BLANK TelemetryAPIKey in the repo." -ForegroundColor Red
        Write-Host "       The key must never be committed. Blank it and re-run." -ForegroundColor Red
        $failed = $true
        return
    }

    $out = $text -replace 'TelemetryAPIKey=', "TelemetryAPIKey=$key"
    Set-Content -Path $dst -Value $out -NoNewline -Encoding ASCII
    $written++
}

if ($failed) {
    Write-Host ""
    Write-Host "ERROR - aborted. DO NOT COMPILE." -ForegroundColor Red
    exit 1
}

# --- verify ---------------------------------------------------------------

$bad = $false
Get-ChildItem "$term\*.set" -File | ForEach-Object {
    $t = Get-Content $_.FullName -Raw
    if ($t -notmatch 'TelemetryAPIKey=[^\r\n]') {
        Write-Host "MISMATCH: $($_.Name) key is blank in the terminal copy" -ForegroundColor Red
        $bad = $true
    }
}

# Repo presets must still be blank - prove this script did not write back.
#
# NOTE the character class. '.+' would MATCH A BLANK LINE, because .set files
# are CRLF on a Windows checkout ('* text=auto' in .gitattributes, .set is not
# pinned) and '.' matches everything except \n - including the \r. That gave a
# false LEAK on all 18 files on the first run, 2026-09-19.
Get-ChildItem "$repo\*.set" -File | ForEach-Object {
    $r = Get-Content $_.FullName -Raw
    if ($r -match 'TelemetryAPIKey=[^\r\n]') {
        Write-Host "LEAK: $($_.Name) now has a key IN THE REPO" -ForegroundColor Red
        $bad = $true
    }
}

Write-Host ""
Write-Host "Presets written: $written   skipped: $skipped"

if ($bad) {
    Write-Host "ERROR - verification failed. DO NOT COMPILE." -ForegroundColor Red
    exit 1
}

Write-Host "Repo presets still blank - no key committed."
Write-Host "Done - presets in place with key injected. Safe to compile, then reattach."
Write-Host ""
Write-Host "Reattach is now: Properties -> Inputs -> Load preset -> OK."
Write-Host "No key copy/paste needed. Check add/exit values read as expected."
