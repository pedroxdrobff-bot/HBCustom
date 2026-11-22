-- ============================================================
-- HBSS_Custom.lua — Fork do Gravel.cc
-- Baseado no HBSS_New.lua original do Gpssickle
-- Melhorias: Scheduler, ProxyHitbox, HK triplo, Prediction
--            Aimbot humanizado, Remote Detector, ModuloEdit tab
-- ============================================================

if getgenv().Graaaaaaaaaaaaaaaaaaaaaaavel_ then return end
getgenv().Graaaaaaaaaaaaaaaaaaaaaaavel_ = true
getgenv().nameeeitttttohhhhhhmahhhhhgahhhhhh_ = ""

local excusemesir = {
    Players           = game:GetService("Players"),
    RunService        = game:GetService("RunService"),
    UserInputService  = game:GetService("UserInputService"),
    VirtualUser       = game:GetService("VirtualUser"),
    TweenService      = game:GetService("TweenService"),
    VirtualInputManager = game:GetService("VirtualInputManager"),
    HttpService       = game:GetService("HttpService"),
    SoundService      = game:GetService("SoundService"),
    Workspace         = game:GetService("Workspace"),
    Lighting          = game:GetService("Lighting"),
    ScriptContext     = game:GetService("ScriptContext"),
    LogService        = game:GetService("LogService"),
    CoreGui           = game:GetService("CoreGui"),
    Teams             = game:GetService("Teams"),
    StarterGui        = game:GetService("StarterGui"),
    MarketplaceService = game:GetService("MarketplaceService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    ReplicatedFirst   = game:GetService("ReplicatedFirst"),
    ServerStorage     = game:GetService("ServerStorage"),
    TeleportService   = game:GetService("TeleportService"),
}

local success, err2 = xpcall(function()

repeat task.wait() until game:IsLoaded()

for _, v in pairs(getconnections(game:GetService("ScriptContext").Error)) do v:Disable() end
for _, v in pairs(getconnections(game:GetService("LogService").MessageOut)) do v:Disable() end

local player       = excusemesir.Players.LocalPlayer
local localPlayer  = excusemesir.Players.LocalPlayer
local clone_ref    = cloneref or function(v) return v end

-- ============================================================
-- [PATCH 1] SCHEDULER com jitter
-- ============================================================
local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    local self = setmetatable({}, Scheduler)
    self._tasks = {}
    self._conn  = nil
    return self
end

function Scheduler:add(name, hz, fn)
    local base = 1 / math.max(hz, 1)
    self._tasks[name] = {
        fn       = fn,
        interval = base,
        jitter   = base * 0.15,
        last     = 0,
    }
end

function Scheduler:remove(name)
    self._tasks[name] = nil
end

function Scheduler:start()
    if self._conn then self._conn:Disconnect() end
    self._conn = excusemesir.RunService.Heartbeat:Connect(function()
        local now = tick()
        for _, t in next, self._tasks do
            local jitter = (math.random() - 0.5) * 2 * t.jitter
            if now - t.last >= t.interval + jitter then
                t.last = now
                local ok, e = pcall(t.fn)
                if not ok then warn("[Sched] " .. tostring(e)) end
            end
        end
    end)
end

function Scheduler:stop()
    if self._conn then self._conn:Disconnect(); self._conn = nil end
end

local GravelSched = Scheduler.new()

-- ============================================================
-- [PATCH 2] DRAWING POOL
-- ============================================================
local DrawingPool = { _pool = {} }

function DrawingPool:get(type)
    local b = self._pool[type]
    if b and #b > 0 then
        local d = table.remove(b)
        d.Visible = false
        return d
    end
    return Drawing.new(type)
end

function DrawingPool:release(d)
    if not d then return end
    local t = d.Type
    d.Visible = false
    self._pool[t] = self._pool[t] or {}
    table.insert(self._pool[t], d)
end

-- ============================================================
-- [PATCH 3] CAMERA CACHE
-- ============================================================
local CameraCache = {
    lastCF    = CFrame.new(),
    threshold = 0.008,
    dirty     = true,
}

excusemesir.RunService.Heartbeat:Connect(function()
    local cf  = workspace.CurrentCamera.CFrame
    local dot = cf.LookVector:Dot(CameraCache.lastCF.LookVector)
    CameraCache.dirty = dot < (1 - CameraCache.threshold)
    if CameraCache.dirty then CameraCache.lastCF = cf end
end)

-- ============================================================
-- [PATCH 4] PROXY HITBOX
-- ============================================================
local ProxyHitbox = {}
local _proxyMap   = {}

function ProxyHitbox.create(targetPart, size)
    if _proxyMap[targetPart] then ProxyHitbox.remove(targetPart) end
    local proxy         = Instance.new("Part")
    proxy.Size          = Vector3.one * size
    proxy.CFrame        = targetPart.CFrame
    proxy.Transparency  = 1
    proxy.CanCollide    = false
    proxy.Anchored      = false
    proxy.Massless      = true
    proxy.Name          = "__GravelProxy"
    proxy.Parent        = workspace
    local weld          = Instance.new("WeldConstraint")
    weld.Part0          = proxy
    weld.Part1          = targetPart
    weld.Parent         = proxy
    _proxyMap[targetPart] = proxy
    return proxy
end

function ProxyHitbox.remove(targetPart)
    local p = _proxyMap[targetPart]
    if p and p.Parent then p:Destroy() end
    _proxyMap[targetPart] = nil
end

function ProxyHitbox.removeAll()
    for part in next, _proxyMap do ProxyHitbox.remove(part) end
end

function ProxyHitbox.updateAll(size)
    for _, proxy in next, _proxyMap do
        if proxy and proxy.Parent then
            proxy.Size = Vector3.one * size
        end
    end
end

-- ============================================================
-- [PATCH 5] SILENT AIM HK — hook triplo
-- ============================================================
local SA_Hooks   = {}
local _hkEnabled = false
local _hkOrig    = {}

local function getHKTarget()
    local cfg = getgenv().config
    if not cfg then return nil end
    local t = cfg.SA2_currentTarget or cfg.aimbotCurrentTarget
    if not t then return nil end
    local char = (t.Character or t)
    return char and char:FindFirstChild(cfg.SA2_TargetPart or "Head")
end

local function buildHook(original)
    return newcclosure(function(self, origin, direction, params)
        local tp = getHKTarget()
        if not tp then return original(self, origin, direction, params) end
        local cfg = getgenv().config
        if cfg and cfg.SA2_HitChance and math.random(1,100) > cfg.SA2_HitChance then
            return original(self, origin, direction, params)
        end
        return original(self, origin, tp.Position - origin, params)
    end)
end

function SA_Hooks.enable()
    if _hkEnabled or not hookfunction then return end
    _hkEnabled = true

    _hkOrig.Raycast = hookfunction(workspace.Raycast, buildHook(workspace.Raycast))

    if workspace.FindPartOnRay then
        _hkOrig.FindPartOnRay = hookfunction(
            workspace.FindPartOnRay,
            newcclosure(function(self, ray, ignore, tc, iw)
                local tp = getHKTarget()
                if tp then
                    local char = localPlayer.Character
                    local org  = char and char.HumanoidRootPart
                        and char.HumanoidRootPart.Position or ray.Origin
                    ray = Ray.new(org, tp.Position - org)
                end
                return _hkOrig.FindPartOnRay(self, ray, ignore, tc, iw)
            end)
        )
    end

    if hookmetamethod then
        _hkOrig.namecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local m = getnamecallmethod and getnamecallmethod() or ""
            if m == "Raycast" or m == "FindPartOnRay" then
                local tp = getHKTarget()
                if tp then
                    local args   = {...}
                    local origin = args[1]
                    if typeof(origin) == "Vector3" then
                        args[2] = tp.Position - origin
                        return _hkOrig.namecall(self, table.unpack(args))
                    end
                end
            end
            return _hkOrig.namecall(self, ...)
        end))
    end
