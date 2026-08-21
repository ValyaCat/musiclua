-- spec/m3u_spec.lua
-- Tests for musiclua.sources.m3u

package.path = package.path .. ";./?.lua;./?/init.lua"

describe("m3u", function()
    local m3u
    local test_dir = "/tmp/musiclua_m3u_test"
    local m3u_file = test_dir .. "/test.m3u"

    setup(function()
        m3u = require("musiclua.sources.m3u")
        os.execute("mkdir -p " .. test_dir)
    end)

    teardown(function()
        os.execute("rm -rf " .. test_dir)
    end)

    it("parses a simple M3U with file paths", function()
        local f = io.open(m3u_file, "w")
        f:write("#EXTM3U\n")
        f:write("/music/song1.mp3\n")
        f:write("/music/song2.ogg\n")
        f:write("# a comment\n")
        f:write("/music/song3.flac\n")
        f:close()

        local tracks, err = m3u.scan(m3u_file)
        assert.is_nil(err)
        assert.is_table(tracks)
        assert.are.equal(3, #tracks)
        assert.are.equal("song1.mp3", tracks[1].title)
        assert.are.equal("/music/song1.mp3", tracks[1].path)
        assert.are.equal("m3u", tracks[1].source)
    end)

    it("parses #EXTINF metadata", function()
        local f = io.open(m3u_file, "w")
        f:write("#EXTM3U\n")
        f:write("#EXTINF:240,My Favorite Song\n")
        f:write("/music/fav.mp3\n")
        f:write("#EXTINF:180,\n")
        f:write("/music/notitle.mp3\n")
        f:close()

        local tracks = m3u.scan(m3u_file)
        assert.are.equal(2, #tracks)
        assert.are.equal("My Favorite Song", tracks[1].title)
        assert.are.equal(240, tracks[1].duration)
        -- When EXTINF title is empty, falls back to filename
        assert.are.equal("notitle.mp3", tracks[2].title)
    end)

    it("resolves relative paths against M3U directory", function()
        local f = io.open(m3u_file, "w")
        f:write("relative/song.mp3\n")
        f:write("/absolute/song.mp3\n")
        f:close()

        local tracks = m3u.scan(m3u_file)
        assert.are.equal(2, #tracks)
        assert.are.equal(test_dir .. "/relative/song.mp3", tracks[1].path)
        assert.are.equal("/absolute/song.mp3", tracks[2].path)
    end)

    it("skips empty lines and comments", function()
        local f = io.open(m3u_file, "w")
        f:write("#EXTM3U\n")
        f:write("\n")
        f:write("# comment\n")
        f:write("\n")
        f:write("/music/song.mp3\n")
        f:close()

        local tracks = m3u.scan(m3u_file)
        assert.are.equal(1, #tracks)
    end)

    it("returns error for non-existent file", function()
        local tracks, err = m3u.scan("/tmp/nonexistent_m3u_file_xyz.m3u")
        assert.is_nil(tracks)
        assert.is_string(err)
    end)

    it("assigns sequential IDs", function()
        local f = io.open(m3u_file, "w")
        f:write("/a.mp3\n/b.mp3\n/c.mp3\n")
        f:close()

        local tracks = m3u.scan(m3u_file)
        for i, t in ipairs(tracks) do
            assert.are.equal(tostring(i), t.id)
        end
    end)
end)
