# Replay harness runner (fix3 P1). PowerShell 5+.
param(
   [Parameter(Mandatory = $true)]
   [ValidateSet('Copy', 'Inputs', 'Suite', 'Run')]
   [string]$Mode,

   [string]$Tag = '',
   [string]$Label = '',
   [string]$Set = '',
   [string]$Commit = '',
   [string]$SwapsSha = '',
   [switch]$Sync,
   [int]$TimeoutSec = 1800
)

$ErrorActionPreference = 'Stop'

$Root = 'D:\mt5-replay'
$RootPrefix = $Root + '\'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SafeToken = '^[A-Za-z0-9_]+$'
$SafeCommit = '^[0-9a-f]{7,40}$'
$SafeSha64 = '^[0-9a-f]{64}$'
$SafeFile = '^[A-Za-z0-9_.]+$'

function Assert-Match([string]$Name, [string]$Value, [string]$Pattern) {
   if ($Value -notmatch $Pattern) {
      throw "Invalid $Name"
   }
}

function Stop-ReplayTerminals() {
   $deadline = (Get-Date).AddSeconds(30)
   do {
      $procs = Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue
      foreach ($p in $procs) {
         $path = $p.ExecutablePath
         if ([string]::IsNullOrEmpty($path)) { continue }
         if ($path.StartsWith($RootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
         }
      }
      Start-Sleep -Milliseconds 500
   } while ((Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($RootPrefix, [StringComparison]::OrdinalIgnoreCase) }) -and
            (Get-Date) -lt $deadline)
   $left = Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($RootPrefix, [StringComparison]::OrdinalIgnoreCase) }
   if ($left) { throw 'Replay terminal still running under D:\mt5-replay' }
}

function Write-Utf16LeIni([string]$Path, [string[]]$Lines) {
   $text = $Lines -join "`n"
   [System.IO.File]::WriteAllText($Path, $text, [System.Text.UnicodeEncoding]::new($false, $true))
}

function Write-Utf8CrlfPreset([string]$Path, [string[]]$Lines) {
   $text = ($Lines -join "`r`n") + "`r`n"
   $utf8 = New-Object System.Text.UTF8Encoding $false
   [System.IO.File]::WriteAllText($Path, $text, $utf8)
}

function Get-LogLinesAfter([datetime]$StartLocal, [object[]]$LogSources) {
   $out = New-Object System.Collections.Generic.List[string]
   foreach ($src in $LogSources) {
      $lp = $src.Path
      $lineDate = $src.LineDate
      if (-not (Test-Path $lp)) { continue }
      $raw = [System.IO.File]::ReadAllText($lp, [System.Text.Encoding]::Unicode)
      foreach ($line in ($raw -split "`r?`n")) {
         if ($line.Length -lt 20) { continue }
         if ($line -notmatch 'RPL\|' -and $line -notmatch 'FAIL \|' -and $line -notmatch 'RT35-LOAD-MS') { continue }
         if ($line -match '^\S+\s+\d+\s+(\d{2}):(\d{2}):(\d{2})\.\d+\s+') {
            $h = [int]$Matches[1]; $m = [int]$Matches[2]; $s = [int]$Matches[3]
            $ts = Get-Date -Year $lineDate.Year -Month $lineDate.Month -Day $lineDate.Day -Hour $h -Minute $m -Second $s
            if ($ts -lt $StartLocal.AddSeconds(-2)) { continue }
         }
         $out.Add($line) | Out-Null
      }
   }
   return $out
}

# --- Step 0 validation ---
if ($TimeoutSec -lt 60 -or $TimeoutSec -gt 7200) { throw 'Invalid TimeoutSec' }

switch ($Mode) {
   'Copy' { }
   'Inputs' {
      Assert-Match 'Set' $Set $SafeToken
      Assert-Match 'Commit' $Commit $SafeCommit
   }
   'Suite' {
      Assert-Match 'Tag' $Tag $SafeToken
      $Label = $Tag
   }
   'Run' {
      Assert-Match 'Tag' $Tag $SafeToken
      Assert-Match 'Label' $Label $SafeToken
      Assert-Match 'SwapsSha' $SwapsSha $SafeSha64
   }
}

if ($Mode -eq 'Copy') {
   $srcDir = Join-Path $RepoRoot 'ea'
   $dstDir = Join-Path $Root 'MQL5\Scripts\fxmatrix'
   New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
   $files = @(Get-ChildItem $srcDir -Filter '*.mq5') + @(Get-ChildItem $srcDir -Filter '*.mqh')
   $n = 0
   foreach ($f in $files) {
      $dst = Join-Path $dstDir $f.Name
      Copy-Item $f.FullName $dst -Force
      $h1 = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLower()
      $h2 = (Get-FileHash $dst -Algorithm SHA256).Hash.ToLower()
      if ($h1 -ne $h2) { throw "COPY mismatch $($f.Name)" }
      $n++
   }
   Write-Output "COPY $n/$n identical"
   exit 0
}

