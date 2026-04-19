# COREX Framework — Task Blueprint

> **Source:** Bug reports and enhancement requests — structured for execution.
> **Scope:** `corex-core`, `corex-spawn`, `corex-inventory`, `corex-death`, `corex-events`, zombie AI system.
> **Severity Legend:** `P0` Launch-blocker · `P1` Essential feature · `P2` Polish/Quality.

---

## P0 — Launch-Blocking Bugs (Must fix before release)

### P0-1 · Metadata System Missing in Core
- **Resource:** `corex-core`
- **Problem:** Player survival states are not persisted. When a player disconnects and reconnects, states like hunger, thirst, poisoning, bleeding, and cold are lost.
- **Required Change:**
  - Build a dedicated **metadata layer** inside `corex-core` (lighter than the main data table, separate from `money`/`identifier`).
  - Must persist **only the states that already exist** in the framework (do NOT invent new ones):
    - `hunger`, `thirst`
    - `poisoning` (all existing sub-states: توكسين/تسمم)
    - `cold` (حاله البروده)
    - `bleeding` (حاله النزيف)
    - Any other existing survival state currently tracked at runtime.
  - Save on: player drop, auto-save interval (5 min), and server shutdown.
  - Load on: `playerConnecting` → restore every state to exactly the value it held at disconnect.
  - Expose via: `Corex.Functions.SetMetaData(source, key, value)` and `Corex.Functions.GetMetaData(source, key)` (these already exist — extend the persisted schema).
- **Acceptance:** Player leaves with `hunger = 37`, `bleeding = true` → reconnects → values are identical.

---

### P0-2 · Wrong Spawn Location on Reconnect
- **Resource:** `corex-spawn`
- **Problem:** Reconnecting player is sometimes placed in a location where they were never present — not their last saved position, not the default spawn.
- **Required Change:**
  - On disconnect, save `lastPosition {x, y, z, heading}` to metadata (tied to P0-1).
  - On spawn, load order:
    1. If `lastPosition` exists and is valid → use it.
    2. Else → use character's default spawn from config.
  - Validate coordinates against map bounds before teleporting.
- **Acceptance:** Player always spawns at their exact disconnect position (or config default for new characters). No random/ghost locations.

---

### P0-3 · Death Screen Desync — Player Alive Elsewhere
- **Resource:** `corex-death` + `corex-spawn`
- **Problem:** On death, the death UI appears **but the player is simultaneously teleported to another location as a living character** (default house spawn). Zombies attack this "alive clone" while the death overlay is still showing.
- **Root Cause Hypothesis:** Death handler triggers spawn logic before the respawn button is pressed, or spawn resource doesn't check death state.
- **Required Change:**
  - When player dies: ped must **remain on the ground at the death location**, dead, until the respawn button is clicked.
  - Disable any auto-spawn, auto-teleport, or character-load logic while `isDead = true`.
  - Only after user clicks respawn → execute spawn flow.
  - `corex-spawn` must check death state before running any spawn routine.
- **Acceptance:** Die → body stays on ground → death UI + timer visible → click respawn → THEN teleport to spawn point. No mid-death teleport.

---

### P0-4 · Respawn Button Unclickable (10–20% of deaths)
- **Resource:** `corex-death`
- **Problem:** Occasionally the respawn button does not register clicks when the player dies.
- **Required Change:**
  - Investigate NUI focus state on death — `SetNuiFocus(true, true)` must be called reliably when the death screen opens.
  - Ensure no other NUI element is stealing focus (inventory, chat, HUD).
  - Add a fallback keybind (e.g., `ENTER` or `E`) as a secondary respawn trigger.
  - Add server-side validation: if client sends a respawn request while dead → always honor it.
- **Acceptance:** Respawn button is clickable 100% of the time after death, across 50+ consecutive tests.

---

### P0-5 · Fallen Zombie Sliding Physics
- **Resource:** Zombie AI system
- **Problem:** Fast-type zombie is shot in the leg → falls → but continues **sliding/crawling toward the player while face-down**. Caused by the zombie speed-modifier code that keeps applying velocity even when the ped is ragdolled.
- **Required Change:**
  - In the speed control loop, check `IsPedRagdoll(ped)` / `IsPedFalling(ped)` / `GetPedLastDamageBone` before applying speed multiplier.
  - If ragdolled or fallen → **stop all velocity/speed modifications** until the ped stands up.
  - If a leg bone is destroyed → the zombie should crawl (use proper crawl animation), not slide while lying flat.
