
#############################################################################################
#Title:dellemc_device_data_extractor.py
#Version:3.0 
#Creation Date: 01-Apr-2018
#Description: dellemc_device_data_extractor.py provides the device details.
#Copyright (c) 2018 Dell Inc. or its subsidiaries. All rights reserved. Dell, EMC,
#             and other trademarks are trademarks of Dell Inc. or its subsidiaries.
#			  Other trademarks may be trademarks of their respective owners.
############################################################################################
import fileTemplate
import datetime
from log import NagiosLogger
import nagios_properties
import  os
import socket
import time
try:
    import argparse,netaddr
except ImportError:
    raise ImportError("%(asctime)s |ERROR |argparse or netaddr is missing,Please check and add the required package")

ipList = []

def str2bool(v):
  return v in ("1")

def validate_ip(ip,port):
    validIp= False
    resolvedIp =""
    if netaddr.valid_ipv4(ip):
        resolvedIp=ip
        validIp = True
    elif netaddr.valid_ipv6(ip):
        resolvedIp = ip
        validIp = True
    else :
        try:
            resolvedIp = get_Ip_from_hostname(ip,port)
            validIp = True
        except socket.gaierror:
            validIp=False
    if not validIp and resolvedIp =="":
        write_log("Invalid ip/host passed.Please pass correct value"+ip,"error")
    return resolvedIp

## Validating IPV6 ip ##
def is_valid_ipv6_address(address):
    try:
        socket.inet_pton(socket.AF_INET6, address)
    except socket.error:  # not a valid address
        return False
    return True

def get_vmmurl(dev):
    vmmurl = ""
    for item in dev.get("System"):
        if item.get("VirtualAddressManagementApplication") and item.get("VirtualAddressManagementApplication") != "Not Available":
            vmmurl = item.get("VirtualAddressManagementApplication")
            break
    return vmmurl

def get_model(dev):
    model = ""
    for item in dev.get("System"):
        if item.get("Model"):
            model = item.get("Model")
            break
    return model

def get_urlString(dev):
    urlString = ""
    for item in dev.get("System"):
        if item.get("URLString"):
            urlString = item.get("URLString")
            break
    return urlString
def get_device_type(dev):
    deviceType= ""
    for item in dev.get("System"):
        if item.get("_Type"):
            deviceType = item.get("_Type")
            break
    return deviceType

def get_compellent_controller_svctag(device_json,adress,isIPV6):
    serviceTag = 'NA'
    controller_comp = device_json.get('Controller')
    if not isIPV6:
        for item in controller_comp:
            if item.get("IPAddress"):
                ip = item.get("IPAddress")
                if (ip == adress):
                    serviceTag = item.get('ServiceTag')
                    break
    else :
        for item in controller_comp:
            if item.get("IPv6Address"):
                ip = item.get("IPv6Address")
                if (ip == adress):
                    serviceTag = item.get('ServiceTag')
                    break
    return serviceTag

def get_equallogic_member_svctag(device_json):
    sys_snmpstr= ""
    for item in device_json.get("System"):
        if item.get("_SNMPIndex"):
            sys_snmpstr = item.get("_SNMPIndex")
            break
    service_tag = None
    member_array = device_json.get("Member")
    for item in  member_array:
       if sys_snmpstr == item.get("_SNMPIndex"):
           service_tag = item.get("ServiceTag")
           break
    return service_tag

def initialize_logger(results,nagiosType,logLoc,fileType):
    st = datetime.datetime.fromtimestamp(time.time()).strftime('%Y%m%d')
    fileName = "discover_"+nagiosType
    logfile = fileTemplate.logFileFormat.format(fileName, st);
    if (nagios_properties.logLoc):
        logpath = os.path.join(logLoc, logfile);
    else:
        path = os.path.join(fileType[0:nagios_properties.fileType.index("nagios") + 7], "var/dell");
        nagios_properties.logLoc = path
        logpath = os.path.join(path, logfile)

    nagios_properties.application_logger = NagiosLogger(__name__,logpath)


def get_equallogic_device_type(dev):
    deviceType= ""
    for item in dev.get("System"):
        if item.get("DeviceType"):
            deviceType = item.get("DeviceType")
            break
    return deviceType

def get_compellent_managementIp(dev):
    mgIp= ""
    for item in dev.get("System"):
        if item.get("ManagementIP"):
            mgIp = item.get("ManagementIP")
            break
    return mgIp

def get_device_serviceTag(dev):
    svcTag=""
    for item in dev.get("System"):
        if item.get("ServiceTag"):
            svcTag = item.get("ServiceTag")
            break
    return svcTag

