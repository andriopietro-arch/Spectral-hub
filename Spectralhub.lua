--[[
    SpectralHub v7.4
    - Em qualquer voo: voa normal e, quando faltarem 750 studs ou menos para o destino, teleporta
    - Auto treinar raça: farma osso no ponto de farm -> V4 ativa: espera no ponto alto -> V4 acabou:
      tenta comprar upgrade e volta a farmar (sem raid/fragmentos)
    - Auto farm osso / treino: ao ligar vão primeiro para o ponto de farm (-9517, 142, 5543)
    - Raid: não puxa/trava mais os NPCs (dessincronizava com o servidor)
    - Iniciar raid: puxa Map["Boat Castle"].MapTeleportA.Hitbox para o personagem antes de clicar no botão
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

-- Cada execução ganha um número; instâncias antigas encerram seus loops sozinhas
local G = (getgenv and getgenv()) or _G
G.SpectralHubGen = (G.SpectralHubGen or 0) + 1
local myGen = G.SpectralHubGen
local function Alive() return G.SpectralHubGen == myGen end
print("[SpectralHub] execução número", myGen)
pcall(function()
    local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local bv = r and r:FindFirstChild("SpectralHold")
    if bv then bv:Destroy() end
end)

-- Limpeza de execuções anteriores (reexecutar não pode travar)
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

-- UI -------------------------------------------------------
local Rayfield
for _, url in ipairs({
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
}) do
    local ok, res = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and res then Rayfield = res break end
    warn("[SpectralHub] falha no Rayfield:", url, res)
end
if not Rayfield then warn("[SpectralHub] ERRO: Rayfield não carregou") return end
pcall(function() if G.SpectralHubUI and G.SpectralHubUI ~= Rayfield then G.SpectralHubUI:Destroy() end end)
G.SpectralHubUI = Rayfield
print("[SpectralHub] 2 - Rayfield ok")

local Window = Rayfield:CreateWindow({
    Name = "Spectral Hub", LoadingTitle = "Spectral Hub", LoadingSubtitle = "v7.4",
    ConfigurationSaving = { Enabled = false },
})

print("[SpectralHub] 3 - abas criadas")

-- CONFIG ---------------------------------------------------
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
local FarmFlags = { Run=false, Buy=false, V4=false }
local AutoFlags = { Team=true, Buso=true }
local FarmMode = "Osso"
local FarmUI = {}
local TrainUI = {}
local CHIP_NAME = "Ice"
local ClearESP

-- Estado do "Auto treinar raça" (controlado pelo orquestrador lá embaixo)
local TS = { farm = false, waiting = false }
local FARM_POS = Vector3.new(-9517, 142, 5543)    -- ponto de farm do osso
local WAIT_POS = Vector3.new(-9523, 3933, 6727)   -- onde espera a V4 acabar
local TP_DISTANCE = 750                           -- voa até faltar 750 studs, aí teleporta para o destino

local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "SpectralHub_config.json"

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
        if type(d.FarmMode) == "string" and table.find({"Príncipe do bolo", "Osso", "Level"}, d.FarmMode) then
            FarmMode = d.FarmMode
        end
    end
end)

local function anyTrue(t) for _, v in pairs(t) do if v then return true end end return false end

-- Helpers de "quem está ligado" (misturam as opções do usuário com o Auto treinar raça)
local function RaceBusy() return RaceFlags.Door or RaceFlags.Trial or RaceFlags.KillPlayers end
local function WantRaidDone() return FruitFlags.RaidDone end
local function FarmActive()
    if RaceFlags.Train then return TS.farm end
    return FarmFlags.Run and FarmMode == "Osso"
end

-- Acesso preguiçoso ----------------------------------------
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

-- Auto entrar no time (Marines) + Auto Buso -----------------
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

-- Auto executar --------------------------------------------
local AUTO_FILE, SCRIPT_FILE = "SpectralHub_auto.txt", "SpectralHub.lua"
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
        hasScript and "sim" or "NÃO (salve o script com esse nome)",
        queued and "ok" or "indisponível",
        #wrote > 0 and ("ok (" .. #wrote .. " pasta)") or "sem pasta autoexec acessível"), 12)
end
if AutoExec then task.spawn(SetupAutoExec, true, true) end

local mState, toggleAll, CleanBoatMovers, StatsUI = nil, nil, nil, {}
-- UI: Auto Farm --------------------------------------------
do
-- Abas criadas na ORDEM desejada, cada uma com um ícone (Lucide). Se o ícone não existir, usa o padrão.
local function MakeTab(name, icon)
    local ok, t = pcall(function() return Window:CreateTab(name, icon) end)
    if ok and t then return t end
    return Window:CreateTab(name, 4483362458)
end
local TabFarm  = MakeTab("Auto Farm",         "warehouse")  -- celeiro/armazém
local TabFruit = MakeTab("Fruta e Raid",      "apple")
local TabRace  = MakeTab("Raça V4 / Miragem", "dna")
local TabSea   = MakeTab("Sea Event",         "waves")
local TabESP   = MakeTab("ESP",               "eye")
local TabStats = MakeTab("Stats do servidor", "bar-chart-3")
local TabCfg   = MakeTab("Configurações",     "settings")
TabFarm:CreateSection("Missão")
TabFarm:CreateDropdown({
    Name = "Escolher missão", Options = {"Príncipe do bolo", "Osso", "Level"},
    CurrentOption = {FarmMode}, MultipleOptions = false,
    Callback = function(o)
        local v = (type(o) == "table" and o[1]) or o
        if table.find({"Príncipe do bolo", "Osso", "Level"}, v) then FarmMode = v end
    end,
})
FarmUI.Toggle = TabFarm:CreateToggle({
    Name = "Iniciar farm", CurrentValue = FarmFlags.Run,
    Callback = function(v)
        if v and FarmMode ~= "Osso" then
            NotifyNow(FarmMode .. " ainda não está disponível. Por enquanto só o Osso funciona.")
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

-- UI: Fruta e Raid ----------------------------------------
TabFruit:CreateSection("Frutas")
TabFruit:CreateToggle({ Name = "Auto coletar fruta", CurrentValue = FruitFlags.Collect, Callback = function(v) FruitFlags.Collect = v end })
TabFruit:CreateToggle({ Name = "Auto armazenar", CurrentValue = FruitFlags.Store, Callback = function(v) FruitFlags.Store = v end })
if not pcall(function() TabFruit:CreateDivider() end) then TabFruit:CreateLabel(" ") end
TabFruit:CreateSection("Raid")
TabFruit:CreateToggle({ Name = "Auto comprar chip", CurrentValue = FruitFlags.Chip, Callback = function(v) FruitFlags.Chip = v end })
TabFruit:CreateToggle({ Name = "Auto começar raid", CurrentValue = FruitFlags.Raid, Callback = function(v) FruitFlags.Raid = v end })
TabFruit:CreateToggle({
    Name = "Auto completar raid", CurrentValue = FruitFlags.RaidDone,
    Callback = function(v)
        FruitFlags.RaidDone = v
        if v then RaidReset = true end
    end,
})

-- UI: Raça / Miragem ---------------------------------------
mState = { visited = {}, dwell = 0, v3Night = false, lookFrames = 0, camLocked = false }
TabRace:CreateSection("Raça V4")
TrainUI.Status = TabRace:CreateLabel("Treino: desligado")
TabRace:CreateToggle({
    Name = "Auto treinar raça (osso → V4 → esperar)", CurrentValue = RaceFlags.Train,
    Callback = function(v) RaceFlags.Train = v end,
})
TabRace:CreateToggle({ Name = "Ir até a porta da raça", CurrentValue = RaceFlags.Door, Callback = function(v) RaceFlags.Door = v end })
TabRace:CreateToggle({ Name = "Auto completar trial", CurrentValue = RaceFlags.Trial, Callback = function(v) RaceFlags.Trial = v end })
TabRace:CreateToggle({ Name = "Auto kill player da trial", CurrentValue = RaceFlags.KillPlayers, Callback = function(v) RaceFlags.KillPlayers = v end })
TabRace:CreateSection("Miragem")
toggleAll = TabRace:CreateToggle({
    Name = "Auto Miragem (tudo em sequência)", CurrentValue = MirageFlags.All,
    Callback = function(v)
        MirageFlags.All = v
        if v then mState.visited = {}; mState.v3Night = false; mState.dwell = 0 end
    end,
})
TabRace:CreateToggle({ Name = "Achar Miragem (navegando de barco)", CurrentValue = MirageFlags.Find, Callback = function(v) MirageFlags.Find = v end })
TabRace:CreateToggle({ Name = "Ir até NPC avançado", CurrentValue = MirageFlags.Npc, Callback = function(v) MirageFlags.Npc = v end })
TabRace:CreateToggle({
    Name = "Pegar baús", CurrentValue = MirageFlags.Chests,
    Callback = function(v) MirageFlags.Chests = v if v then mState.visited = {}; mState.dwell = 0 end end,
})
TabRace:CreateToggle({ Name = "Ir para o ponto mais alto", CurrentValue = MirageFlags.High, Callback = function(v) MirageFlags.High = v end })
TabRace:CreateToggle({
    Name = "Olhar para a lua e ativar V3 (só de noite)", CurrentValue = MirageFlags.Moon,
    Callback = function(v) MirageFlags.Moon = v if v then mState.v3Night = false; mState.lookFrames = 0 end end,
})

-- UI: Sea Event --------------------------------------------
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

-- UI: ESP --------------------------------------------------
TabESP:CreateToggle({
    Name = "ESP fruta", CurrentValue = ESPFlags.Fruit,
    Callback = function(v) ESPFlags.Fruit = v if not v and ClearESP then ClearESP("Fruit") end end,
})
TabESP:CreateToggle({
    Name = "ESP player", CurrentValue = ESPFlags.Player,
    Callback = function(v) ESPFlags.Player = v if not v and ClearESP then ClearESP("Player") end end,
})

-- UI: Stats do servidor ------------------------------------
TabStats:CreateSection("Servidor")
StatsUI.Fruit = TabStats:CreateLabel("Fruta spawnada: 🔴")
StatsUI.Mirage = TabStats:CreateLabel("Ilha da miragem: 🔴")
StatsUI.Moon = TabStats:CreateLabel("Luas até a lua cheia: ...")

-- UI: Configurações ----------------------------------------
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
TabCfg:CreateSection("Raça")
TabCfg:CreateToggle({
    Name = "Auto raça V4 (ativar sozinho)", CurrentValue = FarmFlags.V4,
    Callback = function(v) FarmFlags.V4 = v end,
})
TabCfg:CreateSection("Movimento")
TabCfg:CreateToggle({
    Name = "Andar na água", CurrentValue = WaterWalk,
    Callback = function(v) WaterWalk = v end,
})
TabCfg:CreateSection("Automático")
TabCfg:CreateToggle({
    Name = "Auto entrar no time Marines", CurrentValue = AutoFlags.Team,
    Callback = function(v) AutoFlags.Team = v end,
})
TabCfg:CreateToggle({
    Name = "Auto ativar Buso (Haki)", CurrentValue = AutoFlags.Buso,
    Callback = function(v) AutoFlags.Buso = v end,
})
TabCfg:CreateSection("Notificações")
TabCfg:CreateToggle({
    Name = "Desativar notificações", CurrentValue = NotifyOff,
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
    Name = "Salvar configurações",
    Callback = function()
        if SaveSettings() then
            print("[SpectralHub] Configurações salvas")
            NotifyNow("Configurações salvas!")
        else
            print("[SpectralHub] Não foi possível salvar")
            NotifyNow("Não foi possível salvar (executor sem writefile).")
        end
    end,
})
print("[SpectralHub] 4 - toggles criados")

end
-- FUNÇÕES --------------------------------------------------
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

-- Fast Attack / Kill Aura
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

-- Anti-tremedeira: segura o player parado no ar e trava os NPCs no lugar ---
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
    -- Só mexe no NPC se eu controlo a física dele; senão o servidor não vê e dá dessincronia
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

-- Noclip Otimizado -----------------------------------------
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
        or FarmFlags.Run or TS.farm or TS.waiting) then return end
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
-- Miragem --------------------------------------------------
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
        if ce then ce:FireServer("ActivateAbility") else warn("[SpectralHub] CommE não encontrado") end
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
    if not isl then Notify("Miragem não encontrada.") return false end
    local f = isl:FindFirstChild("npcspawn")
    local kids = f and f:GetChildren() or {}
    local pos = InstPos(kids[MIRAGE_NPC_INDEX] or kids[#kids])
    if not pos then Notify("NPC avançado não encontrado.") return false end
    local goal = pos + Vector3.new(0, 3, 0)
    FlyTo(goal, dt, MIRAGE_SPEED)
    return (root.Position - goal).Magnitude < 12
end
Steps.Chests = function(root, dt)
    local isl = GetMirage()
    if not isl then Notify("Miragem não encontrada.") return false end
    local f = isl:FindFirstChild("Chests")
    if not f then Notify("Pasta Chests não encontrada.") return false end
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
    if not isl then Notify("Miragem não encontrada.") return false end
    local pos = GetHighest(isl)
    if not pos then Notify("Ponto mais alto não encontrado.") return false end
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
        if anyTrue(MirageFlags) and not StartSeaEvent then
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
                        Notify("Sequência da Miragem concluída!")
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

-- Hitbox do Boat Castle ------------------------------------
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
        NotifyNow("Salve primeiro a posição do NPC (botão acima).")
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
        NotifyNow("Boat Castle não encontrado. Veja o console (F9).")
        local map = WS:FindFirstChild("Map")
        local names = {}
        if map then
            for _, c in ipairs(map:GetChildren()) do table.insert(names, c.Name) end
        end
        print("[SpectralHub] Boat Castle não achado. Filhos de Map:", table.concat(names, ", "))
        print("[SpectralHub] Posição usada para carregar:", tostring(BOAT_CASTLE_POS))
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
            warn("[SpectralHub] firetouchinterest não existe no seu executor")
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

-- Frutas / Raid --------------------------------------------
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
        if FruitFlags.Collect then
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

-- Auto completar raid --------------------------------------
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
        if WantRaidDone() and not StartSeaEvent and not anyTrue(MirageFlags) and not RaceBusy() then
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
                    Notify("Aguardando você ser levado para a ilha da raid...")
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

                    -- NÃO mexe nos NPCs da raid (puxar/travar dessincroniza com o servidor)
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
            if not FarmActive() and not RaceBusy() then ReleaseHold() end
        end
    end
end)

end
-- Auto começar raid ----------------------------------------
do
local function GetRaidClick()
    local map = WS:FindFirstChild("Map")
    local castle = map and map:FindFirstChild("Boat Castle")
    local s = castle and castle:FindFirstChild("RaidSummon2")
    local b = s and s:FindFirstChild("Button")
    local m = b and b:FindFirstChild("Main")
    return m and m:FindFirstChildOfClass("ClickDetector")
end
-- Puxa a Hitbox (Map["Boat Castle"].MapTeleportA.Hitbox) para dentro do personagem
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
    if not hb then Notify("Hitbox do Boat Castle não encontrada.") return end
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
                if not cd then Notify("Botão da raid não encontrado.") return end
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
                    warn("[SpectralHub] fireclickdetector não existe no seu executor")
                end
            end)
        end
    end
end)

end
-- Auto Farm: Osso ------------------------------------------
-- Target lock (só troca de alvo quando o atual morre), pega o MAIS PRÓXIMO,
-- NPCs travados no lugar, player preso no ar e missão iniciada SEM ir até o NPC.
do
    local NPC_1 = Vector3.new(-9479.2168, 141.215088, 5566.09277)
    local NPC_2 = Vector3.new(-9516.9931640625, 172.01779174804688, 6078.46533203125)
    local BONE_MOBS = {
        { level = 1975, name = "Reborn Skeleton", keys = { "Reborn Skeleton" },                 quest = "HauntedQuest1", idx = 1, npc = NPC_1, area = Vector3.new(-8763.7236, 165.7232, 6159.8613) },
        { level = 2000, name = "Living Zombie",   keys = { "Living Zombie" },                   quest = "HauntedQuest1", idx = 2, npc = NPC_1, area = Vector3.new(-10144.1318, 138.6274, 5838.0888) },
        { level = 2025, name = "Demonic Soul",    keys = { "Demonic Soul" },                    quest = "HauntedQuest2", idx = 1, npc = NPC_2, area = Vector3.new(-9505.8721, 172.1049, 6158.9931) },
        { level = 2050, name = "Posessed Mummy",  keys = { "Posessed Mummy", "Possessed Mummy" }, quest = "HauntedQuest2", idx = 2, npc = NPC_2, area = Vector3.new(-9582.0225, 6.2515, 6205.4785) },
    }
    local BRING_RADIUS = 350

    local function MyLevel()
        local d = player:FindFirstChild("Data")
        local l = d and d:FindFirstChild("Level")
        return l and tonumber(l.Value) or 0
    end

    local function UnlockedMobs(level)
        local list = {}
        for _, m in ipairs(BONE_MOBS) do
            if level >= m.level then table.insert(list, m) end
        end
        return list
    end

    local function NameMatches(text, mob)
        text = tostring(text):lower()
        for _, k in ipairs(mob.keys) do
            if text:find(k:lower(), 1, true) then return true end
        end
        return false
    end
    local function QuestText()
        local pg = player:FindFirstChild("PlayerGui")
        local main = pg and pg:FindFirstChild("Main")
        local q = main and main:FindFirstChild("Quest")
        if not q or not q.Visible then return nil end
        local parts = {}
        for _, d in ipairs(q:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text ~= "" then table.insert(parts, d.Text:lower()) end
        end
        return #parts > 0 and table.concat(parts, " ") or nil
    end
    local function StemMatch(name, qtext)
        if not qtext then return false end
        local n = 0
        for w in tostring(name):lower():gmatch("%a+") do
            if #w >= 3 then
                n += 1
                local stem = #w > 3 and w:sub(1, #w - 1) or w
                if not qtext:find(stem, 1, true) then return false end
            end
        end
        return n >= 2
    end
    local function MobMatch(name, mob, qtext)
        return NameMatches(name, mob) or StemMatch(name, qtext)
    end

    local function QuestActive(mob)
        local pg = player:FindFirstChild("PlayerGui")
        local main = pg and pg:FindFirstChild("Main")
        local q = main and main:FindFirstChild("Quest")
        if not q then return nil end
        if not q.Visible then return false end
        local this, other = false, false
        for _, d in ipairs(q:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text ~= "" then
                if NameMatches(d.Text, mob) then
                    this = true
                else
                    for _, m2 in ipairs(BONE_MOBS) do
                        if m2 ~= mob and NameMatches(d.Text, m2) then other = true end
                    end
                end
            end
        end
        return this or not other
    end
    local function NearbyNames(root)
        local seen, list = {}, {}
        local folder = Enemies()
        if folder then
            for _, e in ipairs(folder:GetChildren()) do
                local r = e:FindFirstChild("HumanoidRootPart")
                if r and (r.Position - root.Position).Magnitude <= 700 and not seen[e.Name] then
                    seen[e.Name] = true
                    table.insert(list, e.Name)
                    if #list >= 8 then break end
                end
            end
        end
        return #list > 0 and table.concat(list, ", ") or "(nenhum)"
    end

    local function StillAlive(model)
        if not model or not model.Parent then return false, nil end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso")
        if hum and hrp and hum.Health > 0 then return true, hrp end
        return false, nil
    end

    local function AllUnlockedAlive(unlocked, qtext)
        local out = {}
        local folder = Enemies()
        if not folder then return out end
        for _, e in ipairs(folder:GetChildren()) do
            for _, mob in ipairs(unlocked) do
                if MobMatch(e.Name, mob, qtext) then
                    local alive, hrp = StillAlive(e)
                    if alive then table.insert(out, { model = e, hrp = hrp, mob = mob }) end
                    break
                end
            end
        end
        return out
    end

    local spawnCache = {}
    local function SpawnPositions(mob, qtext)
        local key = mob.name .. "|" .. tostring(qtext)
        local c = spawnCache[key]
        if c and os.clock() - c.t < 10 then return c.list end
        local out = {}
        local wo = WS:FindFirstChild("_WorldOrigin")
        if wo then
            local folder = wo:FindFirstChild("EnemySpawns")
            for _, p in ipairs((folder or wo):GetDescendants()) do
                if (p:IsA("BasePart") or p:IsA("Model")) and MobMatch(p.Name, mob, qtext) then
                    local pos = InstPos(p)
                    if pos then table.insert(out, pos) end
                end
            end
        end
        spawnCache[key] = { t = os.clock(), list = out }
        return out
    end

    task.spawn(function()
        local LockedTarget, LockedMob = nil, nil

        local missionIdx = 1
        local curMissionMob = nil
        local starting, startingSince = false, 0
        local lastTry, lastDbg, lastSim = 0, 0, 0
        local spawnIdx, spawnSince = 1, os.clock()
        local lastHit, lastAct = 0, 0
        local lastQText = nil
        local fails = 0
        local wasActive, needGoFarm = false, false

        while Alive() do
            local dt = Run.Heartbeat:Wait()
            if FarmActive() and not StartSeaEvent and not anyTrue(MirageFlags)
                and not RaceBusy() and not WantRaidDone() then
                local ok, err = pcall(function()
                    local char = player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if not hum or not root then return end
                    if hum.SeatPart then JumpOffBoat(hum) return end

                    local level = MyLevel()
                    local unlocked = UnlockedMobs(level)
                    if #unlocked == 0 then
                        Notify("O farm de Osso precisa de nível 1975+ (seu nível: " .. level .. ").")
                        return
                    end

                    local now = os.clock()
                    if now - lastSim > 5 then
                        lastSim = now
                        pcall(function()
                            if sethiddenproperty then sethiddenproperty(player, "SimulationRadius", 4000) end
                        end)
                    end

                    -- Ao ligar o farm (ou voltar da espera da V4) vai primeiro ao ponto de farm
                    if not wasActive then wasActive, needGoFarm = true, true end
                    if needGoFarm then
                        FlyTo(FARM_POS, dt, MIRAGE_SPEED)
                        if (root.Position - FARM_POS).Magnitude <= 20 then
                            needGoFarm = false
                        else
                            return
                        end
                    end

                    local qtext = QuestText()
                    if qtext ~= lastQText then
                        lastQText = qtext
                        print("[SpectralHub] Texto da missão:", tostring(qtext))
                    end

                    -- 1) TARGET LOCK
                    local lockedAlive, lockedHrp = StillAlive(LockedTarget)
                    if lockedAlive then
                        EquipSword()
                        local base = lockedHrp.Position

                        -- alvo principal fica parado no lugar
                        FreezeEnemy(LockedTarget, lockedHrp)
                        base = lockedHrp.Position

                        -- player fica parado no ar em cima do alvo (sem tremer)
                        FlyTo(base + Vector3.new(0, RACE_HEIGHT, 0), dt, 300)
                        HoldPlayer(root)

                        -- outros mobs desbloqueados próximos são puxados e ficam parados também
                        local nearby = AllUnlockedAlive(unlocked, qtext)
                        for _, m in ipairs(nearby) do
                            if m.model ~= LockedTarget and (m.hrp.Position - base).Magnitude <= BRING_RADIUS then
                                pcall(function() FreezeEnemy(m.model, m.hrp, base) end)
                            end
                        end

                        if now - lastHit >= 0.05 then
                            lastHit = now
                            local inRange = { { model = LockedTarget, hrp = lockedHrp, d = (lockedHrp.Position - root.Position).Magnitude } }
                            for _, m in ipairs(nearby) do
                                if m.model ~= LockedTarget then
                                    local d = (m.hrp.Position - root.Position).Magnitude
                                    if d <= KILL_AURA_RANGE then table.insert(inRange, { model = m.model, hrp = m.hrp, d = d }) end
                                end
                            end
                            table.sort(inRange, function(a, b) return a.d < b.d end)
                            AttackList(inRange)
                        end
                        if now - lastAct >= 0.25 then
                            lastAct = now
                            local tool = GetSword()
                            if not tool then
                                Notify("Nenhuma ferramenta do tipo '" .. SelectedToolLabel .. "' encontrada.")
                            elseif tool.Parent == char then
                                pcall(function() tool:Activate() end)
                            end
                        end

                        if now - lastDbg >= 3 then
                            lastDbg = now
                            print("[SpectralHub] Farm Osso: alvo travado =", LockedTarget.Name)
                        end

                        spawnSince = now
                        return
                    end

                    if LockedTarget then
                        print("[SpectralHub] Farm Osso: alvo", LockedTarget.Name, "morreu/sumiu, liberando")
                    end
                    LockedTarget, LockedMob = nil, nil
                    ReleaseHold()

                    -- 2) trava no inimigo desbloqueado vivo MAIS PRÓXIMO
                    local aliveList = AllUnlockedAlive(unlocked, qtext)
                    if #aliveList > 0 then
                        local best, bd = nil, math.huge
                        for _, e in ipairs(aliveList) do
                            local d = (e.hrp.Position - root.Position).Magnitude
                            if d < bd then best, bd = e, d end
                        end
                        if best then
                            LockedTarget, LockedMob = best.model, best.mob
                            pinned[best.model] = nil
                            fails = 0
                            print("[SpectralHub] Farm Osso: travando no alvo mais próximo ->", best.model.Name)
                        end
                        return
                    end

                    -- 3) ninguém vivo: verifica se já existe missão ativa
                    local activeMob = nil
                    for _, m in ipairs(unlocked) do
                        if QuestActive(m) then activeMob = m break end
                    end

                    if not activeMob then
                        -- Sem missão: pega uma remotamente (NÃO vai até o NPC)
                        if curMissionMob == nil or not table.find(unlocked, curMissionMob) then
                            missionIdx = ((missionIdx - 1) % #unlocked) + 1
                            curMissionMob = unlocked[missionIdx]
                            missionIdx += 1
                        end
                        local mob = curMissionMob

                        if starting then
                            if now - startingSince > 8 then starting = false else return end
                        end
                        if now - lastTry >= 3 then
                            lastTry = now
                            starting, startingSince = true, now
                            task.spawn(function()
                                pcall(function()
                                    local cf = CommF()
                                    if cf then
                                        local ok2, res = pcall(function()
                                            return cf:InvokeServer("StartQuest", mob.quest, mob.idx)
                                        end)
                                        print("[SpectralHub] StartQuest:", mob.quest, mob.idx, ok2, tostring(res))
                                    end
                                    task.wait(1.2)
                                    local confirmed = QuestActive(mob)
                                    if confirmed == true then
                                        fails = 0
                                    else
                                        fails += 1
                                        if fails >= 2 then
                                            fails = 0
                                            curMissionMob = nil
                                            Notify("Missão de " .. mob.name .. " não iniciou, tentando a próxima.")
                                            print("[SpectralHub] Missão de", mob.name, "não confirmada: tentando próximo mob da rotação")
                                        end
                                    end
                                end)
                                starting = false
                            end)
                        end
                        return
                    end

                    -- Missão ativa: vai até os spawns esperar nascer
                    curMissionMob = activeMob
                    local spawns = SpawnPositions(activeMob, qtext)
                    if #spawns == 0 then spawns = { activeMob.area } end
                    if spawnIdx > #spawns then spawnIdx = 1 end
                    local target = spawns[spawnIdx] + Vector3.new(0, RACE_HEIGHT + 5, 0)
                    FlyTo(target, dt, MIRAGE_SPEED)
                    if (root.Position - target).Magnitude <= 30 then
                        if now - spawnSince >= 6 then
                            spawnIdx = spawnIdx % #spawns + 1
                            spawnSince = now
                        end
                    else
                        spawnSince = now
                    end

                    if now - lastDbg >= 3 then
                        lastDbg = now
                        print(string.format("[SpectralHub] Farm Osso: missão ativa = %s | esperando nascer", activeMob.name))
                        print("[SpectralHub] Inimigos perto de você:", NearbyNames(root))
                    end
                end)
                if not ok then warn("[SpectralHub] erro no Auto Farm:", err) end
            else
                LockedTarget, LockedMob = nil, nil
                wasActive = false
                if not WantRaidDone() and not RaceBusy() then ReleaseHold() end
            end
        end
    end)
end

-- Auto comprar osso ----------------------------------------
task.spawn(function()
    local lastSig, lastPrint = nil, 0
    while Alive() do
        task.wait(1.5)
        if FarmFlags.Buy then
            pcall(function()
                local cf = CommF()
                if not cf then return end
                local buy = cf:InvokeServer("Bones", "Buy", 1, 1)
                local check = cf:InvokeServer("Bones", "Check")
                local sig = tostring(buy) .. " | " .. tostring(check)
                if sig ~= lastSig or os.clock() - lastPrint > 20 then
                    lastSig, lastPrint = sig, os.clock()
                    print("[SpectralHub] Bones Buy | Check:", sig)
                end
            end)
        end
    end
end)

-- Auto raça V4: ativa via RemoteFunction do Awakening ------
task.spawn(function()
    local lastTry, tries, pauseUntil, lastPrint, lastScan = 0, 0, 0, 0, 0
    local missingSince, announced = nil, false
    local guiVal, guiSrc = nil, nil

    local function IsFull(v) return (v >= 0.999 and v <= 1.001) or v >= 99.9 end

    local function FromCharacter()
        local char = player.Character
        if not char then return nil end
        for _, d in ipairs(char:GetChildren()) do
            if d:IsA("NumberValue") or d:IsA("IntValue") then
                local n = d.Name:lower()
                if n:find("energy", 1, true) or n:find("fury", 1, true) or n:find("awaken", 1, true) then
                    return d.Value, "personagem." .. d.Name
                end
            end
        end
        for name, val in pairs(char:GetAttributes()) do
            local n = name:lower()
            if type(val) == "number" and (n:find("energy", 1, true) or n:find("fury", 1, true) or n:find("awaken", 1, true)) then
                return val, "atributo." .. name
            end
        end
        return nil
    end

    local function FromGui()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return nil end
        local best, src
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text:find("%%") then
                local num = tonumber(d.Text:match("(%d+%.?%d*)%s*%%"))
                if num then
                    local chain, a, depth = d.Name, d.Parent, 0
                    while a and a ~= pg and depth < 5 do
                        chain = chain .. "/" .. a.Name
                        a = a.Parent
                        depth += 1
                    end
                    local c = chain:lower()
                    if c:find("fury", 1, true) or c:find("energy", 1, true) or c:find("awaken", 1, true) or c:find("race", 1, true) then
                        if not best or num > best then best, src = num, "tela." .. chain end
                    end
                end
            end
        end
        return best, src
    end

    local function ActivateAwakeningRemote()
        local char = player.Character
        local bp = player:FindFirstChild("Backpack")
        local awk = (char and char:FindFirstChild("Awakening")) or (bp and bp:FindFirstChild("Awakening"))
        if not awk then return false, "Awakening não encontrado" end

        local rf = awk:FindFirstChild("RemoteFunction") or awk:FindFirstChildOfClass("RemoteFunction")
        if rf then
            local ok, res = pcall(function() return rf:InvokeServer(true) end)
            return ok, res
        end

        local re = awk:FindFirstChildOfClass("RemoteEvent")
        if re then
            local ok, res = pcall(function() re:FireServer(true) end)
            return ok, res
        end

        return false, "RemoteFunction não encontrado em Awakening"
    end

    while Alive() do
        task.wait(0.4)
        if FarmFlags.V4 or RaceFlags.Train then
            local ok, err = pcall(function()
                local now = os.clock()
                if Transformed() then
                    tries = 0
                    return
                end

                local v, vsrc = FromCharacter()
                if now - lastScan > 2 then
                    lastScan = now
                    guiVal, guiSrc = FromGui()
                end
                local found = v ~= nil or guiVal ~= nil
                local full = (v ~= nil and IsFull(v)) or (guiVal ~= nil and guiVal >= 99.9)

                local blind = false
                if not found then
                    missingSince = missingSince or now
                    blind = now - missingSince > 5
                else
                    missingSince = nil
                end
                if blind and not announced then
                    announced = true
                    Notify("Auto raça V4: medidor não detectado, tentando ativar via Awakening periodicamente.")
                elseif found then
                    announced = false
                end

                if now - lastPrint > 5 then
                    lastPrint = now
                    print("[SpectralHub] Auto raça V4: personagem =", tostring(vsrc), tostring(v),
                        "| tela =", tostring(guiSrc), tostring(guiVal),
                        "| cheio =", full, "| sem medidor =", blind, "| transformado =", Transformed())
                end

                local want, interval = full, 1.0
                if blind then want, interval = true, 4.0 end
                if not want then tries = 0 return end
                if now < pauseUntil then return end

                if tries >= 6 then
                    tries = 0
                    pauseUntil = now + 15
                    print("[SpectralHub] Auto raça V4: não transformou após 6 chamadas, aguardando 15s")
                    return
                end

                if now - lastTry >= interval then
                    lastTry = now
                    tries += 1
                    task.spawn(function()
                        local invoked, info = ActivateAwakeningRemote()
                        if not invoked then
                            print("[SpectralHub] Auto raça V4 aviso:", tostring(info))
                        end
                    end)
                end
            end)
            if not ok then warn("[SpectralHub] erro no Auto raça V4:", err) end
        end
    end
end)

-- Auto treinar raça (orquestrador) -------------------------
do
-- Ciclo: farma osso (no ponto de farm) -> V4 ativa: espera no ponto alto até acabar
--        -> V4 acabou: tenta comprar upgrade (se der) -> volta a farmar osso e repete.
local lastTrainText
local function SetTrainStatus(t)
    if lastTrainText == t then return end
    lastTrainText = t
    if TrainUI.Status then pcall(function() TrainUI.Status:Set(t) end) end
end

local function TryUpgradeRace()
    local cf = CommF()
    if not cf then return false end
    local before = Frags()
    local ok, res = pcall(function() return cf:InvokeServer("UpgradeRace", "Buy") end)
    task.wait(1)
    local after = Frags()
    print("[SpectralHub] UpgradeRace Buy:", ok, tostring(res), "| fragmentos:", before, "->", after)
    return ok and (after < before or res == true)
end

-- Espera no ponto alto enquanto a V4 está ativa
task.spawn(function()
    local was = false
    while Alive() do
        local dt = Run.Heartbeat:Wait()
        if TS.waiting and RaceFlags.Train then
            was = true
            pcall(function()
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not hum or not root then return end
                if hum.SeatPart then JumpOffBoat(hum) return end
                FlyTo(WAIT_POS, dt, MIRAGE_SPEED)
                HoldPlayer(root)
            end)
        elseif was then
            was = false
            ReleaseHold()
        end
    end
end)

task.spawn(function()
    local state, wasOn, endedSince = "farm", false, nil
    while Alive() do
        task.wait(0.5)
        if RaceFlags.Train then
            pcall(function()
                local transformed = Transformed()
                if not wasOn then
                    wasOn = true
                    endedSince = nil
                    state = transformed and "v4" or "farm"
                    print("[SpectralHub] Treino de raça iniciado no estado:", state)
                end

                if state == "farm" then
                    TS.farm, TS.waiting = true, false
                    SetTrainStatus("Treino: farmando osso até ativar a V4...")
                    if transformed then
                        state, endedSince = "v4", nil
                        print("[SpectralHub] Treino: V4 ativada, indo esperar no ponto alto")
                    end
                else
                    TS.farm, TS.waiting = false, true
                    SetTrainStatus("Treino: V4 ativa, esperando ela acabar...")
                    if transformed then
                        endedSince = nil
                    else
                        endedSince = endedSince or os.clock()
                        if os.clock() - endedSince >= 1.5 then
                            TS.waiting = false
                            SetTrainStatus("Treino: V4 acabou, checando upgrade...")
                            if TryUpgradeRace() then NotifyNow("Upgrade da raça comprado!") end
                            state, endedSince = "farm", nil
                        end
                    end
                end
            end)
        elseif wasOn then
            wasOn = false
            TS.farm, TS.waiting = false, false
            SetTrainStatus("Treino: desligado")
        end
    end
end)

end
-- Stats do servidor ----------------------------------------
do
    local MIRAGE_DURATION = 600
    local MOON_PHASES = {
        ["9709149431"] = 0,
        ["9709149052"] = 1,
        ["9709143733"] = 2,
        ["9709150401"] = 3,
        ["9709135895"] = 4,
    }

    local scriptStart = os.clock()
    local last = {}
    local function setLabel(key, text)
        if last[key] == text then return end
        last[key] = text
        local l = StatsUI[key]
        if l then pcall(function() l:Set(text) end) end
    end
    local function fmt(sec)
        sec = math.max(0, math.floor(sec))
        return string.format("%02d:%02d", sec // 60, sec % 60)
    end

    task.spawn(function()
        local mirageFirst, mirageEstimated, lastMoonId = nil, false, nil
        while Alive() do
            task.wait(1)
            pcall(function()
                setLabel("Fruit", "Fruta spawnada: " .. (#WorldFruits() > 0 and "🟢" or "🔴"))

                if GetMirage() then
                    if not mirageFirst then
                        mirageFirst = os.clock()
                        mirageEstimated = (os.clock() - scriptStart) < 10
                    end
                    local left = MIRAGE_DURATION - (os.clock() - mirageFirst)
                    setLabel("Mirage", "Ilha da miragem: 🟢  |  some em " .. (mirageEstimated and "~" or "") .. fmt(left))
                else
                    mirageFirst = nil
                    setLabel("Mirage", "Ilha da miragem: 🔴")
                end

                local sky = Lighting:FindFirstChildOfClass("Sky")
                local tex = sky and sky.MoonTextureId
                local id = tex and tostring(tex):match("%d+")
                local n = id and MOON_PHASES[id]
                if id ~= lastMoonId then
                    lastMoonId = id
                    print("[SpectralHub] Textura da lua:", tostring(id), "-> luas até a cheia:", tostring(n))
                end
                if n == nil then
                    setLabel("Moon", "Luas até a lua cheia: lua falsa")
                elseif n == 0 then
                    setLabel("Moon", "Luas até a lua cheia: 0 (lua cheia agora!)")
                else
                    setLabel("Moon", "Luas até a lua cheia: " .. n)
                end
            end)
        end
    end)
end

-- Andar na água --------------------------------------------
do
local waterOrig = nil
local function WaterPlane()
    local map = WS:FindFirstChild("Map")
    return map and map:FindFirstChild("WaterBase-Plane")
end
task.spawn(function()
    while Alive() do
        task.wait(0.5)
        pcall(function()
            if WaterWalk then
                local w = WaterPlane()
                if not w then Notify("Plano da água (WaterBase-Plane) não encontrado.") return end
                if not waterOrig or waterOrig.part ~= w then
                    waterOrig = { part = w, size = w.Size, collide = w.CanCollide }
                end
                if w.Size.Y ~= WATER_WALK_Y or not w.CanCollide then
                    w.Size = Vector3.new(w.Size.X, WATER_WALK_Y, w.Size.Z)
                    w.CanCollide = true
                end
            elseif waterOrig then
                local o = waterOrig
                waterOrig = nil
                if o.part and o.part.Parent then
                    o.part.Size = o.size
                    o.part.CanCollide = o.collide
                end
            end
        end)
    end
end)

end
-- ESP ------------------------------------------------------
do
local espCache = { Fruit = {}, Player = {} }
local function DestroyRec(kind, key)
    local rec = espCache[kind][key]
    if rec then
        pcall(function() rec.gui:Destroy() end)
        pcall(function() rec.hl:Destroy() end)
        espCache[kind][key] = nil
    end
end
ClearESP = function(kind)
    for k in pairs(espCache[kind]) do DestroyRec(kind, k) end
end
local function EnsureESP(kind, key, part, hlTarget, color)
    local rec = espCache[kind][key]
    if rec and rec.part == part and rec.gui.Parent then return rec end
    DestroyRec(kind, key)
    local gui = Instance.new("BillboardGui")
    gui.Name = "SpectralESP"
    gui.AlwaysOnTop = true
    gui.Size = UDim2.fromOffset(180, 34)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.Adornee = part
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0.3
    lbl.Parent = gui
    gui.Parent = part
    local hl = Instance.new("Highlight")
    hl.Name = "SpectralESPHL"
    hl.FillColor, hl.OutlineColor = color, color
    hl.FillTransparency = 0.7
    hl.Adornee = hlTarget
    hl.Parent = hlTarget
    rec = { gui = gui, hl = hl, label = lbl, part = part }
    espCache[kind][key] = rec
    return rec
end
task.spawn(function()
    while Alive() do
        task.wait(0.4)
        pcall(function()
            local root = MyRoot()
            if ESPFlags.Fruit then
                local seen = {}
                for _, f in ipairs(WorldFruits()) do
                    local h = f:FindFirstChild("Handle")
                    if h then
                        seen[f] = true
                        local rec = EnsureESP("Fruit", f, h, f, Color3.fromRGB(255, 200, 0))
                        local d = root and (root.Position - h.Position).Magnitude or 0
                        rec.label.Text = string.format("%s [%dm]", f.Name, d)
                    end
                end
                for k in pairs(espCache.Fruit) do
                    if not seen[k] then DestroyRec("Fruit", k) end
                end
            end
            if ESPFlags.Player then
                local seen = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    local c = p ~= player and p.Character
                    local part = c and (c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart"))
                    if part then
                        seen[p] = true
                        local rec = EnsureESP("Player", p, part, c, Color3.fromRGB(255, 70, 70))
                        local d = root and (root.Position - part.Position).Magnitude or 0
                        rec.label.Text = string.format("%s [%dm]", p.Name, d)
                    end
                end
                for k in pairs(espCache.Player) do
                    if not seen[k] then DestroyRec("Player", k) end
                end
            end
        end)
    end
end)

end
-- Raça (porta / trial / kill players) ----------------------
do
local lastTempleTp = 0

local function GetRaceName()
    local data = player:FindFirstChild("Data")
    local rv = data and data:FindFirstChild("Race")
    return rv and tostring(rv.Value) or nil
end

local function TeleportToTemple()
    if hitboxBusy or os.clock() - lastTempleTp < TEMPLE_TP_COOLDOWN then return end
    lastTempleTp = os.clock()
    task.spawn(UseCastleHitbox)
end

local function NearestEnemy(origin, radius)
    local folder = Enemies()
    if not folder then return nil end
    local be, bh, bd
    for _, e in ipairs(folder:GetChildren()) do
        local alive, hrp = IsAlive(e)
        if alive then
            local d = (hrp.Position - origin).Magnitude
            if d <= radius and (not bd or d < bd) then be, bh, bd = e, hrp, d end
        end
    end
    return be, bh
end
local function NearestPlayer(origin, radius)
    local bp, bc, bh, bd
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 then
                local d = (r.Position - origin).Magnitude
                if d <= radius and (not bd or d < bd) then bp, bc, bh, bd = p, p.Character, r, d end
            end
        end
    end
    return bp, bc, bh
end

task.spawn(function()
    local lastHit = 0
    while Alive() do
        local dt = Run.Heartbeat:Wait()
        if RaceBusy() and not StartSeaEvent and not anyTrue(MirageFlags) then
            local ok, err = pcall(function()
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not hum or not root then return end
                if hum.SeatPart then JumpOffBoat(hum) return end

                if RaceFlags.Door then
                    ReleaseHold()
                    if (root.Position - TEMPLE_CENTER).Magnitude > TEMPLE_NEAR then
                        TeleportToTemple(dt)
                        return
                    end

                    local race = GetRaceName()
                    local pos = RACE_DOOR_POSITION or (race and DOOR_POS[race:lower()])
                    if not pos then
                        Notify("Raça não reconhecida: " .. tostring(race))
                        print("[SpectralHub] Data.Race =", race)
                        return
                    end
                    FlyTo(pos + Vector3.new(0, 3, 0), dt, MIRAGE_SPEED)
                    return
                end

                if RaceFlags.KillPlayers then
                    local p, pc, ph = NearestPlayer(root.Position, KILL_RADIUS)
                    if p then
                        EquipSword()
                        FlyTo(ph.Position + Vector3.new(0, 4, 0), dt, 300)
                        local ra, rh = RegAttack(), RegHit()
                        if ra and rh and os.clock() - lastHit >= 0.05
                            and (root.Position - ph.Position).Magnitude <= 120 then
                            lastHit = os.clock()
                            ra:FireServer(0.36666667461395, 1)
                            rh:FireServer(ph, {{pc, ph}}, "9de8d7f4")
                        end
                        return
                    end
                end
                if RaceFlags.Trial then
                    local e, eh = NearestEnemy(root.Position, TRIAL_RADIUS)
                    if e then
                        EquipSword(); AutoCombatForce = true
                        FlyTo(eh.Position + Vector3.new(0, RACE_HEIGHT, 0), dt, 300)
                        HoldPlayer(root)
                        return
                    end
                end
                ReleaseHold()
            end)
            if not ok then warn("[SpectralHub] erro na Raça:", err) end
        end
    end
end)

end
-- Sea Event ------------------------------------------------
task.spawn(function()
    local track = {
        target = nil, lastHealth = 0, lastChange = 0, escapeUntil = 0, hitUntil = 0,
        hitHeight = HIT_ESCAPE_HEIGHT, myLast = 0, lowHp = false, lowHeight = LOWHP_START,
    }

    while Alive() do
        local dt = Run.Heartbeat:Wait()
        if StartSeaEvent then
            local ok, err = pcall(function()
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not hum or not root then return end

                local boat = GetBoatChecked(hum, root)
                currentBoat = boat

                local target = FindTarget()
                if target then
                    local alive, eroot = IsAlive(target)
                    if alive then
                        EquipSword(); CleanBoatMovers(boat); AutoCombatForce = true
                        if hum.SeatPart then JumpOffBoat(hum) return end

                        if IsTerror(target) then
                            local eh = target:FindFirstChildOfClass("Humanoid")
                            local now = os.clock()
                            local hp = hum.Health
                            local pct = hp / math.max(hum.MaxHealth, 1)

                            if track.target ~= target then
                                track.target = target
                                track.lastHealth = eh and eh.Health or 0
                                track.lastChange = now
                                track.escapeUntil, track.hitUntil = 0, 0
                                track.hitHeight = HIT_ESCAPE_HEIGHT
                                track.myLast = hp
                                track.lowHp = false
                                track.lowHeight = LOWHP_START
                            end
                            if eh then
                                if eh.Health < track.lastHealth then track.lastChange = now end
                                track.lastHealth = eh.Health
                            end
                            local tookDamage = hp < track.myLast - 0.01
                            track.myLast = hp

                            if not track.lowHp and pct < LOWHP_THRESHOLD then
                                print("[SpectralHub] Vida < 20%, fugindo")
                                track.lowHp, track.lowHeight = true, LOWHP_START
                                track.escapeUntil, track.hitUntil = 0, 0
                            end
                            if track.lowHp then
                                if pct >= LOWHP_RECOVER then
                                    print("[SpectralHub] Vida em 50%, voltando")
                                    track.lowHp = false
                                    track.lastChange = now
                                else
                                    track.lowHeight = math.min(LOWHP_MAX, track.lowHeight + LOWHP_RISE * dt)
                                    TeleportTo(eroot.Position + Vector3.new(0, track.lowHeight, 0))
                                    return
                                end
                            end

                            if now < track.hitUntil then
                                TeleportTo(eroot.Position + Vector3.new(0, track.hitHeight, 0))
                                return
                            end
                            local stunned = IsStunned(char, hum)
                            if tookDamage or stunned then
                                local h = stunned and STUN_ESCAPE_HEIGHT or HIT_ESCAPE_HEIGHT
                                print("[SpectralHub] " .. (stunned and "Stun" or "Dano") .. ", subindo " .. h)
                                track.hitHeight = h
                                TeleportTo(eroot.Position + Vector3.new(0, h, 0))
                                track.hitUntil = now + HIT_ESCAPE_HOLD
                                track.escapeUntil = 0
                                track.lastChange = now + HIT_ESCAPE_HOLD
                                return
                            end

                            if now < track.escapeUntil then
                                TeleportTo(eroot.Position + Vector3.new(0, TERROR_ESCAPE_HEIGHT, 0))
                                return
                            end
                            local flat = Vector3.new(root.Position.X - eroot.Position.X, 0, root.Position.Z - eroot.Position.Z).Magnitude
                            local above = root.Position.Y > eroot.Position.Y and flat <= TERROR_ABOVE_RADIUS
                            if above and now - track.lastChange >= TERROR_NO_DAMAGE_TIME then
                                print("[SpectralHub] Terror sem dano, subindo")
                                TeleportTo(eroot.Position + Vector3.new(0, TERROR_ESCAPE_HEIGHT, 0))
                                track.escapeUntil = now + TERROR_ESCAPE_HOLD
                                track.lastChange = now + TERROR_ESCAPE_HOLD
                                return
                            end

                            FlyTo(eroot.Position + Vector3.new(0, TERROR_HEIGHT, 0), dt, 250)
                        else
                            track.target = nil
                            FlyTo(eroot.Position + Vector3.new(0, ATTACK_HEIGHT, 0), dt, 250)
                        end
                        return
                    end
                end

                track.target, track.lowHp = nil, false
                SailStep(hum, root, dt, boat)
            end)
            if not ok then warn("[SpectralHub] erro no Sea Event:", err) end
        elseif not anyTrue(MirageFlags) then
            if currentBoat then CleanBoatMovers(currentBoat) end
            currentBoat = nil
        end
    end
end)

print("[SpectralHub] 5 - pronto!")
end

local ok, err = xpcall(main, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
if not ok then warn("[SpectralHub] ERRO FATAL:", err) end
