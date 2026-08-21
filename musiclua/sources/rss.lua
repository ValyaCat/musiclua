-- musiclua/sources/rss.lua
-- RSS/Podcast feed parser (legal feeds only)
--
-- Parses <item> entries, extracting <enclosure url="..."> audio links
-- and <title> metadata.  Supports RSS 2.0 and basic Atom feeds.

local http = require("musiclua.util.http")
local track = require("musiclua.track")
local log   = require("musiclua.util.log")
local fs    = require("musiclua.util.fs")

local rss = {}

--- Decode basic XML entities.
local function xml_decode(s)
    if not s then return "" end
    return s
        :gsub("&amp;",  "&")
        :gsub("&lt;",   "<")
        :gsub("&gt;",   ">")
        :gsub("&quot;", '"')
        :gsub("&#39;",  "'")
        :gsub("&apos;", "'")
end

--- Strip CDATA wrapper if present.
local function strip_cdata(s)
    if not s then return "" end
    return (s:gsub("^%s*<!%[CDATA%[(.-)%]%]>%s*$", "%1"))
end

--- Extract the first occurrence of a tag value from an XML fragment.
-- Handles both plain text and CDATA.
local function tag_value(xml_str, tag)
    local val = xml_str:match("<" .. tag .. "[^>]*>(.-)</" .. tag .. ">")
    if val then
        val = strip_cdata(val)
        return xml_decode(val)
    end
    return nil
end

--- Extract an attribute value from a self-closing or open tag.
local function attr_value(xml_str, tag, attr)
    local pattern = "<" .. tag .. "[^>]*%s" .. attr .. '%s*=%s*"([^"]*)"'
    return xml_str:match(pattern)
end

--- Parse RSS XML text into a list of tracks.
-- @param xml_text string  raw RSS/Atom XML
-- @param feed_url string  source URL for attribution
-- @return table  list of tracks
local function parse_rss_xml(xml_text, feed_url)
    local tracks = {}

    -- RSS 2.0: iterate <item> blocks
    for item_xml in xml_text:gmatch("<item[^>]*>(.-)</item>") do
        local title    = tag_value(item_xml, "title") or "Untitled"
        local enc_url  = attr_value(item_xml, "enclosure", "url")
        local enc_type = attr_value(item_xml, "enclosure", "type") or ""

        -- Only include items that have an audio enclosure
        if enc_url and (enc_type:find("audio") or enc_url:match("%.(mp3|ogg|m4a|flac|wav|opus)(%?.*)?$")) then
            tracks[#tracks + 1] = track.new({
                title  = title,
                path   = enc_url,
                source = "rss",
            })
        end
    end

    -- Atom: iterate <entry> blocks (fallback)
    if #tracks == 0 then
        for entry_xml in xml_text:gmatch("<entry[^>]*>(.-)</entry>") do
            local title   = tag_value(entry_xml, "title") or "Untitled"
            local link    = attr_value(entry_xml, "link", "href")
            local rel     = attr_value(entry_xml, "link", "rel") or ""

            if link and (rel == "enclosure" or link:match("%.(mp3|ogg|m4a|flac|wav|opus)")) then
                tracks[#tracks + 1] = track.new({
                    title  = title,
                    path   = link,
                    source = "rss",
                })
            end
        end
    end

    return tracks
end

--- Fetch and parse a legal RSS/Podcast feed.
-- @param feed_url string  URL of the RSS/Atom feed
-- @param opts     table?  { cache_dir = string }
-- @return table|nil  list of tracks
-- @return string|nil error message
function rss.scan(feed_url, opts)
    opts = opts or {}

    if not feed_url or feed_url == "" then
        return nil, "no RSS feed URL provided"
    end

    -- Validate: only allow http/https
    if not feed_url:match("^https?://") then
        return nil, "only http/https URLs are allowed"
    end

    log.info("fetching RSS feed:", feed_url)

    local body, err, code = http.fetch(feed_url, {
        timeout   = opts.timeout or 30,
        max_bytes = opts.max_bytes or 2 * 1024 * 1024,  -- 2 MB for feeds
    })

    if not body then
        return nil, "failed to fetch RSS feed: " .. tostring(err)
    end

    local tracks = parse_rss_xml(body, feed_url)
    log.info("rss: parsed", #tracks, "audio entries from", feed_url)

    -- Assign sequential IDs
    for i, t in ipairs(tracks) do
        t.id = tostring(i)
    end

    return tracks
end

--- Cache an RSS feed's audio files to a local directory.
-- Downloads each enclosure to cache_dir/<feed_hash>/.
-- @param feed_url  string
-- @param cache_dir string
-- @param opts      table?
-- @return table|nil  list of tracks with local paths
-- @return string|nil error
function rss.scan_and_cache(feed_url, cache_dir, opts)
    opts = opts or {}

    local tracks, err = rss.scan(feed_url, opts)
    if not tracks then return nil, err end

    -- Create cache subdirectory based on feed URL hash
    local hash = string.format("%08x", tonumber(feed_url:sub(1, 8):byte(1)) or 0)
    local dir = fs.join_path(fs.expand_user(cache_dir or "~/.cache/musiclua"), hash)
    os.execute('mkdir -p "' .. dir .. '"')

    for _, t in ipairs(tracks) do
        local filename = fs.basename(t.path) or ("track_" .. t.id .. ".mp3")
        local local_path = fs.join_path(dir, filename)
        if not fs.is_file(local_path) then
            log.info("downloading:", t.path)
            local ok, dl_err = http.download(t.path, local_path, { timeout = 120, max_bytes = 200 * 1024 * 1024 })
            if ok then
                t.path = local_path
            else
                log.warn("download failed:", dl_err)
            end
        else
            t.path = local_path
        end
    end

    return tracks
end

return rss
