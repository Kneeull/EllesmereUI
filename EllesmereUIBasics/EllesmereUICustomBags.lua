-------------------------------------------------------------------------------
--  EllesmereCustomBags.lua
--  Custom Bags enhancements for EllesmereUIBasics
--  Features: All-in-one bag, item level display, quality borders, search,
--            sort button, junk highlight, new item glow, bag slot counter,
--            profession bag icons, auto-vendor junk
--  IMPORTANT: Uses only public C_Container / C_Item APIs.
--             Secret values in 12.0 affect combat APIs (UnitHealth etc.),
--             NOT container/item APIs. We are safe here.
--             No hooksecurefunc on secure combat frames.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

-- Guard: only run once
if _G["_ECB_Loaded"] then return end
_G["_ECB_Loaded"] = true

local EMC = ns.EMC
local format, floor, ceil = string.format, math.floor, math.ceil
local pairs, ipairs, type = pairs, ipairs, type

-------------------------------------------------------------------------------
--  Constants
-------------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\EllesmereUI\\media\\"
local FONT_PATH = MEDIA .. "fonts\\Expressway.TTF"

local SLOT_SIZE = 37
local SLOT_PAD  = 4
local QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor (gray)
    [1] = { r = 1.00, g = 1.00, b = 1.00 }, -- Common (white)
    [2] = { r = 0.12, g = 1.00, b = 0.00 }, -- Uncommon (green)
    [3] = { r = 0.00, g = 0.44, b = 0.87 }, -- Rare (blue)
    [4] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic (purple)
    [5] = { r = 1.00, g = 0.50, b = 0.00 }, -- Legendary (orange)
    [6] = { r = 0.90, g = 0.80, b = 0.50 }, -- Artifact
    [7] = { r = 0.00, g = 0.80, b = 1.00 }, -- Heirloom
    [8] = { r = 0.00, g = 0.80, b = 1.00 }, -- WoW Token
}

-------------------------------------------------------------------------------
--  DB Defaults
-------------------------------------------------------------------------------
local BAGS_DEFAULTS = {
    enabled         = false,  -- off by default, user opts in
    columns         = 12,
    scale           = 1.0,
    showItemLevel   = true,
    showQualityBorder = true,
    showNewGlow     = true,
    highlightJunk   = true,
    showSlotCount   = true,
    sortDirection   = "right", -- "right" or "left"
    autoVendorJunk  = false,
    bagBarShow      = true,
    searchOnOpen    = false,
}

-------------------------------------------------------------------------------
--  State
-------------------------------------------------------------------------------
local bagFrame        -- main all-in-one bag frame
local slotButtons = {}
local isBuilt = false

-------------------------------------------------------------------------------
--  Helpers
-------------------------------------------------------------------------------
local function GetAccent()
    local eg = EllesmereUI and EllesmereUI.ELLESMERE_GREEN
    if eg then return eg.r, eg.g, eg.b end
    return 12/255, 210/255, 157/255
end

