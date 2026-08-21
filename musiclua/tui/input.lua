-- musiclua/tui/input.lua
-- Input handling: maps key codes to action strings

local input = {}

-- ASCII codes
input.KEY_ENTER  = 10
input.KEY_ESC    = 27
input.KEY_SPACE  = 32
input.KEY_SLASH  = 47
input.KEY_PLUS   = 43
input.KEY_MINUS  = 45
input.KEY_q      = 113
input.KEY_Q      = 81
input.KEY_j      = 106
input.KEY_k      = 107
input.KEY_n      = 110
input.KEY_p      = 112
input.KEY_m      = 109  -- cycle play mode
input.KEY_BACKSPACE = 127
input.KEY_CTRL_H    = 8   -- also backspace on some terminals

--- Map a raw key code to an action string.
-- @param key   number   key code from screen:getch()
-- @param curses_mod table  the curses module (for KEY_UP, KEY_DOWN, etc.)
-- @return string|nil  action name
function input.map_key(key, curses_mod)
    if key == nil then return nil end

    -- Navigation
    if key == input.KEY_j then return "down" end
    if key == input.KEY_k then return "up" end
    if curses_mod then
        if key == curses_mod.KEY_DOWN then return "down" end
        if key == curses_mod.KEY_UP   then return "up" end
    end

    -- Actions
    if key == input.KEY_ENTER then return "play" end
    if key == input.KEY_SPACE then return "toggle" end
    if key == input.KEY_n     then return "next" end
    if key == input.KEY_p     then return "prev" end
    if key == input.KEY_m     then return "mode" end
    if key == input.KEY_SLASH then return "search" end
    if key == input.KEY_PLUS  then return "vol_up" end
    if key == input.KEY_MINUS then return "vol_down" end
    if key == input.KEY_q or key == input.KEY_Q then return "quit" end
    if key == input.KEY_ESC then return "esc" end

    -- Backspace
    if key == input.KEY_BACKSPACE or key == input.KEY_CTRL_H then
        return "backspace"
    end

    -- Printable ASCII character (for search input)
    if key >= 32 and key <= 126 then
        return "char"
    end

    return nil
end

--- Return the ASCII character for a key code.
-- @param key number
-- @return string|nil
function input.char_for(key)
    if key and key >= 32 and key <= 126 then
        return string.char(key)
    end
    return nil
end

return input
