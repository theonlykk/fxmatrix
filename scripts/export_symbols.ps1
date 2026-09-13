# export_symbols.ps1 -- headless Strategy Tester M5 CSV export via DataExporterEA
# Desktop only. Idempotent: skips symbols whose data\<SYMBOL>_m5.csv already verifies.

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$Symbols,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$DataDir = Join-Path $RepoRoot 'data'
$EaSource = Join-Path $RepoRoot 'scripts\DataExporterEA.mq5'
$WorkDir = Join-Path $RepoRoot 'scripts\export_work'
$ExpectedHeader = 'datetime,OPEN,HIGH,LOW,CLOSE,SPREAD'
$MinRowCountHint = 500000

function Find-Terminal64 {
    $candidates = @(
        'C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe',
        'C:\Program Files\MetaTrader 5\terminal64.exe',
        'C:\Program Files\FTMO MetaTrader 5\terminal64.exe'
    )
    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }
    throw 'terminal64.exe not found in known install paths'
}

function Find-MetaEditor64 {
    $term = Split-Path -Parent (Find-Terminal64)
    $editor = Join-Path $term 'metaeditor64.exe'
    if (-not (Test-Path -LiteralPath $editor)) {
        throw 'metaeditor64.exe not found beside terminal64.exe'
    }
    return $editor
}

function Get-TerminalDataDir {
    $root = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
    if (-not (Test-Path -LiteralPath $root)) {
        throw "MetaQuotes Terminal data root missing: $root"
    }
    $dirs = @(Get-ChildItem -LiteralPath $root -Directory |
        Where-Object { $_.Name -ne 'Common' -and $_.Name -ne 'Community' })
    if ($dirs.Count -eq 0) {
        throw 'No MT5 terminal data directory found under AppData\MetaQuotes\Terminal'
    }
    if ($dirs.Count -gt 1) {
        $picked = $dirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "NOTE multiple terminal data dirs; using newest: $($picked.FullName)"
        return $picked.FullName
    }
    return $dirs[0].FullName
}

function Ensure-GuiClosed {
    $names = @('terminal64', 'MetaEditor64', 'metatester64')
    $running = Get-Process -Name $names -ErrorAction SilentlyContinue
    if ($running) {
        Write-Host 'Closing MT5 GUI processes (required for headless tester)...'
        $running | Stop-Process -Force
        Start-Sleep -Seconds 3
    }
    $still = Get-Process -Name $names -ErrorAction SilentlyContinue
    if ($still) {
        throw 'MT5 GUI still running after Stop-Process'
    }
}

