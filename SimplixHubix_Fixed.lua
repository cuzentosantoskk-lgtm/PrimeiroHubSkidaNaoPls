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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- ── Remote com retry e cooldown ──────────────────────────────────────────────
local RequestSkillRemote
local getRemoteRetries = 0
local lastRemoteAttempt = 0
local function getRemote()
    local now = tick()
    if not RequestSkillRemote and getRemoteRetries < 5 and now - lastRemoteAttempt > 5 then
        getRemoteRetries = getRemoteRetries + 1
        lastRemoteAttempt = now
        pcall(function()
            RequestSkillRemote = ReplicatedStorage
                :WaitForChild("@rbxts/wcs:source/networking@GlobalEvents", 5)
                :WaitForChild("requestSkill", 5)
            if RequestSkillRemote then getRemoteRetries = 0 end
        end)
    end
    return RequestSkillRemote
end

-- ── Helper: coleta GetDescendants com yield pra não travar ───────────────────
local function safeGetDescendants(parent, filterFn)
    local result = {}
    local i = 0
    pcall(function()
        for _, v in pairs(parent:GetDescendants()) do
            i = i + 1
            if i % 1000 == 0 then task.wait() end -- yield a cada 1000 pra não engasgar
            pcall(function()
                if filterFn(v) then
                    table.insert(result, v)
                end
            end)
        end
    end)
    return result
end

-- ── Helper: processa lista em batches com intervalo ──────────────────────────
local function processBatch(list, batchSize, interval, fn)
    local count = 0
    for _, item in ipairs(list) do
        pcall(fn, item)
        count = count + 1
        if count >= batchSize then
            count = 0
            task.wait(interval)
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════════
--  BATTLE ASSIST TAB
-- ════════════════════════════════════════════════════════════════════════════
local BattleTab = Window:CreateTab("BattleAssist", 4483362458)

-- ── NoStun ───────────────────────────────────────────────────────────────────
local nostun_connections = {}
local nostun_character_connected = false

BattleTab:CreateToggle({
    Name = "NoStunImprovised",
    CurrentValue = false,
    Flag = "NoStunImprovised",
    Callback = function(v)
        if not v then
            getgenv().NoStunImprovised = false
            for _, conn in ipairs(nostun_connections) do
                if conn then pcall(function() conn:Disconnect() end) end
            end
            nostun_connections = {}
            nostun_character_connected = false
            return
        end
        if getgenv().NoStunImprovised then return end
        getgenv().NoStunImprovised = true

        local BOOST_SPEED = 50
        local BOOST_TIME  = 2
        local DEFAULT_SPEED = 16 -- FIX: salva default pra resetar depois

        local function setup(char)
            pcall(function()
                local hum = char:WaitForChild("Humanoid", 5)
                if not hum then return end

                local boosting  = false
                local boostEnd  = 0
                local lastHealth = hum.Health

                local healthConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
                    if not getgenv().NoStunImprovised then return end
                    local cur = hum.Health
                    if cur < lastHealth and not boosting then
                        boostEnd = tick() + BOOST_TIME
                        boosting = true
                    end
                    lastHealth = cur
                end)

                if healthConn then
                    table.insert(nostun_connections, healthConn)
                end

                task.spawn(function()
                    while hum.Parent and getgenv().NoStunImprovised do
                        if boosting then
                            if tick() < boostEnd then
                                hum.WalkSpeed = BOOST_SPEED
                            else
                                -- FIX: reseta walkspeed quando boost termina
                                boosting = false
                                pcall(function() hum.WalkSpeed = DEFAULT_SPEED end)
                            end
                        end
                        task.wait(0.02)
                    end
                    -- FIX: reseta ao desligar o toggle também
                    pcall(function() if hum.Parent then hum.WalkSpeed = DEFAULT_SPEED end end)
                end)
            end)
        end

        if LocalPlayer.Character then setup(LocalPlayer.Character) end

        if not nostun_character_connected then
            nostun_character_connected = true
            local conn = LocalPlayer.CharacterAdded:Connect(function(char)
                if getgenv().NoStunImprovised then setup(char) end
            end)
            table.insert(nostun_connections, conn)
        end
    end,
})

