-- musiclua/tui/app.lua
-- Main TUI application: main loop, drawing, key handling

local scr_module   = require("musiclua.tui.screen")
local list_module  = require("musiclua.tui.list")
local input_module = require("musiclua.tui.input")
local helpbar_mod  = require("musiclua.tui.helpbar")
local statusbar_mod = require("musiclua.tui.statusbar")
local theme_module = require("musiclua.tui.theme")
local log          = require("musiclua.util.log")
local sys_ok, sys  = pcall(require, "system")

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
    local curses_keys = scr_module  -- ANSI backend: screen module has key constants

    -- TUI state
    local mode         = "normal"   -- "normal" | "search"
    local search_text  = ""
    local running      = true
    local message      = nil        -- transient status message

    ---------------------------------------------------------------------------
    -- Drawing
    ---------------------------------------------------------------------------
    local function draw()
        scr:begin_frame()
        local rows, cols = scr:size()

        -- Row 1: Title bar (bold cyan, with playing track info)
        scr:set_attr(theme.color_title, true)
        local title_line = " " .. theme.header_prefix .. theme.app_title
        scr:write(1, 1, title_line)

        -- Show playing track in title bar (right-aligned)
        local playing = playlist:playing_track()
        if playing and mode ~= "search" then
            local pt = playing.title or ""
            if sys_ok and sys.utf8swidth then
                local dw = sys.utf8swidth(pt) or #pt
                if dw > cols - #title_line - 6 then
                    while #pt > 0 and (sys.utf8swidth(pt) or #pt) > cols - #title_line - 8 do
                        pt = pt:sub(1, -2)
                    end
                    pt = pt .. "\226\128\166"
                end
            end
            scr:set_color(theme.color_dim)
            local right_text = "  " .. theme.playing_icon .. " " .. pt .. " "
            local right_col = cols - #right_text + 1
            if right_col > #title_line + 2 then
                scr:write(1, right_col, right_text)
            end
        end

        -- Filter indicator
        if playlist:get_filter() then
            scr:set_attr(theme.color_accent, false)
            scr:write(1, #title_line + 1, " [" .. playlist:get_filter() .. "]")
        end

        -- Row 2: Track count header + separator
        scr:set_color(theme.color_dim)
        local count = playlist:count()
        local header = string.format("  %d track(s)", count)
        scr:clear_line(2)
        scr:write(2, 1, header)
        scr:set_color(theme.color_dim)
        local sep_start = #header + 2
        if sep_start < cols then
            scr:write(2, sep_start, string.rep(theme.separator, cols - sep_start + 1))
        end

        -- Track list area: rows 3 to (rows - 6)
        -- Bottom area:
        --   rows-5: separator
        --   rows-4: status row 1 (track title)
        --   rows-3: status row 2 (progress bar)
        --   rows-2: status row 3 (info)
        --   rows-1: separator
        --   rows:   help bar
        local list_start = 3
        local list_end   = math.max(list_start, rows - 6)
        if count == 0 then
            scr:clear_line(list_start)
            scr:set_color(theme.color_dim)
            scr:write(list_start, 3, "No audio files found. Press q to quit.")
        else
            list_module.draw(scr, playlist, theme, list_start, list_end)
        end

        -- Separator line above status
        local sep_row = rows - 5
        scr:clear_line(sep_row)
        scr:set_color(theme.color_dim)
        scr:write(sep_row, 1, string.rep(theme.separator, cols))

        -- Status bar: 3 rows starting at (rows - 4)
        local status_row = rows - 4
        statusbar_mod.draw(scr, status_row, playlist, player, theme, mode, search_text)

        -- Help bar separator + help
        local help_sep = rows - 1
        scr:clear_line(help_sep)
        scr:set_color(theme.color_dim)
        scr:write(help_sep, 1, string.rep(theme.separator, cols))
        helpbar_mod.draw(scr, mode, theme)

        -- Transient message (overlay on help line if present)
        if message then
            scr:clear_line(rows)
            scr:set_color(theme.color_status)
            scr:write(rows, 1, " " .. message)
            scr:set_color(0)
            message = nil  -- show only once
        end

        scr:refresh()
    end

    -- Helper: check if player is functional
    local function player_ok()
        if not player then return false end
        if player._available == false then
            message = "mpv not available — install mpv to play audio"
            return false
        end
        return true
    end

    ---------------------------------------------------------------------------
    -- Key handling
    ---------------------------------------------------------------------------
    local function handle_normal_key(key, keytype)
        local action = input_module.map_key(key, curses_keys, keytype)
        if not action then return end

        if action == "quit" then
            running = false

        elseif action == "down" then
            playlist:move_down()

        elseif action == "up" then
            playlist:move_up()

        elseif action == "play" then
            local t = playlist:current()
            if t and player_ok() then
                playlist:set_playing_to_selected()
                player:load(t)
                player:play()
            end

        elseif action == "toggle" then
            if player_ok() then player:toggle() end

        elseif action == "next" then
            local t = playlist:next()
            if t and player_ok() then
                player:load(t)
                player:play()
            end

        elseif action == "prev" then
            local t = playlist:prev()
            if t and player_ok() then
                player:load(t)
                player:play()
            end

        elseif action == "vol_up" then
            if player_ok() then
                local v = player:get_volume() or 80
                player:set_volume(math.min(100, v + 5))
            end

        elseif action == "vol_down" then
            if player_ok() then
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

    local function handle_search_key(key, keytype)
        if keytype == "ctrl" and (key == "\n" or key == "\r") then
            -- Apply filter
            playlist:filter(search_text)
            list_module.reset_scroll()
            mode = "normal"

        elseif keytype == "ctrl" and key == "\27" then
            -- Cancel search
            mode = "normal"
            search_text = ""

        elseif keytype == "ctrl" and (key == "\127" or key == "\8") then
            -- Backspace: remove last UTF-8 character (not just last byte)
            if #search_text > 0 then
                -- Find start of last UTF-8 character
                local i = #search_text
                while i > 1 do
                    local b = search_text:byte(i)
                    if b >= 0x80 and b < 0xC0 then
                        i = i - 1  -- continuation byte, keep going
                    else
                        break
                    end
                end
                search_text = search_text:sub(1, i - 1)
            end

        else
            local ch = input_module.char_for(key, keytype)
            if ch then
                search_text = search_text .. ch
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Main loop (getch timeout replaces os.execute sleep)
    ---------------------------------------------------------------------------
    while running do
        draw()

        -- getch blocks for up to 50ms, acting as both input and frame limiter
        local key, keytype = scr:getch(0.05)
        if key then
            if mode == "search" then
                handle_search_key(key, keytype)
            else
                handle_normal_key(key, keytype)
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Cleanup
    ---------------------------------------------------------------------------
    local cleanup_ok, cleanup_err = pcall(function()
        scr:cleanup()
    end)
    if not cleanup_ok then
        log.warn("screen cleanup error:", cleanup_err)
    end
    if player then
        local player_ok, player_err = pcall(function()
            player:close()
        end)
        if not player_ok then
            log.warn("player close error:", player_err)
        end
    end
end

return app
