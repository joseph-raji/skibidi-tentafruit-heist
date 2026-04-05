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

-- Large baseplate (tropical ground)
local baseplate = Instance.new("Part")
baseplate.Name       = "Baseplate"
baseplate.Size       = Vector3.new(700, 1, 700)
baseplate.Position   = Vector3.new(0, -1, 0)
baseplate.Anchored   = true
baseplate.BrickColor = BrickColor.new("Sand green")
baseplate.Material   = Enum.Material.Grass
baseplate.Parent     = workspace

-- Central island platform (raised slightly, where the shop is)
local islandCenter = Instance.new("Part")
islandCenter.Size        = Vector3.new(160, 2, 160)
islandCenter.Position    = Vector3.new(0, 0, 0)
islandCenter.Anchored    = true
islandCenter.BrickColor  = BrickColor.new("Bright orange")
islandCenter.Material    = Enum.Material.SmoothPlastic
islandCenter.TopSurface  = Enum.SurfaceType.Smooth
islandCenter.Parent      = workspace

-- Paths connecting center to each base position (one per base)
local BASE_POSITIONS = GameConfig.BASE_POSITIONS
for _, pos in ipairs(BASE_POSITIONS) do
	local dir      = Vector3.new(pos.X, 0, pos.Z).Unit
	local dist     = Vector3.new(pos.X, 0, pos.Z).Magnitude
	local midPoint = Vector3.new(pos.X / 2, 0.5, pos.Z / 2)

	local path = Instance.new("Part")
	path.CFrame    = CFrame.lookAt(midPoint, midPoint + dir)
	path.Size      = Vector3.new(8, 0.5, dist - 20)
	path.Anchored  = true
	path.BrickColor = BrickColor.new("Tan")
	path.Material  = Enum.Material.SmoothPlastic
	path.Parent    = workspace
end

-- Decorative palm trees around the map
local palmPositions = {
	Vector3.new(50, 0, 50),  Vector3.new(-50, 0, 50),
	Vector3.new(50, 0, -50), Vector3.new(-50, 0, -50),
	Vector3.new(70, 0, 0),   Vector3.new(-70, 0, 0),
	Vector3.new(0, 0, 70),   Vector3.new(0, 0, -70),
}
for _, treePos in ipairs(palmPositions) do
	-- Trunk
	local trunk = Instance.new("Part")
	trunk.Size       = Vector3.new(1.5, 12, 1.5)
	trunk.Position   = treePos + Vector3.new(0, 6, 0)
	trunk.Anchored   = true
	trunk.BrickColor = BrickColor.new("Reddish brown")
	trunk.Material   = Enum.Material.Wood
	trunk.Shape      = Enum.PartType.Cylinder
	trunk.Parent     = workspace
	-- Leaves (sphere on top)
	local leaves = Instance.new("Part")
	leaves.Shape      = Enum.PartType.Ball
	leaves.Size       = Vector3.new(8, 6, 8)
	leaves.Position   = treePos + Vector3.new(0, 13, 0)
	leaves.Anchored   = true
	leaves.BrickColor = BrickColor.new("Bright green")
	leaves.Material   = Enum.Material.Grass
	leaves.Parent     = workspace
end

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

-- ============================================================
-- 7. Build shop and rebirth structures
-- ============================================================
ShopSystem.createShopPads()
ProgressionSystem.setupRebirthPad(playerBases)
ItemsSystem.createItemsShop()

-- ============================================================
-- 8. Create the bat tool (shared template, cloned per player)
-- ============================================================
local batTool = CombatSystem.createBatTool()

-- ============================================================
-- 9. Start game loops
-- ============================================================
ProgressionSystem.startIncomeLoop(playerBases, brainrotOwner)

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

	-- Destroy the player's base
	if playerBases[player] then
		local folder = playerBases[player].folder
		if folder and folder.Parent then
			folder:Destroy()
		end
		playerBases[player] = nil
	end
	-- Reset base-related attributes to defaults
	player:SetAttribute("BaseIsLocked", false)

	-- Clean up collection
	playerCollection[player] = nil
end)
