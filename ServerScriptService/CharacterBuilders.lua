-- CharacterBuilders.lua
-- ModuleScript: Builds humanoid fruit characters for each skin ID.
-- Returns the torso Part (body / PrimaryPart) for each character.

local CharacterBuilders = {}

local function buildFromImportedMesh(pos, model, s, templateName)
	local template = game:GetService("ReplicatedStorage"):WaitForChild(templateName)
	local clone = template:Clone()
	clone.Parent = model

	-- Ensure PrimaryPart is set (Roblox requires it for SetPrimaryPartCFrame)
	if not clone.PrimaryPart then
		clone.PrimaryPart = clone:FindFirstChildWhichIsA("MeshPart", true)
			or clone:FindFirstChildWhichIsA("BasePart", true)
	end

	-- Scale to match the skin's size parameter (s*2 = total height)
	local extents = clone:GetExtentsSize()
	local currentHeight = math.max(extents.X, extents.Y, extents.Z)
	if currentHeight > 0 then
		clone:ScaleTo(s * 2 / currentHeight)
	end

	-- Anchor all parts and disable collision so the character can't be pushed
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored   = true
			part.CanCollide = false
		end
	end

	-- Position: move every part individually (SetPrimaryPartCFrame does NOT move anchored parts).
	-- Desired: bottom of bounding box at pos.Y - s (= slotSurfaceY), centered on pos.X/Z.
	do
		local bbCF, bbSize = clone:GetBoundingBox()
		local offsetX = pos.X - bbCF.Position.X
		local offsetY = (pos.Y - s) - (bbCF.Position.Y - bbSize.Y / 2)
		local offsetZ = pos.Z - bbCF.Position.Z
		local delta   = Vector3.new(offsetX, offsetY, offsetZ)
		for _, p2 in ipairs(clone:GetDescendants()) do
			if p2:IsA("BasePart") then
				p2.CFrame = p2.CFrame + delta
			end
		end
		-- Also move the PrimaryPart itself
		if clone.PrimaryPart then
			clone.PrimaryPart.CFrame = clone.PrimaryPart.CFrame + delta
		end
	end
	-- Mark this sub-model as FBX so CharacterBuilders.build rotates it correctly
	clone:SetAttribute("_IsFBX", true)
	model.PrimaryPart = clone.PrimaryPart

	-- Play walk animation if present
	local anim = clone:FindFirstChildWhichIsA("Animation", true)
	if anim then
		local animator = clone:FindFirstChildWhichIsA("Animator", true)
		if not animator then
			local ctrl = clone:FindFirstChildWhichIsA("AnimationController", true)
				or clone:FindFirstChildWhichIsA("Humanoid", true)
			if ctrl then
				animator = Instance.new("Animator")
				animator.Parent = ctrl
			end
		end
		if animator then
			local track = animator:LoadAnimation(anim)
			track:Play()
		end
	end
	return clone.PrimaryPart
end

-- ============================================================
-- Shared helpers
-- ============================================================

local function weld(partA, partB)
	local w = Instance.new("WeldConstraint")
	w.Part0 = partA
	w.Part1 = partB
	w.Parent = partA
end

-- Generic part creator — welds to torso automatically
local function p(model, torso, shape, mat, color, size, cf, transp)
	local inst = Instance.new("Part")
	inst.Shape      = shape
	inst.Material   = mat
	inst.BrickColor = color
	inst.Size       = size
	inst.CFrame     = cf
	inst.Anchored   = false
	inst.CanCollide = false
	inst.CastShadow = false
	inst.Parent     = model
	if transp then inst.Transparency = transp end
	weld(torso, inst)
	return inst
end

local B = Enum.PartType.Ball
local BLK = Enum.PartType.Block
local CYL = Enum.PartType.Cylinder
local SMP = Enum.Material.SmoothPlastic
local NEO = Enum.Material.Neon
local GLS = Enum.Material.Glass

local function addEyes(torso, hc, hs, model)
	local es = hs * 0.28
	local ps = es * 0.45
	for _, side in ipairs({-1, 1}) do
		p(model, torso, B, SMP, BrickColor.new("White"),
			Vector3.new(es, es, es),
			CFrame.new(hc + Vector3.new(side * hs * 0.22, hs * 0.08, hs * 0.42)))
		p(model, torso, B, SMP, BrickColor.new("Really black"),
			Vector3.new(ps, ps, ps),
			CFrame.new(hc + Vector3.new(side * hs * 0.22, hs * 0.08, hs * 0.42 + es * 0.35)))
	end
end

local function buildBase(pos, model, s, tc, lc)
	local torso = Instance.new("Part")
	torso.Name      = "Body"
	torso.Shape     = BLK
	torso.Material  = SMP
	torso.BrickColor = tc
	torso.Size      = Vector3.new(s * 0.72, s * 0.9, s * 0.45)
	torso.CFrame    = CFrame.new(pos)
	torso.Anchored  = true
	torso.CanCollide = true
	torso.CastShadow = true
	torso.Parent    = model
	model.PrimaryPart = torso

	local al = s * 0.75
	local at = s * 0.18
	for _, side in ipairs({-1, 1}) do
		p(model, torso, CYL, SMP, tc,
			Vector3.new(al, at, at),
			CFrame.new(pos + Vector3.new(side * (s * 0.36 + al * 0.5), s * 0.22, 0))
				* CFrame.Angles(0, 0, math.rad(side * 25)))
		p(model, torso, CYL, SMP, lc or tc,
			Vector3.new(s * 0.2, s * 0.55, s * 0.2),
			CFrame.new(pos + Vector3.new(side * s * 0.16, -(s * 0.45 + s * 0.275), 0)))
	end

	return torso
