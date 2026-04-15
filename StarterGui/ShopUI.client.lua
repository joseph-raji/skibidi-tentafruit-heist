-- ShopUI.client.lua
-- LocalScript: Shop UI for Skibidi Tentafruit
-- Place in StarterGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local SkinData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SkinData"))

local RE = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenShopEvent     = RE:WaitForChild("OpenShop")
local SpinGachaEvent    = RE:WaitForChild("SpinGacha")
local BuyItemEvent      = RE:WaitForChild("BuyItem")
local RebirthEvent      = RE:WaitForChild("Rebirth")
local NotificationEvent = RE:WaitForChild("Notification")
local OpenFusionEvent   = RE:WaitForChild("OpenFusion")
local FuseRequestEvent  = RE:WaitForChild("FuseRequest")
local FuseOptionsEvent  = RE:WaitForChild("FuseOptions")
local FuseChooseEvent   = RE:WaitForChild("FuseChoose")

-- ============================================================
-- Config
-- ============================================================

local GACHA_COST   = 150
local REBIRTH_COST = 10000

-- Equipment items (mirrors ItemsSystem.ITEMS)
local ITEMS = {
	{ id = "power_bat",      name = "Power Bat",       category = "Weapon",   cost = 500,  icon = "🏏", description = "2x range, stuns enemies 2s" },
	{ id = "rocket_bat",     name = "Rocket Bat",       category = "Weapon",   cost = 2500, icon = "🚀", description = "AOE blast — drops ALL carriers nearby" },
	{ id = "grappling_hook", name = "Grappling Hook",   category = "Mobility", cost = 1500, icon = "🪝", description = "Zip forward to any point" },
	{ id = "speed_boots",    name = "Speed Boots",       category = "Mobility", cost = 600,  icon = "👟", description = "50% speed boost for 20s (consumable)" },
	{ id = "invis_cap",      name = "Invisibility Cap", category = "Stealth",  cost = 1000, icon = "🪄", description = "Turn invisible for 10s (consumable)" },
	{ id = "spike_trap",     name = "Spike Trap",        category = "Trap",     cost = 350,  icon = "⚡", description = "Slows enemies who step on it" },
	{ id = "alarm_trap",     name = "Alarm Trap",         category = "Trap",     cost = 450,  icon = "🔔", description = "Notifies you when enemy enters base" },
	{ id = "freeze_trap",    name = "Freeze Trap",        category = "Trap",     cost = 900,  icon = "❄️", description = "Anchors enemy in place for 3s" },
	{ id = "bouncer_trap",   name = "Bouncer",            category = "Trap",     cost = 1200, icon = "🌀", description = "Launches intruders out of your base" },
	{ id = "shield_bubble",  name = "Shield Bubble",      category = "Defense",  cost = 800,  icon = "🛡️", description = "Absorbs one bat hit (consumable)" },
}

local CATEGORY_COLOR = {
	Weapon   = Color3.fromRGB(220, 60,  60),
	Mobility = Color3.fromRGB(80,  140, 255),
	Stealth  = Color3.fromRGB(200, 200, 200),
	Trap     = Color3.fromRGB(255, 160, 30),
	Defense  = Color3.fromRGB(0,   210, 220),
}

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

local TabInfo  = makeTab("TabInfo",  "🛍️ EQUIPMENT",  1)
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
-- TAB 1: SKIN INFO
-- ============================================================

local InfoPage = Instance.new("Frame")
InfoPage.Name                   = "InfoPage"
InfoPage.Size                   = UDim2.new(1, 0, 1, 0)
InfoPage.BackgroundTransparency = 1
InfoPage.ZIndex                 = 7
InfoPage.Parent                 = ContentArea

-- Hint text
local HintLabel = label(InfoPage, "Buy equipment below — get skins on the red carpet!", 13, Color3.fromRGB(140, 220, 140))
HintLabel.Size     = UDim2.new(1, 0, 0, 22)
HintLabel.Position = UDim2.new(0, 0, 0, 0)
HintLabel.TextXAlignment = Enum.TextXAlignment.Center
HintLabel.ZIndex   = 8

-- Category filter bar
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
	b.Size             = UDim2.new(0, 78, 1, 0)
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

makeFilterBtn("ALL",      1)
makeFilterBtn("Weapon",   2)
makeFilterBtn("Mobility", 3)
makeFilterBtn("Stealth",  4)
makeFilterBtn("Trap",     5)
makeFilterBtn("Defense",  6)

