-- ShopUI.client.lua
-- LocalScript: Full shop UI for Skibidi Tentafruit Heist
-- Place in StarterGui

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Modules      = ReplicatedStorage:WaitForChild("Modules")
local BrainrotData = require(Modules:WaitForChild("BrainrotData"))
local GameConfig   = require(Modules:WaitForChild("GameConfig"))

local RemoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenShopEvent   = RemoteEvents:WaitForChild("OpenShop")
local BuyBrainrotEvent = RemoteEvents:WaitForChild("BuyBrainrot")
local SpinGachaEvent  = RemoteEvents:WaitForChild("SpinGacha")
local RebirthEvent    = RemoteEvents:WaitForChild("Rebirth")
local GachaResultEvent = RemoteEvents:WaitForChild("GachaResult")

-- ============================================================
-- Constants
-- ============================================================

local RARITY_COLORS = GameConfig.RARITY_COLORS
local RARITY_ORDER  = GameConfig.RARITY_ORDER
local GACHA_COST    = GameConfig.GACHA_COST
local REBIRTH_COST  = GameConfig.REBIRTH_COST

local RARITY_BG = {
	Common    = Color3.fromRGB(55,  55,  60),
	Uncommon  = Color3.fromRGB(30,  65,  35),
	Rare      = Color3.fromRGB(20,  35,  80),
	Epic      = Color3.fromRGB(55,  15,  80),
	Legendary = Color3.fromRGB(80,  60,  10),
}

local GACHA_ODDS = {
	{ rarity = "Common",    chance = "50%" },
	{ rarity = "Uncommon",  chance = "25%" },
	{ rarity = "Rare",      chance = "12%" },
	{ rarity = "Epic",      chance = "5%"  },
	{ rarity = "Legendary", chance = "1%"  },
}

-- ============================================================
-- State
-- ============================================================

local activeFilter     = "ALL"
local activeTab        = "DIRECT"   -- "DIRECT" | "GACHA"
local recentPulls      = {}         -- last 5 gacha results
local shopOpen         = false
local gachaSpinning    = false
local cardButtons      = {}         -- { brainrotId -> buttonInstance }
local moneyConnection  = nil

-- ============================================================
-- Utility helpers
-- ============================================================

local function getMoney()
	return LocalPlayer:GetAttribute("Money") or 0
end

local function getCollection()
	-- collection is stored as attributes like "Own_<id>" => count
	-- Fallback: scan attributes
	local col = {}
	for _, entry in ipairs(BrainrotData.list) do
		local val = LocalPlayer:GetAttribute("Own_" .. entry.id)
		if val and val > 0 then
			col[entry.id] = val
		end
	end
	return col
end

local function makeCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function makeStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color     = color or Color3.fromRGB(255, 255, 255)
	stroke.Thickness = thickness or 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function makePadding(parent, px)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft   = UDim.new(0, px)
	pad.PaddingRight  = UDim.new(0, px)
	pad.PaddingTop    = UDim.new(0, px)
	pad.PaddingBottom = UDim.new(0, px)
	pad.Parent = parent
	return pad
end

local function tweenTransparency(obj, property, target, duration)
	local info = TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad)
	local tween = TweenService:Create(obj, info, { [property] = target })
	tween:Play()
	return tween
end

-- ============================================================
-- Build ScreenGui root
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name              = "ShopUI"
ScreenGui.ResetOnSpawn      = false
ScreenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset    = true
ScreenGui.Parent            = PlayerGui

-- ============================================================
-- Background overlay (click-outside-to-close)
-- ============================================================

local Overlay = Instance.new("TextButton")
Overlay.Name               = "Overlay"
Overlay.Size               = UDim2.new(1, 0, 1, 0)
Overlay.Position           = UDim2.new(0, 0, 0, 0)
Overlay.BackgroundColor3   = Color3.fromRGB(0, 0, 0)
Overlay.BackgroundTransparency = 0.55
Overlay.Text               = ""
Overlay.Visible            = false
Overlay.ZIndex             = 5
Overlay.Parent             = ScreenGui

-- ============================================================
-- Main shop panel (600 x 500, centered)
-- ============================================================

local Panel = Instance.new("Frame")
Panel.Name               = "ShopPanel"
Panel.Size               = UDim2.new(0, 600, 0, 500)
Panel.Position           = UDim2.new(0.5, -300, 0.5, -250)
Panel.BackgroundColor3   = Color3.fromRGB(22, 22, 30)
Panel.BorderSizePixel    = 0
Panel.Visible            = false
Panel.ZIndex             = 6
Panel.Parent             = ScreenGui
makeCorner(Panel, 12)
makeStroke(Panel, Color3.fromRGB(80, 80, 120), 2)

-- ============================================================
-- Panel header bar
-- ============================================================

local Header = Instance.new("Frame")
Header.Name             = "Header"
Header.Size             = UDim2.new(1, 0, 0, 48)
Header.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
Header.BorderSizePixel  = 0
Header.ZIndex           = 7
Header.Parent           = Panel
makeCorner(Header, 12)

-- Round only the top corners: cover bottom with an opaque strip
local HeaderFix = Instance.new("Frame")
HeaderFix.Size             = UDim2.new(1, 0, 0.5, 0)
HeaderFix.Position         = UDim2.new(0, 0, 0.5, 0)
HeaderFix.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
HeaderFix.BorderSizePixel  = 0
HeaderFix.ZIndex           = 7
HeaderFix.Parent           = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name             = "Title"
TitleLabel.Size             = UDim2.new(1, -60, 1, 0)
TitleLabel.Position         = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text             = "🛒 SKIBIDI TENTAFRUIT SHOP"
TitleLabel.TextColor3       = Color3.fromRGB(255, 255, 255)
TitleLabel.TextScaled       = true
TitleLabel.Font             = Enum.Font.GothamBold
TitleLabel.TextXAlignment   = Enum.TextXAlignment.Left
TitleLabel.ZIndex           = 8
TitleLabel.Parent           = Header

-- Money display inside header (top-right of panel)
local MoneyDisplay = Instance.new("TextLabel")
MoneyDisplay.Name             = "MoneyDisplay"
MoneyDisplay.Size             = UDim2.new(0, 130, 0, 28)
MoneyDisplay.Position         = UDim2.new(1, -186, 0.5, -14)
MoneyDisplay.BackgroundColor3 = Color3.fromRGB(40, 70, 40)
MoneyDisplay.TextColor3       = Color3.fromRGB(100, 255, 100)
MoneyDisplay.Text             = "$0"
MoneyDisplay.TextScaled       = true
MoneyDisplay.Font             = Enum.Font.GothamBold
MoneyDisplay.ZIndex           = 9
MoneyDisplay.Parent           = Header
makeCorner(MoneyDisplay, 6)
makePadding(MoneyDisplay, 4)

