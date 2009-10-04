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
#include <simple-plugins>

#define PLUGIN_VERSION "1.0.2$"

#define CHAT_SYMBOL '@'
#define TRIGGER_SYMBOL1 '!'
#define TRIGGER_SYMBOL2 '/'
#define CHAR_PERCENT "%"
#define CHAR_NULL "\0"
	
new Handle:g_Cvar_hDebug = INVALID_HANDLE;
new Handle:g_Cvar_hTriggerBackup = INVALID_HANDLE;
new Handle:g_aGroupNames = INVALID_HANDLE;
new Handle:g_aGroupFlag = INVALID_HANDLE;
new Handle:g_aGroupNameColor = INVALID_HANDLE;
new Handle:g_aGroupTextColor = INVALID_HANDLE;

new bool:g_bDebug = false;
new bool:g_bTriggerBackup = false;

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
	Get game type and load the team numbers
	*/
	g_CurrentMod = GetCurrentMod();
	LoadCurrentTeams();
	LogAction(0, -1, "[SCC] Detected [%s].", g_sGameName[g_CurrentMod]);
	
	/**
	Need to create all of our console variables.
	*/
	CreateConVar("sm_chatcolors_version", PLUGIN_VERSION, "Simple Chat Colors", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_Cvar_hDebug = CreateConVar("sm_chatcolors_debug", "0", "Enable/Disable debugging information");
	g_Cvar_hTriggerBackup = CreateConVar("sm_chatcolors_triggerbackup", "0", "Enable/Disable the trigger backup");
	
	/**
	Hook console variables
	*/
	HookConVarChange(g_Cvar_hDebug, ConVarSettingsChanged);
	HookConVarChange(g_Cvar_hTriggerBackup, ConVarSettingsChanged);
	
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
	g_bDebug = GetConVarBool(g_Cvar_hDebug);
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
	Make sure its not the server or a chat trigger
	*/
	if (client == 0 || IsChatTrigger())
	{
		return Plugin_Continue;
	}
	
	/**
	Get the message
	*/
	decl	String:sMessage[1024];
	GetCmdArgString(sMessage, sizeof(sMessage));
	
	/**
	Process the message
	*/
	return ProcessMessage(client, false, sMessage, sizeof(sMessage));
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
	Get the message
	*/
	decl	String:sMessage[1024];
	GetCmdArgString(sMessage, sizeof(sMessage));
	
	/**
	Process the message
	*/
	return ProcessMessage(client, true, sMessage, sizeof(sMessage));
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
			LogMessage("Loaded Group Name/SteamID: %s", sGroupName);
			LogMessage("Loaded Flag String: %s", sGroupFlag);
			LogMessage("Loaded Color on name: %s", sGroupNameColor);
			LogMessage("Loaded Color of text: %s", sGroupTextColor);
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
	new bool:bDebug_FoundBySteamID = false;
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
		bDebug_FoundBySteamID = true;
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
		if (iIndex == -1)
		{
			PrintToChatAll("[SCC] Client %N was NOT found in colors config", client);
		}
		else
		{
			new String:sGroupName[256];
			GetArrayString(g_aGroupNames, iIndex, sGroupName, sizeof(sGroupName));
			PrintToChatAll("[SCC] Client %N was found in colors config", client);
			if (bDebug_FoundBySteamID)
			{
				PrintToChatAll("[SCC] Found steamid: %s in config file", sGroupName);
			}
			else
			{
				PrintToChatAll("[SCC] Found in group: %s in config file", sGroupName);
			}
		}
	}
}

stock bool:IsStringBlank(const String:input[])
{
	new len = strlen(input);
	for (new i=0; i<len; i++)
	{
		if (!IsCharSpace(input[i]))
		{
			return false;
		}
	}
	return true;
}

stock Action:ProcessMessage(client, bool:teamchat, String:message[], maxlength)
{
	
	/**
	Make sure the client has a color assigned
	*/
	if (g_aPlayerColorIndex[client] != -1)
	{
	
		/**
		The client is, so get the chat message and strip it down.
		*/
		decl String:sChatMsg[1280];
		StripQuotes(message);
		TrimString(message);
		new startidx;
		if (message[strlen(message)-1] == '"')
		{
			message[strlen(message)-1] = '\0';
			startidx = 1;
		}
		
		/**
		Because we are dealing with a chat message, lets take out all the %'s
		*/
		ReplaceString(message, maxlength, CHAR_PERCENT, CHAR_NULL);
		
		/**
		Make sure it's not blank
		*/
		if (IsStringBlank(message))
		{
			return Plugin_Stop;
		}
		
		/**
		Bug out if they are using the admin chat symbol (admin chat).
		*/
		if (message[startidx] == CHAT_SYMBOL)
		{
			return Plugin_Continue;
		}
		/**
		If we are using the trigger backup, then bug out on the triggers
		*/
		else if (g_bTriggerBackup && (message[startidx] == TRIGGER_SYMBOL1 || message[startidx] == TRIGGER_SYMBOL2))
		{
			return Plugin_Continue;
		}
		
		/**
		Log the message for hlstatsx and other things.
		*/
		if (teamchat)
		{
			LogPlayerEvent(client, "say_team", message);
		}
		else
		{
			LogPlayerEvent(client, "say", message);
		}
		
		/**
		Format the message.
		*/
		FormatMessage(	client, GetClientTeam(client), IsPlayerAlive(client), teamchat, g_aPlayerColorIndex[client], message, sChatMsg, sizeof(sChatMsg));
		
		/**
		Send the message.
		*/
		new bool:bTeamColorUsed = StrContains(sChatMsg, "{teamcolor}") != -1 ? true : false;
		new iCurrentTeam = GetClientTeam(client);
		if (teamchat)
		{
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == iCurrentTeam)
				{
					if (bTeamColorUsed)
					{
						CPrintToChatEx(i, client, "%s", sChatMsg);
					}
					else
					{
						CPrintToChat(i, "%s", sChatMsg);
					}
				}
			}
		}
		else
		{
			if (bTeamColorUsed)
			{
				CPrintToChatAllEx(client, "%s", sChatMsg);
			}
			else
			{
				CPrintToChatAll("%s", sChatMsg);
			}
		}
		
		/**
		We are done, bug out, and stop the original chat message.
		*/
		return Plugin_Stop;
	}

	/**
	Doesn't have a color assigned, bug out.
	*/
	return Plugin_Continue;
}

stock FormatMessage(client, team, bool:alive, bool:teamchat, index, const String:message[], String:chatmsg[], maxlength)
{
	decl	String:sDead[10],
			String:sTeam[15],
			String:sClientName[64];
	
	GetClientName(client, sClientName, sizeof(sClientName));
	
	if (teamchat)
	{
		if (team != g_aCurrentTeams[Spectator])
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
		if (team != g_aCurrentTeams[Spectator])
		{
			Format(sTeam, sizeof(sTeam), "");
		}
		else
		{
			Format(sTeam, sizeof(sTeam), "*SPEC* ");
		}
	}
	
	if (team != g_aCurrentTeams[Spectator])
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
	
	Format(chatmsg, maxlength, "{default}%s%s%s%s {default}:  %s%s", sDead, sTeam, sNameColor, sClientName, sTextColor, message);
}

/**
Adjust the settings if a convar was changed
*/
public ConVarSettingsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (convar == g_Cvar_hDebug)
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
	else if (convar == g_Cvar_hTriggerBackup)
	{
		if (StringToInt(newValue) == 1)
		{
			g_bTriggerBackup = true;
		}
		else
		{
			g_bTriggerBackup = false;
		}
	}
	

}