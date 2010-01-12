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

new	Handle:g_hTimer_Daemon = INVALID_HANDLE;
new	Handle:g_hTimer_MapStart = INVALID_HANDLE;

stock StartDaemon()
{
	g_hTimer_Daemon = CreateTimer(1.0, Timer_Daemon, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

stock StopDaemon()
{
	ClearTimer(g_hTimer_Daemon);
}

public Action:Timer_Deamon(Handle:timer, any:data)
{
	
	if (!CanScramble() || g_bScrambling)
	{
		return Plugin_Continue;
	}
	
	new bool:bPerformScramble = false;
	
	/**
	Run through a series of checks
	*/
	switch (g_RoundState)
	{
		case Map_Start:
		{
			if (GetSettingValue("map_load") && g_hTimer_MapStart == INVALID_HANDLE)
			{
				g_hTimer_MapStart = CreateTimer(10.0, Timer_MapStart, _, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		case Round_Normal:
		{
			bPerformScramble = ActiveScan();
		}
	}
	
	if (bPerformScramble)
	{
		StartAScramble(e_ScrambleMode:GetSettingValue("sort_mode"));
	}
		
	return Plugin_Continue;
}

public Action:Timer_MapStart(Handle:timer, any:data)
{
	if (CanScramble())
	{
		StartAScramble(e_ScrambleMode:GetSettingValue("sort_mode"));
	}
	
	g_hTimer_MapStart = INVALID_HANDLE;
	
	return Plugin_Handled;
}

stock bool:CanScramble()
{
	if (GetSettingValue("enabled"))
	{
		if (GetSettingValue("min_players") > GetClientCount()
			|| (g_CurrentMod == GameType_TF && GetSettingValue("tf2_full_round_only") && !g_bWasFullRound))
		{
			return false;
		}
		
		return true;
	}
	
	return false;
}

stock bool:ActiveScan()
{
	
	/**
	These are checks that are run often and should be kept to a mininum
	*/
	
	/**
	Check for a score difference
	*/
	new iMaxScoreDifference = GetSettingValue("diff_avg_score");
	if (iMaxScoreDifference)
	{
		
		/**
		Get the teams average score per player and calculate the difference
		*/
		new Float:Team1_AvgDiff = FloatDiv(Float(GetTeamScore(g_aCurrentTeams[Team1])), Float(GetTeamClientCount(g_aCurrentTeams[Team1])));
		new Float:Team2_AvgDiff = FloatDiv(Float(GetTeamScore(g_aCurrentTeams[Team2])), Float(GetTeamClientCount(g_aCurrentTeams[Team2])));
		new iCurrentDifference = RoundFloat(FloatAbs(Team1_AvgDiff - Team2_AvgDiff));
		
		/**
		If the difference is greater than the max, return true
		*/
		if (iCurrentDifference > iMaxScoreDifference)
		{
			return true;
		}
	}
	
	/**
	Check for a frag difference
	*/
	new iMaxFragDifference = GetSettingValue("diff_frag");
	if (iMaxFragDifference)
	{
		
		/**
		Get the teams frag difference
		*/
		new iCurrentDifference = RoundFloat(FloatAbs(Float(g_aTeamInfo[Team1][Team_Frags]) - Float(g_aTeamInfo[Team1][Team_Frags])));
		
		/**
		If the difference is greater than the max, return true
		*/
		if (iCurrentDifference > iMaxFragDifference)
		{
			return true;
		}
	}
	
	/**
	Get the teams average kill death ratio and see if they it's above the max difference
	*/
	new iRatioDifference = GetSettingValue("diff_kdratio");
	if (iRatioDifference)
	{
		
		/**
		Make sure we don't divide by zero
		*/
		if (g_aTeamInfo[Team1][Team_Deaths] != 0 && g_aTeamInfo[Team2][Team_Deaths] != 0)
		{
			
			/**
			Get the teams average kill death ratio and calculate the difference
			*/
			new Float:fTeam1Ratio = FloatDiv(Float(g_aTeamInfo[Team1][Team_Frags]), Float(g_aTeamInfo[Team1][Team_Deaths]));
			new Float:fTeam2Ratio = FloatDiv(Float(g_aTeamInfo[Team2][Team_Frags]), Float(g_aTeamInfo[Team2][Team_Deaths]));
			new iCurrentDifference = RoundFloat(FloatAbs(fTeam1Ratio - fTeam2Ratio));
			
			/**
			If the difference is greater than the max, return true
			*/
			if (iCurrentDifference > iRatioDifference)
			{
				return true;
			}
		}
	}
	
	/**
	Check if we are playing TF2
	*/
	if (g_CurrentMod == GameType_TF)
	{
		
		/**
		Check for a domination difference
		*/
		new iDominationDifference = GetSettingValue("tf2_dominations");
		if (iDominationDifference)
		{
			
			/**
			Get the teams dominations and calculate the difference
			*/
			new Float:fTeam1Doninations = Float(TF2_GetTeamDominations(g_aCurrentTeams[Team1]));
			new Float:fTeam2Doninations = Float(TF2_GetTeamDominations(g_aCurrentTeams[Team2]));
			new iCurrentDifference = RoundFloat(FloatAbs(fTeam1Doninations - fTeam2Doninations));
		
			/**
			If the difference is greater than the max, return true
			*/
			if (iCurrentDifference > iRatioDifference)
			{
				return true;
			}
		}
	}
	
	return false;
}

stock bool:RoundEnd_ScrambleCheck()
{

	if ((g_iRoundCount > 0 && GetSettingValue("rounds") >= g_iRoundCount)
		|| (GetSettingValue("win_streak") >= g_aTeamInfo[Team1][Team_WinStreak])
		|| (GetSettingValue("win_streak") >= g_aTeamInfo[Team2][Team_WinStreak])
		|| (g_iRoundStartTime - GetTime() <= GetSettingValue("time_limit")))
//		I have no idea how you are gonna track this, figure it out and then use it
//		|| (GetSettingValue("spam_protection") && g_bScrambledThisRound)
	{
		return true;
	}
	
	if (g_CurrentMod == GameType_TF)
	{
		new TFGameType:eGameType = TF2_GetGameType();
		if (eGameType != TFGameMode_ARENA)
		{
			new iCaps;
			switch (eGameType)
			{
				case TFGameMode_CTF:
				{
					iCaps = GetSettingValue("tf2_intel_cap")
				}
				case TFGameMode_PL:
				{
					iCaps = GetSettingValue("tf2_pl_cap")
				}
				case TFGameMode_PLR:
				{
					iCaps = GetSettingValue("tf2_pl_cap")
				}
				case TFGameMode_KOTH:
				{
					iCaps = GetSettingValue("tf2_koth_cap")
				}
			}
			
			if (iCaps)
			{
				if (!g_aTeamInfo[Team1][Team_Goal] || !g_aTeamInfo[Team2][Team_Goal])
				{
					return true;
				}
			}
		}
	}
	
	return false;
}