end

-- Shorthand BrickColors
local RED    = BrickColor.new("Bright red")
local DRED   = BrickColor.new("Dark red")
local YEL    = BrickColor.new("Bright yellow")
local DYEL   = BrickColor.new("Dark yellow")
local ORG    = BrickColor.new("Neon orange")
local DORG   = BrickColor.new("Dark orange")
local GRN    = BrickColor.new("Bright green")
local DGRN   = BrickColor.new("Dark green")
local LGRN   = BrickColor.new("Lime green")
local IND    = BrickColor.new("Dark indigo")
local VIO    = BrickColor.new("Bright violet")
local BLU    = BrickColor.new("Bright blue")
local WHT    = BrickColor.new("White")
local BLK2   = BrickColor.new("Really black")
local PNK    = BrickColor.new("Hot pink")
local BRN    = BrickColor.new("Brown")
local TAN    = BrickColor.new("Tan")
local GRY    = BrickColor.new("Mid gray")
local DGRYA  = BrickColor.new("Dark grey")

-- ============================================================
-- Builders
-- ============================================================
local builders = {}

-- fraise_jr (Common): custom imported mesh (FraiseSkin)
builders["fraise_jr"] = function(pos, model, s)
	return buildFromImportedMesh(pos, model, s, "FraiseSkin")
end

-- myrtille_babe (Uncommon): custom imported mesh (MyrtilleSkin)
builders["myrtille_babe"] = function(pos, model, s)
	return buildFromImportedMesh(pos, model, s, "MyrtilleSkin")
end

-- noisette_king (Uncommon): custom imported mesh (NoisetteSkin)
builders["noisette_king"] = function(pos, model, s)
	return buildFromImportedMesh(pos, model, s, "NoisetteSkin")
end

-- poire_belle (Uncommon): custom imported mesh (PoireSkin)
builders["poire_belle"] = function(pos, model, s)
	return buildFromImportedMesh(pos, model, s, "PoireSkin")
end

-- banane_bro (Common): custom imported mesh (BananeSkin)
builders["banane_bro"] = function(pos, model, s)
	return buildFromImportedMesh(pos, model, s, "BananeSkin")
end

-- banane_bro_fallback (procedural, kept for reference)
local function _banane_bro_procedural(pos, model, s)
	local tor = buildBase(pos, model, s, YEL, DYEL)
	local hc  = pos + Vector3.new(0, s * 0.76, 0)
	local hs  = s * 0.65
	p(model, tor, CYL, SMP, YEL, Vector3.new(hs*1.6, hs*0.7, hs*0.7),
		CFrame.new(hc) * CFrame.Angles(0, 0, math.rad(30)))
	addEyes(tor, hc, hs * 0.7, model)
	for _, side in ipairs({-1, 1}) do
		p(model, tor, B, SMP, BRN, Vector3.new(s*0.14, s*0.14, s*0.14),
			CFrame.new(hc + Vector3.new(side * hs*0.72, side * hs*0.42, 0)))
	end
	p(model, tor, BLK, NEO, YEL, Vector3.new(hs*1.1, s*0.04, s*0.04),
		CFrame.new(hc + Vector3.new(0, hs*0.2, hs*0.36)) * CFrame.Angles(0, 0, math.rad(30)), 0.6)
	return tor
end

-- orange_girl (Common): orange sphere head, green stem, 5 peel stripes
builders["orange_girl"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, ORG, DORG)
	local hc  = pos + Vector3.new(0, s * 0.75, 0)
	local hs  = s * 0.68
	p(model, tor, B, SMP, ORG, Vector3.new(hs, hs, hs), CFrame.new(hc))
	addEyes(tor, hc, hs, model)
	p(model, tor, CYL, SMP, GRN, Vector3.new(s*0.1, s*0.35, s*0.1),
		CFrame.new(hc + Vector3.new(0, hs*0.55, 0)))
	for i = 1, 5 do
		local a = math.rad((i-1) * 72)
		p(model, tor, BLK, SMP, ORG, Vector3.new(s*0.06, hs*0.9, s*0.06),
			CFrame.new(hc) * CFrame.Angles(0, a, math.rad(60)) * CFrame.new(0, hs*0.38, 0), 0.4)
	end
	return tor
end

-- raisin_guy (Common): dark indigo squished sphere head, wrinkle bumps
builders["raisin_guy"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, IND, IND)
	local hc  = pos + Vector3.new(0, s * 0.72, 0)
	local hs  = s * 0.6
	p(model, tor, B, SMP, IND, Vector3.new(hs*1.05, hs*0.82, hs), CFrame.new(hc))
	addEyes(tor, hc, hs * 0.82, model)
	for i = 1, 5 do
		p(model, tor, B, SMP, IND, Vector3.new(s*0.09, s*0.06, s*0.06),
			CFrame.new(hc + Vector3.new((i-3)*hs*0.18, hs*(0.1 + math.abs(i-3)*0.06), hs*0.46)))
	end
	for _, side in ipairs({-1, 1}) do
		p(model, tor, BLK, SMP, IND, Vector3.new(hs*0.32, s*0.06, s*0.04),
			CFrame.new(hc + Vector3.new(side*hs*0.2, hs*0.18, hs*0.46))
				* CFrame.Angles(0, 0, math.rad(side * -12)))
	end
	return tor
