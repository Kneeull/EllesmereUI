-------------------------------------------------------------------------------
--  EUI_MinimapChat_Options.lua
--  Registers the Minimap & Chat module with EllesmereUI
--  Pages: Minimap | Friends List | Bags | Minimap Skin
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local PAGE_MINIMAP   = "Minimap"
local PAGE_FRIENDS   = "Friends List"
local PAGE_BAGS      = "Bags"
local PAGE_SKIN      = "Minimap Skin"

local SECTION_THEME       = "THEME"
local SECTION_CLOCK       = "CLOCK"
local SECTION_ZOOM        = "ZOOM"
local SECTION_FRIENDS     = "FRIENDS LIST"
local SECTION_GROUPS      = "FRIEND GROUPS"
local SECTION_FILTERS     = "FILTERS"
local SECTION_DISPLAY     = "DISPLAY"
local SECTION_BAG_GENERAL = "GENERAL"
local SECTION_BAG_DISPLAY = "DISPLAY"
local SECTION_BAG_AUTO    = "AUTOMATION"
local SECTION_SHAPE       = "SHAPE"
local SECTION_BORDER      = "BORDER"

local floor = math.floor

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    if not EllesmereUI or not EllesmereUI.RegisterModule then return end

    ---------------------------------------------------------------------------
    --  DB helpers
    ---------------------------------------------------------------------------
    local db
    C_Timer.After(0, function()
        db = _G._EMC_AceDB
    end)

    local function DB()
        if not db then db = _G._EMC_AceDB end
        return db and db.profile
    end

    local function MinimapDB()
        local p = DB()
        return p and p.minimap
    end

    local function FriendsDB()
        local p = DB()
        if not p then return {} end
        if not p.friends then p.friends = {} end
        return p.friends
    end

    local function BagsDB()
        local p = DB()
        if not p then return {} end
        if not p.bags then p.bags = {} end
        return p.bags
    end

    local function SkinDB()
        local p = DB()
        if not p then return {} end
        if not p.minimapSkin then p.minimapSkin = {} end
        return p.minimapSkin
    end

    ---------------------------------------------------------------------------
    --  Refresh helpers
    ---------------------------------------------------------------------------
    local function RefreshMinimap()
        if _G._EMC_Apply then _G._EMC_Apply() end
    end

    local function RefreshSkin()
        if _G._EMS_ApplyMinimapSkin then _G._EMS_ApplyMinimapSkin() end
    end

    local function RefreshFriends()
        if _G._ECF_RebuildGroupsData then _G._ECF_RebuildGroupsData() end
    end

    local function RefreshBags()
        if _G._ECB_RefreshBagFrame then _G._ECB_RefreshBagFrame() end
    end


    ---------------------------------------------------------------------------
    --  Minimap Page
    ---------------------------------------------------------------------------
    local function BuildMinimapPage(pageName, parent, yOffset)
        local W = EllesmereUI.Widgets
        local y = yOffset

        EllesmereUI:ClearContentHeader()

        -----------------------------------------------------------------------
        --  THEME
        -----------------------------------------------------------------------
        local _, h
        _, h = W:SectionHeader(parent, SECTION_THEME, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="dropdown", text="Theme",
              values={ modern = "Modern", classic = "Classic (Blizzard)" },
              order={ "modern", "classic" },
              getValue=function() local m = MinimapDB(); return m and m.theme or "modern" end,
              setValue=function(v)
                local m = MinimapDB(); if not m then return end
                m.theme = v
                RefreshMinimap()
              end },
            { type="slider", text="Scale", min=0.5, max=2.0, step=0.05,
              getValue=function() local m = MinimapDB(); return m and m.scale or 1 end,
              setValue=function(v)
                local m = MinimapDB(); if not m then return end
                m.scale = v
                if MinimapCluster then MinimapCluster:SetScale(v) end
              end }
        );  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -----------------------------------------------------------------------
        --  CLOCK
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_CLOCK, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Clock",
              getValue=function() local m = MinimapDB(); return m and m.clockShow end,
              setValue=function(v)
                local m = MinimapDB(); if not m then return end
                m.clockShow = v
                RefreshMinimap()
              end },
            { type="toggle", text="24-Hour Format",
              getValue=function() local m = MinimapDB(); return m and m.clock24h end,
              setValue=function(v)
                local m = MinimapDB(); if not m then return end
                m.clock24h = v
              end }
        );  y = y - h

        _, h = W:DualRow(parent, y,
            { type="dropdown", text="Time Source",
              values={ ["local"] = "Local Time", server = "Server Time" },
              order={ "local", "server" },
              getValue=function() local m = MinimapDB(); return m and m.clockMode or "local" end,
              setValue=function(v)
                local m = MinimapDB(); if not m then return end
                m.clockMode = v
              end },
            { type="toggle", text="Mouse Wheel Zoom",
              getValue=function() local m = MinimapDB(); return m and m.mouseZoom end,
              setValue=function(v)
                local m = MinimapDB(); if not m then return end
                m.mouseZoom = v
              end }
        );  y = y - h

        return y
    end

    ---------------------------------------------------------------------------
    --  Friends List Page
    ---------------------------------------------------------------------------
    local function BuildFriendsPage(pageName, parent, yOffset)
        local W = EllesmereUI.Widgets
        local y = yOffset

        EllesmereUI:ClearContentHeader()

        -----------------------------------------------------------------------
        --  DISPLAY
        -----------------------------------------------------------------------
        local _, h
        _, h = W:SectionHeader(parent, SECTION_DISPLAY, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Enable Custom Friends",
              getValue=function() return FriendsDB().enabled ~= false end,
              setValue=function(v)
                FriendsDB().enabled = v
                EllesmereUI:RefreshPage()
              end },
            { type="toggle", text="Class-Colored Names",
              disabled=function() return FriendsDB().enabled == false end,
              disabledTooltip="Enable Custom Friends",
              getValue=function() return FriendsDB().classColors ~= false end,
              setValue=function(v)
                FriendsDB().classColors = v
                RefreshFriends()
              end }
        );  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Level",
              disabled=function() return FriendsDB().enabled == false end,
              disabledTooltip="Enable Custom Friends",
              getValue=function() return FriendsDB().showLevel ~= false end,
              setValue=function(v)
                FriendsDB().showLevel = v
                RefreshFriends()
              end },
            { type="toggle", text="Hide Max Level",
              disabled=function() return FriendsDB().enabled == false end,
              disabledTooltip="Enable Custom Friends",
              getValue=function() return FriendsDB().hideMaxLevel ~= false end,
              setValue=function(v)
                FriendsDB().hideMaxLevel = v
                RefreshFriends()
              end }
        );  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Spec",
              disabled=function() return FriendsDB().enabled == false end,
              disabledTooltip="Enable Custom Friends",
              getValue=function() return FriendsDB().showSpec ~= false end,
              setValue=function(v)
                FriendsDB().showSpec = v
                RefreshFriends()
              end },
            { type="toggle", text="Show Faction Icons",
              disabled=function() return FriendsDB().enabled == false end,
              disabledTooltip="Enable Custom Friends",
              getValue=function() return FriendsDB().showFaction ~= false end,
              setValue=function(v)
                FriendsDB().showFaction = v
                RefreshFriends()
              end }
        );  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -----------------------------------------------------------------------
        --  FILTERS
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_FILTERS, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Hide Offline Friends",
              disabled=function() return FriendsDB().enabled == false end,
              disabledTooltip="Enable Custom Friends",
              getValue=function() return FriendsDB().hideOffline or false end,
              setValue=function(v)
                FriendsDB().hideOffline = v
                RefreshFriends()
              end },
            { type="toggle", text="Hide AFK Friends",
              disabled=function() return FriendsDB().enabled == false end,
              disabledTooltip="Enable Custom Friends",
              getValue=function() return FriendsDB().hideAFK or false end,
              setValue=function(v)
                FriendsDB().hideAFK = v
                RefreshFriends()
              end }
        );  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -----------------------------------------------------------------------
        --  FRIEND GROUPS
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_GROUPS, y);  y = y - h

        -- Info text about friend groups
        do
            local info = parent:CreateFontString(nil, "OVERLAY")
            local fontPath = EllesmereUI.EXPRESSWAY or "Fonts\\FRIZQT__.TTF"
            info:SetFont(fontPath, 11, "")
            info:SetShadowOffset(1, -1)
            info:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
            info:SetWidth(parent:GetWidth() - 40)
            info:SetJustifyH("LEFT")
            info:SetTextColor(0.7, 0.7, 0.7, 1)
            info:SetText("Friend groups are managed by right-clicking friends in the Blizzard Friends List. Groups are stored locally in your saved variables (not in friend notes).\n\nOpen the Friends List (default: O key) to manage groups.")
            local textH = info:GetStringHeight() + 8
            y = y - textH
        end

        return y
    end


    ---------------------------------------------------------------------------
    --  Bags Page
    ---------------------------------------------------------------------------
    local function BuildBagsPage(pageName, parent, yOffset)
        local W = EllesmereUI.Widgets
        local y = yOffset

        EllesmereUI:ClearContentHeader()

        -----------------------------------------------------------------------
        --  GENERAL
        -----------------------------------------------------------------------
        local _, h
        _, h = W:SectionHeader(parent, SECTION_BAG_GENERAL, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Enable Custom Bags",
              getValue=function() return BagsDB().enabled or false end,
              setValue=function(v)
                BagsDB().enabled = v
                EllesmereUI:RefreshPage()
              end },
            { type="slider", text="Scale", min=0.5, max=2.0, step=0.05,
              disabled=function() return not BagsDB().enabled end,
              disabledTooltip="Enable Custom Bags",
              getValue=function() return BagsDB().scale or 1 end,
              setValue=function(v)
                BagsDB().scale = v
                RefreshBags()
              end }
        );  y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Columns", min=6, max=20, step=1,
              disabled=function() return not BagsDB().enabled end,
              disabledTooltip="Enable Custom Bags",
              getValue=function() return BagsDB().columns or 12 end,
              setValue=function(v)
                BagsDB().columns = v
                RefreshBags()
              end },
            { type="dropdown", text="Sort Direction",
              disabled=function() return not BagsDB().enabled end,
              disabledTooltip="Enable Custom Bags",
              values={ right = "Left to Right", left = "Right to Left" },
              order={ "right", "left" },
              getValue=function() return BagsDB().sortDirection or "right" end,
              setValue=function(v)
                BagsDB().sortDirection = v
                RefreshBags()
              end }
        );  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -----------------------------------------------------------------------
        --  DISPLAY
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_BAG_DISPLAY, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Item Level",
              disabled=function() return not BagsDB().enabled end,
              disabledTooltip="Enable Custom Bags",
              getValue=function() return BagsDB().showItemLevel ~= false end,
              setValue=function(v)
                BagsDB().showItemLevel = v
                RefreshBags()
              end },
            { type="toggle", text="Quality Color Borders",
              disabled=function() return not BagsDB().enabled end,
              disabledTooltip="Enable Custom Bags",
              getValue=function() return BagsDB().showQualityBorder ~= false end,
              setValue=function(v)
                BagsDB().showQualityBorder = v
                RefreshBags()
              end }
        );  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Highlight Junk Items",
              disabled=function() return not BagsDB().enabled end,
              disabledTooltip="Enable Custom Bags",
              getValue=function() return BagsDB().highlightJunk ~= false end,
              setValue=function(v)
                BagsDB().highlightJunk = v
                RefreshBags()
              end },
            { type="toggle", text="New Item Glow",
              disabled=function() return not BagsDB().enabled end,
              disabledTooltip="Enable Custom Bags",
              getValue=function() return BagsDB().showNewGlow ~= false end,
              setValue=function(v)
                BagsDB().showNewGlow = v
                RefreshBags()
              end }
        );  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Slot Count",
              disabled=function() return not BagsDB().enabled end,
              disabledTooltip="Enable Custom Bags",
              getValue=function() return BagsDB().showSlotCount ~= false end,
              setValue=function(v)
                BagsDB().showSlotCount = v
                RefreshBags()
              end },
            { type="toggle", text="Focus Search on Open",
              disabled=function() return not BagsDB().enabled end,
              disabledTooltip="Enable Custom Bags",
              getValue=function() return BagsDB().searchOnOpen or false end,
              setValue=function(v)
                BagsDB().searchOnOpen = v
              end }
        );  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -----------------------------------------------------------------------
        --  AUTOMATION
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_BAG_AUTO, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Auto Vendor Junk",
              disabled=function() return not BagsDB().enabled end,
              disabledTooltip="Enable Custom Bags",
              getValue=function() return BagsDB().autoVendorJunk or false end,
              setValue=function(v)
                BagsDB().autoVendorJunk = v
              end },
            nil
        );  y = y - h

        return y
    end


    ---------------------------------------------------------------------------
    --  Minimap Skin Page
    ---------------------------------------------------------------------------
    local function BuildSkinPage(pageName, parent, yOffset)
        local W = EllesmereUI.Widgets
        local y = yOffset

        EllesmereUI:ClearContentHeader()

        local shapeLabels = _G._EMS_SHAPE_LABELS or {}

        -- Build dropdown values/order from shape labels
        local shapeValues = {}
        local shapeOrder = {}
        for _, entry in ipairs(shapeLabels) do
            shapeValues[entry.key] = entry.label
            shapeOrder[#shapeOrder + 1] = entry.key
        end

        -----------------------------------------------------------------------
        --  SHAPE
        -----------------------------------------------------------------------
        local _, h
        _, h = W:SectionHeader(parent, SECTION_SHAPE, y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="dropdown", text="Minimap Shape",
              values=shapeValues,
              order=shapeOrder,
              getValue=function() return SkinDB().shape or "square" end,
              setValue=function(v)
                SkinDB().shape = v
                RefreshSkin()
                RefreshMinimap()
                EllesmereUI:RefreshPage()
              end },
            { type="toggle", text="Show Border",
              getValue=function() return SkinDB().showBorder ~= false end,
              setValue=function(v)
                SkinDB().showBorder = v
                RefreshSkin()
                RefreshMinimap()
                EllesmereUI:RefreshPage()
              end }
        );  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -----------------------------------------------------------------------
        --  BORDER
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_BORDER, y);  y = y - h

        local currentShape = SkinDB().shape or "square"
        local isSquare = (currentShape == "square")

        if isSquare then
            -- Square border: size slider + color swatch
            _, h = W:DualRow(parent, y,
                { type="slider", text="Border Size", min=1, max=6, step=1,
                  disabled=function() return not SkinDB().showBorder end,
                  disabledTooltip="Enable Show Border",
                  getValue=function() return SkinDB().borderSize or 2 end,
                  setValue=function(v)
                    SkinDB().borderSize = v
                    RefreshSkin()
                    RefreshMinimap()
                  end },
                nil
            );  y = y - h

            -- Border color
            do
                local row
                row, h = W:DualRow(parent, y,
                    { type="toggle", text="Border Color",
                      disabled=function() return not SkinDB().showBorder end,
                      disabledTooltip="Enable Show Border",
                      getValue=function() return true end,
                      setValue=function() end },
                    nil
                );  y = y - h

                local rgn = row._leftRegion
                local swatch = EllesmereUI.BuildColorSwatch(rgn, rgn:GetFrameLevel() + 5,
                    function()
                        local s = SkinDB()
                        return s.borderR or 0, s.borderG or 0, s.borderB or 0, s.borderA or 1
                    end,
                    function(r, g, b, a)
                        local s = SkinDB()
                        s.borderR = r; s.borderG = g; s.borderB = b; s.borderA = a
                        RefreshSkin()
                        RefreshMinimap()
                    end, true, 20)
                swatch:SetPoint("RIGHT", rgn._lastInline or rgn._control, "LEFT", -12, 0)
                rgn._lastInline = swatch
            end
        else
            -- Shaped border: color swatch only (border is a texture overlay)
            do
                local row
                row, h = W:DualRow(parent, y,
                    { type="toggle", text="Border Color",
                      disabled=function() return not SkinDB().showBorder end,
                      disabledTooltip="Enable Show Border",
                      getValue=function() return true end,
                      setValue=function() end },
                    nil
                );  y = y - h

                local rgn = row._leftRegion
                local swatch = EllesmereUI.BuildColorSwatch(rgn, rgn:GetFrameLevel() + 5,
                    function()
                        local s = SkinDB()
                        return s.shapedBorderR or 0, s.shapedBorderG or 0, s.shapedBorderB or 0, s.shapedBorderA or 1
                    end,
                    function(r, g, b, a)
                        local s = SkinDB()
                        s.shapedBorderR = r; s.shapedBorderG = g; s.shapedBorderB = b; s.shapedBorderA = a
                        RefreshSkin()
                    end, true, 20)
                swatch:SetPoint("RIGHT", rgn._lastInline or rgn._control, "LEFT", -12, 0)
                rgn._lastInline = swatch
            end
        end

        return y
    end

    ---------------------------------------------------------------------------
    --  Register Module
    ---------------------------------------------------------------------------
    EllesmereUI:RegisterModule("EllesmereUIBasics", {
        title       = "Minimap & Chat",
        description = "Customize your minimap, friends list, bags, and minimap skin.",
        pages       = { PAGE_MINIMAP, PAGE_FRIENDS, PAGE_BAGS, PAGE_SKIN },
        buildPage   = function(pageName, parent, yOffset)
            if pageName == PAGE_MINIMAP then
                return BuildMinimapPage(pageName, parent, yOffset)
            elseif pageName == PAGE_FRIENDS then
                return BuildFriendsPage(pageName, parent, yOffset)
            elseif pageName == PAGE_BAGS then
                return BuildBagsPage(pageName, parent, yOffset)
            elseif pageName == PAGE_SKIN then
                return BuildSkinPage(pageName, parent, yOffset)
            end
        end,
        onReset = function()
            if _G._EMC_AceDB then
                _G._EMC_AceDB:ResetProfile()
            end
            RefreshMinimap()
            RefreshSkin()
        end,
    })

    ---------------------------------------------------------------------------
    --  Slash command  /emc already defined in main lua
    ---------------------------------------------------------------------------
end)