-- Scrollable list
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name                   = "ItemList"
ScrollFrame.Size                   = UDim2.new(1, 0, 1, -58)
ScrollFrame.Position               = UDim2.new(0, 0, 0, 58)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.ScrollBarThickness     = 4
ScrollFrame.ScrollBarImageColor3   = Color3.fromRGB(80, 80, 120)
ScrollFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize    = Enum.AutomaticSize.Y
ScrollFrame.ZIndex                 = 8
ScrollFrame.Parent                 = InfoPage

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding   = UDim.new(0, 4)
ListLayout.Parent    = ScrollFrame

local itemRows = {}  -- { row, category }

local function buildItemList()
	for _, r in ipairs(itemRows) do r.row:Destroy() end
	itemRows = {}

	for i, entry in ipairs(ITEMS) do
		local catColor = CATEGORY_COLOR[entry.category] or Color3.fromRGB(160, 160, 160)

		local row = Instance.new("Frame")
		row.Name             = "Row_" .. i
		row.Size             = UDim2.new(1, -4, 0, 44)
		row.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
		row.BorderSizePixel  = 0
		row.LayoutOrder      = i
		row.ZIndex           = 9
		row.Parent           = ScrollFrame
		corner(row, 6)

		-- Category color strip
		local strip = Instance.new("Frame")
		strip.Size             = UDim2.new(0, 4, 1, 0)
		strip.BackgroundColor3 = catColor
		strip.BorderSizePixel  = 0
		strip.ZIndex           = 10
		strip.Parent           = row
		corner(strip, 3)

		-- Icon + Name
		local nameLabel = label(row, entry.icon .. "  " .. entry.name, 13, Color3.fromRGB(230, 230, 230), Enum.Font.GothamBold)
		nameLabel.Size     = UDim2.new(0, 190, 0, 20)
		nameLabel.Position = UDim2.new(0, 12, 0, 4)
		nameLabel.ZIndex   = 10

		-- Description
		local descLabel = label(row, entry.description, 10, Color3.fromRGB(150, 150, 170), Enum.Font.Gotham)
		descLabel.Size     = UDim2.new(0, 190, 0, 16)
		descLabel.Position = UDim2.new(0, 12, 0, 24)
		descLabel.ZIndex   = 10

		-- Cost
		local costLabel = label(row, "$" .. entry.cost, 12, Color3.fromRGB(255, 210, 80), Enum.Font.GothamBold)
		costLabel.Size     = UDim2.new(0, 80, 1, 0)
		costLabel.Position = UDim2.new(0, 210, 0, 0)
		costLabel.ZIndex   = 10

		-- BUY button
		local buyBtn = button(row, "BUY", Color3.fromRGB(40, 140, 60), Color3.fromRGB(255, 255, 255))
		buyBtn.Size     = UDim2.new(0, 70, 0, 28)
		buyBtn.Position = UDim2.new(1, -78, 0.5, -14)
		buyBtn.ZIndex   = 11
		buyBtn.MouseButton1Click:Connect(function()
			BuyItemEvent:FireServer(entry.id)
		end)

		table.insert(itemRows, { row = row, category = entry.category })
	end
end

local function applyFilter(filter)
	activeFilter = filter
	for name, btn in pairs(filterButtons) do
		if name == filter then
			btn.BackgroundColor3 = Color3.fromRGB(60, 80, 160)
			btn.TextColor3       = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
			btn.TextColor3       = Color3.fromRGB(160, 160, 190)
		end
	end
	for _, item in ipairs(itemRows) do
		item.row.Visible = (filter == "ALL" or item.category == filter)
	end
end

for name, btn in pairs(filterButtons) do
	btn.MouseButton1Click:Connect(function() applyFilter(name) end)
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
-- TAB 3: RENAISSANCE (rebirth screen)
-- ============================================================

local StatsPage = Instance.new("Frame")
StatsPage.Name                   = "StatsPage"
StatsPage.Size                   = UDim2.new(1, 0, 1, 0)
StatsPage.BackgroundTransparency = 1
StatsPage.Visible                = false
StatsPage.ZIndex                 = 7
StatsPage.Parent                 = ContentArea

-- Warning text
local WarnLabel = Instance.new("TextLabel")
WarnLabel.Size                   = UDim2.new(1, -20, 0, 42)
WarnLabel.Position               = UDim2.new(0, 10, 0, 6)
WarnLabel.BackgroundTransparency = 1
WarnLabel.Text                   = "[AVERTISSEMENT] Tu perdras tous les personnages\nCash et Brainrot que tu possèdes quand tu renaîtras"
WarnLabel.TextColor3             = Color3.fromRGB(255, 80, 60)
WarnLabel.TextScaled             = true
WarnLabel.Font                   = Enum.Font.GothamBold
WarnLabel.TextWrapped            = true
WarnLabel.ZIndex                 = 8
WarnLabel.Parent                 = StatsPage