-- ── DashingHelper ─────────────────────────────────────────────────────────────
local dashinghelper_lastScan = 0

BattleTab:CreateToggle({
    Name = "DashingHelper",
    CurrentValue = false,
    Flag = "DashingHelper",
    Callback = function(v)
        if not v then
            getgenv().DashingHelper = false
            dashinghelper_lastScan = 0
            return
        end
        getgenv().DashingHelper = true

        local DashObjects = {}

        task.spawn(function()
            -- FIX: scan inicial do getreg com yield a cada 500 itens
            local i = 0
            for _, obj in pairs(getreg()) do
                i = i + 1
                if i % 500 == 0 then task.wait() end
                if typeof(obj) == "table" and rawget(obj,"_cooltime") and rawget(obj,"_dashStreakCount") then
                    table.insert(DashObjects, obj)
                end
            end
            dashinghelper_lastScan = tick()

            while getgenv().DashingHelper do
                -- Rescan se lista vazia e passou tempo suficiente
                if #DashObjects == 0 and tick() - dashinghelper_lastScan > 3 then
                    local j = 0
                    for _, obj in pairs(getreg()) do
                        j = j + 1
                        if j % 500 == 0 then task.wait() end
                        if typeof(obj) == "table" and rawget(obj,"_cooltime") and rawget(obj,"_dashStreakCount") then
                            local found = false
                            for _, e in ipairs(DashObjects) do
                                if e == obj then found = true break end
                            end
                            if not found then table.insert(DashObjects, obj) end
                        end
                    end
                    dashinghelper_lastScan = tick()
                end

                for _, dash in ipairs(DashObjects) do
                    if rawget(dash, "_dashStreakCount") == 0 then
                        pcall(function()
                            if dash._canDash == false then dash._canDash = true end
                            if dash._lastDashTime then dash._lastDashTime = 0 end
                            if dash._cooltime and dash._cooltime.reset then
                                dash._cooltime:reset(0)
                            end
                        end)
                    end
                end
                task.wait(0.08)
            end
        end)
    end,
})

-- ── AutoBlock ────────────────────────────────────────────────────────────────
local BLOCK_RANGE   = 18
local BLOCK_CD      = 0.25
local AUTOBLOCK_CD  = 1.5
local BLOCK_DUR     = 0.35
local lastBlock     = 0
local lastAutoBlock = 0
local isBlocking    = false

local blockBufferOn  = buffer.fromstring("\r\000\000\000General/Block\001\000\000\000\000")
local blockBufferOff = buffer.fromstring("\r\000\000\000General/Block\000\000\000\000\000")

local IGNORED = {
    idle=true, walk=true, run=true, sprint=true, jump=true, fall=true,
    land=true, heavy_land=true, run_land=true, run_land_backward=true,
    walk_backward=true, walk_left=true, walk_right=true,
    swim=true, swimidle=true, climb=true, sit=true,
    dance=true, dance2=true, dance3=true, cheer=true, laugh=true,
    point=true, wave=true, toollunge=true, toolnone=true, toolslash=true,
    hit_animation1=true, hit_animation2=true, hit_animation3=true,
    block_hit_animation1=true, block_hit_animation2=true, block_hit_animation3=true,
}

local function block()
    -- FIX: usa tick() consistentemente (não mistura os.clock e tick)
    local now = tick()
    if now - lastAutoBlock < AUTOBLOCK_CD then return end
    if now - lastBlock < BLOCK_CD or isBlocking then return end
    lastBlock     = now
    lastAutoBlock = now
    isBlocking    = true

    local r = getRemote()
    if r then
        pcall(function() r:FireServer({buffer = blockBufferOn, blobs = {}}) end)
        task.delay(BLOCK_DUR, function()
            pcall(function() r:FireServer({buffer = blockBufferOff, blobs = {}}) end)
            isBlocking = false
        end)
    else
        isBlocking = false
    end

    -- Failsafe: garante que isBlocking volta pro false
    task.delay(BLOCK_DUR + 2, function()
        if isBlocking then isBlocking = false end
    end)
