local ADDON_NAME = "Vantus Rune Helper"
local VantusRuneHelper = {}
_G["VantusRuneHelper"] = VantusRuneHelper

VantusRuneHelper.version = "1.0.0"
VantusRuneHelper.addonName = ADDON_NAME

local defaults = {
    enabledOnStartup = true,
    showDebugMessages = false,
    buttonPosition = {
        point = "TOPRIGHT",
        relativeTo = "GuildBankFrame",
        relativePoint = "BOTTOMRIGHT",
        xOfs = -4,
        yOfs = -4
    }
}

function VantusRuneHelper:InitializeDB()
    if not VantusRuneHelperDB then
        VantusRuneHelperDB = {}
    end
    
    for k, v in pairs(defaults) do
        if VantusRuneHelperDB[k] == nil then
            VantusRuneHelperDB[k] = v
        end
    end
    
    self.db = VantusRuneHelperDB
end

local vantus_priority = {244149, 244148, 244147}

local vantus_set = {}
for _, id in ipairs(vantus_priority) do
    vantus_set[id] = true
end

local HAS_C = C_Container ~= nil
local GetNumSlots = HAS_C and C_Container.GetContainerNumSlots or GetContainerNumSlots
local GetItemID   = HAS_C and C_Container.GetContainerItemID or GetContainerItemID
local PickupItem  = HAS_C and C_Container.PickupContainerItem or PickupContainerItem

local MAX_BAG = (NUM_BAG_SLOTS or 4)
if type(MAX_BAG) ~= "number" or MAX_BAG < 4 then
    MAX_BAG = 4
end

function VantusRuneHelper:Print(msg)
    print("|cff00ff00" .. ADDON_NAME .. ":|r " .. tostring(msg))
end

function VantusRuneHelper:PrintError(msg)
    print("|cffffff44" .. ADDON_NAME .. ":|r " .. tostring(msg))
end

function VantusRuneHelper:Debug(msg)
    if self.db and self.db.showDebugMessages then
        self:Print("DEBUG: " .. tostring(msg))
    end
end

local function iter_bag_slots(callback)
    for b = 0, MAX_BAG do
        local slots = GetNumSlots and GetNumSlots(b)
        if slots and slots > 0 then
            for s = 1, slots do
                if callback(b, s) then
                    return true
                end
            end
        end
    end
    return false
end

local function player_has_any_vantus()
    local found = false
    iter_bag_slots(function(b, s)
        local item = GetItemID and GetItemID(b, s)
        if item and vantus_set[item] then
            found = true
            return true
        end
    end)
    return found
end

local function find_empty_bag_slot()
    local empty
    iter_bag_slots(function(b, s)
        local item = GetItemID and GetItemID(b, s)
        if not item then
            empty = {b, s}
            return true
        end
    end)
    return empty
end

local function query_all_tabs()
    if not GetNumGuildBankTabs then return end
    for t = 1, GetNumGuildBankTabs() do
        local _, _, view = GetGuildBankTabInfo(t)
        if view then
            QueryGuildBankTab(t)
        end
    end
end

local function find_first_vantus_in_bank()
    if not GetNumGuildBankTabs then return nil end
    for _, wanted in ipairs(vantus_priority) do
        for t = 1, GetNumGuildBankTabs() do
            local _, _, view, _, _, withdraws = GetGuildBankTabInfo(t)
            if view and withdraws ~= 0 then
                for slot = 1, 98 do
                    local link = GetGuildBankItemLink(t, slot)
                    if link then
                        local itemID = GetItemInfoInstant(link)
                        if itemID == wanted then
                            return {t, slot, 1}
                        end
                    end
                end
            end
        end
    end
    return nil
end

function VantusRuneHelper:WithdrawVantus()
    query_all_tabs()
    if player_has_any_vantus() then
        self:PrintError("You already have a rune.")
        return
    end
    local empty_slot = find_empty_bag_slot()
    if not empty_slot then
        self:PrintError("No free bag slots available.")
        return
    end
    local bank_slot = find_first_vantus_in_bank()
    if not bank_slot then
        self:PrintError("No Vantus rune found in guild bank.")
        return
    end
    ClearCursor()
    SplitGuildBankItem(unpack(bank_slot))
    PickupItem(unpack(empty_slot))
    self:Print("Vantus rune successfully withdrawn!")
end

local function add_texture(button, kind, ...)
    local t = button:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(...)
    button["Set" .. kind .. "Texture"](button, t)
end