local function GetDB()
    local db = _G._EMC_AceDB
    if db and db.profile then
        if not db.profile.bags then
            db.profile.bags = {}
            for k, v in pairs(BAGS_DEFAULTS) do
                db.profile.bags[k] = v
            end
        end
        return db.profile.bags
    end
    return BAGS_DEFAULTS
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
--  Slot Button Creation
-------------------------------------------------------------------------------
local function CreateSlotButton(parent, index)
    local btn = CreateFrame("ItemButton", "ECB_Slot" .. index, parent)
    btn:SetSize(SLOT_SIZE, SLOT_SIZE)

    -- Background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.08, 0.9)
    UnsnapTex(bg)
    btn._bg = bg

    -- Quality border (4 edges)
    btn._qBorders = {}
    for i = 1, 4 do
        local edge = btn:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(1, 1, 1, 1)
        UnsnapTex(edge)
        edge:Hide()
        btn._qBorders[i] = edge
    end
    local bsz = 1
    btn._qBorders[1]:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    btn._qBorders[1]:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    btn._qBorders[1]:SetHeight(bsz)
    btn._qBorders[2]:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    btn._qBorders[2]:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    btn._qBorders[2]:SetHeight(bsz)
    btn._qBorders[3]:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    btn._qBorders[3]:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    btn._qBorders[3]:SetWidth(bsz)
    btn._qBorders[4]:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    btn._qBorders[4]:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    btn._qBorders[4]:SetWidth(bsz)

    -- Item level text
    local ilvl = btn:CreateFontString(nil, "OVERLAY")
    ilvl:SetFont(FONT_PATH, 10, "")
    ilvl:SetShadowOffset(1, -1)
    ilvl:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    ilvl:SetTextColor(1, 1, 1, 0.9)
    ilvl:Hide()
    btn._ilvlText = ilvl

    -- Junk coin icon (small gold coin overlay for junk items)
    local junkIcon = btn:CreateTexture(nil, "OVERLAY")
    junkIcon:SetSize(12, 12)
    junkIcon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    junkIcon:SetAtlas("coin-gold")
    junkIcon:Hide()
    btn._junkIcon = junkIcon

    -- New item glow
    local newGlow = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    newGlow:SetAllPoints()
    newGlow:SetColorTexture(1, 1, 1, 0.15)
    newGlow:Hide()
    btn._newGlow = newGlow

    return btn
end

-------------------------------------------------------------------------------
--  Update a single slot
-------------------------------------------------------------------------------
local function UpdateSlot(btn, bagID, slotIndex)
    local p = GetDB()
    btn._bagID = bagID
    btn._slotIndex = slotIndex

    local itemInfo = C_Container.GetContainerItemInfo(bagID, slotIndex)

    -- Reset
    btn._ilvlText:Hide()
    btn._junkIcon:Hide()
    btn._newGlow:Hide()
    for i = 1, 4 do btn._qBorders[i]:Hide() end

    if not itemInfo then
        -- Empty slot
        btn.icon:SetTexture(nil)
        btn._bg:SetColorTexture(0.08, 0.08, 0.08, 0.9)
        return
    end

    -- Icon
    btn.icon:SetTexture(itemInfo.iconFileID)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Stack count handled by ItemButton template

    -- Quality border
    local quality = itemInfo.quality
    if p.showQualityBorder and quality and quality >= 1 then
        local qc = QUALITY_COLORS[quality]
        if qc then
            for i = 1, 4 do
                btn._qBorders[i]:SetColorTexture(qc.r, qc.g, qc.b, 0.8)
                btn._qBorders[i]:Show()
            end
        end
    end

    -- Item level
    if p.showItemLevel and itemInfo.hyperlink then
        local ilvl = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromBagAndSlot(bagID, slotIndex))
        if ilvl and ilvl > 1 then
            btn._ilvlText:SetText(ilvl)
            btn._ilvlText:Show()
        end
    end

    -- Junk highlight
    if p.highlightJunk and quality == 0 then
        btn._junkIcon:Show()
    end

    -- New item glow
    if p.showNewGlow and C_NewItems.IsNewItem(bagID, slotIndex) then
        btn._newGlow:Show()
    end
end

-------------------------------------------------------------------------------
--  Build / Refresh the bag frame
-------------------------------------------------------------------------------
local function CountTotalSlots()
    local total = 0
    for bagID = 0, 4 do
        total = total + C_Container.GetContainerNumSlots(bagID)
    end
    return total
end

local function CountFreeSlots()
    local free = 0
    for bagID = 0, 4 do
        local numFree = C_Container.GetContainerNumFreeSlots(bagID)
        free = free + numFree
    end
    return free
end