end

function SA_Hooks.disable()
    if not _hkEnabled then return end
    _hkEnabled = false
    if _hkOrig.Raycast        then hookfunction(workspace.Raycast, _hkOrig.Raycast); _hkOrig.Raycast = nil end
    if _hkOrig.FindPartOnRay  then hookfunction(workspace.FindPartOnRay, _hkOrig.FindPartOnRay); _hkOrig.FindPartOnRay = nil end
    if _hkOrig.namecall and hookmetamethod then
        hookmetamethod(game, "__namecall", _hkOrig.namecall)
        _hkOrig.namecall = nil
    end
end

-- ============================================================
-- [PATCH 6] PREDICTION BALÍSTICA
-- ============================================================
local function getPredicted(targetPart)
    local ping    = localPlayer:GetNetworkPing()
    local rt      = ping * 2
    local vel     = targetPart.Velocity
    local gravity = Vector3.new(0, -workspace.Gravity * 0.5, 0)
    return targetPart.Position + vel * rt + gravity * (rt * rt)
end

-- ============================================================
-- [PATCH 7] AIMBOT HUMANIZADO
-- ============================================================
local function gaussian()
    local u1 = math.max(1e-9, 1 - math.random())
    local u2 = math.max(1e-9, 1 - math.random())
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local function humanizedAimStep(targetCF, strength)
    local cam     = workspace.CurrentCamera
    local noise   = (strength or 0.5) * 0.025
    local smoothed = cam.CFrame:Lerp(targetCF, strength or 0.5)
    cam.CFrame = smoothed * CFrame.Angles(
        gaussian() * noise * 0.6,
        gaussian() * noise,
        0
    )
