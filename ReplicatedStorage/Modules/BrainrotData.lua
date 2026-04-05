-- BrainrotData.lua
-- ModuleScript: All brainrot definitions for Skibidi Tentafruit Heist
-- 25 brainrots across 5 rarity tiers (5 per tier)

local BrainrotData = {}

BrainrotData.list = {

	-- =====================================================================
	-- COMMON (5) — income ~5, cost direct, dropWeight 50, size 3
	-- =====================================================================

	{
		id          = "skibidi_toilet_jr",
		name        = "Skibidi Toilet Jr",
		rarity      = "Common",
		income      = 5,
		cost        = 100,
		color       = BrickColor.new("Medium stone grey"),
		glowColor   = Color3.fromRGB(160, 160, 160),
		size        = 3,
		description = "A tiny toilet head that won't stop humming the skibidi song at full volume in your ear.",
		dropWeight  = 50,
	},

	{
		id          = "tentafruit_seedling",
		name        = "Tentafruit Seedling",
		rarity      = "Common",
		income      = 5,
		cost        = 100,
		color       = BrickColor.new("Bright blue"),
		glowColor   = Color3.fromRGB(80, 130, 255),
		size        = 3,
		description = "A baby tentafruit that wiggles its two sad little tendrils and occasionally spits seeds at you.",
		dropWeight  = 50,
	},

	{
		id          = "mini_cameraman",
		name        = "Mini Cameraman",
		rarity      = "Common",
		income      = 6,
		cost        = 110,
		color       = BrickColor.new("Sand blue"),
		glowColor   = Color3.fromRGB(100, 140, 200),
		size        = 3,
		description = "Records everything but the lens cap is still on and he refuses to acknowledge this.",
		dropWeight  = 50,
	},

	{
		id          = "baby_speakerman",
		name        = "Baby Speakerman",
		rarity      = "Common",
		income      = 5,
		cost        = 100,
		color       = BrickColor.new("Light bluish gray"),
		glowColor   = Color3.fromRGB(140, 155, 175),
		size        = 3,
		description = "Blasts nursery rhymes at 120 decibels whether you want it to or not.",
		dropWeight  = 50,
	},

	{
		id          = "pixel_tv_head",
		name        = "Pixel TV Head",
		rarity      = "Common",
		income      = 5,
		cost        = 100,
		color       = BrickColor.new("Pastel Blue"),
		glowColor   = Color3.fromRGB(130, 190, 220),
		size        = 3,
		description = "Only gets one channel: static, and it seems very happy about that.",
		dropWeight  = 50,
	},

	-- =====================================================================
	-- UNCOMMON (5) — income ~15, cost direct, dropWeight 25, size 3.5
	-- =====================================================================

	{
		id          = "tentafruit_plus",
		name        = "Tentafruit Plus",
		rarity      = "Uncommon",
		income      = 15,
		cost        = 350,
		color       = BrickColor.new("Bright green"),
		glowColor   = Color3.fromRGB(0, 210, 60),
		size        = 3.5,
		description = "Upgraded with two extra tendrils that it uses exclusively to juggle cheese.",
		dropWeight  = 25,
	},

	{
		id          = "skibidi_deluxe",
		name        = "Skibidi Deluxe",
		rarity      = "Uncommon",
		income      = 14,
		cost        = 330,
		color       = BrickColor.new("Medium green"),
		glowColor   = Color3.fromRGB(50, 200, 100),
		size        = 3.5,
		description = "A toilet head with a little top hat that makes it feel 40% more prestigious than it is.",
		dropWeight  = 25,
	},

	{
		id          = "cameraman_pro",
		name        = "Cameraman Pro",
		rarity      = "Uncommon",
		income      = 16,
		cost        = 370,
		color       = BrickColor.new("Sand green"),
		glowColor   = Color3.fromRGB(80, 180, 80),
		size        = 3.5,
		description = "Has a slightly better lens cap situation — it is now taped to the side of his head.",
		dropWeight  = 25,
	},

	{
		id          = "speaker_bro",
		name        = "Speaker Bro",
		rarity      = "Uncommon",
		income      = 15,
		cost        = 350,
		color       = BrickColor.new("Bright yellowish green"),
		glowColor   = Color3.fromRGB(120, 210, 40),
		size        = 3.5,
		description = "Refers to everyone as bro and his speaker grille is permanently set to dubstep.",
		dropWeight  = 25,
	},

	{
		id          = "dual_screen",
		name        = "Dual Screen",
		rarity      = "Uncommon",
		income      = 15,
		cost        = 350,
		color       = BrickColor.new("Olive green"),
		glowColor   = Color3.fromRGB(140, 200, 50),
		size        = 3.5,
		description = "Two TV heads fused together, both showing different episodes of Skibidi Toilet and neither synced.",
		dropWeight  = 25,
	},

	-- =====================================================================
	-- RARE (5) — income ~40, cost nil (gacha-only), dropWeight 12, size 4
	-- =====================================================================

	{
		id          = "mega_skibidi",
		name        = "Mega Skibidi",
		rarity      = "Rare",
		income      = 40,
		cost        = nil,
		color       = BrickColor.new("Bright blue"),
		glowColor   = Color3.fromRGB(0, 160, 255),
		size        = 4,
		description = "A toilet the size of a vending machine that can only be silenced by flushing it exactly three times.",
		dropWeight  = 12,
	},

	{
		id          = "mutant_tentafruit",
		name        = "Mutant Tentafruit",
		rarity      = "Rare",
		income      = 42,
		cost        = nil,
		color       = BrickColor.new("Cyan"),
		glowColor   = Color3.fromRGB(0, 220, 220),
		size        = 4,
		description = "Grew six tendrils overnight and is now attempting to open a small restaurant.",
		dropWeight  = 12,
	},

	{
		id          = "elite_cameraman",
		name        = "Elite Cameraman",
		rarity      = "Rare",
		income      = 40,
		cost        = nil,
		color       = BrickColor.new("Dark blue"),
		glowColor   = Color3.fromRGB(30, 100, 255),
		size        = 4,
		description = "His footage is stunning but he insists on shooting everything in portrait mode.",
		dropWeight  = 12,
	},

	{
		id          = "bass_speakerman",
		name        = "Bass Speakerman",
		rarity      = "Rare",
		income      = 38,
		cost        = nil,
		color       = BrickColor.new("Medium blue"),
		glowColor   = Color3.fromRGB(60, 80, 255),
		size        = 4,
		description = "His bass is so deep it has caused three nearby buildings to gently relocate themselves.",
		dropWeight  = 12,
	},

	{
		id          = "tri_screen",
		name        = "Tri-Screen",
		rarity      = "Rare",
		income      = 40,
		cost        = nil,
		color       = BrickColor.new("Bright bluish green"),
		glowColor   = Color3.fromRGB(0, 200, 200),
		size        = 4,
		description = "Three screens, three dimensions, zero useful information displayed on any of them.",
		dropWeight  = 12,
	},

	-- =====================================================================
	-- EPIC (5) — income ~100, cost nil (gacha-only), dropWeight 5, size 4.5
	-- =====================================================================

	{
		id          = "supreme_skibidi",
		name        = "Supreme Skibidi",
		rarity      = "Epic",
		income      = 100,
		cost        = nil,
		color       = BrickColor.new("Bright violet"),
		glowColor   = Color3.fromRGB(160, 0, 255),
		size        = 4.5,
		description = "Wears a golden toilet seat as a crown and demands to be addressed as Your Porcelain Majesty.",
		dropWeight  = 5,
	},

	{
		id          = "rainbow_tentafruit",
		name        = "Rainbow Tentafruit",
		rarity      = "Epic",
		income      = 105,
		cost        = nil,
		color       = BrickColor.new("Medium lilac"),
		glowColor   = Color3.fromRGB(200, 50, 255),
		size        = 4.5,
		description = "Cycles through all visible colors every 0.4 seconds, which is medically inadvisable to stare at.",
		dropWeight  = 5,
	},

	{
		id          = "shadow_cam",
		name        = "Shadow Cam",
		rarity      = "Epic",
		income      = 98,
		cost        = nil,
		color       = BrickColor.new("Dark indigo"),
		glowColor   = Color3.fromRGB(120, 0, 220),
		size        = 4.5,
		description = "Exists partially in another dimension, which makes his footage unusable but extremely haunting.",
		dropWeight  = 5,
	},

	{
		id          = "doom_speaker",
		name        = "Doom Speaker",
		rarity      = "Epic",
		income      = 100,
		cost        = nil,
		color       = BrickColor.new("Lavender"),
		glowColor   = Color3.fromRGB(180, 20, 240),
		size        = 4.5,
		description = "Plays the Italian Brainrot theme at frequencies that cause nearby fruit to spontaneously combust.",
		dropWeight  = 5,
	},

	{
		id          = "plasma_tv",
		name        = "Plasma TV",
		rarity      = "Epic",
		income      = 102,
		cost        = nil,
		color       = BrickColor.new("Purple"),
		glowColor   = Color3.fromRGB(140, 0, 255),
		size        = 4.5,
		description = "A plasma display head that visibly phases through solid objects when it gets excited.",
		dropWeight  = 5,
	},

	-- =====================================================================
	-- LEGENDARY (5) — income ~280, cost nil (gacha-only), dropWeight 1, size 5
	-- =====================================================================

	{
		id          = "god_skibidi_omega",
		name        = "GOD Skibidi Omega",
		rarity      = "Legendary",
		income      = 280,
		cost        = nil,
		color       = BrickColor.new("Bright yellow"),
		glowColor   = Color3.fromRGB(255, 200, 0),
		size        = 5,
		description = "The original toilet deity — his flush echoes across all dimensions simultaneously.",
		dropWeight  = 1,
	},

	{
		id          = "cosmic_tentafruit",
		name        = "Cosmic Tentafruit",
		rarity      = "Legendary",
		income      = 290,
		cost        = nil,
		color       = BrickColor.new("Neon orange"),
		glowColor   = Color3.fromRGB(255, 120, 0),
		size        = 5,
		description = "Born from a dying star and tastes like Italian dressing — its tendrils span entire solar systems.",
		dropWeight  = 1,
	},

	{
		id          = "phantom_cameraman",
		name        = "Phantom Cameraman",
		rarity      = "Legendary",
		income      = 275,
		cost        = nil,
		color       = BrickColor.new("Bright red"),
		glowColor   = Color3.fromRGB(255, 40, 0),
		size        = 5,
		description = "Invisible to the naked eye yet somehow his footage wins every film festival he enters.",
		dropWeight  = 1,
	},

	{
		id          = "echo_speakerman",
		name        = "Echo Speakerman",
		rarity      = "Legendary",
		income      = 285,
		cost        = nil,
		color       = BrickColor.new("Neon orange"),
		glowColor   = Color3.fromRGB(255, 170, 0),
		size        = 5,
		description = "Every sound he makes echoes across 47 parallel universes, each one playing a slightly different banger.",
		dropWeight  = 1,
	},

	{
		id          = "sigma_tv",
		name        = "SIGMA TV",
		rarity      = "Legendary",
		income      = 280,
		cost        = nil,
		color       = BrickColor.new("Gold"),
		glowColor   = Color3.fromRGB(255, 210, 30),
		size        = 5,
		description = "Broadcasts the truth of the universe 24/7 on Channel Sigma — unfortunately no one has the right antenna.",
		dropWeight  = 1,
	},
}

-- =========================================================================
-- Helper functions
-- =========================================================================

-- Returns the brainrot entry matching the given id, or nil if not found.
function BrainrotData.getById(id)
	for _, entry in ipairs(BrainrotData.list) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- Returns a list of all brainrot entries with the given rarity string.
function BrainrotData.getByRarity(rarity)
	local results = {}
	for _, entry in ipairs(BrainrotData.list) do
		if entry.rarity == rarity then
			table.insert(results, entry)
		end
	end
	return results
end

-- Performs a weighted gacha roll and returns one brainrot entry.
-- Uses each entry's dropWeight field to build a cumulative distribution.
function BrainrotData.gachaRoll()
	local totalWeight = 0
	for _, entry in ipairs(BrainrotData.list) do
		totalWeight = totalWeight + entry.dropWeight
	end

	local roll = math.random(1, totalWeight)
	local cumulative = 0
	for _, entry in ipairs(BrainrotData.list) do
		cumulative = cumulative + entry.dropWeight
		if roll <= cumulative then
			return entry
		end
	end

	-- Fallback: return the last entry (should never be reached)
	return BrainrotData.list[#BrainrotData.list]
end

return BrainrotData
