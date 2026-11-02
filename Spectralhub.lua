--[[
    SpectralHub v7.5
    - NOVO: Auto Pumpkin Hunt (aba Auto Farm): vai na abobora, clica dentro dela, vai para a proxima
      quando some e mata o Jack o' Lantern quando spawnar
    - Em qualquer voo: voa normal e, quando faltarem 750 studs ou menos para o destino, teleporta
    - Auto treinar raca: farma osso no ponto de farm -> V4 ativa: espera no ponto alto -> V4 acabou:
      tenta comprar upgrade e volta a farmar (sem raid/fragmentos)
    - Auto farm osso / treino: ao ligar vao primeiro para o ponto de farm (-9517, 142, 5543)
    - Raid: nao puxa/trava mais os NPCs (dessincronizava com o servidor)
    - Iniciar raid: puxa Map["Boat Castle"].MapTeleportA.Hitbox para o personagem antes de clicar no botao
]]

pcall(function() (getgenv and getgenv() or _G).SpectralHubLoaded = game.JobId end)
print("[SpectralHub] 0 - executor rodou")

local function main()
if not game:IsLoaded() then game.Loaded:Wait() end
print("[SpectralHub] 1 - jogo carregado")

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local Run = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer

local G = (getgenv and getgenv()) or _G
G.SpectralHubGen = (G.SpectralHubGen or 0) + 1
local myGen = G.SpectralHubGen
local function Alive() return G.SpectralHubGen == myGen end
print("[SpectralHub] execu\u{E7}\u{E3}o n\u{FA}mero", myGen)
pcall(function()
    local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local bv = r and r:FindFirstChild("SpectralHold")
    if bv then bv:Destroy() end
end)

pcall(function() if G.SpectralHubUI then G.SpectralHubUI:Destroy() end end)
pcall(function()
    local roots = { player:FindFirstChild("PlayerGui") }
    pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
    pcall(function() if gethui then table.insert(roots, gethui()) end end)
    for _, root in ipairs(roots) do
        for _, g in ipairs(root:GetChildren()) do
            if g.Name == "Rayfield" or g.Name == "Rayfield-Old" then pcall(function() g:Destroy() end) end
        end
    end
end)
G.SpectralHubUI = nil

local Rayfield
for _, url in ipairs({
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
}) do
    local ok, res = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and res then Rayfield = res break end
    warn("[SpectralHub] falha no Rayfield:", url, res)
end
if not Rayfield then warn("[SpectralHub] ERRO: Rayfield n\u{E3}o carregou") return end
pcall(function() if G.SpectralHubUI and G.SpectralHubUI ~= Rayfield then G.SpectralHubUI:Destroy() end end)
G.SpectralHubUI = Rayfield
print("[SpectralHub] 2 - Rayfield ok")

local Window = Rayfield:CreateWindow({
    Name = "Spectral Hub", LoadingTitle = "Spectral Hub", LoadingSubtitle = "v7.5",
    ConfigurationSaving = { Enabled = false },
})

print("[SpectralHub] 3 - abas criadas")

local WEST = Vector3.new(-1, 0, 0)
local FLY_HEIGHT, FLY_SPEED, PIVOT_ASSIST = 25, 200, 0.8
local SWORD_TOOLTIP, SWORD_NAME = "Sword", "Cursed Dual Katana"
local ATTACK_HEIGHT, MAX_BOAT_DISTANCE = 30, 2000
local TERROR_HEIGHT, TERROR_ESCAPE_HEIGHT = 50, 100
local TERROR_NO_DAMAGE_TIME, TERROR_ESCAPE_HOLD, TERROR_ABOVE_RADIUS = 0.7, 3, 40
local HIT_ESCAPE_HEIGHT, STUN_ESCAPE_HEIGHT, HIT_ESCAPE_HOLD = 100, 125, 2.7
local LOWHP_THRESHOLD, LOWHP_RECOVER = 0.20, 0.50
local LOWHP_START, LOWHP_MAX, LOWHP_RISE = 120, 200, 20
local MIRAGE_SPEED, MIRAGE_NPC_INDEX = 300, 3
local HIGHEST_PART_NAME = "dbz_map1_Cube.012"
local CHEST_DWELL, NIGHT_START, NIGHT_END = 0.4, 18, 5.5
local RACE_DOOR_POSITION = nil
local TEMPLE_TP_COOLDOWN = 6
local TRIAL_RADIUS, KILL_RADIUS, RACE_HEIGHT = 400, 250, 10

local TEMPLE_NEAR = 1500
local TEMPLE_CENTER = Vector3.new(28700, 14890, 0)

local TREE_NPC_POS = Vector3.new(28286, 14897, 103)
local BOAT_CASTLE_POS = Vector3.new(-5075, 315, -3150)
local HITBOX_NAMES = {"MapTeleportA", "MapTeleportB", "MapTeleportC"}
local hitboxBusy = false
local UseCastleHitbox

local DOOR_POS = {
    ghoul    = Vector3.new(28674, 14890, 455),
    fishman  = Vector3.new(28224, 14890, -213),
    shark    = Vector3.new(28224, 14890, -213),
    cyborg   = Vector3.new(28493, 14896, -423),
    ciborgue = Vector3.new(28493, 14896, -423),
    mink     = Vector3.new(29019, 14892, -379),
    human    = Vector3.new(29237, 14892, -206),
    skypiea  = Vector3.new(28969, 14921, 234),
    angel    = Vector3.new(28969, 14921, 234),
}

local SelectedShark, SelectedTerror = false, false
local SelectedBoat = "PirateSloop"
local StartSeaEvent = false
local AutoCombatForce = false
local MirageFlags = { Find=false, Npc=false, Chests=false, High=false, Moon=false, All=false }
local RaceFlags = { Door=false, Trial=false, KillPlayers=false, Train=false }
local currentBoat = nil
local abandoned = setmetatable({}, { __mode = "k" })

local FruitFlags = { Collect=false, Store=false, Chip=false, Raid=false, RaidDone=false }
local ESPFlags = { Fruit=false, Player=false }
local FarmFlags = { Run=false, Buy=false, V4=false, Halloween=false }
local HW = { active = false, boss = false, window = 20 }   -- active: evento rolando (farm normal pausa); window: minutos apos a hora cheia
local AutoFlags = { Team=false, Buso=false }
local FarmMode = "Osso"
local FarmUI = {}
local TrainUI = {}
local CHIP_NAME = "Ice"
local ClearESP

local TS = { farm = false, waiting = false }
local FARM_POS = Vector3.new(-9517, 142, 5543)    -- ponto de farm do osso
local WAIT_POS = Vector3.new(-9523, 3933, 6727)   -- onde espera a V4 acabar
local TP_DISTANCE = 750                           -- voa ate faltar 750 studs, ai teleporta para o destino

local HttpService = game:GetService("HttpService")
-- um arquivo por conta: conta nova (sem arquivo) começa com tudo desativado
local CONFIG_FILE = "SpectralHub_config_" .. tostring(player.UserId) .. ".json"

local TOOL_MAP = { ["Espada"] = "Sword", ["Arma"] = "Gun", ["Fruta"] = "Blox Fruit", ["Soco"] = "Melee" }
local SelectedToolLabel = "Espada"
local KILL_AURA_RANGE, KILL_AURA_MAX = 120, 12
local FastAttackUser = false
local WaterWalk = false
local WATER_WALK_Y = 112
local RaidReset = false
local ISLAND_MARGIN = 150
local RaidNoclip = false
local ISLAND_CLEAR_WAIT = 2.5
local ISLAND_EMPTY_SKIP = 25
local RAID_LAST_ISLAND = 4
local RAID_NEAR_MAX = 1200
local NEXT_ISLAND_MAX_DIST = 3000
local NotifyOff = false

local BOAT_OPTIONS = {"PirateSloop","Speeder","SwagBoat","FlowerShip"}

local function SaveSettings()
    if not writefile then return false end
    local ok, err = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode({
            FastAttack = FastAttackUser,
            FarmHeight = RACE_HEIGHT,
            KillRange = KILL_AURA_RANGE,
            KillMax = KILL_AURA_MAX,
            HalloweenWindow = HW.window,
            Tool = SelectedToolLabel,
            WaterWalk = WaterWalk,
            NoNotify = NotifyOff,
            SelectedShark = SelectedShark,
            SelectedTerror = SelectedTerror,
            SelectedBoat = SelectedBoat,
            StartSeaEvent = StartSeaEvent,
            Mirage = MirageFlags,
            Race = RaceFlags,
            Fruit = FruitFlags,
            ESP = ESPFlags,
            FarmMode = FarmMode,
            Farm = FarmFlags,
            Auto = AutoFlags,
        }))
    end)
    if not ok then warn("[SpectralHub] erro ao salvar:", err) end
    return ok
end

local function LoadFlags(dst, src)
    if type(src) ~= "table" then return end
    for k in pairs(dst) do
        if type(src[k]) == "boolean" then dst[k] = src[k] end
    end
end

pcall(function()
    if isfile and readfile and isfile(CONFIG_FILE) then
        local d = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(d.FastAttack) == "boolean" then FastAttackUser = d.FastAttack end
        if type(d.FarmHeight) == "number" then RACE_HEIGHT = d.FarmHeight end
        if type(d.KillRange) == "number" then KILL_AURA_RANGE = math.clamp(d.KillRange, 30, 400) end
        if type(d.KillMax) == "number" then KILL_AURA_MAX = math.clamp(d.KillMax, 1, 20) end
        if type(d.HalloweenWindow) == "number" then HW.window = math.clamp(d.HalloweenWindow, 5, 55) end
        if type(d.Tool) == "string" and TOOL_MAP[d.Tool] then SelectedToolLabel = d.Tool end
        if type(d.WaterWalk) == "boolean" then WaterWalk = d.WaterWalk end
        if type(d.NoNotify) == "boolean" then NotifyOff = d.NoNotify end
        if type(d.SelectedShark) == "boolean" then SelectedShark = d.SelectedShark end
        if type(d.SelectedTerror) == "boolean" then SelectedTerror = d.SelectedTerror end
        if type(d.StartSeaEvent) == "boolean" then StartSeaEvent = d.StartSeaEvent end
        if type(d.SelectedBoat) == "string" and table.find(BOAT_OPTIONS, d.SelectedBoat) then SelectedBoat = d.SelectedBoat end
        LoadFlags(MirageFlags, d.Mirage)
        LoadFlags(RaceFlags, d.Race)
        LoadFlags(FruitFlags, d.Fruit)
        LoadFlags(ESPFlags, d.ESP)
        LoadFlags(FarmFlags, d.Farm)
        LoadFlags(AutoFlags, d.Auto)
        if type(d.FarmMode) == "string" and table.find({"Pr\u{ED}ncipe do bolo", "Osso", "Level"}, d.FarmMode) then
            FarmMode = d.FarmMode
        end
    end
end)

