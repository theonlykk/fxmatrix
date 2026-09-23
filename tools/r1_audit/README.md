# DeepSeek R1 audit runner

Per-audit inputs live in `prompts/<audit>_config.json`. Do not edit
`r1_audit.py` for each audit.

The API key is read from `D:\candlelab\.env` (override the file with
`R1_ENV_FILE`). Never copy the key into this repo.

## Commands

Dry run (no API call):

```
D:\candlelab\venv\Scripts\python.exe tools\r1_audit\r1_audit.py --config prompts\<audit>_config.json --dry-run
```

Real audit:

```
D:\candlelab\venv\Scripts\python.exe tools\r1_audit\r1_audit.py --config prompts\<audit>_config.json
```
