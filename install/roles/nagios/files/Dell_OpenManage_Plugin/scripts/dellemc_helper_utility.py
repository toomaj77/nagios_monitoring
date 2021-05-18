
#############################################################################################
#Title:dellemc_helper_utility.py 
#Version:3.0 
#Creation Date: 01-Apr-2018
#Description: dellemc_helper_utility.py is  to create object file that contains host 
#             and service definitions
#Copyright (c) 2018 Dell Inc. or its subsidiaries. All rights reserved. Dell, EMC,
#             and other trademarks are trademarks of Dell Inc. or its subsidiaries.
#			  Other trademarks may be trademarks of their respective owners.
############################################################################################

import socket
import os, os.path
import multiprocessing
from dellemc_device_data_extractor import *
import sys
import nagios_properties
import re
import traceback
import fileTemplate
from log import *
import time
import datetime
import math
from multiprocessing import Process, Queue
from ProtocolCreds import SNMPCreds, WSMANCreds
sys.tracebacklimit = 0

try:
    from omsdk.sdkcreds import UserCredentials, ProtocolCredentialsFactory
    from omsdk.sdkprotopref import ProtoPreference, ProtocolEnum, ProtoMethods
    from omsdk.http.sdkwsmanbase import WsManOptions
    from omsdk.sdkproto import SNMPOptions,ProtocolOptionsFactory
    from omsdk.http.sdkhttpep import AuthenticationType
    from omsdk.sdkcreds import Snmpv2Credentials
    from omsdk.sdkinfra import sdkinfra
    from omsdk.sdkinfra import sdkinfra
    from omsdk.http.sdkredfishbase import RedfishOptions
except ImportError:
    raise ImportError("{}|ERROR |OMSDK is missing,Please add the package".format(str(datetime.datetime.now())))

logger = None
results = None
address = None
global inputport
inputport = None
global protocol_used_unpref
protocol_used_unpref = ""
global args_list
args_list = []


def do_setup():
    global sd
    sd = sdkinfra()
    sd.importPath()
    global creds, protFactory
    if (nagios_properties.protocol is not None):
        set_preferred_protocol(nagios_properties.protocol)
    (creds, protFactory) = create_credential_poption()


def argVal_range(option_string,values,parser):
           if option_string in ['--warranty.warningDays','--warranty.criticalDays'] and values not in range(1,366):
               parser.error(option_string+"="+str(values)+" value is not within valid range [1-365].")
           if option_string in ['--snmp.port','--http.port'] and values not in range(1,65536):
               parser.error(option_string+"="+str(values)+" value is not within valid range [1-65535].")
           if option_string in ['--snmp.retries','--http.retries'] and values not in range(1,11):
               parser.error(option_string+"="+str(values)+" value is not within valid range [1-10].")
           if option_string in ['--snmp.timeout','--http.timeout'] and values not in range(1,1441):
               parser.error(option_string+"="+str(values)+" value is not within valid range [1-1440].")

class UniqueStore(argparse.Action):
    def __call__(self, parser, namespace, values, option_string):
        global args_list
        if option_string not in args_list:
            args_list.append(option_string)
            if option_string in ['--snmp.port','--http.port','--snmp.retries','--http.retries','--snmp.timeout','--http.timeout','--warranty.warningDays','--warranty.criticalDays']:
               argVal_range(option_string, values, parser)            
        else:
            parser.error(option_string + " appears several times.")
        setattr(namespace, self.dest, values)
        
