task.wait(0.67)
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

WindUI:SetNotificationLower(true)

local ESPService = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local colors = {
    red = Color3.fromRGB(255,0,0),
    green = Color3.fromRGB(0,255,0),
    blue = Color3.fromRGB(0,0,255),
    yellow = Color3.fromRGB(255,255,0),
    white = Color3.fromRGB(255,255,255),
    darkBlue = Color3.fromRGB(0, 0, 96),
    orange = Color3.fromRGB(255, 153, 28),
    blue1 = Color3.fromRGB(73, 195, 214)
}

local ESPBoxesEnabled = true
local ESPDisplayMode = "Tudo"

local espColors = {
    Monster = Color3.fromRGB(252, 83, 83),
    Generator = Color3.fromRGB(0, 252, 83),
}

local SPECIAL_ITEMS_URL = "https://raw.githubusercontent.com/JuninSB/CGH_HUB/refs/heads/main/assets/special_items.lua"
local special_items = {
    ["AirHorn"] = {color = colors.yellow, notify = false},
    ["Bandage"] = {color = colors.yellow, notify = true},
    ["HealthKit"] = {color = colors.red, notify = true},
    ["Tape"] = {color = colors.darkBlue, notify = false},
    ["ResearchCapsule"] = {color = colors.darkBlue, notify = false},
    ["Pumpkin"] = {color = colors.orange, notify = false},
    ["PopBottle"] = {color = colors.blue1, notify = false},
}

local function loadSpecialItemsFromCloud()
    local ok, remoteItems, remoteColors = pcall(function()
        local source = game:HttpGet(SPECIAL_ITEMS_URL)
        local chunk, compileError = loadstring(source)
        assert(type(chunk) == "function", tostring(compileError))
        return chunk()
    end)
    if not ok or type(remoteItems) ~= "table" then
        warn("[CGH] Nao foi possivel carregar special_items.lua; usando lista local: " .. tostring(remoteItems))
        return
    end

    local validated = {}
    for itemName, properties in pairs(remoteItems) do
        if type(itemName) == "string" and type(properties) == "table" and typeof(properties[1]) == "Color3" then
            validated[itemName] = {color = properties[1], notify = properties[2] == true}
        else
            warn("[CGH] Entrada invalida em special_items.lua: " .. tostring(itemName))
        end
    end
    if next(validated) == nil then
        warn("[CGH] special_items.lua nao tinha entradas validas; usando lista local")
        return
    end

    if type(remoteColors) == "table" then
        for colorName, colorValue in pairs(remoteColors) do
            if type(colorName) == "string" and typeof(colorValue) == "Color3" then
                colors[colorName] = colorValue
            end
        end
    end
    table.clear(special_items)
    for itemName, properties in pairs(validated) do
        special_items[itemName] = properties
    end
    local itemCount = 0
    for _ in pairs(special_items) do itemCount = itemCount + 1 end
    print("[CGH] Itens especiais carregados da nuvem: " .. tostring(itemCount))
end

loadSpecialItemsFromCloud()

local function getSpecialItemNames()
    local names = {}
    for itemName in pairs(special_items) do table.insert(names, itemName) end
    table.sort(names)
    return names
end
local player = Players.LocalPlayer
local objects = {}
local connection
local running = false

local defaults = {
    Text = true,
    Box = true,
    BoxType = "Square",
    Tracer = false,
    HeadCircle = false,
    HealthBar = false,
    Distance = false,
    HealthText = false,
    Filled = false,
    Name = nil,
    Color = Color3.fromRGB(255, 255, 255),
    TextColor = Color3.fromRGB(255, 255, 255),
    BoxColor = Color3.fromRGB(255, 255, 255),
    TracerColor = Color3.fromRGB(255, 255, 255),
    HeadCircleColor = Color3.fromRGB(255, 255, 255),
    HealthColor = Color3.fromRGB(0, 255, 0),
    OutlineColor = Color3.fromRGB(0, 0, 0),
    Size = 14,
    BoxThickness = 1,
    TracerThickness = 1,
    CircleThickness = 1,
    CircleRadius = 6,
    Font = 0,
    Transparency = 1,
    FilledTransparency = 0.5,
    Outline = true,
    Center = true,
    ShowDistance = false,
    MaxDistance = math.huge,
    TracerOrigin = "Bottom",
    Offset = Vector2.zero
}

local function newDrawing(kind, props)
    local obj = Drawing.new(kind)

    for key, value in pairs(props) do
        obj[key] = value
    end

    return obj
end

local function makeDrawings()
    return {
        Text = newDrawing("Text", {
            Text = "",
            Size = 14,
            Center = true,
            Outline = true,
            Visible = false
        }),
        DistanceText = newDrawing("Text", {
            Text = "",
            Size = 13,
            Center = true,
            Outline = true,
            Visible = false
        }),
        HealthText = newDrawing("Text", {
            Text = "",
            Size = 13,
            Center = true,
            Outline = true,
            Visible = false
        }),
        Box = newDrawing("Square", {
            Filled = false,
            Thickness = 1,
            Visible = false
        }),
        Quad = newDrawing("Quad", {
            Filled = false,
            Thickness = 1,
            Visible = false
        }),
        Tracer = newDrawing("Line", {
            Thickness = 1,
            Visible = false
        }),
        HeadCircle = newDrawing("Circle", {
            Filled = false,
            Thickness = 1,
            NumSides = 24,
            Visible = false
        }),
        HealthBack = newDrawing("Square", {
            Filled = true,
            Thickness = 1,
            Visible = false
        }),
        Health = newDrawing("Square", {
            Filled = true,
            Thickness = 1,
            Visible = false
        }),
        Triangle = newDrawing("Triangle", {
            Filled = false,
            Thickness = 1,
            Visible = false
        })
    }
end

local function hideDrawings(esp)
    for _, drawing in pairs(esp.Drawings) do
        drawing.Visible = false
    end
end

local function getTargetPosition(target)
    if not target or not target.Parent then
        return nil
    end

    if target:IsA("BasePart") then
        return target.Position
    end

    if target:IsA("Model") then
        return target:GetPivot().Position
    end

    return nil
end

local function getBounds(target, camera)
    local cf
    local size

    if target:IsA("BasePart") then
        cf = target.CFrame
        size = target.Size
    elseif target:IsA("Model") then
        cf, size = target:GetBoundingBox()
    else
        return nil
    end

    local hx = size.X / 2
    local hy = size.Y / 2
    local hz = size.Z / 2

    local corners = {
        Vector3.new(-hx, -hy, -hz),
        Vector3.new(-hx, -hy, hz),
        Vector3.new(-hx, hy, -hz),
        Vector3.new(-hx, hy, hz),
        Vector3.new(hx, -hy, -hz),
        Vector3.new(hx, -hy, hz),
        Vector3.new(hx, hy, -hz),
        Vector3.new(hx, hy, hz)
    }

    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge

    for _, corner in ipairs(corners) do
        local screen = camera:WorldToViewportPoint(cf:PointToWorldSpace(corner))

        minX = math.min(minX, screen.X)
        minY = math.min(minY, screen.Y)
        maxX = math.max(maxX, screen.X)
        maxY = math.max(maxY, screen.Y)
    end

    return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
end

local function getHumanoid(target)
    if target:IsA("Model") then
        return target:FindFirstChildWhichIsA("Humanoid")
    end

    return nil
end

local function getHead(target)
    if target:IsA("Model") then
        return target:FindFirstChild("Head")
    end

    return nil
end

local function getDistance(target)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local position = getTargetPosition(target)

    if not root or not position then
        return nil
    end

    return (root.Position - position).Magnitude
end

local function applyConfig(esp, config)
    for key, value in pairs(config) do
        esp.Config[key] = value

        if key == "Name" then
            esp.Name = value
        end
    end
end

local function updateESP(esp, camera)
    local target = esp.Part
    local config = esp.Config
    local drawings = esp.Drawings

    if not target or not target.Parent then
        esp:Remove()
        return
    end

    local position = getTargetPosition(target)

    if not position then
        hideDrawings(esp)
        return
    end

    local distance = getDistance(target)

    if distance and distance > config.MaxDistance then
        hideDrawings(esp)
        return
    end

    local center = camera:WorldToViewportPoint(position)

    if center.Z <= 0 then
        hideDrawings(esp)
        return
    end

    local boxPos, boxSize = getBounds(target, camera)

    if not boxPos then
        hideDrawings(esp)
        return
    end

    boxPos += config.Offset

    local boxX = boxPos.X
    local boxY = boxPos.Y
    local boxW = boxSize.X
    local boxH = boxSize.Y

    local boxColor = config.BoxColor or config.Color

    drawings.Box.Position = boxPos
    drawings.Box.Size = boxSize
    drawings.Box.Color = boxColor
    drawings.Box.Thickness = config.BoxThickness
    drawings.Box.Filled = config.Filled
    drawings.Box.Transparency = config.Filled and config.FilledTransparency or config.Transparency
    drawings.Box.Visible = ESPBoxesEnabled and config.Box and config.BoxType == "Square"

    drawings.Quad.PointA = Vector2.new(boxX, boxY)
    drawings.Quad.PointB = Vector2.new(boxX + boxW, boxY)
    drawings.Quad.PointC = Vector2.new(boxX + boxW, boxY + boxH)
    drawings.Quad.PointD = Vector2.new(boxX, boxY + boxH)
    drawings.Quad.Color = boxColor
    drawings.Quad.Thickness = config.BoxThickness
    drawings.Quad.Filled = config.Filled
    drawings.Quad.Transparency = config.Filled and config.FilledTransparency or config.Transparency
    drawings.Quad.Visible = ESPBoxesEnabled and config.Box and config.BoxType == "Quad"

    drawings.Text.Text = config.Name or target.Name
    drawings.Text.Position = Vector2.new(boxX + boxW / 2, boxY - config.Size - 2)
    drawings.Text.Size = config.Size
    drawings.Text.Color = config.TextColor or config.Color
    drawings.Text.Outline = config.Outline
    drawings.Text.OutlineColor = config.OutlineColor
    drawings.Text.Center = config.Center
    drawings.Text.Font = config.Font
    drawings.Text.Transparency = config.Transparency
    drawings.Text.Visible = config.Text

    drawings.DistanceText.Text = distance and string.format("%.1f studs", distance) or ""
    drawings.DistanceText.Position = Vector2.new(boxX + boxW / 2, boxY + boxH + 2)
    drawings.DistanceText.Color = config.TextColor or config.Color
    drawings.DistanceText.Outline = config.Outline
    drawings.DistanceText.OutlineColor = config.OutlineColor
    drawings.DistanceText.Center = true
    drawings.DistanceText.Size = config.Size
    drawings.DistanceText.Visible = config.Distance or config.ShowDistance

    local humanoid = getHumanoid(target)
    local healthRatio = 0

    if humanoid and humanoid.MaxHealth > 0 then
        healthRatio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
    end

    drawings.HealthBack.Position = Vector2.new(boxX - 6, boxY)
    drawings.HealthBack.Size = Vector2.new(4, boxH)
    drawings.HealthBack.Color = config.OutlineColor
    drawings.HealthBack.Visible = config.HealthBar and humanoid ~= nil

    drawings.Health.Position = Vector2.new(boxX - 5, boxY + boxH * (1 - healthRatio))
    drawings.Health.Size = Vector2.new(2, boxH * healthRatio)
    drawings.Health.Color = config.HealthColor
    drawings.Health.Visible = config.HealthBar and humanoid ~= nil

    drawings.HealthText.Text = humanoid and string.format("%d HP", math.floor(humanoid.Health)) or ""
    drawings.HealthText.Position = Vector2.new(boxX + boxW / 2, boxY + boxH + ((config.Distance or config.ShowDistance) and 18 or 2))
    drawings.HealthText.Color = config.HealthColor
    drawings.HealthText.Outline = config.Outline
    drawings.HealthText.OutlineColor = config.OutlineColor
    drawings.HealthText.Center = true
    drawings.HealthText.Visible = config.HealthText and humanoid ~= nil

    local head = getHead(target)

    if head then
        local headPos, headVisible = camera:WorldToViewportPoint(head.Position)
        drawings.HeadCircle.Position = Vector2.new(headPos.X, headPos.Y)
        drawings.HeadCircle.Radius = config.CircleRadius
        drawings.HeadCircle.Color = config.HeadCircleColor
        drawings.HeadCircle.Thickness = config.CircleThickness
        drawings.HeadCircle.Transparency = config.Transparency
        drawings.HeadCircle.Visible = config.HeadCircle and headVisible and headPos.Z > 0
    else
        drawings.HeadCircle.Visible = false
    end

    local viewport = camera.ViewportSize
    local origin

    if config.TracerOrigin == "Center" then
        origin = viewport / 2
    elseif config.TracerOrigin == "Top" then
        origin = Vector2.new(viewport.X / 2, 0)
    else
        origin = Vector2.new(viewport.X / 2, viewport.Y)
    end

    drawings.Tracer.From = origin
    drawings.Tracer.To = Vector2.new(center.X, center.Y)
    drawings.Tracer.Color = config.TracerColor or config.Color
    drawings.Tracer.Thickness = config.TracerThickness
    drawings.Tracer.Transparency = config.Transparency
    drawings.Tracer.Visible = config.Tracer

    drawings.Triangle.PointA = Vector2.new(boxX + boxW / 2, boxY - 10)
    drawings.Triangle.PointB = Vector2.new(boxX + boxW / 2 - 5, boxY - 2)
    drawings.Triangle.PointC = Vector2.new(boxX + boxW / 2 + 5, boxY - 2)
    drawings.Triangle.Color = config.Color
    drawings.Triangle.Thickness = config.BoxThickness
    drawings.Triangle.Visible = config.Triangle == true
end

local function render()
    local camera = workspace.CurrentCamera

    if not camera then
        return
    end

    for esp in pairs(objects) do
        if esp.Removed then
            objects[esp] = nil
        else
            updateESP(esp, camera)
        end
    end
end

local function start()
    if running then
        return
    end

    running = true
    connection = RunService.RenderStepped:Connect(render)
end

