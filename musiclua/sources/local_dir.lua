-- musiclua/sources/local_dir.lua
-- Local directory source: scans a directory for audio files

local fs    = require("musiclua.util.fs")
local track = require("musiclua.track")
local log   = require("musiclua.util.log")

local local_dir = {}

-- Default audio extensions recognised by the scanner.
local_dir.default_extensions = {
    ".mp3", ".ogg", ".wav", ".flac", ".m4a", ".opus",
}

--- Scan a directory for audio files.
-- @param dir   string   directory path
-- @param opts  table?   { extensions = {}, recursive = false, max_depth = 10 }
-- @return table  list of track tables (sorted by title)
-- @return string|nil  error message on failure
function local_dir.scan(dir, opts)
    opts = opts or {}
    local extensions = opts.extensions or local_dir.default_extensions
    local recursive  = opts.recursive or false
    local max_depth  = opts.max_depth or 10

    -- Expand ~ in path
    dir = fs.expand_user(dir)

    if not fs.is_dir(dir) then
        return nil, "not a directory or does not exist: " .. tostring(dir)
    end

    local tracks = {}

    --- Internal recursive scanner.
    -- @param scan_dir string
    -- @param depth    number  current recursion depth
    local function scan_one(scan_dir, depth)
        local entries, err = fs.scandir(scan_dir)
        if not entries then
            log.warn("cannot read directory:", err)
            return
        end

        for _, name in ipairs(entries) do
            if not fs.is_hidden(name) then
                local full_path = fs.join_path(scan_dir, name)

                if fs.is_file(full_path) and fs.has_audio_ext(name, extensions) then
                    -- Use relative path from root dir for a cleaner title
                    local rel = full_path:sub(#dir + 2)  -- strip "dir/"
                    tracks[#tracks + 1] = track.new({
                        title = rel,
                        path  = full_path,
                        source = "local",
                    })
                elseif recursive and depth < max_depth and fs.is_dir(full_path) then
                    scan_one(full_path, depth + 1)
                end
            end
        end
    end

    scan_one(dir, 0)

    -- Sort by title (relative path) ascending
    table.sort(tracks, function(a, b)
        return a.title:lower() < b.title:lower()
    end)

    -- Assign stable sequential IDs after sorting
    for i, t in ipairs(tracks) do
        t.id = tostring(i)
    end

    return tracks
end

return local_dir
