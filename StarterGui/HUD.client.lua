-- HUD.client.lua
-- StarterGui LocalScript for Skibidi Tentafruit Heist
-- Handles all in-game HUD elements

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ScreenGui setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GameHUD"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Remote Events
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
local NotificationEvent   = RemoteEvents and RemoteEvents:WaitForChild("Notification", 10)
local SkinStolenEvent = RemoteEvents and RemoteEvents:WaitForChild("SkinStolen", 10)
local SkinClaimedEvent = RemoteEvents and RemoteEvents:WaitForChild("SkinClaimed", 10)
local RebirthCompleteEvent = RemoteEvents and RemoteEvents:WaitForChild("RebirthComplete", 10)
local LockBaseRemote      = RemoteEvents and RemoteEvents:WaitForChild("LockBase", 10)
local OpenShopRemote      = RemoteEvents and RemoteEvents:WaitForChild("OpenShop", 10)
local OpenPokedexRemote   = RemoteEvents and RemoteEvents:WaitForChild("OpenPokedex", 10)
local SellSkinRemote  = RemoteEvents and RemoteEvents:WaitForChild("SellSkin", 10)

-- Helper: create UICorner
local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
end

-- Helper: create UIStroke (neon border)
local function addStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(255, 255, 255)
	stroke.Thickness = thickness or 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

-- Helper: create text label
local function makeLabel(parent, text, size, font, color, zIndex)
	local lbl = Instance.new("TextLabel")
	lbl.Size = size or UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextScaled = true
	lbl.Font = font or Enum.Font.GothamBold
	lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	lbl.ZIndex = zIndex or 2
	lbl.Parent = parent
	return lbl
end

-- Helper: create frame with dark semi-transparent background
local function makeDarkFrame(name, size, position, parent, transparency)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	frame.BackgroundTransparency = transparency or 0.35
	frame.BorderSizePixel = 0
	frame.Parent = parent
	addCorner(frame, 12)
	return frame
end

-- ─────────────────────────────────────────────────────────
-- BOTTOM GRADIENT BACKDROP
-- ─────────────────────────────────────────────────────────
local BottomGradientFrame = Instance.new("Frame")
BottomGradientFrame.Name = "BottomGradient"
BottomGradientFrame.Size = UDim2.new(1, 0, 0, 120)
BottomGradientFrame.Position = UDim2.new(0, 0, 1, -120)
BottomGradientFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
BottomGradientFrame.BackgroundTransparency = 0
BottomGradientFrame.BorderSizePixel = 0
BottomGradientFrame.ZIndex = 1
BottomGradientFrame.Parent = ScreenGui

local bottomGrad = Instance.new("UIGradient")
bottomGrad.Rotation = 90
bottomGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(1, 0.55),
})
bottomGrad.Parent = BottomGradientFrame

-- ─────────────────────────────────────────────────────────
-- 1. MONEY DISPLAY (top-left)
-- ─────────────────────────────────────────────────────────
local MoneyFrame = makeDarkFrame(
	"MoneyFrame",
	UDim2.new(0, 220, 0, 72),
	UDim2.new(0, 16, 0, 16),
	ScreenGui
)
addStroke(MoneyFrame, Color3.fromRGB(255, 200, 30), 1.5)

local MoneyLabel = makeLabel(
	MoneyFrame,
	"💰 $0",
	UDim2.new(1, 0, 0.55, 0),
	Enum.Font.GothamBold,
	Color3.fromRGB(255, 220, 50)
)
MoneyLabel.Position = UDim2.new(0, 0, 0, 0)

local incomeRateLabel = Instance.new("TextLabel")
incomeRateLabel.Name = "IncomeRateLabel"
incomeRateLabel.Size = UDim2.new(1, -8, 0.42, 0)
incomeRateLabel.Position = UDim2.new(0, 4, 0.56, 0)
incomeRateLabel.BackgroundTransparency = 1
incomeRateLabel.Text = "📈 0$/s"
incomeRateLabel.TextScaled = true
incomeRateLabel.Font = Enum.Font.Gotham
incomeRateLabel.TextColor3 = Color3.fromRGB(80, 200, 100)
incomeRateLabel.TextTransparency = 0.25
incomeRateLabel.ZIndex = 2
incomeRateLabel.Parent = MoneyFrame

-- Income rate: sum IncomePerSecond from all skins owned by this player.
-- Recalculate every second by scanning workspace for owned skin bodies.
local lastIncomeCheck = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastIncomeCheck < 1 then return end
	lastIncomeCheck = now

	local total = 0
	local multiplier = LocalPlayer:GetAttribute("MoneyMultiplier") or 1
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == "Body" then
			local income = obj:GetAttribute("IncomePerSecond")
			if income and income > 0 then
				-- Check this skin belongs to the local player via owner attribute
				local ownerName = obj:GetAttribute("OwnerName")
				if ownerName == LocalPlayer.Name then
					total = total + income
				end
			end
		end
	end
	total = math.floor(total * multiplier)
	if incomeRateLabel then
		incomeRateLabel.Text = "📈 " .. total .. "$/s"
	end
