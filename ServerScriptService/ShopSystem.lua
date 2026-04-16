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

-- Chest lid references (set by createShopPads, used by spinGacha for animation)
local _gachaChestLid      = nil
local _gachaChestLidBaseY = nil
local _gachaPadY          = nil

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

local RARITY_FR = {
	Common    = "Commun",
	Uncommon  = "Peu commun",
	Rare      = "Rare",
	Epic      = "Épique",
	Legendary = "Légendaire",
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
	prompt.ActionText            = "Poser ici"
	prompt.ObjectText            = "Emplacement " .. slotIndex
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
		NotificationEvent:FireClient(player, "Cet emplacement est déjà occupé !", Color3.fromRGB(255, 80, 80))
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

	-- Spawn at new slot position (spawnSkin adds 0.5× internally for 1.5× scale)
	local dest = Vector3.new(slotPos.X, slotPos.Y + skinData.size, slotPos.Z)
	ShopSystem.spawnSkin(skinData, dest, player, _skinOwner, slotIndex)
	NotificationEvent:FireClient(player, bName .. " déplacé vers l'emplacement " .. slotIndex .. " !", Color3.fromRGB(200, 200, 255))
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
	-- 1.5× size: callers pass pos.Y = slotSurfaceY + skinData.size; we lift by an extra 0.5×size
	local SKIN_SCALE = 1.5
	local s = skinData.size * SKIN_SCALE
	position = Vector3.new(position.X, position.Y + skinData.size * (SKIN_SCALE - 1), position.Z)

	-- -----------------------------------------------------------------------
	-- Model container
	-- -----------------------------------------------------------------------
	local model = Instance.new("Model")
	model.Name = "SkinChar_" .. skinData.name
	model.Parent = workspace

	-- -----------------------------------------------------------------------
	-- Build the humanoid fruit character
	-- -----------------------------------------------------------------------
	local baseCenter = owner and _playerBases[owner] and _playerBases[owner].position
	local body
	if CharacterBuilders then
		body = CharacterBuilders.build(skinData.id, position, model, s, skinData, baseCenter)
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
		body.CanCollide = false
		body.CastShadow = true
		body.Parent     = model
		model.PrimaryPart = body
	else
		-- Ensure the body returned by CharacterBuilders is anchored and non-collidable
		body.Anchored   = true
		body.CanCollide = false
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
		rarityLabel.Text            = RARITY_FR[skinData.rarity] or skinData.rarity
		rarityLabel.TextColor3      = RARITY_COLOR[skinData.rarity] or Color3.fromRGB(255, 255, 255)
		rarityLabel.TextStrokeTransparency = 0.4
		rarityLabel.TextScaled      = true
		rarityLabel.Font            = Enum.Font.GothamBold
		rarityLabel.Parent          = billboard
	else
		-- Conveyor shop item: name + price + rarity
		billboard.Size = UDim2.new(0, 180, 0, 80)

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

		local costLabel = Instance.new("TextLabel")
		costLabel.Size            = UDim2.new(1, 0, 0.35, 0)
		costLabel.Position        = UDim2.new(0, 0, 0.38, 0)
		costLabel.BackgroundTransparency = 1
		costLabel.Text            = skinData.cost and ("$" .. skinData.cost) or "GACHA ONLY"
		costLabel.TextColor3      = Color3.fromRGB(255, 220, 0)
		costLabel.TextStrokeTransparency = 0.2
		costLabel.TextScaled      = true
		costLabel.Font            = Enum.Font.GothamBold
		costLabel.Parent          = billboard

		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size            = UDim2.new(1, 0, 0.27, 0)
		rarityLabel.Position        = UDim2.new(0, 0, 0.73, 0)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text            = (skinData.rarity and RARITY_FR[skinData.rarity]) or skinData.rarity or ""
		rarityLabel.TextColor3      = RARITY_COLOR[skinData.rarity] or Color3.fromRGB(255, 255, 255)
		rarityLabel.TextStrokeTransparency = 0.3
		rarityLabel.TextScaled      = true
		rarityLabel.Font            = Enum.Font.GothamBold
		rarityLabel.Parent          = billboard
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
			prompt.ActionText          = "Acheter " .. skinData.cost .. "$"
			prompt.ObjectText          = skinData.name
			prompt.HoldDuration        = 0
			prompt.MaxActivationDistance = 8
			prompt.Parent              = body

			prompt.Triggered:Connect(function(buyer)
				-- Check money
				local money = buyer:GetAttribute("Money") or 0
				if money < skinData.cost then
					NotificationEvent:FireClient(buyer, "Pas assez d'argent ! Il te faut " .. skinData.cost .. "$", Color3.fromRGB(255, 80, 80))
					return
				end
				-- Check slot
				local slotIndex, slotPos = BaseSystem.getNextSlot(buyer, _playerBases)
				if not slotIndex then
					NotificationEvent:FireClient(buyer, "Base pleine ! Renaître pour débloquer plus d'étages.", Color3.fromRGB(255, 180, 0))
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
				local dest = Vector3.new(slotPos.X, slotPos.Y + skinData.size, slotPos.Z)
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
							model:SetPrimaryPartCFrame(CFrame.new(segStart))
						else
							-- Arrived at slot
							conn:Disconnect(); _flyingBodies[body] = nil
							if buyer and buyer.Parent then
								ShopSystem.spawnSkin(skinData, dest, buyer, _skinOwner, slotIndex)
								if not _playerCollection[buyer] then _playerCollection[buyer] = {} end
								_playerCollection[buyer][skinData.id] = (_playerCollection[buyer][skinData.id] or 0) + 1
								CollectionUpdatedEvent:FireClient(buyer, _playerCollection[buyer])
								NotificationEvent:FireClient(buyer, "Tu as reçu " .. skinData.name .. " !", Color3.fromRGB(100, 255, 100))
							end
							if model and model.Parent then model:Destroy() end
						end
						return
					end
					local walkPos = segStart:Lerp(segEnd, t)
					model:SetPrimaryPartCFrame(CFrame.new(walkPos) * CFrame.Angles(0, tick() * 2, 0))
				end)
			end)
		end
	end

	-- -----------------------------------------------------------------------
	-- Bobbing and spinning animation
	-- -----------------------------------------------------------------------
	-- Placed skins are fully static — no bob, no spin.

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
		NotificationEvent:FireClient(player, "Ce brainrot ne s'obtient que par le GACHA !", Color3.fromRGB(255, 80, 80))
		return false
	end

	local currentMoney = player:GetAttribute("Money") or 0
	if currentMoney < data.cost then
		NotificationEvent:FireClient(player, "Pas assez d'argent ! Il te faut " .. data.cost .. "$", Color3.fromRGB(255, 80, 80))
		return false
	end

	-- Check slot limit before spending money
	local slotIndex, slotPos = BaseSystem.getNextSlot(player, _playerBases)
	if not slotIndex then
		NotificationEvent:FireClient(player, "Base pleine ! Renaître pour débloquer plus d'étages.", Color3.fromRGB(255, 180, 0))
		return false
	end

	-- Deduct money
	player:SetAttribute("Money", currentMoney - data.cost)

	-- Spawn at slot surface + full skin size (spawnSkin adds 0.5× internally for 1.5× scale)
	local spawnPos = Vector3.new(slotPos.X, slotPos.Y + data.size, slotPos.Z)
	ShopSystem.spawnSkin(data, spawnPos, player, skinOwner, slotIndex)

	-- Update collection
	if not playerCollection[player] then
		playerCollection[player] = {}
	end
	playerCollection[player][skinId] = (playerCollection[player][skinId] or 0) + 1

	-- Fire events
	CollectionUpdatedEvent:FireClient(player, playerCollection[player])
	NotificationEvent:FireClient(player, "Tu as acheté " .. data.name .. " !", Color3.fromRGB(100, 255, 100))

	return true
