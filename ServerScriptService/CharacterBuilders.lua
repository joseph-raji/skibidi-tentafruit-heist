-- CharacterBuilders.lua
-- ModuleScript: Builds humanoid fruit characters for each brainrot ID.
-- Each builder returns the torso Part (body) which becomes the primary part.

local CharacterBuilders = {}

-- ============================================================
-- Shared helpers
-- ============================================================

local function weld(partA, partB)
	local w = Instance.new("WeldConstraint")
	w.Part0 = partA
	w.Part1 = partB
	w.Parent = partA
end

-- Adds white eyeball spheres + black pupil balls facing +Z onto headCenter
local function addEyes(torso, headCenter, headSize, model)
	local eyeSize   = headSize * 0.28
	local pupilSize = eyeSize  * 0.45
	local eyeOffsetY = headSize * 0.08
	local eyeOffsetZ = headSize * 0.42
	local eyeOffsetX = headSize * 0.22

	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name       = "Eye_" .. (side == -1 and "L" or "R")
		eye.Shape      = Enum.PartType.Ball
		eye.Material   = Enum.Material.SmoothPlastic
		eye.BrickColor = BrickColor.new("White")
		eye.Size       = Vector3.new(eyeSize, eyeSize, eyeSize)
		eye.CFrame     = CFrame.new(headCenter + Vector3.new(side * eyeOffsetX, eyeOffsetY, eyeOffsetZ))
		eye.Anchored   = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent     = model
		weld(torso, eye)

		local pupil = Instance.new("Part")
		pupil.Name       = "Pupil_" .. (side == -1 and "L" or "R")
		pupil.Shape      = Enum.PartType.Ball
		pupil.Material   = Enum.Material.SmoothPlastic
		pupil.BrickColor = BrickColor.new("Really black")
		pupil.Size       = Vector3.new(pupilSize, pupilSize, pupilSize)
		pupil.CFrame     = CFrame.new(headCenter + Vector3.new(side * eyeOffsetX, eyeOffsetY, eyeOffsetZ + eyeSize * 0.35))
		pupil.Anchored   = false
		pupil.CanCollide = false
		pupil.CastShadow = false
		pupil.Parent     = model
		weld(torso, pupil)
	end
end

-- Builds a standard block torso + cylinder arms + cylinder legs.
-- Returns the torso Part (which is also set as model.PrimaryPart).
local function buildBase(position, model, s, torsoColor, legColor)
	-- Torso
	local torso = Instance.new("Part")
	torso.Name       = "Body"
	torso.Shape      = Enum.PartType.Block
	torso.Material   = Enum.Material.SmoothPlastic
	torso.BrickColor = torsoColor or BrickColor.new("Medium stone grey")
	torso.Size       = Vector3.new(s * 0.72, s * 0.9, s * 0.45)
	torso.CFrame     = CFrame.new(position)
	torso.Anchored   = true
	torso.CanCollide = true
	torso.CastShadow = true
	torso.Parent     = model
	model.PrimaryPart = torso

	-- Arms
	local armLength = s * 0.75
	local armThick  = s * 0.18
	for _, side in ipairs({ -1, 1 }) do
		local arm = Instance.new("Part")
		arm.Name       = "Arm_" .. (side == -1 and "L" or "R")
		arm.Shape      = Enum.PartType.Cylinder
		arm.Material   = Enum.Material.SmoothPlastic
		arm.BrickColor = torsoColor or BrickColor.new("Medium stone grey")
		arm.Size       = Vector3.new(armLength, armThick, armThick)
		arm.CFrame     = CFrame.new(
			position + Vector3.new(side * (s * 0.36 + armLength * 0.5), s * 0.22, 0)
		) * CFrame.Angles(0, 0, math.rad(side * 25))
		arm.Anchored   = false
		arm.CanCollide = false
		arm.CastShadow = false
		arm.Parent     = model
		weld(torso, arm)
	end

	-- Legs
	local legLength = s * 0.55
	local legThick  = s * 0.2
	local legOffsetX = s * 0.16
	for _, side in ipairs({ -1, 1 }) do
		local leg = Instance.new("Part")
		leg.Name       = "Leg_" .. (side == -1 and "L" or "R")
		leg.Shape      = Enum.PartType.Cylinder
		leg.Material   = Enum.Material.SmoothPlastic
		leg.BrickColor = legColor or torsoColor or BrickColor.new("Medium stone grey")
		leg.Size       = Vector3.new(legThick, legLength, legThick)
		leg.CFrame     = CFrame.new(
			position + Vector3.new(side * legOffsetX, -(s * 0.45 + legLength * 0.5), 0)
		)
		leg.Anchored   = false
		leg.CanCollide = false
		leg.CastShadow = false
		leg.Parent     = model
		weld(torso, leg)
	end

	return torso
end

-- ============================================================
-- Builder registry
-- ============================================================
local builders = {}

-- ============================================================
-- COMMON (size ≈ 3)
-- ============================================================

-- fraise_jr: red sphere head, white seed balls, 3-leaf green fan on top
builders["fraise_jr"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Bright red"), BrickColor.new("Dark red"))
	local headCenter = position + Vector3.new(0, s * 0.75, 0)
	local headSize = s * 0.7

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Bright red")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.CastShadow = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- White seed dots
	for i = 1, 4 do
		local angle = (i - 1) * math.pi / 2
		local seed = Instance.new("Part")
		seed.Name       = "Seed_" .. i
		seed.Shape      = Enum.PartType.Ball
		seed.Material   = Enum.Material.SmoothPlastic
		seed.BrickColor = BrickColor.new("White")
		seed.Size       = Vector3.new(s * 0.08, s * 0.08, s * 0.08)
		seed.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * 0.35,
			math.sin(angle) * headSize * 0.2 + headSize * 0.05,
			headSize * 0.44
		))
		seed.Anchored   = false
		seed.CanCollide = false
		seed.Parent     = model
		weld(torso, seed)
	end

	-- 3 green leaf blocks fanned on top
	for i = 1, 3 do
		local a = math.rad(-30 + (i - 1) * 30)
		local leaf = Instance.new("Part")
		leaf.Name       = "Leaf_" .. i
		leaf.Shape      = Enum.PartType.Block
		leaf.Material   = Enum.Material.SmoothPlastic
		leaf.BrickColor = BrickColor.new("Bright green")
		leaf.Size       = Vector3.new(s * 0.1, s * 0.4, s * 0.08)
		leaf.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.5 + s * 0.18, 0))
			* CFrame.Angles(0, 0, a)
		leaf.Anchored   = false
		leaf.CanCollide = false
		leaf.Parent     = model
		weld(torso, leaf)
	end

	return torso
end

-- banane_bro: elongated yellow cylinder head tilted 30°, brown tip balls, shine stripe
builders["banane_bro"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Bright yellow"), BrickColor.new("Dark yellow"))
	local headCenter = position + Vector3.new(0, s * 0.76, 0)
	local headSize = s * 0.65

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Cylinder
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Bright yellow")
	head.Size       = Vector3.new(headSize * 1.6, headSize * 0.7, headSize * 0.7)
	head.CFrame     = CFrame.new(headCenter) * CFrame.Angles(0, 0, math.rad(30))
	head.Anchored   = false
	head.CanCollide = false
	head.CastShadow = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize * 0.7, model)

	-- Brown tip balls at each end
	for _, side in ipairs({ -1, 1 }) do
		local tip = Instance.new("Part")
		tip.Name       = "Tip_" .. side
		tip.Shape      = Enum.PartType.Ball
		tip.Material   = Enum.Material.SmoothPlastic
		tip.BrickColor = BrickColor.new("Brown")
		tip.Size       = Vector3.new(s * 0.14, s * 0.14, s * 0.14)
		tip.CFrame     = CFrame.new(headCenter + Vector3.new(side * headSize * 0.72, side * headSize * 0.42, 0))
		tip.Anchored   = false
		tip.CanCollide = false
		tip.Parent     = model
		weld(torso, tip)
	end

	-- Yellow shine stripe
	local shine = Instance.new("Part")
	shine.Name       = "Shine"
	shine.Shape      = Enum.PartType.Block
	shine.Material   = Enum.Material.Neon
	shine.BrickColor = BrickColor.new("Bright yellow")
	shine.Transparency = 0.6
	shine.Size       = Vector3.new(headSize * 1.1, s * 0.04, s * 0.04)
	shine.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.2, headSize * 0.36))
		* CFrame.Angles(0, 0, math.rad(30))
	shine.Anchored   = false
	shine.CanCollide = false
	shine.Parent     = model
	weld(torso, shine)

	return torso
end

-- orange_girl: orange sphere head, green stem, 5 radial peel stripes
builders["orange_girl"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Neon orange"), BrickColor.new("Dark orange"))
	local headCenter = position + Vector3.new(0, s * 0.75, 0)
	local headSize = s * 0.68

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Neon orange")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.CastShadow = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- Green stem
	local stem = Instance.new("Part")
	stem.Name       = "Stem"
	stem.Shape      = Enum.PartType.Cylinder
	stem.Material   = Enum.Material.SmoothPlastic
	stem.BrickColor = BrickColor.new("Bright green")
	stem.Size       = Vector3.new(s * 0.1, s * 0.35, s * 0.1)
	stem.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.55, 0))
	stem.Anchored   = false
	stem.CanCollide = false
	stem.Parent     = model
	weld(torso, stem)

	-- 5 radial peel stripe blocks
	for i = 1, 5 do
		local angle = math.rad((i - 1) * 72)
		local stripe = Instance.new("Part")
		stripe.Name       = "Stripe_" .. i
		stripe.Shape      = Enum.PartType.Block
		stripe.Material   = Enum.Material.SmoothPlastic
		stripe.BrickColor = BrickColor.new("Neon orange")
		stripe.Transparency = 0.4
		stripe.Size       = Vector3.new(s * 0.06, headSize * 0.9, s * 0.06)
		stripe.CFrame     = CFrame.new(headCenter)
			* CFrame.Angles(0, angle, math.rad(60))
			* CFrame.new(0, headSize * 0.38, 0)
		stripe.Anchored   = false
		stripe.CanCollide = false
		stripe.Parent     = model
		weld(torso, stripe)
	end

	return torso