end)

-- Money color flash tracking
local prevMoney = LocalPlayer:GetAttribute("Money") or 0

local function updateMoney()
	local money = LocalPlayer:GetAttribute("Money") or 0
	MoneyLabel.Text = "💰 $" .. tostring(money)
	-- Scale pulse tween
	MoneyFrame:TweenSize(
		UDim2.new(0, 240, 0, 78),
		Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.12, true,
		function()
			MoneyFrame:TweenSize(
				UDim2.new(0, 220, 0, 72),
				Enum.EasingDirection.Out, Enum.EasingStyle.Bounce, 0.18, true
			)
		end
	)
end

updateMoney()

-- Money color flash on change
LocalPlayer:GetAttributeChangedSignal("Money"):Connect(function()
	local newMoney = LocalPlayer:GetAttribute("Money") or 0
	if newMoney > prevMoney then
		MoneyLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		task.delay(0.3, function() MoneyLabel.TextColor3 = Color3.fromRGB(255, 220, 50) end)
	elseif newMoney < prevMoney then
		MoneyLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		task.delay(0.3, function() MoneyLabel.TextColor3 = Color3.fromRGB(255, 220, 50) end)
	end
	prevMoney = newMoney
	updateMoney()
end)

-- ─────────────────────────────────────────────────────────
-- 2. CARRYING BANNER (top-center)
-- ─────────────────────────────────────────────────────────
local CarryFrame = Instance.new("Frame")
CarryFrame.Name = "CarryBanner"
CarryFrame.Size = UDim2.new(0, 420, 0, 52)
CarryFrame.Position = UDim2.new(0.5, -210, 0, 16)
CarryFrame.BackgroundColor3 = Color3.fromRGB(220, 80, 20)
CarryFrame.BackgroundTransparency = 0.15
CarryFrame.BorderSizePixel = 0
CarryFrame.Visible = false
CarryFrame.Parent = ScreenGui
addCorner(CarryFrame, 12)
addStroke(CarryFrame, Color3.fromRGB(255, 120, 30), 1.5)

local CarryLabel = makeLabel(CarryFrame, "🏃 Carrying Skin! Run to your base!", nil, Enum.Font.GothamBold, Color3.fromRGB(255, 255, 255))

-- Pulsing glow animation
local carryPulseTween
local function startCarryPulse()
	if carryPulseTween then carryPulseTween:Cancel() end
	local tweenIn = TweenService:Create(CarryFrame, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		BackgroundTransparency = 0.55
	})
	carryPulseTween = tweenIn
	tweenIn:Play()
end

local function stopCarryPulse()
	if carryPulseTween then
		carryPulseTween:Cancel()
		carryPulseTween = nil
	end
	CarryFrame.BackgroundTransparency = 0.15
end

local function updateCarrying()
	local carrying = LocalPlayer:GetAttribute("IsCarrying")
	if carrying then
		local skinName = LocalPlayer:GetAttribute("CarryingSkinName") or "Skin"
		CarryLabel.Text = "🏃 Carrying " .. skinName .. "! Run to your base!"
		CarryFrame.Visible = true
		startCarryPulse()
	else
		stopCarryPulse()
		CarryFrame.Visible = false
	end
end

updateCarrying()
LocalPlayer:GetAttributeChangedSignal("IsCarrying"):Connect(updateCarrying)
LocalPlayer:GetAttributeChangedSignal("CarryingSkinName"):Connect(updateCarrying)

-- ─────────────────────────────────────────────────────────
-- 3. REBIRTH INFO (top-right)
-- ─────────────────────────────────────────────────────────
local RebirthFrame = makeDarkFrame(
	"RebirthFrame",
	UDim2.new(0, 260, 0, 52),
	UDim2.new(1, -276, 0, 16),
	ScreenGui
)
addStroke(RebirthFrame, Color3.fromRGB(160, 100, 255), 1.5)

local RebirthLabel = makeLabel(RebirthFrame, "🌀 Rebirths: 0 | Multiplier: x1", nil, Enum.Font.Gotham, Color3.fromRGB(180, 140, 255))

local function updateRebirth()
	local count = LocalPlayer:GetAttribute("RebirthCount") or 0
	local mult = LocalPlayer:GetAttribute("Multiplier") or 1
	RebirthLabel.Text = "🌀 Rebirths: " .. count .. " | Multiplier: x" .. mult
end

updateRebirth()
LocalPlayer:GetAttributeChangedSignal("RebirthCount"):Connect(updateRebirth)
LocalPlayer:GetAttributeChangedSignal("Multiplier"):Connect(updateRebirth)

-- ─────────────────────────────────────────────────────────
-- 4. REBIRTH BUTTON (right side, middle — replaces old Lock Base button)
-- ─────────────────────────────────────────────────────────
local RebirthBtnFrame = makeDarkFrame(
	"RebirthBtnFrame",
	UDim2.new(0, 160, 0, 58),
	UDim2.new(1, -176, 0.5, -29),
	ScreenGui
)
addStroke(RebirthBtnFrame, Color3.fromRGB(180, 80, 255), 1.5)

