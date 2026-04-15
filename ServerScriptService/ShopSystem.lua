-- ShopSystem.lua
-- ModuleScript: Shop, gacha rolls, and skin spawning for Skibidi Tentafruit Heist

local RunService      = game:GetService("RunService")
local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

local SkinData  = require(ReplicatedStorage.Modules.SkinData)
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
local NotificationEvent      = RemoteEvents:WaitForChild("Notification")
local CollectionUpdatedEvent = RemoteEvents:WaitForChild("CollectionUpdated")
local OpenFusionEvent        = RemoteEvents:WaitForChild("OpenFusion")
local FuseOptionsEvent       = RemoteEvents:WaitForChild("FuseOptions")
local GachaResultEvent       = RemoteEvents:WaitForChild("GachaResult")

local ShopSystem = {}

-- =========================================================================
-- Module-level state (set via init / setCarrying)
-- =========================================================================

local _playerBases      = {}
local _skinOwner    = {}
local _playerCollection = {}
local _carrying         = {}

-- BaseSystem reference (set via ShopSystem.setBaseSystem)
local BaseSystem = nil
function ShopSystem.setBaseSystem(bs) BaseSystem = bs end

-- StealSystem reference (set via ShopSystem.setStealSystem)
local StealSystem = nil
function ShopSystem.setStealSystem(ss) StealSystem = ss end

-- Pressure plate tracking tables
local _plateToSkin = {}   -- plate Part → body Part
local _skinToPlate = {}   -- body Part → plate Part
local _platePrompt     = {}   -- plate Part → ProximityPrompt
local _flyingBodies    = {}   -- body Part → true, skip bobbing during flight to base

local GACHA_COST = 0          -- Free spins
local GACHA_COOLDOWN = 1800   -- 30 minutes in seconds
local _gachaCooldown = {}     -- [player] → last spin timestamp

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

local function isBeingCarried(skinPart)
	for _, carried in pairs(_carrying) do
		if carried == skinPart then
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
		ShopSystem.placeCarriedSkin(trigPlayer, slotIndex)
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
-- Public: placeCarriedSkin
-- Moves the player's currently-carried skin to a target slot.
-- =========================================================================

function ShopSystem.placeCarriedSkin(player, slotIndex)
	local skin = _carrying[player]
	if not skin then return end
	if _skinOwner[skin] ~= player then return end

	local baseData = _playerBases[player]
	if not baseData then return end

	if baseData.slotGrid[slotIndex] then
		NotificationEvent:FireClient(player, "That slot is already occupied!", Color3.fromRGB(255, 80, 80))
		return
	end

	local slotPos = baseData.slotPositions and baseData.slotPositions[slotIndex]
	if not slotPos then return end

	-- Read all attributes before destroying the model
	local bId    = skin:GetAttribute("SkinId") or ""
	local bName  = skin:GetAttribute("SkinName") or "Skin"
	local income = skin:GetAttribute("IncomePerSecond") or 1
	local oldSlot = skin:GetAttribute("SlotIndex")

	-- Clear carrying state
	_carrying[player] = nil
	player:SetAttribute("IsCarrying", false)
	player:SetAttribute("CarryingSkinName", "")

	-- Remove the collection plate tied to this skin.
	-- The old slot was already freed (and its empty plate recreated) when the
	-- player first picked up the skin in startCarrying → releaseSlot.
	if oldSlot then
		ShopSystem.removePlate(skin)
		-- Guard: if slot was somehow not freed yet (e.g. direct purchase path), free it now.
		if baseData.slotGrid[oldSlot] then
			baseData.slotGrid[oldSlot] = false
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
	end

	-- Destroy old model
	_skinOwner[skin] = nil
	local m = skin.Parent
	if m and m:IsA("Model") then m:Destroy() elseif skin and skin.Parent then skin:Destroy() end

	-- Resolve skin data (fallback for fused/ad-hoc skins)
	local skinData = SkinData.getById(bId)
	if not skinData then
		skinData = {
			id = bId, name = bName, income = income,
			rarity = "Legendary", size = 2, cost = nil,
			color = BrickColor.new("Bright yellow"),
			glowColor = Color3.fromRGB(255, 220, 0),
		}
	end

	-- Spawn at new slot position
	local dest = Vector3.new(slotPos.X, slotPos.Y + skinData.size / 2, slotPos.Z)
	ShopSystem.spawnSkin(skinData, dest, player, _skinOwner, slotIndex)
	NotificationEvent:FireClient(player, bName .. " moved to slot " .. slotIndex .. "!", Color3.fromRGB(200, 200, 255))
end

-- =========================================================================
-- Public: releaseSlot
-- Frees the slot for a player when a skin is removed or stolen.
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

function ShopSystem.init(playerBases, skinOwner, playerCollection)
	_playerBases      = playerBases
	_skinOwner    = skinOwner
	_playerCollection = playerCollection
end

function ShopSystem.setCarrying(carryingTable)
	_carrying = carryingTable
end

-- =========================================================================
-- Internal: count skins currently owned by a player
-- =========================================================================

local function countPlayerSkins(player, skinOwner)
	local count = 0
	for _, owner in pairs(skinOwner) do
		if owner == player then
			count = count + 1
		end
	end
	return count
end

-- =========================================================================
-- Public: removePlate
-- Cleans up the pressure plate associated with a skin body.
-- =========================================================================

function ShopSystem.removePlate(body)
	local plate = _skinToPlate[body]
	if plate and plate.Parent then
		plate:Destroy()
	end
	_skinToPlate[body] = nil
	if plate then
		_plateToSkin[plate] = nil
		_platePrompt[plate] = nil
	end
end

-- =========================================================================
-- Public: spawnSkin
-- =========================================================================

