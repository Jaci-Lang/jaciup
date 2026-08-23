local Test = require("@klur/test")
local Completion = require("@jaciup/shell/completion")
local Profile = require("@jaciup/shell/profile")
local expect = Test.expect

Test.describe("Jaciup: Shell & Completions", function()
    Test.it("should detect shell type", function()
        local shell = Profile.getShellType()
        expect(type(shell)).toBe("string")
    end)

    Test.it("should generate valid completion scripts", function()
        local bash = Completion.generate("bash")
        local zsh = Completion.generate("zsh")
        local fish = Completion.generate("fish")
        local ps = Completion.generate("powershell")

        expect(bash:find("complete -F _jaciup_completions", 1, true) ~= nil).toBe(true)
        expect(zsh:find("#compdef jaciup", 1, true) ~= nil).toBe(true)
        expect(fish:find("complete -c jaciup", 1, true) ~= nil).toBe(true)
        expect(ps:find("Register-ArgumentCompleter", 1, true) ~= nil).toBe(true)
    end)
end)
