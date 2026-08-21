-- musiclua/sources/m3u.lua
-- M3U/M3U8 playlist source
--
-- Supports:
--   - Absolute and relative paths
--   - #EXTINF duration,title metadata
--   - Comment lines (#)
--   - UTF-8 in .m3u8 files

local fs    = require("musiclua.util.fs")
local track = require("musiclua.track")
local log   = require("musiclua.util.log")

local m3u = {}

--- Parse a single M3U line that may be a #EXTINF tag.
-- #EXTINF:<duration>,<title>
-- Returns (duration, title) or nil if not an EXTINF line.
-- @param line string
-- @return number|nil, string|nil
local function parse_extinf(line)
    local dur, title = line:match("^#EXTINF:%s*([%-0-9%.]+)%s*,%s*(.*)$")
    if dur then
        local n = tonumber(dur)
        -- title may be empty
        return n, (title ~= "" and title or nil)
    end
    return nil, nil
end

--- Resolve a file path relative to the M3U file's directory.
-- @param m3u_dir  string  directory containing the .m3u file
-- @param entry    string  path from the M3U entry line
-- @return string  absolute path
local function resolve_path(m3u_dir, entry)
    -- Already absolute
    if entry:sub(1, 1) == "/" then
        return entry
    end
    -- Starts with ~ (home)
    if entry:sub(1, 1) == "~" then
        return fs.expand_user(entry)
    end
    return fs.join_path(m3u_dir, entry)
end

--- Parse an M3U/M3U8 file and return a list of tracks.
-- @param path  string  path to the .m3u / .m3u8 file
-- @param opts  table?  options (unused for now)
-- @return table|nil  list of tracks
-- @return string|nil error message
function m3u.scan(path, opts)
    opts = opts or {}
    path = fs.expand_user(path)

    if not fs.is_file(path) then
        return nil, "not a file or does not exist: " .. tostring(path)
    end

    local file, err = io.open(path, "r")
    if not file then
        return nil, "cannot open file: " .. tostring(err)
    end

    local m3u_dir = path:match("^(.*/)") or "."
    local tracks  = {}
    local pending_duration = nil
    local pending_title    = nil

    for raw_line in file:lines() do
        -- Strip trailing \r (Windows line endings)
        local line = raw_line:gsub("\r$", "")

        -- Skip empty lines
        if line ~= "" then
            -- Check for #EXTINF
            local dur, title = parse_extinf(line)
            if dur then
                pending_duration = dur
                pending_title    = title
            elseif line:sub(1, 1) == "#" then
                -- Other comment/metadata lines – skip
            else
                -- This is a file path / URL entry
                local full_path = resolve_path(m3u_dir, line)

                -- Derive a title: use #EXTINF title, or fall back to basename
                local track_title = pending_title or fs.basename(full_path)

                local t = track.new({
                    title    = track_title,
                    path     = full_path,
                    source   = "m3u",
                    duration = pending_duration and pending_duration > 0 and pending_duration or nil,
                })
                tracks[#tracks + 1] = t

                -- Reset pending metadata
                pending_duration = nil
                pending_title    = nil
            end
        end
    end

    file:close()

    -- Assign sequential IDs
    for i, t in ipairs(tracks) do
        t.id = tostring(i)
    end

    log.info("m3u: parsed", #tracks, "entries from", path)
    return tracks
end

return m3u
