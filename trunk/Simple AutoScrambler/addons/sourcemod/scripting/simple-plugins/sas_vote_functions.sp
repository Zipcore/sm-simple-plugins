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

enum 	e_DelayReasons
{
	Reason_MapStart,
	Reason_Success,
	Reason_Fail,
	Reason_Scrambled
};

new 	Handle:g_hVoteMenu;

new		g_iVotes,
			g_iVoteAllowed;

stock CreateVoteCommand()
{
	new String:sBuffer[64], String:sVoteCommand[64];
	GetTrieString(g_hSettings, "vote_trigger", sBuffer, sizeof(sBuffer));
	Format(sVoteCommand, sizeof(sVoteCommand), "sm_%s", sBuffer);
	RegConsoleCmd(sVoteCommand, Command_Vote, "Command used to start a vote to scramble the teams");
}

public Action:Command_Vote(client, args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if (!GetSettingValue("vote_enabled")
		|| (GetSettingValue("vote_admin_disables") && g_iAdminsPresent)
	{
		ReplyToCommand(client, "\x01\x04[SAS]\x01 %t", "Vote_Disabled");
		return Plugin_Handled;
	}
	
	if (GetClientCount() < GetSettingValue("vote_min_players"))
	{
		ReplyToCommand(client, "\x01\x04[SAS]\x01 %t", "Vote_Min_Players");
		return Plugin_Handled;
	}
	
	if (g_iVoteAllowed > GetTime())
	{
		ReplyToCommand(client, "\x01\x04[SAS]\x01 %t", "Vote_Delayed");
		return Plugin_Handled;
	}
	
	if (g_aPlayers[client][bVoted])
	{
		PrintToChatAll("\x01\x04[SAS]\x01 %t", "Vote_AlreadyVoted");
		return Plugin_Handled;
	}
	
	/**
	Block the client from putting in the last vote when there is a vote in progress
	*/
	/*  I DONT REALLY GET THIS?!?!
	if (!GetSettingValue("vote_style") && IsVoteInProgress() && iVotesNeeded - g_iVotes <= 1)
	{
		ReplyToCommand(client, "\x01\x04[SM]\x01 %t", "Vote in Progress");
		return Plugin_Handled;
	}
	*/
	
	new bool:bDoVoteAction = false;
	
	/**
	Check the voting style
	*/
	if (!GetSettingValue("vote_style"))
	{
		
		/**
		RTV voting
		*/
		new	iMinimum = GetSettingVlaue("vote_min_triggers"),
		if (g_iVotes < iMinimum)
		{
			
			/**
			Add the vote to the tally
			*/
			g_iVotes++;
			g_aPlayers[client][bVoted] = true;
			PrintToChatAll("\x01\x04[SAS]\x01 %t", "Vote_Added", client, g_iVotes, iVotesNeeded);
		}
		else
		{
			bDoVoteAction = true;
		}
	}
	else
	{
		
		/**
		This is basic chat voting
		*/
		new	Float:fPercent = GetSettingValue("vote_chat_percentage") / 100;
		new	iVotesNeeded = RoundToFloor(float(GetClientCount()) * fPercent;
		if (g_iVotes < iVotedNeeded)
		{
		
			/**
			Add the vote to the tally
			*/
			g_aPlayers[client][bVoted] = true;
			if (g_iVotes++ <= iVotedNeeded)
			{
				PrintToChatAll("\x01\x04[SAS]\x01 %t", "Vote_Added", client, g_iVotes, iVotesNeeded);
				if (g_iVotes == iVotedNeeded)
				{
					bDoVoteAction = true;
				}
			}
		}
	}
	
	/**
	See if the trigger has been met
	*/
	if (bDoVoteAction)
	{
		DelayVoting(Reason_Success);
		ResetVotes();
		if (GetSettingValue("vote_style"))
		{
			StartVote();
		}
		else
		{
			if (GetSettingValue("vote_action"))
			{
				StartScramble(e_ScrambleMode:GetSettingValue("sort_mode");
			}
			else
			{
				g_bScrambleNextRound = true;
			}
		}
	}
	
	return Plugin_Handled;
}

public Menu_VoteEnded(Handle:menu, MenuAction:action, param1, param2)
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
			GetMenuVoteInfo(param2, iVotes, iTotalVotes);
			if (param1 == 0)
			{
				new Float:fSuccess = float(GetSettingValue("vote_menu_percentage")) / 100.0;
				if ((float(iVotes) / float(iTotalVotes)) >= fSuccess)
				{
					PrintToChatAll("\x01\x04[SAS]\x01 %t" "Vote_Succeeded", iVotes, iTotalVotes);
					DelayVoting(Reason_Success);
					ResetVotes();
					if (GetSettingValue("vote_action"))
					{
						StartScramble(e_ScrambleMode:GetSettingValue("sort_mode");
					}
					else
					{
						g_bScrambleNextRound = true;
					}
				}
				else
				{
					PrintToChatAll("\x01\x04[SAS]\x01 %t" "Vote_Fail_Percent", iVotes, iTotalVotes);
					DelayVoting(Reason_Fail);
				}
			}
			else
			{
				PrintToChatAll("\x01\x04[SAS\x01\%t" "Vote_Failed", iVotes, iTotalVOtes);
				DelayVoting(Reason_Fail);
			}
		}
	}
}

stock StartVote()
{
	if (IsVoteInProgress())
	{
		PrintToChatAll("\x01\x04[SAS]\x01 %t" "Vote_InProgress");
		return;
	}
	
	g_hVoteMenu = CreateMenu(Menu_VoteEnded);
	SetMenuTitle(g_hVoteMenu, "Scramble the teams?");
	AddMenuItem(g_hVoteMenu, "yes", "Yes");
	AddMenuItem(g_hVoteMenu, "no", "No");
	SetMenuExitButton(g_hVoteMenu, false);
	VoteMenuToAll(g_hVoteMenu, 25);	
}

stock StopVote()
{
	if (g_hVoteMenu != INVALID_HANDLE)
	{
		CloseHandle(g_hVoteMenu);
	}
	g_hVoteMenu = INVALID_HANDLE;
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
		case Reason_MapStart:
		{
			g_iVoteAllowed = GetTime() + GetSettingValue("vote_initial_delay");
		}
		case Reason_Success:
		{
			g_iVoteAllowed = GetTime() + GetSettingValue("vote_success_delay");
		}
		case Reason_Fail:
		{
			g_iVoteAllowed = GetTime() + GetSettingValue("vote_fail_delay");
		}
		case Reason_Scrambled:
		{
			g_iVoteAllowed = GetTime() + GetSettingValue("vote_scramble_delay");
		}
	}
}