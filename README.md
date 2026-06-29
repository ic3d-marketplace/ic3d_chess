# ic3d_chess

Realistic, fully **in-world 3D** chess for FiveM using the **bzzz_chess** prop pack.
Walk up to a table, sit down, and move the real pieces with your mouse — no 2D
chessboard overlay. Play head-to-head against another player, or solo against a
built-in computer opponent (3 difficulty levels).

---

## Features

- Physical chess tables spawned at configurable map locations (table, board,
  chairs — all from the `bzzz_chess` pack).
- **Pure 3D play**: overhead camera when seated, mouse-driven pick-and-place /
  drag-and-drop directly on the real pieces, 3D highlight markers for the
  selected piece, legal moves, captures and the last move.
- **2-player PvP**: one player sits as White, another joins as Black.
- **Vs Computer**: play alone against an AI (easy / medium / hard).
- A full, rules-correct chess engine — castling, en passant, promotion,
  check / checkmate / stalemate, 50-move and insufficient-material draws.
  *(Verified with `perft` to depth 5 and cross-checked against `python-chess`,
  including the Kiwipete / en-passant / promotion test positions.)*
- Captured pieces stack neatly beside the board.
- A native GTA **scaleform result card** (victory / defeat / draw) at the end.
- Seated player & opponent animations (from `bzzz_chess/data/anim.txt`).
- Nearby players see the game update live in the world.
- `ox_target` interaction, with an automatic `[E]` fallback if it isn't installed.

- **Modern styled UI**: the start menu and the on-screen HUD (player names,
  keybinds and a live chess clock for both sides) reuse the AFK-Farms look and
  components.
- **Chess clock** for both players (configurable time + increment); running out
  of time loses the game.
- **ELO ranking & leaderboard** with chess.com-style title tags (Novice →
  Grandmaster). PvP games are rated; the leaderboard is reachable from the
  start menu, and your current rating shows in the menu. Requires `oxmysql`
  (auto-creates the `ic3d_chess_ratings` table). Configure in `Config.Ranking`.
- **Choose your side** (White / Black / Random) when starting any match.
- **Money betting** on PvP matches — pick a stake, both players match it, and
  the winner takes the pot (draws are refunded). Configure in `Config.Betting`.
- **Orbiting camera while waiting** for an opponent, so you can see yourself
  seated at the table. Tunable in `Config.Camera.waitOrbit`.
- Multi-step match setup with **Back / Exit** navigation.

## Controls (while seated)

- **Mouse** — the real cursor is shown; point it at a square.
- **Left click / hold** — pick up a piece, then click (or drag) onto a
  highlighted square to move it.
- **Backspace** — stand up (leaving an active PvP game counts as resigning).

Tunables in `config.lua`: `Config.Camera` (overhead view), `Config.Clock`
(time control), `Config.Marker` (the floor prompt marker), `Config.Seats[...].ped`
(sit height), and `Config.Interact` (`'textui'` AFK-style prompt or `'target'`).

---

## Installation

1. Make sure the prop pack **`bzzz_chess`** is installed and started.
2. Drop `ic3d_chess` into your resources folder.
3. Add to `server.cfg` (after `ox_lib` and `bzzz_chess`):

   ```cfg
   ensure ox_lib
   ensure bzzz_chess
   ensure ic3d_chess
   ```

4. Restart the server.

### Dependencies
- `ox_lib`
- `bzzz_chess` (the prop pack)
- A framework (ESX / QBCore / Qbox) — optional, only used for names & rewards
- `ox_target` — optional (auto-detected; `[E]` marker used otherwise)

---

## Configuration

Everything lives in `config.lua`:

- `Config.Locations` — where the chess tables spawn in the world.
- `Config.NPC` — enable/disable the computer, difficulty search depths, think time.
- `Config.Rewards` — optional payout to the winner (uses the bridge `RewardPlayer`).
- `Config.BoardOffset` — fine-tune the board height on the table if needed
  (default `vector3(0, 0, 0.40)`, taken from `bzzz_chess/data/offsets_table.lua`).
- `Config.Locale` — `'en'` or `'pt'`.

Admin command: `/chessreset [tableId]` — force-reset one or all tables
(requires admin per the bridge `IsAdmin`).

---

## How a game works

1. Walk up to a chess table and interact (ox_target or `[E]`).
2. Choose **Play vs Player** (you sit as White and wait), **Play vs Computer**
   (pick a difficulty), or **Join as Black** at a table that's waiting.
3. You sit down and the overhead camera takes over. Move pieces with the mouse —
   the moves are validated server-side, and the physical pieces update in real
   time for everyone nearby.
4. The game ends on checkmate / stalemate / draw / resignation; a result card is
   shown and the board resets shortly after.
