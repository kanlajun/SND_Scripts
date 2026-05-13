--[=====[
[[SND Metadata]]
author: kanlajun
version: 0.0.5
description: |
  Spends currencies on desired items
  - Allied and Centurios on Aetheryte Tickets (up to 999)
  - Poetics on Goblinol
  - Orange Gatherer Scrips on Mount Tokens
  - Purple Gatherer Scrips on Hi-Cordials (up to 999) then Guile Materia XI
plugin_dependencies:
- vnavmesh
- Lifestream
- YesAlready
configs:
  Quest Check?:
    description: |
      Will perform a quest completion check for quests that expand the scrip vendors.
      Will only perform this check and not spend any currencies until turned off.
      This is a safety mechanism to ensure that the correct items get pruchased.
    default: true
  Spend Allied?:
    description: Spend Allied Seals on Atheryte tickets
    default: true
  Spend Centurio?:
    description: Spend Centurio Seals on Atheryte tickets
    default: true
  Aetheryte Ticket Cap:
    description: Number of Atheryte Tickets to purchase up to
    default: 999
  Spend Poetics?:
    description: Spend Allied Seals on Atheryte tickets
    default: true
  Spend Orange Gatherer Scrips?:
    description: Spend Orange Gatherer Scrips on Mount Tokens
    default: true
  Spend Purple Gatherer Scrips?:
    description: |
      Spend Purple Gatherer Scrips on Hi-Cordials and then Guile Materia XI
    default: true
  Hi-Cordial Cap:
    description: Number of Hi-Cordials to purchase up to
    default: 999
[[End Metadata]]
--]=====]
--[[
********************************************************************************
*                                Change Log                                    *
********************************************************************************
0.0.5 - Use configs to toggle spending different currencies on or off
0.0.4 - Scrip vendor quest check
0.0.3 - allied and centurios is fairly stable...ish?
0.0.2 - initial allied and centurios spending
0.0.1 - initial commits
********************************************************************************
*                                  To-Do                                       *
********************************************************************************
- spend OCS and PCS
- spend bicolor on vouchers
- eventually offload goblinol and then buy G6DM with the proceeds
- somehow check if the appropriate quests to expand the scrip shop are complete
  otherwise some of the indecies get outta whack
********************************************************************************
*           Code: Don't touch this unless you know what you're doing           *
********************************************************************************
]]

import("System.Numerics")

_MACRO_LOG_TITLE = "CurrencyDump"

Settings = {
    logTitle      = "CurrencyDump",
    questCheck    = true,
    spendAllied   = true,
    spendCenturio = true,
    ticketCap     = 999,
    spendPoetics  = true,
    spendOrangeG  = true,
    spendPurpleG  = true,
    hiCordialCap  = 999
}  

Currency = 
{
    Poetics             = 28,
    AlliedSeals         = 27,
    CenturioSeals       = 10307,
    SackOfNuts          = 26533,
    BicolorGemstones    = 26807,
    PurpleCrafterScrip  = 33913,
    PurpleGathererScrip = 33914,
    OrangeCrafterScrip  = 41784,
    OrangeGathererScrip = 41785
}

PoeticTurnIn =
{
    position  = Vector3(-12.3, 211.0, -40.85),
    npcName   = "Hismena",
    zoneId    = 478,
    itemName  = "Goblinol", -- For reference only
    itemId    = 16732,
    catIndex  = 7,
    itemIndex = 6,
    price     = 10
}

ScripTurnIn =
{
    position = Vector3(-17.3, 206.5, 49.8),
    npcName  = "Scrip Exchange",
    zoneId   = 478,
    Purple   = 
    {
        {
            itemName    = "Hi-Cordial",
            itemId      = 12669,
            catIndex    = 4,
            subCatIndex = 1,
            itemIndex   = 0,
            price       = 20
        },
        {
            itemName    = "Gatherer's Guile Materia XI",
            itemId      = 41763,
            catIndex    = 5,
            subCatIndex = 1,
            itemIndex   = 1,
            price       = 250
        }
    },
    Orange = {
        itemName    = "Mount Token", -- For reference only
        itemId      = 41807,
        catIndex    = 4,
        subCatIndex = 8,
        itemIndex   = 7,
        price       = 1000
    }
}

