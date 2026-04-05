-- Pokedex.client.lua
-- StarterGui LocalScript for Skibidi Tentafruit Heist
-- Full Pokédex / collection browser UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BrainrotData = require(Modules:WaitForChild("BrainrotData"))

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenPokedexEvent = RemoteEvents:WaitForChild("OpenPokedex")
local CollectionUpdatedEvent = RemoteEvents:WaitForChild("CollectionUpdated")

-- ============================================================
-- CONSTANTS
-- ============================================================

local TOTAL_BRAINROTS = 25

local RARITY_COLORS = {
	Common    = Color3.fromRGB(160, 160, 160),
	Uncommon  = Color3.fromRGB(80,  200,  80),
	Rare      = Color3.fromRGB(60,  120, 240),
	Epic      = Color3.fromRGB(160,  60, 240),
	Legendary = Color3.fromRGB(255, 200,  30),
}

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local RARITY_BORDER = {
	Common    = Color3.fromRGB(130, 130, 130),
	Uncommon  = Color3.fromRGB(50,  180,  50),
	Rare      = Color3.fromRGB(40,  100, 220),
	Epic      = Color3.fromRGB(140,  40, 220),
	Legendary = Color3.fromRGB(255, 180,   0),
}

local CARD_BG = {
	Common    = Color3.fromRGB(35,  35,  40),
	Uncommon  = Color3.fromRGB(20,  45,  20),
	Rare      = Color3.fromRGB(15,  25,  60),
	Epic      = Color3.fromRGB(35,  10,  60),
	Legendary = Color3.fromRGB(55,  40,   5),
}

local PANEL_BG     = Color3.fromRGB(13,  13,  26)
local HEADER_BG    = Color3.fromRGB(18,  10,  40)
local FILTER_BG    = Color3.fromRGB(20,  15,  45)
local DETAIL_BG    = Color3.fromRGB(18,  12,  38)
local TEXT_PRIMARY = Color3.fromRGB(230, 230, 255)
local TEXT_DIM     = Color3.fromRGB(120, 120, 160)

