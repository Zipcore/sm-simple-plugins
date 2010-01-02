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
#include <tf2_extended>

#define PLUGIN_VERSION "1.1.$Rev$"
#define ADMIN_IMMUNE	(1<<0)
#define MEDIC_IMMUNE	(1<<1)
#define ENGINEER_IMMUNE	(1<<2)
#define BUDDY_IMMUNE	(1<<3)
#define TEAMWORK_IMMUNE	(1<<4)

/**
Round States
PREROUND 	=	Players cannot hurt eachother, or their frags aren't counted
NORMAL		= 	Players are scoring points normally
BONUS		=	A team has won, and we're waiting for next round... Team is slaughtering the defenseless other team
*/
#define PREROUND 0
#define NORMAL 1
#define BONUS 2

/**
Different scramble modes:

1	=	Full Scramble, dont restart round.
2	=	Admins Immune, dont restart round.
3	=	Full Scramble, restart round and reset scores.
4	=	Admins Immune, restart round and reset scores.

*/

/**
Different top player modes:

1	=	Divide Top 4 players on the two teams.
2	=	Protect the Top 2 players on each team.

*/

enum PlayerData
{
	Handle:hForcedTimer,
	bool:bProtected,
	iFrags,
	iDeaths;
};

enum ScrambleMode
{
	random,
	topSwap,
	middleSwap,
	scores,
	frags,
	killRatios;
}

enum RoundData
{
	iRoundState,
	iStartTime,
	iScrambleTriggers,
}

/**
Cvars used for admins

new Handle:	sas_admin_immunity_enabled 		=	INVALID_HANDLE,
	Handle:	sas_admin_flag_scramblenow 		= 	INVALID_HANDLE,
	Handle:	sas_admin_flag_immunity 		= 	INVALID_HANDLE;

/**
Cvars used for autoscramble

new Handle:	sas_autoscramble_enabled 		= 	INVALID_HANDLE,
	Handle:	sas_autoscramble_minplayers 	= 	INVALID_HANDLE,
	Handle:	sas_autoscramble_mode 			= 	INVALID_HANDLE,
	Handle:	sas_autoscramble_winstreak 		= 	INVALID_HANDLE,
	Handle:	sas_autoscramble_steamroll		=	INVALID_HANDLE,
	Handle:	sas_autoscramble_frags 			= 	INVALID_HANDLE;

/**
Cvars used for voting

new Handle:	sas_vote_enabled				= 	INVALID_HANDLE,
	Handle:	sas_vote_upcount 				= 	INVALID_HANDLE,
	Handle:	sas_vote_winpercent 			= 	INVALID_HANDLE,
	Handle:	sas_vote_mode 					= 	INVALID_HANDLE,
	Handle:	sas_vote_minplayers 			= 	INVALID_HANDLE;

/**
Additional cvars

new Handle:	sas_enabled 					= 	INVALID_HANDLE,
	Handle:	sas_timer_scrambledelay 		= 	INVALID_HANDLE,
	Handle:	TFGameModeArena 				= 	INVALID_HANDLE;
	
*/
/**
Timers
*/
new Handle:	g_hScrambleTimer				= 	INVALID_HANDLE;

/**
 Player arrays 
 */
new 		g_aPlayers[MAXPLAYERS + 1][PlayerData];

/**
 Cvar variables
 */
new bool:	g_bIsEnabled,
	bool:	g_bIsAutoScrambleEnabled,
	bool:	g_bIsVoteEnabled,
	bool:	g_bIsAdminImmunityEnabled,
	bool:	g_bScrambling;
new Float:	g_fTimer_ScrambleDelay,
	Float:	g_fVote_UpCount,
	Float:	g_fVote_WinPercent;
new 		g_iAutoScramble_Minplayers,
			g_iAutoScramble_Mode,
			g_iAutoScramble_WinStreak,
			g_iAutoScramble_SteamRoll,
			g_iAutoScramble_Frags,
			g_iVote_Mode,
			g_iVote_MinPlayers,
			g_iImmunity;
