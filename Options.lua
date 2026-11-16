local _, ns = ...
local UI = ns.UI
local C = UI.colors
local Button = ns.Button

local anchor
local handles = {}

local function menuAnchor()
	if not anchor then
		anchor = CreateFrame("Frame", "ABarsMenuAnchor", UIParent)
		anchor:SetSize(1, 1)
		anchor:SetPoint("CENTER", UIParent, "CENTER", -110, 160)
	end
	return anchor
end

local function refreshButtons()
	Button.UpdateAll()
	ns.Fade(ns.InCombat())
end

local function relayout(key)
	local ok
	if key then ok = ns.LayoutBar(key) else ok = ns.LayoutAll() end
	if not ok then ns.Print("change applies when combat ends") end
end

local function choice(at, title, list, current, set, label)
	local entries = { { text = title, title = true } }
	for _, v in ipairs(list) do
		entries[#entries + 1] = {
			text = label and label(v) or tostring(v), checked = v == current,
			func = function() set(v) end,
		}
	end
	UI.Menu(at, entries)
end

local function percent(v) return math.floor(v * 100 + 0.5) .. "%" end

function ns.BarMenu(key, at)
	local bar = ns.bars[key]
	if not bar then return end
	at = at or menuAnchor()
	local cfg = ns.p.bars[key]
	local function again() ns.BarMenu(key, at) end
	local function pick(title, field, list, label, light)
		return {
			text = title .. ": " .. (label and label(cfg[field]) or tostring(cfg[field])),
			func = function()
				choice(at, bar.def.title .. " - " .. title, list, cfg[field], function(v)
					cfg[field] = v
					if light then refreshButtons() else relayout(key) end
					again()
				end, label)
			end,
		}
	end
	local counts = {}
	for i = 1, bar.max do counts[i] = i end
	local visLabel = function(v)
		for _, e in ipairs(ns.VISIBILITY) do
			if e[1] == v then return e[2] end
		end
		return tostring(v)
	end
	local vis = {}
	for i, e in ipairs(ns.VISIBILITY) do vis[i] = e[1] end
	local entries = {
		{ text = bar.def.title, title = true },
		UI.Check(cfg, "enabled", "Enabled", function() relayout(key) end),
		pick("Buttons", "count", counts),
		pick("Columns", "cols", { 1, 2, 3, 4, 5, 6, 10, 12 }),
		pick("Button size", "size", { 24, 28, 32, 36, 40, 44, 48 }),
		pick("Spacing", "spacing", { 0, 1, 2, 3, 4, 6, 8 }),
		pick("Scale", "scale", { 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.35 }, percent),
		pick("Opacity", "alpha", { 1, 0.85, 0.7, 0.5, 0.3 }, percent, true),
		pick("Show", "visibility", vis, visLabel),
		UI.Check(cfg, "fade", "Fade out of combat", refreshButtons),
		pick("Faded opacity", "fadeAlpha", { 0.6, 0.5, 0.35, 0.2, 0 }, percent, true),
		UI.Check(cfg, "mouseover", "Show only on mouseover", refreshButtons),
		UI.Check(cfg, "hideEmpty", "Hide empty buttons", refreshButtons),
		{
			text = "Reset position",
			func = function()
				cfg.pos = nil
				relayout(key)
			end,
		},
		{ text = "< All bars", func = function() ns.OpenOptions(at) end },
	}
	UI.Menu(at, entries)
end

