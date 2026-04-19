# COREX Framework

> A modern FiveM framework for Zombie Survival gameplay — built on a simple table architecture with StateBag synchronization, Lua 5.4, and oxmysql.

---

## Features

- **Simple Table Architecture** — no OOP, all operations via `Corex.Functions`
- **StateBag sync** instead of network events
- **Tetris grid inventory** (corex-inventory)
- **Character creation & spawn flow** (corex-spawn)
- **Dynamic weather & time** (corex-weather)
- **Death/respawn system** (corex-death)
- **Crafting system** (corex-crafting)
- **HUD overlay** (corex-hud)
- **Core player, money, metadata & persistence** (corex-core)

---

## Requirements

| Dependency | Version |
|---|---|
| FiveM Server Artifact | latest recommended |
| MySQL / MariaDB | 5.7+ / 10.4+ |
| [oxmysql](https://github.com/overextended/oxmysql) | latest |
| Lua | 5.4 (set per resource) |

---

## Installation

### 1. Clone the repo

```bash
git clone https://github.com/<your-user>/COREX-Framework.git
cd COREX-Framework
```

### 2. Install the FiveM server binary

The `FXServer/` folder is **not** included in this repo. Download it from:
<https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/>

Extract it to `FXServer/` at the project root.

### 3. Configure the server

```bash
cp server-file/server.cfg.example server-file/server.cfg
```

Edit `server-file/server.cfg` and set:
- `sv_licenseKey` — generate at <https://keymaster.fivem.net/>
- `mysql_connection_string` — your MySQL credentials
- `add_principal` — your FiveM/Discord identifiers for admin access

### 4. Set up the database

Create a database named `corex` and import the schema:

```bash
mysql -u root -p corex < server-file/resources/[corex]/corex-core/sql/corex_framework.sql
```

### 5. Start the server

```bash
FXServer/run.cmd +exec server-file/server.cfg
```

---

## Project Structure

```
COREX_Framework/
├── FXServer/                 # FiveM binary (not in repo — download separately)
├── txData/                   # txAdmin data (not in repo — per-server)
├── docs/                     # Framework documentation
└── server-file/
    ├── server.cfg.example    # Config template (copy to server.cfg)
    └── resources/
        ├── [cfx-default]/    # Default cfx resources
        ├── [standalone]/     # Third-party resources
        ├── [assets]/         # Map / prop assets
        └── [corex]/          # COREX framework resources
            ├── corex-core/       # Player, DB, state management
            ├── corex-spawn/      # Character creation & spawn
            ├── corex-inventory/  # Tetris grid inventory
            ├── corex-weather/    # Weather & time
            ├── corex-death/      # Death / respawn
            ├── corex-crafting/   # Crafting system
            ├── corex-hud/        # HUD overlay
            └── corex-events/     # Global event system
```

---

## Core API — Quick Reference

### Server-side

```lua
local player = Corex.Functions.GetPlayer(source)
local name   = player.name
local cash   = player.money.cash

Corex.Functions.AddMoney(source, 'cash', 500)
Corex.Functions.RemoveMoney(source, 'bank', 100)
Corex.Functions.SetMetaData(source, 'hunger', 100)
Corex.Functions.SavePlayer(source)
```

### Client-side

```lua
local data = Corex.Functions.GetPlayerData()
local cash = Corex.Functions.GetMoney('cash')
local skin = Corex.Functions.GetMetaData('skin')
```

### Using COREX from another resource

```lua
-- fxmanifest.lua
dependencies { 'corex-core' }

-- main.lua
local Corex = exports['corex-core']:GetCoreObject()
local player = Corex.Functions.GetPlayer(source)
```

Full documentation lives in [`docs/`](docs/).

---

## Development Rules

This repo enforces strict rules (see [`CLAUDE.md`](server-file/resources/CLAUDE.md)):

1. **Never call FiveM natives directly** — use `Corex.Functions.*`
2. **Missing function?** Add it to `corex-core` first, then use it
3. **No duplication** — reuse core logic
4. **Lua 5.4 compliant**, modular, defensive
5. **UI must follow** the Anti-Default Protocol (premium fonts, Bento grid, micro-interactions)

---

## Contributing

1. Fork the repo
2. Create a branch: `git checkout -b feat/my-feature`
3. Follow the architecture rules in `CLAUDE.md`
4. Commit with conventional style: `feat:`, `fix:`, `refactor:`, `docs:`
5. Open a Pull Request

---

## License

Private repository — all rights reserved until explicitly open-sourced.
