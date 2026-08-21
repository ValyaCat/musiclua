-- musiclua/tui/helpbar.lua
-- Help bar component showing key bindings with styled keys

local helpbar = {}

--- Help entries as { key, action } pairs for normal mode.
local NORMAL_KEYS = {
    {"enter", "play"},
    {"space", "pause"},
    {"n", "next"},
    {"p", "prev"},
    {"m", "mode"},
    {"/", "search"},
    {"+/-", "vol"},
    {"q", "quit"},
}

--- Help entries for search mode.
local SEARCH_KEYS = {
    {"enter", "confirm"},
    {"esc", "cancel"},
    {"bs", "delete"},
}

--- Draw the help bar on the last row of the screen.
function helpbar.draw(scr, mode, theme)
    local rows, cols = scr:size()
    local help_row = rows
    scr:clear_line(help_row)

    local keys = (mode == "search") and SEARCH_KEYS or NORMAL_KEYS
    local col = 2  -- start with 1-space indent

    for i, entry in ipairs(keys) do
        local key, action = entry[1], entry[2]
        -- Key name in bright color
        scr:set_color(theme.color_key)
        scr:write(help_row, col, key)
        col = col + #key
        -- Action in dim color
        scr:set_color(theme.color_dim)
        local action_text = " " .. action
        scr:write(help_row, col, action_text)
        col = col + #action_text
        -- Separator between entries
        if i < #keys then
            scr:write(help_row, col, "  ")
            col = col + 2
        end
        if col >= cols - 2 then break end
    end
    scr:set_color(0)
end

return helpbar