function ESPService.Create(part, name, config)
    assert(typeof(part) == "Instance", "O alvo precisa ser uma Instance")
    assert(part:IsA("BasePart") or part:IsA("Model"), "O alvo precisa ser uma BasePart ou Model")

    local settings = table.clone(defaults)

    for key, value in pairs(config or {}) do
        settings[key] = value
    end

    local esp = {
        Part = part,
        Name = name or part.Name,
        Config = settings,
        Drawings = makeDrawings(),
        Removed = false
    }

    function esp:Update(newConfig)
        if not self.Removed then
            applyConfig(self, newConfig)
        end
    end

    function esp:SetText(text)
        self.Name = tostring(text)
        self.Config.Name = self.Name
    end

    function esp:Remove()
        if self.Removed then
            return
        end

        self.Removed = true
        objects[self] = nil

        for _, drawing in pairs(self.Drawings) do
            drawing:Remove()
        end
        if next(objects) == nil and connection then
            connection:Disconnect()
            connection = nil
            running = false
        end
    end

    objects[esp] = true
    start()

    return esp
end

function ESPService.RemoveFromPart(part)
    for esp in pairs(objects) do
        if esp.Part == part then
            esp:Remove()
        end
    end
end

function ESPService.Clear()
    local list = {}

    for esp in pairs(objects) do
        table.insert(list, esp)
    end

    for _, esp in ipairs(list) do
        esp:Remove()
    end
end

function ESPService.GetDistance(part)
    return getDistance(part)
end

function ESPService.Count()
    local count = 0

    for _ in pairs(objects) do
        count += 1
    end

    return count
end

function ESPService.Destroy()
    ESPService.Clear()

    if connection then
        connection:Disconnect()
        connection = nil
    end

    running = false
end

function getcurrentroom()
    local workspace = game:GetService("Workspace")
    local crom = workspace:FindFirstChild("CurrentRoom")

    if not crom then
        return false
    end

    while true do
        for _, obj in ipairs(crom:GetChildren()) do
            if obj:IsA("Model") then
                return obj
            end
        end

        crom.ChildAdded:Wait()
    end

    return false
end

local run = game:GetService("RunService")
local CS = game:GetService("CollectionService")
local camera = game:GetService("Workspace").CurrentCamera
local players = game:GetService("Players")
local localplayer = players.LocalPlayer
local Char = localplayer.Character or localplayer.CharacterAdded:Wait()
local light = game:GetService("Lighting")
local originalCameraMinZoomDistance = localplayer.CameraMinZoomDistance
local originalCameraMaxZoomDistance = localplayer.CameraMaxZoomDistance
local originalJumpHeights = setmetatable({}, {__mode = "k"})
local function rememberCharacterHumanoid(character)
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
    if humanoid and originalJumpHeights[humanoid] == nil then
        originalJumpHeights[humanoid] = humanoid.JumpHeight
    end
end
rememberCharacterHumanoid(Char)

local characterAddedConnection = localplayer.CharacterAdded:Connect(function(character)
    Char = character
    rememberCharacterHumanoid(character)
end)

local GenESP = false
local MonsESP = false
local ItemsESP = false

local bkbright = light.Brightness
local bkglobalshadow = light.GlobalShadows
local bkclocktime = light.ClockTime
--local bkexposurecomp = light.ExposureCompensation
local bkfogend = light.FogEnd
local bkfogstart = light.FogStart
local bkoutdooramb = light.OutdoorAmbient

local fbenabled = false

local function applyFullbright(enabled)
    if enabled then
        light.Brightness = 3
        light.GlobalShadows = false
        light.ClockTime = 12
        light.FogEnd = 1000
        light.FogStart = 800
        light.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    else
        light.Brightness = bkbright
        light.GlobalShadows = bkglobalshadow
        light.ClockTime = bkclocktime
        light.FogEnd = bkfogend
        light.FogStart = bkfogstart
        light.OutdoorAmbient = bkoutdooramb
    end
end

local noclipenabled = false

local asd = "Placeholder"
local bignumb = 4294967295
-- loops/conections/functions --

-- tpwalk cfg-runtime
local tpwalkEnabled = false
local tpwalkSpeed = 1

local tpwalkConnection

tpwalkConnection = run.Heartbeat:Connect(function(delta)
    if not tpwalkEnabled then
        return
    end

    local player = game.Players.LocalPlayer
    local character = player.Character
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")

    if not (character and humanoid and humanoid.Parent) then
        return
    end

    local direction = humanoid.MoveDirection

    if direction.Magnitude > 0 then
        character:TranslateBy(direction * tpwalkSpeed * delta * 10)
    end
end)

local noclipconnex
local noclipagressivemode = false
local noclipRoomConnection
local noclipFolderConnection
local noclipRoomFolderRemovalConnection
local noclipCompletedRooms = setmetatable({}, {__mode = "k"})
local noclipRoomStates = setmetatable({}, {__mode = "k"})
local noclipRoomReadyAt = setmetatable({}, {__mode = "k"})
local noclipRoomConnections = setmetatable({}, {__mode = "k"})
local noclipStore = game:GetService("ReplicatedStorage"):FindFirstChild("CGH_NoclipStorage")
local noclipStoreCreated = false
if not noclipStore then
    noclipStore = Instance.new("Folder")
    noclipStore.Name = "CGH_NoclipStorage"
    noclipStore.Parent = game:GetService("ReplicatedStorage")
    noclipStoreCreated = true
end

local noclipRecordId = 0
local function restoreRoomNoclip(room)
    local state = room and noclipRoomStates[room]
    if not state then return end
    local container = state.container

    -- Rebuild parent references from ObjectValues stored next to the moved items.
    if container then
        for _, item in ipairs(container:GetChildren()) do
            if item:GetAttribute("CGH_NoclipMoved") then
                local record = container:FindFirstChild("ParentRef_" .. tostring(item:GetAttribute("CGH_NoclipMoved")))
                local parentRef = record and record:FindFirstChild("OriginalParent")
                local originalParent = parentRef and parentRef.Value
                if originalParent and originalParent:IsDescendantOf(game) then
                    item.Parent = originalParent
                elseif room and room:IsDescendantOf(game) then
                    item.Parent = room
                end
                item:SetAttribute("CGH_NoclipMoved", nil)
            end
        end
        -- Restore collision state from saved values for hitboxes kept in the room.
        for _, record in ipairs(container:GetChildren()) do
            if record:IsA("Folder") and record.Name:sub(1, 7) == "PartRef_" then
                local partRef = record:FindFirstChild("Part")
                local value = record:FindFirstChild("CanCollide")
                if partRef and partRef.Value and value then
                    partRef.Value.CanCollide = value.Value
                end
            end
        end
    end

    for _, record in ipairs(state.parts) do
        if record.instance then record.instance.CanCollide = record.canCollide end
    end
    if container then container:Destroy() end
    noclipRoomStates[room] = nil
    noclipCompletedRooms[room] = nil
    if CS:HasTag(room, "CGH_NoCliped") then CS:RemoveTag(room, "CGH_NoCliped") end
end
local function restoreAllNoclip()
    local rooms = {}
    for room in pairs(noclipRoomStates) do table.insert(rooms, room) end
    for _, room in ipairs(rooms) do restoreRoomNoclip(room) end

    -- Restore containers even if an earlier toggle lost its local room state.
    for _, container in ipairs(noclipStore:GetChildren()) do
        for _, item in ipairs(container:GetChildren()) do
            local id = item:GetAttribute("CGH_NoclipMoved")
            if id then
                local record = container:FindFirstChild("ParentRef_" .. tostring(id))
                local parentRef = record and record:FindFirstChild("OriginalParent")
                local originalParent = parentRef and parentRef.Value
                if originalParent and originalParent:IsDescendantOf(game) then
                    item.Parent = originalParent
                    item:SetAttribute("CGH_NoclipMoved", nil)
                end
            end
        end
        container:Destroy()
    end
    table.clear(noclipCompletedRooms)
end
local function clearOldNoclipStorage(activeRoom)
    for room, state in pairs(noclipRoomStates) do
        if room ~= activeRoom then
            -- Map antigo n o deve ficar no ReplicatedStorage; descarte sua c pia
            -- guardada e solte as refer ncias locais.
            restoreRoomNoclip(room)
        end
    end
end

local scheduleNoclipRoomApply

local function applyNoclipToRoom(room)
    if not noclipenabled or not room or not room:IsA("Model") then return end
    local readyAt = noclipRoomReadyAt[room]
    if readyAt and os.clock() < readyAt then return end
    clearOldNoclipStorage(room)

    local state = noclipRoomStates[room] or {parts = {}, moved = {}, container = nil}
    local names = {NoClip_Collider = true, NoClip = true, CylinderCollider = true}
    local targetSet, partSet = {}, {}
    for _, target in ipairs(state.targets or {}) do targetSet[target] = true end
    for _, record in ipairs(state.parts) do if record.instance then partSet[record.instance] = true end end
    for _, v in ipairs(room:GetDescendants()) do
        local loweredName = string.lower(v.Name)
        local inElevator = v:FindFirstAncestor("Elevator") ~= nil
        local parentName = v.Parent and v.Parent.Name or ""
        local ancestor = v.Parent
        local inNamedContainer = false
        while ancestor and ancestor ~= room do
            if ancestor.Name == "Fence" or ancestor.Name == "WindowWal" or ancestor.Name == "WindowFrame" or ancestor.Name == "WallDisplay" then
                inNamedContainer = true
                break
            end
            ancestor = ancestor.Parent
        end
        inNamedContainer = inNamedContainer or string.find(string.lower(parentName), "wall", 1, true) ~= nil
        if not inElevator then
            if names[v.Name] then
                targetSet[v] = true
            end
            if v:IsA("BasePart") and v.Name ~= "Floor" and (inNamedContainer or string.find(loweredName, "wall", 1, true) ~= nil or string.find(loweredName, "backingwall", 1, true) ~= nil) then
                partSet[v] = true
            end
        end
    end
    state.targets = {}
    for target in pairs(targetSet) do table.insert(state.targets, target) end
    for part in pairs(partSet) do
        local exists = false
        for _, record in ipairs(state.parts) do
            if record.instance == part then
                exists = true
                break
            end
        end
        if not exists then table.insert(state.parts, {instance = part, canCollide = part.CanCollide}) end
        part.CanCollide = false
    end

    if noclipagressivemode and #state.targets > 0 and not state.container then
        local container = Instance.new("Folder")
        container.Name = "Room_" .. room.Name
        container.Parent = noclipStore
        state.container = container
        local moveSet = {}
        for _, target in ipairs(state.targets) do
            -- Store hitbox instances directly and retain their exact parents.
            if target ~= room then moveSet[target] = true end
        end
        for item in pairs(moveSet) do
            if item.Parent then
                noclipRecordId += 1
                local id = noclipRecordId
                local record = Instance.new("Folder")
                record.Name = "ParentRef_" .. tostring(id)
                local parentRef = Instance.new("ObjectValue")
                parentRef.Name = "OriginalParent"
                parentRef.Value = item.Parent
                parentRef.Parent = record
                record.Parent = container
                item:SetAttribute("CGH_NoclipMoved", id)
                table.insert(state.moved, {instance = item, parent = item.Parent})
                item.Parent = container
            end
        end
    else
        for _, target in ipairs(state.targets) do
            if target:IsA("BasePart") then
                local exists = false
                for _, record in ipairs(state.parts) do
                    if record.instance == target then
                        exists = true
                        break
                    end
                end
                if not exists then table.insert(state.parts, {instance = target, canCollide = target.CanCollide}) end
                target.CanCollide = false
            end
        end
    end

    noclipRoomStates[room] = state
    noclipCompletedRooms[room] = true
    if not noclipRoomConnections[room] then
        noclipRoomConnections[room] = room.DescendantAdded:Connect(function()
            if noclipenabled and scheduleNoclipRoomApply then scheduleNoclipRoomApply(room) end
        end)
    end
    local staleParts = {}
    for index, record in ipairs(state.parts) do
        if not record.instance or not record.instance:IsDescendantOf(room) then table.insert(staleParts, index) end
    end
    for index = #staleParts, 1, -1 do table.remove(state.parts, staleParts[index]) end
    CS:AddTag(room, "CGH_NoCliped")
end

local pendingNoclipRoomApplies = setmetatable({}, {__mode = "k"})
scheduleNoclipRoomApply = function(room)
    if pendingNoclipRoomApplies[room] then return end
    pendingNoclipRoomApplies[room] = true
    task.delay(0.1, function()
        pendingNoclipRoomApplies[room] = nil
        if noclipenabled and room.Parent then applyNoclipToRoom(room) end
    end)
end

local function watchNoclipRoomFolder(folder)
    if noclipRoomConnection then noclipRoomConnection:Disconnect() end
    if noclipRoomFolderRemovalConnection then noclipRoomFolderRemovalConnection:Disconnect() end
    if noclipFolderConnection then noclipFolderConnection:Disconnect() end
    noclipRoomConnection, noclipRoomFolderRemovalConnection, noclipFolderConnection = nil, nil, nil
    if not folder then return end
    noclipRoomConnection = folder.ChildAdded:Connect(function(room)
        if room:IsA("Model") then
            noclipRoomReadyAt[room] = os.clock() + 9
            task.delay(9, function()
                if room.Parent == folder and noclipenabled then applyNoclipToRoom(room) end
            end)
        end
    end)
    noclipRoomFolderRemovalConnection = folder.ChildRemoved:Connect(function(room)
        if room:IsA("Model") then
            local connection = noclipRoomConnections[room]
            if connection then
                connection:Disconnect()
                noclipRoomConnections[room] = nil
            end
            noclipRoomReadyAt[room] = nil
            if noclipRoomStates[room] then restoreRoomNoclip(room) end
        end
    end)
    noclipFolderConnection = workspace.ChildAdded:Connect(function(child)
        if child.Name == "CurrentRoom" then watchNoclipRoomFolder(child) end
    end)
    local room = folder:FindFirstChildOfClass("Model")
    if room then
        noclipRoomReadyAt[room] = os.clock() + 9
        task.delay(9, function()
            if room.Parent == folder and noclipenabled then applyNoclipToRoom(room) end
        end)
    end
end

watchNoclipRoomFolder(workspace:FindFirstChild("CurrentRoom"))

local function stopNoclipWatch()
    if noclipconnex then
        noclipconnex:Disconnect()
        noclipconnex = nil
    end
    if noclipRoomConnection then
        noclipRoomConnection:Disconnect()
        noclipRoomConnection = nil
    end
    if noclipRoomFolderRemovalConnection then
        noclipRoomFolderRemovalConnection:Disconnect()
        noclipRoomFolderRemovalConnection = nil
    end
    if noclipFolderConnection then
        noclipFolderConnection:Disconnect()
        noclipFolderConnection = nil
    end
    for room, connection in pairs(noclipRoomConnections) do
        connection:Disconnect()
        noclipRoomConnections[room] = nil
    end
end

