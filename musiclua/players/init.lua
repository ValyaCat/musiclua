-- musiclua/players/init.lua
-- Player factory: creates player instances by name

local players = {}

--- Create a player by name.
-- @param name string  "mpv" (only supported backend for v0.1.0)
-- @param opts table?  options forwarded to the player constructor
-- @return player instance
function players.create(name, opts)
    name = name or "mpv"
    if name == "mpv" then
        local MpvPlayer = require("musiclua.players.mpv")
        return MpvPlayer:new(opts)
    end
    error("unsupported player backend: " .. tostring(name))
end

return players
