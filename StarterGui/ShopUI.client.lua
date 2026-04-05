-- ShopUI.client.lua
-- LocalScript: Shop UI for Skibidi Tentafruit
-- Place in StarterGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BrainrotData"))

local RE = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenShopEvent  = RE:WaitForChild("OpenShop")
local SpinGachaEvent = RE:WaitForChild("SpinGacha")
local RebirthEvent   = RE:WaitForChild("Rebirth")
local NotificationEvent = RE:WaitForChild("Notification")

-- ============================================================
-- Config
-- ============================================================

local GACHA_COST   = 150
local REBIRTH_COST = 10000

local RARITY_COLOR = {
	Common    = Color3.fromRGB(160, 160, 160),
	Uncommon  = Color3.fromRGB(80,  200, 80),
	Rare      = Color3.fromRGB(60,  120, 255),
	Epic      = Color3.fromRGB(180, 60,  255),
	Legendary = Color3.fromRGB(255, 180, 0),
}

local GACHA_ODDS = {
	{ rarity = "Common",    chance = "50%" },
	{ rarity = "Uncommon",  chance = "25%" },
	{ rarity = "Rare",      chance = "12%" },
	{ rarity = "Epic",      chance = "5%"  },
	{ rarity = "Legendary", chance = "1%"  },
}

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- ============================================================
-- State
-- ============================================================

local shopOpen      = false
local activeTab     = "INFO"   -- "INFO" | "GACHA" | "STATS"
local activeFilter  = "ALL"
local recentPulls   = {}
local gachaSpinning = false
local rebirthPending = false

-- ============================================================
-- Helpers
-- ============================================================

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

local function padding(parent, px)
	local p = Instance.new("UIPadding")
	p.PaddingLeft   = UDim.new(0, px)
	p.PaddingRight  = UDim.new(0, px)
	p.PaddingTop    = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color     = color or Color3.fromRGB(100, 100, 140)
	s.Thickness = thickness or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent, text, size, color, font, xalign)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text          = text
	l.TextSize      = size or 14
	l.TextColor3    = color or Color3.fromRGB(220, 220, 220)
	l.Font          = font or Enum.Font.Gotham
	l.TextXAlignment = xalign or Enum.TextXAlignment.Left
	l.TextWrapped   = true
	l.Parent        = parent
	return l
end

local function button(parent, text, bgColor, textColor)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = bgColor or Color3.fromRGB(60, 100, 200)
	b.Text       = text
	b.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	b.Font       = Enum.Font.GothamBold
	b.TextScaled = true
	b.BorderSizePixel = 0
	corner(b, 8)
	b.Parent = parent
	return b
end

local function getMoney()
	return player:GetAttribute("Money") or 0
end

local function getRebirths()
	return player:GetAttribute("Rebirths") or 0
end

local function getMultiplier()
	return player:GetAttribute("Multiplier") or 1
end

-- ============================================================
-- Build ScreenGui
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "ShopUI"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent         = PlayerGui

-- Dim overlay (click to close)
local Overlay = Instance.new("TextButton")
Overlay.Size                   = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
Overlay.BackgroundTransparency = 0.5
Overlay.Text                   = ""
Overlay.Visible                = false
Overlay.ZIndex                 = 5
Overlay.Parent                 = ScreenGui

-- Main panel (550x480, centered)
local Panel = Instance.new("Frame")
Panel.Name             = "ShopPanel"
Panel.Size             = UDim2.new(0, 550, 0, 480)
Panel.Position         = UDim2.new(0.5, -275, 1.5, 0)  -- starts off-screen below
Panel.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
Panel.BorderSizePixel  = 0
Panel.Visible          = false
Panel.ZIndex           = 6
Panel.Parent           = ScreenGui
corner(Panel, 12)
stroke(Panel, Color3.fromRGB(70, 70, 110), 2)

-- ============================================================
-- Header
-- ============================================================

local Header = Instance.new("Frame")
Header.Name             = "Header"
Header.Size             = UDim2.new(1, 0, 0, 46)
Header.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
Header.BorderSizePixel  = 0
Header.ZIndex           = 7
Header.Parent           = Panel
corner(Header, 12)

