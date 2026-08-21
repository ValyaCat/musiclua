-- musiclua/tui/helpbar.lua
-- Help bar component showing key bindings

local helpbar = {}

--- Default help text for normal mode.
helpbar.NORMAL_HELP = "[enter] play  [space] pause  [n] next  [p] prev  [m] mode  [/] search  [+/-] vol  [q] quit"

--- Help text shown while in search mode.
helpbar.SEARCH_HELP = "[enter] confirm  [esc] cancel  [backspace] delete"

--- Draw the help bar on the last row of the screen.
-- @param scr     screen object
-- @param mode    string  "normal" or "search"
-- @param theme   theme table
function helpbar.draw(scr, mode, theme)
    local rows, cols = scr:size()
    local help_row = rows
    scr:clear_line(help_row)

    local text = (mode == "search") and helpbar.SEARCH_HELP or helpbar.NORMAL_HELP
    if #text > cols then
        text = text:sub(1, cols)
    end

    scr:set_color(theme.color_help)
    scr:write(help_row, 1, text)
    scr:set_color(0)
end

return helpbar
