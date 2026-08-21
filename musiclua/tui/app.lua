-- musiclua/tui/app.lua
-- Main TUI application: main loop, drawing, key handling

local scr_module   = require("musiclua.tui.screen")
local list_module  = require("musiclua.tui.list")
local input_module = require("musiclua.tui.input")
local helpbar_mod  = require("musiclua.tui.helpbar")
local statusbar_mod = require("musiclua.tui.statusbar")
local theme_module = require("musiclua.tui.theme")
local log          = require("musiclua.util.log")

local app = {}

--- Run the TUI.
-- @param opts table  { playlist = Playlist, player = MpvPlayer }
function app.run(opts)
    opts = opts or {}
    local playlist = opts.playlist
    local player   = opts.player

    if not playlist then
        error("tui.app.run(): playlist is required")
    end

    local theme = theme_module.get()
    local scr   = scr_module.init()
    local curses_keys = scr_module.keys()

    -- TUI state
    local mode         = "normal"   -- "normal" | "search"
    local search_text  = ""
    local running      = true
    local message      = nil        -- transient status message

    ---------------------------------------------------------------------------
    -- Drawing
    ---------------------------------------------------------------------------
    local function draw()
        scr:clear()
        local rows, cols = scr:size()

        -- Row 1: Title bar
        scr:set_attr(theme.color_title, true)
        local title_line = " " .. theme.app_title
        if playlist:get_filter() then
            title_line = title_line .. "  [" .. playlist:get_filter() .. "]"
        end
        scr:clear_line(1)
        scr:write(1, 1, title_line)
        scr:set_color(0)

        -- Row 2: Column header
        scr:clear_line(2)
        local count = playlist:count()
        local header = string.format("  %d track(s)", count)
        scr:set_color(theme.color_status)
        scr:write(2, 1, header)
        scr:set_color(0)

        -- Track list area: rows 3 to (rows - 4)
        -- Reserve bottom rows: statusbar (2 rows) + helpbar (1 row)
        local list_start = 3
        local list_end   = math.max(list_start, rows - 4)
        if count == 0 then
            scr:clear_line(list_start)
            scr:write(list_start, 2, "No audio files found.")
        else
            list_module.draw(scr, playlist, theme, list_start, list_end)
        end

        -- Status bar: rows (rows - 2) and (rows - 1)
        local status_row = rows - 2
        statusbar_mod.draw(scr, status_row, playlist, player, theme, mode, search_text)

        -- Help bar: last row
        helpbar_mod.draw(scr, mode, theme)

        -- Transient message (if any)
        if message then
            scr:clear_line(rows - 1)
            scr:set_color(theme.color_status)
            scr:write(rows - 1, 1, " " .. message)
            scr:set_color(0)
            message = nil  -- show only once
        end

        -- Search cursor
        if mode == "search" then
            scr:write(rows - 2, 11 + #search_text, "")
        end

        scr:refresh()
    end

    ---------------------------------------------------------------------------
    -- Key handling
    ---------------------------------------------------------------------------
    local function handle_normal_key(key)
        local action = input_module.map_key(key, curses_keys)
        if not action then return end

        if action == "quit" then
            running = false

        elseif action == "down" then
            playlist:move_down()

        elseif action == "up" then
            playlist:move_up()

        elseif action == "play" then
            local t = playlist:current()
            if t and player then
                playlist:set_playing_to_selected()
                player:load(t)
                player:play()
            end

        elseif action == "toggle" then
            if player then player:toggle() end

        elseif action == "next" then
            local t = playlist:next()
            if t and player then
                player:load(t)
                player:play()
            end

        elseif action == "prev" then
            local t = playlist:prev()
            if t and player then
                player:load(t)
                player:play()
            end

        elseif action == "vol_up" then
            if player then
                local v = player:get_volume() or 80
                player:set_volume(math.min(100, v + 5))
            end

        elseif action == "vol_down" then
            if player then
                local v = player:get_volume() or 80
                player:set_volume(math.max(0, v - 5))
            end

        elseif action == "mode" then
            local new_mode = playlist:cycle_mode()
            message = "Play mode: " .. new_mode

        elseif action == "search" then
            mode = "search"
            search_text = ""

        elseif action == "esc" then
            playlist:clear_filter()
            list_module.reset_scroll()
        end
    end

    local function handle_search_key(key)
        if key == input_module.KEY_ENTER then
            -- Apply filter
            playlist:filter(search_text)
            list_module.reset_scroll()
            mode = "normal"

        elseif key == input_module.KEY_ESC then
            -- Cancel search
            mode = "normal"
            search_text = ""

        elseif key == input_module.KEY_BACKSPACE or key == input_module.KEY_CTRL_H then
            search_text = search_text:sub(1, -2)

        else
            local ch = input_module.char_for(key)
            if ch then
                search_text = search_text .. ch
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Main loop
    ---------------------------------------------------------------------------
    -- Use a short sleep to keep CPU usage low while remaining responsive
    local frame_interval = 0.05  -- 50 ms

    while running do
        draw()

        local key = scr:getch()
        if key then
            if mode == "search" then
                handle_search_key(key)
            else
                handle_normal_key(key)
            end
        end

        -- Sleep
        os.execute(string.format("sleep %.2f", frame_interval))
    end

    ---------------------------------------------------------------------------
    -- Cleanup
    ---------------------------------------------------------------------------
    scr:cleanup()
    if player then
        player:close()
    end
end

return app
