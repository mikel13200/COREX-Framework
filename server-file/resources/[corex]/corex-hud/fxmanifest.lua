fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'corex-hud'
description 'COREX Framework - Player HUD System'
author 'ABUGIZA'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua'
}

dependencies {
    'corex-core',
    'corex-inventory',
    'ox_lib'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/weapon-icons/*.png',
}

client_scripts {
    'config.lua',
    'client/main.lua'
}