local VisualWatch = {
    roomFolder = nil,
    map = nil,
    roomConnections = {},
    mapConnections = {},
    contentConnections = {},
    workspaceConnections = {},
    records = {},
    scanId = 0,
}

local function disconnectVisualConnections(connections)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
end

local function removeVisualESP(instance)
    local record = VisualWatch.records[instance]
    if record then
        for _, connection in ipairs(record.connections) do connection:Disconnect() end
        VisualWatch.records[instance] = nil
    end
    local highlight = instance and instance:FindFirstChild("CGH_ESP")
    if highlight then highlight:Destroy() end
    if instance then ESPService.RemoveFromPart(instance) end
end

local function clearVisualMap()
    disconnectVisualConnections(VisualWatch.mapConnections)
    disconnectVisualConnections(VisualWatch.contentConnections)
    local instances = {}
    for instance in pairs(VisualWatch.records) do table.insert(instances, instance) end
    for _, instance in ipairs(instances) do removeVisualESP(instance) end
    VisualWatch.map = nil
end

local function shouldRenderDrawing(kind, instance)
    if ESPDisplayMode == "Nada" then return false end
    if ESPDisplayMode == "Semi" then
        return kind == "item" and special_items[instance.Name] ~= nil
    end
    return true
end

local function applyVisualESP(instance, kind)
    if not instance or not instance.Parent then return end
    local enabled = kind == "monster" and MonsESP or kind == "generator" and GenESP or kind == "item" and ItemsESP
    if not enabled then return end
    local isModel = instance:IsA("Model")
    if kind == "item" and not isModel then return end
    if kind ~= "item" and not isModel then return end

    local color = kind == "monster" and espColors.Monster or espColors.Generator
    local itemSettings = kind == "item" and special_items[instance.Name] or nil
    if kind == "item" then color = itemSettings and itemSettings.color or colors.white end
    local whiteItemOutline = kind == "item" and (instance.Name == "Tape" or instance.Name == "ResearchCapsule")
    local outlineColor = whiteItemOutline and colors.white or Color3.fromRGB(0, 0, 0)
    local record = VisualWatch.records[instance]
    if record then record.kind = kind end
    local highlight = instance:FindFirstChild("CGH_ESP")
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "CGH_ESP"
        highlight.Adornee = instance
        highlight.Parent = instance
    end
    highlight.FillColor = color
    highlight.OutlineColor = outlineColor
    highlight.FillTransparency = kind == "item" and 0.25 or 0.8
    highlight.OutlineTransparency = 0

    ESPService.RemoveFromPart(instance)
    if shouldRenderDrawing(kind, instance) then
        ESPService.Create(instance, instance.Name, {
            Color = color,
            TextColor = color,
            BoxColor = outlineColor,
            OutlineColor = outlineColor,
            Size = kind == "item" and 15 or 16,
            Outline = true,
            Box = kind ~= "item" and kind == "monster",
            ShowDistance = false,
        })
    end

    if not VisualWatch.records[instance] then
        local record = {kind = kind, connections = {}}
        VisualWatch.records[instance] = record
        table.insert(record.connections, instance:GetPropertyChangedSignal("Name"):Connect(function()
            if VisualWatch.records[instance] then
                removeVisualESP(instance)
                applyVisualESP(instance, kind)
            end
        end))
        table.insert(record.connections, instance.AncestryChanged:Connect(function(_, parent)
            if parent == nil then removeVisualESP(instance) end
        end))
    end

    if kind == "item" and itemSettings and itemSettings.notify then
        local notified = VisualWatch.records[instance].notified
        if not notified then
            VisualWatch.records[instance].notified = true
            WindUI:Notify({
                Title = instance.Name .. " encontrado",
                Content = "Item encontrado: " .. instance.Name,
                Icon = "package-check",
                Duration = 5,
            })
        end
    end
end

local function setVisualKindEnabled(kind, enabled)
    for instance, record in pairs(VisualWatch.records) do
        if record.kind == kind then
            removeVisualESP(instance)
        end
    end
    if not enabled then return end
    local map = VisualWatch.map
    local folderName = kind == "monster" and "Monsters" or kind == "generator" and "Generators" or "Items"
    local folder = map and map:FindFirstChild(folderName)
    if not folder then
        if map then
            task.spawn(function()
                local found = map:WaitForChild(folderName, 6)
                if found and VisualWatch.map == map then setVisualKindEnabled(kind, true) end
            end)
        end
        return
    end
    for _, instance in ipairs(folder:GetChildren()) do applyVisualESP(instance, kind) end
end

function f_monesp(status)
    MonsESP = status
    setVisualKindEnabled("monster", status)
end

function f_genesp(status)
    GenESP = status
    setVisualKindEnabled("generator", status)
end

local function f_itemsesp(status)
    ItemsESP = status
    setVisualKindEnabled("item", status)
end

local function attachVisualFolder(map, folderName, kind)
    local folder = map:FindFirstChild(folderName)
    if not folder then
        task.spawn(function()
            local found = map:WaitForChild(folderName, 6)
            if found and VisualWatch.map == map then attachVisualFolder(map, folderName, kind) end
        end)
        return
    end
    local enabled = kind == "monster" and MonsESP or kind == "generator" and GenESP or kind == "item" and ItemsESP
    if enabled then
        for _, instance in ipairs(folder:GetChildren()) do applyVisualESP(instance, kind) end
    end
    table.insert(VisualWatch.contentConnections, folder.ChildAdded:Connect(function(instance)
        if kind == "item" and (instance.Name == "Bandage" or instance.Name == "HealthKit") then
            applyVisualESP(instance, kind)
        elseif kind ~= "item" then
            applyVisualESP(instance, kind)
        elseif ItemsESP then
            applyVisualESP(instance, kind)
        end
    end))
    table.insert(VisualWatch.contentConnections, folder.ChildRemoved:Connect(removeVisualESP))
end

local function identifyVisualMap(folder)
    local candidates = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") then
            local score = 0
            for _, name in ipairs({"Generators", "Monsters", "Items"}) do
                if child:FindFirstChild(name) then score += 1 end
            end
            if score > 0 then table.insert(candidates, {map = child, score = score}) end
        end
    end
    table.sort(candidates, function(a, b) return a.score > b.score end)
    if #candidates == 0 or (#candidates > 1 and candidates[1].score == candidates[2].score) then return nil end
    return candidates[1].map
end

local function bindVisualRoom(folder)
    disconnectVisualConnections(VisualWatch.roomConnections)
    clearVisualMap()
    VisualWatch.scanId += 1
    VisualWatch.roomFolder = folder
    if not folder then return end
    local function schedule(delaySeconds)
        VisualWatch.scanId += 1
        local id = VisualWatch.scanId
        clearVisualMap()
        task.delay(delaySeconds or 9, function()
            if id ~= VisualWatch.scanId or VisualWatch.roomFolder ~= folder or folder.Parent ~= workspace then return end
            local map = identifyVisualMap(folder)
            if not map then
                schedule(2)
                return
            end
            VisualWatch.map = map
            for _, entry in ipairs({{"Monsters", "monster"}, {"Generators", "generator"}, {"Items", "item"}}) do
                attachVisualFolder(map, entry[1], entry[2])
            end
        end)
    end
    table.insert(VisualWatch.roomConnections, folder.ChildAdded:Connect(function(child)
        if child:IsA("Model") then schedule(9) end
    end))
    table.insert(VisualWatch.roomConnections, folder.ChildRemoved:Connect(function(child)
        if child == VisualWatch.map then schedule(9) end
    end))
    schedule(9)
end

table.insert(VisualWatch.workspaceConnections, workspace.ChildAdded:Connect(function(child)
    if child.Name == "CurrentRoom" and child:IsA("Folder") then bindVisualRoom(child) end
end))
table.insert(VisualWatch.workspaceConnections, workspace.ChildRemoved:Connect(function(child)
    if child == VisualWatch.roomFolder then bindVisualRoom(nil) end
end))
bindVisualRoom(workspace:FindFirstChild("CurrentRoom"))

local function setESPDisplayMode(mode)
    if mode ~= "Tudo" and mode ~= "Semi" and mode ~= "Nada" then return end
    ESPDisplayMode = mode
    for instance, record in pairs(VisualWatch.records) do
        applyVisualESP(instance, record.kind)
    end
end

local function setESPBoxesEnabled(enabled)
    ESPBoxesEnabled = enabled
    for esp in pairs(objects) do
        if not enabled then
            esp.Drawings.Box.Visible = false
            esp.Drawings.Quad.Visible = false
        end
    end
end

local function stopVisualWatch()
    VisualWatch.scanId += 1
    disconnectVisualConnections(VisualWatch.roomConnections)
    disconnectVisualConnections(VisualWatch.workspaceConnections)
    clearVisualMap()
    VisualWatch.roomFolder = nil
    MonsESP = false
    GenESP = false
    ItemsESP = false
end


-- mainframe
local anony_ = false
local gui
gui = WindUI:CreateWindow({
    Title = "Conguitos Hub", 
    Icon = "https://raw.githubusercontent.com/JuninSB/CGH_HUB/refs/heads/main/assets/icon.jpg", 
    Author = "by Mike and Tinhopro",
    Folder = "ConguitosHub",
    Theme = "Dark",
    Size = UDim2.fromOffset(640, 520),
    MinSize = Vector2.new(560, 420),
    Resizable = true,
    User = { -- user information located at the bottom left
        Enabled = true, -- can be toggled with Window.User:Enable() or Window.User:Disable()
        Anonymous = anony_, -- can be toggled with Window.User:SetAnonymous(true) --(true or false)
        Callback = function() -- callback on click. optional, it can be removed
            anony_ = not anony_
            if not anony_ then
                gui.User:SetAnonymous(anony_)
                WindUI:Notify({
                Title = "Modo anônimo desativado",
                Content = "Agora outros podem ver seu perfil",
                Icon = "shield-x", -- lucide icon or "rbxassetid://". optional
                Duration = 3, -- time in seconds. optional
            })
            else
                gui.User:SetAnonymous(anony_)
                WindUI:Notify({
                Title = "Modo anônimo ativado",
                Content = "Agora outros nao podem ver o perfil",
                Icon = "shield-check", -- lucide icon or "rbxassetid://". optional
                Duration = 3, -- time in seconds. optional
            })
            end
        end,
    },
})

local sessionStartedAt = os.clock()
local fpsFrames = 0
local fpsValue = 0
local lastFPSUpdate = sessionStartedAt
local fpsTag
local playtimeTag
local fpsTagConnection
local playtimeTagTimerId = 0
local function setFPSTagVisible(visible)
    if fpsTagConnection then
        fpsTagConnection:Disconnect()
        fpsTagConnection = nil
    end
    if fpsTag then
        pcall(function() fpsTag:Destroy() end)
        fpsTag = nil
    end
    if not visible then return end
    fpsTag = gui:Tag({Title = "FPS: 0", Icon = "gauge", Color = Color3.fromRGB(80, 180, 255)})
    fpsFrames = 0
    lastFPSUpdate = os.clock()
    fpsTagConnection = RunService.RenderStepped:Connect(function()
        fpsFrames += 1
        local now = os.clock()
        local elapsed = now - lastFPSUpdate
        if elapsed >= 1 then
            fpsValue = math.floor(fpsFrames / elapsed + 0.5)
            fpsFrames = 0
            lastFPSUpdate = now
            if fpsTag then pcall(function() fpsTag:SetTitle("FPS: " .. tostring(fpsValue)) end) end
        end
    end)
end

local function setPlaytimeTagVisible(visible)
    playtimeTagTimerId += 1
    if playtimeTag then
        pcall(function() playtimeTag:Destroy() end)
        playtimeTag = nil
    end
    if not visible then return end
    playtimeTag = gui:Tag({Title = "00:00:00:00", Icon = "clock-3", Color = Color3.fromRGB(170, 120, 255)})
    local timerId = playtimeTagTimerId
    local function updatePlaytime()
        if timerId ~= playtimeTagTimerId or not playtimeTag then return end
        local elapsed = os.clock() - sessionStartedAt
        local hours = math.floor(elapsed / 3600)
        local minutes = math.floor(elapsed / 60) % 60
        local seconds = math.floor(elapsed) % 60
        local centiseconds = math.floor((elapsed % 1) * 100)
        pcall(function() playtimeTag:SetTitle(string.format("%02d:%02d:%02d:%02d", hours, minutes, seconds, centiseconds)) end)
        task.delay(0.1, updatePlaytime)
    end
    task.defer(updatePlaytime)
end

local function setStatusTagsEnabled(enabled)
    setFPSTagVisible(enabled)
    setPlaytimeTagVisible(enabled)
end

setStatusTagsEnabled(true)

local autoQTEEnabled = false
local replicatedStorage = game:GetService("ReplicatedStorage")
local eventsFolder = replicatedStorage:FindFirstChild("Events")
local QTEEVENT = eventsFolder and eventsFolder:FindFirstChild("SkillcheckUpdate")
if not QTEEVENT or not QTEEVENT:IsA("RemoteFunction") then
    error("ReplicatedStorage.Events.SkillcheckUpdate RemoteFunction not found")
end
local function getQTECallback()
    local getter = getcallbackvalue or getcallbackmember
    if type(getter) ~= "function" then return nil end
    return getter(QTEEVENT, "OnClientInvoke")
end

local originalQTECallback = getQTECallback()
local autoQTEHandler

autoQTEHandler = function(...)
    if autoQTEEnabled then
        WindUI:Notify({
                Title = "AutoQTE",
                Content = "QTE Pulado, BOOST APLICADO.",
                Icon = "gauge", -- lucide icon or "rbxassetid://". optional
                Duration = 1, -- time in seconds. optional
        })
        return "supercomplete"
    end
    if originalQTECallback then
        return originalQTECallback(...)
    end
    return nil
end

local function setAutoQTE(state)
    autoQTEEnabled = state
    if state then
        local currentCallback = getQTECallback()
        if currentCallback ~= autoQTEHandler then
            if currentCallback then originalQTECallback = currentCallback end
            QTEEVENT.OnClientInvoke = autoQTEHandler
        end
    elseif getQTECallback() == autoQTEHandler then
        QTEEVENT.OnClientInvoke = originalQTECallback
    end
end

