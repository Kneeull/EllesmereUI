-------------------------------------------------------------------------------
--  EllesmereUIMythicTimer.lua
--  Mythic+ Dungeon Timer — data provider for the EllesmereUI Quest Tracker.
--  Tracks M+ run state (timer, objectives, deaths, affixes) and exposes
--  _EMT_GetMythicPlusSection() for the quest tracker to render inline.
--  Also hides the default Blizzard M+ objective tracker.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local EMT = EllesmereUI.Lite.NewAddon(ADDON_NAME)
ns.EMT = EMT

-------------------------------------------------------------------------------
--  Lua / WoW API upvalues
-------------------------------------------------------------------------------
local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local format = string.format
local GetTime = GetTime
local GetWorldElapsedTime = GetWorldElapsedTime
local wipe = wipe

-------------------------------------------------------------------------------
--  Constants
-------------------------------------------------------------------------------
local PLUS_TWO_RATIO   = 0.8
local PLUS_THREE_RATIO = 0.6

-------------------------------------------------------------------------------
--  Database defaults
-------------------------------------------------------------------------------
local DB_DEFAULTS = {
    profile = {
        enabled        = true,
        showAffixes    = true,
        showPlusTwo    = true,
        showPlusThree  = true,
        showDeaths     = true,
        showObjectives = true,
        showEnemyBar   = true,
        objectiveAlign = "LEFT",
        timerAlign     = "CENTER",
        detached       = false,     -- true = standalone frame, false = inside QT
    },
}

-------------------------------------------------------------------------------
--  State
-------------------------------------------------------------------------------
local db                 -- AceDB-like table (set on init)
local updateTicker       -- C_Timer ticker (1 Hz)

-- Current run data
local currentRun = {
    active        = false,
    mapID         = nil,
    mapName       = "",
    level         = 0,
    affixes       = {},
    maxTime       = 0,
    elapsed       = 0,
    completed     = false,
    deaths        = 0,
    deathTimeLost = 0,
    objectives    = {},
}

-------------------------------------------------------------------------------
--  Time formatting
-------------------------------------------------------------------------------
local function FormatTime(seconds)
    if not seconds or seconds < 0 then seconds = 0 end
    local m = floor(seconds / 60)
    local s = floor(seconds % 60)
    return format("%d:%02d", m, s)
end

-------------------------------------------------------------------------------
--  Objective tracking
-------------------------------------------------------------------------------
local function UpdateObjectives()
    local numCriteria = select(3, C_Scenario.GetStepInfo()) or 0
    local elapsed = currentRun.elapsed

    for i = 1, numCriteria do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info then
            local obj = currentRun.objectives[i]
            if not obj then
                obj = {
                    name          = "",
                    completed     = false,
                    elapsed       = 0,
                    quantity      = 0,
                    totalQuantity = 0,
                    isWeighted    = false,
                }
                currentRun.objectives[i] = obj
            end

            obj.name = info.description or ("Objective " .. i)
            local wasCompleted = obj.completed
            obj.completed = info.completed

            if obj.completed and not wasCompleted then
                obj.elapsed = elapsed
            end

            obj.quantity = info.quantity or 0
            obj.totalQuantity = info.totalQuantity or 0
            if info.isWeightedProgress then
                obj.isWeighted = true
                -- Match the reference addon logic: use the displayed weighted
                -- progress value when available, then normalize it against the
                -- criterion total. If totalQuantity is 100, this preserves a
                -- percent value directly; if totalQuantity is a raw enemy-force
                -- cap, this converts raw count -> percent with 2dp precision.
                local rawQuantity = info.quantity or 0
                local quantityString = info.quantityString
                if quantityString and quantityString ~= "" then
                    local normalized = quantityString:gsub("%%", "")
                    if normalized:find(",") and not normalized:find("%.") then
                        normalized = normalized:gsub(",", ".")
                    end
                    local parsed = tonumber(normalized)
                    if parsed then
                        rawQuantity = parsed
                    end
                end

                if obj.totalQuantity and obj.totalQuantity > 0 then
                    local percent = (rawQuantity / obj.totalQuantity) * 100
                    local mult = 10 ^ 2
                    obj.quantity = math.floor(percent * mult + 0.5) / mult
                else
                    obj.quantity = rawQuantity
                end

                if obj.completed then
                    obj.quantity = 100
                    obj.totalQuantity = 100
                end
            else
                obj.isWeighted = false
                -- Ensure bosses (single-count) still report 0/1 or 1/1
                if obj.totalQuantity == 0 then
                    obj.quantity = obj.completed and 1 or 0
                    obj.totalQuantity = 1
                end
            end
        end
    end

    for i = numCriteria + 1, #currentRun.objectives do
        currentRun.objectives[i] = nil
    end
