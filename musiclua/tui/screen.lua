-- musiclua/tui/screen.lua
-- Screen abstraction wrapping lua-curses

local screen = {}
screen.__index = screen

local curses_available, curses = pcall(require, "curses")

if not curses_available then
    -- Provide a fallback error when someone tries to actually use screen
    error(
        "\n\n  lua-curses is required but not installed.\n"
        .. "  Install it with:  luarocks install luaposix\n"
        .. "  or:               luarocks install curses\n\n"
    )
end

--- Initialise curses and return a screen object.
-- @return screen
function screen.init()
    local self = setmetatable({}, screen)
    local stdscr = curses.initscr()
    curses.cbreak()
    curses.noecho()
    curses.nl(false)        -- don't translate Enter to newline
    stdscr:keypad(true)     -- enable arrow keys
    stdscr:nodelay(true)    -- non-blocking getch

    -- Set up colours
    if curses.has_colors() then
        curses.start_color()
        curses.use_default_colors()
        -- color pair ID, foreground, background
        curses.init_pair(1, curses.COLOR_CYAN,   -1)  -- title
        curses.init_pair(2, curses.COLOR_BLACK,  curses.COLOR_WHITE) -- selected
        curses.init_pair(3, curses.COLOR_GREEN,  -1)  -- playing
        curses.init_pair(4, curses.COLOR_YELLOW, -1)  -- status
        curses.init_pair(5, curses.COLOR_WHITE,  -1)  -- help
    end

    self._stdscr = stdscr
    return self
end

--- Return (rows, cols) of the terminal.
-- @return number, number
function screen:size()
    local rows, cols = curses.lines(), curses.cols()
    return rows, cols
end

--- Clear the entire screen.
function screen:clear()
    self._stdscr:clear()
end

--- Write text at (row, col), 1-based.
-- @param row number
-- @param col number
-- @param text string
function screen:write(row, col, text)
    self._stdscr:move(row - 1, col - 1)
    self._stdscr:addstr(text)
end

--- Write text truncated to max_width characters.
-- @param row number
-- @param col number
-- @param text string
-- @param max_width number
function screen:write_trunc(row, col, text, max_width)
    if #text > max_width then
        text = text:sub(1, max_width)
    end
    self:write(row, col, text)
end

--- Set the color attribute for subsequent writes.
-- @param pair_id number
function screen:set_color(pair_id)
    if pair_id == 0 then
        self._stdscr:attrset(curses.A_NORMAL)
    else
        self._stdscr:attrset(curses.color_pair(pair_id))
    end
end

--- Set bold attribute.
function screen:set_bold(on)
    if on then
        self._stdscr:attrset(curses.A_BOLD)
    else
        self._stdscr:attrset(curses.A_NORMAL)
    end
end

--- Combine color + bold.
function screen:set_attr(color_pair, bold)
    local attr = curses.A_NORMAL
    if color_pair and color_pair > 0 then
        attr = curses.color_pair(color_pair)
    end
    if bold then
        -- curses.A_BOLD may not be additive in all bindings,
        -- but most Lua curses expose bitwise OR via +.
        -- Fallback: just use bold.
        attr = attr + curses.A_BOLD
    end
    self._stdscr:attrset(attr)
end

--- Clear to end of line at current cursor.
function screen:clrtoeol()
    self._stdscr:clrtoeol()
end

--- Fill a line with spaces (clear the line).
function screen:clear_line(row)
    local _, cols = self:size()
    self:write(row, 1, string.rep(" ", cols))
end

--- Refresh the screen (push buffered changes).
function screen:refresh()
    self._stdscr:refresh()
end

--- Read a single key without blocking.
-- @return number|nil  key code (curses keycode or ASCII)
function screen:getch()
    local ch = self._stdscr:getch()
    if ch == -1 or ch == nil then return nil end
    return ch
end

--- Restore the terminal to its original state.
function screen:cleanup()
    curses.endwin()
end

--- Return the curses constants table (for key codes).
function screen.keys()
    return curses
end

return screen
