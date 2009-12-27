/**
 * Globals
 */
 
//#define _DEBUG

#define SB_PREFIX		"[SourceBans] "

enum ConfigState
{
	ConfigState_None = 0,
	ConfigState_Config,
	ConfigState_Reasons,
	ConfigState_Hacking,
	ConfigState_Times
};
 
enum PlayerData
{
	iBansSubmitted,
	iSubmissionTarget
};

new ConfigState:g_iConfigState;
new g_iConnectLock   	= 0;
new g_iSequence       	= 0;
new g_iServerPort;
new bool:g_bConnected 	= false;
new Handle:g_hConfigParser;
new Handle:g_hDatabase;
new Handle:g_hBanReasons;
new Handle:g_hBanTimes;
new Handle:g_hBanTimesFlags;
new Handle:g_hBanTimesLength;
new Handle:g_hHackingReasons;
new Handle:g_hSettings;
new String:g_sConfigFile[PLATFORM_MAX_PATH];
new String:g_sDatabasePrefix[16];
new String:g_sServerIp[16];

new g_aPlayerSBInfo[MAXPLAYERS + 1][PlayerData];

new String:g_sTargetsAuth[MAXPLAYERS + 1][32];
new String:g_sTargetsName[MAXPLAYERS + 1][MAX_NAME_LENGTH + 1];
new String:g_sTargetsIP[MAXPLAYERS + 1][16];

new g_iServerId, g_iModID;
new Handle:g_hReasonMenu;
new Handle:g_hHackingMenu;
new String:g_sWebsite[256];

/**
 * Plugin Forwards
 */
public SubmitBan_StartUp()
{
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/sourcebans/sourcebans.cfg");
	
	g_hBanReasons    	= CreateArray(256);
	g_hBanTimes     	= CreateArray(256);
	g_hBanTimesFlags		= CreateArray(256);
	g_hBanTimesLength	= CreateArray(256);
	g_hHackingReasons	= CreateArray(256);
	g_hSettings       	= CreateTrie();
	
	g_hConfigParser   	= SMC_CreateParser();
	SMC_SetReaders(g_hConfigParser, ReadConfig_NewSection, ReadConfig_KeyValue, ReadConfig_EndSection);
	
	new iIp           	= GetConVarInt(FindConVar("hostip"));
	g_iServerPort     	= GetConVarInt(FindConVar("hostport"));
	Format(g_sServerIp, sizeof(g_sServerIp), "%i.%i.%i.%i",	(iIp >> 24) & 0x000000FF,
																									(iIp >> 16) & 0x000000FF,
																									(iIp >>  8) & 0x000000FF,
																									iIp         & 0x000000FF);
	
	// Store server IP and port locally
	SetTrieString(g_hSettings, "ServerIP",     g_sServerIp);
	SetTrieValue(g_hSettings,  "ServerPort",   g_iServerPort);
	
	g_hReasonMenu = CreateMenu(MenuHandler_Reason);
	g_hHackingMenu = CreateMenu(MenuHandler_Reason);
}

public OnMapStart()
{
	// Reload settings from config file
	SB_Reload();
	
	// Connect to database
	if(!g_bConnected)
		SB_Connect();
}

/**
 * Client Forwards
 */
public OnClientPostAdminCheck(client)
{
	// If it's console or a fake client, or there is no database connection, we can bug out.
	if(!client || IsFakeClient(client) || !g_hDatabase)
		return;
	
	// Get the steamid and format the query.
	decl String:sAuth[20], String:sQuery[128];
	GetClientAuthString(client, sAuth, sizeof(sAuth));
	Format(sQuery, sizeof(sQuery), "SELECT SteamId FROM %s_submissions WHERE SteamId REGEXP '^STEAM_[0-9]:%s$'", g_sDatabasePrefix, sAuth[8]);
	
	// Send the query.
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, client);
	WritePackString(hPack, sQuery);
	SQL_TQuery(g_hDatabase, Query_RecieveSubmissions, sQuery, hPack, DBPrio_High);
}

public OnClientDisconnect_Post(client)
{
	// Cleanup the client variables
	g_aPlayerSBInfo[client][iBansSubmitted] = -1;
	g_aPlayerSBInfo[client][iSubmissionTarget] = -1;
	// Not going to search to see of the target is currently in the process for a submission
	// This allows us to submit bans even if the person disconnects after the process is started
}

