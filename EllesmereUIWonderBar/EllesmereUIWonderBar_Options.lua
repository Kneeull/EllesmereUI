-------------------------------------------------------------------------------
--  EllesmereUIWonderBar_Options.lua
--  Registers WonderBar as a standalone EllesmereUI module (its own page).
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local WB = ns.WB
local L  = ns.L

local PAGE_WONDERBAR = "WonderBar"

-------------------------------------------------------------------------------
--  Bar colour presets
--  Each entry has a display name and RGBA values.
--  "theme" is a special key that resolves to the active EllesmereUI accent.
-------------------------------------------------------------------------------
local BAR_COLOUR_PRESETS = {
    { key = "dark",    name = "Dark",           r = 0.04, g = 0.04, b = 0.04, a = 0.85 },
    { key = "darker",  name = "Darker",         r = 0.02, g = 0.02, b = 0.02, a = 0.92 },
    { key = "black",   name = "Black",          r = 0,    g = 0,    b = 0,    a = 0.95 },
    { key = "theme",   name = "Theme Accent",   r = 0,    g = 0,    b = 0,    a = 0.85 },
    { key = "charcoal",name = "Charcoal",       r = 0.08, g = 0.08, b = 0.10, a = 0.88 },
    { key = "slate",   name = "Slate",          r = 0.10, g = 0.12, b = 0.16, a = 0.85 },
    { key = "navy",    name = "Navy",           r = 0.04, g = 0.06, b = 0.14, a = 0.88 },
    { key = "midnight",name = "Midnight",       r = 0.06, g = 0.04, b = 0.12, a = 0.88 },
}