end

-------------------------------------------------------------------------------
--  Notify quest tracker to refresh (coalesced)
-------------------------------------------------------------------------------
local _qtRefreshTimer
local function NotifyQuestTracker()
    if _qtRefreshTimer then return end  -- already pending
    _qtRefreshTimer = C_Timer.After(0.05, function()
        _qtRefreshTimer = nil
        if _G._EMT_QTRefresh then _G._EMT_QTRefresh() end
        if _G._EBS_UpdateQTVisibility then _G._EBS_UpdateQTVisibility() end
        if _G._EMT_StandaloneRefresh then _G._EMT_StandaloneRefresh() end
    end)
end

-------------------------------------------------------------------------------
--  Timer tick (1 Hz while a key is active)
-------------------------------------------------------------------------------
local function OnTimerTick()
    if not currentRun.active then return end

    local _, elapsedTime = GetWorldElapsedTime(1)
    currentRun.elapsed = elapsedTime or 0

    local deathCount, timeLost = C_ChallengeMode.GetDeathCount()
    currentRun.deaths = deathCount or 0
    currentRun.deathTimeLost = timeLost or 0

    UpdateObjectives()
    NotifyQuestTracker()
end

-------------------------------------------------------------------------------
--  Suppress / unsuppress Blizzard M+ frames
-------------------------------------------------------------------------------
local _blizzHiddenParent
local _blizzOrigScenarioParent
local _blizzOrigObjectiveParent

local function SuppressBlizzardMPlus()
    if not db or not db.profile.enabled then return end

    if not _blizzHiddenParent then
        _blizzHiddenParent = CreateFrame("Frame")
        _blizzHiddenParent:Hide()
    end

    -- ScenarioBlocksFrame is the container for Blizzard's M+ timer
    local sbf = _G.ScenarioBlocksFrame
    if sbf and sbf:GetParent() ~= _blizzHiddenParent then
        _blizzOrigScenarioParent = sbf:GetParent()
        sbf:SetParent(_blizzHiddenParent)
    end

    local ot = _G.ObjectiveTrackerFrame
    if ot and ot:GetParent() ~= _blizzHiddenParent then
        _blizzOrigObjectiveParent = ot:GetParent()
        ot:SetParent(_blizzHiddenParent)
    end

    -- Let the quest tracker handle ObjectiveTrackerFrame suppression; just
    -- tell it to re-evaluate (it now knows to suppress during M+ too).
    if _G._EQT_ApplyBlizzardTrackerVisibility then
        _G._EQT_ApplyBlizzardTrackerVisibility()
    end
end

local function UnsuppressBlizzardMPlus()
    local sbf = _G.ScenarioBlocksFrame
    if sbf and _blizzOrigScenarioParent and sbf:GetParent() == _blizzHiddenParent then
        sbf:SetParent(_blizzOrigScenarioParent)
    end

    local ot = _G.ObjectiveTrackerFrame
    if ot and _blizzOrigObjectiveParent and ot:GetParent() == _blizzHiddenParent then
        ot:SetParent(_blizzOrigObjectiveParent)
    end

    if _G._EQT_ApplyBlizzardTrackerVisibility then
        _G._EQT_ApplyBlizzardTrackerVisibility()
    end
end

-------------------------------------------------------------------------------
--  Run lifecycle
-------------------------------------------------------------------------------
local function StartRun()
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if not mapID then return end

    local mapName, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
    local level, affixes = C_ChallengeMode.GetActiveKeystoneInfo()

    currentRun.active        = true
    currentRun.completed     = false
    currentRun.mapID         = mapID
    currentRun.mapName       = mapName or "Unknown"
    currentRun.level         = level or 0
    currentRun.maxTime       = timeLimit or 0
    currentRun.elapsed       = 0
    currentRun.deaths        = 0
    currentRun.deathTimeLost = 0
    currentRun.affixes       = affixes or {}
    wipe(currentRun.objectives)

    if updateTicker then updateTicker:Cancel() end
    updateTicker = C_Timer.NewTicker(1, OnTimerTick)
    OnTimerTick()

    SuppressBlizzardMPlus()
    NotifyQuestTracker()
