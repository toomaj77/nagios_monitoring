#!/bin/sh
# satool.sh   --mikeH
#  Checks mounts vs. /etc/(v)fstab file. Does not cleanly detect autofs home
#  dirs or ZFS mounted filesystems.  Solaris 8 is a little weird as it uses a
#  different diff command. '-' means a mount is defined in the (v)fstab file
#  but is not mounted.  '+' means a directory is mounted but not in the
#  (v)fstab file.  Solaris 8 uses '<' as '-' and '>' in place of '+'.
#  ZFS is not in the /etc/vfstab file
#  A dozen other tools related to patching are now included.

#set -x   #uncomment for complete absolute debug
DEBUG=0   #set to 1 to turn on debug or set -debug/+debug
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/ucb:/usr/sfw/bin
export PATH
VERSION="SAtool.sh v5.18.1 (r.2021/05/12)"
SCRIPTNAME="satool.sh"
umask 022
PREPDIR="/root/prepatch"
RVAL=0
DOIT="0"  #exec flag  for -/+ flags
OSCHK=""
SUFF="prepatch"
VERBOSE=0
unset no_proxy
unset http_proxy
unset HTTP_PROXY
unset https_proxy
unset HTTPS_PROXY

#Debug mode? - last arg
eval LARG=\${$#}
if [ "$LARG" = "-debug" ]; then
	echo "::DEBUG MODE::"
	DEBUG=1
fi

if [ "$LARG" = "+debug" ]; then
	echo "::VERBOSE DEBUG MODE::"
	DEBUG=1
	set -x
fi

#process any additional args to pass to yum/apt/dnf
EXTARGS=""
if [ "$2" != "-debug" -a "$2" != "+debug" ]; then
	EXTARGS="$2"
fi
if [ "$3" != "-debug" -a "$3" != "+debug" ]; then
	EXTARGS="$EXTARGS $3"
fi
if [ "$4" != "-debug" -a "$4" != "+debug" ]; then
	EXTARGS="$EXTARGS $4"
fi
if [ "$5" != "-debug" -a "$5" != "+debug" ]; then
	EXTARGS="$EXTARGS $5"
fi
if [ "$6" != "-debug" -a "$6" != "+debug" ]; then
	EXTARGS="$EXTARGS $6"
fi
ARG_1=`echo $EXTARGS | awk '{print$1}'`
ARG_0=$0

OSVER=`uname -s`
if [ "$OSVER" != "Linux" -a "$OSVER" != "SunOS" ]; then
	echo "Unknown OS: $OSVER"
	exit 1
fi

if [ "$OSVER" = "Linux" ]; then #Linux
        FTAB="/etc/fstab"
        FTYPE="fstab"
        VARSIZE=491520 #480MB
	BOOTSIZE=56
        VARSTR="480 MB"
	DFLAG="-u"
	ECF="-e"
	OST="LINUX"
	if [ -f /etc/redhat-release -a -f /etc/system-release ]; then 
		#RH/Centos/Fedora
		UUU=`grep " 5." /etc/redhat-release `
		if [ "$UUU" != "" ]; then
			OSV="5"
		fi
		UUU=`grep " 6." /etc/system-release `
		if [ "$UUU" != "" ]; then
			OSV="6"
		fi
		UUU=`grep " 7." /etc/system-release `
		if [ "$UUU" != "" ]; then
			OSV="7"
		fi
		UUU=`grep " 8." /etc/system-release `
		if [ "$UUU" != "" ]; then
			OSV="8"
		fi
	else  #Ubuntu
		if [ -f /etc/os-release ]; then
			OSV=`grep VERSION_ID /etc/os-release | awk -F"=\"" '{print$2}' | awk -F'"' '{print$1}'`
			OSV="u$OSV"
			ECF=""  #/bin/sh is slightly different on ubuntu
		fi
	fi
else  #SunOS?
	if [ "$OSVER" = "SunOS" ]; then #Sun
        	VARSIZE=1048576  #1GB
        	VARSTR="1 GB"
        	FTYPE="vfstab"
        	FTAB="/etc/vfstab"  #Solaris
        	if [ "`uname -r`" = "5.8" ]; then
               		DFLAG="-w"
		 else
			DFLAG="-u"
        	fi
		OST="SUN"
		OSV=`uname -r`
		ECF=""
	fi
fi

SYSGRP=`getent group sysadmin`
if [ "$SYSGRP" = "" ]; then
	SYSGRP="root"
 else
	SYSGRP="sysadmin"
fi

YUM=""
if [ ! -x /bin/yum -o -x /usr/bin/yum ]; then
	YUM="yum"
 else
	if [ ! -x /usr/bin/dnf ]; then
		YUM="dnf"
	fi
fi

################################################################
#Put functions here VVV that do not require PREPDIR prep work: #
################################################################

preboot_check () { #-preboot/+preboot
	if [ "$OST" = "SUN" ]; then
                return 0
        fi
	if [ "$OSV" = "u20.04" -o "$OSV" = "u18.04" ]; then
		preboot=`apt-get dist-upgrade --dry-run | grep 'Inst linux-' >/dev/null && echo "REBOOT"`
		if [ "$preboot" != "" ]; then 
			echo ":::SERVER APPEARS TO NEED A REBOOT ONCE PATCHED:::"
			return 1
		fi
		return 0
	fi
	UU=`$YUM list updates | egrep '^kernel|^glibc|^linux-firmware|^systemd|udev|^dbus'`
	if [ "$UU" != "" ]; then
		if [ "$DOIT" = "1" ]; then
			echo "$UU"
		fi
		echo ":::SERVER APPEARS TO NEED A REBOOT ONCE PATCHED:::"
		return 1
	fi
	return 0
}  #end of preboot_check()

follow_symlinks () {  # -links
	TMPY=`echo $EXTARGS | rev | cut -c1`
	if [ "$TMPY" = "/" ]; then
		NPATH=`echo $EXTARGS | rev | cut -c2- | rev`  #cut ending /
	 else
		NPATH=$EXTARGS
	fi
	if [ ! -h $NPATH ]; then
		echo "Not a link"
		return 0
	fi
	SAL=1  #Still A Link
	#check if absolute path
	FL=`echo $NPATH | cut -c1`
	if [ "$FL" = "/" ]; then  #starts with absolute path
		BASEPATH=`echo $NPATH |rev | cut -f2- -d / | rev`
	 else  #assume from current directory
		BASEPATH=$PWD
	fi
	echo "    $NPATH"
	while [ $SAL = 1 ]; do
		LF=`/bin/ls -ld $NPATH | awk '{print$NF}'`
		FL=`echo $LF | cut -c1`  #pull link only
		if [ "$FL" = "/" ]; then
			NPATH=$LF
		 else
			BASEPATH=`echo $NPATH |rev | cut -f2- -d / | rev`
			NPATH="$BASEPATH/$LF"
		fi
		TMPY=`echo $NPATH | rev | cut -c1`
		if [ "$TMPY" = "/" ]; then
			NPATH=`echo $NPATH |rev | cut -c2- | rev`
		fi
		if [ -h $NPATH ]; then
			SAL=1
		 else
			SAL=0
		fi
		echo "--> $NPATH"
	done
	if [ ! -e $NPATH ]; then
		echo "--> (BROKEN LINK)"
	fi
	return 0
}  #end of follow_symlinks

check_pidexe () {  # -pexe
	if [ "$OST" = "SUN" ]; then
		return 0
	fi
	if [ "$EXTARGS" = "" ]; then
        	echo "$0 -pexe PID"
        	return 1
	fi

	if [ -d /proc/$EXTARGS ]; then
		cd /proc/$EXTARGS
		EXTARGS=`echo $EXTARGS | awk '{print$1}'` #strip space
        	ls -ld exe | awk -F"->" '{print"EXE: "$NF}'
		ls -lad . | awk '{print"UID/GID:  "$3":"$4}'
		ls -ld cwd | awk -F"->" '{print"CWD: "$NF}'
		#PP=`ps -ef |grep -v grep | grep -v ps | grep -v awk |awk '{print$2","$3","$NF}' | grep ^$EXTARGS | awk -F',' '{print$2}'`
		PP=`grep -i ^PPID status |awk '{print$2}'`
		#UUU=`ps -e | awk '{print$1","$4}' |grep "^$PP," | awk -F',' '{print$NF}'`
		UUU=`/bin/ls -l /proc/$PP/exe | awk '{print$NF}' | awk -F/ '{print$NF}'`
		echo "PPID: $PP, ($UUU)"
		PP=`ls /proc/$EXTARGS/task | wc -l`
		echo "Threads: $PP"
	 else
		echo "No such PID or cannot read"
	fi
	return 0
}  #end of check_pidexe

fixepoch () {  # -epoch
	if [ "$ARG_1" = "" ]; then
		echo "Invalid date"
		return 1
	fi
	date --date="@$ARG_1"
	return $?
}  #end of fixepoch

clean_dns () {  #fix DNS settings in ifcfg-* files, -dns/+dns
	if [ "$OST" = "SUN" ]; then
		return 0
	fi
	RV=0
	for i in /etc/sysconfig/network-scripts/ifcfg-*; do
		egrep -i 'DNS1|DNS2|DOMAIN' $i
		if [ $? = 0 ]; then
			RV=1
			if [ "$DOIT" = "1" ]; then
				cp $i /root/
				egrep -iv 'NM_CONTROLLED|PEERDNS|DNS1|DNS2|DOMAIN' $i > ${i}_new
				echo 'NM_CONTROLLED="no"' >> ${i}_new
				echo 'PEERDNS="no"' >> ${i}_new
				mv ${i}_new $i
				echo "DNS settings found in $i (fixed)"
	 		 else
				echo "DNS settings found in $i"
			fi
		fi
	done
	UUU=`ps -ef | grep -i NetworkManager | grep -v grep`
	if [ "$UUU" != "" ]; then 
		echo "Network Manager running - please stop and disable"
		echo "$UUU"
		RV=1
	fi
	return $RV
}  #end of clean_dns

check_resolv () {  #check /etc/resolv.conf  -resolv
	RV=0
	#check that we have a search field
	UU=`grep "^search " /etc/resolv.conf`
	if [ "$UU" = "" ]; then
		echo "WARNING: no search field (continuing)"
		RV=1
	else #check search field count
        	UU=`grep "^search " /etc/resolv.conf | wc -w`
        	if [ "$UU" -gt "7" -a "$DOIT" = "1" ]; then
                	echo "WARNING: too many domains in search field (continuing)"
		fi
        fi
	#check if we have any nameservrs
	UU=`grep "^nameserver " /etc/resolv.conf`
	if [ "$UU" = "" ]; then
		echo "No defined nameservers in /etc/resolv.conf"
		return 1
	fi
	#check that we have at least two
	UU=`grep -c "^nameserver " /etc/resolv.conf`
	if [ "$UU" = "1" ]; then
		DN1=`grep "^nameserver " /etc/resolv.conf | awk '{print$2}'`
		echo "Only 1 nameserver in /etc/resolv.conf ($DN1)"
		return 1
	fi
	DN1=`grep "^nameserver " /etc/resolv.conf | head -1 | awk '{print$2}'`
	DN2=`grep "^nameserver " /etc/resolv.conf | head -2 | tail -1 | awk '{print$2}'`
	#check nameservers for reachability
	if [ -x /bin/dig -o -x /usr/bin/dig ]; then
		dig alalpans001.risk.regn.net @$DN1 > /dev/null
		if [ $? -ne 0 ]; then
			echo "$DN1 does not appear to be working"
			RV=1
		fi
		dig alalpans001.risk.regn.net @$DN2 > /dev/null
		if [ $? -ne 0 ]; then
			echo "$DN2 does not appear to be working"
			RV=1
		fi
	fi
	return $RV
} #end of check_resolv()

compare_resolv () {  #-/+cmpresolv
	if [ ! -f $PREPDIR/resolv.$SUFF ]; then
		echo "No resolv.$SUFF available"
		return 1
	fi
	UU=`cmp $PREPDIR/resolv.$SUFF /etc/resolv.conf`
	RV=$?
	if [ "$UU" != "" ]; then
		echo "$UU"
		return $RV
	fi
	return 0
}  #end of compare_resolv()

show_networks () {  #-shownet
	if [ "$OST" != "SUN" ]; then
		INF=`netstat -rn | grep "^0.0.0.0" | awk '{print$8}'`
		GW=`netstat -rn | grep "^0.0.0.0" | awk '{print$2}'`
		UU=`netstat -rn | grep $INF | grep "0.0.0.0" | awk '{print$1,$3}' | egrep -v '^0.0.0.0|169.254.0.0'`
		UUU=`ip addr | grep "inet " | grep $INF | egrep -v '127.0.0' | head -1 | awk '{print$2}' | awk -F'/' '{print$2}'`
		NT=`echo $UU | awk '{print$1}'`
		NM=`echo $UU | awk '{print$2}'`
		echo "NET:${NT}/$UUU  NM:$NM  GW:$GW"
	fi
	return 0
}  #end of show_networks()


decomm () { #decomm tests -deccomm
	#OS+HW
	echo "-------------------------------------------"
	echo "OS version + HW:"
	if [ -f /etc/redhat-release ]; then
		cat /etc/redhat-release
	fi
	/usr/local/bin/satool.sh -hw
	echo
	#load
	echo "-------------------------------------------"
	echo "LOAD:"
	uptime
	echo
	#top output
	echo "TOP:"
	top -bn 1 | head -20
	echo
	#network activity
	echo "-------------------------------------------"
	echo "NETWORK ACTIVITY: (10 second sleep)"
	echo "IF    RCV       TX"
	UU=`egrep ' 6.| 5.' /etc/redhat-release`
	if [ "$UU" != "" ]; then
        	NETCK1=`netstat -in | egrep '^em|^eth' | awk '{print$1," ",$4," ",$8}'`
        	sleep 10
        	NETCK2=`netstat -in | egrep '^em|^eth' | awk '{print$1," ",$4," ",$8}'`
	else
        	NETCK1=`netstat -in | egrep '^em|^eth' | awk '{print$1," ",$3," ",$7}'`
        	sleep 10
        	NETCK2=`netstat -in | egrep '^em|^eth' | awk '{print$1," ",$3," ",$7}'`
	fi
	echo "$NETCK1"
	echo "$NETCK2"
	echo
	sleep 3
	#listening ports:
	UU=`netstat -anp | grep LISTEN | grep -v unix | egrep -v ':22|:25|:111|:199|:5666|statd|2049' | awk '{print$4,"  ",$6,"  ",$7}'`
	if [ "$UU" != "" ]; then
        	echo "-------------------------------------------"
        	echo "Listening ports:"
        	netstat -anp | grep LISTEN | grep -v unix | egrep -v ':22|:25|:111|:199|:5666|statd|rpc' | awk '{print$4,"  ",$6,"  ",$7}'
        	echo
	fi
	#not root processes
	UU=`ps -ef | egrep -v 'PPID|root|centos|postfix|smmsp|nrpe|polkitd|ntp|rpc|dbus|apache|ossec|hald'`
	if [ "$UU" != "" ]; then
        	echo "-------------------------------------------"
        	echo "NON-root processes:"
        	ps -ef | egrep -v 'root|centos|postfix|smmsp|nrpe|polkitd|ntp|rpc|dbus|apache|ossec|hald'
        	echo
	fi
	#last logins
	echo "-------------------------------------------"
	echo "Last logins: (excluding centos/root)"
	last -F | egrep -v 'wtmp|root|centos|monitoring|svc-cdb_collect|svc_qual|reboot' | head -20
	echo
	#/home directory
	echo "-------------------------------------------"
	echo "HOME directory accounts:"
	ls -l /home | egrep -v 'centos|lost+found|svc-cdb_collect|svc_qualys|monitoring'
	echo
	#SAN
	UU=`/usr/local/bin/satool.sh -disks | grep ^Disk`
	if [ "$UU" != "" ]; then
        	echo "-------------------------------------------"
        	echo "Storage: (any SAN?)"
        	/usr/local/bin/satool.sh -disks
        	echo
	fi
	#DB?/Web
	UU=`ps -ef | grep apache | grep -v grep | tail -5`
	UUU=`/usr/local/bin/satool.sh -db`
	if [ "$UU" != "" -o "$UUU" != "" ]; then
        	#DB?/Web
        	echo "DB/Web?"
        	echo "-------------------------------------------"
        	ps -ef | grep apache | grep -v grep | tail -5
        	/usr/local/bin/satool.sh -db
        	echo
	fi
	#Virtual machine?
	UU=`/usr/local/bin/satool.sh -zones`
	if [ "$UU" != "" ]; then
        	echo "-------------------------------------------"
        	echo "VM or Hypervisor:"
        	/usr/local/bin/satool.sh -zones
        	echo
	fi
	#App mounts
	UU=`df -h  | egrep '/app$|/ap$|/u$|/db$|/data$' | grep -v tempfs`
	UUU=`ls -l / | egrep ' ap$| u$| db$| data$'`
	if [ "$UU" != "" -o "$UUU" != "" ]; then
        	echo "-------------------------------------------"
        	echo "Data mount points:"
        	df -h | head -1
        	df -h  | egrep '/app$|/ap$|/u$|/db$|/data$' | grep -v tempfs
        	ls -l / | egrep ' ap$| u$| db$| data$'
        	echo
	fi
	#other mounts
	UU=`df -h | egrep -v 'Filesystem|devfs|tmpfs|/var|/boot|/home|/usr|/dev'`
	if [ "$UU" != "" ]; then
        	echo "-------------------------------------------"
        	echo "Base or any other mounts:"
        	df -h | egrep -v 'devfs|tmpfs|/var|/boot|/home|/usr|/dev'
        	echo
	fi
	#Clusters?
	UU=`/usr/local/bin/satool.sh -clusterfs`
	if [ "$UU" != "" ]; then
        	echo "-------------------------------------------"
        	echo "Any Cluster FSes:"
        	/usr/local/bin/satool.sh -clusterfs
        	echo
	fi
	#special processes
	UU=`ps -ef | egrep -v 'tuned|grep' | egrep 'java|named|python'`
	if [ "$UU" != "" ]; then
        	echo "-------------------------------------------"
        	echo "Specific processes:"
        	ps -ef | egrep -v 'tuned|grep' | egrep 'java|named|python'
        	echo
	fi
	return 0
} #end of decomm()

checkosv () { #check OS type and version, -os
	if [ -f /etc/system-release ]; then #C6/7/8,RH6/7/8
		cat /etc/system-release
		return 1
	fi
	if [ -f /etc/redhat-release ]; then #C5,RH5
		cat /etc/redhat-release
		return 1
	fi
	UU=`uname -s`
	if [ "$UU" = "SunOS" ]; then  #Solaris
		UUU=`uname -r`
		if [ -x /usr/bin/zonename ]; then
			UUUU=`/usr/bin/zonename`
			if [ "$UUUU" != "global" ]; then
				UUUU="(zone)"
			 else
				UUUU="(physical)"
			fi
		else
			UUUU="(physical)"
		fi
		echo "$UU $UUU $UUUU"
		return 1
	fi
	if [ -f /etc/os-release ]; then
		UU=`grep PRETTY_NAME /etc/os-release | awk -F'="' '{print$2}' | awk -F'"' '{print$1}'`
		echo $UU
		return 1
	fi
	#non-standard at this point, print generic
	uname -srv
	return 1
} #end of checkosv


checkos () {  #check matching OS type: -oss/-osl/-os5/-os6/-os7/-os8/-osn
	#check for unknown OS
	if [ "$OST" != "LINUX" -a "$OST" != "SUN" ]; then #unknown OS
		if [ "$OSCHK" = "non" ]; then
			UUS=`uname -s`
			UUR=`uname -r`
			UUV=`uname -v`
			echo "$UUS $UUR ($UUV)"
			return 1  #non-matching Linux/Solaris
		fi
		return 0  #unknown
	fi
	#check for sun only
	if [ "$OSCHK" = "sun" ]; then
		NM=`uname -n`
		OV=`uname -r`
		if [ "$OST" = "SUN" ]; then
			if [ "$OV" != "5.10" -a "$OV" != "5.11" ]; then
				return 0  #not Solaris 10/11
			fi
			if [ -x /sbin/zonename ]; then
				if [ -f $PREPDIR/zonepatch.override ]; then
					echo "$NM ($OV) - zone (override)"
					return 1
				fi
				UUU=`zonename`
				if [ "$UUU" != "global" ]; then
					return 0  #a zone
				fi
			fi
			echo "$NM ($OV)"
			return 1
		 else #non-sun
			return 0
		fi
	fi
	#check if SunOS and not "sun"
	if [ "$OST" = "SUN" ]; then
		#if here and we're sun
		if [ "$OSCHK" = "non" ]; then
			ZZ=""
			if [ -x /sbin/zonename ]; then
				ZZ=`zonename`
				if [ "$ZZ" != "global" ]; then
					ZZ="[zone]"
				fi
			fi
			OV=`uname -r`
			if [ "$OV" != 5.10 -o "$ZZ" = "[zone]" ]; then
				NM=`uname -n`
				echo "$NM (SunOS $OV) $ZZ"
				return 1 #zoned and/or not 5.10
			fi
		fi
		return 0  #we're valid or not Linux
	fi
	#only Linux hosts can be here at this point
	if [ "$OSCHK" = "lin" ]; then
		if [ ! -f /etc/redhat-release -a ! -f /etc/os-release ]; then
			return 0
		fi
		#Redhat/CentOS 5 doesn't have system-release
		if [ -f /etc/redhat-release ]; then
			VERS=`cat /etc/redhat-release | awk -F"release" '{print$2}' | awk -F'(' '{print$1}' | awk '{print$1}' | awk -F. '{print$1}'`
			if [ "$VERS" = "5" -o "$VERS" = "6" -o "$VERS" = "7" -o "$VERS" = "8" ]; then
				cat /etc/redhat-release
				return 1
			fi
			return 0
		fi
		if [ -f /etc/os-release ]; then
			V2=`grep ^VERSION= /etc/os-release | awk -F"=\"" '{print$2}' | awk -F'"' '{print$1}'`
			echo "Ubuntu $V2"
			return 1
		fi
		return 0
	fi
	
	#check for individual host types
	#Redhat/Centos/Fedora
	if [ -f /etc/redhat-release -o -f /etc/system-release ]; then 
	   VERS=`cat /etc/redhat-release | awk -F"release" '{print$2}' | awk -F'(' '{print$1}' | awk '{print$1}' | awk -F. '{print$1}'`
	   if [ "$OSCHK" != "non" ]; then
		if [ "$OSCHK" = "lin5" -a "$VERS" = "5" ]; then
			cat /etc/redhat-release
			return 1
		fi
		if [ "$OSCHK" = "lin6" -a "$VERS" = "6" ]; then
			cat /etc/system-release
			return 1
		fi
		if [ "$OSCHK" = "lin7" -a "$VERS" = "7" ]; then
			cat /etc/system-release
			return 1
		fi
		if [ "$OSCHK" = "lin8" -a "$VERS" = "8" ]; then
			cat /etc/system-release
			return 1
		fi
		return 0  #if still here, no match
	   fi
	fi #end if /etc/system-release
	#if still here, we're Linux and "non", check for 5/6/7
	if [ "$VERS" = "5" -o "$VERS" = "6" -o "$VERS" = "7" ]; then
		return 0  #exclude 5/6/7/8
	fi
	if [ "$OSCHK" = "non" ]; then  #probably ubuntu
		if [ -f /etc/system-release ]; then
			cat /etc/system-release
		 else
			UUS=`uname -s`
			UUR=`uname -r`
			UUV=`uname -v`
			echo "$UUS $UUR ($UUV)"
		fi
		return 1  #non-matching Linux
	fi
	return 0
}  #end of checkos

checkrepos () {  #check for LN repo files: -lnrepos
	if [ "$OST" = "SUN" ]; then
		if [ ! -d /var/tmp/10_Recommended ]; then
			echo "/var/tmp/10_Recommended missing"
			return 1
		fi
		head -4 /var/tmp/10_Recommended/10_*Recommended.README | tail -1
		return 0
	fi
	YDIR="/etc/yum.repos.d"
	if [ ! -f /etc/system-release ]; then
		return 0
	fi
	OSST=`head -1 /etc/system-release`
	RV=0
	if [ -d $YDIR ]; then
		if [ ! -f $YDIR/LexisNexis-Frozen.repo ]; then
			#Frozen should not exist on actual RHEL boxes
			if [ -f /etc/system-release ]; then
				REL="/etc/system-release"
			else
				REL="/etc/redhat-release"
			fi
			UU=`grep -v CentOS $REL`
			if [ "$UU" = "" ]; then
				echo "Missing $YDIR/LexisNexis-Frozen.repo [$OSST]"
				RV=1
			fi
		fi
		if [ ! -f $YDIR/LexisNexis.repo ]; then
			echo "Missing $YDIR/LexisNexis.repo [$OSST]"
			RV=1
		fi
	 else
		echo "No $YDIR found"
		return 1
	fi
	return $RV
}  #end of checkrepos

checkzones () {  #check for the presence of Solaris zones: -zones/-nozones
	if [ "$OST" != "SUN" ]; then
		#For Linux, we list the VMs
		if [ ! -x /usr/bin/virsh ]; then
			if [ "$NOZ" = "1" ]; then
				uname -n
				return 1
			fi
			return 0  #no virtualization installed
		fi
		if [ ! -e /var/run/libvirt/libvirt-sock ]; then
			if [ "$NOZ" = "1" ]; then
				uname -n
				return 1
			fi
			return 0  #no hypervisor running
		fi
		UU=`ps -ef | egrep 'libvirtd' | grep -v egrep` #omit xen for now
		if [ "$UU" = "" ]; then
			if [ "$NOZ" = "1" ]; then
				uname -n
				return 1
			fi
			return 0  #no hypervisor running
		fi
		virsh list > /dev/null 2>&1
		if [ $? != 0 ]; then
			echo "failed to connect to running libvirtd server, aborting..."
			return 1
		fi
		RZS=`virsh list --all | tail -n +3 | egrep 'running|idle|dying' | wc -l`
		TZS=`virsh list --all | tail -n +3 | egrep 'running|shutdown|idle|shut off|crashed|dying' | awk '{print$2,"(",$3,")"}' | wc -l`
		if [ "$TZS" = "0" ]; then
			if [ "$NOZ" = "1" ]; then
				uname -n
				return 1
			fi
			return 0
		fi
		if [ "$NOZ" = "1" ]; then
			return 0  #doesn't match -nozones
		fi
		echo "$TZS VM(s) found, $RZS VM(s) running:"
		virsh list --all | tail -n +3 | egrep 'running|shutdown|idle|shut off|crashed|dying' | awk '{print$2,"(",$3$4,")"}'
		return 1
	fi
	#only Suns at this point
	if [ ! -x /usr/sbin/zoneadm ]; then
		if [ "$NOZ" = "1" ]; then
			uname -n
		fi
		return 0
	fi
	ZNM=`/sbin/zonename`
	ZTOT=`/usr/sbin/zoneadm list -cv | grep -v NAME | grep -v global | grep -v $ZNM`
	if [ "$ZTOT" != "" ]; then  #zones found
		ZCS=`/usr/sbin/zoneadm list -cv | grep -v NAME | grep -v global | grep -v $ZNM | wc -l | awk '{print$1}'`
		if [ "$NOZ" = "0" ]; then
			RZS=`/usr/sbin/zoneadm list -cv | grep -v NAME | grep -v global | grep -v $ZNM | grep running | wc -l | awk '{print$1}'`
			echo "$ZCS zones found ($RZS running)"
			return 1
		fi
		return 0	
	else  #no zones found
		if [ "$NOZ" = "1" ]; then
			uname -n
			return 1
		fi
	fi
	return 0
}  #end of checkzones

checkdup () {   # This is very timing specific and has issues
		# working under large lists in Radssh which does
		# not seem to issue commands to all hosts at the
		# same time.: -dup
	NAME=`uname -n`
	L1="/tmp/satool.lck1"
	L2="/tmp/satool.lck2"
	touch /tmp/satool.$$
	if [ -f $L1 ]; then
		echo "Duplicate Found ($NAME)"
		if [ -f $L2 ]; then
			echo "Double Duplicate ($NAME)"
			sleep 3
			rm -f $L2 $L1 /tmp/satool.$$
			exit -1
		fi
		echo $$ > $L2
		sleep 5
		rm -f $L2 $L1 /tmp/satool.$$
		exit -1
	fi
	#No dups detected YET!
	echo $$ > $L1
	sleep 1
	CPID=`cat $L1`
	if [ ${CPID} != $$ ]; then
		echo "Duplicate Found ($NAME)"
		echo $$ > $L2
		sleep 3
		rm -f $L2 $L1 /tmp/satool.$$
		exit -1
	else
		sleep 1
		if [ -f $L2 ]; then
			echo "Duplicate Found ($NAME)"
			sleep 2
			rm -f $L2 $L1 /tmp/satool.$$
			exit -1
		fi
		sleep 1
	fi
	if [ ! -f $L1 ]; then
		echo "Duplicate Found ($NAME)"
		rm /tmp/satool.$$
		exit -1
	fi
	sleep 1
	rm -f $L1 /tmp/satool.$$
	exit 0
}  #end of checkdup

check_astr () {  #check for Asterisk VOIP software: -astr
	if [ "$OST" = "SUN" -o -f /etc/os-release ]; then
                return 0
        fi
	ASTFD=""
	UU=`rpm -qa | grep -i asterisk`
	if [ "$UU" != "" ]; then
		ASTFD="asterisk installed, "
	fi
	R1=`rpm -qa | grep -i '^dahdi-'`
	if [ "$R1" != "" ]; then
        	R1=`lsmod | grep dahdi`
        	if [ "$R1" != "" ]; then
                	R1="(in use)"
        	fi
        	DAH="Dahdi VOIP module found $R1"
	fi
	if [ "$ASTFD" != "" ]; then
		echo "$ASTFD  $DAH"
		return 1
	fi
	return 0
}  #end of check_astr

checkvcs () {  #check for Veritas Clustering: +/-vcs, -clusterfs any clusters
	if [ "$DOIT" = "0" ]; then  #-vcs
           UU=`ps -ef | grep VRTSvcs | grep -v grep`
           if [ "$UU" != "" ]; then
		RETV=1
                echo "Veritas Cluster Service (VRTSvcs) found running"
           fi
           if [ -d /etc/admin/startup ]; then
		RETV=1
                echo "Veritas Cluster Admin directory found in /etc/admin/startup"
           fi
	fi
	if [ "$DOIT" = "1" ]; then #show any Veritas #+vcs
	UU=`ps -ef | grep VRT | grep -v grep`
	   if [ "$UU" != "" ]; then
		RETV=1
		echo "Veritas volume/FS services found running"
	   fi
	fi
	if [ "$DOIT" = "2" ]; then  #-clusterfs
		UU=`mount -v | grep gluster`
		if [ "$UU" != "" ]; then
			RETV=1
			echo "glusterfs found"
		fi
		UU=`mount -v | grep gfs2`
		if [ "$UU" != "" ]; then
			RETV=1
			echo "gfs2 found"
		fi
		UU=`mount -v | grep drbd`
		if [ "$UU" != "" ]; then
			RETV=1
			echo "drbd found"
		fi
	fi
        return $RETV
}  #end of checkvcs

check_pacemaker () {  #-pacem, check for pacemaker clustering
	UU=`ps -ef | egrep 'pacemaker|pcsd' | grep -v grep`
	if [ "$UU" != "" ]; then
		UN=`uname -n | awk -F. '{print$1}'`
		UUU=`pcs status | grep "Started $UN" | grep -v fencing | wc -l`
		if [ "$UUU" != "0" ]; then
			UTXT="(possible primary)"
		else
			UTXT=""
		fi
		echo "Pacemaker found running $UTXT"
		return 1
	fi
	return 0
}  #end of check_pacemaker
		
verlock () {  #check and/or remove yum versioning locks: -verlock/+verlock
	if [ ! -f /etc/yum/pluginconf.d/versionlock.list ]; then
		return 0  #not there just return
	fi
	UU=`cat /etc/yum/pluginconf.d/versionlock.list`
	if [ "$UU" = "" ]; then
		return 0  #empty, nothing to do
	fi
	echo "Found:"
	cat /etc/yum/pluginconf.d/versionlock.list
	if [ "$DOIT" = "1" ]; then
		echo "Clearing versionlock.list"
		cat /dev/null > /etc/yum/pluginconf.d/versionlock.list
	fi
	return 1
}  #end of verlock

checktzdata () {  #check timezone configuration: -tzdata
	RV=0
	if [ "$OST" = "SUN" ]; then
		return 0
	fi
        if [ ! -f /etc/sysconfig/clock ]; then
                return $RV  #probably CentOS7/8
        fi
        if [ ! -f /etc/localtime ]; then
                echo "/etc/localtime missing"
                return 1  #not good for rh5/6
        fi
	
	
        CZ=`date | awk '{print$5}'`
        CLK=`cat /etc/sysconfig/clock | grep ^ZONE | awk -F= '{print$2}' | awk -F\" '{print$2}'`
        TZCH1=`/usr/bin/md5sum /etc/localtime | awk '{print$1}'`
        TZCH2=`/usr/bin/md5sum "/usr/share/zoneinfo/$CLK" 2>/dev/null | awk '{print$1}'`
        if [ "$TZCH1" = "$TZCH2" ]; then
                return $RV
        fi
        echo "TZ mismatch: $CZ != $CLK"
        return 1
}  #end of checktzdata

checkguard () {  #check for guardium install: -gd
        if [ -d /usr/local/guardium ]; then
                echo "Possible Guardium install found in /usr/local/guardium"
                return 1
        fi
        return 0
}  #end of checkguard

checkuptime () {  #check uptime: -uptime/+uptime
	if [ "$SUFF" != "prepatch" ]; then
		return 0  #skip
	fi
	if [ "$UPT" = "1" ]; then
		UPT=`uptime | grep -vi " day"`
	else
		UPT=`uptime | grep -i " day"`
	fi
	if [ "$UPT" != "" ]; then
		if [ $VERBOSE = 1 ]; then
			echo "### -uptime ###"
		fi
		UPT=`uptime | awk -F',' '{print$1,$2}'`
		echo "$UPT"
		return 1
	fi
	return 0
}  #end of checkuptime

dellopenman () {  #check and/or remove dell openmanagement software: -dell/+dell
	if [ ! -f /etc/system-release ]; then
		return 0  #not RH/COS?
	fi
	UU=`grep 6\. /etc/system-release`
	if [ "$UU" != "" ]; then  #RH/COS 6.x
		UU=`rpm -qa | grep srvadmin`
		if [ "$UU" != "" ]; then #found OpenManage packages
			echo "Found:"
			rpm -qa | grep -i srvadmin
			if [ "$DOIT" = "1" ]; then #Remove it
				echo "Removing Dell OpenManage"
				yum -y remove srvadmin-*
			fi
			return 1
		fi
		return 0
	fi
	UU=`grep 5\. /etc/redhat-release`
	if [ "$UU" != "" ]; then  #RH/COS 5.x
		UU=`rpm -qa | grep -i openwsman`
		if [ "$UU" != "" ]; then #found OpenManage packages
			echo "Found:"
			rpm -qa | grep -i openwsman
			if [ "$DOIT" = "1" ]; then #Remove it
				echo "Removing Dell OpenManage"
				yum -y remove openwsman-*
			fi
			return 1
		fi
		return 0
	fi
	return 0
} #end of dellopenman

show_luks () {  #find LUKS volumes only, no checks: -fluks
	if [ "$OSVER" = "Linux" ]; then  #Linux
		LUKFL=""
		LUKFL=`for i in \`blkid | grep "LUKS" | awk '{print$1}'\`; do echo -n "$i  ";done`
		if [ "$LUKFL" != "" ]; then
			echo "LUKS devices found: $LUKFL"
			return 1
		fi
	fi
	return 0
}  #end of show_luks

check_apache() {  #check for local/group apache: -apache
	UCK="apache"
	if [ "$OSVER" = "SunOS" ]; then
		return 0  #only check Linux
	fi
	if [ ! -x /usr/sbin/httpd ]; then
		return 0  # no standard apache installed
	fi
	RT=0
	UUOUT=`grep "$UCK" /etc/passwd`
	if [ "$UUOUT" = "" ];then
		RT=1
	fi
	UUOUT=`grep "$UCK" /etc/group`
	if [ "$UUOUT" = "" ]; then
		RT=`expr $RT + 2`
	fi
	if [ $RT != 0 ]; then
	   case $RT in
		1)
			echo "($RT) httpd installed, group found, but no local apache user"
			;;
		2)
			if [ "$DOIT" = "(FIXED)" ]; then
				echo "apache:x:48:" >> /etc/group
			fi
			echo "($RT) httpd installed, missing apache group /etc/group $DOIT"
			;;
		3)
			echo "($RT) httpd installed, using LDAP only"
	   esac
	fi
	return $RT
} #end of check_apache