function Ensure-EaDeployed {
    param(
        [string]$TerminalData,
        [string]$MetaEditor
    )
    $expertsDir = Join-Path $TerminalData 'MQL5\Experts'
    $destMq5 = Join-Path $expertsDir 'DataExporterEA.mq5'
    $destEx5 = Join-Path $expertsDir 'DataExporterEA.ex5'
    if (-not (Test-Path -LiteralPath $expertsDir)) {
        New-Item -ItemType Directory -Path $expertsDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $EaSource -Destination $destMq5 -Force
    $srcTime = (Get-Item -LiteralPath $EaSource).LastWriteTimeUtc
    $needsCompile = $true
    if (Test-Path -LiteralPath $destEx5) {
        $ex5Time = (Get-Item -LiteralPath $destEx5).LastWriteTimeUtc
        if ($ex5Time -ge $srcTime) {
            $needsCompile = $false
        }
    }
    if ($needsCompile) {
        Ensure-GuiClosed
        $logPath = Join-Path $WorkDir ('compile_' + [guid]::NewGuid().ToString('N') + '.log')
        New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
        $args = @(
            "/compile:`"$destMq5`"",
            "/log:`"$logPath`""
        )
        $proc = Start-Process -FilePath $MetaEditor -ArgumentList $args -PassThru -Wait
        if (-not (Test-Path -LiteralPath $destEx5)) {
            $logText = ''
            if (Test-Path -LiteralPath $logPath) {
                $logText = Get-Content -LiteralPath $logPath -Raw -ErrorAction SilentlyContinue
            }
            throw "DataExporterEA compile failed; ex5 missing. MetaEditor exit=$($proc.ExitCode). Log:`n$logText"
        }
        $ex5Time = (Get-Item -LiteralPath $destEx5).LastWriteTimeUtc
        if ($ex5Time -lt $srcTime) {
            throw 'DataExporterEA.ex5 timestamp older than source; compile likely no-op'
        }
    }
}

function Ensure-MarketWatchSymbol {
    param(
        [string]$Symbol,
        [string]$TerminalExe
    )
    $py = @"
import MetaTrader5 as mt5
import sys
path = r'$($TerminalExe.Replace("'", "''"))'
sym = '$Symbol'
if not mt5.initialize(path=path):
    print('MT5_INIT_FAIL', mt5.last_error())
    sys.exit(2)
info = mt5.symbol_info(sym)
was_visible = info is not None and info.visible
if not mt5.symbol_select(sym, True):
    print('SYMBOL_SELECT_FAIL', sym)
    mt5.shutdown()
    sys.exit(1)
info = mt5.symbol_info(sym)
if info is None or not info.visible:
    print('SYMBOL_NOT_VISIBLE', sym)
    mt5.shutdown()
    sys.exit(1)
print('SYMBOL_OK', sym, 'was_visible=' + str(was_visible))
mt5.shutdown()
sys.exit(0)
"@
    $tmp = Join-Path $WorkDir ('mw_' + $Symbol + '.py')
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    Set-Content -LiteralPath $tmp -Value $py -Encoding ASCII
    $out = & python $tmp 2>&1
    $text = ($out | Out-String).Trim()
    Write-Host $text
    if ($LASTEXITCODE -ne 0) {
        throw "Symbol $Symbol missing from Market Watch (symbol_select failed). Output: $text"
    }
    if ($text -match 'was_visible=False') {
        Write-Host "NOTE $Symbol was not in Market Watch; added via symbol_select before export."
    }
}

function Get-DateTimeUnix {
    param([datetime]$Dt)
    $epoch = Get-Date '1970-01-01 00:00:00'
    return [int64][Math]::Floor(($Dt - $epoch).TotalSeconds)
}

function New-TesterIni {
    param(
        [string]$Symbol,
        [datetime]$FromDt,
        [datetime]$ToDt,
        [string]$OutFile,
        [string]$IniPath
    )
    $fromTs = Get-DateTimeUnix $FromDt
    $toEnd = Get-Date ($ToDt.ToString('yyyy-MM-dd') + ' 23:59:59')
    $toTs = Get-DateTimeUnix $toEnd
    $fromDate = $FromDt.ToString('yyyy.MM.dd')
    $toDate = $ToDt.ToString('yyyy.MM.dd')
    $lines = @(
        '; generated by export_symbols.ps1',
        '[Tester]',
        'Expert=DataExporterEA.ex5',
        "Symbol=$Symbol",
        'Period=M5',
        'Model=2',
        'Optimization=0',
        'Visual=0',
        "FromDate=$fromDate",
        "ToDate=$toDate",
        'Deposit=10000',
        'Currency=USD',
        'Leverage=100',
        'ExecutionMode=0',
        'ForwardMode=0',
        'ReplaceReport=1',
        "Report=export_$Symbol",
        'ShutdownTerminal=1',
        '',
        '[TesterInputs]',
        "InpFrom=$fromTs||$fromTs||1||$fromTs||N",
        "InpTo=$toTs||$toTs||1||$toTs||N",
        "InpOutFile=$OutFile"
    )
    Set-Content -LiteralPath $IniPath -Value $lines -Encoding ASCII
}

function Get-CommonFilesDir {
    return Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
}

function Find-WroteLine {
    param(
        [string]$TerminalData,
        [string]$Symbol,
        [datetime]$RunStarted
    )
    $patterns = @(
        (Join-Path $TerminalData 'logs\*.log'),
        (Join-Path $TerminalData 'Tester\logs\*.log'),
        (Join-Path $TerminalData 'Tester\*.log'),
        (Join-Path $env:APPDATA 'MetaQuotes\Tester\*\Agent-*\logs\*.log')
    )
    $candidates = @()
    foreach ($pat in $patterns) {
        $candidates += @(Get-ChildItem -Path $pat -File -ErrorAction SilentlyContinue)
    }
    $candidates = $candidates |
        Where-Object { $_.LastWriteTime -ge $RunStarted.AddMinutes(-1) } |
        Sort-Object LastWriteTime -Descending
    foreach ($log in $candidates) {
        $matches = Select-String -LiteralPath $log.FullName -Pattern 'DataExporterEA WROTE' -SimpleMatch
        foreach ($m in $matches) {
            if ($m.Line -match $Symbol -or $m.Line -match "${Symbol}_m5\.csv") {
                return @{ Line = $m.Line.Trim(); Log = $log.FullName }
            }
        }
    }
    foreach ($log in $candidates) {
        $matches = Select-String -LiteralPath $log.FullName -Pattern 'DataExporterEA WROTE' -SimpleMatch
        if ($matches) {
            return @{ Line = $matches[-1].Line.Trim(); Log = $log.FullName }
        }
    }
    return $null
}

function Test-ExportedCsv {
    param(
        [string]$CsvPath,
        [datetime]$RunStarted,
        [ref]$RowCount,
        [ref]$FirstDataLines,
        [ref]$LastDataLines
    )
    if (-not (Test-Path -LiteralPath $CsvPath)) {
        throw "CSV missing: $CsvPath"
    }
    $item = Get-Item -LiteralPath $CsvPath
    if ($item.LastWriteTime -lt $RunStarted.AddSeconds(-5)) {
        throw "CSV modification time $($item.LastWriteTime) not newer than run start $RunStarted"
    }
    $reader = [System.IO.File]::OpenText($CsvPath)
    try {
        $header = $reader.ReadLine()
        if ($header -ne $ExpectedHeader) {
            throw "CSV header mismatch. Expected '$ExpectedHeader' got '$header'"
        }
        $count = 0
        $first = New-Object System.Collections.Generic.List[string]
        $last = New-Object System.Collections.Generic.List[string]
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line.Length -eq 0) { continue }
            $count++
            if ($first.Count -lt 2) { [void]$first.Add($line) }
            if ($last.Count -eq 2) { $last.RemoveAt(0) }
            [void]$last.Add($line)
        }
        $RowCount.Value = $count
        $FirstDataLines.Value = $first
        $LastDataLines.Value = $last
    }
    finally {
        $reader.Close()
    }
}

