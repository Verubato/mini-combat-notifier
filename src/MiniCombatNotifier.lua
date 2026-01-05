local addonName = ...
local frame
local textFrame
local animation
---@type Db
local db
---@class Db
local dbDefaults = {
	Point = "CENTER",
	RelativeTo = "UIParent",
	RelativePoint = "CENTER",
	X = 0,
	Y = 0,

	FontPath = "Fonts\\FRIZQT__.TTF",
	FontSize = 16,
	FontFlags = "OUTLINE",

	EnteringCombatText = "<Entering Combat>",
	LeavingCombatText = "<Leaving Combat>",

	-- light red
	EnteringCombatTextColor = {
		R = 1,
		G = 0.1,
		B = 0.1,
		A = 1,
	},

	-- green
	LeavingCombatTextColor = {
		R = 0,
		G = 1,
		B = 0,
		A = 1,
	},

	FadeInDuration = 0.5,
	HoldDuration = 0.5,
	FadeOutDuration = 0.5,
}

local function CopyTable(src, dst)
	if type(dst) ~= "table" then
		dst = {}
	end

	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = CopyTable(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end

	return dst
end

local function OnCombatEvent(_, event)
	local text
	local color

	if event == "PLAYER_REGEN_DISABLED" then
		text = db.EnteringCombatText or dbDefaults.EnteringCombatText
		color = db.EnteringCombatTextColor or dbDefaults.EnteringCombatTextColor
	elseif event == "PLAYER_REGEN_ENABLED" then
		text = db.LeavingCombatText or dbDefaults.LeavingCombatText
		color = db.LeavingCombatTextColor or dbDefaults.LeavingCombatTextColor
	else
		return
	end

	textFrame:SetTextColor(color.R or 1, color.G or 1, color.B or 1, color.A or 1)
	textFrame:SetAlpha(0)
	textFrame:SetText(text)
	textFrame:Show()

	if animation:IsPlaying() then
		animation:Stop()
	end

	animation:Play()
end

local function Init()
	MiniCombatNotifierDB = MiniCombatNotifierDB or {}
	db = CopyTable(dbDefaults, MiniCombatNotifierDB)

	local combatFrame = CreateFrame("Frame")
	combatFrame:HookScript("OnEvent", OnCombatEvent)
	combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

	textFrame = UIParent:CreateFontString(nil, "ARTWORK")
	textFrame:SetFont(
		db.FontPath or dbDefaults.FontPath,
		db.FontSize or dbDefaults.FontSize,
		db.FontFlags or dbDefaults.FontFlags
	)

	local relativeTo = db.RelativeTo and _G[db.RelativeTo] or UIParent
	textFrame:SetPoint(
		db.Point or dbDefaults.Point,
		relativeTo,
		db.RelativePoint or dbDefaults.RelativePoint,
		db.X or dbDefaults.X,
		db.Y or dbDefaults.Y
	)
	textFrame:SetAlpha(0)
	textFrame:Hide()

	animation = textFrame:CreateAnimationGroup()

	local fadeIn = animation:CreateAnimation("Alpha")
	fadeIn:SetOrder(1)
	fadeIn:SetDuration(db.FadeInDuration or dbDefaults.FadeInDuration)
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetSmoothing("IN_OUT")

	local hold = animation:CreateAnimation("Alpha")
	hold:SetOrder(2)
	hold:SetDuration(db.HoldDuration or dbDefaults.HoldDuration)
	hold:SetFromAlpha(1)
	hold:SetToAlpha(1)

	local fadeOut = animation:CreateAnimation("Alpha")
	fadeOut:SetOrder(3)
	fadeOut:SetDuration(db.FadeOutDuration or dbDefaults.FadeOutDuration)
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(0)
	fadeOut:SetSmoothing("IN_OUT")

	animation:SetScript("OnFinished", function()
		textFrame:Hide()
	end)
end

local function OnAddonLoaded(_, _, name)
	if name ~= addonName then
		return
	end

	Init()

	frame:UnregisterEvent("ADDON_LOADED")

	frame:SetScript("OnEvent", OnCombatEvent)
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnAddonLoaded)
