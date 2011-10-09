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

#include <smlib/math>

#define INVIS			{ 255,255,255,0  	}
#define NORMAL			{ 255,255,255,255	}

#define ADD_PROPMODEL(%1,%2) PushArrayString(g_hModelNames, %1); PushArrayString(g_hModelPaths, %2)

new Handle:g_hModelNames = INVALID_HANDLE;
new Handle:g_hModelPaths = INVALID_HANDLE;

new bool:g_bIsPropModel[MAXPLAYERS+1] = { false, ... };

new g_oFOV = -1;
new g_oDefFOV = -1;
new g_iPropArraySize = -1;

public Client_EnablePropHunt(client, Float:gravity)
{
	if (g_oFOV == -1)
	{
		g_oFOV = FindSendPropOffs("CBasePlayer", "m_iFOV");
		g_oDefFOV = FindSendPropOffs("CBasePlayer", "m_iDefaultFOV");
		g_iPropArraySize = GetArraySize(g_hModelNames) - 1;
	}
	
	if (IsEntLimitReached())
	{
		return;
	}
	
	new index = Math_GetRandomInt(0, g_iPropArraySize);
	new String:sPath[PLATFORM_MAX_PATH], String:sName[128];
	GetArrayString(g_hModelNames, index, sName, sizeof(sName));
	GetArrayString(g_hModelPaths, index, sPath, sizeof(sPath));
	
	g_bIsPropModel[client] = true;
	Colorize(client, INVIS);
	SwitchView(client, true, false);
	StripWeapons(client);
	SetEntityGravity(client, gravity);

	SetVariantString(sPath);
	AcceptEntityInput(client, "SetCustomModel");
	SetVariantInt(1);
	AcceptEntityInput(client, "SetCustomModelRotates");
	
	PrintToChat(client,"\x01You are disguised as a \x04%s\x01 Go hide!", sName);
}

public Client_DisablePropHunt(client)
{
	if (g_oFOV == -1)
	{
		g_oFOV = FindSendPropOffs("CBasePlayer", "m_iFOV");
		g_oDefFOV = FindSendPropOffs("CBasePlayer", "m_iDefaultFOV");
		g_iPropArraySize = GetArraySize(g_hModelNames) - 1;
	}
	
	if (IsValidEntity(client))
	{
		SetVariantString("");
		AcceptEntityInput(client, "SetCustomModel");
		Colorize(client, NORMAL);
		SwitchView(client, false, true);
		SetEntityGravity(client, 1.0);
	}
	
	g_bIsPropModel[client] = false;
}

stock PrecachePropHuntModels()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	for(new i = 0; i < GetArraySize(g_hModelNames); i++)
	{
		GetArrayString(g_hModelPaths, i, sPath, sizeof(sPath));
		PrecacheModel(sPath, true);
	} 
}

stock SwitchView(target, bool:observer, bool:viewmodel)
{	
	SetEntPropEnt(target, Prop_Send, "m_hObserverTarget", observer ? target : -1);
	SetEntProp(target, Prop_Send, "m_iObserverMode", observer ? 1 : 0);
	SetEntData(target, g_oFOV, observer ? 100 : GetEntData(target, g_oDefFOV, 4), 4, true);		
	SetEntProp(target, Prop_Send, "m_bDrawViewmodel", viewmodel ? 1 : 0);
}

stock Colorize(client, color[4])
{	
	new TFClassType:class = TF2_GetPlayerClass(client);
	
	//Colorize the wearables, such as hats
	SetWearablesRGBA_Impl(client, "tf_wearable_item", "CTFWearableItem",color);

	if(class == TFClass_DemoMan)
	{
		SetWearablesRGBA_Impl(client, "tf_wearable_item_demoshield", "CTFWearableItemDemoShield", color);
		TF2_RemoveCondition(client, TFCond_DemoBuff);
	}
}

stock SetWearablesRGBA_Impl(client,  const String:entClass[], const String:serverClass[], color[4])
{
	new ent = -1;
	while((ent = FindEntityByClassname(ent, entClass)) != -1)
	{
		if(IsValidEntity(ent))
		{		
			if(GetEntDataEnt2(ent, FindSendPropOffs(serverClass, "m_hOwnerEntity")) == client)
			{
				SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
				SetEntityRenderColor(ent, color[0], color[1], color[2], color[3]);
			}
		}
	}
}

stock StripWeapons(client) 
{
	if(IsClientInGame(client) && IsPlayerAlive(client)) 
	{
		for(new x = 0; x <= 5; x++)
		{
			TF2_RemoveWeaponSlot(client, x);
		}
	}
}

stock bool:IsEntLimitReached()
{
	new maxents = GetMaxEntities();
	new i, c = 0;
	
	for(i = MaxClients; i <= maxents; i++)
	{
		if(IsValidEntity(i))
		c += 1;
	}
		
	if (c >= (maxents-32))
	{
		PrintToServer("Warning: Entity limit is nearly reached! Please switch or reload the map!");
		LogError("Entity limit is nearly reached: %d/%d", c, maxents);
		return true;
	}
	
	return false;
}