end

-- raisin_guy: small dark indigo squished sphere head, wrinkle bumps, droopy brows, slouched
builders["raisin_guy"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Dark indigo"), BrickColor.new("Dark indigo"))
	local headCenter = position + Vector3.new(0, s * 0.72, 0)
	local headSize = s * 0.6

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Dark indigo")
	head.Size       = Vector3.new(headSize * 1.05, headSize * 0.82, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.CastShadow = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize * 0.82, model)

	-- Wrinkle bumps
	for i = 1, 5 do
		local bump = Instance.new("Part")
		bump.Name       = "Wrinkle_" .. i
		bump.Shape      = Enum.PartType.Ball
		bump.Material   = Enum.Material.SmoothPlastic
		bump.BrickColor = BrickColor.new("Dark indigo")
		bump.Size       = Vector3.new(s * 0.09, s * 0.06, s * 0.06)
		bump.CFrame     = CFrame.new(headCenter + Vector3.new(
			(i - 3) * headSize * 0.18,
			headSize * (0.1 + math.abs(i - 3) * 0.06),
			headSize * 0.46
		))
		bump.Anchored   = false
		bump.CanCollide = false
		bump.Parent     = model
		weld(torso, bump)
	end

	-- Droopy brow bars
	for _, side in ipairs({ -1, 1 }) do
		local brow = Instance.new("Part")
		brow.Name       = "Brow_" .. side
		brow.Shape      = Enum.PartType.Block
		brow.Material   = Enum.Material.SmoothPlastic
		brow.BrickColor = BrickColor.new("Dark indigo")
		brow.Size       = Vector3.new(headSize * 0.32, s * 0.06, s * 0.04)
		brow.CFrame     = CFrame.new(headCenter + Vector3.new(side * headSize * 0.2, headSize * 0.18, headSize * 0.46))
			* CFrame.Angles(0, 0, math.rad(side * -12))
		brow.Anchored   = false
		brow.CanCollide = false
		brow.Parent     = model
		weld(torso, brow)
	end

	return torso
end

-- tomate_basic: squished red sphere head, green stem, 5-leaf star crown, belly button
builders["tomate_basic"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Bright red"), BrickColor.new("Bright red"))
	local headCenter = position + Vector3.new(0, s * 0.74, 0)
	local headSize = s * 0.68

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Bright red")
	head.Size       = Vector3.new(headSize * 1.05, headSize * 0.88, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.CastShadow = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize * 0.88, model)

	-- Green stem
	local stem = Instance.new("Part")
	stem.Name       = "Stem"
	stem.Shape      = Enum.PartType.Cylinder
	stem.Material   = Enum.Material.SmoothPlastic
	stem.BrickColor = BrickColor.new("Bright green")
	stem.Size       = Vector3.new(s * 0.1, s * 0.28, s * 0.1)
	stem.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.52, 0))
	stem.Anchored   = false
	stem.CanCollide = false
	stem.Parent     = model
	weld(torso, stem)

	-- 5-leaf star crown
	for i = 1, 5 do
		local angle = math.rad((i - 1) * 72)
		local leaf = Instance.new("Part")
		leaf.Name       = "Leaf_" .. i
		leaf.Shape      = Enum.PartType.Block
		leaf.Material   = Enum.Material.SmoothPlastic
		leaf.BrickColor = BrickColor.new("Bright green")
		leaf.Size       = Vector3.new(s * 0.08, s * 0.28, s * 0.07)
		leaf.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.48, 0))
			* CFrame.Angles(0, angle, math.rad(50))
			* CFrame.new(0, s * 0.16, 0)
		leaf.Anchored   = false
		leaf.CanCollide = false
		leaf.Parent     = model
		weld(torso, leaf)
	end

	-- Belly button dimple
	local dimple = Instance.new("Part")
	dimple.Name       = "BellyButton"
	dimple.Shape      = Enum.PartType.Ball
	dimple.Material   = Enum.Material.SmoothPlastic
	dimple.BrickColor = BrickColor.new("Dark red")
	dimple.Size       = Vector3.new(s * 0.09, s * 0.09, s * 0.06)
	dimple.CFrame     = CFrame.new(position + Vector3.new(0, s * 0.1, s * 0.24))
	dimple.Anchored   = false
	dimple.CanCollide = false
	dimple.Parent     = model
	weld(torso, dimple)

	return torso
end

-- ============================================================
-- UNCOMMON (size ≈ 3.5)
-- ============================================================

-- mangue_queen: tall oval mango head, gold Neon crown with spikes, hot pink gem
builders["mangue_queen"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Neon orange"), BrickColor.new("Dark orange"))
	local headCenter = position + Vector3.new(0, s * 0.76, 0)
	local headSize = s * 0.7

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Neon orange")
	head.Size       = Vector3.new(headSize * 0.9, headSize * 1.25, headSize * 0.9)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- Gold crown band
	local band = Instance.new("Part")
	band.Name       = "CrownBand"
	band.Shape      = Enum.PartType.Cylinder
	band.Material   = Enum.Material.Neon
	band.BrickColor = BrickColor.new("Bright yellow")
	band.Size       = Vector3.new(s * 0.08, headSize * 1.06, headSize * 1.06)
	band.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.6, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	band.Anchored   = false
	band.CanCollide = false
	band.Parent     = model
	weld(torso, band)

	-- Crown spikes
	for i = 1, 5 do
		local angle = math.rad((i - 1) * 72)
		local spike = Instance.new("Part")
		spike.Name       = "Spike_" .. i
		spike.Shape      = Enum.PartType.Cylinder
		spike.Material   = Enum.Material.Neon
		spike.BrickColor = BrickColor.new("Bright yellow")
		spike.Size       = Vector3.new(s * 0.08, s * 0.38, s * 0.08)
		spike.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * 0.42,
			headSize * 0.72,
			math.sin(angle) * headSize * 0.42
		)) * CFrame.Angles(0, 0, math.rad(90) - angle)
		spike.Anchored   = false
		spike.CanCollide = false
		spike.Parent     = model
		weld(torso, spike)
	end

	-- Hot pink gem
	local gem = Instance.new("Part")
	gem.Name       = "Gem"
	gem.Shape      = Enum.PartType.Ball
	gem.Material   = Enum.Material.Neon
	gem.BrickColor = BrickColor.new("Hot pink")
	gem.Size       = Vector3.new(s * 0.15, s * 0.15, s * 0.15)
	gem.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.62, 0))
	gem.Anchored   = false
	gem.CanCollide = false
	gem.Parent     = model
	weld(torso, gem)

	return torso
end

-- ananas_king: yellow sphere head, 7 green spike cylinders at varied angles, dark brow band
builders["ananas_king"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Bright yellow"), BrickColor.new("Brown"))
	local headCenter = position + Vector3.new(0, s * 0.76, 0)
	local headSize = s * 0.7

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Bright yellow")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- 7 green spike cylinders at varied angles
	local spikeAngles = {0, 26, -26, 52, -52, 78, -78}
	for i, a in ipairs(spikeAngles) do
		local spike = Instance.new("Part")
		spike.Name       = "Spike_" .. i
		spike.Shape      = Enum.PartType.Cylinder
		spike.Material   = Enum.Material.SmoothPlastic
		spike.BrickColor = BrickColor.new("Bright green")
		spike.Size       = Vector3.new(s * 0.1, s * 0.5 - math.abs(a) * 0.002 * s, s * 0.1)
		spike.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.44 + s * 0.22, 0))
			* CFrame.Angles(0, 0, math.rad(a))
		spike.Anchored   = false
		spike.CanCollide = false
		spike.Parent     = model
		weld(torso, spike)
	end

	-- Dark brow band
	local brow = Instance.new("Part")
	brow.Name       = "BrowBand"
	brow.Shape      = Enum.PartType.Block
	brow.Material   = Enum.Material.SmoothPlastic
	brow.BrickColor = BrickColor.new("Really black")
	brow.Size       = Vector3.new(headSize * 0.9, s * 0.08, s * 0.05)
	brow.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.18, headSize * 0.47))
	brow.Anchored   = false
	brow.CanCollide = false
	brow.Parent     = model
	weld(torso, brow)

	return torso
end

