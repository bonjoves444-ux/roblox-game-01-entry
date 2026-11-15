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

-- Forward declaration: armTouchDamage shoves an enemy away, and the
-- mover is defined just below it.
local moveEnemyParts

-- Wire one part so touching a player hurts them, once per cooldown.
-- After a hit the enemy is shoved 25 studs away from the player: the
-- old code left the enemy sitting on the player, so Touched fired
-- again the moment the 2-second cooldown ended and hearts drained
-- one per 2 seconds with no way out.
local function armTouchDamage(part, onPlayerHurt, enemy)
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
		local root = hit.Parent:FindFirstChild("HumanoidRootPart")
		if root ~= nil and enemy ~= nil then
			local away = enemy.centre - root.Position
			away = Vector3.new(away.X, 0, away.Z)
			if away.Magnitude < 1 then
				away = Vector3.new(math.random(-1, 1), 0, 1)
			end
			enemy.centre = Vector3.new(
				math.clamp(root.Position.X + away.Unit.X * 25, -GameConfig.MEADOW_HALF_SIZE, GameConfig.MEADOW_HALF_SIZE),
				enemy.centre.Y,
				math.clamp(root.Position.Z + away.Unit.Z * 25, -GameConfig.MEADOW_HALF_SIZE, GameConfig.MEADOW_HALF_SIZE)
			)
			moveEnemyParts(enemy, enemy.centre)
		end
		onPlayerHurt(player)
	end)
end

-- Move one enemy part and its riders together to a new centre.
moveEnemyParts = function(enemy, centre)
	for _, piece in ipairs(enemy.pieces) do
		piece.part.CFrame = CFrame.new(centre + piece.offset)
	end
end

-- One enemy's chase loop: step towards the nearest player, wobbling for bees.
-- It only chases inside the chase range; farther away it wanders slowly,
-- so enemies no longer converge on the player from across the meadow.
local function runEnemyLoop(enemy, token)
	task.spawn(function()
		local wobble = 0
		local wanderAngle = math.random() * math.pi * 2
		local wanderClock = 0
		while enemy.alive and token == waveToken do
			local snapshot = GameState.snapshot()
			if snapshot.phase ~= "Playing" then
				task.wait(0.25)
				continue
			end
			local root = findNearestPlayerRoot(enemy.centre)
			local chased = false
			if root ~= nil then
				local toPlayer = root.Position - enemy.centre
				toPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)
				local distance = toPlayer.Magnitude
				if distance <= GameConfig.ENEMY_CHASE_RANGE_STUDS and distance > 1 then
					chased = true
					local step = toPlayer.Unit * enemy.speed * 0.2
					if enemy.kind == "Bee" then
						wobble += 0.9
						local side = Vector3.new(-toPlayer.Unit.Z, 0, toPlayer.Unit.X)
						step += side * math.sin(wobble) * 1.6
					end
					enemy.centre += Vector3.new(step.X, 0, step.Z)
				end
			end
			if not chased then
				wanderClock += 0.2
				if wanderClock >= 2 then
					wanderClock = 0
					wanderAngle = math.random() * math.pi * 2
				end
				local drift = Vector3.new(math.cos(wanderAngle), 0, math.sin(wanderAngle))
				enemy.centre += drift * enemy.speed * 0.25 * 0.2
			end
			enemy.centre = Vector3.new(
				math.clamp(enemy.centre.X, -GameConfig.MEADOW_HALF_SIZE, GameConfig.MEADOW_HALF_SIZE),
				enemy.centre.Y,
				math.clamp(enemy.centre.Z, -GameConfig.MEADOW_HALF_SIZE, GameConfig.MEADOW_HALF_SIZE)
			)
			moveEnemyParts(enemy, enemy.centre)
			task.wait(0.2)
		end
	end)
end

-- A Thorn Slime: a big bright lime ball with a purple thorn on top.
-- The old 3.5-stud dark green ball blended into the grass; this one
-- is larger, lighter and glowing, so it reads as an enemy at a glance.
local function spawnThornSlime(position, speed, onPlayerHurt, token)
	local body = Instance.new("Part")
	body.Name = "ThornSlime"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(5, 5, 5)
	body.Color = Color3.fromRGB(80, 200, 60)
	body.Material = Enum.Material.Neon
	body.Anchored = true
	body.CanCollide = false
	body.Position = position
	body.Parent = getEnemiesFolder()

	local slimeGlow = Instance.new("PointLight")
	slimeGlow.Color = Color3.fromRGB(80, 200, 60)
	slimeGlow.Range = 8
	slimeGlow.Brightness = 1
	slimeGlow.Parent = body

	local thorn = Instance.new("Part")
	thorn.Name = "Thorn"
	thorn.Shape = Enum.PartType.Ball
	thorn.Size = Vector3.new(2, 2, 2)
	thorn.Color = Color3.fromRGB(160, 60, 220)
	thorn.Material = Enum.Material.Neon
	thorn.Anchored = true
	thorn.CanCollide = false
	thorn.Position = position + Vector3.new(0, 2.8, 0)
	thorn.Parent = getEnemiesFolder()

	local enemy = {
		kind = "Slime",
		speed = speed,
		centre = position,
		alive = true,
		pieces = {
			{ part = body, offset = Vector3.new(0, 0, 0) },
			{ part = thorn, offset = Vector3.new(0, 2.8, 0) },
		},
	}
	armTouchDamage(body, onPlayerHurt, enemy)
	table.insert(activeEnemies, enemy)
	runEnemyLoop(enemy, token)
	return enemy
