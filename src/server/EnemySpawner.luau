-- Sunbloom Meadow: Flower Rush - the enemies, and only the enemies.
-- Thorn Slimes waddle after the nearest player; Dart Bees zig-zag in fast.
-- This module owns every enemy part and its movement, and calls back to the
-- server when one of them touches a player.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))
local GameState = require(script.Parent:WaitForChild("GameState"))

local EnemySpawner = {}

local enemiesFolder = nil
local waveToken = 0
local activeEnemies = {}

-- Find the folder the enemies live in, making it on first use.
local function getEnemiesFolder()
	if enemiesFolder == nil or enemiesFolder.Parent == nil then
		enemiesFolder = Instance.new("Folder")
		enemiesFolder.Name = "SunbloomEnemies"
		enemiesFolder.Parent = Workspace
	end
	return enemiesFolder
end

-- The nearest playing character to a point, or nil when nobody is in.
local function findNearestPlayerRoot(fromPosition)
	local nearestRoot = nil
	local nearestDistance = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root ~= nil then
			local distance = (root.Position - fromPosition).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestRoot = root
			end
		end
	end
	return nearestRoot
end

-- Wire one part so touching a player hurts them, once per cooldown.
local function armTouchDamage(part, onPlayerHurt)
	part.Touched:Connect(function(hit)
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
		if not GameState.canHurtPlayer(player) then
			return
		end
		onPlayerHurt(player)
	end)
end

-- Move one enemy part and its riders together to a new centre.
local function moveEnemyParts(enemy, centre)
	for _, piece in ipairs(enemy.pieces) do
		piece.part.CFrame = CFrame.new(centre + piece.offset)
	end
end

-- One enemy's chase loop: step towards the nearest player, wobbling for bees.
local function runEnemyLoop(enemy, token)
	task.spawn(function()
		local wobble = 0
		while enemy.alive and token == waveToken do
			local snapshot = GameState.snapshot()
			if snapshot.phase ~= "Playing" then
				task.wait(0.25)
				continue
			end
			local root = findNearestPlayerRoot(enemy.centre)
			if root ~= nil then
				local toPlayer = root.Position - enemy.centre
				toPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)
				local distance = toPlayer.Magnitude
				if distance > 1 then
					local step = toPlayer.Unit * enemy.speed * 0.2
					if enemy.kind == "Bee" then
						wobble += 0.9
						local side = Vector3.new(-toPlayer.Unit.Z, 0, toPlayer.Unit.X)
						step += side * math.sin(wobble) * 1.6
					end
					enemy.centre += Vector3.new(step.X, 0, step.Z)
					enemy.centre = Vector3.new(
						math.clamp(enemy.centre.X, -GameConfig.MEADOW_HALF_SIZE, GameConfig.MEADOW_HALF_SIZE),
						enemy.centre.Y,
						math.clamp(enemy.centre.Z, -GameConfig.MEADOW_HALF_SIZE, GameConfig.MEADOW_HALF_SIZE)
					)
					moveEnemyParts(enemy, enemy.centre)
				end
			end
			task.wait(0.2)
		end
	end)
end

-- A Thorn Slime: a dark green ball with a purple thorn on top.
local function spawnThornSlime(position, speed, onPlayerHurt, token)
	local body = Instance.new("Part")
	body.Name = "ThornSlime"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3.5, 3.5, 3.5)
	body.Color = Color3.fromRGB(46, 125, 50)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Position = position
	body.Parent = getEnemiesFolder()

	local thorn = Instance.new("Part")
	thorn.Name = "Thorn"
	thorn.Shape = Enum.PartType.Ball
	thorn.Size = Vector3.new(1.4, 1.4, 1.4)
	thorn.Color = Color3.fromRGB(120, 60, 180)
	thorn.Material = Enum.Material.Neon
	thorn.Anchored = true
	thorn.CanCollide = false
	thorn.Position = position + Vector3.new(0, 2, 0)
	thorn.Parent = getEnemiesFolder()

	local enemy = {
		kind = "Slime",
		speed = speed,
		centre = position,
		alive = true,
		pieces = {
			{ part = body, offset = Vector3.new(0, 0, 0) },
			{ part = thorn, offset = Vector3.new(0, 2, 0) },
		},
	}
	armTouchDamage(body, onPlayerHurt)
	table.insert(activeEnemies, enemy)
	runEnemyLoop(enemy, token)
	return enemy
end

-- A Dart Bee: a yellow ball with a black stripe and white wings.
local function spawnDartBee(position, speed, onPlayerHurt, token)
	local body = Instance.new("Part")
	body.Name = "DartBee"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2.6, 2.6, 2.6)
	body.Color = Color3.fromRGB(255, 210, 30)
	body.Material = Enum.Material.Neon
	body.Anchored = true
	body.CanCollide = false
	body.Position = position
	body.Parent = getEnemiesFolder()

	local stripe = Instance.new("Part")
	stripe.Name = "BeeStripe"
	stripe.Shape = Enum.PartType.Ball
	stripe.Size = Vector3.new(2.7, 1, 2.7)
	stripe.Color = Color3.fromRGB(30, 30, 30)
	stripe.Material = Enum.Material.SmoothPlastic
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.Position = position
	stripe.Parent = getEnemiesFolder()

	local wing = Instance.new("Part")
	wing.Name = "BeeWing"
	wing.Size = Vector3.new(2.4, 0.2, 1.4)
	wing.Color = Color3.fromRGB(255, 255, 255)
	wing.Material = Enum.Material.SmoothPlastic
	wing.Transparency = 0.3
	wing.Anchored = true
	wing.CanCollide = false
	wing.Position = position + Vector3.new(0, 1.6, 0)
	wing.Parent = getEnemiesFolder()

	local enemy = {
		kind = "Bee",
		speed = speed,
		centre = position,
		alive = true,
		pieces = {
			{ part = body, offset = Vector3.new(0, 0, 0) },
			{ part = stripe, offset = Vector3.new(0, 0, 0) },
			{ part = wing, offset = Vector3.new(0, 1.6, 0) },
		},
	}
	armTouchDamage(body, onPlayerHurt)
	table.insert(activeEnemies, enemy)
	runEnemyLoop(enemy, token)
	return enemy
end

-- A random spot on the meadow floor, away from the spawn corner.
local function randomMeadowSpot(height)
	local half = GameConfig.MEADOW_HALF_SIZE
	return Vector3.new(
		math.random(-half, half),
		height,
		math.random(-half, half)
	)
end

-- Clear every enemy and stop their chase loops.
function EnemySpawner.clearEnemies()
	waveToken += 1
	for _, enemy in ipairs(activeEnemies) do
		enemy.alive = false
	end
	table.clear(activeEnemies)
	local folder = Workspace:FindFirstChild("SunbloomEnemies")
	if folder ~= nil then
		folder:Destroy()
	end
	enemiesFolder = nil
end

-- Fill the meadow with the enemies this level calls for.
function EnemySpawner.startWave(level, onPlayerHurt)
	EnemySpawner.clearEnemies()
	local token = waveToken
	local settings = GameConfig.LEVELS[level]
	for _ = 1, settings.slimeCount do
		spawnThornSlime(randomMeadowSpot(2), settings.slimeSpeed, onPlayerHurt, token)
	end
	for _ = 1, settings.beeCount do
		spawnDartBee(randomMeadowSpot(3), settings.beeSpeed, onPlayerHurt, token)
	end
end

return EnemySpawner
