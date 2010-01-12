/************************************************************************
*************************************************************************
Simple AutoScrambler
Description:
	Automatically scrambles the teams based upon a number of events.
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

#define PLUGIN_VERSION "0.1.$Rev$"

enum 	e_ScrambleMode
{
	Mode_Invalid = 0,
	Mode_Random,
	Mode_TopSwap,
	Mode_Scores,
	Mode_KillRatios
};

enum 	e_RoundState
{
	Map_Start,
	Round_Setup,
	Round_Normal,
	Round_Ended
};

enum 	e_PlayerData
{
	Handle:hForcedTimer,
	bool:bProtected,
	iFrags,
	iDeaths
};

enum 	e_TeamData
{
	Team_WinStreak,
	Team_Frags,
	Team_Deaths,
	Team_Goal
};

/**
Timers
*/
new		Handle:g_hAdTimer = INVALID_HANDLE;

/**
Arrays 
*/
new 	g_aPlayers[MAXPLAYERS + 1][e_PlayerData];
new 	g_aTeamInfo[e_Teams][e_TeamData];

/**
Cookies
*/
new 	Handle:g_hCookie_LastConnect = INVALID_HANDLE;
new 	Handle:g_hCookie_LastTeam = INVALID_HANDLE;

/**
Other globals
*/
new		e_RoundState:g_RoundState;

new		bool:g_bWasFullRound = false,
			bool:g_bScrambledThisRound = false,
			bool:g_bUseClientprefs = false;

new		g_iRoundCount,
			g_iRoundStartTime;

/**
Separate files to include
*/
#include "simple-plugins/sas_config_access.sp"
#include "simple-plugins/sas_scramble_functions.sp"
#include "simple-plugins/sas_vote_functions.sp"
#include "simple-plugins/sas_daemon.sp"

public Plugin:myinfo =
{
	name = "Simple AutoScrambler",
	author = "Simple Plugins",
	description = "Automatically scrambles the teams based upon a number of events.",
	version = PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
};

