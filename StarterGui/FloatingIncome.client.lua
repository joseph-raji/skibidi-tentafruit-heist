local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local function showFloatingIncome(part, income)
	if income <= 0 then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 80, 0, 30)
	billboard.StudsOffset = Vector3.new(
		math.random(-20, 20) / 10,
		3,
		0
	)
	billboard.AlwaysOnTop = false
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "+$" .. income
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(100, 255, 100)
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard

	local startOffset = billboard.StudsOffset
	TweenService:Create(billboard, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = startOffset + Vector3.new(0, 3, 0)
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1
	}):Play()

	task.delay(1.3, function()
		billboard:Destroy()
	end)
end

-- Effect shown above the player's head when their Money increases
local lastMoney = player:GetAttribute("Money") or 0
player:GetAttributeChangedSignal("Money"):Connect(function()
	local newMoney = player:GetAttribute("Money") or 0
	local diff = newMoney - lastMoney
	if diff > 0 then
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.new(0, 100, 0, 35)
				bb.StudsOffset = Vector3.new(0, 4, 0)
				bb.AlwaysOnTop = false
				bb.Parent = hrp

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 1, 0)
				lbl.BackgroundTransparency = 1
				lbl.Text = "+$" .. diff
				lbl.TextScaled = true
				lbl.Font = Enum.Font.GothamBold
				lbl.TextColor3 = Color3.fromRGB(255, 220, 50)
				lbl.TextStrokeTransparency = 0.5
				lbl.Parent = bb

				TweenService:Create(bb, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					StudsOffset = Vector3.new(0, 7, 0)
				}):Play()
				TweenService:Create(lbl, TweenInfo.new(1), {
					TextTransparency = 1
				}):Play()

				task.delay(1.1, function()
					bb:Destroy()
				end)
			end
		end
	end
	lastMoney = newMoney
end)

-- Floating income effect above each owned brainrot, once per second
while true do
	task.wait(1)

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj.Name:sub(1, 12) == "BrainrotChar" then
			local body = obj:FindFirstChild("Body")
			if body then
				local income = body:GetAttribute("IncomePerSecond")
				if income and income > 0 then
					showFloatingIncome(body, income)
				end
			end
		end
	end
end
