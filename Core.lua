local ADDON, ns = ...

local function bar(enabled, count, cols, default)
	return {
		enabled = enabled, count = count, cols = cols, size = 36, spacing = 3, scale = 1, alpha = 1,
		fade = false, fadeAlpha = 0.35, mouseover = false, visibility = "always", hideEmpty = false,
		default = default,
	}
end

ns.BARS = {
	{ key = "bar1", title = "Bar 1", kind = "action", offset = 0, paged = true, command = "ACTIONBUTTON%d" },
	{ key = "bar2", title = "Bar 2", kind = "action", offset = 60, command = "MULTIACTIONBAR1BUTTON%d" },
	{ key = "bar3", title = "Bar 3", kind = "action", offset = 48, command = "MULTIACTIONBAR2BUTTON%d" },
	{ key = "bar4", title = "Bar 4", kind = "action", offset = 24, command = "MULTIACTIONBAR3BUTTON%d" },
	{ key = "bar5", title = "Bar 5", kind = "action", offset = 36, command = "MULTIACTIONBAR4BUTTON%d" },
	{ key = "bar6", title = "Bar 6", kind = "action", offset = 12 },
	{ key = "pet", title = "Pet bar", kind = "pet", max = 10, command = "BONUSACTIONBUTTON%d" },
	{ key = "stance", title = "Stance bar", kind = "stance", max = 10, command = "SHAPESHIFTBUTTON%d" },
}

local function profile()
	return {
		locked = true,
		hotkeys = true,
		macroNames = false,
		range = true,
		snap = true,
		dragLock = true,
		cdText = true,
		glow = true,
		textSize = 0,
		blizzard = { main = true, multi = true, stance = true, pet = true, micro = false, bags = false },
		bars = {
			bar1 = bar(true, 12, 12, { "BOTTOM", "BOTTOM", 0, 40 }),
			bar2 = bar(true, 12, 12, { "BOTTOM", "BOTTOM", 0, 82 }),
			bar3 = bar(true, 12, 12, { "BOTTOM", "BOTTOM", 0, 124 }),
			bar4 = bar(true, 12, 1, { "RIGHT", "RIGHT", -8, 0 }),
			bar5 = bar(false, 12, 1, { "RIGHT", "RIGHT", -50, 0 }),
			bar6 = bar(false, 12, 12, { "BOTTOM", "BOTTOM", 0, 166 }),
			pet = bar(true, 10, 10, { "BOTTOM", "BOTTOM", -150, 170 }),
			stance = bar(true, 10, 10, { "BOTTOM", "BOTTOM", -330, 170 }),
		},
	}
end

ACore.New(ADDON, ns, { db = "ABarsDB", defaults = { profiles = {} } })

local function copy(src)
	local out = {}
	for k, v in pairs(src) do
		out[k] = type(v) == "table" and copy(v) or v
	end
	return out
end
ns.Copy = copy

function ns.InCombat()
	return InCombatLockdown and InCombatLockdown() and true or false
end

local queue = {}
function ns.Safe(key, fn)
	if ns.InCombat() then
		if not queue[key] then queue[#queue + 1] = key end
		queue[key] = fn
		return false
	end
	fn()
	return true
end

ns:On("PLAYER_REGEN_ENABLED", function()
	local keys = queue
	queue = {}
	for _, key in ipairs(keys) do
		local fn = keys[key]
		if fn then fn() end
	end
	ns:Fire("COMBAT", false)
end)

ns:On("PLAYER_REGEN_DISABLED", function()
	ns:Fire("COMBAT", true)
end)

function ns.CharKey()
	local name = UnitName and UnitName("player") or "Unknown"
	local realm = GetRealmName and GetRealmName() or "Realm"
	return tostring(name) .. " - " .. tostring(realm)
end

local function fill(p)
	if p.hideBlizzard == false and type(p.blizzard) ~= "table" then
		p.blizzard = { main = false, multi = false, stance = false, pet = false, micro = false, bags = false }
	end
	p.hideBlizzard = nil
	local base = profile()
	ACore.Fill(p, base)
	for key, cfg in pairs(base.bars) do
		p.bars[key].default = cfg.default
	end
	return p
end

ns:Listen("LOGIN", function()
	ns.db.stamps = ns.db.stamps or {}
	local own = ns.db.profiles[ns.CharKey()]
	local fresh = type(ns.db.profiles[ACore.Profile()]) ~= "table"
	local key = ACore.ProfileSync(ns.db.profiles, ns.db.stamps)
	ns.charKey = key
	local p = ns.db.profiles[key]
	if fresh and type(own) == "table" and next(p) == nil then
		for k, v in pairs(ACore.Copy(own)) do p[k] = v end
	end
	fill(p)
	ns.p = p
	ns:Fire("START")
end)

function ns.CopyProfile(from)
	local src = ns.db.profiles[from]
	if not src or from == ns.charKey then return false end
	local p = ns.p
	for k in pairs(p) do p[k] = nil end
	for k, v in pairs(copy(src)) do p[k] = v end
	fill(p)
	ns:Fire("PROFILE")
	return true
end

function ns.ResetProfile()
	local p = ns.p
	for k in pairs(p) do p[k] = nil end
	fill(p)
	ns:Fire("PROFILE")
end

ACore.Register({
	name = "ABars",
	title = "ABars",
	slash = "/abars",
	desc = "action bars",
	toggle = function() ns.OpenOptions() end,
	options = function()
		if not ns.p or not ns.Options then return {} end
		return ns.Options()
	end,
})

SLASH_ABARS1 = "/abars"
SLASH_ABARS2 = "/abar"
SlashCmdList["ABARS"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "" or msg == "options" then
		ns.OpenOptions()
	elseif msg == "unlock" or msg == "move" then
		ns.SetLocked(false)
	elseif msg == "lock" then
		ns.SetLocked(true)
	elseif msg == "bind" or msg == "keys" then
		ns.ToggleBindMode()
	elseif msg == "reset" then
		ns.ResetProfile()
		ns.Print("layout reset")
	else
		ns.Print("/abars, /abars unlock, /abars lock, /abars bind, /abars reset")
	end
end
