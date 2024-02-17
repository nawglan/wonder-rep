local addonName, addonSpace = ...
local addon   = LibStub('AceAddon-3.0'):NewAddon(addonSpace, addonName, 'AceEvent-3.0', 'AceTimer-3.0')

WR = addon

local timerId = nil
local configFrame = nil

local L = LibStub('AceLocale-3.0'):GetLocale(addonName)

local VERSION = GetAddOnMetadata(addonName, 'Version')

local libLDB  = LibStub('LibDataBroker-1.1')
local libQTip = LibStub('LibQTip-1.0')
local WRTip -- Tooltip object


local libRealmInfo = LibStub("LibRealmInfo")

local amountGained = 0

local db
local current, currentMaxXp, startXp
local sessionTime

local sv_defaults = {
    global = {
        display_level = true,
        display_name = true,
        display_percent = true,
        display_time = true,
        change_bar = false,
        change_bar_announce = true,
        announce_time_left = true,
        announce_chat_frame = false,
        announce_left = true
    },
    char = {
        session = 0,
        sesstionTime = 0,
        bufferedRepGain = "",
        reputation = {

        }
    }
}

local options = {
}

local repLevels = {
    [1] = L["HATED"],
    [2] = L["HOSTILE"],
    [3] = L["UNFRIENDLY"],
    [4] = L["NEUTRAL"],
    [5] = L["FRIENDLY"],
    [6] = L["HONORED"],
    [7] = L["REVERED"],
    [8] = L["EXALTED"],
    [9] = L["MAXEXALTED"]
}

local unitsFriends = {
    [1] = L["Stranger"],          --     0 -  8400
    [2] = L["Acquaintance"],      --  8400 - 16800
    [3] = L["Buddy"],             -- 16800 - 25200
    [4] = L["Friend"],            -- 25200 - 33600
    [5] = L["Good Friend"],       -- 33600 - 42000
    [6] = L["Best Friend"]        -- 42000 - 42999
}

local unitsBodyguards = {
    [1] = L["Bodyguard"],         --     0 - 10000
    [2] = L["Trusted Bodyguard"], -- 10000 - 20000
    [3] = L["Personal Wingman"]   -- 20000 - 30000
}

local unitsAzerothianArchives = {
    [1] = L["Junior"],            --     0 - 10500
    [2] = L["Capable"],           -- 10500 - 31500
    [3] = L["Learned"],           -- 31500 - 64000
    [4] = L["Resident"]           -- 64000 - 106000
    [5] = L["Tenured"]            --106000
}

local unitsSoridormi = {
    [1] = L["Anomaly"],           --     0 - 7000
    [2] = L["Future Friend"],     --  7000 - 14000
    [3] = L["Rift-Mender"],       -- 14000 - 24000
    [4] = L["Timewalker"]         -- 24000 - 42000
    [5] = L["Legend"]             -- 42000
}

local unitsGlimmeroggRacer = {
    [1] = L["Aspirational"],      --     0 - 700
    [2] = L["Amateur"],           --   700 - 1400
    [3] = L["Competent"],         --  1400 - 2100
    [4] = L["Skilled"]            --  2100 - 2800
    [5] = L["Professional"]       --  2800
}

local unitsArtisanConsortium = {
    [1] = L["NEUTRAL"],           --     0 - 500
    [2] = L["Preferred"],         --   500 - 2500
    [3] = L["Respected"],         --  2500 - 5500
    [4] = L["Valued"]             --  5500 - 12500
    [5] = L["Esteemed"]           -- 12500
}

local unitsCobaltAssembly = {
    [1] = L["Empty"],             --     0 - 300
    [2] = L["Low"],               --   300 - 1500
    [3] = L["Medium"],            --  1500 - 5100
    [4] = L["High"]               --  5100 - 15100
    [5] = L["Maximum"]            -- 15100
}

local unitsValdrakkenAccord = {
    [1] = L["Acquaintance"],      --     0 - 8400
    [2] = L["Cohort"],            --  8400 - 16800
    [3] = L["Ally"],              -- 16800 - 25200
    [4] = L["Fang"]               -- 25200 - 33600
    [5] = L["Friend"]             -- 33600 - 42000
    [6] = L["True Friend"]        -- 42000
}

local SEX = UnitSex("player")

local function GetRegionStartOfWeek()
    local region = libRealmInfo:GetCurrentRegion()
    if region == "US" then
        return 3
    elseif region == "EU" then
        return 4
    else
        return 3 -- FIXME
    end
end

function addon:GetFactionLabel(standingId)
    if standingId == "paragon" then return "Paragon" end
    return (SEX == 2 and _G["FACTION_STANDING_LABEL" .. standingId]) or _G["FACTION_STANDING_LABEL" .. standingId .. "_FEMALE"] or "?"