local RebirthActionBtn = Instance.new("TextButton")
RebirthActionBtn.Name               = "RebirthButton"
RebirthActionBtn.Size               = UDim2.new(1, 0, 1, 0)
RebirthActionBtn.BackgroundTransparency = 1
RebirthActionBtn.Text               = "🌀 Rebirth\n$8000"
RebirthActionBtn.TextScaled         = true
RebirthActionBtn.Font               = Enum.Font.GothamBold
RebirthActionBtn.TextColor3         = Color3.fromRGB(200, 150, 255)
RebirthActionBtn.ZIndex             = 3
RebirthActionBtn.Parent             = RebirthBtnFrame

local RebirthRemote = RemoteEvents and RemoteEvents:WaitForChild("Rebirth", 10)
local rebirthCooldown = false

RebirthActionBtn.MouseButton1Click:Connect(function()
	if rebirthCooldown then return end
	rebirthCooldown = true
	RebirthActionBtn.TextColor3 = Color3.fromRGB(120, 80, 160)
	task.delay(3, function()
		rebirthCooldown = false
		RebirthActionBtn.TextColor3 = Color3.fromRGB(200, 150, 255)
	end)
	if RebirthRemote then RebirthRemote:FireServer() end
end)

-- ─────────────────────────────────────────────────────────
-- 5. NOTIFICATION TOAST SYSTEM
-- ─────────────────────────────────────────────────────────
local TOAST_WIDTH  = 320
local TOAST_HEIGHT = 52
local TOAST_PADDING = 8
local MAX_TOASTS   = 3
local activeToasts = {}

local function removeToast(toastFrame)
	local idx = table.find(activeToasts, toastFrame)
	if idx then table.remove(activeToasts, idx) end
	-- Slide out to right
	TweenService:Create(toastFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(1, 20, toastFrame.Position.Y.Scale, toastFrame.Position.Y.Offset)
	}):Play()
	task.delay(0.4, function()
		toastFrame:Destroy()
		-- Reposition remaining toasts
		for i, t in ipairs(activeToasts) do
			TweenService:Create(t, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(1, -(TOAST_WIDTH + 16), 0, 80 + (i - 1) * (TOAST_HEIGHT + TOAST_PADDING))
			}):Play()
		end
	end)
end

local function showToast(message, color)
	-- Evict oldest if at max
	while #activeToasts >= MAX_TOASTS do
		removeToast(activeToasts[1])
		task.wait()
	end

	local bgColor = color or Color3.fromRGB(40, 80, 160)
	local slotIndex = #activeToasts + 1
	local yOffset = 80 + (slotIndex - 1) * (TOAST_HEIGHT + TOAST_PADDING)

	local toastFrame = Instance.new("Frame")
	toastFrame.Name = "Toast"
	toastFrame.Size = UDim2.new(0, TOAST_WIDTH, 0, TOAST_HEIGHT)
	toastFrame.Position = UDim2.new(1, 20, 0, yOffset)  -- starts off-screen right
	toastFrame.BackgroundColor3 = bgColor
	toastFrame.BackgroundTransparency = 0.1
	toastFrame.BorderSizePixel = 0
	toastFrame.ZIndex = 10
	toastFrame.Parent = ScreenGui
	addCorner(toastFrame, 10)

	local toastLabel = Instance.new("TextLabel")
	toastLabel.Size = UDim2.new(1, -16, 1, 0)
	toastLabel.Position = UDim2.new(0, 8, 0, 0)
	toastLabel.BackgroundTransparency = 1
	toastLabel.Text = message
	toastLabel.TextScaled = true
	toastLabel.Font = Enum.Font.Gotham
	toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	toastLabel.TextXAlignment = Enum.TextXAlignment.Left
	toastLabel.ZIndex = 11
	toastLabel.Parent = toastFrame

	table.insert(activeToasts, toastFrame)

	-- Slide in
	TweenService:Create(toastFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -(TOAST_WIDTH + 16), 0, yOffset)
	}):Play()

	-- Auto-dismiss after 3s
	task.delay(3, function()
		if toastFrame and toastFrame.Parent then
			removeToast(toastFrame)
		end
	end)
end

if NotificationEvent then
	NotificationEvent.OnClientEvent:Connect(function(message, color)
		showToast(message, color)
	end)
end

-- ─────────────────────────────────────────────────────────
-- 6. STEAL ALERT (red flash + UIStroke border + toast)
-- ─────────────────────────────────────────────────────────
local StealFlash = Instance.new("Frame")
StealFlash.Name = "StealFlash"
StealFlash.Size = UDim2.new(1, 0, 1, 0)
StealFlash.Position = UDim2.new(0, 0, 0, 0)
StealFlash.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
StealFlash.BackgroundTransparency = 1
StealFlash.BorderSizePixel = 0
StealFlash.ZIndex = 20
StealFlash.Parent = ScreenGui

local function doRedFlash()
	StealFlash.BackgroundTransparency = 0.35
	TweenService:Create(StealFlash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	}):Play()
end

