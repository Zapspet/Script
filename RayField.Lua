--[[
    SCRIPT COMPLET RAYFIELD FUSIONNÉ (v3)
    Fonctionnalités :
    - Onglet 1: Gestion des Rifts (sélection, détails, vol, cycle auto, auto-éclosion oeufs BGSI)
    - Onglet 2: Collecte automatique pour BGSI (Gemmes & Pièces)
]]

---------------------------------------------------------------------------------
-- CONFIGURATION INITIALE ET SERVICES
---------------------------------------------------------------------------------
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Pour les RemoteEvents
local Rayfield 

-- !! IMPORTANT : Configurez ces chemins pour la collecte BGSI (Onglet 2) !!
local GEMS_CONTAINER_PATH_BGSI = "Workspace.ExamplePath.Gems" 
local COINS_CONTAINER_PATH_BGSI = "Workspace.ExamplePath.Coins"

-- !! IMPORTANT : Configurez ceci pour l'éclosion d'oeufs dans les Rifts de BGSI (Onglet 1) !!
local EGG_OBJECT_NAME_IN_RIFT_BGSI = "NomDeLOeufDansLeRift" -- Ex: "RiftEgg", "SpecialEgg"
local HATCH_REMOTE_EVENT_NAME_RIFTEGG_BGSI = "HatchRiftEggEvent" -- Ex: Nom du RemoteEvent pour éclore
-- local PATH_TO_EGGS_INSIDE_RIFT_OBJECT_BGSI = "EggsFolder" -- Ex: Si les oeufs sont dans un sous-dossier de l'objet Rift

---------------------------------------------------------------------------------
-- VARIABLES GLOBALES
---------------------------------------------------------------------------------
-- Pour la gestion des Rifts
_G.SelectedRift = ""
_G.EnableAutoFlyToRift_Direct = false
_G.AutoCycleRiftEnabled = false
_G.CurrentRiftNameForCycle = ""
_G.AutoHatchRiftEggEnabled_BGSI = false -- Pour la nouvelle fonctionnalité
local hatchCoroutine_RiftEgg_BGSI -- Coroutine pour l'éclosion d'oeufs de rift BGSI

-- Pour la collecte BGSI (Onglet 2)
local autoCollectEnabled_BGSI = false
local collectCoroutine_BGSI 

---------------------------------------------------------------------------------
-- FONCTIONS UTILITAIRES (COMMUNES ET SPÉCIFIQUES)
---------------------------------------------------------------------------------

-- Fonctions pour la gestion des Rifts (getRiftNames, getRiftDetails, flyPlayerToRiftByName, riftCycleLoop)
-- ... (COLLER ICI LES FONCTIONS getRiftNames, getRiftDetails, flyPlayerToRiftByName, riftCycleLoop de la réponse précédente) ...
-- Assurez-vous qu'elles sont bien présentes. Pour la concision, je ne les répète pas ici.
-- Rappel pour getRiftDetails :
function getRiftDetails(riftObject)
    local details = { timer = "N/A", luck = "Aucun" }
    if not riftObject then return details end
    local displayGui = riftObject:FindFirstChild("DisplayGui") 
    if displayGui then
        local timerLabel = displayGui:FindFirstChild("TimerText") 
        if timerLabel and timerLabel:IsA("TextLabel") then details.timer = timerLabel.Text end
    end
    local luckMultiplierAttr = riftObject:GetAttribute("LuckMultiplier") 
    if luckMultiplierAttr then details.luck = "x" .. tostring(luckMultiplierAttr)
    else
        local luckValueObj = riftObject:FindFirstChild("LuckMultiplier")
        if luckValueObj and (luckValueObj:IsA("IntValue") or luckValueObj:IsA("NumberValue") or luckValueObj:IsA("StringValue")) then
            details.luck = "x" .. tostring(luckValueObj.Value)
        end
    end
    return details