end

function addon:PLAYER_ENTERING_WORLD(event, ...)
    local isInitialLogin, isReloadingUi = ...

    if isInitialLogin then
        for k in pairs(self.db.char.reputation) do
            self.db.char.reputation[k].gainedSession = 0
        end
        self.db.char.session = 0
        self.db.char.sessionTime = 0
        self.db.char.lastRepGained = nil
    end
    addon:ConfigFrame()
    self:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE") -- changes in faction come in on this channel
    self:RegisterEvent("CHAT_MSG_SYSTEM") -- New factions come in on this channel

    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self.PLAYER_ENTERING_WORLD = nil
    self:CheckStatsResets()
    self:UpdateFactions()
    self:SetBrokerText()

end

local function PrintHelp()
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("-----------------------------------")
    DEFAULT_CHAT_FRAME:AddMessage(L["WonderRep commands help:"])
    DEFAULT_CHAT_FRAME:AddMessage(L["Use /wonderrep <command> or /wr <command> to perform the following commands:"])
    DEFAULT_CHAT_FRAME:AddMessage("help -- " .. L["You are viewing it!"])
    DEFAULT_CHAT_FRAME:AddMessage("options -- " ..L["OPENOPTIONS"])
    --print("status -- " .. L["Shows your current settings."])
    --print("announce -- " .. L["Toggles the displaying of reputation points needed to next level message."])
    --print("timeleft -- " .. L("HELPTIMELEFT"))
    --print("autobar -- " .. L("HELPAUTOBAR"))
    --print("barchange -- " .. L("HELPBARCHANGE"))
    --print("interval -- " .. L("HELPINTERVAL"))
    --print("color -- " .. L("HELPCOLOR"))
    DEFAULT_CHAT_FRAME:AddMessage("-----------------------------------")
    DEFAULT_CHAT_FRAME:AddMessage(" ")
end