if ($Mode -eq 'Inputs') {
   $manifestPath = "research/replay/inputs/$Set.sha256"
   $manifest = git -C $RepoRoot show "${Commit}:$manifestPath" 2>&1
   if ($LASTEXITCODE -ne 0) { throw "git show manifest failed" }
   $dest = Join-Path $Root 'MQL5\Files\replay'
   New-Item -ItemType Directory -Force -Path $dest | Out-Null
   $entries = New-Object System.Collections.Generic.List[object]
   foreach ($line in ($manifest -split "`n")) {
      if ($line -notmatch '^([a-f0-9]{64})\s+(.+)$') { continue }
      $want = $Matches[1]; $name = $Matches[2].Trim()
      Assert-Match 'input file' $name $SafeFile
      if ($name -match '\.\.') { throw 'Invalid input file' }
      $entries.Add([pscustomobject]@{ Want = $want; Name = $name }) | Out-Null
   }
   $good = 0
   foreach ($e in $entries) {
      $path = Join-Path $dest $e.Name
      $gitPath = "research/replay/inputs/$Set/$($e.Name)"
      cmd /c "git -C `"$RepoRoot`" show ${Commit}:$gitPath > `"$path`"" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "git show $($e.Name) failed" }
      $got = (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
      if ($got -ne $e.Want) { throw "INPUT hash mismatch $($e.Name)" }
      $good++
   }
   $w2 = Join-Path $dest 'ticks_53077984_EURUSD_w2.csv'
   $w2src = Join-Path $env:USERPROFILE 'Downloads\ticks_53077984_EURUSD_w2.csv'
   if (Test-Path $w2src) { Copy-Item $w2src $w2 -Force }
   $wantW2 = 'db2ea94173a4d0c8746c7fecc972c8950da79c803910a25e0bbc522bc63abd28'
   if (-not (Test-Path $w2)) { throw 'w2 ticks file missing' }
   $gotW2 = (Get-FileHash $w2 -Algorithm SHA256).Hash.ToLower()
   if ($gotW2 -ne $wantW2) { throw 'w2 SHA mismatch' }
   Write-Output "INPUTS $good/$good ok"
   exit 0
}

Stop-ReplayTerminals

if ($Mode -eq 'Run') {
   $swapsPath = Join-Path $Root 'MQL5\Files\replay\swaps.csv'
   $got = (Get-FileHash $swapsPath -Algorithm SHA256).Hash.ToLower()
   if ($got -ne $SwapsSha.ToLower()) { throw 'swaps.csv SHA mismatch' }
   $syncLine = if ($Sync) { 'InpSync=true' } else { 'InpSync=false' }
   $presetPath = Join-Path $Root "MQL5\Presets\fxgrind_replay_$Label.set"
   Write-Utf8CrlfPreset $presetPath @(
      '; fxgrind_replay',
      "InpRunTag=$Tag",
      $syncLine
   )
   $iniLines = @(
      '[StartUp]',
      'Script=fxmatrix\fxgrind_replay',
      "ScriptParameters=fxgrind_replay_$Label.set",
      'Symbol=EURUSD',
      'Period=M1',
      'ShutdownTerminal=1'
   )
} else {
   $iniLines = @(
      '[StartUp]',
      'Script=fxmatrix\fxgrind_replay_tests',
      'Symbol=EURUSD',
      'Period=M1',
      'ShutdownTerminal=1'
   )
}

$iniPath = Join-Path $Root "replay_$Label.ini"
Write-Utf16LeIni $iniPath $iniLines

$startLocal = Get-Date
$startDate = $startLocal.Date
$logToday = Join-Path $Root "MQL5\Logs\$($startLocal.ToString('yyyyMMdd')).log"
$logTomorrow = Join-Path $Root "MQL5\Logs\$($startLocal.AddDays(1).ToString('yyyyMMdd')).log"
$logSources = @(
   [pscustomobject]@{ Path = $logToday; LineDate = $startDate },
   [pscustomobject]@{ Path = $logTomorrow; LineDate = $startDate.AddDays(1) }
)

$proc = Start-Process -FilePath (Join-Path $Root 'terminal64.exe') `
   -ArgumentList @('/portable', "/config:$iniPath") -PassThru
$sw = [Diagnostics.Stopwatch]::StartNew()
while (-not $proc.HasExited -and $sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
   Start-Sleep -Seconds 2
}
if (-not $proc.HasExited) {
   Stop-Process -Id $proc.Id -Force
   throw "Timeout after $TimeoutSec s"
}

$lines = Get-LogLinesAfter $startLocal $logSources
$outDir = Join-Path $RepoRoot 'research\replay\runs'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outFile = Join-Path $outDir "_rpl_$Label.txt"
$lines | Set-Content $outFile -Encoding utf8

Write-Output "DONE $Label exit=$($proc.ExitCode) sec=$([int]$sw.Elapsed.TotalSeconds) lines=$($lines.Count)"