local GeneratorWatch = {
    folder = nil,
    map = nil,
    mapConnections = {},
    generatorRecords = {},
    currentRoomConnections = {},
    workspaceConnections = {},
    scanId = 0,
    stopped = false,
}
local NextGeneratorConnections = {}
local AutoHideEnabled = false
local NextGeneratorEnabled = false
local AutoHideConnections = {}
local AntiMissclickEnabled = false
local AntiMissclickBeingChased = false
local AntiMissclickEventChased = false
local AntiMissclickConnections = {}
local AntiMissclickMonsterConnections = {}
local AntiMissclickMonsterRecords = {}
local AntiMissclickStoppedGenerators = {}
local playerNameFromValue
local valueDescription
local getCharacterRoot
local autoHideSavedCFrame
local autoHideActive = false
local autoHideLoopId = 0
local autoHideTween
local autoHidePositionedGenerator
local autoHideWasSpotted = false
local workingGenerator
local prepositionSourceGenerator
local prepositionedGenerator
local spottedDuringPreposition = false
local updateNextGeneratorState
local teleportToNextGenerator
local startPreHide

local function generatorDiagnostic(message)
    print("[GeneratorWatch] " .. message)
end

local function nextGeneratorDiagnostic(message)
    print("[NextGenerator][" .. string.format("%.2f", os.clock()) .. "] " .. message)
end

local function disconnectConnections(connections)
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    table.clear(connections)
end

local function updateAntiMissclickChaseState()
    local chased = false
    for monster, record in pairs(AntiMissclickMonsterRecords) do
        if monster.Parent and record.chasing and record.chasing:IsA("BoolValue") and record.chasingValue and record.chasingValue:IsA("ValueBase") then
            if record.chasing.Value and playerNameFromValue(record.chasingValue.Value) == localplayer.Name then
                chased = true
                break
            end
        end
    end
    chased = chased or AntiMissclickEventChased
    if chased ~= AntiMissclickBeingChased then
        AntiMissclickBeingChased = chased
        table.clear(AntiMissclickStoppedGenerators)
        print("[Anti Missclick] Monster chase state from Chasing values | beingChased=" .. tostring(chased))
    end
end

local function monitorAntiMissclickMonster(monster)
    if not monster:IsA("Model") or AntiMissclickMonsterRecords[monster] then return end
    local record = {connections = {}, chasing = nil, chasingValue = nil, chasingConnection = nil, chasingValueConnection = nil}
    AntiMissclickMonsterRecords[monster] = record

    local function reportChaseValueChange(changedName)
        local rawTarget = record.chasingValue and record.chasingValue.Value or nil
        local targetName = rawTarget ~= nil and playerNameFromValue(rawTarget) or "nil"
        print("[Anti Missclick] Chase value changed | monster=" .. monster:GetFullName() .. " | changed=" .. changedName .. " | Chasing=" .. tostring(record.chasing and record.chasing.Value) .. " | ChasingValue=" .. valueDescription(rawTarget) .. " | resolvedTarget=" .. tostring(targetName) .. " | localPlayer=" .. tostring(targetName == localplayer.Name))
        updateAntiMissclickChaseState()
    end

    local function configure()
        local chasing = monster:FindFirstChild("Chasing", true)
        local chasingValue = monster:FindFirstChild("ChasingValue", true)
        if chasing ~= record.chasing then
            if record.chasingConnection then
                record.chasingConnection:Disconnect()
                record.chasingConnection = nil
            end
            record.chasing = chasing and chasing:IsA("BoolValue") and chasing or nil
            if record.chasing then
                record.chasingConnection = record.chasing:GetPropertyChangedSignal("Value"):Connect(function()
                    reportChaseValueChange("Chasing")
                end)
            end
        end
        if chasingValue ~= record.chasingValue then
            if record.chasingValueConnection then
                record.chasingValueConnection:Disconnect()
                record.chasingValueConnection = nil
            end
            record.chasingValue = chasingValue and chasingValue:IsA("ValueBase") and chasingValue or nil
            if record.chasingValue then
                record.chasingValueConnection = record.chasingValue:GetPropertyChangedSignal("Value"):Connect(function()
                    reportChaseValueChange("ChasingValue")
                end)
            end
        end
        if record.chasing and record.chasingValue then
            local targetName = playerNameFromValue(record.chasingValue.Value)
            print("[Anti Missclick] Monitoring monster chase values | monster=" .. monster:GetFullName() .. " | Chasing=" .. tostring(record.chasing.Value) .. " | ChasingValue=" .. valueDescription(record.chasingValue.Value) .. " | resolvedTarget=" .. tostring(targetName) .. " | localPlayer=" .. tostring(targetName == localplayer.Name))
        else
            print("[Anti Missclick] Monster chase values missing/invalid | monster=" .. monster:GetFullName() .. " | Chasing=" .. tostring(chasing and chasing.ClassName) .. " | ChasingValue=" .. tostring(chasingValue and chasingValue.ClassName))
        end
        updateAntiMissclickChaseState()
    end

    table.insert(record.connections, monster.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "Chasing" or descendant.Name == "ChasingValue" then task.defer(configure) end
    end))
    table.insert(record.connections, monster.DescendantRemoving:Connect(function(descendant)
        if descendant == record.chasing or descendant == record.chasingValue then task.defer(configure) end
    end))
    table.insert(AntiMissclickMonsterConnections, monster.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            disconnectConnections(record.connections)
            if record.chasingConnection then record.chasingConnection:Disconnect() end
            if record.chasingValueConnection then record.chasingValueConnection:Disconnect() end
            AntiMissclickMonsterRecords[monster] = nil
            updateAntiMissclickChaseState()
        end
    end))
    configure()
end

local function bindAntiMissclickMonsters(map)
    disconnectConnections(AntiMissclickMonsterConnections)
    for monster, record in pairs(AntiMissclickMonsterRecords) do
        disconnectConnections(record.connections)
        if record.chasingConnection then record.chasingConnection:Disconnect() end
        if record.chasingValueConnection then record.chasingValueConnection:Disconnect() end
        AntiMissclickMonsterRecords[monster] = nil
    end
    local monsters = map and map:FindFirstChild("Monsters")
    if not monsters then
        AntiMissclickBeingChased = false
        print("[Anti Missclick] Monsters folder missing for current map")
        return
    end
    for _, monster in ipairs(monsters:GetChildren()) do monitorAntiMissclickMonster(monster) end
    table.insert(AntiMissclickMonsterConnections, monsters.ChildAdded:Connect(monitorAntiMissclickMonster))
    table.insert(AntiMissclickMonsterConnections, monsters.ChildRemoved:Connect(function(monster)
        local record = AntiMissclickMonsterRecords[monster]
        if record then
            disconnectConnections(record.connections)
            if record.chasingConnection then record.chasingConnection:Disconnect() end
            if record.chasingValueConnection then record.chasingValueConnection:Disconnect() end
            AntiMissclickMonsterRecords[monster] = nil
            updateAntiMissclickChaseState()
        end
    end))
end

local function clearGeneratorMap()
    autoHideLoopId += 1
    AntiMissclickBeingChased = false
    AntiMissclickEventChased = false
    bindAntiMissclickMonsters(nil)
    table.clear(AntiMissclickStoppedGenerators)
    if autoHideActive and autoHideSavedCFrame then
        local character = localplayer.Character
        local root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("RootPart"))
        if root then
            if autoHideTween then
                autoHideTween:Cancel()
                autoHideTween = nil
            end
            root.CFrame = autoHideSavedCFrame
            local syncRoot = character:FindFirstChild("RootPart")
            if syncRoot and syncRoot:IsA("BasePart") then syncRoot.CFrame = root.CFrame end
        end
    end
    autoHideActive = false
    autoHideSavedCFrame = nil
    autoHidePositionedGenerator = nil
    autoHideWasSpotted = false
    workingGenerator = nil
    prepositionSourceGenerator = nil
    prepositionedGenerator = nil
    spottedDuringPreposition = false
    if VisualWatch then
        if VisualWatch.map and VisualWatch.map ~= GeneratorWatch.map then
            VisualWatch.scanId += 1
            clearVisualMap()
        end
    end
    disconnectConnections(GeneratorWatch.mapConnections)
    disconnectConnections(NextGeneratorConnections)
    for _, record in pairs(GeneratorWatch.generatorRecords) do
        disconnectConnections(record.connections)
        if record.valueConnection then
            record.valueConnection:Disconnect()
            record.valueConnection = nil
        end
    end
    table.clear(GeneratorWatch.generatorRecords)
    GeneratorWatch.map = nil
end

valueDescription = function(value)
    if value == nil then
        return "nil"
    end
    if typeof(value) == "Instance" then
        return value:GetFullName()
    end
    return tostring(value)
end

local function valueIsActive(value)
    if value == nil then
        return false
    end
    if typeof(value) == "string" then
        return value:match("%S") ~= nil
    end
    return true
end

playerNameFromValue = function(value)
    if typeof(value) == "Instance" and value:IsA("Player") then
        return value.Name
    end
    if typeof(value) == "Instance" then
        local player = Players:FindFirstChild(value.Name)
        if player and player:IsA("Player") then return player.Name end
        if value:IsA("Model") then return value.Name end
        return value.Name
    end

    if typeof(value) == "number" then
        local found = Players:GetPlayerByUserId(value)
        return found and found.Name or tostring(value)
    end

    if typeof(value) == "string" then
        local text = value:match("^%s*(.-)%s*$")
        local exactPlayer = Players:FindFirstChild(text)
        if exactPlayer and exactPlayer:IsA("Player") then
            return exactPlayer.Name
        end
        local numericId = tonumber(text)
        if numericId then
            local found = Players:GetPlayerByUserId(numericId)
            if found then
                return found.Name
            end
        end
        local displayNameMatch
        for _, candidate in ipairs(Players:GetPlayers()) do
            if candidate.DisplayName == text then
                if displayNameMatch then
                    return text
                end
                displayNameMatch = candidate
            end
        end
        if displayNameMatch then
            return displayNameMatch.Name
        end
        return text
    end

    return tostring(value)
end

local function isLocalPlayerValue(value)
    if typeof(value) == "Instance" then
        if value == localplayer or value == localplayer.Character then return true end
        if value:IsA("Model") and value.Name == localplayer.Name then return true end
        return false
    end
    if typeof(value) == "number" then return value == localplayer.UserId end
    if typeof(value) == "string" then return playerNameFromValue(value) == localplayer.Name end
    return false
end

local function stopGeneratorInteractionIfChased(generator)
    if not AntiMissclickEnabled or not AntiMissclickBeingChased or not generator or AntiMissclickStoppedGenerators[generator] then return false end
    if not GeneratorWatch.generatorRecords[generator] then
        generatorDiagnostic("Anti Missclick: target is not in the active generator monitor | " .. generator:GetFullName())
        return false
    end
    local stats = generator:FindFirstChild("Stats")
    local stopInteracting = stats and stats:FindFirstChild("StopInteracting")
    if not stopInteracting or not stopInteracting:IsA("RemoteEvent") then
        generatorDiagnostic("Anti Missclick: Stats.StopInteracting RemoteEvent missing for " .. generator:GetFullName())
        return false
    end

    AntiMissclickStoppedGenerators[generator] = true
    print("[Anti Missclick] Chased generator interaction detected; waiting 0.128s before Stop: " .. generator:GetFullName())
    task.delay(0.128, function()
        if not AntiMissclickEnabled or not AntiMissclickBeingChased then
            AntiMissclickStoppedGenerators[generator] = nil
            print("[Anti Missclick] Stop canceled because LostInterest arrived during sync delay")
            return
        end
        if not generator.Parent or not GeneratorWatch.generatorRecords[generator] then
            AntiMissclickStoppedGenerators[generator] = nil
            print("[Anti Missclick] Stop canceled because the generator was removed before sync")
            return
        end
        local currentStats = generator:FindFirstChild("Stats")
        local activePlayer = currentStats and currentStats:FindFirstChild("ActivePlayer")
        if not activePlayer or not activePlayer:IsA("ValueBase") or not isLocalPlayerValue(activePlayer.Value) then
            AntiMissclickStoppedGenerators[generator] = nil
            print("[Anti Missclick] Stop canceled because this generator is no longer active for the local player")
            return
        end
        local currentStop = currentStats:FindFirstChild("StopInteracting")
        if not currentStop or not currentStop:IsA("RemoteEvent") then
            AntiMissclickStoppedGenerators[generator] = nil
            generatorDiagnostic("Anti Missclick: Stats.StopInteracting disappeared before send | " .. generator:GetFullName())
            return
        end
        currentStop:FireServer("Stop")
        print("[Anti Missclick] Fired Stats.StopInteracting('Stop') for active generator: " .. generator:GetFullName())
    end)
    return true
end

local function cancelAutoHideForMissclick(generator)
    if not autoHideActive or workingGenerator ~= generator then return end
    autoHideLoopId += 1
    if autoHideTween then
        autoHideTween:Cancel()
        autoHideTween = nil
    end
    local savedCFrame = autoHideSavedCFrame
    local root = getCharacterRoot()
    if savedCFrame and root and autoHidePositionedGenerator == generator then
        root.CFrame = savedCFrame
        local syncRoot = localplayer.Character and localplayer.Character:FindFirstChild("RootPart")
        if syncRoot and syncRoot:IsA("BasePart") then syncRoot.CFrame = savedCFrame end
    end
    autoHideSavedCFrame = nil
    autoHideActive = false
    autoHideWasSpotted = false
    autoHidePositionedGenerator = nil
    print("[AutoHide] Pre-hide canceled because generator interaction was a chased missclick")
end

local function bindAntiMissclickEvents()
    disconnectConnections(AntiMissclickConnections)
    local storyEvents = game:GetService("ReplicatedStorage"):FindFirstChild("StoryEvents")
    local spotted = storyEvents and storyEvents:FindFirstChild("Spotted")
    local lostInterest = storyEvents and storyEvents:FindFirstChild("LostInterest")
    if spotted and spotted:IsA("RemoteEvent") then
        table.insert(AntiMissclickConnections, spotted.OnClientEvent:Connect(function(monster)
            if not AntiMissclickEnabled then return end
            AntiMissclickEventChased = true
            table.clear(AntiMissclickStoppedGenerators)
            print("[Anti Missclick] StoryEvents.Spotted.OnClientEvent received | source=" .. valueDescription(monster) .. " | chase window started")
            updateAntiMissclickChaseState()
        end))
    else
        generatorDiagnostic("Anti Missclick: StoryEvents.Spotted RemoteEvent not found")
    end
    if lostInterest and lostInterest:IsA("RemoteEvent") then
        table.insert(AntiMissclickConnections, lostInterest.OnClientEvent:Connect(function()
            if not AntiMissclickEnabled then return end
            AntiMissclickEventChased = false
            AntiMissclickBeingChased = false
            table.clear(AntiMissclickStoppedGenerators)
            print("[Anti Missclick] StoryEvents.LostInterest.OnClientEvent received; chase window ended")
        end))
    else
        generatorDiagnostic("Anti Missclick: StoryEvents.LostInterest RemoteEvent not found")
    end