/**
 * Menu Handlers
 */
public MenuHandler_Reason(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:sInfo[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		if(StrEqual(sInfo, "Hacking") && menu == g_hReasonMenu)
		{
			DisplayMenu(g_hHackingMenu, param1, MENU_TIME_FOREVER);
			return;
		}
		if(g_aPlayerSBInfo[param1][iSubmissionTarget] != -1)
		{
			PrepareSubmittal(param1, g_aPlayerSBInfo[param1][iSubmissionTarget], sInfo);
		}
		StartDisplayingHud(param1);
	}
}


/**
 * Query Callbacks
 */
public Query_ServerSelect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(error[0])
	{
		LogError("Failed to query database (%s)", error);
		return;
	}
	if(SQL_FetchRow(hndl))
	{
		// Store server ID locally
		g_iServerId = SQL_FetchInt(hndl, 0);
		g_iModID = SQL_FetchInt(hndl, 4);
		SetTrieValue(g_hSettings, "ServerID", g_iServerId);
		return;
	}
	else
	{
		LogError("Game server not found in database");
		return;
	}
}
 
public Query_RecieveSubmissions(Handle:owner, Handle:hndl, const String:error[], any:pack)
{
	ResetPack(pack);
	
	// If the client is no longer connected we can bug out.
	new iClient = ReadPackCell(pack);
	if(!IsClientInGame(iClient))
	{
		CloseHandle(pack);
		return;
	}
	
	// Make sure we succeeded.
	if(error[0])
	{
		decl String:sQuery[256];
		ReadPackString(pack, sQuery, sizeof(sQuery));
		LogError("SQL error: %s", error);
		LogError("Query dump: %s", sQuery);
		CloseHandle(pack);
		return;
	}
	
	// We're done with you now.
	CloseHandle(pack);
	
	// Set the number of submissions 
	g_aPlayerSBInfo[iClient][iBansSubmitted] = SQL_GetRowCount(hndl);
}

public Query_Submission(Handle:owner, Handle:hndl, const String:error[], any:pack)
{
	ResetPack(pack);
	
	// Make sure the query worked
	new iClient = ReadPackCell(pack), iTarget = ReadPackCell(pack);
	if(error[0]) 
	{
		decl String:sQuery[256];
		ReadPackString(pack, sQuery, sizeof(sQuery));
		LogError("SQL error: %s", error);
		LogError("Query dump: %s", sQuery);
		if(IsClientInGame(iClient))
			PrintToChat(iClient, "\x03[SM-SPEC]\x01 Submission failed, visit %s", g_sWebsite);
		// We're done with you now.
		CloseHandle(pack);
		return;
	}
	
	// We're done with you now.
	CloseHandle(pack);
	
	// Increment the submission array for the target.
	g_aPlayerSBInfo[iTarget][iBansSubmitted] = 1;
	
	// Blank out the target for this client
	g_aPlayerSBInfo[iClient][iSubmissionTarget] = -1;
	
	// Report the results
	if(!IsClientInGame(iClient))
		return;
	
	PrintToChat(iClient, "\x03[SM-SPEC]\x01 Submission succeeded");
	PrintToChat(iClient, "\x03[SM-SPEC]\x01 Remember to upload demo at %s", g_sWebsite);
}

public Query_ErrorCheck(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(error[0])
		LogError("Failed to query database (%s)", error);
}

/**
 * Connect Callback
 */
public OnConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	#if defined _DEBUG
	PrintToServer("OnDatabaseConnect(%x,%x,%d) ConnectLock=%d", owner, hndl, data, g_iConnectLock);
	#endif
	
	// If this happens to be an old connection request, ignore it.
	if(data != g_iConnectLock || g_hDatabase)
	{
		if(hndl)
			CloseHandle(hndl);
		
		return;
	}
	
	g_iConnectLock = 0;
	g_bConnected   = true;
	g_hDatabase    = hndl;
	
	// See if the connection is valid.  If not, don't un-mark the caches
	// as needing rebuilding, in case the next connection request works.
	if(!g_hDatabase)
	{
		LogError("Could not connect to database (%s)", error);
		return;
	}
	
	// Set character set to UTF-8 in the database
	SQL_TQuery(g_hDatabase, Query_ErrorCheck, "SET NAMES 'UTF8'");
	
	// Select server from the database
	decl String:sQuery[96];
	Format(sQuery, sizeof(sQuery), "SELECT * \
																	FROM   %s_servers \
																	WHERE  ip   = '%s' \
																	  AND  port = %i",
																	g_sDatabasePrefix, g_sServerIp, g_iServerPort);
	SQL_TQuery(g_hDatabase, Query_ServerSelect, sQuery);
}