- **Acceptance:** Shoot a fast zombie's leg → it falls → does not slide across the ground → either dies, crawls with correct animation, or remains down.

---

### P0-6 · Zombies Fleeing/Screaming Like Humans
- **Resource:** Zombie AI system
- **Problem:** Occasionally (10–30% of encounters), especially during events or heavy gunfire, zombies switch to civilian AI behavior — scream like humans, flee, come back, flee again.
- **Required Change:**
  - Force-set combat attributes on every zombie spawn:
    - `SetPedCombatAttributes(ped, 46, true)` (always fight)
    - `SetPedFleeAttributes(ped, 0, 0)` (never flee)
    - `SetPedCombatAttributes(ped, 17, false)` (never hide)
    - `SetPedCombatAttributes(ped, 5, true)` (always charge)
  - Block all civilian voice lines / ambient speech: `SetAmbientVoiceName` cleared or set to silent, `DisablePedPainAudio(ped, true)`.
  - Periodic check (e.g., every 5s) on active zombies to re-apply attributes in case something resets them.
- **Acceptance:** Zombies NEVER flee. They attack RPGs, tanks, helicopters — anything. Zero human voice lines emitted.

---

### P0-7 · Zombies Spawning in Water / Sky
- **Resource:** Zombie AI system (spawn logic)
- **Problem:** Zombies spawn in the sea (ports, docks, when player is on a ship) and sometimes in the air. They fall into the water and drown, making the framework look broken.
- **Required Change:**
  - Before spawning a zombie at a position, validate:
    1. `GetGroundZFor_3dCoord` returns a valid Z (not water surface).
    2. Position is **not** inside a water volume (`TestProbeAgainstWater` or height check vs. sea level `Z = 0`).
    3. Position has walkable ground (navmesh check).
  - If validation fails → pick another candidate point (retry up to N times, then skip).
  - Add a minimum distance from player (e.g., 30m) and max distance (e.g., 120m).
- **Acceptance:** Stand on a boat → zombies never spawn in the water. Zombies never appear in the sky/falling.

---

### P0-8 · Event Loot Crates Don't Spawn
- **Resource:** `corex-events`
- **Problem:** Some events don't create the loot object at the target location. Player travels to the event, searches, finds nothing — no crate, no visual marker.
- **Required Change:**
  - Verify the object spawn call (`CreateObject`/`CreateObjectNoOffset`) is actually reached in every event branch.
  - Add fallback: if object creation fails → log error server-side + re-attempt once.
  - Add a **flare visual effect** (`RequestNamedPtfxAsset('scr_rcbarry2')` / flare ptfx) on the loot crate so the player can see where it is from a distance.
  - Add a temporary blip on the crate once player enters event radius.
- **Acceptance:** Every event that promises loot always spawns a crate. Player can visually locate the crate via flare.

---

### P0-9 · Events Not Showing on Map
- **Resource:** `corex-events`
- **Problem:** Several events (truck convoy, etc.) never show a blip on the map. Players don't know they exist.
- **Required Change:**
  - Every active event MUST create a map blip when it starts, regardless of type.
  - Blip must include: sprite, color, scale, and short name ("Convoy", "Supply Drop", etc.).
  - Remove blip when event ends or times out.
- **Acceptance:** 100% of events (truck, convoy, supply drop, any other) are visible on the pause map while active.

---

### P0-10 · Notification Ugly Black Background
- **Resource:** `corex-core` HUD / notification layer
- **Problem:** Notifications render with a visible black rectangular background layer behind the actual toast container — makes them look broken.
- **Required Change:**
  - Inspect the notification NUI CSS — remove the parent wrapper's `background-color: black` / `rgba(0,0,0,X)`.
  - Keep only the inner card/container styling.
  - Background of the root notification layer must be fully transparent.
- **Acceptance:** Notifications display cleanly — only the styled card shows, no black rectangle behind it.

---

## P1 — Essential Additions & Core Feature Work

### P1-1 · Event Concurrency Limit (Max 2, Configurable)
- **Resource:** `corex-events`
- **Required Change:**
  - Add `Config.MaxConcurrentEvents = 2` (default) in event config.
  - Event scheduler must check active event count before starting a new one.
  - Expose the value in config for server owners to tune.