-- "Tu débloqueras:" header
local UnlockTitle = Instance.new("TextLabel")
UnlockTitle.Size                   = UDim2.new(1, -20, 0, 22)
UnlockTitle.Position               = UDim2.new(0, 10, 0, 52)
UnlockTitle.BackgroundTransparency = 1
UnlockTitle.Text                   = "Tu débloqueras:"
UnlockTitle.TextColor3             = Color3.fromRGB(255, 210, 0)
UnlockTitle.TextScaled             = true
UnlockTitle.Font                   = Enum.Font.GothamBold
UnlockTitle.ZIndex                 = 8
UnlockTitle.Parent                 = StatsPage

-- Unlock tiles grid
local UnlockGrid = Instance.new("Frame")
UnlockGrid.Size             = UDim2.new(1, -20, 0, 80)
UnlockGrid.Position         = UDim2.new(0, 10, 0, 76)
UnlockGrid.BackgroundTransparency = 1
UnlockGrid.ZIndex           = 8
UnlockGrid.Parent           = StatsPage

local gridLayout = Instance.new("UIListLayout")
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.SortOrder     = Enum.SortOrder.LayoutOrder
gridLayout.Padding       = UDim.new(0, 6)
gridLayout.Parent        = UnlockGrid

local unlockDefs = {
	{ top = "MULTI",        icon = "⚡", bottom = "x??" },
	{ top = "ARGENT",       icon = "💰", bottom = "$500K" },
	{ top = "Base verrouillée", icon = "🔒", bottom = "+10s" },
	{ top = "Emplacement",  icon = "📦", bottom = "+1" },
}
local MultTile -- reference to update multiplier value
for i, def in ipairs(unlockDefs) do
	local tile = Instance.new("Frame")
	tile.Size             = UDim2.new(0, 115, 1, 0)
	tile.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
	tile.BorderSizePixel  = 0
	tile.LayoutOrder      = i
	tile.ZIndex           = 9
	tile.Parent           = UnlockGrid
	corner(tile, 8)
	stroke(tile, Color3.fromRGB(70, 80, 120), 1.5)

	local topLbl = Instance.new("TextLabel")
	topLbl.Size = UDim2.new(1, 0, 0.3, 0); topLbl.Position = UDim2.new(0, 0, 0, 0)
	topLbl.BackgroundTransparency = 1; topLbl.Text = def.top
	topLbl.TextScaled = true; topLbl.Font = Enum.Font.Gotham
	topLbl.TextColor3 = Color3.fromRGB(180, 185, 210); topLbl.ZIndex = 10; topLbl.Parent = tile

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Size = UDim2.new(1, 0, 0.4, 0); iconLbl.Position = UDim2.new(0, 0, 0.3, 0)
	iconLbl.BackgroundTransparency = 1; iconLbl.Text = def.icon
	iconLbl.TextScaled = true; iconLbl.Font = Enum.Font.GothamBold
	iconLbl.TextColor3 = Color3.fromRGB(255, 255, 255); iconLbl.ZIndex = 10; iconLbl.Parent = tile

	local botLbl = Instance.new("TextLabel")
	botLbl.Size = UDim2.new(1, 0, 0.3, 0); botLbl.Position = UDim2.new(0, 0, 0.7, 0)
	botLbl.BackgroundTransparency = 1; botLbl.Text = def.bottom
	botLbl.TextScaled = true; botLbl.Font = Enum.Font.GothamBold
	botLbl.TextColor3 = Color3.fromRGB(100, 230, 100); botLbl.ZIndex = 10; botLbl.Parent = tile

	if def.top == "MULTI" then MultTile = botLbl end
end

-- "Requis:" label
local RequisLabel = Instance.new("TextLabel")
RequisLabel.Size                   = UDim2.new(1, -20, 0, 18)
RequisLabel.Position               = UDim2.new(0, 10, 0, 164)
RequisLabel.BackgroundTransparency = 1
RequisLabel.Text                   = "Requis:"
RequisLabel.TextColor3             = Color3.fromRGB(255, 210, 0)
RequisLabel.TextScaled             = true
RequisLabel.Font                   = Enum.Font.GothamBold
RequisLabel.ZIndex                 = 8
RequisLabel.Parent                 = StatsPage

-- Progress bar background
local BarBG = Instance.new("Frame")
BarBG.Size             = UDim2.new(1, -20, 0, 22)
BarBG.Position         = UDim2.new(0, 10, 0, 186)
BarBG.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
BarBG.BorderSizePixel  = 0
BarBG.ZIndex           = 8
BarBG.Parent           = StatsPage
corner(BarBG, 4)

