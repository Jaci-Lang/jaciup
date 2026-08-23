local Test = require("@klur/test")
local Manager = require("@jaciup/toolchain/manager")
local Env = require("@jaciup/core/env")
local Fs = require("@klur/fs")
local Path = require("@klur/path")
local expect = Test.expect

Test.describe("Jaciup: Toolchain Manager", function()
    local mockSrcDir = "/tmp/jaciup-mock-src"

    Test.beforeEach(function()
        Env.ensureDirectories()
        Fs.mkdirp(mockSrcDir)
        Fs.writeFile(Path.join(mockSrcDir, "luau"), "#!/bin/sh\nexit 0\n")
        Manager.linkLocal("test-mock", mockSrcDir)
    end)

    Test.afterEach(function()
        Fs.rimraf(mockSrcDir)
        Manager.uninstall("test-mock")
    end)

    Test.it("should list installed toolchains and recognize mock", function()
        local list = Manager.listInstalled()
        expect(type(list)).toBe("table")
        expect(Manager.has("test-mock")).toBe(true)
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
