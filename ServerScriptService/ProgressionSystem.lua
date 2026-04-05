-- ProgressionSystem.lua
-- ModuleScript: rebirth, income generation, and upgrades

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ProgressionSystem = {}

-- Config
local REBIRTH_COST = 8000
local REBIRTH_MULTIPLIER = 1.5
local MAX_REBIRTHS = 10
local INCOME_INTERVAL = 1
local REBIRTH_PAD_DEBOUNCE_TIME = 3

-- NOTE: Income per second is read from the "IncomePerSecond" attribute on each
-- brainrot part. ShopSystem.spawnBrainrot must set:
--   body:SetAttribute("IncomePerSecond", brainrotData.income)
-- on every spawned brainrot body part for income to be credited.

-- MaxSlots granted per rebirth tier
-- Tiers: [0-1, 2-3, 4-5, 6-7, 8+]
local LEVEL_SLOTS = {5, 8, 12, 16, 20}

-- ShopSystem reference injected by Main
local ShopSystem = nil

function ProgressionSystem.setShopSystem(ss)
	ShopSystem = ss
end

-- BaseSystem reference injected by Main
local BaseSystem = nil

function ProgressionSystem.setBaseSystem(bs)
	BaseSystem = bs
end

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local evtNotification = remoteEvents:WaitForChild("Notification")
local evtRebirthComplete = remoteEvents:WaitForChild("RebirthComplete")

-- Rebirth pad touch debounce
local rebirthDebounce = {}

-- Shared state set by init
local _playerBases = nil
local _brainrotOwner = nil
local _playerCollection = nil

function ProgressionSystem.init(playerBases, brainrotOwner, playerCollection)
	_playerBases = playerBases
	_brainrotOwner = brainrotOwner
	_playerCollection = playerCollection
end

function ProgressionSystem.addMoney(player, amount)
	local current = player:GetAttribute("Money") or 0
	player:SetAttribute("Money", math.max(0, current + amount))
end

function ProgressionSystem.getMoney(player)
	return player:GetAttribute("Money") or 0
end

function ProgressionSystem.getRebirthInfo(player)
	local count = player:GetAttribute("RebirthCount") or 0
	local multiplier = player:GetAttribute("MoneyMultiplier") or 1
	local nextCost = REBIRTH_COST
	return {
		count = count,
		multiplier = multiplier,
		nextCost = nextCost,
	}
end

-- Sets the MaxSlots attribute on the player based on baseData.maxSlots
function ProgressionSystem.updateMaxSlots(player)
	local baseData = _playerBases and _playerBases[player]
	local maxSlots = baseData and (baseData.maxSlots or 10) or 10
	player:SetAttribute("MaxSlots", maxSlots)
end

function ProgressionSystem.rebirth(player, playerBases, brainrotOwner, playerCollection)
	local money = ProgressionSystem.getMoney(player)
	local rebirthCount = player:GetAttribute("RebirthCount") or 0

	-- Validation: enough money
	if money < REBIRTH_COST then
		evtNotification:FireClient(
			player,
			"Need $" .. REBIRTH_COST .. " to rebirth! You have $" .. math.floor(money),
			Color3.fromRGB(220, 50, 50)
		)
		return
	end

	-- Validation: max rebirths not reached
	if rebirthCount >= MAX_REBIRTHS then
		evtNotification:FireClient(
			player,
			"You have reached the maximum of " .. MAX_REBIRTHS .. " rebirths!",
			Color3.fromRGB(220, 50, 50)
		)
		return
	end

	-- Remove all brainrots owned by this player from workspace
	local partsToRemove = {}
	for brainrotPart, owner in pairs(brainrotOwner) do
		if owner == player then
			table.insert(partsToRemove, brainrotPart)
		end
	end
	for _, part in ipairs(partsToRemove) do
		brainrotOwner[part] = nil
		part:Destroy()
	end

	-- Reset collection
	playerCollection[player] = {}

	-- Apply rebirth effects
	player:SetAttribute("Money", 0)
	local newRebirthCount = rebirthCount + 1
	player:SetAttribute("RebirthCount", newRebirthCount)

	-- Multiplier: 1 + (rebirthCount * 0.5), so each rebirth adds +50%
	local newMultiplier = 1 + (newRebirthCount * 0.5)
	player:SetAttribute("MoneyMultiplier", newMultiplier)

	-- Unlock floors based on rebirth count
	local currentRebirthCount = player:GetAttribute("RebirthCount") or 0
	local FLOOR_UNLOCK = {0, 1, 2, 4, 6}  -- same as GameConfig
	local targetFloors = 1
	for i = #FLOOR_UNLOCK, 1, -1 do
		if currentRebirthCount >= FLOOR_UNLOCK[i] then
			targetFloors = i
			break
		end
	end

	local baseData = _playerBases[player]
	if baseData and BaseSystem then
		local currentFloors = baseData.unlockedFloors or 1
		while currentFloors < targetFloors do
			BaseSystem.unlockNextFloor(player, _playerBases)
			currentFloors = baseData.unlockedFloors or 1
		end
	end

	-- Update MaxSlots for the new rebirth tier
	ProgressionSystem.updateMaxSlots(player)

	-- Spawn a proper starter brainrot via ShopSystem if available
	if ShopSystem then
		local commons = ShopSystem.getBrainrotsByRarity("Common")
		if commons and #commons > 0 then
			local baseDataForSpawn = playerBases[player]
			if baseDataForSpawn then
				local basePos = baseDataForSpawn.position
				local spawnPos = Vector3.new(basePos.X, basePos.Y + 3, basePos.Z)
				ShopSystem.spawnBrainrot(commons[1], spawnPos, player, brainrotOwner)
			end
		end
	end

	-- Fire events
	evtRebirthComplete:FireClient(player, newMultiplier)
	evtNotification:FireClient(
		player,
		"REBIRTH! You are now x" .. string.format("%.1f", newMultiplier) .. ". Income boosted!",
		Color3.fromRGB(255, 185, 0)
	)