- **Acceptance:** Server never runs more than `Config.MaxConcurrentEvents` events simultaneously.

---

### P1-2 · Event UI Repositioning (No Hotbar Overlap)
- **Resource:** `corex-events` NUI
- **Problem:** The event notification panel overlaps with the inventory hotbar (bottom-right slots 1–6 that mirror inventory quick-use).
- **Required Change:**
  - Move the event panel to a dedicated position that never overlaps the hotbar.
  - Recommended: top-right or upper-left area, with clear spacing from HUD elements.
  - Must be clearly visible to the player and non-intrusive during gameplay.
- **Acceptance:** Event panel never touches the hotbar. Both are fully readable simultaneously.

---

### P1-3 · Shop Weapon Replacement — Melee Tools Only
- **Resource:** `corex-inventory` (shop config)
- **Required Change:**
  - **Remove all firearms** from the shop item list.
  - **Add these melee tools** to the shop:
    - `WEAPON_WRENCH`
    - `WEAPON_STONE_HATCHET`
    - `WEAPON_GOLFCLUB`
    - `WEAPON_CROWBAR`
    - `WEAPON_DAGGER`
    - `WEAPON_BAT`
    - `WEAPON_STUNROD`
    - `WEAPON_HATCHET`
  - Each tool must be registered in `corex-inventory/shared/weapons.lua` as **weapon type** (not a generic item) so the player can equip and use it as a weapon.
  - Firearms move to the crafting system (see P1-4).
- **Acceptance:** Shop sells only the 8 listed melee tools. Each one can be equipped and swung. No firearms available for direct purchase.

---

### P1-4 · Firearms Moved to Crafting (Expensive)
- **Resource:** `corex-crafting` (existing resource)
- **Required Change:**
  - Move all firearm recipes to crafting.
  - Recipe cost must scale with weapon tier — basic weapons expensive, high-tier weapons very expensive (exact pricing to be tuned by server owner in config).
- **Acceptance:** Firearms are only obtainable via crafting, with meaningful resource cost.

---

### P1-5 · Persistent Ammo System (10 rounds per magazine)
- **Resource:** `corex-inventory` + `corex-core` (metadata)
- **Problem:** Ammo is not persistent. Player shoots until empty, moves weapon to storage, takes it out again → full ammo. Exploit + unrealistic.
- **Required Change:**
  - Ammo count must be a stored property on the weapon instance (not global per weapon type).
  - Persist ammo across:
    - Moving in/out of storage
    - Dropping and picking up
    - Server disconnect/reconnect
  - **Each magazine item = 10 rounds.** Using 1 ammo item → adds 10 bullets to the weapon.
  - Reloading consumes an ammo item from inventory; if no ammo item → cannot reload.
- **Acceptance:** Empty your magazine → move weapon to storage → retrieve → still empty. Must reload using an ammo item. Each ammo item gives exactly 10 rounds. Works across relogs.

---

### P1-6 · Zombie Attack Animations (Bite / Stab / Lunge)
- **Resource:** Zombie AI system
- **Problem:** Zombies attack with standard NPC punches. Should feel like zombies.
- **Required Change:**
  - Use the attack animations **already defined in the zombie config** (do not invent new ones):
    - Bite
    - Stab (lunging claw/grab)
    - Leap/pounce
  - On attack, pick one animation randomly from the config pool.
  - Sync animation with damage tick.
- **Acceptance:** Zombie attacks visibly bite/stab/lunge — no boxing punches. Clear visual distinction from human NPCs.

---

### P1-7 · Zombie Voice/Sound Fix
- **Resource:** Zombie AI system
- **Problem:** Zombies emit human NPC voice lines (pain grunts, phrases like "F*** you").
- **Required Change:**
  - Disable all ambient and pain speech: `SetAmbientVoiceName(ped, "")`, `DisablePedPainAudio(ped, true)`.
  - Block scripted speech: `StopCurrentPlayingAmbientSpeech`, clear voice on spawn and periodically.
  - (Zombie growl sounds, if already in the framework, stay. If not — do NOT add new audio systems; this task is **removal only**.)
- **Acceptance:** Zombies never produce human voice lines. Only growls/silence.

---

### P1-8 · Basic Vehicle Spawn (Bicycle)
- **Resource:** `corex-spawn`
- **Required Change:**
  - The spawn UI already has a reserved slot for this — populate it.
  - Add a **basic-only** vehicle selection (bicycle). **No cars, no motorcycles, no high-tier vehicles.**
  - Player selects a bicycle at spawn → vehicle is created near the spawn point → player exits spawn with transport.
  - Keep the selection minimal (one or two bike models max).
