#!/bin/bash

# A script for Clover Theme Manager
# Copyright (C) 2014-2015 Blackosx
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# Extracts bootlog from ioreg and then parses it for theme info.
# Html is then constructed and injected in to the main template.
    
# ---------------------------------------------------------------------------------------
SetHtmlBootlogSectionTemplates()
{
    blcOpen="        <div id=\"bandHeader\"><span class=\"infoTitle\">Boot Device Info<\/span><\/div>"
    blcLineDeviceInfoMbr="        <div id=\"bandDescription\">\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">Type:<\/span><span class=\"infoBody\">${blBootDeviceType} (${blBootDevicePartType})<\/span><\/div>\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">Signature:<\/span><span class=\"infoBody\">${blBootDevicePartSignature}<\/span><\/div>\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">Partition #:<\/span><span class=\"infoBody\">${blBootDevicePartition}<\/span><\/div>\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">Start:<\/span><span class=\"infoBody\">${blBootDevicePartStartDec}<\/span><\/div>\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">Size:<\/span><span class=\"infoBody\">${blBootDevicePartSizeDec}<\/span><\/div>\
        <\/div>"
    blcLineDeviceInfoGpt="        <div id=\"bandDescription\">\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">Type:<\/span><span class=\"infoBody\">${blBootDeviceType} (${blBootDevicePartType})<\/span><\/div>\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">Signature:<\/span><span class=\"infoBody\">${blBootDevicePartSignature}<\/span><\/div>\
        <\/div>"
    blcLineDevice="        <div id=\"bandHeader\"><span class=\"infoTitle\">Boot Device<\/span><\/div>\
        <div id=\"bandDescription\">\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">Identifier:<\/span><span class=\"infoBody\">${gBootDeviceIdentifierPrint}<\/span><\/div>\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">mountpoint:<\/span><span class=\"infoBody\">${mountpointPrint}<\/span><\/div>\
        <\/div>"
    blcLineNvram="        <div id=\"bandHeader\"><span class=\"infoTitle\">NVRAM<\/span><\/div>\
        <div id=\"bandDescription\">\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">read from:<\/span><span class=\"infoBody\">${blNvramReadFromPrint}<\/span><\/div>\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">Clover.Theme:<\/span><span class=\"infoBodyTheme\">${blNvramThemeEntry}<\/span><\/div>\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">theme existed?:<\/span><span class=\"${nvramThemeExistsCssClass}\">${nvramExistText}<\/span><\/div>\
        <\/div>"
    blcLineNvramNoTheme="        <div id=\"bandHeader\"><span class=\"infoTitle\">NVRAM<\/span><\/div>\
        <div id=\"bandDescription\">\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">read from:<\/span><span class=\"infoBody\">${blNvramReadFromPrint}<\/span><\/div>\
        <\/div>"
    blcLineConfig="        <div id=\"bandHeader\"><span class=\"infoTitle\">config.plist<\/span><\/div>\
        <div id=\"bandDescription\">\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">path:<\/span><span class=\"infoBody\">${blConfigPlistFilePathPrint}<\/span><\/div>\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">theme entry:<\/span><span class=\"infoBodyTheme\">${blConfigPlistThemeEntry}<\/span><\/div>\
        <\/div>"
    blcLineThemeAsked="        <div id=\"bandHeader\"><span class=\"infoTitle\">Theme asked for<\/span><\/div>\
        <div id=\"bandDescription\">\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">path:<\/span><span class=\"infoBody\">${blThemeAskedForPathPrint}<\/span><\/div>\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">theme existed?<\/span><span class=\"${themeExistCssClass}\">${blThemeExists}<\/span><\/div>\
        <\/div>"
    blcLineThemeUsed="        <div id=\"bandHeader\"><span class=\"infoTitle\">Theme used<\/span><\/div>\
        <div id=\"bandDescription\">\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">path:<\/span><span class=\"infoBody\">${blThemeUsedPathPrint}<\/span><\/div>\
            <div id=\"bandCbandColumnLeftolumnRight\"><span class=\"infoTitle\">Chosen:<\/span><span class=\"infoBodyTheme\">${blThemeNameChosen}<\/span><\/div>\
        <\/div>"
    blcLineOverrideUi="        <div id=\"bandHeader\"><span class=\"infoTitle\">Override in GUI<\/span><\/div>\
        <div id=\"bandDescription\">\
            <div id=\"bandColumnLeft\"><span class=\"infoTitle\">theme:<\/span><span class=\"infoBody\">${blGuiOverrideTheme}<\/span><\/div>\
        <\/div>"
}

# ---------------------------------------------------------------------------------------
SetBootlogTextColourClasses()
{
    # Set class and text of NVRAM theme exists
    if [ $blNvramThemeExists -eq 0 ]; then
        nvramThemeExistsCssClass="infoBodyGreen"
        nvramExistText="Yes"
    elif [ $blNvramThemeExists -eq 1 ]; then
        nvramThemeExistsCssClass="infoBodyRed"
        nvramExistText="No"
    fi
    
    # Set class of 'theme exists' text
    if [ "$blThemeExists" == "No" ]; then
        themeExistCssClass="infoBodyRed"
    else
        themeExistCssClass="infoBodyGreen"
    fi
}

