-- Sunbloom Meadow: Flower Rush - the client HUD, rewritten simple.
-- One ScreenGui holds the top strip, the start screen and the end
-- screen. Every piece of text is a direct child of its panel, uses
-- GothamBold, and carries a ZIndex HIGHER than its panel, so no panel
-- can ever paint over its own text again. No decorative fonts, no
-- special glyphs, no frame-built shapes pretending to be text.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local actionRemote = ReplicatedStorage:WaitForChild(GameConfig.REMOTE_ACTION)
local stateRemote = ReplicatedStorage:WaitForChild(GameConfig.REMOTE_STATE)
local flashRemote = ReplicatedStorage:WaitForChild(GameConfig.REMOTE_FLASH)

local PANEL_GREEN = Color3.fromRGB(30, 90, 40)
local BUTTON_GREEN = Color3.fromRGB(60, 180, 80)
local CREAM = Color3.fromRGB(255, 248, 220)
local YELLOW = Color3.fromRGB(255, 220, 80)
local PINK = Color3.fromRGB(255, 150, 220)
local RED = Color3.fromRGB(235, 60, 90)
local HEART_RED = Color3.fromRGB(235, 60, 90)
local HEART_GREY = Color3.fromRGB(70, 70, 70)

-- The whole interface lives in one ScreenGui. ZIndexBehavior is set
-- explicitly to Sibling, so a child's ZIndex is only ever compared
-- with its siblings, never flattened against its parent.
local screen = Instance.new("ScreenGui")
screen.Name = "SunbloomHud"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- A text label with everything set out in the open: font, size,
-- colour, position, size, and a ZIndex above its panel.
local function makeLabel(parent, text, textSize, position, anchor, zIndex, colour)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextSize = textSize
	label.TextScaled = false
	label.TextColor3 = colour or CREAM
	label.TextTransparency = 0
	label.AnchorPoint = anchor
	label.Position = position
	label.Size = UDim2.new(0, 600, 0, textSize + 14)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = zIndex
	label.Parent = parent
	return label
end

-- A chunky button with white text on green. The text is the button's
-- own Text property, so it can never be hidden behind the button.
local function makeButton(parent, text, position, anchor, zIndex)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = BUTTON_GREEN
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextSize = 32
	button.TextScaled = false
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextTransparency = 0
	button.AnchorPoint = anchor
	button.Position = position
	button.Size = UDim2.new(0, 320, 0, 72)
	button.AutoButtonColor = true
	button.ZIndex = zIndex
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = button
	button.Parent = parent
	return button
end

-- Top strip: opaque dark green, ZIndex 10. All of its text is ZIndex 11.
local topStrip = Instance.new("Frame")
topStrip.BackgroundColor3 = PANEL_GREEN
topStrip.BackgroundTransparency = 0
topStrip.BorderSizePixel = 0
topStrip.AnchorPoint = Vector2.new(0.5, 0)
topStrip.Position = UDim2.new(0.5, 0, 0, 0)
topStrip.Size = UDim2.new(1, 0, 0, 96)
topStrip.ZIndex = 10
topStrip.Parent = screen

local scoreLabel = makeLabel(topStrip, "SCORE 0", 28, UDim2.new(0.5, 0, 0, 6), Vector2.new(0.5, 0), 11, CREAM)
local timerLabel = makeLabel(topStrip, "90s", 28, UDim2.new(0.5, 0, 0, 48), Vector2.new(0.5, 0), 11, YELLOW)

local goalLabel = makeLabel(topStrip, "BLOOMS 0 / 8", 28, UDim2.new(0, 16, 0, 48), Vector2.new(0, 0), 11, CREAM)
goalLabel.TextXAlignment = Enum.TextXAlignment.Left
goalLabel.Size = UDim2.new(0, 620, 0, 42)

local levelLabel = makeLabel(topStrip, "LEVEL 1", 28, UDim2.new(1, -16, 0, 48), Vector2.new(1, 0), 11, CREAM)
levelLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Hearts, top right: the word HEARTS plus three red dots. A dot is a
-- plain round frame (UICorner 0.5), red while the heart is alive and
-- grey once it is lost. No font glyph, no rotated squares.
local heartsCaption = makeLabel(topStrip, "HEARTS", 28, UDim2.new(1, -128, 0, 6), Vector2.new(1, 0), 11, CREAM)
heartsCaption.TextXAlignment = Enum.TextXAlignment.Right
heartsCaption.Size = UDim2.new(0, 110, 0, 42)