/**
 * Stocks
 */
stock PrepareSubmittal(iClient, iTarget, const String:sReason[])
{
	// Connect to the database
	if(g_hDatabase == INVALID_HANDLE)
	{
		SB_Connect();
		PrintToChat(iClient, "\x03[SM-SPEC]\x01 Not Connected to sourcebans, trying now.");
		return;
	}
	
	decl String:sClientIp[16], String:sClientName[MAX_NAME_LENGTH + 1], String:sQuery[768];
	decl String:sEscapedClientName[MAX_NAME_LENGTH * 2 + 1], String:sEscapedTargetName[MAX_NAME_LENGTH * 2 + 1], String:sEscapedReason[256];
	
	// Get the clients information
	GetClientIP(iClient,   sClientIp,   sizeof(sClientIp));
	GetClientName(iClient, sClientName, sizeof(sClientName));
	
	// SQL Escape all the information (prepares for query)
	SQL_EscapeString(g_hDatabase, sClientName, sEscapedClientName, sizeof(sEscapedClientName));
	SQL_EscapeString(g_hDatabase, g_sTargetsName[iTarget], sEscapedTargetName, sizeof(sEscapedTargetName));
	SQL_EscapeString(g_hDatabase, sReason,     sEscapedReason,     sizeof(sEscapedReason));
	
	// Format the query
	Format(sQuery, sizeof(sQuery), "INSERT INTO %s_submissions (ModID, SteamId, name, email, reason, ip, subname, sip, server) VALUES ('%s', '%s', '%s', 'support@sharedbans.com', '%s', '%s', '%s', '%s', %d)",
								g_sDatabasePrefix, g_iModID, g_sTargetsAuth[iTarget], sEscapedTargetName, sEscapedReason, g_sTargetsIP[iTarget], sEscapedClientName, sClientIp, g_iServerId);
	
	// Send the query.
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, iClient);
	WritePackCell(hPack, iTarget);
	WritePackString(hPack, sQuery);
	SQL_TQuery(g_hDatabase, Query_Submission, sQuery, hPack);
}

stock AssignTargetInfo(client, target)
{
	g_aPlayerSBInfo[client][iSubmissionTarget] = target;
	GetClientAuthString(target,	g_sTargetsAuth[target],		sizeof(g_sTargetsAuth[]));
	GetClientIP(target,					g_sTargetsIP[target],	   	sizeof(g_sTargetsIP[]));
	GetClientName(target,			g_sTargetsName[target], 	sizeof(g_sTargetsName[]));
}

