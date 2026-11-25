-- MeioSpikeCheck: which addon (or the game itself) is behind the long frames.
-- Every frame over the threshold is printed as it happens (with the time) so it can be
-- matched to what you were doing. Per-addon counts come from the client's addon profiler
-- (C_AddOnProfiler) when it is on. The last report is kept in MeioSpikeCheckDB.last
-- (rows, for the window after a /reload) and .lastReport (plain text).
local _, ns = ...

MeioSpikeCheckDB = MeioSpikeCheckDB or {}

local DEFAULTS = { printHitches = true, hitchMs = 100 }
local PROFILER_CVAR = "addonProfilerEnabled"
local MAX_HITCHES = 500
local TOP_ADDONS = 8
local P, M = C_AddOnProfiler, Enum and Enum.AddOnProfilerMetric

ns.TOP_ADDONS = TOP_ADDONS
ns.PROFILER_CVAR = PROFILER_CVAR

local function Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffb090ffMeioSpikeCheck:|r " .. msg) end
local function Line(msg) DEFAULT_CHAT_FRAME:AddMessage("  " .. msg) end
local function Cmd(text) return "|cffffd100" .. text .. "|r" end
ns.Say, ns.Cmd = Say, Cmd

local db
local function DB()
    if not db then
        db = MeioSpikeCheckDB
        for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
        db.disabled = db.disabled or {}
        ns.db = db
    end
    return db
end
ns.DB = DB

local function Available() return P and M and P.IsEnabled and P.IsEnabled() end
ns.Available = Available

function ns.CanTurnOnProfiler()
    return P and M and C_CVar and C_CVar.GetCVar(PROFILER_CVAR) ~= nil and not Available()
end

-- why the per-addon counts are missing and how to get them, or nil when the profiler is on
local function ProfilerProblem(plain)
    if Available() then return end
    if not (P and M) then
        return "this client has no addon profiler, so only hitch times are noted."
    end
    if C_CVar and C_CVar.GetCVar(PROFILER_CVAR) ~= nil then
        if plain then return "the addon profiler is off, so only hitch times are noted." end
        return "the addon profiler is off, so only hitch times are noted. Turn it on with "
            .. Cmd("/console " .. PROFILER_CVAR .. " 1") .. " then "
            .. Cmd("/reload") .. "."
    end
    return "the addon profiler is off in this client, so only hitch times are noted."
end
ns.ProfilerProblem = ProfilerProblem

local function Get(fn, ...)
    local ok, v = pcall(fn, ...)
    return ok and type(v) == "number" and v or 0
end

local run   -- this session's counting: base counters, start time, threshold
local hitches = {}
local watching, loading = false, false
local memory = {}   -- KB per addon, at start and when the report was last opened

local function Snapshot()
    local s = { addons = {} }
    s.game50 = Get(P.GetApplicationMetric, M.CountTimeOver50Ms)
    s.game100 = Get(P.GetApplicationMetric, M.CountTimeOver100Ms)
    s.all50 = Get(P.GetOverallMetric, M.CountTimeOver50Ms)
    s.all100 = Get(P.GetOverallMetric, M.CountTimeOver100Ms)
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if C_AddOns.IsAddOnLoaded(i) then
            s.addons[name] = {
                c10 = Get(P.GetAddOnMetric, name, M.CountTimeOver10Ms),
                c50 = Get(P.GetAddOnMetric, name, M.CountTimeOver50Ms),
                c100 = Get(P.GetAddOnMetric, name, M.CountTimeOver100Ms),
                peak = Get(P.GetAddOnMetric, name, M.PeakTime),
            }
        end
    end
    return s
end

-- UpdateAddOnMemoryUsage can take a few ms with many addons: only at start and on open
local function ReadMemory()
    if not (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage) then return {} end
    pcall(UpdateAddOnMemoryUsage)
    local out = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if C_AddOns.IsAddOnLoaded(i) then out[name] = Get(GetAddOnMemoryUsage, name) end
    end
    return out
end

function ns.RefreshMemory()
    if run then memory.now = ReadMemory() end
end