function ShopSystem.spawnSkin(skinData, position, owner, skinOwner, slotIndex)
	local s = skinData.size  -- base size unit

	-- -----------------------------------------------------------------------
	-- Model container
	-- -----------------------------------------------------------------------
	local model = Instance.new("Model")
	model.Name = "SkinChar_" .. skinData.name
	model.Parent = workspace

	-- -----------------------------------------------------------------------
	-- Build the humanoid fruit character
	-- -----------------------------------------------------------------------
	local body
	if CharacterBuilders then
		body = CharacterBuilders.build(skinData.id, position, model, s, skinData)
	end
	if not body then
		-- Fallback: simple sphere so the game never crashes
		body = Instance.new("Part")
		body.Name       = "Body"
		body.Shape      = Enum.PartType.Ball
		body.Material   = Enum.Material.Neon
		body.BrickColor = skinData.color
		body.Size       = Vector3.new(s, s, s)
		body.CFrame     = CFrame.new(position)
		body.Anchored   = true
		body.CanCollide = true
		body.CastShadow = true
		body.Parent     = model
		model.PrimaryPart = body
	end

	-- Store body size so carry-beside code can read it without knowing skin type
	body:SetAttribute("BodySize", s)

	-- -----------------------------------------------------------------------
	-- Glow (on body)
	-- -----------------------------------------------------------------------
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range      = 12
	light.Color      = skinData.glowColor
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
		-- Owned skin: 3-row billboard (name / income / rarity)
		billboard.Size = UDim2.new(0, 160, 0, 70)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size            = UDim2.new(1, 0, 0.38, 0)
		nameLabel.Position        = UDim2.new(0, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text            = skinData.name
		nameLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeTransparency = 0.4
		nameLabel.TextScaled      = true
		nameLabel.Font            = Enum.Font.GothamBold
		nameLabel.Parent          = billboard

		local incomeLabel = Instance.new("TextLabel")
		incomeLabel.Size            = UDim2.new(1, 0, 0.37, 0)
		incomeLabel.Position        = UDim2.new(0, 0, 0.38, 0)
		incomeLabel.BackgroundTransparency = 1
		incomeLabel.Text            = "$" .. skinData.income .. "/s"
		incomeLabel.TextColor3      = Color3.fromRGB(100, 255, 100)
		incomeLabel.TextStrokeTransparency = 0.4
		incomeLabel.TextScaled      = true
		incomeLabel.Font            = Enum.Font.Gotham
		incomeLabel.Parent          = billboard

		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size            = UDim2.new(1, 0, 0.25, 0)
		rarityLabel.Position        = UDim2.new(0, 0, 0.75, 0)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text            = skinData.rarity
		rarityLabel.TextColor3      = RARITY_COLOR[skinData.rarity] or Color3.fromRGB(255, 255, 255)
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
		nameLabel.Text            = skinData.name
		nameLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeTransparency = 0.4
		nameLabel.TextScaled      = true
		nameLabel.Font            = Enum.Font.GothamBold
		nameLabel.Parent          = billboard

		local costLabel = Instance.new("TextLabel")
		costLabel.Size            = UDim2.new(1, 0, 0.5, 0)
		costLabel.Position        = UDim2.new(0, 0, 0.5, 0)
		costLabel.BackgroundTransparency = 1
		costLabel.Text            = skinData.cost and ("$" .. skinData.cost) or "GACHA ONLY"
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
		skinOwner[body] = owner
		body:SetAttribute("IncomePerSecond", skinData.income)
		body:SetAttribute("SkinId", skinData.id)
		body:SetAttribute("SkinName", skinData.name)
		body:SetAttribute("OwnerName", owner.Name)
		-- Store the slot index so it can be freed when this skin is removed
		if slotIndex then
			body:SetAttribute("SlotIndex", slotIndex)
		end
		-- Set up E-to-steal ProximityPrompt and touch interactions
		if StealSystem then
			StealSystem.setupSkinTouchEvents(body, owner, _playerBases, _skinOwner, _carrying, _playerCollection)
		end
	end

	-- -----------------------------------------------------------------------
	-- Pressure plate (owned) vs buy prompt (conveyor)
	-- -----------------------------------------------------------------------
	if owner then
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
		_plateToSkin[plate] = body
		_skinToPlate[body]  = plate

		-- Walk over the plate to collect money automatically
		plate.CanCollide = true

		local collectDebounce = {}
		plate.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then return end
			local trigPlayer = Players:GetPlayerFromCharacter(character)
			if not trigPlayer then return end
			if _skinOwner[body] ~= trigPlayer then return end
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
		-- Conveyor skin: fly to buyer's base when purchased
		-- -----------------------------------------------------------------------
		if skinData.cost then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText          = "Buy  $" .. skinData.cost
			prompt.ObjectText          = skinData.name
			prompt.HoldDuration        = 0
			prompt.MaxActivationDistance = 8
			prompt.Parent              = body

			prompt.Triggered:Connect(function(buyer)
				-- Check money
				local money = buyer:GetAttribute("Money") or 0
				if money < skinData.cost then
					NotificationEvent:FireClient(buyer, "Not enough money! Need $" .. skinData.cost, Color3.fromRGB(255, 80, 80))
					return
				end
				-- Check slot
				local slotIndex, slotPos = BaseSystem.getNextSlot(buyer, _playerBases)
				if not slotIndex then
					NotificationEvent:FireClient(buyer, "Base full! Rebirth to unlock more floors.", Color3.fromRGB(255, 180, 0))
					return
				end
				-- Deduct money; disable prompt so only one person buys this instance
				buyer:SetAttribute("Money", money - skinData.cost)
				prompt:Destroy()
				-- Mark as flying so conveyor stops moving it
				_flyingBodies[body] = true
				-- Assign temp ownership so others can steal it mid-flight
				_skinOwner[body] = buyer
				body:SetAttribute("IncomePerSecond", skinData.income)
				body:SetAttribute("SkinId",      skinData.id)
				body:SetAttribute("SkinName",    skinData.name)
				if StealSystem then
					StealSystem.setupSkinTouchEvents(body, buyer, _playerBases, _skinOwner, _carrying, _playerCollection)
				end

				-- Ground-level walk: 3-segment path
			-- belt → just outside entrance (gap center) → just inside entrance → slot
				local WALK_SPEED = 14  -- studs / second
				local dest = Vector3.new(slotPos.X, slotPos.Y + skinData.size / 2, slotPos.Z)
				local startPos = body.Position
				local groundY = dest.Y

				local bd2 = _playerBases[buyer]
				local fs2  = bd2 and bd2.faceSign or 1
				local bp2  = bd2 and bd2.position or dest
				-- frontFaceX = basePos.X + faceSign*14  (halfDepth=20, center offset=6 → 20-6=14)
				local frontFaceX = bp2.X + fs2 * 14
				-- wp1: just outside the entrance gap, centered on base Z
				local wp1 = Vector3.new(frontFaceX + fs2 * 2, groundY, bp2.Z)
				-- wp2: just inside the entrance gap
				local wp2 = Vector3.new(frontFaceX - fs2 * 3, groundY, bp2.Z)

				local waypoints = { wp1, wp2, dest }
				local segment  = 1
				local segStart = startPos
				local segEnd   = waypoints[1]
				local segLen   = math.max(1, (segEnd - segStart).Magnitude)
				local t        = 0
				local conn
				conn = RunService.Heartbeat:Connect(function(dt)
					if not body or not body.Parent then
						conn:Disconnect(); _flyingBodies[body] = nil
						ShopSystem.releaseSlot(buyer, slotIndex)
						return
					end
					if isBeingCarried(body) then
						conn:Disconnect(); _flyingBodies[body] = nil
						ShopSystem.releaseSlot(buyer, slotIndex)
						return
					end
					if _skinOwner[body] ~= buyer then
						conn:Disconnect(); _flyingBodies[body] = nil
						ShopSystem.releaseSlot(buyer, slotIndex)
						return
					end
					t = t + (WALK_SPEED * dt) / segLen
					if t >= 1 then
						if segment < #waypoints then
							-- Advance to next segment
							segment  = segment + 1
							segStart = waypoints[segment - 1]
							segEnd   = waypoints[segment]
							segLen   = math.max(1, (segEnd - segStart).Magnitude)
							t = 0
							body.CFrame = CFrame.new(segStart)
						else
							-- Arrived at slot
							conn:Disconnect(); _flyingBodies[body] = nil
							body.CFrame = CFrame.new(dest); body.Anchored = true
							if buyer and buyer.Parent then
								ShopSystem.spawnSkin(skinData, dest, buyer, _skinOwner, slotIndex)
								if not _playerCollection[buyer] then _playerCollection[buyer] = {} end
								_playerCollection[buyer][skinData.id] = (_playerCollection[buyer][skinData.id] or 0) + 1
								CollectionUpdatedEvent:FireClient(buyer, _playerCollection[buyer])
								NotificationEvent:FireClient(buyer, "You received " .. skinData.name .. "!", Color3.fromRGB(100, 255, 100))
							end
							local m = body.Parent
							if m and m:IsA("Model") then m:Destroy() elseif body and body.Parent then body:Destroy() end
						end
						return
					end
					local pos = segStart:Lerp(segEnd, t)
					body.CFrame = CFrame.new(pos) * CFrame.Angles(0, tick() * 2, 0)
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
	for plate, body in pairs(_plateToSkin) do
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
			-- Skin or plate was destroyed, clean up
			_plateToSkin[plate] = nil
			if body then _skinToPlate[body] = nil end
		end
	end
end)

-- =========================================================================
-- Public: buySkin
-- =========================================================================

function ShopSystem.buySkin(player, skinId, playerBases, skinOwner, playerCollection)
	local data = SkinData.getById(skinId)
	if not data then
		warn("ShopSystem.buySkin: unknown skinId", skinId)
		return false
	end

	if data.cost == nil then
		NotificationEvent:FireClient(player, "This skin can only be obtained from the GACHA!", Color3.fromRGB(255, 80, 80))
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

	-- Spawn at slot surface + half skin height so it rests on the floor
	local spawnPos = Vector3.new(slotPos.X, slotPos.Y + data.size / 2, slotPos.Z)
	ShopSystem.spawnSkin(data, spawnPos, player, skinOwner, slotIndex)

	-- Update collection
	if not playerCollection[player] then
		playerCollection[player] = {}
	end
	playerCollection[player][skinId] = (playerCollection[player][skinId] or 0) + 1

	-- Fire events
	CollectionUpdatedEvent:FireClient(player, playerCollection[player])
	NotificationEvent:FireClient(player, "You bought " .. data.name .. "!", Color3.fromRGB(100, 255, 100))

	return true
end

-- =========================================================================
-- Public: spinGacha
-- =========================================================================

local GACHA_X = -18  -- gacha machine X position
local GACHA_Z = 0    -- gacha machine Z position

function ShopSystem.spinGacha(player, playerBases, skinOwner, playerCollection)
	-- 30-minute cooldown check
	local lastSpin = _gachaCooldown[player]
	if lastSpin then
		local elapsed = tick() - lastSpin
		if elapsed < GACHA_COOLDOWN then
			local remaining = math.ceil(GACHA_COOLDOWN - elapsed)
			local mins = math.floor(remaining / 60)
			local secs = remaining % 60
			NotificationEvent:FireClient(player,
				string.format("Gacha on cooldown! %d:%02d remaining.", mins, secs),
				Color3.fromRGB(255, 80, 80))
			return nil
		end
	end
	_gachaCooldown[player] = tick()

	-- Check slot limit
	local slotIndex, slotPos = BaseSystem.getNextSlot(player, _playerBases)
	if not slotIndex then
		NotificationEvent:FireClient(player, "Base full! Rebirth to unlock more floors.", Color3.fromRGB(255, 180, 0))
		_gachaCooldown[player] = nil  -- don't consume cooldown if base is full
		return nil
	end

	-- Roll
	local result = SkinData.gachaRoll()
	local dest = Vector3.new(slotPos.X, slotPos.Y + result.size / 2, slotPos.Z)

	-- Fire gacha result so client wheel animation can play
	GachaResultEvent:FireClient(player, {
		id     = result.id,
		name   = result.name,
		rarity = result.rarity,
		income = result.income,
	})

	-- Build actual skin character at the machine and walk it to base
	local walkStartPos = Vector3.new(GACHA_X, dest.Y, GACHA_Z)
	local walkModel = Instance.new("Model")
	walkModel.Name   = "GachaWalk_" .. result.name
	walkModel.Parent = workspace
	local walkBody
	if CharacterBuilders then
		walkBody = CharacterBuilders.build(result.id, walkStartPos, walkModel, result.size, result)
	end
	if not walkBody then
		walkBody = Instance.new("Part")
		walkBody.Name       = "Body"
		walkBody.Shape      = Enum.PartType.Ball
		walkBody.Material   = Enum.Material.Neon
		walkBody.BrickColor = result.color
		walkBody.Size       = Vector3.new(result.size, result.size, result.size)
		walkBody.CFrame     = CFrame.new(walkStartPos)
		walkBody.Anchored   = true
		walkBody.CanCollide = false
		walkBody.Parent     = walkModel
		walkModel.PrimaryPart = walkBody
	end
	walkBody.Anchored   = true
	walkBody.CanCollide = false
	_flyingBodies[walkBody] = true

	local bd  = _playerBases[player]
	local fs  = bd and bd.faceSign or 1
	local bp  = bd and bd.position or dest
	local frontFaceX = bp.X + fs * 14
	local wp1 = Vector3.new(frontFaceX + fs * 2, dest.Y, bp.Z)
	local wp2 = Vector3.new(frontFaceX - fs * 3, dest.Y, bp.Z)
	local waypoints   = {wp1, wp2, dest}
	local segIdx      = 1
	local segStartPos = walkStartPos
	local segEndPos   = waypoints[1]
	local segLen      = math.max(1, (segEndPos - segStartPos).Magnitude)
	local walkT       = 0
	local WALK_SPEED  = 14
	local walkConn
	walkConn = RunService.Heartbeat:Connect(function(dt)
		if not walkBody or not walkBody.Parent then
			walkConn:Disconnect(); _flyingBodies[walkBody] = nil; return
		end
		walkT = walkT + (WALK_SPEED * dt) / segLen
		if walkT >= 1 then
			if segIdx < #waypoints then
				segIdx      = segIdx + 1
				segStartPos = waypoints[segIdx - 1]
				segEndPos   = waypoints[segIdx]
				segLen      = math.max(1, (segEndPos - segStartPos).Magnitude)
				walkT       = 0
				walkBody.CFrame = CFrame.new(segStartPos)
			else
				walkConn:Disconnect(); _flyingBodies[walkBody] = nil
				walkModel:Destroy()
				if player and player.Parent then
					ShopSystem.spawnSkin(result, dest, player, skinOwner, slotIndex)
					if not playerCollection[player] then playerCollection[player] = {} end
					playerCollection[player][result.id] = (playerCollection[player][result.id] or 0) + 1
					CollectionUpdatedEvent:FireClient(player, playerCollection[player])
					local rc = RARITY_COLOR[result.rarity] or Color3.fromRGB(255, 255, 255)
					NotificationEvent:FireClient(player, "Gacha: [" .. result.rarity .. "] " .. result.name .. "!", rc)
				end
			end
			return
		end
		walkBody.CFrame = CFrame.new(segStartPos:Lerp(segEndPos, walkT))
	end)

	return result
end

-- =========================================================================
-- Public: createShopPads  (now a conveyor belt shop)
-- =========================================================================

local BELT_LENGTH  = 210  -- spans Z=-105 to Z=105 (all 8 bases)
local BELT_WIDTH   = 8    -- studs wide along X
local BELT_SPEED   = 7    -- studs per second (items move along +Z)
local BELT_Y       = 0.5  -- height
local BELT_START_Z = -BELT_LENGTH / 2   -- -105
local BELT_END_Z   =  BELT_LENGTH / 2   -- +105

-- Number of stripes and their spacing (studs apart)
local STRIPE_COUNT   = 14
local STRIPE_SPACING = BELT_LENGTH / STRIPE_COUNT

function ShopSystem.createShopPads()

	-- -----------------------------------------------------------------------
	-- Carpet / belt base — runs along Z axis to span all 8 houses
	-- -----------------------------------------------------------------------
	local belt = Instance.new("Part")
	belt.Name        = "ShopBelt"
	belt.Anchored    = true
	belt.Size        = Vector3.new(BELT_WIDTH, 0.6, BELT_LENGTH)
	belt.Position    = Vector3.new(0, BELT_Y, 0)
	belt.BrickColor  = BrickColor.new("Bright red")
	belt.Material    = Enum.Material.Fabric
	belt.TopSurface  = Enum.SurfaceType.Smooth
	belt.Parent      = workspace

	-- Belt stripes (decorative, animate along Z to show movement direction)
	local stripes = {}
	for i = 0, STRIPE_COUNT - 1 do
		local stripe = Instance.new("Part")
		stripe.Anchored   = true
		stripe.Size       = Vector3.new(BELT_WIDTH - 1, 0.05, 2)
		stripe.BrickColor = BrickColor.new("Bright orange")
		stripe.Material   = Enum.Material.Neon
		stripe.CanCollide = false
		stripe.Parent     = workspace
		stripes[i + 1] = stripe
	end

	-- Animate stripes scrolling along Z
	local stripeOffset = 0
	RunService.Heartbeat:Connect(function(dt)
		stripeOffset = (stripeOffset + BELT_SPEED * dt) % STRIPE_SPACING
		for i, stripe in ipairs(stripes) do
			local baseZ = BELT_START_Z + (i - 1) * STRIPE_SPACING
			local z = baseZ + stripeOffset
			if z > BELT_END_Z then z = z - BELT_LENGTH end
			stripe.Position = Vector3.new(0, BELT_Y + 0.32, z)
		end
	end)

	-- -----------------------------------------------------------------------
	-- Entry portal (glowing neon arch at each end of belt — at Z extremes)
	-- -----------------------------------------------------------------------
	local function buildPortal(zPos, color)
		local pillarL = Instance.new("Part")
		pillarL.Anchored   = true
		pillarL.Size       = Vector3.new(0.6, 10, 0.6)
		pillarL.Position   = Vector3.new(-BELT_WIDTH / 2 - 0.5, BELT_Y + 5, zPos)
		pillarL.BrickColor = BrickColor.new("Really black")
		pillarL.Material   = Enum.Material.Neon
		pillarL.CanCollide = false
		pillarL.Parent     = workspace

		local pillarR = Instance.new("Part")
		pillarR.Anchored   = true
		pillarR.Size       = Vector3.new(0.6, 10, 0.6)
		pillarR.Position   = Vector3.new(BELT_WIDTH / 2 + 0.5, BELT_Y + 5, zPos)
		pillarR.BrickColor = BrickColor.new("Really black")
		pillarR.Material   = Enum.Material.Neon
		pillarR.CanCollide = false
		pillarR.Parent     = workspace

		local arch = Instance.new("Part")
		arch.Anchored   = true
		arch.Size       = Vector3.new(BELT_WIDTH + 2, 0.6, 0.6)
		arch.Position   = Vector3.new(0, BELT_Y + 10.3, zPos)
		arch.BrickColor = BrickColor.new("Really black")
		arch.Material   = Enum.Material.Neon
		arch.CanCollide = false
		arch.Parent     = workspace

		local archLight = Instance.new("PointLight")
		archLight.Brightness = 4
		archLight.Range      = 18
		archLight.Color      = color
		archLight.Parent     = arch

		RunService.Heartbeat:Connect(function()
			if not arch or not arch.Parent then return end
			local c = Color3.fromHSV((tick() * 0.4) % 1, 0.9, 1)
			arch.Color = c; pillarL.Color = c; pillarR.Color = c; archLight.Color = c
		end)
	end

	buildPortal(BELT_START_Z - 1, Color3.fromRGB(0, 200, 255))
	buildPortal(BELT_END_Z   + 1, Color3.fromRGB(255, 80, 200))

	-- SHOP sign at the north end of belt
	local signPost = Instance.new("Part")
	signPost.Anchored   = true
	signPost.Size       = Vector3.new(0.3, 8, 0.3)
	signPost.Position   = Vector3.new(BELT_WIDTH / 2 + 2, BELT_Y + 4, BELT_START_Z - 2)
	signPost.BrickColor = BrickColor.new("Dark orange")
	signPost.Material   = Enum.Material.SmoothPlastic
	signPost.CanCollide = false
	signPost.Parent     = workspace

	local signBoard = Instance.new("Part")
	signBoard.Anchored   = true
	signBoard.Size       = Vector3.new(0.3, 4, 14)
	signBoard.Position   = Vector3.new(BELT_WIDTH / 2 + 2, BELT_Y + 9, BELT_START_Z + 5)
	signBoard.BrickColor = BrickColor.new("Really black")
	signBoard.Material   = Enum.Material.SmoothPlastic
	signBoard.CanCollide = false
	signBoard.Parent     = workspace

	local signGui = Instance.new("SurfaceGui")
	signGui.Face   = Enum.NormalId.Right
	signGui.Parent = signBoard
	local signLabel = Instance.new("TextLabel")
	signLabel.Size                   = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text                   = "🛒  SKIN SHOP\nPress E to buy!"
	signLabel.TextScaled             = true
	signLabel.Font                   = Enum.Font.GothamBold
	signLabel.TextColor3             = Color3.fromRGB(255, 220, 50)
	signLabel.Parent                 = signGui

	-- -----------------------------------------------------------------------
	-- Active conveyor skins (body part → true) — move along +Z
	-- -----------------------------------------------------------------------
	local conveyorItems = {}

	RunService.Heartbeat:Connect(function(dt)
		for body, _ in pairs(conveyorItems) do
			if not body or not body.Parent then
				conveyorItems[body] = nil
				continue
			end
			if _flyingBodies[body] then
				conveyorItems[body] = nil
				continue
			end
			local newZ = body.Position.Z + BELT_SPEED * dt
			body.CFrame = CFrame.new(body.Position.X, body.Position.Y, newZ)
				* CFrame.Angles(0, tick() * 0.8, 0)
			if newZ >= BELT_END_Z then
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

	-- Spawn 1 skin every 4 seconds at the start of the belt
	task.spawn(function()
		while true do
			task.wait(4)
			local chosen = SkinData.gachaRoll()
			if chosen then
				local spawnPos = Vector3.new(0, BELT_Y + chosen.size / 2 + 0.3, BELT_START_Z)
				local body = ShopSystem.spawnSkin(chosen, spawnPos, nil, _skinOwner, nil)
				if body then
					conveyorItems[body] = true
				end
			end
		end
	end)

	-- -----------------------------------------------------------------------
	-- GACHA pad — on the west side of the belt, center
	-- -----------------------------------------------------------------------
	local padY = BELT_Y + 0.25
	local gachaPad = Instance.new("Part")
	gachaPad.Name      = "GachaPad"
	gachaPad.Anchored  = true
	gachaPad.Size      = Vector3.new(12, 0.5, 12)
	gachaPad.Position  = Vector3.new(-18, padY, 0)
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
		local c = Color3.fromHSV((tick() * 0.5) % 1, 1, 1)
		gachaPad.Color = c; gachaLight.Color = c
	end)

	local gachaBB = Instance.new("BillboardGui")
	gachaBB.Size        = UDim2.new(0, 240, 0, 90)
	gachaBB.StudsOffset = Vector3.new(0, 14, 0)
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

	-- Prize wheel machine above the gacha pad
	local MACHINE_X       = gachaPad.Position.X
	local MACHINE_Z       = gachaPad.Position.Z
	local WHEEL_CENTER_Y  = padY + 7
	local WHEEL_CENTER    = Vector3.new(MACHINE_X, WHEEL_CENTER_Y, MACHINE_Z)
	local WHEEL_RADIUS    = 4.5

	-- 1. Metal vertical post
	local post = Instance.new("Part")
	post.Shape      = Enum.PartType.Cylinder
	post.Size       = Vector3.new(1.2, 8, 1.2)
	post.CFrame     = CFrame.new(MACHINE_X, padY + 4, MACHINE_Z)
	post.BrickColor = BrickColor.new("Dark grey metallic")
	post.Material   = Enum.Material.Metal
	post.CanCollide = false
	post.Anchored   = true
	post.Parent     = workspace

	-- 2. Wheel disc (thin cylinder, face pointing toward +X / player side)
	local disc = Instance.new("Part")
	disc.Shape      = Enum.PartType.Cylinder
	disc.Size       = Vector3.new(0.5, 11, 11)
	disc.CFrame     = CFrame.new(WHEEL_CENTER) * CFrame.Angles(0, 0, math.pi / 2)
	disc.Color      = Color3.fromRGB(25, 25, 30)
	disc.Material   = Enum.Material.SmoothPlastic
	disc.CanCollide = false
	disc.Anchored   = true
	disc.Parent     = workspace

	-- 3. Hub center sphere
	local hub = Instance.new("Part")
	hub.Shape      = Enum.PartType.Ball
	hub.Size       = Vector3.new(2, 2, 2)
	hub.Position   = WHEEL_CENTER
	hub.Color      = Color3.fromRGB(255, 200, 0)
	hub.Material   = Enum.Material.Metal
	hub.CanCollide = false
	hub.Anchored   = true
	hub.Parent     = workspace

	-- 4. Fixed red pointer arrow at the top of the wheel
	local pointer = Instance.new("WedgePart")
	pointer.Size      = Vector3.new(0.5, 2, 1)
	pointer.CFrame    = CFrame.new(WHEEL_CENTER + Vector3.new(0, WHEEL_RADIUS + 2, 0)) * CFrame.Angles(0, 0, math.pi)
	pointer.Color     = Color3.fromRGB(255, 40, 40)
	pointer.Material  = Enum.Material.Neon
	pointer.CanCollide = false
	pointer.Anchored  = true
	pointer.Parent    = workspace

	-- 5. Five rarity segment paddles (animated)
	local WHEEL_RARITY_COLORS = {
		Color3.fromRGB(180, 180, 180),  -- Common
		Color3.fromRGB(50,  200, 80),   -- Uncommon
		Color3.fromRGB(60,  120, 255),  -- Rare
		Color3.fromRGB(180, 0,   255),  -- Epic
		Color3.fromRGB(255, 200, 0),    -- Legendary
	}
	local WHEEL_RARITY_NAMES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

	local wheelSegments = {}
	local segBaseAngles = {}
	for i = 1, 5 do
		local baseAngle = (i - 1) * (2 * math.pi / 5)
		segBaseAngles[i] = baseAngle

		local seg = Instance.new("Part")
		seg.Size      = Vector3.new(0.4, 3.8, 1.6)
		seg.Color     = WHEEL_RARITY_COLORS[i]
		seg.Material  = Enum.Material.Neon
		seg.CanCollide = false
		seg.Anchored  = true
		seg.Parent    = workspace

		local bb = Instance.new("BillboardGui")
		bb.Size        = UDim2.new(0, 90, 0, 28)
		bb.AlwaysOnTop = false
		bb.Parent      = seg
		local lbl = Instance.new("TextLabel")
		lbl.Size                   = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text                   = WHEEL_RARITY_NAMES[i]
		lbl.TextScaled             = true
		lbl.Font                   = Enum.Font.GothamBold
		lbl.TextColor3             = Color3.fromRGB(255, 255, 255)
		lbl.TextStrokeTransparency = 0.3
		lbl.Parent                 = bb

		wheelSegments[i] = seg
	end

	-- 6. Animate the spinning wheel
	local wheelAngle     = 0
	local WHEEL_SPIN_SPEED = 1.2  -- radians per second
	RunService.Heartbeat:Connect(function(dt)
		wheelAngle = (wheelAngle + WHEEL_SPIN_SPEED * dt) % (2 * math.pi)
		for i, seg in ipairs(wheelSegments) do
			if not seg or not seg.Parent then continue end
			local angle = segBaseAngles[i] + wheelAngle
			local segY  = WHEEL_CENTER_Y + math.sin(angle) * WHEEL_RADIUS
			local segZ  = MACHINE_Z      + math.cos(angle) * WHEEL_RADIUS
			seg.CFrame  = CFrame.new(MACHINE_X, segY, segZ)
				* CFrame.Angles(angle, 0, math.pi / 2)
		end
		-- Pulse the hub color
		if hub and hub.Parent then
			hub.Color = Color3.fromHSV((tick() * 0.6) % 1, 0.8, 1)
		end
	end)

	-- ProximityPrompt instead of Touched
	local gachaPrompt = Instance.new("ProximityPrompt")
	gachaPrompt.ActionText            = "Spin Gacha (FREE)"
	gachaPrompt.ObjectText            = "GACHA MACHINE — 30 min cooldown"
	gachaPrompt.HoldDuration          = 0
	gachaPrompt.MaxActivationDistance = 10
	gachaPrompt.Parent                = gachaPad

	gachaPrompt.Triggered:Connect(function(player)
		ShopSystem.spinGacha(player, _playerBases, _skinOwner, _playerCollection)
	end)
end

-- =========================================================================
-- Fusion system (UI-based): pick 2 skins from collection, see 4 results
-- =========================================================================

local RARITY_INDEX = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
local INDEX_RARITY = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local _fusionPending = {}  -- [player] → list of 4 skinData options

local function pickRandom(rarityName)
	local list = SkinData.getByRarity(rarityName)
	if not list or #list == 0 then return nil end
	return list[math.random(1, #list)]
end

local function generateFusionOptions(id1, id2)
	local d1 = SkinData.getById(id1)
	local d2 = SkinData.getById(id2)
	local tier1 = d1 and (RARITY_INDEX[d1.rarity] or 1) or 1
	local tier2 = d2 and (RARITY_INDEX[d2.rarity] or 1) or 1
	local avgTier = math.floor((tier1 + tier2) / 2)

	local worseTier = math.max(1, avgTier - 1)
	local opt1 = pickRandom(INDEX_RARITY[worseTier])
	local opt2 = pickRandom(INDEX_RARITY[worseTier])
	for _ = 1, 5 do
		local candidate = pickRandom(INDEX_RARITY[worseTier])
		if candidate and opt1 and candidate.id ~= opt1.id then opt2 = candidate; break end
	end

	local betterTier = math.min(5, avgTier + 1)
	local opt3 = pickRandom(INDEX_RARITY[betterTier])
	local opt4 = pickRandom("Legendary")
	return { opt1 or opt3, opt2 or opt3, opt3, opt4 }
end

function ShopSystem.handleFuseRequest(player, id1, id2)
	local collection = _playerCollection[player]
	if not collection then
		NotificationEvent:FireClient(player, "You have no skins to fuse!", Color3.fromRGB(255, 80, 80))
		return
	end
	local count1 = collection[id1] or 0
	local count2 = collection[id2] or 0
	if id1 == id2 then
		if count1 < 2 then
			NotificationEvent:FireClient(player, "Need 2 copies to fuse the same skin!", Color3.fromRGB(255, 80, 80))
			return
		end
	else
		if count1 < 1 or count2 < 1 then
			NotificationEvent:FireClient(player, "You don't own one of those skins!", Color3.fromRGB(255, 80, 80))
			return
		end
	end

	local toDestroy = {}
	local need1, need2 = true, true
	for skin, owner in pairs(_skinOwner) do
		if owner == player and skin and skin.Parent then
			local bId = skin:GetAttribute("SkinId")
			if need1 and bId == id1 then
				table.insert(toDestroy, skin); need1 = false
			elseif need2 and bId == id2 then
				table.insert(toDestroy, skin); need2 = false
			end
		end
		if not need1 and not need2 then break end
	end
	if #toDestroy < 2 then
		NotificationEvent:FireClient(player, "Couldn't find both skins in your base!", Color3.fromRGB(255, 80, 80))
		return
	end
	for _, part in ipairs(toDestroy) do
		local slotIdx = part:GetAttribute("SlotIndex")
		if slotIdx then ShopSystem.releaseSlot(player, slotIdx) end
		ShopSystem.removePlate(part)
		_skinOwner[part] = nil
		local m = part.Parent
		if m and m:IsA("Model") then m:Destroy() elseif part and part.Parent then part:Destroy() end
	end

	collection[id1] = (collection[id1] or 1) - 1
	if collection[id1] <= 0 then collection[id1] = nil end
	if id1 ~= id2 then
		collection[id2] = (collection[id2] or 1) - 1
		if collection[id2] <= 0 then collection[id2] = nil end
	end
	CollectionUpdatedEvent:FireClient(player, collection)

	local options = generateFusionOptions(id1, id2)
	_fusionPending[player] = options
	local clientOptions = {}
	for _, opt in ipairs(options) do
		if opt then
			table.insert(clientOptions, { id = opt.id, name = opt.name, rarity = opt.rarity, income = opt.income })
		end
	end
	FuseOptionsEvent:FireClient(player, clientOptions)
end

function ShopSystem.handleFuseChoose(player, choiceIndex)
	local options = _fusionPending[player]
	if not options or not options[choiceIndex] then
		NotificationEvent:FireClient(player, "No pending fusion result!", Color3.fromRGB(255, 80, 80))
		return
	end
	_fusionPending[player] = nil
	local chosen = options[choiceIndex]
	local slotIndex, slotPos = BaseSystem.getNextSlot(player, _playerBases)
	if not slotIndex then
		NotificationEvent:FireClient(player, "Base full! Free a slot first.", Color3.fromRGB(255, 180, 0))
		return
	end
	local dest = Vector3.new(slotPos.X, slotPos.Y + chosen.size / 2, slotPos.Z)
	ShopSystem.spawnSkin(chosen, dest, player, _skinOwner, slotIndex)
	if not _playerCollection[player] then _playerCollection[player] = {} end
	_playerCollection[player][chosen.id] = (_playerCollection[player][chosen.id] or 0) + 1
	CollectionUpdatedEvent:FireClient(player, _playerCollection[player])
	local rarityColor = RARITY_COLOR[chosen.rarity] or Color3.fromRGB(255, 255, 255)
	NotificationEvent:FireClient(player, "Fusion result: [" .. chosen.rarity .. "] " .. chosen.name .. "!", rarityColor)
end

-- =========================================================================
-- Physical Fusion Machine
-- Players carry skins to 2 input pedestals (press E to deposit).
-- When both slots are filled, 4 result pedestals appear.
-- Press E on a result pedestal to claim it; the rest vanish.
-- =========================================================================

-- Per-player fusion state
local _fusionDeposits  = {}   -- [player] → { slot1=skinData/nil, slot2=skinData/nil }
local _fusionDisplays  = {}   -- [player] → { [slotNum] = Part }  glowing ball on pedestal top

local MACHINE_X = 18   -- east side of belt
local MACHINE_Z = 0    -- center of map
local MACHINE_BASE_Y = BELT_Y + 0.25

local function makePedestal(cx, cy, cz, colorRGB, labelText)
	local ped = Instance.new("Part")
	ped.Anchored   = true
	ped.Size       = Vector3.new(4, 3, 4)
	ped.Position   = Vector3.new(cx, cy, cz)
	ped.Color      = colorRGB
	ped.Material   = Enum.Material.SmoothPlastic
	ped.CanCollide = true
	ped.CastShadow = true
	ped.Parent     = workspace

	local top = Instance.new("Part")
	top.Anchored   = true
	top.Size       = Vector3.new(4.4, 0.3, 4.4)
	top.Position   = Vector3.new(cx, cy + 1.65, cz)
	top.Color      = Color3.fromRGB(255, 220, 50)
	top.Material   = Enum.Material.Neon
	top.CanCollide = false
	top.CastShadow = false
	top.Parent     = workspace

	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0, 180, 0, 55)
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
	bb.Parent      = ped
	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text                   = labelText
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.GothamBold
	lbl.TextColor3             = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.3
	lbl.Parent                 = bb

	return ped, top
end

local function destroyFusionDisplays(player)
	local displays = _fusionDisplays[player]
	if displays then
		for _, p in pairs(displays) do
			if p and p.Parent then p:Destroy() end
		end
	end
	_fusionDisplays[player] = nil
end

function ShopSystem.createFusionMachine()
	local baseY = MACHINE_BASE_Y

	-- Platform base
	local platform = Instance.new("Part")
	platform.Anchored  = true
	platform.Size      = Vector3.new(16, 0.5, 24)
	platform.Position  = Vector3.new(MACHINE_X, baseY, MACHINE_Z)
	platform.Color     = Color3.fromRGB(40, 40, 50)
	platform.Material  = Enum.Material.SmoothPlastic
	platform.Parent    = workspace

	-- Glowing center orb
	local orb = Instance.new("Part")
	orb.Name      = "FusionOrb"
	orb.Shape     = Enum.PartType.Ball
	orb.Anchored  = true
	orb.Size      = Vector3.new(3, 3, 3)
	orb.Position  = Vector3.new(MACHINE_X, baseY + 4, MACHINE_Z)
	orb.Material  = Enum.Material.Neon
	orb.CanCollide = false
	orb.Parent    = workspace

	RunService.Heartbeat:Connect(function()
		if not orb or not orb.Parent then return end
		orb.Color = Color3.fromHSV(((tick() * 0.5) + 0.6) % 1, 1, 1)
	end)

	-- Sign above
	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0, 300, 0, 80)
	bb.StudsOffset = Vector3.new(0, 8, 0)
	bb.Parent      = orb
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.5, 0)
	title.BackgroundTransparency = 1
	title.Text = "⚡ FUSION MACHINE"
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 255, 100)
	title.Parent = bb
	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0.5, 0)
	hint.Position = UDim2.new(0, 0, 0.5, 0)
	hint.BackgroundTransparency = 1
	hint.Text = "Carry skins to the 2 slots & press E"
	hint.TextScaled = true
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(200, 200, 255)
	hint.Parent = bb

	-- Two input pedestals
	local slotColors = { Color3.fromRGB(30, 100, 200), Color3.fromRGB(200, 60, 30) }
	local slotZOffsets = { -5, 5 }
	local slotLabels = { "Slot 1\n(carry here)", "Slot 2\n(carry here)" }

	-- Store the top plate of each pedestal so we can place display balls on them
	local slotTops = {}

	for slotNum = 1, 2 do
		local sz = MACHINE_Z + slotZOffsets[slotNum]
		local ped, top = makePedestal(MACHINE_X, baseY + 1.5, sz, slotColors[slotNum], slotLabels[slotNum])
		top.Color = slotColors[slotNum]
		slotTops[slotNum] = top

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText            = "Deposit Skin"
		prompt.ObjectText            = "Fusion Slot " .. slotNum
		prompt.HoldDuration          = 0
		prompt.MaxActivationDistance = 8
		prompt.Parent                = ped

		local slotNumCopy = slotNum
		prompt.Triggered:Connect(function(trigPlayer)
			-- Player must be carrying a skin they own
			local carried = _carrying[trigPlayer]
			if not carried then
				NotificationEvent:FireClient(trigPlayer, "Carry a skin to this slot first!", Color3.fromRGB(255, 180, 0))
				return
			end
			if _skinOwner[carried] ~= trigPlayer then
				NotificationEvent:FireClient(trigPlayer, "You can only fuse your own skins!", Color3.fromRGB(255, 80, 80))
				return
			end

			local bId   = carried:GetAttribute("SkinId") or ""
			local bData = SkinData.getById(bId)
			if not bData then
				NotificationEvent:FireClient(trigPlayer, "Unknown skin!", Color3.fromRGB(255, 80, 80))
				return
			end

			-- Initialise deposit table
			if not _fusionDeposits[trigPlayer] then
				_fusionDeposits[trigPlayer] = {}
			end
			local deposits = _fusionDeposits[trigPlayer]

			-- Destroy the carried skin and free its slot
			local slotIdx2 = carried:GetAttribute("SlotIndex")
			if slotIdx2 then ShopSystem.releaseSlot(trigPlayer, slotIdx2) end
			ShopSystem.removePlate(carried)
			_skinOwner[carried] = nil
			_carrying[trigPlayer] = nil
			trigPlayer:SetAttribute("IsCarrying", false)
			trigPlayer:SetAttribute("CarryingSkinName", "")
			local m2 = carried.Parent
			if m2 and m2:IsA("Model") then m2:Destroy() elseif carried and carried.Parent then carried:Destroy() end

			-- Update collection
			local col = _playerCollection[trigPlayer]
			if col and col[bId] then
				col[bId] = col[bId] - 1
				if col[bId] <= 0 then col[bId] = nil end
				CollectionUpdatedEvent:FireClient(trigPlayer, col)
			end

			deposits[slotNumCopy] = bData

			-- Spawn a glowing display ball on top of this slot's pedestal
			if not _fusionDisplays[trigPlayer] then
				_fusionDisplays[trigPlayer] = {}
			end
			local pedTop = slotTops[slotNumCopy]
			if pedTop and pedTop.Parent then
				local topPos = pedTop.Position
				local rarityCol = RARITY_COLOR[bData.rarity] or Color3.fromRGB(255, 255, 255)
				local ball = Instance.new("Part")
				ball.Shape     = Enum.PartType.Ball
				ball.Size      = Vector3.new(2, 2, 2)
				ball.Material  = Enum.Material.Neon
				ball.Color     = rarityCol
				ball.Anchored  = true
				ball.CanCollide = false
				ball.Position  = Vector3.new(topPos.X, topPos.Y + 1.3, topPos.Z)
				ball.Parent    = workspace
				-- Destroy old display for this slot if any
				if _fusionDisplays[trigPlayer][slotNumCopy] then
					local old = _fusionDisplays[trigPlayer][slotNumCopy]
					if old and old.Parent then old:Destroy() end
				end
				_fusionDisplays[trigPlayer][slotNumCopy] = ball
			end

			NotificationEvent:FireClient(trigPlayer, "Deposited " .. bData.name .. " into slot " .. slotNumCopy .. "!", Color3.fromRGB(100, 200, 255))

			-- Both slots filled → auto-pick one random result and spawn it
			if deposits[1] and deposits[2] then
				local options = generateFusionOptions(deposits[1].id, deposits[2].id)
				deposits[1] = nil; deposits[2] = nil
				-- Destroy display balls for both slots
				destroyFusionDisplays(trigPlayer)
				-- Pick one at random
				local chosen = options[math.random(1, #options)]
				local slotIdx, slotPos = BaseSystem.getNextSlot(trigPlayer, _playerBases)
				if not slotIdx then
					NotificationEvent:FireClient(trigPlayer, "Base full! Free a slot first.", Color3.fromRGB(255, 180, 0))
					return
				end
				local dest = Vector3.new(slotPos.X, slotPos.Y + chosen.size / 2, slotPos.Z)

				-- Flash the orb white then back to cycling
				local orbRef = workspace:FindFirstChild("FusionOrb")
				if orbRef then
					orbRef.Color = Color3.fromRGB(255, 255, 255)
					orbRef.Size  = Vector3.new(5, 5, 5)
					task.delay(0.3, function()
						if orbRef and orbRef.Parent then
							orbRef.Size = Vector3.new(3, 3, 3)
						end
					end)
				end

				-- Build the actual skin character at the machine so it walks to base
				local walkStartPos = Vector3.new(MACHINE_X, dest.Y, MACHINE_Z)
				local walkModel = Instance.new("Model")
				walkModel.Name   = "FusionWalk_" .. chosen.name
				walkModel.Parent = workspace
				local walkBody
				if CharacterBuilders then
					walkBody = CharacterBuilders.build(chosen.id, walkStartPos, walkModel, chosen.size, chosen)
				end
				if not walkBody then
					walkBody = Instance.new("Part")
					walkBody.Name      = "Body"
					walkBody.Shape     = Enum.PartType.Ball
					walkBody.Material  = Enum.Material.Neon
					walkBody.BrickColor = chosen.color
					walkBody.Size      = Vector3.new(chosen.size, chosen.size, chosen.size)
					walkBody.CFrame    = CFrame.new(walkStartPos)
					walkBody.Anchored  = true
					walkBody.CanCollide = false
					walkBody.Parent    = walkModel
					walkModel.PrimaryPart = walkBody
				end
				walkBody.Anchored  = true
				walkBody.CanCollide = false
				_flyingBodies[walkBody] = true

				-- 3-segment walk path through base entrance
				local bd  = _playerBases[trigPlayer]
				local fs  = bd and bd.faceSign or 1
				local bp  = bd and bd.position or dest
				local frontFaceX = bp.X + fs * 14
				local wp1 = Vector3.new(frontFaceX + fs * 2, dest.Y, bp.Z)
				local wp2 = Vector3.new(frontFaceX - fs * 3, dest.Y, bp.Z)
				local waypoints = {wp1, wp2, dest}
				local segIdx  = 1
				local segStartPos = walkStartPos
				local segEndPos   = waypoints[1]
				local segLen  = math.max(1, (segEndPos - segStartPos).Magnitude)
				local walkT   = 0
				local FUSION_WALK_SPEED = 14
				local walkConn
				walkConn = RunService.Heartbeat:Connect(function(dt)
					if not walkBody or not walkBody.Parent then
						walkConn:Disconnect(); _flyingBodies[walkBody] = nil; return
					end
					walkT = walkT + (FUSION_WALK_SPEED * dt) / segLen
					if walkT >= 1 then
						if segIdx < #waypoints then
							segIdx = segIdx + 1
							segStartPos = waypoints[segIdx - 1]
							segEndPos   = waypoints[segIdx]
							segLen = math.max(1, (segEndPos - segStartPos).Magnitude)
							walkT  = 0
							walkBody.CFrame = CFrame.new(segStartPos)
						else
							walkConn:Disconnect(); _flyingBodies[walkBody] = nil
							walkModel:Destroy()
							if trigPlayer and trigPlayer.Parent then
								ShopSystem.spawnSkin(chosen, dest, trigPlayer, _skinOwner, slotIdx)
								if not _playerCollection[trigPlayer] then _playerCollection[trigPlayer] = {} end
								_playerCollection[trigPlayer][chosen.id] = (_playerCollection[trigPlayer][chosen.id] or 0) + 1
								CollectionUpdatedEvent:FireClient(trigPlayer, _playerCollection[trigPlayer])
								local rc = RARITY_COLOR[chosen.rarity] or Color3.fromRGB(255, 255, 255)
								NotificationEvent:FireClient(trigPlayer, "Fusion: [" .. chosen.rarity .. "] " .. chosen.name .. "!", rc)
							end
						end
						return
					end
					walkBody.CFrame = CFrame.new(segStartPos:Lerp(segEndPos, walkT))
				end)
			end
		end)
	end
end

return ShopSystem
