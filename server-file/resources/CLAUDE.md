# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Framework Overview

COREX is a FiveM framework for Zombie Survival games built with:
- **Simple Table Architecture** - No OOP, uses Corex.Functions for all operations
- **StateBag Synchronization** instead of network events for data sync
- **Lua 5.4** and **oxmysql** for database operations

## Resource Structure

```
[corex]/
├── corex-core/      # Foundation (Player class, DB, state management)
├── corex-spawn/     # Character creation & spawning
├── corex-inventory/ # Tetris grid inventory system
└── corex-weather/   # Dynamic weather & time
```

**Load Order:** `oxmysql` → `corex-core` → other corex resources

## Core Architecture Patterns

### Simple Player Table (server/players.lua)

```lua
-- Player is a simple table (NO OOP)
{
    source = 1,
    identifier = "license:abc123",
    name = "PlayerName",
    money = {cash = 0, bank = 0},
    metadata = {},
    _loaded = true
}
```

Access players via: `COREX.Functions.GetPlayer(source)` returns simple table

### StateBag Sync (No TriggerClientEvent)

Server syncs data via StateBag:
```lua
Player(self.source).state:set('money', self.money, true)
```

Client listens automatically:
```lua
AddStateBagChangeHandler('money', playerBag, function(bagName, key, value)
    PlayerData.money = value
    TriggerEvent('corex:client:moneyChanged', value)
end)
```

### Metadata System

Flexible key-value storage for any player data:
```lua
COREX.Functions.SetMetaData(source, 'skin', skinData)
COREX.Functions.SetMetaData(source, 'lastPosition', {x=0, y=0, z=0, heading=0})
COREX.Functions.SetMetaData(source, 'hunger', 100)
```

## Key APIs

### Server-Side

```lua
-- Get player (simple table, not OOP)
local player = COREX.Functions.GetPlayer(source)
local name = player.name
local money = player.money.cash

-- Use Corex.Functions for operations (NOT methods)
Corex.Functions.AddMoney(source, 'cash', 500)
Corex.Functions.RemoveMoney(source, 'bank', 100)  -- Returns false if insufficient
Corex.Functions.SetMetaData(source, key, value)
Corex.Functions.GetMetaData(source, key)
Corex.Functions.GetPlayerName(source)
Corex.Functions.SavePlayer(source)
```

### Client-Side

```lua
Corex.Functions.GetPlayerData()
Corex.Functions.GetMoney('cash')
Corex.Functions.GetMetaData('skin')
Corex.Functions.WaitForPlayerData(timeout)
```

## Server Events

```lua
-- Player lifecycle
AddEventHandler('corex:server:playerReady', function(source, player) end)
AddEventHandler('corex:server:playerDropped', function(source, player, reason) end)

-- Data changes
TriggerEvent('corex:server:playerMoneyChanged', source, type, oldAmount, newAmount, action)
TriggerEvent('corex:server:playerMetaDataChanged', source, key, newValue, oldValue)
```

## Database

Uses oxmysql. Connection string in server.cfg:
```cfg
set mysql_connection_string "mysql://user:pass@localhost/corex?charset=utf8mb4"
```

**Players table schema:**
```sql
CREATE TABLE players (
    id INT AUTO_INCREMENT PRIMARY KEY,
    identifier VARCHAR(60) NOT NULL UNIQUE,
    name VARCHAR(50) NOT NULL,
    money LONGTEXT,      -- JSON: {"cash": 0, "bank": 0}
    metadata LONGTEXT    -- JSON: skin, position, stats, etc.
);
```

## Debug System

```lua
COREX.Debug.Error(msg)    -- Level 1
COREX.Debug.Warn(msg)     -- Level 2
COREX.Debug.Info(msg)     -- Level 3
COREX.Debug.Verbose(msg)  -- Level 4
```

Enable in `config.lua`: `Config.Debug = true`

## Creating Resources That Use COREX

```lua
-- Get Corex object
local Corex = exports['corex-core']:GetCoreObject()

-- Use functions (NOT methods)
local player = Corex.Functions.GetPlayer(source)
if player then
    local name = player.name  -- Direct table access
    Corex.Functions.AddMoney(source, 'cash', 100)  -- Use functions for operations
end

-- fxmanifest.lua
dependencies { 'corex-core' }
```

