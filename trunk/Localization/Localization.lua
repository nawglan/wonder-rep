--[[
	Localization
	 	Embeddable addon for selecting a global localization for addons.
	
	By: AnduinLothar
	
	Based on inspiration from Babylonian code by norganna and MentalPower.
	Brought to you without any real xml thanks to Iriel's VirtualFrames.
	
	To use as an embeddable addon:
	- Put the Localization folder inside your Interface/AddOns/<YourAddonName>/ folder.
	- Add Localization\Localization.xml to your toc or load it in your xml before your localization files.
	- Add Localization to the OptionalDeps in your toc
	
	To use as an addon library:
	- Put the Localization folder inside your Interface/AddOns/ folder.
	- Add Localization to the Dependencies in your toc
	
	Note: The AddonName passed to most functions must be identical to the AddonName as returned by arg1 of ADDON_LOADED for Load on Demand addons.
	
	$Id: Localization.lua 3547 2006-05-16 02:35:13Z karlkfi $
	$Rev: 3547 $
	$LastChangedBy: karlkfi $
	$Date: 2006-05-15 19:35:13 -0700 (Mon, 15 May 2006) $
]]--

local LOCALIZATION_NAME 		= "Localization"
local LOCALIZATION_VERSION 		= 0.06
local LOCALIZATION_LAST_UPDATED	= "May 4, 2006"
local LOCALIZATION_AUTHOR 		= "AnduinLothar"
local LOCALIZATION_EMAIL		= "karlkfi@cosmosui.org"
local LOCALIZATION_WEBSITE		= "http://www.wowwiki.com/Localization_Lib"

------------------------------------------------------------------------------
--[[ Embedded Sub-Library Load Algorithm ]]--
------------------------------------------------------------------------------

if (not Localization) then
	Localization = {}
	RegisterCVar("PreferedLocale", "")
	RegisterCVar("RemoveUnusedLocales", 'false')
end
local isBetterInstanceLoaded = ( Localization.version and Localization.version >= LOCALIZATION_VERSION )

