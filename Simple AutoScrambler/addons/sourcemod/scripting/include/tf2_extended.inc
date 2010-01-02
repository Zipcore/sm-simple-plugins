#if defined _tf2_extended_included
 #endinput
#endif
#define _tf2_extended_included

#tryinclude <tf2_stocks>

stock TF2_GetPlayerDominations(client)
{
	new offset = FindSendPropInfo("CTFPlayerResource", "m_iActiveDominations"),
		ent = FindEntityByClassname(-1, "tf_player_manager");
	if (ent != -1)
		return GetEntData(ent, (offset + client*4), 4);	
	return 0;
}

stock TF2_GetTeamDominations(team)
{
	new dominations;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == team)
			dominations += TF2_GetPlayerDominations(i);
	}
	return dominations;
}

/**
* checks if a client is only class
* @param client		=	client index
* @param class		= 	player class
* Valid Classes:
* TFClass_Medic; TFClass_Engineer; TFClass_Sniper; TFClass_Spy; TFClass_Heavy
* TFClass_Scout; TFClass_Demoman; TFClass_Soldier; TFClass_Pyro
*/

stock bool:TF2_IsClientOnlyClass(client, TFClassType:class)
{
	if (TFClassType:TF2_GetPlayerClass(client) != class)
		return false;
	new clientTeam = GetClientTeam(client);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == clientTeam && TFClassType:TF2_GetPlayerClass(i) == class)
			return false;
	}
	return true;
}

stock TF2_RemoveRagdolls()
{
	new iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "tf_ragdoll")) != -1)
		AcceptEntityInput(iEnt, "Kill");
}

stock bool:TF2_IsClientUberCharged(client)
{
	if (!IsPlayerAlive(client))
		return false;
	new TFClassType:class = TF2_GetPlayerClass(client);
	if (class == TFClass_Medic)
	{			
		new entityIndex = GetPlayerWeaponSlot(client, 1);
		new Float:chargeLevel = GetEntPropFloat(entityIndex, Prop_Send, "m_flChargeLevel");
		if (chargeLevel >= 0.40)				
			return true;				
	}
	return false;
}

stock bool:TF2_IsClientUbered(client)
{
	if (GetEntProp(client, Prop_Send, "m_nPlayerCond") & 32)
		return true;
	return false;
}

/**
valid buildings:
obj_sentrygun
obj_dispenser
obj_teleporter
*/
stock bool:TF2_DoesClientHaveBuilding(client, const String:building)
{
	new iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, building)) != -1)
	{
		if (GetEntDataEnt2(iEnt, FindSendPropInfo("CBaseObject", "m_hBuilder")) == client)
			return true;
	}
	return false;
}

stock bool:TF2_InSetup()
{
	iTimerEnt = FindEntityByClassname(-1, "team_round_timer");
	if (iTimerEnt != -1)
	{
		if (!GetEntProp(iTimerEnt, Prop_Send, "m_nState"))
			return true;
	}
	return false;
}

stock TF2_GetClientScore(client)
{	
	return TF2_GetPlayerResourceData(client, TFResource_TotalScore));
}

stock TF2_DestroyBuildings(client)
{
	
	/**
	We have to start a loop to check the owner of all the valid entities
	*/
	for (new i = MaxClients + 1; i <= g_iMaxEntities; i++)
	{
		if (!IsValidEntity(i))
		{
			
			/**
			Not valid, continue to next one
			*/
			continue;
		}
		
		/**
		Get the name of the current entity
		*/
		decl String:sNetClass[32];
		GetEntityNetClass(i, sNetClass, sizeof(sNetClass));
		
		/**
		See if its something that an engineer would build
		*/
		if (strcmp(sNetClass, "CObjectSentrygun") == 0 
		|| strcmp(sNetClass, "CObjectTeleporter") == 0 
		|| strcmp(sNetClass, "CObjectDispenser") == 0)
		{
		
			/**
			It is, so lets check the owner
			*/
			if (GetEntDataEnt2(i, g_iOwnerOffset) == client)
			{
				
				/**
				It's the clients building, so we blow it up.
				*/
				SetVariantInt(9999);
				AcceptEntityInput(i, "RemoveHealth");
			}
		}
	}
}