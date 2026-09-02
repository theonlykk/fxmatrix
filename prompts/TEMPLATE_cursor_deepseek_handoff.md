# Template — DeepSeek → Cursor Handoff Prompts

**Purpose:** Canonical structure for Claude when drafting Phase 4 Cursor prompts
after DeepSeek Phase 1 (and Gemini Phase 3) are complete.

**Pipeline (ARCHITECT.md):**
```
Phase 1  DeepSeek teardown     — adversarial, zero implementation code
Phase 2  Claude blueprint      — synthesize fixes, draft Cursor prompt
Phase 3  Gemini ruling         — lock design
Phase 4  Cursor one-shot       — implement only after Gemini approval
```

**Naming convention:**
- DeepSeek commission: `prompts/deepseek_[topic].md`
- DeepSeek response:   `prompts/deepseek_[topic]_response.md`
- Cursor handoff:      `prompts/cursor_[topic].md` or `prompts/cursor_prompt_[topic].md`

---

## Template A — Cursor one-shot (DeepSeek **referenced**)

Use when the DeepSeek prompt and response already live in `prompts/`.
This is the default for full teardowns and multi-round audits.

```markdown
This message has a line count at the bottom.

# Cursor Implementation Prompt — [SHORT TITLE]

## AUDIT TRAIL (mandatory — do not skip)

| Phase | Artifact | Status |
|-------|----------|--------|
| DeepSeek Phase 1 | `prompts/[deepseek_prompt].md` | COMPLETE |
| DeepSeek response | `prompts/[deepseek_response].md` | [CLEARED / OVERRIDE: abort / CONDITIONS] |
| Gemini ruling | [date / ADR-NNN / verbal ruling] | APPROVED |
| Baseline commit | `[hash]` | |

**Binding constraints from DeepSeek (summarize — Cursor must not re-litigate):**
1. [e.g. Path A only; Path B rejected as false-negative risk]
2. [e.g. debounce >=2 consecutive audits before alert fires]
3. [any DeepSeek-mandated caps, bounds, or supplementary checks]

**Gemini overrides (if any):**
- [e.g. floor ships with this change, not deferred]

---

## MANDATORY FIRST STEP

Before editing, read these files and confirm anchor line numbers from the
**current** working tree. Report each back before proceeding:

1. `[path/to/primary/file.mqh]` — function `[Name]()` at line ~NNN
2. `[path/to/test/file.mq5]` — test case `[T-XXX]` at line ~NNN
3. Re-read DeepSeek response section **[THREAT-ID or QUESTION]** — state in
   one sentence what you are implementing.

Do NOT begin editing until anchors are confirmed.

---

## CONTEXT

[2–4 paragraphs: what broke, what we're fixing, why now. Ground in commit
hash and incident details if applicable.]

**In scope:** [files / functions / behaviors]
**Out of scope:** [parked items DeepSeek flagged but Gemini deferred]

---

## THE CHANGE(S)

### Change 1 — [name]

**File:** `[exact path]`

**REPLACE:**
```mql5
[exact before block, or "find block matching ..."]
```

**WITH:**
```mql5
[exact after block]
```

**Why (from DeepSeek/Gemini):** [one sentence — ties to audit finding ID]

### Change 2 — [name]

[repeat as needed]

---

## TESTS / VERIFICATION

- [ ] Compile: `[ea names]` — 0 errors, 0 warnings
- [ ] Unit suite: `[command]` — baseline N/N + new assertions [T-XXX-1..N]
- [ ] Regression gate: [Tier 1 case names / parity window names]
- [ ] Manual: [GUI 0/0, reattach drill, etc. if required]

---

## ADR

Create `docs/architecture/ADR-[NNN].md` documenting:
- Problem (cite DeepSeek finding)
- Decision (what was implemented)
- Rejected alternatives (cite DeepSeek Path B / etc.)
- Verification performed

---

## NEGATIVE SPACE

Do NOT:
- [file / behavior explicitly forbidden]
- Re-litigate [GIVEN from DeepSeek prompt]
- Touch [pre-existing dirty files / production shells / VPS]
- Commit unless explicitly asked

---

## FAILURE MODES

If [unexpected X], stop and report — do not guess.
If scope review finds unexpected files, halt before staging.

---

## SELF-REVIEW

Before commit (if asked): re-read every diff; flag any band-aid, scope creep,
or violation of DeepSeek/Gemini constraints.

Line count: [NN]
```

---

## Template B — Cursor one-shot (DeepSeek **embedded**)

Use for smaller fixes when a separate response file is unnecessary, or when
the audit output is short enough to inline (common for `cursor_patch_*.md`).

Same structure as Template A, but replace the AUDIT TRAIL reference table with:

