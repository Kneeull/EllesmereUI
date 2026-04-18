-- EllesmereUIWonderBar.lua — modular bar; each module registers via :RegisterModule(key, tbl).
-- Module contract: key, events?, OnCreate?, OnRefresh?, OnEnable?, OnDisable?, OnEvent?, GetContentWidth?
-- Layout: slotPos 0 = centre pivot (Clock default). Others sort ascending. Public WB: helpers for back-compat.
local ADDON_NAME, ns = ...

local WB = EllesmereUI.Lite.NewAddon("EllesmereUIWonderBar")
ns.WB = WB

-- Strings (inlined; English only — no localization).
local L = {
    -- Generic click hints
    LEFT_CLICK         = "|cffFFFFFFLeft Click:|r",
    RIGHT_CLICK        = "|cffFFFFFFRight Click:|r",
    SHIFT_MIDDLE_CLICK = "|cffFFFFFFShift + Middle Click:|r",
    CTRL_RIGHT_CLICK   = "|cffFFFFFFCtrl + Right Click:|r",
    -- Clock
    YOU_HAVE_MAIL      = "You've Got Mail!",
    SERVER_TIME        = "Server time",
    SAVED_INSTANCES    = "Saved Raid(s)",
    DAILY_RESET        = "Daily reset",
    WEEKLY_RESET       = "Weekly reset",
    TOGGLE_CALENDAR    = "Toggle Calendar",
    TOGGLE_CLOCK       = "Toggle Clock",
    RELOAD_UI          = "Reload UI",
    -- System
    FPS                = "FPS",
    HOME               = "Home",
    WORLD              = "World",
    MEMORY_USAGE       = "Memory Usage",
    -- Gold
    GOLD               = "Gold",
    SESSION            = "Session",
    EARNED             = "Earned",
    SPENT              = "Spent",
    PROFIT             = "Profit",
    DEFICIT            = "Deficit",
    WARBANK            = "Warbank",
    TOTAL              = "Total",
    WOW_TOKEN          = "WoW Token",
    OPEN_BAGS          = "Open Bags",
    OPEN_CURRENCIES    = "Open Currencies",
    RESET_SESSION      = "Reset Session",
    GOLD_SUFFIX        = "g",
    SILVER_SUFFIX      = "s",
    COPPER_SUFFIX      = "c",
    -- Travel
    TRAVEL_COOLDOWNS   = "Travel Cooldowns",
    HEARTHSTONE        = "Hearthstone",
    READY              = "Ready",
    MYTHIC_TELEPORTS   = "Mythic+ Teleports",
    USE_HEARTHSTONE    = "Use Hearthstone",
    -- SpecSwitch
    CURRENT_SPEC       = "Current Specialization",
    CHANGE_SPEC        = "Change Specialization",
    CHANGE_LOOT_SPEC   = "Change Loot Spec",
    CHANGE_LOADOUT     = "Change Loadout",
    -- Profession
    OPEN_PROFESSION      = "Open Profession",
    OPEN_PROFESSION_BOOK = "Open Profession Book",
    -- MicroMenu tooltips
    ACH_POINTS      = "Achievement Points",
    DELVE_JOURNEY   = "Delver's Journey",
    COMPANION_LEVEL = "Companion Level",
    -- Options panel
    OPT_BAR                 = "BAR",
    OPT_BAR_ENABLE          = "Enable WonderBar",
    OPT_BAR_POSITION        = "Position",
    OPT_BAR_POSITION_BOTTOM = "Bottom",
    OPT_BAR_POSITION_TOP    = "Top",
    OPT_BAR_POSITION_LEFT   = "Left",
    OPT_BAR_POSITION_RIGHT  = "Right",
    OPT_BAR_HEIGHT          = "Bar Height",
    OPT_BAR_VISIBILITY      = "Visibility",
    OPT_BAR_COLOUR          = "Bar Colour",
    OPT_VIS_ALWAYS          = "Always",
    OPT_VIS_MOUSEOVER       = "Mouseover",
    OPT_MICROMENU           = "MICROMENU",
    OPT_MM_ENABLE           = "Enable MicroMenu",
    OPT_MM_HIDE_BLIZZARD    = "Hide Blizzard MicroMenu",
    OPT_MM_COMBAT           = "Enable in Combat",
    OPT_CLOCK               = "CLOCK",
    OPT_CLOCK_ENABLE        = "Enable Clock",
    OPT_CLOCK_DATE          = "Show Date",
    OPT_MODULES             = "MODULES",
    OPT_MOD_SYSTEM          = "System (FPS/Latency)",
    OPT_MOD_GOLD            = "Gold",
    OPT_MOD_TRAVEL          = "Travel",
    OPT_MOD_PROFESSION      = "Profession",
    OPT_MOD_SPECSWITCH      = "Specialization",
    OPT_MOD_DATABAR         = "DataBar (XP/Rep)",
    OPT_MOD_CLOCK           = "Clock",
    OPT_MOD_MICROMENU       = "MicroMenu",
    OPT_ORDER               = "MODULE ORDER",
    OPT_ORDER_CENTRE        = "Centre",
    OPT_ORDER_NONE          = "— none —",
}
ns.L = L

-- Upvalues
local _G                = _G
local CreateFrame       = CreateFrame
local UIParent          = UIParent
local InCombatLockdown  = InCombatLockdown
local C_Timer           = C_Timer
local GetTime           = GetTime
local hooksecurefunc    = hooksecurefunc
local pairs, ipairs     = pairs, ipairs
local type, select      = type, select
local pcall             = pcall
local rawget            = rawget
local wipe              = wipe
local format            = string.format
local tinsert, tremove  = table.insert, table.remove
local tconcat, tsort    = table.concat, table.sort
local floor, ceil       = math.floor, math.ceil
local max, min, abs     = math.max, math.min, math.abs
local mrandom           = math.random

-- Core services
local PP = EllesmereUI.PP


local MEDIA = "Interface\\AddOns\\EllesmereUIWonderBar\\media\\"

-- Defaults (single source of truth; module keys nest under their module name)
local defaults = {
    profile = {
        -- Bar
        bar = {
            enabled        = true,
            position       = "BOTTOM",
            width          = 0,
            height         = 30,
            bgR            = 0.04,
            bgG            = 0.04,
            bgB            = 0.04,
            bgA            = 0.85,
            barColour      = "dark",
            visibility     = "ALWAYS",
            mouseoverDelay = 0.3,
            fontSizeNormal = 14,
            fontSizeLarge  = 32,
            fontSizeSmall  = 16,
            savedPoint     = nil,
            savedRelPoint  = nil,
            savedX         = nil,
            savedY         = nil,
        },
        -- Clock
        clock = {
            enabled       = true,
            slotPos       = 0,     -- 0 = centre pivot (only one module may be 0)
            localTime     = true,
            twentyFour    = true,
            showDate      = true,
            showMail      = true,
            showResting   = true,
            fontSizeClock = nil,
            fontSizeInfo  = nil,
        },
        -- System
        system = {
            enabled         = true,
            slotPos         = 60,
            useWorldLatency = false,
            showIcons       = true,
        },
        -- Gold
        gold = {
            enabled      = true,
            slotPos      = 50,
            showIcons    = true,
            showBagSpace = true,
            showSmall    = true,
            useColors    = true,
        },
        -- Cross-char gold tracking
        characters = {},
        -- DataBar
        databar = {
            enabled = true,
            slotPos = 20,
            mode    = "auto",
            width   = 300,
        },
        -- Travel
        travel = {
            enabled     = true,
            slotPos     = 70,
            randomizeHs = true,
        },
        -- SpecSwitch
        specswitch = {
            enabled      = true,
            slotPos      = 30,
            showLoadout  = true,
            useUppercase = true,
        },
        -- Profession
        profession = {
            enabled = true,
            slotPos = 40,
        },
        -- MicroMenu
        micromenu = {
            enabled                 = true,
            slotPos                 = 10,
            showTooltips            = true,
            showKeybindInTooltip    = true,
            disableBlizzardMicroMenu = false,
            combatEn                = false,
            hideSocialText          = false,
            hideAppContact          = false,
            showGuildMOTD           = false,
            mainMenuSpacing         = 4,
            iconSpacing             = 2,
            osSocialText            = 12,
            menu = true, guild = true, social = true,
            char = true, spell = true, talent = true, ach = true,
            quest = true, lfg = true, pvp = true, housing = true, journal = true,
            pet = true, shop = true, help = true,
        },
    },
}

-- Public helpers (back-compat with Options file and external addons)

-- Font resolution (wrappers over core font API)────
function WB:GetFont(size)
    local path  = EllesmereUI.GetFontPath("wonderBar")
    local flags = EllesmereUI.GetFontOutlineFlag()
    return path, size or 11, flags
end

function WB:SetFont(fs, size)
    if not (fs and fs.SetFont) then return end
    local path, sz, flags = self:GetFont(size)
    fs:SetFont(path, sz, flags)
    if flags == "" then
        if EllesmereUI.GetFontUseShadow() then
            fs:SetShadowOffset(1, -1)
            fs:SetShadowColor(0, 0, 0, 1)
        else
            fs:SetShadowOffset(0, 0)
        end
    else
        fs:SetShadowOffset(0, 0)
    end
end

-- ── Accent colour ─────────────────────────────────────────────────────────
-- Back-compat shim: the core exposes EllesmereUI.GetAccentColor. Keeping this
-- as a WB method so the options file (and any legacy code) still works.
function WB:GetAccent()
    if EllesmereUI and EllesmereUI.GetAccentColor then
        return EllesmereUI.GetAccentColor()
    end
    local theme = EllesmereUI and EllesmereUI.ELLESMERE_GREEN
    if theme then return theme.r, theme.g, theme.b end
    return 0.047, 0.824, 0.616
end

-- Colour gradient (bad → caution → good)
function WB:SlowColorGradient(perc)
    perc = max(0, min(1, perc))
    local function smoothstep(t) return t * t * (3 - 2 * t) end
    if perc < 0.5 then
        local t = smoothstep(perc * 2)
        return 1, t, 0.08 * (1 - t)
    else
        local t = smoothstep((perc - 0.5) * 2)
        return 1, 1, t
    end
end

-- ── Pixel snap ────────────────────────────────────────────────────────────
-- Back-compat shim: snap a measurement to an even whole pixel, min 2.
-- The core's PP.Scale handles positioning/sizing; this helper is for text
-- height measurements where XIV-style rounding is desired.
function WB:SnapToPixelGrid(v)
    local r = floor((v or 0) + 0.5)
    return max(2, r + (r % 2))
end

-- Money formatting──
local DENOMINATIONS = {
    { divisor = 10000, suffix = "GOLD_SUFFIX",   color = "|cffffd700" },
    { divisor = 100,   suffix = "SILVER_SUFFIX", color = "|cffc7c7cf" },
    { divisor = 1,     suffix = "COPPER_SUFFIX", color = "|cffeda55f" },
}

