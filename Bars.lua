local _, ns = ...
local UI = ns.UI
local C = UI.colors
local Button = ns.Button

local bars = {}
ns.bars = bars
ns.barList = {}

local PAGE = "[bonusbar:5]11;[bar:2]2;[bar:3]3;[bar:4]4;[bar:5]5;[bar:6]6;[bonusbar:1]7;[bonusbar:2]8;[bonusbar:3]9;[bonusbar:4]10;1"

local PAGING = [[
	local offset = (tonumber(newstate) - 1) * 12
	self:SetAttribute("page", newstate)
	for i = 1, 12 do
		local b = self:GetFrameRef("b" .. i)
		if b then b:SetAttribute("action", offset + i) end
	end
]]

local VISIBILITY = {
	always = { "show", "[pet]show;hide" },
	combat = { "[combat]show;hide", "[pet,combat]show;hide" },
	nocombat = { "[combat]hide;show", "[pet,nocombat]show;hide" },
	hidden = { "hide", "hide" },
}
ns.VISIBILITY = { { "always", "Always" }, { "combat", "Only in combat" }, { "nocombat", "Only out of combat" }, { "hidden", "Never" } }

local function condition(bar)
	local cfg = bar.cfg
	if not cfg.enabled then return "hide" end
	local v = VISIBILITY[cfg.visibility] or VISIBILITY.always
	return bar.def.kind == "pet" and v[2] or v[1]
end

local function stanceCount()
	local n = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
	if type(n) ~= "number" or ns.IsSecret(n) then return 0 end
	return n
end