function addon:CHAT_MSG_COMBAT_FACTION_CHANGE(event, ...)
    arg1 = ...
    addon:UpdateFactions()
    -- Reputation with <REPNAME> increased by <AMOUNT>.
    local HasIndexStart, HasIndexStop, FactionName, AmountGained = string.find(arg1, L["Reputation with (.*) increased by (%d+)."])
    if HasIndexStart == nil then
        -- Try the Ve'nari one
        HasIndexStart, HasIndexStop, FactionName, AmountGained = string.find(arg1, L["(.+) judges .+ %[(%d+) reputation gained%.%]"])
        if HasIndexStart == nil then
            -- Try the 2nd string for spanish
            HasIndexStart, HasIndexStop, FactionName, AmountGained = string.find(arg1, L["REPMATCHSTR2"])
            if HasIndexStart == nil then
                -- Try the 2nd string for spanish
                HasIndexStart, HasIndexStop, FactionName, AmountGained = string.find(arg1, L["Your (.*) reputation has increased by (%d+)."])
                if HasIndexStart == nil then
                    -- still not found, probably not the string we want
                    return
                end
            end
        end
    end

    local factionIncreasedBy = 1
    factionIncreasedBy = AmountGained + 0 -- ensure that the string value is converted to an integer
    if FactionName == L["Guild"] then
        return
    end

    local RepIndex, standingId, topValue, earnedValue, factionID = addon:GetRepMatch(FactionName)
    if RepIndex ~= nil then
        self.db.char.lastSaved = time()
        self.db.char.reputation[FactionName].gainedSession = self.db.char.reputation[FactionName].gainedSession + factionIncreasedBy
        self.db.char.reputation[FactionName].gainedDay = self.db.char.reputation[FactionName].gainedDay + factionIncreasedBy
        self.db.char.reputation[FactionName].gainedWeek = self.db.char.reputation[FactionName].gainedWeek + factionIncreasedBy
        amountGained = amountGained + factionIncreasedBy
        local nextStandingId = standingId + 1
        local repLeftToLevel = 0
        local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = C_GossipInfo.GetFriendshipReputation(factionID)
        if (friendID) then
            local currentRank, maxRank = C_GossipInfo.GetFriendshipReputationRanks(factionID)
            -- print(currentRank, maxRank)
        end

        if addon:isFriendRep(FactionName) or addon:isValdrakkenRep(FactionName) then
            local tmpVal = earnedValue / 8400
            local tmpValInt = floor(tmpVal)
            nextStandingId = tmpValInt + 2
            if nextStandingId > 6 then
                return
            end
            repLeftToLevel = 8400 - (8400 * (tmpVal - tmpValInt))
        elseif addon:isBodyguardRep(FactionName) then
            local tmpVal = earnedValue / 10000
            local tmpValInt = floor(tmpVal)
            nextStandingId = tmpValInt + 2
            if nextStandingId > 3 then
                return
            end
            repLeftToLevel = 10000 - (10000 * (tmpVal - tmpValInt))
        elseif addon:isAzerothianArchivesRep(FactionName) then
          if earnedValue < 10500 then
            repLeftToLevel = 10500 - earnedValue
            nextStandingId = 2
          elseif earnedValue < 31500 then
            repLeftToLevel = 31500 - earnedValue
            nextStandingId = 3
          elseif earnedValue < 64000 then
            repLeftToLevel = 64000 - earnedValue
            nextStandingId = 4
          elseif earnedValue < 106000 then
            repLeftToLevel = 106000 - earnedValue
            nextStandingId = 5
          else
            return
          end
        elseif addon:isSoridormiRep(FactionName) then
          if earnedValue < 7000 then
            repLeftToLevel = 7000 - earnedValue
            nextStandingId = 2
          elseif earnedValue < 14000 then
            repLeftToLevel = 14000 - earnedValue
            nextStandingId = 3
          elseif earnedValue < 24000 then
            repLeftToLevel = 24000 - earnedValue
            nextStandingId = 4
          elseif earnedValue < 42000 then
            repLeftToLevel = 42000 - earnedValue
            nextStandingId = 5
          else
            return
          end
        elseif addon:isGlimmeroggRacerRep(FactionName) then
          if earnedValue < 700 then
            repLeftToLevel = 700 - earnedValue
            nextStandingId = 2
          elseif earnedValue < 1400 then
            repLeftToLevel = 1400 - earnedValue
            nextStandingId = 3
          elseif earnedValue < 2100 then
            repLeftToLevel = 2100 - earnedValue
            nextStandingId = 4
          elseif earnedValue < 2800 then
            repLeftToLevel = 2800 - earnedValue
            nextStandingId = 5
          else
            return
          end
        elseif addon:isArtisanConsortiumRep(FactionName) then
          if earnedValue < 500 then
            repLeftToLevel = 500 - earnedValue
            nextStandingId = 2
          elseif earnedValue < 2500 then
            repLeftToLevel = 2500 - earnedValue
            nextStandingId = 3
          elseif earnedValue < 5500 then
            repLeftToLevel = 5500 - earnedValue
            nextStandingId = 4
          elseif earnedValue < 12500 then
            repLeftToLevel = 12500 - earnedValue
            nextStandingId = 5
          else
            return
          end
        elseif addon:isCobaltAssemblyRep(FactionName) then
          if earnedValue < 300 then
            repLeftToLevel = 300 - earnedValue
            nextStandingId = 2
          elseif earnedValue < 1500 then
            repLeftToLevel = 1500 - earnedValue
            nextStandingId = 3
          elseif earnedValue < 5100 then
            repLeftToLevel = 5100 - earnedValue
            nextStandingId = 4
          elseif earnedValue < 15100 then
            repLeftToLevel = 15100 - earnedValue
            nextStandingId = 5
          else
            return
          end
        elseif addon:isRenownRep(factionID) then
            data = C_MajorFactions.GetMajorFactionData(factionID)
            earnedValue = data['renownReputationEarned']
            nextStandingId = data['renownLevel'] + 20 -- shortcut
            topValue = data['renownLevelThreshold']
            repLeftToLevel = topValue - earnedValue
        else
            if nextStandingId > 9 then
                return
            end
            repLeftToLevel = topValue - earnedValue
        end

        local RepNextLevelName = addon:GetNextRepLevelName(FactionName, nextStandingId)

        local paraValue, paraThreshold, paraQuestId, paraRewardPending = C_Reputation.GetFactionParagonInfo(factionID)

        if C_Reputation.IsFactionParagon(factionID) then
            while (paraValue > paraThreshold) do
                paraValue = paraValue - paraThreshold
            end
            repLeftToLevel = paraThreshold - paraValue
            RepNextLevelName = L['Paragon']
        end

        local KillsToNext = ceil(.5 + (repLeftToLevel / factionIncreasedBy))
        local estimatedTimeTolevel = repLeftToLevel / (self.db.char.reputation[FactionName].gainedSession / self.db.char.sessionTime)

        if self.db.global.announce_left == true and self.db.global.announce_time_left == true then
            if self.db.global.announce_chat_frame == true then
                self:GetChatFrame(string.format("WonderRep: " .. L['REPSTRFULL'], repLeftToLevel, FactionName, RepNextLevelName, KillsToNext, self.db.char.reputation[FactionName].gainedDay, addon:TimeTextMed(estimatedTimeTolevel), RepNextLevelName))
            else
                print(string.format("WonderRep: " .. L['REPSTRFULL'], repLeftToLevel, FactionName, RepNextLevelName, KillsToNext, self.db.char.reputation[FactionName].gainedDay, addon:TimeTextMed(estimatedTimeTolevel), RepNextLevelName))
            end
        end        

        self.db.char.lastRepGained = FactionName
        self.db.char.lastRepGainedIndex = RepIndex
        if self:TimeLeft(timerId) == 0 then
            timerId = self:ScheduleTimer('ChangeWatched', 1)
        end
    end