end

-- A Dart Bee: a bigger yellow ball with a black stripe and white wings.
local function spawnDartBee(position, speed, onPlayerHurt, token)
	local body = Instance.new("Part")
	body.Name = "DartBee"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3.6, 3.6, 3.6)
	body.Color = Color3.fromRGB(255, 210, 30)
	body.Material = Enum.Material.Neon
	body.Anchored = true
	body.CanCollide = false
	body.Position = position
	body.Parent = getEnemiesFolder()

	local beeGlow = Instance.new("PointLight")
	beeGlow.Color = Color3.fromRGB(255, 210, 30)
	beeGlow.Range = 7
	beeGlow.Brightness = 1
	beeGlow.Parent = body

	local stripe = Instance.new("Part")
	stripe.Name = "BeeStripe"
	stripe.Shape = Enum.PartType.Ball
	stripe.Size = Vector3.new(3.7, 1.2, 3.7)
	stripe.Color = Color3.fromRGB(30, 30, 30)
	stripe.Material = Enum.Material.SmoothPlastic
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.Position = position
	stripe.Parent = getEnemiesFolder()

	local wing = Instance.new("Part")
	wing.Name = "BeeWing"
	wing.Size = Vector3.new(3.2, 0.2, 1.8)
	wing.Color = Color3.fromRGB(255, 255, 255)
	wing.Material = Enum.Material.SmoothPlastic
	wing.Transparency = 0.3
	wing.Anchored = true
	wing.CanCollide = false
	wing.Position = position + Vector3.new(0, 2, 0)
	wing.Parent = getEnemiesFolder()

	local enemy = {
		kind = "Bee",
		speed = speed,
		centre = position,
		alive = true,
		pieces = {
			{ part = body, offset = Vector3.new(0, 0, 0) },
			{ part = stripe, offset = Vector3.new(0, 0, 0) },
			{ part = wing, offset = Vector3.new(0, 2, 0) },
		},
	}
	armTouchDamage(body, onPlayerHurt, enemy)
	table.insert(activeEnemies, enemy)
	runEnemyLoop(enemy, token)
	return enemy
end

-- A random spot on the meadow floor, away from the spawn corner and
-- away from every player: the old code spawned anywhere, so an enemy
-- could start on top of the player before they had moved at all.
local function randomMeadowSpot(height)
	local half = GameConfig.MEADOW_HALF_SIZE
	local safe = GameConfig.SPAWN_SAFE_RADIUS_STUDS
	local spot = Vector3.new(0, height, 0)
	for _ = 1, 20 do
		spot = Vector3.new(math.random(-half, half), height, math.random(-half, half))
		local fromSpawn = Vector3.new(spot.X, 0, spot.Z + 60).Magnitude
		local nearestRoot = findNearestPlayerRoot(spot)
		local fromPlayer = math.huge
		if nearestRoot ~= nil then
			fromPlayer = (nearestRoot.Position - spot).Magnitude
		end
		if fromSpawn >= safe and fromPlayer >= 18 then
			break
		end
	end
	return spot
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
-- The first slime always starts in front of the spawn pad, 24 studs
-- out: visible in the first play screenshot, but never on the player.
function EnemySpawner.startWave(level, onPlayerHurt)
	EnemySpawner.clearEnemies()
	local token = waveToken
	local settings = GameConfig.LEVELS[level]
	spawnThornSlime(Vector3.new(16, 2.5, -36), settings.slimeSpeed, onPlayerHurt, token)
	for _ = 2, settings.slimeCount do
		spawnThornSlime(randomMeadowSpot(2.5), settings.slimeSpeed, onPlayerHurt, token)
	end
	for _ = 1, settings.beeCount do
		spawnDartBee(randomMeadowSpot(3), settings.beeSpeed, onPlayerHurt, token)
	end
end

return EnemySpawner