check_grub () {  #check if grub.conf is a proper symlink: -grub
        if [ "$OSVER" = "SunOS" ]; then
                return 0  #only check Linux
        fi
	if [ -d /etc/grub.d -o -f /etc/grub2.cfg ]; then
		return 0  #skip Linux 7.x
	fi
	if [ ! -f /etc/grub.conf ]; then
		echo "/etc/grub.conf does not exist"
		return 1
	fi
	if [ ! -f /boot/grub/grub.conf ]; then
		echo "/boot/grub/grub.conf does not exist"
		return 1
	fi
	if [ -h /etc/grub.conf ]; then
		UU=`ls -l /etc/grub.conf | grep -v boot/grub/grub.conf`
		if [ "$UU" != "" ]; then
			UU=`ls -l /etc/grub.conf | grep -v boot/efi/`
			if [ "$UU" != "" ]; then
				echo "/etc/grub.conf does not point to grub config under /boot"
			fi
			return 1
		fi
		U1=`stat -L --format='%Z %s' /etc/grub.conf`
		U2=`stat --format='%Z %s' /boot/grub/grub.conf`
		if [ -f /boot/efi/EFI/redhat/grub.efi ]; then
			U3=`stat --format='%Z %s' /boot/efi/EFI/redhat/grub.efi`
		 else
			U3=$U2
		fi
		if [ "$U1" != "$U2" -a "$U1" != "$U3" ]; then
			echo "/etc/grub.conf does not match /boot/*/grub.conf or /boot/*/grub.efi"
			return 2
		fi
		return 0  #symlink and the match, we're good
	fi
	#if still here it must be a file
	echo "/etc/grub.conf is a regular file, should be a symlink"
	return 2
}  #end of check_grub

listupdates () {  #-listup, list available updates for Linux
	if [ "$OSVER" = "SunOS" ]; then
		return 0
	fi
	#FIXME-UBUNTU#
	if [ -x /usr/bin/yum -o -x /bin/yum ]; then
		yum -q list updates | grep -v "Updated Packages"
	fi
	return 0
} #end of listupdates

check_exclude () {   #-excl, check for yum excludes (fmr. -chex)
	if [ "$OSVER" = "SunOS" ]; then
		return 0
	fi
	if [ -f /etc/yum.conf ]; then
		UUOUT=`grep ^exclude= /etc/yum.conf`
		if [ "$UUOUT" != "" ]; then
			grep ^exclude= /etc/yum.conf
			return 1
		fi
	fi
	return 0
}  #end of check_exclude

check_vm () {  #-vm, is host a VM?
	if [ "$OSVER" = "SunOS" ]; then
		if [ -x /sbin/zonename ]; then
			UU=`zonename`
			if [ "$UU" != "global" -a "$UU" != "" ]; then
				echo "host is a Solaris zone"
				return 1
			 else
				return 0
			fi
		fi
		echo "zonename not found (Solaris 8?)"
		return 1
	fi
	UU=`whoami`
	if [ "$UU" != "root" ]; then
		echo "root permissions needed on Linux"
		return 2
	fi
	UU=`dmidecode | grep OpenStack|grep Manufacturer|head -1`
	if [ "$UU" != "" ]; then
		echo "host is on OpenStack"
		return 1
	fi
	UU=`dmidecode | grep VMware | grep Manufacturer|head -1`
	if [ "$UU" != "" ]; then
		echo "host is on VMware"
		return 1
	fi
	UU=`dmidecode | grep KVM | grep "Product Name"|head -1`
	if [ "$UU" != "" ]; then
		echo "host is on unknown KVM"
		return 1
	fi
	UU=`dmidecode | grep QEMU | grep "Manufacturer"|head -1`
	if [ "$UU" != "" ]; then
		echo "host is on QEMU/Proxmox"
		return 1
	fi
	UU=`dmidecode | grep Xen | grep Manufacturer|head -1`  #is this correct?
	if [ "$UU" != "" ]; then
		echo "host is on Xen"
		return 1
	fi
	UU=`dmidecode | grep VirtualBox | grep "Product Name"|head -1`
	if [ "$UU" != "" ]; then
		echo "host is on VirtualBox"
		return 1
	fi
	return 0
}  #end of check_vm

print_dimms () {  #-dimms, show memory config
	if [ "$OSVER" = "SunOS" ]; then
		return 0
	fi
	dmidecode | (
        read A
        RC=$?
        MF=0
        while [ $RC = 0 ]; do
                if [ "$A" = "Memory Device" ]; then
                        MF=1
                        read A
                        RC=$?
                        if [ $RC != 0 ]; then
                                exit 0  #nothing more
                        fi
                fi
                if [ "$A" = "" ]; then
                        if [ $MF = 1 ]; then
                                echo "Slot: $SLOT, Type: $TYPE, Speed: $SPEED, Size: $SIZE"
                        fi
                        MF=0  #done if MF=1
                fi
                if [ $MF = 1 ];then
                        F1=`echo $A | awk -F': ' '{print$1}'`
                        F2=`echo $A | awk -F': ' '{print$2}'`
                        if [ "$F1" = "Size" ]; then
                                if [ "$F2" = "No Module Installed" ]; then
                                        SIZE="0"
                                else
                                        SIZE="$F2"
                                fi
                        fi
                        if [ "$F1" = "Speed" ]; then
                                if [ "$F2" = "Unknown" ]; then
                                        SPEED="N/A"
                                else
                                        SPEED="$F2"
                                fi
                        fi
                        if [ "$F1" = "Locator" ]; then
                                SLOT="$F2"
                        fi
                        if [ "$F1" = "Type" ]; then
                                TYPE="$F2"
                        fi
                fi
                read A
                RC=$?
        done
        ) | head -32
	return 0
} #end print_dimms

#RAID options below this point, set MEGACLI variable now
MEGACLI="/bin/false"
if [ -x /opt/MegaRAID/MegaCli/MegaCli64 ]; then
	MEGACLI="/opt/MegaRAID/MegaCli/MegaCli64"
else
	if [ -x /opt/MegaRAID/MegaCli/MegaCli ]; then
		MEGACLI="/opt/MegaRAID/MegaCli/MegaCli"
	fi
	if [ -x /usr/sbin/megacli ]; then
		MEGACLI="/usr/sbin/megacli"
	fi
	if [ -x /usr/local/bin/megacli ]; then
		MEGACLI="/usr/local/bin/megacli"
	fi
fi

list_vdisks () { #-vdisks, show RAIDed virtual disks
	if [ "$OSVER" = "SunOS" ]; then
		return 0
	fi
	USER=`whoami`
	if [ "$USER" != "root" ]; then
		echo "Need to be root"
		return 1
	fi
	if [ $MEGACLI = "/bin/false" ]; then
		echo "No MegaRAID installed?"
		return 1
	fi
	$MEGACLI -LDInfo -Lall -aALL | (
		read A
                RC=$?
                MF=0
                while [ $RC = 0 ]; do
			ADN=`echo $A | grep "^Adapter " `
			if [ "$ADN" != "" ]; then
				ADP=`echo $ADN | awk '{print$2}'`
			fi
                        F1=`echo $A | awk -F: '{print$1}'`
                        if [ "$F1" = "Virtual Drive" -o "$F1" = "Virtual Disk" ]; then
                                if [ $MF = 1 ]; then
                                        echo "--------------------------------"
                                fi
                                MF=1
                                echo "Adapter $ADP:$A"
				#print out phy disk slot IDs for this vdisk
				$MEGACLI -LdPdInfo -a$ADP | grep -E "Virtual Drive:|Slot Number:|Enclosure Device ID:|^Adapter " | (
					read B
					RCC=$?
					MFF=0
					SNSTR=""
					while [ $RCC = 0 ]; do
						TSTR=`echo $B | awk '{print$1}'`
						if [ "$B" = "$A" ]; then
							MFF=1
						fi
						F2=`echo $B | awk -F':' '{print$1}'`
						if [ "$F2" = "Enclosure Device ID" ]; then
							EDI=`echo $B | awk -F': ' '{print$2}'`
						fi
						if [ "$F2" = "Slot Number" ]; then
							if [ $MFF = 1 ]; then
								F2=`echo $B | awk '{print$3}'`
								SNSTR="$SNSTR $EDI:$F2"
							fi
						fi
						if [ "$B" != "$A" -a "$TSTR" = "Virtual" ]; then
							#New Virtual disk
							if [ $MFF = 1 -a "$SNSTR" != "" ]; then
								echo "Physical Drive [Enclosure:Slot] IDs:$SNSTR"
								exit 0 #nothing more needed now
							fi
							MFF=0  #new virtual disk
						fi
						read B
						RCC=$?
					done
					#only get here if this was the last vdisk
					if [ "$SNSTR" != "" ]; then
						echo "Physical Drive slot IDs:$SNSTR"
					fi
				)
                        fi
                        for i in "Name" "RAID Level" "Size" "State" \
                          "Strip Size" "Stripe Size" "Number Of Drives" \
                          "Span Depth" "Current Cache Policy" \
                          "Encryption Type"; do

                                F1=`echo $A | grep "^$i"`
                                if [ "$F1" != "" ]; then
                                        echo $A
                                fi
                        done
                        read A
                        RC=$?
                done
		if [ -f MegaSAS.log ]; then
                	rm -f MegaSAS.log
                fi
                if [ $MF = 0 ]; then
                        echo "No virtual disks found"
                        return 1
                else
                        return 0
                fi
        )
        return $?
} #end list_vdisks

list_pdisks () {  #-pdisks, show RAIDed physical disks
        if [ "$OSVER" = "SunOS" ]; then
                return 0
        fi
        USER=`whoami`
        if [ "$USER" != "root" ]; then
                echo "Need to be root"
                return 1
        fi
        if [ $MEGACLI = "/bin/false" ]; then
                echo "No MegaRAID installed?"
                return 1
        fi
	$MEGACLI -PDList -aALL | (
		ADP="0"
		read A
                RC=$?
                MF=0
                while [ $RC = 0 ]; do
			A1=`echo $A | grep ^Adapter`
                        if [ "$A1" != "" ]; then
                                ADP=`echo $A1 | awk -F'#' '{print$2}'`
                        fi
                        F1=`echo $A | awk -F: '{print$1}'`
                        if [ "$F1" = "Enclosure Device ID" ]; then
                                if [ $MF = 1 ]; then
                                        echo "--------------------------------"
					EID=""
					SID=""
                                fi
                                MF=1
                        fi
			case $F1 in
                                "Enclosure Device ID")
                                        echo "Adapter $ADP; $A"
					EID=`echo $A | awk -F": " '{print$2}'`
                                        ;;
                                "Slot Number")
                                        echo $A
					SID=`echo $A | awk -F": " '{print$2}'`
                                        ;;
                                "Drive's position")
                                        echo $A
                                        ;;
				"Enclosure position")
					echo $A
					;;
                                "Media Error Count")
                                        echo $A
                                        ;;
                                "Other Error Count")
                                        echo $A
                                        ;;
                                "Predictive Failure Count")
                                        echo $A
                                        ;;
                                "PD Type")
                                        echo $A
                                        ;;
                                "Raw Size")
                                        echo $A
                                        ;;
				"FDE Capable")
					echo $A
					;;
				"FDE Enable")
					echo $A
					;;
				"Device Firmware Level")
					echo $A
					;;
				"Media Type")
					echo $A
					;;
                                "Firmware state")
					FST=`echo $A | awk -F": " '{print$2}'`
					if [ "$FST" = "Rebuild" ]; then
						if [ "$EID" = "N/A" ]; then
							NEID=""
						else
							NEID=$EID
						fi
						UUU=`$MEGACLI PDRbld -ShowProg -PhysDrv [$NEID:$SID] -a$ADP | grep "^Rebuild Progress" | awk -F"Completed " '{print$2}'`
						if [ "$UUU" != "" ]; then
							echo "$A (completed $UUU)"
						else
							echo $A
						fi
					else
						echo $A
					fi
                                        ;;
                                "Inquiry Data")
                                        echo $A
                                        ;;
                                "Secured")
                                        echo $A
                                        ;;
                                "Foreign State")
                                        echo $A
                                        ;;
                                "Drive has flagged a S.M.A.R.T alert ")
                                        echo $A
                                        ;;
                        esac
                        read A
                        RC=$?
                done
		if [ -f MegaSAS.log ]; then
                	rm -f MegaSAS.log
                fi
		if [ $MF = 0 ]; then
                        echo "No RAID managed physical disks found"
                        return 1
                else
                        return 0
                fi
        )
        return $?
}  #end list_pdisks

list_baddisks () {  #-/+baddisks
        if [ "$OSVER" = "SunOS" ]; then
                return 0
        fi
        USER=`whoami`
        if [ "$USER" != "root" ]; then
                echo "Need to be root"
                return 1
        fi
        if [ $MEGACLI = "/bin/false" ]; then
                echo "No MegaRAID installed?"
                return 1
        fi
	TMPFILE1="/tmp/zsatoolz-BDtmp.$$._"
	TMPFILE="/tmp/zsatoolz-BD.$$._"
	$MEGACLI -PDList -aALL | (
		FOUND=0
		ADP="0"  #default to 0
                read A
                RC=$?
                MF=0
                while [ $RC = 0 ]; do
			A1=`echo $A | grep ^Adapter`
			if [ "$A1" != "" ]; then
				ADP=`echo $A1 | awk -F'#' '{print$2}'`
			fi
                        F1=`echo $A | awk -F: '{print$1}'`
                        if [ "$F1" = "Enclosure Device ID" ]; then
				if [ $FOUND = 1 ]; then
					cat $TMPFILE1 >> $TMPFILE
					FOUND=0
					PFAIL=0
					rm -f $TMPFILE1
				fi
                                if [ $MF = 1 ]; then
                                        echo "--------------------------------" > $TMPFILE1
                                fi
                                MF=1
                        fi
                        case $F1 in
                                "Enclosure Device ID")
                                        echo "Adapter $ADP; $A" >> $TMPFILE1
					EID=`echo $A | awk -F": " '{print$2}'`
                                        ;;
                                "Slot Number")
                                        echo $A >> $TMPFILE1
					SID=`echo $A | awk -F": " '{print$2}'`
                                        ;;
                                "Drive's position")
                                        echo $A >> $TMPFILE1
                                        ;;
				"Enclosure position")
					echo $A >> $TMPFILE1
					;;
                                "Media Error Count")
                                        echo $A >> $TMPFILE1
					UU=`echo $A | awk -F": " '{print$2}'`
					if [ "$UU" != "0" -a "$DOIT" = "1" ]; then
						FOUND=1
					fi
                                        ;;
                                "Other Error Count")
                                        echo $A >> $TMPFILE1
					#UU=`echo $A | awk -F": " '{print$2}'`
					#if [ "$UU" != "0" -a "$DOIT" = "1" ]; then
					#	FOUND=1
					#fi
                                        ;;
                                "Predictive Failure Count")
                                        echo $A >> $TMPFILE1
					UU=`echo $A | awk -F": " '{print$2}'`
					if [ "$UU" != "0" -a "$DOIT" = "1" ]; then
						FOUND=1
					fi
                                        ;;
                                "PD Type")
                                        echo $A >> $TMPFILE1
                                        ;;
                                "Raw Size")
                                        echo $A >> $TMPFILE1
                                        ;;
				"FDE Capable")
					echo $A >> $TMPFILE1
					;;
                                "Firmware state")
					UU=`echo $A | egrep -v 'Online|Hotspare|good'`
					FST=`echo $UU | grep Rebuild`
					if [ "$FST" != "" ]; then
						FOUND=1
					        if [ "$EID" = "N/A" ]; then
                                                       	NEID=""
                                               	else
                                                       	NEID=$EID
                                               	fi
						UUU=`$MEGACLI PDRbld -ShowProg -PhysDrv [$NEID:$SID] -a$ADP | grep "^Rebuild Progress" | awk -F"Completed " '{print$2}'`
						if [ "$UUU" != "" ]; then
							echo "$A (completed $UUU)" >> $TMPFILE1
						else
							echo $A >> $TMPFILE1
						fi
					else
						echo $A >> $TMPFILE1
					fi
					if [ "$UU" != "" ]; then
						FOUND=1
					fi
                                        ;;
                                "Inquiry Data")
                                        echo $A >> $TMPFILE1
                                        ;;
                                "Secured")
                                        echo $A >> $TMPFILE1
                                        ;;
                                "Foreign State")
                                        echo $A >> $TMPFILE1
					UU=`echo $A | awk -F": " '{print$2}'`
					if [ "$UU" != "None" ]; then
						FOUND=1
					fi
                                        ;;
                                "Media Type")
                                        echo $A >> $TMPFILE1
                                        ;;
                                "Drive has flagged a S.M.A.R.T alert ")
                                        echo $A >> $TMPFILE1
					if [ "$DOIT" = "1" ]; then
					  UU=`echo $A | grep  Yes`
					  if [ "$UU" != "" ]; then
						FOUND=1
					  fi
					fi
                                        ;;
                        esac
                        read A
                        RC=$?
                done
		if [ $FOUND = 1 ]; then
                	cat $TMPFILE1 >> $TMPFILE
		fi
		rm -f $TMPFILE1
		$MEGACLI -PdGetMissing -aALL >> $TMPFILE1
		UU=`$MEGACLI -PdGetMissing -aALL | grep "Expected"`
		if [ "$UU" != "" ]; then
			echo "==========================================" > $TMPFILE1
			$MEGACLI -PdGetMissing -aALL | egrep 'Adapter|Expected|MB' >> $TMPFILE1
			cat $TMPFILE1 >> $TMPFILE
			FOUND=1
			rm -f $TMPFILE1
		fi
		if [ -f MegaSAS.log ]; then
                	rm -f MegaSAS.log
                fi
                if [ $MF = 0 ]; then
                        echo "No RAID managed physical disks found"
                        return 1
                else
			if [ -f $TMPFILE ]; then
				cat $TMPFILE
				rm -f $TMPFILE
				return 1
			fi
		fi
                return 0
        )
        return $?
} #end of list_baddisks
	
list_unused_drives () {  #-sparedisks
	if [ "$OSVER" = "SunOS" ]; then
		return 0
	fi
	USER=`whoami`
	if [ "$USER" != "root" ]; then
		echo "Need to be root"
		return 1
	fi
	if [ $MEGACLI = "/bin/false" ]; then
		echo "No MegaRAID installed?"
		return 1
	fi
	TMPFILE1="/tmp/zsatoolz-BDtmp.$$._"
	TMPFILE="/tmp/zsatoolz-BD.$$._"
	$MEGACLI -PDList -aALL | (
		FOUND=0
		ADP="0"  #default to 0
		read A
		RC=$?
		MF=0
		while [ $RC = 0 ]; do
			A1=`echo $A | grep ^Adapter`
			if [ "$A1" != "" ]; then
				ADP=`echo $A1 | awk -F'#' '{print$2}'`
			fi
			F1=`echo $A | awk -F: '{print$1}'`
			if [ "$F1" = "Enclosure Device ID" ]; then
				if [ $FOUND = 1 ]; then
					cat $TMPFILE1 >> $TMPFILE
					FOUND=0
					PFAIL=0
					rm -f $TMPFILE1
				fi
				if [ $MF = 1 ]; then
					echo "--------------------------------" > $TMPFILE1
				fi
				MF=1
			fi
			case $F1 in
				"Enclosure Device ID")
					echo "Adapter $ADP; $A" >> $TMPFILE1						EID=`echo $A | awk -F": " '{print$2}'`
					;;
				"Slot Number")
					echo $A >> $TMPFILE1
					SID=`echo $A | awk -F": " '{print$2}'`
					;;
				"Drive's position")
					echo $A >> $TMPFILE1
					;;
				"Enclosure position")
					echo $A >> $TMPFILE1
					;;
				"Media Error Count")
					echo $A >> $TMPFILE1
					;;
				"Other Error Count")
					echo $A >> $TMPFILE1
					;;
				"Predictive Failure Count")
					echo $A >> $TMPFILE1
					;;
				"PD Type")
					echo $A >> $TMPFILE1
					;;
				"Raw Size")
					echo $A >> $TMPFILE1
					;;
				"FDE Capable")
					echo $A >> $TMPFILE1
					;;
				"Firmware state")
					echo $A >> $TMPFILE1
					UU=`echo $A | egrep 'good|Hotspare'`
					if [ "$UU" != "" ]; then
						FOUND=1
					fi
					;;
				"Inquiry Data")
					echo $A >> $TMPFILE1
					;;
				"Secured")
					echo $A >> $TMPFILE1
					;;
				"Foreign State")
					echo $A >> $TMPFILE1
					UU=`echo $A | awk -F": " '{print$2}'`
					if [ "$UU" != "None" ]; then
						FOUND=1
					fi
					;;
				"Media Type")
					echo $A >> $TMPFILE1
					;;
				"Drive has flagged a S.M.A.R.T alert ")
					echo $A >> $TMPFILE1
					;;
			esac
			read A
			RC=$?
		done
		if [ $FOUND = 1 ]; then
			cat $TMPFILE1 >> $TMPFILE
		fi
		rm -f $TMPFILE1
		if [ -f MegaSAS.log ]; then
			rm -f MegaSAS.log
		fi
		if [ $MF = 0 ]; then
			echo "No RAID managed physical disks found"
			return 1
		else
			if [ -f $TMPFILE ]; then
				cat $TMPFILE
				rm -f $TMPFILE
				return 1
			fi
		fi
		return 0
	)
	return $?
} #end of list_unused_drives