-- cerise_duo: two red sphere heads side by side, green stem cylinders
builders["cerise_duo"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Bright red"), BrickColor.new("Dark red"))
	local headSize = s * 0.52

	for i, side in ipairs({ -1, 1 }) do
		local headCenter = position + Vector3.new(side * headSize * 0.65, s * 0.74, 0)

		local head = Instance.new("Part")
		head.Name       = "Head_" .. i
		head.Shape      = Enum.PartType.Ball
		head.Material   = Enum.Material.SmoothPlastic
		head.BrickColor = BrickColor.new("Bright red")
		head.Size       = Vector3.new(headSize, headSize, headSize)
		head.CFrame     = CFrame.new(headCenter)
		head.Anchored   = false
		head.CanCollide = false
		head.Parent     = model
		weld(torso, head)

		addEyes(torso, headCenter, headSize, model)

		-- Green stem
		local stem = Instance.new("Part")
		stem.Name       = "Stem_" .. i
		stem.Shape      = Enum.PartType.Cylinder
		stem.Material   = Enum.Material.SmoothPlastic
		stem.BrickColor = BrickColor.new("Bright green")
		stem.Size       = Vector3.new(s * 0.07, s * 0.32, s * 0.07)
		stem.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.54, 0))
			* CFrame.Angles(0, 0, math.rad(side * 18))
		stem.Anchored   = false
		stem.CanCollide = false
		stem.Parent     = model
		weld(torso, stem)
	end

	return torso
end

-- pasteque_bro: green outer sphere + red inner sphere forward-offset, 5 black seed balls
builders["pasteque_bro"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Bright green"), BrickColor.new("Dark green"))
	local headCenter = position + Vector3.new(0, s * 0.76, 0)
	local headSize = s * 0.7

	-- Green outer head
	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Bright green")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	-- Red inner (face) sphere slightly forward
	local inner = Instance.new("Part")
	inner.Name       = "InnerFace"
	inner.Shape      = Enum.PartType.Ball
	inner.Material   = Enum.Material.SmoothPlastic
	inner.BrickColor = BrickColor.new("Bright red")
	inner.Size       = Vector3.new(headSize * 0.86, headSize * 0.86, headSize * 0.86)
	inner.CFrame     = CFrame.new(headCenter + Vector3.new(0, 0, headSize * 0.08))
	inner.Anchored   = false
	inner.CanCollide = false
	inner.Parent     = model
	weld(torso, inner)

	addEyes(torso, headCenter, headSize * 0.86, model)

	-- 5 black seed balls
	for i = 1, 5 do
		local angle = math.rad((i - 1) * 72 + 36)
		local seed = Instance.new("Part")
		seed.Name       = "Seed_" .. i
		seed.Shape      = Enum.PartType.Ball
		seed.Material   = Enum.Material.SmoothPlastic
		seed.BrickColor = BrickColor.new("Really black")
		seed.Size       = Vector3.new(s * 0.09, s * 0.09, s * 0.09)
		seed.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * 0.28,
			math.sin(angle) * headSize * 0.22 + headSize * 0.05,
			headSize * 0.43
		))
		seed.Anchored   = false
		seed.CanCollide = false
		seed.Parent     = model
		weld(torso, seed)
	end

	return torso
end

-- citron_vert: lime green sphere head, yellow Neon dot, angled brows, 3-piece hair tuft
builders["citron_vert"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Lime green"), BrickColor.new("Dark green"))
	local headCenter = position + Vector3.new(0, s * 0.76, 0)
	local headSize = s * 0.68

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Lime green")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- Yellow Neon highlight dot
	local dot = Instance.new("Part")
	dot.Name       = "Highlight"
	dot.Shape      = Enum.PartType.Ball
	dot.Material   = Enum.Material.Neon
	dot.BrickColor = BrickColor.new("Bright yellow")
	dot.Size       = Vector3.new(s * 0.13, s * 0.13, s * 0.13)
	dot.CFrame     = CFrame.new(headCenter + Vector3.new(headSize * 0.28, headSize * 0.28, headSize * 0.38))
	dot.Anchored   = false
	dot.CanCollide = false
	dot.Parent     = model
	weld(torso, dot)

	-- Angled brows
	for _, side in ipairs({ -1, 1 }) do
		local brow = Instance.new("Part")
		brow.Name       = "Brow_" .. side
		brow.Shape      = Enum.PartType.Block
		brow.Material   = Enum.Material.SmoothPlastic
		brow.BrickColor = BrickColor.new("Dark green")
		brow.Size       = Vector3.new(headSize * 0.28, s * 0.06, s * 0.04)
		brow.CFrame     = CFrame.new(headCenter + Vector3.new(side * headSize * 0.2, headSize * 0.18, headSize * 0.47))
			* CFrame.Angles(0, 0, math.rad(side * 15))
		brow.Anchored   = false
		brow.CanCollide = false
		brow.Parent     = model
		weld(torso, brow)
	end

	-- 3-piece hair tuft
	for i = 1, 3 do
		local a = math.rad(-20 + (i - 1) * 20)
		local tuft = Instance.new("Part")
		tuft.Name       = "Tuft_" .. i
		tuft.Shape      = Enum.PartType.Cylinder
		tuft.Material   = Enum.Material.SmoothPlastic
		tuft.BrickColor = BrickColor.new("Lime green")
		tuft.Size       = Vector3.new(s * 0.1, s * 0.32, s * 0.1)
		tuft.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.52, 0))
			* CFrame.Angles(0, 0, a)
		tuft.Anchored   = false
		tuft.CanCollide = false
		tuft.Parent     = model
		weld(torso, tuft)
	end

	return torso
end

-- ============================================================
-- RARE (size ≈ 4)
-- ============================================================

-- avocat_elite: dark green oval head, bright green face patch, tan seed bump, black sunglasses
builders["avocat_elite"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Dark green"), BrickColor.new("Dark green"))
	local headCenter = position + Vector3.new(0, s * 0.77, 0)
	local headSize = s * 0.72

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Dark green")
	head.Size       = Vector3.new(headSize * 0.88, headSize * 1.18, headSize * 0.88)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	-- Bright green face patch
	local patch = Instance.new("Part")
	patch.Name       = "FacePatch"
	patch.Shape      = Enum.PartType.Ball
	patch.Material   = Enum.Material.SmoothPlastic
	patch.BrickColor = BrickColor.new("Lime green")
	patch.Size       = Vector3.new(headSize * 0.62, headSize * 0.78, headSize * 0.62)
	patch.CFrame     = CFrame.new(headCenter + Vector3.new(0, -headSize * 0.06, headSize * 0.1))
	patch.Anchored   = false
	patch.CanCollide = false
	patch.Parent     = model
	weld(torso, patch)

	addEyes(torso, headCenter, headSize * 0.78, model)

	-- Tan seed bump
	local seed = Instance.new("Part")
	seed.Name       = "Seed"
	seed.Shape      = Enum.PartType.Ball
	seed.Material   = Enum.Material.SmoothPlastic
	seed.BrickColor = BrickColor.new("Tan")
	seed.Size       = Vector3.new(headSize * 0.3, headSize * 0.38, headSize * 0.3)
	seed.CFrame     = CFrame.new(headCenter + Vector3.new(0, -headSize * 0.08, headSize * 0.32))
	seed.Anchored   = false
	seed.CanCollide = false
	seed.Parent     = model
	weld(torso, seed)

	-- Black sunglasses (2 lens blocks + bridge block)
	for _, side in ipairs({ -1, 1 }) do
		local lens = Instance.new("Part")
		lens.Name       = "Lens_" .. side
		lens.Shape      = Enum.PartType.Block
		lens.Material   = Enum.Material.SmoothPlastic
		lens.BrickColor = BrickColor.new("Really black")
		lens.Size       = Vector3.new(headSize * 0.28, headSize * 0.14, s * 0.04)
		lens.CFrame     = CFrame.new(headCenter + Vector3.new(side * headSize * 0.22, headSize * 0.14, headSize * 0.47))
		lens.Anchored   = false
		lens.CanCollide = false
		lens.Parent     = model
		weld(torso, lens)
	end
	local bridge = Instance.new("Part")
	bridge.Name       = "Bridge"
	bridge.Shape      = Enum.PartType.Block
	bridge.Material   = Enum.Material.SmoothPlastic
	bridge.BrickColor = BrickColor.new("Really black")
	bridge.Size       = Vector3.new(headSize * 0.1, s * 0.04, s * 0.04)
	bridge.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.14, headSize * 0.47))
	bridge.Anchored   = false
	bridge.CanCollide = false
	bridge.Parent     = model
	weld(torso, bridge)

	return torso
end

-- dragon_fruit: hot pink sphere + large transparent Neon aura, 8 white spike protrusions
builders["dragon_fruit"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Hot pink"), BrickColor.new("Hot pink"))
	local headCenter = position + Vector3.new(0, s * 0.77, 0)
	local headSize = s * 0.72

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Hot pink")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	-- Large transparent Neon aura
	local aura = Instance.new("Part")
	aura.Name         = "Aura"
	aura.Shape        = Enum.PartType.Ball
	aura.Material     = Enum.Material.Neon
	aura.BrickColor   = BrickColor.new("Hot pink")
	aura.Transparency = 0.72
	aura.Size         = Vector3.new(headSize * 1.6, headSize * 1.6, headSize * 1.6)
	aura.CFrame       = CFrame.new(headCenter)
	aura.Anchored     = false
	aura.CanCollide   = false
	aura.Parent       = model
	weld(torso, aura)

	addEyes(torso, headCenter, headSize, model)

	-- 8 white cylinder spike protrusions oriented radially around head equator
	for i = 1, 8 do
		local angle = math.rad((i - 1) * 45)
		local spike = Instance.new("Part")
		spike.Name       = "Spike_" .. i
		spike.Shape      = Enum.PartType.Cylinder
		spike.Material   = Enum.Material.SmoothPlastic
		spike.BrickColor = BrickColor.new("White")
		spike.Size       = Vector3.new(s * 0.38, s * 0.1, s * 0.1)
		spike.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * 0.52,
			math.sin(angle) * headSize * 0.2 + headSize * 0.08,
			math.sin(angle) * headSize * 0.52
		)) * CFrame.Angles(0, angle, math.rad(90))
		spike.Anchored   = false
		spike.CanCollide = false
		spike.Parent     = model
		weld(torso, spike)
	end

	return torso
