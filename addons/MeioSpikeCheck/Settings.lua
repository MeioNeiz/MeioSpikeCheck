-- Options panel (Esc > Options > AddOns > MeioSpikeCheck, or /spikes settings).
-- Settings write straight into MeioSpikeCheckDB.
local _, ns = ...

local category

function ns.RegisterSettings()
    if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    category = Settings.RegisterVerticalLayoutCategory("MeioSpikeCheck")
    local db = ns.DB()

    local print = Settings.RegisterAddOnSetting(category, "MEIOSPIKECHECK_PRINT",
        "printHitches", db, Settings.VarType.Boolean, "Each hitch in chat", true)
    Settings.CreateCheckbox(category, print, "After /spikes start, each frame over the "
        .. "threshold is printed in chat with the time, so you can match it to what you did. "
        .. "Off: they are only counted for the report. /spikes stop does this for one run.")

    if Settings.CreateSlider and Settings.CreateSliderOptions then
        local ms = Settings.RegisterAddOnSetting(category, "MEIOSPIKECHECK_MS", "hitchMs", db,
            Settings.VarType.Number, "Threshold (ms)", 100)
        local options = Settings.CreateSliderOptions(50, 500, 10)
        if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        end
        Settings.CreateSlider(category, ms, options, "A frame longer than this counts as a "
            .. "hitch (100 ms is a stutter you notice). Takes effect at the next /spikes "
            .. "start; /spikes start 50 uses 50 for one run.")
    end

    Settings.RegisterAddOnCategory(category)
end

function ns.OpenSettings()
    if not category then return false end
    Settings.OpenToCategory(category:GetID())
    return true
end
