#!/bin/bash

# Simple Plugins - Simple sourcemod plugins for source based games
# http://www.simple-plugins.com
# Copyleft (C) 2007-2010 Simple Plugins
#             
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; 

# Package Prefix
# Example: HLXCommunityEdition
PKG_PREFIX=HLXCE-snapshot-r

# Configure these to the absolute paths of the SVN trunk local copy
# and the directory were we should package the release.
TRUNK_DIR=/home/hlxmaster/builds/trunk

# Configure where to temporary build the package
TEMP_DIR=/home/hlxmaster/builds/temp

# Configure the absolute path to the Sourcemod Scripting folder
# Used to compile sourcemod plugins (when applicable)
SOURCEMOD_DIR=/home/hlxmaster/builds/sourcemod/addons/sourcemod/scripting

# Configure the absolute path to the AMXmodX Scripting folder
# Used to compile AMX plugins
AMXMODX_DIR=/home/hlxmaster/builds/amxmodx/addons/amxmodx/scripting

# Configure where to save completed packages
OUTPUT_DIR=/home/hlxmaster/master.hlxcommunity.com/builds

# NOTHING TO CHANGE BELOW THIS LINE
# -----------------------------------------------------------------------------

# Get the current directory
CURRENT_DIR=`pwd`

# Divider is used to seperate sections
DIVIDER="==================================================================================================="

# Verify we have a revision rev number
if [ "$1" != "" ]; then
	REV=$1
else
	echo "[-] No revision number specified."
	exit 1
fi


# Update trunk and see if we've got work
svn update ${TRUNK_DIR} | grep "trunk/"
if [ "$?" == "0" ]; then

	echo -ne "[+] A change in trunk has been detected.  Building revision ${REV}\\n\\n"

	# Make sure the temp directory exists -- if so, clean it up.
	echo -ne "[+] Setting up ${TEMP_DIR} for build bot\\n\\n"
	if [ ! -w ${TEMP_DIR} ]; then
		if [ ! -d ${TEMP_DIR} ]; then
			mkdir ${TEMP_DIR}
			if [ $? != 0 ]; then
				echo "[-] Could not create ${TEMP_DIR}"
				exit 1
			fi
		fi
	else
        	rm -Rf ${TEMP_DIR}/*

	fi

	svn export -q --force ${TRUNK_DIR} ${TEMP_DIR}

	# Remove directories that should not be in the shipped packages
	echo -ne "[+] Removing unneeded/unshipable files and folders\\n\\n"
	
	rm -Rf ${TEMP_DIR}/build
	rm -Rf ${TEMP_DIR}/extras
	rm -Rf ${TEMP_DIR}/scripts/DONOTSHIP
	find ${TEMP_DIR}/heatmaps/src/* -type d -exec rm -Rf {} \;


	# Set additional permissions on folders
	echo -ne "[+] Setting permissions on hlstatsimg/games directory\\n\\n"
	find ${TEMP_DIR}/web/hlstatsimg/games/ -type d -exec chmod 777 {} \; 2> /dev/null

        # Symlink the HLXCE plugins and compile
        echo -ne "[+] Setting up symlinks for HLXCE plugin compile\\n\\n"
        ln -fs ${TEMP_DIR}/sourcemod/scripting/*.sp ${SOURCEMOD_DIR}/ > /dev/null
        ln -fs ${TEMP_DIR}/sourcemod/scripting/include/*.inc ${SOURCEMOD_DIR}/include/ > /dev/null
        ln -fs ${TEMP_DIR}/amxmodx/scripting/*.sma ${AMXMODX_DIR}/ > /dev/null
        mkdir ${TEMP_DIR}/sourcemod/plugins
        mkdir ${TEMP_DIR}/amxmodx/plugins

        echo -ne "${DIVIDER}\\n\\n[+] Compiling SourceMod Plugin \\n\\n"
        cd ${SOURCEMOD_DIR}
        for sm_source in hlstats*.sp
        do
                smxfile="`echo ${sm_source} | sed -e 's/\.sp$/.smx/'`"
                ./spcomp ${sm_source} -o${TEMP_DIR}/sourcemod/plugins/${smxfile} | grep -q Error
                if [ $? = 0 ]; then
                        echo " [!] WARNING: ${smxfile} DID NOT COMPILE SUCCESSFULLY."
                        exit
                else
                        echo " [+] ${smxfile} compiled successfully."
                fi
        done
        echo -ne \\n
        echo -ne "[+] SourceMod plugins compiled \\n\\n${DIVIDER}\\n\\n"

        echo -ne "[+] Compiling AMXMODX plugins \\n\\n"
        cd ${AMXMODX_DIR}
        for amx_source in hlstatsx_*.sma
        do
                amxxfile="`echo ${amx_source} | sed -e 's/\.sma$/.amxx/'`"
                ./amxxpc ${amx_source} -o${TEMP_DIR}/amxmodx/plugins/${amxxfile} | grep -q Done
                if [ $? -eq 0 ]; then
                        echo " [+] ${amxxfile} compiled successfully"
                else
                        echo " [!] WARNING: ${amxxfile} DID NOT COMPILE SUCCESSFULLY."
                        exit
                fi
        done
        echo -ne \\n
        echo -ne "[+] AMXMODX plugins compiled \\n\\n${DIVIDER}\\n\\n"

	cd ${TEMP_DIR}
	echo -ne "${DIVIDER}\\n\\n[+] Creating TGZ package\\n\\n"
	tar --owner=0 --group=users -czf ${OUTPUT_DIR}/${PKG_PREFIX}${REV}.tar.gz *
	echo -ne "[+] Creating ZIP package\\n\\n"
	zip -r ${OUTPUT_DIR}/${PKG_PREFIX}${REV}.zip * > /dev/null
	echo -ne "[+] Packages created\\n\\n"

	echo -ne "${DIVIDER}\\n\\n[+] Build for revision ${REV} complete.\\n"
else
	echo -ne "[-] No update to trunk.  Not building a release.\\n"
fi
exit 0
