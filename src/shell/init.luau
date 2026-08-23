--!strict
-- Shell integration aggregator for Jaciup

local Profile = require("./profile")
local Completion = require("./completion")

return {
    Profile = Profile,
    Completion = Completion,
}
