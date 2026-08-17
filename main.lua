loadstring(game:HttpGet("https://scripts.wabisabi.mom/wabi-sabi-ui-lib.lua"))()
local lib = WabiSabi

local pls = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local ws = game:GetService("Workspace")

local lp = pls.LocalPlayer

local w = lib:CreateWindow({
    Title = "SDBRP",
    SubTitle = "Cash Auto Farm",
    Size = Vector2.new(480, 460),
    Resize = true,
})

local tb = w:AddTab({ Title = "Farm", Icon = "play" })

local iol = {
    "1. Avacados ($150)",
    "2. Wagyu ($350)",
    "3. Brew ($500)",
    "4. Sneakers ($700)",
    "5. Diamond Ring ($1000)",
    "6. Mona Lisa ($3750)"
}

local io = {
    ["1. Avacados ($150)"] = { ItemName = "Crate Of Avacados", Price = 150, CivPos = Vector3.new(6820.77, 17.74, 37.39), ElcPos = Vector3.new(6629.36, 64.91, -448.51) },
    ["2. Wagyu ($350)"] = { ItemName = "Wagyu Beef", Price = 350, CivPos = Vector3.new(6811.53, 17.16, 38.47), ElcPos = Vector3.new(6638.55, 64.33, -448.93) },
    ["3. Brew ($500)"] = { ItemName = "Witches Brew", Price = 500, CivPos = Vector3.new(6803.72, 17.57, 33.37), ElcPos = Vector3.new(6646.54, 64.74, -444.12) },
    ["4. Sneakers ($700)"] = { ItemName = "Fake Designer Sneakers", Price = 700, CivPos = Vector3.new(6810.00, 17.72, 17.01), ElcPos = Vector3.new(6640.85, 64.44, -427.54) },
    ["5. Diamond Ring ($1000)"] = { ItemName = "Fake Diamond Ring", Price = 1000, CivPos = Vector3.new(6820.82, 17.48, 16.86), ElcPos = Vector3.new(6632.05, 64.46, -427.11) },
    ["6. Mona Lisa ($3750)"] = { ItemName = "Mona Lisa Painting", Price = 3750, CivPos = Vector3.new(6803.45, 18.40, 23.06), ElcPos = Vector3.new(6628.01, 65.57, -427.00) }
}

local pr = rs.__remotes.WorldBuyableItemService.PurchaseWorldBuyableItem
local sr = rs.__remotes.SmuggleService.SellSmuggledGoods
local lr = rs.__remotes.SmuggleService.LaunderBriefcase

local sellerOptions = { "Seller 1", "Seller 2 (Most Money)", "Seller 3", "Seller 4" }
local sellerDropdown = tb:AddDropdown({ Id = "selected_seller", Title = "Select Seller", Values = sellerOptions, Default = sellerOptions[1] })

local function getSelectedSellerName()
    local v = sellerDropdown.Value
    if type(v) == "table" and v.Value then v = v.Value end
    if not v then return "Seller 1" end
    if tostring(v):match("Seller 2") then return "Seller 2" end
    return tostring(v)
end

local function getSellerInstance()
    local npc = ws:FindFirstChild("NPC")
    if not npc then return nil end
    local name = getSelectedSellerName()
    if name == "Seller 2" then return npc:FindFirstChild("Seller2")
    elseif name == "Seller 3" then return npc:FindFirstChild("Seller3")
    elseif name == "Seller 1" then return npc:FindFirstChild("Seller")
    else return npc:FindFirstChild("Seller4") end
end

local elChapo = false
local function getLaunderTrigger()
    local prompts = ws:FindFirstChild("LaunderPrompts")
    if not prompts then return nil end
    local targetPos = elChapo and Vector3.new(6557.73, 91.19, -439.28) or Vector3.new(6805.80, 18.09, -34.34)
    local best = nil
    local minDst = math.huge
    for _, trigger in ipairs(prompts:GetChildren()) do
        local part = trigger:FindFirstChild("PromptPart") or trigger:FindFirstChildWhichIsA("BasePart", true)
        if part then
            local dst = (part.Position - targetPos).Magnitude
            if dst < minDst then
                minDst = dst
                best = part
            end
        end
    end
    return best
