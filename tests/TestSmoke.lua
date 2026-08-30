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

---The Test Mode button sits after the X/Y boxes now, so a test follows its own anchor rather
---than reading the layout code back.
---@return boolean
local function TestModeButtonFollowsCoordinates()
	local button

	for _, frame in ipairs(WowMock.Frames) do
		if frame:GetObjectType() == "Button" and frame.GetText and frame:GetText() == "Enable Test Mode" then
			button = frame
		end
	end

	if not button then
		return false
	end

	local _, relativeTo = button:GetPoint()

	return relativeTo ~= nil and relativeTo:GetObjectType() == "EditBox"
end

smoke.Run("MiniCombatNotifier", {
	extra = function(context)
		fw.eq(context.Addon.Framework.CustomStyling, true, "custom styling on")
		fw.eq(context.Addon.Framework.CustomStylingOverrides.Button, false, "stock buttons")
		fw.truthy(TestModeButtonFollowsCoordinates(), "test mode button anchored after the coordinate boxes")

		fw.falsy(DividerIndex("COLORS"), "the colors divider was removed")

		local fontDivider = DividerIndex("FONT")
		local colorSwatch = FirstColorSwatchIndex()

		fw.truthy(fontDivider and colorSwatch and colorSwatch > fontDivider, "the colour controls moved into the font section")
	end,
})