local TWEEN_OPEN  = TweenInfo.new(0.35, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local TWEEN_CLOSE = TweenInfo.new(0.25, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)
local TWEEN_SLIDE = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- ============================================================
-- STATE
-- ============================================================

local playerCollection = {}   -- { [brainrotId] = count }
local currentFilter    = "ALL"
local showMode         = "ALL"   -- ALL / OWNED / MISSING
local sortMode         = "RARITY"
local pokedexOpen      = false
local detailOpen       = false
local legendaryConnections = {}  -- shimmer RunService connections

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

local function makeCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function makeStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(80, 80, 120)
	s.Thickness = thickness or 1.5
	s.Parent = parent
	return s
end

local function makePadding(parent, top, right, bottom, left)
	local p = Instance.new("UIPadding")
	p.PaddingTop    = UDim.new(0, top    or 8)
	p.PaddingRight  = UDim.new(0, right  or 8)
	p.PaddingBottom = UDim.new(0, bottom or 8)
	p.PaddingLeft   = UDim.new(0, left   or 8)
	p.Parent = parent
	return p
end

local function newLabel(text, size, color, parent, bold)
	local l = Instance.new("TextLabel")
	l.Text              = text
	l.TextSize          = size or 14
	l.TextColor3        = color or TEXT_PRIMARY
	l.Font              = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.BackgroundTransparency = 1
	l.TextXAlignment    = Enum.TextXAlignment.Left
	l.TextWrapped       = true
	l.Size              = UDim2.new(1, 0, 0, size and size + 6 or 20)
	l.Parent            = parent
	return l
end

local function newButton(text, size, bgColor, textColor, parent)
	local b = Instance.new("TextButton")
	b.Text           = text
	b.TextSize       = size or 13
	b.Font           = Enum.Font.GothamBold
	b.TextColor3     = textColor or Color3.fromRGB(255, 255, 255)
	b.BackgroundColor3 = bgColor or Color3.fromRGB(60, 60, 100)
	b.AutoButtonColor  = false
	b.Size           = UDim2.new(1, 0, 0, 32)
	b.Parent         = parent
	makeCorner(b, 8)
	return b
end

local function rarityIndex(rarity)
	for i, r in ipairs(RARITY_ORDER) do
		if r == rarity then return i end
	end
	return 0
end

local function getTotalOwned()
	local total = 0
	for _, count in pairs(playerCollection) do
		total = total + count
	end
	return total
end

local function getUniqueOwned()
	local unique = 0
	for _, count in pairs(playerCollection) do
		if count > 0 then unique = unique + 1 end
	end
	return unique
end

local function getTotalIncome()
	local income = 0
	local all = BrainrotData.getAll()
	for _, b in ipairs(all) do
		local count = playerCollection[b.id] or 0
		if count > 0 then
			income = income + (b.incomePerSecond or 0) * count
		end
	end
	return income
end

local function getRarestOwned()
	local best = nil
	local bestIdx = 0
	local all = BrainrotData.getAll()
	for _, b in ipairs(all) do
		local count = playerCollection[b.id] or 0
		if count > 0 then
			local idx = rarityIndex(b.rarity)
			if idx > bestIdx then
				bestIdx = idx
				best = b
			end
		end
	end
	return best
end

-- ============================================================
-- BUILD UI
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name              = "PokedexGui"
ScreenGui.ResetOnSpawn      = false
ScreenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset    = true
ScreenGui.Parent            = PlayerGui

-- Backdrop (click-to-close)
local Backdrop = Instance.new("TextButton")
Backdrop.Name                = "Backdrop"
Backdrop.Size                = UDim2.new(1, 0, 1, 0)
Backdrop.BackgroundColor3    = Color3.fromRGB(0, 0, 0)
Backdrop.BackgroundTransparency = 0.5
Backdrop.Text                = ""
Backdrop.ZIndex              = 5
Backdrop.Visible             = false
Backdrop.Parent              = ScreenGui

-- Main Panel
local MainPanel = Instance.new("Frame")
MainPanel.Name              = "MainPanel"
MainPanel.Size              = UDim2.new(0, 700, 0, 550)
MainPanel.Position          = UDim2.new(0.5, -350, 0.5, -275)
MainPanel.BackgroundColor3  = PANEL_BG
MainPanel.ZIndex            = 6
MainPanel.Visible           = false
MainPanel.Parent            = ScreenGui
makeCorner(MainPanel, 16)
makeStroke(MainPanel, Color3.fromRGB(80, 60, 140), 2)

-- Start off-screen for slide-in
MainPanel.Position = UDim2.new(0.5, -350, 1.5, 0)

-- ---- HEADER ----
local Header = Instance.new("Frame")
Header.Name            = "Header"
Header.Size            = UDim2.new(1, 0, 0, 70)
Header.BackgroundColor3 = HEADER_BG
Header.ZIndex          = 7
Header.Parent          = MainPanel
makeCorner(Header, 16)

-- Header bottom corners square
local HeaderFill = Instance.new("Frame")
HeaderFill.Size              = UDim2.new(1, 0, 0.5, 0)
HeaderFill.Position          = UDim2.new(0, 0, 0.5, 0)
HeaderFill.BackgroundColor3  = HEADER_BG
HeaderFill.BorderSizePixel   = 0
HeaderFill.ZIndex            = 7
HeaderFill.Parent            = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text              = "BRAINROT POKÉDEX"
TitleLabel.TextSize          = 22
TitleLabel.Font              = Enum.Font.GothamBlack
TitleLabel.TextColor3        = Color3.fromRGB(200, 160, 255)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Size              = UDim2.new(1, -120, 0, 36)
TitleLabel.Position          = UDim2.new(0, 16, 0, 6)
TitleLabel.TextXAlignment    = Enum.TextXAlignment.Left
TitleLabel.ZIndex            = 8
TitleLabel.Parent            = Header

local SubLabel = Instance.new("TextLabel")
SubLabel.Text               = "Collect them all!"
SubLabel.TextSize           = 13
SubLabel.Font               = Enum.Font.Gotham
SubLabel.TextColor3         = TEXT_DIM
SubLabel.BackgroundTransparency = 1
SubLabel.Size               = UDim2.new(1, -120, 0, 20)
SubLabel.Position           = UDim2.new(0, 16, 0, 40)
SubLabel.TextXAlignment     = Enum.TextXAlignment.Left
SubLabel.ZIndex             = 8
SubLabel.Parent             = Header

-- Close button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Text               = "✕"
CloseBtn.TextSize           = 18
CloseBtn.Font               = Enum.Font.GothamBold
CloseBtn.TextColor3         = Color3.fromRGB(200, 150, 255)
CloseBtn.BackgroundColor3   = Color3.fromRGB(40, 20, 60)
CloseBtn.Size               = UDim2.new(0, 36, 0, 36)
CloseBtn.Position           = UDim2.new(1, -48, 0, 17)
CloseBtn.ZIndex             = 9
CloseBtn.AutoButtonColor    = false
CloseBtn.Parent             = Header
makeCorner(CloseBtn, 8)

-- Progress bar
local ProgressBg = Instance.new("Frame")
ProgressBg.Name             = "ProgressBg"
ProgressBg.Size             = UDim2.new(1, -32, 0, 12)
ProgressBg.Position         = UDim2.new(0, 16, 0, 56)
ProgressBg.BackgroundColor3 = Color3.fromRGB(30, 20, 55)
ProgressBg.ZIndex           = 8
ProgressBg.Parent           = Header
makeCorner(ProgressBg, 6)

local ProgressFill = Instance.new("Frame")
ProgressFill.Name           = "ProgressFill"
ProgressFill.Size           = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = Color3.fromRGB(120, 80, 220)
ProgressFill.ZIndex         = 9
ProgressFill.Parent         = ProgressBg
makeCorner(ProgressFill, 6)

local ProgressLabel = Instance.new("TextLabel")
ProgressLabel.Name          = "ProgressLabel"
ProgressLabel.Text          = "0 / 25 Collected"
ProgressLabel.TextSize      = 11
ProgressLabel.Font          = Enum.Font.GothamBold
ProgressLabel.TextColor3    = Color3.fromRGB(200, 180, 255)
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Size          = UDim2.new(1, 0, 1, 0)
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Center
ProgressLabel.ZIndex        = 10
ProgressLabel.Parent        = ProgressBg

-- ---- BODY (below header) ----
local Body = Instance.new("Frame")
Body.Name               = "Body"
Body.Size               = UDim2.new(1, 0, 1, -70)
Body.Position           = UDim2.new(0, 0, 0, 70)
Body.BackgroundTransparency = 1
Body.ZIndex             = 7
Body.Parent             = MainPanel

-- ---- LEFT PANEL (filters) ----
local LeftPanel = Instance.new("Frame")
LeftPanel.Name              = "LeftPanel"
LeftPanel.Size              = UDim2.new(0, 155, 1, -10)
LeftPanel.Position          = UDim2.new(0, 8, 0, 5)
LeftPanel.BackgroundColor3  = FILTER_BG
LeftPanel.ZIndex            = 8
LeftPanel.Parent            = Body
makeCorner(LeftPanel, 10)
makeStroke(LeftPanel, Color3.fromRGB(60, 40, 100), 1.5)

local LeftScroll = Instance.new("ScrollingFrame")
LeftScroll.Size             = UDim2.new(1, -8, 1, -8)
LeftScroll.Position         = UDim2.new(0, 4, 0, 4)
LeftScroll.BackgroundTransparency = 1
LeftScroll.ScrollBarThickness = 3
LeftScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 70, 180)
LeftScroll.CanvasSize       = UDim2.new(0, 0, 0, 0)
LeftScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
LeftScroll.ZIndex           = 9
LeftScroll.Parent           = LeftPanel