-- OnUpdate's elapsed is the length of the frame that just ended
local watch = CreateFrame("Frame")
local function OnUpdate(_, elapsed)
    if loading then return end
    local ms = elapsed * 1000
    if ms < run.ms then return end
    local text = ("%s  %.0f ms%s"):format(date("%H:%M:%S"), ms,
        InCombatLockdown() and " (combat)" or "")
    if #hitches >= MAX_HITCHES then table.remove(hitches, 1) end
    hitches[#hitches + 1] = text
    if watching then Say("hitch " .. text) end
end

-- a loading screen is one long frame by design. loads counts them so a timer left from
-- an earlier one can't end the quiet spell of a newer one.
local loads = 0
watch:RegisterEvent("LOADING_SCREEN_ENABLED")
watch:RegisterEvent("LOADING_SCREEN_DISABLED")
watch:RegisterEvent("PLAYER_ENTERING_WORLD")
watch:RegisterEvent("PLAYER_LOGIN")
watch:RegisterEvent("PLAYER_LOGOUT")
watch:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        DB()
        if ns.RegisterSettings then pcall(ns.RegisterSettings) end
        return
    elseif event == "PLAYER_LOGOUT" then
        if run then ns.SaveLast(true) end
        return
    end
    loads = loads + 1
    if event == "LOADING_SCREEN_ENABLED" then
        loading = true
        return
    end
    local this = loads
    C_Timer.After(2, function() if loads == this then loading = false end end)
end)

function ns.Start(ms)
    DB()
    local profiled = Available()
    if not profiled then Say(ProfilerProblem()) end
    run = profiled and Snapshot() or { addons = {} }
    run.profiled = profiled
    run.time = GetTime()
    run.clock = date("%H:%M")
    run.ms = ms or db.hitchMs
    memory = { start = ReadMemory() }
    memory.now = memory.start
    wipe(hitches)
    watching = db.printHitches
    watch:SetScript("OnUpdate", OnUpdate)
    Say(("started. Hitches over %d ms are %s. Play, then type %s.")
        :format(run.ms, watching and "printed as they happen" or "noted", Cmd("/spikes")))
    if ns.RefreshWindow then ns.RefreshWindow() end
end

function ns.Running() return run ~= nil end