end

-- kiwi_shadow: brown shell sphere, green flesh disc, lime core, ninja headband
builders["kiwi_shadow"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Brown"), BrickColor.new("Dark grey"))
	local headCenter = position + Vector3.new(0, s * 0.77, 0)
	local headSize = s * 0.72

	-- Brown outer shell
	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Brown")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	-- Green flesh disc (front face)
	local flesh = Instance.new("Part")
	flesh.Name       = "FleshDisc"
	flesh.Shape      = Enum.PartType.Cylinder
	flesh.Material   = Enum.Material.SmoothPlastic
	flesh.BrickColor = BrickColor.new("Bright green")
	flesh.Size       = Vector3.new(s * 0.06, headSize * 0.9, headSize * 0.9)
	flesh.CFrame     = CFrame.new(headCenter + Vector3.new(0, 0, headSize * 0.35))
		* CFrame.Angles(0, 0, math.rad(90))
	flesh.Anchored   = false
	flesh.CanCollide = false
	flesh.Parent     = model
	weld(torso, flesh)

	-- Lime core
	local core = Instance.new("Part")
	core.Name       = "Core"
	core.Shape      = Enum.PartType.Ball
	core.Material   = Enum.Material.Neon
	core.BrickColor = BrickColor.new("Lime green")
	core.Size       = Vector3.new(headSize * 0.28, headSize * 0.28, headSize * 0.28)
	core.CFrame     = CFrame.new(headCenter + Vector3.new(0, 0, headSize * 0.4))
	core.Anchored   = false
	core.CanCollide = false
	core.Parent     = model
	weld(torso, core)

	addEyes(torso, headCenter, headSize * 0.9, model)

	-- Black ninja headband cylinder
	local band = Instance.new("Part")
	band.Name       = "Headband"
	band.Shape      = Enum.PartType.Cylinder
	band.Material   = Enum.Material.SmoothPlastic
	band.BrickColor = BrickColor.new("Really black")
	band.Size       = Vector3.new(s * 0.1, headSize * 1.02, headSize * 1.02)
	band.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.06, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	band.Anchored   = false
	band.CanCollide = false
	band.Parent     = model
	weld(torso, band)

	-- Grey metal plate on headband
	local plate = Instance.new("Part")
	plate.Name       = "Plate"
	plate.Shape      = Enum.PartType.Block
	plate.Material   = Enum.Material.SmoothPlastic
	plate.BrickColor = BrickColor.new("Mid gray")
	plate.Size       = Vector3.new(s * 0.06, headSize * 0.36, headSize * 0.22)
	plate.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.06, headSize * 0.52))
	plate.Anchored   = false
	plate.CanCollide = false
	plate.Parent     = model
	weld(torso, plate)

	return torso
end

-- figue_mystique: tall purple teardrop head, wizard hat, white beard, 4 Neon orbiting orbs
builders["figue_mystique"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Dark indigo"), BrickColor.new("Dark indigo"))
	local headCenter = position + Vector3.new(0, s * 0.77, 0)
	local headSize = s * 0.72

	-- Tall purple teardrop (taller Y)
	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Dark indigo")
	head.Size       = Vector3.new(headSize * 0.85, headSize * 1.35, headSize * 0.85)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- 3-part wizard hat (brim + 2 cone segments)
	local brim = Instance.new("Part")
	brim.Name       = "HatBrim"
	brim.Shape      = Enum.PartType.Cylinder
	brim.Material   = Enum.Material.SmoothPlastic
	brim.BrickColor = BrickColor.new("Dark indigo")
	brim.Size       = Vector3.new(s * 0.1, headSize * 1.2, headSize * 1.2)
	brim.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.72, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	brim.Anchored   = false
	brim.CanCollide = false
	brim.Parent     = model
	weld(torso, brim)

	local hatMid = Instance.new("Part")
	hatMid.Name       = "HatMid"
	hatMid.Shape      = Enum.PartType.Ball
	hatMid.Material   = Enum.Material.SmoothPlastic
	hatMid.BrickColor = BrickColor.new("Dark indigo")
	hatMid.Size       = Vector3.new(headSize * 0.7, headSize * 0.7, headSize * 0.7)
	hatMid.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.92, 0))
	hatMid.Anchored   = false
	hatMid.CanCollide = false
	hatMid.Parent     = model
	weld(torso, hatMid)

	local hatTip = Instance.new("Part")
	hatTip.Name       = "HatTip"
	hatTip.Shape      = Enum.PartType.Ball
	hatTip.Material   = Enum.Material.SmoothPlastic
	hatTip.BrickColor = BrickColor.new("Dark indigo")
	hatTip.Size       = Vector3.new(headSize * 0.3, headSize * 0.5, headSize * 0.3)
	hatTip.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 1.28, 0))
	hatTip.Anchored   = false
	hatTip.CanCollide = false
	hatTip.Parent     = model
	weld(torso, hatTip)

	-- White beard block
	local beard = Instance.new("Part")
	beard.Name       = "Beard"
	beard.Shape      = Enum.PartType.Block
	beard.Material   = Enum.Material.SmoothPlastic
	beard.BrickColor = BrickColor.new("White")
	beard.Size       = Vector3.new(headSize * 0.52, headSize * 0.5, s * 0.1)
	beard.CFrame     = CFrame.new(headCenter + Vector3.new(0, -headSize * 0.38, headSize * 0.42))
	beard.Anchored   = false
	beard.CanCollide = false
	beard.Parent     = model
	weld(torso, beard)

	-- 4 Neon orbiting orbs
	for i = 1, 4 do
		local angle = math.rad((i - 1) * 90)
		local orb = Instance.new("Part")
		orb.Name       = "Orb_" .. i
		orb.Shape      = Enum.PartType.Ball
		orb.Material   = Enum.Material.Neon
		orb.BrickColor = BrickColor.new("Bright violet")
		orb.Size       = Vector3.new(s * 0.18, s * 0.18, s * 0.18)
		orb.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * 0.82,
			-headSize * 0.15,
			math.sin(angle) * headSize * 0.82
		))
		orb.Anchored   = false
		orb.CanCollide = false
		orb.Parent     = model
		weld(torso, orb)
	end

	return torso
end

