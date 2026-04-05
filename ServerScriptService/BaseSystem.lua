-- BaseSystem.lua
-- ModuleScript: handles player base creation, locking, unlocking, and boundary checks

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BaseSystem = {}

-- ============================================================
-- Constants
-- ============================================================

local BASE_SIZE = 50           -- plot footprint (square)
local FLOOR_HEIGHT = 1         -- plot ground slab height

-- Building dimensions
local BUILDING_W = 30          -- building width (parallel to road-facing axis)
local BUILDING_D = 20          -- building depth (perpendicular to road)
local WALL_HEIGHT = 8          -- house wall height
local WALL_THICKNESS = 1       -- house wall thickness
local FOUNDATION_HEIGHT = 2    -- concrete foundation slab height
local FOUNDATION_MARGIN = 1    -- how much foundation extends past walls
local ROOF_OVERHANG = 3        -- how far roof extends past walls on each side
local ROOF_THICKNESS = 1.5     -- flat roof thickness
local ENTRANCE_GAP = 12        -- width of open entrance in front wall

-- Neon red bars on front face
local NEON_BAR_COUNT = 5
local NEON_BAR_W = 2
local NEON_BAR_H = 7
local NEON_BAR_D = 0.5

-- Shield / lock
local LOCK_SHIELD_DURATION = 15
local LOCK_COOLDOWN = 30

-- Slot grid (brainrot placement inside house)
local SLOT_COLS = 4
local SLOT_ROWS = 5
local SLOT_SPACING_X = 4
local SLOT_SPACING_Z = 3

-- How many slots each level unlocks
local LEVEL_SLOTS = {
	[0] = 8,   -- level 0: 8 slots
	[1] = 12,  -- level 1
	[2] = 16,  -- level 2
	[3] = 18,  -- level 3
	[4] = 20,  -- level 4 (max = 4x5)
}

-- ============================================================
-- Module-level state
-- ============================================================

-- Tracks cooldown per player (UserId → os.clock() when lock was last activated)
local lockCooldowns = {}

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local evtNotification = remoteEvents:WaitForChild("Notification")

-- ============================================================
-- Helper: determine level from RebirthCount attribute
-- ============================================================

local function getLevel(player)
	local rebirths = player:GetAttribute("RebirthCount") or 0
	if rebirths >= 8 then
		return 4
	elseif rebirths >= 5 then
		return 3
	elseif rebirths >= 3 then
		return 2
	elseif rebirths >= 1 then
		return 1
	else
		return 0
	end
end

-- ============================================================
-- Helper: create a basic anchored Part
-- ============================================================