def parse_argument():
    parser = argparse.ArgumentParser(description='Helper Tool',formatter_class=argparse.RawTextHelpFormatter)
    group=parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--host', dest="host", type=str, action=UniqueStore, help="Host IP address or FQDN name which need to be discovered")
    group.add_argument('--File', dest="file", type=str, action=UniqueStore,
                        help="File with absolute path containing list of newline separated IP address / FQDN name / Subnet with mask")
    group.add_argument('--subnet', dest="subnet", type=str, action=UniqueStore, 
                        help="Subnet with mask")
    parser.add_argument('--all', dest="all", action='store_true',
                        help="If this parameter is passed, all the services will be enabled, else only basic services will be enabled")
    parser.add_argument('--prefProtocol', dest="protocol", choices=('1', '2', '3'), type=str, action=UniqueStore,
                        help="Protocol used for discovery/monitoring. Allowed options 1 (SNMP), 2 (WSMan) and 3 (Redfish)")
    parser.add_argument('--output.file', dest="outputLoc", type=str, action=UniqueStore,
                        help="Location where the host file will be created. Location should be <NAGIOS_HOME>/dell/config/objects", required=True)
    parser.add_argument('--logLoc', dest="logLoc", type=str, action=UniqueStore,
                        help="Location where the log file will be created in .info format")
    parser.add_argument('--snmp.version', dest="snVersion", type=str, action=UniqueStore,
                        help="Version of SNMP protocol. Allowed options 1(SNMP v1) and 2(SNMP v2c)", choices=('1', '2'))
    parser.add_argument('--snmp.community', dest="comString", type=str,
                        help="Community string for SNMP communication", default='public',action=UniqueStore)
    parser.add_argument('--snmp.port', dest="snmpPort", type=int, action=UniqueStore,
                        help="SNMP port number. Allowed value is [1-65535]", default=161)
    parser.add_argument('--snmp.retries', dest="snmpRet", type=int, action=UniqueStore,
                        help="SNMP retries count. Allowed value is [1-10]", default=2)
    parser.add_argument('--snmp.timeout', dest="snmpTout", type=int, action=UniqueStore,
                        help="SNMP timeout value in seconds. Allowed value is [1-1440]", default=3)
    parser.add_argument('--http.user', dest="httpUser", type=str, action=UniqueStore,
                        help="WSMan / REST authentication username")
    parser.add_argument('--http.password', dest="httpPassword", type=str, action=UniqueStore,
                        help="WSMan / REST authentication Password")
    parser.add_argument('--http.timeout', dest="httpTimeout", type=int, action=UniqueStore,
                        help="WSMan / REST timeout in seconds. Allowed value is [1-1440]", default=30)
    parser.add_argument('--http.retries', dest="httpRet", type=int, action=UniqueStore,
                        help="WSMan / REST retries count. Allowed value is [1-10]", default=1)
    parser.add_argument('--http.port', dest="httpPort", type=int, action=UniqueStore,
                        help="WSMan / REST port number. Allowed value is [1-65535]", default=443)
    parser.add_argument('--enableLog', dest="enableLog", action='store_true',
                        help="If this parameter is passed logs will be enabled, else logs will be disabled")
    parser.add_argument('--warranty.criticalDays', dest="usercriticalDays", type=int, action=UniqueStore,
                        help="Warranty critical days. Allowed value is [1-365]")
    parser.add_argument('--warranty.warningDays', dest="userwarningDays", type=int, action=UniqueStore,
                        help="Warranty warning days. Allowed value is [1-365]")
    parser.add_argument('--force', dest="force", action='store_true', help="Force rewrite of config file")
    parser.add_argument('--nagios.type', dest="nagiostype", type=int, help="Decides the output format of the host file. Allowed options is 0 for .cfg format and 1 for .xml format", default=0,action=UniqueStore)
    results = parser.parse_args()
    nagios_properties.protocol = nagios_properties.protocol_map.get(results.protocol)
    nagios_properties.allservice = True if results.all else False
    global nagiosType
    if (results.outputLoc):
        nagiosType = "core"
    nagios_properties.fileType = results.outputLoc
    nagios_properties.logLoc = results.logLoc
    nagios_properties.subnet = results.subnet
    nagios_properties.host = results.host
    nagios_properties.input_file = results.file
    nagios_properties.criticalDays = results.usercriticalDays
    nagios_properties.warningDays = results.userwarningDays
    nagios_properties.force_discover = True if results.force else False
    nagios_properties.nagios_type = results.nagiostype
    read_cfgfileLoc(results.outputLoc)
    global wsmancreds
    wsmancreds = WSMANCreds(results.httpUser, results.httpPassword, results.httpPort, results.httpTimeout,
                            results.httpRet)
    global snmpcreds
    snmpcreds = SNMPCreds(results.snVersion, results.comString, results.snmpPort, results.snmpRet, results.snmpTout)

    return results

