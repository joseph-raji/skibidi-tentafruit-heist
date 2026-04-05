-- BaseSystem.lua
-- ModuleScript: handles player base creation, locking, unlocking, and boundary checks

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BaseSystem = {}

local BASE_SIZE = 44
local WALL_HEIGHT = 12
local WALL_THICKNESS = 1
local FLOOR_HEIGHT = 1
local LOCK_SHIELD_DURATION = 15
local LOCK_COOLDOWN = 30

-- Tracks cooldown per player (UserId → os.clock() when lock was last activated)
local lockCooldowns = {}

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local evtNotification = remoteEvents:WaitForChild("Notification")

local function makePart(parent, name, size, position, color, transparency, material, anchored, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.BrickColor = BrickColor.new(color)
	part.Color = part.BrickColor.Color
	part.Transparency = transparency or 0
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = anchored ~= false
	part.CanCollide = canCollide ~= false
	part.Parent = parent
	return part
end

function BaseSystem.createBase(player, position, playerBases)
	local folder = Instance.new("Folder")
	folder.Name = player.Name .. "_Base"
	folder.Parent = workspace

	-- Floor (green)
	local floor = makePart(
		folder,
		"Floor",
		Vector3.new(BASE_SIZE, FLOOR_HEIGHT, BASE_SIZE),
		Vector3.new(position.X, position.Y, position.Z),
		"Bright green",
		0,
		Enum.Material.SmoothPlastic
	)

	-- Name label on the floor surface
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize = Vector2.new(500, 500)
	surfaceGui.Parent = floor

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.Name
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Parent = surfaceGui

	local wallY = position.Y + FLOOR_HEIGHT / 2 + WALL_HEIGHT / 2
	local halfBase = BASE_SIZE / 2 - WALL_THICKNESS / 2

	-- Back wall (full width)
	makePart(
		folder,
		"WallBack",
		Vector3.new(BASE_SIZE, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(position.X, wallY, position.Z - halfBase),
		"Bright yellow",
		0.4,
		Enum.Material.SmoothPlastic
	)

	-- Left wall (full depth)
	makePart(
		folder,
		"WallLeft",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, BASE_SIZE),
		Vector3.new(position.X - halfBase, wallY, position.Z),
		"Bright yellow",
		0.4,
		Enum.Material.SmoothPlastic
	)

	-- Right wall (full depth)
	makePart(
		folder,
		"WallRight",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, BASE_SIZE),
		Vector3.new(position.X + halfBase, wallY, position.Z),
		"Bright yellow",
		0.4,
		Enum.Material.SmoothPlastic
	)

	-- Front wall: two segments with 8-stud gap in center
	-- Total front = BASE_SIZE studs. Gap = 8 studs centered → each segment = (BASE_SIZE - 8) / 2 = 18 studs
	local GAP = 8
	local segmentWidth = (BASE_SIZE - GAP) / 2  -- 18 studs each
	local frontZ = position.Z + halfBase

	-- Front wall left segment
	makePart(
		folder,
		"WallFrontLeft",
		Vector3.new(segmentWidth, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(position.X - (GAP / 2 + segmentWidth / 2), wallY, frontZ),
		"Bright yellow",
		0.4,
		Enum.Material.SmoothPlastic
	)

	-- Front wall right segment
	makePart(
		folder,
		"WallFrontRight",
		Vector3.new(segmentWidth, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(position.X + (GAP / 2 + segmentWidth / 2), wallY, frontZ),
		"Bright yellow",
		0.4,
		Enum.Material.SmoothPlastic
	)

	-- Register in playerBases
	playerBases[player] = {
		floor = floor,
		folder = folder,
		position = position,
		lockShield = nil,
		isLocked = false,
	}

	return folder
end

function BaseSystem.lockBase(player, playerBases)
	local baseData = playerBases[player]
	if not baseData then
		return
	end

	-- Cooldown check
	local now = os.clock()
	local lastLock = lockCooldowns[player.UserId]
	if lastLock and (now - lastLock) < LOCK_COOLDOWN then
		local remaining = math.ceil(LOCK_COOLDOWN - (now - lastLock))
		evtNotification:FireClient(player, "Base lock on cooldown (" .. remaining .. "s remaining)", Color3.fromRGB(255, 200, 50))
		return
	end

	-- Already locked
	if baseData.isLocked then
		evtNotification:FireClient(player, "Your base is already locked!", Color3.fromRGB(255, 200, 50))
		return
	end

	lockCooldowns[player.UserId] = now

	-- Create shield dome (large sphere)
	local basePos = baseData.position
	local shieldDiameter = BASE_SIZE + 10
	local shieldCenterY = basePos.Y + shieldDiameter / 2

	local shield = Instance.new("Part")
	shield.Name = "LockShield"
	shield.Shape = Enum.PartType.Ball
	shield.Size = Vector3.new(shieldDiameter, shieldDiameter, shieldDiameter)
	shield.CFrame = CFrame.new(basePos.X, shieldCenterY, basePos.Z)
	shield.Transparency = 0.6
	shield.Material = Enum.Material.Neon
	shield.Color = Color3.fromRGB(0, 255, 255)
	shield.CanCollide = false
	shield.Anchored = true
	shield.CastShadow = false
	shield.Parent = workspace

	baseData.lockShield = shield
	baseData.isLocked = true
	player:SetAttribute("BaseIsLocked", true)

	evtNotification:FireClient(player, "Base locked for " .. LOCK_SHIELD_DURATION .. " seconds!", Color3.fromRGB(0, 220, 255))

	-- Auto-unlock after duration
	task.delay(LOCK_SHIELD_DURATION, function()
		-- Only unlock if the shield is still the same one we created (not manually unlocked and re-locked)
		if baseData.lockShield == shield then
			BaseSystem.unlockBase(player, playerBases)
		end
	end)
end

function BaseSystem.unlockBase(player, playerBases)
	local baseData = playerBases[player]
	if not baseData then
		return
	end

	if baseData.lockShield and baseData.lockShield.Parent then
		baseData.lockShield:Destroy()
	end
	baseData.lockShield = nil
	baseData.isLocked = false
	player:SetAttribute("BaseIsLocked", false)
end

function BaseSystem.isInBase(position, baseData)
	if not baseData then
		return false
	end

	local basePos = baseData.position
	local halfBound = BASE_SIZE / 2

	local insideX = math.abs(position.X - basePos.X) < halfBound
	local insideZ = math.abs(position.Z - basePos.Z) < halfBound

	return insideX and insideZ
end

function BaseSystem.teleportToBase(player, position)
	task.delay(0.5, function()
		local character = player.Character
		if not character then
			return
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		root.CFrame = CFrame.new(position + Vector3.new(0, 6, 0))
	end)
end

return BaseSystem
