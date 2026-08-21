-- examples/play_local.lua
-- Example: scan a local directory and print tracks (no TUI)

-- Adjust package path so we can require from project root
package.path = package.path .. ";./?.lua;./?/init.lua"

local library = require("musiclua.library")

local dir = arg[1] or "./test_music_scan"

print("Scanning: " .. dir)
print(string.rep("-", 40))

local tracks, err = library.scan_dir(dir)

if not tracks then
    print("Error: " .. tostring(err))
    os.exit(1)
end

if #tracks == 0 then
    print("No audio files found.")
    os.exit(0)
end

for i, t in ipairs(tracks) do
    print(string.format("%3d  %-30s  %s", i, t.title, t.path))
end

print(string.rep("-", 40))
print(string.format("Total: %d track(s)", #tracks))
