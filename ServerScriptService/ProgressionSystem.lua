-- ProgressionSystem.lua
-- ModuleScript: rebirth, income generation, and upgrades

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ProgressionSystem = {}

-- Config
local REBIRTH_COST = 10000
local REBIRTH_MULTIPLIER = 1.5
local MAX_REBIRTHS = 10
local INCOME_INTERVAL = 1
local REBIRTH_PAD_DEBOUNCE_TIME = 3

-- NOTE: Income per second is read from the "IncomePerSecond" attribute on each
-- brainrot part. ShopSystem.spawnBrainrot must set:
--   body:SetAttribute("IncomePerSecond", brainrotData.income)
-- on every spawned brainrot body part for income to be credited.

-- Starter brainrot spawned after a rebirth (Common tier)
local STARTER_BRAINROT_NAME = "Skibidi Toilet"
local STARTER_BRAINROT_COLOR = Color3.fromRGB(100, 200, 255)
local STARTER_BRAINROT_INCOME = 5

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

-- Spawns a starter brainrot inside the player's base after rebirth
local function spawnStarterBrainrot(player, playerBases, brainrotOwner, playerCollection)
	local baseData = playerBases[player]
	if not baseData then
		return
	end

	local basePos = baseData.position
	local spawnPos = Vector3.new(basePos.X, basePos.Y + 3, basePos.Z)

	local part = Instance.new("Part")
	part.Name = STARTER_BRAINROT_NAME
	part.Size = Vector3.new(4, 4, 4)
	part.Color = STARTER_BRAINROT_COLOR
	part.Material = Enum.Material.Neon
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CFrame = CFrame.new(spawnPos)

	-- Set income attribute so the income loop picks this part up
	part:SetAttribute("IncomePerSecond", STARTER_BRAINROT_INCOME)

	part.Parent = Workspace

	-- Register ownership
	brainrotOwner[part] = player

	-- Register in collection
	if not playerCollection[player] then
		playerCollection[player] = {}
	end
	playerCollection[player][STARTER_BRAINROT_NAME] = (playerCollection[player][STARTER_BRAINROT_NAME] or 0) + 1

	-- Billboard showing name and income rate
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 160, 0, 55)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = part

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.Text = STARTER_BRAINROT_NAME
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.Parent = billboard

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Size = UDim2.new(1, 0, 0.45, 0)
	incomeLabel.Position = UDim2.new(0, 0, 0.55, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	incomeLabel.TextStrokeTransparency = 0
	incomeLabel.Text = "$" .. STARTER_BRAINROT_INCOME .. "/s"
	incomeLabel.Font = Enum.Font.Gotham
	incomeLabel.TextScaled = true
	incomeLabel.Parent = billboard
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

	-- Spawn starter brainrot in their base
	spawnStarterBrainrot(player, playerBases, brainrotOwner, playerCollection)

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
		local tickCount = 0
		while true do
			task.wait(INCOME_INTERVAL)
			tickCount = tickCount + 1

			-- Accumulate income per owner in a temporary table to batch SetAttribute calls
			local incomeMap = {}

			for brainrotPart, owner in pairs(brainrotOwner) do
				if brainrotPart and brainrotPart.Parent and owner and owner.Parent then
					local income = brainrotPart:GetAttribute("IncomePerSecond") or 0
					if income > 0 then
						local mult = owner:GetAttribute("MoneyMultiplier") or 1
						incomeMap[owner] = (incomeMap[owner] or 0) + (income * mult)
					end
				end
			end

			for owner, totalIncome in pairs(incomeMap) do
				ProgressionSystem.addMoney(owner, totalIncome)
			end

			-- Every 10 seconds, notify each player of their income rate
			if tickCount % 10 == 0 then
				for player, earned in pairs(incomeMap) do
					evtNotification:FireClient(
						player,
						"💰 +$" .. math.floor(earned) .. " earned (earning $" .. math.floor(earned) .. "/s total)",
						Color3.fromRGB(100, 220, 100)
					)
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
	label.Text = "REBIRTH\n$10,000 to reset + multiplier boost"
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
