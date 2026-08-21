-- musiclua/playlist.lua
-- Playlist management: tracks, current index, filtering, navigation, play modes

local Playlist = {}
Playlist.__index = Playlist

-- Supported play modes
Playlist.MODE_SEQUENTIAL = "sequential"  -- play in order, stop at end
Playlist.MODE_REPEAT_ALL = "repeat-all"  -- wrap around at ends
Playlist.MODE_REPEAT_ONE = "repeat-one"  -- replay the same track
Playlist.MODE_SHUFFLE    = "shuffle"     -- random order

--- Create a new Playlist instance.
-- @param tracks table?  initial track list
-- @return Playlist
function Playlist.new(tracks)
    local self = setmetatable({}, Playlist)
    self._tracks           = {}    -- full (unfiltered) track list
    self._filtered         = nil   -- filtered view (nil = no filter active)
    self._selected_index   = 1     -- cursor position in the visible list
    self._playing_index    = 0     -- index of currently playing track in visible list (0 = nothing)
    self._filter_keyword   = nil
    self._play_mode        = Playlist.MODE_REPEAT_ALL
    self._shuffle_order    = nil   -- shuffled index list (when mode is shuffle)
    self._shuffle_pos      = 0     -- position in shuffle order
    if tracks then
        self:set_tracks(tracks)
    end
    return self
end

---------------------------------------------------------------------------
-- Track list management
---------------------------------------------------------------------------

--- Replace the full track list.  Resets filter and cursor.
-- @param tracks table
function Playlist:set_tracks(tracks)
    self._tracks         = tracks or {}
    self._filtered       = nil
    self._filter_keyword = nil
    self._selected_index = 1
    self._playing_index  = 0
end

