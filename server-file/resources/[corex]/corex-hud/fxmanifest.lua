fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'corex-hud'
description 'COREX Framework - Player HUD System'
author 'ABUGIZA'
version '1.0.0'

dependencies {
    'corex-core'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/fonts/*.woff2'
}

client_scripts {
    'config.lua',
    'client/main.lua'
}