-- Red UIStroke border on ScreenGui root frame for "base under attack"
local attackBorderStroke = Instance.new("UIStroke")
attackBorderStroke.Color = Color3.fromRGB(230, 30, 30)
attackBorderStroke.Thickness = 6
attackBorderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
attackBorderStroke.Transparency = 1
attackBorderStroke.Parent = ScreenGui

-- We attach the stroke to a full-screen frame so it renders as a screen border
local AttackBorderFrame = Instance.new("Frame")
AttackBorderFrame.Name = "AttackBorderFrame"
AttackBorderFrame.Size = UDim2.new(1, 0, 1, 0)
AttackBorderFrame.Position = UDim2.new(0, 0, 0, 0)
AttackBorderFrame.BackgroundTransparency = 1
AttackBorderFrame.BorderSizePixel = 0
AttackBorderFrame.ZIndex = 19
AttackBorderFrame.Parent = ScreenGui

local attackBorder = Instance.new("UIStroke")
attackBorder.Color = Color3.fromRGB(230, 30, 30)
attackBorder.Thickness = 8
attackBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
attackBorder.Transparency = 1
attackBorder.Parent = AttackBorderFrame

local function showAttackBorder()
	-- Fade in
	TweenService:Create(attackBorder, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 0
	}):Play()
	-- Fade out after 2 seconds
	task.delay(2, function()
		TweenService:Create(attackBorder, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1
		}):Play()
	end)
end

if SkinStolenEvent then
	SkinStolenEvent.OnClientEvent:Connect(function(thiefName, skinName)
		doRedFlash()
		showAttackBorder()
		showToast(
			"😡 " .. (thiefName or "Someone") .. " stole your " .. (skinName or "Skin") .. "!",
			Color3.fromRGB(180, 30, 30)
		)
	end)
end

-- ─────────────────────────────────────────────────────────
-- 7. CLAIM CELEBRATION (green flash + floating text)
-- ─────────────────────────────────────────────────────────
local ClaimFlash = Instance.new("Frame")
ClaimFlash.Name = "ClaimFlash"
ClaimFlash.Size = UDim2.new(1, 0, 1, 0)
ClaimFlash.Position = UDim2.new(0, 0, 0, 0)
ClaimFlash.BackgroundColor3 = Color3.fromRGB(30, 200, 80)
ClaimFlash.BackgroundTransparency = 1
ClaimFlash.BorderSizePixel = 0
ClaimFlash.ZIndex = 20
ClaimFlash.Parent = ScreenGui

local function doGreenFlash()
	ClaimFlash.BackgroundTransparency = 0.45
	TweenService:Create(ClaimFlash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	}):Play()
end

local function spawnClaimPopup(skinName)
	local popup = Instance.new("TextLabel")
	popup.Name = "ClaimPopup"
	popup.Size = UDim2.new(0, 400, 0, 70)
	popup.Position = UDim2.new(0.5, -200, 0.5, 0)
	popup.BackgroundTransparency = 1
	popup.Text = "⭐ " .. (skinName or "Skin") .. " CLAIMED!"
	popup.TextScaled = true
	popup.Font = Enum.Font.GothamBold
	popup.TextColor3 = Color3.fromRGB(255, 215, 0)
	popup.ZIndex = 21
	popup.TextTransparency = 0
	popup.Parent = ScreenGui

	-- Float up and fade
	TweenService:Create(popup, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -200, 0.3, 0),
		TextTransparency = 1
	}):Play()

	task.delay(1.5, function()
		popup:Destroy()
	end)
end

if SkinClaimedEvent then
	SkinClaimedEvent.OnClientEvent:Connect(function(skinName)
		doGreenFlash()
		spawnClaimPopup(skinName)
	end)
end

-- ─────────────────────────────────────────────────────────
-- 8. REBIRTH ANIMATION (full-screen white flash + big text)
-- ─────────────────────────────────────────────────────────
local RebirthFlash = Instance.new("Frame")
RebirthFlash.Name = "RebirthFlash"
RebirthFlash.Size = UDim2.new(1, 0, 1, 0)
RebirthFlash.Position = UDim2.new(0, 0, 0, 0)
RebirthFlash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
RebirthFlash.BackgroundTransparency = 1
RebirthFlash.BorderSizePixel = 0
RebirthFlash.ZIndex = 25
RebirthFlash.Parent = ScreenGui

local RebirthBigLabel = Instance.new("TextLabel")
RebirthBigLabel.Name = "RebirthBigText"
RebirthBigLabel.Size = UDim2.new(0.8, 0, 0, 100)
RebirthBigLabel.Position = UDim2.new(0.1, 0, 0.38, 0)
RebirthBigLabel.BackgroundTransparency = 1
RebirthBigLabel.Text = ""
RebirthBigLabel.TextScaled = true
RebirthBigLabel.Font = Enum.Font.GothamBold
RebirthBigLabel.TextColor3 = Color3.fromRGB(120, 50, 255)
RebirthBigLabel.TextTransparency = 1
RebirthBigLabel.ZIndex = 26
RebirthBigLabel.Parent = ScreenGui