--- Add a single track to the end of the full list.
-- @param t table  track
function Playlist:add(t)
    self._tracks[#self._tracks + 1] = t
    -- If a filter is active, also add to filtered view if it matches
    if self._filtered and self._filter_keyword then
        if self:_matches(t, self._filter_keyword) then
            self._filtered[#self._filtered + 1] = t
        end
    end
end

--- Return the visible track list (filtered if active, otherwise full).
-- @return table
function Playlist:visible()
    return self._filtered or self._tracks
end

--- Number of visible tracks.
-- @return number
function Playlist:count()
    return #self:visible()
end

---------------------------------------------------------------------------
-- Navigation
---------------------------------------------------------------------------

--- Return the currently selected track (under the cursor).
-- @return table|nil
function Playlist:current()
    local vis = self:visible()
    if #vis == 0 then return nil end
    self:_clamp_index()
    return vis[self._selected_index]
end

--- Return the currently selected index.
-- @return number
function Playlist:selected_index()
    return self._selected_index
end

--- Return the currently playing track (may differ from selected).
-- @return table|nil
function Playlist:playing_track()
    local vis = self:visible()
    if self._playing_index < 1 or self._playing_index > #vis then return nil end
    return vis[self._playing_index]
end

--- Return the playing index.
-- @return number
function Playlist:playing_index()
    return self._playing_index
end

--- Move cursor down by one (wraps to top).
function Playlist:move_down()
    local n = self:count()
    if n == 0 then return end
    self._selected_index = (self._selected_index % n) + 1
end

--- Move cursor up by one (wraps to bottom).
function Playlist:move_up()
    local n = self:count()
    if n == 0 then return end
    self._selected_index = self._selected_index - 1
    if self._selected_index < 1 then
        self._selected_index = n
    end
end

--- Advance to next track based on current play mode.  Returns the new playing track.
-- @return table|nil
function Playlist:next()
    local n = self:count()
    if n == 0 then return nil end

    if self._play_mode == Playlist.MODE_REPEAT_ONE then
        -- Stay on the same track
        self._selected_index = self._playing_index
        return self:visible()[self._playing_index]

    elseif self._play_mode == Playlist.MODE_SHUFFLE then
        self:_ensure_shuffle()
        self._shuffle_pos = self._shuffle_pos + 1
        if self._shuffle_pos > n then
            self:_reshuffle()
            self._shuffle_pos = 1
        end
        local idx = self._shuffle_order[self._shuffle_pos]
        self._playing_index  = idx
        self._selected_index = idx
        return self:visible()[idx]

    elseif self._play_mode == Playlist.MODE_SEQUENTIAL then
        -- Stop at end instead of wrapping
        if self._playing_index >= n then
            return nil  -- end of playlist
        end
        self._playing_index  = self._playing_index + 1
        self._selected_index = self._playing_index
        return self:visible()[self._playing_index]

    else -- MODE_REPEAT_ALL (default)
        self._playing_index = (self._playing_index % n) + 1
        self._selected_index = self._playing_index
        return self:visible()[self._playing_index]
    end
end

--- Go back to previous track based on current play mode.  Returns the new playing track.
-- @return table|nil
function Playlist:prev()
    local n = self:count()
    if n == 0 then return nil end

    if self._play_mode == Playlist.MODE_REPEAT_ONE then
        self._selected_index = self._playing_index
        return self:visible()[self._playing_index]

    elseif self._play_mode == Playlist.MODE_SHUFFLE then
        self:_ensure_shuffle()
        self._shuffle_pos = self._shuffle_pos - 1
        if self._shuffle_pos < 1 then
            self._shuffle_pos = n
        end
        local idx = self._shuffle_order[self._shuffle_pos]
        self._playing_index  = idx
        self._selected_index = idx
        return self:visible()[idx]

    elseif self._play_mode == Playlist.MODE_SEQUENTIAL then
        if self._playing_index <= 1 then
            return nil  -- beginning of playlist
        end
        self._playing_index  = self._playing_index - 1
        self._selected_index = self._playing_index
        return self:visible()[self._playing_index]

    else -- MODE_REPEAT_ALL (default)
        self._playing_index = self._playing_index - 1
        if self._playing_index < 1 then
            self._playing_index = n
        end
        self._selected_index = self._playing_index
        return self:visible()[self._playing_index]
    end
end

--- Jump to a specific index (1-based).  Clamps to valid range.
-- @param idx number
function Playlist:goto_index(idx)
    local n = self:count()
    if n == 0 then
        self._selected_index = 1
        return
    end
    if idx < 1 then idx = 1 end
    if idx > n then idx = n end
    self._selected_index = idx
end

--- Mark the current selected track as the playing track.
function Playlist:set_playing_to_selected()
    self._playing_index = self._selected_index
end

---------------------------------------------------------------------------
-- Filtering
---------------------------------------------------------------------------

--- Filter tracks by keyword (case-insensitive match on title).
-- Resets cursor to 1.
-- @param keyword string
function Playlist:filter(keyword)
    if not keyword or keyword == "" then
        self:clear_filter()
        return
    end
    self._filter_keyword = keyword
    self._filtered = {}
    local kw = keyword:lower()
    for _, t in ipairs(self._tracks) do
        if self:_matches(t, kw) then
            self._filtered[#self._filtered + 1] = t
        end
    end
    self._selected_index = 1
end

--- Remove the current filter, restoring the full track list.
-- Attempts to keep the cursor near the previously selected track.
function Playlist:clear_filter()
    if not self._filter_keyword then return end
    -- Remember the currently selected track before clearing
    local selected = self:visible()[self._selected_index]
    self._filtered       = nil
    self._filter_keyword = nil
    -- Try to find the same track in the full list
    if selected then
        for i, t in ipairs(self._tracks) do
            if t == selected or t.id == selected.id then
                self._selected_index = i
                return
            end
        end
    end
    self._selected_index = 1
end

--- Return the active filter keyword, or nil.
-- @return string|nil
function Playlist:get_filter()
    return self._filter_keyword
end

---------------------------------------------------------------------------
-- Play mode
---------------------------------------------------------------------------

--- Get the current play mode.
-- @return string
function Playlist:get_mode()
    return self._play_mode
end

--- Set the play mode.  Resets shuffle state when switching.
-- @param mode string  one of MODE_SEQUENTIAL, MODE_REPEAT_ALL, MODE_REPEAT_ONE, MODE_SHUFFLE
function Playlist:set_mode(mode)
    if mode == Playlist.MODE_SHUFFLE and self._play_mode ~= Playlist.MODE_SHUFFLE then
        self:_reshuffle()
    end
    if mode ~= Playlist.MODE_SHUFFLE then
        self._shuffle_order = nil
        self._shuffle_pos   = 0
    end
    self._play_mode = mode
end

--- Cycle to the next play mode.
-- @return string  the new mode
function Playlist:cycle_mode()
    local order = {
        Playlist.MODE_REPEAT_ALL,
        Playlist.MODE_REPEAT_ONE,
        Playlist.MODE_SHUFFLE,
        Playlist.MODE_SEQUENTIAL,
    }
    for i, m in ipairs(order) do
        if m == self._play_mode then
            local next_mode = order[(i % #order) + 1]
            self:set_mode(next_mode)
            return next_mode
        end
    end
    self:set_mode(Playlist.MODE_REPEAT_ALL)
    return Playlist.MODE_REPEAT_ALL
end

---------------------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------------------

--- Generate a new Fisher-Yates shuffle order.
function Playlist:_reshuffle()
    local n = self:count()
    self._shuffle_order = {}
    for i = 1, n do
        self._shuffle_order[i] = i
    end
    for i = n, 2, -1 do
        local j = math.random(1, i)
        self._shuffle_order[i], self._shuffle_order[j] =
            self._shuffle_order[j], self._shuffle_order[i]
    end
    -- Place current playing track first so shuffle starts near it
    if self._playing_index > 0 then
        for k = 1, n do
            if self._shuffle_order[k] == self._playing_index then
                self._shuffle_order[k], self._shuffle_order[1] =
                    self._shuffle_order[1], self._shuffle_order[k]
                break
            end
        end
    end
    self._shuffle_pos = 0
end

--- Ensure shuffle order exists; create if missing.
function Playlist:_ensure_shuffle()
    if not self._shuffle_order then
        self:_reshuffle()
    end
end

function Playlist:_matches(t, keyword)
    if not t or not t.title then return false end
    return t.title:lower():find(keyword, 1, true) ~= nil
end

function Playlist:_clamp_index()
    local n = self:count()
    if n == 0 then
        self._selected_index = 1
        return
    end
    if self._selected_index < 1 then
        self._selected_index = 1
    elseif self._selected_index > n then
        self._selected_index = n
    end
end

return Playlist