# ---------------------------------------------------------------------------------------
ReadBootLog()
{
    if [ -f "$bootLogFile" ]; then
    
        # Is bootlog from Clover?
        local checkLog=$( grep "Starting Clover" $bootLogFile )
        if [ "$checkLog" != "" ]; then
               
            # Set default vars
            blCloverRevision=""               # Clover revision
            blBootType=""                     # Either legacy or UEFI
            blBootDeviceType="-"              # Example: USB, SATA, VenHW
            blBootDevicePartition=""          # Example: 1
            blBootDevicePartType=""           # Example: MBR, GPT
            blBootDevicePartSignature=""      # Example: GUID (for GPT), 0x00000000 (for MBR)
            blBootDevicePartStart=""          # Example: 0x28
            blBootDevicePartSize=""           # Example: 0x64000
            blConfigOem=""                    # Example: OEM
            blNvramPlistVolume=""             # OS X volume name: Example: Macintosh HD
            blNvramPlistExists=1              # Set to 0 if existence of nvram.plist is detected
            blNvramThemeEntry=""              # Theme name from nvram
            blNvramBootArgs=1                 # Set to 0 if boot-args found in NVRAM. (Shows NVRAM is working if Clover.Theme var not used).
            blNvramReadFrom=""                 # Either full path to nvram.plist or 'Native NVRAM'
            blNvramThemeExists=1              # Set to 0 if theme exists
            blNvramThemeAbsent=1              # Set to 0 if theme in nvram is absent
            blConfigPlistFilePath=""          # Path for config.plist
            blConfigPlistThemeEntry=""        # Theme name from config.plist
            blGuiOverrideTheme=""             # Theme name if set from GUI
            blGuiOverrideThemeChanged=1       # Set to 0 if theme set in GUI was used
            blThemeAskedForPath=""            # Set to path
            blThemeAskedForTitle=""           # Set to theme name as it's detected.
            blThemeExists="Yes"               # Set to 'No' if not exists, or 'Always' if embedded.
            blUsedRandomTheme=1               # Set to 0 if no default theme set and random theme used
            blThemeUsedPath=""                # Path of the theme used
            blUsingTheme=""                   # Theme used
            blThemeNameChosen=""              # Name of theme finally chosen
            blUsingEmbedded=1                 # Set to 0 if embedded theme used
            
            # gBootDeviceIdentifier is passed from script.sh # Example disk0s1 or 'Failed'
            mountpoint=""
            mountpointPrint=""

            while read -r lineRead
            do
            
                if [[ "$lineRead" == *"Starting Clover"* ]]; then
                    blCloverRevision="${lineRead##*Starting Clover rev }"
                    blCloverRevision="${blCloverRevision% on*}"
                    blBootType="${lineRead#*on }"
                    if [[ "$blBootType" == *"CLOVER EFI"* ]]; then
                        blBootType="Legacy"
                    else
                        blBootType="UEFI"
                    fi
                fi
                
                #0:100  0:000  SelfDevicePath=PciRoot(0x0)\Pci(0x1F,0x2)\Sata(0x0,0xFFFF,0x0)\HD(1,GPT,BC1B343C-2D6B-4C0C-8B88-71C2AFCF6E65,0x28,0x64000) @C7AA598
                if [[ "$lineRead" == *"SelfDevicePath"* ]]; then

                    # Get device path and split in to parts
                    devicePath="${lineRead#*=}"
                    declare -a devicePathArr
                    IFS=$'\\'
                    devicePathArr=($devicePath)
                    IFS="$oIFS"
                    blBootDeviceType="${devicePathArr[2]%(*}"
                    
                    for ((i=0; i<${#devicePathArr[@]}; i++))
                    do
                        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}devicePathArr[$i]=${devicePathArr[$i]}"
                    done

                    # Split HD in to parts
                    #devicePathHD="${devicePathArr[$hd]}"
                    devicePathHD="${devicePathArr[3]%)*}"
                    devicePathHD="${devicePathHD#*(}"
                    # Should be something like these examples:
                    #1,MBR,0x2A482A48,0x2,0x4EFC1B80
                    #2,GPT,F55D9AC4-08A8-4269-9A8E-396DBE7C7943,0x64028,0x1C0000
                    declare -a hdArr
                    IFS=$','
                    hdArr=($devicePathHD)
                    IFS="$oIFS"
                    blBootDevicePartition="${hdArr[0]}"
                    blBootDevicePartType="${hdArr[1]}"
                    blBootDevicePartSignature="${hdArr[2]}"
                    blBootDevicePartStart="${hdArr[3]}"
                    blBootDevicePartSize="${hdArr[4]}"

                    if [[ "$blBootDevicePartType" == *GPT* ]]; then
                        # Translate Device UUID to mountpoint
                        if [ "$gBootDeviceIdentifier" != "" ]; then
                            mountpoint=$( "$partutil" --show-mountpoint "$gBootDeviceIdentifier" )
                            if [[ "$mountpoint" == *$gESPMountPrefix* ]]; then
                                mountpointPrint="$mountpoint (aka /Volumes/EFI)"
                            else
                                mountpointPrint="$mountpoint"
                            fi
                        fi
                    elif [[ "$blBootDevicePartType" == *MBR* ]]; then
                        if [ "$gBootDeviceIdentifier" != "" ] && [ "$gBootDeviceIdentifier" != "Failed" ]; then
                            mountpoint="/"$( df -laH | grep /dev/"$gBootDeviceIdentifier" | cut -d'/' -f 4- )
                            mountpointPrint="$mountpoint"
                        fi
                    fi
                fi
                
                # 3:539  0:023  Using OEM config.plist at path: EFI\CLOVER\config.plist
                if [[ "$lineRead" == *"config.plist at path:"* ]]; then
                    blConfigOem="${lineRead##*Using }"
                    blConfigOem="${blConfigOem% config.plist*}"
                fi
                
                # 3:539  0:000  EFI\CLOVER\config.plist loaded: Success
                if [[ "$lineRead" == *"config.plist loaded: Success"* ]]; then
                    blConfigPlistFilePath=$( echo "$lineRead" | awk '{print $3}' )
                    blConfigPlistFilePath="/"$( echo "$blConfigPlistFilePath" | sed 's/\\/\//g' )
                fi
                
                # 0:110  0:000  Default theme: red
                if [[ "$lineRead" == *"Default theme"* ]]; then
                    blConfigPlistThemeEntry="${lineRead##*: }"
                    blThemeAskedForTitle="$blConfigPlistThemeEntry"
                fi
                
                # 6:149  0:172  Loading nvram.plist from Vol 'OSX' - loaded, size=2251
                if [[ "$lineRead" == *"Loading nvram.plist"* ]]; then
                    blNvramPlistVolume="${lineRead#*\'}"
                    blNvramPlistVolume="${blNvramPlistVolume%\'*}"
                fi
                
                # 6:167  0:018  PutNvramPlistToRtVars ...
                if [[ "$lineRead" == *"PutNvramPlistToRtVars"* ]]; then
                    blNvramPlistExists=0
                fi
                
                # 6:167  0:000   Adding Key: Clover.Theme: Size = 11, Data: 62 6C 61 63 6B 5F 67 72 65 65 6E 
                if [[ "$lineRead" == *"Adding Key: Clover.Theme:"* ]]; then
                    # Remove any trailing spaces
                    blNvramThemeEntry=$( echo "${lineRead##*Data:}" | sed 's/ *$//g' )
                    # Check for new style boot log
                    if [ "${blNvramThemeEntry:0:5}" != " Size" ]; then
                        blNvramThemeEntry="${blNvramThemeEntry// /\\x}"
                        blNvramThemeEntry="$blNvramThemeEntry\\n"
                        blNvramThemeEntry=$( printf "$blNvramThemeEntry" )
                        blNvramReadFrom="/Volumes/${blNvramPlistVolume}/nvram.plist"
                        blThemeAskedForTitle="$blNvramThemeEntry"
                    else # older style boot log
                        blNvramThemeEntry="not shown in bootlog"
                        blNvramReadFrom="/Volumes/${blNvramPlistVolume}/nvram.plist"
                    fi
                fi
                
                # 0:718  0:000  theme ios7 chosen from nvram is absent, using theme defined in config: red
                if [[ "$lineRead" == *"chosen from nvram is absent"* ]]; then
                    blNvramThemeEntry="${lineRead#*theme }"
                    blNvramThemeEntry=$( echo "${blNvramThemeEntry%chosen from*}" | sed 's/ *$//g' )
                    if [ "$blNvramReadFrom" == "" ]; then
                        blNvramReadFrom="Native NVRAM"
                    fi
                    blNvramThemeAbsent=0
                    blThemeAskedForTitle="$blConfigPlistThemeEntry"
                fi
                
                # 0:732  0:000  found boot-args in NVRAM:-v kext-dev-mode=1, size=18
                if [[ "$lineRead" == *"found boot-args in NVRAM"* ]]; then
                    blNvramBootArgs=0
                fi
                
                if [[ "$lineRead" == *"EDITED:"* ]]; then
                    blGuiOverrideTheme="${lineRead##*: }"
                fi
                
                if [[ "$lineRead" == *"change theme"* ]]; then
                    if [ "$blGuiOverrideTheme" != "" ]; then
                        blGuiOverrideThemeChanged=0
                    fi
                fi
                
                if [[ "$lineRead" == *"no default theme"* ]]; then
                    if [[ "$lineRead" == *"get random"* ]]; then
                        blUsedRandomTheme=0
                    fi
                fi
                
                # 0:718  0:000  Using theme 'red' (EFI\CLOVER\themes\red)
                if [[ "$lineRead" == *"Using theme"* ]]; then
                    blUsingTheme="${lineRead#*\'}"
                    blUsingTheme="${blUsingTheme%\'*}"
                    blThemeUsedPath="${lineRead#*(}"
                    blThemeUsedPath="${blThemeUsedPath%)*}"
                    blThemeUsedPath=$( echo "$blThemeUsedPath" | sed 's/\\/\//g' )
                    blThemeUsedPath="/${blThemeUsedPath%/*}"
                fi
                
                # 6:208  0:000  theme black_green defined in NVRAM found and theme.plist parsed
                if [[ "$lineRead" == *"defined in NVRAM found"* ]]; then
                    blNvramThemeEntry="${lineRead#*theme }"
                    blNvramThemeEntry="${blNvramThemeEntry% defined*}"
                    if [ "$blNvramReadFrom" == "" ]; then
                        blNvramReadFrom="Native NVRAM"
                    fi
                    blNvramThemeExists=0
                fi
                
                # 6:227  0:000  Choosing theme black_green
                if [[ "$lineRead" == *"Choosing theme"* ]]; then
                    blThemeNameChosen=$( echo "${lineRead##*Choosing theme }" | sed 's/ *$//' )
                fi
                
                # 1:848  0:000  no themes available, using embedded
                if [[ "$lineRead" == *"no themes available, using embedded"* ]]; then
                    blUsingEmbedded=0
                fi

            done < "$bootLogFile"
        else
            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}Found boot.log but Not Clover."
        fi
    else
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}$bootLogFile was not found."
    fi
}