end

local idd = tb:AddDropdown({ Id = "selected_item_option", Title = "Select Item Option", Values = iol, Default = iol[1] })
local spd = tb:AddSlider({ Id = "movement_speed", Title = "Movement Speed", Min = 0, Max = 600, Default = 300, Rounding = 0, Callback = function(v, ov) end })

tb:AddToggle({ Id = "el_chapo_toggle", Title = "El Chapo Owner (8 Items)", Default = false, Callback = function(v) elChapo = v end })

local function getBuyableItemInstance(inm)
    local folder = elChapo and ws.WorldBuyableItems:FindFirstChild("ElCapo") or ws.WorldBuyableItems:FindFirstChild("CivilianArea")
    if folder then
        local item = folder:FindFirstChild(inm)
        if item then return item end
        for _, child in ipairs(folder:GetChildren()) do
            local cn = child.Name:lower()
            local tn = inm:lower()
            if cn == tn or cn:find(tn, 1, true) or tn:find(cn, 1, true) then
                return child
            end
        end
    end
    return ws.WorldBuyableItems:FindFirstChild(inm, true)
end

local function getItemTargetPos(td)
    local fallback = elChapo and td.ElcPos or td.CivPos
    local item = getBuyableItemInstance(td.ItemName)
    if item then
        local bp = item:FindFirstChildWhichIsA("BasePart", true)
        if bp then return bp.Position end
    end
    return fallback
end

local run = false
local fth = nil
local ftg
local trackStartTime = nil
local startMoney = nil
local currentMoney = 0
local elapsedTime = 0

local function getMaxCapacity() return elChapo and 8 or 5 end

local function gs()
    if not spd then return 300 end
    local v = nil
    if type(spd.Get) == "function" then v = spd:Get() end
    if not v and spd.Value then v = spd.Value end
    return tonumber(v) or 300
end

local function gm()
    local stats = lp:FindFirstChild("ReplicatedStats")
    if stats then
        local mo = stats:FindFirstChild("Money") or stats:FindFirstChild("Cash")
        if mo then
            local rv = mo:GetAttribute("RawValue") or mo:GetAttribute("Value")
            if rv and type(rv) == "number" then return rv
            elseif mo:IsA("ValueBase") then return tonumber(mo.Value) or 0 end
        end
    end
    local ls = lp:FindFirstChild("leaderstats")
    if ls then
        local mo = ls:FindFirstChild("Money") or ls:FindFirstChild("Cash")
        if mo and mo:IsA("ValueBase") then return tonumber(mo.Value) or 0 end
    end
    local am = lp:GetAttribute("Money") or lp:GetAttribute("Cash")
    if am and type(am) == "number" then return am end
    return 0
end

local function ci(inm)
    local c = 0
    local ch = lp.Character
    local bp = lp:FindFirstChild("Backpack")
    local function cc(cnt)
        if not cnt then return end
        for _, itm in ipairs(cnt:GetChildren()) do
            local name = itm.Name:lower()
            local target = inm:lower()
            if name == target or name:find(target, 1, true) or target:find(name, 1, true) then
                c = c + 1
            elseif target:find("mona") and name:find("mona") then
                c = c + 1
            elseif target:find("avacado") and (name:find("avacado") or name:find("avocado")) then
                c = c + 1
            end
        end
    end
    cc(bp)
    cc(ch)
    return c
end

local function getTotalItems()
    local total = 0
    for _, info in pairs(io) do total = total + ci(info.ItemName) end
    return total
end

