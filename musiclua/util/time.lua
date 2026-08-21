-- musiclua/util/time.lua
-- Time formatting utilities

local time = {}

--- Format a number of seconds as MM:SS or HH:MM:SS.
-- @param seconds number|nil
-- @return string
function time.format_seconds(seconds)
    if type(seconds) ~= "number" or seconds < 0 then
        return "00:00"
    end
    seconds = math.floor(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

return time
