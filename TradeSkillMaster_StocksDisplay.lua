-- ------------------------------------------------------------------------------ --
--                        TradeSkillMaster_StocksDisplay                          --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.   --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
TSM = LibStub("AceAddon-3.0"):NewAddon(TSM, "TSM_StocksDisplay", "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_StocksDisplay")

-- Constants
local ICON_SIZE = 32
local ICONS_PER_ROW = 8
local HEADER_HEIGHT = 24
local GROUP_HEADER_HEIGHT = 20
local PADDING = 4

-- Default saved variables
local savedDBDefaults = {
	profile = {
		trackedItems = {}, -- { itemString = groupName or nil }
		groups = {}, -- { "groupName1", "groupName2", ... }
		windowPos = { point = "CENTER", x = 0, y = 0 },
		collapsed = false,
	},
}

function TSM:OnInitialize()
	-- Load saved variables
	TSM.db = LibStub("AceDB-3.0"):New("AscensionTSM_StocksDisplayDB", savedDBDefaults, true)

	-- Migrate old format (array) to new format (table with groups)
	TSM:MigrateData()

	-- Register module with TSM
	TSM:RegisterModule()

	-- Create the display window
	TSM:CreateStockWindow()

	-- Create dialogs
	TSM:CreateGroupDialog()
	TSM:CreateDeleteConfirmDialog()
	TSM:CreateContextMenu()

	-- Hook item clicks for Alt+Click functionality
	TSM:HookItemClicks()

	-- Start periodic refresh timer (every 2 seconds)
	TSM:StartRefreshTimer()
end

function TSM:StartRefreshTimer()
	local refreshFrame = CreateFrame("Frame")
	refreshFrame.elapsed = 0
	refreshFrame:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		if self.elapsed >= 2 then
			self.elapsed = 0
			TSM:RefreshDisplay()
		end
	end)
	TSM.refreshFrame = refreshFrame
end

function TSM:MigrateData()
	-- Migrate from old array format to new table format
	if TSM.db.profile.trackedItems[1] then
		local oldItems = TSM.db.profile.trackedItems
		TSM.db.profile.trackedItems = {}
		for _, itemString in ipairs(oldItems) do
			TSM.db.profile.trackedItems[itemString] = ""
		end
	end
	-- Initialize groups if needed
	if not TSM.db.profile.groups then
		TSM.db.profile.groups = {}
	end
end

function TSM:RegisterModule()
	TSM.icons = {
		{
			side = "module",
			desc = "StocksDisplay",
			slashCommand = "stocks",
			callback = function() TSM:ToggleWindow() end,
			icon = "Interface\\Icons\\INV_Misc_Bag_10",
		},
	}

	TSM.slashCommands = {
		{ key = "stocks", label = L["Toggle stock display window"], callback = function() TSM:ToggleWindow() end },
	}

	TSMAPI:NewModule(TSM)
end

function TSM:CreateStockWindow()
	-- Main frame
	local frame = CreateFrame("Frame", "TSMStocksDisplayFrame", UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint()
		TSM.db.profile.windowPos = { point = point, x = x, y = y }
	end)

	-- Apply TSM styling
	TSMAPI.Design:SetFrameBackdropColor(frame)

	-- Header
	local header = CreateFrame("Frame", nil, frame)
	header:SetHeight(HEADER_HEIGHT)
	header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	TSMAPI.Design:SetFrameColor(header)

	-- Title
	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("LEFT", header, "LEFT", 8, 0)
	title:SetText(L["Stocks"])
	title:SetTextColor(1, 1, 1)

	-- Collapse/Expand button
	local toggleBtn = CreateFrame("Button", nil, header)
	toggleBtn:SetSize(16, 16)
	toggleBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)

	local toggleText = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	toggleText:SetPoint("CENTER")
	toggleText:SetText(TSM.db.profile.collapsed and "+" or "-")
	toggleText:SetTextColor(1, 1, 1)
	toggleBtn.text = toggleText

	toggleBtn:SetScript("OnClick", function(self)
		TSM.db.profile.collapsed = not TSM.db.profile.collapsed
		self.text:SetText(TSM.db.profile.collapsed and "+" or "-")
		TSM:RefreshDisplay()
	end)

	-- Add Group button
	local addGroupBtn = CreateFrame("Button", nil, header)
	addGroupBtn:SetPoint("RIGHT", toggleBtn, "LEFT", -8, 0)
	local addGroupText = addGroupBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	addGroupText:SetPoint("CENTER")
	addGroupText:SetText(L["Add Group"])
	addGroupText:SetTextColor(1, 0.82, 0) -- Gold color
	addGroupBtn:SetSize(addGroupText:GetStringWidth() + 4, 16)
	addGroupBtn:SetScript("OnClick", function() TSM:ShowGroupDialog() end)
	addGroupBtn:SetScript("OnEnter", function(self)
		addGroupText:SetTextColor(1, 1, 0.5)
	end)
	addGroupBtn:SetScript("OnLeave", function(self)
		addGroupText:SetTextColor(1, 0.82, 0)
	end)

	-- Content frame (holds the item icons)
	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", PADDING, -PADDING)
	content:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -PADDING, -PADDING)

	-- Store references
	frame.header = header
	frame.content = content
	frame.toggleBtn = toggleBtn
	frame.itemButtons = {}
	frame.groupHeaders = {}

	TSM.stockFrame = frame

	-- Position from saved variables
	local pos = TSM.db.profile.windowPos
	frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

	-- Initial update
	TSM:RefreshDisplay()
