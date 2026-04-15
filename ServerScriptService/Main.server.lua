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
	"BuySkin",
	"SpinGacha",
	"Rebirth",
	"LockBase",
	"UnlockBase",
	"MoneyUpdated",
	"SkinStolen",
	"SkinClaimed",
	"RebirthComplete",
	"Notification",
	"CollectionUpdated",
	"OpenShop",
	"OpenPokedex",
	"BuyItem",
	"OpenFusion",
	"FuseRequest",
	"FuseOptions",
	"FuseChoose",
	"GachaResult",
	"SellSkin",
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
local SkinData  = require(Modules:WaitForChild("SkinData"))
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
local skinOwner    = {}   -- [Part]   -> Player
local carrying         = {}   -- [Player] -> Part
local playerCollection = {}   -- [Player] -> { [skinId] = count }
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

-- Boundary walls — tall Minecraft-style (gray stone body + green grass top)
-- N/S walls have a 24-stud gap centred at X=0 for the belt portal
do
	local H       = 35    -- wall body height (studs)
	local T       = 4     -- thickness
	local GAP     = 34    -- portal opening width (centred); wider than BELT_WIDTH=30 so carpet fits
	local SIDE_W  = (300 - GAP) / 2   -- 138 studs each side panel
	local STONE   = Color3.fromRGB(88, 90, 96)
	local GRASS   = Color3.fromRGB(80, 168, 60)
	local baseY   = H / 2 - 0.5   -- wall body centre Y (bottom sits on ground)
	local topY    = H - 0.5 + 1   -- grass strip centre Y

	local function wallPart(size, pos, color, mat)
		local w = Instance.new("Part")
		w.Anchored  = true; w.Size = size; w.Position = pos
		w.Color = color; w.Material = mat or Enum.Material.SmoothPlastic
		w.CanCollide = true; w.Parent = workspace
	end

	-- North (Z = -140): two stone sections + grass cap
	wallPart(Vector3.new(SIDE_W, H, T), Vector3.new(-(GAP/2 + SIDE_W/2), baseY, -140), STONE)
	wallPart(Vector3.new(SIDE_W, H, T), Vector3.new( (GAP/2 + SIDE_W/2), baseY, -140), STONE)
	wallPart(Vector3.new(300,    2, T), Vector3.new(0, topY, -140), GRASS, Enum.Material.Grass)

	-- South (Z = +140): same
	wallPart(Vector3.new(SIDE_W, H, T), Vector3.new(-(GAP/2 + SIDE_W/2), baseY,  140), STONE)
	wallPart(Vector3.new(SIDE_W, H, T), Vector3.new( (GAP/2 + SIDE_W/2), baseY,  140), STONE)
	wallPart(Vector3.new(300,    2, T), Vector3.new(0, topY,  140), GRASS, Enum.Material.Grass)

	-- West (X = -150): full stone + grass cap
	wallPart(Vector3.new(T, H, 280), Vector3.new(-150, baseY, 0), STONE)
	wallPart(Vector3.new(T, 2, 280), Vector3.new(-150, topY,  0), GRASS, Enum.Material.Grass)

	-- East (X = +150): full stone + grass cap
	wallPart(Vector3.new(T, H, 280), Vector3.new( 150, baseY, 0), STONE)
	wallPart(Vector3.new(T, 2, 280), Vector3.new( 150, topY,  0), GRASS, Enum.Material.Grass)
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
StealSystem.init(playerBases, skinOwner, carrying, playerCollection)
-- BaseSystem has no init function
ShopSystem.init(playerBases, skinOwner, playerCollection)
ShopSystem.setCarrying(carrying)
CombatSystem.init(carrying, playerBases, skinOwner)
ProgressionSystem.init(playerBases, skinOwner, playerCollection)
ItemsSystem.init(playerBases, carrying)

ProgressionSystem.setShopSystem(ShopSystem)
ProgressionSystem.setCarrying(carrying)
ShopSystem.setBaseSystem(BaseSystem)
ShopSystem.setStealSystem(StealSystem)
StealSystem.setShopSystem(ShopSystem)
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
ShopSystem.createFusionMachine()
-- Rebirth is handled via the HUD button; no physical pad needed
-- ItemsSystem.createItemsShop()  -- physical shop removed; buy equipment via the Shop UI button

-- ============================================================
-- 9. Create the bat tool (shared template, cloned per player)
-- ============================================================
local batTool = CombatSystem.createBatTool()

-- ============================================================
-- 10. Start game loops
-- ============================================================
ProgressionSystem.startIncomeLoop(playerBases, skinOwner)
DataStore.setupAutoSave(skinOwner)

-- Heartbeat: move carried skins above carrier's head and detect claims
RunService.Heartbeat:Connect(function()
	StealSystem.onHeartbeat(playerBases, skinOwner, carrying, playerCollection)
end)

-- ============================================================
-- 10. RemoteEvent handlers (client -> server)
-- ============================================================

-- Buy a skin from the shop pad
RemoteEvents.BuySkin.OnServerEvent:Connect(function(player, skinId)
	if not player or not skinId then return end
	ShopSystem.buySkin(player, skinId, playerBases, skinOwner, playerCollection)
end)

-- Spin the gacha
RemoteEvents.SpinGacha.OnServerEvent:Connect(function(player)
	if not player then return end
	ShopSystem.spinGacha(player, playerBases, skinOwner, playerCollection)
end)

