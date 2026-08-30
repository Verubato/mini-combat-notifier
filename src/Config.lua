local addonName, addon = ...

local testModeActive = false
local testModeBg  -- background texture shown in test mode

-- Build panel

local function BuildPanel(panel)
	local mini = addon.Framework
	local db   = addon.Db

	local vSpace = mini.VerticalSpacing
	local hSpace = mini.HorizontalSpacing
	local xMid   = 316  -- x start for right-side control on shared rows
	local panelW = select(1, mini:SettingsSize()) - hSpace
	local y      = -vSpace

	local function Row(amount) y = y - amount; return y end

	local function Label(text)
		local lbl = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		lbl:SetText(text)
		return lbl
	end

	-- Title and description

	mini:PanelHeader({
		Parent = panel,
		Description = "Notifies you when entering and leaving combat.",
		Width = panelW,
		Test = {
			OnClick = function()
				testModeActive = not testModeActive
				addon.SetTestMode(testModeActive)

				if testModeBg then testModeBg:SetShown(testModeActive) end
			end,
		},
		Reset = {
			OnAccept = function()
				db = mini:ResetSavedVars(addon.DbDefaults)
				addon.Db = db
				addon.RefreshDisplay()
			end,
		},
	})
	Row(52)

	-- Notification Text
	-- Row: "Entering Combat:" [editbox]    "Leaving Combat:" [editbox]

	local divText = mini:Divider({ Parent = panel, Text = "Notification Text" })
	divText:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
	divText:SetWidth(panelW)
	Row(40)

	local enterRes = mini:EditBox({
		Parent = panel, Width = 160, LabelText = "",
		GetValue = function() return db.EnteringCombatText end,
		SetValue = function(v) db.EnteringCombatText = v end,
	})
	local enterLbl = Label("Entering Combat:")
	enterLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
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

	-- Font
	-- Row: "Entering Combat:" [swatch]    "Leaving Combat:" [swatch]
	-- Row: "Font:" [dropdown]    "Style:" [dropdown]
	-- Row: [Font Size slider]

	local divFont = mini:Divider({ Parent = panel, Text = "Font" })
	divFont:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
	divFont:SetWidth(panelW)
	Row(40)

	-- The stored A is alpha (1 = opaque) - it is handed straight to SetTextColor - so it maps
	-- onto the framework's alpha convention without conversion.
	local enterSwatch = mini:ColorSwatch({
		Parent = panel,
		Size = 24,
		Tooltip = "Click to change color",
		GetValue = function()
			local c = db.EnteringCombatTextColor
			return c.R, c.G, c.B, c.A
		end,
		SetValue = function(r, g, b, a)
			local c = db.EnteringCombatTextColor
			c.R, c.G, c.B, c.A = r, g, b, a
		end,
	})
	local enterColorLbl = Label("Entering Combat:")
	enterColorLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
	enterSwatch:SetPoint("LEFT", enterColorLbl, "RIGHT", 8, 0)

	local leaveSwatch = mini:ColorSwatch({
		Parent = panel,
		Size = 24,
		Tooltip = "Click to change color",
		GetValue = function()
			local c = db.LeavingCombatTextColor
			return c.R, c.G, c.B, c.A
		end,
		SetValue = function(r, g, b, a)
			local c = db.LeavingCombatTextColor
			c.R, c.G, c.B, c.A = r, g, b, a
		end,
	})
	local leaveColorLbl = Label("Leaving Combat:")
	leaveColorLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", xMid, y)
	leaveSwatch:SetPoint("LEFT", leaveColorLbl, "RIGHT", 8, 0)
	Row(44)

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
	fontLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
	local flagLbl = Label("Style:")
	flagLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", xMid, y)
	Row(22)

	local fontDD, fontModern = mini:Dropdown({
		Parent = panel, Items = fontValues, Width = 180,
		GetValue = function() return db.FontPath end,
		SetValue = function(v) db.FontPath = v; addon.RefreshDisplay() end,
		GetText  = function(v) return fontNames[v] or v end,
	})
	fontDD:SetPoint("TOPLEFT", panel, "TOPLEFT", (fontModern and 0 or -16), y)

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
	sizeRes.Slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
	Row(48)

	-- Position
	-- Row: hint text
	-- Row: X: [editbox]    Y: [editbox]

	local divPos = mini:Divider({ Parent = panel, Text = "Position" })
	divPos:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
	divPos:SetWidth(panelW)
	Row(40)

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
	hint:SetText("Click Test, then drag the text to reposition it.")
	hint:SetTextColor(0.7, 0.7, 0.7, 1)
	Row(28)

	local xLbl = Label("X:")
	xLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)

	local posXRes = mini:EditBox({
		Parent = panel, Width = 60, Numeric = true, AllowNegatives = true, LabelText = "",
		GetValue = function() return db.X end,
		SetValue = function(v) db.X = mini:ClampInt(v, -2000, 2000, db.X); addon.RefreshDisplay() end,
	})
	posXRes.EditBox:SetPoint("LEFT", xLbl, "RIGHT", 6, 0)

	local yLbl = Label("Y:")
	yLbl:SetPoint("LEFT", posXRes.EditBox, "RIGHT", hSpace, 0)

	local posYRes = mini:EditBox({
		Parent = panel, Width = 60, Numeric = true, AllowNegatives = true, LabelText = "",
		GetValue = function() return db.Y end,
		SetValue = function(v) db.Y = mini:ClampInt(v, -2000, 2000, db.Y); addon.RefreshDisplay() end,
	})
	posYRes.EditBox:SetPoint("LEFT", yLbl, "RIGHT", 6, 0)

	panel:HookScript("OnShow", function()
		RefreshFontList()
		if panel.MiniRefresh then panel:MiniRefresh() end
		if testModeBg then testModeBg:SetShown(testModeActive) end
	end)
end

function addon.InitConfig()
	local mini = addon.Framework

	-- A styled button clashes with the stock Blizzard art around it in the settings screen.
	mini:SetCustomStyling(true, { Button = false })

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