local BarFill = Instance.new("Frame")
BarFill.Size             = UDim2.new(0, 0, 1, 0)
BarFill.BackgroundColor3 = Color3.fromRGB(190, 140, 30)
BarFill.BorderSizePixel  = 0
BarFill.ZIndex           = 9
BarFill.Parent           = BarBG
corner(BarFill, 4)

local BarLabel = Instance.new("TextLabel")
BarLabel.Size                   = UDim2.fromScale(1, 1)
BarLabel.BackgroundTransparency = 1
BarLabel.Text                   = "$0 / $" .. REBIRTH_COST
BarLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
BarLabel.TextScaled             = true
BarLabel.Font                   = Enum.Font.GothamBold
BarLabel.ZIndex                 = 10
BarLabel.Parent                 = BarBG

-- Stats row (money / rebirths / multiplier — small, for reference)
local MoneyStatLabel   = Instance.new("TextLabel")
MoneyStatLabel.Size                   = UDim2.new(1, -20, 0, 16)
MoneyStatLabel.Position               = UDim2.new(0, 10, 0, 214)
MoneyStatLabel.BackgroundTransparency = 1
MoneyStatLabel.Text                   = "💰 $0  |  🔄 0 renaissances  |  ⚡ x1"
MoneyStatLabel.TextColor3             = Color3.fromRGB(160, 165, 190)
MoneyStatLabel.TextScaled             = true
MoneyStatLabel.Font                   = Enum.Font.Gotham
MoneyStatLabel.ZIndex                 = 8
MoneyStatLabel.Parent                 = StatsPage
-- keep legacy variable names alive for refreshStats
local RebirthStatLabel = MoneyStatLabel  -- same label, updated together
local MultStatLabel    = MoneyStatLabel

-- RENAISSANCE button
local RebirthBtn = button(StatsPage, "Renaissance", Color3.fromRGB(120, 100, 20))
RebirthBtn.Size     = UDim2.new(1, -20, 0, 42)
RebirthBtn.Position = UDim2.new(0, 10, 0, 238)
RebirthBtn.ZIndex   = 8
RebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RebirthBtn.Font     = Enum.Font.GothamBold
stroke(RebirthBtn, Color3.fromRGB(200, 170, 30), 2)

-- Confirm bar (hidden until rebirth clicked)
local ConfirmBar = Instance.new("Frame")
ConfirmBar.Name                   = "ConfirmBar"
ConfirmBar.Size                   = UDim2.new(1, -20, 0, 44)
ConfirmBar.Position               = UDim2.new(0, 10, 0, 285)
ConfirmBar.BackgroundColor3       = Color3.fromRGB(25, 18, 14)
ConfirmBar.BorderSizePixel        = 0
ConfirmBar.Visible                = false
ConfirmBar.ZIndex                 = 8
ConfirmBar.Parent                 = StatsPage
corner(ConfirmBar, 8)
stroke(ConfirmBar, Color3.fromRGB(200, 60, 40), 1.5)

local ConfirmLabel = label(ConfirmBar, "Sûr(e) ? Tu perdras tout !", 12, Color3.fromRGB(255, 200, 80))
ConfirmLabel.Size     = UDim2.new(1, 0, 0, 18)
ConfirmLabel.Position = UDim2.new(0, 0, 0, 4)
ConfirmLabel.TextXAlignment = Enum.TextXAlignment.Center
ConfirmLabel.ZIndex   = 9

local YesBtn = button(ConfirmBar, "OUI", Color3.fromRGB(160, 30, 30))
YesBtn.Size     = UDim2.new(0, 90, 0, 24)
YesBtn.Position = UDim2.new(0.5, -96, 1, -28)
YesBtn.ZIndex   = 9

local NoBtn = button(ConfirmBar, "NON", Color3.fromRGB(40, 120, 40))
NoBtn.Size     = UDim2.new(0, 90, 0, 24)
NoBtn.Position = UDim2.new(0.5, 6, 1, -28)
NoBtn.ZIndex   = 9