local function create(def)
	local name = "ABars" .. def.key:sub(1, 1):upper() .. def.key:sub(2)
	local header = CreateFrame("Frame", name, UIParent, "SecureHandlerStateTemplate")
	header:SetMovable(true)
	header:SetClampedToScreen(true)
	local bar = { def = def, header = header, buttons = {}, max = def.max or 12, name = name }
	for i = 1, bar.max do
		local b = Button.Create(name .. "Button" .. i, header, def.kind, i)
		b.bar = bar
		if def.kind == "action" then
			b.slot = def.offset + i
			b:SetAttribute("type", "action")
			b:SetAttribute("action", b.slot)
			if header.SetFrameRef then header:SetFrameRef("b" .. i, b) end
		elseif def.kind == "pet" then
			b:SetAttribute("type", "pet")
			b:SetAttribute("action", i)
			b:SetAttribute("type2", "autocast")
		else
			b:SetAttribute("type", "spell")
		end
		if def.command then b.command = def.command:format(i) end
		bar.buttons[i] = b
	end
	if def.paged and RegisterStateDriver then
		header:SetAttribute("_onstate-page", PAGING)
		RegisterStateDriver(header, "page", PAGE)
	end
	bars[def.key] = bar
	ns.barList[#ns.barList + 1] = bar
	return bar
end

local function place(bar)
	local cfg = bar.cfg
	local header = bar.header
	local pos = cfg.pos or cfg.default
	header:ClearAllPoints()
	header:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
	header:SetScale(cfg.scale or 1)
	if not header.Restore then
		header.Restore = function() place(bar) end
	end
	if ACore.RegisterMover then
		ACore.RegisterMover(header, cfg, nil, "ABars " .. bar.def.title, function() return bar.cfg.enabled end)
	end
end

function ns.Layout(bar)
	local cfg = ns.p.bars[bar.def.key]
	bar.cfg = cfg
	local count = math.max(1, math.min(cfg.count or bar.max, bar.max))
	if bar.def.kind == "stance" then
		local forms = stanceCount()
		for i = 1, bar.max do
			local _, _, _, spell = ns.StanceInfo(i)
			if spell ~= nil then bar.buttons[i]:SetAttribute("spell", spell) end
		end
		count = math.min(count, forms)
	end
	local cols = math.max(1, math.min(cfg.cols or count, math.max(count, 1)))
	local size, gap = cfg.size or 36, cfg.spacing or 3
	for i, b in ipairs(bar.buttons) do
		b.cfg = cfg
		if i <= count then
			local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
			b:SetSize(size, size)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", bar.header, "TOPLEFT", col * (size + gap), -row * (size + gap))
			b:Show()
			b.active = cfg.enabled and true or false
		else
			b:Hide()
			b.active = false
		end
	end
	local rows = math.max(1, math.ceil(count / cols))
	bar.header:SetSize(math.max(size, cols * (size + gap) - gap), math.max(size, rows * (size + gap) - gap))
	place(bar)
	bar.count = count
	if RegisterStateDriver then
		if UnregisterStateDriver then UnregisterStateDriver(bar.header, "visibility") end
		local cond = condition(bar)
		if count == 0 then cond = "hide" end
		RegisterStateDriver(bar.header, "visibility", cond)
		bar.condition = cond
	else
		bar.header:SetShown(cfg.enabled and count > 0)
	end
	bar.alpha = nil
	for _, b in ipairs(bar.buttons) do
		b.alpha = nil
		if b.active then Button.Update(b) end
	end
	ns:Fire("LAYOUT", bar)
end

function ns.LayoutAll()
	return ns.Safe("layout", function()
		for _, bar in ipairs(ns.barList) do ns.Layout(bar) end
		if ns.ApplyBindings then ns.ApplyBindings() end
	end)
end

function ns.LayoutBar(key)
	local bar = bars[key]
	if not bar then return false end
	return ns.Safe("layout:" .. key, function()
		ns.Layout(bar)
		if ns.ApplyBindings then ns.ApplyBindings() end
	end)
end

function ns.Snap(v)
	if not ns.p.snap then return v end
	return math.floor(v / 8 + 0.5) * 8
end

function ns.SavePosition(bar)
	local header = bar.header
	local x, y = header:GetLeft(), header:GetBottom()
	if type(x) ~= "number" or type(y) ~= "number" then return end
	bar.cfg.pos = { "BOTTOMLEFT", "BOTTOMLEFT", ns.Snap(x), ns.Snap(y) }
	place(bar)
end

local function fade(inCombat)
	for _, bar in ipairs(ns.barList) do
		local cfg = bar.cfg
		if cfg and cfg.enabled then
			local alpha = cfg.alpha or 1
			if not ns.p.locked or ns.bindMode then
				alpha = 1
			elseif cfg.mouseover then
				local over = bar.header.IsMouseOver and bar.header:IsMouseOver()
				if not over then alpha = 0 end
			elseif cfg.fade and not inCombat then
				alpha = math.min(alpha, cfg.fadeAlpha or 0.35)
			end
			if bar.alpha ~= alpha then
				bar.alpha = alpha
				bar.header:SetAlpha(alpha)
			end
		end
	end
end
ns.Fade = fade

local combat = false
ns:Listen("COMBAT", function(on)
	combat = on
	fade(on)
end)

local function grid(on)
	ns.grid = on
	for _, b in ipairs(ns.buttons) do
		if b.active then Button.Alpha(b) end
	end
end

ns:Listen("START", function()
	for _, def in ipairs(ns.BARS) do create(def) end
	ns.LayoutAll()

	local ticker = CreateFrame("Frame")
	local a, r = 0, 0
	ticker:SetScript("OnUpdate", function(_, dt)
		dt = dt or 0
		a, r = a + dt, r + dt
		if a >= 0.1 then
			a = 0
			fade(combat)
		end
		if r >= 0.2 then
			r = 0
			Button.TintAll()
		end
	end)
	ns.ticker = ticker

	local function all() Button.UpdateAll() end
	local function actions() Button.UpdateAll("action") end
	ns:On("PLAYER_ENTERING_WORLD", function()
		ns.LayoutAll()
		all()
	end)
	ns:On("ACTIONBAR_SLOT_CHANGED", actions)
	ns:On("ACTIONBAR_PAGE_CHANGED", actions)
	ns:On("UPDATE_BONUS_ACTIONBAR", actions)
	ns:On("ACTIONBAR_UPDATE_STATE", actions)
	ns:On("ACTIONBAR_UPDATE_USABLE", function() Button.TintAll() end)
	ns:On("SPELL_UPDATE_USABLE", function() Button.TintAll() end)
	ns:On("PLAYER_TARGET_CHANGED", function() Button.TintAll() end)
	ns:On("ACTIONBAR_UPDATE_COOLDOWN", function() Button.CooldownAll() end)
	ns:On("SPELL_UPDATE_COOLDOWN", function() Button.CooldownAll() end)
	ns:On("PET_BAR_UPDATE_COOLDOWN", function() Button.CooldownAll() end)
	ns:On("BAG_UPDATE_DELAYED", actions)
	ns:On("PLAYER_EQUIPMENT_CHANGED", actions)
	ns:On("SPELLS_CHANGED", actions)
	ns:On("ACTIONBAR_SHOWGRID", function() grid(true) end)
	ns:On("ACTIONBAR_HIDEGRID", function() grid(false) end)
	local function pet() Button.UpdateAll("pet") end
	ns:On("PET_BAR_UPDATE", pet)
	ns:On("PET_UI_UPDATE", pet)
	ns:On("UNIT_PET", pet)
	ns:On("PLAYER_CONTROL_LOST", pet)
	ns:On("PLAYER_CONTROL_GAINED", pet)
	ns:On("UPDATE_SHAPESHIFT_FORMS", function() ns.LayoutBar("stance") end)
	ns:On("UPDATE_SHAPESHIFT_FORM", function() Button.UpdateAll("stance") end)
	ns:On("UPDATE_SHAPESHIFT_USABLE", function() Button.UpdateAll("stance") end)
	ns:On("UPDATE_SHAPESHIFT_COOLDOWN", function() Button.UpdateAll("stance") end)
end)

ns:Listen("PROFILE", function() ns.LayoutAll() end)