stock SB_Reload()
{
	if(!FileExists(g_sConfigFile))
		SetFailState("%sFile not found: %s", SB_PREFIX, g_sConfigFile);
	
	// Empty ban reason and ban time arrays
	ClearArray(g_hBanReasons);
	ClearArray(g_hBanTimes);
	ClearArray(g_hBanTimesFlags);
	ClearArray(g_hBanTimesLength);
	ClearArray(g_hHackingReasons);
	
	// Reset config state
	g_iConfigState      = ConfigState_None;
	
	// Parse config file
	new SMCError:iError = SMC_ParseFile(g_hConfigParser, g_sConfigFile);
	if(iError          != SMCError_Okay)
	{
		decl String:sError[64];
		if(SMC_GetErrorString(iError, sError, sizeof(sError)))
			LogError(sError);
		else
			LogError("Fatal parse error");
		return;
	}
	
	GetTrieString(g_hSettings, "DatabasePrefix", g_sDatabasePrefix, sizeof(g_sDatabasePrefix));
	SetTrieValue(g_hSettings,  "BanReasons",     g_hBanReasons);
	SetTrieValue(g_hSettings,  "BanTimes",       g_hBanTimes);
	SetTrieValue(g_hSettings,  "BanTimesFlags",  g_hBanTimesFlags);
	SetTrieValue(g_hSettings,  "BanTimesLength", g_hBanTimesLength);
	SetTrieValue(g_hSettings,  "HackingReasons", g_hHackingReasons);
	
	// Get settings from SourceBans config and store them locally
	GetSettingString("DatabasePrefix", g_sDatabasePrefix, sizeof(g_sDatabasePrefix));
	GetSettingString("Website",        g_sWebsite,        sizeof(g_sWebsite));
	
	// Get reasons from SourceBans config and store them locally
	decl String:sReason[128];
	new Handle:hBanReasons    	= Handle:GetSettingCell("BanReasons");
	new Handle:hHackingReasons = Handle:GetSettingCell("HackingReasons");
	
	// Empty reason menus
	RemoveAllMenuItems(g_hReasonMenu);
	RemoveAllMenuItems(g_hHackingMenu);
	
	// Add reasons from SourceBans config to reason menus
	for(new i = 0, iSize = GetArraySize(hBanReasons);     i < iSize; i++)
	{
		GetArrayString(hBanReasons,     i, sReason, sizeof(sReason));
		AddMenuItem(g_hReasonMenu,  sReason, sReason);
	}
	for(new i = 0, iSize = GetArraySize(hHackingReasons); i < iSize; i++)
	{
		GetArrayString(hHackingReasons, i, sReason, sizeof(sReason));
		AddMenuItem(g_hHackingMenu, sReason, sReason);
	}
	CloseHandle(hBanReasons);
	CloseHandle(hHackingReasons);
}

stock SB_Connect()
{
	g_iConnectLock = ++g_iSequence;
	// Connect using the "sourcebans" section, or the "default" section if "sourcebans" does not exist
	SQL_TConnect(OnConnect, SQL_CheckConfig("sourcebans") ? "sourcebans" : "default", g_iConnectLock);
}

stock GetSettingCell(const String:key[])
{
	// Get value from setting
	new iBuffer;
	GetTrieValue(g_hSettings, key, iBuffer);
	
	// Return value
	return iBuffer;
}

stock GetSettingString(const String:key[], String:buffer[], maxlength)
{
	// Get max length for the string buffer
	if(maxlength <= 0)
		return;
	
	// Get value from setting
	decl String:sBuffer[maxlength + 1];
	GetTrieString(g_hSettings, key, sBuffer, maxlength + 1);
	
	// Store value in string buffer
	Format(buffer, maxlength + 1, "%s", sBuffer);
}

/**
 * Config Parser
 */
public SMCResult:ReadConfig_EndSection(Handle:smc)
{
	return SMCParse_Continue;
}

public SMCResult:ReadConfig_KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
	if(!key[0])
		return SMCParse_Continue;
	
	switch(g_iConfigState)
	{
		case ConfigState_Config:
		{
			// If value is an integer
			if(StrEqual("Addban",           key, false) ||
				 StrEqual("ProcessQueueTime", key, false) ||
				 StrEqual("Unban",            key, false))
				SetTrieValue(g_hSettings,  key, StringToInt(value));
			// If value is a float
			else if(StrEqual("RetryTime",   key, false))
				SetTrieValue(g_hSettings,  key, StringToFloat(value));
			// If value is a string
			else
				SetTrieString(g_hSettings, key, value);
		}
		case ConfigState_Hacking:
			PushArrayString(g_hHackingReasons, value);
		case ConfigState_Reasons:
			PushArrayString(g_hBanReasons,     value);
		case ConfigState_Times:
		{
			if(StrEqual("flags",       key, false))
				PushArrayString(g_hBanTimesFlags,  value);
			else if(StrEqual("length", key, false))
				PushArrayString(g_hBanTimesLength, value);
		}
	}
	return SMCParse_Continue;
}

public SMCResult:ReadConfig_NewSection(Handle:smc, const String:name[], bool:opt_quotes)
{
	if(StrEqual("Config",              name, false))
		g_iConfigState = ConfigState_Config;
	else if(StrEqual("BanReasons",     name, false))
		g_iConfigState = ConfigState_Reasons;
	else if(StrEqual("BanTimes",       name, false))
		g_iConfigState = ConfigState_Times;
	else if(StrEqual("HackingReasons", name, false))
		g_iConfigState = ConfigState_Hacking;
	else if(g_iConfigState == ConfigState_Times)
		PushArrayString(g_hBanTimes, name);
	return SMCParse_Continue;
}