local function gso()
    local v = nil
    if type(idd.Get) == "function" then v = idd:Get() end
    if not v and idd.Value then v = idd.Value end
    if type(v) == "table" and v.Value then v = v.Value end
    v = tostring(v or "")
    if io[v] then return v, io[v] end
    for _, opt in ipairs(iol) do
        if opt == v or opt:lower():find(v:lower(), 1, true) then
            return opt, io[opt]
        end
    end
    return iol[1], io[iol[1]]
end

local function mv(tp)
    if not tp or typeof(tp) ~= "Vector3" then return end
    local tc = CFrame.new(tp.X, tp.Y, tp.Z)
    while run do
        local ch = lp.Character
        local hum = ch and ch:FindFirstChild("Humanoid")
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        
        -- If died or respawning, wait for new character
        if not ch or not hrp or not hum or hum.Health <= 0 or not hrp.Parent then
            task.wait(0.5)
            continue
        end
        
        local csp = gs()
        if csp <= 0 then task.wait(0.1) continue end
        local cp = hrp.Position
        local dst = (cp - tp).Magnitude
        if dst < 1.5 then hrp.CFrame = tc break end
        
        local dt = task.wait()
        if not run then return end
        dt = tonumber(dt) or 0.016
        csp = gs()
        if csp <= 0 then continue end
        
        local stp = csp * dt
        if stp >= dst then hrp.CFrame = tc break
        else
            local alp = math.clamp(stp / dst, 0, 1)
            pcall(function()
                hrp.CFrame = hrp.CFrame:Lerp(tc, alp)
            end)
        end
    end
end

local function hb()
    local ch = lp.Character
    local bp = lp:FindFirstChild("Backpack")
    if ch and ch:FindFirstChild("Briefcase") then return true end
    if bp and bp:FindFirstChild("Briefcase") then return true end
    return false
end

local function esp()
    local sellerName = getSelectedSellerName()
    local sp
    if sellerName == "Seller 2" then
        sp = {
            Vector3.new(6857.43, 17.34, 23.49), Vector3.new(6855.35, 17.34, 92.38),
            Vector3.new(5879.55, 17.34, 98.18), Vector3.new(4943.38, 17.34, 96.58),
            Vector3.new(4007.21, 17.34, 94.97), Vector3.new(3071.04, 17.34, 93.37),
            Vector3.new(2134.86, 17.34, 91.76), Vector3.new(1198.69, 17.34, 90.16),
            Vector3.new(262.51, 17.34, 88.56), Vector3.new(58.78, 17.34, 95.13),
            Vector3.new(59.62, 17.30, 401.90), Vector3.new(49.37, 52.60, 406.83),
            Vector3.new(52.36, 49.37, 430.99), Vector3.new(-82.61, 49.36, 429.24)
        }
    elseif sellerName == "Seller 1" then
        sp = {
            Vector3.new(6857.43, 17.34, 23.49), Vector3.new(6855.35, 17.34, 92.38),
            Vector3.new(5879.55, 17.34, 98.18), Vector3.new(4943.38, 17.34, 96.58),
            Vector3.new(4007.21, 17.34, 94.97), Vector3.new(3071.04, 17.34, 93.37),
            Vector3.new(2134.86, 17.34, 91.76), Vector3.new(1198.69, 17.34, 90.16),
            Vector3.new(262.51, 17.34, 88.56), Vector3.new(133.96, 17.34, 90.43),
            Vector3.new(132.42, 17.34, 223.90), Vector3.new(130.97, 17.36, 235.90),
            Vector3.new(131.01, 18.04, 261.44), Vector3.new(155.45, 17.05, 261.39)
        }
    elseif sellerName == "Seller 3" then
        sp = {
            Vector3.new(6857.43, 17.34, 23.49), Vector3.new(6855.35, 17.34, 92.38),
            Vector3.new(5879.55, 17.34, 98.18), Vector3.new(4943.38, 17.34, 96.58),
            Vector3.new(4007.21, 17.34, 94.97), Vector3.new(3071.04, 17.34, 93.37),
            Vector3.new(2134.86, 17.34, 91.76), Vector3.new(1198.69, 17.34, 90.16),
            Vector3.new(262.51, 17.34, 88.56), Vector3.new(-139.88, 17.34, 88.50),
            Vector3.new(-141.18, 17.30, 1151.30), Vector3.new(-208.29, 17.30, 1150.50),
            Vector3.new(-195.72, 17.04, 1244.65)
        }
    else
        sp = {
            Vector3.new(6857.43, 17.34, 23.49), Vector3.new(6855.35, 17.34, 92.38),
            Vector3.new(5879.55, 17.34, 98.18), Vector3.new(4943.38, 17.34, 96.58),
            Vector3.new(4007.21, 17.34, 94.97), Vector3.new(3071.04, 17.34, 93.37),
            Vector3.new(2134.86, 17.34, 91.76), Vector3.new(1198.69, 17.34, 90.16),
            Vector3.new(262.51, 17.34, 88.56), Vector3.new(260.52, 17.36, -44.73),
            Vector3.new(208.82, 17.03, -39.99)
        }
    end
    local ch = lp.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then
        for _, pt in ipairs(sp) do
            if not run then return false end
            mv(pt)
        end
        return true
    end
    local cidx = 1
    local mdist = math.huge
    for i, pt in ipairs(sp) do
        local d = (hrp.Position - pt).Magnitude
        if d < mdist then mdist = d cidx = i end
    end
    for i = cidx, #sp do
        if not run then return false end
        mv(sp[i])
    end
    return true
