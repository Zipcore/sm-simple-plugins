/************************************************************************
*************************************************************************
[TF2] RoundEnd Fun
Description:
	Provides some fun at the end of the round
*************************************************************************
*************************************************************************
This file is part of Simple Plugins project.

This plugin is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or any later version.

This plugin is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this plugin.  If not, see <http://www.gnu.org/licenses/>.
*************************************************************************
*************************************************************************
File Information
$Id: simple-roundimmunity.sp 55 2009-10-10 08:39:11Z antithasys $
$Author: antithasys $
$Revision: 55 $
$Date: 2009-10-10 03:39:11 -0500 (Sat, 10 Oct 2009) $
$LastChangedBy: antithasys $
$LastChangedDate: 2009-10-10 03:39:11 -0500 (Sat, 10 Oct 2009) $
$URL: https://sm-simple-plugins.googlecode.com/svn/trunk/Simple%20Round%20Immunity/addons/sourcemod/scripting/simple-roundimmunity.sp $
$Copyright: (c) Simple Plugins 2008-2009$
*************************************************************************
*************************************************************************
*/

#define PLUGIN_VERSION "2.0.0"

public Plugin:myinfo =
{
	name = "[TF2] RoundEnd Fun",
	author = "Simple Plugins",
	description = "Provides some fun at the end of the round",
	version = PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
}

#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#undef REQUIRE_EXTENSIONS
#undef AUTOLOAD_EXTENSIONS
#include <clientprefs>
#define REQUIRE_EXTENSIONS
#define AUTOLOAD_EXTENSIONS

enum EndRoundInfo
{
	bool:InFunTime,
	TFTeam:Won,
	TFTeam:Lost
};

new Handle:gCvar_mpBonusRoundTime = INVALID_HANDLE;
new Float:g_fBonusRoundTime = 0.0;
new bool:g_bUseClientprefs = false;
new g_FunTime[EndRoundInfo];

#include "simple-plugins/sp_common.sp"
#include "simple-plugins/ref_prophunt.sp"
#include "simple-plugins/ref_music.sp"
#include "simple-plugins/ref_config.sp"
//#include "simple-plugins/ref_clientprefs.sp"
#include "simple-plugins/ref_effects.sp"
#include "simple-plugins/ref_flipsentries.sp"
#include "simple-plugins/ref_friendlyfire.sp"
#include "simple-plugins/ref_godmode.sp"
#include "simple-plugins/ref_noblock.sp"
#include "simple-plugins/ref_powerplay.sp"
#include "simple-plugins/ref_respawn.sp"
#include "simple-plugins/ref_unlimitedammo.sp"

public OnPluginStart()
{
	CreateConVar("sref_version", PLUGIN_VERSION, "Simple RoundEnd Fun", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_CurrentMod = GetCurrentMod();
	LoadCurrentTeams();
	ProcessConfigFile();
	
	if (g_CurrentMod == GameType_TF)
	{
		HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_Post);
		HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
		HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
		HookEvent("player_changeclass", Event_PlayerChangeClass, EventHookMode_Post);
	}
	else
	{
		SetFailState("Plugin only supports Team Fortress 2");
	}
	
	gCvar_mpBonusRoundTime = FindConVar("mp_bonusroundtime");
	if (gCvar_mpBonusRoundTime == INVALID_HANDLE)
	{
		LogError("Could not locate cvar mp_bonusroundtime");
		SetFailState("Could not locate cvar mp_bonusroundtime");
	}
	else
	{
		HookConVarChange(gCvar_mpBonusRoundTime, BonusRoundTimeChanged);
	}
	
	if (GetConfigValue("clientprefs"))
	{
		decl String:sExtError[256];
		new iExtStatus = GetExtensionFileStatus("clientprefs.ext", sExtError, sizeof(sExtError));
		if (iExtStatus == -2)
		{
			LogError("Client Preferences extension was not found.");
			LogError("Plugin continued to load, but that feature will not be used.");
			g_bUseClientprefs = false;
		}
		if (iExtStatus == -1 || iExtStatus == 0)
		{
			LogError("Client Preferences extension is loaded with errors.");
			LogError("Status reported was [%s].", sExtError);
			LogError("Plugin continued to load, but that feature will not be used.");
			g_bUseClientprefs = false;
		}
		if (iExtStatus == 1)
		{
			LogError("Client Preferences extension is loaded, checking database.");
			if (!SQL_CheckConfig("clientprefs"))
			{
				LogError("No 'clientprefs' database found.  Check your database.cfg file.");
				LogError("Plugin continued to load, but Client Preferences will not be used.");
				g_bUseClientprefs = false;
			}
			g_bUseClientprefs = true;
			//CreateGlobalCookieHandles();
		}
	}
	
	RegAdminCmd("sm_testfeature", Command_TestFeature, ADMFLAG_ROOT, "Test a feature of Round End Fun");
	
	LoadTranslations("common.phrases");
}

