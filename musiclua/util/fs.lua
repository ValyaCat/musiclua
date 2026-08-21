-- musiclua/util/fs.lua
-- Filesystem utility functions

local lfs = require("lfs")

local fs = {}

--- Check if a path exists.
-- @param path string
-- @return boolean
function fs.exists(path)
    local ok, _ = lfs.attributes(path)
    return ok ~= nil
end

--- Check if path is a regular file.
-- @param path string
-- @return boolean
function fs.is_file(path)
    local attr, _ = lfs.attributes(path)
    return attr ~= nil and attr.mode == "file"
end

--- Check if path is a directory.
-- @param path string
-- @return boolean
function fs.is_dir(path)
    local attr, _ = lfs.attributes(path)
    return attr ~= nil and attr.mode == "directory"
end

--- Expand leading ~ to the user's home directory.
-- @param path string
-- @return string
function fs.expand_user(path)
    if type(path) ~= "string" then return path end
    if path:sub(1, 1) == "~" then
        local home = os.getenv("HOME")
        if not home then
            -- Fallback for non-POSIX systems
            home = os.getenv("USERPROFILE") or ""
        end
        path = home .. path:sub(2)
    end
    return path
end

--- Check whether a filename has one of the allowed audio extensions.
-- @param filename string
-- @param extensions table  list of extensions including the dot, e.g. {".mp3",".ogg"}
-- @return boolean
function fs.has_audio_ext(filename, extensions)
    if type(filename) ~= "string" then return false end
    local ext = filename:match("(%.[^%.]+)$")
    if not ext then return false end
    ext = ext:lower()
    for _, e in ipairs(extensions) do
        if ext == e:lower() then
            return true
        end
    end
    return false
end

--- Join two path segments with a separator.
-- @param a string
-- @param b string
-- @return string
function fs.join_path(a, b)
    if not a or a == "" then return b end
    if not b or b == "" then return a end
    -- Avoid double slash
    if a:sub(-1) == "/" then
        return a .. b
    end
    return a .. "/" .. b
end

--- Return the basename (filename component) of a path.
-- @param path string
-- @return string
function fs.basename(path)
    if type(path) ~= "string" then return "" end
    return path:match("([^/]+)/*$") or path
end

--- Check whether a filename is hidden (starts with a dot).
-- @param name string  filename (not full path)
-- @return boolean
function fs.is_hidden(name)
    if type(name) ~= "string" then return false end
    return name:sub(1, 1) == "."
end

--- Return a sorted list of filenames in a directory (non-recursive, one level).
-- Skips "." and "..".
-- @param dir string
-- @return table|nil  list of filenames, or nil on error
-- @return string|nil error message
function fs.scandir(dir)
    local entries = {}

    -- lfs.dir returns (iterator, state, initial) for generic for.
    -- Wrap in pcall to catch errors (bad path, permissions, etc.)
    local ok, iter, state, initial = pcall(lfs.dir, dir)
    if not ok then
        return nil, tostring(iter)
    end
    if not iter then
        return nil, "cannot open directory"
    end

    -- Use the three-value generic for to be compatible with all lfs versions
    for name in iter, state, initial do
        if name ~= "." and name ~= ".." then
            entries[#entries + 1] = name
        end
    end

    table.sort(entries)
    return entries
end

return fs
