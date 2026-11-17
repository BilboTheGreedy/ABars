local _, ns = ...

local hidden
local parked = {}
local state = {}

local GROUPS = {
	{ key = "main", text = "Main action bar", frames = { "MainMenuBar", "MainActionBar" }, buttons = { "ActionButton" } },
	{
		key = "multi", text = "Extra action bars", events = true,
		frames = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight", "MultiBar5", "MultiBar6", "MultiBar7" },
		buttons = {
			"MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarLeftButton", "MultiBarRightButton",
			"MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
		},
	},
	{ key = "stance", text = "Stance bar", events = true, frames = { "StanceBar", "StanceBarFrame", "PossessActionBar", "PossessBarFrame" } },
	{ key = "pet", text = "Pet bar", events = true, frames = { "PetActionBar", "PetActionBarFrame" } },
	{ key = "micro", text = "Micro menu", live = true, frames = { "MicroMenuContainer" } },
	{ key = "bags", text = "Bag bar", live = true, frames = { "BagsBar" } },
}
ns.BLIZZARD = GROUPS

local function park(frame, events)
	if type(frame) ~= "table" or not frame.SetParent or not frame.GetParent then return false end
	if parked[frame] == nil then parked[frame] = frame:GetParent() or UIParent end
	if events and frame.UnregisterAllEvents then frame:UnregisterAllEvents() end
	frame:SetParent(hidden)
	return true
end

local function hide(g)
	local count = 0
	local classic = g.key == "main" and _G.MainMenuBarArtFrame ~= nil
	if not classic then
		for _, name in ipairs(g.frames) do
			if park(_G[name], g.events) then count = count + 1 end
		end
	end
	for _, prefix in ipairs(g.buttons or {}) do
		for i = 1, 12 do
			local b = _G[prefix .. i]
			if type(b) == "table" then
				if b.UnregisterAllEvents then b:UnregisterAllEvents() end
				if classic and park(b) then count = count + 1 end
			end
		end
	end
	return count
end

local function show(g)
	for _, name in ipairs(g.frames) do
		local frame = _G[name]
		if type(frame) == "table" and parked[frame] then
			frame:SetParent(parked[frame])
			parked[frame] = nil
			if frame.Show then frame:Show() end
		end
	end
end

function ns.HideBlizzard()
	local reload = false
	local ok = ns.Safe("blizzard", function()
		hidden = hidden or CreateFrame("Frame", "ABarsHidden", UIParent)
		hidden:Hide()
		for _, g in ipairs(GROUPS) do
			local on = ns.p.blizzard[g.key] and true or false
			if on and not state[g.key] then
				state[g.key] = true
				ns.hiddenCount = (ns.hiddenCount or 0) + hide(g)
			elseif not on and state[g.key] then
				if g.live then
					state[g.key] = nil
					show(g)
				else
					reload = true
				end
			end
		end
	end)
	return ok, reload
end

ns:Listen("START", function() ns.HideBlizzard() end)
ns:Listen("PROFILE", function() ns.HideBlizzard() end)
