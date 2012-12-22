--[[
  - VERSION: 1.6.24

  - WonderRep: Adds all sorts of functionality for reputation changes!
]]

------------
-- Global Vars, and strings
------------

-- Interface to the Localization lib
Localization.SetAddonDefault("WonderRep", "enUS")
local function TEXT(key) return Localization.GetClientString("WonderRep", key) end

WRep = {
  defaultframe = "ChatFrame1",
  Units = {
    [1] = TEXT("HATED"),
    [2] = TEXT("HOSTILE"),
    [3] = TEXT("UNFRIENDLY"),
    [4] = TEXT("NEUTRAL"),
    [5] = TEXT("FRIENDLY"),
    [6] = TEXT("HONORED"),
    [7] = TEXT("REVERED"),
    [8] = TEXT("EXALTED"),
    [9] = TEXT("MAXEXALTED")
  },
  UnitsFriends = {
    [1] = TEXT("STRANGER"),      --     0 -  8400
    [2] = TEXT("ACQUAINTANCE"),  --  8400 - 16800
    [3] = TEXT("BUDDY"),         -- 16800 - 25200
    [4] = TEXT("FRIEND"),        -- 25200 - 33600
    [5] = TEXT("GOODFRIEND"),    -- 33600 - 42000
    [6] = TEXT("BESTFRIEND")     -- 42000 - 42999
  },
  Color = {
    R = 1,
    G = 1,
    B = 0
  },
  AmountGainedInterval = 10,
  AmountGained = 0,
  SessionTime = 0,
  TimeSave = 0
}

Wrl = {}

------------
-- Load Function
------------
function WonderRep_OnLoad(self)
  self.registry = {
    id = "WonderRep"
  }
  -- Register the game events neccesary for the addon
  self:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("VARIABLES_LOADED")
  self:RegisterEvent("WORLD_MAP_UPDATE")

  -- Register our slash command
  SLASH_WONDERREP1 = "/wonderrep"
  SLASH_WONDERREP2 = "/wr"
  SlashCmdList["WONDERREP"] = function(msg)
    WonderRep(msg)
  end

  -- Printing Message in Chat Frame
  if DEFAULT_CHAT_FRAME then
    ChatFrame1:AddMessage(TEXT("LOADEDSTR") .. " 1.6.24", 1, 1, 0)
  end

  -- Don't let this function run more than once
  WonderRep_OnLoad = nil
end

function WonderRep_UpdateFactions()
  local factionIndex = 1
  local lastFactionName = ""

  -- update known factions
  repeat
    local name = GetFactionInfo(factionIndex)
    if name == lastFactionName then break end
    lastFactionName = name
    if name then
      if not Wrl[name] then
        Wrl[name] = {
          gained = 0
        }
      end
    end
    factionIndex = factionIndex + 1
  until factionIndex > 200
end

function WonderRep_LoadSavedVars()
  if not Wr_version then
    Wr_version = 180
  end

  if not Wr_save then
    Wr_save = {
      AnnounceLeft = true,
      RepChange = true,
      ChangeBar = true,
      frame = true,
      ATimeLeft = true,
      Guild = true,
      Color = {
        id = 4,
        R = 1,
        G = 1,
        B = 0
      },
      AmountGainedInterval = 1
    }
    ChatFrame1:AddMessage(TEXT("NEWLOADSTR"), 1, 1, 0)
  end

  if Wr_version < 170 then
    Wr_save.ATimeLeft = true
    Wr_save.AmountGainedInterval = Wr_save.AmountGainedLevel
    Wr_save.Color = {
      id = Wr_save.colorid,
      R = Wr_save.colora,
      G = Wr_save.colorb,
      B = Wr_save.colorc
    }
    Wr_version = 170
  end
  if Wr_version < 180 then
    Wr_save.Guild = true
  end

  if Wr_save.frame then
    WRep.frame = _G["ChatFrame1"]
  else
    WRep.frame = _G["ChatFrame2"]
  end

  WRep.Color.R = Wr_save.Color.R
  WRep.Color.G = Wr_save.Color.G
  WRep.Color.B = Wr_save.Color.B
  WRep.AmountGainedInterval = Wr_save.AmountGainedInterval
  WRep.ChangeBar = Wr_save.ChangeBar

  Wr_Status()
end

