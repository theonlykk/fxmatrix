# PARKED IDEA: V2 Broker-Position Reconciliation on Startup

**Status: PARKED — not scheduled, not scoped for implementation. Operational workaround (deploy only when flat) in use today.**

**Author:** Claude, written up from a live finding during ADR-092 exit-mechanism deployment.
**Date:** 2026-07-15

---

## 1. The finding that motivated this

While preparing to deploy the rebuilt exit mechanism (resting pending limits + CloseBy, replacing SLTP) to the VPS, a diagnostic confirmed: **`fxmatrix_v2.mq5`'s `OnInit()` does not scan existing broker positions and rebuild its in-memory layer state (`g_long_layers[]`/`g_short_layers[]`) from them.** Both the old SLTP build and the new exit-limit build share this gap — it is not new, and not specific to today's rebuild.

**Practical consequence:** if the EA is detached, recompiled, or the terminal reloads it while real positions are open, it restarts believing it is completely flat. No exit orders get placed for the existing stack, no reload/add logic targets it, telemetry reports zero layers, and the positions sit **completely unmanaged** — invisible to the EA's own logic — until manually closed or some reconciliation mechanism exists to re-adopt them. This was caught **before** it happened (a live 5-layer `MM_SHORT_V2` stack was open at the time), not discovered after the fact.

## 2. Why V1 doesn't have this problem

`FXMatrix.mq5` has a full persistence and reconciliation path V2 was never given: `LoadGlobalState()`, `LoadInventoryState()` (per-slot, from `fxmatrix_state_*.json`/`fxmatrix_global_state_*.json`), and `CheckForOrphans()` — which explicitly **halts** (`INIT_FAILED`) if orphan positions are detected that don't reconcile with loaded state, rather than silently proceeding. V2 has no state files at all (confirmed earlier this session — all V2 state is in-memory only, by deliberate design, for simplicity), and consequently has no reconciliation mechanism to go with it. This wasn't an oversight in ADR-092's original scope — V2 was built stripped-down deliberately — but the *implication* of that simplification (every redeploy requires a flat account) doesn't appear to have been explicitly weighed at the time.

## 3. Why this isn't a one-off inconvenience

This will recur **every time** V2 needs a code update, config change, or restart while any position is open — which, given the pace of iteration on this project so far, could be a frequent constraint, not a rare edge case. The current operational workaround ("wait until the stack returns to flat before deploying") is safe but means deployment timing is dictated by market conditions and stack depth, not by when the engineering work is actually ready.

## 4. Two tiers worth distinguishing, not conflating

**Tier 1 — cheap, high-value, should probably be prioritized ahead of Tier 2: a startup safety check, not a fix.** Mirror the *spirit* of V1's `CheckForOrphans()` without the complexity of full state reconstruction: at `OnInit()`, scan for open positions on this symbol/magic number; if any exist while in-memory layer arrays are empty, **halt and alert loudly** (return `INIT_FAILED`, log a clear error, populate `system_alerts[]`) rather than silently proceeding as if flat. This doesn't solve the underlying problem (still can't hot-swap while positions are open), but it closes the actual danger — the EA would never again silently trade blind next to unmanaged positions; it would refuse to start and force a human to look, exactly the failure mode today's diagnostic was checking for by hand. Low effort, small and well-contained change, arguably should not stay parked as long as Tier 2.

**Tier 2 — larger, genuinely hard, correctly parked: full reconciliation, allowing redeployment while positions are open.** This requires reconstructing not just *that* positions exist, but the *specific state* needed to resume correct operation: layer order (which position is "top" for LIFO purposes), each layer's exit target (derivable: entry ± 3 pips, assuming `InpExitPips` hasn't changed), but also **path-dependent state that has no persisted record at all** — specifically `current_add_pips` (the running widen-state value, which depends on the pod's full history of first-time adds and reload cycles, not just its current depth — this is exactly the distinction the earlier widen-bug fix was built around) and `last_exit_price`/`last_exit_valid` (whether the pod is mid-reload-cycle). Broker position data alone (entry price, open time, volume) cannot fully determine these without either inference/approximation (risking a repeat of the exact positional-vs-path-dependent bug already caught once) or reintroducing some form of lightweight persisted state that V2 was deliberately built without.

## 5. Open questions

1. Is Tier 1 (halt-on-unexpected-positions) worth building now, ahead of the other parked ideas, given it's a safety guardrail rather than a feature — and given today's diagnostic was itself essentially a manual version of what this check would do automatically?
2. For Tier 2, if ever pursued: would reintroducing minimal persisted state (just enough to reconstruct `current_add_pips`/`last_exit_price`, not V1's full JSON schema) be more tractable and lower-risk than trying to infer path-dependent widen state purely from broker position data after the fact?
3. Should this be scoped as its own ADR given it touches core startup/state-management architecture, or as a smaller addendum given Tier 1 at least is a narrow, contained change?

## 6. Next steps (not started)

- [ ] Decide whether Tier 1 should be built as a near-term safety addition (recommended) versus staying fully parked alongside Tier 2's larger scope.
- [ ] If Tier 1 proceeds: scope the exact halt condition (position count > 0 on this symbol/magic vs. in-memory layer count == 0, at `OnInit()` only, or also checked periodically in case of a mid-session desync) and confirm it doesn't introduce its own false-positive risk (e.g., correctly distinguishing "genuinely orphaned" from "EA is mid-restart and about to legitimately rebuild state via incoming deal events" — though given layers are only ever built via live `OnTradeTransaction` events, not a startup scan, this distinction should be straightforward: if positions exist and the EA has processed zero deal events since this init, they're orphaned by definition).
- [ ] Continue the current operational discipline (deploy only when flat) until at least Tier 1 exists.
- [ ] If Tier 2 is ever pursued: full DeepSeek Phase 1 / Gemini Phase 3 pass, given it touches core state-management architecture and carries real risk of reintroducing a path-dependent-state bug similar to the one already found and fixed once this session.