local function refreshStats()
	local money    = getMoney()
	local rebirths = getRebirths()
	local mult     = getMultiplier()
	local nextMult = math.floor(mult * 1.5 * 10) / 10

	MoneyStatLabel.Text = "💰 $" .. money .. "  |  🔄 " .. rebirths .. " renaissances  |  ⚡ x" .. mult
	if MultTile then MultTile.Text = "x" .. nextMult end

	-- Progress bar
	local pct = math.min(money / REBIRTH_COST, 1)
	BarFill.Size  = UDim2.new(pct, 0, 1, 0)
	BarLabel.Text = "$" .. money .. " / $" .. REBIRTH_COST
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
	buildItemList()
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
	-- Show gacha wheel in HUD (it listens for GachaResult to stop)
	local wheelGui = player.PlayerGui:FindFirstChild("GachaWheelGui")
	if wheelGui then
		wheelGui.Enabled = true
	end
	task.delay(3.5, function()
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

-- ============================================================
-- FUSION UI (opened by pressing E on the Fusion Machine)
-- ============================================================

local fusionOpen       = false
local fusionSelected   = {}   -- up to 2 selected skin IDs

-- Fusion ScreenGui
local FusionGui = Instance.new("ScreenGui")
FusionGui.Name           = "FusionUI"
FusionGui.ResetOnSpawn   = false
FusionGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
FusionGui.IgnoreGuiInset = true
FusionGui.Parent         = PlayerGui

local FusOverlay = Instance.new("TextButton")
FusOverlay.Size                   = UDim2.new(1, 0, 1, 0)
FusOverlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
FusOverlay.BackgroundTransparency = 0.6
FusOverlay.Text                   = ""
FusOverlay.Visible                = false
FusOverlay.ZIndex                 = 50
FusOverlay.Parent                 = FusionGui

local FusPanel = Instance.new("Frame")
FusPanel.Name             = "FusionPanel"
FusPanel.Size             = UDim2.new(0, 520, 0, 500)
FusPanel.Position         = UDim2.new(0.5, -260, 1.5, 0)
FusPanel.BackgroundColor3 = Color3.fromRGB(16, 16, 28)
FusPanel.BorderSizePixel  = 0
FusPanel.Visible          = false
FusPanel.ZIndex           = 51
FusPanel.Parent           = FusionGui
corner(FusPanel, 14)
stroke(FusPanel, Color3.fromRGB(120, 60, 220), 2)

-- Header
local FusHeader = Instance.new("Frame")
FusHeader.Size             = UDim2.new(1, 0, 0, 46)
FusHeader.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
FusHeader.BorderSizePixel  = 0
FusHeader.ZIndex           = 52
FusHeader.Parent           = FusPanel
corner(FusHeader, 14)
local FusHeaderFill = Instance.new("Frame")
FusHeaderFill.Size             = UDim2.new(1, 0, 0.5, 0)
FusHeaderFill.Position         = UDim2.new(0, 0, 0.5, 0)
FusHeaderFill.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
FusHeaderFill.BorderSizePixel  = 0
FusHeaderFill.ZIndex           = 52
FusHeaderFill.Parent           = FusHeader

local FusTitleLabel = Instance.new("TextLabel")
FusTitleLabel.Size                   = UDim2.new(1, -52, 1, 0)
FusTitleLabel.Position               = UDim2.new(0, 14, 0, 0)
FusTitleLabel.BackgroundTransparency = 1
FusTitleLabel.Text                   = "⚡ FUSION MACHINE"
FusTitleLabel.TextScaled             = true
FusTitleLabel.Font                   = Enum.Font.GothamBold
FusTitleLabel.TextColor3             = Color3.fromRGB(255, 255, 100)
FusTitleLabel.ZIndex                 = 53
FusTitleLabel.Parent                 = FusHeader

local FusCloseBtn = Instance.new("TextButton")
FusCloseBtn.Size             = UDim2.new(0, 32, 0, 32)
FusCloseBtn.Position         = UDim2.new(1, -40, 0.5, -16)
FusCloseBtn.BackgroundColor3 = Color3.fromRGB(190, 45, 45)
FusCloseBtn.Text             = "✕"
FusCloseBtn.TextScaled       = true
FusCloseBtn.Font             = Enum.Font.GothamBold
FusCloseBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
FusCloseBtn.ZIndex           = 54
FusCloseBtn.Parent           = FusHeader
corner(FusCloseBtn, 8)

-- Selection bar
local FusSelBar = Instance.new("Frame")
FusSelBar.Size             = UDim2.new(1, -20, 0, 56)
FusSelBar.Position         = UDim2.new(0, 10, 0, 52)
FusSelBar.BackgroundColor3 = Color3.fromRGB(24, 22, 40)
FusSelBar.BorderSizePixel  = 0
FusSelBar.ZIndex           = 52
FusSelBar.Parent           = FusPanel
corner(FusSelBar, 8)

local FusSlot1Label = Instance.new("TextLabel")
FusSlot1Label.Size                   = UDim2.new(0.45, 0, 1, 0)
FusSlot1Label.Position               = UDim2.new(0, 8, 0, 0)
FusSlot1Label.BackgroundTransparency = 1
FusSlot1Label.Text                   = "Slot 1: —"
FusSlot1Label.TextScaled             = true
FusSlot1Label.Font                   = Enum.Font.Gotham
FusSlot1Label.TextColor3             = Color3.fromRGB(180, 180, 220)
FusSlot1Label.ZIndex                 = 53
FusSlot1Label.Parent                 = FusSelBar

local FusPlusLabel = Instance.new("TextLabel")
FusPlusLabel.Size                   = UDim2.new(0, 30, 1, 0)
FusPlusLabel.Position               = UDim2.new(0.45, 0, 0, 0)
FusPlusLabel.BackgroundTransparency = 1
FusPlusLabel.Text                   = "+"
FusPlusLabel.TextScaled             = true
FusPlusLabel.Font                   = Enum.Font.GothamBold
FusPlusLabel.TextColor3             = Color3.fromRGB(255, 220, 50)
FusPlusLabel.TextXAlignment         = Enum.TextXAlignment.Center
FusPlusLabel.ZIndex                 = 53
FusPlusLabel.Parent                 = FusSelBar

local FusSlot2Label = Instance.new("TextLabel")
FusSlot2Label.Size                   = UDim2.new(0.45, -8, 1, 0)
FusSlot2Label.Position               = UDim2.new(0.5, 0, 0, 0)
FusSlot2Label.BackgroundTransparency = 1
FusSlot2Label.Text                   = "Slot 2: —"
FusSlot2Label.TextScaled             = true
FusSlot2Label.Font                   = Enum.Font.Gotham
FusSlot2Label.TextColor3             = Color3.fromRGB(180, 180, 220)
FusSlot2Label.ZIndex                 = 53
FusSlot2Label.Parent                 = FusSelBar

-- Scrollable collection list
local FusScroll = Instance.new("ScrollingFrame")
FusScroll.Size                = UDim2.new(1, -20, 1, -180)
FusScroll.Position            = UDim2.new(0, 10, 0, 116)
FusScroll.BackgroundColor3    = Color3.fromRGB(20, 20, 32)
FusScroll.BorderSizePixel     = 0
FusScroll.ScrollBarThickness  = 4
FusScroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
FusScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
FusScroll.ZIndex              = 52
FusScroll.Parent              = FusPanel
corner(FusScroll, 8)

local FusListLayout = Instance.new("UIListLayout")
FusListLayout.SortOrder = Enum.SortOrder.LayoutOrder
FusListLayout.Padding   = UDim.new(0, 4)
FusListLayout.Parent    = FusScroll
local FusListPad = Instance.new("UIPadding")
FusListPad.PaddingLeft  = UDim.new(0, 6)
FusListPad.PaddingRight = UDim.new(0, 6)
FusListPad.PaddingTop   = UDim.new(0, 4)
FusListPad.Parent       = FusScroll

-- FUSE button
local FuseBtn = Instance.new("TextButton")
FuseBtn.Size             = UDim2.new(0, 200, 0, 44)
FuseBtn.Position         = UDim2.new(0.5, -100, 1, -54)
FuseBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 160)
FuseBtn.Text             = "⚡ FUSE"
FuseBtn.TextScaled       = true
FuseBtn.Font             = Enum.Font.GothamBold
FuseBtn.TextColor3       = Color3.fromRGB(255, 255, 100)
FuseBtn.ZIndex           = 52
FuseBtn.Parent           = FusPanel
corner(FuseBtn, 10)
stroke(FuseBtn, Color3.fromRGB(160, 80, 255), 2)

