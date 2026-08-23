local Test = require("@klur/test")
local Manager = require("@jaciup/toolchain/manager")
local expect = Test.expect

Test.describe("Jaciup: Toolchain Manager", function()
    Test.it("should list installed toolchains and recognize dev", function()
        local list = Manager.listInstalled()
        expect(type(list)).toBe("table")
        expect(Manager.has("dev")).toBe(true)
    end)

    Test.it("should resolve active toolchain", function()
        local active, reason = Manager.resolveActiveToolchain()
        expect(active ~= "").toBe(true)
        expect(reason ~= "").toBe(true)
    end)

    Test.it("should locate luau binary via which", function()
        local path = Manager.which("luau")
        expect(path ~= nil).toBe(true)
        expect((path :: string):find("luau", 1, true) ~= nil).toBe(true)
    end)
end)