-- Close button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name             = "CloseBtn"
CloseBtn.Size             = UDim2.new(0, 36, 0, 36)
CloseBtn.Position         = UDim2.new(1, -44, 0.5, -18)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text             = "✕"
CloseBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
CloseBtn.TextScaled       = true
CloseBtn.Font             = Enum.Font.GothamBold
CloseBtn.ZIndex           = 10
CloseBtn.Parent           = Header
makeCorner(CloseBtn, 6)

-- ============================================================
-- Tab bar
-- ============================================================

local TabBar = Instance.new("Frame")
TabBar.Name             = "TabBar"
TabBar.Size             = UDim2.new(1, -24, 0, 36)
TabBar.Position         = UDim2.new(0, 12, 0, 52)
TabBar.BackgroundTransparency = 1
TabBar.ZIndex           = 7
TabBar.Parent           = Panel

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.SortOrder     = Enum.SortOrder.LayoutOrder
TabLayout.Padding       = UDim.new(0, 8)
TabLayout.Parent        = TabBar

local function makeTab(name, label, order)
	local btn = Instance.new("TextButton")
	btn.Name             = name
	btn.Size             = UDim2.new(0, 160, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	btn.Text             = label
	btn.TextColor3       = Color3.fromRGB(180, 180, 200)
	btn.TextScaled       = true
	btn.Font             = Enum.Font.GothamBold
	btn.LayoutOrder      = order
	btn.ZIndex           = 8
	btn.Parent           = TabBar
	makeCorner(btn, 6)
	return btn
end

local DirectTab = makeTab("DirectTab", "DIRECT BUY", 1)
local GachaTab  = makeTab("GachaTab",  "🎰 GACHA",   2)

-- ============================================================
-- Content area (below tabs)
-- ============================================================

local ContentArea = Instance.new("Frame")
ContentArea.Name             = "ContentArea"
ContentArea.Size             = UDim2.new(1, -24, 0, 346)
ContentArea.Position         = UDim2.new(0, 12, 0, 96)
ContentArea.BackgroundTransparency = 1
ContentArea.ZIndex           = 7
ContentArea.Parent           = Panel

-- ============================================================
-- REBIRTH section (bottom strip)
-- ============================================================

local RebirthBar = Instance.new("Frame")
RebirthBar.Name             = "RebirthBar"
RebirthBar.Size             = UDim2.new(1, -24, 0, 44)
RebirthBar.Position         = UDim2.new(0, 12, 1, -50)
RebirthBar.BackgroundColor3 = Color3.fromRGB(28, 20, 40)
RebirthBar.BorderSizePixel  = 0
RebirthBar.ZIndex           = 7
RebirthBar.Parent           = Panel
makeCorner(RebirthBar, 8)
makeStroke(RebirthBar, Color3.fromRGB(120, 50, 200), 1.5)

local RebirthLabel = Instance.new("TextLabel")
RebirthLabel.Name             = "RebirthLabel"
RebirthLabel.Size             = UDim2.new(1, -120, 1, 0)
RebirthLabel.Position         = UDim2.new(0, 10, 0, 0)
RebirthLabel.BackgroundTransparency = 1
RebirthLabel.Text             = "🌀 REBIRTH — $" .. REBIRTH_COST .. "  |  Resets progress, boosts income permanently"
RebirthLabel.TextColor3       = Color3.fromRGB(200, 160, 255)
RebirthLabel.TextScaled       = true
RebirthLabel.Font             = Enum.Font.Gotham
RebirthLabel.TextXAlignment   = Enum.TextXAlignment.Left
RebirthLabel.ZIndex           = 8
RebirthLabel.Parent           = RebirthBar

local RebirthBtn = Instance.new("TextButton")
RebirthBtn.Name             = "RebirthBtn"
RebirthBtn.Size             = UDim2.new(0, 100, 0, 30)
RebirthBtn.Position         = UDim2.new(1, -108, 0.5, -15)
RebirthBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 200)
RebirthBtn.Text             = "REBIRTH"
RebirthBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
RebirthBtn.TextScaled       = true
RebirthBtn.Font             = Enum.Font.GothamBold
RebirthBtn.ZIndex           = 9
RebirthBtn.Parent           = RebirthBar
makeCorner(RebirthBtn, 6)

-- ============================================================
-- DIRECT BUY content
-- ============================================================

local DirectContent = Instance.new("Frame")
DirectContent.Name             = "DirectContent"
DirectContent.Size             = UDim2.new(1, 0, 1, 0)
DirectContent.BackgroundTransparency = 1
DirectContent.ZIndex           = 8
DirectContent.Visible          = true
DirectContent.Parent           = ContentArea

-- Filter bar
local FilterBar = Instance.new("Frame")
FilterBar.Name             = "FilterBar"
FilterBar.Size             = UDim2.new(1, 0, 0, 30)
FilterBar.BackgroundTransparency = 1
FilterBar.ZIndex           = 9
FilterBar.Parent           = DirectContent

local FilterLayout = Instance.new("UIListLayout")
FilterLayout.FillDirection = Enum.FillDirection.Horizontal
FilterLayout.SortOrder     = Enum.SortOrder.LayoutOrder
FilterLayout.Padding       = UDim.new(0, 4)
FilterLayout.Parent        = FilterBar

local filterNames = { "ALL", "Common", "Uncommon", "Rare", "Epic", "Legendary" }
-- Only show rarities that have buyable brainrots (cost ~= nil)
local buyableRarities = {}
do
	local seen = {}
	for _, entry in ipairs(BrainrotData.list) do
		if entry.cost ~= nil and not seen[entry.rarity] then
			seen[entry.rarity] = true
			table.insert(buyableRarities, entry.rarity)
		end
	end
end

local filterBtns = {}

local function setFilterActive(name)
	activeFilter = name
	for fname, fbtn in pairs(filterBtns) do
		if fname == name then
			fbtn.BackgroundColor3 = Color3.fromRGB(60, 100, 200)
			fbtn.TextColor3       = Color3.fromRGB(255, 255, 255)
		else
			fbtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
			fbtn.TextColor3       = Color3.fromRGB(160, 160, 180)
		end
	end
end

