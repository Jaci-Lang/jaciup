local Test = require("@klur/test")
local Config = require("@jaciup/core/config")
local expect = Test.expect

Test.describe("Jaciup: Config & Settings", function()
    Test.it("should load settings with defaults", function()
        local settings = Config.load()
        expect(type(settings)).toBe("table")
        expect(type(settings.mirror)).toBe("string")
    end)

    Test.it("should set and retrieve default toolchain", function()
        local prev = Config.getDefaultToolchain()
        Config.setDefaultToolchain("test-channel")
        expect(Config.getDefaultToolchain()).toBe("test-channel")
        if prev then
            Config.setDefaultToolchain(prev)
        end
    end)
end)
