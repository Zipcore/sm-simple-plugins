/************************************************************************
*************************************************************************
Simple Round Immunity
Description:
	Gives admins immunity during certain rounds
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
 
#pragma semicolon 1
#include <sourcemod>
#include <simple-plugins>
#undef REQUIRE_EXTENSIONS
#undef AUTOLOAD_EXTENSIONS
#include <clientprefs>
#define REQUIRE_EXTENSIONS
#define AUTOLOAD_EXTENSIONS

#define PLUGIN_VERSION "1.1.$Rev$"

#define COLOR_GREEN 0
#define COLOR_BLACK 1
#define COLOR_RED 2
#define COLOR_BLUE 3
#define COLOR_TEAM 4
#define COLOR_RAINBOW 5
#define COLOR_NONE 6

enum e_Cookies
{
	bEnabled,
	iColor
};

enum e_ColorNames
{
	Green,
	Black,
	Red,
	Blue
};

enum e_ColorValues
{
	iRed,
	iGreen,
	iBlue
};

enum e_PlayerData
{
	Handle:hColorTimer,
	bool:bIsAdmin,
	bool:bIsImmune,
	iCycleColor
};

/**
 Global convar handles 
 */
new Handle:sri_charadminflag = INVALID_HANDLE;
new Handle:sri_enabled = INVALID_HANDLE;
new Handle:sri_cookie_enabled = INVALID_HANDLE;
new Handle:sri_cookie_color = INVALID_HANDLE;

/**
 Player arrays 
 */
new g_aPlayers[MAXPLAYERS + 1][e_PlayerData];
new g_aClientCookies[MAXPLAYERS + 1][e_Cookies];

/**
 Global bools
 */
new bool:g_bIsEnabled = true;
new bool:g_bUseClientprefs = false;

/**
 Global strings/integers/floats 
 */
new String:g_sCharAdminFlag[32];
new g_iColors[e_ColorNames][e_ColorValues];

public Plugin:myinfo =
{
	name = "Simple Round Immunity",
	author = "Simple Plugins",
	description = "Gives admins immunity during certain rounds",
	version = PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
}

