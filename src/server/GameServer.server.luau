-- Sunbloom Meadow: Flower Rush - the server that runs the game.
-- It owns the blooms, the timer, the level flow and the remotes, and keeps
-- the single GameState as the one source of truth for the whole run.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local EnemySpawner = require(script.Parent:WaitForChild("EnemySpawner"))

-- Forward declarations: the bloom and ending helpers below are locals
-- shared by the award, start and timer code above their definitions.
local spawnBloom
local spawnBloomWave
local endGame
local onPlayerHurt

-- The three remotes the client talks to, made here so they always exist.
local actionRemote = Instance.new("RemoteEvent")
actionRemote.Name = GameConfig.REMOTE_ACTION
actionRemote.Parent = ReplicatedStorage

local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = GameConfig.REMOTE_STATE
stateRemote.Parent = ReplicatedStorage

local flashRemote = Instance.new("RemoteEvent")
flashRemote.Name = GameConfig.REMOTE_FLASH
flashRemote.Parent = ReplicatedStorage

-- One cheerful chime for pickups, one low thud for hits, both built in.
local pickupSound = Instance.new("Sound")
pickupSound.Name = "SunbloomPickupSound"
pickupSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
pickupSound.Volume = 0.6
pickupSound.Parent = Workspace

local hurtSound = Instance.new("Sound")
hurtSound.Name = "SunbloomHurtSound"
hurtSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
hurtSound.PlaybackSpeed = 0.6
hurtSound.Volume = 0.8
hurtSound.Parent = Workspace

local bloomsFolder = nil
local runToken = 0

-- Send the current state to every player at once.
local function broadcastState()
	stateRemote:FireAllClients(GameState.snapshot())
end

-- The folder the live blooms grow in, made on first use.
local function getBloomsFolder()
	if bloomsFolder == nil or bloomsFolder.Parent == nil then
		bloomsFolder = Instance.new("Folder")
		bloomsFolder.Name = "SunbloomBlooms"
		bloomsFolder.Parent = Workspace
	end
	return bloomsFolder
end

-- How many blooms of one kind are still growing in the meadow.
local function countAliveBlooms(kind)
	local count = 0
	local folder = Workspace:FindFirstChild("SunbloomBlooms")
	if folder == nil then
		return 0
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child.Name == kind then
			count += 1
		end
	end
	return count
end

-- Grow one fresh bloom of a kind after a short pause, while the run lasts.
local function regrowBloom(kind)
	task.delay(GameConfig.BLOOM_REGROW_SECONDS, function()
		if GameState.snapshot().phase ~= "Playing" then
			return
		end
		local target = kind == "RainbowBloom" and GameConfig.ALIVE_RAINBOWS or GameConfig.ALIVE_SUNBLOOMS
		if countAliveBlooms(kind) < target then
			spawnBloom(kind)
		end
	end)
end

-- Give the player their points for one bloom, then check the level goal.
local function awardBloomPoints(player, bloom, kind)
	if bloom:GetAttribute("Taken") then
		return
	end
	bloom:SetAttribute("Taken", true)
	local points = kind == "RainbowBloom" and GameConfig.RAINBOW_POINTS or GameConfig.SUNBLOOM_POINTS
	GameState.awardBloomPoints(points)
	pickupSound.TimePosition = 0
	pickupSound:Play()
	flashRemote:FireClient(player, { kind = "pickup", points = points })
	bloom:Destroy()
	regrowBloom(kind)

	local snapshot = GameState.snapshot()
	if snapshot.collected >= snapshot.goal then
		if GameState.advanceLevel() then
			local nextLevel = GameState.snapshot().level
			local settings = GameConfig.LEVELS[nextLevel]
			local ok = pcall(function()
				Lighting.ClockTime = settings.clockTime
			end)
			if not ok then
				warn("Sunbloom Meadow: could not set the sky clock for level " .. nextLevel)
			end
			spawnBloomWave()
			EnemySpawner.startWave(nextLevel, onPlayerHurt)
			broadcastState()
		else
			endGame(true, "You picked every bloom! The meadow is yours!")
		end
	else
		broadcastState()
	end
end