AlliedTurnIn = {
    GC = {
        {
            position       = Vector3(96.0, 40.2, 60.7),
            lifestreamName = "Aftcastle",
            zoneId         = 128,
        },
        {
            position       = Vector3(-73.9, -0.5, 1.5),
            lifestreamName = "New Gridania",
            zoneId = 132
        },
        {
            position       = Vector3(-151.8, 4.1, -94.3),
            lifestreamName = "Steps of Nald",
            zoneId         = 130
        }
    },
    npcName   = "Hunt Billmaster",
    itemName  = "Aetheryte Ticket",
    itemId    = 7569,
    catIndex  = 4,
    itemIndex = 1,
    price     = 5
}

CenturioTurnIn = {
    position  = Vector3(94.4, 15.0, 31.6),
    npcName   = "Ardolain",
    zoneId    = 418,
    itemName  = "Aetheryte Ticket",
    itemId    = 7569,
    catIndex  = 0,
    itemIndex = 1,
    price     = 5
}

SelectTurnInPage = false
PurpleIndex = 1

function Logger(logMessage)
    local logTitle = Settings.logTitle
    local fullLogMessage = "["..logTitle.."] "..logMessage
    yield("/echo "..fullLogMessage)
    Dalamud.Log(fullLogMessage)
end

function Teleport(aetheryteName, zoneId)
    yield("/li "..aetheryteName)
    Logger("Initiate Teleport")

    if zoneId == nil then
        while not Svc.Condition[CharacterCondition.betweenAreas] do
            yield("/wait 0.1")
        end
        while Svc.Condition[CharacterCondition.betweenAreas] or IPC.Lifestream.IsBusy() do
            yield("/wait 0.1")
        end
    else
        while Svc.ClientState.TerritoryType ~= zoneId do
            yield("/wait 1")
        end
    end
    Logger("Finished Teleport")
end

function GoToAlliedTurnIn()
    local currentZone = Svc.ClientState.TerritoryType
    local dist = GetDistanceToPoint(AlliedTurnIn.GC[Player.GrandCompany].position)
    if currentZone ~= AlliedTurnIn.GC[Player.GrandCompany].zoneId then
        Teleport(AlliedTurnIn.GC[Player.GrandCompany].lifestreamName, AlliedTurnIn.GC[Player.GrandCompany].zoneId)
    elseif dist > 5 then
        if not IPC.vnavmesh.PathfindInProgress() and not IPC.vnavmesh.IsRunning() then
            yield("/wait 5")
            yield("/gaction sprint")
            IPC.vnavmesh.PathfindAndMoveTo(AlliedTurnIn.GC[Player.GrandCompany].position, false)
        end
    elseif State ~= CharacterState.spendAllied then
        State = CharacterState.spendAllied
        Logger("Buying "..AlliedTurnIn.itemName.." with Allied Seals")
    end
end

function GoToCenturioTurnIn()
    local currentZone = Svc.ClientState.TerritoryType
    local dist = GetDistanceToPoint(CenturioTurnIn.position)
    if currentZone ~= CenturioTurnIn.zoneId then
        Teleport("Forgotten Knight")
    elseif dist > 5 then
        if not IPC.vnavmesh.PathfindInProgress() and not IPC.vnavmesh.IsRunning() then
            yield("/wait 5")
            yield("/gaction sprint")
            IPC.vnavmesh.PathfindAndMoveTo(CenturioTurnIn.position, false)
        end
    elseif State ~= CharacterState.spendCenturio then
        yield("/wait 2")
        State = CharacterState.spendCenturio
        Logger("Buying "..CenturioTurnIn.itemName.." with Centurio Seals")
    end
end

function GoToPoeticTurnIn()
    local currentZone = Svc.ClientState.TerritoryType
    local dist = GetDistanceToPoint(PoeticTurnIn.position)
    if currentZone ~= PoeticTurnIn.zoneId then
        Teleport("Idyllshire")
    elseif dist > 5 then
        if not Svc.Condition[CharacterCondition.mounted] then
            yield('/gaction "mount roulette"')
            yield("/wait 1")
        elseif not IPC.vnavmesh.PathfindInProgress() and not IPC.vnavmesh.IsRunning() then
            IPC.vnavmesh.PathfindAndMoveTo(PoeticTurnIn.position, false)
        end
    elseif State ~= CharacterState.spendPoetics then
        State = CharacterState.spendPoetics
        Logger("Purchasing "..PoeticTurnIn.itemName.." from "..PoeticTurnIn.npcName)
    end