end

-- tomate_basic (Common): squished red sphere, 5-leaf star crown, belly dimple
builders["tomate_basic"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, RED, RED)
	local hc  = pos + Vector3.new(0, s * 0.74, 0)
	local hs  = s * 0.68
	p(model, tor, B, SMP, RED, Vector3.new(hs*1.05, hs*0.88, hs), CFrame.new(hc))
	addEyes(tor, hc, hs * 0.88, model)
	p(model, tor, CYL, SMP, GRN, Vector3.new(s*0.1, s*0.28, s*0.1),
		CFrame.new(hc + Vector3.new(0, hs*0.52, 0)))
	for i = 1, 5 do
		local a = math.rad((i-1) * 72)
		p(model, tor, BLK, SMP, GRN, Vector3.new(s*0.08, s*0.28, s*0.07),
			CFrame.new(hc + Vector3.new(0, hs*0.48, 0))
				* CFrame.Angles(0, a, math.rad(50)) * CFrame.new(0, s*0.16, 0))
	end
	p(model, tor, B, SMP, DRED, Vector3.new(s*0.09, s*0.09, s*0.06),
		CFrame.new(pos + Vector3.new(0, s*0.1, s*0.24)))
	return tor
end

-- mangue_queen (Uncommon): tall oval mango head, Neon gold crown, pink gem
builders["mangue_queen"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, ORG, DORG)
	local hc  = pos + Vector3.new(0, s * 0.76, 0)
	local hs  = s * 0.7
	p(model, tor, B, SMP, ORG, Vector3.new(hs*0.9, hs*1.25, hs*0.9), CFrame.new(hc))
	addEyes(tor, hc, hs, model)
	p(model, tor, CYL, NEO, YEL, Vector3.new(s*0.08, hs*1.06, hs*1.06),
		CFrame.new(hc + Vector3.new(0, hs*0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)))
	for i = 1, 5 do
		local a = math.rad((i-1) * 72)
		p(model, tor, CYL, NEO, YEL, Vector3.new(s*0.08, s*0.38, s*0.08),
			CFrame.new(hc + Vector3.new(math.cos(a)*hs*0.42, hs*0.72, math.sin(a)*hs*0.42)))
	end
	p(model, tor, B, NEO, PNK, Vector3.new(s*0.15, s*0.15, s*0.15),
		CFrame.new(hc + Vector3.new(0, hs*0.62, 0)))
	return tor
end

-- ananas_king (Uncommon): yellow sphere, 7 green spikes, dark brow
builders["ananas_king"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, YEL, BRN)
	local hc  = pos + Vector3.new(0, s * 0.76, 0)
	local hs  = s * 0.7
	p(model, tor, B, SMP, YEL, Vector3.new(hs, hs, hs), CFrame.new(hc))
	addEyes(tor, hc, hs, model)
	local sAngles = {0, 26, -26, 52, -52, 78, -78}
	for i, a in ipairs(sAngles) do
		p(model, tor, CYL, SMP, GRN, Vector3.new(s*0.1, s*0.5 - math.abs(a)*0.002*s, s*0.1),
			CFrame.new(hc + Vector3.new(0, hs*0.44 + s*0.22, 0)) * CFrame.Angles(0, 0, math.rad(a)))
	end
	p(model, tor, BLK, SMP, BLK2, Vector3.new(hs*0.9, s*0.08, s*0.05),
		CFrame.new(hc + Vector3.new(0, hs*0.18, hs*0.47)))
	return tor
end

-- cerise_duo (Uncommon): two red sphere heads side by side
builders["cerise_duo"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, RED, DRED)
	local hs  = s * 0.52
	for _, side in ipairs({-1, 1}) do
		local hc = pos + Vector3.new(side * hs * 0.65, s * 0.74, 0)
		p(model, tor, B, SMP, RED, Vector3.new(hs, hs, hs), CFrame.new(hc))
		addEyes(tor, hc, hs, model)
		p(model, tor, CYL, SMP, GRN, Vector3.new(s*0.07, s*0.32, s*0.07),
			CFrame.new(hc + Vector3.new(0, hs*0.54, 0)) * CFrame.Angles(0, 0, math.rad(side * 18)))
	end
	return tor
end

-- pasteque_bro (Uncommon): green outer sphere, red face, 5 black seeds
builders["pasteque_bro"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, GRN, DGRN)
	local hc  = pos + Vector3.new(0, s * 0.76, 0)
	local hs  = s * 0.7
	p(model, tor, B, SMP, GRN, Vector3.new(hs, hs, hs), CFrame.new(hc))
	p(model, tor, B, SMP, RED, Vector3.new(hs*0.86, hs*0.86, hs*0.86),
		CFrame.new(hc + Vector3.new(0, 0, hs*0.08)))
	addEyes(tor, hc, hs * 0.86, model)
	for i = 1, 5 do
		local a = math.rad((i-1) * 72 + 36)
		p(model, tor, B, SMP, BLK2, Vector3.new(s*0.09, s*0.09, s*0.09),
			CFrame.new(hc + Vector3.new(math.cos(a)*hs*0.28, math.sin(a)*hs*0.22 + hs*0.05, hs*0.43)))
	end
	return tor
