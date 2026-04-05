-- StealSystem.lua
-- ModuleScript: handles brainrot stealing, carrying, and claiming logic

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StealSystem = {}

local BASE_SIZE = 44
local CARRY_OFFSET = Vector3.new(0, 7, 0)

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local evtBrainrotStolen = remoteEvents:WaitForChild("BrainrotStolen")
local evtBrainrotClaimed = remoteEvents:WaitForChild("BrainrotClaimed")
local evtNotification = remoteEvents:WaitForChild("Notification")

-- Internal debounce table to prevent repeated touch triggers
local touchDebounce = {}

-- Per-brainrot touch connection storage
local touchConnections = {}

function StealSystem.init(playerBases, brainrotOwner, carrying, playerCollection)
	-- Called once at startup. State tables are passed in by reference from Main.server.lua.
	-- Nothing needs to be stored here since all functions receive the tables as parameters.
end

function StealSystem.startCarrying(player, brainrot, playerBases, brainrotOwner, carrying)
	-- Guard: player already carrying something
	if carrying[player] then
		return
	end

	-- Guard: brainrot is already being carried by someone
	for _, carriedPart in pairs(carrying) do
		if carriedPart == brainrot then
			return
		end
	end

	-- Guard: brainrot has no owner entry
	local victim = brainrotOwner[brainrot]
	if not victim then
		return
	end

	local isOwnBrainrot = (victim == player)

	-- Guard: victim's base is locked (only applies when stealing)
	if not isOwnBrainrot then
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

	local brainrotName = brainrot:GetAttribute("BrainrotName") or "Brainrot"

	-- Begin carrying
	brainrot.Anchored = false
	carrying[player] = brainrot

	player:SetAttribute("IsCarrying", true)
	player:SetAttribute("CarryingBrainrotName", brainrotName)

	if isOwnBrainrot then
		evtNotification:FireClient(player, "Picked up " .. brainrotName .. ". Walk back to your base!", Color3.fromRGB(200, 200, 255))
	else
		-- Notify victim (orange)
		evtNotification:FireClient(victim, player.Name .. " is stealing your " .. brainrotName .. "!", Color3.fromRGB(255, 140, 0))
		evtBrainrotStolen:FireClient(victim, player.Name, brainrotName)
		evtNotification:FireClient(player, "You grabbed " .. brainrotName .. "! Run to your base!", Color3.fromRGB(80, 200, 255))
	end
end

function StealSystem.dropBrainrot(player, carrying)
	local brainrot = carrying[player]
	if not brainrot then
		return
	end

	-- Anchor brainrot at its current position
	brainrot.Anchored = true

	carrying[player] = nil
	player:SetAttribute("IsCarrying", false)
	player:SetAttribute("CarryingBrainrotName", "")
end

function StealSystem.claimBrainrot(player, playerBases, brainrotOwner, carrying, playerCollection)
	local brainrot = carrying[player]
	if not brainrot then
		return
	end

	local brainrotName = brainrot:GetAttribute("BrainrotName") or brainrot.Name
	local baseData = playerBases[player]
	if not baseData then
		return
	end

	-- Read IncomePerSecond before transferring ownership so it is preserved
	local income = brainrot:GetAttribute("IncomePerSecond") or 0
	local originalOwner = brainrotOwner[brainrot]
	local isOwnBrainrot = (originalOwner == player)

	if not isOwnBrainrot then
		-- Stealing: update collection and award money
		if not playerCollection[player] then
			playerCollection[player] = {}
		end
		local brainrotId = brainrotName
		playerCollection[player][brainrotId] = (playerCollection[player][brainrotId] or 0) + 1
		local multiplier = player:GetAttribute("MoneyMultiplier") or 1
		local currentMoney = player:GetAttribute("Money") or 0
		player:SetAttribute("Money", currentMoney + (100 * multiplier))
	end

	-- Transfer ownership
	brainrotOwner[brainrot] = player
	brainrot:SetAttribute("IncomePerSecond", income)

	-- Clear carrying state
	carrying[player] = nil
	player:SetAttribute("IsCarrying", false)
	player:SetAttribute("CarryingBrainrotName", "")

	-- Move brainrot to a random spot inside the player's base
	local basePos = baseData.position
	local halfSize = BASE_SIZE / 2 - 4
	local randomX = basePos.X + math.random(-halfSize, halfSize)
	local randomZ = basePos.Z + math.random(-halfSize, halfSize)
	brainrot.CFrame = CFrame.new(randomX, basePos.Y + 3, randomZ)
	brainrot.Anchored = true

	-- Re-attach touch events with new owner so it can be stolen again
	StealSystem.setupBrainrotTouchEvents(brainrot, player, playerBases, brainrotOwner, carrying, playerCollection)

	if isOwnBrainrot then
		evtNotification:FireClient(player, brainrotName .. " placed!", Color3.fromRGB(200, 200, 255))
	else
		evtNotification:FireClient(player, "You claimed " .. brainrotName .. "!", Color3.fromRGB(0, 220, 100))
		evtBrainrotClaimed:FireClient(player, brainrotName)
	end
