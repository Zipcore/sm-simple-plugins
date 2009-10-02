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
$Id$
$Author$
$Revision$
$Date$
$LastChangedBy$
$LastChangedDate$
$URL$
$Copyright: (c) Simple Plugins 2008-2009$
*************************************************************************
*************************************************************************
*/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <colors>
#include <loghelper>

#define PLUGIN_VERSION "1.0.1.$Rev$"

#define CHAT_SYMBOL '@'
#define TRIGGER_SYMBOL1 '!'
#define TRIGGER_SYMBOL2 '/'

new Handle:g_hDebugCvar = INVALID_HANDLE;
new Handle:g_aGroupNames = INVALID_HANDLE;
new Handle:g_aGroupFlag = INVALID_HANDLE;
new Handle:g_aGroupNameColor = INVALID_HANDLE;
new Handle:g_aGroupTextColor = INVALID_HANDLE;

new bool:g_bDebug = false;

new g_iArraySize;

new g_aPlayerColorIndex[MAXPLAYERS + 1] = { -1, ... };

public Plugin:myinfo =
{
	name = "Simple Chat Colors",
	author = "Simple Plugins",
	description = "Changes the colors of players chat based on config file.",
	version = PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
};

/**
Sourcemod callbacks
*/
public OnPluginStart()
{

	/**
	Need to create all of our console variables.
	*/
	CreateConVar("sm_chatcolors_version", PLUGIN_VERSION, "Simple Chat Colors", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hDebugCvar = CreateConVar("sm_chatcolors_debug", "0", "Enable/Disable debugging information");
	
	/**
	Hook console variables
	*/
	HookConVarChange(g_hDebugCvar, ConVarSettingsChanged);
	
	/**
	Need to register the commands we are going to use
	*/
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_SayTeam);
	RegAdminCmd("sm_reloadchatcolors", Command_Reload, ADMFLAG_GENERIC,  "Reloads settings from config file");
	RegAdminCmd("sm_printchatcolors", Command_PrintChatColors, ADMFLAG_GENERIC,  "Prints out the color names in their color");
	
	/**
	Create the arrays
	*/
	g_aGroupNames = CreateArray(256, 1);
	g_aGroupFlag = CreateArray(15, 1);
	g_aGroupNameColor = CreateArray(15, 1);
	g_aGroupTextColor = CreateArray(15, 1);
	
	/**
	Load the admins and colors from the config
	*/
	LoadAdminsAndColorsFromConfig();
	g_iArraySize = GetArraySize(g_aGroupNames);
}

public OnConfigsExecuted()
{
	g_bDebug = GetConVarBool(g_hDebugCvar);
	ReloadConfigFile();	
}

public OnClientPostAdminCheck(client)
{
	
	/**
	Check the client to see if they are a admin
	*/
	CheckAdmin(client);
}

public OnClientDisconnect(client)
{
	g_aPlayerColorIndex[client] = -1;
}

public OnMapStart()
{
	GetTeams();
}

/**
Commands
*/
public Action:Command_Say(client, args)
{
	
	/**
	Make sure we are enabled.
	*/
	if (client == 0 || IsChatTrigger())
	{
		return Plugin_Continue;
	}
	
	if (g_aPlayerColorIndex[client] != -1)
	{
	
		/**
		The client is, so get the chat message and strip it down.
		*/
		decl	String:sArg[1024],
			String:sChatMsg[1024];
		
		GetCmdArgString(sArg, sizeof(sArg));
		StripQuotes(sArg);
		TrimString(sArg);
		new startidx;
		if (sArg[strlen(sArg)-1] == '"')
		{
			sArg[strlen(sArg)-1] = '\0';
			startidx = 1;
		}
		
		/**
		Bug out if they are using the admin chat symbol (admin chat).  If we are in CSS it may not find all the triggers, so we double check.
		*/
		if (sArg[startidx] == CHAT_SYMBOL || sArg[startidx] == TRIGGER_SYMBOL1 || sArg[startidx] == TRIGGER_SYMBOL2)
		{
			return Plugin_Continue;
		}
		
		/**
		Log the message for hlstatsx and other things.
		*/
		LogPlayerEvent(client, "say", sArg);
		
		/**
		Format the message.
		*/
		FormatMessage(client, GetClientTeam(client), IsPlayerAlive(client), false, g_aPlayerColorIndex[client], sArg, sChatMsg, sizeof(sChatMsg));
		
		/**
		Send the message.
		*/
		if (StrContains(sChatMsg, "{teamcolor}") != -1)
		{
			CPrintToChatAllEx(client, sChatMsg);
		}
		else
		{
			CPrintToChatAll(sChatMsg);
		}
		
		/**
		We are done, bug out, and stop the original chat message.
		*/
		return Plugin_Stop;
	}
	
	/**
	We are done, bug out.
	*/
	return Plugin_Continue;
}

