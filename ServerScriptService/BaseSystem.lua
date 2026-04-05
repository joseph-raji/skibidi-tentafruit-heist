-- BaseSystem.lua
-- ModuleScript: handles player base creation, locking, unlocking, and boundary checks

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BaseSystem = {}

-- ============================================================
-- Constants
-- ============================================================

local BASE_SIZE        = 50    -- plot footprint (square)
local BUILDING_DEPTH   = 34   -- along depth axis (X for left/right houses)
local BUILDING_WIDTH   = 28   -- along Z axis
local WALL_HEIGHT      = 10   -- wall height per floor
local FLOOR_THICKNESS  = 2    -- floor slab thickness
local ROOF_OVERHANG    = 3    -- roof overhang on each side
local ROOF_THICKNESS   = 1.5
local YARD_DEPTH       = 14   -- green area between building front and plot edge toward road
local FLOOR_HEIGHT_STEP = 12  -- Y distance between each floor's ground level

local WALL_THICKNESS   = 1
local ENTRANCE_GAP     = 12   -- width of open entrance in front wall

local MAX_FLOORS       = 5
local SLOTS_PER_FLOOR  = 10   -- 5 left + 5 right

-- Neon red bars on front face
local NEON_BAR_COUNT = 5
local NEON_BAR_W     = 2
local NEON_BAR_H     = 7
local NEON_BAR_D     = 0.5

-- Shield / lock
local LOCK_SHIELD_DURATION = 15
local LOCK_COOLDOWN        = 30

-- ============================================================
-- Module-level state
-- ============================================================

local lockCooldowns = {}

local remoteEvents   = ReplicatedStorage:WaitForChild("RemoteEvents")
local evtNotification = remoteEvents:WaitForChild("Notification")

-- ============================================================
-- Helper: create a basic anchored Part
-- ============================================================

local function makePart(parent, name, size, cframe, color3, transparency, material, canCollide)
	local part = Instance.new("Part")
	part.Name        = name
	part.Size        = size
	part.CFrame      = cframe
	part.Color       = color3
	part.Transparency = transparency or 0
	part.Material    = material or Enum.Material.SmoothPlastic
	part.Anchored    = true
	part.CanCollide  = canCollide ~= false
	part.CastShadow  = true
	part.Parent      = parent
	return part
end

-- ============================================================
-- Helper: getFaceSign
-- Houses at X<0 face +X (toward road), houses at X>0 face -X
-- ============================================================

local function getFaceSign(pos)
	if pos.X < 0 then
		return 1
	elseif pos.X > 0 then
		return -1
	else
		return 0  -- edge case, face +Z
	end
end

-- ============================================================
-- Pre-compute all 50 slot positions (5 floors x 10 slots)
-- and their matching pressure plate positions.
--
-- Layout per floor:
--   5 rows, back-to-front, along depth axis: rowOffsets = {-12, -6, 0, 6, 12}
--   2 sides along Z: leftZ = pos.Z - 9,  rightZ = pos.Z + 9
--   Slots 1-5:  left side  (rows 1-5, back=1 front=5)
--   Slots 6-10: right side (rows 1-5)
--
-- Pressure plates sit between brainrot and aisle:
--   Left plate:  Z = pos.Z - 4.5
--   Right plate: Z = pos.Z + 4.5
-- ============================================================

local ROW_OFFSETS = {-16, -8, 0, 8, 16}  -- 8-stud spacing prevents visual crowding

local function computeAllSlotPositions(pos)
	local faceSign = getFaceSign(pos)
	-- Building center along depth axis is 6 studs inward from plot center
	local bCX = pos.X + faceSign * (-6)

	local leftZ  = pos.Z - 11   -- pushed further from aisle to avoid brainrot/plate overlap
	local rightZ = pos.Z + 11

	local leftPlateZ  = pos.Z - 6   -- plate sits in the aisle, clear of the brainrot body
	local rightPlateZ = pos.Z + 6

	local slotPositions  = {}
	local platePositions = {}

	for floorIndex = 1, MAX_FLOORS do
		local floorY = pos.Y + 5 + (floorIndex - 1) * FLOOR_HEIGHT_STEP

		for row = 1, 5 do
			local rowX = bCX + faceSign * ROW_OFFSETS[row]

			-- Slot on left side (global slot index within this floor: row, left=1..5)
			local leftSlotGlobal  = (floorIndex - 1) * SLOTS_PER_FLOOR + row
			-- Slot on right side (right=6..10 within this floor)
			local rightSlotGlobal = (floorIndex - 1) * SLOTS_PER_FLOOR + 5 + row

			slotPositions[leftSlotGlobal]  = Vector3.new(rowX, floorY, leftZ)
			slotPositions[rightSlotGlobal] = Vector3.new(rowX, floorY, rightZ)

			platePositions[leftSlotGlobal]  = Vector3.new(rowX, floorY, leftPlateZ)
			platePositions[rightSlotGlobal] = Vector3.new(rowX, floorY, rightPlateZ)
		end
	end

	return slotPositions, platePositions
