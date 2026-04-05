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
	local s = brainrotData.size  -- base size unit

	-- -----------------------------------------------------------------------
	-- Model container
	-- -----------------------------------------------------------------------
	local model = Instance.new("Model")
	model.Name = "BrainrotChar_" .. brainrotData.name
	model.Parent = workspace

	-- -----------------------------------------------------------------------
	-- Helper: weld partB to partA
	-- -----------------------------------------------------------------------
	local function weld(partA, partB)
		local w = Instance.new("WeldConstraint")
		w.Part0 = partA
		w.Part1 = partB
		w.Parent = partA
	end

	-- -----------------------------------------------------------------------
	-- Body (primary part — torso sphere)
	-- -----------------------------------------------------------------------
	local body = Instance.new("Part")
	body.Name       = "Body"
	body.Shape      = Enum.PartType.Ball
	body.Material   = Enum.Material.Neon
	body.BrickColor = brainrotData.color
	body.Size       = Vector3.new(s, s, s)
	body.CFrame     = CFrame.new(position)
	body.Anchored   = true
	body.CanCollide = true
	body.CastShadow = true
	body.Parent     = model
	model.PrimaryPart = body

	-- -----------------------------------------------------------------------
	-- Head (slightly smaller sphere, same color, positioned above body)
	-- -----------------------------------------------------------------------
	local headSize = s * 0.65
	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = brainrotData.color
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(position + Vector3.new(0, s * 0.82, 0))
	head.Anchored   = false
	head.CanCollide = false
	head.CastShadow = false
	head.Parent     = model
	weld(body, head)

	-- -----------------------------------------------------------------------
	-- Eyes: two white spheres with black dot pupils
	-- -----------------------------------------------------------------------
	local eyeSize   = headSize * 0.28
	local pupilSize = eyeSize * 0.45
	local eyeOffsetY  = headSize * 0.08
	local eyeOffsetZ  = headSize * 0.42
	local eyeOffsetX  = headSize * 0.22

	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name       = "Eye_" .. (side == -1 and "L" or "R")
		eye.Shape      = Enum.PartType.Ball
		eye.Material   = Enum.Material.SmoothPlastic
		eye.BrickColor = BrickColor.new("White")
		eye.Size       = Vector3.new(eyeSize, eyeSize, eyeSize)
		eye.CFrame     = CFrame.new(
			position
			+ Vector3.new(side * eyeOffsetX, s * 0.82 + eyeOffsetY, eyeOffsetZ)
		)
		eye.Anchored   = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent     = model
		weld(body, eye)

		local pupil = Instance.new("Part")
		pupil.Name       = "Pupil_" .. (side == -1 and "L" or "R")
		pupil.Shape      = Enum.PartType.Ball
		pupil.Material   = Enum.Material.SmoothPlastic
		pupil.BrickColor = BrickColor.new("Really black")
		pupil.Size       = Vector3.new(pupilSize, pupilSize, pupilSize)
		pupil.CFrame     = CFrame.new(
			position
			+ Vector3.new(side * eyeOffsetX, s * 0.82 + eyeOffsetY, eyeOffsetZ + eyeSize * 0.35)
		)
		pupil.Anchored   = false
		pupil.CanCollide = false
		pupil.CastShadow = false
		pupil.Parent     = model
		weld(body, pupil)
	end

	-- -----------------------------------------------------------------------
	-- Arms: two thin cylinder stubs on the sides, angled slightly downward
	-- -----------------------------------------------------------------------
	local armLength = s * 0.8
	local armThick  = s * 0.18
	local armOffsetY = s * 0.05

	for _, side in ipairs({ -1, 1 }) do
		local arm = Instance.new("Part")
		arm.Name       = "Arm_" .. (side == -1 and "L" or "R")
		arm.Shape      = Enum.PartType.Cylinder
		arm.Material   = Enum.Material.SmoothPlastic
		arm.BrickColor = brainrotData.color
		arm.Size       = Vector3.new(armLength, armThick, armThick)
		-- Cylinders extend along the X axis by default; offset out to the side
		arm.CFrame     = CFrame.new(
			position + Vector3.new(side * (s * 0.5 + armLength * 0.5), armOffsetY, 0)
		) * CFrame.Angles(0, 0, math.rad(side * 20))  -- tilt slightly downward
		arm.Anchored   = false
		arm.CanCollide = false
		arm.CastShadow = false
		arm.Parent     = model
		weld(body, arm)
	end

	-- -----------------------------------------------------------------------
	-- Leg stubs: two short cylinders below body
	-- -----------------------------------------------------------------------
	local legLength = s * 0.55
	local legThick  = s * 0.2
	local legOffsetX = s * 0.2

	for _, side in ipairs({ -1, 1 }) do
		local leg = Instance.new("Part")
		leg.Name       = "Leg_" .. (side == -1 and "L" or "R")
		leg.Shape      = Enum.PartType.Cylinder
		leg.Material   = Enum.Material.SmoothPlastic
		leg.BrickColor = brainrotData.color
		leg.Size       = Vector3.new(legThick, legLength, legThick)
		leg.CFrame     = CFrame.new(
			position + Vector3.new(side * legOffsetX, -(s * 0.5 + legLength * 0.5), 0)
		)
		leg.Anchored   = false
		leg.CanCollide = false
		leg.CastShadow = false
		leg.Parent     = model
		weld(body, leg)
	end

	-- -----------------------------------------------------------------------
	-- Glow (on body)
	-- -----------------------------------------------------------------------
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range      = 12
	light.Color      = brainrotData.glowColor
	light.Parent     = body

	-- -----------------------------------------------------------------------
	-- Billboard GUI (on body)
	-- Conveyor items show cost prominently.
	-- Owned items show income/rarity (cost is already paid).
	-- -----------------------------------------------------------------------
	local billboard = Instance.new("BillboardGui")
	billboard.StudsOffset   = Vector3.new(0, s + headSize + 1.2, 0)
	billboard.AlwaysOnTop   = false
	billboard.LightInfluence = 0
	billboard.Parent        = body

	if owner then
		-- Owned brainrot: 3-row billboard (name / income / rarity)
		billboard.Size = UDim2.new(0, 160, 0, 70)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size            = UDim2.new(1, 0, 0.38, 0)
		nameLabel.Position        = UDim2.new(0, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text            = brainrotData.name
		nameLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeTransparency = 0.4
		nameLabel.TextScaled      = true
		nameLabel.Font            = Enum.Font.GothamBold
		nameLabel.Parent          = billboard

		local incomeLabel = Instance.new("TextLabel")
		incomeLabel.Size            = UDim2.new(1, 0, 0.37, 0)
		incomeLabel.Position        = UDim2.new(0, 0, 0.38, 0)
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
	else
		-- Conveyor shop item: 4-row billboard with cost as the most prominent element
		billboard.Size = UDim2.new(0, 200, 0, 110)

		-- Row 1: name (white, bold)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size            = UDim2.new(1, 0, 0.22, 0)
		nameLabel.Position        = UDim2.new(0, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text            = brainrotData.name
		nameLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeTransparency = 0.4
		nameLabel.TextScaled      = true
		nameLabel.Font            = Enum.Font.GothamBold
		nameLabel.Parent          = billboard

		-- Row 2: cost (yellow, large — most prominent)
		local costLabel = Instance.new("TextLabel")
		costLabel.Size            = UDim2.new(1, 0, 0.36, 0)
		costLabel.Position        = UDim2.new(0, 0, 0.22, 0)
		costLabel.BackgroundTransparency = 1
		costLabel.Text            = "COST: " .. (brainrotData.cost and ("$" .. brainrotData.cost) or "GACHA")
		costLabel.TextColor3      = Color3.fromRGB(255, 220, 0)
		costLabel.TextStrokeTransparency = 0.2
		costLabel.TextScaled      = true
		costLabel.Font            = Enum.Font.GothamBold
		costLabel.Parent          = billboard

		-- Row 3: income (green, smaller)
		local incomeLabel = Instance.new("TextLabel")
		incomeLabel.Size            = UDim2.new(1, 0, 0.22, 0)
		incomeLabel.Position        = UDim2.new(0, 0, 0.58, 0)
		incomeLabel.BackgroundTransparency = 1
		incomeLabel.Text            = "+" .. brainrotData.income .. "$/s income"
		incomeLabel.TextColor3      = Color3.fromRGB(100, 255, 100)
		incomeLabel.TextStrokeTransparency = 0.4
		incomeLabel.TextScaled      = true
		incomeLabel.Font            = Enum.Font.Gotham
		incomeLabel.Parent          = billboard

		-- Row 4: rarity (rarity color)
		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size            = UDim2.new(1, 0, 0.20, 0)
		rarityLabel.Position        = UDim2.new(0, 0, 0.80, 0)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text            = brainrotData.rarity
		rarityLabel.TextColor3      = RARITY_COLOR[brainrotData.rarity] or Color3.fromRGB(255, 255, 255)
		rarityLabel.TextStrokeTransparency = 0.4
		rarityLabel.TextScaled      = true
		rarityLabel.Font            = Enum.Font.GothamBold
		rarityLabel.Parent          = billboard
	end

	-- -----------------------------------------------------------------------
	-- Register ownership on the body (PrimaryPart)
	-- -----------------------------------------------------------------------
	-- Register ownership (nil for conveyor shop items)
	if owner then
		brainrotOwner[body] = owner
		body:SetAttribute("IncomePerSecond", brainrotData.income)
		body:SetAttribute("BrainrotId", brainrotData.id)
		body:SetAttribute("BrainrotName", brainrotData.name)
	end

	-- -----------------------------------------------------------------------
	-- Income plaque — small sign planted at spawn position (only for owned brainrots)
	-- Shows name, income rate, and rarity on a wider board.
	-- -----------------------------------------------------------------------
	if owner then
		local plaque = Instance.new("Part")
		plaque.Name       = "IncomePlaque"
		plaque.Size       = Vector3.new(3, 1.5, 0.1)
		plaque.Position   = Vector3.new(position.X, position.Y - s * 0.3, position.Z + s * 0.9)
		plaque.Anchored   = true
		plaque.CanCollide = false
		plaque.BrickColor = BrickColor.new("Really black")
		plaque.Material   = Enum.Material.SmoothPlastic
		plaque.Parent     = workspace

		local sg = Instance.new("SurfaceGui")
		sg.Face   = Enum.NormalId.Front
		sg.Parent = plaque

		-- Top: brainrot name (white)
		local nameText = Instance.new("TextLabel")
		nameText.Size                  = UDim2.new(1, 0, 0.33, 0)
		nameText.Position              = UDim2.new(0, 0, 0, 0)
		nameText.BackgroundTransparency = 1
		nameText.Text                  = brainrotData.name
		nameText.TextScaled            = true
		nameText.Font                  = Enum.Font.GothamBold
		nameText.TextColor3            = Color3.fromRGB(255, 255, 255)
		nameText.Parent                = sg

		-- Middle: income (green, large)
		local incomeText = Instance.new("TextLabel")
		incomeText.Size                  = UDim2.new(1, 0, 0.40, 0)
		incomeText.Position              = UDim2.new(0, 0, 0.33, 0)
		incomeText.BackgroundTransparency = 1
		incomeText.Text                  = "$" .. brainrotData.income .. "/s"
		incomeText.TextScaled            = true
		incomeText.Font                  = Enum.Font.GothamBold
		incomeText.TextColor3            = Color3.fromRGB(100, 255, 100)
		incomeText.Parent                = sg

		-- Bottom: rarity (rarity color)
		local rarityText = Instance.new("TextLabel")
		rarityText.Size                  = UDim2.new(1, 0, 0.27, 0)
		rarityText.Position              = UDim2.new(0, 0, 0.73, 0)
		rarityText.BackgroundTransparency = 1
		rarityText.Text                  = brainrotData.rarity
		rarityText.TextScaled            = true
		rarityText.Font                  = Enum.Font.Gotham
		rarityText.TextColor3            = RARITY_COLOR[brainrotData.rarity] or Color3.fromRGB(255,255,255)
		rarityText.Parent                = sg

		-- Destroy plaque when brainrot is destroyed
		body.AncestryChanged:Connect(function()
			if not body.Parent then
				plaque:Destroy()
			end
		end)
	end

	-- -----------------------------------------------------------------------
	-- Bobbing and spinning animation
	-- -----------------------------------------------------------------------
	local baseY      = position.Y
	local timeOffset = math.random() * math.pi * 2
	local BOB_AMP    = 0.4
	local BOB_SPEED  = 2
	local SPIN_SPEED = 0.6

	RunService.Heartbeat:Connect(function(dt)
		if not body or not body.Parent then return end
		if isBeingCarried(body) then return end

		local t     = tick() + timeOffset
		local bobY  = math.sin(t * BOB_SPEED) * BOB_AMP
		local angle = (tick() * SPIN_SPEED) % (2 * math.pi)

		body.CFrame = CFrame.new(
			body.Position.X,
			baseY + bobY,
			body.Position.Z
		) * CFrame.Angles(0, angle, 0)
	end)

	return body
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
-- Public: createShopPads  (now a conveyor belt shop)
-- =========================================================================

-- How often each rarity tier appears on the belt (seconds between spawns)
local CONVEYOR_INTERVALS = {
	Common    = 4,
	Uncommon  = 10,
	Rare      = 22,
	Epic      = 50,
	Legendary = 120,
}

local BELT_LENGTH  = 80   -- studs long
local BELT_WIDTH   = 8    -- studs wide
local BELT_SPEED   = 7    -- studs per second
local BELT_Y       = 0.5  -- height
local BELT_START_X = -BELT_LENGTH / 2
local BELT_END_X   =  BELT_LENGTH / 2

-- Number of stripes and their spacing (studs apart)
local STRIPE_COUNT   = 8
local STRIPE_SPACING = BELT_LENGTH / STRIPE_COUNT

function ShopSystem.createShopPads()

	-- -----------------------------------------------------------------------
	-- Carpet / belt base
	-- -----------------------------------------------------------------------
	local belt = Instance.new("Part")
	belt.Name        = "ShopBelt"
	belt.Anchored    = true
	belt.Size        = Vector3.new(BELT_LENGTH, 0.6, BELT_WIDTH)
	belt.Position    = Vector3.new(0, BELT_Y, 0)
	belt.BrickColor  = BrickColor.new("Bright red")
	belt.Material    = Enum.Material.Fabric
	belt.TopSurface  = Enum.SurfaceType.Smooth
	belt.Parent      = workspace

	-- Belt stripes (decorative arrows showing direction)
	-- Stored so their positions can be animated each heartbeat.
	local stripes = {}
	for i = 0, STRIPE_COUNT - 1 do
		local stripe = Instance.new("Part")
		stripe.Anchored   = true
		stripe.Size       = Vector3.new(2, 0.05, BELT_WIDTH - 1)
		stripe.BrickColor = BrickColor.new("Bright orange")
		stripe.Material   = Enum.Material.Neon
		stripe.CanCollide = false
		stripe.Parent     = workspace
		stripes[i + 1] = stripe
	end

	-- Animate stripes to simulate belt movement
	local stripeOffset = 0
	RunService.Heartbeat:Connect(function(dt)
		stripeOffset = (stripeOffset + BELT_SPEED * dt) % STRIPE_SPACING
		for i, stripe in ipairs(stripes) do
			local baseX = BELT_START_X + (i - 1) * STRIPE_SPACING
			local x = baseX + stripeOffset
			-- Wrap around so stripes loop seamlessly within belt bounds
			if x > BELT_END_X then
				x = x - BELT_LENGTH
			end
			stripe.Position = Vector3.new(x, BELT_Y + 0.32, 0)
		end
	end)

	-- -----------------------------------------------------------------------
	-- Entry portal (glowing neon arch at belt start)
	-- -----------------------------------------------------------------------
	local function buildPortal(xPos, color)
		-- Left pillar
		local pillarL = Instance.new("Part")
		pillarL.Anchored   = true
		pillarL.Size       = Vector3.new(0.6, 10, 0.6)
		pillarL.Position   = Vector3.new(xPos, BELT_Y + 5, -BELT_WIDTH / 2 - 0.5)
		pillarL.BrickColor = BrickColor.new("Really black")
		pillarL.Material   = Enum.Material.Neon
		pillarL.CanCollide = false
		pillarL.Parent     = workspace

		-- Right pillar
		local pillarR = Instance.new("Part")
		pillarR.Anchored   = true
		pillarR.Size       = Vector3.new(0.6, 10, 0.6)
		pillarR.Position   = Vector3.new(xPos, BELT_Y + 5, BELT_WIDTH / 2 + 0.5)
		pillarR.BrickColor = BrickColor.new("Really black")
		pillarR.Material   = Enum.Material.Neon
		pillarR.CanCollide = false
		pillarR.Parent     = workspace

		-- Arch crossbar
		local arch = Instance.new("Part")
		arch.Anchored   = true
		arch.Size       = Vector3.new(0.6, 0.6, BELT_WIDTH + 2)
		arch.Position   = Vector3.new(xPos, BELT_Y + 10.3, 0)
		arch.BrickColor = BrickColor.new("Really black")
		arch.Material   = Enum.Material.Neon
		arch.CanCollide = false
		arch.Parent     = workspace

		-- Glow light on arch
		local archLight = Instance.new("PointLight")
		archLight.Brightness = 4
		archLight.Range      = 18
		archLight.Color      = color
		archLight.Parent     = arch

		-- Pulse the glow color over time
		RunService.Heartbeat:Connect(function()
			if not arch or not arch.Parent then return end
			local h   = (tick() * 0.4) % 1
			local c   = Color3.fromHSV(h, 0.9, 1)
			arch.Color       = c
			pillarL.Color    = c
			pillarR.Color    = c
			archLight.Color  = c
		end)
	end

	buildPortal(BELT_START_X - 1, Color3.fromRGB(0, 200, 255))
	buildPortal(BELT_END_X   + 1, Color3.fromRGB(255, 80, 200))

	-- SHOP sign above belt start
	local signPost = Instance.new("Part")
	signPost.Anchored   = true
	signPost.Size       = Vector3.new(0.3, 8, 0.3)
	signPost.Position   = Vector3.new(BELT_START_X - 2, BELT_Y + 4, 0)
	signPost.BrickColor = BrickColor.new("Dark orange")
	signPost.Material   = Enum.Material.SmoothPlastic
	signPost.CanCollide = false
	signPost.Parent     = workspace

	local signBoard = Instance.new("Part")
	signBoard.Anchored   = true
	signBoard.Size       = Vector3.new(12, 4, 0.3)
	signBoard.Position   = Vector3.new(BELT_START_X + 4, BELT_Y + 9, 0)
	signBoard.BrickColor = BrickColor.new("Really black")
	signBoard.Material   = Enum.Material.SmoothPlastic
	signBoard.CanCollide = false
	signBoard.Parent     = workspace

	local signGui = Instance.new("SurfaceGui")
	signGui.Face   = Enum.NormalId.Front
	signGui.Parent = signBoard
	local signLabel = Instance.new("TextLabel")
	signLabel.Size                   = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text                   = "🛒  BRAINROT SHOP\nHold E on one to buy!"
	signLabel.TextScaled             = true
	signLabel.Font                   = Enum.Font.GothamBold
	signLabel.TextColor3             = Color3.fromRGB(255, 220, 50)
	signLabel.Parent                 = signGui

	-- -----------------------------------------------------------------------
	-- Active conveyor brainrots (body part → true)
	-- -----------------------------------------------------------------------
	local conveyorItems = {}

	-- Move all conveyor brainrots each frame
	RunService.Heartbeat:Connect(function(dt)
		for body, _ in pairs(conveyorItems) do
			if not body or not body.Parent then
				conveyorItems[body] = nil
				continue
			end
			local newX = body.Position.X + BELT_SPEED * dt
			body.CFrame = CFrame.new(newX, body.Position.Y, body.Position.Z)
				* CFrame.Angles(0, tick() * 0.8, 0)
			if newX >= BELT_END_X then
				-- Reached end of belt: destroy the whole model
				local model = body.Parent
				conveyorItems[body] = nil
				if model and model:IsA("Model") then
					model:Destroy()
				elseif body.Parent then
					body:Destroy()
				end
			end
		end
	end)

	-- -----------------------------------------------------------------------
	-- Spawn loops — one per rarity tier, staggered so they don't all arrive
	-- at the same time
	-- -----------------------------------------------------------------------
	local rarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
	local buyDebounce = {}

	for idx, rarity in ipairs(rarityOrder) do
		local interval = CONVEYOR_INTERVALS[rarity]
		task.spawn(function()
			task.wait(idx * 1.5) -- stagger initial spawns
			while true do
				-- Pick a random brainrot of this rarity
				local options = BrainrotData.getByRarity(rarity)
				if options and #options > 0 then
					local chosen = options[math.random(1, #options)]
					local spawnPos = Vector3.new(
						BELT_START_X,
						BELT_Y + chosen.size / 2 + 0.3,
						0
					)

					-- Spawn visual without ownership (nil owner = no plaque, no steal events)
					local body = ShopSystem.spawnBrainrot(chosen, spawnPos, nil, _brainrotOwner)
					if body then
						conveyorItems[body] = true

						-- ProximityPrompt buy (hold E for 0.3s — prevents accidental purchase)
						local prompt = Instance.new("ProximityPrompt")
						prompt.ObjectText            = chosen.name
						prompt.ActionText            = chosen.cost and ("Buy - $" .. chosen.cost) or "Gacha Only"
						prompt.MaxActivationDistance = 8
						prompt.HoldDuration          = 0.3
						prompt.UIOffset              = Vector2.new(0, 50)
						prompt.Parent                = body

						prompt.Triggered:Connect(function(player)
							if not conveyorItems[body] then return end  -- already bought
							if buyDebounce[player] then return end

							if chosen.cost == nil then
								local RE = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents")
								RE:WaitForChild("Notification"):FireClient(player,
									chosen.name .. " is GACHA only!", Color3.fromRGB(255, 150, 0))
								return
							end

							local money = player:GetAttribute("Money") or 0
							if money < chosen.cost then
								local RE = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents")
								RE:WaitForChild("Notification"):FireClient(player,
									"Need $" .. chosen.cost .. "! You have $" .. money,
									Color3.fromRGB(255, 80, 80))
								return
							end

							buyDebounce[player] = true
							task.delay(2, function() buyDebounce[player] = nil end)

							player:SetAttribute("Money", money - chosen.cost)
							conveyorItems[body] = nil
							prompt:Destroy()

							-- Move to base
							local baseInfo = _playerBases[player]
							local dest = baseInfo
								and Vector3.new(
									baseInfo.position.X + math.random(-12, 12),
									baseInfo.position.Y + chosen.size / 2 + 1,
									baseInfo.position.Z + math.random(-12, 12))
								or Vector3.new(0, 5, 0)

							body.Anchored = true
							body.CFrame = CFrame.new(dest)
							_brainrotOwner[body] = player
							body:SetAttribute("IncomePerSecond", chosen.income)
							body:SetAttribute("BrainrotId", chosen.id)
							body:SetAttribute("BrainrotName", chosen.name)

							if not _playerCollection[player] then _playerCollection[player] = {} end
							_playerCollection[player][chosen.id] = (_playerCollection[player][chosen.id] or 0) + 1

							local RE = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents")
							RE:WaitForChild("CollectionUpdated"):FireClient(player, _playerCollection[player])
							RE:WaitForChild("Notification"):FireClient(player,
								"✅ Bought " .. chosen.name .. "! +" .. chosen.income .. "$/s",
								Color3.fromRGB(100, 255, 100))

							-- Spawn income plaque at destination
							local plaque = Instance.new("Part")
							plaque.Size       = Vector3.new(3, 1.5, 0.1)
							plaque.Position   = Vector3.new(dest.X, dest.Y - chosen.size * 0.3, dest.Z + chosen.size * 0.9)
							plaque.Anchored   = true
							plaque.CanCollide = false
							plaque.BrickColor = BrickColor.new("Really black")
							plaque.Material   = Enum.Material.SmoothPlastic
							plaque.Parent     = workspace

							local sg = Instance.new("SurfaceGui")
							sg.Face = Enum.NormalId.Front
							sg.Parent = plaque

							-- Name (top, white)
							local t0 = Instance.new("TextLabel")
							t0.Size = UDim2.new(1, 0, 0.33, 0)
							t0.Position = UDim2.new(0, 0, 0, 0)
							t0.BackgroundTransparency = 1
							t0.Text = chosen.name
							t0.TextScaled = true
							t0.Font = Enum.Font.GothamBold
							t0.TextColor3 = Color3.fromRGB(255, 255, 255)
							t0.Parent = sg

							-- Income (middle, green, large)
							local t1 = Instance.new("TextLabel")
							t1.Size = UDim2.new(1, 0, 0.40, 0)
							t1.Position = UDim2.new(0, 0, 0.33, 0)
							t1.BackgroundTransparency = 1
							t1.Text = "$" .. chosen.income .. "/s"
							t1.TextScaled = true
							t1.Font = Enum.Font.GothamBold
							t1.TextColor3 = Color3.fromRGB(100, 255, 100)
							t1.Parent = sg

							-- Rarity (bottom, rarity color)
							local t2 = Instance.new("TextLabel")
							t2.Size = UDim2.new(1, 0, 0.27, 0)
							t2.Position = UDim2.new(0, 0, 0.73, 0)
							t2.BackgroundTransparency = 1
							t2.Text = chosen.rarity
							t2.TextScaled = true
							t2.Font = Enum.Font.Gotham
							t2.TextColor3 = RARITY_COLOR[chosen.rarity] or Color3.fromRGB(255, 255, 255)
							t2.Parent = sg

							body.AncestryChanged:Connect(function()
								if not body.Parent then plaque:Destroy() end
							end)
						end)
					end
				end

				-- Wait with slight randomness so spawns feel organic
				task.wait(interval * (0.8 + math.random() * 0.4))
			end
		end)
	end

	-- -----------------------------------------------------------------------
	-- GACHA pad — beside the belt
	-- -----------------------------------------------------------------------
	local padY = BELT_Y + 0.25
	local gachaPad = Instance.new("Part")
	gachaPad.Name      = "GachaPad"
	gachaPad.Anchored  = true
	gachaPad.Size      = Vector3.new(12, 0.5, 12)
	gachaPad.Position  = Vector3.new(0, padY, 18)
	gachaPad.BrickColor = BrickColor.new("Hot pink")
	gachaPad.Material  = Enum.Material.Neon
	gachaPad.Parent    = workspace

	local gachaLight = Instance.new("PointLight")
	gachaLight.Brightness = 3
	gachaLight.Range      = 20
	gachaLight.Color      = Color3.fromRGB(255, 0, 128)
	gachaLight.Parent     = gachaPad

	RunService.Heartbeat:Connect(function()
		if not gachaPad or not gachaPad.Parent then return end
		local h   = (tick() * 0.5) % 1
		local c   = Color3.fromHSV(h, 1, 1)
		gachaPad.Color   = c
		gachaLight.Color = c
	end)

	local gachaBB = Instance.new("BillboardGui")
	gachaBB.Size        = UDim2.new(0, 240, 0, 90)
	gachaBB.StudsOffset = Vector3.new(0, 6, 0)
	gachaBB.Parent      = gachaPad
	local gachaLbl = Instance.new("TextLabel")
	gachaLbl.Size                   = UDim2.new(1, 0, 1, 0)
	gachaLbl.BackgroundTransparency = 1
	gachaLbl.Text                   = "🎰 GACHA SPIN\n$150 — any rarity!"
	gachaLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
	gachaLbl.TextStrokeTransparency = 0
	gachaLbl.TextScaled             = true
	gachaLbl.Font                   = Enum.Font.GothamBold
	gachaLbl.Parent                 = gachaBB

	local gachaDebounce = {}
	gachaPad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = game.Players:GetPlayerFromCharacter(character)
		if not player then return end
		if gachaDebounce[player] then return end
		gachaDebounce[player] = true
		task.delay(1, function() gachaDebounce[player] = nil end)
		ShopSystem.spinGacha(player, _playerBases, _brainrotOwner, _playerCollection)
	end)
end

return ShopSystem