end

function StealSystem.setupBrainrotTouchEvents(brainrot, owner, playerBases, brainrotOwner, carrying, playerCollection)
	-- Disconnect any existing connections for this brainrot
	if touchConnections[brainrot] then
		for _, conn in ipairs(touchConnections[brainrot]) do
			conn:Disconnect()
		end
	end
	touchConnections[brainrot] = {}

	local connections = touchConnections[brainrot]

	-- ProximityPrompt: non-owner presses E → start carrying (steal)
	local oldPrompt = brainrot:FindFirstChildOfClass("ProximityPrompt")
	if oldPrompt then oldPrompt:Destroy() end

	local stealPrompt = Instance.new("ProximityPrompt")
	stealPrompt.ActionText            = "Carry"
	stealPrompt.ObjectText            = brainrot:GetAttribute("BrainrotName") or "Brainrot"
	stealPrompt.HoldDuration          = 0
	stealPrompt.MaxActivationDistance = 8
	stealPrompt.Parent                = brainrot

	local conn0 = stealPrompt.Triggered:Connect(function(trigPlayer)
		if not carrying[trigPlayer] then
			StealSystem.startCarrying(trigPlayer, brainrot, playerBases, brainrotOwner, carrying)
		end
	end)
	table.insert(connections, conn0)

	-- Touch event 1: non-owner touches brainrot → start carrying
	local conn1 = brainrot.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local touchingPlayer = Players:GetPlayerFromCharacter(character)
		if not touchingPlayer then return end

		-- Only non-owners can steal
		local currentOwner = brainrotOwner[brainrot]
		if touchingPlayer == currentOwner then return end

		-- Debounce
		local debounceKey = tostring(touchingPlayer.UserId) .. "_" .. brainrot:GetFullName()
		if touchDebounce[debounceKey] then return end
		touchDebounce[debounceKey] = true
		task.delay(1, function()
			touchDebounce[debounceKey] = nil
		end)

		-- Not already carrying
		if not carrying[touchingPlayer] then
			StealSystem.startCarrying(touchingPlayer, brainrot, playerBases, brainrotOwner, carrying)
		end
	end)
	table.insert(connections, conn1)

	-- Touch event 2: a different player touches the carrier while they carry this brainrot → drop
	local conn2 = brainrot.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local touchingPlayer = Players:GetPlayerFromCharacter(character)
		if not touchingPlayer then return end

		-- Find who is carrying this brainrot
		local carrier = nil
		for p, carriedPart in pairs(carrying) do
			if carriedPart == brainrot then
				carrier = p
				break
			end
		end

		if not carrier then return end
		if touchingPlayer == carrier then return end

		-- Enemy player hit the carrier while carrying: drop the brainrot
		local debounceKey = "drop_" .. brainrot:GetFullName()
		if touchDebounce[debounceKey] then return end
		touchDebounce[debounceKey] = true
		task.delay(1, function()
			touchDebounce[debounceKey] = nil
		end)

		local droppedName = brainrot:GetAttribute("BrainrotName") or brainrot.Name

		StealSystem.dropBrainrot(carrier, carrying)
		evtNotification:FireClient(carrier, "You got hit! " .. droppedName .. " dropped!", Color3.fromRGB(255, 80, 80))
		evtNotification:FireClient(touchingPlayer, "Hit! You knocked their " .. droppedName .. " loose!", Color3.fromRGB(100, 255, 120))
	end)
	table.insert(connections, conn2)

	-- Clean up connection table when brainrot is destroyed / removed from workspace
	brainrot.AncestryChanged:Connect(function()
		if not brainrot.Parent then
			if touchConnections[brainrot] then
				for _, conn in ipairs(touchConnections[brainrot]) do
					conn:Disconnect()
				end
				touchConnections[brainrot] = nil
			end
		end
	end)
end

function StealSystem.onHeartbeat(playerBases, brainrotOwner, carrying, playerCollection)
	for player, brainrot in pairs(carrying) do
		local character = player.Character
		if not character then
			-- Player disconnected or respawned, drop it
			StealSystem.dropBrainrot(player, carrying)
			continue
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			StealSystem.dropBrainrot(player, carrying)
			continue
		end

		-- Move brainrot above carrier's head
		brainrot.CFrame = CFrame.new(root.Position + CARRY_OFFSET)

		-- Check if carrier is inside their own base
		local baseData = playerBases[player]
		if not baseData then continue end

		local basePos = baseData.position
		local rootPos = root.Position
		local halfBound = BASE_SIZE / 2 - 3

		local insideX = math.abs(rootPos.X - basePos.X) < halfBound
		local insideZ = math.abs(rootPos.Z - basePos.Z) < halfBound

		if insideX and insideZ then
			-- Only auto-claim stolen brainrots; own brainrots require the player to press E on a slot plate
			if brainrotOwner[brainrot] ~= player then
				StealSystem.claimBrainrot(player, playerBases, brainrotOwner, carrying, playerCollection)
			end
		end
	end
end

return StealSystem
