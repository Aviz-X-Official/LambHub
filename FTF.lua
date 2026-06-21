local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local playerCache = {}
local computerCache = {}
local freezerCache = {}
local exitCache = {}

local newInstance = Instance.new
local colorFromRGB = Color3.fromRGB

local BEAST_COLOR = colorFromRGB(255, 25, 25)
local SURVIVOR_COLOR = colorFromRGB(0, 255, 255)
local COMPUTER_COLOR = colorFromRGB(255, 85, 0)
local COMPUTER_HACKED_COLOR = colorFromRGB(0, 255, 0)
local EXIT_COLOR = colorFromRGB(255, 255, 0)
local FREEZER_COLOR = colorFromRGB(100, 150, 255)
local FREEZER_OCCUPIED_COLOR = colorFromRGB(255, 0, 255)

StarterGui:SetCore("SendNotification", {Title = "LambHub Loaded", Text = "By MrZeta", Duration = 4})

local function waitForAdornee(obj)
    if obj:IsA("BasePart") then return obj end
    local adornee = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    if adornee then return adornee end

    local result
    local conn = obj.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then result = desc end
    end)

    adornee = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    if adornee then conn:Disconnect(); return adornee end

    local start = tick()
    while not result and (tick() - start) < 10 do
        task.wait(0.1)
        result = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end
    conn:Disconnect()
    return result
end

