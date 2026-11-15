-- Sunbloom Meadow: Flower Rush - the one place the run's state lives.
-- The server and the enemy spawner both require this module, so they share
-- the same score, hearts, timer and level instead of each keeping a copy.

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))

local GameState = {}

-- Phases: "Lobby" before Play, "Playing" during a run, "Won" and "Lost".
local state = {
	phase = "Lobby",
	score = 0,
	hearts = GameConfig.START_HEARTS,
	timeLeft = GameConfig.GAME_SECONDS,
	level = 1,
	collected = 0,
	totalBlooms = 0,
	goal = GameConfig.LEVELS[1].goalBlooms,
	banner = "Welcome to Sunbloom Meadow!",
	reason = "",
}

-- When each player was last hurt, so one touch cannot eat two hearts.
local lastHurtAt = {}

-- Start a fresh run from the lobby or after an ending.
function GameState.startNewRun()
	state.phase = "Playing"
	state.score = 0
	state.hearts = GameConfig.START_HEARTS
	state.timeLeft = GameConfig.GAME_SECONDS
	state.level = 1
	state.collected = 0
	state.totalBlooms = 0
	state.goal = GameConfig.LEVELS[1].goalBlooms
	state.banner = "Level 1: Sunny Meadow - pick 8 blooms!"
	state.reason = ""
	table.clear(lastHurtAt)
end

-- Add points for one picked bloom and count it towards the level goal.
-- collected is this level's count (it resets on advance); totalBlooms
-- is the run total, so the HUD can show both and the score agrees.
function GameState.awardBloomPoints(points)
	state.score += points
	state.collected += 1
	state.totalBlooms += 1
end

-- Move to the next level. Returns false when there is no next level.
function GameState.advanceLevel()
	if state.level >= #GameConfig.LEVELS then
		return false
	end
	state.level += 1
	state.collected = 0
	local level = GameConfig.LEVELS[state.level]
	state.goal = level.goalBlooms
	state.banner = "Level " .. state.level .. ": " .. level.name .. " - pick " .. level.goalBlooms .. " blooms!"
	return true
end

-- Take one heart from the run. Returns the hearts left.
function GameState.loseHeart()
	state.hearts -= 1
	if state.hearts < 0 then
		state.hearts = 0
	end
	return state.hearts
end

-- True when this player may be hurt again after the cooldown.
function GameState.canHurtPlayer(player)
	local now = os.clock()
	local last = lastHurtAt[player]
	if last ~= nil and now - last < GameConfig.HURT_COOLDOWN_SECONDS then
		return false
	end
	lastHurtAt[player] = now
	return true
end

-- End the run with a win or a loss and the reason the player sees.
-- The banner is cleared here, not set to the reason: the old code put
-- the reason into the banner field, so an ending could re-show stale
-- banner text over the end screen.
function GameState.endRun(won, reason)
	if won then
		state.phase = "Won"
	else
		state.phase = "Lost"
	end
	state.reason = reason
	state.banner = ""
end

-- Spend one second of the timer. Returns the seconds left.
function GameState.tickTimer()
	state.timeLeft -= 1
	if state.timeLeft < 0 then
		state.timeLeft = 0
	end
	return state.timeLeft
end

-- A plain copy of the state, safe to send to the client.
function GameState.snapshot()
	return {
		phase = state.phase,
		score = state.score,
		hearts = state.hearts,
		timeLeft = state.timeLeft,
		level = state.level,
		collected = state.collected,
		totalBlooms = state.totalBlooms,
		goal = state.goal,
		banner = state.banner,
		reason = state.reason,
	}
end

return GameState
