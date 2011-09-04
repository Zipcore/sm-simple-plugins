/************************************************************************
*************************************************************************
Simple Chat Colors
Description:
		Changes the colors of players chat based on config file
*************************************************************************
*************************************************************************
This file is part of Simple Plugins project.

This plugin is free software: you can redistribute 
it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License, or
later version. 

This plugin is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this plugin.  If not, see <http://www.gnu.org/licenses/>.
*************************************************************************
*************************************************************************
File Information
$Id: simple-chatcolors.sp 160 2011-08-27 07:02:56Z antithasys $
$Author: antithasys $
$Revision: 160 $
$Date: 2011-08-27 02:02:56 -0500 (Sat, 27 Aug 2011) $
$LastChangedBy: antithasys $
$LastChangedDate: 2011-08-27 02:02:56 -0500 (Sat, 27 Aug 2011) $
$URL: https://sm-simple-plugins.googlecode.com/svn/trunk/Simple%20Chat%20Colors/addons/sourcemod/scripting/simple-chatcolors.sp $
$Copyright: (c) Simple Plugins 2008-2009$
*************************************************************************
*************************************************************************
*/

#include <sourcemod>
#include <sdktools>
#include <scp>
#include <smlib>

#define PLUGIN_VERSION "0.1.0"

enum e_Settings
{
	Handle:hGroupName,
	Handle:hGroupFlag,
	Handle:hNameColor,
	Handle:hTextColor,
	Handle:hTagText,
	Handle:hTagColor
};

new Handle:g_aSettings[e_Settings];
new g_aPlayerIndex[MAXPLAYERS + 1] = { -1, ... };
new g_iArraySize = -1;

public Plugin:myinfo =
{
	name = "Simple Chat Colors",
	author = "Simple Plugins",
	description = "Changes the colors of players chat based on config file.",
	version = PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
};

public OnPluginStart()
{
	CreateConVar("scc_version", PLUGIN_VERSION, "Simple Chat Colors", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	RegAdminCmd("sm_reloadscc", Command_Reload, ADMFLAG_CONFIG,  "Reloads settings from the config files");
	RegAdminCmd("sm_printcolors", Command_PrintColors, ADMFLAG_GENERIC,  "Prints out the color names in their color");
	
	/**
	Create the arrays
	*/
	for (new e_Settings:i; i < e_Settings:sizeof(g_aSettings); i++)
	{
		g_aSettings[i] = CreateArray(256, 1);
	}
	
	ProcessConfigFile("configs/simple-chatcolors.cfg");
}

public OnClientPostAdminCheck(client)
{
	CheckPlayer(client);
}

public OnClientDisconnect(client)
{
	g_aPlayerIndex[client] = -1;
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "scp"))
	{
		SetFailState("Simple Chat Processor Unloaded.  Plugin Disabled.");
	}
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	//the sequence of the following is important to get the color tags in front of the text
	if (g_aPlayerIndex[author] != -1)
	{
		new index = CHATCOLOR_NOSUBJECT;
		decl String:sBuffer[4][256];
		GetArrayString(g_aSettings[hNameColor], g_aPlayerIndex[author], sBuffer[0], sizeof(sBuffer[]));
		GetArrayString(g_aSettings[hTagText], g_aPlayerIndex[author], sBuffer[1], sizeof(sBuffer[]));
		GetArrayString(g_aSettings[hTagColor], g_aPlayerIndex[author], sBuffer[2], sizeof(sBuffer[]));
		GetArrayString(g_aSettings[hTextColor], g_aPlayerIndex[author], sBuffer[3], sizeof(sBuffer[]));
		
		decl String:sFormatBuffer[256];
		Format(sFormatBuffer, sizeof(sFormatBuffer), "%s%s%s%s", sBuffer[2], sBuffer[1], sBuffer[0], name);
		index = Color_ParseChatText(sFormatBuffer, name, MAX_NAME_LENGTH);
		
		Format(sFormatBuffer, sizeof(sFormatBuffer), "%s%s", sBuffer[3], message);	
		if (index == CHATCOLOR_NOSUBJECT)
		{
			index = Color_ParseChatText(sFormatBuffer, message, MAX_MESSAGE_LENGTH);
		}
		else
		{
			Color_ChatSetSubject(index)
			Color_ParseChatText(sFormatBuffer, message, MAX_MESSAGE_LENGTH);
			Color_ChatClearSubject();
		}
		
		if (index != CHATCOLOR_NOSUBJECT)
		{
			author = index;
		}
		
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action:Command_Reload(client, args)
{
	ProcessConfigFile("configs/simple-chatcolors.cfg");
	LogAction(client, 0, "[SCC] Config file has been reloaded");
	ReplyToCommand(client, "[SCC] Config file has been reloaded");
	return Plugin_Handled;
}

public Action:Command_PrintColors(client, args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "Command can only be ran while in game");
		return Plugin_Handled;
	}
	Client_PrintToChat(client, true, "{N}default");
	Client_PrintToChat(client, true, "{G}green");
	Client_PrintToChat(client, true, "{L}lightgreen");
	Client_PrintToChat(client, true, "{R}red");
	Client_PrintToChat(client, true, "{B}blue");
	Client_PrintToChat(client, true, "{T}teamcolor");
	Client_PrintToChat(client, true, "{OG}olive");
	return Plugin_Handled;
}

