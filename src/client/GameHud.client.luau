-- Sunbloom Meadow: Flower Rush - the client that draws the whole game.
-- It builds the HUD, the start screen and the end screen from code, shows
-- the state the server sends, and flashes feedback on every pickup and hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local actionRemote = ReplicatedStorage:WaitForChild(GameConfig.REMOTE_ACTION)
local stateRemote = ReplicatedStorage:WaitForChild(GameConfig.REMOTE_STATE)
local flashRemote = ReplicatedStorage:WaitForChild(GameConfig.REMOTE_FLASH)

-- Make a text label with one job: big, bold, readable at a glance.
local function makeLabel(parent, text, size, position, anchor)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextSize = size
	label.TextColor3 = Color3.fromRGB(255, 248, 220)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(30, 90, 40)
	label.AnchorPoint = anchor
	label.Position = position
	label.Size = UDim2.new(0, 500, 0, size + 16)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = parent
	return label
end

-- Make a chunky button the player cannot miss.
local function makeButton(parent, text, size, position, anchor, colour)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = colour
	button.Font = Enum.Font.FredokaOne
	button.Text = text
	button.TextSize = size
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeTransparency = 0.2
	button.TextStrokeColor3 = Color3.fromRGB(30, 90, 40)
	button.AnchorPoint = anchor
	button.Position = position
	button.Size = UDim2.new(0, 320, 0, 72)
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = button
	button.Parent = parent
	return button
end

-- The whole interface lives in one ScreenGui, built here.
local screen = Instance.new("ScreenGui")
screen.Name = "SunbloomHud"
screen.ResetOnSpawn = false
screen.Parent = playerGui

-- A dark strip across the top so the score always reads against the sky.
-- Fully opaque: a see-through strip let the sky wash the text out.
local topStrip = Instance.new("Frame")
topStrip.BackgroundColor3 = Color3.fromRGB(30, 90, 40)
topStrip.BackgroundTransparency = 0
topStrip.BorderSizePixel = 0
topStrip.AnchorPoint = Vector2.new(0.5, 0)
topStrip.Position = UDim2.new(0.5, 0, 0, 0)
topStrip.Size = UDim2.new(1, 0, 0, 96)
topStrip.ZIndex = 2
topStrip.Parent = screen

-- Score in the middle of the top strip, clear of the Roblox menu at left.
local scoreLabel = makeLabel(topStrip, "SCORE 0", 40, UDim2.new(0.5, 0, 0, 4), Vector2.new(0.5, 0))
local timerLabel = makeLabel(topStrip, "90s", 30, UDim2.new(0.5, 0, 0, 48), Vector2.new(0.5, 0))
timerLabel.TextColor3 = Color3.fromRGB(255, 220, 80)

-- Hearts at the top right, level just under them. Hearts are built from
-- frames, never from a "♥" glyph: FredokaOne has no heart glyph, so the
-- glyph rendered as a stray dash, and at 0 hearts the code even wrote an
-- em-dash on purpose. Three frame hearts, red when alive, grey when lost.
local heartsFrame = Instance.new("Frame")
heartsFrame.BackgroundTransparency = 1
heartsFrame.AnchorPoint = Vector2.new(1, 0)
heartsFrame.Position = UDim2.new(1, -16, 0, 8)
heartsFrame.Size = UDim2.new(0, 102, 0, 30)
heartsFrame.ZIndex = 3
heartsFrame.Parent = topStrip

local heartWidgets = {}
local function makeHeart(xOffset)
	local heart = Instance.new("Frame")
	heart.BackgroundTransparency = 1
	heart.Position = UDim2.new(0, xOffset, 0, 0)
	heart.Size = UDim2.new(0, 30, 0, 30)
	heart.Parent = heartsFrame
	local function heartPart(size, x, y, rotation, cornerRadius)
		local part = Instance.new("Frame")
		part.BackgroundColor3 = Color3.fromRGB(235, 60, 90)
		part.BorderSizePixel = 0
		part.Position = UDim2.new(0, x, 0, y)
		part.Size = UDim2.new(0, size, 0, size)
		part.Rotation = rotation or 0
		part.Parent = heart
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, cornerRadius)
		corner.Parent = part
		return part
	end
	-- Two round lobes on top and a rotated square below: a heart shape.
	local lobeLeft = heartPart(15, 0, 0, 0, 8)
	local lobeRight = heartPart(15, 15, 0, 0, 8)
	local point = heartPart(18, 6, 9, 45, 3)
	local widget = { lobeLeft, lobeRight, point }
	table.insert(heartWidgets, widget)
	return widget
end

makeHeart(0)
makeHeart(36)
makeHeart(72)

