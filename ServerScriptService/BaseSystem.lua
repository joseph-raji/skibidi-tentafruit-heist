-- BaseSystem.lua
-- ModuleScript: handles player base creation, locking, unlocking, and boundary checks

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BaseSystem = {}

-- ============================================================
-- Constants
-- ============================================================

local BASE_SIZE        = 58    -- plot footprint (square)
local BUILDING_DEPTH   = 40   -- along depth axis (X for left/right houses)
local BUILDING_WIDTH   = 34   -- along Z axis
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
-- Pressure plates sit between skin and aisle:
--   Left plate:  Z = pos.Z - 4.5
--   Right plate: Z = pos.Z + 4.5
-- ============================================================

local ROW_OFFSETS = {-14, -7, 0, 7, 14}  -- 7-stud spacing, fits inside enlarged building

local function computeAllSlotPositions(pos)
	local faceSign = getFaceSign(pos)
	-- Building center along depth axis is 6 studs inward from plot center
	local bCX = pos.X + faceSign * (-6)

	local leftZ  = pos.Z - 11   -- pushed further from aisle to avoid skin/plate overlap
	local rightZ = pos.Z + 11

	local leftPlateZ  = pos.Z - 6   -- plate sits in the aisle, clear of the skin body
	local rightPlateZ = pos.Z + 6

	local slotPositions  = {}
	local platePositions = {}

	for floorIndex = 1, MAX_FLOORS do
		-- Floor 1 interior surface: pos.Y + 2.2 (foundation 2 + interior slab 0.2).
		-- Upper floors surface: pos.Y + (floorIndex-1) * FLOOR_HEIGHT_STEP.
		-- slotPositions store the floor SURFACE Y — callers must add skinData.size/2
		-- to get the correct body-centre spawn position.
		local floorSurfaceY
		if floorIndex == 1 then
			floorSurfaceY = pos.Y + 2.2
		else
			floorSurfaceY = pos.Y + (floorIndex - 1) * FLOOR_HEIGHT_STEP
		end
		local plateY = floorSurfaceY + 0.15  -- plate sits flush with floor

		for row = 1, 5 do
			local rowX = bCX + faceSign * ROW_OFFSETS[row]

			local leftSlotGlobal  = (floorIndex - 1) * SLOTS_PER_FLOOR + row
			local rightSlotGlobal = (floorIndex - 1) * SLOTS_PER_FLOOR + 5 + row

			slotPositions[leftSlotGlobal]  = Vector3.new(rowX, floorSurfaceY, leftZ)
			slotPositions[rightSlotGlobal] = Vector3.new(rowX, floorSurfaceY, rightZ)

			platePositions[leftSlotGlobal]  = Vector3.new(rowX, plateY, leftPlateZ)
			platePositions[rightSlotGlobal] = Vector3.new(rowX, plateY, rightPlateZ)
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
	local WALL_COLOR      = Color3.fromRGB(130, 130, 135)
	local ROOF_COLOR      = Color3.fromRGB(190, 190, 195)

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

	-- Full concrete walls matching ground floor style
	local wallY     = floorGroundY + WALL_HEIGHT / 2
	local halfDepth = BUILDING_DEPTH / 2
	local halfWidth = BUILDING_WIDTH / 2

	-- Back wall
	makePart(folder, "WallBack" .. floorNum,
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, BUILDING_WIDTH),
		CFrame.new(bCX - faceSign * halfDepth, wallY, pos.Z),
		WALL_COLOR, 0, Enum.Material.Concrete, true)

	-- Left wall
	makePart(folder, "WallLeft" .. floorNum,
		Vector3.new(BUILDING_DEPTH, WALL_HEIGHT, WALL_THICKNESS),
		CFrame.new(bCX, wallY, pos.Z - halfWidth),
		WALL_COLOR, 0, Enum.Material.Concrete, true)

	-- Right wall
	makePart(folder, "WallRight" .. floorNum,
		Vector3.new(BUILDING_DEPTH, WALL_HEIGHT, WALL_THICKNESS),
		CFrame.new(bCX, wallY, pos.Z + halfWidth),
		WALL_COLOR, 0, Enum.Material.Concrete, true)

	-- Front wall: two segments with entrance gap
	local frontFaceX   = bCX + faceSign * halfDepth
	local segmentWidth = (BUILDING_WIDTH - ENTRANCE_GAP) / 2

	-- Front wall left segment
	makePart(folder, "WallFrontLeft" .. floorNum,
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, segmentWidth),
		CFrame.new(frontFaceX, wallY, pos.Z - ENTRANCE_GAP / 2 - segmentWidth / 2),
		WALL_COLOR, 0, Enum.Material.Concrete, true)

	-- Front wall right segment
	makePart(folder, "WallFrontRight" .. floorNum,
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, segmentWidth),
		CFrame.new(frontFaceX, wallY, pos.Z + ENTRANCE_GAP / 2 + segmentWidth / 2),
		WALL_COLOR, 0, Enum.Material.Concrete, true)

	-- Roof
	local roofY = floorGroundY + WALL_HEIGHT + 0.75
	makePart(folder, "Roof" .. floorNum,
		Vector3.new(BUILDING_DEPTH + 6, 1.5, BUILDING_WIDTH + 6),
		CFrame.new(bCX, roofY, pos.Z),
		ROOF_COLOR, 0, Enum.Material.SmoothPlastic, true)

	-- Walkable staircase: 6 steps, each 2 studs tall x 4 studs deep, 12 studs wide
	-- Placed at the back of the building, rising from the previous floor to this floor
	local prevFloorY  = pos.Y + (floorNum - 2) * FLOOR_HEIGHT_STEP
	local STEP_HEIGHT = 2
	local STEP_DEPTH  = 4
	local STEP_COUNT  = 6   -- 6 x 2 = 12 studs rise = FLOOR_HEIGHT_STEP
	local STAIR_WIDTH = ENTRANCE_GAP  -- 12 studs, centered at pos.Z

	-- Back of staircase anchors at back wall inner face (1 stud inside back wall)
	local stairBackX = bCX - faceSign * (halfDepth - 1)

	for step = 1, STEP_COUNT do
		local stepTopY    = prevFloorY + step * STEP_HEIGHT
		local stepCenterY = stepTopY - STEP_HEIGHT / 2
		-- step=1 is closest to back wall, step=6 is furthest (toward front/center)
		local stepCenterX = stairBackX + faceSign * ((step - 1) * STEP_DEPTH + STEP_DEPTH / 2)

		makePart(
			folder, "Stair" .. floorNum .. "_" .. step,
			Vector3.new(STEP_DEPTH, STEP_HEIGHT, STAIR_WIDTH),
			CFrame.new(stepCenterX, stepCenterY, pos.Z),
			Color3.fromRGB(90, 90, 95), 0, Enum.Material.SmoothPlastic, true
		)
	end
