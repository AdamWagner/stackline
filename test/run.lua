local root = assert(os.getenv("PWD"), "PWD must be set when running tests")
package.path = table.concat({
    root .. "/?.lua",
    root .. "/?/init.lua",
    root .. "/test/?.lua",
    package.path,
}, ";")

local suites = {
    "test.conf_spec",
    "test.query_spec",
    "test.window_spec",
}

local total = 0
local failures = {}

for _, suite_name in ipairs(suites) do
    local suite = require(suite_name)
    local test_names = {}

    for name in pairs(suite) do
        if name:match("^test_") then
            table.insert(test_names, name)
        end
    end

    table.sort(test_names)

    for _, test_name in ipairs(test_names) do
        total = total + 1
        io.write(string.format("RUN %s.%s\n", suite_name, test_name))
        local ok, err = xpcall(suite[test_name], debug.traceback)
        if ok then
            io.write("PASS\n")
        else
            io.write("FAIL\n")
            table.insert(failures, {
                name = suite_name .. "." .. test_name,
                error = err,
            })
        end
    end
end

io.write(string.format("\n%d tests, %d failures\n", total, #failures))

if #failures > 0 then
    for _, failure in ipairs(failures) do
        io.write(string.format("\n[%s]\n%s\n", failure.name, failure.error))
    end
    os.exit(1)
end