local function BuildColourValues()
    local values, order = {}, {}
    for _, preset in ipairs(BAR_COLOUR_PRESETS) do
        values[preset.key] = preset.name
        order[#order + 1] = preset.key
    end
    return values, order
end

local function ApplyColourPreset(key)
    local db = WB.db and WB.db.profile and WB.db.profile.bar
    if not db then return end
    for _, preset in ipairs(BAR_COLOUR_PRESETS) do
        if preset.key == key then
            if key == "theme" then
                local ar, ag, ab = WB:GetAccent()
                db.bgR = ar * 0.15
                db.bgG = ag * 0.15
                db.bgB = ab * 0.15
            else
                db.bgR = preset.r
                db.bgG = preset.g
                db.bgB = preset.b
            end
            db.bgA = preset.a
            db.barColour = key
            WB:RefreshBar()
            return
        end
    end
end

local function GetCurrentColourKey()
    local db = WB.db and WB.db.profile and WB.db.profile.bar
    return db and db.barColour or "dark"
end

-------------------------------------------------------------------------------
--  Page builder
-------------------------------------------------------------------------------
local function BuildWonderBarPage(pageName, parent, yOffset)
    local W = EllesmereUI.Widgets
    if not W then return math.abs(yOffset) end

    local y = yOffset
    local _, h
    local function DB() return WB.db and WB.db.profile end
    local function CommitPendingSlotChanges()
        if WB and WB.CommitPendingSlotAssignments and WB:HasPendingSlotAssignments() then
            WB:CommitPendingSlotAssignments()
        end
    end
    local colourValues, colourOrder = BuildColourValues()

    -- ── Bar ──────────────────────────────────────────────────────────────
    _, h = W:SectionHeader(parent, L["OPT_BAR"], y);  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "toggle", text = L["OPT_BAR_ENABLE"],
          getValue = function() return DB() and DB().bar.enabled end,
          setValue = function(v)
              if not DB() then return end
              DB().bar.enabled = v
              if v then WB:OnEnable() else WB:OnDisable() end
          end },
        { type = "dropdown", text = L["OPT_BAR_POSITION"],
          values = {
              BOTTOM = L["OPT_BAR_POSITION_BOTTOM"],
              TOP    = L["OPT_BAR_POSITION_TOP"],
              LEFT   = L["OPT_BAR_POSITION_LEFT"],
              RIGHT  = L["OPT_BAR_POSITION_RIGHT"],
          },
          order = { "BOTTOM", "TOP", "LEFT", "RIGHT" },
          getValue = function() return DB() and DB().bar.position end,
          setValue = function(v)
              if not DB() then return end
              DB().bar.position = v
              DB().bar.savedPoint    = nil
              DB().bar.savedRelPoint = nil
              DB().bar.savedX        = nil
              DB().bar.savedY        = nil
              CommitPendingSlotChanges()
              WB:RefreshBar()
          end }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "slider", text = L["OPT_BAR_HEIGHT"], min = 20, max = 35, step = 1,
          getValue = function() return DB() and DB().bar.height end,
          setValue = function(v)
              if not DB() then return end
              DB().bar.height = v
              CommitPendingSlotChanges()
              WB:RefreshBar()
          end },
        { type = "dropdown", text = L["OPT_BAR_VISIBILITY"],
          values = {
              ALWAYS    = L["OPT_VIS_ALWAYS"],
              MOUSEOVER = L["OPT_VIS_MOUSEOVER"],
          },
          order = { "ALWAYS", "MOUSEOVER" },
          getValue = function() return DB() and DB().bar.visibility end,
          setValue = function(v)
              if not DB() then return end
              DB().bar.visibility = v
              WB:RefreshBar()
          end }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = L["OPT_BAR_COLOUR"],
          values = colourValues,
          order  = colourOrder,
          getValue = function() return GetCurrentColourKey() end,
          setValue = function(v) ApplyColourPreset(v) end },
        nil
    );  y = y - h

    -- ── MicroMenu ────────────────────────────────────────────────────────
    _, h = W:SectionHeader(parent, L["OPT_MICROMENU"], y);  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "toggle", text = L["OPT_MM_ENABLE"],
          getValue = function() return DB() and DB().micromenu.enabled end,
          setValue = function(v)
              if not DB() then return end
              DB().micromenu.enabled = v
              local mm = WB._modules and WB._modules.micromenu
              if mm then
                  if v then mm:Enable() else mm:Disable() end
              end
              WB:RefreshBar()
          end },
        { type = "toggle", text = L["OPT_MM_HIDE_BLIZZARD"],
          getValue = function() return DB() and DB().micromenu.disableBlizzardMicroMenu end,
          setValue = function(v)
              if not DB() then return end
              DB().micromenu.disableBlizzardMicroMenu = v
              local mm = WB._modules and WB._modules.micromenu
              if mm and mm.ToggleBlizzardMicroMenu then mm:ToggleBlizzardMicroMenu() end
          end }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "toggle", text = L["OPT_MM_COMBAT"],
          getValue = function() return DB() and DB().micromenu.combatEn end,
          setValue = function(v)
              if not DB() then return end
              DB().micromenu.combatEn = v
              local mm = WB._modules and WB._modules.micromenu
              if mm then
                  if mm.ApplyCombatState then mm:ApplyCombatState() end
                  if mm.Refresh then mm:Refresh() end
              end
          end },
        nil
    );  y = y - h

    -- ── Clock ────────────────────────────────────────────────────────────
    _, h = W:SectionHeader(parent, L["OPT_CLOCK"], y);  y = y - h

    _, h = W:DualRow(parent, y,
        { type = "toggle", text = L["OPT_CLOCK_ENABLE"],
          getValue = function() return DB() and DB().clock.enabled end,
          setValue = function(v)
              if not DB() then return end
              DB().clock.enabled = v
              local mod = WB._modules and WB._modules.clock
              if mod then
                  if v then mod:Enable() else mod:Disable() end
              end
              WB:RefreshBar()
          end },
        { type = "toggle", text = L["OPT_CLOCK_DATE"],
          getValue = function() return DB() and DB().clock and DB().clock.showDate end,
          setValue = function(v)
              if not DB() then return end
              DB().clock.showDate = v
              local mod = WB._modules and WB._modules.clock
              if mod and mod.Refresh then mod:Refresh() end
          end }
    );  y = y - h

    -- ── Modules on/off ───────────────────────────────────────────────────
    -- (Clock and MicroMenu already have their own section headers above,
    -- so their enable toggles live there; the remaining six live here.)
    _, h = W:SectionHeader(parent, L["OPT_MODULES"], y);  y = y - h

    local moduleList = {
        { key = "system",     label = L["OPT_MOD_SYSTEM"]     },
        { key = "gold",       label = L["OPT_MOD_GOLD"]       },
        { key = "travel",     label = L["OPT_MOD_TRAVEL"]     },
        { key = "profession", label = L["OPT_MOD_PROFESSION"] },
        { key = "specswitch", label = L["OPT_MOD_SPECSWITCH"] },
        { key = "databar",    label = L["OPT_MOD_DATABAR"]    },
    }

    for i = 1, #moduleList, 2 do
        local left  = moduleList[i]
        local right = moduleList[i + 1]

        local function makeToggle(entry)
            return {
                type = "toggle",
                text = entry.label,
                getValue = function()
                    return DB() and DB()[entry.key] and DB()[entry.key].enabled
                end,
                setValue = function(v)
                    if not DB() or not DB()[entry.key] then return end
                    DB()[entry.key].enabled = v
                    local mod = WB._modules and WB._modules[entry.key]
                    if mod then
                        if v then mod:Enable() else mod:Disable() end
                    end
                    WB:RefreshBar()
                end,
            }
        end

        _, h = W:DualRow(parent, y, makeToggle(left), right and makeToggle(right) or nil)
        y = y - h
    end

    -- ── Module order (slotPos + hidden) ──────────────────────────────────
    -- One dropdown per bar slot: Centre (slotPos 0), then non-centre slots
    -- ordered 1..N. Each dropdown also has a "None" entry that hides the
    -- occupying module from the bar (sets enabled = false). Picking a module
    -- name in a slot that was "None" re-enables that module and places it
    -- there; picking a different module in an occupied slot swaps them.
    --
    -- Centre has no "None" entry — a bar without a pivot is undefined. If you
    -- want to hide Clock specifically, use its enable toggle above.
    _, h = W:SectionHeader(parent, L["OPT_ORDER"], y);  y = y - h

    -- All modules that can be reordered, with human labels.
    local ALL_MODULES = {
        { key = "clock",      label = L["OPT_MOD_CLOCK"]      },
        { key = "micromenu",  label = L["OPT_MOD_MICROMENU"]  },
        { key = "databar",    label = L["OPT_MOD_DATABAR"]    },
        { key = "specswitch", label = L["OPT_MOD_SPECSWITCH"] },
        { key = "profession", label = L["OPT_MOD_PROFESSION"] },
        { key = "gold",       label = L["OPT_MOD_GOLD"]       },
        { key = "system",     label = L["OPT_MOD_SYSTEM"]     },
        { key = "travel",     label = L["OPT_MOD_TRAVEL"]     },
    }
    local NON_CENTRE_SLOTS = #ALL_MODULES - 1   -- one slot is Centre

    local NONE_KEY = "__none__"

    -- Dropdown values: all module names + "None" (except the centre dropdown,
    -- which omits "None" because a pivot is required).
    local function BuildModuleChoices(includeNone)
        local values, order = {}, {}
        for _, m in ipairs(ALL_MODULES) do
            values[m.key] = m.label
            order[#order + 1] = m.key
        end
        if includeNone then
            values[NONE_KEY] = L["OPT_ORDER_NONE"]
            order[#order + 1] = NONE_KEY
        end
        return values, order
    end

    -- A module is "visible on the bar" if it's enabled. We consider the
    -- `enabled` flag authoritative for presence in the layout, including Clock.
    local function IsVisible(key)
        local mdb = DB() and DB()[key]
        if not mdb then return false end
        return mdb.enabled ~= false
    end

    local FIXED_SLOT_POSITIONS = { [0] = 0, [1] = 10, [2] = 20, [3] = 30, [4] = 40, [5] = 50, [6] = 60, [7] = 70 }

    local function GetFixedSlotPos(slotIdx)
        return FIXED_SLOT_POSITIONS[slotIdx]
    end

    local function GetModuleAtSlot(slotIdx)
        if not DB() then return nil end
        local wantedPos = GetFixedSlotPos(slotIdx)
        if wantedPos == nil then return nil end

        local best = nil
        for _, m in ipairs(ALL_MODULES) do
            if IsVisible(m.key) and ((DB()[m.key].slotPos or 0) == wantedPos) then
                if not best or m.key < best then best = m.key end
            end
        end
        return best
    end

    local function GetDisplayedModuleAtSlot(slotIdx)
        local pending = WB and WB._pendingSlotAssignments
        if type(pending) ~= "table" then
            return GetModuleAtSlot(slotIdx)
        end
        local entry = pending[slotIdx]
        if entry and type(entry.newKey) == "string" and entry.newKey ~= "" then
            return entry.newKey
        end
        return GetModuleAtSlot(slotIdx)
    end

    local function AssignModuleToSlot(slotIdx, newKey)
        if not DB() then return end
        local targetPos = GetFixedSlotPos(slotIdx)
        if targetPos == nil then return end
        local current = GetModuleAtSlot(slotIdx)

        if newKey == NONE_KEY then
            if slotIdx == 0 then return end
            if current and DB()[current] then
                if current == "clock" then return end
                DB()[current].enabled = false
                local mod = WB._modules and WB._modules[current]
                if mod then mod:Disable() end
                if WB and WB._pendingSlotAssignments then
                    WB._pendingSlotAssignments[slotIdx] = nil
                end
                WB:RefreshBar()
            end
            return
        end

        local newDB = DB()[newKey]
        if not newDB then return end

        local wasHidden = not IsVisible(newKey)
        if wasHidden then
            newDB.enabled = true
            local mod = WB._modules and WB._modules[newKey]
            if mod then mod:Enable() end
        end

        if WB and WB.StageSlotAssignment then
            WB:StageSlotAssignment(slotIdx, newKey)
        else
            local oldPos = newDB.slotPos or targetPos
            if current and current ~= newKey and DB()[current] then
                DB()[current].slotPos = oldPos
            end
            newDB.slotPos = targetPos
        end

        if WB and WB.PreviewPendingSlotAssignments then
            WB:PreviewPendingSlotAssignments()
        else
            WB:RefreshBar()
        end
    end

    -- Dropdowns: Centre omits "None"; others include it.
    local centreValues, centreOrder     = BuildModuleChoices(false)
    local slotValues,   slotOrder       = BuildModuleChoices(true)

    local function MakeSlotDropdown(slotIdx, label)
        local isCentre = slotIdx == 0
        local values = isCentre and centreValues or slotValues
        local order  = isCentre and centreOrder  or slotOrder
        return {
            type = "dropdown",
            text = label,
            values = values,
            order = order,
            getValue = function()
                local v = GetDisplayedModuleAtSlot(slotIdx)
                if v then return v end
                return isCentre and (order[1]) or NONE_KEY
            end,
            setValue = function(v) AssignModuleToSlot(slotIdx, v) end,
        }
    end

    local function IsVerticalBar()
        local bar = DB() and DB().bar
        local pos = bar and bar.position
        return pos == "LEFT" or pos == "RIGHT"
    end

    local function GetSlotVisualLabel(slotIdx)
        if slotIdx == 0 then
            return L["OPT_ORDER_CENTRE"]
        end

        local vertical = IsVerticalBar()
        local leftCount = math.floor(NON_CENTRE_SLOTS / 2)
        local isLeadingSide = slotIdx <= leftCount

        if vertical then
            if isLeadingSide then
                local n = (leftCount - slotIdx) + 1
                return (n == 1) and "Top 1 (inner)" or string.format("Top %d", n)
            else
                local n = slotIdx - leftCount
                return (n == 1) and "Bottom 1 (inner)" or string.format("Bottom %d", n)
            end
        else
            if isLeadingSide then
                local n = (leftCount - slotIdx) + 1
                return (n == 1) and "Left 1 (inner)" or string.format("Left %d", n)
            else
                local n = slotIdx - leftCount
                return (n == 1) and "Right 1 (inner)" or string.format("Right %d", n)
            end
        end
    end

    -- Centre on its own row.
    _, h = W:DualRow(parent, y,
        MakeSlotDropdown(0, GetSlotVisualLabel(0)),
        nil
    );  y = y - h

    -- Remaining slots, two per row, using final visual positions around centre.
    for i = 1, NON_CENTRE_SLOTS, 2 do
        local leftLabel  = GetSlotVisualLabel(i)
        local rightLabel = (i + 1) <= NON_CENTRE_SLOTS and GetSlotVisualLabel(i + 1) or nil
        local left  = MakeSlotDropdown(i,     leftLabel)
        local right = rightLabel and MakeSlotDropdown(i + 1, rightLabel) or nil
        _, h = W:DualRow(parent, y, left, right)
        y = y - h
    end

    return math.abs(y)
end

-------------------------------------------------------------------------------
--  Standalone registration with EllesmereUI core
--
--  EllesmereUI.lua is expected to include "EllesmereUIWonderBar" in its
--  module list (the user has wired this in manually). We register here with
--  a single page that uses the shared page builder above.
-------------------------------------------------------------------------------
local function Register()
    if not EllesmereUI or not EllesmereUI.RegisterModule then return false end
    EllesmereUI:RegisterModule("EllesmereUIWonderBar", {
        title                = "WonderBar",
        description          = "Information bar — clock, gold, reputation, and more.",
        pages                = { PAGE_WONDERBAR },
        disabledPages        = {},
        disabledPageTooltips = {},
        buildPage = function(pageName, parent, yOffset)
            if pageName == PAGE_WONDERBAR then
                return BuildWonderBarPage(pageName, parent, yOffset)
            end
        end,
    })
    return true
end

if not Register() then
    -- Core not yet ready at file-load (this file sits after the core in the
    -- TOC, but be defensive). Retry once PLAYER_LOGIN fires.
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        Register()
    end)
end
