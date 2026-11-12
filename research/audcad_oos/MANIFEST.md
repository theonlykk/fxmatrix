This message has a line count at the bottom

# AUDCAD OUT OF SAMPLE -- MANIFEST (11 Nov 2026)

| | |
|---|---|
| The new data | `bars_1514878887_AUDCAD.csv`, **123,183,334 bytes, sha256 `0f618c4c0816613ef72d5f81f1aa0c0e54efcaa7409110ac6d780cfe829887a1`**. On the desktop at `D:\fxmatrix-exports\bars_ftmo_2018\` (its own folder: the name is the same as the 2023-2026 file's). |
| How made | `scripts/grind_bar_dump.mq5` on the desktop terminal, 18:58 EST 11 Nov: `InpSymbols = AUDCAD`, `InpFrom = 2018.01.01 00:00`, `InpTo = 2023.01.01 00:00`. Printed `BARDUMP|AUDCAD|n=1854026|first=2018.01.02 00:02|last=2022.12.30 23:54`. |
| Feed | FTMO-Demo (account 1514878887), the in-sample feed: PREREG s2's first choice; 60 months, so no IC fall-back. |
| Header (line 1, the only line read before the self-checks) | `# symbol=AUDCAD account=1514878887 server=FTMO-Demo digits=5 point=0.00001000 server_minus_gmt_s=0 from=2018.01.01 00:00 to=2023.01.01 00:00` |
| Note | **`server_minus_gmt_s=0` is an artefact:** the terminal was not connected (the bars came from its stored FTMO history), so it could not know the server's offset. The bar times are the server clock, as in the 2023-2026 file (whose header says 10800). Nothing in the engine reads the header's offset. |
| The in-sample file | `D:\fxmatrix-exports\bars_ftmo\bars_1514878887_AUDCAD.csv`, 93,922,653 bytes, sha256 first 16 `b8eccff28a6bcad0`: re-hashed 11 Nov after the export, unchanged (`research/longrun/MANIFEST.md`). |
| The control's references | Fable's `04_ladder_cells_cont.csv` (sha256 first 16 `63052ba31b142d92`) and `04_ladder_cells_one.csv` (`d224418cff16c238`), `D:\fxmatrix-exports\fable_review\out\` (`reviews/fable_pass1/MANIFEST.md`). |
| Reviews | Argon 1 (`review/argon-audcad-oos`, `15c7a6e`): failed its quote check (29 of 122), changes checked and taken (s93j). **Argon 2 (`review/argon-audcad-oos-2`, `9250f33`): 305 lines, 134 of 136 quotes exact (the other two real text cited one line late), all five amendments and all seven items CONFIRMED: SOUND.** |

Line count: 16