# ---------------------------------------------------------------------------------------
PostProcess()
{
    if [ $blUsingEmbedded -eq 0 ]; then
        blThemeUsedPath="internal"
        blThemeNameChosen="embedded"
    fi

    if [ "$blNvramThemeEntry" != "" ] && [ $blNvramThemeAbsent -eq 1 ]; then
        blThemeAskedForTitle="$blNvramThemeEntry"
    elif [ "$blConfigPlistThemeEntry" != "" ]; then
        blThemeAskedForTitle="$blConfigPlistThemeEntry"
    else
        blThemeAskedForTitle=""
    fi

    if [ "$blThemeAskedForTitle" == "$blUsingTheme" ]; then
        blThemeAskedForPath="${blThemeUsedPath}"/"${blThemeAskedForTitle}"
    else
        if [ "$blUsingTheme" == "" ] && [ "$blThemeAskedForTitle" == "embedded" ]; then
            blThemeAskedForPath="internal"
            blThemeExists="Always"
        else
            blThemeAskedForPath="${blConfigPlistFilePath%/*}/Themes/${blThemeAskedForTitle}"
            blThemeExists="No"
        fi
    fi

    #if [ $blUsedRandomTheme -eq 0 ]; then
    #    blThemeNameChosen="$blThemeNameChosen (random)"s
    #fi

    if [ "$blNvramReadFrom" == "Native NVRAM" ]; then
        gNvramWorkingType="Native"
    fi

    if [ $blNvramPlistExists -eq 0 ]; then
        gNvramWorkingType="Fake"
    fi
    
    if [ "$blNvramReadFrom" == "" ] && [ $blNvramPlistExists -eq 0 ] && [ "$blNvramThemeEntry" == "" ]; then
        blNvramReadFrom="/Volumes/${blNvramPlistVolume}/nvram.plist"
    fi
    
    if [ "$mountpoint" != "" ]; then
        if [[ "$mountpoint" == *$gESPMountPrefix* ]]; then
            blThemeUsedPath="/Volumes/EFI${blThemeUsedPath}"
        else
            blThemeUsedPath="${mountpoint}${blThemeUsedPath}"
        fi
    fi

    if [ "$mountpoint" != "" ]; then
        if [[ "$mountpoint" == *$gESPMountPrefix* ]]; then
            blConfigPlistFilePathPrint="/Volumes/EFI${blConfigPlistFilePath}"
            blThemeAskedForPathPrint="/Volumes/EFI${blThemeAskedForPath}"
        else
            blConfigPlistFilePathPrint="${mountpoint}${blConfigPlistFilePath}"
            blThemeAskedForPathPrint="${mountpoint}${blThemeAskedForPath}"
        fi
        blConfigPlistFilePath="${mountpoint}${blConfigPlistFilePath}"
    else
        mountpoint="not found" && mountpointPrint="not found"
        blConfigPlistFilePathPrint="${blConfigPlistFilePath}"
        blThemeAskedForPathPrint="${blThemeAskedForPath}"
    fi
    
    # Convert device hex info to human readable
    blBootDevicePartStartDec=$(echo "ibase=16; ${blBootDevicePartStart#*x}" | bc)
    blBootDevicePartSizeDec=$(echo "ibase=16; ${blBootDevicePartSize#*x}" | bc)
    
    [[ "$gBootDeviceIdentifier" == "" ]] && gBootDeviceIdentifier="not found"
    [[ "$gBootDeviceIdentifier" == "Failed" ]] && gBootDeviceIdentifier="Failed to detect"
}

