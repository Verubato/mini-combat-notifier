-- Loads the whole addon into a mocked client and drives it through login.
-- The shared body lives in build/Lua/SmokeTest.lua.

local fw = require("TestFramework")
local smoke = require("SmokeTest")
local WowMock = require("WowMock")

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
	end,
})
