-- musiclua/tui/input.lua
-- Input handling: maps key strings (from ANSI backend) to action strings

local input = {}

-- Well-known key strings (ANSI backend returns these)
input.KEY_ENTER     = "\n"
input.KEY_ESC       = "\27"
input.KEY_BACKSPACE = "\127"     -- DEL
input.KEY_CTRL_H    = "\8"       -- Ctrl-H (also backspace on some terminals)

--- Map a raw key + keytype to an action string.
-- With the ANSI backend, key is a string and keytype is "ctrl"|"char"|"ansi".
-- @param key     string  key from screen:getch()
-- @param keytype string  "ctrl", "char", or "ansi" (from readansi)
-- @param curses_keys table  unused (kept for API compat)
-- @return string|nil  action name
function input.map_key(key, curses_keys, keytype)
    if key == nil then return nil end

    -- ANSI escape sequences (arrow keys etc.)
    if keytype == "ansi" then
        -- readansi classifies standalone ESC as "ansi" (not "ctrl")
        -- Handle bare ESC: byte 27, possibly with trailing bytes
        if key:byte(1) == 27 then
            if #key == 1 then return "esc" end
            -- ESC followed by newline from stdin pipe
            if #key == 2 and key:byte(2) == 10 then return "esc" end
        end

        local scr = curses_keys
        if scr then
            if key == scr.KEY_DOWN  then return "down" end
            if key == scr.KEY_UP    then return "up" end
            if key == scr.KEY_RIGHT then return "right" end
            if key == scr.KEY_LEFT  then return "left" end
        end
        -- Fallback: match raw ANSI sequences directly
        if key == "\27[B" then return "down" end
        if key == "\27[A" then return "up" end
        if key == "\27[C" then return "right" end
        if key == "\27[D" then return "left" end
        return nil
    end

    -- Control characters
    if keytype == "ctrl" then
        if key == "\n" or key == "\r" then return "play" end
        if key == "\27" then return "esc" end
        if key == "\8"  then return "backspace" end
        if key == "\127" then return "backspace" end
        local byte = key:byte(1)
        if byte == 32 then return "toggle" end
        return nil
    end

    -- Regular printable characters (keytype == "char")
    if key == " " then return "toggle" end
    if key == "/" then return "search" end
    if key == "+" or key == "=" then return "vol_up" end
    if key == "-" then return "vol_down" end
    if key == "j" then return "down" end
    if key == "k" then return "up" end
    if key == "n" then return "next" end
    if key == "p" then return "prev" end
    if key == "m" then return "mode" end
    if key == "s" then return "stop" end
    if key == "r" then return "refresh" end
    if key == "d" then return "delete" end
    if key == "c" then return "clear" end
    if key == "?" then return "help" end
    if key == "q" or key == "Q" then return "quit" end

    -- Printable character (for search input etc.)
    return "char"
end

--- Return the character string for a printable key.
-- With the ANSI backend, the key is already the character string.
-- @param key string
-- @param keytype string
-- @return string|nil
function input.char_for(key, keytype)
    if key and keytype == "char" then
        -- Only return printable characters (not control chars)
        local byte = key:byte(1)
        if byte and byte >= 32 then
            return key
        end
    end
    return nil
end

return input
