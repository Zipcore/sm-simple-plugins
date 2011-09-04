/************************************************************************
*************************************************************************
Simple Plugins
Description:
	Included file for Simple Chat Processor in the Simple Plugins project
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
$Id: simple-plugins.inc 132 2010-01-25 03:30:42Z antithasys $
$Author: antithasys $
$Revision: 132 $
$Date: 2010-01-24 21:30:42 -0600 (Sun, 24 Jan 2010) $
$LastChangedBy: antithasys $
$LastChangedDate: 2010-01-24 21:30:42 -0600 (Sun, 24 Jan 2010) $
$URL: https://sm-simple-plugins.googlecode.com/svn/trunk/Simple%20Plugins%20Core/addons/sourcemod/scripting/include/simple-plugins.inc $
$Copyright: (c) Simple Plugins 2008-2009$
*************************************************************************
*************************************************************************/

#if defined _scp_included
  #endinput
#endif
#define _scp_included

#define MAX_MESSAGE_LENGTH 256
//MAX_NAME_LENGTH  <-- This already exists

#define CHATFLAGS_INVALID		0
#define CHATFLAGS_ALL				(1<<0)
#define CHATFLAGS_TEAM				(1<<1)
#define CHATFLAGS_SPEC				(1<<2)
#define CHATFLAGS_DEAD				(1<<3)

/**********************************************************************
 * When a player types a chat message
 * Use constants MAX_NAME_LENGTH and MAX_MESSAGE_LENGTH for formating
 * Do not rely on the recipients handle to exist beyond the forward
 *
 * @param 		author							The client index of the player who sent the chat message (Byref)
 * @param 		recipients					The handle to the client index adt array of the players who should recieve the chat message
 * @param 		name							The client's name of the player who sent the chat message (Byref)
 * @param 		message						The contents of the chat message (Byref)
 * @noreturn
 **********************************************************************/
forward Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[]);

/**********************************************************************
 * Gets the current flags for the chat message
 * Should only be called within OnChatMessage()
 *
 * @return		The current type of chat message (see constants) 
 **********************************************************************/
 native GetMessageFlags();

/**
Shared plugin information
**/
public SharedPlugin:_pl_scp = 
{
	name = "scp",
	file = "simple-chatprocessor.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public _pl_scp_SetNTVOptional()
{
	MarkNativeAsOptional("GetMessageType");
}
#endif