public OnConfigsExecuted()
{
	g_fBonusRoundTime = GetConVarFloat(gCvar_mpBonusRoundTime);
}

public OnClientDisconnect(client)
{
	Client_DisableFun(client);
}

public OnMapStart()
{
	PrecachePropHuntModels();
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetSettingValue("enabled"))
	{
		g_FunTime[Won] = TFTeam:GetEventInt(event, "team");
		g_FunTime[Lost] = (g_FunTime[Won] == TFTeam_Red) ? TFTeam_Blue : TFTeam_Red;
		g_FunTime[InFunTime] = true;
		CreateTimer(0.5, Timer_EnableFunTime);
		CreateTimer(FloatSub(g_fBonusRoundTime, 1.0), Timer_DisableFunTime);
	}
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetSettingValue("enabled") && GetSettingValue("prophunt_hitremove"))
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		
		if (!IsValidClient(client) || client == attacker)
		{
			return;
		}
		
		if (g_bIsPropModel[client])
		{
			Client_DisablePropHunt(client);
		}
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new deathflags = GetEventInt(event, "death_flags");
	if(deathflags & TF_DEATHFLAG_DEADRINGER)
	{
		return;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidClient(client))
	{
		if (g_bIsPropModel[client])
		{
			Client_DisablePropHunt(client);
		}
		if (g_aPlayer_Respawn[client])
		{
			TF2_RespawnPlayer(client);
		}
	}
}

