local fw = require("TestFramework")
local WowMock = require("WowMock")
local Env = require("Env")

fw.describe("MiniCombatNotifier - combat event routing", function()
	local env

	fw.before_each(function()
		env = Env.Build()
	end)

	fw.it("shows the entering-combat text and color on PLAYER_REGEN_DISABLED", function()
		WowMock.FireEvent("PLAYER_REGEN_DISABLED")

		local text = env.TextFrame()
		local color = env.Addon.Db.EnteringCombatTextColor

		fw.truthy(text:IsShown(), "the notification shows")
		fw.eq(text:GetText(), env.Addon.Db.EnteringCombatText, "it carries the entering-combat text")

		local r, g, b, a = text:GetTextColor()
		fw.eq(r, color.R, "red channel matches the entering-combat color")
		fw.eq(g, color.G, "green channel matches the entering-combat color")
		fw.eq(b, color.B, "blue channel matches the entering-combat color")
		fw.eq(a, color.A, "alpha channel matches the entering-combat color")

		fw.truthy(env.AnimationGroup:IsPlaying(), "the fade animation starts")
	end)

	fw.it("shows the leaving-combat text and color on PLAYER_REGEN_ENABLED", function()
		WowMock.FireEvent("PLAYER_REGEN_ENABLED")

		local text = env.TextFrame()
		local color = env.Addon.Db.LeavingCombatTextColor

		fw.truthy(text:IsShown(), "the notification shows")
		fw.eq(text:GetText(), env.Addon.Db.LeavingCombatText, "it carries the leaving-combat text")

		local r, g, b, a = text:GetTextColor()
		fw.eq(r, color.R, "red channel matches the leaving-combat color")
		fw.eq(g, color.G, "green channel matches the leaving-combat color")
		fw.eq(b, color.B, "blue channel matches the leaving-combat color")
		fw.eq(a, color.A, "alpha channel matches the leaving-combat color")
	end)
end)

fw.describe("MiniCombatNotifier - the fade animation sequence", function()
	local env

	fw.before_each(function()
		-- Distinct from DbDefaults' 0.5/0.5/0.5, so a hardcoded duration would still pass a
		-- test built against the defaults.
		env = Env.Build({ FadeInDuration = 0.25, HoldDuration = 1.25, FadeOutDuration = 2.25 })
	end)

	fw.it("orders the three stages fade in, hold, fade out with durations read from config", function()
		fw.eq(#env.Animations, 3, "Init() builds exactly three animation stages")

		local fadeIn, hold, fadeOut = env.Animations[1], env.Animations[2], env.Animations[3]

		fw.eq(fadeIn:GetOrder(), 1, "fade in runs first")
		fw.eq(fadeIn:GetDuration(), 0.25, "fade in's duration comes from FadeInDuration")
		fw.eq(fadeIn:GetFromAlpha(), 0, "fade in starts invisible")
		fw.eq(fadeIn:GetToAlpha(), 1, "fade in ends opaque")

		fw.eq(hold:GetOrder(), 2, "hold runs second")
		fw.eq(hold:GetDuration(), 1.25, "hold's duration comes from HoldDuration")
		fw.eq(hold:GetFromAlpha(), 1, "hold starts opaque")
		fw.eq(hold:GetToAlpha(), 1, "hold stays opaque")

		fw.eq(fadeOut:GetOrder(), 3, "fade out runs third")
		fw.eq(fadeOut:GetDuration(), 2.25, "fade out's duration comes from FadeOutDuration")
		fw.eq(fadeOut:GetFromAlpha(), 1, "fade out starts opaque")
		fw.eq(fadeOut:GetToAlpha(), 0, "fade out ends invisible")
	end)

	fw.it("hides the text frame once the animation finishes", function()
		WowMock.FireEvent("PLAYER_REGEN_DISABLED")

		local text = env.TextFrame()
		fw.truthy(text:IsShown(), "shown while the sequence runs")

		env.AnimationGroup:GetScript("OnFinished")()

		fw.falsy(text:IsShown(), "the finish handler hides it")
	end)
end)

fw.describe("MiniCombatNotifier - test mode", function()
	local env

	fw.before_each(function()
		env = Env.Build()
	end)

	fw.it("shows the notification and makes it draggable once enabled", function()
		env.Addon.SetTestMode(true)

		local text = env.TextFrame()
		local container = env.Container()

		fw.truthy(text:IsShown(), "the preview shows")
		fw.eq(text:GetAlpha(), 1, "fully opaque, not mid-fade")
		fw.eq(text:GetText(), env.Addon.Db.EnteringCombatText, "previews the entering-combat text")
		fw.truthy(container:IsMovable(), "the container can be dragged")
		fw.truthy(container:IsMouseEnabled(), "the container can receive the drag")
		fw.not_nil(container:GetScript("OnDragStart"), "a drag start handler is wired")
	end)

	fw.it("hides the notification and stops it dragging once disabled", function()
		env.Addon.SetTestMode(true)
		env.Addon.SetTestMode(false)

		local text = env.TextFrame()
		local container = env.Container()

		fw.falsy(text:IsShown(), "the preview hides")
		fw.eq(text:GetAlpha(), 0, "faded back out")
		fw.falsy(container:IsMouseEnabled(), "no longer draggable")
		fw.is_nil(container:GetScript("OnDragStart"), "the drag start handler is removed")
		fw.is_nil(container:GetScript("OnDragStop"), "the drag stop handler is removed")
	end)
end)

fw.describe("MiniCombatNotifier - font fallback", function()
	local env

	fw.before_each(function()
		env = Env.Build()
	end)

	-- The mock's own SetFontObject accepts nil without complaint, so "does not crash" alone
	-- would pass whether or not the guard exists.
	fw.it("keeps its current font instead of losing it to a nil font object", function()
		local before = env.TextFrame():GetFontObject()
		fw.not_nil(before, "a real font object is already applied")

		env.Addon.Fonts.FileFontObject = function()
			return nil
		end

		fw.no_error(function()
			env.Addon.RefreshDisplay()
		end, "RefreshDisplay tolerates a missing font object")

		fw.eq(env.TextFrame():GetFontObject(), before, "the guard skips SetFontObject rather than clearing the font")
	end)
end)

Env.Teardown()