end

-- citron_vert (Uncommon): lime green sphere, yellow dot, brows, hair tuft
builders["citron_vert"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, LGRN, DGRN)
	local hc  = pos + Vector3.new(0, s * 0.76, 0)
	local hs  = s * 0.68
	p(model, tor, B, SMP, LGRN, Vector3.new(hs, hs, hs), CFrame.new(hc))
	addEyes(tor, hc, hs, model)
	p(model, tor, B, NEO, YEL, Vector3.new(s*0.13, s*0.13, s*0.13),
		CFrame.new(hc + Vector3.new(hs*0.28, hs*0.28, hs*0.38)))
	for _, side in ipairs({-1, 1}) do
		p(model, tor, BLK, SMP, DGRN, Vector3.new(hs*0.28, s*0.06, s*0.04),
			CFrame.new(hc + Vector3.new(side*hs*0.2, hs*0.18, hs*0.47))
				* CFrame.Angles(0, 0, math.rad(side * 15)))
	end
	for i = 1, 3 do
		p(model, tor, CYL, SMP, LGRN, Vector3.new(s*0.1, s*0.32, s*0.1),
			CFrame.new(hc + Vector3.new(0, hs*0.52, 0))
				* CFrame.Angles(0, 0, math.rad(-20 + (i-1)*20)))
	end
	return tor
end

-- avocat_elite (Rare): dark green oval head, lime face patch, tan seed, sunglasses
builders["avocat_elite"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, DGRN, DGRN)
	local hc  = pos + Vector3.new(0, s * 0.77, 0)
	local hs  = s * 0.72
	p(model, tor, B, SMP, DGRN, Vector3.new(hs*0.88, hs*1.18, hs*0.88), CFrame.new(hc))
	p(model, tor, B, SMP, LGRN, Vector3.new(hs*0.62, hs*0.78, hs*0.62),
		CFrame.new(hc + Vector3.new(0, -hs*0.06, hs*0.1)))
	addEyes(tor, hc, hs * 0.78, model)
	p(model, tor, B, SMP, TAN, Vector3.new(hs*0.3, hs*0.38, hs*0.3),
		CFrame.new(hc + Vector3.new(0, -hs*0.08, hs*0.32)))
	for _, side in ipairs({-1, 1}) do
		p(model, tor, BLK, SMP, BLK2, Vector3.new(hs*0.28, hs*0.14, s*0.04),
			CFrame.new(hc + Vector3.new(side*hs*0.22, hs*0.14, hs*0.47)))
	end
	p(model, tor, BLK, SMP, BLK2, Vector3.new(hs*0.1, s*0.04, s*0.04),
		CFrame.new(hc + Vector3.new(0, hs*0.14, hs*0.47)))
	return tor
end

-- dragon_fruit (Rare): hot pink sphere, transparent aura, 8 white spikes
builders["dragon_fruit"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, PNK, PNK)
	local hc  = pos + Vector3.new(0, s * 0.77, 0)
	local hs  = s * 0.72
	p(model, tor, B, SMP, PNK, Vector3.new(hs, hs, hs), CFrame.new(hc))
	p(model, tor, B, NEO, PNK, Vector3.new(hs*1.6, hs*1.6, hs*1.6), CFrame.new(hc), 0.72)
	addEyes(tor, hc, hs, model)
	for i = 1, 8 do
		local a = math.rad((i-1) * 45)
		p(model, tor, CYL, SMP, WHT, Vector3.new(s*0.38, s*0.1, s*0.1),
			CFrame.new(hc + Vector3.new(math.cos(a)*hs*0.52, math.sin(a)*hs*0.2 + hs*0.08, math.sin(a)*hs*0.52))
				* CFrame.Angles(0, a, math.rad(90)))
	end
	return tor
end

-- kiwi_shadow (Rare): brown head, green flesh disc, lime core, ninja headband
builders["kiwi_shadow"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, BRN, DGRYA)
	local hc  = pos + Vector3.new(0, s * 0.77, 0)
	local hs  = s * 0.72
	p(model, tor, B, SMP, BRN, Vector3.new(hs, hs, hs), CFrame.new(hc))
	p(model, tor, CYL, SMP, GRN, Vector3.new(s*0.06, hs*0.9, hs*0.9),
		CFrame.new(hc + Vector3.new(0, 0, hs*0.35)) * CFrame.Angles(0, 0, math.rad(90)))
	p(model, tor, B, NEO, LGRN, Vector3.new(hs*0.28, hs*0.28, hs*0.28),
		CFrame.new(hc + Vector3.new(0, 0, hs*0.4)))
	addEyes(tor, hc, hs * 0.9, model)
	p(model, tor, CYL, SMP, BLK2, Vector3.new(s*0.1, hs*1.02, hs*1.02),
		CFrame.new(hc + Vector3.new(0, hs*0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)))
	p(model, tor, BLK, SMP, GRY, Vector3.new(s*0.06, hs*0.36, hs*0.22),
		CFrame.new(hc + Vector3.new(0, hs*0.06, hs*0.52)))
	return tor