foreigncfg () {  #-/+foreign
	if [ "$OSVER" = "SunOS" ]; then
		return 0  #only check Linux
	fi
	if [ $MEGACLI = "/bin/false" ]; then
		echo "No MegaRAID installed?"
		return 1
	fi
	TMPFILE1="/tmp/zsatoolz-BDtmp.$$._"
	TMPFILE="/tmp/zsatoolz-BD.$$._"
	$MEGACLI -PDList -aALL | (
		ADP="0"
		read A
		RC=$?
		FOUND=0
		MF=0
		while [ $RC = 0 ]; do
			A1=`echo $A | grep ^Adapter`
			if [ "$A1" != "" ]; then
				ADP=`echo $A1 | awk -F'#' '{print$2}'`
			fi
			F1=`echo $A | awk -F: '{print$1}'`
			if [ "$F1" = "Enclosure Device ID" ]; then
				if [ $FOUND = 1 ]; then
					cat $TMPFILE1 >> $TMPFILE
					FOUND=0
					PFAIL=0
					rm -f $TMPFILE1
				fi
				if [ $MF = 1 ]; then
					echo "--------------------------------" > $TMPFILE1
				fi
				MF=1
			fi
			case $F1 in
				"Enclosure Device ID")
                                        echo "Adapter $ADP; $A" >> $TMPFILE1                                            EID=`echo $A | awk -F": " '{print$2}'`
                                        ;;
                                "Slot Number")
                                        echo $A >> $TMPFILE1
                                        SID=`echo $A | awk -F": " '{print$2}'`
                                        ;;
                                "Drive's position")
                                        echo $A >> $TMPFILE1
                                        ;;
                                "Enclosure position")
                                        echo $A >> $TMPFILE1
                                        ;;
                                "Raw Size")
                                        echo $A >> $TMPFILE1
                                        ;;
                                "FDE Capable")
                                        echo $A >> $TMPFILE1
                                        ;;
				"Firmware state")
                                        echo $A >> $TMPFILE1
					;;
				"Inquiry Data")
                                        echo $A >> $TMPFILE1
                                        ;;
				"Secured")
					echo $A >> $TMPFILE1
					UU=`echo $A | awk -F": " '{print$2}'`
					if [ "$UU" != "Unsecured" ]; then
						SEC=1  #future use
					fi
					;;
                                "Foreign State")
                                        echo $A >> $TMPFILE1
                                        UU=`echo $A | awk -F": " '{print$2}'`
                                        if [ "$UU" != "None" ]; then
                                                FOUND=1
						FOR=1 #future use
                                        fi
                                        ;;
                                "Media Type")
                                        echo $A >> $TMPFILE1
                                        ;;
			esac
			read A
			RC=$?
		done
		if [ $FOUND = 1 ]; then
                        cat $TMPFILE1 >> $TMPFILE
                fi
                rm -f $TMPFILE1
                if [ -f MegaSAS.log ]; then
                        rm -f MegaSAS.log
                fi
                if [ $MF = 0 ]; then
                        echo "No RAID managed physical disks found"
                        return 1
                else
                        if [ -f $TMPFILE ]; then
                                cat $TMPFILE
                                rm -f $TMPFILE
                                return 1
                        fi
                fi
                return 0
        )
        return $?
} #end of foreigncfg

display_vdrives () { #+/-vdrives
	if [ "$OSVER" = "SunOS" ]; then
                return 0  #only check Linux
        fi
	if [ $MEGACLI = "/bin/false" ]; then
		echo "No Megacli installed?"
		return 0
	fi
	if [ -x $MEGACLI ]; then
		UU=`$MEGACLI -LdPdInfo -aALL | grep -E "Virtual Drive:|Slot Number:"`
		if [ "$UU" = "" ]; then
			return 0  #nothing to report
		fi
		#Cool line so I'm keeping it here VVV - only works with 1 adapter present
		if [ "$DOIT" = "1" ]; then  #+vdrives
			$MEGACLI -LdPdInfo -aALL | grep -E "Virtual Drive:|Slot Number:" | xargs | sed -r 's/(Slot Number:)(\s[0-9]+)/\2,/g' | sed 's/(Target Id: .)/Physical Drive Slot IDs:/g' | sed 's/Virtual Drive:/\nVirtual Drive:/g' | tail -n +2
			if [ -f MegaSAS.log ]; then
				rm -f MegaSAS.log
			fi
			return 0
		fi
		$MEGACLI -LdPdInfo -aALL | grep -E "Virtual Drive:|Slot Number:|Enclosure Device ID:|^Adapter " | (
			read B
			RCC=$?
			MFF=0
			SNSTR=""
			while [ $RCC = 0 ]; do
				F2=`echo $B | awk -F: '{print$1}'`
				FA=`echo $B | awk -F'#' '{print$1}'`
				TSTR=`echo $F2 | awk '{print$1}'`
				if [ "$FA" = "Adapter " ]; then
					ADPN=`echo $B | awk -F'#' '{print$2}'`
					if [ $MFF = 0 ]; then
						ADP=$ADPN
					fi
				fi
				if [ "$F2" = "Enclosure Device ID" ]; then
					EDI=`echo $B | awk -F': ' '{print$2}'`
				fi
				if [ "$F2" = "Slot Number" ]; then
					if [ $MFF = 1 ]; then
						F1=`echo $B | awk '{print$3}'`
						SNSTR="$SNSTR $EDI:$F1"
					fi
				fi
				if [ "$TSTR" = "Virtual" ]; then #new VD
					if [ $MFF = 1 -a "$SNSTR" != "" ]; then
						echo "Adapter $ADP: Virtual Drive $VDS - Physical Drives[Enclosure:Slot]=$SNSTR"
					fi
					VDS=`echo $B | awk -F: '{print$2}' | awk '{print$1}'`
					MFF=1
					SNSTR=""
					ADP=$ADPN
				fi
				read B
				RCC=$?
			done
			#only get here if this was the last vdisk
			if [ "$SNSTR" != "" ]; then
				echo "Adapter $ADP: Virtual Drive $VDS - Physical Drives[Enclosure:Slot]=$SNSTR"
			fi
			if [ -f MegaSAS.log ]; then
				rm -f MegaSAS.log
			fi
			if [ $MFF = 0 ]; then
				echo "No virtual disks found"
				return 1
			else
				return 0
			fi
		)
		return 1  #data returned
	fi
	return 0  #shouldn't ever get here
} #end of display_vdrives

raid_status () { #-raid
	if [ "$OSVER" = "SunOS" ]; then
                return 0  #only check Linux
        fi
	if [ $MEGACLI = "/bin/false" ]; then
		echo "No MegaRAID installed?"
		return 1
	fi
	$MEGACLI -AdpAllInfo -aAll | (
		read A
		RC=$?
		MF=0
		while [ $RC = 0 ]; do
			UU=`echo $A | grep "^Adapter #"`
			if [ "$UU" != "" ]; then
				if [ $MF = 1 ]; then
					MF=0
					echo
				fi
				echo -e "-\n$A"
			fi
			if [ $MF = 1 ]; then
				if [ "$A" = "" ]; then
					MF=0
				else
					UU=`echo $A | grep "Physical Devices"`
					if [ "$UU" != "" ]; then
						CHAS=`echo $A | awk -F': ' '{print$2}'`
					else
						UUU=`echo $A | awk '{print$1}' | grep "^Disks"`
						if [ "$UUU" != "" ]; then
							DISKCO=`echo $A | awk -F': ' '{print$2}'`
							CHASCO=`expr $CHAS - $DISKCO`
							echo -e "Chassis Count\t: $CHASCO"
						fi
						echo "$A"
					fi
				fi
			else  #MF=0
				UU=`echo "$A" | grep "Device Present"`
				if [ "$UU" != "" ]; then
					MF=1
				fi
				UU=`echo "$A" | grep "^Product Name"`
				if [ "$UU" != "" ]; then
					UUU=`echo $A | awk -F: '{print$2}'`
					echo "Model:$UUU"
				fi
				UU=`echo "$A" | grep "^FW Package Build"`
				if [ "$UU" != "" ]; then
					UUU=`echo $A | awk -F: '{print$2}'`
					echo "Firmware version:$UUU"
				fi
			fi
			read A
			RC=$?
		done
	)
	#read chassis info
	ADP=""
	$MEGACLI -EncInfo -aALL | (
		read A
		RC=$?
		while [ $RC = 0 ]; do
			UU=`echo $A | grep "Number of enclosures on adapter"`
			if [ "$UU" != "" ]; then
				ADP=`echo $A | awk -F"adapter" '{print $2}' | awk '{print$1}'`
			fi
			UU=`echo $A | grep "Device ID"`
			if [ "$UU" != "" ]; then
				ENC=`echo $A | awk -F':' '{print$2}'`
				echo "############ Enclosure ############"
				echo "Adapter $ADP; Device ID $ENC"
			fi
			UU=`echo $A | grep "Number of Slots"`
			if [ "$UU" != "" ]; then
				echo "$A"
			fi
			UU=`echo $A | grep "Number of Physical Drives"`
			if [ "$UU" != "" ]; then
				echo "$A"
			fi
			UU=`echo $A | grep "^Status"`
			if [ "$UU" != "" ]; then
				echo "$A"
			fi
			read A
			RC=$?
		done
	) 
	if [ -f MegaSAS.log ]; then
		rm -f MegaSAS.log
	fi
	return 0
}  #end of raid_status

print_hwarch () {  #-hw; print HW vendor/model/OS/version
        if [ "$OSVER" = "SunOS" ]; then
		OS=`uname -s`
		VN=`uname -i`
		VER=`uname -r`
		if [ -x /sbin/zonename ]; then
			ZN=`zonename`
		else
			ZN="global"
		fi
		echo "Vendor: Sun Microsystems, Product: $VN,  OS: $OS ($VER) [$ZN zone]"
                return 0
        fi
	#Linux follows
        USER=`whoami`
        if [ "$USER" != "root" ]; then
                echo "Need to be root"
                return 1
        fi
	if [ -x /usr/bin/lscpu ]; then
		#SOCKS=`lscpu | grep ^Socket | awk -F':' '{print$2}' | awk '{print$1}'`
		#CORES=`lscpu | grep ^Core | awk -F':' '{print$2}' | awk '{print$1}'`
		CPUS=`lscpu | grep "^CPU(s)" | awk -F':' '{print$2}' | awk '{print$1}'`
		THRDS=`lscpu | grep "^Thread" | awk -F':' '{print$2}' | awk '{print$1}'`
		HZ=`lscpu | grep "^CPU MHz" | awk -F':' '{print$2}' | awk '{print$1}' | awk -F'.' '{print$1}'`
		GHZ=`lscpu | grep "^Model name:" | awk '{print$NF}'`
		if [ "$THRDS" = "2" ]; then
			CPU="CPUs: $CPUS (HT) [${HZ} MHz/$GHZ], "
		 else
			CPU="CPUs: $CPUS [${HZ} MHz/$GHZ], "
		fi
	fi
	MEM=`free -mt | grep Mem: | awk '{print$2}'`
	BIOS=`dmidecode -s bios-version`
	dmidecode | (
		read A
		RC=$?
		MF=0
		while [ $RC = 0 ]; do
			if [ "$A" = "System Information" ]; then
				MF=1
				read A
				RC=$?
				if [ $RC != 0 ]; then
					exit 0
				fi
			fi
			if [ $MF = 1 ]; then
				UU=`echo $A | grep "Manufacturer:"`
				if [ "$UU" != "" ]; then
					MAN=`echo $A | awk -F: '{print$2}'`
				fi
				UU=`echo $A | grep "Product Name:"`
				if [ "$UU" != "" ]; then
					PROD=`echo $A | awk -F: '{print$2}'`
				fi
				if [ -f /etc/redhat-release ]; then
					VERS=`cat /etc/redhat-release | awk -F"release" '{print$2}' | awk -F'(' '{print$1}' | awk '{print$1}' | awk -F. '{print$1}'`
				else
					if [ -f /etc/os-release ]; then
						VERS=`grep ^PRETTY_NAME /etc/os-release | awk -F"=\"" '{print$2}' | awk -F '"' '{print$1}'`
					fi
				fi
				if [ "$MAN" != "" -a "$PROD" != "" ]; then
					OS=`uname -s`
					echo "Vendor: $MAN,  Product: $PROD,  BIOSver: $BIOS,  RAM: $MEM MB, ${CPU}OS: $OS (${VERS}.x)"
					return 0
				fi
			fi
			read A
			RC=$?
		done
		if [ $MF = 0 ]; then
			echo "Unable to retrieve vendor/product"
			return 1
		fi 
	)
	return $?
}  #end print_hwarch

show_db () {  #-db/+db
	RV=0
	DBSTRING=""
	if [ "$DOIT" = "1" ]; then  #+db, show non-DB servers
		UU=`ps -ef | egrep -i '(ORACLE|mysqld|sybase|pgsql|mongodb|mariadb)' | egrep -v 'grep|clamscan'`
		if [ "$UU" = "" ]; then  #found a "non"match
			echo "No DBs found"
			return 1
		fi
		return 0  #DBs were found
	fi
	#show DB servers, -db
	UU=`ps -ef | grep -i mysqld | egrep -v 'grep|clamscan'`
	if [ "$UU" != "" ]; then
		DBSTRING=" Mysqld"
		RV=1
	fi
	UU=`ps -ef | grep -i oracle | egrep -v 'grep|clamscan'`
	if [ "$UU" != "" ]; then
		DBSTRING="$DBSTRING Oracle"
		RV=1
	fi
	UU=`ps -ef | grep -i sybase | egrep -v 'grep|clamscan'`
	if [ "$UU" != "" ]; then
		DBSTRING="$DBSTRING Sybase"
		RV=1
	fi
	UU=`ps -ef | grep -i mariadb | egrep -v 'grep|clamscan'`
	if [ "$UU" != "" ]; then
		DBSTRING="$DBSTRING MariaDB"
		RV=1
	fi
	UU=`ps -ef | grep -i mongodb | egrep -v 'grep|clamscan'`
	if [ "$UU" != "" ]; then
		DBSTRING="$DBSTRING MongoDB"
		RV=1
	fi
	UU=`ps -ef | grep -i pgsql | egrep -v 'grep|clamscan'`
	if [ "$UU" != "" ]; then
		DBSTRING="$DBSTRING PostgreSQL"
		RV=1
	fi
	if [ $RV != 0 ]; then
		echo "DB/Tools possibly running: $DBSTRING"
	fi
	return $RV
} #end of show_db

show_procs () {  #-/+running
	if [ "$ARGV" = "" ]; then
		echo "$0 -|+running PROCESSNAME"
		exit 0
	fi
	if [ "$ARGV" = "-debug" -o "$ARGV" = "+debug" ]; then
		echo "$0 -|+running PROCESSNAME [-|+debug]"
		exit 0
	fi
	UU=`ps -ef | grep -i $ARGV | grep -v satool | grep -v grep`
	if [ "$UU" != "" ]; then #found matches
		if [ "$DOIT" = "1" ]; then  #print full list
			ps -ef | grep -i $ARGV | grep -v satool | grep -v grep
			return 1
		 else  #print just count
			UU=`ps -ef | grep -i $ARGV | grep -v grep |grep -v satool |  wc -l`
			echo "$UU processes found"
			return 1
		fi
	fi
	return 0  #nothing found
}  #end of show_procs

debracket () {  #-debracket
	if [ "$ARG_1" = "" -o "$ARG_1" = "-debug" -o "$ARG_1" = "+debug" ]; then
        	echo "$ARG_0 -debracket FILENAME [-/+debug]"
        	exit 0
	fi
	if [ ! -f "$ARG_1" ]; then
        	echo "Cannot open $ARG_1"
        	exit 1
	fi
	RC=0
	cat $ARG_1 | (
        	read A
        	RC=$?
        	while [ $RC = 0 ]; do
			if [ "$A" != "" ]; then
                	   echo "$A" | awk -F'[' '{print$2}' | awk -F']' '{print$1}'
			fi
                	read A
                	RC=$?
        	done
	) | sort | uniq
	return 0
} #end of debracket

lastupdate () {  #-/+lastup
	if [ -f /var/log/yum.log ]; then
        	UU=`tail -1 /var/log/yum.log`
        	if [ "$UU" != "" ]; then
                	MO=`echo $UU | awk '{print$1}'`
                	DA=`echo $UU | awk '{print$2}'`
                	TDAT="$MO $DA"
                	if [ "$DOIT" = "1" ]; then
                        	tail -1000 /var/log/yum.log | grep "^$TDAT"
                	else
                        	UU=`tail -1000 /var/log/yum.log | grep "^$TDAT" | egrep '(Updated|Installed|Erased)' | wc -l`
                        	echo "$UU packages updated/installed/deleted ($TDAT)"
                	fi
                	return 1
        	fi
	fi
	return 0
}  #end of lastupdate

stat_repos() {  #-enabled
	if [ "$OSVER" = "SunOS" -o ! -d /etc/yum.repos.d ]; then
                return 0   #not Centos/RedHat
        fi
        cd /etc/yum.repos.d
        FOUND=0
        RV=0
        for i in `ls *.repo`; do
                cat $i | (
                        read A
                        RC=$?
                        MF=0
			EN=0
                        while [ $RC = 0 ]; do
                                UU=`echo $A | grep "^\["`
                                if [ "$UU" != "" ]; then
                                        RPC=`echo $A | awk -F'[' '{print$2}' | awk -F']' '{print$1}'`
                                 else RPC=""
                                fi
                                if [ "$RPC" != "" ]; then  #repo found
                                        if [ $MF = 0 ]; then  #first repo
                                                MF=1
                                                REPO=$RPC
                                        else  #new repo
                                                if [ $EN = 1 ]; then
                                                        if [ "$ARG2" = "" ]; then
                                                                ELIST="$ELIST $REPO"
                                                        else
                                                                if [ "$REPO" = "$ARG2" ]; then
                                                                        ELIST="$ELIST $REPO"
                                                                fi
                                                        fi
                                                fi
                                                REPO=$RPC
                                        fi
                                        EN=1  #default is enabled
                                fi
                                UU=`echo "$A" | grep "^enabled" | grep -v metadata`
                                if [ "$UU" != "" ]; then
                                        ENS=`echo $UU | awk -F'=' '{print$2}' | awk '{print$1}' | awk '{print$1}' | grep "0"`
                                        if [ "$ENS" != "" ]; then
                                                EN=0
                                        fi
                                fi
                                read A
                                RC=$?
                        done
                        if [ $EN = 1 ]; then
                                if [ "$ARG2" = "" ]; then
                                        ELIST="$ELIST $REPO"
                                else
                                        if [ "$REPO" = "$ARG2" ]; then
                                                ELIST="$ELIST $REPO"
                                        fi
                                fi
                        fi
                        if [ "$ELIST" != "" ]; then
                                echo "Enabled Repos($i): $ELIST"
                                RV=1
                        fi
                        return $RV
                )
                if [ $? != 0 ]; then RV=1
                fi
        done
        return $RV
}  #end stat_repos

readonly_chk () {  #+/-readonlyfs
        TMPFILE="zsatoolz-ROtest.$$._"
        RV=0
        for i in `mount -v | egrep "( ext3 | ext4 | xfs | ufs | zfs | vxfs | nfs | cifs | sshfs | gfs2 | btrfs | ceph | glusterfs | fuse\. )" | egrep -v "(chroot| /home| /export/zones| autofs | \(ro\))"| awk '{print$3":"$5}' | sort`; do
		TYPE=`echo $i | awk -F: '{print$2}'`
		i=`echo $i | awk -F: '{print$1}'`
if [ $DEBUG = 1 ]; then
                echo "checking $i  ($TYPE)"
fi
                cd $i > /dev/null 2>&1
                TV=$?
                if [ $TV != 0 ]; then
                        echo "Cannot cd to $i ($TYPE)"
                        RV=1
                else
			/bin/ls > /dev/null 2>&1
			TV=$?
			if [ $TV != 0 ]; then
				echo "unable to access $i ($TYPE)"
				RV=1
			else
                        	touch $TMPFILE > /dev/null 2>&1
                        	TV=$?
                        	RTD=$i
                        	if [ "$RTD" = "" ]; then RTD="/"
                        	fi
				#some NFS mounts may not allow root so be
				#lenient for nfs unless +readonly
                        	if [ $TV != 0 ]; then
					if [ "$DOIT" = "1" -o $TYPE != "nfs" ]; then
                                		echo "unable to create temp file on $RTD ($TYPE)"
                                		RV=1
					fi
                        	else
                                	/bin/rm $TMPFILE > /dev/null 2>&1
                                	TV=$?
                                	if [ $TV != 0 ]; then
						if [ "$DOIT" = "1" -o $TYPE != "nfs" ]; then
                                        		echo "unable to remove $RTD/TMPFILE"
                                        		RV=1
						fi
                                	fi
				fi
                        fi
                fi
        done
        return $RV
}  #end of readonly_chk

chknics () {  #-/+nics
	if [ "$OSVER" = "SunOS" ]; then
		return 0
	fi
	if [ ! -x /sbin/ethtool ]; then
		echo "ethtool not found"
		return 1
	fi
	WHO=`whoami`
	if [ "$WHO" != "root" ]; then
		echo "root access required"
		return 1
	fi
	UUV=`netstat -in | grep Iface | grep Met`
	for IFF in `netstat -in |egrep -v "(^Iface|^Kernel|^lo)" | awk '{print$1}'`; do
		IFFA=`echo $IFF | awk -F: '{print$2}'`
		if [ "$IFFA" = "" ]; then #proceed
		   if [ "$UUV" = "" ]; then #Centos7
        	   	RXERR=`netstat -in | grep $IFF | grep -v $IFF:$IFFA | awk '{print$4}'`
        	   	TXERR=`netstat -in | grep $IFF | grep -v $IFF:$IFFA | awk '{print$8}'`
		   else
			RXERR=`netstat -in | grep $IFF | grep -v $IFF:$IFFA | awk '{print$5}'`
			TXERR=`netstat -in | grep $IFF | grep -v $IFF:$IFFA | awk '{print$9}'`
		   fi
        	   LSPD=`ethtool $IFF | grep "Speed:" | awk -F": " '{print$2}'`
        	   LNK=`ethtool $IFF | grep "Link detected:" | awk -F": " '{print$2}'`
        	   DPLX=`ethtool $IFF | grep "Duplex:" | awk -F": " '{print$2}'`
        	   AUTN=`ethtool $IFF | grep "Auto-neg" | awk -F": " '{print$2}'`
		   UU=`ifconfig $IFF | egrep -i '(inet|slave)'`
		   if [ "$UU" != "" ]; then
			US="Up"
		    else
			US="Down"
		   fi
		   if [ "$US" = "Up" -o "$DOIT" = "1" ]; then
        		echo "$IFF: $US, rxerrs: $RXERR, txerrs: $TXERR, Link: $LNK, autoneg: $AUTN, speed: $LSPD, duplex: $DPLX"
		   fi
		fi
	done
	return 1
}  #end of chknics

print_idrac () {  #-idrac
        if [ "$OSVER" = "SunOS" ]; then
                return 0
        fi
	if [ ! -x /bin/ipmitool -a ! -x /usr/bin/ipmitool ]; then
		echo "ipmitool not found"
		return 1
	fi
	UU=`ls /dev | grep ipmi`
	if [ "$UU" = "" ]; then
		echo "ipmi interfaces not found/supported"
		return 1
	fi
	WHO=`whoami`
	if [ "$WHO" != "root" ]; then
		echo "root priviledges needed"
		return 1
	fi
	check_vm > /dev/null
	if [ $? = 1 ]; then
		echo "VM, info not available"
		return 1
	fi
	ipmitool lan print | egrep "IP Address|Subnet Mask|MAC Address|Default Gateway IP" | grep -v Source
	ipmitool mc info | grep "^Firmware Revision"
	return 0
} #end of print_idrac

print_disks () {  #-disks
	#note: if size < 1 GB, sizes may not be correct
	if [ ! -x /sbin/fdisk ]; then
		echo "Unable to determine disks"
		return 1
	fi
	if [ ! -d $PREPDIR ]; then
		mkdir -p $PREPDIR
	fi
	LOCALD="$PREPDIR/localdisks"
	TMPF="$PREPDIR/sandisks.tmp"
	echo > $TMPF
	SANS="$PREPDIR/sandisks"
        echo "None detected" > $SANS
	if [ -x /sbin/multipath ]; then
		UU=`multipath -ll`
    		if [ "$UU" != "" ]; then  #SAN disks
		   multipath -ll | (
		     #subshell
		     SZEALL="0"
                     read A
                     RC=$?
                     while [ $RC = 0 ]; do
                        UU=`echo $A | grep '^mpath'`
                        if [ "$UU" != "" ]; then  #new mpath device
                                if [ "$DEV" != "" ]; then  #flush
                                        NF=`echo $LDEVS | awk '{print$2}'`
                                        if [ "$NF" != "" ]; then  #is true SAN-double path
                                                echo "$FDEV; $SIZE; ($LDEVS )"
                                                echo "$DEV $LDEVS" >> $TMPF
						UUU=`echo $SIZE | grep -i t`
						if [ "$UUU" != "" ]; then
							UUU=`echo $SIZE | awk -F'T' '{print$1}' | awk -F't' '{print$1}'`
							SZEALL="$SZEALL+($UUU*1024)"
						 else
							UUU=`echo $SIZE | awk -F'g' '{print$1}' | awk -F'G' '{print$1}'`
							SZEALL="$SZEALL+$UUU"
						fi
                                        fi
                                fi
                                FDEV=$UU
                                DEV=`echo $UU | awk '{print$1}'`
                                LDEVS=""
                        fi
			#pull out size
                        UU=`echo $A | grep 'size='`
                        if [ "$UU" != "" ]; then
                                SZTMP=`echo $A | awk '{print$1}' | awk -F"size=" '{print$2}' | awk -F']' '{print$1}'`
				SIZE="size=$SZTMP"
                        fi
			#pull out any sd# aliases
                        UU=`echo $A | grep ' sd' | awk -F':' '{print$4}' | awk '{print$2}'`
                        if [ "$UU" != "" ]; then
                                LDEVS="$LDEVS /dev/$UU"
                        fi
                        read A
                        RC=$?
                     done
                     if [ "$DEV" != "" ]; then
                        NF=`echo $LDEVS | awk '{print$1}'`
                        if [ "$NF" != "" ]; then  #is at least SAN-single path
                                echo "$FDEV; $SIZE; ($LDEVS ) "
                                echo "$DEV $LDEVS" >> $TMPF
				UUU=`echo $SIZE | grep -i t`
                                if [ "$UUU" != "" ]; then
                                        UUU=`echo $SIZE | awk -F'T' '{print$1}' | awk -F't' '{print$1}'`
                                        SZEALL="$SZEALL+($UUU*1024)"
                                 else
                                        UUU=`echo $SIZE | awk -F'g' '{print$1}' | awk -F'G' '{print$1}'`
                                        SZEALL="$SZEALL+$UUU"
                                fi
                        fi
                     fi
		     echo "$SZEALL"
        	   ) > $SANS
		fi
	fi
	#eliminate "local" disks that are also SAN disks in disguise
	SZEALL="0"
        fdisk -l 2>/dev/null | grep ^Disk | grep -v mapper | grep -v identifier | grep -v label | grep -v "/dev/dm-" | grep -v "/dev/loop" | awk -F',' '{print$1}' | (
                read A
                RC=$?
                while [ $RC = 0 ]; do
                        UU=`echo $A | awk '{print$2}' | awk -F':' '{print$1}'`
                        UUF=`grep "$UU" $TMPF`
                        if [ "$UUF" = "" ]; then  #not in SAN list
				echo "$A"
				SZE=`echo $A | awk '{print$3}'`
				STP=`echo $A | awk '{print$4}'`
				if [ "$STP" = "GB" -o "$STP" = "GiB" ]; then
					SZEALL="$SZEALL+$SZE"
				fi
				if [ "$STP" = "TB" -o "$STP" = "TiB" ]; then
					SZE=`echo "$SZE*1024" | bc`
					SZEALL="$SZEALL+$SZE"
				fi
			fi
                        read A
                        RC=$?
                done
		echo "$SZEALL"
        ) > $LOCALD
	if [ -x /bin/bc -o -x /usr/bin/bc ]; then
		SZE=`tail -1 $LOCALD | bc`
	 else
		SZE="N/A"
	fi
	echo "  #### Local disks ($SZE GB) ####"
	cat $LOCALD | grep -v "^0"
	#Handle SANS if any
	if [ -x /sbin/multipath ]; then
		SZE="0"
		UU=`tail -1 $SANS | grep "^0+"`
		if [ "$UU" != "" ]; then
			if [ -x /bin/bc -o -x /usr/bin/bc ]; then
				SZE=`tail -1 $SANS | bc`
			 else
				SZE="N/A"
			fi
		fi
        	echo "  #### SAN disks ($SZE GB) ####"
        	cat $SANS | grep -v "^0"
	fi
	rm -f $TMPF $LOCALD #$SANS
}  #end of print_disks

print_disks2 () {  #-disks
	if [ -x /sbin/fdisk ]; then
		echo "  #### Local disks ####"
		fdisk -l 2>/dev/null | grep ^Disk | grep -v mapper | grep -v identifier | grep -v label | grep -v "/dev/dm-"
		if [ -x /sbin/multipath -o -x /usr/sbin/multipath ]; then
			UU=`multipath -ll` 2>/dev/null
			if [ "$UU" != "" ]; then
				echo "  #### SAN disks ####"
			fi
			multipath -ll | (
				read A
				RC=$?
				while [ $RC = 0 ]; do
					UU=`echo $A | grep '^mpath'`
					if [ "$UU" != "" ]; then
						DEV=$UU
					fi
					UU=`echo $A | grep '^size='`
					if [ "$UU" != "" ]; then
						SIZE=`echo $A | awk '{print$1}'`
					fi
					UU=`echo $A | grep 'status='`
					if [ "$UU" != "" ]; then
						STAT=`echo $A | awk -F'status=' '{print$2}'`
						echo "$DEV; $SIZE; status=$STAT"
					fi
					read A
					RC=$?
				done
			)
		fi
	fi
	return 0
}  #end of print_disks

rescan_drives () {  # -hdscan
	UU=`whoami`
	if [ "$UU" != "root" ]; then
		echo "Must be root"
		return 2
	fi
	if [ -f /sys/class/scsi_host/host2/scan ]; then
		echo "- - -" > /sys/class/scsi_host/host2/scan
		return 1
	fi
	return 0
}  #end of rescan_drives

check_mfa () {  #-mfa
	UU=`whoami`
	if [ "$UU" != "root" ]; then
		echo "Must be root"
		return 2
	fi
	if [ ! -f /var/log/secure -o ! -f /etc/security/access.conf ]; then
		return 1  #cannot proceed
	fi
        if [ "$ARG_1" = "" -o "$ARG_1" = "-debug" -o "$ARG_1" = "+debug" ]; then
                echo "$ARG_0 -mfa username [-/+debug]"
                exit 0
        fi
	IPS=`cat /var/log/secure | grep $ARG_1 | grep from | awk '{print $11}' | tr -d \'\" | grep -v $ARG_1`  #| cut -c 1-` #| sed '/^.\{,8\}$/d'`
	for line in $IPS; do
		if grep -q $line /etc/security/access.conf; then
			echo "IP address $line is whitelisted"
		else
			echo "IP address $line is not in the whitelist.  Login may fail."
		fi
	done
	return 0
} #end of check_mfa

