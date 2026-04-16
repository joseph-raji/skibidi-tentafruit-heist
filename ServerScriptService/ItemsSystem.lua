-- ItemsSystem.lua
-- ModuleScript: Items shop with weapons, traps, and gadgets for Skibidi Tentafruit Heist

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local remoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local evtNotification = remoteEvents:WaitForChild("Notification")

local ItemsSystem = {}

-- =========================================================================
-- Shared state (set via init)
-- =========================================================================

local _playerBases = {}
local _carrying    = {}

-- =========================================================================
-- Item catalogue
-- =========================================================================

local ITEMS = {
	{ id = "power_bat",      name = "Power Bat",        category = "weapon",   cost = 5000,  icon = "🏏", color = BrickColor.new("Bright orange"),       description = "2x range, stuns enemies 2s" },
	{ id = "rocket_bat",     name = "Rocket Bat",        category = "weapon",   cost = 25000, icon = "🚀", color = BrickColor.new("Bright red"),           description = "AOE blast — drops ALL carriers nearby" },
	{ id = "grappling_hook", name = "Grappling Hook",    category = "mobility", cost = 15000, icon = "🪝", color = BrickColor.new("Medium stone grey"),    description = "Shoot forward and zip to that point" },
	{ id = "speed_boots",    name = "Speed Boots",        category = "mobility", cost = 6000,  icon = "👟", color = BrickColor.new("Bright blue"),          description = "50% speed boost for 20 seconds (consumable)" },
	{ id = "invis_cap",      name = "Invisibility Cap",  category = "stealth",  cost = 10000, icon = "🪄", color = BrickColor.new("White"),                description = "Turn invisible for 10 seconds (consumable)" },
	{ id = "spike_trap",     name = "Spike Trap",         category = "trap",     cost = 3500,  icon = "⚡", color = BrickColor.new("Dark grey"),            description = "Slows any enemy who steps on it" },
	{ id = "alarm_trap",     name = "Alarm Trap",          category = "trap",     cost = 4500,  icon = "🔔", color = BrickColor.new("Bright yellow"),       description = "Notifies you when enemy enters your base" },
	{ id = "freeze_trap",    name = "Freeze Trap",         category = "trap",     cost = 9000,  icon = "❄️", color = BrickColor.new("Bright bluish green"),  description = "Anchors enemy in place for 3 seconds" },
	{ id = "bouncer_trap",   name = "Bouncer",             category = "trap",     cost = 12000, icon = "🌀", color = BrickColor.new("Hot pink"),             description = "Launches intruders out of your base" },
	{ id = "shield_bubble",  name = "Shield Bubble",       category = "defense",  cost = 8000,  icon = "🛡️", color = BrickColor.new("Cyan"),                description = "Absorbs one bat hit (consumable)" },
}

-- Fast lookup by id
local ITEM_BY_ID = {}
for _, item in ipairs(ITEMS) do
	ITEM_BY_ID[item.id] = item
end

-- =========================================================================
-- Category colors for display labels
-- =========================================================================

local CATEGORY_COLOR = {
	weapon   = Color3.fromRGB(220, 50,  50),
	mobility = Color3.fromRGB(80,  120, 255),
	stealth  = Color3.fromRGB(220, 220, 220),
	trap     = Color3.fromRGB(255, 160, 30),
	defense  = Color3.fromRGB(0,   200, 220),
}

-- =========================================================================
-- Module-level state
-- =========================================================================

-- cooldowns[player][itemId] = timestamp
local cooldowns  = {}

-- trapOwners[trapPart] = player
local trapOwners = {}

-- Per-player trap count by type: trapCount[player][id] = number
local trapCount  = {}

-- =========================================================================
-- Public: init
-- =========================================================================

function ItemsSystem.init(playerBases, carrying)
	_playerBases = playerBases
	_carrying    = carrying
end

-- =========================================================================
-- Internal: cooldown helpers
-- =========================================================================

local function hasCooldown(player, itemId, duration)
	if not cooldowns[player] then return false end
	local last = cooldowns[player][itemId]
	if not last then return false end
	return (tick() - last) < duration
end

local function setCooldown(player, itemId)
	if not cooldowns[player] then cooldowns[player] = {} end
	cooldowns[player][itemId] = tick()
end

-- =========================================================================
-- Internal: trap count helpers
-- =========================================================================

local function getTrapCount(player, trapId)
	if not trapCount[player] then return 0 end
	return trapCount[player][trapId] or 0
end

local function incrementTrapCount(player, trapId)
	if not trapCount[player] then trapCount[player] = {} end
	trapCount[player][trapId] = (trapCount[player][trapId] or 0) + 1
end

local function decrementTrapCount(player, trapId)
	if not trapCount[player] then return end
	local n = (trapCount[player][trapId] or 0) - 1
	trapCount[player][trapId] = math.max(0, n)
end

-- =========================================================================
-- Internal: flash a character a given color
-- =========================================================================

local function flashCharacter(character, color, duration)
	if not character then return end
	local originals = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			originals[part] = { color = part.Color, material = part.Material }
			part.Color    = color
			part.Material = Enum.Material.Neon
		end
	end
	task.delay(duration, function()
		for part, orig in pairs(originals) do
			if part and part.Parent then
				part.Color    = orig.color
				part.Material = orig.material
			end
		end
	end)
end

-- =========================================================================
-- Internal: apply stun (WalkSpeed = 0) then restore
-- =========================================================================

local function applyStun(target, duration)
	local char = target.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum.WalkSpeed = 0
	task.delay(duration, function()
		if hum and hum.Parent then
			hum.WalkSpeed = 16
		end
	end)
end

-- =========================================================================
-- Internal: get HumanoidRootPart position
-- =========================================================================

local function getRootPos(player)
	local char = player.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	return root.Position
end

-- =========================================================================
-- Tool factories
-- =========================================================================

