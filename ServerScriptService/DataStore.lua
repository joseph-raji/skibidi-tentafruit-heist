-- NOTE: Enable 'API Services' in Studio Game Settings > Security for DataStore to work in Studio

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local store = DataStoreService:GetDataStore("SkibidiTentafruit_v1")

local DEFAULTS = {
	money = 50,
	rebirths = 0,
	multiplier = 1,
	brainrotIds = {},
}

local DataStore = {}

function DataStore.loadPlayer(player)
	local key = "player_" .. player.UserId
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)

	if not ok then
		warn("[DataStore] Failed to load data for " .. player.Name .. ": " .. tostring(result))
		return {
			money = DEFAULTS.money,
			rebirths = DEFAULTS.rebirths,
			multiplier = DEFAULTS.multiplier,
			brainrotIds = {},
		}
	end

	if result == nil then
		return {
			money = DEFAULTS.money,
			rebirths = DEFAULTS.rebirths,
			multiplier = DEFAULTS.multiplier,
			brainrotIds = {},
		}
	end

	return {
		money = result.money or DEFAULTS.money,
		rebirths = result.rebirths or DEFAULTS.rebirths,
		multiplier = result.multiplier or DEFAULTS.multiplier,
		brainrotIds = result.brainrotIds or {},
	}
end

function DataStore.savePlayer(player, brainrotOwner)
	local key = "player_" .. player.UserId

	local brainrotIds = {}
	for part, owner in pairs(brainrotOwner) do
		if owner == player then
			local id = part:GetAttribute("BrainrotId")
			if id then
				table.insert(brainrotIds, id)
			end
		end
	end

	local data = {
		money = player:GetAttribute("money") or DEFAULTS.money,
		rebirths = player:GetAttribute("RebirthCount") or DEFAULTS.rebirths,
		multiplier = player:GetAttribute("MoneyMultiplier") or DEFAULTS.multiplier,
		brainrotIds = brainrotIds,
	}

	local ok, err = pcall(function()
		store:SetAsync(key, data)
	end)

	if not ok then
		warn("[DataStore] Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataStore.setupAutoSave(brainrotOwner)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				DataStore.savePlayer(player, brainrotOwner)
			end
		end
	end)
end

return DataStore
