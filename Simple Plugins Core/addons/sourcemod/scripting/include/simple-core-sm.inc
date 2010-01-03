/************************************************************************
*************************************************************************
Simple Plugins SourceMod Core Include File
Description:
Core SourceMod include file for the Simple Plugins project.
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
#if defined _simple_core_sm_included
	#endinput
#endif

#define _simple_core_sm_included

#define IN  (0x0001 | 0x0010)
#define OUT (0x0002 | 0x0008)

new g_FilteredEntity = -1;

stock bool:RemovePunctuation(String:input[], String:buffer[], maxlength)
{
	new len = strlen(input);
	new bool:found;
	for (new i=len-1; i >= 0; i--)
	{
		if (!IsCharAlpha(input[i]))
		{
			decl String:sBuffer[32];
			strcopy(sBuffer, sizeof(sBuffer), buffer);
			Format(buffer, maxlength, "%s%s", sBuffer, input[i]);
			input[i] = '\0';
			found = true;
		}
	}
	return found;
}

stock bool:IsValidClient(client) 
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || IsFakeClient(client)) 
    { 
      return false; 
    } 
    return IsClientInGame(client); 
}

stock ClearTimer(&Handle:timer)
{
	if (timer != INVALID_HANDLE)
	{
		KillTimer(timer);
	}
	timer = INVALID_HANDLE;
}

stock bool:EdictEqual(ent, const String:name[])
{
	if (ent != -1 && IsValidEdict(ent))
	{
		new String:edictName[32];
		GetEdictClassname( ent, edictName, sizeof(edictName));
		return StrEqual(edictName, name);
	}
	return false;
}

stock bool:CanSeeTarget( any:origin, Float:pos[3], any:target, Float:targetPos[3], Float:range, bool:throughPlayer=true, bool:throughBuild=true)
{
	new Float:distance;
	
	distance = GetVectorDistanceMeter(pos, targetPos);
	if (distance >= range)
	{
		return false;
	}
	
	new Handle:TraceEx = INVALID_HANDLE;
	new hitEnt = -1;
	new Float:hitPos[3];
	g_FilteredEntity = origin;
	TraceEx = TR_TraceRayFilterEx(pos, targetPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter);
	hitEnt = TR_GetEntityIndex(TraceEx);
	TR_GetEndPosition(hitPos, TraceEx);
	if (GetVectorDistanceMeter( hitPos, targetPos) <= 1.0 )
	{
		if (throughPlayer)
		{
			new String:edictName[64];
			GetEdictClassname( hitEnt, edictName, sizeof(edictName)); 
			if(StrEqual(edictName, "player"))  
			{
				GetEntPropVector( hitEnt, Prop_Data, "m_vecAbsOrigin", pos);
				if (GetVectorDistanceMeter(pos, targetPos) > 1.0)
				{
					g_FilteredEntity = hitEnt;
					TraceEx = TR_TraceRayFilterEx( hitPos, targetPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter);
					hitEnt = TR_GetEntityIndex(TraceEx);
					TR_GetEndPosition(hitPos, TraceEx);
				}
				else
				{
					pos = targetPos;
				}
			}
		}		
		if (throughBuild)
		{
			new String:edictName[64];
			GetEdictClassname(hitEnt, edictName, sizeof(edictName)); 
			if (StrEqual(edictName, "obj_dispenser")
			|| StrEqual(edictName, "obj_sentrygun") 
			||	StrEqual(edictName, "obj_teleporter_entrance") 
			||	StrEqual(edictName, "obj_teleporter_exit")
			||	StrEqual(edictName, "obj_attachment_sapper")
			)
			{
				GetEntPropVector(hitEnt, Prop_Data, "m_vecAbsOrigin", pos);
				if (GetVectorDistanceMeter(pos, targetPos) > 1.0)
				{
					g_FilteredEntity = hitEnt;
					TraceEx = TR_TraceRayFilterEx( hitPos, targetPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter);
					hitEnt = TR_GetEntityIndex(TraceEx);
					TR_GetEndPosition(hitPos, TraceEx);
				}
				else
				{
					pos = targetPos;
				}
			}
		}		
	}
	if (GetVectorDistanceMeter(hitPos, targetPos) <= 1.0)
	{
		return true;
	}
	return false;
}

stock bool:IsEntLimitReached()
{
	new maxclients = GetMaxClients();
	new maxents = GetMaxEntities();
	new i, c = 0;
	for (i = maxclients; i <= maxents; i++)
	{
		if (IsValidEntity(i))
			c += 1;
	}
	if (c >= (maxents-16))
	{
		PrintToServer("Warning: Entity limit is nearly reached! Please switch or reload the map!");
		LogError("Entity limit is nearly reached: %d/%d", c, maxents);
		return true;
	}
	else
	return false;
}

public bool:TraceFilter(ent, contentMask)
{
	return (ent == g_FilteredEntity) ? false : true;
}

stock Float:UnitToMeter(Float:distance)
{
	return distance / 50.00;
}

stock Float:MeterToUnit(Float:distance)
{
	return distance * 50.00;
}

stock Float:GetVectorDistanceMeter(const Float:vec1[3], const Float:vec2[3], bool:squared=false) 
{
	return UnitToMeter( GetVectorDistance( vec1, vec2, squared ) );
}

stock PrePlayParticle(String:particlename[])
{
	if (IsValidEntity(0))
	{
		new particle = CreateEntityByName("info_particle_system");
		if (IsValidEdict(particle))
		{
			new String:tName[32];
			GetEntPropString(0, Prop_Data, "m_iName", tName, sizeof(tName));
			DispatchKeyValue(particle, "targetname", "tf2particle");
			DispatchKeyValue(particle, "parentname", tName);
			DispatchKeyValue(particle, "effect_name", particlename);
			DispatchSpawn(particle);
			SetVariantString(tName);
			AcceptEntityInput(particle, "SetParent", 0, particle, 0);
			ActivateEntity(particle);
			AcceptEntityInput(particle, "start");
			CreateTimer(0.01, DeleteParticles, particle);
		}
	}
}

stock ShowParticle(String:particlename[], Float:time, Float:pos[3], Float:ang[3]=NULL_VECTOR)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
	else
	{
		LogError("ShowParticle: could not create info_particle_system");
	}	
}

stock any:ShowParticleEntity(ent, String:particleType[], Float:time, Float:addPos[3]=NULL_VECTOR, Float:addAngle[3]=NULL_VECTOR)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		new Float:pos[3];
		new Float:ang[3];
		new String:tName[32];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
		AddVectors(pos, addPos, pos);
		GetEntPropVector(ent, Prop_Send, "m_angRotation", ang);
		AddVectors(ang, addAngle, ang);
		
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName);
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);
		SetVariantString(tName);
		//AcceptEntityInput(particle, "SetParent", ent, particle, 0);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
	else
	{
		LogError("AttachParticle: could not create info_particle_system");
	}
	
	return particle;
}

stock AttachParticle(ent, String:particleType[], Float:time, Float:addPos[3]=NULL_VECTOR, Float:addAngle[3]=NULL_VECTOR)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		new Float:pos[3];
		new Float:ang[3];
		new String:tName[32];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
		AddVectors(pos, addPos, pos);
		GetEntPropVector(ent, Prop_Send, "m_angRotation", ang);
		AddVectors(ang, addAngle, ang);
		
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName);
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);
		SetVariantString("!activator");
		AcceptEntityInput(particle, "SetParent", ent, particle, 0);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
	else
	{
		LogError("AttachParticle: could not create info_particle_system");
	}
}

stock AttachParticleBone(ent, String:particleType[], String:attachBone[], Float:time, Float:addPos[3]=NULL_VECTOR, Float:addAngle[3]=NULL_VECTOR)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		new String:tName[32];
		GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName);
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);
		SetVariantString("!activator");
		AcceptEntityInput(particle, "SetParent", ent, ent, 0);
		SetVariantString(attachBone);
		AcceptEntityInput(particle, "SetParentAttachment", particle, particle, 0);
		ActivateEntity(particle);
		
		TeleportEntity(particle, addPos, addAngle, NULL_VECTOR);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
}

stock any:AttachLoopParticle(ent, String:particleType[], Float:addPos[3]=NULL_VECTOR, Float:addAngle[3]=NULL_VECTOR)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		new Float:pos[3];
		new Float:ang[3];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
		AddVectors(pos, addPos, pos);
		GetEntPropVector(ent, Prop_Send, "m_angRotation", ang);
		AddVectors(ang, addAngle, ang);
		
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		new String:tName[32];
		GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName);
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);
		SetVariantString("!activator");
		AcceptEntityInput(particle, "SetParent", ent, ent, 0);
		//		SetVariantString(attachBone);
		//		AcceptEntityInput(particle, "SetParentAttachment", particle, particle, 0);
		ActivateEntity(particle);
		
		AcceptEntityInput(particle, "start");
	}
	return particle;
}

stock any:AttachLoopParticleBone(ent, String:particleType[], String:attachBone[], Float:addPos[3]=NULL_VECTOR, Float:addAngle[3]=NULL_VECTOR)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		new String:tName[32];
		GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName);
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);
		SetVariantString("!activator");
		AcceptEntityInput(particle, "SetParent", ent, ent, 0);
		SetVariantString(attachBone);
		AcceptEntityInput(particle, "SetParentAttachment", particle, particle, 0);
		ActivateEntity(particle);
		
		TeleportEntity(particle, addPos, addAngle, NULL_VECTOR);
		AcceptEntityInput(particle, "start");
	}
	return particle;
}

stock DeleteLoopParticle(any:particle, Float:delay = 0.0)
{
	if (particle != -1)
	{
		if (IsValidEdict(particle))
		{
			new String:classname[32];
			GetEdictClassname(particle, classname, sizeof(classname));
			if (StrEqual(classname, "info_particle_system", false))
			{
				ActivateEntity(particle);
				AcceptEntityInput(particle, "stop");
				CreateTimer(delay, DeleteParticles, particle);
			}
		}
	}
} 

public Action:DeleteParticles(Handle:timer, any:particle)
{
	if (IsValidEntity(particle))
	{
		new String:classname[32];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "stop");
			RemoveEdict(particle);
		}
	}
}

public ScreenFade(client, red, green, blue, alpha, duration, type)
{
	new Handle:msg;
	
	msg = StartMessageOne("Fade", client);
	BfWriteShort(msg, 255);
	BfWriteShort(msg, duration);
	BfWriteShort(msg, type);
	BfWriteByte(msg, red);
	BfWriteByte(msg, green);
	BfWriteByte(msg, blue);
	BfWriteByte(msg, alpha);
	EndMessage();
}

public Action:UnFade(Handle:timer, any:client)
{
	if (client)
	{
		if (IsClientInGame(client))
		{
			if (IsPlayerAlive(client))
			{
				ScreenFade(client, 0, 0, 0, 0, 2000, IN);
			}
		}
	}
}

stock StringToUpper(String:target[], String:source[])
{
	for (new i = 0; i < strlen(source); i++)
	{
		target[i] = CharToUpper(source[i]);		
	}
}

stock StringToLower(String:target[], String:source[])
{
	for (new i = 0; i < strlen(source); i++)
	{
		target[i] = CharToLower(source[i]);		
	}
}
