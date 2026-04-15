-- GameConfig.lua
-- ModuleScript: Global configuration constants for Skibidi Tentafruit Heist

return {
	-- Base size of each player's home base plot (studs).
	BASE_SIZE = 50,

	-- How often the server awards income to each player (seconds).
	INCOME_INTERVAL = 1,

	-- How long a placed lock shield lasts at its base duration (seconds).
	LOCK_SHIELD_DURATION = 15,

	-- Cooldown before a player can place another lock shield (seconds).
	LOCK_COOLDOWN = 30,

	-- Cost in money for a single gacha spin.
	GACHA_COST = 1500,

	-- Total money required to trigger a rebirth.
	REBIRTH_COST = 5000,

	-- Income multiplier gained per rebirth (stacks multiplicatively).
	REBIRTH_MULTIPLIER = 1.5,

	-- Maximum number of rebirths a player can perform.
	MAX_REBIRTHS = 10,

	-- Height above the player's head at which a carried skin floats (studs).
	CARRY_DROP_HEIGHT = 5.5,

	-- Minimum seconds between bat swing actions.
	BAT_COOLDOWN = 1.5,

	-- Money a new player starts with.
	STARTER_MONEY = 1000,

	-- Seconds between each income tick.
	INCOME_TICK = 1,

	-- Z position of the conveyor belt in the world (center road).
	CONVEYOR_BELT_Z = 0,

	-- Z position of the items shop in the world (center road, offset along Z).
	ITEMS_SHOP_Z = 0,

	-- Number of skin slots on each side of the aisle per floor
	FLOOR_SLOT_SIDE_COUNT = 5,   -- 5 left + 5 right = 10 per floor

	-- Max number of house floors a player can unlock
	MAX_FLOORS = 5,

	-- How many rebirths are needed to unlock each floor (floor index = position in array)
	-- Floor 1 is always unlocked. Floor 2 needs 1 rebirth, etc.
	FLOOR_UNLOCK_REBIRTHS = {0, 1, 2, 4, 6},

	-- Height in studs between floor levels (ceiling clearance + floor thickness)
	FLOOR_HEIGHT_STEP = 12,

	-- Building dimensions inside the house plot
	BUILDING_DEPTH = 40,   -- along the axis facing the road (X for left/right houses)
	BUILDING_WIDTH = 34,   -- along the Z axis

	-- Yard depth (space between building front and plot edge facing road)
	YARD_DEPTH = 14,

	-- Eight player house plots arranged in two rows of four facing each other
	-- across a central road. Left row at X=-75, right row at X=+75.
	-- All plots face the center (front/open side toward X=0).
	BASE_POSITIONS = {
		-- Left row (X = -75)
		Vector3.new(-75, 0.5, -90),
		Vector3.new(-75, 0.5, -30),
		Vector3.new(-75, 0.5,  30),
		Vector3.new(-75, 0.5,  90),
		-- Right row (X = +75)
		Vector3.new( 75, 0.5, -90),
		Vector3.new( 75, 0.5, -30),
		Vector3.new( 75, 0.5,  30),
		Vector3.new( 75, 0.5,  90),
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