end

local function elp()
    local sellerName = getSelectedSellerName()
    local lpth
    if sellerName == "Seller 2" then
        lpth = {
            Vector3.new(-82.61, 49.36, 429.24), Vector3.new(52.36, 49.37, 430.99),
            Vector3.new(49.37, 52.60, 406.83), Vector3.new(59.62, 17.30, 401.90),
            Vector3.new(58.78, 17.34, 95.13), Vector3.new(262.51, 17.34, 88.56),
            Vector3.new(1198.69, 17.34, 90.16), Vector3.new(2134.86, 17.34, 91.76),
            Vector3.new(3071.04, 17.34, 93.37), Vector3.new(4007.21, 17.34, 94.97),
            Vector3.new(4943.38, 17.34, 96.58), Vector3.new(5879.55, 17.34, 98.18),
            Vector3.new(6855.35, 17.34, 92.38), Vector3.new(6857.43, 17.34, 23.49),
            Vector3.new(6851.19, 17.53, -40.88), Vector3.new(6816.40, 17.56, -40.54),
            Vector3.new(6805.80, 18.09, -34.34)
        }
    elseif sellerName == "Seller 1" then
        lpth = {
            Vector3.new(155.45, 17.05, 261.39), Vector3.new(131.01, 18.04, 261.44),
            Vector3.new(130.97, 17.36, 235.90), Vector3.new(132.42, 17.34, 223.90),
            Vector3.new(133.96, 17.34, 90.43), Vector3.new(262.51, 17.34, 88.56),
            Vector3.new(1198.69, 17.34, 90.16), Vector3.new(2134.86, 17.34, 91.76),
            Vector3.new(3071.04, 17.34, 93.37), Vector3.new(4007.21, 17.34, 94.97),
            Vector3.new(4943.38, 17.34, 96.58), Vector3.new(5879.55, 17.34, 98.18),
            Vector3.new(6855.35, 17.34, 92.38), Vector3.new(6857.43, 17.34, 23.49),
            Vector3.new(6851.19, 17.53, -40.88), Vector3.new(6816.40, 17.56, -40.54),
            Vector3.new(6805.80, 18.09, -34.34)
        }
    elseif sellerName == "Seller 3" then
        lpth = {
            Vector3.new(-195.72, 17.04, 1244.65), Vector3.new(-208.29, 17.30, 1150.50),
            Vector3.new(-141.18, 17.30, 1151.30), Vector3.new(-139.88, 17.34, 88.50),
            Vector3.new(262.51, 17.34, 88.56), Vector3.new(1198.69, 17.34, 90.16),
            Vector3.new(2134.86, 17.34, 91.76), Vector3.new(3071.04, 17.34, 93.37),
            Vector3.new(4007.21, 17.34, 94.97), Vector3.new(4943.38, 17.34, 96.58),
            Vector3.new(5879.55, 17.34, 98.18), Vector3.new(6855.35, 17.34, 92.38),
            Vector3.new(6857.43, 17.34, 23.49), Vector3.new(6851.19, 17.53, -40.88),
            Vector3.new(6816.40, 17.56, -40.54), Vector3.new(6805.80, 18.09, -34.34)
        }
    else
        lpth = {
            Vector3.new(208.82, 17.03, -39.99), Vector3.new(260.52, 17.36, -44.73),
            Vector3.new(262.51, 17.34, 88.56), Vector3.new(1198.69, 17.34, 90.16),
            Vector3.new(2134.86, 17.34, 91.76), Vector3.new(3071.04, 17.34, 93.37),
            Vector3.new(4007.21, 17.34, 94.97), Vector3.new(4943.38, 17.34, 96.58),
            Vector3.new(5879.55, 17.34, 98.18), Vector3.new(6855.35, 17.34, 92.38),
            Vector3.new(6857.43, 17.34, 23.49), Vector3.new(6851.19, 17.53, -40.88),
            Vector3.new(6816.40, 17.56, -40.54), Vector3.new(6805.80, 18.09, -34.34)
        }
    end
    local ch = lp.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then
        for _, pt in ipairs(lpth) do
            if not run then return false end
            mv(pt)
        end
        return true
    end
    local cidx = 1
    local mdist = math.huge
    for i, pt in ipairs(lpth) do
        local d = (hrp.Position - pt).Magnitude
        if d < mdist then mdist = d cidx = i end
    end
    for i = cidx, #lpth do
        if not run then return false end
        mv(lpth[i])
    end
    return true
