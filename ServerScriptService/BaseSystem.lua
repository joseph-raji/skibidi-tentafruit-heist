-- BaseSystem.lua
-- ModuleScript: handles player base creation, locking, unlocking, and boundary checks

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BaseSystem = {}

local BASE_SIZE = 44
local WALL_HEIGHT = 6
local WALL_THICKNESS = 0.3
local FLOOR_HEIGHT = 1
local LOCK_SHIELD_DURATION = 15
local LOCK_COOLDOWN = 30

local BASE_ACCENT_COLORS = {
	BrickColor.new("Bright blue"),
	BrickColor.new("Bright red"),
	BrickColor.new("Bright orange"),
	BrickColor.new("Bright violet"),
	BrickColor.new("Cyan"),
	BrickColor.new("Lime green"),
	BrickColor.new("Hot pink"),
	BrickColor.new("Gold"),
}

-- Tracks cooldown per player (UserId → os.clock() when lock was last activated)
local lockCooldowns = {}

-- Tracks how many bases have been created so far (for accent color cycling)
local baseCount = 0

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
	baseCount = baseCount + 1
	local accentColor = BASE_ACCENT_COLORS[((baseCount - 1) % #BASE_ACCENT_COLORS) + 1]

	local folder = Instance.new("Folder")
	folder.Name = player.Name .. "_Base"
	folder.Parent = workspace

	-- Floor (grass green)
	local floor = makePart(
		folder,
		"Floor",
		Vector3.new(BASE_SIZE, FLOOR_HEIGHT, BASE_SIZE),
		Vector3.new(position.X, position.Y, position.Z),
		"Bright green",
		0,
		Enum.Material.Grass
	)

	-- Border strips (4 sides, 2 studs wide, accent color)
	local borderHeight = FLOOR_HEIGHT
	local borderWidth = 2
	local halfBase = BASE_SIZE / 2

	-- Back border
	local backBorder = makePart(
		folder,
		"BorderBack",
		Vector3.new(BASE_SIZE, borderHeight, borderWidth),
		Vector3.new(position.X, position.Y, position.Z - halfBase + borderWidth / 2),
		"Earth green",
		0,
		Enum.Material.Grass
	)
	backBorder.BrickColor = accentColor
	backBorder.Color = accentColor.Color

	-- Front border
	local frontBorder = makePart(
		folder,
		"BorderFront",
		Vector3.new(BASE_SIZE, borderHeight, borderWidth),
		Vector3.new(position.X, position.Y, position.Z + halfBase - borderWidth / 2),
		"Earth green",
		0,
		Enum.Material.Grass
	)
	frontBorder.BrickColor = accentColor
	frontBorder.Color = accentColor.Color

	-- Left border
	local leftBorder = makePart(
		folder,
		"BorderLeft",
		Vector3.new(borderWidth, borderHeight, BASE_SIZE),
		Vector3.new(position.X - halfBase + borderWidth / 2, position.Y, position.Z),
		"Earth green",
		0,
		Enum.Material.Grass
	)
	leftBorder.BrickColor = accentColor
	leftBorder.Color = accentColor.Color

	-- Right border
	local rightBorder = makePart(
		folder,
		"BorderRight",
		Vector3.new(borderWidth, borderHeight, BASE_SIZE),
		Vector3.new(position.X + halfBase - borderWidth / 2, position.Y, position.Z),
		"Earth green",
		0,
		Enum.Material.Grass
	)
	rightBorder.BrickColor = accentColor
	rightBorder.Color = accentColor.Color

	-- Sign post at front-center of the base
	local postX = position.X
	local postZ = position.Z + halfBase - 1
	local postY = position.Y + FLOOR_HEIGHT / 2 + 2  -- 4-stud post, centered at Y+2
	local post = makePart(
		folder,
		"SignPost",
		Vector3.new(0.3, 4, 0.3),
		Vector3.new(postX, postY, postZ),
		"Really black",
		0,
		Enum.Material.Wood
	)

	-- Sign board at the top of the post
	local boardY = postY + 2 + 1  -- top of post + half board height
	local signBoard = makePart(
		folder,
		"SignBoard",
		Vector3.new(6, 2, 0.3),
		Vector3.new(postX, boardY, postZ),
		"Really black",
		0,
		Enum.Material.SmoothPlastic
	)

	-- SurfaceGui on the sign board
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize = Vector2.new(300, 100)
	surfaceGui.Parent = signBoard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.Name
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Parent = surfaceGui

	local wallY = position.Y + FLOOR_HEIGHT / 2 + WALL_HEIGHT / 2
	local halfWall = BASE_SIZE / 2 - WALL_THICKNESS / 2

	-- Back wall (wooden fence)
	makePart(
		folder,
		"WallBack",
		Vector3.new(BASE_SIZE, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(position.X, wallY, position.Z - halfWall),
		"Reddish brown",
		0,
		Enum.Material.Wood
	)

	-- Left wall (wooden fence)
	makePart(
		folder,
		"WallLeft",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, BASE_SIZE),
		Vector3.new(position.X - halfWall, wallY, position.Z),
		"Reddish brown",
		0,
		Enum.Material.Wood
	)

	-- Right wall (wooden fence)
	makePart(
		folder,
		"WallRight",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, BASE_SIZE),
		Vector3.new(position.X + halfWall, wallY, position.Z),
		"Reddish brown",
		0,
		Enum.Material.Wood
	)

	-- Front wall: two segments with 8-stud gap in center
	local GAP = 8
	local segmentWidth = (BASE_SIZE - GAP) / 2  -- 18 studs each
	local frontZ = position.Z + halfWall

	makePart(
		folder,
		"WallFrontLeft",
		Vector3.new(segmentWidth, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(position.X - (GAP / 2 + segmentWidth / 2), wallY, frontZ),
		"Reddish brown",
		0,
		Enum.Material.Wood
	)

	makePart(
		folder,
		"WallFrontRight",
		Vector3.new(segmentWidth, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(position.X + (GAP / 2 + segmentWidth / 2), wallY, frontZ),
		"Reddish brown",
		0,
		Enum.Material.Wood
	)

	-- Corner fence posts (4 corners, accent color)
	local postSize = Vector3.new(1, 8, 1)
	local cornerOffset = BASE_SIZE / 2
	local postY_corner = position.Y + FLOOR_HEIGHT / 2 + 4

	local corners = {
		Vector3.new(position.X - cornerOffset, postY_corner, position.Z - cornerOffset),
		Vector3.new(position.X + cornerOffset, postY_corner, position.Z - cornerOffset),
		Vector3.new(position.X - cornerOffset, postY_corner, position.Z + cornerOffset),
		Vector3.new(position.X + cornerOffset, postY_corner, position.Z + cornerOffset),
	}

	for i, cornerPos in ipairs(corners) do
		local cornerPost = Instance.new("Part")
		cornerPost.Name = "CornerPost" .. i
		cornerPost.Size = postSize
		cornerPost.CFrame = CFrame.new(cornerPos)
		cornerPost.BrickColor = accentColor
		cornerPost.Color = accentColor.Color
		cornerPost.Material = Enum.Material.Wood
		cornerPost.Anchored = true
		cornerPost.CanCollide = true
		cornerPost.Parent = folder
	end

	-- Ambient glow at floor level (accent color)
	local glowPart = Instance.new("Part")
	glowPart.Name = "GlowSource"
	glowPart.Size = Vector3.new(0.1, 0.1, 0.1)
	glowPart.CFrame = CFrame.new(position.X, position.Y + FLOOR_HEIGHT / 2 + 0.1, position.Z)
	glowPart.Anchored = true
	glowPart.CanCollide = false
	glowPart.Transparency = 1
	glowPart.Parent = folder

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0.5
	pointLight.Range = 30
	pointLight.Color = accentColor.Color
	pointLight.Parent = glowPart

	-- Register in playerBases
	playerBases[player] = {
		floor = floor,
		folder = folder,
		position = position,
		lockShield = nil,
		isLocked = false,
		accentColor = accentColor,
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

	-- Create hexagonal shield ring: 6 rectangular panels arranged in a circle
	local basePos = baseData.position
	local shieldFolder = Instance.new("Folder")
	shieldFolder.Name = "LockShield"
	shieldFolder.Parent = workspace

	local panelCount = 6
	local panelY = basePos.Y + FLOOR_HEIGHT / 2 + 4
	local radius = BASE_SIZE / 2 + 1

	for i = 1, panelCount do
		local angle = (2 * math.pi / panelCount) * (i - 1)
		local panelX = basePos.X + radius * math.cos(angle)
		local panelZ = basePos.Z + radius * math.sin(angle)

		local panel = Instance.new("Part")
		panel.Name = "ShieldPanel" .. i
		panel.Size = Vector3.new(BASE_SIZE + 2, 8, 1)
		panel.CFrame = CFrame.new(panelX, panelY, panelZ) * CFrame.Angles(0, angle + math.pi / 2, 0)
		panel.Anchored = true
		panel.CanCollide = false
		panel.BrickColor = BrickColor.new("Cyan")
		panel.Color = Color3.fromRGB(0, 255, 255)
		panel.Material = Enum.Material.Neon
		panel.Transparency = 0.5
		panel.CastShadow = false
		panel.Parent = shieldFolder
	end

	-- Central glow point
	local glowCenter = Instance.new("Part")
	glowCenter.Name = "ShieldGlow"
	glowCenter.Size = Vector3.new(0.1, 0.1, 0.1)
	glowCenter.CFrame = CFrame.new(basePos.X, panelY, basePos.Z)
	glowCenter.Anchored = true
	glowCenter.CanCollide = false
	glowCenter.Transparency = 1
	glowCenter.Parent = shieldFolder

	local shieldLight = Instance.new("PointLight")
	shieldLight.Brightness = 2
	shieldLight.Range = BASE_SIZE + 10
	shieldLight.Color = Color3.fromRGB(0, 255, 255)
	shieldLight.Parent = glowCenter

	baseData.lockShield = shieldFolder
	baseData.isLocked = true
	player:SetAttribute("BaseIsLocked", true)

	evtNotification:FireClient(player, "Base locked for " .. LOCK_SHIELD_DURATION .. " seconds!", Color3.fromRGB(0, 220, 255))

	-- Auto-unlock after duration
	task.delay(LOCK_SHIELD_DURATION, function()
		if baseData.lockShield == shieldFolder then
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

		-- Teleport ring effect
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.3, 8, 8)
		ring.CFrame = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Anchored = true
		ring.CanCollide = false
		ring.BrickColor = BrickColor.new("Cyan")
		ring.Material = Enum.Material.Neon
		ring.Parent = workspace

		task.spawn(function()
			for i = 1, 10 do
				task.wait(0.05)
				ring.Size = ring.Size + Vector3.new(0, 2, 2)
				ring.Transparency = i / 10
			end
			ring:Destroy()
		end)

		root.CFrame = CFrame.new(position + Vector3.new(0, 6, 0))
	end)
end

return BaseSystem