local LeftLayout = Instance.new("UIListLayout")
LeftLayout.FillDirection    = Enum.FillDirection.Vertical
LeftLayout.SortOrder        = Enum.SortOrder.LayoutOrder
LeftLayout.Padding          = UDim.new(0, 6)
LeftLayout.Parent           = LeftScroll
makePadding(LeftScroll, 8, 4, 8, 4)

-- Section label helper
local function sectionLabel(text, parent, order)
	local l = Instance.new("TextLabel")
	l.Text              = text
	l.TextSize          = 11
	l.Font              = Enum.Font.GothamBold
	l.TextColor3        = TEXT_DIM
	l.BackgroundTransparency = 1
	l.Size              = UDim2.new(1, 0, 0, 18)
	l.TextXAlignment    = Enum.TextXAlignment.Left
	l.LayoutOrder       = order or 0
	l.ZIndex            = 10
	l.Parent            = parent
	return l
end

sectionLabel("RARITY FILTER", LeftScroll, 1)

-- Rarity filter buttons
local rarityFilterBtns = {}
local rarityFilterOptions = { "ALL", "Common", "Uncommon", "Rare", "Epic", "Legendary" }

for i, rarity in ipairs(rarityFilterOptions) do
	local color = RARITY_COLORS[rarity] or Color3.fromRGB(80, 60, 130)
	local btn = Instance.new("TextButton")
	btn.Text            = rarity == "ALL" and "ALL" or ("● " .. rarity)
	btn.TextSize        = 12
	btn.Font            = Enum.Font.GothamBold
	btn.TextColor3      = rarity == "ALL" and TEXT_PRIMARY or color
	btn.BackgroundColor3 = Color3.fromRGB(30, 20, 55)
	btn.Size            = UDim2.new(1, 0, 0, 28)
	btn.LayoutOrder     = i + 1
	btn.AutoButtonColor = false
	btn.ZIndex          = 10
	btn.Parent          = LeftScroll
	makeCorner(btn, 7)
	rarityFilterBtns[rarity] = btn
end

sectionLabel("SHOW", LeftScroll, 10)

-- Show mode toggles
local showModeBtns = {}
local showModeOptions = { "ALL", "OWNED", "MISSING" }
for i, mode in ipairs(showModeOptions) do
	local btn = Instance.new("TextButton")
	btn.Text            = mode
	btn.TextSize        = 12
	btn.Font            = Enum.Font.GothamBold
	btn.TextColor3      = TEXT_PRIMARY
	btn.BackgroundColor3 = Color3.fromRGB(30, 20, 55)
	btn.Size            = UDim2.new(1, 0, 0, 28)
	btn.LayoutOrder     = 10 + i
	btn.AutoButtonColor = false
	btn.ZIndex          = 10
	btn.Parent          = LeftScroll
	makeCorner(btn, 7)
	showModeBtns[mode] = btn
end

sectionLabel("SORT BY", LeftScroll, 20)

local sortBtns = {}
local sortOptions = { "NAME", "RARITY", "INCOME" }
for i, sort in ipairs(sortOptions) do
	local btn = Instance.new("TextButton")
	btn.Text            = sort
	btn.TextSize        = 12
	btn.Font            = Enum.Font.GothamBold
	btn.TextColor3      = TEXT_PRIMARY
	btn.BackgroundColor3 = Color3.fromRGB(30, 20, 55)
	btn.Size            = UDim2.new(1, 0, 0, 28)
	btn.LayoutOrder     = 20 + i
	btn.AutoButtonColor = false
	btn.ZIndex          = 10
	btn.Parent          = LeftScroll
	makeCorner(btn, 7)
	sortBtns[sort] = btn
