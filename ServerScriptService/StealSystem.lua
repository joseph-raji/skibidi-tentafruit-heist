-- StealSystem.lua
-- ModuleScript: handles skin stealing, carrying, and claiming logic

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StealSystem = {}

local BASE_SIZE = 52
local CARRY_SIDE_OFFSET = 1.8  -- studs to the right of the carrier

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local evtSkinStolen     = remoteEvents:WaitForChild("SkinStolen")
local evtSkinClaimed    = remoteEvents:WaitForChild("SkinClaimed")
local evtNotification       = remoteEvents:WaitForChild("Notification")
local evtCollectionUpdated  = remoteEvents:WaitForChild("CollectionUpdated")

-- ShopSystem reference (set via StealSystem.setShopSystem)
local _shopSystem = nil
function StealSystem.setShopSystem(ss) _shopSystem = ss end

-- Internal debounce table to prevent repeated touch triggers
local touchDebounce = {}

-- Per-skin touch connection storage
local touchConnections = {}

function StealSystem.init(playerBases, skinOwner, carrying, playerCollection)
	-- Called once at startup. State tables are passed in by reference from Main.server.lua.
	-- Nothing needs to be stored here since all functions receive the tables as parameters.
end

function StealSystem.startCarrying(player, skin, playerBases, skinOwner, carrying)
	-- Guard: player already carrying something
	if carrying[player] then
		return
	end

	-- Guard: skin is already being carried by someone
	for _, carriedPart in pairs(carrying) do
		if carriedPart == skin then
			return
		end
	end

	-- Guard: skin has no owner entry
	local victim = skinOwner[skin]
	if not victim then
		return
	end

	local isOwnSkin = (victim == player)

	-- Guard: victim's base is locked (only applies when stealing)
	if not isOwnSkin then
		local victimBase = playerBases[victim]
		if victimBase and victimBase.isLocked then
			evtNotification:FireClient(player, "That base is protected by a lock shield!", Color3.fromRGB(255, 100, 100))
			return
		end
	end

	-- Guard: player character must exist
	local character = player.Character
	if not character then
		return
	end

	local skinName = skin:GetAttribute("SkinName") or "Skin"

	-- Begin carrying
	skin.Anchored = false
	carrying[player] = skin

	player:SetAttribute("IsCarrying", true)
	player:SetAttribute("CarryingSkinName", skinName)

	if isOwnSkin then
		-- Immediately free the slot so the empty plate reappears and the player
		-- can place the skin in any available slot (including the same one).
		if _shopSystem then
			local oldSlot = skin:GetAttribute("SlotIndex")
			if oldSlot then
				_shopSystem.removePlate(skin)
				_shopSystem.releaseSlot(player, oldSlot)
			end
		end
		evtNotification:FireClient(player, "Picked up " .. skinName .. ". Press E on any slot to place it!", Color3.fromRGB(200, 200, 255))
	else
		-- Notify victim (orange)
		evtNotification:FireClient(victim, player.Name .. " is stealing your " .. skinName .. "!", Color3.fromRGB(255, 140, 0))
		evtSkinStolen:FireClient(victim, player.Name, skinName)
		evtNotification:FireClient(player, "You grabbed " .. skinName .. "! Run to your base!", Color3.fromRGB(80, 200, 255))
	end
end

function StealSystem.dropSkin(player, carrying)
	local skin = carrying[player]
	if not skin then
		return
	end

	-- Anchor skin at its current position
	skin.Anchored = true

	carrying[player] = nil
	player:SetAttribute("IsCarrying", false)
	player:SetAttribute("CarryingSkinName", "")
end

