--!strict
-- Core modules aggregator for Jaciup

local Env = require("./env")
local Platform = require("./platform")
local Config = require("./config")

return {
    Env = Env,
    Platform = Platform,
    Config = Config,
}