local heartDots = {}
for i = 1, 3 do
	local dot = Instance.new("Frame")
	dot.BackgroundColor3 = HEART_RED
	dot.BackgroundTransparency = 0
	dot.BorderSizePixel = 0
	dot.AnchorPoint = Vector2.new(1, 0)
	dot.Position = UDim2.new(1, -16 - (3 - i) * 34, 0, 8)
	dot.Size = UDim2.new(0, 26, 0, 26)
	dot.ZIndex = 11
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot
	dot.Parent = topStrip
	heartDots[i] = dot
end

local function paintHearts(aliveCount)
	for i, dot in ipairs(heartDots) do
		if i <= aliveCount then
			dot.BackgroundColor3 = HEART_RED
			dot.BackgroundTransparency = 0
		else
			dot.BackgroundColor3 = HEART_GREY
			dot.BackgroundTransparency = 0
		end
	end
end

-- One banner line in the middle of the screen, ZIndex 15. Shown for
-- three seconds, then hidden. It is never re-armed by a state
-- broadcast: renderState only shows a banner whose text changed.
local bannerLabel = makeLabel(screen, "", 36, UDim2.new(0.5, 0, 0.32, 0), Vector2.new(0.5, 0), 15, YELLOW)
bannerLabel.Visible = false

-- A floating "+10" that pops whenever a bloom is picked, ZIndex 16.
local pointsLabel = makeLabel(screen, "", 48, UDim2.new(0.5, 0, 0.45, 0), Vector2.new(0.5, 0), 16, YELLOW)
pointsLabel.Visible = false

-- A red wash that flashes over the game when the player is hurt.
-- ZIndex 18: above the HUD, below the start and end panels (20).
local hurtFlash = Instance.new("Frame")
hurtFlash.BackgroundColor3 = Color3.fromRGB(220, 30, 40)
hurtFlash.BackgroundTransparency = 1
hurtFlash.BorderSizePixel = 0
hurtFlash.Size = UDim2.new(1, 0, 1, 0)
hurtFlash.ZIndex = 18
hurtFlash.Parent = screen

-- The start screen. Opaque dark green panel, ZIndex 20. Every line of
-- text on it is a direct child with ZIndex 21 or higher.
local startFrame = Instance.new("Frame")
startFrame.BackgroundColor3 = PANEL_GREEN
startFrame.BackgroundTransparency = 0
startFrame.BorderSizePixel = 0
startFrame.AnchorPoint = Vector2.new(0.5, 0.5)
startFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
startFrame.Size = UDim2.new(0, 640, 0, 440)
startFrame.ZIndex = 20
startFrame.Parent = screen
local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 24)
startCorner.Parent = startFrame

makeLabel(startFrame, "SUNBLOOM MEADOW", 48, UDim2.new(0.5, 0, 0, 20), Vector2.new(0.5, 0), 21, YELLOW)
makeLabel(startFrame, "Flower Rush - collect blooms, dodge slimes!", 24, UDim2.new(0.5, 0, 0, 92), Vector2.new(0.5, 0), 21, PINK)
local howLabel = makeLabel(startFrame, "Run with WASD or arrow keys. Walk into yellow Sunblooms (+10) and rare pink Rainbow Blooms (+50). Dodge the green Thorn Slimes and the Dart Bees. 3 hearts, 90 seconds, 3 sunny levels.", 20, UDim2.new(0.5, 0, 0, 140), Vector2.new(0.5, 0), 21, CREAM)
howLabel.Size = UDim2.new(0, 580, 0, 130)
howLabel.TextWrapped = true
local playButton = makeButton(startFrame, "PLAY", UDim2.new(0.5, 0, 1, -24), Vector2.new(0.5, 1), 22)

