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
	GameType_DM,
	GameType_ZPS
};

enum e_Teams
{
	Unknown,
	Spectator,
	Team1,
	Team2
};

new g_aCurrentTeams[e_Teams];
new e_SupportedMods:g_CurrentMod;
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
																							"Dark Messiah",
																							"Zombie Panic: Source"
};

stock MovePlayer(client, team)
{
	switch (g_CurrentMod)
	{
		case GameType_CSS:
		{
			CS_SwitchTeam(client, team);
		}
		default:
		{
			ChangeClientTeam(client, team);
		}
	}
}

stock bool:IsValidClient(client, bool:nobots = true)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
    { 
      return false; 
    } 
    return IsClientInGame(client); 
}

stock LoadCurrentTeams()
{
	switch (g_CurrentMod)
	{
		case GameType_INS:
		{
			g_aCurrentTeams[Unknown] = 0;
			g_aCurrentTeams[Spectator] = 3;
			g_aCurrentTeams[Team1] = 1;
			g_aCurrentTeams[Team2] = 2;
		}
		default:
		{
			g_aCurrentTeams[Unknown] = 0;
			g_aCurrentTeams[Spectator] = 1;
			g_aCurrentTeams[Team1] = 2;
			g_aCurrentTeams[Team2] = 3;
		}
	}
}

stock e_SupportedMods:GetCurrentMod()
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
	if (StrEqual(sGameType, "mmdarkmessiah", false))
	{
		return GameType_DM;
	}
	LogMessage("Unknown Game Folder: %s", sGameType);
	return GameType_Unknown;
}
