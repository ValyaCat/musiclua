-- examples/tui_demo.lua
-- Demo: launch the TUI with the bundled test directory
-- Requires: lua-curses, mpv

package.path = package.path .. ";./?.lua;./?/init.lua"

local app = require("musiclua.app")

app.run({ directory = "./test_music_scan" })
