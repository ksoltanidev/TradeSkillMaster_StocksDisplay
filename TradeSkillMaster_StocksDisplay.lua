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
local ICON_SIZE = 24
local ICONS_PER_ROW = 10
local HEADER_HEIGHT = 24
local GROUP_HEADER_HEIGHT = 20
local FOOTER_HEIGHT = 20
local PADDING = 4

-- Default saved variables
local savedDBDefaults = {
	profile = {
		-- Current display profile (our custom profiles, not AceDB profiles)
		currentDisplayProfile = "Default",
		-- Display profiles containing items/groups
		displayProfiles = {
			["Default"] = {
				trackedItems = {}, -- { itemString = groupName or nil }
				groups = {}, -- { "groupName1", "groupName2", ... }
			},
		},
		-- Window settings (shared across display profiles)
		windowPos = { point = "CENTER", x = 0, y = 0 },
		collapsed = false,
	},
}

function TSM:OnInitialize()
	-- Load saved variables
	TSM.db = LibStub("AceDB-3.0"):New("AscensionTSM_StocksDisplayDB", savedDBDefaults, true)

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


-- Helper to get current display profile data
function TSM:GetCurrentProfileData()
	return TSM.db.profile.displayProfiles[TSM.db.profile.currentDisplayProfile]
end

-- Get sorted list of display profile names
function TSM:GetSortedProfileNames()
	local names = {}
	for name in pairs(TSM.db.profile.displayProfiles) do
		tinsert(names, name)
	end
	sort(names)
	return names
end

-- Switch to a different display profile
function TSM:SwitchProfile(profileName)
	if TSM.db.profile.displayProfiles[profileName] then
		TSM.db.profile.currentDisplayProfile = profileName
		TSM:RefreshDisplay()
		TSM:Print(format(L["Switched to profile: %s"], profileName))
	end
end

-- Create a new display profile
function TSM:CreateProfile(name)
	if TSM.db.profile.displayProfiles[name] then
		TSM:Print(format(L["Profile '%s' already exists."], name))
		return false
	end

	TSM.db.profile.displayProfiles[name] = {
		trackedItems = {},
		groups = {},
	}
	TSM:Print(format(L["Profile '%s' created."], name))
	return true
end

-- Delete a display profile
function TSM:DeleteProfile(name)
	if name == "Default" then
		TSM:Print(L["Cannot delete the Default profile."])
		return false
	end

	if not TSM.db.profile.displayProfiles[name] then
		return false
	end

	-- If deleting current profile, switch to Default first
	if TSM.db.profile.currentDisplayProfile == name then
		TSM:SwitchProfile("Default")
	end

	TSM.db.profile.displayProfiles[name] = nil
	TSM:Print(format(L["Profile '%s' deleted."], name))

	TSM:RefreshDisplay()
	return true
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

	-- Footer frame (holds Export/Import/Profile buttons)
	local footer = CreateFrame("Frame", nil, frame)
	footer:SetHeight(FOOTER_HEIGHT)
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

	-- Import button (bottom right)
	local importBtn = CreateFrame("Button", nil, footer)
	importBtn:SetPoint("RIGHT", footer, "RIGHT", -8, 0)
	local importText = importBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	importText:SetPoint("CENTER")
	importText:SetText(L["Import"])
	importText:SetTextColor(0.5, 1, 0.5) -- Light green
	importBtn:SetSize(importText:GetStringWidth() + 4, 16)
	importBtn:SetScript("OnClick", function() TSM:ShowImportDialog() end)
	importBtn:SetScript("OnEnter", function(self)
		importText:SetTextColor(0.7, 1, 0.7)
	end)
	importBtn:SetScript("OnLeave", function(self)
		importText:SetTextColor(0.5, 1, 0.5)
	end)

	-- Export button (left of Import)
	local exportBtn = CreateFrame("Button", nil, footer)
	exportBtn:SetPoint("RIGHT", importBtn, "LEFT", -8, 0)
	local exportText = exportBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	exportText:SetPoint("CENTER")
	exportText:SetText(L["Export"])
	exportText:SetTextColor(0.5, 0.8, 1) -- Light blue
	exportBtn:SetSize(exportText:GetStringWidth() + 4, 16)
	exportBtn:SetScript("OnClick", function() TSM:ShowExportDialog() end)
	exportBtn:SetScript("OnEnter", function(self)
		exportText:SetTextColor(0.7, 0.9, 1)
	end)
	exportBtn:SetScript("OnLeave", function(self)
		exportText:SetTextColor(0.5, 0.8, 1)
	end)

	-- Profile button (bottom left) - shows current profile name, click for menu
	local profileBtn = CreateFrame("Button", nil, footer)
	profileBtn:SetPoint("LEFT", footer, "LEFT", 8, 0)
	local profileText = profileBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	profileText:SetPoint("CENTER")
	profileText:SetTextColor(1, 1, 1)
	profileBtn.text = profileText
	profileBtn:SetScript("OnClick", function(self) TSM:ShowProfileMenu(self) end)
	profileBtn:SetScript("OnEnter", function(self)
		profileText:SetTextColor(1, 1, 0.5)
	end)
	profileBtn:SetScript("OnLeave", function(self)
		profileText:SetTextColor(1, 1, 1)
	end)
	frame.profileBtn = profileBtn

	-- Store references
	frame.header = header
	frame.content = content
	frame.footer = footer
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

