/************************************************************************
*************************************************************************
Simple Team Balancer
Description:
 		Balances teams based upon player count
 		Player will not be balanced more than once in 5 (default) mins
 		Buddy system tries to keep buddies together
 		Ability to prioritize players
 		Ability to force players to accept the new team
 		Admins are immune
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

#include <simple-plugins>
#undef REQUIRE_EXTENSIONS
#undef AUTOLOAD_EXTENSIONS
#tryinclude <clientprefs>
#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS

#define 	PLUGIN_VERSION "2.1.0.$Rev$"

enum 	e_RoundState
{
	Map_Start,
	Round_Setup,
	Round_Normal,
	Round_Overtime,
	Round_SuddenDeath,
	Round_Ended
};

enum	e_PlayerStruct
{
	Handle:	hSwitchTimer,
	bool:		bSwitched,
	bool:		bFlagCarrier
};

/**
 Built-in cvars handles 
 */
new 	Handle:g_Cvar_mp_autoteambalance = INVALID_HANDLE;
new 	Handle:g_Cvar_mp_teams_unbalance_limit = INVALID_HANDLE;

/**
Cookies
*/
new 	Handle:g_hCookie_LastConnect = INVALID_HANDLE;
new 	Handle:g_hCookie_LastTeam = INVALID_HANDLE;
new 	Handle:g_hCookie_WasForced = INVALID_HANDLE;

/**
 Player arrays 
 */
new 	g_aPlayers[MAXPLAYERS + 1][e_PlayerStruct];

/**
Other Globals
*/
new		bool:g_bUseClientprefs = false;
new		e_RoundState:g_eRoundState;

#include "simple-plugins/stb-config.sp"
#include "simple-plugins/stb-daemon.sp"

public Plugin:myinfo =
{
	name = "Simple Team Balancer",
	author = "Simple Plugins",
	description = "Balances teams based upon player count.",
	version = PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
}

