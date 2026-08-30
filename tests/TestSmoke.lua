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

---A modern dropdown only exposes its rows through the generator it handed to SetupMenu, so a
---test replays that generator against a description that keeps the callbacks.
---@param dd table
---@param createRadio fun(root: table, text: string, isSelected: function, setSelected: fun(), value: any): table?
local function ReplayMenu(dd, createRadio)
	local description = setmetatable({ CreateRadio = createRadio }, {
		__index = function()
			return function() end
		end,
	})

	dd.__menuGenerator(dd, description)
end

---@param dd table
---@return table<string, fun()>
local function MenuChoices(dd)
	local choices = {}

	ReplayMenu(dd, function(_, text, _, setSelected)
		choices[text] = setSelected
	end)

	return choices
end

---The row a value selects. A row's label is the font's name while the display stores its file,
---so a lookup by label never matches what is in the db.
---@param dd table
---@return table<any, fun()>
local function MenuChoicesByValue(dd)
	local choices = {}

	ReplayMenu(dd, function(_, _, _, setSelected, value)
		choices[value] = setSelected
	end)

	return choices
end

---The shared mock's own menu description has no AddInitializer, so calling a decorator directly
---would stay green even if it were never wired to the dropdown.
---@param dd table
---@return table<any, fun(button: table)>
local function MenuInitializers(dd)
	local initializers = {}

	ReplayMenu(dd, function(_, _, _, _, value)
		local node = {}

		node.AddInitializer = function(_, initializer)
			initializers[value] = initializer
		end

		return node
	end)

	return initializers
end

---A stand-in for a row's font string, tracking whichever font object it was last handed.
---@param initial table?
---@return table
local function StubFontString(initial)
	local stub = { object = initial }

	function stub:GetFontObject()
		return self.object
	end

	function stub:SetFontObject(object)
		self.object = object
	end

	return stub
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

---The display's text, which the addon keeps to itself, found through the one container it names.
---@return table?
local function FindDisplayText()
	local container = _G["MiniCombatNotifierContainer"]

	if not container then
		return nil
	end

	for _, region in ipairs({ container:GetRegions() }) do
		if region:GetObjectType() == "FontString" then
			return region
		end
	end
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

		local _, fontInitializer = next(MenuInitializers(fontDD))
		fw.not_nil(fontInitializer, "the font dropdown wires a row initializer")

		local stockFont = {}
		local button = { fontString = StubFontString(stockFont) }

		fontInitializer(button)

		local previewed = button.fontString:GetFontObject()
		fw.truthy(previewed ~= nil and previewed ~= stockFont, "the row previews the font it names")

		-- A plain CreateFont object has no __members, and an incomplete family has fewer than
		-- five, so this one count proves both the family route and the full alphabet list.
		fw.eq(previewed.__members and #previewed.__members or 0, 5, "the preview is a family declaring all five alphabets")

		local capturedStock = button.MiniCombatNotifierStockFont
		fw.eq(capturedStock, stockFont, "the row's original face is captured before the preview is applied")

		fontInitializer(button)
		fw.eq(button.MiniCombatNotifierStockFont, capturedStock, "a reopened row keeps the face it first captured")

		local originalGetFontObjectForAlphabet = GameFontNormal.GetFontObjectForAlphabet

		GameFontNormal.GetFontObjectForAlphabet = function(_, alphabet)
			return { GetFont = function() return "Fonts\\" .. alphabet .. ".ttf" end }
		end

		local Fonts = context.Addon.Fonts
		fw.not_nil(Fonts, "the addon exposes its Fonts module")

		local customFile = "Fonts\\MiniCombatNotifierCustomFace.ttf"
		local substituted = Fonts:FileFontObject(customFile, 18, "OUTLINE")
		local ownAlphabetFile, otherAlphabetFile

		for _, member in ipairs(substituted.__members) do
			if member.alphabet == "roman" then
				ownAlphabetFile = member.file
			elseif member.alphabet == "korean" then
				otherAlphabetFile = member.file
			end
		end

		GameFontNormal.GetFontObjectForAlphabet = originalGetFontObjectForAlphabet

		fw.eq(ownAlphabetFile, customFile, "the client's own alphabet keeps the requested face")
		fw.eq(otherAlphabetFile, "Fonts\\korean.ttf", "another alphabet borrows the client's own file for it")

		local firstFile = "Fonts\\FRIZQT__.TTF"
		local first = Fonts:FileFontObject(firstFile, 18, "OUTLINE")
		local second = Fonts:FileFontObject(firstFile, 18, "OUTLINE")
		local third = Fonts:FileFontObject(firstFile, 18, "")

		fw.truthy(first == second, "the same file, size and flags return the same cached object")
		fw.truthy(first ~= third, "a different flags value returns a different object")

		local displayText = FindDisplayText()

		fw.not_nil(displayText, "the display's text exists")

		local before = displayText:GetFontObject()

		fw.not_nil(before, "the display took a font object rather than a raw SetFont")

		local db = _G.MiniCombatNotifierDB
		local byValue = MenuChoicesByValue(fontDD)

		fw.has_key(byValue, db.FontPath, "the face in use is one of the rows, so skipping it has work to do")

		local pick

		for file, choose in pairs(byValue) do
			if file ~= db.FontPath then
				pick = choose
				break
			end
		end

		fw.not_nil(pick, "the dropdown lists a face other than the one in use")

		local message = displayText:GetText()

		fw.truthy(message ~= "", "the display is showing a message to repaint")

		local repaints = {}
		local SetText = displayText.SetText

		displayText.SetText = function(text, value)
			repaints[#repaints + 1] = value

			return SetText(text, value)
		end

		pick()

		displayText.SetText = SetText

		fw.truthy(displayText:GetFontObject() ~= before, "picking another face hands the display a different object")
		fw.eq(repaints[1], "", "the message is cleared so the new face redraws it")
		fw.eq(repaints[2], message, "and then put back")
	end,
})
