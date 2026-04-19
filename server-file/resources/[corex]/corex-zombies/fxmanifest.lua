fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ABUGIZA'
description 'COREX Zombie AI System'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/horde.lua',
    'client/audio.lua',
    'client/effects.lua',
    'client/combat.lua',
    'client/spawn.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'corex-core'
}

exports {
    'GetActiveZombies',
    'GetZombieCount',
    'SpawnZombie',
    'IsPlayerGrabbed',
    'ForceEndGrab'
}