local function createESP(adornee, name, color)
    local highlight = newInstance("Highlight")
    highlight.Adornee = adornee
    highlight.FillColor = color
    highlight.OutlineColor = Color3.new(0, 0, 0)
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.6
    highlight.Parent = CoreGui

    local billboard = newInstance("BillboardGui")
    billboard.Adornee = adornee
    billboard.Size = UDim2.new(0, 150, 0, 20)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = CoreGui

    local label = newInstance("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.2
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Text = name
    label.Parent = billboard

    return highlight, billboard, label
end

local function destroyPlayer(player)
    local data = playerCache[player]
    if data then
        if data.hl then data.hl:Destroy() end
        if data.bb then data.bb:Destroy() end
        local conns = data.conns
        for i = 1, #conns do conns[i]:Disconnect() end
        playerCache[player] = nil
    end
end

local function destroyComputer(obj) local d = computerCache[obj]; if d then if d.hl then d.hl:Destroy() end; if d.bb then d.bb:Destroy() end; computerCache[obj] = nil end end
local function destroyFreezer(obj) local d = freezerCache[obj]; if d then if d.hl then d.hl:Destroy() end; if d.bb then d.bb:Destroy() end; freezerCache[obj] = nil end end
local function destroyExit(obj) local d = exitCache[obj]; if d then if d.hl then d.hl:Destroy() end; if d.bb then d.bb:Destroy() end; exitCache[obj] = nil end end

local function onCharacterAdded(player, char)
    destroyPlayer(player)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hrp or not hum then return end

    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    
    local hl, bb, label = createESP(char, player.Name, SURVIVOR_COLOR)
    local conns = {
        char.AncestryChanged:Connect(function() if not char:IsDescendantOf(game) then destroyPlayer(player) end end)
    }

    playerCache[player] = {hl = hl, bb = bb, label = label, hrp = hrp, char = char, conns = conns, isBeast = false, pName = player.Name, lastStr = ""}
end

local function setupPlayer(player)
    if player == LocalPlayer then return end
    playerCache[player] = {conns = {}}
    local c = playerCache[player].conns
    c[#c + 1] = player.CharacterAdded:Connect(function(char) task.spawn(onCharacterAdded, player, char) end)
    c[#c + 1] = player.AncestryChanged:Connect(function() if not player.Parent then destroyPlayer(player) end end)
    if player.Character then task.spawn(onCharacterAdded, player, player.Character) end
end

local function setupComputer(obj)
    if computerCache[obj] then return end
    task.spawn(function()
        local adornee = waitForAdornee(obj)
        if not adornee or not obj:IsDescendantOf(game) then return end
        local hl, bb, label = createESP(obj, "Computer", COMPUTER_COLOR)
        computerCache[obj] = {hl = hl, bb = bb, label = label, adornee = adornee, screen = obj:FindFirstChild("Screen", true), isHacked = false, lastStr = ""}
    end)
end

local function setupFreezer(obj)
    if freezerCache[obj] then return end
    task.spawn(function()
        local adornee = waitForAdornee(obj)
        if not adornee or not obj:IsDescendantOf(game) then return end
        local hl, bb, label = createESP(obj, "Freezer", FREEZER_COLOR)
        local ov = nil
        local pt = obj:FindFirstChild("PodTrigger")
        if pt then ov = pt:FindFirstChild("CapturedTorso") end
        freezerCache[obj] = {hl = hl, bb = bb, label = label, adornee = adornee, ov = ov, isOccupied = false, lastStr = ""}
    end)
end

local function setupExit(obj)
    if exitCache[obj] then return end
    task.spawn(function()
        local adornee = waitForAdornee(obj)
        if not adornee or not obj:IsDescendantOf(game) then return end
        local hl, bb, label = createESP(obj, "Exit", EXIT_COLOR)
        exitCache[obj] = {hl = hl, bb = bb, label = label, adornee = adornee, lastStr = ""}
    end)
end

local function scanWorkspace()
    for _, obj in next, Workspace:GetDescendants() do
        if obj.ClassName == "Model" then
            local n = obj.Name
            if n == "ComputerTable" then setupComputer(obj)
            elseif n == "FreezePod" then setupFreezer(obj)
            elseif n == "ExitDoor" then setupExit(obj) end
        end
    end
end

for _, p in next, Players:GetPlayers() do setupPlayer(p) end
scanWorkspace()

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(destroyPlayer)

Workspace.DescendantAdded:Connect(function(desc)
    if desc.ClassName == "Model" then
        local n = desc.Name
        if n == "ComputerTable" then setupComputer(desc)
        elseif n == "FreezePod" then setupFreezer(desc)
        elseif n == "ExitDoor" then setupExit(desc) end
    end
end)

Workspace.DescendantRemoving:Connect(function(desc)
    if computerCache[desc] then destroyComputer(desc)
    elseif freezerCache[desc] then destroyFreezer(desc)
    elseif exitCache[desc] then destroyExit(desc) end
end)

local frameCount = 0
RunService.Heartbeat:Connect(function()
    frameCount += 1
    local updateText = frameCount % 5 == 0
    
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    local localPos = localRoot.Position

    for player, data in next, playerCache do
        if not player.Parent then
            destroyPlayer(player)
        else
            local hrp = data.hrp
            local char = data.char
            if hrp and hrp.Parent and char and char.Parent then
                if not data.hl.Enabled then data.hl.Enabled = true; data.bb.Enabled = true end
                if updateText then
                    local hasHammer = char:FindFirstChild("Hammer") ~= nil
                    if data.isBeast ~= hasHammer then
                        data.isBeast = hasHammer
                        local c = hasHammer and BEAST_COLOR or SURVIVOR_COLOR
                        data.hl.FillColor = c
                        data.label.TextColor3 = c
                    end
                    local dist = (localPos - hrp.Position).Magnitude // 1
                    local newStr = data.pName .. (hasHammer and " [BEAST] " or " [SURVIVOR] ") .. dist .. "m"
                    if data.lastStr ~= newStr then
                        data.label.Text = newStr
                        data.lastStr = newStr
                    end
                end
            else
                if data.hl.Enabled then data.hl.Enabled = false; data.bb.Enabled = false end
            end
        end
    end

    for obj, data in next, computerCache do
        if not obj.Parent then
            destroyComputer(obj)
        else
            local adornee = data.adornee
            if adornee and adornee.Parent then
                if updateText then
                    local hacked = false
                    local screen = data.screen
                    if screen and screen.Parent then
                        local c = screen.Color
                        if c.R <= 0.16 and c.G >= 0.49 and c.B <= 0.28 then hacked = true end
                    end
                    if data.isHacked ~= hacked then
                        data.isHacked = hacked
                        local clr = hacked and COMPUTER_HACKED_COLOR or COMPUTER_COLOR
                        data.hl.FillColor = clr
                        data.label.TextColor3 = clr
                    end
                    local dist = (localPos - adornee.Position).Magnitude // 1
                    local newStr = (hacked and "Computer [HACKED] " or "Computer ") .. dist .. "m"
                    if data.lastStr ~= newStr then
                        data.label.Text = newStr
                        data.lastStr = newStr
                    end
                end
            else
                if data.hl.Enabled then data.hl.Enabled = false; data.bb.Enabled = false end
            end
        end
    end

    for obj, data in next, freezerCache do
        if not obj.Parent then
            destroyFreezer(obj)
        else
            local adornee = data.adornee
            if adornee and adornee.Parent then
                if updateText then
                    local occupied = false
                    local ov = data.ov
                    if ov and ov.Value ~= nil then occupied = true end
                    if data.isOccupied ~= occupied then
                        data.isOccupied = occupied
                        local clr = occupied and FREEZER_OCCUPIED_COLOR or FREEZER_COLOR
                        data.hl.FillColor = clr
                        data.label.TextColor3 = clr
                    end
                    local dist = (localPos - adornee.Position).Magnitude // 1
                    local newStr = (occupied and "Freezer [CAPTURED] " or "Freezer ") .. dist .. "m"
                    if data.lastStr ~= newStr then
                        data.label.Text = newStr
                        data.lastStr = newStr
                    end
                end
            else
                if data.hl.Enabled then data.hl.Enabled = false; data.bb.Enabled = false end
            end
        end
    end

    for obj, data in next, exitCache do
        if not obj.Parent then
            destroyExit(obj)
        else
            local adornee = data.adornee
            if adornee and adornee.Parent then
                if updateText then
                    local dist = (localPos - adornee.Position).Magnitude // 1
                    local newStr = "Exit [" .. dist .. "m]"
                    if data.lastStr ~= newStr then
                        data.label.Text = newStr
                        data.lastStr = newStr
                    end
                end
            else
                if data.hl.Enabled then data.hl.Enabled = false; data.bb.Enabled = false end
            end
        end
    end
end)
