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

new g_aPlayer_UnlimitedAmmo[MAXPLAYERS + 1];

public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
	if (g_aPlayer_UnlimitedAmmo[client])
	{
		new ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType") * 4;
		new weaponindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		new offset_ammo = FindSendPropInfo("CBasePlayer", "m_iAmmo");
		new offset_clip = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
		new TFClassType:playerclass = TF2_GetPlayerClass(client);
		switch(playerclass)
		{
			case TFClass_Scout:
			{
				if(weaponindex == 448)
				{
					SetEntPropFloat(client, Prop_Send, "m_flHypeMeter", 100.0);
				}
				SetEntPropFloat(client, Prop_Send, "m_flEnergyDrinkMeter", 100.0);
				if(GetClientButtons(client) & IN_ATTACK2)
				{
					TF2_RemoveCondition(client, TFCond_Bonked); 
				}
			}
			case TFClass_Soldier:
			{
				if(GetEntPropFloat(client, Prop_Send, "m_flRageMeter") == 0.00)
				{
					SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 100.0);
				}
			}
			case TFClass_DemoMan:
			{
				if(!TF2_IsPlayerInCondition(client, TFCond_Charging))
				{
					SetEntPropFloat(client, Prop_Send, "m_flChargeMeter", 100.0);
				}
				if(weaponindex == 307)
				{
					SetEntProp(weapon, Prop_Send, "m_bBroken", 0);
					SetEntProp(weapon, Prop_Send, "m_iDetonated", 0);
				}
			}
			case TFClass_Engineer:
			{
				SetEntData(client, FindDataMapOffs(client, "m_iAmmo")+12, 200, 4);
			}
			case TFClass_Medic:
			{
				if((StrEqual(weaponname, "tf_weapon_medigun", false)) && GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel") == 0.00)
				{						
					SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", 1.00);
				}
			}
			case TFClass_Spy:
			{
				SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", 100.0);
			}
		}
		switch(weaponindex)
		{
			case 441,442:
			{
				SetEntPropFloat(weapon, Prop_Send, "m_flEnergy", 100.0);
			}
			case 141,525:
			{
				SetEntProp(client, Prop_Send, "m_iRevengeCrits", 99);
			}
		}
		SetEntData(weapon, offset_clip, 99, 4, true);
		SetEntData(client, ammotype+offset_ammo, 99, 4, true);
	}
	
	return Plugin_Continue;
}

public Client_EnableUnlimitedAmmo(client)
{
	g_aPlayer_UnlimitedAmmo[client] = true;
}

public Client_EnableUnlimitedAmmoAll()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			Client_EnableUnlimitedAmmo(i);
		}
	}
}

public Client_DisableUnlimitedAmmo(client)
{
	g_aPlayer_UnlimitedAmmo[client] = false;
	//need to reset the ammo to defaults
}

public Client_DisableUnlimitedAmmoAll()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			Client_DisableUnlimitedAmmo(i);
		}
	}
}