end

-- ============================================================
-- Build the ground-floor house structure
-- ============================================================

local function buildGroundFloor(folder, pos, faceSign)
	local FOUNDATION_COLOR     = Color3.fromRGB(80,  80,  80)
	local WALL_COLOR           = Color3.fromRGB(130, 130, 135)
	local ROOF_COLOR           = Color3.fromRGB(190, 190, 195)
	local INTERIOR_FLOOR_COLOR = Color3.fromRGB(60,  60,  60)
	local NEON_RED             = Color3.fromRGB(255, 30,  30)
	local GRASS_COLOR          = Color3.fromRGB(106, 127, 63)
	local YARD_COLOR           = Color3.fromRGB(90,  140, 50)

	-- Plot ground slab
	makePart(
		folder, "PlotGround",
		Vector3.new(BASE_SIZE, 1, BASE_SIZE),
		CFrame.new(pos.X, pos.Y - 0.5, pos.Z),
		GRASS_COLOR, 0, Enum.Material.Grass, true
	)

	-- Building center: bCX is along X (depth axis), pos.Z is the Z center
	local bCX = pos.X + faceSign * (-6)

	-- Foundation (dark grey SmoothPlastic, covers building footprint, 2 studs tall)
	-- The foundation sits just above plot ground level
	local foundBaseY  = pos.Y  -- top of plot ground
	local foundTopY   = foundBaseY + FLOOR_THICKNESS
	local foundCenterY = foundBaseY + FLOOR_THICKNESS / 2
	makePart(
		folder, "Foundation",
		Vector3.new(BUILDING_DEPTH, FLOOR_THICKNESS, BUILDING_WIDTH),
		CFrame.new(bCX, foundCenterY, pos.Z),
		FOUNDATION_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Interior floor (dark grey, sits on top of foundation)
	makePart(
		folder, "InteriorFloor",
		Vector3.new(BUILDING_DEPTH, 0.2, BUILDING_WIDTH),
		CFrame.new(bCX, foundTopY + 0.1, pos.Z),
		INTERIOR_FLOOR_COLOR, 0, Enum.Material.SmoothPlastic, false
	)

	-- Walls Y center: foundTopY + WALL_HEIGHT/2
	local wallY    = foundTopY + WALL_HEIGHT / 2
	local halfDepth = BUILDING_DEPTH / 2
	local halfWidth = BUILDING_WIDTH / 2

	-- Back wall (opposite side from road)
	-- Back is away from road. For faceSign=+1 (house at X<0, faces +X), back is at lower X.
	-- Back wall center X = bCX - faceSign * halfDepth
	local backWallX = bCX - faceSign * halfDepth
	makePart(
		folder, "WallBack",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, BUILDING_WIDTH),
		CFrame.new(backWallX, wallY, pos.Z),
		WALL_COLOR, 0, Enum.Material.Concrete, true
	)

	-- Left side wall (full depth, along X axis)
	-- Left side: Z = pos.Z - halfWidth
	makePart(
		folder, "WallLeft",
		Vector3.new(BUILDING_DEPTH, WALL_HEIGHT, WALL_THICKNESS),
		CFrame.new(bCX, wallY, pos.Z - halfWidth),
		WALL_COLOR, 0, Enum.Material.Concrete, true
	)

	-- Right side wall
	makePart(
		folder, "WallRight",
		Vector3.new(BUILDING_DEPTH, WALL_HEIGHT, WALL_THICKNESS),
		CFrame.new(bCX, wallY, pos.Z + halfWidth),
		WALL_COLOR, 0, Enum.Material.Concrete, true
	)

	-- Front wall with entrance gap (12 studs) in center
	-- Front face X = bCX + faceSign * halfDepth
	local frontFaceX = bCX + faceSign * halfDepth
	local segmentWidth = (BUILDING_WIDTH - ENTRANCE_GAP) / 2

	-- Left segment (Z < pos.Z - ENTRANCE_GAP/2)
	local fwLeftZ = pos.Z - ENTRANCE_GAP / 2 - segmentWidth / 2
	makePart(
		folder, "WallFrontLeft",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, segmentWidth),
		CFrame.new(frontFaceX, wallY, fwLeftZ),
		WALL_COLOR, 0, Enum.Material.Concrete, true
	)

	-- Right segment (Z > pos.Z + ENTRANCE_GAP/2)
	local fwRightZ = pos.Z + ENTRANCE_GAP / 2 + segmentWidth / 2
	makePart(
		folder, "WallFrontRight",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, segmentWidth),
		CFrame.new(frontFaceX, wallY, fwRightZ),
		WALL_COLOR, 0, Enum.Material.Concrete, true
	)

	-- Flat roof (light grey, overhanging by ROOF_OVERHANG, 1.5 studs thick)
	local roofWidth = BUILDING_WIDTH + ROOF_OVERHANG * 2
	local roofDepth = BUILDING_DEPTH + ROOF_OVERHANG * 2
	local roofY = foundTopY + WALL_HEIGHT + ROOF_THICKNESS / 2
	makePart(
		folder, "Roof",
		Vector3.new(roofDepth, ROOF_THICKNESS, roofWidth),
		CFrame.new(bCX, roofY, pos.Z),
		ROOF_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- 5 vertical red neon bars on the front face exterior
	local barY = foundTopY + WALL_HEIGHT / 2
	local barSpacing = BUILDING_WIDTH / (NEON_BAR_COUNT + 1)
	for i = 1, NEON_BAR_COUNT do
		local barZ = pos.Z - halfWidth + barSpacing * i
		-- Bar sits just outside the front face
		local barX = frontFaceX + faceSign * (WALL_THICKNESS / 2 + NEON_BAR_D / 2)
		makePart(
			folder, "NeonBar" .. i,
			Vector3.new(NEON_BAR_D, NEON_BAR_H, NEON_BAR_W),
			CFrame.new(barX, barY, barZ),
			NEON_RED, 0, Enum.Material.Neon, false
		)
	end

	-- Green yard slab in front of building (between front face and plot edge toward road)
	-- Plot front edge at X = pos.X + faceSign * (BASE_SIZE / 2)
	-- Building front face at X = frontFaceX
	-- Yard spans from frontFaceX to plotFrontEdge along X, full building width along Z
	local plotFrontEdgeX = pos.X + faceSign * (BASE_SIZE / 2)
	local yardLengthX = math.abs(plotFrontEdgeX - frontFaceX)
	local yardCenterX = (plotFrontEdgeX + frontFaceX) / 2
	makePart(
		folder, "Yard",
		Vector3.new(yardLengthX, 0.2, BUILDING_WIDTH),
		CFrame.new(yardCenterX, foundBaseY + 0.1, pos.Z),
		YARD_COLOR, 0, Enum.Material.Grass, false
	)
end

-- ============================================================
-- Build the name sign post at front edge of plot
-- ============================================================

local function buildSign(folder, pos, faceSign, playerName)
	local halfBase = BASE_SIZE / 2
	local postX    = pos.X + faceSign * (halfBase - 1)
	local postH    = 5
	local postBaseY = pos.Y
	local postCenterY = postBaseY + postH / 2

	makePart(
		folder, "SignPost",
		Vector3.new(0.4, postH, 0.4),
		CFrame.new(postX, postCenterY, pos.Z),
		Color3.fromRGB(30, 30, 30), 0, Enum.Material.Metal, true
	)

	local boardY = postBaseY + postH + 1
	local signBoard = makePart(
		folder, "SignBoard",
		Vector3.new(7, 2, 0.4),
		CFrame.new(postX, boardY, pos.Z),
		Color3.fromRGB(20, 20, 20), 0, Enum.Material.SmoothPlastic, false
	)

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face       = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize = Vector2.new(350, 100)
	surfaceGui.Parent     = signBoard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size                  = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text                  = playerName
	nameLabel.TextScaled            = true
	nameLabel.Font                  = Enum.Font.GothamBold
	nameLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Parent                = surfaceGui
end

-- ============================================================
-- Build an upper floor platform + railings + ramp
-- floorNum is 1-indexed (2 = second floor, etc.)
-- ============================================================

local function buildUpperFloor(folder, pos, faceSign, floorNum)
	local PLATFORM_COLOR  = Color3.fromRGB(70, 70, 75)
	local RAILING_COLOR   = Color3.fromRGB(100, 100, 105)
	local RAMP_COLOR      = Color3.fromRGB(90, 90, 95)

	local bCX = pos.X + faceSign * (-6)

	-- Y of this floor's ground surface (floorNum=2 means first upper floor)
	local floorGroundY = pos.Y + (floorNum - 1) * FLOOR_HEIGHT_STEP

	-- Platform slab (same X/Z footprint as ground floor building interior)
	-- Slab is FLOOR_THICKNESS thick, its top surface is floorGroundY
	local slabCenterY = floorGroundY - FLOOR_THICKNESS / 2
	makePart(
		folder, "FloorSlab" .. floorNum,
		Vector3.new(BUILDING_DEPTH, FLOOR_THICKNESS, BUILDING_WIDTH),
		CFrame.new(bCX, slabCenterY, pos.Z),
		PLATFORM_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Railings on all sides except the front entrance gap
	local railH     = 3
	local railThick = 0.5
	local railY     = floorGroundY + railH / 2
	local halfDepth = BUILDING_DEPTH / 2
	local halfWidth = BUILDING_WIDTH / 2

	-- Back railing
	local backRailX = bCX - faceSign * halfDepth
	makePart(
		folder, "RailBack" .. floorNum,
		Vector3.new(railThick, railH, BUILDING_WIDTH),
		CFrame.new(backRailX, railY, pos.Z),
		RAILING_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Left railing (full depth along X)
	makePart(
		folder, "RailLeft" .. floorNum,
		Vector3.new(BUILDING_DEPTH, railH, railThick),
		CFrame.new(bCX, railY, pos.Z - halfWidth),
		RAILING_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Right railing
	makePart(
		folder, "RailRight" .. floorNum,
		Vector3.new(BUILDING_DEPTH, railH, railThick),
		CFrame.new(bCX, railY, pos.Z + halfWidth),
		RAILING_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Front railing: two segments with entrance gap
	local frontFaceX   = bCX + faceSign * halfDepth
	local segmentWidth = (BUILDING_WIDTH - ENTRANCE_GAP) / 2

	local fwLeftZ  = pos.Z - ENTRANCE_GAP / 2 - segmentWidth / 2
	local fwRightZ = pos.Z + ENTRANCE_GAP / 2 + segmentWidth / 2
	makePart(
		folder, "RailFrontLeft" .. floorNum,
		Vector3.new(railThick, railH, segmentWidth),
		CFrame.new(frontFaceX, railY, fwLeftZ),
		RAILING_COLOR, 0, Enum.Material.SmoothPlastic, true
	)
	makePart(
		folder, "RailFrontRight" .. floorNum,
		Vector3.new(railThick, railH, segmentWidth),
		CFrame.new(frontFaceX, railY, fwRightZ),
		RAILING_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Ramp/wedge going from previous floor to this floor, placed at the back of the aisle
	-- Ramp sits between the back wall and the aisle along depth axis.
	-- Previous floor ground Y:
	local prevFloorY = pos.Y + (floorNum - 2) * FLOOR_HEIGHT_STEP
	-- Ramp height = FLOOR_HEIGHT_STEP, ramp depth = 6 studs (1 row spacing)
	local rampHeight = FLOOR_HEIGHT_STEP
	local rampDepth  = 6
	local rampWidth  = ENTRANCE_GAP  -- span the aisle width
	-- Ramp center Y: midpoint between prevFloorY and floorGroundY
	local rampCenterY = (prevFloorY + floorGroundY) / 2
	-- Place ramp at the back of the building along depth axis (back row area)
	local rampX = bCX - faceSign * (halfDepth - rampDepth / 2)

	-- Use a wedge part oriented so it slopes upward from front to back
	local ramp = Instance.new("WedgePart")
	ramp.Name      = "Ramp" .. floorNum
	ramp.Size      = Vector3.new(rampDepth, rampHeight, rampWidth)
	ramp.Anchored  = true
	ramp.CanCollide = true
	ramp.Color     = RAMP_COLOR
	ramp.Material  = Enum.Material.SmoothPlastic
	ramp.CastShadow = true

	-- Orient the wedge so the slope goes upward in the direction toward the back of the building.
	-- A default WedgePart slopes upward from -Z toward +Z in its local space.
	-- We want the slope to go upward from the front toward the back (away from road).
	-- faceSign=+1: back is at -X relative to bCX, so we rotate to align slope with -X world direction.
	-- faceSign=-1: back is at +X, slope should go toward +X.
	-- CFrame: position at rampX, rampCenterY, pos.Z, then rotate to align wedge slope with depth axis.
	local slopeAngle
	if faceSign >= 0 then
		-- slope rises toward -X (back): rotate around Z by 90 deg, then around Y
		-- WedgePart default: top face tilts from front (+Z) to back (-Z).
		-- We need it to tilt from front (+X, toward road) to back (-X).
		-- Rotate -90 deg around Y so +Z of wedge aligns with -X world.
		slopeAngle = math.pi / 2
	else
		slopeAngle = -math.pi / 2
	end

	ramp.CFrame = CFrame.new(rampX, rampCenterY, pos.Z) * CFrame.Angles(0, slopeAngle, 0)
	ramp.Parent = folder
end

-- ============================================================
-- Public: createBase
-- ============================================================

function BaseSystem.createBase(player, position, playerBases)
	local folder = Instance.new("Folder")
	folder.Name   = player.Name .. "_Base"
	folder.Parent = workspace

	local faceSign = getFaceSign(position)

	-- Build ground floor
	buildGroundFloor(folder, position, faceSign)

	-- Build name sign
	buildSign(folder, position, faceSign, player.Name)

	-- Pre-compute all 50 slot and plate positions
	local slotPositions, platePositions = computeAllSlotPositions(position)

	-- Initialise state
	playerBases[player] = {
		folder         = folder,
		position       = position,
		faceSign       = faceSign,
		lockShield     = nil,
		isLocked       = false,
		slotPositions  = slotPositions,
		platePositions = platePositions,
		unlockedFloors = 1,
		slotGrid       = {},     -- true = occupied, nil/false = free
		maxSlots       = 10,     -- floor 1 gives 10 slots
	}

	return folder
end

-- ============================================================
-- Public: getNextSlot
-- Scan slotGrid[1..maxSlots] for first nil/false.
-- Returns slotIndex, slotPosition (Vector3), or nil if full.
-- ============================================================

function BaseSystem.getNextSlot(player, playerBases)
	local baseData = playerBases[player]
	if not baseData then
		return nil
	end

	for i = 1, baseData.maxSlots do
		if not baseData.slotGrid[i] then
			baseData.slotGrid[i] = true
			return i, baseData.slotPositions[i]
		end
	end

	return nil
end

-- ============================================================
-- Public: releaseSlot
-- ============================================================

function BaseSystem.releaseSlot(player, playerBases, slotIndex)
	local baseData = playerBases[player]
	if not baseData then
		return
	end
	if slotIndex then
		baseData.slotGrid[slotIndex] = false
	end
end

-- ============================================================
-- Public: unlockNextFloor
-- Build the next floor and update maxSlots.
-- Returns true if a new floor was unlocked, false if already at max.
-- ============================================================

function BaseSystem.unlockNextFloor(player, playerBases)
	local baseData = playerBases[player]
	if not baseData then
		return false
	end

	if baseData.unlockedFloors >= MAX_FLOORS then
		return false
	end

	baseData.unlockedFloors = baseData.unlockedFloors + 1
	local floorNum = baseData.unlockedFloors  -- e.g. 2 for first upper floor

	buildUpperFloor(baseData.folder, baseData.position, baseData.faceSign, floorNum)

	baseData.maxSlots = baseData.maxSlots + SLOTS_PER_FLOOR

	return true
end

-- ============================================================
-- Public: lockBase
-- ============================================================

function BaseSystem.lockBase(player, playerBases)
	local baseData = playerBases[player]
	if not baseData then
		return
	end

	local now      = os.clock()
	local lastLock = lockCooldowns[player.UserId]
	if lastLock and (now - lastLock) < LOCK_COOLDOWN then
		local remaining = math.ceil(LOCK_COOLDOWN - (now - lastLock))
		evtNotification:FireClient(player, "Base lock on cooldown (" .. remaining .. "s remaining)", Color3.fromRGB(255, 200, 50))
		return
	end

	if baseData.isLocked then
		evtNotification:FireClient(player, "Your base is already locked!", Color3.fromRGB(255, 200, 50))
		return
	end

	lockCooldowns[player.UserId] = now

	local basePos     = baseData.position
	local shieldFolder = Instance.new("Folder")
	shieldFolder.Name   = "LockShield"
	shieldFolder.Parent = workspace

	local panelCount = 6
	local panelY     = basePos.Y + 4
	local radius     = BASE_SIZE / 2 + 1

	for i = 1, panelCount do
		local angle  = (2 * math.pi / panelCount) * (i - 1)
		local panelX = basePos.X + radius * math.cos(angle)
		local panelZ = basePos.Z + radius * math.sin(angle)

		local panel = Instance.new("Part")
		panel.Name        = "ShieldPanel" .. i
		panel.Size        = Vector3.new(BASE_SIZE + 2, 8, 1)
		panel.CFrame      = CFrame.new(panelX, panelY, panelZ) * CFrame.Angles(0, angle + math.pi / 2, 0)
		panel.Anchored    = true
		panel.CanCollide  = false
		panel.Color       = Color3.fromRGB(0, 255, 255)
		panel.Material    = Enum.Material.Neon
		panel.Transparency = 0.5
		panel.CastShadow  = false
		panel.Parent      = shieldFolder
	end

	local glowCenter = Instance.new("Part")
	glowCenter.Name        = "ShieldGlow"
	glowCenter.Size        = Vector3.new(0.1, 0.1, 0.1)
	glowCenter.CFrame      = CFrame.new(basePos.X, panelY, basePos.Z)
	glowCenter.Anchored    = true
	glowCenter.CanCollide  = false
	glowCenter.Transparency = 1
	glowCenter.Parent      = shieldFolder

	local shieldLight = Instance.new("PointLight")
	shieldLight.Brightness = 2
	shieldLight.Range      = BASE_SIZE + 10
	shieldLight.Color      = Color3.fromRGB(0, 255, 255)
	shieldLight.Parent     = glowCenter

	baseData.lockShield = shieldFolder
	baseData.isLocked   = true
	player:SetAttribute("BaseIsLocked", true)

	evtNotification:FireClient(player, "Base locked for " .. LOCK_SHIELD_DURATION .. " seconds!", Color3.fromRGB(0, 220, 255))

	task.delay(LOCK_SHIELD_DURATION, function()
		if baseData.lockShield == shieldFolder then
			BaseSystem.unlockBase(player, playerBases)
		end
	end)
end

-- ============================================================
-- Public: unlockBase
-- ============================================================

function BaseSystem.unlockBase(player, playerBases)
	local baseData = playerBases[player]
	if not baseData then
		return
	end

	if baseData.lockShield and baseData.lockShield.Parent then
		baseData.lockShield:Destroy()
	end
	baseData.lockShield = nil
	baseData.isLocked   = false
	player:SetAttribute("BaseIsLocked", false)
end

-- ============================================================
-- Public: isInBase
-- ============================================================

function BaseSystem.isInBase(position, baseData)
	if not baseData then
		return false
	end

	local basePos  = baseData.position
	local halfBound = BASE_SIZE / 2

	local insideX = math.abs(position.X - basePos.X) < halfBound
	local insideZ = math.abs(position.Z - basePos.Z) < halfBound

	return insideX and insideZ
end

-- ============================================================
-- Public: teleportToBase
-- ============================================================

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

		local ring = Instance.new("Part")
		ring.Shape     = Enum.PartType.Cylinder
		ring.Size      = Vector3.new(0.3, 8, 8)
		ring.CFrame    = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Anchored  = true
		ring.CanCollide = false
		ring.Color     = Color3.fromRGB(0, 255, 255)
		ring.Material  = Enum.Material.Neon
		ring.Parent    = workspace

		task.spawn(function()
			for i = 1, 10 do
				task.wait(0.05)
				ring.Size        = ring.Size + Vector3.new(0, 2, 2)
				ring.Transparency = i / 10
			end
			ring:Destroy()
		end)

		root.CFrame = CFrame.new(position + Vector3.new(0, 6, 0))
	end)
end

return BaseSystem
