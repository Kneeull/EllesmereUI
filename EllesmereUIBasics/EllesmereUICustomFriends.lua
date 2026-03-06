-------------------------------------------------------------------------------
--  EllesmereCustomFriends.lua
--  Custom Friends List enhancements for EllesmereUIBasics
--  Features: Friend Groups, Class/Spec display, Class-colored names,
--            Faction icons, Level display, Search, Hide offline, Copy name
--  IMPORTANT: Uses only public C_BattleNet / C_FriendList APIs.
--             No secret values are involved (friends APIs are not combat APIs).
--             No hooksecurefunc on secure combat frames.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

-- Guard: only run once across all EllesmereUI addon copies
if _G["_ECF_Loaded"] then return end
_G["_ECF_Loaded"] = true

local EMC = ns.EMC
local format, tinsert, tremove, wipe, sort = string.format, table.insert, table.remove, table.wipe, table.sort
local pairs, ipairs, type, tostring = pairs, ipairs, type, tostring

-------------------------------------------------------------------------------
--  Constants
-------------------------------------------------------------------------------
local BNET_CLIENT_WOW = BNET_CLIENT_WOW or "WoW"
local FRIENDS_BUTTON_TYPE_BNET = FRIENDS_BUTTON_TYPE_BNET or 2
local FRIENDS_BUTTON_TYPE_WOW  = FRIENDS_BUTTON_TYPE_WOW or 1

local FONT_PATH = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF"

local CLASS_COLORS = {} -- populated from RAID_CLASS_COLORS at runtime

-------------------------------------------------------------------------------
--  DB Defaults (merged into EMC defaults from main lua)
-------------------------------------------------------------------------------
local FRIENDS_DEFAULTS = {
    enabled           = true,
    classColors       = true,
    showLevel         = true,
    hideMaxLevel      = true,
    showSpec          = true,
    showFaction       = true,
    hideOffline       = false,
    hideAFK           = false,
    groupsCollapsed   = {},   -- [groupName] = true/false
    friendGroups      = {},   -- [bnetAccountID or "wow:name"] = { "GroupA", "GroupB" }
    groupOrder        = {},   -- ordered list of group names
}

-------------------------------------------------------------------------------
--  State
-------------------------------------------------------------------------------
local friendsFrame       -- our custom overlay frame
local isInitialized = false
local groupsData = {}    -- rebuilt each refresh: [groupName] = { entries... }
local groupsSorted = {}  -- ordered group names
local groupCounts = {}   -- [groupName] = { online=N, total=N }
local searchText = ""

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
        if not db.profile.friends then
            db.profile.friends = {}
            for k, v in pairs(FRIENDS_DEFAULTS) do
                if type(v) == "table" then
                    db.profile.friends[k] = {}
                else
                    db.profile.friends[k] = v
                end
            end
        end
        return db.profile.friends
    end
    return FRIENDS_DEFAULTS
end

local function PopulateClassColors()
    if RAID_CLASS_COLORS then
        for class, color in pairs(RAID_CLASS_COLORS) do
            CLASS_COLORS[class] = { r = color.r, g = color.g, b = color.b }
        end
    end
end

local function ClassColorCode(class)
    if not class or class == "" then return "|cff999999" end
    -- Normalize localized class name to token
    local token = class
    if LOCALIZED_CLASS_NAMES_MALE then
        for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do
            if v == class then token = k; break end
        end
    end
    if LOCALIZED_CLASS_NAMES_FEMALE then
        for k, v in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
            if v == class then token = k; break end
        end
    end
    local c = CLASS_COLORS[token]
    if c then
        return format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
    return "|cff999999"
end


-------------------------------------------------------------------------------
--  Friend Group Management
--  Groups are stored per-profile in SavedVariables (not in friend notes).
--  This avoids modifying BNet notes and keeps groups local/private.
--  Key format: "bnet:12345" for BNet friends, "wow:CharName" for WoW friends
-------------------------------------------------------------------------------
local function FriendKey(id, buttonType)
    if buttonType == FRIENDS_BUTTON_TYPE_BNET then
        local info = C_BattleNet.GetFriendAccountInfo(id)
        if info then return "bnet:" .. info.bnetAccountID end
    elseif buttonType == FRIENDS_BUTTON_TYPE_WOW then
        local info = C_FriendList.GetFriendInfoByIndex(id)
        if info and info.name then return "wow:" .. info.name end
    end
    return nil
