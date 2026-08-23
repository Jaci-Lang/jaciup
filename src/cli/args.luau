--!strict
-- Command line argument parser for Jaciup

export type ParsedArgs = {
    command: string?,
    args: {string},
    flags: {[string]: string | boolean},
}

local Args = {}

function Args.parse(rawArgs: {string}): ParsedArgs
    local result: ParsedArgs = {
        command = nil,
        args = {},
        flags = {},
    }

    local i = 1
    while i <= #rawArgs do
        local arg = rawArgs[i]
        if arg:sub(1, 2) == "--" then
            local flag = arg:sub(3)
            local eqIdx = flag:find("=")
            if eqIdx then
                local k = flag:sub(1, eqIdx - 1)
                local v = flag:sub(eqIdx + 1)
                result.flags[k] = v
            else
                if i + 1 <= #rawArgs and not rawArgs[i + 1]:match("^%-") then
                    result.flags[flag] = rawArgs[i + 1]
                    i = i + 1
                else
                    result.flags[flag] = true
                end
            end
        elseif arg:sub(1, 1) == "-" and #arg > 1 then
            local flag = arg:sub(2)
            result.flags[flag] = true
        else
            if not result.command then
                result.command = arg
            else
                table.insert(result.args, arg)
            end
        end
        i = i + 1
    end

    return result
end

return Args
