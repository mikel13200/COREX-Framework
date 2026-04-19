fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'corex-notify'
description 'COREX Framework - Professional Notification System'
author 'COREX'
version '1.0.0'

dependencies {
    'corex-core'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

client_scripts {
    'config.lua',
    'client/main.lua'
}
