-- musiclua/tui/theme.lua
-- Default theme configuration

local theme = {}

theme.default = {
    -- Icons (UTF-8)
    playing_icon    = "\226\150\182",           -- ▶ U+25B6
    paused_icon     = "\226\158\186",           -- ⏸ U+23F8
    stopped_icon    = "\194\183",               -- · U+00B7
    selected_icon   = "\226\150\184",           -- ▸ U+25B8

    -- Status text
    playing_text    = "playing",
    paused_text     = "paused",
    stopped_text    = "stopped",
    loading_text    = "loading",

    -- Colours (pair IDs defined in screen.lua)
    color_title     = 1,   -- cyan (bold)
    color_selected  = 2,   -- black on white
    color_playing   = 3,   -- green
    color_status    = 4,   -- yellow
    color_help      = 5,   -- white
    color_normal    = 0,   -- default
    color_dim       = 6,   -- dim gray (borders, separators)
    color_accent    = 7,   -- bright cyan
    color_bar_fg    = 8,   -- bright cyan (progress filled)
    color_bar_bg    = 9,   -- dim gray (progress empty)
    color_bar_time  = 10,  -- white (time labels)
    color_key       = 11,  -- bright white (help bar keys)

    -- Progress bar characters
    bar_full        = "\226\150\136",           -- █ U+2588 full block
    bar_right       = "\226\150\144",           -- ▐ U+2590 right half (sub-cell precision)
    bar_empty       = "\226\150\145",           -- ░ U+2591 light shade
    bar_thumb       = "\226\150\136",           -- █ U+2588 (playhead thumb)

    -- Visual tokens
    separator       = "\226\148\128",           -- ─ U+2500
    header_prefix   = "\226\153\170 ",          -- ♪ U+266A

    -- Title
    app_title       = "musiclua",
}

--- Return the current theme (for now always default).
function theme.get(name)
    return theme.default
end

return theme