end

function ProgressionSystem.startIncomeLoop(playerBases, brainrotOwner)
	task.spawn(function()
		while true do
			task.wait(INCOME_INTERVAL)

			for brainrotPart, owner in pairs(brainrotOwner) do
				if brainrotPart and brainrotPart.Parent and owner and owner.Parent then
					local income = brainrotPart:GetAttribute("IncomePerSecond") or 0
					if income > 0 then
						local mult = owner:GetAttribute("MoneyMultiplier") or 1
						local accum = brainrotPart:GetAttribute("AccumulatedMoney") or 0
						brainrotPart:SetAttribute("AccumulatedMoney", accum + income * mult)
					end
				end
			end
		end
	end)
end

function ProgressionSystem.setupRebirthPad(playerBases)
	-- Prefer the stored _playerBases from init; accept param for backward compatibility
	local bases = _playerBases or playerBases

	-- Pad placed at a distinct position in the shop area
	local padPosition = Vector3.new(0, 0.75, -20)

	local pad = Instance.new("Part")
	pad.Name = "RebirthPad"
	pad.Size = Vector3.new(12, 0.5, 12)
	pad.Color = Color3.fromRGB(60, 0, 120) -- dark purple
	pad.Material = Enum.Material.Neon
	pad.Anchored = true
	pad.CFrame = CFrame.new(padPosition)
	pad.CastShadow = false
	pad.Parent = Workspace

	-- Swirling visual: a slightly larger transparent ring on top
	local ring = Instance.new("Part")
	ring.Name = "RebirthPadRing"
	ring.Size = Vector3.new(14, 0.2, 14)
	ring.Color = Color3.fromRGB(120, 0, 200)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.5
	ring.Anchored = true
	ring.CastShadow = false
	ring.CFrame = CFrame.new(padPosition + Vector3.new(0, 0.4, 0))
	ring.Shape = Enum.PartType.Cylinder
	ring.Parent = Workspace

	-- Spin the ring continuously for a swirling effect
	task.spawn(function()
		local angle = 0
		while pad and pad.Parent do
			angle = angle + 1
			ring.CFrame = CFrame.new(padPosition + Vector3.new(0, 0.4, 0))
				* CFrame.Angles(0, math.rad(angle), 0)
			task.wait(0.03)
		end
	end)

	-- Label billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 220, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 220, 50)
	label.TextStrokeTransparency = 0
	label.Text = "REBIRTH\n$8,000 to reset + multiplier boost"
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	-- Touch detection with 3-second debounce
	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local userId = player.UserId
		if rebirthDebounce[userId] then return end

		rebirthDebounce[userId] = true
		task.delay(REBIRTH_PAD_DEBOUNCE_TIME, function()
			rebirthDebounce[userId] = nil
		end)

		ProgressionSystem.rebirth(player, _playerBases, _brainrotOwner, _playerCollection)
	end)
end

return ProgressionSystem
