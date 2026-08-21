# musiclua

A modular, extensible terminal music player written in Lua.

## Features

- **Local music scanning** — auto-scan directories for audio files (mp3, flac, ogg, wav, aac, m4a, opus, wma)
- **Playback control** — play/pause, next/prev, seek, volume, progress bar
- **Curses TUI** — keyboard-driven terminal interface with playlist view and metadata display
- **Playlist modes** — sequential, repeat-all, repeat-one, shuffle
- **Sorting** — by title, artist, album, date, or path
- **M3U/M3U8 support** — load playlists with metadata
- **RSS/Podcast** — subscribe to feeds, auto-download episodes
- **URL streaming** — play audio directly from URLs
- **Modular sources** — local_dir, m3u, rss, url (easily extensible)
- **Modular players** — mpv backend (system player fallback planned)

## Requirements

- Lua 5.4+
- mpv (for audio playback)
- LuaRocks packages:
  - `luafilesystem` — directory scanning
  - `luasocket` — networking
  - `luasec` — HTTPS support
  - `dkjson` — JSON parsing

## Installation

```sh
# Install mpv (macOS)
brew install mpv

# Install Lua dependencies
luarocks install luafilesystem
luarocks install luasocket
luarocks install luasec
luarocks install dkjson

# Install musiclua from rockspec
luarocks make rockspecs/musiclua-scm-1.rockspec
```

## Quick Start

```sh
# Scan and play a directory
./bin/musiclua play ~/Music

# Non-interactive scan (prints track list)
./bin/musiclua scan ~/Music

# Interactive TUI (auto-scan if tracks found)
./bin/musiclua
```

## Usage

### CLI Commands

```sh
# Play a directory
musiclua play ~/Music

# Play with options
musiclua play ~/Music --recursive --sort title --mode shuffle

# Scan without playing
musiclua scan ~/Music

# Play a URL directly
musiclua play-url https://example.com/song.mp3

# Import RSS feed tracks into library
musiclua add-rss https://example.com/podcast.xml

# Other options
musiclua --config ~/.musiclua/config.lua
musiclua --library ~/Music  --playlists ~/Playlists
musiclua --player system
```

### TUI Keybindings

| Key | Action |
|-----|--------|
| `space` | Play / Pause |
| `n` / `p` | Next / Previous track |
| `s` | Stop |
| `←` / `→` | Seek -5s / +5s |
| `-` / `+` | Volume down / up |
| `j` / `k` | Move down / up in playlist |
| `Enter` | Play selected track |
| `d` | Remove track from playlist |
| `c` | Clear playlist |
| `r` | Refresh / rescan library |
| `m` | Cycle play mode |
| `/` | Search / filter |
| `q` | Quit |
| `?` | Toggle help bar |

### Play Modes

Press `m` to cycle through modes:

- **sequential** — play in order, stop at end
- **repeat-all** — loop the entire playlist
- **repeat-one** — repeat current track
- **shuffle** — random order, visit all tracks

### Configuration

Copy the example config:

```sh
cp config.example.lua ~/.musiclua/config.lua
```

Edit to set your library path, playlists directory, player backend, and keybindings:

```lua
return {
    library_dir = "~/Music",
    playlists_dir = "~/.musiclua/playlists",
    player = "mpv",
    scan = {
        recursive = true,
        extensions = { "mp3", "flac", "ogg", "wav", "aac", "m4a", "opus", "wma" },
    },
    keys = {
        play_pause = " ",
        next = "n",
        prev = "p",
        quit = "q",
    },
}
```

## Running Tests

```sh
busted spec/
```

## Project Structure

```
musiclua/
├── musiclua/          # Core library modules
│   ├── app.lua        # High-level orchestrator
│   ├── library.lua    # Collection + playlist registry
│   ├── playlist.lua   # Playlist management + play modes
│   ├── track.lua      # Track metadata
│   ├── config.lua     # Configuration loading
│   ├── sources/       # Music sources (local_dir, m3u, rss, url)
│   ├── players/       # Player backends (mpv, system)
│   ├── tui/           # Curses-based terminal UI
│   └── util/          # Utilities (fs, json, log, time, http)
├── bin/musiclua       # CLI entry point
├── examples/          # Example scripts
├── spec/              # Test suite
└── rockspecs/         # LuaRocks package spec
```

### Future Releases

For each new version (e.g., v0.4.0):

```sh
# 1. Update version in musiclua/version.lua
# 2. Create new rockspec: rockspecs/musiclua-0.4.0-1.rockspec
# 3. Tag and push
git tag v0.4.0
git push origin v0.4.0

# 4. Upload
luarocks upload rockspecs/musiclua-0.4.0-1.rockspec --api-key=YOUR_API_KEY
```

## License

MIT
