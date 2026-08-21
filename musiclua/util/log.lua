-- musiclua/util/log.lua
-- Simple logging utility (writes to stderr)

local log = {}

log.levels = {
    debug = 1,
    info  = 2,
    warn  = 3,
    error = 4,
}

--- Current minimum log level (default: warn).
log.level = log.levels.warn

--- Set the minimum log level.
-- @param level string  one of "debug", "info", "warn", "error"
function log.set_level(level)
    if log.levels[level] then
        log.level = log.levels[level]
    end
end

local function output(level_name, ...)
    local parts = { level_name:upper() .. ":" }
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[#parts + 1] = tostring(v)
    end
    io.stderr:write(table.concat(parts, " ") .. "\n")
end

function log.debug(...)
    if log.level <= log.levels.debug then output("debug", ...) end
end

function log.info(...)
    if log.level <= log.levels.info then output("info", ...) end
end

function log.warn(...)
    if log.level <= log.levels.warn then output("warn", ...) end
end

function log.error(...)
    if log.level <= log.levels.error then output("error", ...) end
end

return log
