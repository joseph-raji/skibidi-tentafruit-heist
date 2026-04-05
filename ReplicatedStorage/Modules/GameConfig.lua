-- GameConfig.lua
-- ModuleScript: Global configuration constants for Skibidi Tentafruit Heist

return {
	-- Base size of each player's home base plot (studs).
	BASE_SIZE = 44,

	-- How often the server awards income to each player (seconds).
	INCOME_INTERVAL = 1,

	-- How long a placed lock shield lasts at its base duration (seconds).
	LOCK_SHIELD_DURATION = 15,

	-- Cooldown before a player can place another lock shield (seconds).
	LOCK_COOLDOWN = 30,

	-- Cost in money for a single gacha spin.
	GACHA_COST = 150,

	-- Total money required to trigger a rebirth.
	REBIRTH_COST = 8000,

	-- Income multiplier gained per rebirth (stacks multiplicatively).
	REBIRTH_MULTIPLIER = 1.5,

	-- Maximum number of rebirths a player can perform.
	MAX_REBIRTHS = 10,

	-- Height above the player's head at which a carried brainrot floats (studs).
	CARRY_DROP_HEIGHT = 5.5,

	-- Minimum seconds between bat swing actions.
	BAT_COOLDOWN = 1.5,

	-- Money a new player starts with.
	STARTER_MONEY = 50,

	-- Maximum number of brainrots a player can own on their base.
	MAX_BRAINROTS_PER_BASE = 20,

	-- Seconds between each income tick.
	INCOME_TICK = 1,

	-- Z position of the conveyor belt in the world.
	CONVEYOR_BELT_Z = 0,

	-- Z position of the items shop in the world.
	ITEMS_SHOP_Z = -60,

	-- Eight spawn positions evenly distributed around the central shop area.
	BASE_POSITIONS = {
		Vector3.new(-90,  0.5, -90),
		Vector3.new( 90,  0.5, -90),
		Vector3.new(-90,  0.5,  90),
		Vector3.new( 90,  0.5,  90),
		Vector3.new(  0,  0.5, -130),
		Vector3.new(  0,  0.5,  130),
		Vector3.new(-130, 0.5,   0),
		Vector3.new( 130, 0.5,   0),
	},

	-- UI and model tint colors keyed by rarity name.
	RARITY_COLORS = {
		Common    = Color3.fromRGB(180, 180, 180),
		Uncommon  = Color3.fromRGB(0,   200,  80),
		Rare      = Color3.fromRGB(0,   120, 255),
		Epic      = Color3.fromRGB(160,   0, 255),
		Legendary = Color3.fromRGB(255, 170,   0),
	},

	-- Canonical ordering of rarity tiers from lowest to highest.
	RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" },
}