end

function TSM:CreateGroupDialog()
	local dialog = CreateFrame("Frame", "TSMStocksDisplayGroupDialog", UIParent)
	dialog:SetSize(250, 100)
	dialog:SetPoint("CENTER")
	dialog:SetFrameStrata("DIALOG")
	dialog:EnableMouse(true)
	dialog:SetMovable(true)
	dialog:RegisterForDrag("LeftButton")
	dialog:SetScript("OnDragStart", dialog.StartMoving)
	dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
	dialog:Hide()
	TSMAPI.Design:SetFrameBackdropColor(dialog)

	-- Title
	local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", dialog, "TOP", 0, -10)
	title:SetText(L["Create Group"])

	-- Edit box
	local editBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
	editBox:SetSize(180, 20)
	editBox:SetPoint("TOP", title, "BOTTOM", 0, -15)
	editBox:SetAutoFocus(true)
	editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
	editBox:SetScript("OnEnterPressed", function(self)
		local name = self:GetText():trim()
		if name ~= "" then
			TSM:CreateGroup(name)
			dialog:Hide()
		end
	end)
	dialog.editBox = editBox

	-- Create button
	local createBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	createBtn:SetSize(80, 22)
	createBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -5, 10)
	createBtn:SetText(L["Create"])
	createBtn:SetScript("OnClick", function()
		local name = editBox:GetText():trim()
		if name ~= "" then
			TSM:CreateGroup(name)
			dialog:Hide()
		end
	end)

	-- Cancel button
	local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	cancelBtn:SetSize(80, 22)
	cancelBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 5, 10)
	cancelBtn:SetText(L["Cancel"])
	cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

	TSM.groupDialog = dialog
end

function TSM:CreateDeleteConfirmDialog()
	local dialog = CreateFrame("Frame", "TSMStocksDisplayDeleteDialog", UIParent)
	dialog:SetSize(250, 80)
	dialog:SetPoint("CENTER")
	dialog:SetFrameStrata("DIALOG")
	dialog:EnableMouse(true)
	dialog:Hide()
	TSMAPI.Design:SetFrameBackdropColor(dialog)

	-- Title
	local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", dialog, "TOP", 0, -15)
	title:SetText(L["Delete this group?"])
	dialog.title = title

	-- Delete button
	local deleteBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	deleteBtn:SetSize(80, 22)
	deleteBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -5, 10)
	deleteBtn:SetText(L["Delete"])
	dialog.deleteBtn = deleteBtn

	-- Cancel button
	local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	cancelBtn:SetSize(80, 22)
	cancelBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 5, 10)
	cancelBtn:SetText(L["Cancel"])
	cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

	TSM.deleteDialog = dialog
end

function TSM:CreateContextMenu()
	local menu = CreateFrame("Frame", "TSMStocksDisplayContextMenu", UIParent, "UIDropDownMenuTemplate")
	TSM.contextMenu = menu
end

function TSM:ShowGroupDialog()
	TSM.groupDialog.editBox:SetText("")
	TSM.groupDialog:Show()
	TSM.groupDialog.editBox:SetFocus()
end

function TSM:ShowDeleteConfirm(groupName)
	local dialog = TSM.deleteDialog
	dialog.title:SetText(format(L["Delete group '%s'?"], groupName))
	dialog.deleteBtn:SetScript("OnClick", function()
		TSM:DeleteGroup(groupName)
		dialog:Hide()
	end)
	dialog:Show()
