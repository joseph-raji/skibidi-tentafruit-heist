-- ProgressionSystem.lua
-- ModuleScript: rebirth, income generation, and upgrades

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ProgressionSystem = {}

-- Config
local REBIRTH_COST = 50
local REBIRTH_MULTIPLIER = 1.5
local MAX_REBIRTHS = 10
local INCOME_INTERVAL = 1
local REBIRTH_PAD_DEBOUNCE_TIME = 3

-- NOTE: Income per second is read from the "IncomePerSecond" attribute on each
-- skin part. ShopSystem.spawnSkin must set:
--   body:SetAttribute("IncomePerSecond", skinData.income)
-- on every spawned skin body part for income to be credited.

-- ShopSystem reference injected by Main
local ShopSystem = nil

function ProgressionSystem.setShopSystem(ss)
	ShopSystem = ss
end

-- Carrying table injected by Main so rebirth pad can detect carried skins
local _carrying = nil
function ProgressionSystem.setCarrying(t)
	_carrying = t
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
local _skinOwner = nil
local _playerCollection = nil

function ProgressionSystem.init(playerBases, skinOwner, playerCollection)
	_playerBases = playerBases
	_skinOwner = skinOwner
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
	local maxSlots = baseData and (baseData.maxSlots or 5) or 5
	player:SetAttribute("MaxSlots", maxSlots)
end

function ProgressionSystem.rebirth(player, playerBases, skinOwner, playerCollection)
	local money = ProgressionSystem.getMoney(player)
	local rebirthCount = player:GetAttribute("RebirthCount") or 0

	-- Validation: enough money
	if money < REBIRTH_COST then
		evtNotification:FireClient(
			player,
			"Il te faut " .. REBIRTH_COST .. "$ pour renaître ! Tu as " .. math.floor(money) .. "$",
			Color3.fromRGB(220, 50, 50)
		)
		return
	end

	-- Validation: max rebirths not reached
	if rebirthCount >= MAX_REBIRTHS then
		evtNotification:FireClient(
			player,
			"Tu as atteint le maximum de " .. MAX_REBIRTHS .. " renaissances !",
			Color3.fromRGB(220, 50, 50)
		)
		return
	end

	-- Remove all skins owned by this player from workspace
	local partsToRemove = {}
	for skinPart, owner in pairs(skinOwner) do
		if owner == player then
			table.insert(partsToRemove, skinPart)
		end
	end
	for _, part in ipairs(partsToRemove) do
		local slotIndex = part:GetAttribute("SlotIndex")
		if ShopSystem then
			ShopSystem.removePlate(part)
			if slotIndex then
				ShopSystem.releaseSlot(player, slotIndex)
			end
		end
		skinOwner[part] = nil
		local m = part.Parent
		if m and m:IsA("Model") then m:Destroy() else part:Destroy() end
	end

	-- Reset collection
	playerCollection[player] = {}

	-- Apply rebirth effects
	player:SetAttribute("Money", 5000)
	local newRebirthCount = rebirthCount + 1
	player:SetAttribute("RebirthCount", newRebirthCount)

	-- Multiplier: 1 + rebirthCount, so each rebirth adds +1×
	-- Example: rebirth 1 → 2x, rebirth 2 → 3x, rebirth 10 → 11x
	local newMultiplier = 1 + newRebirthCount
	player:SetAttribute("MoneyMultiplier", newMultiplier)

	-- Grant 1 additional slot per rebirth; BaseSystem.grantSlot handles floor unlocking
	if BaseSystem then
		local newTotal = BaseSystem.grantSlot(player, _playerBases)
		player:SetAttribute("MaxSlots", newTotal)
	end

	-- Fire events
	evtRebirthComplete:FireClient(player, newMultiplier)
	evtNotification:FireClient(
		player,
		"RENAISSANCE ! Revenus x" .. newMultiplier .. " !",
		Color3.fromRGB(255, 185, 0)
	)
end

function ProgressionSystem.startIncomeLoop(playerBases, skinOwner)
	task.spawn(function()
		while true do
			task.wait(INCOME_INTERVAL)

			for skinPart, owner in pairs(skinOwner) do
				if skinPart and skinPart.Parent and owner and owner.Parent then
					local income = skinPart:GetAttribute("IncomePerSecond") or 0
					if income > 0 then
						local mult = owner:GetAttribute("MoneyMultiplier") or 1
						local accum = skinPart:GetAttribute("AccumulatedMoney") or 0
						skinPart:SetAttribute("AccumulatedMoney", accum + income * mult)
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
	label.Text = "REBIRTH MACHINE\nCarry a skin here to sacrifice it!"
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	-- Touch detection: player must carry a skin to sacrifice for rebirth
	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local userId = player.UserId
		if rebirthDebounce[userId] then return end

		-- Check player is carrying a skin
		local skin = _carrying and _carrying[player]
		if not skin then
			evtNotification:FireClient(player, "Porte un brainrot ici pour le sacrifier et renaître !", Color3.fromRGB(255, 220, 50))
			return
		end

		rebirthDebounce[userId] = true
		task.delay(REBIRTH_PAD_DEBOUNCE_TIME, function()
			rebirthDebounce[userId] = nil
		end)

		-- Sacrifice the skin
		_carrying[player] = nil
		player:SetAttribute("IsCarrying", false)
		player:SetAttribute("CarryingSkinName", "")
		_skinOwner[skin] = nil
		skin.Anchored = true
		task.delay(0.3, function()
			if skin and skin.Parent then
				local m = skin.Parent
				if m and m:IsA("Model") then m:Destroy() else skin:Destroy() end
			end
		end)

		ProgressionSystem.rebirth(player, _playerBases, _skinOwner, _playerCollection)
	end)
end

return ProgressionSystem