if RebirthCompleteEvent then
	RebirthCompleteEvent.OnClientEvent:Connect(function(multiplier)
		RebirthBigLabel.Text = "🌀 REBORN!  x" .. (multiplier or "?") .. " MULTIPLIER!"
		RebirthBigLabel.TextTransparency = 0
		RebirthFlash.BackgroundTransparency = 0

		TweenService:Create(RebirthFlash, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1
		}):Play()

		TweenService:Create(RebirthBigLabel, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1
		}):Play()
	end)
end

-- ─────────────────────────────────────────────────────────
-- 9. HOW-TO-PLAY HINT (bottom-left, fades after 10s)
-- ─────────────────────────────────────────────────────────
local HintFrame = makeDarkFrame(
	"HintFrame",
	UDim2.new(0, 360, 0, 46),
	UDim2.new(0, 16, 1, -62),
	ScreenGui,
	0.45
)

makeLabel(
	HintFrame,
	"Touch enemy skins to steal | Return to base to claim | Shop in center",
	nil,
	Enum.Font.Gotham,
	Color3.fromRGB(210, 210, 210)
)

task.delay(10, function()
	TweenService:Create(HintFrame, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	}):Play()
	for _, child in ipairs(HintFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 1
			}):Play()
		end
	end
	task.delay(1.3, function()
		HintFrame.Visible = false
	end)
end)

-- ─────────────────────────────────────────────────────────
-- 10. SHOP & POKÉDEX BUTTONS (bottom-right)
-- ─────────────────────────────────────────────────────────
local BottomRightHolder = Instance.new("Frame")
BottomRightHolder.Name = "BottomRightButtons"
BottomRightHolder.Size = UDim2.new(0, 260, 0, 50)
BottomRightHolder.Position = UDim2.new(1, -276, 1, -68)
BottomRightHolder.BackgroundTransparency = 1
BottomRightHolder.Parent = ScreenGui

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.FillDirection = Enum.FillDirection.Horizontal
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
UIListLayout.Padding = UDim.new(0, 10)
UIListLayout.Parent = BottomRightHolder

local function makeBottomButton(text, color, strokeColor, parent)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 120, 0, 50)
	btn.BackgroundColor3 = color
	btn.BackgroundTransparency = 0.15
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.ZIndex = 3
	btn.Parent = parent
	addCorner(btn, 10)
	addStroke(btn, strokeColor or color, 1.5)

	-- Hover effect
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 0.15}):Play()
	end)

	return btn
end

local ShopButton = makeBottomButton("🛒 SHOP", Color3.fromRGB(30, 130, 200), Color3.fromRGB(80, 180, 255), BottomRightHolder)
local PokedexButton = makeBottomButton("📖 POKÉDEX", Color3.fromRGB(80, 170, 60), Color3.fromRGB(120, 220, 80), BottomRightHolder)

ShopButton.MouseButton1Click:Connect(function()
	if OpenShopRemote then OpenShopRemote:FireServer() end
end)

PokedexButton.MouseButton1Click:Connect(function()
	if OpenPokedexRemote then OpenPokedexRemote:FireServer() end
end)

-- ─────────────────────────────────────────────────────────
-- Keyboard shortcuts: N = Shop, M = Pokédex
-- ─────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.N then
		if OpenShopRemote then OpenShopRemote:FireServer() end
	elseif input.KeyCode == Enum.KeyCode.M then
		if OpenPokedexRemote then OpenPokedexRemote:FireServer() end
	end
end)

-- ─────────────────────────────────────────────────────────
-- F-hold to sell carried skin (2-second hold)
-- ─────────────────────────────────────────────────────────
local SELL_HOLD_DURATION = 2

-- Sell progress bar UI
local SellFrame = Instance.new("Frame")
SellFrame.Name              = "SellFrame"
SellFrame.Size              = UDim2.new(0, 260, 0, 52)
SellFrame.Position          = UDim2.new(0.5, -130, 0.82, 0)
SellFrame.BackgroundColor3  = Color3.fromRGB(20, 20, 20)
SellFrame.BackgroundTransparency = 0.3
SellFrame.BorderSizePixel   = 0
SellFrame.Visible           = false
SellFrame.ZIndex            = 10
SellFrame.Parent            = ScreenGui
addCorner(SellFrame, 8)

local SellLabel = Instance.new("TextLabel")
SellLabel.Size               = UDim2.new(1, 0, 0.45, 0)
SellLabel.Position           = UDim2.new(0, 0, 0, 0)
SellLabel.BackgroundTransparency = 1
SellLabel.Text               = "HOLD F — DISCARD SKIN"
SellLabel.TextScaled         = true
SellLabel.Font               = Enum.Font.GothamBold
SellLabel.TextColor3         = Color3.fromRGB(255, 160, 50)
SellLabel.ZIndex             = 11
SellLabel.Parent             = SellFrame