end

local function CompleteRun()
    currentRun.completed = true
    currentRun.active = false

    if updateTicker then updateTicker:Cancel(); updateTicker = nil end

    local _, elapsedTime = GetWorldElapsedTime(1)
    currentRun.elapsed = elapsedTime or currentRun.elapsed
    UpdateObjectives()
    NotifyQuestTracker()
end

local function ResetRun()
    currentRun.active    = false
    currentRun.completed = false
    currentRun.mapID     = nil
    currentRun.mapName   = ""
    currentRun.level     = 0
    currentRun.maxTime   = 0
    currentRun.elapsed   = 0
    currentRun.deaths    = 0
    currentRun.deathTimeLost = 0
    wipe(currentRun.affixes)
    wipe(currentRun.objectives)

    if updateTicker then updateTicker:Cancel(); updateTicker = nil end

    UnsuppressBlizzardMPlus()
    NotifyQuestTracker()
end

local function CheckForActiveRun()
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if mapID then StartRun() end
end

-------------------------------------------------------------------------------
--  GetMythicPlusSection() — public API for the quest tracker
-------------------------------------------------------------------------------

-- Returns true if M+ data provider is active (regardless of detach mode).
-- Used by IsInHiddenInstance() in the quest tracker.
function _G._EMT_IsMythicPlusActive()
    if not db or not db.profile.enabled then return false end
    return currentRun.active or currentRun.completed
end

function _G._EMT_ShouldHideQuestTracker()
    if not db or not db.profile.enabled or not db.profile.detached then return false end
    return currentRun.active or currentRun.completed
end