def read_cfgfileLoc(temp):
    if nagios_properties.nagios_type == 0:
        with open ("./dellconfigLoc.cfg", "w") as myfile:
            temp = "NagiosCLoc="+temp+"/"
            myfile.write(temp)
        myfile.close()
 
 
def process_WSMAN_param():
    (wsmanCred, wsmnpOption) = (None, None)
    if (wsmancreds.get_wsmanpassword() is not None and wsmancreds.get_wsmanuser() is not None):
        inputport = wsmancreds.get_wsmanport()
        wsmanCred = UserCredentials(wsmancreds.get_wsmanuser(), wsmancreds.get_wsmanpassword())
        wsmnpOption = WsManOptions(authentication=AuthenticationType.Basic, port=wsmancreds.get_wsmanport(),
                           connection_timeout=wsmancreds.get_wsmanTimout(),
                           read_timeout=wsmancreds.get_wsmanTimout(), \
                           max_retries=wsmancreds.get_wsmanretries(), verify_ssl=False)
        write_log("WSMAN parameters passed : port {} timeout {} retiries {}".format(wsmancreds.get_wsmanport(),
                                                                                wsmancreds.get_wsmanTimout(),
                                                                                wsmancreds.get_wsmanretries()),
              "info")
    return (wsmanCred, wsmnpOption)

def process_Redfish_param():
    (redfishCred, redfishOption) = (None, None)
    if (wsmancreds.get_wsmanpassword() is not None and wsmancreds.get_wsmanuser() is not None):
        inputport = wsmancreds.get_wsmanport()
        redfishCred = UserCredentials(wsmancreds.get_wsmanuser(), wsmancreds.get_wsmanpassword())
        redfishOption = RedfishOptions(authentication=AuthenticationType.Basic, port=wsmancreds.get_wsmanport(),
                           connection_timeout=wsmancreds.get_wsmanTimout(),
                           read_timeout=wsmancreds.get_wsmanTimout(), \
                           max_retries=wsmancreds.get_wsmanretries(), verify_ssl=False)
        write_log("REDFISH parameters passed : port {} timeout {} retiries {}".format(wsmancreds.get_wsmanport(),
                                                                                wsmancreds.get_wsmanTimout(),
                                                                                wsmancreds.get_wsmanretries()),
              "info")
    return (redfishCred, redfishOption)

def process_SNMP_param():
    (snmpCred, snmpPoption) = (None, None)
    if (snmpcreds.get_version() is not None):
        inputport = snmpcreds.get_snmpport()
        if (snmpcreds.get_version() in ['1', '2']):
            snmpCred = Snmpv2Credentials(snmpcreds.get_snmpCommString())
            snmpPoption = SNMPOptions(port=int(snmpcreds.get_snmpport()), timeout=int(snmpcreds.get_snmpTimout()),
                                      nretries=int(snmpcreds.get_snmpretries()))
        write_log(" SNMP parameters passed : port {} timeout {} retiries {}".format(snmpcreds.get_snmpport(),
                                                                                    snmpcreds.get_snmpTimout(),
                                                                                    snmpcreds.get_snmpretries()),
                  "info")
    return (snmpCred, snmpPoption)


def to_bool(val):
    if val == '1':
        return True
    else:
        return False


def get_basic_services(deviceType, services,protUsed):
    basic_service = None
    if deviceType in ['EqualLogic', 'Compellent']:
        basic_service = {k: v for k, v in services.items() if
                         v.get("type") == 'basic' and protUsed in v.get(
                             "protocol") and nagios_properties.splcase_device == v.get("DeviceType")}
    else:
        basic_service = {k: v for k, v in services.items() if
                         v.get("type") == 'basic' and protUsed in v.get(
                             "protocol") and modelname in v.get("model")}
    return basic_service