public OnPluginStart()
{
	
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
	HookEvent("player_death", HookPlayerDeath, EventHookMode_Pre);
	LogAction(0, -1, "[SAS] Hooking events for [%s].", g_sGameName[g_CurrentMod]);
	switch (g_CurrentMod)
	{
		case GameType_TF:
		{
			HookEvent("teamplay_round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("teamplay_round_win", HookRoundEnd, EventHookMode_Post);
			HookEvent("teamplay_setup_finished", HookSetupFinished, EventHookMode_PostNoCopy);
			HookEvent("ctf_flag_captured", HookCapture, EventHookMode_Post);
			HookEvent("teamplay_point_captured", HookCapture, EventHookMode_Post);
		}
		case GameType_DOD:
		{
			HookEvent("dod_round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("dod_round_win", HookRoundEnd, EventHookMode_Post);
			HookEvent("dod_point_captured", HookCapture, EventHookMode_Post);
		}
		default:
		{
			HookEvent("round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("round_end", HookRoundEnd, EventHookMode_Post);
		}
	}
	
	/**
	Create console variables
	*/
	CreateConVar("sas_version", PLUGIN_VERSION, "Simple AutoScrambler Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	/**
	Register the commands
	*/
	RegConsoleCmd("sm_scramble", Command_Scramble, "sm_scramble <mode>: Scrambles the teams");
	RegConsoleCmd("sm_resetscores", Command_ResetScores, "sm_resetscores: Resets the players scores");
	RegConsoleCmd("sm_scramblesetting", Command_SetSetting, "sm_scramblesetting <setting> <value>: Sets a plugin setting");
	RegConsoleCmd("sm_scramblereload", Command_Reload, "sm_scramblereload: Reloads the config file");
	CreateVoteCommand();
	
	if (GetSettingValue("vote_ad_enabled"))
	{
		new Float:fAdInterval = float(GetSettingValue("vote_ad_interval"));
		g_hAdTimer = CreateTimer(fAdInterval, Timer_VoteAdvertisement, _, TIMER_REPEAT);
	}
	
	/**
	Load translations and .cfg file
	*/
	LoadTranslations ("simpleautoscrambler.phrases");
	LogAction(0, -1, "[SAS] Simple AutoScrambler is loaded.");
}

public OnAllPluginsLoaded()
{
	
	/**
	Now lets check for client prefs extension
	*/
	new String:sExtError[256];
	new iExtStatus = GetExtensionFileStatus("clientprefs.ext", sExtError, sizeof(sExtError));
	if (iExtStatus == -2)
	{
		LogAction(0, -1, "[SAS] Client Preferences extension was not found.");
		LogAction(0, -1, "[SAS] Plugin continued to load, but that feature will not be used.");
		g_bUseClientprefs = false;
	}
	if (iExtStatus == -1 || iExtStatus == 0)
	{
		LogAction(0, -1, "[SAS] Client Preferences extension is loaded with errors.");
		LogAction(0, -1, "[SAS] Status reported was [%s].", sExtError);
		LogAction(0, -1, "[SAS] Plugin continued to load, but that feature will not be used.");
		g_bUseClientprefs = false;
	}
	if (iExtStatus == 1)
	{
		LogAction(0, -1, "[SAS] Client Preferences extension is loaded, checking database.");
		if (!SQL_CheckConfig("clientprefs"))
		{
			LogAction(0, -1, "[SAS] No 'clientprefs' database found.  Check your database.cfg file.");
			LogAction(0, -1, "[SAS] Plugin continued to load, but Client Preferences will not be used.");
			g_bUseClientprefs = false;
		}
		else
		{
			LogAction(0, -1, "[SAS] Database config 'clientprefs' was found.");
			LogAction(0, -1, "[SAS] Plugin will use Client Preferences.");
			g_bUseClientprefs = true;
		}
		
		/**
		Deal with client cookies
		*/
		if (g_bUseClientprefs)
		{
			g_hCookie_LastConnect = RegClientCookie("sas_lastconnect", "Timestamp of your last disconnection.", CookieAccess_Protected);
			g_hCookie_LastTeam = RegClientCookie("sas_lastteam", "Last team you were on.", CookieAccess_Protected);
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
	Log our activity
	*/
	if (GetSettingValue("enabled"))
	{
		LogAction(0, -1, "Simple AutoScrambler is ENABLED");
	}
	else
	{
		LogAction(0, -1, "Simple AutoScrambler is DISABLED");
	}
}

public OnMapStart()
{
	g_RoundState = Map_Start;
	g_bWasFullRound = true;
	ResetScores();
	ResetStreaks();
	StartDaemon();
}

public OnMapEnd()
{
	StopDaemon();
	StopScramble();
}

public OnClientPostAdminCheck(client)
{
	
}

public OnClientCookiesCached(client)
{
	
	if (GetSettingValue("lock_players")
		&& (GetSettingValue("lockimmunity") && !IsAuthorized(client, "flag_lockimmunity")))
	{
		new	String:sLastConnect[32],
				String:sLastTeam[3];
	
		/**
		Get the client cookies
		*/
		GetClientCookie(client, g_hCookie_LastConnect, sLastConnect, sizeof(sLastConnect));
		GetClientCookie(client, g_hCookie_LastTeam, sLastTeam, sizeof(sLastTeam));
	
		new	iCurrentTime = GetTime(),
				iConnectTime = StringToInt(sLastConnect);
	
		if (iCurrentTime - iConnectTime <= GetSettingValue("lock_duration"))
		{
	
			/**
			Bastard tried to reconnect
			*/
			SM_MovePlayer(client, StringToInt(sLastTeam));
		}
	}
}

public SM_OnPlayerMoved(Handle:plugin, client, team)
{
	
	/**
	Make sure we called the move function
	*/
	if (plugin != GetMyHandle())
	{
		return;
	}
	
	/**
	Check if we are supposed to lock the players to the team
	*/
	if (GetSettingValue("lock_players") 
		&& g_aPlayers[client][hForcedTimer] == INVALID_HANDLE 
		&& (GetSettingValue("lockimmunity") && !IsAuthorized(client, "flag_lockimmunity")))
	{
		
		/**
		We are, set the forced team and start the timer
		*/
		SM_SetForcedTeam(client, team);
		new Float:fLockDuration = float(GetSettingValue("lock_duration"));
		g_aPlayers[client][hForcedTimer] = CreateTimer(fLockDuration, Timer_PlayerTeamLock, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public OnClientDisconnect(client)
{
	
	/**
	Cleanup
	*/
	ClearTimer(g_aPlayers[client][hForcedTimer]);
	g_aPlayers[client][bProtected] = false;
	g_aPlayers[client][iFrags] = 0;
	g_aPlayers[client][iDeaths] = 0;
	
	
	if (g_bUseClientprefs)
	{
		
		/**
		Set the disconnect cookies to prevent lock bypasses
		*/
		new	String:sTimeStamp[32],
				String:sTeam[3];
	
		new	iTeam = GetClientTeam(client),
				iTime = GetTime();
	
		//FormatTime(sTimeStamp, sizeof(sTimeStamp), "%j-%H-%M");
		Format(sTimeStamp, sizeof(sTimeStamp), "%d", iTime);
		Format(sTeam, sizeof(sTeam), "%d", iTeam);
		
		SetClientCookie(client, g_hCookie_LastConnect, sTimeStamp);
		SetClientCookie(client, g_hCookie_LastTeam, sTeam);
	}
}

public Action:Command_Scramble(client, args)
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
	if (!IsAuthorized(client, "flag_scramble"))
	{
		ReplyToCommand(client, "\x01\x04[SM]\x01 %T", "RestrictedCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	
	/**
	Make sure it's ok to scramble at this time
	*/
	if (!CanScramble())
	{
		return Plugin_Handled;
	}
	
	/**
	Log some activity
	TODO: Add ShowActivity and maybe do this at the end of the scramble, add client, and more info
	*/
	LogAction(0, -1, "[SAS] The scramble command was used");
	
	/**
	TODO: Check for command arguments and show the menu if we dont have any or they are not right
	*/
	
	/**
	We are done, bug out.
	*/
	return Plugin_Handled;
}

public Action:Command_ResetScores(client, args)
{
	
	/**
	Make sure the client is authorized to run this command.
	*/
	if (!IsAuthorized(client, "flag_reset_scores"))
	{
		ReplyToCommand(client, "\x01\x04[SM]\x01 %T", "RestrictedCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	
	/**
	Reset the scores
	*/
	ResetScores();
	ResetStreaks();
	
	/**
	Log some activity
	*/
	ShowActivityEx(client, "[SAS]", "%N reset the score tracking for the scrambler", client);
	LogAction(client, -1, "%N reset the score tracking for the scrambler", client);
	
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
		ReplyToCommand(client, "\x01\x04[SAS]\x01 %T", "RestrictedCmd", LANG_SERVER);
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
			ReplyToCommand(client, "Check console for a list of settings");
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
			ReplyToCommand(client, "Check console for a list of settings");
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
		ShowActivityEx(client, "[SAS]", "%N changed the scramble option (%s) to (%s)", client, sArg[1]);
		LogAction(client, -1, "%N changed the scramble option (%s) to (%s)", client);
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
		ReplyToCommand(client, "\x01\x04[SM]\x01 %T", "RestrictedCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	
	/**
	Process the config file
	*/
	ProcessConfigFile();
	
	/**
	Log some activity
	*/
	ShowActivityEx(client, "[SAS]", "%N reloaded the scrambler config file", client);
	LogAction(client, -1, "%N reloaded the config file", client);
	
	/**
	We are done, bug out.
	*/
	return Plugin_Handled;
}

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
			g_iRoundStartTime = GetTime();
			g_RoundState = Round_Normal;
		}
	}
}

public HookSetupFinished(Handle:event, const String:name[], bool: dontBroadcast)
{
	g_iRoundStartTime = GetTime();
	g_RoundState = Round_Normal;
}

public HookCapture(Handle:event, const String:name[], bool:dontBroadCast)
{
	new e_Teams:CappingTeam = e_Teams:GetEventInt(event, "capping_team");
	g_aTeamInfo[CappingTeam][Team_Goal] = 1;
}

public HookRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	new iRoundWinner;
	
	g_iRoundCount++;
	g_bWasFullRound = true;
	
	switch (g_CurrentMod)
	{
		case GameType_TF:
		{
			if (GetEventBool(event, "full_round"))
			{
				iRoundWinner = GetEventInt(event, "team");
			}
			else
			{
				g_iRoundCount--;
				g_bWasFullRound = false;
			}
		}
		case GameType_DOD:
		{
			iRoundWinner = GetEventInt(event, "team");
		}
		default:
		{
			iRoundWinner = GetEventInt(event, "winner");
		}
	}
	
	AddTeamStreak(e_Teams:iRoundWinner);
	
	g_RoundState = Round_Ended;
	
	if (CanScramble() && RoundEnd_ScrambleCheck())
	{
		if (GetSettingValue("auto_action"))
		{
			StartVote();
		}
		else
		{
			StartScramble(e_ScrambleMode:GetSettingValue("sort_mode"));
		}
	}
}

public Action:HookPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	/**
	If scrambling block deaths from being logged as a result of scramble
	*/
	if (g_bScrambling)
	{
		return Plugin_Handled;
	}
	
	switch (g_CurrentMod)
	{
		case GameType_TF:
		{
			
			/** 
			Check for spy fake deaths
			*/
			if (GetEventInt(event, "death_flags") & 32)
			{
				return Plugin_Continue;
			}
		}
	}
	
	/**
	Check the round state and count the kills and deaths if round is active
	*/
	if (g_RoundState == Round_Normal)
	{
		new iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		new iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
		
		if (IsValidClient(iAttacker))
		{
			new e_Teams:iAttackerTeam = e_Teams:GetClientTeam(iAttacker);
			g_aPlayers[iAttacker][iFrags]++;
			g_aTeamInfo[iAttackerTeam][Team_Frags]++;
		}
		
		if (IsValidClient(iVictim))
		{
			new e_Teams:iVictimTeam = e_Teams:GetClientTeam(iVictim);
			g_aPlayers[iVictim][iDeaths]++;
			g_aTeamInfo[iVictimTeam][Team_Deaths]++;
		}
	}
	
	return Plugin_Continue;
}

public Action:Timer_CheckState(Handle:timer, any:data)
{
	
	if (TF2_InSetup())
	{
		g_RoundState = Round_Setup;
	}
	else
	{
		g_iRoundStartTime = GetTime();
		g_RoundState = Round_Normal;
	}
	
	return Plugin_Handled;
}

public Action:Timer_PlayerTeamLock(Handle:timer, any:client)
{
	
	SM_ClearForcedTeam(client);
	g_aPlayers[client][hForcedTimer] = INVALID_HANDLE;
	
	return Plugin_Handled;
}

public Action:Timer_VoteAdvertisement(Handle:timer, any:data)
{
	if (!GetSettingValue("vote_ad_enabled"))
	{
		g_hAdTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	PrintToChatAll("\x01\x04[SAS]\x01 %T", "Vote_Advertisement", LANG_SERVER);
	return Plugin_Handled;
}