-- Main.server.lua
-- Script (ServerScriptService): Server orchestrator for Skibidi Tentafruit Heist
-- Initializes all systems, builds the map, wires RemoteEvents, and manages player lifecycle.

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- 1. RemoteEvents FIRST — modules WaitForChild these at load time
-- ============================================================
local RemoteEvents = Instance.new("Folder")
RemoteEvents.Name = "RemoteEvents"
RemoteEvents.Parent = ReplicatedStorage

local eventNames = {
	"BuyBrainrot",
	"SpinGacha",
	"Rebirth",
	"LockBase",
	"UnlockBase",
	"MoneyUpdated",
	"BrainrotStolen",
	"BrainrotClaimed",
	"RebirthComplete",
	"Notification",
	"CollectionUpdated",
	"OpenShop",
	"OpenPokedex",
}

for _, name in ipairs(eventNames) do
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = RemoteEvents
end

-- Convenience references
local CollectionUpdated = RemoteEvents:WaitForChild("CollectionUpdated")
local Notification      = RemoteEvents:WaitForChild("Notification")

-- ============================================================
-- 2. Shared data modules (ReplicatedStorage)
-- ============================================================
local Modules       = ReplicatedStorage:WaitForChild("Modules")
local BrainrotData  = require(Modules:WaitForChild("BrainrotData"))
local GameConfig    = require(Modules:WaitForChild("GameConfig"))

-- ============================================================
-- 3. Server system modules (ServerScriptService)
-- ============================================================
local StealSystem       = require(ServerScriptService:WaitForChild("StealSystem"))
local BaseSystem        = require(ServerScriptService:WaitForChild("BaseSystem"))
local ShopSystem        = require(ServerScriptService:WaitForChild("ShopSystem"))
local CombatSystem      = require(ServerScriptService:WaitForChild("CombatSystem"))
local ProgressionSystem = require(ServerScriptService:WaitForChild("ProgressionSystem"))
local ItemsSystem       = require(ServerScriptService:WaitForChild("ItemsSystem"))
local DataStore         = require(ServerScriptService:WaitForChild("DataStore"))

-- ============================================================
-- 4. Shared state tables
-- ============================================================
local playerBases      = {}   -- [Player] -> { floor, folder, position, lockShield, isLocked }
local brainrotOwner    = {}   -- [Part]   -> Player
local carrying         = {}   -- [Player] -> Part
local playerCollection = {}   -- [Player] -> { [brainrotId] = count }
local baseIndex        = 0

-- ============================================================
-- 5. Build the map
-- ============================================================

-- Green grass baseplate (300 x 280)
local baseplate = Instance.new("Part")
baseplate.Name       = "Baseplate"
baseplate.Size       = Vector3.new(300, 1, 280)
baseplate.Position   = Vector3.new(0, -1, 0)
baseplate.Anchored   = true
baseplate.BrickColor = BrickColor.new("Bright green")
baseplate.Material   = Enum.Material.Grass
baseplate.Parent     = workspace

-- Central dirt road running down the Z axis (20 studs wide, X=-10 to X=10)
local road = Instance.new("Part")
road.Name       = "CentralRoad"
road.Size       = Vector3.new(20, 0.5, 280)
road.Position   = Vector3.new(0, -0.25, 0)
road.Anchored   = true
road.BrickColor = BrickColor.new("Brown")
road.Material   = Enum.Material.SmoothPlastic
road.Parent     = workspace

-- Brown/dirt border strips along the left and right edges
local leftBorder = Instance.new("Part")
leftBorder.Name     = "LeftBorder"
leftBorder.Size     = Vector3.new(10, 0.5, 280)
leftBorder.Position = Vector3.new(-145, -0.25, 0)
leftBorder.Anchored = true
leftBorder.BrickColor = BrickColor.new("Brown")
leftBorder.Material = Enum.Material.SmoothPlastic
leftBorder.Parent   = workspace

local rightBorder = Instance.new("Part")
rightBorder.Name     = "RightBorder"
rightBorder.Size     = Vector3.new(10, 0.5, 280)
rightBorder.Position = Vector3.new(145, -0.25, 0)
rightBorder.Anchored = true
rightBorder.BrickColor = BrickColor.new("Brown")
rightBorder.Material = Enum.Material.SmoothPlastic
rightBorder.Parent   = workspace

-- Boundary water (visual only, large blue ring around the map)
local waterParts = {
	{ size = Vector3.new(700, 2, 50),  pos = Vector3.new(0,    -1.5,  375) },
	{ size = Vector3.new(700, 2, 50),  pos = Vector3.new(0,    -1.5, -375) },
	{ size = Vector3.new(50,  2, 700), pos = Vector3.new( 375, -1.5,    0) },
	{ size = Vector3.new(50,  2, 700), pos = Vector3.new(-375, -1.5,    0) },
}
for _, w in ipairs(waterParts) do
	local water = Instance.new("Part")
	water.Size         = w.size
	water.Position     = w.pos
	water.Anchored     = true
	water.BrickColor   = BrickColor.new("Cyan")
	water.Material     = Enum.Material.Water
	water.Transparency = 0.3
	water.Parent       = workspace
