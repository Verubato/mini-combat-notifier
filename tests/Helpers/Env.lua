-- Loads MiniCombatNotifier into a mocked client. OnCombatEvent, ApplyFont and the fade
-- animation Init() builds are all file-local, so these drive them through the events the addon
-- registers for and the public API it exposes (addon.Db, addon.RefreshDisplay,
-- addon.SetTestMode, addon.Fonts), and read state back off the frames the addon itself named or
-- parented under its container.

local harness = require("AddonHarness")

local M = {}

local patched = false
local currentEnv

---The mock's animation methods are no-ops and GetDuration always answers 0 (see
---build/Lua/WowMock.lua's widget table), so a test can't otherwise see what Init() configured
---each stage with. This patches the shared widget prototype, reached through any frame's own
---metatable since WowMock exports no handle to it directly, to actually record what is set and
---to capture each animation/group Init() creates, in creation order.
local function EnsurePatched()
	if patched then
		return
	end

	patched = true

	local proto = getmetatable(_G.UIParent).__index

	local realCreateAnimation = proto.CreateAnimation
	proto.CreateAnimation = function(self, ...)
		local animation = realCreateAnimation(self, ...)

		if currentEnv then
			currentEnv.Animations[#currentEnv.Animations + 1] = animation
		end

		return animation
	end

	local realCreateAnimationGroup = proto.CreateAnimationGroup
	proto.CreateAnimationGroup = function(self, ...)
		local group = realCreateAnimationGroup(self, ...)

		if currentEnv then
			currentEnv.AnimationGroup = group
		end

		return group
	end

	proto.SetDuration = function(self, seconds)
		self.__duration = seconds
	end

	proto.GetDuration = function(self)
		return self.__duration
	end

	proto.SetFromAlpha = function(self, alpha)
		self.__fromAlpha = alpha
	end

	proto.GetFromAlpha = function(self)
		return self.__fromAlpha
	end

	proto.SetToAlpha = function(self, alpha)
		self.__toAlpha = alpha
	end

	proto.GetToAlpha = function(self)
		return self.__toAlpha
	end

	proto.SetOrder = function(self, order)
		self.__order = order
	end

	proto.GetOrder = function(self)
		return self.__order
	end
end

---@param env table
local function InstallOverrides(env, context)
	env.Context = context
	env.Addon = context.Addon
	env.Animations = {}

	currentEnv = env

	---@return table the container frame Init() names, and MakeMovable/EnableMouse act on
	function env.Container()
		return _G["MiniCombatNotifierContainer"]
	end

	---The display's own text, which the addon keeps to itself, found through its named container.
	---@return table?
	function env.TextFrame()
		local container = env.Container()

		if not container then
			return nil
		end

		for _, region in ipairs({ container:GetRegions() }) do
			if region:IsObjectType("FontString") then
				return region
			end
		end
	end
end

---Logs in, seeding the account-wide saved variables with dbOverrides first so Init() builds the
---animations and applies the font from those values rather than the shipped defaults.
---@param dbOverrides table?
---@return table env
function M.Build(dbOverrides)
	_G["MiniCombatNotifierDB"] = dbOverrides or {}

	local context = harness.Load("MiniCombatNotifier")
	local env = {}

	EnsurePatched()
	InstallOverrides(env, context)
	harness.Login(context)

	return env
end

---The prototype patch above never undoes itself, so call this once a file's tests are done
---to stop a stray CreateAnimation from landing in a dead env's Animations.
function M.Teardown()
	currentEnv = nil
end

return M
