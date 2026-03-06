-------------------------------------------------------------------------------
--  EllesmereMinimapSkin.lua
--  Minimap shape masking using the same portrait mask system as ActionBars
--  Shapes: circle, csquare, diamond, hexagon, portrait, shield, square
--  Each shape has a matching mask + border texture in EllesmereUI/media/portraits/
--  Border color, size, and visibility are all configurable.
--  IMPORTANT: No secret values involved. Minimap is not a combat API.
--             No hooksecurefunc on secure combat frames.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

-- Guard: only run once
if _G["_EMS_Loaded"] then return end
_G["_EMS_Loaded"] = true

local EMC = ns.EMC

-------------------------------------------------------------------------------
--  Media paths â€” shared portraits folder (synced across all Ellesmere addons)
-------------------------------------------------------------------------------
local PORTRAIT_MEDIA = "Interface\\AddOns\\EllesmereUI\\media\\portraits\\"

local SHAPE_MASKS = {
    circle   = PORTRAIT_MEDIA .. "circle_mask.tga",
    csquare  = PORTRAIT_MEDIA .. "csquare_mask.tga",
    diamond  = PORTRAIT_MEDIA .. "diamond_mask.tga",
    hexagon  = PORTRAIT_MEDIA .. "hexagon_mask.tga",
    portrait = PORTRAIT_MEDIA .. "portrait_mask.tga",
    shield   = PORTRAIT_MEDIA .. "shield_mask.tga",
    square   = "Interface\\Buttons\\WHITE8x8", -- solid white = square (no mask)
}

local SHAPE_BORDERS = {
    circle   = PORTRAIT_MEDIA .. "circle_border.tga",
    csquare  = PORTRAIT_MEDIA .. "csquare_border.tga",
    diamond  = PORTRAIT_MEDIA .. "diamond_border.tga",
    hexagon  = PORTRAIT_MEDIA .. "hexagon_border.tga",
    portrait = PORTRAIT_MEDIA .. "portrait_border.tga",
    shield   = PORTRAIT_MEDIA .. "shield_border.tga",
    square   = nil, -- square uses edge textures, not a shaped border
}

-- How much to inset the shaped border overlay (px) so it sits on the mask edge
local SHAPE_BORDER_INSETS = {
    circle = 2, csquare = 2, diamond = 2,
    hexagon = 2, portrait = 2, shield = 2, square = 0,
}

-- Display names for the options dropdown
local SHAPE_LABELS = {
    { key = "square",   label = "Square" },
    { key = "circle",   label = "Circle" },
    { key = "csquare",  label = "Rounded Square" },
    { key = "diamond",  label = "Diamond" },
    { key = "hexagon",  label = "Hexagon" },
    { key = "portrait", label = "Portrait" },
    { key = "shield",   label = "Shield" },
}

-------------------------------------------------------------------------------
--  DB Defaults
-------------------------------------------------------------------------------
local SKIN_DEFAULTS = {
    shape         = "square",   -- default shape
    showBorder    = true,
    borderSize    = 2,          -- px for square edge borders
    borderR       = 0,
    borderG       = 0,
    borderB       = 0,
    borderA       = 1,
    shapedBorderR = 0,
    shapedBorderG = 0,
    shapedBorderB = 0,
    shapedBorderA = 1,
}

-------------------------------------------------------------------------------
--  State
-------------------------------------------------------------------------------
local maskTexture       -- MaskTexture applied to Minimap
local shapedBorderTex   -- shaped border overlay texture
local edgeBorders = {}  -- 4 edge textures for square border

-------------------------------------------------------------------------------
--  Helpers
-------------------------------------------------------------------------------
local function GetDB()
    local db = _G._EMC_AceDB
    if db and db.profile then
        if not db.profile.minimapSkin then
            db.profile.minimapSkin = {}
            for k, v in pairs(SKIN_DEFAULTS) do
                db.profile.minimapSkin[k] = v
            end
        end
        return db.profile.minimapSkin
    end
    return SKIN_DEFAULTS
end

local function UnsnapTex(tex)
    local PP = EllesmereUI and EllesmereUI.PP
    if PP then PP.DisablePixelSnap(tex); return end
    if tex and tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
end


-------------------------------------------------------------------------------
--  Edge borders (for square shape â€” same system as existing EMC border)
-------------------------------------------------------------------------------
local function CreateEdgeBorders()
    if edgeBorders[1] then return end
    for i = 1, 4 do
        local tex = Minimap:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(0, 0, 0, 1)
        UnsnapTex(tex)
        tex:Hide()
        edgeBorders[i] = tex
    end
end