-- ----- power_bat -----
local function makePowerBatTool()
	local tool = Instance.new("Tool")
	tool.Name            = "Power Bat"
	tool.ToolTip         = "2x portée, étourdit 2s"
	tool.RequiresHandle  = true
	tool.CanBeDropped    = false

	local handle = Instance.new("Part")
	handle.Name     = "Handle"
	handle.Size     = Vector3.new(1.2, 4, 1.2)
	handle.BrickColor = BrickColor.new("Bright orange")
	handle.Material = Enum.Material.SmoothPlastic
	handle.Parent   = tool

	tool.GripPos     = Vector3.new(0, -1.8, 0)
	tool.GripForward = Vector3.new(0, 0, 1)
	tool.GripRight   = Vector3.new(1, 0, 0)
	tool.GripUp      = Vector3.new(0, 1, 0)

	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0, 120, 0, 30)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.Parent      = handle
	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text                   = "POWER BAT"
	lbl.TextColor3             = Color3.fromRGB(255, 140, 0)
	lbl.TextStrokeTransparency = 0.3
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.GothamBold
	lbl.Parent                 = bb

	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player then return end
		if hasCooldown(player, "power_bat", 2) then return end
		setCooldown(player, "power_bat")

		-- Flash orange swing
		local orig = handle.Color
		handle.Color = Color3.fromRGB(255, 200, 0)
		task.delay(0.15, function()
			if handle and handle.Parent then handle.Color = orig end
		end)

		local attackerRoot = getRootPos(player)
		if not attackerRoot then return end

		for _, target in ipairs(Players:GetPlayers()) do
			if target == player then continue end
			local targetPos = getRootPos(target)
			if not targetPos then continue end
			if (attackerRoot - targetPos).Magnitude > 14 then continue end

			-- Drop skin if carrying
			if _carrying[target] then
				_carrying[target].Anchored = true
				_carrying[target] = nil
				target:SetAttribute("IsCarrying", false)
				target:SetAttribute("CarryingSkinName", "")
				evtNotification:FireClient(target, "Batte Puissante ! Tu as lâché le brainrot !", Color3.fromRGB(255, 100, 0))
				evtNotification:FireClient(player, "Coup puissant ! " .. target.Name .. " a lâché son brainrot !", Color3.fromRGB(100, 255, 100))
			end

			-- Stun 2s
			applyStun(target, 2)
			flashCharacter(target.Character, Color3.fromRGB(255, 140, 0), 0.4)
		end
	end)

	return tool
end

-- ----- rocket_bat -----
local function makeRocketBatTool()
	local tool = Instance.new("Tool")
	tool.Name           = "Rocket Bat"
	tool.ToolTip        = "Explosion AoE — fait lâcher TOUS les porteurs proches"
	tool.RequiresHandle = true
	tool.CanBeDropped   = false

	local handle = Instance.new("Part")
	handle.Name      = "Handle"
	handle.Shape     = Enum.PartType.Cylinder
	handle.Size      = Vector3.new(5, 1, 1)
	handle.BrickColor = BrickColor.new("Bright red")
	handle.Material  = Enum.Material.SmoothPlastic
	handle.Parent    = tool

	tool.GripPos     = Vector3.new(-2, 0, 0)
	tool.GripForward = Vector3.new(0, 0, 1)
	tool.GripRight   = Vector3.new(1, 0, 0)
	tool.GripUp      = Vector3.new(0, 1, 0)

	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player then return end
		if hasCooldown(player, "rocket_bat", 5) then
			evtNotification:FireClient(player, "Batte Roquette en recharge...", Color3.fromRGB(200, 100, 50))
			return
		end
		setCooldown(player, "rocket_bat")

		local attackerRoot = getRootPos(player)
		if not attackerRoot then return end

		-- Expanding neon sphere effect
		task.spawn(function()
			local sphere = Instance.new("Part")
			sphere.Shape       = Enum.PartType.Ball
			sphere.Anchored    = true
			sphere.CanCollide  = false
			sphere.Material    = Enum.Material.Neon
			sphere.Color       = Color3.fromRGB(255, 50, 0)
			sphere.Transparency = 0.3
			sphere.Size        = Vector3.new(1, 1, 1)
			sphere.CFrame      = CFrame.new(attackerRoot)
			sphere.Parent      = workspace

			for i = 1, 20 do
				task.wait(0.03)
				if sphere and sphere.Parent then
					local s = i
					sphere.Size        = Vector3.new(s, s, s)
					sphere.Transparency = 0.3 + (i / 20) * 0.7
				end
			end
			if sphere and sphere.Parent then sphere:Destroy() end
		end)

		-- AOE hit
		for _, target in ipairs(Players:GetPlayers()) do
			if target == player then continue end
			local targetPos = getRootPos(target)
			if not targetPos then continue end
			if (attackerRoot - targetPos).Magnitude > 20 then continue end

			if _carrying[target] then
				_carrying[target].Anchored = true
				_carrying[target] = nil
				target:SetAttribute("IsCarrying", false)
				target:SetAttribute("CarryingSkinName", "")
				evtNotification:FireClient(target, "Batte Roquette BOOM ! Lâché !", Color3.fromRGB(255, 50, 0))
			end

			applyStun(target, 3)
			flashCharacter(target.Character, Color3.fromRGB(255, 50, 0), 0.6)
		end

		evtNotification:FireClient(player, "BATTE ROQUETTE — BOOM !", Color3.fromRGB(255, 150, 0))
	end)

	return tool
end