end

-- figue_mystique (Rare): tall purple head, wizard hat, white beard, 4 orbs
builders["figue_mystique"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, IND, IND)
	local hc  = pos + Vector3.new(0, s * 0.77, 0)
	local hs  = s * 0.72
	p(model, tor, B, SMP, IND, Vector3.new(hs*0.85, hs*1.35, hs*0.85), CFrame.new(hc))
	addEyes(tor, hc, hs, model)
	p(model, tor, CYL, SMP, IND, Vector3.new(s*0.1, hs*1.2, hs*1.2),
		CFrame.new(hc + Vector3.new(0, hs*0.72, 0)) * CFrame.Angles(0, 0, math.rad(90)))
	p(model, tor, B, SMP, IND, Vector3.new(hs*0.7, hs*0.7, hs*0.7),
		CFrame.new(hc + Vector3.new(0, hs*0.92, 0)))
	p(model, tor, B, SMP, IND, Vector3.new(hs*0.3, hs*0.5, hs*0.3),
		CFrame.new(hc + Vector3.new(0, hs*1.28, 0)))
	p(model, tor, BLK, SMP, WHT, Vector3.new(hs*0.52, hs*0.5, s*0.1),
		CFrame.new(hc + Vector3.new(0, -hs*0.38, hs*0.42)))
	for i = 1, 4 do
		local a = math.rad((i-1) * 90)
		p(model, tor, B, NEO, VIO, Vector3.new(s*0.18, s*0.18, s*0.18),
			CFrame.new(hc + Vector3.new(math.cos(a)*hs*0.82, -hs*0.15, math.sin(a)*hs*0.82)))
	end
	return tor
end

-- papaye_pro (Rare): tall orange oval head, 3 seeds, shoulder pads, tribal stripes
builders["papaye_pro"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, ORG, DORG)
	local hc  = pos + Vector3.new(0, s * 0.77, 0)
	local hs  = s * 0.72
	p(model, tor, B, SMP, ORG, Vector3.new(hs*0.88, hs*1.22, hs*0.88), CFrame.new(hc))
	addEyes(tor, hc, hs, model)
	for i = 1, 3 do
		p(model, tor, B, SMP, BLK2, Vector3.new(s*0.1, s*0.1, s*0.1),
			CFrame.new(hc + Vector3.new((i-2)*hs*0.22, (i == 2 and 0 or -hs*0.12), hs*0.45)))
	end
	for _, side in ipairs({-1, 1}) do
		p(model, tor, BLK, SMP, DORG, Vector3.new(s*0.28, s*0.18, s*0.22),
			CFrame.new(pos + Vector3.new(side*s*0.5, s*0.28, 0)))
	end
	for i = 1, 3 do
		p(model, tor, BLK, NEO, ORG, Vector3.new(s*0.52, s*0.06, s*0.05),
			CFrame.new(pos + Vector3.new(0, s*(0.02 + (i-1)*0.18), s*0.24)))
	end
	return tor
end

-- fraise_supreme (Epic): custom imported mesh (FraiseSkin)
builders["fraise_supreme"] = function(pos, model, s)
	return buildFromImportedMesh(pos, model, s, "FraiseSkin")
end

-- banane_doom (Epic): yellow elongated head, black visor, red slits, shoulder spikes
builders["banane_doom"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, YEL, BLK2)
	local hc  = pos + Vector3.new(0, s * 0.78, 0)
	local hs  = s * 0.74
	p(model, tor, B, SMP, YEL, Vector3.new(hs*1.5, hs*0.72, hs*0.72),
		CFrame.new(hc) * CFrame.Angles(0, 0, math.rad(20)))
	p(model, tor, BLK, NEO, BLK2, Vector3.new(hs*1.3, hs*0.2, s*0.05),
		CFrame.new(hc + Vector3.new(0, hs*0.06, hs*0.38)) * CFrame.Angles(0, 0, math.rad(20)))
	for _, side in ipairs({-1, 1}) do
		p(model, tor, BLK, NEO, RED, Vector3.new(hs*0.28, s*0.06, s*0.05),
			CFrame.new(hc + Vector3.new(side*hs*0.3, hs*0.06, hs*0.4))
				* CFrame.Angles(0, 0, math.rad(20)))
		for j = 1, 3 do
			p(model, tor, CYL, SMP, BLK2, Vector3.new(s*0.08, s*0.28, s*0.08),
				CFrame.new(pos + Vector3.new(side*s*0.5, s*(0.38 - (j-1)*0.16), 0))
					* CFrame.Angles(0, 0, math.rad(side * 65)))
		end
	end
	for i = 1, 2 do
		p(model, tor, BLK, NEO, RED, Vector3.new(s*0.54, s*0.06, s*0.05),
			CFrame.new(pos + Vector3.new(0, s*(0.08 + (i-1)*0.26), s*0.24)))
	end
	return tor
end

