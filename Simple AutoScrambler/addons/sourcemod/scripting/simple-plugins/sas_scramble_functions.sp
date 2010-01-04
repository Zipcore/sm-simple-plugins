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
	if (mode == Mode_TopSwap)
	{
		SwapTopPlayers();
	}
	else
	{
		new Float:f_ToScramble[GetClientCount()][2],
			iCounter, team = g_iLastRoundLoser;
		if (!team)
		{
			team = GetRandomInt(0,1) ? g_aCurrentTeams[TeamOne]:g_aCurrentTeams[TeamTwo];
		}
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && CanScrambleTarget(i))
			{
				f_ToScramlbe[counter++][0] = float(i);
			}
		}
		switch (mode)
		{
			case Mode_Random:
			{
				SortRandomly(f_ToScramble, iCounter);
			}
			case Mode_Scores:
			{
				SortByScores(f_ToScramble, iCounter);
			}
			case Mode_Scores:
			{
				SortByScores(f_ToScramble, iCounter);
			}
			case Mode_KillRatios:
			{
				SortByKillRatios(f_ToScramble, iCounter);
			}
		}
		// start swapping
		for (new i; i < iCounter; i++)
		{
			new client = RoundFloat(f_ToScramble[i][0]);
			SM_MovePlayer(client, team);
			team = team ==  g_aCurrentTeams[TeamTwo] ? g_aCurrentTeams[TeamOne] : g_aCurrentTeams[TeamTwo];
		}			
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

stock SwapTopPlayers();
{
	new aTeamOne[GetTeamClientCount(g_aCurrentTeams[TeamOne])][2],
		aTeamTwo[GetTeamClientCount(g_aCurrentTeams[TeamTwo])][2],
		iCounter1, iCounter2, iSwaps = GetSettingValue("top_swaps")
	// load up the top players into an array
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && CanScrambleTarget(i))
		{
			new iTeam = GetClientTeam(i);
			if (iTeam == g_aCurrentTeams[TeamOne])
			{
				aTeamOne[iCounter1][0] = i;
				aTeamOne[iCounter1][1] = GetClientScore(client);
				iCounter1++
			}
			else
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
		SM_MovePlayer(aTeamOne[i][0], g_aCurrentTeams[TeamTwo]);
		SM_MovePlayer(aTeamTwo[i][0], g_aCurrentTeams[TeamOne]);
	}
}

stock SortRandomly(float:array[][], numClients)
{
	// copy everything into a 1d array
	new clients[numClints];
	for (new i; i < numClients; i++)
		clients[i] = RoundFloat(array[i][0]);
	SortIntegers(clients, iCount, Sort_Random);
	// copy back to the main array
	for (new i; i<numClients; i++)
		array[i][0] = float(clients[i]);
}

stock SortByScores(float:array[][], numClients)
{
	// get everyone's score
	for (new i; i < numClients; i++)
	{
		array[i][1] = float(GetClientScore(i));
	}
	SortCustom2D(array, numClients, SortFloatsDesc);
}

stock SortByKillRatios(float:array[][], numClients)
{
	// get everyone's kill/death ratio
	for (new i; i < numClients; i++)
	{
		array[i][1] = g_aPlayers[i][iFrags] / g_aPlayers[i][iDeaths];
	}
	SortCustom2D(array, numClients, SortFloatsDesc);
}

stock bool:CanScrambleTarget(client)
{
	new team = GetClientTeam(client);
	if (team != g_aCurrentTeams[team1] && team != g_aCurrentTeams[team2])
		return false;
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
			if (g_aRoundInfo[Round_State] == Round_Normal)
			{
				if (TF2_IsClientUbered(client))
				{
					return false;
				}
			if (GetSettingValue("tf2_engineers"))
			{
				if (GetSettingValue("tf2_buildings") && TF2_DoesClientHaveBuilding(client "obj_*"))
				{
					return false;
				}
				if (GetSettingValue("tf2_lone_engineer") && TF2_IsClientOnlyClass(client, TFClass_Engineer))
				{
					return false;
				}
			}
			if (GetSettingValue("tf2_medics"))
			{
				if (TF2_IsClientUberCharged(client))
				{
					return false;
				}
				if (GetSettingValue("tf2_lone_medic") && TF2_IsClientOnlyClass(client, TFClass_Medic))
				{
					return false;
				}
			}	
		}
		default:
		{
		
		}
	}
	return true;
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

GetClientScore(client)
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
	
