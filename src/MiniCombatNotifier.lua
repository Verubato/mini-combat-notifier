local addonName, addon = ...
local container  -- Frame parent for textFrame (enables dragging)
local textFrame  -- FontString
local animation

---@type Db
local db
---@class Db
addon.DbDefaults = {
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

	EnteringCombatTextColor = { R = 1,   G = 0.1, B = 0.1, A = 1 },
	LeavingCombatTextColor  = { R = 0,   G = 1,   B = 0,   A = 1 },

	FadeInDuration  = 0.5,
	HoldDuration    = 0.5,
	FadeOutDuration = 0.5,
}

local function ApplyFont()
	textFrame:SetFont(db.FontPath, db.FontSize, db.FontFlags)
end

local function ApplyPosition()
	local relativeTo = db.RelativeTo and _G[db.RelativeTo] or UIParent
	container:ClearAllPoints()
	container:SetPoint(db.Point, relativeTo, db.RelativePoint, db.X, db.Y)
end

local function OnCombatEvent(_, event)
	if animation:IsPlaying() then animation:Stop() end

	local text, color
	if event == "PLAYER_REGEN_DISABLED" then
		text  = db.EnteringCombatText
		color = db.EnteringCombatTextColor
	elseif event == "PLAYER_REGEN_ENABLED" then
		text  = db.LeavingCombatText
		color = db.LeavingCombatTextColor
	else
		return
	end

	textFrame:SetTextColor(color.R, color.G, color.B, color.A)
	textFrame:SetAlpha(0)
	textFrame:SetText(text)
	textFrame:Show()
	animation:Play()
end

local function Init()
	db = addon.Framework:GetSavedVars(addon.DbDefaults)
	addon.Db = db

	container = CreateFrame("Frame", "MiniCombatNotifierContainer", UIParent)
	container:SetSize(500, 60)
	container:SetFrameStrata("MEDIUM")

	local relativeTo = db.RelativeTo and _G[db.RelativeTo] or UIParent
	container:SetPoint(db.Point, relativeTo, db.RelativePoint, db.X, db.Y)

	textFrame = container:CreateFontString(nil, "ARTWORK")
	textFrame:SetAllPoints(container)
	textFrame:SetJustifyH("CENTER")
	textFrame:SetJustifyV("MIDDLE")
	ApplyFont()
	textFrame:SetAlpha(0)
	textFrame:Hide()

	animation = textFrame:CreateAnimationGroup()

	local fadeIn = animation:CreateAnimation("Alpha")
	fadeIn:SetOrder(1)
	fadeIn:SetDuration(db.FadeInDuration)
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetSmoothing("IN_OUT")

	local hold = animation:CreateAnimation("Alpha")
	hold:SetOrder(2)
	hold:SetDuration(db.HoldDuration)
	hold:SetFromAlpha(1)
	hold:SetToAlpha(1)

	local fadeOut = animation:CreateAnimation("Alpha")
	fadeOut:SetOrder(3)
	fadeOut:SetDuration(db.FadeOutDuration)
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(0)
	fadeOut:SetSmoothing("IN_OUT")

	animation:SetScript("OnFinished", function()
		textFrame:Hide()
	end)
end

-- called by Config.lua after settings change
function addon.RefreshDisplay()
	ApplyFont()
	ApplyPosition()
end

function addon.SetTestMode(enabled)
	if enabled then
		if animation:IsPlaying() then animation:Stop() end
		textFrame:Show()
		textFrame:SetAlpha(1)
		textFrame:SetText(db.EnteringCombatText)
		local c = db.EnteringCombatTextColor
		textFrame:SetTextColor(c.R, c.G, c.B, c.A)

		container:SetMovable(true)
		container:EnableMouse(true)
		container:RegisterForDrag("LeftButton")
		container:SetScript("OnDragStart", container.StartMoving)
		container:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local point, _, relativePoint, x, y = self:GetPoint()
			db.Point = point
			db.RelativePoint = relativePoint
			db.X = math.floor(x + 0.5)
			db.Y = math.floor(y + 0.5)
		end)
	else
		container:EnableMouse(false)
		container:SetScript("OnDragStart", nil)
		container:SetScript("OnDragStop", nil)
		textFrame:SetAlpha(0)
		textFrame:Hide()
		ApplyPosition()
	end
end

addon.Framework:WaitForAddonLoad(function()
	Init()
	addon.InitConfig()
	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", OnCombatEvent)
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
end)
