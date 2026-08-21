-- musiclua/players/mpv.lua
-- mpv player implementation using JSON IPC over Unix socket

local BasePlayer = require("musiclua.players.base")
local json       = require("musiclua.util.json")
local log        = require("musiclua.util.log")

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

    self:_start_mpv()
    return self
end

---------------------------------------------------------------------------
-- mpv process management
---------------------------------------------------------------------------

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
        local f = io.open(self._ipc_path, "r")
        if f then
            f:close()
            log.debug("mpv socket ready after", attempts, "attempts")
            return
        end
        -- Sleep 0.1s using os.execute (portable enough for POSIX)
        os.execute("sleep 0.1")
        attempts = attempts + 1
    end
    log.warn("mpv socket did not appear within 3 s:", self._ipc_path)
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
        log.warn("mpv socket connect failed:", err)
        pcall(function() sock:close() end)
        return false
    end
    self._socket = sock
    return true
end

---------------------------------------------------------------------------
-- IPC communication
---------------------------------------------------------------------------

--- Send a JSON command to mpv and return the parsed response (or nil).
-- @param cmd_table table  e.g. { "get_property", "time-pos" }
-- @return table|nil  response data field
function MpvPlayer:_command(cmd_table)
    if not self:_connect() then
        return nil
    end

    local payload = json.encode({ command = cmd_table }) .. "\n"
    local ok, err = self._socket:send(payload)
    if not ok then
        log.warn("mpv send failed:", err)
        -- Invalidate socket so next call reconnects
        pcall(function() self._socket:close() end)
        self._socket = nil
        return nil
    end

    -- Read one line response (mpv sends one JSON object per line)
    local line, read_err = self._socket:receive("*l")
    if not line then
        log.debug("mpv recv:", read_err)
        return nil
    end

    local resp, dec_err = json.decode(line)
    if not resp then
        log.debug("mpv json decode error:", dec_err)
        return nil
    end

    if resp.error and resp.error ~= "success" then
        log.debug("mpv error:", resp.error)
        return nil
    end

    return resp.data
end

--- Send a command that doesn't return useful data.
-- @param cmd_table table
function MpvPlayer:_command_no_response(cmd_table)
    if not self:_connect() then return end
    local payload = json.encode({ command = cmd_table }) .. "\n"
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
    self:_command_no_response({ "loadfile", track.path, "replace" })
    self._status   = "loading"
    self._position = 0
    self._duration = 0
    self._loaded   = true
end

function MpvPlayer:play()
    self:_command_no_response({ "set_property", "pause", false })
    self._status = "playing"
end

function MpvPlayer:pause()
    self:_command_no_response({ "set_property", "pause", true })
    self._status = "paused"
end

function MpvPlayer:toggle()
    self:_command_no_response({ "cycle", "pause" })
    -- Update status from mpv after toggling
    local paused = self:_command({ "get_property", "pause" })
    if paused == true then
        self._status = "paused"
    else
        self._status = "playing"
    end
end

function MpvPlayer:stop()
    self:_command_no_response({ "stop" })
    self._status   = "stopped"
    self._position = 0
    self._loaded   = false
end

function MpvPlayer:set_volume(v)
    if type(v) ~= "number" then return end
    if v < 0 then v = 0 end
    if v > 100 then v = 100 end
    self:_command_no_response({ "set_property", "volume", v })
    self._volume = v
end

function MpvPlayer:get_volume()
    local v = self:_command({ "get_property", "volume" })
    if type(v) == "number" then
        self._volume = v
    end
    return self._volume
end

function MpvPlayer:get_status()
    -- Query mpv for the real pause/idle state each time
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

function MpvPlayer:close()
    log.debug("closing mpv player")
    -- Send quit command
    self:_command_no_response({ "quit" })

    -- Close socket
    if self._socket then
        pcall(function() self._socket:close() end)
        self._socket = nil
    end

    -- Give mpv a moment to exit, then force-kill if still running
    os.execute("sleep 0.2")
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