-- Build filter buttons: ALL + only rarities with buyable items
local filterOrder = 1
for _, fname in ipairs(filterNames) do
	local isBuyableRarity = false
	for _, r in ipairs(buyableRarities) do
		if r == fname then
			isBuyableRarity = true
			break
		end
	end
	if fname == "ALL" or isBuyableRarity then
		local fbtn = Instance.new("TextButton")
		fbtn.Name             = "Filter_" .. fname
		fbtn.Size             = UDim2.new(0, 80, 1, 0)
		fbtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		fbtn.Text             = fname
		fbtn.TextColor3       = Color3.fromRGB(160, 160, 180)
		fbtn.TextScaled       = true
		fbtn.Font             = Enum.Font.GothamBold
		fbtn.LayoutOrder      = filterOrder
		fbtn.ZIndex           = 10
		fbtn.Parent           = FilterBar
		makeCorner(fbtn, 5)

		filterBtns[fname] = fbtn
		local capturedName = fname
		fbtn.MouseButton1Click:Connect(function()
			setFilterActive(capturedName)
			-- Refresh card visibility
			for _, entry in ipairs(BrainrotData.list) do
				if entry.cost ~= nil then
					local card = DirectContent:FindFirstChild("Card_" .. entry.id)
					if card then
						if capturedName == "ALL" or entry.rarity == capturedName then
							card.Visible = true
						else
							card.Visible = false
						end
					end
				end
			end
		end)

		filterOrder = filterOrder + 1
	end
end

setFilterActive("ALL")

-- Scrolling card list
local CardScroll = Instance.new("ScrollingFrame")
CardScroll.Name             = "CardScroll"
CardScroll.Size             = UDim2.new(1, 0, 1, -36)
CardScroll.Position         = UDim2.new(0, 0, 0, 34)
CardScroll.BackgroundTransparency = 1
CardScroll.ScrollBarThickness = 6
CardScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 120)
CardScroll.CanvasSize       = UDim2.new(0, 0, 0, 0)   -- set dynamically
CardScroll.ZIndex           = 9
CardScroll.Parent           = DirectContent

local CardGrid = Instance.new("UIGridLayout")
CardGrid.CellSize           = UDim2.new(0, 160, 0, 160)
CardGrid.CellPadding        = UDim2.new(0, 8, 0, 8)
CardGrid.SortOrder          = Enum.SortOrder.LayoutOrder
CardGrid.FillDirection      = Enum.FillDirection.Horizontal
CardGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
CardGrid.VerticalAlignment  = Enum.VerticalAlignment.Top
CardGrid.Parent             = CardScroll

local GridPad = Instance.new("UIPadding")
GridPad.PaddingLeft   = UDim.new(0, 4)
GridPad.PaddingTop    = UDim.new(0, 4)
GridPad.Parent        = CardScroll

-- Auto-resize canvas
CardGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	CardScroll.CanvasSize = UDim2.new(0, 0, 0, CardGrid.AbsoluteContentSize.Y + 8)
end)

-- Build cards
local function updateCardAffordability()
	local money = getMoney()
	local collection = getCollection()
	for _, entry in ipairs(BrainrotData.list) do
		if entry.cost ~= nil then
			local card = DirectContent:FindFirstChild("Card_" .. entry.id)
			if card then
				local buyBtn = card:FindFirstChild("BuyBtn")
				local ownBadge = card:FindFirstChild("OwnBadge")
				if buyBtn then
					if money >= entry.cost then
						buyBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
						buyBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
					else
						buyBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
						buyBtn.TextColor3       = Color3.fromRGB(140, 140, 140)
					end
				end
				if ownBadge then
					local ownCount = collection[entry.id] or 0
					if ownCount > 0 then
						ownBadge.Text    = "x" .. ownCount
						ownBadge.Visible = true
					else
						ownBadge.Visible = false
					end
				end
			end
		end
	end
end

-- Sort buyable brainrots by rarity order then name
local buyableSorted = {}
for _, entry in ipairs(BrainrotData.list) do
	if entry.cost ~= nil then
		table.insert(buyableSorted, entry)
	end
end
table.sort(buyableSorted, function(a, b)
	local ai, bi = 99, 99
	for i, r in ipairs(RARITY_ORDER) do
		if r == a.rarity then ai = i end
		if r == b.rarity then bi = i end
	end
	if ai ~= bi then return ai < bi end
	return a.name < b.name
end)