end

local function GetFriendGroupNames(key)
    local p = GetDB()
    local groups = p.friendGroups[key]
    if groups and #groups > 0 then return groups end
    return nil -- nil means "Ungrouped"
end

local function SetFriendGroups(key, groupList)
    local p = GetDB()
    if not groupList or #groupList == 0 then
        p.friendGroups[key] = nil
    else
        p.friendGroups[key] = groupList
    end
end

local function AddFriendToGroup(key, groupName)
    local p = GetDB()
    if not p.friendGroups[key] then p.friendGroups[key] = {} end
    for _, g in ipairs(p.friendGroups[key]) do
        if g == groupName then return end -- already in group
    end
    tinsert(p.friendGroups[key], groupName)
    -- Ensure group exists in order list
    local found = false
    for _, g in ipairs(p.groupOrder) do
        if g == groupName then found = true; break end
    end
    if not found then tinsert(p.groupOrder, groupName) end
end

local function RemoveFriendFromGroup(key, groupName)
    local p = GetDB()
    if not p.friendGroups[key] then return end
    for i = #p.friendGroups[key], 1, -1 do
        if p.friendGroups[key][i] == groupName then
            tremove(p.friendGroups[key], i)
        end
    end
    if #p.friendGroups[key] == 0 then
        p.friendGroups[key] = nil
    end
end

local function CreateGroup(groupName)
    local p = GetDB()
    for _, g in ipairs(p.groupOrder) do
        if g == groupName then return end -- already exists
    end
    tinsert(p.groupOrder, groupName)
end

local function DeleteGroup(groupName)
    local p = GetDB()
    -- Remove from order
    for i = #p.groupOrder, 1, -1 do
        if p.groupOrder[i] == groupName then tremove(p.groupOrder, i) end
    end
    -- Remove all friends from this group
    for key, groups in pairs(p.friendGroups) do
        for i = #groups, 1, -1 do
            if groups[i] == groupName then tremove(groups, i) end
        end
        if #groups == 0 then p.friendGroups[key] = nil end
    end
    -- Remove collapsed state
    p.groupsCollapsed[groupName] = nil
end

local function RenameGroup(oldName, newName)
    if oldName == newName or newName == "" then return end
    local p = GetDB()
    -- Update order
    for i, g in ipairs(p.groupOrder) do
        if g == oldName then p.groupOrder[i] = newName end
    end
    -- Update all friend assignments
    for key, groups in pairs(p.friendGroups) do
        for i, g in ipairs(groups) do
            if g == oldName then groups[i] = newName end
        end
    end
    -- Transfer collapsed state
    p.groupsCollapsed[newName] = p.groupsCollapsed[oldName]
    p.groupsCollapsed[oldName] = nil
end

-------------------------------------------------------------------------------
--  Data Collection â€” Build the grouped friends list
-------------------------------------------------------------------------------
local function IsOnline_BNet(id)
    local info = C_BattleNet.GetFriendAccountInfo(id)
    if info and info.gameAccountInfo then
        return info.gameAccountInfo.isOnline
    end
    return false
end

local function IsOnline_WoW(id)
    local info = C_FriendList.GetFriendInfoByIndex(id)
    return info and info.connected
end

local function IsAFK_BNet(id)
    local info = C_BattleNet.GetFriendAccountInfo(id)
    if info then
        if info.isAFK then return true end
        if info.gameAccountInfo and info.gameAccountInfo.isGameAFK then return true end
    end
    return false
end

local function IsAFK_WoW(id)
    local info = C_FriendList.GetFriendInfoByIndex(id)
    return info and info.afk
end