end

local function bmi(inm, iprc, db)
    db = db or 0.25
    local maxCap = getMaxCapacity()
    local itemInst = getBuyableItemInstance(inm)
    if not itemInst then return false end
    
    local cmon = gm()
    local ned = maxCap - getTotalItems()
    if ned <= 0 then return false end
    local pam = math.floor(cmon / iprc)
    local atb = math.min(ned, pam)
    
    if atb > 0 then
        for i = 1, atb do
            if not run then break end
            pr:FireServer(itemInst)
            task.wait(db)
        end
        return true
    end
    return false
end

local function resetTracker()
    trackStartTime = os.clock()
    elapsedTime = 0
    local val = gm()
    startMoney = val or 0
    currentMoney = startMoney
end

local function sf()
    if run then return end
    run = true
    resetTracker()
    lib:Notify({ Title = "AutoFarm", Content = "enabled!", Duration = 2 })
    fth = task.spawn(function()
        while run do
            local ok, err = pcall(function()
                local ch = lp.Character
                local hum = ch and ch:FindFirstChild("Humanoid")
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if not ch or not hrp or not hum or hum.Health <= 0 or not hrp.Parent then
                    task.wait(1)
                    return
                end
                
                while run and hb() do
                    lib:Notify({ Title = "AutoFarm", Content = "Briefcase detected -> Laundering...", Duration = 2 })
                    if not elp() then break end
                    local lt = getLaunderTrigger()
                    if lt then
                        mv(lt.Position)
                        task.wait(0.5)
                        lr:FireServer(lt)
                    end
                    task.wait(1.5)
                    mv(Vector3.new(6816.40, 17.56, -40.54))
                    if not run then break end
                    mv(Vector3.new(6851.19, 17.53, -40.88))
                    if not run then break end
                    mv(Vector3.new(6857.43, 17.34, 23.49))
                    if not run then break end
                end
                if not run then return end
                
                local tk, td = gso()
                if not td then td = io[iol[1]] end
                
                local selectedCount = ci(td.ItemName)
                local totalItems = getTotalItems()
                local maxCap = getMaxCapacity()
                local sellerName = getSelectedSellerName()
                
                if (totalItems > 0 and selectedCount < totalItems) or (totalItems >= maxCap) then
                    lib:Notify({ Title = "AutoFarm", Content = "Selling at " .. sellerName .. "...", Duration = 2 })
                    if not esp() then return end
                    local st = getSellerInstance()
                    if st then
                        local part = st:FindFirstChild("HumanoidRootPart") or st:FindFirstChildWhichIsA("BasePart")
                        if part then mv(part.Position) end
                        task.wait(0.5)
                        sr:FireServer(st)
                    end
                    task.wait(1.5)
                elseif totalItems < maxCap and selectedCount < maxCap and gm() >= td.Price then
                    lib:Notify({ Title = "AutoFarm", Content = "Buying " .. td.ItemName .. " ("..selectedCount.."/"..maxCap..")...", Duration = 2 })
                    mv(Vector3.new(6857.43, 17.34, 23.49))
                    if not run then return end
                    
                    local targetPos = getItemTargetPos(td)
                    mv(targetPos)
                    if not run then return end
                    task.wait(0.5)
                    bmi(td.ItemName, td.Price, 0.25)
                    task.wait(0.5)
                    if not run then return end
                    mv(Vector3.new(6857.43, 17.34, 23.49))
                    if not run then return end
                elseif selectedCount > 0 then
                    lib:Notify({ Title = "AutoFarm", Content = "Selling " .. td.ItemName .. " at " .. sellerName .. "...", Duration = 2 })
                    if not esp() then return end
                    local st = getSellerInstance()
                    if st then
                        local part = st:FindFirstChild("HumanoidRootPart") or st:FindFirstChildWhichIsA("BasePart")
                        if part then mv(part.Position) end
                        task.wait(0.5)
                        sr:FireServer(st)
                    end
                    task.wait(1.5)
                else
                    task.wait(1.5)
                end
            end)
            
            if not ok then
                task.wait(1)
            end
        end
    end)
