-- musiclua/util/json.lua
-- JSON utility wrapper around dkjson

local json = {}

local ok, dkjson = pcall(require, "dkjson")
if not ok then
    -- Provide a minimal fallback so the module can still be loaded
    -- (useful for unit tests that don't exercise the mpv IPC path)
    dkjson = nil
end

--- Encode a Lua table to a JSON string.
-- @param tbl table
-- @return string
function json.encode(tbl)
    if dkjson then
        return dkjson.encode(tbl)
    end
    -- Minimal fallback encoder – only handles the simple cases we need
    local t = type(tbl)
    if t == "string" then
        return '"' .. tbl:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(tbl)
    elseif t == "table" then
        local parts = {}
        -- Detect array vs object
        if #tbl > 0 then
            for _, v in ipairs(tbl) do
                parts[#parts + 1] = json.encode(v)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(tbl) do
                parts[#parts + 1] = '"' .. tostring(k) .. '":' .. json.encode(v)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    elseif tbl == nil then
        return "null"
    end
    return tostring(tbl)
end

--- Decode a JSON string to a Lua table.
-- @param str string
-- @return table|nil, string|nil (error message)
function json.decode(str)
    if dkjson then
        local obj, pos, err = dkjson.decode(str)
        if err then return nil, err end
        return obj
    end
    return nil, "dkjson not available; install it with: luarocks install dkjson"
end

return json
