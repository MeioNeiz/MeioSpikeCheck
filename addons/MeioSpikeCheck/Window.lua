-- The /spikes window: this run's worst addons, each with a Turn off (from the next
-- /reload) button; after a /reload, the run before it. Headers sort (kept in the SV).
local _, ns = ...

local W, ROW_H = 560, 22
local function Col(label, x, w, justify)
    return { label = label, x = x, w = w, justify = justify }
end
local COLS = { Col("Addon", 16, 166, "LEFT"), Col("50 ms+", 182, 56, "RIGHT"),
    Col("100 ms+", 240, 58, "RIGHT"), Col("Worst", 300, 58, "RIGHT"),
    Col("Memory", 360, 98, "RIGHT") }
local GOLD, GREY, RED, GREEN, ORANGE = "|cffffd100", "|cff999999", "|cffff8080",
    "|cff80ff80", "|cffff8040"

local frame, ticker
local rowNames = {}

-- per column: the value it sorts by; the natural order is biggest first, A to Z for names.
-- Ties keep the worst-first order, so 100 ms+ in its natural order is the default.
local SORT_BY = { function(r) return r.name:lower() end, function(r) return r.d50 end,
    function(r) return r.d100 end, function(r) return r.peak or 0 end,
    function(r) return r.kb or 0 end }
local DEFAULT_SORT = 3

local function SortCol()
    local c = ns.DB().sortCol
    return SORT_BY[c] and c or DEFAULT_SORT
end

local function Sorted(rows)
    local col, rev = SortCol(), ns.DB().sortRev
    local by, rank, out = SORT_BY[col], {}, {}
    for i, row in ipairs(rows) do rank[row], out[i] = i, row end
    local up = col == 1
    table.sort(out, function(x, y)
        if rev then x, y = y, x end
        local a, b = by(x), by(y)
        if a ~= b then
            if up then return a < b end
            return a > b
        end
        return rank[x] < rank[y]
    end)
    return out
end

-- the arrow sits on the label's inner side (left of right-aligned numbers)
local function ShowArrow()
    local col, rev = SortCol(), ns.DB().sortRev
    local up = (col == 1) == not rev
    for j, h in ipairs(frame.header.cols) do
        local a, fs = h.arrow, h.label
        a:SetShown(j == col)
        if j == col then
            a:ClearAllPoints()
            if COLS[j].justify == "LEFT" then
                a:SetPoint("LEFT", fs, "LEFT", fs:GetStringWidth() + 3, 0)
            else
                a:SetPoint("RIGHT", fs, "RIGHT", -fs:GetStringWidth() - 3, 0)
            end
            local t, b = up and 1 or 0, up and 0 or 1
            a:SetTexCoord(0, 0.5625, t, b)
            a.up = up
        end
    end
end

local function Duration(s)
    s = math.floor(s)
    if s < 60 then return s .. " s" end
    if s < 3600 then return ("%dm %02ds"):format(s / 60, s % 60) end
    return ("%dh %02dm"):format(s / 3600, s % 3600 / 60)
end

local function Memory(kb, grow)
    if not kb then return "" end
    local t = kb >= 1024 and ("%.1f MB"):format(kb / 1024) or ("%d KB"):format(kb)
    if grow and grow >= 512 then t = t .. ORANGE .. (" +%.1f"):format(grow / 1024) .. "|r" end
    return t
end

