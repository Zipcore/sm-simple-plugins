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

new Handle:g_hScrambleTimer	 = INVALID_HANDLE;

new bool:g_bScrambling = false;

stock StartAScramble(e_ScrambleMode:mode)
{
	
	/**
	See if we are already started a scramble
	*/
	if (g_hScrambleTimer != INVALID_HANDLE)
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
	g_hScrambleTimer = CreateTimer(15.0, Timer_ScrambleTeams, mode, TIMER_FLAG_NO_MAPCHANGE);
	LogAction(0, -1, "[SAS] A scamble timer was started");
}

public Action:Timer_ScrambleTeams(Handle:timer, any:mode)
{
	
	/**
	Make sure it's still ok to scramble
	*/
	if (!CanScramble())
	{
		
		/**
		Not ok, bug out
		*/
		g_hScrambleTimer = INVALID_HANDLE;
		g_bScrambling = false;
		return Plugin_Handled;
	}
	
	if (mode == Mode_Invalid);
	{		
		mode = GetSettingValue("sort_mode")
	}	
	g_bScrambling = true;
	if (mode == Mode_TopSwap)
	{
		SwapTopPlayers();
	}
	else
	{
	/**
	get the valid scramble targets, put them into an array for sorting
	*/
		new	iClients[GetClientCount()],
				iCounter, team = g_iLastRoundLoser;
		
		if (!team)
		{
			team = GetRandomInt(0,1) ? g_aCurrentTeams[Team1] : g_aCurrentTeams[Team2];
		}
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && CanScrambleTarget(i))
			{
				iClients[iCounter++] = i;
			}
		}
		
		switch (mode)
		{
			case Mode_Random:
			{
				SortIntegers(iClients, iCounter, Sort_Random);
			}
			case Mode_Scores:
			{
				SortByScores(iClients, iCounter);
			}
			case Mode_KillRatios:
			{
				SortByKillRatios(iClients, iCounter);
			}
		}
		
		// start swapping
		for (new i; i < iCounter; i++)
		{
			new client = iClients[i];
			SM_MovePlayer(client, team);
			team = team ==  g_aCurrentTeams[Team2] ? g_aCurrentTeams[Team1] : g_aCurrentTeams[Team2];
		}			
	}


	/**
	Reset the handle because the timer is over and the callback is done
	*/
	g_hScrambleTimer = INVALID_HANDLE;
	g_bScrambling = false;
	
	/**
	Global Reset Functions
	*/
	ResetScores();
	ResetStreaks();
	
	/**
	Check if we need to restart the round
	*/
	if (GetSettingValue("restart_round")
		|| (GetSettingValue("mid_game_restart") && g_RoundState == Round_Normal)
		|| (g_RoundState == Round_Normal && g_iRoundStartTime - GetTime() <= GetSettingValue("time_restart"))
	{
		RestartRound();
		if (GetSettingValue("reset_scores"))
		{
			ResetScores();
		}
	}
	
	/**
	We are done, bug out.
	*/
	return Plugin_Handled;
}

stock SwapTopPlayers();
{
	new	aTeamOne[GetTeamClientCount(g_aCurrentTeams[Team1])][2],
			aTeamTwo[GetTeamClientCount(g_aCurrentTeams[Team2])][2],
			iCounter1, iCounter2, iSwaps = GetSettingValue("top_swaps")
	
	// load up the top players into an array
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && CanScrambleTarget(i))
		{
			new iTeam = GetClientTeam(i);
			if (iTeam == g_aCurrentTeams[Team1])
			{
				aTeamOne[iCounter1][0] = i;
				aTeamOne[iCounter1][1] = GetClientScore(client);
				iCounter1++
			}
			else
			{
				aTeamTwo[iCounter2][0] = i;
				aTeamTwo[iCounter2][1] = GetClientScore(client);
				iCounter2++;
			}
		}
	}
	SortCustom2D(aTeamOne, iCounter1, SortIntsDesc);
	SortCustom2D(aTeamTwo, iCounter2, SortIntsDesc);
	if (!iSwaps)
	{
		LogError("[SAS] You have set top_swaps to 0, defaulting to 2");
		iSwaps = 2;
	}
	if (iCounter1 < iSwaps || iCounter2 < iSwaps)
	{
		if (iCounter1 > iCounter2)
		{
			iSwaps = iCounter2;
		}
		else
		{
			iSwaps = iCounter1
		}
		if (!iSwaps)
		{
			LogMessage("[SAS] not enough valid players to do a top-swap");
			return;
		}
	}
	// swap the players
	for (new i; i < iSwaps; i++)
	{
		SM_MovePlayer(aTeamOne[i][0], g_aCurrentTeams[Team2]);
		SM_MovePlayer(aTeamTwo[i][0], g_aCurrentTeams[Team1]);
	}
}

