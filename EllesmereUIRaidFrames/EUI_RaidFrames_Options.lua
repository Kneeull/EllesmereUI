-------------------------------------------------------------------------------
--  EUI_RaidFrames_Options.lua
--  Registers the Raid Frames module with EllesmereUI
--  Options UI with interactive preview, Display/Colors/General pages
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

-------------------------------------------------------------------------------
--  Page / section names
-------------------------------------------------------------------------------
local PAGE_DISPLAY  = "Display"
local PAGE_COLORS   = "Colors"
local PAGE_GENERAL  = "General"

local SECTION_FRAME       = "FRAME SIZE & LAYOUT"
local SECTION_HEALTH_BAR  = "HEALTH BAR"
local SECTION_POWER_BAR   = "POWER BAR"
local SECTION_NAME_TEXT   = "NAME TEXT"
local SECTION_HEALTH_TEXT = "HEALTH TEXT"
local SECTION_BORDER      = "BORDER & BACKGROUND"
local SECTION_ICONS       = "ICONS"
local SECTION_AURAS       = "BUFFS & DEBUFFS"

local SECTION_HEALTH_COLORS = "HEALTH COLORS"
local SECTION_HIGHLIGHTS    = "HIGHLIGHTS & EFFECTS"
local SECTION_ROLE_TINT     = "ROLE TINT"

local SECTION_LAYOUT      = "LAYOUT & SORTING"
local SECTION_VISIBILITY  = "VISIBILITY"
local SECTION_RANGE       = "RANGE & FADING"

