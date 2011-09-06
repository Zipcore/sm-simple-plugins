/************************************************************************
*************************************************************************
Simple Chat All Dead
Description:
		Displays dead chat based upon a console variable
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

#include <sourcemod>
#include <sdktools>
#include <scp>
#include <smlib>

#define PLUGIN_VERSION		"0.1.$Rev$"

enum e_DeadChat
{
	DeadChat_None,
	DeadChat_Dead,
	DeadChat_Team,
	DeadChat_All
};

new Handle:g_Cvar_hDeadChat = INVALID_HANDLE;

new e_DeadChat:g_eDeadChatMode;

public Plugin:myinfo =
{
	name = "Simple Chat All Dead",
	author = "Simple Plugins",
	description = "Displays dead chat based upon a console variable.",
	version = PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
};

public OnPluginStart()
{
	CreateConVar("scad_version", PLUGIN_VERSION, "Simple Chat All Dead", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_Cvar_hDeadChat = CreateConVar("scad_deadchat", "1",	"0 = Dead can't type chat \n 1 = Dead can type to other dead (team & all) players \n 2 = Dead can type to other dead (team & all) and living team players \n 3 = Dead can type to all players");
	HookConVarChange(g_Cvar_hDeadChat, ConVarSettingsChanged);
	
	AutoExecConfig(true);
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "scp"))
	{
		SetFailState("Simple Chat Processor Unloaded.  Plugin Disabled.");
	}
}

public OnConfigsExecuted()
{
	g_eDeadChatMode = e_DeadChat:GetConVarInt(g_Cvar_hDeadChat);
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	if (GetMessageFlags() & CHATFLAGS_DEAD == CHATFLAGS_DEAD)
	{
		switch (g_eDeadChatMode)
		{
			case DeadChat_None:
			{
				ClearArray(recipients);
			}
			case DeadChat_Dead:
			{
				if (GetMessageFlags() & CHATFLAGS_ALL == CHATFLAGS_ALL)
				{
					ClearArray(recipients);
					for (new i = 1; i <= MaxClients; i++)
					{
						if (IsValidClient(i) && !IsPlayerAlive(i))
						{
							PushArrayCell(recipients, i);
						}
					}	
				}
				else
				{
					ClearArray(recipients);
					new authorteam = GetClientTeam(author);
					for (new i = 1; i <= MaxClients; i++)
					{
						if (IsValidClient(i) && !IsPlayerAlive(i) && GetClientTeam(i) == authorteam)
						{
							PushArrayCell(recipients, i);
						}
					}
				}
			}
			case DeadChat_Team:
			{
				if (GetMessageFlags() & CHATFLAGS_ALL == CHATFLAGS_ALL)
				{
					ClearArray(recipients);
					new authorteam = GetClientTeam(author);
					for (new i = 1; i <= MaxClients; i++)
					{
						if (IsValidClient(i) && (!IsPlayerAlive(i) || GetClientTeam(i) == authorteam))
						{
							PushArrayCell(recipients, i);
						}
					}	
				}
				else
				{
					ClearArray(recipients);
					new authorteam = GetClientTeam(author);
					for (new i = 1; i <= MaxClients; i++)
					{
						if (IsValidClient(i) && GetClientTeam(i) == authorteam)
						{
							PushArrayCell(recipients, i);
						}
					}
				}
			}
			case DeadChat_All:
			{
				if (GetMessageFlags() & CHATFLAGS_ALL == CHATFLAGS_ALL)
				{
					ClearArray(recipients);
					for (new i = 1; i <= MaxClients; i++)
					{
						if (IsValidClient(i))
						{
							PushArrayCell(recipients, i);
						}
					}	
				}
				else
				{
					ClearArray(recipients);
					new authorteam = GetClientTeam(author);
					for (new i = 1; i <= MaxClients; i++)
					{
						if (IsValidClient(i) && GetClientTeam(i) == authorteam)
						{
							PushArrayCell(recipients, i);
						}
					}		
				}
			}
		}
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public ConVarSettingsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	OnConfigsExecuted();
}

stock bool:IsValidClient(client, bool:nobots = true) 
{  
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client))) 
    {  
        return false;  
    }  
    return IsClientInGame(client);  
}