-- Flat bottom strip so only top corners are rounded
local HeaderBottom = Instance.new("Frame")
HeaderBottom.Size             = UDim2.new(1, 0, 0.5, 0)
HeaderBottom.Position         = UDim2.new(0, 0, 0.5, 0)
HeaderBottom.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
HeaderBottom.BorderSizePixel  = 0
HeaderBottom.ZIndex           = 7
HeaderBottom.Parent           = Header

local TitleLabel = label(Header, "🛒  SKIBIDI TENTAFRUIT SHOP", 16, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
TitleLabel.Size     = UDim2.new(1, -52, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.ZIndex   = 8
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = button(Header, "✕", Color3.fromRGB(190, 45, 45))
CloseBtn.Size     = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -40, 0.5, -16)
CloseBtn.ZIndex   = 9

-- ============================================================
-- Tab bar
-- ============================================================

local TabBar = Instance.new("Frame")
TabBar.Name                   = "TabBar"
TabBar.Size                   = UDim2.new(1, -20, 0, 34)
TabBar.Position               = UDim2.new(0, 10, 0, 50)
TabBar.BackgroundTransparency = 1
TabBar.ZIndex                 = 7
TabBar.Parent                 = Panel

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.SortOrder     = Enum.SortOrder.LayoutOrder
TabLayout.Padding       = UDim.new(0, 6)
TabLayout.Parent        = TabBar

local function makeTab(name, labelText, order)
	local b = Instance.new("TextButton")
	b.Name             = name
	b.Size             = UDim2.new(0, 162, 1, 0)
	b.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	b.Text             = labelText
	b.TextColor3       = Color3.fromRGB(160, 160, 190)
	b.TextScaled       = true
	b.Font             = Enum.Font.GothamBold
	b.LayoutOrder      = order
	b.ZIndex           = 8
	b.BorderSizePixel  = 0
	b.Parent           = TabBar
	corner(b, 6)
	return b
end

local TabInfo  = makeTab("TabInfo",  "BRAINROT INFO", 1)
local TabGacha = makeTab("TabGacha", "🎰 GACHA",      2)
local TabStats = makeTab("TabStats", "📊 STATS",      3)

-- ============================================================
-- Content area
-- ============================================================

local ContentArea = Instance.new("Frame")
ContentArea.Name                   = "ContentArea"
ContentArea.Size                   = UDim2.new(1, -20, 1, -100)
ContentArea.Position               = UDim2.new(0, 10, 0, 90)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants       = true
ContentArea.ZIndex                 = 7
ContentArea.Parent                 = Panel

-- ============================================================
-- TAB 1: BRAINROT INFO
-- ============================================================

local InfoPage = Instance.new("Frame")
InfoPage.Name                   = "InfoPage"
InfoPage.Size                   = UDim2.new(1, 0, 1, 0)
InfoPage.BackgroundTransparency = 1
InfoPage.ZIndex                 = 7
InfoPage.Parent                 = ContentArea

-- Hint text
local HintLabel = label(InfoPage, "🏃 Walk to the conveyor belt to buy brainrots!", 13, Color3.fromRGB(140, 220, 140))
HintLabel.Size     = UDim2.new(1, 0, 0, 22)
HintLabel.Position = UDim2.new(0, 0, 0, 0)
HintLabel.TextXAlignment = Enum.TextXAlignment.Center
HintLabel.ZIndex   = 8

-- Filter bar
local FilterBar = Instance.new("Frame")
FilterBar.Name                   = "FilterBar"
FilterBar.Size                   = UDim2.new(1, 0, 0, 28)
FilterBar.Position               = UDim2.new(0, 0, 0, 26)
FilterBar.BackgroundTransparency = 1
FilterBar.ZIndex                 = 8
FilterBar.Parent                 = InfoPage

local FilterLayout = Instance.new("UIListLayout")
FilterLayout.FillDirection = Enum.FillDirection.Horizontal
FilterLayout.SortOrder     = Enum.SortOrder.LayoutOrder
FilterLayout.Padding       = UDim.new(0, 4)
FilterLayout.Parent        = FilterBar

local filterButtons = {}

local function makeFilterBtn(name, order)
	local b = Instance.new("TextButton")
	b.Name             = name
	b.Size             = UDim2.new(0, 72, 1, 0)
	b.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	b.Text             = name
	b.TextColor3       = Color3.fromRGB(160, 160, 190)
	b.TextSize         = 11
	b.Font             = Enum.Font.GothamBold
	b.LayoutOrder      = order
	b.ZIndex           = 9
	b.BorderSizePixel  = 0
	b.Parent           = FilterBar
	corner(b, 5)
	filterButtons[name] = b
	return b
end

makeFilterBtn("ALL",       1)
makeFilterBtn("Common",    2)
makeFilterBtn("Uncommon",  3)
makeFilterBtn("Rare",      4)
makeFilterBtn("Epic",      5)
makeFilterBtn("Legendary", 6)

-- Scrollable list
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name                        = "BrainrotList"
ScrollFrame.Size                        = UDim2.new(1, 0, 1, -58)
ScrollFrame.Position                    = UDim2.new(0, 0, 0, 58)
ScrollFrame.BackgroundTransparency      = 1
ScrollFrame.ScrollBarThickness          = 4
ScrollFrame.ScrollBarImageColor3        = Color3.fromRGB(80, 80, 120)
ScrollFrame.CanvasSize                  = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize         = Enum.AutomaticSize.Y
ScrollFrame.ZIndex                      = 8
ScrollFrame.Parent                      = InfoPage

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder   = Enum.SortOrder.LayoutOrder
ListLayout.Padding     = UDim.new(0, 4)
ListLayout.Parent      = ScrollFrame

local brainrotRows = {}  -- { row, rarity, gachaOnly }

local function buildBrainrotList()
	-- Clear old rows
	for _, r in ipairs(brainrotRows) do
		r.row:Destroy()
	end
	brainrotRows = {}

	for i, entry in ipairs(BrainrotData.list) do
		local rarityName = entry.rarity or "Common"
		local rarityColor = RARITY_COLOR[rarityName] or Color3.fromRGB(160, 160, 160)
		local isGachaOnly = entry.gachaOnly == true or entry.cost == nil

		local row = Instance.new("Frame")
		row.Name             = "Row_" .. i
		row.Size             = UDim2.new(1, -4, 0, 36)
		row.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
		row.BorderSizePixel  = 0
		row.LayoutOrder      = i
		row.ZIndex           = 9
		row.Parent           = ScrollFrame
		corner(row, 6)

		-- Rarity color strip
		local strip = Instance.new("Frame")
		strip.Size             = UDim2.new(0, 4, 1, 0)
		strip.BackgroundColor3 = rarityColor
		strip.BorderSizePixel  = 0
		strip.ZIndex           = 10
		strip.Parent           = row
		corner(strip, 3)

		-- Name
		local nameLabel = label(row, entry.name or entry.id, 13, Color3.fromRGB(230, 230, 230), Enum.Font.GothamBold)
		nameLabel.Size     = UDim2.new(0, 160, 1, 0)
		nameLabel.Position = UDim2.new(0, 12, 0, 0)
		nameLabel.ZIndex   = 10

		-- Income/s
		local incomeText = entry.income and ("+$" .. entry.income .. "/s") or ""
		local incomeLabel = label(row, incomeText, 12, Color3.fromRGB(100, 220, 100))
		incomeLabel.Size     = UDim2.new(0, 90, 1, 0)
		incomeLabel.Position = UDim2.new(0, 178, 0, 0)
		incomeLabel.ZIndex   = 10

		-- Cost
		local costText = isGachaOnly and "GACHA ONLY" or ("$" .. (entry.cost or "?"))
		local costColor = isGachaOnly and Color3.fromRGB(200, 130, 255) or Color3.fromRGB(255, 210, 80)
		local costLabel = label(row, costText, 12, costColor, Enum.Font.GothamBold)
		costLabel.Size     = UDim2.new(0, 100, 1, 0)
		costLabel.Position = UDim2.new(0, 274, 0, 0)
		costLabel.ZIndex   = 10

		-- Rarity badge
		local badge = Instance.new("TextLabel")
		badge.Size             = UDim2.new(0, 78, 0, 20)
		badge.Position         = UDim2.new(1, -84, 0.5, -10)
		badge.BackgroundColor3 = rarityColor
		badge.BackgroundTransparency = 0.6
		badge.Text             = rarityName
		badge.TextColor3       = Color3.fromRGB(255, 255, 255)
		badge.TextSize         = 10
		badge.Font             = Enum.Font.GothamBold
		badge.TextXAlignment   = Enum.TextXAlignment.Center
		badge.ZIndex           = 10
		badge.Parent           = row
		corner(badge, 4)

		table.insert(brainrotRows, { row = row, rarity = rarityName })
	end
end

local function applyFilter(filter)
	activeFilter = filter

	-- Update button highlights
	for name, btn in pairs(filterButtons) do
		if name == filter then
			btn.BackgroundColor3 = Color3.fromRGB(60, 80, 160)
			btn.TextColor3       = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
			btn.TextColor3       = Color3.fromRGB(160, 160, 190)
		end
	end

	-- Show/hide rows
	for _, item in ipairs(brainrotRows) do
		item.row.Visible = (filter == "ALL" or item.rarity == filter)
	end
end

-- Wire up filter buttons
for name, btn in pairs(filterButtons) do
	btn.MouseButton1Click:Connect(function()
		applyFilter(name)
	end)
end

-- ============================================================
-- TAB 2: GACHA
-- ============================================================

local GachaPage = Instance.new("Frame")
GachaPage.Name                   = "GachaPage"
GachaPage.Size                   = UDim2.new(1, 0, 1, 0)
GachaPage.BackgroundTransparency = 1
GachaPage.Visible                = false
GachaPage.ZIndex                 = 7
GachaPage.Parent                 = ContentArea

-- Spin button
local SpinBtn = button(GachaPage, "🎰  SPIN  ($" .. GACHA_COST .. ")", Color3.fromRGB(180, 30, 180))
SpinBtn.Size     = UDim2.new(0, 220, 0, 54)
SpinBtn.Position = UDim2.new(0.5, -110, 0, 4)
SpinBtn.ZIndex   = 8
stroke(SpinBtn, Color3.fromRGB(220, 80, 220), 2)

-- Odds table
local OddsFrame = Instance.new("Frame")
OddsFrame.Name             = "OddsFrame"
OddsFrame.Size             = UDim2.new(0, 200, 0, 140)
OddsFrame.Position         = UDim2.new(0.5, -100, 0, 66)
OddsFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
OddsFrame.BorderSizePixel  = 0
OddsFrame.ZIndex           = 8
OddsFrame.Parent           = GachaPage
corner(OddsFrame, 8)
padding(OddsFrame, 8)

local OddsLayout = Instance.new("UIListLayout")
OddsLayout.SortOrder = Enum.SortOrder.LayoutOrder
OddsLayout.Padding   = UDim.new(0, 3)
OddsLayout.Parent    = OddsFrame

for i, entry in ipairs(GACHA_ODDS) do
	local row = Instance.new("Frame")
	row.Size                   = UDim2.new(1, 0, 0, 20)
	row.BackgroundTransparency = 1
	row.LayoutOrder            = i
	row.ZIndex                 = 9
	row.Parent                 = OddsFrame

	local rarityColor = RARITY_COLOR[entry.rarity] or Color3.fromRGB(200, 200, 200)

	local rLabel = label(row, entry.rarity, 12, rarityColor, Enum.Font.GothamBold)
	rLabel.Size     = UDim2.new(0.65, 0, 1, 0)
	rLabel.Position = UDim2.new(0, 0, 0, 0)
	rLabel.ZIndex   = 9

	local cLabel = label(row, entry.chance, 12, Color3.fromRGB(200, 200, 200))
	cLabel.Size     = UDim2.new(0.35, 0, 1, 0)
	cLabel.Position = UDim2.new(0.65, 0, 0, 0)
	cLabel.TextXAlignment = Enum.TextXAlignment.Right
	cLabel.ZIndex   = 9
end

-- Recent pulls label
local PullsTitle = label(GachaPage, "Recent Pulls:", 12, Color3.fromRGB(160, 160, 200), Enum.Font.GothamBold)
PullsTitle.Size     = UDim2.new(1, 0, 0, 18)
PullsTitle.Position = UDim2.new(0, 0, 0, 214)
PullsTitle.TextXAlignment = Enum.TextXAlignment.Center
PullsTitle.ZIndex   = 8

local PullsFrame = Instance.new("Frame")
PullsFrame.Name                   = "PullsFrame"
PullsFrame.Size                   = UDim2.new(1, 0, 0, 28)
PullsFrame.Position               = UDim2.new(0, 0, 0, 236)
PullsFrame.BackgroundTransparency = 1
PullsFrame.ZIndex                 = 8
PullsFrame.Parent                 = GachaPage

local PullsLayout = Instance.new("UIListLayout")
PullsLayout.FillDirection = Enum.FillDirection.Horizontal
PullsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
PullsLayout.SortOrder = Enum.SortOrder.LayoutOrder
PullsLayout.Padding   = UDim.new(0, 6)
PullsLayout.Parent    = PullsFrame

local pullLabels = {}
for i = 1, 5 do
	local pill = Instance.new("Frame")
	pill.Size             = UDim2.new(0, 88, 1, 0)
	pill.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
	pill.BorderSizePixel  = 0
	pill.LayoutOrder      = i
	pill.ZIndex           = 9
	pill.Parent           = PullsFrame
	corner(pill, 6)

	local pillLabel = label(pill, "—", 11, Color3.fromRGB(120, 120, 140), Enum.Font.Gotham)
	pillLabel.Size             = UDim2.new(1, 0, 1, 0)
	pillLabel.TextXAlignment   = Enum.TextXAlignment.Center
	pillLabel.ZIndex           = 10

	pullLabels[i] = { frame = pill, label = pillLabel }
end

local function refreshPullHistory()
	for i = 1, 5 do
		local pull = recentPulls[i]
		if pull then
			local color = RARITY_COLOR[pull.rarity] or Color3.fromRGB(200, 200, 200)
			pullLabels[i].label.Text       = pull.name or pull.id or "?"
			pullLabels[i].label.TextColor3 = color
			pullLabels[i].frame.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
		else
			pullLabels[i].label.Text       = "—"
			pullLabels[i].label.TextColor3 = Color3.fromRGB(120, 120, 140)
		end
	end
end

-- Result popup (shown briefly after a spin)
local ResultPopup = Instance.new("Frame")
ResultPopup.Name             = "ResultPopup"
ResultPopup.Size             = UDim2.new(0, 260, 0, 70)
ResultPopup.Position         = UDim2.new(0.5, -130, 0, 270)
ResultPopup.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
ResultPopup.BorderSizePixel  = 0
ResultPopup.Visible          = false
ResultPopup.ZIndex           = 12
ResultPopup.Parent           = GachaPage
corner(ResultPopup, 10)
stroke(ResultPopup, Color3.fromRGB(150, 80, 220), 2)

local ResultLabel = label(ResultPopup, "", 15, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
ResultLabel.Size             = UDim2.new(1, 0, 1, 0)
ResultLabel.TextXAlignment   = Enum.TextXAlignment.Center
ResultLabel.ZIndex           = 13

local function showResultPopup(text, color)
	ResultLabel.Text       = text
	ResultLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	ResultPopup.Visible    = true
	task.delay(3, function()
		ResultPopup.Visible = false
	end)
end

-- ============================================================
-- TAB 3: STATS
-- ============================================================

local StatsPage = Instance.new("Frame")
StatsPage.Name                   = "StatsPage"
StatsPage.Size                   = UDim2.new(1, 0, 1, 0)
StatsPage.BackgroundTransparency = 1
StatsPage.Visible                = false
StatsPage.ZIndex                 = 7
StatsPage.Parent                 = ContentArea

local StatsBox = Instance.new("Frame")
StatsBox.Name             = "StatsBox"
StatsBox.Size             = UDim2.new(0, 300, 0, 160)
StatsBox.Position         = UDim2.new(0.5, -150, 0, 10)
StatsBox.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
StatsBox.BorderSizePixel  = 0
StatsBox.ZIndex           = 8
StatsBox.Parent           = StatsPage
corner(StatsBox, 10)
padding(StatsBox, 14)

local StatsLayout = Instance.new("UIListLayout")
StatsLayout.SortOrder = Enum.SortOrder.LayoutOrder
StatsLayout.Padding   = UDim.new(0, 8)
StatsLayout.Parent    = StatsBox

local MoneyStatLabel    = label(StatsBox, "💰 Money: $0",    14, Color3.fromRGB(100, 240, 100), Enum.Font.GothamBold)
MoneyStatLabel.Size     = UDim2.new(1, 0, 0, 18)
MoneyStatLabel.LayoutOrder = 1
MoneyStatLabel.ZIndex   = 9

local RebirthStatLabel  = label(StatsBox, "🔄 Rebirths: 0", 14, Color3.fromRGB(160, 120, 255), Enum.Font.GothamBold)
RebirthStatLabel.Size   = UDim2.new(1, 0, 0, 18)
RebirthStatLabel.LayoutOrder = 2
RebirthStatLabel.ZIndex = 9

local MultStatLabel     = label(StatsBox, "⚡ Multiplier: 1x", 14, Color3.fromRGB(255, 200, 60), Enum.Font.GothamBold)
MultStatLabel.Size      = UDim2.new(1, 0, 0, 18)
MultStatLabel.LayoutOrder = 3
MultStatLabel.ZIndex    = 9

local RebirthHint = label(StatsBox, "Rebirth for $" .. REBIRTH_COST .. " → permanent income boost", 12, Color3.fromRGB(160, 160, 190))
RebirthHint.Size      = UDim2.new(1, 0, 0, 30)
RebirthHint.LayoutOrder = 4
RebirthHint.ZIndex    = 9
RebirthHint.TextWrapped = true

local RebirthBtn = button(StatsPage, "REBIRTH", Color3.fromRGB(100, 30, 160))
RebirthBtn.Size     = UDim2.new(0, 180, 0, 42)
RebirthBtn.Position = UDim2.new(0.5, -90, 0, 180)
RebirthBtn.ZIndex   = 8
stroke(RebirthBtn, Color3.fromRGB(160, 80, 255), 2)

-- Confirm bar (hidden until rebirth clicked)
local ConfirmBar = Instance.new("Frame")
ConfirmBar.Name                   = "ConfirmBar"
ConfirmBar.Size                   = UDim2.new(0, 320, 0, 44)
ConfirmBar.Position               = UDim2.new(0.5, -160, 0, 234)
ConfirmBar.BackgroundColor3       = Color3.fromRGB(30, 20, 46)
ConfirmBar.BorderSizePixel        = 0
ConfirmBar.Visible                = false
ConfirmBar.ZIndex                 = 8
ConfirmBar.Parent                 = StatsPage
corner(ConfirmBar, 8)
stroke(ConfirmBar, Color3.fromRGB(140, 60, 220), 1.5)

local ConfirmLabel = label(ConfirmBar, "Are you sure? This resets your brainrots!", 12, Color3.fromRGB(255, 200, 80))
ConfirmLabel.Size     = UDim2.new(1, 0, 0, 18)
ConfirmLabel.Position = UDim2.new(0, 0, 0, 4)
ConfirmLabel.TextXAlignment = Enum.TextXAlignment.Center
ConfirmLabel.ZIndex   = 9

local YesBtn = button(ConfirmBar, "YES", Color3.fromRGB(160, 30, 30))
YesBtn.Size     = UDim2.new(0, 90, 0, 24)
YesBtn.Position = UDim2.new(0.5, -96, 1, -28)
YesBtn.ZIndex   = 9

local NoBtn = button(ConfirmBar, "NO", Color3.fromRGB(40, 120, 40))
NoBtn.Size     = UDim2.new(0, 90, 0, 24)
NoBtn.Position = UDim2.new(0.5, 6, 1, -28)
NoBtn.ZIndex   = 9

local function refreshStats()
	MoneyStatLabel.Text   = "💰 Money: $" .. getMoney()
	RebirthStatLabel.Text = "🔄 Rebirths: "  .. getRebirths()
	MultStatLabel.Text    = "⚡ Multiplier: " .. getMultiplier() .. "x"
end

-- ============================================================
-- Tab switching
-- ============================================================

local pages = {
	INFO  = InfoPage,
	GACHA = GachaPage,
	STATS = StatsPage,
}

local tabBtns = {
	INFO  = TabInfo,
	GACHA = TabGacha,
	STATS = TabStats,
}

local function switchTab(tab)
	activeTab = tab
	for key, page in pairs(pages) do
		page.Visible = (key == tab)
	end
	for key, btn in pairs(tabBtns) do
		if key == tab then
			btn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
			btn.TextColor3       = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
			btn.TextColor3       = Color3.fromRGB(160, 160, 190)
		end
	end
	if tab == "STATS" then
		refreshStats()
	end
end

TabInfo.MouseButton1Click:Connect(function()  switchTab("INFO")  end)
TabGacha.MouseButton1Click:Connect(function() switchTab("GACHA") end)
TabStats.MouseButton1Click:Connect(function() switchTab("STATS") end)

-- ============================================================
-- Open / close shop
-- ============================================================

local OPEN_POS  = UDim2.new(0.5, -275, 0.5, -240)
local CLOSE_POS = UDim2.new(0.5, -275, 1.5, 0)
local TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function openShop()
	if shopOpen then return end
	shopOpen = true
	buildBrainrotList()
	applyFilter("ALL")
	switchTab("INFO")
	Panel.Position = CLOSE_POS
	Panel.Visible  = true
	Overlay.Visible = true
	TweenService:Create(Panel, TWEEN_INFO, { Position = OPEN_POS }):Play()
end

local function closeShop()
	if not shopOpen then return end
	shopOpen = false
	rebirthPending = false
	ConfirmBar.Visible = false
	local tween = TweenService:Create(Panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = CLOSE_POS })
	tween:Play()
	tween.Completed:Connect(function()
		Panel.Visible   = false
		Overlay.Visible = false
	end)
end

OpenShopEvent.OnClientEvent:Connect(openShop)
CloseBtn.MouseButton1Click:Connect(closeShop)
Overlay.MouseButton1Click:Connect(closeShop)

-- ============================================================
-- Gacha spin
-- ============================================================

SpinBtn.MouseButton1Click:Connect(function()
	if gachaSpinning then return end
	gachaSpinning = true
	SpinBtn.Text = "Spinning..."
	SpinBtn.BackgroundColor3 = Color3.fromRGB(100, 20, 100)
	SpinGachaEvent:FireServer()
	task.delay(1, function()
		gachaSpinning = false
		SpinBtn.Text = "🎰  SPIN  ($" .. GACHA_COST .. ")"
		SpinBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 180)
	end)
end)