-- ----- grappling_hook -----
local function makeGrapplingHookTool()
	local tool = Instance.new("Tool")
	tool.Name           = "Grappling Hook"
	tool.ToolTip        = "Propulse vers une surface"
	tool.RequiresHandle = true
	tool.CanBeDropped   = false

	local handle = Instance.new("Part")
	handle.Name      = "Handle"
	handle.Size      = Vector3.new(0.8, 3, 0.8)
	handle.BrickColor = BrickColor.new("Medium stone grey")
	handle.Material  = Enum.Material.SmoothPlastic
	handle.Parent    = tool

	tool.GripPos     = Vector3.new(0, -1.2, 0)
	tool.GripForward = Vector3.new(0, 0, 1)
	tool.GripRight   = Vector3.new(1, 0, 0)
	tool.GripUp      = Vector3.new(0, 1, 0)

	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player then return end
		if hasCooldown(player, "grappling_hook", 4) then
			evtNotification:FireClient(player, "Grappin en refroidissement...", Color3.fromRGB(150, 150, 150))
			return
		end

		local char = player.Character
		if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Raycast 60 studs forward from player look direction
		local lookDir = root.CFrame.LookVector
		local origin  = root.Position + Vector3.new(0, 1, 0)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { char }
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local result = workspace:Raycast(origin, lookDir * 60, raycastParams)
		if not result then
			evtNotification:FireClient(player, "Rien à accrocher !", Color3.fromRGB(180, 180, 180))
			return
		end

		setCooldown(player, "grappling_hook")

		local hitPoint = result.Position

		-- Visible rope
		task.spawn(function()
			local rope = Instance.new("Part")
			rope.Name       = "GrappleRope"
			rope.Anchored   = true
			rope.CanCollide = false
			rope.Material   = Enum.Material.Neon
			rope.BrickColor = BrickColor.new("Medium stone grey")

			local mid    = (origin + hitPoint) / 2
			local length = (hitPoint - origin).Magnitude
			rope.Size    = Vector3.new(0.15, 0.15, length)
			rope.CFrame  = CFrame.lookAt(mid, hitPoint)
			rope.Parent  = workspace

			task.delay(0.5, function()
				if rope and rope.Parent then rope:Destroy() end
			end)
		end)

		-- Zip toward hit point using LinearVelocity
		task.spawn(function()
			local attachment = Instance.new("Attachment")
			attachment.Parent = root

			local lv = Instance.new("LinearVelocity")
			lv.Attachment0 = attachment
			lv.VectorVelocity = Vector3.zero
			lv.MaxForce = 100000
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.Parent = root

			local elapsed   = 0
			local maxTime   = 1.5
			local connection
			connection = RunService.Heartbeat:Connect(function(dt)
				elapsed = elapsed + dt
				if not root or not root.Parent then
					connection:Disconnect()
					lv:Destroy()
					attachment:Destroy()
					return
				end
				local dist = (hitPoint - root.Position).Magnitude
				if dist <= 4 or elapsed >= maxTime then
					connection:Disconnect()
					lv:Destroy()
					attachment:Destroy()
					return
				end
				-- Recalculate direction each frame so we curve toward target
				lv.VectorVelocity = (hitPoint - root.Position).Unit * 80
			end)
		end)
	end)

	return tool
end

-- ----- speed_boots (consumable) -----
local function makeSpeedBootsTool()
	local tool = Instance.new("Tool")
	tool.Name           = "Speed Boots"
	tool.ToolTip        = "+50% vitesse pendant 20s"
	tool.RequiresHandle = true
	tool.CanBeDropped   = false

	local handle = Instance.new("Part")
	handle.Name      = "Handle"
	handle.Size      = Vector3.new(1.5, 1, 2)
	handle.BrickColor = BrickColor.new("Bright blue")
	handle.Material  = Enum.Material.SmoothPlastic
	handle.Parent    = tool

	local used = false

	tool.Activated:Connect(function()
		if used then return end
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player then return end
		used = true

		local char = player.Character
		if not char then tool:Destroy(); return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then tool:Destroy(); return end

		hum.WalkSpeed = 28
		evtNotification:FireClient(player, "⚡ Boost de vitesse actif pendant 20s !", Color3.fromRGB(80, 120, 255))

		task.delay(20, function()
			if hum and hum.Parent then
				hum.WalkSpeed = 16
			end
			if tool and tool.Parent then
				tool:Destroy()
			end
		end)
	end)

	return tool
end

-- ----- invis_cap (consumable) -----
local function makeInvisCapTool()
	local tool = Instance.new("Tool")
	tool.Name           = "Invisibility Cap"
	tool.ToolTip        = "Invisible pendant 10s"
	tool.RequiresHandle = true
	tool.CanBeDropped   = false

	local handle = Instance.new("Part")
	handle.Name      = "Handle"
	handle.Size      = Vector3.new(2, 0.8, 2)
	handle.BrickColor = BrickColor.new("White")
	handle.Material  = Enum.Material.SmoothPlastic
	handle.Parent    = tool

	local used = false

	tool.Activated:Connect(function()
		if used then return end
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player then return end
		used = true

		local char = player.Character
		if not char then tool:Destroy(); return end

		-- Store original transparencies
		local originals = {}
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				originals[part] = part.Transparency
				if part.Name ~= "HumanoidRootPart" then
					part.Transparency = 0.95
				end
			end
		end

		local hum = char:FindFirstChildOfClass("Humanoid")
		local origNameDist = hum and hum.NameDisplayDistance or 100
		if hum then hum.NameDisplayDistance = 0 end

		evtNotification:FireClient(player, "🪄 Invisible pendant 10s ! Va voler !", Color3.fromRGB(200, 200, 255))

		task.delay(10, function()
			-- Restore transparencies
			for part, orig in pairs(originals) do
				if part and part.Parent then
					part.Transparency = orig
				end
			end
			if hum and hum.Parent then
				hum.NameDisplayDistance = origNameDist
			end
			if tool and tool.Parent then
				tool:Destroy()
			end
		end)
	end)

	return tool
end

