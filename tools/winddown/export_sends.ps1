# export_sends.ps1 -- pipshed send_logs, one file per instance (winddown runbook s5 step 3c).
# pipshed deletes send_logs after 14 days; this keeps them. Read-only on pipshed. Never overwrites a file.
#   & "$HOME\Downloads\export_sends.ps1"
$ErrorActionPreference = 'Continue'
$out = 'D:\fxmatrix-exports\winddown\pipshed\sends'
New-Item -ItemType Directory -Force $out | Out-Null
Set-Location D:\pipshed
$ids = @(
  'GRIND_AUDCAD_ALT',
  'GRIND_AUDCAD_ALTC',
  'GRIND_AUDCAD_ALTD',
  'GRIND_AUDCAD_ALTE',
  'GRIND_AUDCAD_OPT',
  'GRIND_AUDCAD_OPTB',
  'GRIND_AUDCAD_OPTC',
  'GRIND_AUDCAD_OPTD',
  'GRIND_AUDCAD_OPTE',
  'GRIND_AUDCHF_ALT',
  'GRIND_AUDCHF_ALTD',
  'GRIND_AUDCHF_ALTE',
  'GRIND_AUDCHF_OPT',
  'GRIND_AUDCHF_OPTB',
  'GRIND_AUDCHF_OPTC',
  'GRIND_AUDCHF_OPTD',
  'GRIND_AUDCHF_OPTE',
  'GRIND_AUDNZD_ALT',
  'GRIND_AUDNZD_ALTB',
  'GRIND_AUDNZD_ALTC',
  'GRIND_AUDNZD_ALTD',
  'GRIND_AUDNZD_OPT',
  'GRIND_AUDNZD_OPTB',
  'GRIND_AUDNZD_OPTC',
  'GRIND_AUDNZD_OPTD',
  'GRIND_CADCHF_ALT',
  'GRIND_CADCHF_ALTD',
  'GRIND_CADCHF_ALTE',
  'GRIND_CADCHF_OPT',
  'GRIND_CADCHF_OPTB',
  'GRIND_CADCHF_OPTC',
  'GRIND_CADCHF_OPTD',
  'GRIND_CADCHF_OPTE',
  'GRIND_EURGBP_ALT',
  'GRIND_EURGBP_ALTD',
  'GRIND_EURGBP_ALTE',
  'GRIND_EURGBP_OPT',
  'GRIND_EURGBP_OPTB',
  'GRIND_EURGBP_OPTC',
  'GRIND_EURGBP_OPTD',
  'GRIND_EURGBP_OPTE',
  'GRIND_EURUSD_ALT',
  'GRIND_EURUSD_ALTC',
  'GRIND_EURUSD_ALTD',
  'GRIND_EURUSD_ALTE',
  'GRIND_EURUSD_OPT',
  'GRIND_EURUSD_OPTB',
  'GRIND_EURUSD_OPTC',
  'GRIND_EURUSD_OPTD',
  'GRIND_EURUSD_OPTE',
  'GRIND_GBPCHF_ALTC',
  'GRIND_GBPCHF_OPTC',
  'GRIND_GBPUSD_ALT',
  'GRIND_GBPUSD_ALTD',
  'GRIND_GBPUSD_ALTE',
  'GRIND_GBPUSD_OPT',
  'GRIND_GBPUSD_OPTB',
  'GRIND_GBPUSD_OPTC',
  'GRIND_GBPUSD_OPTD',
  'GRIND_GBPUSD_OPTE',
  'GRIND_NZDCAD_ALT',
  'GRIND_NZDCAD_ALTB',
  'GRIND_NZDCAD_ALTC',
  'GRIND_NZDCAD_ALTD',
  'GRIND_NZDCAD_OPT',
  'GRIND_NZDCAD_OPTB',
  'GRIND_NZDCAD_OPTC',
  'GRIND_NZDCAD_OPTD',
  'GRIND_NZDCHF_OPT',
  'GRIND_NZDCHF_OPTB',
  'GRIND_NZDCHF_OPTC',
  'GRIND_NZDCHF_OPTD'
)
$i = 0
foreach ($id in $ids) {
  $i++
  $f = Join-Path $out ("sends_" + $id + ".jsonl")
  if (Test-Path -LiteralPath $f) { "SENDS|SKIP|$id|exists"; continue }
  railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --export-sends --instance $id | Out-File -Encoding utf8 $f
  $n = (Get-Content -LiteralPath $f | Measure-Object -Line).Lines
  "SENDS|$i/$($ids.Count)|$id|lines $n"
}
"SENDS|DONE|$($ids.Count) instances"

