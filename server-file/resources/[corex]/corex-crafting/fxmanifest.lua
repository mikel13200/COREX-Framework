fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'corex-crafting'
description 'COREX Crafting System'
author 'ABUGIZA'
version '1.0.0'

shared_scripts {
    '@corex-inventory/shared/items.lua',
    '@corex-inventory/shared/weapons.lua',
    'config.lua'
}
client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/script.js' }

dependencies { 'corex-core', 'corex-inventory' }