function TSM:CreateNewProfileDialog()
	local dialog = CreateFrame("Frame", "TSMStocksDisplayNewProfileDialog", UIParent)
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
	title:SetText(L["New Profile"])

	-- Edit box
	local editBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
	editBox:SetSize(180, 20)
	editBox:SetPoint("TOP", title, "BOTTOM", 0, -15)
	editBox:SetAutoFocus(true)
	editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
	editBox:SetScript("OnEnterPressed", function(self)
		local name = self:GetText():trim()
		if name ~= "" then
			if TSM:CreateProfile(name) then
				TSM:SwitchProfile(name)
			end
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
			if TSM:CreateProfile(name) then
				TSM:SwitchProfile(name)
			end
			dialog:Hide()
		end
	end)

	-- Cancel button
	local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	cancelBtn:SetSize(80, 22)
	cancelBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 5, 10)
	cancelBtn:SetText(L["Cancel"])
	cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

	TSM.newProfileDialog = dialog
end

function TSM:CreateDeleteProfileDialog()
	local dialog = CreateFrame("Frame", "TSMStocksDisplayDeleteProfileDialog", UIParent)
	dialog:SetSize(250, 120)
	dialog:SetPoint("CENTER")
	dialog:SetFrameStrata("DIALOG")
	dialog:EnableMouse(true)
	dialog:Hide()
	TSMAPI.Design:SetFrameBackdropColor(dialog)

	-- Title
	local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", dialog, "TOP", 0, -10)
	title:SetText(L["Delete Profile"])
	dialog.title = title

	-- Dropdown for profile selection
	local dropdown = CreateFrame("Frame", "TSMStocksDisplayDeleteProfileDropdown", dialog, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOP", title, "BOTTOM", 0, -5)
	UIDropDownMenu_SetWidth(dropdown, 150)
	dialog.dropdown = dropdown

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

	TSM.deleteProfileDialog = dialog
end

function TSM:CreateExportDialog()
	local dialog = CreateFrame("Frame", "TSMStocksDisplayExportDialog", UIParent)
	dialog:SetSize(450, 350)
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
	title:SetText(L["Export Data"])

	-- Scroll frame for the text
	local scrollFrame = CreateFrame("ScrollFrame", "TSMStocksDisplayExportScrollFrame", dialog, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", dialog, "TOPLEFT", 15, -35)
	scrollFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -35, 45)

	-- Edit box (multi-line)
	local editBox = CreateFrame("EditBox", "TSMStocksDisplayExportEditBox", scrollFrame)
	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject(GameFontHighlightSmall)
	editBox:SetWidth(scrollFrame:GetWidth())
	editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
	scrollFrame:SetScrollChild(editBox)
	dialog.editBox = editBox

	-- Close button
	local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	closeBtn:SetSize(80, 22)
	closeBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 10)
	closeBtn:SetText(L["Close"])
	closeBtn:SetScript("OnClick", function() dialog:Hide() end)

	-- Instructions
	local instructions = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	instructions:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 15, 15)
	instructions:SetText("Ctrl+A to select all, Ctrl+C to copy")
	instructions:SetTextColor(0.7, 0.7, 0.7)

	TSM.exportDialog = dialog
end