end

function addon:GetNextRepLevelName(FactionName, standingId)
  local RepNextLevelName = ""

  if addon:isFriendRep(FactionName) and standingId <= 6 then
    RepNextLevelName = unitsFriends[standingId]
  elseif addon:isBodyguardRep(FactionName) and standingId <= 3 then
    RepNextLevelName = unitsBodyguards[standingId]
  elseif addon:isAzerothianArchivesRep(FactionName) and standingId <= 5 then
    RepNextLevelName = unitsAzerothianArchives[standingId]
  elseif addon:isSoridormiRep(FactionName) and standingId <= 5 then
    RepNextLevelName = unitsSoridormi[standingId]
  elseif addon:isGlimmeroggRacerRep(FactionName) and standingId <= 5 then
    RepNextLevelName = unitsSoridormi[standingId]
  elseif addon:isArtisanConsortiumRep(FactionName) and standingId <= 5 then
    RepNextLevelName = unitsSoridormi[standingId]
  elseif addon:isCobaltAssemblyRep(FactionName) and standingId <= 5 then
    RepNextLevelName = unitsCobaltAssembly[standingId]
  elseif addon:isValdrakkenRep(FactionName) and standingId <= 6 then
    RepNextLevelName = unitsValdkrakkenAccord[standingId]
  elseif (standingId <= 9) then
    RepNextLevelName = repLevels[standingId]
  elseif (standingId >= 20) then
    local new = standingId - 19
    RepNextLevelName = L["Renown"] .. " " .. new
  end

  return RepNextLevelName
end

function addon:isFriendRep(FactionName)
    local FriendRep = {}
    table.insert(FriendRep, L["Farmer Fung"])
    table.insert(FriendRep, L["Chee Chee"])
    table.insert(FriendRep, L["Ella"])
    table.insert(FriendRep, L["Fish Fellreed"])
    table.insert(FriendRep, L["Gina Mudclaw"])
    table.insert(FriendRep, L["Haohan Mudclaw"])
    table.insert(FriendRep, L["Jogu the Drunk"])
    table.insert(FriendRep, L["Old Hillpaw"])
    table.insert(FriendRep, L["Sho"])
    table.insert(FriendRep, L["Tina Mudclaw"])
    table.insert(FriendRep, L["Nat Pagle"])

    return tContains(FriendRep, FactionName)
end

function addon:isBodyguardRep(FactionName)
    local BodyguardRep = {}
    table.insert(BodyguardRep, L["Leorajh"])
    table.insert(BodyguardRep, L["Tormmok"])
    table.insert(BodyguardRep, L["Talonpriest Ishaal"])
    table.insert(BodyguardRep, L["Vivianne"])
    table.insert(BodyguardRep, L["Delvar Ironfist"])
    table.insert(BodyguardRep, L["Aeda Brightdawn"])
    table.insert(BodyguardRep, L["Defender Illona"])

    return tContains(BodyguardRep, FactionName)
end

function addon:isRenownRep(factionID)
    local RenownRep = {}
    table.insert(RenownRep, 2507)
    table.insert(RenownRep, 2510)
    table.insert(RenownRep, 2511)
    table.insert(RenownRep, 2503)

    return tContains(RenownRep, factionID)
end

function addon:isAzerothianArchivesRep(FactionName)
    local AzerothianRep = {}
    table.insert(AzerothianRep, L["Azerothian Archives"])

    return tContains(AzerothianRep, FactionName)
end

function addon:isSoridormiRep(FactionName)
    local SoridormiRep = {}
    table.insert(SoridormiRep, L["Soridormi"])

    return tContains(SoridormiRep, FactionName)
end

function addon:isGlimmeroggRacerRep(FactionName)
    local GlimmeroggRep = {}
    table.insert(GlimmeroggRep, L["Glimmerogg Racer"])

    return tContains(GlimmeroggRep, FactionName)
end

function addon:isArtisanConsortiumRep(FactionName)
    local ArtisanRep = {}
    table.insert(ArtisanRep, L["Artisan's Consortium - Dragon Isles Branch"])

    return tContains(ArtisanRep, FactionName)
end

