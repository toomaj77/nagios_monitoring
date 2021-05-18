#!/bin/bash
rollback()
{
	level="$1"

	case "$level" in
		"1") 
			rollback_first
			;;
		"2") 
			rollback_first
			rollback_second
			;;
		"3") 
			rollback_first
			rollback_second
			rollback_third
			;;
		"4")
			;;
	esac
}

rollback_first()
{
	included_files=$BASEDIR/../config/templates/*.conf
	
	#Copy back original config files to template folder
	if [ ! "`echo $included_files`" = "$BASEDIR/../config/templates/*.conf" ] 
	then
		for j in $included_files 
		do
			if [  -f "$j.dellbkp" ] && [  -f "$j" ] 
			then
				mv -f "$j.dellbkp" "$j"
			fi
		done
	fi  
	
	#Copy back original Dell EMC specific config file to script folder
	if [  -f "$BASEDIR/../scripts/dellconfig.cfg.dellbkp" ] && [  -f "$BASEDIR/../scripts/dellconfig.cfg" ] 
	then   
		mv -f "$BASEDIR/../scripts/dellconfig.cfg.dellbkp" "$BASEDIR/../scripts/dellconfig.cfg"
	fi
	
	#Copy back original dell_commands.cfg file to script folder
	if [  -f "$BASEDIR/../config/templates/dell_commands.cfg" ] && [  -f "$BASEDIR/../config/templates/dell_commands.cfg.dellbkp" ] 
	then   
		mv -f "$BASEDIR/../config/templates/dell_commands.cfg.dellbkp" "$BASEDIR/../config/templates/dell_commands.cfg"
	fi
	
	#Copy back original Dell EMC specific config file to script folder
    if [ "$MULTILINE" = "1" ] 
	then   
		sed -i 's/^escape_html_tags[ \t]*=[ \t]*0/escape_html_tags = 1/g' "${NAGIOS_HOME}/etc/cgi.cfg"
	fi
	
	
	rm -rf ${NAGIOS_HOME}/dell
	rm -rf ${NAGIOS_HOME}/var/dell
	
}

rollback_second()
{
    #Copy back original nagios.cfg file
	if [  -f "${NAGIOS_HOME}/etc/nagios.cfg.dellbkp" ] && [  -f "${NAGIOS_HOME}/etc/nagios.cfg" ] 
	then
		mv -f "${NAGIOS_HOME}/etc/nagios.cfg.dellbkp" "${NAGIOS_HOME}/etc/nagios.cfg"
	fi
}

rollback_third()
{
    #Copy back original snmptt.ini file
	if [  -f "{SNMPTTINI}.dellbkp" ] && [  -f "${SNMPTTINI}" ] 
	then
		mv -f "{SNMPTTINI}.dellbkp" "${SNMPTTINI}"
	fi
}


error_exit()
{
	log_msg "$1"
	printf "\n$1\n" 1>&2
	printf "\n$3 is Unsuccessful.\n"
	rollback "$2"
	exit $FAILURE
}

log_msg()
{
	echo "$1" | sed -e "s/^/$(date -R) /" >> ${LOG_FILE}
}

log_msg_print()
{
	printf "$1" | sed -e "s/^/$(date -R) /" >> ${LOG_FILE}
	printf "$1"
}

exit_if_error()
{
	if [ "$?" != "0" ]; then
		log_msg "Error:  $5"
		if [ "$USER_CHOICE_UPGRADE" = "1" ]
		then
			log_msg "Restoring the Dell Plug-in v$INSTALLEDVERSION from /var/tmp/dellomp1backup location."
			error=`cp -rf /var/tmp/dellomp1backup ${NAGIOS_HOME}/dell 2>&1 >/dev/null`
			if [ "$?" != "0" ]; then
				log_msg "Error:  $error"
				log_msg "Error: Failed to restore the backup of the Dell Plug-in v$INSTALLEDVERSION from /var/tmp/dellomp1backup location."
				log_msg_print "\nError: Failed to restore to Dell Plug-in v$INSTALLEDVERSION from /var/tmp/dellomp1backup location.\n"
				log_msg_print "\n\nRestore to Dell Plug-in v$INSTALLEDVERSION manually.\n"
				error_exit "\nExiting Installation..."  "4" "Installation"
			fi
		fi
		error_exit "$1" "$3" "$4"
	else
		log_msg  "$2"
	fi
}

check_prerequisites()
{

    log_msg_print "\nChecking prerequisites...\n"
	#Check whether the required perl modules are present

	
	JAVA_PRESENT=$(check_prerequisites_binary java)
	
	javaVersion=$("/usr/bin/java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
	IFS=. read major minor extra <<< "$javaVersion";

        if (( "$JAVA_PRESENT" == "1" )) && (( major == 1 && minor >= 6 )); then	
			log_msg_print "\tJAVA is installed.\n"			
		else
			printf "\n\tJAVA is not installed or not appropriate. Dell EMC device warranty information may not be available.\n\tPress 'Y' to continue.\n\tPress any other key to exit installation (default: 'Y'):  "
			read -e -n 1 option
			case $option in
				[Yy]*|"" )
					;;
				* ) 
					error_exit "\nExiting Installation..."  "4" "Installation"
					;;
			esac
			error=`sed -i'.dellbkp' "s|JAVAINSTALLPATH[ \t]*=[ \t]*$DEFAULTJAVAINSTALLPATH|JAVAINSTALLPATH=|g" $BASEDIR/../scripts/dellconfig.cfg  2>&1 >/dev/null`
			exit_if_error "Cannot edit $BASEDIR/../scripts/dellconfig.cfg" "$BASEDIR/../scripts/dellconfig.cfg edited successfully" "$ACTIONLEVEL" "Installation" "$error"
		fi
	PYTHON_PRESENT=$(check_prerequisites_binary python)
	
	python_version=$(python --version 2>&1 | awk '{print $2}')
      IFS=. read major minor extra <<< "$python_version";	
        if ((( "$PYTHON_PRESENT" == "1" )) && ((( major >= 2 && minor >= 7 )) || ((major >= 3)))); then		
			log_msg_print "\tPYTHON $major.$minor.$extra is installed.\n"			
		else
			printf "\n\tPYTHON version (2.7.5 / 3.6.3) or above is  not installed or not appropriate.\tPress 'Y' to continue.\n\tPress any other key to exit installation (default: 'Y'):  "
			read -e -n 1 option
			case $option in
				[Yy]*|"" )
					;;
				* ) 
					error_exit "\nExiting Installation..."  "4" "Installation"
					;;
			esac
		fi
	PYTHON_ARGPARSE_PRESENT=$(check_prerequisites_binary_pyhton_modules argparse)
	
        if (("$PYTHON_ARGPARSE_PRESENT" == "0")); then	
			log_msg_print "\tPYTHON argparse module is installed.\n"			
		else
			printf "\n\tPYTHON argparse module is not installed or not appropriate.\tPress 'Y' to continue.\n\tPress any other key to exit installation (default: 'Y'):  "
			read -e -n 1 option
			case $option in
				[Yy]*|"" )
					;;
				* ) 
					error_exit "\nExiting Installation..."  "4" "Installation"
					;;
			esac
		fi
	PYTHON_NETADDR_PRESENT=$(check_prerequisites_binary_pyhton_modules netaddr)
	
        if (( "$PYTHON_NETADDR_PRESENT" == "0" )); then	
			log_msg_print "\tPYTHON netaddr module is installed.\n"			
		else
			printf "\n\tPYTHON netaddr module is not installed or not appropriate.\tPress 'Y' to continue.\n\tPress any other key to exit installation (default: 'Y'):  "
			read -e -n 1 option
			case $option in
				[Yy]*|"" )
					;;
				* ) 
					error_exit "\nExiting Installation..."  "4" "Installation"
					;;
			esac
		fi
	
    PYTHON_OMSDK_PRESENT=$(check_prerequisites_binary_pyhton_modules omsdk)
	PYTHON_OMDRIVER_PRESENT=$(check_prerequisites_binary_pyhton_modules omdrivers)
	
	
        if (( "$PYTHON_OMSDK_PRESENT" == "0"  &&  "$PYTHON_OMDRIVER_PRESENT" == "0" )); then	
			log_msg_print "\tOpenManage Python Software Development Kit (OMSDK) module is installed.\n"			
		else
			printf "\n\tOpenManage Python Software Development Kit (OMSDK) module is not installed or not appropriate."
			
		fi

}

check_prerequisites_perl_module()
{

    #Check whether the required perl modules are present
    if !  perl -e "use $1" >/dev/null 2>&1;
    then
        echo "0"
    else
        echo "1"
    fi
}


check_prerequisites_binary()
{
    #Check whether the required perl modules are present
    if ! type "$1" >/dev/null 2>&1;
    then
        echo "0"
    else
        echo "1"
    fi

}

check_prerequisites_binary_pyhton_modules()
{  
 #Check whether the required perl modules are present
 if pip show $1 &> /dev/null; then
     echo "0"
 else
    echo "1"
 fi

}

check_prerequisites_snmptt()
{

    log_msg_print "\nChecking prerequisites...\n"
	if ! type "snmptt" >/dev/null 2>&1; then
        SNMPTT_PRESENT=0
		error_exit "\tSNMPTT is not installed or not resolvable. Pre-requisite check failed.\n\tExiting Installation..."  "4" "Installation"
	else
        SNMPTT_PRESENT=2
		log_msg_print "\tSNMPTT is installed.\n"
	fi
}


check_prerequisites_java()
{

    log_msg_print "\nChecking prerequisites...\n"
	if ! type "java" >/dev/null 2>&1; then
        JAVA_PRESENT=0
		error_exit "\tJAVA is not installed or not resolvable. Pre-requisite check failed.\n\tExiting Installation..."  "4" "Installation"
	else
	    javaVersion=$("java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
		IFS=. read major minor extra <<< "$javaVersion";
		
		if (( major == 1 && minor >= 6 )); then
            JAVA_PRESENT=2
			log_msg_print "\tJAVA is installed.\n"
		else
		    log_msg_print "\tJAVA is not installed or not appropriate. Dell EMC device warranty information may not be available.\n"
		fi
	fi
}


delete_backup_files()
{
    #Deleting backup files and folders
	log_msg "Deleting backup files"
	find $BASEDIR/.. -name "*.dellbkp" -type f -delete
	find "${NAGIOS_HOME}/dell" -name "*.dellbkp" -type f -delete
	rm -rf ${NAGIOS_HOME}/etc/nagios.cfg.dellbkp
	rm -rf ${SNMPTTINI}.dellbkp
  if [ "$USER_CHOICE_UPGRADE" = "1" ]
  then
      rm -rf /var/tmp/dellomp1backup
  fi
}

get_nagios_location()
{
		NAGIOS_HOME="/etc/nagios"
		
}


check_multiline_prompt()
{
    #Prompt to enable html tags if it is not enabled	
	multiline=`sed -n '/^escape_html_tags[ \t]*=[ \t]*0/p' "${NAGIOS_HOME}/etc/cgi.cfg"`
	if [ "$multiline" = "" ]
	then
	    log_msg_print  "\nEnabling HTML tags...\n"
		while true; do
			printf "\nThe attribute \"escape_html_tags\" in file \"cgi.cfg\" is set to 1. Set it to 0 for better readability in Nagios Core console (recommended).\nPress 'Y' if you would like to set it to '0' (default: 'N'): "
			read -e -n 1 option
			case $option in
				[Yy]* )
					error=`sed -i 's/^escape_html_tags[ \t]*=[ \t]*1/escape_html_tags = 0/g' "${NAGIOS_HOME}/etc/cgi.cfg" 2>&1 >/dev/null`
					exit_if_error "Cannot enable multiline" "Multiline enabled successfully" "$ACTIONLEVEL" "Installation" "$error"
					MULTILINE=1
					ACTIONLEVEL=1
					break
					;;   
				[Nn]*|"" ) 
					break
					;;
				* ) 
					printf "\nInvalid Command. Press 'Y' or 'N'.\n"
					;;
			esac
		done		
	fi
}


copy_files()
{ 	
	if [ ! -d "${NAGIOS_HOME}/dell" ] 
	then
	    #Creating dell folder
		log_msg_print "\nInstalling \"dell emc\" Plug-in specific folders and files...\n"
		error=`mkdir -p "${NAGIOS_HOME}/dell"  2>&1 >/dev/null`
		exit_if_error "Cannot create directory ${NAGIOS_HOME}/dell" "${NAGIOS_HOME}/dell directory created successfully" "$ACTIONLEVEL" "Installation" "$error"
        ACTIONLEVEL=1
		#Creating dell version file
		error=`touch "${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver" 2>&1 >/dev/null`
		exit_if_error "Cannot create version file" "Version file created successfully" "$ACTIONLEVEL" "Installation" "$error"
		echo "$MYVERSION" > "${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver" 
	else
		if [  -f "${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver" ] 
		then
		    printf "\nDell EMC OpenManage Plug-in v$MYVERSION for Nagios Core is already installed.\n"
			printf "\nExiting installation.\n"
			exit $FAILURE		
		else
			error=`touch "${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver"  2>&1 >/dev/null`
			exit_if_error "Cannot create version file" "Version file created successfully" "$ACTIONLEVEL" "Installation" "$error"
		    ACTIONLEVEL=1
			echo "$MYVERSION" > "${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver" 
		fi
	fi
	log_msg "Updating files..."
    #Change the nagios home location in dellconfig.cfg and dellcommands.cfg
	if [ ! "$DEFAULT_HOME" = "$NAGIOS_HOME" ] 
	then 		
		error=`sed -i'.dellbkp' "s|$DEFAULT_HOME|$NAGIOS_HOME|g" $BASEDIR/../scripts/dellconfig.cfg  2>&1 >/dev/null`
		exit_if_error "Cannot edit $BASEDIR/../scripts/dellconfig.cfg" "$BASEDIR/../scripts/dellconfig.cfg edited successfully" "$ACTIONLEVEL" "Installation" "$error"
		ACTIONLEVEL=1

		error=`sed -i'.dellbkp' "s|$DEFAULT_HOME|$NAGIOS_HOME|g" $BASEDIR/../config/templates/dell_commands.cfg  2>&1 >/dev/null`
		exit_if_error "Cannot edit $BASEDIR/../config/templates/dell_commands.cfg" "$BASEDIR/../config/templates/dell_commands.cfg edited successfully" "$ACTIONLEVEL" "Installation" "$error"
	fi
	
	if [ ! -d "${NAGIOS_HOME}/share/DellKB" ]
	then
	    error=`mkdir -p "${NAGIOS_HOME}/share/DellKB"  2>&1 >/dev/null`
	    exit_if_error "Cannot create directory ${NAGIOS_HOME}/share/DellKB" "${NAGIOS_HOME}/share/DellKB directory created successfully" "$ACTIONLEVEL" "Installation" "$error"
        ACTIONLEVEL=1
	fi
	
	#Retrieve the MS IP
	ip_address=`/sbin/ifconfig | grep -e "inet addr" | head -n 1 | awk '{print $2}' | cut -c6-`
	if [ "$ip_address" = "" ]
    then
        ip_address=`/sbin/ifconfig | grep -e "inet" | head -n 1 | awk '{print $2}' | cut -c1-`
    fi
	
	#insert MS IP address in the trap files
	trap_files=$BASEDIR/../config/templates/*.conf
	if [ ! "`echo $trap_files`" = "$BASEDIR/../config/templates/*.conf" ] 
	then
		for j in $trap_files 
		do
		    error=`sed -i'.dellbkp' "s|MSIP|$ip_address|g" "$j"  2>&1 >/dev/null`
		    exit_if_error "Cannot insert MS IP address in $j" "MS IP address inserted successfully in $j" "$ACTIONLEVEL" "Installation" "$error"
		    ACTIONLEVEL=1

		done
	fi
	
	#Change the nagios home location in trap files
	included_files=$BASEDIR/../config/templates/*.conf
	if [ ! "`echo $included_files`" = "$BASEDIR/../config/templates/*.conf" ] 
	then
		for j in $included_files 
		do
			if [ ! "$DEFAULT_HOME" = "$NAGIOS_HOME" ] 
			then 
				error=`sed -i'.dellbkp' "s|$DEFAULT_HOME|$NAGIOS_HOME|g" "$j"  2>&1 >/dev/null`
				exit_if_error "Cannot edit $j" "$j edited successfully" "$ACTIONLEVEL" "Installation" "$error"
				error=`sed -i'.dellbkp' "s|MSIP|$ip_address|g" "$j"  2>&1 >/dev/null`
				exit_if_error "Cannot insert MS IP address in $j" "MS IP address inserted successfully in $j" "$ACTIONLEVEL" "Installation" "$error"
				ACTIONLEVEL=1
			fi
		done
	fi

	#Create log directory
	if [ ! -d "${NAGIOS_HOME}/var/dell" ] 
	then
	    log_msg "Creating dell folder for logs..."
		error=`mkdir -p "${NAGIOS_HOME}/var/dell" 2>&1 >/dev/null`
		exit_if_error "Cannot create directory ${NAGIOS_HOME}/var/dell" "${NAGIOS_HOME}/var/dell directory created successfully" "$ACTIONLEVEL" "Installation" "$error"
		ACTIONLEVEL=1
	fi
    
	
    
	log_msg "\nCreating \"dell emc\" Plug-in specific folders and files...\n"
	#Creating dell log folder and giving user permissions...
	error=`chmod 750 "${NAGIOS_HOME}/var/dell" 2>&1 >/dev/null`
	exit_if_error "Cannot change permissions of ${NAGIOS_HOME}/var/dell directory" "The permissions of ${NAGIOS_HOME}/var/dell directory changed successfully" "$ACTIONLEVEL" "Installation" "$error"
    ACTIONLEVEL=1
	
	error=`chown nagios:nagios -R "${NAGIOS_HOME}/var/dell" 2>&1 >/dev/null`
	exit_if_error "Cannot change user and user group of the directory" "The user and user group of the directory changed successfully" "$ACTIONLEVEL" "Installation" "$error"
 
	if [ $UPGRADE = "0" ] 
	then
		error=`cp -rf $BASEDIR/../* "${NAGIOS_HOME}/dell" 2>&1 >/dev/null`
		exit_if_error "Cannot copy the dell directory" "dell directory successfully copied" "$ACTIONLEVEL" "Installation" "$error"
	else 
		error=`rsync -avP --exclude 'dell_resource.cfg' $BASEDIR/../* "${NAGIOS_HOME}/dell"`
		exit_if_error "Cannot copy $BASEDIR/dell directory." "$BASEDIR/dell directory copied successfully." "$ACTIONLEVEL" "Installation" "$error"
		#restore dell emc plug-in 2.1 if error occurred.
		#copy the .dell_device_comm_params.cfg file to NAGIOS_HOME's script dir
		error=`cp -f /var/tmp/dellomp1backup/dell/scripts/.dell_device_comm_params.cfg ${NAGIOS_HOME}/dell/scripts/`
		if [ "$?" != "0" ]; then
			log_msg "Error:  $error"
			log_msg_print "\nCannot copy /var/tmp/dellomp1backup/dell/scripts/.dell_device_comm_params.cfg file. Copy it manually."
		fi
		if [ -d "${NAGIOS_HOME}/dell/MIB" ]
	    then
	        error=`rm -rf "${NAGIOS_HOME}/dell/MIB"  2>&1 >/dev/null`
	        exit_if_error "Cannot delete directory ${NAGIOS_HOME}/dell/MIB" "${NAGIOS_HOME}/dell/MIB directory deleted successfully" "$ACTIONLEVEL" "Installation" "$error"
            ACTIONLEVEL=1
	    fi
		SERVICETEMPLATENAME=""
		CURRENTTEMPLATEFILE=""
		#read Dell EMC Server Service template and store in array
		if version_gt $INSTALLEDVERSION "1.0";
		then
		    SERVICETEMPLATENAME="/var/tmp/dellomp1backup/dell/scripts/dell_device_services_template.cfg"
			IFS=$'\n' read -d '' -r -a serverlines < /var/tmp/dellomp1backup/dell/scripts/dell_device_services_template.cfg
        else
		    SERVICETEMPLATENAME="/var/tmp/dellomp1backup/dell/scripts/dell_server_services_template.cfg"
			IFS=$'\n' read -d '' -r -a serverlines < /var/tmp/dellomp1backup/dell/scripts/dell_server_services_template.cfg
	    fi 
		CURRENTTEMPLATEFILE="${NAGIOS_HOME}/dell/scripts/dell_device_services_template.cfg"
	    if [ -f "$SERVICETEMPLATENAME" ];
	    then 
			for i in "${serverlines[@]}"
			do
				if [[ "$i" == *"#Dell Server"* ]]
		        then
					replaceServer="Dell EMC"
					var=$i
					IFS=#
					ary=($var)
					for key in "${!ary[@]}"
					do 
						finalstr=${ary[1]}
					done 
					dellstr1=${finalstr//Dell/$replaceServer} 
					linenumber=`grep -n "$dellstr1" $CURRENTTEMPLATEFILE  | grep -Eo '^[^:]+'`
					output=`sed -i "$linenumber"' s/^/#/' "$CURRENTTEMPLATEFILE"` 
                fi
				if [[ "$i" == *"#Dell Chassis"* ]]
		        then
					replaceServer="Dell EMC"
					var=$i
					IFS=#
					ary=($var)
					for key in "${!ary[@]}"
					do 
						finalstr=${ary[1]}
					done 
					dellstr1=${finalstr//Dell/$replaceServer} 
					linenumber=`grep -n "$dellstr1" $CURRENTTEMPLATEFILE  | grep -Eo '^[^:]+'`
					output=`sed -i "$linenumber"' s/^/#/' "$CURRENTTEMPLATEFILE"` 
                fi
				if [[ "$i" == *"#Dell Storage EqualLogic"* ]]
		        then
					replaceServer="Dell EMC Storage PS-Series"
					var=$i
					IFS=#
					ary=($var)
					for key in "${!ary[@]}"
					do 
						finalstr=${ary[1]}
					done 
					dellstr1=${finalstr//Dell Storage EqualLogic/$replaceServer} 
					linenumber=`grep -n "$dellstr1" $CURRENTTEMPLATEFILE  | grep -Eo '^[^:]+'` 
					output=`sed -i "$linenumber"' s/^/#/' "$CURRENTTEMPLATEFILE"` 
                fi
				if [[ "$i" == *"#Dell Storage Compellent"* ]]
		        then
					replaceServer="Dell EMC Storage SC-Series"
					var=$i
					IFS=#
					ary=($var)
					for key in "${!ary[@]}"
					do 
						finalstr=${ary[1]}
					done 
					dellstr1=${finalstr//Dell Storage Compellent/$replaceServer} 
					linenumber=`grep -n "$dellstr1" $CURRENTTEMPLATEFILE  | grep -Eo '^[^:]+'` 
					output=`sed -i "$linenumber"' s/^/#/' "$CURRENTTEMPLATEFILE"` 
                fi
				if [[ "$i" == *"#Dell Storage PowerVault MD"* ]]
		        then
					replaceServer="Dell EMC Storage MD-Series"
					var=$i
					IFS=#
					ary=($var)
					for key in "${!ary[@]}"
					do 
						finalstr=${ary[1]}
					done 
					dellstr1=${finalstr//Dell Storage PowerVault MD/$replaceServer} 
					linenumber=`grep -n "$dellstr1" $CURRENTTEMPLATEFILE  | grep -Eo '^[^:]+'` 
					output=`sed -i "$linenumber"' s/^/#/' "$CURRENTTEMPLATEFILE"`
                fi
			done
	  fi	
	fi
    
    log_msg "Changing the permissions of the folder dell, Install, Images, config, templates, default, objects, MIB, scripts "	
	error=`chmod 750 ${NAGIOS_HOME}/dell ${NAGIOS_HOME}/dell/Install ${NAGIOS_HOME}/dell/Images ${NAGIOS_HOME}/dell/resources ${NAGIOS_HOME}/dell/config ${NAGIOS_HOME}/dell/config/templates ${NAGIOS_HOME}/dell/scripts/default ${NAGIOS_HOME}/dell/config/objects ${NAGIOS_HOME}/dell/MIB ${NAGIOS_HOME}/dell/scripts 2>&1 >/dev/null` 
	log_msg_print ""
	exit_if_error "Error while changing the permissions" "The permissions of directories changed successfully" "$ACTIONLEVEL" "Installation" "$error"

	log_msg "Changing the permissions of the files with .sh extension in Install and .pl extension in scripts "	
	error=`chmod 700 ${NAGIOS_HOME}/dell/Install/*.sh ${NAGIOS_HOME}/dell/scripts/*.pl 2>&1 >/dev/null` 
	log_msg_print ""
	exit_if_error "Error while changing the permissions" "The permissions of directory changed successfully" "$ACTIONLEVEL" "Installation" "$error"
	
	log_msg "Changing the permissions of the files in templates, scripts folder"		
	error=`chmod 600 ${NAGIOS_HOME}/dell/config/templates/*  ${NAGIOS_HOME}/dell/scripts/*.cfg ${NAGIOS_HOME}/dell/resources/dell_resource.cfg ${NAGIOS_HOME}/dell/scripts/.dell_device_comm_params.cfg ${NAGIOS_HOME}/dell/MIB/* 2>&1 >/dev/null` 
	log_msg_print ""
	exit_if_error "Error while changing the permissions" "The permissions of directory changed successfully" "$ACTIONLEVEL" "Installation" "$error"
	
	log_msg "Changing the permissions of the files in Images folder"		
	error=`chmod 644 ${NAGIOS_HOME}/dell/Images/* 2>&1 >/dev/null` 
	log_msg_print ""
	exit_if_error "Error while changing the permissions" "The permissions of directory changed successfully" "$ACTIONLEVEL" "Installation" "$error"
	
	
	log_msg "Changing the permissions of the files in default folder"
	error=`chmod 400 ${NAGIOS_HOME}/dell/scripts/default/.dell_device_comm_params.cfg  ${NAGIOS_HOME}/dell/scripts/default/* ${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver 2>&1 >/dev/null` 
	log_msg_print ""
	exit_if_error "Error while changing the permissions" "The permissions of directory changed successfully" "$ACTIONLEVEL" "Installation" "$error"

	error=`chown nagios:nagios -R "${NAGIOS_HOME}/dell" 2>&1 >/dev/null` 
	exit_if_error "Error while changing the ownership" "The user and user group of the directory changed successfully" "ACTIONLEVEL" "Installation"

	error=`cp -pf ${NAGIOS_HOME}/dell/Images/*  ${NAGIOS_HOME}/share/images/logos/ 2>&1 >/dev/null`
	exit_if_error "Cannot copy the Images directory" "Images directory successfully copied" "$ACTIONLEVEL" "Installation" "$error"
	
	error=`cp -rf ${NAGIOS_HOME}/dell/KB/*  ${NAGIOS_HOME}/share/DellKB/ 2>&1 >/dev/null`
	exit_if_error "Cannot copy the KB directory content" "KB directory content successfully copied" "$ACTIONLEVEL" "Installation" "$error"
}


edit_nagios_cfg()
{
	log_msg_print "\nUpdating nagios.cfg...\n"
	#Adding cfg_dir entry in nagios.cfg if its not present
	cfg_dir=`sed -n '/^cfg_dir[ \t]*=[ \t]*.*\/dell\/config/p' "${NAGIOS_HOME}/etc/nagios.cfg"`
	if [ "$cfg_dir" = "" ]
	then
		error=`sed -i.dellbkp "\\$acfg_dir=${NAGIOS_HOME}/dell/config" "${NAGIOS_HOME}/etc/nagios.cfg" 2>&1 >/dev/null`
		exit_if_error "Cannot update ${NAGIOS_HOME}/etc/nagios.cfg for config directory" "${NAGIOS_HOME}/etc/nagios.cfg successfully updated for config directory" "$ACTIONLEVEL" "Installation" "$error"
		ACTIONLEVEL=2
        printf "\n\tThe following entry is added for configuring Dell EMC OpenManage Plug-in config directory:\n"
		printf "\t--------------------------------------------------\n"
		printf "\tcfg_dir=${NAGIOS_HOME}/dell/config\n"
		printf "\t--------------------------------------------------\n"
	else
	    error=`sed -i.dellbkp "s|^cfg_dir[ \t]*=[ \t]*.*/dell/config|cfg_dir=${NAGIOS_HOME}/dell/config|g" "${NAGIOS_HOME}/etc/nagios.cfg" 2>&1 >/dev/null`
		exit_if_error "${NAGIOS_HOME}/etc/nagios.cfg cannot be updated for config directory" "${NAGIOS_HOME}/etc/nagios.cfg successfully updated for config directory" "$ACTIONLEVEL" "Installation" "$error"
		ACTIONLEVEL=2 
	fi
	
}