new String:	g_sScrambleNowFlag[5],
	String:	g_sAdminImmunityFlag[5];
	
/**
Other globals
*/
new 		g_iMaxEntities,
			g_iOwnerOffset;

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
			new String:sExtError[256];
			new iExtStatus = GetExtensionFileStatus("game.tf2.ext", sExtError, sizeof(sExtError));
			if (iExtStatus == -2)
			{
				LogAction(0, -1, "[SAS] TF2 extension was not found.");
				SetFailState("[SAS] Plugin failed to load.");
			}
			else if (iExtStatus == -1 || iExtStatus == 0)
			{
				LogAction(0, -1, "[SAS] TF2 extension is loaded with errors.");
				LogAction(0, -1, "[SAS] Status reported was [%s].", sExtError);
				SetFailState("[SAS] Plugin failed to load.");
			}
			else if (iExtStatus == 1)
			{
				LogAction(0, -1, "[SAS] TF2 extension is loaded and will be used.");
			}
		}
		case GameType_DOD:
		{
			HookEvent("dod_round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("dod_round_win", HookRoundEnd, EventHookMode_Post);
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
	CreateConVar("sas_version", PLUGIN_VERSION, "Simple AutoScrambler Version",FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	sas_enabled = CreateConVar("sas_enabled", "1", "Enable/Disable Simple AutoScrambler");
	sas_timer_scrambledelay = CreateConVar("sas_timer_scrambledelay", "5.0", "Delay used after a scramble has been started", _, true, 1.0, true, 30.0);
	
	/**
	Cvars used for admins
	*/
	sas_admin_immunity_enabled = CreateConVar("sas_admin_immunity_enabled", "1", "Enable/Disable admin immunity for scrambles");
	sas_admin_flag_scramblenow = CreateConVar("sas_admin_flag_scramblenow", "z", "Admin flag to use for scramblenow function/command");
	sas_admin_flag_immunity = CreateConVar("sas_admin_flag_immunity", "z", "Admin flag to use for scramble immunity");
	
	/**
	Cvars used for autoscramble
	*/
	sas_autoscramble_enabled = CreateConVar("sas_autoscramble_enabled", "1", "Enable/Disable the autoscramble function");
	sas_autoscramble_minplayers = CreateConVar("sas_autoscramble_minplayers", "16", "Min players needed to start an autoscramble");
	sas_autoscramble_mode = CreateConVar("sas_autoscramble_mode", "1", "Scramble mode used when autoscrambling");
	sas_autoscramble_winstreak = CreateConVar("sas_autoscramble_winstreak", "5", "Max amount of wins in a row a team can achieve before an autoscramble starts");
	sas_autoscramble_steamroll = CreateConVar("sas_autoscramble_steamroll", "120", "Shortest amount of time a team can win by before an autoscramble starts (seconds)");
	sas_autoscramble_frags = CreateConVar("sas_autoscramble_frags", "1", "Min players needed to start a vote and scramble");
	
	/**
	Cvars used for voting
	*/	
	sas_vote_enabled = CreateConVar("sas_vote_enabled", "1", "Enable/Disable voting for scramble");
	sas_vote_upcount = CreateConVar("sas_vote_upcount", "5", "Amount of people wanting a scramble before a vote starts.  If less than 1 it will be considered a percentage. (ie 0.5 = 50% | 1 = 1 Player | 5 = 5 Players)");
	sas_vote_winpercent = CreateConVar("sas_vote_winpercent", "0.6", "Percentage of votes needed to scramble", _, true, 0.0, true, 1.0);
	sas_vote_mode = CreateConVar("sas_vote_mode", "1", "Scramble mode used when a vote results in a scramble");
	sas_vote_minplayers = CreateConVar("sas_vote_minplayers", "16", "Min players needed to start a vote and scramble");
	
	/**
	Hook the console variables if they change
	*/
	HookConVarChange(sas_enabled, ConVarSettingsChanged);
	HookConVarChange(sas_timer_scrambledelay, ConVarSettingsChanged);
	HookConVarChange(sas_admin_immunity_enabled, ConVarSettingsChanged);
	HookConVarChange(sas_admin_flag_scramblenow, ConVarSettingsChanged);
	HookConVarChange(sas_admin_flag_immunity, ConVarSettingsChanged);
	HookConVarChange(sas_autoscramble_enabled, ConVarSettingsChanged);
	HookConVarChange(sas_autoscramble_minplayers, ConVarSettingsChanged);
	HookConVarChange(sas_autoscramble_mode, ConVarSettingsChanged);
	HookConVarChange(sas_autoscramble_winstreak, ConVarSettingsChanged);
	HookConVarChange(sas_autoscramble_steamroll, ConVarSettingsChanged);
	HookConVarChange(sas_autoscramble_frags, ConVarSettingsChanged);
	HookConVarChange(sas_vote_enabled, ConVarSettingsChanged);
	HookConVarChange(sas_vote_upcount, ConVarSettingsChanged);
	HookConVarChange(sas_vote_winpercent, ConVarSettingsChanged);
	HookConVarChange(sas_vote_mode, ConVarSettingsChanged);
	HookConVarChange(sas_vote_minplayers, ConVarSettingsChanged);
	
	/**
	Register the command
	*/
	RegConsoleCmd("sm_scramblenow", Command_ScrambleNow, "sm_scramblenow (mode): Scrambles the teams");
	
	/**
	Load translations and .cfg file
	*/
	LoadTranslations ("simpleautoscrambler.phrases");
	AutoExecConfig(true, "plugin.simpleautoscrambler");
	LogAction(0, -1, "[SAS] Simple AutoScrambler is loaded.");
}

public OnAllPluginsLoaded()
{
	/*
	Check for SDK Tools
	*/
	new String:sExtError[256];
	new iExtStatus = GetExtensionFileStatus("sdkhooks.ext", sExtError, sizeof(sExtError));
	if (iExtStatus == -2)
	{
		LogAction(0, -1, "[SSPEC] SDK Hooks extension was not found.");
		LogAction(0, -1, "[SSPEC] Plugin continued to load, but that feature will not be used.");
		g_aPluginSettings[bUseSDKHooks] = false;
	}
	else if (iExtStatus == -1 || iExtStatus == 0)
	{
		LogAction(0, -1, "[SSPEC] SDK Hooks extension is loaded with errors.");
		LogAction(0, -1, "[SSPEC] Status reported was [%s].", sExtError);
		LogAction(0, -1, "[SSPEC] Plugin continued to load, but that feature will not be used.");
		g_aPluginSettings[bUseSDKHooks] = false;
	}
	else if (iExtStatus == 1)
	{
		LogAction(0, -1, "[SSPEC] SDK Hooks extension is loaded and will be used.");
		g_aPluginSettings[bUseSDKHooks] = true;
	}
}

public OnLibraryRemoved(const String:name[])
{
	//something
}

public OnConfigsExecuted()
{
	
	/**
	Load up all the variable defaults
	*/
	LoadUpVariables();
	
	/**
	Log our activity
	*/
	if (g_bIsEnabled)
		LogAction(0, -1, "Simple AutoScrambler is ENABLED");
	else
		LogAction(0, -1, "Simple AutoScrambler is DISABLED");
}

public Action:Command_ScrambleNow(client, args)
{

	/**
	Make sure we are enabled
	*/
	if (!g_bIsEnabled)
	{
		return Plugin_Handled;
	}
	
	/**
	Make sure the client is authorized to run this command.
	*/
	if (!SM_IsValidAdmin(client, g_sScrambleNowFlag))
	{
		ReplyToCommand(client, "\x01\x04[SM]\x01 %T", "RestrictedCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	
	/**
	Make sure it's ok to scramble at this time
	*/
	if (!OkToScramble)
	{
		return Plugin_Handled;
	}
	
	/**
	Make sure it's ok to scramble at this time
	*/
	LogAction(0, -1, "[SAS] The scramblenow command was used");
	
	/**
	Scramble the teams
	*/
	StartAScramble();
	
	/**
	We are done, bug out.
	*/
	return Plugin_Handled;
}

public HookRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	
}

public HookRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	
}

public Action:HookPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bScrambling)
		return Plugin_Handled;
	switch (g_CurrentMod)
	{
		case TF2:
		{
			if (GetEventInt(event, "death_flags") & 32) 
				return Plugin_Handled;
		}
	}
	
}

