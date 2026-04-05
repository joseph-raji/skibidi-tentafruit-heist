-- ShopSystem.lua
-- ModuleScript: Shop, gacha rolls, and brainrot spawning for Skibidi Tentafruit Heist

local RunService      = game:GetService("RunService")
local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

local BrainrotData  = require(ReplicatedStorage.Modules.BrainrotData)
local GameConfig    = require(ReplicatedStorage.Modules.GameConfig)

local CharacterBuilders
local ok, err = pcall(function()
	CharacterBuilders = require(game:GetService("ServerScriptService"):WaitForChild("CharacterBuilders", 5))
end)
if not ok then
	warn("CharacterBuilders failed to load: " .. tostring(err))
	CharacterBuilders = nil
end

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

-- BaseSystem reference (set via ShopSystem.setBaseSystem)
local BaseSystem = nil
function ShopSystem.setBaseSystem(bs) BaseSystem = bs end

-- StealSystem reference (set via ShopSystem.setStealSystem)
local StealSystem = nil
function ShopSystem.setStealSystem(ss) StealSystem = ss end

-- Pressure plate tracking tables
local _plateToBrainrot = {}   -- plate Part → body Part
local _brainrotToPlate = {}   -- body Part → plate Part
local _platePrompt     = {}   -- plate Part → ProximityPrompt
local _flyingBodies    = {}   -- body Part → true, skip bobbing during flight to base

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

-- =========================================================================
-- Internal: add a "Place here" ProximityPrompt to an empty slot plate
-- =========================================================================

local function addPlacementPrompt(emptyPlate, owner, slotIndex)
	local old = emptyPlate:FindFirstChildOfClass("ProximityPrompt")
	if old then old:Destroy() end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Place here"
	prompt.ObjectText            = "Slot " .. slotIndex
	prompt.HoldDuration          = 0
	prompt.MaxActivationDistance = 6
	prompt.Parent                = emptyPlate
	prompt.Triggered:Connect(function(trigPlayer)
		if trigPlayer ~= owner then return end
		ShopSystem.placeCarriedBrainrot(trigPlayer, slotIndex)
	end)
end

-- =========================================================================
-- Public: initBasePlates
-- Wire placement prompts on all existing empty slot plates for a player.
-- Call from Main.server.lua right after BaseSystem.claimBase.
-- =========================================================================

function ShopSystem.initBasePlates(player)
	local baseData = _playerBases[player]
	if not baseData or not baseData.emptyPlates then return end
	for slotIndex, ep in pairs(baseData.emptyPlates) do
		if ep and ep.Parent then
			addPlacementPrompt(ep, player, slotIndex)
		end
	end
end

-- =========================================================================
-- Public: placeCarriedBrainrot
-- Moves the player's currently-carried brainrot to a target slot.
-- =========================================================================

function ShopSystem.placeCarriedBrainrot(player, slotIndex)
	local brainrot = _carrying[player]
	if not brainrot then return end
	if _brainrotOwner[brainrot] ~= player then return end

	local baseData = _playerBases[player]
	if not baseData then return end

	if baseData.slotGrid[slotIndex] then
		NotificationEvent:FireClient(player, "That slot is already occupied!", Color3.fromRGB(255, 80, 80))
		return
	end

	local slotPos = baseData.slotPositions and baseData.slotPositions[slotIndex]
	if not slotPos then return end

	-- Read all attributes before destroying the model
	local bId    = brainrot:GetAttribute("BrainrotId") or ""
	local bName  = brainrot:GetAttribute("BrainrotName") or "Brainrot"
	local income = brainrot:GetAttribute("IncomePerSecond") or 1
	local oldSlot = brainrot:GetAttribute("SlotIndex")

	-- Clear carrying state
	_carrying[player] = nil
	player:SetAttribute("IsCarrying", false)
	player:SetAttribute("CarryingBrainrotName", "")

	-- Free old slot and remove its collect plate
	if oldSlot then
		ShopSystem.removePlate(brainrot)
		baseData.slotGrid[oldSlot] = false
		-- Recreate empty plate for old slot with placement prompt
		local oldPlatePos = baseData.platePositions and baseData.platePositions[oldSlot]
		if oldPlatePos and baseData.folder and baseData.folder.Parent then
			if not baseData.emptyPlates then baseData.emptyPlates = {} end
			local ep = Instance.new("Part")
			ep.Name         = "EmptySlotPlate_" .. oldSlot
			ep.Size         = Vector3.new(4, 0.3, 4)
			ep.Material     = Enum.Material.Neon
			ep.Color        = Color3.fromRGB(50, 50, 55)
			ep.Transparency = 0.4
			ep.CanCollide   = false
			ep.Anchored     = true
			ep.CFrame       = CFrame.new(oldPlatePos)
			ep.Parent       = baseData.folder
			baseData.emptyPlates[oldSlot] = ep
			addPlacementPrompt(ep, player, oldSlot)
		end
	end

	-- Destroy old model
	_brainrotOwner[brainrot] = nil
	local m = brainrot.Parent
	if m and m:IsA("Model") then m:Destroy() elseif brainrot and brainrot.Parent then brainrot:Destroy() end

	-- Resolve brainrot data (fallback for fused/ad-hoc brainrots)
	local brainrotData = BrainrotData.getById(bId)
	if not brainrotData then
		brainrotData = {
			id = bId, name = bName, income = income,
			rarity = "Legendary", size = 2, cost = nil,
			color = BrickColor.new("Bright yellow"),
			glowColor = Color3.fromRGB(255, 220, 0),
		}
	end

	-- Spawn at new slot position
	local dest = Vector3.new(slotPos.X, slotPos.Y + brainrotData.size / 2, slotPos.Z)
	ShopSystem.spawnBrainrot(brainrotData, dest, player, _brainrotOwner, slotIndex)
	NotificationEvent:FireClient(player, bName .. " moved to slot " .. slotIndex .. "!", Color3.fromRGB(200, 200, 255))
