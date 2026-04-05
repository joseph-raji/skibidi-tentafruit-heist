-- ShopSystem.lua
-- ModuleScript: Shop, gacha rolls, and brainrot spawning for Skibidi Tentafruit Heist

local RunService      = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotData = require(ReplicatedStorage.Modules.BrainrotData)
local GameConfig   = require(ReplicatedStorage.Modules.GameConfig)

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local NotificationEvent    = RemoteEvents:WaitForChild("Notification")
local CollectionUpdatedEvent = RemoteEvents:WaitForChild("CollectionUpdated")

local ShopSystem = {}

-- =========================================================================
-- Module-level state (set via init / setCarrying)
-- =========================================================================

local _playerBases      = {}
local _brainrotOwner    = {}
local _playerCollection = {}
local _carrying         = {}

local GACHA_COST = 150

-- =========================================================================
-- Rarity colors for UI labels
-- =========================================================================

local RARITY_COLOR = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(50,  200, 80),
	Rare      = Color3.fromRGB(60,  120, 255),
	Epic      = Color3.fromRGB(180, 0,   255),
	Legendary = Color3.fromRGB(255, 200, 0),
}

-- =========================================================================
-- Internal helpers
-- =========================================================================

local function isBeingCarried(brainrotPart)
	for _, carried in pairs(_carrying) do
		if carried == brainrotPart then
			return true
		end
	end
	return false
end

local function randomBasePosition(player)
	local baseInfo = _playerBases[player]
	if not baseInfo then
		return Vector3.new(0, 5, 0)
	end
	local basePos = baseInfo.position
	local offsetX = math.random(-20, 20)
	local offsetZ = math.random(-20, 20)
	return Vector3.new(basePos.X + offsetX, basePos.Y + 5, basePos.Z + offsetZ)
end

-- =========================================================================
-- Public: init
-- =========================================================================

function ShopSystem.init(playerBases, brainrotOwner, playerCollection)
	_playerBases      = playerBases
	_brainrotOwner    = brainrotOwner
	_playerCollection = playerCollection
end

function ShopSystem.setCarrying(carryingTable)
	_carrying = carryingTable
end

-- =========================================================================
-- Public: spawnBrainrot
-- =========================================================================

