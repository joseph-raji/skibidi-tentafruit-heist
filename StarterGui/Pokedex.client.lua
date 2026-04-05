-- Pokedex.client.lua
-- StarterGui LocalScript for Skibidi Tentafruit Heist
-- Pokédex / collection browser UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BrainrotData = require(Modules:WaitForChild("BrainrotData"))

local RE = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenPokedexEvent = RE:WaitForChild("OpenPokedex")
local CollectionUpdatedEvent = RE:WaitForChild("CollectionUpdated")

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

local CARD_BG_OWNED = {
	Common    = Color3.fromRGB(45,  45,  50),
	Uncommon  = Color3.fromRGB(25,  55,  25),
	Rare      = Color3.fromRGB(18,  30,  70),
	Epic      = Color3.fromRGB(45,  12,  70),
	Legendary = Color3.fromRGB(65,  48,   8),
}

local CARD_BG_UNOWNED  = Color3.fromRGB(22, 18, 32)
local PANEL_BG         = Color3.fromRGB(20, 20, 30)
local TEXT_PRIMARY     = Color3.fromRGB(230, 230, 255)
local TEXT_DIM         = Color3.fromRGB(120, 120, 160)

local TWEEN_OPEN  = TweenInfo.new(0.3, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local TWEEN_CLOSE = TweenInfo.new(0.2, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)

-- ============================================================
-- STATE
-- ============================================================

local playerCollection = {}  -- { [brainrotId] = count }
local currentFilter    = "ALL"
local pokedexOpen      = false

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

local function rarityIndex(rarity)
	for i, r in ipairs(RARITY_ORDER) do
		if r == rarity then return i end
	end
	return 0
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
	for _, b in ipairs(BrainrotData.list) do
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
	for _, b in ipairs(BrainrotData.list) do
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
Backdrop.BackgroundTransparency = 0.45
Backdrop.Text                = ""
Backdrop.ZIndex              = 5
Backdrop.Visible             = false
Backdrop.Parent              = ScreenGui

-- Main Panel: 680x520, centered
local pokedexPanel = Instance.new("Frame")
pokedexPanel.Name              = "PokedexPanel"
pokedexPanel.Size              = UDim2.new(0, 680, 0, 520)
pokedexPanel.Position          = UDim2.new(0.5, -340, 1.5, 0)  -- off-screen initially
pokedexPanel.BackgroundColor3  = PANEL_BG
pokedexPanel.ZIndex            = 6
pokedexPanel.Visible           = false
pokedexPanel.Parent            = ScreenGui
makeCorner(pokedexPanel, 14)
makeStroke(pokedexPanel, Color3.fromRGB(70, 50, 120), 2)

-- ---- HEADER (title + progress + close) ----
local Header = Instance.new("Frame")
Header.Name              = "Header"
Header.Size              = UDim2.new(1, 0, 0, 56)
Header.BackgroundColor3  = Color3.fromRGB(15, 10, 28)
Header.ZIndex            = 7
Header.Parent            = pokedexPanel
makeCorner(Header, 14)

-- Fill bottom half of header to square off the bottom corners
local HeaderBottomFill = Instance.new("Frame")
HeaderBottomFill.Size             = UDim2.new(1, 0, 0.5, 0)
HeaderBottomFill.Position         = UDim2.new(0, 0, 0.5, 0)
HeaderBottomFill.BackgroundColor3 = Color3.fromRGB(15, 10, 28)
HeaderBottomFill.BorderSizePixel  = 0
HeaderBottomFill.ZIndex           = 7
HeaderBottomFill.Parent           = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text              = "BRAINROT POKÉDEX"
TitleLabel.TextSize          = 20
TitleLabel.Font              = Enum.Font.GothamBlack
TitleLabel.TextColor3        = Color3.fromRGB(200, 160, 255)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Size              = UDim2.new(0, 400, 0, 30)
TitleLabel.Position          = UDim2.new(0, 14, 0, 7)
TitleLabel.TextXAlignment    = Enum.TextXAlignment.Left
TitleLabel.ZIndex            = 8
TitleLabel.Parent            = Header

local ProgressLabel = Instance.new("TextLabel")
ProgressLabel.Name           = "ProgressLabel"
ProgressLabel.Text           = "0 / 25 collected"
ProgressLabel.TextSize       = 13
ProgressLabel.Font           = Enum.Font.GothamBold
ProgressLabel.TextColor3     = TEXT_DIM
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Size           = UDim2.new(0, 200, 0, 20)
ProgressLabel.Position       = UDim2.new(0, 14, 0, 32)
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Left
ProgressLabel.ZIndex         = 8
ProgressLabel.Parent         = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text               = "✕"
CloseBtn.TextSize           = 16
CloseBtn.Font               = Enum.Font.GothamBold
CloseBtn.TextColor3         = Color3.fromRGB(200, 150, 255)
CloseBtn.BackgroundColor3   = Color3.fromRGB(40, 20, 60)
CloseBtn.Size               = UDim2.new(0, 34, 0, 34)
CloseBtn.Position           = UDim2.new(1, -46, 0, 11)
CloseBtn.ZIndex             = 9
CloseBtn.AutoButtonColor    = false
CloseBtn.Parent             = Header
makeCorner(CloseBtn, 8)

-- ---- FILTER ROW ----
local FilterRow = Instance.new("Frame")
FilterRow.Name             = "FilterRow"
FilterRow.Size             = UDim2.new(1, -16, 0, 34)
FilterRow.Position         = UDim2.new(0, 8, 0, 62)
FilterRow.BackgroundTransparency = 1
FilterRow.ZIndex           = 7
FilterRow.Parent           = pokedexPanel

local FilterLayout = Instance.new("UIListLayout")
FilterLayout.FillDirection        = Enum.FillDirection.Horizontal
FilterLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Left
FilterLayout.VerticalAlignment    = Enum.VerticalAlignment.Center
FilterLayout.Padding              = UDim.new(0, 6)
FilterLayout.Parent               = FilterRow

local filterOptions = { "ALL", "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local filterBtns = {}

for _, opt in ipairs(filterOptions) do
	local color = RARITY_COLORS[opt] or Color3.fromRGB(180, 180, 220)
	local btn = Instance.new("TextButton")
	btn.Text             = opt
	btn.TextSize         = 12
	btn.Font             = Enum.Font.GothamBold
	btn.TextColor3       = opt == "ALL" and TEXT_PRIMARY or color
	btn.BackgroundColor3 = Color3.fromRGB(30, 22, 52)
	btn.Size             = UDim2.new(0, 90, 0, 28)
	btn.AutoButtonColor  = false
	btn.ZIndex           = 8
	btn.Parent           = FilterRow
	makeCorner(btn, 7)
	filterBtns[opt] = btn
end

-- ---- GRID SCROLL ----
local GridScroll = Instance.new("ScrollingFrame")
GridScroll.Name                  = "GridScroll"
GridScroll.Size                  = UDim2.new(1, -16, 0, 358)
GridScroll.Position              = UDim2.new(0, 8, 0, 102)
GridScroll.BackgroundTransparency = 1
GridScroll.ScrollBarThickness    = 5
GridScroll.ScrollBarImageColor3  = Color3.fromRGB(100, 70, 180)
GridScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
GridScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
GridScroll.ZIndex                = 7
GridScroll.Parent                = pokedexPanel

local GridLayout = Instance.new("UIGridLayout")
GridLayout.CellSize     = UDim2.new(0, 100, 0, 120)
GridLayout.CellPadding  = UDim2.new(0, 8, 0, 8)
GridLayout.SortOrder    = Enum.SortOrder.LayoutOrder
GridLayout.Parent       = GridScroll

local GridPadding = Instance.new("UIPadding")
GridPadding.PaddingTop    = UDim.new(0, 6)
GridPadding.PaddingRight  = UDim.new(0, 6)
GridPadding.PaddingBottom = UDim.new(0, 6)
GridPadding.PaddingLeft   = UDim.new(0, 6)
GridPadding.Parent        = GridScroll

-- ---- STATS BAR ----
local StatsBar = Instance.new("Frame")
StatsBar.Name             = "StatsBar"
StatsBar.Size             = UDim2.new(1, -16, 0, 36)
StatsBar.Position         = UDim2.new(0, 8, 1, -44)
StatsBar.BackgroundColor3 = Color3.fromRGB(14, 8, 28)
StatsBar.ZIndex           = 7
StatsBar.Parent           = pokedexPanel
makeCorner(StatsBar, 8)
makeStroke(StatsBar, Color3.fromRGB(55, 35, 100), 1.5)

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Name              = "StatsLabel"
StatsLabel.Text              = "Collected: 0/25  |  Total income: 0$/s  |  Best: None"
StatsLabel.TextSize          = 13
StatsLabel.Font              = Enum.Font.GothamBold
StatsLabel.TextColor3        = TEXT_PRIMARY
StatsLabel.BackgroundTransparency = 1
StatsLabel.Size              = UDim2.new(1, -16, 1, 0)
StatsLabel.Position          = UDim2.new(0, 8, 0, 0)
StatsLabel.TextXAlignment    = Enum.TextXAlignment.Left
StatsLabel.ZIndex            = 8
StatsLabel.Parent            = StatsBar

-- ============================================================
-- UPDATE STATS
-- ============================================================

local function updateStats()
	local unique = getUniqueOwned()
	local income = getTotalIncome()
	local rarest = getRarestOwned()
	local bestName = rarest and rarest.name or "None"

	ProgressLabel.Text = unique .. " / " .. TOTAL_BRAINROTS .. " collected"
	StatsLabel.Text = "Collected: " .. unique .. "/" .. TOTAL_BRAINROTS
		.. "  |  Total income: " .. string.format("%.1f", income) .. "$/s"
		.. "  |  Best: " .. bestName
end

-- ============================================================
-- UPDATE FILTER BUTTON VISUALS
-- ============================================================

local function updateFilterVisuals()
	for opt, btn in pairs(filterBtns) do
		local active = (currentFilter == opt)
		if active then
			btn.BackgroundColor3 = Color3.fromRGB(60, 35, 110)
			local s = btn:FindFirstChildWhichIsA("UIStroke")
			if s then
				s.Thickness = 2
			else
				makeStroke(btn, RARITY_COLORS[opt] or Color3.fromRGB(150, 120, 220), 2)
			end
		else
			btn.BackgroundColor3 = Color3.fromRGB(30, 22, 52)
			local s = btn:FindFirstChildWhichIsA("UIStroke")
			if s then s.Thickness = 0 end
		end
	end
end

-- ============================================================
-- CARD BUILDER
-- ============================================================

local function buildCard(brainrot, layoutOrder)
	local count = playerCollection[brainrot.id] or 0
	local owned = count > 0
	local isLegendary = brainrot.rarity == "Legendary"

	local card = Instance.new("TextButton")
	card.Name             = "Card_" .. brainrot.id
	card.Text             = ""
	card.LayoutOrder      = layoutOrder
	card.BackgroundColor3 = owned and CARD_BG_OWNED[brainrot.rarity] or CARD_BG_UNOWNED
	card.AutoButtonColor  = false
	card.ClipsDescendants = true
	card.ZIndex           = 10
	card.Parent           = GridScroll
	makeCorner(card, 10)
	makeStroke(card,
		owned and (RARITY_COLORS[brainrot.rarity] or Color3.fromRGB(80, 80, 120)) or Color3.fromRGB(45, 35, 65),
		owned and 2 or 1
	)

	if owned then
		-- Icon / emoji
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Text              = brainrot.icon or ""
		iconLabel.TextSize          = 32
		iconLabel.Font              = Enum.Font.GothamBold
		iconLabel.TextColor3        = Color3.fromRGB(255, 255, 255)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Size              = UDim2.new(1, 0, 0, 44)
		iconLabel.Position          = UDim2.new(0, 0, 0, 8)
		iconLabel.TextXAlignment    = Enum.TextXAlignment.Center
		iconLabel.ZIndex            = 11
		iconLabel.Parent            = card

		-- Name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Text              = brainrot.name
		nameLabel.TextSize          = 10
		nameLabel.Font              = Enum.Font.GothamBold
		nameLabel.TextColor3        = TEXT_PRIMARY
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size              = UDim2.new(1, -4, 0, 22)
		nameLabel.Position          = UDim2.new(0, 2, 0, 54)
		nameLabel.TextXAlignment    = Enum.TextXAlignment.Center
		nameLabel.TextWrapped       = true
		nameLabel.ZIndex            = 11
		nameLabel.Parent            = card

		-- Income
		local incLabel = Instance.new("TextLabel")
		incLabel.Text               = "+" .. (brainrot.incomePerSecond or 0) .. "$/s"
		incLabel.TextSize           = 10
		incLabel.Font               = Enum.Font.Gotham
		incLabel.TextColor3         = Color3.fromRGB(100, 220, 100)
		incLabel.BackgroundTransparency = 1
		incLabel.Size               = UDim2.new(1, -4, 0, 16)
		incLabel.Position           = UDim2.new(0, 2, 0, 76)
		incLabel.TextXAlignment     = Enum.TextXAlignment.Center
		incLabel.ZIndex             = 11
		incLabel.Parent             = card

		-- Rarity badge
		local rarityColor = RARITY_COLORS[brainrot.rarity] or TEXT_DIM
		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Text            = brainrot.rarity
		rarityLabel.TextSize        = 9
		rarityLabel.Font            = Enum.Font.GothamBold
		rarityLabel.TextColor3      = rarityColor
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Size            = UDim2.new(1, -4, 0, 14)
		rarityLabel.Position        = UDim2.new(0, 2, 0, 93)
		rarityLabel.TextXAlignment  = Enum.TextXAlignment.Center
		rarityLabel.ZIndex          = 11
		rarityLabel.Parent          = card

		-- Count badge (if more than 1)
		if count > 1 then
			local badge = Instance.new("Frame")
			badge.Size              = UDim2.new(0, 26, 0, 18)
			badge.Position          = UDim2.new(1, -29, 0, 4)
			badge.BackgroundColor3  = Color3.fromRGB(200, 55, 55)
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
	else
		-- Not owned: show "???" and rarity
		local qmark = Instance.new("TextLabel")
		qmark.Text              = "???"
		qmark.TextSize          = 24
		qmark.Font              = Enum.Font.GothamBlack
		qmark.TextColor3        = Color3.fromRGB(65, 55, 85)
		qmark.BackgroundTransparency = 1
		qmark.Size              = UDim2.new(1, 0, 0, 50)
		qmark.Position          = UDim2.new(0, 0, 0, 20)
		qmark.TextXAlignment    = Enum.TextXAlignment.Center
		qmark.ZIndex            = 11
		qmark.Parent            = card

		-- Name: hide for legendary, show for others
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Text          = isLegendary and "???" or brainrot.name
		nameLabel.TextSize      = 10
		nameLabel.Font          = Enum.Font.GothamBold
		nameLabel.TextColor3    = TEXT_DIM
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size          = UDim2.new(1, -4, 0, 22)
		nameLabel.Position      = UDim2.new(0, 2, 0, 72)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.TextWrapped   = true
		nameLabel.ZIndex        = 11
		nameLabel.Parent        = card

		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Text        = "? Rarity"
		rarityLabel.TextSize    = 9
		rarityLabel.Font        = Enum.Font.Gotham
		rarityLabel.TextColor3  = Color3.fromRGB(70, 60, 90)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Size        = UDim2.new(1, -4, 0, 14)
		rarityLabel.Position    = UDim2.new(0, 2, 0, 95)
		rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
		rarityLabel.ZIndex      = 11
		rarityLabel.Parent      = card
	end

	return card
end

-- ============================================================
-- REFRESH GRID
-- ============================================================

local function refreshGrid()
	-- Remove old cards
	for _, child in ipairs(GridScroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- Filter by rarity
	local filtered = {}
	for _, b in ipairs(BrainrotData.list) do
		local passRarity = (currentFilter == "ALL") or (b.rarity == currentFilter)
		if passRarity then
			table.insert(filtered, b)
		end
	end

	-- Sort by rarity (legendary first) then name
	table.sort(filtered, function(a, b_)
		local diff = rarityIndex(b_.rarity) - rarityIndex(a.rarity)
		if diff ~= 0 then return diff > 0 end
		return a.name < b_.name
	end)

	for i, brainrot in ipairs(filtered) do
		local card = buildCard(brainrot, i)

		card.MouseEnter:Connect(function()
			local owned = (playerCollection[brainrot.id] or 0) > 0
			local target = owned
				and Color3.fromRGB(
					math.min(255, math.floor(CARD_BG_OWNED[brainrot.rarity].R * 255 + 18)),
					math.min(255, math.floor(CARD_BG_OWNED[brainrot.rarity].G * 255 + 18)),
					math.min(255, math.floor(CARD_BG_OWNED[brainrot.rarity].B * 255 + 18))
				)
				or Color3.fromRGB(35, 28, 48)
			TweenService:Create(card, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { BackgroundColor3 = target }):Play()
		end)

		card.MouseLeave:Connect(function()
			local owned = (playerCollection[brainrot.id] or 0) > 0
			TweenService:Create(card, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
				BackgroundColor3 = owned and CARD_BG_OWNED[brainrot.rarity] or CARD_BG_UNOWNED,
			}):Play()
		end)
	end

	updateStats()
	updateFilterVisuals()
end

-- ============================================================
-- OPEN / CLOSE
-- ============================================================

local function closePokedex()
	if not pokedexOpen then return end
	pokedexOpen = false

	TweenService:Create(pokedexPanel, TWEEN_CLOSE, {
		Position = UDim2.new(0.5, -340, 1.5, 0),
	}):Play()

	task.delay(TWEEN_CLOSE.Time, function()
		pokedexPanel.Visible = false
		Backdrop.Visible     = false
	end)
end

local function openPokedex()
	if pokedexOpen then return end
	pokedexOpen = true
	pokedexPanel.Visible = true
	Backdrop.Visible     = true

	refreshGrid()

	TweenService:Create(pokedexPanel, TWEEN_OPEN, {
		Position = UDim2.new(0.5, -340, 0.5, -260),
	}):Play()
end

-- ============================================================
-- BUTTON CONNECTIONS
-- ============================================================

CloseBtn.MouseButton1Click:Connect(closePokedex)
Backdrop.MouseButton1Click:Connect(closePokedex)

for opt, btn in pairs(filterBtns) do
	btn.MouseButton1Click:Connect(function()
		currentFilter = opt
		refreshGrid()
	end)
end

-- ============================================================
-- REMOTE EVENTS
-- ============================================================

OpenPokedexEvent.OnClientEvent:Connect(function()
	pokedexPanel.Visible = true
	openPokedex()
end)

CollectionUpdatedEvent.OnClientEvent:Connect(function(collectionData)
	playerCollection = collectionData or {}
	if pokedexOpen then
		refreshGrid()
	end
end)

-- ============================================================
-- INITIAL STATE
-- ============================================================

updateFilterVisuals()