local function BuildBagFrame()
    if bagFrame then return bagFrame end

    bagFrame = CreateFrame("Frame", "EllesmereCustomBags", UIParent, "BackdropTemplate")
    bagFrame:SetFrameStrata("HIGH")
    bagFrame:SetClampedToScreen(true)
    bagFrame:SetMovable(true)
    bagFrame:EnableMouse(true)
    bagFrame:RegisterForDrag("LeftButton")
    bagFrame:SetScript("OnDragStart", bagFrame.StartMoving)
    bagFrame:SetScript("OnDragStop", bagFrame.StopMovingOrSizing)

    bagFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bagFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
    bagFrame:SetBackdropBorderColor(0, 0, 0, 1)

    -- Title bar
    local title = bagFrame:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT_PATH, 12, "")
    title:SetShadowOffset(1, -1)
    title:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 8, -6)
    local ar, ag, ab = GetAccent()
    title:SetTextColor(ar, ag, ab, 1)
    title:SetText("Bags")
    bagFrame._title = title

    -- Slot count
    local slotCount = bagFrame:CreateFontString(nil, "OVERLAY")
    slotCount:SetFont(FONT_PATH, 11, "")
    slotCount:SetShadowOffset(1, -1)
    slotCount:SetPoint("TOPRIGHT", bagFrame, "TOPRIGHT", -8, -6)
    slotCount:SetTextColor(0.8, 0.8, 0.8, 1)
    bagFrame._slotCount = slotCount

    -- Close button
    local closeBtn = CreateFrame("Button", nil, bagFrame, "UIPanelCloseButton")
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", bagFrame, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() bagFrame:Hide() end)

    -- Sort button
    local sortBtn = CreateFrame("Button", nil, bagFrame)
    sortBtn:SetSize(16, 16)
    sortBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    sortBtn:SetNormalAtlas("bags-icon-sortbags")
    sortBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    sortBtn:SetScript("OnClick", function()
        C_Container.SortBags()
    end)
    sortBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sort Bags")
        GameTooltip:Show()
    end)
    sortBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Search box
    local search = CreateFrame("EditBox", "ECB_SearchBox", bagFrame, "SearchBoxTemplate")
    search:SetSize(120, 18)
    search:SetPoint("LEFT", title, "RIGHT", 12, 0)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        local text = self:GetText()
        C_Container.SetItemSearch(text)
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        C_Container.SetItemSearch("")
    end)
    bagFrame._search = search

    -- Gold display
    local goldText = bagFrame:CreateFontString(nil, "OVERLAY")
    goldText:SetFont(FONT_PATH, 11, "")
    goldText:SetShadowOffset(1, -1)
    goldText:SetPoint("BOTTOMLEFT", bagFrame, "BOTTOMLEFT", 8, 6)
    goldText:SetTextColor(1, 0.84, 0, 1)
    bagFrame._goldText = goldText

    bagFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 100)
    bagFrame:Hide()

    return bagFrame
end


local function RefreshBagFrame()
    local p = GetDB()
    if not p.enabled then
        if bagFrame then bagFrame:Hide() end
        return
    end

    local frame = BuildBagFrame()
    frame:SetScale(p.scale)

    local cols = p.columns
    local totalSlots = CountTotalSlots()
    local rows = ceil(totalSlots / cols)

    -- Size the frame
    local contentW = cols * (SLOT_SIZE + SLOT_PAD) + SLOT_PAD
    local contentH = rows * (SLOT_SIZE + SLOT_PAD) + SLOT_PAD
    local headerH = 24
    local footerH = 22
    frame:SetSize(contentW + 8, contentH + headerH + footerH + 8)

    -- Create/reuse slot buttons
    local slotIdx = 0
    for bagID = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        for slot = 1, numSlots do
            slotIdx = slotIdx + 1
            if not slotButtons[slotIdx] then
                slotButtons[slotIdx] = CreateSlotButton(frame, slotIdx)
            end
            local btn = slotButtons[slotIdx]
            local col = (slotIdx - 1) % cols
            local row = floor((slotIdx - 1) / cols)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT",
                4 + SLOT_PAD + col * (SLOT_SIZE + SLOT_PAD),
                -(headerH + 4 + SLOT_PAD + row * (SLOT_SIZE + SLOT_PAD)))
            btn:SetSize(SLOT_SIZE, SLOT_SIZE)
            btn:Show()
            UpdateSlot(btn, bagID, slot)
        end
    end

    -- Hide excess buttons
    for i = slotIdx + 1, #slotButtons do
        slotButtons[i]:Hide()
    end

    -- Update slot count
    if p.showSlotCount then
        local free = CountFreeSlots()
        frame._slotCount:SetText(free .. " / " .. totalSlots)
        frame._slotCount:Show()
    else
        frame._slotCount:Hide()
    end

    -- Update gold
    local copper = GetMoney()
    local gold = floor(copper / 10000)
    local silver = floor((copper % 10000) / 100)
    frame._goldText:SetText(format("%s|cffFFD700g|r %s|cffC0C0C0s|r", BreakUpLargeNumbers(gold), silver))