end

local function setAntiMissclick(state)
    AntiMissclickEnabled = state
    table.clear(AntiMissclickStoppedGenerators)
    if state then
        AntiMissclickBeingChased = false
        AntiMissclickEventChased = false
        bindAntiMissclickEvents()
    else
        AntiMissclickBeingChased = false
        AntiMissclickEventChased = false
        disconnectConnections(AntiMissclickConnections)
    end
    print("[Anti Missclick] Toggle changed | enabled=" .. tostring(state))
    if state then
        bindAntiMissclickMonsters(GeneratorWatch.map)
    else
        bindAntiMissclickMonsters(nil)
    end
end

local function configureGenerator(record)
    if not record.instance.Parent then
        return
    end

    local stats = record.instance:FindFirstChild("Stats")
    local activePlayer = stats and stats:FindFirstChild("ActivePlayer")
    local validValue = activePlayer and activePlayer:IsA("ValueBase")

    local function stopValueMonitor()
        if record.valueConnection then
            record.valueConnection:Disconnect()
            record.valueConnection = nil
        end
        record.activePlayer = nil
    end

    if not stats then
        stopValueMonitor()
        if record.status ~= "missing-stats" then
            generatorDiagnostic("Generator " .. record.instance.Name .. " has no Stats child")
            record.status = "missing-stats"
        end
        return
    end
    if not activePlayer then
        stopValueMonitor()
        if record.status ~= "missing-active-player" then
            generatorDiagnostic("Generator " .. record.instance.Name .. " has Stats but no ActivePlayer child")
            record.status = "missing-active-player"
        end
        return
    end
    if not validValue then
        stopValueMonitor()
        if record.status ~= "invalid-active-player" then
            generatorDiagnostic("Generator " .. record.instance.Name .. " ActivePlayer is " .. activePlayer.ClassName .. ", not a ValueBase")
            record.status = "invalid-active-player"
        end
        return
    end
    if record.activePlayer == activePlayer and record.valueConnection then
        return
    end

    if record.valueConnection then
        record.valueConnection:Disconnect()
        record.valueConnection = nil
    end

    record.activePlayer = activePlayer
    record.status = "monitoring"
    local previousValue = activePlayer.Value
    generatorDiagnostic("Generator " .. record.instance.Name .. " ActivePlayer type=" .. activePlayer.ClassName .. " initial=" .. valueDescription(previousValue))
    nextGeneratorDiagnostic("ActivePlayer attached | generator=" .. record.instance:GetFullName() .. " | class=" .. activePlayer.ClassName .. " | initial=" .. valueDescription(previousValue) .. " | localPlayer=" .. tostring(isLocalPlayerValue(previousValue)))
    if isLocalPlayerValue(previousValue) then
        workingGenerator = record.instance
        local stoppedAsMissclick = stopGeneratorInteractionIfChased(record.instance)
        if stoppedAsMissclick then
            cancelAutoHideForMissclick(record.instance)
        else
            startPreHide(record.instance)
        end
        nextGeneratorDiagnostic("WORKING GENERATOR SET FROM INITIAL VALUE | " .. record.instance:GetFullName())
        if updateNextGeneratorState then task.defer(updateNextGeneratorState, record.instance) end
    elseif workingGenerator == record.instance then
        workingGenerator = nil
    end

    record.valueConnection = activePlayer:GetPropertyChangedSignal("Value"):Connect(function()
        local newValue = activePlayer.Value
        generatorDiagnostic("Generator " .. record.instance.Name .. " ActivePlayer changed from " .. valueDescription(previousValue) .. " to " .. valueDescription(newValue))
        nextGeneratorDiagnostic("ActivePlayer.Value changed | generator=" .. record.instance:GetFullName() .. " | from=" .. valueDescription(previousValue) .. " | to=" .. valueDescription(newValue) .. " | localPlayer=" .. tostring(isLocalPlayerValue(newValue)))
        if isLocalPlayerValue(newValue) then
            workingGenerator = record.instance
            local startedDuringChase = not isLocalPlayerValue(previousValue)
            local stoppedAsMissclick = startedDuringChase and stopGeneratorInteractionIfChased(record.instance)
            if startedDuringChase and not stoppedAsMissclick then
                print("[Anti Missclick] Generator start was not canceled | enabled=" .. tostring(AntiMissclickEnabled) .. " | beingChased=" .. tostring(AntiMissclickBeingChased) .. " | generator=" .. record.instance:GetFullName())
            end
            if stoppedAsMissclick then
                cancelAutoHideForMissclick(record.instance)
            else
                startPreHide(record.instance)
            end
            nextGeneratorDiagnostic("WORKING GENERATOR SET | " .. record.instance:GetFullName())
            if updateNextGeneratorState then task.defer(updateNextGeneratorState, record.instance) end
        elseif isLocalPlayerValue(previousValue) and workingGenerator == record.instance then
            workingGenerator = nil
            if autoHidePositionedGenerator == record.instance and not autoHideActive then
                autoHidePositionedGenerator = nil
            end
            nextGeneratorDiagnostic("WORKING GENERATOR CLEARED | " .. record.instance:GetFullName())
        end
        if not valueIsActive(previousValue) and valueIsActive(newValue) then
            local username = playerNameFromValue(newValue)
            local message = "Generator " .. record.instance.Name .. " is now being used by " .. username
            print("[GeneratorWatch] " .. message)
            WindUI:Notify({
                Title = "Generator in use",
                Content = message,
                Icon = "zap",
                Duration = 4,
            })
        end
        previousValue = newValue
    end)
end

local function monitorGenerator(generator)
    if not generator:IsA("Model") or GeneratorWatch.generatorRecords[generator] then
        return
    end

    local record = {
        instance = generator,
        connections = {},
        valueConnection = nil,
        activePlayer = nil,
        status = nil,
    }
    GeneratorWatch.generatorRecords[generator] = record
    configureGenerator(record)

    table.insert(record.connections, generator.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "Stats" or descendant.Name == "ActivePlayer" then
            task.defer(configureGenerator, record)
        end
    end))
    table.insert(record.connections, generator.DescendantRemoving:Connect(function(descendant)
        if descendant == record.activePlayer or descendant.Name == "Stats" or descendant.Name == "ActivePlayer" then
            task.defer(configureGenerator, record)
        end
    end))
    local function watchStatValue(valueObject)
        if valueObject and valueObject:IsA("ValueBase") then
            table.insert(record.connections, valueObject:GetPropertyChangedSignal("Value"):Connect(function()
                nextGeneratorDiagnostic("Stat changed | generator=" .. generator:GetFullName() .. " | stat=" .. valueObject.Name .. " | value=" .. tostring(valueObject.Value) .. " | active=" .. tostring(workingGenerator == generator) .. " | toggle=" .. tostring(NextGeneratorEnabled))
                if updateNextGeneratorState and workingGenerator == generator then
                    updateNextGeneratorState(generator)
                end
            end))
        end
    end
    local stats = generator:FindFirstChild("Stats")
    if stats then
        watchStatValue(stats:FindFirstChild("CurrentAmount"))
        watchStatValue(stats:FindFirstChild("RequiredAmount"))
    end
    table.insert(record.connections, generator.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "CurrentAmount" or descendant.Name == "RequiredAmount" then
            watchStatValue(descendant)
        end
    end))
end

local function structureForMap(map)
    local generators = map:FindFirstChild("Generators")
    if not generators or not generators:IsA("Folder") then
        return nil, 0, 0, 0
    end

    local total = 0
    local statsCount = 0
    local activePlayerCount = 0
    for _, generator in ipairs(generators:GetChildren()) do
        if generator:IsA("Model") then
            total += 1
            local stats = generator:FindFirstChild("Stats")
            if stats then
                statsCount += 1
                local activePlayer = stats:FindFirstChild("ActivePlayer")
                if activePlayer and activePlayer:IsA("ObjectValue") then
                    activePlayerCount += 1
                end
            end
        end
    end
    return generators, total, statsCount, activePlayerCount
end

local bindNextGenerator

local function startGeneratorMapScan(reason, scanId)
    task.delay(6, function()
        if GeneratorWatch.stopped or scanId ~= GeneratorWatch.scanId then
            return
        end

        local currentRoom = GeneratorWatch.folder
        if not currentRoom or currentRoom.Parent ~= workspace then
            generatorDiagnostic("CurrentRoom does not exist when scanning after " .. reason)
            return
        end

        local candidates = {}
        local modelCount = 0
        for _, child in ipairs(currentRoom:GetChildren()) do
            if child:IsA("Model") then
                modelCount += 1
                local generators, total, statsCount, activeCount = structureForMap(child)
                if generators then
                    table.insert(candidates, {
                        map = child,
                        generators = generators,
                        total = total,
                        statsCount = statsCount,
                        activeCount = activeCount,
                    })
                    generatorDiagnostic("Map candidate " .. child.Name .. ": generators=" .. total .. ", Stats=" .. statsCount .. ", ActivePlayer=" .. activeCount)
                else
                    generatorDiagnostic("Model " .. child.Name .. " has no valid Generators Folder")
                end
            end
        end

        if #candidates == 0 then
            if modelCount == 0 then
                generatorDiagnostic("No map Model found inside CurrentRoom after " .. reason)
            else
                generatorDiagnostic("No valid map Model with a Generators Folder found inside CurrentRoom after " .. reason)
            end
            return
        end

        local selected
        for _, candidate in ipairs(candidates) do
            if candidate.total > 0 and candidate.statsCount > 0 then
                if selected then
                    generatorDiagnostic("Multiple map candidates contain a Generators folder; refusing to choose arbitrarily")
                    return
                end
                selected = candidate
            end
        end
        if not selected then
            generatorDiagnostic("No map candidate has actual generator models with Stats")
            return
        end

        clearGeneratorMap()
        GeneratorWatch.map = selected.map
        if AntiMissclickEnabled then bindAntiMissclickMonsters(selected.map) end
        generatorDiagnostic("Identified new map " .. selected.map.Name .. " after 6 seconds; monitoring " .. selected.generators:GetFullName())
        table.insert(GeneratorWatch.mapConnections, selected.map.DescendantAdded:Connect(function(descendant)
            if AntiMissclickEnabled and descendant.Name == "Monsters" and descendant:IsA("Folder") then
                bindAntiMissclickMonsters(selected.map)
            end
        end))
        if VisualWatch and VisualWatch.map ~= selected.map then
            VisualWatch.scanId += 1
            clearVisualMap()
            VisualWatch.map = selected.map
            for _, entry in ipairs({{"Monsters", "monster"}, {"Generators", "generator"}, {"Items", "item"}}) do
                attachVisualFolder(selected.map, entry[1], entry[2])
            end
        end

        for _, generator in ipairs(selected.generators:GetChildren()) do
            monitorGenerator(generator)
        end

        table.insert(GeneratorWatch.mapConnections, selected.map.DescendantAdded:Connect(function(descendant)
            if descendant.Parent == selected.generators and descendant:IsA("Model") then
                nextGeneratorDiagnostic("Generator model added after initial scan: " .. descendant:GetFullName())
                monitorGenerator(descendant)
                task.defer(bindNextGenerator)
            elseif descendant.Name == "Stats" or descendant.Name == "ActivePlayer" or descendant.Name == "CurrentAmount" or descendant.Name == "RequiredAmount" or descendant.Name == "Completed" then
                local ancestor = descendant.Parent
                while ancestor and ancestor ~= selected.map and ancestor.Parent ~= selected.generators do ancestor = ancestor.Parent end
                if ancestor and ancestor.Parent == selected.generators then
                    nextGeneratorDiagnostic("Generator stat/ActivePlayer added late: " .. descendant:GetFullName())
                    monitorGenerator(ancestor)
                end
            end
        end))

        table.insert(GeneratorWatch.mapConnections, selected.generators.ChildAdded:Connect(function(generator)
            generatorDiagnostic("New generator added: " .. generator.Name)
            monitorGenerator(generator)
            task.defer(bindNextGenerator)
        end))
        table.insert(GeneratorWatch.mapConnections, selected.generators.ChildRemoved:Connect(function(generator)
            local record = GeneratorWatch.generatorRecords[generator]
            if record then
                disconnectConnections(record.connections)
                if record.valueConnection then
                    record.valueConnection:Disconnect()
                end
                GeneratorWatch.generatorRecords[generator] = nil
                generatorDiagnostic("Generator removed: " .. generator.Name)
                task.defer(bindNextGenerator)
            end
        end))

        generatorDiagnostic("Found " .. selected.total .. " generators in " .. selected.map.Name)
        task.defer(bindNextGenerator)
    end)
end

local function scheduleGeneratorMapScan(reason)
    GeneratorWatch.scanId += 1
    local scanId = GeneratorWatch.scanId
    clearGeneratorMap()
    generatorDiagnostic("Map scan scheduled in 6 seconds: " .. reason)
    startGeneratorMapScan(reason, scanId)
end

local function bindGeneratorCurrentRoom(folder)
    disconnectConnections(GeneratorWatch.currentRoomConnections)
    clearGeneratorMap()
    GeneratorWatch.scanId += 1
    GeneratorWatch.folder = folder
    if not folder then
        generatorDiagnostic("CurrentRoom does not exist")
        return
    end

    table.insert(GeneratorWatch.currentRoomConnections, folder.ChildAdded:Connect(function(child)
        if child:IsA("Model") then
            scheduleGeneratorMapScan("map Model added: " .. child.Name)
        end
    end))
    table.insert(GeneratorWatch.currentRoomConnections, folder.ChildRemoved:Connect(function(child)
        if child:IsA("Model") then
            scheduleGeneratorMapScan("map Model removed: " .. child.Name)
        end
    end))
    scheduleGeneratorMapScan("CurrentRoom bound")
end

getCharacterRoot = function()
    local character = localplayer.Character
    return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("RootPart"))
end

local function getGeneratorTarget(generator)
    if not generator then return nil end
    local machine = generator:FindFirstChild("BaseMachine")
    local chamber = machine and machine:FindFirstChild("ChamberPart")
    if chamber and chamber:IsA("BasePart") then return chamber end
    if generator:IsA("Model") then
        local part = generator.PrimaryPart or generator:FindFirstChildWhichIsA("BasePart", true)
        if part then return part end
    end
    return nil
end

