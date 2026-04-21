# COREX Framework

> FiveM Zombie-Survival framework — Lua 5.4, oxmysql, StateBag sync.

- 📖 **Full Documentation:** <https://corex-zombies.gitbook.io/corex-docs>
- 💬 **Discord Community:** <https://discord.gg/G95rtnb9sg>

## Resources
`corex-core` • `corex-spawn` • `corex-inventory` • `corex-weather` • `corex-death` • `corex-crafting` • `corex-hud` • `corex-events`

---

## 🎬 Video Tutorial

Full install & run walkthrough:

[![Watch the video](https://img.youtube.com/vi/vSct4sr6mgs/maxresdefault.jpg)](https://youtu.be/vSct4sr6mgs)

▶ <https://youtu.be/vSct4sr6mgs>

---

## Quick Start

### 1. Clone
```bash
git clone https://github.com/ABUGIZA/COREX-Framework.git
cd COREX-Framework
```

### 2. Download FXServer
Get the latest Windows build → <https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/>
Extract into `FXServer/` at the project root.

### 3. Create `server.cfg`
```bash
cd server-file
copy server.cfg.example server.cfg
```
Edit and set:
- `sv_licenseKey` → <https://keymaster.fivem.net/>
- `mysql_connection_string` → pick the format that matches your MySQL setup:

**A) MySQL WITH a password** (most production setups, MySQL Workbench, remote hosts)
```cfg
set mysql_connection_string "mysql://root:YOUR_PASSWORD@localhost/corex?charset=utf8mb4"
```
Example with a real password:
```cfg
set mysql_connection_string "mysql://root:A11223344@localhost/corex?charset=utf8mb4"
```

**B) MySQL WITHOUT a password** (XAMPP / Laragon / WAMP default root user)
```cfg
set mysql_connection_string "mysql://root@localhost/corex?charset=utf8mb4"
```

> Notice there is **no colon and no password** after `root` in option B.
> Use this only if your `root` user has an empty password.

### 4. Create the database

Run this SQL once in your MySQL client (HeidiSQL / phpMyAdmin / CLI):

```sql
CREATE DATABASE IF NOT EXISTS `corex`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE `corex`;

CREATE TABLE IF NOT EXISTS `players` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `name` VARCHAR(50) NOT NULL DEFAULT 'Unknown',
    `money` LONGTEXT NOT NULL,
    `metadata` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`),
    KEY `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `inventories` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `inventory_type` VARCHAR(50) NOT NULL DEFAULT 'player',
    `inventory_id` VARCHAR(60) NOT NULL,
    `items` LONGTEXT NOT NULL,
    `hotbar` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_inventory` (`identifier`, `inventory_type`, `inventory_id`),
    KEY `idx_inventory_lookup` (`identifier`, `inventory_type`),
    KEY `idx_inventory_id` (`inventory_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 5. Start FXServer
Double-click `FXServer/run.cmd` → open **<http://localhost:40120/>**

---

## txAdmin Setup (first run)

1. Set PIN → link Cfx.re (or local admin)
2. **Deployment Type:** `Existing Server Data`
3. **Server Data Folder:** `C:\COREX_Framework\server-file`
4. **CFG File:** `server.cfg`
5. Save → click **Start Server**

---

## API

### Server
```lua
local player = Corex.Functions.GetPlayer(source)
Corex.Functions.AddMoney(source, 'cash', 500)
Corex.Functions.SetMetaData(source, 'hunger', 100)
Corex.Functions.SavePlayer(source)
```

### Client
```lua
local data = Corex.Functions.GetPlayerData()
local cash = Corex.Functions.GetMoney('cash')
```

### From another resource
```lua
-- fxmanifest.lua
dependencies { 'corex-core' }

-- main.lua
local Corex = exports['corex-core']:GetCoreObject()
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| txAdmin asks for a new deployment | Choose **Existing Server Data** instead |
| `Config file detected` not showing | Copy `server.cfg.example` → `server.cfg` first |
| oxmysql connection fails | Check MySQL is running + credentials in `server.cfg` |
| Port 30120 in use | Close other FiveM server or change port in `server.cfg` |

---

## License
Private — all rights reserved.
