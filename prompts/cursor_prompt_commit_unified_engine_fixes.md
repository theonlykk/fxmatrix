This message has a line count at the bottom.

TASK: Stage and commit the parity-verified Unified V2 Engine
implementation, now that both real bugs (BC bc_now, AB ArrayCopy)
are fixed and confirmed via full three-pair parity testing.

CONTEXT
All implementation files have been sitting uncommitted per standing
practice (review before committing). They're now reviewed and proven:
GBPUSD 4/5 windows exact match, EURUSD 5/5, EURGBP 4/4 (all runnable
windows), both real bugs found and fixed with confirmed root causes.
This commits the working code — it does NOT authorize cutover, which
remains pending vaccine_rally GUI verification and the Layer 4 demo
drill per Gemini's ruling.

OBJECTIVE

STEP 1 — Categorized scope review (standing practice)
Run git status and produce the categorized report: group (a) files
clearly part of the unified engine implementation (all Phase A/B
files, the fixes applied during parity investigation, ADR-104, the
extended fxmatrix_v2_tests.mq5 additions), group (b) everything else,
explicitly enumerated. Do not stage anything yet.

STEP 2 — Confirm scope with the known pre-existing dirty state
Cross-check group (b) against the already-known pre-existing dirty
files (5 ref-variant files, other M-but-empty-diff files) — these
must NOT be staged. Flag anything unexpected in group (b) before
proceeding.

STEP 3 — Stage exactly the confirmed unified-engine file list
By exact name, not git add . or git add -u.

STEP 4 — Commit
Message documenting what this actually is:

Unified V2 Engine: Phase A/B implementation, parity-verified (GBPUSD/EURUSD/EURGBP)

- Phase A: pair preset struct, per-pair fragments, cap-bridge
  declarations, pure L0 signal core (BC + AB paths)
- Phase B: shared engine body (pair-agnostic, linter/grep-verified),
  three thin shells, extended test suite, ADR-104
- Bug fix: BC bc_now reverted to match production's genuinely
  unguarded half-spread calculation (was incorrectly guarded)
- Bug fix: AB path ArrayCopy-into-struct removed, arrays now passed
  by reference (mirrors the BC fix) — resolved a 16-pip bar-zero
  divergence on EURGBP
- Parity gate results: GBPUSD 4/5 windows exact match (vaccine_rally
  deferred, headless infra issue), EURUSD 5/5, EURGBP 4/4 all
  runnable windows exact match
- Does NOT authorize production cutover — pending vaccine_rally GUI
  verification (GBPUSD/EURGBP) and a live/demo Layer 4 halt-gate
  drill per Gemini's ruling, 2026-08-03

STEP 5 — Push
Push to origin main. Report the resulting commit hash.

NEGATIVE SPACE
Stage only the confirmed unified-engine file list. Do not touch any
production file. Do not touch the pre-existing dirty _ref/temp files.
No VPS interaction.

FAILURE MODES
If group (b) contains anything unexpected, stop and report before
staging anything.

SELF-REVIEW
Confirm: categorized scope report produced first; only confirmed
unified-engine files staged; commit created with the message above;
push succeeded; commit hash reported.

Line count: 72