end
function getRiftNames()
    local riftNames = {}
    local renderedFolder = Workspace:FindFirstChild("Rendered", true)
    local riftsContainer
    if renderedFolder then riftsContainer = renderedFolder:FindFirstChild("Rifts") end
    if riftsContainer and typeof(riftsContainer.GetChildren) == "function" then
        local children = riftsContainer:GetChildren()
        if #children > 0 then
            for _, riftObject in ipairs(children) do table.insert(riftNames, riftObject.Name) end
        else
            table.insert(riftNames, "Aucune faille trouvée")
        end
    else
        print("AVERTISSEMENT (Rifts): 'workspace.Rendered.Rifts' non trouvé.")
        table.insert(riftNames, "Erreur: Rifts non trouvés")
    end
    return riftNames
end
function flyPlayerToRiftByName(riftName, flightDuration)
    flightDuration = flightDuration or 3
    local localPlayerFly = Players.LocalPlayer
    if not localPlayerFly or not localPlayerFly.Character then print("VolRift: Joueur/personnage non trouvé."); return false end
    local characterFly = localPlayerFly.Character
    local humanoidFly = characterFly:FindFirstChildOfClass("Humanoid")
    local hrpFly = characterFly:FindFirstChild("HumanoidRootPart")
    if not humanoidFly or not hrpFly then print("VolRift: Humanoïde/HRP non trouvé."); return false end

    local renderedFolder = Workspace:FindFirstChild("Rendered", true)
    local riftsContainerFly
    if renderedFolder then riftsContainerFly = renderedFolder:FindFirstChild("Rifts") end
    if not riftsContainerFly then print("VolRift: Conteneur Rifts non trouvé."); return false end
    local riftObjectFly = riftsContainerFly:FindFirstChild(riftName)
    if not riftObjectFly then print("VolRift: Rift '" .. riftName .. "' non trouvé."); return false end

    local targetCFrameValueFly
    if riftObjectFly:IsA("Model") and riftObjectFly.PrimaryPart then targetCFrameValueFly = riftObjectFly.PrimaryPart.CFrame
    elseif riftObjectFly:IsA("BasePart") then targetCFrameValueFly = riftObjectFly.CFrame
    else print("VolRift: Rift '"..riftName.."' invalide."); return false end
    
    local destinationCFrameFly = targetCFrameValueFly * CFrame.new(0, 5, 0)
    local originalAnchorStateFly = hrpFly.Anchored
    local originalPlatformStandFly = humanoidFly.PlatformStand
    hrpFly.Anchored = true; humanoidFly.PlatformStand = true
    print("VolRift: Début du vol vers " .. riftName)
    local tweenInfoFly = TweenInfo.new(flightDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
    local tweenFly = TweenService:Create(hrpFly, tweenInfoFly, {CFrame = destinationCFrameFly})
    tweenFly:Play(); tweenFly.Completed:Wait()
    hrpFly.Anchored = originalAnchorStateFly; humanoidFly.PlatformStand = originalPlatformStandFly
    humanoidFly:ChangeState(Enum.HumanoidStateType.RunningNoPhysics); task.wait(0.1); humanoidFly:ChangeState(Enum.HumanoidStateType.GettingUp)
    print("VolRift: Arrivé à " .. riftName); return true
end
function riftCycleLoop()
    print("CycleRift: Lancement pour " .. _G.CurrentRiftNameForCycle)
    while _G.AutoCycleRiftEnabled and _G.CurrentRiftNameForCycle ~= "" do
        local riftsContCycle = Workspace:FindFirstChild("Rendered", true)
        if riftsContCycle then riftsContCycle = riftsContCycle:FindFirstChild("Rifts") end
        if not riftsContCycle then print("CycleRift: Conteneur Rifts non trouvé. Pause 5s."); task.wait(5); if not _G.AutoCycleRiftEnabled then break end; continue end

        local currentRiftObjCycle = riftsContCycle:FindFirstChild(_G.CurrentRiftNameForCycle)
        if currentRiftObjCycle then
            print("CycleRift: '" .. _G.CurrentRiftNameForCycle .. "' trouvé. Vol...");
            if flyPlayerToRiftByName(_G.CurrentRiftNameForCycle, 3) then
                print("CycleRift: Arrivé. Surveillance...");
                local monitoringStart = tick()
                while _G.AutoCycleRiftEnabled and currentRiftObjCycle and currentRiftObjCycle.Parent do
                    local detailsCycle = getRiftDetails(currentRiftObjCycle)
                    if detailsCycle.timer == "00:00" or detailsCycle.timer == "N/A" or detailsCycle.timer == "" or string.lower(detailsCycle.timer) == "terminé" then
                        print("CycleRift: Timer '" .. _G.CurrentRiftNameForCycle .. "' terminé."); break
                    end
                    task.wait(1)
                    if tick() - monitoringStart > 300 then print("CycleRift: Surveillance > 5min. Forcer recherche."); break end
                end
                if not _G.AutoCycleRiftEnabled then break end
                print("CycleRift: '" .. _G.CurrentRiftNameForCycle .. "' disparu/arrêté. Recherche...");
            else print("CycleRift: Échec vol vers '" .. _G.CurrentRiftNameForCycle .. "'. Nouvelle tentative 5s."); task.wait(5) end
        else print("CycleRift: '" .. _G.CurrentRiftNameForCycle .. "' non trouvé. Attente réapparition..."); task.wait(5) end
        if not _G.AutoCycleRiftEnabled then break end; task.wait(0.1)
    end
    print("CycleRift: Boucle pour '" .. (_G.CurrentRiftNameForCycle or "aucun") .. "' terminée.")
end


-- Fonctions pour la collecte BGSI (getPlayerCharacterParts_BGSI, collectItem_BGSI, autoCollectLoop_BGSI)
-- ... (COLLER ICI LES FONCTIONS getPlayerCharacterParts_BGSI, collectItem_BGSI, autoCollectLoop_BGSI de la réponse précédente) ...
-- Assurez-vous qu'elles sont bien présentes.
local player_BGSI = Players.LocalPlayer
local character_BGSI
local humanoidRootPart_BGSI
local function getPlayerCharacterParts_BGSI()
    if not player_BGSI then return false end
    character_BGSI = player_BGSI.Character
    if not character_BGSI then return false end
    humanoidRootPart_BGSI = character_BGSI:FindFirstChild("HumanoidRootPart")
    return humanoidRootPart_BGSI ~= nil
end
function collectItem_BGSI(item)
    if not item or not item:IsA("BasePart") or not item.Parent or not getPlayerCharacterParts_BGSI() then return end
    humanoidRootPart_BGSI.CFrame = CFrame.new(item.Position) * CFrame.new(0, -(humanoidRootPart_BGSI.Size.Y / 2) + 0.5, 0)
    task.wait(0.05)
end
function autoCollectLoop_BGSI()
    print("BGSI Auto Collect: Boucle démarrée.")
    while autoCollectEnabled_BGSI do
        if not getPlayerCharacterParts_BGSI() then
            print("BGSI Auto Collect: Attente personnage..."); task.wait(1); if not autoCollectEnabled_BGSI then break end; continue
        end
        local gemsContainer_BGSI = Workspace
        for _, partName in ipairs(string.split(GEMS_CONTAINER_PATH_BGSI, ".")) do if gemsContainer_BGSI then gemsContainer_BGSI = gemsContainer_BGSI:FindFirstChild(partName) else break end end
        local coinsContainer_BGSI = Workspace
        for _, partName in ipairs(string.split(COINS_CONTAINER_PATH_BGSI, ".")) do if coinsContainer_BGSI then coinsContainer_BGSI = coinsContainer_BGSI:FindFirstChild(partName) else break end end

        if gemsContainer_BGSI then
            for _, gem in ipairs(gemsContainer_BGSI:GetChildren()) do
                if not autoCollectEnabled_BGSI then break end
                if gem:IsA("BasePart") and gem.Parent and (humanoidRootPart_BGSI.Position - gem.Position).Magnitude < 150 then
                    collectItem_BGSI(gem); if not autoCollectEnabled_BGSI then break end; task.wait()
                end
            end
        end; if not autoCollectEnabled_BGSI then break end
        if coinsContainer_BGSI then
            for _, coin in ipairs(coinsContainer_BGSI:GetChildren()) do
                if not autoCollectEnabled_BGSI then break end
                if coin:IsA("BasePart") and coin.Parent and (humanoidRootPart_BGSI.Position - coin.Position).Magnitude < 150 then
                    collectItem_BGSI(coin); if not autoCollectEnabled_BGSI then break end; task.wait()
                end
            end
        end; if not autoCollectEnabled_BGSI then break end
        task.wait(0.25)
    end
    print("BGSI Auto Collect: Boucle terminée."); collectCoroutine_BGSI = nil
end


-- NOUVELLES Fonctions pour l'éclosion d'oeufs de Rift BGSI
local player_RiftEggHatch = Players.LocalPlayer
local character_RiftEggHatch
local humanoidRootPart_RiftEggHatch

local function getPlayerParts_RiftEggHatch()
    if not player_RiftEggHatch then return false end
    character_RiftEggHatch = player_RiftEggHatch.Character
    if not character_RiftEggHatch then return false end
    humanoidRootPart_RiftEggHatch = character_RiftEggHatch:FindFirstChild("HumanoidRootPart")
    return humanoidRootPart_RiftEggHatch ~= nil
end

function attemptHatch_RiftEgg_BGSI(eggObject)
    if not eggObject or not eggObject.Parent or not getPlayerParts_RiftEggHatch() then
        print("AutoHatchRiftBGSI: Objet oeuf invalide ou personnage non trouvé.")
        return
    end
    print("AutoHatchRiftBGSI: Tentative d'éclosion pour " .. eggObject.Name)
    local originalCFrame_Hatch = humanoidRootPart_RiftEggHatch.CFrame
    humanoidRootPart_RiftEggHatch.CFrame = CFrame.new(eggObject.Position) - Vector3.new(0, humanoidRootPart_RiftEggHatch.Size.Y/2 - eggObject.Size.Y/2, 0) + (humanoidRootPart_RiftEggHatch.CFrame.LookVector * -3) -- Se positionner devant
    task.wait(0.2)

    -- Logique d'interaction (À ADAPTER PRÉCISÉMENT POUR BGSI)
    local hatchRemote = ReplicatedStorage:FindFirstChild(HATCH_REMOTE_EVENT_NAME_RIFTEGG_BGSI, true) -- Recherche récursive
    if hatchRemote and hatchRemote:IsA("RemoteEvent") then
        print("AutoHatchRiftBGSI: Utilisation du RemoteEvent '" .. HATCH_REMOTE_EVENT_NAME_RIFTEGG_BGSI .. "'")
        hatchRemote:FireServer(eggObject) -- Les paramètres peuvent varier !
        task.wait(1) -- Délai pour l'éclosion
    else
        print("AutoHatchRiftBGSI: RemoteEvent '" .. HATCH_REMOTE_EVENT_NAME_RIFTEGG_BGSI .. "' non trouvé ou méthode d'interaction inconnue.")
        print("AutoHatchRiftBGSI: Vous devrez implémenter la méthode d'interaction correcte ici (ex: clic, ProximityPrompt).")
        -- Exemple ProximityPrompt (si applicable):
        -- local prompt = eggObject:FindFirstChildWhichIsA("ProximityPrompt")
        -- if prompt then prompt:InputHoldBegin(); task.wait(prompt.HoldDuration); prompt:InputHoldEnd() end
    end
    -- Optionnel: revenir en arrière
    -- humanoidRootPart_RiftEggHatch.CFrame = originalCFrame_Hatch
end

function autoHatchRiftEggLoop_BGSI()
    print("AutoHatchRiftBGSI: Boucle démarrée.")
    while _G.AutoHatchRiftEggEnabled_BGSI do
        if not getPlayerParts_RiftEggHatch() then
            print("AutoHatchRiftBGSI: Attente personnage..."); task.wait(1); if not _G.AutoHatchRiftEggEnabled_BGSI then break end; continue
        end

        if not _G.SelectedRift or _G.SelectedRift == "" or _G.SelectedRift == "Aucune faille trouvée" or _G.SelectedRift == "Erreur: Rifts non trouvés" then
            print("AutoHatchRiftBGSI: Aucun Rift valide sélectionné. Pause."); task.wait(2); if not _G.AutoHatchRiftEggEnabled_BGSI then break end; continue
        end

        local riftsCont = Workspace:FindFirstChild("Rendered", true); if riftsCont then riftsCont = riftsCont:FindFirstChild("Rifts") end
        if not riftsCont then print("AutoHatchRiftBGSI: Conteneur Rifts non trouvé. Pause."); task.wait(2); if not _G.AutoHatchRiftEggEnabled_BGSI then break end; continue end
        
        local currentRiftObj = riftsCont:FindFirstChild(_G.SelectedRift)
        if not currentRiftObj then print("AutoHatchRiftBGSI: Rift '" .. _G.SelectedRift .. "' non trouvé. Pause."); task.wait(2); if not _G.AutoHatchRiftEggEnabled_BGSI then break end; continue end

        print("AutoHatchRiftBGSI: Recherche d'oeufs dans le Rift '" .. currentRiftObj.Name .. "' nommés '".. EGG_OBJECT_NAME_IN_RIFT_BGSI .."'")
        local eggFoundAndAttempted = false
        local eggContainer = currentRiftObj -- Par défaut, chercher directement dans l'objet Rift
        -- Si PATH_TO_EGGS_INSIDE_RIFT_OBJECT_BGSI est défini:
        -- if PATH_TO_EGGS_INSIDE_RIFT_OBJECT_BGSI and PATH_TO_EGGS_INSIDE_RIFT_OBJECT_BGSI ~= "" then
        --    eggContainer = currentRiftObj:FindFirstChild(PATH_TO_EGGS_INSIDE_RIFT_OBJECT_BGSI, true) -- Recherche récursive
        -- end

        if eggContainer then
            for _, potentialEgg in ipairs(eggContainer:GetChildren()) do
                if not _G.AutoHatchRiftEggEnabled_BGSI then break end
                if potentialEgg.Name == EGG_OBJECT_NAME_IN_RIFT_BGSI and potentialEgg:IsA("BasePart") then
                    attemptHatch_RiftEgg_BGSI(potentialEgg)
                    eggFoundAndAttempted = true
                    task.wait(1.5) -- Attendre un peu après une tentative avant de chercher le suivant
                    if not _G.AutoHatchRiftEggEnabled_BGSI then break end
                end
            end
        else
            -- print("AutoHatchRiftBGSI: Conteneur d'oeufs non trouvé dans le Rift '".. currentRiftObj.Name .."'")
        end
        
        if not eggFoundAndAttempted then
            -- print("AutoHatchRiftBGSI: Aucun oeuf nommé '"..EGG_OBJECT_NAME_IN_RIFT_BGSI.."' trouvé dans le Rift actuel. Réessayer dans 5s.")
        end
        
        if not _G.AutoHatchRiftEggEnabled_BGSI then break end
        task.wait(5) -- Pause avant de re-vérifier le même rift pour de nouveaux oeufs
    end
    print("AutoHatchRiftBGSI: Boucle terminée."); hatchCoroutine_RiftEgg_BGSI = nil
end

---------------------------------------------------------------------------------
-- CHARGEMENT DE RAYFIELD ET CRÉATION DE L'UI PRINCIPALE
---------------------------------------------------------------------------------
local success, errorMsg = pcall(function()
    Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/Zapspet/Script/b74d4b9ac38fa7522c3529a033df48b5e92830fc/RayField.Lua', true))()
end)
if not success or not Rayfield or not Rayfield.CreateWindow then
    warn("ERREUR CRITIQUE RAYFIELD: " .. tostring(errorMsg)); return
end
print("Bibliothèque Rayfield chargée avec succès.")

local Window = Rayfield:CreateWindow({
    Name = "Panneau de Contrôle Multifonctions v2",
    LoadingTitle = "Chargement du Panneau...",
    LoadingSubtitle = "par VotreNom", 
    ConfigurationSaving = { Enabled = true, FolderName = "MonConfigRayfieldFusionV2", FileName = "SettingsGlobalV2" }
})

---------------------------------------------------------------------------------
-- ONGLET 1: GESTION DES RIFTS
---------------------------------------------------------------------------------
local TabRifts = Window:CreateTab("Gestion Rifts", nil) -- Premier onglet

TabRifts:CreateLabel("--- Infos Rift Sélectionné ---")
local SelectedRiftNameLabel_Rifts = TabRifts:CreateLabel("Rift sélectionné : Aucun")
local RiftTimerLabel_Rifts = TabRifts:CreateLabel("Minuteur : N/A")
local RiftLuckLabel_Rifts = TabRifts:CreateLabel("Chance : N/A")
TabRifts:CreateLabel("--- Contrôles de Déplacement Rift ---")
local AutoFlySimpleToggle_Rifts = TabRifts:CreateToggle({
    Name = "Activer Vol Direct vers Rift", Default = _G.EnableAutoFlyToRift_Direct,
    Callback = function(value)
        if _G.AutoCycleRiftEnabled and value then print("Désactivez Cycle Auto pour Vol Direct."); AutoFlySimpleToggle_Rifts:Set(false); return end
        if _G.AutoHatchRiftEggEnabled_BGSI and value then print("Désactivez Auto Hatch BGSI pour Vol Direct."); AutoFlySimpleToggle_Rifts:Set(false); return end
        _G.EnableAutoFlyToRift_Direct = value; print("Vol direct " .. (value and "activé." or "désactivé."))
    end
})

local AutoCycleModeToggle_Rifts = TabRifts:CreateToggle({
    Name = "Cycle Auto: Rester & Revisiter Rift", Default = _G.AutoCycleRiftEnabled,
    Callback = function(value)
        if _G.AutoHatchRiftEggEnabled_BGSI and value then print("Désactivez Auto Hatch BGSI pour Cycle Auto."); AutoCycleModeToggle_Rifts:Set(false); return end
        _G.AutoCycleRiftEnabled = value
        if value then
            if _G.SelectedRift and _G.SelectedRift ~= "" and _G.SelectedRift ~= "Aucune faille trouvée" and _G.SelectedRift ~= "Erreur: Rifts non trouvés" then
                _G.CurrentRiftNameForCycle = _G.SelectedRift
                print("Cycle auto activé pour : " .. _G.CurrentRiftNameForCycle); task.spawn(riftCycleLoop)
            else
                print("Sélectionnez un Rift valide pour le Cycle Auto."); _G.AutoCycleRiftEnabled = false; AutoCycleModeToggle_Rifts:Set(false)
            end
        else print("Cycle auto désactivé."); _G.CurrentRiftNameForCycle = "" end
    end
})

TabRifts:CreateLabel("--- Auto Éclosion Oeufs Rift (BGSI) ---")
TabRifts:CreateLabel("NOTE: Cible le Rift sélectionné ci-dessus.")
local AutoHatchRiftEggToggle_BGSI = TabRifts:CreateToggle({
    Name = "Activer Auto Hatch Oeufs (Rift BGSI)",
    Default = _G.AutoHatchRiftEggEnabled_BGSI,
    Callback = function(value)
        if (_G.AutoCycleRiftEnabled or _G.EnableAutoFlyToRift_Direct) and value then
             print("Désactivez les autres modes de déplacement Rift avant d'activer Auto Hatch.")
             AutoHatchRiftEggToggle_BGSI:Set(false) -- Remettre à false si Rayfield le permet
             return
        end
        _G.AutoHatchRiftEggEnabled_BGSI = value
        if value then
            if _G.SelectedRift and _G.SelectedRift ~= "" and _G.SelectedRift ~= "Aucune faille trouvée" and _G.SelectedRift ~= "Erreur: Rifts non trouvés" then
                print("Auto Hatch Oeufs BGSI (Rift) activé pour : " .. _G.SelectedRift)
                if not hatchCoroutine_RiftEgg_BGSI or coroutine.status(hatchCoroutine_RiftEgg_BGSI) == "dead" then
                    hatchCoroutine_RiftEgg_BGSI = task.spawn(autoHatchRiftEggLoop_BGSI)
                end
            else
                print("Veuillez sélectionner un Rift valide pour l'Auto Hatch Oeufs.")
                _G.AutoHatchRiftEggEnabled_BGSI = false; AutoHatchRiftEggToggle_BGSI:Set(false)
            end
        else
            print("Auto Hatch Oeufs BGSI (Rift) désactivé.")
        end
    end
})


local riftNameList_Rifts = getRiftNames()
_G.SelectedRift = riftNameList_Rifts[1] or ""

local RiftSelectorDropdown_Rifts = TabRifts:CreateDropdown({
    Name = "Sélectionner une Faille :", Content = riftNameList_Rifts, Default = _G.SelectedRift,
    Callback = function(chosenRiftName)
        if chosenRiftName == "Aucune faille trouvée" or chosenRiftName == "Erreur: Rifts non trouvés" then
            _G.SelectedRift = ""; SelectedRiftNameLabel_Rifts:Set("Rift : Aucun")
            RiftTimerLabel_Rifts:Set("Minuteur : N/A"); RiftLuckLabel_Rifts:Set("Chance : N/A"); return
        end
        local oldSelectedRift = _G.SelectedRift
        _G.SelectedRift = chosenRiftName; SelectedRiftNameLabel_Rifts:Set("Rift : " .. chosenRiftName)
        local riftsContDrop = Workspace:FindFirstChild("Rendered",true); if riftsContDrop then riftsContDrop=riftsContDrop:FindFirstChild("Rifts") end
        if riftsContDrop then local riftObjDrop = riftsContDrop:FindFirstChild(chosenRiftName)
            if riftObjDrop then local detailsDrop = getRiftDetails(riftObjDrop)
                RiftTimerLabel_Rifts:Set("Minuteur : " .. detailsDrop.timer); RiftLuckLabel_Rifts:Set("Chance : " .. detailsDrop.luck)
            else RiftTimerLabel_Rifts:Set("Minuteur : (Err)"); RiftLuckLabel_Rifts:Set("Chance : (Err)") end
        else RiftTimerLabel_Rifts:Set("Minuteur : (Err Cont.)"); RiftLuckLabel_Rifts:Set("Chance : (Err Cont.)") end
        
        if _G.EnableAutoFlyToRift_Direct and not _G.AutoCycleRiftEnabled and not _G.AutoHatchRiftEggEnabled_BGSI then flyPlayerToRiftByName(chosenRiftName) end
        
        -- Si un mode auto est actif et que le rift change, l'utilisateur doit le relancer sur la nouvelle cible
        if (_G.AutoCycleRiftEnabled or _G.AutoHatchRiftEggEnabled_BGSI) and oldSelectedRift ~= chosenRiftName then
             print("Mode Auto actif. Pour cibler '"..chosenRiftName.."', désactivez et réactivez le mode Auto correspondant.")
             -- Pour une màj dynamique de la cible du cycle (plus complexe):
             -- if _G.AutoCycleRiftEnabled then _G.CurrentRiftNameForCycle = chosenRiftName end
             -- Si AutoHatch est actif, il utilisera _G.SelectedRift qui vient d'être mis à jour.
        end
    end
})

local ManualFlyButton_Rifts = TabRifts:CreateButton({
    Name = "Voler vers Rift (Manuel)",
    Callback = function()
        if _G.AutoCycleRiftEnabled then print("Vol manuel désactivé (Cycle Auto actif)."); return end
        if _G.AutoHatchRiftEggEnabled_BGSI then print("Vol manuel désactivé (Auto Hatch BGSI actif)."); return end
        if not _G.EnableAutoFlyToRift_Direct then print("Vol direct désactivé."); return end
        if _G.SelectedRift and _G.SelectedRift ~= "" and _G.SelectedRift ~= "Aucune faille trouvée" and _G.SelectedRift ~= "Erreur: Rifts non trouvés" then
            flyPlayerToRiftByName(_G.SelectedRift)
        else print("Aucune faille valide sélectionnée.") end
    end
})

-- Init labels Rifts
if _G.SelectedRift and _G.SelectedRift ~= "" and _G.SelectedRift ~= "Aucune faille trouvée" and _G.SelectedRift ~= "Erreur: Rifts non trouvés" then
    SelectedRiftNameLabel_Rifts:Set("Rift : " .. _G.SelectedRift)
    local riftsInitCont = Workspace:FindFirstChild("Rendered",true); if riftsInitCont then riftsInitCont=riftsInitCont:FindFirstChild("Rifts") end
    if riftsInitCont then local riftInitObj = riftsInitCont:FindFirstChild(_G.SelectedRift)
        if riftInitObj then local detailsInit = getRiftDetails(riftInitObj)
            RiftTimerLabel_Rifts:Set("Minuteur : " .. detailsInit.timer); RiftLuckLabel_Rifts:Set("Chance : " .. detailsInit.luck)
        else RiftTimerLabel_Rifts:Set("Minuteur : N/A"); RiftLuckLabel_Rifts:Set("Chance : N/A") end
    else RiftTimerLabel_Rifts:Set("Minuteur : N/A"); RiftLuckLabel_Rifts:Set("Chance : N/A") end
else SelectedRiftNameLabel_Rifts:Set("Rift : Aucun"); RiftTimerLabel_Rifts:Set("Minuteur : N/A"); RiftLuckLabel_Rifts:Set("Chance : N/A") end


---------------------------------------------------------------------------------
-- ONGLET 2: COLLECTE BGSI (inchangé par rapport à la fusion précédente)
---------------------------------------------------------------------------------
local TabBGSI = Window:CreateTab("BGSI Collecte", nil) -- Deuxième onglet

TabBGSI:CreateLabel("Collecte Auto pour Bubble Gum Simulator Infinity")
TabBGSI:CreateLabel("IMPORTANT: Configurez les chemins GEMS et COINS")
TabBGSI:CreateLabel("en haut du script (GEMS_CONTAINER_PATH_BGSI)!")

local AutoGrabToggle_BGSI = TabBGSI:CreateToggle({
    Name = "Activer Auto Grab Gems & Coins (BGSI)",
    Default = autoCollectEnabled_BGSI,
    Callback = function(value)
        autoCollectEnabled_BGSI = value
        if autoCollectEnabled_BGSI then
            print("BGSI Auto Collect: Activé.")
            if not collectCoroutine_BGSI or coroutine.status(collectCoroutine_BGSI) == "dead" then
                collectCoroutine_BGSI = task.spawn(autoCollectLoop_BGSI)
            end
        else
            print("BGSI Auto Collect: Désactivé.")
        end
    end
})

print("Interface Rayfield Fusionnée v2 (avec Auto Hatch Rift BGSI) initialisée et prête.")
