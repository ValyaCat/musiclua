-- musiclua/tui/statusbar.lua
-- Status bar component showing current playback info

local time_util = require("musiclua.util.time")

local statusbar = {}

--- Draw the status bar (2 lines: track title + playback details).
-- @param scr       screen object
-- @param row       number  top row of the status area
-- @param playlist  Playlist instance
-- @param player    MpvPlayer instance (or nil)
-- @param theme     theme table
-- @param mode      string  "normal" or "search"
-- @param search_text string  current search keyword
function statusbar.draw(scr, row, playlist, player, theme, mode, search_text)
    local _, cols = scr:size()

    -- Line 1: Now Playing
    scr:clear_line(row)
    local playing = playlist:playing_track()
    local title = playing and playing.title or "(nothing)"
    local line1 = " Now Playing: " .. title

    -- Filter indicator
    local kw = playlist:get_filter()
    if kw and kw ~= "" then
        line1 = line1 .. "  [filter: " .. kw .. "]"
    end
    if mode == "search" then
        line1 = " Search: " .. (search_text or "") .. "_"
    end

    if #line1 > cols then line1 = line1:sub(1, cols) end
    scr:set_color(theme.color_status)
    scr:write(row, 1, line1)

    -- Line 2: Status / time / volume
    local status_row = row + 1
    scr:clear_line(status_row)

    local status_text = "stopped"
    local pos_text    = "00:00"
    local dur_text    = "00:00"
    local vol_text    = "0%"

    if player then
        status_text = player:get_status() or "stopped"
        local pos   = player:get_position()
        local dur   = player:get_duration()
        pos_text = time_util.format_seconds(pos)
        dur_text = time_util.format_seconds(dur)
        local vol = player:get_volume()
        if type(vol) == "number" then
            vol_text = string.format("%.0f%%", vol)
        end
    end

    local play_mode = "repeat-all"
    if playlist.get_mode then
        play_mode = playlist:get_mode()
    end
    local line2 = string.format(
        " Status: %s | %s / %s | vol: %s | mode: %s",
        status_text, pos_text, dur_text, vol_text, play_mode
    )
    if #line2 > cols then line2 = line2:sub(1, cols) end
    scr:write(status_row, 1, line2)
    scr:set_color(0)
end

return statusbar