end

-- ---- MAIN GRID PANEL ----
local GridPanel = Instance.new("Frame")
GridPanel.Name              = "GridPanel"
GridPanel.Size              = UDim2.new(1, -170, 1, -70)
GridPanel.Position          = UDim2.new(0, 168, 0, 5)
GridPanel.BackgroundColor3  = Color3.fromRGB(16, 10, 32)
GridPanel.ZIndex            = 8
GridPanel.Parent            = Body
makeCorner(GridPanel, 10)
makeStroke(GridPanel, Color3.fromRGB(50, 35, 90), 1.5)

local GridScroll = Instance.new("ScrollingFrame")
GridScroll.Name             = "GridScroll"
GridScroll.Size             = UDim2.new(1, -8, 1, -8)
GridScroll.Position         = UDim2.new(0, 4, 0, 4)
GridScroll.BackgroundTransparency = 1
GridScroll.ScrollBarThickness = 5
GridScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 70, 180)
GridScroll.CanvasSize       = UDim2.new(0, 0, 0, 0)
GridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
GridScroll.ZIndex           = 9
GridScroll.Parent           = GridPanel

local GridLayout = Instance.new("UIGridLayout")
GridLayout.CellSize         = UDim2.new(0, 120, 0, 140)
GridLayout.CellPadding      = UDim2.new(0, 8, 0, 8)
GridLayout.SortOrder        = Enum.SortOrder.LayoutOrder
GridLayout.Parent           = GridScroll
makePadding(GridScroll, 8, 8, 8, 8)

-- ---- STATS BAR (bottom of main panel) ----
local StatsBar = Instance.new("Frame")
StatsBar.Name               = "StatsBar"
StatsBar.Size               = UDim2.new(1, -170, 0, 54)
StatsBar.Position           = UDim2.new(0, 168, 1, -60)
StatsBar.BackgroundColor3   = Color3.fromRGB(15, 8, 35)
StatsBar.ZIndex             = 8
StatsBar.Parent             = Body
makeCorner(StatsBar, 10)
makeStroke(StatsBar, Color3.fromRGB(60, 40, 110), 1.5)

local StatsLayout = Instance.new("UIListLayout")
StatsLayout.FillDirection   = Enum.FillDirection.Horizontal
StatsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
StatsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
StatsLayout.Padding         = UDim.new(0, 0)
StatsLayout.Parent          = StatsBar
makePadding(StatsBar, 4, 8, 4, 8)

local function statChunk(parent, order)
	local f = Instance.new("Frame")
	f.Size              = UDim2.new(0.25, 0, 1, 0)
	f.BackgroundTransparency = 1
	f.LayoutOrder       = order
	f.ZIndex            = 9
	f.Parent            = parent

	local top = Instance.new("TextLabel")
	top.TextSize        = 11
	top.Font            = Enum.Font.Gotham
	top.TextColor3      = TEXT_DIM
	top.BackgroundTransparency = 1
	top.Size            = UDim2.new(1, 0, 0.45, 0)
	top.TextXAlignment  = Enum.TextXAlignment.Center
	top.ZIndex          = 10
	top.Parent          = f

	local bot = Instance.new("TextLabel")
	bot.TextSize        = 13
	bot.Font            = Enum.Font.GothamBold
	bot.TextColor3      = TEXT_PRIMARY
	bot.BackgroundTransparency = 1
	bot.Size            = UDim2.new(1, 0, 0.55, 0)
	bot.Position        = UDim2.new(0, 0, 0.45, 0)
	bot.TextXAlignment  = Enum.TextXAlignment.Center
	bot.ZIndex          = 10
	bot.Parent          = f

	return top, bot
end

local statTopOwned,  statBotOwned  = statChunk(StatsBar, 1)
local statTopIncome, statBotIncome = statChunk(StatsBar, 2)
local statTopRarest, statBotRarest = statChunk(StatsBar, 3)
local statTopMsg,    statBotMsg    = statChunk(StatsBar, 4)

statTopOwned.Text  = "TOTAL OWNED"
statTopIncome.Text = "TOTAL INCOME/s"
statTopRarest.Text = "RAREST OWNED"
statTopMsg.Text    = "PROGRESS"

-- ---- DETAIL PANEL (slides in from right) ----
local DetailPanel = Instance.new("Frame")
DetailPanel.Name            = "DetailPanel"
DetailPanel.Size            = UDim2.new(0, 240, 1, -16)
DetailPanel.Position        = UDim2.new(1, 10, 0, 8)  -- hidden off right edge
DetailPanel.BackgroundColor3 = DETAIL_BG
DetailPanel.ZIndex          = 12
DetailPanel.ClipsDescendants = true
DetailPanel.Parent          = MainPanel
makeCorner(DetailPanel, 12)
makeStroke(DetailPanel, Color3.fromRGB(100, 60, 180), 2)