-- raisin_rainbow (Epic): purple sphere, 6 rainbow orbs, double halo
builders["raisin_rainbow"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, IND, IND)
	local hc  = pos + Vector3.new(0, s * 0.78, 0)
	local hs  = s * 0.74
	p(model, tor, B, SMP, IND, Vector3.new(hs, hs*0.88, hs), CFrame.new(hc))
	addEyes(tor, hc, hs * 0.88, model)
	local rbColors = {RED, ORG, YEL, LGRN, BLU, VIO}
	for i, col in ipairs(rbColors) do
		local a = math.rad((i-1) * 60)
		p(model, tor, B, NEO, col, Vector3.new(s*0.19, s*0.19, s*0.19),
			CFrame.new(hc + Vector3.new(math.cos(a)*hs*0.85, hs*0.1, math.sin(a)*hs*0.85)))
	end
	p(model, tor, CYL, NEO, YEL, Vector3.new(s*0.08, hs*1.2, hs*1.2),
		CFrame.new(hc + Vector3.new(0, hs*0.76, 0)) * CFrame.Angles(0, 0, math.rad(90)))
	p(model, tor, CYL, NEO, WHT, Vector3.new(s*0.08, hs*0.95, hs*0.95),
		CFrame.new(hc + Vector3.new(0, hs*0.76, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0.15)
	return tor
end

-- ananas_sigma (Epic): yellow sphere, dramatic spikes, Neon glasses, backwards cap, crossed arms
builders["ananas_sigma"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, YEL, BRN)
	local hc  = pos + Vector3.new(0, s * 0.78, 0)
	local hs  = s * 0.74
	p(model, tor, B, SMP, YEL, Vector3.new(hs, hs, hs), CFrame.new(hc))
	addEyes(tor, hc, hs, model)
	local sa = {0, 32, -32, 64, -64, 88, -88}
	for i, a in ipairs(sa) do
		p(model, tor, CYL, SMP, GRN, Vector3.new(s*0.12, s*0.62 - math.abs(a)*0.003*s, s*0.12),
			CFrame.new(hc + Vector3.new(0, hs*0.46 + s*0.24, 0)) * CFrame.Angles(0, 0, math.rad(a)))
	end
	for _, side in ipairs({-1, 1}) do
		p(model, tor, BLK, NEO, BLK2, Vector3.new(hs*0.3, hs*0.15, s*0.04),
			CFrame.new(hc + Vector3.new(side*hs*0.24, hs*0.1, hs*0.48)))
	end
	p(model, tor, CYL, SMP, DGRYA, Vector3.new(s*0.2, hs*1.05, hs*1.05),
		CFrame.new(hc + Vector3.new(0, hs*0.52, 0)) * CFrame.Angles(0, 0, math.rad(90)))
	p(model, tor, BLK, SMP, DGRYA, Vector3.new(s*0.15, hs*0.5, hs*0.2),
		CFrame.new(hc + Vector3.new(0, hs*0.52, -hs*0.6)))
	for _, side in ipairs({-1, 1}) do
		p(model, tor, BLK, SMP, YEL, Vector3.new(s*0.7, s*0.2, s*0.2),
			CFrame.new(pos + Vector3.new(0, s*0.24, s*0.24))
				* CFrame.Angles(0, 0, math.rad(side * 28)))
	end
	return tor
end

-- pasteque_plasma (Epic): Neon pink sphere, flying chunks, plasma orbs
builders["pasteque_plasma"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, GRN, DGRN)
	local hc  = pos + Vector3.new(0, s * 0.78, 0)
	local hs  = s * 0.74
	p(model, tor, B, NEO, PNK, Vector3.new(hs, hs, hs), CFrame.new(hc), 0.12)
	addEyes(tor, hc, hs, model)
	local chunkCols = {GRN, RED, GRN, RED, GRN, RED}
	for i, col in ipairs(chunkCols) do
		local a = math.rad((i-1) * 60)
		p(model, tor, BLK, SMP, col, Vector3.new(s*0.22, s*0.14, s*0.1),
			CFrame.new(hc + Vector3.new(math.cos(a)*hs*(0.86+i*0.04),
				math.sin(a)*hs*0.2 + hs*0.05, math.sin(a)*hs*0.86)))
	end
	for i = 1, 7 do
		local a = math.rad((i-1) * (360/7))
		p(model, tor, B, NEO, PNK, Vector3.new(s*0.15, s*0.15, s*0.15),
			CFrame.new(hc + Vector3.new(math.cos(a)*hs*1.08, hs*0.08, math.sin(a)*hs*1.08)))
	end
	return tor
end

-- mangue_cosmique (Legendary): Neon orange sphere, 8-spike crown, 6 gold orbs, cape
builders["mangue_cosmique"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, ORG, DORG)
	local hc  = pos + Vector3.new(0, s * 0.8, 0)
	local hs  = s * 0.76
	p(model, tor, B, NEO, ORG, Vector3.new(hs, hs, hs), CFrame.new(hc))
	addEyes(tor, hc, hs, model)
	for i = 1, 8 do
		local a = math.rad((i-1) * 45)
		p(model, tor, CYL, NEO, YEL, Vector3.new(s*0.1, s*0.52, s*0.1),
			CFrame.new(hc + Vector3.new(math.cos(a)*hs*0.42, hs*0.62, math.sin(a)*hs*0.42)))
	end
	for i = 1, 6 do
		local a = math.rad((i-1) * 60)
		p(model, tor, B, NEO, YEL, Vector3.new(s*0.22, s*0.22, s*0.22),
			CFrame.new(pos + Vector3.new(math.cos(a)*s*0.9, s*0.28, math.sin(a)*s*0.9)))
	end
	for i = 1, 2 do
		p(model, tor, BLK, NEO, ORG, Vector3.new(s*0.08, s*(0.9-i*0.15), s*(0.7-i*0.1)),
			CFrame.new(pos + Vector3.new(0, s*0.22, -(s*0.3 + i*s*0.12))), 0.3)
	end
	return tor
end

-- fraise_omega (Legendary): custom imported mesh (FraiseSkin)
builders["fraise_omega"] = function(pos, model, s)
	return buildFromImportedMesh(pos, model, s, "FraiseSkin")
end

-- banane_fantome (Legendary): semi-transparent ghost, wisps, tail chain, blue halo
builders["banane_fantome"] = function(pos, model, s)
	-- Ghost torso (built manually — transparent)
	local tor = Instance.new("Part")
	tor.Name         = "Body"
	tor.Shape        = BLK
	tor.Material     = NEO
	tor.BrickColor   = WHT
	tor.Transparency = 0.2
	tor.Size         = Vector3.new(s*0.72, s*0.9, s*0.45)
	tor.CFrame       = CFrame.new(pos)
	tor.Anchored     = true
	tor.CanCollide   = true
	tor.CastShadow   = true
	tor.Parent       = model
	model.PrimaryPart = tor

	local al = s * 0.75
	local at = s * 0.18
	for _, side in ipairs({-1, 1}) do
		p(model, tor, CYL, NEO, WHT, Vector3.new(al, at, at),
			CFrame.new(pos + Vector3.new(side*(s*0.36+al*0.5), s*0.22, 0))
				* CFrame.Angles(0, 0, math.rad(side*25)), 0.25)
	end

	local hc = pos + Vector3.new(0, s * 0.8, 0)
	local hs = s * 0.76
	p(model, tor, B, NEO, WHT, Vector3.new(hs*1.4, hs*0.72, hs*0.72),
		CFrame.new(hc) * CFrame.Angles(0, 0, math.rad(20)), 0.3)
	addEyes(tor, hc, hs * 0.72, model)

	local LBLU = BrickColor.new("Light blue")
	for i = 1, 7 do
		local a = math.rad((i-1) * (360/7))
		p(model, tor, B, NEO, LBLU, Vector3.new(s*0.15, s*0.15, s*0.15),
			CFrame.new(hc + Vector3.new(math.cos(a)*hs*(0.78+i*0.04),
				math.sin(a)*hs*0.3, math.sin(a+math.rad(30))*hs*0.5)), 0.4)
	end
	for i = 1, 6 do
		p(model, tor, B, NEO, WHT, Vector3.new(s*(0.38-i*0.04), s*(0.38-i*0.04), s*(0.38-i*0.04)),
			CFrame.new(pos + Vector3.new(math.sin(i*0.6)*s*0.2, -(s*0.45+i*s*0.3), 0)),
			0.2 + i * 0.08)
	end
	p(model, tor, CYL, NEO, LBLU, Vector3.new(s*0.08, hs*1.18, hs*1.18),
		CFrame.new(hc + Vector3.new(0, hs*0.72, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0.3)
	return tor
end

-- dragon_ultime (Legendary): deep orange Neon sphere, 7 spikes, dragon wings, fire arc, tail
builders["dragon_ultime"] = function(pos, model, s)
	local DEPO = BrickColor.new("Deep orange")
	local tor = buildBase(pos, model, s, DEPO, BLK2)
	local hc  = pos + Vector3.new(0, s * 0.8, 0)
	local hs  = s * 0.76
	p(model, tor, B, NEO, DEPO, Vector3.new(hs, hs, hs), CFrame.new(hc))
	addEyes(tor, hc, hs, model)
	for i = 1, 7 do
		local a = math.rad((i-1) * (360/7))
		p(model, tor, CYL, NEO, WHT, Vector3.new(s*0.12, s*0.7, s*0.12),
			CFrame.new(hc + Vector3.new(math.cos(a)*hs*0.44,
				hs*0.52 + math.abs(math.cos(a))*s*0.1, math.sin(a)*hs*0.44)))
	end
	for _, side in ipairs({-1, 1}) do
		for seg = 1, 3 do
			p(model, tor, BLK, NEO, RED, Vector3.new(s*0.07, s*(0.6-seg*0.1), s*(0.56-seg*0.12)),
				CFrame.new(pos + Vector3.new(side*s*(0.48+seg*0.28), s*(0.36-seg*0.08), -s*0.15))
					* CFrame.Angles(0, math.rad(side*12), math.rad(side*(22+seg*14))), 0.2)
		end
	end
	for i = 1, 7 do
		local t = (i-1) / 6
		local col = i <= 4 and ORG or YEL
		local sz = s * (0.2 - t*0.08)
		p(model, tor, B, NEO, col, Vector3.new(sz, sz, sz),
			CFrame.new(hc + Vector3.new((t-0.5)*hs*0.8, hs*(-0.1-t*0.5), hs*(0.5+t*0.6))))
	end
	for i = 1, 5 do
		local sz = s * (0.4 - i*0.05)
		p(model, tor, B, NEO, DEPO, Vector3.new(sz, sz, sz),
			CFrame.new(pos + Vector3.new(math.sin(i*0.7)*s*0.3, -(s*0.3+i*s*0.28), -(s*0.2+i*s*0.18))))
	end
	return tor
end

-- le_tentafruit (Legendary): purple Neon sphere, 8 tentacles, elaborate crown, chaos orbs
builders["le_tentafruit"] = function(pos, model, s)
	local tor = buildBase(pos, model, s, IND, IND)
	local hc  = pos + Vector3.new(0, s * 0.8, 0)
	local hs  = s * 0.76
	p(model, tor, B, NEO, VIO, Vector3.new(hs, hs, hs), CFrame.new(hc))
	addEyes(tor, hc, hs, model)

	-- 8 tentacles (each is 4 cylinder segments)
	for i = 1, 8 do
		local ba = math.rad((i-1) * 45)
		for seg = 1, 4 do
			local sw = math.sin(i * 1.3 + seg * 0.8) * 0.3
			local col = seg <= 2 and VIO or IND
			local segSz = s * (0.12 - seg * 0.018)
			p(model, tor, CYL, NEO, col, Vector3.new(segSz, s*0.32, segSz),
				CFrame.new(hc + Vector3.new(0, hs*0.44, 0) + Vector3.new(
					math.cos(ba)*s*(0.18+seg*0.16) + sw*s*0.1,
					s*0.28*seg,
					math.sin(ba)*s*(0.18+seg*0.16))))
		end
		-- glowing tip
		local sw = math.sin(i * 1.3 + 4 * 0.8) * 0.3
		p(model, tor, B, NEO, VIO, Vector3.new(s*0.14, s*0.14, s*0.14),
			CFrame.new(hc + Vector3.new(0, hs*0.44, 0) + Vector3.new(
				math.cos(ba)*s*(0.18+5*0.16) + sw*s*0.1,
				s*0.28*5,
				math.sin(ba)*s*(0.18+5*0.16))))
	end

	-- 4 crown rings
	for i = 1, 4 do
		local col = i % 2 == 0 and YEL or VIO
		p(model, tor, CYL, NEO, col, Vector3.new(s*0.08, hs*(1.28-i*0.1), hs*(1.28-i*0.1)),
			CFrame.new(hc + Vector3.new(0, hs*(0.68+i*0.06), 0))
				* CFrame.Angles(math.rad(i*20), 0, math.rad(90)), (i-1)*0.1)
	end

	-- 4 torso tentacle extensions
	for i = 1, 4 do
		local a = math.rad((i-1) * 90 + 45)
		p(model, tor, CYL, NEO, VIO, Vector3.new(s*0.1, s*0.5, s*0.1),
			CFrame.new(pos + Vector3.new(math.cos(a)*s*0.46, s*0.1, math.sin(a)*s*0.46))
				* CFrame.Angles(0, a, math.rad(80)))
	end

	-- 6 chaos orbs
	local chaosCols = {RED, ORG, YEL, LGRN, BLU, PNK}
	for i, col in ipairs(chaosCols) do
		local a = math.rad((i-1) * 60)
		p(model, tor, B, NEO, col, Vector3.new(s*0.2, s*0.2, s*0.2),
			CFrame.new(pos + Vector3.new(math.cos(a)*s*1.0, s*0.18, math.sin(a)*s*1.0)))
	end

	return tor
end

-- ============================================================
-- Generic fallback
-- ============================================================
function CharacterBuilders.generic(pos, model, s, skinData)
	local tor = buildBase(pos, model, s, skinData.color, skinData.color)
	local hc  = pos + Vector3.new(0, s * 0.76, 0)
	local hs  = s * 0.68
	p(model, tor, B, SMP, skinData.color, Vector3.new(hs, hs, hs), CFrame.new(hc))
	addEyes(tor, hc, hs, model)
	return tor
end

-- ============================================================
-- Dispatcher
-- ============================================================
-- baseCenter: Vector3 of the owning base's position (passed from spawnSkin).
-- Nil for belt/gacha preview skins which don't need facing.
function CharacterBuilders.build(skinId, position, model, s, skinData, baseCenter)
	local builder = builders[skinId]
	local torso
	if builder then
		torso = builder(position, model, s)
	else
		torso = CharacterBuilders.generic(position, model, s, skinData)
	end

	if torso and torso:IsA("BasePart") and baseCenter then
		-- Skins face toward their pressure plate (between skin and aisle at baseCenter.Z).
		-- Left slots (skin Z < base Z): plate in +Z direction.
		-- Right slots (skin Z > base Z): plate in -Z direction.
		local subModel = torso.Parent
		local isFBX = subModel and subModel:IsA("Model") and subModel:GetAttribute("_IsFBX")

		local faceAngle
		if isFBX then
			-- FBX models import facing -Z; flip them with π for left slots,
			-- leave at 0 for right slots (π would point them away from the plate).
			faceAngle = position.Z > baseCenter.Z and 0 or math.pi
			subModel:SetPrimaryPartCFrame(
				CFrame.new(torso.Position) * CFrame.Angles(0, faceAngle, 0)
			)
		else
			-- Procedural models face +Z by default; only right slots need a π flip.
			faceAngle = position.Z > baseCenter.Z and math.pi or 0
			if faceAngle ~= 0 then
				torso.CFrame = CFrame.new(torso.Position) * CFrame.Angles(0, faceAngle, 0)
			end
		end
	end

	return torso
end

return CharacterBuilders
