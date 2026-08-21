-- musiclua/track.lua
-- Track data model

local track = {}

--- Create a new track table.
-- @param opts table  { id, title, path, source, duration?, artist?, album? }
-- @return table
function track.new(opts)
    opts = opts or {}
    return {
        id       = opts.id       or tostring(os.time()) .. "-" .. math.random(1000),
        title    = opts.title    or "Unknown",
        path     = opts.path     or "",
        source   = opts.source   or "local",
        duration = opts.duration,
        artist   = opts.artist,
        album    = opts.album,
        added_at = opts.added_at or os.time(),
    }
end

return track