local DetailScroll = Instance.new("ScrollingFrame")
DetailScroll.Size           = UDim2.new(1, 0, 1, 0)
DetailScroll.BackgroundTransparency = 1
DetailScroll.ScrollBarThickness = 4
DetailScroll.ScrollBarImageColor3 = Color3.fromRGB(120, 80, 200)
DetailScroll.CanvasSize     = UDim2.new(0, 0, 0, 0)
DetailScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
DetailScroll.ZIndex         = 13
DetailScroll.Parent         = DetailPanel

local DetailLayout = Instance.new("UIListLayout")
DetailLayout.FillDirection  = Enum.FillDirection.Vertical
DetailLayout.SortOrder      = Enum.SortOrder.LayoutOrder
DetailLayout.Padding        = UDim.new(0, 8)
DetailLayout.Parent         = DetailScroll
makePadding(DetailScroll, 12, 10, 12, 10)

-- Detail elements (will be populated when showing)
local DetailName       = newLabel("", 18, TEXT_PRIMARY, DetailScroll, true)
DetailName.LayoutOrder = 1
DetailName.TextXAlignment = Enum.TextXAlignment.Center

local DetailRarity = newLabel("", 13, TEXT_DIM, DetailScroll, false)
DetailRarity.LayoutOrder = 2
DetailRarity.TextXAlignment = Enum.TextXAlignment.Center

local DetailSeparator = Instance.new("Frame")
DetailSeparator.Size  = UDim2.new(1, 0, 0, 1)
DetailSeparator.BackgroundColor3 = Color3.fromRGB(80, 50, 130)
DetailSeparator.LayoutOrder = 3
DetailSeparator.BorderSizePixel = 0
DetailSeparator.Parent = DetailScroll

local DetailDesc  = newLabel("", 12, TEXT_DIM, DetailScroll, false)
DetailDesc.LayoutOrder = 4
DetailDesc.TextWrapped = true
DetailDesc.Size   = UDim2.new(1, 0, 0, 60)

local DetailIncome = newLabel("", 14, Color3.fromRGB(100, 220, 100), DetailScroll, true)
DetailIncome.LayoutOrder = 5
DetailIncome.TextXAlignment = Enum.TextXAlignment.Center

local DetailCost   = newLabel("", 13, Color3.fromRGB(255, 200, 80), DetailScroll, false)
DetailCost.LayoutOrder = 6
DetailCost.TextXAlignment = Enum.TextXAlignment.Center

local DetailOwned  = newLabel("", 13, TEXT_PRIMARY, DetailScroll, false)
DetailOwned.LayoutOrder = 7
DetailOwned.TextXAlignment = Enum.TextXAlignment.Center

local DetailHowGet = newLabel("", 12, TEXT_DIM, DetailScroll, false)
DetailHowGet.LayoutOrder = 8
DetailHowGet.TextWrapped = true
DetailHowGet.Size = UDim2.new(1, 0, 0, 36)

local DetailClose  = newButton("Nice!", 14, Color3.fromRGB(80, 40, 160), Color3.fromRGB(255, 255, 255), DetailScroll)
DetailClose.LayoutOrder = 9
DetailClose.Size   = UDim2.new(1, 0, 0, 36)

-- ============================================================
-- HUD BUTTON (connects to existing HUD)
-- ============================================================
-- The HUD has a POKÉDEX button somewhere in StarterGui. We listen for it.
-- We also accept the server remote event. Attempt to hook up existing HUD button if present.

task.delay(1, function()
	-- Look for a button named "PokedexButton" or "POKÉDEX" in any ScreenGui
	for _, gui in ipairs(PlayerGui:GetChildren()) do
		if gui:IsA("ScreenGui") then
			local btn = gui:FindFirstChild("PokedexButton", true)
			if not btn then
				btn = gui:FindFirstChild("POKEDEX", true)
			end
			if btn and btn:IsA("TextButton") or (btn and btn:IsA("ImageButton")) then
				btn.MouseButton1Click:Connect(function()
					if pokedexOpen then
						closePokedex()
					else
						openPokedex()
					end
				end)
				break
			end
		end
	end
end)

-- ============================================================
-- FILTER & SORT LOGIC
-- ============================================================

local function getFilteredSorted()
	local all = BrainrotData.getAll()
	local filtered = {}
	for _, b in ipairs(all) do
		local passRarity = (currentFilter == "ALL") or (b.rarity == currentFilter)
		local count = playerCollection[b.id] or 0
		local passShow = true
		if showMode == "OWNED"   then passShow = count > 0 end
		if showMode == "MISSING" then passShow = count == 0 end
		if passRarity and passShow then
			table.insert(filtered, b)
		end
	end

	table.sort(filtered, function(a, b_)
		if sortMode == "NAME" then
			return a.name < b_.name
		elseif sortMode == "RARITY" then
			local diff = rarityIndex(b_.rarity) - rarityIndex(a.rarity)
			if diff ~= 0 then return diff > 0 end
			return a.name < b_.name
		elseif sortMode == "INCOME" then
			local ai = (a.incomePerSecond or 0)
			local bi = (b_.incomePerSecond or 0)
			if ai ~= bi then return ai > bi end
			return a.name < b_.name
		end
		return false
	end)

	return filtered
