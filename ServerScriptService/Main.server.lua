-- Main.server.lua
-- Script (ServerScriptService): Server orchestrator for Skibidi Tentafruit Heist
-- Initializes all systems, builds the map, wires RemoteEvents, and manages player lifecycle.

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- 1. Shared data modules (ReplicatedStorage)
-- ============================================================
local Modules       = ReplicatedStorage:WaitForChild("Modules")
local BrainrotData  = require(Modules:WaitForChild("BrainrotData"))
local GameConfig    = require(Modules:WaitForChild("GameConfig"))

-- ============================================================
-- 2. Server system modules (ServerScriptService)
-- ============================================================
local StealSystem       = require(ServerScriptService:WaitForChild("StealSystem"))
local BaseSystem        = require(ServerScriptService:WaitForChild("BaseSystem"))
local ShopSystem        = require(ServerScriptService:WaitForChild("ShopSystem"))
local CombatSystem      = require(ServerScriptService:WaitForChild("CombatSystem"))
local ProgressionSystem = require(ServerScriptService:WaitForChild("ProgressionSystem"))

-- ============================================================
-- 3. RemoteEvents folder + all events
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

-- Convenience references to frequently-fired events
local CollectionUpdated = RemoteEvents:WaitForChild("CollectionUpdated")
local Notification      = RemoteEvents:WaitForChild("Notification")

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

-- Baseplate
local baseplate = Instance.new("Part")
baseplate.Name        = "Baseplate"
baseplate.Size        = Vector3.new(600, 1, 600)
baseplate.Position    = Vector3.new(0, -1, 0)
baseplate.Anchored    = true
baseplate.BrickColor  = BrickColor.new("Medium stone grey")
baseplate.Material    = Enum.Material.SmoothPlastic
baseplate.Parent      = workspace

-- ============================================================
-- 6. Initialize all systems
-- ============================================================
StealSystem.init(playerBases, brainrotOwner, carrying, playerCollection)
BaseSystem.init(playerBases)
ShopSystem.init(playerBases, brainrotOwner, playerCollection)
ShopSystem.setCarrying(carrying)
CombatSystem.init(carrying, playerBases, brainrotOwner)
ProgressionSystem.init(playerBases, brainrotOwner, playerCollection)

-- ============================================================
-- 7. Build shop and rebirth structures
-- ============================================================
ShopSystem.createShopPads()
ProgressionSystem.setupRebirthPad()

-- ============================================================
-- 8. Create the bat tool (shared template, cloned per player)
-- ============================================================
local batTool = CombatSystem.createBatTool()

-- ============================================================
-- 9. Start game loops
-- ============================================================
ProgressionSystem.startIncomeLoop(brainrotOwner)

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

-- ============================================================
-- 11. Player lifecycle
-- ============================================================

Players.PlayerAdded:Connect(function(player)
	-- Default attributes
	player:SetAttribute("Money",               100)
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
	moneyValue.Value  = 100
	moneyValue.Parent = leaderstats

	local rebirthsValue = Instance.new("IntValue")
	rebirthsValue.Name   = "Rebirths"
	rebirthsValue.Value  = 0
	rebirthsValue.Parent = leaderstats

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

	-- Create the base plot
	BaseSystem.createBase(player, pos, playerBases)

	-- Initialize collection
	playerCollection[player] = {}

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

	-- Spawn a free starter brainrot after the base is ready
	task.wait(1.5)

	-- Verify player is still in game after the wait
	if not player or not player.Parent then return end
	if not playerBases[player] then return end

	local commons = BrainrotData.getByRarity("Common")
	if commons and #commons > 0 then
		local starterBrainrot = commons[1]
		ShopSystem.spawnBrainrot(starterBrainrot, pos, player, brainrotOwner)

		playerCollection[player][starterBrainrot.id] = 1
		CollectionUpdated:FireClient(player, playerCollection[player])

		Notification:FireClient(
			player,
			"Welcome! You received a free " .. starterBrainrot.name .. "!",
			Color3.fromRGB(0, 220, 100)
		)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	-- Drop any brainrot the player was carrying so it stays in the world
	if carrying[player] then
		StealSystem.dropBrainrot(player, carrying)
	end

	-- Destroy all brainrots owned by this player
	for brainrot, owner in pairs(brainrotOwner) do
		if owner == player then
			if brainrot and brainrot.Parent then
				brainrot:Destroy()
			end
			brainrotOwner[brainrot] = nil
		end
	end

	-- Destroy the player's base
	if playerBases[player] then
		local folder = playerBases[player].folder
		if folder and folder.Parent then
			folder:Destroy()
		end
		playerBases[player] = nil
	end

	-- Clean up collection
	playerCollection[player] = nil
end)