public OnPluginStart()
{

	/**
	Create console variables
	*/
	CreateConVar("sri_version", PLUGIN_VERSION, "Simple Round Immunity", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	sri_enabled = CreateConVar("sri_enabled", "1", "Enable/Disable Admin immunity during certain round.");
	sri_charadminflag = CreateConVar("sri_charadminflag", "a", "Admin flag to use for immunity (only one).  Must be a in char format.");
	
	/**
	Get game type and load the team numbers
	*/
	g_CurrentMod = GetCurrentMod();
	LoadCurrentTeams();
	
	/**
	Hook some events and check extensions
	*/
	decl String:sExtError[256];
	LogAction(0, -1, "[SRI] Hooking events for [%s].", g_sGameName[g_CurrentMod]);
	HookEvent("player_spawn", HookPlayerReApply, EventHookMode_Post);
	switch (g_CurrentMod)
	{
		case GameType_CSS:
		{
			HookEvent("round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("round_end", HookRoundEnd, EventHookMode_PostNoCopy);
			new iExtStatus = GetExtensionFileStatus("game.cstrike.ext", sExtError, sizeof(sExtError));
			if (iExtStatus == -2)
			{
				LogAction(0, -1, "[SRI] Required extension was not found.");
				LogAction(0, -1, "[SRI] Plugin FAILED TO LOAD.");
				SetFailState("Required extension was not found.");
			}
			if (iExtStatus == -1 || iExtStatus == 0)
			{
				LogAction(0, -1, "[SRI] Required extension is loaded with errors.");
				LogAction(0, -1, "[SRI] Status reported was [%s].", sExtError);
				LogAction(0, -1, "[SRI] Plugin FAILED TO LOAD.");
				SetFailState("Required extension is loaded with errors.");
			}
			if (iExtStatus == 1)
			{
				LogAction(0, -1, "[SRI] Required css extension is loaded.");
			}
		}
		case GameType_TF:
		{
			HookEvent("teamplay_round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("teamplay_round_win", HookRoundEnd, EventHookMode_PostNoCopy);
			HookEvent("player_changeclass", HookPlayerReApply, EventHookMode_Post);
			new iExtStatus = GetExtensionFileStatus("game.tf2.ext", sExtError, sizeof(sExtError));
			if (iExtStatus == -2)
			{
				LogAction(0, -1, "[SRI] Required extension was not found.");
				LogAction(0, -1, "[SRI] Plugin FAILED TO LOAD.");
				SetFailState("Required extension was not found.");
			}
			if (iExtStatus == -1 || iExtStatus == 0)
			{
				LogAction(0, -1, "[SRI] Required extension is loaded with errors.");
				LogAction(0, -1, "[SRI] Status reported was [%s].", sExtError);
				LogAction(0, -1, "[SRI] Plugin FAILED TO LOAD.");
				SetFailState("Required extension is loaded with errors.");
			}
			if (iExtStatus == 1)
			{
				LogAction(0, -1, "[SRI] Required tf2 extension is loaded.");
			}
		}
		case GameType_DOD:
		{
			HookEvent("dod_round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("dod_round_win", HookRoundEnd, EventHookMode_PostNoCopy);
		}
		default:
		{
			HookEvent("round_start", HookRoundStart, EventHookMode_PostNoCopy);
			HookEvent("round_end", HookRoundEnd, EventHookMode_PostNoCopy);
		}
	}
	/**
	Now lets check for client prefs extension
	*/
	new iExtStatus = GetExtensionFileStatus("clientprefs.ext", sExtError, sizeof(sExtError));
	if (iExtStatus == -2)
	{
		LogAction(0, -1, "[SRI] Client Preferences extension was not found.");
		LogAction(0, -1, "[SRI] Plugin continued to load, but that feature will not be used.");
		g_bUseClientprefs = false;
	}
	if (iExtStatus == -1 || iExtStatus == 0)
	{
		LogAction(0, -1, "[SRI] Client Preferences extension is loaded with errors.");
		LogAction(0, -1, "[SRI] Status reported was [%s].", sExtError);
		LogAction(0, -1, "[SRI] Plugin continued to load, but that feature will not be used.");
		g_bUseClientprefs = false;
	}
	if (iExtStatus == 1)
	{
		LogAction(0, -1, "[SRI] Client Preferences extension is loaded, checking database.");
		if (!SQL_CheckConfig("clientprefs"))
		{
			LogAction(0, -1, "[SRI] No 'clientprefs' database found.  Check your database.cfg file.");
			LogAction(0, -1, "[SRI] Plugin continued to load, but Client Preferences will not be used.");
			g_bUseClientprefs = false;
		}
		g_bUseClientprefs = true;
		
		/**
		Deal with client cookies
		*/
		sri_cookie_enabled = RegClientCookie("bri_client_enabled", "Enable/Disable your immunity during the bonus round.", CookieAccess_Public);
		sri_cookie_color = RegClientCookie("bri_client_color", "Color to render when immune.", CookieAccess_Public);
		SetCookieMenuItem(CookieMenu_TopMenu, sri_cookie_enabled, "Bonus Round Immunity");
	}
	
	HookConVarChange(sri_enabled, EnabledChanged);

	RegAdminCmd("sm_immunity", Command_Immunity, ADMFLAG_ROOT, "sm_immunity: Gives you immunity");
	
	LoadColors();
	
	AutoExecConfig(true, "plugin.simpleroundimmunity");
}

public OnAllPluginsLoaded()
{
	//something
	// need to deal with the unloading of dukehacks, clientprefs, and simpleplugins
	// should move hooking the client prefs cookies to a function to make sure they are done post plugin start if ext is loaded late
}

public OnLibraryRemoved(const String:name[])
{
	//something
	// need to deal with the loading of dukehacks, clientprefs, and simpleplugins
}

public OnConfigsExecuted()
{
	GetConVarString(sri_charadminflag, g_sCharAdminFlag, sizeof(g_sCharAdminFlag));
	g_bIsEnabled = GetConVarBool(sri_enabled);
}

/**
 Client events
 */

public OnClientPostAdminCheck(client)
{
	if (SM_IsValidAdmin(client, g_sCharAdminFlag))
		g_aPlayers[client][bIsAdmin] = true;
	else
		g_aPlayers[client][bIsAdmin] = false;
}

public OnClientCookiesCached(client)
{
	decl String:sEnabled[2], String:sColor[4];
	GetClientCookie(client, sri_cookie_enabled, sEnabled, sizeof(sEnabled));
	GetClientCookie(client, sri_cookie_color, sColor, sizeof(sColor));
	g_aClientCookies[client][bEnabled] = StringToInt(sEnabled);
	g_aClientCookies[client][iColor] = StringToInt(sColor);
}

public OnClientDisconnect(client)
{
	CleanUp(client);
}

/**
 Commands
 */

public Action:Command_Immunity(client, args)
{
	if (g_aPlayers[client][bIsImmune])
	{
		DisableImmunity(client);
	}
	else
	{
		EnableImmunity(client);
	}
	return Plugin_Handled;
}

/**
 Event hooks
 */

public HookRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bIsEnabled) 
	{
		for (new i = 1; i <= MaxClients; i++) 
		{
			if (g_aPlayers[i][bIsImmune]) 
			{
				DisableImmunity(i);
			}
		}
	}
}

public HookRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bIsEnabled) 
	{
		for (new i = 1; i <= MaxClients; i++) 
		{
			if (g_aPlayers[i][bIsAdmin]) 
			{
				EnableImmunity(i);
			}
		}
	}
}

