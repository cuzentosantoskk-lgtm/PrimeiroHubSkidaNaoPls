local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Simple hub",
    Icon = 0,
    LoadingTitle = "Loading",
    LoadingSubtitle = "by UmFemboyqualquer",
    ShowText = "Rayfield",
    Theme = "Default",
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = nil
    },
    Discord = { Enabled = false, Invite = "noinvitelink", RememberJoins = true },
    KeySystem = false,
})

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

local BattleTab = Window:CreateTab("BattleAssist", 4483362458)

local nostun_conns    = {}
local nostun_charconn = nil
local DEFAULT_SPEED   = 16
local BOOST_SPEED     = 50
local BOOST_TIME      = 2

BattleTab:CreateToggle({
    Name = "NoStunImprovised",
    CurrentValue = false,
    Flag = "NoStunImprovised",
    Callback = function(enabled)
        getgenv().NoStunImprovised = enabled

        if not enabled then
            for _, c in ipairs(nostun_conns) do pcall(function() c:Disconnect() end) end
            nostun_conns = {}
            if nostun_charconn then pcall(function() nostun_charconn:Disconnect() end) nostun_charconn = nil end
            pcall(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
                if hum then hum.WalkSpeed = DEFAULT_SPEED end
            end)
            return
        end

        local function setup(char)
            local hum = char:WaitForChild("Humanoid")
            local boosting   = false
            local boostEnd   = 0
            local lastHealth = hum.Health

            local conn = hum:GetPropertyChangedSignal("Health"):Connect(function()
                if not getgenv().NoStunImprovised then return end
                local cur = hum.Health
                if cur < lastHealth then
                    boostEnd = tick() + BOOST_TIME
                    boosting = true
                end
                lastHealth = cur
            end)
            table.insert(nostun_conns, conn)

            task.spawn(function()
                while hum.Parent and getgenv().NoStunImprovised do
                    if boosting then
                        if tick() < boostEnd then
                            hum.WalkSpeed = BOOST_SPEED
                        else
                            boosting = false
                            if hum.Parent then hum.WalkSpeed = DEFAULT_SPEED end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end

        if LocalPlayer.Character then pcall(setup, LocalPlayer.Character) end
        nostun_charconn = LocalPlayer.CharacterAdded:Connect(function(char)
            if getgenv().NoStunImprovised then task.wait(0.1) pcall(setup, char) end
        end)
    end,
})

BattleTab:CreateSection("AutoBlock Settings")

local RequestSkillRemote = ReplicatedStorage:WaitForChild("@rbxts/wcs:source/networking@GlobalEvents"):WaitForChild("requestSkill")

local BLOCK_RANGE = 18
local AUTOBLOCK_COOLDOWN = 0.5
local BLOCK_DURATION = 0.35
local REACTION_DELAY = 0.3
local POST_BLOCK_CD = 0
local autoblockEnabled = false
local lastAutoBlockTime = 0
local lastPostBlock = 0
local isBlocking = false
local hookedModels = {}

BattleTab:CreateSlider({
    Name = "Block Range",
    Range = {5, 50},
    Increment = 1,
    CurrentValue = 18,
    Flag = "BlockRange",
    Callback = function(value)
        BLOCK_RANGE = value
    end,
})

BattleTab:CreateSlider({
    Name = "Block Duration",
    Range = {0.1, 2},
    Increment = 0.05,
    CurrentValue = 0.35,
    Flag = "BlockDuration",
    Callback = function(value)
        BLOCK_DURATION = value
    end,
})

BattleTab:CreateSlider({
    Name = "Post Block Cooldown",
    Range = {0, 2},
    Increment = 0.05,
    CurrentValue = 0,
    Flag = "PostBlockCD",
    Callback = function(value)
        POST_BLOCK_CD = value
    end,
})

BattleTab:CreateSlider({
    Name = "Reaction Delay",
    Range = {0, 1},
    Increment = 0.05,
    CurrentValue = 0.3,
    Flag = "ReactionDelay",
    Callback = function(value)
        REACTION_DELAY = value
    end,
})

local function doBlock()
    if not autoblockEnabled then return end
    local now = os.clock()
    if now - lastAutoBlockTime < AUTOBLOCK_COOLDOWN then return end
    if now - lastPostBlock < POST_BLOCK_CD then return end
    if isBlocking then return end
    lastAutoBlockTime = now
    isBlocking = true
    RequestSkillRemote:FireServer(unpack({{
        buffer = buffer.fromstring("\r\000\000\000General/Block\001\000\000\000\000"), blobs = {}
    }}))
    task.delay(BLOCK_DURATION, function()
        RequestSkillRemote:FireServer(unpack({{
            buffer = buffer.fromstring("\r\000\000\000General/Block\000\000\000\000\000"), blobs = {}
        }}))
        isBlocking = false
        lastPostBlock = os.clock()
    end)
end

local IGNORED_ANIMS = {
    idle=true, walk=true, run=true, sprint=true, jump=true, fall=true,
    land=true, heavy_land=true, run_land=true, run_land_backward=true,
    walk_backward=true, swim=true, swimidle=true, climb=true, sit=true,
    dance=true, dance2=true, dance3=true, cheer=true, laugh=true,
    point=true, wave=true, toollunge=true, toolnone=true, toolslash=true,
    hit_animation1=true, hit_animation2=true, hit_animation3=true,
    block_hit_animation1=true, block_hit_animation2=true, block_hit_animation3=true,
}

local function isEnemy(model)
    if model == LocalPlayer.Character then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    return true
end

local function setupEnemy(model)
    if hookedModels[model] then return end
    if not model:FindFirstChild("combatCooldown") then
        local conn
        conn = model.DescendantAdded:Connect(function(child)
            if child.Name == "combatCooldown" then
                conn:Disconnect()
                task.wait(0.1)
                setupEnemy(model)
            end
        end)
        return
    end
    if not isEnemy(model) then return end
    local hum = model:FindFirstChildWhichIsA("Humanoid", true)
    if not hum then task.delay(0.3, function() setupEnemy(model) end) return end
    local root = model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("RootPart")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
    if not root then task.delay(0.3, function() setupEnemy(model) end) return end
    hookedModels[model] = true
    local gotHit = false
    local lastHP = hum.Health
    hum.HealthChanged:Connect(function(hp)
        if hp < lastHP then gotHit = true task.delay(1, function() gotHit = false end) end
        lastHP = hp
    end)
    local function checkDist()
        local char = LocalPlayer.Character
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        if not myRoot then return false end
        return (myRoot.Position - root.Position).Magnitude <= BLOCK_RANGE
    end
    local function shouldBlock(track)
        if track.Looped then return false end
        local name = (track.Animation and track.Animation.Name or ""):lower()
        if name ~= "" and IGNORED_ANIMS[name] then return false end
        return true
    end
    task.spawn(function()
        local playingSet = {}
        while model.Parent and hum.Parent do
            if not gotHit and checkDist() and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                for _, v in pairs(model:GetDescendants()) do
                    if v:IsA("Animator") then
                        local ok, tracks = pcall(function() return v:GetPlayingAnimationTracks() end)
                        if ok and tracks then
                            for _, track in pairs(tracks) do
                                local id = tostring(track)
                                if not playingSet[id] and shouldBlock(track) then
                                    playingSet[id] = true
                                    task.delay(REACTION_DELAY, doBlock)
                                    task.delay(0.5, function() playingSet[id] = nil end)
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.15)
        end
        hookedModels[model] = nil
    end)