end

-- ============================================================
-- [PATCH 8] REMOTE DETECTOR
-- ============================================================
local RemoteDetector = {
    hits     = {},
    detected = {},
    _orig    = nil,
    _hooked  = false,
}

local DMG_KW = {
    "hit","damage","dmg","shoot","bullet","fire",
    "attack","hurt","kill","projectile","hitscan",
    "raycast","shot","wound","deal","inflict",
}

function RemoteDetector.enable()
    if RemoteDetector._hooked or not hookmetamethod then return end
    RemoteDetector._hooked = true
    RemoteDetector._orig   = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod and getnamecallmethod() or ""
        if m == "FireServer" or m == "InvokeServer" then
            local name = (self.Name or ""):lower()
            for _, kw in ipairs(DMG_KW) do
                if name:find(kw, 1, true) then
                    RemoteDetector.hits[self] = (RemoteDetector.hits[self] or 0) + 1
                    if RemoteDetector.hits[self] >= 3 then
                        RemoteDetector.detected[self] = true
                    end
                    break
                end
            end
        end
        return RemoteDetector._orig(self, ...)
    end))
end

function RemoteDetector.disable()
    if not RemoteDetector._hooked or not RemoteDetector._orig then return end
    hookmetamethod(game, "__namecall", RemoteDetector._orig)
    RemoteDetector._hooked = false
    RemoteDetector._orig   = nil
end

function RemoteDetector.getDetected()
    local list = {}
    for r in next, RemoteDetector.detected do
        if r and r.Parent then table.insert(list, r) end
    end
    return list
end

-- ============================================================
-- [PATCH 9] SPEED / JUMP SUAVE
-- ============================================================
local TS = excusemesir.TweenService

local function setSpeedSmooth(speed, dur)
    local hum = localPlayer.Character
        and localPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    TS:Create(hum, TweenInfo.new(dur or 0.25, Enum.EasingStyle.Linear),
        {WalkSpeed = speed}):Play()
end

local function setJumpSmooth(power, dur)
    local hum = localPlayer.Character
        and localPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    TS:Create(hum, TweenInfo.new(dur or 0.25, Enum.EasingStyle.Linear),
        {JumpPower = power}):Play()
end

-- ============================================================
-- [PATCH 10] BHOP HUMANIZADO
-- ============================================================
local function humanizedBhop()
    local char = localPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hum.FloorMaterial ~= Enum.Material.Air then
        task.wait(0.05 + math.random() * 0.03)
        hum.Jump = true
    end
end

-- ============================================================
-- [PATCH 11] ANTI-SCREENSHARE
-- ============================================================
local function protectGUI(gui)
    if not gui then return end
    if syn and syn.protect_gui then
        syn.protect_gui(gui); gui.Parent = game.CoreGui
    elseif gethui then
        gui.Parent = gethui()
    else
        pcall(function() gui.Parent = game.CoreGui end)
    end
end

