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

#include <smlib/clients>

public Client_FlipSentry(client)
{
	new maxentities = GetMaxEntities();
	for (new i = MaxClients+1; i <= maxentities; i++)
	{
		if (!IsValidEntity(i))
			continue;

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if (!strcmp(netclass, "CObjectSentrygun") && GetEntDataEnt2(i, FindSendPropOffs("CObjectSentrygun","m_hBuilder")) == client)
		{
			new losing_team = GetClientTeam(client);
			new oPlayer = GetOppositeTeamMember(losing_team);
			if (!IsValidClient(oPlayer, false))
			{
				return;
			}
			
			new Float:fLocation[3], Float:fAngle[3];
			GetEntDataVector(i, FindSendPropOffs("CObjectSentrygun","m_vecOrigin"), fLocation);
			GetEntDataVector(i, FindSendPropOffs("CObjectSentrygun","m_angRotation"), fAngle);
			new iUpgradeLevel = GetEntProp(i, Prop_Send, "m_iUpgradeLevel");
			RemoveEdict(i);
			TF2_BuildSentry(oPlayer, fLocation, fAngle, iUpgradeLevel);
			break;
		}
    }
}

stock GetOppositeTeamMember(team)
{
	new TeamFilter = TFTeam:team == TFTeam_Red ? CLIENTFILTER_TEAMONE : CLIENTFILTER_TEAMTWO;
	new Filters = TeamFilter|CLIENTFILTER_INGAME|CLIENTFILTER_NOSPECTATORS|CLIENTFILTER_NOOBSERVERS;
	return Client_GetRandom(Filters);
}

//Not my code, credit goes to The JCS and Muridas
stock TF2_BuildSentry(iBuilder, Float:fOrigin[3], Float:fAngle[3], iLevel=1)
{
	new Float:fBuildMaxs[3];
	fBuildMaxs[0] = 24.0;
	fBuildMaxs[1] = 24.0;
	fBuildMaxs[2] = 66.0;

	new Float:fMdlWidth[3];
	fMdlWidth[0] = 1.0;
	fMdlWidth[1] = 0.5;
	fMdlWidth[2] = 0.0;
    
	decl String:sModel[64]; 
	new iTeam = GetClientTeam(iBuilder);
	new iShells, iHealth, iRockets;

	if(iLevel == 1)
	{
		sModel = "models/buildables/sentry1.mdl";
		iShells = 100;
		iHealth = 200;
	}
	else if(iLevel == 2)
	{
		sModel = "models/buildables/sentry2.mdl";
		iShells = 120;
		iHealth = 230;
	}
	else if(iLevel == 3)
	{
		sModel = "models/buildables/sentry3.mdl";
		iShells = 144;
		iHealth = 250;
		iRockets = 20;
	}
    
	new iSentry = CreateEntityByName("obj_sentrygun");  
	DispatchSpawn(iSentry);
	TeleportEntity(iSentry, fOrigin, fAngle, NULL_VECTOR);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_flAnimTime"), 51, 4, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_nNewSequenceParity"), 4, 4, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_nResetEventsParity"), 4, 4, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_iAmmoShells"), iShells, 4, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_iMaxHealth"), iHealth, 4, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_iHealth"), iHealth, 4, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_bBuilding"), 0, 2, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_bPlacing"), 0, 2, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_bDisabled"), 0, 2, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_iObjectType"), 3, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_iState"), 1, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_iUpgradeMetal"), 0, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_bHasSapper"), 0, 2, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_nSkin"), (iTeam-2), 1, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_bServerOverridePlacement"), 1, 1, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_iUpgradeLevel"), iLevel, 4, true);
	SetEntData(iSentry, FindSendPropOffs("CObjectSentrygun","m_iAmmoRockets"), iRockets, 4, true);   
	SetEntDataEnt2(iSentry, FindSendPropOffs("CObjectSentrygun","m_nSequence"), 0, true);
	SetEntDataEnt2(iSentry, FindSendPropOffs("CObjectSentrygun","m_hBuilder"), iBuilder, true);
	SetEntDataFloat(iSentry, FindSendPropOffs("CObjectSentrygun","m_flCycle"), 0.0, true);
	SetEntDataFloat(iSentry, FindSendPropOffs("CObjectSentrygun","m_flPlaybackRate"), 1.0, true);
	SetEntDataFloat(iSentry, FindSendPropOffs("CObjectSentrygun","m_flPercentageConstructed"), 1.0, true);
	SetEntDataVector(iSentry, FindSendPropOffs("CObjectSentrygun","m_vecOrigin"), fOrigin, true);
	SetEntDataVector(iSentry, FindSendPropOffs("CObjectSentrygun","m_angRotation"), fAngle, true);
	SetEntDataVector(iSentry, FindSendPropOffs("CObjectSentrygun","m_vecBuildMaxs"), fBuildMaxs, true);
	SetEntDataVector(iSentry, FindSendPropOffs("CObjectSentrygun","m_flModelWidthScale"), fMdlWidth, true);
	SetVariantInt(iTeam);
	AcceptEntityInput(iSentry, "TeamNum", -1, -1, 0);
	SetVariantInt(iTeam);
	AcceptEntityInput(iSentry, "SetTeam", -1, -1, 0);    
	SetEntityModel(iSentry,sModel);
	return iSentry;
}