def get_advanced_services(deviceType, services,protUsed):
    advanced_service = None
    if deviceType in ['EqualLogic', 'Compellent']:
        advanced_service = {k: v for k, v in services.items() if
                            v.get("type") == 'advanced' and protUsed in v.get(
                                "protocol") and nagios_properties.splcase_device == v.get("DeviceType")}
    else:
        advanced_service = {k: v for k, v in services.items() if
                            v.get("type") == 'advanced' and protUsed in v.get(
                                "protocol") and modelname in v.get("model")}
    return advanced_service


def _service_list_(protUsed):
    services = nagios_properties.dell_device_services.get(deviceType)
    basic_service = get_basic_services(deviceType, services,protUsed)

    advanced_service = get_advanced_services(deviceType, services,protUsed)
    return (basic_service, advanced_service)


def _host_def_(address,protUsed):
    protocol_selected = "Protocol selected :" + protUsed
    hostgrpstr = hostgroup
    if (nagios_properties.dyanamic_hostgrp != ""):
        hostgrpstr = hostgrpstr + "," + nagios_properties.dyanamic_hostgrp
        nagios_properties.dyanamic_hostgrp = ""
    if nagios_properties.nagios_type == 0:
        if(action_url != 'NA'):
            hostString = fileTemplate.host.format(host_title=title, host_use=host_use, host_name=host_name, alias=host_name,
                                              address=address, \
                                              display_name=host_name, icon_image=icon_image, hostgroups=hostgrpstr,
                                              statusmap_image=icon_image, \
                                              action_url=action_url, serviceTag=serviceTag, protocol=protocol_selected)
        else:
            hostString = re.sub(".*action_url.*","",fileTemplate.host).format(host_title=title, host_use=host_use, host_name=host_name, alias=host_name,
                                              address=address, \
                                              display_name=host_name, icon_image=icon_image, hostgroups=hostgrpstr,
                                              statusmap_image=icon_image, \
                                              serviceTag=serviceTag, protocol=protocol_selected)

    else:
        if (action_url != 'NA'):
            hostString = fileTemplate.xml_host.format(host_title=title, host_use=host_use, host_name=host_name, alias=host_name, address=address,\
                 display_name=host_name, icon_image=icon_image, hostgroups=hostgrpstr, statusmap_image=icon_image,\
                 action_url=action_url, serviceTag=serviceTag,protocol=protocol_selected,device_type=deviceType,model=modelname,device_subtype=nagios_properties.splcase_device)
        else :
            hostString = re.sub(".*action_url.*", "", fileTemplate.xml_host).format(host_title=title, host_use=host_use, host_name=host_name, alias=host_name, address=address,\
                 display_name=host_name, icon_image=icon_image, hostgroups=hostgrpstr, statusmap_image=icon_image,\
                  serviceTag=serviceTag,protocol=protocol_selected,device_type=deviceType,model=modelname,device_subtype=nagios_properties.splcase_device)

    return hostString