end

-- ============================================================
-- SHIMMER ANIMATION
-- ============================================================

local function attachShimmer(card)
	local shimmer = Instance.new("Frame")
	shimmer.Name              = "Shimmer"
	shimmer.Size              = UDim2.new(0, 30, 1, 0)
	shimmer.Position          = UDim2.new(-0.3, 0, 0, 0)
	shimmer.BackgroundColor3  = Color3.fromRGB(255, 240, 180)
	shimmer.BackgroundTransparency = 0.75
	shimmer.BorderSizePixel   = 0
	shimmer.ZIndex            = card.ZIndex + 2
	shimmer.Rotation          = 15
	shimmer.ClipsDescendants  = false
	shimmer.Parent            = card

	local t = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		t = t + dt * 0.6
		local x = (t % 1.6) / 1.6  -- 0..1 cycle
		shimmer.Position = UDim2.new(x - 0.2, 0, 0, 0)
		shimmer.BackgroundTransparency = 0.6 + math.abs(math.sin(t * math.pi)) * 0.35
	end)
	return conn
end

-- ============================================================
-- CARD BUILDER
-- ============================================================

local cardFrames = {}

local function buildCard(brainrot, layoutOrder)
	local owned = (playerCollection[brainrot.id] or 0) > 0
	local count = playerCollection[brainrot.id] or 0
	local isLegendary = brainrot.rarity == "Legendary"
	local revealName = brainrot.rarity ~= "Legendary" or owned

	local card = Instance.new("TextButton")
	card.Name               = "Card_" .. brainrot.id
	card.Text               = ""
	card.LayoutOrder        = layoutOrder
	card.BackgroundColor3   = owned and CARD_BG[brainrot.rarity] or Color3.fromRGB(20, 15, 30)
	card.AutoButtonColor    = false
	card.ClipsDescendants   = true
	card.ZIndex             = 10
	card.Parent             = GridScroll
	makeCorner(card, 10)

	local borderColor = owned and RARITY_BORDER[brainrot.rarity] or Color3.fromRGB(50, 40, 70)
	makeStroke(card, borderColor, owned and 2 or 1)

	if not owned then
		-- Darken overlay
		local overlay = Instance.new("Frame")
		overlay.Size              = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
		overlay.BackgroundTransparency = 0.45
		overlay.ZIndex            = 11
		overlay.Parent            = card

		-- Question mark
		local qmark = Instance.new("TextLabel")
		qmark.Text              = "?"
		qmark.TextSize          = 40
		qmark.Font              = Enum.Font.GothamBlack
		qmark.TextColor3        = Color3.fromRGB(80, 70, 100)
		qmark.BackgroundTransparency = 1
		qmark.Size              = UDim2.new(1, 0, 0, 55)
		qmark.Position          = UDim2.new(0, 0, 0, 20)
		qmark.TextXAlignment    = Enum.TextXAlignment.Center
		qmark.ZIndex            = 12
		qmark.Parent            = card
	else
		-- Emoji / icon area
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Text          = brainrot.icon or "?"
		iconLabel.TextSize      = 36
		iconLabel.Font          = Enum.Font.GothamBold
		iconLabel.TextColor3    = Color3.fromRGB(255, 255, 255)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Size          = UDim2.new(1, 0, 0, 50)
		iconLabel.Position      = UDim2.new(0, 0, 0, 12)
		iconLabel.TextXAlignment = Enum.TextXAlignment.Center
		iconLabel.ZIndex        = 11
		iconLabel.Parent        = card

		-- Owned count badge
		if count > 1 then
			local badge = Instance.new("Frame")
			badge.Size              = UDim2.new(0, 26, 0, 18)
			badge.Position          = UDim2.new(1, -28, 0, 5)
			badge.BackgroundColor3  = Color3.fromRGB(200, 60, 60)
			badge.ZIndex            = 14
			badge.Parent            = card
			makeCorner(badge, 9)

			local badgeLabel = Instance.new("TextLabel")
			badgeLabel.Text         = "x" .. count
			badgeLabel.TextSize     = 10
			badgeLabel.Font         = Enum.Font.GothamBold
			badgeLabel.TextColor3   = Color3.fromRGB(255, 255, 255)
			badgeLabel.BackgroundTransparency = 1
			badgeLabel.Size         = UDim2.new(1, 0, 1, 0)
			badgeLabel.TextXAlignment = Enum.TextXAlignment.Center
			badgeLabel.ZIndex       = 15
			badgeLabel.Parent       = badge
		end
	end

	-- Name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Text          = (owned or revealName) and brainrot.name or "???"
	nameLabel.TextSize      = 11
	nameLabel.Font          = Enum.Font.GothamBold
	nameLabel.TextColor3    = owned and TEXT_PRIMARY or TEXT_DIM
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size          = UDim2.new(1, -4, 0, 24)
	nameLabel.Position      = UDim2.new(0, 2, 0, 68)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextWrapped   = true
	nameLabel.ZIndex        = 12
	nameLabel.Parent        = card

	-- Rarity pip
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Text        = brainrot.rarity
	rarityLabel.TextSize    = 10
	rarityLabel.Font        = Enum.Font.GothamBold
	rarityLabel.TextColor3  = RARITY_COLORS[brainrot.rarity] or TEXT_DIM
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Size        = UDim2.new(1, -4, 0, 16)
	rarityLabel.Position    = UDim2.new(0, 2, 0, 92)
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
	rarityLabel.ZIndex      = 12
	rarityLabel.Parent      = card

	-- Income label
	if owned then
		local incLabel = Instance.new("TextLabel")
		incLabel.Text       = "+" .. (brainrot.incomePerSecond or 0) .. "$/s"
		incLabel.TextSize   = 10
		incLabel.Font       = Enum.Font.Gotham
		incLabel.TextColor3 = Color3.fromRGB(100, 220, 100)
		incLabel.BackgroundTransparency = 1
		incLabel.Size       = UDim2.new(1, -4, 0, 14)
		incLabel.Position   = UDim2.new(0, 2, 0, 108)
		incLabel.TextXAlignment = Enum.TextXAlignment.Center
		incLabel.ZIndex     = 12
		incLabel.Parent     = card
	end

	-- Legendary shimmer
	if owned and isLegendary then
		local conn = attachShimmer(card)
		table.insert(legendaryConnections, conn)
	end

	return card