function _G._EMT_GetMythicPlusSection()
    if not db or not db.profile.enabled then return nil end
    if db.profile.detached then return nil end  -- standalone frame handles rendering
    local run = currentRun
    if not run.active and not run.completed then return nil end

    local p = db.profile
    local section = {
        isMythicPlus   = true,
        title          = run.mapName or "Mythic+",
        level          = run.level or 0,
        maxTime        = run.maxTime or 0,
        elapsed        = run.elapsed or 0,
        completed      = run.completed or false,
        deaths         = run.deaths or 0,
        deathTimeLost  = run.deathTimeLost or 0,
        affixes        = {},
        objectives     = {},
        -- Config flags
        showAffixes    = p.showAffixes,
        showPlusTwo    = p.showPlusTwo,
        showPlusThree  = p.showPlusThree,
        showDeaths     = p.showDeaths,
        showObjectives = p.showObjectives,
        showEnemyBar   = p.showEnemyBar,
        objectiveAlign = p.objectiveAlign or "LEFT",
        timerAlign     = p.timerAlign or "CENTER",
        detached       = p.detached or false,
    }

    -- Affix names
    if run.affixes then
        for _, id in ipairs(run.affixes) do
            local name = C_ChallengeMode.GetAffixInfo(id)
            if name then
                section.affixes[#section.affixes + 1] = { id = id, name = name }
            end
        end
    end

    -- Objectives
    for i, obj in ipairs(run.objectives) do
        section.objectives[i] = {
            name          = obj.name,
            completed     = obj.completed,
            elapsed       = obj.elapsed,
            quantity      = obj.quantity,
            totalQuantity = obj.totalQuantity,
            isWeighted    = obj.isWeighted,
        }
    end

    -- Computed thresholds
    section.plusTwoTime   = run.maxTime * PLUS_TWO_RATIO
    section.plusThreeTime = run.maxTime * PLUS_THREE_RATIO
    section.timeLeft      = max(0, run.maxTime - run.elapsed)

    return section
end

-- Expose apply for options panel
_G._EMT_Apply = function()
    NotifyQuestTracker()
    if _G._EMT_StandaloneRefresh then _G._EMT_StandaloneRefresh() end
end

-------------------------------------------------------------------------------
--  Standalone frame (used when detached = true)
--  Mirrors the quest-tracker M+ section as its own movable frame.
-------------------------------------------------------------------------------
local standaloneFrame       -- main container
local standaloneCreated = false

-- Font/color helpers (mirrors QT approach but self-contained)
local FALLBACK_FONT = "Fonts/FRIZQT__.TTF"
local function SFont()
    if EllesmereUI and EllesmereUI.GetFontPath then
        local p = EllesmereUI.GetFontPath("unitFrames")
        if p and p ~= "" then return p end
    end
    return FALLBACK_FONT
end
local function SOutline()
    if EllesmereUI.GetFontOutlineFlag then return EllesmereUI.GetFontOutlineFlag() end
    return ""
end
local function SetFS(fs, size, flags)
    if not fs then return end
    local p = SFont()
    flags = flags or SOutline()
    fs:SetFont(p, size, flags)
    if not fs:GetFont() then fs:SetFont(FALLBACK_FONT, size, flags) end
end
local function ApplyShadow(fs)
    if not fs then return end
    if EllesmereUI.GetFontUseShadow and EllesmereUI.GetFontUseShadow() then
        fs:SetShadowColor(0, 0, 0, 0.8); fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

local function GetAccentColor()
    if EllesmereUI.ResolveThemeColor then
        local theme = EllesmereUIDB and EllesmereUIDB.accentTheme or "Class Colored"
        return EllesmereUI.ResolveThemeColor(theme)
    end
    return 0.05, 0.83, 0.62
end

-- Pool of objective row fontstrings
local objRows = {}
local function GetObjRow(parent, idx)
    if objRows[idx] then return objRows[idx] end
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetWordWrap(false)
    objRows[idx] = fs
    return fs
end

local function CreateStandaloneFrame()
    if standaloneCreated then return standaloneFrame end
    standaloneCreated = true

    local FRAME_W = 260
    local PAD = 8

    local f = CreateFrame("Frame", "EllesmereUIMythicTimerStandalone", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, 200)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(10)
    f:SetClampedToScreen(true)

    -- Background
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.05, 0.04, 0.08, 0.85)
    f:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.6)

    -- Accent stripe (right edge)
    f._accent = f:CreateTexture(nil, "BORDER")
    f._accent:SetWidth(2)
    f._accent:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    f._accent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

    -- Banner title
    f._titleFS = f:CreateFontString(nil, "OVERLAY")
    f._titleFS:SetWordWrap(false)
    f._titleFS:SetJustifyV("MIDDLE")

    -- Affixes
    f._affixFS = f:CreateFontString(nil, "OVERLAY")
    f._affixFS:SetWordWrap(false)

    -- Timer
    f._timerFS = f:CreateFontString(nil, "OVERLAY")
    f._timerFS:SetJustifyH("CENTER")

    -- Timer bar bg
    f._barBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f._barFill = f:CreateTexture(nil, "ARTWORK")
    f._seg3 = f:CreateTexture(nil, "OVERLAY")
    f._seg2 = f:CreateTexture(nil, "OVERLAY")

    -- Threshold text
    f._threshFS = f:CreateFontString(nil, "OVERLAY")
    f._threshFS:SetWordWrap(false)

    -- Deaths
    f._deathFS = f:CreateFontString(nil, "OVERLAY")
    f._deathFS:SetWordWrap(false)

    -- Enemy forces label
    f._enemyFS = f:CreateFontString(nil, "OVERLAY")
    f._enemyFS:SetWordWrap(false)

    -- Enemy bar
    f._enemyBarBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f._enemyBarFill = f:CreateTexture(nil, "ARTWORK")

    -- The frame can be created by unlock-mode registration before it has any
    -- content to render. Keep it hidden until RenderStandalone() explicitly
    -- shows it for detached active runs.
    f:Hide()

    standaloneFrame = f
    return f
end