-- Result overlay (shown after server picks 4 options)
local FusResultPanel = Instance.new("Frame")
FusResultPanel.Size                   = UDim2.new(1, 0, 1, 0)
FusResultPanel.BackgroundColor3       = Color3.fromRGB(12, 10, 22)
FusResultPanel.BackgroundTransparency = 0.05
FusResultPanel.BorderSizePixel        = 0
FusResultPanel.Visible                = false
FusResultPanel.ZIndex                 = 60
FusResultPanel.Parent                 = FusPanel
corner(FusResultPanel, 14)

local FusResultTitle = Instance.new("TextLabel")
FusResultTitle.Size                   = UDim2.new(1, 0, 0, 50)
FusResultTitle.Position               = UDim2.new(0, 0, 0, 8)
FusResultTitle.BackgroundTransparency = 1
FusResultTitle.Text                   = "Pick your fusion result!"
FusResultTitle.TextScaled             = true
FusResultTitle.Font                   = Enum.Font.GothamBold
FusResultTitle.TextColor3             = Color3.fromRGB(255, 255, 100)
FusResultTitle.ZIndex                 = 61
FusResultTitle.Parent                 = FusResultPanel

-- 4 result cards (2x2 grid)
local resultCards = {}
local cardPositions = {
	UDim2.new(0, 10,    0, 66),
	UDim2.new(0.5, 5,   0, 66),
	UDim2.new(0, 10,    0, 278),
	UDim2.new(0.5, 5,   0, 278),
}