end

local function isEnemy(model)
    if not model or not model:IsA("Model") then return false end
    if model == LocalPlayer.Character then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    if not model:FindFirstChild("combatCooldown") then return false end
    return true
end

local autoBl_enemies     = false
local hooked_enemies     = {}
local autoblock_connections = {}
-- FIX: tabela separada pra guardar conns de "aguardando combatCooldown"
local pending_conns = {}

local function hookEnemy_Enemies(model)
    if not model or not model.Parent then return end
    if hooked_enemies[model] then return end

    if not model:FindFirstChild("combatCooldown") then
        -- FIX: guarda a conn pendente pra poder desconectar depois
        if pending_conns[model] then return end
        local conn
        conn = model.DescendantAdded:Connect(function(child)
            if child.Name == "combatCooldown" then
                conn:Disconnect()
                pending_conns[model] = nil
                task.wait(0.1)
                hookEnemy_Enemies(model)
            end
        end)
        pending_conns[model] = conn
        return
    end

    if not isEnemy(model) then return end

    local hum = model:FindFirstChildWhichIsA("Humanoid", true)
    if not hum then task.delay(0.3, function() hookEnemy_Enemies(model) end) return end

    local root = model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
    if not root then task.delay(0.3, function() hookEnemy_Enemies(model) end) return end

    hooked_enemies[model] = true
    local hit = false
    local hp  = hum.Health

    local healthConn = hum.HealthChanged:Connect(function(h)
        if h < hp then
            hit = true
            task.delay(1, function() hit = false end)
        end
        hp = h
    end)

    local function dist()
        if not root or not root.Parent then return false end
        local char = LocalPlayer.Character
        local r = char and char:FindFirstChild("HumanoidRootPart")
        if not r then return false end
        return (r.Position - root.Position).Magnitude <= BLOCK_RANGE
    end

    local function shouldBlock(track)
        if not track or not track.IsPlaying then return false end
        if track.Looped then return false end
        local name = (track.Animation and track.Animation.Name or ""):lower()
        if name ~= "" and IGNORED[name] then return false end
        return true
    end

    task.spawn(function()
        local seen = {}
        while model.Parent and hum.Parent do
            if not hit and dist() and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                local animator = model:FindFirstChildWhichIsA("Animator", true)
                if animator and animator.Parent then
                    local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
                    if ok and tracks then
                        for _, track in ipairs(tracks) do
                            local id = tostring(track)
                            if not seen[id] and shouldBlock(track) then
                                seen[id] = true
                                if autoBl_enemies then block() end
                                task.delay(0.5, function() seen[id] = nil end)
                            end
                        end
                    end
                end
            end
            task.wait(0.12)
        end
        hooked_enemies[model] = nil
        pcall(function() healthConn:Disconnect() end)
    end)
end

task.spawn(function()
    task.wait(1)
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        pcall(function()
            for _, v in pairs(enemies:GetDescendants()) do
                if v:IsA("Model") then task.spawn(hookEnemy_Enemies, v) end
            end
        end)

        table.insert(autoblock_connections, enemies.DescendantAdded:Connect(function(v)
            if v:IsA("Model") then
                task.wait(0.15)
                if autoBl_enemies then hookEnemy_Enemies(v) end
            end
        end))

        table.insert(autoblock_connections, enemies.DescendantRemoving:Connect(function(v)
            hooked_enemies[v] = nil
            -- FIX: limpa pending conn se o inimigo saiu antes de ter combatCooldown
            if pending_conns[v] then
                pcall(function() pending_conns[v]:Disconnect() end)
                pending_conns[v] = nil
            end
        end))
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    hooked_enemies = {}
    pending_conns  = {}
    if autoBl_enemies then
        local enemies = workspace:FindFirstChild("Enemies")
        if enemies then
            for _, v in pairs(enemies:GetDescendants()) do
                if v:IsA("Model") then task.spawn(hookEnemy_Enemies, v) end
            end
        end
    end
end)