def service_def_(service_list, fh, serv_str):
    service_definition = ""
    command_string = ""
    for key, value in service_list.items():
        global component
        component = key
        if (value.get("requiredAdditionalComponent")):
            component = component + "," + value.get("requiredAdditionalComponent")
        if (deviceType in ['MDArray'] and key == 'Subsystem'):
            component = "System"
            if (value.get("requiredAdditionalComponent")):
                component = component + "," + value.get("requiredAdditionalComponent")
            dellcommand_eql = fileTemplate.dellcommand + " --primaryStatusOnly=1!"
            command_string = dellcommand_eql.format(device=deviceType, comp=component,
                                                    protocol=nagios_properties.protocol_string,
                                                    logPath=nagios_properties.logLoc)
        elif (deviceType in ['CMC'] and key == 'Subsystem'):
            component = "Subsystem"
            if (value.get("requiredAdditionalComponent")):
                component = component + "," + value.get("requiredAdditionalComponent")
            dellcommand_eql = fileTemplate.dellcommand + " --primaryStatusOnly=1!"
            command_string = dellcommand_eql.format(device=deviceType, comp=component,
                                                    protocol=nagios_properties.protocol_string,
                                                    logPath=nagios_properties.logLoc)
        elif deviceType in ['EqualLogic'] and key == 'Subsystem':
            component = "Member"
            if (value.get("requiredAdditionalComponent")):
                component = component + "," + value.get("requiredAdditionalComponent")
            dellcommand_eql = fileTemplate.dellcommand + " --primaryStatusOnly=1!"
            command_string = dellcommand_eql.format(device=deviceType, comp=component,
                                                    protocol=nagios_properties.protocol_string,
                                                    logPath=nagios_properties.logLoc)
        elif deviceType in ['Compellent'] and key == 'Subsystem_Mgmt':
            component = "System"
            if (value.get("requiredAdditionalComponent")):
                component = component + "," + value.get("requiredAdditionalComponent")
            dellcommand_eql = fileTemplate.dellcommand + " --primaryStatusOnly=1!"
            command_string = dellcommand_eql.format(device=deviceType, comp=component,
                                                    protocol=nagios_properties.protocol_string,
                                                    logPath=nagios_properties.logLoc)
        elif deviceType in ['Compellent'] and key == 'Subsystem_Ctrl':
            component = "Controller"
            if (value.get("requiredAdditionalComponent")):
                component = component + "," + value.get("requiredAdditionalComponent")
            dellcommand_eql = fileTemplate.dellcommand + " --primaryStatusOnly=1!"
            command_string = dellcommand_eql.format(device=deviceType, comp=component,
                                                    protocol=nagios_properties.protocol_string,
                                                    logPath=nagios_properties.logLoc)

        elif deviceType in ['F10','NSeries'] and key == 'Subsystem':
            component = "System"
            if (value.get("requiredAdditionalComponent")):
                component = component + "," + value.get("requiredAdditionalComponent")
            dellcommand_eql = fileTemplate.dellcommand + " --primaryStatusOnly=1!"
            command_string = dellcommand_eql.format(device=deviceType, comp=component,
                                                    protocol=nagios_properties.protocol_string,
                                                    logPath=nagios_properties.logLoc)

        elif key == 'warranty':
            if (not check_preReq("java")):
                continue;
            else:
                dellemc_warrantycommand_eql = fileTemplate.dellemc_warranty_command
                command_string = dellemc_warrantycommand_eql.format(device=deviceType, comp=component,
                                                                    protocol=nagios_properties.protocol_string,
                                                                    logPath=nagios_properties.logLoc,
                                                                    w_wDays=nagios_properties.warningDays,
                                                                    w_cDays=nagios_properties.criticalDays)

        else:
            dellcommand_eql = fileTemplate.dellcommand
            if 'NA' != value.get('setservicestatus', 'NA'):
                dellcommand_eql += " --setservicestatus=" + str(value.get('setservicestatus')) + "!"
            if 'NA' != value.get('excludeinstance', 'NA'):
                dellcommand_eql += " --excludeinstance=\"" + str(value.get('excludeinstance')) + "\"!"
            command_string = dellcommand_eql.format(device=deviceType, comp=component,
                                                    protocol=nagios_properties.protocol_string,
                                                    logPath=nagios_properties.logLoc)
        if component == 'Trap' or component == 'TrapG':
            if(check_preReq("snmptt")):
                service_definition = fileTemplate.trap_service.format(service_use=value.get("use"), host_name=host_name,
                                                                      service_description=value.get("name"))
        else:
            service_definition = serv_str.format(service_use=value.get("use"), host_name=host_name,
                                                 service_description=value.get("name"), check_command=command_string)
        fh.write(service_definition)


