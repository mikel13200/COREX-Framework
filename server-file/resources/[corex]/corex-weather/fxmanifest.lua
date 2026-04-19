fx_version 'cerulean'
game 'gta5'

author 'ABUGIZA'
description 'Weather & Time Synchronization System'
version '1.0.0'

lua54 'yes'

dependencies {
    'corex-core'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
