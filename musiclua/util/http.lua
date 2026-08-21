-- musiclua/util/http.lua
-- Simple HTTP/HTTPS download utility using luasocket + luasec

local log = require("musiclua.util.log")

local http = {}

--- Fetch the body of an HTTP/HTTPS URL as a string.
-- @param url    string
-- @param opts   table?  { timeout = number, max_bytes = number }
-- @return string|nil  body
-- @return string|nil  error message
-- @return number|nil  status code
function http.fetch(url, opts)
    opts = opts or {}
    local timeout   = opts.timeout   or 15
    local max_bytes = opts.max_bytes or 5 * 1024 * 1024  -- 5 MB default

    local scheme = url:match("^(https?)://")
    if not scheme then
        return nil, "unsupported scheme (only http/https)", 0
    end

    -- Parse host, port, path
    local host, port, path
    if scheme == "https" then
        host, port, path = url:match("^https://([^:/]+):?(%d*)(/.*)$")
        port = tonumber(port) or 443
    else
        host, port, path = url:match("^http://([^:/]+):?(%d*)(/.*)$")
        port = tonumber(port) or 80
    end
    if not host then
        return nil, "cannot parse URL: " .. url, 0
    end
    if not path or path == "" then path = "/" end

    local sock, err

    if scheme == "https" then
        local ok_ssl, ssl = pcall(require, "ssl")
        if not ok_ssl then
            return nil, "luasec not installed (required for HTTPS). Install: luarocks install luasec", 0
        end
        local tcp = require("socket").tcp()
        tcp:settimeout(timeout)
        local ok_conn, conn_err = tcp:connect(host, port)
        if not ok_conn then
            return nil, "connect failed: " .. tostring(conn_err), 0
        end
        sock = ssl.wrap(tcp, { mode = "client", protocol = "tlsv1_2" })
        local ok_hs, hs_err = sock:dohandshake()
        if not ok_hs then
            sock:close()
            return nil, "TLS handshake failed: " .. tostring(hs_err), 0
        end
    else
        local socket = require("socket")
        sock = socket.tcp()
        sock:settimeout(timeout)
        local ok_conn, conn_err = sock:connect(host, port)
        if not ok_conn then
            return nil, "connect failed: " .. tostring(conn_err), 0
        end
    end

    -- Send HTTP GET request
    local request = string.format(
        "GET %s HTTP/1.1\r\nHost: %s\r\nUser-Agent: musiclua/0.3\r\nConnection: close\r\n\r\n",
        path, host
    )
    sock:send(request)

    -- Read response
    local chunks = {}
    local total = 0
    while true do
        local chunk, read_err, partial = sock:receive(math.min(8192, max_bytes - total))
        if chunk then
            chunks[#chunks + 1] = chunk
            total = total + #chunk
            if total >= max_bytes then break end
        elseif partial and #partial > 0 then
            chunks[#chunks + 1] = partial
            total = total + #partial
            break
        else
            break
        end
    end
    sock:close()

    local raw = table.concat(chunks)

    -- Parse status line and extract body
    local status_code = tonumber(raw:match("^HTTP/%S+ (%d+)")) or 0
    local body = raw:match("\r\n\r\n(.*)$")
    if not body then
        -- Might be a response without body
        body = ""
    end

    -- Handle chunked transfer encoding (simplified: just strip chunk headers)
    if raw:find("Transfer%-Encoding:%s*chunked", 1, true) then
        body = http._decode_chunked(body)
    end

    if status_code >= 400 then
        return nil, "HTTP " .. status_code, status_code
    end

    return body, nil, status_code
end

--- Simple chunked transfer encoding decoder.
-- @param data string
-- @return string
function http._decode_chunked(data)
    local parts = {}
    local pos = 1
    while pos <= #data do
        local size_hex = data:match("^([%x]+)\r?\n", pos)
        if not size_hex then break end
        local size = tonumber(size_hex, 16)
        if not size or size == 0 then break end
        pos = pos + #size_hex + (data:sub(pos + #size_hex, pos + #size_hex) == "\r" and 2 or 1)
        local chunk = data:sub(pos, pos + size - 1)
        parts[#parts + 1] = chunk
        pos = pos + size + (data:sub(pos + size, pos + size) == "\r" and 2 or 1)
    end
    return table.concat(parts)
end

--- Download a URL to a local file.
-- @param url       string
-- @param dest_path string
-- @param opts      table?  forwarded to http.fetch
-- @return boolean  success
-- @return string|nil error message
function http.download(url, dest_path, opts)
    local body, err, code = http.fetch(url, opts)
    if not body then
        return false, err
    end

    local file, file_err = io.open(dest_path, "wb")
    if not file then
        return false, "cannot open file for writing: " .. tostring(file_err)
    end
    file:write(body)
    file:close()
    log.info("downloaded", url, "->", dest_path, "(" .. #body .. " bytes)")
    return true
end

return http
