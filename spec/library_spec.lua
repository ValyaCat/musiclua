-- spec/library_spec.lua
-- Tests for musiclua.library

package.path = package.path .. ";./?.lua;./?/init.lua"

describe("library", function()
    local library

    setup(function()
        library = require("musiclua.library")
    end)

    it("returns empty list for an empty directory", function()
        -- Create a temporary empty directory
        os.execute("mkdir -p /tmp/musiclua_test_empty")
        local tracks = library.scan_dir("/tmp/musiclua_test_empty")
        assert.is_table(tracks)
        assert.are.equal(0, #tracks)
        os.execute("rmdir /tmp/musiclua_test_empty")
    end)

    it("only returns audio files, ignoring non-audio files", function()
        local tracks = library.scan_dir("./test_music_scan")
        assert.is_table(tracks)
        -- test_music_scan has: a.mp3, b.ogg, c.txt, d.flac, .hidden.mp3
        -- Should return: a.mp3, b.ogg, d.flac (not c.txt, not .hidden.mp3)
        assert.are.equal(3, #tracks)
        local titles = {}
        for _, t in ipairs(tracks) do
            titles[t.title] = true
        end
        assert.is_true(titles["a.mp3"])
        assert.is_true(titles["b.ogg"])
        assert.is_true(titles["d.flac"])
        assert.is_nil(titles["c.txt"])
        assert.is_nil(titles[".hidden.mp3"])
    end)

    it("sorts tracks by title", function()
        local tracks = library.scan_dir("./test_music_scan")
        assert.is_table(tracks)
        for i = 2, #tracks do
            assert.is_true(tracks[i-1].title:lower() <= tracks[i].title:lower())
        end
    end)

    it("returns error for non-existent directory", function()
        local tracks, err = library.scan_dir("/tmp/nonexistent_musiclua_test_dir_xyz")
        -- scan_dir returns empty table and error message for bad directories
        assert.is_table(tracks)
        assert.are.equal(0, #tracks)
        assert.is_string(err)
    end)

    it("each track has required fields", function()
        local tracks = library.scan_dir("./test_music_scan")
        for _, t in ipairs(tracks) do
            assert.is_string(t.id)
            assert.is_string(t.title)
            assert.is_string(t.path)
            assert.are.equal("local", t.source)
        end
    end)
end)
