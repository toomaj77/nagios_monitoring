log_msg()
{
	echo "$1" | sed -e "s/^/$(date -R) /" >> ${LOG_FILE}
}

function log_msg_print
{
	printf "$1" | sed -e "s/^/$(date -R) /" >> ${LOG_FILE}
	printf "$1"
}

remove_folders()
{
	log_msg_print "\nRemoving \"dell emc\" Plug-in specific folders and files...\n"
	#Removing folder during uninstallation
	error=`rm -rf ${NAGIOS_HOME}/dell 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		accumulate_error "\nCannot delete ${NAGIOS_HOME}/dell folder. Delete it manually"
	fi 
	error=`rm -rf ${NAGIOS_HOME}/var/dell 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		accumulate_error "Cannot delete ${NAGIOS_HOME}/var/dell folder"
	fi 
	error=`rm -rf ${NAGIOS_HOME}/share/images/logos/idrac.png 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		accumulate_error "Cannot delete ${NAGIOS_HOME}/share/images/logos/idrac.png"
	fi 
	error=`rm -rf ${NAGIOS_HOME}/share/images/logos/chassis.png 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		accumulate_error "Cannot delete ${NAGIOS_HOME}/share/images/logos/chassis.png"
	fi
	error=`rm -rf ${NAGIOS_HOME}/share/images/logos/compellent.png 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		accumulate_error "Cannot delete ${NAGIOS_HOME}/share/images/logos/compellent.png"
	fi
	error=`rm -rf ${NAGIOS_HOME}/share/images/logos/equallogic.png 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		accumulate_error "Cannot delete ${NAGIOS_HOME}/share/images/logos/equallogic.png"
	fi
	error=`rm -rf ${NAGIOS_HOME}/share/images/logos/MdArray.png 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		accumulate_error "Cannot delete ${NAGIOS_HOME}/share/images/logos/MdArray.png"
	fi
	#Removing DellKB folder during uninstallation
	error=`rm -rf ${NAGIOS_HOME}/share/DellKB 2>&1 >/dev/null`
	if [ "$?" != "0" ]; then
	    log_msg "Error:  $error"
		accumulate_error "\nCannot delete ${NAGIOS_HOME}/share/DellKB folder. Delete it manually"
	fi
	
}


remove_entries()
{
	#remove nagios.cfg entries
	log_msg_print "\nUpdating nagios.cfg...\n"
		cfg_present=`sed -n '/^cfg_dir[ \t]*=[ \t]*.*\/dell\/config/p' "${NAGIOS_HOME}/etc/nagios.cfg"`
		if [ ! "$cfg_present" = "" ]
		then
			error=`sed -i "s|^cfg_dir[ \t]*=[ \t]*.*/dell/config||g" "${NAGIOS_HOME}/etc/nagios.cfg" 2>&1 >/dev/null`
			if [ "$?" != "0" ]; then
				log_msg "Error:  $error"
				accumulate_error "Cannot update nagios.cfg for config directory entries."
			else
				printf "\nThe following entry is removed from nagios.cfg file:\n"
				echo "-------------------------------------------------------------------"
				printf "$cfg_present\n"
				echo "-------------------------------------------------------------------"		
			fi
		fi
	
		res_present=`sed -n '/^resource_file[ \t]*=[ \t]*.*\/dell\/resources\/dell_resource.cfg/p' "${NAGIOS_HOME}/etc/nagios.cfg"`
		if [ ! "$res_present" = "" ]
		then
			error=`sed -i "s|^resource_file[ \t]*=[ \t]*.*/dell/resources/dell_resource.cfg||g" "${NAGIOS_HOME}/etc/nagios.cfg" 2>&1 >/dev/null`
			if [ "$?" != "0" ]; then
				log_msg "Error:  $error"
				accumulate_error "Cannot update nagios.cfg for resource file entries."
			fi
		fi
	
	#remove snmptt.ini entries

if [ "$DEFAULTSNMPTTINI" = "" ]
then
	SNMPTTPRESENT=0
fi


 if [ "$SNMPTTPRESENT" = "1" ]
 then
	
	if [ ! -f "$SNMPTTINI" ]
	then
		accumulate_error "Cannot update snmptt.ini. File path is not valid."
		return
	else
		log_msg "snmptt.ini file path is valid : ($SNMPTTINI)"
	fi
 	log_msg_print "\nUpdating snmptt.ini...\n"		

  append=0
 				
	included_files=${NAGIOS_HOME}/dell/config/templates/*.conf
	if [ ! "`echo $included_files`" = "${NAGIOS_HOME}/dell/config/templates/*.conf" ] 
	then
		for j in $included_files 
		do
			entryExists=`grep -c $j $SNMPTTINI` 
			if [ "$entryExists" != "0" ]
			then
				error=`sed -i -e "s|$j|blank_space|g" "${SNMPTTINI}" 2>&1 >/dev/null`						
				if [ "$?" != "0" ]; 
				then
					log_msg "Error:  $error"
					if [ ! $append = "1" ]
					then
              append=1
						accumulate_error "Unable to update snmptt.ini file. "
						accumulate_error "\n\tRemove the following line in section "[TrapFiles]" of file snmptt.ini."
            accumulate_error   "\t---------------------------------------------------------------------"
				    fi
						accumulate_error "\t$j"
				else
					present=`sed -n '/blank_space/p' "${SNMPTTINI}"`
					if [ ! present = "" ]
					then							
						error=`sed -i  '/^snmptt_conf_files = <<END/,/^END/{ /^[ \t]*blank_space[ \t]*$/d}' "${SNMPTTINI}" 2>&1 >/dev/null`
						if [ "$?" != "0" ]; 
						then
							log_msg "Error:  $error"
							if [ ! "$append" = "1" ]
							then
								append=1
								accumulate_error "Unable to update snmptt.ini file. "
								accumulate_error "\n\tRemove the following line in section "[TrapFiles]" of file snmptt.ini."
                                accumulate_error   "\t---------------------------------------------------------------------"
							fi
							
							accumulate_error "\t$j"
							
						fi
						if [ ! "$append_no_error" = "1" ]
						then
							append_no_error=1
							printf "\nThe following entry is removed from snmptt.ini file:\n"
							echo "-------------------------------------------------------------------"
						fi
						printf "$j\n"
					fi 
				fi
			fi
		done 
		if [ "$append_no_error" = "1" ]
		then
			echo "-------------------------------------------------------------------"
		fi
		if [  "$append" = "1" ]
		then
                accumulate_error   "\t---------------------------------------------------------------------"
		fi
							
						
	fi
fi
}

verify_nagios_installation_prompt()
{
    
	printf "\nFor the Dell EMC OpenManage Plug-in removal to take effect, ";
	if [ "$SNMPTTPRESENT" = "1" ]
	then 
		printf "verify the Nagios and SNMPTT configuration entries as per product guidelines and then restart the Nagios and SNMPTT services.\n\n"
	else
		printf "verify the Nagios configuration entries as per product guidelines and then restart the Nagios service.\n\n"
	fi
}



accumulate_error()
{
    log_msg "$1"
	error_array[$error_count]=$1
	error_count=$((error_count+1))
}

display_errors()
{
    if [ ! "$error_count" = "0" ]
    then 
		printf "\nFAILURE: The following errors occurred during removal.\n"
		echo "--------------------------------------------------------"
		for i in "${error_array[@]}" 
		do 
			printf "$i\n"
		done 
		echo "--------------------------------------------------------"
		printf "Perform these removal steps manually.\n"
	else
		    printf "\nSUCCESS: Dell EMC OpenManage Plug-in version v$MYVERSION for Nagios Core is removed successfully.\n"
	        verify_nagios_installation_prompt
	fi
}

print_uninstallation_in_log()
{
    echo ""   >> "${LOG_FILE}"
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -  >> "${LOG_FILE}"
	printf '                                 UNINSTALLATION LOG\n' >> "${LOG_FILE}"
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -  >> "${LOG_FILE}"
	echo ""   >> "${LOG_FILE}"
}

BASEDIR=$(dirname $0)

source $BASEDIR/../scripts/dellconfig.cfg
#Creating log files
LOG_FILE="/tmp/dell_omp_$MYVERSION_nagios_core_uninstall_`date +%Y%m%d%H%M%S`.log"
touch "${LOG_FILE}"




SUCCESS=0
FAILURE=1
ACTIONLEVEL=4
DEFAULT_HOME=$NAGIOS_HOME
DEFAULTSNMPTTINI=$SNMPTTINI
SNMPTTPRESENT=1
MYVERSION="3.0"
print_uninstallation_in_log
if [ ! -f "$BASEDIR/../../bin/nagios" ]
then
	printf "\nRun the uninstall script from Dell EMC OpenManage Plug-in installed location.\n"
	printf "\nExiting uninstallation.\n"
	exit $FAILURE
fi
while true; do
printf "\nPress 'Y' to continue with uninstallation (default: 'N'):  "
read -e -n 1 option
case $option in
	[Yy]* )
	
		while true; do
		printf "\nThis will remove all \"dell emc\" Plug-in specific folders and files from your system.\nPress 'Y' to continue (default: 'N'):"
		read -e -n 1 option
		case $option in
			[Yy]* )
				error_count=0
				if [ ! -f "${NAGIOS_HOME}/dell/.dell_omp_nagios_core_ver" ] 
				then
					printf "\nDell EMC OpenManage Plug-in not installed or not found in $NAGIOS_HOME. Exiting...\n"    
					exit $FAILURE
				fi
				remove_entries
				
				remove_folders
				
				display_errors
				
				exit $SUCCESS

				break
				;;
			[Nn]*|"" )
	    
				uninstall="N"
				printf "\nExiting uninstallation.\n"
				log_msg "Choice for uninstallation: $uninstall. Exiting..."
				exit $SUCCESS		
				;;
			* ) 
				printf "\nInvalid Command. Press 'Y' or 'N'.\n"
				;;
				esac	
        done				
	   ;;
	[Nn]*|"" )	    
	    uninstall="N"
		printf "\nExiting uninstallation.\n"
		log_msg "Choice for uninstallation: $uninstall. Exiting..."
		exit $SUCCESS		
		;;
	* ) 
		printf "\nInvalid Command. Press 'Y' or 'N'.\n"
		;;
		esac
done

	