for orderIdx, entry in ipairs(buyableSorted) do
	local card = Instance.new("Frame")
	card.Name             = "Card_" .. entry.id
	card.Size             = UDim2.new(0, 160, 0, 160)
	card.BackgroundColor3 = RARITY_BG[entry.rarity] or Color3.fromRGB(40, 40, 50)
	card.LayoutOrder      = orderIdx
	card.ZIndex           = 10
	card.Parent           = CardScroll
	makeCorner(card, 8)
	makeStroke(card, RARITY_COLORS[entry.rarity] or Color3.fromRGB(100,100,100), 1.5)

	-- Rarity color top strip
	local rarityStrip = Instance.new("Frame")
	rarityStrip.Size             = UDim2.new(1, 0, 0, 4)
	rarityStrip.BackgroundColor3 = RARITY_COLORS[entry.rarity] or Color3.fromRGB(100,100,100)
	rarityStrip.BorderSizePixel  = 0
	rarityStrip.ZIndex           = 11
	rarityStrip.Parent           = card
	makeCorner(rarityStrip, 4)

	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name             = "NameLabel"
	nameLabel.Size             = UDim2.new(1, -8, 0, 32)
	nameLabel.Position         = UDim2.new(0, 4, 0, 6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text             = entry.name
	nameLabel.TextColor3       = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled       = true
	nameLabel.Font             = Enum.Font.GothamBold
	nameLabel.TextWrapped      = true
	nameLabel.ZIndex           = 11
	nameLabel.Parent           = card

	-- Rarity label
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name             = "RarityLabel"
	rarityLabel.Size             = UDim2.new(1, -8, 0, 18)
	rarityLabel.Position         = UDim2.new(0, 4, 0, 40)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text             = entry.rarity
	rarityLabel.TextColor3       = RARITY_COLORS[entry.rarity] or Color3.fromRGB(200,200,200)
	rarityLabel.TextScaled       = true
	rarityLabel.Font             = Enum.Font.GothamBold
	rarityLabel.ZIndex           = 11
	rarityLabel.Parent           = card

	-- Income
	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name             = "IncomeLabel"
	incomeLabel.Size             = UDim2.new(1, -8, 0, 18)
	incomeLabel.Position         = UDim2.new(0, 4, 0, 62)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text             = "+" .. entry.income .. "$/s"
	incomeLabel.TextColor3       = Color3.fromRGB(100, 220, 100)
	incomeLabel.TextScaled       = true
	incomeLabel.Font             = Enum.Font.Gotham
	incomeLabel.ZIndex           = 11
	incomeLabel.Parent           = card

	-- Cost
	local costLabel = Instance.new("TextLabel")
	costLabel.Name             = "CostLabel"
	costLabel.Size             = UDim2.new(1, -8, 0, 18)
	costLabel.Position         = UDim2.new(0, 4, 0, 82)
	costLabel.BackgroundTransparency = 1
	costLabel.Text             = "$" .. entry.cost
	costLabel.TextColor3       = Color3.fromRGB(255, 220, 80)
	costLabel.TextScaled       = true
	costLabel.Font             = Enum.Font.GothamBold
	costLabel.ZIndex           = 11
	costLabel.Parent           = card

	-- BUY button
	local buyBtn = Instance.new("TextButton")
	buyBtn.Name             = "BuyBtn"
	buyBtn.Size             = UDim2.new(1, -16, 0, 28)
	buyBtn.Position         = UDim2.new(0, 8, 1, -36)
	buyBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
	buyBtn.Text             = "BUY"
	buyBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
	buyBtn.TextScaled       = true
	buyBtn.Font             = Enum.Font.GothamBold
	buyBtn.ZIndex           = 12
	buyBtn.Parent           = card
	makeCorner(buyBtn, 6)

	-- Owned badge (top-right of card)
	local ownBadge = Instance.new("TextLabel")
	ownBadge.Name             = "OwnBadge"
	ownBadge.Size             = UDim2.new(0, 36, 0, 20)
	ownBadge.Position         = UDim2.new(1, -40, 0, 6)
	ownBadge.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
	ownBadge.Text             = "x0"
	ownBadge.TextColor3       = Color3.fromRGB(0, 0, 0)
	ownBadge.TextScaled       = true
	ownBadge.Font             = Enum.Font.GothamBold
	ownBadge.Visible          = false
	ownBadge.ZIndex           = 13
	ownBadge.Parent           = card
	makeCorner(ownBadge, 4)

	-- Wire up BUY button
	local capturedId = entry.id
	local capturedCost = entry.cost
	buyBtn.MouseButton1Click:Connect(function()
		local money = getMoney()
		if money >= capturedCost then
			BuyBrainrotEvent:FireServer(capturedId)
		end
	end)

	cardButtons[entry.id] = buyBtn
end

-- ============================================================
-- GACHA content
-- ============================================================

local GachaContent = Instance.new("Frame")
GachaContent.Name             = "GachaContent"
GachaContent.Size             = UDim2.new(1, 0, 1, 0)
GachaContent.BackgroundTransparency = 1
GachaContent.ZIndex           = 8
GachaContent.Visible          = false
GachaContent.Parent           = ContentArea

-- Left side: spin area
local SpinArea = Instance.new("Frame")
SpinArea.Name             = "SpinArea"
SpinArea.Size             = UDim2.new(0.55, -8, 1, 0)
SpinArea.BackgroundTransparency = 1
SpinArea.ZIndex           = 9
SpinArea.Parent           = GachaContent

-- Cost label
local GachaCostLabel = Instance.new("TextLabel")
GachaCostLabel.Name             = "GachaCostLabel"
GachaCostLabel.Size             = UDim2.new(1, 0, 0, 28)
GachaCostLabel.Position         = UDim2.new(0, 0, 0, 8)
GachaCostLabel.BackgroundTransparency = 1
GachaCostLabel.Text             = "$" .. GACHA_COST .. " per spin"
GachaCostLabel.TextColor3       = Color3.fromRGB(255, 220, 80)
GachaCostLabel.TextScaled       = true
GachaCostLabel.Font             = Enum.Font.GothamBold
GachaCostLabel.ZIndex           = 10
GachaCostLabel.Parent           = SpinArea

-- Spin animation display (cycling rarity names)
local SpinDisplay = Instance.new("Frame")
SpinDisplay.Name             = "SpinDisplay"
SpinDisplay.Size             = UDim2.new(0.85, 0, 0, 90)
SpinDisplay.Position         = UDim2.new(0.075, 0, 0, 44)
SpinDisplay.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
SpinDisplay.ZIndex           = 10
SpinDisplay.Parent           = SpinArea
makeCorner(SpinDisplay, 10)
makeStroke(SpinDisplay, Color3.fromRGB(80, 80, 140), 2)

local SpinDisplayLabel = Instance.new("TextLabel")
SpinDisplayLabel.Name             = "SpinDisplayLabel"
SpinDisplayLabel.Size             = UDim2.new(1, 0, 1, 0)
SpinDisplayLabel.BackgroundTransparency = 1
SpinDisplayLabel.Text             = "❓"
SpinDisplayLabel.TextColor3       = Color3.fromRGB(255, 255, 255)
SpinDisplayLabel.TextScaled       = true
SpinDisplayLabel.Font             = Enum.Font.GothamBold
SpinDisplayLabel.ZIndex           = 11
SpinDisplayLabel.Parent           = SpinDisplay

-- SPIN button (pulsing rainbow)
local SpinBtn = Instance.new("TextButton")
SpinBtn.Name             = "SpinBtn"
SpinBtn.Size             = UDim2.new(0.7, 0, 0, 52)
SpinBtn.Position         = UDim2.new(0.15, 0, 0, 146)
SpinBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 200)
SpinBtn.Text             = "🎰 SPIN!"
SpinBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
SpinBtn.TextScaled       = true
SpinBtn.Font             = Enum.Font.GothamBold
SpinBtn.ZIndex           = 10
SpinBtn.Parent           = SpinArea
makeCorner(SpinBtn, 10)
makeStroke(SpinBtn, Color3.fromRGB(255, 255, 255), 2)

-- Pulsing rainbow animation for spin button
local spinBtnHue = 0
RunService.RenderStepped:Connect(function(dt)
	if not SpinBtn or not SpinBtn.Parent then return end
	if gachaSpinning then return end
	spinBtnHue = (spinBtnHue + dt * 0.4) % 1
	SpinBtn.BackgroundColor3 = Color3.fromHSV(spinBtnHue, 0.85, 0.95)
end)

-- Recent pulls label
local RecentLabel = Instance.new("TextLabel")
RecentLabel.Name             = "RecentLabel"
RecentLabel.Size             = UDim2.new(1, 0, 0, 22)
RecentLabel.Position         = UDim2.new(0, 0, 0, 210)
RecentLabel.BackgroundTransparency = 1
RecentLabel.Text             = "Recent pulls:"
RecentLabel.TextColor3       = Color3.fromRGB(180, 180, 200)
RecentLabel.TextScaled       = true
RecentLabel.Font             = Enum.Font.GothamBold
RecentLabel.TextXAlignment   = Enum.TextXAlignment.Left
RecentLabel.ZIndex           = 10
RecentLabel.Parent           = SpinArea

local RecentScroll = Instance.new("ScrollingFrame")
RecentScroll.Name             = "RecentScroll"
RecentScroll.Size             = UDim2.new(1, 0, 0, 100)
RecentScroll.Position         = UDim2.new(0, 0, 0, 234)
RecentScroll.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
RecentScroll.ScrollBarThickness = 4
RecentScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 120)
RecentScroll.CanvasSize       = UDim2.new(0, 0, 0, 0)
RecentScroll.ZIndex           = 10
RecentScroll.Parent           = SpinArea
makeCorner(RecentScroll, 6)

