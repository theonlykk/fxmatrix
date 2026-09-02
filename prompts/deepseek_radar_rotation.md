# DeepSeek Audit — Radar Approach: Rotation Frequency vs Performance

## Role
You are the Red Team auditor for FXMatrix, a native MQL5 EA.
Identify the mechanical flaw in the Radar approach causing
regression vs the no-Radar baseline, and propose a minimal fix.

## Performance comparison

Without Radar: +$387.86, PF 20.11, 324 trades, 90.74% win rate
With Radar v2: +$137.75, PF 2.85,  202 trades, 78.22% win rate

## Log evidence

Radar rotates between GBPUSD and EURUSD every 1-5 bars:
13:25 — placed GBPUSD BUY  dislocation=0.001386
13:30 — placed EURUSD SELL dislocation=0.000814 (cancelled GBPUSD)
13:35 — placed GBPUSD BUY  dislocation=0.001386 (cancelled EURUSD)

Each rotation cancels a valid limit before it fills.

## Questions

1. Is rapid rotation the mechanical cause of regression?

2. Minimal fix — which option:
   a. Rotation dampener: only rotate if new dislocation exceeds
      current by 20%+ margin
   b. Minimum holding bars: hold N bars before rotation allowed
   c. Hysteresis: cancel only if dislocation falls below
      threshold x (1 - hysteresis_factor)
   d. Abandon Radar: no-Radar is structurally superior

3. Mathematical argument for why commit-and-hold outperforms
   best-case-hunting in mean reversion specifically?

4. Any other flaws in the Radar logic?

Propose minimal fix with exact implementation guidance.
No architectural changes.