local function MatchesSearch(id, buttonType)
    if searchText == "" then return true end
    local s = searchText:lower()

    if buttonType == FRIENDS_BUTTON_TYPE_BNET then
        local info = C_BattleNet.GetFriendAccountInfo(id)
        if not info then return false end
        if info.accountName and info.accountName:lower():find(s, 1, true) then return true end
        if info.battleTag and info.battleTag:lower():find(s, 1, true) then return true end
        if info.note and info.note:lower():find(s, 1, true) then return true end
        local gi = info.gameAccountInfo
        if gi then
            if gi.characterName and gi.characterName:lower():find(s, 1, true) then return true end
            if gi.className and gi.className:lower():find(s, 1, true) then return true end
            if gi.realmName and gi.realmName:lower():find(s, 1, true) then return true end
            if gi.areaName and gi.areaName:lower():find(s, 1, true) then return true end
        end
    elseif buttonType == FRIENDS_BUTTON_TYPE_WOW then
        local info = C_FriendList.GetFriendInfoByIndex(id)
        if not info then return false end
        if info.name and info.name:lower():find(s, 1, true) then return true end
        if info.className and info.className:lower():find(s, 1, true) then return true end
        if info.notes and info.notes:lower():find(s, 1, true) then return true end
        if info.area and info.area:lower():find(s, 1, true) then return true end
    end
    return false
end


local function BuildEntry(id, buttonType)
    local entry = { id = id, buttonType = buttonType }

    if buttonType == FRIENDS_BUTTON_TYPE_BNET then
        local info = C_BattleNet.GetFriendAccountInfo(id)
        if not info then return nil end
        entry.accountName = info.accountName or UNKNOWN
        entry.battleTag = info.battleTag
        entry.isFavorite = info.isFavorite
        entry.isAFK = info.isAFK
        entry.isDND = info.isDND
        entry.note = info.note

        local gi = info.gameAccountInfo
        if gi then
            entry.isOnline = gi.isOnline
            entry.charName = gi.characterName
            entry.class = gi.className
            entry.level = gi.characterLevel
            entry.client = gi.clientProgram
            entry.zone = gi.areaName
            entry.realm = gi.realmName
            entry.faction = gi.factionName
            entry.isGameAFK = gi.isGameAFK
            entry.isGameBusy = gi.isGameBusy
            entry.isMobile = gi.isWowMobile
            entry.wowProjectID = gi.wowProjectID
            entry.richPresence = gi.richPresence
        end
    elseif buttonType == FRIENDS_BUTTON_TYPE_WOW then
        local info = C_FriendList.GetFriendInfoByIndex(id)
        if not info then return nil end
        entry.charName = info.name
        entry.class = info.className
        entry.level = info.level
        entry.isOnline = info.connected
        entry.zone = info.area
        entry.isAFK = info.afk
        entry.isDND = info.dnd
        entry.client = BNET_CLIENT_WOW
        entry.note = info.notes
    end

    -- Sort priority: online in-game > online other > offline
    local pri = 3 -- offline
    if entry.isOnline then
        if entry.client == BNET_CLIENT_WOW then pri = 1
        else pri = 2 end
    end
    if entry.isAFK or entry.isGameAFK then pri = pri + 0.5 end
    entry.sortPriority = pri

    return entry
end