```markdown
## DEEPSEEK PHASE 1 RULING (embedded — binding)

**Commission:** [one-line scope]
**Verdict:** [CLEARED / CONDITIONS / ABORT]
**Override check:** [last line from DeepSeek output]

### Findings Cursor must implement

| ID | Verdict | Load-bearing claim | Required fix |
|----|---------|---------------------|--------------|
| T-1 | FIXABLE-WITHIN-DESIGN | `V2_Bcc_*` in `fxmatrix_v2_bcc.mqh` | streak >= 2 before alert |
| T-3 | EXPLOIT-FOUND | broker-first scan, not layer-driven | [specific change] |

### Findings explicitly NOT to implement (DeepSeek flagged, Gemini rejected)

- [item]

### Minimal repro / mechanism (preserve for ADR)

[ paste DeepSeek repro verbatim if security-relevant ]

---
```

Then continue with MANDATORY FIRST STEP, CONTEXT, THE CHANGE(S), etc.

---

## Template C — DeepSeek Phase 1 commission

What Claude sends **to** DeepSeek. Save as `prompts/deepseek_[topic].md`.
Cursor either references this file or embeds its ruling (Templates A/B).

```markdown
This message has a line count at the bottom.

# DeepSeek Phase 1 — [Narrow / Full Teardown]: [TITLE]

## Role
Phase 1 Red Team (adversarial quant). **Write ZERO implementation code.**

## Frame (do NOT retail-judge)
[MM thesis, per-side grids, fail-closed halt semantics — only if needed]

## GIVENS (source-verified at commit `[hash]` — do NOT re-litigate)
G1. [resolved fact + file/function]
G2. [...]

## Motivating incident / finding
[what happened, with timestamps/tickets if live]

## The proposal to attack
[spec, blueprint, or mechanism — include source excerpts for existing code]

## Threats / questions (spend effort here)

### T-1 — [PRIMARY]
[DIRECTIVE: prove debounce / construct tamper / etc.]

### T-2 — [SECONDARY]
[...]

## Negative space
- Do NOT write implementation code
- Do NOT re-litigate G1–Gn without concrete proof
- Do NOT judge by retail metrics
- Every exploit needs a minimal repro (tick/fill/crash sequence)

## Required output format

For EACH threat T-N:
- **VERDICT:** EXPLOIT-FOUND / NO-EXPLOIT / DESIGN-UNSAFE
- **LOAD-BEARING CLAIM:** file / function / invariant (checkable in source)
- **MINIMAL REPRO / MECHANISM:** concrete sequence
- **SEVERITY:** fatal-to-premise / fixable-within-design / cosmetic

**OVERRIDE CHECK (last line):** Does any finding invalidate the premise, or
are all findings fixable within the design?

Line count: [NN]
```

---

## When to use reference vs embed

| Situation | Pattern |
|-----------|---------|
| Full teardown (BCC, SRE round N) | **Reference** both prompt + response files |
| Narrow single-question audit (HALT_30 round) | **Reference**; embed only 3–5 binding bullets |
| Small patch after audit (`cursor_patch_*.md`) | **Embed** verdict table + 1–2 findings |
| Gemini cleared, no DeepSeek needed | Omit DeepSeek block; header: `# Gemini cleared — no DeepSeek audit required` |

---

## Sequencing block (optional footer on DeepSeek prompt)

Append to DeepSeek commission or Claude blueprint when helpful:

```markdown
## Sequencing (post-audit)
1. This prompt → DeepSeek ([narrow question only])
2. On clear → Claude drafts Cursor prompt (Template A)
3. Gemini ruling → lock design
4. Cursor implements + ADR + regression gate
5. [Tier 1 / parity / live drill before cutover]
```

---

## Quick header example (copy-paste)

```markdown
# Cursor Implementation Prompt — TA Divergence Debounce After Instant Harvest
# DeepSeek: prompts/deepseek_ta_divergence_harvest_race.md (CLEARED)
# Gemini: APPROVED 2026-08-28 — debounce only, no SRE path
# Baseline: main @ f74a180
```

---

## ARCHITECT.md requirements checklist (Phase 4)

Every Cursor handoff prompt must include:

- [ ] **Negative space** — explicit do-not-touch list
- [ ] **Failure mode handling** — stop conditions, don't guess
- [ ] **Line count bookends** — open + close with exact count
- [ ] **Self-review instruction** — re-read diffs before commit
- [ ] **ADR instruction** — `docs/architecture/ADR-NNN.md` alongside code
- [ ] **Silent Error Test** — if confirmation step can fail silently,
      split into two-step (confirm alone, then implement after review)

---

## Real examples in this repo

| Type | File |
|------|------|
| DeepSeek full teardown | `prompts/DEEPSEEK_TEARDOWN_BCC.md` |
| DeepSeek narrow audit | `prompts/deepseek_phase1_round1_halt30_fix.md` |
| DeepSeek response | `prompts/DEEPSEEK_TEARDOWN_BCC_response.md` |
| Cursor with DeepSeek header | `prompts/cursor_patch_instrument_direction.md` |
| Cursor standalone (Gemini only) | `prompts/cursor_prompt_exit_skew_phase1.md` |
| Post-DeepSeek proposal | `prompts/proposal_v2_depth_triggered_l0_easing_post_deepseek.md` |