-- ============================================================
-- URL dos módulos originais do Gravel
-- ============================================================
getgenv().HttpUrlz_ = {
    hbssloader  = "https://raw.githubusercontent.com/hm5650/HBSS/refs/heads/main/GUIs/HBSS_Loader.lua",
    hbsscloser  = "https://raw.githubusercontent.com/hm5650/HBSS/refs/heads/main/GUIs/HBSS_Closer.lua",
    ineedbloxycola = "https://raw.githubusercontent.com/hm5650/HBSS/refs/heads/main/module/uimodule/HBSS_InitGui.lua",
    sa2func     = "https://raw.githubusercontent.com/hm5650/HBSS/refs/heads/main/module/SA2/SA2_Function.lua",
    sa2findtool = "https://raw.githubusercontent.com/hm5650/HBSS/refs/heads/main/module/SA2/SA2_FindTool.lua",
    showmyipadress_jk = "https://raw.githubusercontent.com/hm5650/HBSS/refs/heads/main/module/getInfo.lua",
    uithesavory = "https://raw.githubusercontent.com/hm5650/HBSS/refs/heads/main/module/uimodule/HBSS_SaveUI.lua",
    hbssbmg     = "https://raw.githubusercontent.com/hm5650/HBSS/refs/heads/main/module/uimodule/HBSS_BGM.lua",
    imalurtingyou = "https://raw.githubusercontent.com/azir-py/project/refs/heads/main/Zwolf/AlurtUI.lua",
    ilikedisui  = "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
}

local function getgist_(url, how, sigma)
    how   = how or 10
    sigma = sigma or 1
    local attempts = 0
    local lasterr  = nil
    while attempts < how do
        local ok, result = xpcall(function()
            return game:HttpGet(url)
        end, function(e)
            return debug.traceback("[getgist_] " .. tostring(e), 2)
        end)
        if ok then return result end
        attempts = attempts + 1
        lasterr  = result
        if tostring(result):find("429") then
            local wait = sigma * (2 ^ (attempts - 1))
            warn("http 429 — aguardando " .. wait .. "s")
            task.wait(wait)
        else
            task.wait(sigma)
        end
    end
    warn("[Custom] falha ao buscar url após " .. how .. " tentativas: " .. tostring(lasterr))
end

-- ============================================================
-- CARREGA MÓDULOS ORIGINAIS
-- ============================================================
local lp_info = loadstring(getgist_(getgenv().HttpUrlz_.showmyipadress_jk))()
loadstring(getgist_(getgenv().HttpUrlz_.hbssloader))()

local Alurt = loadstring(getgist_(getgenv().HttpUrlz_.imalurtingyou))()
local function n(opts)
    if typeof(Alurt) == "table" and type(Alurt.CreateNode) == "function" then
        Alurt.CreateNode(opts)
    end
end

task.wait(5.7)

local func   = loadstring(getgist_(getgenv().HttpUrlz_.sa2func))()
local WindUI = loadstring(getgist_(getgenv().HttpUrlz_.ilikedisui))()
local SaveUI = loadstring(getgist_(getgenv().HttpUrlz_.uithesavory))()
local BMG    = loadstring(getgist_(getgenv().HttpUrlz_.hbssbmg))()

task.wait(0.8)

n({
    Title    = "Gravel.cc | Custom Fork",
    Content  = "patched build — scheduler + proxy hitbox + moduloedit",
    Length   = 8,
    BarColor = Color3.fromRGB(120, 255, 120),
})

