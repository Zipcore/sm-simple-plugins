/************************************************************************
*************************************************************************
Approval Snippets
Description:
	Handy stock functions to make using your plugin easier and help obey approval rules
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
*************************************************************************/

#if defined _approval_snippets_included
  #endinput
#endif

#define _approval_snippets_included

enum e_SupportedMods
{
	GameType_Unknown,
	GameType_AOC,
	GameType_CSS,
	GameType_DOD,
	GameType_FF,
	GameType_HIDDEN,
	GameType_HL2DM,
	GameType_INS,
	GameType_L4D,
	GameType_L4D2,
	GameType_NEO,
	GameType_SGTLS,
	GameType_TF,
	GameType_ZPS
};

enum e_CvarTypes
{
	CvarType_Integer = 0,
	CvarType_String = 1,
	CvarType_Float = 2
};

new e_SupportedMods:g_eCurrentMod;
new Handle:g_hCvarValues;
new Handle:g_hCvarIndexes;
new Handle:g_hCvarTypes;
new String:g_sGameName[e_SupportedMods][32] = {	"Unknown",
																							"Age of Chivalry",
																							"Counter Strike",
																							"Day Of Defeat",
																							"Fortress Forever",
																							"Hidden: Source",
																							"Half Life 2: Deathmatch",
																							"Insurgency",
																							"Left 4 Dead",
																							"Left 4 Dead 2",
																							"Neotokyo",
																							"Stargate TLS",
																							"Team Fortress 2",
																							"Zombie Panic: Source"
																						};

/**********************************************************************
 * Check for the correct game type and possibly fail when not the correct game
 *
 * @param 		gametype	The game mod to check for.  See e_SupportedMods enum for valid types
 * @param 		fail				Whether or not to fail if gametype is not detected (default: true)
 * @return							True if detected, false if not
 * @error								None
 **********************************************************************/
stock bool:SM_CheckForMod(e_SupportedMods:gametype, bool:fail = true)
{
	if (g_eCurrentMod == GameType_Unknown)
	{
		g_eCurrentMod = SM_GetCurrentMod();
	}
	if (g_eCurrentMod != gametype)
	{
		if (fail)
		{
			SetFailState("Game type does not match.  Plugin requires [%s] and found [%s]", g_sGameName[gametype], g_sGameName[g_eCurrentMod]);
		}
		else
		{
			return false;
		}
	}
	return true;
}
 
 /**********************************************************************
 * Detect current game mod
 *
 * @return						Gametype.  See e_SupportedMods enum for valid types
 * @error							None
 **********************************************************************/
stock e_SupportedMods:SM_GetCurrentMod()
{
	new String:sGameType[64];
	GetGameFolderName(sGameType, sizeof(sGameType));
	
	if (StrEqual(sGameType, "aoc", false))
	{
		return GameType_AOC;
	}
	if (StrEqual(sGameType, "cstrike", false))
	{
		return GameType_CSS;
	}
	if (StrEqual(sGameType, "dod", false))
	{
		return GameType_DOD;
	}
	if (StrEqual(sGameType, "ff", false))
	{
		return GameType_FF;
	}
	if (StrEqual(sGameType, "hidden", false))
	{
		return GameType_HIDDEN;
	}
	if (StrEqual(sGameType, "hl2mp", false))
	{
		return GameType_FF;
	}
	if (StrEqual(sGameType, "insurgency", false) || StrEqual(sGameType, "ins", false))
	{
		return GameType_INS;
	}
	if (StrEqual(sGameType, "left4dead", false) || StrEqual(sGameType, "l4d", false))
	{
		return GameType_L4D;
	}
	if (StrEqual(sGameType, "left4dead2", false) || StrEqual(sGameType, "l4d2", false))
	{
		return GameType_L4D2;
	}
	if (StrEqual(sGameType, "nts", false))
	{
		return GameType_NEO;
	}
	if (StrEqual(sGameType, "sgtls", false))
	{
		return GameType_SGTLS;
	}
	if (StrEqual(sGameType, "tf", false))
	{
		return GameType_TF;
	}
	if (StrEqual(sGameType, "zps", false))
	{
		return GameType_ZPS;
	}
	return GameType_Unknown;
}

