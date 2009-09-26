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
This file is part of Simple SourceMod Plugins project.

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
$Copyright: (c) Simple SourceMod Plugins 2008-2009$
*************************************************************************
*************************************************************************
*/

#include <simple-plugins>
#include <sdktools>

#define PLUGIN_VERSION "2.1.$Rev$"

enum PlayerData
{
	Handle:hBalanceTimer,
	Handle:hForcedTimer,
	bool:bSwitched,
	bool:bFlagCarrier
};

/**
 Global convar handles 
 */
new Handle:stb_enabled = INVALID_HANDLE;
new Handle:stb_buddyenabled = INVALID_HANDLE;
new Handle:stb_logactivity = INVALID_HANDLE;
new Handle:stb_logactivity2 = INVALID_HANDLE;
new Handle:stb_unbalancelimit = INVALID_HANDLE;
new Handle:stb_deadonly = INVALID_HANDLE;
new Handle:stb_priorityenabled = INVALID_HANDLE;
new Handle:stb_uberlevel = INVALID_HANDLE;
new Handle:stb_balancedelay = INVALID_HANDLE;
new Handle:stb_livingplayerswitchdelay = INVALID_HANDLE;
new Handle:stb_livingplayercheckdelay = INVALID_HANDLE;
new Handle:stb_roundstartdelay = INVALID_HANDLE;
new Handle:stb_switchbackforced = INVALID_HANDLE;
new Handle:stb_adminflag = INVALID_HANDLE;
new Handle:stb_buddyrestriction = INVALID_HANDLE;
new Handle:stb_convarcontrol = INVALID_HANDLE;

/**
 Built-in cvars handles 
 */
new Handle:stb_mp_autoteambalance = INVALID_HANDLE;
new Handle:stb_mp_teams_unbalance_limit = INVALID_HANDLE;
new Handle:TFGameModeArena = INVALID_HANDLE;

/**
 Timer handles 
 */
new Handle:g_hBalanceTimer = INVALID_HANDLE;
new Handle:g_hLivingPlayerCheckTimer = INVALID_HANDLE;

/**
 Player arrays 
 */
new g_aPlayers[MAXPLAYERS + 1][PlayerData];

/**
Global bools 
*/
new bool:g_bIsEnabled = true;
new bool:g_bPriorityPlayers = true;
new bool:g_bBuddyRestriction = false;
new bool:g_bLogActivity = false;
new bool:g_bLogActivity2 = false;
new bool:g_bDeadOnly = false;
new bool:g_bConVarControl = true;
new bool:g_bBuddyEnabled = true;
new bool:g_bBalanceInProgress = false;
new bool:g_bRoundStart = false;
new bool:g_bRoundEnd = false;
new bool:g_bSuddenDeath = false;
new bool:g_bIsArenaMode = false;

/**
 Global strings/integers/floats 
 */
new g_iUnbalanceLimit, g_iLivingPlayerSwitchDelay, g_iLivingPlayerCheckDelay;
new g_iRoundStartDelay, g_iSwitchBackForced, g_iBalanceDelay;
new Float:g_fUberLevel;
new g_iOwnerOffset;
new String:g_sAdminFlag[5];

public Plugin:myinfo =
{
	name = "Simple Team Balancer",
	author = "Simple SourceMod Plugins",
	description = "Balances teams based upon player count.",
	version = PLUGIN_VERSION,
	url = "http://projects.mygsn.net"
}

