--[[
  - VERSION: 1.6.17

  - WonderRep: Adds all sorts of functionality for reputation changes!
]]

------------
-- Global Vars, and strings
------------
WRep = {
  defaultframe = "ChatFrame1",
  Units = {
    [1] = "Hated",
    [2] = "Hostile",
    [3] = "Unfriendly",
    [4] = "Neutral",
    [5] = "Friendly",
    [6] = "Honored",
    [7] = "Revered",
    [8] = "Exalted",
    [9] = "Max Exalted"
  },
  UnitsFriends = {
    [1] = "Stranger",       --     0 -  8400
    [2] = "Acquaintance",   --  8400 - 16800
    [3] = "Buddy",          -- 16800 - 25200
    [4] = "Friend",         -- 25200 - 33600
    [5] = "Good Friend",    -- 33600 - 42000
    [6] = "Best Friend"     -- 42000 - 42999
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
  if (DEFAULT_CHAT_FRAME) then
    ChatFrame1:AddMessage("WonderRep Loaded! Version: 1.6.17", 1, 1, 0)
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
    if (name) then
      if (not Wrl[name]) then
        Wrl[name] = {
          gained = 0
        }
      end
    end
    factionIndex = factionIndex + 1
  until factionIndex > 200
end

function WonderRep_LoadSavedVars()
  if (not Wr_version) then
    Wr_version = 170
  end

  if (not Wr_save) then
    Wr_save = {
      AnnounceLeft = true,
      RepChange = true,
      ChangeBar = true,
      frame = true,
      ATimeLeft = true,
      Color = {
        id = 4,
        R = 1,
        G = 1,
        B = 0
      },
      AmountGainedInterval = 1
    }
    ChatFrame1:AddMessage("NEW LOAD, default values set!", 1, 1, 0)
  end

  if (Wr_version ~= 170) then
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

  if (Wr_save.frame) then
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

  if (event == "VARIABLES_LOADED") then
    WonderRep_LoadSavedVars()
  end

  -- Event fired when the player gets, or loses, rep in the chat frame
  if (event == "CHAT_MSG_COMBAT_FACTION_CHANGE") then
    WonderRep_UpdateFactions()

    -- This is set to hopefully stop an error when Reputation LEVEL changes
    local RepError, RepError2 = string.find(arg1, "Your")

    -- Don't process reputation level changes
    if (RepError ~= nil) then
      return
    end

    -- Check to see if the reputation is gained or lost, if lost quits
    for GainLoss in string.gmatch(arg1, "decreased") do
      return
    end

    -- This code first finds where 'has' is in the string then,
    -- Gets the Substring (rep name) between With ... Has
    local HasIndexStart, HasIndexStop = string.find(arg1, 'increased')
    local FactionName = string.sub(arg1, 17, HasIndexStart - 2)

    -- Using the string we just made, sending to Match function
    local RepIndex, standingId, topValue, earnedValue = WonderRep_GetRepMatch(FactionName)
    local watchedName = GetWatchedFactionInfo()

    if (RepIndex ~= nil) then
      -- Changes Rep bar to the rep we matched above
      if (FactionName ~= watchedName) then
        WRep.AmountGained = 0
        if (Wr_save.ChangeBar == true) then
          SetWatchedFactionIndex(RepIndex)
          if (Wr_save.RepChange == true) then
            WRep.frame:AddMessage("WonderRep: Reputation Bar changed to: " .. FactionName .. ".", WRep.Color.R, WRep.Color.G, WRep.Color.B)
          end
        end
      end

      -- grab the amount of increase in faction
      local factionIncreasedBy = 1
      local AmountGained = 0
      for AmountGained in string.gmatch(arg1, "%d+")  do
        factionIncreasedBy = AmountGained + 0
        break
      end

      Wrl[FactionName].gained = Wrl[FactionName].gained + factionIncreasedBy
      WRep.AmountGained = WRep.AmountGained + factionIncreasedBy

      -- Have we gained more rep than the reporting level?
      if (WRep.AmountGained >= WRep.AmountGainedInterval) then
        local nextStandingId = standingId + 1
        local RepNextLevelName = WonderRep_GetNextRepLevelName(FactionName, nextStandingId)
        local RepGained = Wrl[FactionName].gained
        local RepLeftToLevel = topValue - earnedValue
        local KillsToNext = floor(.5 + (RepLeftToLevel / factionIncreasedBy))

        if RepLeftToLevel < factionIncreasedBy then
          KillsToNext = 1
        end

        local EstimatedTimeTolevel = RepLeftToLevel / (RepGained / WRep.SessionTime)
        if (Wr_save.AnnounceLeft == true and Wr_save.ATimeLeft == true) then
          WRep.frame:AddMessage("WonderRep: " .. RepLeftToLevel .. " reputation with " .. FactionName .. " needed for " .. RepNextLevelName .. ". (" .. KillsToNext .. " reputation gains left) A total of " .. RepGained .. " reputation gained this session. " .. WonderRep_TimeText(EstimatedTimeTolevel) .. " estimated time to " .. RepNextLevelName .. ".", WRep.Color.R, WRep.Color.G, WRep.Color.B)
        elseif (Wr_save.AnnounceLeft == true) then
          WRep.frame:AddMessage("WonderRep: " .. RepLeftToLevel .. " reputation with " .. FactionName .. " needed for " .. RepNextLevelName .. ". (" .. KillsToNext .. " reputation gains left)", WRep.Color.R, WRep.Color.G, WRep.Color.B)
        elseif (Wr_save.ATimeLeft == true) then
          WRep.frame:AddMessage("WonderRep: " .. RepGained .. " reputation with " .. FactionName .. " gained this session. " .. WonderRep_TimeText(EstimatedTimeTolevel) .. " estimated time to " .. RepNextLevelName .. ".", WRep.Color.R, WRep.Color.G, WRep.Color.B)
        end
        WRep.AmountGained = 0
      end
    else
      WRep.frame:AddMessage("Brand new faction detected!", WRep.Color.R, WRep.Color.G, WRep.Color.B)
    end
  end

  -- Event fired when player finish loading the game (zone, login, reloadui)
  -- We use this event to check where the player is using GetCurrentMapContinent(),
  -- we can tell if the player if in a BG, if they are we find out which
  if (event == "PLAYER_ENTERING_WORLD") then
    -- Variable to hold if player is Horde or Alliance
    local HordeOrAlliance = UnitFactionGroup("player")
    SetMapToCurrentZone()
    local x = GetCurrentMapContinent()
    local FactionName

    if (x == -1) then
      local i = 0
      for i = 1, GetMaxBattlefieldID() do
        local status, mapName, instanceID = GetBattlefieldStatus(i)
        if (instanceID ~= 0) then
          if (mapName == "Arathi Basin") then
            if (HordeOrAlliance == "Horde") then
              FactionName = "The Defilers"
            else
              FactionName = "The League of Arathor"
            end
          elseif (mapName == "Warsong Gulch") then
            if (HordeOrAlliance == "Horde") then
              FactionName = "Warsong Outriders"
            else
              FactionName = "Silverwing Sentinels"
            end
          elseif (mapName == "Alterac Valley") then
            if (HordeOrAlliance == "Horde") then
              FactionName = "Frostwolf Clan"
            else
              FactionName = "Stormpike Guard"
            end
          else
            WRep.frame:AddMessage("We have a problem - 1")
          end
        end
      end

      local watched_name = GetWatchedFactionInfo()
      local RepIndex, standingId = WonderRep_GetRepMatch(FactionName)
      if (standingId == 8) then
        return
      end
      if (FactionName ~= watched_name) then
        SetWatchedFactionIndex(RepIndex)
        WRep.frame:AddMessage("WonderRep: Reputation Bar changed to: " .. FactionName .. ".", WRep.Color.R, WRep.Color.G, WRep.Color.B)
      end
    end
  end

  if (event == "WORLD_MAP_UPDATE") then
    local x,y = GetPlayerMapPosition("player")
    if (x and y == 0) then
      local InstanceName = GetRealZoneText()
      local FactionName = ""
      if (InstanceName == "Zul'Gurub") then
        FactionName = "Zandalar Tribe"
      end
      if (InstanceName == "Stratholme") then
        FactionName = "Argent Dawn"
      end
      if (InstanceName == "Naxxramas") then
        FactionName = "Argent Dawn"
      end
      if FactionName ~= "" then
        local RepIndex, standingId = WonderRep_GetRepMatch(FactionName)
        if (standingId == 8) then
          return
        end
        local WatchedName = GetWatchedFactionInfo()
        if (FactionName ~= WatchedName) then
          SetWatchedFactionIndex(RepIndex)
          WRep.frame:AddMessage("WonderRep: Reputation Bar changed to: " .. FactionName .. ".", WRep.Color.R, WRep.Color.G, WRep.Color.B)
        end
      end
    end
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

    if (name == FactionName) then
      return factionIndex, standingId, topValue, earnedValue
    end

    factionIndex = factionIndex + 1
  until factionIndex > 200
end

function WonderRep_OnUpdate(self, elapsed)
  WRep.TimeSave = WRep.TimeSave + elapsed
  if (WRep.TimeSave > 0.5) then
    WRep.SessionTime = WRep.SessionTime + WRep.TimeSave
    WRep.TimeSave = 0
  end
end

------------
-- Printing Functions
------------
function Wr_Status()
  WRep.frame:AddMessage("WonderRep Status:", WRep.Color.R, WRep.Color.G, WRep.Color.B)

  if (Wr_save.RepChange == true) then
    WRep.frame:AddMessage("WonderRep will announce when reputation bar is changed.", WRep.Color.R, WRep.Color.G, WRep.Color.B)
  else
    WRep.frame:AddMessage("WonderRep will not announce when reputation bar is changed.", WRep.Color.R, WRep.Color.G, WRep.Color.B)
  end
  if (Wr_save.ChangeBar == true) then
    WRep.frame:AddMessage("WonderRep will automatically change the reputation bar.", WRep.Color.R, WRep.Color.G, WRep.Color.B)
  else
    WRep.frame:AddMessage("WonderRep will not automatically change the reputation bar.", WRep.Color.R, WRep.Color.G, WRep.Color.B)
  end
  if (Wr_save.AnnounceLeft == true) then
    WRep.frame:AddMessage("WonderRep will announce reputation left to next level every "..WRep.AmountGainedInterval.." reputation", WRep.Color.R, WRep.Color.G, WRep.Color.B)
  else
    WRep.frame:AddMessage("WonderRep will not announce reputation left to next level", WRep.Color.R, WRep.Color.G, WRep.Color.B)
  end
  if (Wr_save.ATimeLeft == true) then
    WRep.frame:AddMessage("WonderRep will announce estimated time left to next level every "..WRep.AmountGainedInterval.." reputation", WRep.Color.R, WRep.Color.G, WRep.Color.B)
  else
    WRep.frame:AddMessage("WonderRep will not announce estimated time left to next level", WRep.Color.R, WRep.Color.G, WRep.Color.B)
  end
  if (Wr_save.frame == true) then
    WRep.frame:AddMessage("WonderRep will show all messages in the Chat Frame", WRep.Color.R, WRep.Color.G, WRep.Color.B)
  else
    WRep.frame:AddMessage("WonderRep will show all messages in the Combat Log", WRep.Color.R, WRep.Color.G, WRep.Color.B)
  end
end

function WonderRep_PrintHelp()
  WRep.frame:AddMessage(" ")
  WRep.frame:AddMessage("-----------------------------------")
  WRep.frame:AddMessage("WonderRep commands help:")
  WRep.frame:AddMessage("Use /wonderrep <command> or /wr <command> to perform the following commands")
  WRep.frame:AddMessage("help -- you are viewing it!")
  WRep.frame:AddMessage("status -- shows your current settings")
  WRep.frame:AddMessage("announce -- toggles whether to display reputation to next level message")
  WRep.frame:AddMessage("autobar -- toggles whether to automatically change the reputation bar or not")
  WRep.frame:AddMessage("barchange -- toggles whether to display a message when the reputation bar is changed")
  WRep.frame:AddMessage("chat -- Changes where WonderRep messages are displayed to the Chat Frame")
  WRep.frame:AddMessage("combatlog -- Changes where WonderRep messages are displayed to the Combat Log")
  WRep.frame:AddMessage("interval <##> -- Changes how often WonderRep will announce how much reputation untill the next level. If announce is turned off there is no affect. Available intervals: 1, 10, 50, 100, 200, 500. (EX: /wr interval 50)")
  WRep.frame:AddMessage("color <color> -- change the color used by WonderRep messages. Colors available: red, green, emerald, yellow, orange, blue, purple, cyan. (EX: /wr color red)")
  WRep.frame:AddMessage("-----------------------------------")
  WRep.frame:AddMessage(" ")
end

function WonderRep_TimeText(s)
  local days = floor(s/24/60/60); s = mod(s, 24*60*60)
  local hours = floor(s/60/60); s = mod(s, 60*60)
  local minutes = floor(s/60); s = mod(s, 60)
  local seconds = s

  local timeText = ""
  if (days ~= 0) then
    timeText = timeText..format("%dd ", days)
  end
  if (hours ~= 0) then
    timeText = timeText..format("%dh ", hours)
  end
  if (minutes ~= 0) then
    timeText = timeText..format("%dm ", minutes)
  end
  if (seconds ~= 0) then
    timeText = timeText..format("%ds", seconds)
  end

  return timeText
end

------------
-- Slash Function
------------
function WonderRep(msg)
  if (msg) then
    local command = string.lower(msg)
    if (command == "") then
      WonderRepOptions_Toggle()
    elseif (command == "help") then
      WonderRep_PrintHelp()
    elseif (command == "combatlog") then
      WRep.frame = _G[ChatFrame2]
      Wr_save.frame = false
      Wr_Status()
    elseif (command == "chat") then
      WRep.frame = _G[ChatFrame1]
      Wr_save.frame = true
      Wr_Status()
    elseif (command == "status") then
      Wr_Status()
    elseif (command == "announce") then
      if (Wr_save.AnnounceLeft == true) then
        Wr_save.AnnounceLeft = false
      else
        Wr_save.AnnounceLeft = true
      end
      Wr_Status()
    elseif (command == "barchange") then
      if (Wr_save.RepChange == true) then
        Wr_save.RepChange = false
      else
        Wr_save.RepChange = true
      end
      Wr_Status()
    elseif (command == "autobar") then
      if (Wr_save.ChangeBar == true) then
        Wr_save.ChangeBar = false
      else
        Wr_save.ChangeBar = true
      end
      Wr_Status()
    elseif (command == "interval 1") then
      WRep.AmountGainedInterval = 1
      Wr_save.AmountGainedInterval = 1
      Wr_Status()
    elseif (command == "interval 10") then
      WRep.AmountGainedInterval = 10
      Wr_save.AmountGainedInterval = 10
      Wr_Status()
    elseif (command == "interval 50") then
      WRep.AmountGainedInterval = 50
      Wr_save.AmountGainedInterval = 50
      Wr_Status()
    elseif (command == "interval 100") then
      WRep.AmountGainedInterval = 100
      Wr_save.AmountGainedInterval = 100
      Wr_Status()
    elseif (command == "interval 200") then
      WRep.AmountGainedInterval = 200
      Wr_save.AmountGainedInterval = 200
      Wr_Status()
    elseif (command == "interval 500") then
      WRep.AmountGainedInterval = 500
      Wr_save.AmountGainedInterval = 500
      Wr_Status()
    elseif (command == "color red") then
      WRep.Color.R = 1
      WRep.Color.G = 0
      WRep.Color.B = 0
      Wr_save.Color.id = 1
      Wr_save.Color.R = 1
      Wr_save.Color.G = 0
      Wr_save.Color.B = 0
      WRep.frame:AddMessage("WonderRep: Color Changed", WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif (command == "color blue") then
      WRep.Color.R = 0
      WRep.Color.G = 0
      WRep.Color.B = 1
      Wr_save.Color.id = 6
      Wr_save.Color.R = 0
      Wr_save.Color.G = 0
      Wr_save.Color.B = 1
      WRep.frame:AddMessage("WonderRep: Color Changed", WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif (command == "color green") then
      WRep.Color.R = 0
      WRep.Color.G = 1
      WRep.Color.B = 0
      Wr_save.Color.id = 2
      Wr_save.Color.R = 0
      Wr_save.Color.G = 1
      Wr_save.Color.B = 0
      WRep.frame:AddMessage("WonderRep: Color Changed", WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif (command == "color emerald") then
      WRep.Color.R = .3
      WRep.Color.G = .8
      WRep.Color.B = .5
      Wr_save.Color.id = 3
      Wr_save.Color.R = .3
      Wr_save.Color.G = .8
      Wr_save.Color.B = .5
      WRep.frame:AddMessage("WonderRep: Color Changed", WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif (command == "color yellow") then
      WRep.Color.R = 1
      WRep.Color.G = 1
      WRep.Color.B = 0
      Wr_save.Color.id = 4
      Wr_save.Color.R = 1
      Wr_save.Color.G = 1
      Wr_save.Color.B = 0
      WRep.frame:AddMessage("WonderRep: Color Changed", WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif (command == "color orange") then
      WRep.Color.R = 1
      WRep.Color.G = .61
      WRep.Color.B = 0
      Wr_save.Color.id = 5
      Wr_save.Color.R = 1
      Wr_save.Color.G = .61
      Wr_save.Color.B = 0
      WRep.frame:AddMessage("WonderRep: Color Changed", WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif (command == "color purple") then
      WRep.Color.R = .4
      WRep.Color.G = 0
      WRep.Color.B = .6
      Wr_save.Color.id = 7
      Wr_save.Color.R = .4
      Wr_save.Color.G = 0
      Wr_save.Color.B = .6
      WRep.frame:AddMessage("WonderRep: Color Changed", WRep.Color.R, WRep.Color.G, WRep.Color.B)
    elseif (command == "color cyan") then
      WRep.Color.R = 0
      WRep.Color.G = 1
      WRep.Color.B = 1
      Wr_save.Color.id = 8
      Wr_save.Color.R = 0
      Wr_save.Color.G = 1
      Wr_save.Color.B = 1
      WRep.frame:AddMessage("WonderRep: Color Changed", WRep.Color.R, WRep.Color.G, WRep.Color.B)
    end
  end
end

function WonderRep_GetNextRepLevelName(FactionName, standingId)
  local FriendRep = {}
  table.insert(FriendRep, "Farmer Fung")
  table.insert(FriendRep, "Chee Chee")
  table.insert(FriendRep, "Ella")
  table.insert(FriendRep, "Fish Fellreed")
  table.insert(FriendRep, "Gina Mudclaw")
  table.insert(FriendRep, "Haohan Mudclaw")
  table.insert(FriendRep, "Jogu the Drunk")
  table.insert(FriendRep, "Old Hillpaw")
  table.insert(FriendRep, "Sho")
  table.insert(FriendRep, "Tina Mudclaw")
  table.insert(FriendRep, "Nat Pagle")
  local RepNextLevelName = ""

  if tContains(FriendRep, FactionName) and standingId <= 9 then
    standingId = standingId - 3
    RepNextLevelName = WRep.UnitsFriends[standingId]
  elseif (standingId <= 9) then
    RepNextLevelName = WRep.Units[standingId]
  end

  return RepNextLevelName
end