def write_device_file(device, address, resolvedAddress,protUsed,host_file_name):
    all = nagios_properties.allservice
    pre_set_attributes_for_host(device, address, resolvedAddress)
    write_log("Device discovered is " + deviceType, "info")
    filePath = create_file_name(host_file_name)
    (basic_service, advanced_service) = _service_list_(protUsed)
    with open(filePath, "w+") as fh:
        service_string = re.sub("[#]", "", fileTemplate.service_commented)
        hostString = _host_def_(resolvedAddress,protUsed)
        write_log("Host information for host " + address + " is written in " + filePath, "info")
        if nagios_properties.nagios_type == 1:
            fh.write("<hostdef>")
        fh.write(hostString)
        if nagios_properties.nagios_type == 0:
            service_def_(basic_service, fh, re.sub("[#]", "", fileTemplate.service_commented))

            if all is True:
                ss = re.sub("[#]", "", fileTemplate.service_commented)
            else:
                ss = fileTemplate.service_commented
            service_def_(advanced_service, fh, ss)
        if nagios_properties.nagios_type == 1:
            fh.write("</hostdef>")
    write_log("Service are written in the host file " + filePath, "info")
    nagios_properties.ipProcessed = nagios_properties.ipProcessed + 1


def create_host_group(vmmurl, address):
    host = vmmurl.replace("https://", "").split(":")[0]
    nagios_properties.dyanamic_hostgrp = vmmurl.replace("https://", "Cluster_").replace(":", "_")
    hostgrpstr = fileTemplate.host_group_def.format(hostGroup=nagios_properties.dyanamic_hostgrp,
                                                    alias=nagios_properties.dyanamic_hostgrp)
    filePath = create_file_name(host)
    if not os.path.exists(filePath):
        with open(filePath, "w+") as fh:
            if nagios_properties.nagios_type == 0:
                hostgrpstr =  fileTemplate.host_group_def.format(hostGroup=nagios_properties.dyanamic_hostgrp,alias=nagios_properties.dyanamic_hostgrp)
                fh.write(hostgrpstr)
            if nagios_properties.nagios_type == 1:
                hostgrpstr =  fileTemplate.xml_host_group_def.format(hostGroup=nagios_properties.dyanamic_hostgrp,alias=nagios_properties.dyanamic_hostgrp)
                fh.write(hostgrpstr)
    write_log("HostGroup  Created for cluster  for host " + address + " is written in " + filePath, "info")




def pre_set_attributes_for_host(device, address, resolvedAddress):
    dev = device.entityjson
    global deviceType
    global serviceTag
    serviceTag = 'NA'
    deviceType = get_device_type(dev)
    global model
    model = None
    global modelname
    modelname = "Default"
    global log_model
    log_model = "Default"
    global action_url
    global hostgroup
    global title
    title = "title"
    hostgroup = "hostgroup"
    action_url = get_action_url(address,deviceType)
    if deviceType == "Server":
        deviceType = "iDRAC"
        if device.IDRACURL not in [ "<not_found>", "Not Available"] :
            action_url = device.IDRACURL
        serviceTag = device.ServiceTag
        model = device.Model
        if "XC" in model or "VxRail" in model:
            dev = complete_system_json(device)
            vmmurl = get_vmmurl(dev)
            if vmmurl != "":
                action_url = vmmurl
                create_host_group(vmmurl, address)
        if "XC" in model:
            hostgroup = hostgroup + "XC"
            title = title + "XC"
            nagios_properties.splcase_device = "XC"

        elif "VxRail" in model:
            hostgroup = hostgroup + "VxRail"
            title = title + "VxRail"
            nagios_properties.splcase_device = "VxRail"

    elif deviceType == "CMC":
        if get_urlString(dev) != "<not_found>":
            action_url = get_urlString(dev)
        serviceTag = get_device_serviceTag(dev)
        model = get_model(dev)

    elif deviceType == "EqualLogic":
        dev = complete_system_json(device)
        if (get_equallogic_device_type(dev) == "EqualLogic Member"):
            serviceTag = get_equallogic_member_svctag(dev)
            nagios_properties.splcase_device = "Member"
        else:
            serviceTag = "NA"
            nagios_properties.splcase_device = "Group"

    elif deviceType == "Compellent":
        dev = complete_system_json(device)
        if get_compellent_managementIp(dev) == resolvedAddress:
            serviceTag = "NA"
            nagios_properties.splcase_device = "Management"
        else:
            nagios_properties.splcase_device = "Controller"
            isiPV6 = is_valid_ipv6_address(resolvedAddress)
            serviceTag = get_compellent_controller_svctag(dev, resolvedAddress,isiPV6)

    elif deviceType == 'MDArray':
        action_url = 'NA'

    elif deviceType in ["NSeries","F10"]:
        action_url = get_switch_url(device,deviceType)




    hostgroup = nagios_properties.device_data.get(deviceType).get(hostgroup)
    title = nagios_properties.device_data.get(deviceType).get(title)

    global host_use
    host_use = nagios_properties.device_data.get(deviceType).get("host_use")
    global icon_image
    icon_image = nagios_properties.device_data.get(deviceType).get("image")
    log_model = get_model(dev)
    if model is not None:
        model = [i for i in nagios_properties.device_data.get(deviceType).get("model") if re.search(i, model)]
        if len(model) != 0:
            modelname = model[0]



