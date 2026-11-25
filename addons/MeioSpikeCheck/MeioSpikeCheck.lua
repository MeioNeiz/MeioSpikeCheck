-- MeioSpikeCheck: which addon (or the game itself) is behind the long frames.
-- Every frame over the threshold (100 ms unless /spikes start says) is printed as it happens
-- (with the time) so it can be matched to what you were doing. Per-addon counts come from
-- the client's addon profiler (C_AddOnProfiler) when it is on. The last report is kept in
-- MeioSpikeCheckDB.lastReport.

MeioSpikeCheckDB = MeioSpikeCheckDB or {}

local DEFAULT_HITCH_MS = 100
local hitchMs = DEFAULT_HITCH_MS
local PROFILER_CVAR = "addonProfilerEnabled"
local MAX_HITCHES = 500
local TOP_ADDONS = 8
local P, M = C_AddOnProfiler, Enum and Enum.AddOnProfilerMetric

local function Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffb090ffMeioSpikeCheck:|r " .. msg) end
local function Line(msg) DEFAULT_CHAT_FRAME:AddMessage("  " .. msg) end
local function Cmd(text) return "|cffffd100" .. text .. "|r" end

local function Available() return P and M and P.IsEnabled and P.IsEnabled() end

-- why the per-addon counts are missing and how to get them, or nil when the profiler is on
local function ProfilerProblem()
    if Available() then return end
    if not (P and M) then
        return "this client has no addon profiler, so only hitch times are noted."
    end
    if C_CVar and C_CVar.GetCVar(PROFILER_CVAR) ~= nil then
        return "the addon profiler is off, so only hitch times are noted. Turn it on with "
            .. Cmd("/console " .. PROFILER_CVAR .. " 1") .. " then "
            .. Cmd("/reload") .. "."
    end
    return "the addon profiler is off in this client, so only hitch times are noted."
end
local function Get(fn, ...)
    local ok, v = pcall(fn, ...)
    return ok and type(v) == "number" and v or 0
end

local base   -- counters at /spikes start
local hitches = {}
local watching, loading = false, false

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

-- OnUpdate's elapsed is the length of the frame that just ended
local watch = CreateFrame("Frame")
local function OnUpdate(_, elapsed)
    if loading then return end
    local ms = elapsed * 1000
    if ms < hitchMs then return end
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
watch:SetScript("OnEvent", function(_, event)
    loads = loads + 1
    if event == "LOADING_SCREEN_ENABLED" then
        loading = true
        return
    end
    local this = loads
    C_Timer.After(2, function() if loads == this then loading = false end end)
end)

local function Start(ms)
    hitchMs = ms or DEFAULT_HITCH_MS
    local profiled = Available()
    if not profiled then Say(ProfilerProblem()) end
    base = profiled and Snapshot() or { addons = {} }
    base.profiled = profiled
    base.time = GetTime()
    wipe(hitches)
    watching = true
    watch:SetScript("OnUpdate", OnUpdate)
    Say(("started. Hitches over %d ms are printed as they happen. Play, then type %s.")
        :format(hitchMs, Cmd("/spikes")))
end

local function AddonRows(now)
    local rows = {}
    for name, a in pairs(now.addons) do
        local b = base.addons[name] or { c10 = 0, c50 = 0, c100 = 0, peak = 0 }
        local d10, d50, d100 = a.c10 - b.c10, a.c50 - b.c50, a.c100 - b.c100
        if d10 > 0 then
            rows[#rows + 1] = { name = name, d10 = d10, d50 = d50, d100 = d100,
                peak = a.peak > b.peak and a.peak or nil }
        end
    end
    table.sort(rows, function(x, y)
        if x.d100 ~= y.d100 then return x.d100 > y.d100 end
        if x.d50 ~= y.d50 then return x.d50 > y.d50 end
        return x.d10 > y.d10
    end)
    return rows
end

