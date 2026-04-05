-- CombatSystem.lua
-- ModuleScript: handles bat combat, hit detection, and forced brainrot drops

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatSystem = {}

local BAT_COOLDOWN = 1.5
local HIT_RANGE = 8

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local evtNotification = remoteEvents:WaitForChild("Notification")

-- Per-player swing cooldown tracker
local swingCooldowns = {}

-- Shared state, set by init
local _carrying = nil
local _playerBases = nil
local _brainrotOwner = nil

function CombatSystem.init(carrying, playerBases, brainrotOwner)
	_carrying = carrying
	_playerBases = playerBases
	_brainrotOwner = brainrotOwner
end

function CombatSystem.dropBrainrot(player, carrying)
	local brainrot = carrying[player]
	if not brainrot then
		return
	end

	-- Anchor the brainrot in place where it was dropped
	brainrot.Anchored = true

	carrying[player] = nil
	player:SetAttribute("IsCarrying", false)
	player:SetAttribute("CarryingBrainrotName", "")

	evtNotification:FireClient(
		player,
		"You were hit! Dropped the brainrot!",
		Color3.fromRGB(220, 50, 50)
	)
end

function CombatSystem.detectHit(attacker, carrying, playerBases, brainrotOwner)
	local attackerChar = attacker.Character
	if not attackerChar then
		return
	end

	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	if not attackerRoot then
		return
	end

	local attackerPos = attackerRoot.Position
	local hitSomeone = false

	for _, target in ipairs(Players:GetPlayers()) do
		if target == attacker then
			continue
		end

		local targetChar = target.Character
		if not targetChar then
			continue
		end

		local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
		if not targetRoot then
			continue
		end

		local distance = (attackerPos - targetRoot.Position).Magnitude
		if distance > HIT_RANGE then
			continue
		end

		-- Hit visual: brief red highlight on the target's character
		for _, part in ipairs(targetChar:GetDescendants()) do
			if part:IsA("BasePart") then
				local originalColor = part.Color
				local originalMaterial = part.Material
				part.Color = Color3.fromRGB(220, 50, 50)
				part.Material = Enum.Material.Neon
				task.delay(0.2, function()
					if part and part.Parent then
						part.Color = originalColor
						part.Material = originalMaterial
					end
				end)
			end
		end

		if carrying[target] then
			CombatSystem.dropBrainrot(target, carrying)
			evtNotification:FireClient(
				attacker,
				"Hit! You made " .. target.Name .. " drop their brainrot!",
				Color3.fromRGB(50, 220, 100)
			)
			hitSomeone = true
		else
			evtNotification:FireClient(
				attacker,
				"Hit " .. target.Name .. "! (They weren't carrying anything)",
				Color3.fromRGB(255, 200, 50)
			)
			evtNotification:FireClient(
				target,
				attacker.Name .. " hit you with a Skibidi Bat!",
				Color3.fromRGB(220, 50, 50)
			)
			hitSomeone = true
		end
	end

	if not hitSomeone then
		evtNotification:FireClient(
			attacker,
			"Swing and a miss! No one in range.",
			Color3.fromRGB(180, 180, 180)
		)
	end
end

function CombatSystem.createBatTool()
	local tool = Instance.new("Tool")
	tool.Name = "Skibidi Bat"
	tool.ToolTip = "Hit carriers to make them drop!"
	tool.RequiresHandle = true

	-- Handle: a simple brown bat shape
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 3, 1)
	handle.Color = Color3.fromRGB(101, 71, 25) -- brown
	handle.Material = Enum.Material.SmoothPlastic
	handle.CastShadow = true
	handle.Parent = tool

	-- Grip offset: hold near the bottom of the bat
	tool.GripPos = Vector3.new(0, -1.2, 0)
	tool.GripForward = Vector3.new(0, 0, 1)
	tool.GripRight = Vector3.new(1, 0, 0)
	tool.GripUp = Vector3.new(0, 1, 0)

	-- Swing logic on Activated
	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player then
			return
		end

		-- Enforce cooldown
		local now = tick()
		if swingCooldowns[player] and (now - swingCooldowns[player]) < BAT_COOLDOWN then
			return
		end
		swingCooldowns[player] = now

		-- Visual swing effect: flash handle yellow briefly
		local originalColor = handle.Color
		handle.Color = Color3.fromRGB(255, 220, 50)
		task.delay(0.15, function()
			if handle and handle.Parent then
				handle.Color = originalColor
			end
		end)

		-- Perform hit detection using shared state
		if _carrying and _playerBases and _brainrotOwner then
			CombatSystem.detectHit(player, _carrying, _playerBases, _brainrotOwner)
		end
	end)

	return tool
end

function CombatSystem.giveBatToPlayer(player, batTool)
	local function giveOnSpawn(character)
		-- Wait a frame for the backpack to be ready
		task.wait()
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			local clone = batTool:Clone()
			clone.Parent = backpack
		end
	end

	-- Give to current character if already spawned
	if player.Character then
		giveOnSpawn(player.Character)
	end

	-- Re-give on every future respawn
	player.CharacterAdded:Connect(giveOnSpawn)
end

return CombatSystem