function TSM:CreateImportDialog()
	local dialog = CreateFrame("Frame", "TSMStocksDisplayImportDialog", UIParent)
	dialog:SetSize(450, 350)
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
	title:SetText(L["Import Data"])

	-- Scroll frame for the text
	local scrollFrame = CreateFrame("ScrollFrame", "TSMStocksDisplayImportScrollFrame", dialog, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", dialog, "TOPLEFT", 15, -35)
	scrollFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -35, 45)

	-- Edit box (multi-line)
	local editBox = CreateFrame("EditBox", "TSMStocksDisplayImportEditBox", scrollFrame)
	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(true)
	editBox:SetFontObject(GameFontHighlightSmall)
	editBox:SetWidth(scrollFrame:GetWidth())
	editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
	scrollFrame:SetScrollChild(editBox)
	dialog.editBox = editBox

	-- Import button
	local importBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	importBtn:SetSize(80, 22)
	importBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -5, 10)
	importBtn:SetText(L["Import"])
	importBtn:SetScript("OnClick", function()
		local text = editBox:GetText()
		if text and text ~= "" then
			TSM:ImportFromString(text)
			dialog:Hide()
		end
	end)

	-- Cancel button
	local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	cancelBtn:SetSize(80, 22)
	cancelBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 5, 10)
	cancelBtn:SetText(L["Cancel"])
	cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

	-- Instructions
	local instructions = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	instructions:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 15, 15)
	instructions:SetText("Ctrl+V to paste")
	instructions:SetTextColor(0.7, 0.7, 0.7)

	TSM.importDialog = dialog
end

function TSM:GenerateExportString()
	-- Helper to extract item ID from "item:12345" format
	local function getItemId(itemString)
		return itemString:match("item:(%d+)") or itemString
	end

	local profileData = TSM:GetCurrentProfileData()
	local lines = {}
	local ungroupedIds = {}

	-- First, collect ungrouped items
	for itemString, groupName in pairs(profileData.trackedItems) do
		if not groupName or groupName == "" then
			tinsert(ungroupedIds, getItemId(itemString))
		end
	end

	-- Line 1: ungrouped items (comma-separated IDs)
	tinsert(lines, table.concat(ungroupedIds, ","))

	-- Then one line per group: "groupName:id1,id2,id3"
	for _, groupName in ipairs(profileData.groups) do
		local groupIds = {}
		for itemString, itemGroup in pairs(profileData.trackedItems) do
			if itemGroup == groupName then
				tinsert(groupIds, getItemId(itemString))
			end
		end
		if #groupIds > 0 then
			tinsert(lines, groupName .. ":" .. table.concat(groupIds, ","))
		else
			-- Empty group, still export it
			tinsert(lines, groupName .. ":")
		end
	end

	return table.concat(lines, "\n")
end

function TSM:ImportFromString(importString)
	local profileData = TSM:GetCurrentProfileData()

	-- Clear current data
	profileData.trackedItems = {}
	profileData.groups = {}

	local lines = { strsplit("\n", importString) }

	for lineNum, line in ipairs(lines) do
		line = line:trim()
		if line ~= "" then
			-- Check if it's a group line (contains ":")
			local groupName, itemIds = strsplit(":", line, 2)

			if itemIds then
				-- It's a group line: "groupName:id1,id2,id3"
				groupName = groupName:trim()
				if groupName ~= "" then
					tinsert(profileData.groups, groupName)

					-- Parse item IDs
					if itemIds and itemIds ~= "" then
						local ids = { strsplit(",", itemIds) }
						for _, id in ipairs(ids) do
							id = id:trim()
							if id ~= "" then
								-- Use full itemString format for TSM compatibility
								local itemString = "item:" .. id .. ":0:0:0:0:0:0"
								profileData.trackedItems[itemString] = groupName
							end
						end
					end
				end
			else
				-- It's the ungrouped items line (first line, no ":")
				local ids = { strsplit(",", line) }
				for _, id in ipairs(ids) do
					id = id:trim()
					if id ~= "" then
						-- Use full itemString format for TSM compatibility
						local itemString = "item:" .. id .. ":0:0:0:0:0:0"
						profileData.trackedItems[itemString] = ""
					end
				end
			end
		end
	end

	TSM:Print(L["Import completed."])
	TSM:RefreshDisplay()
end

function TSM:ShowExportDialog()
	if not TSM.exportDialog then
		TSM:CreateExportDialog()
	end

	local exportString = TSM:GenerateExportString()
	TSM.exportDialog.editBox:SetText(exportString)
	TSM.exportDialog:Show()

	-- Select all text for easy copying
	TSM.exportDialog.editBox:HighlightText()
	TSM.exportDialog.editBox:SetFocus()