-- ============================================================
-- [PATCH 12] TAB MODULOEDIT
-- (injeta no Window após ele ser criado pelo hbssloader)
-- ============================================================
task.spawn(function()
    -- aguarda Window do Gravel
    local W = nil
    for _ = 1, 40 do
        W = getgenv().Window or _G.Window
        if W then break end
        task.wait(0.5)
    end
    if not W then
        warn("[Custom] Window não encontrada — ModuloEdit não adicionado")
        return
    end

    local Tab = W:CreateTab("ModuloEdit", "rbxassetid://7733960981")

    -- ── estado interno ─────────────────────────────────────
    local SERVICES = {
        Workspace         = game:GetService("Workspace"),
        Players           = game:GetService("Players"),
        ReplicatedStorage = game:GetService("ReplicatedStorage"),
        ReplicatedFirst   = game:GetService("ReplicatedFirst"),
        StarterGui        = game:GetService("StarterGui"),
        StarterPlayer     = game:GetService("StarterPlayer"),
    }

    local moduleList    = {}
    local selectedTable = nil
    local selectedMod   = nil
    local tableStack    = {}
    local _editKey      = ""
    local _editVal      = ""

    -- ── Seção: Serviço ─────────────────────────────────────
    Tab:CreateSection("Serviço")

    local svcNames = {}
    for k in next, SERVICES do table.insert(svcNames, k) end
    table.sort(svcNames)

    local modLabel = Tab:CreateLabel("Selecione um serviço")

    Tab:CreateDropdown({
        Name     = "Serviço Alvo",
        Options  = svcNames,
        Default  = "ReplicatedStorage",
        Callback = function(choice)
            moduleList   = {}
            selectedTable = nil
            selectedMod   = nil
            tableStack    = {}
            local svc = SERVICES[choice]
            if not svc then return end
            for _, obj in ipairs(svc:GetDescendants()) do
                if obj:IsA("ModuleScript") then
                    local ok, mod = pcall(require, obj)
                    table.insert(moduleList, {
                        name    = obj.Name,
                        path    = obj:GetFullName(),
                        success = ok and typeof(mod) == "table",
                        module  = (ok and typeof(mod) == "table") and mod or nil,
                        obj     = obj,
                    })
                end
            end
            local lines = {}
            for _, m in ipairs(moduleList) do
                table.insert(lines, (m.success and "[✔] " or "[✘] ") .. m.name)
            end
            modLabel:Set(#lines > 0
                and table.concat(lines, "\n")
                or  "Nenhum ModuleScript encontrado")
        end,
    })

    -- ── Seção: Selecionar módulo ───────────────────────────
    Tab:CreateSection("Módulo")

    Tab:CreateInput({
        Name        = "Buscar",
        Default     = "",
        Placeholder = "nome do módulo...",
        Callback    = function(text)
            local out = {}
            for _, m in ipairs(moduleList) do
                if m.name:lower():find(text:lower(), 1, true) then
                    table.insert(out, (m.success and "[✔] " or "[✘] ") .. m.name .. " — " .. m.path)
                end
            end
            modLabel:Set(#out > 0 and table.concat(out, "\n") or "Nenhum resultado")
        end,
    })

    Tab:CreateInput({
        Name        = "Selecionar (nome exato)",
        Default     = "",
        Placeholder = "ex: GameConfig",
        Callback    = function(name)
            selectedMod   = nil
            selectedTable = nil
            tableStack    = {}
            for _, m in ipairs(moduleList) do
                if m.name == name then
                    selectedMod   = m
                    selectedTable = m.module
                    break
                end
            end
            if selectedMod and selectedMod.success then
                modLabel:Set("✔ Carregado: " .. selectedMod.name .. "\nUse 'Listar Chaves' para ver campos.")
            else
                modLabel:Set("✘ Não encontrado ou não retorna tabela")
            end
        end,
    })

    -- ── Seção: Editor ──────────────────────────────────────
    Tab:CreateSection("Editor de Tabela")

    local keyLabel = Tab:CreateLabel("Chaves: —")

    Tab:CreateButton({
        Name     = "📋 Listar Chaves",
        Callback = function()
            if not selectedTable then
                keyLabel:Set("Nenhum módulo selecionado")
                return
            end
            local lines = {}
            for k, v in next, selectedTable do
                if typeof(v) ~= "function" then
                    local display = typeof(v) == "table" and "[table]" or tostring(v)
                    table.insert(lines, tostring(k) .. " = " .. display .. " (" .. typeof(v) .. ")")
                end
            end
            table.sort(lines)
            keyLabel:Set(#lines > 0
                and table.concat(lines, "\n")
                or  "Tabela vazia ou só funções")
        end,
    })

    Tab:CreateInput({
        Name        = "Chave",
        Default     = "",
        Placeholder = "Speed | subtab.chave",
        Callback    = function(v) _editKey = v end,
    })

    Tab:CreateInput({
        Name        = "Novo Valor",
        Default     = "",
        Placeholder = "100 | true | false | texto",
        Callback    = function(v) _editVal = v end,
    })

    Tab:CreateButton({
        Name     = "✏️ Aplicar",
        Callback = function()
            if not selectedTable then
                keyLabel:Set("✘ Nenhum módulo selecionado")
                return
            end
            if _editKey == "" then
                keyLabel:Set("✘ Chave vazia")
                return
            end

            local target = selectedTable
            local parts  = _editKey:split(".")
            if #parts > 1 then
                for i = 1, #parts - 1 do
                    if typeof(target[parts[i]]) == "table" then
                        target = target[parts[i]]
                    else
                        keyLabel:Set("✘ Path inválido: " .. parts[i])
                        return
                    end
                end
                _editKey = parts[#parts]
            end

            local raw = _editVal
            local newVal
            if raw == "true" then newVal = true
            elseif raw == "false" then newVal = false
            elseif raw == "nil" then newVal = nil
            elseif raw:match('^".*"$') then newVal = raw:sub(2, -2)
            else newVal = tonumber(raw) or raw
            end

            local old = target[_editKey]
            target[_editKey] = newVal
            keyLabel:Set("✔ " .. tostring(_editKey)
                .. "\n  antes : " .. tostring(old)
                .. "\n  depois: " .. tostring(newVal))
            print("[ModuloEdit] " .. tostring(_editKey) .. " = " .. tostring(newVal))
        end,
    })

    -- ── Seção: Navegação ───────────────────────────────────
    Tab:CreateSection("Sub-Tabelas")

    Tab:CreateInput({
        Name        = "Entrar em Sub-Tabela",
        Default     = "",
        Placeholder = "nome da chave",
        Callback    = function(key)
            if not selectedTable then return end
            local sub = selectedTable[key]
            if typeof(sub) == "table" then
                table.insert(tableStack, selectedTable)
                selectedTable = sub
                keyLabel:Set("📁 Dentro de: " .. key)
            else
                keyLabel:Set("✘ '" .. key .. "' não é tabela")
            end
        end,
    })

    Tab:CreateButton({
        Name     = "⬅ Voltar",
        Callback = function()
            if #tableStack > 0 then
                selectedTable = table.remove(tableStack)
                keyLabel:Set("↩ Voltou um nível")
            else
                keyLabel:Set("Já está na raiz")
            end
        end,
    })

    -- ── Seção: Remotes ─────────────────────────────────────
    Tab:CreateSection("Remote Detector")

    local remoteLabel = Tab:CreateLabel("Detector desligado")

    Tab:CreateToggle({
        Name     = "Monitorar Remotes",
        Default  = false,
        Callback = function(state)
            if state then
                RemoteDetector.enable()
                remoteLabel:Set("🔍 Monitorando... dispare no jogo")
            else
                RemoteDetector.disable()
                remoteLabel:Set("Detector desligado")
            end
        end,
    })

    Tab:CreateButton({
        Name     = "📋 Ver Detectados",
        Callback = function()
            local list = RemoteDetector.getDetected()
            if #list == 0 then
                remoteLabel:Set("Nenhum remote detectado\n(dispare algumas vezes)")
                return
            end
            local lines = {}
            for _, r in ipairs(list) do
                table.insert(lines, "• " .. r:GetFullName() .. " [" .. r.ClassName .. "]")
            end
            remoteLabel:Set(table.concat(lines, "\n"))
        end,
    })

    Tab:CreateButton({
        Name     = "➕ Adicionar ao SA2",
        Callback = function()
            local cfg  = getgenv().config
            if not cfg then remoteLabel:Set("✘ config não encontrado"); return end
            local list = RemoteDetector.getDetected()
            if #list == 0 then remoteLabel:Set("✘ Nenhum remote detectado"); return end
            cfg.detectedRemotes = cfg.detectedRemotes or {}
            local added = 0
            for _, r in ipairs(list) do
                if not table.find(cfg.detectedRemotes, r) then
                    table.insert(cfg.detectedRemotes, r)
                    added += 1
                end
            end
            remoteLabel:Set("✔ " .. added .. " remote(s) adicionados ao SA2")
        end,
    })

    -- ── Seção: Utilitários ─────────────────────────────────
    Tab:CreateSection("Utilitários")

    Tab:CreateButton({
        Name     = "🔁 Recarregar Módulo",
        Callback = function()
            if not selectedMod or not selectedMod.obj then
                keyLabel:Set("✘ Nenhum módulo selecionado")
                return
            end
            local ok, mod = pcall(require, selectedMod.obj)
            if ok and typeof(mod) == "table" then
                selectedMod.module = mod
                selectedTable      = mod
                tableStack         = {}
                keyLabel:Set("✔ Recarregado: " .. selectedMod.name)
            else
                keyLabel:Set("✘ Falha: " .. tostring(mod))
            end
        end,
    })

    Tab:CreateButton({
        Name     = "📤 Dump no Console",
        Callback = function()
            if not selectedTable then keyLabel:Set("✘ Nenhum módulo"); return end
            print("[ModuloEdit] DUMP — " .. (selectedMod and selectedMod.name or "?"))
            for k, v in next, selectedTable do
                if typeof(v) ~= "function" then
                    print("  " .. tostring(k) .. " = " .. tostring(v) .. " (" .. typeof(v) .. ")")
                end
            end
            keyLabel:Set("✔ Dump enviado ao console")
        end,
    })

    Tab:CreateButton({
        Name     = "🧹 Limpar Histórico",
        Callback = function()
            tableStack = {}
            if selectedMod and selectedMod.module then
                selectedTable = selectedMod.module
            end
            keyLabel:Set("✔ Voltou para raiz do módulo")
        end,
    })

    -- ── Seção: HK Controls ─────────────────────────────────
    Tab:CreateSection("SA Hook Controls")

    Tab:CreateToggle({
        Name     = "Hook Triplo (Raycast)",
        Default  = false,
        Callback = function(state)
            if state then SA_Hooks.enable() else SA_Hooks.disable() end
        end,
    })

    Tab:CreateToggle({
        Name     = "Proxy Hitbox",
        Default  = false,
        Callback = function(state)
            if not state then ProxyHitbox.removeAll() end
        end,
    })

    Tab:CreateButton({
        Name     = "🧹 Limpar Proxy Hitboxes",
        Callback = function()
            ProxyHitbox.removeAll()
            keyLabel:Set("✔ Proxies removidos")
        end,
    })

    print("[Custom] ✔ Tab ModuloEdit adicionado")
end)

-- ============================================================
-- [PATCH 13] LIGA SCHEDULER COM SISTEMAS DO GRAVEL
-- ============================================================
task.spawn(function()
    -- aguarda config do Gravel existir
    local cfg = nil
    for _ = 1, 60 do
        cfg = getgenv().config
        if cfg then break end
        task.wait(0.5)
    end
    if not cfg then
        warn("[Custom] config não encontrado — scheduler não ligado ao Gravel")
        return
    end

    -- aimbot humanizado substituindo o loop original
    GravelSched:add("aimbot_human", cfg.aimhertz or 60, function()
        if not cfg.aimbotEnabled then return end
        local t = cfg.aimbotCurrentTarget
        if not t then return end
        local char = t.Character
        local part = char and char:FindFirstChild(cfg.aimbotTargetPart or "Head")
        if not part then return end
        local predicted = getPredicted(part)
        humanizedAimStep(
            CFrame.new(workspace.CurrentCamera.CFrame.Position, predicted),
            cfg.aimbotStrength or 0.5
        )
    end)

    -- bhop humanizado
    GravelSched:add("bhop", 60, function()
        if cfg.bhop and cfg.bhop.enabled then
            humanizedBhop()
        end
    end)

    -- proxy hitbox sync (atualiza tamanho se mudou)
    GravelSched:add("proxyhb_sync", 10, function()
        if cfg.hitboxEnabled then
            ProxyHitbox.updateAll(cfg.hitboxSize or 10)
        else
            ProxyHitbox.removeAll()
        end
    end)

    -- speed suave — monitora mudança de walkspeed
    local lastSpeed = cfg.walkspeedValue or 16
    GravelSched:add("speed_smooth", 5, function()
        if not cfg.walkspeedEnabled then return end
        local target = cfg.walkspeedValue or 16
        if target ~= lastSpeed then
            setSpeedSmooth(target)
            lastSpeed = target
        end
    end)

    GravelSched:start()

    -- liga remote detector em background
    RemoteDetector.enable()

    print("[Custom] ✔ Scheduler ligado | RemoteDetector ativo")
end)

-- ============================================================
-- EXPORTS GLOBAIS
-- ============================================================
getgenv().GravelCustom = {
    Scheduler       = GravelSched,
    DrawingPool     = DrawingPool,
    CameraCache     = CameraCache,
    ProxyHitbox     = ProxyHitbox,
    SA_Hooks        = SA_Hooks,
    RemoteDetector  = RemoteDetector,
    getPredicted    = getPredicted,
    humanizedAim    = humanizedAimStep,
    setSpeedSmooth  = setSpeedSmooth,
    setJumpSmooth   = setJumpSmooth,
    humanizedBhop   = humanizedBhop,
    protectGUI      = protectGUI,
}

end, function(err)
    warn("[HBSS_Custom] erro: " .. debug.traceback(tostring(err), 2))
end)
