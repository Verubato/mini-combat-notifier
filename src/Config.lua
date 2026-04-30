local addonName, addon = ...

local testModeActive = false
local testModeBg  -- background texture shown in test mode
local testModeBtn -- button ref so we can update its label

StaticPopupDialogs["MINICOMBATNOTIFIER_CONFIRM_RESET"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, data)
		if data and data.OnYes then data.OnYes() end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- Color picker

local function OpenColorPicker(r, g, b, a, onUpdate, onCancel)
	if ColorPickerFrame.SetupColorPickerAndShow then
		local prev = { r = r, g = g, b = b, a = a }
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r, g = g, b = b,
			opacity = 1 - a,
			hasOpacity = true,
			swatchFunc = function()
				local r2, g2, b2 = ColorPickerFrame:GetColorRGB()
				local a2 = 1 - ColorPickerFrame:GetColorAlpha()
				onUpdate(r2, g2, b2, a2)
			end,
			opacityFunc = function()
				local r2, g2, b2 = ColorPickerFrame:GetColorRGB()
				local a2 = 1 - ColorPickerFrame:GetColorAlpha()
				onUpdate(r2, g2, b2, a2)
			end,
			cancelFunc = function()
				if onCancel then onCancel(prev.r, prev.g, prev.b, prev.a) end
			end,
		})
	else
		-- Classic API
		local prevR, prevG, prevB, prevA = r, g, b, a
		ColorPickerFrame.func = function()
			local r2, g2, b2 = ColorPickerFrame:GetColorRGB()
			onUpdate(r2, g2, b2, prevA)
		end
		ColorPickerFrame.hasOpacity = true
		ColorPickerFrame.opacity = 1 - a
		ColorPickerFrame.opacityFunc = function()
			onUpdate(prevR, prevG, prevB, 1 - ColorPickerFrame.opacity)
		end
		ColorPickerFrame.cancelFunc = function()
			if onCancel then onCancel(prevR, prevG, prevB, prevA) end
		end
		ColorPickerFrame:SetColorRGB(r, g, b)
		ShowUIPanel(ColorPickerFrame)
	end
end

-- Color swatch button

local function CreateColorSwatch(parent, getColor, setColor, onChange)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(24, 24)

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetPoint("TOPLEFT", 1, -1)
	bg:SetPoint("BOTTOMRIGHT", -1, 1)

	-- thin border using 4 textures
	local function MakeBorder(a1, o1x, o1y, a2, o2x, o2y, w, h)
		local t = btn:CreateTexture(nil, "BORDER")
		t:SetColorTexture(0.4, 0.4, 0.4, 1)
		t:SetPoint(a1, btn, a1, o1x, o1y)
		t:SetPoint(a2, btn, a2, o2x, o2y)
		if w then t:SetWidth(w) end
		if h then t:SetHeight(h) end
		return t
	end
	MakeBorder("TOPLEFT",     0,  0, "TOPRIGHT",    0,  0, nil, 1)
	MakeBorder("BOTTOMLEFT",  0,  0, "BOTTOMRIGHT", 0,  0, nil, 1)
	MakeBorder("TOPLEFT",     0,  0, "BOTTOMLEFT",  0,  0, 1, nil)
	MakeBorder("TOPRIGHT",    0,  0, "BOTTOMRIGHT", 0,  0, 1, nil)

	local function Refresh()
		local c = getColor()
		bg:SetColorTexture(c.R, c.G, c.B, 1)
	end

	btn:SetScript("OnClick", function()
		local c = getColor()
		OpenColorPicker(c.R, c.G, c.B, c.A,
			function(r, g, b, a)
				setColor(r, g, b, a)
				Refresh()
				if onChange then onChange() end
			end,
			function(r, g, b, a)
				setColor(r, g, b, a)
				Refresh()
				if onChange then onChange() end
			end
		)
	end)

	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Click to change color", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	Refresh()
	btn.MiniRefresh = Refresh
	return btn
end

-- Build panel