end

function GoToScripTurnIn()
    local currentZone = Svc.ClientState.TerritoryType
    local dist = GetDistanceToPoint(ScripTurnIn.position)
    if currentZone ~= ScripTurnIn.zoneId then
        Teleport("Idyllshire")
    elseif dist > 5 then
        if not Svc.Condition[CharacterCondition.mounted] then
            yield('/gaction "mount roulette"')
            yield("/wait 1")
        elseif not IPC.vnavmesh.PathfindInProgress() and not IPC.vnavmesh.IsRunning() then
            IPC.vnavmesh.PathfindAndMoveTo(ScripTurnIn.position, false)
        end
    elseif State ~= CharacterState.spendOrange then
        State = CharacterState.spendOrange
        Logger("Purchasing items with Scrips")
    end
end

function SpendAllied()
    local allied    = Inventory.GetItemCount(Currency.AlliedSeals)
    local itemCount = Inventory.GetItemCount(AlliedTurnIn.itemId)
    local needed    = 999 - itemCount
    local canBuy    = math.min(allied//AlliedTurnIn.price,99)
    local toBuy     = math.min(math.min(canBuy,99),needed)

    if not Settings.spendAllied or allied < AlliedTurnIn.price or toBuy <= 0 then
        if Addons.GetAddon("ShopExchangeCurrency").Ready then
            yield("/callback ShopExchangeCurrency true -1")
        else
            local centurio = Inventory.GetItemCount(Currency.CenturioSeals)
            if Settings.spendCenturio and Inventory.GetItemCount(CenturioTurnIn.itemId) < 999 and Inventory.GetItemCount(Currency.CenturioSeals) > CenturioTurnIn.price then
                State = CharacterState.goToCenturioTurnIn
                Logger("We still have less than 999 "..CenturioTurnIn.itemName.." and have more than "..CenturioTurnIn.price.." Centurio Seals... Heading to Centurio vendor.")
            elseif Settings.spendPoetics then
                State = CharacterState.goToPoeticTurnIn
                Logger("Heading to Poetics vendor.")
            elseif Settings.spendOrangeG or Settings.spendPurpleG then
                State = CharacterState.goToScripTurnIn
                Logger("Heading to Scrip vendor.")
            else
                StopFlag = true
                Logger("No other spending is enabled.")
            end
        end
        return
    end

    GoToAlliedTurnIn()

    if not Entity.Target or Entity.Target.Name ~= AlliedTurnIn.npcName then
        yield("/target "..AlliedTurnIn.npcName)
    elseif Addons.GetAddon("SelectIconString").Ready then
        yield("/callback SelectIconString true "..AlliedTurnIn.catIndex)
    elseif Addons.GetAddon("SelectYesno").Ready then
        yield("/callback SelectYesno true 0")
    elseif Addons.GetAddon("ShopExchangeCurrency").Ready then
        yield("/callback ShopExchangeCurrency false 0 "..AlliedTurnIn.itemIndex.." "..toBuy.." 0")
    else
        yield("/interact")
    end
end

function SpendCenturio()
    local centurio  = Inventory.GetItemCount(Currency.CenturioSeals)
    local itemCount = Inventory.GetItemCount(CenturioTurnIn.itemId)
    local needed    = 999 - itemCount
    local canBuy    = math.min(centurio//CenturioTurnIn.price,99)
    local toBuy     = math.min(math.min(canBuy,99),needed)

    if not Settings.spendCenturio or centurio < CenturioTurnIn.price or toBuy <= 0 then
        if Addons.GetAddon("ShopExchangeCurrency").Ready then
            yield("/callback ShopExchangeCurrency true -1")
            yield("/wait 0.5")
            yield("/callback SelectString true 3")
        elseif Addons.GetAddon("SelectString").Ready then
            yield("/callback SelectString true 3")
        elseif Settings.spendPoetics then
            State = CharacterState.goToPoeticTurnIn
            Logger("Heading to Poetics vendor.")
        elseif Settings.spendOrangeG or Settings.spendPurpleG then
            State = CharacterState.goToScripTurnIn
            Logger("Heading to Scrip vendor.")
        else
            StopFlag = true
            Logger("No other spending is enabled.")
        end
        return
    end

    GoToCenturioTurnIn()

    if not Entity.Target or Entity.Target.Name ~= CenturioTurnIn.npcName then
        yield("/target "..CenturioTurnIn.npcName)
    elseif Addons.GetAddon("SelectString").Ready then
        yield("/callback SelectString true "..CenturioTurnIn.catIndex)
    elseif Addons.GetAddon("SelectYesno").Ready then
        yield("/callback SelectYesno true 0")
    elseif Addons.GetAddon("ShopExchangeCurrency").Ready then
        yield("/callback ShopExchangeCurrency false 0 "..CenturioTurnIn.itemIndex.." "..toBuy.." 0")
    else
        yield("/interact")
    end
end

function SpendPoetics()
    local poetics = Inventory.GetItemCount(Currency.Poetics)
    local toBuy =  math.min(poetics//PoeticTurnIn.price,99)

    if not Settings.spendPoetics or poetics < PoeticTurnIn.price then
        if Addons.GetAddon("ShopExchangeCurrency").Ready then
            yield("/callback ShopExchangeCurrency true -1")
        elseif Settings.spendOrangeG or Settings.spendPurpleG then
            yield("/wait 3")
            State = CharacterState.goToScripTurnIn
            Logger("Heading to Scrip vendor.")
        else
            StopFlag = true
            Logger("No other spending is enabled.")
        end
        return
    end

    GoToPoeticTurnIn()

    if not Entity.Target or Entity.Target.Name ~= PoeticTurnIn.npcName then
        yield("/target "..PoeticTurnIn.npcName)
    elseif Addons.GetAddon("SelectIconString").Ready then
        yield("/callback SelectIconString true "..PoeticTurnIn.catIndex)
    elseif Addons.GetAddon("SelectYesno").Ready then
        yield("/callback SelectYesno true 0")
    elseif Addons.GetAddon("ShopExchangeCurrency").Ready then
        yield("/callback ShopExchangeCurrency false 0 "..PoeticTurnIn.itemIndex.." "..toBuy.." 0")
    else
        yield("/interact")
    end
end

function SpendOrange()
    local ogs = Inventory.GetItemCount(Currency.OrangeGathererScrip)
    local toBuy =  math.min(ogs//ScripTurnIn.Orange.price,4)

    if not Settings.spendOrangeG or ogs < ScripTurnIn.Orange.price then
        if Addons.GetAddon("InclusionShop").Ready then
            yield("/callback InclusionShop true -1")
        elseif Settings.spendPurpleG then
            SelectTurnInPage = false
            State = CharacterState.spendPurple
            Logger("WIP Buying "..ScripTurnIn.Purple[PurpleIndex].itemName)
        else
            StopFlag = true
            Logger("No other spending is enabled.")
        end
        return
    end

    GoToScripTurnIn()

    if not Entity.Target or Entity.Target.Name ~= ScripTurnIn.npcName then
        yield("/target "..ScripTurnIn.npcName)
    elseif Addons.GetAddon("SelectIconString").Ready then
        yield("/callback SelectIconString true 0")
    elseif Addons.GetAddon("InclusionShop").Ready then
      if not SelectTurnInPage then
          yield("/callback InclusionShop true 12 "..ScripTurnIn.Orange.catIndex)
          yield("/wait 1")
          yield("/callback InclusionShop true 13 "..ScripTurnIn.Orange.subCatIndex)
          yield("/wait 1")
          SelectTurnInPage = true
      end
      qty = math.min(Inventory.GetItemCount(Currency.OrangeGathererScrip)//ScripTurnIn.Orange.price, 4)
      yield("/callback InclusionShop true 14 "..ScripTurnIn.Orange.itemIndex.." "..qty)
      yield("/wait 1")
    else
        yield("/interact")
    end
end

function SpendPurple()
    local toBuy = 0
    if PurpleIndex > 2 then
        if Addons.GetAddon("InclusionShop").Ready then
            yield("/callback InclusionShop true -1")
        else
            SelectTurnInPage = false
            PurpleIndex = 1
            State = CharacterState.sell
            Logger("WIP Selling "..PoeticTurnIn.itemName)
        end
    elseif PurpleIndex == 1 then

        local pgs = Inventory.GetItemCount(Currency.PurpleGathererScrip)
        local itemCount = Inventory.GetItemCount(ScripTurnIn.Purple[PurpleIndex].itemId)
        local needed = 999 - itemCount
        local canBuy =  math.min(pgs//ScripTurnIn.Purple[PurpleIndex].price,99)
        toBuy = math.min(math.min(canBuy,99),needed)
        
        if not Settings.spendPurpleG or pgs < ScripTurnIn.Purple[PurpleIndex].price or toBuy <= 0 then
            if Addons.GetAddon("InclusionShop").Ready then
                yield("/callback InclusionShop true -1")
            else
                SelectTurnInPage = false
                PurpleIndex = PurpleIndex + 1
                Logger("WIP Buying "..ScripTurnIn.Purple[PurpleIndex].itemName)
            end
            return
        end
    else
        local pgs = Inventory.GetItemCount(Currency.PurpleGathererScrip)
        local itemCount = Inventory.GetItemCount(ScripTurnIn.Purple[PurpleIndex].itemId)
        toBuy =  math.min(pgs//ScripTurnIn.Purple[PurpleIndex].price,16)
        
        if not Settings.spendPurpleG or pgs < ScripTurnIn.Purple[PurpleIndex].price then
            if Addons.GetAddon("InclusionShop").Ready then
                yield("/callback InclusionShop true -1")
            else
                SelectTurnInPage = false
                PurpleIndex = PurpleIndex + 1
                Logger("WIP Selling "..PoeticTurnIn.itemName)
            end
            return
        end
    end

    if not Entity.Target or Entity.Target.Name ~= ScripTurnIn.npcName then
        yield("/target "..ScripTurnIn.npcName)
    elseif Addons.GetAddon("SelectIconString").Ready then
        yield("/callback SelectIconString true 0")
    elseif Addons.GetAddon("InclusionShop").Ready then
      if not SelectTurnInPage then
          yield("/callback InclusionShop true 12 "..ScripTurnIn.Purple[PurpleIndex].catIndex)
          yield("/wait 1")
          yield("/callback InclusionShop true 13 "..ScripTurnIn.Purple[PurpleIndex].subCatIndex)
          yield("/wait 1")
          SelectTurnInPage = true
      end
      -- qty = math.min(Inventory.GetItemCount(Currency.OrangeGathererScrip)//ScripTurnIn.Orange.price, 4)
      yield("/callback InclusionShop true 14 "..ScripTurnIn.Purple[PurpleIndex].itemIndex.." "..toBuy)
      yield("/wait 1")
    else
        yield("/interact")
    end
end

function TurnIn()
    local ore = Inventory.GetItemCount(OreItemId)
    if ore == 0 then
        if Addons.GetAddon("ShopExchangeItem").Ready then
            yield("/callback ShopExchangeItem true -1")
        else
            StopFlag = true
        end
        return
    end

    GoToPoeticTurnIn()

    if GetTargetName() ~= PoeticTurnIn.turnInNpc then
        yield("/target "..PoeticTurnIn.turnInNpc)
    elseif IsAddonVisible("SelectIconString") then
        yield("/callback SelectIconString true 5")
    elseif IsAddonVisible("ShopExchangeItemDialog") then
        yield("/callback ShopExchangeItemDialog true 0")
    elseif IsAddonVisible("ShopExchangeItem") then
        yield("/callback ShopExchangeItem true 0 1 "..ore.." 0")
    else
        yield("/interact")
    end
end

function Sell()
    Logger("Sell "..PoeticTurnIn.itemName)
    
    local goblinol = Inventory.GetItemCount(PoeticTurnIn.itemId)
    if goblinol == 0 then
        if Addons.GetAddon("ShopExchangeItem").Ready then
            yield("/callback ShopExchangeItem true -1")
        else
            yield("/li auto")
            StopFlag = true
            Logger("WIP Buying G6DM")
        end
        return
    end

    yield("/li auto")
    StopFlag = true
    Logger("WIP Returning to home")
end

function Ready()
    if Settings.spendAllied and Inventory.GetItemCount(CenturioTurnIn.itemId) < 999 and Inventory.GetItemCount(Currency.AlliedSeals) > AlliedTurnIn.price then
        Logger("Less than 999 "..CenturioTurnIn.itemName.." and more than "..AlliedTurnIn.price.." Allied Seals... Heading to Allied Seals vendor.")
        State = CharacterState.goToAlliedTurnIn
    elseif Settings.spendCenturio and Inventory.GetItemCount(CenturioTurnIn.itemId) < 999 and Inventory.GetItemCount(Currency.CenturioSeals) > CenturioTurnIn.price then
        Logger("Less than 999 "..CenturioTurnIn.itemName.." and more than "..CenturioTurnIn.price.." Centurio Seals... Heading to Allied Seals vendor.")
        State = CharacterState.goToCenturioTurnIn
    elseif Settings.spendPoetics and Inventory.GetItemCount(Currency.Poetics) > PoeticTurnIn.price then
        Logger("More than "..PoeticTurnIn.price.." Poetics... Heading to Poetic vendor to purchase "..PoeticTurnIn.itemName..".")
        State = CharacterState.goToPoeticTurnIn
    elseif Settings.spendOrangeG and Inventory.GetItemCount(Currency.OrangeGathererScrip) > ScripTurnIn.Orange.price then
        Logger("More than "..ScripTurnIn.Orange.price.." Orange Gatherer's Scrips... Heading to Scrip vendor to purchase "..ScripTurnIn.Orange.itemName..".")
        State = CharacterState.goToScripTurnIn
    elseif Settings.spendPurpleG and Inventory.GetItemCount(ScripTurnIn.Purple[1].itemId) < 999 and Inventory.GetItemCount(Currency.PurpleGathererScrip) > ScripTurnIn.Purple[1].price then
        Logger("Less than 999 "..ScripTurnIn.Purple[1].itemName.." and more than"..ScripTurnIn.Purple[1].price" Purple Gatherer's Scrips... Heading to Scrip vendor.")
        State = CharacterState.goToScripTurnIn
    elseif Settings.spendPurpleG and Inventory.GetItemCount(Currency.PurpleGathererScrip) > ScripTurnIn.Purple[2].price then
        Logger("More than "..ScripTurnIn.Purple[2].price.." Purple Gatherer's Scrips... Heading to Scrip vendor to purchase "..ScripTurnIn.Purple[2].itemName..".")
        State = CharacterState.goToScripTurnIn
    elseif Inventory.GetItemCount(PoeticTurnIn.itemId) >= 0 then
        Logger("We have some Goblinol... Heading to sell WIP.")
        State = CharacterState.sell
    else
        Logger("Nothing to do...")
        StopFlag = true
    end
end

function GetDistanceToPoint(position)
    local player = Entity.Player
    if not player or not player.Position then
        return math.huge
    end

    local px = player.Position.X
    local py = player.Position.Y
    local pz = player.Position.Z

    local dX = position.X
    local dY = position.Y
    local dZ = position.Z

    local dx = dX - px
    local dy = dY - py
    local dz = dZ - pz

    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    return distance
end

function RefreshSettings()
    local questCheck = Config.Get("Quest Check?")
    if questCheck ~= nil then
        Settings.questCheck = questCheck
    end

    local spendAllied = Config.Get("Spend Allied?")
    if spendAllied ~= nil then
        Settings.spendAllied = spendAllied
    end

    local spendCenturio = Config.Get("Spend Centurio?")
    if spendCenturio ~= nil then
        Settings.spendCenturio = spendCenturio
    end
    
    local ticketCap = Config.Get("Aetheryte Ticket Cap")
    if type(ticketCap) == "number" then
        Settings.ticketCap = ticketCap
    end
    
    local spendPoetics = Config.Get("Spend Poetics?")
    if spendPoetics ~= nil then
        Settings.spendPoetics = spendPoetics
    end

    local spendOrangeG = Config.Get("Spend Orange Gatherer Scrips?")
    if spendOrangeG ~= nil
        Settings.spendOrangeG = spendOrangeG
    end

    local spendPurpleG = Config.Get("Spend Purple Gatherer Scrips?")
    if spendPurpleG ~= nil
        Settings.spendPurpleG = spendPurpleG
    end
    
    local hiCordialCap = Config.Get("Hi-Cordial Cap")
    if type(hiCordialCap) == "number" then
        Settings.hiCordialCap = hiCordialCap
    end
end

function QuestCheck()
    local numComplete = 0

    for questIdx = 1, #RequiredQuests do
        local name = RequiredQuests[questIdx].name
        local id   = RequiredQuests[questIdx].id

        if not Quests.IsQuestComplete(id) then
            local zone  = RequiredQuests[questIdx].zone
            local x     = RequiredQuests[questIdx].x
            local y     = RequiredQuests[questIdx].y
            local giver = RequiredQuests[questIdx].giver
            safeSetFlagMapMarker(zone, x, y)
            Logger(name.." not completed. Speak with "..giver.." at <flag> to accept.")
        else
            numComplete = numComplete + 1
            Logger(name.." is complete.")
        end
    end

    if numComplete ~= #RequiredQuests then
        local numMissing = #RequiredQuests - numComplete
        Logger("There are "..numMissing.." scrip vendor expansions that are still locked. It is not safe to disable the Quest Check in the config until these are completed.")
    else
        Logger("All scrip vendor expansions are unlocked. It is safe to disable the Quest Check in the config.")
    end
end

function safeSetFlagMapMarker(territoryId, x, y)
    territoryId = tonumber(territoryId)
    x = tonumber(x)
    y = tonumber(y)

    if not territoryId or not x or not y then
        return false
    end

    if not (Instances and Instances.Map and Instances.Map.Flag and Instances.Map.Flag.SetFlagMapMarker) then
        return false
    end

    local ok = pcall(function()
        Instances.Map.Flag:SetFlagMapMarker(territoryId, x, y)
    end)

    return ok
end

RequiredQuests = 
{
    {
        name  = "Inscrutable Tastes",
        id    = 67631,
        zone  = 418,
        x     = -54.43,
        y     = -38.10,
        giver = "Morgayne"
    },
    {
        name  = "Go West, Craftsman",
        id    = 67634,
        zone  = 156,
        x     = 45.61,
        y     = -732.91,
        giver = "Lydirlona"
    },
    {
        name = "Reach Long and Prosper",
        id   = 68477,
        zone  = 635,
        x     = -70.54,
        y     = 64.38,
        giver = "Galiena"
    },
    {
        name = "The Boutique Always Wins",
        id   = 69139,
        zone  = 820,
        x     = 12.985352,
        y     = -25.22,
        giver = "Mowen"
    },
    {
        name = "Expanding House of Splendors",
        id   = 69711,
        zone  = 963,
        x     = 24.22,
        y     = -80.74,
        giver = "Ofpilona"
    },
    {
        name = "Dawn of a New Deal",
        id   = 70544,
        zone  = 1186,
        x     = -157.64,
        y     = -38.13,
        giver = "Rhodina"
    },
    {
        name = "Mislaid Plans",
        id   = 69384,
        zone  = 418,
        x     = 151.48,
        y     = 65.90,
        giver = "Skysteel Engineer"
    }
}

CharacterCondition = {
    mounted=4,
    gathering=6,
    inCombat=26,
    casting=27,
    occupiedInEvent=31,
    occupiedInQuestEvent=32,
    occupied=33,
    boundByDuty=34,
    occupiedMateriaExtractionAndRepair=39,
    gathering42=42,
    fishing=43,
    betweenAreas=45,
    jumping48=48,
    jumpPlatform=61,
    betweenAreas51=51,
    boundByDuty56=56,
    mounting57=57,
    mounting64=64,
    beingMoved=70,
    flying=77
}

CharacterState =
{
    ready              = Ready,
    goToAlliedTurnIn   = GoToAlliedTurnIn,
    goToCenturioTurnIn = GoToCenturioTurnIn,
    goToPoeticTurnIn   = GoToPoeticTurnIn,
    goToScripTurnIn    = GoToScripTurnIn,
    spendAllied        = SpendAllied,
    spendCenturio      = SpendCenturio,
    spendPoetics       = SpendPoetics,
    spendOrange        = SpendOrange,
    spendPurple        = SpendPurple,
    sell               = Sell,
    turnIn             = TurnIn
}

--#region Main

RefreshSettings()

State = CharacterState.ready
StopFlag = false

if Settings.questCheck then
    QuestCheck()
    StopFlag = true
end

while not StopFlag do
    State()
    yield("/wait 0.1")
end

--#endregion Main