local RecentList = Instance.new("UIListLayout")
RecentList.FillDirection    = Enum.FillDirection.Vertical
RecentList.SortOrder        = Enum.SortOrder.LayoutOrder
RecentList.Padding          = UDim.new(0, 3)
RecentList.Parent           = RecentScroll

RecentList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	RecentScroll.CanvasSize = UDim2.new(0, 0, 0, RecentList.AbsoluteContentSize.Y + 4)
end)

-- Right side: odds table
local OddsArea = Instance.new("Frame")
OddsArea.Name             = "OddsArea"
OddsArea.Size             = UDim2.new(0.42, 0, 1, 0)
OddsArea.Position         = UDim2.new(0.58, 0, 0, 0)
OddsArea.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
OddsArea.ZIndex           = 9
OddsArea.Parent           = GachaContent
makeCorner(OddsArea, 8)
makeStroke(OddsArea, Color3.fromRGB(60, 60, 100), 1.5)

local OddsTitle = Instance.new("TextLabel")
OddsTitle.Name             = "OddsTitle"
OddsTitle.Size             = UDim2.new(1, 0, 0, 28)
OddsTitle.Position         = UDim2.new(0, 0, 0, 6)
OddsTitle.BackgroundTransparency = 1
OddsTitle.Text             = "ODDS TABLE"
OddsTitle.TextColor3       = Color3.fromRGB(220, 220, 255)
OddsTitle.TextScaled       = true
OddsTitle.Font             = Enum.Font.GothamBold
OddsTitle.ZIndex           = 10
OddsTitle.Parent           = OddsArea

local OddsList = Instance.new("UIListLayout")
OddsList.FillDirection = Enum.FillDirection.Vertical
OddsList.SortOrder     = Enum.SortOrder.LayoutOrder
OddsList.Padding       = UDim.new(0, 4)
OddsList.Parent        = OddsArea

-- spacer for title
local OddsTopSpacer = Instance.new("Frame")
OddsTopSpacer.Size             = UDim2.new(1, 0, 0, 36)
OddsTopSpacer.BackgroundTransparency = 1
OddsTopSpacer.LayoutOrder      = 0
OddsTopSpacer.Parent           = OddsArea

for i, row in ipairs(GACHA_ODDS) do
	local rowFrame = Instance.new("Frame")
	rowFrame.Name             = "OddsRow_" .. row.rarity
	rowFrame.Size             = UDim2.new(1, -12, 0, 36)
	rowFrame.BackgroundColor3 = RARITY_BG[row.rarity] or Color3.fromRGB(30,30,40)
	rowFrame.LayoutOrder      = i
	rowFrame.ZIndex           = 10
	rowFrame.Parent           = OddsArea
	makeCorner(rowFrame, 6)

	local rowPad = Instance.new("UIPadding")
	rowPad.PaddingLeft   = UDim.new(0, 8)
	rowPad.PaddingRight  = UDim.new(0, 8)
	rowPad.Parent        = rowFrame

	local rarityTxt = Instance.new("TextLabel")
	rarityTxt.Size             = UDim2.new(0.6, 0, 1, 0)
	rarityTxt.BackgroundTransparency = 1
	rarityTxt.Text             = row.rarity
	rarityTxt.TextColor3       = RARITY_COLORS[row.rarity] or Color3.fromRGB(200,200,200)
	rarityTxt.TextScaled       = true
	rarityTxt.Font             = Enum.Font.GothamBold
	rarityTxt.TextXAlignment   = Enum.TextXAlignment.Left
	rarityTxt.ZIndex           = 11
	rarityTxt.Parent           = rowFrame

	local chanceTxt = Instance.new("TextLabel")
	chanceTxt.Size             = UDim2.new(0.4, 0, 1, 0)
	chanceTxt.Position         = UDim2.new(0.6, 0, 0, 0)
	chanceTxt.BackgroundTransparency = 1
	chanceTxt.Text             = row.chance
	chanceTxt.TextColor3       = Color3.fromRGB(220, 220, 220)
	chanceTxt.TextScaled       = true
	chanceTxt.Font             = Enum.Font.Gotham
	chanceTxt.TextXAlignment   = Enum.TextXAlignment.Right
	chanceTxt.ZIndex           = 11
	chanceTxt.Parent           = rowFrame
end

-- ============================================================
-- Gacha result popup
-- ============================================================

local ResultPopup = Instance.new("Frame")
ResultPopup.Name             = "ResultPopup"
ResultPopup.Size             = UDim2.new(0, 360, 0, 280)
ResultPopup.Position         = UDim2.new(0.5, -180, 0.5, -140)
ResultPopup.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
ResultPopup.ZIndex           = 20
ResultPopup.Visible          = false
ResultPopup.Parent           = ScreenGui
makeCorner(ResultPopup, 14)
makeStroke(ResultPopup, Color3.fromRGB(100, 100, 160), 2)

local ResultBg = Instance.new("Frame")
ResultBg.Name             = "ResultBg"
ResultBg.Size             = UDim2.new(1, 0, 0.42, 0)
ResultBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
ResultBg.BorderSizePixel  = 0
ResultBg.ZIndex           = 20
ResultBg.Parent           = ResultPopup
makeCorner(ResultBg, 14)

local ResultBgFix = Instance.new("Frame")
ResultBgFix.Size             = UDim2.new(1, 0, 0.5, 0)
ResultBgFix.Position         = UDim2.new(0, 0, 0.5, 0)
ResultBgFix.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
ResultBgFix.BorderSizePixel  = 0
ResultBgFix.ZIndex           = 20
ResultBgFix.Parent           = ResultBg

local YouGotLabel = Instance.new("TextLabel")
YouGotLabel.Name             = "YouGotLabel"
YouGotLabel.Size             = UDim2.new(1, 0, 0, 28)
YouGotLabel.Position         = UDim2.new(0, 0, 0, 12)
YouGotLabel.BackgroundTransparency = 1
YouGotLabel.Text             = "YOU GOT..."
YouGotLabel.TextColor3       = Color3.fromRGB(220, 220, 220)
YouGotLabel.TextScaled       = true
YouGotLabel.Font             = Enum.Font.GothamBold
YouGotLabel.ZIndex           = 21
YouGotLabel.Parent           = ResultPopup

local ResultNameLabel = Instance.new("TextLabel")
ResultNameLabel.Name             = "ResultNameLabel"
ResultNameLabel.Size             = UDim2.new(0.9, 0, 0, 52)
ResultNameLabel.Position         = UDim2.new(0.05, 0, 0, 46)
ResultNameLabel.BackgroundTransparency = 1
ResultNameLabel.Text             = ""
ResultNameLabel.TextColor3       = Color3.fromRGB(255, 255, 255)
ResultNameLabel.TextScaled       = true
ResultNameLabel.Font             = Enum.Font.GothamBold
ResultNameLabel.ZIndex           = 21
ResultNameLabel.Parent           = ResultPopup