if (not isBetterInstanceLoaded) then
	
	------------------------------------------------------------------------------
	--[[ Variables ]]--
	------------------------------------------------------------------------------
	
	Localization.version = LOCALIZATION_VERSION
	Localization.clientLocale = GetLocale()
	if (not Localization.preferedLocale) then
		local pref = GetCVar("PreferedLocale")
		if (pref and pref ~= "") then
			Localization.preferedLocale = pref
		else
			Localization.preferedLocale = Localization.clientLocale
			--Localization.promptForPrefrence = true
		end
	end
	if (not Localization.callbacks) then
		Localization.callbacks = {}
	end
	if (not Localization.localizedStrings) then
		Localization.localizedStrings = {}
	end
	if (not Localization.localizedGlobalStrings) then
		Localization.localizedGlobalStrings = {}
	end
	if (not Localization.protected) then
		Localization.protected = {}
	end
	
	------------------------------------------------------------------------------
	--[[ User Addon Functions ]]--
	------------------------------------------------------------------------------
	
	function Localization.RegisterAddonStrings(locale, addon, stringTable, eraseOrig, protect)
		-- Registers strings with the global database by addon and locale
		-- 'eraseOrig' will remove all previously registered strings for this addon in this locale
		-- 'protect' will not allow this information to be deleted by RemoveUnusedLocales. For internal use only. Used to protect the language selection screen text.
		-- This method is highly prefered over RegisterGlobalAddonStrings so as not to pollute the global namespace.
		if (not locale) then
			DEFAULT_CHAT_FRAME:AddMessage("[Localization] WARNING: locale for RegisterAddonStrings invalid.")
			return
		end
		if (not addon) then
			DEFAULT_CHAT_FRAME:AddMessage("[Localization] WARNING: addon for RegisterAddonStrings invalid.")
		end
		if (not Localization.localizedStrings[locale]) then
			Localization.localizedStrings[locale] = {}
		end
		local lang = Localization.localizedStrings[locale]
		if (eraseOrig or not lang[addon]) then
			lang[addon] = stringTable
		else
			lang = lang[addon]
			for key, text in pairs(stringTable) do
				lang[key] = text
			end
		end
		
		--protection
		if (not Localization.protected[locale]) then
			Localization.protected[locale] = {}
		end
		if (protect and not Localization.protected[locale][addon]) then
			Localization.protected[locale][addon] = true;
		end
	end
	
	function Localization.RegisterGlobalAddonStrings(locale, addon, stringTable, eraseOrig, protect)
		-- Registers strings with the global database by addon and locale
		-- 'eraseOrig' will remove all previously registered strings for this addon in this locale
		-- 'protect' will not allow this information to be deleted by RemoveUnusedLocales. For internal use only. Used to protect the language selection screen text.
		-- This method may be useful if the strings are called frequently or are used in bindings.
		if (not locale) then
			DEFAULT_CHAT_FRAME:AddMessage("[Localization] WARNING: locale for RegisterGlobalAddonStrings invalid.")
			return
		end
		if (not addon) then
			DEFAULT_CHAT_FRAME:AddMessage("[Localization] WARNING: addon for RegisterGlobalAddonStrings invalid.")
		end
		if (not Localization.localizedGlobalStrings[locale]) then
			Localization.localizedGlobalStrings[locale] = {}
		end
		local lang = Localization.localizedGlobalStrings[locale]
		if (eraseOrig or not lang[addon]) then
			lang[addon] = stringTable
		else
			lang = lang[addon]
			for key, text in stringTable do
				lang[key] = text
			end
		end
		
		--protection
		if (not Localization.protected[locale]) then
			Localization.protected[locale] = {}
		end
		if (protect and not Localization.protected[locale][addon]) then
			Localization.protected[locale][addon] = true;
		end
	end
	
	function Localization.SetAddonDefault(addon, locale)
		-- Sets required Addon default locale.  It should have values for all availible strings.
		if (not Localization.defaults) then
			Localization.defaults = {}
		end
		Localization.defaults[addon] = locale
	end
	
	function Localization.RegisterCallback(key, callback, silent)
		-- Registers optional callback function to update your addon's strings when the prefered locale is changed
		if (not silent) then
			if (not key) then
				DEFAULT_CHAT_FRAME:AddMessage("[Localization] WARNING: key for RegisterCallback invalid.")
				return
			end
			if (not callback) then
				DEFAULT_CHAT_FRAME:AddMessage("[Localization] WARNING: callback for RegisterCallback invalid.")
			end
			if (Localization.callbacks[key]) then
				DEFAULT_CHAT_FRAME:AddMessage("[Localization] WARNING: callback allready exists for key: " .. key)
			end
		end
		Localization.callbacks[key] = callback
	end

	function Localization.GetString(addon, stringKey)
		-- returns the globally prefered localization, else client locale, else addon default
		-- It is recommended you make an addon file local refrence to shorten this call in your code:
		-- local function TEXT(key) return Localization.GetString("YourAddonName", key) end
		local lang;
		if (Localization.preferedLocale) then
			lang = Localization.localizedStrings[Localization.preferedLocale]
			if (lang[addon] and lang[addon][stringKey]) then
				return lang[addon][stringKey]
			elseif (Localization.preferedLocale == "enGB") then
				-- enGB falls back on enUS
				lang = Localization.localizedStrings["enUS"]
				if (lang and lang[addon] and lang[addon][stringKey]) then
					return lang[addon][stringKey]
				end
			end
		end
		lang = Localization.localizedStrings[Localization.clientLocale]
		if (lang[addon] and lang[addon][stringKey]) then
			return lang[addon][stringKey]
		elseif (Localization.clientLocale == "enGB") then
			-- enGB falls back on enUS
			lang = Localization.localizedStrings["enUS"]
			if (lang and lang[addon] and lang[addon][stringKey]) then
				return lang[addon][stringKey]
			end
		end
		
		return Localization.localizedStrings[Localization.defaults[addon]][addon][stringKey]
	end
	
	function Localization.GetClientString(addon, stringKey)
		-- returns the client localization, else addon default
		local lang = Localization.localizedStrings[Localization.clientLocale]
		if (lang[addon] and lang[addon][stringKey]) then
			return lang[addon][stringKey]
		elseif (Localization.clientLocale == "enGB") then
			-- enGB falls back on enUS
			lang = Localization.localizedStrings["enUS"]
			if (lang and lang[addon] and lang[addon][stringKey]) then
				return lang[addon][stringKey]
			end
		end
		
		return Localization.localizedStrings[Localization.defaults[addon]][addon][stringKey]
	end
	
	function Localization.GetSpecificString(language, addon, stringKey)
		if (Localization.localizedStrings[language] and Localization.localizedStrings[language][addon]) then
			return Localization.localizedStrings[language][addon][stringKey]
		end
	end
	
	function Localization.AssignAddonGlobalStrings(addon)
		-- Assigns global values to the keys of the global String database
		-- First choice is prefered localization, else client locale, else addon default
		-- This function must be called in your addon after SetAddonDefault and before the global strings can be used.
		local prefLang = Localization.preferedLocale and Localization.localizedGlobalStrings[Localization.preferedLocale] and Localization.localizedGlobalStrings[Localization.preferedLocale][addon]
		local clientLang = Localization.clientLocale and Localization.localizedGlobalStrings[Localization.clientLocale] and Localization.localizedGlobalStrings[Localization.clientLocale][addon]
		local preferedIsGB = (Localization.preferedLocale == "enGB")
		local enUSLang = Localization.localizedGlobalStrings["enUS"] and Localization.localizedGlobalStrings["enUS"][addon]
		local defaultLang = Localization.localizedGlobalStrings[Localization.defaults[addon]][addon]
		
		for key, text in defaultLang do
			if (prefLang and prefLang[key]) then
				setglobal(key, prefLang[key])
			elseif (preferedIsGB and enUSLang and enUSLang[key]) then
				setglobal(key, enUSLang[key])
			elseif (clientLang and clientLang[key]) then
				setglobal(key, clientLang[key])
			else
				setglobal(key, text)
			end
		end

	end
	
	------------------------------------------------------------------------------
	--[[ Internal Functions ]]--
	------------------------------------------------------------------------------
	
	local function TEXT(key) return Localization.GetString("Localization", key) end
	
	function Localization.SetGlobalPreference(localization)
		if (type(localization) ~= "string") then
			return
		end
		-- Global preference will be used for GetString
		Localization.preferedLocale = localization
		SetCVar("PreferedLocale", localization)
		for key, func in Localization.callbacks do
			func(localization)
		end
	end
	
	function Localization.GetGlobalPreference()
		return GetCVar("PreferedLocale")
	end
	
	function Localization.RemoveUnusedLocales()
		-- Keeps current prefered and client Localizations as well as addon defaults, removes all else from memory
		-- reloadui to get back deleted localized strings
		for locale, addonTable in Localization.localizedStrings do
			if (locale ~= Localization.clientLocale and locale ~= Localization.preferedLocale) then
				local used;
				for addon, default in Localization.defaults do
					if (locale == default or Localization.protected[locale][addon]) then
						used = true
					else
						Localization.localizedStrings[locale][addon] = nil 
					end
				end
				if (not used) then
					Localization.localizedStrings[locale] = nil
				end
			end
		end
	end
	
	function Localization.AssignAllGlobalStrings()
		-- Assigns global values to the keys of the global String database
		-- First choice is prefered localization, else client locale, else addon default
		-- This function is called when the Global preference is updated
		local prefLang = Localization.preferedLocale and Localization.localizedGlobalStrings[Localization.preferedLocale]
		local clientLang = Localization.clientLocale and Localization.localizedGlobalStrings[Localization.clientLocale]
		local preferedIsGB = (Localization.preferedLocale == "enGB")
		local enUSLang = Localization.localizedGlobalStrings["enUS"]
		
		for addon, locale in Localization.defaults do
			local lang = Localization.localizedGlobalStrings[locale]
			if (lang and lang[addon]) then
				-- If there aren't any default global strings for this local or addon, don't bother trying to assign any from other locales
				for key, text in lang[addon] do
					if (prefLang and prefLang[addon] and prefLang[addon][key]) then
						setglobal(key, prefLang[addon][key])
					elseif (preferedIsGB and enUSLang and enUSLang[addon] and enUSLang[addon][key]) then
						setglobal(key, enUSLang[addon][key])
					elseif (clientLang and clientLang[addon] and clientLang[addon][key]) then
						setglobal(key, clientLang[addon][key])
					else
						setglobal(key, text)
					end
				end
			end
		end

	end
	
	------------------------------------------------------------------------------
	--[[ Slash Command ]]--
	------------------------------------------------------------------------------
	
	SLASH_LOCALIZATION1 = "/locale"
	SlashCmdList["LOCALIZATION"] = Localization.Prompt	
	
	------------------------------------------------------------------------------
	--[[ Direct Execution ]]--
	------------------------------------------------------------------------------
	
	Localization.SetAddonDefault("Localization", "enUS")
	Localization.RegisterCallback("AssignAllGlobalStrings", Localization.AssignAllGlobalStrings)
	
	-- Leave frame text updating until after the localization files have been loaded
	
end