end

-- =========================================================================
-- Public: spinGacha
-- =========================================================================

local GACHA_X = -18  -- gacha machine X position (symmetric to fusion machine at +18)
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
				string.format("Gacha en recharge ! %d:%02d restant.", mins, secs),
				Color3.fromRGB(255, 80, 80))
			return nil
		end
	end
	_gachaCooldown[player] = tick()

	-- Check slot limit
	local slotIndex, slotPos = BaseSystem.getNextSlot(player, _playerBases)
	if not slotIndex then
		NotificationEvent:FireClient(player, "Base pleine ! Renaître pour débloquer plus d'étages.", Color3.fromRGB(255, 180, 0))
		_gachaCooldown[player] = nil  -- don't consume cooldown if base is full
		return nil
	end

	-- Roll
	local result = SkinData.gachaRoll()
	local dest = Vector3.new(slotPos.X, slotPos.Y + result.size, slotPos.Z)

	-- Fire gacha result so client wheel animation can play
	GachaResultEvent:FireClient(player, {
		id     = result.id,
		name   = result.name,
		rarity = result.rarity,
		income = result.income,
	})

	-- Open chest lid
	if _gachaChestLid and _gachaChestLid.Parent and _gachaChestLidBaseY then
		TweenService:Create(
			_gachaChestLid,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Position = Vector3.new(_gachaChestLid.Position.X, _gachaChestLidBaseY + 6, _gachaChestLid.Position.Z)}
		):Play()
	end

	-- Build actual skin character at the machine and walk it to base
	-- Start above the open chest opening (padY + 4.5 = top of chest base)
	local chestTopY = (_gachaPadY or 0.75) + 4.5
	local walkStartPos = Vector3.new(GACHA_X, chestTopY + result.size, GACHA_Z)
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
				walkModel:SetPrimaryPartCFrame(CFrame.new(segStartPos))
			else
				walkConn:Disconnect(); _flyingBodies[walkBody] = nil
				walkModel:Destroy()
				-- Close chest lid
				if _gachaChestLid and _gachaChestLid.Parent and _gachaChestLidBaseY then
					TweenService:Create(
						_gachaChestLid,
						TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{Position = Vector3.new(_gachaChestLid.Position.X, _gachaChestLidBaseY, _gachaChestLid.Position.Z)}
					):Play()
				end
				if player and player.Parent then
					ShopSystem.spawnSkin(result, dest, player, skinOwner, slotIndex)
					if not playerCollection[player] then playerCollection[player] = {} end
					playerCollection[player][result.id] = (playerCollection[player][result.id] or 0) + 1
					CollectionUpdatedEvent:FireClient(player, playerCollection[player])
					local rc = RARITY_COLOR[result.rarity] or Color3.fromRGB(255, 255, 255)
					NotificationEvent:FireClient(player, "Gacha : [" .. result.rarity .. "] " .. result.name .. " !", rc)
				end
			end
			return
		end
		walkModel:SetPrimaryPartCFrame(CFrame.new(segStartPos:Lerp(segEndPos, walkT)))
	end)

	return result
