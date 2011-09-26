/************************************************************************
*************************************************************************
Simple Chat Filter
Description:
		Filters the display of banned words from players chat messages
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

#include <sourcemod>
#include <sdktools>
#include <scp>
#include <smlib>
#include <regex>

#define PLUGIN_VERSION	"1.0.1"
#define CHAR_FILTER			"*"

new Handle:g_CvarFilterMsg = INVALID_HANDLE;
new Handle:g_hBannedWords = INVALID_HANDLE;

new bool:g_bDisplayMsg = false;

public Plugin:myinfo =
{
	name = "Simple Chat Filter",
	author = "Simple Plugins",
	description = "Filters the display of banned words from players chat messages.",
	version = PLUGIN_VERSION,
	url = "http://www.simple-plugins.com"
};

public OnPluginStart()
{
	CreateConVar("scf_version", PLUGIN_VERSION, "Simple Chat Filter", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_CvarFilterMsg = CreateConVar("scf_filtermsg", "1", "Turn ON/OFF the display of the filter message");
	HookConVarChange(g_CvarFilterMsg, ConVarSettingsChanged);
	RegAdminCmd("sm_reloadscf", Command_Reload, ADMFLAG_CONFIG,  "Reloads bad words from the config file");
	g_hBannedWords = CreateArray(128);
	ProcessConfigFile("configs/simple-chatfilter.cfg");
	AutoExecConfig();
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "scp"))
	{
		SetFailState("Simple Chat Processor Unloaded.  Plugin Disabled.");
	}
}

public OnConfigsExecuted()
{
	g_bDisplayMsg = GetConVarBool(g_CvarFilterMsg);
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	if (SaidBadWord(message, MAXLENGTH_INPUT))
	{
		new userid = GetClientUserId(author);
		if (g_bDisplayMsg)
		{
			CreateTimer(0.001, SendFilterMessage, userid, TIMER_FLAG_NO_MAPCHANGE);
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action:SendFilterMessage(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client == 0)
	{
		return Plugin_Stop;
	}
	Client_PrintToChat(client, true, "You said a {R}banned word{N}.  Your message has been filtered.");
	return Plugin_Stop;
}

public Action:Command_Reload(client, args)
{
	ProcessConfigFile("configs/simple-chatfilter.cfg");
	LogAction(client, 0, "[SCF] Config file has been reloaded");
	ReplyToCommand(client, "[SCF] Config file has been reloaded");
	return Plugin_Handled;
}

stock ProcessConfigFile(const String:file[])
{
	new String:sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), file);
	if (!FileExists(sConfigFile)) 
	{
		LogError("[SCF] Simple Chat Filter is not running! Could not find file %s", sConfigFile);
		SetFailState("Could not find file %s", sConfigFile);
	}
	
	new iArrayBannedSize = GetArraySize(g_hBannedWords);
	for (new i = 0; i < iArrayBannedSize; i++)
	{
		CloseHandle(GetArrayCell(g_hBannedWords, i));
	}
	ClearArray(g_hBannedWords);
	
	new Handle:hFile = OpenFile(sConfigFile, "r");
	new String:sRegEx[256];

	do
	{
		ReadFileLine(hFile, sRegEx, sizeof(sRegEx));
		TrimString(sRegEx);
		if (sRegEx[0] == '\0' || sRegEx[0] == ';' || (sRegEx[0] == '/' && sRegEx[1] == '/'))
		{
			continue;
		}
		new String:sError[256], RegexError:iError;
		new Handle:hRegEx = CompileRegex(sRegEx, PCRE_CASELESS, sError, sizeof(sError), iError);
		if (iError != REGEX_ERROR_NONE)
		{
			LogError(sError);
		}
		else
		{
			PushArrayCell(g_hBannedWords, hRegEx);
		}
	} while (!IsEndOfFile(hFile));
	CloseHandle(hFile);
}

stock bool:SaidBadWord(String:message[], maxlength)
{
	new index = 0;
	new iArrayBannedSize = GetArraySize(g_hBannedWords);
	new bool:bBad = false;
	new String:sWords[64][MAXLENGTH_INPUT];

	StripQuotes(message);
	ExplodeString(message, " ", sWords, sizeof(sWords), sizeof(sWords[]));

	do
	{
		TrimString(sWords[index]);
		Color_StripFromChatText(sWords[index], sWords[index], sizeof(sWords[]));
		
		new String:sError[256], RegexError:iError;	
		for (new i = 0; i < iArrayBannedSize; i++)
		{
			new Handle:hRegEx = GetArrayCell(g_hBannedWords, i);
			new iFound = MatchRegex(hRegEx, sWords[index], iError);
			if (iError != REGEX_ERROR_NONE)
			{
				LogError(sError);
			}
			else if (iFound > 0)
			{
				bBad = true;
				FilterWord(sWords[index], sizeof(sWords[]));
				break;
			}
		}
		index++;
	} while !IsStringBlank(sWords[index]);
	
	if (bBad)
	{
		ImplodeStrings(sWords, sizeof(sWords), " ", message, maxlength);
		TrimString(message);
	}
	
	return bBad;
}

stock FilterWord(String:word[], maxlength)
{
	new String:sFilter[128];
	for (new x = 0; x < strlen(word); x++)
	{
		decl String:sBuffer[128];
		strcopy(sBuffer, sizeof(sBuffer), sFilter);
		Format(sFilter, sizeof(sFilter), "%s%s", CHAR_FILTER, sBuffer);
	}
	strcopy(word, maxlength, sFilter);
}

stock bool:IsStringBlank(const String:input[])
{
	new len = strlen(input);
	for (new i=0; i<len; i++)
	{
		if (!IsCharSpace(input[i]))
		{
			return false;
		}
	}
	return true;
}

public ConVarSettingsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bDisplayMsg = GetConVarBool(g_CvarFilterMsg);
}