-- ----- spike_trap -----
local function makeSpikeTrapTool()
	local tool = Instance.new("Tool")
	tool.Name           = "Spike Trap"
	tool.ToolTip        = "Ralentit les ennemis qui marchent dessus"
	tool.RequiresHandle = true
	tool.CanBeDropped   = false

	local handle = Instance.new("Part")
	handle.Name      = "Handle"
	handle.Size      = Vector3.new(1.5, 0.5, 1.5)
	handle.BrickColor = BrickColor.new("Dark grey")
	handle.Material  = Enum.Material.Neon
	handle.Parent    = tool

	local MAX_TRAPS   = 3
	local slowDebounce = {}

	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player then return end

		if getTrapCount(player, "spike_trap") >= MAX_TRAPS then
			evtNotification:FireClient(player, "Maximum de pièges à pics posés (3) !", Color3.fromRGB(255, 80, 80))
			return
		end

		local pos = getRootPos(player)
		if not pos then return end

		local trapPart = Instance.new("Part")
		trapPart.Name      = "SpikeTrap"
		trapPart.Anchored  = true
		trapPart.Size      = Vector3.new(4, 0.3, 4)
		trapPart.BrickColor = BrickColor.new("Dark grey")
		trapPart.Material  = Enum.Material.Neon
		trapPart.CFrame    = CFrame.new(pos.X, pos.Y - 2.5, pos.Z)
		trapPart.Parent    = workspace

		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range      = 8
		light.Color      = Color3.fromRGB(80, 80, 80)
		light.Parent     = trapPart

		trapOwners[trapPart] = player
		incrementTrapCount(player, "spike_trap")

		trapPart.Touched:Connect(function(hit)
			local victimChar = hit.Parent
			local victim = Players:GetPlayerFromCharacter(victimChar)
			if not victim then return end
			if victim == trapOwners[trapPart] then return end
			if slowDebounce[victim] then return end

			slowDebounce[victim] = true
			local hum = victimChar:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = 8
				evtNotification:FireClient(victim, "Piège à pics ! Ralenti !", Color3.fromRGB(150, 150, 150))
				task.delay(3, function()
					if hum and hum.Parent then hum.WalkSpeed = 16 end
					slowDebounce[victim] = nil
				end)
			else
				slowDebounce[victim] = nil
			end
		end)

		-- Remove trap after 60s
		task.delay(60, function()
			if trapPart and trapPart.Parent then
				trapOwners[trapPart] = nil
				decrementTrapCount(player, "spike_trap")
				trapPart:Destroy()
			end
		end)

		evtNotification:FireClient(player, "Piège à pics posé !", Color3.fromRGB(200, 200, 200))
	end)

	return tool
end

-- ----- alarm_trap -----
local function makeAlarmTrapTool()
	local tool = Instance.new("Tool")
	tool.Name           = "Alarm Trap"
	tool.ToolTip        = "Alerte quand un ennemi entre dans ta base"
	tool.RequiresHandle = true
	tool.CanBeDropped   = false

	local handle = Instance.new("Part")
	handle.Name      = "Handle"
	handle.Size      = Vector3.new(1, 1, 1)
	handle.BrickColor = BrickColor.new("Bright yellow")
	handle.Material  = Enum.Material.SmoothPlastic
	handle.Parent    = tool

	local MAX_TRAPS    = 2
	local alarmDebounce = {}

	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player then return end

		if getTrapCount(player, "alarm_trap") >= MAX_TRAPS then
			evtNotification:FireClient(player, "Maximum de pièges alarme posés (2) !", Color3.fromRGB(255, 80, 80))
			return
		end

		local pos = getRootPos(player)
		if not pos then return end

		local trapPart = Instance.new("Part")
		trapPart.Name     = "AlarmTrap"
		trapPart.Shape    = Enum.PartType.Ball
		trapPart.Anchored = true
		trapPart.Size     = Vector3.new(2, 2, 2)
		trapPart.BrickColor = BrickColor.new("Bright yellow")
		trapPart.Material = Enum.Material.Neon
		trapPart.CFrame   = CFrame.new(pos.X, pos.Y - 2, pos.Z)
		trapPart.Parent   = workspace

		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range      = 10
		light.Color      = Color3.fromRGB(255, 220, 0)
		light.Parent     = trapPart

		-- Pulsing yellow light
		task.spawn(function()
			while trapPart and trapPart.Parent do
				light.Brightness = 2
				task.wait(0.5)
				if trapPart and trapPart.Parent then
					light.Brightness = 0.5
				end
				task.wait(0.5)
			end
		end)

		trapOwners[trapPart] = player
		incrementTrapCount(player, "alarm_trap")

		trapPart.Touched:Connect(function(hit)
			local victimChar = hit.Parent
			local victim = Players:GetPlayerFromCharacter(victimChar)
			if not victim then return end
			local owner = trapOwners[trapPart]
			if not owner then return end
			if victim == owner then return end

			local key = tostring(trapPart) .. tostring(victim)
			if alarmDebounce[key] then return end
			alarmDebounce[key] = true
			task.delay(4, function() alarmDebounce[key] = nil end)

			evtNotification:FireClient(owner, "🔔 " .. victim.Name .. " est dans ta base !", Color3.fromRGB(255, 220, 0))
		end)

		-- Remove after 120s
		task.delay(120, function()
			if trapPart and trapPart.Parent then
				trapOwners[trapPart] = nil
				decrementTrapCount(player, "alarm_trap")
				trapPart:Destroy()
			end
		end)

		evtNotification:FireClient(player, "Piège alarme posé !", Color3.fromRGB(255, 220, 0))
	end)

	return tool
end

