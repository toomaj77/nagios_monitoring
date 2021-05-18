
#############################################################################################
#Title:dellemc_device_check.py
#Version:3.0 
#Creation Date: 01-Apr-2018
#Description: dellemc_device_check.py, to excute the service definition command.
#Copyright (c) 2018 Dell Inc. or its subsidiaries. All rights reserved. Dell, EMC,
#             and other trademarks are trademarks of Dell Inc. or its subsidiaries.
#			  Other trademarks may be trademarks of their respective owners.
############################################################################################
import sys
import json
import os
import subprocess
import time
import datetime
import argparse
from fileTemplate import *
import nagios_properties
from log import NagiosLogger

sys.path.append(os.getcwd())
from omsdk.sdkproto import SNMPOptions
from omsdk.http.sdkwsmanbase import WsManOptions
from omsdk.http.sdkhttpep import AuthenticationType
from sys import stdout, path
from omsdk.sdkenum import ComponentScope,CreateMonitorScopeFilter
from omsdk.sdkcreds import UserCredentials,ProtocolCredentialsFactory,Snmpv2Credentials
from omsdk.sdkinfra import sdkinfra
from nagiossdkvisitor import EntitySerializer,SDKHealthVisitor,StringFormatter
from dellemc_check_warranty import *
from omsdk.sdkprotopref import ProtoPreference, ProtocolEnum
from omsdk.http.sdkredfishbase import RedfishOptions

parser = argparse.ArgumentParser()
parser.add_argument('--host', dest='host' )
parser.add_argument('--devicetype', dest='devicetype')
parser.add_argument('--protocol',  dest="protocol", type=str)
parser.add_argument('--componentname', dest='componentname')
parser.add_argument('--monitorfilter', dest='monitorfilter')
parser.add_argument('--primaryStatusOnly', dest='primaryStatusOnly', type=str,choices=('0','1'))
parser.add_argument('--setservicestatus', dest='setservicestatus', type=str,choices=('0','1','2','3'))
parser.add_argument('--logPath',dest='logPath',type=str)
parser.add_argument('--warranty.criticalDays',  dest="usercriticalDays")
parser.add_argument('--warranty.warningDays',  dest="userwarningDays")
parser.add_argument('--excludeinstance',dest='excludeinstance',type=str)
parser.add_argument('--readFile',dest='protoInfo',type=bool, default=False)
parser.add_argument('--s',dest='servicename',type=str)
parser.add_argument('--snmp.version',  dest="snVersion", type=str,
                        help="version of SNMP protocol")
parser.add_argument('--snmp.community',  dest="comString", type=str,
                        help="Community string for SNMP",default='public')
parser.add_argument('--snmp.port', dest="snmpPort", type=int,
                        help="Provides SNMP port information",default=161)
parser.add_argument('--snmp.retries',  dest="snmpRet", type=int,
                        help="SNMP retries count",default=2)
parser.add_argument('--snmp.timeout',  dest="snmpTout", type=int,
                        help="SNMP timeout value in seconds",default=3)
parser.add_argument('--http.user',  dest="httpUser", type=str,
                        help="WSMan / REST authentication  username")
parser.add_argument('--http.password',  dest="httpPassword", type=str,
                        help="WSMan / REST authentication Password")
parser.add_argument('--http.timeout',  dest="httpTimeout", type=int,
                        help="WSMan / REST timeout in seconds",default=30)
parser.add_argument('--http.retries',  dest="httpRet", type=int,
                        help="WSMan / REST timeout",default=1)
parser.add_argument('--http.port', dest="httpPort", type=int,
                        help="WSMan / REST port",default=443)
parser.add_argument('--nagios.type', dest="nagiostype", type=int,
                        help="0 - Nagios Core, 1 - Nagios XI", default=0)
args = parser.parse_args()

host            = args.host
deviceType      = args.devicetype
componentname   = args.componentname
excludeinstance = args.excludeinstance
logger=None
setTrap=args.protoInfo
service=args.servicename
inputPort = None
protopref = None

MF   = "Key+MainHealth+BasicInventory+Inventory+ConfigState+Metrics+OtherHealth+Health"
if componentname in ["Subsystem"]:
    MF = "Key+MainHealth"

def initialize_logger1(logPath):
    st = datetime.datetime.fromtimestamp(time.time()).strftime('%Y%m')
    logfile = logFileFormat.format("device_monitor_"+host, st);
    if setTrap == True:
        logfile = logFileFormat.format("device_monitor_TBH_"+host, st);
    logPath = os.path.join(logPath, logfile);
    global logger
    logger = NagiosLogger(__name__,logPath)

if(args.logPath != 'None'):
    initialize_logger1(args.logPath)

def write_log(string,level):
    if logger:
        logger.setLevel(level)
        logger.writeLog(string)
protocol = None
loc_submitcheck = None
   
def set_submitcheckLoc():
    global loc_submitcheck
    if args.nagiostype == 1:
      loc_submitcheck = nagios_properties.nagiosxi_location+"/submit_check_result.sh"
    else:
      loc_submitcheck = sys.argv[0].replace("/dell/scripts/dellemc_device_check.py","")+"/libexec/eventhandlers/submit_check_result"

       