local function Text(parent, template, x, y, w, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    if w then fs:SetWidth(w) end
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(not w)
    return fs
end

local function Button(parent, text, w, onClick, tip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tipTitle or self:GetText(), 1, 1, 1)
            GameTooltip:AddLine(self.tip or tip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
    end
    return b
end

local function Refresh()
    if not (frame and frame:IsShown()) then return end
    local r, before = ns.Current(), false
    if not r and ns.DB().last then r, before = ns.DB().last, true end

    local status
    if before then
        status = ("%s%s|r (%s to %s, %s counted). Start for a new run."):format(GOLD,
            r.reload and "Before your last reload" or "Your last run", r.clock or "?",
            r.ended or "?", Duration(r.secs))
    elseif r then
        status = ("Counting for %s. %d hitch%s over %d ms."):format(Duration(r.secs),
            r.count, r.count == 1 and "" or "es", r.ms)
    else
        status = ("Press %sStart|r, play as usual, then come back here (%s). Each frame "
            .. "over %d ms is noted with the time."):format(GOLD, ns.Cmd("/spikes"),
            ns.DB().hitchMs)
    end
    frame.status:SetText(status)

    local problem = (not r or not r.profiled) and ns.ProfilerProblem(true)
    frame.problem:SetText(problem and RED .. problem .. "|r" or "")
    frame.profilerBtn:SetShown(problem and ns.CanTurnOnProfiler() or false)

    if r and r.profiled then
        frame.totals:SetText(("Whole game: %s%d|r frames over 50 ms, %s%d|r over 100 ms.  "
            .. "All addons: %d and %d."):format(GOLD, r.game50, GOLD, r.game100, r.all50,
            r.all100))
    else
        frame.totals:SetText("")
    end

    local rows = r and r.rows or {}
    local worst = rows[1] and rows[1].name
    rows = Sorted(rows)
    frame.header:SetShown(#rows > 0)
    ShowArrow()
    for i, line in ipairs(frame.rows) do
        local row = rows[i]
        line:SetShown(row ~= nil)
        if row then
            local off = ns.IsOff(row.name)
            local colour = off and GREY or row.name == worst and ORANGE or ""
            line.cells[1]:SetText(colour .. row.name .. (off and (C_AddOns.IsAddOnLoaded(row.name)
                and " (off after reload)" or " (off)") or "")
                .. (colour ~= "" and "|r" or ""))
            line.cells[2]:SetText(row.d50)
            line.cells[3]:SetText(row.d100 > 0 and RED .. row.d100 .. "|r" or row.d100)
            line.cells[4]:SetText(row.peak and ("%.0f ms"):format(row.peak) or "")
            line.cells[5]:SetText(Memory(row.kb, row.grow))
            rowNames[i] = row.name
            line.toggle:SetText(off and "Turn on" or "Turn off")
            line.toggle.tip = off
                and ("Leave " .. row.name .. " on after the next /reload.")
                or ("Turn " .. row.name .. " off for this character from the next /reload, "
                .. "to see if the stutter goes. Turn it back on here or in the AddOns list.")
        end
    end
    local none = r and r.profiled and #rows == 0
    frame.empty:SetText(none and GREEN .. "No addon had a frame over 10 ms.|r" or "")

    local list = r and r.hitches or {}
    frame.hitches:SetText(#list > 0 and (GOLD .. "Last hitches:|r " .. table.concat(list,
        ",  ")) or "")

    local pending = ns.Pending()
    frame.reload:SetShown(#pending > 0)
    frame.reloadNote:SetText(#pending > 0 and (GREY .. "Changes apply after a reload: "
        .. table.concat(pending, ", ") .. "|r") or "")
    frame.start:SetText(ns.Running() and "Start again" or "Start")
    frame.chat:SetShown(ns.Running())
end
ns.RefreshWindow = Refresh

local function Create()
    frame = CreateFrame("Frame", "MeioSpikeCheckFrame", UIParent, "ButtonFrameTemplate")
    if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(frame) end
    frame:SetSize(W, 120 + ROW_H * ns.TOP_ADDONS + 110)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetTitle then frame:SetTitle("MeioSpikeCheck") end
    tinsert(UISpecialFrames, frame:GetName())
    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", 8, -28)
        frame.Inset:SetPoint("BOTTOMRIGHT", -8, 40)
    end

    local y = -38
    frame.status = Text(frame, "GameFontHighlight", 18, y)
    frame.status:SetWidth(W - 36)
    frame.problem = Text(frame, "GameFontHighlightSmall", 18, y - 34)
    frame.problem:SetWidth(W - 200)
    frame.profilerBtn = Button(frame, "Turn on profiler", 150, function()
        C_CVar.SetCVar(ns.PROFILER_CVAR, "1")
        ReloadUI()
    end, "Turns on the game's addon profiler and reloads, so the report can name addons.")
    frame.profilerBtn:SetPoint("TOPRIGHT", -18, y - 28)
    frame.totals = Text(frame, "GameFontHighlightSmall", 18, y - 34)
    frame.totals:SetWidth(W - 36)

    local top = y - 60
    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT", 0, top)
    frame.header:SetSize(W, ROW_H)
    frame.header.cols = {}
    for j, c in ipairs(COLS) do
        local h = CreateFrame("Button", nil, frame.header)
        h:SetPoint("TOPLEFT", c.x + 2, 0)
        h:SetSize(c.w, ROW_H)
        h:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        h.label = Text(h, "GameFontNormalSmall", 0, -4, c.w, c.justify)
        h.label:SetText(c.label)
        h.arrow = h:CreateTexture(nil, "OVERLAY")
        h.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
        h.arrow:SetSize(9, 8)
        h:SetScript("OnClick", function()
            local db = ns.DB()
            if SortCol() == j then
                db.sortRev = not db.sortRev
            else
                db.sortCol, db.sortRev = j, false
            end
            Refresh()
        end)
        frame.header.cols[j] = h
    end
    frame.rows = {}
    for i = 1, ns.TOP_ADDONS do
        local line = CreateFrame("Frame", nil, frame)
        line:SetPoint("TOPLEFT", 0, top - i * ROW_H)
        line:SetSize(W, ROW_H)
        if i % 2 == 1 then
            local bg = line:CreateTexture(nil, "BACKGROUND", nil, 1)
            bg:SetPoint("TOPLEFT", 12, 0)
            bg:SetPoint("BOTTOMRIGHT", -12, 0)
            bg:SetColorTexture(1, 1, 1, 0.04)
        end
        line.cells = {}
        for j, c in ipairs(COLS) do
            line.cells[j] = Text(line, "GameFontHighlight", c.x + 2, -4, c.w, c.justify)
        end
        line.toggle = Button(line, "Turn off", 76, function()
            ns.SetOff(rowNames[i], not ns.IsOff(rowNames[i]))
            Refresh()
        end, "")
        line.toggle:SetPoint("RIGHT", -16, 0)
        line.toggle:SetHeight(20)
        frame.rows[i] = line
    end
    frame.empty = Text(frame, "GameFontHighlight", 18, top - ROW_H - 4)
    frame.hitches = Text(frame, "GameFontHighlightSmall", 18, top - (ns.TOP_ADDONS + 1)
        * ROW_H - 8)
    frame.hitches:SetWidth(W - 36)
    frame.reloadNote = Text(frame, "GameFontHighlightSmall", 18, top - (ns.TOP_ADDONS + 1)
        * ROW_H - 40)
    frame.reloadNote:SetWidth(W - 36)

    frame.start = Button(frame, "Start", 110, function() ns.Start() end,
        "Reset the counters and watch from now.")
    frame.start:SetPoint("BOTTOMLEFT", 14, 10)
    frame.chat = Button(frame, "Report in chat", 130, function() ns.ChatReport() end,
        "Print this report in chat (also kept for after a /reload).")
    frame.chat:SetPoint("LEFT", frame.start, "RIGHT", 6, 0)
    frame.reload = Button(frame, "Reload now", 110, function() ReloadUI() end,
        "Reload the interface so the addons you turned on or off change.")
    frame.reload:SetPoint("BOTTOMRIGHT", -14, 10)

    frame:SetScript("OnShow", function()
        ns.RefreshMemory()
        Refresh()
        ticker = C_Timer.NewTicker(1, Refresh)
    end)
    frame:SetScript("OnHide", function()
        if ticker then ticker:Cancel() ticker = nil end
    end)
    frame:Hide()
end

function ns.ToggleWindow()
    if not frame then Create() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
