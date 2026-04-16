-- SkinData.lua
-- ModuleScript: All skin definitions for Skibidi Tentafruit Heist
-- 25 fruit anthropomorph characters across 5 rarity tiers (5 per tier)

local SkinData = {}

SkinData.list = {

	-- =====================================================================
	-- COMMON (5) — income 50-80/s, cost 500-800, dropWeight 50, size 3
	-- =====================================================================

	{
		id          = "fraise_jr",
		name        = "Fraise Jr",
		rarity      = "Common",
		income      = 50,
		cost        = 500,
		color       = BrickColor.new("Bright red"),
		glowColor   = Color3.fromRGB(255, 50, 80),
		size        = 3,
		description = "Petit gamin fraise avec des graines en taches de rousseur. Pleure tout le temps sans raison.",
		dropWeight  = 50,
	},

	{
		id          = "banane_bro",
		name        = "Banane Bro",
		rarity      = "Common",
		income      = 60,
		cost        = 600,
		color       = BrickColor.new("Bright yellow"),
		glowColor   = Color3.fromRGB(255, 220, 0),
		size        = 3,
		description = "Grand mec banane tout tordu. Glisse sur lui-même en permanence.",
		dropWeight  = 50,
	},

	{
		id          = "orange_girl",
		name        = "Orange Girl",
		rarity      = "Common",
		income      = 70,
		cost        = 700,
		color       = BrickColor.new("Bright orange"),
		glowColor   = Color3.fromRGB(255, 140, 0),
		size        = 3,
		description = "Reine des agrumes à la peau lumineuse. Sent divinement bon, se bat comme une sale.",
		dropWeight  = 50,
	},

	{
		id          = "raisin_guy",
		name        = "Raisin Guy",
		rarity      = "Common",
		income      = 60,
		cost        = 600,
		color       = BrickColor.new("Bright violet"),
		glowColor   = Color3.fromRGB(120, 0, 200),
		size        = 3,
		description = "Bonhomme raisin tout ratatiné. Convaincu d'être le personnage principal.",
		dropWeight  = 50,
	},

	{
		id          = "tomate_basic",
		name        = "Tomate Basic",
		rarity      = "Common",
		income      = 80,
		cost        = 800,
		color       = BrickColor.new("Bright red"),
		glowColor   = Color3.fromRGB(200, 30, 30),
		size        = 3,
		description = "Incapable de décider si c'est un fruit ou un légume. Crise d'identité quotidienne.",
		dropWeight  = 50,
	},

	-- =====================================================================
	-- UNCOMMON (5) — income 150-200/s, cost 1500-2000, dropWeight 25, size 3.5
	-- =====================================================================

	{
		id          = "mangue_queen",
		name        = "Mangue Queen",
		rarity      = "Uncommon",
		income      = 180,
		cost        = 1800,
		color       = BrickColor.new("Neon orange"),
		glowColor   = Color3.fromRGB(255, 160, 0),
		size        = 3.5,
		description = "Diva mangue tropicale. Trop juteuse pour ce monde.",
		dropWeight  = 25,
	},

	{
		id          = "ananas_king",
		name        = "Ananas King",
		rarity      = "Uncommon",
		income      = 150,
		cost        = 1500,
		color       = BrickColor.new("Bright yellow"),
		glowColor   = Color3.fromRGB(255, 200, 50),
		size        = 3.5,
		description = "Guerrier ananas hérissé. Couronne faite de vraies feuilles.",
		dropWeight  = 25,
	},

	{
		id          = "cerise_duo",
		name        = "Cerise Duo",
		rarity      = "Uncommon",
		income      = 200,
		cost        = 2000,
		color       = BrickColor.new("Crimson"),
		glowColor   = Color3.fromRGB(200, 0, 50),
		size        = 3.5,
		description = "Jumeaux cerises toujours collés l'un à l'autre. Jamais séparés.",
		dropWeight  = 25,
	},

	{
		id          = "pasteque_bro",
		name        = "Pastèque Bro",
		rarity      = "Uncommon",
		income      = 170,
		cost        = 1700,
		color       = BrickColor.new("Bright green"),
		glowColor   = Color3.fromRGB(0, 200, 80),
		size        = 3.5,
		description = "Vert à l'extérieur, rouge à l'intérieur. Plein de graines et de mauvaises décisions.",
		dropWeight  = 25,
	},

	{
		id          = "citron_vert",
		name        = "Citron Vert",
		rarity      = "Uncommon",
		income      = 160,
		cost        = 1600,
		color       = BrickColor.new("Bright green"),
		glowColor   = Color3.fromRGB(100, 255, 50),
		size        = 3.5,
		description = "Fille citron vert. Personnalité extrêmement acide. Iconique.",
		dropWeight  = 25,
	},

	{
		id          = "noisette_king",
		name        = "Noisette King",
		rarity      = "Uncommon",
		income      = 165,
		cost        = 1650,
		color       = BrickColor.new("Brown"),
		glowColor   = Color3.fromRGB(180, 110, 30),
		size        = 3.5,
		description = "Royauté noisette. Croustillant à l'extérieur, étonnamment doux à l'intérieur.",
		dropWeight  = 25,
	},

	{
		id          = "myrtille_babe",
		name        = "Myrtille Babe",
		rarity      = "Uncommon",
		income      = 175,
		cost        = 1750,
		color       = BrickColor.new("Dark indigo"),
		glowColor   = Color3.fromRGB(100, 0, 220),
		size        = 3.5,
		description = "Petite myrtille avec une grande attitude. Laisse des taches violettes partout.",
		dropWeight  = 25,
	},

	{
		id          = "poire_belle",
		name        = "Poire Belle",
		rarity      = "Uncommon",
		income      = 155,
		cost        = 1550,
		color       = BrickColor.new("Lime green"),
		glowColor   = Color3.fromRGB(180, 230, 80),
		size        = 3.5,
		description = "Duchesse poire élégante. Des coudes étonnamment tranchants.",
		dropWeight  = 25,
	},

	-- =====================================================================
	-- RARE (5) — income 400-500/s, cost nil (gacha-only), dropWeight 12, size 4
	-- =====================================================================

	{
		id          = "avocat_elite",
		name        = "Avocat Elite",
		rarity      = "Rare",
		income      = 430,
		cost        = nil,
		color       = BrickColor.new("Earth green"),
		glowColor   = Color3.fromRGB(80, 160, 60),
		size        = 4,
		description = "Avocat influenceur. Coûte trop cher. Ça vaut le coup.",
		dropWeight  = 12,
	},

	{
		id          = "dragon_fruit",
		name        = "Dragon Fruit",
		rarity      = "Rare",
		income      = 480,
		cost        = nil,
		color       = BrickColor.new("Hot pink"),
		glowColor   = Color3.fromRGB(255, 0, 150),
		size        = 4,
		description = "Légende rose et blanche tachetée. Origine mystérieuse.",
		dropWeight  = 12,
	},

	{
		id          = "kiwi_shadow",
		name        = "Kiwi Shadow",
		rarity      = "Rare",
		income      = 400,
		cost        = nil,
		color       = BrickColor.new("Dark green"),
		glowColor   = Color3.fromRGB(60, 120, 40),
		size        = 4,
		description = "Poilu et marron dehors, vert électrique dedans. Silencieux mais redoutable.",
		dropWeight  = 12,
	},

	{
		id          = "figue_mystique",
		name        = "Figue Mystique",
		rarity      = "Rare",
		income      = 450,
		cost        = nil,
		color       = BrickColor.new("Dark purple"),
		glowColor   = Color3.fromRGB(100, 0, 150),
		size        = 4,
		description = "Sage figue antique. Ne parle qu'en énigmes.",
		dropWeight  = 12,
	},

	{
		id          = "papaye_pro",
		name        = "Papaye Pro",
		rarity      = "Rare",
		income      = 500,
		cost        = nil,
		color       = BrickColor.new("Neon orange"),
		glowColor   = Color3.fromRGB(255, 100, 50),
		size        = 4,
		description = "Guerrier papaye exotique. Origine tropicale, impact mondial.",
		dropWeight  = 12,
	},

	-- =====================================================================
	-- EPIC (5) — income 1000-1200/s, cost nil (gacha-only), dropWeight 5, size 4.5
	-- =====================================================================

	{
		id          = "fraise_supreme",
		name        = "Fraise Suprême",
		rarity      = "Epic",
		income      = 1000,
		cost        = nil,
		color       = BrickColor.new("Bright red"),
		glowColor   = Color3.fromRGB(255, 0, 60),
		size        = 4.5,
		description = "Fraise en forme finale. Ses graines sont devenues des diamants.",
		dropWeight  = 5,
	},

	{
		id          = "banane_doom",
		name        = "Banane Doom",
		rarity      = "Epic",
		income      = 1150,
		cost        = nil,
		color       = BrickColor.new("Bright yellow"),
		glowColor   = Color3.fromRGB(255, 255, 0),
		size        = 4.5,
		description = "Chaos ultra-courbé. Classé comme arme dans 12 pays.",
		dropWeight  = 5,
	},

	{
		id          = "raisin_rainbow",
		name        = "Raisin Rainbow",
		rarity      = "Epic",
		income      = 1050,
		cost        = nil,
		color       = BrickColor.new("Royal purple"),
		glowColor   = Color3.fromRGB(200, 0, 255),
		size        = 4.5,
		description = "Divinité raisin arc-en-ciel. Change de couleur selon l'humeur.",
		dropWeight  = 5,
	},

	{
		id          = "ananas_sigma",
		name        = "Ananas Sigma",
		rarity      = "Epic",
		income      = 1100,
		cost        = nil,
		color       = BrickColor.new("Bright orange"),
		glowColor   = Color3.fromRGB(255, 180, 0),
		size        = 4.5,
		description = "Mentalité sigma ananas. Ne s'explique jamais.",
		dropWeight  = 5,
	},

	{
		id          = "pasteque_plasma",
		name        = "Pastèque Plasma",
		rarity      = "Epic",
		income      = 1200,
		cost        = nil,
		color       = BrickColor.new("Hot pink"),
		glowColor   = Color3.fromRGB(255, 50, 100),
		size        = 4.5,
		description = "Pastèque explosée reformée en être de plasma.",
		dropWeight  = 5,
	},

	-- =====================================================================
	-- LEGENDARY (5) — income 2800-3200/s, cost nil (gacha-only), dropWeight 1, size 5
	-- =====================================================================

	{
		id          = "mangue_cosmique",
		name        = "Mangue Cosmique",
		rarity      = "Legendary",
		income      = 2950,
		cost        = nil,
		color       = BrickColor.new("Neon orange"),
		glowColor   = Color3.fromRGB(255, 140, 0),
		size        = 5,
		description = "Forgée dans une étoile tropicale. Sent comme l'univers.",
		dropWeight  = 1,
	},

	{
		id          = "fraise_omega",
		name        = "Fraise Oméga",
		rarity      = "Legendary",
		income      = 3100,
		cost        = nil,
		color       = BrickColor.new("Hot pink"),
		glowColor   = Color3.fromRGB(255, 0, 100),
		size        = 5,
		description = "La première fraise. La dernière fraise. Éternelle.",
		dropWeight  = 1,
	},

	{
		id          = "banane_fantome",
		name        = "Banane Fantôme",
		rarity      = "Legendary",
		income      = 2800,
		cost        = nil,
		color       = BrickColor.new("White"),
		glowColor   = Color3.fromRGB(200, 200, 255),
		size        = 5,
		description = "Banane fantôme. Décédée mais refuse de partir.",
		dropWeight  = 1,
	},

	{
		id          = "dragon_ultime",
		name        = "Dragon Ultime",
		rarity      = "Legendary",
		income      = 3000,
		cost        = nil,
		color       = BrickColor.new("Deep orange"),
		glowColor   = Color3.fromRGB(255, 50, 0),
		size        = 5,
		description = "Fruit du dragon qui a atteint la conscience et la vengeance.",
		dropWeight  = 1,
	},

	{
		id          = "le_tentafruit",
		name        = "LE TENTAFRUIT",
		rarity      = "Legendary",
		income      = 3200,
		cost        = nil,
		color       = BrickColor.new("Royal purple"),
		glowColor   = Color3.fromRGB(150, 0, 255),
		size        = 5,
		description = "L'original. Celui qui a tout déclenché. Inégalable.",
		dropWeight  = 1,
	},
}

-- =========================================================================
-- Helper functions
-- =========================================================================

-- Returns the skin entry matching the given id, or nil if not found.
function SkinData.getById(id)
	for _, entry in ipairs(SkinData.list) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- Returns a list of all skin entries with the given rarity string.
function SkinData.getByRarity(rarity)
	local result = {}
	for _, entry in ipairs(SkinData.list) do
		if entry.rarity == rarity then
			table.insert(result, entry)
		end
	end
	return result
end

-- Performs a weighted gacha roll and returns one skin entry.
-- Uses each entry's dropWeight field to build a cumulative distribution.
function SkinData.gachaRoll()
	local totalWeight = 0
	for _, entry in ipairs(SkinData.list) do
		totalWeight = totalWeight + entry.dropWeight
	end

	local roll = math.random(1, totalWeight)
	local cumulative = 0
	for _, entry in ipairs(SkinData.list) do
		cumulative = cumulative + entry.dropWeight
		if roll <= cumulative then
			return entry
		end
	end

	-- Fallback: return the last entry (should never be reached)
	return SkinData.list[#SkinData.list]
end

-- Returns all skin entries.
function SkinData.getAll()
	return SkinData.list
end

return SkinData
