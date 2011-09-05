/************************************************************************
*************************************************************************
Simple Chat Responses
Description:
		Provides automatic respondes based on a players chat message
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

#define PLUGIN_VERSION 		"0.1.0"
#define INVALID_RESPONSE 	-1

enum e_AutoResponses
{
	Handle:hPhrase,
	Handle:hResponse,
	Handle:hMatch
};

new Handle:g_aResponses[e_AutoResponses];

public Plugin:myinfo =
{
	name = "Simple Chat Responses",
	author = "Simple Plugins",
	description = "Provides automatic respondes based on a players chat message.",
	version = PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
};

public OnPluginStart()
{
	CreateConVar("scr_version", PLUGIN_VERSION, "Simple Chat Responses", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	RegAdminCmd("sm_reloadscr", Command_Reload, ADMFLAG_CONFIG,  "Reloads settings from the config files");
	
	for (new e_AutoResponses:i; i < e_AutoResponses:sizeof(g_aResponses); i++)
	{
		g_aResponses[i] = CreateArray(512, 1);
	}
	
	ProcessConfigFile("configs/simple-chatresponses.cfg");
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "scp"))
	{
		SetFailState("Simple Chat Processor Unloaded.  Plugin Disabled.");
	}
}

public Action:Command_Reload(client, args)
{
	ProcessConfigFile("configs/simple-chatresponses.cfg");
	LogAction(client, 0, "[SCP] Config file has been reloaded");
	ReplyToCommand(client, "[SCP] Config file has been reloaded");
	return Plugin_Handled;
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	new userid = GetClientUserId(author);
	new iArrayResponseSize = GetArraySize(g_aResponses[hPhrase]);
	new ResponseIndex = INVALID_RESPONSE;
	
	decl String:sMessageBuffer[MAX_MESSAGE_LENGTH];
	Color_StripFromChatText(message, sMessageBuffer, MAX_MESSAGE_LENGTH);
	//strcopy(sMessageBuffer, MAX_MESSAGE_LENGTH, message);
	TrimString(sMessageBuffer);
	
	for (new i = 0; i < iArrayResponseSize; i++)
	{
		new String:sMatchBuffer[512];
		GetArrayString(g_aResponses[hMatch], i, sMatchBuffer, sizeof(sMatchBuffer));
		if (StrEqual("exact", sMatchBuffer, false))
		{
			new String:sResponseBuffer[512];
			GetArrayString(g_aResponses[hPhrase], i, sResponseBuffer, sizeof(sResponseBuffer));
			if (StrEqual(sMessageBuffer, sResponseBuffer, false))
			{
				ResponseIndex = i;
				break;
			}
		}
	}

	if (ResponseIndex == INVALID_RESPONSE)
	{
		for (new x = 0; x < iArrayResponseSize; x++)
		{
			new String:sMatchBuffer[512];
			GetArrayString(g_aResponses[hMatch], x, sMatchBuffer, sizeof(sMatchBuffer));
			if (StrEqual("contains", sMatchBuffer, false))
			{
				new String:sResponseBuffer[512];
				GetArrayString(g_aResponses[hPhrase], x, sResponseBuffer, sizeof(sResponseBuffer));
				if (StrContains(sMessageBuffer, sResponseBuffer, false) != -1)
				{
					ResponseIndex = x;
					break;
				}
			}
		}
	}

	if (ResponseIndex != INVALID_RESPONSE)
	{
		new Handle:hPack;
		new numClients = GetArraySize(recipients);
		
		CreateDataTimer(0.5, Timer_ChatResponse, hPack, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(hPack, userid);
		WritePackCell(hPack, ResponseIndex);
		WritePackCell(hPack, numClients);
		for (new i = 0; i < numClients; i++)
		{
			new x = GetArrayCell(recipients, i);
			WritePackCell(hPack, x);
		}
	}
	
	return Plugin_Continue;
}

public Action:Timer_ChatResponse(Handle:timer, any:pack)
{
	ResetPack(pack);

	new client	= GetClientOfUserId(ReadPackCell(pack));
	if (client == 0)
	{
		return Plugin_Stop;
	}
	
	Color_ChatSetSubject(client);
	
	new ResponseIndex = ReadPackCell(pack);
	new numClients = ReadPackCell(pack);
	new clients[numClients];
	
	for (new i = 0; i < numClients; i++)
	{
		clients[i] = ReadPackCell(pack);
	}
	
	new String:sResponse[512];
	new String:sClientName[128];
	GetClientName(client, sClientName, sizeof(sClientName));
	GetArrayString(g_aResponses[hResponse], ResponseIndex, sResponse, sizeof(sResponse));
	ReplaceString(sResponse, sizeof(sResponse), "{name}", sClientName, false);
	
	for (new i = 0; i < numClients; i++)
	{
		if (Client_IsValid(clients[i]))
		{
			Client_PrintToChat(clients[i], true, sResponse);
		}
	}
	
	Color_ChatClearSubject();
	
	return Plugin_Stop;
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
		LogError("[SCR] Simple Chat Responses is not running! Could not find file %s", sConfigFile);
		SetFailState("Could not find file %s", sConfigFile);
	}
	else if (!ParseConfigFile(sConfigFile))
	{
		LogError("[SCR] Simple Chat Responses is not running! Failed to parse %s", sConfigFile);
		SetFailState("Parse error on file %s", sConfigFile);
	}
}

bool:ParseConfigFile(const String:file[]) 
{
	new Handle:hParser = SMC_CreateParser();
	new String:error[128];
	new line = 0;
	new col = 0;

	SMC_SetReaders(hParser, Config_NewSection, Config_KeyValue, Config_EndSection);
	SMC_SetParseEnd(hParser, Config_End);

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
	if (StrEqual(section, "auto_responses"))
	{
		return SMCParse_Continue;
	}
	
	PushArrayString(g_aResponses[hPhrase], section);
	
	return SMCParse_Continue;
}

public SMCResult:Config_KeyValue(Handle:parser, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{

	if(StrEqual(key, "text", false))
	{
		PushArrayString(g_aResponses[hResponse], value);
	}
	
	if(StrEqual(key, "match", false))
	{
		PushArrayString(g_aResponses[hMatch], value);
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