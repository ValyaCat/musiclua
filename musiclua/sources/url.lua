-- musiclua/sources/url.lua
-- Direct audio URL source (legal URLs only)
--
-- Accepts an http/https URL pointing directly to an audio file.
-- Optionally downloads to a local cache for offline playback.

local http  = require("musiclua.util.http")
local track = require("musiclua.track")
local fs    = require("musiclua.util.fs")
local log   = require("musiclua.util.log")

local url_source = {}

--- Audio extensions we recognise in URLs.
local AUDIO_EXTS = { "mp3", "ogg", "wav", "flac", "m4a", "opus", "aac" }

--- Check whether a URL looks like a direct audio file link.
local function is_audio_url(u)
    local lower = u:lower()
    for _, ext in ipairs(AUDIO_EXTS) do
        if lower:match("%." .. ext .. "(%?.*)?$") then
            return true
        end
    end
    return false
end

--- Derive a human-readable title from a URL.
local function title_from_url(u)
    local filename = u:match("([^/]+)%?.*$") or u:match("([^/]+)$") or "stream"
    -- Strip extension
    return filename:gsub("%.[^%.]+$", "")
end

--- Create a track from a direct audio URL.
-- @param audio_url string  http/https URL to an audio file
-- @param opts      table?  options
-- @return table|nil  list containing one track
-- @return string|nil error message
function url_source.scan(audio_url, opts)
    opts = opts or {}

    if not audio_url or audio_url == "" then
        return nil, "no URL provided"
    end

    -- Validate protocol
    if not audio_url:match("^https?://") then
        return nil, "only http/https URLs are allowed"
    end

    local t = track.new({
        title  = title_from_url(audio_url),
        path   = audio_url,
        source = "url",
    })

    return { t }
end

--- Download the audio file to a local cache directory.
-- Returns a track with the local file path.
-- @param audio_url string
-- @param cache_dir string
-- @param opts      table?
-- @return table|nil  list with one track (local path)
-- @return string|nil error
function url_source.scan_and_cache(audio_url, cache_dir, opts)
    opts = opts or {}

    local tracks, err = url_source.scan(audio_url, opts)
    if not tracks then return nil, err end

    local t = tracks[1]
    local dir = fs.expand_user(cache_dir or "~/.cache/musiclua/url")
    os.execute('mkdir -p "' .. dir .. '"')

    local filename = fs.basename(audio_url) or "audio.mp3"
    local local_path = fs.join_path(dir, filename)

    if not fs.is_file(local_path) then
        log.info("downloading:", audio_url)
        local ok, dl_err = http.download(audio_url, local_path, {
            timeout   = 120,
            max_bytes = 500 * 1024 * 1024,  -- 500 MB for large files
        })
        if ok then
            t.path = local_path
        else
            log.warn("download failed:", dl_err)
            -- Keep the remote URL as fallback path
        end
    else
        t.path = local_path
        log.debug("using cached:", local_path)
    end

    return tracks
end

return url_source