## Player Lifecycle Flow

1. `playerConnecting` → Load data from DB
2. `corex:player:loaded` (client) → Create PlayerClass instance
3. `corex:server:playerReady` → Other resources react (e.g., spawn)
4. `playerDropped` → Auto-save and cleanup

## Critical Implementation Notes

- **NO OOP**: Player is a simple table, use `Corex.Functions` for ALL operations
- **StateBag handlers** must register AFTER `NetworkIsPlayerActive()` returns true
- **Server ID validation**: `GetPlayerServerId(PlayerId())` can return 0 if called too early
- Auto-save runs every 5 minutes for all players
- All money operations validate and return boolean success
- Use `COREX.Functions` (global) or `Corex.Functions` (exported) - both work

---

# STRICT DEVELOPMENT RULES

## Code Style & Comments

**Comment Policy:**
- Avoid excessive comments
- Only add comments to explain complex logic or non-obvious algorithms
- Prefer clean, self-explanatory code with descriptive variable/function names
- **NO decorative comments** (e.g., `-- ==========`, `-- TODO: maybe`, `-- this is a function`)
- **NO obvious comments** (e.g., `-- increment counter` above `counter = counter + 1`)

## COREX Framework Architecture Rules

**MANDATORY - You MUST follow these rules at all times:**

### 1. Always Use COREX Core Exports
- **DO NOT use FiveM natives directly** in resource code
- Prohibited natives: `PlayerPedId()`, `GetEntityCoords()`, `Wait()`, `IsPedInAnyVehicle()`, etc.
- **USE:** `Corex.Functions.GetPed()`, `Corex.Functions.GetCoords()`, `Corex.Functions.IsInVehicle()`

### 2. Missing Functions Must Be Added to Core First
If a needed function doesn't exist in corex-core:
1. **STOP** - Do not use FiveM native as a workaround
2. Create the function in `corex-core/client/main.lua` or `corex-core/server/*.lua`
3. Export it properly in `fxmanifest.lua`
4. Then use it in the target resource

### 3. Never Duplicate Core Logic
- Before implementing any common functionality, check if it exists in corex-core
- Common functions: player management, coords, health, vehicles, notifications, callbacks
- If similar logic exists, **refactor and reuse** instead of copying

### 4. Code Quality Standards
All code MUST be:
- **Lua 5.4 compliant** (use `lua54 'yes'` in fxmanifest)
- **Modular** - small, focused functions with single responsibility
- **Defensive** - validate all inputs, handle nil cases, use pcall for risky operations
- **No global pollution** - use `local` for all variables, avoid creating globals

### 5. Response Requirements
Every code response MUST include:

**Code Blocks:**
```lua
-- Proper markdown formatting for ALL Lua code
-- Use syntax highlighting
```

**Self-Review Section:**
```markdown
## Self-Review
**What was reviewed:**
- [List specific files/functions checked]

**Edge cases considered:**
- [List potential error cases and how they're handled]

**COREX compliance:**
- ✅ No FiveM natives used directly
- ✅ All functions use Corex.Functions.*
- ✅ Input validation implemented
- ✅ Error handling with pcall/fallbacks
```

### 6. FiveM Native Usage (Last Resort Only)
If FiveM native usage is absolutely unavoidable:
1. **Explain exactly why** the native is required
2. Add a `-- TODO: Move to corex-core export` comment
3. Show how the export should be implemented

Example:
```lua
-- TODO: Move to corex-core export
-- TEMPORARY: Using native until Corex.Functions.GetVehicleProperties() is implemented
local props = GetVehicleProperties(vehicle)

-- Proposed export:
-- function Corex.Functions.GetVehicleProperties(vehicle)
--     -- Full vehicle data extraction
--     return { plate, color, mods, ... }
-- end
```

### 7. Engineering Standards
- **No weak, careless, or unreviewed code**
- Act as a **senior framework engineer** at all times
- Think about maintainability, performance, and scalability
- Consider multiplayer synchronization and race conditions
- Always handle resource restarts gracefully

---

# UI/UX Design Standards

