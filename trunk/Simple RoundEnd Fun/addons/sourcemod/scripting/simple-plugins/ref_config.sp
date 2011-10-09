/************************************************************************
*************************************************************************
[TF2] RoundEnd Fun
Description:
	Provides some fun at the end of the round
*************************************************************************
*************************************************************************
This file is part of Simple Plugins project.

This plugin is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or any later version.

This plugin is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this plugin.  If not, see <http://www.gnu.org/licenses/>.
*************************************************************************
*************************************************************************
File Information
$Id: simple-roundimmunity.sp 55 2009-10-10 08:39:11Z antithasys $
$Author: antithasys $
$Revision: 55 $
$Date: 2009-10-10 03:39:11 -0500 (Sat, 10 Oct 2009) $
$LastChangedBy: antithasys $
$LastChangedDate: 2009-10-10 03:39:11 -0500 (Sat, 10 Oct 2009) $
$URL: https://sm-simple-plugins.googlecode.com/svn/trunk/Simple%20Round%20Immunity/addons/sourcemod/scripting/simple-roundimmunity.sp $
$Copyright: (c) Simple Plugins 2008-2009$
*************************************************************************
*************************************************************************
*/

/**
Create our parser globals
*/
enum e_ConfigState
{
	Reading_Integers,
	Reading_Strings
};

enum e_ConfigSection
{
	Section_Global,
	Section_Map,
	Section_Models
};

new Handle:g_hSettings = INVALID_HANDLE;
new Handle:g_hSettingsList = INVALID_HANDLE;

new e_ConfigState:g_eConfigState;
new e_ConfigSection:g_eConfigSection;

new bool:g_bSkipSection = false;

/**
Parse the config file
*/
stock ProcessConfigFile()
{
	new String:sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/simple-roundendfun.cfg");
	if (!FileExists(sConfigFile)) 
	{
		/**
		Config file doesn't exists, stop the plugin
		*/
		LogError("[SREF] Simple RoundEnd Fun is not running! Could not find file %s", sConfigFile);
		SetFailState("Could not find file %s", sConfigFile);
	}
	else
	{
		
		/**
		Clear the trie
		*/
		if (g_hSettings == INVALID_HANDLE)
		{
			g_hSettings = CreateTrie();
			g_hSettingsList = CreateArray(64);
			g_hModelNames = CreateArray(64);
			g_hModelPaths = CreateArray(64);
		}
		ClearTrie(g_hSettings);
		ClearArray(g_hSettingsList);
		ClearArray(g_hModelNames);
		ClearArray(g_hModelPaths);
		
		new Handle:hParser = SMC_CreateParser();
		SMC_SetReaders(hParser, Config_NewSection, Config_KeyValue, Config_EndSection);
		SMC_SetParseEnd(hParser, Config_End);

		new line, col;
		new String:error[128];
		new SMCError:result = SMC_ParseFile(hParser, sConfigFile, line, col);
		CloseHandle(hParser);
		
		if (result != SMCError_Okay) 
		{
			SMC_GetErrorString(result, error, sizeof(error));
			LogError("[SREF] %s on line %d, col %d of %s", error, line, col, sConfigFile);
			LogError("[SREF] Simple RoundEnd Fun is not running! Failed to parse %s", sConfigFile);
			SetFailState("Could not parse file %s", sConfigFile);
		}
	}
}

public SMCResult:Config_NewSection(Handle:parser, const String:section[], bool:quotes) 
{
	if (StrEqual(section, "map_settings"))
	{
		g_eConfigSection = Section_Map;
	}
	else if (StrEqual(section, "prophunt_models"))
	{
		g_eConfigSection = Section_Models;
	}
	else
	{
		g_eConfigSection = Section_Global;
	}
	
	if (g_eConfigSection == Section_Map)
	{
		if (IsMapSection(section))
		{
			g_bSkipSection = false;
		}
		else
		{
			g_bSkipSection = true;
		}
	}
	else
	{
		g_bSkipSection = false;
	}
	
	return SMCParse_Continue;
}

public SMCResult:Config_KeyValue(Handle:parser, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
	if (g_bSkipSection)
	{
		return SMCParse_Continue;
	}
	
	if (StrContains(key, "flag") != -1 || StrContains(key, "file") != -1)
	{
		g_eConfigState = Reading_Strings;
	}
	else
	{
		g_eConfigState = Reading_Integers;
	}
	
	if (g_eConfigSection == Section_Models)
	{
		ADD_PROPMODEL(key, value);
		return SMCParse_Continue;
	}
	
	if (g_eConfigSection == Section_Map)
	{
		switch (g_eConfigState)
		{
			case Reading_Integers:
			{
				new iBuffer;
				if (!GetTrieValue(g_hSettings, key, iBuffer))
				{
					LogError("[SREF] Invalid key used in map section.");
					return SMCParse_Continue;
				}
			}
			case Reading_Strings:
			{
				new String:sBuffer[64];
				if (!GetTrieString(g_hSettings, key, sBuffer, sizeof(sBuffer)))
				{
					LogError("[SREF] Invalid key used in map section.");
					return SMCParse_Continue;
				}
			}
		}
	}
	
	switch (g_eConfigState)
	{
		case Reading_Integers:
		{
			SetTrieValue(g_hSettings, key, StringToInt(value));
		}
		case Reading_Strings:
		{
			SetTrieString(g_hSettings, key, value);
		}
	}
	
	if (FindStringInArray(g_hSettingsList, key) == -1)
	{
		PushArrayString(g_hSettingsList, key);
	}
	
	return SMCParse_Continue;
}

public SMCResult:Config_EndSection(Handle:parser) 
{	
	return SMCParse_Continue;
}

public Config_End(Handle:parser, bool:halted, bool:failed) 
{
	if (failed)
	{
		SetFailState("Plugin configuration error");
	}
}

/**
Access the settings
*/
stock PrintSettings(client)
{
	new iArraySize = GetArraySize(g_hSettingsList);
	if (iArraySize == 0)
	{
		return;
	}
	for (new i = 0; i < iArraySize; i++)
	{
		new String:sSetting[64];
		GetArrayString(g_hSettingsList, i, sSetting, sizeof(sSetting));
		PrintToConsole(client, sSetting);
	}
}

stock GetConfigValue(const String:key[])
{
	new iValue;
	GetTrieValue(g_hSettings, key, iValue);
	return iValue;
}

stock bool:IsAuthorized(client, const String:flagkey[])
{
	new String:sAccessFlags[18];
	GetTrieString(g_hSettings, flagkey, sAccessFlags, sizeof(sAccessFlags));
	new ibFlags = ReadFlagString(sAccessFlags);
	if ((GetUserFlagBits(client) & ibFlags) == ibFlags)
	{
		return true;
	}
	if (GetUserFlagBits(client) & ADMFLAG_ROOT)
	{
		return true;
	}
	return false;
}

/**
Stocks for the parser
*/
stock bool:IsMapSection(const String:section[])
{
	new String:sCurrentMap[64];
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));
	
	if (StrContains(sCurrentMap, section) == 0)
	{
		return true;
	}
	
	return false;
}