-- spec/rss_spec.lua
-- Tests for musiclua.sources.rss (XML parsing, not network)

package.path = package.path .. ";./?.lua;./?/init.lua"

describe("rss", function()
    local rss

    setup(function()
        rss = require("musiclua.sources.rss")
    end)

    it("rejects non-http URLs", function()
        local tracks, err = rss.scan("ftp://example.com/feed.rss")
        assert.is_nil(tracks)
        assert.is_string(err)
    end)

    it("rejects empty URL", function()
        local tracks, err = rss.scan("")
        assert.is_nil(tracks)
        assert.is_string(err)
    end)

    it("rejects nil URL", function()
        local tracks, err = rss.scan(nil)
        assert.is_nil(tracks)
        assert.is_string(err)
    end)
end)

describe("url source", function()
    local url_source

    setup(function()
        url_source = require("musiclua.sources.url")
    end)

    it("creates a track from a valid URL", function()
        local tracks, err = url_source.scan("https://example.com/podcast/episode42.mp3")
        assert.is_nil(err)
        assert.is_table(tracks)
        assert.are.equal(1, #tracks)
        assert.are.equal("episode42", tracks[1].title)
        assert.are.equal("https://example.com/podcast/episode42.mp3", tracks[1].path)
        assert.are.equal("url", tracks[1].source)
    end)

    it("rejects non-http URLs", function()
        local tracks, err = url_source.scan("ftp://example.com/song.mp3")
        assert.is_nil(tracks)
        assert.is_string(err)
    end)

    it("rejects empty URL", function()
        local tracks, err = url_source.scan("")
        assert.is_nil(tracks)
        assert.is_string(err)
    end)

    it("derives title from filename in URL", function()
        local tracks = url_source.scan("https://cdn.example.com/music/cool-song.ogg")
        assert.are.equal("cool-song", tracks[1].title)
    end)

    it("handles query parameters in URL", function()
        local tracks = url_source.scan("https://example.com/audio.mp3?token=abc123")
        assert.are.equal("audio", tracks[1].title)
    end)
end)