# ---------------------------------------------------------------------------------------
EscapeVarsForHtml()
{
    gBootDeviceIdentifierPrint=$( echo "$gBootDeviceIdentifier" | sed 's/\//\\\//g' )
    mountpointPrint=$( echo "$mountpointPrint" | sed 's/\//\\\//g' )
    blConfigPlistFilePathPrint=$( echo "$blConfigPlistFilePathPrint" | sed 's/\//\\\//g' )
    blNvramReadFromPrint=$( echo "$blNvramReadFrom" | sed 's/\//\\\//g' )
    blThemeUsedPathPrint=$( echo "$blThemeUsedPath" | sed 's/\//\\\//g' )
    blThemeAskedForPathPrint=$( echo "$blThemeAskedForPathPrint" | sed 's/\//\\\//g' )
}

# ---------------------------------------------------------------------------------------
CheckNvramIsWorking()
{
    # $blBootType (either UEFI or Legacy) / $gNvramWorkingType (either Fake or Native)
    if [ "$blBootType" != "" ] && [ "$gNvramWorkingType" != "" ]; then
    
        if [ "$blBootType" == "Legacy" ]; then
            # Check for necessary files to save nvram.plist file to disk
            if [ -f /Library/LaunchDaemons/com.projectosx.clover.daemon.plist ]; then
                local checkState=$( grep -A1 "RunAtLoad" /Library/LaunchDaemons/com.projectosx.clover.daemon.plist)
                if [[ "$checkState" == *true* ]]; then
                    if [ -f "/Library/Application Support/Clover/CloverDaemon" ]; then
                        if [ -f /private/etc/rc.clover.lib ]; then
                            if [ -f /private/etc/rc.shutdown.d/80.save_nvram_plist.local ]; then
                                gNvramWorking=0
                            fi
                        fi
                    fi
                fi
            fi
        fi

        if [ "$blBootType" == "UEFI" ]; then
            if [ "$gNvramWorkingType" == "Native" ]; then
                gNvramWorking=0
            fi
        fi
    fi
}