check_auth () {  #check auth type -auth
	AA=`grep "^passwd" /etc/nsswitch.conf | grep "sss"`
	if [ "$AA" != "" ]; then
		grep 'NOAM.LNRM.NET' /etc/sssd/sssd.conf > /dev/null
		if [ $? = 0 ]; then
			echo "Appears to be NOAM"
			return 0
		fi
		grep 'ldap.risk.regn.net' /etc/sssd/sssd.conf > /dev/null
		if [ $? = 0 ]; then
			echo "Appears to be RISK"
			return 0
		fi
		echo "Unknown SSSD"
		return 1
	fi
	AA=`grep "^passwd" /etc/nsswitch.conf | grep "ldap"`
	if [ "$AA" != "" ]; then
		echo "Legacy LDAP"
		return 0
	fi
	AA=`grep "^passwd" /etc/nsswitch.conf | grep "files"`
	if [ "$AA" != "" ]; then
		echo "Local auth only"
		return 0
	fi
	echo "Cannot determine auth type"
	return 1
}  #end of check_auth

checkurl () {  #-chkurl/+chkurl
   if [ ! -x /usr/bin/curl -a ! -x /bin/curl ]; then
	echo "curl not found"
	return 2
   fi
   TEMPER="/var/tmp/$$_curlz"
   if [ "$http_proxy" = "" -a "$https_proxy" = "" ]; then
        if [ "$DOIT" = "1" ]; then
                echo "Setting Proxy..."
                LOC=`uname -n | cut -b1`
                if [ "$LOC" = "a" ]; then
                        export http_proxy="admzproxyout.risk.regn.net:80"
                        export https_proxy="admzproxyout.risk.regn.net:80"
                 else  #default to boca if unknown
                        export http_proxy="bdmzproxyout.risk.regn.net:80"
                        export https_proxy="bdmzproxyout.risk.regn.net:80"
                fi
        else
                echo "Proxy not set, using direct call"
        fi
   fi

   if [ "$http_proxy" != "" -o "$https_proxy" != "" ]; then
        echo "Proxy Set:"
        echo "  http_proxy=$http_proxy"
        echo "  https_proxy=$https_proxy"
   fi

   cat > $TEMPER << EOF__
{\n
"time_redirect": %{time_redirect},\n
"time_namelookup": %{time_namelookup},\n
"time_connect": %{time_connect},\n
"time_appconnect": %{time_appconnect},\n
"time_pretransfer": %{time_pretransfer},\n
"time_starttransfer": %{time_starttransfer},\n
"time_total": %{time_total},\n
"size_request": %{size_request},\n
"size_upload": %{size_upload},\n
"size_download": %{size_download},\n
"size_header": %{size_header}\n
}\n
EOF__

   curl -v -w "@$TEMPER" $EXTARGS
   RV=$?
   rm -f $TEMPER
   return $RV
} #end of checkurl()

###PUT NEW stuff that doesn't need prep here:

update_myself () {  #-new
	NEWPT="/var/tmp/satool.sh_$$"
	if [ -f $NEWPT ]; then
		rm -f $NEWPT
	fi
        UU=`whoami`
        if [ "$UU" != "root" ]; then
                echo "root permissions needed"
                return 2
        fi

	SUC=0
	if [ -x /usr/bin/wget -o -x /usr/sfw/bin/wget ]; then
		wget -q --connect-timeout=10 --read-timeout=20 -O $NEWPT http://linuxcores.risk.regn.net/cblr/localmirror/satool.sh
		RC=$?
		if [ $RC != 0 ]; then
			echo "Update failed via wget ($RC)"
			rm -f $NEWPT
			return 1
		fi
		SUC=1
	else 
		if [ -x /usr/bin/curl -o -x /usr/local/bin/curl ]; then
			curl -s http://linuxcores.risk.regn.net/cblr/localmirror/satool.sh > $NEWPT
			RC=$?
			if [ $RC != 0 ]; then
				echo "Update failed via curl ($RC)"
				rm -f $NEWPT
				return 1
			fi
			SUC=1
		fi
	fi
	if [ $SUC != 1 ]; then
		echo "Neither curl nor wget found...aboring"
		return 1
	fi
	UO=`/usr/local/bin/satool.sh -v`
	mv $NEWPT /usr/local/bin/satool.shnew
	chmod 0755 /usr/local/bin/satool.shnew
	UN=`/usr/local/bin/satool.shnew -v`
	if [ "$DOIT" = "1" ]; then  #we force update even if none
		mv /usr/local/bin/satool.sh /usr/local/bin/satool.shold
		mv /usr/local/bin/satool.shnew /usr/local/bin/satool.sh
		echo "Upgraded: $UO --> $UN"
	else
		if [ "$UO" != "$UN" ]; then
			echo "Available: $UO --> $UN"
		fi
	fi
	rm -f $NEWPT
	return 0
}  #end of update_myself

printusage () {  #print version/aid: -v and -?
        echo $"Usage: $0"
        echo "        {-p|-f|-c|-fc|-/+pc|-pf|-/+pfc|-/+r|-/+R|-varfs|-rootfs|-/+/++bootfs|"
        echo "         -usrfs|-allfs|-kern|-prekern|+/-netfs|-list FS|-/+vcs|-/+verlock|"
	echo "         -/+dell|-tz|-tzdata|-gd|-enabled|-lnrepos|-/+chkup|-yum|"
	echo "         -/+/++/--patch|-/+vips|-routes|-chkdrvr|-mem|-/+luks|-fluks|"
	echo "         -/+uptime|-os#|-zones|-nozones|-cmpzones|+stopzones|-/+testall|"
	echo "         -/+apache|-grub|-/+netprocs|-cmpsvcs|-cmpsys|-astr|-vm|-/+db|-/+last|"
	echo "         -lastall|-/+lastup|-/+running|-dimms|-vdisks|-pdisks|-vdrives|"
	echo "         -/+baddisks|-raid|-/+nics|-hw|-/+ntp|-/+readonlyfs|-clusterfs|"
	echo "         -debracket|-dup|-autopatch|-autoprepatch|-autopostpatch|-patchout|"
	echo "         -yumout|--/++/-/+prep|-prepout|-idrac|-disks|-/+newpt|-hdscan|"
	echo "         -hwreport|-excl|-/+appupdate|-/+appchkup|-appupdate|-/+liveappchk|"
	echo "         -liveappupdate|-/+livechkup|-liveupdate|-sparedisks|-/+cleanup|"
	echo "         -links|-pexe|-mfa|-auth|-/+chkurl|-/+dns|-resolv|-foreign|-decomm|"
	echo "         -shownet|-exports|-needreboot|-/+preboot|-pacem|-epoch|-/+cmpresolv"
	echo "         -v|-help} [Additional *patch (yum) flags]"
	echo "        [-debug|+debug]"
        echo "$VERSION"
	echo "   Data Directory: $PREPDIR   Archive: $PREPDIR/old"
	echo " -help : print usage information"
	return 0
}  #end of printusage

printfullusage() {  #print help: -help
	echo "============= PRE-patch options ============="
        echo " -apache : report if local apache user and/or local group do not exist"
        echo " +apache : report and fix if local apache user found, but local group is not"
        echo " -astr : check if asterisk/Dahdi VOIP software is installed"
        echo " -chkdrvr : check for Virident/FusionIO/Veritas/Dahdi drivers (Linux)"
        echo " -chkup : check for package updates for current repo config (Linux)"
	echo " +chkup : list available updates for current repo config (Linux)"
        echo " -dell : check for any Dell OpenManagement stuff (Linux)"
        echo " +dell : Remove any Dell OpenManagement stuff (Linux)"
        echo " -enabled [REPO] : list any enabled repos or if REPO is enabled (Linux)"
        echo " -excl : check for excludes in /etc/yum.conf (Linux)"
        echo " -gd : check for Guardium installation"
        echo " -grub : check that /etc/grub.conf is a proper symlink (Linux 5/6)"
        echo " -lnrepos : Check for LN Linux repository files or Solaris patch cluster date"
        echo " +r : refresh $PREPDIR/*.prepatch files for pre-patch preparation"
	echo " -r : report when last refresh of prepatch files was done"
	echo " +R : generate $PREPDIR/*.snapshot files apart from prepatch"
	echo " -R : same as -r"
        echo " -bootfs : report if /boot has less than $BOOTSIZE MB of space (Linux)"
	echo " +bootfs : do kernel cleanup if less than $BOOTSIZE MB of space on /boot (Linux)"
	echo " ++bootfs : force kernel cleanup for /boot (Linux)"
        echo " -rootfs : report if / has less than 512 MB of space"
        echo " -usrfs : report if /usr has less than 128 MB of space (Linux)"
        echo " -varfs : report if /var has less than $VARSTR of space"
        echo " -allfs : check /, /var, /usr, and /boot for the above free space"
        echo " -kern : check running Linux kernel against latest installed"
        echo " -luks : check for LUKS usage and verify basic integrity (Linux)"
        echo " +luks : show and check LUKS usage and verify basic integrity (Linux)"
        echo " -netfs : only check /etc/fstab for _netdev, netfs, and net delay (Linux)"
        echo " +netfs : FIX /etc/fstab for _netdev, activate netfs, add net delay (Linux)"
        echo " -nozones : report hosts where no running zones/VMs are found"
        echo " -ntp : report if any NTP issues found (Linux)"
        echo " +ntp : fix NTP issues one at a time, use -ntp to recheck (Linux)"
        echo " -os# : match OS type, where # = s [non-zone Solaris 10], 6 [RH6], 7 [RH7]"
        echo "        8 [RH8], l [Linux RH5/6/7/8], n [non-patchable], ' ' [anything]"
	echo " -pacem : check for PaceMaker Clustering (Linux)"
        echo " -prep : create patching prep report, showing any fatal errors only"
        echo " --prep : create a verbose patching prep report, show all output"
        echo " +prep : execute quiet patching prep, aborting on fatal errors"
        echo " ++prep : execute verbose patching prep, aborting on fatal errors"
	echo " -prepout : show results of last prep report or run"
        echo " -tzdata: compare timezone configuration with current timezone (Linux)"
        echo " -vcs : check for possible Veritas Cluster (use -pfc|-pc to verify)"
        echo " +vcs : check for any Veritas services"
        echo " -verlock : check for YUM version locks (Linux)"
        echo " +verlock : remove any YUM version locks (Linux)"
        echo " -yum : 'yum update' test run (requires expect to be installed, Linux)"
	echo " -yumout : show output of last -yum check (Linux)"
        echo " -zones : report hosts where running zones/VMs are found"
        echo "============= Legacy Patching options ============="
	echo " -autoprepatch : initiate prepatch collection via autopatch engine (Linux)"
        echo " -autopatch : initiate patching via the autopatch engine if capable (Linux)"
	echo " -autopostpatch : initiate post patching analysis via autopatch engine (Linux)"
        echo " +patch : Apply patches Sun/Linux, fully verbose output"
        echo " ++patch : Apply patches Sun/Linux, fully verbose output only on errors"
        echo " -patch : Apply patches Sun/Linux quietly, output warnings and errors"
        echo " --patch : Apply patches Sun/Linux quietly, output fatal errors only"
	echo " -patchout : show any output from last patching option"
        echo " +stopzones : issues a shutdown to any non-global running zones/VMs"
	echo "============= App Patching Options ============="
        echo " -appchkup : check for updates to App repo package against *-FROZEN (Linux)"
	echo " +appchkup : list available updates in App repos in *-FROZEN (Linux)"
	echo " -appupdate : update only App Repo packages against *-FROZEN (Linux)"
	echo " -liveappchk : check for updates to App repo packages against LN-LIVE (Linux)"
	echo " +liveappchk : list available updates in App repos in LN-LIVE (Linux)"
	echo " -liveappupdate : update only App Repo packages against LN-LIVE (Linux)"
	echo " -livechkup : check for any updates (App & OS) against LN-LIVE (Linux)"
	echo " +livechkup : list any updates (App & non-App) in LN-LIVE (Linux)"
	echo " -liveupdate : apply all available updates in LN-LIVE (Linux)"
	echo "============= POST-patch options ============="
	echo " -cmpresolv : compare prepatch /etc/resolv.conf for changes"
	echo " +cmpresolv : compare snapshot /etc/resolv.conf for chnages"
        echo " -cmpsvcs : compare service configurations (experimental)"
        echo " -cmpsys : compare sysctl kernel settings (Linux)"
	echo " -cmpzones : compare previously running VMs/zones to currently running"
	echo " -exports : compare exported filesystems, before and after (Linux)"
        echo " -mem : check to see if RAM amount changed (more than +/- 512MB)"
        echo " -p : show previous mounts only (if available)"
        echo " -f : show mountable entries in $FTYPE file only"
        echo " -c : show current mounts only"
        echo " -fc : compare $FTYPE with current mounts"
        echo " -pc : show missing mounts previously mounted with current, ignoring $FTYPE"
        echo " +pc : compare previous mounts with current mounts, ignoring $FTYPE file"
        echo " -pf : compare previous mounts with $FTYPE file"
        echo " -pfc : show missing previous mounts in $FTYPE not currently mounted"
        echo " +pfc : compare previous mounts that are in $FTYPE file to current mounts"
        echo " -prekern : compare previous with current kernel, report if not latest"
	echo " -needreboot : does the system need rebooting after patching?"
	echo " -preboot : report if a reboot will be needed if patched"
	echo " +preboot : report if reboot needed if patched, relevant updates listed"
        echo " -routes : compare previous and current ipv4 routing tables"
        echo " -tz : compare previous time zone with current"
        echo " -uptime : return if not rebooted in over a day"
        echo " +uptime : return if up less than a day"
        echo " -vips : check to see if all IP/VIPs are reachable"
        echo " +vips : compare previous IP/VIPs with current"
        echo " -testall : runs -uptime, -prekern, -mem, -vips, -pfc"
        echo "            -cmpzones  [all post-patch checks]  (see -r)"
        echo " +testall : runs -testall checks against last snapshot run (see +R)"
	echo "============= Extra Patching options ============="
        echo " -last : show most recent patch run (-patch/+patch/++patch/--patch)"
        echo " +last : show pkg updates from last patch run (Linux)"
	echo " -lastall : show history of past patch runs"
        echo " -lastup : show when and number of changes for last yum update (Linux)"
        echo " +lastup : show actual changes for last yum update/install (Linux)"
        echo "============= Filesystem Misc Options ============="
        echo " -c : show current mounts only"
        echo " -clusterfs : check for any clustered filesystems (Veritas/Gluster/GFS2)"
        echo " -fluks : just show any LUKS devices, no checks (Linux)"
        echo " -list FS : list all mounted filesystems matching 'FS' (eg. ext4, nfs, zfs)"
        echo " -readonlyfs : scan for any non-writable local/network filesystems"
        echo " +readonlyfs : more verbose scan for non-writable filesystems"
	echo "============= Misc. options ============="
	echo " -auth : determine user authentication for the system"
	echo " -chkurl URL : check reachability of a URL"
	echo " +chkurl URL : check reachability of a URL via proxy"
        echo " +db : show possible hosts with no Databases"
        echo " -db : show possible hosts with Databases (or DB library usage)"
	echo "       -/+db checks for usage of oracle/mysql/sybase/maria/mongo/postgresql"
	echo " -debracket FILE : debracket [] hostnames from Radssh output, send to stdout"
	echo " -deccom : run set of decommissioning tests and report findings"
	echo " -dns : detect any DNS settings in the ifcfg-* files (Linux)"
	echo " +dns : remove any DNS settings in the ifcfg-* files (Linux)"
	echo " -epoch [TIME] : convert epoch time in seconds to normal date"
	echo " -links FILE : follow and show all symlinks for an existing symlink"
	echo " -mfa USER : check if the user if getting blocked via MFA whitelisting"
        echo " -netprocs : print out processes listening on network ports (needs lsof)"
	echo " +netprocs : print out processes listening on network ports (netstat only)"
	echo " -shownet : show primary network info (Linux)"
	echo " -pexe PID: show the full path of the executable associated witha a PID"
	echo " -resolv : check the configuration of the /etc/resolv.conf file"
        echo " -running PROC : show number of 'PROCNAME' processes running, if any"
        echo " +running PROC : show any 'PROCNAME' processes that are running"
        echo " -vm : check if host is a virtual machine"
	echo "============= HW related options ============="
        echo " -baddisks : show inoperable disks in the RAID setup (Linux)"
        echo " +baddisks : show any inoperable/problematic disks in the RAID setup (Linux)"
	echo " -dimms : show memory slot configuration (Linux)"
	echo " -disks : show any local/SAN disks on the system (Linux)"
	echo " -foreign : show any disks with a foreign configuration (Linux)"
	echo " -hdscan : rescan for any drive changes (Linux)"
        echo " -hw : show Vendor and product information along with Memory and OS version"
	echo " -hwreport : display general hardware report (Linux)"
        echo " -idrac : print idrac network information if available (Linux)"
        echo " -nics : show info for any physical/virtual NICs that are active (Linux)"
        echo " +nics : show info for any physical/virtual NICs that could be active (Linux)"
	echo " -pdisks : show RAID physical disks (Linux)"
	echo " -raid : show brief summary of RAID devices (Linux)"
        echo " -readonlyfs : scan for any non-writable local/network filesystems"
        echo " +readonlyfs : more vebose scan for non-writable filesystems"
	echo " -sparedisks : list any Foreign, unconfigured, or hotspare disks (Linux)"
        echo " -vdisks : show RAID virtual disks (Linux)"
        echo " -vdrives : show RAID physical disks per virtual disk (Linux)"
	echo "============= satool.sh Internal options ============="
	echo " -new : check for satool updates via the Linuxcores"
	echo " +new : update satool via the Linuxcores"
        echo " -dup : check for duplicate host conflicts in host list (radssh/experimental)"
        echo " -cleanup : remove .snapshot files (generated via +R flag)"
        echo " +cleanup : remove .snapshot files and archived prepatch files"
        echo " -v : print the version information"
	echo " -debug : do not remove the temporary files"
	echo " +debug : keep temporary files and turn on shell tracing"
        echo " -? : same as -help"
        echo
        return 0
} #end of printusage

##########################################################
# All non-PREPDIR functions go above here ^^^
##########################################################

#MAIN handle for simple cases requiring no PREPDIR work
case $1 in
  -v)
	echo $VERSION
	exit 0
	;;
  -dup)
	checkdup
	exit $?
	;;
  -vcs)
	DOIT="0"
	checkvcs
	exit $?
	;;
  +vcs)
	DOIT="1"
	checkvcs
	exit $?
	;;
  -clusterfs)
	DOIT="2"
	checkvcs
	exit $?
	;;
  -pacem)
	check_pacemaker
	exit $?
	;;
  -verlock)
	DOIT="0"
	verlock
	exit $?
	;;
  +verlock)
	DOIT="1"
	verlock
	exit $?
	;;
  -dell)
	DOIT="0"
	dellopenman
	exit $?
	;;
  +dell)
	DOIT="1"
	dellopenman
	exit $?
	;;
  -tzdata)
        checktzdata
        exit $?
        ;;
  -gd)
        checkguard
        exit $?
        ;;
  -fluks)   #just show luks devices
	show_luks
	exit $?
	;;
  -uptime)
	checkuptime
	exit $?
	;;
  +uptime)
	UPT="1"
	checkuptime
	exit $?
	;;
  -decomm)
	decomm
	exit $?
	;;
  -os)
	checkosv
	exit $?
	;;
  -oss)
	OSCHK="sun"
	checkos
	exit $?
	;;
  -osl)
	OSCHK="lin"
	checkos
	exit $?
	;;
  -os5)
	OSCHK="lin5"
	checkos
	exit $?
	;;
  -os6)
	OSCHK="lin6"
	checkos
	exit $?
	;;
  -os7)
	OSCHK="lin7"
	checkos
	exit $?
	;;
  -os8) OSCHK="lin8"
	checkos
	exit $?
	;;
  -os56) #depreciated
	OSCHK="lin5"
	checkos
	RV=$?
	OSCHK="lin6"
	checkos
	if [ $? = 1 ]; then
		RV=1
	fi
	exit $RV
	;;
  -os67)
	OSCHK="lin6"
	checkos
	RV=$?
	OSCHK="lin7"
	checkos
	if [ $? = 1 ]; then
		RV=1
	fi
	exit $RV
	;;
  -os57)  #depreciated
	OSCHK="lin5"
	checkos
	RV=$?
	OSCHK="lin7"
	checkos
	if [ $? = 1 ]; then
		RV=1
	fi
	exit $RV
	;;
  -os678)
	OSCHK="lin"
	checkos
	exit $?
	;;
  -os78)
	OSCHK="lin7"
	checkos
	RV=$?
	OSCHK="lin8"
	checkos
	if [ $? = 1 ]; then
		RV=1
	fi
	exit $RV
	;;
  -osu)
	OSCHK="non"
	checkos
	exit $?
	;;
  -osn)
	OSCHK="non"
	checkos
	exit $?
	;;
  -zones)
	NOZ="0"
	checkzones
	exit $?
	;;
  -nozones)
	NOZ="1"
	checkzones
	exit $?
	;;
  -preboot)
	preboot_check
	exit $?
	;;
  +preboot)
	DOIT="1"
	preboot_check
	exit $?
	;;
  -apache)
	DOIT=""
	check_apache
	exit $?
	;;
  +apache)
	DOIT="(FIXED)"
	check_apache
	exit $?
	;;
  -grub)
	check_grub
	exit $?
	;;
  -lastup)
	lastupdate
	exit $?
	;;
  +lastup)
	DOIT="1"
	lastupdate
	exit $?
	;;
  -listup)  #legacy
	listupdates
	exit $?
	;;
  -enabled)
	ARG2=$2
	stat_repos
	exit $?
	;;
  -lnrepos)
	checkrepos
	exit $?
	;;
  -excl)
	check_exclude
	exit $?
	;;
  -astr)
	check_astr
	exit $?
	;;
  -links)
	follow_symlinks
	exit $?
	;;
  -pexe)
	check_pidexe
	exit $?
	;;
  -epoch)
	fixepoch
	exit $?
	;;
  -dns)
	DOIT="0"
	clean_dns
	exit $?
	;;
  +dns)
	DOIT="1"
	clean_dns
	exit $?
	;;
  -resolv)
	DOIT="1"
	check_resolv
	exit $?
	;;
  -cmpresolv)
	compare_resolv
	exit $?
	;;
  +cmpresolv)
	SUFF="snapshot"
	compare_resolv
	exit $?
	;;
  -shownet)
	show_networks
	exit $?
	;;
  -vm)
	check_vm
	exit $?
	;;
  -dimms)
	print_dimms
	exit $?
	;;
  -disks)
	print_disks
	exit $?
	;;
  -vdisks)
	list_vdisks
	exit $?
	;;
  -pdisks)
	list_pdisks
	exit $?
	;;
  -baddisks)
	list_baddisks
	exit $?
	;;
  +baddisks)
	DOIT="1"
	list_baddisks
	exit $?
	;;
  -sparedisks)
	list_unused_drives
	exit $?
	;;
  -foreign)
	foreigncfg
	exit $?
	;;
  -vdrives)
	display_vdrives
	exit $?
	;;
  +vdrives)
	DOIT="1"
	display_vdrives
	exit $?
	;;
  -raid)
	raid_status
	exit $?
	;;
  -nics)
	chknics
	exit $?
	;;
  +nics)
	DOIT="1"
	chknics
	exit $?
	;;
  -hdscan)
        rescan_drives
        exit $?
        ;;
  -hw)
	print_hwarch
	exit $?
	;;
  +db)
	DOIT="1"
	show_db
	exit $?
	;;
  -db)
	show_db
	exit $?
	;;
  -running)
	DOIT="0"
	ARGV="$2"
	show_procs
	exit $?
	;;
  +running)
	DOIT="1"
	ARGV="$2"
	show_procs
	exit $?
	;;
  -readonlyfs)
	readonly_chk
	exit $?
	;;
  +readonlyfs)
	DOIT="1"
	readonly_chk
	exit $?
	;;
  -debracket)
	debracket
	exit $?
	;;
  -idrac)
	print_idrac
	exit $?
	;;
  -mfa)
	check_mfa
	exit $?
	;;
  -auth)
	check_auth
	exit $?
	;;
  -chkurl)
	checkurl
	exit $?
	;;
  +chkurl)
	DOIT="1"
	checkurl
	exit $?
	;;
  -new)
	update_myself
	exit $?
	;;
  +new)
	DOIT="1"
	update_myself
	exit $?
	;;
  -newpt)  #legacy support, depreciated
	update_myself
	exit $?
	;;
  +newpt)  #legacy support, depreciated
	DOIT="1"
	update_myself
	exit $?
	;;
  -help)
	printusage
	printfullusage
	exit 0
	;;
  -\?)  #same as -help
	printusage
	printfullusage
	exit 0
	;;
  "")
	printusage
	exit 2
esac

##########################################################
# All non-PREPDIR functions go above here ^^^            #
##########################################################

##################################################
#Everything below VVV requires PREPDIR prep work #
##################################################

if [ ! -d $PREPDIR ]; then
        mkdir -p $PREPDIR  #create /root even on Solaris
        chgrp $SYSGRP $PREPDIR
        chmod 775 $PREPDIR
fi

#Link old to new location
if [ ! -h /var/tmp/prepatch ]; then
  if [ -d /var/tmp/prepatch ]; then
        mv /var/tmp/prepatch /var/tmp/prepatch.old
        ln -s /root/prepatch /var/tmp/prepatch
  fi
fi

PREP="$PREPDIR/mounts"  #output of mount (Linux)/mount -v|-p (Solaris)
CHPRE="$PREPDIR/checkmountdata.pre"      #blah.8
CHTAB="$PREPDIR/checkmountdata.tab"      #blah.9
CHPOST="$PREPDIR/checkmountdata.post"    #output of mounts [-vp]
TEMPER="$PREPDIR/checkmountdata.tmp"     #tmp of common premounts/fstab
TEMPER2="$PREPDIR/checkmountdata.tmp.2"  #uncommon previous and fstab
TEMPER3="$PREPDIR/checkmountdata.tmp.3"  #striped current
LOCK="$PREPDIR/satool.run"          #Lock file

#Check to see if two instances are running
#Create Lockfile
NAME=`uname -n`
if [ -f $LOCK ]; then
	PID=`cat $LOCK`
	kill -0 "$PID"
	if [ $? = 0 ]; then
		echo "WARNING: *** Another instance of $SCRIPTNAME running *** ($NAME)" >&2
		exit 255
	fi
	echo "WARNING: $SCRIPTNAME run/lock file found ($NAME) [removing]" >&2
	rm -f $LOCK
	#exit 255  #do not exit
   else
	echo $$ > $LOCK
fi

cleanup () {  #remove tmp and lock files
	rm -f $TEMPER $TEMPER2 $TEMPER3 $CHPRE $CHPOST $CHTAB $LOCK
	return
} #end of cleanup

#######################################################################

prepare () {  #Preliminary Prep work for prepatch related file work
 PREP="$PREP.$SUFF"
 if [ $FTAB = "/etc/vfstab" ]; then  #SUN
   mount -v | egrep '(ufs|xfs|nfs|vxfs)' | grep -v '/export/zones' | grep -v '^\/home\/' | awk '{print$3,"\t("$5")"}' | sort | uniq > $CHPOST
   grep -v '^#' $FTAB | egrep '(ufs|xfs|nfs|vxfs)' | grep -v '^\/home\/' | awk '{print$3,"\t("$4")"}' | sort | uniq > $CHTAB
   if [ -f $PREP ]; then 
	cat $PREP | egrep '(ufs|xfs|nfs|vxfs)' | grep -v '/export/zones' | awk '{print$3,"\t("$5")"}' | sort | uniq > $CHPRE
    else cat /dev/null > $CHPRE
   fi
else #Linux
   mount | egrep '(ext4| nfs |ext3|xfs|vxfs|ext2|btrfs|cifs|gfs2|glusterfs|ceph|vfat)' | awk '{print$3,"\t("$5")"}' | egrep -v '^\/home\/|.snapshot' | grep -v '^\/var\/lib\/docker' | sort | uniq > $CHPOST
   grep -v '^#' $FTAB | egrep '(ext4|ext3|nfs|cifs|btrfs|xfs|vxfs|glusterfs|gfs2|ceph|sshfs|ext2|vfat)' | awk '{print$2,"\t("$3")"}' | grep -v '^\/home\/' | grep -v '^\/var\/lib\/docker' | sort | uniq > $CHTAB
   if [ -f $PREP ]; then
	cat $PREP | egrep '(ext4| nfs |ext3|cifs| xfs|btrfs|vxfs|glusterfs|gfs2|sshfs|ceph|ext2|vfat)' | awk '{print$3,"\t("$5")"}' | egrep -v '^\/home\/|.snapshot' | grep -v '^\/var\/lib\/docker' | sort | uniq > $CHPRE
    else cat /dev/null > $CHPRE
   fi
 fi

  #Fix $CHPRE/CHPOST for fuse.crap
  NEWFILE="$PREPDIR/fuseprep.tmp"
  for i in $CHPRE $CHPOST; do cat $i | (
        cat /dev/null > $NEWFILE
        chmod 0644 $NEWFILE
        read A
        RC=$?
        while [ $RC = 0 ]; do
                GRP=""
                MOU=`echo $A | awk '{print$1}'`
                FST=`echo $A | awk '{print$2}'`
                GRP=`echo $A | awk '{print$2}' | grep 'fuse.'`
                if [ "$GRP" != "" ]; then  #got a FUSE FS
                        NFST=`echo $FST | awk -F. '{print$2}'`
                        FST=$NFST
			echo $ECF "${MOU} \t(${FST}" >> $NEWFILE
                else
			echo $ECF "${MOU} \t${FST}" >> $NEWFILE
		fi
                read A
                RC=$?
        done
     ) #end of cat $i subshell
     mv $NEWFILE $i
  done

  if [ -f $PREP ];then #filter diffs between premounts and fstab
	cat /dev/null > $TEMPER
	#while IFS="\n" read i; do
	while read i; do
		#while IFS="\n" read j;do
		while read j; do
			if [ "$i" = "$j" ]; then
				echo $i >> $TEMPER
			fi
		done < $CHTAB
	done < $CHPRE
	#$TEMPER now holds common premounts/fstab entries
  else
	cat /dev/null > $TEMPER
  fi
  cat $CHPRE $CHTAB | sort | uniq > $TEMPER3
  cat /dev/null > $TEMPER2
  #while IFS="\n" read i; do
  while read i; do
	XFLAG="0"
	#while IFS="\n" read j; do
	while read j; do
		if [ "$i" = "$j" ]; then XFLAG="1"
		fi
	done < $TEMPER
	if [ $XFLAG = "0" ]; then echo $i >> $TEMPER2
	fi
  done < $TEMPER3
  cat /dev/null > $TEMPER3  #reusing tmp.3
  #while IFS="\n" read i; do
  while read i; do
	XFLAG="0"
	#while IFS="\n" read j; do
	while read j; do
		if [ "$i" = "$j" ]; then XFLAG="1"
		fi
	done < $TEMPER2
	if [ $XFLAG = "0" ]; then echo $i >> $TEMPER3
	fi
  done < $CHPOST

} #end prepare

