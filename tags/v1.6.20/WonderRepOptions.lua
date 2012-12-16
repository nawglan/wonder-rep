
-- Options
-- Interface to the Localization lib
Localization.SetAddonDefault("WonderRep", "enUS")
local function TEXT(key) return Localization.GetClientString("WonderRep", key) end

local WONDERREP_COLOR_DROPDOWN_LIST = {
  {name = TEXT("OPTIONRED"), color = TEXT("COLORRED")},
  {name = TEXT("OPTIONGREEN"), color = TEXT("COLORGREEN")},
  {name = TEXT("OPTIONEMERALD"), color = TEXT("COLOREMERALD")},
  {name = TEXT("OPTIONYELLOW"), color = TEXT("COLORYELLOW")},
  {name = TEXT("OPTIONORANGE"), color = TEXT("COLORORANGE")},
  {name = TEXT("OPTIONBLUE"), color = TEXT("COLORBLUE")},
  {name = TEXT("OPTIONPURPLE"), color = TEXT("COLORPURPLE")},
  {name = TEXT("OPTIONCYAN"), color = TEXT("COLORCYAN")}
}

function WonderRepOptions_AnnounceToggle()
  if Wr_save.AnnounceLeft then
    Wr_save.AnnounceLeft = false
  else
    Wr_save.AnnounceLeft = true
  end
  WonderRepOptions_Init()
end

function WonderRepOptions_AutoBarToggle()
  if Wr_save.ChangeBar then
    Wr_save.ChangeBar = false
  else
    Wr_save.ChangeBar = true
  end
  WonderRepOptions_Init()
end

function WonderRepOptions_BarChangeToggle()
  if Wr_save.RepChange then
    Wr_save.RepChange = false
  else
    Wr_save.RepChange = true
  end
  WonderRepOptions_Init()
end

function WonderRepOptions_ChatToggle()
  if Wr_save.frame then
    WRep.frame = _G["ChatFrame2"]
    Wr_save.frame = false
  else
    WRep.frame = _G["ChatFrame1"]
    Wr_save.frame = true
  end
  WonderRepOptions_Init()
end

function WonderRepOptions_TimeToggle()
  if Wr_save.ATimeLeft then
    Wr_save.ATimeLeft = false
  else
    Wr_save.ATimeLeft = true
  end
  WonderRepOptions_Init()
end

function WonderRepOptions_Toggle()
  if WonderRepOptionsFrame:IsVisible() then
    WonderRepOptionsFrame:Hide()
    Wr_Status()
  else
    WonderRepOptions_Init()
    WonderRepOptionsFrame:Show()
  end
end

function WonderRepOptions_ResetTime()
  WRep.SessionTime = 0
  WonderRepOptions_Init()
end

function WonderRepOptions_IntervalSlider()
  WRep.AmountGainedInterval = Wr_save.AmountGainedInterval
end

function WonderRepOptionsColorDropDown_OnLoad()
  UIDropDownMenu_Initialize(WonderRepOptionsColorDropDown, WonderRepOptionsColorDropDown_Initialize)
  UIDropDownMenu_SetSelectedID(WonderRepOptionsColorDropDown, Wr_save.Color.id)
end

function WonderRepOptionsColorDropDown_Initialize()
  local info
  local i
  for i = 1, getn(WONDERREP_COLOR_DROPDOWN_LIST) do
    info = {}
    info.text = WONDERREP_COLOR_DROPDOWN_LIST[i].name
    info.func = WonderRepOptionsColorDropDown_OnClick
    UIDropDownMenu_AddButton(info)
  end
end


function WonderRepOptionsColorDropDown_OnClick(self)
  UIDropDownMenu_SetSelectedID(WonderRepOptionsColorDropDown, Wr_save.Color.id)
  local id = self:GetID()
  if id == 1 then
    WRep.Color.R = 1
    WRep.Color.G = 0
    WRep.Color.B = 0
  elseif id == 2 then
    WRep.Color.R = 0
    WRep.Color.G = 1
    WRep.Color.B = 0
  elseif id == 3 then
    WRep.Color.R = .3
    WRep.Color.G = .8
    WRep.Color.B = .5
  elseif id == 4 then
    WRep.Color.R = 1
    WRep.Color.G = 1
    WRep.Color.B = 0
  elseif id == 5 then
    WRep.Color.R = 1
    WRep.Color.G = .61
    WRep.Color.B = 0
  elseif id == 6 then
    WRep.Color.R = 0
    WRep.Color.G = 0
    WRep.Color.B = 1
  elseif id == 7 then
    WRep.Color.R = .4
    WRep.Color.G = 0
    WRep.Color.B = .6
  elseif id == 8 then
    WRep.Color.R = 0
    WRep.Color.G = 1
    WRep.Color.B = 1
  end

  Wr_save.Color.id = id
  Wr_save.Color.R = WRep.Color.R
  Wr_save.Color.G = WRep.Color.G
  Wr_save.Color.B = WRep.Color.B
  WRep.frame:AddMessage("WonderRep: " .. TEXT("COLORCHANGED"), WRep.Color.R, WRep.Color.G, WRep.Color.B)
  WonderRepOptions_Init()
end

function WonderRepOptions_OnLoad()
  UIPanelWindows['WonderRepOptionsFrame'] = {area = 'center', pushable = 0}
end

function WonderRepOptions_Init()
  WonderRepOptions_SessionTimeNumber:SetText(WonderRep_TimeText(WRep.SessionTime))
  UIDropDownMenu_SetSelectedID(WonderRepOptionsColorDropDown, Wr_save.Color.id)
  WonderRepOptionsFrameAnnounce:SetChecked(Wr_save.AnnounceLeft)
  WonderRepOptionsFrameAutoBar:SetChecked(Wr_save.ChangeBar)
  WonderRepOptionsFrameBarChange:SetChecked(Wr_save.RepChange)
  WonderRepOptionsFrameChat:SetChecked(Wr_save.frame)
  WonderRepOptionsFrameCombatLog:SetChecked(not Wr_save.frame)
  WonderRepOptionsFrameTime:SetChecked(Wr_save.ATimeLeft)
  SliderInterval:SetValue(Wr_save.AmountGainedInterval)
end