end

-- =========================================================================
-- Public: createShopPads  (now a conveyor belt shop)
-- =========================================================================

local BELT_LENGTH  = 210  -- visual belt spans Z=-105 to Z=105 (all 8 bases)
local BELT_WIDTH   = 24   -- studs wide along X
local BELT_SPEED   = 7    -- studs per second (items move along +Z)
local BELT_Y       = 0.5  -- height
local BELT_START_Z = -BELT_LENGTH / 2   -- -105
local BELT_END_Z   =  BELT_LENGTH / 2   -- +105
local SPAWN_Z      = -140  -- skins spawn inside north portal
local DESPAWN_Z    =  140  -- skins despawn inside south portal

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
		stripe.Size       = Vector3.new(BELT_WIDTH - 2, 0.05, 1.5)
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
	-- Entry portal — clean gold/white arch matching red carpet aesthetic
	-- -----------------------------------------------------------------------
	local PILLAR_COLOR = Color3.fromRGB(200, 170, 60)   -- gold
	local ARCH_COLOR   = Color3.fromRGB(220, 190, 80)   -- lighter gold
	local PILLAR_H     = 12
	local PILLAR_W     = 1.2

	local function buildPortal(zPos)
		local isStart = (zPos < 0)
		local baseY   = 0   -- ground is at Y=0

		-- Portal matches wall gap (GAP=34) and covers full belt width (30)
		local BLDG_W  = 34    -- fills the 34-stud wall gap
		local BLDG_H  = 35    -- matches boundary wall height
		local BLDG_D  = 5     -- thick enough to be solid; matches wall T=4
		local ARCH_W  = 24    -- = BELT_WIDTH, full passage width
		local ARCH_H  = 14    -- archway height (players + skins fit)
		local sideW   = (BLDG_W - ARCH_W) / 2   -- 5 studs each side

		local BRICK_CLR = Color3.fromRGB(70, 50, 38)   -- dark brown brick
		local VOID_CLR  = Color3.fromRGB(4, 4, 6)      -- near-black portal interior

		-- Left brick pillar
		local lp = Instance.new("Part")
		lp.Anchored = true; lp.Size = Vector3.new(sideW, BLDG_H, BLDG_D)
		lp.Position = Vector3.new(-(ARCH_W/2 + sideW/2), baseY + BLDG_H/2, zPos)
		lp.Color = BRICK_CLR; lp.Material = Enum.Material.Brick; lp.Parent = workspace

		-- Right brick pillar
		local rp = lp:Clone()
		rp.Position = Vector3.new(ARCH_W/2 + sideW/2, baseY + BLDG_H/2, zPos)
		rp.Parent = workspace

		-- Top lintel (above arch opening)
		local topH = BLDG_H - ARCH_H
		local tp = Instance.new("Part")
		tp.Anchored = true; tp.Size = Vector3.new(ARCH_W, topH, BLDG_D)
		tp.Position = Vector3.new(0, baseY + ARCH_H + topH/2, zPos)
		tp.Color = BRICK_CLR; tp.Material = Enum.Material.Brick; tp.Parent = workspace

		-- Grass cap (top strip, matching boundary walls)
		local gc = Instance.new("Part")
		gc.Anchored = true; gc.Size = Vector3.new(BLDG_W, 2, BLDG_D)
		gc.Position = Vector3.new(0, baseY + BLDG_H + 1, zPos)
		gc.Color = Color3.fromRGB(80, 168, 60); gc.Material = Enum.Material.Grass
		gc.CanCollide = true; gc.Parent = workspace

		-- Dark fill inside the arch (solid opaque, no gaps) — non-collidable so skins walk through
		local void = Instance.new("Part")
		void.Anchored = true
		void.Size = Vector3.new(ARCH_W + 1, ARCH_H + 1, BLDG_D + 2)  -- oversize to seal all edges
		void.Position = Vector3.new(0, baseY + ARCH_H/2, zPos)
		void.Color = VOID_CLR; void.Material = Enum.Material.SmoothPlastic
		void.CanCollide = false; void.Transparency = 0; void.Parent = workspace

		-- Glowing neon frame around arch opening (player-facing side)
		local frameSide = isStart and 1 or -1
		local neonClr = Color3.fromRGB(0, 200, 255)
		local frameZ = zPos - frameSide * (BLDG_D/2 + 0.2)
		-- Horizontal bar (top of arch)
		local hBar = Instance.new("Part")
		hBar.Anchored = true; hBar.Size = Vector3.new(ARCH_W, 0.5, 0.5)
		hBar.Position = Vector3.new(0, baseY + ARCH_H, frameZ)
		hBar.Color = neonClr; hBar.Material = Enum.Material.Neon
		hBar.CanCollide = false; hBar.Parent = workspace
		-- Left bar
		local lBar = Instance.new("Part")
		lBar.Anchored = true; lBar.Size = Vector3.new(0.5, ARCH_H, 0.5)
		lBar.Position = Vector3.new(-ARCH_W/2, baseY + ARCH_H/2, frameZ)
		lBar.Color = neonClr; lBar.Material = Enum.Material.Neon
		lBar.CanCollide = false; lBar.Parent = workspace
		-- Right bar
		local rBar = lBar:Clone()
		rBar.Position = Vector3.new(ARCH_W/2, baseY + ARCH_H/2, frameZ)
		rBar.Parent = workspace

		-- Red carpet from wall outer face all the way to the belt start/end
		local carpetDir  = isStart and 1 or -1
		local outerFaceZ = zPos - carpetDir * BLDG_D / 2   -- flush with outer wall face
		local beltEndZ   = isStart and BELT_START_Z or BELT_END_Z
		local carpetLen  = math.abs(beltEndZ - outerFaceZ) + 2
		local carpetCtrZ = (outerFaceZ + beltEndZ) / 2
		local carpet = Instance.new("Part")
		carpet.Anchored  = true
		carpet.Size      = Vector3.new(BELT_WIDTH, 0.3, carpetLen)
		carpet.Position  = Vector3.new(0, BELT_Y + 0.05, carpetCtrZ)
		carpet.Color     = Color3.fromRGB(180, 20, 20)
		carpet.Material  = Enum.Material.Fabric
		carpet.CanCollide = false
		carpet.Parent    = workspace
	end

	buildPortal(-140)   -- north portal, embedded in north wall
	buildPortal( 140)   -- south portal, embedded in south wall

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
			if newZ >= DESPAWN_Z then
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

	-- Only the 5 imported/FBX brainrots appear on the belt
	local FBX_IDS = {
		fraise_jr = true,
		banane_bro = true,
		myrtille_babe = true,
		noisette_king = true,
		poire_belle = true,
	}

	-- Spawn 1 skin every 4 seconds at the start of the belt
	task.spawn(function()
		while true do
			task.wait(3)
			-- Only show the real (FBX) brainrots on the carpet
			local purchasable = {}
			for _, entry in ipairs(SkinData.list) do
				if entry.cost and FBX_IDS[entry.id] then
					table.insert(purchasable, entry)
				end
			end
			local chosen = purchasable[math.random(1, #purchasable)]
			if chosen then
				local spawnPos = Vector3.new(0, BELT_Y + 0.3 + chosen.size, SPAWN_Z)
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
	gachaPad.Name         = "GachaPad"
	gachaPad.Anchored     = true
	gachaPad.Size         = Vector3.new(12, 0.5, 12)
	gachaPad.Position     = Vector3.new(GACHA_X, padY, 0)
	gachaPad.Transparency = 1
	gachaPad.CanCollide   = false
	gachaPad.Parent       = workspace

	local gachaLight = Instance.new("PointLight")
	gachaLight.Brightness = 3
	gachaLight.Range      = 20
	gachaLight.Color      = Color3.fromRGB(255, 0, 128)
	gachaLight.Parent     = gachaPad

	-- -----------------------------------------------------------------------
	-- COFFRE AU TRÉSOR — loot chest machine
	-- -----------------------------------------------------------------------
	local CX = gachaPad.Position.X
	local CZ = gachaPad.Position.Z
	local CY = padY  -- top of pad

	-- Chest base (lower box)
	local chestBase = Instance.new("Part")
	chestBase.Anchored = true; chestBase.Size = Vector3.new(7, 4.5, 5)
	chestBase.CFrame = CFrame.new(CX, CY + 2.25, CZ)
	chestBase.Color = Color3.fromRGB(139, 90, 43); chestBase.Material = Enum.Material.WoodPlanks
	chestBase.CanCollide = true; chestBase.Parent = workspace

	-- Chest lid (slightly wider, arched top using WedgeParts on sides + flat center)
	local chestLid = Instance.new("Part")
	chestLid.Anchored = true; chestLid.Size = Vector3.new(7.4, 2.5, 5.4)
	chestLid.CFrame = CFrame.new(CX, CY + 4.5 + 1.25, CZ)
	chestLid.Color = Color3.fromRGB(160, 100, 50); chestLid.Material = Enum.Material.WoodPlanks
	chestLid.CanCollide = true; chestLid.Parent = workspace

	-- Store references so spinGacha can animate the lid
	_gachaChestLid      = chestLid
	_gachaChestLidBaseY = CY + 4.5 + 1.25
	_gachaPadY          = padY

	-- Metal bands (horizontal straps around base)
	for _, yOff in ipairs({1, 3.2}) do
		local band = Instance.new("Part")
		band.Anchored = true; band.Size = Vector3.new(7.2, 0.5, 5.2)
		band.CFrame = CFrame.new(CX, CY + yOff, CZ)
		band.Color = Color3.fromRGB(80, 80, 85); band.Material = Enum.Material.Metal
		band.CanCollide = false; band.Parent = workspace
	end
	-- Metal band on lid
	local lidBand = Instance.new("Part")
	lidBand.Anchored = true; lidBand.Size = Vector3.new(7.5, 0.5, 5.5)
	lidBand.CFrame = CFrame.new(CX, CY + 4.5 + 0.5, CZ)
	lidBand.Color = Color3.fromRGB(80, 80, 85); lidBand.Material = Enum.Material.Metal
	lidBand.CanCollide = false; lidBand.Parent = workspace

	-- Gold lock in center front
	local lock = Instance.new("Part")
	lock.Anchored = true; lock.Shape = Enum.PartType.Ball
	lock.Size = Vector3.new(1.2, 1.2, 1.2)
	lock.CFrame = CFrame.new(CX - 3.7, CY + 2.5, CZ)
	lock.Color = Color3.fromRGB(255, 210, 0); lock.Material = Enum.Material.Neon
	lock.CanCollide = false; lock.Parent = workspace

	-- Glow light from chest (on chestBase so it actually illuminates)
	local chestLight = Instance.new("PointLight")
	chestLight.Brightness = 4; chestLight.Range = 25
	chestLight.Color = Color3.fromRGB(255, 200, 50)
	chestLight.Parent = chestBase

	-- Animate chest color cycling
	RunService.Heartbeat:Connect(function()
		if not chestBase or not chestBase.Parent then return end
		local hue = (tick() * 0.3) % 1
		local glowCol = Color3.fromHSV(hue, 0.7, 1)
		lock.Color = glowCol; chestLight.Color = glowCol
	end)

	-- Billboard above chest
	local wbb = Instance.new("BillboardGui")
	wbb.Size = UDim2.new(0, 300, 0, 90); wbb.StudsOffset = Vector3.new(0, 8, 0)
	wbb.Parent = chestLid
	local wtitle = Instance.new("TextLabel")
	wtitle.Size = UDim2.new(1,0,0.55,0); wtitle.BackgroundTransparency = 1
	wtitle.Text = "COFFRE AU TRÉSOR"; wtitle.TextScaled = true
	wtitle.Font = Enum.Font.GothamBold; wtitle.TextColor3 = Color3.fromRGB(255, 220, 0)
	wtitle.TextStrokeTransparency = 0; wtitle.Parent = wbb
	local wsub = Instance.new("TextLabel")
	wsub.Size = UDim2.new(1,0,0.45,0); wsub.Position = UDim2.new(0,0,0.55,0)
	wsub.BackgroundTransparency = 1; wsub.Text = "Tour gratuit — 30 min de cooldown"
	wsub.TextScaled = true; wsub.Font = Enum.Font.Gotham
	wsub.TextColor3 = Color3.fromRGB(220, 220, 255); wsub.Parent = wbb

	-- ProximityPrompt on the chest lid (at eye level, line-of-sight disabled)
	local gachaPrompt = Instance.new("ProximityPrompt")
	gachaPrompt.ActionText            = "Ouvrir (GRATUIT)"
	gachaPrompt.ObjectText            = "COFFRE AU TRÉSOR — 30 min de recharge"
	gachaPrompt.HoldDuration          = 0
	gachaPrompt.MaxActivationDistance = 15
	gachaPrompt.RequiresLineOfSight   = false
	gachaPrompt.Parent                = chestLid

	gachaPrompt.Triggered:Connect(function(player)
		ShopSystem.spinGacha(player, _playerBases, _skinOwner, _playerCollection)
	end)
end

-- =========================================================================
-- Fusion system (UI-based): fuse 2 skins → deterministic result
-- Naming rule: strip "Skin" suffix, sort alphabetically, join, re-add "Skin"
-- Example: fraiseSkin + bananeSkin → BananeFraiseSkin
-- =========================================================================

local function computeFusionId(id1, id2)
	-- Strip "Skin" suffix (case-insensitive trailing match)
	local n1 = id1:match("^(.-)Skin$") or id1:match("^(.-)skin$") or id1
	local n2 = id2:match("^(.-)Skin$") or id2:match("^(.-)skin$") or id2
	-- Capitalise first letter for clean name
	n1 = n1:sub(1,1):upper() .. n1:sub(2)
	n2 = n2:sub(1,1):upper() .. n2:sub(2)
	local names = {n1, n2}
	table.sort(names)
	return names[1] .. names[2] .. "Skin"
end

function ShopSystem.handleFuseRequest(player, id1, id2)
	local collection = _playerCollection[player]
	if not collection then
		NotificationEvent:FireClient(player, "Tu n'as pas de brainrots à fusionner !", Color3.fromRGB(255, 80, 80))
		return
	end
	local count1 = collection[id1] or 0
	local count2 = collection[id2] or 0
	if id1 == id2 then
		if count1 < 2 then
			NotificationEvent:FireClient(player, "Il faut 2 exemplaires pour fusionner le même brainrot !", Color3.fromRGB(255, 80, 80))
			return
		end
	else
		if count1 < 1 or count2 < 1 then
			NotificationEvent:FireClient(player, "Tu ne possèdes pas l'un de ces brainrots !", Color3.fromRGB(255, 80, 80))
			return
		end
	end

	-- Compute result id
	local resultId = computeFusionId(id1, id2)
	local resultData = SkinData.getById(resultId)
	if not resultData then
		NotificationEvent:FireClient(player, "Ce brainrot fusion (" .. resultId .. ") n'existe pas encore — reviens plus tard !", Color3.fromRGB(200, 150, 255))
		return
	end

	-- Consume the two input skins from the base
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
		NotificationEvent:FireClient(player, "Impossible de trouver les deux brainrots dans ta base !", Color3.fromRGB(255, 80, 80))
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

	-- Spawn the fusion result
	local slotIndex, slotPos = BaseSystem.getNextSlot(player, _playerBases)
	if not slotIndex then
		NotificationEvent:FireClient(player, "Base pleine ! Libère un emplacement d'abord.", Color3.fromRGB(255, 180, 0))
		return
	end
	local dest = Vector3.new(slotPos.X, slotPos.Y + resultData.size, slotPos.Z)
	ShopSystem.spawnSkin(resultData, dest, player, _skinOwner, slotIndex)
	if not _playerCollection[player] then _playerCollection[player] = {} end
	_playerCollection[player][resultData.id] = (_playerCollection[player][resultData.id] or 0) + 1
	CollectionUpdatedEvent:FireClient(player, _playerCollection[player])
	local rarityColor = RARITY_COLOR[resultData.rarity] or Color3.fromRGB(255, 255, 255)
	NotificationEvent:FireClient(player, "Fusion réussie ! Tu obtiens [" .. resultData.rarity .. "] " .. resultData.name .. " !", rarityColor)
end

function ShopSystem.handleFuseChoose(player, _choiceIndex)
	-- No-op: fusion is now deterministic, no choice needed
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

-- Builds one arcade-style slot pod. Returns (body, topRef).
-- body  → gets the ProximityPrompt
-- topRef → invisible part used for display-ball placement
local function makeSlotPod(cx, baseY, cz, slotNum)
	local METAL      = Color3.fromRGB(108, 112, 122)
	local METAL_DARK = Color3.fromRGB(72, 75, 85)
	local SCREEN_BG  = Color3.fromRGB(10, 10, 20)
	local RED_ACC    = Color3.fromRGB(195, 18, 18)

	local podH = 8
	local body = Instance.new("Part")
	body.Anchored   = true
	body.Size       = Vector3.new(5, podH, 4)
	body.Position   = Vector3.new(cx, baseY + podH / 2, cz)
	body.Color      = METAL
	body.Material   = Enum.Material.SmoothPlastic
	body.CanCollide = true
	body.Parent     = workspace

	-- Dark screen panel on the front face (faces belt at -X)
	local screen = Instance.new("Part")
	screen.Anchored   = true
	screen.Size       = Vector3.new(0.25, 3.5, 3.5)
	screen.Position   = Vector3.new(cx - 2.65, baseY + podH * 0.62, cz)
	screen.Color      = SCREEN_BG
	screen.Material   = Enum.Material.SmoothPlastic
	screen.CanCollide = false
	screen.Parent     = workspace

	local sg = Instance.new("SurfaceGui")
	sg.Face           = Enum.NormalId.Left
	sg.SizingMode     = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize     = Vector2.new(200, 200)
	sg.Parent         = screen
	local screenLbl = Instance.new("TextLabel")
	screenLbl.Size                   = UDim2.fromScale(1, 1)
	screenLbl.BackgroundColor3       = SCREEN_BG
	screenLbl.BackgroundTransparency = 0
	screenLbl.Text                   = "SLOT " .. slotNum .. "\n\nWAITING\nFOR\nPLAYER..."
	screenLbl.TextScaled             = true
	screenLbl.Font                   = Enum.Font.GothamBold
	screenLbl.TextColor3             = Color3.fromRGB(160, 210, 255)
	screenLbl.Parent                 = sg

	-- Red accent strip at base
	local strip = Instance.new("Part")
	strip.Anchored   = true
	strip.Size       = Vector3.new(5.2, 0.6, 4.2)
	strip.Position   = Vector3.new(cx, baseY + 0.3, cz)
	strip.Color      = RED_ACC
	strip.Material   = Enum.Material.SmoothPlastic
	strip.CanCollide = false
	strip.Parent     = workspace

	-- Side hex-style decoration panels
	for _, side in ipairs({-1, 1}) do
		local hex = Instance.new("Part")
		hex.Anchored   = true
		hex.Size       = Vector3.new(0.25, 2.5, 2.5)
		hex.Position   = Vector3.new(cx, baseY + 2.5, cz + side * 2.15)
		hex.Color      = METAL_DARK
		hex.Material   = Enum.Material.SmoothPlastic
		hex.CanCollide = false
		hex.Parent     = workspace
	end

	-- Invisible top reference for display-ball placement
	local topRef = Instance.new("Part")
	topRef.Anchored     = true
	topRef.Size         = Vector3.new(0.1, 0.1, 0.1)
	topRef.Transparency = 1
	topRef.CanCollide   = false
	topRef.Position     = Vector3.new(cx, baseY + podH + 0.5, cz)
	topRef.Parent       = workspace

	return body, topRef
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

	-- Wide stone platform
	local platform = Instance.new("Part")
	platform.Anchored  = true
	platform.Size      = Vector3.new(10, 0.5, 18)
	platform.Position  = Vector3.new(MACHINE_X, baseY, MACHINE_Z)
	platform.Color     = Color3.fromRGB(90, 90, 100)
	platform.Material  = Enum.Material.SmoothPlastic
	platform.Parent    = workspace

	-- Side slot pods (Z = ±7 from center)
	local slotZOffsets = { -7, 7 }

	-- Center control pod (shorter, darker)
	local ctrlH  = 5
	local ctrlW  = 4
	local CTRL_DARK   = Color3.fromRGB(28, 28, 35)
	local CTRL_RED    = Color3.fromRGB(210, 40, 40)
	local CTRL_YELLOW = Color3.fromRGB(240, 190, 0)

	local ctrlBody = Instance.new("Part")
	ctrlBody.Anchored   = true
	ctrlBody.Size       = Vector3.new(ctrlW, ctrlH, ctrlW)
	ctrlBody.Position   = Vector3.new(MACHINE_X, baseY + ctrlH / 2 + 0.25, MACHINE_Z)
	ctrlBody.Color      = CTRL_DARK
	ctrlBody.Material   = Enum.Material.SmoothPlastic
	ctrlBody.Parent     = workspace

	-- Dark top panel on center pod
	local ctrlTop = Instance.new("Part")
	ctrlTop.Anchored   = true
	ctrlTop.Size       = Vector3.new(ctrlW + 0.2, 0.3, ctrlW + 0.2)
	ctrlTop.Position   = Vector3.new(MACHINE_X, baseY + ctrlH + 0.25, MACHINE_Z)
	ctrlTop.Color      = Color3.fromRGB(18, 18, 24)
	ctrlTop.Material   = Enum.Material.SmoothPlastic
	ctrlTop.Parent     = workspace

	-- Exchange-arrow screen on front face of center pod
	local ctrlScreen = Instance.new("Part")
	ctrlScreen.Anchored   = true
	ctrlScreen.Size       = Vector3.new(0.2, 2, 3)
	ctrlScreen.Position   = Vector3.new(MACHINE_X - ctrlW / 2 - 0.1, baseY + ctrlH * 0.6, MACHINE_Z)
	ctrlScreen.Color      = Color3.fromRGB(15, 15, 20)
	ctrlScreen.Material   = Enum.Material.SmoothPlastic
	ctrlScreen.CanCollide = false
	ctrlScreen.Parent     = workspace
	local ctrlSg = Instance.new("SurfaceGui")
	ctrlSg.Face       = Enum.NormalId.Left
	ctrlSg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	ctrlSg.CanvasSize = Vector2.new(180, 120)
	ctrlSg.Parent     = ctrlScreen
	local ctrlLbl = Instance.new("TextLabel")
	ctrlLbl.Size                   = UDim2.fromScale(1, 1)
	ctrlLbl.BackgroundTransparency = 1
	ctrlLbl.Text                   = "🔄\nFUSION"
	ctrlLbl.TextScaled             = true
	ctrlLbl.Font                   = Enum.Font.GothamBold
	ctrlLbl.TextColor3             = Color3.fromRGB(255, 220, 50)
	ctrlLbl.Parent                 = ctrlSg

	-- Two headlights on center pod front
	for _, zOff in ipairs({ -0.8, 0.8 }) do
		local light = Instance.new("Part")
		light.Anchored   = true
		light.Shape      = Enum.PartType.Ball
		light.Size       = Vector3.new(0.5, 0.5, 0.5)
		light.Position   = Vector3.new(MACHINE_X - ctrlW / 2 - 0.3, baseY + ctrlH - 1, MACHINE_Z + zOff)
		light.Material   = Enum.Material.Neon
		light.Color      = Color3.fromRGB(255, 255, 200)
		light.CanCollide = false
		light.Parent     = workspace
	end

	-- Red/yellow stripe at base of center pod
	for i, col in ipairs({ CTRL_RED, CTRL_YELLOW, CTRL_RED, CTRL_YELLOW }) do
		local stripe = Instance.new("Part")
		stripe.Anchored   = true
		stripe.Size       = Vector3.new(ctrlW + 0.2, 0.5, 0.7)
		stripe.Position   = Vector3.new(MACHINE_X, baseY + 0.5, MACHINE_Z - 1.5 + (i - 1) * 1)
		stripe.Color      = col
		stripe.Material   = Enum.Material.SmoothPlastic
		stripe.CanCollide = false
		stripe.Parent     = workspace
	end

	-- Red/yellow buttons on top panel of center pod
	for i, bCol in ipairs({ CTRL_RED, CTRL_YELLOW }) do
		local btn = Instance.new("Part")
		btn.Anchored   = true
		btn.Shape      = Enum.PartType.Ball
		btn.Size       = Vector3.new(0.6, 0.6, 0.6)
		btn.Position   = Vector3.new(MACHINE_X, baseY + ctrlH + 0.6, MACHINE_Z - 0.6 + (i - 1) * 1.2)
		btn.Color      = bCol
		btn.Material   = Enum.Material.Neon
		btn.CanCollide = false
		btn.Parent     = workspace
	end

	-- Hidden FusionOrb inside center pod (used for flash effect)
	local orb = Instance.new("Part")
	orb.Name        = "FusionOrb"
	orb.Shape       = Enum.PartType.Ball
	orb.Anchored    = true
	orb.Size        = Vector3.new(1, 1, 1)
	orb.Transparency = 1
	orb.CanCollide  = false
	orb.Position    = Vector3.new(MACHINE_X, baseY + ctrlH / 2, MACHINE_Z)
	orb.Parent      = workspace

	-- BillboardGui sign on center pod
	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0, 320, 0, 80)
	bb.StudsOffset = Vector3.new(0, ctrlH + 2.5, 0)
	bb.Parent      = ctrlBody
	local title = Instance.new("TextLabel")
	title.Size                   = UDim2.new(1, 0, 0.5, 0)
	title.BackgroundTransparency = 1
	title.Text                   = "⚡ FUSION MACHINE"
	title.TextScaled             = true
	title.Font                   = Enum.Font.GothamBold
	title.TextColor3             = Color3.fromRGB(255, 255, 100)
	title.Parent                 = bb
	local hint = Instance.new("TextLabel")
	hint.Size                   = UDim2.new(1, 0, 0.5, 0)
	hint.Position               = UDim2.new(0, 0, 0.5, 0)
	hint.BackgroundTransparency = 1
	hint.Text                   = "Carry skins to the 2 slots & press E"
	hint.TextScaled             = true
	hint.Font                   = Enum.Font.Gotham
	hint.TextColor3             = Color3.fromRGB(200, 200, 255)
	hint.Parent                 = bb

	-- Connecting pipes: horizontal cylinders from each side pod top to center pod top
	local pipeY     = baseY + 8.5   -- just above pod tops (pod height = 8)
	local pipeColor = Color3.fromRGB(60, 62, 72)
	for _, zOff in ipairs(slotZOffsets) do
		local pipeLen = math.abs(zOff)   -- distance from center to pod
		local pipe = Instance.new("Part")
		pipe.Anchored   = true
		pipe.Shape      = Enum.PartType.Cylinder
		pipe.Size       = Vector3.new(pipeLen, 1, 1)
		-- Cylinder extends along X by default; rotate 90° around Y so it runs along Z
		pipe.CFrame     = CFrame.new(MACHINE_X, pipeY, MACHINE_Z + zOff / 2)
			* CFrame.Angles(0, math.pi / 2, 0)
		pipe.Color      = pipeColor
		pipe.Material   = Enum.Material.SmoothPlastic
		pipe.CanCollide = false
		pipe.Parent     = workspace

		-- Elbow connector cube at the pod end
		local elbow = Instance.new("Part")
		elbow.Anchored   = true
		elbow.Size       = Vector3.new(1.2, 1.2, 1.2)
		elbow.Position   = Vector3.new(MACHINE_X, pipeY, MACHINE_Z + zOff)
		elbow.Color      = pipeColor
		elbow.Material   = Enum.Material.SmoothPlastic
		elbow.CanCollide = false
		elbow.Parent     = workspace
	end

	-- Store the topRef of each slot pod so we can place display balls on them
	local slotTops = {}

	for slotNum = 1, 2 do
		local sz = MACHINE_Z + slotZOffsets[slotNum]
		local ped, top = makeSlotPod(MACHINE_X, baseY + 0.25, sz, slotNum)
		slotTops[slotNum] = top

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText            = "Deposit Skin"
		prompt.ObjectText            = "Emplacement Fusion " .. slotNum
		prompt.HoldDuration          = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight   = false
		prompt.Parent                = ped

		local slotNumCopy = slotNum
		prompt.Triggered:Connect(function(trigPlayer)
			-- Player must be carrying a skin they own
			local carried = _carrying[trigPlayer]
			if not carried then
				NotificationEvent:FireClient(trigPlayer, "Porte un brainrot vers cet emplacement d'abord !", Color3.fromRGB(255, 180, 0))
				return
			end
			if _skinOwner[carried] ~= trigPlayer then
				NotificationEvent:FireClient(trigPlayer, "Tu ne peux fusionner que tes propres brainrots !", Color3.fromRGB(255, 80, 80))
				return
			end

			local bId   = carried:GetAttribute("SkinId") or ""
			local bData = SkinData.getById(bId)
			if not bData then
				NotificationEvent:FireClient(trigPlayer, "Brainrot inconnu !", Color3.fromRGB(255, 80, 80))
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

			NotificationEvent:FireClient(trigPlayer, bData.name .. " déposé dans l'emplacement " .. slotNumCopy .. " !", Color3.fromRGB(100, 200, 255))

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
					NotificationEvent:FireClient(trigPlayer, "Base pleine ! Libère un emplacement d'abord.", Color3.fromRGB(255, 180, 0))
					return
				end
				local dest = Vector3.new(slotPos.X, slotPos.Y + chosen.size, slotPos.Z)

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
				local walkStartPos = Vector3.new(MACHINE_X, BELT_Y + 0.3 + chosen.size, MACHINE_Z)
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
							walkModel:SetPrimaryPartCFrame(CFrame.new(segStartPos))
						else
							walkConn:Disconnect(); _flyingBodies[walkBody] = nil
							walkModel:Destroy()
							if trigPlayer and trigPlayer.Parent then
								ShopSystem.spawnSkin(chosen, dest, trigPlayer, _skinOwner, slotIdx)
								if not _playerCollection[trigPlayer] then _playerCollection[trigPlayer] = {} end
								_playerCollection[trigPlayer][chosen.id] = (_playerCollection[trigPlayer][chosen.id] or 0) + 1
								CollectionUpdatedEvent:FireClient(trigPlayer, _playerCollection[trigPlayer])
								local rc = RARITY_COLOR[chosen.rarity] or Color3.fromRGB(255, 255, 255)
								NotificationEvent:FireClient(trigPlayer, "Fusion : [" .. chosen.rarity .. "] " .. chosen.name .. " !", rc)
							end
						end
						return
					end
					walkModel:SetPrimaryPartCFrame(CFrame.new(segStartPos:Lerp(segEndPos, walkT)))
				end)
			end
		end)
	end
end

return ShopSystem