##############################
# PREPDIR required functions #
##############################

preserve () {  #archive prepatch files for refresh runs
	WHO=`whoami`
        if [ "$WHO" != "root" ]; then
                echo "WARNING: Root permissions required to refresh" >&2
                cleanup
                exit 2
        fi
	if [ -d $PREPDIR ]; then
		if [ ! -d $PREPDIR/old ]; then
			mkdir $PREPDIR/old
		fi
		if [ -f $PREPDIR/dmidecode.${SUFF} ]; then
			mv $PREPDIR/dmidecode.${SUFF} $PREPDIR/hardware.${SUFF}
		fi
		for i in date df dmesg fstab ifconfig kernelver mounts netports netprocs packages processes routes routes6 uptime vfstab vips memory hardware blockdevs services crypttab sysctl iptables zones exports resolv; do
		   for J in 5 4 3 2 1; do  #keep 5+1 runs of archives
			JP=`expr $J + 1`
			if [ -f $PREPDIR/old/${i}.${SUFF}.$J ]; then
				mv $PREPDIR/old/${i}.${SUFF}.$J $PREPDIR/old/${i}.${SUFF}.$JP
			fi
		   done
		   if [ -f $PREPDIR/${i}.${SUFF} ]; then
			mv $PREPDIR/${i}.${SUFF} $PREPDIR/old/${i}.${SUFF}.1
		   fi
		done
	fi
	return 0
}  #end of preserve

################ PREPDIR Functions ################

verify_luks () { #verify integrity of LUKS configuration: -luks/+luks
        if [ "$OSVER" = "SunOS" ]; then
                return 0  #Bye Solaris
        fi
        PROBFOUND=0;
        MDEVD=`blkid | grep LUKS | grep dev\/mapper | wc -l`
        if [ "$MDEVD" != "0" ]; then
                echo "LUKS /dev/mapper/* files found - LUKS on SAN?"
        fi
        #Are all blkid LUKS devs in crypttab?
        for i in `blkid | grep _LUKS | awk '{print$2}' | sort | uniq`; do
                NOTFOUND=1;
                for j in `cat /etc/crypttab | grep -v "^#" | awk '{print$2}'`; do
                        if [ "$j" = "$i" ]; then
                                NOTFOUND=0;
                        fi
                done
                if [ $NOTFOUND = 1 ]; then
                        echo "BLKID: $i not found in /etc/crypttab (unused?)"
                        PROBFOUND=1;
                fi
        done
        #Are all crypttab devs found in blkid?
        for j in `cat /etc/crypttab | grep -v "^#" | awk '{print$2}'`; do
                NOTFOUND=1;
                #check first against UUID
                for i in `blkid | grep _LUKS | awk '{print$2}'`; do
                        if [ "$j" = "$i" ]; then
                                NOTFOUND=0;
                        fi
                done
                if [ $NOTFOUND = 1 ]; then
                        NOTFOUND=1
                        #rerun against devname
                        for i in `blkid | grep _LUKS | awk '{print$1}' | awk -F: '{print$1}'`; do
                                if [ "$i" = "$j" ]; then
                                        NOTFOUND=0
                                        echo "CRYPTTAB Device: $i found instead of UUID - Please UUID instead"
                                fi
                        done
                        if [ $NOTFOUND = 1 ]; then
                                echo "CRYPTTAB: $j not found in LUKS block device list (old entry?)"
                        fi
                        PROBFOUND=1;  #true anyway if we reach here
                fi
        done
        #check keyfiles for crypttab devs
        for i in `cat /etc/crypttab | grep -v "^#" | awk '{print$3}'`; do
                if [ ! -f $i ]; then
                        echo "CRYPTTAB: $i key file is missing (Please FIX)"
                        PROBFOUND=1;
                else
                        KFF1=`ls -lad $i | cut -c 8`  #r
                        KFF2=`ls -lad $i | cut -c 9`  #w
                        KFF3=`ls -lad $i | cut -d ' ' -f 5`  #size
                        if [ "$KFF1" = "r" ]; then
                                echo "Keyfile: $i is world readable (please fix)"
                                PROBFOUND=1;
                        fi
                        if [ "$KFF2" = "w" ]; then
                                echo "Keyfile: $i is world writable (please fix)"
                                PROBFOUND=1;
                        fi
                        if [ "$KFF3" = "0" ]; then
                                echo "Keyfile: $i is empty"
                                PROBFOUND=1;
                        fi
                fi
        done
        #check for valid key in keyfile - converted from reilly's script
        #C5=`rpm -q centos-release | awk -F'-' '{print$3}'`
        C5=`grep " 5." /etc/redhat-release`
        if [ "$C5" != "" ]; then  #CentOS 5 hack
                echo "1m7HeLukE1" > /root/.ssh/tmpkey_
                for LDEV in `blkid | grep LUKS | awk -F: '{print$1}'`; do
                        KEY_SLOT=`cryptsetup luksDump $LDEV | grep 'Key Slot' | grep 'DISABLED' | head -n1 | awk -F' ' '{ print $3; }' | sed -e 's/://g'`
                        LDEVNM=`echo $LDEV | awk -F'/' '{ print $3; }'`
                        LUDEV=`blkid | grep LUKS | grep $LDEV | awk '{print$2}'`
                        LUUID=`blkid | grep LUKS | grep $LDEV | awk -F'"' '{print$2}'`
                        LKEYF=`cat /etc/crypttab | grep -v "^#" | grep $LUUID | awk '{print$3}'`
			if [ "$LKEYF" != "" ]; then
                           cryptsetup -d $LKEYF luksAddKey $LDEV /root/.ssh/tmpkey_ > /root/prepatch/lukschecks.out 2>&1
                           if [ $? -eq 2 ]; then
                                echo "KEYFILE: $LKEYF does not seem to match $LDEV"
                                PROBFOUND=1;
                           else
                                cryptsetup -d $LKEYF luksDelKey $LDEV $KEY_SLOT >> /root/prepatch/lukschecks.out 2>&1
                                if [ $? != 0 ]; then
                                        echo "Error removing test key for $LDEV"
                                        PROBFOUND=1;
                                fi
                           fi
			 else
				echo " key for $LUUID missing or commented out, skipping"
			fi
                done
                rm /root/.ssh/tmpkey_
                return $PROBFOUND
        fi
        #CentOS/RH 6,7 - check validity of key file
	echo "1m7HeLukE1" > /root/.ssh/tmpkey_
	cat /dev/null > $PREPDIR/luksIDs.tmp
	for i in `blkid | grep LUKS | awk -F': ' '{print$1}'`; do  #devname
			j=`blkid | grep $i | awk -F'"' '{print$2}'`
			echo "$i UUID=\"$j\"" >> $PREPDIR/luksIDs.tmp
	done
	#NOTE: LDEV can be a device or UUID, if a UUID, match to first device
	for LDEVC in `cat /etc/crypttab | grep -v "^#" | awk '{print$2}'`; do 
		LDEVUU=`grep $LDEVC $PREPDIR/luksIDs.tmp | awk '{print$2}'|head -1`  #pull UUID
		LDEVNM=`grep $LDEVC $PREPDIR/luksIDs.tmp | awk '{print$1}'|head -1`  #pull devname
		LKEYF=`cat /etc/crypttab | grep -v "^#" | grep $LDEVC | awk '{print$3}'` #pull keyfile
                #backup LUKS header
                if [ -d $PREPDIR/old ]; then
                        mv /root/prepatch/luks_header_backup_* $PREPDIR/old/ >/dev/null 2>&1
                fi
		LLDEVC=`echo $LDEVC | awk -F'/' '{print$NF}'` #pull last path
                HDRF=/root/prepatch/luks_header_backup_${LLDEVC}_`date +%Y%m%d%H%M%S`
                if [ "$LKEYF" != "" -a "$LDEVNM" != "" -a "$LDEVUU" != "" ]; then
			cryptsetup luksHeaderBackup $LDEVNM --header-backup-file $HDRF
if [ $DEBUG = 1 ]; then
	echo "DEBUG: testing KEYFILE:$LKEYF for UUID:$LDEVUU from DEV:$LDEVC ($LDEVNM)"
fi
                	cryptsetup -d $LKEYF --key-slot=7 luksAddKey $LDEVNM /root/.ssh/tmpkey_ > /root/prepatch/lukschecks.out 2>&1
                	if [ $? = 2 ]; then
                                echo "KEYFILE: $LKEYF does not seem to match $LDEVC"
                                PROBFOUND=2;
                	else
                                cryptsetup -d $LKEYF luksKillSlot $LDEVNM 7
                	fi
                else
                        echo "WARNING: Keyfile for $LDEVC not found in /etc/crypttab"
                fi
        done
	rm /root/.ssh/tmpkey_
	rm $PREPDIR/luksIDs.tmp
        return $PROBFOUND
}  #end of verify_luks

find_luks () {  #find LUKS volumes and do basic checks on them:  -fluks/+luks
        if [ "$OSVER" = "Linux" ]; then  #Linux
                LUKFL=""
                LUKFL=`for i in \`blkid | grep "LUKS" | awk '{print$1}'\`; do echo -n "$i  ";done`
                if [ "$LUKFL" = "" ]; then
                        if  [ -f /etc/crypttab ]; then
                                TMPGARB=`cat /etc/crypttab | grep -v dev\/mapper | grep -v "^#" | head -1`
                                if [ "$TMPGARB" != "" ]; then
                                        echo "non-empty /etc/crypttab found, but no LUKS devices detected"
                                        return 0  #not fatal
                                fi
                                #ignore if /etc/crypttab is empty
                        fi
                else  #LUKS device found
                        if  [ ! -f /etc/crypttab ]; then
                                echo "LUKS devices found (${LUKFL}), but no /etc/crypttab"
                                return 1
                        fi
                        TMPGARB=`cat /etc/crypttab | grep -v dev\/mapper | grep -v "^#" | head -1`
                        if [ "$TMPGARB" = "" ]; then
                                echo "LUKS devices found (${LUKFL}), but /etc/crypttab is empty"
                                return 0 #not fatal
                        fi
                        if [ "$QLUKS" = "" ]; then
                                echo "LUKS devices found: $LUKFL"
                        fi
                        #if still here, do additional luks checks
                        verify_luks
                        return $?
                fi
        fi
        return 0
}  #end of find_luks

defch () {  # -fc flag : compare fstab with current mounts
 RETV=0
 if [ $FTAB = "/etc/vfstab" ]; then  #SUN
   if [ $DFLAG = "-w" ]; then  #Sol8
	U=`diff $DFLAG $CHTAB $CHPOST | egrep '(^> /|^< /)'`
	if [ "$U" != "" ]; then
		RETV=1
		echo " <:only $FTYPE | >:mounted only"
		echo '================================'
		diff $DFLAG $CHTAB $CHPOST | egrep '(^> /|^< /)'
	fi
   else  #Sol 10
	U=`diff $DFLAG $CHTAB $CHPOST | egrep '(^\+/|^\-/)'`
	if [ "$U" != "" ]; then
		RETV=1
		echo " -:$FTYPE only | +:mounted only"
		echo '================================'
		diff $DFLAG $CHTAB $CHPOST | egrep '(^\+/|^\-/)'
	fi
   fi
 else  #Linux
   U=`diff $DFLAG $CHTAB $CHPOST | egrep '(^\+/|^\-/)'`
   if [ "$U" != "" ]; then
	RETV=1
	echo " -:$FTYPE only | +:mounted only"
	echo '================================'
	diff $DFLAG $CHTAB $CHPOST | egrep '(^\+/|^\-/)'
   fi
 fi
 return $RETV
} #end defch

postcur () { # -pc : compare previous mounts with current mounts
 RETV=0
 PREP="$PREPDIR/mounts.$SUFF"
 if [ ! -f $PREP ]; then
	echo "WARNING: no $PREP file found" >&2
	RETV=2
 fi
   if [ $DFLAG = "-w" ]; then  #Sol8
        U=`diff $DFLAG $CHPRE $CHPOST | egrep '(^> /|^< /)'`
        if [ "$U" != "" ]; then
		RETV=1
		if [ $VERBOSE = 1 ]; then
			echo "### -pc ###"
		fi
                echo ' <:prepatches | >:postpatches'
                echo '==============================='
                diff $DFLAG $CHPRE $CHPOST | egrep '(^> /|^< /)'
        fi
   else  #Sol 10/Linux
	if [ "$DOIT" = "1" ]; then  #report additions too
           U=`diff $DFLAG $CHPRE $CHPOST | egrep '(^\+/|^\-/)'`
           if [ "$U" != "" ]; then
		RETV=1
		if [ $VERBOSE = 1 ]; then
			echo "### -pc ###"
		fi
                echo ' -:prepatches | +:postpatches'
                echo '==============================='
                diff $DFLAG $CHPRE $CHPOST | egrep '(^\+/|^\-/)'
            fi
	else  #omit + results
	   U=`diff $DFLAG $CHPRE $CHPOST | egrep '^\-/'`
	   if [ "$U" != "" ]; then
		RETV=1
		if [ $VERBOSE = 1 ]; then
			echo "### -pc ###"
		fi
		echo " -:prepatches (showing missing)"
		echo '======================================'
		diff $DFLAG $CHPRE $CHPOST | egrep '^\-/'
	   fi
	fi  #end of doit
   fi
 return $RETV
} #end postcur

filtcomp () { #-pfc: compare previous mounts currently in v/fstab file to current
	RETV=0
	PREP="$PREPDIR/mounts.$SUFF"
	if [ ! -f $PREP ]; then
        	echo "WARNING: no $PREP file found"
		RETV=2
	fi
	if [ $DFLAG = "-w" ]; then  #Sol8	
		U=`diff $DFLAG $TEMPER $TEMPER3 | egrep '(^> /|^< /)'`
		if [ "$U" != "" ]; then
			if [ $VERBOSE = 1 ]; then
				echo "### -pfc ###"
			fi
			RETV=1
			echo " <:prepatches+$FTYPE | >:postpatches"
			echo '====================================='
			diff $DFLAG $TEMPER $TEMPER3 | egrep '(^> /|^< /)'
		fi
	else  #Linux/Sol10
		if [ "$DOIT" = "1" ]; then  #report additions too
		   U=`diff $DFLAG $TEMPER $TEMPER3 | egrep '(^\+/|^\-/)'`
		   if [ "$U" != "" ]; then
			RETV=1
			if [ $VERBOSE = 1 ]; then
                                echo "### -pfc ###"
                        fi
			echo " -:prepatches+$FTYPE | +:postpatches"
			echo '====================================='
			diff $DFLAG $TEMPER $TEMPER3 | egrep '(^\+/|^\-/)'
		   fi
		else #omit + results
		   U=`diff $DFLAG $TEMPER $TEMPER3 | egrep '^\-/'`
		   if [ "$U" != "" ]; then
			RETV=1
			if [ $VERBOSE = 1 ]; then
				echo "### -pfc ###"
			fi
			echo " -:prepatches+$FTYPE (showing missing)"
			echo '======================================'
			diff $DFLAG $TEMPER $TEMPER3 | egrep '^\-/'
		   fi
		fi  #end of doit
	fi
return $RETV
}  #end filtcomp

preonly () {  #-pf : compare only previous mounts with fstab
	RETV=0
	PREP="$PREPDIR/mounts.$SUFF"
	if [ ! -f $PREP ]; then
        	echo "WARNING: no $PREP file found" >&2
		RETV=2
	fi
	if [ "$DFLAG" = "-w" ]; then  #Sol8
		U=`diff $DFLAG $CHPRE $CHTAB | egrep '(^> /|^< /)'`
                if [ "$U" != "" ]; then
			RETV=1
                        echo " <:prepatches | >:$FTYPE"
                        echo '==================================='
                        diff $DFLAG $CHPRE $CHTAB | egrep '(^> /|^< /)'
                fi
        else #Linux/Sol10
                U=`diff $DFLAG $CHPRE $CHTAB | egrep '(^\+/|^\-/)'`
                if [ "$U" != "" ]; then
			RETV=1
                        echo " -:prepatches | +:$FTYPE"
                        echo '==================================='
                        diff $DFLAG $CHPRE $CHTAB | egrep '(^\+/|^\-/)'
                fi
        fi
return $RETV
} #end preonly

printprev () {  #print previous mounts: -p
	if [ ! -f $PREP ]; then
		echo "WARNING: no $PREP file found" >&2
		return 2
	fi
	cat $CHPRE
	return 0
}  #end printprev

genvips () {  #generate vips.prepatch/snapshot: +R/-r/+vips
	if [ "$OSVER" = "Linux" ]; then
		ip addr | (
                WINF=""
                read A
                RC=$?
                while [ $RC = 0 ]; do
                   UOUT=`echo $A | grep mtu`
                   if [ "$UOUT" != "" ]; then
                        #get interface
                        UOUT=`echo $A | grep LOWER_UP | awk '{print$2}'`
                        if [ "$UOUT" != "" ]; then
                                WINF=$UOUT
                         else
                                WINF=""
                        fi
                        read A  #go to the next line as we read a inf line
                        RC=$?
                   fi
                   if [ "$WINF" != "" ]; then
                        if [ $RC = 0 ]; then
                                UOUT=`echo $A | grep inet | egrep '(global|host)' | grep -v "::1/128"`
                                if [ "$UOUT" != "" ]; then
                                        UOUT2=`echo $UOUT | grep global`
                                        if [ "$UOUT2" != "" ]; then
                                                TYP="global"
                                         else
                                                TYP="host"
                                        fi
                                        F1=`echo $A | awk '{print$2}' | awk -F/ '{print$1}'`
                                        F2=`echo $A | awk '{print$NF}'`
                                        INF=$WINF
                                        IPT=$F1
                                        echo "$INF  $IPT  ($TYP)"
                                fi
                        fi
                   fi
                   read A
                   RC=$?
                done
         ) | sort > $VIPFILE
	else  #Sun-Solaris
		for i in `netstat -in | awk '{print$1'} | grep -v Name`; do
                        for j in `ifconfig -a | grep "^$i" | awk '{print$1}'`; do
                                F0=$i
                                F1=`echo $j | awk -F: '{print$2}'`
                                if [ "$F1" != "" ];  then
                                        FF="$F0:$F1"
                                        FFF="$F0:"
                                else
                                        FF="$F0"
                                        FFF=$FF
                                fi
                                NJJ=`ifconfig $FF | grep 'inet ' | awk  '{print$2}'`
                                echo "$FFF  $NJJ"
                        done
                done | sort | uniq > $VIPFILE
        fi
	return 0
}  #end of genvips

refreshpre () {  #generate new prepatch/snapshot files: +r/+R
	WHO=`whoami`
	if [ "$WHO" != "root" ]; then
		echo "WARNING: Root permissions required to refresh" >&2
		cleanup
		exit 2
	fi
	#Linux+Sun
	PREP="$PREPDIR/mounts.$SUFF"
	VIPFILE="$PREPDIR/vips.$SUFF"
	genvips
	date > $PREPDIR/date.$SUFF
	uptime > $PREPDIR/uptime.$SUFF
	netstat -rn | grep -v "169\.254\." > $PREPDIR/routes.$SUFF
	mount -v > $PREP
	echo "========ifconfig -a========" > $PREPDIR/ifconfig.$SUFF
	ifconfig -a >> $PREPDIR/ifconfig.$SUFF
	df -k > $PREPDIR/df.$SUFF &  #df can hang on hozed FSes
	echo "========netstat -in========" >> $PREPDIR/ifconfig.$SUFF
	netstat -in >> $PREPDIR/ifconfig.$SUFF
	ps -ef | head -1 > $PREPDIR/processes.$SUFF
	ps -ef | grep -v sshd | grep -v "\[" | grep -vi tty |sort -k 8 >> $PREPDIR/processes.$SUFF
	echo >> $PREPDIR/processes.$SUFF
	echo "ps -ef" >> $PREPDIR/processes.$SUFF
	echo "===================================================================" >> $PREPDIR/processes.$SUFF
	echo "ps auxw" >> $PREPDIR/processes.$SUFF
	echo >> $PREPDIR/processes.$SUFF
	netstat -an | head -2 > $PREPDIR/netports.$SUFF
	netstat -an | egrep 'LISTEN|ESTABLISH' | grep -v unix >> $PREPDIR/netports.$SUFF
	cp /etc/resolv.conf $PREPDIR/resolv.$SUFF
	#
	if [ "$OSVER" = "SunOS" ]; then  #Solaris specific
		uname -v > $PREPDIR/kernelver.$SUFF
		cp /etc/vfstab $PREPDIR/vfstab.$SUFF
		/usr/ucb/ps auxw | grep -v ssh >> $PREPDIR/processes.$SUFF
		if [ -x /usr/local/bin/top ]; then
			top -n 1 | grep "^Mem" > $PREPDIR/memory.$SUFF
		else
			SOLMEM=`echo "::memstat" | mdb -k | grep "^Total" | awk '{print$3}'`
			echo "Memory: $SOLMEM" > $PREPDIR/memory.$SUFF
		fi
		if [ -x /usr/sbin/zoneadm ]; then
			zoneadm list -cv > $PREPDIR/zones.$SUFF
		fi
		#add any Solaris blockdevice data
		if [ -x /usr/sbin/cfgadm ]; then
			echo "========cfgadm========" > $PREPDIR/blockdevs.$SUFF
			cfgadm -al >> $PREPDIR/blockdevs.$SUFF 2>&1
		fi
		if [ -x /sbin/metastat ]; then
			echo "=======metastat=======" >> $PREPDIR/blockdevs.$SUFF
			metastat -a >> $PREPDIR/blockdevs.$SUFF 2>&1
		fi
		if [ -x /sbin/zfs ]; then
			echo "=======zfs list=======" >> $PREPDIR/blockdevs.$SUFF
			zfs list >> $PREPDIR/blockdevs.$SUFF 2>&1
		fi
		if [ -x /sbin/zpool ]; then
			echo "=======zpool status=======" >> $PREPDIR/blockdevs.$SUFF
			zpool status >> $PREPDIR/blockdevs.$SUFF 2>&1
		fi
		echo  "========format========" >> $PREPDIR/blockdevs.$SUFF
		/usr/sbin/format < /dev/null >> $PREPDIR/blockdevs.$SUFF 2>&1 &  #format can take a while
		if [ -x /usr/sbin/prtdiag ]; then
			prtdiag -v > $PREPDIR/hardware.$SUFF 2>&1 &  #can take a while
		fi
		if [ -x /usr/bin/svcs ]; then  #skip Sol8
			svcs -a > $PREPDIR/services.$SUFF 2>&1
		fi
		if [ -x /usr/local/bin/lsof ]; then
			gen_netprocs_sol
		 else
                        echo "No lsof installed" > $PREPDIR/netprocs.$SUFF
		fi
	else #Linux specific
		echo "=============ip addr============" >> $PREPDIR/ifconfig.$SUFF
		ip addr >> $PREPDIR/ifconfig.$SUFF
		if [ -f /proc/net/ipv6_route ]; then #if missing, no ipv6
			netstat -rn --inet6 > $PREPDIR/routes6.$SUFF
		fi
		if [ -f /etc/crypttab ];  then
			cp /etc/crypttab $PREPDIR/crypttab.$SUFF
		fi
		ps auxw | grep -v ssh >> $PREPDIR/processes.$SUFF
		dmesg > $PREPDIR/dmesg.$SUFF
		uname -r > $PREPDIR/kernelver.$SUFF
		cat /dev/null > $PREPDIR/netprocs.$SUFF
		if [ -f /var/log/yum.log -o -x /bin/rpm ]; then
			rpm -qa | sort > $PREPDIR/packages.$SUFF
		else 
			dpkg -l | sort > $PREPDIR/packages.$SUFF
		fi
		cp /etc/fstab $PREPDIR/fstab.$SUFF
		if [ -x /sbin/lspci ]; then
			echo "========lspci========" > $PREPDIR/hardware.$SUFF
			lspci >> $PREPDIR/hardware.$SUFF
		else
			cat /dev/null > $PREPDIR/hardware.$SUFF
		fi
		echo "=======dmidecode=======" >> $PREPDIR/hardware.$SUFF
		dmidecode >> $PREPDIR/hardware.$SUFF
		free -mt > $PREPDIR/memory.$SUFF
		echo "=======chkconfig=======" > $PREPDIR/services.$SUFF
		chkconfig --list >> $PREPDIR/services.$SUFF 2>&1
		if [ -x /usr/bin/systemctl ]; then
			echo "=======systemctl=======" >> $PREPDIR/services.$SUFF
			systemctl >> $PREPDIR/services.$SUFF
			echo "=======systemctl list-unit-files=======" >> $PREPDIR/services.$SUFF
			systemctl list-unit-files >> $PREPDIR/services.$SUFF
		fi
		#
		if [ -x /usr/sbin/lsof -o -x /usr/bin/lsof ]; then
			gen_netprocs_lin
		else
			echo "No lsof installed" > $PREPDIR/netprocs.$SUFF
			netstat -pna | head -1 >> $PREPDIR/netprocs.$SUFF
			netstat -pna | grep LISTEN | grep -v unix >> $PREPDIR/netprocs.$SUFF
		fi
		echo "========blkid========" > $PREPDIR/blockdevs.$SUFF
		blkid >> $PREPDIR/blockdevs.$SUFF
		echo >> $PREPDIR/blockdevs.$SUFF
		if [ -x /sbin/multipath -o -x /usr/sbin/multipath ]; then
			echo "======multipath -ll=======" >> $PREPDIR/blockdevs.$SUFF
			multipath -ll >> $PREPDIR/blockdevs.$SUFF 2>&1
			echo >> $PREPDIR/blockdevs.$SUFF
		fi
		if [ -x /sbin/dmsetup -o -x /usr/sbin/dmsetup ]; then
			echo "=======dmsetup info========" >> $PREPDIR/blockdevs.$SUFF
			dmsetup info >> $PREPDIR/blockdevs.$SUFF
		fi
                if [ -x /usr/bin/lsscsi ]; then
                        echo "========lsscsi========" >> $PREPDIR/blockdevs.$SUFF
                        lsscsi >> $PREPDIR/blockdevs.$SUFF 2>&1
			echo >> $PREPDIR/blockdevs.$SUFF
                fi
		if [ -x /sbin/pvscan -o -x /usr/sbin/pvscan ]; then
			pvscan > /dev/null 2>&1   #cleanup before pvs
		fi
		if [ -x /sbin/pvs -o -x /usr/sbin/pvs ]; then
			echo "=========pvs==========" >> $PREPDIR/blockdevs.$SUFF
			pvs >> $PREPDIR/blockdevs.$SUFF #2>&1 #let errors go to stderr
			echo >> $PREPDIR/blockdevs.$SUFF
		fi
		if [ -x /sbin/pvdisplay -o -x /usr/sbin/pvdisplay ]; then
			echo "======pvdisplay=======" >> $PREPDIR/blockdevs.$SUFF
			pvdisplay >> $PREPDIR/blockdevs.$SUFF 2>&1

		fi
		if [ -x /sbin/vgdisplay -o -x /usr/sbin/vgdisplay ]; then
			echo "======vgdisplay=======" >> $PREPDIR/blockdevs.$SUFF
			vgdisplay >> $PREPDIR/blockdevs.$SUFF 2>&1
		fi
		if [ -x /sbin/lvdisplay -o -x /usr/sbin/lvdisplay ]; then
			echo "======lvdisplay=======" >> $PREPDIR/blockdevs.$SUFF
			lvdisplay >> $PREPDIR/blockdevs.$SUFF 2>&1
		fi
		if [ -x /bin/lsblk -o -x /usr/sbin/lsblk ]; then
			echo "========lsblk -o +uuid=========" >> $PREPDIR/blockdevs.$SUFF
			lsblk -o +uuid >> $PREPDIR/blockdevs.$SUFF 2>&1
			echo >> $PREPDIR/blockdevs.$SUFF
		fi
		if [ -x /bin/findmnt -o -x /usr/bin/findmnt ]; then
			echo "=======findmnt========" >> $PREPDIR/blockdevs.$SUFF
			findmnt >> $PREPDIR/blockdevs.$SUFF 2>&1
			echo >> $PREPDIR/blockdevs.$SUFF
		fi
		echo "========fdisk -l========" >> $PREPDIR/blockdevs.$SUFF
		fdisk -l >> $PREPDIR/blockdevs.$SUFF 2>&1
		sysctl -a 2>&1 | sort > $PREPDIR/sysctl.$SUFF
		iptables -n -L > $PREPDIR/iptables.$SUFF 2>&1
		if [ -x /usr/bin/virsh ]; then
			UU=`ps -ef | grep qemu | grep -v grep`
			if [ "$UU" != "" ]; then
				virsh list --all > $PREPDIR/zones.$SUFF
			fi
		fi
		if [ -x /usr/sbin/showmount ]; then
			showmount -a > $PREPDIR/exports.$SUFF 2>/dev/null
		fi
	fi
	return 0
} #end refreshpre

