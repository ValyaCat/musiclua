-- musiclua/sources/init.lua
-- Source registry: dispatches to the appropriate source module

local fs = require("musiclua.util.fs")

local sources = {}

-- Registry of source modules (lazy-loaded)
local _registry = {}

--- Register a source module under a name.
-- @param name string  e.g. "local_dir", "m3u", "rss", "url"
-- @param mod  table   the source module, must expose scan(input, opts)
function sources.register(name, mod)
    _registry[name] = mod
end

--- Detect which source type fits the given input path/string.
-- @param input string
-- @return string  source name
function sources.detect(input)
    if not input or input == "" then return "local_dir" end
    -- Expand ~ first for detection
    local expanded = fs.expand_user(input)
    if fs.is_dir(expanded) then
        return "local_dir"
    end
    local ext = (input:match("(%.[^%.]+)$") or ""):lower()
    if ext == ".m3u" or ext == ".m3u8" then
        return "m3u"
    end
    if input:match("^https?://") then
        -- Distinguish RSS feeds from direct audio URLs
        if ext == ".rss" or ext == ".xml" or input:match("rss") or input:match("feed") then
            return "rss"
        end
        return "url"
    end
    -- Default to local_dir
    return "local_dir"
end

--- Get a registered source module by name.
-- @param name string
-- @return table|nil
function sources.get(name)
    return _registry[name]
end

-- Auto-register built-in sources
for _, name in ipairs({ "local_dir", "m3u", "rss", "url" }) do
    local ok, mod = pcall(require, "musiclua.sources." .. name)
    if ok then sources.register(name, mod) end
end

return sources
