fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ABUGIZA'
description 'COREX Safe Zones System'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'corex-core'
}

exports {
    'IsPlayerInSafeZone',
    'GetNearestSafeZone',
    'GetSafeZones',
    'GetSafeZoneDistance'
}