end

function TSM:ShowImportDialog()
	if not TSM.importDialog then
		TSM:CreateImportDialog()
	end

	TSM.importDialog.editBox:SetText("")
	TSM.importDialog:Show()
	TSM.importDialog.editBox:SetFocus()
end

function TSM:ShowNewProfileDialog()
	if not TSM.newProfileDialog then
		TSM:CreateNewProfileDialog()
	end
	TSM.newProfileDialog.editBox:SetText("")
	TSM.newProfileDialog:Show()
	TSM.newProfileDialog.editBox:SetFocus()
end

function TSM:ShowDeleteProfileDialog()
	if not TSM.deleteProfileDialog then
		TSM:CreateDeleteProfileDialog()
	end

	local dialog = TSM.deleteProfileDialog
	local selectedProfile = nil

	UIDropDownMenu_Initialize(dialog.dropdown, function(self, level)
		local profiles = TSM:GetSortedProfileNames()
		for _, profileName in ipairs(profiles) do
			if profileName ~= "Default" then
				local info = UIDropDownMenu_CreateInfo()
				info.text = profileName
				info.func = function()
					selectedProfile = profileName
					UIDropDownMenu_SetText(dialog.dropdown, profileName)
					CloseDropDownMenus()
				end
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end)

	-- Set initial selection to first non-Default profile
	local profiles = TSM:GetSortedProfileNames()
	for _, profileName in ipairs(profiles) do
		if profileName ~= "Default" then
			selectedProfile = profileName
			UIDropDownMenu_SetText(dialog.dropdown, profileName)
			break
		end
	end

	dialog.deleteBtn:SetScript("OnClick", function()
		if selectedProfile then
			TSM:DeleteProfile(selectedProfile)
		end
		dialog:Hide()
	end)

	dialog:Show()
end

function TSM:ShowProfileMenu(anchorFrame)
	local menuList = {}

	-- Current profile as title
	tinsert(menuList, {
		text = TSM.db.profile.currentDisplayProfile,
		isTitle = true,
		notCheckable = true,
	})

	-- List all profiles
	local profiles = TSM:GetSortedProfileNames()
	for _, profileName in ipairs(profiles) do
		tinsert(menuList, {
			text = profileName,
			checked = (profileName == TSM.db.profile.currentDisplayProfile),
			func = function()
				TSM:SwitchProfile(profileName)
				CloseDropDownMenus()
			end,
		})
	end

	-- Separator
	tinsert(menuList, {
		text = "",
		disabled = true,
		notCheckable = true,
	})

	-- New Profile option
	tinsert(menuList, {
		text = L["New Profile..."],
		notCheckable = true,
		func = function()
			TSM:ShowNewProfileDialog()
			CloseDropDownMenus()
		end,
	})

	-- Delete Profile option (only if more than 1 profile)
	if #profiles > 1 then
		tinsert(menuList, {
			text = L["Delete Profile..."],
			notCheckable = true,
			func = function()
				TSM:ShowDeleteProfileDialog()
				CloseDropDownMenus()
			end,
		})
	end

	EasyMenu(menuList, TSM.contextMenu, anchorFrame, 0, 0, "MENU")
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

function TSM:ShowGroupSettingsMenu(anchorFrame, groupName)
	local menuList = {
		{ text = groupName, isTitle = true, notCheckable = true },
		{ text = L["Rename"], notCheckable = true,
			func = function()
				TSM:ShowRenameGroupDialog(groupName)
				CloseDropDownMenus()
			end
		},
		{ text = L["Move to profile"], notCheckable = true, hasArrow = true,
			menuList = TSM:GetGroupProfileMenuList(groupName)
		},
		{ text = L["Move up"], notCheckable = true,
			func = function()
				TSM:MoveGroupUp(groupName)
				CloseDropDownMenus()
			end
		},
		{ text = L["Move down"], notCheckable = true,
			func = function()
				TSM:MoveGroupDown(groupName)
				CloseDropDownMenus()
			end
		},
		{ text = L["Delete"], notCheckable = true,
			func = function()
				TSM:ShowDeleteConfirm(groupName)
				CloseDropDownMenus()
			end
		},
	}

	EasyMenu(menuList, TSM.contextMenu, anchorFrame, 0, 0, "MENU")
end