local function anyTrue(t) for _, v in pairs(t) do if v then return true end end return false end

local function RaceBusy() return RaceFlags.Door or RaceFlags.Trial or RaceFlags.KillPlayers end
local function WantRaidDone() return FruitFlags.RaidDone end
local function FarmActive()
    if HW.active then return false end
    if RaceFlags.Train then return TS.farm end
    return FarmFlags.Run and FarmMode == "Osso"
end

local function Enemies() return WS:FindFirstChild("Enemies") end
local function Remote(path)
    local cur = RS
    for _, n in ipairs(path) do
        cur = cur and cur:FindFirstChild(n)
    end
    return cur
end
local function RegAttack() return Remote({"Modules","Net","RE/RegisterAttack"}) end
local function RegHit() return Remote({"Modules","Net","RE/RegisterHit"}) end
local function CommF() return Remote({"Remotes","CommF_"}) end
local function CommE() return Remote({"Remotes","CommE"}) end

local lastNotify = 0
local function Notify(msg)
    if NotifyOff then return end
    if os.clock() - lastNotify > 8 then
        lastNotify = os.clock()
        pcall(function() Rayfield:Notify({ Title = "Spectral Hub", Content = msg, Duration = 4 }) end)
    end
end
local function NotifyNow(msg, dur)
    if NotifyOff then return end
    pcall(function() Rayfield:Notify({ Title = "Spectral Hub", Content = msg, Duration = dur or 4 }) end)
end

do
    local function HasTeam()
        local t = player.Team
        return t ~= nil and (t.Name == "Pirates" or t.Name == "Marines")
    end
    local function HasBuso(char) return char and char:FindFirstChild("HasBuso") ~= nil end

    task.spawn(function()
        local lastTeam, busoFails, busoChar = 0, 0, nil
        while Alive() do
            task.wait(1)
            pcall(function()
                local cf = CommF()
                if not cf then return end
                local now = os.clock()

                if not HasTeam() then
                    if AutoFlags.Team and now - lastTeam >= 3 then
                        lastTeam = now
                        local ok, res = pcall(function() return cf:InvokeServer("SetTeam2", "Marines") end)
                        print("[SpectralHub] SetTeam2 Marines:", ok, tostring(res))
                    end
                    return
                end

                local char = player.Character
                if char ~= busoChar then busoChar, busoFails = char, 0 end
                if AutoFlags.Buso and char and char:FindFirstChildOfClass("Humanoid")
                    and not HasBuso(char) and busoFails < 3 then
                    local ok, res = pcall(function() return cf:InvokeServer("Buso") end)
                    print("[SpectralHub] Buso:", ok, tostring(res))
                    task.wait(1.5)
                    if not HasBuso(player.Character) then busoFails += 1 end
                end
            end)
        end
    end)
end

