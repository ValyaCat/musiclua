-- musiclua/config.lua
-- Configuration management: defaults, loading, merging

local fs = require("musiclua.util.fs")
local log = require("musiclua.util.log")

local config = {}

--- Default configuration values.
config.defaults = {
    library_dirs = {
        "~/Music",
    },
    audio_extensions = {
        ".mp3", ".ogg", ".wav", ".flac", ".m4a", ".aac", ".opus", ".wma",
    },
    player    = "mpv",
    recursive = false,        -- scan subdirectories
    sort      = "title",      -- "title", "artist", "album", "date", "path"
    play_mode = "repeat-all", -- "sequential", "repeat-all", "repeat-one", "shuffle"
    tui = {
        theme        = "default",
        show_helpbar  = true,
        show_statusbar = true,
    },
    mpv = {
        ipc_path  = nil,
        volume    = 80,
        autoplay  = false,
    },
    cache_dir = "~/.cache/musiclua",
    log_level = "warn",
}

--- Deep-merge user config over defaults (recursive).
-- @param base  table  defaults
-- @param over  table  user overrides
-- @return table merged result
local function deep_merge(base, over)
    local result = {}
    for k, v in pairs(base) do
        if type(v) == "table" then
            result[k] = {}  -- shallow copy base table
            for k2, v2 in pairs(v) do result[k][k2] = v2 end
        else
            result[k] = v
        end
    end
    for k, v in pairs(over) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = deep_merge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

--- Load configuration from the standard config file.
-- Looks for: ~/.config/musiclua/config.lua
-- @return table  merged configuration
function config.load()
    local cfg = config.defaults

    local config_path = fs.expand_user("~/.config/musiclua/config.lua")
    if fs.is_file(config_path) then
        local ok, user_cfg = pcall(dofile, config_path)
        if ok and type(user_cfg) == "table" then
            cfg = deep_merge(cfg, user_cfg)
            log.info("loaded config from", config_path)
        else
            log.warn("failed to load config:", user_cfg)
        end
    end

    return cfg
end

--- Apply command-line overrides onto a config table.
-- @param cfg   table   existing config
-- @param args  table   parsed CLI arguments { directory = string, volume = number, ... }
-- @return table
function config.apply_cli(cfg, args)
    args = args or {}
    if args.directory then
        cfg.library_dirs = { args.directory }
    end
    if args.volume then
        cfg.mpv.volume = args.volume
    end
    if args.log_level then
        cfg.log_level = args.log_level
    end
    if args.recursive ~= nil then
        cfg.recursive = args.recursive
    end
    if args.sort then
        cfg.sort = args.sort
    end
    if args.play_mode then
        cfg.play_mode = args.play_mode
    end
    return cfg
end

return config