# ---------------------------------------------------------------------------------------
PrintVarsToLog()
{
    WriteToLog "${debugIndentTwo}Read Boot Log"
    WriteToLog "${debugIndentTwo}Clover Revision=$blCloverRevision"
    WriteToLog "${debugIndentTwo}Boot Type=$blBootType"
    WriteToLog "${debugIndentTwo}bootDevice partNo=$blBootDevicePartition"
    WriteToLog "${debugIndentTwo}bootDevice partType=$blBootDevicePartType"
    WriteToLog "${debugIndentTwo}bootDevice partSignature=$blBootDevicePartSignature"
    WriteToLog "${debugIndentTwo}bootDevice partLBA=$blBootDevicePartStart"
    WriteToLog "${debugIndentTwo}bootDevice partSize=$blBootDevicePartSize"
    WriteToLog "${debugIndentTwo}identifier: ${gBootDeviceIdentifier}"
    WriteToLog "${debugIndentTwo}mountpoint: ${mountpoint}"
    WriteToLog "${debugIndentTwo}Config.plist OEM=$blConfigOem"
    WriteToLog "${debugIndentTwo}Config.plist file path: $blConfigPlistFilePath"
    WriteToLog "${debugIndentTwo}Config.plist theme entry: $blConfigPlistThemeEntry"
    WriteToLog "${debugIndentTwo}NVRAM.plist volume location: $blNvramPlistVolume"
    WriteToLog "${debugIndentTwo}NVRAM.plist exists? (1=No, 0=Yes): $blNvramPlistExists"
    WriteToLog "${debugIndentTwo}NVRAM read from: $blNvramReadFrom"
    WriteToLog "${debugIndentTwo}NVRAM theme entry: $blNvramThemeEntry"
    WriteToLog "${debugIndentTwo}NVRAM theme absent? (1=No, 0=Yes): $blNvramThemeAbsent"
    WriteToLog "${debugIndentTwo}NVRAM theme exist? (1=No, 0=Yes): $blNvramThemeExists"
    WriteToLog "${debugIndentTwo}Theme asked for path: $blThemeAskedForPath"
    WriteToLog "${debugIndentTwo}Theme asked for exist: $themeExist"
    WriteToLog "${debugIndentTwo}Theme set in UI? (1=No, 0=Yes): $blGuiOverrideThemeChanged"
    WriteToLog "${debugIndentTwo}Random theme used? (1=No, 0=Yes):$blUsedRandomTheme"
    WriteToLog "${debugIndentTwo}Theme chosen in UI: $blGuiOverrideTheme"
    WriteToLog "${debugIndentTwo}Theme used path: $blThemeUsedPath"
    WriteToLog "${debugIndentTwo}Theme used chosen: $blThemeNameChosen"
    WriteLinesToLog
    WriteToLog "${debugIndentTwo}NVRAM working type: $gNvramWorkingType"
    WriteToLog "${debugIndentTwo}Is nvram working? (1=No, 0=Yes): $gNvramWorking"
    WriteLinesToLog
    WriteToLog "${debugIndentTwo}mountpointPrint=$mountpointPrint"
    WriteToLog "${debugIndentTwo}blConfigPlistFilePathPrint=$blConfigPlistFilePathPrint"
    WriteToLog "${debugIndentTwo}blNvramReadFromPrint=$blNvramReadFromPrint"
    WriteToLog "${debugIndentTwo}blThemeUsedPathPrint=$blThemeUsedPathPrint"
    WriteToLog "${debugIndentTwo}blThemeAskedForPathPrint=$blThemeAskedForPathPrint"
    WriteLinesToLog
}