function StealSystem.claimSkin(player, playerBases, skinOwner, carrying, playerCollection)
	local skin = carrying[player]
	if not skin then
		return
	end

	local skinName = skin:GetAttribute("SkinName") or skin.Name
	local baseData = playerBases[player]
	if not baseData then
		return
	end

	-- Read IncomePerSecond before transferring ownership so it is preserved
	local income = skin:GetAttribute("IncomePerSecond") or 0
	local originalOwner = skinOwner[skin]
	local isOwnSkin = (originalOwner == player)

	if not isOwnSkin then
		-- Stealing: update collection and award money
		if not playerCollection[player] then
			playerCollection[player] = {}
		end
		local skinId = skinName
		playerCollection[player][skinId] = (playerCollection[player][skinId] or 0) + 1
		local multiplier = player:GetAttribute("MoneyMultiplier") or 1
		local currentMoney = player:GetAttribute("Money") or 0
		player:SetAttribute("Money", currentMoney + (100 * multiplier))
	end

	-- Transfer ownership
	skinOwner[skin] = player
	skin:SetAttribute("IncomePerSecond", income)

	-- Clear carrying state
	carrying[player] = nil
	player:SetAttribute("IsCarrying", false)
	player:SetAttribute("CarryingSkinName", "")

	-- Move skin to a random spot inside the player's base
	local basePos = baseData.position
	local halfSize = BASE_SIZE / 2 - 4
	local randomX = basePos.X + math.random(-halfSize, halfSize)
	local randomZ = basePos.Z + math.random(-halfSize, halfSize)
	skin.CFrame = CFrame.new(randomX, basePos.Y + 3, randomZ)
	skin.Anchored = true

	-- Re-attach touch events with new owner so it can be stolen again
	StealSystem.setupSkinTouchEvents(skin, player, playerBases, skinOwner, carrying, playerCollection)

	if isOwnSkin then
		evtNotification:FireClient(player, skinName .. " placed!", Color3.fromRGB(200, 200, 255))
	else
		evtNotification:FireClient(player, "You claimed " .. skinName .. "!", Color3.fromRGB(0, 220, 100))
		evtSkinClaimed:FireClient(player, skinName)
	end
end

function StealSystem.setupSkinTouchEvents(skin, owner, playerBases, skinOwner, carrying, playerCollection)
	-- Disconnect any existing connections for this skin
	if touchConnections[skin] then
		for _, conn in ipairs(touchConnections[skin]) do
			conn:Disconnect()
		end
	end
	touchConnections[skin] = {}

	local connections = touchConnections[skin]

	-- ProximityPrompt: non-owner presses E → start carrying (steal)
	local oldPrompt = skin:FindFirstChildOfClass("ProximityPrompt")
	if oldPrompt then oldPrompt:Destroy() end

	local stealPrompt = Instance.new("ProximityPrompt")
	stealPrompt.ActionText            = "Carry"
	stealPrompt.ObjectText            = skin:GetAttribute("SkinName") or "Skin"
	stealPrompt.HoldDuration          = 0
	stealPrompt.MaxActivationDistance = 8
	stealPrompt.Parent                = skin

	local conn0 = stealPrompt.Triggered:Connect(function(trigPlayer)
		if not carrying[trigPlayer] then
			StealSystem.startCarrying(trigPlayer, skin, playerBases, skinOwner, carrying)
		end
	end)
	table.insert(connections, conn0)

	-- Touch event 1: non-owner touches skin → start carrying
	local conn1 = skin.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local touchingPlayer = Players:GetPlayerFromCharacter(character)
		if not touchingPlayer then return end

		-- Only non-owners can steal
		local currentOwner = skinOwner[skin]
		if touchingPlayer == currentOwner then return end

		-- Debounce
		local debounceKey = tostring(touchingPlayer.UserId) .. "_" .. skin:GetFullName()
		if touchDebounce[debounceKey] then return end
		touchDebounce[debounceKey] = true
		task.delay(1, function()
			touchDebounce[debounceKey] = nil
		end)

		-- Not already carrying
		if not carrying[touchingPlayer] then
			StealSystem.startCarrying(touchingPlayer, skin, playerBases, skinOwner, carrying)
		end
	end)
	table.insert(connections, conn1)

	-- Touch event 2: a different player touches the carrier while they carry this skin → drop
	local conn2 = skin.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local touchingPlayer = Players:GetPlayerFromCharacter(character)
		if not touchingPlayer then return end

		-- Find who is carrying this skin
		local carrier = nil
		for p, carriedPart in pairs(carrying) do
			if carriedPart == skin then
				carrier = p
				break
			end
		end

		if not carrier then return end
		if touchingPlayer == carrier then return end

		-- Enemy player hit the carrier while carrying: drop the skin
		local debounceKey = "drop_" .. skin:GetFullName()
		if touchDebounce[debounceKey] then return end
		touchDebounce[debounceKey] = true
		task.delay(1, function()
			touchDebounce[debounceKey] = nil
		end)

		local droppedName = skin:GetAttribute("SkinName") or skin.Name

		StealSystem.dropSkin(carrier, carrying)
		evtNotification:FireClient(carrier, "You got hit! " .. droppedName .. " dropped!", Color3.fromRGB(255, 80, 80))
		evtNotification:FireClient(touchingPlayer, "Hit! You knocked their " .. droppedName .. " loose!", Color3.fromRGB(100, 255, 120))
	end)
	table.insert(connections, conn2)

	-- Clean up connection table when skin is destroyed / removed from workspace
	skin.AncestryChanged:Connect(function()
		if not skin.Parent then
			if touchConnections[skin] then
				for _, conn in ipairs(touchConnections[skin]) do
					conn:Disconnect()
				end
				touchConnections[skin] = nil
			end
		end
	end)
