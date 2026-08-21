-- musiclua/library.lua
-- Music library: scans directories and returns track lists

local sources = require("musiclua.sources")
local log     = require("musiclua.util.log")
local fs      = require("musiclua.util.fs")

local library = {}

--- Default audio file extensions.
library.default_extensions = {
    ".mp3", ".ogg", ".wav", ".flac", ".m4a", ".opus",
}

--- Available sort modes.
library.sort_modes = {
    title  = function(a, b) return (a.title  or ""):lower() < (b.title  or ""):lower() end,
    artist = function(a, b) return (a.artist or ""):lower() < (b.artist or ""):lower() end,
    album  = function(a, b) return (a.album  or ""):lower() < (b.album  or ""):lower() end,
    date   = function(a, b) return (a.added_at or 0) < (b.added_at or 0) end,
    path   = function(a, b) return (a.path   or ""):lower() < (b.path   or ""):lower() end,
}

--- Default sort mode.
library.default_sort = "title"

--- Scan a single directory and return a list of tracks.
-- @param path string  directory path (may contain ~)
-- @param opts table?  forwarded to the source scanner
-- @return table  list of track tables
-- @return string|nil  error message
function library.scan_dir(path, opts)
    opts = opts or {}
    if not opts.extensions then
        opts.extensions = library.default_extensions
    end

    local source_name = sources.detect(path)
    local src = sources.get(source_name)
    if not src then
        return nil, "unknown source type for: " .. tostring(path)
    end

    local tracks, err = src.scan(path, opts)
    if not tracks then
        log.warn("scan_dir failed:", err)
        return {}, err
    end
    return tracks
end

--- Scan multiple directories, merge, and sort the results.
-- @param paths table  list of directory paths
-- @param opts  table? options: { extensions, recursive, sort = "title"|"artist"|... }
-- @return table  merged, sorted list of tracks
function library.scan_dirs(paths, opts)
    opts = opts or {}
    local all = {}

    for _, path in ipairs(paths or {}) do
        local tracks, err = library.scan_dir(path, opts)
        if tracks then
            for _, t in ipairs(tracks) do
                all[#all + 1] = t
            end
        else
            log.warn("skipping", path, "-", err)
        end
    end

    -- Determine sort mode
    local sort_name = opts.sort or library.default_sort
    local sort_fn = library.sort_modes[sort_name]
    if not sort_fn then
        log.warn("unknown sort mode:", sort_name, "- falling back to title")
        sort_fn = library.sort_modes.title
    end

    table.sort(all, sort_fn)

    -- Re-assign sequential IDs
    for i, t in ipairs(all) do
        t.id = tostring(i)
    end
    return all
end

return library