public Action:Timer_ScrambleTeams(Handle:timer, any:mode)
{
	
	/**
	Make sure it's still ok to scramble
	*/
	if (!OkToScramble)
	{
		return Plugin_Handled;
	}
	
	g_bScrambling = true;
	
	switch (mode)
	{
		case 
	
	
	
	}


	/**
	Reset the handle because the timer is over and the callback is done
	*/
	g_hScrambleTimer = INVALID_HANDLE;
	
	/**
	We are done, bug out.
	*/
	g_bScrambling = false;
	return Plugin_Handled;
}

public ConVarSettingsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{

}

stock StartAScramble(mode)
{
	
	/**
	See if we are already started a scramble
	*/
	if (g_hScrambleTimer == INVALID_HANDLE)
	{
		
		/**
		There is a scramble in progress
		*/
		return;

	}
	
	/**
	Report that a scramble is about to start
	*/
	PrintCenterTextAll("%T", "Scramble", LANG_SERVER);
	
	/**
	Start a timer and log the action
	*/
	g_hScrambleTimer = CreateTimer(g_fTimer_ScrambleDelay, Timer_ScrambleTeams, mode, TIMER_FLAG_NO_MAPCHANGE);
	LogAction(0, -1, "[SAS] A scamble timer was started");
}

stock bool:OkToScramble()
{

}