function addon:isCobaltAssemblyRep(FactionName)
    local CobaltRep = {}
    table.insert(CobaltRep, L["Cobalt Assembly"])

    return tContains(CobaltRep FactionName)
end

function addon:isValdrakkenRep(FactionName)
    local ValdrakkenRep = {}
    table.insert(ValdrakkenRep, L["Wrathion"])
    table.insert(ValdrakkenRep, L["Sabellian"])

    return tContains(ValdrakkenRep, FactionName)
end

function addon:CHAT_MSG_SYSTEM(event, ...)
    local arg1 = ...
    if self.db.char.bufferedRepGain ~= "" then
        arg1 = self.db.char.bufferedRepGain
        self.db.char.bufferedRepGain = ""
    end
    -- Reputation with <REPNAME> increased by <AMOUNT>.
    local HasIndexStart, HasIndexStop, FactionName, AmountGained = string.find(arg1, L["Reputation with (.*) increased by (%d+)."])
    if HasIndexStart == nil then
      -- Try the REPMATCHSTR2
      HasIndexStart, HasIndexStop, FactionName, AmountGained = string.find(arg1, L["(.+) judges .+ %[(%d+) reputation gained%.%]"])
      if HasIndexStart == nil then
        -- still not found, probably not the string we want
        return
      else
        -- reset buffer
        self.db.char.BufferedRepGain = ""
      end
    end
end

function addon:GetRepMatch(FactionName)
    local factionIndex = 1
    local lastFactionName
    repeat
        local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
            canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(factionIndex)
        if name == lastFactionName then break end
        lastFactionName = name
        if name == FactionName then
            return factionIndex, standingId, topValue, earnedValue, factionID
        end

        factionIndex = factionIndex + 1
    until factionIndex > GetNumFactions()
end

function addon:ChangeWatched()
    if self.db.global.change_bar then
        local watchedName = GetWatchedFactionInfo()
        if self.db.char.lastRepGained ~= watchedName then
            SetWatchedFactionIndex(self.db.char.lastRepGainedIndex)
            if self.db.global.change_bar_announce == true then
                print("WonderRep: " .. L["Reputation Bar changed to:"] .. " " .. self.db.char.lastRepGained .. ".")
            end
        end
    end
end

function addon:UpdateFactions()
    local factionIndex = 1
    local lastFactionName = ""

    -- update known factions
    repeat
        local name = GetFactionInfo(factionIndex)
        if name == lastFactionName then break end
        lastFactionName = name
        if name then
            if not self.db.char.reputation[name] then
                self.db.char.reputation[name] = {
                    gainedSession = 0,
                    gainedDay = 0,
                    gainedWeek = 0
                }
            elseif self.db.char.reputation[name].gainedDay == nil then
                self.db.char.reputation[name].gainedDay = 0
                self.db.char.reputation[name].gainedWeek = 0
            end
        end
        factionIndex = factionIndex + 1
    until factionIndex > GetNumFactions()
end

function addon:GetChatFrame(msg)
    i = 0
    repeat
        i = i+1
        local name, fontSize, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(i)
        if name == nil then
            break
        end
        if name == "WonderRep" then
            _G["ChatFrame"..i]:AddMessage(msg)
        end
    until i > 100
end

function WonderRep(msg)
    if msg then
        if msg == "" then
            PrintHelp()
            InterfaceOptionsFrame_OpenToCategory(configFrame)
        elseif msg == "ct" then
            i = 0
            repeat
                i = i+1
                local name, fontSize, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(i)
                if name == nil then
                    break
                end
                if name == "WonderRep" then
                    _G["ChatFrame"..i]:AddMessage("test")
                end
            until i > 100
        elseif msg == "options" then
            InterfaceOptionsFrame_OpenToCategory(configFrame)
        elseif msg == "help" then
            PrintHelp()
        end
    end
end

local function GetTipAnchor(frame)
    local x,y = frame:GetCenter()
    if not x or not y then return "TOPLEFT", "BOTTOMLEFT" end
    local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
    local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
    return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf
end