local function ApplyEdgeBorders(size, r, g, b, a)
    CreateEdgeBorders()
    local s = size or 2
    -- Top
    edgeBorders[1]:ClearAllPoints()
    edgeBorders[1]:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -s, s)
    edgeBorders[1]:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", s, s)
    edgeBorders[1]:SetHeight(s)
    edgeBorders[1]:SetColorTexture(r, g, b, a)
    -- Bottom
    edgeBorders[2]:ClearAllPoints()
    edgeBorders[2]:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -s, -s)
    edgeBorders[2]:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", s, -s)
    edgeBorders[2]:SetHeight(s)
    edgeBorders[2]:SetColorTexture(r, g, b, a)
    -- Left
    edgeBorders[3]:ClearAllPoints()
    edgeBorders[3]:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -s, s)
    edgeBorders[3]:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -s, -s)
    edgeBorders[3]:SetWidth(s)
    edgeBorders[3]:SetColorTexture(r, g, b, a)
    -- Right
    edgeBorders[4]:ClearAllPoints()
    edgeBorders[4]:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", s, s)
    edgeBorders[4]:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", s, -s)
    edgeBorders[4]:SetWidth(s)
    edgeBorders[4]:SetColorTexture(r, g, b, a)

    for i = 1, 4 do edgeBorders[i]:Show() end
end

local function HideEdgeBorders()
    for i = 1, 4 do
        if edgeBorders[i] then edgeBorders[i]:Hide() end
    end
end

-------------------------------------------------------------------------------
--  Shaped border overlay (for non-square shapes)
-------------------------------------------------------------------------------
local function CreateShapedBorder()
    if shapedBorderTex then return shapedBorderTex end
    shapedBorderTex = Minimap:CreateTexture(nil, "OVERLAY", nil, 7)
    UnsnapTex(shapedBorderTex)
    shapedBorderTex:Hide()
    return shapedBorderTex
end

local function ApplyShapedBorder(shape, r, g, b, a)
    local borderPath = SHAPE_BORDERS[shape]
    if not borderPath then
        if shapedBorderTex then shapedBorderTex:Hide() end
        return
    end

    local tex = CreateShapedBorder()
    local inset = SHAPE_BORDER_INSETS[shape] or 2
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -inset, inset)
    tex:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", inset, -inset)
    tex:SetTexture(borderPath)
    tex:SetVertexColor(r, g, b, a)
    tex:Show()
end

local function HideShapedBorder()
    if shapedBorderTex then shapedBorderTex:Hide() end
end

-------------------------------------------------------------------------------
--  Mask application
-------------------------------------------------------------------------------
local function ApplyMinimapMask(shape)
    if not Minimap.SetMaskTexture then return end

    local maskPath = SHAPE_MASKS[shape]
    if not maskPath then
        -- Fallback to Blizzard circle
        Minimap:SetMaskTexture("Textures\\MinimapMask")
        return
    end

    Minimap:SetMaskTexture(maskPath)

    -- Notify LibDBIcon about shape change
    if shape == "square" then
        function GetMinimapShape() return "SQUARE" end
    elseif shape == "circle" then
        function GetMinimapShape() return "ROUND" end
    else
        -- Non-standard shapes â€” tell addons it's square-ish for icon placement
        function GetMinimapShape() return "SQUARE" end
    end
end

-------------------------------------------------------------------------------
--  Master Apply
-------------------------------------------------------------------------------
local function ApplyMinimapSkin()
    local p = GetDB()
    local shape = p.shape or "square"

    -- 1. Apply mask
    ApplyMinimapMask(shape)

    -- 2. Apply border
    if p.showBorder then
        if shape == "square" then
            -- Use edge borders for square
            HideShapedBorder()
            ApplyEdgeBorders(p.borderSize, p.borderR, p.borderG, p.borderB, p.borderA)
        else
            -- Use shaped border overlay for non-square shapes
            HideEdgeBorders()
            ApplyShapedBorder(shape, p.shapedBorderR, p.shapedBorderG, p.shapedBorderB, p.shapedBorderA)
        end
    else
        HideEdgeBorders()
        HideShapedBorder()
    end
end

local function RevertMinimapSkin()
    -- Restore Blizzard circle mask
    if Minimap.SetMaskTexture then
        Minimap:SetMaskTexture("Textures\\MinimapMask")
    end
    function GetMinimapShape() return "ROUND" end
    HideEdgeBorders()
    HideShapedBorder()
end

-------------------------------------------------------------------------------
--  Expose
-------------------------------------------------------------------------------
_G._EMS_DEFAULTS = SKIN_DEFAULTS
_G._EMS_GetDB = GetDB
_G._EMS_ApplyMinimapSkin = ApplyMinimapSkin
_G._EMS_RevertMinimapSkin = RevertMinimapSkin
_G._EMS_SHAPE_LABELS = SHAPE_LABELS
_G._EMS_SHAPE_MASKS = SHAPE_MASKS
_G._EMS_SHAPE_BORDERS = SHAPE_BORDERS