function TSM:GetGroupProfileMenuList(groupName)
	local list = {}
	local profiles = TSM:GetSortedProfileNames()

	for _, profileName in ipairs(profiles) do
		-- Skip current profile
		if profileName ~= TSM.db.profile.currentDisplayProfile then
			tinsert(list, {
				text = profileName,
				notCheckable = true,
				func = function()
					TSM:MoveGroupToProfile(groupName, profileName)
					CloseDropDownMenus()
				end
			})
		end
	end

	-- If no other profiles, show disabled message
	if #list == 0 then
		tinsert(list, {
			text = L["No other profiles"],
			notCheckable = true,
			disabled = true,
		})
	end

	return list
end

function TSM:MoveGroupToProfile(groupName, targetProfileName)
	local currentProfileData = TSM:GetCurrentProfileData()
	local targetProfileData = TSM.db.profile.displayProfiles[targetProfileName]

	if not targetProfileData then return end

	-- Add group to target profile if it doesn't exist
	local groupExists = false
	for _, existingGroup in ipairs(targetProfileData.groups) do
		if existingGroup == groupName then
			groupExists = true
			break
		end
	end
	if not groupExists then
		tinsert(targetProfileData.groups, groupName)
	end

	-- Move all items from this group to target profile
	for itemString, itemGroup in pairs(currentProfileData.trackedItems) do
		if itemGroup == groupName then
			currentProfileData.trackedItems[itemString] = nil
			targetProfileData.trackedItems[itemString] = groupName
		end
	end

	-- Remove group from current profile
	for i, existingGroup in ipairs(currentProfileData.groups) do
		if existingGroup == groupName then
			tremove(currentProfileData.groups, i)
			break
		end
	end

	TSM:Print(format(L["Moved group '%s' to profile '%s'"], groupName, targetProfileName))
	TSM:RefreshDisplay()
end

function TSM:ShowRenameGroupDialog(oldName)
	if not TSM.renameGroupDialog then
		TSM:CreateRenameGroupDialog()
	end

	TSM.renameGroupDialog.oldName = oldName
	TSM.renameGroupDialog.editBox:SetText(oldName)
	TSM.renameGroupDialog:Show()
	TSM.renameGroupDialog.editBox:SetFocus()
	TSM.renameGroupDialog.editBox:HighlightText()
end

function TSM:CreateRenameGroupDialog()
	local dialog = CreateFrame("Frame", "TSMStocksDisplayRenameGroupDialog", UIParent)
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
	title:SetText(L["Rename Group"])

	-- Edit box
	local editBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
	editBox:SetSize(180, 20)
	editBox:SetPoint("TOP", title, "BOTTOM", 0, -15)
	editBox:SetAutoFocus(true)
	editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
	editBox:SetScript("OnEnterPressed", function(self)
		local newName = self:GetText():trim()
		if newName ~= "" and newName ~= dialog.oldName then
			TSM:RenameGroup(dialog.oldName, newName)
		end
		dialog:Hide()
	end)
	dialog.editBox = editBox

	-- Rename button
	local renameBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	renameBtn:SetSize(80, 22)
	renameBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -5, 10)
	renameBtn:SetText(L["Rename"])
	renameBtn:SetScript("OnClick", function()
		local newName = editBox:GetText():trim()
		if newName ~= "" and newName ~= dialog.oldName then
			TSM:RenameGroup(dialog.oldName, newName)
		end
		dialog:Hide()
	end)

	-- Cancel button
	local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	cancelBtn:SetSize(80, 22)
	cancelBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 5, 10)
	cancelBtn:SetText(L["Cancel"])
	cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

	TSM.renameGroupDialog = dialog
end

function TSM:RenameGroup(oldName, newName)
	local profileData = TSM:GetCurrentProfileData()

	-- Check if new name already exists
	for _, groupName in ipairs(profileData.groups) do
		if groupName == newName then
			TSM:Print(format(L["Group '%s' already exists."], newName))
			return
		end
	end

	-- Rename in groups list
	for i, groupName in ipairs(profileData.groups) do
		if groupName == oldName then
			profileData.groups[i] = newName
			break
		end
	end

	-- Update items that belong to this group
	for itemString, itemGroup in pairs(profileData.trackedItems) do
		if itemGroup == oldName then
			profileData.trackedItems[itemString] = newName
		end
	end

	-- Clear cached header for old name so it gets recreated
	if TSM.stockFrame and TSM.stockFrame.groupHeaders[oldName] then
		TSM.stockFrame.groupHeaders[oldName]:Hide()
		TSM.stockFrame.groupHeaders[oldName] = nil
	end

	TSM:Print(format(L["Group renamed to '%s'"], newName))
	TSM:RefreshDisplay()