end

function StealSystem.onHeartbeat(playerBases, skinOwner, carrying, playerCollection)
	for player, skin in pairs(carrying) do
		local character = player.Character
		if not character then
			-- Player disconnected or respawned, drop it
			StealSystem.dropSkin(player, carrying)
			continue
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			StealSystem.dropSkin(player, carrying)
			continue
		end

		-- Move skin beside carrier at ground level
		local bodySize = skin:GetAttribute("BodySize") or 2
		local rightVec = root.CFrame.RightVector
		local sidePos  = root.Position + rightVec * (bodySize * 0.5 + CARRY_SIDE_OFFSET)
		skin.CFrame = CFrame.new(sidePos.X, root.Position.Y - 2.5 + bodySize * 0.5, sidePos.Z)

		local rootPos = root.Position

		-- Check if carrier is inside their own base
		local baseData = playerBases[player]
		if not baseData then continue end

		local basePos = baseData.position
		local halfBound = BASE_SIZE / 2 - 3

		local insideX = math.abs(rootPos.X - basePos.X) < halfBound
		local insideZ = math.abs(rootPos.Z - basePos.Z) < halfBound

		if insideX and insideZ then
			-- Only auto-claim stolen skins; own skins require the player to press E on a slot plate
			if skinOwner[skin] ~= player then
				StealSystem.claimSkin(player, playerBases, skinOwner, carrying, playerCollection)
			end
		end
	end
end

-- =========================================================================
-- Public: sellSkin
-- Called when a player holds F for 2 seconds to discard their carried skin.
-- =========================================================================

function StealSystem.sellSkin(player, playerBases, skinOwner, carrying, playerCollection)
	local skin = carrying[player]
	if not skin then return end
	if skinOwner[skin] ~= player then return end  -- can only sell own skins

	local bId   = skin:GetAttribute("SkinId") or ""
	local bName = skin:GetAttribute("SkinName") or "Skin"

	-- Update collection count
	if playerCollection[player] and bId ~= "" then
		local count = (playerCollection[player][bId] or 1) - 1
		if count <= 0 then
			playerCollection[player][bId] = nil
		else
			playerCollection[player][bId] = count
		end
	end

	skinOwner[skin] = nil
	carrying[player] = nil
	player:SetAttribute("IsCarrying", false)
	player:SetAttribute("CarryingSkinName", "")

	local m = skin.Parent
	if m and m:IsA("Model") then
		m:Destroy()
	elseif skin and skin.Parent then
		skin:Destroy()
	end

	evtCollectionUpdated:FireClient(player, playerCollection[player] or {})
	evtNotification:FireClient(player, bName .. " discarded!", Color3.fromRGB(255, 160, 50))
end

return StealSystem
