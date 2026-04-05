-- StealSystem.lua
-- ModuleScript: handles brainrot stealing, carrying, and claiming logic

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StealSystem = {}

local BASE_SIZE = 44
local CARRY_OFFSET = Vector3.new(0, 5.5, 0)

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local evtBrainrotStolen = remoteEvents:WaitForChild("BrainrotStolen")
local evtBrainrotClaimed = remoteEvents:WaitForChild("BrainrotClaimed")
local evtNotification = remoteEvents:WaitForChild("Notification")

-- Internal debounce table to prevent repeated touch triggers
local touchDebounce = {}

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

	-- Guard: cannot steal from yourself
	if victim == player then
		return
	end

	-- Guard: victim's base is locked
	local victimBase = playerBases[victim]
	if victimBase and victimBase.isLocked then
		evtNotification:FireClient(player, "That base is protected by a lock shield!", Color3.fromRGB(255, 100, 100))
		return
	end

	-- Guard: player character must exist
	local character = player.Character
	if not character then
		return
	end

	local brainrotName = brainrot.Name

	-- Begin carrying
	brainrot.Anchored = false
	carrying[player] = brainrot

	player:SetAttribute("IsCarrying", true)
	player:SetAttribute("CarryingBrainrotName", brainrotName)

	-- Notify victim (orange)
	evtNotification:FireClient(victim, player.Name .. " is stealing your " .. brainrotName .. "!", Color3.fromRGB(255, 140, 0))

	-- Fire stolen event for victim UI
	evtBrainrotStolen:FireClient(victim, player.Name, brainrotName)
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

	local brainrotName = brainrot.Name
	local baseData = playerBases[player]
	if not baseData then
		return
	end

	local userId = player.UserId

	-- Update collection
	if not playerCollection[player] then
		playerCollection[player] = {}
	end

	local brainrotId = brainrotName
	playerCollection[player][brainrotId] = (playerCollection[player][brainrotId] or 0) + 1

	-- Apply money multiplier
	local multiplier = player:GetAttribute("MoneyMultiplier") or 1
	local currentMoney = player:GetAttribute("Money") or 0
	player:SetAttribute("Money", currentMoney + (100 * multiplier))

	-- Transfer ownership
	brainrotOwner[brainrot] = player

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

	-- Re-attach touch events with new owner
	StealSystem.setupBrainrotTouchEvents(brainrot, player, playerBases, brainrotOwner, carrying, playerCollection)

	-- Notify thief (green)
	evtNotification:FireClient(player, "You claimed " .. brainrotName .. "!", Color3.fromRGB(0, 220, 100))
	evtBrainrotClaimed:FireClient(player, brainrotName)
end

function StealSystem.setupBrainrotTouchEvents(brainrot, owner, playerBases, brainrotOwner, carrying, playerCollection)
	-- Disconnect any previously connected touch events stored on the part
	if brainrot:GetAttribute("TouchEventsConnected") then
		-- Disconnect by storing connections on the instance via a BindableEvent workaround.
		-- We use ObjectValue children to store connections; clean them up first.
	end

	-- Use a separate connection storage table keyed by brainrot
	if not StealSystem._touchConnections then
		StealSystem._touchConnections = {}
	end

	-- Disconnect old connections for this brainrot
	local oldConns = StealSystem._touchConnections[brainrot]
	if oldConns then
		for _, conn in ipairs(oldConns) do
			conn:Disconnect()
		end
	end

	local connections = {}
	StealSystem._touchConnections[brainrot] = connections

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

	-- Touch event 2: brainrot is being carried and a different player touches carrier → drop
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

		StealSystem.dropBrainrot(carrier, carrying)
		evtNotification:FireClient(carrier, touchingPlayer.Name .. " knocked the brainrot out of your hands!", Color3.fromRGB(255, 80, 80))
	end)
	table.insert(connections, conn2)
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
			StealSystem.claimBrainrot(player, playerBases, brainrotOwner, carrying, playerCollection)
		end
	end
end

return StealSystem
