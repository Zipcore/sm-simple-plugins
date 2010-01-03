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

#include "simple-plugins/sas_config_access.sp"

#define PLUGIN_VERSION "0.1.$Rev$"

/**
#define ADMIN_IMMUNE			(1<<0)
#define MEDIC_IMMUNE			(1<<1)
#define ENGINEER_IMMUNE	(1<<2)
#define BUDDY_IMMUNE			(1<<3)
#define TEAMWORK_IMMUNE	(1<<4)
*/

/**
Round States
PREROUND 	=	Players cannot hurt eachother, or their frags aren't counted
NORMAL		= 	Players are scoring points normally
BONUS		=	A team has won, and we're waiting for next round... Team is slaughtering the defenseless other team
#define PREROUND 0
#define NORMAL 1
#define BONUS 2
*/

enum e_RoundState
{
	Round_Pre,
	Round_Normal,
	Round_Bonus
};

/**
Different scramble modes:
1	=	Full Scramble, dont restart round.
2	=	Admins Immune, dont restart round.
3	=	Full Scramble, restart round and reset scores.
4	=	Admins Immune, restart round and reset scores.

Different top player modes:
1	=	Divide Top 4 players on the two teams.
2	=	Protect the Top 2 players on each team.
*/

enum e_PlayerData
{
	Handle:hForcedTimer,
	bool:bProtected,
	iFrags,
	iDeaths;
};

enum e_ScrambleMode
{
	Mode_Random,
	Mode_TopSwap,
	Mode_MiddleSwap,
	Mode_Scores,
	Mode_Frags,
	Mode_KillRatios
};

enum e_RoundData
{
	e_RoundState:Round_State,
	Round_StartTime,
	Round_ScrambleTriggers
};

/**
Timers
*/
new Handle:g_hScrambleTimer	 = INVALID_HANDLE;

/**
Arrays 
 */
new g_aPlayers[MAXPLAYERS + 1][e_PlayerData];
new g_aRoundInfo[e_RoundData];

/**
 Other globals
 */
new bool:g_bScrambling = false;

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
			g_iOwnerOffset = FindSendPropInfo("CBaseObject", "m_hBuilder");
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
	CreateConVar("sas_version", PLUGIN_VERSION, "Simple AutoScrambler Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	/**
	Register the commands
	*/
	RegConsoleCmd("sm_scramblenow", Command_Scramble, "sm_scramblenow <mode>: Scrambles the teams");
	RegConsoleCmd("sm_resetscores", Command_ResetScores, "sm_resetscores: Resets the players scores");
	RegConsoleCmd("sm_scramblesetting", Command_SetSetting, "sm_scramblesetting <setting> <value>: Set a setting");
	RegConsoleCmd("sm_scramblereload", Command_Reload, "sm_scramblereload: Reloads the config file");
	
	new String:sBuffer, String:sVoteCommand[64];
	GetTrieString(g_hSettings, "vote_trigger", sBuffer, sizeof(sBuffer));
	Format(sVoteCommand, sizeof(sVoteCommand), "sm_%s", sBuffer);
	RegConsoleCmd(sVoteCommand, Command_ScrambleNow, "Command used to start a vote to scramble the teams");
	
	/**
	Load translations and .cfg file
	*/
	LoadTranslations ("simpleautoscrambler.phrases");
	LogAction(0, -1, "[SAS] Simple AutoScrambler is loaded.");
}

public OnAllPluginsLoaded()
{
	//something
}

public OnLibraryRemoved(const String:name[])
{
	//something
}

public OnConfigsExecuted()
{
	
	/**
	Log our activity
	*/
	if (GetSettingValue("enabled"))
		LogAction(0, -1, "Simple AutoScrambler is ENABLED");
	else
		LogAction(0, -1, "Simple AutoScrambler is DISABLED");
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
	if (!OkToScramble)
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
	Log some activity
	TODO: Add ShowActivity and maybe do this at the end of the scramble, add client, and more info
	*/
	LogAction(0, -1, "[SAS] The scores were reset");
	
	/**
	TODO: Actually reset the scores
	*/
	
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
		ReplyToCommand(client, "\x01\x04[SM]\x01 %T", "RestrictedCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	
	/**
	Log some activity
	TODO: Add ShowActivity and maybe do this at the end of the scramble, add client, and more info
	*/
	LogAction(0, -1, "[SAS] A setting was set");
	
	/**
	TODO: Actually set the setting in the trie
	*/
	
	/**
	We are done, bug out.
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
	Log some activity
	TODO: Add ShowActivity and maybe do this at the end of the scramble, add client, and more info
	*/
	LogAction(0, -1, "[SAS] The config file was reloaded");
	
	/**
	Process the config file
	*/
	ProcessConfigFile();
	
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
			if (TF2_InSetup)
			{
				g_aRoundInfo[Round_State] = Round_Pre;
				//TODO: Start a timer to change the round state to normal
			}
			else
			{
				g_aRoundInfo[Round_State] = Round_Normal;
			}
		}
	}
}

public HookRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	switch (g_CurrentMod)
	{
		case GameType_TF:
		{
			g_aRoundInfo[Round_State] = Round_Bonus;
		}
	}
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
				return Plugin_Continue;
		}
	}
	g_aPlayers[GetClientOfUserId(GetEventInt(event, "attacker"))][iFrags]++;
	g_aPlayers[GetClientOfUserId(GetEventInt(event, "victim"))][iDeaths]++;
	
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

GetClientScore(client)
{
	switch (g_CurrentMod)
	{
		case GameType_TF:
			return TF2_GetClientScore(client);
		case GameType_DOD:
			// something
		default:
			return g_aPlayers[client][iFrags];
}