-- ----- freeze_trap -----
local function makeFreezeTrapTool()
	local tool = Instance.new("Tool")
	tool.Name           = "Freeze Trap"
	tool.ToolTip        = "Immobilise les ennemis pendant 3 secondes"
	tool.RequiresHandle = true
	tool.CanBeDropped   = false

	local handle = Instance.new("Part")
	handle.Name      = "Handle"
	handle.Size      = Vector3.new(1.5, 0.5, 1.5)
	handle.BrickColor = BrickColor.new("Bright bluish green")
	handle.Material  = Enum.Material.Neon
	handle.Parent    = tool

	local MAX_TRAPS    = 2
	local freezeDebounce = {}

	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player then return end

		if getTrapCount(player, "freeze_trap") >= MAX_TRAPS then
			evtNotification:FireClient(player, "Maximum de pièges glaciaux posés (2) !", Color3.fromRGB(255, 80, 80))
			return
		end

		local pos = getRootPos(player)
		if not pos then return end

		local trapPart = Instance.new("Part")
		trapPart.Name      = "FreezeTrap"
		trapPart.Anchored  = true
		trapPart.Size      = Vector3.new(4, 0.3, 4)
		trapPart.BrickColor = BrickColor.new("Bright bluish green")
		trapPart.Material  = Enum.Material.Neon
		trapPart.CFrame    = CFrame.new(pos.X, pos.Y - 2.5, pos.Z)
		trapPart.Parent    = workspace

		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range      = 10
		light.Color      = Color3.fromRGB(0, 200, 220)
		light.Parent     = trapPart

		trapOwners[trapPart] = player
		incrementTrapCount(player, "freeze_trap")

		trapPart.Touched:Connect(function(hit)
			local victimChar = hit.Parent
			local victim = Players:GetPlayerFromCharacter(victimChar)
			if not victim then return end
			if victim == trapOwners[trapPart] then return end
			if freezeDebounce[victim] then return end

			freezeDebounce[victim] = true
			local hum = victimChar:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = 0
				evtNotification:FireClient(victim, "Gelé ! 3 secondes...", Color3.fromRGB(0, 200, 220))
				flashCharacter(victimChar, Color3.fromRGB(100, 220, 255), 3)
				task.delay(3, function()
					if hum and hum.Parent then hum.WalkSpeed = 16 end
					freezeDebounce[victim] = nil
				end)
			else
				freezeDebounce[victim] = nil
			end
		end)

		-- Remove after 90s
		task.delay(90, function()
			if trapPart and trapPart.Parent then
				trapOwners[trapPart] = nil
				decrementTrapCount(player, "freeze_trap")
				trapPart:Destroy()
			end
		end)

		evtNotification:FireClient(player, "Piège glacial posé !", Color3.fromRGB(0, 200, 220))
	end)

	return tool
end

-- ----- bouncer_trap -----
local function makeBouncerTrapTool()
	local tool = Instance.new("Tool")
	tool.Name           = "Bouncer"
	tool.ToolTip        = "Éjecte les intrus hors de ta base"
	tool.RequiresHandle = true
	tool.CanBeDropped   = false

	local handle = Instance.new("Part")
	handle.Name      = "Handle"
	handle.Size      = Vector3.new(2, 0.5, 2)
	handle.BrickColor = BrickColor.new("Hot pink")
	handle.Material  = Enum.Material.Neon
	handle.Parent    = tool

	local MAX_TRAPS      = 2
	local bounceDebounce = {}

	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player then return end

		if getTrapCount(player, "bouncer_trap") >= MAX_TRAPS then
			evtNotification:FireClient(player, "Maximum d'éjecteurs posés (2) !", Color3.fromRGB(255, 80, 80))
			return
		end

		local pos = getRootPos(player)
		if not pos then return end

		local trapPart = Instance.new("Part")
		trapPart.Name      = "BouncerTrap"
		trapPart.Anchored  = true
		trapPart.Size      = Vector3.new(5, 0.3, 5)
		trapPart.BrickColor = BrickColor.new("Hot pink")
		trapPart.Material  = Enum.Material.Neon
		trapPart.CFrame    = CFrame.new(pos.X, pos.Y - 2.5, pos.Z)
		trapPart.Parent    = workspace

		local light = Instance.new("PointLight")
		light.Brightness = 3
		light.Range      = 14
		light.Color      = Color3.fromRGB(255, 0, 128)
		light.Parent     = trapPart

		-- Hot pink spinning animation
		task.spawn(function()
			local angle = 0
			while trapPart and trapPart.Parent do
				angle = angle + 0.05
				trapPart.CFrame = CFrame.new(trapPart.Position) * CFrame.Angles(0, angle, 0)
				task.wait()
			end
		end)

		trapOwners[trapPart] = player
		incrementTrapCount(player, "bouncer_trap")

		trapPart.Touched:Connect(function(hit)
			local victimChar = hit.Parent
			local victim = Players:GetPlayerFromCharacter(victimChar)
			if not victim then return end
			if victim == trapOwners[trapPart] then return end
			if bounceDebounce[victim] then return end

			local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")
			if not victimRoot then return end

			bounceDebounce[victim] = true
			task.delay(3, function() bounceDebounce[victim] = nil end)

			-- Direction away from trap center + strong upward boost
			local awayDir = (victimRoot.Position - trapPart.Position)
			awayDir = Vector3.new(awayDir.X, 0, awayDir.Z)
			if awayDir.Magnitude < 0.1 then awayDir = Vector3.new(1, 0, 0) end
			awayDir = awayDir.Unit

			local launchVelocity = awayDir * 60 + Vector3.new(0, 80, 0)

			local attachment = Instance.new("Attachment")
			attachment.Parent = victimRoot

			local lv = Instance.new("LinearVelocity")
			lv.Attachment0    = attachment
			lv.VectorVelocity = launchVelocity
			lv.MaxForce       = 100000
			lv.RelativeTo     = Enum.ActuatorRelativeTo.World
			lv.Parent         = victimRoot

			task.delay(0.25, function()
				if lv and lv.Parent then lv:Destroy() end
				if attachment and attachment.Parent then attachment:Destroy() end
			end)

			evtNotification:FireClient(victim, "Éjecté hors de la base !", Color3.fromRGB(255, 0, 128))
		end)

		-- Remove after 90s
		task.delay(90, function()
			if trapPart and trapPart.Parent then
				trapOwners[trapPart] = nil
				decrementTrapCount(player, "bouncer_trap")
				trapPart:Destroy()
			end
		end)

		evtNotification:FireClient(player, "Éjecteur posé !", Color3.fromRGB(255, 0, 128))
	end)

	return tool