function WB:FormatMoneyPlain(amount, showSmall)
    amount = floor(abs(amount or 0))
    local parts, foundGold = {}, false
    for i, denom in ipairs(DENOMINATIONS) do
        local val = floor(amount / denom.divisor)
        amount = amount % denom.divisor
        if i == 1 and val > 0 then
            foundGold = true
            local display = BreakUpLargeNumbers and BreakUpLargeNumbers(val) or tostring(val)
            parts[#parts + 1] = display .. L[denom.suffix]
        elseif i > 1 and (not foundGold or showSmall ~= false) and (val > 0 or (i == 3 and #parts == 0)) then
            parts[#parts + 1] = val .. L[denom.suffix]
        end
    end
    return #parts > 0 and tconcat(parts, " ") or ("0" .. L["COPPER_SUFFIX"])
end

function WB:FormatMoney(amount, useColors, showSmall)
    amount = floor(abs(amount or 0))
    local coloured = useColors ~= false
    local parts, foundGold = {}, false
    for i, denom in ipairs(DENOMINATIONS) do
        local val = floor(amount / denom.divisor)
        amount = amount % denom.divisor
        if i == 1 and val > 0 then
            foundGold = true
            local display = BreakUpLargeNumbers and BreakUpLargeNumbers(val) or tostring(val)
            local cOpen  = coloured and denom.color or ""
            local cClose = coloured and "|r" or ""
            parts[#parts + 1] = display .. cOpen .. L[denom.suffix] .. cClose
        elseif i > 1 and (not foundGold or showSmall ~= false) and (val > 0 or (i == 3 and #parts == 0)) then
            local cOpen  = coloured and denom.color or ""
            local cClose = coloured and "|r" or ""
            parts[#parts + 1] = val .. cOpen .. L[denom.suffix] .. cClose
        end
    end
    if #parts == 0 then
        local cOpen  = coloured and DENOMINATIONS[3].color or ""
        local cClose = coloured and "|r" or ""
        return "0" .. cOpen .. L["COPPER_SUFFIX"] .. cClose
    end
    return tconcat(parts, " ")
end

-- Time / cooldown formatting
local TIME_UNITS = { {86400, "d"}, {3600, "h"}, {60, "min"} }
function WB:FormatTimeLeft(seconds)
    seconds = floor(seconds or 0)
    local parts = {}
    for _, unit in ipairs(TIME_UNITS) do
        local val = floor(seconds / unit[1])
        seconds = seconds % unit[1]
        if val > 0 then parts[#parts + 1] = val .. unit[2] end
    end
    return #parts > 0 and tconcat(parts, " ") or "0min"
end

function WB:FormatCooldown(cd)
    if cd <= 0 then return nil end
    cd = floor(cd)
    if cd >= 3600 then
        return format("%d:%02d:%02d", floor(cd / 3600), floor(cd % 3600 / 60), cd % 60)
    end
    return format("%d:%02d", floor(cd / 60), cd % 60)
end

-- Tooltip helpers──
function WB:OpenTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_TOP")
    GameTooltip:ClearLines()
end

function WB:AddTooltipHint(leftText, rightText)
    local r, g, b = self:GetAccent()
    GameTooltip:AddDoubleLine(leftText, rightText, 1, 1, 1, r, g, b)
end

function WB:GetFPSSuffix() return FPS_ABBR or " fps" end
function WB:GetMSSuffix()  return MILLISECONDS_ABBR or " ms" end

-- Combat deferral (last caller per key wins; one shared frame for all keys)
do
    local pending = {}
    local frame
    function WB:DeferUntilOOC(key, fn)
        if not InCombatLockdown() then fn(); return end
        pending[key] = fn
        if not frame then
            frame = CreateFrame("Frame")
            frame:SetScript("OnEvent", function(self)
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                for k, f in pairs(pending) do
                    pending[k] = nil
                    if f then pcall(f) end
                end
            end)
        end
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end

-- Frame pool (short-lived child frames e.g. popup rows)
function WB:CreateFramePool(frameType, parent, template)
    self._trackedPools = self._trackedPools or setmetatable({}, { __mode = "k" })
    local pool = { _type = frameType, _parent = parent, _template = template }
    self._trackedPools[pool] = true
    pool._active = {}
    pool._inactive = {}

    function pool:Acquire()
        local f = tremove(self._inactive)
        if not f then
            f = CreateFrame(self._type, nil, self._parent, self._template)
        end
        f:SetParent(self._parent)
        f:Show()
        self._active[#self._active + 1] = f
        return f
    end

    local function ResetPooledFrame(f)
        if not f then return end
        f:Hide()
        f:ClearAllPoints()
        f:SetParent(pool._parent)
        f:SetAlpha(1)
        f:SetScale(1)
        f:SetWidth(1)
        f:SetHeight(1)
        f:EnableMouse(false)
        f:RegisterForClicks()
        f:SetScript("OnEnter", nil)
        f:SetScript("OnLeave", nil)
        f:SetScript("OnClick", nil)
        f:SetScript("OnMouseDown", nil)
        f:SetScript("OnMouseUp", nil)
        f:SetScript("OnUpdate", nil)
        f:SetScript("OnShow", nil)
        f:SetScript("OnHide", nil)
        if f.UnregisterAllEvents then pcall(f.UnregisterAllEvents, f) end
        if f.GetAnimationGroups then
            local ok, groups = pcall(function() return { f:GetAnimationGroups() } end)
            if ok and groups then
                for _, ag in ipairs(groups) do
                    if ag and ag.Stop then pcall(ag.Stop, ag) end
                end
            end
        end
        if f.GetNormalTexture and f:GetNormalTexture() and f:GetNormalTexture().SetTexture then f:GetNormalTexture():SetTexture(nil) end
        if f.GetPushedTexture and f:GetPushedTexture() and f:GetPushedTexture().SetTexture then f:GetPushedTexture():SetTexture(nil) end
        if f.GetHighlightTexture and f:GetHighlightTexture() and f:GetHighlightTexture().SetTexture then f:GetHighlightTexture():SetTexture(nil) end
        if f.GetDisabledTexture and f:GetDisabledTexture() and f:GetDisabledTexture().SetTexture then f:GetDisabledTexture():SetTexture(nil) end
        if f.GetCheckedTexture and f:GetCheckedTexture() and f:GetCheckedTexture().SetTexture then f:GetCheckedTexture():SetTexture(nil) end
        if f.SetButtonState then f:SetButtonState("NORMAL") end
        if f.SetChecked then f:SetChecked(false) end
        if f.SetText then f:SetText("") end
        if f.SetAttribute then
            pcall(f.SetAttribute, f, "type", nil)
            pcall(f.SetAttribute, f, "macrotext", nil)
            pcall(f.SetAttribute, f, "clickbutton", nil)
        end
        if f.GetNumRegions then
            local regions = { f:GetRegions() }
            for _, r in ipairs(regions) do
                if r and r.Hide then r:Hide() end
                if r and r.SetAlpha then r:SetAlpha(1) end
                if r and r.ClearAllPoints then r:ClearAllPoints() end
                if r and r.SetText then r:SetText("") end
                if r and r.SetTexture then r:SetTexture(nil) end
                if r and r.SetVertexColor then r:SetVertexColor(1, 1, 1, 1) end
                if r and r.SetTexCoord then r:SetTexCoord(0, 1, 0, 1) end
            end
        end
    end

    function pool:ReleaseAll()
        for i = #self._active, 1, -1 do
            local f = tremove(self._active, i)
            ResetPooledFrame(f)
            self._inactive[#self._inactive + 1] = f
        end
    end

    function pool:GetActive() return self._active end

    return pool
end

-- Popup helper — single shared click-catcher closes whichever popup is open.
do
    local sharedClickCatcher
    local activePopup

    local function GetClickCatcher()
        if not sharedClickCatcher then
            sharedClickCatcher = CreateFrame("Button", nil, UIParent)
            sharedClickCatcher:SetAllPoints(UIParent)
            sharedClickCatcher:SetFrameStrata("DIALOG")
            sharedClickCatcher:SetFrameLevel(100)
            sharedClickCatcher:Hide()
            sharedClickCatcher:EnableMouse(true)
            sharedClickCatcher:RegisterForClicks("AnyDown", "AnyUp")
            sharedClickCatcher:SetScript("OnClick", function()
                if activePopup and activePopup:IsShown() then activePopup:Hide() end
            end)
        end
        return sharedClickCatcher
    end

    function WB:CreatePopupFrame(parent)
        local popup = CreateFrame("Frame", nil, UIParent, "TooltipBackdropTemplate")
        popup:SetFrameStrata("TOOLTIP")
        popup:SetClampedToScreen(true)
        popup:Hide()
        popup:EnableKeyboard(false)
        popup:SetToplevel(true)

        local cc = GetClickCatcher()
        popup._wbClickCatcher = cc
        popup:SetFrameLevel(cc:GetFrameLevel() + 10)
        popup:SetScript("OnShow", function(self)
            activePopup = self
            local catcher = self._wbClickCatcher
            if catcher then
                catcher:ClearAllPoints()
                catcher:SetAllPoints(UIParent)
                catcher:Show()
                catcher:SetFrameStrata(self:GetFrameStrata())
                catcher:SetFrameLevel(max(1, self:GetFrameLevel() - 1))
            end
        end)
        popup:SetScript("OnHide", function(self)
            if activePopup == self then activePopup = nil end
            local catcher = self._wbClickCatcher
            if catcher and (not activePopup or not activePopup:IsShown()) then catcher:Hide() end
            if self._wbOnHide then self:_wbOnHide() end
        end)
        return popup
    end
end

-- Module registry: drives slot creation, layout, event frames, lifecycle dispatch.
-- Back-compat: _modules[key]:Refresh/Enable/Disable still work for callers.
WB._modules     = {}
WB._moduleOrder = {}   -- stable insertion order (used for enable/disable loops)

-- Module slotPos layout: 0 = pivot (centre); others sort ascending; ties break alphabetically.

-- Attach event frame for module's declared events (AceEvent-like dispatch)
local function AttachEventFrame(mod)
    if not mod.events or #mod.events == 0 then return end
    local f = mod._eventFrame
    if not f then
        f = CreateFrame("Frame")
        mod._eventFrame = f
        f:SetScript("OnEvent", function(_, event, ...)
            if mod.OnEvent then
                mod:OnEvent(event, ...)
            elseif mod[event] then
                mod[event](mod, event, ...)
            end
        end)
    else
        -- Re-enable after Disable: re-register declared events.
        f:UnregisterAllEvents()
    end
    for _, evt in ipairs(mod.events) do f:RegisterEvent(evt) end
end

local function DetachEventFrame(mod)
    if mod._eventFrame then mod._eventFrame:UnregisterAllEvents() end
end

function WB:RegisterModule(key, mod)
    if self._modules[key] then return end
    mod.key = mod.key or key
    self._modules[key] = mod
    self._moduleOrder[#self._moduleOrder + 1] = key

    -- Shim legacy Enable/Disable/Refresh for Options file compat
    if not mod.Enable then
        mod.Enable = function(self)
            if not self._created and self.OnCreate then
                self:OnCreate(); self._created = true
            end
            AttachEventFrame(self)
            if self.OnEnable then self:OnEnable() end
            if self.OnRefresh then self:OnRefresh() end
        end
    end
    if not mod.Disable then
        mod.Disable = function(self)
            DetachEventFrame(self)
            if self.OnDisable then self:OnDisable() end
        end
    end
    if not mod.Refresh then
        mod.Refresh = function(self)
            if self.OnRefresh then self:OnRefresh() end
        end
    end

    -- Late registration: if bar already up, enable immediately.
    if self.db and self._barReady then
        local mdb = self.db.profile[key]
        if mdb and mdb.enabled ~= false then
            mod:Enable()
        end
    end
end

function WB:IterateModules()
    local i = 0
    return function()
        i = i + 1
        local key = self._moduleOrder[i]
        if key then return key, self._modules[key] end
    end
end

-- Unlock Mode registration (provided by EUI core)
WB._unlockElements = {}
WB._pendingSlotAssignments = WB._pendingSlotAssignments or {}

function WB:StageSlotAssignment(slotIdx, newKey)
    if type(slotIdx) ~= "number" or type(newKey) ~= "string" or newKey == "" then return end
    self._pendingSlotAssignments = self._pendingSlotAssignments or {}
    for idx, entry in pairs(self._pendingSlotAssignments) do
        if entry and entry.newKey == newKey and idx ~= slotIdx then
            self._pendingSlotAssignments[idx] = nil
        end
    end
    self._pendingSlotAssignments[slotIdx] = { slotIdx = slotIdx, newKey = newKey }
end

function WB:HasPendingSlotAssignments()
    for _, entry in pairs(self._pendingSlotAssignments or {}) do
        if entry and entry.newKey then return true end
    end
    return false
end

-- Shared core for Preview/Commit. `commit=true` clears staged entries and
-- runs CleanupOrphanedOwners; `commit=false` calls RefreshBar when changed.
local SLOT_FIXED_POS = { [0] = 0, [1] = 10, [2] = 20, [3] = 30, [4] = 40, [5] = 50, [6] = 60, [7] = 70 }

local function _ApplySlotAssignments(self, commit)
    local staged = self._pendingSlotAssignments
    if type(staged) ~= "table" then return false end

    local slots = {}
    for slotIdx, entry in pairs(staged) do
        if type(slotIdx) == "number" and type(entry) == "table" and type(entry.newKey) == "string" and entry.newKey ~= "" then
            slots[#slots + 1] = slotIdx
        end
    end
    local hadEntries = (#slots > 0)
    if not hadEntries then return false end
    table.sort(slots)

    local db = self.db and self.db.profile
    if type(db) ~= "table" then return false end

    local function isVisible(key)
        local mdb = db[key]
        return mdb and (mdb.enabled ~= false)
    end

    local function getModuleAtFixedSlot(slotIdx)
        local targetPos = SLOT_FIXED_POS[slotIdx]
        if targetPos == nil then return nil end
        local best = nil
        for _, key in ipairs(self._moduleOrder or {}) do
            local mdb = db[key]
            if mdb and isVisible(key) and ((mdb.slotPos or 0) == targetPos) then
                if not best or key < best then best = key end
            end
        end
        return best
    end

    local changed = false
    for _, slotIdx in ipairs(slots) do
        local entry = staged[slotIdx]
        local newKey = entry and entry.newKey
        local newDB = newKey and db[newKey]
        local targetPos = SLOT_FIXED_POS[slotIdx]
        if newDB and targetPos ~= nil then
            local current = getModuleAtFixedSlot(slotIdx)
            if current ~= newKey or (newDB.slotPos or 0) ~= targetPos or not isVisible(newKey) then
                local wasHidden = not isVisible(newKey)
                local oldPos = newDB.slotPos or targetPos
                if wasHidden then newDB.enabled = true end
                if current and current ~= newKey and db[current] then
                    db[current].slotPos = oldPos
                end
                newDB.slotPos = targetPos
                if wasHidden then
                    local mod = self._modules and self._modules[newKey]
                    if mod then mod:Enable() end
                end
                changed = true
            end
        end
        if commit then staged[slotIdx] = nil end
    end

    if commit then
        if self.CleanupOrphanedOwners then
            pcall(function() self:CleanupOrphanedOwners() end)
        end
        return hadEntries or changed
    else
        if changed then self:RefreshBar() end
        return changed
    end
end

function WB:PreviewPendingSlotAssignments() return _ApplySlotAssignments(self, false) end
function WB:CommitPendingSlotAssignments()  return _ApplySlotAssignments(self, true)  end

-- OnInitialize — runs on ADDON_LOADED (saved vars available)
function WB:OnInitialize()
    self.db = EllesmereUI.Lite.NewDB("EllesmereUIWonderBarDB", defaults)
end

-- Bar — frame, layout, visibility, unlock integration
do
    local bar, bgTex
    local moduleSlots = {}

    -- Short DB accessor for bar settings
    local function BDB() return WB.db.profile.bar end

    -- Side-anchor detection
    local SIDE_POSITIONS = { LEFT = true, RIGHT = true }
    local function IsSideAnchored() return SIDE_POSITIONS[BDB().position] or false end
    WB.IsSideAnchored = IsSideAnchored

    -- Active-module resolution (all modules respect their `enabled` flag)
    local function IsModuleActive(key)
        local mdb = WB.db and WB.db.profile[key]
        return mdb == nil or mdb.enabled ~= false
    end

    local function GetSlotPos(key)
        local mdb = WB.db and WB.db.profile[key]
        return (mdb and mdb.slotPos) or 0
    end

    local function IsPivotKey(key)
        return GetSlotPos(key) == 0
    end

    -- Build ordered list: [left half] + [pivot] + [right half]
    -- Pivot = slotPos 0 (prefer Clock). Others sorted ascending by slotPos.
    local _activeCache = {}
    local _nonPivotScratch = {}
    local function GetActiveModules()
        wipe(_activeCache)
        wipe(_nonPivotScratch)

        -- Find all active keys and select a pivot.
        local pivotKey = nil
        for _, key in ipairs(WB._moduleOrder) do
            if IsModuleActive(key) then
                if IsPivotKey(key) then
                    if not pivotKey or key < pivotKey then
                        if pivotKey then
                            -- Previous pivot candidate now loses; push to non-pivots.
                            _nonPivotScratch[#_nonPivotScratch + 1] = pivotKey
                        end
                        pivotKey = key
                    else
                        _nonPivotScratch[#_nonPivotScratch + 1] = key
                    end
                else
                    _nonPivotScratch[#_nonPivotScratch + 1] = key
                end
            end
        end
        -- Fallback pivot: Clock if still nothing.
        if not pivotKey then
            for i, key in ipairs(_nonPivotScratch) do
                if key == "clock" then
                    pivotKey = key
                    table.remove(_nonPivotScratch, i)
                    break
                end
            end
        end
        -- Last resort: no pivot at all — pick the middle element.
        if not pivotKey and #_nonPivotScratch > 0 then
            local midIdx = floor(#_nonPivotScratch / 2) + 1
            pivotKey = _nonPivotScratch[midIdx]
            table.remove(_nonPivotScratch, midIdx)
        end

        -- Sort non-pivots by slotPos ascending, key alphabetical as tiebreak.
        table.sort(_nonPivotScratch, function(a, b)
            local pa, pb = GetSlotPos(a), GetSlotPos(b)
            if pa == pb then return a < b end
            return pa < pb
        end)

        -- Split: first half left, second half right of pivot.
        local n = #_nonPivotScratch
        local leftCount = floor(n / 2)

        for i = 1, leftCount do
            _activeCache[#_activeCache + 1] = _nonPivotScratch[i]
        end
        if pivotKey then
            _activeCache[#_activeCache + 1] = pivotKey
        end
        for i = leftCount + 1, n do
            _activeCache[#_activeCache + 1] = _nonPivotScratch[i]
        end
        return _activeCache
    end

    local function FindPivotIndex(active)
        -- The active list is built with the pivot already in the middle.
        for i, key in ipairs(active) do
            if IsPivotKey(key) then return i end
        end
        for i, key in ipairs(active) do
            if key == "clock" then return i end
        end
        return floor(#active / 2) + 1
    end

    -- Fade animations for mouseover visibility──────
    local function CreateFadeAnimations(frame)
        frame._wbFadeTarget = nil

        local ig = frame:CreateAnimationGroup()
        local ia = ig:CreateAnimation("Alpha")
        ia:SetOrder(1); ia:SetDuration(0.15); ia:SetSmoothing("OUT")
        ig:SetScript("OnFinished", function()
            if frame._wbFadeTarget == 1 then frame:SetAlpha(1) end
        end)

        local og = frame:CreateAnimationGroup()
        local oa = og:CreateAnimation("Alpha")
        oa:SetOrder(1); oa:SetDuration(0.25); oa:SetSmoothing("IN")
        og:SetScript("OnFinished", function()
            if frame._wbFadeTarget == 0 then frame:SetAlpha(0) end
        end)

        frame._wbFadeInGrp  = ig; frame._wbFadeIn  = ia
        frame._wbFadeOutGrp = og; frame._wbFadeOut = oa
    end

    local function PlayFade(frame, toAlpha)
        local grp   = toAlpha == 1 and frame._wbFadeInGrp  or frame._wbFadeOutGrp
        local anim  = toAlpha == 1 and frame._wbFadeIn      or frame._wbFadeOut
        local other = toAlpha == 1 and frame._wbFadeOutGrp or frame._wbFadeInGrp
        if not grp then return end
        frame._wbFadeTarget = toAlpha
        if other:IsPlaying() then other:Stop() end
        anim:SetFromAlpha(frame:GetAlpha()); anim:SetToAlpha(toAlpha); grp:Play()
    end

    local function ShowBar()
        if not bar then return end
        if not bar:IsShown() then bar:Show() end
        if bar._wbVisible then return end
        bar._wbVisible = true
        PlayFade(bar, 1)
    end

    local function HideBar()
        if not bar then return end
        if not bar._wbVisible then
            if not (bar._wbFadeOutGrp and bar._wbFadeOutGrp:IsPlaying()) then
                bar:SetAlpha(0)
            end
            return
        end
        bar._wbVisible = false
        PlayFade(bar, 0)
    end

    local function UpdateVisibility()
        if not bar then return end
        local d = BDB()
        if not d or d.enabled == false then
            bar._wbVisible = false
            bar:SetAlpha(0)
            bar:Hide()
            return
        end
        if not bar:IsShown() then bar:Show() end

        if d.visibility == "MOUSEOVER" then
            if bar:IsMouseOver() then ShowBar() else HideBar() end
        else
            ShowBar()
        end
    end

    -- Sizing and positioning──
    local function GetSideBarWidth()
        local thickness = PP.Scale(BDB().height)
        return max(thickness, min(150, floor(thickness * 3.6 + 0.5)))
    end
    WB.GetSideBarWidth = GetSideBarWidth

    local function ApplyBarSize()
        local db = BDB()
        local thickness = PP.Scale(db.height)
        local hLen = (db.width and db.width > 0) and PP.Scale(db.width) or UIParent:GetWidth()
        local vLen = (db.width and db.width > 0) and PP.Scale(db.width) or UIParent:GetHeight()

        if IsSideAnchored() then
            bar:SetSize(GetSideBarWidth(), vLen)
        else
            bar:SetSize(hLen, thickness)
        end
    end

    local function ApplyBackground()
        local db = BDB()
        bgTex:SetColorTexture(db.bgR, db.bgG, db.bgB, db.bgA)
    end

    local function ApplySavedOrDefaultPosition()
        local db = BDB()
        local pos = db.position
        bar:ClearAllPoints()
        if IsSideAnchored() then
            local y = db.savedY or 0
            if pos == "LEFT" then
                bar:SetPoint("LEFT", UIParent, "LEFT", 0, y)
            else
                bar:SetPoint("RIGHT", UIParent, "RIGHT", 0, y)
            end
        elseif db.savedPoint then
            bar:SetPoint(db.savedPoint, UIParent, db.savedRelPoint, db.savedX or 0, db.savedY or 0)
        else
            bar:SetPoint(pos, UIParent, pos, 0, 0)
        end
    end

    -- ── Slot layout ──────────────────────────────────────────────────────
    -- Clock pinned to absolute centre; modules distribute to each side with
    -- equal spacing. Scales down proportionally if content exceeds the bar.
    local _contentW = {}
    local _slotHeights = {}
    local function ApplyDynamicSlots()
        local active = GetActiveModules()
        local n = #active
        if n == 0 then return end

        for _, slot in pairs(moduleSlots) do slot:Hide() end

        wipe(_contentW)
        local contentW = _contentW
        local totalContent = 0
        for _, key in ipairs(active) do
            local mod = WB._modules[key]
            local w = (mod and mod.GetContentWidth) and mod:GetContentWidth() or 80
            contentW[key] = w
            totalContent = totalContent + w
        end

        if IsSideAnchored() then
            local MIN_SLOT_H = 40
            local bw = bar:GetWidth()
            local bl = bar:GetHeight()
            local pivotIdx = FindPivotIndex(active)
            local nTop     = pivotIdx - 1
            local nBottom  = n - pivotIdx

            wipe(_slotHeights)
            local totalWanted = 0
            for _, key in ipairs(active) do
                local h = max(MIN_SLOT_H, contentW[key])
                _slotHeights[key] = h
                totalWanted = totalWanted + h
            end
            local fitScale = (totalWanted > 0 and totalWanted > bl) and (bl / totalWanted) or 1
            local function SlotH(key) return max(MIN_SLOT_H, floor(_slotHeights[key] * fitScale + 0.5)) end

            local pivotH = SlotH(active[pivotIdx])
            local zoneTop = floor(bl / 2 - pivotH / 2 + 0.5)
            local totalTopContent = 0
            for i = 1, nTop do totalTopContent = totalTopContent + SlotH(active[i]) end
            local gapTop = nTop > 0 and max(0, (zoneTop - totalTopContent) / nTop) or 0

            local pivotBottom = floor(bl / 2 + pivotH / 2 + 0.5)
            local zoneBottom = bl - pivotBottom
            local totalBottomContent = 0
            for i = pivotIdx + 1, n do totalBottomContent = totalBottomContent + SlotH(active[i]) end
            local gapBottom = nBottom > 0 and max(0, (zoneBottom - totalBottomContent) / nBottom) or 0

            local y = 0
            for i = 1, nTop do
                local key  = active[i]
                local slot = moduleSlots[key]
                slot:SetWidth(bw); slot:SetHeight(SlotH(key))
                slot:ClearAllPoints(); slot:SetPoint("TOP", bar, "TOP", 0, -y)
                slot:Show()
                y = y + SlotH(key) + gapTop
            end

            local pivotSlot = moduleSlots[active[pivotIdx]]
            pivotSlot:SetWidth(bw); pivotSlot:SetHeight(pivotH)
            pivotSlot:ClearAllPoints(); pivotSlot:SetPoint("CENTER", bar, "CENTER", 0, 0)
            pivotSlot:Show()

            local yb = 0
            for i = nBottom, 1, -1 do
                local key  = active[pivotIdx + i]
                local slot = moduleSlots[key]
                slot:SetWidth(bw); slot:SetHeight(SlotH(key))
                slot:ClearAllPoints(); slot:SetPoint("BOTTOM", bar, "BOTTOM", 0, yb)
                slot:Show()
                yb = yb + SlotH(key) + gapBottom
            end
        else
            local bh = bar:GetHeight()
            local bw = bar:GetWidth()
            local pivotIdx = FindPivotIndex(active)
            local nLeft    = pivotIdx - 1
            local nRight   = n - pivotIdx
            local pivotW = contentW[active[pivotIdx]]

            local zoneLeft = floor(bw / 2 - pivotW / 2 + 0.5)
            local totalLeftContent = 0
            for i = 1, nLeft do totalLeftContent = totalLeftContent + contentW[active[i]] end
            local gapLeft = nLeft > 0 and max(0, (zoneLeft - totalLeftContent) / nLeft) or 0

            local pivotRight = floor(bw / 2 + pivotW / 2 + 0.5)
            local zoneRight  = bw - pivotRight
            local totalRightContent = 0
            for i = pivotIdx + 1, n do totalRightContent = totalRightContent + contentW[active[i]] end
            local gapRight = nRight > 0 and max(0, (zoneRight - totalRightContent) / nRight) or 0

            local x = 0
            for i = 1, nLeft do
                local key  = active[i]
                local slot = moduleSlots[key]
                slot:SetHeight(bh); slot:SetWidth(contentW[key])
                slot:ClearAllPoints(); slot:SetPoint("LEFT", bar, "LEFT", x, 0)
                slot:Show()
                x = x + contentW[key] + gapLeft
            end

            local pivotSlot = moduleSlots[active[pivotIdx]]
            pivotSlot:SetHeight(bh); pivotSlot:SetWidth(pivotW)
            pivotSlot:ClearAllPoints(); pivotSlot:SetPoint("CENTER", bar, "CENTER", 0, 0)
            pivotSlot:Show()

            local xr = 0
            for i = nRight, 1, -1 do
                local key  = active[pivotIdx + i]
                local slot = moduleSlots[key]
                slot:SetHeight(bh); slot:SetWidth(contentW[key])
                slot:ClearAllPoints(); slot:SetPoint("RIGHT", bar, "RIGHT", -xr, 0)
                slot:Show()
                xr = xr + contentW[key] + gapRight
            end
        end
    end

    -- Public refresh API──
    function WB:RefreshBar()
        if not bar then return end
        if self._fitCache then wipe(self._fitCache); self._fitCacheCount = 0 end
        ApplyBarSize()
        ApplySavedOrDefaultPosition()
        ApplyBackground()
        UpdateVisibility()
        -- Let modules compute content sizes, then lay out on the next frame.
        for _, mod in self:IterateModules() do
            if mod.Refresh then mod:Refresh() end
        end
        if self._layoutRefreshPending then return end
        self._layoutRefreshPending = true
        C_Timer.After(0, function()
            self._layoutRefreshPending = nil
            if not bar then return end
            ApplyDynamicSlots()
        end)
    end

    -- Bar construction────
    local function ConstructBar()
        if bar then return end

        bar = CreateFrame("Frame", "EllesmereUIWonderBar", UIParent)
        bar:SetFrameStrata("MEDIUM"); bar:SetFrameLevel(10); bar._wbVisible = true

        bgTex = bar:CreateTexture(nil, "BACKGROUND", nil, -1); bgTex:SetAllPoints()
        PP.CreateBorder(bar, 0, 0, 0, 0.8, 1, "OVERLAY", 7)
        CreateFadeAnimations(bar)

        bar:SetMovable(true); bar:EnableMouse(false)

        bar:SetScript("OnEnter", function()
            if BDB().visibility == "MOUSEOVER" then ShowBar() end
        end)
        bar:SetScript("OnLeave", function()
            if BDB().visibility ~= "MOUSEOVER" then return end
            local delay = BDB().mouseoverDelay or 0.3
            local token = (bar._wbHideToken or 0) + 1
            bar._wbHideToken = token
            C_Timer.After(delay, function()
                if bar._wbHideToken ~= token then return end
                if not bar:IsMouseOver() then HideBar() end
            end)
        end)

        -- One slot per registered module (disabled slots just hide)
        for _, key in ipairs(WB._moduleOrder) do
            local slot = CreateFrame("Frame", "EllesmereUIWonderBarSlot_" .. key, bar)
            slot:SetSize(100, 30)
            slot:Hide()
            moduleSlots[key] = slot
        end

        WB.bar = bar
        WB.moduleSlots = moduleSlots

        -- Pet-battle hide/show
        WB._barEvtFrame = CreateFrame("Frame")
        local evtFrame = WB._barEvtFrame
        evtFrame:RegisterEvent("PET_BATTLE_OPENING_START")
        evtFrame:RegisterEvent("PET_BATTLE_CLOSE")
        evtFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        evtFrame:SetScript("OnEvent", function(_, event)
            if event == "PET_BATTLE_OPENING_START" then
                bar._wbVisible = false; bar:SetAlpha(0); bar:Hide(); return
            end
            if event == "PET_BATTLE_CLOSE" then
                bar:Show(); UpdateVisibility(); return
            end
            UpdateVisibility()
        end)

        WB:RefreshBar()
    end

    -- Unlock-mode integration──
    local function RegisterBarWithUnlockMode()
        if WB._unlockRegistered then return end
        if not (EllesmereUI and EllesmereUI.MakeUnlockElement) then return end
        if not bar then return end
        local elem = EllesmereUI.MakeUnlockElement({
            key      = "WonderBar",
            label    = "WonderBar",
            group    = "WonderBar",
            order    = 900,
            getFrame = function() return bar end,
            getSize  = function()
                if not bar then return 0, 0 end
                return bar:GetSize()
            end,
            savePos  = function(_, pt, rpt, x, y)
                local d = BDB()
                d.savedPoint = pt; d.savedRelPoint = rpt; d.savedX = x; d.savedY = y
            end,
            loadPos  = function()
                local d = BDB()
                if not d.savedPoint then return nil end
                return { point = d.savedPoint, relPoint = d.savedRelPoint, x = d.savedX, y = d.savedY }
            end,
            clearPos = function()
                local d = BDB()
                d.savedPoint = nil; d.savedRelPoint = nil; d.savedX = nil; d.savedY = nil
            end,
            applyPos = function()
                local changed = WB:CommitPendingSlotAssignments()
                WB:RefreshBar()
                if changed and WB.CleanupOrphanedOwners then
                    pcall(function() WB:CleanupOrphanedOwners() end)
                end
            end,
            noResize = true,
        })
        WB._unlockElements[#WB._unlockElements + 1] = elem
        WB._unlockRegistered = true
        if type(WB.RegisterUnlock) == "function" then
            WB:RegisterUnlock()
        elseif type(EllesmereUI) == "table" and type(EllesmereUI.RegisterUnlock) == "function" then
            EllesmereUI.RegisterUnlock(WB)
        end
    end

    -- Lifecycle───
    function WB:OnEnable()
        if not self.db or not self.db.profile or not self.db.profile.bar then return end
        if self.db.profile.bar.enabled == false then
            if bar then
                bar._wbVisible = false; bar:SetAlpha(0); bar:Hide()
            end
            return
        end

        ConstructBar()
        RegisterBarWithUnlockMode()
        self._barReady = true

        -- Live theme-colour update when bar uses "theme" preset
        if not self._themeCallbackRegistered and EllesmereUI.RegAccent then
            self._themeCallbackRegistered = true
            EllesmereUI.RegAccent({
                type = "callback",
                callback = function(r, g, b)
                    local barDb = self.db and self.db.profile and self.db.profile.bar
                    if barDb and barDb.barColour == "theme" then
                        barDb.bgR = r * 0.15
                        barDb.bgG = g * 0.15
                        barDb.bgB = b * 0.15
                        if bar then ApplyBackground() end
                    end
                end,
            })
        end

        if bar then
            bar:Show(); bar._wbVisible = true; bar:SetAlpha(1)
        end
        for key, mod in self:IterateModules() do
            local mdb = self.db.profile[key]
            if mdb and mdb.enabled ~= false and mod.Enable then mod:Enable() end
        end
        UpdateVisibility()
    end

    function WB:OnDisable()
        if bar then bar:Hide() end
        for _, mod in self:IterateModules() do
            if mod.Disable then mod:Disable() end
        end
    end

    function WB:GetModuleSlot(key) return moduleSlots[key] end
    function WB:GetBarHeight() return BDB().height end
    function WB:GetBarWidth()  return bar and bar:GetWidth() or 0 end
end

-- Module-authoring helpers (closure-scoped; shared text-fitting for horizontal and side bars)
local IsSideAnchored   -- forward-bind after bar closure has set WB.IsSideAnchored
local GetSideBarWidth  -- same

local function DB(key) return WB.db and WB.db.profile[key] end
local function BarDB() return WB.db and WB.db.profile.bar end

local function GetSlotWidth(key, fallback)
    if IsSideAnchored() then
        local slot = WB.GetModuleSlot and WB:GetModuleSlot(key)
        local w = slot and slot:GetWidth()
        if w and w > 1 then return w end
        return GetSideBarWidth()
    end
    return fallback or 400
end

local function SetWrappedText(fs, width, justify)
    if not fs then return end
    fs:SetWidth(max(1, width or 1))
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(true) end
    if fs.SetJustifyH then fs:SetJustifyH(justify or "CENTER") end
end

local function ResetInlineText(fs, justify)
    if not fs then return end
    fs:SetWidth(0)
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
    if fs.SetJustifyH then fs:SetJustifyH(justify or "LEFT") end
end

-- FitFontToLines: largest font in [minSize..startSize] where all lines fit maxWidth. Cached.
WB._fitCache = WB._fitCache or {}
WB._fitCacheCount = WB._fitCacheCount or 0
local _measureFS
local _fitKeyParts = {}
local function FitFontToLines(lines, startSize, minSize, maxWidth)
    if not _measureFS then
        if not UIParent then return startSize end
        _measureFS = UIParent:CreateFontString(nil, "OVERLAY")
        if not _measureFS then return startSize end
    end
    local width = max(1, maxWidth or 1)
    local start = startSize or 14
    local floorSize = minSize or max(8, start - 6)

    wipe(_fitKeyParts)
    _fitKeyParts[1] = start; _fitKeyParts[2] = floorSize; _fitKeyParts[3] = width
    for i, line in ipairs(lines or {}) do _fitKeyParts[i + 3] = line or "" end
    local cacheKey = tconcat(_fitKeyParts, "\1")
    local cached = WB._fitCache[cacheKey]
    if cached then return cached end

    for size = start, floorSize, -1 do
        WB:SetFont(_measureFS, size)
        local widest = 0
        for _, line in ipairs(lines or {}) do
            _measureFS:SetText(line or "")
            local w = _measureFS:GetStringWidth() or 0
            if w > widest then widest = w end
        end
        if widest <= width then
            if WB._fitCacheCount > 200 then WB._fitCache = {}; WB._fitCacheCount = 0 end
            WB._fitCache[cacheKey] = size
            WB._fitCacheCount = WB._fitCacheCount + 1
            return size
        end
    end
    if WB._fitCacheCount > 200 then WB._fitCache = {}; WB._fitCacheCount = 0 end
    WB._fitCache[cacheKey] = floorSize
    WB._fitCacheCount = WB._fitCacheCount + 1
    return floorSize
end

-- Shared heartbeat buckets: multiple modules piggy-back on one ticker per interval.
WB._heartbeatBuckets = WB._heartbeatBuckets or {}
local function GetHeartbeatBucket(interval)
    local buckets = WB._heartbeatBuckets
    local bucket = buckets[interval]
    if not bucket then
        bucket = { callbacks = {}, ticker = nil }
        buckets[interval] = bucket
    end
    return bucket
end

local function StartHeartbeat(owner, interval, callback)
    if not owner or type(callback) ~= "function" then return end
    local bucket = GetHeartbeatBucket(interval)
    bucket.callbacks[owner] = callback
    if bucket.ticker then return end
    bucket.ticker = C_Timer.NewTicker(interval, function()
        for key, fn in pairs(bucket.callbacks) do
            if type(fn) ~= "function" then
                bucket.callbacks[key] = nil
            else
                local ok, keep = pcall(fn)
                if not ok or keep == false then
                    bucket.callbacks[key] = nil
                end
            end
        end
        if not next(bucket.callbacks) and bucket.ticker then
            bucket.ticker:Cancel()
            bucket.ticker = nil
        end
    end)
end

local function StopHeartbeat(owner, interval)
    local buckets = WB._heartbeatBuckets
    local bucket = buckets and buckets[interval]
    if not bucket then return end
    bucket.callbacks[owner] = nil
    if not next(bucket.callbacks) and bucket.ticker then
        bucket.ticker:Cancel()
        bucket.ticker = nil
    end
end

function WB:RunHousekeeping()
    local stats = {
        heartbeatOwnersRemoved = 0,
        heartbeatBucketsStopped = 0,
        poolsReleased = 0,
        pooledFramesReleased = 0,
        popupsHidden = 0,
        orphanFramesHidden = 0,
    }

    local buckets = self._heartbeatBuckets
    if buckets then
        for _, bucket in pairs(buckets) do
            if bucket and bucket.callbacks then
                for owner, fn in pairs(bucket.callbacks) do
                    local remove = (type(fn) ~= "function")
                    if not remove then
                        if type(owner) ~= "table" and type(owner) ~= "userdata" then
                            remove = true
                        elseif owner.IsShown and owner.IsObjectType then
                            local parent = owner.GetParent and owner:GetParent()
                            remove = (owner:IsObjectType("Frame") and not owner:IsShown() and (not parent or parent == UIParent or not parent:IsShown()))
                        elseif owner.IsShown then
                            remove = not owner:IsShown()
                        end
                    end
                    if remove then
                        bucket.callbacks[owner] = nil
                        stats.heartbeatOwnersRemoved = stats.heartbeatOwnersRemoved + 1
                    end
                end
                if not next(bucket.callbacks) and bucket.ticker then
                    bucket.ticker:Cancel()
                    bucket.ticker = nil
                    stats.heartbeatBucketsStopped = stats.heartbeatBucketsStopped + 1
                end
            end
        end
    end

    local pools = rawget(self, "_trackedPools")
    if pools then
        for pool in pairs(pools) do
            if pool then
                local active = pool.GetActive and pool:GetActive()
                if active and #active > 0 then
                    stats.pooledFramesReleased = stats.pooledFramesReleased + #active
                    if pool._popup and pool._popup.IsShown and pool._popup:IsShown() then
                        pool._popup:Hide()
                        stats.popupsHidden = stats.popupsHidden + 1
                    end
                    if pool.ReleaseAll then pool:ReleaseAll() end
                    stats.poolsReleased = stats.poolsReleased + 1
                elseif pool._popup and pool._popup.IsShown and pool._popup:IsShown() then
                    pool._popup:Hide()
                    stats.popupsHidden = stats.popupsHidden + 1
                end
            end
        end
    end

    local f = EnumerateFrames and EnumerateFrames()
    while f do
        local name = f.GetName and f:GetName()
        if name and name:match("^EllesmereUIWonderBar") then
            local parent = f.GetParent and f:GetParent()
            local hidden = f.IsShown and not f:IsShown()
            local orphaned = hidden and (not parent or parent == UIParent or (parent.IsShown and not parent:IsShown()))
            if orphaned then
                if f.UnregisterAllEvents then pcall(f.UnregisterAllEvents, f) end
                if f.SetScript then
                    pcall(f.SetScript, f, "OnUpdate", nil)
                    pcall(f.SetScript, f, "OnEvent", nil)
                end
                if f.Hide then pcall(f.Hide, f) end
                stats.orphanFramesHidden = stats.orphanFramesHidden + 1
            end
        end
        f = EnumerateFrames(f)
    end

    return stats
end

-- Bind forwards once bar block has attached the methods to WB
IsSideAnchored  = function(...) return WB.IsSideAnchored(...) end
GetSideBarWidth = function(...) return WB.GetSideBarWidth(...) end

-- Module: CLOCK
do
    local M = {
        events = { "PLAYER_UPDATE_RESTING", "PLAYER_REGEN_ENABLED",
                   "MAIL_INBOX_UPDATE", "UPDATE_PENDING_MAIL" },
    }

    local infoIndex = 1
    local infoItems = {}
    local needsResize = false
    local isMouseOver = false
    local infoTickCount = 0
    local forceRefresh = true
    local lastTimeText, lastDateText, lastHasMail = nil, nil, nil
    local _fitTimeBuf = { "" }
    local _fitDateBuf = { "" }

    local RESTING_TEX = MEDIA .. "resting.blp"

    local function FontSizeClock()
        local d = DB("clock")
        return d and d.fontSizeClock or BarDB().fontSizeLarge or 32
    end
    local function FontSizeInfo()
        local d = DB("clock")
        return d and d.fontSizeInfo or BarDB().fontSizeSmall or 16
    end

    local function GetTimeString()
        local d = DB("clock") or {}
        local h, m
        if d.localTime ~= false then
            h = tonumber(date("%H")); m = tonumber(date("%M"))
        else
            local gh, gm = GetGameTime()
            h = floor(gh); m = floor(gm)
        end
        if d.twentyFour == false then
            if h > 12 then h = h - 12 end
            if h == 0 then h = 12 end
            return format("%d:%02d", h, m)
        end
        return format("%02d:%02d", h, m)
    end

    local function RebuildInfoItems()
        local d = DB("clock") or {}
        wipe(infoItems)
        if d.showDate ~= false then
            infoItems[#infoItems + 1] = date("%d/%m/%Y")
        end
        if d.showMail ~= false and HasNewMail() then
            infoItems[#infoItems + 1] = L["YOU_HAVE_MAIL"]
        end
        if infoIndex > #infoItems then infoIndex = 1 end
    end

    function M:OnRefresh()
        if not self.clockFrame then return end
        if InCombatLockdown() then needsResize = true; return end

        local isSide = IsSideAnchored()
        local clockSz = FontSizeClock()
        local infoSz  = FontSizeInfo()
        local ar, ag, ab = WB:GetAccent()
        local timeText = GetTimeString()

        if isSide then
            local slotW = GetSlotWidth("clock", 120)
            local innerW = max(30, slotW - 8)
            _fitTimeBuf[1] = timeText
            clockSz = FitFontToLines(_fitTimeBuf, clockSz, max(10, clockSz - 10), innerW)
            if #infoItems > 0 then
                infoSz = FitFontToLines(infoItems, infoSz, max(8, infoSz - 8), innerW)
            else
                _fitDateBuf[1] = date("%d/%m/%Y")
                infoSz = FitFontToLines(_fitDateBuf, infoSz, max(8, infoSz - 8), innerW)
            end
        end

        WB:SetFont(self.clockText, clockSz)
        self.clockText:SetText(timeText)
        if isMouseOver then
            self.clockText:SetTextColor(ar, ag, ab, 1)
        else
            self.clockText:SetTextColor(1, 1, 1, 1)
        end

        WB:SetFont(self.eventText, infoSz)
        RebuildInfoItems()
        if #infoItems > 0 then
            self.eventText:SetText(infoItems[infoIndex] or "")
            self.eventText:SetTextColor(ar, ag, ab, 1)
            self.eventText:Show()
        else
            self.eventText:Hide()
        end

        local dc = DB("clock") or {}
        if dc.showResting ~= false and IsResting() then
            self.restFrame:Show()
        else
            self.restFrame:Hide()
        end

        local barAtTop = BarDB().position == "TOP"
        local barH2 = WB:GetBarHeight()
        local restW = floor(barH2 * 0.55 + 0.5)
        local restH = floor(barH2 * 0.72 + 0.5)
        self.restFrame:SetSize(restW, restH)
        self.restFrame:ClearAllPoints()

        if isSide then
            local slotW = GetSlotWidth("clock", 120)
            local innerW = max(30, slotW - 8)

            self.clockFrame:SetWidth(slotW)
            self.clockTextFrame:SetWidth(slotW)
            self.clockFrame:ClearAllPoints()
            self.clockFrame:SetPoint("CENTER", WB:GetModuleSlot("clock"), "CENTER", 0, 0)
            self.clockTextFrame:ClearAllPoints()
            self.clockTextFrame:SetPoint("CENTER", self.clockFrame, "CENTER", 0, 0)

            SetWrappedText(self.clockText, innerW, "CENTER")
            self.clockText:ClearAllPoints()
            self.clockText:SetPoint("TOP", self.clockTextFrame, "TOP", 0, -4)

            local totalH = 8 + WB:SnapToPixelGrid(self.clockText:GetStringHeight())
            if self.eventText:IsShown() then
                SetWrappedText(self.eventText, innerW, "CENTER")
                self.eventText:ClearAllPoints()
                self.eventText:SetPoint("TOP", self.clockText, "BOTTOM", 0, -4)
                totalH = totalH + 4 + WB:SnapToPixelGrid(self.eventText:GetStringHeight())
            end

            totalH = max(totalH, WB:GetBarHeight() + 8)
            self.clockFrame:SetHeight(totalH)
            self.clockTextFrame:SetHeight(totalH)

            if self.restFrame:IsShown() then
                self.restFrame:SetPoint("TOPRIGHT", self.clockFrame, "TOPRIGHT", -2, -2)
            end
        else
            local slotW = GetSlotWidth("clock", 120)
            local restExtra = self.restFrame:IsShown() and (restW + 4) or 0
            local textBudget = max(30, slotW - restExtra)
            clockSz = FitFontToLines(_fitTimeBuf, clockSz, max(10, clockSz - 8), textBudget)
            WB:SetFont(self.clockText, clockSz)
            self.clockText:SetText(timeText)
            if #infoItems > 0 then
                infoSz = FitFontToLines(infoItems, infoSz, max(8, infoSz - 8), textBudget)
                WB:SetFont(self.eventText, infoSz)
                self.eventText:SetText(infoItems[infoIndex] or "")
            end

            ResetInlineText(self.clockText, "CENTER")
            ResetInlineText(self.eventText, "CENTER")

            local tw = WB:SnapToPixelGrid(self.clockText:GetStringWidth())
            local th = WB:SnapToPixelGrid(self.clockText:GetStringHeight())
            if th < 1 then th = 1 end

            self.clockFrame:SetSize(min(slotW, max(tw, 1) + restExtra), th)
            self.clockFrame:ClearAllPoints()
            self.clockFrame:SetPoint("CENTER")

            self.clockTextFrame:SetSize(min(slotW, max(tw, 1) + restExtra), th)
            self.clockTextFrame:ClearAllPoints()
            self.clockTextFrame:SetPoint("CENTER")

            self.clockText:ClearAllPoints()
            self.clockText:SetPoint("CENTER")

            self.eventText:ClearAllPoints()
            if barAtTop then
                self.eventText:SetPoint("CENTER", self.clockText, "BOTTOM", 0, -6)
            else
                self.eventText:SetPoint("CENTER", self.clockText, "TOP", 0, 6)
            end

            if self.restFrame:IsShown() then
                if barAtTop then
                    self.restFrame:SetPoint("TOPLEFT", self.clockText, "TOPRIGHT", 2, -12)
                else
                    self.restFrame:SetPoint("BOTTOMLEFT", self.clockText, "BOTTOMRIGHT", 2, 12)
                end
            end
        end
    end

    local FRAME_DELAY = 2 / 8
    local NUM_FRAMES  = 8
    local COL_W       = 1 / 16
    local restFrameIndex = 1

    local function RefreshClockInfoLabel()
        if M.eventText and #infoItems > 0 then
            local r, g, b = WB:GetAccent()
            M.eventText:SetText(infoItems[infoIndex] or "")
            M.eventText:SetTextColor(r, g, b, 1)
        end
    end

    local function StartRestAnimation()
        if not (M.restFrame and M.restIcon and M.restFrame:IsShown()) then return end
        restFrameIndex = 1
        M.restIcon:SetTexCoord(0, COL_W, 0, 0.5)
        StartHeartbeat(M.restFrame, FRAME_DELAY, function()
            if not (M.restFrame and M.restFrame:IsShown() and M.restIcon) then return false end
            restFrameIndex = (restFrameIndex % NUM_FRAMES) + 1
            local left = (restFrameIndex - 1) * COL_W
            M.restIcon:SetTexCoord(left, left + COL_W, 0, 0.5)
            return true
        end)
    end

    local function StopRestAnimation()
        if M.restFrame then StopHeartbeat(M.restFrame, FRAME_DELAY) end
    end

    function M:OnHeartbeat()
        if not (self.clockFrame and self.clockFrame:IsShown()) then return false end

        local d = DB("clock") or {}
        local currentTime = GetTimeString()
        local currentDate = date("%d/%m/%Y")
        local hasMail = HasNewMail() and true or false
        local shouldRefresh = forceRefresh

        if currentTime ~= lastTimeText then
            lastTimeText = currentTime
            shouldRefresh = true
        end
        if d.showDate ~= false and currentDate ~= lastDateText then
            lastDateText = currentDate
            shouldRefresh = true
        end
        if d.showMail ~= false and hasMail ~= lastHasMail then
            lastHasMail = hasMail
            shouldRefresh = true
        end

        if shouldRefresh then
            forceRefresh = false
            infoTickCount = 0
            self:OnRefresh()
        elseif #infoItems > 1 then
            infoTickCount = infoTickCount + 1
            if infoTickCount >= 5 then
                infoTickCount = 0
                infoIndex = (infoIndex % #infoItems) + 1
                RefreshClockInfoLabel()
            end
        else
            infoTickCount = 0
        end

        return true
    end

    function M:OnCreate()
        self.clockFrame = CreateFrame("Frame", "EllesmereUIWonderBarClock", WB:GetModuleSlot("clock"))
        self.clockFrame:SetSize(100, 20)
        self.clockFrame:SetPoint("CENTER")

        self.clockTextFrame = CreateFrame("Button", nil, self.clockFrame)
        self.clockTextFrame:SetSize(100, 20)
        self.clockTextFrame:SetPoint("CENTER")
        self.clockTextFrame:EnableMouse(true)

        self.clockText = self.clockTextFrame:CreateFontString(nil, "OVERLAY")
        self.clockText:SetPoint("CENTER")
        self.clockText:SetTextColor(1, 1, 1, 1)

        self.eventText = self.clockTextFrame:CreateFontString(nil, "OVERLAY")
        self.eventText:SetPoint("CENTER", self.clockText, "TOP", 0, 6)
        self.eventText:Hide()

        -- Resting icon flipbook
        self.restFrame = CreateFrame("Frame", nil, self.clockFrame)
        self.restFrame:SetSize(16, 21)
        self.restFrame:Hide()

        self.restIcon = self.restFrame:CreateTexture(nil, "OVERLAY")
        self.restIcon:SetDrawLayer("OVERLAY", 7)
        self.restIcon:SetAllPoints(self.restFrame)
        self.restIcon:SetTexture(RESTING_TEX)
        self.restIcon:SetTexCoord(0, 1/16, 0, 0.5)

        self.restFrame:SetScript("OnShow", StartRestAnimation)
        self.restFrame:SetScript("OnHide", StopRestAnimation)

        -- Mouse + click
        self.clockTextFrame:SetScript("OnEnter", function()
            isMouseOver = true
            local ar, ag, ab = WB:GetAccent()
            M.clockText:SetTextColor(ar, ag, ab, 1)
            WB:OpenTooltip(self.clockTextFrame, "ANCHOR_TOP")
            GameTooltip:AddLine(date("%A %d %B %Y"), 1, 1, 1)
            local gh, gm = GetGameTime()
            GameTooltip:AddDoubleLine(L["SERVER_TIME"], format("%02d:%02d", floor(gh), floor(gm)), 0.6,0.6,0.6, 1,1,1)

            local numInstances = GetNumSavedInstances and GetNumSavedInstances() or 0
            if numInstances > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L["SAVED_INSTANCES"], 1, 0.82, 0)
                for i = 1, numInstances do
                    local name, _, reset, _, locked, extended = GetSavedInstanceInfo(i)
                    if locked or extended then
                        GameTooltip:AddDoubleLine(name, WB:FormatTimeLeft(reset), 1,1,1, 0.6,0.6,0.6)
                    end
                end
            end
            GameTooltip:AddLine(" ")
            local dailyReset = GetQuestResetTime and GetQuestResetTime() or 0
            if dailyReset > 0 then
                GameTooltip:AddDoubleLine(L["DAILY_RESET"], WB:FormatTimeLeft(dailyReset), 0.6,0.6,0.6, 1,1,1)
            end
            local weeklyReset = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset() or 0
            if weeklyReset > 0 then
                GameTooltip:AddDoubleLine(L["WEEKLY_RESET"], WB:FormatTimeLeft(weeklyReset), 0.6,0.6,0.6, 1,1,1)
            end
            if HasNewMail() then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L["YOU_HAVE_MAIL"], 1, 0.82, 0)
            end
            GameTooltip:AddLine(" ")
            local r, g, b = WB:GetAccent()
            GameTooltip:AddDoubleLine(L["LEFT_CLICK"], L["TOGGLE_CALENDAR"], 1,1,1, r,g,b)
            GameTooltip:AddDoubleLine(L["RIGHT_CLICK"], L["TOGGLE_CLOCK"], 1,1,1, r,g,b)
            GameTooltip:AddDoubleLine(L["SHIFT_MIDDLE_CLICK"], L["RELOAD_UI"], 1,1,1, r,g,b)
            GameTooltip:Show()
        end)
        self.clockTextFrame:SetScript("OnLeave", function()
            isMouseOver = false
            M.clockText:SetTextColor(1, 1, 1, 1)
            GameTooltip:Hide()
        end)
        self.clockTextFrame:SetScript("OnClick", function(_, button)
            if button == "MiddleButton" and IsShiftKeyDown() then ReloadUI()
            elseif button == "LeftButton" then if ToggleCalendar then ToggleCalendar() end
            elseif button == "RightButton" then
                if ToggleTimeManager then ToggleTimeManager()
                elseif GameTimeFrame then GameTimeFrame:Click() end
            end
        end)
        self.clockTextFrame:RegisterForClicks("AnyUp")
    end

    function M:OnEvent(event)
        forceRefresh = true
        if event == "PLAYER_REGEN_ENABLED" and needsResize then
            needsResize = false
        end
        if self.clockFrame and self.clockFrame:IsShown() and not InCombatLockdown() then
            self:OnRefresh()
            forceRefresh = false
        end
    end

    function M:OnEnable()
        self.clockFrame:Show()
        forceRefresh = true
        infoTickCount = 0
        needsResize = false
        lastTimeText = nil
        lastDateText = nil
        lastHasMail = nil
        StartHeartbeat(self, 1, function() return self:OnHeartbeat() end)
        self:OnRefresh()
    end

    function M:OnDisable()
        needsResize = false
        forceRefresh = true
        infoTickCount = 0
        StopHeartbeat(self, 1)
        StopRestAnimation()
        if self.clockFrame then self.clockFrame:Hide() end
        if self.restFrame then self.restFrame:Hide() end
    end

    function M:GetContentWidth()
        if not self.clockTextFrame then return 80 end
        if IsSideAnchored() then
            local barH = WB:GetBarHeight() or 30
            local textH = self.clockText and self.clockText:GetStringHeight() or FontSizeClock()
            local infoH = (self.eventText and self.eventText:IsShown()) and (self.eventText:GetStringHeight() + 4) or 0
            return max(8 + textH + infoH + 8, barH, 60)
        end
        local w = self.clockTextFrame:GetWidth() or 80
        local dc = DB("clock") or {}
        if dc.showResting ~= false then
            w = w + floor(WB:GetBarHeight() * 0.55 + 0.5) + 4
        end
        return max(w, 60)
    end

    WB:RegisterModule("clock", M)
end

-- Module: SYSTEM (FPS + latency)
do
    local M = {}

    local FPS_TEX  = MEDIA .. "fps.tga"
    local PING_TEX = MEDIA .. "ping.tga"
    local FPS_THRESHOLD, LAT_THRESHOLD = 60, 60

    local function GetFPSColor(fps)
        local lb = FPS_THRESHOLD * 0.5
        local perc = fps < FPS_THRESHOLD and ((fps - lb) / lb) or 1
        return WB:SlowColorGradient(perc)
    end
    local function GetLatColor(lat)
        local perc = lat > LAT_THRESHOLD and (1 - (lat - LAT_THRESHOLD) / LAT_THRESHOLD) or 1
        return WB:SlowColorGradient(perc)
    end

    local _sysFitBuf = { "", "" }

    function M:OnRefresh()
        if not self.systemFrame then return end
        local barH = WB:GetBarHeight() or 30
        local baseFontSize = max(9, floor(barH * 0.46 + 0.5))
        local dbs = DB("system") or {}
        local iconSz = dbs.showIcons ~= false and baseFontSize or 0
        local gap = 3
        local isSide = IsSideAnchored()

        local fps = floor(GetFramerate())
        local _, _, home, world = GetNetStats()
        local lat = dbs.useWorldLatency and floor(world) or floor(home)
        local fpsStr = fps .. WB:GetFPSSuffix()
        local latStr = lat .. WB:GetMSSuffix()

        local fr, fg, fb, lr, lg, lb
        if self.mouseOver then
            fr, fg, fb = WB:GetAccent(); lr, lg, lb = fr, fg, fb
        else
            fr, fg, fb = GetFPSColor(fps); lr, lg, lb = GetLatColor(lat)
        end

        local fontSize = baseFontSize
        if isSide then
            local slotW = GetSlotWidth("system", 120)
            local innerW = max(36, slotW - 8)
            local textW = max(16, innerW - ((dbs.showIcons ~= false and iconSz > 0) and (iconSz + gap + 2) or 0))
            _sysFitBuf[1] = fpsStr; _sysFitBuf[2] = latStr
            fontSize = FitFontToLines(_sysFitBuf, baseFontSize, max(8, baseFontSize - 6), textW)
            iconSz = dbs.showIcons ~= false and fontSize or 0
        end

        WB:SetFont(self.fpsText, fontSize)
        WB:SetFont(self.pingText, fontSize)
        self.fpsText:SetText(fpsStr)
        self.pingText:SetText(latStr)
        self.fpsText:SetTextColor(fr, fg, fb, 1)
        self.pingText:SetTextColor(lr, lg, lb, 1)

        if dbs.showIcons ~= false and iconSz > 0 then
            self.fpsIcon:SetSize(iconSz, iconSz); self.fpsIcon:SetVertexColor(fr, fg, fb, 1); self.fpsIcon:Show()
            self.pingIcon:SetSize(iconSz, iconSz); self.pingIcon:SetVertexColor(lr, lg, lb, 1); self.pingIcon:Show()
        else
            self.fpsIcon:Hide(); self.pingIcon:Hide(); iconSz = 0
        end

        if InCombatLockdown() then return end

        if isSide then
            local slotW = GetSlotWidth("system", 120)
            local innerW = max(36, slotW - 8)
            local lineH = max(fontSize + 4, iconSz)
            local totalH = 8 + lineH + 2 + lineH + 4
            local textW = max(16, innerW - ((iconSz > 0) and (iconSz + gap + 2) or 0))

            self.fpsFrame:SetSize(innerW, lineH)
            self.pingFrame:SetSize(innerW, lineH)

            self.fpsFrame:ClearAllPoints()
            self.fpsFrame:SetPoint("TOP", self.systemFrame, "TOP", 0, -4)
            self.pingFrame:ClearAllPoints()
            self.pingFrame:SetPoint("TOP", self.fpsFrame, "BOTTOM", 0, -2)

            if iconSz > 0 then
                self.fpsIcon:ClearAllPoints(); self.fpsIcon:SetPoint("LEFT", self.fpsFrame, "LEFT", 0, 0)
                self.fpsText:ClearAllPoints(); self.fpsText:SetPoint("LEFT", self.fpsIcon, "RIGHT", gap, 0)
                SetWrappedText(self.fpsText, textW, "LEFT")
                self.pingIcon:ClearAllPoints(); self.pingIcon:SetPoint("LEFT", self.pingFrame, "LEFT", 0, 0)
                self.pingText:ClearAllPoints(); self.pingText:SetPoint("LEFT", self.pingIcon, "RIGHT", gap, 0)
                SetWrappedText(self.pingText, textW, "LEFT")
            else
                self.fpsText:ClearAllPoints(); self.fpsText:SetPoint("CENTER", self.fpsFrame, "CENTER", 0, 0)
                SetWrappedText(self.fpsText, innerW, "CENTER")
                self.pingText:ClearAllPoints(); self.pingText:SetPoint("CENTER", self.pingFrame, "CENTER", 0, 0)
                SetWrappedText(self.pingText, innerW, "CENTER")
            end

            self.systemFrame:SetSize(slotW, max(totalH, barH))
            self.systemFrame:ClearAllPoints()
            self.systemFrame:SetPoint("CENTER", self.slot, "CENTER", 0, 0)
        else
            local slotW = GetSlotWidth("system", 120)
            local spacing = 10
            local availablePerLine = max(18, floor((slotW - spacing) / 2))
            local textBudget = max(16, availablePerLine - ((iconSz > 0) and (iconSz + gap + 4) or 4))
            _sysFitBuf[1] = fpsStr; _sysFitBuf[2] = latStr
            fontSize = FitFontToLines(_sysFitBuf, fontSize, max(8, fontSize - 6), textBudget)
            if dbs.showIcons ~= false then
                iconSz = fontSize
                self.fpsIcon:SetSize(iconSz, iconSz)
                self.pingIcon:SetSize(iconSz, iconSz)
            end
            WB:SetFont(self.fpsText, fontSize)
            WB:SetFont(self.pingText, fontSize)
            self.fpsText:SetText(fpsStr)
            self.pingText:SetText(latStr)
            ResetInlineText(self.fpsText, "LEFT")
            ResetInlineText(self.pingText, "LEFT")
            self.fpsText:ClearAllPoints()
            self.fpsText:SetPoint("LEFT", self.fpsFrame, "LEFT", iconSz + gap, 0)
            self.pingText:ClearAllPoints()
            self.pingText:SetPoint("LEFT", self.pingFrame, "LEFT", iconSz + gap, 0)

            local fpsW  = min(availablePerLine, iconSz + gap + self.fpsText:GetStringWidth() + 4)
            local pingW = min(availablePerLine, iconSz + gap + self.pingText:GetStringWidth() + 4)
            self.fpsFrame:SetSize(fpsW, barH)
            self.pingFrame:SetSize(pingW, barH)

            local totalW = fpsW + pingW + spacing
            self.systemFrame:SetSize(min(slotW, totalW), barH)

            self.pingFrame:ClearAllPoints()
            self.pingFrame:SetPoint("RIGHT", self.systemFrame, "RIGHT", 0, 0)
            self.fpsFrame:ClearAllPoints()
            self.fpsFrame:SetPoint("RIGHT", self.pingFrame, "LEFT", -spacing, 0)
            self.systemFrame:ClearAllPoints()
            self.systemFrame:SetPoint("RIGHT", self.slot, "RIGHT", 0, 0)
        end
    end

    -- Memory scan (amortised across tooltip refreshes)
    local memTable = {}
    local function memSort(a, b) return a.mem > b.mem end
    local lastMemScanTime = 0

    local function ShowTooltip(self, skipMemoryScan)
        local ar, ag, ab = WB:GetAccent()
        WB:OpenTooltip(self.systemFrame, "ANCHOR_TOP")
        local fps = floor(GetFramerate())
        local _, _, home, world = GetNetStats()
        GameTooltip:AddDoubleLine(L["FPS"],   fps .. WB:GetFPSSuffix(), 0.6,0.6,0.6, GetFPSColor(fps))
        GameTooltip:AddDoubleLine(L["HOME"],  floor(home)  .. WB:GetMSSuffix(),  0.6,0.6,0.6, GetLatColor(home))
        GameTooltip:AddDoubleLine(L["WORLD"], floor(world) .. WB:GetMSSuffix(),  0.6,0.6,0.6, GetLatColor(world))

        local now = GetTime()
        if not skipMemoryScan and (now - lastMemScanTime) >= 5 then
            lastMemScanTime = now
            UpdateAddOnMemoryUsage()
            local count = 0
            for i = 1, C_AddOns.GetNumAddOns() do
                local _, name = C_AddOns.GetAddOnInfo(i)
                local mem = GetAddOnMemoryUsage(i)
                if mem > 0 then
                    count = count + 1
                    if not memTable[count] then memTable[count] = {} end
                    memTable[count].name = name
                    memTable[count].mem = mem
                end
            end
            for i = count + 1, #memTable do memTable[i] = nil end
            tsort(memTable, memSort)
        end

        if #memTable > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["MEMORY_USAGE"], ar, ag, ab)
            GameTooltip:AddLine(" ")
            for i = 1, min(10, #memTable) do
                local ms = memTable[i].mem > 1024 and format("%.2f MB", memTable[i].mem/1024) or format("%.0f KB", memTable[i].mem)
                GameTooltip:AddDoubleLine(memTable[i].name, ms, 1,1,1, ar,ag,ab)
            end
        end
        GameTooltip:AddLine(" ")
        WB:AddTooltipHint(L["LEFT_CLICK"], "Clean WonderBar state")
        GameTooltip:Show()
    end

    function M:OnCreate()
        local slot = WB:GetModuleSlot("system")
        self.slot = slot
        self.systemFrame = CreateFrame("Frame", "EllesmereUIWonderBarSystem", slot)
        self.systemFrame:SetSize(120, WB:GetBarHeight())
        self.systemFrame:SetPoint("RIGHT", slot, "RIGHT", 0, 0)

        self.fpsFrame = CreateFrame("Button", nil, self.systemFrame)
        self.fpsFrame:SetSize(50, WB:GetBarHeight()); self.fpsFrame:EnableMouse(true); self.fpsFrame:RegisterForClicks("AnyUp")
        self.fpsIcon = self.fpsFrame:CreateTexture(nil, "OVERLAY"); self.fpsIcon:SetTexture(FPS_TEX); self.fpsIcon:SetPoint("LEFT")
        self.fpsText = self.fpsFrame:CreateFontString(nil, "OVERLAY"); self.fpsText:SetPoint("LEFT")

        self.pingFrame = CreateFrame("Button", nil, self.systemFrame)
        self.pingFrame:SetSize(70, WB:GetBarHeight()); self.pingFrame:EnableMouse(true); self.pingFrame:RegisterForClicks("AnyUp")
        self.pingIcon = self.pingFrame:CreateTexture(nil, "OVERLAY"); self.pingIcon:SetTexture(PING_TEX); self.pingIcon:SetPoint("LEFT")
        self.pingText = self.pingFrame:CreateFontString(nil, "OVERLAY"); self.pingText:SetPoint("LEFT")

        self.mouseOver = false
        local function OnEnter() self.mouseOver = true; self:OnRefresh(); ShowTooltip(self) end
        local function OnLeave() self.mouseOver = false; GameTooltip:Hide(); self:OnRefresh() end
        local function OnClick(_, button)
            if button == "LeftButton" then
                local stats = WB:RunHousekeeping()
                UpdateAddOnMemoryUsage()
                self:OnRefresh()
                local memKb = collectgarbage("count")
                local msg = memKb > 1024 and format("%.2f MB", memKb/1024) or format("%.0f KB", memKb)
                print(format("|cff0cd29fWonderBar|r: Cleaned %d pooled frame(s), %d popup(s), %d heartbeat owner(s), %d orphan frame(s). Memory snapshot |cffffff00%s|r",
                    stats.pooledFramesReleased or 0,
                    stats.popupsHidden or 0,
                    stats.heartbeatOwnersRemoved or 0,
                    stats.orphanFramesHidden or 0,
                    msg))
                if self.mouseOver then ShowTooltip(self) end
            end
        end
        for _, f in ipairs({ self.fpsFrame, self.pingFrame }) do
            f:SetScript("OnEnter", OnEnter); f:SetScript("OnLeave", OnLeave); f:SetScript("OnClick", OnClick)
        end
    end

    function M:OnHeartbeat()
        if not (self.systemFrame and self.systemFrame:IsShown()) then return false end
        self:OnRefresh()
        if self.mouseOver then ShowTooltip(self, true) end
        return true
    end

    function M:OnEnable()
        self.systemFrame:Show()
        self:OnRefresh()
        StartHeartbeat(self, 1, function() return self:OnHeartbeat() end)
    end
    function M:OnDisable()
        StopHeartbeat(self, 1)
        if self.systemFrame then self.systemFrame:Hide() end
    end

    function M:GetContentWidth()
        if not self.systemFrame then return 120 end
        if IsSideAnchored() then
            return max(self.systemFrame:GetHeight() or 120, 60)
        end
        return max(self.systemFrame:GetWidth() or 120, 60)
    end

    WB:RegisterModule("system", M)
end

-- Module: GOLD (inc. cross-character tracking)
do
    local M = {
        events = { "PLAYER_MONEY", "BAG_UPDATE", "TOKEN_MARKET_PRICE_UPDATED" },
    }

    local sessionProfit, sessionSpent, lastMoney = 0, 0, nil
    local tokenPrice = nil
    local GOLD_TEX = MEDIA .. "gold.tga"
    local _goldFitBuf = { "", "" }

    local function CharKey()
        return (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Unknown")
    end

    local function GetCharStore()
        if not (WB.db and WB.db.profile) then return {} end
        WB.db.profile.characters = WB.db.profile.characters or {}
        return WB.db.profile.characters
    end

    local function SaveCurrentMoney(money)
        local store = GetCharStore()
        local _, class = UnitClass("player")
        store[CharKey()] = { currentMoney = money, class = class, realm = GetRealmName(), name = UnitName("player") }
    end

    local function GetFreeBagSlots()
        local free = 0
        for i = 0, 4 do
            local n = C_Container and C_Container.GetContainerNumFreeSlots(i)
            if n then free = free + n end
        end
        return free
    end

    local _sideLinesBuf = { "", "", "" }
    local _sideLineCount = 0
    local function GetMoneySideLines(amount, showSmall)
        amount = floor(abs(amount or 0))
        local gold   = floor(amount / 10000)
        local silver = floor((amount % 10000) / 100)
        local copper = amount % 100
        local gStr = BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or tostring(gold)
        _sideLinesBuf[1] = gStr .. L["GOLD_SUFFIX"]
        if showSmall ~= false then
            _sideLinesBuf[2] = silver .. L["SILVER_SUFFIX"]
            _sideLinesBuf[3] = copper .. L["COPPER_SUFFIX"]
            _sideLineCount = 3
        else
            _sideLinesBuf[2] = nil
            _sideLinesBuf[3] = nil
            _sideLineCount = 1
        end
        return _sideLinesBuf, _sideLineCount
    end

    local function UpdateMoney()
        local money = GetMoney()
        if lastMoney then
            local diff = money - lastMoney
            if diff > 0 then sessionProfit = sessionProfit + diff
            elseif diff < 0 then sessionSpent = sessionSpent + (-diff) end
        end
        lastMoney = money
        SaveCurrentMoney(money)
    end
    M._UpdateMoney = UpdateMoney  -- expose for tests/other callers

    function M:OnRefresh()
        if not self.goldFrame then return end
        local dg = DB("gold") or {}
        local fontSize = max(9, floor(WB:GetBarHeight() * 0.46 + 0.5))
        local iconSz = dg.showIcons ~= false and fontSize or 0
        local gap = 4
        local isSide = IsSideAnchored()
        local ar, ag, ab = WB:GetAccent()

        WB:SetFont(self.goldText, fontSize)
        WB:SetFont(self.bagText, fontSize)

        local money = GetMoney()
        if isSide then
            local slotW = GetSlotWidth("gold", 120)
            local innerW = max(30, slotW - 8)
            local lines, lineCount = GetMoneySideLines(money, dg.showSmall)
            local startSize = min(fontSize, max(10, floor(WB:GetBarHeight() * 0.52 + 0.5)))
            local goldFontSize = FitFontToLines(lines, startSize, max(8, startSize - 6), innerW)
            WB:SetFont(self.goldText, goldFontSize)
            self.goldText:SetText(tconcat(lines, "\n", 1, lineCount))
            local r, g, b
            if self.mouseOver then r, g, b = ar, ag, ab else r, g, b = 1, 1, 1 end
            self.goldText:SetTextColor(r, g, b, 1)
        elseif self.mouseOver then
            self.goldText:SetText(WB:FormatMoneyPlain(money, dg.showSmall))
            self.goldText:SetTextColor(ar, ag, ab, 1)
        else
            self.goldText:SetText(WB:FormatMoney(money, dg.useColors, dg.showSmall))
            self.goldText:SetTextColor(1, 1, 1, 1)
        end

        if dg.showBagSpace ~= false then
            self.bagText:SetText("(" .. GetFreeBagSlots() .. ")"); self.bagText:Show()
        else
            self.bagText:Hide()
        end

        local r, g, b
        if self.mouseOver then r, g, b = ar, ag, ab else r, g, b = 1, 1, 1 end
        self.bagText:SetTextColor(r, g, b, 1)

        if dg.showIcons ~= false and iconSz > 0 then
            self.goldIcon:SetSize(iconSz, iconSz)
            self.goldIcon:SetVertexColor(r, g, b, 1)
            self.goldIcon:Show()
        else
            self.goldIcon:Hide(); iconSz = 0
        end

        local barH = WB:GetBarHeight()
        if isSide then
            local slotW = GetSlotWidth("gold", 120)
            local innerW = max(30, slotW - 8)
            local totalH = 8

            if iconSz > 0 then
                self.goldIcon:ClearAllPoints()
                self.goldIcon:SetPoint("TOP", self.goldButton, "TOP", 0, -4)
                totalH = totalH + iconSz + 2
            end

            SetWrappedText(self.goldText, innerW, "CENTER")
            self.goldText:ClearAllPoints()
            if iconSz > 0 then
                self.goldText:SetPoint("TOP", self.goldIcon, "BOTTOM", 0, -2)
            else
                self.goldText:SetPoint("TOP", self.goldButton, "TOP", 0, -4)
            end
            totalH = totalH + WB:SnapToPixelGrid(self.goldText:GetStringHeight())

            if self.bagText:IsShown() then
                SetWrappedText(self.bagText, innerW, "CENTER")
                self.bagText:ClearAllPoints()
                self.bagText:SetPoint("TOP", self.goldText, "BOTTOM", 0, -2)
                totalH = totalH + 2 + WB:SnapToPixelGrid(self.bagText:GetStringHeight())
            end

            totalH = max(totalH, barH)
            self.goldButton:SetSize(slotW, totalH)
            self.goldFrame:SetSize(slotW, totalH)
            self.goldButton:ClearAllPoints(); self.goldButton:SetPoint("CENTER", self.goldFrame, "CENTER", 0, 0)
            self.goldFrame:ClearAllPoints(); self.goldFrame:SetPoint("CENTER", WB:GetModuleSlot("gold"), "CENTER", 0, 0)
        else
            local slotW = GetSlotWidth("gold", 100)
            local moneyText = self.mouseOver and WB:FormatMoneyPlain(money, dg.showSmall) or WB:FormatMoney(money, dg.useColors, dg.showSmall)
            local bagTextValue = dg.showBagSpace ~= false and ("(" .. GetFreeBagSlots() .. ")") or ""
            local textBudget = max(24, slotW - iconSz - (bagTextValue ~= "" and 26 or 8))
            _goldFitBuf[1] = moneyText; _goldFitBuf[2] = bagTextValue
            local fitSize = FitFontToLines(_goldFitBuf, fontSize, max(8, fontSize - 6), textBudget)
            WB:SetFont(self.goldText, fitSize)
            WB:SetFont(self.bagText, fitSize)
            self.goldText:SetText(moneyText)
            if bagTextValue ~= "" then self.bagText:SetText(bagTextValue) end
            ResetInlineText(self.goldText, "LEFT")
            ResetInlineText(self.bagText, "LEFT")
            iconSz = dg.showIcons ~= false and fitSize or 0
            self.goldIcon:SetSize(iconSz, iconSz)
            self.goldIcon:ClearAllPoints(); self.goldIcon:SetPoint("LEFT", self.goldButton, "LEFT", 0, 0)
            self.goldText:ClearAllPoints(); self.goldText:SetPoint("LEFT", self.goldButton, "LEFT", iconSz + gap, 0)
            local bagW = dg.showBagSpace ~= false and (self.bagText:GetStringWidth() + 4) or 0
            self.bagText:ClearAllPoints(); self.bagText:SetPoint("LEFT", self.goldText, "RIGHT", 4, 0)

            local textW = min(slotW, iconSz + gap + self.goldText:GetStringWidth() + bagW + 4)
            self.goldButton:SetSize(textW, barH)
            self.goldFrame:SetSize(textW, barH)
            self.goldButton:ClearAllPoints(); self.goldButton:SetPoint("CENTER", self.goldFrame, "CENTER", 0, 0)
            self.goldFrame:ClearAllPoints(); self.goldFrame:SetPoint("RIGHT", WB:GetModuleSlot("gold"), "RIGHT", 0, 0)
        end
    end

    function M:OnCreate()
        self.mouseOver = false
        self.goldFrame = CreateFrame("Frame", "EllesmereUIWonderBarGold", WB:GetModuleSlot("gold"))
        self.goldFrame:SetSize(120, WB:GetBarHeight())

        self.goldButton = CreateFrame("Button", nil, self.goldFrame)
        self.goldButton:SetSize(120, WB:GetBarHeight()); self.goldButton:SetPoint("CENTER")
        self.goldButton:EnableMouse(true); self.goldButton:RegisterForClicks("AnyUp")

        self.goldIcon = self.goldButton:CreateTexture(nil, "OVERLAY"); self.goldIcon:SetTexture(GOLD_TEX)
        self.goldText = self.goldButton:CreateFontString(nil, "OVERLAY")
        self.bagText  = self.goldButton:CreateFontString(nil, "OVERLAY")

        self.goldButton:SetScript("OnEnter", function()
            self.mouseOver = true; self:OnRefresh()
            local ar, ag, ab = WB:GetAccent()
            WB:OpenTooltip(self.goldButton, "ANCHOR_TOP")
            GameTooltip:AddLine(L["GOLD"], ar, ag, ab)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["SESSION"], 0.8, 0.8, 0.8)
            GameTooltip:AddDoubleLine(L["EARNED"], WB:FormatMoney(sessionProfit, true), 0.6,0.6,0.6, 0,1,0)
            GameTooltip:AddDoubleLine(L["SPENT"],  WB:FormatMoney(sessionSpent,  true), 0.6,0.6,0.6, 1,0.3,0.3)
            local net = sessionProfit - sessionSpent
            if net ~= 0 then
                GameTooltip:AddDoubleLine(net > 0 and L["PROFIT"] or L["DEFICIT"],
                    WB:FormatMoney(abs(net), true), 0.6,0.6,0.6,
                    net > 0 and 0 or 1, net > 0 and 1 or 0.3, 0.3)
            end
            local store = GetCharStore()
            local total, charList = 0, {}
            for _, data in pairs(store) do
                if data and data.currentMoney then tinsert(charList, data); total = total + data.currentMoney end
            end
            tsort(charList, function(a,b) return (a.currentMoney or 0) > (b.currentMoney or 0) end)
            if #charList > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(GetRealmName() or "?", 0.5, 0.78, 1)
                for _, char in ipairs(charList) do
                    local cr, cg, cb = 1, 1, 1
                    if char.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[char.class] then
                        local cc = RAID_CLASS_COLORS[char.class]; cr, cg, cb = cc.r, cc.g, cc.b
                    end
                    local label = char.name or "?"
                    if char.name == UnitName("player") then
                        label = label .. " |TInterface\\COMMON\\Indicator-Green:14|t"
                    end
                    GameTooltip:AddDoubleLine(label, WB:FormatMoney(char.currentMoney, true), cr,cg,cb, 1,1,1)
                end
            end
            local bankType = Enum and Enum.BankType and Enum.BankType.Account or 2
            if C_Bank and C_Bank.FetchDepositedMoney then
                local wb = C_Bank.FetchDepositedMoney(bankType)
                if wb and wb > 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddDoubleLine(L["WARBANK"], WB:FormatMoney(wb, true), 0.6,0.6,0.6, 1,1,1)
                    total = total + wb
                end
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(L["TOTAL"], WB:FormatMoney(total, true), ar,ag,ab, 1,1,1)
            if tokenPrice and tokenPrice > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(L["WOW_TOKEN"], WB:FormatMoney(tokenPrice, true), 0,0.8,1, 1,1,1)
            end
            GameTooltip:AddLine(" ")
            WB:AddTooltipHint(L["LEFT_CLICK"],       L["OPEN_BAGS"])
            WB:AddTooltipHint(L["RIGHT_CLICK"],      L["OPEN_CURRENCIES"])
            WB:AddTooltipHint(L["CTRL_RIGHT_CLICK"], L["RESET_SESSION"])
            GameTooltip:Show()
        end)
        self.goldButton:SetScript("OnLeave", function()
            self.mouseOver = false; GameTooltip:Hide(); self:OnRefresh()
        end)
        self.goldButton:SetScript("OnClick", function(_, button)
            if IsControlKeyDown() and button == "RightButton" then
                sessionProfit = 0; sessionSpent = 0; self:OnRefresh()
            elseif button == "RightButton" then
                if C_CurrencyInfo and C_CurrencyInfo.OpenCurrencyPanel then
                    C_CurrencyInfo.OpenCurrencyPanel()
                elseif ToggleCharacter then
                    ToggleCharacter("TokenFrame")
                end
            elseif button == "LeftButton" then
                ToggleAllBags()
            end
        end)
    end

    function M:OnEvent(event)
        if event == "TOKEN_MARKET_PRICE_UPDATED" then
            if C_WowTokenPublic and C_WowTokenPublic.GetCurrentMarketPrice then
                tokenPrice = C_WowTokenPublic.GetCurrentMarketPrice()
            end
            return
        end
        if event ~= "BAG_UPDATE" then UpdateMoney() end
        self:OnRefresh()
    end

    function M:OnEnable()
        lastMoney = GetMoney(); sessionProfit = 0; sessionSpent = 0
        SaveCurrentMoney(lastMoney)
        if C_WowTokenPublic and C_WowTokenPublic.UpdateMarketPrice then
            C_WowTokenPublic.UpdateMarketPrice()
        end
        self.goldFrame:Show()
    end
    function M:OnDisable()
        if self.goldFrame then self.goldFrame:Hide() end
    end

    function M:GetContentWidth()
        if not self.goldFrame then return 100 end
        if IsSideAnchored() then
            local barH = WB:GetBarHeight() or 30
            local fontSize = max(9, floor(barH * 0.46 + 0.5))
            local iconSz = fontSize
            local textH  = self.goldText and self.goldText:GetStringHeight() or fontSize
            local bagH   = (self.bagText and self.bagText:IsShown()) and (self.bagText:GetStringHeight() + 2) or 0
            return max(8 + iconSz + 2 + textH + bagH + 4, barH, 50)
        end
        return max(self.goldFrame:GetWidth() or 100, 40)
    end

    WB:RegisterModule("gold", M)
end

-- Module: DATABAR (XP / Reputation, based on XIV_Databar)
do
    local M = {
        events = { "PLAYER_XP_UPDATE", "UPDATE_FACTION", "PLAYER_ENTERING_WORLD" },
    }

    local mode = "rep"
    local BAR_TEX = MEDIA .. "rep.tga"
    local _dbFitBuf = { "" }

    local function DataDB() return DB("databar") or {} end

    local function UpdateMode()
        local d = DataDB()
        if d.mode == "xp"  then mode = "xp";  return end
        if d.mode == "rep" then mode = "rep"; return end
        local atMax = IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel()
        local xpOff = IsXPUserDisabled and IsXPUserDisabled()
        mode = (not atMax and not xpOff) and "xp" or "rep"
    end

    -- XIV compat: legacy GetWatchedFactionInfo vs C_Reputation.GetWatchedFactionData
    local LegacyGetWatchedFactionInfo = rawget(_G, "GetWatchedFactionInfo")
    local C_Rep = C_Reputation
    local function GetWatchedFactionInfoCompat()
        if LegacyGetWatchedFactionInfo then return LegacyGetWatchedFactionInfo() end
        if C_Rep and C_Rep.GetWatchedFactionData then
            local d = C_Rep.GetWatchedFactionData()
            if d then
                return d.name, d.reaction, d.currentReactionThreshold,
                       d.nextReactionThreshold, d.currentStanding, d.factionID
            end
        end
        return nil
    end

    local function GetProgressValues(cur, minV, maxV)
        minV = type(minV) == "number" and minV or 0
        maxV = type(maxV) == "number" and maxV or minV + 1
        cur  = type(cur)  == "number" and cur  or minV
        local pCur = cur - minV; local pMax = maxV - minV
        if pMax <= 0 then local n = pCur > 0 and pCur or 1; return n, n, 100 end
        return pCur, pMax, max(0, min(100, floor((pCur / pMax) * 100)))
    end

    function M:OnRefresh()
        if not self.databarFrame then return end
        UpdateMode()
        local barH = WB:GetBarHeight()
        local d = DataDB()
        local slot = WB:GetModuleSlot("databar")
        local slotW = max((slot and slot:GetWidth()) or d.width or 300, 60)
        local textHeight = max(9, floor(barH * 0.46 + 0.5))
        local iconSize = min(max(14, floor(barH * 0.72 + 0.5)), max(14, slotW - 20))
        local bH = max(3, iconSize - textHeight - 2)
        local barYOffset = max(0, floor((barH - iconSize) / 2))
        local ar, ag, ab = WB:GetAccent()

        self.databarFrame:SetSize(slotW, barH)
        self.databarFrame:ClearAllPoints()
        if slot then self.databarFrame:SetPoint("CENTER", slot, "CENTER", 0, 0) end
        self.icon:SetSize(iconSize, iconSize)
        self.icon:ClearAllPoints(); self.icon:SetPoint("LEFT", self.databarFrame, "LEFT", 0, 0)

        self.restBar:Hide()
        if mode == "xp" then
            local atMax = IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel()
            local curXP = not atMax and (UnitXP("player") or 0) or 0
            local maxXP = not atMax and (UnitXPMax("player") or 1) or 1
            if maxXP <= 0 then maxXP = 1 end
            local pct = floor((curXP / maxXP) * 100)
            local level = UnitLevel and UnitLevel("player") or 0
            local label = string.upper(LEVEL .. " " .. level .. " " .. UnitClass("player")) .. " " .. pct .. "%"
            local textBudget = max(40, slotW - iconSize - 8)
            _dbFitBuf[1] = label
            local fitSize = FitFontToLines(_dbFitBuf, textHeight, max(8, textHeight - 6), textBudget)
            WB:SetFont(self.nameText, fitSize)
            self.nameText:SetText(label)
            self.bar:SetStatusBarColor(ar, ag, ab, 1)
            self.bar:SetMinMaxValues(0, maxXP); self.bar:SetValue(curXP)
            local restedXP = GetXPExhaustion() or 0
            if restedXP > 0 and not atMax then
                self.restBar:SetMinMaxValues(0, maxXP)
                self.restBar:SetValue(min(curXP + restedXP, maxXP))
                self.restBar:Show()
            else self.restBar:Hide() end
            self.databarFrame:Show()
        else
            local name, reaction, minV, maxV, curV, factionID = GetWatchedFactionInfoCompat()
            if not name then self.databarFrame:Hide(); return end
            self.databarFrame:Show()
            -- Major Factions (renown progress)
            if factionID and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
                local mfd = C_MajorFactions.GetMajorFactionData(factionID)
                if mfd and type(mfd.renownLevelThreshold) == "number" and mfd.renownLevelThreshold > 0 then
                    minV = 0; maxV = mfd.renownLevelThreshold; curV = mfd.renownReputationEarned or 0
                end
            end
            -- Normalise
            if type(minV) == "number" and type(maxV) == "number" and type(curV) == "number" then
                local nMax = maxV - minV; local nCur = curV - minV
                if nMax > 0 then minV = 0; maxV = nMax; curV = nCur end
            end
            minV = type(minV) == "number" and minV or 0
            maxV = type(maxV) == "number" and maxV or 1
            curV = type(curV) == "number" and curV or 0
            if maxV <= minV then maxV = minV + 1 end
            curV = max(minV, min(maxV, curV))
            local _, _, pct = GetProgressValues(curV, minV, maxV)
            local dname = #name > 20 and name:sub(1,20) .. "..." or name
            local label = string.upper(dname) .. " " .. pct .. "%"
            local textBudget = max(40, slotW - iconSize - 8)
            _dbFitBuf[1] = label
            local fitSize = FitFontToLines(_dbFitBuf, textHeight, max(8, textHeight - 6), textBudget)
            WB:SetFont(self.nameText, fitSize)
            self.nameText:SetText(label)
            local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
            if color then self.bar:SetStatusBarColor(color.r, color.g, color.b, 1)
            else self.bar:SetStatusBarColor(ar, ag, ab, 1) end
            self.bar:SetMinMaxValues(minV, maxV); self.bar:SetValue(curV)
            self.restBar:Hide()
        end

        self.nameText:ClearAllPoints(); self.nameText:SetPoint("CENTER", self.databarFrame, "CENTER", 0, 0)
        local textW = slotW - iconSize - 5
        self.barTrack:ClearAllPoints()
        self.barTrack:SetPoint("BOTTOMLEFT", self.databarFrame, "BOTTOMLEFT", iconSize + 5, barYOffset)
        self.barTrack:SetSize(textW, bH)
        self.barTrack:SetColorTexture(ar * 0.2, ag * 0.2, ab * 0.2, 0.8)
        self.bar:ClearAllPoints(); self.bar:SetSize(textW, bH)
        self.bar:SetPoint("BOTTOMLEFT", self.databarFrame, "BOTTOMLEFT", iconSize + 5, barYOffset)
        self.restBar:ClearAllPoints(); self.restBar:SetAllPoints(self.bar)
    end

    function M:OnCreate()
        local slot = WB:GetModuleSlot("databar")
        self.databarFrame = CreateFrame("Frame", "EllesmereUIWonderBarDataBar", slot)
        self.databarFrame:SetSize(120, WB:GetBarHeight())

        self.barButton = CreateFrame("Button", nil, self.databarFrame)
        self.barButton:SetAllPoints(); self.barButton:EnableMouse(true); self.barButton:RegisterForClicks("AnyUp")
        self.barButton:SetScript("OnEnter", nil)
        self.barButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.barButton:SetScript("OnClick", function(_, btn)
            if btn == "RightButton" and not InCombatLockdown() then
                local d = DataDB(); d.mode = mode == "xp" and "rep" or "xp"; self:OnRefresh()
            end
        end)

        self.icon = self.databarFrame:CreateTexture(nil, "OVERLAY"); self.icon:SetTexture(BAR_TEX)
        self.nameText = self.databarFrame:CreateFontString(nil, "OVERLAY")
        self.bar = CreateFrame("StatusBar", nil, self.databarFrame)
        self.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        self.barTrack = self.databarFrame:CreateTexture(nil, "BACKGROUND")
        self.restBar = CreateFrame("StatusBar", nil, self.databarFrame)
        self.restBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        self.restBar:SetStatusBarColor(0.3, 0.3, 1, 0.5); self.restBar:Hide()
    end

    function M:OnEvent() self:OnRefresh() end
    function M:OnEnable()  self.databarFrame:Show() end
    function M:OnDisable() if self.databarFrame then self.databarFrame:Hide() end end

    function M:GetContentWidth()
        if IsSideAnchored() then
            local barH = WB:GetBarHeight() or 30
            return max(barH + 10, 50)
        end
        return max((DataDB().width or 300), 60)
    end

    WB:RegisterModule("databar", M)
end

-- Module: TRAVEL (Hearthstone + M+ teleports)
do
    local M = {
        events = { "HEARTHSTONE_BOUND", "PLAYER_ENTERING_WORLD", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED" },
    }

    local tooltipTickCount = 0
    local lastCoolingState = nil
    local HEARTH_TEX = MEDIA .. "hearth.tga"
    local _trvFitBuf1 = { "" }
    local _trvFitBuf2 = { "" }

    local HEARTHSTONE_IDS = {
        -- Midnight
        263933, 265100, 263489,
        -- The War Within
        257736, 246565, 245970, 228940, 212337, 209035, 208704, 210455,
        -- Dragonflight
        236687, 235016, 200630, 193588,
        -- Shadowlands
        190196, 190237, 188952, 184353, 182773, 180290, 183716, 172179,
        -- Seasonal / Holiday
        163045, 162973, 165669, 165670, 165802, 166746, 166747,
        -- Legacy / Misc
        6948, 64488, 28585, 93672, 142542, 142298, 168907, 54452, 556,
    }

    -- Midnight Season 1 M+ teleports
    local SEASON_TELEPORTS = {
        { spellIds = 393273,            dungeonId = 2366 },  -- Algeth'ar Academy
        { spellIds = 1254572,           dungeonId = 3085 },  -- Magisters' Terrace
        { spellIds = 1254559,           dungeonId = 3097 },  -- Maisara Caverns
        { spellIds = 1254563,           dungeonId = 3056 },  -- Nexus-Point Xenas
        { spellIds = 1254555,           dungeonId = 3113 },  -- Pit of Saron
        { spellIds = 1254551,           dungeonId = 3118 },  -- Seat of the Triumvirate
        { spellIds = {159898, 1254557}, dungeonId = 779  },  -- Skyreach
        { spellIds = 1254400,           dungeonId = 2739 },  -- Windrunner Spire
    }

    -- Pre-allocated buffers for tooltip building
    local _mythicLinesBuf = {}
    for i = 1, #SEASON_TELEPORTS do _mythicLinesBuf[i] = { name = "", cd = 0 } end
    local _mythicLineCount = 0

    local function IsUsable(id)
        if not id then return false end
        if PlayerHasToy(id) then return true end
        if IsPlayerSpell(id) then return true end
        return (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id) or 0) > 0
    end

    local function GetRemainingCooldown(id, isSpell)
        local startTime, duration
        if isSpell then
            local info = C_Spell.GetSpellCooldown(id)
            if info then startTime, duration = info.startTime, info.duration end
        else
            if C_Item and C_Item.GetItemCooldown then
                startTime, duration = C_Item.GetItemCooldown(id)
            elseif C_Container and C_Container.GetItemCooldown then
                startTime, duration = C_Container.GetItemCooldown(id)
            end
        end
        if type(startTime) == "number" and type(duration) == "number" and duration > 0 then
            return max(0, startTime + duration - GetTime())
        end
        return 0
    end

    local function GetPrimaryCooldown() return GetRemainingCooldown(6948, false) end

    local _hearthList = {}
    local _hearthListCount = 0
    local function GetAvailableHearthstones()
        _hearthListCount = 0
        for _, id in ipairs(HEARTHSTONE_IDS) do
            if IsUsable(id) then
                _hearthListCount = _hearthListCount + 1
                _hearthList[_hearthListCount] = id
            end
        end
        for i = _hearthListCount + 1, #_hearthList do _hearthList[i] = nil end
        return _hearthList
    end

    local function BuildMacro(id)
        if PlayerHasToy(id) then return "/use item:" .. id end
        if IsPlayerSpell(id) then
            local info = C_Spell.GetSpellInfo(id)
            if info and info.name then return "/cast " .. info.name end
        end
        return "/use item:" .. id
    end

    local function PickHearthstone(randomize)
        local list = GetAvailableHearthstones()
        if #list == 0 then return nil end
        if randomize then return list[mrandom(#list)] end
        for _, id in ipairs(list) do if id == 6948 then return id end end
        return list[1]
    end

    local function ResolveMythicId(idOrTable)
        if type(idOrTable) == "table" then
            for _, id in ipairs(idOrTable) do if IsPlayerSpell(id) then return id end end
            return nil
        end
        return IsPlayerSpell(idOrTable) and idOrTable or nil
    end

    function M:OnRefresh()
        if not self.travelFrame then return end
        local fontSize = max(9, floor(WB:GetBarHeight() * 0.46 + 0.5))
        local cooldownFont = max(9, floor(WB:GetBarHeight() * 0.46 + 0.5))
        local barH = WB:GetBarHeight()
        local isSide = IsSideAnchored()

        local location = GetBindLocation() or "?"
        if isSide then
            local slotW = GetSlotWidth("travel", 120)
            local innerW = max(30, slotW - 8)
            _trvFitBuf1[1] = location
            fontSize = FitFontToLines(_trvFitBuf1, fontSize, max(8, fontSize - 8), innerW)
            _trvFitBuf2[1] = "00:00:00"
            cooldownFont = FitFontToLines(_trvFitBuf2, cooldownFont, max(8, cooldownFont - 8), innerW)
        end

        WB:SetFont(self.hearthText, fontSize)
        WB:SetFont(self.cooldownText, cooldownFont)

        self.hearthText:SetText(location)

        local cd = GetPrimaryCooldown()
        if cd > 0 then
            local ar, ag, ab = WB:GetAccent()
            self.cooldownText:SetText(WB:FormatCooldown(cd) or L["READY"])
            self.cooldownText:SetTextColor(ar, ag, ab, 1); self.cooldownText:Show()
        else
            self.cooldownText:Hide()
        end

        if self.mouseOver then
            local ar, ag, ab = WB:GetAccent()
            self.hearthText:SetTextColor(ar, ag, ab, 1); self.hearthIcon:SetVertexColor(ar, ag, ab, 1)
        elseif cd > 0 then
            self.hearthText:SetTextColor(1, 0.3, 0.3, 1); self.hearthIcon:SetVertexColor(1, 0.3, 0.3, 1)
        else
            self.hearthText:SetTextColor(1, 1, 1, 1); self.hearthIcon:SetVertexColor(1, 1, 1, 1)
        end

        if InCombatLockdown() then return end

        local iconSz, gap = fontSize, 4
        if isSide then
            iconSz = min(iconSz, max(14, floor(WB:GetBarHeight() * 0.72 + 0.5)))
        end
        self.hearthIcon:ClearAllPoints()
        self.hearthIcon:SetSize(iconSz, iconSz)

        if isSide then
            local slotW = GetSlotWidth("travel", 120)
            local innerW = max(30, slotW - 8)
            local totalH = 8 + iconSz + 2

            self.travelFrame:SetWidth(slotW)
            self.hearthButton:SetWidth(slotW)
            self.hearthIcon:SetPoint("TOP", self.hearthButton, "TOP", 0, -4)

            SetWrappedText(self.hearthText, innerW, "CENTER")
            self.hearthText:ClearAllPoints()
            self.hearthText:SetPoint("TOP", self.hearthIcon, "BOTTOM", 0, -2)
            totalH = totalH + WB:SnapToPixelGrid(self.hearthText:GetStringHeight())

            if self.cooldownText:IsShown() then
                SetWrappedText(self.cooldownText, innerW, "CENTER")
                self.cooldownText:ClearAllPoints()
                self.cooldownText:SetPoint("TOP", self.hearthText, "BOTTOM", 0, -2)
                totalH = totalH + 2 + WB:SnapToPixelGrid(self.cooldownText:GetStringHeight())
            end

            totalH = max(totalH, barH)
            self.travelFrame:SetHeight(totalH)
            self.hearthButton:SetHeight(totalH)
            self.travelFrame:ClearAllPoints()
            self.travelFrame:SetPoint("CENTER", WB:GetModuleSlot("travel"), "CENTER", 0, 0)
        else
            local slotW = GetSlotWidth("travel", 120)
            local textBudget = max(30, slotW - iconSz - gap - 8)
            _trvFitBuf1[1] = location
            fontSize = FitFontToLines(_trvFitBuf1, fontSize, max(8, fontSize - 6), textBudget)
            _trvFitBuf2[1] = self.cooldownText:GetText() or "00:00:00"
            cooldownFont = FitFontToLines(_trvFitBuf2, cooldownFont, max(8, cooldownFont - 6), textBudget)
            WB:SetFont(self.hearthText, fontSize)
            WB:SetFont(self.cooldownText, cooldownFont)
            self.hearthText:SetText(location)
            iconSz = min(fontSize, max(14, floor(WB:GetBarHeight() * 0.72 + 0.5)))
            self.hearthIcon:SetSize(iconSz, iconSz)
            ResetInlineText(self.hearthText, "LEFT")
            ResetInlineText(self.cooldownText, "CENTER")
            local tw = WB:SnapToPixelGrid(self.hearthText:GetStringWidth())
            local totalW = min(slotW, iconSz + gap + tw + 4)
            self.travelFrame:SetSize(totalW, barH)
            self.hearthButton:SetSize(totalW, barH)
            self.hearthIcon:SetPoint("LEFT", self.hearthButton, "LEFT", 0, 0)
            self.hearthText:ClearAllPoints(); self.hearthText:SetPoint("LEFT", self.hearthButton, "LEFT", iconSz + gap, 0)
            self.cooldownText:ClearAllPoints(); self.cooldownText:SetPoint("CENTER", self.hearthText, "TOP", 0, 4)
            self.travelFrame:ClearAllPoints()
            self.travelFrame:SetPoint("RIGHT", WB:GetModuleSlot("travel"), "RIGHT", -6, 0)
        end
    end

    local function RefreshTravelTooltip(self)
        local ar, ag, ab = WB:GetAccent()
        WB:OpenTooltip(self.hearthButton, "ANCHOR_TOP")
        GameTooltip:AddLine("|cFFFFFFFF[|r" .. L["TRAVEL_COOLDOWNS"] .. "|cFFFFFFFF]|r", ar, ag, ab)
        GameTooltip:AddLine(" ")
        local cd2 = GetPrimaryCooldown()
        local cdStr = WB:FormatCooldown(cd2) or L["READY"]
        local ready = cd2 <= 0
        GameTooltip:AddDoubleLine(L["HEARTHSTONE"] .. " |cffffffff(" .. (GetBindLocation() or "?") .. ")|r",
                                  cdStr, ar,ag,ab,
                                  ready and 0 or 1, ready and 1 or 0, 0)

        -- Mythic+ teleports
        _mythicLineCount = 0
        for _, entry in ipairs(SEASON_TELEPORTS) do
            local spellId = ResolveMythicId(entry.spellIds)
            if spellId then
                local dName = entry.dungeonId and GetLFGDungeonInfo and GetLFGDungeonInfo(entry.dungeonId) or nil
                local spInfo = C_Spell.GetSpellInfo(spellId)
                local name2 = dName or (spInfo and spInfo.name) or tostring(spellId)
                _mythicLineCount = _mythicLineCount + 1
                _mythicLinesBuf[_mythicLineCount].name = name2
                _mythicLinesBuf[_mythicLineCount].cd   = GetRemainingCooldown(spellId, true)
            end
        end
        if _mythicLineCount > 0 then
            GameTooltip:AddLine(" "); GameTooltip:AddLine(L["MYTHIC_TELEPORTS"], ar, ag, ab)
            -- Insertion sort on active entries only (max ~8)
            for i = 2, _mythicLineCount do
                local j = i
                while j > 1 and _mythicLinesBuf[j].name < _mythicLinesBuf[j - 1].name do
                    _mythicLinesBuf[j].name, _mythicLinesBuf[j - 1].name = _mythicLinesBuf[j - 1].name, _mythicLinesBuf[j].name
                    _mythicLinesBuf[j].cd,   _mythicLinesBuf[j - 1].cd   = _mythicLinesBuf[j - 1].cd,   _mythicLinesBuf[j].cd
                    j = j - 1
                end
            end
            for i = 1, _mythicLineCount do
                local e = _mythicLinesBuf[i]
                local cs = WB:FormatCooldown(e.cd) or L["READY"]
                GameTooltip:AddDoubleLine(e.name, cs, 0.8,0.8,0.8, e.cd <= 0 and 0 or 1, e.cd <= 0 and 1 or 0, 0)
            end
        end
        GameTooltip:AddLine(" "); WB:AddTooltipHint(L["LEFT_CLICK"], L["USE_HEARTHSTONE"])
        GameTooltip:Show()
    end

    local function SeedTravelMacro(self)
        if not (self and self.hearthButton) or InCombatLockdown() then return end
        local dt = DB("travel") or {}
        local id = PickHearthstone(dt.randomizeHs)
        if id then self.hearthButton:SetAttribute("macrotext", BuildMacro(id)) end
    end

    function M:SyncTickerState()
        if not self.travelFrame then return end
        local cooling = GetPrimaryCooldown() > 0
        lastCoolingState = cooling
        if cooling or self.mouseOver then
            StartHeartbeat(self, 1, function() return self:OnHeartbeat() end)
        else
            StopHeartbeat(self, 1)
        end
    end

    function M:OnHeartbeat()
        if not (self.travelFrame and self.travelFrame:IsShown()) then return false end

        local cooling = GetPrimaryCooldown() > 0
        if cooling or cooling ~= lastCoolingState then
            self:OnRefresh()
        end
        lastCoolingState = cooling

        if self.mouseOver and GameTooltip:IsOwned(self.hearthButton) then
            tooltipTickCount = tooltipTickCount + 1
            if tooltipTickCount >= 5 then
                tooltipTickCount = 0
                RefreshTravelTooltip(self)
            end
        else
            tooltipTickCount = 0
        end

        if not cooling and not self.mouseOver then
            return false
        end
        return true
    end

    function M:OnCreate()
        self.mouseOver = false
        self.travelFrame = CreateFrame("Frame", "EllesmereUIWonderBarTravel", WB:GetModuleSlot("travel"))
        self.travelFrame:SetSize(120, WB:GetBarHeight())

        self.hearthButton = CreateFrame("Button", "EllesmereUIWonderBarHearthBtn", self.travelFrame, "SecureActionButtonTemplate")
        self.hearthButton:SetAllPoints(); self.hearthButton:EnableMouse(true); self.hearthButton:RegisterForClicks("AnyUp", "AnyDown")
        self.hearthButton:SetAttribute("type", "macro"); self.hearthButton:SetAttribute("macrotext", "")

        self.hearthIcon   = self.hearthButton:CreateTexture(nil, "OVERLAY"); self.hearthIcon:SetTexture(HEARTH_TEX)
        self.hearthText   = self.hearthButton:CreateFontString(nil, "OVERLAY")
        self.cooldownText = self.hearthButton:CreateFontString(nil, "OVERLAY"); self.cooldownText:Hide()

        self.hearthButton:SetScript("PreClick", function()
            if InCombatLockdown() then return end
            SeedTravelMacro(self)
        end)
        self.hearthButton:SetScript("PostClick", function()
            C_Timer.After(0.1, function()
                if self.travelFrame and self.travelFrame:IsShown() then
                    self:OnRefresh()
                    self:SyncTickerState()
                end
            end)
        end)

        self.hearthButton:SetScript("OnEnter", function()
            self.mouseOver = true
            tooltipTickCount = 0
            self:OnRefresh()
            RefreshTravelTooltip(self)
            self:SyncTickerState()
        end)
        self.hearthButton:SetScript("OnLeave", function()
            self.mouseOver = false
            tooltipTickCount = 0
            GameTooltip:Hide()
            self:OnRefresh()
            self:SyncTickerState()
        end)

        -- Seed macrotext shortly after enable so first-combat click works
        C_Timer.After(1, function() SeedTravelMacro(self) end)
    end

    function M:OnEvent(event)
        if event == "PLAYER_REGEN_ENABLED" then
            SeedTravelMacro(self)
        end
        self:OnRefresh()
        self:SyncTickerState()
    end
    function M:OnEnable()
        self.travelFrame:Show()
        tooltipTickCount = 0
        lastCoolingState = nil
        self:OnRefresh()
        SeedTravelMacro(self)
        self:SyncTickerState()
    end
    function M:OnDisable()
        StopHeartbeat(self, 1)
        tooltipTickCount = 0
        lastCoolingState = nil
        if self.travelFrame then
            self.travelFrame:Hide()
        end
    end

    function M:GetContentWidth()
        if not self.travelFrame then return 120 end
        if IsSideAnchored() then
            local barH = WB:GetBarHeight() or 30
            local fontSize = max(9, floor(barH * 0.46 + 0.5))
            local iconSz = fontSize
            local textH = self.hearthText and self.hearthText:GetStringHeight() or fontSize
            local cdH   = (self.cooldownText and self.cooldownText:IsShown()) and (self.cooldownText:GetStringHeight() + 4) or 0
            return max(8 + iconSz + 2 + textH + cdH + 4, barH, 50)
        end
        return max(self.travelFrame:GetWidth() or 120, 40)
    end

    WB:RegisterModule("travel", M)
end

-- Module: SPECSWITCH (specialisation, loot-spec, loadout popups)
do
    local M = {
        events = { "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_LOOT_SPEC_UPDATED",
                   "TRAIT_CONFIG_UPDATED", "PLAYER_ENTERING_WORLD" },
    }

    local SPEC_MEDIA = MEDIA .. "spec\\"
    local _specFitBuf1 = { "" }
    local _specFitBuf2 = { "" }
    local SPEC_COORDS = {
        [1] = {0.00, 0.25, 0, 1}, [2] = {0.25, 0.50, 0, 1},
        [3] = {0.50, 0.75, 0, 1}, [4] = {0.75, 1.00, 0, 1},
    }

    local specCache, numSpecs = {}, 0
    local currentSpecIdx, currentLootSpecID = nil, 0

    local specPool, lootPool, loadoutPool  -- popup frame pools (lazy)

    local function SSdb() return DB("specswitch") or {} end

    local function BuildSpecCache()
        specCache = {}; numSpecs = GetNumSpecializations() or 0
        for i = 1, numSpecs do
            local id, name, _, icon, role = GetSpecializationInfo(i)
            if id then specCache[i] = { id = id, name = name, icon = icon, role = role } end
        end
    end

    local function UpdateCurrentSpec()
        currentSpecIdx    = GetSpecialization()
        currentLootSpecID = GetLootSpecialization() or 0
    end

    local function GetCurrentLoadoutName()
        if not (C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID) then return nil end
        local specId = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID()
        if not specId then return nil end
        local configID = C_ClassTalents.GetLastSelectedSavedConfigID(specId)
        if not configID then return nil end
        local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID)
        return info and info.name or nil
    end

    local function GetLootSpecName()
        if currentLootSpecID == 0 then
            return currentSpecIdx and specCache[currentSpecIdx] and specCache[currentSpecIdx].name
        end
        local _, name = GetSpecializationInfoByID and GetSpecializationInfoByID(currentLootSpecID)
        return name
    end

    local function GetBarDisplayText()
        local d = SSdb()
        local loadoutName = d.showLoadout ~= false and GetCurrentLoadoutName()
        local text = loadoutName or (currentSpecIdx and specCache[currentSpecIdx] and specCache[currentSpecIdx].name) or ""
        return d.useUppercase ~= false and text:upper() or text
    end

    -- Generic popup builder (shared across the three popups)
    local function BuildPopup(pool, parent, title, entries, onClickEntry)
        if not pool then return nil end
        pool:ReleaseAll()
        local popup = pool._popup
        if not popup then
            popup = WB:CreatePopupFrame(parent)
            pool._popup = popup
        end
        popup._wbOnHide = function()
            pool:ReleaseAll()
            if pool._onHide then pool._onHide() end
        end
        popup:Show()

        local ar, ag, ab = WB:GetAccent()
        local fontSize = BarDB().fontSizeNormal or 14
        local iconSz = fontSize + 2
        local PAD, LINE = 6, 18

        if not popup._title then
            popup._title = popup:CreateFontString(nil, "OVERLAY")
            WB:SetFont(popup._title, fontSize)
            popup._title:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -PAD)
        end
        popup._title:SetText(title); popup._title:SetTextColor(ar, ag, ab, 1)

        local maxW = popup._title:GetStringWidth()
        local yOff = PAD + LINE + PAD

        for _, entry in ipairs(entries) do
            local btn = pool:Acquire()
            btn:SetParent(popup)
            btn:SetHeight(iconSz)
            btn:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -yOff)
            btn:EnableMouse(true); btn:RegisterForClicks("AnyUp")

            if not btn._icon then btn._icon = btn:CreateTexture(nil, "OVERLAY") end
            btn._icon:SetSize(iconSz, iconSz)
            btn._icon:ClearAllPoints()
            btn._icon:SetPoint("LEFT")

            if not btn._label then btn._label = btn:CreateFontString(nil, "OVERLAY") end
            btn._label:ClearAllPoints()
            btn._label:SetPoint("LEFT", btn._icon, "RIGHT", 4, 0)
            btn:Show()
            WB:SetFont(btn._label, fontSize)
            btn._label:SetText(entry.name)
            btn._label:Show()
            if entry.icon then
                btn._icon:SetTexture(entry.icon)
                btn._icon:SetTexCoord(4/64, 60/64, 4/64, 60/64)
                btn._icon:Show()
            else
                btn._icon:Hide()
            end

            if entry.isActive then btn._label:SetTextColor(ar, ag, ab, 1)
            else btn._label:SetTextColor(1, 1, 1, 1) end

            btn:SetScript("OnEnter", function() btn._label:SetTextColor(ar, ag, ab, 1) end)
            btn:SetScript("OnLeave", function()
                if entry.isActive then btn._label:SetTextColor(ar, ag, ab, 1)
                else btn._label:SetTextColor(1, 1, 1, 1) end
            end)
            btn:SetScript("OnClick", function(_, mb)
                if mb == "LeftButton" and not InCombatLockdown() then
                    onClickEntry(entry)
                    popup:Hide()
                end
            end)

            local bw = (btn._icon:IsShown() and iconSz + 4 or 0) + btn._label:GetStringWidth()
            if bw > maxW then maxW = bw end
            btn:SetWidth(bw)
            yOff = yOff + iconSz + 2
        end

        popup:SetSize(maxW + PAD * 2, yOff + PAD)
        popup:ClearAllPoints()
        if IsSideAnchored() then
            local pos = BarDB() and BarDB().position
            if pos == "RIGHT" then
                popup:SetPoint("RIGHT", parent, "LEFT", -4, 0)
            else
                popup:SetPoint("LEFT", parent, "RIGHT", 4, 0)
            end
        else
            popup:SetPoint("BOTTOM", parent, "TOP", 0, 4)
        end
        popup:SetClampedToScreen(true)
        if popup._wbClickCatcher then
            popup._wbClickCatcher:ClearAllPoints()
            popup._wbClickCatcher:SetAllPoints(UIParent)
        end
        return popup
    end

    function M:ToggleSpecPopup()
        if specPool and specPool._popup and specPool._popup:IsShown() then
            specPool._popup:Hide(); return
        end
        if not specPool then specPool = WB:CreateFramePool("Button", UIParent) end
        local entries = {}
        for i = 1, numSpecs do
            local info = specCache[i]
            if info then
                entries[#entries + 1] = { name = info.name, icon = info.icon, isActive = (i == currentSpecIdx), specIndex = i }
            end
        end
        BuildPopup(specPool, self.specButton, L["CHANGE_SPEC"], entries, function(e)
            C_SpecializationInfo.SetSpecialization(e.specIndex)
        end)
    end

    function M:ToggleLootSpecPopup()
        if lootPool and lootPool._popup and lootPool._popup:IsShown() then
            lootPool._popup:Hide(); return
        end
        if not lootPool then lootPool = WB:CreateFramePool("Button", UIParent) end
        local entries = {{
            name = L["CURRENT_SPEC"],
            icon = specCache[currentSpecIdx] and specCache[currentSpecIdx].icon,
            isActive = currentLootSpecID == 0,
            specIndex = 0,
        }}
        for i = 1, numSpecs do
            local info = specCache[i]
            if info then
                entries[#entries + 1] = { name = info.name, icon = info.icon, isActive = (info.id == currentLootSpecID), specIndex = i }
            end
        end
        BuildPopup(lootPool, self.specButton, L["CHANGE_LOOT_SPEC"], entries, function(e)
            local id = e.specIndex > 0 and select(1, GetSpecializationInfo(e.specIndex)) or 0
            SetLootSpecialization(id or 0)
        end)
    end

    function M:ToggleLoadoutPopup()
        if loadoutPool and loadoutPool._popup and loadoutPool._popup:IsShown() then
            loadoutPool._popup:Hide(); return
        end
        if not (C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID and C_Traits and C_Traits.GetConfigInfo) then return end
        if not loadoutPool then loadoutPool = WB:CreateFramePool("Button", UIParent) end

        local specId = currentSpecIdx and specCache[currentSpecIdx] and specCache[currentSpecIdx].id
        if not specId then return end
        local activeConfigID = C_ClassTalents.GetLastSelectedSavedConfigID and C_ClassTalents.GetLastSelectedSavedConfigID(specId)
        local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specId)
        local entries = {}
        for _, cid in ipairs(configIDs) do
            local info = C_Traits.GetConfigInfo(cid)
            if info and info.name then
                entries[#entries + 1] = { name = info.name, isActive = (cid == activeConfigID), configID = cid }
            end
        end
        BuildPopup(loadoutPool, self.specButton, L["CHANGE_LOADOUT"], entries, function(e)
            C_ClassTalents.LoadConfig(e.configID, true)
            C_ClassTalents.UpdateLastSelectedSavedConfigID(specId, e.configID)
            self:OnRefresh()
        end)
    end

    function M:OnRefresh()
        if not self.specFrame or InCombatLockdown() then return end
        UpdateCurrentSpec()
        local d = SSdb()
        local fontSize = max(9, floor(WB:GetBarHeight() * 0.46 + 0.5))
        local infoSz   = max(9, floor(WB:GetBarHeight() * 0.46 + 0.5))
        local gap, barH = 4, WB:GetBarHeight()
        local ar, ag, ab = WB:GetAccent()
        local isSide = IsSideAnchored()
        local specLabel = GetBarDisplayText()

        if isSide then
            local slotW = GetSlotWidth("specswitch", 120)
            local innerW = max(30, slotW - 8)
            _specFitBuf1[1] = specLabel
            fontSize = FitFontToLines(_specFitBuf1, fontSize, max(8, fontSize - 8), innerW)
            local lootNameForFit = GetLootSpecName()
            if lootNameForFit then
                _specFitBuf2[1] = d.useUppercase ~= false and lootNameForFit:upper() or lootNameForFit
                infoSz = FitFontToLines(_specFitBuf2, infoSz, max(8, infoSz - 8), innerW)
            end
        end
        local iconSz = fontSize + 2

        WB:SetFont(self.specText, fontSize); WB:SetFont(self.infoText, infoSz)
        self.specText:SetText(specLabel)

        if currentSpecIdx then
            local _, classId = UnitClass("player")
            local coords = SPEC_COORDS[currentSpecIdx]
            if classId and coords then
                self.specIcon:SetTexture(SPEC_MEDIA .. classId)
                self.specIcon:SetTexCoord(unpack(coords))
            end
        end

        if self.mouseOver then
            self.specText:SetTextColor(ar, ag, ab, 1); self.specIcon:SetVertexColor(ar, ag, ab, 1)
        else
            self.specText:SetTextColor(1, 1, 1, 1); self.specIcon:SetVertexColor(1, 1, 1, 1)
        end

        local lootName = GetLootSpecName()
        local activeSpecName = currentSpecIdx and specCache[currentSpecIdx] and specCache[currentSpecIdx].name
        if lootName and lootName ~= activeSpecName then
            self.infoText:SetText(d.useUppercase ~= false and lootName:upper() or lootName)
            self.infoText:SetTextColor(ar, ag, ab, 1); self.infoText:Show()
        else
            self.infoText:Hide()
        end

        if isSide then
            iconSz = min(iconSz, max(14, floor(WB:GetBarHeight() * 0.72 + 0.5)))
        end
        self.specIcon:SetSize(iconSz, iconSz)

        if isSide then
            local slotW = GetSlotWidth("specswitch", 120)
            local innerW = max(30, slotW - 8)
            local totalH = 8 + iconSz + 2

            self.specIcon:ClearAllPoints()
            self.specIcon:SetPoint("TOP", self.specFrame, "TOP", 0, -4)

            SetWrappedText(self.specText, innerW, "CENTER")
            self.specText:ClearAllPoints()
            self.specText:SetPoint("TOP", self.specIcon, "BOTTOM", 0, -2)
            totalH = totalH + WB:SnapToPixelGrid(self.specText:GetStringHeight())

            if self.infoText:IsShown() then
                SetWrappedText(self.infoText, innerW, "CENTER")
                self.infoText:ClearAllPoints()
                self.infoText:SetPoint("TOP", self.specText, "BOTTOM", 0, -2)
                totalH = totalH + 2 + WB:SnapToPixelGrid(self.infoText:GetStringHeight())
            end

            totalH = max(totalH, barH)
            self.specFrame:SetSize(slotW, totalH)
            self.specFrame:ClearAllPoints()
            self.specFrame:SetPoint("CENTER", WB:GetModuleSlot("specswitch"), "CENTER", 0, 0)
        else
            local slotW = GetSlotWidth("specswitch", 120)
            local textBudget = max(30, slotW - iconSz - gap - 8)
            _specFitBuf1[1] = specLabel
            fontSize = FitFontToLines(_specFitBuf1, fontSize, max(8, fontSize - 6), textBudget)
            WB:SetFont(self.specText, fontSize)
            self.specText:SetText(specLabel)
            if self.infoText:IsShown() then
                local infoLabel = self.infoText:GetText() or ""
                _specFitBuf2[1] = infoLabel
                infoSz = FitFontToLines(_specFitBuf2, infoSz, max(8, infoSz - 6), textBudget)
                WB:SetFont(self.infoText, infoSz)
            end
            iconSz = min(fontSize + 2, max(14, floor(WB:GetBarHeight() * 0.72 + 0.5)))
            self.specIcon:SetSize(iconSz, iconSz)
            ResetInlineText(self.specText, "LEFT")
            ResetInlineText(self.infoText, "CENTER")
            local tw = WB:SnapToPixelGrid(self.specText:GetStringWidth())
            local totalW = min(slotW, iconSz + gap + tw + 4)
            self.specIcon:ClearAllPoints(); self.specIcon:SetPoint("LEFT", self.specFrame, "LEFT", 0, 0)
            self.specText:ClearAllPoints(); self.specText:SetPoint("LEFT", self.specFrame, "LEFT", iconSz + gap, 0)
            self.infoText:ClearAllPoints(); self.infoText:SetPoint("BOTTOM", self.specText, "TOP", 0, 2)
            self.specFrame:SetSize(totalW, barH)
            self.specFrame:ClearAllPoints(); self.specFrame:SetPoint("RIGHT", WB:GetModuleSlot("specswitch"), "RIGHT", 0, 0)
        end
        self.specButton:ClearAllPoints(); self.specButton:SetAllPoints(self.specFrame)
    end

    function M:OnCreate()
        self.mouseOver = false
        self.specFrame = CreateFrame("Frame", "EllesmereUIWonderBarSpecSwitch", WB:GetModuleSlot("specswitch"))
        self.specFrame:SetSize(120, WB:GetBarHeight())

        self.specButton = CreateFrame("Button", nil, self.specFrame)
        self.specButton:SetAllPoints(); self.specButton:EnableMouse(true); self.specButton:RegisterForClicks("AnyUp")

        self.specIcon = self.specFrame:CreateTexture(nil, "OVERLAY"); self.specIcon:SetSize(16, 16)
        self.specText = self.specFrame:CreateFontString(nil, "OVERLAY")
        self.infoText = self.specFrame:CreateFontString(nil, "OVERLAY"); self.infoText:Hide()

        self.specButton:SetScript("OnEnter", function() self.mouseOver = true;  self:OnRefresh() end)
        self.specButton:SetScript("OnLeave", function() self.mouseOver = false; GameTooltip:Hide(); self:OnRefresh() end)
        self.specButton:SetScript("OnClick", function(_, button)
            if InCombatLockdown() then return end
            GameTooltip:Hide()
            local function HideOthers(keepName)
                if keepName ~= "spec"    and specPool    and specPool._popup    and specPool._popup:IsShown()    then specPool._popup:Hide()    end
                if keepName ~= "loot"    and lootPool    and lootPool._popup    and lootPool._popup:IsShown()    then lootPool._popup:Hide()    end
                if keepName ~= "loadout" and loadoutPool and loadoutPool._popup and loadoutPool._popup:IsShown() then loadoutPool._popup:Hide() end
            end
            if button == "LeftButton" then
                if IsControlKeyDown() then
                    if loadoutPool and loadoutPool._popup and loadoutPool._popup:IsShown() then loadoutPool._popup:Hide(); return end
                    HideOthers(); self:ToggleLoadoutPopup()
                elseif IsShiftKeyDown() then
                    HideOthers()
                    if PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentFrame then PlayerSpellsUtil.ToggleClassTalentFrame()
                    elseif ToggleTalentFrame then ToggleTalentFrame() end
                else
                    if specPool and specPool._popup and specPool._popup:IsShown() then specPool._popup:Hide(); return end
                    HideOthers(); self:ToggleSpecPopup()
                end
            elseif button == "RightButton" then
                if lootPool and lootPool._popup and lootPool._popup:IsShown() then lootPool._popup:Hide(); return end
                HideOthers(); self:ToggleLootSpecPopup()
            end
        end)
    end

    function M:OnEvent()
        if not InCombatLockdown() then self:OnRefresh() end
    end

    function M:OnEnable()
        BuildSpecCache(); UpdateCurrentSpec()
        self.specFrame:Show()
    end
    function M:OnDisable()
        if specPool    and specPool._popup    then specPool._popup:Hide()    end
        if lootPool    and lootPool._popup    then lootPool._popup:Hide()    end
        if loadoutPool and loadoutPool._popup then loadoutPool._popup:Hide() end
        if self.specFrame then self.specFrame:Hide() end
    end

    function M:GetContentWidth()
        if not self.specFrame then return 120 end
        if IsSideAnchored() then
            local barH = WB:GetBarHeight() or 30
            local fontSize = max(9, floor(barH * 0.46 + 0.5))
            local iconSz = min(fontSize + 2, max(14, floor(barH * 0.72 + 0.5)))
            local textH  = self.specText and self.specText:GetStringHeight() or fontSize
            local infoH  = (self.infoText and self.infoText:IsShown()) and (self.infoText:GetStringHeight() + 2) or 0
            return max(8 + iconSz + 2 + textH + infoH + 4, barH, 60)
        end
        return max(self.specFrame:GetWidth() or 120, 40)
    end

    WB:RegisterModule("specswitch", M)
end

-- Module: PROFESSION
do
    local M = {
        events = { "TRADE_SKILL_DETAILS_UPDATE", "SPELLS_CHANGED" },
    }

    local MEDIA_PROF = MEDIA .. "profession\\"
    local profIcons = {
        [164]="blacksmithing", [165]="leatherworking", [171]="alchemy", [182]="herbalism",
        [186]="mining",        [202]="engineering",    [333]="enchanting", [755]="jewelcrafting",
        [773]="inscription",   [197]="tailoring",      [393]="skinning",  [185]="cooking",
    }
    local prof1, prof2 = {}, {}

    local function UpdateProfValues()
        local p1, p2 = GetProfessions()
        prof1 = {}; prof2 = {}
        if p1 then
            local name, icon, rank, maxRank, _, _, id = GetProfessionInfo(p1)
            name = name or ""
            prof1 = { idx=p1, name=name, nameUpper=name:upper(), icon=icon, rank=rank or 0, maxRank=maxRank or 0, id=id }
        end
        if p2 then
            local name, icon, rank, maxRank, _, _, id = GetProfessionInfo(p2)
            name = name or ""
            prof2 = { idx=p2, name=name, nameUpper=name:upper(), icon=icon, rank=rank or 0, maxRank=maxRank or 0, id=id }
        end
    end

    local function StyleProfFrame(profData, profFrame, profIcon, profText, profBar, profBarBg)
        if not profData or not profData.idx then profFrame:Hide(); return end
        local barH = WB:GetBarHeight()
        local fontSize = max(9, floor(barH * 0.46 + 0.5))
        local iconSize = fontSize + 4
        local isSide = IsSideAnchored()

        local iconTex = profIcons[profData.id] and (MEDIA_PROF .. profIcons[profData.id]) or profData.icon
        profIcon:SetTexture(iconTex); profIcon:SetSize(iconSize, iconSize); profIcon:Show()

        WB:SetFont(profText, floor((barH - 4) / 2))
        profText:SetTextColor(1, 1, 1, 1); profText:SetText(profData.nameUpper or "")

        if isSide then
            local frameW = GetSlotWidth("profession", 120)
            local innerW = max(30, frameW - 8)
            local totalH = 8 + iconSize + 2

            profIcon:ClearAllPoints()
            profIcon:SetPoint("TOP", profFrame, "TOP", 0, -4)

            SetWrappedText(profText, innerW, "CENTER")
            profText:ClearAllPoints()
            profText:SetPoint("TOP", profIcon, "BOTTOM", 0, -2)
            totalH = totalH + WB:SnapToPixelGrid(profText:GetStringHeight())

            if profData.rank ~= profData.maxRank then
                local ar, ag, ab = WB:GetAccent()
                local bH = 4
                profBar:Show()
                profBar:SetMinMaxValues(1, profData.maxRank); profBar:SetValue(profData.rank)
                profBar:SetStatusBarColor(ar, ag, ab, 1); profBarBg:SetColorTexture(0.15, 0.15, 0.15, 0.6)
                profBar:SetSize(innerW, bH)
                profBar:ClearAllPoints()
                profBar:SetPoint("TOP", profText, "BOTTOM", 0, -3)
                totalH = totalH + 3 + bH
            else
                profBar:Hide()
            end

            profFrame:SetSize(frameW, max(totalH, barH))
            profFrame:Show()
        else
            ResetInlineText(profText, "LEFT")
            profIcon:ClearAllPoints(); profIcon:SetPoint("LEFT", profFrame, "LEFT", 0, 0)

            if profData.rank == profData.maxRank then
                profBar:Hide()
                profText:ClearAllPoints(); profText:SetPoint("LEFT", profIcon, "RIGHT", 5, 0)
            else
                profBar:Show()
                profText:ClearAllPoints(); profText:SetPoint("TOPLEFT", profIcon, "TOPRIGHT", 5, 0)
                local ar, ag, ab = WB:GetAccent()
                profBar:SetMinMaxValues(1, profData.maxRank); profBar:SetValue(profData.rank)
                profBar:SetStatusBarColor(ar, ag, ab, 1); profBarBg:SetColorTexture(0.15, 0.15, 0.15, 0.6)
                local textW = max(profText:GetStringWidth(), 20)
                local bH = max(3, iconSize - floor((barH - 4) / 2) - 2)
                profBar:SetSize(textW, bH)
                profBar:ClearAllPoints()
                profBar:SetPoint("BOTTOMLEFT", profFrame, "BOTTOMLEFT", iconSize + 5, max(0, floor((barH - iconSize) / 2)))
            end
            local textW = max(profText:GetStringWidth(), 20)
            profFrame:SetSize(iconSize + textW + 5, barH); profFrame:Show()
        end
    end

    function M:OnRefresh()
        if not self.profFrame or InCombatLockdown() then return end
        UpdateProfValues()
        local barH, gap = WB:GetBarHeight(), 5
        local isSide = IsSideAnchored()

        self.profFrame:ClearAllPoints()
        if isSide then
            self.profFrame:SetPoint("CENTER", WB:GetModuleSlot("profession"), "CENTER", 0, 0)
        else
            self.profFrame:SetHeight(barH)
            self.profFrame:SetPoint("LEFT", WB:GetModuleSlot("profession"), "LEFT", 0, 0)
        end

        StyleProfFrame(prof1, self.prof1Frame, self.prof1Icon, self.prof1Text, self.prof1Bar, self.prof1BarBg)
        StyleProfFrame(prof2, self.prof2Frame, self.prof2Icon, self.prof2Text, self.prof2Bar, self.prof2BarBg)

        if isSide then
            local slotW = GetSlotWidth("profession", 120)
            local totalH = 0
            if prof1.idx and self.prof1Frame:IsShown() then
                self.prof1Frame:ClearAllPoints()
                self.prof1Frame:SetPoint("TOP", self.profFrame, "TOP", 0, 0)
                totalH = totalH + self.prof1Frame:GetHeight()
            end
            if prof2.idx and self.prof2Frame:IsShown() then
                self.prof2Frame:ClearAllPoints()
                if prof1.idx and self.prof1Frame:IsShown() then
                    self.prof2Frame:SetPoint("TOP", self.prof1Frame, "BOTTOM", 0, -4)
                    totalH = totalH + 4
                else
                    self.prof2Frame:SetPoint("TOP", self.profFrame, "TOP", 0, 0)
                end
                totalH = totalH + self.prof2Frame:GetHeight()
            end
            self.profFrame:SetSize(slotW, max(totalH, 1))
        else
            if prof1.idx and self.prof1Frame:IsShown() then
                self.prof1Frame:ClearAllPoints(); self.prof1Frame:SetPoint("LEFT", self.profFrame, "LEFT", 0, 0)
            end
            if prof2.idx and self.prof2Frame:IsShown() then
                self.prof2Frame:ClearAllPoints()
                if prof1.idx and self.prof1Frame:IsShown() then
                    self.prof2Frame:SetPoint("LEFT", self.prof1Frame, "RIGHT", gap, 0)
                else
                    self.prof2Frame:SetPoint("LEFT", self.profFrame, "LEFT", 0, 0)
                end
            end

            local totalW = 0
            if prof1.idx and self.prof1Frame:IsShown() then totalW = totalW + self.prof1Frame:GetWidth() end
            if prof2.idx and self.prof2Frame:IsShown() then totalW = totalW + gap + self.prof2Frame:GetWidth() end
            self.profFrame:SetWidth(max(totalW, 1))
        end
        if not prof1.idx and not prof2.idx then self.profFrame:Hide() else self.profFrame:Show() end
    end

    function M:OnCreate()
        self.profFrame = CreateFrame("Frame", "EllesmereUIWonderBarProf", WB:GetModuleSlot("profession"))
        self.profFrame:SetSize(1, WB:GetBarHeight())

        local function MakeProfFrame(name)
            local f = CreateFrame("Button", name, self.profFrame, "SecureActionButtonTemplate")
            f:SetSize(1, WB:GetBarHeight()); f:EnableMouse(true); f:RegisterForClicks("AnyUp")
            if _G.ProfessionMicroButton then
                f:SetAttribute("*type2", "click")
                f:SetAttribute("*clickbutton2", _G.ProfessionMicroButton)
            end
            local icon = f:CreateTexture(nil, "OVERLAY")
            local text = f:CreateFontString(nil, "OVERLAY")
            local bar  = CreateFrame("StatusBar", nil, f); bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            local bg   = bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
            return f, icon, text, bar, bg
        end

        self.prof1Frame, self.prof1Icon, self.prof1Text, self.prof1Bar, self.prof1BarBg = MakeProfFrame("EllesmereUIWonderBarProf1")
        self.prof2Frame, self.prof2Icon, self.prof2Text, self.prof2Bar, self.prof2BarBg = MakeProfFrame("EllesmereUIWonderBarProf2")

        local function OpenProf(prof)
            if not prof or not prof.id or InCombatLockdown() then return end
            local currInfo = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
            if currInfo and currInfo.professionID == prof.id and _G.ProfessionsFrame and _G.ProfessionsFrame:IsShown() then
                C_TradeSkillUI.CloseTradeSkill()
            elseif prof.id then
                C_TradeSkillUI.OpenTradeSkill(prof.id)
            end
        end

        for i, frame in ipairs({ self.prof1Frame, self.prof2Frame }) do
            local isFirst = (i == 1)
            frame:SetScript("OnClick", function(_, button)
                if button == "LeftButton" then OpenProf(isFirst and prof1 or prof2) end
            end)
            frame:SetScript("OnEnter", function(f)
                local txt = isFirst and self.prof1Text or self.prof2Text
                local ar, ag, ab = WB:GetAccent(); txt:SetTextColor(ar, ag, ab, 1)
                WB:OpenTooltip(f, "ANCHOR_TOP")
                GameTooltip:AddLine(TRADE_SKILLS or "Professions", ar, ag, ab)
                GameTooltip:AddLine(" ")
                local function AddLine(p)
                    if not p or not p.name then return end
                    GameTooltip:AddDoubleLine(p.name, "|cffFFFFFF"..p.rank.."|r / "..p.maxRank, 1,1,1, ar,ag,ab)
                end
                if prof1.idx then AddLine(prof1) end
                if prof2.idx then AddLine(prof2) end
                GameTooltip:AddLine(" ")
                WB:AddTooltipHint(L["LEFT_CLICK"],  L["OPEN_PROFESSION"])
                WB:AddTooltipHint(L["RIGHT_CLICK"], L["OPEN_PROFESSION_BOOK"])
                GameTooltip:Show()
            end)
            frame:SetScript("OnLeave", function()
                local txt = isFirst and self.prof1Text or self.prof2Text
                txt:SetTextColor(1, 1, 1, 1)
                GameTooltip:Hide()
            end)
        end
    end

    function M:OnEvent() self:OnRefresh() end
    function M:OnEnable()  self.profFrame:Show() end
    function M:OnDisable() if self.profFrame then self.profFrame:Hide() end end

    function M:GetContentWidth()
        if not self.profFrame then return 80 end
        if IsSideAnchored() then
            local barH = WB:GetBarHeight() or 30
            local p1H  = (self.prof1Frame and self.prof1Frame:IsShown()) and self.prof1Frame:GetHeight() or 0
            local p2H  = (self.prof2Frame and self.prof2Frame:IsShown()) and self.prof2Frame:GetHeight() or 0
            local gap  = (p1H > 0 and p2H > 0) and 5 or 0
            return max(p1H + gap + p2H, barH, 50)
        end
        return max(self.profFrame:GetWidth() or 80, 30)
    end

    WB:RegisterModule("profession", M)
end

-- Module: MICROMENU (icon size scales with bar height; combat-gated changes via DeferUntilOOC)
do
    local M = {
        events = {
            "GUILD_ROSTER_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
            "FRIENDLIST_UPDATE",
            "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD",
        },
    }

    local SPACING = 2
    local MM_MEDIA = MEDIA .. "microbar\\"

    M.frames   = {}
    M.icons    = {}
    M.text     = {}
    M.bgTexture = {}
    M.functions = {}
    M.buttonOrder = {}
    M.buttonDefs  = {}
    M.mmFrame = nil

    local buttonDefs = {
        { key='menu',    binding='TOGGLEGAMEMENU',    label=MAINMENU_BUTTON,                   special=true },
        { key='guild',   binding='TOGGLEGUILD',       label=GUILD,                             micro=GuildMicroButton,     info=true },
        { key='social',  binding='TOGGLESOCIAL',      label=SOCIAL_LABEL or SOCIAL_BUTTON,     micro=QuickJoinToastButton, info=true },
        { key='char',    binding='TOGGLECHARACTER0',  label=CHARACTER_BUTTON,                  micro=CharacterMicroButton },
        { key='spell',   binding='TOGGLESPELLBOOK',   label=SPELLBOOK_ABILITIES_BUTTON or 'Spellbook', special=true },
        { key='talent',  binding='TOGGLETALENTS',     label=TALENTS_BUTTON,                    special=true },
        { key='ach',     binding='TOGGLEACHIEVEMENT', label=ACHIEVEMENTS,                      micro=AchievementMicroButton },
        { key='quest',   binding='TOGGLEQUESTLOG',    label=QUEST_LOG,                         micro=QuestLogMicroButton },
        { key='lfg',     binding='TOGGLEGROUPFINDER', label=DUNGEONS_BUTTON,                   micro=LFDMicroButton },
        { key='pvp',     binding='TOGGLECHARACTER4',  label=PLAYER_V_PLAYER or PVP_OPTIONS or 'PvP', special=true },
        { key='housing', binding='TOGGLEHOUSINGDASHBOARD', label=HOUSING_MICRO_BUTTON or 'Housing', micro=HousingMicroButton },
        { key='journal', binding='TOGGLEENCOUNTERJOURNAL', label=ADVENTURE_JOURNAL,             special=true },
        { key='pet',     binding='TOGGLECOLLECTIONS', label=COLLECTIONS,                       micro=CollectionsMicroButton },
        { key='shop',    binding=false,                label=BLIZZARD_STORE,                   micro=StoreMicroButton },
        { key='help',    binding=false,                label=HELP_BUTTON,                      micro=HelpMicroButton },
    }
    for _, def in ipairs(buttonDefs) do
        M.buttonOrder[#M.buttonOrder + 1] = def.key
        M.buttonDefs[def.key] = def
    end

    function M:GetIconSize()
        local barH = WB:GetBarHeight()
        local scaled = floor(barH * 0.82 + 0.5)
        return max(16, min(barH - 4, scaled))
    end

    function M:ToggleBlizzardMicroMenu(force)
        local mm = DB("micromenu") or {}
        local hide = mm.disableBlizzardMicroMenu
        if force ~= nil then hide = force end
        WB:DeferUntilOOC("mm_blizz", function()
            for _, frame in ipairs({ _G.MicroMenuContainer, _G.MainMenuBarMicroButtons, _G.MicroButtonAndBagsBar }) do
                if frame then if hide then frame:Hide() else frame:Show() end end
            end
        end)
    end

    local function TryClickFrame(frame)
        if not frame then return false end
        if frame.Click then
            local ok = pcall(frame.Click, frame)
            if ok then return true end
        end
        return false
    end

    local function ShowPVEFrameTab(tabIndex)
        if _G.LFDMicroButton and TryClickFrame(_G.LFDMicroButton) then
            if _G.PVEFrame and tabIndex and _G.PVEFrameTab1 then
                C_Timer.After(0, function()
                    if _G.PVEFrame and _G.PVEFrame:IsShown() and PanelTemplates_SetTab then
                        PanelTemplates_SetTab(_G.PVEFrame, tabIndex)
                        if _G.PVEFrame_ShowFrame and tabIndex == 1 then
                            _G.PVEFrame_ShowFrame("GroupFinderFrame")
                        end
                    end
                end)
            end
            return true
        end
        return false
    end

    function M:HandleGenericButtonClick(name, button)
        if button ~= "LeftButton" then return end
        local mm = DB("micromenu") or {}
        if InCombatLockdown() and not mm.combatEn then return end

        local def = self.buttonDefs[name]
        if not def then return end

        if name == 'quest' then
            if _G.QuestLogMicroButton and TryClickFrame(_G.QuestLogMicroButton) then return end
        elseif name == 'lfg' then
            if ShowPVEFrameTab(1) then return end
        elseif name == 'help' then
            if _G.HelpMicroButton and TryClickFrame(_G.HelpMicroButton) then return end
        elseif name == 'shop' then
            -- The shop firing ADDON_ACTION_FORBIDDEN is an unavoidable side
            -- effect of Blizzard's protected EventStoreUISetShown path: any
            -- addon-initiated call chain that reaches that path is flagged,
            -- regardless of how we dispatch the click. The shop still opens
            -- successfully; the error is cosmetic.
            --
            -- We considered (a) SecureActionButton with clickbutton forward
            -- and (b) /click macro — both still end up calling :Click()
            -- programmatically inside addon stacks, so both still trip the
            -- forbidden check. Users who don't want the noise can filter
            -- "EllesmereUIWonderBar.*UNKNOWN" in BugSack.
            if _G.ToggleStoreUI then ToggleStoreUI() end
            return
        elseif name == 'pet' then
            if _G.CollectionsMicroButton and TryClickFrame(_G.CollectionsMicroButton) then return end
        elseif name == 'ach' then
            if _G.AchievementMicroButton and TryClickFrame(_G.AchievementMicroButton) then return end
        elseif name == 'char' then
            if _G.CharacterMicroButton and TryClickFrame(_G.CharacterMicroButton) then return end
        elseif name == 'guild' then
            if _G.GuildMicroButton and TryClickFrame(_G.GuildMicroButton) then return end
        elseif name == 'social' then
            if _G.QuickJoinToastButton and TryClickFrame(_G.QuickJoinToastButton) then return end
        elseif name == 'housing' then
            if _G.HousingMicroButton and TryClickFrame(_G.HousingMicroButton) then return end
        end

        local micro = def.micro
        if not micro and name == 'housing' then micro = _G.HousingMicroButton end
        if micro and TryClickFrame(micro) then return end
    end

    function M:CreateClickFunctions()
        if self.functions.menu then return end
        self.functions.menu = function(_, button)
            if InCombatLockdown() and not (DB("micromenu") or {}).combatEn then return end
            if button == "LeftButton" and not InCombatLockdown() then
                ToggleFrame(GameMenuFrame)
            elseif button == "RightButton" then
                if IsShiftKeyDown() then C_UI.Reload()
                elseif not InCombatLockdown() then ToggleFrame(AddonList) end
            end
        end
        self.functions.spell = function(_, button)
            if InCombatLockdown() or button ~= "LeftButton" then return end
            if PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then
                PlayerSpellsUtil.ToggleSpellBookFrame()
            elseif _G.SpellBookFrame then ToggleFrame(_G.SpellBookFrame) end
        end
        self.functions.talent = function(_, button)
            if InCombatLockdown() or button ~= "LeftButton" then return end
            if PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentFrame then
                PlayerSpellsUtil.ToggleClassTalentFrame()
            elseif _G.ToggleTalentFrame then _G.ToggleTalentFrame() end
        end
        self.functions.pvp = function(_, button)
            if InCombatLockdown() or button ~= "LeftButton" then return end
            if ShowPVEFrameTab(2) then return end
        end
        self.functions.journal = function(_, button)
            if InCombatLockdown() or button ~= "LeftButton" then return end
            if _G.EncounterJournal_LoadUI then _G.EncounterJournal_LoadUI() end
            local ej = _G.EncounterJournal
            if ej then
                if ej:IsShown() then ej:Hide()
                else if ej.tab1 then PanelTemplates_SetTab(ej, 1) end; ej:Show() end
            elseif _G.ToggleEncounterJournal then _G.ToggleEncounterJournal() end
        end
    end

    function M:CreateFramesInner()
        local mm = DB("micromenu") or {}
        if not self.mmFrame then
            self.mmFrame = CreateFrame("Frame", "EllesmereUIWonderBarMMFrame", WB:GetModuleSlot("micromenu"))
            self.mmFrame:SetSize(1, 1)
            self.mmFrame:SetPoint("LEFT", WB:GetModuleSlot("micromenu"), "LEFT", 0, 0)
        end
        for _, def in ipairs(buttonDefs) do
            local key = def.key
            if mm[key] then
                local micro = def.micro
                if not micro and key == 'housing' then micro = _G.HousingMicroButton end
                if key == 'housing' and not micro then
                    -- Skip housing if the Blizzard micro button doesn't exist yet.
                else
                    local frameName = 'EWB_MM_' .. key
                    local frame = self.frames[key] or _G[frameName]
                    if not frame then
                        frame = CreateFrame('BUTTON', frameName, self.mmFrame)
                    end
                    self.frames[key] = frame
                    if def.info then
                        if not self.text[key] then
                            self.text[key] = frame:CreateFontString(nil, 'OVERLAY')
                        end
                        if not self.bgTexture[key] then
                            self.bgTexture[key] = frame:CreateTexture(nil, 'OVERLAY')
                        end
                    end
                    frame:EnableMouse(true)
                end
            end
        end
    end

    function M:ApplyCombatState()
        local mm = DB("micromenu") or {}
        local hideForCombat = InCombatLockdown() and not mm.combatEn
        if self.mmFrame then
            if hideForCombat then self.mmFrame:Hide() else self.mmFrame:Show() end
        end
        for _, frame in pairs(self.frames) do
            if frame then frame:EnableMouse(not hideForCombat) end
        end
    end

    function M:CreateIcons()
        for name, frame in pairs(self.frames) do
            if not self.icons[name] then
                self.icons[name] = frame:CreateTexture(nil, "OVERLAY")
            end
            self.icons[name]:SetTexture(MM_MEDIA .. name)
        end
    end

    function M:ShowButtonTooltip(name)
        if name == 'social' or name == 'guild' then return end
        local frame = self.frames[name]; if not frame then return end
        local def   = self.buttonDefs[name]; if not def then return end
        local r, g, b = WB:GetAccent()
        local anchor = 'ANCHOR_' .. (BarDB().position == 'TOP' and 'BOTTOM' or 'TOP')
        GameTooltip:SetOwner(frame, anchor); GameTooltip:ClearLines()
        local title = '|cFFFFFFFF' .. (def.label or name) .. '|r'
        if def.binding then
            local k1, k2 = GetBindingKey(def.binding)
            local keys = {}
            if k1 and k1 ~= '' then keys[#keys+1] = GetBindingText(k1) end
            if k2 and k2 ~= '' then keys[#keys+1] = GetBindingText(k2) end
            if #keys > 0 then
                title = title .. ' |cFFFFD200(' .. tconcat(keys, ' / ') .. ')|r'
            end
        end
        GameTooltip:AddLine(title, r, g, b)

        if name == 'ach' then
            local pts = GetTotalAchievementPoints and GetTotalAchievementPoints() or 0
            local hexAccent = format('%02x%02x%02x', floor(r*255), floor(g*255), floor(b*255))
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(
                '|cFFFFFFFF' .. (L["ACH_POINTS"] or "Achievement Points") .. '|r',
                '|cFF' .. hexAccent .. pts .. '|r',
                1, 1, 1, r, g, b)
        end

        if name == 'journal' then
            local hexAccent = format('%02x%02x%02x', floor(r*255), floor(g*255), floor(b*255))
            GameTooltip:AddLine(" ")
            local delveRank, delveMax = 0, '?'
            if C_DelvesUI and C_DelvesUI.GetDelvesFactionForSeason
               and C_MajorFactions and C_MajorFactions.GetCurrentRenownLevel then
                local fid = C_DelvesUI.GetDelvesFactionForSeason()
                if fid then
                    delveRank = C_MajorFactions.GetCurrentRenownLevel(fid) or 0
                    if C_MajorFactions.GetRenownLevels then
                        local levels = C_MajorFactions.GetRenownLevels(fid)
                        if type(levels) == 'table' and #levels > 0 then
                            delveMax = tostring(#levels)
                        end
                    end
                end
            end
            GameTooltip:AddDoubleLine(
                '|cFFFFFFFF' .. (L["DELVE_JOURNEY"] or "Delver's Journey") .. '|r',
                '|cFF' .. hexAccent .. delveRank .. '|r |cFFAAAAAA/ ' .. delveMax .. '|r',
                1, 1, 1, r, g, b)
            local companionLvl = 0
            if C_DelvesUI and C_DelvesUI.GetFactionForCompanion and C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
                local cfid = C_DelvesUI.GetFactionForCompanion()
                if cfid then
                    local fi = C_GossipInfo.GetFriendshipReputation(cfid)
                    if fi and fi.reaction then
                        companionLvl = tonumber(fi.reaction:match("%d+")) or 0
                    end
                end
            end
            GameTooltip:AddDoubleLine(
                '|cFFFFFFFF' .. (L["COMPANION_LEVEL"] or "Companion Level") .. '|r',
                '|cFF' .. hexAccent .. companionLvl .. '|r',
                1, 1, 1, r, g, b)
        end

        GameTooltip:Show()
    end

    function M:RegisterFrameEvents()
        for name, frame in pairs(self.frames) do
            frame:EnableMouse(true); frame:RegisterForClicks("AnyUp")
            frame:SetScript('OnClick', self.functions[name] or function(_, button)
                self:HandleGenericButtonClick(name, button)
            end)

            local function OnEnter()
                if not (DB("micromenu") or {}).combatEn and InCombatLockdown() then return end
                if self.icons[name] then
                    local r, g, b = WB:GetAccent()
                    self.icons[name]:SetVertexColor(r, g, b, 1)
                end
                self:ShowButtonTooltip(name)
            end
            local function OnLeave()
                if self.icons[name] then self.icons[name]:SetVertexColor(1, 1, 1, 1) end
                GameTooltip:Hide()
            end
            frame:SetScript("OnEnter", OnEnter); frame:SetScript("OnLeave", OnLeave)
        end
    end

    function M:UpdateGuildText()
        local mm = DB("micromenu") or {}
        if not self.text.guild or not mm.guild or mm.hideSocialText then return end
        if not IsInGuild() then
            if self.text.guild then self.text.guild:Hide() end
            return
        end
        if not InCombatLockdown() then C_GuildInfo.GuildRoster() end
        local _, online = GetNumGuildMembers()
        WB:SetFont(self.text.guild, BarDB().fontSizeSmall or 12)
        local ar, ag, ab = WB:GetAccent()
        self.text.guild:SetTextColor(ar, ag, ab, 1); self.text.guild:SetText(online)
        local ost = mm.osSocialText or 12
        if BarDB().position == 'TOP' then ost = -ost end
        self.text.guild:SetPoint('CENTER', self.frames.guild, 'CENTER', 0, ost)
        if self.bgTexture.guild then
            self.bgTexture.guild:SetPoint('CENTER', self.text.guild)
            self.bgTexture.guild:SetColorTexture(BarDB().bgR or 0.04, BarDB().bgG or 0.04, BarDB().bgB or 0.04, BarDB().bgA or 0.85)
            self.bgTexture.guild:Show()
        end
        self.text.guild:Show()
    end

    function M:UpdateFriendText()
        local mm = DB("micromenu") or {}
        if mm.hideSocialText or not mm.social or not self.text.social then return end
        local _, bnOnline = BNGetNumFriends()
        local total = (bnOnline or 0) + C_FriendList.GetNumOnlineFriends()
        WB:SetFont(self.text.social, BarDB().fontSizeSmall or 12)
        local ar, ag, ab = WB:GetAccent()
        self.text.social:SetTextColor(ar, ag, ab, 1); self.text.social:SetText(total)
        local ost = mm.osSocialText or 12
        if BarDB().position == 'TOP' then ost = -ost end
        self.text.social:SetPoint('CENTER', self.frames.social, 'CENTER', 0, ost)
        if self.bgTexture.social then
            self.bgTexture.social:SetPoint('CENTER', self.text.social)
            self.bgTexture.social:SetColorTexture(BarDB().bgR or 0.04, BarDB().bgG or 0.04, BarDB().bgB or 0.04, BarDB().bgA or 0.85)
        end
    end

    function M:OnRefresh()
        if not self.mmFrame then return end
        self:ToggleBlizzardMicroMenu()
        self:ApplyCombatState()
        if not self.mmFrame:IsShown() then return end
        if not next(self.frames) then return end
        if InCombatLockdown() then return end

        local mm = DB("micromenu") or {}
        local ICON_SIZE = self:GetIconSize()

        local pos = BarDB().position
        local isVertical = (pos == "LEFT" or pos == "RIGHT")
        local totalWidth, totalHeight, prev = 0, 0, nil
        for _, key in ipairs(self.buttonOrder) do
            local frame = self.frames[key]
            if frame then
                frame:SetSize(ICON_SIZE, ICON_SIZE)
                if self.icons[key] then
                    self.icons[key]:ClearAllPoints()
                    self.icons[key]:SetPoint("CENTER")
                    local iconSize = ICON_SIZE
                    if key == 'housing' then
                        iconSize = max(14, floor(ICON_SIZE * 0.84 + 0.5))
                    end
                    self.icons[key]:SetSize(iconSize, iconSize)
                    self.icons[key]:SetVertexColor(1, 1, 1, 1)
                end
                frame:ClearAllPoints()
                local spacing = (prev and prev == self.frames.menu) and (mm.mainMenuSpacing or 4) or (mm.iconSpacing or SPACING)
                if not prev then
                    if isVertical then frame:SetPoint("TOP", self.mmFrame, "TOP", 0, 0)
                    else              frame:SetPoint("LEFT", self.mmFrame, "LEFT", 0, 0) end
                else
                    if isVertical then frame:SetPoint("TOP", prev, "BOTTOM", 0, -spacing)
                    else              frame:SetPoint("LEFT", prev, "RIGHT", spacing, 0) end
                end
                if isVertical then
                    totalHeight = totalHeight + ICON_SIZE + (prev and spacing or 0)
                    totalWidth  = max(totalWidth, ICON_SIZE)
                else
                    totalWidth  = totalWidth + ICON_SIZE + (prev and spacing or 0)
                    totalHeight = max(totalHeight, ICON_SIZE)
                end
                prev = frame
            end
        end

        if isVertical then
            self.mmFrame:SetSize(max(totalWidth, 1), max(totalHeight, 1))
            self.mmFrame:ClearAllPoints()
            self.mmFrame:SetPoint("TOP", WB:GetModuleSlot("micromenu"), "TOP", 0, 0)
        else
            self.mmFrame:SetSize(max(totalWidth, 1), max(totalHeight, 1))
            self.mmFrame:ClearAllPoints()
            self.mmFrame:SetPoint("LEFT", WB:GetModuleSlot("micromenu"), "LEFT", 0, 0)
        end

        if mm.hideSocialText then
            for _, fs in pairs(self.text) do fs:Hide() end
        else
            self:UpdateFriendText(); self:UpdateGuildText()
        end
    end

    function M:OnCreate()
        self:CreateClickFunctions()
        self:CreateFramesInner()
        self:RegisterFrameEvents()
        self:CreateIcons()
    end

    function M:OnEvent(event)
        if event == 'GUILD_ROSTER_UPDATE' then
            self:UpdateGuildText()
        elseif event == 'BN_FRIEND_ACCOUNT_ONLINE'
            or event == 'BN_FRIEND_ACCOUNT_OFFLINE'
            or event == 'FRIENDLIST_UPDATE' then
            self:UpdateFriendText()
        elseif event == 'PLAYER_REGEN_ENABLED'
            or event == 'PLAYER_REGEN_DISABLED'
            or event == 'PLAYER_ENTERING_WORLD' then
            self:ApplyCombatState()
            self:OnRefresh()
        end
    end

    function M:OnEnable()
        self.mmFrame:Show()
        self:ToggleBlizzardMicroMenu()
        self:ApplyCombatState()
    end
    function M:OnDisable()
        if self.mmFrame then self.mmFrame:Hide() end
        self:ToggleBlizzardMicroMenu(false)
    end

    function M:GetContentWidth()
        if not self.mmFrame then return 200 end
        if IsSideAnchored() then
            local mm = DB("micromenu") or {}
            local ICON_SIZE = self:GetIconSize()
            local count = 0
            for _, key in ipairs(self.buttonOrder) do
                if self.frames[key] then count = count + 1 end
            end
            if count == 0 then return 50 end
            local spacing = mm.iconSpacing or 2
            return max(count * ICON_SIZE + (count - 1) * spacing, 50)
        end
        return max(self.mmFrame:GetWidth() or 200, 50)
    end

    WB:RegisterModule("micromenu", M)
end

-- End of WonderBar rewrite.
