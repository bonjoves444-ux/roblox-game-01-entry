# Sunbloom Meadow — Flower Rush

A bright 3D third-person collect-a-thon for Roblox, built for the
make.fun bounty "Make the best Roblox game" (roblox-game-01).

## The game

You are a gardener in a sunny meadow. Run around with WASD or the arrow
keys, walk into glowing yellow **Sunblooms (+10)** and rare pink
**Rainbow Blooms (+50)**, and dodge the green **Thorn Slimes** and the
zig-zagging **Dart Bees**. Each touch costs one of your 3 hearts.

- **3 levels:** Sunny Meadow, Buzzing Field, then the Dusk Garden, where
  the sky darkens and the enemies get faster and more numerous.
- **90 seconds** on the clock for the whole run. Pick the level's goal of
  blooms to advance; clear all three levels to win.
- **HUD:** score, timer, hearts, level and bloom goal across the top,
  a banner for level-ups, a golden "+10" pop on every pickup, and a red
  flash plus a low thud on every hit.
- **Start screen** with the title and how to play, **end screen** with
  win/lose, final score and a Play Again button that restarts the run.

## How it is built

- `src/shared/GameConfig.luau` — every number both sides agree on.
- `src/server/GameState.luau` — the one place the run's state lives.
- `src/server/GameServer.server.luau` — blooms, timer, levels, remotes.
- `src/server/EnemySpawner.luau` — Thorn Slimes and Dart Bees only.
- `src/client/GameHud.client.luau` — the HUD, start and end screens.
- `default.project.json` — the meadow itself, built by Rojo 7.7:
  `rojo build default.project.json --output game.rbxl`.
- `main.ts` — hands the game in: copies `game.rbxl`, `src/`,
  `screenshots/` and `PLAY.json` to `$MAKEFUN_OUTPUT_DIR` and writes
  `dossier.json` with the kit's `buildDossier`.

## Status

`PLAY.json` still holds the starter's zeros until the experience is
published as Public on Roblox; the screenshots are the starter's
placeholders until real Studio captures replace them. Do not submit
before both are real.