-- ============================================================
-- Rebirth
-- ============================================================

RebirthBtn.MouseButton1Click:Connect(function()
	ConfirmBar.Visible = not ConfirmBar.Visible
end)

YesBtn.MouseButton1Click:Connect(function()
	ConfirmBar.Visible = false
	RebirthEvent:FireServer()
end)

NoBtn.MouseButton1Click:Connect(function()
	ConfirmBar.Visible = false
end)

-- ============================================================
-- Notifications from server (gacha results, etc.)
-- ============================================================

NotificationEvent.OnClientEvent:Connect(function(data)
	if type(data) == "table" then
		local name    = data.name or data.id or "Unknown"
		local rarity  = data.rarity or "Common"
		local color   = RARITY_COLOR[rarity] or Color3.fromRGB(200, 200, 200)

		-- Add to history (newest first)
		table.insert(recentPulls, 1, data)
		if #recentPulls > 5 then
			table.remove(recentPulls, 6)
		end

		refreshPullHistory()
		showResultPopup("✨ " .. rarity .. ": " .. name .. "!", color)
	end
end)

-- ============================================================
-- Keep stats live when stats tab is open
-- ============================================================

player:GetAttributeChangedSignal("Money"):Connect(function()
	if activeTab == "STATS" and shopOpen then
		refreshStats()
	end
	-- Also update money in header if desired (no header money display in this version)
end)
