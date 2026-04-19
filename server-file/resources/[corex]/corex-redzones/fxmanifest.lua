fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'corex-redzones'
description 'COREX Red Zones - high-risk high-reward extreme danger areas'
author 'ABUGIZA'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/effects.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'corex-core',
    'corex-loot',
    'corex-zombies',
    'corex-inventory'
}
