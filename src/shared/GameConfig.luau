-- Sunbloom Meadow: Flower Rush - shared tuning and rules.
-- One place for every number both sides of the game agree on, so the
-- server, the enemy spawner and the client never drift apart.

local GameConfig = {}

-- How long one whole run lasts, in seconds, across all three levels.
GameConfig.GAME_SECONDS = 90

-- Hearts a run starts with. A thorn or a sting costs one heart.
GameConfig.START_HEARTS = 3

-- Points for each kind of bloom.
GameConfig.SUNBLOOM_POINTS = 10
GameConfig.RAINBOW_POINTS = 50

-- Seconds a player cannot be hurt again after taking a hit.
GameConfig.HURT_COOLDOWN_SECONDS = 2

-- How many blooms of each kind stay alive in the meadow at once.
GameConfig.ALIVE_SUNBLOOMS = 10
GameConfig.ALIVE_RAINBOWS = 2

-- Live bloom sizes, in studs: big enough to spot across the meadow.
-- The old 2.4-stud balls were dots from the spawn view.
GameConfig.SUNBLOOM_SIZE = 4.2
GameConfig.RAINBOW_SIZE = 5.2
GameConfig.BLOOM_HEIGHT = 3.2

-- No bloom or enemy may spawn this close to the spawn pad, in studs:
-- the old code spawned anywhere, so an enemy could start on top of
-- the player and the first screen showed nothing nearby.
GameConfig.SPAWN_SAFE_RADIUS_STUDS = 22

-- An enemy only chases inside this range, in studs; farther away it
-- wanders, so the whole field no longer converges on the player.
GameConfig.ENEMY_CHASE_RANGE_STUDS = 30

-- How long after a picked bloom a fresh one grows back, in seconds.
GameConfig.BLOOM_REGROW_SECONDS = 3

-- The meadow floor the blooms may grow in, in studs from the centre.
GameConfig.MEADOW_HALF_SIZE = 65

-- One row per level: blooms to pick to clear it, how many of each enemy
-- hunts the player, and how fast each enemy moves, in studs per second.
-- Speeds are below the player's 16 studs/s walk, and level 1 is gentle:
-- the old level-1 slimes at 6 studs/s, homing forever, with no
-- knockback, could sit on the player and eat a heart every cooldown.
GameConfig.LEVELS = {
	{
		name = "Sunny Meadow",
		goalBlooms = 8,
		slimeCount = 2,
		beeCount = 0,
		slimeSpeed = 4,
		beeSpeed = 9,
		clockTime = 14,
	},
	{
		name = "Buzzing Field",
		goalBlooms = 10,
		slimeCount = 3,
		beeCount = 1,
		slimeSpeed = 5,
		beeSpeed = 10,
		clockTime = 15,
	},
	{
		name = "Dusk Garden",
		goalBlooms = 12,
		slimeCount = 3,
		beeCount = 2,
		slimeSpeed = 7,
		beeSpeed = 12,
		clockTime = 17.5,
	},
}

-- Palette of the meadow, as RGB triples the world and the HUD share.
GameConfig.PALETTE = {
	grass = { 86, 178, 76 },
	sky = { 135, 206, 235 },
	sunbloom = { 255, 200, 40 },
	rainbow = { 255, 80, 200 },
	slime = { 46, 125, 50 },
	bee = { 255, 210, 30 },
	heart = { 235, 60, 90 },
	cream = { 255, 248, 220 },
	leaf = { 60, 160, 70 },
}

-- Names of the remotes the server creates for the client to use.
GameConfig.REMOTE_ACTION = "SunbloomAction"
GameConfig.REMOTE_STATE = "SunbloomState"
GameConfig.REMOTE_FLASH = "SunbloomFlash"

return GameConfig