local function makePart(parent, name, size, cframe, color3, transparency, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color3
	part.Transparency = transparency or 0
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = canCollide ~= false
	part.CastShadow = true
	part.Parent = parent
	return part
end

-- ============================================================
-- Helper: determine which direction the house faces based on plot X
-- Returns a unit Vector3 pointing toward the road (front direction).
-- ============================================================

local function getFrontDirection(positionX)
	if positionX < 0 then
		return Vector3.new(1, 0, 0)   -- face +X
	elseif positionX > 0 then
		return Vector3.new(-1, 0, 0)  -- face -X
	else
		return Vector3.new(0, 0, 1)   -- face +Z (default)
	end
end

-- Given a front direction unit vector, return the perpendicular "side" direction
-- (always in the XZ plane, 90° counterclockwise from front).
local function getSideDirection(front)
	-- rotate 90° around Y: (x,0,z) -> (z,0,-x)
	return Vector3.new(front.Z, 0, -front.X)
end

-- ============================================================
-- Build the house structure
-- Returns the folder containing all house parts.
-- ============================================================

local function buildHouse(folder, plotCenter, groundY, level)
	-- groundY is the Y of the top surface of the plot ground.

	local front = getFrontDirection(plotCenter.X)
	local side = getSideDirection(front)

	-- The building sits at the BACK of the plot.
	-- "back" is opposite of front direction.
	-- Building center offset from plot center:
	--   Along front axis: push toward back by (BASE_SIZE/2 - BUILDING_D/2 - some yard gap)
	--   The yard in front is ~(BASE_SIZE/2 - BUILDING_D) deep, minus a small buffer.
	local yardDepth = BASE_SIZE / 2 - BUILDING_D  -- ~30/2 = 15 → there is 15 studs of yard
	-- Building center is at plotCenter - front * (yardDepth/2 + small offset)
	-- More precisely: building back edge at plotCenter - front*(BASE_SIZE/2 - 1)
	-- building center at plotCenter - front*(BASE_SIZE/2 - 1 - BUILDING_D/2)
	local buildingOffset = (BASE_SIZE / 2 - 1 - BUILDING_D / 2)
	local buildingCenter = Vector3.new(
		plotCenter.X - front.X * buildingOffset,
		groundY,
		plotCenter.Z - front.Z * buildingOffset
	)

	-- Colors
	local FOUNDATION_COLOR  = Color3.fromRGB(80,  80,  80)   -- dark grey concrete
	local WALL_COLOR         = Color3.fromRGB(130, 130, 135)  -- medium stone grey
	local ROOF_COLOR         = Color3.fromRGB(190, 190, 195)  -- light grey
	local INTERIOR_FLOOR_COLOR = Color3.fromRGB(60, 60, 60)   -- dark grey floor
	local NEON_RED           = Color3.fromRGB(255, 30,  30)
	local GRASS_COLOR        = Color3.fromRGB(106, 127, 63)

	-- ----------------------------------------------------------------
	-- Yard (grass between plot front edge and building front face)
	-- ----------------------------------------------------------------
	local yardLength = BASE_SIZE / 2 - 1 - BUILDING_D   -- studs of yard in front of building
	-- yard center is between building front face and plot front edge
	-- building front face Y: buildingCenter + front * (BUILDING_D/2)
	-- plot front edge: plotCenter + front * (BASE_SIZE/2)
	local yardCenterOffset = (BASE_SIZE / 2 - 1 - BUILDING_D / 2) - BUILDING_D / 2
	-- simpler: yard extends from (buildingCenter + front*BUILDING_D/2) to plotCenter + front*(BASE_SIZE/2 - 1)
	local yardCenterAlongFront = ((BASE_SIZE / 2 - 1) + (BASE_SIZE / 2 - 1 - BUILDING_D)) / 2
	-- yard center position:
	local yardCenter = Vector3.new(
		plotCenter.X + front.X * yardCenterAlongFront / 2,
		groundY - FLOOR_HEIGHT / 2 + 0.5,
		plotCenter.Z + front.Z * yardCenterAlongFront / 2
	)
	-- Simpler approach: yard spans the full width of the plot, runs from building front to plot front
	local yardLengthActual = BASE_SIZE / 2 - 1 - (BASE_SIZE / 2 - 1 - BUILDING_D)  -- = BUILDING_D? No.
	-- Let me compute directly:
	-- Building front face at: buildingCenter + front*(BUILDING_D/2)  along front axis from plotCenter
	--   = plotCenter - front*(BASE_SIZE/2 - 1 - BUILDING_D/2) + front*(BUILDING_D/2)
	--   = plotCenter - front*(BASE_SIZE/2 - 1 - BUILDING_D)
	-- Plot front edge at: plotCenter + front*(BASE_SIZE/2 - 1)
	-- Yard length = (BASE_SIZE/2 - 1) + (BASE_SIZE/2 - 1 - BUILDING_D) = BASE_SIZE - 2 - BUILDING_D
	local trueYardLength = BASE_SIZE - 2 - BUILDING_D
	-- Yard center along front axis from plotCenter:
	--   = plotCenter + front * ((BASE_SIZE/2 - 1) - trueYardLength/2)
	local yardCenterAlongFrontScalar = (BASE_SIZE / 2 - 1) - trueYardLength / 2
	local yardPartCenter = Vector3.new(
		plotCenter.X + front.X * yardCenterAlongFrontScalar,
		groundY + FLOOR_HEIGHT / 2 + 0.05,
		plotCenter.Z + front.Z * yardCenterAlongFrontScalar
	)
	-- yard width = BASE_SIZE (full plot width), yard length = trueYardLength
	-- size: along side direction = BASE_SIZE, along front direction = trueYardLength
	local yardSizeX = math.abs(side.X) * BASE_SIZE + math.abs(front.X) * trueYardLength
	local yardSizeZ = math.abs(side.Z) * BASE_SIZE + math.abs(front.Z) * trueYardLength
	makePart(
		folder, "Yard",
		Vector3.new(yardSizeX, 0.2, yardSizeZ),
		CFrame.new(yardPartCenter),
		GRASS_COLOR, 0, Enum.Material.Grass, false
	)

	-- ----------------------------------------------------------------
	-- Foundation (dark grey concrete)
	-- ----------------------------------------------------------------
	local foundW = BUILDING_W + FOUNDATION_MARGIN * 2
	local foundD = BUILDING_D + FOUNDATION_MARGIN * 2
	local foundTopY = groundY + FLOOR_HEIGHT / 2 + FOUNDATION_HEIGHT
	local foundCenterY = groundY + FLOOR_HEIGHT / 2 + FOUNDATION_HEIGHT / 2
	-- Foundation is centered on buildingCenter (XZ)
	local foundSizeX = math.abs(side.X) * foundW + math.abs(front.X) * foundD
	local foundSizeZ = math.abs(side.Z) * foundW + math.abs(front.Z) * foundD
	makePart(
		folder, "Foundation",
		Vector3.new(foundSizeX, FOUNDATION_HEIGHT, foundSizeZ),
		CFrame.new(Vector3.new(buildingCenter.X, foundCenterY, buildingCenter.Z)),
		FOUNDATION_COLOR, 0, Enum.Material.Concrete, true
	)

	-- ----------------------------------------------------------------
	-- Interior floor (sits on top of foundation, same footprint as building)
	-- ----------------------------------------------------------------
	local intFloorSizeX = math.abs(side.X) * BUILDING_W + math.abs(front.X) * BUILDING_D
	local intFloorSizeZ = math.abs(side.Z) * BUILDING_W + math.abs(front.Z) * BUILDING_D
	makePart(
		folder, "InteriorFloor",
		Vector3.new(intFloorSizeX, 0.2, intFloorSizeZ),
		CFrame.new(Vector3.new(buildingCenter.X, foundTopY + 0.1, buildingCenter.Z)),
		INTERIOR_FLOOR_COLOR, 0, Enum.Material.SmoothPlastic, false
	)

	-- ----------------------------------------------------------------
	-- Walls (8 studs tall, 1 stud thick)
	-- Wall Y center: foundTopY + WALL_HEIGHT/2
	-- ----------------------------------------------------------------
	local wallY = foundTopY + WALL_HEIGHT / 2
	-- half extents
	local halfW = BUILDING_W / 2   -- along side direction
	local halfD = BUILDING_D / 2   -- along front direction

	-- Back wall (opposite of front, full width)
	local backWallCenter = Vector3.new(
		buildingCenter.X - front.X * halfD,
		wallY,
		buildingCenter.Z - front.Z * halfD
	)
	local backWallSizeX = math.abs(side.X) * BUILDING_W + math.abs(front.X) * WALL_THICKNESS
	local backWallSizeZ = math.abs(side.Z) * BUILDING_W + math.abs(front.Z) * WALL_THICKNESS
	makePart(
		folder, "WallBack",
		Vector3.new(backWallSizeX, WALL_HEIGHT, backWallSizeZ),
		CFrame.new(backWallCenter),
		WALL_COLOR, 0, Enum.Material.Concrete, true
	)

	-- Left side wall (full depth)
	local leftWallCenter = Vector3.new(
		buildingCenter.X - side.X * halfW,
		wallY,
		buildingCenter.Z - side.Z * halfW
	)
	local sideWallSizeX = math.abs(front.X) * BUILDING_D + math.abs(side.X) * WALL_THICKNESS
	local sideWallSizeZ = math.abs(front.Z) * BUILDING_D + math.abs(side.Z) * WALL_THICKNESS
	makePart(
		folder, "WallLeft",
		Vector3.new(sideWallSizeX, WALL_HEIGHT, sideWallSizeZ),
		CFrame.new(leftWallCenter),
		WALL_COLOR, 0, Enum.Material.Concrete, true
	)

	-- Right side wall (full depth)
	local rightWallCenter = Vector3.new(
		buildingCenter.X + side.X * halfW,
		wallY,
		buildingCenter.Z + side.Z * halfW
	)
	makePart(
		folder, "WallRight",
		Vector3.new(sideWallSizeX, WALL_HEIGHT, sideWallSizeZ),
		CFrame.new(rightWallCenter),
		WALL_COLOR, 0, Enum.Material.Concrete, true
	)

	-- Front wall: two segments with ENTRANCE_GAP in the center
	-- Front face is at: buildingCenter + front * halfD
	local frontFaceOffset = halfD  -- distance from building center to front face along front axis
	local frontWallBaseX = buildingCenter.X + front.X * frontFaceOffset
	local frontWallBaseZ = buildingCenter.Z + front.Z * frontFaceOffset
	local segmentWidth = (BUILDING_W - ENTRANCE_GAP) / 2

	-- Front wall left segment
	local fwLeftCenter = Vector3.new(
		frontWallBaseX - side.X * (ENTRANCE_GAP / 2 + segmentWidth / 2),
		wallY,
		frontWallBaseZ - side.Z * (ENTRANCE_GAP / 2 + segmentWidth / 2)
	)
	local fwSizeX = math.abs(side.X) * segmentWidth + math.abs(front.X) * WALL_THICKNESS
	local fwSizeZ = math.abs(side.Z) * segmentWidth + math.abs(front.Z) * WALL_THICKNESS
	makePart(
		folder, "WallFrontLeft",
		Vector3.new(fwSizeX, WALL_HEIGHT, fwSizeZ),
		CFrame.new(fwLeftCenter),
		WALL_COLOR, 0, Enum.Material.Concrete, true
	)

	-- Front wall right segment
	local fwRightCenter = Vector3.new(
		frontWallBaseX + side.X * (ENTRANCE_GAP / 2 + segmentWidth / 2),
		wallY,
		frontWallBaseZ + side.Z * (ENTRANCE_GAP / 2 + segmentWidth / 2)
	)
	makePart(
		folder, "WallFrontRight",
		Vector3.new(fwSizeX, WALL_HEIGHT, fwSizeZ),
		CFrame.new(fwRightCenter),
		WALL_COLOR, 0, Enum.Material.Concrete, true
	)

	-- ----------------------------------------------------------------
	-- Flat roof (overhangs walls by ROOF_OVERHANG on all sides)
	-- ----------------------------------------------------------------
	local roofW = BUILDING_W + ROOF_OVERHANG * 2
	local roofD = BUILDING_D + ROOF_OVERHANG * 2
	local roofY = foundTopY + WALL_HEIGHT + ROOF_THICKNESS / 2
	local roofSizeX = math.abs(side.X) * roofW + math.abs(front.X) * roofD
	local roofSizeZ = math.abs(side.Z) * roofW + math.abs(front.Z) * roofD
	makePart(
		folder, "Roof",
		Vector3.new(roofSizeX, ROOF_THICKNESS, roofSizeZ),
		CFrame.new(Vector3.new(buildingCenter.X, roofY, buildingCenter.Z)),
		ROOF_COLOR, 0, Enum.Material.SmoothPlastic, true
	)

	-- ----------------------------------------------------------------
	-- 5 vertical neon red bars on the front face
	-- Evenly spaced across the front face width (BUILDING_W)
	-- They sit flush against the front wall, on the exterior side
	-- ----------------------------------------------------------------
	local barY = foundTopY + NEON_BAR_H / 2 + (WALL_HEIGHT - NEON_BAR_H) / 2  -- vertically centered on wall
	local spacing = BUILDING_W / (NEON_BAR_COUNT + 1)
	-- Bar depth direction is along front axis
	local barSizeX = math.abs(side.X) * NEON_BAR_W + math.abs(front.X) * NEON_BAR_D
	local barSizeZ = math.abs(side.Z) * NEON_BAR_W + math.abs(front.Z) * NEON_BAR_D

	for i = 1, NEON_BAR_COUNT do
		local sideOffset = -BUILDING_W / 2 + spacing * i
		local barCenter = Vector3.new(
			frontWallBaseX + side.X * sideOffset + front.X * (WALL_THICKNESS / 2 + NEON_BAR_D / 2),
			barY,
			frontWallBaseZ + side.Z * sideOffset + front.Z * (WALL_THICKNESS / 2 + NEON_BAR_D / 2)
		)
		makePart(
			folder, "NeonBar" .. i,
			Vector3.new(barSizeX, NEON_BAR_H, barSizeZ),
			CFrame.new(barCenter),
			NEON_RED, 0, Enum.Material.Neon, false
		)
	end

	-- ----------------------------------------------------------------
	-- Level-based visual upgrades
	-- ----------------------------------------------------------------

	if level >= 1 then
		-- Gold corner accent posts at building corners
		local goldColor = Color3.fromRGB(255, 200, 0)
		local postH = WALL_HEIGHT + FOUNDATION_HEIGHT + 1
		local postY = foundTopY + postH / 2 - FOUNDATION_HEIGHT
		local corners = {
			{ side_sign =  1, front_sign =  1 },
			{ side_sign = -1, front_sign =  1 },
			{ side_sign =  1, front_sign = -1 },
			{ side_sign = -1, front_sign = -1 },
		}
		for ci, c in ipairs(corners) do
			local postCenter = Vector3.new(
				buildingCenter.X + side.X * c.side_sign * halfW + front.X * c.front_sign * halfD,
				postY,
				buildingCenter.Z + side.Z * c.side_sign * halfW + front.Z * c.front_sign * halfD
			)
			makePart(
				folder, "GoldPost" .. ci,
				Vector3.new(1, postH, 1),
				CFrame.new(postCenter),
				goldColor, 0, Enum.Material.Metal, true
			)
		end
	end

	if level >= 2 then
		-- Neon blue glow strip around roof edge (4 thin strips)
		local blueNeon = Color3.fromRGB(30, 180, 255)
		local stripThick = 0.4
		local stripH = 0.5
		local stripY = roofY + ROOF_THICKNESS / 2 + stripH / 2

		-- Along side axis, front edge
		local rfFrontCenter = Vector3.new(
			buildingCenter.X + front.X * (roofD / 2),
			stripY,
			buildingCenter.Z + front.Z * (roofD / 2)
		)
		local rfFrontSizeX = math.abs(side.X) * roofW + math.abs(front.X) * stripThick
		local rfFrontSizeZ = math.abs(side.Z) * roofW + math.abs(front.Z) * stripThick
		local rfFront = makePart(folder, "RoofGlowFront", Vector3.new(rfFrontSizeX, stripH, rfFrontSizeZ), CFrame.new(rfFrontCenter), blueNeon, 0, Enum.Material.Neon, false)

		local rfBackCenter = Vector3.new(
			buildingCenter.X - front.X * (roofD / 2),
			stripY,
			buildingCenter.Z - front.Z * (roofD / 2)
		)
		makePart(folder, "RoofGlowBack", Vector3.new(rfFrontSizeX, stripH, rfFrontSizeZ), CFrame.new(rfBackCenter), blueNeon, 0, Enum.Material.Neon, false)

		local rfLeftCenter = Vector3.new(
			buildingCenter.X - side.X * (roofW / 2),
			stripY,
			buildingCenter.Z - side.Z * (roofW / 2)
		)
		local rfSideSizeX = math.abs(front.X) * roofD + math.abs(side.X) * stripThick
		local rfSideSizeZ = math.abs(front.Z) * roofD + math.abs(side.Z) * stripThick
		makePart(folder, "RoofGlowLeft", Vector3.new(rfSideSizeX, stripH, rfSideSizeZ), CFrame.new(rfLeftCenter), blueNeon, 0, Enum.Material.Neon, false)

		local rfRightCenter = Vector3.new(
			buildingCenter.X + side.X * (roofW / 2),
			stripY,
			buildingCenter.Z + side.Z * (roofW / 2)
		)
		makePart(folder, "RoofGlowRight", Vector3.new(rfSideSizeX, stripH, rfSideSizeZ), CFrame.new(rfRightCenter), blueNeon, 0, Enum.Material.Neon, false)
	end

	if level >= 3 then
		-- Purple neon panels on side walls (exterior)
		local purpleNeon = Color3.fromRGB(180, 0, 255)
		local panelW = BUILDING_D - 2   -- slightly inset from corners
		local panelH = WALL_HEIGHT - 2
		local panelThick = 0.3
		local panelY = foundTopY + panelH / 2 + 1

		-- Left side panel
		local leftPanelCenter = Vector3.new(
			buildingCenter.X - side.X * (halfW + panelThick / 2),
			panelY,
			buildingCenter.Z - side.Z * (halfW + panelThick / 2)
		)
		local leftPanelSizeX = math.abs(front.X) * panelW + math.abs(side.X) * panelThick
		local leftPanelSizeZ = math.abs(front.Z) * panelW + math.abs(side.Z) * panelThick
		makePart(folder, "PurplePanelLeft", Vector3.new(leftPanelSizeX, panelH, leftPanelSizeZ), CFrame.new(leftPanelCenter), purpleNeon, 0.3, Enum.Material.Neon, false)

		-- Right side panel
		local rightPanelCenter = Vector3.new(
			buildingCenter.X + side.X * (halfW + panelThick / 2),
			panelY,
			buildingCenter.Z + side.Z * (halfW + panelThick / 2)
		)
		makePart(folder, "PurplePanelRight", Vector3.new(leftPanelSizeX, panelH, leftPanelSizeZ), CFrame.new(rightPanelCenter), purpleNeon, 0.3, Enum.Material.Neon, false)
	end

	if level >= 4 then
		-- Rainbow neon roof trim (replace blue strip with a sequence of colored trim)
		-- and gold panels on the side walls
		local rainbowColors = {
			Color3.fromRGB(255, 0,   0),
			Color3.fromRGB(255, 165, 0),
			Color3.fromRGB(255, 255, 0),
			Color3.fromRGB(0,   255, 0),
			Color3.fromRGB(0,   180, 255),
			Color3.fromRGB(128, 0,   255),
		}
		local segCount = #rainbowColors
		-- Replace the blue glow strips with rainbow by adding extra thin colored bands
		local stripY = roofY + ROOF_THICKNESS / 2 + 0.5 + 0.3  -- slightly above level 2 strip
		local bandH = 0.25
		local bandThick = 0.35

		for ci, col in ipairs(rainbowColors) do
			-- Distribute colors along the perimeter (simplified: one color per segment along front edge)
			local segOffset = -roofW / 2 + (ci - 0.5) * (roofW / segCount)
			local bandSizeX = math.abs(side.X) * (roofW / segCount) + math.abs(front.X) * bandThick
			local bandSizeZ = math.abs(side.Z) * (roofW / segCount) + math.abs(front.Z) * bandThick
			local bandCenter = Vector3.new(
				buildingCenter.X + front.X * (roofD / 2) + side.X * segOffset,
				stripY,
				buildingCenter.Z + front.Z * (roofD / 2) + side.Z * segOffset
			)
			makePart(folder, "RainbowTrim" .. ci, Vector3.new(bandSizeX, bandH, bandSizeZ), CFrame.new(bandCenter), col, 0, Enum.Material.Neon, false)
		end

		-- Gold panels on sides (overrides / supplements purple panels)
		local goldColor = Color3.fromRGB(255, 215, 0)
		local panelW = BUILDING_D - 2
		local panelH = WALL_HEIGHT - 2
		local panelThick = 0.35
		local panelY = foundTopY + panelH / 2 + 1

		local leftGoldCenter = Vector3.new(
			buildingCenter.X - side.X * (halfW + panelThick / 2 + 0.1),
			panelY,
			buildingCenter.Z - side.Z * (halfW + panelThick / 2 + 0.1)
		)
		local gpSizeX = math.abs(front.X) * panelW + math.abs(side.X) * panelThick
		local gpSizeZ = math.abs(front.Z) * panelW + math.abs(side.Z) * panelThick
		makePart(folder, "GoldPanelLeft", Vector3.new(gpSizeX, panelH, gpSizeZ), CFrame.new(leftGoldCenter), goldColor, 0, Enum.Material.Metal, false)

		local rightGoldCenter = Vector3.new(
			buildingCenter.X + side.X * (halfW + panelThick / 2 + 0.1),
			panelY,
			buildingCenter.Z + side.Z * (halfW + panelThick / 2 + 0.1)
		)
		makePart(folder, "GoldPanelRight", Vector3.new(gpSizeX, panelH, gpSizeZ), CFrame.new(rightGoldCenter), goldColor, 0, Enum.Material.Metal, false)
	end

	return buildingCenter, foundTopY, front, side
end

-- ============================================================
-- Build the name sign near road edge
-- ============================================================

local function buildSign(folder, plotCenter, groundY, front, playerName)
	-- Sign post at front edge of the plot
	local halfBase = BASE_SIZE / 2
	local postX = plotCenter.X + front.X * (halfBase - 1)
	local postZ = plotCenter.Z + front.Z * (halfBase - 1)
	local postBaseY = groundY + FLOOR_HEIGHT / 2
	local postH = 5
	local postY = postBaseY + postH / 2

	local post = makePart(
		folder, "SignPost",
		Vector3.new(0.4, postH, 0.4),
		CFrame.new(Vector3.new(postX, postY, postZ)),
		Color3.fromRGB(30, 30, 30), 0, Enum.Material.Metal, true
	)

	local boardY = postBaseY + postH + 1
	local signBoard = makePart(
		folder, "SignBoard",
		Vector3.new(7, 2, 0.4),
		CFrame.new(Vector3.new(postX, boardY, postZ)),
		Color3.fromRGB(20, 20, 20), 0, Enum.Material.SmoothPlastic, false
	)

	-- SurfaceGui on sign board face toward road
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize = Vector2.new(350, 100)
	surfaceGui.Parent = signBoard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = playerName
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Parent = surfaceGui
end

-- ============================================================
-- Compute slot grid positions inside the house
-- ============================================================

local function computeSlotPositions(buildingCenter, foundTopY, front, side, maxSlots)
	local slots = {}
	-- Grid starts at interior, centered on building, slightly offset toward back
	-- Slot Y is just above interior floor
	local slotY = foundTopY + 1.5

	-- Total grid extents
	local totalW = (SLOT_COLS - 1) * SLOT_SPACING_X
	local totalD = (SLOT_ROWS - 1) * SLOT_SPACING_Z

	-- Offset from building center: push slightly toward back (away from entrance)
	local backOffset = 2  -- studs toward back from building center
	local gridCenterX = buildingCenter.X - front.X * backOffset
	local gridCenterZ = buildingCenter.Z - front.Z * backOffset

	local count = 0
	for row = 0, SLOT_ROWS - 1 do
		for col = 0, SLOT_COLS - 1 do
			count = count + 1
			if count > maxSlots then
				break
			end
			local sideOff = -totalW / 2 + col * SLOT_SPACING_X
			local frontOff = -totalD / 2 + row * SLOT_SPACING_Z

			local slotPos = Vector3.new(
				gridCenterX + side.X * sideOff + front.X * frontOff,
				slotY,
				gridCenterZ + side.Z * sideOff + front.Z * frontOff
			)
			slots[count] = slotPos
		end
		if count > maxSlots then
			break
		end
	end

	return slots
end

-- ============================================================
-- Public: createBase
-- ============================================================

function BaseSystem.createBase(player, position, playerBases)
	local level = getLevel(player)
	local maxSlots = LEVEL_SLOTS[level] or LEVEL_SLOTS[0]

	local folder = Instance.new("Folder")
	folder.Name = player.Name .. "_Base"
	folder.Parent = workspace

	-- Plot ground (grass-coloured base slab)
	local groundY = position.Y
	local plotGround = makePart(
		folder, "PlotGround",
		Vector3.new(BASE_SIZE, FLOOR_HEIGHT, BASE_SIZE),
		CFrame.new(Vector3.new(position.X, groundY, position.Z)),
		Color3.fromRGB(100, 160, 60), 0, Enum.Material.Grass, true
	)

	-- Determine facing direction
	local front = getFrontDirection(position.X)
	local side = getSideDirection(front)

	-- Build the house, get building center and foundTopY back
	local buildingCenter, foundTopY, retFront, retSide = buildHouse(folder, position, groundY, level)

	-- Build the name sign near road edge
	buildSign(folder, position, groundY, front, player.Name)

	-- Compute slot positions
	local slotPositions = computeSlotPositions(buildingCenter, foundTopY, front, side, maxSlots)
	local slotGrid = {}
	for i = 1, maxSlots do
		slotGrid[i] = false  -- false = free, true = occupied
	end

	-- Register in playerBases
	playerBases[player] = {
		folder = folder,
		position = position,
		buildingCenter = buildingCenter,
		lockShield = nil,
		isLocked = false,
		level = level,
		slotPositions = slotPositions,
		slotGrid = slotGrid,
		maxSlots = maxSlots,
	}

	return folder
end

-- ============================================================
-- Public: getNextSlot
-- Returns Vector3 of next free slot, or nil if full
-- ============================================================

function BaseSystem.getNextSlot(player, playerBases)
	local baseData = playerBases[player]
	if not baseData then
		return nil
	end

	for i = 1, baseData.maxSlots do
		if not baseData.slotGrid[i] then
			baseData.slotGrid[i] = true
			return baseData.slotPositions[i], i
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
	if slotIndex and baseData.slotGrid[slotIndex] ~= nil then
		baseData.slotGrid[slotIndex] = false
	end
end

-- ============================================================
-- Public: lockBase  (existing logic preserved)
-- ============================================================

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

-- ============================================================
-- Public: unlockBase  (existing logic preserved)
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
	baseData.isLocked = false
	player:SetAttribute("BaseIsLocked", false)
end

-- ============================================================
-- Public: isInBase  (existing logic preserved)
-- ============================================================

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

-- ============================================================
-- Public: teleportToBase  (existing logic preserved)
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

		-- Teleport ring effect
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.3, 8, 8)
		ring.CFrame = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Anchored = true
		ring.CanCollide = false
		ring.Color = Color3.fromRGB(0, 255, 255)
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