gen_netprocs_lin () {	#generate list of processes listening on
			# network ports: +r/+R
	PIDD="$PREPDIR/ports.$$"
	cat /dev/null > $PIDD
	cat /dev/null > $PREPDIR/netprocs.$SUFF

	if [ -x /usr/sbin/lsof -o -x /usr/bin/lsof ]; then
		for i in `netstat -an | grep LISTEN | grep -v unix | grep -v ::: | awk '{print$4}'`; do
			echo $i | awk -F: '{print$2"?["$1"]"}' >> $PIDD
		done
		for i in `netstat -an | grep LISTEN | grep -v unix | grep ::: | awk '{print$4}'`; do
			echo $i | awk -F: '{print$NF"?[:::]"}' >> $PIDD
		done
		mv ${PIDD} ${PIDD}_
		sort -n < ${PIDD}_ > ${PIDD}
		for i in `cat ${PIDD}`; do echo "============================" >> $PREPDIR/netprocs.$SUFF
			echo $i | awk -F? '{print"PORT "$2" "$1}' >> $PREPDIR/netprocs.$SUFF
			echo >> $PREPDIR/netprocs.$SUFF
			PORTT=`echo $i | awk -F? '{print$1}'`
			#if [ "$OSV" = "7" -o "$OSV" = "8" ]; then
			   #preliminary code for using netstat instead of lsof
			   #if [ "$DOIT" = "1" ]; then  #what does this do?
				#netstat -anp | grep LISTEN | grep -v unix | grep ":${PORTT}" >> $PREPDIR/netprocs.$SUFF
				#CMDD=`echo $NPORT | awk -F/ '{print$2}'`
				#CPID=`echo $NPORT | awk -F/ '{print$1}'`
			   #fi
			#else
				lsof -ni :$PORTT | egrep 'DEVICE|LISTEN' >> $PREPDIR/netprocs.$SUFF
			#fi
		done
		#echo "DEBUG: $PIDD ${PIDD}_"
#FIXOR		rm -f $PIDD ${PIDD}_
	 else
		echo "No lsof installed" >> $PREPDIR/netprocs.$SUFF
		return 1
	fi
	return 0
} #end of gen_netprocs_lin

gen_netprocs_sol () {	#generate list of processes listening on
                        # network ports: +r/+R
	PIDD="$PREPDIR/ports.$$"
	cat /dev/null > $PIDD
	cat /dev/null > $PREPDIR/netprocs.$SUFF

	if [ -x /usr/local/bin/lsof ]; then
		for i in `netstat -an | grep LISTEN | grep -v unix | grep -v ::: | awk '{print$1}'`; do
			TPT=`echo $i | awk -F. '{print$NF}'`
			TVV=`echo $i | awk -F. '{print$1}'`
			if [ "$TVV" != "*" ]; then
				TVV=`echo $i | awk -F. '{print$1"."$2"."$3"."$4}'`
			 else
				TVV="0.0.0.0"
			fi
			echo "$TPT:$TVV" >> $PIDD
		done
		mv $PIDD ${PIDD}_
		sort -n < ${PIDD}_ > $PIDD
		for i in `cat $PIDD`; do
			TVV=`echo $i | awk -F: '{print$2}'`
			TPT=`echo $i | awk -F: '{print$1}'`
			echo "============================" >> $PREPDIR/netprocs.$SUFF
			echo "PORT [$TVV] $TPT" >> $PREPDIR/netprocs.$SUFF
			echo >> $PREPDIR/netprocs.$SUFF
			lsof -ni :$TPT | egrep 'DEVICE|LISTEN' >> $PREPDIR/netprocs.$SUFF
		done
		rm -f $PIDD ${PIDD}_
	 else
		echo "No lsof installed" >> $PREPDIR/netprocs.$SUFF
		return 1
	fi
	return 0
} #end of gen_netprocs_sol

print_netprocs () {  #-netprocs
	WHOAMI=`whoami`
	if [ "$WHOAMI" != "root" ]; then
		echo "WARNING: needs root priviledges to work properly"
	fi
	SUFF=tmp_
	if [ "$OSVER" = "SunOS" ]; then  #Solaris
		gen_netprocs_sol
		RV=$?
	 else
		gen_netprocs_lin
		RV=$?
	fi
	cat $PREPDIR/netprocs.$SUFF
	rm $PREPDIR/netprocs.$SUFF
	echo
	return $RV
}  #end of print_netprocs

check_ntp () {  #+ntp/-ntp
	if [ "$OSVER" = "SunOS" ]; then
		return 0  #we don't check Solaris
	fi
	RV=0
	UU=`ps -ef | grep "/usr/sbin/ntpd" | grep -v grep`
	if [ "$UU" != "" ]; then
		return 0 #ntpd running
	fi
	if [ "$OSV" = "8" ]; then #may add 7 later
		#first check if conf is good
		NTPCONF="/etc/chrony.conf"
		NEWCONF=0
		UUU=`grep ^server $NTPCONF | egrep -i 'time..risk.regn.net|10.193.24.11|10.193.24.12|p-ad01.ukrisk.net|p-ad02.ukrisk.net|10.224.152.1|10.224.152.2|172.25.255.210|172.25.255.211|10.121.146.70|10.121.146.71'`
		if [ "$UUU" = "" ]; then #fix chrony.conf
		   if [ "$DOIT" != "1" ]; then
			echo "LN NTP servers not in chrony.conf"
			return 1  #nothing further to do, return
		   fi
		   #Fix chrony.conf, we assume chronyd is installed already
		   RV=2
		   cat $NTPCONF | (
				cat /dev/null > ${NTPCONF}_new
				chmod 0644 ${NTPCONF}_new
				MF=0
				read A
				RC=$?
				while [ $RC = 0 ]; do
				   F1=`echo $A | awk '{print$1}'`
				   F2=`echo $A | awk '{print$2}'`
				   F3=`echo $A | awk '{print$3}'`
				   if [ "$F1" = "server" ]; then
					if [ $MF != 1 ]; then
						#Add time servers
						echo "server time0.risk.regn.net $F3" >> ${NTPCONF}_new
                                                echo "server time1.risk.regn.net $F3" >> ${NTPCONF}_new
                                                echo "server time2.risk.regn.net $F3" >> ${NTPCONF}_new
                                                echo "server time3.risk.regn.net $F3" >> ${NTPCONF}_new
                                                MF=1 #ignore further server lines
					fi
				   else  #not a server line
					echo "$A" >> ${NTPCONF}_new
				   fi
				   read A
				   RC=$?
				done
			 )
		   #install new chrony.conf
		   NEWCONF=1
		   cp $NTPCONF ${NTPCONF}.old
                   mv ${NTPCONF}_new $NTPCONF
                   echo "LN NTP servers not in $NTPCONF (FIXED)"
		fi #end check if chrony.conf good and fix
		#check if chrony is running
		UU=`ps -ef | grep chronyd | grep -v grep`
		if [ "$UU" = "" ]; then #chronyd not running,
			if [ $DOIT != "1" ]; then
				echo "chronyd not running"
				return 1
			fi
			#not running, enable and start
			echo "Enabling and/or starting chronyd"
                        systemctl enable chronyd
                        systemctl start chronyd
                        return $?
		 else #is running
			if [ $NEWCONF -eq 1 ]; then #restart with new conf
				systemctl restart chronyd
				return 1
			fi
		fi
		return 0 #if we get here, all good
	fi #RH/Cento8

	#assume RH/Centos 5/6/7 at this point with ntpd default
	if [ ! -f /etc/ntp.conf ]; then
		echo "NTPD not installed or conf file missing"
		if [ "$DOIT" = "1" -a -x /usr/bin/yum ]; then
			echo "Installing ntpd..."
			yum -y install ntp
			if [ $? != 0 ]; then
				echo "Failed"
				return 2
			fi
		else
			return 1  #can't continue
		fi
	fi
	#check if ntp.conf is sane
	UU=`grep ^server /etc/ntp.conf | egrep -i 'risk.regn.net|10.193.24.11|10.193.24.12|p-ad01.ukrisk.net|p-ad02.ukrisk.net|10.224.152.1|10.224.152.2'`
	if [ "$UU" = "" ]; then
		RV=2
		if [ "$DOIT" = "1" ]; then  #standardize ntp.conf - US servers only!!!
			cat /etc/ntp.conf | (
				cat /dev/null > /etc/ntp.conf_new
				chmod 0644 /etc/ntp.conf_new
				MF=0
				read A
				RC=$?
				while [ $RC = 0 ]; do
					F1=`echo $A | awk '{print$1}'`
					F2=`echo $A | awk '{print$2}'`
					F3=`echo $A | awk '{print$3}'`
					if [ "$F1" = "server" ]; then
						if [ $MF != 1 ]; then
					 		#Add servers
							echo "server time0.risk.regn.net $F3" >> /etc/ntp.conf_new
							echo "server time1.risk.regn.net $F3" >> /etc/ntp.conf_new
							echo "server time2.risk.regn.net $F3" >> /etc/ntp.conf_new
							echo "server time3.risk.regn.net $F3" >> /etc/ntp.conf_new
							MF=1 #ignore further server lines
						fi
					else #not a server line
						echo "$A" >> /etc/ntp.conf_new
					fi
					read A
					RC=$?
				done
			)
			cp /etc/ntp.conf /etc/ntp.conf.old
			mv /etc/ntp.conf_new /etc/ntp.conf
			echo "LN NTP servers not in ntp.conf (FIXED)"
		else
			echo "LN NTP servers not in ntp.conf"
			return $RV
		fi #end if DOIT
	fi  #end of grep for LN NTP servers in ntp.conf
	#check for chronyd running, should only get here for Centos 6/7
	UU=`ps -ef | grep -v grep | grep chronyd`
	if [ "$UU" != "" ]; then 
		if [ "$DOIT" = "1" ]; then  #change back to 1 FIXME
			systemctl stop chronyd
			systemctl disable chronyd
			echo "chronyd running (attempting to stop and disable)"
		else
			echo "chronyd running"
			return 3
		fi
	fi
	UU=`ps -ef | grep -v grep | grep chronyd`
	if [ "$UU" != "" ]; then #if errors, abort any further checks
		echo "chronyd failed to stop"
		return 3
	fi
	#is ntpd installed/running
	UU=`ps -ef | grep -v grep | grep "ntpd -u"`
	if [ "$UU" = "" ]; then  #no ntpd running, check why
        	if [ ! -x /usr/sbin/ntpd -a ! -x/sbin/ntpd ]; then
			echo "NTPD still not installed, aborting"
			return 1
		fi
		#else its installed, but not running
		echo "ntpd not running"
		if [ "$DOIT" = "1" ]; then
		   date
		   UUN=`date`
		   echo "(attempting to sync before starting)"
		   UUN=`ntpdate time0.risk.regn.net 2>&1`
                   RV=$?
                   if [ $RV != 0 ]; then  #time0 failed, try time3
                        UUN=`ntpdate time3.risk.regn.net 2>&1`
                        RV=$?
                   fi
                   if [ $RV != 0 ]; then
			echo "WARNING: No reachable NTP servers"
		   fi
		   #if time synced, enable and start service
		   echo "enabling (if disabled) and starting"
		   if [ -x /usr/bin/systemctl ]; then #C/RH7
			systemctl enable ntpd
			systemctl start ntpd
		   else  #C/RH56
			chkconfig ntpd on
			service ntpd start
		   fi
		   UU=`ps -ef | grep -v grep | grep "ntpd -u"`
		   if [ "$UU" = "" ]; then
			echo "ntpd failed to start"
			return 8
		   else
			echo "ntpd now running"
			date
		   fi
		fi  #end if DOIT
	fi
	return 0
}  #end of check_ntp

cmpservices () { #-cmpsvcs
	WHO=`whoami`
	if [ "$WHO" != "root" ]; then
		echo "WARNING: need to be root for proper services checking"
		return 1
	fi
	TMPSVF="$PREPDIR/services.tmp"
	if [ ! -f $PREPDIR/services.$SUFF ]; then
		echo "WARNING, no $PREPDIR/services.$SUFF file found"
		return 1
	fi
	if [ "$OSVER" = "SunOS" ]; then
		if [ "$OSV" != "5.10" ]; then
			return 0  #cannot check Solaris 8/9
		fi
		svcs -a | grep -v STIME | awk '{print$3,$1}' | sort > ${TMPSVF}.2
		cat $PREPDIR/services.$SUFF | grep -v STIME | awk '{print$3,$1}' | sort > ${TMPSVF}.1
		UUU=`diff -u ${TMPSVF}.1 ${TMPSVF}.2`
		if [ "$UUU" = "No differences encountered" ]; then
			rm ${TMPSVF}.1 ${TMPSVF}.2
			return 0
		fi
	fi
	if [ "$OSVER" = "Linux" ]; then
		if [ "$OSV" = "5" -o "$OSV" = "6" ]; then
			chkconfig --list | sort > ${TMPSVF}.2
			cat $PREPDIR/services.$SUFF | grep -v "===" | sort > ${TMPSVF}.1
		fi
		if [ "$OSV" = "7" -o "$OSV" = "8" ]; then
			systemctl list-unit-files | grep -iv "UNIT FILE" | sort | awk '{print$1,$2}' > ${TMPSVF}.2
			#cat $PREPDIR/services.$SUFF | grep -iv "UNIT FILE" | grep -v "===" | sort > ${TMPSVF}.1
			cat $PREPDIR/services.$SUFF | (
				SERFLAG=0
				read A
				RC=$?
				while [ $RC = 0 ]; do
					if [ "$A" = "=======systemctl list-unit-files=======" ]; then
						SERFLAG=1
						read A
						RC=$?
					fi
					if [ $SERFLAG = 1 ]; then
						echo $A | grep -iv "UNIT FILE" |awk '{print$1,$2}'
					fi
					read A
					RC=$?
				done
			) | sort > ${TMPSVF}.1
		fi
		UUU=`diff -u ${TMPSVF}.1 ${TMPSVF}.2`
		if [ "$UUU" = "" ]; then  #no diff
			rm ${TMPSVF}.1 ${TMPSVF}.2
			return 0
		fi
	fi
	diff -u ${TMPSVF}.1 ${TMPSVF}.2 | egrep '^\-|^\+' | grep -v "^+++" | grep -v "^---"
	rm ${TMPSVF}.1 ${TMPSVF}.2
	return 1
}  #end of cmpservices

comparesysctl () {  #-cmpsys
	if [ "$OSVER" = "SunOS" ]; then  #Solaris
		return 0
	fi
	if [ ! -f $PREPDIR/sysctl.$SUFF ]; then
		echo "$PREPDIR/sysctl.$SUFF not available"
		return 1
	fi
	sysctl -a | sort > $PREPDIR/sysctl.tmp
	UU=`diff -u $PREPDIR/sysctl.$SUFF $PREPDIR/sysctl.tmp`
	diff -u $PREPDIR/sysctl.$SUFF $PREPDIR/sysctl.tmp
	rm -f $PREPDIR/sysctl.tmp
	if [ "$UU" != "" ]; then
		return 1
	fi
	return 0
}  #end of cmpsys

cmpexports () { #-exports
        if [ "$OSVER" = "SunOS" ]; then  #Solaris
                return 0
        fi
	if [ ! -f $PREPDIR/exports.$SUFF ]; then
		echo "$PREPDIR/exports.$SUFF not available"
		return 1
	fi
	if [ ! -x /usr/sbin/showmount ]; then
		echo "no showmounts installed"
		return 1
	fi
	showmount -a 2>/dev/null | sort > $PREPDIR/exports.tmp
	sort < $PREPDIR/exports.$SUFF > $PREPDIR/exports.tmp_
	diff -u $PREPDIR/exports.tmp_ $PREPDIR/exports.tmp
	RV=$?
	rm -f $PREPDIR/exports.tmp_ $PREPDIR/exports.tmp
	return $RV
} #end of cmpexports

checkvar () {  #-varfs
	RETV=0
        if [ "$OSVER" = "SunOS" ]; then  #Solaris
                FSP=`df -k /var | tail -1 | awk '{print$4}'`
                if [ $FSP -lt $VARSIZE ]; then  #1GB
                        RETV=1
                        echo "only $FSP K free on /var"
                fi
        else  #Linux
                FSP=`df -kP /var | tail -1 | awk '{print$4}'`
                if [ $FSP -lt $VARSIZE ]; then  #320MB
                        RETV=1
                        echo "only $FSP K free on /var"
                fi
        fi
        return $RETV
}  #end checkvar

checkroot () {  #-rootfs
	RETV=0
	if [ "$OSVER" = "SunOS" ]; then  #Solaris
                FSP=`df -k / | tail -1 | awk '{print$4}'`
        else  #Linux
                FSP=`df -kP / | tail -1 | awk '{print$4}'`
        fi
        if [ $FSP -lt 524288 ]; then  #512MB
		RETV=1
                echo "only $FSP K free on /"
        fi
        return $RETV
}  #end checkroot

checkboot () {  #-bootfs
	RETV=0
	if [ "$OSVER" = "Linux" ]; then  #Linux only
		FSP=`df -kP /boot | tail -1 | awk '{print$4}'`
		BCK=`expr $BOOTSIZE \* 1024`
		if [ $FSP -lt $BCK ]; then
			RETV=1
			echo "only $FSP K free on /boot"
		fi
	fi
	return $RETV
}  #end checkboot

cleanbootfs () {  #+bootfs/++bootfs
	RETV=0
	if [ "$OSVER" = "Linux" ]; then  #Linux only
		FSP=`df -kP /boot | tail -1 | awk '{print$4}'`
		BCK=`expr $BOOTSIZE \* 1024`
		if [ $FSP -lt $BCK -o "$FORCE" = "1" ]; then
			RETV=1
			echo "$FSP K free on /boot, running cleanup"
			if [ -x /usr/bin/package-cleanup ]; then
				package-cleanup -y --oldkernels --count=2
				if [ $? != 0 ]; then
					RETV=2
				fi
			else
				echo "package-cleanup not installed"
			fi
		fi
	fi
	return $RETV
}  #end of cleanbootfs

checkusr () {  #-usrfs
	RETV=0
	if [ "$OSVER" = "Linux" ]; then  #Linux only
		FSP=`df -kP /usr | tail -1 | awk '{print$4}'`
		if [ $FSP -lt 131072 ]; then  #128MB
			RETV=1
			echo "only $FSP K free on /usr"
		fi
	fi
	return $RETV
} # end checkusr

checkkern () {  #Linux only - check to see if running latest installed kernel:
		# -kern
	if [ "$OSVER" = "SunOS" ]; then   #skip Solaris
		return 0
	fi
	if [ ! -f /var/log/yum.log ]; then
		return 0  #unbuntu?
	fi
	CKMV=`uname -r | awk -F".x86_64" '{print$1}' | awk -F".el" '{print$1}'`
	LKMV=`grep "Installed: kernel-" /var/log/yum.log | grep -v devel | grep -v headers | grep -v debug | grep -v tools | grep -v firmware | grep -v doc | tail -1 | awk -F"kernel-" '{print$2}' | awk -F".x86_64" '{print$1}' | awk -F".i686" '{print$1}' | awk -F".i386" '{print$1}'`
	if [ "$LKMV" = "" ]; then  #no legit yum.log, or no updates yet
		#this isn't perfect, but should catch most cases okay
		LKMV=`rpm -qa | grep ^kernel | grep -v devel | grep -v headers | grep -v debug | grep -v tools | grep -v doc | grep -v firmware | awk -F"kernel-" '{print$2}' | awk -F".x86_64" '{print$1}' | awk -F".i686" '{print$1}' | awk -F".i386" '{print$1}' | awk -F".el" '{print$1}' | sort | tail -1`
	fi
	LKMV=`echo $LKMV | awk -F".el" '{print$1}'`
	if [ "$CKMV" != "$LKMV" ]; then
		echo "(current) ${CKMV} != ${LKMV} (latest)"
		return 1
	fi
	return 0
} #end checkkern

newkern () {  #see if running newest kernel after patching/reboot: -prekern
	      #only report if NOT the LATEST, -testall
	if [ "$SUFF" = "snapshot" ]; then
		return 0  #we don't check kernel versions for snapshots
	fi
	if [ ! -f /var/log/yum.log ]; then
		return 0  #ubuntu?
	fi
	if [ "$OSVER" = "SunOS" ]; then   #Solaris
		CURK=`uname -v`
	else 
		CURK=`uname -r | awk -F".x86_64" '{print$1}'`
	fi
	if [ -f ${PREPDIR}/kernelver.$SUFF ]; then
		PREK=`cat ${PREPDIR}/kernelver.$SUFF | awk -F".x86_64" '{print$1}'`
	else
		if [ $VERBOSE = 1 ]; then
			echo "### -prekern ###"
		fi
		echo "WARNING: No previous kernel recorded in ${PREPDIR}/kernelver.$SUFF" >&2
		return 2
	fi
	if [ "$CURK" = "$PREK" ]; then  #same version
		if [ "$OSVER" = "Linux" ]; then  #Linux check if latest
			LATK=`grep "Installed: kernel-" /var/log/yum.log | grep -v devel | grep -v headers | grep -v debug | tail -1 | awk -F"kernel-" '{print$2}' | awk -F".x86_64" '{print$1}' | awk -F".i686" '{print$1}' | awk -F".i386" '{print$1}'`
			if  [ "$LATK" = "$CURK" ]; then
				return 0  #no newer kernel installed, skip
			fi
			if [ "$LATK" = "" ]; then
				return 0  #no newer kernel to compare
			fi
		fi #end Linux only
		if [ $VERBOSE = 1 ]; then
                        echo "### -prekern ###"
                fi
		echo "Current is same as previous kernel: $PREK"
		return 1
	fi
	return 0
}  #end newkern

fixnetfs () {  #add net delay, fix netfs/fstab for _netdev: -netfs/+netfs
  RV=0
  if [ -f /etc/fstab ]; then   #Linux only
	#Fix FSTAB file
	NEWFILE="$PREPDIR/fstab.fixed"
	cat /dev/null > $NEWFILE
	chmod 0644 $NEWFILE
	cat /etc/fstab | (
	 CHF="0"
	 read A
	 RC=$?
	 while [ $RC = 0 ]; do
	 	#B=`echo $A | grep -v ^# | grep -v _netdev | awk '{print$3}' | egrep 'cifs|nfs|vxfs|ceph|glusterfs|gfs2|sshfs'`
		B=`echo $A | grep -v ^# | awk '{print$3}' | egrep 'cifs|nfs|vxfs|glusterfs|gfs2|ceph|sshfs'`
	 	if [ "$B" != "" ]; then  #network FS found
			F1=`echo $A | awk '{print$1}'`
			F2=`echo $A | awk '{print$2}'`
			F3=`echo $A | awk '{print$3}'`
			F4=`echo $A | awk '{print$4}'`
			F5=`echo $A | awk '{print$5}'`
			F6=`echo $A | awk '{print$6}'`
			if [ "$F5" = "" ]; then
				F5="0"
			fi
			if [ "$F6" = "" ]; then
				F6="0"
			fi
			C1=`echo $F4 | grep "_netdev"`
			if [ "$C1" = "" ]; then
				NOPTS=",_netdev"
				CHF="1"
			 else
				NOPTS=""
			fi
			if [ "$OSV" = "7" -a "$OSV" = "8" ]; then
			   if [ "$F3" = "nfs" ]; then
				#add checks for x-systemd.automount,x-systemd.device-timeout=10,timeo=14
				C1=`echo $F4 | grep "x-systemd.automount"`
				if [ "$C1" = "" ]; then
					NOPTS="$NOPTS,x-systemd.automount"
					CHF="1"
				fi
				C1=`echo $F4 | grep "x-systemd.device-timeout=10"`
				if [ "$C1" = "" ]; then
					NOPTS="$NOPTS,x-systemd.device-timeout=10"
					CHF="1"
				fi
				C1=`echo $F4 | grep "timeo=14"`
				if [ "$C1" = "" ]; then
					NOPTS="$NOPTS,timeo=14"
					CHF="1"
				fi
			   fi
			fi
			if [ "$CHF" = "1" ]; then
				NOPTS="${F4}$NOPTS"  #add any new options
				echo $ECF "${F1}\t${F2}\t${F3}\t$NOPTS\t${F5} ${F6}" >> $NEWFILE
			 else #netfs, but no change needed, echo line out
				echo "$A" >> $NEWFILE
			fi
	 	 else #not netfs, no change needed, echo line out
			echo "$A" >> $NEWFILE
	 	fi
	 	read A
	 	RC=$?
	 done
	 if [ "$CHF" = "1" ]; then
		RV=1
		if [ ! -d  $PREPDIR ]; then
			mkdir $PREPDIR 
		fi
	 	echo "new fstab file generated"
	 	DT=`date +%s`
	 	cp /etc/fstab  $PREPDIR/fstab.${DT}.pre-fixed
		if [ $DOIT = "1" ]; then
			mv $NEWFILE /etc/fstab
		fi
	 else  #no change in (v)fstab
		rm -f $NEWFILE
	 fi
	)  #end of cat /etd/fstab subshell

	if [ ! -f /etc/sysconfig/network ]; then
		return 0  #not RH/Centos/Fedora
	fi
	#fix /etc/syconfig/network
	ND=`grep ^NETWORKDELAY /etc/sysconfig/network`
	if  [ "$ND" = "" ]; then
		echo "Adding network delay"
		if [ "$DOIT" = "1" ]; then
			echo "NETWORKDELAY=20" >> /etc/sysconfig/network
		fi
		RV=`expr $RV + 2`
	fi
	# Add NOZEROCONF="yes" or "no"
	#ND=`grep ^NOZEROCONF /etc/sysconfig/network`
	#if  [ "$ND" = "" ]; then
	#	echo "Adding NOZEROCONF=yes"
	#	if [ "$DOIT" = "1" ]; then
	#		#grep -v NOZEROCONF /etc/sysconfig/network > /etc/sysconfig/network__
	#		echo "NOZEROCONF=yes" >> /etc/sysconfig/network
	#		#mv /etc/sysconfig/network__ /etc/sysconfig/network
	#	fi
	#	RV=`expr $RV + 4`;
	#fi
	#fix netfs
	if [ -f /etc/init.d/netfs.old ]; then
		if [ ! -f /etc/init.d/netfs ]; then #new version,ignore
			echo "Renaming netfs.old"
			if [ $DOIT = "1" ]; then
				mv /etc/init.d/netfs.old /etc/init.d/netfs
			fi
			RV=`expr $RV + 8`
		fi
	fi
	if [ -f /etc/init.d/netfs ]; then  #only exists on 5/6
		if [ $DOIT = "1" ]; then
			/sbin/chkconfig netfs on
		fi
	fi
  fi
  return $RV
}  #end fixnetfs

listfstype () { #find and list file system type in current mounts: -list FS
	if [ "$B" = "" ]; then
		echo "Usage: $0 -list <FS type>"
		echo "  Examples of file system (FS) types:"
		echo "   ext3, ext4, xfs, ufs, zfs, vxfs, nfs, cifs, sshfs, gfs2, glusterfs, vfat"
		return 2
	fi
	if [ "$OSVER" = "SunOS" ]; then  #Solaris
		mount -v | grep " $B " | awk '{print$3" \tmounted from "$1}' | sort
	else  #Linux
		mount | egrep "( $B |fuse.$B)" | awk '{print$3" \tmounted from "$1}' | sort
	fi
	return 0
} #end of listfstype

checktz () {  #check if TimeZone changed: -tz
	RETV=0
	if [ -f $PREPDIR/date.${SUFF} ]; then
		if [ "$OSV" = "u20.04" -o "$OSV" = "u18.04" ]; then
			CTIM=`date | awk '{print$NF}'`
			PTIM=`cat $PREPDIR/date.${SUFF} | awk '{print$NF}'`
		else 
			CTIM=`date | awk '{print$5}'`
			PTIM=`cat $PREPDIR/date.${SUFF} | awk '{print$5}'`
		fi
		if [ "$CTIM" != "$PTIM" ]; then
			RETV=1
			if [ $VERBOSE = 1 ]; then
                        	echo "### -tz ###"
                	fi
			echo "Time Zone appears to have changed ($PTIM -> $CTIM)."
		fi
	else
		echo "WARNING: no $PREPDIR/date.$SUFF found" >&2
		return 2
	fi
	return $RETV
}  #end of checktz

checkupdate () {  #check for yum updates: -chkup
	if [ "$OSVER" = "SunOS" ]; then  #skip Sun boxes
		return 0
	fi
	if [ "$OSV" = "u20.04" -o "$OSV" = "u18.04" ]; then
		num_updates=`LANG=C apt-get upgrade -s |grep -P '^\d+ upgraded'|cut -d" " -f1`
		echo "$num_updates Updates available"
		return 100
	fi
	if [ ! -x /bin/yum -a ! -x /usr/bin/yum ]; then
        	return 0 #not RH linux
	fi
	yum check-update > $PREPDIR/yumcheck.out 2>&1
	RV=$?
	if [ $RV = 100 ]; then
		RVV=`yum -q list updates | grep -v "Updated Packages" |wc -l`
		echo "$RVV Updates available"
		return 100
	fi
	if [ $RV -lt 0 ]; then
		echo "Error checking for updates ($RV)"
		return 2
	fi
	return 0
}  #end of checkupdate