end

function TSM:ShowContextMenu(itemButton)
	local itemString = itemButton.itemString
	if not itemString then return end

	local menuList = {
		{ text = GetItemInfo(itemString) or itemString, isTitle = true, notCheckable = true },
		{ text = L["Move to group"], notCheckable = true, hasArrow = true,
			menuList = TSM:GetGroupMenuList(itemString)
		},
		{ text = L["Move to profile"], notCheckable = true, hasArrow = true,
			menuList = TSM:GetProfileMenuList(itemString)
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

	local profileData = TSM:GetCurrentProfileData()
	for _, groupName in ipairs(profileData.groups) do
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

function TSM:GetProfileMenuList(itemString)
	local list = {}
	local profiles = TSM:GetSortedProfileNames()

	for _, profileName in ipairs(profiles) do
		-- Skip current profile
		if profileName ~= TSM.db.profile.currentDisplayProfile then
			local profileData = TSM.db.profile.displayProfiles[profileName]

			-- Build submenu with "Root" and groups
			local submenu = {
				{ text = L["Root"], notCheckable = true,
					func = function()
						TSM:MoveItemToProfile(itemString, profileName, "")
						CloseDropDownMenus()
					end
				},
			}

			-- Add groups from target profile
			for _, groupName in ipairs(profileData.groups) do
				tinsert(submenu, {
					text = groupName, notCheckable = true,
					func = function()
						TSM:MoveItemToProfile(itemString, profileName, groupName)
						CloseDropDownMenus()
					end
				})
			end

			tinsert(list, {
				text = profileName,
				notCheckable = true,
				hasArrow = true,
				menuList = submenu,
			})
		end
	end

	-- If no other profiles, show disabled message
	if #list == 0 then
		tinsert(list, {
			text = L["No other profiles"],
			notCheckable = true,
			disabled = true,
		})
	end

	return list
end

function TSM:MoveItemToProfile(itemString, targetProfileName, targetGroup)
	local currentProfileData = TSM:GetCurrentProfileData()
	local targetProfileData = TSM.db.profile.displayProfiles[targetProfileName]

	if not targetProfileData then return end

	-- Remove from current profile
	currentProfileData.trackedItems[itemString] = nil

	-- Add to target profile
	targetProfileData.trackedItems[itemString] = targetGroup or ""

	local itemName = GetItemInfo(itemString) or itemString
	TSM:Print(format(L["Moved %s to profile '%s'"], itemName, targetProfileName))

	TSM:RefreshDisplay()
end

function TSM:CreateGroup(name)
	local profileData = TSM:GetCurrentProfileData()

	-- Check if group already exists
	for _, groupName in ipairs(profileData.groups) do
		if groupName == name then
			TSM:Print(format(L["Group '%s' already exists."], name))
			return
		end
	end

	tinsert(profileData.groups, name)
	TSM:Print(format(L["Group '%s' created."], name))
	TSM:RefreshDisplay()
end

function TSM:DeleteGroup(name)
	local profileData = TSM:GetCurrentProfileData()

	-- Remove group from list
	for i, groupName in ipairs(profileData.groups) do
		if groupName == name then
			tremove(profileData.groups, i)
			break
		end
	end

	-- Move items from this group to ungrouped
	for itemString, group in pairs(profileData.trackedItems) do
		if group == name then
			profileData.trackedItems[itemString] = ""
		end
	end

	TSM:Print(format(L["Group '%s' deleted."], name))
	TSM:RefreshDisplay()
end

function TSM:SetItemGroup(itemString, groupName)
	local profileData = TSM:GetCurrentProfileData()
	profileData.trackedItems[itemString] = groupName or ""
	TSM:RefreshDisplay()
end

function TSM:RefreshDisplay()
	local frame = TSM.stockFrame
	if not frame then return end

	local content = frame.content

	-- Update profile button text
	if frame.profileBtn then
		local profileName = TSM.db.profile.currentDisplayProfile
		frame.profileBtn.text:SetText(profileName .. " ▼")
		frame.profileBtn:SetSize(frame.profileBtn.text:GetStringWidth() + 4, 16)
	end

	-- Hide all existing buttons and group headers
	for _, btn in pairs(frame.itemButtons) do
		btn:Hide()
	end
	for _, header in pairs(frame.groupHeaders) do
		header:Hide()
	end

	if TSM.db.profile.collapsed then
		content:Hide()
		frame.footer:Hide()
		frame:SetSize(ICONS_PER_ROW * ICON_SIZE + PADDING * 2, HEADER_HEIGHT)
		return
	end

	content:Show()
	frame.footer:Show()

	-- Get ItemTracker addon
	local ItemTracker = LibStub("AceAddon-3.0"):GetAddon("TSM_ItemTracker", true)
	if not ItemTracker then return end

	-- Get current profile data
	local profileData = TSM:GetCurrentProfileData()

	-- Organize items by group
	local ungroupedItems = {}
	local groupedItems = {}

	for itemString, groupName in pairs(profileData.trackedItems) do
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
	for _, groupName in ipairs(profileData.groups) do
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

	-- Update window size (include footer height)
	local contentHeight = math.max(ICON_SIZE, yOffset)
	content:SetHeight(contentHeight)
	frame:SetSize(ICONS_PER_ROW * ICON_SIZE + PADDING * 2, HEADER_HEIGHT + contentHeight + PADDING + FOOTER_HEIGHT)
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
		local count = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalOutlineSmall")
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

		-- Settings button (gear icon) - aligned right, smaller size (~33% reduction: 14 -> 10)
		local settingsBtn = CreateFrame("Button", nil, header)
		settingsBtn:SetSize(10, 10)
		settingsBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)

		local settingsIcon = settingsBtn:CreateTexture(nil, "ARTWORK")
		settingsIcon:SetAllPoints()
		settingsIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
		settingsIcon:SetVertexColor(0.7, 0.7, 0.7)
		settingsBtn.icon = settingsIcon

		settingsBtn:SetScript("OnClick", function(self)
			TSM:ShowGroupSettingsMenu(self, groupName)
		end)
		settingsBtn:SetScript("OnEnter", function(self)
			settingsIcon:SetVertexColor(1, 1, 1)
		end)
		settingsBtn:SetScript("OnLeave", function(self)
			settingsIcon:SetVertexColor(0.7, 0.7, 0.7)
		end)

		frame.groupHeaders[groupName] = header
	end

	return header
end

function TSM:MoveGroupUp(groupName)
	local profileData = TSM:GetCurrentProfileData()
	local groups = profileData.groups
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
	local profileData = TSM:GetCurrentProfileData()
	local groups = profileData.groups
	for i, name in ipairs(groups) do
		if name == groupName and i < #groups then
			-- Swap with next
			groups[i], groups[i + 1] = groups[i + 1], groups[i]
			TSM:RefreshDisplay()
			return
		end
	end
end

function TSM:FormatCount(count)
	if count >= 1000 then
		local thousands = math.floor(count / 1000)
		local hundreds = math.floor((count % 1000) / 100)
		if hundreds > 0 then
			return thousands .. "k" .. hundreds
		else
			return thousands .. "k"
		end
	end
	return tostring(count)
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
		-- Ascension WoW: Include personal banks and realm bank
		local personalBanksTotal = ItemTracker:GetPersonalBanksTotal(itemString) or 0
		local realmBankTotal = ItemTracker:GetRealmBankTotal(itemString) or 0
		local total = (playerTotal or 0) + (altTotal or 0) + guildTotal + auctionTotal + personalBanksTotal + realmBankTotal

		btn.count:SetText(TSM:FormatCount(total))
	else
		btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		btn.itemString = itemString
		btn.itemLink = nil
		btn.count:SetText("?")
	end
end

function TSM:AddTrackedItem(itemString)
	local profileData = TSM:GetCurrentProfileData()

	-- Check if already tracked
	if profileData.trackedItems[itemString] then
		TSM:Print(L["Item already in stock display."])
		return
	end

	-- Add to list (ungrouped by default)
	profileData.trackedItems[itemString] = ""

	local itemName = GetItemInfo(itemString) or itemString
	TSM:Print(format(L["Item added to stock display: %s"], itemName))

	TSM:RefreshDisplay()
end

function TSM:RemoveTrackedItem(itemString)
	local profileData = TSM:GetCurrentProfileData()

	if profileData.trackedItems[itemString] then
		local itemName = GetItemInfo(itemString) or itemString
		profileData.trackedItems[itemString] = nil
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