local function closeFusion()
	if not fusionOpen then return end
	fusionOpen = false
	FusResultPanel.Visible = false
	local tween = TweenService:Create(FusPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, -260, 1.5, 0)
	})
	tween:Play()
	tween.Completed:Connect(function()
		FusPanel.Visible   = false
		FusOverlay.Visible = false
	end)
end

for i = 1, 4 do
	local card = Instance.new("Frame")
	card.Size             = UDim2.new(0.5, -15, 0, 198)
	card.Position         = cardPositions[i]
	card.BackgroundColor3 = Color3.fromRGB(28, 24, 46)
	card.BorderSizePixel  = 0
	card.ZIndex           = 61
	card.Parent           = FusResultPanel
	corner(card, 10)
	stroke(card, Color3.fromRGB(100, 60, 180), 1.5)

	local cardLabel = Instance.new("TextLabel")
	cardLabel.Size                   = UDim2.new(1, -8, 1, -44)
	cardLabel.Position               = UDim2.new(0, 4, 0, 4)
	cardLabel.BackgroundTransparency = 1
	cardLabel.Text                   = ""
	cardLabel.TextScaled             = true
	cardLabel.Font                   = Enum.Font.Gotham
	cardLabel.TextColor3             = Color3.fromRGB(220, 220, 255)
	cardLabel.TextWrapped            = true
	cardLabel.ZIndex                 = 62
	cardLabel.Parent                 = card

	local pickBtn = Instance.new("TextButton")
	pickBtn.Size             = UDim2.new(0.7, 0, 0, 32)
	pickBtn.Position         = UDim2.new(0.15, 0, 1, -36)
	pickBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
	pickBtn.Text             = "PICK"
	pickBtn.TextScaled       = true
	pickBtn.Font             = Enum.Font.GothamBold
	pickBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
	pickBtn.ZIndex           = 63
	pickBtn.Parent           = card
	corner(pickBtn, 6)

	local idx = i
	pickBtn.MouseButton1Click:Connect(function()
		FuseChooseEvent:FireServer(idx)
		closeFusion()
	end)

	resultCards[i] = { card = card, label = cardLabel, pickBtn = pickBtn }
end

-- Helpers
local function updateSelectionLabels()
	local id1 = fusionSelected[1]
	local id2 = fusionSelected[2]
	if id1 then
		local d = SkinData.getById(id1)
		FusSlot1Label.Text      = "Slot 1: " .. (d and d.name or id1)
		FusSlot1Label.TextColor3 = Color3.fromRGB(100, 255, 180)
	else
		FusSlot1Label.Text      = "Slot 1: —"
		FusSlot1Label.TextColor3 = Color3.fromRGB(180, 180, 220)
	end
	if id2 then
		local d = SkinData.getById(id2)
		FusSlot2Label.Text      = "Slot 2: " .. (d and d.name or id2)
		FusSlot2Label.TextColor3 = Color3.fromRGB(100, 255, 180)
	else
		FusSlot2Label.Text      = "Slot 2: —"
		FusSlot2Label.TextColor3 = Color3.fromRGB(180, 180, 220)
	end
end

local fusRowById = {}