local function BuildPanel(panel)
	local mini = addon.Framework
	local db   = addon.Db

	local vSpace = mini.VerticalSpacing
	local hSpace = mini.HorizontalSpacing
	local xPad   = hSpace
	local xMid   = 316  -- x start for right-side control on shared rows
	local panelW = select(1, mini:SettingsSize()) - xPad * 2
	local y      = -vSpace

	local function Row(amount) y = y - amount; return y end

	local function Label(text)
		local lbl = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		lbl:SetText(text)
		return lbl
	end

	-- Title and description

	local version = C_AddOns and C_AddOns.GetAddOnMetadata(addonName, "Version") or GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", xPad, y)
	title:SetText(string.format("%s - %s", addonName, version or ""))

	local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	subtitle:SetText("Notifies you when entering and leaving combat.")
	Row(52)

	-- Notification Text
	-- Row: "Entering Combat:" [editbox]    "Leaving Combat:" [editbox]

	local divText = mini:Divider({ Parent = panel, Text = "Notification Text" })
	divText:SetPoint("TOPLEFT", panel, "TOPLEFT", xPad, y)
	divText:SetWidth(panelW)
	Row(40)

	local enterRes = mini:EditBox({
		Parent = panel, Width = 160, LabelText = "",
		GetValue = function() return db.EnteringCombatText end,
		SetValue = function(v) db.EnteringCombatText = v end,
	})
	local enterLbl = Label("Entering Combat:")
	enterLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", xPad, y)
	enterRes.EditBox:SetPoint("LEFT", enterLbl, "RIGHT", 8, 0)

	local leaveRes = mini:EditBox({
		Parent = panel, Width = 160, LabelText = "",
		GetValue = function() return db.LeavingCombatText end,
		SetValue = function(v) db.LeavingCombatText = v end,
	})
	local leaveLbl = Label("Leaving Combat:")
	leaveLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", xMid, y)
	leaveRes.EditBox:SetPoint("LEFT", leaveLbl, "RIGHT", 8, 0)
	Row(44)

	-- Colors
	-- Row: "Entering Combat:" [swatch]    "Leaving Combat:" [swatch]

	local divColor = mini:Divider({ Parent = panel, Text = "Colors" })
	divColor:SetPoint("TOPLEFT", panel, "TOPLEFT", xPad, y)
	divColor:SetWidth(panelW)
	Row(40)

	local enterSwatch = CreateColorSwatch(panel,
		function() return db.EnteringCombatTextColor end,
		function(r, g, b, a) local c = db.EnteringCombatTextColor; c.R, c.G, c.B, c.A = r, g, b, a end
	)
	local enterColorLbl = Label("Entering Combat:")
	enterColorLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", xPad, y)
	enterSwatch:SetPoint("LEFT", enterColorLbl, "RIGHT", 8, 0)

	local leaveSwatch = CreateColorSwatch(panel,
		function() return db.LeavingCombatTextColor end,
		function(r, g, b, a) local c = db.LeavingCombatTextColor; c.R, c.G, c.B, c.A = r, g, b, a end
	)
	local leaveColorLbl = Label("Leaving Combat:")
	leaveColorLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", xMid, y)
	leaveSwatch:SetPoint("LEFT", leaveColorLbl, "RIGHT", 8, 0)
	Row(44)

	-- Font
	-- Row: "Font:" [dropdown]    "Style:" [dropdown]
	-- Row: [Font Size slider]

	local divFont = mini:Divider({ Parent = panel, Text = "Font" })
	divFont:SetPoint("TOPLEFT", panel, "TOPLEFT", xPad, y)
	divFont:SetWidth(panelW)
	Row(40)

	local fontValues = {}
	local fontNames  = {}

	local function RefreshFontList()
		wipe(fontValues)
		wipe(fontNames)
		local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
		if LSM then
			for _, name in ipairs(LSM:List("font")) do
				local file = LSM:Fetch("font", name)
				if file then
					fontValues[#fontValues + 1] = file
					fontNames[file] = name
				end
			end
		else
			local fallback = {
				{ "Fonts\\FRIZQT__.TTF", "Friz Quadrata" },
				{ "Fonts\\ARIALN.TTF",   "Arial Narrow"  },
				{ "Fonts\\MORPHEUS.TTF", "Morpheus"       },
				{ "Fonts\\SKURRI.TTF",   "Skurri"         },
				{ "Fonts\\2002.ttf",     "2002"           },
			}
			for _, entry in ipairs(fallback) do
				fontValues[#fontValues + 1] = entry[1]
				fontNames[entry[1]] = entry[2]
			end
		end
	end

	RefreshFontList()
	local flagValues = { "OUTLINE", "THICKOUTLINE", "MONOCHROME", "OUTLINE, MONOCHROME", "" }
	local flagNames = {
		["OUTLINE"]             = "Outline",
		["THICKOUTLINE"]        = "Thick Outline",
		["MONOCHROME"]          = "Monochrome",
		["OUTLINE, MONOCHROME"] = "Outline + Mono",
		[""]                    = "None",
	}

	local fontLbl = Label("Font:")
	fontLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", xPad, y)
	local flagLbl = Label("Style:")
	flagLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", xMid, y)
	Row(22)

	local fontDD, fontModern = mini:Dropdown({
		Parent = panel, Items = fontValues, Width = 180,
		GetValue = function() return db.FontPath end,
		SetValue = function(v) db.FontPath = v; addon.RefreshDisplay() end,
		GetText  = function(v) return fontNames[v] or v end,
	})
	fontDD:SetPoint("TOPLEFT", panel, "TOPLEFT", xPad + (fontModern and 0 or -16), y)

	local flagDD, flagModern = mini:Dropdown({
		Parent = panel, Items = flagValues, Width = 180,
		GetValue = function() return db.FontFlags end,
		SetValue = function(v) db.FontFlags = v; addon.RefreshDisplay() end,
		GetText  = function(v) return flagNames[v] or v end,
	})
	flagDD:SetPoint("TOPLEFT", panel, "TOPLEFT", xMid + (flagModern and 0 or -16), y)
	-- Slider value box floats 20 px above slider top; needs ~55 px clearance from dropdown bottom.
	Row(74)

	local sizeRes = mini:Slider({
		Parent = panel, LabelText = "Font Size",
		Min = 8, Max = 48, Step = 1, Width = panelW - 60,
		GetValue = function() return db.FontSize end,
		SetValue = function(v) db.FontSize = mini:ClampInt(v, 8, 48, db.FontSize); addon.RefreshDisplay() end,
	})
	sizeRes.Slider:SetPoint("TOPLEFT", panel, "TOPLEFT", xPad, y)
	Row(48)

	-- Position
	-- Row: hint text
	-- Row: [Test Mode button]    X: [editbox]    Y: [editbox]

	local divPos = mini:Divider({ Parent = panel, Text = "Position" })
	divPos:SetPoint("TOPLEFT", panel, "TOPLEFT", xPad, y)
	divPos:SetWidth(panelW)
	Row(40)

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	hint:SetPoint("TOPLEFT", panel, "TOPLEFT", xPad, y)
	hint:SetText("Enable test mode, then drag the text to reposition it.")
	hint:SetTextColor(0.7, 0.7, 0.7, 1)
	Row(28)

	testModeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	testModeBtn:SetSize(160, 24)
	testModeBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", xPad, y)
	testModeBtn:SetText("Enable Test Mode")
	testModeBtn:SetScript("OnClick", function()
		testModeActive = not testModeActive
		addon.SetTestMode(testModeActive)
		testModeBtn:SetText(testModeActive and "Disable Test Mode" or "Enable Test Mode")
		if testModeBg then testModeBg:SetShown(testModeActive) end
	end)

	local posXRes = mini:EditBox({
		Parent = panel, Width = 60, Numeric = true, AllowNegatives = true, LabelText = "",
		GetValue = function() return db.X end,
		SetValue = function(v) db.X = mini:ClampInt(v, -2000, 2000, db.X); addon.RefreshDisplay() end,
	})
	local xLbl = Label("X:")
	xLbl:SetPoint("LEFT", testModeBtn, "RIGHT", hSpace, 0)
	posXRes.EditBox:SetPoint("LEFT", xLbl, "RIGHT", 6, 0)

	local posYRes = mini:EditBox({
		Parent = panel, Width = 60, Numeric = true, AllowNegatives = true, LabelText = "",
		GetValue = function() return db.Y end,
		SetValue = function(v) db.Y = mini:ClampInt(v, -2000, 2000, db.Y); addon.RefreshDisplay() end,
	})
	local yLbl = Label("Y:")
	yLbl:SetPoint("LEFT", posXRes.EditBox, "RIGHT", hSpace, 0)
	posYRes.EditBox:SetPoint("LEFT", yLbl, "RIGHT", 6, 0)

	-- Reset to defaults button (top-right corner)
	local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	resetBtn:SetSize(120, 24)
	resetBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -xPad, -vSpace)
	resetBtn:SetText("Reset to Defaults")
	resetBtn:SetScript("OnClick", function()
		StaticPopup_Show("MINICOMBATNOTIFIER_CONFIRM_RESET", "Reset all settings to default?", nil, {
			OnYes = function()
				db = mini:ResetSavedVars(addon.DbDefaults)
				addon.Db = db
				panel:MiniRefresh()
				addon.RefreshDisplay()
			end,
		})
	end)

	-- Register swatches for panel-wide refresh (dropdowns auto-register via AddControlForRefresh)
	panel.MiniControls = panel.MiniControls or {}
	panel.MiniControls[#panel.MiniControls + 1] = enterSwatch
	panel.MiniControls[#panel.MiniControls + 1] = leaveSwatch

	panel:HookScript("OnShow", function()
		RefreshFontList()
		if panel.MiniRefresh then panel:MiniRefresh() end
		if testModeBg then testModeBg:SetShown(testModeActive) end
		if testModeBtn then
			testModeBtn:SetText(testModeActive and "Disable Test Mode" or "Enable Test Mode")
		end
	end)
end

function addon.InitConfig()
	local mini = addon.Framework

	local container = _G["MiniCombatNotifierContainer"]
	if container then
		testModeBg = container:CreateTexture(nil, "BACKGROUND")
		testModeBg:SetAllPoints(container)
		testModeBg:SetColorTexture(1, 1, 1, 0.07)
		testModeBg:Hide()
	end

	local panel = CreateFrame("Frame")
	panel.name  = addonName

	BuildPanel(panel)

	local category = mini:AddCategory(panel)
	mini:RegisterSlashCommand(category, panel, { "/mcn", "/minicn", "/minicombatnotifier" })
end