end

-- ============================================================
-- UPDATE STATS BAR
-- ============================================================

local function updateStats()
	local unique  = getUniqueOwned()
	local total   = getTotalOwned()
	local income  = getTotalIncome()
	local rarest  = getRarestOwned()

	statBotOwned.Text  = tostring(total)
	statBotIncome.Text = "+" .. string.format("%.1f", income) .. "$/s"
	statBotRarest.Text = rarest and rarest.name or "None"

	local pct = math.floor((unique / TOTAL_BRAINROTS) * 100)
	if unique == TOTAL_BRAINROTS then
		statBotMsg.Text = "COMPLETE!"
		statTopMsg.Text = "POKÉDEX DONE"
	else
		statBotMsg.Text = pct .. "%"
	end

	-- Progress bar
	local ratio = unique / TOTAL_BRAINROTS
	TweenService:Create(ProgressFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(ratio, 0, 1, 0),
	}):Play()
	ProgressLabel.Text = unique .. " / " .. TOTAL_BRAINROTS .. " Collected"
end

-- ============================================================
-- UPDATE FILTER BUTTON VISUALS
-- ============================================================

local function updateFilterVisuals()
	for rarity, btn in pairs(rarityFilterBtns) do
		local active = (currentFilter == rarity)
		if active then
			btn.BackgroundColor3 = Color3.fromRGB(60, 35, 110)
			makeStroke(btn, RARITY_COLORS[rarity] or Color3.fromRGB(150, 120, 220), 2)
		else
			btn.BackgroundColor3 = Color3.fromRGB(30, 20, 55)
			-- Remove extra stroke by setting thickness to 0
			local s = btn:FindFirstChildWhichIsA("UIStroke")
			if s then s.Thickness = 0 end
		end
	end
	for mode, btn in pairs(showModeBtns) do
		btn.BackgroundColor3 = (showMode == mode) and Color3.fromRGB(60, 35, 110) or Color3.fromRGB(30, 20, 55)
	end
	for sort, btn in pairs(sortBtns) do
		btn.BackgroundColor3 = (sortMode == sort) and Color3.fromRGB(60, 35, 110) or Color3.fromRGB(30, 20, 55)
	end
end

-- ============================================================
-- REBUILD GRID
-- ============================================================

local function rebuildGrid()
	-- Disconnect shimmer connections
	for _, conn in ipairs(legendaryConnections) do
		conn:Disconnect()
	end
	legendaryConnections = {}

	-- Remove old cards
	for _, child in ipairs(GridScroll:GetChildren()) do
		if child:IsA("TextButton") and child.Name:sub(1, 5) == "Card_" then
			child:Destroy()
		end
	end
	cardFrames = {}

	local filtered = getFilteredSorted()
	for i, brainrot in ipairs(filtered) do
		local card = buildCard(brainrot, i)
		cardFrames[brainrot.id] = card

		card.MouseButton1Click:Connect(function()
			showDetail(brainrot)
		end)

		-- Hover effect
		card.MouseEnter:Connect(function()
			TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
				BackgroundColor3 = (playerCollection[brainrot.id] or 0) > 0
					and Color3.fromRGB(
						math.min(255, CARD_BG[brainrot.rarity].R * 255 + 20),
						math.min(255, CARD_BG[brainrot.rarity].G * 255 + 20),
						math.min(255, CARD_BG[brainrot.rarity].B * 255 + 20)
					)
					or Color3.fromRGB(35, 25, 50),
			}):Play()
		end)
		card.MouseLeave:Connect(function()
			TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
				BackgroundColor3 = (playerCollection[brainrot.id] or 0) > 0
					and CARD_BG[brainrot.rarity]
					or Color3.fromRGB(20, 15, 30),
			}):Play()
		end)
	end

	updateStats()
	updateFilterVisuals()