end

-- Atmosphere and sky
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Color   = Color3.fromRGB(199, 170, 120)
atmosphere.Glare   = 0.5
atmosphere.Haze    = 1.5
atmosphere.Parent  = game:GetService("Lighting")

Instance.new("Sky").Parent = game:GetService("Lighting")

-- ============================================================
-- 5b. Lighting
-- ============================================================
local Lighting = game:GetService("Lighting")
Lighting.Brightness    = 3
Lighting.ClockTime     = 14   -- afternoon
Lighting.FogEnd        = 1000
Lighting.GlobalShadows = true
Lighting.Ambient       = Color3.fromRGB(100, 100, 80)

-- ============================================================
-- 6. Initialize all systems
-- ============================================================
StealSystem.init(playerBases, brainrotOwner, carrying, playerCollection)
-- BaseSystem has no init function
ShopSystem.init(playerBases, brainrotOwner, playerCollection)
ShopSystem.setCarrying(carrying)
CombatSystem.init(carrying, playerBases, brainrotOwner)
ProgressionSystem.init(playerBases, brainrotOwner, playerCollection)
ItemsSystem.init(playerBases, carrying)

ProgressionSystem.setShopSystem(ShopSystem)
ShopSystem.setBaseSystem(BaseSystem)
ProgressionSystem.setBaseSystem(BaseSystem)

-- ============================================================
-- 7. Pre-build all 8 empty base plots so they are visible before players join
-- ============================================================
for _, pos in ipairs(GameConfig.BASE_POSITIONS) do
	BaseSystem.buildEmptyBase(pos)
end

-- ============================================================
-- 8. Build shop and rebirth structures
-- ============================================================
ShopSystem.createShopPads()
ProgressionSystem.setupRebirthPad(playerBases)
ItemsSystem.createItemsShop()

-- ============================================================
-- 9. Create the bat tool (shared template, cloned per player)
-- ============================================================
local batTool = CombatSystem.createBatTool()

-- ============================================================
-- 10. Start game loops
-- ============================================================
ProgressionSystem.startIncomeLoop(playerBases, brainrotOwner)
DataStore.setupAutoSave(brainrotOwner)

-- Heartbeat: move carried brainrots above carrier's head and detect claims
RunService.Heartbeat:Connect(function()
	StealSystem.onHeartbeat(playerBases, brainrotOwner, carrying, playerCollection)
end)

-- ============================================================
-- 10. RemoteEvent handlers (client -> server)
-- ============================================================

-- Buy a brainrot from the shop pad
RemoteEvents.BuyBrainrot.OnServerEvent:Connect(function(player, brainrotId)
	if not player or not brainrotId then return end
	ShopSystem.buyBrainrot(player, brainrotId, playerBases, brainrotOwner, playerCollection)
end)

-- Spin the gacha
RemoteEvents.SpinGacha.OnServerEvent:Connect(function(player)
	if not player then return end
	ShopSystem.spinGacha(player, playerBases, brainrotOwner, playerCollection)
end)

-- Rebirth (prestige)
RemoteEvents.Rebirth.OnServerEvent:Connect(function(player)
	if not player then return end
	ProgressionSystem.rebirth(player, playerBases, brainrotOwner, playerCollection)
end)

-- Lock base with a temporary shield
RemoteEvents.LockBase.OnServerEvent:Connect(function(player)
	if not player then return end
	BaseSystem.lockBase(player, playerBases)
end)

-- Open shop UI on the requesting client
RemoteEvents.OpenShop.OnServerEvent:Connect(function(player)
	RemoteEvents.OpenShop:FireClient(player)
end)

-- Open pokédex UI on the requesting client
RemoteEvents.OpenPokedex.OnServerEvent:Connect(function(player)
	RemoteEvents.OpenPokedex:FireClient(player)
end)

-- ============================================================
-- 11. Player lifecycle
-- ============================================================

