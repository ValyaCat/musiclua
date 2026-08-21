-- musiclua/app.lua
-- Application orchestration layer: connects library, playlist, player, and TUI

local library  = require("musiclua.library")
local Playlist = require("musiclua.playlist")
local players  = require("musiclua.players")
local tui      = require("musiclua.tui")
local config   = require("musiclua.config")
local fs       = require("musiclua.util.fs")
local log      = require("musiclua.util.log")

local app = {}

--- Run the full application.
-- @param cli_args table  parsed command-line arguments { directory = string }
function app.run(cli_args)
    cli_args = cli_args or {}

    -- 1. Load configuration
    local cfg = config.load()
    cfg = config.apply_cli(cfg, cli_args)

    -- Set log level
    log.set_level(cfg.log_level or "warn")

    -- 2. Resolve library directories
    local dirs = {}
    for _, d in ipairs(cfg.library_dirs or {}) do
        local expanded = fs.expand_user(d)
        if fs.is_dir(expanded) then
            dirs[#dirs + 1] = expanded
        else
            log.warn("directory does not exist, skipping:", expanded)
        end
    end

    if #dirs == 0 then
        io.stderr:write("Error: no valid library directories found.\n")
        io.stderr:write("Create ~/Music or specify a directory:\n")
        io.stderr:write("  musiclua /path/to/music\n")
        os.exit(1)
    end

    -- 3. Scan library
    log.info("scanning", #dirs, "director(ies)...")
    local tracks = library.scan_dirs(dirs, {
        extensions = cfg.audio_extensions,
        recursive  = cfg.recursive,
        sort       = cfg.sort,
    })
    log.info("found", #tracks, "track(s)")

    -- 4. Create playlist
    local playlist = Playlist.new(tracks)
    if cfg.play_mode then
        playlist:set_mode(cfg.play_mode)
    end

    -- 5. Create player
    local player_ok, player = pcall(players.create, cfg.player, {
        ipc_path = cfg.mpv.ipc_path,
        volume   = cfg.mpv.volume,
    })
    if not player_ok then
        io.stderr:write("Error: " .. tostring(player) .. "\n")
        os.exit(1)
    end

    -- 6. Launch TUI (this blocks until the user quits)
    local tui_ok, tui_err = pcall(tui.run, {
        playlist = playlist,
        player   = player,
    })

    -- 7. Ensure cleanup even if TUI crashes
    pcall(function() player:close() end)

    if not tui_ok then
        local err_str = tostring(tui_err)
        -- Re-throw TUI backend errors so the CLI fallback can catch them
        if err_str:find("curses") or err_str:find("luasystem") then
            error(tui_err)
        end
        io.stderr:write("TUI error: " .. err_str .. "\n")
        os.exit(1)
    end
end

--- Run in CLI mode (no TUI, uses mpv directly).
-- Plays tracks sequentially from the command line with a polished UI.
-- @param cli_args table  parsed command-line arguments
function app.run_cli(cli_args)
    cli_args = cli_args or {}

    -- ANSI colors
    local c = {
        reset    = "\27[0m",
        bold     = "\27[1m",
        dim      = "\27[2m",
        italic   = "\27[3m",
        cyan     = "\27[36m",
        green    = "\27[32m",
        yellow   = "\27[33m",
        magenta  = "\27[35m",
        white    = "\27[97m",
        gray     = "\27[90m",
    }

    local cfg = config.load()
    cfg = config.apply_cli(cfg, cli_args)
    log.set_level("error")

    -- Resolve library directories
    local dirs = {}
    for _, d in ipairs(cfg.library_dirs or {}) do
        local expanded = fs.expand_user(d)
        if fs.is_dir(expanded) then
            dirs[#dirs + 1] = expanded
        end
    end

    if #dirs == 0 then
        io.stderr:write("\n  " .. c.yellow .. "!" .. c.reset .. " No valid directories found.\n")
        io.stderr:write("  " .. c.gray .. "Try: musiclua /path/to/music" .. c.reset .. "\n\n")
        os.exit(1)
    end

    -- Scan
    local tracks = library.scan_dirs(dirs, {
        extensions = cfg.audio_extensions,
        recursive  = cfg.recursive,
        sort       = cfg.sort,
    })

    if #tracks == 0 then
        io.stderr:write("\n  " .. c.yellow .. "!" .. c.reset .. " No audio files found.\n\n")
        os.exit(1)
    end

    -- Terminal dimensions: 80 cols × 24 rows
    local TERM_W = 80
    local TERM_H = 24
    local W = TERM_W - 2  -- inner width (78, between │ borders)
    local B = c.cyan       -- border color

    -- Helper: calculate display width of a string (UTF-8 + emoji aware)
    local function display_width(s)
        s = s:gsub("\27%[[%d;]*m", "")
        local width, i, len = 0, 1, #s
        while i <= len do
            local b = s:byte(i)
            if b < 0x80 then
                i = i + 1; width = width + 1
            elseif b < 0xC0 then
                i = i + 1; width = width + 1
            elseif b < 0xE0 then
                i = i + 2; width = width + 1
            elseif b < 0xF0 then
                i = i + 3; width = width + 1
            else
                i = i + 4; width = width + 2
            end
        end
        return width
    end

    -- Helper: truncate to max display width
    local function trunc_display(s, max_w)
        if display_width(s) <= max_w then return s end
        return s:sub(1, max_w - 3) .. "..."
    end

    -- Helper: write a bordered line (fills full width)
    local function line(inner)
        inner = inner or ""
        local dw = display_width(inner)
        local pad = W - dw
        if pad < 0 then pad = 0 end
        io.write(B .. "│" .. c.reset .. inner .. string.rep(" ", pad) .. B .. "│" .. c.reset .. "\n")
    end

    -- Helper: horizontal border
    local function hline(left, fill, right)
        io.write(B .. left .. string.rep(fill, W) .. right .. c.reset .. "\n")
    end

    -- Helper: centered text
    local function centered(text)
        local dw = display_width(text)
        local left_pad = math.floor((W - dw) / 2)
        if left_pad < 0 then left_pad = 0 end
        return string.rep(" ", left_pad) .. text
    end

    local max_title = W - 12

    -- ═══ Layout calculation ═══
    -- Row 1:  ╔═╗
    -- Row 2:  title
    -- Row 3:  ╠═╣
    -- Row 4:  blank
    -- Row 5+: playlist (up to max_playlist rows)
    -- After playlist: blank, controls, ╠─╣, blank, now-playing(2), blank, ╠═╣, done, ╚═╝
    -- Fixed rows outside playlist: 1+1+1+1 +1+1+1+1+2+1+1+1+1 = 14
    local fixed = 14
    local max_playlist = TERM_H - fixed
    if max_playlist < 2 then max_playlist = 2 end
    local show_count = math.min(#tracks, max_playlist)

    -- Row positions (1-based)
    local playlist_start = 5
    local now_playing_row = playlist_start + show_count + 3

    -- Cursor helpers
    local function goto_row(row)
        io.write(string.format("\27[%d;1H", row))
    end

    local function clear_line()
        io.write("\27[2K\r")
    end

    -- ═══ Draw full static UI ═══
    io.write("\27[2J\27[H")  -- clear screen, cursor to top-left

    -- Top
    hline("╔", "═", "╗")
    local title_text = c.bold .. "♪  musiclua" .. c.reset
        .. c.gray .. "  ·  " .. #tracks .. " track(s)" .. c.reset
    line(centered(title_text))
    hline("╠", "═", "╣")
    line("")

    -- Playlist entries
    for i = 1, show_count do
        local t = tracks[i]
        local title = t.title or fs.basename(t.path)
        title = title:gsub("%.[%w]+$", "")
        if display_width(title) > max_title then
            title = trunc_display(title, max_title)
        end
        line("    " .. c.gray .. string.format("%3d.", i) .. c.reset .. "  " .. title)
    end
    if #tracks > show_count then
        line("        " .. c.gray .. "... and " .. (#tracks - show_count) .. " more" .. c.reset)
    end

    -- Fill remaining rows
    local shown = show_count
    if #tracks > show_count then shown = shown + 1 end
    for _ = 1, max_playlist - shown do
        line("")
    end

    -- Bottom section (static frame)
    line("    " .. c.gray .. "Controls:  "
        .. c.white .. "space" .. c.gray .. " pause   "
        .. c.white .. "q" .. c.gray .. " quit" .. c.reset)
    hline("╠", "─", "╣")
    line("")
    -- Now playing area: 2 rows (will be updated in-place)
    line("")  -- placeholder row 1: track name
    line("")  -- placeholder row 2: progress
    line("")  -- blank
    hline("╠", "═", "╣")
    line(centered(c.gray .. "Waiting..." .. c.reset))
    hline("╚", "═", "╝")

    -- ═══ Playback loop (in-place updates) ═══
    for i, t in ipairs(tracks) do
        local title = t.title or fs.basename(t.path)
        title = title:gsub("%.[%w]+$", "")
        if display_width(title) > max_title then
            title = trunc_display(title, max_title)
        end

        -- Update now-playing row 1: show ▶
        goto_row(now_playing_row)
        clear_line()
        line("    " .. c.cyan .. c.bold .. "▶" .. c.reset
            .. "  " .. c.white .. title .. c.reset)

        -- Update now-playing row 2: track counter
        goto_row(now_playing_row + 1)
        clear_line()
        line("       " .. c.gray .. string.format("%d of %d", i, #tracks) .. c.reset)

        -- Play with mpv silently
        local escaped = t.path:gsub('"', '\\"')
        local cmd = string.format('mpv --no-video --really-quiet "%s"', escaped)
        os.execute(cmd)

        -- Update now-playing to show ✓
        goto_row(now_playing_row)
        clear_line()
        line("    " .. c.green .. "✓" .. c.reset
            .. "  " .. c.gray .. title .. c.reset)
        goto_row(now_playing_row + 1)
        clear_line()
        line("")

        -- Also update the playlist entry to show ✓
        if i <= show_count then
            local entry_row = playlist_start + i - 1
            goto_row(entry_row)
            clear_line()
            line("    " .. c.green .. " ✓ " .. c.reset .. c.gray .. title .. c.reset)
        end

        -- Update footer
        goto_row(TERM_H - 1)
        clear_line()
        if i < #tracks then
            line(centered(c.gray .. "Playing " .. i .. "/" .. #tracks .. "..." .. c.reset))
        else
            line(centered(c.green .. c.bold .. "✓  All done — " .. #tracks .. " track(s) played" .. c.reset))
        end
    end

    -- Position cursor below the box (no extra newline)
    goto_row(TERM_H + 1)
end

return app