end

function TSM:ShowContextMenu(itemButton)
	local itemString = itemButton.itemString
	if not itemString then return end

	local menuList = {
		{ text = GetItemInfo(itemString) or itemString, isTitle = true, notCheckable = true },
		{ text = L["Move to group"], notCheckable = true, hasArrow = true,
			menuList = TSM:GetGroupMenuList(itemString)
		},
		{ text = L["Remove"], notCheckable = true,
			func = function() TSM:RemoveTrackedItem(itemString) end
		},
	}

	EasyMenu(menuList, TSM.contextMenu, "cursor", 0, 0, "MENU")
end

function TSM:GetGroupMenuList(itemString)
	local list = {
		{ text = L["None"], notCheckable = true,
			func = function()
				TSM:SetItemGroup(itemString, nil)
				CloseDropDownMenus()
			end
		},
	}

	for _, groupName in ipairs(TSM.db.profile.groups) do
		tinsert(list, {
			text = groupName, notCheckable = true,
			func = function()
				TSM:SetItemGroup(itemString, groupName)
				CloseDropDownMenus()
			end
		})
	end

	return list
end

function TSM:CreateGroup(name)
	-- Check if group already exists
	for _, groupName in ipairs(TSM.db.profile.groups) do
		if groupName == name then
			TSM:Print(format(L["Group '%s' already exists."], name))
			return
		end
	end

	tinsert(TSM.db.profile.groups, name)
	TSM:Print(format(L["Group '%s' created."], name))
	TSM:RefreshDisplay()
end

function TSM:DeleteGroup(name)
	-- Remove group from list
	for i, groupName in ipairs(TSM.db.profile.groups) do
		if groupName == name then
			tremove(TSM.db.profile.groups, i)
			break
		end
	end

	-- Move items from this group to ungrouped
	for itemString, group in pairs(TSM.db.profile.trackedItems) do
		if group == name then
			TSM.db.profile.trackedItems[itemString] = ""
		end
	end

	TSM:Print(format(L["Group '%s' deleted."], name))
	TSM:RefreshDisplay()
end

function TSM:SetItemGroup(itemString, groupName)
	TSM.db.profile.trackedItems[itemString] = groupName or ""
	TSM:RefreshDisplay()
end