end

-- =========================================================================
-- Public: releaseSlot
-- Frees the slot for a player when a brainrot is removed or stolen.
-- =========================================================================

function ShopSystem.releaseSlot(player, slotIndex)
	if slotIndex == nil or slotIndex < 1 then return end
	local baseData = _playerBases[player]
	if not baseData then return end
	if baseData.slotGrid then
		baseData.slotGrid[slotIndex] = false
	end
	-- Recreate the empty visual plate for this slot
	local platePos = baseData.platePositions and baseData.platePositions[slotIndex]
	if platePos and baseData.folder and baseData.folder.Parent then
		if not baseData.emptyPlates then baseData.emptyPlates = {} end
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
		-- Wire placement prompt so owner can press E here
		addPlacementPrompt(ep, player, slotIndex)
	end
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
-- Internal: count brainrots currently owned by a player
-- =========================================================================

local function countPlayerBrainrots(player, brainrotOwner)
	local count = 0
	for _, owner in pairs(brainrotOwner) do
		if owner == player then
			count = count + 1
		end
	end
	return count
end

-- =========================================================================
-- Public: removePlate
-- Cleans up the pressure plate associated with a brainrot body.
-- =========================================================================

function ShopSystem.removePlate(body)
	local plate = _brainrotToPlate[body]
	if plate and plate.Parent then
		plate:Destroy()
	end
	_brainrotToPlate[body] = nil
	if plate then
		_plateToBrainrot[plate] = nil
		_platePrompt[plate] = nil
	end
end

-- =========================================================================
-- Public: spawnBrainrot
-- =========================================================================

