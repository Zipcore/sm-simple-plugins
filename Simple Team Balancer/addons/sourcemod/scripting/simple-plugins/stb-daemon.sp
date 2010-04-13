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

enum	e_BalanceState
{
	Balance_UnAcceptable,
	Balance_Acceptable,
	Balance_Needed,
	Balance_Delayed,
	Balance_InProgress
};

new	Handle:	g_hTimer_Daemon = INVALID_HANDLE;
new	Handle:	g_hBalanceTimer = INVALID_HANDLE;
new					e_BalanceState:g_eBalanceState;

stock StartDaemon()
{
	g_hTimer_Daemon = CreateTimer(2.0, Timer_Daemon, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

stock StopDaemon()
{
	ClearTimer(g_hTimer_Daemon);
}

public Action:Timer_Daemon(Handle:timer, any:data)
{
	
	/**
	Run through a series of checks
	*/
	
	if (GetSettingValue("log_detailed"))
	{
		LogMessage("Current Round State: %i", g_eRoundState);
	}
	
	switch (g_eRoundState)
	{
		case Map_Start:
		{
			g_eBalanceState = Balance_UnAcceptable;
		}
		case Round_Setup:
		{
			if (g_CurrentMod == GameType_TF && GetSettingValue("tf2_allowsetup"))
			{
				g_eBalanceState = Balance_UnAcceptable;
			}
			else
			{
				g_eBalanceState = Balance_Acceptable;
			}
		}
		case Round_Normal:
		{
			if (g_eBalanceState == Balance_UnAcceptable)
			{
				g_eBalanceState = Balance_Acceptable;
			}
		}
		case Round_Overtime:
		{
			g_eBalanceState = Balance_UnAcceptable;
		}
		case Round_SuddenDeath:
		{
			g_eBalanceState = Balance_UnAcceptable;
		}
		case Round_Ended:
		{
			g_eBalanceState = Balance_UnAcceptable;
		}
	}
	
	if (GetSettingValue("log_detailed"))
	{
		LogMessage("Current Balance State: %i", g_eBalanceState);
	}
	
	switch (g_eBalanceState)
	{
		case Balance_Acceptable:
		{
			if (OkToBalance())
			{
				if (GetUnbalancedCount() > GetSettingValue("unbalance_limit"))
				{
					if (GetSettingValue("log_detailed"))
					{
						LogMessage("Teams are unbalanced");
					}
					g_eBalanceState = Balance_Needed;
				}
			}
		}
		case Balance_Needed:
		{
			StartBalance();
		}
		case Balance_Delayed:
		{
			if (!OkToBalance())
			{
				if (GetUnbalancedCount() <= GetSettingValue("unbalance_limit"))
				{
					if (GetSettingValue("log_detailed"))
					{
						LogMessage("Teams are no longer unbalanced");
					}
					StopBalance();
				}
			}
		}
		case Balance_InProgress:
		{
			if (OkToBalance())
			{
				if (GetUnbalancedCount() < GetSettingValue("unbalance_limit"))
				{
					if (GetSettingValue("log_detailed"))
					{
						LogMessage("Teams are no longer unbalanced");
					}
					StopBalance();
				}
				else
				{
					new iLargerTeam, iSmallerTeam;
					GetUnbalancedCount(iLargerTeam, iSmallerTeam);
					for (new x = 1; x <= MaxClients; x++)
					{
						if (IsSwitchablePlayer(x, iLargerTeam))
						{
							BalancePlayer(x, iSmallerTeam);
							break;
						}
						if (x == MaxClients)
						{
							new iRandomPlayer;
							do
							{
								iRandomPlayer = GetRandomInt(1, MaxClients);
							} while (IsSwitchablePlayer(iRandomPlayer, iLargerTeam, false);
							BalancePlayer(iRandomPlayer, iSmallerTeam);
						}
					}
				}
			}
			else
			{
				if (GetSettingValue("log_detailed"))
				{
					LogMessage("No longer ok to balance");
				}
				StopBalance();
			}
		}
	}	
	
	return Plugin_Continue;
}

stock GetUnbalancedCount(&largerteam = 0, &smallerteam = 0)
{
	
	if (GetSettingValue("log_detailed"))
	{
		LogMessage("Checking if teams are unbalanced");
	}
	
	new Team1Count = GetTeamClientCount(g_aCurrentTeams[Team1]);
	new Team2Count = GetTeamClientCount(g_aCurrentTeams[Team2]);
	new ubCount = RoundFloat(FloatAbs(float(Team1Count - Team2Count)));
	
	if (GetSettingValue("log_detailed"))
	{
		LogMessage("Team1:%i Team2:%i Difference:%i", Team1Count, Team2Count, ubCount);
	}
	
	if (ubCount > 0)
	{
		if (Team1Count > Team2Count)
		{
			largerteam = g_aCurrentTeams[Team1];
			smallerteam = g_aCurrentTeams[Team2];
		}
		else
		{
			largerteam = g_aCurrentTeams[Team2];
			smallerteam = g_aCurrentTeams[Team1];
		}
	}
	else
	{
		
		if (GetSettingValue("log_detailed"))
		{
			LogMessage("Teams are not unbalanced");
		}
		
		return 0;
	}
	
	return ubCount;
}

stock bool:OkToBalance()
{
	if (GetSettingValue("log_detailed"))
	{
		LogMessage("Checking if OK to balance.");
	}
	new bool:bResult = false;
	if (GetSettingValue("enabled") && (GetSettingValue("min_players") < GetClientCount()))
	{
		if (GetSettingValue("log_detailed"))
		{
			LogMessage("Passed IF statement");
			LogMessage("Now checking admins");
		}
		for (new x = 1; x <= MaxClients; x++) 
		{
			if (IsValidClient(x, !GetSettingValue("bots_included")) && !IsAuthorized(x, "flag_immunity")) 
			{
				if (GetSettingValue("log_detailed"))
				{
					LogMessage("Found at least 1 non-admin");
					LogMessage("OK to balance");
				}
				bResult = true;
				break;
			}
		}
		if (!bResult && GetSettingValue("log_detailed"))
		{
			LogMessage("All admins online");
		}
	}
	if (!bResult && GetSettingValue("log_detailed"))
	{
		LogMessage("Not OK to balance");
	}
	return bResult;
}

stock StartBalance()
{

	/**
	Report that teams are unbalanced
	*/
	PrintToChatAll("[SM] %T", "UnBalanced", LANG_SERVER);
	g_eBalanceState = Balance_Delayed;
	g_hBalanceTimer = CreateTimer(float(GetSettingValue("delay_balancestart")), Timer_BalanceTeams, _, TIMER_FLAG_NO_MAPCHANGE);
	if (GetSettingValue("log_basic"))
	{
		LogMessage("Teams are unbalanced.  Balance delay timer started.");
	}
}

stock StopBalance()
{
	ClearTimer(g_hBalanceTimer);
	g_eBalanceState = Balance_UnAcceptable;
	if (GetSettingValue("log_basic"))
	{
		LogMessage("Balance was stopped");
	}
}

public Action:Timer_BalanceTeams(Handle:timer, any:data)
{
	
	/**
	See if we still need to balance the teams
	*/
	if (g_eBalanceState != Balance_Delayed)
	{
	
		/**
		We don't, kill the balance
		*/
		if (GetSettingValue("log_basic"))
		{
			LogMessage("Balance was stopped at the start of the callback");
		}
		StopBalance();
		return Plugin_Handled;
	}
	
	/**
	We still need to balance the teams
	*/
	g_eBalanceState = Balance_InProgress;
	if (GetSettingValue("log_basic"))
	{
		LogMessage("Teams are still unbalanced.  Balance is now in progress.");
	}
	
	g_hBalanceTimer = INVALID_HANDLE;
	return Plugin_Handled;
}

stock BalancePlayer(client, team)
{
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, client);
	WritePackCell(hPack, team);
	CreateTimer(0.5, Timer_BalancePlayer, hPack, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_BalancePlayer(Handle:timer, Handle:pack)
{
	
	/**
	Rest the datapack and load the variables
	*/
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new iUnBalancedTeam = ReadPackCell(pack);
	CloseHandle(pack);
	
	/**
	Check the team and make sure its a valid team
	*/
	if(iUnBalancedTeam <= 1)
	{
		if (GetSettingValue("log_basic"))
		{
			LogMessage("Balance failed due to invalid team number %i", iUnBalancedTeam);
		}
		return Plugin_Handled;
	}
	
	/**
	Use our core function to change the clients team
	*/
	SM_MovePlayer(client, iUnBalancedTeam);
	g_aPlayers[client][hSwitchTimer] = CreateTimer(float(GetSettingValue("delay_switchagain")), Timer_PlayerSwitchCleared, client, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Handled;
}

public Action:Timer_BalancePlayer(Handle:timer, Handle:pack)
{
	g_aPlayers[client][bSwitched] = false;
	g_aPlayers[client][hSwitchTimer] = INVALID_HANDLE;
	return Plugin_Handled;
}

stock bool:IsSwitchablePlayer(client, biggerteam, bool:switchcheck = true)
{

	/**
	Run the client thru some standard checks
	*/
	if (!IsValidClient(client, !GetSettingValue("bots_included"))
		|| IsAuthorized(client, "flag_immunity")
		|| GetClientTeam(client) != biggerteam
		|| (switchcheck && g_aPlayers[client][bSwitched])
		|| (GetSettingValue("dead_only") && IsPlayerAlive(client))
		|| (GetSettingValue("buddy_enabled") && SM_IsBuddyTeamed(client))
		|| (GetSettingValue("top_players") && IsClientTopTeamPlayer(client)))
	{
		return false;
	}
	else
	{
		switch (g_CurrentMod)
		{
			case GameType_TF:
			{
				if (g_aPlayers[client][bFlagCarrier] || TF2_IsPlayerUber(client))
				{
					return false;
				}
				if (GetSettingValue("tf2_medics") && TF2_GetPlayerClass(client) == TFClass_Medic)
				{
					if (TF2_GetPlayerUberLevel(client) >= GetSettingValue("tf2_charge_level")
						|| (GetSettingValue("tf2_lone_medic") && TF2_IsClientOnlyClass(client, TFClass_Medic)))
					{
						return false;
					}
				}
				if (GetSettingValue("tf2_engineers") && TF2_GetPlayerClass(client) == TFClass_Engineer)
				{
					if (GetSettingValue("tf2_buildings") && TF2_DoesClientHaveBuildings(client)
						|| (GetSettingValue("tf2_lone_engineer") && TF2_IsClientOnlyClass(client, TFClass_Engineer)))
					{
						return false;
					}
				}
			}
			default:
			{
				return true;
			}
		}
	}
	
	/**
	The supplied client can be switched
	*/
	return true;
}

stock bool:IsClientTopTeamPlayer(client)
{
	new iTeam = GetClientTeam(client);
	new iPlayerScores[MAXPLAYERS + 1][2];
	new iCount;
	
	for (new x = 1; x <= MaxClients; x++)
	{
		if (IsValidClient(x, !GetSettingValue("bots_included")) && GetClientTeam(x) == iTeam)
		{
			iPlayerScores[iCount][0] = x;
			iPlayerScores[iCount++][1] = GetClientScore(x);
		}
	}

	SortCustom2D(iPlayerScores, iCount, SortIntsDesc);
	
	if (iPlayerScores[0][0] == client)
	{
		return true;
	}
	return false;
}

public SortIntsDesc(x[], y[], array[][], Handle:data)
{
	if (x[1] > y[1])
	{
		return -1;
	}
	else if (x[1] < y[1])
	{
		return 1;
	}
	return 0;
}