local function RebuildGroupsData()
    wipe(groupsData)
    wipe(groupsSorted)
    wipe(groupCounts)

    local p = GetDB()
    local maxLevel = GetMaxLevelForLatestExpansion and GetMaxLevelForLatestExpansion() or 90

    -- Collect all entries
    local allEntries = {}

    local numBNet = BNGetNumFriends()
    for i = 1, numBNet do
        local entry = BuildEntry(i, FRIENDS_BUTTON_TYPE_BNET)
        if entry then
            -- Apply filters
            local dominated = false
            if p.hideOffline and not entry.isOnline then dominated = true end
            if p.hideAFK and (entry.isAFK or entry.isGameAFK) then dominated = true end
            if not MatchesSearch(i, FRIENDS_BUTTON_TYPE_BNET) then dominated = true end

            if not dominated then
                local key = FriendKey(i, FRIENDS_BUTTON_TYPE_BNET)
                local groups = key and GetFriendGroupNames(key)
                if not groups then groups = { "Ungrouped" } end
                for _, gn in ipairs(groups) do
                    if not groupsData[gn] then groupsData[gn] = {} end
                    tinsert(groupsData[gn], entry)
                end
            end
        end
    end

    local numWoW = C_FriendList.GetNumFriends()
    for i = 1, numWoW do
        local entry = BuildEntry(i, FRIENDS_BUTTON_TYPE_WOW)
        if entry then
            local dominated = false
            if p.hideOffline and not entry.isOnline then dominated = true end
            if p.hideAFK and entry.isAFK then dominated = true end
            if not MatchesSearch(i, FRIENDS_BUTTON_TYPE_WOW) then dominated = true end

            if not dominated then
                local key = FriendKey(i, FRIENDS_BUTTON_TYPE_WOW)
                local groups = key and GetFriendGroupNames(key)
                if not groups then groups = { "Ungrouped" } end
                for _, gn in ipairs(groups) do
                    if not groupsData[gn] then groupsData[gn] = {} end
                    tinsert(groupsData[gn], entry)
                end
            end
        end
    end

    -- Build sorted group list: user-ordered groups first, then any extras, "Ungrouped" last
    local seen = {}
    for _, gn in ipairs(p.groupOrder) do
        if groupsData[gn] then
            tinsert(groupsSorted, gn)
            seen[gn] = true
        end
    end
    -- Any groups not in user order (shouldn't happen, but safety)
    for gn in pairs(groupsData) do
        if not seen[gn] and gn ~= "Ungrouped" then
            tinsert(groupsSorted, gn)
        end
    end
    -- Ungrouped always last
    if groupsData["Ungrouped"] then
        tinsert(groupsSorted, "Ungrouped")
    end

    -- Sort entries within each group
    for gn, entries in pairs(groupsData) do
        sort(entries, function(a, b)
            if a.sortPriority ~= b.sortPriority then
                return a.sortPriority < b.sortPriority
            end
            local na = a.accountName or a.charName or ""
            local nb = b.accountName or b.charName or ""
            return na < nb
        end)
        -- Count
        local online, total = 0, #entries
        for _, e in ipairs(entries) do
            if e.isOnline then online = online + 1 end
        end
        groupCounts[gn] = { online = online, total = total }
    end
end

-------------------------------------------------------------------------------
--  Expose for options / other modules
-------------------------------------------------------------------------------
_G._ECF_RebuildGroupsData = RebuildGroupsData
_G._ECF_GetDB = GetDB
_G._ECF_CreateGroup = CreateGroup
_G._ECF_DeleteGroup = DeleteGroup
_G._ECF_RenameGroup = RenameGroup
_G._ECF_AddFriendToGroup = AddFriendToGroup
_G._ECF_RemoveFriendFromGroup = RemoveFriendFromGroup
_G._ECF_FriendKey = FriendKey
_G._ECF_GetFriendGroupNames = GetFriendGroupNames
_G._ECF_ClassColorCode = ClassColorCode
_G._ECF_GroupsData = function() return groupsData end
_G._ECF_GroupsSorted = function() return groupsSorted end
_G._ECF_GroupCounts = function() return groupCounts end
_G._ECF_SetSearch = function(text) searchText = text or "" end

-------------------------------------------------------------------------------
--  Hook into Blizzard Friends List
--  We hook FriendsFrame_UpdateFriendButton to inject class color + spec text.
--  We hook FriendsList_Update to inject group headers via ScrollBox data.
--  These are display-only hooks â€” no secure frame modification.
-------------------------------------------------------------------------------
local hookFrame = CreateFrame("Frame", "EllesmereCustomFriendsHook")

local function OnFriendsShow()
    if not isInitialized then
        PopulateClassColors()
        isInitialized = true
    end
    RebuildGroupsData()
end

hookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hookFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        PopulateClassColors()
        isInitialized = true
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

-- Expose the defaults so the main addon can merge them
_G._ECF_DEFAULTS = FRIENDS_DEFAULTS
