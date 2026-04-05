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

	-- Anchor the brainrot at its current position
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

local function flashRed(character)
	local origColors = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			origColors[part] = part.BrickColor
			part.BrickColor = BrickColor.new("Bright red")
		end
	end
	task.delay(0.2, function()
		for part, color in pairs(origColors) do
			if part and part.Parent then
				part.BrickColor = color
			end
		end
	end)
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

		local dist = (targetRoot.Position - attackerRoot.Position).Magnitude
		if dist > HIT_RANGE then
			continue
		end

		-- Check shield before applying any hit effects
		local hasShield = target:GetAttribute("HasShield") == true
		if hasShield then
			-- Shield absorbs the hit
			target:SetAttribute("HasShield", false)
			-- Destroy the shield bubble Part on the character
			local char = target.Character
			if char then
				for _, part in ipairs(char:GetChildren()) do
					if part.Name == "ShieldBubble" then
						part:Destroy()
					end
				end
			end
			evtNotification:FireClient(attacker, "🛡️ Their shield blocked your hit!", Color3.fromRGB(100, 200, 255))
			evtNotification:FireClient(target, "🛡️ Shield blocked a hit!", Color3.fromRGB(100, 200, 255))
			hitSomeone = true
			continue
		end

		-- No shield: apply hit flash
		flashRed(targetChar)

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

	-- Handle: main bat body (tall, brown, Wood material)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 4, 1)
	handle.BrickColor = BrickColor.new("Reddish brown")
	handle.Material = Enum.Material.Wood
	handle.CastShadow = true
	handle.Parent = tool

	-- Grip wrap: darker band at the bottom of the handle
	local grip = Instance.new("Part")
	grip.Name = "GripWrap"
	grip.Size = Vector3.new(1.2, 1.5, 1.2)
	grip.BrickColor = BrickColor.new("Dark orange")
	grip.Material = Enum.Material.Wood
	grip.CastShadow = false
	grip.Parent = tool

	local gripWeld = Instance.new("WeldConstraint")
	gripWeld.Part0 = handle
	gripWeld.Part1 = grip
	gripWeld.Parent = handle

	-- Position grip at the bottom of the handle
	grip.CFrame = handle.CFrame * CFrame.new(0, -1.25, 0)

	-- "SKIBIDI BAT" label via SurfaceGui
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize = Vector2.new(200, 800)
	surfaceGui.Parent = handle

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "SKIBIDI BAT"
	label.TextColor3 = Color3.fromRGB(255, 220, 50)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Rotation = 90
	label.Parent = surfaceGui

	-- Hold grip at the bottom of the bat
	tool.GripPos = Vector3.new(0, -1.5, 0)
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
		local originalColor = handle.BrickColor
		handle.BrickColor = BrickColor.new("Bright yellow")
		task.delay(0.15, function()
			if handle and handle.Parent then
				handle.BrickColor = originalColor
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