end

-------------------------------------------------------------------------------
--  Toggle bag open/close
-------------------------------------------------------------------------------
local function ToggleBags()
    local p = GetDB()
    if not p.enabled then return end

    if not bagFrame then BuildBagFrame() end
    if bagFrame:IsShown() then
        bagFrame:Hide()
        PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE or 863)
    else
        RefreshBagFrame()
        bagFrame:Show()
        PlaySound(SOUNDKIT.IG_BACKPACK_OPEN or 862)
        if p.searchOnOpen and bagFrame._search then
            bagFrame._search:SetFocus()
        end
    end
end

-------------------------------------------------------------------------------
--  Auto Vendor Junk
-------------------------------------------------------------------------------
local vendorFrame = CreateFrame("Frame", "ECB_VendorFrame")
vendorFrame:RegisterEvent("MERCHANT_SHOW")
vendorFrame:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        local p = GetDB()
        if not p.autoVendorJunk then return end
        -- Use Blizzard's built-in junk sell (safe, no secret values involved)
        if C_MerchantFrame and C_MerchantFrame.SellAllJunkItems then
            C_MerchantFrame.SellAllJunkItems()
        end
    end
end)

-------------------------------------------------------------------------------
--  Event-driven refresh
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "ECB_EventFrame")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:SetScript("OnEvent", function()
    if bagFrame and bagFrame:IsShown() then
        RefreshBagFrame()
    end
end)

-------------------------------------------------------------------------------
--  Hook Blizzard bag toggle (replace default bags with ours when enabled)
--  We hook OpenAllBags/CloseAllBags to intercept before Blizzard acts.
--  ToggleAllBags calls these internally, so we catch both paths.
-------------------------------------------------------------------------------
local hookFrame = CreateFrame("Frame", "ECB_HookFrame")
hookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hookFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        -- Post-hook: after Blizzard opens bags, close them and show ours
        hooksecurefunc("OpenAllBags", function()
            local p = GetDB()
            if not p.enabled then return end
            -- Close all Blizzard bag frames silently
            for i = 0, 4 do
                CloseBag(i)
            end
            if not bagFrame or not bagFrame:IsShown() then
                RefreshBagFrame()
                if bagFrame then bagFrame:Show() end
            end
        end)

        -- When Blizzard closes bags, also close ours
        hooksecurefunc("CloseAllBags", function()
            local p = GetDB()
            if not p.enabled then return end
            if bagFrame and bagFrame:IsShown() then
                bagFrame:Hide()
            end
        end)
    end
end)

-------------------------------------------------------------------------------
--  Expose
-------------------------------------------------------------------------------
_G._ECB_DEFAULTS = BAGS_DEFAULTS
_G._ECB_GetDB = GetDB
_G._ECB_ToggleBags = ToggleBags
_G._ECB_RefreshBagFrame = RefreshBagFrame
