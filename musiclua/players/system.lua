-- musiclua/players/system.lua
-- System command player (fallback, planned for future)

local BasePlayer = require("musiclua.players.base")

local SystemPlayer = setmetatable({}, { __index = BasePlayer })
SystemPlayer.__index = SystemPlayer

function SystemPlayer:new(opts)
    error("SystemPlayer not yet implemented")
end

return SystemPlayer
