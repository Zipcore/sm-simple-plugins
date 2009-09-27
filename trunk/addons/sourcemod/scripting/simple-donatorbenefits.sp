/************************************************************************
*************************************************************************
Simple Donator Benefits
Description:
	Provides donator benefits to players
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
#include <dukehacks>

#define PLUGIN_VERSION "1.1.$Rev$"

#define CHAT_SYMBOL '@'
#define CHAT_MAX_MESSAGE_LENGTH 1024

enum PlayerData
{
	bool:bIsDonator,
	bool:bQueue,
	bool:bImmune,
	iHealthCount,
	iNewTeam
};

/**
 Public convar handles 
 */
new Handle:sdb_enabled = INVALID_HANDLE;
new Handle:sdb_donationflag = INVALID_HANDLE;
new Handle:sdb_soundfile = INVALID_HANDLE;
new Handle:sdb_joinsound_enabled = INVALID_HANDLE;
new Handle:sdb_joinpubmsg_enabled = INVALID_HANDLE;
new Handle:sdb_joinprivmsg_enabled = INVALID_HANDLE;
new Handle:sdb_chatcolors_enabled = INVALID_HANDLE;
new Handle:sdb_immunity_enabled = INVALID_HANDLE;
new Handle:sdb_ubercharge_enabled = INVALID_HANDLE;
new Handle:sdb_givehealth_enabled = INVALID_HANDLE;
new Handle:sdb_nofalldmg_enabled = INVALID_HANDLE;
new Handle:sdb_fastheavy_enabled = INVALID_HANDLE;
new Handle:sdb_swapteam_enabled = INVALID_HANDLE;
new Handle:sdb_chatcolor = INVALID_HANDLE;
new Handle:sdb_uberlevel = INVALID_HANDLE;
new Handle:sdb_healthcount = INVALID_HANDLE;
new Handle:sdb_healthbonus = INVALID_HANDLE;
new Handle:sdb_heavymultiplier = INVALID_HANDLE;

/**
Create global enable/disable bools so we don't have to check the console variable on every call
*/
new bool:g_bIsEnabled = true;
new bool:g_bIsJoinSoundEnabled = true;
new bool:g_bIsJoinPubMsgEnabled = true;
new bool:g_bIsJoinPrivMsgEnabled = true;
new bool:g_bIsChatColorsEnabled = true;
new bool:g_bIsImmuntyEnabled = true;
new bool:g_bIsUberChargeEnabled = true;
new bool:g_bIsGiveHealthEnabled = true;
new bool:g_bIsNoFallDmgEnabled = true;
new bool:g_bIsFastHeayEnabled = true;
new bool:g_bIsSwapTeamEnabled = true;

/**
 Player arrays 
 */
new g_aPlayers[MAXPLAYERS + 1][PlayerData];


/**
Rest of the globals
*/
new bool:g_bRoundEnd = false;
new String:g_sCharDonatorFlag[5];
new String:g_sSoundFile[PLATFORM_MAX_PATH];
new String:g_sChatColor[11];
new g_iHealthBonus;
new g_iHealthCount;
new g_iClassMaxHealth[TFClassType] = {0, 125, 125, 200, 175, 150, 300, 175, 125, 125};
new g_fClassMaxSpeed[TFClassType] = {0, 400, 300, 240, 280, 320, 230, 300, 300, 300};
new Float:g_fHeavyMultiplier = 0.0;
new Float:g_fUberLevel = 0.0;

public Plugin:myinfo =
{
	name = "Simple Donation Benefits",
	author = "Simple Plugins",
	description = "Gives donators benefits to players",
	version = PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
}