local function Workflow()
    Say("finds which addon (or the game) is behind long frames")
    Line("1. " .. Cmd("/spikes start") .. " - reset the counters")
    Line("2. play as usual; each frame over " .. DEFAULT_HITCH_MS
        .. " ms is printed with the time, so you can match it to what you did")
    Line("3. " .. Cmd("/spikes")
        .. " - the report: whole game, all addons, the worst addons")
    local problem = ProfilerProblem()
    Line(problem and "|cffff8080" .. problem .. "|r" or "Addon profiler: |cff80ff80on|r"
        .. " (per-addon counts in the report)")
    Line(Cmd("/spikes help") .. " lists every command.")
end

local function Report()
    if not base then Workflow() return end
    local lines = {}
    -- shown: a coloured copy for chat; lastReport keeps plain text
    local function Add(t, shown) lines[#lines + 1] = t Say(shown or t) end
    Add(("%d s since start, %d hitches over %d ms seen."):format(GetTime() - base.time,
        #hitches, hitchMs))
    -- counters from a start without the profiler would count from client start
    local now = base.profiled and Available() and Snapshot()
    if now then
        Add(("Whole game: %d frames over 50 ms, %d over 100 ms."):format(
            now.game50 - base.game50, now.game100 - base.game100))
        Add(("All addons together: %d frames over 50 ms, %d over 100 ms."):format(
            now.all50 - base.all50, now.all100 - base.all100))
        local rows = AddonRows(now)
        if #rows == 0 then Add("No addon had a frame over 10 ms.") end
        for i = 1, math.min(TOP_ADDONS, #rows) do
            local r = rows[i]
            local row = ("%s: over 10/50/100 ms: %d/%d/%d%s"):format(r.name, r.d10, r.d50,
                r.d100, r.peak and (", new worst %.0f ms"):format(r.peak) or "")
            Add("  " .. row, i == 1 and "  |cffff8040" .. row .. "|r" or nil)
        end
    end
    if not now then
        Add(ProfilerProblem() or "the profiler was off at start: no addon counts.")
    end
    for i = math.max(1, #hitches - 9), #hitches do Add("  hitch " .. hitches[i]) end
    MeioSpikeCheckDB.lastReport = table.concat(lines, "\n")
end

local function Help()
    Say("finds which addon (or the game) is behind long frames")
    Line(Cmd("/spikes start [ms]") .. " - reset the counters, print each frame over ms"
        .. " as it happens (default " .. DEFAULT_HITCH_MS .. ")")
    Line(Cmd("/spikes")
        .. " - report since start (whole game, all addons, the worst addons);"
        .. " before a start, how it works")
    Line(Cmd("/spikes stop") .. " - stop printing hitches (counting goes on)")
    Line(Cmd("/spikes off") .. " - stop counting altogether")
    Line(Cmd("/spikes help") .. " - this list")
    local problem = ProfilerProblem()
    if problem then Line("|cffff8080" .. problem .. "|r") end
end

SLASH_MEIOSPIKECHECK1 = "/spikes"
SLASH_MEIOSPIKECHECK2 = "/spike"
SlashCmdList.MEIOSPIKECHECK = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local word, arg = msg:match("^(%S*)%s*(.-)$")
    if word == "start" and (arg == "" or tonumber(arg)) then
        Start(arg ~= "" and math.max(math.floor(tonumber(arg)), 20) or nil)
    elseif msg == "stop" then
        watching = false
        Say("hitches no longer printed; " .. Cmd("/spikes") .. " still reports.")
    elseif msg == "off" then
        watching = false
        base = nil
        watch:SetScript("OnUpdate", nil)
        Say("off. " .. Cmd("/spikes start") .. " to begin again.")
    elseif msg == "" then
        Report()
    elseif msg == "help" or msg == "?" then
        Help()
    else
        Say(('unknown command "%s"'):format(msg))
        Help()
    end
end
