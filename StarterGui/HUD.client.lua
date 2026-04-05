-- HUD.client.lua
-- StarterGui LocalScript for Skibidi Tentafruit Heist
-- Handles all in-game HUD elements

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local BrainrotStolenEvent = RemoteEvents and RemoteEvents:WaitForChild("BrainrotStolen", 10)
local BrainrotClaimedEvent = RemoteEvents and RemoteEvents:WaitForChild("BrainrotClaimed", 10)
local RebirthCompleteEvent = RemoteEvents and RemoteEvents:WaitForChild("RebirthComplete", 10)
local LockBaseRemote      = RemoteEvents and RemoteEvents:WaitForChild("LockBase", 10)
local OpenShopRemote      = RemoteEvents and RemoteEvents:WaitForChild("OpenShop", 10)
local OpenPokedexRemote   = RemoteEvents and RemoteEvents:WaitForChild("OpenPokedex", 10)

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

-- Income rate tracking
local lastMoney = LocalPlayer:GetAttribute("Money") or 0
local lastTime = tick()
local currentIncomeRate = 0

RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastTime >= 2 then
		local currentMoney = LocalPlayer:GetAttribute("Money") or 0
		local gained = currentMoney - lastMoney
		if gained > 0 then
			currentIncomeRate = math.floor(gained / (now - lastTime))
		end
		lastMoney = currentMoney
		lastTime = now
		if incomeRateLabel then
			incomeRateLabel.Text = "📈 " .. currentIncomeRate .. "$/s"
		end
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

local CarryLabel = makeLabel(CarryFrame, "🏃 Carrying Brainrot! Run to your base!", nil, Enum.Font.GothamBold, Color3.fromRGB(255, 255, 255))

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
		local brainrotName = LocalPlayer:GetAttribute("CarryingBrainrotName") or "Brainrot"
		CarryLabel.Text = "🏃 Carrying " .. brainrotName .. "! Run to your base!"
		CarryFrame.Visible = true
		startCarryPulse()
	else
		stopCarryPulse()
		CarryFrame.Visible = false
	end
end

updateCarrying()
LocalPlayer:GetAttributeChangedSignal("IsCarrying"):Connect(updateCarrying)
LocalPlayer:GetAttributeChangedSignal("CarryingBrainrotName"):Connect(updateCarrying)

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
-- 4. BASE LOCK BUTTON (right side, middle)
-- ─────────────────────────────────────────────────────────
local LockFrame = makeDarkFrame(
	"LockFrame",
	UDim2.new(0, 160, 0, 58),
	UDim2.new(1, -176, 0.5, -29),
	ScreenGui
)
addStroke(LockFrame, Color3.fromRGB(80, 200, 255), 1.5)

local LockButton = Instance.new("TextButton")
LockButton.Name = "LockButton"
LockButton.Size = UDim2.new(1, 0, 1, 0)
LockButton.BackgroundTransparency = 1
LockButton.Text = "🔒 Lock Base"
LockButton.TextScaled = true
LockButton.Font = Enum.Font.GothamBold
LockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
LockButton.ZIndex = 3
LockButton.Parent = LockFrame

local LOCK_COOLDOWN = 30
local lockOnCooldown = false
local lockCooldownConn

local function setLockCooldown()
	lockOnCooldown = true
	LockButton.TextColor3 = Color3.fromRGB(140, 140, 140)
	local function countdown(n)
		if n <= 0 then
			lockOnCooldown = false
			LockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			local locked = LocalPlayer:GetAttribute("BaseIsLocked")
			LockButton.Text = locked and "🔒 BASE LOCKED" or "🔒 Lock Base"
			return
		end
		LockButton.Text = "⏳ Recharging: " .. n .. "s"
		task.delay(1, function() countdown(n - 1) end)
	end
	countdown(LOCK_COOLDOWN)
end

local function updateLockVisual()
	if lockOnCooldown then return end
	local locked = LocalPlayer:GetAttribute("BaseIsLocked")
	if locked then
		LockButton.Text = "🔒 BASE LOCKED"
		LockButton.TextColor3 = Color3.fromRGB(80, 230, 100)
	else
		LockButton.Text = "🔒 Lock Base"
		LockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

updateLockVisual()
LocalPlayer:GetAttributeChangedSignal("BaseIsLocked"):Connect(updateLockVisual)

LockButton.MouseButton1Click:Connect(function()
	if lockOnCooldown then return end
	if LockBaseRemote then LockBaseRemote:FireServer() end
	setLockCooldown()
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

if BrainrotStolenEvent then
	BrainrotStolenEvent.OnClientEvent:Connect(function(thiefName, brainrotName)
		doRedFlash()
		showAttackBorder()
		showToast(
			"😡 " .. (thiefName or "Someone") .. " stole your " .. (brainrotName or "Brainrot") .. "!",
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

local function spawnClaimPopup(brainrotName)
	local popup = Instance.new("TextLabel")
	popup.Name = "ClaimPopup"
	popup.Size = UDim2.new(0, 400, 0, 70)
	popup.Position = UDim2.new(0.5, -200, 0.5, 0)
	popup.BackgroundTransparency = 1
	popup.Text = "⭐ " .. (brainrotName or "Brainrot") .. " CLAIMED!"
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

if BrainrotClaimedEvent then
	BrainrotClaimedEvent.OnClientEvent:Connect(function(brainrotName)
		doGreenFlash()
		spawnClaimPopup(brainrotName)
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
	"Touch enemy brainrots to steal | Return to base to claim | Shop in center",
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
	"Press E near a brainrot to buy it",
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

	local z = rootPart.Position.Z
	if z >= -15 and z <= 15 then
		showBuyHint()
	else
		hideBuyHint()
	end
end)