public Event_PlayerChangeClass(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (GetSettingValue("enabled") && g_FunTime[InFunTime]) 
	{
		Client_EnableFun(client);
	}
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon,
	Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (g_FunTime[InFunTime] && GetSettingValue("enabled"))
	{
		new TFTeam:aTeam = TFTeam:GetClientTeam(attacker);
		new TFTeam:vTeam = TFTeam:GetClientTeam(victim);
		
		if (GetSettingValue("ff_enabled"))
		{
			if (aTeam == vTeam)
			{
				if (GetSettingValue("ff_adminvsadminonly")
				&& (!IsAuthorized(attacker, "ff_adminflag") 
					|| !IsAuthorized(victim, "ff_adminflag")))
				{
					damage = 0.0;
				}
			}
		}
		
		if (GetSettingValue("prophunt_enabled") 
		&& GetSettingValue("prophunt_hitremove") 
		&& aTeam != vTeam
		&& g_bIsPropModel[victim])
		{
			Client_DisablePropHunt(victim);
		}
		
		if (GetSettingValue("flip_enabled"))
		{		
			decl String:sBuffer[32];
			GetEdictClassname(weapon, sBuffer, sizeof(sBuffer));
			if (StrEqual(sBuffer, "obj_sentrygun"))
			{
				//Still not done... need to check if this sentry is one that was flipped...
				GetTrieString(g_hSettings, "flip_damage", sBuffer, sizeof(sBuffer));
				new Float:sentry_damage = FloatDiv(damage, StringToFloat(sBuffer));
				damage = sentry_damage;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Timer_EnableFunTime(Handle:timer)
{
	Client_EnableFunAll();
}

public Action:Timer_DisableFunTime(Handle:timer)
{
	g_FunTime[Won] = TFTeam_Unassigned;
	g_FunTime[Lost] = TFTeam_Unassigned;
	g_FunTime[InFunTime] = false;
	Client_DisableFunAll();
}

public Action:Command_TestFeature(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "sm_testfeature <function> <parameters...>");
		return Plugin_Handled;
	}
	
	decl String:arg1[128];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	new Handle:pl = GetMyHandle();
	new Function:func = GetFunctionByName(pl, arg1);
	if (func != INVALID_FUNCTION)
	{
		new dummyreturn;
		Call_StartFunction(pl, func);
		if (StrContains(arg1, "Client_") != -1)
		{
			decl String:arg2[128];
			GetCmdArg(2, arg2, sizeof(arg2));
			
			decl String:target_name[MAX_TARGET_LENGTH];
			decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
			
			if ((target_count = ProcessTargetString(
							arg2,
							client,
							target_list,
							MAXPLAYERS,
							COMMAND_FILTER_NO_MULTI,
							target_name,
							sizeof(target_name),
							tn_is_ml)) <= 0)
			{
				ReplyToTargetError(client, target_count);
				CloseHandle(pl);
				return Plugin_Handled;
			}
			
			Call_PushCell(target_list[0]);
			
			if (StrEqual(arg1, "Client_EnableGodMode"))
			{
				if (args < 3)
				{
					ReplyToCommand(client, "[SM] Invalid Parameter");
					ReplyToCommand(client, "sm_testfeature <function> <parameters...>");
					CloseHandle(pl);
					return Plugin_Handled;
				}
				decl String:arg3[32];
				GetCmdArg(3, arg3, sizeof(arg3));
				Call_PushCell(StringToInt(arg3));
			}
			else if (StrEqual(arg1, "Client_EnablePropHunt"))
			{
				if (args < 3)
				{
					ReplyToCommand(client, "[SM] Invalid Parameter");
					ReplyToCommand(client, "sm_testfeature <function> <parameters...>");
					CloseHandle(pl);
					return Plugin_Handled;
				}
				
				decl String:arg3[32];
				GetCmdArg(3, arg3, sizeof(arg3));
				Call_PushFloat(StringToFloat(arg3));
			}
			
			Call_Finish(dummyreturn);
		}
		else
		{
			ReplyToCommand(client, "[SM] Invalid Function");
			ReplyToCommand(client, "sm_testfeature <function> <parameters...>");
		}
	}
		
	CloseHandle(pl);
	return Plugin_Handled;
}

stock Client_EnableFun(client)
{
	new TFTeam:team = TFTeam:GetClientTeam(client);
	if (team < TFTeam_Red)
	{
		return;
	}
	
	new bool:bLoser = TFTeam:GetClientTeam(client) == g_FunTime[Won] ? true : false;
	if (team == bLoser)
	{
		if (GetSettingValue("flip_enabled"))
		{
			if (!GetSettingValue("flip_notadmins") 
				|| (GetSettingValue("flip_notadmins") && !IsAuthorized(client, "flip_adminflag")))
			{
				Client_FlipSentry(client);
			}
		}
		if (GetSettingValue("god_enabled"))
		{
			if (IsAuthorized(client, "god_adminflag"))
			{
				Client_EnableGodMode(client, true);
			}
		}
		if (GetSettingValue("prophunt_enabled"))
		{
			if (!GetSettingValue("prophunt_adminonly") 
				|| (GetSettingValue("prophunt_adminonly") && IsAuthorized(client, "prophunt_adminflag")))
			{
				decl String:sBuffer[16];
				GetTrieString(g_hSettings, "prophunt_gravity", sBuffer, sizeof(sBuffer));
				new Float:fGravity = StringToFloat(sBuffer);
				Client_EnablePropHunt(client, fGravity);
			}
		}
		else
		{
			if (GetSettingValue("effects_enabled"))
			{
				//Client_EnableEffects(client);
			}
			if (GetSettingValue("powerplay_enabled") && GetSettingValue("powerplay_loser"))
			{
				if (!GetSettingValue("powerplay_adminonly") 
					|| (GetSettingValue("powerplay_adminonly") && IsAuthorized(client, "powerplay_adminflag")))
				{
					Client_EnablePowerPlay(client);
				}
			}
		}
	}
	else
	{
		if (GetSettingValue("powerplay_enabled") && GetSettingValue("powerplay_winner"))
		{
			if (!GetSettingValue("powerplay_adminonly") 
				|| (GetSettingValue("powerplay_adminonly") && IsAuthorized(client, "powerplay_adminflag")))
			{
				Client_EnablePowerPlay(client);
			}
		}
		if (GetSettingValue("unlimitedammo_enabled"))
		{
			if (!GetSettingValue("unlimitedammo_adminonly") 
				|| (GetSettingValue("unlimitedammo_adminonly") && IsAuthorized(client, "unlimitedammo_adminflag")))
			{
				Client_EnableUnlimitedAmmo(client);
			}
		}
		if (GetSettingValue("effects_enabled"))
		{
			//Client_EnableEffects(client);
		}
	}
	
	if (GetSettingValue("noblock_enabled"))
	{
		if (!GetSettingValue("noblock_adminonly") 
			|| (GetSettingValue("noblock_adminonly") && IsAuthorized(client, "noblock_adminflag")))
		{
			Client_EnableNoBlock(client);
		}
	}
	if (GetSettingValue("respawn_enabled"))
	{
		if ((!GetSettingValue("respawn_adminonly") && !GetSettingValue("respawn_guestonly"))
			|| (GetSettingValue("respawn_adminonly") && IsAuthorized(client, "respawn_adminflag"))
			|| (GetSettingValue("respawn_guestonly") && !IsAuthorized(client, "respawn_adminflag")))
		{
			Client_EnableRespawn(client);
		}
	}
}

stock Client_EnableFunAll()
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i)) 
		{
			Client_EnableFun(i);
		}
	}
}

stock Client_DisableFun(client)
{
	Client_DisableGodMode(client);
	Client_DisablePowerPlay(client);
	Client_DisableNoBlock(client);
	Client_DisablePropHunt(client);
	//Client_DisableEffects(client);
	Client_DisableUnlimitedAmmo(client);
}

stock Client_DisableFunAll()
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i)) 
		{
			Client_DisableFun(i);
		}
	}
}

stock GetSettingValue(const String:setting[])
{
	//need to deal with damage multipliers and stuff the client should not set
	if (GetConfigValue("clientprefs") && g_bUseClientprefs)
	{
		//return GetClientPrefValue(setting);
	}
	else
	{
		return GetConfigValue(setting);
	}
	return -1;
}

public BonusRoundTimeChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_fBonusRoundTime = StringToFloat(newValue);
}