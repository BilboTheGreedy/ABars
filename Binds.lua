local _, ns = ...
local UI = ns.UI
local C = UI.colors
local Button = ns.Button

local owner
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true }

function ns.Command(b)
	return b.command or ("CLICK " .. b.buttonName .. ":LeftButton")
end

local function keys(b)
	if not GetBindingKey then return {} end
	return { GetBindingKey(ns.Command(b)) }
end
ns.KeysFor = keys

function ns.KeyFor(b)
	return keys(b)[1]
end

function ns.ApplyBindings()
	return ns.Safe("binds", function()
		if not owner then owner = CreateFrame("Frame", "ABarsBindOwner", UIParent) end
		if ClearOverrideBindings then ClearOverrideBindings(owner) end
		for _, b in ipairs(ns.buttons) do
			if b.active and b.command and SetOverrideBindingClick then
				for _, key in ipairs(keys(b)) do
					SetOverrideBindingClick(owner, false, key, b.buttonName, "Keybind")
				end
			end
			Button.Hotkey(b)
		end
	end)
end

local function save()
	if SaveBindings and GetCurrentBindingSet then pcall(SaveBindings, GetCurrentBindingSet()) end
end

function ns.Bind(b, key)
	if ns.InCombat() or not b or not key or not SetBinding then return false end
	SetBinding(key, ns.Command(b))
	save()
	ns.ApplyBindings()
	return true
end

function ns.Unbind(b)
	if ns.InCombat() or not b or not SetBinding then return false end
	for _, key in ipairs(keys(b)) do SetBinding(key, nil) end
	save()
	ns.ApplyBindings()
	return true
end

local capture

local function combo(key)
	local out = ""
	if IsAltKeyDown and IsAltKeyDown() then out = out .. "ALT-" end
	if IsControlKeyDown and IsControlKeyDown() then out = out .. "CTRL-" end
	if IsShiftKeyDown and IsShiftKeyDown() then out = out .. "SHIFT-" end
	return out .. key
end

local function status()
	if not capture then return end
	local b = ns.hover
	if b then
		local list = keys(b)
		capture.text:SetText(b.bar.def.title .. " button " .. b.id .. ": " .. (#list > 0 and table.concat(list, ", ") or "not bound"))
	else
		capture.text:SetText("Hover a button and press a key. Backspace clears, Escape ends.")
	end
end

local function onKey(_, key)
	if type(key) ~= "string" or MODIFIERS[key] then return end
	if key == "ESCAPE" then
		ns.SetBindMode(false)
		return
	end
	local b = ns.hover
	if not b then return end
	if key == "BACKSPACE" or key == "DELETE" then
		ns.Unbind(b)
	else
		ns.Bind(b, combo(key))
	end
	status()
end

local function build()
	capture = CreateFrame("Frame", "ABarsBindFrame", UIParent)
	capture:SetSize(520, 44)
	capture:SetPoint("TOP", UIParent, "TOP", 0, -120)
	capture:SetFrameStrata("DIALOG")
	UI.Fill(capture, C.bg)
	UI.Border(capture, C.accent)
	capture.title = UI.Text(capture, "GameFontNormal", "CENTER", C.accent)
	capture.title:SetPoint("TOP", 0, -6)
	capture.title:SetText("Keybind mode")
	capture.text = UI.Text(capture, "GameFontHighlightSmall", "CENTER")
	capture.text:SetPoint("BOTTOM", 0, 8)
	capture:EnableKeyboard(true)
	if capture.SetPropagateKeyboardInput then capture:SetPropagateKeyboardInput(false) end
	capture:SetScript("OnKeyDown", onKey)
	capture:EnableMouseWheel(true)
	capture:Hide()
end

function ns.SetBindMode(on)
	if on and ns.InCombat() then
		ns.Print("keybind mode is not available in combat")
		return false
	end
	if on and not capture then build() end
	ns.bindMode = on and true or false
	if capture then capture:SetShown(ns.bindMode) end
	for _, b in ipairs(ns.buttons) do
		if b.active then Button.Alpha(b) end
	end
	status()
	return true
end

function ns.ToggleBindMode()
	return ns.SetBindMode(not ns.bindMode)
end

ns:Listen("HOVER", function()
	if ns.bindMode then status() end
end)

ns:Listen("COMBAT", function(on)
	if on and ns.bindMode then ns.SetBindMode(false) end
end)

ns:Listen("START", function()
	ns:On("UPDATE_BINDINGS", function() ns.ApplyBindings() end)
end)