When creating or modifying UI (NUI, HTML/CSS/JS):

## Anti-Default Protocol

**🚫 STRICTLY PROHIBITED:**
- Generic fonts: Inter, Roboto, Open Sans, Segoe UI
- Default colors: Bootstrap blue, pure black (#000)
- Heavy drop shadows or generic CSS shadows
- Empty white space in cards/panels

**✅ REQUIRED:**
- Premium variable fonts: Geist, Satoshi, or custom font stacks
- Nuanced color palettes: Slate, Zinc, Carbon, Indigo/Violet
- Subtle borders (`border-white/10`) or soft glows for depth
- High-density layouts - every pixel serves a purpose

## Layout Philosophy: "Bento Grid"

**The "Anti-Hollow" Rule:**
Never leave a card empty. Fill white space with:
- Micro-charts (sparklines, trend graphs)
- Trend indicators ("+12% vs last week" with icons)
- Metadata tags (Status, Role, ID, timestamps)
- Actionable micro-buttons (Copy, Edit, View, Delete)

**Grid Standards:**
- Strict grid alignments (8px/16px baseline)
- Think "Financial Terminal meets Modern SaaS"
- Balance density with readability

## Micro-Interactions & Polish

**Mandatory Feedback:**
- Every interactive element MUST have `:hover` and `:active` states
- Smooth transitions (150-200ms ease-in-out)
- Glass morphism: `backdrop-blur-md` + `bg-opacity` for depth

**Data Visualization:**
- Never show raw numbers alone
- Always pair with context: progress bar, trend arrow, mini-graph
- Use color to indicate state (success/warning/error)

## UI Pre-Flight Checklist

Before generating UI code, verify:
1. **Is this card too empty?** → Add micro-chart or metadata
2. **Does this look like Bootstrap?** → Change font stack, tighten spacing
3. **Are interactions defined?** → Add hover/active states
4. **Is data contextualized?** → Add visual indicators

---

# Debugging Workflow

When a bug, error, or unexpected behavior is reported:

## 1. Clarify and Restate
- Restate the bug in your own words
- Ask for missing details: exact steps, inputs, expected vs actual behavior, environment
- Request logs, stack traces, screenshots if available
- **DO NOT change code before understanding the problem**

## 2. Localize the Bug
- Identify minimal set of files/functions likely involved
- Search codebase for relevant symbols, routes, commands, events
- List most likely related components

## 3. Form Hypotheses Before Editing
- List 3-5 plausible root causes
- Explain reasoning for each
- Choose 1-2 most likely causes
- Design simple experiments: extra logs, guard checks, targeted tests

## 4. Instrument and Test
- Add lightweight logging/assertions instead of large refactors
- Show exact files/lines to edit
- Apply minimal changes
- Run relevant commands/tests
- Analyze output and explain what's confirmed/ruled out

## 5. Propose Focused Fix
- Once root cause is clear, propose smallest safe code change
- Explain fix in plain language
- Show why it works and which edge cases it covers
- Provide tightly scoped diffs/code blocks

## 6. Verify and Prevent Regressions
- Re-run failing scenario and related tests
- Add/update tests to prevent silent reappearance
- Point out similar patterns elsewhere that may need checking

## 7. Communication Style
- Present short plan before changing code
- Execute step by step
- If information missing, stop and ask precise questions instead of guessing
- Keep explanations concise but concrete

---

# Quality Checklist

Before submitting any code, verify:

**Architecture:**
- [ ] Uses Corex.Functions.* instead of FiveM natives
- [ ] No logic duplication from corex-core
- [ ] Proper resource initialization (waits for COREX)
- [ ] Graceful handling of resource restarts

**Code Quality:**
- [ ] All variables are `local` scoped
- [ ] Input validation on all public functions
- [ ] Error handling with pcall or nil checks
- [ ] No global pollution

**Performance:**
- [ ] No tight loops without Wait()
- [ ] Efficient StateBag usage (no spam)
- [ ] Database queries are batched/optimized
- [ ] UI rendering is throttled/debounced

**Documentation:**
- [ ] Complex logic has explanatory comments
- [ ] No decorative/obvious comments
- [ ] Function purpose is clear from name
- [ ] Self-review section included in response