local SellBarBg = Instance.new("Frame")
SellBarBg.Size              = UDim2.new(0.92, 0, 0.35, 0)
SellBarBg.Position          = UDim2.new(0.04, 0, 0.58, 0)
SellBarBg.BackgroundColor3  = Color3.fromRGB(60, 60, 60)
SellBarBg.BorderSizePixel   = 0
SellBarBg.ZIndex            = 11
SellBarBg.Parent            = SellFrame
addCorner(SellBarBg, 5)

local SellBarFill = Instance.new("Frame")
SellBarFill.Size            = UDim2.new(0, 0, 1, 0)
SellBarFill.BackgroundColor3 = Color3.fromRGB(255, 120, 30)
SellBarFill.BorderSizePixel = 0
SellBarFill.ZIndex          = 12
SellBarFill.Parent          = SellBarBg
addCorner(SellBarFill, 5)

local sellHoldStart = nil
local sellHoldConn  = nil

local function cancelSell()
	sellHoldStart = nil
	if sellHoldConn then sellHoldConn:Disconnect(); sellHoldConn = nil end
	SellFrame.Visible = false
	SellBarFill.Size  = UDim2.new(0, 0, 1, 0)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.F then return end
	if not LocalPlayer:GetAttribute("IsCarrying") then return end
	if sellHoldStart then return end  -- already holding

	sellHoldStart     = tick()
	SellFrame.Visible = true

	sellHoldConn = RunService.Heartbeat:Connect(function()
		if not sellHoldStart then cancelSell(); return end
		local elapsed = tick() - sellHoldStart
		local frac    = math.min(elapsed / SELL_HOLD_DURATION, 1)
		SellBarFill.Size = UDim2.new(frac, 0, 1, 0)
		if elapsed >= SELL_HOLD_DURATION then
			cancelSell()
			if SellSkinRemote then SellSkinRemote:FireServer() end
		end
	end)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		cancelSell()
	end
end)

-- ─────────────────────────────────────────────────────────
-- 11. "E TO BUY" PROXIMITY HINT (bottom-center)
-- ─────────────────────────────────────────────────────────
local BuyHintFrame = makeDarkFrame(
	"BuyHintFrame",
	UDim2.new(0, 340, 0, 46),
	UDim2.new(0.5, -170, 1, -80),
	ScreenGui,
	0.3
)
BuyHintFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
BuyHintFrame.BackgroundTransparency = 1
BuyHintFrame.ZIndex = 4

local BuyHintLabel = makeLabel(
	BuyHintFrame,
	"Press E near a skin to buy it",
	nil,
	Enum.Font.Gotham,
	Color3.fromRGB(220, 220, 255),
	5
)
BuyHintLabel.TextTransparency = 1

addStroke(BuyHintFrame, Color3.fromRGB(140, 100, 255), 1.5)

local buyHintVisible = false

local function showBuyHint()
	if buyHintVisible then return end
	buyHintVisible = true
	TweenService:Create(BuyHintFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.3
	}):Play()
	TweenService:Create(BuyHintLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0
	}):Play()
end

local function hideBuyHint()
	if not buyHintVisible then return end
	buyHintVisible = false
	TweenService:Create(BuyHintFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	}):Play()
	TweenService:Create(BuyHintLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1
	}):Play()
end

-- Check proximity to conveyor belt every heartbeat (sampled every 0.5s for perf)
local lastProximityCheck = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastProximityCheck < 0.5 then return end
	lastProximityCheck = now

	local character = LocalPlayer.Character
	if not character then
		hideBuyHint()
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		hideBuyHint()
		return
	end

	-- Belt runs along Z; show hint when player is near X=0 (center road)
	local x = rootPart.Position.X
	if math.abs(x) < 20 then
		showBuyHint()
	else
		hideBuyHint()
	end
end)

-- ─────────────────────────────────────────────────────────
-- 12. GACHA SPINNING WHEEL
-- ─────────────────────────────────────────────────────────
local GachaResultEvent = RemoteEvents and RemoteEvents:WaitForChild("GachaResult", 10)

local RARITY_SLOTS = {
	{ name = "Common",    color = Color3.fromRGB(160, 160, 160) },
	{ name = "Uncommon",  color = Color3.fromRGB(50,  200, 80)  },
	{ name = "Rare",      color = Color3.fromRGB(60,  120, 255) },
	{ name = "Epic",      color = Color3.fromRGB(180, 0,   255) },
	{ name = "Legendary", color = Color3.fromRGB(255, 200, 0)   },
}
local RARITY_INDEX_MAP = {}
for i, r in ipairs(RARITY_SLOTS) do RARITY_INDEX_MAP[r.name] = i end

-- Build wheel overlay (hidden by default)
local WheelGui = Instance.new("ScreenGui")
WheelGui.Name         = "GachaWheelGui"
WheelGui.ResetOnSpawn = false
WheelGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
WheelGui.Enabled      = false
WheelGui.Parent       = PlayerGui

local WheelOverlay = Instance.new("Frame")
WheelOverlay.Size                   = UDim2.new(1, 0, 1, 0)
WheelOverlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
WheelOverlay.BackgroundTransparency = 0.45
WheelOverlay.BorderSizePixel        = 0
WheelOverlay.ZIndex                 = 2
WheelOverlay.Parent                 = WheelGui