function addon:SetTooltipContents()
    WRTip:Clear()

    local line
    line = WRTip:AddLine()
    WRTip:SetCell(line, 1, L["Reputation Earned Summary"], nil, "CENTER", 7)

    WRTip:AddSeparator();

    line = WRTip:AddLine()
    WRTip:SetCell(line, 5, L["Earned"], 3)

    line = WRTip:AddLine()
    WRTip:SetCell(line, 1, L["Faction Name"])
    WRTip:SetCell(line, 2, L["Standing"])
    WRTip:SetCell(line, 3, L["%"])
    WRTip:SetCell(line, 4, L["Time"])
    WRTip:SetCell(line, 5, L["Session"])
    WRTip:SetCell(line, 6, L["Day"])
    WRTip:SetCell(line, 7, L["Week"])

    WRTip:AddSeparator();

    local factionIndex = 1
    local lastFactionName = ""
    repeat
        local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
            canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(factionIndex)
        standingName = repLevels[standingId]
        if factionID == nil then
            break
        end

        local paraValue, paraThreshold, paraQuestId, paraRewardPending = C_Reputation.GetFactionParagonInfo(factionID)
        
        local levelTop, levelEarned, percent, roundedPercent, repLeftToLevel

        if C_Reputation.IsFactionParagon(factionID) then
            while (paraValue > paraThreshold) do
                paraValue = paraValue - paraThreshold
            end
            levelTop = paraThreshold
            levelEarned = paraValue
            repLeftToLevel = paraThreshold - paraValue
        elseif addon:isRenownRep(factionID) then
            data = C_MajorFactions.GetMajorFactionData(factionID)
            levelEarned = data['renownReputationEarned']
            nextStandingId = data['renownLevel']
            levelTop = data['renownLevelThreshold']
            repLeftToLevel = levelTop - levelEarned
            standingName = L["Renown"].." "..nextStandingId
        else 
            levelTop = topValue - bottomValue
            levelEarned = earnedValue - bottomValue
            repLeftToLevel = topValue - earnedValue
        end

        percent = (levelEarned / levelTop) * 100
        roundedPercent = percent + 0.5 - (percent + 0.5) % 1

        if name == lastFactionName then break end
        lastFactionName = name
        
        local showTip = false
        if isHeader and hasRep then
            showTip = true
        elseif not isHeader then
            showTip = true
        end
        if showTip and self.db.char.reputation[name] and self.db.char.reputation[name].gainedSession > 0 then
            local estimatedTimeTolevel = repLeftToLevel / (self.db.char.reputation[name].gainedSession / self.db.char.sessionTime)

            line = WRTip:AddLine()
            WRTip:SetCell(line, 1, name.."  ")
            WRTip:SetCell(line, 2, " "..standingName.." ")
            WRTip:SetCell(line, 3, " "..roundedPercent.."% ")
            WRTip:SetCell(line, 4, " "..addon:TimeTextMed(estimatedTimeTolevel).." ")
            WRTip:SetCell(line, 5, " "..self.db.char.reputation[name].gainedSession.." ")
            WRTip:SetCell(line, 6, " "..self.db.char.reputation[name].gainedDay.." ")
            WRTip:SetCell(line, 7, " "..self.db.char.reputation[name].gainedWeek.." ")
        end

        factionIndex = factionIndex + 1
    until factionIndex > GetNumFactions()
    WRTip:Show()
end

function addon:TimeTextShort(s)
    if math.huge == s then
        return L["Infinite"]
    end

    local days = floor(s/24/60/60); s = mod(s, 24*60*60)
    local hours = floor(s/60/60); s = mod(s, 60*60)
    local minutes = floor(s/60); s = mod(s, 60)
    local seconds = s

    local timeText = ""
    if days ~= 0 then
        timeText = timeText..format(" %d:%d:%d:%d ", days, hours, minutes, seconds)
    elseif hours ~= 0 then
        timeText = timeText..format(" %d:%d:%d ", hours, minutes, seconds)
    elseif minutes ~= 0 then
        timeText = timeText..format(" %d:%d", minutes, seconds)
    elseif seconds ~= 0 then
        timeText = timeText..format("%d ", seconds)
    end

    return timeText
end

function addon:TimeTextMed(s)

    if math.huge == s then
        return L["Infinite"]
    end

    local days = floor(s/24/60/60); s = mod(s, 24*60*60)
    local hours = floor(s/60/60); s = mod(s, 60*60)
    local minutes = floor(s/60); s = mod(s, 60)
    local seconds = s

    local timeText = ""
    if days ~= 0 then
        timeText = timeText..format(" %dd %dh %dm %ds ", days, hours, minutes, seconds)
    elseif hours ~= 0 then
        timeText = timeText..format(" %dh %dm %ds ", hours, minutes, seconds)
    elseif minutes ~= 0 then
        timeText = timeText..format(" %dm %ds ", minutes, seconds)
    elseif seconds ~= 0 then
        timeText = timeText..format("%ds ", seconds)
    end

    return timeText
end

-- Open options on click, for now
function addon:DataObjClick(button)
    InterfaceOptionsFrame_OpenToCategory(configFrame)
end

