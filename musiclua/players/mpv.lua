-- musiclua/players/mpv.lua
-- mpv player implementation using JSON IPC over Unix socket

local BasePlayer = require("musiclua.players.base")
local json       = require("musiclua.util.json")
local log        = require("musiclua.util.log")
local sys_ok, sys = pcall(require, "system")
local lfs_ok, lfs = pcall(require, "lfs")

local MpvPlayer = setmetatable({}, { __index = BasePlayer })
MpvPlayer.__index = MpvPlayer

--- Create a new MpvPlayer.
-- @param opts table?  { ipc_path = string, volume = number }
-- @return MpvPlayer
function MpvPlayer:new(opts)
    opts = opts or {}
    local self = setmetatable({}, MpvPlayer)

    -- Determine socket path
    self._ipc_path = opts.ipc_path
        or string.format("/tmp/musiclua-%d.sock", os.time())

    self._volume   = opts.volume or 80
    self._status   = "stopped"
    self._position = 0
    self._duration = 0
    self._proc     = nil  -- mpv OS process handle (via os.execute / io.popen)
    self._socket   = nil  -- luasocket connection
    self._loaded   = false
    self._available = true  -- false after repeated connection failures
    self._connect_warned = false  -- only warn once about connect failure

    self:_start_mpv()
    return self
end

---------------------------------------------------------------------------
-- mpv process management
---------------------------------------------------------------------------

--- Portable sleep: use luasystem if available, fall back to os.execute.
local function portable_sleep(secs)
    if sys_ok and sys.sleep then
        sys.sleep(secs)
    else
        os.execute(string.format("sleep %.2f", secs))
    end
end

--- Check whether mpv is installed.
local function mpv_available()
    local ok = os.execute("command -v mpv >/dev/null 2>&1")
    -- In Lua 5.1 os.execute returns 0 on success; in 5.3+ returns true/0
    return ok == true or ok == 0
end

--- Start the mpv idle process in the background.
function MpvPlayer:_start_mpv()
    if not mpv_available() then
        error("mpv is required but not installed.\n"
            .. "Install it from: https://mpv.io/installation/")
    end

    -- Remove stale socket file if present
    os.remove(self._ipc_path)

    local cmd = string.format(
        "mpv --no-video --idle=yes --input-ipc-server=%s --volume=%d >/dev/null 2>&1 &",
        self._ipc_path, self._volume
    )
    log.debug("starting mpv:", cmd)
    os.execute(cmd)

    -- Give mpv a moment to start and create the socket
    self:_wait_for_socket()
end