end

-- ============================================================
-- DETAIL PANEL
-- ============================================================

function showDetail(brainrot)
	local owned = (playerCollection[brainrot.id] or 0) > 0
	local count = playerCollection[brainrot.id] or 0
	local revealName = brainrot.rarity ~= "Legendary" or owned

	DetailName.Text   = (owned or revealName) and brainrot.name or "???"
	DetailName.TextColor3 = owned and (RARITY_COLORS[brainrot.rarity] or TEXT_PRIMARY) or TEXT_DIM

	DetailRarity.Text      = brainrot.rarity
	DetailRarity.TextColor3 = RARITY_COLORS[brainrot.rarity] or TEXT_DIM

	DetailDesc.Text   = owned and (brainrot.description or "A mysterious brainrot creature.") or "???"
	DetailIncome.Text = owned and ("+" .. (brainrot.incomePerSecond or 0) .. "$/s") or "+???$/s"

	if brainrot.directCost then
		DetailCost.Text = "Buy: $" .. brainrot.directCost
	else
		DetailCost.Text = "Gacha Only"
	end

	DetailOwned.Text  = owned and ("You own: " .. count) or "Not owned yet"
	DetailOwned.TextColor3 = owned and Color3.fromRGB(100, 220, 100) or Color3.fromRGB(200, 100, 100)

	if owned then
		DetailHowGet.Text = ""
	elseif brainrot.directCost then
		DetailHowGet.Text = "How to get: Direct Shop"
	else
		DetailHowGet.Text = "How to get: Gacha Only"
	end

	if not detailOpen then
		detailOpen = true
		-- Resize main grid to make room
		TweenService:Create(GridPanel, TWEEN_SLIDE, {
			Size = UDim2.new(1, -420, 1, -70),
		}):Play()
		TweenService:Create(StatsBar, TWEEN_SLIDE, {
			Size = UDim2.new(1, -420, 0, 54),
		}):Play()
		TweenService:Create(DetailPanel, TWEEN_SLIDE, {
			Position = UDim2.new(1, -248, 0, 8),
		}):Play()
	end
end

function hideDetail()
	if not detailOpen then return end
	detailOpen = false
	TweenService:Create(GridPanel, TWEEN_SLIDE, {
		Size = UDim2.new(1, -170, 1, -70),
	}):Play()
	TweenService:Create(StatsBar, TWEEN_SLIDE, {
		Size = UDim2.new(1, -170, 0, 54),
	}):Play()
	TweenService:Create(DetailPanel, TWEEN_SLIDE, {
		Position = UDim2.new(1, 10, 0, 8),
	}):Play()
end

DetailClose.MouseButton1Click:Connect(hideDetail)

-- ============================================================
-- OPEN / CLOSE
-- ============================================================

function openPokedex()
	if pokedexOpen then return end
	pokedexOpen = true
	MainPanel.Visible = true
	Backdrop.Visible  = true

	rebuildGrid()

	TweenService:Create(MainPanel, TWEEN_OPEN, {
		Position = UDim2.new(0.5, -350, 0.5, -275),
	}):Play()
end

function closePokedex()
	if not pokedexOpen then return end
	pokedexOpen = false
	hideDetail()

	TweenService:Create(MainPanel, TWEEN_CLOSE, {
		Position = UDim2.new(0.5, -350, 1.5, 0),
	}):Play()

	task.delay(TWEEN_CLOSE.Time, function()
		MainPanel.Visible = false
		Backdrop.Visible  = false
	end)
end

CloseBtn.MouseButton1Click:Connect(closePokedex)
Backdrop.MouseButton1Click:Connect(closePokedex)

-- ============================================================
-- FILTER / SORT BUTTON CONNECTIONS
-- ============================================================

for rarity, btn in pairs(rarityFilterBtns) do
	btn.MouseButton1Click:Connect(function()
		currentFilter = rarity
		hideDetail()
		rebuildGrid()
	end)
end

for mode, btn in pairs(showModeBtns) do
	btn.MouseButton1Click:Connect(function()
		showMode = mode
		hideDetail()
		rebuildGrid()
	end)
end

for sort, btn in pairs(sortBtns) do
	btn.MouseButton1Click:Connect(function()
		sortMode = sort
		hideDetail()
		rebuildGrid()
	end)
end

-- ============================================================
-- REMOTE EVENTS
-- ============================================================

OpenPokedexEvent.OnClientEvent:Connect(function()
	if pokedexOpen then
		closePokedex()
	else
		openPokedex()
	end
end)

CollectionUpdatedEvent.OnClientEvent:Connect(function(newCollection)
	-- newCollection: { [brainrotId] = count }
	playerCollection = {}
	for id, count in pairs(newCollection) do
		playerCollection[id] = count
	end

	if pokedexOpen then
		hideDetail()
		rebuildGrid()
	end
end)

-- ============================================================
-- INITIAL STATE — ensure filter visuals are set on first open
-- ============================================================

updateFilterVisuals()