local function generatorIsComplete(generator)
    local stats = generator and generator:FindFirstChild("Stats")
    local completed = stats and stats:FindFirstChild("Completed")
    if completed and completed:IsA("BoolValue") and completed.Value then return true end
    local current = stats and stats:FindFirstChild("CurrentAmount")
    local required = stats and stats:FindFirstChild("RequiredAmount")
    return current and required and current:IsA("ValueBase") and required:IsA("ValueBase") and tonumber(current.Value) and tonumber(required.Value) and tonumber(current.Value) >= tonumber(required.Value) or false
end

local function getOrderedGenerators()
    local folder = GeneratorWatch.map and GeneratorWatch.map:FindFirstChild("Generators")
    if not folder then return {} end
    return folder:GetChildren()
end

local function getNextIncompleteGenerator(afterGenerator)
    local list = getOrderedGenerators()
    local startIndex = 1
    if afterGenerator then
        for index, generator in ipairs(list) do
            if generator == afterGenerator then
                startIndex = index + 1 
                break
            end
        end
    end
    for index = startIndex, #list do
        if not generatorIsComplete(list[index]) then return list[index] end
    end
    for _, generator in ipairs(list) do
        if not generatorIsComplete(generator) then return generator end
    end
    return nil
end

local function getLocalActiveGenerator()
    for generator, record in pairs(GeneratorWatch.generatorRecords) do
        local valueObject = record.activePlayer
        if valueObject and valueObject.Parent then
            local value = valueObject.Value
            if isLocalPlayerValue(value) then
                return generator
            end
        end
    end
    return nil
end

local function getPreSpottedGenerator()
    if workingGenerator and GeneratorWatch.generatorRecords[workingGenerator] then return workingGenerator end
    return getLocalActiveGenerator()
end

local function findGeneratorFromMachineInteraction()
    local playersFolder = workspace:FindFirstChild("InGamePlayers")
    local character = playersFolder and playersFolder:FindFirstChild(localplayer.Name)
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("RootPart"))
    if not root then return nil end
    local closestGenerator
    local closestDistance = 18
    for generator in pairs(GeneratorWatch.generatorRecords) do
        local target = getGeneratorTarget(generator)
        if target then
            local distance = (root.Position - target.Position).Magnitude
            if distance < closestDistance then
                closestGenerator = generator
                closestDistance = distance
            end
        end
    end
    return closestGenerator
end

local function nearbyMonsterDistance(maxDistance, origin)
    local root = getCharacterRoot()
    local monsters = GeneratorWatch.map and GeneratorWatch.map:FindFirstChild("Monsters")
    if not root or not monsters then return nil end
    origin = origin or root.Position
    local nearest
    for _, monster in ipairs(monsters:GetChildren()) do
        if monster:IsA("Model") and monster.Name ~= "RodgerMonster" and monster.Name ~= "RazzleDazzleMonster" then
            local part = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local distance = (origin - part.Position).Magnitude
                if distance <= maxDistance and (not nearest or distance < nearest) then nearest = distance end
            end
        end
    end
    return nearest
end

local function teleportAboveGenerator(generator)
    local root = getCharacterRoot()
    local target = getGeneratorTarget(generator)
    if not root or not target then return false end
    root.CFrame = target.CFrame + Vector3.new(0, 100, 0)
    local characterRoot = localplayer.Character and localplayer.Character:FindFirstChild("RootPart")
    if characterRoot and characterRoot:IsA("BasePart") then characterRoot.CFrame = root.CFrame end
    return true
end

local function tweenBackToSavedPosition()
    if not autoHideSavedCFrame then return end
    local root = getCharacterRoot()
    if not root then return end
    if autoHideTween then autoHideTween:Cancel() end
    autoHideTween = TweenService:Create(root, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = autoHideSavedCFrame})
    local characterRoot = localplayer.Character and localplayer.Character:FindFirstChild("RootPart")
    if characterRoot and characterRoot:IsA("BasePart") and characterRoot ~= root then
        local syncTween = TweenService:Create(characterRoot, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = autoHideSavedCFrame})
        syncTween:Play()
    end
    autoHideTween:Play()
    autoHideTween.Completed:Once(function()
        autoHideTween = nil
        autoHideSavedCFrame = nil
        autoHidePositionedGenerator = nil
        autoHideActive = false
        autoHideWasSpotted = false
    end)
end

local function monitorAutoHideReturn(generator, loopId)
    task.spawn(function()
        local clearSince
        while AutoHideEnabled and autoHideActive and loopId == autoHideLoopId and generator.Parent do
            task.wait(0.25)
            if not AutoHideEnabled or not autoHideActive or loopId ~= autoHideLoopId then break end
            local activeNow = getLocalActiveGenerator() == generator or workingGenerator == generator
            local waitingForNext = NextGeneratorEnabled and prepositionSourceGenerator == generator and prepositionedGenerator ~= nil
            local monstersFolder = GeneratorWatch.map and GeneratorWatch.map:FindFirstChild("Monsters")
            local savedPosition = autoHideSavedCFrame and autoHideSavedCFrame.Position
            local monsterNearSavedPosition = monstersFolder and savedPosition and nearbyMonsterDistance(60, savedPosition) or nil
            local currentRoot = getCharacterRoot()
            local monsterNearCurrentPosition = monstersFolder and currentRoot and nearbyMonsterDistance(60, currentRoot.Position) or nil
            local areaClear = not monstersFolder or (not monsterNearSavedPosition and not monsterNearCurrentPosition)
            if areaClear then
                clearSince = clearSince or os.clock()
            else
                clearSince = nil
            end

            if generatorIsComplete(generator) and NextGeneratorEnabled and not waitingForNext then
                nextGeneratorDiagnostic("AutoHide: completed while hidden; advancing to next generator")
                teleportToNextGenerator(generator)
                autoHideLoopId += 1
                autoHideSavedCFrame = nil
                autoHidePositionedGenerator = nil
                autoHideActive = false
                autoHideWasSpotted = false
                break
            end

            local areaStayedClear = areaClear and clearSince and os.clock() - clearSince >= 1.5
            if areaStayedClear and ((autoHideWasSpotted and not spottedDuringPreposition) or (generatorIsComplete(generator) and not NextGeneratorEnabled and not activeNow and not waitingForNext)) then
                nextGeneratorDiagnostic("AutoHide: area clear; tweening back down | spotted=" .. tostring(autoHideWasSpotted) .. " | completed=" .. tostring(generatorIsComplete(generator)) .. " | active=" .. tostring(activeNow))
                tweenBackToSavedPosition()
                break
            end
        end
    end)
end

startPreHide = function(generator)
    if not AutoHideEnabled or not generator or autoHidePositionedGenerator == generator then return end
    local root = getCharacterRoot()
    if not root then return end
    if autoHideActive and autoHideSavedCFrame then
        if teleportAboveGenerator(generator) then
            autoHidePositionedGenerator = generator
            nextGeneratorDiagnostic("AutoHide: pre-hide moved above active generator " .. generator:GetFullName())
        end
        return
    end
    autoHideSavedCFrame = root.CFrame
    autoHideActive = true
    autoHideWasSpotted = false
    autoHideLoopId += 1
    local loopId = autoHideLoopId
    task.spawn(function()
        task.wait(1)
        if not AutoHideEnabled or not autoHideActive or loopId ~= autoHideLoopId or not generator.Parent then return end
        if not teleportAboveGenerator(generator) then
            autoHideSavedCFrame = nil
            autoHideActive = false
            return
        end
        autoHidePositionedGenerator = generator
        print("[AutoHide] Pre-hide started after 1 second above " .. generator:GetFullName())
        monitorAutoHideReturn(generator, loopId)
    end)
end

local function onSpotted()
    if not AutoHideEnabled then return end
    local root = getCharacterRoot()
    local generator = getPreSpottedGenerator()
    if not root or not generator then return end
    if AntiMissclickEnabled and AntiMissclickStoppedGenerators[generator] then
        nextGeneratorDiagnostic("AutoHide: ignored spotted event for generator canceled by Anti Missclick")
        return
    end
    local wasPrepositioning = NextGeneratorEnabled and prepositionSourceGenerator == generator and prepositionedGenerator ~= nil
    if not autoHideSavedCFrame then autoHideSavedCFrame = root.CFrame end
    autoHideActive = true
    autoHideWasSpotted = true
    autoHideLoopId += 1
    local loopId = autoHideLoopId
    if autoHidePositionedGenerator ~= generator then
        if not teleportAboveGenerator(generator) then
            nextGeneratorDiagnostic("AutoHide: spotted event received but teleport above generator failed")
            return
        end
        autoHidePositionedGenerator = generator
    end
    spottedDuringPreposition = wasPrepositioning
    print("[AutoHide] Spotted received | generator=" .. generator:GetFullName() .. " | prepositioning=" .. tostring(wasPrepositioning) .. " | alreadyAboveGenerator=" .. tostring(autoHidePositionedGenerator == generator))
    monitorAutoHideReturn(generator, loopId)
end

local function bindSpottedEvent()
    disconnectConnections(AutoHideConnections)
    local storyEvents = game:GetService("ReplicatedStorage"):FindFirstChild("StoryEvents")
    local spotted = storyEvents and storyEvents:FindFirstChild("Spotted")
    if spotted and spotted:IsA("RemoteEvent") then
        table.insert(AutoHideConnections, spotted.OnClientEvent:Connect(onSpotted))
    else
        generatorDiagnostic("StoryEvents.Spotted RemoteEvent not found; AutoHide cannot react to spotted events")
    end
end

local function setAutoHide(state)
    AutoHideEnabled = state
    if state then
        bindSpottedEvent()
        autoHideActive = false
        autoHideSavedCFrame = nil
        autoHidePositionedGenerator = nil
    else
        disconnectConnections(AutoHideConnections)
        autoHideLoopId += 1
        if autoHideActive and autoHideSavedCFrame then
            local root = getCharacterRoot()
            if root then
                if autoHideTween then
                    autoHideTween:Cancel()
                    autoHideTween = nil
                end
                root.CFrame = autoHideSavedCFrame
            end
        end
        autoHideActive = false
        autoHideSavedCFrame = nil
        autoHidePositionedGenerator = nil
    end
end

teleportToNextGenerator = function(afterGenerator)
    local generator = getNextIncompleteGenerator(afterGenerator)
    if not generator then
        local elevators = workspace:FindFirstChild("Elevators")
        local elevator = elevators and elevators:FindFirstChild("Elevator")
        local forceZone = elevator and elevator:FindFirstChild("ForceZone")
        local root = getCharacterRoot()
        if forceZone and forceZone:IsA("BasePart") and root then root.CFrame = forceZone.CFrame end
        return
    end
    local nextTarget = getGeneratorTarget(generator)
    if nearbyMonsterDistance(40, nextTarget and nextTarget.Position) then
        teleportAboveGenerator(generator)
        local target = nextTarget
        if target then
            task.spawn(function()
                while NextGeneratorEnabled and target.Parent and nearbyMonsterDistance(40, target.Position) do
                    task.wait(0.25)
                end
                if NextGeneratorEnabled and target.Parent then
                    local root = getCharacterRoot()
                    if root then root.CFrame = target.CFrame end
                end
            end)
        end
    else
        local root = getCharacterRoot()
        local target = getGeneratorTarget(generator)
        if root and target then root.CFrame = target.CFrame end
    end
end

updateNextGeneratorState = function(generator)
    if not NextGeneratorEnabled then
        nextGeneratorDiagnostic("Progress check ignored: toggle disabled")
        return
    end
    if not generator then
        nextGeneratorDiagnostic("Progress check ignored: no generator")
        return
    end
    if generatorIsComplete(generator) then
        nextGeneratorDiagnostic("Progress check: generator already complete | " .. generator:GetFullName())
        return
    end
    local activeGenerator = getLocalActiveGenerator()
    if activeGenerator == generator then
        workingGenerator = generator
    elseif activeGenerator == nil and workingGenerator ~= generator then
        local nearbyGenerator = findGeneratorFromMachineInteraction()
        if nearbyGenerator ~= generator then
            nextGeneratorDiagnostic("Progress check ignored: no local ActivePlayer and player is not near candidate | candidate=" .. generator:GetFullName() .. " | nearby=" .. (nearbyGenerator and nearbyGenerator:GetFullName() or "nil"))
            return
        end
        workingGenerator = generator
        nextGeneratorDiagnostic("Working generator inferred from local character proximity because ActivePlayer was nil | " .. generator:GetFullName())
    elseif activeGenerator and activeGenerator ~= generator then
        nextGeneratorDiagnostic("Progress check ignored: another generator is active | candidate=" .. generator:GetFullName() .. " | active=" .. activeGenerator:GetFullName())
        return
    end
    local stats = generator:FindFirstChild("Stats")
    local current = stats and stats:FindFirstChild("CurrentAmount")
    local required = stats and stats:FindFirstChild("RequiredAmount")
    local currentAmount = current and tonumber(current.Value)
    local requiredAmount = required and tonumber(required.Value)
    nextGeneratorDiagnostic("Progress read | generator=" .. generator:GetFullName() .. " | current=" .. tostring(currentAmount) .. " | required=" .. tostring(requiredAmount) .. " | percent=" .. tostring(currentAmount and requiredAmount and requiredAmount > 0 and (currentAmount / requiredAmount * 100) or nil))
    if not currentAmount or not requiredAmount or requiredAmount <= 0 then
        nextGeneratorDiagnostic("Progress check stopped: missing/non-numeric amounts or RequiredAmount <= 0")
        return
    end
    if currentAmount / requiredAmount < 0.9 then
        nextGeneratorDiagnostic("Progress check stopped: below 90% threshold")
        return
    end
    if prepositionSourceGenerator == generator and prepositionedGenerator and prepositionedGenerator.Parent then
        local nextTarget = getGeneratorTarget(prepositionedGenerator)
        local monsterDistance = nextTarget and nearbyMonsterDistance(40, nextTarget.Position)
        if nextTarget and not monsterDistance and not autoHideActive then
            local root = getCharacterRoot()
            if root then
                nextGeneratorDiagnostic("Monster cleared from preposition target; teleporting down | target=" .. prepositionedGenerator:GetFullName())
                root.CFrame = nextTarget.CFrame
            end
        end
        return
    end
    local nextGenerator = getNextIncompleteGenerator(generator)
    if not nextGenerator then
        nextGeneratorDiagnostic("No incomplete generator found after 90% | source=" .. generator:GetFullName())
        return
    end
    prepositionSourceGenerator = generator
    prepositionedGenerator = nextGenerator
    local target = getGeneratorTarget(nextGenerator)
    local monsterDistance = target and nearbyMonsterDistance(40, target.Position)
    nextGeneratorDiagnostic("PREPOSITION TRIGGERED | source=" .. generator:GetFullName() .. " | next=" .. nextGenerator:GetFullName() .. " | monsterDistance=" .. tostring(monsterDistance) .. " | target=" .. tostring(target and target:GetFullName() or "nil"))
    if monsterDistance then
        nextGeneratorDiagnostic("Monster within 40 studs of next generator; teleporting above it")
        teleportAboveGenerator(nextGenerator)
    else
        local root = getCharacterRoot()
        if root and target then
            nextGeneratorDiagnostic("No monster near next generator; teleporting to target position")
            root.CFrame = target.CFrame
        else
            nextGeneratorDiagnostic("Preposition failed: missing character root or generator target")
        end
    end
