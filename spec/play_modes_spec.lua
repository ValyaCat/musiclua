-- spec/play_modes_spec.lua
-- Tests for playlist play modes

package.path = package.path .. ";./?.lua;./?/init.lua"

describe("play modes", function()
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

    it("defaults to repeat-all mode", function()
        local pl = Playlist.new(make_tracks(3))
        assert.are.equal("repeat-all", pl:get_mode())
    end)

    it("set_mode changes the mode", function()
        local pl = Playlist.new(make_tracks(3))
        pl:set_mode("shuffle")
        assert.are.equal("shuffle", pl:get_mode())
        pl:set_mode("sequential")
        assert.are.equal("sequential", pl:get_mode())
    end)

    it("repeat-all wraps next() at end", function()
        local pl = Playlist.new(make_tracks(3))
        pl:set_mode("repeat-all")
        pl:goto_index(3)
        pl:set_playing_to_selected()
        local t = pl:next()
        assert.are.equal("1", t.id)
    end)

    it("repeat-all wraps prev() at start", function()
        local pl = Playlist.new(make_tracks(3))
        pl:set_mode("repeat-all")
        pl:goto_index(1)
        pl:set_playing_to_selected()
        local t = pl:prev()
        assert.are.equal("3", t.id)
    end)

    it("sequential stops next() at end", function()
        local pl = Playlist.new(make_tracks(3))
        pl:set_mode("sequential")
        pl:goto_index(3)
        pl:set_playing_to_selected()
        local t = pl:next()
        assert.is_nil(t)
    end)

    it("sequential stops prev() at start", function()
        local pl = Playlist.new(make_tracks(3))
        pl:set_mode("sequential")
        pl:goto_index(1)
        pl:set_playing_to_selected()
        local t = pl:prev()
        assert.is_nil(t)
    end)

    it("repeat-one keeps next() on the same track", function()
        local pl = Playlist.new(make_tracks(5))
        pl:set_mode("repeat-one")
        pl:goto_index(3)
        pl:set_playing_to_selected()
        local t = pl:next()
        assert.are.equal("3", t.id)
    end)

    it("repeat-one keeps prev() on the same track", function()
        local pl = Playlist.new(make_tracks(5))
        pl:set_mode("repeat-one")
        pl:goto_index(3)
        pl:set_playing_to_selected()
        local t = pl:prev()
        assert.are.equal("3", t.id)
    end)

    it("shuffle returns a track on next()", function()
        local pl = Playlist.new(make_tracks(10))
        pl:set_mode("shuffle")
        pl:goto_index(1)
        pl:set_playing_to_selected()
        local t = pl:next()
        assert.is_not_nil(t)
        assert.is_string(t.id)
    end)

    it("shuffle visits all tracks over enough next() calls", function()
        local pl = Playlist.new(make_tracks(5))
        pl:set_mode("shuffle")
        pl:goto_index(1)
        pl:set_playing_to_selected()
        local seen = {}
        for _ = 1, 5 do
            local t = pl:next()
            seen[t.id] = true
        end
        -- With 5 next() calls, all 5 tracks should be visited
        local count = 0
        for _ in pairs(seen) do count = count + 1 end
        assert.are.equal(5, count)
    end)

    it("cycle_mode rotates through all modes", function()
        local pl = Playlist.new(make_tracks(3))
        local initial = pl:get_mode()
        -- There are 4 modes, so 4 cycles returns to initial
        for _ = 1, 4 do
            pl:cycle_mode()
        end
        assert.are.equal(initial, pl:get_mode())
    end)

    it("setting mode to shuffle reshuffles", function()
        local pl = Playlist.new(make_tracks(5))
        pl:set_mode("shuffle")
        -- Just verify it doesn't crash
        assert.is_not_nil(pl._shuffle_order)
    end)
end)