/**********************************************************************
 * Save the current value of a console variable
 *
 * @param 		cvar			The console variable to save
 * @param 		type			The type of cvar value.  See e_CvarTypes enum for valid types
 * @return						Handle to the saved cvar or INVALID_HANDLE on error. Same as FindConVar().
 * @error							Invalid console variable
 **********************************************************************/
stock Handle:SM_SaveConVar(const String:cvar[], e_CvarTypes:type)
{
	new Handle:hCvar = FindConVar(cvar);
	if (hCvar == INVALID_HANDLE)
	{
		return INVALID_HANDLE;
	}
	else
	{
		if (g_hCvarValues == INVALID_HANDLE)
		{
			g_hCvarValues = CreateArray(256, 0);
			g_hCvarIndexes = CreateArray(256, 0);
			g_hCvarTypes = CreateArray(1, 0);
		}
		switch (type)
		{
			case CvarType_Integer:
			{
				PushArrayCell(g_hCvarValues, GetConVarInt(hCvar));
				PushArrayString(g_hCvarIndexes, cvar);
				PushArrayCell(g_hCvarTypes, CvarType_Integer);
			}
			case CvarType_String:
			{
				new String:sCvarValue[256];
				GetConVarString(hCvar, sCvarValue, sizeof(sCvarValue));
				PushArrayString(g_hCvarValues, sCvarValue);
				PushArrayString(g_hCvarIndexes, cvar);
				PushArrayCell(g_hCvarTypes, CvarType_String);
			}
			case CvarType_Float:
			{
				new String:sCvarValue[256];
				GetConVarString(hCvar, sCvarValue, sizeof(sCvarValue));
				PushArrayString(g_hCvarValues, sCvarValue);
				PushArrayString(g_hCvarIndexes, cvar);
				PushArrayCell(g_hCvarTypes, CvarType_Float);
			}
			default:
			{
				return INVALID_HANDLE;
			}
		}
	}
	return hCvar;
}

/**********************************************************************
 * Restore the original value of a console variable
 *
 * @param 		cvar			The console variable to save
 * @param 		remove	Whether or not to remove the cvar from the list of saved cvars
 * @return						True if successful, false if not
 * @error							Invalid console variable
 **********************************************************************/
stock bool:SM_RestoreConVar(const String:cvar[], bool:remove = false)
{
	new Handle:hCvar = FindConVar(cvar);
	if (hCvar == INVALID_HANDLE)
	{
		return false;
	}
	else
	{
		new Index = FindStringInArray(g_hCvarIndexes, cvar);
		if (Index == -1)
		{
			return false;
		}
		new e_CvarTypes:eType = e_CvarTypes:GetArrayCell(g_hCvarTypes, Index);
		switch (eType)
		{
			case CvarType_Integer:
			{
				SetConVarInt(hCvar, GetArrayCell(g_hCvarValues, Index));
			}
			case CvarType_String:
			{
				new String:sCvarValue[256];
				GetArrayString(g_hCvarValues, Index, sCvarValue, sizeof(sCvarValue));
				SetConVarString(hCvar, sCvarValue);
			}
			case CvarType_Float:
			{
				new String:sCvarValue[64];
				GetArrayString(g_hCvarValues, Index, sCvarValue, sizeof(sCvarValue));
				new Float:fCvarValue = StringToFloat(sCvarValue);
				SetConVarFloat(hCvar, fCvarValue);
			}
			default:
			{
				return false;
			}
		}
		if (remove)
		{
			RemoveFromArray(g_hCvarValues, Index);
			RemoveFromArray(g_hCvarTypes, Index);
			RemoveFromArray(g_hCvarIndexes, Index);
		}
	}
	return true;
}

/**********************************************************************
 * Restore the original value of all the saved console variables
 *
 * @param 		remove	Whether or not to remove the cvars from the list of saved cvars
 * @noreturn					
 * @error							None
 **********************************************************************/
stock SM_RestoreAllConVars(bool:remove = false)
{
	new iArraySize = GetArraySize(g_hCvarIndexes) - 1;
	if (iArraySize <= -1)
	{
		return;
	}
	for (new i = 0; i <= iArraySize; i++)
	{
		new String:sCvarName[256];
		GetArrayString(g_hCvarIndexes, i, sCvarName, sizeof(sCvarName));
		SM_RestoreConVar(sCvarName);
	}
	if (remove)
	{
		ClearArray(g_hCvarValues);
		ClearArray(g_hCvarTypes);
		ClearArray(g_hCvarIndexes);
	}
	return;
}