function ShopSystem.spawnBrainrot(brainrotData, position, owner, brainrotOwner, slotIndex)
	local s = brainrotData.size  -- base size unit

	-- -----------------------------------------------------------------------
	-- Model container
	-- -----------------------------------------------------------------------
	local model = Instance.new("Model")
	model.Name = "BrainrotChar_" .. brainrotData.name
	model.Parent = workspace

	-- -----------------------------------------------------------------------
	-- Build the humanoid fruit character
	-- -----------------------------------------------------------------------
	local body
	if CharacterBuilders then
		body = CharacterBuilders.build(brainrotData.id, position, model, s, brainrotData)
	end
	if not body then
		-- Fallback: simple sphere so the game never crashes
		body = Instance.new("Part")
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
	billboard.StudsOffset   = Vector3.new(0, s * 2.0 + 1.2, 0)
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
		-- Conveyor shop item: name + price only (details in Pokédex)
		billboard.Size = UDim2.new(0, 180, 0, 60)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size            = UDim2.new(1, 0, 0.5, 0)
		nameLabel.Position        = UDim2.new(0, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text            = brainrotData.name
		nameLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeTransparency = 0.4
		nameLabel.TextScaled      = true
		nameLabel.Font            = Enum.Font.GothamBold
		nameLabel.Parent          = billboard

		local costLabel = Instance.new("TextLabel")
		costLabel.Size            = UDim2.new(1, 0, 0.5, 0)
		costLabel.Position        = UDim2.new(0, 0, 0.5, 0)
		costLabel.BackgroundTransparency = 1
		costLabel.Text            = brainrotData.cost and ("$" .. brainrotData.cost) or "GACHA ONLY"
		costLabel.TextColor3      = Color3.fromRGB(255, 220, 0)
		costLabel.TextStrokeTransparency = 0.2
		costLabel.TextScaled      = true
		costLabel.Font            = Enum.Font.GothamBold
		costLabel.Parent          = billboard
	end

	-- -----------------------------------------------------------------------
	-- Register ownership on the body (PrimaryPart)
	-- -----------------------------------------------------------------------
	if owner then
		brainrotOwner[body] = owner
		body:SetAttribute("IncomePerSecond", brainrotData.income)
		body:SetAttribute("BrainrotId", brainrotData.id)
		body:SetAttribute("BrainrotName", brainrotData.name)
		-- Store the slot index so it can be freed when this brainrot is removed
		if slotIndex then
			body:SetAttribute("SlotIndex", slotIndex)
		end
		-- Set up E-to-steal ProximityPrompt and touch interactions
		if StealSystem then
			StealSystem.setupBrainrotTouchEvents(body, owner, _playerBases, _brainrotOwner, _carrying, _playerCollection)
		end
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

		-- -----------------------------------------------------------------------
		-- Pressure plate — flat pad at the slot's plate position
		-- -----------------------------------------------------------------------
		local platePos = position  -- fallback to spawn position
		if _playerBases[owner] and _playerBases[owner].platePositions and slotIndex then
			platePos = _playerBases[owner].platePositions[slotIndex]
		end

		-- Remove empty placeholder plate for this slot if present
		local baseDataForPlate = _playerBases[owner]
		if baseDataForPlate and baseDataForPlate.emptyPlates and slotIndex then
			local ep = baseDataForPlate.emptyPlates[slotIndex]
			if ep and ep.Parent then ep:Destroy() end
			baseDataForPlate.emptyPlates[slotIndex] = nil
		end

		local plate = Instance.new("Part")
		plate.Name        = "CollectPlate_" .. (slotIndex or 0)
		plate.Size        = Vector3.new(4, 0.3, 4)
		plate.Material    = Enum.Material.Neon
		plate.Color       = Color3.fromRGB(30, 80, 30)
		plate.CanCollide  = false
		plate.Anchored    = true
		plate.CFrame      = CFrame.new(platePos)
		plate.Parent      = workspace

		-- BillboardGui showing accumulated money
		local plateBB = Instance.new("BillboardGui")
		plateBB.StudsOffset = Vector3.new(0, 2, 0)
		plateBB.Size        = UDim2.new(0.1, 0, 0.1, 0)
		plateBB.AlwaysOnTop = false
		plateBB.Parent      = plate

		local plateLabel = Instance.new("TextLabel")
		plateLabel.Size                   = UDim2.new(1, 0, 1, 0)
		plateLabel.BackgroundTransparency = 1
		plateLabel.Text                   = "$0"
		plateLabel.TextColor3             = Color3.fromRGB(100, 255, 100)
		plateLabel.TextStrokeTransparency = 0.4
		plateLabel.TextScaled             = true
		plateLabel.Font                   = Enum.Font.GothamBold
		plateLabel.Parent                 = plateBB

		-- Link plate and body
		_plateToBrainrot[plate] = body
		_brainrotToPlate[body]  = plate

		-- Walk over the plate to collect money automatically
		plate.CanCollide = true

		local collectDebounce = {}
		plate.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then return end
			local trigPlayer = Players:GetPlayerFromCharacter(character)
			if not trigPlayer then return end
			if _brainrotOwner[body] ~= trigPlayer then return end
			if collectDebounce[trigPlayer] then return end

			local money = math.floor(body:GetAttribute("AccumulatedMoney") or 0)
			if money <= 0 then return end

			collectDebounce[trigPlayer] = true
			task.delay(1, function() collectDebounce[trigPlayer] = nil end)

			body:SetAttribute("AccumulatedMoney", 0)
			trigPlayer:SetAttribute("Money", (trigPlayer:GetAttribute("Money") or 0) + money)

			-- Update label immediately
			local gui = plate:FindFirstChildWhichIsA("BillboardGui")
			if gui then
				local lbl = gui:FindFirstChildWhichIsA("TextLabel")
				if lbl then lbl.Text = "$0" end
			end

			-- Flash plate to bright lime green
			TweenService:Create(plate, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 1, true), {
				Color = Color3.fromRGB(0, 255, 80),
				Transparency = 0.4,
			}):Play()

			NotificationEvent:FireClient(trigPlayer, "+" .. money .. "$", Color3.fromRGB(100, 255, 100))
		end)
	else
		-- -----------------------------------------------------------------------
		-- Conveyor brainrot: fly to buyer's base when purchased
		-- -----------------------------------------------------------------------
		if brainrotData.cost then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText          = "Buy  $" .. brainrotData.cost
			prompt.ObjectText          = brainrotData.name
			prompt.HoldDuration        = 0
			prompt.MaxActivationDistance = 8
			prompt.Parent              = body

			prompt.Triggered:Connect(function(buyer)
				-- Check money
				local money = buyer:GetAttribute("Money") or 0
				if money < brainrotData.cost then
					NotificationEvent:FireClient(buyer, "Not enough money! Need $" .. brainrotData.cost, Color3.fromRGB(255, 80, 80))
					return
				end
				-- Check slot
				local slotIndex, slotPos = BaseSystem.getNextSlot(buyer, _playerBases)
				if not slotIndex then
					NotificationEvent:FireClient(buyer, "Base full! Rebirth to unlock more floors.", Color3.fromRGB(255, 180, 0))
					return
				end
				-- Deduct money; disable prompt so only one person buys this instance
				buyer:SetAttribute("Money", money - brainrotData.cost)
				prompt:Destroy()
				-- Mark as flying so conveyor stops moving it
				_flyingBodies[body] = true
				-- Assign temp ownership so others can steal it mid-flight
				_brainrotOwner[body] = buyer
				body:SetAttribute("IncomePerSecond", brainrotData.income)
				body:SetAttribute("BrainrotId",      brainrotData.id)
				body:SetAttribute("BrainrotName",    brainrotData.name)
				if StealSystem then
					StealSystem.setupBrainrotTouchEvents(body, buyer, _playerBases, _brainrotOwner, _carrying, _playerCollection)
				end

				-- Heartbeat-based flight so it can be intercepted
				local FLIGHT_SPEED = 18  -- studs / second
				local dest = Vector3.new(slotPos.X, slotPos.Y + brainrotData.size / 2, slotPos.Z)
				local conn
				conn = RunService.Heartbeat:Connect(function(dt)
					if not body or not body.Parent then
						conn:Disconnect(); _flyingBodies[body] = nil
						ShopSystem.releaseSlot(buyer, slotIndex)
						return
					end
					-- If intercepted (another player is now carrying it), stop flight
					if isBeingCarried(body) then
						conn:Disconnect(); _flyingBodies[body] = nil
						ShopSystem.releaseSlot(buyer, slotIndex)
						return
					end
					-- If ownership changed (stolen during flight without carrying), stop
					if _brainrotOwner[body] ~= buyer then
						conn:Disconnect(); _flyingBodies[body] = nil
						ShopSystem.releaseSlot(buyer, slotIndex)
						return
					end
					local dir = dest - body.Position
					local dist = dir.Magnitude
					if dist < 1 then
						-- Arrived
						conn:Disconnect(); _flyingBodies[body] = nil
						body.CFrame = CFrame.new(dest); body.Anchored = true
						if buyer and buyer.Parent then
							ShopSystem.spawnBrainrot(brainrotData, dest, buyer, _brainrotOwner, slotIndex)
							if not _playerCollection[buyer] then _playerCollection[buyer] = {} end
							_playerCollection[buyer][brainrotData.id] = (_playerCollection[buyer][brainrotData.id] or 0) + 1
							CollectionUpdatedEvent:FireClient(buyer, _playerCollection[buyer])
							NotificationEvent:FireClient(buyer, "You received " .. brainrotData.name .. "!", Color3.fromRGB(100, 255, 100))
						end
						local m = body.Parent
						if m and m:IsA("Model") then m:Destroy() elseif body and body.Parent then body:Destroy() end
						return
					end
					local step = math.min(FLIGHT_SPEED * dt, dist)
					body.CFrame = CFrame.new(body.Position + dir.Unit * step) * CFrame.Angles(0, tick() * 2, 0)
				end)
			end)
		end
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
		if _flyingBodies[body] then return end

		local t     = tick() + timeOffset
		local bobY  = math.sin(t * BOB_SPEED) * BOB_AMP
		local angle = (tick() * SPIN_SPEED) % (2 * math.pi)

		body.CFrame = CFrame.new(
			body.Position.X,
			(body:GetAttribute("BaseY") or baseY) + bobY,
			body.Position.Z
		) * CFrame.Angles(0, angle, 0)
	end)

	return body