public OnPluginStart()
{
	
	/**
	Create console variables
	*/
	CreateConVar("stb_version", PLUGIN_VERSION, "Simple Team Balancer", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	stb_enabled = CreateConVar("stb_enabled", "1", "Enable or Disable Simple Team Balancer", _, true, 0.0, true, 1.0);
	stb_priorityenabled = CreateConVar("stb_priorityenabled", "1", "Enable or Disable the prioritization of living players", _, true, 0.0, true, 1.0);
	stb_buddyrestriction = CreateConVar("stb_buddyrestriction", "0", "Enable or Disable Admin Only buddy lists", _, true, 0.0, true, 1.0);
	stb_logactivity = CreateConVar("stb_logactivity", "0", "Enable or Disable the disaplying of events in the log", _, true, 0.0, true, 1.0);
	stb_logactivity2 = CreateConVar("stb_logactivity2", "0", "Enable or Disable the disaplying of detailed events in the log (WILL SPAM LOG)", _, true, 0.0, true, 1.0);
	stb_deadonly = CreateConVar("stb_deadonly", "0", "Enable or Disable the switching of only dead players", _, true, 0.0, true, 1.0);
	stb_convarcontrol = CreateConVar("stb_convarcontrol", "1", "Enable or Disable the control of builtin console variables", _, true, 0.0, true, 1.0);
	stb_buddyenabled = CreateConVar("stb_buddyenabled", "1", "Enable or Disable the buddy system", _, true, 0.0, true, 1.0);	
	stb_unbalancelimit = CreateConVar("stb_unbalancelimit", "2", "Amount of players teams are ALLOWED to be unbalanced by", _, true, 1.0, true, 32.0);
	stb_balancedelay = CreateConVar("stb_balancedelay", "10", "Delay in seconds to start an autobalance");
	stb_livingplayerswitchdelay = CreateConVar("stb_livingplayerswitchdelay", "20", "Delay in seconds to switch living players once selected");
	stb_livingplayercheckdelay = CreateConVar("stb_livingplayercheckdelay", "10", "Delay in seconds to start checking living players once teams become unbalanced");
	stb_roundstartdelay = CreateConVar("stb_roundstartdelay", "15", "Delay in seconds to start balancing teams after the start of a round");
	stb_switchbackforced = CreateConVar("stb_switchbackforced", "300", "Amount of time in seconds to not switch a player twice and force the team if enabled");
	stb_uberlevel = CreateConVar("stb_uberlevel", "1.0", "Min uber level medic must have to have priority over other living players. Setting to 0 will rarely switch a living medic", _, true, 0.0, true, 1.0);
	stb_adminflag = CreateConVar("stb_adminflag", "a", "Admin flag to use for immunity.  Must be a in char format.");
	stb_mp_autoteambalance = FindConVar("mp_autoteambalance");
	stb_mp_teams_unbalance_limit = FindConVar("mp_teams_unbalance_limit");
	
	/**
	Removing the notify tags from the built in cvars.  We dont want spam.
	*/
	if (stb_mp_autoteambalance != INVALID_HANDLE)
	{
		SetConVarFlags(stb_mp_autoteambalance, GetConVarFlags(stb_mp_autoteambalance)^FCVAR_NOTIFY);
	}
	if (stb_mp_teams_unbalance_limit != INVALID_HANDLE)
	{
		SetConVarFlags(stb_mp_teams_unbalance_limit, GetConVarFlags(stb_mp_teams_unbalance_limit)^FCVAR_NOTIFY);
	}
	
	/**
	Hook console variables
	*/
	HookConVarChange(stb_enabled, ConVarSettingsChanged);
	HookConVarChange(stb_priorityenabled, ConVarSettingsChanged);
	HookConVarChange(stb_buddyrestriction, ConVarSettingsChanged);
	HookConVarChange(stb_logactivity, ConVarSettingsChanged);
	HookConVarChange(stb_logactivity2, ConVarSettingsChanged);
	HookConVarChange(stb_deadonly, ConVarSettingsChanged);
	HookConVarChange(stb_convarcontrol, ConVarSettingsChanged);
	HookConVarChange(stb_buddyenabled, ConVarSettingsChanged);
	HookConVarChange(stb_unbalancelimit, ConVarSettingsChanged);
	HookConVarChange(stb_balancedelay, ConVarSettingsChanged);
	HookConVarChange(stb_livingplayerswitchdelay, ConVarSettingsChanged);
	HookConVarChange(stb_livingplayercheckdelay, ConVarSettingsChanged);
	HookConVarChange(stb_roundstartdelay, ConVarSettingsChanged);
	HookConVarChange(stb_switchbackforced, ConVarSettingsChanged);
	HookConVarChange(stb_uberlevel, ConVarSettingsChanged);
	HookConVarChange(stb_mp_autoteambalance, ConVarSettingsChanged);
	HookConVarChange(stb_mp_teams_unbalance_limit, ConVarSettingsChanged);
	
	/**
	Create console commands
	*/
	RegConsoleCmd("sm_buddy", Command_AddBalanceBuddy, "Add a balance buddy");
	RegConsoleCmd("sm_lockbuddy", Command_LockBuddy, "Locks your balance buddy selection");

	/**
	Get game type and load the team numbers
	*/
	g_CurrentMod = GetCurrentMod();
	LoadCurrentTeams();
	
	/**
	Hook the game events
	*/
	LogAction(0, -1, "[STB] Hooking events for [%s].", g_sGameName[g_CurrentMod]);
	HookEvent("player_death", HookPlayerDeath, EventHookMode_Post);
	HookEvent("player_team", HookPlayerChangeTeam, EventHookMode_Post);
	switch (g_CurrentMod)
	{
		case GameType_TF:
		{
			HookEvent("teamplay_round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("teamplay_round_win", HookRoundEnd, EventHookMode_Post);
			HookEvent("teamplay_suddendeath_begin", HookSuddenDeathBegin, EventHookMode_PostNoCopy);
			HookEvent("teamplay_flag_event", HookFlagEvent, EventHookMode_Post);
			TFGameModeArena = FindConVar("tf_gamemode_arena");
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
			HookEvent("round_end", HookRoundEnd, EventHookMode_PostNoCopy);
		}
	}

	/**
	Load translations and .cfg file
	*/
	LoadTranslations ("simpleteambalancer.phrases");
	AutoExecConfig(true, "plugin.simpleteambalancer");
	LogAction(0, -1, "[STB] Simple Team Balancer is loaded.");
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
	Load up global variables 
	*/
	g_bIsEnabled = GetConVarBool(stb_enabled);
	g_bBuddyEnabled = GetConVarBool(stb_buddyenabled);
	g_bLogActivity = GetConVarBool(stb_logactivity);
	g_bLogActivity2 = GetConVarBool(stb_logactivity2);
	g_bDeadOnly = GetConVarBool(stb_deadonly);
	g_bPriorityPlayers = GetConVarBool(stb_priorityenabled);
	g_bBuddyRestriction = GetConVarBool(stb_buddyrestriction);
	g_bConVarControl = GetConVarBool(stb_convarcontrol);
	g_fUberLevel = GetConVarFloat(stb_uberlevel);
	g_iUnbalanceLimit = GetConVarInt(stb_unbalancelimit);
	g_iBalanceDelay = GetConVarInt(stb_balancedelay);
	g_iLivingPlayerSwitchDelay = GetConVarInt(stb_livingplayerswitchdelay);
	g_iLivingPlayerCheckDelay = GetConVarInt(stb_livingplayercheckdelay);
	g_iRoundStartDelay = GetConVarInt(stb_roundstartdelay);
	g_iSwitchBackForced = GetConVarInt(stb_switchbackforced);
	GetConVarString(stb_adminflag, g_sAdminFlag, sizeof(g_sAdminFlag));
	
	/**
	Report enabled
	*/
	if (g_bIsEnabled)
	{
		LogAction(0, -1, "[STB] Simple Team Balancer is ENABLED.");
	}
	else
	{
		LogAction(0, -1, "[STB] Simple Team Balancer is DISABLED.");
	}	
	
	
	/**
	Report log activity 
	*/
	if (g_bLogActivity)
	{
		LogAction(0, -1, "[STB] Log Activity ENABLED.");
	}
	else
	{
		LogAction(0, -1, "[STB] Log Activity DISABLED.");
	}
	if (g_bLogActivity2)
	{
		LogAction(0, -1, "[STB] Detailed Log Activity ENABLED.");
	}
	else
	{
		LogAction(0, -1, "[STB] Detailed Log Activity DISABLED.");
	}	
}

public OnMapStart()
{

	/**
	Check for arena mode 
	*/
	if (g_CurrentMod == GameType_TF && GetConVarBool(TFGameModeArena))
	{
		g_bIsArenaMode = true;
		if (g_bLogActivity)
		{
			LogAction(0, -1, "[STB] Simple Team Balancer detected arena mode and will be bypassed");
		}
	}
	else
	{
		g_bIsArenaMode = false;
	}
	
	/**
	Reset the globals
	*/
	g_bBalanceInProgress = false;
	g_bRoundStart = false;
	g_bRoundEnd = false;
	g_bSuddenDeath = false;
	
	/**
	Set the built-in convars
	*/
	SetGameCvars();
}

public OnClientPostAdminCheck(client)
{
	
	/**
	Make sure its a valid connected client and buddy system is enabled 
	*/
	if (client == 0 || !g_bIsEnabled || !IsClientConnected(client) || !g_bBuddyEnabled)
	{
		return;
	}
	
	/**
	Make sure if its set for admins only they have the flags 
	*/
	if (g_bBuddyRestriction && !SM_IsValidAdmin(client, g_sAdminFlag))
	{
		return;
	}
	
	/**
	Start the advertisement timer 
	*/
	CreateTimer (60.0, Timer_WelcomeAdvert, client);
}

public OnClientDisconnect(client)
{

	/**
	Call stock function to cleaup 
	*/
	CleanUp(client);
}

public OnClientDisconnect_Post(client)
{
	
	/**
	Determine if we need a balance 
	*/
	if (OkToBalance() && IsUnbalanced() && !g_bBalanceInProgress)
	{
		
		/**
		No balance in progress but balance is needed 
		*/
		StartABalance();
	}
}

public SM_OnPlayerMoved(Handle:plugin, client, team)
{
	
	/**
	Make sure we called the move function
	*/
	if (plugin != GetMyHandle())
	{
		if (g_bLogActivity2)
		{
			LogAction(0, client, "[STB] Callback was not started with current plugin, bugging out.");
		}
		return;
	}
	
	/**
	Get the players name and report the event
	*/
	decl String:sPlayerName[64];
	GetClientName(client, sPlayerName, sizeof(sPlayerName));
	if (g_bLogActivity)
	{
		LogAction(0, client, "[STB] Changed %s to team %i.", sPlayerName, team);
	}

	/**
	If we are in TF2 fire the bult-in team balance event
	*/
	if(g_CurrentMod == GameType_TF)
	{
		new Handle:event = CreateEvent("teamplay_teambalanced_player");
		SetEventInt(event, "player", client);
		SetEventInt(event, "team", team);
		FireEvent(event);
	}
		
	/**
	Notify the players
	*/
	PrintToChatAll("[SM] %T", "BalanceMessage", LANG_SERVER, sPlayerName);
	
	/**
	Set the players variables and start a timer
	*/
	g_aPlayers[client][bSwitched] = true;
	g_aPlayers[client][hForcedTimer] = CreateTimer(float(g_iSwitchBackForced), Timer_ForcedExpired, client, TIMER_FLAG_NO_MAPCHANGE);
	
	/**
	We are done, log the completion and end the balance
	*/
	if (g_bLogActivity)
	{
		LogAction(0, client, "[STB] Balance finished.");
	}
	g_bBalanceInProgress = false;
}

/* HOOKED EVENTS */

public HookPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	/**
	Get our event variables
	*/
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:sWeapon[64];
	GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
	
	/**
	Return if death was not caused by a player
	This is the case when the player switches teams
	*/
	if (StrEqual(sWeapon, "world", false))
	{
		return;
	}
	
	
	/**
	Check if balance is needed 
	*/
	if (IsClientInGame(iClient) && OkToBalance() && IsUnbalanced())
	{
		new iSmallerTeam = GetSmallerTeam();

		/**
		Check if balance is in progress 
		*/
		if (g_bBalanceInProgress)
		{
		
			/**
			There is a balance in progress
			Check the player who died to see if he is supposed to be switched
			*/
			if (g_aPlayers[iClient][hBalanceTimer] != INVALID_HANDLE)
			{
			
				/**
				The player has a timer on him to switch him to other team
				Stop the timer
				*/
				CloseHandle(g_aPlayers[iClient][hBalanceTimer]);
				g_aPlayers[iClient][hBalanceTimer] = INVALID_HANDLE;
				if (g_bLogActivity)
				{
					LogAction(0, iClient, "[STB] With a balance in progress the queued living player died and was switched.");
				}

				/**
				Call the stock change team function 
				*/
				BalancePlayer(iClient, SM_GetForcedTeam(iClient));
				return;
			}
			
			/**
			Before we continue, lets make sure the client is switchable
			*/
			if (IsSwitchablePlayer(iClient, GetBiggerTeam()))
			{
			
				/**
				Now we check the buddy system
				*/
				if (g_bBuddyEnabled)
				{
			
					/**
					Buddy system is enabled, check to see if client has buddy
					*/
					new iBuddyIndex = SM_GetClientBuddy(iClient);
					if (iBuddyIndex != 0)
					{
				
						/**
						The client has a buddy, so we check to see if they are on same team
						*/
						if (GetClientTeam(iClient) == GetClientTeam(iBuddyIndex))
						{
				
							/**
							They are, but we don't bug out, we still need to start a balance
							*/
							if (g_bLogActivity2)
							{
								LogAction(0, -1, "[STB] With a balance in progress a buddy on the right team was found and skipped.");
							}
						}
						else
						{
							
							/**
							They are not on the same team
							The buddy could be in spec, and that would make it not matter where he is, or the buddy is on the smaller team
							*/
							if (g_bLogActivity2)
							{
								LogAction(0, -1, "[STB] With a balance in progress a buddy on the wrong team was switched.");
							}
							BalancePlayer(iClient, iSmallerTeam);
							return;
						}
					}
					else
					{
					
						/**
						Client doesn't have a buddy, balance this player
						*/
						BalancePlayer(iClient, iSmallerTeam);
						return;
					}
				}
				else
				{

					/**
					Buddy system is not enabled, balance this player
					*/
					BalancePlayer(iClient, iSmallerTeam);
					return;
				}
			}
		}
		else
		{
		
			/**
			If we get to here then we must need to start a balance
			*/
			StartABalance();
		}
	}
}

public HookPlayerChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{

	/**
	Get our event variables.
	*/
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new iTeam = GetEventInt(event, "team");
	
	/**
	Make sure its ok to balance.
	*/
	if (OkToBalance()) 
	{

		/**
		See if the client that changed teams was set to with a balance.
		*/
		if (g_aPlayers[iClient][hBalanceTimer] != INVALID_HANDLE
		&& SM_GetForcedTeam(iClient) == iTeam
		&& g_bBalanceInProgress) 
		{

			/**
			The client was set to be balanced, so we close the timer.
			*/
			CloseHandle(g_aPlayers[iClient][hBalanceTimer]);
			g_aPlayers[iClient][hBalanceTimer] = INVALID_HANDLE;
			
			/**
			Stop the balance.
			*/
			g_bBalanceInProgress = false;
			return;
		}
		
		/**
		It's not likely that this team change can cause us to need a balance.
		If it does, start one with a small dealy to deal with forced switch backs.
		*/
		if (IsUnbalanced() && !g_bBalanceInProgress) 
		{
			CreateTimer(2.0, Timer_ChangeTeamBalanceDelay, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public HookRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{

	/**
	Set the variables we need to start a round
	*/
	g_bRoundStart = true;
	g_bRoundEnd = false;
	g_bSuddenDeath = false;
	if (g_bLogActivity)
	{
		LogAction(0, -1, "[STB] Round Started");
	}
	
	/**
	Start a delayed balance check at the start of the round
	*/
	CreateTimer(float(g_iRoundStartDelay), Timer_RoundStart);
}

public HookRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{

	/**
	Set the variables we need at round end
	*/
	g_bRoundEnd = true;
	if (g_bLogActivity)
	{
		LogAction(0, -1, "[STB] Round Ended");
	}
}

public HookSuddenDeathBegin(Handle:event, const String:name[], bool:dontBroadcast)
{

	/**
	Set the variables we need for sudden death
	*/
	g_bSuddenDeath = true;
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
	if (!IsClientInGame(iClient))
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

/* COMMAND EVENTS */

public Action:Command_AddBalanceBuddy(client, args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] %T", "PlayerLevelCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	if (!g_bIsEnabled || !g_bBuddyEnabled) 
	{
		ReplyToCommand(client, "[SM] %T", "CmdDisabled", LANG_SERVER);
		return Plugin_Handled;
	}
	if (g_bBuddyRestriction) 
	{
		if (!SM_IsValidAdmin(client, g_sAdminFlag)) 
		{
			ReplyToCommand(client, "[SM] %T", "RestrictedBuddy", LANG_SERVER);
			return Plugin_Handled;
		}
	}
	decl String:sPlayerUserId[24];
	GetCmdArg(1, sPlayerUserId, sizeof(sPlayerUserId));
	new iPlayer = GetClientOfUserId(StringToInt(sPlayerUserId));
	if (!iPlayer || !IsClientInGame(iPlayer) || client == iPlayer) 
	{
		if (client == iPlayer) 
		{
			PrintHintText(client, "%T", "SelectSelf", LANG_SERVER);
		}
		ReplyToCommand(client, "[SM] Usage: buddy <userid>");
		new Handle:playermenu = BuildPlayerMenu();
		DisplayMenu(playermenu, client, MENU_TIME_FOREVER);	
	} 
	else 
	{
		decl String:cName[128];
		decl String:bName[128];
		GetClientName(client, cName, sizeof(cName));
		GetClientName(iPlayer, bName, sizeof(bName));
		if (SM_IsBuddyLocked(iPlayer)) 
		{
			ReplyToCommand(client, "[SM] %T", "PlayerLockedBuddyMsg", LANG_SERVER, bName);
			return Plugin_Handled;
		}
		SM_AssignBuddy(client, iPlayer);
		PrintHintText(client, "%T", "BuddyMsg", LANG_SERVER, bName);
		PrintHintText(iPlayer, "%T", "BuddyMsg", LANG_SERVER, cName);
	}
	return Plugin_Handled;	
}

public Action:Command_LockBuddy(client, args)
{
	if (client == 0) 
	{
		ReplyToCommand(client, "[SM] %T", "PlayerLevelCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	if (!g_bIsEnabled) 
	{
		ReplyToCommand(client, "[SM] %T", "CmdDisabled", LANG_SERVER);
		return Plugin_Handled;
	}
	if (g_bBuddyRestriction)
	{
		if (!SM_IsValidAdmin(client, g_sAdminFlag)) 
		{
			ReplyToCommand(client, "[SM] %T", "RestrictedBuddy", LANG_SERVER);
			return Plugin_Handled;
		}
	}
	if (SM_IsBuddyLocked(client)) 
	{
		SM_LockBuddy(client, false);
		PrintHintText(client, "%T", "BuddyLockMsgDisabled", LANG_SERVER);
	} 
	else 
	{
		SM_LockBuddy(client, true);
		PrintHintText(client, "%T", "BuddyLockMsgEnabled", LANG_SERVER);
	}
	return Plugin_Handled;
}

/**
Stock functions .
 */

stock bool:IsUnbalanced()
{
	if (g_bLogActivity2)
	{
		LogAction(0, -1, "[STB] Checking if teams are unbalanced");
	}
	new Team1Count = GetTeamClientCount(g_aCurrentTeams[Team1]);
	new Team2Count = GetTeamClientCount(g_aCurrentTeams[Team2]);
	new ubCount = RoundFloat(FloatAbs(float(Team1Count - Team2Count)));
	if (g_bLogActivity2)
	{
		LogAction(0, -1, "[STB] Team1:%i Team2:%i Difference:%i", Team1Count, Team2Count, ubCount);
	}
	if (ubCount > g_iUnbalanceLimit)
	{
		if (g_bLogActivity2)
		{
			LogAction(0, -1, "[STB] Teams are unbalanced");
		}
		return true;
	}
	if (g_bLogActivity2)
	{
		LogAction(0, -1, "[STB] Teams are not unbalanced");
	}
	return false;
}

stock bool:OkToBalance()
{
	if (g_bLogActivity2) 
	{
		LogAction(0, -1, "[STB] Checking if OK to balance.");
	}
	new bool:bResult = false;
	if (g_bIsEnabled && !g_bRoundStart && !g_bRoundEnd && !g_bIsArenaMode && !g_bSuddenDeath)
	{
		if (g_bLogActivity2) 
		{
			LogAction(0, -1, "[STB] Passed IF statement");
			LogAction(0, -1, "[STB] Now checking admins");
		}
		for (new i = 1; i <= MaxClients; i++) 
		{
			if (IsClientInGame(i) && !SM_IsValidAdmin(i, g_sAdminFlag)) 
			{
				if (g_bLogActivity2) 
				{
					LogAction(0, -1, "[STB] Found at least 1 non-admin");
					LogAction(0, -1, "[STB] OK to balance");
				}
				bResult = true;
				break;
			}
		}
		if (!bResult && g_bLogActivity2)
		{
			LogAction(0, -1, "[STB] All admins online");
		}
	}
	if (!bResult && g_bLogActivity2)
	{
		LogAction(0, -1, "[STB] Not OK to balance");
	}
	return bResult;
}

stock bool:IsSwitchablePlayer(iClient, iBiggerTeam)
{

	/**
	Run the client thru some standard checks
	*/
	if (!IsClientInGame(iClient)
		|| SM_IsValidAdmin(iClient, g_sAdminFlag)
		|| g_aPlayers[iClient][bFlagCarrier]
		|| GetClientTeam(iClient) != iBiggerTeam
		|| g_aPlayers[iClient][bSwitched])
	{
		
		/**
		The supplied client can't be switched
		*/
		return false;
	}
	
	/**
	The supplied client can be switched
	*/
	return true;
}

stock bool:HasUber(iClient)
{

	/**
	First things first, make sure the client is a medic
	*/
	if(TF2_GetPlayerClass(iClient) == TFClass_Medic)
	{
		
		/**
		We can only check the active weapon, so make sure the client is holding the uber gun
		*/
		decl String:sWeaponName[32];
		GetClientWeapon(iClient, sWeaponName, sizeof(sWeaponName));
		if(StrEqual(sWeaponName, "tf_weapon_medigun"))
		{
			
			/**
			They are, so lets check the uber level of the gun
			*/
			new iEntityIndex = GetEntDataEnt2(iClient, FindSendPropInfo("CTFPlayer", "m_hActiveWeapon"));
			new Float:fChargeLevel = GetEntDataFloat(iEntityIndex, FindSendPropInfo("CWeaponMedigun", "m_flChargeLevel"));
			if (fChargeLevel >= g_fUberLevel)
			{
			
				/**
				The client supplied has an uber above the supplied level, return true
				*/
				if (g_bLogActivity2)
				{
					LogAction(0, iClient, "[STB] Found a medic with a uber and skipped him.");
				}
				return true;
			}
		}
	}
	
	/**
	The client supplied does not have an uber above the supplied level, return false
	*/
	return false;
}

stock bool:HasBuildingsBuilt(iClient)
{

	/**
	We have to start a loop to check the owner of all the valid entities
	*/
	new iMaxEntities = GetMaxEntities();
	for (new i = MaxClients + 1; i <= iMaxEntities; i++)
	{
		if (!IsValidEntity(i))
		{
		
			/**
			Not valid, continue to next one
			*/
			continue;
		}
		
		/**
		Get the name of the current entity
		*/
		decl String:sNetClass[32];
		GetEntityNetClass(i, sNetClass, sizeof(sNetClass));
		
		/**
		See if its something that an engineer would build
		*/
		if (strcmp(sNetClass, "CObjectSentrygun") == 0 
		|| strcmp(sNetClass, "CObjectTeleporter") == 0 
		|| strcmp(sNetClass, "CObjectDispenser") == 0) 
		{
			
			/**
			It is, so lets check the owner
			*/
			if (GetEntDataEnt2(i, g_iOwnerOffset) == iClient)
			{
				
				/**
				The client supplied is the owner, return true
				*/
				if (g_bLogActivity2)
				{
					LogAction(0, iClient, "[STB] Found an engineer with buildings and skipped him.");
				}
				return true;
			}
		}
	}
	
	/**
	The client supplied didn't have any buildings, return false
	*/
	return false;
}

stock StartABalance()
{

	/**
	See if we are already started a balance
	*/
	if (g_hBalanceTimer != INVALID_HANDLE)
	{
		
		/**
		We have, check if we still need to
		*/
		if (!IsUnbalanced() || !OkToBalance())
		{
			
			/**
			We don't, stop the balance
			It's almost impossible to reach this code, but we do it just in case
			*/
			CloseHandle(g_hBalanceTimer);
			g_hBalanceTimer = INVALID_HANDLE;
			g_bBalanceInProgress = false;
			if (g_bLogActivity)
			{
				LogAction(0, -1, "[STB] Balance delay timer was not needed and was killed before the callback.");
			}
			return;
		}
		else
		{
	
			/**
			We still need to balance
			Bug out and wait for the current one to finish
			*/
			return;
		}
	}
	
	/**
	Report that teams are unbalanced
	*/
	PrintToChatAll("[SM] %T", "UnBalanced", LANG_SERVER);
	
	/**
	Check to see if we are supposed to delay the balance
	*/
	if (g_iBalanceDelay == 0)
	{
		
		/**
		Start the balance now
		*/
		if (g_bLogActivity)
		{
			LogAction(0, -1, "[STB] Balance is now in progress.");
		}
		g_bBalanceInProgress = true;
		g_hBalanceTimer = INVALID_HANDLE;
		
		/**
		Check if we are allowed to scan living players
		*/
		if (!g_bDeadOnly)
		{
			
			/**
			We are allowed to, so we start a timer
			*/
			StartALivingPlayerTimer();
			
			/**
			Also report that we are now scanning dead players as well
			*/
			if (g_bLogActivity)
			{
				LogAction(0, -1, "[STB] Now scanning dead players.");
			}
		}
		else
		{
			
			/**
			We are not allowed to, so report that we are only scanning dead players
			*/
			if (g_bLogActivity)
				LogAction(0, -1, "[STB] Only scanning dead players.");
		}
		
		/**
		We started the balance, bug out
		*/
		return;
	}
	
	/**
	We are supposed to delay the balance, start a balance timer
	*/
	g_hBalanceTimer = CreateTimer(float(g_iBalanceDelay), Timer_BalanceTeams, _, TIMER_FLAG_NO_MAPCHANGE);
	if (g_bLogActivity)
	{
		LogAction(0, -1, "[STB] Teams are unbalanced.  Balance delay timer started.");
	}
}

stock StartALivingPlayerTimer()
{

	/**
	Start a timer to check living players
	*/
	if (g_hLivingPlayerCheckTimer != INVALID_HANDLE)
	{
		
		/**
		If we for some reason already have one started, stop it.
		*/
		CloseHandle(g_hLivingPlayerCheckTimer);
		g_hLivingPlayerCheckTimer = INVALID_HANDLE;
	}
	
	if (g_bLogActivity)
	{
		LogAction(0, -1, "[STB] Living player balance delay timer started.");
	}
	g_hLivingPlayerCheckTimer = CreateTimer(float(g_iLivingPlayerCheckDelay), Timer_LivingPlayerCheck, _, TIMER_FLAG_NO_MAPCHANGE);
}

stock FindSwitchablePlayer()
{

	/**
	Start a loop to find a switchable player
	*/
	new iPlayer;
	new iBiggerTeam = GetBiggerTeam();
	for (new i = 1; i <= MaxClients; i++)
	{
	
		/**
		Check the stock function to see if we are allows to even switch the player
		*/
		if (!IsSwitchablePlayer(i, iBiggerTeam))
		{
			continue;
		}
		
		/**
		If the mod is TF2 and they have Priority Players set check if the client has buildings or an uber
		*/
		if (g_CurrentMod == GameType_TF && g_bPriorityPlayers)
		{
			if (HasUber(i) || HasBuildingsBuilt(i))
			{
				continue;
			}
		}
		
		/**
		So far we are able we switch this player
		Now we check the buddy system
		*/
		if (g_bBuddyEnabled)
		{
			
			/**
			Buddy system is enabled, check to see if client has buddy
			*/
			if (SM_GetClientBuddy(i) != 0)
			{
				
				/**
				The client has a buddy, so we check to see if they are on same team
				*/
				if (GetClientTeam(i) == GetClientTeam(SM_GetClientBuddy(i)))
				{
				
					/**
					They are, so we continue to next client
					*/
					if (g_bLogActivity2)
					{
						LogAction(0, -1, "[STB] With a balance in progress a buddy on the right team was found and skipped.");
					}
					continue;
				}
				else
				{

					/**
					They are not on the same team, set this client
					The buddy could be in spec, and that would make it not matter where he is, or the buddy is on the smaller team
					*/
					iPlayer = i;
					if (g_bLogActivity2)
					{
						LogAction(0, -1, "[STB] With a balance in progress a buddy on the wrong team was found.");
					}
					break;
				}
			}
			else
			{
				
				/**
				The client does not have a buddy, set this client
				*/
				iPlayer = i;
				break;
			}
		}
		else
		{
		
			/**
			Buddy system is not enabled, set this client
			*/
			iPlayer = i;
			break;
		}
	}
	
	/**
	Return the client we set, this could be 0, but very unlikely
	*/
	return iPlayer;
}

stock BalancePlayer(iClient, iTeam)
{
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, iClient);
	WritePackCell(hPack, iTeam);
	CreateTimer(0.1, Timer_BalancePlayer, hPack, TIMER_FLAG_NO_MAPCHANGE);
}

stock CleanUp(iClient)
{
	g_aPlayers[iClient][bFlagCarrier] = false;
	g_aPlayers[iClient][bSwitched] = false;
	if (g_aPlayers[iClient][hForcedTimer] != INVALID_HANDLE)
	{
		CloseHandle(g_aPlayers[iClient][hForcedTimer]);
		g_aPlayers[iClient][hForcedTimer] = INVALID_HANDLE;
		if (g_bLogActivity)
		{
			LogAction(0, iClient, "[STB] Forced player disconnected, killing timer.");
		}
	}
	if (g_aPlayers[iClient][hBalanceTimer] != INVALID_HANDLE)
	{
		CloseHandle(g_aPlayers[iClient][hBalanceTimer]);
		g_aPlayers[iClient][hBalanceTimer] = INVALID_HANDLE;
		if (g_bLogActivity)
		{
			LogAction(0, iClient, "[STB] Living player set to be balanced disconnected, killing timer.");
		}
	}
}

stock GetSmallerTeam()
{
	
	/**
	Get the count of players on each team
	*/
	new iCountT1 = GetTeamClientCount(g_aCurrentTeams[Team1]);
	new iCountT2 = GetTeamClientCount(g_aCurrentTeams[Team2]);
	
	/**
	Return the smaller team
	*/
	if (iCountT1 < iCountT2)
	{
		return g_aCurrentTeams[Team1];
	}
	else if (iCountT1 > iCountT2)
	{
		return g_aCurrentTeams[Team2];
	}
	return 0;
}

stock GetBiggerTeam()
{

	/**
	Get the count of players on each team
	*/
	new iCountT1 = GetTeamClientCount(g_aCurrentTeams[Team1]);
	new iCountT2 = GetTeamClientCount(g_aCurrentTeams[Team2]);
	
	/**
	Return the bigger team
	*/
	if (iCountT1 > iCountT2)
	{
		return g_aCurrentTeams[Team1];
	}
	else if (iCountT1 < iCountT2)
	{
		return g_aCurrentTeams[Team2];
	}
	return 0;
}

stock SetGameCvars()
{
	if (g_bConVarControl && g_bIsEnabled)
	{
		if (stb_mp_autoteambalance != INVALID_HANDLE)
		{
			SetConVarInt(stb_mp_autoteambalance, 0);
		}
		if (stb_mp_teams_unbalance_limit != INVALID_HANDLE)
		{
			SetConVarInt(stb_mp_teams_unbalance_limit, g_iUnbalanceLimit);
		}
	}
}

/* TIMER FUNCTIONS */

public Action:Timer_ChangeTeamBalanceDelay(Handle:timer, any:data)
{
	
	/**
	Finally start one if it's still unbalanced
	*/
	if (IsUnbalanced() && !g_bBalanceInProgress) 
	{
		StartABalance();
	}
}

public Action:Timer_BalanceTeams(Handle:timer, any:data)
{
	
	/**
	See if we still need to balance the teams
	*/
	if (!IsUnbalanced() || !OkToBalance())
	{
	
		/**
		We don't, kill the balance
		*/
		g_bBalanceInProgress = false;
		if (g_bLogActivity)
		{
			LogAction(0, -1, "[STB] Balance delay timer was not needed and died.");
		}
		g_hBalanceTimer = INVALID_HANDLE;
		return Plugin_Handled;
	}
	
	/**
	We still need to balance the teams
	*/
	if (g_bLogActivity)
	{
		LogAction(0, -1, "[STB] Teams are still unbalanced.  Balance is now in progress.");
	}
	g_bBalanceInProgress = true;
	
	
	/**
	Check if we are allowed to scan living players
	*/
	if (!g_bDeadOnly)
	{
	
		/**
		We are allowed to, so we start a timer
		*/
		StartALivingPlayerTimer();
		
		/**
		Also report that we are now scanning dead players as well
		*/
		if (g_bLogActivity)
		{
			LogAction(0, -1, "[STB] Now scanning dead players.");
		}
	}
	else
	{
		
		/**
		We are not allowed to, so report that we are only scanning dead players
		*/
		if (g_bLogActivity)
		{
			LogAction(0, -1, "[STB] Only scanning dead players.");
		}
	}
	
	g_hBalanceTimer = INVALID_HANDLE;
	return Plugin_Handled;
}

public Action:Timer_LivingPlayerCheck(Handle:timer, any:data)
{

	/**
	Check to see if we still need to balance the teams
	*/
	if (!IsUnbalanced() || !OkToBalance())
	{
	
		/**
		We don't, kill it and bug out
		*/
		g_bBalanceInProgress = false;
		if (g_bLogActivity)
		{
			LogAction(0, -1, "[STB] Living player balance delay timer was not needed and died.");
		}
		g_hLivingPlayerCheckTimer = INVALID_HANDLE;
		return Plugin_Handled;
	}
	
	/**
	Call the stock function to find a player we can switch
	*/
	new iPlayer	= FindSwitchablePlayer();
	
	/**
	Check to see if we found a player
	*/
	if (iPlayer == 0)
	{
		
		/**
		In the unlikely event that the stock function didn't return a player
		Start a loop to find a random player
		*/
		new iBiggerTeam = GetBiggerTeam();
		do
		{
			iPlayer = GetRandomInt(1, MaxClients);
		} while (!IsSwitchablePlayer(iPlayer, iBiggerTeam));
		
		if (g_bLogActivity)
		{
			LogAction(0, iPlayer, "[STB] Found a random living player.");
		}
	} 
	else
	{
		if (g_bLogActivity)
		{
			LogAction(0, iPlayer, "[STB] Found a living player.");
		}
	}
	
	/**
	Now that we have a player assigned them to the smaller team
	*/
	new iSmallerTeam = GetSmallerTeam();
	SM_SetForcedTeam(iPlayer, iSmallerTeam, true);
	
	/**
	Let the player know we could be switching him soon
	*/
	PrintHintText(iPlayer, "%T", "PlayerMessage", LANG_SERVER, g_iLivingPlayerSwitchDelay);
	if (g_bLogActivity)
	{
		LogAction(0, iPlayer, "[STB] Living player placed on a timer.");
	}
	
	/**
	Create a timer to switch the player
	*/
	g_aPlayers[iPlayer][hBalanceTimer] = CreateTimer(float(g_iLivingPlayerSwitchDelay), Timer_LivingPlayerBalance, iPlayer, TIMER_FLAG_NO_MAPCHANGE);
	
	/**
	Reset the timer handle
	*/
	g_hLivingPlayerCheckTimer = INVALID_HANDLE;
	
	/**
	We are done, bug out
	*/
	return Plugin_Handled;
}

public Action:Timer_LivingPlayerBalance(Handle:timer, any:iClient)
{
	
	/**
	Check to make sure we still need to balance
	*/
	if (!IsUnbalanced() || !OkToBalance())
	{
		
		/**
		We don't need to balance, bug out
		*/
		g_bBalanceInProgress = false;
		g_aPlayers[iClient][hBalanceTimer] = INVALID_HANDLE;
		SM_ClearForcedTeam(iClient);
		return Plugin_Handled;
	}
	
	/**
	We still need to balance, lets make sure we can still balance this player
	*/
	if (!IsClientConnected(iClient) || g_aPlayers[iClient][bFlagCarrier])
	{
		g_bBalanceInProgress = false;
		g_aPlayers[iClient][hBalanceTimer] = INVALID_HANDLE;
		SM_ClearForcedTeam(iClient);
		if (g_bLogActivity)
		{
			if (g_aPlayers[iClient][bFlagCarrier])
			{
				LogAction(0, iClient, "[STB] Living player became flag carrier, balance restarted.");
			}
			else
			{
				LogAction(0, iClient, "[STB] Living player timer was not needed and died.");
			}
		}
		return Plugin_Handled;
	}

	/**
	Clear to balance this player, so do it
	*/
	BalancePlayer(iClient, SM_GetForcedTeam(iClient));
	if (g_bLogActivity)
	{
		LogAction(0, iClient, "[STB] Living player was switched.");
	}
	
	/**
	We are done, bug out
	*/
	g_aPlayers[iClient][hBalanceTimer] = INVALID_HANDLE;
	return Plugin_Handled;
}

public Action:Timer_BalancePlayer(Handle:timer, Handle:pack)
{
	
	/**
	Rest the datapack and load the variables
	*/
	ResetPack(pack);
	new iClient = ReadPackCell(pack);
	new iUnBalancedTeam = ReadPackCell(pack);
	
	/**
	We are done with you now
	*/
	CloseHandle(pack);
	
	/**
	Check the team and make sure its a valid team
	*/
	if(!SM_IsValidTeam(iUnBalancedTeam)) 
	{
		if (g_bLogActivity)
		{
			LogAction(0, iClient, "[STB] Balance failed due to invalid team number %i", iUnBalancedTeam);
		}
		return Plugin_Handled;
	}
	
	/**
	Use our core function to change the clients team
	*/
	SM_MovePlayer(iClient, iUnBalancedTeam);
	
	return Plugin_Handled;
}

public Action:Timer_RoundStart(Handle:timer, any:data)
{
	g_bRoundStart = false;
	if (OkToBalance() && IsUnbalanced() && !g_bBalanceInProgress) 
	{
		StartABalance();
	}
	return Plugin_Handled;
}

public Action:Timer_ForcedExpired(Handle:timer, any:iClient)
{
	SM_ClearForcedTeam(iClient);
	g_aPlayers[iClient][bSwitched] = false;
	g_aPlayers[iClient][hForcedTimer] = INVALID_HANDLE;
	return Plugin_Handled;
}

public Action:Timer_WelcomeAdvert(Handle:timer, any:iClient)
{
	if (IsClientConnected(iClient) && IsClientInGame(iClient)) 
	{
		PrintToChat (iClient, "\x01\x04[STB]\x01 %T", "BuddyWelcomeMsg1", LANG_SERVER);
		PrintToChat (iClient, "\x01\x04[STB]\x01 %T", "BuddyWelcomeMsg2", LANG_SERVER);
		PrintToChat (iClient, "\x01\x04[STB]\x01 %T", "BuddyWelcomeMsg3", LANG_SERVER);
	}
	return Plugin_Handled;
}

/* CONSOLE VARIABLE CHANGE EVENT */

public ConVarSettingsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (convar == stb_enabled)
	{
		if (StringToInt(newValue) == 0)
		{
			g_bIsEnabled = false;
			PrintToChatAll("[SM] %T", "Disabled", LANG_SERVER);
			LogAction(0, -1, "[SimpleTeamBalancer] Disabled");
		}
		else
		{		
			g_bIsEnabled = true;
			SetGameCvars();
			PrintToChatAll("[SM] %T", "Enabled", LANG_SERVER);
			LogAction(0, -1, "[SimpleTeamBalancer] Enabled");
		}
	}
	else if (convar == stb_logactivity)
	{
		if (StringToInt(newValue) == 0)
		{
			g_bLogActivity = false;
			LogAction(0, -1, "[STB] Log Activity DISABLED.");
		} 
		else
		{
			g_bLogActivity = true;
			LogAction(0, -1, "[STB] Log Activity ENABLED.");
		}
	}
	else if (convar == stb_logactivity2)
	{
		if (StringToInt(newValue) == 0) 
		{
			g_bLogActivity2 = false;
			LogAction(0, -1, "[STB] Detailed Log Activity DISABLED.");
		}
		else 
		{
			g_bLogActivity2 = true;
			LogAction(0, -1, "[STB] Detailed Log Activity ENABLED.");
		}
	}
	else if (convar == stb_convarcontrol) 
	{
		if (StringToInt(newValue) == 0)
		{
			g_bConVarControl = false;
		}
		else
		{
			g_bConVarControl = true;
			SetGameCvars();
		}
	}
	else if (convar == stb_deadonly) 
	{
		if (StringToInt(newValue) == 0)
		{
			g_bDeadOnly = false;
		}
		else
		{
			g_bDeadOnly = true;
		}
	}
	else if (convar == stb_priorityenabled)
	{
		if (StringToInt(newValue) == 0)
		{
			g_bPriorityPlayers = false;
		}
		else
		{
			g_bPriorityPlayers = true;
		}
	}
	else if (convar == stb_buddyenabled)
	{
		if (StringToInt(newValue) == 0)
		{
			g_bBuddyEnabled = false;
		}
		else
		{
			g_bBuddyEnabled = true;
		}
	}
	else if (convar == stb_buddyrestriction)
	{
		if (StringToInt(newValue) == 0)
		{
			g_bBuddyRestriction = false;
		}
		else
		{
			g_bBuddyRestriction = true;
		}
	}
	else if (convar == stb_unbalancelimit)
	{
		g_iUnbalanceLimit = StringToInt(newValue);
		SetGameCvars();
	}
	else if (convar == stb_balancedelay)
	{
		g_iBalanceDelay = StringToInt(newValue);
	}
	else if (convar == stb_roundstartdelay)
	{
		g_iRoundStartDelay = StringToInt(newValue);
	}
	else if (convar == stb_livingplayerswitchdelay)
	{
		g_iLivingPlayerSwitchDelay = StringToInt(newValue);
	}
	else if (convar == stb_livingplayercheckdelay)
	{
		g_iLivingPlayerCheckDelay = StringToInt(newValue);
	}
	else if (convar == stb_uberlevel)
	{
		g_fUberLevel = StringToFloat(newValue);
	}
	else if (convar == stb_switchbackforced)
	{
		g_iSwitchBackForced = StringToInt(newValue);
	}
	else if (convar == stb_adminflag)
	{
		SetConVarString(stb_adminflag, newValue);
	}
	else if (convar == stb_mp_autoteambalance) 
	{
		SetGameCvars();
	}
	else if (convar == stb_mp_teams_unbalance_limit) 
	{
		SetGameCvars();
	}
}

/* MENU CODE */

stock Handle:BuildPlayerMenu()
{
	new Handle:menu = CreateMenu(Menu_SelectPlayer);
	AddTargetsToMenu(menu, 0, true, false);
	SetMenuTitle(menu, "Select A Player:");
	SetMenuExitButton(menu, true);
	return menu;
}

public Menu_SelectPlayer(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select) {
		new String:sSelection[24];
		GetMenuItem(menu, param2, sSelection, sizeof(sSelection));
		new buddy = GetClientOfUserId(StringToInt(sSelection));
		if (param1 == buddy) {
			PrintHintText(param1, "%T", "SelectSelf", LANG_SERVER);
		} else if (!IsClientInGame(buddy)) {
			PrintHintText(param1, "%T", "BuddyGone", LANG_SERVER);
		} else {
			decl String:cName[128];
			decl String:bName[128];
			GetClientName(param1, cName, sizeof(cName));
			GetClientName(buddy, bName, sizeof(bName));
			if (!SM_IsBuddyLocked(buddy)) {
				SM_AssignBuddy(param1, buddy);
				PrintHintText(param1, "%T", "BuddyMsg", LANG_SERVER, bName);
				PrintHintText(buddy, "%T", "BuddyMsg", LANG_SERVER, cName);
			} else
				PrintHintText(param1, "%T", "PlayerLockedBuddyMsg", LANG_SERVER, bName);
		}
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}