end

-- ============================================================
-- Public: createBase
-- ============================================================

-- ============================================================
-- Empty-base visual placeholders (shown before any player claims a slot)
-- ============================================================

local emptyBaseFolders = {}  -- "X_Z" key → Folder

function BaseSystem.buildEmptyBase(position)
	local key = position.X .. "_" .. position.Z
	if emptyBaseFolders[key] then return end  -- already built

	local faceSign = getFaceSign(position)
	local folder = Instance.new("Folder")
	folder.Name   = "EmptyBase_" .. key
	folder.Parent = workspace

	buildGroundFloor(folder, position, faceSign)
	buildSign(folder, position, faceSign, "Available")

	emptyBaseFolders[key] = folder
end

function BaseSystem.claimBase(player, position, playerBases)
	-- Destroy the empty placeholder for this slot, then create the real base
	local key = position.X .. "_" .. position.Z
	local emptyFolder = emptyBaseFolders[key]
	if emptyFolder and emptyFolder.Parent then
		emptyFolder:Destroy()
	end
	emptyBaseFolders[key] = nil
	return BaseSystem.createBase(player, position, playerBases)
end

function BaseSystem.releaseBase(position)
	-- Called when a player leaves — rebuild the empty placeholder
	BaseSystem.buildEmptyBase(position)
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

	-- Pre-create empty visual plates for all floor-1 slots
	local emptyPlates = {}
	for i = 1, 5 do
		local platePos = platePositions[i]
		if platePos then
			local ep = Instance.new("Part")
			ep.Name         = "EmptySlotPlate_" .. i
			ep.Size         = Vector3.new(4, 0.3, 4)
			ep.Material     = Enum.Material.Neon
			ep.Color        = Color3.fromRGB(50, 50, 55)
			ep.Transparency = 0.4
			ep.CanCollide   = false
			ep.Anchored     = true
			ep.CFrame       = CFrame.new(platePos)
			ep.Parent       = folder
			emptyPlates[i]  = ep
		end
	end

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
		maxSlots       = 5,      -- players start with 5 slots
		emptyPlates    = emptyPlates,
	}

	-- ── Lock pad in center of base ──────────────────────────────────────
	-- Owner steps on it to activate the base shield (replaces HUD button).
	local lockPad = Instance.new("Part")
	lockPad.Name         = "LockPad"
	lockPad.Size         = Vector3.new(8, 0.3, 8)
	lockPad.Material     = Enum.Material.Neon
	lockPad.Color        = Color3.fromRGB(0, 200, 255)
	lockPad.CanCollide   = true
	lockPad.Anchored     = true
	lockPad.CastShadow   = false
	lockPad.Transparency = 0.3
	lockPad.CFrame       = CFrame.new(position.X, position.Y + 2.3, position.Z)
	lockPad.Parent       = folder

	local lockBB = Instance.new("BillboardGui")
	lockBB.Size        = UDim2.new(0, 180, 0, 55)
	lockBB.StudsOffset = Vector3.new(0, 3, 0)
	lockBB.Parent      = lockPad

	local lockLabel = Instance.new("TextLabel")
	lockLabel.Size                   = UDim2.new(1, 0, 1, 0)
	lockLabel.BackgroundTransparency = 1
	lockLabel.Text                   = "🔒 LOCK BASE"
	lockLabel.TextScaled             = true
	lockLabel.Font                   = Enum.Font.GothamBold
	lockLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
	lockLabel.TextStrokeTransparency = 0
	lockLabel.Parent                 = lockBB

	local lockTouchDebounce = false
	lockPad.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end
		local touchPlayer = Players:GetPlayerFromCharacter(character)
		if not touchPlayer or touchPlayer ~= player then return end
		if lockTouchDebounce then return end
		lockTouchDebounce = true
		task.delay(LOCK_COOLDOWN, function() lockTouchDebounce = false end)
		BaseSystem.lockBase(player, playerBases)
	end)

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
-- Public: grantSlot
-- Grant one additional skin slot to a player.
-- If the new slot count exceeds the current floor capacity, also unlocks the next floor.
-- Returns the new total maxSlots.
-- ============================================================