pdict ={}
def readfile(host):
 global pdict
 global protocol 
 objectFile_loc = None
 tempfilename = None
 curloc = None
 if "dellemc_device_check.py" in sys.argv[0]:
    curloc=sys.argv[0].replace("dellemc_device_check.py","")
 if args.nagiostype == 1:
     curloc = nagios_properties.nagiosxi_location
 config_file_path = curloc+ "/dellconfigLoc.cfg"
 with open (config_file_path, "r") as loc:
    for line in loc:
        if "NagiosCLoc=" in line:
          objectFile_loc =line.split("=")
          break
 if args.nagiostype == 1:
     tempfilename = os.path.join(objectFile_loc[1], host + ".cfg")
 else:
     tempfilename = objectFile_loc[1]+ host + ".cfg"
 if not os.path.isfile(tempfilename):
     hostname = gethostname(host)
     tempfilename = objectFile_loc[1] + hostname + ".cfg"

 with open (tempfilename, "r") as myfile:
    for line in myfile:
        if "--protocol" in line:
            string1=line.split("! ")
            for string in string1:
              if 'check_command' in string:
                  string1.remove(string)
                  break

            pdict = {y[0]:y[1] for y in (x.split('=') for x in string1)} 
            break
 protocol = nagios_properties.protocol_map.get(pdict.get('--protocol').strip())
 myfile.close()

def gethostname(host):
    try:
        data = socket.gethostbyaddr(host)
        hostname = data[0]
        return hostname
    except Exception:
        return host

if setTrap == True:
 readfile(host)
 set_submitcheckLoc()
else:
 protocol = nagios_properties.protocol_map.get(args.protocol)
primaryStatusOnly = args.primaryStatusOnly
setservicestatus  = args.setservicestatus

sd = sdkinfra()
sd.importPath()

def process_WSMAN_param():
     if setTrap==True:
        (user, password, port, conTimeout, retries) = (pdict.get('--http.user'), pdict.get('--http.password'), pdict.get('--http.port'), pdict.get('--http.timeout'), pdict.get('--http.retries'))
     else:
        (user, password, port, conTimeout, retries) = (args.httpUser, args.httpPassword, args.httpPort, args.httpTimeout, args.httpRet)
     creds = ProtocolCredentialsFactory()
     creds.add(UserCredentials(user, password))
     pOpUser = WsManOptions(authentication=AuthenticationType.Basic, port=int(port), connection_timeout=int(conTimeout),read_timeout = 50,\
                               max_retries=int(retries), verify_ssl=False)
     return (creds, pOpUser)

def process_SNMP_param():
     if setTrap==True:
              (commString, port, conTimeout, retries) = (
            pdict.get('--snmp.community'), pdict.get('--snmp.port'), pdict.get('--snmp.timeout'), pdict.get('--snmp.retries'))
     else:
              (commString, port, conTimeout, retries) = (
            args.comString, args.snmpPort, args.snmpTout, args.snmpRet)
     creds = ProtocolCredentialsFactory()
     creds.add(Snmpv2Credentials(commString))
     pOpUser = SNMPOptions(port=int(port), timeout=int(conTimeout), nretries=int(retries))
     return (creds, pOpUser)

def process_Redfish_param():
    if setTrap == True:
        (user, password, port, conTimeout, retries) = (
        pdict.get('--http.user'), pdict.get('--http.password'), pdict.get('--http.port'), pdict.get('--http.timeout'),
        pdict.get('--http.retries'))
    else:
        (user, password, port, conTimeout, retries) = (
        args.httpUser, args.httpPassword, args.httpPort, args.httpTimeout, args.httpRet)
    creds = ProtocolCredentialsFactory()
    creds.add(UserCredentials(user, password))
    pOpUser = RedfishOptions(authentication=AuthenticationType.Basic, port=int(port), connection_timeout=int(conTimeout),read_timeout = 50,\
                               max_retries=int(retries), verify_ssl=False)
    return (creds, pOpUser)
if ('WSMAN' in protocol):
    (creds, pOption) = process_WSMAN_param()
if ('SNMP' in protocol):
    (creds, pOption) = process_SNMP_param()
if ('REDFISH' in protocol):
    (creds, pOption) = process_Redfish_param()
    protopref = ProtoPreference(ProtocolEnum.REDFISH)



deviceObj = sd.get_driver(deviceType, host, creds,protopref, pOptions=pOption)

if deviceObj is None:
    print("Error:"+status_message_format.format(protocol, host))
    write_log(status_message_format.format(protocol, host),"error")
    exit(3)

temp = componentname.split(',')
MC = temp
tempDict = {}
write_log("Monitoring "+deviceType+ " ip "+host+" using protocol "+protocol +" for componentname "+componentname,"info")
deviceObj.get_partial_entityjson_str(*MC)
if(len(MC) >1):
    tempDict,componentname = get_extraAttribute_dict(deviceType,MC,deviceObj)

monitorfilter = CreateMonitorScopeFilter(MF)
templist = MF.split('+')

def call():
    if (componentname == "warranty"):
        ip = validate_ip(host,inputPort)
        check_warranty(re_usr_ipCrit=args.usercriticalDays, re_usr_ipWarn=args.userwarningDays,device_obj=deviceObj, address=ip)
    else:
        mystring = EntitySerializer(deviceObj, StringFormatter('<br>'), templist, excludeinstance, deviceType,
                                    primaryStatusOnly,tempDict).visit(componentname).formatter.mystring
        exit_code = SDKHealthVisitor(deviceObj, excludeinstance, deviceType,setservicestatus).visit(
            componentname)._exit_code()
        write_log(" Component " + componentname + " is " + nagios_properties.nagios_health.get(exit_code), "info")
        deviceObj.reset()
        mystring = mystring[:-4]
        if setTrap == True :
          trapbasedcmd = loc_submitcheck
          subprocess.Popen([trapbasedcmd, str(host), str(service), str(exit_code), str(mystring)], stdout=subprocess.PIPE)
          write_log("collecting Trap based health information for host "+host+" service:"+str(service)+" :"+str(mystring),"info")
        else:
          print(mystring)
          #print(int(exit_code))
          exit(int(exit_code))

call()
    