local function RenderStandalone()
    if not db or not db.profile.enabled or not db.profile.detached then
        if standaloneFrame then standaloneFrame:Hide() end
        return
    end

    local run = currentRun
    if not run.active and not run.completed then
        if standaloneFrame then standaloneFrame:Hide() end
        return
    end

    local f = CreateStandaloneFrame()
    local p = db.profile
    local PAD = 8
    local TBAR_PAD = 10
    local TBAR_H = 10

    local aR, aG, aB = GetAccentColor()
    f._accent:SetColorTexture(aR, aG, aB, 0.9)

    local frameW = f:GetWidth()
    local innerW = frameW - PAD * 2
    local y = -PAD

    -- Title: "+15 Mists of Tirna Scithe"
    SetFS(f._titleFS, 13)
    ApplyShadow(f._titleFS)
    f._titleFS:SetTextColor(1, 1, 1)
    f._titleFS:SetText(format("+%d  %s", run.level, run.mapName or "Mythic+"))
    f._titleFS:ClearAllPoints()
    f._titleFS:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    f._titleFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
    f._titleFS:SetHeight(20)
    f._titleFS:SetJustifyH("CENTER")
    f._titleFS:Show()
    y = y - 22

    -- Affixes
    if p.showAffixes and #run.affixes > 0 then
        local names = {}
        for _, id in ipairs(run.affixes) do
            local name = C_ChallengeMode.GetAffixInfo(id)
            if name then names[#names + 1] = name end
        end
        SetFS(f._affixFS, 10)
        ApplyShadow(f._affixFS)
        f._affixFS:SetTextColor(0.55, 0.55, 0.55)
        f._affixFS:SetText(table.concat(names, "  \194\183  "))
        f._affixFS:ClearAllPoints()
        f._affixFS:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
        f._affixFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
        f._affixFS:SetJustifyH("CENTER")
        f._affixFS:Show()
        y = y - (f._affixFS:GetStringHeight() or 12) - 4
    else
        f._affixFS:Hide()
    end

    -- Timer
    local elapsed = run.elapsed or 0
    local maxTime = run.maxTime or 0
    local timeLeft = max(0, maxTime - elapsed)
    local plusThreeT = maxTime * PLUS_THREE_RATIO
    local plusTwoT   = maxTime * PLUS_TWO_RATIO

    local timerText
    if run.completed then
        timerText = FormatTime(elapsed)
    else
        timerText = FormatTime(timeLeft)
    end

    local tR, tG, tB
    if run.completed then
        if elapsed <= plusThreeT then      tR, tG, tB = 0.3, 0.8, 1
        elseif elapsed <= plusTwoT then    tR, tG, tB = 0.4, 1, 0.4
        elseif elapsed <= maxTime then     tR, tG, tB = 0.9, 0.7, 0.2
        else                               tR, tG, tB = 0.9, 0.2, 0.2 end
    elseif timeLeft <= 0 then              tR, tG, tB = 0.9, 0.2, 0.2
    elseif timeLeft < maxTime * 0.2 then   tR, tG, tB = 0.9, 0.7, 0.2
    else                                   tR, tG, tB = 1, 1, 1 end

    SetFS(f._timerFS, 20)
    ApplyShadow(f._timerFS)
    f._timerFS:SetTextColor(tR, tG, tB)
    f._timerFS:SetText(timerText)
    local timerAlign = p.timerAlign or "CENTER"
    f._timerFS:SetJustifyH(timerAlign)
    f._timerFS:ClearAllPoints()
    local timerBlockW = min(innerW, max(140, floor(innerW * 0.72)))
    if timerAlign == "RIGHT" then
        f._timerFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
    elseif timerAlign == "LEFT" then
        f._timerFS:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
    else
        f._timerFS:SetPoint("TOP", f, "TOP", 0, y)
    end
    f._timerFS:SetWidth(timerBlockW)
    f._timerFS:Show()
    local timerH = f._timerFS:GetStringHeight() or 20
    if timerH < 20 then timerH = 20 end
    y = y - timerH - 4

    -- Timer bar
    if maxTime > 0 then
        local barW = innerW - TBAR_PAD * 2

        f._barBg:ClearAllPoints()
        f._barBg:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + TBAR_PAD, y)
        f._barBg:SetSize(barW, TBAR_H)
        f._barBg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
        f._barBg:Show()

        local fillPct = math.min(1, elapsed / maxTime)
        local fillW = math.max(1, barW * fillPct)
        f._barFill:ClearAllPoints()
        f._barFill:SetPoint("TOPLEFT", f._barBg, "TOPLEFT", 0, 0)
        f._barFill:SetSize(fillW, TBAR_H)
        f._barFill:SetColorTexture(tR, tG, tB, 0.85)
        f._barFill:Show()

        -- +3 marker (60%)
        f._seg3:ClearAllPoints()
        f._seg3:SetSize(1, TBAR_H + 4)
        f._seg3:SetPoint("TOP", f._barBg, "TOPLEFT", floor(barW * 0.6), 2)
        f._seg3:SetColorTexture(0.3, 0.8, 1, 0.9)
        if p.showPlusThree then f._seg3:Show() else f._seg3:Hide() end

        -- +2 marker (80%)
        f._seg2:ClearAllPoints()
        f._seg2:SetSize(1, TBAR_H + 4)
        f._seg2:SetPoint("TOP", f._barBg, "TOPLEFT", floor(barW * 0.8), 2)
        f._seg2:SetColorTexture(0.4, 1, 0.4, 0.9)
        if p.showPlusTwo then f._seg2:Show() else f._seg2:Hide() end

        y = y - TBAR_H - 8
    else
        f._barBg:Hide(); f._barFill:Hide()
        f._seg3:Hide(); f._seg2:Hide()
    end

    -- +2 / +3 threshold text
    if (p.showPlusTwo or p.showPlusThree) and maxTime > 0 then
        local parts = {}
        if p.showPlusTwo then
            local diff = plusTwoT - elapsed
            if diff >= 0 then
                parts[#parts + 1] = format("|cff66ff66+2  %s|r", FormatTime(diff))
            else
                parts[#parts + 1] = format("|cff666666+2  -%s|r", FormatTime(abs(diff)))
            end
        end
        if p.showPlusThree then
            local diff = plusThreeT - elapsed
            if diff >= 0 then
                parts[#parts + 1] = format("|cff4dccff+3  %s|r", FormatTime(diff))
            else
                parts[#parts + 1] = format("|cff666666+3  -%s|r", FormatTime(abs(diff)))
            end
        end
        if #parts > 0 then
            SetFS(f._threshFS, 10)
            ApplyShadow(f._threshFS)
            f._threshFS:SetTextColor(1, 1, 1)
            f._threshFS:SetText(table.concat(parts, "      "))
            f._threshFS:SetJustifyH("CENTER")
            f._threshFS:ClearAllPoints()
            f._threshFS:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
            f._threshFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
            f._threshFS:Show()
            y = y - (f._threshFS:GetStringHeight() or 12) - 6
        else
            f._threshFS:Hide()
        end
    else
        f._threshFS:Hide()
    end

    -- Deaths
    if p.showDeaths and run.deaths > 0 then
        SetFS(f._deathFS, 10)
        ApplyShadow(f._deathFS)
        f._deathFS:SetText(format("|cffee5555%d Death%s  -%s|r",
            run.deaths, run.deaths ~= 1 and "s" or "", FormatTime(run.deathTimeLost)))
        f._deathFS:ClearAllPoints()
        f._deathFS:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
        f._deathFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
        f._deathFS:SetJustifyH("LEFT")
        f._deathFS:Show()
        y = y - (f._deathFS:GetStringHeight() or 12) - 4
    else
        f._deathFS:Hide()
    end

    -- Objectives
    local objIdx = 0
    if p.showObjectives then
        local objAlign = p.objectiveAlign or "LEFT"
        for i, obj in ipairs(run.objectives) do
            if not obj.isWeighted then
                objIdx = objIdx + 1
                local row = GetObjRow(f, objIdx)
                SetFS(row, 10)
                ApplyShadow(row)

                local displayName = obj.name or ("Objective " .. i)
                if obj.totalQuantity and obj.totalQuantity > 1 then
                    displayName = format("%d/%d %s", obj.quantity or 0, obj.totalQuantity, displayName)
                end
                if obj.completed then
                    displayName = "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t " .. displayName
                    row:SetTextColor(0.3, 0.8, 0.3)
                else
                    row:SetTextColor(0.9, 0.9, 0.9)
                end
                local timeStr = ""
                if obj.completed and obj.elapsed and obj.elapsed > 0 then
                    timeStr = "  |cff888888" .. FormatTime(obj.elapsed) .. "|r"
                end
                row:SetText(displayName .. timeStr)
                row:SetJustifyH(objAlign)
                row:ClearAllPoints()
                local objBlockW = min(innerW, max(160, floor(innerW * 0.8)))
                if objAlign == "RIGHT" then
                    row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
                elseif objAlign == "CENTER" then
                    row:SetPoint("TOP", f, "TOP", 0, y)
                else
                    row:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
                end
                row:SetWidth(objBlockW)
                row:Show()
                y = y - (row:GetStringHeight() or 12) - 2
            end
        end
    end

    -- Hide unused objective rows
    for i = objIdx + 1, #objRows do
        objRows[i]:Hide()
    end

    -- Enemy forces
    if p.showEnemyBar then
        local enemyObj = nil
        for _, obj in ipairs(run.objectives) do
            if obj.isWeighted then enemyObj = obj; break end
        end
        if enemyObj then
            local pctRaw = min(100, max(0, enemyObj.quantity))
            local label = format("Enemy Forces %.2f%%", pctRaw)

            SetFS(f._enemyFS, 10)
            ApplyShadow(f._enemyFS)
            if enemyObj.completed then
                f._enemyFS:SetTextColor(0.3, 0.8, 0.3)
            else
                f._enemyFS:SetTextColor(0.9, 0.9, 0.9)
            end
            f._enemyFS:SetText(label)
            f._enemyFS:ClearAllPoints()
            f._enemyFS:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
            f._enemyFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
            f._enemyFS:SetJustifyH("LEFT")
            f._enemyFS:Show()
            y = y - (f._enemyFS:GetStringHeight() or 12) - 4

            -- Progress bar
            if not enemyObj.completed then
                local barW = innerW - TBAR_PAD * 2
                f._enemyBarBg:ClearAllPoints()
                f._enemyBarBg:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + TBAR_PAD, y)
                f._enemyBarBg:SetSize(barW, 6)
                f._enemyBarBg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
                f._enemyBarBg:Show()

                local epct = min(1, max(0, pctRaw / 100))
                local eFillW = max(1, barW * epct)
                f._enemyBarFill:ClearAllPoints()
                f._enemyBarFill:SetPoint("TOPLEFT", f._enemyBarBg, "TOPLEFT", 0, 0)
                f._enemyBarFill:SetSize(eFillW, 6)
                f._enemyBarFill:SetColorTexture(aR, aG, aB, 0.8)
                f._enemyBarFill:Show()
                y = y - 10
            else
                f._enemyBarBg:Hide()
                f._enemyBarFill:Hide()
            end
        else
            f._enemyFS:Hide()
            f._enemyBarBg:Hide()
            f._enemyBarFill:Hide()
        end
    else
        f._enemyFS:Hide()
        f._enemyBarBg:Hide()
        f._enemyBarFill:Hide()
    end

    -- Resize frame to content
    local totalH = abs(y) + PAD
    f:SetHeight(totalH)
    f:Show()
end

-- Global refresh callback for standalone frame
_G._EMT_StandaloneRefresh = RenderStandalone

-- Expose standalone frame getter for unlock mode
_G._EMT_GetStandaloneFrame = function()
    return CreateStandaloneFrame()
end

local function ApplyStandalonePosition()
    if not db or not db.profile.detached then return end
    if not standaloneFrame then return end
    local pos = db.profile.standalonePos
    if pos then
        standaloneFrame:ClearAllPoints()
        standaloneFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
end

local function ArePrimaryObjectivesComplete()
    local numCriteria = select(3, C_Scenario.GetStepInfo()) or 0
    if numCriteria == 0 then return false end

    local seenPrimary = false
    for i = 1, numCriteria do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info and not info.isWeightedProgress then
            seenPrimary = true
            if not info.completed then
                return false
            end
        end
    end

    return seenPrimary
end

local runtimeFrame = CreateFrame("Frame")
local runtimePollElapsed = 0
local runtimeInitElapsed = 0
local runtimeInitialized = false

local function RuntimeOnUpdate(_, elapsed)
    if not db then return end

    if not runtimeInitialized then
        runtimeInitElapsed = runtimeInitElapsed + elapsed
        if runtimeInitElapsed >= 1 then
            runtimeInitialized = true
            CheckForActiveRun()
            ApplyStandalonePosition()
        end
    end

    runtimePollElapsed = runtimePollElapsed + elapsed
    if runtimePollElapsed < 0.25 then return end
    runtimePollElapsed = 0

    if not db.profile.enabled then
        if currentRun.active or currentRun.completed then
            ResetRun()
        end
        return
    end

    local activeMapID = C_ChallengeMode.GetActiveChallengeMapID()
    if activeMapID then
        if not currentRun.active and not currentRun.completed then
            StartRun()
        elseif currentRun.active and ArePrimaryObjectivesComplete() then
            CompleteRun()
        end
    elseif currentRun.active or currentRun.completed then
        ResetRun()
    end
end

function EMT:OnInitialize()
    db = EllesmereUI.Lite.NewDB("EllesmereUIMythicTimerDB", DB_DEFAULTS)
    _G._EMT_AceDB = db

    if db and db.profile and db.profile.objectiveAlign == nil then
        local oldAlign = db.profile.thresholdAlign
        if oldAlign == "RIGHT" then
            db.profile.objectiveAlign = "RIGHT"
        elseif oldAlign == "CENTER" then
            db.profile.objectiveAlign = "CENTER"
        else
            db.profile.objectiveAlign = "LEFT"
        end
    end

    if db and db.profile and db.profile.timerAlign == nil then
        db.profile.timerAlign = "CENTER"
    end

    runtimeFrame:SetScript("OnUpdate", RuntimeOnUpdate)
end

function EMT:OnEnable()
    if not db or not db.profile.enabled then return end

    -- Register with unlock mode
    if EllesmereUI and EllesmereUI.RegisterUnlockElements and EllesmereUI.MakeUnlockElement then
        local MK = EllesmereUI.MakeUnlockElement
        EllesmereUI:RegisterUnlockElements({
            MK({
                key   = "EMT_MythicTimer",
                label = "Mythic+ Timer",
                group = "Mythic+",
                order = 520,
                noResize = true,
                getFrame = function()
                    return _G._EMT_GetStandaloneFrame and _G._EMT_GetStandaloneFrame()
                end,
                getSize  = function()
                    local f = standaloneFrame
                    if f then return f:GetWidth(), f:GetHeight() end
                    return 260, 200
                end,
                isHidden = function()
                    return not db.profile.detached
                end,
                savePos = function(_, point, relPoint, x, y)
                    db.profile.standalonePos = { point = point, relPoint = relPoint, x = x, y = y }
                    if standaloneFrame and not EllesmereUI._unlockActive then
                        standaloneFrame:ClearAllPoints()
                        standaloneFrame:SetPoint(point, UIParent, relPoint, x, y)
                    end
                end,
                loadPos = function()
                    return db.profile.standalonePos
                end,
                clearPos = function()
                    db.profile.standalonePos = nil
                end,
                applyPos = function()
                    local pos = db.profile.standalonePos
                    if pos and standaloneFrame then
                        standaloneFrame:ClearAllPoints()
                        standaloneFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
                    end
                end,
            }),
        })
    end
end

-------------------------------------------------------------------------------
--  Slash commands
-------------------------------------------------------------------------------
SLASH_EMTIMER1 = "/mpt"
SLASH_EMTIMER2 = "/mythictimer"
SlashCmdList.EMTIMER = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "test" then
        if not db then return end
        currentRun.active        = true
        currentRun.completed     = false
        currentRun.mapID         = 375
        currentRun.mapName       = "Mists of Tirna Scithe"
        currentRun.level         = 15
        currentRun.maxTime       = 1800
        currentRun.elapsed       = 720
        currentRun.deaths        = 2
        currentRun.deathTimeLost = 10
        currentRun.affixes       = { 9, 7, 124 }
        wipe(currentRun.objectives)
        currentRun.objectives = {
            { name = "Ingra Maloch",       completed = true,  elapsed = 245, quantity = 1,   totalQuantity = 1,   isWeighted = false },
            { name = "Mistcaller",         completed = true,  elapsed = 512, quantity = 1,   totalQuantity = 1,   isWeighted = false },
            { name = "Quarry camps liberated", completed = false, elapsed = 0, quantity = 3, totalQuantity = 6,   isWeighted = false },
            { name = "Tred'ova",           completed = false, elapsed = 0,   quantity = 0,   totalQuantity = 1,   isWeighted = false },
            { name = "Enemy Forces",       completed = false, elapsed = 0,   quantity = 11,  totalQuantity = 100, isWeighted = true  },
        }
        if updateTicker then updateTicker:Cancel() end
        updateTicker = C_Timer.NewTicker(1, OnTimerTick)
        OnTimerTick()
        SuppressBlizzardMPlus()
        NotifyQuestTracker()
        RenderStandalone()
        print("|cff0cd29fEllesmereUI|r Mythic+ Timer: test mode active. Use /mpt reset to clear.")
    elseif msg == "reset" then
        ResetRun()
        print("|cff0cd29fEllesmereUI|r Mythic+ Timer: reset.")
    else
        print("|cff0cd29fEllesmereUI|r Mythic+ Timer:")
        print("  /mpt test  — Simulate an M+ run in the quest tracker")
        print("  /mpt reset — Clear the simulated run")
    end
end