end

-- ----- shield_bubble (consumable) -----
local function makeShieldBubbleTool()
	local tool = Instance.new("Tool")
	tool.Name           = "Shield Bubble"
	tool.ToolTip        = "Absorbe un coup de batte"
	tool.RequiresHandle = true
	tool.CanBeDropped   = false

	local handle = Instance.new("Part")
	handle.Name      = "Handle"
	handle.Shape     = Enum.PartType.Ball
	handle.Size      = Vector3.new(1.5, 1.5, 1.5)
	handle.BrickColor = BrickColor.new("Cyan")
	handle.Material  = Enum.Material.Neon
	handle.Transparency = 0.3
	handle.Parent    = tool

	local used = false

	tool.Activated:Connect(function()
		if used then return end
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player then return end
		used = true

		local char = player.Character
		if not char then tool:Destroy(); return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then tool:Destroy(); return end

		-- Create shield sphere welded to HumanoidRootPart
		local bubble = Instance.new("Part")
		bubble.Name        = "ShieldBubble"
		bubble.Shape       = Enum.PartType.Ball
		bubble.Anchored    = false
		bubble.CanCollide  = false
		bubble.Size        = Vector3.new(8, 8, 8)
		bubble.BrickColor  = BrickColor.new("Cyan")
		bubble.Material    = Enum.Material.Neon
		bubble.Transparency = 0.6
		bubble.CFrame      = root.CFrame
		bubble.Parent      = workspace

		local weld = Instance.new("WeldConstraint")
		weld.Part0  = root
		weld.Part1  = bubble
		weld.Parent = root

		player:SetAttribute("HasShield", true)
		evtNotification:FireClient(player, "🛡️ Bouclier actif !", Color3.fromRGB(0, 200, 220))

		-- Auto-expire after 30s
		task.delay(30, function()
			if player:GetAttribute("HasShield") then
				ItemsSystem.consumeShield(player, bubble)
				if tool and tool.Parent then tool:Destroy() end
			end
		end)

		-- Store bubble reference on the tool so consumeShield can find it
		tool:SetAttribute("BubbleId", bubble:GetDebugId())
		tool.AncestryChanged:Connect(function()
			-- Clean up if tool removed without being used
			if not tool.Parent then
				if bubble and bubble.Parent then bubble:Destroy() end
			end
		end)
	end)

	return tool
end

-- =========================================================================
-- Tool factory dispatch
-- =========================================================================

local TOOL_FACTORIES = {
	power_bat      = makePowerBatTool,
	rocket_bat     = makeRocketBatTool,
	grappling_hook = makeGrapplingHookTool,
	speed_boots    = makeSpeedBootsTool,
	invis_cap      = makeInvisCapTool,
	spike_trap     = makeSpikeTrapTool,
	alarm_trap     = makeAlarmTrapTool,
	freeze_trap    = makeFreezeTrapTool,
	bouncer_trap   = makeBouncerTrapTool,
	shield_bubble  = makeShieldBubbleTool,
}

-- =========================================================================
-- Public: buyItem
-- =========================================================================

function ItemsSystem.buyItem(player, itemId)
	local itemData = ITEM_BY_ID[itemId]
	if not itemData then
		warn("ItemsSystem.buyItem: unknown itemId", itemId)
		return false
	end

	local money = player:GetAttribute("Money") or 0
	if money < itemData.cost then
		evtNotification:FireClient(player, "Pas assez d'argent ! Il te faut $" .. itemData.cost, Color3.fromRGB(255, 80, 80))
		return false
	end

	local factory = TOOL_FACTORIES[itemId]
	if not factory then
		warn("ItemsSystem.buyItem: no factory for", itemId)
		return false
	end

	-- Deduct cost
	player:SetAttribute("Money", money - itemData.cost)

	-- Build and give tool
	local tool = factory()
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		tool.Parent = backpack
	else
		-- Fallback: parent directly to character so the player gets it
		local char = player.Character
		if char then
			tool.Parent = char
		end
	end

	evtNotification:FireClient(
		player,
		"Acheté " .. itemData.icon .. " " .. itemData.name .. " !",
		Color3.fromRGB(100, 255, 100)
	)
	return true
end

-- =========================================================================
-- Public: dropSkin helper (clears _carrying reference)
-- =========================================================================

function ItemsSystem.dropSkin(player)
	if _carrying[player] then
		_carrying[player].Anchored = true
		_carrying[player] = nil
		player:SetAttribute("IsCarrying", false)
		player:SetAttribute("CarryingSkinName", "")
	end
end

-- =========================================================================
-- Public: shield helpers
-- =========================================================================

function ItemsSystem.checkShield(player)
	return player:GetAttribute("HasShield") == true
end

function ItemsSystem.consumeShield(player, bubblePart)
	player:SetAttribute("HasShield", false)
	-- If a specific bubble part was passed, destroy it
	if bubblePart and bubblePart.Parent then
		bubblePart:Destroy()
		return
	end
	-- Otherwise search the character for the bubble
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	for _, obj in ipairs(root:GetChildren()) do
		if obj:IsA("WeldConstraint") and obj.Part1 and obj.Part1.Name == "ShieldBubble" then
			obj.Part1:Destroy()
			obj:Destroy()
			return
		end
	end
	-- Also check workspace
	local found = workspace:FindFirstChild("ShieldBubble", true)
	if found and found.Parent then
		found:Destroy()
	end
end