checkupdate_live () {  # -livechkup/+livechkup  (all repos)
	if [ "$OSVER" = "SunOS" ]; then  #skip Sun boxes
		return 0
	fi
	if [ ! -x /bin/yum -a ! -x /usr/bin/yum ]; then
        	return 0 #not RH linux
	fi
	REPOLIST=""
	#for i in `yum repolist | grep ^' * ' | grep Frozen-LN | awk '{print$2}' | awk -F: '{print$1}' | awk -F'Frozen-' '{print$2}'`; do
	for i in `yum repolist | grep -v ^' * ' | grep Frozen-LN | awk '{print$1}' | awk -F'/' '{print$1}' | awk -F'Frozen-' '{print$2}'`; do
		if [ "$REPOLIST" = "" ]; then
			REPOLIST="$i"
		else
			REPOLIST="$REPOLIST,$i"
		fi
	done
	if [ "$REPOLIST" = "" ]; then
		ENABLED=""   #RedHat doesn't use Frozen, so nothing to set
	else
		ENABLED="--enablerepo=$REPOLIST"
	fi
	yum -q check-update --disablerepo "Frozen-LN-*" $ENABLED > $PREPDIR/yumcheck.out 2>&1
        RV=$?
        if [ $RV = 100 ]; then
                RVV=`yum -q --disablerepo "Frozen-LN-*" $ENABLED -q list updates | grep -v "Updated Packages" |wc -l`
		if [ "$DOIT" = "1" ]; then
			cat $PREPDIR/yumcheck.out | grep -v "Updated Packages"
		fi
                echo "$RVV Updates available"
                return 100
        fi
        if [ $RV -lt 0 ]; then
                echo "Error checking for updates ($RV)"
                return 2
        fi
        return 0
} #end of checkupdate_live

yumcheckup () { #check if yum can update: -yum
  if [ "$OSVER" = "SunOS" ]; then  #skip Sun boxes
	return 0
  fi
  if [ ! -x /bin/yum -a ! -x /usr/bin/yum ]; then
	return 0
  fi
  RETV=0
  if [ -x /usr/bin/expect -o -x /bin/expect ]; then
	cat /dev/null > $PREPDIR/check-yum.out
	expect << EOF_
	  set timeout 300
	  log_file -a $PREPDIR/check-yum.out
	  log_user 0
	  spawn /usr/bin/yum -q update
	  expect {
		timeout { send_user "\nError : Yum timed out\n"; exit 1}
		"Is this ok" {
			send_user "Yum check: Okay\n"
			send "n\r\n"; exit 0
		 }
		"Error " { send_user "\n Yum Check: Error encountered\n\n";
			exit 1}
		" error" { send_user "\n Yum Check: Error encountered\n\n";
			exit 1}
		" failed" { send_user "\n Failure doing Yum updates\n\n";
		exit 1}
		"Error: " { send_user "\n Yum Check: Error encountered\n\n";
			exit 1}
		eof { send_user "Yum check: <\$expect_out(buffer)>\n"; exit 0 }
	  }
	  exit 1
EOF_
	RETV=$?
  else
	echo "WARNING: expect command not found" >&2
	RETV=2
  fi
  if [ $RETV = 1 ]; then
	cat $PREPDIR/check-yum.out
  fi
  return $RETV
} #end of yumcheckup


yumcheckout () { #-yumout, show output of last -yum check
	if [ "$OSVER" = "SunOS" ]; then  #skip Sun boxes
        	return 0
	fi
	if [ ! -f $PREPDIR/check-yum.out ]; then
		echo "N/A"
		return 1
	fi
	cat $PREPDIR/check-yum.out
	return 0
}  #end yumcheckout

appcheckup () {  # -appchkup/+appchkup
	if [ "$OSVER" = "SunOS" ]; then  #skip Sun boxes
                return 0
        fi
	if [ ! -x /bin/yum -a ! -x /usr/bin/yum ]; then
		return 0 #not a RH based Linux
	fi
        REPOLIST=""
	TMPFILE="/tmp/zsatoolz-BD.$$._"
	echo > $TMPFILE
	yum repolist | (
	  read A
	  RC=$?
	  MF=0
	  while [ $RC = 0 ]; do
		UUU=`echo $A | grep "^repolist:"`
		if [ "$UUU" != "" ]; then
			MF=0
		fi
		UU=`echo $A | grep "^repo id "`
		if [ "$UU" != "" ]; then
			MF=1
		else
		   if [ $MF = 1 ]; then
			UUU=`echo $A | awk '{print$1}' | awk -F'/' '{print$1}' | egrep 'AppFrozen-LN|DevFrozen'`
			if [ "$UUU" != "" ]; then
				echo "$UUU" >> $TMPFILE
			fi
		   fi
		fi
		read A
		RC=$?
	   done
	 )
	for i in `cat $TMPFILE`; do
		if [ "$REPOLIST" = "" ]; then
			REPOLIST="$i"
		else
			REPOLIST="$REPOLIST,$i"
		fi
	done
	rm -f $TMPFILE
	yum -q check-update --disablerepo="Frozen-LN-*" --enablerepo="$REPOLIST" > $PREPDIR/yumchecka.out 2>&1
	RV=$?
	if [ $RV = 100 ]; then
                RVV=`yum --disablerepo="Frozen-LN-*" --enablerepo="$REPOLIST" -q list updates | grep -v "Updated Packages" |wc -l`
		if [ "$DOIT" = "1" ]; then
                	cat $PREPDIR/yumchecka.out | grep -v "Updated Packages"
		fi
                echo "$RVV Updates available"
                return 100
        fi
        if [ $RV -lt 0 ]; then
                echo "Error checking for updates ($RV)"
                return 2
        fi
        return 0
}  #end appcheckup

liveappcheckup () {  # -/+liveappchk
        if [ "$OSVER" = "SunOS" ]; then  #skip Sun boxes
                return 0
        fi
	        if [ ! -x /bin/yum -a ! -x /usr/bin/yum ]; then
                return 0 #non-RH based linux?
        fi
        REPOLIST=""
        #for i in `yum repolist | grep ^' * ' | egrep 'AppFrozen-LN|DevFrozen' | awk '{print$2}' | awk -F: '{print$1}'| awk -F'Frozen-' '{print$2}'`; do
	for i in `yum repolist | grep -v ^' * ' | egrep 'AppFrozen-LN|DevFrozen' | awk -F'/' '{print$1}' | awk -F'Frozen-' '{print$2}' | awk '{print$1}'`; do
                if [ "$REPOLIST" = "" ]; then
                        REPOLIST="$i"
                else
                        REPOLIST="$REPOLIST,$i"
                fi
        done
        yum -q check-update --disablerepo="*Frozen-LN-*" --enablerepo="$REPOLIST" > $PREPDIR/yumchecka.out 2>&1
        RV=$?
        if [ $RV = 100 ]; then
                RVV=`yum --disablerepo="*Frozen-LN-*" --enablerepo="$REPOLIST" -q list updates | grep -v "Updated Packages" |wc -l`
                if [ "$DOIT" = "1" ]; then
			echo "checking ${REPOLIST}"
                        cat $PREPDIR/yumchecka.out | grep -v "Updated Packages"
                fi
                echo "$RVV Updates available"
                return 100
        fi
        if [ $RV -lt 0 ]; then
                echo "Error checking for updates ($RV)"
                return 2
        fi
        return 0
}  #end liveappcheckup

appupdate () {  # -appupdate
		#update APP only packages against FROZEN, skipping OS
        if [ "$OSVER" = "SunOS" ]; then  #skip Sun boxes
                return 0
        fi
	if [ ! -x /bin/yum -a ! -x /usr/bin/yum ]; then
		return 0 #non-RH based linux?
	fi
        REPOLIST=""
        #for i in `yum repolist | grep ^' * ' | egrep 'AppFrozen-LN|DevFrozen' | awk '{print$2}' | awk -F: '{print$1}'`; do
	for i in `yum repolist | grep -v ^' * ' | egrep 'AppFrozen-LN|DevFrozen' | awk -F'/' '{print$1}' | awk '{print$1}'`; do
                if [ "$REPOLIST" = "" ]; then
                        REPOLIST="$i"
                else
                        REPOLIST="$REPOLIST,$i"
                fi
        done
        yum update --disablerepo="Frozen-LN-*" --enablerepo="$REPOLIST" $EXTARGS
        RV=$?
        return $RV
}  #end appupdate

liveappupdate () {  # -liveappupdate
		#update + APP only packages if any against LIVE, skipping OS
	if [ "$OSVER" = "SunOS" ]; then  #skip Sun boxes
		return 0
	fi
	if [ ! -x /bin/yum -a ! -x /usr/bin/yum ]; then
                return 0  #doesn't use yum
        fi
	REPOLIST=""
	#for i in `yum repolist | grep -v ^' * ' | egrep 'AppFrozen-LN|DevFrozen' | awk '{print$2}' | awk -F: '{print$1}' | awk -F'Frozen-' '{print$2}'`; do
	for i in `yum repolist | grep -v ^' * ' | egrep 'AppFrozen-LN|DevFrozen' | awk -F'/' '{print$1}' | awk -F'Frozen-' '{print$2}' | awk '{print$1}'`; do
		if [ "$REPOLIST" = "" ]; then
			REPOLIST="$i"
		else
			REPOLIST="$REPOLIST,$i"
		fi
	done
	yum update --disablerepo="*Frozen*" --enablerepo="$REPOLIST" $EXTARGS
	RV=$?
	return $RV
}  #end liveappupdate

livepatch () {   #-liveupdate
	#update any enabled repo against LIVE, including OS
	if [ "$OSVER" = "SunOS" ]; then
		#skip Sun boxes
		return 0
	fi
	if [ ! -x /bin/yum -a ! -x /usr/bin/yum ]; then
		return 0  #doesn't use yum
	fi
	REPOLIST=""
	#for i in `yum repolist | grep ^' * ' | egrep 'AppFrozen-LN|DevFrozen|Frozen-LN' | awk '{print$2}' | awk -F: '{print$1}' | awk -F'Frozen-' '{print$2}'`; do
	for i in `yum repolist | grep -v ^' * ' | egrep 'AppFrozen-LN|DevFrozen|Frozen-LN' | awk '{print$1}' | awk -F'/' '{print$1}' | awk -F'Frozen-' '{print$2}' | awk '{print$1}'`; do
		if [ "$REPOLIST" = "" ]; then
			REPOLIST="$i"
		else
			REPOLIST="$REPOLIST,$i"
		fi
	done
	if [ "$REPOLIST" = "" ]; then
		ENABLED=""  #RedHat doesn't use Frozen, so nothing to set
	else
		ENABLED="--enablerepo=$REPOLIST"
	fi
	#echo "yum update --disablerepo=\"*Frozen*\" $ENABLED $EXTARGS"
	yum update --disablerepo="*Frozen*" $ENABLED $EXTARGS
	RV=$?
	return $RV
} #end liveupdate

checkvips2 () {  #compare before/after IP configs: +vips
		 #old checkvips
	RETV=0
	if [ ! -f $PREPDIR/vips.$SUFF ]; then
		echo "WARNING: $PREPDIR/vips.$SUFF is missing"
		return 2
	fi
	VIPFILE="$PREPDIR/vips.tmp"
	genvips
	U=`diff $DFLAG $PREPDIR/vips.$SUFF $PREPDIR/vips.tmp | egrep '(^\+|^\-)' | egrep -v '\+\+\+|\-\-\-' | grep -v "HA-keepalive"`
	if [ "$U" != "" ]; then
		RETV=1
		if [ $VERBOSE = 1 ]; then
			echo "### -vips ###"
		fi
		diff $DFLAG $PREPDIR/vips.$SUFF $PREPDIR/vips.tmp | egrep '(^\+|^\-)' | egrep -v '\+\+\+|\-\-\-' | grep -v "HA-keepalive"
	fi
	if [ $DEBUG = 0 ]; then
		rm -f $VIPFILE
	fi
	return $RETV
}  #end of checkvips2

checkvips () {  #ping all managed ips/vips: -vips
	RETVAL=0
	VB=0
	if [ ! -f $PREPDIR/vips.$SUFF ]; then
		echo "WARNING: $PREPDIR/vips.$SUFF is missing"
		return 2
	fi
	for i in `cat $PREPDIR/vips.$SUFF | awk '{print$2}' | grep -v '172\...\.'`;
	do
	   OCT=`echo $i | awk -F'.' '{print$3}'`
	   if [ "$OCT" != "" ]; then
		ping -c 1 $i > /dev/null
		if [ $? = 1 ]; then
			if [ $VB = 0 -a $VERBOSE = 1 ]; then
				VB=1
				echo "### -vips ###"
			fi
			IFF=`grep $i $PREPDIR/vips.$SUFF | awk '{print$1}'`
			echo "ping of IP/VIP failed: $i ($IFF), missing or down"
			RETVAL=1
		fi
	fi
	done
	return $RETVAL
} #end of checkvips

checkroutes () { #compare routing tables (currently IPv4 only): -routes
	RETV=0
	if [ -f $PREPDIR/routes.$SUFF ]; then
		netstat -rn | awk '{print$1,$2,$3,$6}' | grep -v "169\.254\." | grep -v "172\...\.0" | sort > $PREPDIR/routes.tmp
		if [ $OST = "SUN" ]; then
			netstat -rn | awk '{print$1,$2,$3,$6}' | sort > $PREPDIR/routes.tmp
			cat $PREPDIR/routes.$SUFF | awk '{print$1,$2,$3,$6}' | sort > $PREPDIR/routes.tmp2
		else  #Linux
			netstat -rn | grep -v "169\.254\." | grep -v "172\...\.0" | awk '{print$1,$2,$3,$4,$8}' | sort > $PREPDIR/routes.tmp
			cat $PREPDIR/routes.$SUFF | grep -v 169.254.0.0 | grep -v "172\...\.0" | awk '{print$1,$2,$3,$4,$8}' | sort > $PREPDIR/routes.tmp2
		fi
		U=`diff $DFLAG $PREPDIR/routes.tmp2 $PREPDIR/routes.tmp | egrep '(^\+|^\-)' | egrep -v '\+\+\+|\-\-\-'`
		if [ "$U" != "" ]; then
			RETV=1
			if [ $VERBOSE = 1 ]; then
				echo "### -routes ###"
			fi
			diff $DFLAG $PREPDIR/routes.tmp2 $PREPDIR/routes.tmp | egrep '(^\+|^\-)' | egrep -v '\+\+\+|\-\-\-'
		fi
		rm -f $PREPDIR/routes.tmp $PREPDIR/routes.tmp2
	else
		echo "Warning: $PREPDIR/routes.$SUFF missing"
		return 2
	fi
	return $RETV
} #end of checkroutes

checkallfs () {  #check all filesystem space: -usrfs/-rootfs/-bootfs/-varfs
	RETV=0
        checkroot
	if [ $? != 0 ]; then
		RETV=1
	fi
        checkboot
	if [ $? != 0 ]; then
		RETV=1
	fi
        checkvar
	if [ $? != 0 ]; then
		RETV=1
	fi
        checkusr
	if [ $? != 0 ]; then
		RETV=1
	fi
	return $RETV
} #end of checkallfs

chkdrvr () { #check for Veritas/FusionIO/Virident drivers/software: -chkdrvr
  VGC=""
  FIO=""
  VRT=""
  DAH=""
  FOU=0
  if [ ! -f /etc/redhat-release ]; then
        return 0   #Solaris?
  fi
  R1=`rpm -qa | grep -i ^vgc-utils`
  if [ "$R1" != "" ]; then
	R1V=`echo $R1 | awk -F- '{print$3}'`
        FOU=1
        R1A=`ls /dev/vgc*`
        if [ "$R1A" != "" ]; then
                U=`grep ^/dev/vgc /etc/fstab`
                if [ "$U" = "" ]; then
                        VII="(unused)"
                else
                        VII="(in use)"
                fi
                VGC="Virident[$R1V] device found $VII; "
        else
                VGC="Virident[$R1V] software installed; "
        fi
  fi
  R1=`rpm -qa | grep -i ^fio-util- | head -1`
  if [ "$R1" != "" ]; then
	R1V=`echo $R1 | awk -F- '{print$3}'`
        FOU=1
        R1A=`ls /dev/fio*` 2> /dev/null
        if [ "$R1A" != "" ]; then
                U=`grep ^/dev/fio /etc/fstab`
                if [ "$U" = "" ]; then
                        FII="(unused)"
                else
                        FII="(in use)"
                fi
                FIO="FusionIO[$R1V] device found $FII; "
        else
                FIO="FusionIO[$R1V] software installed; "
        fi
  fi

  R1=`rpm -qa | grep ^VRTSvxfs- | head -1`
  if [ "$R1" != "" ]; then
	R1V=`echo $R1 | awk -F- '{print$2}'`
	if [ "$R1V" = "platform" -o "$R1V" = "common" ]; then
		R1V=`echo $R1 | awk -F- '{print$3}'`
	fi
        FOU=1
        R1A=`ls /dev/vx*`
        if [ "$R1A" != "" ]; then
                U=`grep ^/dev/vx /etc/fstab`
                if [ "$U" = "" ]; then
                        VI="(device unused OR clustered)"
                else
                        VI="(device in use)"
                fi
                VRT="Veritas[$R1V] drivers found $VI; "
        else
                VRT="Veritas[$R1V] software installed; "
        fi
  fi

  R1=`rpm -qa | grep -i '^dahdi-'`
  if [ "$R1" != "" ]; then
	R1=`lsmod | grep dahdi`
	if [ "$R1" != "" ]; then
		R1="(in use)"
	fi
	DAH="Dahdi VOIP module found $R1"
	FOU=1
  fi

  if [ $FOU != 0 ]; then
        echo "$VGC$FIO$VRT$DAH"
  fi
  return $FOU
}  #end of chkdrvr

checkmem() {  #check if RAM size changed significantly: -mem
	#threshold is 512M
	RV=0
	if [ -f ${PREPDIR}/memory.$SUFF ]; then
	   if [ "$OSVER" = "Linux" ]; then  #Linux
	   	CMEM=`free -m | grep "^Mem:" | awk '{print$2}'`
	   	PMEM=`cat ${PREPDIR}/memory.$SUFF | grep "^Mem:" | awk '{print$2}'`
		DMEM=`expr $CMEM - $PMEM`
	   else  #Solaris  (only valid if top is installed)
		if [ -x /usr/local/bin/top ]; then
			CMEM=`top -n 1 | grep "^Memory:" | awk '{print$2}' | awk -F'M' '{print$1}' | awk -F'G' '{print$1}'`
		else
			CMEM=`echo "::memstat" | mdb -k | grep "^Total" | awk '{print$3}'`
		fi
		PMEM=`cat ${PREPDIR}/memory.$SUFF | grep "^Memory:" | awk '{print$2}' | awk -F'M' '{print$1}' | awk -F'G' '{print$1}'`
		if [ $PMEM -lt 384 ]; then
			PMEM=`expr $PMEM \* 1024`
		fi
		if [ $CMEM -lt 384 ]; then
			CMEM=`expr $CMEM \* 1024`
		fi
		DMEM=`expr $CMEM - $PMEM`
	   fi
	   if [ "$PMEM" != "$CMEM" ]; then
		#check to see if large enough to warrant our time >512MB
		if [ $DMEM -gt 512 -o $DMEM -lt -512 ]; then
			RV=1
			if [ $VERBOSE = 1 ]; then
				echo "### -mem ###"
			fi
			echo "Memory changed: $PMEM -> $CMEM  (diff: $DMEM)"
		fi
	   fi
	else
		RV=2
		echo "Warning: ${PREPDIR}/memory.$SUFF does not exist"
	fi
	return $RV
} #end of checkmem

