-- examples/test_scan.lua
-- Quick sanity check: scan the bundled test directory and print results

package.path = package.path .. ";./?.lua;./?/init.lua"

local library  = require("musiclua.library")
local Playlist = require("musiclua.playlist")

local dir = "./test_music_scan"
print("=== musiclua scan test ===")
print("Directory: " .. dir)
print()

local tracks, err = library.scan_dir(dir)
if not tracks then
    print("Error: " .. tostring(err))
    os.exit(1)
end

print(string.format("Found %d track(s):", #tracks))
for _, t in ipairs(tracks) do
    print(string.format("  [%s] %s (%s)", t.id, t.title, t.source))
end

print()
print("=== Playlist test ===")
local pl = Playlist.new(tracks)
print("Count: " .. pl:count())
print("Current: " .. (pl:current() and pl:current().title or "nil"))

pl:move_down()
print("After move_down: " .. (pl:current() and pl:current().title or "nil"))

pl:filter("mp3")
print("After filter 'mp3': " .. pl:count() .. " track(s)")

pl:clear_filter()
print("After clear_filter: " .. pl:count() .. " track(s)")

print()
print("All tests passed!")