local ResultRarityLabel = Instance.new("TextLabel")
ResultRarityLabel.Name             = "ResultRarityLabel"
ResultRarityLabel.Size             = UDim2.new(0.9, 0, 0, 24)
ResultRarityLabel.Position         = UDim2.new(0.05, 0, 0, 100)
ResultRarityLabel.BackgroundTransparency = 1
ResultRarityLabel.Text             = ""
ResultRarityLabel.TextColor3       = Color3.fromRGB(200, 200, 200)
ResultRarityLabel.TextScaled       = true
ResultRarityLabel.Font             = Enum.Font.GothamBold
ResultRarityLabel.ZIndex           = 21
ResultRarityLabel.Parent           = ResultPopup

local ResultDescLabel = Instance.new("TextLabel")
ResultDescLabel.Name             = "ResultDescLabel"
ResultDescLabel.Size             = UDim2.new(0.9, 0, 0, 64)
ResultDescLabel.Position         = UDim2.new(0.05, 0, 0, 128)
ResultDescLabel.BackgroundTransparency = 1
ResultDescLabel.Text             = ""
ResultDescLabel.TextColor3       = Color3.fromRGB(180, 180, 190)
ResultDescLabel.TextScaled       = true
ResultDescLabel.Font             = Enum.Font.Gotham
ResultDescLabel.TextWrapped      = true
ResultDescLabel.ZIndex           = 21
ResultDescLabel.Parent           = ResultPopup

local NiceBtn = Instance.new("TextButton")
NiceBtn.Name             = "NiceBtn"
NiceBtn.Size             = UDim2.new(0, 120, 0, 36)
NiceBtn.Position         = UDim2.new(0.5, -60, 1, -46)
NiceBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
NiceBtn.Text             = "NICE!"
NiceBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
NiceBtn.TextScaled       = true
NiceBtn.Font             = Enum.Font.GothamBold
NiceBtn.ZIndex           = 22
NiceBtn.Parent           = ResultPopup
makeCorner(NiceBtn, 8)

-- Confetti container (children are individual confetti pieces)
local ConfettiHolder = Instance.new("Frame")
ConfettiHolder.Name             = "ConfettiHolder"
ConfettiHolder.Size             = UDim2.new(1, 0, 1, 0)
ConfettiHolder.BackgroundTransparency = 1
ConfettiHolder.ZIndex           = 19
ConfettiHolder.ClipsDescendants = false
ConfettiHolder.Parent           = ResultPopup

-- ============================================================
-- Confirmation dialog (for rebirth)
-- ============================================================

local ConfirmDialog = Instance.new("Frame")
ConfirmDialog.Name             = "ConfirmDialog"
ConfirmDialog.Size             = UDim2.new(0, 340, 0, 180)
ConfirmDialog.Position         = UDim2.new(0.5, -170, 0.5, -90)
ConfirmDialog.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
ConfirmDialog.ZIndex           = 25
ConfirmDialog.Visible          = false
ConfirmDialog.Parent           = ScreenGui
makeCorner(ConfirmDialog, 12)
makeStroke(ConfirmDialog, Color3.fromRGB(120, 50, 200), 2)

local ConfirmTitle = Instance.new("TextLabel")
ConfirmTitle.Size             = UDim2.new(1, -20, 0, 36)
ConfirmTitle.Position         = UDim2.new(0, 10, 0, 10)
ConfirmTitle.BackgroundTransparency = 1
ConfirmTitle.Text             = "🌀 REBIRTH CONFIRMATION"
ConfirmTitle.TextColor3       = Color3.fromRGB(200, 160, 255)
ConfirmTitle.TextScaled       = true
ConfirmTitle.Font             = Enum.Font.GothamBold
ConfirmTitle.ZIndex           = 26
ConfirmTitle.Parent           = ConfirmDialog

local ConfirmBody = Instance.new("TextLabel")
ConfirmBody.Size             = UDim2.new(1, -20, 0, 64)
ConfirmBody.Position         = UDim2.new(0, 10, 0, 50)
ConfirmBody.BackgroundTransparency = 1
ConfirmBody.Text             = "Are you sure? This resets your brainrots for a permanent income multiplier."
ConfirmBody.TextColor3       = Color3.fromRGB(200, 200, 210)
ConfirmBody.TextScaled       = true
ConfirmBody.Font             = Enum.Font.Gotham
ConfirmBody.TextWrapped      = true
ConfirmBody.ZIndex           = 26
ConfirmBody.Parent           = ConfirmDialog

local ConfirmYes = Instance.new("TextButton")
ConfirmYes.Size             = UDim2.new(0, 120, 0, 36)
ConfirmYes.Position         = UDim2.new(0.18, 0, 1, -48)
ConfirmYes.BackgroundColor3 = Color3.fromRGB(120, 40, 200)
ConfirmYes.Text             = "YES, REBIRTH"
ConfirmYes.TextColor3       = Color3.fromRGB(255, 255, 255)
ConfirmYes.TextScaled       = true
ConfirmYes.Font             = Enum.Font.GothamBold
ConfirmYes.ZIndex           = 27
ConfirmYes.Parent           = ConfirmDialog
makeCorner(ConfirmYes, 7)

local ConfirmNo = Instance.new("TextButton")
ConfirmNo.Size             = UDim2.new(0, 100, 0, 36)
ConfirmNo.Position         = UDim2.new(0.62, 0, 1, -48)
ConfirmNo.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
ConfirmNo.Text             = "NO"
ConfirmNo.TextColor3       = Color3.fromRGB(255, 255, 255)
ConfirmNo.TextScaled       = true
ConfirmNo.Font             = Enum.Font.GothamBold
ConfirmNo.ZIndex           = 27
ConfirmNo.Parent           = ConfirmDialog
makeCorner(ConfirmNo, 7)

-- ============================================================
-- Open / close shop
-- ============================================================

local function openShop()
	shopOpen = true
	Overlay.Visible = true
	Panel.Visible   = true
	updateCardAffordability()

	-- Slide in from center with scale
	Panel.Position = UDim2.new(0.5, -300, 0.5, -250)
	local tweenIn = TweenService:Create(
		Panel,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -300, 0.5, -250) }
	)
	tweenIn:Play()
end

local function closeShop()
	shopOpen = false
	local tweenOut = TweenService:Create(
		Panel,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, -300, 0.6, -250) }
	)
	tweenOut:Play()
	tweenOut.Completed:Connect(function()
		Panel.Visible   = false
		Overlay.Visible = false
		Panel.Position  = UDim2.new(0.5, -300, 0.5, -250)
	end)