-- =========================================================================
-- Internal: create a floating section sign above a group of pedestals
-- =========================================================================

local function makeSectionSign(text, color, posX, posY, posZ)
	local signPart = Instance.new("Part")
	signPart.Name        = "ShopSectionSign_" .. text
	signPart.Anchored    = true
	signPart.CanCollide  = false
	signPart.Size        = Vector3.new(18, 3, 0.2)
	signPart.CFrame      = CFrame.new(posX, posY, posZ)
	signPart.BrickColor  = BrickColor.new("Really black")
	signPart.Material    = Enum.Material.SmoothPlastic
	signPart.Transparency = 0.2
	signPart.Parent      = workspace

	local sg = Instance.new("SurfaceGui")
	sg.Face   = Enum.NormalId.Front
	sg.Parent = signPart

	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text                   = text
	lbl.TextColor3             = color
	lbl.TextStrokeTransparency = 0.2
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.GothamBold
	lbl.Parent                 = sg

	local light = Instance.new("PointLight")
	light.Brightness = 1
	light.Range      = 12
	light.Color      = color
	light.Parent     = signPart
end

-- =========================================================================
-- Public: createItemsShop
-- =========================================================================

function ItemsSystem.createItemsShop()
	local SHOP_Z     = -60
	local FLOOR_Y    = 0.5
	local STAND_HEIGHT  = 2.5
	local PEDESTAL_SIZE = Vector3.new(3, STAND_HEIGHT, 3)

	-- -----------------------------------------------------------------------
	-- Floor
	-- -----------------------------------------------------------------------
	local floor = Instance.new("Part")
	floor.Name      = "ItemsShopFloor"
	floor.Anchored  = true
	floor.Size      = Vector3.new(80, 1, 30)
	floor.Position  = Vector3.new(0, FLOOR_Y, SHOP_Z)
	floor.BrickColor = BrickColor.new("Dark stone grey")
	floor.Material  = Enum.Material.SmoothPlastic
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.Parent    = workspace

	-- Floor border light strip
	local strip = Instance.new("Part")
	strip.Name      = "ItemsShopStrip"
	strip.Anchored  = true
	strip.CanCollide = false
	strip.Size      = Vector3.new(80, 0.1, 30)
	strip.Position  = Vector3.new(0, FLOOR_Y + 0.55, SHOP_Z)
	strip.BrickColor = BrickColor.new("Bright red")
	strip.Material  = Enum.Material.Neon
	strip.Transparency = 0.6
	strip.Parent    = workspace

	-- Shop sign
	local signPost = Instance.new("Part")
	signPost.Anchored   = true
	signPost.CanCollide = false
	signPost.Size       = Vector3.new(0.3, 8, 0.3)
	signPost.Position   = Vector3.new(-38, FLOOR_Y + 4, SHOP_Z)
	signPost.BrickColor = BrickColor.new("Dark orange")
	signPost.Material   = Enum.Material.SmoothPlastic
	signPost.Parent     = workspace

	local signBoard = Instance.new("Part")
	signBoard.Anchored   = true
	signBoard.CanCollide = false
	signBoard.Size       = Vector3.new(16, 5, 0.3)
	signBoard.Position   = Vector3.new(-30, FLOOR_Y + 9, SHOP_Z)
	signBoard.BrickColor = BrickColor.new("Really black")
	signBoard.Material   = Enum.Material.SmoothPlastic
	signBoard.Parent     = workspace

	local signGui = Instance.new("SurfaceGui")
	signGui.Face   = Enum.NormalId.Front
	signGui.Parent = signBoard
	local signLabel = Instance.new("TextLabel")
	signLabel.Size                   = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text                   = "⚔️ ITEMS SHOP\nWeapons · Traps · Gadgets"
	signLabel.TextScaled             = true
	signLabel.Font                   = Enum.Font.GothamBold
	signLabel.TextColor3             = Color3.fromRGB(255, 220, 50)
	signLabel.Parent                 = signGui

	-- -----------------------------------------------------------------------
	-- Category grouping: define which items belong to which section and their
	-- layout. Sections are placed left-to-right along the shop floor.
	--
	-- Layout:
	--   WEAPONS  (2 items) — leftmost group,  columns centered around X = -28
	--   MOBILITY (3 items) — next group,       columns centered around X = -7
	--   TRAPS    (4 items) — next group,       columns centered around X = 14
	--   DEFENSE  (1 item)  — rightmost group,  centered at X = 28
	--
	-- Each pedestal sits at SHOP_Z (single row — shop is narrower this way).
	-- -----------------------------------------------------------------------

	local SECTIONS = {
		{
			label    = "⚔️ WEAPONS",
			color    = CATEGORY_COLOR.weapon,
			centerX  = -28,
			posZ     = SHOP_Z,
			items    = { "power_bat", "rocket_bat" },
		},
		{
			label    = "🏃 MOBILITY",
			color    = CATEGORY_COLOR.mobility,
			centerX  = -7,
			posZ     = SHOP_Z,
			items    = { "grappling_hook", "speed_boots", "invis_cap" },
		},
		{
			label    = "🪤 TRAPS",
			color    = CATEGORY_COLOR.trap,
			centerX  = 14,
			posZ     = SHOP_Z,
			items    = { "spike_trap", "alarm_trap", "freeze_trap", "bouncer_trap" },
		},
		{
			label    = "🛡️ DEFENSE",
			color    = CATEGORY_COLOR.defense,
			centerX  = 28,
			posZ     = SHOP_Z,
			items    = { "shield_bubble" },
		},
	}

	local COL_SPACING = 8  -- tighter spacing within a section

	for _, section in ipairs(SECTIONS) do
		local itemCount  = #section.items
		-- Spread columns symmetrically around centerX
		local totalWidth = (itemCount - 1) * COL_SPACING
		local startX     = section.centerX - totalWidth / 2

		-- Section sign floating above the group
		local signY = FLOOR_Y + STAND_HEIGHT + 5
		makeSectionSign(section.label, section.color, section.centerX, signY, section.posZ - 1)

		for i, itemId in ipairs(section.items) do
			local item  = ITEM_BY_ID[itemId]
			local posX  = startX + (i - 1) * COL_SPACING
			local posZ  = section.posZ
			local baseY = FLOOR_Y + STAND_HEIGHT / 2

			-- Pedestal
			local pedestal = Instance.new("Part")
			pedestal.Name      = "ItemStand_" .. item.id
			pedestal.Anchored  = true
			pedestal.Size      = PEDESTAL_SIZE
			pedestal.Position  = Vector3.new(posX, baseY, posZ)
			pedestal.BrickColor = BrickColor.new("Dark stone grey")
			pedestal.Material  = Enum.Material.SmoothPlastic
			pedestal.TopSurface = Enum.SurfaceType.Smooth
			pedestal.Parent    = workspace

			-- Colored top cap (category color)
			local cap = Instance.new("Part")
			cap.Name      = "ItemStandCap_" .. item.id
			cap.Anchored  = true
			cap.CanCollide = false
			cap.Size      = Vector3.new(3.2, 0.3, 3.2)
			cap.Position  = Vector3.new(posX, FLOOR_Y + STAND_HEIGHT + 0.15, posZ)
			cap.Color     = CATEGORY_COLOR[item.category] or Color3.fromRGB(200, 200, 200)
			cap.Material  = Enum.Material.Neon
			cap.Transparency = 0.2
			cap.Parent    = workspace

			-- Point light on cap
			local pedLight = Instance.new("PointLight")
			pedLight.Brightness = 1.5
			pedLight.Range      = 8
			pedLight.Color      = CATEGORY_COLOR[item.category] or Color3.fromRGB(200, 200, 200)
			pedLight.Parent     = cap

			-- Icon part (small sphere on top)
			local iconPart = Instance.new("Part")
			iconPart.Name        = "ItemIcon_" .. item.id
			iconPart.Anchored    = true
			iconPart.CanCollide  = false
			iconPart.Shape       = Enum.PartType.Ball
			iconPart.Size        = Vector3.new(1.5, 1.5, 1.5)
			iconPart.Position    = Vector3.new(posX, FLOOR_Y + STAND_HEIGHT + 1.2, posZ)
			iconPart.BrickColor  = item.color
			iconPart.Material    = Enum.Material.Neon
			iconPart.Parent      = workspace

			-- Billboard above the stand
			local bb = Instance.new("BillboardGui")
			bb.Size        = UDim2.new(0, 180, 0, 110)
			bb.StudsOffset = Vector3.new(0, 5, 0)
			bb.AlwaysOnTop = false
			bb.Parent      = pedestal

			-- Icon + Name row
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size                   = UDim2.new(1, 0, 0.30, 0)
			nameLabel.Position               = UDim2.new(0, 0, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text                   = item.icon .. " " .. item.name
			nameLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
			nameLabel.TextStrokeTransparency = 0.3
			nameLabel.TextScaled             = true
			nameLabel.Font                   = Enum.Font.GothamBold
			nameLabel.Parent                 = bb

			-- Category label
			local catLabel = Instance.new("TextLabel")
			catLabel.Size                   = UDim2.new(1, 0, 0.20, 0)
			catLabel.Position               = UDim2.new(0, 0, 0.30, 0)
			catLabel.BackgroundTransparency = 1
			catLabel.Text                   = "[" .. item.category:upper() .. "]"
			catLabel.TextColor3             = CATEGORY_COLOR[item.category] or Color3.fromRGB(200, 200, 200)
			catLabel.TextStrokeTransparency = 0.4
			catLabel.TextScaled             = true
			catLabel.Font                   = Enum.Font.Gotham
			catLabel.Parent                 = bb

			-- Cost label
			local costLabel = Instance.new("TextLabel")
			costLabel.Size                   = UDim2.new(1, 0, 0.22, 0)
			costLabel.Position               = UDim2.new(0, 0, 0.50, 0)
			costLabel.BackgroundTransparency = 1
			costLabel.Text                   = "$" .. item.cost
			costLabel.TextColor3             = Color3.fromRGB(100, 255, 100)
			costLabel.TextStrokeTransparency = 0.4
			costLabel.TextScaled             = true
			costLabel.Font                   = Enum.Font.GothamBold
			costLabel.Parent                 = bb

			-- Description label
			local descLabel = Instance.new("TextLabel")
			descLabel.Size                   = UDim2.new(1, 0, 0.18, 0)
			descLabel.Position               = UDim2.new(0, 0, 0.82, 0)
			descLabel.BackgroundTransparency = 1
			descLabel.Text                   = item.description
			descLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
			descLabel.TextStrokeTransparency = 0.5
			descLabel.TextScaled             = true
			descLabel.Font                   = Enum.Font.Gotham
			descLabel.Parent                 = bb

			-- ProximityPrompt on the icon sphere — replaces Touched buy logic
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText            = item.name
			prompt.ActionText            = "Buy — $" .. item.cost
			prompt.MaxActivationDistance = 8
			prompt.HoldDuration          = 0.5
			prompt.Parent                = iconPart

			local capturedId = item.id  -- capture for closure
			prompt.Triggered:Connect(function(buyingPlayer)
				ItemsSystem.buyItem(buyingPlayer, capturedId)
			end)
		end
	end
end

-- =========================================================================
-- Cleanup when player leaves
-- =========================================================================

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player]   = nil
	trapCount[player]   = nil
	-- Clean up any traps owned by this player
	for trapPart, owner in pairs(trapOwners) do
		if owner == player then
			trapOwners[trapPart] = nil
			if trapPart and trapPart.Parent then
				trapPart:Destroy()
			end
		end
	end
end)

return ItemsSystem