stock bool:CanScrambleTarget(client)
{
	// if admins are set to be immune, check the client's access
	if (GetSettingValue("admins"))
	{
		if (IsAuthorized(client, "flag_immunity"))
		{
			return false;
		}
	}
	
	// check for buddy immunity
	if (GetSettingValue("buddies"))
	{
		new iBuddy = SM_GetClientBuddy(client);
		if (iBuddy && GetClientTeam(client) == GetClientTeam(iBuddy))
		{
			return false;
		}
	}
	
	// check to see if a client should be protected due to being a leader
	if (GetSettingValue("top_protection") && IsClientTopPlayer(client))
	{
		return false;
	}
		
	// only do specific immunity checks during a mid-round scramble
	switch (g_CurrentMod)
	{
		case GameType_TF:
		{
			if (g_RoundState == Round_Normal)
			{
				if (TF2_IsClientUbered(client))
				{
					return false;
				}
			}
			if (GetSettingValue("tf2_engineers"))
			{
				if (GetSettingValue("tf2_buildings") && TF2_DoesClientHaveBuilding(client "obj_*")
					|| (GetSettingValue("tf2_lone_engineer") && TF2_IsClientOnlyClass(client, TFClass_Engineer)))
				{
					return false;
				}
			}
			if (GetSettingValue("tf2_medics"))
			{
				if (TF2_IsClientUberCharged(client)
					|| (GetSettingValue("tf2_lone_medic") && TF2_IsClientOnlyClass(client, TFClass_Medic)))
				{
					return false;
				}
			}
		}
		default:
		{
			//something
		}
	}
	
	return true;
}

stock bool:IsClientTopPlayer(client)
{
	new teamSize = GetTeamClientCount(client), 
			scores[][2],
			count;
	for (new i = i; i < teamSize; i++)
	{
		scores[count++][0] = i;
		scores[count][1] = GetClientScore(i);
	}
	SortCustom2D(scores, count, SortIntsDesc);
	for (new i; i <= PROTECTION; i++)
	{
		if (i == client)
		{
			return true;
		}
	}	
	return false;
}

stock GetClientScore(client)
{
	switch (g_CurrentMod)
	{
		case GameType_TF:
		{
			return TF2_GetClientScore(client);
		}
		case GameType_DOD:
		{
			// something
		}
		default:
		{
			return g_aPlayers[client][iFrags];
		}
	}
}

stock ResetScores()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		g_aPlayers[i][iFrags] = 0;
		g_aPlayers[i][iDeaths] = 0;
	}
	for (new e_Teams:x = Unknown; x < e_Teams:sizeof(g_aTeamInfo); x++)
	{
		for (new e_TeamData:y = Team_Frags; y < e_TeamData:sizeof(g_aTeamInfo[]); y++)
		{
			g_aTeamInfo[i][y] = 0;
		}
	}
}

stock ResetStreaks()
{
	for (new e_Teams:x = Unknown; x < e_Teams:sizeof(g_aTeamInfo); x++)
	{
		g_aTeamInfo[x][Team_WinStreak] = 0;
	}
}

stock AddTeamStreak(e_Teams:iTeam)
{
	switch (iTeam)
	{
		case Team1:
		{
			g_aTeamInfo[Team1][Team_WinStreak]++;
			g_aTeamInfo[Team2][Team_WinStreak] = 0;
		}
		case Team2:
		{
			g_aTeamInfo[Team1][Team_WinStreak] = 0;
			g_aTeamInfo[Team2][Team_WinStreak]++;
		}
		default:
		{
			ResetStreaks();
		}
	}
}

stock SortByScores(array[], numClients)
{
	new	sortArray[numClients][2],
			client;
	// get everyone's score
	for (new i; i < numClients; i++)
	{
		sortArray[i][0] = array[i];
		sortArray[i][1] = GetClientScore(array[i]);
	}
	SortCustom2D(sortArray, numClients, SortIntsDesc);
	// copy the sorted array to the original
	for (new i; i < numClients; i++)
	{
		array[i] = sortArray[i][0];
	}
}

stock SortByKillRatios(array[], numClients)
{
	new	Float:sortArray[numClients][2],
			client;
	// get everyone's kill/death ratio
	for (new i; i < numClients; i++)
	{
		client = array[i]
		sortArray[i][1] = g_aPlayers[client][iFrags] / g_aPlayers[client][iDeaths];
		sortArray[i][0] = float(client);
	}
	SortCustom2D(sortArray, numClients, SortFloatsDesc);
	for (new i; i < numClients; i++)
	{
		array[i] = RoundFloat(sortArray[i][0]);
	}
}

public SortFloatsDesc(x[], y[], array[][], Handle:data)
{
  if (Float:x[1] > Float:y[1])
	{
    return -1;
	}
	else if (Float:x[1] < Float:y[1])
	{
		return 1;
	}
  return 0;
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