end

-- ============================================================
-- Tab switching
-- ============================================================

local function activateTab(tabName)
	activeTab = tabName
	if tabName == "DIRECT" then
		DirectContent.Visible = true
		GachaContent.Visible  = false
		DirectTab.BackgroundColor3 = Color3.fromRGB(60, 100, 200)
		DirectTab.TextColor3       = Color3.fromRGB(255, 255, 255)
		GachaTab.BackgroundColor3  = Color3.fromRGB(40, 40, 55)
		GachaTab.TextColor3        = Color3.fromRGB(180, 180, 200)
	else
		DirectContent.Visible = false
		GachaContent.Visible  = true
		GachaTab.BackgroundColor3  = Color3.fromRGB(60, 100, 200)
		GachaTab.TextColor3        = Color3.fromRGB(255, 255, 255)
		DirectTab.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		DirectTab.TextColor3       = Color3.fromRGB(180, 180, 200)
	end
end

activateTab("DIRECT")

-- ============================================================
-- Live money update
-- ============================================================

local function updateMoneyDisplay()
	MoneyDisplay.Text = "$" .. getMoney()
	updateCardAffordability()
end

moneyConnection = LocalPlayer:GetAttributeChangedSignal("Money"):Connect(updateMoneyDisplay)
updateMoneyDisplay()

-- Also update owned counts when collection attributes change
for _, entry in ipairs(BrainrotData.list) do
	LocalPlayer:GetAttributeChangedSignal("Own_" .. entry.id):Connect(function()
		updateCardAffordability()
	end)
end

-- ============================================================
-- Recent pulls UI update
-- ============================================================

local function refreshRecentPulls()
	for _, child in ipairs(RecentScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, pullData in ipairs(recentPulls) do
		local row = Instance.new("Frame")
		row.Name             = "Pull_" .. i
		row.Size             = UDim2.new(1, -8, 0, 22)
		row.BackgroundColor3 = RARITY_BG[pullData.rarity] or Color3.fromRGB(30,30,40)
		row.LayoutOrder      = i
		row.ZIndex           = 11
		row.Parent           = RecentScroll
		makeCorner(row, 4)

		local pullLabel = Instance.new("TextLabel")
		pullLabel.Size             = UDim2.new(1, -8, 1, 0)
		pullLabel.Position         = UDim2.new(0, 4, 0, 0)
		pullLabel.BackgroundTransparency = 1
		pullLabel.Text             = "[" .. pullData.rarity .. "] " .. pullData.name
		pullLabel.TextColor3       = RARITY_COLORS[pullData.rarity] or Color3.fromRGB(200,200,200)
		pullLabel.TextScaled       = true
		pullLabel.Font             = Enum.Font.Gotham
		pullLabel.TextXAlignment   = Enum.TextXAlignment.Left
		pullLabel.ZIndex           = 12
		pullLabel.Parent           = row
	end
end

-- ============================================================
-- Confetti effect
-- ============================================================

local confettiColors = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(80, 255, 80),
	Color3.fromRGB(80, 120, 255),
	Color3.fromRGB(255, 255, 80),
	Color3.fromRGB(255, 80, 255),
	Color3.fromRGB(80, 255, 255),
}

local function spawnConfetti()
	for pieceIdx = 1, 28 do
		local piece = Instance.new("Frame")
		piece.Size             = UDim2.new(0, math.random(6, 14), 0, math.random(6, 14))
		piece.Position         = UDim2.new(math.random(10, 90) / 100, 0, -0.05, 0)
		piece.BackgroundColor3 = confettiColors[math.random(1, #confettiColors)]
		piece.BorderSizePixel  = 0
		piece.Rotation         = math.random(0, 360)
		piece.ZIndex           = 22
		piece.Parent           = ConfettiHolder
		makeCorner(piece, 2)

		local targetY = math.random(80, 130) / 100
		local targetX = (math.random(10, 90) / 100)
		local duration = math.random(8, 16) / 10

		local tween = TweenService:Create(
			piece,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.new(targetX, 0, targetY, 0),
				Rotation = math.random(180, 540),
				BackgroundTransparency = 1,
			}
		)
		tween:Play()
		tween.Completed:Connect(function()
			if piece and piece.Parent then
				piece:Destroy()
			end
		end)
	end
end

-- ============================================================
-- Gacha result popup display
-- ============================================================

local RARE_RARITIES = { Rare = true, Epic = true, Legendary = true }

local function showGachaResult(resultData)
	if not resultData then return end

	local rarColor = RARITY_COLORS[resultData.rarity] or Color3.fromRGB(200,200,200)

	ResultBg.BackgroundColor3    = RARITY_BG[resultData.rarity] or Color3.fromRGB(40,40,60)
	ResultBgFix.BackgroundColor3 = RARITY_BG[resultData.rarity] or Color3.fromRGB(40,40,60)
	ResultNameLabel.Text          = resultData.name
	ResultNameLabel.TextColor3    = rarColor
	ResultRarityLabel.Text        = "[ " .. resultData.rarity .. " ]"
	ResultRarityLabel.TextColor3  = rarColor
	ResultDescLabel.Text          = resultData.description or ""

	ResultPopup.Visible = true
	ResultPopup.BackgroundTransparency = 1
	local showTween = TweenService:Create(
		ResultPopup,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 }
	)
	showTween:Play()

	if RARE_RARITIES[resultData.rarity] then
		task.delay(0.1, spawnConfetti)
	end
end

-- ============================================================
-- Gacha spinning animation (slot-machine style)
-- ============================================================

local spinAnimationNames = {}
for _, r in ipairs(RARITY_ORDER) do
	for _, entry in ipairs(BrainrotData.list) do
		if entry.rarity == r then
			table.insert(spinAnimationNames, { name = entry.name, rarity = r })
		end
	end
end

