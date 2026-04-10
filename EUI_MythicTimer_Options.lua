-------------------------------------------------------------------------------
--  EUI_MythicTimer_Options.lua
--  Registers the Mythic+ Timer module with EllesmereUI sidebar options.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local PAGE_DISPLAY = "Mythic+ Timer"

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    if not EllesmereUI or not EllesmereUI.RegisterModule then return end

    local db
    C_Timer.After(0, function() db = _G._EMT_AceDB end)

    local function DB()
        if not db then db = _G._EMT_AceDB end
        return db and db.profile
    end

    local function Cfg(key)
        local p = DB()
        return p and p[key]
    end

    local function Set(key, val)
        local p = DB()
        if p then p[key] = val end
    end

    local function Refresh()
        if _G._EMT_Apply then _G._EMT_Apply() end
    end

    ---------------------------------------------------------------------------
    --  Build Page
    ---------------------------------------------------------------------------
    local function BuildPage(_, parent, yOffset)
        local W = EllesmereUI.Widgets
        local y = yOffset
        local row, h

        if EllesmereUI.ClearContentHeader then EllesmereUI:ClearContentHeader() end
        parent._showRowDivider = true

        -- ── DISPLAY ────────────────────────────────────────────────────────
        _, h = W:SectionHeader(parent, "DISPLAY", y); y = y - h

        row, h = W:DualRow(parent, y,
            { type="toggle", text="Enable Module",
              getValue=function() return Cfg("enabled") ~= false end,
              setValue=function(v) Set("enabled", v); Refresh() end },
            { type="toggle", text="Detach from Quest Tracker",
              disabled=function() return Cfg("enabled") == false end,
              disabledTooltip="Module is disabled",
              getValue=function() return Cfg("detached") == true end,
              setValue=function(v) Set("detached", v); Refresh() end })
        y = y - h

        -- ── TIMER ──────────────────────────────────────────────────────────
        _, h = W:SectionHeader(parent, "TIMER", y); y = y - h

        row, h = W:DualRow(parent, y,
            { type="toggle", text="Show +2 Threshold",
              disabled=function() return Cfg("enabled") == false end,
              disabledTooltip="Module is disabled",
              getValue=function() return Cfg("showPlusTwo") ~= false end,
              setValue=function(v) Set("showPlusTwo", v); Refresh() end },
            { type="toggle", text="Show +3 Threshold",
              disabled=function() return Cfg("enabled") == false end,
              disabledTooltip="Module is disabled",
              getValue=function() return Cfg("showPlusThree") ~= false end,
              setValue=function(v) Set("showPlusThree", v); Refresh() end })
        y = y - h

        local alignValues = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }
        local alignOrder  = { "LEFT", "CENTER", "RIGHT" }
        row, h = W:DualRow(parent, y,
            { type="dropdown", text="Timer Align",
              disabled=function() return Cfg("enabled") == false end,
              disabledTooltip="Module is disabled",
              values=alignValues,
              order=alignOrder,
              getValue=function() return Cfg("timerAlign") or "CENTER" end,
              setValue=function(v) Set("timerAlign", v); Refresh() end },
            { type="label", text="" })
        y = y - h

        -- ── OBJECTIVES ─────────────────────────────────────────────────────
        _, h = W:SectionHeader(parent, "OBJECTIVES", y); y = y - h

        row, h = W:DualRow(parent, y,
            { type="toggle", text="Show Affixes",
              disabled=function() return Cfg("enabled") == false end,
              disabledTooltip="Module is disabled",
              getValue=function() return Cfg("showAffixes") ~= false end,
              setValue=function(v) Set("showAffixes", v); Refresh() end },
            { type="toggle", text="Show Deaths",
              disabled=function() return Cfg("enabled") == false end,
              disabledTooltip="Module is disabled",
              getValue=function() return Cfg("showDeaths") ~= false end,
              setValue=function(v) Set("showDeaths", v); Refresh() end })
        y = y - h

        row, h = W:DualRow(parent, y,
            { type="toggle", text="Show Boss Objectives",
              disabled=function() return Cfg("enabled") == false end,
              disabledTooltip="Module is disabled",
              getValue=function() return Cfg("showObjectives") ~= false end,
              setValue=function(v) Set("showObjectives", v); Refresh() end },
            { type="toggle", text="Show Enemy Forces",
              disabled=function() return Cfg("enabled") == false end,
              disabledTooltip="Module is disabled",
              getValue=function() return Cfg("showEnemyBar") ~= false end,
              setValue=function(v) Set("showEnemyBar", v); Refresh() end })
        y = y - h

        row, h = W:DualRow(parent, y,
            { type="dropdown", text="Objective Align",
              disabled=function() return Cfg("enabled") == false end,
              disabledTooltip="Module is disabled",
              values=alignValues,
              order=alignOrder,
              getValue=function() return Cfg("objectiveAlign") or "LEFT" end,
              setValue=function(v) Set("objectiveAlign", v); Refresh() end },
            { type="label", text="" })
        y = y - h

        parent:SetHeight(math.abs(y - yOffset))
    end

    ---------------------------------------------------------------------------
    --  RegisterModule
    ---------------------------------------------------------------------------
    EllesmereUI:RegisterModule("EllesmereUIMythicTimer", {
        title    = "Mythic+ Timer",
        icon_on  = "Interface\\AddOns\\EllesmereUI\\media\\icons\\sidebar\\consumables-ig.tga",
        icon_off = "Interface\\AddOns\\EllesmereUI\\media\\icons\\sidebar\\consumables-g.tga",
        pages    = { PAGE_DISPLAY },
        buildPage = BuildPage,
    })
end)