-- The end screen. Same pattern as the start screen: opaque panel at
-- ZIndex 20, all text direct children at ZIndex 21 or higher.
local endFrame = Instance.new("Frame")
endFrame.BackgroundColor3 = PANEL_GREEN
endFrame.BackgroundTransparency = 0
endFrame.BorderSizePixel = 0
endFrame.AnchorPoint = Vector2.new(0.5, 0.5)
endFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
endFrame.Size = UDim2.new(0, 640, 0, 400)
endFrame.Visible = false
endFrame.ZIndex = 20
endFrame.Parent = screen
local endCorner = Instance.new("UICorner")
endCorner.CornerRadius = UDim.new(0, 24)
endCorner.Parent = endFrame

local resultLabel = makeLabel(endFrame, "", 48, UDim2.new(0.5, 0, 0, 24), Vector2.new(0.5, 0), 21, YELLOW)
local reasonLabel = makeLabel(endFrame, "", 24, UDim2.new(0.5, 0, 0, 100), Vector2.new(0.5, 0), 21, CREAM)
reasonLabel.Size = UDim2.new(0, 580, 0, 60)
reasonLabel.TextWrapped = true
local finalScoreLabel = makeLabel(endFrame, "", 32, UDim2.new(0.5, 0, 0, 180), Vector2.new(0.5, 0), 21, YELLOW)
local againButton = makeButton(endFrame, "PLAY AGAIN", UDim2.new(0.5, 0, 1, -24), Vector2.new(0.5, 1), 22)

-- Show the banner text for a few seconds, then hide it.
local bannerToken = 0
local lastBannerText = ""
local function showBanner(text, seconds)
	bannerToken += 1
	local token = bannerToken
	bannerLabel.Text = text
	bannerLabel.Visible = true
	task.delay(seconds, function()
		if token == bannerToken then
			bannerLabel.Visible = false
			bannerLabel.Text = ""
			lastBannerText = ""
		end
	end)
end

-- Hide the banner now, cancelling any delayed hide still pending.
local function hideBanner()
	bannerToken += 1
	bannerLabel.Visible = false
	bannerLabel.Text = ""
	lastBannerText = ""
end

-- Draw the whole HUD from one state snapshot from the server.
local function renderState(state)
	scoreLabel.Text = "SCORE " .. state.score
	timerLabel.Text = state.timeLeft .. "s"
	if state.timeLeft <= 10 and state.phase == "Playing" then
		timerLabel.TextColor3 = RED
	else
		timerLabel.TextColor3 = YELLOW
	end
	paintHearts(state.hearts)
	levelLabel.Text = "LEVEL " .. state.level
	goalLabel.Text = "BLOOMS " .. state.collected .. " / " .. state.goal .. "  -  TOTAL " .. state.totalBlooms

	if state.phase == "Lobby" then
		hideBanner()
		startFrame.Visible = true
		endFrame.Visible = false
	elseif state.phase == "Playing" then
		startFrame.Visible = false
		endFrame.Visible = false
		if state.banner ~= "" and state.banner ~= lastBannerText then
			lastBannerText = state.banner
			showBanner(state.banner, 3)
		end
	elseif state.phase == "Won" then
		hideBanner()
		startFrame.Visible = false
		endFrame.Visible = true
		resultLabel.Text = "YOU WIN!"
		resultLabel.TextColor3 = YELLOW
		reasonLabel.Text = state.reason
		finalScoreLabel.Text = "FINAL SCORE " .. state.score .. "  -  " .. state.totalBlooms .. " BLOOMS"
	elseif state.phase == "Lost" then
		hideBanner()
		startFrame.Visible = false
		endFrame.Visible = true
		resultLabel.Text = "GAME OVER"
		resultLabel.TextColor3 = RED
		reasonLabel.Text = state.reason
		finalScoreLabel.Text = "FINAL SCORE " .. state.score .. "  -  " .. state.totalBlooms .. " BLOOMS"
	end
end

-- A pickup pops a golden "+10" or "+50" in the middle of the screen.
local function showPickupPoints(points)
	pointsLabel.Text = "+" .. points
	pointsLabel.TextTransparency = 0
	pointsLabel.Visible = true
	local tween = TweenService:Create(pointsLabel, TweenInfo.new(1), { TextTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		pointsLabel.Visible = false
	end)
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
