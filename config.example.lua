-- config.example.lua
-- Example musiclua configuration file.
-- Copy this to ~/.config/musiclua/config.lua and edit as needed.

return {
    -- Directories to scan for audio files.
    library_dirs = {
        "~/Music",
    },

    -- Audio file extensions to recognise.
    audio_extensions = {
        ".mp3", ".ogg", ".wav", ".flac", ".m4a", ".opus",
    },

    -- Player backend ("mpv" is the only supported option for now).
    player = "mpv",

    -- TUI settings.
    tui = {
        theme          = "default",
        show_helpbar   = true,
        show_statusbar = true,
    },

    -- mpv-specific settings.
    mpv = {
        ipc_path = nil,       -- nil = auto-generate /tmp/musiclua-<time>.sock
        volume   = 80,        -- initial volume 0-100
        autoplay = false,     -- start playing immediately on launch
    },

    -- Log level: "debug", "info", "warn", "error".
    log_level = "warn",
}