def get_extraAttribute_dict(devType,paramList,obj):
    mergeCompDict = nagios_properties.mergeSingleInstanceSpec.get(devType)
    outer = None
    inner = None
    tempDict = {}

    for k in mergeCompDict.keys():
        if(k in paramList):
            outer = k
            break;
    for k in mergeCompDict.get(k).keys():
        if(k in paramList):
            inner = k
            break
    if(outer != None and inner != None):
        dev = obj.get_json_device()
        outInstance = dev.get(outer)
        innerInstance = dev.get(inner)
        if(outInstance != None and innerInstance != None and len(outInstance) == len(innerInstance) == 1):
            slaveAttributes = nagios_properties.mergeSingleInstanceSpec.get(devType).get(outer).get(inner)
            for i in slaveAttributes:
               tempDict[i] = ('Not Available' if innerInstance[0].get(i) is None else innerInstance[0].get(i))
    return (tempDict,outer)

def write_log(string,level):
    if  nagios_properties.application_logger:
        nagios_properties.application_logger.setLevel(level)
        nagios_properties.application_logger.writeLog(string)

def add_to_queue(q):
    pid = str(os.getpid())
    q.put(pid+"=IpProviced="+str(nagios_properties.ipProvided))
    q.put(pid+"=Ipprocessed=" + str(nagios_properties.ipProcessed))
    q.put(pid+"=IpUnSucessful=" + str(nagios_properties.ipUnsuccess))
    q.put(pid + "=hostFilePresent=" + str(nagios_properties.ipFileExists))



def write_summary(q,ipList):
    tot_ip_prov=len(ipList)
    tot_ip_procs=0
    tot_ip_unsuc=0
    tot_file_present =0
    while (not q.empty()):
        line = q.get()
        if "Ipprocessed" in line:
            tot_ip_procs = tot_ip_procs + int(line.split("=")[2])
        elif "hostFilePresent" in line:
            tot_file_present = tot_file_present +int(line.split("=")[2])
        elif "IpUnSucessful" in line:
            tot_ip_unsuc = tot_ip_unsuc +int(line.split("=")[2])
    q.close()
    q.join_thread()
    display_prereq_message()
    print("Total no of Hosts / IPs provided :"+ str(tot_ip_prov))
    print("Total no of Hosts / IPs processed successfully :"+ str(tot_ip_procs))
    print("Total no of Hosts / IPs already discovered:" + str(tot_file_present))
    print("Total no of Hosts / IPs processing unsuccessful:"+ str(tot_ip_unsuc))
    print("\nDell EMC device discovery completed.")
    if (tot_ip_procs):
        print("\nPlease verify the Nagios configuration and restart the Nagios service.")


def create_file_name(ip):
    if (nagios_properties.nagios_type == 0):
        filename = ip + ".cfg"
    else:
        filename = ip + ".xml"
    filePath = os.path.join(nagios_properties.fileType, filename)
    return filePath

def process_subnet(subnet):
    try:
        ipList .extend([str(ip) for ip in netaddr.IPNetwork(subnet)])
    except netaddr.core.AddrFormatError:
        print("Error:Invalid subnet passed.Please pass correct value")
        write_log("Invalid subnet passed.Please pass correct value","error")
    return ipList

def process_file(file):
    try:
        with open(file,"r") as fh :
            for line  in fh:
                if(line.rstrip().find("/")!=-1):
                    process_subnet(line.rstrip())
                else:
                    ipList.append(line.rstrip())

    except IOError:
        print("Error:The input file is invalid,Please pass correct file path")
        write_log("The input file is invalid,Please pass correct file path","error")
    return ipList

def check_file_exists(ip):
    isFileExist= False
    filePath=create_file_name(ip)
    isFileExist= os.path.exists(filePath)
    if(isFileExist):
        write_log("Force option is disabled ,Host File already exists for ip "+ip,"info")
        nagios_properties.ipFileExists = nagios_properties.ipFileExists + 1
    return isFileExist

def get_Ip_from_hostname(ip,port):
    host = ""
    sa = ""
    for res in socket.getaddrinfo(ip, port):
        af, socktype, proto, canonname, sa = res
        if sa != "":
            break
    for items in sa:
        host = items
        if host != "":
            break

    return host

def check_preReq(req):
    isReqInstalled = False
    cmd = "type {}  >/dev/null 2>&1".format(req)
    output = os.system(cmd)
    if(output == 0):
        isReqInstalled = True
    return isReqInstalled

def complete_system_json(device):
    comp = ["System"]
    device.get_partial_entityjson_str(*comp)
    dev = device.get_json_device()
    return dev

def get_switch_url(device,deviceType):
    weburl = ""
    comp = ["Chassis","System"]
    device.get_partial_entityjson_str(*comp)
    dev = device.get_json_device()
    if deviceType != "NSeries":
        for item in dev.get("Chassis") :
            if item.get("WebURL"):
                weburl = item.get("WebURL")
                break
    else :
        for item in dev.get("System"):
            if item.get("ManagementIP"):
                weburl = item.get("ManagementIP")
                break



    return weburl


def display_prereq_message():
    if(not check_preReq("java")):
        print("Java 1.6 or above is not installed/configured. Warranty Information service will not be created.")
        write_log("Java 1.6 or above is not installed/configured. Warranty Information service will not be created.","info")
    if(not check_preReq("snmptt")):
        print("SNMPTT is not installed/configured. Traps service will not be created")
        write_log("SNMPTT is not installed/configured. Traps service will not be created","info")



