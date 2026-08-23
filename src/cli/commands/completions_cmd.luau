--!strict
-- Command: jaciup completions <shell>

local Completion = require("../../shell/completion")
local Term = require("@klur/term")

return function(args: {string}): number
    local shell = args[1] or "bash"
    local script = Completion.generate(shell)
    print(script)
    return 0
end
