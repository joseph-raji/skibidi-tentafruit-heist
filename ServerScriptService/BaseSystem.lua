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
local WALL_HEIGHT      = 15   -- wall height per floor
local FLOOR_THICKNESS  = 2    -- floor slab thickness
local ROOF_OVERHANG    = 3    -- roof overhang on each side
local ROOF_THICKNESS   = 1.5
local YARD_DEPTH       = 14   -- green area between building front and plot edge toward road
local FLOOR_HEIGHT_STEP = 17  -- Y distance between each floor's ground level

local WALL_THICKNESS   = 1
local ENTRANCE_GAP     = 12   -- width of open entrance in front wall

local MAX_FLOORS       = 3
local SLOTS_PER_FLOOR  = 10   -- 5 left + 5 right

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
	local WALL_COLOR           = Color3.fromRGB(52, 55, 63)
	local ROOF_COLOR           = Color3.fromRGB(38, 40, 48)
	local INTERIOR_FLOOR_COLOR = Color3.fromRGB(48, 50, 58)
	local TRIM_COLOR           = Color3.fromRGB(190, 193, 200)
	local BAR_COLOR            = Color3.fromRGB(210, 20, 20)
	local SIGN_COLOR           = Color3.fromRGB(95, 58, 18)
	local BETON_COLOR          = Color3.fromRGB(110, 112, 115)  -- béton / concrete
	local FOUNDATION_COLOR     = Color3.fromRGB(65, 68, 76)

	-- Plot ground slab — béton (concrete)
	makePart(
		folder, "PlotGround",
		Vector3.new(BASE_SIZE, 1, BASE_SIZE),
		CFrame.new(pos.X, pos.Y - 0.5, pos.Z),
		BETON_COLOR, 0, Enum.Material.Concrete, true
	)

	local bCX          = pos.X + faceSign * (-6)
	local foundBaseY   = pos.Y
	local foundTopY    = foundBaseY + FLOOR_THICKNESS
	local foundCenterY = foundBaseY + FLOOR_THICKNESS / 2

	-- Foundation
	makePart(
		folder, "Foundation",
		Vector3.new(BUILDING_DEPTH, FLOOR_THICKNESS, BUILDING_WIDTH),
		CFrame.new(bCX, foundCenterY, pos.Z),
		FOUNDATION_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Interior floor
	makePart(
		folder, "InteriorFloor",
		Vector3.new(BUILDING_DEPTH, 0.2, BUILDING_WIDTH),
		CFrame.new(bCX, foundTopY + 0.1, pos.Z),
		INTERIOR_FLOOR_COLOR, 0, Enum.Material.SmoothPlastic, false
	)

	local halfDepth  = BUILDING_DEPTH / 2
	local halfWidth  = BUILDING_WIDTH / 2
	local frontFaceX = bCX + faceSign * halfDepth
	local wallY      = foundTopY + WALL_HEIGHT / 2

	-- Back wall
	makePart(
		folder, "WallBack",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, BUILDING_WIDTH),
		CFrame.new(bCX - faceSign * halfDepth, wallY, pos.Z),
		WALL_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Left side wall
	makePart(
		folder, "WallLeft",
		Vector3.new(BUILDING_DEPTH, WALL_HEIGHT, WALL_THICKNESS),
		CFrame.new(bCX, wallY, pos.Z - halfWidth),
		WALL_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Right side wall
	makePart(
		folder, "WallRight",
		Vector3.new(BUILDING_DEPTH, WALL_HEIGHT, WALL_THICKNESS),
		CFrame.new(bCX, wallY, pos.Z + halfWidth),
		WALL_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- -----------------------------------------------------------------------
	-- Front display window: brown sign header + silver trim + red bars
	-- -----------------------------------------------------------------------
	local topBeamH  = 2.5   -- height of brown sign header at top
	local sillH     = 1.0   -- height of bottom sill
	local pillarW   = 2.5   -- width of each side pillar
	local openH     = WALL_HEIGHT - topBeamH - sillH   -- 6.5
	local openY     = foundTopY + sillH + openH / 2

	-- Brown sign header (named SignBoard so buildSign can attach text)
	makePart(
		folder, "SignBoard",
		Vector3.new(WALL_THICKNESS + 0.2, topBeamH, BUILDING_WIDTH),
		CFrame.new(frontFaceX, foundTopY + WALL_HEIGHT - topBeamH / 2, pos.Z),
		SIGN_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Bottom sill
	makePart(
		folder, "FrontSill",
		Vector3.new(WALL_THICKNESS + 0.2, sillH, BUILDING_WIDTH),
		CFrame.new(frontFaceX, foundTopY + sillH / 2, pos.Z),
		TRIM_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Left pillar
	makePart(
		folder, "FrontPillarL",
		Vector3.new(WALL_THICKNESS + 0.2, openH, pillarW),
		CFrame.new(frontFaceX, openY, pos.Z - halfWidth + pillarW / 2),
		TRIM_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Right pillar
	makePart(
		folder, "FrontPillarR",
		Vector3.new(WALL_THICKNESS + 0.2, openH, pillarW),
		CFrame.new(frontFaceX, openY, pos.Z + halfWidth - pillarW / 2),
		TRIM_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Red vertical bars filling the opening (non-collidable, decorative)
	local displayWidth = BUILDING_WIDTH - pillarW * 2
	local barCount     = 10
	local barSpacing   = displayWidth / (barCount + 1)
	for i = 1, barCount do
		local barZ = pos.Z - halfWidth + pillarW + barSpacing * i
		makePart(
			folder, "DisplayBar" .. i,
			Vector3.new(0.45, openH, 0.45),
			CFrame.new(frontFaceX, openY, barZ),
			BAR_COLOR, 0, Enum.Material.Neon, false
		)
	end

	-- -----------------------------------------------------------------------
	-- Flat roof
	-- -----------------------------------------------------------------------
	local roofWidth = BUILDING_WIDTH + ROOF_OVERHANG * 2
	local roofDepth = BUILDING_DEPTH + ROOF_OVERHANG * 2
	local roofY     = foundTopY + WALL_HEIGHT + ROOF_THICKNESS / 2
	makePart(
		folder, "Roof",
		Vector3.new(roofDepth, ROOF_THICKNESS, roofWidth),
		CFrame.new(bCX, roofY, pos.Z),
		ROOF_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- Yard (strip between building front and plot edge) — béton like the rest of the plot
	local plotFrontEdgeX = pos.X + faceSign * (BASE_SIZE / 2)
	local yardLengthX    = math.abs(plotFrontEdgeX - frontFaceX)
	local yardCenterX    = (plotFrontEdgeX + frontFaceX) / 2
	makePart(
		folder, "Yard",
		Vector3.new(yardLengthX, 0.2, BUILDING_WIDTH),
		CFrame.new(yardCenterX, foundBaseY + 0.1, pos.Z),
		BETON_COLOR, 0, Enum.Material.Concrete, false
	)
end

-- ============================================================
-- Build the name sign post at front edge of plot
-- ============================================================

local function buildSign(folder, pos, faceSign, playerName)
	local signBoard = folder:FindFirstChild("SignBoard")
	if not signBoard then return end

	local surfaceGui          = Instance.new("SurfaceGui")
	surfaceGui.Face           = faceSign > 0 and Enum.NormalId.Right or Enum.NormalId.Left
	surfaceGui.SizingMode     = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize     = Vector2.new(1400, 100)  -- wider canvas = smaller text relative to sign
	surfaceGui.Parent         = signBoard

	local nameLabel                    = Instance.new("TextLabel")
	nameLabel.Size                     = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency   = 1
	nameLabel.Text                     = playerName
	nameLabel.TextScaled               = false
	nameLabel.TextSize                 = 42
	nameLabel.Font                     = Enum.Font.GothamBold
	nameLabel.TextColor3               = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency   = 0.3
	nameLabel.TextXAlignment           = Enum.TextXAlignment.Center
	nameLabel.TextYAlignment           = Enum.TextYAlignment.Center
	nameLabel.Parent                   = surfaceGui
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

	-- Back wall: two segments with a central gap for ladder entry
	local LADDER_GAP = 6
	local backSegW   = (BUILDING_WIDTH - LADDER_GAP) / 2
	local backWallX  = bCX - faceSign * halfDepth
	makePart(folder, "WallBackL" .. floorNum,
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, backSegW),
		CFrame.new(backWallX, wallY, pos.Z - LADDER_GAP/2 - backSegW/2),
		WALL_COLOR, 0, Enum.Material.Concrete, true)
	makePart(folder, "WallBackR" .. floorNum,
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, backSegW),
		CFrame.new(backWallX, wallY, pos.Z + LADDER_GAP/2 + backSegW/2),
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

	-- External climbable ladder (TrussPart) on the back exterior, aligned with the wall gap
	local prevFloorY   = pos.Y + (floorNum - 2) * FLOOR_HEIGHT_STEP
	local ladderHeight = (floorGroundY - prevFloorY) + 4  -- 4 studs above this floor so player can step off
	local ladderCenterY = prevFloorY + ladderHeight / 2
	local ladderX      = backWallX - faceSign * 2   -- 2 studs outside the back wall

	local ladder = Instance.new("TrussPart")
	ladder.Name       = "Ladder" .. floorNum
	ladder.Size       = Vector3.new(2, ladderHeight, 2)
	ladder.CFrame     = CFrame.new(ladderX, ladderCenterY, pos.Z)
	ladder.Anchored   = true
	ladder.CanCollide = false
	ladder.BrickColor = BrickColor.new("Dark stone grey")
	ladder.Material   = Enum.Material.Metal
	ladder.Parent     = folder
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
	buildSign(folder, position, faceSign, "Disponible")

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
	lockPad.Size         = Vector3.new(4, 0.3, 4)
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
	lockLabel.Text                   = "🔒 VERROUILLER"
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
		evtNotification:FireClient(player, "Verrou en recharge (" .. remaining .. "s restantes)", Color3.fromRGB(255, 200, 50))
		return
	end

	if baseData.isLocked then
		evtNotification:FireClient(player, "Ta base est déjà verrouillée !", Color3.fromRGB(255, 200, 50))
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

	evtNotification:FireClient(player, "Base verrouillée " .. LOCK_SHIELD_DURATION .. " sec ! Les autres ne peuvent pas entrer.", Color3.fromRGB(0, 220, 255))

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