end

BattleTab:CreateToggle({
    Name = "AutoBlock",
    CurrentValue = false,
    Flag = "AutoBlock",
    Callback = function(enabled)
        autoblockEnabled = enabled
        if not enabled then
            hookedModels = {}
            return
        end
        task.spawn(function()
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("Model") and v:FindFirstChild("combatCooldown") then
                    pcall(setupEnemy, v)
                end
            end
        end)
        workspace.DescendantAdded:Connect(function(v)
            if not autoblockEnabled then return end
            if v.Name == "combatCooldown" and v.Parent and v.Parent:IsA("Model") then
                task.wait(0.1)
                pcall(setupEnemy, v.Parent)
            end
        end)
    end,
})

local FarmTab = Window:CreateTab("Farm", 4483362458)

local VACUUM_NAMES = {SlimeSample=true,LotusOoze=true,RottenBlood=true,EnchantedCrystals=true}

FarmTab:CreateButton({
    Name = "Auto Vacuum",
    Callback = function()
        task.spawn(function()
            local visited = {}
            pcall(function()
                for _, v in pairs(workspace:GetDescendants()) do
                    if VACUUM_NAMES[v.Name] and not visited[v] then
                        visited[v] = true
                        local p = v:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if p then pcall(fireproximityprompt, p) end
                    end
                end
            end)
        end)
    end,
})