-- Rebirth (prestige)
RemoteEvents.Rebirth.OnServerEvent:Connect(function(player)
	if not player then return end
	ProgressionSystem.rebirth(player, playerBases, skinOwner, playerCollection)
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

-- Buy an equipment item from the shop UI
RemoteEvents.BuyItem.OnServerEvent:Connect(function(player, itemId)
	if not player or not itemId then return end
	ItemsSystem.buyItem(player, itemId)
end)

-- Handle fusion request (client sends 2 skin IDs to fuse)
RemoteEvents.FuseRequest.OnServerEvent:Connect(function(player, id1, id2)
	if not player or not id1 or not id2 then return end
	ShopSystem.handleFuseRequest(player, id1, id2)
end)

-- Handle fusion choice (client picks 1 of 4 result options by index)
RemoteEvents.FuseChoose.OnServerEvent:Connect(function(player, choiceIndex)
	if not player or not choiceIndex then return end
	ShopSystem.handleFuseChoose(player, choiceIndex)
end)

-- Sell carried skin (player held F for 2 seconds)
RemoteEvents.SellSkin.OnServerEvent:Connect(function(player)
	if not player then return end
	StealSystem.sellSkin(player, playerBases, skinOwner, carrying, playerCollection)
end)

-- ============================================================
-- 11. Player lifecycle
-- ============================================================

local function onPlayerAdded(player)
	-- Default attributes
	player:SetAttribute("Money",               GameConfig.STARTER_MONEY)
	player:SetAttribute("RebirthCount",         0)
	player:SetAttribute("MoneyMultiplier",       1)
	player:SetAttribute("BaseIsLocked",       false)
	player:SetAttribute("IsCarrying",         false)
	player:SetAttribute("CarryingSkinName", "")

	-- Leaderstats (visible on Roblox leaderboard)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local moneyValue = Instance.new("IntValue")
	moneyValue.Name   = "Cash"
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

	-- Wire placement prompts on the empty slot plates for this base
	ShopSystem.initBasePlates(player)

	-- Initialize collection
	playerCollection[player] = {}

	-- Update max slots based on loaded rebirth count
	ProgressionSystem.updateMaxSlots(player)

	-- Per-spawn setup: teleport and give bat
	local function onCharacterAdded(character)
		if not character then return end
		BaseSystem.teleportToBase(player, pos)
		CombatSystem.giveBatToPlayer(player, batTool)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 24  -- 1.5x default (16)
		end
	end

	player.CharacterAdded:Connect(onCharacterAdded)

	-- Handle character that may already be present (edge case for Studio testing)
	if player.Character then
		onCharacterAdded(player.Character)
	end

	-- Spawn skins after the base is ready
	task.wait(1.5)

	-- Verify player is still in game after the wait
	if not player or not player.Parent then return end
	if not playerBases[player] then return end

	if savedData and #savedData.skinIds > 0 then
		-- Player has saved skins, re-spawn them
		local SkinDataModule = require(Modules:WaitForChild("SkinData"))
		for _, skinId in ipairs(savedData.skinIds) do
			local skinDef = SkinDataModule.getById(skinId)
			if skinDef then
				local slotIndex, slotPos = BaseSystem.getNextSlot(player, playerBases)
				local fallbackY = pos.Y + 2.2 + skinDef.size
				local spawnPos = slotPos and Vector3.new(slotPos.X, slotPos.Y + skinDef.size, slotPos.Z) or Vector3.new(pos.X, fallbackY, pos.Z)
				ShopSystem.spawnSkin(skinDef, spawnPos, player, skinOwner, slotIndex)
				playerCollection[player][skinId] = (playerCollection[player][skinId] or 0) + 1
			end
		end
		CollectionUpdated:FireClient(player, playerCollection[player])
		Notification:FireClient(player, "Bon retour ! Tes brainrots ont été restaurés.", Color3.fromRGB(0, 220, 255))
	else
		-- New player: give free starter
		local commons = SkinData.getByRarity("Common")
		if commons and #commons > 0 then
			local starterSkin = commons[1]
			local slotIndex, slotPos = BaseSystem.getNextSlot(player, playerBases)
			local fallbackY = pos.Y + 2.2 + starterSkin.size
			local spawnPos = slotPos and Vector3.new(slotPos.X, slotPos.Y + starterSkin.size, slotPos.Z) or Vector3.new(pos.X, fallbackY, pos.Z)
			ShopSystem.spawnSkin(starterSkin, spawnPos, player, skinOwner, slotIndex)

			playerCollection[player][starterSkin.id] = 1
			CollectionUpdated:FireClient(player, playerCollection[player])

			Notification:FireClient(
				player,
				"Bienvenue ! Tu as reçu " .. starterSkin.name .. " gratuitement !",
				Color3.fromRGB(0, 220, 100)
			)
		end
	end
end

-- Connect for future players and also handle any already-present players
-- (in Play Solo / Studio the local player may exist before this script fires)
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	-- Save player data before cleanup
	DataStore.savePlayer(player, skinOwner)

	-- Drop any skin the player was carrying so it stays in the world
	if carrying[player] then
		StealSystem.dropSkin(player, carrying)
	end
	-- Remove carrying table entry and reset related attributes
	carrying[player] = nil
	player:SetAttribute("IsCarrying",         false)
	player:SetAttribute("CarryingSkinName", "")

	-- Destroy all skins owned by this player
	for skin, owner in pairs(skinOwner) do
		if owner == player then
			if skin and skin.Parent then
				skin:Destroy()
			end
			skinOwner[skin] = nil
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