public OnPluginStart()
{
	
	/**
	Lets start to load
	*/
	LogMessage("Simple Team Balancer is loading...");
	
	/**
	Get game type and load the team numbers
	*/
	g_CurrentMod = GetCurrentMod();
	LoadCurrentTeams();
	
	/**
	Process the config file
	*/
	ProcessConfigFile();

	/**
	Hook the game events
	*/
	LogMessage("Hooking events for [%s].", g_sGameName[g_CurrentMod]);
	switch (g_CurrentMod)
	{
		case GameType_TF:
		{
			HookEvent("teamplay_round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("teamplay_round_win", HookRoundEnd, EventHookMode_Post);
			HookEvent("teamplay_suddendeath_begin", HookSuddenDeathBegin, EventHookMode_PostNoCopy);
			HookEvent("teamplay_flag_event", HookFlagEvent, EventHookMode_Post);
		}
		case GameType_DOD:
		{
			HookEvent("dod_round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("dod_round_win", HookRoundEnd, EventHookMode_Post);
		}
		case GameType_INS:
		{
			HookEvent("round_end", HookRoundEnd, EventHookMode_PostNoCopy);
		}
		default:
		{
			HookEvent("round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("round_end", HookRoundEnd, EventHookMode_PostNoCopy);
		}
	}
	
	/**
	Create console variables
	*/
	CreateConVar("stb_version", PLUGIN_VERSION, "Simple Team Balancer", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	/**
	Register the commands
	*/
	RegConsoleCmd("sm_balance", Command_Balance, "sm_balance: Balances the teams");
	RegConsoleCmd("sm_balancesetting", Command_SetSetting, "sm_balancesetting <setting> <value>: Sets a plugin setting");
	RegConsoleCmd("sm_balancereload", Command_Reload, "sm_balancereload: Reloads the config file");
	
	/**
	Try to find some built-in cvars
	*/
	g_Cvar_mp_autoteambalance = FindConVar("mp_autoteambalance");
	g_Cvar_mp_teams_unbalance_limit = FindConVar("mp_teams_unbalance_limit");
	
	/**
	Check if we found them
	If we did, remove the notify tags and hook the cvar
	*/
	if (g_Cvar_mp_autoteambalance != INVALID_HANDLE)
	{
		SetConVarFlags(g_Cvar_mp_autoteambalance, GetConVarFlags(g_Cvar_mp_autoteambalance)^FCVAR_NOTIFY);
		HookConVarChange(g_Cvar_mp_autoteambalance, ResetGameConVars);
	}
	if (g_Cvar_mp_teams_unbalance_limit != INVALID_HANDLE)
	{
		SetConVarFlags(g_Cvar_mp_teams_unbalance_limit, GetConVarFlags(g_Cvar_mp_teams_unbalance_limit)^FCVAR_NOTIFY);
		HookConVarChange(g_Cvar_mp_teams_unbalance_limit, ResetGameConVars);
	}
	
	/**
	Load translations and .cfg file
	*/
	LoadTranslations ("simpleteambalancer.phrases");
	LoadTranslations ("common.phrases");
}

public OnAllPluginsLoaded()
{
	
	/**
	Now lets check for client prefs extension
	*/
	if (CheckExtStatus("clientprefs.ext", true))
	{
		LogMessage("Client Preferences extension is loaded, checking database.");
		if (!SQL_CheckConfig("clientprefs"))
		{
			LogMessage("No 'clientprefs' database found.  Check your database.cfg file.");
			LogMessage("Plugin continued to load, but Client Preferences will not be used.");
			g_bUseClientprefs = false;
		}
		else
		{
			LogMessage("Database config 'clientprefs' was found.");
			LogMessage("Plugin will use Client Preferences.");
			g_bUseClientprefs = true;
		}
		
		/**
		Deal with client cookies
		*/
		if (g_bUseClientprefs)
		{
			g_hCookie_LastConnect = RegClientCookie("stb_lastconnect", "Timestamp of your last disconnection.", CookieAccess_Protected);
			g_hCookie_LastTeam = RegClientCookie("stb_lastteam", "Last team you were on.", CookieAccess_Protected);
			g_hCookie_WasForced = RegClientCookie("stb_wasforced", "If you were forced to this team", CookieAccess_Protected);
		}
	}
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "simpleplugins", false))
	{
		SetFailState("Core was unloaded and is required to run.");
	}
}

public OnConfigsExecuted()
{
	
	/**
	Report enabled
	*/
	if (GetSettingValue("enabled"))
	{
		LogMessage("Simple Team Balancer is ENABLED.");
	}
	else
	{
		LogMessage("Simple Team Balancer is DISABLED.");
	}	
	
	
	/**
	Report log activity 
	*/
	if (GetSettingValue("log_basic"))
	{
		LogMessage("Log Activity ENABLED.");
	}
	else
	{
		LogMessage("Log Activity DISABLED.");
	}
	if (GetSettingValue("log_detailed"))
	{
		LogMessage("Detailed Log Activity ENABLED.");
	}
	else
	{
		LogMessage("Detailed Log Activity DISABLED.");
	}
	
	StartDaemon();
}

public OnMapStart()
{
	
	/**
	Reset the globals
	*/
	g_eBalanceState = Balance_UnAcceptable;
	g_eRoundState = Map_Start;
	
	/**
	Set the built-in convars
	*/
	SetGameCvars();
	
	/**
	No round start in insurgency
	*/
	if (g_CurrentMod == GameType_INS || g_CurrentMod == GameType_DM)
	{
		CreateTimer(float(GetSettingValue("delay_roundstart")), Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public OnMapEnd()
{
	StopDaemon();
}

public OnClientCookiesCached(client)
{
	
	if (GetSettingValue("lock_players")
		&& (GetSettingValue("lock_reconnects"))
		&& (GetSettingValue("lockimmunity") && !IsAuthorized(client, "flag_lockimmunity"))
		&& IsValidClient(client))
	{
		new	String:sLastConnect[32],
				String:sLastTeam[3],
				String:sWasForced[3];
	
		/**
		Get the client cookies
		*/
		GetClientCookie(client, g_hCookie_LastConnect, sLastConnect, sizeof(sLastConnect));
		GetClientCookie(client, g_hCookie_LastTeam, sLastTeam, sizeof(sLastTeam));
		GetClientCookie(client, g_hCookie_WasForced, sWasForced, sizeof(sWasForced));
		
		if (StringToInt(sWasForced))
		{
			new	iCurrentTime = GetTime(),
					iConnectTime = StringToInt(sLastConnect);
	
			if (iCurrentTime - iConnectTime <= GetSettingValue("lock_duration"))
			{
	
				/**
				Bastard tried to reconnect
				*/
				SM_SetForcedTeam(client, StringToInt(sLastTeam), float(GetSettingValue("lock_duration")));
			}
		}
	}
}

public OnClientDisconnect(client)
{

	/**
	Call stock function to cleaup 
	*/
	CleanUp(client);
	
	if (g_bUseClientprefs && IsValidClient(client))
	{
		
		/**
		Set the disconnect cookies to prevent lock bypasses
		*/
		new	String:sTimeStamp[32],
				String:sTeam[3],
				String:sWasForced[3];
	
		new	iTeam = SM_GetForcedTeam(client),
				iTime = GetTime();
		
		Format(sWasForced, sizeof(sWasForced), "%d", iTeam);
		Format(sTimeStamp, sizeof(sTimeStamp), "%d", iTime);
		Format(sTeam, sizeof(sTeam), "%d", iTeam);
		
		SetClientCookie(client, g_hCookie_LastConnect, sTimeStamp);
		SetClientCookie(client, g_hCookie_LastTeam, sTeam);
		SetClientCookie(client, g_hCookie_WasForced, sWasForced);
	}
}

public SM_OnPlayerMoved(Handle:plugin, client, oldteam, newteam)
{
	
	/**
	Make sure we called the move function
	*/
	if (plugin != GetMyHandle())
	{
		return;
	}
	
	/**
	Get the players name and report the event
	*/
	if (GetSettingValue("log_basic"))
	{
		LogMessage("Changed %N to team %i.", client, newteam);
	}

	/**
	If we are in TF2 fire the bult-in team balance event
	*/
	if (g_CurrentMod == GameType_TF)
	{
		new Handle:event = CreateEvent("teamplay_teambalanced_player");
		SetEventInt(event, "player", client);
		SetEventInt(event, "team", newteam);
		FireEvent(event);
	}
		
	/**
	Notify the players
	*/
	SetGlobalTransTarget(client);
	PrintToChatAll("[SM] %t", "BalanceMessage", client);
	
	/**
	Set the players variables and start a timer
	*/
	g_aPlayers[client][bSwitched] = true;
	if (GetSettingValue("lock_players"))
	{
		SM_SetForcedTeam(client, newteam, float(GetSettingValue("lock_duration")), true);
	}
}

public SM_OnClientTeamForced(Handle:plugin, client, team, Float:time)
{
	// Maybe intergrate the autobalancers forced team and switching here
}

public Action:Command_Balance(client, args)
{

	/**
	Make sure we are enabled
	*/
	if (GetSettingValue("enabled"))
	{
		return Plugin_Handled;
	}
	
	/**
	Make sure the client is authorized to run this command.
	*/
	if (!IsAuthorized(client, "flag_balance"))
	{
		ReplyToCommand(client, "\x01\x04[STB]\x01 %t", "No Access");
		return Plugin_Handled;
	}
	
	/**
	TODO: Check for command arguments and show the menu if we dont have any or they are not right
	*/
	
	/**
	Log some activity
	TODO: Add ShowActivity and maybe do this at the end of the balance, add client, and more info
	*/
	LogAction(-1, -1, "[STB] The balance command was used");
	
	/**
	We are done, bug out.
	*/
	return Plugin_Handled;
}

public Action:Command_SetSetting(client, args)
{
	
	/**
	Make sure the client is authorized to run this command.
	*/
	if (!IsAuthorized(client, "flag_settings"))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	/**
	Check for command arguments
	*/
	new bool:bArgError = false;
	if (!GetCmdArgs())
	{
		
		/**
		No command arguments
		*/
		ReplyToCommand(client, "sm_scramblesetting <setting> <value>: Sets a plugin setting");
		if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
		{
			ReplyToCommand(client, "%t", "CheckConsoleForList");
		}
		PrintSettings(client);
		
		/**
		We are done, bug out.
		*/
		return Plugin_Handled;
	}
	
	/**
	Get the command arguments
	*/
	new String:sArg[2][64];
	GetCmdArg(1, sArg[0], sizeof(sArg[]));
	GetCmdArg(2, sArg[1], sizeof(sArg[]));
	
	/**
	Setup some buffers
	*/
	new iBuffer;
	new String:sBuffer[64];
	
	/**
	Check to see if we can get this with the value function
	If we can, the value is an integer and we know how to set it
	*/
	if (GetTrieValue(g_hSettings, sArg[0], iBuffer))
	{
		
		/**
		We attempt to set the setting with the integer functions
		Doublechecking that they didn't send us a string for this setting
		*/
		if (!SetTrieValue(g_hSettings, sArg[0], StringToInt(sArg[1])))
		{
			
			/**
			There was a problem with the value they tried to store
			*/
			bArgError = true;
			ReplyToCommand(client, "Invalid setting");
		}
	}
	
	/**
	We couldn't get it with the value function
	Check to see if we can get this with the string function
	If we can, the value is an string and we know how to set it
	*/
	else if (GetTrieString(g_hSettings, sArg[0], sBuffer, sizeof(sBuffer)))
	{
		
		/**
		We attempt to set the setting with the string functions
		Doublechecking that they didn't send us a string for this setting
		*/
		if (!SetTrieString(g_hSettings, sArg[0], sArg[1]))
		{
			
			/**
			There was a problem with the value they tried to store
			*/
			bArgError = true;
			ReplyToCommand(client, "Invalid setting");
		}
	}
	
	/**
	It must be an invalid key cause we can't find it
	*/
	else
	{
		bArgError = true;
		ReplyToCommand(client, "Invalid key");
	}
	
	/**
	Check to see if we encountered an error
	*/
	if (bArgError)
	{
		
		/**
		Looks like we did, tell them so
		*/
		ReplyToCommand(client, "sm_scramblesetting <setting> <value>: Sets a plugin setting");
		if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
		{
			ReplyToCommand(client, "%t", "CheckConsoleForList");
		}
		PrintSettings(client);
		
		/**
		We are done, bug out
		*/
		return Plugin_Handled;
	}
	else
	{
		
		/**
		We didn't have an error
		Log some activity
		*/
		ShowActivityEx(client, "\x01\x04[SAS]\x01 ", "%t", "Changed Setting", client, sArg[0], sArg[1]);
		LogAction(client, -1, "%T", "Changed Setting", LANG_SERVER, client, sArg[0], sArg[1]);
	}
	
	/**
	We are done, bug out
	*/
	return Plugin_Handled;
}

public Action:Command_Reload(client, args)
{
	
	/**
	Make sure the client is authorized to run this command.
	*/
	if (!IsAuthorized(client, "flag_settings"))
	{
		ReplyToCommand(client, "\x01\x04[SAS]\x01 %t", "No Access");
		return Plugin_Handled;
	}
	
	/**
	Process the config file
	*/
	ProcessConfigFile();
	
	/**
	Log some activity
	*/
	ShowActivityEx(client, "\x01\x04[SAS]\x01 ", "%t", "Reloaded Config", client);
	LogAction(client, -1, "%T", "Reloaded Config", LANG_SERVER, client);
	
	/**
	We are done, bug out.
	*/
	return Plugin_Handled;
}

/**
Hooked events 
*/
public HookRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	switch (g_CurrentMod)
	{
		case GameType_TF:
		{
			CreateTimer(1.0, Timer_CheckState);
		}
		default:
		{
			CreateTimer(float(GetSettingValue("delay_roundstart")), Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public HookSetupFinished(Handle:event, const String:name[], bool: dontBroadcast)
{
	CreateTimer(float(GetSettingValue("delay_roundstart")), Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

public HookRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_eRoundState = Round_Ended;
}

public HookSuddenDeathBegin(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_eRoundState = Round_SuddenDeath;
}

public HookFlagEvent(Handle:event, const String:name[], bool:dontBroadcast)
{

	/**
	Get our event variables
	*/
	new iClient = GetEventInt(event, "player");
	new iFlagStatus = GetEventInt(event, "eventtype");
	
	/**
	Make sure we have a valid client
	*/
	if (!IsValidClient(iClient))
	{
		return;
	}
	
	/**
	Determine what kind of event this is
	*/
	switch (iFlagStatus)
	{
		case 1:
		{
		
			/**
			The flag was picked up
			*/
			g_aPlayers[iClient][bFlagCarrier] = true;
		}
		case 2:
		{
		
			/**
			The flag was capped
			*/
			g_aPlayers[iClient][bFlagCarrier] = false;
		}
		case 3:
		{
		
			/**
			The flag was defended, we don't have to do anything
			*/
		}
		case 4:
		{
			
			/**
			The flag was dropped
			*/
			g_aPlayers[iClient][bFlagCarrier] = false;
		}
	}
}

/**
Stock functions 
 */
stock CleanUp(client)
{
	g_aPlayers[client][bFlagCarrier] = false;
	g_aPlayers[client][bSwitched] = false;
	ClearTimer(g_aPlayers[client][hSwitchTimer]);
}

stock SetGameCvars()
{
	if (GetSettingValue("convar_control") && GetSettingValue("enabled"))
	{
		if (g_Cvar_mp_autoteambalance != INVALID_HANDLE)
		{
			SetConVarInt(g_Cvar_mp_autoteambalance, 0);
		}
		if (g_Cvar_mp_teams_unbalance_limit != INVALID_HANDLE)
		{
			SetConVarInt(g_Cvar_mp_teams_unbalance_limit, GetSettingValue("unbalance_limit"));
		}
	}
}

/**
Timer functions 
 */
public Action:Timer_CheckState(Handle:timer, any:data)
{
	
	if (TF2_InSetup())
	{
		g_eRoundState = Round_Setup;
	}
	else
	{
		CreateTimer(float(GetSettingValue("delay_roundstart")), Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return Plugin_Handled;
}

public Action:Timer_RoundStart(Handle:timer, any:data)
{
	g_eRoundState = Round_Normal;
	return Plugin_Handled;
}

/**
Console variable change event 
*/
public ResetGameConVars(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SetGameCvars();
}