function TSM:RefreshDisplay()
	local frame = TSM.stockFrame
	if not frame then return end

	local content = frame.content

	-- Hide all existing buttons and group headers
	for _, btn in pairs(frame.itemButtons) do
		btn:Hide()
	end
	for _, header in pairs(frame.groupHeaders) do
		header:Hide()
	end

	if TSM.db.profile.collapsed then
		content:Hide()
		frame:SetSize(ICONS_PER_ROW * ICON_SIZE + PADDING * 2, HEADER_HEIGHT)
		return
	end

	content:Show()

	-- Get ItemTracker addon
	local ItemTracker = LibStub("AceAddon-3.0"):GetAddon("TSM_ItemTracker", true)
	if not ItemTracker then return end

	-- Organize items by group
	local ungroupedItems = {}
	local groupedItems = {}

	for itemString, groupName in pairs(TSM.db.profile.trackedItems) do
		if not groupName or groupName == "" then
			tinsert(ungroupedItems, itemString)
		else
			if not groupedItems[groupName] then
				groupedItems[groupName] = {}
			end
			tinsert(groupedItems[groupName], itemString)
		end
	end

	-- Sort items by item level (ascending)
	local function sortByItemLevel(a, b)
		local _, _, _, ilvlA = GetItemInfo(a)
		local _, _, _, ilvlB = GetItemInfo(b)
		return (ilvlA or 0) < (ilvlB or 0)
	end

	sort(ungroupedItems, sortByItemLevel)
	for _, items in pairs(groupedItems) do
		sort(items, sortByItemLevel)
	end

	local yOffset = 0
	local buttonIndex = 0

	-- Display ungrouped items first
	if #ungroupedItems > 0 then
		for i, itemString in ipairs(ungroupedItems) do
			buttonIndex = buttonIndex + 1
			local btn = TSM:GetOrCreateItemButton(buttonIndex)

			local row = math.floor((i - 1) / ICONS_PER_ROW)
			local col = (i - 1) % ICONS_PER_ROW
			btn:SetPoint("TOPLEFT", content, "TOPLEFT", col * ICON_SIZE, -yOffset - row * ICON_SIZE)

			TSM:SetupItemButton(btn, itemString, ItemTracker)
			btn:Show()
		end

		local numRows = math.ceil(#ungroupedItems / ICONS_PER_ROW)
		yOffset = yOffset + numRows * ICON_SIZE + PADDING
	end

	-- Display grouped items
	for _, groupName in ipairs(TSM.db.profile.groups) do
		local items = groupedItems[groupName]
		if items and #items > 0 then
			-- Create/get group header
			local header = TSM:GetOrCreateGroupHeader(groupName)
			header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
			header:Show()

			yOffset = yOffset + GROUP_HEADER_HEIGHT

			-- Display items in this group
			for i, itemString in ipairs(items) do
				buttonIndex = buttonIndex + 1
				local btn = TSM:GetOrCreateItemButton(buttonIndex)

				local row = math.floor((i - 1) / ICONS_PER_ROW)
				local col = (i - 1) % ICONS_PER_ROW
				btn:SetPoint("TOPLEFT", content, "TOPLEFT", col * ICON_SIZE, -yOffset - row * ICON_SIZE)

				TSM:SetupItemButton(btn, itemString, ItemTracker)
				btn:Show()
			end

			local numRows = math.ceil(#items / ICONS_PER_ROW)
			yOffset = yOffset + numRows * ICON_SIZE + PADDING
		end
	end

	-- Update window size
	local contentHeight = math.max(ICON_SIZE, yOffset)
	content:SetHeight(contentHeight)
	frame:SetSize(ICONS_PER_ROW * ICON_SIZE + PADDING * 2, HEADER_HEIGHT + contentHeight + PADDING)
end

function TSM:GetOrCreateItemButton(index)
	local frame = TSM.stockFrame
	local btn = frame.itemButtons[index]

	if not btn then
		btn = CreateFrame("Button", nil, frame.content)
		btn:SetSize(ICON_SIZE, ICON_SIZE)
		btn:EnableMouse(true)
		btn:RegisterForClicks("AnyUp")

		-- Background
		local bg = btn:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
		btn.bg = bg

		-- Icon
		local icon = btn:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
		btn.icon = icon

		-- Count text
		local count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		count:SetPoint("BOTTOMRIGHT", -2, 2)
		count:SetJustifyH("RIGHT")
		btn.count = count

		-- Tooltip
		btn:SetScript("OnEnter", function(self)
			if self.itemLink then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetHyperlink(self.itemLink)
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(L["Right-click for options"], 0.5, 0.5, 0.5, true)
				GameTooltip:Show()
			end
		end)
		btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

		-- Click handling
		btn:SetScript("OnClick", function(self, button)
			if button == "RightButton" then
				TSM:ShowContextMenu(self)
			elseif self.itemLink then
				HandleModifiedItemClick(self.itemLink)
			end
		end)

		frame.itemButtons[index] = btn
	end

	return btn
end

function TSM:GetOrCreateGroupHeader(groupName)
	local frame = TSM.stockFrame
	local header = frame.groupHeaders[groupName]

	if not header then
		header = CreateFrame("Frame", nil, frame.content)
		header:SetHeight(GROUP_HEADER_HEIGHT)
		header:SetWidth(ICONS_PER_ROW * ICON_SIZE)

		-- Group name text
		local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		text:SetPoint("LEFT", header, "LEFT", 2, 0)
		text:SetText(groupName)
		text:SetTextColor(1, 0.82, 0) -- Gold
		header.text = text

		-- Delete button (X)
		local deleteBtn = CreateFrame("Button", nil, header)
		deleteBtn:SetSize(16, 16)
		deleteBtn:SetPoint("RIGHT", header, "RIGHT", -2, 0)

		local deleteText = deleteBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		deleteText:SetPoint("CENTER")
		deleteText:SetText("X")
		deleteText:SetTextColor(1, 0.3, 0.3)

		deleteBtn:SetScript("OnClick", function()
			TSM:ShowDeleteConfirm(groupName)
		end)
		deleteBtn:SetScript("OnEnter", function()
			deleteText:SetTextColor(1, 0.5, 0.5)
		end)
		deleteBtn:SetScript("OnLeave", function()
			deleteText:SetTextColor(1, 0.3, 0.3)
		end)

		-- Move Down button
		local downBtn = CreateFrame("Button", nil, header)
		downBtn:SetSize(16, 16)
		downBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -2, 0)

		local downText = downBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		downText:SetPoint("CENTER")
		downText:SetText("▼")
		downText:SetTextColor(0.7, 0.7, 0.7)

		downBtn:SetScript("OnClick", function()
			TSM:MoveGroupDown(groupName)
		end)
		downBtn:SetScript("OnEnter", function()
			downText:SetTextColor(1, 1, 1)
		end)
		downBtn:SetScript("OnLeave", function()
			downText:SetTextColor(0.7, 0.7, 0.7)
		end)

		-- Move Up button
		local upBtn = CreateFrame("Button", nil, header)
		upBtn:SetSize(16, 16)
		upBtn:SetPoint("RIGHT", downBtn, "LEFT", -2, 0)

		local upText = upBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		upText:SetPoint("CENTER")
		upText:SetText("▲")
		upText:SetTextColor(0.7, 0.7, 0.7)

		upBtn:SetScript("OnClick", function()
			TSM:MoveGroupUp(groupName)
		end)
		upBtn:SetScript("OnEnter", function()
			upText:SetTextColor(1, 1, 1)
		end)
		upBtn:SetScript("OnLeave", function()
			upText:SetTextColor(0.7, 0.7, 0.7)
		end)

		frame.groupHeaders[groupName] = header
	end

	return header
end

function TSM:MoveGroupUp(groupName)
	local groups = TSM.db.profile.groups
	for i, name in ipairs(groups) do
		if name == groupName and i > 1 then
			-- Swap with previous
			groups[i], groups[i - 1] = groups[i - 1], groups[i]
			TSM:RefreshDisplay()
			return
		end
	end
end

function TSM:MoveGroupDown(groupName)
	local groups = TSM.db.profile.groups
	for i, name in ipairs(groups) do
		if name == groupName and i < #groups then
			-- Swap with next
			groups[i], groups[i + 1] = groups[i + 1], groups[i]
			TSM:RefreshDisplay()
			return
		end
	end
end

function TSM:SetupItemButton(btn, itemString, ItemTracker)
	local itemName, itemLink, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemString)

	if itemTexture then
		btn.icon:SetTexture(itemTexture)
		btn.itemLink = itemLink
		btn.itemString = itemString

		-- Get stock count from ItemTracker
		local playerTotal, altTotal = ItemTracker:GetPlayerTotal(itemString)
		local guildTotal = ItemTracker:GetGuildTotal(itemString) or 0
		local auctionTotal = ItemTracker:GetAuctionsTotal(itemString) or 0
		local total = (playerTotal or 0) + (altTotal or 0) + guildTotal + auctionTotal

		btn.count:SetText(total > 0 and total or "0")
	else
		btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		btn.itemString = itemString
		btn.itemLink = nil
		btn.count:SetText("?")
	end
