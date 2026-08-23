local Test = require("@klur/test")
local Config = require("@jaciup/core/config")
local Download = require("@jaciup/toolchain/download")
local Crypto = require("@klur/crypto")
local Fs = require("@klur/fs")
local expect = Test.expect

Test.describe("Jaciup: CDN & Releases API Client", function()
    Test.it("should configure registry URL and respect environment overrides", function()
        local defaultUrl = Config.getRegistryUrl()
        expect(type(defaultUrl)).toBe("string")

        process.env["JACI_CDN_URL"] = "http://localhost:8080"
        expect(Config.getRegistryUrl()).toBe("http://localhost:8080")
        process.env["JACI_CDN_URL"] = nil
    end)

    Test.it("should verify SHA-256 checksums correctly", function()
        local testFile = "/tmp/jaciup-sha-test.txt"
        local content = "hello jaciup cdn releases api"
        Fs.writeFile(testFile, content)

        local expectedHash = Crypto.sha256Hex(content)
        expect(Download.verifySha256(testFile, expectedHash)).toBe(true)
        expect(Download.verifySha256(testFile, "0000000000000000000000000000000000000000000000000000000000000000")).toBe(false)

        Fs.unlink(testFile)
    end)
end)