public OnPluginStart()
{

	/**
	Get game type and load the team numbers
	*/
	g_CurrentMod = GetCurrentMod();
	LoadCurrentTeams();
	
	/**
	Hook the game events
	*/
	LogAction(0, -1, "[SDB] Hooking events for [%s].", g_sGameName[g_CurrentMod]);
	HookEvent("player_connect", HookPlayerSpawn, EventHookMode_Pre);
	HookEvent("player_spawn", HookPlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", HookPlayerDeath, EventHookMode_Post);
	HookEvent("player_team", HookPlayerChangeTeam, EventHookMode_Post);
	switch (g_CurrentMod)
	{
		case GameType_TF:
		{
			HookEvent("teamplay_round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("teamplay_round_win", HookRoundEnd, EventHookMode_Post);
			HookEvent("player_changeclass", HookPlayerClass, EventHookMode_Post);
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
	Create console variables
	*/
	CreateConVar("sdb_version", PLUGIN_VERSION, "Simple Donation Benefits", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	sdb_enabled = CreateConVar("sdb_enabled", "1", "Enable/Disable Simple Donation Benefits");
	sdb_donationflag = CreateConVar("sdb_donationflag", "a", "Flag ALREADY given to donators. Must be in char format");
	
	/**
	Create the enable/disable donator console variables
	*/
	sdb_joinsound_enabled = CreateConVar("sdb_joinsound_enabled", "1", "Enable/Disable donator join sound");
	sdb_joinpubmsg_enabled = CreateConVar("sdb_joinpubmsg_enabled", "1", "Enable/Disable public donator join message (replaces: <name> as connected)");
	sdb_joinprivmsg_enabled = CreateConVar("sdb_joinprivmsg_enabled", "1", "Enable/Disable private donator join message (sent only to donator)");
	sdb_chatcolors_enabled = CreateConVar("sdb_chatcolors_enabled", "1", "Enable/Disable donator chat colors");
	sdb_immunity_enabled = CreateConVar("sdb_immunity_enabled", "1", "Enable/Disable donator round end immunity");
	sdb_ubercharge_enabled = CreateConVar("sdb_ubercharge_enabled", "1", "Enable/Disable donator medics starting with ubercharge");
	sdb_givehealth_enabled = CreateConVar("sdb_givehealth_enabled", "1", "Enable/Disable donator instant health bonus");
	sdb_nofalldmg_enabled = CreateConVar("sdb_nofalldmg_enabled", "1", "Enable/Disable no fall damage for donators");
	sdb_fastheavy_enabled = CreateConVar("sdb_fastheavy_enabled", "1", "Enable/Disable donator heavies moving faster while spinning");
	sdb_swapteam_enabled = CreateConVar("sdb_swampteam_enabled", "1", "Enable/Disable donator swap team ability");
	
	/**
	Create the donator setting console variables
	*/
	sdb_soundfile = CreateConVar("sdb_soundfile", "custom/donatorjoin.mp3", "The location of sound file");
	sdb_chatcolor = CreateConVar("sdb_chatcolor", "green", "Color to use for donator chat.  Valid colors are green and lightgreen");
	sdb_uberlevel = CreateConVar("sdb_uberlevel", "0.5", "Uberlevel to give donator medic at spawn. 1.0 = full uber", _, true, 0.0, true, 1.0);
	sdb_healthcount = CreateConVar("sdb_healthcount", "1", "Number of times a donator can use use instant health per life");
	sdb_healthbonus = CreateConVar("sdb_healthbonus", "100", "The amount of health to heal the donator");
	sdb_heavymultiplier = CreateConVar("sdb_heavyspeed", "0.5", "The speed multiplier for the fast heavy.  Based on running speed. 1.0 = running speed. (Game Default is 0.20)", _, true, 0.0, true, 1.0);
	
	/**
	Hook dukehacks calls
	*/
	dhAddClientHook(CHK_TakeDamage, Hacks_TakeDamageHook);
	dhAddClientHook(CHK_PreThink, Hacks_PreThinkHook);
	
	/**
	Hook the console variables if they change
	*/
	HookConVarChange(sdb_enabled, ConVarSettingsChanged);
	HookConVarChange(sdb_donationflag, ConVarSettingsChanged);
	HookConVarChange(sdb_joinsound_enabled, ConVarSettingsChanged);
	HookConVarChange(sdb_joinpubmsg_enabled, ConVarSettingsChanged);
	HookConVarChange(sdb_joinprivmsg_enabled, ConVarSettingsChanged);
	HookConVarChange(sdb_chatcolors_enabled, ConVarSettingsChanged);
	HookConVarChange(sdb_immunity_enabled, ConVarSettingsChanged);
	HookConVarChange(sdb_ubercharge_enabled, ConVarSettingsChanged);
	HookConVarChange(sdb_givehealth_enabled, ConVarSettingsChanged);
	HookConVarChange(sdb_nofalldmg_enabled, ConVarSettingsChanged);
	HookConVarChange(sdb_swapteam_enabled, ConVarSettingsChanged);
	HookConVarChange(sdb_fastheavy_enabled, ConVarSettingsChanged);
	HookConVarChange(sdb_soundfile, ConVarSettingsChanged);
	HookConVarChange(sdb_chatcolor, ConVarSettingsChanged);
	HookConVarChange(sdb_uberlevel, ConVarSettingsChanged);
	HookConVarChange(sdb_healthcount, ConVarSettingsChanged);
	HookConVarChange(sdb_healthbonus, ConVarSettingsChanged);
	HookConVarChange(sdb_heavymultiplier, ConVarSettingsChanged);
	
	/**
	Register the commands
	*/
	RegConsoleCmd("sm_swapteams", Command_SwapTeam, "sm_swapteams <[0]instant/[1]queued>: Swaps your team to the other team");
	RegConsoleCmd("sm_ihealth", Command_InstantHealth, "sm_ihealth: Gives you a instant health pack");
	RegAdminCmd("sm_teaser", Command_Teaser, ADMFLAG_GENERIC,"sm_teaser <name/#userid> <[0]add/[1]remove>: Gives temporary donator privilages to a player");
	RegConsoleCmd("say", Command_Say);
	
	RegConsoleCmd("sm_test", Command_TEST);
	
	/**
	Load the translations
	*/
	LoadTranslations("common.phrases");
	LoadTranslations("simpledonatorbenefits.phrases");
	
	/**
	Load or create the config file
	*/
	AutoExecConfig(true, "plugin.simpledonatorbenefits");
	LogAction(0, -1, "[SDB] Simple Donator Benefits is loaded.");
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
	Load up all the variable defaults
	*/
	LoadUpVariables();
	
	/**
	If the join sound is enabled, prep the sound files
	*/
	if (g_bIsJoinSoundEnabled)
		PrepSoundFile();
	
	/**
	Log our activity
	*/
	if (g_bIsEnabled)
		LogAction(0, -1, "Simple Donation Benefits is ENABLED");
	else
		LogAction(0, -1, "Simple Donation Benefits is DISABLED");
}

public OnClientPostAdminCheck(client)
{

	/**
	Check if the client is a donator
	*/
	if (SM_IsValidAdmin(client, g_sCharDonatorFlag))
	{
	
		/**
		They are, so we set the player array to true and start a timer for the sound or add
		*/
		g_aPlayers[client][bIsDonator] = true;
		if (g_bIsJoinSoundEnabled || g_bIsJoinPrivMsgEnabled)
		{
			CreateTimer(10.0, Timer_DonatorJoined, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	} 
	else
	{
		/**
		They aren't, so we set the player array to false
		*/
		g_aPlayers[client][bIsDonator] = false;
	}
}

public OnClientDisconnect_Post(client)
{

	/**
	Clean up the player variables
	*/
	CleanUpPlayer(client);
}

public Action:Command_SwapTeam(client, args)
{

	/**
	Make sure we are enabled
	*/
	if (!g_bIsEnabled || !g_bIsSwapTeamEnabled)
	{
		return Plugin_Handled;
	}
	
	/**
	Make sure the command is not started by the server
	*/
	if (client == 0)
	{
		ReplyToCommand(client, "\x01\x04[SDB]\x01 %T", "PlayerLevelCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	
	/**
	Make sure the player is a donator
	*/
	if (!g_aPlayers[client][bIsDonator])
	{
		ReplyToCommand(client, "\x01\x04[SDB]\x01 %T", "RestrictedCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	
	/**
	Lets make sure the client is one a team we can swap.
	If he is we set the global array to the opposite team.
	*/
	new iTeam = GetClientTeam(client);
	if (iTeam == g_aCurrentTeams[Team1])
	{
		g_aPlayers[client][iNewTeam] = g_aCurrentTeams[Team2];
	}
	else  if (iTeam == g_aCurrentTeams[Team2])
	{
		g_aPlayers[client][iNewTeam] = g_aCurrentTeams[Team1];
	}
	else
	{
		ReplyToCommand(client, "\x01\x04[SM]\x01 %T", "InValidTeam", LANG_SERVER);
		return Plugin_Handled;
	}
	
	/**
	Check to see if we have command arguments.
	*/
	if (GetCmdArgs())
	{
	
		/**
		We do, so lets get it and see if the client wants to be switched instantly or queued for death.
		*/
		decl String:sArg[5];
		GetCmdArg(1, sArg, sizeof(sArg));
		new iWantsQue = StringToInt(sArg);
		if (iWantsQue && !g_aPlayers[client][bQueue])
		{
		
			/**
			He wants the que and isn't already in it, set the global array.
			*/
			g_aPlayers[client][bQueue] = true;
			ReplyToCommand(client, "\x01\x04[STM]\x01 %T", "PlayerQueue", LANG_SERVER);
		}
		else if (!iWantsQue)
		{
		
			/**
			He wants to be switched right now, lets call the stock function.
			*/
			SM_MovePlayer(client, g_aPlayers[client][iNewTeam]);
		}
	}
	else
	{
		
		/**
		There are no command arguments so we build and display the swap menu.
		*/
		new Handle:hPlayerMenu = BuildSwapModeMenu();
		DisplayMenu(hPlayerMenu, client, MENU_TIME_FOREVER);
	}
	
	/**
	We are done, bug out.
	*/
	return Plugin_Handled;
}

public Action:Command_InstantHealth(client, args)
{

	/**
	Make sure we are enabled
	*/
	if (!g_bIsEnabled || !g_bIsGiveHealthEnabled)
	{
		return Plugin_Handled;
	}
	
	/**
	Make sure the command is not started by the server
	*/
	if (client == 0)
	{
		ReplyToCommand(client, "\x01\x04[SDB]\x01 %T", "PlayerLevelCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	
	/**
	Make sure the player is a donator
	*/
	if (!g_aPlayers[client][bIsDonator])
	{
		ReplyToCommand(client, "\x01\x04[SDB]\x01 %T", "RestrictedCmd", LANG_SERVER);
		return Plugin_Handled;
	}
	
	/**
	Check health count to see if the player has reached the max
	*/
	if (g_aPlayers[client][iHealthCount] >= g_iHealthCount) 
	{
		ReplyToCommand(client, "\x01\x04[SDB]\x01 %T", "ReachedCount", LANG_SERVER);
		return Plugin_Handled;
	}
	
	/**
	Get the class of the player and the max health for that class
	*/
	new iHealth = GetClientHealth(client);
	new TFClassType:PlayerClass = TF2_GetPlayerClass(client);
	new iMaxHealth = g_iClassMaxHealth[PlayerClass];

	/**
	Check to see if the player is at the max health of the class
	*/
	if (iHealth >= iMaxHealth)
	{
		ReplyToCommand(client, "\x01\x04[SDB]\x01 %T", "AtMaxHealth", LANG_SERVER);
		return Plugin_Handled;
	}

	/**
	Check the current health
	*/
	if (iHealth + g_iHealthBonus >= iMaxHealth)
	{
		
		/**
		Raise them to max health  if the current health + bonus would go above it
		*/
		SetEntityHealth(client, iMaxHealth);
		ReplyToCommand(client, "\x01\x04[SDB]\x01 %T", "ToMaxHealth", LANG_SERVER);
	}
	else
	{
	
		/**
		Give them the instant health bonus
		*/
		SetEntityHealth(client, iHealth + g_iHealthBonus);
		ReplyToCommand(client, "\x01\x04[SDB]\x01 %T", "HealthBonus", LANG_SERVER);
	}
	
	/**
	Increase the count
	*/
	g_aPlayers[client][iHealthCount] += 1;
	
	/**
	We are done, bug out.
	*/
	return Plugin_Handled;
}

public Action:Command_Teaser(client, args)
{

	/**
	Make sure we are enabled
	*/
	if (!g_bIsEnabled)
	{
		return Plugin_Handled;
	}
	
	/**
	Check to see if we have command arguments.
	*/
	new iCmdArgs = GetCmdArgs();
	if (iCmdArgs == 0)
	{
	
		/**
		We don't so display the player menu.
		*/
		new Handle:hPlayerMenu = BuildPlayerMenu();
		DisplayMenu(hPlayerMenu, client, MENU_TIME_FOREVER);
		return Plugin_Handled;
	}
	
	/**
	We have some arguments, see if we can find the player
	*/
	decl String:sPlayer[64];
	GetCmdArg(1, sPlayer, sizeof(sPlayer));
	new iTarget = FindTarget(client, sPlayer, true, true);
	if (iTarget == -1 || !IsClientInGame(iTarget))
	{
		
		/**
		We don't know who this is, so display the player menu.
		*/
		new Handle:hPlayerMenu = BuildPlayerMenu();
		DisplayMenu(hPlayerMenu, client, MENU_TIME_FOREVER);
	}
	else
	{
		/**
		We found the player, see if we are supposed to turn it on or off.
		*/
		if (iCmdArgs >= 2)
		{
			decl String:sOn[3];
			GetCmdArg(2, sOn, sizeof(sOn));
			if (StringToInt(sOn))
			{
				
				/**
				Turn temp benefits on.
				*/
				g_aPlayers[iTarget][bIsDonator] = true;
			}
			else
			{
				
				/**
				Turn temp benefits on.
				*/
				g_aPlayers[iTarget][bIsDonator] = false;
			}
		}
		else
		{
			
			/**
			We don't know what to do, so just turn it on.
			*/
			g_aPlayers[iTarget][bIsDonator] = true;
		}
	}
	
	/**
	We are done, bug out.
	*/
	return Plugin_Handled;
}

public Action:Command_Say(client, args)
{

	/**
	Make sure we are enabled.
	*/
	if (client == 0 || IsChatTrigger() || !g_bIsChatColorsEnabled || !g_bIsEnabled)
	{
		return Plugin_Continue;
	}
	
	/**
	Check the client to see if they are a donator.
	*/
	if (g_aPlayers[client][bIsDonator])
	{
	
		/**
		The client is, so get the chat message and strip it down.
		*/
		decl String:sArg[CHAT_MAX_MESSAGE_LENGTH],
			 String:sChatMsg[CHAT_MAX_MESSAGE_LENGTH];
		new  bool:bAlive = IsPlayerAlive(client);
		GetCmdArgString(sArg, sizeof(sArg));
		StripQuotes(sArg);
		TrimString(sArg);
		new startidx;
		if (sArg[strlen(sArg)-1] == '"')
		{
			sArg[strlen(sArg)-1] = '\0';
			startidx = 1;
		}
		
		/**
		Bug out if they are using the admin chat symbol (admin chat).
		*/
		if (sArg[startidx] == CHAT_SYMBOL)
		{
			return Plugin_Continue;
		}
		
		/**
		Format the message.
		*/
		FormatMessage(client, 0, bAlive, sChatMsg, sArg);
		
		/**
		Send the message.
		*/
		SayText2(0, client, sChatMsg);
		
		/**
		We are done, bug out, and stop the original chat message.
		*/
		return Plugin_Stop;
	}
	
	/**
	We are done, bug out.
	*/
	return Plugin_Continue;
}

public Action:Hacks_TakeDamageHook(client, attacker, inflictor, Float:damage, &Float:multiplier, damagetype)
{

	/**
	Make sure we are enabled and the client is a donator.
	*/
	if (g_bIsEnabled && g_bIsNoFallDmgEnabled && g_aPlayers[client][bIsDonator])
	{
	
		/**
		Check for fall damage.
		*/
		if (damagetype & DMG_FALL)
		{
		
			/**
			Cancel the fall damage and bug out.
			*/
			multiplier *= 0.0;
			return Plugin_Changed;
		}
	}
	
	/**
	We are done, bug out.
	*/
	return Plugin_Continue;
}

public Action:Hacks_PreThinkHook(client)
{
	
	/**
	Make sure we are enabled and the client is a donator.
	*/
	if (!g_bIsEnabled || !g_bIsFastHeayEnabled || !g_aPlayers[client][bIsDonator])
	{
		return Plugin_Continue;
	}
	
	/**
	Check the players class. We are looking for the heavy.
	*/
	new TFClassType:PlayerClass = TF2_GetPlayerClass(client);
	if (PlayerClass == TFClass_Heavy) 
	{
		
		/**
		We have a heavy, lets check the weapon.
		*/
		decl String:sWeaponCurrent[64];
		GetClientWeapon(client, sWeaponCurrent, sizeof(sWeaponCurrent));
		if (StrEqual(sWeaponCurrent, "tf_weapon_minigun", false))
		{
		
			/**
			We have a minigun, check the heavies current weapon state to see if it's spinning.
			*/
			new iWeapon = GetPlayerWeaponSlot(client, 0);
			new iWeaponState = GetEntProp(iWeapon, Prop_Send, "m_iWeaponState");
			if (iWeaponState > 0)
			{
			
				/**
				He is spinning, so lets change the heavies speed.
				*/
				new Float:fMaxSpeed = FloatMul(g_fHeavyMultiplier, float(g_fClassMaxSpeed[PlayerClass]));
				SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", fMaxSpeed);
			}
		}
	}
	
	/**
	We are done, bug out.
	*/
	// use Plugin_Continue (other options are ignored on PreThink hook)
	return Plugin_Continue;
}

public Action:HookPlayerConnect(Handle:event, const String:name[], bool:dontBroadcast)
{

	/**
	Make sure we are enabled.
	*/
	if (!g_bIsEnabled || !g_bIsJoinPubMsgEnabled || !dontBroadcast)
	{
		return Plugin_Continue;
	}
	
	/**
	Get our event variables and check the client.
	*/
	new iUserId = GetEventInt(event,"userid");
	new iClient = GetClientOfUserId(iUserId);
	if (iClient != 0)
	{
	
		/**
		Get the info on the client and format the message.
		*/
		decl String:sClientName[255],
			 String:sAuthID[255],
			 String:sMsg[1024];

		GetEventString(event, "name", sClientName, sizeof(sClientName));
		GetClientAuthString(iClient, sAuthID, sizeof(sAuthID));
		Format(sMsg, sizeof(sMsg), "%T", "PublicJoinMessage", LANG_SERVER, sClientName);
		
		/**
		Print the message to the clients and do the normal functions.
		*/
		for (new i = 1; i <= MaxClients; i++)
		{
			if(IsClientConnected(i) && IsClientInGame(i))
			{
				PrintToChat(i,"\x01\x05%s", sMsg);
				PrintToConsole(i,"%s has connected.", sClientName);
			}
		}
		LogToGame("\"%s<%d><%s><>\" entered the game", sClientName, iUserId, sAuthID);
	}
	
	/**
	We are done, bug out.
	*/
	return Plugin_Handled;
}

public HookPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{

	/**
	Make sure we are enabled.
	*/
	if (g_bIsEnabled && g_bIsUberChargeEnabled)
	{

		/**
		Get the event variables and check the class for medic
		*/	
		new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
		if (TF2_GetPlayerClass(iClient) == TFClass_Medic)
		{
			
			/**
			Start a timer to get the medic the uber  boost
			*/
			CreateTimer(0.25, Timer_PlayerUberDelay, iClient, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public HookPlayerClass(Handle:event, const String:name[], bool:dontBroadcast)
{

	/**
	Make sure we are enabled.
	*/
	if (g_bIsEnabled && g_bIsUberChargeEnabled)
	{
	
		/**
		Get the event variables and check the class for medic
		*/
		new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
		if (TF2_GetPlayerClass(iClient) == TFClass_Medic)
		{
		
			/**
			Start a timer to get the medic the uber  boost
			*/
			CreateTimer(0.25, Timer_PlayerUberDelay, iClient, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public HookPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	/**
	Make sure we are enabled.
	*/
	if (g_bIsEnabled || g_bIsSwapTeamEnabled)
	{

		/**
		Get the event variables
		*/
		new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
		new String:sWeapon[256];
		GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
		
		/**
		Bug out if world killed him.  Means he changed team or something
		*/
		if (StrEqual(sWeapon, "world", false))
		{
			g_aPlayers[iClient][bQueue] = false;
			return;
		}
		
		/**
		If he is queued up, swap him
		*/
		if (g_aPlayers[iClient][bQueue])
		{
			SM_MovePlayer(iClient, g_aPlayers[iClient][iNewTeam]);
		}
	}
}

public HookPlayerChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{

	/**
	Make sure we are enabled.
	*/
	if (g_bIsEnabled || g_bIsSwapTeamEnabled)
	{
	
		/**
		Get the event variables
		*/
		new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
		
		/**
		If he is queued up, clear the status
		*/
		if (g_aPlayers[iClient][bQueue])
		{
			g_aPlayers[iClient][bQueue] = false;
		}
	}
}

public HookRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{

	/**
	Set our variables.
	*/
	g_bRoundEnd = false;
	
	/**
	Make sure we are enabled.
	*/
	if (g_bIsEnabled && g_bIsImmuntyEnabled)
	{
	
		/**
		Get rid of their immunity.
		*/
		ProcessRoundEndImmunity(false);
	}
}

public HookRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	/**
	Set our variables.
	*/
	g_bRoundEnd = true;
	
	/**
	Make sure we are enabled.
	*/
	if (g_bIsEnabled && g_bIsImmuntyEnabled)
	{
		
		/**
		Give them their immunity.
		*/
		ProcessRoundEndImmunity(true);
	}
}

public Action:Timer_DonatorJoined(Handle:timer, any:client)
{

	/**
	Make sure sounds are enabled.
	*/
	if (g_bIsEnabled && g_bIsJoinSoundEnabled)
	{
		EmitSoundToClient(client, g_sSoundFile);
	}
	
	/**
	Make sure private messages are enabled.
	*/
	if (g_bIsJoinPrivMsgEnabled) 
	{
	
		/**
		Send messages to the client.
		*/
		decl String:sMsg[1024];
		Format(sMsg, sizeof(sMsg), "%T", "PrivateJoinMessage", LANG_SERVER);
		PrintToChat(client,"\x01\x05%s", sMsg);
	}
	
	/**
	We are done, bug out.
	*/
	return Plugin_Handled;
}

public Action:Timer_PlayerUberDelay(Handle:timer, any:client)
{

	/**
	Make sure the client is still in game.
	*/
	if (IsClientInGame(client)) 
	{
	
		/**
		Make sure the client is still a medic.
		*/
		if (TF2_GetPlayerClass(client) == TFClass_Medic)
		{
		
			/**
			Get the medgun weapon index
			*/
			new iIndex = GetPlayerWeaponSlot(client, 1);
			if (iIndex > 0)
			{
			
				/**
				Set the uber level with the bonus.
				*/
				SetEntPropFloat(iIndex, Prop_Send, "m_flChargeLevel", g_fUberLevel);
			}
		}
	}
}

public ConVarSettingsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (convar == sdb_enabled) 
	{
		if (StringToInt(newValue) == 0)
		{
			g_bIsEnabled = false;
		}
		else
		{
			g_bIsEnabled = true;
		}
	} 
	else if (convar == sdb_donationflag) 
	{
		Format(g_sCharDonatorFlag, sizeof(g_sCharDonatorFlag), "%s", newValue);
	} 
	else if (convar == sdb_soundfile) 
	{
		Format(g_sSoundFile, sizeof(g_sSoundFile), "%s", newValue);
	} 
	else if (convar == sdb_joinsound_enabled) 
	{
		if (StringToInt(newValue) == 0)
		{
			g_bIsJoinSoundEnabled = false;
		}
		else
		{
			g_bIsJoinSoundEnabled = true;
		}
	} 
	else if (convar == sdb_joinpubmsg_enabled) 
	{
		if (StringToInt(newValue) == 0)
		{
			g_bIsJoinPubMsgEnabled = false;
		}
		else
		{
			g_bIsJoinPubMsgEnabled = true;
		}
	}
	else if (convar == sdb_joinprivmsg_enabled) 
	{
		if (StringToInt(newValue) == 0)
		{
			g_bIsJoinPrivMsgEnabled = false;
		}
		else
		{
			g_bIsJoinPrivMsgEnabled = true;
		}
	}
	else if (convar == sdb_chatcolors_enabled) 
	{
		if (StringToInt(newValue) == 0)
		{
			g_bIsChatColorsEnabled = false;
		}
		else
		{
			g_bIsChatColorsEnabled = true;
		}
	}
	else if (convar == sdb_immunity_enabled) 
	{
		if (StringToInt(newValue) == 0)
		{
			g_bIsImmuntyEnabled = false;
		}
		else
		{
			g_bIsImmuntyEnabled = true;
		}
	} 
	else if (convar == sdb_ubercharge_enabled) 
	{
		if (StringToInt(newValue) == 0)
		{
			g_bIsUberChargeEnabled = false;
		}
		else
		{
			g_bIsUberChargeEnabled = true;
		}
	} 
	else if (convar == sdb_givehealth_enabled) 
	{
		if (StringToInt(newValue) == 0)
		{
			g_bIsGiveHealthEnabled = false;
		}
		else
		{
			g_bIsGiveHealthEnabled = true;
		}
	} 
	else if (convar == sdb_nofalldmg_enabled) 
	{
		if (StringToInt(newValue) == 0)
		{
			g_bIsNoFallDmgEnabled = false;
		}
		else
		{
			g_bIsNoFallDmgEnabled = true;
		}
	} 
	else if (convar == sdb_fastheavy_enabled) 
	{
		if (StringToInt(newValue) == 0)
		{
			g_bIsFastHeayEnabled = false;
		}
		else
		{
			g_bIsFastHeayEnabled = true;
		}
	}
	else if (convar == sdb_swapteam_enabled)
	{
		if (StringToInt(newValue) == 0)
		{
			g_bIsSwapTeamEnabled = false;
		}
		else
		{
			g_bIsSwapTeamEnabled = true;
		}
	} 
	else if (convar == sdb_chatcolor) 
	{
		Format(g_sChatColor, sizeof(g_sChatColor), "%s", newValue);
	}
	else if (convar == sdb_uberlevel) 
	{
		g_fUberLevel = StringToFloat(newValue);
	}
	else if (convar == sdb_healthcount) 
	{
		g_iHealthCount = StringToInt(newValue);
	}
	else if (convar == sdb_healthbonus) 
	{
		g_iHealthBonus = StringToInt(newValue);
	}
	else if (convar == sdb_heavymultiplier) 
	{
		g_fHeavyMultiplier = StringToFloat(newValue);
	}
}

stock LoadUpVariables()
{
	g_bIsEnabled = GetConVarBool(sdb_enabled);
	g_bIsJoinSoundEnabled = GetConVarBool(sdb_enabled);
	g_bIsJoinPubMsgEnabled = GetConVarBool(sdb_enabled);
	g_bIsJoinPrivMsgEnabled = GetConVarBool(sdb_enabled);
	g_bIsChatColorsEnabled = GetConVarBool(sdb_enabled);
	g_bIsImmuntyEnabled = GetConVarBool(sdb_enabled);
	g_bIsUberChargeEnabled = GetConVarBool(sdb_enabled);
	g_bIsGiveHealthEnabled = GetConVarBool(sdb_enabled);
	g_bIsNoFallDmgEnabled = GetConVarBool(sdb_enabled);
	g_bIsFastHeayEnabled = GetConVarBool(sdb_enabled);
	g_bIsSwapTeamEnabled = GetConVarBool(sdb_enabled);
	GetConVarString(sdb_donationflag, g_sCharDonatorFlag, sizeof(g_sCharDonatorFlag));
	GetConVarString(sdb_soundfile, g_sSoundFile, sizeof(g_sSoundFile));
	GetConVarString(sdb_chatcolor, g_sChatColor, sizeof(g_sChatColor));
	g_bRoundEnd = false;
	g_iHealthBonus = GetConVarInt(sdb_healthbonus);
	g_iHealthCount = GetConVarInt(sdb_healthcount);
	g_fHeavyMultiplier = GetConVarFloat(sdb_heavymultiplier);
	g_fUberLevel = GetConVarFloat(sdb_uberlevel);
}

stock PrepSoundFile()
{
	decl String:buffer[PLATFORM_MAX_PATH];
	PrecacheSound(g_sSoundFile, true);
	Format(buffer, sizeof(buffer), "sound/%s", g_sSoundFile);
	AddFileToDownloadsTable(buffer);
}

stock CleanUpPlayer(client)
{
	g_aPlayers[client][bIsDonator] = false;
	g_aPlayers[client][bQueue] = false;
	g_aPlayers[client][bImmune] = false;
	g_aPlayers[client][iNewTeam] = 0;
	g_aPlayers[client][iHealthCount] = 0;
}

stock ProcessRoundEndImmunity(bool:give)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (g_aPlayers[i][bIsDonator])
		{
			if (give)
			{
				SetEntProp(i, Prop_Data, "m_takedamage", 0, 1);
				g_aPlayers[i][bImmune] = true;
			}
			else 
			{
				SetEntProp(i, Prop_Data, "m_takedamage", 2, 1);
				g_aPlayers[i][bImmune] = false;
			}
		}
	}
}

stock FormatMessage(iClient, iTeam, bool:bAlive, String:sChatMsg[], const Sting:sMessage[])
{
	decl String:sDead[10],
		 String:sTeam[10],
		 String:sClientName[64];
	GetClientName(iClient, sClientName, sizeof(sClientName));
	if (iTeam != 0)
		Format(sTeam, sizeof(sTeam), "(TEAM) ");
	else
		Format(sTeam, sizeof(sTeam), "");
	if (bAlive)
		Format(sDead, sizeof(sDead), "");
	else
		Format(sDead, sizeof(sDead), "*DEAD* ");
	if (StrContains(g_sChatColor, "light", false) == -1)
		Format(sChatMsg, CHAT_MAX_MESSAGE_LENGTH, "\x01%s%s\x03%s \x01:  \x05%s", sDead, sTeam, sClientName, sMessage);
	else
		Format(sChatMsg, CHAT_MAX_MESSAGE_LENGTH, "\x01%s%s\x03%s \x01:  \x04%s", sDead, sTeam, sClientName, sMessage);
}

stock SayText2(target, author, const String:message[]) 
{
	new Handle:hBf;
	if (target == 0)
		hBf = StartMessageAll("SayText2");
	else
		hBf = StartMessageOne("SayText2", target);
	if (hBf != INVALID_HANDLE)
	{
		BfWriteByte(hBf, author);
		BfWriteByte(hBf, true);
		BfWriteString(hBf, message);
		EndMessage();
	}
}

stock ProcessAdmins()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (SM_IsValidAdmin(i, g_sCharDonatorFlag))
		{
			g_aPlayers[i][bDonator] = true;
		}
		else
		{
			g_aPlayers[i][bDonator] = false;
		}
	}
}

stock ProcessLate()
{
	if (g_bIsEnabled)
	{
		ProcessAdmins();
		PrepSoundFile();
		if (g_bRoundEnd && g_bIsImmuntyEnabled)
		{
			ProcessRoundEndImmunity(true);
		}
		if (!g_bIsImmuntyEnabled)
		{
			ProcessRoundEndImmunity(false);
		}
	} 
	else
	{
		ProcessRoundEndImmunity(false);
	}
}

public Menu_SwapMode(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select) {
		new String:sSelection[64];
		GetMenuItem(menu, param2, sSelection, 64);
		if (StringToInt(sSelection))
			g_aPlayers[param1][bQueue] = false;
		else
			g_aPlayers[param1][bQueue] = true;
		if (!g_aPlayers[param1][bQueue])
			SM_MovePlayer(param1, g_aPlayers[param1][iNewTeam]);
	} else if (action == MenuAction_End)
		CloseHandle(menu);
	return;
}

public Menu_SelectPlayer(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select) {
		new String:sSelection[256];
		GetMenuItem(menu, param2, sSelection, sizeof(sSelection));
		new iTarget = GetClientOfUserId(StringToInt(sSelection));
		if (g_aPlayers[iTarget][bIsDonator])
			g_aPlayers[iTarget][bIsDonator] = false;
		else
			g_aPlayers[iTarget][bIsDonator] = true;
	} else if (action == MenuAction_End)
		CloseHandle(menu);
	return;
}

stock Handle:BuildSwapModeMenu()
{
	new Handle:menu = CreateMenu(Menu_SwapMode);
	SetMenuTitle(menu, "Select When to Swap:");
	AddMenuItem(menu, "0", "Instantly (Kills)");
	AddMenuItem(menu, "1", "Queue on next death");
	SetMenuExitBackButton(menu, false);
	return menu;
}

stock Handle:BuildPlayerMenu()
{
	new Handle:menu = CreateMenu(Menu_SelectPlayer);
	AddTargetsToMenu(menu, 0, true, false);
	SetMenuTitle(menu, "Select A Player:");
	SetMenuExitBackButton(menu, true);
	return menu;
}

public Action:Command_TEST(client, args)
{

}