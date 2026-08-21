-- musiclua/tui/list.lua
-- Track list component for the TUI

local sys_ok, sys = pcall(require, "system")
local time_util   = require("musiclua.util.time")

local list = {}

--- Helper: compute display width of a string (UTF-8 aware).
local function display_width(s)
    if sys_ok and sys.utf8swidth then
        return sys.utf8swidth(s) or #s
    end
    return #s
end

--- Helper: truncate string to fit within max_w display cells.
local function trunc_to_width(s, max_w)
    if display_width(s) <= max_w then return s end
    while #s > 0 and display_width(s) > max_w - 1 do
        s = s:sub(1, -2)
    end
    return s .. "\226\128\166"  -- "…"
end

--- Helper: pad string to exactly w display cells.
local function pad_to_width(s, w)
    local dw = display_width(s)
    if dw >= w then return s end
    return s .. string.rep(" ", w - dw)
end

--- Draw the track list on the screen.
function list.draw(scr, playlist, theme, start_row, end_row)
    local vis   = playlist:visible()
    local count = #vis
    local sel   = playlist:selected_index()
    local pidx  = playlist:playing_index()
    local rows  = end_row - start_row + 1

    -- Compute scroll offset: keep the selected item visible
    local offset = list._offset or 0
    if sel <= offset then
        offset = sel - 1
    elseif sel > offset + rows then
        offset = sel - rows
    end
    if offset < 0 then offset = 0 end
    if offset > count - rows then
        offset = math.max(0, count - rows)
    end
    list._offset = offset

    local _, cols = scr:size()
    -- Width budget: [sel(1)] [icon(1)] [space] [idx(w)] [.] [space] [title...] [space] [dur]
    local idx_width = #tostring(count)
    if idx_width < 2 then idx_width = 2 end
    local dur_width = 6   -- "MM:SS\0"
    local fixed_overhead = 1 + 1 + 1 + idx_width + 1 + 1 + 1 + dur_width  -- ~14-16
    local title_width = cols - fixed_overhead
    if title_width < 10 then title_width = 10 end

    for i = 0, rows - 1 do
        local track_idx = offset + i + 1
        local row       = start_row + i

        if track_idx > count then
            -- Empty line
            scr:clear_line(row)
        else
            local t = vis[track_idx]
            local is_selected = (track_idx == sel)
            local is_playing  = (track_idx == pidx and pidx > 0)

            -- Icons
            local icon = " "
            if is_playing then
                icon = theme.playing_icon
            end

            local sel_mark = " "
            if is_selected then
                sel_mark = theme.selected_icon
            end

            -- Build line parts
            local idx_str = string.format("%" .. idx_width .. "d", track_idx)
            local title   = t.title or ""
            title = trunc_to_width(title, title_width)

            -- Duration (if available)
            local dur_str = ""
            if t.duration and type(t.duration) == "number" and t.duration > 0 then
                dur_str = time_util.format_seconds(t.duration)
            end

            -- Set colour/attribute
            if is_selected and is_playing then
                scr:set_attr(theme.color_selected, true)
            elseif is_playing then
                scr:set_color(theme.color_playing)
            elseif is_selected then
                scr:set_color(theme.color_selected)
            else
                scr:set_color(theme.color_normal)
            end

            -- Compose line
            scr:clear_line(row)
            local line = string.format(
                "%s%s %s. %s",
                sel_mark, icon, idx_str, title
            )
            scr:write(row, 1, line)

            -- Draw duration right-aligned in dim color
            if dur_str ~= "" then
                local dur_col = cols - dur_width + 1
                scr:set_color(theme.color_dim)
                scr:write(row, dur_col, dur_str)
            end

            scr:set_color(0)  -- reset
        end
    end

    -- Scroll indicator
    if count > rows then
        local pct = math.floor((offset + rows) / count * 100)
        local scroll_text = string.format(" %d%%", pct)
        scr:set_color(theme.color_dim)
        scr:write(end_row, cols - #scroll_text, scroll_text)
        scr:set_color(0)
    end
end

--- Reset scroll state.
function list.reset_scroll()
    list._offset = 0
end

return list