end

local function spf()
    run = false
    if fth then task.cancel(fth) fth = nil end
    lib:Notify({ Title = "AutoFarm", Content = "disabled!", Duration = 2 })
end

lp.CharacterAdded:Connect(function(newChar)
    if run then
        pcall(function()
            newChar:WaitForChild("HumanoidRootPart", 10)
            lib:Notify({ Title = "AutoFarm", Content = "Respawned, resuming farm...", Duration = 2 })
        end)
    end
end)

local iup = false
ftg = tb:AddToggle({
    Id = "autofarm_toggle", Title = "Start / Stop Auto Farm", Default = false,
    Callback = function(stt) if iup then return end if stt then sf() else spf() end end,
})
tb:AddKeybind({
    Id = "farm_keybind", Title = "Farm Keybind", Default = "F", Mode = "Toggle",
    Callback = function(s)
        iup = true
        if ftg and ftg.SetValue then ftg:SetValue(s) end
        iup = false
        if s then sf() else spf() end
    end,
})

local modDetectionEnabled = false
local targetUserIds = {
    [700913853] = true, [395178354] = true, [248521802] = true, [293652396] = true,
    [245781938] = true, [4647053869] = true, [241853519] = true, [7516459321] = true,
    [2568763019] = true, [347840260] = true, [1690777311] = true, [583547011] = true,
    [13741143] = true, [8158000] = true, [2636062189] = true, [70407408] = true,
    [25661233] = true, [2800814811] = true, [6100317] = true, [1464931650] = true,
    [45567938] = true, [20022879] = true,
}

local function triggerModSequence()
    spf()
    pcall(function() keypress(0x1B) task.wait(0.05) keyrelease(0x1B) end)
    task.wait(0.1)
    pcall(function() keypress(0x4C) task.wait(0.05) keyrelease(0x4C) end)
    task.wait(0.1)
    pcall(function() keypress(0x0D) task.wait(0.05) keyrelease(0x0D) end)
