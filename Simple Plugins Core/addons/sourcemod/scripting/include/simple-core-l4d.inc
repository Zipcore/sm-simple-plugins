/************************************************************************
*************************************************************************
Simple Plugins L4D Core Include File
Description:
	Core Left 4 Dead 1/2 include file for the Simple Plugins project.
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
#if defined _simple_core_l4d_included
	#endinput
#endif

#define _simple_core_l4d_included

#define CORE_L4D_INC_VERSION "1.0.$Rev$"

enum e_L4DGameType
{
	L4DGameMode_Unknown,
	L4DGameMode_Coop,
	L4DGameMode_Versus,
	L4DGameMode_TeamVersus,
	L4DGameMode_Scavenge,
	L4DGameMode_TeamScavenge,
	L4DGameMode_Survial,
	L4DGameMode_Realism
};

enum e_L4DGameDifficulty
{
	
}

stock e_L4DGameType:L4D_GetGameType()
{	
	new Handle:hGameMode = FindConVar("mp_gamemode");
	new String:sGameMode[32];
	GetConVarString(hGameMode, sGameMode, sizeof(sGameMode));
	
	if (StrEqual(sGameMode, "coop", false))
	{
		return L4DGameMode_Coop;
	}
	else if (StrEqual(sGameMode, "versus", false))
	{
		return L4DGameMode_Versus;
	}
	else if (StrEqual(sGameMode, "teamversus", false))
	{
		return L4DGameMode_TeamVersus;
	}
	else if (StrEqual(sGameMode, "scavenge", false))
	{
		return L4DGameMode_Scavenge;
	}
	else if (StrEqual(sGameMode, "teamscavenge", false))
	{
		return L4DGameMode_TeamScavenge;
	}
	else if (StrEqual(sGameMode, "survival", false))
	{
		return L4DGameMode_Survial;
	}
	else if (StrEqual(sGameMode, "realism", false))
	{
		return L4DGameMode_Realism;
	}
	
	return L4DGameMode_Unknown;
}