local function runSpinAnimation(onDone)
	gachaSpinning = true
	SpinBtn.Active = false
	SpinBtn.Text   = "Spinning..."

	local stepCount  = 18
	local stepDelay  = 0.06
	local slowSteps  = 6
	local slowDelay  = 0.14

	local function doStep(idx)
		if not SpinDisplayLabel or not SpinDisplayLabel.Parent then return end
		local entry = spinAnimationNames[((idx - 1) % #spinAnimationNames) + 1]
		SpinDisplayLabel.Text      = entry.name
		SpinDisplayLabel.TextColor3 = RARITY_COLORS[entry.rarity] or Color3.fromRGB(200,200,200)
		SpinDisplay.BackgroundColor3 = RARITY_BG[entry.rarity] or Color3.fromRGB(18,18,28)
	end

	local step = 0
	local function nextStep()
		step = step + 1
		doStep(step)
		local delay
		if step <= stepCount then
			delay = stepDelay
		elseif step <= stepCount + slowSteps then
			delay = slowDelay + (step - stepCount) * 0.04
		else
			-- Done
			gachaSpinning = false
			SpinBtn.Active = true
			SpinBtn.Text   = "🎰 SPIN!"
			onDone()
			return
		end
		task.delay(delay, nextStep)
	end

	nextStep()
end

-- ============================================================
-- Wire SPIN button
-- ============================================================

SpinBtn.MouseButton1Click:Connect(function()
	if gachaSpinning then return end
	local money = getMoney()
	if money < GACHA_COST then return end

	runSpinAnimation(function()
		-- Fire server; result comes back via GachaResult event
		SpinGachaEvent:FireServer()
	end)
end)

-- ============================================================
-- Receive gacha result from server
-- ============================================================

GachaResultEvent.OnClientEvent:Connect(function(resultId)
	local resultData = BrainrotData.getById(resultId)
	if not resultData then return end

	-- Update spin display to final result
	SpinDisplayLabel.Text       = resultData.name
	SpinDisplayLabel.TextColor3 = RARITY_COLORS[resultData.rarity] or Color3.fromRGB(200,200,200)
	SpinDisplay.BackgroundColor3 = RARITY_BG[resultData.rarity] or Color3.fromRGB(18,18,28)

	-- Add to recent pulls (keep last 5)
	table.insert(recentPulls, 1, resultData)
	if #recentPulls > 5 then
		table.remove(recentPulls, #recentPulls)
	end
	refreshRecentPulls()

	-- Show result popup after a brief pause
	task.delay(0.3, function()
		showGachaResult(resultData)
	end)
end)

-- ============================================================
-- CollectionUpdated from server (updates owned badges)
-- ============================================================

local CollectionUpdatedEvent = RemoteEvents:WaitForChild("CollectionUpdated")
CollectionUpdatedEvent.OnClientEvent:Connect(function(collection)
	if not collection then return end
	for id, count in pairs(collection) do
		local card = DirectContent:FindFirstChild("Card_" .. id)
		if card then
			local ownBadge = card:FindFirstChild("OwnBadge")
			if ownBadge then
				if count and count > 0 then
					ownBadge.Text    = "x" .. count
					ownBadge.Visible = true
				else
					ownBadge.Visible = false
				end
			end
		end
	end
end)

-- ============================================================
-- Open shop from HUD button (fired from separate HUD script)
-- handled via BindableEvent or direct call;
-- also listen for server "OpenShop" RemoteEvent (shop pad)
-- ============================================================

OpenShopEvent.OnClientEvent:Connect(function()
	if not shopOpen then
		openShop()
	end
end)

-- HUD SHOP button is wired below via a BindableEvent that the HUD script fires.
-- If a separate HUD script is not present, we create a minimal SHOP button here.
local existingShopBtn = PlayerGui:FindFirstChild("HudUI") and
	PlayerGui:FindFirstChild("HudUI"):FindFirstDescendant("ShopButton")

if not existingShopBtn then
	-- Minimal fallback SHOP button in corner
	local HudFrame = Instance.new("ScreenGui")
	HudFrame.Name           = "ShopHudBtn"
	HudFrame.ResetOnSpawn   = false
	HudFrame.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	HudFrame.Parent         = PlayerGui

	local shopHudBtn = Instance.new("TextButton")
	shopHudBtn.Name             = "ShopButton"
	shopHudBtn.Size             = UDim2.new(0, 110, 0, 40)
	shopHudBtn.Position         = UDim2.new(0, 12, 0, 12)
	shopHudBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
	shopHudBtn.Text             = "🛒 SHOP"
	shopHudBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
	shopHudBtn.TextScaled       = true
	shopHudBtn.Font             = Enum.Font.GothamBold
	shopHudBtn.ZIndex           = 3
	shopHudBtn.Parent           = HudFrame
	makeCorner(shopHudBtn, 8)

	shopHudBtn.MouseButton1Click:Connect(function()
		if shopOpen then
			closeShop()
		else
			openShop()
		end
	end)
end

-- ============================================================
-- Button wiring
-- ============================================================

CloseBtn.MouseButton1Click:Connect(function()
	closeShop()
end)

Overlay.MouseButton1Click:Connect(function()
	closeShop()
end)

DirectTab.MouseButton1Click:Connect(function()
	activateTab("DIRECT")
end)

GachaTab.MouseButton1Click:Connect(function()
	activateTab("GACHA")
end)

NiceBtn.MouseButton1Click:Connect(function()
	ResultPopup.Visible = false
	-- Clear confetti
	for _, child in ipairs(ConfettiHolder:GetChildren()) do
		child:Destroy()
	end
end)

RebirthBtn.MouseButton1Click:Connect(function()
	ConfirmDialog.Visible = true
end)

ConfirmNo.MouseButton1Click:Connect(function()
	ConfirmDialog.Visible = false
end)

ConfirmYes.MouseButton1Click:Connect(function()
	ConfirmDialog.Visible = false
	RebirthEvent:FireServer()
end)

-- ============================================================
-- Button hover effects
-- ============================================================

local function addHover(btn, normalColor, hoverColor)
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = hoverColor }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = normalColor }):Play()
	end)
end

addHover(CloseBtn,    Color3.fromRGB(200, 50, 50),   Color3.fromRGB(240, 80, 80))
addHover(NiceBtn,     Color3.fromRGB(40, 160, 60),   Color3.fromRGB(60, 200, 80))
addHover(RebirthBtn,  Color3.fromRGB(120, 40, 200),  Color3.fromRGB(150, 60, 240))
addHover(ConfirmYes,  Color3.fromRGB(120, 40, 200),  Color3.fromRGB(150, 60, 240))
addHover(ConfirmNo,   Color3.fromRGB(70, 70, 80),    Color3.fromRGB(100, 100, 110))
addHover(DirectTab,   Color3.fromRGB(40, 40, 55),    Color3.fromRGB(55, 55, 75))
addHover(GachaTab,    Color3.fromRGB(40, 40, 55),    Color3.fromRGB(55, 55, 75))

-- Hover effects for BUY buttons (only when affordable)
for _, entry in ipairs(buyableSorted) do
	local buyBtn = cardButtons[entry.id]
	if buyBtn then
		buyBtn.MouseEnter:Connect(function()
			local money = getMoney()
			if money >= entry.cost then
				TweenService:Create(buyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(60, 200, 80) }):Play()
			end
		end)
		buyBtn.MouseLeave:Connect(function()
			local money = getMoney()
			if money >= entry.cost then
				TweenService:Create(buyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(40, 160, 60) }):Play()
			end
		end)
	end
end

-- ============================================================
-- Initial state
-- ============================================================

Panel.Visible   = false
Overlay.Visible = false
