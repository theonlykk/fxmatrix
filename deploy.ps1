# deploy.ps1
cd c:\fxmatrix
git pull origin main

$repo = "c:\fxmatrix\ea"
$term = "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Experts\fxmatrix"

xcopy ea\* "$term\" /I /Y

# Verify the copy actually landed byte-identical content - git's commit hash
# already proves c:\fxmatrix\ea is correct; this proves the xcopy step didn't
# silently skip or partially fail on a locked file.
$mismatch = $false
Get-ChildItem $repo -File | ForEach-Object {
    $f = $_.Name
    $r = (Get-FileHash "$repo\$f" -Algorithm SHA256).Hash
    $t = (Get-FileHash "$term\$f" -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
    if ($r -ne $t) {
        Write-Host "MISMATCH: $f (repo=$r term=$t)" -ForegroundColor Red
        $mismatch = $true
    } else {
        Write-Host "OK: $f"
    }
}

if ($mismatch) {
    Write-Host ""
    Write-Host "ERROR - one or more files failed to sync correctly. DO NOT COMPILE." -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "Done - all files verified byte-identical. Safe to recompile in MetaEditor."
}