def process_command(results):
    ipList = []
    log_protocol = ""
    if (results.enableLog):
        initialize_logger(results, nagiosType, nagios_properties.logLoc, nagios_properties.fileType)

    if (nagios_properties.subnet and nagios_properties.input_file and nagios_properties.host):
        write_log(
            "User is allowed to pass only one of the following parameters at a time : --subnet,--host,--File.Please pass one of them correctly",
            "error")
        exit(1)
    do_setup()
    if(nagios_properties.protocol is  None):
        log_protocol = protocol_used_unpref
    else:
        log_protocol = nagios_properties.protocol

    if (nagios_properties.subnet):
        write_log("Discovery requested for subnet  {} using protocol {}".format(nagios_properties.subnet,
                                                                                log_protocol), "info")
        ipList = process_subnet(nagios_properties.subnet)
    elif (nagios_properties.input_file):
        write_log("Discovery requested for ip file  {} using protocol {}".format(nagios_properties.input_file,
                                                                                 log_protocol), "info")
        ipList = process_file(nagios_properties.input_file)
    elif (nagios_properties.host):
        write_log("Discovery requested for ip {} using protocol {}".format(results.host, log_protocol),
                  "info")
        ipList.append(nagios_properties.host)

    else:
        write_log("Either of --host --subnet --File option is mandatory.Please pass any one of them", "error")
        exit(1)


    if (len(ipList) > 0):
        start_process(ipList)


def start_discovery(ip):
    device_discovered = False
    host_file_name = None
    global  host_name
    device = None
    resolvedAddress = validate_ip(ip, inputport)
    write_log("Trying to find device type for host " + ip, "info")
    if ((nagios_properties.force_discover) or (not check_file_exists(ip))):
        (device,protUsed) = find_driver(ip)

    if (device is not None):
        create_proto_string(protUsed)
        if(device.hostname):
            host_file_name = device.hostname
        else:
            host_file_name = ip
        host_name = host_file_name
        write_device_file(device, ip, resolvedAddress,protUsed,host_file_name)


def start_process(ipList):
    procs = []
    ipListLen = len(ipList)
    item_per_List = int(math.ceil(ipListLen / nagios_properties.default_process))
    q = Queue()
    sub_lists = [ipList[i:i + item_per_List] for i in range(0, len(ipList), item_per_List)]
    print("\nDell EMC device discovery is in progress...\n")
    write_log("Dell EMC device discovery is in progress...", "info")
    for i in sub_lists:
        proc = Process(target=process_ipList, args=(i, q,))
        procs.append(proc)
        proc.start()

    for proc in procs:
        proc.join()

    write_summary(q, ipList)


def process_ipList(ipList, q):
    ipList = set(ipList)
    nagios_properties.ipProvided = len(ipList)
    for ip in ipList:
        start_discovery(ip)
    add_to_queue(q)


def set_preferred_protocol(prefProt):
    idracpref = None
    if prefProt == "SNMP":
        validateSNMPParamas()
        idracpref = ProtoPreference(ProtocolEnum.SNMP)
    elif prefProt == 'WSMAN':
        validateWSMANparamas()
        idracpref = ProtoPreference(ProtocolEnum.WSMAN)
    elif prefProt == 'REDFISH':
        validateWSMANparamas()
        idracpref = ProtoPreference(ProtocolEnum.REDFISH)
    if(idracpref is not None):
        sd.setPrefProtocolDriver('iDRAC', idracpref)