stock CheckPlayer(client)
{
	new String:sFlags[15];
	new String:sClientSteamID[64];
	new iIndex = -1;
	
	/**
	Look for a steamid first
	*/
	GetClientAuthString(client, sClientSteamID, sizeof(sClientSteamID));
	iIndex = FindStringInArray(g_aSettings[hGroupName], sClientSteamID);	
	if (iIndex != -1)
	{
		g_aPlayerIndex[client] = iIndex;
	}
	
	/**
	Didn't find one, check for flags
	*/
	else
	{
		
		/**
		Search for flag in groups
		*/
		for (new i = 0; i <= g_iArraySize; i++)
		{
			decl String:sGroupName[64];
			GetArrayString(g_aSettings[hGroupName], i, sGroupName, sizeof(sGroupName));
			GetArrayString(g_aSettings[hGroupFlag], i, sFlags, sizeof(sFlags));
			new iGroupFlags = ReadFlagString(sFlags);
			if (iGroupFlags != 0 && CheckCommandAccess(client, "scc_colors", iGroupFlags, true))
			{
				g_aPlayerIndex[client] = i;
				iIndex = i;
				break;
			}
		}
		
		/**
		Check to see if flag was found
		*/
		if (iIndex == -1)
		{
			
			/**
			No flag, look for an "everyone" group
			*/
			iIndex = FindStringInArray(g_aSettings[hGroupName], "everyone");
			if (iIndex != -1)
			{
				g_aPlayerIndex[client] = iIndex;
			}
		}
	}
}

/**
Parse the config file
*/
stock ProcessConfigFile(const String:file[])
{
	new String:sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), file);
	if (!FileExists(sConfigFile)) 
	{
		/**
		Config file doesn't exists, stop the plugin
		*/
		LogError("[SCC] Simple Chat Colors is not running! Could not find file %s", sConfigFile);
		SetFailState("Could not find file %s", sConfigFile);
	}
	else if (!ParseConfigFile(sConfigFile))
	{
		/**
		Config file doesn't exists, stop the plugin
		*/
		LogError("[SCC] Simple Chat Colors is not running! Failed to parse %s", sConfigFile);
		SetFailState("Parse error on file %s", sConfigFile);
	}
	
	/**
	Recheck all the online players for assigned colors
	*/
	for (new index = 1; index <= MaxClients; index++)
	{
		if (IsClientConnected(index) && IsClientInGame(index))
		{
			CheckPlayer(index);
		}
	}
}

bool:ParseConfigFile(const String:file[]) 
{

	new Handle:hParser = SMC_CreateParser();
	new String:error[128];
	new line = 0;
	new col = 0;
	
	/**
	Define the color config functions
	*/
	SMC_SetReaders(hParser, Config_NewSection, Config_KeyValue, Config_EndSection);
	SMC_SetParseEnd(hParser, Config_End);
	
	/**
	Parse the file and get the result
	*/
	new SMCError:result = SMC_ParseFile(hParser, file, line, col);
	CloseHandle(hParser);

	if (result != SMCError_Okay) 
	{
		SMC_GetErrorString(result, error, sizeof(error));
		LogError("%s on line %d, col %d of %s", error, line, col, file);
	}
	
	return (result == SMCError_Okay);
}

public SMCResult:Config_NewSection(Handle:parser, const String:section[], bool:quotes) 
{
	if (StrEqual(section, "admin_colors"))
	{
		return SMCParse_Continue;
	}
	PushArrayString(g_aSettings[hGroupName], section);
	return SMCParse_Continue;
}

public SMCResult:Config_KeyValue(Handle:parser, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
	if(StrEqual(key, "flag", false))
	{
		PushArrayString(g_aSettings[hGroupFlag], value);
	}
	else if(StrEqual(key, "tag", false))
	{
		PushArrayString(g_aSettings[hTagText], value);
	}
	else if(StrEqual(key, "tagcolor", false))
	{
		PushArrayString(g_aSettings[hTagColor], value);
	}
	else if(StrEqual(key, "namecolor", false))
	{
		PushArrayString(g_aSettings[hNameColor], value);
	}
	else if(StrEqual(key, "textcolor", false))
	{
		PushArrayString(g_aSettings[hTextColor], value);
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
	g_iArraySize = GetArraySize(g_aSettings[hGroupName]) - 1;
}