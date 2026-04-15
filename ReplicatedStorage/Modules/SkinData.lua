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
		description = "Tiny strawberry kid with seed freckles. Always crying for no reason.",
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
		description = "Tall bendy banana dude. Slips on himself constantly.",
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
		description = "Citrus queen with glowing skin. Smells amazing, fights dirty.",
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
		description = "Shriveled grape man. Claims to be the main character.",
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
		description = "Cannot decide if fruit or vegetable. Identity crisis daily.",
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
		description = "Tropical mango diva. Too juicy for this world.",
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
		description = "Spiky pineapple warrior. Crown made of actual leaves.",
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
		description = "Twin cherry siblings always attached. Never separated.",
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
		description = "Green outside, red inside. Full of seeds and bad decisions.",
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
		description = "Lime girl. Extremely sour personality. Iconic.",
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
		description = "Hazelnut royalty. Crunchy on the outside, surprisingly soft inside.",
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
		description = "Tiny blueberry with big attitude. Leaves purple stains everywhere.",
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
		description = "Avocado influencer. Costs too much. Worth it.",
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
		description = "Pink and white spotted legend. Mysterious origin.",
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
		description = "Fuzzy brown outside, electric green inside. Silent but deadly.",
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
		description = "Ancient fig sage. Speaks only in riddles.",
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
		description = "Exotic papaya warrior. Tropical origin, global impact.",
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
		description = "Final form strawberry. Seeds turned into diamonds.",
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
		description = "Ultra-curved chaos. Classified as a weapon in 12 countries.",
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
		description = "Rainbow grape divinity. Changes color with mood.",
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
		description = "Sigma pineapple grindset. Does not explain himself.",
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
		description = "Exploded watermelon reformed as plasma being.",
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
		description = "Forged in a tropical star. Smells like the universe.",
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
		description = "The first strawberry. The last strawberry. Eternal.",
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
		description = "Ghost banana. Passed away but refuses to leave.",
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
		description = "Dragon fruit that achieved sentience and vengeance.",
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
		description = "The original. The one who started it all. Unmatchable.",
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