# ---------------------------------------------------------------------------------------
PopulateNvramFunctionalityBand()
{
    local message=""
    local fillColour=""
    
    [[ DEBUG -eq 1 ]] && WriteLinesToLog
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}PopulateNvramFunctionalityBand() option $1"
    
    if [ "$1" == "0" ]; then
    
        if [ $gNvramWorking -eq 0 ]; then
            if [ "$blBootType" == "Legacy" ]; then
                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}Launch Daemon \&amp; rc scripts are installed and operational. NVRAM changes will be saved."
                message="Launch Daemon \&amp; rc scripts are installed and operational. NVRAM changes will be saved."
                fillColour="nvramFillWorking"
            elif [ "$blBootType" == "UEFI" ]; then
                [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}Native NVRAM is functional and direct changes will be retained next boot."
                message="Native NVRAM is functional and direct changes will be retained next boot."
                fillColour="nvramFillWorking"
            fi
        elif [ $gNvramWorking -eq 1 ]; then
            if [ "$blBootType" == "Legacy" ]; then
                message="Launch Daemon \&amp; rc scripts not operational. Direct changes to NVRAM won't be retained next boot. Run Clover Installer to fix."
                fillColour="nvramFillNotWorking"
            elif [ "$blBootType" == "UEFI" ]; then
                if [ "$gNvramWorkingType" == "" ]; then
                    if [ $blNvramBootArgs -eq 0 ]; then
                        message="Native NVRAM is working but not being used for default theme choice."
                        fillColour="nvramFillWorking"
                    else
                        message="Bootlog showed NVRAM is not being used for default theme choice."
                        fillColour="nvramFillNotWorking"
                    fi
                fi
            fi
        fi
    
    elif [ "$1" == "1" ]; then
        
        if [ ! -f "$bootLogFile" ]; then
            [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}This system was not booted using Clover."
            message="This system was not booted using Clover."
            fillColour="nvramFillRed"
        fi
    
    fi
    
    if [ "$message" != "" ]; then
        # Create html mesasage
        local htmlToInsert="    <div id=\"NvramFunctionalityBand\" class=\"${fillColour}\">\
        <div id=\"nvramTextArea\">\
            <span class=\"textBody\">${message}<\/span>\
        <\/div>\
    <\/div> <!-- End NvramFunctionalityBand -->"

        # Insert bootlog Html in to placeholder
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}Inserting nvram functionality message HTML in to managethemes.html"
        LANG=C sed -ie "s/<!--INSERT_NVRAM_MESSAGE_BAND_HERE-->/${htmlToInsert}/g" "${PUBLIC_DIR}"/managethemes.html
    fi
}