public HookPlayerReApply(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if (g_aPlayers[iClient][bIsImmune]) 
	{
		EnableImmunity(iClient);
	}
}

/**
 Cookie menus
 */

public CookieMenu_TopMenu(client, CookieMenuAction:action, any:info, String:buffer[], maxlen)
{
	if (action == CookieMenuAction_DisplayOption)
	{
		//don't think we need to do anything
	}
	else
	{
		new Handle:hMenu = CreateMenu(Menu_CookieSettings);
		SetMenuTitle(hMenu, "Options (Current Setting)");
		if (g_aClientCookies[client][bEnabled])
		{
			AddMenuItem(hMenu, "enable", "Enabled/Disable (Enabled)");
		}
		else
		{
			AddMenuItem(hMenu, "enable", "Enabled/Disable (Disabled)");
		}
		switch (g_aClientCookies[client][iColor])
		{
			case COLOR_GREEN:
			{
				AddMenuItem(hMenu, "color", "Color (Green)");
			}
			case COLOR_BLACK:
			{
				AddMenuItem(hMenu, "color", "Color (Black)");
			}
			case COLOR_RED:
			{
				AddMenuItem(hMenu, "color", "Color (Red)");
			}
			case COLOR_BLUE:
			{
				AddMenuItem(hMenu, "color", "Color (Blue)");
			}
			case COLOR_TEAM:
			{
				AddMenuItem(hMenu, "color", "Color (Team)");
			}
			case COLOR_RAINBOW:
			{
				AddMenuItem(hMenu, "color", "Color (Rainbow)");
			}
			case COLOR_NONE:
			{
				AddMenuItem(hMenu, "color", "Color (None)");
			}
		}
		SetMenuExitBackButton(hMenu, true);
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
}

public Menu_CookieSettings(Handle:menu, MenuAction:action, param1, param2)
{
	new client = param1;
	if (action == MenuAction_Select) 
	{
		new String:sSelection[24];
		GetMenuItem(menu, param2, sSelection, sizeof(sSelection));
		if (StrEqual(sSelection, "enable", false))
		{
			new Handle:hMenu = CreateMenu(Menu_CookieSettingsEnable);
			SetMenuTitle(hMenu, "Enable/Disable Round End Immunity");
			
			if (g_aClientCookies[client][bEnabled])
			{
				AddMenuItem(hMenu, "enable", "Enable (Set)");
				AddMenuItem(hMenu, "disable", "Disable");
			}
			else
			{
				AddMenuItem(hMenu, "enable", "Enabled");
				AddMenuItem(hMenu, "disable", "Disable (Set)");
			}
			
			SetMenuExitBackButton(hMenu, true);
			DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
		}
		else
		{
			new Handle:hMenu = CreateMenu(Menu_CookieSettingsColors);
			SetMenuTitle(hMenu, "Select Immunity Color");
			switch (g_aClientCookies[client][iColor])
			{
				case COLOR_GREEN:
				{
					AddMenuItem(hMenu, "Green", "Green (Set)");
					AddMenuItem(hMenu, "Black", "Black");
					AddMenuItem(hMenu, "Red", "Red");
					AddMenuItem(hMenu, "Blue", "Blue");
					AddMenuItem(hMenu, "Team", "Team Color");
					AddMenuItem(hMenu, "Rain", "Rainbow");
					AddMenuItem(hMenu, "None", "None");
				}
				case COLOR_BLACK:
				{
					AddMenuItem(hMenu, "Green", "Green");
					AddMenuItem(hMenu, "Black", "Black (Set)");
					AddMenuItem(hMenu, "Red", "Red");
					AddMenuItem(hMenu, "Blue", "Blue");
					AddMenuItem(hMenu, "Team", "Team Color");
					AddMenuItem(hMenu, "Rain", "Rainbow");
					AddMenuItem(hMenu, "None", "None");
				}
				case COLOR_RED:
				{
					AddMenuItem(hMenu, "Green", "Green");
					AddMenuItem(hMenu, "Black", "Black");
					AddMenuItem(hMenu, "Red", "Red (Set)");
					AddMenuItem(hMenu, "Blue", "Blue");
					AddMenuItem(hMenu, "Team", "Team Color");
					AddMenuItem(hMenu, "Rain", "Rainbow");
					AddMenuItem(hMenu, "None", "None");
				}
				case COLOR_BLUE:
				{
					AddMenuItem(hMenu, "Green", "Green");
					AddMenuItem(hMenu, "Black", "Black");
					AddMenuItem(hMenu, "Red", "Red");
					AddMenuItem(hMenu, "Blue", "Blue (Set)");
					AddMenuItem(hMenu, "Team", "Team Color");
					AddMenuItem(hMenu, "Rain", "Rainbow");
					AddMenuItem(hMenu, "None", "None");
				}
				case COLOR_TEAM:
				{
					AddMenuItem(hMenu, "Green", "Green");
					AddMenuItem(hMenu, "Black", "Black");
					AddMenuItem(hMenu, "Red", "Red");
					AddMenuItem(hMenu, "Blue", "Blue");
					AddMenuItem(hMenu, "Team", "Team Color (Set)");
					AddMenuItem(hMenu, "Rain", "Rainbow");
					AddMenuItem(hMenu, "None", "None");
				}
				case COLOR_RAINBOW:
				{
					AddMenuItem(hMenu, "Green", "Green");
					AddMenuItem(hMenu, "Black", "Black");
					AddMenuItem(hMenu, "Red", "Red");
					AddMenuItem(hMenu, "Blue", "Blue");
					AddMenuItem(hMenu, "Team", "Team Color");
					AddMenuItem(hMenu, "Rain", "Rainbow (Set)");
					AddMenuItem(hMenu, "None", "None");
				}
				case COLOR_NONE:
				{
					AddMenuItem(hMenu, "Green", "Green");
					AddMenuItem(hMenu, "Black", "Black");
					AddMenuItem(hMenu, "Red", "Red");
					AddMenuItem(hMenu, "Blue", "Blue");
					AddMenuItem(hMenu, "Team", "Team Color");
					AddMenuItem(hMenu, "Rain", "Rainbow");
					AddMenuItem(hMenu, "None", "None (Set)");
				}
			}
			SetMenuExitBackButton(hMenu, true);
			DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
		}
	}
	else if (action == MenuAction_Cancel) 
	{
		if (param2 == MenuCancel_ExitBack)
		{
			ShowCookieMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Menu_CookieSettingsEnable(Handle:menu, MenuAction:action, param1, param2)
{
	new client = param1;
	if (action == MenuAction_Select) 
	{
		new String:sSelection[24];
		GetMenuItem(menu, param2, sSelection, sizeof(sSelection));
		if (StrEqual(sSelection, "enable", false))
		{
			SetClientCookie(client, sri_cookie_enabled, "1");
			g_aClientCookies[client][bEnabled] = 1;
			PrintToChat(client, "[SM] Simple Round Immunity is ENABLED");
		}
		else
		{
			SetClientCookie(client, sri_cookie_enabled, "0");
			g_aClientCookies[client][bEnabled] = 0;
			PrintToChat(client, "[SM] Simple Round Immunity is DISABLED");
		}
	}
	else if (action == MenuAction_Cancel) 
	{
		if (param2 == MenuCancel_ExitBack)
		{
			ShowCookieMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Menu_CookieSettingsColors(Handle:menu, MenuAction:action, param1, param2)
{
	new client = param1;
	if (action == MenuAction_Select) 
	{
		new String:sSelection[24];
		GetMenuItem(menu, param2, sSelection, sizeof(sSelection));
		if (StrEqual(sSelection, "Green", false))
		{
			SetClientCookie(client, sri_cookie_color, "0");
			g_aClientCookies[client][iColor] = COLOR_GREEN;
			PrintToChat(client, "[SM] Simple Round Immunity color set to GREEN");
		}
		else if (StrEqual(sSelection, "Black", false))
		{
			SetClientCookie(client, sri_cookie_color, "1");
			g_aClientCookies[client][iColor] = COLOR_BLACK;
			PrintToChat(client, "[SM] Simple Round Immunity color set to BLACK");
		}
		else if (StrEqual(sSelection, "Red", false))
		{
			SetClientCookie(client, sri_cookie_color, "2");
			g_aClientCookies[client][iColor] = COLOR_RED;
			PrintToChat(client, "[SM] Simple Round Immunity color set to RED");
		}
		else if (StrEqual(sSelection, "Blue", false))
		{
			SetClientCookie(client, sri_cookie_color, "3");
			g_aClientCookies[client][iColor] = COLOR_BLUE;
			PrintToChat(client, "[SM] Simple Round Immunity color set to BLUE");
		}
		else if (StrEqual(sSelection, "Team", false))
		{
			SetClientCookie(client, sri_cookie_color, "4");
			g_aClientCookies[client][iColor] = COLOR_TEAM;
			PrintToChat(client, "[SM] Simple Round Immunity color set to TEAM COLOR");
		}
		else if (StrEqual(sSelection, "Rain", false))
		{
			SetClientCookie(client, sri_cookie_color, "5");
			g_aClientCookies[client][iColor] = COLOR_RAINBOW;
			PrintToChat(client, "[SM] Simple Round Immunity color set to RAINBOW");
		}
		else if (StrEqual(sSelection, "None", false))
		{
			SetClientCookie(client, sri_cookie_color, "6");
			g_aClientCookies[client][iColor] = COLOR_NONE;
			PrintToChat(client, "[SM] Simple Round Immunity color set to NONE");
		}
	}
	else if (action == MenuAction_Cancel) 
	{
		if (param2 == MenuCancel_ExitBack)
		{
			ShowCookieMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

/**
Timer functions
 */
public Action:Timer_ChangeColor(Handle:timer, any:client)
{
	if (g_aPlayers[client][iCycleColor]++ == 3)
	{
		g_aPlayers[client][iCycleColor] = 0;
	}
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, g_iColors[g_aPlayers[client][iCycleColor]][iRed], g_iColors[g_aPlayers[client][iCycleColor]][iGreen], g_iColors[g_aPlayers[client][iCycleColor]][iBlue], 255);
	return Plugin_Continue;
}

/**
Stock functions .
 */
stock CleanUp(iClient)
{
	g_aPlayers[iClient][bIsAdmin] = false;
	DisableImmunity(iClient);
}

stock EnableImmunity(iClient)
{
	SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
	switch (g_aClientCookies[iClient][iColor])
	{
		case COLOR_TEAM:
		{
			new iTeam = GetClientTeam(iClient);
			SetEntityRenderColor(iClient, g_iColors[e_ColorNames:iTeam][iRed], g_iColors[e_ColorNames:iTeam][iGreen], g_iColors[e_ColorNames:iTeam][iBlue], 255);
		}
		case COLOR_RAINBOW:
		{
			if (g_aPlayers[iClient][hColorTimer] != INVALID_HANDLE)
			{
				CloseHandle(g_aPlayers[iClient][hColorTimer]);
				g_aPlayers[iClient][hColorTimer] = INVALID_HANDLE;
			}
			g_aPlayers[iClient][hColorTimer] = CreateTimer(0.5, Timer_ChangeColor, iClient, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}
		case COLOR_NONE:
		{
			//We dont have to set a color
		}
		default:
		{
			SetEntityRenderColor(iClient, g_iColors[e_ColorNames:g_aClientCookies[iClient][iColor]][iRed], g_iColors[e_ColorNames:g_aClientCookies[iClient][iColor]][iGreen], g_iColors[e_ColorNames:g_aClientCookies[iClient][iColor]][iBlue], 255);
		}
	}
	SetEntProp(iClient, Prop_Data, "m_takedamage", 1, 1);
	g_aPlayers[iClient][bIsImmune] = true;
}

stock DisableImmunity(iClient)
{
	if (g_aPlayers[iClient][hColorTimer] != INVALID_HANDLE)
	{
		CloseHandle(g_aPlayers[iClient][hColorTimer]);
		g_aPlayers[iClient][hColorTimer] = INVALID_HANDLE;
	}
	if (IsClientInGame(iClient))
	{
		SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
		SetEntityRenderColor(iClient, 255, 255, 255, 255);
		SetEntProp(iClient, Prop_Data, "m_takedamage", 2, 1);
	}
	g_aPlayers[iClient][iCycleColor] = 0;
	g_aPlayers[iClient][bIsImmune] = false;
}

stock LoadColors()
{
	g_iColors[Green][iRed] = 0;
	g_iColors[Green][iGreen] = 255;
	g_iColors[Green][iBlue] = 0;

	g_iColors[Black][iRed] = 10;
	g_iColors[Black][iGreen] = 10;
	g_iColors[Black][iBlue] = 0;
	
	g_iColors[Red][iRed] = 255;
	g_iColors[Red][iGreen] = 0;
	g_iColors[Red][iBlue] = 0;
	
	g_iColors[Blue][iRed] = 0;
	g_iColors[Blue][iGreen] = 0;
	g_iColors[Blue][iBlue] = 255;
}

/**
Enabled hook
 */
public EnabledChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0) 
	{
		for (new i = 1; i <= MaxClients; i++) 
		{
			if (g_aPlayers[i][bIsAdmin] && g_aPlayers[i][bIsImmune]) 
			{
				DisableImmunity(i);
			}
		}
		g_bIsEnabled = false;
	} 
	else 
	{
		g_bIsEnabled = true;
	}
}