-- papaye_pro: tall orange oval head, 3 black seeds, shoulder armor pads, tribal torso stripes
builders["papaye_pro"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Neon orange"), BrickColor.new("Dark orange"))
	local headCenter = position + Vector3.new(0, s * 0.77, 0)
	local headSize = s * 0.72

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Neon orange")
	head.Size       = Vector3.new(headSize * 0.88, headSize * 1.22, headSize * 0.88)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- 3 black seed balls
	for i = 1, 3 do
		local seed = Instance.new("Part")
		seed.Name       = "Seed_" .. i
		seed.Shape      = Enum.PartType.Ball
		seed.Material   = Enum.Material.SmoothPlastic
		seed.BrickColor = BrickColor.new("Really black")
		seed.Size       = Vector3.new(s * 0.1, s * 0.1, s * 0.1)
		seed.CFrame     = CFrame.new(headCenter + Vector3.new(
			(i - 2) * headSize * 0.22,
			(i == 2 and 0 or -headSize * 0.12),
			headSize * 0.45
		))
		seed.Anchored   = false
		seed.CanCollide = false
		seed.Parent     = model
		weld(torso, seed)
	end

	-- Shoulder armor pads
	for _, side in ipairs({ -1, 1 }) do
		local pad = Instance.new("Part")
		pad.Name       = "Pad_" .. side
		pad.Shape      = Enum.PartType.Block
		pad.Material   = Enum.Material.SmoothPlastic
		pad.BrickColor = BrickColor.new("Dark orange")
		pad.Size       = Vector3.new(s * 0.28, s * 0.18, s * 0.22)
		pad.CFrame     = CFrame.new(position + Vector3.new(side * s * 0.5, s * 0.28, 0))
		pad.Anchored   = false
		pad.CanCollide = false
		pad.Parent     = model
		weld(torso, pad)

		local spike = Instance.new("Part")
		spike.Name       = "PadSpike_" .. side
		spike.Shape      = Enum.PartType.Cylinder
		spike.Material   = Enum.Material.SmoothPlastic
		spike.BrickColor = BrickColor.new("Really black")
		spike.Size       = Vector3.new(s * 0.06, s * 0.22, s * 0.06)
		spike.CFrame     = CFrame.new(position + Vector3.new(side * s * 0.5, s * 0.42, 0))
		spike.Anchored   = false
		spike.CanCollide = false
		spike.Parent     = model
		weld(torso, spike)
	end

	-- 3 tribal torso stripes
	for i = 1, 3 do
		local stripe = Instance.new("Part")
		stripe.Name       = "Stripe_" .. i
		stripe.Shape      = Enum.PartType.Block
		stripe.Material   = Enum.Material.Neon
		stripe.BrickColor = BrickColor.new("Bright orange")
		stripe.Size       = Vector3.new(s * 0.52, s * 0.06, s * 0.05)
		stripe.CFrame     = CFrame.new(position + Vector3.new(0, s * (0.02 + (i - 1) * 0.18), s * 0.24))
		stripe.Anchored   = false
		stripe.CanCollide = false
		stripe.Parent     = model
		weld(torso, stripe)
	end

	return torso
end

-- ============================================================
-- EPIC (size ≈ 4.5)
-- ============================================================

-- fraise_supreme: red sphere head, diamond gems, Neon gold crown, angel wings
builders["fraise_supreme"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Bright red"), BrickColor.new("Dark red"))
	local headCenter = position + Vector3.new(0, s * 0.78, 0)
	local headSize = s * 0.74

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Bright red")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- 8 diamond gem balls (Glass material)
	for i = 1, 8 do
		local angle = math.rad((i - 1) * 45)
		local gem = Instance.new("Part")
		gem.Name       = "Gem_" .. i
		gem.Shape      = Enum.PartType.Ball
		gem.Material   = Enum.Material.Glass
		gem.BrickColor = BrickColor.new("Hot pink")
		gem.Size       = Vector3.new(s * 0.1, s * 0.1, s * 0.1)
		gem.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * 0.44,
			math.sin(angle) * headSize * 0.18,
			headSize * 0.4
		))
		gem.Anchored   = false
		gem.CanCollide = false
		gem.Parent     = model
		weld(torso, gem)
	end

	-- Neon gold crown band
	local crown = Instance.new("Part")
	crown.Name       = "Crown"
	crown.Shape      = Enum.PartType.Cylinder
	crown.Material   = Enum.Material.Neon
	crown.BrickColor = BrickColor.new("Bright yellow")
	crown.Size       = Vector3.new(s * 0.1, headSize * 1.08, headSize * 1.08)
	crown.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.56, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	crown.Anchored   = false
	crown.CanCollide = false
	crown.Parent     = model
	weld(torso, crown)

	-- 5 crown spikes
	for i = 1, 5 do
		local angle = math.rad((i - 1) * 72)
		local spike = Instance.new("Part")
		spike.Name       = "CrownSpike_" .. i
		spike.Shape      = Enum.PartType.Cylinder
		spike.Material   = Enum.Material.Neon
		spike.BrickColor = BrickColor.new("Bright yellow")
		spike.Size       = Vector3.new(s * 0.1, s * 0.44, s * 0.1)
		spike.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * 0.44,
			headSize * 0.68,
			math.sin(angle) * headSize * 0.44
		))
		spike.Anchored   = false
		spike.CanCollide = false
		spike.Parent     = model
		weld(torso, spike)
	end

	-- Angel wings (2 tiers per side, 4 wing slabs total)
	for _, side in ipairs({ -1, 1 }) do
		for tier = 1, 2 do
			local wing = Instance.new("Part")
			wing.Name       = "Wing_" .. side .. "_" .. tier
			wing.Shape      = Enum.PartType.Block
			wing.Material   = Enum.Material.Neon
			wing.BrickColor = BrickColor.new("White")
			wing.Transparency = 0.2
			wing.Size       = Vector3.new(s * 0.06, s * (0.5 - tier * 0.1), s * (0.7 - tier * 0.15))
			wing.CFrame     = CFrame.new(position + Vector3.new(side * s * (0.5 + s * 0.1), s * (0.28 + tier * 0.18), -s * 0.18))
				* CFrame.Angles(0, math.rad(side * 20), math.rad(side * (25 + tier * 12)))
			wing.Anchored   = false
			wing.CanCollide = false
			wing.Parent     = model
			weld(torso, wing)
		end
	end

	return torso
end

-- banane_doom: elongated yellow head, black visor with red slits, shoulder spikes, DANGER accents
builders["banane_doom"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Bright yellow"), BrickColor.new("Really black"))
	local headCenter = position + Vector3.new(0, s * 0.78, 0)
	local headSize = s * 0.74

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Bright yellow")
	head.Size       = Vector3.new(headSize * 1.5, headSize * 0.72, headSize * 0.72)
	head.CFrame     = CFrame.new(headCenter) * CFrame.Angles(0, 0, math.rad(20))
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	-- Black Neon visor
	local visor = Instance.new("Part")
	visor.Name       = "Visor"
	visor.Shape      = Enum.PartType.Block
	visor.Material   = Enum.Material.Neon
	visor.BrickColor = BrickColor.new("Really black")
	visor.Size       = Vector3.new(headSize * 1.3, headSize * 0.2, s * 0.05)
	visor.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.06, headSize * 0.38))
		* CFrame.Angles(0, 0, math.rad(20))
	visor.Anchored   = false
	visor.CanCollide = false
	visor.Parent     = model
	weld(torso, visor)

	-- Red glowing visor slits
	for _, side in ipairs({ -1, 1 }) do
		local slit = Instance.new("Part")
		slit.Name       = "Slit_" .. side
		slit.Shape      = Enum.PartType.Block
		slit.Material   = Enum.Material.Neon
		slit.BrickColor = BrickColor.new("Bright red")
		slit.Size       = Vector3.new(headSize * 0.28, s * 0.06, s * 0.05)
		slit.CFrame     = CFrame.new(headCenter + Vector3.new(side * headSize * 0.3, headSize * 0.06, headSize * 0.4))
			* CFrame.Angles(0, 0, math.rad(20))
		slit.Anchored   = false
		slit.CanCollide = false
		slit.Parent     = model
		weld(torso, slit)
	end

	-- 6 black shoulder spikes
	local spikePositions = {
		{s * 0.5, s * 0.38, -1}, {s * 0.5, s * 0.22, -1}, {s * 0.46, s * 0.06, -1},
		{s * 0.5, s * 0.38,  1}, {s * 0.5, s * 0.22,  1}, {s * 0.46, s * 0.06,  1},
	}
	for i, sp in ipairs(spikePositions) do
		local spike = Instance.new("Part")
		spike.Name       = "Spike_" .. i
		spike.Shape      = Enum.PartType.Cylinder
		spike.Material   = Enum.Material.SmoothPlastic
		spike.BrickColor = BrickColor.new("Really black")
		spike.Size       = Vector3.new(s * 0.08, s * 0.28, s * 0.08)
		spike.CFrame     = CFrame.new(position + Vector3.new(sp[3] * sp[1], sp[2], 0))
			* CFrame.Angles(0, 0, math.rad(sp[3] * 65))
		spike.Anchored   = false
		spike.CanCollide = false
		spike.Parent     = model
		weld(torso, spike)
	end

	-- Red DANGER accent strips on torso
	for i = 1, 2 do
		local acc = Instance.new("Part")
		acc.Name       = "Accent_" .. i
		acc.Shape      = Enum.PartType.Block
		acc.Material   = Enum.Material.Neon
		acc.BrickColor = BrickColor.new("Bright red")
		acc.Size       = Vector3.new(s * 0.54, s * 0.06, s * 0.05)
		acc.CFrame     = CFrame.new(position + Vector3.new(0, s * (0.08 + (i - 1) * 0.26), s * 0.24))
		acc.Anchored   = false
		acc.CanCollide = false
		acc.Parent     = model
		weld(torso, acc)
	end

	return torso
end