# ---------------------------------------------------------------------------------------
PopulateBootLogTitleBand()
{
    # Create bootlog band and title html
    bootlogBandTitleHtml="    <div id=\"BootLogTitleBar\" class=\"bootlogBandFill\">"
    bandTitle="        <span class=\"titleBarTextTitle\">LAST BOOT\&nbsp;\&nbsp;\&\#x25BE\&nbsp;\&nbsp;\&nbsp;\&nbsp;|<\/span>"
    bandTitleDescStart="        <span class=\"titleBarTextDescription\">"
    
    # No nvram theme entry and chosen theme matches config.plist entry
    if [ "$blNvramThemeEntry" == "" ] && [ "$blThemeNameChosen" == "$blConfigPlistThemeEntry" ]; then
        bootlogBandTitleHtml="${bootlogBandTitleHtml}${bandTitle}${bandTitleDescStart}${blBootType} Clover ${blCloverRevision} loaded <span class=\"themeName\">$blThemeNameChosen<\/span> as set in ${blConfigPlistFilePathPrint} on device ${gBootDeviceIdentifier}<\/span>"
    
    # nvram theme entry was used
    elif [ "$blNvramThemeEntry" != "" ] && [ "$blThemeNameChosen" == "$blNvramThemeEntry" ]; then
        bootlogBandTitleHtml="${bootlogBandTitleHtml}${bandTitle}${bandTitleDescStart}${blBootType} Clover ${blCloverRevision} loaded <span class=\"themeName\">$blThemeNameChosen<\/span> as set in Clover.Theme var from ${blNvramReadFromPrint}<\/span>"
    
    # nvram theme entry points to non-existent theme AND chosen theme matches config.plist entry
    elif [ "$blNvramThemeEntry" != "" ] && [ $blNvramThemeExists -eq 1 ] && [ "$blThemeNameChosen" == "$blConfigPlistThemeEntry" ] && [ "$themeExist" == "Yes" ] && [ $blNvramThemeAbsent -eq 0 ]; then
        bootlogBandTitleHtml="${bootlogBandTitleHtml}${bandTitle}${bandTitleDescStart}${blBootType} Clover ${blCloverRevision} loaded <span class=\"themeName\">$blThemeNameChosen<\/span> as set in ${blConfigPlistFilePathPrint} as NVRAM theme was absent<\/span>"

    # Any pointed to theme does not exist AND embedded theme was not used AND random theme was used
    #elif [ "$themeExist" == "No" ] && [ $blUsingEmbedded -eq 1 ]; then
    elif [ $blNvramThemeExists -eq 1 ] && [ $blUsingEmbedded -eq 1 ] && [ $blUsedRandomTheme -eq 0 ]; then
        bootlogBandTitleHtml="${bootlogBandTitleHtml}${bandTitle}${bandTitleDescStart}${blBootType} Clover ${blCloverRevision} loaded a random theme as it couldn't find the theme asked for<\/span>"
    
    # Embedded theme was used
    elif [ $blUsingEmbedded -eq 0 ]; then
        bootlogBandTitleHtml="${bootlogBandTitleHtml}${bandTitle}${bandTitleDescStart}${blBootType} Clover ${blCloverRevision} loaded theme embedded as it couldn't find any themes<\/span>"
    
    # Something else happened
    else
        bootlogBandTitleHtml="${bootlogBandTitleHtml}${bandTitle}${bandTitleDescStart}${blBootType} Clover ${blCloverRevision}<\/span>"
    fi
    bootlogBandTitleHtml="${bootlogBandTitleHtml}    <\/div> <!-- End BootLogTitleBar -->"

    # Insert bootlog Html in to placeholder
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}Inserting bootlog Band Title HTML in to managethemes.html"
    LANG=C sed -ie "s/<!--INSERT_BOOTLOG_BAND_TITLE_HERE-->/${bootlogBandTitleHtml}/g" "${PUBLIC_DIR}"/managethemes.html && (( insertCount++ ))
}

# ---------------------------------------------------------------------------------------
PopulateBootLog()
{
    # Create bootlog container HTML
    bootlogHtml="    <div id=\"BootLogContainer\" class=\"nvramFillNone\">"

    # Add HTML for Boot Device Info / Boot Device Sections
    if [ "$blBootDevicePartType" == "MBR" ]; then
        bootlogHtml="${bootlogHtml}${blcOpen}${blcLineDeviceInfoMbr}${blcLineDevice}"
    elif [ "$blBootDevicePartType" == "GPT" ]; then
        bootlogHtml="${bootlogHtml}${blcOpen}${blcLineDeviceInfoGpt}${blcLineDevice}"
    fi

    # Add HTML for NVRAM section
    if [ "$blNvramReadFrom" != "" ]; then
        if [ "$blNvramThemeEntry" != "" ]; then
            bootlogHtml="${bootlogHtml}${blcLineNvram}"
        else
            bootlogHtml="${bootlogHtml}${blcLineNvramNoTheme}"
        fi
    fi
    
    # Add HTML for Config.plist / Theme asked for sections
    bootlogHtml="${bootlogHtml}${blcLineConfig}${blcLineThemeAsked}"
    
    if [ $blGuiOverrideThemeChanged -eq 0 ] && [ "$blGuiOverrideTheme" != "" ]; then
        bootlogHtml="${bootlogHtml}${blcLineOverrideUi}"
    fi
    
    # Add HTML for Theme used section
    bootlogHtml="${bootlogHtml}${blcLineThemeUsed}"
    
    # Add ending HTML
    bootlogHtml="${bootlogHtml}    <\/div> <!-- End BootLogContainer -->"

    # Insert bootlog Html in to placeholder
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}Inserting bootlog HTML in to managethemes.html"
    LANG=C sed -ie "s/<!--INSERT_BOOTLOG_INFO_HERE-->/${bootlogHtml}/g" "${PUBLIC_DIR}"/managethemes.html && (( insertCount++ ))

    # Clean up
    if [ -f "${PUBLIC_DIR}"/managethemes.htmle ]; then
        rm "${PUBLIC_DIR}"/managethemes.htmle
    fi
}