local CHEST_NAMES = {NormalChest=true, LegendaryChest=true, CursedChest_Purple=true, CursedChest_Green=true}

FarmTab:CreateButton({
    Name = "ChestsTp",
    Callback = function()
        task.spawn(function()
            local visited = {}
            pcall(function()
                for _, v in pairs(workspace:GetDescendants()) do
                    if CHEST_NAMES[v.Name] and not visited[v] then
                        local char = LocalPlayer.Character
                        if not char then task.wait(0.1) char = LocalPlayer.Character end
                        if not char then return end
                        local r    = char:FindFirstChild("HumanoidRootPart")
                        local part = v:IsA("Model") and v.PrimaryPart or (v:IsA("BasePart") and v)
                        if part and r then
                            visited[v] = true
                            pcall(function() r.CFrame = part.CFrame + Vector3.new(0, 3, 0) end)
                            task.wait(0.5)
                            local prompt = v:FindFirstChildWhichIsA("ProximityPrompt", true)
                            if prompt then pcall(fireproximityprompt, prompt) end
                            task.wait(1)
                        end
                    end
                end
            end)
        end)
    end,
})

local MiscTab = Window:CreateTab("Misc", 4483362458)

local function destroyButton(btn)
    task.delay(0.5, function()
        if btn then pcall(function() btn:Destroy() end) end
    end)
end

local fpsBoostBtn = MiscTab:CreateButton({
    Name = "FPS Boost",
    Callback = function()
        if getgenv().FPSBoost then return end
        getgenv().FPSBoost = true
        
        task.spawn(function()
            pcall(function()
                local L = game:GetService("Lighting")
                L.GlobalShadows = false
                L.Brightness = 2
                workspace.WindSpeed = 0
                workspace.WindDirection = Vector3.new(0,0,0)
                
                for _, v in pairs(L:GetChildren()) do
                    if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect")
                       or v:IsA("ColorCorrectionEffect") or v:IsA("DepthOfFieldEffect") then
                        pcall(function() v:Destroy() end)
                    end
                end
            end)

            local function handle(v)
                if not v.Parent then return end
                
                local model = v:FindFirstAncestorWhichIsA("Model")
                if model and model:FindFirstChildWhichIsA("Humanoid", true) then return end
                
                local cn = v.ClassName
                if cn == "ParticleEmitter" or cn == "Sparkles" or cn == "Smoke" or cn == "Fire" then
                    pcall(function() v.Enabled = false end)
                elseif cn == "Trail" then
                    pcall(function() v.Enabled = false end)
                elseif cn == "Beam" then
                    pcall(function() 
                        v.Enabled = false
                        v.Transparency = NumberSequence.new(1)
                    end)
                end
            end

            local descendants = workspace:GetDescendants()
            local batchSize = 750
            local count = 0
            
            for _, v in pairs(descendants) do
                pcall(handle, v)
                count = count + 1
                
                if count >= batchSize then
                    count = 0
                    task.wait(0.08)
                end
            end
        end)
        
        destroyButton(fpsBoostBtn)
    end,
})

MiscTab:CreateLabel("⚠️ VERY HEAVY OPERATIONS")

local pointLightsBtn = MiscTab:CreateButton({
    Name = "Remove PointLights",
    Callback = function()
        if getgenv().FPS_PL then return end
        getgenv().FPS_PL = true
        
        task.spawn(function()
            for _, v in pairs(workspace:GetDescendants()) do
                if v.ClassName == "PointLight" then
                    pcall(function() v:Destroy() end)
                end
            end
        end)
        
        destroyButton(pointLightsBtn)
    end,
})