function ns.ProfileMenu(at)
	at = at or menuAnchor()
	local entries = { { text = "Copy layout from", title = true } }
	local names = {}
	for name in pairs(ns.db.profiles) do
		if name ~= ns.charKey then names[#names + 1] = name end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		entries[#entries + 1] = {
			text = name,
			func = function()
				if ns.CopyProfile(name) then ns.Print("copied layout from " .. name) end
			end,
		}
	end
	if #names == 0 then entries[#entries + 1] = { text = "No other layouts yet", title = true } end
	entries[#entries + 1] = {
		text = "Reset this layout",
		func = function() UI.Confirm("Reset the ABars layout?", ns.ResetProfile) end,
	}
	entries[#entries + 1] = { text = "< Back", func = function() ns.OpenOptions(at) end }
	UI.Menu(at, entries)
end

function ns.OpenOptions(at)
	if not ns.p then return end
	at = at or menuAnchor()
	local p = ns.p
	local entries = {
		{ text = "ABars", title = true },
		{ text = p.locked and "Unlock bars to move them" or "Lock bars", func = function() ns.SetLocked(not p.locked) end },
		{ text = ns.bindMode and "Leave keybind mode" or "Keybind mode", func = function() ns.ToggleBindMode() end },
		UI.Check(p, "snap", "Snap to grid when moving"),
		UI.Check(p, "dragLock", "Hold shift to drag spells off bars"),
		UI.Check(p, "hotkeys", "Show key text", refreshButtons),
		UI.Check(p, "macroNames", "Show macro names", refreshButtons),
		UI.Check(p, "range", "Red when out of range", refreshButtons),
		UI.Check(p, "hideBlizzard", "Hide the default bars", function(on)
			if on then
				ns.HideBlizzard()
			else
				ns.Print("the default bars come back after /reload")
			end
		end),
		{ text = "Bars", title = true },
	}
	for _, def in ipairs(ns.BARS) do
		local cfg = p.bars[def.key]
		entries[#entries + 1] = {
			text = def.title .. (cfg.enabled and "" or "  (off)"),
			color = cfg.enabled and nil or C.dim,
			func = function() ns.BarMenu(def.key, at) end,
		}
	end
	entries[#entries + 1] = { text = "Characters", title = true }
	entries[#entries + 1] = { text = "Copy or reset layout", func = function() ns.ProfileMenu(at) end }
	UI.Menu(at, entries)
end

local function handle(bar)
	local h = handles[bar.def.key]
	if h then return h end
	h = CreateFrame("Button", nil, UIParent)
	h:SetFrameStrata("DIALOG")
	h:SetAllPoints(bar.header)
	UI.Fill(h, { C.accent[1], C.accent[2], C.accent[3], 0.22 })
	UI.Border(h, C.accent)
	h.text = UI.Text(h, "GameFontNormalSmall", "CENTER", C.accent)
	h.text:SetPoint("CENTER")
	h.text:SetText(bar.def.title)
	h:RegisterForDrag("LeftButton")
	h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	h:SetScript("OnDragStart", function()
		if ns.InCombat() then return end
		bar.moving = true
		bar.header:StartMoving()
	end)
	h:SetScript("OnDragStop", function()
		if not bar.moving then return end
		bar.moving = false
		bar.header:StopMovingOrSizing()
		ns.Safe("pos:" .. bar.def.key, function() ns.SavePosition(bar) end)
	end)
	h:SetScript("OnClick", function(self, button)
		if button == "RightButton" then ns.BarMenu(bar.def.key, self) end
	end)
	h:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(bar.def.title, 1, 0.82, 0)
		GameTooltip:AddLine("Drag to move, right-click for options", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	h:SetScript("OnLeave", function() GameTooltip:Hide() end)
	handles[bar.def.key] = h
	return h
end
ns.handles = handles

function ns.SetLocked(locked)
	if not ns.p then return false end
	if not locked and ns.InCombat() then
		ns.Print("bars cannot be moved in combat")
		return false
	end
	ns.p.locked = locked and true or false
	for _, bar in ipairs(ns.barList) do
		local h = handle(bar)
		if bar.moving then
			bar.moving = false
			bar.header:StopMovingOrSizing()
		end
		h:SetShown(not ns.p.locked and bar.cfg and bar.cfg.enabled)
	end
	refreshButtons()
	return true
end

ns:Listen("COMBAT", function(on)
	if on and ns.p and not ns.p.locked then
		ns.SetLocked(true)
		ns.Print("bars locked for combat")
	end
end)

ns:Listen("LAYOUT", function(bar)
	local h = handles[bar.def.key]
	if h then h:SetShown(not ns.p.locked and bar.cfg.enabled) end
end)

ns:Listen("START", function()
	if not ns.p.locked then ns.p.locked = true end
end)