function ShopSystem.spawnBrainrot(brainrotData, position, owner, brainrotOwner)
	local part = Instance.new("Part")
	part.Name      = brainrotData.id
	part.Shape     = Enum.PartType.Ball
	part.Material  = Enum.Material.Neon
	part.BrickColor = brainrotData.color
	part.Size      = Vector3.new(brainrotData.size, brainrotData.size, brainrotData.size)
	part.Position  = position
	part.Anchored  = false
	part.CanCollide = true
	part.CastShadow = true
	part.Parent    = workspace

	-- Glow
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range      = 12
	light.Color      = brainrotData.glowColor
	light.Parent     = part

	-- Billboard GUI
	local billboard = Instance.new("BillboardGui")
	billboard.Size          = UDim2.new(0, 160, 0, 70)
	billboard.StudsOffset   = Vector3.new(0, brainrotData.size + 1, 0)
	billboard.AlwaysOnTop   = false
	billboard.LightInfluence = 0
	billboard.Parent        = part

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size            = UDim2.new(1, 0, 0.45, 0)
	nameLabel.Position        = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text            = brainrotData.name
	nameLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.TextScaled      = true
	nameLabel.Font            = Enum.Font.GothamBold
	nameLabel.Parent          = billboard

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Size            = UDim2.new(1, 0, 0.3, 0)
	incomeLabel.Position        = UDim2.new(0, 0, 0.45, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text            = "$" .. brainrotData.income .. "/s"
	incomeLabel.TextColor3      = Color3.fromRGB(100, 255, 100)
	incomeLabel.TextStrokeTransparency = 0.4
	incomeLabel.TextScaled      = true
	incomeLabel.Font            = Enum.Font.Gotham
	incomeLabel.Parent          = billboard

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size            = UDim2.new(1, 0, 0.25, 0)
	rarityLabel.Position        = UDim2.new(0, 0, 0.75, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text            = brainrotData.rarity
	rarityLabel.TextColor3      = RARITY_COLOR[brainrotData.rarity] or Color3.fromRGB(255, 255, 255)
	rarityLabel.TextStrokeTransparency = 0.4
	rarityLabel.TextScaled      = true
	rarityLabel.Font            = Enum.Font.GothamBold
	rarityLabel.Parent          = billboard

	-- Register ownership
	brainrotOwner[part] = owner

	-- Bobbing and spinning animation
	local baseY    = position.Y
	local timeOffset = math.random() * math.pi * 2
	local BOB_AMP   = 0.4
	local BOB_SPEED = 2
	local SPIN_SPEED = 0.6

	RunService.Heartbeat:Connect(function(dt)
		if not part or not part.Parent then return end
		if isBeingCarried(part) then return end

		local t = tick() + timeOffset
		local bobY  = math.sin(t * BOB_SPEED) * BOB_AMP
		local angle = (tick() * SPIN_SPEED) % (2 * math.pi)

		part.CFrame = CFrame.new(
			part.Position.X,
			baseY + bobY,
			part.Position.Z
		) * CFrame.Angles(0, angle, 0)
	end)

	return part
end

-- =========================================================================
-- Public: buyBrainrot
-- =========================================================================

function ShopSystem.buyBrainrot(player, brainrotId, playerBases, brainrotOwner, playerCollection)
	local data = BrainrotData.getById(brainrotId)
	if not data then
		warn("ShopSystem.buyBrainrot: unknown brainrotId", brainrotId)
		return false
	end

	if data.cost == nil then
		NotificationEvent:FireClient(player, "This brainrot can only be obtained from the GACHA!", Color3.fromRGB(255, 80, 80))
		return false
	end

	local currentMoney = player:GetAttribute("Money") or 0
	if currentMoney < data.cost then
		NotificationEvent:FireClient(player, "Not enough money! Need $" .. data.cost, Color3.fromRGB(255, 80, 80))
		return false
	end

	-- Deduct money
	player:SetAttribute("Money", currentMoney - data.cost)

	-- Spawn at player's base
	local spawnPos = randomBasePosition(player)
	ShopSystem.spawnBrainrot(data, spawnPos, player, brainrotOwner)

	-- Update collection
	if not playerCollection[player] then
		playerCollection[player] = {}
	end
	playerCollection[player][brainrotId] = (playerCollection[player][brainrotId] or 0) + 1

	-- Fire events
	CollectionUpdatedEvent:FireClient(player, playerCollection[player])
	NotificationEvent:FireClient(player, "You bought " .. data.name .. "!", Color3.fromRGB(100, 255, 100))

	return true
end

-- =========================================================================
-- Public: spinGacha
-- =========================================================================

function ShopSystem.spinGacha(player, playerBases, brainrotOwner, playerCollection)
	local currentMoney = player:GetAttribute("Money") or 0
	if currentMoney < GACHA_COST then
		NotificationEvent:FireClient(player, "Need $" .. GACHA_COST .. " for a GACHA spin!", Color3.fromRGB(255, 80, 80))
		return nil
	end

	-- Deduct cost
	player:SetAttribute("Money", currentMoney - GACHA_COST)

	-- Roll
	local result = BrainrotData.gachaRoll()

	-- Spawn at player's base
	local spawnPos = randomBasePosition(player)
	ShopSystem.spawnBrainrot(result, spawnPos, player, brainrotOwner)

	-- Update collection
	if not playerCollection[player] then
		playerCollection[player] = {}
	end
	playerCollection[player][result.id] = (playerCollection[player][result.id] or 0) + 1

	-- Fire events
	CollectionUpdatedEvent:FireClient(player, playerCollection[player])

	local rarityColor = RARITY_COLOR[result.rarity] or Color3.fromRGB(255, 255, 255)
	NotificationEvent:FireClient(
		player,
		"You got [" .. result.rarity .. "]: " .. result.name .. "!",
		rarityColor
	)

	return result
end

-- =========================================================================
-- Public: createShopPads
-- =========================================================================

function ShopSystem.createShopPads()
	-- Collect all brainrots that have a direct cost
	local buyable = {}
	for _, entry in ipairs(BrainrotData.list) do
		if entry.cost ~= nil then
			table.insert(buyable, entry)
		end
	end

	-- Shop floor
	local shopCenter = Vector3.new(0, 0, 0)

	local floor = Instance.new("Part")
	floor.Name      = "ShopFloor"
	floor.Anchored  = true
	floor.Size      = Vector3.new(70, 1, 70)
	floor.Position  = Vector3.new(shopCenter.X, shopCenter.Y, shopCenter.Z)
	floor.BrickColor = BrickColor.new("Deep orange")
	floor.Material  = Enum.Material.SmoothPlastic
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.Parent    = workspace

	-- "SHOP" overhead label
	local shopBillboard = Instance.new("BillboardGui")
	shopBillboard.Size        = UDim2.new(0, 300, 0, 80)
	shopBillboard.StudsOffset = Vector3.new(0, 8, 0)
	shopBillboard.AlwaysOnTop = false
	shopBillboard.Parent      = floor

	local shopLabel = Instance.new("TextLabel")
	shopLabel.Size            = UDim2.new(1, 0, 1, 0)
	shopLabel.BackgroundTransparency = 1
	shopLabel.Text            = "SHOP"
	shopLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
	shopLabel.TextStrokeTransparency = 0
	shopLabel.TextScaled      = true
	shopLabel.Font            = Enum.Font.GothamBold
	shopLabel.Parent          = shopBillboard

	-- Grid layout for buyable pads
	local PAD_SPACING = 10
	local count = #buyable
	local cols = math.ceil(math.sqrt(count))
	local rows = math.ceil(count / cols)

	local gridWidth  = (cols - 1) * PAD_SPACING
	local gridDepth  = (rows - 1) * PAD_SPACING
	local startX     = shopCenter.X - gridWidth / 2
	local startZ     = shopCenter.Z - gridDepth / 2 - 10  -- shifted back from gacha pad

	local padY = shopCenter.Y + 0.75

	-- Debounce table for pad touches
	local debounce = {}

	for i, entry in ipairs(buyable) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)

		local padX = startX + col * PAD_SPACING
		local padZ = startZ + row * PAD_SPACING

		local pad = Instance.new("Part")
		pad.Name      = "BuyPad_" .. entry.id
		pad.Anchored  = true
		pad.Size      = Vector3.new(8, 0.5, 8)
		pad.Position  = Vector3.new(padX, padY, padZ)
		pad.BrickColor = entry.color
		pad.Material  = Enum.Material.SmoothPlastic
		pad.TopSurface = Enum.SurfaceType.Smooth
		pad.Parent    = workspace

		-- Pad label
		local padBillboard = Instance.new("BillboardGui")
		padBillboard.Size        = UDim2.new(0, 160, 0, 70)
		padBillboard.StudsOffset = Vector3.new(0, 3, 0)
		padBillboard.AlwaysOnTop = false
		padBillboard.Parent      = pad

		local padNameLabel = Instance.new("TextLabel")
		padNameLabel.Size            = UDim2.new(1, 0, 0.5, 0)
		padNameLabel.Position        = UDim2.new(0, 0, 0, 0)
		padNameLabel.BackgroundTransparency = 1
		padNameLabel.Text            = entry.name
		padNameLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
		padNameLabel.TextStrokeTransparency = 0.3
		padNameLabel.TextScaled      = true
		padNameLabel.Font            = Enum.Font.GothamBold
		padNameLabel.Parent          = padBillboard

		local padCostLabel = Instance.new("TextLabel")
		padCostLabel.Size            = UDim2.new(1, 0, 0.5, 0)
		padCostLabel.Position        = UDim2.new(0, 0, 0.5, 0)
		padCostLabel.BackgroundTransparency = 1
		padCostLabel.Text            = "$" .. entry.cost
		padCostLabel.TextColor3      = Color3.fromRGB(255, 230, 80)
		padCostLabel.TextStrokeTransparency = 0.3
		padCostLabel.TextScaled      = true
		padCostLabel.Font            = Enum.Font.Gotham
		padCostLabel.Parent          = padBillboard

		-- Touch connection with 1s debounce
		local entryId = entry.id
		pad.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = game.Players:GetPlayerFromCharacter(character)
			if not player then return end
			if debounce[player] then return end

			debounce[player] = true
			ShopSystem.buyBrainrot(player, entryId, _playerBases, _brainrotOwner, _playerCollection)
			task.delay(1, function()
				debounce[player] = nil
			end)
		end)
	end

	-- -----------------------------------------------------------------------
	-- GACHA pad (rainbow cycling, front of shop)
	-- -----------------------------------------------------------------------

	local gachaPad = Instance.new("Part")
	gachaPad.Name      = "GachaPad"
	gachaPad.Anchored  = true
	gachaPad.Size      = Vector3.new(12, 0.5, 12)
	gachaPad.Position  = Vector3.new(0, padY, 20)
	gachaPad.BrickColor = BrickColor.new("Hot pink")
	gachaPad.Material  = Enum.Material.Neon
	gachaPad.TopSurface = Enum.SurfaceType.Smooth
	gachaPad.Parent    = workspace

	-- Rainbow glow light
	local gachaLight = Instance.new("PointLight")
	gachaLight.Brightness = 3
	gachaLight.Range      = 20
	gachaLight.Color      = Color3.fromRGB(255, 0, 128)
	gachaLight.Parent     = gachaPad

	-- Rainbow color cycling via Heartbeat
	RunService.Heartbeat:Connect(function()
		if not gachaPad or not gachaPad.Parent then return end
		local t        = tick() * 0.8
		local hue      = t % 1
		local r        = math.abs(math.sin(hue * math.pi))
		local g        = math.abs(math.sin((hue + 0.333) * math.pi))
		local b        = math.abs(math.sin((hue + 0.666) * math.pi))
		local c        = Color3.new(r, g, b)
		gachaPad.Color = c
		gachaLight.Color = c
	end)

	-- GACHA billboard
	local gachaBillboard = Instance.new("BillboardGui")
	gachaBillboard.Size        = UDim2.new(0, 220, 0, 90)
	gachaBillboard.StudsOffset = Vector3.new(0, 5, 0)
	gachaBillboard.AlwaysOnTop = false
	gachaBillboard.Parent      = gachaPad

	local gachaLabel = Instance.new("TextLabel")
	gachaLabel.Size            = UDim2.new(1, 0, 1, 0)
	gachaLabel.BackgroundTransparency = 1
	gachaLabel.Text            = "🎰 GACHA SPIN\n$150 per roll"
	gachaLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
	gachaLabel.TextStrokeTransparency = 0
	gachaLabel.TextScaled      = true
	gachaLabel.Font            = Enum.Font.GothamBold
	gachaLabel.Parent          = gachaBillboard

	-- GACHA touch with debounce
	local gachaDebounce = {}
	gachaPad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = game.Players:GetPlayerFromCharacter(character)
		if not player then return end
		if gachaDebounce[player] then return end

		gachaDebounce[player] = true
		ShopSystem.spinGacha(player, _playerBases, _brainrotOwner, _playerCollection)
		task.delay(1, function()
			gachaDebounce[player] = nil
		end)
	end)
end

return ShopSystem