public Action:Command_SayTeam(client, args)
{
	
	/**
	Make sure we are enabled.
	*/
	if (client == 0 || IsChatTrigger())
	{
		return Plugin_Continue;
	}
	
	/**
	Check the client to see if they are a admin
	*/
	if (g_aPlayerColorIndex[client] != -1)
	{
	
		/**
		The client is, so get the chat message and strip it down.
		*/
		decl	String:sArg[1024],
			String:sChatMsg[1024];
		
		new iCurrentTeam = GetClientTeam(client);
		
		GetCmdArgString(sArg, sizeof(sArg));
		StripQuotes(sArg);
		TrimString(sArg);
		new startidx;
		if (sArg[strlen(sArg)-1] == '"')
		{
			sArg[strlen(sArg)-1] = '\0';
			startidx = 1;
		}
		
		/**
		Bug out if they are using the admin chat symbol (admin chat).
		*/
		if (sArg[startidx] == CHAT_SYMBOL || sArg[startidx] == TRIGGER_SYMBOL1 || sArg[startidx] == TRIGGER_SYMBOL2)
		{
			return Plugin_Continue;
		}
		
		/**
		Log the message for hlstatsx and other things.
		*/
		LogPlayerEvent(client, "say_team", sArg);
		
		/**
		Format the message.
		*/
		FormatMessage(client, iCurrentTeam, IsPlayerAlive(client), true, g_aPlayerColorIndex[client], sArg, sChatMsg, sizeof(sChatMsg));
		
		/**
		Send the message to the same team
		*/
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == iCurrentTeam)
			{
				if (StrContains(sChatMsg, "{teamcolor}") != -1)
				{
					CPrintToChatEx(i, client, sChatMsg);
				}
				else
				{
					CPrintToChat(i, sChatMsg);
				}
			}
		}
		
		/**
		We are done, bug out, and stop the original chat message.
		*/
		return Plugin_Stop;
	}
	
	/**
	We are done, bug out.
	*/
	return Plugin_Continue;
}

public Action:Command_Reload(client, args)
{
	ReloadConfigFile();	
	return Plugin_Handled;
}

public Action:Command_PrintChatColors(client, args)
{
	CPrintToChat(client, "{default}default");
	CPrintToChat(client, "{green}green");
	CPrintToChat(client, "{yellow}yellow");
	CPrintToChat(client, "{lightgreen}lightgreen");
	CPrintToChat(client, "{red}red");
	CPrintToChat(client, "{blue}blue");
	CPrintToChatEx(client, client, "{teamcolor}teamcolor");
	CPrintToChat(client, "{olive}olive");
	return Plugin_Handled;
}

/**
Stock Functions
*/
stock LoadAdminsAndColorsFromConfig()
{
	
	/**
	Make sure the config file is here and load it up
	*/
	new String:sConfigFile[256];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/simple-chatcolors.cfg");
	if (!FileExists(sConfigFile)) 
	{
        
		/**
		Config file doesn't exists, stop the plugin
		*/
		LogError("[SCC] Simple Chat Colors is not running! Could not find file %s", sConfigFile);
		SetFailState("Could not find file %s", sConfigFile);
    }
	
	/**
	Create the arrays and variables
	*/
	new String:sGroupName[256];
	new String:sGroupFlag[15];
	new String:sGroupNameColor[15];
	new String:sGroupTextColor[15];
	
	
	/**
	Load config file as a KeyValues file
	*/
	new Handle:kvChatColors = CreateKeyValues("admin_colors");
	FileToKeyValues(kvChatColors, sConfigFile);
	
	if (!KvGotoFirstSubKey(kvChatColors))
	{
		return;
	}
	
	/**
	Load up all the groups in the file
	*/
	do
	{
		
		/**
		Get the section name; should be the "group" name
		*/
		KvGetSectionName(kvChatColors, sGroupName, sizeof(sGroupName));
		
		
		/**
		Get the flags and colors
		*/
		KvGetString(kvChatColors, "flag", sGroupFlag, sizeof(sGroupFlag));
		KvGetString(kvChatColors, "namecolor", sGroupNameColor, sizeof(sGroupNameColor));
		KvGetString(kvChatColors, "textcolor", sGroupTextColor, sizeof(sGroupTextColor));
		
		if (g_bDebug)
		{
			LogMessage("Group Name/SteamID: %s", sGroupName);
			LogMessage("Flag String: %s", sGroupFlag);
			LogMessage("Color on name: %s", sGroupNameColor);
			LogMessage("Color of text: %s", sGroupTextColor);
		}
		
		/**
		Push the values to the arrays
		*/
		PushArrayString(g_aGroupNames, sGroupName);
		PushArrayString(g_aGroupFlag, sGroupFlag);
		PushArrayString(g_aGroupNameColor, sGroupNameColor);
		PushArrayString(g_aGroupTextColor, sGroupTextColor);
	} while (KvGotoNextKey(kvChatColors));
	
	/**
	Close our handle
	*/
	CloseHandle(kvChatColors);
}