--- Wait up to 3 seconds for the IPC socket to appear.
function MpvPlayer:_wait_for_socket()
    local attempts = 0
    local max_attempts = 30  -- 30 * 0.1s = 3s
    while attempts < max_attempts do
        -- io.open() fails on Unix sockets ("Operation not supported on socket")
        -- so we use lfs.attributes() to check for file existence instead.
        if lfs_ok then
            local attr = lfs.attributes(self._ipc_path)
            if attr then
                log.debug("mpv socket ready after", attempts, "attempts")
                return
            end
        else
            -- Fallback: try io.open (won't work on sockets, but catches regular files)
            local f = io.open(self._ipc_path, "r")
            if f then
                f:close()
                log.debug("mpv socket ready after", attempts, "attempts")
                return
            end
        end
        -- Sleep 0.1s using native sleep (no process spawning)
        portable_sleep(0.1)
        attempts = attempts + 1
    end
    log.warn("mpv socket did not appear within 3 s:", self._ipc_path)
    -- Clean up stale socket file if mpv partially started
    os.remove(self._ipc_path)
    -- Mark player as unavailable so IPC calls short-circuit
    self._available = false
end

--- Connect (or reconnect) to the mpv IPC socket via luasocket.
-- @return boolean success
function MpvPlayer:_connect()
    if self._socket then
        -- Try a quick test write; if it fails, reconnect
        local ok = pcall(function()
            self._socket:send("")
        end)
        if ok then return true end
        pcall(function() self._socket:close() end)
        self._socket = nil
    end

    local ok_unix, socket_unix = pcall(require, "socket.unix")
    if not ok_unix then
        -- Try alternate path (some installs use socket/unix)
        ok_unix, socket_unix = pcall(function()
            local s = require("socket")
            return s.unix
        end)
    end
    if not ok_unix or not socket_unix then
        log.error("luasocket Unix socket support not available")
        return false
    end

    local sock = socket_unix()
    sock:settimeout(0.5)
    local ok, err = sock:connect(self._ipc_path)
    if not ok then
        if not self._connect_warned then
            log.warn("mpv socket connect failed:", err)
            self._connect_warned = true
        end
        pcall(function() sock:close() end)
        return false
    end
    self._socket = sock
    self._connect_warned = false  -- reset on success
    return true
end

---------------------------------------------------------------------------
-- IPC communication
---------------------------------------------------------------------------

-- Request ID counter for matching responses to commands
local _req_id = 0

--- Read lines from the socket until we find the response matching our
-- request_id.  Skips event notifications AND stale responses from
-- previous commands (which may have different request_ids).
-- @param socket  luasocket object
-- @param req_id  number  the request_id we're looking for
-- @return table|nil  parsed response
local function _read_response(socket, req_id)
    for _ = 1, 200 do  -- skip at most 200 non-matching lines
        local line, err = socket:receive("*l")
        if not line then return nil, err end

        local resp = json.decode(line)
        if not resp then return nil, "json decode error" end

        -- Match by request_id: this is OUR response
        if resp.request_id == req_id then
            return resp
        end
        -- Everything else (events, stale responses) is silently skipped
    end
    return nil, "too many non-matching lines"
end

--- Send a JSON command to mpv and return the parsed response (or nil).
-- Uses request_id matching (not drain) so stale lines are skipped
-- without blocking.
-- @param cmd_table table  e.g. { "get_property", "time-pos" }
-- @return table|nil  response data field
function MpvPlayer:_command(cmd_table)
    if not self._available then return nil end
    if not self:_connect() then
        self._available = false
        return nil
    end

    _req_id = _req_id + 1
    local my_id = _req_id
    local payload = json.encode({ command = cmd_table, request_id = my_id }) .. "\n"
    local ok, err = self._socket:send(payload)
    if not ok then
        log.warn("mpv send failed:", err)
        pcall(function() self._socket:close() end)
        self._socket = nil
        return nil
    end

    local resp, read_err = _read_response(self._socket, my_id)
    if not resp then
        log.debug("mpv recv:", read_err)
        return nil
    end

    if resp.error and resp.error ~= "success" then
        log.debug("mpv error:", resp.error)
        return nil
    end

    return resp.data
end

--- Send a command that doesn't return useful data.
-- Also uses request_id so the response can be identified and skipped
-- by future _read_response calls.
-- @param cmd_table table
function MpvPlayer:_command_no_response(cmd_table)
    if not self._available then return end
    if not self:_connect() then
        self._available = false
        return
    end
    _req_id = _req_id + 1
    local payload = json.encode({ command = cmd_table, request_id = _req_id }) .. "\n"
    local ok, err = self._socket:send(payload)
    if not ok then
        log.warn("mpv send failed:", err)
        pcall(function() self._socket:close() end)
        self._socket = nil
    end
end

---------------------------------------------------------------------------
-- Player interface implementation
---------------------------------------------------------------------------

function MpvPlayer:load(track)
    if not track or not track.path then
        log.warn("load(): no track or path")
        return
    end
    if not self._available then
        log.warn("player unavailable (mpv not running)")
        return
    end
    self:_command_no_response({ "loadfile", track.path, "replace" })
    self._status   = "loading"
    self._position = 0
    self._duration = 0
    self._loaded   = true
    self:invalidate_cache()
end

function MpvPlayer:play()
    self:_command_no_response({ "set_property", "pause", false })
    self._status = "playing"
    self:invalidate_cache()
end

function MpvPlayer:pause()
    self:_command_no_response({ "set_property", "pause", true })
    self._status = "paused"
    self:invalidate_cache()
end

function MpvPlayer:toggle()
    if not self._available then return end
    self:_command_no_response({ "cycle", "pause" })
    local paused = self:_command({ "get_property", "pause" })
    if paused == true then
        self._status = "paused"
    else
        self._status = "playing"
    end
    self:invalidate_cache()
end

function MpvPlayer:stop()
    self:_command_no_response({ "stop" })
    self._status   = "stopped"
    self._position = 0
    self._loaded   = false
    self:invalidate_cache()
end

function MpvPlayer:set_volume(v)
    if type(v) ~= "number" then return end
    if v < 0 then v = 0 end
    if v > 100 then v = 100 end
    self:_command_no_response({ "set_property", "volume", v })
    self._volume = v
    self:invalidate_cache()
end

function MpvPlayer:get_volume()
    local v = self:_command({ "get_property", "volume" })
    if type(v) == "number" then
        self._volume = v
    end
    return self._volume
end

function MpvPlayer:get_status()
    local paused = self:_command({ "get_property", "pause" })
    local idle   = self:_command({ "get_property", "idle-active" })
    if not self._loaded then
        self._status = "stopped"
    elseif idle == true then
        self._status = "stopped"
    elseif paused == true then
        self._status = "paused"
    else
        self._status = "playing"
    end
    return self._status
end

function MpvPlayer:get_position()
    local pos = self:_command({ "get_property", "time-pos" })
    if type(pos) == "number" then
        self._position = pos
    end
    return self._position
end

function MpvPlayer:get_duration()
    local dur = self:_command({ "get_property", "duration" })
    if type(dur) == "number" then
        self._duration = dur
    end
    return self._duration
end

--- Cached state: query all playback info at once, cache until the next
-- wall-clock second.  Uses os.time() (not os.clock()) because the TUI
-- main loop sleeps most of the time and consumes zero CPU, so
-- os.clock() never advances.
-- @return table  { status, position, duration, volume }
function MpvPlayer:get_state()
    local now = os.time()
    if self._state_cache and self._state_cache_time == now then
        return self._state_cache
    end

    local state = {
        status   = self:get_status(),
        position = self:get_position(),
        duration = self:get_duration(),
        volume   = self:get_volume(),
    }
    self._state_cache = state
    self._state_cache_time = now
    return state
end

--- Invalidate the state cache (call after load/play/pause/toggle).
function MpvPlayer:invalidate_cache()
    self._state_cache = nil
    self._state_cache_time = 0
end

function MpvPlayer:close()
    log.debug("closing mpv player")
    -- Send quit command (only if potentially connected)
    if self._available then
        self:_command_no_response({ "quit" })
    end

    -- Close socket
    if self._socket then
        pcall(function() self._socket:close() end)
        self._socket = nil
    end

    -- Give mpv a moment to exit, then force-kill if still running
    portable_sleep(0.2)
    -- Kill any remaining mpv process that uses our socket
    local kill_cmd = string.format(
        "pkill -f 'input-ipc-server=%s' 2>/dev/null", self._ipc_path
    )
    os.execute(kill_cmd)

    -- Remove socket file
    os.remove(self._ipc_path)

    self._status = "stopped"
    self._loaded = false
end

return MpvPlayer