- **Acceptance:** New spawn flow offers a bicycle. Player leaves spawn already having basic transport. Feature is visible and functional in the spawn UI.

---

### P1-9 · Shared World State — True Online Multiplayer Sync
- **Resource:** `corex-core` (new sync layer) + Zombie AI system + `corex-events`
- **Problem:**
  - Zombies are currently **spawned client-side per player**. Each player sees their own private zombie instances → not a shared world.
  - When Player A is in an area fighting hordes (normal, fire, poison, etc.), Player B arriving at the same location does **not** see Player A's zombies — instead the system spawns a fresh set of zombies for Player B on top of the existing ones.
  - Event loot is also not synchronized — two players can "take" the same crate, or Player B has no visibility that Player A is looting it.
  - Net result: framework feels single-player in a multiplayer world. Players cannot cooperate, cannot defend each other, cannot compete for loot.

- **Required Change (core goal):**
  - Build a **server-authoritative shared world state** so that **every zombie and every event object exists once on the server and is visible/interactable to all players within range**.
  - Two players standing in the same area must see the **same zombies** at the **same positions** with the **same HP**.
  - Killing a zombie = killing it for everyone.
  - Taking a loot crate = gone for everyone.
  - Players can shoot and damage zombies targeting another player (co-op defense).

- **Required Change (detailed architecture):**

  **A. Server-Authoritative Zombie Spawning**
  - Move zombie spawn decisions from client-side to server-side.
  - Server maintains a global `ActiveZombies` registry: `{ entityNetId, position, type, hp, targetPlayer, ownerPlayer }`.
  - Server decides **when** and **where** zombies spawn based on the aggregate of all nearby players, not each player individually.
  - Use `CreatePed` server-side (FiveM supports server-side ped creation) → returns a network ID that all clients share.
  - If server-side peds are not viable for performance, use a **designated host model**: server picks one client as the "zone host" responsible for spawning; other clients in the zone request the entity via netId and do NOT spawn their own.

  **B. Network Ownership & Entity Control**
  - Every zombie must have a clearly defined network owner at any moment.
  - When the current owner leaves the zone or disconnects, ownership **migrates** to the next closest player (handled server-side).
  - Ownership transfer must preserve zombie state: HP, animation, current target, path.
  - Use `NetworkGetEntityOwner` / `NetworkRequestControlOfEntity` / server entity APIs to manage this — never let two clients think they own the same zombie.

  **C. Damage Replication & Death Sync**
  - All damage events route through the server:
    1. Client detects hit → sends `corex:zombie:damage` to server with `{ netId, damage, weapon, shooter }`.
    2. Server validates (distance, weapon, line-of-sight sanity) and updates zombie HP in `ActiveZombies`.
    3. Server broadcasts updated HP to all clients in the zone (StateBag on the zombie entity).
    4. When HP ≤ 0 → server issues a single kill command; all clients play the death animation on the same entity.
  - **No client-side "my zombie is dead but yours isn't"** — death is one event, globally.
  - Damage numbers, blood effects, ragdoll — all triggered from the server broadcast so every observer sees the same thing.

  **D. Target & Aggro Sharing**
  - A zombie's current target is server-side state.
  - If zombie is chasing Player A, Player B can see it chasing Player A (not chasing themselves).
  - Player B can shoot that zombie and damage it → aggro may transfer based on threat (configurable: last-damager, closest, or fixed).
  - This enables **co-op defense** — the core requested behavior.

  **E. Event Loot Synchronization**
  - Event loot crates are **server-spawned objects** (one per event, one netId).
  - Looting flow:
    1. Player presses interact key → client sends `corex:event:lootRequest` to server.
    2. Server checks: is crate still open? Who started looting? Is another player already looting?
    3. If free → server locks the crate to that player, broadcasts "Player X is looting" to all nearby clients (visible animation).
    4. When complete → server removes crate globally, gives loot only to the locking player.
  - Other players **see** the looting player taking the crate (animation + progress), and the crate becomes unavailable for them.
  - No two players can ever receive loot from the same crate.

  **F. Proximity-Based Sync Zones (Performance)**
  - Do NOT sync every zombie on the map to every client — that would destroy performance.
  - Define a **sync radius** (e.g., 200m, configurable).
  - Each client only receives updates for zombies within their sync radius.
  - Zombies entering a client's radius → created locally with server-provided state.
  - Zombies leaving the radius → despawned locally, state preserved on server.
  - Server periodically culls zombies in zones with **zero nearby players** to save resources.

  **G. Configuration Hooks (server-owner tunable)**
  ```lua
  Config.Sync = {
      Enabled = true,
      ZombieSyncRadius = 200.0,      -- meters
      MaxGlobalZombies = 150,        -- hard cap across the map
      MaxZombiesPerZone = 25,        -- per cluster of players
      AggroMode = 'lastDamager',     -- 'lastDamager' | 'closest' | 'sticky'
      OwnershipMigrationDelay = 500, -- ms
      EventLootLockTimeout = 10000,  -- ms (abandon lock if looter leaves)
  }
  ```

  **H. Anti-Conflict with Existing Per-Client Spawner**
  - The current client-side zombie spawning code **must be disabled** when `Config.Sync.Enabled = true`.
  - Leave the old path behind a config flag so solo/offline testing still works, but default to synced mode.