local AUTO_FILE, SCRIPT_FILE = "SpectralHub_auto_" .. tostring(player.UserId) .. ".txt", "SpectralHub.lua"
local AUTO_DIRS = { "../autoexec/", "../Autoexec/", "../autoexecute/", "../Autoexecute/", "../AutoExecute/", "autoexec/" }
local AutoExec = false
pcall(function()
    if isfile and readfile and isfile(AUTO_FILE) then AutoExec = readfile(AUTO_FILE) == "1" end
end)
local AUTO_LOADER = [[
repeat task.wait() until game:IsLoaded()
local g = getgenv and getgenv() or _G
if g.SpectralHubLoaded == game.JobId then return end
local rem = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 15)
if not rem or not rem:WaitForChild("CommF_", 5) then return end
if g.SpectralHubLoaded == game.JobId then return end
if isfile and isfile("SpectralHub.lua") then
    loadstring(readfile("SpectralHub.lua"))()
end
]]
local function SetupAutoExec(enable, silent)
    pcall(function() if writefile then writefile(AUTO_FILE, enable and "1" or "0") end end)
    if not enable then
        for _, dir in ipairs(AUTO_DIRS) do
            pcall(function() if delfile and isfile and isfile(dir .. SCRIPT_FILE) then delfile(dir .. SCRIPT_FILE) end end)
        end
        if not silent then NotifyNow("Auto executar desativado.") end
        return
    end
    local hasScript = false
    pcall(function() hasScript = isfile ~= nil and isfile(SCRIPT_FILE) end)
    local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    local queued = false
    if q then queued = pcall(q, AUTO_LOADER) end
    local wrote = {}
    for _, dir in ipairs(AUTO_DIRS) do
        if pcall(function() writefile(dir .. SCRIPT_FILE, AUTO_LOADER) end) then table.insert(wrote, dir) end
    end
    print("[SpectralHub] Auto executar: script no workspace =", hasScript,
        "| queue_on_teleport =", queued, "| pastas autoexec gravadas =", table.concat(wrote, " "))
    if silent then return end
    NotifyNow(string.format("SpectralHub.lua no workspace: %s | trocar de servidor: %s | ao entrar no jogo: %s",
        hasScript and "sim" or "N\u{C3}O (salve o script com esse nome)",
        queued and "ok" or "indispon\u{ED}vel",
        #wrote > 0 and ("ok (" .. #wrote .. " pasta)") or "sem pasta autoexec acess\u{ED}vel"), 12)
end
if AutoExec then task.spawn(SetupAutoExec, true, true) end

local mState, toggleAll, CleanBoatMovers, StatsUI = nil, nil, nil, {}
do
local function MakeTab(name, icon)
    local ok, t = pcall(function() return Window:CreateTab(name, icon) end)
    if ok and t then return t end
    return Window:CreateTab(name, 4483362458)
end
local TabFarm  = MakeTab("Auto Farm",         "warehouse")  -- celeiro/armazem
local TabFruit = MakeTab("Fruta e Raid",      "apple")
local TabRace  = MakeTab("Ra\u{E7}a V4 / Miragem", "dna")
local TabSea   = MakeTab("Sea Event",         "waves")
local TabESP   = MakeTab("ESP",               "eye")
local TabStats = MakeTab("Stats do servidor", "bar-chart-3")
local TabCfg   = MakeTab("Configura\u{E7}\u{F5}es",     "settings")
TabFarm:CreateSection("Miss\u{E3}o")
TabFarm:CreateDropdown({
    Name = "Escolher miss\u{E3}o", Options = {"Pr\u{ED}ncipe do bolo", "Osso", "Level"},
    CurrentOption = {FarmMode}, MultipleOptions = false,
    Callback = function(o)
        local v = (type(o) == "table" and o[1]) or o
        if table.find({"Pr\u{ED}ncipe do bolo", "Osso", "Level"}, v) then FarmMode = v end
    end,
})
FarmUI.Toggle = TabFarm:CreateToggle({
    Name = "Iniciar farm", CurrentValue = FarmFlags.Run,
    Callback = function(v)
        if v and FarmMode ~= "Osso" then
            NotifyNow(FarmMode .. " ainda n\u{E3}o est\u{E1} dispon\u{ED}vel. Por enquanto s\u{F3} o Osso funciona.")
            FarmFlags.Run = false
            if FarmUI.Toggle then FarmUI.Toggle:Set(false) end
            return
        end
        FarmFlags.Run = v
    end,
})
TabFarm:CreateToggle({
    Name = "Auto comprar osso", CurrentValue = FarmFlags.Buy,
    Callback = function(v) FarmFlags.Buy = v end,
})
TabFarm:CreateSection("Evento")
TabFarm:CreateToggle({
    Name = "Auto Halloween (ab\u{F3}bora + portas + boss)", CurrentValue = FarmFlags.Halloween,
    Callback = function(v) FarmFlags.Halloween = v end,
})

TabFruit:CreateSection("Frutas")
TabFruit:CreateToggle({ Name = "Auto coletar fruta", CurrentValue = FruitFlags.Collect, Callback = function(v) FruitFlags.Collect = v end })
TabFruit:CreateToggle({ Name = "Auto armazenar", CurrentValue = FruitFlags.Store, Callback = function(v) FruitFlags.Store = v end })
if not pcall(function() TabFruit:CreateDivider() end) then TabFruit:CreateLabel(" ") end
TabFruit:CreateSection("Raid")
TabFruit:CreateToggle({ Name = "Auto comprar chip", CurrentValue = FruitFlags.Chip, Callback = function(v) FruitFlags.Chip = v end })
TabFruit:CreateToggle({ Name = "Auto come\u{E7}ar raid", CurrentValue = FruitFlags.Raid, Callback = function(v) FruitFlags.Raid = v end })
TabFruit:CreateToggle({
    Name = "Auto completar raid", CurrentValue = FruitFlags.RaidDone,
    Callback = function(v)
        FruitFlags.RaidDone = v
        if v then RaidReset = true end
    end,
})

mState = { visited = {}, dwell = 0, v3Night = false, lookFrames = 0, camLocked = false }
TabRace:CreateSection("Ra\u{E7}a V4")
TrainUI.Status = TabRace:CreateLabel("Treino: desligado")
TabRace:CreateToggle({
    Name = "Auto treinar ra\u{E7}a (osso \u{2192} V4 \u{2192} esperar)", CurrentValue = RaceFlags.Train,
    Callback = function(v) RaceFlags.Train = v end,
})
TabRace:CreateToggle({ Name = "Ir at\u{E9} a porta da ra\u{E7}a", CurrentValue = RaceFlags.Door, Callback = function(v) RaceFlags.Door = v end })
TabRace:CreateToggle({ Name = "Auto completar trial", CurrentValue = RaceFlags.Trial, Callback = function(v) RaceFlags.Trial = v end })
TabRace:CreateToggle({ Name = "Auto kill player da trial", CurrentValue = RaceFlags.KillPlayers, Callback = function(v) RaceFlags.KillPlayers = v end })
TabRace:CreateSection("Miragem")
toggleAll = TabRace:CreateToggle({
    Name = "Auto Miragem (tudo em sequ\u{EA}ncia)", CurrentValue = MirageFlags.All,
    Callback = function(v)
        MirageFlags.All = v
        if v then mState.visited = {}; mState.v3Night = false; mState.dwell = 0 end
    end,
})
TabRace:CreateToggle({ Name = "Achar Miragem (navegando de barco)", CurrentValue = MirageFlags.Find, Callback = function(v) MirageFlags.Find = v end })
TabRace:CreateToggle({ Name = "Ir at\u{E9} NPC avan\u{E7}ado", CurrentValue = MirageFlags.Npc, Callback = function(v) MirageFlags.Npc = v end })
TabRace:CreateToggle({
    Name = "Pegar ba\u{FA}s", CurrentValue = MirageFlags.Chests,
    Callback = function(v) MirageFlags.Chests = v if v then mState.visited = {}; mState.dwell = 0 end end,
})
TabRace:CreateToggle({ Name = "Ir para o ponto mais alto", CurrentValue = MirageFlags.High, Callback = function(v) MirageFlags.High = v end })
TabRace:CreateToggle({
    Name = "Olhar para a lua e ativar V3 (s\u{F3} de noite)", CurrentValue = MirageFlags.Moon,
    Callback = function(v) MirageFlags.Moon = v if v then mState.v3Night = false; mState.lookFrames = 0 end end,
})

TabSea:CreateToggle({ Name = "Select Shark", CurrentValue = SelectedShark, Callback = function(v) SelectedShark = v end })
TabSea:CreateToggle({ Name = "Select Terror Shark", CurrentValue = SelectedTerror, Callback = function(v) SelectedTerror = v end })
TabSea:CreateDropdown({
    Name = "Select Boat", Options = {"PirateSloop","Speeder","SwagBoat","FlowerShip"},
    CurrentOption = {SelectedBoat}, MultipleOptions = false,
    Callback = function(o) SelectedBoat = (type(o) == "table" and o[1]) or o end,
})
TabSea:CreateToggle({
    Name = "Start Sea Event", CurrentValue = StartSeaEvent,
    Callback = function(v)
        StartSeaEvent = v
        print("[SpectralHub] Start Sea Event =", v)
        if not v and currentBoat and CleanBoatMovers then CleanBoatMovers(currentBoat) end
    end,
})

TabESP:CreateToggle({
    Name = "ESP fruta", CurrentValue = ESPFlags.Fruit,
    Callback = function(v) ESPFlags.Fruit = v if not v and ClearESP then ClearESP("Fruit") end end,
})
TabESP:CreateToggle({
    Name = "ESP player", CurrentValue = ESPFlags.Player,
    Callback = function(v) ESPFlags.Player = v if not v and ClearESP then ClearESP("Player") end end,
})

TabStats:CreateSection("Servidor")
StatsUI.Fruit = TabStats:CreateLabel("Fruta spawnada: \u{1F534}")
StatsUI.Mirage = TabStats:CreateLabel("Ilha da miragem: \u{1F534}")
StatsUI.Moon = TabStats:CreateLabel("Luas at\u{E9} a lua cheia: ...")

TabCfg:CreateSection("Combate")
TabCfg:CreateToggle({
    Name = "Fast Attack / Kill Aura", CurrentValue = FastAttackUser,
    Callback = function(v) FastAttackUser = v end,
})
TabCfg:CreateSlider({
    Name = "Alcance do Kill Aura", Range = {30, 400}, Increment = 5, Suffix = " studs",
    CurrentValue = KILL_AURA_RANGE,
    Callback = function(v) KILL_AURA_RANGE = v end,
})
TabCfg:CreateSlider({
    Name = "Inimigos por golpe (Kill Aura)", Range = {1, 20}, Increment = 1, Suffix = "",
    CurrentValue = KILL_AURA_MAX,
    Callback = function(v) KILL_AURA_MAX = v end,
})
TabCfg:CreateDropdown({
    Name = "Ferramenta de farm", Options = {"Espada", "Arma", "Fruta", "Soco"},
    CurrentOption = {SelectedToolLabel}, MultipleOptions = false,
    Callback = function(o)
        local v = (type(o) == "table" and o[1]) or o
        if TOOL_MAP[v] then SelectedToolLabel = v end
    end,
})
TabCfg:CreateSlider({
    Name = "Altitude de farm dos NPCs", Range = {0, 100}, Increment = 1, Suffix = " studs",
    CurrentValue = math.clamp(RACE_HEIGHT, 0, 100),
    Callback = function(v) RACE_HEIGHT = v end,
})
TabCfg:CreateSection("Ra\u{E7}a")
TabCfg:CreateToggle({
    Name = "Auto ra\u{E7}a V4 (ativar sozinho)", CurrentValue = FarmFlags.V4,
    Callback = function(v) FarmFlags.V4 = v end,
})
TabCfg:CreateSection("Movimento")
TabCfg:CreateToggle({
    Name = "Andar na \u{E1}gua", CurrentValue = WaterWalk,
    Callback = function(v) WaterWalk = v end,
})
TabCfg:CreateSection("Autom\u{E1}tico")
TabCfg:CreateToggle({
    Name = "Auto entrar no time Marines", CurrentValue = AutoFlags.Team,
    Callback = function(v) AutoFlags.Team = v end,
})
TabCfg:CreateToggle({
    Name = "Auto ativar Buso (Haki)", CurrentValue = AutoFlags.Buso,
    Callback = function(v) AutoFlags.Buso = v end,
})
TabCfg:CreateSection("Notifica\u{E7}\u{F5}es")
TabCfg:CreateToggle({
    Name = "Desativar notifica\u{E7}\u{F5}es", CurrentValue = NotifyOff,
    Callback = function(v) NotifyOff = v end,
})
TabCfg:CreateSection("Sistema")
TabCfg:CreateToggle({
    Name = "Auto executar", CurrentValue = AutoExec,
    Callback = function(v) AutoExec = v; SetupAutoExec(v) end,
})
TabCfg:CreateButton({
    Name = "Testar auto executar",
    Callback = function()
        if AutoExec then SetupAutoExec(true) else NotifyNow("Ligue o Auto executar primeiro.") end
    end,
})
TabCfg:CreateSection("Salvar")
TabCfg:CreateButton({
    Name = "Salvar configura\u{E7}\u{F5}es",
    Callback = function()
        if SaveSettings() then
            print("[SpectralHub] Configura\u{E7}\u{F5}es salvas")
            NotifyNow("Configura\u{E7}\u{F5}es salvas!")
        else
            print("[SpectralHub] N\u{E3}o foi poss\u{ED}vel salvar")
            NotifyNow("N\u{E3}o foi poss\u{ED}vel salvar (executor sem writefile).")
        end
    end,
})
print("[SpectralHub] 4 - toggles criados")

end
local function IsAlive(e)
    local folder = Enemies()
    if e and folder and e.Parent == folder then
        local hum = e:FindFirstChildOfClass("Humanoid")
        local hrp = e:FindFirstChild("HumanoidRootPart") or e:FindFirstChild("UpperTorso")
        if hum and hrp and hum.Health > 0 then return true, hrp end
    end
    return false, nil
end
local function IsTerror(e) return e and (e.Name == "Terrorshark" or e.Name == "Terror Shark") end

local function IsStunned(char, hum)
    if hum and hum.PlatformStand then return true end
    if not char then return false end
    for _, n in ipairs({"Stun","Stunned"}) do
        local v = char:FindFirstChild(n)
        if v then
            if v:IsA("BoolValue") and v.Value then return true end
            if (v:IsA("NumberValue") or v:IsA("IntValue")) and v.Value > 0 then return true end
        end
        local a = char:GetAttribute(n)
        if a == true or (type(a) == "number" and a > 0) then return true end
    end
    return false
end

local ATTACK_KEY = "9de8d7f4"
local function AttackList(list)
    local ra, rh = RegAttack(), RegHit()
    if not ra or not rh or #list == 0 then return end
    local hits = {}
    for i = 1, math.min(#list, KILL_AURA_MAX) do
        hits[i] = { list[i].model, list[i].hrp }
    end
    ra:FireServer(0.36666667461395, 1)
    rh:FireServer(list[1].hrp, hits, ATTACK_KEY)
end
local function EnemiesInRange(origin, radius)
    local out = {}
    local folder = Enemies()
    if not folder then return out end
    for _, e in ipairs(folder:GetChildren()) do
        local alive, hrp = IsAlive(e)
        if alive then
            local d = (hrp.Position - origin).Magnitude
            if d <= radius then table.insert(out, { model = e, hrp = hrp, d = d }) end
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

task.spawn(function()
    while Alive() do
        if FastAttackUser or AutoCombatForce then
            pcall(function()
                local char = player.Character
                local myHrp = char and char:FindFirstChild("HumanoidRootPart")
                if myHrp then AttackList(EnemiesInRange(myHrp.Position, KILL_AURA_RANGE)) end
            end)
        end
        AutoCombatForce = false
        task.wait(0.05)
    end
end)

local lastEquip = 0
local function GetSword()
    local want = TOOL_MAP[SelectedToolLabel] or SWORD_TOOLTIP
    local cs = {player.Character, player:FindFirstChild("Backpack")}
    for _, c in ipairs(cs) do
        if c then for _, i in ipairs(c:GetChildren()) do
            if i:IsA("Tool") and i.ToolTip == want then return i end
        end end
    end
    if want == SWORD_TOOLTIP then
        for _, c in ipairs(cs) do
            if c then local b = c:FindFirstChild(SWORD_NAME) if b then return b end end
        end
    end
end
local function EquipSword()
    if os.clock() - lastEquip < 0.3 then return end
    lastEquip = os.clock()
    pcall(function()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local s = GetSword()
        if hum and s and s.Parent ~= char then
            hum:EquipTool(s)
            local ev = s:FindFirstChild("EquipEvent")
            if ev then ev:FireServer(true) end
        end
    end)
end

local function GetBoatFromSeat(hum)
    local seat, boats = hum.SeatPart, WS:FindFirstChild("Boats")
    if not seat or not boats then return nil end
    local i = seat
    while i and i.Parent ~= boats do i = i.Parent end
    return i
end
local function GetMyBoat()
    local boats = WS:FindFirstChild("Boats")
    if not boats then return nil end
    local fallback
    for _, b in ipairs(boats:GetChildren()) do
        if not abandoned[b] and b.Name == SelectedBoat and b:FindFirstChildWhichIsA("VehicleSeat", true) then
            local o = b:FindFirstChild("Owner")
            if o then
                if o.Value == player or o.Value == player.Name then return b end
            else fallback = fallback or b end
        end
    end
    return fallback
end

local function FindTarget()
    local folder = Enemies()
    if not folder then return nil end
    local shark, terror
    for _, e in ipairs(folder:GetChildren()) do
        if IsAlive(e) then
            if SelectedTerror and IsTerror(e) then terror = terror or e
            elseif SelectedShark and e.Name == "Shark" then shark = shark or e end
        end
    end
    return terror or shark
end

local lastJump = 0
local function JumpOffBoat(hum)
    if os.clock() - lastJump < 0.4 then return end
    lastJump = os.clock()
    pcall(function() hum.Sit = false end)
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.delay(0.1, function() VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
    end)
end

local function MyRoot() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end
local function FlyTo(pos, dt, speed)
    local r = MyRoot() if not r then return end
    local off = pos - r.Position
    local d = off.Magnitude
    if d > 1 and d <= TP_DISTANCE then
        r.CFrame = CFrame.new(pos) * r.CFrame.Rotation
        r.AssemblyLinearVelocity = Vector3.zero
        return
    end
    if d > 1 then
        r.CFrame = CFrame.new(r.Position + off.Unit * math.min(d, speed * dt)) * r.CFrame.Rotation
    end
    r.AssemblyLinearVelocity = Vector3.zero
end
local function TeleportTo(pos)
    local r = MyRoot() if not r then return end
    r.CFrame = CFrame.new(pos) * r.CFrame.Rotation
    r.AssemblyLinearVelocity = Vector3.zero
end
local function SitOnSeat(seat, hum)
    local r = MyRoot() if not r then return end
    r.CFrame = seat.CFrame * CFrame.new(0, 2, 0)
    r.AssemblyLinearVelocity = Vector3.zero
    pcall(function() seat:Sit(hum) end)
end

local holdOn = false
local function HoldPlayer(root)
    if not root then return end
    local bv = root:FindFirstChild("SpectralHold")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "SpectralHold"
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bv.Velocity = Vector3.zero
        bv.Parent = root
    end
    holdOn = true
end
local function ReleaseHold()
    if not holdOn then return end
    holdOn = false
    local r = MyRoot()
    local bv = r and r:FindFirstChild("SpectralHold")
    if bv then bv:Destroy() end
end

local pinned = setmetatable({}, { __mode = "k" })
local function FreezeEnemy(model, hrp, at)
    if not model or not hrp then return end
    local owned = false
    if isnetworkowner then
        local ok, res = pcall(isnetworkowner, hrp)
        owned = ok and res == true
    end
    if not owned then pinned[model] = nil return end
    if at then pinned[model] = CFrame.new(at) end
    local cf = pinned[model]
    if not cf then cf = hrp.CFrame; pinned[model] = cf end
    hrp.CFrame = cf
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CanCollide = false
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = 0
        hum.JumpPower = 0
    end
end

local function Transformed()
    local char = player.Character
    if not char then return false end
    local v = char:FindFirstChild("RaceTransformed")
    if v and v:IsA("BoolValue") then return v.Value end
    return char:GetAttribute("RaceTransformed") == true
end

local function Frags()
    local d = player:FindFirstChild("Data")
    local f = d and d:FindFirstChild("Fragments")
    return f and tonumber(f.Value) or 0
end

CleanBoatMovers = function(boat)
    if not boat then return end
    for _, d in ipairs(boat:GetDescendants()) do
        if d.Name == "SpectralMover" or d.Name == "SpectralGyro" then d:Destroy() end
    end
end

local function StopBoat(boat)
    if not boat then return end
    pcall(function()
        local seat = boat:FindFirstChildWhichIsA("VehicleSeat", true)
        if seat then
            seat.Throttle = 0
            local root = seat.AssemblyRootPart or seat
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

local pivotAccum = setmetatable({}, { __mode = "k" })
local function RigidBoatFly(boat, seat, target, speed, dt)
    local root = seat.AssemblyRootPart or seat
    local off = target - seat.Position
    local dist = off.Magnitude
    if dist > 3 then
        local dir = off.Unit
        local vel = dir * math.min(speed, dist * 5)
        root.AssemblyLinearVelocity = vel
        root.AssemblyAngularVelocity = Vector3.zero

        pivotAccum[boat] = (pivotAccum[boat] or 0) + dt
        if pivotAccum[boat] >= 0.1 then
            local acc = pivotAccum[boat]
            pivotAccum[boat] = 0
            local pv = boat:GetPivot()
            local np = pv.Position + vel * PIVOT_ASSIST * acc
            local flat = Vector3.new(dir.X, 0, dir.Z)
            if flat.Magnitude > 0.01 then boat:PivotTo(CFrame.lookAt(np, np + flat))
            else boat:PivotTo(CFrame.new(np) * pv.Rotation) end
        end
        pcall(function() seat.Throttle = 1 end)
    else
        root.AssemblyLinearVelocity = Vector3.zero
        pivotAccum[boat] = 0
        pcall(function() seat.Throttle = 0 end)
    end
end

local isBuying, lastSit = false, 0
local westDir = WEST.Unit

local function GetBoatChecked(hum, root)
    local boat = GetBoatFromSeat(hum) or GetMyBoat()
    if boat then
        local seatedHere = hum.SeatPart and hum.SeatPart:IsDescendantOf(boat)
        if not seatedHere and (boat:GetPivot().Position - root.Position).Magnitude > MAX_BOAT_DISTANCE then
            print("[SpectralHub] Barco longe demais, comprando outro")
            abandoned[boat] = true
            CleanBoatMovers(boat)
            boat = nil
        end
    end
    return boat
end

local function SailStep(hum, root, dt, boat)
    if not boat then
        local cf = CommF()
        if not isBuying and cf then
            isBuying = true
            pcall(function() cf:InvokeServer("BuyBoat", SelectedBoat) end)
            task.wait(1.5)
            isBuying = false
        end
        return
    end

    local seat = (hum.SeatPart and hum.SeatPart:IsDescendantOf(boat) and hum.SeatPart)
        or boat:FindFirstChildWhichIsA("VehicleSeat", true)
    if not seat then return end

    local seated = hum.SeatPart ~= nil and hum.SeatPart:IsDescendantOf(boat)
    if not seated then
        FlyTo(seat.Position + Vector3.new(0, 2, 0), dt, 250)
        if (root.Position - seat.Position).Magnitude <= 8 and os.clock() - lastSit >= 0.3 then
            lastSit = os.clock()
            SitOnSeat(seat, hum)
        end
        return
    end

    local pos = seat.Position
    RigidBoatFly(boat, seat, Vector3.new(pos.X, FLY_HEIGHT, pos.Z) + westDir * 1000, FLY_SPEED, dt)
end

do
local noclipParts = {}
local lastNoclipRebuild, lastBoatForNoclip = 0, nil
local function RebuildNoclipParts()
    table.clear(noclipParts)
    local char = player.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then table.insert(noclipParts, p) end
        end
    end
    if currentBoat and currentBoat.Parent then
        for _, p in ipairs(currentBoat:GetDescendants()) do
            if p:IsA("BasePart") then table.insert(noclipParts, p) end
        end
    end
end
local function ApplyNoclip()
    if not (StartSeaEvent or anyTrue(MirageFlags) or anyTrue(RaceFlags) or RaidNoclip
        or FarmFlags.Run or FarmFlags.Halloween or TS.farm or TS.waiting) then return end
    local now = os.clock()
    if now - lastNoclipRebuild > 1 or lastBoatForNoclip ~= currentBoat then
        lastNoclipRebuild = now
        lastBoatForNoclip = currentBoat
        RebuildNoclipParts()
    end
    for _, p in ipairs(noclipParts) do
        if p.Parent then p.CanCollide = false end
    end
end
local steppedConn
steppedConn = Run.Stepped:Connect(function()
    if not Alive() then steppedConn:Disconnect() return end
    pcall(ApplyNoclip)
end)

local charConn
charConn = player.CharacterAdded:Connect(function()
    if not Alive() then charConn:Disconnect() return end
    lastNoclipRebuild = 0
    holdOn = false
    task.wait(0.5)
    pcall(function()
        if ClearESP then ClearESP("Fruit") ClearESP("Player") end
    end)
end)

end
local function InstPos(i)
    if not i then return nil end
    if i:IsA("BasePart") then return i.Position end
    if i:IsA("Model") then return i:GetPivot().Position end
    local p = i:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end
local function GetMirage()
    local m = WS:FindFirstChild("Map")
    local isl = m and m:FindFirstChild("MysticIsland")
    if isl and InstPos(isl) then return isl end
    return nil
end
local function GetHighest(island)
    local n = island:FindFirstChild(HIGHEST_PART_NAME, true)
    if n and n:IsA("BasePart") then return n.Position + Vector3.new(0, n.Size.Y/2 + 5, 0) end
    local chests = island:FindFirstChild("Chests")
    local bt, bp
    for _, d in ipairs(island:GetDescendants()) do
        if d:IsA("BasePart") and d.Size.X * d.Size.Z >= 25 and not (chests and d:IsDescendantOf(chests)) then
            local top = d.Position.Y + d.Size.Y/2
            if not bt or top > bt then bt, bp = top, d end
        end
    end
    if bp then return Vector3.new(bp.Position.X, bt + 5, bp.Position.Z) end
end
local function TouchInst(i, root)
    local part = i:IsA("BasePart") and i or i:FindFirstChildWhichIsA("BasePart", true)
    if part and firetouchinterest then
        pcall(function() firetouchinterest(root, part, 0) firetouchinterest(root, part, 1) end)
    end
end
local function IsNight() local t = Lighting.ClockTime return t >= NIGHT_START or t < NIGHT_END end
local function ReleaseCamera()
    if mState.camLocked then
        mState.camLocked, mState.lookFrames = false, 0
        local c = WS.CurrentCamera
        if c then c.CameraType = Enum.CameraType.Custom end
    end
end

local function ActivateV3()
    pcall(function()
        local ce = CommE()
        if ce then ce:FireServer("ActivateAbility") else warn("[SpectralHub] CommE n\u{E3}o encontrado") end
    end)
end

local Steps = {}

Steps.Find = function(root, dt, hold, hum)
    local isl = GetMirage()
    if not isl then
        local boat = GetBoatChecked(hum, root)
        currentBoat = boat
        Notify("Procurando a Miragem de barco...")
        SailStep(hum, root, dt, boat)
        return false
    end
    if currentBoat then
        CleanBoatMovers(currentBoat)
        StopBoat(currentBoat)
        currentBoat = nil
    end
    local pos = InstPos(isl)
    FlyTo(Vector3.new(pos.X, pos.Y + 200, pos.Z), dt, MIRAGE_SPEED)
    return Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z).Magnitude < 300
end
Steps.Npc = function(root, dt)
    local isl = GetMirage()
    if not isl then Notify("Miragem n\u{E3}o encontrada.") return false end
    local f = isl:FindFirstChild("npcspawn")
    local kids = f and f:GetChildren() or {}
    local pos = InstPos(kids[MIRAGE_NPC_INDEX] or kids[#kids])
    if not pos then Notify("NPC avan\u{E7}ado n\u{E3}o encontrado.") return false end
    local goal = pos + Vector3.new(0, 3, 0)
    FlyTo(goal, dt, MIRAGE_SPEED)
    return (root.Position - goal).Magnitude < 12
end
Steps.Chests = function(root, dt)
    local isl = GetMirage()
    if not isl then Notify("Miragem n\u{E3}o encontrada.") return false end
    local f = isl:FindFirstChild("Chests")
    if not f then Notify("Pasta Chests n\u{E3}o encontrada.") return false end
    local best, bp, bd
    for _, c in ipairs(f:GetChildren()) do
        if not mState.visited[c] then
            local p = InstPos(c)
            if p then
                local d = (p - root.Position).Magnitude
                if not bd or d < bd then best, bp, bd = c, p, d end
            end
        end
    end
    if not best then return true end
    FlyTo(bp + Vector3.new(0, 2, 0), dt, MIRAGE_SPEED)
    if bd <= 8 then
        mState.dwell += dt
        if mState.dwell >= CHEST_DWELL then
            TouchInst(best, root)
            mState.visited[best] = true
            mState.dwell = 0
        end
    else mState.dwell = 0 end
    return false
end
Steps.High = function(root, dt)
    local isl = GetMirage()
    if not isl then Notify("Miragem n\u{E3}o encontrada.") return false end
    local pos = GetHighest(isl)
    if not pos then Notify("Ponto mais alto n\u{E3}o encontrado.") return false end
    FlyTo(pos, dt, MIRAGE_SPEED)
    return (root.Position - pos).Magnitude < 6
end
Steps.Moon = function(root, dt, hold)
    if hold then
        local isl = GetMirage()
        local pos = isl and GetHighest(isl)
        if pos then FlyTo(pos, dt, MIRAGE_SPEED) end
    end
    if not IsNight() then
        ReleaseCamera(); mState.v3Night = false
        Notify("Esperando anoitecer para ativar o V3...")
        return false
    end
    if mState.v3Night then ReleaseCamera() return true end
    local cam = WS.CurrentCamera
    if not cam then return false end
    local moon = Lighting:GetMoonDirection()
    mState.camLocked = true
    cam.CameraType = Enum.CameraType.Scriptable
    local cp = cam.CFrame.Position
    cam.CFrame = CFrame.lookAt(cp, cp + moon)
    if cam.CFrame.LookVector:Dot(moon) > 0.99 then
        mState.lookFrames += 1
        if mState.lookFrames >= 10 then
            ActivateV3(); mState.v3Night = true
            print("[SpectralHub] V3 ativado (ActivateAbility)")
            ReleaseCamera()
            return true
        end
    else mState.lookFrames = 0 end
    return false
end

task.spawn(function()
    local order = {"Find","Npc","Chests","High","Moon"}
    local idx, lastAll = 1, false
    while Alive() do
        local dt = Run.Heartbeat:Wait()
        if anyTrue(MirageFlags) and not StartSeaEvent and not HW.boss then
            local ok, err = pcall(function()
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not hum or not root then return end

                if MirageFlags.All and not lastAll then idx = 1 end

                local step
                if MirageFlags.All then step = order[idx]
                else
                    for _, n in ipairs(order) do
                        if MirageFlags[n] then step = n break end
                    end
                end
                if not step then return end

                if hum.SeatPart and (step ~= "Find" or GetMirage()) then
                    if currentBoat then CleanBoatMovers(currentBoat); StopBoat(currentBoat); currentBoat = nil end
                    JumpOffBoat(hum)
                    return
                end

                if step ~= "Find" then currentBoat = nil end

                local done = Steps[step](root, dt, MirageFlags.All, hum)
                if MirageFlags.All and done then
                    if idx >= #order then
                        MirageFlags.All = false
                        Notify("Sequ\u{EA}ncia da Miragem conclu\u{ED}da!")
                        if toggleAll then toggleAll:Set(false) end
                    else idx += 1; mState.dwell = 0 end
                end
                lastAll = MirageFlags.All
            end)
            if not ok then warn("[SpectralHub] erro na Miragem:", err) end
        else
            pcall(ReleaseCamera)
        end
    end
end)

local function FindCastleHitbox()
    local map = WS:FindFirstChild("Map")
    local castle = (map and map:FindFirstChild("Boat Castle")) or WS:FindFirstChild("Boat Castle", true)
    if not castle then return nil end
    local cp = InstPos(castle)
    if cp then BOAT_CASTLE_POS = cp end
    for _, n in ipairs(HITBOX_NAMES) do
        local m = castle:FindFirstChild(n, true)
        local h = m and m:FindFirstChild("Hitbox")
        if h and h:IsA("BasePart") then return h end
    end
    return nil
end

task.spawn(function()
    while Alive() do
        pcall(FindCastleHitbox)
        task.wait(3)
    end
end)

UseCastleHitbox = function()
    if hitboxBusy then return end
    if not TREE_NPC_POS then
        NotifyNow("Salve primeiro a posi\u{E7}\u{E3}o do NPC (bot\u{E3}o acima).")
        return
    end
    local root = MyRoot()
    if not root then return end

    local hb = FindCastleHitbox()
    if not hb and BOAT_CASTLE_POS then
        hitboxBusy = true
        Notify("Carregando o Boat Castle...")
        pcall(function() player:RequestStreamAroundAsync(BOAT_CASTLE_POS) end)
        local t0 = os.clock()
        while not hb and os.clock() - t0 < 8 do
            task.wait(0.25)
            hb = FindCastleHitbox()
        end
        hitboxBusy = false
    end
    if not hb then
        NotifyNow("Boat Castle n\u{E3}o encontrado. Veja o console (F9).")
        local map = WS:FindFirstChild("Map")
        local names = {}
        if map then
            for _, c in ipairs(map:GetChildren()) do table.insert(names, c.Name) end
        end
        print("[SpectralHub] Boat Castle n\u{E3}o achado. Filhos de Map:", table.concat(names, ", "))
        print("[SpectralHub] Posi\u{E7}\u{E3}o usada para carregar:", tostring(BOAT_CASTLE_POS))
        return
    end

    hitboxBusy = true
    Notify("Teleportando pela hitbox do Boat Castle...")
    local originalCF = hb.CFrame
    local originalTouch = hb.CanTouch
    print("[SpectralHub] Usando hitbox:", hb:GetFullName())

    pcall(function()
        hb.CanTouch = true
        hb.CFrame = CFrame.new(TREE_NPC_POS)
        root.CFrame = CFrame.new(TREE_NPC_POS) * root.CFrame.Rotation
        root.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.15)
        if firetouchinterest then
            firetouchinterest(root, hb, 0)
            task.wait(0.1)
            firetouchinterest(root, hb, 1)
        else
            warn("[SpectralHub] firetouchinterest n\u{E3}o existe no seu executor")
        end
        task.wait(1.5)
    end)

    pcall(function()
        hb.CFrame = originalCF
        hb.CanTouch = originalTouch
    end)
    print("[SpectralHub] Hitbox devolvida ao lugar original")
    hitboxBusy = false
end

local function IsFruitName(i) return i:IsA("Tool") and i.Name:find("Fruit") ~= nil end
local function WorldFruits()
    local list = {}
    for _, c in ipairs(WS:GetChildren()) do
        if IsFruitName(c) and c:FindFirstChild("Handle") then table.insert(list, c) end
    end
    return list
end

task.spawn(function()
    local pulled = setmetatable({}, { __mode = "k" })
    while Alive() do
        task.wait(0.3)
        if FruitFlags.Collect and not HW.boss then
            pcall(function()
                local root = MyRoot()
                if not root then return end
                for _, f in ipairs(WorldFruits()) do
                    local h = f:FindFirstChild("Handle")
                    if h then
                        local first = pulled[f]
                        if not first then pulled[f] = os.clock() end
                        if first and os.clock() - first > 2 then
                            TeleportTo(h.Position + Vector3.new(0, 3, 0))
                        else
                            h.CFrame = root.CFrame
                        end
                        if firetouchinterest then
                            firetouchinterest(root, h, 0)
                            firetouchinterest(root, h, 1)
                        end
                    end
                end
            end)
        end
    end
end)

local storeTry = setmetatable({}, { __mode = "k" })
local function FruitStoreName(tool)
    local n = tool:GetAttribute("OriginalName") or tool:GetAttribute("FruitName")
    if type(n) == "string" and n ~= "" then return n end
    local base = tool.Name:gsub("%s*Fruit%s*$", "")
    return base .. "-" .. base
end
task.spawn(function()
    while Alive() do
        task.wait(1)
        if FruitFlags.Store then
            pcall(function()
                local cf = CommF()
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not cf or not hum then return end
                for _, container in ipairs({char, player:FindFirstChild("Backpack")}) do
                    if container then
                        for _, t in ipairs(container:GetChildren()) do
                            if IsFruitName(t) then
                                local rec = storeTry[t]
                                local now = os.clock()
                                if not rec or (rec.n < 2 and now - rec.t > 8) then
                                    rec = rec or { n = 0, t = 0 }
                                    rec.n += 1
                                    rec.t = now
                                    storeTry[t] = rec
                                    if t.Parent ~= char then
                                        pcall(function() hum:EquipTool(t) end)
                                        task.wait(0.3)
                                    end
                                    local ok, res = pcall(function()
                                        return cf:InvokeServer("StoreFruit", FruitStoreName(t), t)
                                    end)
                                    print("[SpectralHub] StoreFruit:", t.Name, ok, res)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

local function HasChip()
    for _, c in ipairs({player.Character, player:FindFirstChild("Backpack")}) do
        if c and c:FindFirstChild("Special Microchip") then return true end
    end
    return false
end

task.spawn(function()
    local lastChip = 0
    while Alive() do
        task.wait(1)
        if FruitFlags.Chip and not HasChip() and os.clock() - lastChip > 6 then
            lastChip = os.clock()
            local cf = CommF()
            if cf then
                local ok, res = pcall(function() return cf:InvokeServer("RaidsNpc", "Select", CHIP_NAME) end)
                print("[SpectralHub] Comprar chip:", CHIP_NAME, ok, res)
            end
        end
    end
end)

do
local islandCache = { t = 0, list = {} }

local function FlatDist(a, b) return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end

local function IslandBox(isl)
    local parts = {}
    if isl:IsA("BasePart") then table.insert(parts, isl) end
    for _, d in ipairs(isl:GetDescendants()) do
        if d:IsA("BasePart") then table.insert(parts, d) end
    end
    if #parts == 0 then return nil end
    local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
    local topY, botY = -math.huge, math.huge
    for _, p in ipairs(parts) do
        local half = math.max(p.Size.X, p.Size.Z) / 2
        local pos = p.Position
        minX, maxX = math.min(minX, pos.X - half), math.max(maxX, pos.X + half)
        minZ, maxZ = math.min(minZ, pos.Z - half), math.max(maxZ, pos.Z + half)
        topY = math.max(topY, pos.Y + p.Size.Y / 2)
        botY = math.min(botY, pos.Y - p.Size.Y / 2)
    end
    return {
        isl = isl,
        center = Vector3.new((minX + maxX) / 2, topY, (minZ + maxZ) / 2),
        radius = math.min(math.max(maxX - minX, maxZ - minZ) / 2, 800),
        top = topY, bottom = botY,
    }
end

local function RaidIslands()
    if os.clock() - islandCache.t < 2 then return islandCache.list end
    islandCache.t = os.clock()
    local list = {}
    local map = WS:FindFirstChild("Map")
    local rm = map and map:FindFirstChild("RaidMap")
    if rm then
        for _, d in ipairs(rm:GetDescendants()) do
            if d.Name:match("^RaidIsland%d+$") and (d:IsA("Model") or d:IsA("Folder") or d:IsA("BasePart")) then
                local box = IslandBox(d)
                if box then
                    box.index = tonumber(d.Name:match("^RaidIsland(%d+)$"))
                    table.insert(list, box)
                end
            end
        end
    end
    islandCache.list = list
    return list
end

local standCache = setmetatable({}, { __mode = "k" })
local function StandPos(box)
    local c = standCache[box.isl]
    if c and os.clock() - c.t < 5 then return c.pos end
    local cx, cz = box.center.X, box.center.Z
    local pos = Vector3.new(cx, box.top + 4, cz)
    pcall(function()
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Include
        rp.FilterDescendantsInstances = { box.isl }
        local res = WS:Raycast(Vector3.new(cx, box.top + 100, cz),
            Vector3.new(0, -(box.top - box.bottom + 300), 0), rp)
        if res then pos = Vector3.new(cx, res.Position.Y + 4, cz) end
    end)
    standCache[box.isl] = { pos = pos, t = os.clock() }
    return pos
end

local function MyIsland(pos)
    local best, bd
    for _, b in ipairs(RaidIslands()) do
        local d = FlatDist(pos, b.center)
        if d <= b.radius + ISLAND_MARGIN and pos.Y >= b.bottom - 300 and pos.Y <= b.top + 600 then
            if not bd or d < bd then best, bd = b, d end
        end
    end
    if best then return best end
    for _, b in ipairs(RaidIslands()) do
        local d = (pos - b.center).Magnitude
        if d <= RAID_NEAR_MAX and (not bd or d < bd) then best, bd = b, d end
    end
    return best
end

local nilCache, nilStamp = {}, 0
local function NilModels()
    if not getnilinstances then return {} end
    if os.clock() - nilStamp < 20 then return nilCache end
    nilStamp = os.clock()
    local out = {}
    pcall(function()
        for _, v in next, getnilinstances() do
            if v.ClassName == "Model" and not Players:GetPlayerFromCharacter(v) then
                if v:FindFirstChildOfClass("Humanoid") and v:FindFirstChild("HumanoidRootPart") then
                    table.insert(out, v)
                end
            end
        end
    end)
    nilCache = out
    return out
end

local function RaidEnemies(box, useNil)
    local out = {}
    local limit = box.radius + ISLAND_MARGIN
    local folder = Enemies()
    if folder then
        for _, e in ipairs(folder:GetChildren()) do
            local alive, hrp = IsAlive(e)
            if alive and FlatDist(hrp.Position, box.center) <= limit then
                table.insert(out, { model = e, hrp = hrp })
            end
        end
    end
    if #out > 0 or not useNil then return out, false end
    for _, m in ipairs(NilModels()) do
        local h = m:FindFirstChildOfClass("Humanoid")
        local r = m:FindFirstChild("HumanoidRootPart")
        if h and r and h.Health > 0 and FlatDist(r.Position, box.center) <= limit then
            table.insert(out, { model = m, hrp = r })
        end
    end
    return out, #out > 0
end

local function FindTravelTarget(tf)
    local best, bd
    for _, b in ipairs(RaidIslands()) do
        if b.index == tf.index then
            local d = FlatDist(b.center, tf.center)
            if d <= NEXT_ISLAND_MAX_DIST and (not bd or d < bd) then best, bd = b, d end
        end
    end
    return best
end

task.spawn(function()
    local current, hoverPos, nilFor, travelFrom = nil, nil, 0, nil
    local sawEnemy, emptyFor = false, 0
    local lastHit, lastAct, lastDbg = 0, 0, 0
    while Alive() do
        local dt = Run.Heartbeat:Wait()
        if RaidReset then
            current, hoverPos, nilFor, travelFrom, sawEnemy, emptyFor, RaidReset = nil, nil, 0, nil, false, 0, false
        end
        if WantRaidDone() and not StartSeaEvent and not anyTrue(MirageFlags) and not RaceBusy() and not HW.boss then
            local ok, err = pcall(function()
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not hum or not root then RaidNoclip = false return end
                if hum.SeatPart then JumpOffBoat(hum) return end

                local box = MyIsland(root.Position)

                if travelFrom then
                    local target = FindTravelTarget(travelFrom)
                    if target and box and box.isl == target.isl then
                        print("[SpectralHub] Raid: cheguei na", target.isl.Name)
                        travelFrom = nil
                        current, hoverPos, nilFor, sawEnemy, emptyFor = box, nil, 0, false, 0
                    elseif target then
                        ReleaseHold()
                        RaidNoclip = true
                        FlyTo(StandPos(target) + Vector3.new(0, 5, 0), dt, MIRAGE_SPEED)
                        return
                    elseif not box then
                        travelFrom = nil
                    elseif #RaidEnemies(box, false) > 0 then
                        travelFrom = nil
                    else
                        ReleaseHold()
                        RaidNoclip = true
                        FlyTo(StandPos(box) + Vector3.new(0, 5, 0), dt, MIRAGE_SPEED)
                        Notify("Esperando a RaidIsland" .. travelFrom.index .. " nascer...")
                        return
                    end
                end

                if not box then
                    ReleaseHold()
                    current, hoverPos, nilFor, sawEnemy, emptyFor, RaidNoclip = nil, nil, 0, false, 0, false
                    Notify("Aguardando voc\u{EA} ser levado para a ilha da raid...")
                    return
                end
                if not current or current.isl ~= box.isl then
                    hoverPos, nilFor, sawEnemy, emptyFor = nil, 0, false, 0
                    print("[SpectralHub] Raid: agora na ilha", box.isl:GetFullName(),
                        "| meio da ilha =", tostring(StandPos(box)))
                end
                current = box
                RaidNoclip = true

                local enemies, fromNil = RaidEnemies(box, nilFor < 10)
                if fromNil then nilFor += dt else nilFor = 0 end

                if os.clock() - lastDbg >= 3 then
                    lastDbg = os.clock()
                    print(string.format("[SpectralHub] Raid: %s | inimigos na ilha: %d%s",
                        box.isl.Name, #enemies, fromNil and " (nil)" or ""))
                end

                if #enemies > 0 then
                    sawEnemy, emptyFor = true, 0
                    EquipSword()

                    local best, bd = nil, math.huge
                    for _, en in ipairs(enemies) do
                        en.d = (en.hrp.Position - root.Position).Magnitude
                        if en.d < bd then best, bd = en, en.d end
                    end

                    FlyTo(best.hrp.Position + Vector3.new(0, RACE_HEIGHT, 0), dt, 300)
                    HoldPlayer(root)
                    hoverPos = root.Position

                    if os.clock() - lastHit >= 0.05 then
                        lastHit = os.clock()
                        local inRange = {}
                        for _, en in ipairs(enemies) do
                            if en.d <= KILL_AURA_RANGE then table.insert(inRange, en) end
                        end
                        table.sort(inRange, function(a, b) return a.d < b.d end)
                        AttackList(inRange)
                    end
                    if os.clock() - lastAct >= 0.25 then
                        lastAct = os.clock()
                        local tool = GetSword()
                        if not tool then
                            Notify("Nenhuma ferramenta do tipo '" .. SelectedToolLabel .. "' encontrada.")
                        elseif tool.Parent == char then
                            pcall(function() tool:Activate() end)
                        end
                    end
                    return
                end

                ReleaseHold()
                local stand = StandPos(box) + Vector3.new(0, 5, 0)
                FlyTo(stand, dt, MIRAGE_SPEED)
                if (root.Position - stand).Magnitude <= 25 then emptyFor += dt else emptyFor = 0 end
                if emptyFor >= (sawEnemy and ISLAND_CLEAR_WAIT or ISLAND_EMPTY_SKIP) then
                    emptyFor = 0
                    if box.index and box.index < RAID_LAST_ISLAND then
                        travelFrom = { index = box.index + 1, center = box.center }
                        sawEnemy = false
                        print("[SpectralHub] Raid: ilha limpa, indo para a ilha", box.index + 1)
                    elseif sawEnemy then
                        sawEnemy = false
                        Notify("Raid completa: ilha " .. RAID_LAST_ISLAND .. " limpa!")
                    end
                end
            end)
            if not ok then warn("[SpectralHub] erro no Auto completar raid:", err) end
        else
            RaidNoclip = false
            if not FarmActive() and not RaceBusy() and not HW.active then ReleaseHold() end
        end
    end
end)

end
do
local function GetRaidClick()
    local map = WS:FindFirstChild("Map")
    local castle = map and map:FindFirstChild("Boat Castle")
    local s = castle and castle:FindFirstChild("RaidSummon2")
    local b = s and s:FindFirstChild("Button")
    local m = b and b:FindFirstChild("Main")
    return m and m:FindFirstChildOfClass("ClickDetector")
end
local function RaidHitbox()
    local map = WS:FindFirstChild("Map")
    local castle = map and map:FindFirstChild("Boat Castle")
    local m = castle and castle:FindFirstChild("MapTeleportA")
    local h = m and m:FindFirstChild("Hitbox")
    if h and h:IsA("BasePart") then return h end
    return FindCastleHitbox()
end
local function PullRaidHitbox()
    if hitboxBusy then return end
    local root = MyRoot()
    if not root then return end
    local hb = RaidHitbox()
    if not hb and BOAT_CASTLE_POS then
        hitboxBusy = true
        Notify("Carregando o Boat Castle...")
        pcall(function() player:RequestStreamAroundAsync(BOAT_CASTLE_POS) end)
        local t0 = os.clock()
        while not hb and os.clock() - t0 < 8 do
            task.wait(0.25)
            hb = RaidHitbox()
        end
        hitboxBusy = false
    end
    if not hb then Notify("Hitbox do Boat Castle n\u{E3}o encontrada.") return end
    hitboxBusy = true
    local origCF, origTouch = hb.CFrame, hb.CanTouch
    pcall(function()
        hb.CanTouch = true
        hb.CFrame = root.CFrame
        if firetouchinterest then
            firetouchinterest(root, hb, 0)
            task.wait(0.1)
            firetouchinterest(root, hb, 1)
        end
        task.wait(0.8)
    end)
    pcall(function()
        hb.CFrame = origCF
        hb.CanTouch = origTouch
    end)
    hitboxBusy = false
    print("[SpectralHub] Hitbox puxada para o personagem:", hb:GetFullName())
end

task.spawn(function()
    local lastClick, tries = 0, 0
    while Alive() do
        task.wait(1)
        if not HasChip() then
            tries = 0
        elseif FruitFlags.Raid and os.clock() - lastClick > 5 then
            pcall(function()
                PullRaidHitbox()
                local cd = GetRaidClick()
                if not cd and BOAT_CASTLE_POS then
                    Notify("Carregando o Boat Castle...")
                    pcall(function() player:RequestStreamAroundAsync(BOAT_CASTLE_POS) end)
                    local t0 = os.clock()
                    while not cd and os.clock() - t0 < 8 do
                        task.wait(0.25)
                        cd = GetRaidClick()
                    end
                end
                lastClick = os.clock()
                if not cd then Notify("Bot\u{E3}o da raid n\u{E3}o encontrado.") return end
                tries += 1
                local part = cd.Parent
                if tries > 1 and part and part:IsA("BasePart") then
                    TeleportTo(part.Position + Vector3.new(0, 5, 0))
                    task.wait(0.3)
                end
                if fireclickdetector then
                    fireclickdetector(cd)
                    print("[SpectralHub] Clique na raid enviado")
                else
                    warn("[SpectralHub] fireclickdetector n\u{E3}o existe no seu executor")
                end
            end)
        end
    end
end)

end
-- ===== AUTO HALLOWEEN =====
-- Fora do evento: farma aboboras e mata os NPCs de Halloween que spawnam.
-- Evento (primeiros HW.window min de cada hora): portas + E + NPCs.
-- Porta do boss spawnou: ignora tudo e vai matar o boss. Acabou: volta para as aboboras.
do
    local DOOR_START_INDEX, BOSS_DOOR_INDEX = 135, 123
    local BOSS_NAME = "Hellfire Gas"
    local HOLD_E_TIME, MOB_SEARCH_RADIUS = 2, 350
    local DOOR_MARKERS    = { "hallow", "pumpkin", "jack", "spook", "ghost", "skull" }
    local PUMPKIN_MARKERS = { "pumpkin", "abobora", "halloween" }
    local ENEMY_MARKERS   = { "jack", "lantern", "pumpkin", "ghost", "skull", "spook", "hallow" }

    local function hasAny(name, list)
        name = name:lower()
        for _, m in ipairs(list) do if name:find(m, 1, true) then return true end end
        return false
    end

    -- ---------- portas ----------
    local function DoorFolder()
        local m = WS:FindFirstChild("Map")
        local d = m and m:FindFirstChild("Dressrosa")
        return d and d:FindFirstChild("Dressrosa")
    end
    local function IsHalloweenDoor(d)
        if hasAny(d.Name, DOOR_MARKERS) then return true end
        for _, x in ipairs(d:GetDescendants()) do
            if hasAny(x.Name, DOOR_MARKERS) then return true end
        end
        return false
    end
    local function HalloweenDoors()
        local out, f = {}, DoorFolder()
        if not f then return out end
        for i, d in ipairs(f:GetChildren()) do
            if i == DOOR_START_INDEX or (i ~= BOSS_DOOR_INDEX and IsHalloweenDoor(d)) then
                local p = InstPos(d)
                if p then table.insert(out, { idx = i, inst = d, pos = p }) end
            end
        end
        return out
    end
    local function BossDoorFrame()
        local f = DoorFolder()
        local d = f and f:GetChildren()[BOSS_DOOR_INDEX]
        return d and d:FindFirstChild("Frame")
    end
    local function BossModel()
        local e = Enemies()
        local b = e and e:FindFirstChild(BOSS_NAME)
        local alive, hrp = IsAlive(b)
        if alive then return b, hrp end
    end

    -- ---------- interacao ----------
    local function PressE(down)
        pcall(function() VIM:SendKeyEvent(down, Enum.KeyCode.E, false, game) end)
    end
    local function FirePrompts(inst)
        if not fireproximityprompt then return end
        if inst:IsA("ProximityPrompt") then pcall(fireproximityprompt, inst) end
        for _, x in ipairs(inst:GetDescendants()) do
            if x:IsA("ProximityPrompt") then pcall(fireproximityprompt, x) end
        end
    end
    local function FireClicks(inst)
        if not fireclickdetector then return end
        if inst:IsA("ClickDetector") then pcall(fireclickdetector, inst) end
        for _, x in ipairs(inst:GetDescendants()) do
            if x:IsA("ClickDetector") then pcall(fireclickdetector, x) end
        end
    end
    local function Hit(char, model, hrp)
        AttackList({ { model = model, hrp = hrp } })
        local tool = GetSword()
        if tool and tool.Parent == char then pcall(function() tool:Activate() end) end
    end

    -- ---------- NPCs ----------
    local function NearestMob(origin, radius)       -- qualquer inimigo perto (fase do evento)
        local best, bd, bh
        local f = Enemies()
        if not f then return end
        for _, e in ipairs(f:GetChildren()) do
            if e.Name ~= BOSS_NAME then
                local alive, hrp = IsAlive(e)
                if alive then
                    local d = (hrp.Position - origin).Magnitude
                    if d <= radius and (not bd or d < bd) then best, bd, bh = e, d, hrp end
                end
            end
        end
        return best, bh
    end
    local function HalloweenMob(origin)             -- NPC de Halloween em qualquer lugar (fase das aboboras)
        local best, bd, bh
        local f = Enemies()
        if not f then return end
        for _, e in ipairs(f:GetChildren()) do
            if e.Name ~= BOSS_NAME and hasAny(e.Name, ENEMY_MARKERS) then
                local alive, hrp = IsAlive(e)
                if alive then
                    local d = (hrp.Position - origin).Magnitude
                    if not bd or d < bd then best, bd, bh = e, d, hrp end
                end
            end
        end
        return best, bh
    end

    -- ---------- aboboras ----------
    local pumpkins = {}                                   -- [instancia] = true
    local pumpkinBad = setmetatable({}, { __mode = "k" }) -- instancia -> ignorar ate
    local function InCharacter(x)
        local m = x:FindFirstAncestorWhichIsA("Model")
        while m do
            if m:FindFirstChildOfClass("Humanoid") then return true end
            m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model")
        end
        return false
    end
    local function Consider(x)
        local cand
        if x:IsA("ClickDetector") or x:IsA("ProximityPrompt") then
            local p = x.Parent
            if not p then return end
            if not (hasAny(p.Name, PUMPKIN_MARKERS) or (p.Parent and hasAny(p.Parent.Name, PUMPKIN_MARKERS))) then return end
            cand = p
        elseif x:IsA("Model") or x:IsA("BasePart") then
            if not hasAny(x.Name, PUMPKIN_MARKERS) then return end
            cand = x
        else
            return
        end
        local en, df = Enemies(), DoorFolder()
        if (en and cand:IsDescendantOf(en)) or (df and cand:IsDescendantOf(df)) then return end
        if InCharacter(cand) then return end
        local a = cand
        while a and a ~= WS do
            if pumpkins[a] then return end
            a = a.Parent
        end
        pumpkins[cand] = true
    end
    task.spawn(function()
        local n = 0
        for _, x in ipairs(WS:GetDescendants()) do
            if not Alive() then return end
            pcall(Consider, x)
            n += 1
            if n % 3000 == 0 then task.wait() end
        end
        local c, shown = 0, 0
        for inst in pairs(pumpkins) do
            c += 1
            if shown < 8 then shown += 1 print("[SpectralHub] abobora:", inst:GetFullName()) end
        end
        print("[SpectralHub] Halloween: aboboras encontradas no mapa agora =", c)
    end)
    local addConn
    addConn = WS.DescendantAdded:Connect(function(x)
        if not Alive() then addConn:Disconnect() return end
        pcall(Consider, x)
    end)
    local function NextPumpkin(origin)
        local best, bp, bd
        for inst in pairs(pumpkins) do
            if not inst.Parent then
                pumpkins[inst] = nil
            elseif not (pumpkinBad[inst] and pumpkinBad[inst] > os.clock()) then
                local p = InstPos(inst)
                if p then
                    local d = (p - origin).Magnitude
                    if not bd or d < bd then best, bp, bd = inst, p, d end
                end
            end
        end
        return best, bp
    end

    local S = { visited = {}, cur = nil, dwell = 0, pressed = false, reenter = false, lastHour = -1,
                bossKilled = false, sawBoss = false, enteredAt = nil, pk = nil, pkT = 0, pkAct = 0 }

    local function HookDeath(char)
        local hum = char:WaitForChild("Humanoid", 10)
        if hum then hum.Died:Connect(function() S.reenter = true end) end
    end
    if player.Character then task.spawn(HookDeath, player.Character) end
    player.CharacterAdded:Connect(function(c) task.spawn(HookDeath, c) end)

    task.spawn(function()
        local lastHit = 0
        while Alive() do
            local dt = Run.Heartbeat:Wait()
            local ok, err = pcall(function()
                HW.active = FarmFlags.Halloween      -- ligado: o farm de osso fica pausado
                if not FarmFlags.Halloween then
                    HW.boss = false
                    if S.pressed then PressE(false); S.pressed = false end
                    return
                end

                local t = os.date("*t")
                if t.hour ~= S.lastHour then
                    S.lastHour = t.hour
                    S.visited, S.cur, S.dwell, S.pressed = {}, nil, 0, false
                    S.bossKilled, S.sawBoss, S.enteredAt = false, false, nil
                end
                local boss, bossHrp = BossModel()
                local frame = BossDoorFrame()
                local inWindow = t.min < HW.window
                if boss then S.sawBoss = true
                elseif S.sawBoss and not S.reenter then S.bossKilled, S.sawBoss = true, false end
                local wantBoss = not S.bossKilled and (boss ~= nil or (frame ~= nil and inWindow))
                HW.boss = wantBoss and true or false
                local eventOn = inWindow or boss ~= nil

                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not hum or not root or hum.Health <= 0 then return end
                if hum.SeatPart then JumpOffBoat(hum) return end
                EquipSword()

                -- 1) BOSS: prioridade maxima
                if wantBoss then
                    if S.pressed then PressE(false); S.pressed = false end
                    if boss and bossHrp and (bossHrp.Position - root.Position).Magnitude <= 500 then
                        S.reenter, S.enteredAt = false, nil
                        FlyTo(bossHrp.Position + Vector3.new(0, RACE_HEIGHT, 0), dt, 300)
                        HoldPlayer(root)
                        Hit(char, boss, bossHrp)
                        return
                    end
                    if S.enteredAt and os.clock() - S.enteredAt < 12 then
                        HoldPlayer(root)
                        return
                    end
                    S.enteredAt = nil
                    ReleaseHold()
                    if frame then
                        local p = InstPos(frame)
                        FlyTo(p, dt, MIRAGE_SPEED)
                        if (root.Position - p).Magnitude <= 10 then
                            if firetouchinterest then
                                pcall(function() firetouchinterest(root, frame, 0) firetouchinterest(root, frame, 1) end)
                            end
                            S.enteredAt = os.clock()
                        end
                    elseif boss and bossHrp then
                        FlyTo(bossHrp.Position + Vector3.new(0, RACE_HEIGHT, 0), dt, MIRAGE_SPEED)
                    end
                    return
                end

                -- 2) FORA DO EVENTO: aboboras + NPCs de Halloween
                if not eventOn then
                    if S.pressed then PressE(false); S.pressed = false end
                    local mob, mobHrp = HalloweenMob(root.Position)
                    if mob then
                        FlyTo(mobHrp.Position + Vector3.new(0, RACE_HEIGHT, 0), dt, 300)
                        HoldPlayer(root)
                        Hit(char, mob, mobHrp)
                        return
                    end
                    ReleaseHold()
                    local inst, p = NextPumpkin(root.Position)
                    if not inst then
                        S.pk = nil
                        Notify("Procurando aboboras...")
                        return
                    end
                    local target = p + Vector3.new(0, 3, 0)
                    FlyTo(target, dt, MIRAGE_SPEED)
                    if (root.Position - target).Magnitude <= 8 then
                        if S.pk ~= inst then S.pk, S.pkT = inst, os.clock() end
                        if os.clock() - S.pkAct >= 0.3 then
                            S.pkAct = os.clock()
                            FirePrompts(inst)
                            FireClicks(inst)
                            TouchInst(inst, root)
                        end
                        if os.clock() - S.pkT > 6 then          -- nao sumiu: pula e volta depois
                            pumpkinBad[inst] = os.clock() + 30
                            S.pk = nil
                        end
                    end
                    return
                end

                -- 3) EVENTO: NPC perto da porta
                local mob, mobHrp = NearestMob(root.Position, MOB_SEARCH_RADIUS)
                if mob and S.cur and S.visited[S.cur.idx] then
                    FlyTo(mobHrp.Position + Vector3.new(0, RACE_HEIGHT, 0), dt, 300)
                    HoldPlayer(root)
                    Hit(char, mob, mobHrp)
                    return
                end
                ReleaseHold()

                -- 4) EVENTO: ciclo de portas (E por 2s em cada)
                local doors = HalloweenDoors()
                if #doors == 0 then Notify("Nenhuma porta de Halloween encontrada.") return end
                if not S.cur or S.visited[S.cur.idx] then
                    local best, bd
                    for _, d in ipairs(doors) do
                        if not S.visited[d.idx] then
                            local dd = (d.pos - root.Position).Magnitude
                            if not bd or dd < bd then best, bd = d, dd end
                        end
                    end
                    if not best then S.visited = {} return end
                    S.cur, S.dwell, S.pressed = best, 0, false
                end
                local target = S.cur.pos + Vector3.new(0, 3, 0)
                FlyTo(target, dt, MIRAGE_SPEED)
                if (root.Position - target).Magnitude <= 8 then
                    if not S.pressed then PressE(true); S.pressed = true; FirePrompts(S.cur.inst) end
                    S.dwell += dt
                    if S.dwell >= HOLD_E_TIME then
                        PressE(false); S.pressed = false
                        S.visited[S.cur.idx] = true
                    end
                else
                    S.dwell = 0
                end
            end)
            if not ok then warn("[SpectralHub] erro no Auto Halloween:", err) end
        end
    end)
end

-- ===== AUTO FARM OSSO (reconstruido) =====
do
    local NPC_1 = Vector3.new(-9479.2168, 141.215088, 5566.09277)
    local NPC_2 = Vector3.new(-9516.9931640625, 172.01779174804688, 6078.46533203125)
    local BONE_MOBS = {
        { level = 1975, name = "Reborn Skeleton", quest = "HauntedQuest1", qlvl = 1, npc = NPC_1 },
        { level = 2000, name = "Demonic Soul",    quest = "HauntedQuest2", qlvl = 1, npc = NPC_2 },
        { level = 2025, name = "Posessed Mummy",  quest = "HauntedQuest2", qlvl = 2, npc = NPC_2 },
    }
    local function MyLevel()
        local d = player:FindFirstChild("Data")
        local l = d and d:FindFirstChild("Level")
        return l and tonumber(l.Value) or 0
    end
    local function PickMob()
        local lvl, pick = MyLevel(), BONE_MOBS[1]
        for _, m in ipairs(BONE_MOBS) do if lvl >= m.level then pick = m end end
        return pick
    end
    local function HasQuest()
        local gui = player:FindFirstChild("PlayerGui")
        local main = gui and gui:FindFirstChild("Main")
        local q = main and main:FindFirstChild("Quest")
        return q ~= nil and q.Visible == true
    end

    -- comprar osso
    task.spawn(function()
        while Alive() do
            task.wait(3)
            if FarmFlags.Buy and not HW.active then
                pcall(function()
                    local cf = CommF()
                    if cf then cf:InvokeServer("Bones", "Buy", 1, 1) end
                end)
            end
        end
    end)

    task.spawn(function()
        local wentToFarm, lastQuest, lastHit, lastAct = false, 0, 0, 0
        while Alive() do
            local dt = Run.Heartbeat:Wait()
            local want = FarmFlags.Run and FarmMode == "Osso" and not HW.active
                and not StartSeaEvent and not anyTrue(MirageFlags) and not RaceBusy()
                and not WantRaidDone()
            TS.farm = want
            if not want then
                wentToFarm = false
            else
                local ok, err = pcall(function()
                    local char = player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if not hum or not root or hum.Health <= 0 then return end
                    if hum.SeatPart then JumpOffBoat(hum) return end
                    EquipSword()

                    if not wentToFarm then
                        FlyTo(FARM_POS, dt, MIRAGE_SPEED)
                        if (root.Position - FARM_POS).Magnitude <= 15 then wentToFarm = true end
                        return
                    end

                    local mob = PickMob()
                    if not HasQuest() then
                        ReleaseHold()
                        local goal = mob.npc + Vector3.new(0, 3, 0)
                        FlyTo(goal, dt, MIRAGE_SPEED)
                        if (root.Position - goal).Magnitude <= 12 and os.clock() - lastQuest > 1.5 then
                            lastQuest = os.clock()
                            local cf = CommF()
                            if cf then pcall(function() cf:InvokeServer("StartQuest", mob.quest, mob.qlvl) end) end
                        end
                        return
                    end

                    local best, bh, bd
                    local folder = Enemies()
                    if folder then
                        for _, e in ipairs(folder:GetChildren()) do
                            if e.Name == mob.name then
                                local alive, hrp = IsAlive(e)
                                if alive then
                                    local d = (hrp.Position - root.Position).Magnitude
                                    if not bd or d < bd then best, bh, bd = e, hrp, d end
                                end
                            end
                        end
                    end
                    if not best then
                        ReleaseHold()
                        FlyTo(FARM_POS, dt, MIRAGE_SPEED)
                        return
                    end
                    FlyTo(bh.Position + Vector3.new(0, RACE_HEIGHT, 0), dt, 300)
                    HoldPlayer(root)
                    if os.clock() - lastHit >= 0.05 then
                        lastHit = os.clock()
                        AttackList(EnemiesInRange(root.Position, KILL_AURA_RANGE))
                    end
                    if os.clock() - lastAct >= 0.25 then
                        lastAct = os.clock()
                        local tool = GetSword()
                        if tool and tool.Parent == char then pcall(function() tool:Activate() end) end
                    end
                end)
                if not ok then warn("[SpectralHub] erro no farm de osso:", err) end
            end
        end
    end)
end

print("[SpectralHub] 5 - tudo carregado")
end -- fim de main()

local ok, err = pcall(main)
if not ok then warn("[SpectralHub] ERRO FATAL:", err) end
