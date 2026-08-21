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
        io.stderr:write("TUI error: " .. tostring(tui_err) .. "\n")
        os.exit(1)
    end
end

return app
