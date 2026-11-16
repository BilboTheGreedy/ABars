local _, ns = ...

local hidden
local done = false

local BARS = {
	"MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
	"MultiBar5", "MultiBar6", "MultiBar7",
	"StanceBar", "StanceBarFrame", "PetActionBar", "PetActionBarFrame", "PossessActionBar", "PossessBarFrame",
}
local MAIN = { "MainMenuBar", "MainActionBar" }
local BUTTONS = {
	"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarLeftButton", "MultiBarRightButton",
	"MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

local function park(frame)
	if type(frame) ~= "table" or not frame.SetParent then return false end
	frame:SetParent(hidden)
	return true
end

function ns.HideBlizzard()
	if done or not ns.p.hideBlizzard then return false end
	return ns.Safe("blizzard", function()
		if done then return end
		done = true
		hidden = hidden or CreateFrame("Frame", "ABarsHidden", UIParent)
		hidden:Hide()
		local count = 0
		for _, name in ipairs(BARS) do
			if park(_G[name]) then count = count + 1 end
		end
		local classic = _G.MainMenuBarArtFrame ~= nil
		for _, prefix in ipairs(BUTTONS) do
			for i = 1, 12 do
				local b = _G[prefix .. i]
				if type(b) == "table" then
					if b.UnregisterAllEvents then b:UnregisterAllEvents() end
					if classic and prefix == "ActionButton" and park(b) then count = count + 1 end
				end
			end
		end
		if not classic then
			for _, name in ipairs(MAIN) do
				if park(_G[name]) then count = count + 1 end
			end
		end
		ns.hiddenCount = count
	end)
end

ns:Listen("START", function() ns.HideBlizzard() end)