Players.PlayerAdded:Connect(function(player)
	-- Default attributes
	player:SetAttribute("Money",               GameConfig.STARTER_MONEY)
	player:SetAttribute("RebirthCount",         0)
	player:SetAttribute("MoneyMultiplier",       1)
	player:SetAttribute("BaseIsLocked",       false)
	player:SetAttribute("IsCarrying",         false)
	player:SetAttribute("CarryingBrainrotName", "")

	-- Leaderstats (visible on Roblox leaderboard)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local moneyValue = Instance.new("IntValue")
	moneyValue.Name   = "Money"
	moneyValue.Value  = GameConfig.STARTER_MONEY
	moneyValue.Parent = leaderstats

	local rebirthsValue = Instance.new("IntValue")
	rebirthsValue.Name   = "Rebirths"
	rebirthsValue.Value  = 0
	rebirthsValue.Parent = leaderstats

	-- Load saved data and apply it
	local savedData = DataStore.loadPlayer(player)
	player:SetAttribute("Money", savedData.money)
	player:SetAttribute("RebirthCount", savedData.rebirths)
	player:SetAttribute("MoneyMultiplier", savedData.multiplier)
	moneyValue.Value = savedData.money
	rebirthsValue.Value = savedData.rebirths

	-- Keep leaderstats in sync with attributes
	player:GetAttributeChangedSignal("Money"):Connect(function()
		moneyValue.Value = player:GetAttribute("Money") or 0
	end)

	player:GetAttributeChangedSignal("RebirthCount"):Connect(function()
		rebirthsValue.Value = player:GetAttribute("RebirthCount") or 0
	end)

	-- Assign a base position (cycles through BASE_POSITIONS)
	baseIndex += 1
	local posIndex = ((baseIndex - 1) % #GameConfig.BASE_POSITIONS) + 1
	local pos = GameConfig.BASE_POSITIONS[posIndex]

	-- Claim the base slot (destroys the empty placeholder, builds the real base)
	BaseSystem.claimBase(player, pos, playerBases)

	-- Initialize collection
	playerCollection[player] = {}

	-- Update max slots based on loaded rebirth count
	ProgressionSystem.updateMaxSlots(player)

	-- Per-spawn setup: teleport and give bat
	local function onCharacterAdded(character)
		if not character then return end
		BaseSystem.teleportToBase(player, pos)
		CombatSystem.giveBatToPlayer(player, batTool)
	end

	player.CharacterAdded:Connect(onCharacterAdded)

	-- Handle character that may already be present (edge case for Studio testing)
	if player.Character then
		onCharacterAdded(player.Character)
	end

	-- Spawn brainrots after the base is ready
	task.wait(1.5)

	-- Verify player is still in game after the wait
	if not player or not player.Parent then return end
	if not playerBases[player] then return end

	if savedData and #savedData.brainrotIds > 0 then
		-- Player has saved brainrots, re-spawn them
		local BrainrotDataModule = require(Modules:WaitForChild("BrainrotData"))
		for _, brainrotId in ipairs(savedData.brainrotIds) do
			local brainrotDef = BrainrotDataModule.getById(brainrotId)
			if brainrotDef then
				local slotIndex, slotPos = BaseSystem.getNextSlot(player, playerBases)
				local fallbackY = pos.Y + 2.2 + brainrotDef.size / 2
				local spawnPos = slotPos and Vector3.new(slotPos.X, slotPos.Y + brainrotDef.size / 2, slotPos.Z) or Vector3.new(pos.X, fallbackY, pos.Z)
				ShopSystem.spawnBrainrot(brainrotDef, spawnPos, player, brainrotOwner, slotIndex)
				playerCollection[player][brainrotId] = (playerCollection[player][brainrotId] or 0) + 1
			end
		end
		CollectionUpdated:FireClient(player, playerCollection[player])
		Notification:FireClient(player, "Welcome back! Your brainrots have been restored.", Color3.fromRGB(0, 220, 255))
	else
		-- New player: give free starter
		local commons = BrainrotData.getByRarity("Common")
		if commons and #commons > 0 then
			local starterBrainrot = commons[1]
			local slotIndex, slotPos = BaseSystem.getNextSlot(player, playerBases)
			local fallbackY = pos.Y + 2.2 + starterBrainrot.size / 2
			local spawnPos = slotPos and Vector3.new(slotPos.X, slotPos.Y + starterBrainrot.size / 2, slotPos.Z) or Vector3.new(pos.X, fallbackY, pos.Z)
			ShopSystem.spawnBrainrot(starterBrainrot, spawnPos, player, brainrotOwner, slotIndex)

			playerCollection[player][starterBrainrot.id] = 1
			CollectionUpdated:FireClient(player, playerCollection[player])

			Notification:FireClient(
				player,
				"Welcome! You received a free " .. starterBrainrot.name .. "!",
				Color3.fromRGB(0, 220, 100)
			)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	-- Save player data before cleanup
	DataStore.savePlayer(player, brainrotOwner)

	-- Drop any brainrot the player was carrying so it stays in the world
	if carrying[player] then
		StealSystem.dropBrainrot(player, carrying)
	end
	-- Remove carrying table entry and reset related attributes
	carrying[player] = nil
	player:SetAttribute("IsCarrying",         false)
	player:SetAttribute("CarryingBrainrotName", "")

	-- Destroy all brainrots owned by this player
	for brainrot, owner in pairs(brainrotOwner) do
		if owner == player then
			if brainrot and brainrot.Parent then
				brainrot:Destroy()
			end
			brainrotOwner[brainrot] = nil
		end
	end

	-- Destroy the player's base and rebuild the empty placeholder
	if playerBases[player] then
		local basePos = playerBases[player].position
		local folder  = playerBases[player].folder
		if folder and folder.Parent then
			folder:Destroy()
		end
		playerBases[player] = nil
		-- Show the slot as available again
		BaseSystem.releaseBase(basePos)
	end
	-- Reset base-related attributes to defaults
	player:SetAttribute("BaseIsLocked", false)

	-- Clean up collection
	playerCollection[player] = nil
end)