BattleTab:CreateToggle({
    Name = "AutoBlock Enemies",
    CurrentValue = false,
    Flag = "AutoBlockEnemies",
    Callback = function(v)
        autoBl_enemies = v
        if not v then
            for _, conn in ipairs(autoblock_connections) do
                if conn then pcall(function() conn:Disconnect() end) end
            end
            autoblock_connections = {}
            hooked_enemies = {}
            -- FIX: limpa pending conns ao desligar
            for _, conn in pairs(pending_conns) do
                pcall(function() conn:Disconnect() end)
            end
            pending_conns = {}
        end
    end,
})

BattleTab:CreateSlider({
    Name = "Block Range",
    Range = {5, 50},
    Increment = 1,
    Suffix = "m",
    CurrentValue = 18,
    Flag = "BlockRange",
    Callback = function(val) BLOCK_RANGE = val end,
})

BattleTab:CreateSlider({
    Name = "Block Cooldown",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.25,
    Flag = "BlockCD",
    Callback = function(val) BLOCK_CD = val end,
})

BattleTab:CreateSlider({
    Name = "AutoBlock Cooldown",
    Range = {0, 5},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 1.5,
    Flag = "AutoBlockCD",
    Callback = function(val) AUTOBLOCK_CD = val end,
})

BattleTab:CreateSlider({
    Name = "Block Duration",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.35,
    Flag = "BlockDuration",
    Callback = function(val) BLOCK_DUR = val end,
})

-- ════════════════════════════════════════════════════════════════════════════
--  FARM HELPER TAB
-- ════════════════════════════════════════════════════════════════════════════
local FarmTab = Window:CreateTab("FarmHelper", 4483362458)

local tp = {
    ["GOJO"]    = CFrame.new(2075.68042,164.128494,1157.99573,0.0221533291,0.956951737,-0.28940022,-4.65661343e-10,0.289471269,0.957186639,0.999754608,-0.0212048702,0.00641275244),
    ["SUKUNA"]  = CFrame.new(617.986206,181.247147,2959.45898,0.185924381,-0.628661394,0.755127192,7.4505806e-09,0.76852721,0.639817178,-0.982564092,-0.118957609,0.14288795),
    ["ITADORI"] = CFrame.new(-532.307556,238.75798,2415.08838,0.738092363,-0.523102105,0.426126778,-1.49011647e-08,0.631579876,0.775310814,-0.674699843,-0.572250962,0.466164201),
    ["ESO"]     = CFrame.new(1984.95032,123.46376,-2138.87695,-0.193435311,-4.02031048e-08,0.981113017,2.06824886e-08,1,4.50547759e-08,-0.981113017,2.90070439e-08,-0.193435311),
    ["URAUME"]  = CFrame.new(-133.396622,476.409729,-1265.70117,0.193170547,0.476926029,-0.857453644,0,0.873913646,0.486081272,0.98116523,-0.0938965827,0.168814361),
}

FarmTab:CreateDropdown({
    Name = "Boss",
    Options = {"GOJO","SUKUNA","ITADORI","ESO","URAUME"},
    CurrentOption = {"GOJO"},
    MultipleOptions = false,
    Flag = "Boss",
    Callback = function(opts)
        local cf = tp[opts[1]]
        if cf then
            task.spawn(function()
                pcall(function()
                    local char = LocalPlayer.Character
                    if not char then
                        char = LocalPlayer.CharacterAdded:Wait()
                        if not char then return end
                    end
                    local r = char:WaitForChild("HumanoidRootPart", 5)
                    if r then r.CFrame = cf end
                end)
            end)
        end
    end,
})

local VACUUM_NAMES = {SlimeSample=true, LotusOoze=true, RottenBlood=true, EnchantedCrystals=true}

