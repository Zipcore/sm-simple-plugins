/************************************************************************
*************************************************************************
Simple AutoScrambler
Description:
	Automatically scrambles the teams based upon a number of events.
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
new Handle:g_hVoteMenu;

stock CreateVoteCommand()
{
	new String:sBuffer[64], String:sVoteCommand[64];
	GetTrieString(g_hSettings, "vote_trigger", sBuffer, sizeof(sBuffer));
	Format(sVoteCommand, sizeof(sVoteCommand), "sm_%s", sBuffer);
	RegConsoleCmd(sVoteCommand, Command_Vote, "Command used to start a vote to scramble the teams");
}

stock StartVote()
{
	if (IsVoteInProgress())
		return;
	g_hVoteMenu = CreateMenu(VoteCallback, MenuAction:MENU_ACTIONS_ALL);
	SetMenuTitle(g_hVoteMenu, "Scramble the teams?");
	AddMenuItem(g_hVoteMenu, "yes", "Yes");
	AddMenuItem(g_hVoteMenu, "no", "No");
	SetMenuExitButton(g_hVoteMenu, false);
	VoteMenuToAll(g_hVoteMenu, 25);	
}

public VoteCallback(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			CloseHandle(g_hVoteMenu);
			g_hVoteMenu = INVALID_HANDLE;
		}
		case MenuAction_VoteEnd:
		{
			new iVotes, iTotalVotes;
			if (param1 == 0)
			{
				new Float:fSuccess = float(GetSettingValue("vote_menu_percentage")) / 100.0;
				GetMenuVoteInfo(param2, iVotes, iTotalVotes);
				if ((float(iVotes) / float(iTotalVotes)) >= fSuccess)
				{
					PrintToChatAll("\x01\x04[SAS]\x01 %t" "Vote_Succeeded", iVotes, iTotalVotes);
					DelayVoting(Vote_Success);
				}
				else
				{
					PrintToChatAll("\x01\x04[SAS]\x01 %t" "Vote_Fail_Percent", iVotes, iTotalVotes);
					DelayVoting(Vote_Fail);
				}
			}
			else
			{
				PrintToChatAll("\x01\x04[SAS\x01\%t" "Vote_Failed", iVotes, iTotalVOtes);
				DelayVoting(Vote_Fail);
			}		
		}
	}
}

public Action:Command_Say(client, args)
{
	if (client)
	{	
		new String:sBuffer[64], sArg[64];
		GetCmdArgString(sArg, sizeof(sArg);
		new startidx = 0;
		if (sArg[strlen(sArg)-1] == '"')
		{
			sArg[strlen(sArg)-1] = '\0';
			startidx = 1;
		}	
		/**
		see if the args supplied are equal to our trigger
		*/
		if (strcmp(text[startidx], sBuffer, false) == 0)
		{
			new ReplySource:old = SetCmdReplySource(SM_REPLY_TO_CHAT);	
			AttemptVote(client);
			SetCmdReplySource(old);		
		}			
	}
	return Plugin_Continue;		
}

public Action:Command_Vote(client, args)
{
	if (client)
	{
		AttemptVote(client);
	}	
	return Plugin_Handled;
}

stock AttemptVote(client)
{
	if (!GetSettingValue("vote_enabled"))
	{
		ReplyToCommand(client, "\x01\x04[SAS]\x01 %t", "Vote_Disabled");
		return;
	}
	if (GetClientCount() < GetSettingValue("vote_min_players"))
	{
		ReplyToCommand(client, "\x01\x04[SAS]\x01 %t", "Vote_Min_Players");
		return;
	}
	if (g_iVoteAllowed > GetTime())
	{
		ReplyToCommand(client, "\x01\x04[SAS]\x01 %t", "Vote_Delayed");
		return;
	}
	/**
	now we made it though the checks, tally the votes
	*/
	new iVotesNeeded = GetVotesNeeded(),
			String:sClientName[MAX_NAME_LENGTH+1];
			
	/**
	block the client from putting in the last vote when there is a vote in progress
	*/
	
	if (!GetSettingValue("vote_style") && IsVoteInProgress() && iVotesNeeded - g_iVotes <= 1)
	{
		ReplyToCommand(client, "\x01\x04[SM]\x01 %t", "Vote in Progress");
		return;
	}
	
	/**
	notify a vote has been tallied
	*/
	GetClientName(client, sClientName, sizeof(sClientName);
	g_iVotes++;
	g_aPlayers[client][bVoted] = true;
	PrintToChatAll("\x01\x04[SAS]\x01 %t", "Vote_Added", sClientName, g_iVotes, iVotesNeeded);
	
	/**
	see if the trigger has been met
	*/
	if (g_iVotes >= iVotedNeeded)
	{
		DelayVoting(Vote_Success);
		ResetVotes();
		if (GetSettingValue("vote_style"))
		{
			StartScramble(e_ScrambleMode:GetSettingValue("sort_mode");
		}
		else
		{
			StartVote();
		}
	}
}

stock GetVotesNeeded()
{
	new Float:fPercent = GetSettingValue("vote_tigger_percentage") / 100,
			iMinimum = GetSettingVlaue("vote_min_triggers"),
			iVotesNeeded = RoundToFloor(float(GetClientCount()) * fPercent;
	if (iVotesNeeded < iMinimum)
		return iMinimum;
	else
		return iVotesNeeded;
}

stock ResetVotes()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		g_aPlayers[i][bVoted] = false;
	}
	g_iVotes = 0;
}

stock DelayVoting(e_DelayReasons:reason)
{
	switch (reason)
	{
		case Vote_Initiate:
		{
			g_iVoteAllowed = GetTime() + GetSettingValue("vote_initial_delay");
		}
		case Vote_Fail:
		{
			g_iVoteAllowed = GetTime() + GetSettingValue("vote_fail_delay");
		}
		case Vote_Success:
		{
			g_iVoteAllowed = GetTime() + GetSettingValue("vote_success_delay");
		}
		case Vote_Scrambled:
		{
			g_iVoteAllowed = GetTime() + GetSettingValue("vote_scramble_delay");
		}
	}
}

stock StopVote()
{
	if (g_hVoteMenu != INVALID_HANDLE)
	{
		CloseHandle(g_hVoteMenu);
	}
	g_hVoteMenu = INVALID_HANDLE;
}