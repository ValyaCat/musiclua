-- spec/playlist_spec.lua
-- Tests for musiclua.playlist

package.path = package.path .. ";./?.lua;./?/init.lua"

describe("playlist", function()
    local Playlist

    setup(function()
        Playlist = require("musiclua.playlist")
    end)

    local function make_tracks(n)
        local tracks = {}
        for i = 1, n do
            tracks[i] = {
                id = tostring(i),
                title = "track_" .. i .. ".mp3",
                path = "/music/track_" .. i .. ".mp3",
                source = "local",
            }
        end
        return tracks
    end

    it("returns nil for current() on empty playlist", function()
        local pl = Playlist.new()
        assert.is_nil(pl:current())
    end)

    it("returns 0 for count() on empty playlist", function()
        local pl = Playlist.new()
        assert.are.equal(0, pl:count())
    end)

    it("wraps next() from last track to first", function()
        local pl = Playlist.new(make_tracks(3))
        pl:goto_index(3)
        pl:set_playing_to_selected()
        local t = pl:next()
        assert.is_not_nil(t)
        assert.are.equal("1", t.id)
    end)

    it("wraps prev() from first track to last", function()
        local pl = Playlist.new(make_tracks(3))
        pl:goto_index(1)
        pl:set_playing_to_selected()
        local t = pl:prev()
        assert.is_not_nil(t)
        assert.are.equal("3", t.id)
    end)

    it("goto_index clamps to valid range", function()
        local pl = Playlist.new(make_tracks(5))
        pl:goto_index(100)
        assert.are.equal(5, pl:selected_index())
        pl:goto_index(-5)
        assert.are.equal(1, pl:selected_index())
    end)

    it("goto_index on empty playlist does not crash", function()
        local pl = Playlist.new()
        pl:goto_index(5)
        assert.are.equal(1, pl:selected_index())
    end)

    it("filter reduces visible tracks", function()
        local tracks = {
            { id = "1", title = "Live at Wembley", path = "/a", source = "local" },
            { id = "2", title = "Studio Version",  path = "/b", source = "local" },
            { id = "3", title = "Live in Paris",    path = "/c", source = "local" },
        }
        local pl = Playlist.new(tracks)
        assert.are.equal(3, pl:count())

        pl:filter("live")
        assert.are.equal(2, pl:count())
        pl:clear_filter()
        assert.are.equal(3, pl:count())
    end)

    it("filter is case-insensitive", function()
        local tracks = {
            { id = "1", title = "Hello World", path = "/a", source = "local" },
            { id = "2", title = "HELLO Again", path = "/b", source = "local" },
            { id = "3", title = "Goodbye",     path = "/c", source = "local" },
        }
        local pl = Playlist.new(tracks)
        pl:filter("hello")
        assert.are.equal(2, pl:count())
    end)

    it("clear_filter resets selected_index sensibly", function()
        local pl = Playlist.new(make_tracks(5))
        pl:goto_index(3)
        pl:filter("track_3")
        assert.are.equal(1, pl:selected_index())
        pl:clear_filter()
        -- Should try to restore position
        assert.is_number(pl:selected_index())
    end)

    it("move_down wraps from last to first", function()
        local pl = Playlist.new(make_tracks(3))
        pl:goto_index(3)
        pl:move_down()
        assert.are.equal(1, pl:selected_index())
    end)

    it("move_up wraps from first to last", function()
        local pl = Playlist.new(make_tracks(3))
        pl:goto_index(1)
        pl:move_up()
        assert.are.equal(3, pl:selected_index())
    end)

    it("add appends a track", function()
        local pl = Playlist.new(make_tracks(2))
        assert.are.equal(2, pl:count())
        pl:add({ id = "3", title = "new.mp3", path = "/new", source = "local" })
        assert.are.equal(3, pl:count())
    end)

    it("set_tracks replaces all tracks and resets state", function()
        local pl = Playlist.new(make_tracks(5))
        pl:goto_index(4)
        pl:set_tracks(make_tracks(2))
        assert.are.equal(2, pl:count())
        assert.are.equal(1, pl:selected_index())
    end)
end)