- **Acceptance Criteria:**
  1. Two players stand in the same area → both see the **same zombies** at the **same coordinates** with the **same HP values**.
  2. Player A shoots zombie → Player B sees HP drop + blood effect + sound.
  3. Player A kills zombie → Player B sees the exact same death animation on the exact same entity; zombie does not respawn as a "new" one for Player B.
  4. Player B can damage a zombie that is currently chasing Player A → aggro transitions per `Config.Sync.AggroMode`.
  5. At an event: Player A starts looting the crate → Player B sees the looting animation and cannot initiate their own loot → crate vanishes globally when A finishes.
  6. Player count scales: 10 players in the same area = one shared horde, not 10 private hordes.
  7. Leaving the zone → zombies persist on the server; returning → you see the same zombies (if not yet killed).
  8. Disconnect of the zone host → ownership migrates cleanly with zero zombie duplication or deletion.
  9. Performance budget: zombie sync does not exceed a configurable network/CPU threshold with 32 concurrent players.

- **Risk & Notes:**
  - This is the **largest architectural change** in the blueprint. Depends on: P0-1 (metadata for persisted context) and benefits from P0-5/6/7 (so the synced zombies behave correctly).
  - Strongly recommended to stage the rollout: (1) sync-read-only, (2) sync damage, (3) sync death, (4) sync events. Don't ship all layers at once.
  - Requires thorough load testing before launch.

---

## P2 — Polish & Quality Improvements

### P2-1 · Zombie Spawn Quality Pass (RP-grade placement)
- **Resource:** Zombie AI system
- **Required Change:** Beyond the water/sky fix (P0-7), refine the spawn algorithm:
  - Prefer streets, buildings, and alleys over open wilderness when possible.
  - Avoid spawning inside interiors the player can't see (wasted peds).
  - Respect safe zones / no-spawn zones if the framework defines any.
- **Acceptance:** Zombie placement feels intentional and RP-consistent, not random.

---

## Execution Order (Recommended)

1. **Foundation first:** P0-1 (metadata) — blocks P0-2, P1-5, and anything state-related.
2. **Death/Spawn chain:** P0-3 → P0-4 → P0-2 → P1-8 (they share code paths).
3. **Zombie overhaul (local behavior):** P0-5 → P0-6 → P0-7 → P1-6 → P1-7 → P2-1.
4. **Events chain:** P0-8 → P0-9 → P1-1 → P1-2.
5. **Inventory/Shop/Ammo:** P1-3 → P1-4 → P1-5.
6. **UI polish:** P0-10.
7. **Shared world sync (final, highest-impact change):** P1-9 — tackled last because it depends on the zombie behavior being correct (tracks 3 & 4) and the metadata layer being in place (track 1). Ship in staged layers: read-only sync → damage sync → death sync → event-loot sync.

---

## Cross-Cutting Compliance

Every task above must follow the framework rules defined in `CLAUDE.md`:
- Use `Corex.Functions.*` — no direct FiveM natives in resource code.
- If a needed function is missing → add it to `corex-core` first, then use it.
- All variables `local`; validate inputs; handle nil; use `pcall` for risky ops.
- Metadata persists via the new layer from P0-1.
- StateBag sync for live values; metadata layer for persisted values.