------------
-- Event Functions
------------
function WonderRep_OnEvent(self, event, ...)
  local arg1 = ...

  if event == "VARIABLES_LOADED" then
    WonderRep_LoadSavedVars()
    return
  end

  -- Event fired when the player gets, or loses, rep in the chat frame
  if event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
    WonderRep_UpdateFactions()

    -- Reputation with <REPNAME> increased by <AMOUNT>.
    local HasIndexStart, HasIndexStop, FactionName, AmountGained = string.find(arg1, TEXT("REPMATCHSTR"))
    if HasIndexStart == nil then
      -- Try the REPMATCHSTR2
      HasIndexStart, HasIndexStop, FactionName, AmountGained = string.find(arg1, TEXT("REPMATCHSTR2"))
      if HasIndexStart == nil then
        return
      end
    end
    local factionIncreasedBy = 1
    factionIncreasedBy = AmountGained + 0 -- ensure that the string value is converted to an integer
    
    if FactionName == TEXT("GUILD") then
      if not Wr_save.Guild then
        return
      end
      FactionName = GetGuildInfo("player");
    end

    -- Using the string we just made, sending to Match function
    local RepIndex, standingId, topValue, earnedValue = WonderRep_GetRepMatch(FactionName)
    local watchedName = GetWatchedFactionInfo()

    if RepIndex ~= nil then
      -- Changes Rep bar to the rep we matched above
      if FactionName ~= watchedName then
        WRep.AmountGained = 0
        if Wr_save.ChangeBar == true then
          SetWatchedFactionIndex(RepIndex)
          if Wr_save.RepChange == true then
            WRep.frame:AddMessage("WonderRep: " .. TEXT("REPBARCHANGED") .. " " .. FactionName .. ".", WRep.Color.R, WRep.Color.G, WRep.Color.B)
          end
        end
      end

      Wrl[FactionName].gained = Wrl[FactionName].gained + factionIncreasedBy
      WRep.AmountGained = WRep.AmountGained + factionIncreasedBy

      -- Have we gained more rep than the reporting level?
      if WRep.AmountGained >= WRep.AmountGainedInterval then
        local nextStandingId = standingId + 1
        local RepLeftToLevel = 0

        -- Friend reputation doesn't have same amount of faction needed for each level
        -- and the standing id doesn't line up either
        if isFriendRep(FactionName) then
          local tmpVal = earnedValue / 8400
          local tmpValInt = floor(tmpVal)
          nextStandingId = tmpValInt + 2
          if nextStandingId > 6 then
            return
          end
          RepLeftToLevel = 8400 - (8400 * (tmpVal - tmpValInt))
        else
          if nextStandingId > 9 then
            return
          end
          RepLeftToLevel = topValue - earnedValue
        end

        local RepNextLevelName = WonderRep_GetNextRepLevelName(FactionName, nextStandingId)
        local RepGained = Wrl[FactionName].gained
        local KillsToNext = ceil(.5 + (RepLeftToLevel / factionIncreasedBy))

        if RepLeftToLevel < factionIncreasedBy then
          KillsToNext = 1
        end

        local EstimatedTimeTolevel = RepLeftToLevel / (RepGained / WRep.SessionTime)
        if Wr_save.AnnounceLeft == true and Wr_save.ATimeLeft == true then
          WRep.frame:AddMessage(string.format("WonderRep: " .. TEXT("REPSTRFULL"), RepLeftToLevel, FactionName, RepNextLevelName, KillsToNext, RepGained, WonderRep_TimeText(EstimatedTimeTolevel), RepNextLevelName) , WRep.Color.R, WRep.Color.G, WRep.Color.B)
        elseif Wr_save.AnnounceLeft == true then
          WRep.frame:AddMessage(string.format("WonderRep: " .. TEXT("REPSTRLEFT"), RepLeftToLevel, FactionName, RepNextLevelName, KillsToNext), WRep.Color.R, WRep.Color.G, WRep.Color.B)
        elseif Wr_save.ATimeLeft == true then
          WRep.frame:AddMessage(string.format("WonderRep: " .. TEXT("REPSTRTIME"), RepGained, FactionName, WonderRep_TimeText(EstimatedTimeTolevel), RepNextLevelName), WRep.Color.R, WRep.Color.G, WRep.Color.B)
        end
        WRep.AmountGained = 0
      end
    else
      WRep.frame:AddMessage(TEXT("NEWFACTION"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
    end
    return
  end

  -- Event fired when player finish loading the game (zone, login, reloadui)
  -- We use this event to check where the player is using GetCurrentMapContinent(),
  -- we can tell if the player if in a BG, if they are we find out which
  if event == "PLAYER_ENTERING_WORLD" then
    -- Variable to hold if player is Horde or Alliance
    local HordeOrAlliance = UnitFactionGroup("player")
    SetMapToCurrentZone()
    local x = GetCurrentMapContinent()
    local FactionName

    if x == -1 then
      local i = 0
      for i = 1, GetMaxBattlefieldID() do
        local status, mapName, instanceID = GetBattlefieldStatus(i)
        if instanceID ~= 0 then
          if mapName == TEXT("ARATHIBASIN") then
            if HordeOrAlliance == "Horde" then
              FactionName = TEXT("DEFILERS")
            else
              FactionName = TEXT("LEAGUEARATHOR")
            end
          elseif mapName == TEXT("WARSONGGULCH") then
            if HordeOrAlliance == "Horde" then
              FactionName = TEXT("OUTRIDERS")
            else
              FactionName = TEXT("SENTINELS")
            end
          elseif mapName == TEXT("ALTERACVALLEY") then
            if HordeOrAlliance == "Horde" then
              FactionName = TEXT("FROSTWOLF")
            else
              FactionName = TEXT("STORMPIKE")
            end
          else
            WRep.frame:AddMessage("We have a problem - 1")
          end
        end
      end

      local watched_name = GetWatchedFactionInfo()
      local RepIndex, standingId = WonderRep_GetRepMatch(FactionName)
      if standingId == 8 then
        return
      end
      if FactionName ~= watched_name then
        SetWatchedFactionIndex(RepIndex)
        WRep.frame:AddMessage("WonderRep: " .. TEXT("REPBARCHANGED") .." " .. FactionName .. ".", WRep.Color.R, WRep.Color.G, WRep.Color.B)
      end
    end
  end

  if event == "WORLD_MAP_UPDATE" then
    local x,y = GetPlayerMapPosition("player")
    if x and y == 0 then -- should this be x == 0 and y == 0?
      local InstanceName = GetRealZoneText()
      local FactionName = ""
      if InstanceName == TEXT("ZULGURUB") then
        FactionName = TEXT("ZANDALAR")
      elseif InstanceName == TEXT("STRATHOLME") or InstanceName == TEXT("NAXXRAMAS") then
        FactionName = TEXT("ARGENTDAWN")
      end
      if FactionName ~= "" then
        local RepIndex, standingId = WonderRep_GetRepMatch(FactionName)
        if standingId == 8 then
          return
        end
        local WatchedName = GetWatchedFactionInfo()
        if FactionName ~= WatchedName then
          SetWatchedFactionIndex(RepIndex)
          WRep.frame:AddMessage("WonderRep: " .. TEXT("REPBARCHANGED") .." " .. FactionName .. ".", WRep.Color.R, WRep.Color.G, WRep.Color.B)
        end
      end
    end
    return
  end
end

------------
-- Reputation pharsing and math function
------------
function WonderRep_GetRepMatch(FactionName)
  local factionIndex = 1
  local lastFactionName
  repeat
    local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
      canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(factionIndex)
    if name == lastFactionName then break end
    lastFactionName = name

    if name == FactionName then
      return factionIndex, standingId, topValue, earnedValue
    end

    factionIndex = factionIndex + 1
  until factionIndex > 200
end

function WonderRep_OnUpdate(self, elapsed)
  WRep.TimeSave = WRep.TimeSave + elapsed
  if WRep.TimeSave > 0.5 then
    WRep.SessionTime = WRep.SessionTime + WRep.TimeSave
    WRep.TimeSave = 0
  end
end

------------
-- Printing Functions
------------
function Wr_Status()
  WRep.frame:AddMessage("WonderRep " .. TEXT("STATUS"), WRep.Color.R, WRep.Color.G, WRep.Color.B)

  if Wr_save.RepChange == true then
    WRep.frame:AddMessage("WonderRep " .. TEXT("ANNOUNCE"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  else
    WRep.frame:AddMessage("WonderRep " .. TEXT("NOANNOUNCE"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  end
  if Wr_save.ChangeBar == true then
    WRep.frame:AddMessage("WonderRep " .. TEXT("CHANGEBAR"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  else
    WRep.frame:AddMessage("WonderRep " .. TEXT("NOCHANGEBAR"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  end
  if Wr_save.AnnounceLeft == true then
    WRep.frame:AddMessage("WonderRep " .. string.format(TEXT("REPLEFT"), WRep.AmountGainedInterval), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  else
    WRep.frame:AddMessage("WonderRep " .. TEXT("NOREPLEFT"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  end
  if Wr_save.ATimeLeft == true then
    WRep.frame:AddMessage("WonderRep " .. string.format(TEXT("TIMELEFT"), WRep.AmountGainedInterval), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  else
    WRep.frame:AddMessage("WonderRep " .. TEXT("NOTIMELEFT"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  end
  if Wr_save.Guild == true then
    WRep.frame:AddMessage("WonderRep " .. string.format(TEXT("PROCESSGUILD"), WRep.AmountGainedInterval), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  else
    WRep.frame:AddMessage("WonderRep " .. TEXT("NOPROCESSGUILD"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  end
  if Wr_save.frame == true then
    WRep.frame:AddMessage("WonderRep " .. TEXT("SHOWCHATFRAME"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  else
    WRep.frame:AddMessage("WonderRep " .. TEXT("SHOWCOMBATLOG"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  end
end

function WonderRep_PrintHelp()
  WRep.frame:AddMessage(" ")
  WRep.frame:AddMessage("-----------------------------------")
  WRep.frame:AddMessage(TEXT("HELPTITLE"))
  WRep.frame:AddMessage(TEXT("HELPSLASH"))
  WRep.frame:AddMessage(TEXT("COMMANDHELP") .. " -- " .. TEXT("HELPHELP"))
  WRep.frame:AddMessage(TEXT("COMMANDSTATUS") .. " -- " .. TEXT("HELPSTATUS"))
  WRep.frame:AddMessage(TEXT("COMMANDANNOUNCE") .. " -- " .. TEXT("HELPANNOUNCE"))
  WRep.frame:AddMessage(TEXT("COMMANDGUILD") .. " -- " .. TEXT("HELPGUILD"))
  WRep.frame:AddMessage(TEXT("COMMANDTIMELEFT") .. " -- " .. TEXT("HELPTIMELEFT"))
  WRep.frame:AddMessage(TEXT("COMMANDAUTOBAR") .. " -- " .. TEXT("HELPAUTOBAR"))
  WRep.frame:AddMessage(TEXT("COMMANDBARCHANGE") .. " -- " .. TEXT("HELPBARCHANGE"))
  WRep.frame:AddMessage(TEXT("COMMANDCHAT") .. " -- " .. TEXT("HELPCHAT"))
  WRep.frame:AddMessage(TEXT("COMMANDCOMBATLOG") .. " -- " .. TEXT("HELPCOMBATLOG"))
  WRep.frame:AddMessage(TEXT("COMMANDINTERVAL") .. " -- " .. TEXT("HELPINTERVAL"))
  WRep.frame:AddMessage(TEXT("COMMANDCOLOR") .. " -- " .. TEXT("HELPCOLOR"))
  WRep.frame:AddMessage("-----------------------------------")
  WRep.frame:AddMessage(" ")
end

function WonderRep_TimeText(s)
  local days = floor(s/24/60/60); s = mod(s, 24*60*60)
  local hours = floor(s/60/60); s = mod(s, 60*60)
  local minutes = floor(s/60); s = mod(s, 60)
  local seconds = s

  local timeText = ""
  if days ~= 0 then
    timeText = timeText..format("%d" .. TEXT("DAYS") .. " ", days)
  end
  if hours ~= 0 then
    timeText = timeText..format("%d" .. TEXT("HOURS") .. " ", hours)
  end
  if minutes ~= 0 then
    timeText = timeText..format("%d" .. TEXT("MINUTES") .. " ", minutes)
  end
  if seconds ~= 0 then
    timeText = timeText..format("%d" .. TEXT("SECONDS") .. " ", seconds)
  end

  return timeText
end

------------
-- Slash Function
------------
function WonderRep(msg)
  if msg then
    local command = string.lower(msg)
    if command == "" then
      WonderRepOptions_Toggle()
    elseif command == TEXT("COMMANDHELP") then
      WonderRep_PrintHelp()
    elseif command == TEXT("COMMANDCOMBATLOG") then
      WRep.frame = _G["ChatFrame2"]
      Wr_save.frame = false
      Wr_Status()
    elseif command == TEXT("COMMANDCHAT") then
      WRep.frame = _G["ChatFrame1"]
      Wr_save.frame = true
      Wr_Status()
    elseif command == TEXT("COMMANDSTATUS") then
      Wr_Status()
    elseif command == TEXT("COMMANDANNOUNCE") then
      if Wr_save.AnnounceLeft == true then
        Wr_save.AnnounceLeft = false
      else
        Wr_save.AnnounceLeft = true
      end
      Wr_Status()
    elseif command == TEXT("COMMANDGUILD") then
      if Wr_save.Guild == true then
        Wr_save.Guild = false
      else
        Wr_save.Guild = true
      end
      Wr_Status()
    elseif command == TEXT("COMMANDTIMELEFT") then
      if Wr_save.ATimeLeft == true then
        Wr_save.ATimeLeft = false
      else
        Wr_save.ATimeLeft = true
      end
      Wr_Status()
    elseif command == TEXT("COMMANDBARCHANGE") then
      if Wr_save.RepChange == true then
        Wr_save.RepChange = false
      else
        Wr_save.RepChange = true
      end
      Wr_Status()
    elseif command == TEXT("COMMANDAUTOBAR") then
      if Wr_save.ChangeBar == true then
        Wr_save.ChangeBar = false
      else
        Wr_save.ChangeBar = true
      end
      Wr_Status()
    elseif command == TEXT("COMMANDINTERVAL") .. " 1" then
      WRep.AmountGainedInterval = 1
      Wr_save.AmountGainedInterval = 1
      Wr_Status()
    elseif command == TEXT("COMMANDINTERVAL") .. " 50" then
      WRep.AmountGainedInterval = 50
      Wr_save.AmountGainedInterval = 50
      Wr_Status()
    elseif command == TEXT("COMMANDINTERVAL") .. " 100" then
      WRep.AmountGainedInterval = 100
      Wr_save.AmountGainedInterval = 100
      Wr_Status()
    elseif command == TEXT("COMMANDINTERVAL") .. " 150" then
      WRep.AmountGainedInterval = 150
      Wr_save.AmountGainedInterval = 150
      Wr_Status()
    elseif command == TEXT("COMMANDINTERVAL") .. " 200" then
      WRep.AmountGainedInterval = 200
      Wr_save.AmountGainedInterval = 200
      Wr_Status()
    elseif command == TEXT("COMMANDINTERVAL") .. " 250" then
      WRep.AmountGainedInterval = 250
      Wr_save.AmountGainedInterval = 250
      Wr_Status()
    elseif command == TEXT("COMMANDINTERVAL") .. " 300" then
      WRep.AmountGainedInterval = 300
      Wr_save.AmountGainedInterval = 300
      Wr_Status()
    elseif command == TEXT("COMMANDINTERVAL") .. " 350" then
      WRep.AmountGainedInterval = 350
      Wr_save.AmountGainedInterval = 350
      Wr_Status()
    elseif command == TEXT("COMMANDINTERVAL") .. " 400" then
      WRep.AmountGainedInterval = 400
      Wr_save.AmountGainedInterval = 400
      Wr_Status()
    elseif command == TEXT("COMMANDINTERVAL") .. " 450" then
      WRep.AmountGainedInterval = 450
      Wr_save.AmountGainedInterval = 450
      Wr_Status()
    elseif command == TEXT("COMMANDINTERVAL") .. " 500" then
      WRep.AmountGainedInterval = 500
      Wr_save.AmountGainedInterval = 500
      Wr_Status()
    elseif command == TEXT("COMMANDCOLOR") .. " " .. TEXT("COLORRED") then
      WRep.Color.R = 1
      WRep.Color.G = 0
      WRep.Color.B = 0
      Wr_save.Color.id = 1
      Wr_save.Color.R = 1
      Wr_save.Color.G = 0
      Wr_save.Color.B = 0
      WRep.frame:AddMessage("WonderRep: " .. TEXT("COLORCHANGED"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif command == TEXT("COMMANDCOLOR") .. " " .. TEXT("COLORBLUE") then
      WRep.Color.R = 0
      WRep.Color.G = 0
      WRep.Color.B = 1
      Wr_save.Color.id = 6
      Wr_save.Color.R = 0
      Wr_save.Color.G = 0
      Wr_save.Color.B = 1
      WRep.frame:AddMessage("WonderRep: " .. TEXT("COLORCHANGED"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif command == TEXT("COMMANDCOLOR") .. " " .. TEXT("COLORGREEN") then
      WRep.Color.R = 0
      WRep.Color.G = 1
      WRep.Color.B = 0
      Wr_save.Color.id = 2
      Wr_save.Color.R = 0
      Wr_save.Color.G = 1
      Wr_save.Color.B = 0
      WRep.frame:AddMessage("WonderRep: " .. TEXT("COLORCHANGED"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif command == TEXT("COMMANDCOLOR") .. " " .. TEXT("COLOREMERALD") then
      WRep.Color.R = .3
      WRep.Color.G = .8
      WRep.Color.B = .5
      Wr_save.Color.id = 3
      Wr_save.Color.R = .3
      Wr_save.Color.G = .8
      Wr_save.Color.B = .5
      WRep.frame:AddMessage("WonderRep: " .. TEXT("COLORCHANGED"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif command == TEXT("COMMANDCOLOR") .. " " .. TEXT("COLORYELLOW") then
      WRep.Color.R = 1
      WRep.Color.G = 1
      WRep.Color.B = 0
      Wr_save.Color.id = 4
      Wr_save.Color.R = 1
      Wr_save.Color.G = 1
      Wr_save.Color.B = 0
      WRep.frame:AddMessage("WonderRep: " .. TEXT("COLORCHANGED"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif command == TEXT("COMMANDCOLOR") .. " " .. TEXT("COLORORANGE") then
      WRep.Color.R = 1
      WRep.Color.G = .61
      WRep.Color.B = 0
      Wr_save.Color.id = 5
      Wr_save.Color.R = 1
      Wr_save.Color.G = .61
      Wr_save.Color.B = 0
      WRep.frame:AddMessage("WonderRep: " .. TEXT("COLORCHANGED"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif command == TEXT("COMMANDCOLOR") .. " " .. TEXT("COLORPURPLE") then
      WRep.Color.R = .4
      WRep.Color.G = 0
      WRep.Color.B = .6
      Wr_save.Color.id = 7
      Wr_save.Color.R = .4
      Wr_save.Color.G = 0
      Wr_save.Color.B = .6
      WRep.frame:AddMessage("WonderRep: " .. TEXT("COLORCHANGED"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif command == TEXT("COMMANDCOLOR") .. " " .. TEXT("COLORCYAN") then
      WRep.Color.R = 0
      WRep.Color.G = 1
      WRep.Color.B = 1
      Wr_save.Color.id = 8
      Wr_save.Color.R = 0
      Wr_save.Color.G = 1
      Wr_save.Color.B = 1
      WRep.frame:AddMessage("WonderRep: " .. TEXT("COLORCHANGED"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
    end
  end
end

function WonderRep_GetNextRepLevelName(FactionName, standingId)
  local RepNextLevelName = ""

  if isFriendRep(FactionName) and standingId <= 6 then
    RepNextLevelName = WRep.UnitsFriends[standingId]
  elseif (standingId <= 9) then
    RepNextLevelName = WRep.Units[standingId]
  end

  return RepNextLevelName
end

function isFriendRep(FactionName)
  local FriendRep = {}
  table.insert(FriendRep, TEXT("FUNG"))
  table.insert(FriendRep, TEXT("CHEE"))
  table.insert(FriendRep, TEXT("ELLA"))
  table.insert(FriendRep, TEXT("FISH"))
  table.insert(FriendRep, TEXT("GINA"))
  table.insert(FriendRep, TEXT("HAOHAN"))
  table.insert(FriendRep, TEXT("JOGU"))
  table.insert(FriendRep, TEXT("HILLPAW"))
  table.insert(FriendRep, TEXT("SHO"))
  table.insert(FriendRep, TEXT("TINA"))
  table.insert(FriendRep, TEXT("NAT"))

  return tContains(FriendRep, FactionName)
end