function BaseSystem.grantSlot(player, playerBases)
	local baseData = playerBases[player]
	if not baseData then return 0 end

	baseData.maxSlots = (baseData.maxSlots or 5) + 1
	local newSlots = baseData.maxSlots

	-- Check if a new floor is needed (each floor holds SLOTS_PER_FLOOR = 10 slots)
	local floorsNeeded = math.ceil(newSlots / SLOTS_PER_FLOOR)
	while (baseData.unlockedFloors or 1) < floorsNeeded do
		BaseSystem.unlockNextFloor(player, playerBases)
	end

	-- If this new slot is on the current highest floor and it's within range,
	-- create an empty plate for it so the player can see and use it
	local slotIndex = newSlots
	local platePos = baseData.platePositions and baseData.platePositions[slotIndex]
	if platePos and baseData.folder and baseData.folder.Parent then
		if not baseData.emptyPlates then baseData.emptyPlates = {} end
		-- Only create if not already occupied
		if not baseData.emptyPlates[slotIndex] and not baseData.slotGrid[slotIndex] then
			local ep = Instance.new("Part")
			ep.Name         = "EmptySlotPlate_" .. slotIndex
			ep.Size         = Vector3.new(4, 0.3, 4)
			ep.Material     = Enum.Material.Neon
			ep.Color        = Color3.fromRGB(50, 50, 55)
			ep.Transparency = 0.4
			ep.CanCollide   = false
			ep.Anchored     = true
			ep.CFrame       = CFrame.new(platePos)
			ep.Parent       = baseData.folder
			baseData.emptyPlates[slotIndex] = ep
		end
	end

	return newSlots
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

	local basePos  = baseData.position
	local faceSign = baseData.faceSign

	-- Build a physical door at the front entrance gap.
	-- Front face X = bCX + faceSign * halfDepth = pos.X + faceSign * 11
	local bCX        = basePos.X + faceSign * (-6)
	local halfDepth  = BUILDING_DEPTH / 2   -- 17
	local frontFaceX = bCX + faceSign * halfDepth   -- pos.X + faceSign * 11
	local doorCenterY = basePos.Y + FLOOR_THICKNESS + WALL_HEIGHT / 2  -- mid-height of wall

	local doorFolder = Instance.new("Folder")
	doorFolder.Name   = "LockDoor"
	doorFolder.Parent = workspace

	-- Main solid door panel spanning the entrance gap
	local door = Instance.new("Part")
	door.Name         = "EntranceDoor"
	door.Size         = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ENTRANCE_GAP)
	door.CFrame       = CFrame.new(frontFaceX, doorCenterY, basePos.Z)
	door.Anchored     = true
	door.CanCollide   = true
	door.Color        = Color3.fromRGB(0, 200, 255)
	door.Material     = Enum.Material.Neon
	door.Transparency = 0.4
	door.CastShadow   = false
	door.Parent       = doorFolder

	-- Glow light on door
	local doorLight = Instance.new("PointLight")
	doorLight.Brightness = 2
	doorLight.Range      = 20
	doorLight.Color      = Color3.fromRGB(0, 220, 255)
	doorLight.Parent     = door

	-- Owner passthrough: door becomes non-collidable for 1 second when owner touches it
	local passThroughActive = false
	door.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end
		local touchPlayer = Players:GetPlayerFromCharacter(character)
		if touchPlayer ~= player then return end
		if passThroughActive then return end
		passThroughActive = true
		door.CanCollide   = false
		door.Transparency = 0.8
		task.delay(1.2, function()
			if door and door.Parent then
				door.CanCollide   = true
				door.Transparency = 0.4
			end
			passThroughActive = false
		end)
	end)

	baseData.lockShield = doorFolder
	baseData.isLocked   = true
	player:SetAttribute("BaseIsLocked", true)

	evtNotification:FireClient(player, "Base locked for " .. LOCK_SHIELD_DURATION .. " seconds! Others cannot enter.", Color3.fromRGB(0, 220, 255))

	task.delay(LOCK_SHIELD_DURATION, function()
		if baseData.lockShield == doorFolder then
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