-- raisin_rainbow: purple sphere head, 6 rainbow Neon orbiting spheres, double halo
builders["raisin_rainbow"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Dark indigo"), BrickColor.new("Dark indigo"))
	local headCenter = position + Vector3.new(0, s * 0.78, 0)
	local headSize = s * 0.74

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Dark indigo")
	head.Size       = Vector3.new(headSize, headSize * 0.88, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize * 0.88, model)

	-- 6 rainbow Neon orbiting spheres around head
	local rainbowColors = {
		BrickColor.new("Bright red"), BrickColor.new("Neon orange"),
		BrickColor.new("Bright yellow"), BrickColor.new("Lime green"),
		BrickColor.new("Bright blue"), BrickColor.new("Bright violet"),
	}
	for i, color in ipairs(rainbowColors) do
		local angle = math.rad((i - 1) * 60)
		local orb = Instance.new("Part")
		orb.Name       = "RainbowOrb_" .. i
		orb.Shape      = Enum.PartType.Ball
		orb.Material   = Enum.Material.Neon
		orb.BrickColor = color
		orb.Size       = Vector3.new(s * 0.19, s * 0.19, s * 0.19)
		orb.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * 0.85,
			headSize * 0.1,
			math.sin(angle) * headSize * 0.85
		))
		orb.Anchored   = false
		orb.CanCollide = false
		orb.Parent     = model
		weld(torso, orb)
	end

	-- Double halo (yellow outer + white inner)
	local haloData = {
		{BrickColor.new("Bright yellow"), headSize * 1.2, 0.0},
		{BrickColor.new("White"),         headSize * 0.95, 0.15},
	}
	for _, hd in ipairs(haloData) do
		local halo = Instance.new("Part")
		halo.Name         = "Halo"
		halo.Shape        = Enum.PartType.Cylinder
		halo.Material     = Enum.Material.Neon
		halo.BrickColor   = hd[1]
		halo.Transparency = hd[3]
		halo.Size         = Vector3.new(s * 0.08, hd[2], hd[2])
		halo.CFrame       = CFrame.new(headCenter + Vector3.new(0, headSize * 0.76, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		halo.Anchored     = false
		halo.CanCollide   = false
		halo.Parent       = model
		weld(torso, halo)
	end

	return torso
end

-- ananas_sigma: yellow sphere, dramatic spikes, black Neon sunglasses, backwards cap, crossed arms
builders["ananas_sigma"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Bright yellow"), BrickColor.new("Brown"))
	local headCenter = position + Vector3.new(0, s * 0.78, 0)
	local headSize = s * 0.74

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = BrickColor.new("Bright yellow")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- 7 dramatic green spikes at larger angles
	local spikeAngles = {0, 32, -32, 64, -64, 88, -88}
	for i, a in ipairs(spikeAngles) do
		local spike = Instance.new("Part")
		spike.Name       = "Spike_" .. i
		spike.Shape      = Enum.PartType.Cylinder
		spike.Material   = Enum.Material.SmoothPlastic
		spike.BrickColor = BrickColor.new("Bright green")
		spike.Size       = Vector3.new(s * 0.12, s * 0.62 - math.abs(a) * 0.003 * s, s * 0.12)
		spike.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.46 + s * 0.24, 0))
			* CFrame.Angles(0, 0, math.rad(a))
		spike.Anchored   = false
		spike.CanCollide = false
		spike.Parent     = model
		weld(torso, spike)
	end

	-- Black Neon sunglasses
	for _, side in ipairs({ -1, 1 }) do
		local lens = Instance.new("Part")
		lens.Name       = "Lens_" .. side
		lens.Shape      = Enum.PartType.Block
		lens.Material   = Enum.Material.Neon
		lens.BrickColor = BrickColor.new("Really black")
		lens.Size       = Vector3.new(headSize * 0.3, headSize * 0.15, s * 0.04)
		lens.CFrame     = CFrame.new(headCenter + Vector3.new(side * headSize * 0.24, headSize * 0.1, headSize * 0.48))
		lens.Anchored   = false
		lens.CanCollide = false
		lens.Parent     = model
		weld(torso, lens)
	end

	-- Backwards dark grey cap
	local cap = Instance.new("Part")
	cap.Name       = "Cap"
	cap.Shape      = Enum.PartType.Cylinder
	cap.Material   = Enum.Material.SmoothPlastic
	cap.BrickColor = BrickColor.new("Dark grey")
	cap.Size       = Vector3.new(s * 0.2, headSize * 1.05, headSize * 1.05)
	cap.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.52, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	cap.Anchored   = false
	cap.CanCollide = false
	cap.Parent     = model
	weld(torso, cap)

	-- Cap brim (pointing backwards = -Z)
	local brim = Instance.new("Part")
	brim.Name       = "CapBrim"
	brim.Shape      = Enum.PartType.Block
	brim.Material   = Enum.Material.SmoothPlastic
	brim.BrickColor = BrickColor.new("Dark grey")
	brim.Size       = Vector3.new(s * 0.15, headSize * 0.5, headSize * 0.2)
	brim.CFrame     = CFrame.new(headCenter + Vector3.new(0, headSize * 0.52, -headSize * 0.6))
	brim.Anchored   = false
	brim.CanCollide = false
	brim.Parent     = model
	weld(torso, brim)

	-- Crossed arms (2 thick blocks crossing the torso front)
	for _, side in ipairs({ -1, 1 }) do
		local carm = Instance.new("Part")
		carm.Name       = "CrossArm_" .. side
		carm.Shape      = Enum.PartType.Block
		carm.Material   = Enum.Material.SmoothPlastic
		carm.BrickColor = BrickColor.new("Bright yellow")
		carm.Size       = Vector3.new(s * 0.7, s * 0.2, s * 0.2)
		carm.CFrame     = CFrame.new(position + Vector3.new(0, s * 0.24, s * 0.24))
			* CFrame.Angles(0, 0, math.rad(side * 28))
		carm.Anchored   = false
		carm.CanCollide = false
		carm.Parent     = model
		weld(torso, carm)
	end

	return torso
end

-- pasteque_plasma: hot pink Neon sphere head, 6 flying chunks, 7 plasma orbs
builders["pasteque_plasma"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Bright green"), BrickColor.new("Dark green"))
	local headCenter = position + Vector3.new(0, s * 0.78, 0)
	local headSize = s * 0.74

	-- Hot pink Neon sphere head (slightly transparent)
	local head = Instance.new("Part")
	head.Name         = "Head"
	head.Shape        = Enum.PartType.Ball
	head.Material     = Enum.Material.Neon
	head.BrickColor   = BrickColor.new("Hot pink")
	head.Transparency = 0.12
	head.Size         = Vector3.new(headSize, headSize, headSize)
	head.CFrame       = CFrame.new(headCenter)
	head.Anchored     = false
	head.CanCollide   = false
	head.Parent       = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- 6 flying chunk blocks (red rind + hot pink flesh alternating)
	local chunkColors = {
		BrickColor.new("Bright green"), BrickColor.new("Bright red"),
		BrickColor.new("Bright green"), BrickColor.new("Bright red"),
		BrickColor.new("Bright green"), BrickColor.new("Bright red"),
	}
	for i, color in ipairs(chunkColors) do
		local angle = math.rad((i - 1) * 60)
		local chunk = Instance.new("Part")
		chunk.Name       = "Chunk_" .. i
		chunk.Shape      = Enum.PartType.Block
		chunk.Material   = Enum.Material.SmoothPlastic
		chunk.BrickColor = color
		chunk.Size       = Vector3.new(s * 0.22, s * 0.14, s * 0.1)
		chunk.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * (0.86 + i * 0.04),
			math.sin(angle) * headSize * 0.2 + headSize * 0.05,
			math.sin(angle) * headSize * 0.86
		)) * CFrame.Angles(math.random() * 0.6, angle, 0)
		chunk.Anchored   = false
		chunk.CanCollide = false
		chunk.Parent     = model
		weld(torso, chunk)
	end

	-- 7 plasma Neon orbs
	for i = 1, 7 do
		local angle = math.rad((i - 1) * (360 / 7))
		local orb = Instance.new("Part")
		orb.Name       = "PlasmaOrb_" .. i
		orb.Shape      = Enum.PartType.Ball
		orb.Material   = Enum.Material.Neon
		orb.BrickColor = BrickColor.new("Hot pink")
		orb.Size       = Vector3.new(s * 0.15, s * 0.15, s * 0.15)
		orb.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * 1.08,
			headSize * 0.08,
			math.sin(angle) * headSize * 1.08
		))
		orb.Anchored   = false
		orb.CanCollide = false
		orb.Parent     = model
		weld(torso, orb)
	end

	return torso
end

-- ============================================================
-- LEGENDARY (size ≈ 5)
-- ============================================================

-- mangue_cosmique: Neon orange sphere, 8-spike star crown, 6 gold cosmic orbs, 2-layer Neon cape
builders["mangue_cosmique"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Neon orange"), BrickColor.new("Dark orange"))
	local headCenter = position + Vector3.new(0, s * 0.8, 0)
	local headSize = s * 0.76

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.Neon
	head.BrickColor = BrickColor.new("Neon orange")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- 8-spike star crown
	for i = 1, 8 do
		local angle = math.rad((i - 1) * 45)
		local spike = Instance.new("Part")
		spike.Name       = "CrownSpike_" .. i
		spike.Shape      = Enum.PartType.Cylinder
		spike.Material   = Enum.Material.Neon
		spike.BrickColor = BrickColor.new("Bright yellow")
		spike.Size       = Vector3.new(s * 0.1, s * 0.52, s * 0.1)
		spike.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * 0.42,
			headSize * 0.62,
			math.sin(angle) * headSize * 0.42
		))
		spike.Anchored   = false
		spike.CanCollide = false
		spike.Parent     = model
		weld(torso, spike)
	end

	-- 6 gold cosmic orbs orbiting torso
	for i = 1, 6 do
		local angle = math.rad((i - 1) * 60)
		local orb = Instance.new("Part")
		orb.Name       = "CosmicOrb_" .. i
		orb.Shape      = Enum.PartType.Ball
		orb.Material   = Enum.Material.Neon
		orb.BrickColor = BrickColor.new("Bright yellow")
		orb.Size       = Vector3.new(s * 0.22, s * 0.22, s * 0.22)
		orb.CFrame     = CFrame.new(position + Vector3.new(
			math.cos(angle) * s * 0.9,
			s * 0.28,
			math.sin(angle) * s * 0.9
		))
		orb.Anchored   = false
		orb.CanCollide = false
		orb.Parent     = model
		weld(torso, orb)
	end

	-- 2-layer Neon cape behind torso
	local capeColors = {BrickColor.new("Neon orange"), BrickColor.new("Bright yellow")}
	for i, color in ipairs(capeColors) do
		local cape = Instance.new("Part")
		cape.Name         = "Cape_" .. i
		cape.Shape        = Enum.PartType.Block
		cape.Material     = Enum.Material.Neon
		cape.BrickColor   = color
		cape.Transparency = 0.3
		cape.Size         = Vector3.new(s * 0.08, s * (0.9 - i * 0.15), s * (0.7 - i * 0.1))
		cape.CFrame       = CFrame.new(position + Vector3.new(0, s * 0.22, -(s * 0.3 + i * s * 0.12)))
		cape.Anchored     = false
		cape.CanCollide   = false
		cape.Parent       = model
		weld(torso, cape)
	end

	return torso
end

