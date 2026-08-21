-- spec/sources_spec.lua
-- Tests for musiclua.sources and musiclua.sources.local_dir

package.path = package.path .. ";./?.lua;./?/init.lua"

describe("sources", function()

    describe("sources.detect", function()
        local sources

        setup(function()
            sources = require("musiclua.sources")
        end)

        it("detects a directory as local_dir", function()
            assert.are.equal("local_dir", sources.detect("./test_music_scan"))
        end)

        it("defaults to local_dir for nil input", function()
            assert.are.equal("local_dir", sources.detect(nil))
        end)

        it("detects .m3u files", function()
            assert.are.equal("m3u", sources.detect("playlist.m3u"))
        end)

        it("detects http URLs", function()
            assert.are.equal("url", sources.detect("https://example.com/song.mp3"))
        end)

        it("detects RSS feeds", function()
            assert.are.equal("rss", sources.detect("https://example.com/podcast.rss"))
        end)
    end)

    describe("local_dir.scan", function()
        local local_dir

        setup(function()
            local_dir = require("musiclua.sources.local_dir")
        end)

        it("returns tracks for valid audio files", function()
            local tracks = local_dir.scan("./test_music_scan")
            assert.is_table(tracks)
            assert.are.equal(3, #tracks)
        end)

        it("ignores hidden files", function()
            local tracks = local_dir.scan("./test_music_scan")
            for _, t in ipairs(tracks) do
                assert.is_false(t.title:sub(1,1) == ".")
            end
        end)

        it("ignores non-audio files", function()
            local tracks = local_dir.scan("./test_music_scan")
            for _, t in ipairs(tracks) do
                assert.is_false(t.title == "c.txt")
            end
        end)

        it("returns error for non-existent directory", function()
            local tracks, err = local_dir.scan("/tmp/nonexistent_xyz_musiclua")
            assert.is_nil(tracks)
            assert.is_string(err)
        end)

        it("assigns sequential IDs", function()
            local tracks = local_dir.scan("./test_music_scan")
            for i, t in ipairs(tracks) do
                assert.are.equal(tostring(i), t.id)
            end
        end)

        it("each track has source='local'", function()
            local tracks = local_dir.scan("./test_music_scan")
            for _, t in ipairs(tracks) do
                assert.are.equal("local", t.source)
            end
        end)
    end)
end)