local function paintHearts(aliveCount)
	for i, widget in ipairs(heartWidgets) do
		local colour = Color3.fromRGB(235, 60, 90)
		local transparency = 0
		if i > aliveCount then
			colour = Color3.fromRGB(70, 70, 70)
			transparency = 0.45
		end
		for _, part in ipairs(widget) do
			part.BackgroundColor3 = colour
			part.BackgroundTransparency = transparency
		end
	end
end

local levelLabel = makeLabel(topStrip, "LEVEL 1", 28, UDim2.new(1, -16, 0, 50), Vector2.new(1, 0))

-- Blooms picked towards the level goal, under the timer.
local goalLabel = makeLabel(topStrip, "BLOOMS 0 / 8", 26, UDim2.new(0, 16, 0, 50), Vector2.new(0, 0))
goalLabel.TextXAlignment = Enum.TextXAlignment.Left
-- Wide enough for the level count plus the run total ("• TOTAL 9").
goalLabel.Size = UDim2.new(0, 620, 0, 42)

-- A banner in the middle of the screen for level-ups and endings.
-- It lives under the start/end panels (ZIndex 5 vs their 20) and is
-- hidden outright whenever an ending shows, so it can never bleed
-- through an ending the way the Level 2 banner did over GAME OVER.
local bannerLabel = makeLabel(screen, "", 44, UDim2.new(0.5, 0, 0.32, 0), Vector2.new(0.5, 0))
bannerLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
bannerLabel.ZIndex = 5

-- A floating "+10" that pops whenever a bloom is picked.
local pointsLabel = makeLabel(screen, "", 48, UDim2.new(0.5, 0, 0.45, 0), Vector2.new(0.5, 0))
pointsLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
pointsLabel.ZIndex = 6

-- A red wash that flashes over everything when the player is hurt.
-- Above the HUD, below the start/end panels.
local hurtFlash = Instance.new("Frame")
hurtFlash.BackgroundColor3 = Color3.fromRGB(220, 30, 40)
hurtFlash.BackgroundTransparency = 1
hurtFlash.BorderSizePixel = 0
hurtFlash.Size = UDim2.new(1, 0, 1, 0)
hurtFlash.ZIndex = 12
hurtFlash.Parent = screen

-- The start screen: title, how to play, and the big Play button.
-- Fully opaque: the old 0.25 transparency let the meadow and the
-- player show through the panel and muddy every line of text.
local startFrame = Instance.new("Frame")
startFrame.BackgroundColor3 = Color3.fromRGB(30, 90, 40)
startFrame.BackgroundTransparency = 0
startFrame.BorderSizePixel = 0
startFrame.AnchorPoint = Vector2.new(0.5, 0.5)
startFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
startFrame.Size = UDim2.new(0, 640, 0, 420)
startFrame.ZIndex = 20
startFrame.Parent = screen
local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 24)
startCorner.Parent = startFrame

local titleLabel = makeLabel(startFrame, "SUNBLOOM MEADOW", 56, UDim2.new(0.5, 0, 0, 24), Vector2.new(0.5, 0))
titleLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
local subtitleLabel = makeLabel(startFrame, "FLOWER RUSH", 36, UDim2.new(0.5, 0, 0, 96), Vector2.new(0.5, 0))
subtitleLabel.TextColor3 = Color3.fromRGB(255, 150, 220)
local howLabel = makeLabel(
	startFrame,
	"Run with WASD or arrow keys.\nWalk into yellow Sunblooms (+10)\nand rare pink Rainbow Blooms (+50).\nDodge the green Thorn Slimes and the Dart Bees!\n3 hearts, 90 seconds, 3 sunny levels.",
	26,
	UDim2.new(0.5, 0, 0, 150),
	Vector2.new(0.5, 0)
)
howLabel.Size = UDim2.new(0, 580, 0, 150)
local playButton = makeButton(startFrame, "▶  PLAY", 36, UDim2.new(0.5, 0, 1, -28), Vector2.new(0.5, 1), Color3.fromRGB(60, 180, 80))

-- The end screen: win or lose, the final score, and Play Again.
-- Fully opaque, like the start screen: nothing behind it may show.
local endFrame = Instance.new("Frame")
endFrame.BackgroundColor3 = Color3.fromRGB(30, 90, 40)
endFrame.BackgroundTransparency = 0
endFrame.BorderSizePixel = 0
endFrame.AnchorPoint = Vector2.new(0.5, 0.5)
endFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
endFrame.Size = UDim2.new(0, 640, 0, 360)
endFrame.Visible = false
endFrame.ZIndex = 20
endFrame.Parent = screen
local endCorner = Instance.new("UICorner")
endCorner.CornerRadius = UDim.new(0, 24)
endCorner.Parent = endFrame

