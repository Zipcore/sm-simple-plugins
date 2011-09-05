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

#define PLUGIN_VERSION	"0.1.0"
#define CHAR_FILTER			"*"

new Handle:g_hBannedWords = INVALID_HANDLE;

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
	
	RegAdminCmd("sm_reloadscf", Command_Reload, ADMFLAG_CONFIG,  "Reloads settings from the config files");
	
	g_hBannedWords = CreateArray(128, 1);
	
	ProcessConfigFile("configs/simple-chatfilter.cfg");
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "scp"))
	{
		SetFailState("Simple Chat Processor Unloaded.  Plugin Disabled.");
	}
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	if (SaidBadWord(message, MAX_MESSAGE_LENGTH))
	{
		new userid = GetClientUserId(author);
		CreateTimer(0.001, SendFilterMessage, userid, TIMER_FLAG_NO_MAPCHANGE);
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
	ProcessConfigFile("configs/simple-chatfiler.cfg");
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
	
	new Handle:hFile = OpenFile(sConfigFile, "r");
	new String:sBadWord[128];
	
	do
	{
		ReadFileLine(hFile, sBadWord, sizeof(sBadWord));
		TrimString(sBadWord);
		if (sBadWord[0] == '\0' || sBadWord[0] == ';' || (sBadWord[0] == '/' && sBadWord[1] == '/'))
		{
			continue;
		}
		PushArrayString(g_hBannedWords, sBadWord);
	} while (!IsEndOfFile(hFile));
	
	CloseHandle(hFile);
}

stock bool:SaidBadWord(String:message[], maxlength)
{
	new index = 0;
	new iArrayBannedSize = GetArraySize(g_hBannedWords);
	new bool:bBad = false;
	new String:sWords[64][128];

	StripQuotes(message);
	ExplodeString(message, " ", sWords, sizeof(sWords), sizeof(sWords[]));

	do
	{
		TrimString(sWords[index]);

		new BannedIndex = -1;
		
		for (new i = 0; i < iArrayBannedSize; i++)
		{
			new String:sBuffer[512];
			GetArrayString(g_hBannedWords, i, sBuffer, sizeof(sBuffer));
			if (StrContains(sWords[index], sBuffer, false) != -1)
			{
				BannedIndex = i;
				break;
			}
		}
		
		if (BannedIndex != -1)
		{
			FilterWord(sWords[index], sizeof(sWords[]));
			bBad = true;
		}
		
		index++;
	} while !IsStringBlank(sWords[index]);

	ImplodeStrings(sWords, sizeof(sWords), " ", message, maxlength);
	TrimString(message);
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