display_snmptt_error()
{
		printf "\n\tFor Trap integration insert the following line in section "[TrapFiles]" before "END", to file snmptt.ini.\n"
		printf   "\t---------------------------------------------------------------------\n"
		included_files=${NAGIOS_HOME}/dell/config/templates/*.conf
		if [ ! "`echo $included_files`" = "${NAGIOS_HOME}/dell/config/templates/*.conf" ] 
		then
			for j in $included_files 
			do
					printf "\t$j\n"
			done   		
		fi
		printf   "\t---------------------------------------------------------------------\n"
}

edit_snmptt_ini()
{
    #Adding trap conf file entry in snmptt.ini if its not present
 	if [ "$DEFAULTSNMPTTINI" = "" ]
        then
        	SNMPTTINI=/etc/snmp/snmptt.ini

        else
        	SNMPTTINI=$DEFAULTSNMPTTINI
        fi

	printf   "\nProvide the file path where snmptt.ini is installed (Press ENTER to continue with the default file path: '$SNMPTTINI'):\n"
	read -e SNMPTTINI_INPUT
	

	if [ ! "$SNMPTTINI_INPUT" = "" ]
	then
			SNMPTTINI=$SNMPTTINI_INPUT
	fi
	
	if [ -f "$SNMPTTINI" ] && [ -f "$DEFAULTSNMPTTINI" ]
	then
		if  [ "$(stat -c "%d:%i" "$SNMPTTINI")" == "$(stat -c "%d:%i" "$DEFAULTSNMPTTINI")" ]
		then
			SNMPTTINI=$DEFAULTSNMPTTINI
			log_msg "\tUsing default snmptt.ini file path: $SNMPTTINI \n"
		fi
	else
			log_msg "\tUsing the snmptt.ini file path: $SNMPTTINI \n"
	fi
	
	if [ ! -f "$SNMPTTINI" ] 
	then
		printf "\n\n\tUnable to locate SNMPTT.ini file."
		snmptt_error=1
		display_snmptt_error
		return
	else
		log_msg_print "\tProvided file path $SNMPTTINI is valid.\n"
	fi  
	
	log_msg_print "\nUpdating snmptt.ini...\n"
	
	if [ ! "$DEFAULTSNMPTTINI" = "$SNMPTTINI" ] && [ ! "$snmptt_error" = "1" ]
	then 		
            error=`sed -i'.dellbkp' "s|SNMPTTINI[ \t]*=[ \t]*$DEFAULTSNMPTTINI|SNMPTTINI=$SNMPTTINI|g" ${NAGIOS_HOME}/dell/scripts/dellconfig.cfg  2>&1 >/dev/null`
			exit_if_error "Cannot update $BASEDIR/../scripts/dellconfig.cfg" "$BASEDIR/../scripts/dellconfig.cfg updated successfully" "$ACTIONLEVEL" "Installation" "$error"
	fi
	
	

	prev_included_files=`sed -n '/^snmptt_conf_files = <<END/,/^END/{s/snmptt_conf_files = <<END//;/^END/d;p;}' "${SNMPTTINI}"`
    error=`cp -rf "${SNMPTTINI}" "${SNMPTTINI}.dellbkp" 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "$error"
	    printf "\n\n\tUnable to update SNMPTT.ini file."
		display_snmptt_error
		return
	fi 
	exit_if_error "Cannot create the backup of snmptt.ini" "Backup of snmptt.ini successfully created" "$ACTIONLEVEL" "Installation" "$error"
	included_files=${NAGIOS_HOME}/dell/config/templates/*.conf
	if [ ! "`echo $included_files`" = "${NAGIOS_HOME}/dell/config/templates/*.conf" ] 
	then
	    for j in $included_files 
		do
			present="0"
			for i in $prev_included_files 
			do
				#if  [ "$i" = "$j" ]
				if [ -f "$i" ] && [ -f "$j"  ]
				then
					if [ "$(stat -c "%d:%i" "$i")" == "$(stat -c "%d:%i" "$j")" ]
					then
						present="1"
						break
					fi
				fi
			done
			if [ "$present" = "0" ]
			then
			    ACTIONLEVEL=3
			    error=`sed -i -e "s|^snmptt_conf_files[ \t]*=[ \t]*<<END|&\n$j|g" "${SNMPTTINI}" 2>&1 >/dev/null`
				if [ "$?" != "0" ]; then
				    log_msg "error"
					printf "\n\n\tUnable to update snmptt.ini file."
					display_snmptt_error
					return
				fi

				if [ "$append" != "1" ]
				then		
					append=1
					printf "\n\n\tThe following entry is added for supporting Dell EMC device traps:\n"
					printf   "\t---------------------------------------------------------------------\n"
				
				fi
				printf "\t$j\n"
			fi
		done
        		
	fi
	
	if [ "$append" = "1" ]
	then		
		printf   "\t---------------------------------------------------------------------\n"
	fi
				

}


configureJavaPath()
{
    #Configuring java path in the config file
 	if [ "$DEFAULTJAVALOC" = "" ]
        then
        	JAVAINSTALLPATH=/usr/bin/java

        else
        	JAVAINSTALLPATH=$DEFAULTJAVAINSTALLPATH
        fi

	printf   "\nProvide the file path where JAVA is installed (Press ENTER to continue with the default file path: '$JAVAINSTALLPATH'):\n"
	read -e JAVA_INPUT
	
	if [ ! "$JAVA_INPUT" = "" ]; then
	
		javaVersion=$($JAVA_INPUT -version 2>&1 | awk -F '"' '/version/ {print $2}')
		IFS=. read major minor extra <<< "$javaVersion";
	
	    if (( major == 1 && minor >= 6 )); then
			JAVAINSTALLPATH=$JAVA_INPUT
		else
			printf "\n\n\tUnable to locate java or the file is not appropriate. The default JAVA configuration path will be retained.\n"
			java_error=1
			return	
        fi			
	fi
	
	if [ -f "$JAVAINSTALLPATH" ] && [ -f "$DEFAULTJAVAINSTALLPATH" ]
	then
		if  [ "$(stat -c "%d:%i" "$JAVAINSTALLPATH")" == "$(stat -c "%d:%i" "$DEFAULTJAVAINSTALLPATH")" ]
		then
			JAVAINSTALLPATH=$DEFAULTJAVAINSTALLPATH
			log_msg "Using default java file path: $JAVAINSTALLPATH"
		fi
	else
			log_msg "Using the java file path: $JAVAINSTALLPATH"
	fi
	
	if [ ! -f "$JAVAINSTALLPATH" ] 
	then
		printf "\n\n\tUnable to locate java file. The default JAVA configuration path will be retained."
		java_error=1
		return
	else
		log_msg_print "\tProvided file path $JAVAINSTALLPATH is valid.\n"
	fi  
	
	log_msg_print "\nUpdating dellconfig.cfg...\n"
	
	if [ ! "$DEFAULTJAVAINSTALLPATH" = "$JAVAINSTALLPATH" ] && [ ! "$java_error" = "1" ]
	then 		
            error=`sed -i'.dellbkp' "s|JAVAINSTALLPATH[ \t]*=[ \t]*$DEFAULTJAVAINSTALLPATH|JAVAINSTALLPATH=$JAVAINSTALLPATH|g" ${NAGIOS_HOME}/dell/scripts/dellconfig.cfg  2>&1 >/dev/null`
			exit_if_error "Cannot update ${NAGIOS_HOME}/dell/scripts/dellconfig.cfg" "${NAGIOS_HOME}/dell/scripts/dellconfig.cfg updated successfully" "$ACTIONLEVEL" "Installation" "$error"
	fi
}

verify_licenses_prompt()
{
	
    	while true; do
		printf "\nRead the Dell EMC End User License Agreement (EULA) license file (license_en.txt) packaged with this product before proceeding with the installation.\nPress 'Y' to accept the license.\nPress any other key to exit installation (default: 'Y'):  "
		read -e -n 1 option
		case $option in
			[Yy]*|"" )
				break;;
			* ) 
				error_exit "\nExiting Installation..."  "4" "Installation"
				;;
		esac
	done

}


verify_nagios_installation_prompt()
{
	printf "\nFor the Dell EMC OpenManage Plug-in changes to take effect, "; 
	if [ "$SNMPTT_PRESENT" = "1" ]
	then 
		printf "verify the Nagios and SNMPTT configuration entries as per product guidelines and then restart the Nagios and SNMPTT services.\n\n"
	elif [ "$SNMPTT_PRESENT" = "2" ]
	then
	    printf "verify the SNMPTT configuration entries as per product guidelines and then restart the SNMPTT service.\n\n"
	else
		printf "verify the Nagios configuration entries as per product guidelines and then restart the Nagios service.\n\n"
	fi
}

check_previous_version()
{
   if [ -f ${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver ]
   then 
      while read line           
      do           
        if [ ! -z "$line" ]
	then 
           INSTALLEDVERSION=$line			 
	   
	   if version_gt $MYVERSION $INSTALLEDVERSION; 
	   then
             UPGRADE=1           
	     fi  
         fi		 
      done <"${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver"
   fi
   if [ "$UPGRADE" = "1" ]
   then
		while true; do
		      printf "\nDell OpenManage Plug-in v$INSTALLEDVERSION for Nagios Core is already installed.\nPress 'Y' to upgrade to Dell EMC OpenManage Plug-in v$MYVERSION for Nagios Core.\nPress any other key to exit installation (default: 'Y'):  "
		      read -e -n 1 option
		      case $option in
		      [Yy]*|"" )
              USER_CHOICE_UPGRADE=$UPGRADE
				      break;;
		      * ) 
				      error_exit "\nExiting Installation..."  "4" "Installation" ;;
		      esac
		done
		
		#take the backup of Dell Plug-in $INSTALLEDVERSION specific folders and files before removing
		error=`mkdir -p /var/tmp/dellomp1backup`
		if [ "$?" != "0" ]; then
			log_msg "Error:  $error"
			log_msg "Cannot create /var/tmp/dellomp1backup directory."
			printf "\nError: Failed to create the backup location for the Dell OpenManage Plug-in v$INSTALLEDVERSION for Nagios Core\n"
			error_exit "\nExiting Installation..."  "4" "Installation"
		else
			log_msg "Taking backup of Dell Plug-in  v$INSTALLEDVERSION in /var/tmp/dellomp1backup location."
			error=`cp -rf ${NAGIOS_HOME}/dell /var/tmp/dellomp1backup 2>&1 >/dev/null`
			if [ "$?" != "0" ]; then
				log_msg "Error:  $error"
				log_msg "Error: Failed to take the backup of the Dell OpenManage Plug-in v$INSTALLEDVERSION for Nagios Core /var/tmp/dellomp1backup location."
				log_msg_print "\nError: Failed to take the backup of the Dell OpenManage Plug-in v$INSTALLEDVERSION for Nagios Core\n"
				error_exit "\nExiting Installation..."  "4" "Installation"
			fi
		fi
   fi
}

remove_previous_ver_dir()
{
	log_msg_print "\nRemoving \"dell\" Plug-in v$INSTALLEDVERSION specific folders and files...\n"

	error=`rm -rf ${NAGIOS_HOME}/dell/config/templates 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
		log_msg "Error:  $error"
		log_msg_print "\nCannot delete ${NAGIOS_HOME}/dell/config/templates folder."
	fi 

	error=`rm -rf ${NAGIOS_HOME}/dell/Images 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		log_msg_print "\nCannot delete ${NAGIOS_HOME}/dell/Images folder."
	fi
  error=`rm -rf ${NAGIOS_HOME}/dell/Install 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		log_msg_print "\nCannot delete ${NAGIOS_HOME}/dell/Install folder."
	fi

	error=`rm -rf ${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		log_msg_print "\nCannot delete ${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver . Delete it manually"
	fi
  
	error=`rm -rf ${NAGIOS_HOME}/dell/scripts 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		log_msg_print "\nCannot delete ${NAGIOS_HOME}/dell/scripts folder. Delete it manually"
	fi
	error=`rm -rf ${NAGIOS_HOME}/var/dell 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		log_msg_print "Cannot delete ${NAGIOS_HOME}/var/dell folder"
	fi 
	error=`rm -rf ${NAGIOS_HOME}/share/images/logos/idrac.png 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		log_msg_print "Cannot delete ${NAGIOS_HOME}/share/images/logos/idrac.png"
	fi 
	
}
check_prot_comm()
{
 if [ -f "/var/tmp/dellomp1backup/dell/resources/dell_resource.cfg" ]; then  
   ret_val=' '
   nul_val=' '
   while read line
    do
      [[ $line = \#* ]] && continue
      if [ ! -z "$line"  ];then  
        IFS=$"=" read key value <<<$line
         if [ $key = $1 ]; then
             ret_val=$value
             echo "$value"
             return
         fi
      fi
    done < /var/tmp/dellomp1backup/dell/resources/dell_resource.cfg
	if [ $ret_val = $nul_val ]; then
       if [ $2 = 1 ]; then
       printf "'--snmp.community=', please update in ${NAGIOS_HOME}/dell/config/objects/$3 file with the value of $1 everywhere. $1 value is not available in ${NAGIOS_HOME}/dell/resources/dell_resource.cfg" >&2
       elif [ $2 = 2 ]; then
          printf "'--http.user=', please update in  ${NAGIOS_HOME}/dell/config/objects/$3 file with the value of $1 everywhere. $1 value is not available in ${NAGIOS_HOME}/dell/resources/dell_resource.cfg" >&2
       elif [ $2 = 3 ]; then
          printf "'--http.password=', please update in ${NAGIOS_HOME}/dell/config/objects/$3 file with the value of $1 everywhere. $1 value is not available in ${NAGIOS_HOME}/dell/resources/dell_resource.cfg" >&2
       fi
     fi
 else
      printf "please change the protocol communication parameters in ${NAGIOS_HOME}/dell/config/objects files properly." >&2
 fi
 }
object_file_cmd_rebranding(){
ARRAY=( #"info:System"
        "pd:PhysicalDisk"
        "cpu:CPU"
        "ghs:Subsystem"
        "vd:VirtualDisk"
        #"ctl:Controller"
        "amp:Sensors_Amperage"
        "int:Sensors_Intrusion"
        "fan:Sensors_Fan"
        "bat:Sensors_Battery"
        "ps:PowerSupply"
        "vlt:Sensors_Voltage"
        "temp:Sensors_Temperature"
        "nic:NIC"
        "sd:VFlash"
        "fcnic:FC"        
        "mempd:PhysicalDisk"
        "grpvol:Volume"
        "grpstor:StoragePool"
        "grpinfo:System"  
        "ps:PowerSupply"
        "fan:Fan"
        #"ctl:Controller"
        "pci:PCIDevice"
        "enc:Enclosure"
        "kvm:KVM"
        "io:IOModule"
        "slot:StorageModule"
        "computeslot:ComputeModule"
       ) 


file=${NAGIOS_HOME}/dell/config/objects/*.cfg
log_msg "started changing the service command for new formate in each object file in ${NAGIOS_HOME}/dell/config/objects/ directory."
for i in $file
do
log_msg "Checking  $i object file exist or not"
if [ -f "$i" ]; then
  log_msg "yes  $i object file exist in the location ${NAGIOS_HOME}/dell/config/objects/"
  log_msg "Started Changing  check command in each service definition of $i object file"
  sed -i 's#'$i'# #g; s/" "!/ /g' $i
  ##storing the commu protocol info
  while IFS= read -r line
  do
   if test "${line#*"_dell_comm_params"}" != "$line"
     then
        IFS=$' ,' read -r -a array <<< "$line"
   fi
   if test "${line#*"host_name"}" != "$line"
     then
        IFS=$' ,' read -r -a hostname <<< "$line"
   fi
  done < $i
  
  grep -q "check_dell_oob_server_component_wsman" $i
  if [ $? == 0 ];
  then 
  sed -i "s/ check_dell_oob_server_component_wsman! / dellemc_check_script! --devicetype=iDRAC! /g; s/ dell_check_warranty!/ dellemc_warranty_check_script! --devicetype=iDRAC!/g" $i
  fi
  grep -q "check_dell_oob_server_component_snmp" $i
  if [ $? == 0 ];
  then
  sed -i "s/ check_dell_oob_server_component_snmp! / dellemc_check_script! --devicetype=iDRAC! /; s/ dell_check_warranty!/ dellemc_warranty_check_script! --devicetype=iDRAC! /" $i
  fi
  grep -q "check_dell_chassis_component" $i
  if [ $? == 0 ];
  then
   log_msg "adding new service 'Dell EMC Chassis Server slot information' in $i object file"
   sed -i "s/ Dell EMC Chassis Slot Information / Dell EMC Chassis Storage Slot Information /" $i
   echo "      define service{" >> $i
   echo "      use                     Dell EMC Device Component Status" >> $i
   echo "      host_name               ${hostname[1]}" >> $i
   echo "      service_description     Dell EMC Chassis Server Slot Information"   >> $i 
   echo "      check_command           check_dell_chassis_component!    computeslot" >> $i
   echo "      }" >> $i
  sed -i "s/ check_dell_chassis_component! / dellemc_check_script! --devicetype=CMC! /g; s/ dell_check_warranty!/ dellemc_warranty_check_script! --devicetype=CMC!/g" $i
  fi
  grep -q "check_dell_md_component" $i
  if [ $? == 0 ];
  then  
  sed -i "s/ check_dell_md_component! / dellemc_check_script! --devicetype=MDArray!  /g; s/ dell_check_warranty!/ dellemc_warranty_check_script! --devicetype=MDArray!/g" $i
  fi 
  grep -q "check_dell_equallogic_component" $i
  if [ $? == 0 ];
  then   
  sed -i "s/ check_dell_equallogic_component! / dellemc_check_script! --devicetype=EqualLogic! /g; s/ dell_check_warranty!/ dellemc_warranty_check_script! --devicetype=EqualLogic!/g" $i
  fi
  grep -q "check_dell_compellent_component" $i
  if [ $? == 0 ];
  then
  sed -i "s/ check_dell_compellent_component! / dellemc_check_script! --devicetype=Compellent! /g; s/ dell_check_warranty!/ dellemc_warranty_check_script! --devicetype=Compellent!/g"  $i
  fi  
  edit_the_string=$i
  obj_file=`sed -e "s|$NAGIOS_HOME\/dell\/config\/objects\/||g" <<< "$edit_the_string"`
  if [[ " ${array[@]} " =~ "SNMP" ]]; then
     snmp_comm_string=$(check_prot_comm ${array[2]} 1 $obj_file)
  elif [[ " ${array[@]} " =~ "WSMAN" ]]; then
     wsman_uName=$(check_prot_comm ${array[2]} 2 $obj_file)
	   wsman_pwd=$(check_prot_comm ${array[3]} 3 $obj_file)
  fi
  for service in "${ARRAY[@]}" ; do
    key="${service%%:*}"
    VALUE="${service##*:}"
     if [[ " ${array[@]} " =~ "SNMP" ]]; then
       sed -i "s| $key|--componentname=$VALUE!  --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None!|" $i
       sed -i "s| --devicetype=iDRAC!.*mem| --devicetype=iDRAC! --componentname=Memory! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None! --excludeinstance=\"Status==OK\"!|" $i
	   sed -i "s| --devicetype=iDRAC!.*info| --devicetype=iDRAC! --componentname=System,iDRAC! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None! --setservicestatus=0!|" $i
	   sed -i "s| --devicetype=iDRAC!.*ctl| --devicetype=iDRAC! --componentname=Controller! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None! --excludeinstance=\"Status==OK\"!|" $i
       sed -i "s| warranty | --componentname=warranty! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None! --warranty.warningDays=None!  --warranty.criticalDays=None! |" $i
     elif [[ " ${array[@]} " =~ "WSMAN" ]]; then
       sed -i "s| $key|--componentname=$VALUE! --protocol=2! --http.user=$wsman_uName! --http.password=$wsman_pwd! --http.port=${array[5]}! --http.retries=${array[7]}! --http.timeout=${array[4]}! --logPath=None! |" $i
       sed -i "s| --devicetype=iDRAC!.*mem| --devicetype=iDRAC! --componentname=Memory! --protocol=2! --http.user=$wsman_uName! --http.password=$wsman_pwd! --http.port=${array[5]}! --http.retries=${array[7]}! --http.timeout=${array[4]}! --logPath=None! --excludeinstance=\"Status==OK\"!|" $i
	   sed -i "s| --devicetype=iDRAC!.*info| --devicetype=iDRAC! --componentname=System,iDRAC! --protocol=2! --http.user=$wsman_uName! --http.password=$wsman_pwd! --http.port=${array[5]}! --http.retries=${array[7]}! --http.timeout=${array[4]}! --logPath=None! --setservicestatus=0!|" $i
	   sed -i "s| --devicetype=iDRAC!.*ctl| --devicetype=iDRAC! --componentname=Controller! --protocol=2! --http.user=$wsman_uName! --http.password=$wsman_pwd! --http.port=${array[5]}! --http.retries=${array[7]}! --http.timeout=${array[4]}! --logPath=None! --excludeinstance=\"Status==OK\"!|" $i
       sed -i "s| warranty | --componentname=warranty! --protocol=2! --http.user=$wsman_uName! --http.password=$wsman_pwd! --http.port=${array[5]}! --http.retries=${array[7]}! --http.timeout=${array[4]}! --logPath=None! --warranty.warningDays=None!  --warranty.criticalDays=None! |" $i
    fi
       
  done
  idrac_array=(
  "VFlash"
  "CPU"
  #"Memory"
  "Controller"
  "PowerSupply"
  "VirtualDisk"
  "Sensors_Fan"
  "Sensors_Temperature"
  "Sensors_Battery"
  "Sensors_Amperage"
  "Sensors_Intrusion"
  "Sensors_Voltage"
  "PhysicalDisk"          
  )
  cmc_array=(
  "PhysicalDisk"
  "IOModule"
  #"PCIDevice"
  "KVM"
  "PowerSupply"
  "VirtualDisk"
  "Sensors_Fan"
  "Enclosure"
  "StorageModule"
  "ComputeModule"
  )
  
    ## iDRAC related serviceStatus
     sed -i "/ --devicetype=iDRAC!.*--componentname=NIC!/s/$/ --excludeinstance=\"ConnectionStatus==Up\"!/" $i
     sed -i "/ --devicetype=iDRAC!.*--componentname=FC!/s/$/ --excludeinstance=\"ConnectionStatus==Up\"!/" $i
     #sed -i "/ --devicetype=iDRAC!.*--componentname=System!/s/$/ --setservicestatus=0!/" $i
     
     for name in "${idrac_array[@]}" 
     do
     sed -i "/ --devicetype=iDRAC!.*--componentname=$name!/s/$/ --excludeinstance=\"Status==OK\"!/" $i
     done
     
     #CMC related serviceStatus
     sed -i "/ --devicetype=CMC!.*--componentname=Subsystem!/s/$/ --primaryStatusOnly=1!/" $i
     sed -i "/ --devicetype=CMC!.*--componentname=System!/s/$/ --setservicestatus=0!/" $i
     for name in "${cmc_array[@]}" 
     do
     sed -i "/ --devicetype=CMC!.*--componentname=$name!/s/$/ --excludeinstance=\"Status==OK\"!/" $i
     done
	 sed -i "/ --devicetype=CMC!.*--componentname=PCIDevice!/s/$/ --setservicestatus=0!/" $i
	 sed -i "s| --devicetype=CMC!.*ctl| --devicetype=CMC! --componentname=Controller! --protocol=2! --http.user=$wsman_uName! --http.password=$wsman_pwd! --http.port=${array[5]}! --http.retries=${array[7]}! --http.timeout=${array[4]}! --logPath=None! --excludeinstance=\"Status==OK\"!|" $i
	 sed -i "s| --devicetype=CMC!.*info| --devicetype=CMC! --componentname=System! --protocol=2! --http.user=$wsman_uName! --http.password=$wsman_pwd! --http.port=${array[5]}! --http.retries=${array[7]}! --http.timeout=${array[4]}! --logPath=None! --setservicestatus=0!|" $i
     sed -i "s| --devicetype=CMC!.*--componentname=Sensors_Fan!| --devicetype=CMC! --componentname=Fan! |" $i
	 
     ##Equal related serviceStatus
     sed -i "s| --devicetype=EqualLogic!.*meminfo| --devicetype=EqualLogic! --componentname=Member! --setservicestatus=0! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None!|" $i
     sed -i "s| --devicetype=EqualLogic!.*memghs| --devicetype=EqualLogic! --componentname=Member! --primaryStatusOnly=1! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None!|" $i
     sed -i "/ --devicetype=EqualLogic!.*--componentname=PhysicalDisk!/s/$/  --excludeinstance=\"Status==online,Status==spare,Status==alt-sig,Status==replacement,Status==encrypted\"!/" $i
     sed -i "/ --devicetype=EqualLogic!.*--componentname=System!/s/$/ --setservicestatus=0!/" $i
     sed -i "/ --devicetype=EqualLogic!.*--componentname=Volume!/s/$/ --excludeinstance=\"Status==online,Status==offline,Status==available \(no new connections\)\"!/" $i
     sed -i "/ --devicetype=EqualLogic!.*--componentname=StoragePool!/s/$/ --setservicestatus=0!/" $i
     
     
     ##MD-Array related serviceStatus
     sed -i "s| --devicetype=MDArray!.*mdinfo| --devicetype=MDArray! --componentname=System! --setservicestatus=0! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None!|" $i
     sed -i "s| --devicetype=MDArray!.*mdghs| --devicetype=MDArray! --componentname=System! --primaryStatusOnly=1! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None!|" $i
     
     ##Compallent related serviceStatus
     sed -i "s| --devicetype=Compellent!.*mnginfo| --devicetype=Compellent! --componentname=System! --setservicestatus=0! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None!|" $i
     sed -i "s| --devicetype=Compellent!.*mngghs| --devicetype=Compellent! --componentname=System! --primaryStatusOnly=1! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None!|" $i
     sed -i "s| --devicetype=Compellent!.*mngvol| --devicetype=Compellent! --componentname=Volume! --excludeinstance=\"Status==OK\"! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None!|" $i
     sed -i "s| --devicetype=Compellent!.*mngpd| --devicetype=Compellent! --componentname=Disk! --excludeinstance=\"Status==OK\"! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None!|" $i
     sed -i "s| --devicetype=Compellent!.*ctlinfo| --devicetype=Compellent! --componentname=Controller! --setservicestatus=0! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None!|" $i
     sed -i "s| --devicetype=Compellent!.*ctlghs| --devicetype=Compellent! --componentname=Controller! --primaryStatusOnly=1! --protocol=1! --snmp.version=${array[3]}! --snmp.community=$snmp_comm_string!  --snmp.port=${array[6]}! --snmp.retries=${array[5]}! --snmp.timeout=${array[4]}! --logPath=None!|" $i
    log_msg "successfully Changed the check command in each service definition of $i object file\n"
fi  
done
}


rem_unwanted()
 {
 rm -f ${NAGIOS_HOME}/dell/scripts/.dell_device_comm_params.cfg
 if [ $? = 1 ];then
   printf "please remove the '${NAGIOS_HOME}/dell/scripts/.dell_device_comm_params.cfg' manually."
 fi
 rm -rf ${NAGIOS_HOME}/dell/resources 
 if [ $? = 1 ];then
   printf "please remove the '${NAGIOS_HOME}/dell/resources' directory manually."
 fi
 resource_path=${NAGIOS_HOME}/etc/nagios.cfg
 sed -i -e '/resource_file\=.*\/dell\/resources\/dell_resource.cfg/d' $resource_path
 if [ $? = 1 ];then
   printf "please comment or remove the line 'resource_file=${NAGIOS_HOME}/dell/resources/dell_resource.cfg/' in '${NAGIOS_HOME}/etc/nagios.cfg' file manually."
 fi
}

object_file_rebranding()
{
  FILE=(${NAGIOS_HOME}/dell/config/objects/*.cfg)
   if [ -f "$FILE" ]; then
     log_msg "Rebranding the Service names for all the devices."
	 sed -i 's/Dell MD Storage Array /Dell Storage MD-Series /' ${NAGIOS_HOME}/dell/config/objects/*.cfg
	 sed -i 's/Dell EqualLogic /Dell Storage PS-Series /' ${NAGIOS_HOME}/dell/config/objects/*.cfg
	 sed -i 's/Dell Compellent /Dell Storage SC-Series /' ${NAGIOS_HOME}/dell/config/objects/*.cfg
	 sed -i 's/Dell Storage PowerVault MD /Dell Storage MD-Series /' ${NAGIOS_HOME}/dell/config/objects/*.cfg
	 sed -i 's/Dell Storage Compellent /Dell Storage SC-Series /' ${NAGIOS_HOME}/dell/config/objects/*.cfg
	 sed -i 's/Dell Storage EqualLogic /Dell Storage PS-Series /' ${NAGIOS_HOME}/dell/config/objects/*.cfg
	 sed -i 's/Dell OOB Server /Dell Agent Free Server /' ${NAGIOS_HOME}/dell/config/objects/*.cfg
	 sed -i 's/Dell /Dell EMC /' ${NAGIOS_HOME}/dell/config/objects/*.cfg
   fi
}
print_installation_in_log()
{
    echo ""   >> "${LOG_FILE}"
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -  >> "${LOG_FILE}"
	printf '                                 INSTALLATION LOG\n' >> "${LOG_FILE}"
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -  >> "${LOG_FILE}"
	echo ""   >> "${LOG_FILE}"
}

warranty_info()
{
    sed -i "s/RemainingDaysWarning = [[:digit:]]\+/RemainingDaysWarning = $warranty_warningDays /" "$BASEDIR/../scripts/nagios_properties.py"

    sed -i "s/RemainingDaysCritical = [[:digit:]]\+/RemainingDaysCritical = $warranty_criticalDays /" "$BASEDIR/../scripts/nagios_properties.py"
} 
check_for_warranty()
{
if [ -f "$NAGIOS_HOME/dell/resources/dell_pluginconfig.cfg" ]; then
  while IFS="=" read -r key value line
   do
    if [ "$key" == "RemainingDaysWarning" ];
     then
        warranty_warningDays=$value      
    elif [ "$key" == "RemainingDaysCritical" ];
     then
        warranty_criticalDays=$value
    fi
   done < $NAGIOS_HOME/dell/resources/dell_pluginconfig.cfg
 fi
} 

function version_gt() 
{ 
	test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; 
}

BASEDIR=$(dirname $0)

source $BASEDIR/../scripts/dellconfig.cfg
#Creating log files
LOG_FILE="/tmp/dell_omp_$MYVERSION_nagios_core_install_`date +%Y%m%d%H%M%S`.log"
touch "${LOG_FILE}"
SUCCESS=0
FAILURE=1
ACTIONLEVEL=4
DEFAULT_HOME=$NAGIOS_HOME
DEFAULTSNMPTTINI=$SNMPTTINI
DEFAULTRACADM=$RACADM
DEFAULTJAVAINSTALLPATH=$JAVAINSTALLPATH
MULTILINE=0
SNMPTT_PRESENT=0
RACADM_PRESENT=0
JAVA_PRESENT=0
UPGRADE=0
USER_CHOICE_UPGRADE=0
DELL_OMP1_SERV_TEMP_PATH="$NAGIOS_HOME/dell/scripts/dell_server_services_template.cfg"
INSTALLEDVERSION=""
MYVERSION="3.0"
REBRANDVERSION="2.1"
warranty_warningDays=0
warranty_criticalDays=0

if [ "$#" = "1" ] && [ "$1" = "trap" ]
then 
    SNMPTT_PRESENT=2
	#if [ ! -f "$BASEDIR/../../bin/nagios" ]
	#then
		#printf "\nRun the Install script from Dell EMC Plug-in installed location.\n"
		#printf "\nExiting Installation.\n"
		#exit $FAILURE
	#else
		#if [  -f "${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver" ] 
		#then
		    #if [ "$DEFAULTSNMPTTINI" = "" ] 
		    #then
				#check_prerequisites_snmptt
			#else
			    #error_exit "SNMPTT is already installed."  "4" "Installation"
			#fi
		#else
			#error_exit "Dell EMC OpenManage Plug-in for Nagios Core is not installed. Install the Plug-in before enabling trap integration in snmptt.ini"  "4" "Installation"
		#fi
	#fi
elif [ "$#" = "1" ] && [ "$1" = "java" ]
then 
    JAVA_PRESENT=2
	#if [ ! -f "$BASEDIR/../../bin/nagios" ]
	#then
		#printf "\nRun the Install script from Dell EMC Plug-in installed location.\n"
		#printf "\nExiting Installation.\n"
		#exit $FAILURE
	#else
		#if [  -f "${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver" ] 
		#then
		    #if [ "$DEFAULTJAVAINSTALLPATH" = "" ] 
		    #then
				#check_prerequisites_java
			#else
				#JAVA_PRESENT=2
			#fi
		#else
			#error_exit "Dell EMC OpenManage Plug-in for Nagios Core is not installed. Install the Plug-in before configuring java path"  "4" "Installation"
		#fi
	#fi
elif  [ "$#" = "0" ]
then

	print_installation_in_log

	get_nagios_location

	check_prerequisites
 
	check_previous_version

	verify_licenses_prompt
 
	if [ "$USER_CHOICE_UPGRADE" = "1" ]
	then
		remove_previous_ver_dir
	fi 
        
        check_for_warranty        

	copy_files

	check_multiline_prompt

	edit_nagios_cfg
	
	if [ "$USER_CHOICE_UPGRADE" = "1" ] && [ "version_gt $REBRANDVERSION $INSTALLEDVERSION" ] && [ $REBRANDVERSION != $INSTALLEDVERSION ]
	then
	    object_file_rebranding
	fi	
	if [ "$USER_CHOICE_UPGRADE" = "1" ]
	then
		object_file_cmd_rebranding
		warranty_info
		rem_unwanted
	fi
        
else
	error_exit "Invalid arguments. Exiting Installation."  "4" "Installation"
fi


if [ "$SNMPTT_PRESENT" = "1" ]  ||  [ "$SNMPTT_PRESENT" = "2" ]
then
	edit_snmptt_ini
fi

if [ "$JAVA_PRESENT" = "1" ] ||  [ "$JAVA_PRESENT" = "2" ]
then
	configureJavaPath
fi

printf "\nSUCCESS: Dell EMC OpenManage Plug-in version v$MYVERSION is installed successfully.\n"

verify_nagios_installation_prompt

delete_backup_files

exit $SUCCESS

