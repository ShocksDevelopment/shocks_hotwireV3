fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'shocks_hotwire'
author 'SHOCKS Development'
description 'SHOCKS Hotwire - standalone vehicle hotwiring mini-game'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'bridge/client/keys.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server/keys.lua',
    'server/main.lua'
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js'
}

dependencies {
    'ox_lib'
}
