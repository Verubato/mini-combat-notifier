local addonName, addon = ...

local sliderId    = 1
local dropDownId  = 1
local loaded      = false
local onLoadCallbacks = {}

---@class MiniFramework
local M = {
	VerticalSpacing   = 16,
	HorizontalSpacing = 20,
}
addon.Framework = M

if not PixelUtil then
	PixelUtil = {
		SetHeight = function(frame, h) frame:SetHeight(h) end,
		SetWidth  = function(frame, w) frame:SetWidth(w) end,
		SetPoint  = function(frame, ...) frame:SetPoint(...) end,
	}
end

local function AddControlForRefresh(panel, control)
	panel.MiniControls = panel.MiniControls or {}
	panel.MiniControls[#panel.MiniControls + 1] = control

	if panel.MiniRefresh then return end

	panel.MiniRefresh = function(panelSelf)
		for _, c in ipairs(panelSelf.MiniControls or {}) do
			if c.MiniRefresh then c:MiniRefresh() end
		end
	end
end

local function ConfigureNumericBox(box, allowNegative)
	if not allowNegative then
		box:SetNumeric(true)
		return
	end

	box:HookScript("OnTextChanged", function(boxSelf, userInput)
		if not userInput then return end
		local text = boxSelf:GetText()
		if text == "" or text == "-" or text:match("^%-?%d+$") then return end
		text = text:gsub("[^%d%-]", "")
		text = text:gsub("%-+", "-")
		if text:sub(1, 1) ~= "-" then
			text = text:gsub("%-", "")
		else
			text = "-" .. text:sub(2):gsub("%-", "")
		end
		boxSelf:SetText(text)
	end)
end

function M:CopyTable(src, dst)
	if type(dst) ~= "table" then dst = {} end
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = M:CopyTable(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

function M:GetSavedVars(defaults)
	local name = addonName .. "DB"
	local vars = _G[name] or {}
	_G[name] = vars
	if defaults then
		return M:CopyTable(defaults, vars)
	end
	return vars
end

local function NilKeys(target)
	for k, v in pairs(target) do
		if type(v) == "table" then
			NilKeys(v)
		else
			target[k] = nil
		end
	end
end

function M:ResetSavedVars(defaults)
	local name = addonName .. "DB"
	local vars = _G[name] or {}
	NilKeys(vars)
	if defaults then
		return M:CopyTable(defaults, vars)
	end
	return vars
end

function M:ClampInt(v, minV, maxV, fallback)
	v = tonumber(v)
	if not v then return fallback end
	return math.min(math.max(math.floor(v + 0.5), minV), maxV)
end

function M:ClampFloat(v, minV, maxV, fallback)
	v = tonumber(v)
	if not v then return fallback end
	return math.min(math.max(v, minV), maxV)
end

function M:SettingsSize()
	local c = SettingsPanel and SettingsPanel.Container
	if c then return c:GetWidth(), c:GetHeight() end
	if InterfaceOptionsFramePanelContainer then
		return InterfaceOptionsFramePanelContainer:GetWidth(), InterfaceOptionsFramePanelContainer:GetHeight()
	end
	return 626, 508
end

function M:AddCategory(panel)
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		Settings.RegisterAddOnCategory(cat)
		return cat
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
		return panel
	end
	return nil
end

function M:OpenSettings(category, panel)
	if Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(category:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end

function M:RegisterSlashCommand(category, panel, commands)
	local upper = string.upper(addonName)
	SlashCmdList[upper] = function()
		M:OpenSettings(category, panel)
	end
	if commands then
		for i, cmd in ipairs(commands) do
			_G["SLASH_" .. upper .. i] = cmd
		end
	end
end

function M:Divider(options)
	local container = CreateFrame("Frame", nil, options.Parent)
	container:SetHeight(26)

	local leftLine = container:CreateTexture(nil, "ARTWORK")
	leftLine:SetColorTexture(1, 1, 1, 0.15)
	PixelUtil.SetHeight(leftLine, 1)

	local rightLine = container:CreateTexture(nil, "ARTWORK")
	rightLine:SetColorTexture(1, 1, 1, 0.15)
	PixelUtil.SetHeight(rightLine, 1)

	local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	label:SetText(options.Text or "")
	label:SetTextColor(1, 1, 1, 1)
	label:SetPoint("CENTER", container, "CENTER")

	PixelUtil.SetPoint(leftLine, "LEFT", container, "LEFT", 0, 0)
	PixelUtil.SetPoint(leftLine, "RIGHT", label, "LEFT", -8, 0)
	PixelUtil.SetPoint(rightLine, "LEFT", label, "RIGHT", 8, 0)
	PixelUtil.SetPoint(rightLine, "RIGHT", container, "RIGHT", 0, 0)

	return container
end

function M:EditBox(options)
	local label = options.Parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetText(options.LabelText or "")

	local box = CreateFrame("EditBox", nil, options.Parent, "InputBoxTemplate")
	box:SetSize(options.Width or 200, options.Height or 20)
	box:SetAutoFocus(false)

	if options.Numeric then
		ConfigureNumericBox(box, options.AllowNegatives)
	end

	local function Commit()
		options.SetValue(box:GetText())
		box:SetText(tostring(options.GetValue() or ""))
		box:SetCursorPosition(0)
	end

	box:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Commit() end)
	box:SetScript("OnEditFocusLost", Commit)

	function box.MiniRefresh(self)
		self:SetText(tostring(options.GetValue() or ""))
		self:SetCursorPosition(0)
	end

	box:MiniRefresh()
	AddControlForRefresh(options.Parent, box)

	return { EditBox = box, Label = label }
end

function M:Dropdown(options)
	if not options or not options.Parent or not options.GetValue or not options.SetValue or not options.Items then
		error("Dropdown - invalid options.")
	end

	-- Modern WoW (Dragonflight+)
	if MenuUtil and MenuUtil.CreateRadioMenu then
		local dd = CreateFrame("DropdownButton", nil, options.Parent, "WowStyle1DropdownTemplate")
		if options.Width then dd:SetWidth(options.Width) end

		dd:SetupMenu(function(_, rootDescription)
			for _, value in ipairs(options.Items) do
				local text = options.GetText and options.GetText(value) or tostring(value)
				rootDescription:CreateRadio(text, function(x)
					return x == options.GetValue()
				end, function()
					options.SetValue(value)
				end, value)
			end
		end)

		function dd.MiniRefresh(ddSelf)
			ddSelf:Update()
			local value = options.GetValue()
			local text = options.GetText and options.GetText(value) or tostring(value)
			ddSelf:SetText(text)
		end

		AddControlForRefresh(options.Parent, dd)
		dd:MiniRefresh()
		return dd, true
	end

	-- Legacy WoW
	if UIDropDownMenu_Initialize then
		local dd = CreateFrame("Frame", addonName .. "Dropdown" .. dropDownId, options.Parent, "UIDropDownMenuTemplate")
		dropDownId = dropDownId + 1

		if options.Width then UIDropDownMenu_SetWidth(dd, options.Width) end

		UIDropDownMenu_Initialize(dd, function()
			for _, value in ipairs(options.Items) do
				local info = {}
				info.text    = options.GetText and options.GetText(value) or tostring(value)
				info.value   = value
				info.checked = function() return options.GetValue() == value end
				info.func    = function()
					options.SetValue(value)
					local text = options.GetText and options.GetText(value) or tostring(value)
					UIDropDownMenu_SetText(dd, text)
					CloseDropDownMenus()
				end
				UIDropDownMenu_AddButton(info, 1)
			end
		end)

		function dd.MiniRefresh()
			local value = options.GetValue()
			local text = options.GetText and options.GetText(value) or tostring(value)
			UIDropDownMenu_SetText(dd, text)
		end

		AddControlForRefresh(options.Parent, dd)
		dd:MiniRefresh()
		return dd, false
	end

	error("Dropdown - no implementation available.")
end

function M:Slider(options)
	local slider = CreateFrame("Slider", addonName .. "Slider" .. sliderId, options.Parent, "OptionsSliderTemplate")
	sliderId = sliderId + 1

	local label = slider:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 8)
	label:SetText(options.LabelText or "")

	slider:SetOrientation("HORIZONTAL")
	slider:SetMinMaxValues(options.Min, options.Max)
	slider:SetValueStep(options.Step)
	slider:SetObeyStepOnDrag(true)
	slider:SetHeight(20)
	slider:SetWidth(options.Width or 200)

	local low  = _G[slider:GetName() .. "Low"]
	local high = _G[slider:GetName() .. "High"]
	if low and high then low:SetText(options.Min); high:SetText(options.Max) end

	local text = _G[slider:GetName() .. "Text"]
	if text then text:Hide() end

	local hasFloat = math.floor(options.Step) ~= options.Step
	local box = CreateFrame("EditBox", nil, slider, "InputBoxTemplate")
	if not hasFloat then ConfigureNumericBox(box, options.Min < 0) end

	box:SetPoint("CENTER", slider, "CENTER", 0, 30)
	box:SetFontObject("GameFontWhite")
	box:SetSize(50, 20)
	box:SetAutoFocus(false)
	box:SetJustifyH("CENTER")

	-- set initial value after controls are ready
	slider:SetValue(options.GetValue())
	box:SetText(tostring(options.GetValue()))
	box:SetCursorPosition(0)

	slider:SetScript("OnValueChanged", function(_, v, userInput)
		if userInput ~= nil and not userInput then return end
		box:SetText(tostring(v))
		options.SetValue(v)
	end)

	box:SetScript("OnTextChanged", function(_, userInput)
		if not userInput then return end
		local v = tonumber(box:GetText())
		if not v then return end
		slider:SetValue(v)
		options.SetValue(v)
	end)

	function box.MiniRefresh(self)
		self:SetText(tostring(options.GetValue()))
		self:SetCursorPosition(0)
	end

	function slider.MiniRefresh(self)
		self:SetValue(options.GetValue())
	end

	AddControlForRefresh(options.Parent, slider)
	AddControlForRefresh(options.Parent, box)

	return { Slider = slider, EditBox = box, Label = label }
end

function M:WaitForAddonLoad(callback)
	if not callback then
		error("WaitForAddonLoad - callback must not be nil.")
	end
	onLoadCallbacks[#onLoadCallbacks + 1] = callback
	if loaded then
		callback()
	end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
	if name ~= addonName then return end
	loaded = true
	loader:UnregisterEvent("ADDON_LOADED")
	for _, cb in ipairs(onLoadCallbacks) do
		cb()
	end
end)