local surfaceLightsBtn = MiscTab:CreateButton({
    Name = "Remove SurfaceLights",
    Callback = function()
        if getgenv().FPS_SL then return end
        getgenv().FPS_SL = true
        
        task.spawn(function()
            for _, v in pairs(workspace:GetDescendants()) do
                if v.ClassName == "SurfaceLight" then
                    pcall(function() v:Destroy() end)
                end
            end
        end)
        
        destroyButton(surfaceLightsBtn)
    end,
})

local neonPartsBtn = MiscTab:CreateButton({
    Name = "Remove Neon Parts",
    Callback = function()
        if getgenv().FPS_NE then return end
        getgenv().FPS_NE = true
        
        task.spawn(function()
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("BasePart") and v.Material == Enum.Material.Neon then
                    pcall(function()
                        v.Material = Enum.Material.SmoothPlastic
                        v.CastShadow = false
                    end)
                end
            end
        end)
        
        destroyButton(neonPartsBtn)
    end,
})

local zonesWindBtn = MiscTab:CreateButton({
    Name = "Remove Zones & Wind",
    Callback = function()
        if getgenv().FPS_ZW then return end
        getgenv().FPS_ZW = true
        
        task.spawn(function()
            -- Lista de nomes EXATOS para remover (mais rápido)
            local exactNames = {
                WaterFallZone = true,
                ZonePvPRanked = true,
                ZoneRaidMode = true,
                ZoneRaidLobby = true,
                ["leaf particle"] = true,
                chosowind = true,
                Windmill = true,
                WindStartingArea = true,
            }
            
            local snapshot = workspace:GetDescendants()
            local total = #snapshot
            local maxProcess = math.min(total, 50000) -- LIMITE MÁXIMO
            local removed = 0
            local batchSize = 300
            
            for i = 1, maxProcess do
                local v = snapshot[i]
                
                -- Wait a cada batch
                if i % batchSize == 0 then
                    task.wait(0.1)
                end
                
                -- Verifica se ainda existe
                if v and v.Parent then
                    local shouldRemove = false
                    local name = v.Name
                    
                    -- Check 1: Nome exato (RÁPIDO)
                    if exactNames[name] then
                        shouldRemove = true
                    -- Check 2: Apenas se for Model ou BasePart (OTIMIZADO)
                    elseif v:IsA("Model") or v:IsA("BasePart") then
                        local nameLower = name:lower()
                        -- Usa 'match' ao invés de 'find' (mais rápido)
                        if nameLower:match("wind") or nameLower:match("tree") or nameLower:match("leaf") then
                            shouldRemove = true
                        end
                    end
                    
                    -- Remove se necessário
                    if shouldRemove then
                        pcall(function()
                            v:Destroy()
                            removed = removed + 1
                        end)
                    end
                end
                
                -- SAFETY: Para se removeu muitos items (proteção contra loop)
                if removed > 5000 then
                    break
                end
            end
            
            -- Limpa memória
            snapshot = nil
            collectgarbage("collect")
        end)
        
        destroyButton(zonesWindBtn)
    end,
})

MiscTab:CreateButton({
    Name = "Clear Misc Tab",
    Callback = function()
        task.spawn(function()
            task.wait(0.5)
            if MiscTab then
                pcall(function() 
                    for _, v in pairs(MiscTab:GetDescendants()) do
                        pcall(function() v:Destroy() end)
                    end
                end)
            end
        end)
    end,
})

local BlafantTab = Window:CreateTab("BlafantHelping", 4483362458)

BlafantTab:CreateLabel("When you die, you'll respawn at the exact location where you clicked this button. That's it.")

local tpDieConn = nil

BlafantTab:CreateButton({
    Name = "TpDieLocal",
    Callback = function()
        pcall(function()
            local c = LocalPlayer.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if not r then return end
            getgenv().Spawn = r.CFrame
            if tpDieConn then pcall(function() tpDieConn:Disconnect() end) tpDieConn = nil end
            tpDieConn = LocalPlayer.CharacterAdded:Connect(function(ch)
                if not getgenv().Spawn then return end
                task.wait(0.3)
                pcall(function()
                    local hrp = ch:WaitForChild("HumanoidRootPart", 5)
                    if hrp then hrp.CFrame = getgenv().Spawn end
                end)
            end)
        end)
    end,
})
