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

new Handle:gCvar_FriendlyFire = INVALID_HANDLE;
new Handle:gCvar_svTags = INVALID_HANDLE;

public EnableFF()
{
	if (gCvar_FriendlyFire == INVALID_HANDLE)
	{
		gCvar_FriendlyFire = FindConVar("mp_friendlyfire");
		gCvar_svTags = FindConVar("sv_tags");
	}
	new iFlags  = GetConVarFlags(gCvar_FriendlyFire);
	iFlags &= ~FCVAR_NOTIFY;
	SetConVarFlags(gCvar_FriendlyFire, iFlags);
	SetConVarInt(gCvar_FriendlyFire, 1);
}

public DisableFF()
{
	if (gCvar_FriendlyFire == INVALID_HANDLE)
	{
		gCvar_FriendlyFire = FindConVar("mp_friendlyfire");
		gCvar_svTags = FindConVar("sv_tags");
	}
	SetConVarInt(gCvar_FriendlyFire, 0);
	new iFlags  = GetConVarFlags(gCvar_FriendlyFire);
	iFlags = iFlags|FCVAR_NOTIFY;
	SetConVarFlags(gCvar_FriendlyFire, iFlags);
	CreateTimer(0.5, Timer_RemoveFFServerTag, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_RemoveFFServerTag(Handle:timer, any:data)
{
	new iFlags = GetConVarFlags(gCvar_svTags);
	iFlags &= ~FCVAR_NOTIFY;
	SetConVarFlags(gCvar_svTags, iFlags);
	decl String:sBuffer[32];
	GetConVarString(gCvar_svTags, sBuffer, sizeof(sBuffer));
	ReplaceString(sBuffer, sizeof(sBuffer), "friendlyfire", "");
	SetConVarString(gCvar_svTags, sBuffer);
	iFlags = iFlags|FCVAR_NOTIFY;
	SetConVarFlags(gCvar_svTags, iFlags);
	return Plugin_Handled;
}
