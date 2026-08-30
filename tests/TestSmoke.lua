-- Loads the whole addon into a mocked client and drives it through login.
-- The shared body lives in build/Lua/SmokeTest.lua.

local fw = require("TestFramework")
local smoke = require("SmokeTest")
local WowMock = require("WowMock")

---The section rule is built by the framework and never handed back to the addon, so a test
---finds one by its label and the order it was created in.
---@param text string
---@return integer? the frame's index in creation order, nil when no such divider exists
local function DividerIndex(text)
	for i, frame in ipairs(WowMock.Frames) do
		if frame.Label and frame.Label.GetText and frame.Label:GetText() == text then
			return i
		end
	end
end

---A colour swatch is a bare Button with no label of its own, so only its MiniRefresh marks it
---out from the panel's other buttons.
---@return integer? the first swatch's index in creation order, nil when none was created
local function FirstColorSwatchIndex()
	for i, frame in ipairs(WowMock.Frames) do
		if frame:GetObjectType() == "Button" and frame.MiniRefresh then
			return i
		end
	end
end

---The last Button with this text, since a toggled label can leave an earlier one stale.
---@param text string
---@return table?
local function FindButton(text)
	local button

	for _, frame in ipairs(WowMock.Frames) do
		if frame:GetObjectType() == "Button" and frame.GetText and frame:GetText() == text then
			button = frame
		end
	end

	return button
end

---The font dropdown is the first modern dropdown this panel builds, ahead of the font style
---dropdown.
---@return table?
local function FindFontDropdown()
	for _, frame in ipairs(WowMock.Frames) do
		if frame.__menuGenerator then
			return frame
		end
	end
end

---A modern dropdown only exposes its choices through the generator it handed to SetupMenu, so a
---test replays that generator against a description that keeps the callbacks.
---@param dd table
---@return table<string, fun()>
local function MenuChoices(dd)
	local choices = {}
	local description = {}

	setmetatable(description, {
		__index = function()
			return function() end
		end,
	})

	description.CreateRadio = function(_, text, _, setSelected)
		choices[text] = setSelected

		return nil
	end

	dd.__menuGenerator(dd, description)

	return choices
end

---@return boolean
local function TestButtonSitsLeftOfReset()
	local test = FindButton("Test")
	local reset = FindButton("Reset to Defaults")

	if not test or not reset then
		return false
	end

	local point, relativeTo, relativePoint = test:GetPoint()

	return point == "RIGHT" and relativeTo == reset and relativePoint == "LEFT"
end

---The client does nothing with a prompt in the mock, so a test stands in for it.
---@param open fun()
---@return boolean
local function AcceptConfirm(open)
	local seen
	local real = StaticPopup_Show

	StaticPopup_Show = function(which, _, _, data)
		seen = { Which = which, Data = data }
	end

	local ok, err = pcall(open)

	StaticPopup_Show = real

	if not ok then
		error(err, 0)
	end

	if not seen then
		return false
	end

	StaticPopupDialogs[seen.Which].OnAccept(nil, seen.Data)

	return true
end

---Clicks the panel's reset button and accepts the confirmation, the way a player would, then
---checks the setting it changed came back to its default.
---@param db table
---@return boolean
local function ResetButtonAppliesDefaults(db)
	local resetBtn = FindButton("Reset to Defaults")

	if not resetBtn then
		return false
	end

	local onClick = resetBtn:GetScript("OnClick")

	if not AcceptConfirm(function()
		onClick(resetBtn)
	end) then
		return false
	end

	return db.EnteringCombatText ~= "changed"
end

smoke.Run("MiniCombatNotifier", {
	extra = function(context)
		fw.eq(context.Addon.Framework.CustomStyling, true, "custom styling on")
		fw.eq(context.Addon.Framework.CustomStylingOverrides.Button, false, "stock buttons")
		fw.truthy(TestButtonSitsLeftOfReset(), "the test button sits left of the reset button")

		fw.falsy(DividerIndex("COLORS"), "the colors divider was removed")

		local fontDivider = DividerIndex("FONT")
		local colorSwatch = FirstColorSwatchIndex()

		fw.truthy(fontDivider and colorSwatch and colorSwatch > fontDivider, "the colour controls moved into the font section")

		context.Addon.Db.EnteringCombatText = "changed"
		fw.truthy(ResetButtonAppliesDefaults(context.Addon.Db), "the framework's reset button restores defaults")

		local fontDD = FindFontDropdown()
		fw.not_nil(fontDD, "the font dropdown exists")

		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		fw.not_nil(lsm, "LibSharedMedia resolves under the mock")

		local newFontName = "MiniCombatNotifier Test Face"
		lsm:Register("font", newFontName, "Fonts\\MiniCombatNotifierTestFace.ttf")

		fw.no_key(MenuChoices(fontDD), newFontName, "the registration alone doesn't rebuild the list yet")

		WowMock.RunTimers()

		fw.has_key(MenuChoices(fontDD), newFontName, "the font appears once the coalesced refresh runs")

		local secondFontName = "MiniCombatNotifier Second Test Face"
		local thirdFontName = "MiniCombatNotifier Third Test Face"

		lsm:Register("font", secondFontName, "Fonts\\MiniCombatNotifierSecondTestFace.ttf")
		lsm:Register("font", thirdFontName, "Fonts\\MiniCombatNotifierThirdTestFace.ttf")

		fw.eq(WowMock.RunTimers(), 1, "two registrations in one frame coalesce into a single refresh")
		fw.has_key(MenuChoices(fontDD), secondFontName, "the first of the pair lands after the one refresh")
		fw.has_key(MenuChoices(fontDD), thirdFontName, "the second of the pair lands after the same refresh")

		local overrideTargetName = "MiniCombatNotifier Override Target Face"
		lsm:Register("font", overrideTargetName, "Fonts\\MiniCombatNotifierOverrideTargetFace.ttf")
		WowMock.RunTimers()

		lsm:SetGlobal("font", overrideTargetName)

		local fourthFontName = "MiniCombatNotifier Fourth Test Face"
		lsm:Register("font", fourthFontName, "Fonts\\MiniCombatNotifierFourthTestFace.ttf")

		WowMock.RunTimers()

		local overridden = MenuChoices(fontDD)
		fw.has_key(overridden, overrideTargetName, "the overridden face keeps its own name once a global font is set")
		fw.has_key(overridden, fourthFontName, "a face registered after the override still gets its own name")

		lsm:SetGlobal("font", nil)

		local refreshCount = 0
		local originalMiniRefresh = fontDD.MiniRefresh

		fontDD.MiniRefresh = function(...)
			refreshCount = refreshCount + 1
			return originalMiniRefresh(...)
		end

		lsm:Register("font", "MiniCombatNotifier Spy Face", "Fonts\\MiniCombatNotifierSpyFace.ttf")
		WowMock.RunTimers()

		fw.eq(refreshCount, 1, "the font dropdown is told to redraw once after a registration")

		fontDD.MiniRefresh = originalMiniRefresh
	end,
})