FarmTab:CreateButton({
    Name = "Vacum",
    Callback = function()
        task.spawn(function()
            local visited = {}
            local i = 0
            pcall(function()
                for _, v in pairs(workspace:GetDescendants()) do
                    i = i + 1
                    if i > 100000 then break end
                    if i % 200 == 0 then task.wait() end -- yield pra não travar
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
            local i = 0
            pcall(function()
                for _, v in pairs(workspace:GetDescendants()) do
                    i = i + 1
                    if i > 100000 then break end

                    if CHEST_NAMES[v.Name] and not visited[v] then
                        local char = LocalPlayer.Character
                        -- FIX: `return` aqui saia do pcall, não do loop — usando `continue` pattern
                        if not char or not char:FindFirstChild("HumanoidRootPart") then
                            task.wait(0.1)
                            -- tenta novamente a partir do próximo chest
                        else
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
                end
            end)
        end)
    end,
})

-- ════════════════════════════════════════════════════════════════════════════
--  MISC TAB
-- ════════════════════════════════════════════════════════════════════════════
local MiscTab = Window:CreateTab("Misc", 4483362458)

-- ── FPS Boost ────────────────────────────────────────────────────────────────
MiscTab:CreateLabel("✅ These FPS scripts boosted my FPS from 43 to 60 (cap). Results may vary.")

MiscTab:CreateButton({
    Name = "FPS Boost",
    Callback = function()
        if getgenv().FPSBoost then return end
        getgenv().FPSBoost = true

        -- Lighting: instantâneo, poucos itens
        pcall(function()
            local L = game:GetService("Lighting")
            pcall(function() L.GlobalShadows = false end)
            pcall(function() L.Brightness = 2 end)
            pcall(function() workspace.WindSpeed = 0 end)
            pcall(function() workspace.WindDirection = Vector3.new(0,0,0) end)
            for _, v in pairs(L:GetChildren()) do
                if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect")
                   or v:IsA("ColorCorrectionEffect") or v:IsA("DepthOfFieldEffect") then
                    pcall(function() v:Destroy() end)
                end
            end
        end)

        task.spawn(function()
            task.wait(0.3)

            -- FIX: coleta com safeGetDescendants (yield a cada 1000)
            local particles = safeGetDescendants(workspace, function(v) return v.ClassName == "ParticleEmitter" end)
            local trails    = safeGetDescendants(workspace, function(v) return v.ClassName == "Trail" end)
            local beams     = safeGetDescendants(workspace, function(v) return v.ClassName == "Beam" end)

            -- Limpa WindShake attributes num loop separado com yield
            task.spawn(function()
                local i = 0
                pcall(function()
                    for _, v in pairs(workspace:GetDescendants()) do
                        i = i + 1
                        if i % 1000 == 0 then task.wait() end
                        if v:IsA("BasePart") then
                            pcall(function()
                                v:SetAttribute("WindShake", nil)
                                v:SetAttribute("Shake", nil)
                            end)
                        end
                    end
                end)
            end)

            processBatch(beams,     20, 0.05, function(v) v.Transparency = NumberSequence.new(1) v:Destroy() end)
            processBatch(trails,    25, 0.05, function(v) v.Enabled = false end)
            processBatch(particles, 25, 0.05, function(v) v.Enabled = false end)

            -- WindShake via getreg com yield a cada 500 itens
            task.wait(0.5)
            local count = 0
            for _, v in pairs(getreg()) do
                count = count + 1
                if count > 50000 then break end
                if count % 500 == 0 then task.wait(0.1) end
                pcall(function()
                    if typeof(v) == "table" then
                        if rawget(v,"WindShakeObjects") or (rawget(v,"Objects") and rawget(v,"WindSpeed")) then
                            if rawget(v,"Stop") then v:Stop() end
                            if rawget(v,"HeartbeatConnection") then v.HeartbeatConnection:Disconnect() end
                        end
                        if rawget(v,"Bones") and rawget(v,"WindInfluence") then
                            if rawget(v,"Connection") then v.Connection:Disconnect() end
                            if rawget(v,"Running") then v.Running = false end
                        end
                        if rawget(v,"Lines") and rawget(v,"Wind") then
                            if rawget(v,"Stop") then v:Stop() end
                            if rawget(v,"Connection") then v.Connection:Disconnect() end
                        end
                    end
                end)
            end
        end)
    end,
})

-- ── Aviso botões pesados ──────────────────────────────────────────────────────
MiscTab:CreateLabel("⚠️ WARNING: Buttons below are HEAVY. They remove slowly over ~3 minutes to avoid freezing.")

-- ── Remove PointLights ───────────────────────────────────────────────────────
MiscTab:CreateButton({
    Name = "Remove PointLights [HEAVY - runs ~3min]",
    Callback = function()
        if getgenv().FPS_PL then return end
        getgenv().FPS_PL = true
        task.spawn(function()
            task.wait(0.5)
            -- FIX: coleta com yield
            local lights = safeGetDescendants(workspace, function(v) return v.ClassName == "PointLight" end)
            processBatch(lights, 5, 2, function(v) v:Destroy() end)
        end)
    end,
})

-- ── Remove Zones & Wind ───────────────────────────────────────────────────────
MiscTab:CreateButton({
    Name = "Remove Zones & Wind [HEAVY - runs ~3min]",
    Callback = function()
        if getgenv().FPS_ZW then return end
        getgenv().FPS_ZW = true
        task.spawn(function()
            task.wait(0.5)
            local zonesToDelete = {
                ["WaterFallZone"]=true,["ZonePvPRanked"]=true,
                ["ZoneRaidMode"]=true,["ZoneRaidLobby"]=true,
                ["leaf particle"]=true,["chosowind"]=true,
                ["Windmill"]=true,["WindStartingArea"]=true,
            }
            -- FIX: coleta com yield
            local zones = safeGetDescendants(workspace, function(v) return zonesToDelete[v.Name] end)
            local windObjects = safeGetDescendants(workspace, function(v)
                local nm = v.Name:lower()
                return (nm:find("wind") or nm:find("tree") or nm:find("leaf"))
                    and (v:IsA("Model") or v:IsA("BasePart"))
            end)
            processBatch(zones,       5, 2, function(v) v:Destroy() end)
            processBatch(windObjects, 5, 2, function(v) v:Destroy() end)
        end)
    end,
})

-- ── Remove SurfaceLights ─────────────────────────────────────────────────────
MiscTab:CreateButton({
    Name = "Remove SurfaceLights [HEAVY - runs ~3min]",
    Callback = function()
        if getgenv().FPS_SL then return end
        getgenv().FPS_SL = true
        task.spawn(function()
            task.wait(0.5)
            -- FIX: coleta com yield
            local surfaceLights = safeGetDescendants(workspace, function(v) return v.ClassName == "SurfaceLight" end)
            processBatch(surfaceLights, 5, 2, function(v) v:Destroy() end)
        end)
    end,
})

-- ── Remove Neon Parts ────────────────────────────────────────────────────────
MiscTab:CreateButton({
    Name = "Remove Neon Parts [HEAVY - runs ~3min]",
    Callback = function()
        if getgenv().FPS_NE then return end
        getgenv().FPS_NE = true
        task.spawn(function()
            task.wait(0.5)
            -- FIX: coleta com yield
            local neonParts = safeGetDescendants(workspace, function(v)
                return v:IsA("BasePart") and v.Material == Enum.Material.Neon
            end)
            -- Troca material ao invés de destruir (preserva colisões do mapa)
            processBatch(neonParts, 5, 2, function(v)
                v.Material   = Enum.Material.SmoothPlastic
                v.CastShadow = false
            end)
        end)
    end,
})

-- ════════════════════════════════════════════════════════════════════════════
--  BLAFANT TAB
-- ════════════════════════════════════════════════════════════════════════════
local BlafantTab = Window:CreateTab("BlafantHelping", 4483362458)

BlafantTab:CreateLabel("When you die, you'll respawn at the exact location where you clicked this button. That's it.")

-- FIX: connection leak — guarda a conn e só cria uma vez
local tpDieConn = nil

BlafantTab:CreateButton({
    Name = "TpDieLocal",
    Callback = function()
        pcall(function()
            local c = LocalPlayer.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if not r then return end

            getgenv().Spawn = r.CFrame

            -- FIX: desconecta conn anterior antes de criar nova
            if tpDieConn then
                pcall(function() tpDieConn:Disconnect() end)
                tpDieConn = nil
            end

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
