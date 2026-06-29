--   _      ____      _       _
--  (_)    |___ \    | |     | |
--   _  ___  __) | __| | ___ | |__   ___  ___ ___
--  | |/ __||__ < / _` |/ __|| '_ \ / _ \/ __/ __|
--  | | (__ ___) | (_| | (__ | | | |  __/\__ \__ \
--  |_|\___|____/ \__,_|\___||_| |_|\___||___/___/
--
--  ic3d_chess - Realistic 2-player chess (with vs Computer/NPC option)
--  Props: bzzz_chess | Bridge: ic3d_territories_v2

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ic3d_'
version '1.0.0'
description 'Realistic in-world 3D chess - PvP & vs Computer using bzzz_chess props'

ui_page 'web/index.html'

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua',
  'shared/chess_engine.lua',
  'shared/chess_ai.lua',
}

client_scripts {
  'bridge/client.lua',
  'client/main.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'bridge/server.lua',
  'server/main.lua',
}

files {
  'web/index.html',
  'web/style.css',
  'web/script.js',
  'web/components/*.svg',
}

dependencies {
  'ox_lib',
  'oxmysql',
  'bzzz_chess',
}

escrow_ignore {
  'config.lua',
}