local function buildFusionList(collectionData)
	for _, row in pairs(fusRowById) do
		if row and row.Parent then row:Destroy() end
	end
	fusRowById = {}

	local order = 0
	local hasAny = false
	for skinId, count in pairs(collectionData) do
		if type(count) == "number" and count > 0 then
			local def = SkinData.getById(skinId)
			if def then
				hasAny = true
				order = order + 1
				local rarityColor = RARITY_COLOR[def.rarity] or Color3.fromRGB(200, 200, 200)

				local row = Instance.new("TextButton")
				row.Size             = UDim2.new(1, 0, 0, 44)
				row.BackgroundColor3 = Color3.fromRGB(28, 26, 44)
				row.Text             = ""
				row.BorderSizePixel  = 0
				row.LayoutOrder      = order
				row.ZIndex           = 53
				row.Parent           = FusScroll
				corner(row, 6)

				local nameL = Instance.new("TextLabel")
				nameL.Size                   = UDim2.new(0.6, 0, 1, 0)
				nameL.Position               = UDim2.new(0, 8, 0, 0)
				nameL.BackgroundTransparency = 1
				nameL.Text                   = def.name .. " (x" .. count .. ")"
				nameL.TextScaled             = true
				nameL.Font                   = Enum.Font.GothamBold
				nameL.TextColor3             = Color3.fromRGB(220, 220, 255)
				nameL.TextXAlignment         = Enum.TextXAlignment.Left
				nameL.ZIndex                 = 54
				nameL.Parent                 = row

				local rarL = Instance.new("TextLabel")
				rarL.Size                   = UDim2.new(0.36, 0, 1, 0)
				rarL.Position               = UDim2.new(0.62, 0, 0, 0)
				rarL.BackgroundTransparency = 1
				rarL.Text                   = def.rarity
				rarL.TextScaled             = true
				rarL.Font                   = Enum.Font.Gotham
				rarL.TextColor3             = rarityColor
				rarL.TextXAlignment         = Enum.TextXAlignment.Right
				rarL.ZIndex                 = 54
				rarL.Parent                 = row

				local id = skinId
				row.MouseButton1Click:Connect(function()
					-- Toggle selection
					if fusionSelected[1] == id and fusionSelected[2] == id then
						fusionSelected[2] = nil
					elseif fusionSelected[1] == id then
						fusionSelected[1] = fusionSelected[2]; fusionSelected[2] = nil
					elseif fusionSelected[2] == id then
						fusionSelected[2] = nil
					elseif not fusionSelected[1] then
						fusionSelected[1] = id
					elseif not fusionSelected[2] then
						fusionSelected[2] = id
					else
						fusionSelected[1] = fusionSelected[2]; fusionSelected[2] = id
					end
					updateSelectionLabels()
					for rid, r in pairs(fusRowById) do
						if r and r.Parent then
							local sel = (fusionSelected[1] == rid or fusionSelected[2] == rid)
							r.BackgroundColor3 = sel and Color3.fromRGB(50, 40, 80) or Color3.fromRGB(28, 26, 44)
						end
					end
				end)

				fusRowById[skinId] = row
			end
		end
	end

	if not hasAny then
		local empty = Instance.new("TextLabel")
		empty.Size                   = UDim2.new(1, 0, 0, 44)
		empty.BackgroundTransparency = 1
		empty.Text                   = "You have no skins to fuse!"
		empty.TextScaled             = true
		empty.Font                   = Enum.Font.Gotham
		empty.TextColor3             = Color3.fromRGB(160, 160, 180)
		empty.TextXAlignment         = Enum.TextXAlignment.Center
		empty.ZIndex                 = 53
		empty.Parent                 = FusScroll
	end
end

local function openFusion(collectionData)
	if fusionOpen then return end
	fusionOpen = true
	fusionSelected = {}
	FusResultPanel.Visible = false
	updateSelectionLabels()
	buildFusionList(collectionData or {})
	FusPanel.Position  = UDim2.new(0.5, -260, 1.5, 0)
	FusPanel.Visible   = true
	FusOverlay.Visible = true
	TweenService:Create(FusPanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -260, 0.5, -250)
	}):Play()
end

-- Events
OpenFusionEvent.OnClientEvent:Connect(function(collectionData)
	openFusion(collectionData)
end)

FuseOptionsEvent.OnClientEvent:Connect(function(options)
	local labels = { "▼ WORSE", "▼ WORSE", "▲ BETTER", "★ LEGENDARY" }
	for i = 1, 4 do
		local opt  = options[i]
		local card = resultCards[i]
		if card and opt then
			local rColor = RARITY_COLOR[opt.rarity] or Color3.fromRGB(200, 200, 200)
			card.label.Text      = labels[i] .. "\n\n" .. opt.name .. "\n[" .. opt.rarity .. "]\n$" .. (opt.income or 0) .. "/s"
			card.label.TextColor3 = rColor
			card.pickBtn.Visible = true
		elseif card then
			card.label.Text      = "—"
			card.pickBtn.Visible = false
		end
	end
	FusResultPanel.Visible = true
end)

FuseBtn.MouseButton1Click:Connect(function()
	local id1 = fusionSelected[1]
	local id2 = fusionSelected[2]
	if not id1 or not id2 then return end
	FuseRequestEvent:FireServer(id1, id2)
end)

FusCloseBtn.MouseButton1Click:Connect(closeFusion)
FusOverlay.MouseButton1Click:Connect(closeFusion)
