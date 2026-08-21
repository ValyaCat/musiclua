-- musiclua/init.lua
-- Package entry point

local version = require("musiclua.version")

local musiclua = {}

musiclua._VERSION     = version.string
musiclua._VERSION_NUM = { major = version.major, minor = version.minor, patch = version.patch }

--- Launch the TUI application.
-- @param opts table  { library = string, player = string }
function musiclua.run_tui(opts)
    opts = opts or {}
    local app = require("musiclua.app")
    app.run({
        directory = opts.library,
    })
end

return musiclua
