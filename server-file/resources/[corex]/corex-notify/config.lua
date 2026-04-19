Config = {}

Config.Position = 'top-right'
Config.MaxVisible = 5
Config.DefaultDuration = 5000
Config.AnimationDuration = 250
Config.StackGap = 10
Config.Width = 340

Config.Types = {
    success = { color = '#22c55e', glyph = 'check',   label = 'SUCCESS' },
    error   = { color = '#ef4444', glyph = 'error',   label = 'ERROR'   },
    warning = { color = '#f59e0b', glyph = 'warning', label = 'WARNING' },
    info    = { color = '#3b82f6', glyph = 'info',    label = 'INFO'    },
    money   = { color = '#10b981', glyph = 'money',   label = 'MONEY'   },
    zone    = { color = '#8b5cf6', glyph = 'zone',    label = 'ZONE'    },
    item    = { color = '#06b6d4', glyph = 'item',    label = 'ITEM'    },
    combat  = { color = '#dc2626', glyph = 'combat',  label = 'COMBAT'  }
}

Config.Sound = {
    enabled = true,
    volume = 0.3,
    map = {
        success = 'ROBBERY_MONEY_TOTAL',
        error   = 'ERROR',
        warning = 'CHARACTER_DAMAGE_ALERT',
        info    = 'NAV_UP_DOWN'
    }
}