end

-- =========================================================================
-- RunService: update plate BillboardGui text (throttled to ~1 second)
-- =========================================================================

local lastPlateUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastPlateUpdate < 1 then return end
	lastPlateUpdate = now
	for plate, body in pairs(_plateToBrainrot) do
		if plate.Parent and body.Parent then
			local amt = math.floor(body:GetAttribute("AccumulatedMoney") or 0)
			local amtText = "$" .. amt
			local gui = plate:FindFirstChildWhichIsA("BillboardGui")
			if gui then
				local label = gui:FindFirstChildWhichIsA("TextLabel")
				if label then label.Text = amtText end
			end
			-- Dim when empty, bright when has money
			plate.Color = amt > 0 and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(30, 80, 30)
		else
			-- Brainrot or plate was destroyed, clean up
			_plateToBrainrot[plate] = nil
			if body then _brainrotToPlate[body] = nil end
		end
	end
end)

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

	-- Check slot limit before spending money
	local slotIndex, slotPos = BaseSystem.getNextSlot(player, _playerBases)
	if not slotIndex then
		NotificationEvent:FireClient(player, "Base full! Rebirth to unlock more floors.", Color3.fromRGB(255, 180, 0))
		return false
	end

	-- Deduct money
	player:SetAttribute("Money", currentMoney - data.cost)

	-- Spawn at slot surface + half brainrot height so it rests on the floor
	local spawnPos = Vector3.new(slotPos.X, slotPos.Y + data.size / 2, slotPos.Z)
	ShopSystem.spawnBrainrot(data, spawnPos, player, brainrotOwner, slotIndex)

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

	-- Check slot limit before spending money
	local slotIndex, slotPos = BaseSystem.getNextSlot(player, _playerBases)
	if not slotIndex then
		NotificationEvent:FireClient(player, "Base full! Rebirth to unlock more floors.", Color3.fromRGB(255, 180, 0))
		return nil
	end

	-- Deduct cost
	player:SetAttribute("Money", currentMoney - GACHA_COST)

	-- Roll
	local result = BrainrotData.gachaRoll()

	-- Spawn at slot surface + half brainrot height so it rests on the floor
	local spawnPos = Vector3.new(slotPos.X, slotPos.Y + result.size / 2, slotPos.Z)
	ShopSystem.spawnBrainrot(result, spawnPos, player, brainrotOwner, slotIndex)

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
			-- Body was purchased and is flying to a base — stop conveyor movement
			if _flyingBodies[body] then
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
	-- -----------------------------------------------------------------------
	-- Single spawn loop: 1 brainrot every 2 seconds (weighted random by rarity)
	-- -----------------------------------------------------------------------
	task.spawn(function()
		while true do
			task.wait(4)
			local chosen = BrainrotData.gachaRoll()
			if chosen then
				local spawnPos = Vector3.new(BELT_START_X, BELT_Y + chosen.size / 2 + 0.3, 0)
				local body = ShopSystem.spawnBrainrot(chosen, spawnPos, nil, _brainrotOwner, nil)
				if body then
					conveyorItems[body] = true
				end
			end
		end
	end)

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