-- this run's report: { secs, ms, clock, hitches, profiled, game/all counts, rows }
function ns.Current()
    if not run then return end
    local r = { secs = GetTime() - run.time, ms = run.ms, clock = run.clock,
        hitches = { unpack(hitches, math.max(1, #hitches - 9)) }, count = #hitches,
        profiled = false, rows = {} }
    local now = run.profiled and Available() and Snapshot()
    if not now then return r end
    r.profiled = true
    r.game50, r.game100 = now.game50 - run.game50, now.game100 - run.game100
    r.all50, r.all100 = now.all50 - run.all50, now.all100 - run.all100
    for name, a in pairs(now.addons) do
        local b = run.addons[name] or { c10 = 0, c50 = 0, c100 = 0, peak = 0 }
        local d10, d50, d100 = a.c10 - b.c10, a.c50 - b.c50, a.c100 - b.c100
        if d10 > 0 then
            local m0, m1 = memory.start and memory.start[name], memory.now and memory.now[name]
            r.rows[#r.rows + 1] = { name = name, d10 = d10, d50 = d50, d100 = d100,
                peak = a.peak > b.peak and a.peak or nil, kb = m1,
                grow = m0 and m1 and m1 - m0 or nil }
        end
    end
    table.sort(r.rows, function(x, y)
        if x.d100 ~= y.d100 then return x.d100 > y.d100 end
        if x.d50 ~= y.d50 then return x.d50 > y.d50 end
        return x.d10 > y.d10
    end)
    for i = #r.rows, TOP_ADDONS + 1, -1 do r.rows[i] = nil end
    return r
end

-- kept for the window after a /reload: the run before it, with the time it ended
function ns.SaveLast(reload)
    local r = ns.Current()
    if not r then return end
    r.ended = date("%H:%M")
    r.reload = reload
    DB().last = r
end

function ns.Stop()
    watching = false
    Say("hitches no longer printed; " .. Cmd("/spikes") .. " still reports.")
end

function ns.Off()
    if run then ns.SaveLast() end
    watching = false
    run = nil
    watch:SetScript("OnUpdate", nil)
    Say("off. " .. Cmd("/spikes start") .. " to begin again.")
    if ns.RefreshWindow then ns.RefreshWindow() end
end

local function RowText(r)
    return ("%s: over 10/50/100 ms: %d/%d/%d%s"):format(r.name, r.d10, r.d50, r.d100,
        r.peak and (", new worst %.0f ms"):format(r.peak) or "")
end

local function Workflow()
    Say("finds which addon (or the game) is behind long frames")
    Line("1. " .. Cmd("/spikes start") .. " - reset the counters")
    Line("2. play as usual; each frame over " .. DB().hitchMs
        .. " ms is printed with the time, so you can match it to what you did")
    Line("3. " .. Cmd("/spikes") .. " - the report window (or " .. Cmd("/spikes report")
        .. " in chat)")
    local problem = ProfilerProblem()
    Line(problem and "|cffff8080" .. problem .. "|r" or "Addon profiler: |cff80ff80on|r"
        .. " (per-addon counts in the report)")
end

function ns.ChatReport()
    local r = ns.Current()
    if not r then Workflow() return end
    local lines = {}
    -- shown: a coloured copy for chat; lastReport keeps plain text
    local function Add(t, shown) lines[#lines + 1] = t Say(shown or t) end
    Add(("%d s since start, %d hitches over %d ms seen."):format(r.secs, r.count, r.ms))
    if r.profiled then
        Add(("Whole game: %d frames over 50 ms, %d over 100 ms."):format(r.game50, r.game100))
        Add(("All addons together: %d frames over 50 ms, %d over 100 ms."):format(r.all50,
            r.all100))
        if #r.rows == 0 then Add("No addon had a frame over 10 ms.") end
        for i, row in ipairs(r.rows) do
            local t = RowText(row)
            Add("  " .. t, i == 1 and "  |cffff8040" .. t .. "|r" or nil)
        end
    else
        Add(ProfilerProblem() or "the profiler was off at start: no addon counts.")
    end
    for _, h in ipairs(r.hitches) do Add("  hitch " .. h) end
    MeioSpikeCheckDB.lastReport = table.concat(lines, "\n")
    ns.SaveLast()
end

-- off from the next /reload for this character; DisableAddOn wants a name, not a unit
local function Me() return UnitName("player") end
function ns.IsOff(name)
    return C_AddOns.GetAddOnEnableState(name, Me()) == 0
end
function ns.SetOff(name, off)
    if off then C_AddOns.DisableAddOn(name, Me()) else C_AddOns.EnableAddOn(name, Me()) end
    DB().disabled[name] = off or nil
    if C_AddOns.SaveAddOns then C_AddOns.SaveAddOns() end
end
-- names whose on/off state differs from how they loaded this session
function ns.Pending()
    local out = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if C_AddOns.IsAddOnLoaded(i) == ns.IsOff(name) then out[#out + 1] = name end
    end
    return out
end

local function Help()
    Say("finds which addon (or the game) is behind stutters and long frames")
    Line(Cmd("/spikes") .. " - open the report window")
    Line(Cmd("/spikes start [ms]") .. " - reset the counters and watch for frames over ms"
        .. " (now " .. DB().hitchMs .. ")")
    Line(Cmd("/spikes report") .. " - the report in chat")
    Line(Cmd("/spikes stop") .. " - stop printing hitches (counting goes on)")
    Line(Cmd("/spikes off") .. " - stop counting altogether")
    Line(Cmd("/spikes help") .. " - this list")
    Line("Settings: Esc > Options > AddOns > MeioSpikeCheck (" .. Cmd("/spikes settings")
        .. ")")
end

function MeioSpikeCheck_OnAddonCompartmentClick() ns.ToggleWindow() end

SLASH_MEIOSPIKECHECK1 = "/spikes"
SLASH_MEIOSPIKECHECK2 = "/spike"
SlashCmdList.MEIOSPIKECHECK = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local word, arg = msg:match("^(%S*)%s*(.-)$")
    if word == "start" and (arg == "" or tonumber(arg)) then
        ns.Start(arg ~= "" and math.max(math.floor(tonumber(arg)), 20) or nil)
    elseif msg == "stop" then
        ns.Stop()
    elseif msg == "off" then
        ns.Off()
    elseif msg == "" then
        ns.ToggleWindow()
    elseif msg == "report" then
        ns.ChatReport()
    elseif msg == "settings" or msg == "options" then
        if not (ns.OpenSettings and ns.OpenSettings()) then Help() end
    elseif msg == "help" or msg == "?" then
        Help()
    else
        Say(('unknown command "%s"'):format(msg))
        Help()
    end
end
