--[[
SPDX-License-Identifier: ISC
Copyright (c) 2023-2026, Sergey Bronnikov.

6.9 – Operating System Facilities
https://www.lua.org/manual/5.3/manual.html#6.9

Synopsis: os.time([table])
]]

local luzer = require("luzer")
local test_lib = require("lib")
local MAX_INT64 = test_lib.MAX_INT64
local MIN_INT64 = test_lib.MIN_INT64

local function TestOneInput(buf)
    local fdp = luzer.FuzzedDataProvider(buf)
    test_lib.random_misc_settings(fdp)
    os.setlocale(test_lib.random_locale(fdp), "all")

    -- os.time() without arguments always works.
    local now = os.time()
    assert(type(now) == "number" and now > 0, "os.time() must be positive")

    local t = {
        day = fdp:consume_number(MIN_INT64, MAX_INT64),
        hour = fdp:consume_number(MIN_INT64, MAX_INT64),
        isdst = fdp:consume_boolean(),
        min = fdp:consume_number(MIN_INT64, MAX_INT64),
        month = fdp:consume_number(MIN_INT64, MAX_INT64),
        sec = fdp:consume_number(MIN_INT64, MAX_INT64),
        year = fdp:consume_number(MIN_INT64, MAX_INT64),
    }
    local ok, ts = pcall(os.time, t)
    if not ok then
        return
    end
    assert(type(ts) == "number" and ts == math.floor(ts),
           "os.time(table) must return an integer")

    -- Roundtrip: encoding then decoding back yields the same timestamp.
    local ok2, t2 = pcall(os.date, "!*t", ts)
    if ok2 and type(t2) == "table" then
        local ts2 = os.time({
            day = t2.day,
            hour = t2.hour,
            min = t2.min,
            month = t2.month,
            sec = t2.sec,
            year = t2.year,
        })
        assert(ts2 == ts,
               ("roundtrip broken: os.time(t)=%s, os.time(os.date(t))=%s")
               :format(tostring(ts), tostring(ts2)))
    end

    -- Normalisation invariants via os.date -> os.time roundtrip.
    local n = {
        day = fdp:consume_integer(0, 60),
        hour = fdp:consume_integer(0, 48),
        min = fdp:consume_integer(0, 120),
        month = fdp:consume_integer(0, 24),
        sec = fdp:consume_integer(0, 120),
        year = fdp:consume_integer(1, 9999),
    }
    local ok3, nts = pcall(os.time, n)
    if not ok3 then
        return
    end
    local nt = os.date("!*t", nts)
    local nts2 = os.time({
        day = nt.day,
        hour = nt.hour,
        min = nt.min,
        month = nt.month,
        sec = nt.sec,
        year = nt.year,
    })
    assert(nts == nts2, "normalisation roundtrip broken")
end

local args = {
    artifact_prefix = "os_time_",
}
luzer.Fuzz(TestOneInput, nil, args)