stock ReloadConfigFile()
{
	
	/**
	Clear the array
	*/
	ClearArray(g_aGroupNames);
	ClearArray(g_aGroupFlag);
	ClearArray(g_aGroupNameColor);
	ClearArray(g_aGroupTextColor);
	
	/**
	Load the admins, groups, and colors from the config
	*/
	LoadAdminsAndColorsFromConfig();
	g_iArraySize = GetArraySize(g_aGroupNames);
	
	/**
	Recheck all the online players for assigned colors
	*/
	for (new index = 1; index <= MaxClients; index++)
	{
		if (IsClientConnected(index) && IsClientInGame(index))
		{
			CheckAdmin(index);
		}
	}
}

stock CheckAdmin(client)
{
	new String:sFlags[15];
	new String:sClientSteamID[64];
	new iGroupFlags;
	new iFlags;
	new iIndex = -1;
	
	/**
	Look for a steamid first
	*/
	GetClientAuthString(client, sClientSteamID, sizeof(sClientSteamID));
	iIndex = FindStringInArray(g_aGroupNames, sClientSteamID);	
	if (iIndex != -1)
	{
		g_aPlayerColorIndex[client] = iIndex;
	}
	
	/**
	Didn't find one, check flags
	*/
	else
	{
		/**
		Search for flag in groups
		*/
		
		iFlags = GetUserFlagBits(client);
		for (iIndex = 0; iIndex < g_iArraySize; iIndex++)
		{
			GetArrayString(g_aGroupFlag, iIndex, sFlags, sizeof(sFlags));
			iGroupFlags = ReadFlagString(sFlags);
			if (iFlags & iGroupFlags)
			{
				g_aPlayerColorIndex[client] = iIndex;
				break;
			}
		}
	}
	
	if (g_bDebug)
	{
		PrintToChatAll("SteamID: %s", sClientSteamID);
		PrintToChatAll("Array Index: %i", iIndex);
		PrintToChatAll("Flag String: %s", sFlags);
		PrintToChatAll("Flag Bits of Client: %i", iFlags);
		PrintToChatAll("Flag Bits of Group: %i", iGroupFlags);
	}
}

stock FormatMessage(client, team, bool:alive, bool:teamchat, index, const Sting:sMessage[], String:sChatMsg[], maxlength)
{
	decl	String:sDead[10],
		String:sTeam[15],
		String:sClientName[64];
	
	GetClientName(client, sClientName, sizeof(sClientName));
	
	if (teamchat)
	{
		if (team > 1)
		{
			Format(sTeam, sizeof(sTeam), "(TEAM) ");
		}
		else
		{
			Format(sTeam, sizeof(sTeam), "(Spectator) ");
		}
	}
	else
	{
		if (team > 1)
		{
			Format(sTeam, sizeof(sTeam), "");
		}
		else
		{
			Format(sTeam, sizeof(sTeam), "*Spec* ");
		}
	}
	
	if (team > 1)
	{
		if (alive)
		{
			Format(sDead, sizeof(sDead), "");
		}
		else
		{
			Format(sDead, sizeof(sDead), "*DEAD* ");
		}
	}
	else
	{
		Format(sDead, sizeof(sDead), "");
	}
	
	new String:sNameColor[15];
	new String:sTextColor[15];
	GetArrayString(g_aGroupNameColor, index, sNameColor, sizeof(sNameColor));
	GetArrayString(g_aGroupTextColor, index, sTextColor, sizeof(sTextColor));
	
	Format(sChatMsg, maxlength, "{default}%s%s%s%s {default}: %s%s", sDead, sTeam, sNameColor, sClientName, sTextColor, sMessage);
}

/**
Adjust the settings if a convar was changed
*/
public ConVarSettingsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 1)
	{
		g_bDebug = true;
	}
	else
	{
		g_bDebug = false;
	}
}