-- =========================================================================
-- Public: createFusionMachine
-- Fusion pad: carry two brainrots here to merge them into a stronger one.
-- =========================================================================

local fusionQueue = {}  -- [player] → { part, income, name, id }

function ShopSystem.createFusionMachine()
	local padY = BELT_Y + 0.25

	local fusionPad = Instance.new("Part")
	fusionPad.Name      = "FusionPad"
	fusionPad.Anchored  = true
	fusionPad.Size      = Vector3.new(12, 0.5, 12)
	fusionPad.Position  = Vector3.new(50, padY, 0)
	fusionPad.Material  = Enum.Material.Neon
	fusionPad.Parent    = workspace

	RunService.Heartbeat:Connect(function()
		if not fusionPad or not fusionPad.Parent then return end
		local h = ((tick() * 0.35) + 0.55) % 1
		fusionPad.Color = Color3.fromHSV(h, 1, 1)
	end)

	local fusBB = Instance.new("BillboardGui")
	fusBB.Size        = UDim2.new(0, 260, 0, 90)
	fusBB.StudsOffset = Vector3.new(0, 7, 0)
	fusBB.Parent      = fusionPad

	local fusTitle = Instance.new("TextLabel")
	fusTitle.Size = UDim2.new(1, 0, 0.5, 0)
	fusTitle.BackgroundTransparency = 1
	fusTitle.Text = "⚡ FUSION MACHINE"
	fusTitle.TextScaled = true
	fusTitle.Font = Enum.Font.GothamBold
	fusTitle.TextColor3 = Color3.fromRGB(255, 255, 100)
	fusTitle.Parent = fusBB

	local fusHint = Instance.new("TextLabel")
	fusHint.Size = UDim2.new(1, 0, 0.5, 0)
	fusHint.Position = UDim2.new(0, 0, 0.5, 0)
	fusHint.BackgroundTransparency = 1
	fusHint.Text = "Carry 2 brainrots here to fuse!"
	fusHint.TextScaled = true
	fusHint.Font = Enum.Font.Gotham
	fusHint.TextColor3 = Color3.fromRGB(200, 200, 255)
	fusHint.Parent = fusBB

	local fusDebounce = {}
	fusionPad.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		if fusDebounce[player] then return end

		local brainrot = _carrying[player]
		if not brainrot then return end

		fusDebounce[player] = true
		task.delay(1.5, function() fusDebounce[player] = nil end)

		local income = brainrot:GetAttribute("IncomePerSecond") or 1
		local name   = brainrot:GetAttribute("BrainrotName") or "Brainrot"
		local bId    = brainrot:GetAttribute("BrainrotId") or "unknown"

		if not fusionQueue[player] then
			-- Slot 1: park the brainrot above the machine
			_carrying[player] = nil
			player:SetAttribute("IsCarrying", false)
			player:SetAttribute("CarryingBrainrotName", "")
			brainrot.Anchored = true
			brainrot.CFrame = CFrame.new(50, padY + 5, 0)
			_brainrotOwner[brainrot] = player
			fusionQueue[player] = { part = brainrot, income = income, name = name, id = bId }
			NotificationEvent:FireClient(player, "Brainrot 1 loaded! Bring a second one to fuse.", Color3.fromRGB(100, 200, 255))
		else
			-- Slot 2: fuse!
			local first = fusionQueue[player]
			fusionQueue[player] = nil

			_carrying[player] = nil
			player:SetAttribute("IsCarrying", false)
			player:SetAttribute("CarryingBrainrotName", "")

			-- Destroy both parts
			local firstPart = first.part
			_brainrotOwner[firstPart] = nil
			_brainrotOwner[brainrot]  = nil
			local function destroyModel(part)
				if not part or not part.Parent then return end
				local m = part.Parent
				if m and m:IsA("Model") then m:Destroy() else part:Destroy() end
			end
			destroyModel(firstPart)
			destroyModel(brainrot)

			-- Build fused brainrotData
			local fusedIncome = first.income + income + 5
			local n1 = first.name:sub(1, 6)
			local n2 = name:sub(1, 6)
			local fusedData = {
				id        = "fused_" .. tostring(math.floor(tick())),
				name      = n1 .. "-" .. n2,
				income    = fusedIncome,
				rarity    = "Legendary",
				size      = 3,
				cost      = nil,
				color     = BrickColor.new("Bright yellow"),
				glowColor = Color3.fromRGB(255, 220, 0),
			}

			-- Spawn in player's base
			local slotIndex, slotPos = BaseSystem.getNextSlot(player, _playerBases)
			if slotIndex and slotPos then
				local dest = Vector3.new(slotPos.X, slotPos.Y + fusedData.size / 2, slotPos.Z)
				ShopSystem.spawnBrainrot(fusedData, dest, player, _brainrotOwner, slotIndex)
				NotificationEvent:FireClient(player, "FUSION! " .. fusedData.name .. " earns $" .. fusedIncome .. "/s!", Color3.fromRGB(255, 220, 0))
			else
				NotificationEvent:FireClient(player, "Base full — fusion failed! Free a slot first.", Color3.fromRGB(255, 80, 80))
			end
		end
	end)
end

return ShopSystem