-- Grow one bloom: a glowing Sunbloom, or a bigger pink Rainbow Bloom.
function spawnBloom(kind)
	local isRainbow = kind == "RainbowBloom"
	local bloom = Instance.new("Part")
	bloom.Name = kind
	bloom.Shape = Enum.PartType.Ball
	if isRainbow then
		bloom.Size = Vector3.new(3.4, 3.4, 3.4)
		bloom.Color = Color3.fromRGB(255, 80, 200)
	else
		bloom.Size = Vector3.new(2.4, 2.4, 2.4)
		bloom.Color = Color3.fromRGB(255, 200, 40)
	end
	bloom.Material = Enum.Material.Neon
	bloom.Anchored = true
	bloom.CanCollide = false
	local half = GameConfig.MEADOW_HALF_SIZE
	bloom.Position = Vector3.new(math.random(-half, half), 2, math.random(-half, half))
	bloom.Parent = getBloomsFolder()

	local glow = Instance.new("PointLight")
	glow.Color = bloom.Color
	glow.Range = 7
	glow.Brightness = 1
	glow.Parent = bloom

	bloom.Touched:Connect(function(hit)
		if GameState.snapshot().phase ~= "Playing" then
			return
		end
		local humanoid = hit.Parent and hit.Parent:FindFirstChildWhichIsA("Humanoid")
		if humanoid == nil then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player == nil then
			return
		end
		awardBloomPoints(player, bloom, kind)
	end)
	return bloom
end

-- Fill the meadow with a fresh wave of blooms for the current level.
function spawnBloomWave()
	local folder = Workspace:FindFirstChild("SunbloomBlooms")
	if folder ~= nil then
		folder:Destroy()
	end
	bloomsFolder = nil
	for _ = 1, GameConfig.ALIVE_SUNBLOOMS do
		spawnBloom("Sunbloom")
	end
	for _ = 1, GameConfig.ALIVE_RAINBOWS do
		spawnBloom("RainbowBloom")
	end
end

-- Finish the run and show every player the ending screen.
function endGame(won, reason)
	runToken += 1
	GameState.endRun(won, reason)
	if won then
		pickupSound.PlaybackSpeed = 1.4
		pickupSound.TimePosition = 0
		pickupSound:Play()
		pickupSound.PlaybackSpeed = 1
	end
	broadcastState()
end

-- One second at a time, count the run down until it ends.
local function runTimerLoop(token)
	while token == runToken do
		task.wait(1)
		if token ~= runToken then
			return
		end
		if GameState.snapshot().phase ~= "Playing" then
			return
		end
		local left = GameState.tickTimer()
		broadcastState()
		if left <= 0 then
			endGame(false, "Time ran out! The sun has set on the meadow.")
			return
		end
	end
end

-- Start a brand new run: fresh state, fresh blooms, fresh enemies.
local function startGame()
	if GameState.snapshot().phase == "Playing" then
		return
	end
	runToken += 1
	GameState.startNewRun()
	local settings = GameConfig.LEVELS[1]
	local ok = pcall(function()
		Lighting.ClockTime = settings.clockTime
	end)
	if not ok then
		warn("Sunbloom Meadow: could not set the sky clock for level 1")
	end
	spawnBloomWave()
	EnemySpawner.startWave(1, onPlayerHurt)
	broadcastState()
	runTimerLoop(runToken)
end

-- An enemy touched a player: lose a heart, flash the screen, maybe end.
function onPlayerHurt(_player)
	local hearts = GameState.loseHeart()
	hurtSound.TimePosition = 0
	hurtSound:Play()
	flashRemote:FireAllClients({ kind = "hit" })
	broadcastState()
	if hearts <= 0 then
		endGame(false, "The thorns got you! No hearts left.")
	end
end

-- The client asks to start, or to play again after an ending.
actionRemote.OnServerEvent:Connect(function(_player, action)
	if action == "StartGame" or action == "PlayAgain" then
		task.spawn(startGame)
	end
end)

-- A player who joins late still gets the current state for their HUD.
Players.PlayerAdded:Connect(function(player)
	task.wait(1)
	stateRemote:FireClient(player, GameState.snapshot())
end)

-- The lobby waits with a sunny sky and an empty meadow.
local ok = pcall(function()
	Lighting.ClockTime = GameConfig.LEVELS[1].clockTime
	Lighting.Brightness = 2
end)
if not ok then
	warn("Sunbloom Meadow: could not set the lobby sky")
end
broadcastState()
