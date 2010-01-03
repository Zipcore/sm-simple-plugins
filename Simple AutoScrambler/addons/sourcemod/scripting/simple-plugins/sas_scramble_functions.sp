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
$Id: sas_config_access.sp 85 2010-01-02 12:43:24Z antithasys $
$Author: antithasys $
$Revision: 85 $
$Date: 2010-01-02 06:43:24 -0600 (Sat, 02 Jan 2010) $
$LastChangedBy: antithasys $
$LastChangedDate: 2010-01-02 06:43:24 -0600 (Sat, 02 Jan 2010) $
$URL: https://sm-simple-plugins.googlecode.com/svn/trunk/Simple%20AutoScrambler/addons/sourcemod/scripting/simple-plugins/sas_config_access.sp $
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
	