end

function TSM:AddTrackedItem(itemString)
	-- Check if already tracked
	if TSM.db.profile.trackedItems[itemString] then
		TSM:Print(L["Item already in stock display."])
		return
	end

	-- Add to list (ungrouped by default)
	TSM.db.profile.trackedItems[itemString] = ""

	local itemName = GetItemInfo(itemString) or itemString
	TSM:Print(format(L["Item added to stock display: %s"], itemName))

	TSM:RefreshDisplay()
end

function TSM:RemoveTrackedItem(itemString)
	if TSM.db.profile.trackedItems[itemString] then
		local itemName = GetItemInfo(itemString) or itemString
		TSM.db.profile.trackedItems[itemString] = nil
		TSM:Print(format(L["Item removed from stock display: %s"], itemName))
		TSM:RefreshDisplay()
	end
end

function TSM:ToggleWindow()
	if TSM.stockFrame:IsShown() then
		TSM.stockFrame:Hide()
	else
		TSM.stockFrame:Show()
	end
end

function TSM:HookItemClicks()
	-- Hook ContainerFrameItemButton clicks (bags)
	hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
		if IsAltKeyDown() and button == "LeftButton" then
			local bag = self:GetParent():GetID()
			local slot = self:GetID()
			local itemLink = GetContainerItemLink(bag, slot)
			if itemLink then
				local itemString = TSMAPI:GetItemString(itemLink)
				if itemString then
					TSM:AddTrackedItem(itemString)
				end
			end
		end
	end)

	-- Hook for clicking on item links in chat and other places
	local origHandleModifiedItemClick = HandleModifiedItemClick
	HandleModifiedItemClick = function(itemLink, ...)
		if IsAltKeyDown() and itemLink then
			local itemString = TSMAPI:GetItemString(itemLink)
			if itemString then
				TSM:AddTrackedItem(itemString)
				return true
			end
		end
		return origHandleModifiedItemClick(itemLink, ...)
	end
end