local WheelPanel = Instance.new("Frame")
WheelPanel.Size             = UDim2.new(0, 500, 0, 320)
WheelPanel.Position         = UDim2.new(0.5, -250, 0.5, -160)
WheelPanel.BackgroundColor3 = Color3.fromRGB(16, 14, 28)
WheelPanel.BorderSizePixel  = 0
WheelPanel.ZIndex           = 3
WheelPanel.Parent           = WheelGui
local wpCorner = Instance.new("UICorner")
wpCorner.CornerRadius = UDim.new(0, 18)
wpCorner.Parent = WheelPanel
local wpStroke = Instance.new("UIStroke")
wpStroke.Color = Color3.fromRGB(200, 100, 255)
wpStroke.Thickness = 2.5
wpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
wpStroke.Parent = WheelPanel

local WheelTitle = Instance.new("TextLabel")
WheelTitle.Size                   = UDim2.new(1, 0, 0, 48)
WheelTitle.Position               = UDim2.new(0, 0, 0, 0)
WheelTitle.BackgroundTransparency = 1
WheelTitle.Text                   = "🎰  GACHA SPIN"
WheelTitle.TextScaled             = true
WheelTitle.Font                   = Enum.Font.GothamBold
WheelTitle.TextColor3             = Color3.fromRGB(255, 220, 50)
WheelTitle.ZIndex                 = 4
WheelTitle.Parent                 = WheelPanel

-- Reel viewport: clips the scrolling strip
local ReelViewport = Instance.new("Frame")
ReelViewport.Size             = UDim2.new(1, -40, 0, 90)
ReelViewport.Position         = UDim2.new(0, 20, 0, 58)
ReelViewport.BackgroundColor3 = Color3.fromRGB(5, 5, 10)
ReelViewport.ClipsDescendants = true
ReelViewport.BorderSizePixel  = 0
ReelViewport.ZIndex           = 4
ReelViewport.Parent           = WheelPanel
local rvCorner = Instance.new("UICorner")
rvCorner.CornerRadius = UDim.new(0, 10)
rvCorner.Parent = ReelViewport

-- Pointer indicator (centered triangle/bar over the reel)
local Pointer = Instance.new("Frame")
Pointer.Size             = UDim2.new(0, 4, 1, 0)
Pointer.Position         = UDim2.new(0.5, -2, 0, 0)
Pointer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Pointer.BorderSizePixel  = 0
Pointer.ZIndex           = 6
Pointer.Parent           = ReelViewport

-- Scrolling reel strip (contains rarity slots side by side, wider than viewport)
local SLOT_WIDTH  = 100
local SLOT_HEIGHT = 88
local NUM_COPIES  = 4  -- repeat rarities several times for seamless looping
local ReelStrip = Instance.new("Frame")
ReelStrip.BackgroundTransparency = 1
ReelStrip.BorderSizePixel        = 0
ReelStrip.ZIndex                 = 5
ReelStrip.Parent                 = ReelViewport

local slotParts = {}
for copy = 0, NUM_COPIES - 1 do
	for i, rarity in ipairs(RARITY_SLOTS) do
		local idx = copy * #RARITY_SLOTS + i
		local slot = Instance.new("Frame")
		slot.Size             = UDim2.new(0, SLOT_WIDTH - 4, 0, SLOT_HEIGHT - 4)
		slot.BackgroundColor3 = rarity.color
		slot.BorderSizePixel  = 0
		slot.ZIndex           = 5
		slot.Parent           = ReelStrip
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(0, 8)
		sc.Parent = slot

		local slotLbl = Instance.new("TextLabel")
		slotLbl.Size                   = UDim2.new(1, 0, 1, 0)
		slotLbl.BackgroundTransparency = 1
		slotLbl.Text                   = rarity.name
		slotLbl.TextScaled             = true
		slotLbl.Font                   = Enum.Font.GothamBold
		slotLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
		slotLbl.TextStrokeTransparency = 0.3
		slotLbl.ZIndex                 = 6
		slotLbl.Parent                 = slot

		slotParts[idx] = slot
	end
end

local TOTAL_STRIP_WIDTH = #RARITY_SLOTS * NUM_COPIES * SLOT_WIDTH
ReelStrip.Size = UDim2.new(0, TOTAL_STRIP_WIDTH, 0, SLOT_HEIGHT)

-- Result display (appears after wheel stops)
local WheelResult = Instance.new("Frame")
WheelResult.Size             = UDim2.new(1, -40, 0, 80)
WheelResult.Position         = UDim2.new(0, 20, 0, 160)
WheelResult.BackgroundTransparency = 1
WheelResult.BorderSizePixel  = 0
WheelResult.ZIndex           = 4
WheelResult.Visible          = false
WheelResult.Parent           = WheelPanel

