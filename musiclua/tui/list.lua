-- musiclua/tui/list.lua
-- Track list component for the TUI

local list = {}

--- Draw the track list on the screen.
-- @param scr        screen object
-- @param playlist   Playlist instance
-- @param theme      theme table
-- @param start_row  number  first row for the list
-- @param end_row    number  last row for the list (inclusive)
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
    -- Width available for the title (subtract index + icons + padding)
    local idx_width = #tostring(count) + 1  -- at least "1 "
    if idx_width < 4 then idx_width = 4 end
    local title_width = cols - idx_width - 6  -- 6 for icons and margins

    for i = 0, rows - 1 do
        local track_idx = offset + i + 1
        local row       = start_row + i
        scr:clear_line(row)

        if track_idx > count then
            -- Empty line – nothing to draw
        else
            local t = vis[track_idx]
            local is_selected = (track_idx == sel)
            local is_playing  = (track_idx == pidx and pidx > 0)

            -- Determine icon
            local icon = " "
            if is_playing then
                icon = theme.playing_icon
            end

            -- Selection marker
            local sel_mark = " "
            if is_selected then
                sel_mark = theme.selected_icon
            end

            -- Build the line
            local idx_str = string.format("%" .. (idx_width - 1) .. "d", track_idx)
            local title   = t.title or ""
            if #title > title_width then
                title = title:sub(1, title_width - 1) .. "…"
            end

            local line = string.format(
                "%s %s %s  %s",
                sel_mark, icon, idx_str, title
            )

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

            scr:write(row, 1, line)
            scr:set_color(0)  -- reset
        end
    end
end

--- Reset scroll state.
function list.reset_scroll()
    list._offset = 0
end

return list
