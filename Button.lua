local _, ns = ...
local UI = ns.UI
local C = UI.colors

local Button = {}
ns.Button = Button
ns.buttons = {}

local AB = C_ActionBar or {}

local function api(name)
	return _G[name] or AB[name]
end

local function call(name, ...)
	local fn = api(name)
	if not fn then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	return nil
end

local function plain(v)
	if ns.IsSecret(v) then return nil, true end
	if v == nil then return nil, true end
	return v, false
end

local function present(v)
	if ns.IsSecret(v) then return true end
	return v ~= nil
end
ns.Present = present

local function cooldown(slot)
	if GetActionCooldown then
		local ok, start, duration, enable, rate = pcall(GetActionCooldown, slot)
		if ok then return start, duration, enable, rate end
		return nil
	end
	if AB.GetActionCooldown then
		local ok, info = pcall(AB.GetActionCooldown, slot)
		if ok and type(info) == "table" then
			if not ns.IsSecret(info.isActive) and info.isActive == false then return nil end
			return info.startTime, info.duration, info.isEnabled, info.modRate
		end
	end
	return nil
end

local function setCooldown(cd, start, duration, rate)
	if not present(start) or not present(duration) then
		if cd.Clear then cd:Clear() end
		return
	end
	if not present(rate) or not pcall(cd.SetCooldown, cd, start, duration, rate) then
		pcall(cd.SetCooldown, cd, start, duration)
	end
end

local function actionCooldown(b)
	local cd = b.cd
	if AB.GetActionCooldownDuration and cd.SetCooldownFromDurationObject then
		local ok, d = pcall(AB.GetActionCooldownDuration, b.slot)
		if ok and present(d) and pcall(cd.SetCooldownFromDurationObject, cd, d) then return end
	end
	setCooldown(cd, cooldown(b.slot))
end

local CURSOR = { spell = true, item = true, macro = true, petaction = true, mount = true, companion = true, flyout = true, equipmentset = true, toy = true, battlepet = true }

local function cursorHolds()
	if not GetCursorInfo then return false end
	local kind = plain((GetCursorInfo()))
	return kind ~= nil and CURSOR[kind] == true
end

local function pickupKey()
	if IsModifiedClick then
		local ok, down = pcall(IsModifiedClick, "PICKUPACTION")
		if ok then return down and true or false end
	end
	return IsShiftKeyDown and IsShiftKeyDown() and true or false
end

local REPLACE = {
	{ "SHIFT%-", "s" }, { "CTRL%-", "c" }, { "ALT%-", "a" }, { "META%-", "m" },
	{ "MOUSEWHEELUP", "WU" }, { "MOUSEWHEELDOWN", "WD" }, { "BUTTON", "M" }, { "NUMPAD", "N" },
	{ "PAGEUP", "PU" }, { "PAGEDOWN", "PD" }, { "SPACE", "Sp" }, { "INSERT", "Ins" }, { "DELETE", "Del" },
	{ "HOME", "Hm" }, { "END", "End" }, { "BACKSPACE", "Bs" }, { "CAPSLOCK", "Cl" }, { "ESCAPE", "Esc" },
	{ "TAB", "Tab" }, { "ENTER", "Ent" }, { "MINUS", "-" }, { "PLUS", "+" }, { "MULTIPLY", "*" }, { "DIVIDE", "/" },
}

function ns.ShortKey(key)
	if type(key) ~= "string" then return "" end
	local k = key:upper()
	for _, r in ipairs(REPLACE) do k = k:gsub(r[1], r[2]) end
	return k
end

local function petInfo(id)
	if not GetPetActionInfo then return nil end
	local ok, name, texture, isToken, isActive, autoAllowed, autoEnabled = pcall(GetPetActionInfo, id)
	if not ok then return nil end
	if plain(isToken) and not ns.IsSecret(texture) and type(texture) == "string" then texture = _G[texture] end
	return name, texture, isActive, autoAllowed, autoEnabled
end

local function stanceInfo(id)
	if not GetShapeshiftFormInfo then return nil end
	local ok, icon, active, castable, spell = pcall(GetShapeshiftFormInfo, id)
	if not ok then return nil end
	return icon, active, castable, spell
end
ns.StanceInfo = stanceInfo

