-- musiclua/tui/screen.lua
-- Screen abstraction: ANSI escape-code backend using luasystem
--
-- Performance design:
--   1. All writes go into an internal buffer (_buf).
--   2. refresh() emits a SINGLE io.write() — eliminates flicker.
--   3. clear() does NOT wipe the screen; clear_line() uses \e[K (clear-to-EOL).
--      This avoids the full-screen flash between clear and redraw.
--   4. Line cache: rows whose content hasn't changed are skipped.

local screen = {}
screen.__index = screen

local sys_ok, sys = pcall(require, "system")

if not sys_ok then sys = nil end

-- ANSI constants
local ESC = "\27"
local CSI = ESC .. "["
local ANSI_HIDE_CUR = CSI .. "?25l"
local ANSI_SHOW_CUR = CSI .. "?25h"
local ANSI_CLR_EOL  = CSI .. "K"
local ANSI_RESET    = CSI .. "0m"
local ANSI_BOLD     = CSI .. "1m"
local ANSI_DIM      = CSI .. "2m"
local ANSI_ITALIC   = CSI .. "3m"
local ANSI_INVERSE  = CSI .. "7m"

-- Color pairs: id → ANSI SGR sequence
local color_pairs = {
    [0]  = ANSI_RESET,                          -- default
    [1]  = CSI .. "36m",                        -- cyan   (title)
    [2]  = CSI .. "30;47m",                     -- black on white (selected)
    [3]  = CSI .. "32m",                        -- green  (playing)
    [4]  = CSI .. "33m",                        -- yellow (status)
    [5]  = CSI .. "37m",                        -- white  (help)
    [6]  = CSI .. "90m",                        -- dim gray (borders)
    [7]  = CSI .. "96m",                        -- bright cyan (accents)
    [8]  = CSI .. "38;5;51m",                   -- bright cyan (progress filled)
    [9]  = CSI .. "38;5;238m",                  -- dark gray (progress empty)
    [10] = CSI .. "38;5;252m",                  -- light white (time labels)
    [11] = CSI .. "97m",                        -- bright white (help keys)
}

-- Key constants (string values matching readansi output)
screen.KEY_UP        = CSI .. "A"
screen.KEY_DOWN      = CSI .. "B"
screen.KEY_RIGHT     = CSI .. "C"
screen.KEY_LEFT      = CSI .. "D"
screen.KEY_HOME      = CSI .. "H"
screen.KEY_END       = CSI .. "F"
screen.KEY_DELETE    = CSI .. "3~"
screen.KEY_BACKSPACE_STR = "\127"
screen.KEY_CTRL_H    = "\8"
screen.KEY_ENTER     = "\n"
screen.KEY_ESC       = ESC

--- Initialise the terminal for TUI mode and return a screen object.
function screen.init()
    if not sys then
        error("luasystem is required but not installed.\n"
            .. "Install it with: luarocks install luasystem")
    end

    local self = setmetatable({}, screen)

    -- Back up terminal state and arrange automatic restore on exit
    self._term_backup = sys.termbackup()
    sys.autotermrestore()

    -- Enter raw mode: disable canonical processing and echo
    local flags = sys.tcgetattr(io.stdin)
    if flags then
        if flags.lflag and sys.L_ICANON then
            flags.lflag = flags.lflag - sys.L_ICANON - sys.L_ECHO
            if sys.L_ISIG then flags.lflag = flags.lflag - sys.L_ISIG end
        end
        if flags.iflag then
            if sys.I_ICRNL then flags.iflag = flags.iflag - sys.I_ICRNL end
            if sys.I_IXON  then flags.iflag = flags.iflag - sys.I_IXON  end
        end
        sys.tcsetattr(io.stdin, sys.TCSANOW, flags)
    end

    -- Enter alternate screen buffer, hide cursor, clear once
    io.write(ESC .. "7")                        -- save cursor position
    io.write(ESC .. "[?1049h")                  -- alt screen buffer (with save)
    io.write(ANSI_HIDE_CUR)
    io.write(CSI .. "2J" .. CSI .. "H")         -- clear + home
    io.flush()

    -- Internal state
    self._buf        = {}        -- output buffer (strings to concat)
    self._line_cache = {}        -- row → previous frame's content string
    self._cur_row    = 0         -- row currently being written to
    self._cur_line   = {}        -- segments for the current row
    self._rows       = 0
    self._cols       = 0
    self._initialized = true
    return self
end

--- Return (rows, cols) of the terminal.
function screen:size()
    local rows, cols = sys.termsize()
    return rows, cols
end

--- Begin a new frame: flush previous row and reset buffer.
-- Call this at the start of each draw cycle instead of clear().
function screen:begin_frame()
    -- Flush any pending row from previous writes
    self:_flush_cur_line()
    self._buf = {}
    self._cur_row = 0
    self._cur_line = {}
    self._rows, self._cols = self:size()
end

--- Emit a single segment into the current row's line buffer.
local function emit(self, s)
    if s and #s > 0 then
        local n = #self._cur_line
        self._cur_line[n + 1] = s
    end
end

--- Flush the accumulated current-row content into the output buffer.
-- Compares against the line cache and skips unchanged rows.
function screen:_flush_cur_line()
    if self._cur_row > 0 and #self._cur_line > 0 then
        local content = table.concat(self._cur_line)
        -- Only emit if this line differs from the previous frame
        if self._line_cache[self._cur_row] ~= content then
            local n = #self._buf
            self._buf[n + 1] = CSI .. self._cur_row .. ";1H"
            self._buf[n + 2] = content
            self._buf[n + 3] = ANSI_CLR_EOL       -- clear remainder of line
            self._line_cache[self._cur_row] = content
        end
    end
    self._cur_line = {}
end

--- Write text at (row, col), 1-based.
function screen:write(row, col, text)
    -- If we've moved to a different row, flush the previous one
    if row ~= self._cur_row then
        self:_flush_cur_line()
        self._cur_row = row
    end
    -- If col > 1, emit cursor positioning within the row
    if col > 1 then
        emit(self, CSI .. row .. ";" .. col .. "H")
    end
    emit(self, text)
end

--- Write text truncated to max display width (UTF-8 aware).
function screen:write_trunc(row, col, text, max_width)
    if sys.utf8swidth then
        local dw = sys.utf8swidth(text) or #text
        if dw > max_width then
            while #text > 0 and (sys.utf8swidth(text) or #text) > max_width - 1 do
                text = text:sub(1, -2)
            end
            text = text .. "\226\128\166" -- "…"
        end
    elseif #text > max_width then
        text = text:sub(1, max_width - 1) .. "\226\128\166"
    end
    self:write(row, col, text)
end

--- Set the color attribute for subsequent writes.
function screen:set_color(pair_id)
    emit(self, color_pairs[pair_id] or ANSI_RESET)
end

--- Set bold attribute.
function screen:set_bold(on)
    emit(self, on and ANSI_BOLD or ANSI_RESET)
end

--- Combine color + bold.
function screen:set_attr(color_pair, bold)
    emit(self, color_pairs[color_pair] or ANSI_RESET)
    if bold then emit(self, ANSI_BOLD) end
end

--- Set inverse video.
function screen:set_inverse(on)
    emit(self, on and ANSI_INVERSE or ANSI_RESET)
end

--- Set dim attribute.
function screen:set_dim(on)
    emit(self, on and ANSI_DIM or ANSI_RESET)
end

--- Clear to end of line at current cursor.
function screen:clrtoeol()
    emit(self, ANSI_CLR_EOL)
end

--- Clear a specific line (writes spaces, then EOL clear).
function screen:clear_line(row)
    if row ~= self._cur_row then
        self:_flush_cur_line()
        self._cur_row = row
    end
    -- Start with reset, so the line is visually empty
    emit(self, ANSI_RESET)
end

--- Push all buffered output to the terminal in a single write.
function screen:refresh()
    self:_flush_cur_line()
    if #self._buf > 0 then
        io.write(table.concat(self._buf))
        io.flush()
        self._buf = {}
    end
end

--- Read a single key with a short timeout.
function screen:getch(timeout)
    timeout = timeout or 0.05
    local key, keytype = sys.readansi(timeout)
    if key == nil then return nil end
    return key, keytype
end

--- Restore the terminal to its original state.
function screen:cleanup()
    if not self._initialized then return end
    io.write(ANSI_SHOW_CUR)
    io.write(ESC .. "[?1049l")   -- leave alt screen buffer
    io.write(ESC .. "8")         -- restore cursor position
    io.write(ANSI_RESET)
    io.flush()
    if self._term_backup then
        sys.termrestore(self._term_backup)
        self._term_backup = nil
    end
    self._initialized = false
end

--- Return key constants table (for input.lua).
function screen.keys()
    return screen
end

return screen