stock LoadUpVariables()
{
	g_bIsEnabled = GetConVarBool(sas_enabled);
	g_bIsAutoScrambleEnabled = GetConVarBool(sas_autoscramble_enabled);
	g_bIsVoteEnabled = GetConVarBool(sas_vote_enabled);
	g_bIsAdminImmunityEnabled = GetConVarBool(sas_admin_immunity_enabled);
	g_iAutoScramble_Minplayers = GetConVarInt(sas_autoscramble_minplayers);
	g_iAutoScramble_Mode = GetConVarInt(sas_autoscramble_mode);
	g_iAutoScramble_WinStreak = GetConVarInt(sas_autoscramble_winstreak);
	g_iAutoScramble_SteamRoll = GetConVarInt(sas_autoscramble_steamroll);
	g_iAutoScramble_Frags = GetConVarInt(sas_autoscramble_frags);
	g_iVote_Mode = GetConVarInt(sas_vote_mode);
	g_iVote_MinPlayers = GetConVarInt(sas_vote_minplayers);
	GetConVarString(sas_admin_flag_scramblenow, g_sScrambleNowFlag, sizeof(g_sScrambleNowFlag));
	GetConVarString(sas_admin_flag_immunity, g_sAdminImmunityFlag, sizeof(g_sAdminImmunityFlag));
	g_fTimer_ScrambleDelay = GetConVarFloat(sas_timer_scrambledelay);
	g_fVote_UpCount = GetConVarFloat(sas_vote_upcount);
	g_fVote_WinPercent = GetConVarFloat(sas_vote_winpercent);
	g_iMaxEntities = GetMaxEntities();
	g_iOwnerOffset = FindSendPropInfo("CBaseObject", "m_hBuilder");
}