local function showTooltip(b)
	if not GameTooltip then return end
	if GameTooltip_SetDefaultAnchor then
		GameTooltip_SetDefaultAnchor(GameTooltip, b)
	else
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	end
	local shown
	if b.kind == "action" then
		if b.has then shown = pcall(GameTooltip.SetAction, GameTooltip, b.slot) end
	elseif b.kind == "pet" then
		if b.has then shown = pcall(GameTooltip.SetPetAction, GameTooltip, b.id) end
	elseif b.has then
		shown = pcall(GameTooltip.SetShapeshift, GameTooltip, b.id)
	end
	if shown then GameTooltip:Show() else GameTooltip:Hide() end
end

local function now()
	return GetTime and GetTime() or 0
end

local function dropActive(b)
	return b.dropped ~= nil and now() - b.dropped < 3
end

local function release(b)
	if not b.held then return end
	ns.Safe("held:" .. b.buttonName, function()
		b.held = nil
		b:SetAttribute("useOnKeyDown", nil)
	end)
end

function Button.Create(name, parent, kind, id)
	local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
	b.kind = kind
	b.id = id
	b.buttonName = name
	b:RegisterForClicks("AnyDown", "AnyUp")
	b.bg = UI.Fill(b, { 0.05, 0.05, 0.065, 0.85 })
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints(b.icon)
	if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(false) end
	if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end
	b.over = CreateFrame("Frame", nil, b)
	b.over:SetAllPoints(b)
	b.over:SetFrameLevel((b:GetFrameLevel() or 1) + 4)
	b.edges = UI.Border(b.over)
	b.hotkey = UI.Text(b.over, "NumberFontNormalSmallGray", "RIGHT", C.dim)
	b.hotkey:SetPoint("TOPRIGHT", -2, -2)
	b.count = UI.Text(b.over, "NumberFontNormal", "RIGHT")
	b.count:SetPoint("BOTTOMRIGHT", -2, 2)
	b.label = UI.Text(b.over, "GameFontHighlightSmall", "CENTER")
	b.label:SetPoint("BOTTOMLEFT", 1, 2)
	b.label:SetPoint("BOTTOMRIGHT", -1, 2)
	b.flash = UI.Fill(b.over, { 1, 1, 1, 0.35 }, "OVERLAY")
	b.flash:Hide()
	b.hl = UI.Fill(b.over, C.hover, "HIGHLIGHT")
	b.auto = UI.Tex(b.over, "OVERLAY", { 1, 0.82, 0, 0.9 })
	b.auto:SetSize(6, 6)
	b.auto:SetPoint("TOPLEFT", 2, -2)
	b.auto:Hide()
	b.glow = UI.Border(b.over, { 1, 0.9, 0.35, 1 })
	b.glow[1]:SetHeight(2)
	b.glow[2]:SetHeight(2)
	b.glow[3]:SetWidth(2)
	b.glow[4]:SetWidth(2)
	for i = 1, 4 do b.glow[i]:Hide() end

	b:SetScript("OnEnter", function(self)
		ns.hover = self
		showTooltip(self)
		ns:Fire("HOVER", self)
	end)
	b:SetScript("OnLeave", function(self)
		if ns.hover == self then ns.hover = nil end
		if GameTooltip then GameTooltip:Hide() end
		ns:Fire("HOVER", nil)
	end)
	b:SetScript("PreClick", function(self, button, down)
		if not self.flashing then
			self.flashing = true
			self.flash:Show()
			ns.After(0.12, function()
				self.flashing = nil
				self.flash:Hide()
			end)
		end
		if ns.InCombat() or self.kind == "stance" then return end
		if down and button ~= "Keybind" then
			if ns.p.dragLock and pickupKey() and self:IsMouseOver() then
				self.held = true
				self:SetAttribute("useOnKeyDown", false)
			else
				release(self)
			end
		end
		if self.kind ~= "action" then return end
		if down then
			self.dropped = nil
			if cursorHolds() then self.dropping = true end
		end
		if self.dropping or dropActive(self) then self:SetAttribute("type", "empty") end
	end)
	b:SetScript("PostClick", function(self, button, down)
		if self.kind == "pet" and button == "RightButton" and not down and TogglePetAutocast and not ns.InCombat() then
			pcall(TogglePetAutocast, self.id)
		end
		if self.kind == "action" and (self.dropping or self.dropped) and not ns.InCombat() then
			self:SetAttribute("type", "action")
			if self.dropping then
				self.dropping = nil
				self.dropped = now()
				if self.slot and PlaceAction then pcall(PlaceAction, self.slot) end
			elseif not down then
				self.dropped = nil
				self.dropEnd = now()
			end
		end
		if not down then release(self) end
		Button.Update(self)
	end)
	if kind == "pet" then
		b:RegisterForDrag("LeftButton", "RightButton")
		local function swap(self, drop)
			if ns.InCombat() or not PickupPetAction then return end
			if not drop and ns.p.dragLock and not pickupKey() then return end
			release(self)
			pcall(PickupPetAction, self.id)
			Button.Update(self)
		end
		b:SetScript("OnDragStart", function(self) swap(self, false) end)
		b:SetScript("OnReceiveDrag", function(self) swap(self, true) end)
	end
	if kind == "action" then
		b:RegisterForDrag("LeftButton", "RightButton")
		b:SetScript("OnDragStart", function(self)
			if ns.InCombat() or not self.slot or not PickupAction then return end
			if ns.p.dragLock and not pickupKey() then return end
			release(self)
			pcall(PickupAction, self.slot)
			Button.Update(self)
		end)
		b:SetScript("OnReceiveDrag", function(self)
			if ns.InCombat() or not self.slot or not PlaceAction then return end
			if dropActive(self) or (self.dropEnd and now() - self.dropEnd < 0.3) then return end
			pcall(PlaceAction, self.slot)
			Button.Update(self)
		end)
		b:SetScript("OnAttributeChanged", function(self, attr, value)
			if attr == "action" and type(value) == "number" and value ~= self.slot then
				self.slot = value
				Button.Update(self)
			end
		end)
	end
	ns.buttons[#ns.buttons + 1] = b
	return b
end

local function border(b, r, g, bl, a)
	for i = 1, 4 do b.edges[i]:SetColorTexture(r, g, bl, a or 1) end
end

local function tint(b)
	local icon = b.icon
	if b.kind ~= "action" or not b.has then
		if b.far then
			b.far = nil
			b.hotkey:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
		end
		icon:SetVertexColor(1, 1, 1)
		if icon.SetDesaturated then icon:SetDesaturated(false) end
		return
	end
	local usable, noMana = call("IsUsableAction", b.slot)
	local secretU
	usable, secretU = plain(usable)
	noMana = plain(noMana)
	local grey = false
	local r, g, bl = 1, 1, 1
	if not secretU then
		if noMana then
			r, g, bl = 0.4, 0.5, 1
		elseif not usable then
			r, g, bl = 0.45, 0.45, 0.45
			grey = true
		end
	end
	local far = false
	if ns.p.range then
		local inRange = plain(call("IsActionInRange", b.slot))
		far = inRange == false or inRange == 0
		if far and not grey then r, g, bl = 0.9, 0.25, 0.25 end
	end
	if b.far ~= far then
		b.far = far
		if far then
			b.hotkey:SetTextColor(0.95, 0.25, 0.25)
		else
			b.hotkey:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
		end
	end
	icon:SetVertexColor(r, g, bl)
	if icon.SetDesaturated then icon:SetDesaturated(grey) end
end
Button.Tint = tint

local function glowing(slot)
	if not ns.p.glow or not ns.glows or next(ns.glows) == nil then return false end
	local kind, id = call("GetActionInfo", slot)
	kind, id = plain(kind), plain(id)
	if kind ~= "spell" or id == nil then return false end
	return ns.glows[id] == true
end

local function updateAction(b)
	local slot = b.slot
	local texture, has
	if slot then
		texture = call("GetActionTexture", slot)
		has = plain(call("HasAction", slot))
	end
	b.has = (has or present(texture)) and true or false
	local lit = b.has and glowing(slot)
	if b.lit ~= lit then
		b.lit = lit
		for i = 1, 4 do b.glow[i]:SetShown(lit) end
	end
	if present(texture) then
		b.icon:SetTexture(texture)
		b.icon:Show()
	else
		b.icon:Hide()
	end
	if b.has then
		actionCooldown(b)
		local count = ""
		local consumable = plain(call("IsConsumableAction", slot))
		local stackable = plain(call("IsStackableAction", slot))
		if AB.GetActionDisplayCount then
			local ok, text = pcall(AB.GetActionDisplayCount, slot, 999)
			if ok and present(text) then count = text end
		elseif consumable or stackable then
			local n, secret = plain(call("GetActionCount", slot))
			if secret then
				count = call("GetActionCount", slot)
			elseif type(n) == "number" then
				count = n > 999 and "*" or tostring(n)
			end
		end
		b.count:SetText(count)
		local text = ""
		if ns.p.macroNames then
			local t = plain(call("GetActionText", slot))
			if type(t) == "string" then text = t:sub(1, 6) end
		end
		b.label:SetText(text)
		local equipped = plain(call("IsEquippedAction", slot))
		local current = plain(call("IsCurrentAction", slot)) or plain(call("IsAutoRepeatAction", slot))
		if current then
			border(b, C.accent[1], C.accent[2], C.accent[3], 1)
		elseif equipped then
			border(b, 0.2, 0.85, 0.3, 1)
		else
			border(b, C.line[1], C.line[2], C.line[3], 1)
		end
	else
		setCooldown(b.cd)
		b.count:SetText("")
		b.label:SetText("")
		border(b, C.line[1], C.line[2], C.line[3], 1)
	end
	tint(b)
end

local function updatePet(b)
	local name, texture, active, autoAllowed, autoEnabled = petInfo(b.id)
	b.has = present(name)
	if present(texture) then
		b.icon:SetTexture(texture)
		b.icon:Show()
	else
		b.icon:Hide()
	end
	if b.has and GetPetActionCooldown then
		local ok, start, duration = pcall(GetPetActionCooldown, b.id)
		if ok then setCooldown(b.cd, start, duration) end
	else
		setCooldown(b.cd)
	end
	active = plain(active)
	autoEnabled = plain(autoEnabled)
	autoAllowed = plain(autoAllowed)
	if active then
		border(b, C.accent[1], C.accent[2], C.accent[3], 1)
	else
		border(b, C.line[1], C.line[2], C.line[3], 1)
	end
	b.auto:SetShown(autoAllowed and true or false)
	if autoEnabled then
		b.auto:SetColorTexture(1, 0.82, 0, 0.95)
	else
		b.auto:SetColorTexture(0.45, 0.45, 0.5, 0.8)
	end
	b.count:SetText("")
	b.label:SetText("")
end

local function updateStance(b)
	local icon, active, castable = stanceInfo(b.id)
	b.has = present(icon)
	if present(icon) then
		b.icon:SetTexture(icon)
		b.icon:Show()
	else
		b.icon:Hide()
	end
	if b.has and GetShapeshiftFormCooldown then
		local ok, start, duration = pcall(GetShapeshiftFormCooldown, b.id)
		if ok then setCooldown(b.cd, start, duration) end
	else
		setCooldown(b.cd)
	end
	active = plain(active)
	local usable, secret = plain(castable)
	if active then
		border(b, C.accent[1], C.accent[2], C.accent[3], 1)
	else
		border(b, C.line[1], C.line[2], C.line[3], 1)
	end
	if secret or usable then
		b.icon:SetVertexColor(1, 1, 1)
	else
		b.icon:SetVertexColor(0.45, 0.45, 0.45)
	end
	b.count:SetText("")
	b.label:SetText("")
end

function Button.Update(b)
	if b.kind == "action" then
		updateAction(b)
	elseif b.kind == "pet" then
		updatePet(b)
	else
		updateStance(b)
	end
	Button.Hotkey(b)
	Button.Alpha(b)
end

function Button.Hotkey(b)
	local text = ""
	if ns.p.hotkeys and ns.KeyFor then text = ns.ShortKey(ns.KeyFor(b)) end
	b.hotkey:SetText(text)
end

function Button.Alpha(b)
	local cfg = b.cfg
	local alpha = 1
	if cfg and cfg.hideEmpty and not b.has and not ns.grid and not ns.bindMode and ns.p.locked then alpha = 0 end
	if b.alpha ~= alpha then
		b.alpha = alpha
		b:SetAlpha(alpha)
	end
end

function Button.UpdateAll(kind)
	for _, b in ipairs(ns.buttons) do
		if b.active and (not kind or b.kind == kind) then Button.Update(b) end
	end
end

function Button.CooldownAll()
	for _, b in ipairs(ns.buttons) do
		if b.active and b.has then
			if b.kind == "action" then
				actionCooldown(b)
			elseif b.kind == "pet" and GetPetActionCooldown then
				local ok, start, duration = pcall(GetPetActionCooldown, b.id)
				if ok then setCooldown(b.cd, start, duration) end
			end
		end
	end
end

function Button.TintAll()
	for _, b in ipairs(ns.buttons) do
		if b.active and b.kind == "action" then tint(b) end
	end
end

function Button.Style(b)
	if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(not ns.p.cdText) end
	local size = ns.p.textSize or 0
	for _, fs in ipairs({ b.hotkey, b.count, b.label }) do
		local path, base, flags = fs:GetFont()
		if type(path) == "string" and type(base) == "number" then
			if not fs.baseSize then fs.baseSize = base end
			fs:SetFont(path, size > 0 and size or fs.baseSize, flags)
		end
	end
end
