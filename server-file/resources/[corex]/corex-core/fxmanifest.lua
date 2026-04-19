fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'corex-core'
description 'COREX Framework - Core Engine for Zombie Survival'
author 'ABUGIZA'
version '2.0.0'

shared_scripts {
    'config.lua',
    'shared/debug.lua',
    'shared/utils.lua',
    'shared/validation.lua',
    'shared/vehicles.lua'
}

server_scripts {
    'server/main.lua',
    'server/players.lua',
    'server/state.lua',
    'server/utils.lua'
}

client_scripts {
    'client/main.lua',
    'client/cl_interact.lua',
    'client/cl_world.lua'
}

ui_page 'html/interact.html'

files {
    'html/interact.html'
}

server_exports {
    'GetCoreObject',
    'GetPlayer',
    'GetPlayers',
    'GetNearbyPlayers',
    'GetPlayerById',
    'GetMoney',
    'AddMoney',
    'RemoveMoney',
    'HasMoney',
    'GetStat',
    'SetStat',
    'AddStat',
    'SetBusy',
    'TrySetBusy',
    'ClearBusy',
    'IsBusy',
    'SetPlayerState',
    'GetPlayerState',
    'GetPlayersByState',
    'SavePlayer',
    'SetMetaData',
    'GetMetaData',
    'GetVehicleCatalog',
    'GetVehicleDefinition'
}

exports {
    'GetCoreObject',
    'AddTarget',
    'RemoveTarget',
    'IsReady',
    'GetVehicleCatalog',
    'GetVehicleDefinition'
}
