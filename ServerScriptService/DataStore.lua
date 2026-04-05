-- DataStore.lua
-- Wrap GetDataStore in pcall so a missing API Services toggle in Studio
-- does NOT crash the whole server script at require() time.

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local store
local storeReady = false
local storeOk, storeErr = pcall(function()
	store = DataStoreService:GetDataStore("SkibidiTentafruit_v1")
	storeReady = true
end)
if not storeOk then
	warn("[DataStore] DataStore unavailable — enable 'API Services' in Studio Game Settings > Security. Error: " .. tostring(storeErr))
end

local DEFAULTS = {
	money      = 50,
	rebirths   = 0,
	multiplier = 1,
	brainrotIds = {},
}

local DataStore = {}

function DataStore.loadPlayer(player)
	if not storeReady then
		return {
			money      = DEFAULTS.money,
			rebirths   = DEFAULTS.rebirths,
			multiplier = DEFAULTS.multiplier,
			brainrotIds = {},
		}
	end

	local key = "player_" .. player.UserId
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)

	if not ok then
		warn("[DataStore] Failed to load data for " .. player.Name .. ": " .. tostring(result))
		return {
			money      = DEFAULTS.money,
			rebirths   = DEFAULTS.rebirths,
			multiplier = DEFAULTS.multiplier,
			brainrotIds = {},
		}
	end

	if result == nil then
		return {
			money      = DEFAULTS.money,
			rebirths   = DEFAULTS.rebirths,
			multiplier = DEFAULTS.multiplier,
			brainrotIds = {},
		}
	end

	return {
		money      = result.money      or DEFAULTS.money,
		rebirths   = result.rebirths   or DEFAULTS.rebirths,
		multiplier = result.multiplier or DEFAULTS.multiplier,
		brainrotIds = result.brainrotIds or {},
	}
end

function DataStore.savePlayer(player, brainrotOwner)
	if not storeReady then return end

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
		money      = player:GetAttribute("Money")          or DEFAULTS.money,
		rebirths   = player:GetAttribute("RebirthCount")   or DEFAULTS.rebirths,
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
	if not storeReady then return end
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
