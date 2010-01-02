/************************************************************************
*************************************************************************
Approval Snippets Example
Description:
 		Example on how to use the the snippets
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

//Standard stuff
#pragma semicolon 1
#include <sourcemod>

//We include our snippet file
#include <approval-snippets>

#define PLUGIN_VERSION "1.0.$Rev$"

//Creating some cvar handles to use for the example
new Handle:g_Cvar_hMenuSounds = INVALID_HANDLE;
new Handle:g_Cvar_hDateFormat = INVALID_HANDLE;
new Handle:g_Cvar_hFloodTime = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "Approval Snippets Example",
	author = "Simple Plugins",
	description = "Example on how to use the the snippets",
	version = PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
};

/**
Sourcemod callbacks
*/
public OnPluginStart()
{
	//This is an example of a public console variable.  This is the only cvar that should be put in your posts description
	CreateConVar("approval_version", PLUGIN_VERSION, "Approval Snippets Example Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	//Lets check for a few game mods.  We won't use the fail option as we are just testing
	//For a full list of game types, look in the include file
	
	//A check for Left 4 Dead 1 and 2
	if (!SM_CheckForMod(GameType_L4D, false))
	{
		//If we were not testing then i would set the fail option to TRUE here if my mod ran only on left 4 dead 1/2
		//SM_CheckForMod(GameType_L4D2, true);   <--- Not testing if only runs on l4d 1 or 2
		SM_CheckForMod(GameType_L4D2, false);  // <--- Only for testing or if you support more mods
	}
	
	//A check for Teamfortress 2
	SM_CheckForMod(GameType_TF, false);  //Again, we would set fail to TRUE here if our plugin only works in TF2
	
	//A check for Neotokyo
	SM_CheckForMod(GameType_NEO, false);  //Again, we would set fail to TRUE here if our plugin only works in Neotokyo
	
	//We can also run game type specific code if the plugin works on more than one mod
	//Lets hook round start based upon a few game types
	LogAction(0, -1, "[Example] Hooking events for [%s].", g_sGameName[g_eCurrentMod]);
	switch (g_eCurrentMod)
	{
		case GameType_TF:
		{
			HookEvent("teamplay_round_start", HookRoundStart, EventHookMode_PostNoCopy);
		}
		case GameType_DOD:
		{
			HookEvent("dod_round_start", HookRoundStart, EventHookMode_PostNoCopy);
		}
		default:
		{
			HookEvent("round_start", HookRoundStart, EventHookMode_PostNoCopy);
		}
	}
	
	//Now lets save some cvar values so we can restore them if the plugin is unloaded
	//This function also gives you the handle to the cvar you want to save
	g_Cvar_hMenuSounds = SM_SaveConVar("sm_menu_sounds", CvarType_Integer);
	g_Cvar_hDateFormat = SM_SaveConVar("sm_datetime_format", CvarType_String);
	g_Cvar_hFloodTime = SM_SaveConVar("sm_flood_time", CvarType_Float);
	
	//Lets go ahead and make a few admin commands to test the stock functions 
	RegAdminCmd("sm_example-change", Command_Change, ADMFLAG_GENERIC,  "Alters example cvars slightly for testing");
	RegAdminCmd("sm_example-reset", Command_Reset, ADMFLAG_GENERIC,  "Restores example cvars slightly for testing");
	RegAdminCmd("sm_example-resetall", Command_ResetAll, ADMFLAG_GENERIC,  "Restores example cvars slightly for testing");
}

public OnPluginEnd()
{
	//Since this plugin is about to be unloaded, lets restore all the cvars back to the original state.  
	//This is NOT the default value, but the original value.
	SM_RestoreAllConVars();
}

/**
Commands
*/
public Action:Command_Change(client, args)
{
	//Lets go ahead and change these cvars to something to non default values
	SetConVarInt(g_Cvar_hMenuSounds, 0);
	SetConVarString(g_Cvar_hDateFormat, "%m/%d/%Y - %I:%M:%S %p");
	SetConVarFloat(g_Cvar_hFloodTime, 0.80);
	return Plugin_Handled;
}

public Action:Command_Reset(client, args)
{
	//Lets restore these one at a time to test the function, removing the last one from the list
	SM_RestoreConVar("sm_menu_sounds");
	SM_RestoreConVar("sm_datetime_format");
	SM_RestoreConVar("sm_flood_time", true);
	return Plugin_Handled;
}

public Action:Command_ResetAll(client, args)
{
	//Lets restore all of them
	SM_RestoreAllConVars();
	return Plugin_Handled;
}

/**
 Event hooks
 */
public HookRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	//Our event hook worked!
	PrintToChatAll("[Example] Round Started!");
}