-- fraise_omega: hot pink Neon sphere, Omega symbol, 3 halo rings, 4 large wing slabs, 3 torso accents
builders["fraise_omega"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Hot pink"), BrickColor.new("Dark red"))
	local headCenter = position + Vector3.new(0, s * 0.8, 0)
	local headSize = s * 0.76

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.Neon
	head.BrickColor = BrickColor.new("Hot pink")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- Omega symbol: 2 Neon cylinders on face
	for _, side in ipairs({ -1, 1 }) do
		local omegaPart = Instance.new("Part")
		omegaPart.Name       = "Omega_" .. side
		omegaPart.Shape      = Enum.PartType.Cylinder
		omegaPart.Material   = Enum.Material.Neon
		omegaPart.BrickColor = BrickColor.new("White")
		omegaPart.Size       = Vector3.new(s * 0.06, headSize * 0.5, headSize * 0.5)
		omegaPart.CFrame     = CFrame.new(headCenter + Vector3.new(side * headSize * 0.22, -headSize * 0.12, headSize * 0.4))
			* CFrame.Angles(0, 0, math.rad(90))
		omegaPart.Anchored   = false
		omegaPart.CanCollide = false
		omegaPart.Parent     = model
		weld(torso, omegaPart)
	end

	-- 3 overlapping halo rings (Neon cylinder discs)
	for i = 1, 3 do
		local halo = Instance.new("Part")
		halo.Name         = "Halo_" .. i
		halo.Shape        = Enum.PartType.Cylinder
		halo.Material     = Enum.Material.Neon
		halo.BrickColor   = BrickColor.new("Bright yellow")
		halo.Transparency = (i - 1) * 0.2
		halo.Size         = Vector3.new(s * 0.07, headSize * (1.15 - i * 0.08), headSize * (1.15 - i * 0.08))
		halo.CFrame       = CFrame.new(headCenter + Vector3.new(0, headSize * (0.72 + i * 0.04), 0))
			* CFrame.Angles(math.rad(i * 15), 0, math.rad(90))
		halo.Anchored     = false
		halo.CanCollide   = false
		halo.Parent       = model
		weld(torso, halo)
	end

	-- 4 large Neon wing slabs
	local wingData = {
		{ 1,  1, 0.52, 0.38}, { 1,  2, 0.46, 0.26},
		{-1,  1, 0.52, 0.38}, {-1,  2, 0.46, 0.26},
	}
	for i, wd in ipairs(wingData) do
		local wing = Instance.new("Part")
		wing.Name         = "Wing_" .. i
		wing.Shape        = Enum.PartType.Block
		wing.Material     = Enum.Material.Neon
		wing.BrickColor   = BrickColor.new("Hot pink")
		wing.Transparency = 0.25
		wing.Size         = Vector3.new(s * 0.07, s * wd[3], s * wd[4])
		wing.CFrame       = CFrame.new(position + Vector3.new(wd[1] * s * (0.52 + wd[2] * 0.18), s * 0.3, -s * 0.12))
			* CFrame.Angles(0, math.rad(wd[1] * 18), math.rad(wd[1] * (30 + wd[2] * 18)))
		wing.Anchored     = false
		wing.CanCollide   = false
		wing.Parent       = model
		weld(torso, wing)
	end

	-- 3 torso accent strips
	for i = 1, 3 do
		local acc = Instance.new("Part")
		acc.Name       = "TorsoAccent_" .. i
		acc.Shape      = Enum.PartType.Block
		acc.Material   = Enum.Material.Neon
		acc.BrickColor = BrickColor.new("White")
		acc.Size       = Vector3.new(s * 0.54, s * 0.06, s * 0.05)
		acc.CFrame     = CFrame.new(position + Vector3.new(0, s * (0.04 + (i - 1) * 0.22), s * 0.24))
		acc.Anchored   = false
		acc.CanCollide = false
		acc.Parent     = model
		weld(torso, acc)
	end

	return torso
end

-- banane_fantome: semi-transparent ghost body, 7 wisps, 6-sphere tail chain, pale blue halo
builders["banane_fantome"] = function(position, model, s, brainrotData)
	-- Ghost torso (semi-transparent Neon white)
	local torso = Instance.new("Part")
	torso.Name         = "Body"
	torso.Shape        = Enum.PartType.Block
	torso.Material     = Enum.Material.Neon
	torso.BrickColor   = BrickColor.new("White")
	torso.Transparency = 0.2
	torso.Size         = Vector3.new(s * 0.72, s * 0.9, s * 0.45)
	torso.CFrame       = CFrame.new(position)
	torso.Anchored     = true
	torso.CanCollide   = true
	torso.CastShadow   = true
	torso.Parent       = model
	model.PrimaryPart  = torso

	-- Arms (also transparent)
	local armLength = s * 0.75
	local armThick  = s * 0.18
	for _, side in ipairs({ -1, 1 }) do
		local arm = Instance.new("Part")
		arm.Name         = "Arm_" .. side
		arm.Shape        = Enum.PartType.Cylinder
		arm.Material     = Enum.Material.Neon
		arm.BrickColor   = BrickColor.new("White")
		arm.Transparency = 0.25
		arm.Size         = Vector3.new(armLength, armThick, armThick)
		arm.CFrame       = CFrame.new(
			position + Vector3.new(side * (s * 0.36 + armLength * 0.5), s * 0.22, 0)
		) * CFrame.Angles(0, 0, math.rad(side * 25))
		arm.Anchored   = false
		arm.CanCollide = false
		arm.Parent     = model
		weld(torso, arm)
	end

	local headCenter = position + Vector3.new(0, s * 0.8, 0)
	local headSize = s * 0.76

	-- Semi-transparent Neon head
	local head = Instance.new("Part")
	head.Name         = "Head"
	head.Shape        = Enum.PartType.Ball
	head.Material     = Enum.Material.Neon
	head.BrickColor   = BrickColor.new("White")
	head.Transparency = 0.3
	head.Size         = Vector3.new(headSize * 1.4, headSize * 0.72, headSize * 0.72)
	head.CFrame       = CFrame.new(headCenter) * CFrame.Angles(0, 0, math.rad(20))
	head.Anchored     = false
	head.CanCollide   = false
	head.Parent       = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize * 0.72, model)

	-- 7 ghost wisps (small pale blue Neon balls drifting around torso/head area)
	for i = 1, 7 do
		local angle = math.rad((i - 1) * (360 / 7))
		local wisp = Instance.new("Part")
		wisp.Name       = "Wisp_" .. i
		wisp.Shape      = Enum.PartType.Ball
		wisp.Material   = Enum.Material.Neon
		wisp.BrickColor = BrickColor.new("Light blue")
		wisp.Transparency = 0.4
		wisp.Size       = Vector3.new(s * 0.15, s * 0.15, s * 0.15)
		wisp.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * (0.78 + i * 0.04),
			math.sin(angle) * headSize * 0.3,
			math.sin(angle + math.rad(30)) * headSize * 0.5
		))
		wisp.Anchored   = false
		wisp.CanCollide = false
		wisp.Parent     = model
		weld(torso, wisp)
	end

	-- 6-sphere ghost tail chain below torso
	for i = 1, 6 do
		local tail = Instance.new("Part")
		tail.Name         = "Tail_" .. i
		tail.Shape        = Enum.PartType.Ball
		tail.Material     = Enum.Material.Neon
		tail.BrickColor   = BrickColor.new("White")
		tail.Transparency = 0.2 + i * 0.08
		tail.Size         = Vector3.new(s * (0.38 - i * 0.04), s * (0.38 - i * 0.04), s * (0.38 - i * 0.04))
		tail.CFrame       = CFrame.new(position + Vector3.new(
			math.sin(i * 0.6) * s * 0.2,
			-(s * 0.45 + i * s * 0.3),
			0
		))
		tail.Anchored     = false
		tail.CanCollide   = false
		tail.Parent       = model
		weld(torso, tail)
	end

	-- Pale blue halo
	local halo = Instance.new("Part")
	halo.Name         = "Halo"
	halo.Shape        = Enum.PartType.Cylinder
	halo.Material     = Enum.Material.Neon
	halo.BrickColor   = BrickColor.new("Light blue")
	halo.Transparency = 0.3
	halo.Size         = Vector3.new(s * 0.08, headSize * 1.18, headSize * 1.18)
	halo.CFrame       = CFrame.new(headCenter + Vector3.new(0, headSize * 0.72, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	halo.Anchored     = false
	halo.CanCollide   = false
	halo.Parent       = model
	weld(torso, halo)

	return torso
end

-- dragon_ultime: deep orange sphere, 7 large white Neon spikes, 2x3 dragon wings, fire arc, Neon tail
builders["dragon_ultime"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Deep orange"), BrickColor.new("Really black"))
	local headCenter = position + Vector3.new(0, s * 0.8, 0)
	local headSize = s * 0.76

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.Neon
	head.BrickColor = BrickColor.new("Deep orange")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- 7 large white Neon spikes radiating from head
	for i = 1, 7 do
		local angle = math.rad((i - 1) * (360 / 7))
		local spike = Instance.new("Part")
		spike.Name       = "Spike_" .. i
		spike.Shape      = Enum.PartType.Cylinder
		spike.Material   = Enum.Material.Neon
		spike.BrickColor = BrickColor.new("White")
		spike.Size       = Vector3.new(s * 0.12, s * 0.7, s * 0.12)
		spike.CFrame     = CFrame.new(headCenter + Vector3.new(
			math.cos(angle) * headSize * 0.44,
			headSize * 0.52 + math.abs(math.cos(angle)) * s * 0.1,
			math.sin(angle) * headSize * 0.44
		))
		spike.Anchored   = false
		spike.CanCollide = false
		spike.Parent     = model
		weld(torso, spike)
	end

	-- 2x3 segment dragon wings (red Neon)
	for _, side in ipairs({ -1, 1 }) do
		for seg = 1, 3 do
			local wing = Instance.new("Part")
			wing.Name         = "Wing_" .. side .. "_" .. seg
			wing.Shape        = Enum.PartType.Block
			wing.Material     = Enum.Material.Neon
			wing.BrickColor   = BrickColor.new("Bright red")
			wing.Transparency = 0.2
			wing.Size         = Vector3.new(s * 0.07, s * (0.6 - seg * 0.1), s * (0.56 - seg * 0.12))
			wing.CFrame       = CFrame.new(position + Vector3.new(
				side * s * (0.48 + seg * 0.28),
				s * (0.36 - seg * 0.08),
				-s * 0.15
			)) * CFrame.Angles(0, math.rad(side * 12), math.rad(side * (22 + seg * 14)))
			wing.Anchored   = false
			wing.CanCollide = false
			wing.Parent     = model
			weld(torso, wing)
		end
	end

	-- 7-orb fire breath arc in front
	for i = 1, 7 do
		local t = (i - 1) / 6
		local orb = Instance.new("Part")
		orb.Name       = "FireOrb_" .. i
		orb.Shape      = Enum.PartType.Ball
		orb.Material   = Enum.Material.Neon
		orb.BrickColor = i <= 4 and BrickColor.new("Bright orange") or BrickColor.new("Bright yellow")
		orb.Size       = Vector3.new(s * (0.2 - t * 0.08), s * (0.2 - t * 0.08), s * (0.2 - t * 0.08))
		orb.CFrame     = CFrame.new(headCenter + Vector3.new(
			(t - 0.5) * headSize * 0.8,
			headSize * (-0.1 - t * 0.5),
			headSize * (0.5 + t * 0.6)
		))
		orb.Anchored   = false
		orb.CanCollide = false
		orb.Parent     = model
		weld(torso, orb)
	end

	-- 5-segment Neon tail behind torso
	for i = 1, 5 do
		local tail = Instance.new("Part")
		tail.Name       = "Tail_" .. i
		tail.Shape      = Enum.PartType.Ball
		tail.Material   = Enum.Material.Neon
		tail.BrickColor = BrickColor.new("Deep orange")
		tail.Size       = Vector3.new(s * (0.4 - i * 0.05), s * (0.4 - i * 0.05), s * (0.4 - i * 0.05))
		tail.CFrame     = CFrame.new(position + Vector3.new(
			math.sin(i * 0.7) * s * 0.3,
			-(s * 0.3 + i * s * 0.28),
			-(s * 0.2 + i * s * 0.18)
		))
		tail.Anchored   = false
		tail.CanCollide = false
		tail.Parent     = model
		weld(torso, tail)
	end

	return torso
end

-- le_tentafruit: purple Neon sphere, 8 tentacles, 4-ring elaborate crown, 4 torso tentacles, 6 chaos orbs
builders["le_tentafruit"] = function(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, BrickColor.new("Dark indigo"), BrickColor.new("Dark indigo"))
	local headCenter = position + Vector3.new(0, s * 0.8, 0)
	local headSize = s * 0.76

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.Neon
	head.BrickColor = BrickColor.new("Bright violet")
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	-- 8 tentacles from head top (4 segments + glowing tip orb each)
	for i = 1, 8 do
		local baseAngle = math.rad((i - 1) * 45)
		local prevPart = head
		local segBase = headCenter + Vector3.new(0, headSize * 0.44, 0)
		for seg = 1, 4 do
			local sway = math.sin(i * 1.3 + seg * 0.8) * 0.3
			local segPart = Instance.new("Part")
			segPart.Name       = "Tentacle_" .. i .. "_" .. seg
			segPart.Shape      = Enum.PartType.Cylinder
			segPart.Material   = Enum.Material.Neon
			segPart.BrickColor = seg <= 2 and BrickColor.new("Bright violet") or BrickColor.new("Dark indigo")
			segPart.Size       = Vector3.new(s * (0.12 - seg * 0.018), s * 0.32, s * (0.12 - seg * 0.018))
			local offset = Vector3.new(
				math.cos(baseAngle) * s * (0.18 + seg * 0.16) + sway * s * 0.1,
				s * 0.28 * seg,
				math.sin(baseAngle) * s * (0.18 + seg * 0.16)
			)
			segPart.CFrame     = CFrame.new(segBase + offset)
			segPart.Anchored   = false
			segPart.CanCollide = false
			segPart.Parent     = model
			weld(torso, segPart)
		end
		-- Glowing tip orb
		local tip = Instance.new("Part")
		tip.Name       = "TentacleTip_" .. i
		tip.Shape      = Enum.PartType.Ball
		tip.Material   = Enum.Material.Neon
		tip.BrickColor = BrickColor.new("Bright violet")
		tip.Size       = Vector3.new(s * 0.14, s * 0.14, s * 0.14)
		local sway = math.sin(i * 1.3 + 4 * 0.8) * 0.3
		tip.CFrame     = CFrame.new(segBase + Vector3.new(
			math.cos(baseAngle) * s * (0.18 + 5 * 0.16) + sway * s * 0.1,
			s * 0.28 * 5,
			math.sin(baseAngle) * s * (0.18 + 5 * 0.16)
		))
		tip.Anchored   = false
		tip.CanCollide = false
		tip.Parent     = model
		weld(torso, tip)
	end

	-- 4-ring elaborate crown (cylinders of decreasing radius + Neon)
	for i = 1, 4 do
		local ring = Instance.new("Part")
		ring.Name         = "CrownRing_" .. i
		ring.Shape        = Enum.PartType.Cylinder
		ring.Material     = Enum.Material.Neon
		ring.BrickColor   = i % 2 == 0 and BrickColor.new("Bright yellow") or BrickColor.new("Bright violet")
		ring.Transparency = (i - 1) * 0.1
		ring.Size         = Vector3.new(s * 0.08, headSize * (1.28 - i * 0.1), headSize * (1.28 - i * 0.1))
		ring.CFrame       = CFrame.new(headCenter + Vector3.new(0, headSize * (0.68 + i * 0.06), 0))
			* CFrame.Angles(math.rad(i * 20), 0, math.rad(90))
		ring.Anchored     = false
		ring.CanCollide   = false
		ring.Parent       = model
		weld(torso, ring)
	end

	-- 4 torso tentacle extensions (shorter, from torso sides)
	for i = 1, 4 do
		local angle = math.rad((i - 1) * 90 + 45)
		local tent = Instance.new("Part")
		tent.Name       = "TorsoTentacle_" .. i
		tent.Shape      = Enum.PartType.Cylinder
		tent.Material   = Enum.Material.Neon
		tent.BrickColor = BrickColor.new("Bright violet")
		tent.Size       = Vector3.new(s * 0.1, s * 0.5, s * 0.1)
		tent.CFrame     = CFrame.new(position + Vector3.new(
			math.cos(angle) * s * 0.46,
			s * 0.1,
			math.sin(angle) * s * 0.46
		)) * CFrame.Angles(0, angle, math.rad(80))
		tent.Anchored   = false
		tent.CanCollide = false
		tent.Parent     = model
		weld(torso, tent)
	end

	-- 6 chaos orbs orbiting at mid-torso height
	local chaosColors = {
		BrickColor.new("Bright red"), BrickColor.new("Bright orange"),
		BrickColor.new("Bright yellow"), BrickColor.new("Lime green"),
		BrickColor.new("Cyan"), BrickColor.new("Hot pink"),
	}
	for i, color in ipairs(chaosColors) do
		local angle = math.rad((i - 1) * 60)
		local orb = Instance.new("Part")
		orb.Name       = "ChaosOrb_" .. i
		orb.Shape      = Enum.PartType.Ball
		orb.Material   = Enum.Material.Neon
		orb.BrickColor = color
		orb.Size       = Vector3.new(s * 0.2, s * 0.2, s * 0.2)
		orb.CFrame     = CFrame.new(position + Vector3.new(
			math.cos(angle) * s * 1.0,
			s * 0.18,
			math.sin(angle) * s * 1.0
		))
		orb.Anchored   = false
		orb.CanCollide = false
		orb.Parent     = model
		weld(torso, orb)
	end

	return torso
end

-- ============================================================
-- Generic fallback (used when no specific builder exists)
-- ============================================================
function CharacterBuilders.generic(position, model, s, brainrotData)
	local torso = buildBase(position, model, s, brainrotData.color, brainrotData.color)
	local headCenter = position + Vector3.new(0, s * 0.76, 0)
	local headSize = s * 0.68

	local head = Instance.new("Part")
	head.Name       = "Head"
	head.Shape      = Enum.PartType.Ball
	head.Material   = Enum.Material.SmoothPlastic
	head.BrickColor = brainrotData.color
	head.Size       = Vector3.new(headSize, headSize, headSize)
	head.CFrame     = CFrame.new(headCenter)
	head.Anchored   = false
	head.CanCollide = false
	head.CastShadow = false
	head.Parent     = model
	weld(torso, head)

	addEyes(torso, headCenter, headSize, model)

	return torso
end

-- ============================================================
-- Dispatcher
-- ============================================================
function CharacterBuilders.build(brainrotId, position, model, s, brainrotData)
	local builder = builders[brainrotId]
	if builder then
		return builder(position, model, s, brainrotData)
	end
	return CharacterBuilders.generic(position, model, s, brainrotData)
end

return CharacterBuilders
