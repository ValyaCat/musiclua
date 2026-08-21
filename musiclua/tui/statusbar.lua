-- musiclua/tui/statusbar.lua
-- Status bar: 3-row layout with full-width sub-character progress bar
--
-- Row 1:  Track title + mode icon
-- Row 2:  00:42  ████████████████▌░░░░░░░░░░░░░░  03:05
-- Row 3:  playing │ vol: 75% │ repeat-all

local time_util = require("musiclua.util.time")
local sys_ok, sys = pcall(require, "system")

local statusbar = {}

--- Helper: truncate string to fit within max display width.
local function trunc_display(s, max_w)
    if max_w < 2 then return "" end
    local dw = (sys_ok and sys.utf8swidth) and sys.utf8swidth(s) or #s
    if dw <= max_w then return s end
    while #s > 0 do
        local cur_w = (sys_ok and sys.utf8swidth) and sys.utf8swidth(s) or #s
        if cur_w <= max_w - 1 then break end
        s = s:sub(1, -2)
    end
    return s .. "\226\128\166"  -- "…"
end

--- Draw the status area (3 rows starting at `row`).
-- @param scr       screen object
-- @param row       number  first row of the status area
-- @param playlist  Playlist instance
-- @param player    MpvPlayer instance (or nil)
-- @param theme     theme table
-- @param mode      string  "normal" or "search"
-- @param search_text string  current search keyword
function statusbar.draw(scr, row, playlist, player, theme, mode, search_text)
    local _, cols = scr:size()

    -- Get playback data
    local status_text = "stopped"
    local pos         = 0
    local dur         = 0
    local vol_text    = "--"

    if player then
        -- Query player state directly each frame (no cache).
        -- 5 IPC round-trips per frame is ~2.5ms, negligible at 20fps.
        status_text = player:get_status() or "stopped"
        pos = player:get_position() or 0
        dur = player:get_duration() or 0
        local vol = player:get_volume()
        if type(vol) == "number" then
            vol_text = string.format("%.0f%%", vol)
        end
    end

    local play_mode = "repeat-all"
    if playlist.get_mode then
        play_mode = playlist:get_mode() or play_mode
    end

    ----------------------------------------------------------------
    -- Row 1: Track title
    ----------------------------------------------------------------
    scr:clear_line(row)
    if mode == "search" then
        scr:set_color(theme.color_accent)
        scr:write(row, 1, " / ")
        scr:set_color(0)
        scr:write(row, 4, search_text or "")
        scr:write(row, 4 + #(search_text or ""), "\226\150\142")  -- ▎ cursor
    else
        local playing = playlist:playing_track()
        if playing then
            local title = playing.title or "(untitled)"
            -- Status icon
            local icon = theme.stopped_icon
            if status_text == "playing" then
                icon = theme.playing_icon
                scr:set_color(theme.color_playing)
            elseif status_text == "paused" then
                icon = theme.paused_icon
                scr:set_color(theme.color_status)
            else
                scr:set_color(theme.color_dim)
            end
            scr:write(row, 2, icon)
            -- Title
            scr:set_color(0)
            local max_title = cols - 4
            scr:write(row, 4, trunc_display(title, max_title))
        else
            scr:set_color(theme.color_dim)
            scr:write(row, 2, "(nothing playing)")
        end
    end

    ----------------------------------------------------------------
    -- Row 2: Progress bar (full-width, sub-character precision)
    ----------------------------------------------------------------
    local bar_row = row + 1
    scr:clear_line(bar_row)

    local pos_text = time_util.format_seconds(pos)
    local dur_text = time_util.format_seconds(dur)
    -- Time labels: "00:42" and "03:05" with 1-space padding
    local left_label  = " " .. pos_text .. " "
    local right_label = " " .. dur_text .. " "
    local label_w = #left_label + #right_label

    -- Bar width = full terminal width minus time labels
    local bar_w = cols - label_w
    if bar_w < 4 then bar_w = 4 end

    -- Compute fill with sub-character precision
    local ratio = (dur > 0) and math.min(1, pos / dur) or 0
    local exact_pos = ratio * bar_w
    local full_cells = math.floor(exact_pos)
    local sub_frac  = exact_pos - full_cells

    -- Left time label
    scr:set_color(theme.color_bar_time)
    scr:write(bar_row, 1, left_label)

    -- Draw the bar character by character with sub-cell precision
    local bar_col_start = 1 + #left_label
    local used = 0  -- cells consumed so far

    -- Filled portion (full blocks)
    if full_cells > 0 then
        scr:set_color(theme.color_bar_fg)
        scr:write(bar_row, bar_col_start,
            string.rep(theme.bar_full, full_cells))
        used = full_cells
    end

    -- Sub-character transition (right-half block ▐)
    if sub_frac >= 0.5 and used < bar_w then
        scr:set_color(theme.color_bar_fg)
        scr:write(bar_row, bar_col_start + used, theme.bar_right)
        used = used + 1
    end

    -- Empty portion (light shade ░)
    local empty_cells = bar_w - used
    if empty_cells > 0 then
        scr:set_color(theme.color_bar_bg)
        scr:write(bar_row, bar_col_start + used,
            string.rep(theme.bar_empty, empty_cells))
    end

    -- Right time label
    scr:set_color(theme.color_bar_time)
    scr:write(bar_row, bar_col_start + bar_w, right_label)

    ----------------------------------------------------------------
    -- Row 3: Status info line
    ----------------------------------------------------------------
    local info_row = row + 2
    scr:clear_line(info_row)

    -- Status label with color
    scr:write(info_row, 1, " ")
    if status_text == "playing" then
        scr:set_color(theme.color_playing)
    elseif status_text == "paused" then
        scr:set_color(theme.color_status)
    else
        scr:set_color(theme.color_dim)
    end
    scr:write(info_row, 2, status_text)
    scr:set_color(theme.color_dim)

    -- Separator + volume + mode
    scr:write(info_row, 2 + #status_text,
        string.format("  %s  vol: %s  %s  %s",
            theme.separator, vol_text, theme.separator, play_mode))
    scr:set_color(0)
end

return statusbar