local resultLabel = makeLabel(endFrame, "", 56, UDim2.new(0.5, 0, 0, 24), Vector2.new(0.5, 0))
local reasonLabel = makeLabel(endFrame, "", 28, UDim2.new(0.5, 0, 0, 100), Vector2.new(0.5, 0))
reasonLabel.Size = UDim2.new(0, 580, 0, 80)
local finalScoreLabel = makeLabel(endFrame, "", 36, UDim2.new(0.5, 0, 0, 180), Vector2.new(0.5, 0))
finalScoreLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
local againButton = makeButton(endFrame, "↻  PLAY AGAIN", 36, UDim2.new(0.5, 0, 1, -28), Vector2.new(0.5, 1), Color3.fromRGB(60, 180, 80))

-- Show the banner text for a few seconds, then clear it.
local bannerToken = 0
local lastBannerText = ""
local function showBanner(text, seconds)
	bannerToken += 1
	local token = bannerToken
	bannerLabel.Text = text
	task.delay(seconds, function()
		if token == bannerToken then
			bannerLabel.Text = ""
			lastBannerText = ""
		end
	end)
end

-- Hide the banner now, cancelling any delayed clear still pending.
local function hideBanner()
	bannerToken += 1
	bannerLabel.Text = ""
	lastBannerText = ""
end

-- Draw the whole HUD from one state snapshot from the server.
local function renderState(state)
	scoreLabel.Text = "SCORE " .. state.score
	timerLabel.Text = state.timeLeft .. "s"
	if state.timeLeft <= 10 and state.phase == "Playing" then
		timerLabel.TextColor3 = Color3.fromRGB(235, 60, 90)
	else
		timerLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
	end
	-- Frame hearts, never a glyph: three slots, always visible, so the
	-- player can count them at a glance even at 0 hearts.
	paintHearts(state.hearts)
	levelLabel.Text = "LEVEL " .. state.level
	-- Score is the run total, blooms are this level's count: label both,
	-- so "SCORE 130, BLOOMS 1 / 10" no longer looks inconsistent.
	goalLabel.Text = "BLOOMS " .. state.collected .. " / " .. state.goal .. "  •  TOTAL " .. state.totalBlooms

	if state.phase == "Lobby" then
		hideBanner()
		startFrame.Visible = true
		endFrame.Visible = false
	elseif state.phase == "Playing" then
		startFrame.Visible = false
		endFrame.Visible = false
		-- The server never clears its banner field, and it broadcasts
		-- every timer tick: without this check the banner re-fired
		-- every second and never went away. Show each banner once.
		if state.banner ~= "" and state.banner ~= lastBannerText then
			lastBannerText = state.banner
			showBanner(state.banner, 3)
		end
	elseif state.phase == "Won" then
		hideBanner()
		startFrame.Visible = false
		endFrame.Visible = true
		resultLabel.Text = "YOU WIN!"
		resultLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
		reasonLabel.Text = state.reason
		finalScoreLabel.Text = "FINAL SCORE " .. state.score .. "  •  " .. state.totalBlooms .. " BLOOMS"
	elseif state.phase == "Lost" then
		hideBanner()
		startFrame.Visible = false
		endFrame.Visible = true
		resultLabel.Text = "GAME OVER"
		resultLabel.TextColor3 = Color3.fromRGB(235, 60, 90)
		reasonLabel.Text = state.reason
		finalScoreLabel.Text = "FINAL SCORE " .. state.score .. "  •  " .. state.totalBlooms .. " BLOOMS"
	end
end

-- A pickup pops a golden "+10" or "+50" in the middle of the screen.
local function showPickupPoints(points)
	pointsLabel.Text = "+" .. points
	pointsLabel.TextTransparency = 0
	local tween = TweenService:Create(pointsLabel, TweenInfo.new(1), { TextTransparency = 1 })
	tween:Play()
end

-- A hit washes the screen red, then fades back out.
local function showHurtFlash()
	hurtFlash.BackgroundTransparency = 0.35
	local tween = TweenService:Create(hurtFlash, TweenInfo.new(0.8), { BackgroundTransparency = 1 })
	tween:Play()
end

playButton.MouseButton1Click:Connect(function()
	actionRemote:FireServer("StartGame")
end)

againButton.MouseButton1Click:Connect(function()
	actionRemote:FireServer("PlayAgain")
end)

stateRemote.OnClientEvent:Connect(renderState)

flashRemote.OnClientEvent:Connect(function(feedback)
	if feedback.kind == "pickup" then
		showPickupPoints(feedback.points)
	elseif feedback.kind == "hit" then
		showHurtFlash()
	end
end)