def find_driver(ip):
    device = None
    protUsed = None
    device = sd.find_driver(ip, creds, pOptions=protFactory)
    if device is None:
        if(nagios_properties.protocol is not None):
            protUsed = nagios_properties.protocol
        else :
            protUsed = protocol_used_unpref
        nagios_properties.ipUnsuccess = nagios_properties.ipUnsuccess + 1
        write_log(fileTemplate.status_message_format.format(protUsed, ip), "error")
    else:
        protUsed = device.cfactory.work_protocols[0].name
    return (device,protUsed)

def create_credential_poption():
    global protocol_used_unpref
    protocol_used_unpref= ""
    creds = None
    protFactory = None
    (wsmanCred, wsmnpOption) = process_WSMAN_param()
    (snmpCred, snmpPoption) = process_SNMP_param()
    (redfishCred, redfishOption) = process_Redfish_param()
    creds = ProtocolCredentialsFactory()
    protFactory = ProtocolOptionsFactory()
    if (wsmanCred is not None and wsmnpOption is not None):
        protocol_used_unpref = protocol_used_unpref + "WSMAN"
        creds.add(wsmanCred)
        protFactory.add(wsmnpOption)
    if (snmpCred is not None and snmpPoption is not None):
        protocol_used_unpref = protocol_used_unpref + "SNMP"
        creds.add(snmpCred)
        protFactory.add(snmpPoption)
    if (redfishCred is not None and redfishOption is not None):
        protocol_used_unpref = protocol_used_unpref + "/REDFISH"
        creds.add(redfishCred)
        protFactory.add(redfishOption)
    if (not creds.creds):
        print("Error:Atleast one protocol parameter need to be correct.Please pass parameter correctly")
        exit(1)
    return (creds,protFactory)


def validateSNMPParamas():
    if (snmpcreds.get_version() is None):
        print("Error:SNMP version is missing.Please pass the correct values")
        write_log("SNMP version is missing.Please pass the correct values", "error")
        exit(1)

def validateWSMANparamas():
    if (wsmancreds.get_wsmanpassword() is  None or wsmancreds.get_wsmanuser() is  None):
        print("Error:Either user or password is missing.Please pass the correct values")
        write_log("Either user or password is missing.Please pass the correct values", "error")
        exit(1)

def create_proto_string(protoUsed):
    protoString = None
    if(protoUsed == "SNMP"):
        protoString = fileTemplate.protocol_string_snmp.format(protocol="1", version=snmpcreds.get_version(),
                                                               community=snmpcreds.get_snmpCommString(),
                                                               port=snmpcreds.get_snmpport(),
                                                               timeout=snmpcreds.get_snmpTimout(),
                                                               retries=snmpcreds.get_snmpretries())
    elif(protoUsed == "WSMAN"):
        protoString = fileTemplate.protocol_string_wsman.format(protocol="2",
                                                                user=wsmancreds.get_wsmanuser(),
                                                                password=wsmancreds.get_wsmanpassword(),
                                                                port=wsmancreds.get_wsmanport(),
                                                                timeout=wsmancreds.get_wsmanTimout(),
                                                                retries=wsmancreds.get_wsmanretries())

    elif(protoUsed == "REDFISH"):
        protoString = fileTemplate.protocol_string_wsman.format(protocol="3",
                                                                user=wsmancreds.get_wsmanuser(),
                                                                password=wsmancreds.get_wsmanpassword(),
                                                                port=wsmancreds.get_wsmanport(),
                                                                timeout=wsmancreds.get_wsmanTimout(),
                                                                retries=wsmancreds.get_wsmanretries())
    if(protoString is not None):
        nagios_properties.protocol_string = protoString

def get_action_url(address,deviceType):
    action_url = ""
    connect_protocol = "https://"
    if(deviceType == "EqualLogic"):
        connect_protocol =  "http://"
    if is_valid_ipv6_address(address):
        action_url = connect_protocol + "[" + address + "]"
    else:
        action_url = connect_protocol + address
    return action_url