local function border_helper(frame, a, b, c, x, y, color)
    local f = frame:CreateTexture(nil, "OVERLAY")
    f:SetPoint(a)
    f:SetPoint(b, frame, c, x, y)
    f:SetColorTexture(unpack(color))
end

local function add_border(frame, width, color)
    border_helper(frame, "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", width, 0, color)
    border_helper(frame, "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", -width, 0, color)
    border_helper(frame, "TOPLEFT", "BOTTOMRIGHT", "TOPRIGHT", 0, -width, color)
    border_helper(frame, "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT", 0, width, color)
end

local BUTTON_NAME = "VantusRuneHelperWithdrawButton"

function VantusRuneHelper:CreateButton()
    if _G[BUTTON_NAME] then 
        return _G[BUTTON_NAME] 
    end
    
    if not GuildBankFrame then 
        self:Debug("GuildBankFrame not available")
        return nil 
    end
    
    local button = CreateFrame("Button", BUTTON_NAME, GuildBankFrame)
    button:SetSize(72, 26)
    
    add_texture(button, "Normal", 104/255, 11/255, 18/255, 1)
    add_texture(button, "Highlight", 124/255, 31/255, 38/255, 1)
    add_border(button, 2, {121/255, 117/255, 120/255, 1})
    
    local fs = button:CreateFontString(nil, "ARTWORK")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    fs:SetPoint("CENTER")
    button:SetFontString(fs)
    button:SetText("Vantus")
    
    button:ClearAllPoints()
    local pos = self.db.buttonPosition
    button:SetPoint(pos.point, _G[pos.relativeTo] or GuildBankFrame, pos.relativePoint, pos.xOfs, pos.yOfs)
    
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Vantus Rune Helper", 1, 1, 1, 1, true)
        GameTooltip:AddLine("Click to withdraw a Vantus rune from guild bank", nil, nil, nil, true)
        GameTooltip:AddLine("Priority: Higher level runes first", 0.5, 0.5, 0.5, true)
        GameTooltip:Show()
        query_all_tabs()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    button:SetScript("OnShow", query_all_tabs)
    button:SetScript("OnClick", function()
        VantusRuneHelper:WithdrawVantus()
    end)
    
    button:Show()
    self:Debug("Button created successfully")
    return button
end

function VantusRuneHelper:EnsureButton()
    if not self.db then
        self:InitializeDB()
    end
    
    if not self.db.enabledOnStartup then return end
    
    self:CreateButton()
end

function VantusRuneHelper:HandleSlashCommand(input)
    local args = {strsplit(" ", input:lower())}
    local cmd = args[1]
    
    if cmd == "debug" then
        self.db.showDebugMessages = not self.db.showDebugMessages
        self:Print("Debug messages " .. (self.db.showDebugMessages and "enabled" or "disabled"))
    elseif cmd == "withdraw" then
        self:WithdrawVantus()
    elseif cmd == "help" then
        self:Print("Available commands:")
        self:Print("/vantus debug - Toggle debug messages")
        self:Print("/vantus withdraw - Manually withdraw a Vantus rune")
        self:Print("/vantus help - Show this help")
    else
        self:Print("Version " .. self.version .. " loaded. Type '/vantus help' for commands.")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "VantusRuneHelper" then
            VantusRuneHelper:InitializeDB()
        end
    elseif event == "GUILDBANKFRAME_OPENED" then
        VantusRuneHelper:EnsureButton()
    elseif event == "PLAYER_LOGIN" then
        if GuildBankFrame then
            GuildBankFrame:HookScript("OnShow", function()
                VantusRuneHelper:EnsureButton()
            end)
        end
    end
end)

SLASH_VANTUSRUNEHELPER1 = "/vantus"
SLASH_VANTUSRUNEHELPER2 = "/vantusrune"
SlashCmdList["VANTUSRUNEHELPER"] = function(msg)
    VantusRuneHelper:HandleSlashCommand(msg)
end

local function waitForGuildBankFrame()
    local waiter = CreateFrame("Frame")
    local elapsed = 0
    waiter:SetScript("OnUpdate", function(self, e)
        elapsed = elapsed + e
        if elapsed > 0.5 then
            if GuildBankFrame then
                GuildBankFrame:HookScript("OnShow", function()
                    VantusRuneHelper:EnsureButton()
                end)
                VantusRuneHelper:EnsureButton()
                self:SetScript("OnUpdate", nil)
                self:Hide()
            end
            elapsed = 0
        end
    end)
end

if not GuildBankFrame then
    waitForGuildBankFrame()
end