function addon:DataObjEnter(LDBFrame)
    if WRTip ~= nil then
        if libQTip:IsAcquired("WonderRepTip") then WRTip:Clear() end
        WRTip:Hide()
        libQTip:Release(WRTip)
        WRTip = nil
    end

    WRTip = libQTip:Acquire("WonderRepTip", 7, "LEFT", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER")
    WRTip:SmartAnchorTo(LDBFrame)
    addon:SetTooltipContents()
end

function addon:SessionTimer()
    self.db.char.sessionTime = self.db.char.sessionTime + 1
    if ((self.db.char.sessionTime % 5) == 0) then
        self:SetBrokerText()
    end
end

function addon:CheckStatsResets()
    local now = date('*t')


    local startOfDay, startOfMonth, startOfYear, startOfWeek
    local reset = {
        hour = 0,   
        min  = 0,   
        sec  = 0
    }

    -- Start of today
    reset.day   = now.day
    reset.month = now.month
    reset.year  = now.year
    startOfDay = time(reset)

    reset.day    = 1
    startOfMonth = time(reset)

    reset.month = 1
    startOfYear = time(reset)

    reset = date('*t',time()+GetQuestResetTime())

    local numDaysBack = (reset.wday - 3 - 1) % 7 + 1
    startOfWeek = time(reset) - numDaysBack*86400


    -- for key,char in pairs(db.sv.char) do
    if self.db.char.lastSaved ~= nill then
        local lastSaved = self.db.char.lastSaved or time()

        if lastSaved < startOfDay then
            for k in pairs(self.db.char.reputation) do
                self.db.char.reputation[k].gainedDay = 0
            end
        end
        if lastSaved < startOfWeek  then
            for k in pairs(self.db.char.reputation) do
                self.db.char.reputation[k].lastweek = self.db.char.reputation[k].gainedWeek
                self.db.char.reputation[k].gainedWeek = 0
            end
        end
        self.db.char.lastSaved = time()
    end


    now.day  = now.day + 1  
    now.hour = 0           
    now.min  = 0   
    now.sec  = 1    

    -- schedule the next update at next daily reset or next day, whichever is earlier
    local next_check = min(difftime(time(now), time()), GetQuestResetTime()+1)
    self:ScheduleTimer('CheckStatsResets', next_check)
end

function addon:SetBrokerText()
    local dotext
    self.dataobj.icon = azeriteItemIcon
    
    local name, standingID, barMin, barMax, barValue, factionID = GetWatchedFactionInfo()
    local RepIndex, standingId, topValue, earnedValue = addon:GetRepMatch(name)
    local paraValue, paraThreshold, paraQuestId, paraRewardPending = C_Reputation.GetFactionParagonInfo(factionID)
    local repLevelName = repLevels[standingID]
    if name == nil then
        dotext = L["No Watched Faction"]
    elseif C_Reputation.IsFactionParagon(factionID) then
        while (paraValue > paraThreshold) do
            paraValue = paraValue - paraThreshold
        end

        if self.db.global.display_name == true and standingID ~= nil then
            dotext = name..": "
        else
            dotext = ""
        end

        if self.db.global.display_level == true then
            dotext = dotext.."Paragon: "
        end

        if self.db.global.display_percent == true then
            local percent = (paraValue / paraThreshold) * 100
            local roundedPercent = percent + 0.5 - (percent + 0.5) % 1
            dotext = dotext..roundedPercent.."%: "
        end

        if self.db.global.display_time == true and self.db.char.reputation[name] ~= nil then
            local repLeftToLevel = paraThreshold - paraValue
            local estimatedTimeTolevel = repLeftToLevel / (self.db.char.reputation[name].gainedSession / self.db.char.sessionTime)
            dotext = dotext..addon:TimeTextMed(estimatedTimeTolevel)
        end
    elseif (standingID == 8) then
        dotext = name..": "..L["maxed, pick another faction."]
    else
        if addon:isRenownRep(factionID) then
            data = C_MajorFactions.GetMajorFactionData(factionID)
            barValue = data['renownReputationEarned']
            standingID = data['renownLevel']
            barMax = data['renownLevelThreshold']
            repLevelName = L["Renown"].." "..standingID
            barMin = 0
        end
        local trueMax = barMax - barMin
        local trueValue = barValue - barMin

        if self.db.global.display_name == true and standingID ~= nil then
            dotext = name..": "
        else
            dotext = ""
        end

        if self.db.global.display_level == true then
            dotext = dotext..repLevelName..": "
        end

        if self.db.global.display_percent == true then
            local percent = (trueValue / trueMax) * 100
            local roundedPercent = percent + 0.5 - (percent + 0.5) % 1
            dotext = dotext..roundedPercent.."%: "
        end

        if self.db.global.display_time == true and self.db.char.reputation[name] ~= nil then
            local repLeftToLevel = trueMax - trueValue
            local estimatedTimeTolevel = repLeftToLevel / (self.db.char.reputation[name].gainedSession / self.db.char.sessionTime)
            dotext = dotext..addon:TimeTextMed(estimatedTimeTolevel)
        end
    end
    self.dataobj.text = ' '..dotext..' '
end

function addon:ConfigFrame()
    local menuPad = 16
    local linePad = 30

    local cfgFrame = CreateFrame("Frame", "WonderRepConfig",InterfaceOptionsFramePanelContainer)
    configFrame = cfgFrame
    cfgFrame.name = "WonderRep"
    InterfaceOptions_AddCategory(cfgFrame)

    local title = cfgFrame:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
    title:SetPoint("TOPLEFT",menuPad,-menuPad)
    title:SetText("WonderRep v"..GetAddOnMetadata("WonderRep","Version"))

    -- Function to create check buttons
    function createCheckbutton(parent, x_loc, y_loc, varname, displayname)
        local checkbutton = CreateFrame("CheckButton", varname, parent, "ChatConfigCheckButtonTemplate");
        checkbutton:SetPoint("TOPLEFT", parent, "TOPLEFT", x_loc, y_loc);
        _G[varname..'Text']:SetText(displayname);
        checkbutton:SetHitRectInsets(0,0,0,0);
        return checkbutton;
    end

    local crbcb = createCheckbutton(cfgFrame, menuPad, -30-linePad, "wrcrb"," "..L["Enable change reputation watch bar on reputation change."]);
    crbcb:SetSize(30,30);
    crbcb:SetScript("PostClick", function()
        self.db.global.change_bar = wrcrb:GetChecked()
        if wrcrb:GetChecked() then
            --L_UIDropDownMenu_EnableDropDown(ORaidDropDownMenu)
        else
            --L_UIDropDownMenu_DisableDropDown(ORaidDropDownMenu)
        end
    end);
    if self.db.global.change_bar then crbcb:SetChecked(true) end

    local crbacb = createCheckbutton(cfgFrame, menuPad, -30-(linePad*2), "wrcrba"," "..L["Enable announcement of reputation bar changes."]);
    crbacb:SetSize(30,30);
    crbacb:SetScript("PostClick", function()
        self.db.global.change_bar_announce = wrcrba:GetChecked()
        if wrcrba:GetChecked() then
            --L_UIDropDownMenu_EnableDropDown(ORaidDropDownMenu)
        else
            --L_UIDropDownMenu_DisableDropDown(ORaidDropDownMenu)
        end
    end);
    if self.db.global.change_bar_announce then crbacb:SetChecked(true) end

    local atlcb = createCheckbutton(cfgFrame, menuPad, -30-(linePad*3), "wratl"," "..L["Enable announcement of time left to next level."]);
    atlcb:SetSize(30,30);
    atlcb:SetScript("PostClick", function()
        self.db.global.announce_time_left = wratl:GetChecked()
        if wratl:GetChecked() then
            --L_UIDropDownMenu_EnableDropDown(ORaidDropDownMenu)
        else
            --L_UIDropDownMenu_DisableDropDown(ORaidDropDownMenu)
        end
    end);
    if self.db.global.announce_time_left then atlcb:SetChecked(true) end

    local atacf = createCheckbutton(cfgFrame, menuPad, -30-(linePad*4), "wracf"," "..L["Change announce messages to 'WonderRep' chat window."]);
    atacf:SetSize(30,30);
    atacf:SetScript("PostClick", function()
        self.db.global.announce_chat_frame = wracf:GetChecked()
        if wracf:GetChecked() then
            --L_UIDropDownMenu_EnableDropDown(ORaidDropDownMenu)
        else
            --L_UIDropDownMenu_DisableDropDown(ORaidDropDownMenu)
        end
    end);
    if self.db.global.announce_chat_frame then atacf:SetChecked(true) end
end

-- Startup Events --
function addon:OnInitialize()
    self.dataobj = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
        type = "data source",
        text = " ",
        icon = azeriteItemIcon,
        OnClick = function(f,b) addon:DataObjClick(b) end,
        OnLeave = function() 
            libQTip:Release(WRTip)
            WRTip = nil 
        end,
        OnEnter = function(f) addon:DataObjEnter(f) end,
    })

    self.db = LibStub("AceDB-3.0"):New("WonderRep_DB", sv_defaults, true)

    SLASH_WONDERREP1 = "/wonderrep"
    SLASH_WONDERREP2 = "/wr"
    SlashCmdList["WONDERREP"] = function(msg)
        WonderRep(msg)
    end

    self.sessionTimer = self:ScheduleRepeatingTimer("SessionTimer", 1)
    
    if IsLoggedIn() then self:PLAYER_ENTERING_WORLD() else self:RegisterEvent("PLAYER_ENTERING_WORLD") end
end