end

bindNextGenerator = function()
    disconnectConnections(NextGeneratorConnections)
    nextGeneratorDiagnostic("Binding stat events | toggle=" .. tostring(NextGeneratorEnabled) .. " | monitoredGenerators=" .. tostring(#getOrderedGenerators()) .. " | working=" .. (workingGenerator and workingGenerator:GetFullName() or "nil"))
    if not NextGeneratorEnabled then return end
    for generator, record in pairs(GeneratorWatch.generatorRecords) do
        updateNextGeneratorState(generator)
        local stats = generator:FindFirstChild("Stats")
        local completed = stats and stats:FindFirstChild("Completed")
        local current = stats and stats:FindFirstChild("CurrentAmount")
        local required = stats and stats:FindFirstChild("RequiredAmount")
        local alreadyHandled = generatorIsComplete(generator)
        local function checkCompletion()
            nextGeneratorDiagnostic("Completion event | generator=" .. generator:GetFullName() .. " | completed=" .. tostring(generatorIsComplete(generator)) .. " | alreadyHandled=" .. tostring(alreadyHandled) .. " | working=" .. tostring(workingGenerator == generator))
            if NextGeneratorEnabled and not alreadyHandled and generatorIsComplete(generator) then
                alreadyHandled = true
                if workingGenerator == generator or prepositionSourceGenerator == generator or spottedDuringPreposition then
                    nextGeneratorDiagnostic("Current generator completed; advancing | " .. generator:GetFullName())
                    teleportToNextGenerator(generator)
                    if workingGenerator == generator then workingGenerator = nil end
                    prepositionSourceGenerator = nil
                    prepositionedGenerator = nil
                    if spottedDuringPreposition then
                        autoHideLoopId += 1
                        autoHideActive = false
                        autoHideSavedCFrame = nil
                    end
                    spottedDuringPreposition = false
                end
            elseif NextGeneratorEnabled then
                updateNextGeneratorState(generator)
            end
        end
        local function connectCompletion(signal)
            local eventConnection = signal:Connect(checkCompletion)
            table.insert(NextGeneratorConnections, eventConnection)
        end
        if completed and completed:IsA("BoolValue") then
            connectCompletion(completed:GetPropertyChangedSignal("Value"))
        end
        if current and current:IsA("ValueBase") then
            connectCompletion(current:GetPropertyChangedSignal("Value"))
        end
        if required and required:IsA("ValueBase") then
            connectCompletion(required:GetPropertyChangedSignal("Value"))
        end
    end
end

table.insert(GeneratorWatch.workspaceConnections, workspace.ChildAdded:Connect(function(child)
    if child.Name == "CurrentRoom" and child:IsA("Folder") then
        bindGeneratorCurrentRoom(child)
    end
end))
table.insert(GeneratorWatch.workspaceConnections, workspace.ChildRemoved:Connect(function(child)
    if child == GeneratorWatch.folder then
        bindGeneratorCurrentRoom(nil)
    end
end))

local initialCurrentRoom = workspace:FindFirstChild("CurrentRoom")
if initialCurrentRoom and initialCurrentRoom:IsA("Folder") then
    bindGeneratorCurrentRoom(initialCurrentRoom)
else
    generatorDiagnostic("CurrentRoom does not exist")
end

local function stopGeneratorWatch()
    GeneratorWatch.stopped = true
    GeneratorWatch.scanId += 1
    disconnectConnections(GeneratorWatch.workspaceConnections)
    disconnectConnections(GeneratorWatch.currentRoomConnections)
    setAutoHide(false)
    setAntiMissclick(false)
    setStatusTagsEnabled(false)
    clearGeneratorMap()
    GeneratorWatch.folder = nil
    NextGeneratorEnabled = false
end

gui:SetToggleKey(Enum.KeyCode.RightControl)

-- // GUI STOPED PROTOCOL // --
local deathProtocolDone = false
function gui_death_protocol()
    if deathProtocolDone then return end
    deathProtocolDone = true
    print("Stoping script...")
    stopGeneratorWatch()
    setAutoQTE(false)
    autoQTEEnabled = false

    fbenabled = false
    applyFullbright(false)
    print("Disabled Fullbright")

    localplayer.CameraMinZoomDistance = originalCameraMinZoomDistance
    localplayer.CameraMaxZoomDistance = originalCameraMaxZoomDistance
    for humanoid, jumpHeight in pairs(originalJumpHeights) do
        if humanoid and humanoid.Parent then humanoid.JumpHeight = jumpHeight end
    end
    if characterAddedConnection then
        characterAddedConnection:Disconnect()
        characterAddedConnection = nil
    end

    print("Disabled zooms and jump")

    tpwalkEnabled = false
    if tpwalkConnection then
        tpwalkConnection:Disconnect()
        tpwalkConnection = nil
    end
    print("Disabled tpwalk")
    noclipenabled = false
    stopNoclipWatch()
    restoreAllNoclip()
    if noclipStoreCreated and noclipStore and noclipStore.Parent then
        noclipStore:Destroy()
        noclipStore = nil
    end
    local taggedRooms = CS:GetTagged("CGH_NoCliped")
    for _, room in ipairs(taggedRooms) do
        CS:RemoveTag(room, "CGH_NoCliped")
    end
    table.clear(noclipCompletedRooms)
    print(("Disabled Noclip apply"))
    stopVisualWatch()
    ESPService.Destroy()
    print("Disabled esp")
    print("Stoped.")
end

gui:OnDestroy(
    function()
        gui_death_protocol()
    end
)

local function buildInterface()
local Player = gui:Tab({Title = "Player", Icon = "user-round"})
local Visual = gui:Tab({Title = "Visuals", Icon = "scan-eye"})
local Gameplay = gui:Tab({Title = "Generators", Icon = "bolt"})
local Misc = gui:Tab({Title = "Misc", Icon = "sliders-horizontal"})
local Settings = gui:Tab({Title = "Settings", Icon = "settings-2"})

Player:Paragraph({
    Title = "Player",
    Desc = "Opções de personagem, movimento e câmera.",
})
Player:Space()

Visual:Paragraph({
    Title = "Visuals",
    Desc = "Recursos visuais da sala e preferências de cores.",
})
Visual:Space()

Gameplay:Paragraph({
    Title = "Generators",
    Desc = "Assistências relacionadas à partida e aos geradores.",
})
Gameplay:Space()

Settings:Paragraph({
    Title = "Settings",
    Desc = "Preferências da interface, personalização e configurações salvas.",
})
Settings:Space()

Misc:Paragraph({
    Title = "Misc",
    Desc = "Opções leves para ajustar elementos visuais e reduzir trabalho em dispositivos móveis.",
})
Misc:Space()

local function applyVisualColors()
    for instance, record in pairs(VisualWatch.records) do
        if record.kind == "monster" or record.kind == "generator" then
            local kind = record.kind
            removeVisualESP(instance)
            applyVisualESP(instance, kind)
        end
    end
end

local function applySpecialItemColors()
    for instance, record in pairs(VisualWatch.records) do
        if record.kind == "item" then
            removeVisualESP(instance)
            applyVisualESP(instance, "item")
        end
    end
end

local function getThemeNames()
    local names = {}
    local ok, themes = pcall(function() return WindUI:GetThemes() end)
    if ok and type(themes) == "table" then
        for key, theme in pairs(themes) do
            local name = type(theme) == "table" and (theme.Name or theme.name) or nil
            if type(theme) == "string" then name = theme end
            if type(name) ~= "string" and type(key) == "string" then name = key end
            if type(name) == "string" then table.insert(names, name) end
        end
    end
    if #names == 0 then
        names = {"Dark", "Light"}
    end
    table.sort(names)
    return names
end

local function setSpecialItemColor(itemName, color)
    if not special_items[itemName] then return end
    special_items[itemName].color = color
    applySpecialItemColors()
end

local function setSpecialItemNotify(itemName, enabled)
    if not special_items[itemName] then return end
    special_items[itemName].notify = enabled == true
end

local SpecialItemColorPicker

-- toggles
local ToggleMinZoom = Player:Toggle({
    Title = "Sem zoom maximo",
    Icon = "zoom-in",
    Callback = function(state)
        if state then
            localplayer.CameraMinZoomDistance = 0
        else
            localplayer.CameraMinZoomDistance = 2.5
        end
    end
})

local ToggleMaxZoom = Player:Toggle({
    Title = "Sem zoom minimo.",
    Icon = "zoom-out",
    Callback = function(state)
        if state then
            localplayer.CameraMaxZoomDistance = bignumb
        else
            localplayer.CameraMaxZoomDistance = 15
        end
    end
})
Player:Space()

local Jump = Player:Toggle({
    Title = "Ativar Pulo",
    Icon = "arrow-up",
    Desc = "Ativa ou desativa o pulo do personagem.",
    Callback = function(state)
        local character = localplayer.Character
        local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")

        if humanoid then
            if state then
                humanoid.JumpHeight = 13
            else
                humanoid.JumpHeight = 0
            end
        end
    end
})

local FB = Visual:Toggle({
    Title = "Fullbright",
    Icon = "sun",
    Desc = "Aumenta a iluminação para melhorar a visibilidade em áreas escuras.",
    Callback = function(state)
        fbenabled = state
        applyFullbright(state)
    end,
})
Visual:Space()

local TpwalkToggle = Player:Toggle({
    Title = "Stamina Infinita",
    Icon = "zap",
    Desc = "Mantém o recurso de movimento associado à velocidade ativo.",
    Callback = function(state)
        if state then
            tpwalkEnabled = true
        else
            tpwalkEnabled = false
        end
    end
}) 

local TpwalkSlider = Player:Slider({
    Title = "Velocidade",
    Desc = "Ajusta a intensidade da assistência de movimento.",
    Value = {
        Min = 0.1,
        Max = 5,
        Default =  1
    },
    Step = 0.1,
    Callback = function(value)
        tpwalkSpeed = value
    end
})

local Noclip = Player:Toggle({
    Title = "NoClip",
    Icon = "ghost",
    Desc = "Desativa a colisão das hitboxes da sala atual.",
    Callback = function(state)
        noclipenabled = state
        if state then
            local folder = workspace:FindFirstChild("CurrentRoom")
            local room = folder and folder:FindFirstChildOfClass("Model")
            if room then task.defer(applyNoclipToRoom, room) end
        else
            restoreAllNoclip()
        end
    end
})
Player:Space()

Player:Paragraph({
    Title = "Função descontinuada",
    Desc = "O NoClip Agressivo permanece bloqueado até ser liberado em Settings.",
})

local Noclip_AGR = Player:Toggle({
    Title = "NoClip Agressivo",
    Icon = "shield",
    Desc = "Move os objetos das hitboxes para o ReplicatedStorage enquanto o noclip está ativo.",
    Type = "Checkbox",
    Value = false,
    Locked = true,
    Callback = function(state)
        noclipagressivemode = state
        if not noclipenabled then return end
        local folder = workspace:FindFirstChild("CurrentRoom")
        local room = folder and folder:FindFirstChildOfClass("Model")
        if room then
            restoreAllNoclip()
            task.delay(0.1, function()
                if noclipenabled and room.Parent then applyNoclipToRoom(room) end
            end)
        end
    end
})

Noclip_AGR:Lock()

local ESPGroup = Visual:Group({})
local ESP_Monster = ESPGroup:Toggle({
    Title = "ESP Twisted",
    Icon = "skull",
    Callback = function(state)
        MonsESP = state
        f_monesp(state)
    end
})

ESPGroup:Space()

local ESP_Generators = ESPGroup:Toggle({
    Title = "ESP Geradores",
    Icon = "cpu",
    Callback = function(state)
        GenESP = state
        f_genesp(state)
    end
})
Visual:Space()
local ESP_Items = Visual:Toggle({
    Title = "ESP Itens",
    Icon = "package",
    Desc = "Mostra itens com highlight e nome; Bandage e HealthKit geram notificação.",
    Callback = function(state)
        f_itemsesp(state)
    end
})

Visual:Space()

local MonsterColorPicker = Visual:Colorpicker({
    Title = "Cor dos monstros",
    Desc = "Cor de preenchimento do ESP dos monstros.",
    Default = espColors.Monster,
    Flag = "ESP_MonsterColor",
    Callback = function(color)
        espColors.Monster = color
        applyVisualColors()
    end,
})

local GeneratorColorPicker = Visual:Colorpicker({
    Title = "Cor dos geradores",
    Desc = "Cor de preenchimento do ESP dos geradores.",
    Default = espColors.Generator,
    Flag = "ESP_GeneratorColor",
    Callback = function(color)
        espColors.Generator = color
        applyVisualColors()
    end,
})

local AutoQTEToggle
AutoQTEToggle = Gameplay:Toggle({
    Title = "AutoQTE",
    Icon = "target",
    Desc = "Completa o QTE enquanto ligado e restaura o callback anterior ao desligar.",
    Callback = function(state)
        setAutoQTE(state)
    end
}) 

local AutoHideToggle = Gameplay:Toggle({
    Title = "AutoHide ao ser visto",
    Icon = "eye",
    Desc = "Só reage ao Spotted se você estava usando um gerador; sobe acima dele e retorna quando a área ficar livre.",
    Callback = function(state)
        setAutoHide(state)
    end
})


Misc:Toggle({
    Title = "Desligar boxes",
    Icon = "square-x",
    Desc = "Oculta as caixas do ESP para reduzir elementos desenhados.",
    Value = false,
    Flag = "Misc_DisableBoxes",
    Callback = function(disabled)
        setESPBoxesEnabled(not disabled)
    end,
})

Misc:Dropdown({
    Title = "Modo de drawing",
    Desc = "Tudo mostra todos os desenhos; Semi mostra desenhos apenas para itens especiais; Nada desativa os desenhos. Highlights continuam ativos.",
    Values = {"Tudo", "Semi", "Nada"},
    Value = "Tudo",
    Flag = "Misc_DrawingMode",
    Callback = function(mode)
        if type(mode) == "string" then setESPDisplayMode(mode) end
    end,
})
Misc:Space()
Misc:Toggle({
    Title = "Ocultar FPS",
    Icon = "gauge",
    Desc = "Oculta somente a tag de FPS.",
    Value = false,
    Flag = "Misc_HideFPS",
    Callback = function(hidden)
        setFPSTagVisible(not hidden)
    end,
})

Misc:Toggle({
    Title = "Ocultar timer",
    Icon = "clock",
    Desc = "Oculta somente a tag de tempo de sessao.",
    Value = false,
    Flag = "Misc_HideTimer",
    Callback = function(hidden)
        setPlaytimeTagVisible(not hidden)
    end,
})

local NextGeneratorToggle = Gameplay:Toggle({
    Title = "Next Generator",
    Icon = "arrow-right",
    Desc = "Aos 90% do gerador em uso, prepara o próximo. Se for visto durante a preparação, espera terminar o atual antes de descer no próximo.",
    Callback = function(state)
        NextGeneratorEnabled = state
        nextGeneratorDiagnostic("Toggle changed | enabled=" .. tostring(state))
        if not state then
            prepositionSourceGenerator = nil
            prepositionedGenerator = nil
            spottedDuringPreposition = false
        end
        if state and GeneratorWatch.map then
            for generator in pairs(GeneratorWatch.generatorRecords) do
                local stats = generator:FindFirstChild("Stats")
                local activePlayer = stats and stats:FindFirstChild("ActivePlayer")
                local current = stats and stats:FindFirstChild("CurrentAmount")
                local required = stats and stats:FindFirstChild("RequiredAmount")
                local completed = stats and stats:FindFirstChild("Completed")
                nextGeneratorDiagnostic("Toggle scan | generator=" .. generator:GetFullName() .. " | activeClass=" .. tostring(activePlayer and activePlayer.ClassName) .. " | activeValue=" .. valueDescription(activePlayer and activePlayer.Value) .. " | current=" .. tostring(current and current.Value) .. " | required=" .. tostring(required and required.Value) .. " | completed=" .. tostring(completed and completed.Value))
            end
        end
        bindNextGenerator()
    end
})
Gameplay:Space()
local AntiMissclickToggle = Gameplay:Toggle({
    Title = "Anti Missclick",
    Icon = "ban",
    Type = "Checkbox",
    Value = false,
    Locked = true,
    Desc = "Descontinuado. Pode conflitar com Next Generator e AutoHide; libere funcoes descontinuadas em Settings para desbloquear.",
    Callback = function(state)
        setAntiMissclick(state)
    end
})
AntiMissclickToggle:Lock()

local currentTheme = "Dark"
pcall(function()
    if WindUI.GetCurrentTheme then currentTheme = WindUI:GetCurrentTheme() or currentTheme end
end)

local themeOptions = getThemeNames()
if table.find(themeOptions, currentTheme) == nil then table.insert(themeOptions, currentTheme) end
local ThemeDropdown = Settings:Dropdown({
    Title = "Tema da interface",
    Desc = "Escolha um dos temas disponíveis no WindUI.",
    Values = getThemeNames(),
    Value = currentTheme,
    Flag = "Settings_Theme",
    Callback = function(themeName)
        if type(themeName) ~= "string" then return end
        currentTheme = themeName
        pcall(function() WindUI:SetTheme(themeName) end)
    end,
})

local specialItemOptions = getSpecialItemNames()
local pendingSpecialItem = specialItemOptions[1]
local pendingSpecialColor = special_items[pendingSpecialItem] and special_items[pendingSpecialItem].color or colors.white
local SpecialItemNotifyToggle

Settings:Space()

local SpecialItemDropdown = Settings:Dropdown({
    Title = "Item especial",
    Desc = "Selecione qual item terá a cor alterada pelo seletor abaixo.",
    Values = specialItemOptions,
    Value = pendingSpecialItem,
    Flag = "Settings_SpecialItemSelection",
    Callback = function(itemName)
        if type(itemName) == "string" and special_items[itemName] then
            pendingSpecialItem = itemName
            pendingSpecialColor = special_items[itemName].color
            if SpecialItemColorPicker then SpecialItemColorPicker:Set(pendingSpecialColor) end
            if SpecialItemNotifyToggle then SpecialItemNotifyToggle:Set(special_items[itemName].notify) end
        end
    end,
})

SpecialItemNotifyToggle = Settings:Toggle({
    Title = "Notificar ao encontrar",
    Icon = "bell",
    Desc = "Ativa ou desativa a notificacao para o item selecionado.",
    Type = "Checkbox",
    Value = special_items[pendingSpecialItem] and special_items[pendingSpecialItem].notify or false,
    Flag = "Settings_NotifySelectedSpecialItem",
    Callback = function(enabled)
        setSpecialItemNotify(pendingSpecialItem, enabled)
    end,
})

SpecialItemColorPicker = Settings:Colorpicker({
    Title = "Nova cor",
    Desc = "Escolha a cor e pressione Aplicar para atualizar o ESP deste item.",
    Default = pendingSpecialColor,
    Flag = "Settings_SpecialItemColor",
    Callback = function(color)
        pendingSpecialColor = color
    end,
})

Settings:Button({
    Title = "Aplicar cor ao item",
    Desc = "Salva a cor escolhida para o item selecionado e atualiza o ESP.",
    Icon = "paintbrush",
    Callback = function()
        if pendingSpecialItem and typeof(pendingSpecialColor) == "Color3" then
            setSpecialItemColor(pendingSpecialItem, pendingSpecialColor)
            WindUI:Notify({Title = "ESP de itens", Content = "Cor aplicada a " .. pendingSpecialItem .. ".", Icon = "paintbrush", Duration = 3})
        end
    end,
})

local function getConfigManager()
    return gui.ConfigManager
end

local configManager = getConfigManager()
local registeredConfigs = {}
local EditConfigDropdown
local selectedConfigName
if configManager and configManager.Init then
    pcall(function() configManager:Init(gui) end)
end
Settings:Toggle({
    Title = "Transparência da janela",
    Icon = "panels-top-left",
    Desc = "Alterne o modo transparente da interface.",
    Value = false,
    Flag = "Settings_WindowTransparency",
    Callback = function(enabled)
        gui:ToggleTransparency(enabled)
    end,
})

Settings:Space()
Settings:Paragraph({Title = "Criar configuração", Desc = "Dê um nome para criar uma configuração com as preferências atuais."})

local ConfigNameInput = "default"
Settings:Input({
    Title = "Nome",
    Desc = "Nome da nova configuração.",
    Placeholder = "default",
    Value = "default",
    Callback = function(value)
        if type(value) == "string" then
            value = value:gsub("[^%w_%-]", "")
            if value ~= "" then ConfigNameInput = value end
        end
    end,
})

local function configNames()
    if not configManager then return {} end
    local ok, entries = pcall(function() return configManager:AllConfigs() end)
    if not ok or type(entries) ~= "table" then return {} end
    local names, seen = {}, {}
    for key, entry in pairs(entries) do
        local name
        if type(entry) == "string" then
            name = entry
        elseif type(entry) == "table" then
            name = entry.Name or entry.name or entry.ConfigName or entry.FileName
        elseif type(key) == "string" and entry then
            name = key
        end
        if type(name) == "string" then
            name = name:gsub("%.json$", "")
            if not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end
    table.sort(names)
    return names
end

local function resolveConfig(name)
    if not configManager or type(name) ~= "string" or name == "" then return nil end
    if registeredConfigs[name] then return registeredConfigs[name] end
    local ok, config = pcall(function() return configManager:CreateConfig(name) end)
    if ok and config then registeredConfigs[name] = config end
    return ok and config or nil
end

local function serializeSpecialItemColors()
    local serialized = {}
    for itemName, itemSettings in pairs(special_items) do
        local color = itemSettings.color
        serialized[itemName] = string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
    end
    return serialized
end

local function serializeSpecialItemNotifications()
    local serialized = {}
    for itemName, itemSettings in pairs(special_items) do
        serialized[itemName] = itemSettings.notify == true
    end
    return serialized
end

local function restoreSpecialItemColors(config)
    if not config or not config.Get then return end
    local ok, savedColors = pcall(function() return config:Get("SpecialItemColors") end)
    if not ok or type(savedColors) ~= "table" then return end
    for itemName, colorHex in pairs(savedColors) do
        if special_items[itemName] and type(colorHex) == "string" then
            local colorOk, color = pcall(function() return Color3.fromHex(colorHex) end)
            if colorOk then special_items[itemName].color = color end
        end
    end
    applySpecialItemColors()
    pendingSpecialColor = special_items[pendingSpecialItem] and special_items[pendingSpecialItem].color or colors.white
    if SpecialItemColorPicker then SpecialItemColorPicker:Set(pendingSpecialColor) end
end

local function restoreSpecialItemNotifications(config)
    if not config or not config.Get then return end
    local ok, savedNotifications = pcall(function() return config:Get("SpecialItemNotifications") end)
    if not ok or type(savedNotifications) ~= "table" then return end
    for itemName, enabled in pairs(savedNotifications) do
        if special_items[itemName] and type(enabled) == "boolean" then
            special_items[itemName].notify = enabled
        end
    end
    if SpecialItemNotifyToggle and special_items[pendingSpecialItem] then
        SpecialItemNotifyToggle:Set(special_items[pendingSpecialItem].notify)
    end
end

Settings:Button({
    Title = "Criar e salvar",
    Desc = "Cria uma configuração nova com os valores atuais.",
    Icon = "plus",
    Callback = function()
        if table.find(configNames(), ConfigNameInput) then
            return WindUI:Notify({Title = "Configuração", Content = "Esse nome já existe. Selecione a configuração em Editar para sobrescrevê-la.", Icon = "circle-alert", Duration = 4})
        end
        local config = resolveConfig(ConfigNameInput)
        if not config then return WindUI:Notify({Title = "Configuração", Content = "Não foi possível criar a configuração.", Icon = "circle-alert", Duration = 4}) end
        local ok = pcall(function()
            if config.Set then
                config:Set("SpecialItemColors", serializeSpecialItemColors())
                config:Set("SpecialItemNotifications", serializeSpecialItemNotifications())
            end
            config:Save()
        end)
        WindUI:Notify({Title = "Configuração", Content = ok and ("Configuração '" .. ConfigNameInput .. "' criada.") or "Falha ao criar a configuração.", Icon = ok and "check" or "circle-alert", Duration = 4})
        if ok and EditConfigDropdown then
            local updatedNames = configNames()
            EditConfigDropdown:Refresh(updatedNames)
            selectedConfigName = ConfigNameInput
            EditConfigDropdown:Select(ConfigNameInput)
        end
        return nil
    end,
})

Settings:Space()
Settings:Paragraph({Title = "Editar configuração", Desc = "Escolha uma configuração existente para carregar, sobrescrever ou excluir."})

local existingConfigs = configNames()
selectedConfigName = existingConfigs[1]
EditConfigDropdown = Settings:Dropdown({
    Title = "Configuração",
    Desc = "Configurações já criadas.",
    Values = existingConfigs,
    Value = selectedConfigName,
    AllowNone = true,
    Callback = function(name)
        selectedConfigName = type(name) == "string" and name or nil
    end,
})

local function selectedConfig()
    if not selectedConfigName then
        WindUI:Notify({Title = "Configuração", Content = "Selecione uma configuração primeiro.", Icon = "circle-alert", Duration = 4})
        return nil
    end
    return resolveConfig(selectedConfigName)
end

Settings:Button({
    Title = "Carregar",
    Desc = "Aplica as preferências salvas na configuração selecionada.",
    Icon = "folder-open",
    Callback = function()
        local config = selectedConfig()
        if not config then return end
        local ok = pcall(function() config:Load() end)
        if ok then
            restoreSpecialItemColors(config)
            restoreSpecialItemNotifications(config)
        end
        WindUI:Notify({Title = "Configuração", Content = ok and ("Configuração '" .. selectedConfigName .. "' carregada.") or "Falha ao carregar.", Icon = ok and "check" or "circle-alert", Duration = 4})
    end,
})

Settings:Button({
    Title = "Salvar alterações",
    Desc = "Sobrescreve a configuração selecionada com as preferências atuais.",
    Icon = "save",
    Callback = function()
        local config = selectedConfig()
        if not config then return end
        local ok = pcall(function()
            if config.Set then
                config:Set("SpecialItemColors", serializeSpecialItemColors())
                config:Set("SpecialItemNotifications", serializeSpecialItemNotifications())
            end
            config:Save()
        end)
        WindUI:Notify({Title = "Configuração", Content = ok and ("Configuração '" .. selectedConfigName .. "' atualizada.") or "Falha ao salvar.", Icon = ok and "check" or "circle-alert", Duration = 4})
    end,
})

Settings:Button({
    Title = "Deletar configuração",
    Desc = "Exclui a configuração selecionada.",
    Icon = "trash-2",
    Callback = function()
        local config = selectedConfig()
        if not config then return end
        local deletedName = selectedConfigName
        local ok = pcall(function() config:Delete() end)
        if ok then
            registeredConfigs[deletedName] = nil
            selectedConfigName = nil
            local updatedNames = configNames()
            EditConfigDropdown:Refresh(updatedNames)
            if #updatedNames > 0 then
                selectedConfigName = updatedNames[1]
                EditConfigDropdown:Select(selectedConfigName)
            end
        end
        WindUI:Notify({Title = "Configuração", Content = ok and ("Configuração '" .. deletedName .. "' excluída.") or "Falha ao excluir.", Icon = ok and "check" or "circle-alert", Duration = 4})
    end,
})

Settings:Space()

local LegacyFeaturesToggle = Settings:Toggle({
    Title = "Habilitar funções descontinuadas",
    Icon = "flask-conical",
    Desc = "Libera NoClip Agressivo e Anti Missclick, ambos descontinuados e bloqueados por padrao.",
    Value = false,
    Flag = "Settings_LegacyFeatures",
    Callback = function(enabled)
        if Noclip_AGR == nil then return end
        if enabled then
            Noclip_AGR:Unlock()
            if Noclip_AGR.Set then Noclip_AGR:Set(false) end
            AntiMissclickToggle:Unlock()
            if AntiMissclickToggle.Set then AntiMissclickToggle:Set(false) end
        else
            if Noclip_AGR.Set then Noclip_AGR:Set(false) end
            Noclip_AGR:Lock()
            if AntiMissclickToggle.Set then AntiMissclickToggle:Set(false) end
            AntiMissclickToggle:Lock()
        end
    end,
})

end

buildInterface()
-- end