-- Wait for EllesmereUI to exist
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    if not EllesmereUI or not EllesmereUI.RegisterModule then return end
    if not EllesmereUIRaidFrames then return end

    local ERF = EllesmereUIRaidFrames
    local W = EllesmereUI.Widgets

    ---------------------------------------------------------------------------
    --  DB helpers
    ---------------------------------------------------------------------------
    local function DB()
        return ERF.db and ERF.db.profile
    end

    local function DBVal(key)
        local db = DB()
        if db and db[key] ~= nil then return db[key] end
        local d = ns.defaults and ns.defaults.profile
        return d and d[key]
    end

    local function DBColor(key)
        local c = DBVal(key)
        if not c then return 0, 0, 0 end
        return c.r, c.g, c.b
    end

    local function SetDB(key, val)
        local db = DB()
        if db then db[key] = val end
    end

    local function RefreshAll()
        ERF:UpdateAllFrames()
    end

    local function RefreshLayout()
        ERF:ApplyLayoutToAll()
    end

    ---------------------------------------------------------------------------
    --  Font dropdown values
    ---------------------------------------------------------------------------
    local FONT_DIR = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\"
    local fontValues = {
        [FONT_DIR .. "Expressway.TTF"]           = { text = "Expressway",           font = FONT_DIR .. "Expressway.TTF" },
        [FONT_DIR .. "Avant Garde.ttf"]          = { text = "Avant Garde",          font = FONT_DIR .. "Avant Garde.ttf" },
        [FONT_DIR .. "Arial Bold.TTF"]           = { text = "Arial Bold",           font = FONT_DIR .. "Arial Bold.TTF" },
        [FONT_DIR .. "Poppins.ttf"]              = { text = "Poppins",              font = FONT_DIR .. "Poppins.ttf" },
        [FONT_DIR .. "FiraSans Medium.ttf"]      = { text = "Fira Sans Medium",     font = FONT_DIR .. "FiraSans Medium.ttf" },
        [FONT_DIR .. "Arial Narrow.ttf"]         = { text = "Arial Narrow",         font = FONT_DIR .. "Arial Narrow.ttf" },
        ["Fonts\\FRIZQT__.TTF"]                  = { text = "Friz Quadrata",        font = "Fonts\\FRIZQT__.TTF" },
        ["Fonts\\ARIALN.TTF"]                    = { text = "Arial",                font = "Fonts\\ARIALN.TTF" },
    }
    local fontOrder = {
        FONT_DIR .. "Expressway.TTF",
        FONT_DIR .. "Avant Garde.ttf",
        FONT_DIR .. "Arial Bold.TTF",
        FONT_DIR .. "Poppins.ttf",
        FONT_DIR .. "FiraSans Medium.ttf",
        "---",
        FONT_DIR .. "Arial Narrow.ttf",
        "Fonts\\FRIZQT__.TTF",
        "Fonts\\ARIALN.TTF",
    }

    ---------------------------------------------------------------------------
    --  Preview state
    ---------------------------------------------------------------------------
    local activePreview
    local _displayHeaderBuilder

    -- Random preview values (regenerated on tab switch)
    local _previewHpPct, _previewPowerPct, _previewAbsorbPct
    local function RandomizePreviewValues()
        _previewHpPct = 0.55 + math.random() * 0.30
        _previewPowerPct = 0.40 + math.random() * 0.50
        _previewAbsorbPct = 0.05 + math.random() * 0.15
    end
    RandomizePreviewValues()

    local function UpdatePreview()
        if activePreview and activePreview.Update then
            activePreview:Update()
        end
    end

    EllesmereUI:RegisterOnShow(UpdatePreview)

    ---------------------------------------------------------------------------
    --  Build interactive preview (shown in content header area)
    ---------------------------------------------------------------------------
    local function BuildRaidFramePreview(parent, parentW)
        local db = DB()
        local FONT_PATH = DBVal("nameFont")

        -- Container
        local pf = CreateFrame("Frame", nil, parent)
        pf:SetPoint("TOP", parent, "TOP", 0, 0)

        -- Scale to match real frame size
        local previewScale = UIParent:GetEffectiveScale() / parent:GetEffectiveScale()
        pf:SetScale(previewScale)
        local localParentW = parentW / previewScale

        local function Snap(val)
            local s = pf:GetEffectiveScale()
            return math.floor(val * s + 0.5) / s
        end

        local px = Snap(1)

        -- Section-to-scroll mapping for hover highlights
        local hoverZones = {}

        local function AddHoverZone(frame, sectionName)
            frame:EnableMouse(true)
            frame:SetScript("OnEnter", function(self)
                self.highlight = self.highlight or self:CreateTexture(nil, "HIGHLIGHT")
                self.highlight:SetAllPoints()
                self.highlight:SetColorTexture(0.05, 0.82, 0.62, 0.15)
                -- Scroll to section
                if sectionName and EllesmereUI.ScrollToSection then
                    EllesmereUI:ScrollToSection(sectionName)
                end
            end)
            frame:SetScript("OnLeave", function(self)
                if self.highlight then self.highlight:Hide() end
            end)
            frame:SetScript("OnMouseUp", function(self)
                if sectionName and EllesmereUI.ScrollToSection then
                    EllesmereUI:ScrollToSection(sectionName)
                end
            end)
            hoverZones[sectionName] = frame
        end

        -- Build the preview frame elements
        local frameW = DBVal("frameWidth")
        local frameH = DBVal("frameHeight")
        local pad = DBVal("framePadding")
        local powerH = DBVal("powerBarEnabled") and DBVal("powerBarHeight") or 0

        -- Main frame container
        local mainFrame = CreateFrame("Frame", nil, pf)
        mainFrame:SetSize(frameW, frameH)
        mainFrame:SetPoint("CENTER", pf, "CENTER", 0, 0)

        -- Background
        local bgTex = mainFrame:CreateTexture(nil, "BACKGROUND")
        bgTex:SetAllPoints()
        local bgc = DBVal("bgColor")
        bgTex:SetColorTexture(bgc.r, bgc.g, bgc.b, bgc.a)

        -- Border
        local borderS = DBVal("borderSize")
        local bc = DBVal("borderColor")
        if DBVal("borderEnabled") then
            local bTop = mainFrame:CreateTexture(nil, "BORDER")
            bTop:SetHeight(borderS); bTop:SetPoint("TOPLEFT"); bTop:SetPoint("TOPRIGHT")
            bTop:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
            local bBot = mainFrame:CreateTexture(nil, "BORDER")
            bBot:SetHeight(borderS); bBot:SetPoint("BOTTOMLEFT"); bBot:SetPoint("BOTTOMRIGHT")
            bBot:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
            local bLeft = mainFrame:CreateTexture(nil, "BORDER")
            bLeft:SetWidth(borderS); bLeft:SetPoint("TOPLEFT"); bLeft:SetPoint("BOTTOMLEFT")
            bLeft:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
            local bRight = mainFrame:CreateTexture(nil, "BORDER")
            bRight:SetWidth(borderS); bRight:SetPoint("TOPRIGHT"); bRight:SetPoint("BOTTOMRIGHT")
            bRight:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
        end

        -- Health bar zone (clickable to scroll to health section)
        local healthZone = CreateFrame("Frame", nil, mainFrame)
        healthZone:SetPoint("TOPLEFT", pad, -pad)
        healthZone:SetPoint("BOTTOMRIGHT", -pad, pad + powerH)
        healthZone:SetFrameLevel(mainFrame:GetFrameLevel() + 5)

        -- Health bar background (missing health)
        local missingTex = healthZone:CreateTexture(nil, "BACKGROUND")
        missingTex:SetAllPoints()
        local mhc = DBVal("missingHealthColor")
        missingTex:SetColorTexture(mhc.r, mhc.g, mhc.b, 1)

        -- Health bar fill
        local healthFill = healthZone:CreateTexture(nil, "ARTWORK")
        healthFill:SetPoint("TOPLEFT")
        healthFill:SetPoint("BOTTOMLEFT")
        healthFill:SetTexture(DBVal("healthTexture"))

        -- Heal prediction
        local healPredTex = healthZone:CreateTexture(nil, "ARTWORK", nil, 1)
        healPredTex:SetTexture(DBVal("healthTexture"))
        local hpc = DBVal("healPredColor")
        healPredTex:SetVertexColor(hpc.r, hpc.g, hpc.b, hpc.a)
        healPredTex:SetBlendMode("ADD")

        -- Absorb overlay
        local absorbTex = healthZone:CreateTexture(nil, "ARTWORK", nil, 2)
        absorbTex:SetTexture("Interface\\Buttons\\WHITE8x8")
        local abc = DBVal("absorbColor")
        absorbTex:SetVertexColor(abc.r, abc.g, abc.b, abc.a)
        absorbTex:SetBlendMode("ADD")

        AddHoverZone(healthZone, SECTION_HEALTH_BAR)

        -- Power bar zone
        local powerZone
        if DBVal("powerBarEnabled") then
            powerZone = CreateFrame("Frame", nil, mainFrame)
            powerZone:SetPoint("BOTTOMLEFT", pad, pad)
            powerZone:SetPoint("BOTTOMRIGHT", -pad, pad)
            powerZone:SetHeight(powerH)
            powerZone:SetFrameLevel(mainFrame:GetFrameLevel() + 5)

            local powerBg = powerZone:CreateTexture(nil, "BACKGROUND")
            powerBg:SetAllPoints()
            powerBg:SetColorTexture(0, 0, 0, 0.5)

            local powerFill = powerZone:CreateTexture(nil, "ARTWORK")
            powerFill:SetPoint("TOPLEFT")
            powerFill:SetPoint("BOTTOMLEFT")
            powerFill:SetTexture(DBVal("powerBarTexture"))
            powerFill:SetVertexColor(0, 0, 1, 1)  -- Mana blue default

            powerZone._fill = powerFill
            AddHoverZone(powerZone, SECTION_POWER_BAR)
        end

        -- Name text
        local nameFS = mainFrame:CreateFontString(nil, "OVERLAY")
        local _rfPreviewFont = (EllesmereUI and EllesmereUI.GetFontPath and EllesmereUI.GetFontPath("raidFrames")) or DBVal("nameFont")
        nameFS:SetFont(_rfPreviewFont, DBVal("nameFontSize"), DBVal("nameOutline"))
        nameFS:SetPoint(DBVal("namePosition"), mainFrame, DBVal("namePosition"), 0, DBVal("nameYOffset"))
        nameFS:SetText("Ellesmere")
        nameFS:SetTextColor(0.05, 0.82, 0.62, 1)  -- Ellesmere teal

        -- Name hover zone
        local nameZone = CreateFrame("Frame", nil, mainFrame)
        nameZone:SetPoint("TOPLEFT", nameFS, "TOPLEFT", -4, 4)
        nameZone:SetPoint("BOTTOMRIGHT", nameFS, "BOTTOMRIGHT", 4, -4)
        nameZone:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
        AddHoverZone(nameZone, SECTION_NAME_TEXT)

        -- Health text
        local healthFS = mainFrame:CreateFontString(nil, "OVERLAY")
        healthFS:SetFont(_rfPreviewFont, DBVal("healthFontSize"), DBVal("healthOutline"))
        healthFS:SetPoint(DBVal("healthPosition"), mainFrame, DBVal("healthPosition"), 0, DBVal("healthYOffset"))
        healthFS:SetTextColor(1, 1, 1, 1)

        -- Health text hover zone
        local healthTextZone = CreateFrame("Frame", nil, mainFrame)
        healthTextZone:SetPoint("TOPLEFT", healthFS, "TOPLEFT", -4, 4)
        healthTextZone:SetPoint("BOTTOMRIGHT", healthFS, "BOTTOMRIGHT", 4, -4)
        healthTextZone:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
        AddHoverZone(healthTextZone, SECTION_HEALTH_TEXT)

        -- Role icon
        local roleIconTex = mainFrame:CreateTexture(nil, "OVERLAY")
        roleIconTex:SetSize(DBVal("roleIconSize"), DBVal("roleIconSize"))
        roleIconTex:SetPoint(DBVal("roleIconPosition"), mainFrame, DBVal("roleIconPosition"),
            DBVal("roleIconXOffset"), DBVal("roleIconYOffset"))
        roleIconTex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        roleIconTex:SetTexCoord(20/64, 39/64, 1/64, 20/64)  -- Healer icon

        -- Role icon hover zone
        local roleZone = CreateFrame("Frame", nil, mainFrame)
        roleZone:SetPoint("TOPLEFT", roleIconTex, "TOPLEFT", -2, 2)
        roleZone:SetPoint("BOTTOMRIGHT", roleIconTex, "BOTTOMRIGHT", 2, -2)
        roleZone:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
        AddHoverZone(roleZone, SECTION_ICONS)

        -- Debuff icons (sample)
        local debuffZone = CreateFrame("Frame", nil, mainFrame)
        debuffZone:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
        local sampleDebuffs = { 135812, 136197, 135808 }
        local debuffSize = DBVal("debuffSize")
        local debuffPos = DBVal("debuffPosition")
        local dGrow = (debuffPos == "BOTTOMLEFT" or debuffPos == "TOPLEFT") and 1 or -1
        local prevIcon
        for i, texID in ipairs(sampleDebuffs) do
            if i > DBVal("debuffMax") then break end
            local dIcon = mainFrame:CreateTexture(nil, "OVERLAY")
            dIcon:SetSize(debuffSize, debuffSize)
            dIcon:SetTexture(texID)
            dIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            if i == 1 then
                dIcon:SetPoint(debuffPos, mainFrame, debuffPos, dGrow, (debuffPos:find("BOTTOM") and 1 or -1))
            else
                if dGrow > 0 then
                    dIcon:SetPoint("LEFT", prevIcon, "RIGHT", 1, 0)
                else
                    dIcon:SetPoint("RIGHT", prevIcon, "LEFT", -1, 0)
                end
            end
            prevIcon = dIcon
        end
        if prevIcon then
            debuffZone:SetPoint("TOPLEFT", mainFrame, debuffPos, 0, 0)
            debuffZone:SetSize(debuffSize * math.min(#sampleDebuffs, DBVal("debuffMax")) + 4, debuffSize + 4)
        end
        AddHoverZone(debuffZone, SECTION_AURAS)

        -- Border hover zone (the frame edges)
        local borderZone = CreateFrame("Frame", nil, mainFrame)
        borderZone:SetAllPoints()
        borderZone:SetFrameLevel(mainFrame:GetFrameLevel() + 1)
        AddHoverZone(borderZone, SECTION_BORDER)

        -- Container sizing
        local totalH = frameH + 30  -- padding above and below
        pf:SetSize(localParentW, totalH / previewScale)

        -- Update function
        function pf:Update()
            local d = DB()
            if not d then return end

            local w = d.frameWidth
            local h = d.frameHeight
            local p = d.framePadding
            local pwH = d.powerBarEnabled and d.powerBarHeight or 0

            mainFrame:SetSize(w, h)

            -- Background
            local bg = d.bgColor
            bgTex:SetColorTexture(bg.r, bg.g, bg.b, bg.a)

            -- Health zone
            healthZone:ClearAllPoints()
            healthZone:SetPoint("TOPLEFT", p, -p)
            healthZone:SetPoint("BOTTOMRIGHT", -p, p + pwH)

            -- Health fill
            local barW = w - p * 2
            local hpPct = _previewHpPct or 0.72
            healthFill:SetWidth(math.max(barW * hpPct, 1))
            healthFill:SetTexture(d.healthTexture)

            -- Class color for preview (use Ellesmere teal-ish)
            if d.healthColorMode == "CLASS" then
                healthFill:SetVertexColor(0.05, 0.82, 0.62, 1)
            elseif d.healthColorMode == "HEALTH_GRADIENT" then
                local r = math.min(2 * (1 - hpPct), 1)
                local g = math.min(2 * hpPct, 1)
                healthFill:SetVertexColor(r, g, 0, 1)
            else
                local cc = d.healthCustomColor
                healthFill:SetVertexColor(cc.r, cc.g, cc.b, 1)
            end

            -- Missing health
            local mh = d.missingHealthColor
            missingTex:SetColorTexture(mh.r, mh.g, mh.b, 1)

            -- Heal prediction
            if d.healPrediction then
                local predPct = math.min(hpPct + 0.12, 1)
                local startX = hpPct * barW
                local predW = (predPct - hpPct) * barW
                if predW > 1 then
                    healPredTex:ClearAllPoints()
                    healPredTex:SetPoint("TOPLEFT", healthZone, "TOPLEFT", startX, 0)
                    healPredTex:SetPoint("BOTTOMLEFT", healthZone, "BOTTOMLEFT", startX, 0)
                    healPredTex:SetWidth(predW)
                    local hp = d.healPredColor
                    healPredTex:SetVertexColor(hp.r, hp.g, hp.b, hp.a)
                    healPredTex:Show()
                else
                    healPredTex:Hide()
                end
            else
                healPredTex:Hide()
            end

            -- Absorb
            if d.absorbEnabled then
                local absPct = _previewAbsorbPct or 0.10
                local absW = absPct * barW
                if absW > 1 then
                    absorbTex:ClearAllPoints()
                    absorbTex:SetPoint("TOPLEFT", healthZone, "TOPLEFT", hpPct * barW, 0)
                    absorbTex:SetPoint("BOTTOMLEFT", healthZone, "BOTTOMLEFT", hpPct * barW, 0)
                    absorbTex:SetWidth(math.min(absW, barW))
                    local ab = d.absorbColor
                    absorbTex:SetVertexColor(ab.r, ab.g, ab.b, ab.a)
                    absorbTex:Show()
                else
                    absorbTex:Hide()
                end
            else
                absorbTex:Hide()
            end

            -- Power bar
            if powerZone and d.powerBarEnabled then
                powerZone:ClearAllPoints()
                powerZone:SetPoint("BOTTOMLEFT", p, p)
                powerZone:SetPoint("BOTTOMRIGHT", -p, p)
                powerZone:SetHeight(d.powerBarHeight)
                if powerZone._fill then
                    local ppct = _previewPowerPct or 0.65
                    powerZone._fill:SetWidth(math.max((w - p * 2) * ppct, 1))
                end
                powerZone:Show()
            elseif powerZone then
                powerZone:Hide()
            end

            -- Name
            local _rfPvFont = (EllesmereUI and EllesmereUI.GetFontPath and EllesmereUI.GetFontPath("raidFrames")) or d.nameFont
            nameFS:SetFont(_rfPvFont, d.nameFontSize, d.nameOutline)
            nameFS:ClearAllPoints()
            nameFS:SetPoint(d.namePosition, mainFrame, d.namePosition, 0, d.nameYOffset)

            -- Health text
            healthFS:SetFont(_rfPvFont, d.healthFontSize, d.healthOutline)
            healthFS:ClearAllPoints()
            healthFS:SetPoint(d.healthPosition, mainFrame, d.healthPosition, 0, d.healthYOffset)
            if d.healthTextEnabled and d.healthFormat ~= "NONE" then
                if d.healthFormat == "PERCENT" then
                    healthFS:SetText(math.floor(hpPct * 100) .. "%")
                elseif d.healthFormat == "DEFICIT" then
                    healthFS:SetText("-" .. math.floor((1 - hpPct) * 150000 / 1000) .. "K")
                elseif d.healthFormat == "CURRENT" then
                    healthFS:SetText(math.floor(hpPct * 150) .. "K")
                end
                healthFS:Show()
            else
                healthFS:Hide()
            end

            -- Role icon
            roleIconTex:SetSize(d.roleIconSize, d.roleIconSize)
            roleIconTex:ClearAllPoints()
            roleIconTex:SetPoint(d.roleIconPosition, mainFrame, d.roleIconPosition,
                d.roleIconXOffset, d.roleIconYOffset)

            -- Update container height
            pf:SetSize(localParentW, (h + 30) / previewScale)
        end

        activePreview = pf
        pf:Update()

        return (frameH + 30)
    end

    ---------------------------------------------------------------------------
    --  Display page builder
    ---------------------------------------------------------------------------
    local function BuildDisplayPage(pageName, parent, yOffset)
        local y = yOffset
        local h

        -------------------------------------------------------------------
        --  FRAME SIZE & LAYOUT
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_FRAME, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Frame Width", min=40, max=200, step=1,
              getValue=function() return DBVal("frameWidth") end,
              setValue=function(v) SetDB("frameWidth", v); RefreshLayout(); UpdatePreview() end },
            { type="slider", text="Frame Height", min=20, max=100, step=1,
              getValue=function() return DBVal("frameHeight") end,
              setValue=function(v) SetDB("frameHeight", v); RefreshLayout(); UpdatePreview() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Frame Spacing", min=0, max=20, step=1,
              getValue=function() return DBVal("frameSpacing") end,
              setValue=function(v) SetDB("frameSpacing", v); ERF:OnGroupChanged() end },
            { type="slider", text="Frame Padding", min=0, max=8, step=1,
              getValue=function() return DBVal("framePadding") end,
              setValue=function(v) SetDB("framePadding", v); RefreshLayout(); UpdatePreview() end });  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -------------------------------------------------------------------
        --  HEALTH BAR
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_HEALTH_BAR, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="dropdown", text="Health Color Mode",
              values={ CLASS="Class Color", HEALTH_GRADIENT="Health Gradient", CUSTOM="Custom" },
              order={ "CLASS", "HEALTH_GRADIENT", "CUSTOM" },
              getValue=function() return DBVal("healthColorMode") end,
              setValue=function(v) SetDB("healthColorMode", v); RefreshAll(); UpdatePreview() end },
            { type="colorpicker", text="Custom Health Color",
              getValue=function() return DBColor("healthCustomColor") end,
              setValue=function(r, g, b)
                  SetDB("healthCustomColor", { r=r, g=g, b=b })
                  RefreshAll(); UpdatePreview()
              end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="colorpicker", text="Missing Health Color",
              getValue=function() return DBColor("missingHealthColor") end,
              setValue=function(r, g, b)
                  SetDB("missingHealthColor", { r=r, g=g, b=b })
                  RefreshAll(); UpdatePreview()
              end },
            { type="toggle", text="Heal Prediction",
              getValue=function() return DBVal("healPrediction") end,
              setValue=function(v) SetDB("healPrediction", v); RefreshAll(); UpdatePreview() end });  y = y - h

        local healPredRow
        healPredRow, h = W:DualRow(parent, y,
            { type="colorpicker", text="Heal Prediction Color",
              getValue=function()
                  local c = DBVal("healPredColor")
                  return c.r, c.g, c.b, c.a
              end,
              setValue=function(r, g, b, a)
                  SetDB("healPredColor", { r=r, g=g, b=b, a=a or 0.45 })
                  RefreshAll(); UpdatePreview()
              end,
              hasAlpha=true },
            { type="toggle", text="Absorb Shield",
              getValue=function() return DBVal("absorbEnabled") end,
              setValue=function(v) SetDB("absorbEnabled", v); RefreshAll(); UpdatePreview() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="colorpicker", text="Absorb Color",
              getValue=function()
                  local c = DBVal("absorbColor")
                  return c.r, c.g, c.b, c.a
              end,
              setValue=function(r, g, b, a)
                  SetDB("absorbColor", { r=r, g=g, b=b, a=a or 0.55 })
                  RefreshAll(); UpdatePreview()
              end,
              hasAlpha=true },
            { type="toggle", text="Absorb Overflow",
              getValue=function() return DBVal("absorbOverflow") end,
              setValue=function(v) SetDB("absorbOverflow", v); RefreshAll(); UpdatePreview() end });  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -------------------------------------------------------------------
        --  POWER BAR
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_POWER_BAR, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Power Bar",
              getValue=function() return DBVal("powerBarEnabled") end,
              setValue=function(v) SetDB("powerBarEnabled", v); RefreshLayout(); UpdatePreview()
                  EllesmereUI:RefreshPage()
              end },
            { type="slider", text="Power Bar Height", min=1, max=12, step=1,
              getValue=function() return DBVal("powerBarHeight") end,
              setValue=function(v) SetDB("powerBarHeight", v); RefreshLayout(); UpdatePreview() end });  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -------------------------------------------------------------------
        --  NAME TEXT
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_NAME_TEXT, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Font Size", min=6, max=18, step=1,
              getValue=function() return DBVal("nameFontSize") end,
              setValue=function(v) SetDB("nameFontSize", v); RefreshAll(); UpdatePreview() end },
            nil);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="dropdown", text="Name Position",
              values={ TOP="Top", CENTER="Center", BOTTOM="Bottom" },
              order={ "TOP", "CENTER", "BOTTOM" },
              getValue=function() return DBVal("namePosition") end,
              setValue=function(v) SetDB("namePosition", v); RefreshAll(); UpdatePreview() end },
            { type="slider", text="Name Y Offset", min=-20, max=20, step=1,
              getValue=function() return DBVal("nameYOffset") end,
              setValue=function(v) SetDB("nameYOffset", v); RefreshAll(); UpdatePreview() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="dropdown", text="Name Color",
              values={ CLASS="Class Color", WHITE="White", CUSTOM="Custom" },
              order={ "CLASS", "WHITE", "CUSTOM" },
              getValue=function() return DBVal("nameColorMode") end,
              setValue=function(v) SetDB("nameColorMode", v); RefreshAll() end },
            { type="slider", text="Name Length", min=3, max=20, step=1,
              getValue=function() return DBVal("nameLength") end,
              setValue=function(v) SetDB("nameLength", v); RefreshAll() end });  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -------------------------------------------------------------------
        --  HEALTH TEXT
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_HEALTH_TEXT, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Health Text",
              getValue=function() return DBVal("healthTextEnabled") end,
              setValue=function(v) SetDB("healthTextEnabled", v); RefreshAll(); UpdatePreview()
                  EllesmereUI:RefreshPage()
              end },
            { type="dropdown", text="Health Format",
              values={ PERCENT="Percent", CURRENT="Current", DEFICIT="Deficit", NONE="None" },
              order={ "PERCENT", "CURRENT", "DEFICIT", "NONE" },
              getValue=function() return DBVal("healthFormat") end,
              setValue=function(v) SetDB("healthFormat", v); RefreshAll(); UpdatePreview() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Health Font Size", min=6, max=18, step=1,
              getValue=function() return DBVal("healthFontSize") end,
              setValue=function(v) SetDB("healthFontSize", v); RefreshAll(); UpdatePreview() end },
            nil);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="dropdown", text="Health Position",
              values={ TOP="Top", CENTER="Center", BOTTOM="Bottom" },
              order={ "TOP", "CENTER", "BOTTOM" },
              getValue=function() return DBVal("healthPosition") end,
              setValue=function(v) SetDB("healthPosition", v); RefreshAll(); UpdatePreview() end },
            { type="slider", text="Health Y Offset", min=-20, max=20, step=1,
              getValue=function() return DBVal("healthYOffset") end,
              setValue=function(v) SetDB("healthYOffset", v); RefreshAll(); UpdatePreview() end });  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -------------------------------------------------------------------
        --  BORDER & BACKGROUND
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_BORDER, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Border",
              getValue=function() return DBVal("borderEnabled") end,
              setValue=function(v) SetDB("borderEnabled", v); RefreshAll(); UpdatePreview() end },
            { type="slider", text="Border Size", min=1, max=4, step=1,
              getValue=function() return DBVal("borderSize") end,
              setValue=function(v) SetDB("borderSize", v); RefreshAll(); UpdatePreview() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="colorpicker", text="Border Color",
              getValue=function()
                  local c = DBVal("borderColor")
                  return c.r, c.g, c.b, c.a
              end,
              setValue=function(r, g, b, a)
                  SetDB("borderColor", { r=r, g=g, b=b, a=a or 1 })
                  RefreshAll(); UpdatePreview()
              end,
              hasAlpha=true },
            { type="colorpicker", text="Background Color",
              getValue=function()
                  local c = DBVal("bgColor")
                  return c.r, c.g, c.b, c.a
              end,
              setValue=function(r, g, b, a)
                  SetDB("bgColor", { r=r, g=g, b=b, a=a or 0.85 })
                  RefreshAll(); UpdatePreview()
              end,
              hasAlpha=true });  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -------------------------------------------------------------------
        --  ICONS
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_ICONS, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Role Icon",
              getValue=function() return DBVal("roleIconEnabled") end,
              setValue=function(v) SetDB("roleIconEnabled", v); RefreshAll(); UpdatePreview() end },
            { type="slider", text="Role Icon Size", min=8, max=24, step=1,
              getValue=function() return DBVal("roleIconSize") end,
              setValue=function(v) SetDB("roleIconSize", v); RefreshAll(); UpdatePreview() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Raid Target Icon",
              getValue=function() return DBVal("raidTargetEnabled") end,
              setValue=function(v) SetDB("raidTargetEnabled", v); RefreshAll() end },
            { type="slider", text="Raid Target Size", min=8, max=32, step=1,
              getValue=function() return DBVal("raidTargetSize") end,
              setValue=function(v) SetDB("raidTargetSize", v); RefreshAll() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Ready Check Icon",
              getValue=function() return DBVal("readyCheckEnabled") end,
              setValue=function(v) SetDB("readyCheckEnabled", v); RefreshAll() end },
            { type="slider", text="Ready Check Size", min=12, max=32, step=1,
              getValue=function() return DBVal("readyCheckSize") end,
              setValue=function(v) SetDB("readyCheckSize", v); RefreshAll() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Center Icon (Defensives)",
              getValue=function() return DBVal("centerIconEnabled") end,
              setValue=function(v) SetDB("centerIconEnabled", v); RefreshAll() end },
            { type="slider", text="Center Icon Size", min=12, max=40, step=1,
              getValue=function() return DBVal("centerIconSize") end,
              setValue=function(v) SetDB("centerIconSize", v); RefreshAll() end });  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -------------------------------------------------------------------
        --  BUFFS & DEBUFFS
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_AURAS, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Debuffs",
              getValue=function() return DBVal("showDebuffs") end,
              setValue=function(v) SetDB("showDebuffs", v); RefreshAll(); UpdatePreview() end },
            { type="slider", text="Debuff Icon Size", min=10, max=32, step=1,
              getValue=function() return DBVal("debuffSize") end,
              setValue=function(v) SetDB("debuffSize", v); RefreshAll(); UpdatePreview() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Max Debuffs", min=1, max=8, step=1,
              getValue=function() return DBVal("debuffMax") end,
              setValue=function(v) SetDB("debuffMax", v); RefreshAll(); UpdatePreview() end },
            { type="toggle", text="Debuff Type Border",
              getValue=function() return DBVal("debuffTypeColor") end,
              setValue=function(v) SetDB("debuffTypeColor", v); RefreshAll() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Buffs",
              getValue=function() return DBVal("showBuffs") end,
              setValue=function(v) SetDB("showBuffs", v); RefreshAll() end },
            { type="slider", text="Buff Icon Size", min=10, max=32, step=1,
              getValue=function() return DBVal("buffSize") end,
              setValue=function(v) SetDB("buffSize", v); RefreshAll() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Max Buffs", min=1, max=8, step=1,
              getValue=function() return DBVal("buffMax") end,
              setValue=function(v) SetDB("buffMax", v); RefreshAll() end },
            { type="label", text="" });  y = y - h

        return y
    end

    ---------------------------------------------------------------------------
    --  Colors page builder
    ---------------------------------------------------------------------------
    local function BuildColorsPage(pageName, parent, yOffset)
        local y = yOffset
        local h

        -------------------------------------------------------------------
        --  HIGHLIGHTS & EFFECTS
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_HIGHLIGHTS, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Dispel Highlight",
              getValue=function() return DBVal("dispelHighlight") end,
              setValue=function(v) SetDB("dispelHighlight", v); RefreshAll() end },
            { type="slider", text="Dispel Glow Alpha", min=0.1, max=1.0, step=0.05,
              getValue=function() return DBVal("dispelGlowAlpha") end,
              setValue=function(v) SetDB("dispelGlowAlpha", v); RefreshAll() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Aggro Highlight",
              getValue=function() return DBVal("aggroHighlight") end,
              setValue=function(v) SetDB("aggroHighlight", v); RefreshAll() end },
            { type="colorpicker", text="Aggro Color",
              getValue=function()
                  local c = DBVal("aggroColor")
                  return c.r, c.g, c.b, c.a
              end,
              setValue=function(r, g, b, a)
                  SetDB("aggroColor", { r=r, g=g, b=b, a=a or 0.6 })
                  RefreshAll()
              end,
              hasAlpha=true });  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -------------------------------------------------------------------
        --  ROLE TINT (unique feature)
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_ROLE_TINT, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Enable Role Tint",
              tooltip="Adds a subtle background color tint based on the unit's role (Tank/Healer/DPS). Helps quickly identify roles at a glance.",
              getValue=function() return DBVal("roleTintEnabled") end,
              setValue=function(v) SetDB("roleTintEnabled", v); RefreshAll()
                  EllesmereUI:RefreshPage()
              end },
            { type="slider", text="Tint Opacity", min=0.02, max=0.25, step=0.01,
              getValue=function() return DBVal("roleTintAlpha") end,
              setValue=function(v) SetDB("roleTintAlpha", v); RefreshAll() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="colorpicker", text="Tank Tint",
              getValue=function() return DBColor("roleTintTank") end,
              setValue=function(r, g, b)
                  SetDB("roleTintTank", { r=r, g=g, b=b })
                  RefreshAll()
              end },
            { type="colorpicker", text="Healer Tint",
              getValue=function() return DBColor("roleTintHealer") end,
              setValue=function(r, g, b)
                  SetDB("roleTintHealer", { r=r, g=g, b=b })
                  RefreshAll()
              end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="colorpicker", text="DPS Tint",
              getValue=function() return DBColor("roleTintDamager") end,
              setValue=function(r, g, b)
                  SetDB("roleTintDamager", { r=r, g=g, b=b })
                  RefreshAll()
              end },
            { type="label", text="" });  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -------------------------------------------------------------------
        --  STATUS TEXT
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, "STATUS TEXT", y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Status Font Size", min=6, max=18, step=1,
              getValue=function() return DBVal("statusFontSize") end,
              setValue=function(v) SetDB("statusFontSize", v); RefreshAll() end },
            nil);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="colorpicker", text="Status Text Color",
              getValue=function() return DBColor("statusColor") end,
              setValue=function(r, g, b)
                  SetDB("statusColor", { r=r, g=g, b=b })
                  RefreshAll()
              end },
            { type="label", text="" });  y = y - h

        return y
    end

    ---------------------------------------------------------------------------
    --  General page builder
    ---------------------------------------------------------------------------
    local function BuildGeneralPage(pageName, parent, yOffset)
        local y = yOffset
        local h

        -------------------------------------------------------------------
        --  LAYOUT & SORTING
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_LAYOUT, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="dropdown", text="Growth Direction",
              values={ DOWN="Down", UP="Up", LEFT="Left", RIGHT="Right" },
              order={ "DOWN", "UP", "LEFT", "RIGHT" },
              getValue=function() return DBVal("growthDirection") end,
              setValue=function(v) SetDB("growthDirection", v); ERF:OnGroupChanged() end },
            { type="dropdown", text="Group By",
              values={ GROUP="Group", ROLE="Role", CLASS="Class", NONE="None" },
              order={ "GROUP", "ROLE", "CLASS", "NONE" },
              getValue=function() return DBVal("groupBy") end,
              setValue=function(v) SetDB("groupBy", v); ERF:OnGroupChanged() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="dropdown", text="Sort By",
              values={ INDEX="Index", NAME="Name" },
              order={ "INDEX", "NAME" },
              getValue=function() return DBVal("sortBy") end,
              setValue=function(v) SetDB("sortBy", v); ERF:OnGroupChanged() end },
            { type="dropdown", text="Raid Layout",
              values={ BY_GROUP="By Group", COMBINED="Combined" },
              order={ "BY_GROUP", "COMBINED" },
              getValue=function() return DBVal("raidLayout") end,
              setValue=function(v) SetDB("raidLayout", v); ERF:OnGroupChanged() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Group Spacing", min=0, max=30, step=1,
              getValue=function() return DBVal("groupSpacing") end,
              setValue=function(v) SetDB("groupSpacing", v); ERF:OnGroupChanged() end },
            { type="slider", text="Column Spacing", min=0, max=30, step=1,
              getValue=function() return DBVal("columnSpacing") end,
              setValue=function(v) SetDB("columnSpacing", v); ERF:OnGroupChanged() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="dropdown", text="Column Growth",
              values={ LEFT="Left", RIGHT="Right" },
              order={ "LEFT", "RIGHT" },
              getValue=function() return DBVal("columnGrowth") end,
              setValue=function(v) SetDB("columnGrowth", v); ERF:OnGroupChanged() end },
            { type="slider", text="Max Columns", min=1, max=8, step=1,
              getValue=function() return DBVal("maxColumns") end,
              setValue=function(v) SetDB("maxColumns", v); ERF:OnGroupChanged() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Units Per Column", min=1, max=40, step=1,
              getValue=function() return DBVal("unitsPerColumn") end,
              setValue=function(v) SetDB("unitsPerColumn", v); ERF:OnGroupChanged() end },
            { type="label", text="" });  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -------------------------------------------------------------------
        --  VISIBILITY
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_VISIBILITY, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Player",
              getValue=function() return DBVal("showPlayer") end,
              setValue=function(v) SetDB("showPlayer", v); ERF:OnGroupChanged() end },
            { type="toggle", text="Show Solo",
              tooltip="Show raid frames even when not in a group (useful for testing).",
              getValue=function() return DBVal("showSolo") end,
              setValue=function(v) SetDB("showSolo", v); ERF:OnGroupChanged() end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Pets",
              getValue=function() return DBVal("showPets") end,
              setValue=function(v) SetDB("showPets", v); ERF:OnGroupChanged() end },
            { type="label", text="" });  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -------------------------------------------------------------------
        --  RANGE & FADING
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_RANGE, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Range Fade",
              tooltip="Smoothly fade out-of-range units instead of a hard cutoff.",
              getValue=function() return DBVal("rangeFadeEnabled") end,
              setValue=function(v) SetDB("rangeFadeEnabled", v); RefreshAll() end },
            { type="slider", text="Out-of-Range Alpha", min=0.1, max=0.8, step=0.05,
              getValue=function() return DBVal("rangeFadeAlpha") end,
              setValue=function(v) SetDB("rangeFadeAlpha", v); RefreshAll() end });  y = y - h

        return y
    end

    ---------------------------------------------------------------------------
    --  Register module with EllesmereUI
    ---------------------------------------------------------------------------
    EllesmereUI:RegisterModule("EllesmereUIRaidFrames", {
        title       = "Raid Frames",
        description = "Custom party and raid unit frames.",
        pages       = { PAGE_DISPLAY, PAGE_COLORS, PAGE_GENERAL },
        buildPage   = function(pageName, parent, yOffset)
            if pageName == PAGE_DISPLAY then
                return BuildDisplayPage(pageName, parent, yOffset)
            elseif pageName == PAGE_COLORS then
                return BuildColorsPage(pageName, parent, yOffset)
            elseif pageName == PAGE_GENERAL then
                return BuildGeneralPage(pageName, parent, yOffset)
            end
        end,
        getHeaderBuilder = function(pageName)
            if pageName == PAGE_DISPLAY then
                _displayHeaderBuilder = function(headerParent, headerW)
                    RandomizePreviewValues()
                    return BuildRaidFramePreview(headerParent, headerW)
                end
                return _displayHeaderBuilder
            end
            return nil
        end,
        onPageCacheRestore = function(pageName)
            if pageName == PAGE_DISPLAY then
                RandomizePreviewValues()
                if activePreview and activePreview.Update then activePreview:Update() end
            end
        end,
        onReset = function()
            EllesmereUI:InvalidatePageCache()
            if ERF.db then
                ERF.db:ResetProfile()
            end
            ERF:OnGroupChanged()
        end,
    })

end)  -- end PLAYER_LOGIN
