-- musiclua/tui/theme.lua
-- Default theme configuration

local theme = {}

theme.default = {
    -- Icons
    playing_icon    = "▶",
    paused_icon     = "❚❚",
    stopped_icon    = " ",
    selected_icon   = ">",

    -- Status text
    playing_text    = "playing",
    paused_text     = "paused",
    stopped_text    = "stopped",
    loading_text    = "loading",

    -- Colours (curses color-pair IDs, defined in screen.lua)
    color_title     = 1,
    color_selected  = 2,
    color_playing   = 3,
    color_status    = 4,
    color_help      = 5,
    color_normal    = 0,  -- default terminal color

    -- Title
    app_title       = "musiclua",
}

--- Return the current theme (for now always default).
-- @param name string?
-- @return table
function theme.get(name)
    return theme.default
end

return theme
