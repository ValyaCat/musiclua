-- musiclua/players/base.lua
-- Player interface contract (all player implementations must provide these methods)

local BasePlayer = {}
BasePlayer.__index = BasePlayer

function BasePlayer:new(opts)
    error("BasePlayer:new() must be overridden")
end

--- Load a track into the player (does not start playback).
function BasePlayer:load(track) error("load() not implemented") end

--- Start or resume playback.
function BasePlayer:play() error("play() not implemented") end

--- Pause playback.
function BasePlayer:pause() error("pause() not implemented") end

--- Toggle pause/play.
function BasePlayer:toggle() error("toggle() not implemented") end

--- Stop playback completely.
function BasePlayer:stop() error("stop() not implemented") end

--- Set volume (0-100).
function BasePlayer:set_volume(v) error("set_volume() not implemented") end

--- Get current volume.
-- @return number
function BasePlayer:get_volume() error("get_volume() not implemented") end

--- Get playback status string.
-- @return string  "playing"|"paused"|"stopped"|"loading"
function BasePlayer:get_status() error("get_status() not implemented") end

--- Get current playback position in seconds.
-- @return number|nil
function BasePlayer:get_position() error("get_position() not implemented") end

--- Get duration of the current track in seconds.
-- @return number|nil
function BasePlayer:get_duration() error("get_duration() not implemented") end

--- Shut down the player and release all resources.
function BasePlayer:close() error("close() not implemented") end

return BasePlayer
