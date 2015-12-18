Simple Plugins is a collection of game server plugins, written in SourceMod and Metamod:Source, designed to provide some great tools for admins and donators. There are currently a few plugins already released and supported with more in development. Our focus has been Counter-Strike: Source, Day of Defeat: Source, Team Fortress 2, but we expect to expand into Left 4 Dead as well as other popular mods.

## Simple Plugins Core ##

This is the core plugin for the Simple Plugins project. It is required for most of the plugins developed by us. This plugin provides a central location of reusable code and allows us to code our plugins to work with multiple game mods.

## Simple AllTalk Manager ##

This plugin allows you to set alltalk at different times during the game. It loads the game event, reasons, and settings from a config file and should be compatible with every single game mod. This is one of the only plugins that does not require the core plugin.

## Simple Chat Colors ##

This plugin allows server admins to customize the colors of the names and chat messages of a player or group of players. It is very customizable and works with HLstatsX:CE.

## Simple Class Notifier ##

This plugin was written for Team Fortress 2 and will notifiy players on the same team when a certain class is to low (not enough players playing the class) and to high (to many players playing the class). This plugin does not restrict the classes in any way, it only tries to get the teams to be more evenly distributed in classes by informing the players and suggesting they switch.

## Simple Spectate ##

This plugin displays a hud to spectators. The hud can be restricted to only admins with a certain flag, and only provides certain options to admins and public players based upon cvars. Admins have the ability to punish the player directly from the hud, including ban (supports SourceBans and MySQLBans), kick, slap, slay, beacon, etc., and a custom feature to flag a player as a cheater which makes that player to cause no damage to other players and kills them on any fall damage.

## Simple Team Balancer ##

This plugin balances teams based upon player count. It is very customizable and allows the admin to set numerous options on how the balance is performed, who is immune, and even allows players to select a buddy and tries to keep them together during a balance.

## Simple Team Manager ##

This plugin allows admins to manage players and their teams. It also has a feature to allow players with a certain flag to swap their team. It has a built-in scramble command that can either restart the round or not, and allows players to vote for a scramble if enabled.