function Test-DestCsvValid {
    param([string]$DestPath)
    if (-not (Test-Path -LiteralPath $DestPath)) { return $false }
    try {
        $reader = [System.IO.File]::OpenText($DestPath)
        try {
            $header = $reader.ReadLine()
            if ($header -ne $ExpectedHeader) { return $false }
            $count = 0
            while ($null -ne ($line = $reader.ReadLine())) {
                if ($line.Length -gt 0) { $count++ }
            }
            return ($count -gt 0)
        }
        finally {
            $reader.Close()
        }
    }
    catch {
        return $false
    }
}

function Export-Symbol {
    param(
        [string]$Symbol,
        [string]$TerminalExe,
        [string]$TerminalData,
        [datetime]$FromDt,
        [datetime]$ToDt
    )
    Ensure-MarketWatchSymbol -Symbol $Symbol -TerminalExe $TerminalExe

    $outName = "${Symbol}_m5.csv"
    $destPath = Join-Path $DataDir $outName
    if ((Test-Path -LiteralPath $destPath) -and (-not $Force)) {
        if (Test-DestCsvValid -DestPath $destPath) {
            Write-Host "SKIP $Symbol -- valid CSV already at $destPath"
            return
        }
    }

    Ensure-GuiClosed
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    $iniPath = Join-Path $WorkDir ("tester_" + $Symbol + '.ini')
    New-TesterIni -Symbol $Symbol -FromDt $FromDt -ToDt $ToDt -OutFile $outName -IniPath $iniPath

    Write-Host "CONFIG $iniPath"
    Get-Content -LiteralPath $iniPath | ForEach-Object { Write-Host $_ }

    $runStarted = Get-Date
    $proc = Start-Process -FilePath $TerminalExe -ArgumentList @("/config:`"$iniPath`"") -PassThru -Wait
    Write-Host "terminal64 exit code: $($proc.ExitCode)"

    $commonCsv = Join-Path (Get-CommonFilesDir) $outName
    Start-Sleep -Seconds 2

    $wrote = Find-WroteLine -TerminalData $TerminalData -Symbol $Symbol -RunStarted $runStarted
    if (-not $wrote) {
        throw "No 'DataExporterEA WROTE' line found in post-run logs for $Symbol"
    }
    Write-Host "LOG $($wrote.Log)"
    Write-Host "WROTE $($wrote.Line)"

    $rowCount = 0
    $first = $null
    $last = $null
    Test-ExportedCsv -CsvPath $commonCsv -RunStarted $runStarted `
        -RowCount ([ref]$rowCount) -FirstDataLines ([ref]$first) -LastDataLines ([ref]$last)

    if ($rowCount -lt $MinRowCountHint) {
        Write-Host "WARN $Symbol row count $rowCount below hint $MinRowCountHint (thin cross may be genuine)"
    }

    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
    Copy-Item -LiteralPath $commonCsv -Destination $destPath -Force
    Write-Host "COPIED $commonCsv -> $destPath rows=$rowCount"
}

# --- main ---
if (-not (Test-Path -LiteralPath $EaSource)) {
    throw "Missing EA source: $EaSource"
}

$terminalExe = Find-Terminal64
$metaEditor = Find-MetaEditor64
$terminalData = Get-TerminalDataDir
$commonFiles = Get-CommonFilesDir

Write-Host "terminal64=$terminalExe"
Write-Host "terminal_data=$terminalData"
Write-Host "common_files=$commonFiles"

Ensure-GuiClosed
Ensure-EaDeployed -TerminalData $terminalData -MetaEditor $metaEditor

$fromDt = Get-Date '2015-01-01 00:00:00'
$toDt = Get-Date

foreach ($sym in $Symbols) {
    Write-Host "=== EXPORT $sym ==="
    Export-Symbol -Symbol $sym -TerminalExe $terminalExe -TerminalData $terminalData `
        -FromDt $fromDt -ToDt $toDt
}

Write-Host 'DONE'
