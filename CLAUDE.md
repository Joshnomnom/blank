# Project: Car MMORPG (working title "Wasteland Drive")

Godot 4.7.2 · GDScript · Compatibility renderer · web-first.

## Start of every session and every request
1. Read `docs/DEVLOG.md`, starting with **Current Status**.
2. Use `docs/GAME_DESIGN.md` for the big picture.
3. Check `docs/research/` for research already done before researching again.

## DOCUMENTATION RULE (mandatory, every request)
Nothing is finished until it's written down. Sessions can end at any time (stopping work, running out of credits), so the docs must always be enough to pick up cold.

- **After any code change, decision, test feedback, or progress:** update `docs/DEVLOG.md`:
  - **Current Status** (phase, state, waiting on, next step)
  - **Session Log**: add to the current session entry (date, decisions, done, not done, open questions). The newest session goes at the top.
  - **Project Structure** and **How Systems Work**: keep them in sync with the code (new files, changed values, new systems).
- **After any research:** write the findings in detail to `docs/research/<TOPIC>.md`. Include the math, values, techniques, sources and a "what this means for our game" section. Link it from DEVLOG Current Status and the session log. Never leave research only in chat.
- **When the design changes:** update `docs/GAME_DESIGN.md`.
- **When the user gives feedback on feel or bugs:** record it in the DEVLOG session log, quoted or summarized, so later tuning knows why values changed.
- Update the docs in the **same turn** as the work, not "later".

## Working rules
- **One step at a time.** Build only the step the user asked for, then stop and report. Don't start the next phase without the user's go-ahead.
- **Use usage credits sparingly.** Prefer a few standard web searches over many. Don't spawn agents unless needed.
- Godot is not on PATH, so code can't be run from the terminal. Say clearly that changes are untested until the user reports back.

## Code conventions
- GDScript only. Placeholder art is built in code. Input actions are registered in `scripts/core/input_setup.gd`.
- Tunable gameplay values go in `@export` variables.
- Cars face −Z.
- Physics layers: 1 = solid (walls, ramps; car body collides), 2 = ground (terrain; only the car's wheel rays touch it). Ramps use 1+2. New world geometry must follow this, or the car chassis can get stuck on the ground.
