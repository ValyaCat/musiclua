-- musiclua/tui/init.lua
-- TUI entry point

local tui = {}

--- Launch the TUI with the given playlist and optional player.
-- @param opts table  { playlist = Playlist, player = MpvPlayer }
function tui.run(opts)
    local app = require("musiclua.tui.app")
    app.run(opts)
end

return tui