local WheelResultLabel = Instance.new("TextLabel")
WheelResultLabel.Size                   = UDim2.new(1, 0, 1, 0)
WheelResultLabel.BackgroundTransparency = 1
WheelResultLabel.Text                   = ""
WheelResultLabel.TextScaled             = true
WheelResultLabel.Font                   = Enum.Font.GothamBold
WheelResultLabel.TextColor3             = Color3.fromRGB(255, 220, 50)
WheelResultLabel.ZIndex                 = 5
WheelResultLabel.Parent                 = WheelResult

local WheelCloseBtn = Instance.new("TextButton")
WheelCloseBtn.Size             = UDim2.new(0, 160, 0, 44)
WheelCloseBtn.Position         = UDim2.new(0.5, -80, 0, 260)
WheelCloseBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
WheelCloseBtn.BorderSizePixel  = 0
WheelCloseBtn.Text             = "Continue"
WheelCloseBtn.TextScaled       = true
WheelCloseBtn.Font             = Enum.Font.GothamBold
WheelCloseBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
WheelCloseBtn.ZIndex           = 4
WheelCloseBtn.Visible          = false
WheelCloseBtn.Parent           = WheelPanel
local wcbCorner = Instance.new("UICorner")
wcbCorner.CornerRadius = UDim.new(0, 10)
wcbCorner.Parent = WheelCloseBtn

WheelCloseBtn.MouseButton1Click:Connect(function()
	WheelGui.Enabled = false
	WheelResult.Visible   = false
	WheelCloseBtn.Visible = false
end)

-- Position all reel slots
local function layoutReelStrip(offsetX)
	for i, slot in ipairs(slotParts) do
		local baseX = (i - 1) * SLOT_WIDTH + 2
		slot.Position = UDim2.new(0, baseX + offsetX, 0, 2)
	end
end
layoutReelStrip(0)

-- Wheel spin state
local wheelSpinning = false
local wheelOffsetX  = 0

-- Start the spin animation
local function startGachaWheel()
	if wheelSpinning then return end
	wheelSpinning    = true
	WheelGui.Enabled = true
	WheelResult.Visible   = false
	WheelCloseBtn.Visible = false
	wheelOffsetX = 0
end

-- Stop the wheel on a specific rarity
local function stopGachaWheel(resultData)
	wheelSpinning = false

	-- Snap to the target rarity slot in the last copy of the strip
	local targetRarityIdx = RARITY_INDEX_MAP[resultData.rarity] or 1
	-- Position so that the target slot is centered under the pointer
	local viewportHalfW = 230  -- approx half of viewport width
	local targetCopy = NUM_COPIES - 1  -- land on the last copy
	local targetSlotIdx = targetCopy * #RARITY_SLOTS + targetRarityIdx
	local targetCenterX = (targetSlotIdx - 1) * SLOT_WIDTH + SLOT_WIDTH / 2
	local finalOffset = viewportHalfW - targetCenterX
	layoutReelStrip(finalOffset)

	-- Show result
	local rc = Color3.fromRGB(255, 220, 50)
	if resultData.rarity == "Common"    then rc = Color3.fromRGB(160, 160, 160)
	elseif resultData.rarity == "Uncommon"  then rc = Color3.fromRGB(50, 200, 80)
	elseif resultData.rarity == "Rare"      then rc = Color3.fromRGB(60, 120, 255)
	elseif resultData.rarity == "Epic"      then rc = Color3.fromRGB(180, 0, 255)
	elseif resultData.rarity == "Legendary" then rc = Color3.fromRGB(255, 200, 0)
	end
	WheelResultLabel.TextColor3 = rc
	WheelResultLabel.Text       = "✨ " .. (resultData.rarity or "?") .. "\n" .. (resultData.name or "?") .. "  +" .. (resultData.income or 0) .. "$/s"
	WheelResult.Visible   = true
	WheelCloseBtn.Visible = true
end

-- Animate the reel strip while spinning
local SPIN_SPEED_FAST = 600   -- px / second
RunService.Heartbeat:Connect(function(dt)
	if not wheelSpinning then return end
	wheelOffsetX = wheelOffsetX - SPIN_SPEED_FAST * dt
	-- Loop: when we've scrolled past one full repeat, reset
	local loopWidth = #RARITY_SLOTS * SLOT_WIDTH
	if wheelOffsetX < -loopWidth then
		wheelOffsetX = wheelOffsetX + loopWidth
	end
	layoutReelStrip(wheelOffsetX)
end)

-- Listen for GachaResult from server
if GachaResultEvent then
	GachaResultEvent.OnClientEvent:Connect(function(resultData)
		-- If wheel isn't showing (e.g. gacha pad touch without shop open), still show it
		if not WheelGui.Enabled then
			startGachaWheel()
		end
		-- Let it spin for 2s then land on result
		task.delay(2, function()
			stopGachaWheel(resultData)
		end)
	end)
end

-- Also hook into SpinGacha: start wheel whenever a spin is fired
-- (This covers the shop SpinBtn path AND gacha pad path)
local SpinGachaRemote = RemoteEvents and RemoteEvents:WaitForChild("SpinGacha", 10)
-- We can't directly listen for client fires, but GachaResultEvent covers the response.
-- The pad touch is server-only; wheel starts when GachaResult arrives.