end

task.spawn(function()
    while true do
        task.wait(1)
        if modDetectionEnabled then
            for _, player in ipairs(pls:GetPlayers()) do
                if targetUserIds[player.UserId] then
                    triggerModSequence()
                    task.wait(5)
                    break
                end
            end
        end
    end
end)

tb:AddToggle({
    Id = "mod_detection_toggle",
    Title = "Mod Detection",
    Default = false,
    Callback = function(v) modDetectionEnabled = v end,
})

local trk_tab = w:AddTab({ Title = "Tracker", Icon = "bar-chart" })
local statsParagraph = trk_tab:AddParagraph({ Title = "Money Statistics", Content = "Status: Waiting for Auto Farm to start..." })
trk_tab:AddButton({
    Title = "Reset Counter ($/h)",
    Callback = function()
        if run then
            resetTracker()
            lib:Notify({ Title = "Tracker", Content = "Counter reset!", Duration = 2 })
        else
            lib:Notify({ Title = "Tracker", Content = "Start Auto Farm first!", Duration = 2 })
        end
    end,
})

task.spawn(function()
    while true do
        if run then
            local liveMoney = gm()
            if liveMoney ~= nil then
                if startMoney == nil then startMoney = liveMoney trackStartTime = os.clock() end
                currentMoney = liveMoney
                local diff = currentMoney - startMoney
                elapsedTime = math.max(1, os.clock() - (trackStartTime or os.clock()))
                local moneyPerHour = math.floor((diff / elapsedTime) * 3600)
                local hrs = math.floor(elapsedTime / 3600)
                local mins = math.floor((elapsedTime % 3600) / 60)
                local secs = math.floor(elapsedTime % 60)
                local timeStr = string.format("%02dh %02dm %02ds", hrs, mins, secs)
                local sign = diff >= 0 and "+" or ""
                local contentText = string.format(
                    "Status: Active\nCurrent Money: $%s\nGained / Lost: %s$%s\nElapsed Time: %s\nMoney / Hour Rate: $%s / hour",
                    tostring(currentMoney), sign, tostring(diff), timeStr, tostring(moneyPerHour)
                )
                if statsParagraph.SetContent then statsParagraph:SetContent(contentText)
                elseif statsParagraph.SetText then statsParagraph:SetText(contentText) end
            end
        else
            if startMoney ~= nil then
                local diff = currentMoney - startMoney
                local duration = math.max(1, elapsedTime)
                local moneyPerHour = math.floor((diff / duration) * 3600)
                local hrs = math.floor(duration / 3600)
                local mins = math.floor((duration % 3600) / 60)
                local secs = math.floor(duration % 60)
                local timeStr = string.format("%02dh %02dm %02ds", hrs, mins, secs)
                local sign = diff >= 0 and "+" or ""
                local contentText = string.format(
                    "Status: Stopped (Start farm to track)\nCurrent Money: $%s\nGained / Lost: %s$%s\nElapsed Time: %s\nMoney / Hour Rate: $%s / hour",
                    tostring(currentMoney), sign, tostring(diff), timeStr, tostring(moneyPerHour)
                )
                if statsParagraph.SetContent then statsParagraph:SetContent(contentText) end
            else
                if statsParagraph.SetContent then statsParagraph:SetContent("Status: Waiting for Auto Farm to start...") end
            end
        end
        task.wait(1)
    end
end)

local cf = w:AddTab({ Title = "Config", Icon = "save" })
w:BuildConfigSection(cf)
lib:LoadAutoloadConfig()

local stt_tab = w:AddTab({ Title = "Settings", Icon = "settings" })
w:BuildInterfaceSection(stt_tab)

local cr = w:AddTab({ Title = "Credits", Icon = "info" })
cr:AddParagraph({ Title = "Credits", Content = "Original script by @xban11\nUI by @d.unne\nRecoded by @makor444" })
