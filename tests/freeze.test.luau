local Test = require("@klur/test")
local Freeze = require("@jaciup/toolchain/freeze")
local Fs = require("@klur/fs")
local Path = require("@klur/path")
local expect = Test.expect

Test.describe("Jaciup: Toolchain Freeze & Discovery", function()
    local testDir = "/tmp/jaciup-test-project"

    Test.beforeEach(function()
        Fs.mkdirp(testDir)
    end)

    Test.afterEach(function()
        Fs.rimraf(testDir)
    end)

    Test.it("should write and read jaciup-toolchain.toml", function()
        local ok = Freeze.writeToolchainFile(testDir, "0.10.0")
        expect(ok).toBe(true)

        local file = Freeze.findToolchainFile(testDir)
        expect(file ~= nil).toBe(true)

        local detected = Freeze.detectPinnedToolchain(testDir)
        expect(detected).toBe("0.10.0")
    end)
end)