cleanup_old () {  #cleanup archives, create dirs if they don't exist:
		  #-cleanup/+cleanup
	if [ ! -d /root ]; then
		mkdir  /root
		mkdir $PREPDIR
		return 0
	fi
	if [ ! -d $PREPDIR ]; then
		mkdir $PREPDIR
		return 0
	fi
	if [ ! -d $PREPDIR/old ]; then
		mkdir $PREPDIR/old
		rm -f $PREPDIR/*.snapshot
		return 0
	fi
	rm -f $PREPDIR/*.snapshot
	if [ "$DOIT" = "1" ]; then
		rm -f $PREPDIR/old/*
	else
		rm -f $PREPDIR/old/*.snapshot.*
	fi
	rm -f $PREPDIR/prepout.*
	return 0
}  #end of cleanup_old

cmp_zones() { #compare before/after zone/vm states: -cmpzones
	if [ "$OSVER" = "Linux" ]; then
		if [ ! -f $PREPDIR/zones.$SUFF ]; then
			return 0
		fi
		if [ ! -x /usr/bin/virsh ]; then
			return 0
		fi
		cat $PREPDIR/zones.$SUFF | grep running | awk '{print$2,"(",$3,")"}' |sort > $PREPDIR/zones.1
		virsh list --all | awk '{print$2,"(",$3,")"}' | grep running | sort > $PREPDIR/zones.2
		
	fi
	if [ "$OSVER" = "SunOS" ]; then
		if [ ! -x /usr/sbin/zoneadm ]; then
			return 0 # no zone mgmt software installed
		fi
		#UU=`zoneadm list -cv | awk '{print$2,$3}' | grep running | grep -v global`
		#if [ "$UU" = "" ]; then  #why do we check this here?
		#	return 0  #no running zones, #but maybe there should be
		#fi
		if [ ! -f $PREPDIR/zones.$SUFF ]; then
			echo "WARNING: missing zone info prepatch file"
			return 1
		fi
		cat $PREPDIR/zones.$SUFF | awk '{print$2,$3}' | grep running | grep -v global | sort > $PREPDIR/zones.1
		zoneadm list -cv | grep running | grep -v global | awk '{print$2,$3}' | sort >  $PREPDIR/zones.2
	fi
	UU=`diff -u $PREPDIR/zones.1 $PREPDIR/zones.2 | grep -v differences`
	if [ "$UU" = "" ]; then
		if [ $DEBUG = 0 ]; then
			rm -f $PREPDIR/zones.1 $PREPDIR/zones.2
		fi
		return 0
	fi
	if [ $VERBOSE = 1 ]; then
		echo "### -cmpzones ###"
	fi
	echo " Running zone/vm mismatch: -:previous, +:current"
	echo "========================================================"
	diff -u $PREPDIR/zones.1 $PREPDIR/zones.2 | egrep -v '(^\+\+\+|^\-\-\-)' | egrep '(^\+|^\-)'
	if [ $DEBUG = 0 ]; then
		rm -f $PREPDIR/zones.1 $PREPDIR/zones.2
	fi
	return 1
}  #end of comp_zones

shutdown_zones () { #shutdown running Solaris zones: +stopzones
        if [ "$OSVER" = "Linux" ]; then
		if [ ! -x  /usr/bin/virsh ]; then
                	return 0  #no virtualization installed
		fi
		UU=`ps -ef | grep qemu | grep -v grep`
		if [ "$UU" = "" ]; then
			return 0  #no hypervisor running
		fi
		UU=`virsh list --all | egrep 'running|idle|dying' | grep -v egrep`
		if [ "$UU" = "" ]; then
			return 0 #no running VMs
		fi
		for i in `virsh list --all | egrep 'running|idle|dying' | grep -v grep | awk '{print$2}'`; do
			echo "Shutting down $i"
			virsh shutdown $i
			sleep 1
		done
		return 1  #if still here for Linux, something was shutdown
        fi
	#Only Solaris beyond this point
        if [ ! -x /usr/sbin/zoneadm ]; then
                return 0 # no zone mgmt software installed
        fi
	UU=`zoneadm list -cv | grep -v global | grep running | awk '{print$2}'`
	if [ "$UU" = "" ]; then
		return 0  #no running zones
	fi
	for i in `zoneadm list -cv | grep -v global | grep running | awk '{print$2}'`; do
		echo "Shutting down $i"
		if [ -x /usr/sbin/zlogin ]; then
			zlogin $i shutdown -y -i0 -g0
			sleep 1
		else
			zoneadm -z $i halt
			sleep 1
		fi
	done
	return 0
}  #end of shutdown_zones

check_reboot() { #-needreboot
	RV=0
	if [ "$OSV" = "u20.04" -o "$OSV" = "u18.04" ]; then
		if [ ! -f /var/run/reboot-required ]; then
			return 0
		fi
		needreboot=`cat /var/run/reboot-required | grep 'System restart required' >/dev/null 2>&1 && echo 'rebooting'`
		if [ "$needreboot" != "" ]; then
			echo "System will need rebooting"
			return 1
		fi
		return 0
	fi
	if [ -x /usr/bin/needs-restarting ]; then
                if [ "$OSV" = "6" ]; then
                        /usr/bin/needs-restarting >/dev/null 2>&1
                        RV=$?
			UPT=`uptime | grep -vi " day"`
			if [ "$UPT" = "" -o $RV != 0 ]; then
				echo "System may need rebooting (Centos 6)"
				RV=1
			fi
                else
                        /usr/bin/needs-restarting -r >/dev/null 2>&1
                        RV=$?
                fi
                if [ $RV != 0 ]; then
                        echo "System needs rebooting"
                fi
        fi
	return $RV
}  #end check_reboot

testall_postchks () {  #do all postpatch checks: -uptime/-prekern/-tz/-mem
		       #-routes/-vips/-pfc/-pc/-cmpzones/-cmpsvcs : -/+testall
			# -needreboot
	if [ $DEBUG = 1 ]; then
		echo "###Doing: -needreboot"
	fi
	check_reboot
	if [ $? != 0 ]; then
		ISS=1
	fi
	if [ "$SNAP" = "1" ]; then
		SUFF="snapshot"
	fi
	VERBOSE=1
	ISS=0
	if [ $DEBUG = 1 ]; then
		echo "###Doing: -uptime"
	fi
	check_reboot > /dev/null
	if [ $? != 0 ]; then  #if no reboot needed, ignore uptime
		checkuptime
	fi
	if [ $? != 0 ]; then
		ISS=1
	fi
	if [ $DEBUG = 1 ]; then
		echo "###Doing: -prekern"
	fi
	newkern
	if [ $? != 0 ]; then
		ISS=1
	fi
	if [ $DEBUG = 1 -a "$SUFF" != "prepatch" ]; then
		echo "###Doing: -tz"
	fi
	#skip for -testall
	if [ "$SUFF" != "prepatch" ]; then
		checktz
		if [ $? != 0 ]; then
			ISS=1
		fi
	fi
	if [ $DEBUG = 1 ]; then
		echo "###Doing: -mem"
	fi
	checkmem
	if [ $? != 0 ]; then
		ISS=1
	fi
	if [ $DEBUG = 1 -a "$SUFF" != "prepatch" ]; then
		echo "###Doing: -routes"
	fi
	if [ "$SUFF" != "prepatch" ]; then
		checkroutes
		if [ $? != 0 ]; then
			ISS=1
		fi
	fi
	if [ $DEBUG = 1 ]; then
		echo "###Doing: -vips"
	fi
	checkvips
	if [ $? != 0 ]; then
		ISS=1
	fi
	if [ $DEBUG = 1 ]; then
		echo "###Doing: -pfc"
	fi
	#mount -a;sleep 1
	prepare
	filtcomp
	if [ $? != 0 ]; then
		ISS=1
	fi
	if [ $DEBUG = 1 -a "$SUFF" != "prepatch" ]; then
		echo "###Doing: -pc"
	fi
	if [ "$SUFF" != "prepatch" ]; then
		postcur
		if [ $? != 0 ]; then
			ISS=1
		fi
	fi
	#Needs refinement to avoid false positives
	#if [ $DEBUG = 1 ]; then
	#	echo "###Doing: -cmpsvcs"
	#fi
	#if [ $OSVER = "SunOS" ];then
	#	cmpservices
	# else  skip Linux for now, do only Solaris
	#fi
	if [ $? != 0 ]; then
		ISS=1
	fi
	if [ -f $PREPDIR/zones.$SUFF ]; then
		if [ $DEBUG = 1 ]; then
			echo "###Doing: -cmpzones"
		fi
		cmp_zones
		if [ $? != 0 ]; then
			ISS=1
		fi
	fi
	if [ -f $PREPDIR/exports.$SUFF ]; then
		if [ $DEBUG = 1 ]; then
			echo "###Doing: -exports"
		fi
		cmpexports
		if [ $? != 0 ]; then
			ISS=1
		fi
	fi
	if [ -f $PREPDIR/resolv.$SUFF ]; then
		UU=`cmp $PREPDIR/resolv.$SUFF /etc/resolv.conf`
		RV=$?
		if [ $RV != 0 ]; then
			echo "###Doing: -cmpresolv"
			cmp $PREPDIR/resolv.$SUFF /etc/resolv.conf
			ISS=1
		fi
	fi
	return $ISS
}  #end of testall_postchks

do_patching () {  #actually apply patches Sun/Linux: +patch/-patch/--patch
	RT=0
	UU="N/A"
	if [ ! -d $PREPDIR/old ]; then
		mkdir -p $PREPDIR/old
	fi
	SYST=`uname -s`
	if [ "$SYST" != "SunOS" -a "$SYST" != "Linux" ]; then
		echo "Unknown system: $SYST"
		return 1
	fi
	if [ -f $PREPDIR/patching.out ]; then
		for j in 5 4 3 2 1; do
			JP=`expr $j + 1`
			if [ -f $PREPDIR/old/patching.out.$j ]; then
				mv $PREPDIR/old/patching.out.$j $PREPDIR/old/patching.out.$JP
			fi
			if [ -f $PREPDIR/old/lastpatchrun.$j ]; then
				mv $PREPDIR/old/lastpatchrun.$j $PREPDIR/old/lastpatchrun.$JP
			fi
			if [ -f $PREPDIR/old/lastpatchset.$j ]; then
				mv $PREPDIR/old/lastpatchset.$j $PREPDIR/old/lastpatchset.$JP

			fi
		done
		if [ -f $PREPDIR/patching.out ]; then
			mv $PREPDIR/patching.out $PREPDIR/old/patching.out.1
		fi
		if [ -f $PREPDIR/lastpatchrun ]; then
			mv $PREPDIR/lastpatchrun $PREPDIR/old/lastpatchrun.1
		fi
		if [ -f $PREPDIR/lastpatchset ]; then
			mv $PREPDIR/lastpatchset $PREPDIR/old/lastpatchset.1
		fi
	fi
	if [ "$SYST" = "SunOS" ]; then
		if [ "$REDIR" = "2" -o "$REDIR" = "3" ]; then # --patch/++patch
			/var/tmp/10_Recommended/installpatchset --disable-space-check --s10patchset > $PREPDIR/patching.out 2>&1
			RT=$?
			if [ $RT = 0 ]; then
				echo "Patching completed"
			fi
		else  # -patch or +patch, no difference on Solaris
			/var/tmp/10_Recommended/installpatchset --disable-space-check --s10patchset | tee $PREPDIR/patching.out 2>&1
			RT=$?  #always returns 0 with tee in use and /bin/sh
		fi
	else  #Linux
		if [ "$OSV" = "u18.04" -o "$OSV" = "u20.04" ]; then #UBUNTU
			UU=`apt -qq list --upgradable 2>/dev/null | wc -l`
			#REDIR=0 (+patch), 1 (-patch), 2 (--patch)
			if [ "$REDIR" = "3" ]; then  #++patch
				apt-get --assume-yes --with-new-pkgs upgrade $EXTARGS > $PREPDIR/patching.out 2>&1
				RT=$?
				if [ $RT != 0 ]; then
					tail -35 $PREPDIR/patching.out
					return $RT
				fi
			fi
			if [ "$REDIR" = "2" ]; then  #--patch
				apt-get -qq --assume-yes -o Dpkg::Use-Pty=0 --with-new-pkgs $EXTARGS upgrade > $PREPDIR/patching.out 2>&1
				RT=$?
			fi
			if [ "$REDIR" = "1" ]; then  # -patch (show warnings/errors)
				apt-get -q --assume-yes -o Dpkg::Use-Pty=0 upgrade --with-new-pkgs $EXTARGS > $PREPDIR/patching.out 2>&1
				RT=$?
			fi
			if [ "$REDIR" = "0" ]; then  # +patch (show warnings/errors)
				apt-get --assume-yes --with-new-pkgs upgrade $EXTARGS > $PREPDIR/patching.out 2>&1
				RT=$?
			fi
			if [ $RT = 0 -a $UU != "0" ]; then
				echo "$UU Patches completed"
			else
				tail -15 $PREPDIR/patching.out
			fi
			return $RT
		fi
		#REDHAT/CENTOS at this point
		if [ $OSV = "8" ]; then
			DNF_FLAGS="--nobest"
		else
			DNF_FLAGS=""
		fi
		if [ -f $PREPDIR/yum.flags ]; then
			PERMFLAGS=`cat $PREPDIR/yum.flags | grep -v ^# | head -1`
		else
			PERMFLAGS=""
		fi
		UU=`yum -q list updates | wc -l`
		if [ "$REDIR" = "3" ]; then  # ++patch, full redirected verbose
			yum -y $DNF_FLAGS --nogpgcheck update $PERMFLAGS $EXTARGS > $PREPDIR/patching.out 2>&1
			RT=$?
			if [ $RT = 0 -a $UU != "0" ]; then
				echo "$UU Patches completed"
			fi
		fi
		if [ "$REDIR" = "2" ]; then  # --patch  (no output but errors)
			yum -y $DNF_FLAGS -q --nogpgcheck update $PERMFLAGS $EXTARGS > $PREPDIR/patching.out 2>&1
			RT=$?
			if [ $RT = 0 -a $UU != "0" ]; then
				echo "$UU Patches completed"
			fi
		fi
		if [ "$REDIR" = "1" ]; then  # -patch (show warnings/errors)
			yum -y $DNF_FLAGS -q --nogpgcheck update $PERMFLAGS $EXTARGS | tee $PREPDIR/patching.out 2>&1
			RT=${PIPESTATUS[0]}
			if [ $RT = 0 -a $UU != "0" ]; then
				echo "$UU Patches completed"
			fi
		fi
		if [ "$REDIR" = "0" ]; then  # +patch (full output, don't use in RadSSH)
			yum -y $DNF_FLAGS --nogpgcheck update $PERMFLAGS $EXTARGS | tee $PREPDIR/patching.out 2>&1
			RT=${PIPESTATUS[0]}
		fi
	fi
	if [ $RT != 0 -a "$REDIR" = "2" ]; then
		#only show output on fatal errors
		if [ "$SYST" = "SunOS" ]; then
			tail -35 $PREPDIR/patching.out
		 else
			cat $PREPDIR/patching.out #send all output
		fi
	fi
	if [ $RT != 0 -a "$REDIR" = "3" ]; then
		#only tail output on fatal errors
		if [ "$SYST" = "SunOS" ]; then
			tail -35 $PREPDIR/patching.out
		 else
			tail -15 $PREPDIR/patching.out
		fi
	fi
	ND=`date | head -1`
	echo "$ND :: $UU applied :: Status $RT " > $PREPDIR/lastpatchrun
	if [ $RT = 0 -a $UU != "0" ]; then
		DOIT="1"
                lastrun > $PREPDIR/lastpatchset
	fi
	return $RT
}  #end of do_patching

patchout () { #-patchout, show output results from last patching run
	if [ ! -f $PREPDIR/patching.out ]; then
		echo "N/A"
		return 1
	fi
	cat $PREPDIR/patching.out
	return 0
}  #end of patchout

do_autopatch () {   #-autopatch
	if [ ! -x /usr/local/autopatch/autopatch.sh ]; then
		echo "/usr/local/autopatch/autopatch.sh not found"
		return 1
	fi
	/usr/local/autopatch/autopatch.sh --patch
	echo $?
	return $?
}  #end of do_autopatch

do_autoprepatch () {  # -autoprepatch
	if [ ! -x /usr/local/autopatch/autopatch.sh ]; then
		echo "/usr/local/autopatch/autopatch.sh not found"
		return 1
	fi
	/usr/local/autopatch/autopatch.sh --prepatch
	echo $?
	return $?
}  #end of do_autoprepatch

do_autopostpatch () {  # -autopostpatch
	if [ ! -x /usr/local/autopatch/autopatch.sh ]; then
		echo "/usr/local/autopatch/autopatch.sh not found"
		return 1
	fi
	/usr/local/autopatch/autopatch.sh --postpatch
	echo $?
	return $?
}  #end of do_autopostpatch

lastrun () {  #-last, include saving
        if [ "$DOIT" = "0" ]; then
          if [ -f $PREPDIR/lastpatchrun ]; then
                cat $PREPDIR/lastpatchrun;
          else
                echo "N/A"
		return 1
          fi
	else  #DOIT=1
	   if [ -f /var/log/yum.log ]; then
		if [ ! -f $PREPDIR/lastpatchrun ]; then
			echo "N/A"
			return 1
		fi
                UU=`cat /root/prepatch/lastpatchrun`
                if [ "$UU" != "" ]; then
                        MO=`echo $UU | awk '{print$2}'`
                        DA=`echo $UU | awk '{print$3}'`
                        TDAT="$MO $DA"
                        if [ "$DOIT" = "1" ]; then
                                tail -2000 /var/log/yum.log | grep "^$TDAT"
                        else
                                UU=`tail -2000 /var/log/yum.log | grep "^$TDAT" | egrep 'Updated|Installed|Erased' | wc -l`
                                echo "$UU packages updated/installed/deleted ($TDAT)"
                        fi
                        return 1
                fi
           fi
	fi
	return 0
} #end of lastrun

lastrunset () {  #+last
	if [ -f $PREPDIR/lastpatchset ]; then
		cat $PREPDIR/lastpatchset
	else 
		DOIT="1"
		lastrun
	fi
	return 0
} #end of lastrunset

lastrunall () {  #-lastall
	if [ -f $PREPDIR/lastpatchrun ]; then
		cat $PREPDIR/lastpatchrun
	fi
	if [ -d $PREPDIR/old ]; then
		for i in 1 2 3 4 5 6; do
			if [ -f $PREPDIR/old/lastpatchrun.$i ]; then
				cat $PREPDIR/old/lastpatchrun.$i
			fi
		done
	fi
	return 0
}  #end of lastrunall

lastrefresh () {  #-r
        if [ -f $PREPDIR/date.prepatch ]; then  #should not use $SUFF
                PR=`cat $PREPDIR/date.prepatch`  #should not use $SUFF
                RV=0
           else
                PR="N/A"
                RV=1
        fi
        if [ -f $PREPDIR/date.snapshot ]; then  #should not use $SUFF
                SN=`cat $PREPDIR/date.snapshot`  #should not use $SUFF
           else
                SN="N/A"
        fi
        echo "Prepatch: $PR, Snapshot: $SN"
        return 0
}  #end of lastrefresh

do_solaris_prep () {
        if [ "$OSVER" = "SunOS" ]; then
                OV=`uname -r`
                if [ "$OV" = "5.10" ]; then
                        if [ -x /sbin/zonename ]; then
                                ZN=`zonename`
                                if [ "$ZN" = "global" -o -f ${PREPDIR}/zonepatch.override ]; then
                                        echo "### Solaris Prep ###" > $TMPR
                                        echo "### patch date ###" >> $TMPR
                                        head -4 /var/tmp/10_Recommended/10_*Recommended.README | tail -1 >> $TMPR
                                        UU=`find /var/tmp/10_Recommended/10_*Recommended.README -mtime +93`
                                        if [ "$UU" != "" ]; then
                                                echo ":: Patch cluster may be out of date, please check ::" >> $TMPR
                                                RTV=1
                                        fi
                                        echo "### -varfs ###" >> $TMPR
                                        checkvar >> $TMPR
                                        if [ $? != 0 ]; then
                                                RTV=`expr $RTV + 1`
                                        fi
                                        echo "### -vcs ###" >> $TMPR
                                        DOIT="0"
                                        checkvcs >> $TMPR
                                        echo "### -zones ###" >> $TMPR
                                        checkzones >> $TMPR
                                        if [ $RDOPREP = 1 ]; then
                                                echo "### +r ###" >> $TMPR
                                                preserve
                                                refreshpre >> $TMPR 2>&1
                                                if [ $QUIET != 0 ]; then
                                                         echo ":: patching prep completed ($RTV fatal issues found) ::"
                                                else #QUIET=0
                                                        echo ":: patching prep completed ($RTV fatal issues found) ::" >> $TMPR
                                                        cat $TMPR
                                                fi
                                        else  #-prep/--prep
                                                if [ $QUIET = 0 ]; then
                                                        echo ":: Patching prep report completed ($RTV fatal issues found) ::" >> $TMPR
                                                        cat $TMPR
                                                else
                                                        if [ $RTV != 0 ]; then
                                                                echo ":: Patching prep report completed ($RTV fatal issues found) ::"
                                                        fi
                                                fi
                                        fi
                                        mv $TMPR $TMPRS
                                        return $RTV
                                fi
                        fi
                fi
                echo ":: Not patchable (SunOS $OV) ::"
                return 2
        fi  #end of SunOS
}  #end of do_solaris_prep()

do_ubuntu_prep () { 
        if [ "$OSV" != "u18.04" -a "$OSV" != "u20.04" ]; then
		echo "Unsupported OS"
		return 1 #not implemented
	fi
        #echo ":::Prep not yet implemented for Ubuntu:::"
        #return 0
        #Code below is preliminary -prep
        if [ $RDOPREP = 0 ]; then
        	echo "### -allfs ###" >> $TMPR
                checkboot >> $TMPR
                checkusr >> $TMPR
                URC=$?
                checkroot >> $TMPR
                RRC=$?
                checkvar >> $TMPR
                VRC=$?
         else
                echo "### -bootfs ###" >> $TMPR
                checkboot >> $TMPR
                echo "### -allfs ###" >> $TMPR
                checkallfs >> $TMPR
                if [ $? != 0 ]; then
                        echo ":: Please fix ::" >> $TMPR
                        cat $TMPR
                        mv $TMPR $TMPRS
                        RTV=`expr $RTV + 1`
                fi
        fi
        #CONTINUE Ubuntu +prep/-prep
        if [ $RDOPREP = 1 ]; then
                echo "### clearing pkg cache ###" >> $TMPR
                #yum clean all >> $TMPR 2>&1
        fi
        echo "### -chkup ###" >> $TMPR
        checkupdate >> $TMPR
        if [ $? != 100 ]; then
                if [ $RDOPREP = 1 ]; then
                        echo ":: Please fix ::" >> $TMPR
                        cat $TMPR
                        mv $TMPR $TMPRS
                        return 1
                fi
                #we only abort on +prep
                RTV=`expr $RTV + 1`
        fi
	#actual prep
	if [ $RDOPREP = 1 -a $RTV = 0 ]; then
		SUFF="prepatch"
        	echo "### +r ###" >> $TMPR
        	preserve
        	refreshpre >> $TMPR 2>&1
		if [ $QUIET = 1 ]; then
			echo ":: Patching prep completed ::"
		else
			echo ":: Patching prep completed ::" >> $TMPR
			cat $TMPR
		fi
		mv $TMPR $TMPRS
		return 0
	fi
	#prep report only, or we have failures, report count
	if [ $QUIET = 1 ]; then
                if [ $RTV != 0 ]; then
                        echo ":: Patching prep report completed ($RTV fatal issues found) ::"
                        mv $TMPR $TMPRS
                        return $RTV
                fi
        else
                echo ":: Patching prep report completed ($RTV fatal issues found) ::" >> $TMPR
                cat $TMPR
        fi
        mv $TMPR $TMPRS
        return $RTV
}  #end of do_ubuntu_prep()

do_prep () {  #-prep +prep
	SUFF="prepatch"
	TMPR=$PREPDIR/prepout.$$
	TMPRS=$PREPDIR/prepout.last
	if [ ! -d $PREPDIR/old/ ]; then
		mkdir -p $PREPDIR/old/
	fi
	for i in 6 5 4 3 2 ; do
		NI=`expr $i - 1`
		if [ -f $PREPDIR/old/prepout.last.$NI ]; then
			mv $PREPDIR/old/prepout.last.$NI $PREPDIR/old/prepout.last.$i
		fi
	done
	if [ -f $TMPRS ]; then
		mv $TMPRS $PREPDIR/old/prepout.last.1
	fi
	RTV=0
	if [ "$OSV" = "u18.04" -o "$OSV" = "u20.04" ]; then
		do_ubuntu_prep
		return $?
	fi
	if [ "$OSVER" = "SunOS" ]; then
		do_solaris_prep
		return $?
	fi  #end of SunOS	
	#only RH/Centos Linux at this point
	if [ "$OSVER" != "Linux" ]; then
		echo ":: Not patchable ::"
		return 1
	fi
	echo "### Linux prep ###" > $TMPR
	echo "### -chkdrvr ###" >> $TMPR
	chkdrvr >> $TMPR
	if [ $? != 0 ]; then
		echo " ### -kern ###" >> $TMPR
		checkkern >> $TMPR
	fi
	if [ $RDOPREP = 0 ]; then
		DOIT="0"
		echo "### -dell ###" >> $TMPR
		dellopenman >> $TMPR
		DOIT=""
		echo "### -apache ###" >> $TMPR
		check_apache >> $TMPR
		echo "### -tzdata ###" >> $TMPR
		checktzdata >> $TMPR
		if [ $? != 0 ]; then
			RTV=`expr $RTV + 1`
		fi
		DOIT="0"
		echo "### -ntp ###" >> $TMPR
		check_ntp >> $TMPR
		DOIT="0"
		echo "### -netfs ###" >> $TMPR
		fixnetfs >> $TMPR
		#we skip luks for prep report
		echo "### -allfs ###" >> $TMPR
		checkboot >> $TMPR
		checkusr >> $TMPR
		URC=$?
		checkroot >> $TMPR
		RRC=$?
		checkvar >> $TMPR
		VRC=$?
		#checkallfs >> $TMPR #exclude boot here
		if [ $URC != 0 -o $RRC != 0 -o $VRC != 0 ]; then
			RTV=`expr $RTV + 1`
		fi
		if [ -x /bin/package-cleanup ]; then
		   echo "### package-duplicates check ###" >> $TMPR
		   UU=`package-cleanup --dupes 2>/dev/null | egrep -v '^Last|^Loaded|fastestmirror'`
		   if [ "$UU" != "" ]; then
			package-cleanup --dupes >> $TMPR 2>&1
			if [ $? != 0 ]; then
				RTV=`expr $RTV + 1`
			fi
		   fi
		fi
	else #RDOPREP=1
		RTV=0
		#DOIT="1"  #skip removal for now
		echo "### -dell ###" >> $TMPR
		dellopenman >> $TMPR
		DOIT="(FIXED)"
		echo "### +apache ###" >> $TMPR
		check_apache >> $TMPR
		echo "### -tzdata ###" >> $TMPR
		checktzdata >> $TMPR
		if [ $? != 0 ]; then
			echo ":: Please fix ::" >> $TMPR
			cat $TMPR
			mv $TMPR $TMPRS
			RTV=`expr $RTV + 1`
		fi
		echo "### +ntp ###" >> $TMPR
		DOIT="1"
		check_ntp >> $TMPR 2>&1
		DOIT="1"
		echo "### +netfs ###" >> $TMPR
		fixnetfs >> $TMPR
		QLUKS="1"
		echo "### -luks (skipped) ###" >> $TMPR  #skip luks for now
		#find_luks >> $TMPR
		#if [ $? != 0 ]; then
		#	echo ":: Please fix ::" >> $TMPR
		#	cat $TMPR
		#	mv $TMPR $TMPRS
		#	return 1
		#fi
		echo "### -bootfs ###" >> $TMPR
		checkboot >> $TMPR
		if [ $? != 0 ]; then
			if [ -x /usr/bin/package-cleanup ]; then
				echo " ### running kernel cleanup ###" >> $TMPR
				cleanbootfs >> $TMPR 2>&1
			fi
		fi
		echo "### -allfs ###" >> $TMPR
		checkallfs >> $TMPR
		if [ $? != 0 ]; then
			echo ":: Please fix ::" >> $TMPR
			cat $TMPR
			mv $TMPR $TMPRS
			RTV=`expr $RTV + 1`
		fi
		if [ -x /usr/bin/package-cleanup ]; then
		   echo "### package-duplicates check ###" >> $TMPR
                   UU=`package-cleanup --dupes 2>/dev/null | egrep -v '^Last|^Loaded|fastestmirror|entitlement|'`
                   if [ "$UU" != "" ]; then
			echo ":: Please fix ::" >> $TMPR
                        package-cleanup --dupes >> $TMPR 2>&1
			cat $TMPR
			mv $TMPR $TMPRS
			RTV=`expr $RTV + 1`
                   fi
		fi
	fi
	if [ $RDOPREP = 0 ]; then
		echo "### -verlock ###" >> $TMPR
		verlock >> $TMPR
	else
		DOIT="1"
		echo "### +verlock ###" >> $TMPR
		verlock >> $TMPR
	fi
	echo "### -excl ###" >> $TMPR
	check_exclude >> $TMPR
	echo "### -lnrepos ###" >> $TMPR
	checkrepos >> $TMPR
	if [ $? != 0 ]; then
		if [ $RDOPREP = 1 ]; then
			echo ":: Please fix ::" >> $TMPR
			cat $TMPR
			mv $TMPR $TMPRS
			return 1
		fi
		RTV=`expr $RTV + 1`
	fi
	if [ $RDOPREP = 1 ]; then
		echo "### clearing yum cache ###" >> $TMPR
		yum clean all >> $TMPR 2>&1
	fi
	echo "### -chkup ###" >> $TMPR
	checkupdate >> $TMPR
	if [ ! -x /usr/bin/expect -a ! -x /bin/expect ]; then
		if [ $RDOPREP = 0 ]; then
			if [ $QUIET = 0 ]; then
				echo ":: expect not installed, cannot continue ::" >> $TMPR
				cat $TMPR
			else
				RTV=`expr $RTV + 1`
				echo ":: expect not installed, cannot continue ($RTV fatal issues found)::"
			fi
			mv $TMPR $TMPRS
			return 1
		fi
		echo "### installing expect and friends ###" >> $TMPR
		yum -y install expect lsof tcpdump sysstat bind-utils strace >> $TMPR 2>&1
	fi
	echo "### -yum ###" >> $TMPR
	if [ -f $PREPDIR/yum.flags ]; then
		echo "$PREPDIR/yum.flags found:"
		cat $PREPDIR/yum.flags | grep -v ^# | head -1
	fi
	yumcheckup >> $TMPR
	if [ $? != 0 ]; then
		if [ $RDOPREP = 1 ]; then
			echo ":: Please fix ::" >> $TMPR
			cat $TMPR
			mv $TMPR $TMPRS
			return 1
		fi
		RTV=`expr $RTV + 1`
	fi
	if [ $RDOPREP = 1 -a $RTV = 0 ]; then
		if [ ! -x /sbin/lsof -a ! -x /usr/sbin/lsof -a ! -x /usr/bin/lsof ]; then
			echo "### installing lsof ###" >> $TMPR
			yum -y install lsof >> $TMPR 2>&1
		fi
		SUFF="prepatch"
		echo "### +r ###" >> $TMPR
		preserve
		refreshpre >> $TMPR 2>&1
		if [ $QUIET = 1 ]; then
			echo ":: Patching prep completed ::"
		else
			echo ":: Patching prep completed ::" >> $TMPR
			cat $TMPR
		fi
		mv $TMPR $TMPRS
		return 0
	fi
	if [ $QUIET = 1 ]; then
		if [ $RTV != 0 ]; then
			echo ":: Patching prep report completed ($RTV fatal issues found) ::"
			mv $TMPR $TMPRS
			return $RTV
		fi
	else
		echo ":: Patching prep report completed ($RTV fatal issues found) ::" >> $TMPR
		cat $TMPR
	fi
	mv $TMPR $TMPRS
	return $RTV  #0=no serious issues, 1+=serious failure(s)
}  #end of do_prep

prepout () {  #-prepout
	TMPRS=$PREPDIR/prepout.last
	if [ -f $TMPRS ]; then
		cat $TMPRS
	fi
	return 0
} #end of prepout

print_hw_report () {  #-hwreport
	echo ":::HardWare Report:::"
	echo "############### Base Summary ################"
	print_hwarch
	echo "############### Clustered Filesystems #################"
	checkvcs
	echo "############### DB host? #################"
	show_db
	echo "############### NICs #################"
	chknics
	echo "############### Storage Sizes #################"
	print_disks
	echo "############### RAID config ################"
	raid_status|egrep -v '^Critical|^Failed'
	echo "############### Virtual Disks ################"
	list_vdisks | egrep -v '^State|Current Access|VD Cached'
	echo "############### Physical Disks ################"
	list_pdisks | egrep 'PD Type|Raw Size|Media Type|FDE Capable|-------'
	echo "###############################################"
	print_dimms
	echo "###############################################"
	return 0
}  #end print_hw_report

########## Main ##########

A=$1
if [ "$A" = "" ]; then A="-?"
fi

B=$2

case "$A" in
  -pc)
	prepare
	postcur
	RVAL=$?
	;;
  +pc)
	prepare
	DOIT="1"
	postcur
	RVAL=$?
	;;
  -cp)  #typo fix :)
	prepare
	postcur
	RVAL=$?
	;;
  -pfc)
	prepare
	filtcomp
	RVAL=$?
	;;
  +pfc)
	prepare
	DOIT="1"
	filtcomp
	RVAL=$?
	;;
  -pf)
	prepare
	preonly
	RVAL=$?
	;;
  -fp)  #typo fix :)
	prepare
	preonly
	RVAL=$?
	;;
  -fc)
	prepare
	defch
	RVAL=$?
	;;
  -cf)  #typo fix :)
	prepare
	defch
	RVAL=$?
	;;
  -f)
	prepare
	cat $CHTAB
	;;
  -p)
	prepare
	printprev
	;;
  -c)
	prepare
	cat $CHPOST
	;;
  +r)
	SUFF="prepatch"
	preserve
	refreshpre
	RVAL=$?
	;;
  -r)
        lastrefresh
        RVAL=$?
        ;;
  +R)
	SUFF="snapshot"
	preserve
	refreshpre
	RVAL=$?
	;;
  -R)
        lastrefresh
        RVAL=$?
        ;;
  -varfs)
	checkvar
	RVAL=$?
	;;
  -rootfs)
	checkroot
	RVAL=$?
	;;
  -bootfs)
	checkboot
	RVAL=$?
	;;
  +bootfs)
	FORCE="0"
	cleanbootfs
	RVAL=$?
	;;
  ++bootfs)
	FORCE="1"
	cleanbootfs
	RVAL=$?
	;;
  -usrfs)
	checkusr
	RVAL=$?
	;;
  -allfs)
	checkallfs
	RVAL=$?
	;;
  -kern)
	checkkern
	RVAL=$?
	;;
  -prekern)
	newkern
	RVAL=$?
	;;
  -netfs)
	fixnetfs
	RVAL=$?
	;;
  +netfs)
	DOIT="1"
	fixnetfs
	RVAL=$?
	;;
  -list)
	listfstype
	;;
  -tz)
	checktz
	RVAL=$?
	;;
  -luks)    #don't show luks devices, just check for issues
        QLUKS="1"
        find_luks
        RVAL=$?
        ;;
  +luks)    #show luks devs and check for luks issues
        find_luks
        RVAL=$?
        ;;
  -exports)
	cmpexports
	RVAL=$?
	;;
  -yum)
	yumcheckup
	RVAL=$?
	;;
  -yumout)
	yumcheckout
	RVAL=$?
	;;
  -chkup)
	checkupdate
	RVAL=$?
	;;
  +chkup)
	listupdates
	RVAL=$?
	;;
  +listup)  #legacy
	DOIT="1"
	checkupdate_live
	RVAL=$?
	;;
  -livechkup)
	checkupdate_live
	RVAL=$?
	;;
  +livechkup)
	DOIT="1"
	checkupdate_live
	RVAL=$?
	;;
  -appchkup)
	appcheckup
	RVAL=$?
	;;
  +appchkup)
	DOIT="1"
	appcheckup
	RVAL=$?
	;;
  -appupdate)
	appupdate
	RVAL=$?
	;;
  -liveappchk)
	liveappcheckup
	RVAL=$?
	;;
  +liveappchk)
	DOIT="1"
	liveappcheckup
	RVAL=$?
	;;
  -liveappupdate)
	liveappupdate
	RVAL=$?
	;;
  -liveupdate)
	livepatch
	RVAL=$?
	;;
  -needreboot)
	check_reboot
	RVAL=$?
	;;
  -prep)
	QUIET=1
	RDOPREP=0
	do_prep
	RVAL=$?
	;;
  +prep)
	QUIET=1
	RDOPREP=1
	do_prep
	RVAL=$?
	;;
  --prep)
	RDOPREP=0
	QUIET=0
	do_prep
	RVAL=$?
	;;
  ++prep)
	QUIET=0
	RDOPREP=1
	do_prep
	RVAL=$?
	;;
  -prepout)
	prepout
	RVAL=$?
	;;
  +patch)
	REDIR="0"   #verbose
	do_patching
	RVAL=$?
	;;
  ++patch)
	REDIR="3"  # verbose redirected
	do_patching
	RVAL=$?
	;;
  -patchout)
	patchout
	RVAL=$?
	;;
  -patch)
	REDIR="1"  #just -q
	do_patching
	RVAL=$?
	;;
  --patch)
	REDIR="2"  #total redirect
	do_patching
	RVAL=$?
	;;
  -autopatch)
	do_autopatch
	RVAL=$?
	;;
  -autoprepatch)
	do_autoprepatch
	RVAL=$?
	;;
  -autopostpatch)
	do_autopostpatch
	RVAL=$?
	;;
  -last)
	lastrun
	RVAL=$?
	;;
  +last)
        lastrunset
        RVAL=$?
        ;;
  -lastall)
	lastrunall
	RVAL=$?
	;;
  -vips)
	checkvips
	RVAL=$?
	;;
  +vips)
	checkvips2
	RVAL=$?
	;;
  -routes)
	checkroutes
	RVAL=$?
	;;
  -chkdrvr)
	chkdrvr
	RVAL=$?
	;;
  -mem)
	checkmem
	RVAL=$?
	;;
  -testall)
	testall_postchks
	RVAL=$?
	;;
  +testall)
	SNAP="1"
	testall_postchks
	RVAL=$?
	;;
  -cmpzones)
	cmp_zones
	RVAL=$?
	;;
  +stopzones)  #CAREFUL!
	shutdown_zones
	RVAL=$?
	;;
  -netprocs)
	print_netprocs
	RVAL=$?
	;;
  +netprocs)
	DOIT="1"
	print_netprocs
	RVAL=$?
	;;
  -cmpsvcs)
	cmpservices
	RVAL=$?
	;;
  -cmpsys)
	comparesysctl
	RVAL=$?
	;;
  -hwreport)
	print_hw_report
	RVAL=$?
	;;
  -ntp)
	DOIT="0"
	check_ntp
	RVAL=$?
	;;
  +ntp)
	DOIT="1"
	check_ntp
	RVAL=$?
	;;
  -cleanup)
	cleanup_old
	RVAL=$?
	;;
  +cleanup)  #remove everything from old/
	DOIT="1"
	cleanup_old
	RVAL=$?
	;;
  *)
	printusage	
	RVAL=2
	;;
esac

if [ $DEBUG = 0 ]; then
	rm -f $TEMPER $TEMPER2 $TEMPER3 $CHPRE $CHPOST $CHTAB
fi
rm -f $LOCK
#sync  #can hang on problematic hosts
exit $RVAL