# ---------------------------------------------------------------------------------------
CheckNvramIsWorkingAndInserthtml()
{
    # $blBootType (either UEFI or Legacy) / $gNvramWorkingType (either Fake or Native)
    if [ "$blBootType" != "" ] && [ "$gNvramWorkingType" != "" ]; then
    
        local message=""
        local colour=""
        
        if [ "$blBootType" == "Legacy" ]; then
            # Check for necessary files to save nvram.plist file to disk
            if [ -f /Library/LaunchDaemons/com.projectosx.clover.daemon.plist ]; then
                local checkState=$( grep -A1 "RunAtLoad" /Library/LaunchDaemons/com.projectosx.clover.daemon.plist)
                if [[ "$checkState" == *true* ]]; then
                    if [ -f "/Library/Application Support/Clover/CloverDaemon" ]; then
                        if [ -f /private/etc/rc.clover.lib ]; then
                            if [ -f /private/etc/rc.shutdown.d/80.save_nvram_plist.local ]; then
                                gNvramWorking=0
                            fi
                        fi
                    fi
                fi
            fi
            if [ $gNvramWorking -eq 0 ]; then
                message="Launch Daemon \&amp; rc scripts are installed and operational. NVRAM changes will be saved."
                colour="nvramFillWorking"
            elif [ $gNvramWorking -eq 1 ]; then
                message="Launch Daemon \&amp; rc scripts not operational. Direct changes to NVRAM won't be retained next boot. Run Clover Installer to fix."
                colour="nvramFillNotWorking"
            fi
        fi

        if [ "$blBootType" == "UEFI" ]; then
            if [ "$gNvramWorkingType" == "Native" ]; then
                message="Native NVRAM is functional and changes will be saved."
                colour="nvramFillWorking"
                gNvramWorking=0
            fi
        fi
        
    else
        message="This system was not booted using Clover."
        colour="nvramFillRed"
    fi
    
    if [ "$message" != "" ]; then
        # Create html mesasage
        #local htmlToInsert="        <span class=\"textBody\">${message}<\/span>"
        local htmlToInsert="    <div id=\"NvramFunctionalityBand\" class=\"${colour}\">\
        <div id=\"nvramTextArea\">\
            <span class=\"textBody\">${message}<\/span>\
        <\/div>\
    <\/div> <!-- End NvramFunctionalityBand -->"

        # Insert bootlog Html in to placeholder
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}Inserting nvram functionality message HTML in to managethemes.html"
        LANG=C sed -ie "s/<!--INSERT_NVRAM_MESSAGE_BAND_HERE-->/${htmlToInsert}/g" "${PUBLIC_DIR}"/managethemes.html
    fi
}


# Resolve path
SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P) && SELF_PATH=$SELF_PATH/$(basename -- "$0")
source "${SELF_PATH%/*}"/shared.sh

# Check for missing temp dir in case of local script testing.
[[ ! -d $TEMPDIR ]] && mkdir -p $TEMPDIR

# *************************************************************************
# Copy managethemes.html.template for testing only.
# Comment these two lines out for normal use
#cp "$PUBLIC_DIR"/managethemes.html.template "$TEMPDIR"/managethemes.html && PUBLIC_DIR="$TEMPDIR"
# *************************************************************************

[[ DEBUG -eq 1 ]] && WriteLinesToLog
[[ DEBUG -eq 1 ]] && WriteToLog "${debugIndent}bootlog.sh"

gNvramWorkingType=""
gNvramWorking=1                   # Set to 0 if writing to nvram can be saved for next boot
insertCount=0                     # increments each time an html block is injected in to managethemes.html
gBootDeviceIdentifier="$1"

if [ -f "$bootLogFile" ]; then
    ReadBootLog
    PostProcess
    CheckNvramIsWorking
    EscapeVarsForHtml
    [[ DEBUG -eq 1 ]] && PrintVarsToLog

    # Write boot device info to file
    echo "${blBootDevicePartition}@${blBootDevicePartType}@${blBootDevicePartSignature}@${blBootDevicePartStartDec}@${blBootDevicePartSizeDec}" > "$bootDeviceInfo"

    # Create NVRAM functionality band
    PopulateNvramFunctionalityBand "0"

    # Show user what happened last boot
    PopulateBootLogTitleBand
    SetBootlogTextColourClasses
    SetHtmlBootlogSectionTemplates
    PopulateBootLog

    # Add message in to log for initialise.js to detect.
    if [ $insertCount -eq 2 ]; then
        WriteToLog "CTM_BootlogOK"
    else
        [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}insertCount=$insertCount | boot.log html failed to be inserted".
    fi

    # Write some vars to file for script.sh to use.
    if [ "$blNvramReadFrom" != "" ]; then
        echo "nvram@$blNvramReadFrom" >> "$bootlogScriptOutfile"
    elif [ $blNvramBootArgs -eq 0 ]; then
        echo "nvram@Native NVRAM" >> "$bootlogScriptOutfile"
    fi
    [[ "$blConfigPlistFilePath" != "" ]] && echo "config@$blConfigPlistFilePath" >> "$bootlogScriptOutfile"
    [[ "$blBootType" != "" ]] && echo "bootType@$blBootType" >> "$bootlogScriptOutfile"
    echo "nvramSave@$gNvramWorking" >> "$bootlogScriptOutfile"
    
else
    # TO FIGURE OUT
    PopulateNvramFunctionalityBand "1"
    
    # Add message in to log for initialise.js to detect.
    WriteToLog "CTM_BootlogMissing"
    [[ DEBUG -eq 1 ]] && WriteToLog "${debugIndentTwo}boot.log does not exist".
fi