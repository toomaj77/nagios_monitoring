
#############################################################################################
#Title:nagiossdkvisitor.py
#Version:3.0 
#Creation Date: 01-Apr-2018
#Description: nagiossdkvisitor.py, processing inventory data.
#Copyright (c) 2018 Dell Inc. or its subsidiaries. All rights reserved. Dell, EMC,
#             and other trademarks are trademarks of Dell Inc. or its subsidiaries.
#			  Other trademarks may be trademarks of their respective owners.
############################################################################################
import sys
import os

sys.path.append(os.getcwd())
from device_mapping_json import *
from omsdk.sdkenum import MonitorScopeFilter, MonitorScope,MonitorScopeFilter_All
from dellemc_device_data_extractor import *
from nagios_properties import dell_device_services


class SDKVisitor(object):
    def __init__(self):
        self.data = None

    def _start(self, comp):
        pass

    def _process(self, comp, obj, index=-1):
        pass

    def _end(self, comp):
        pass

    def _proceed(self):
        return True

    def visitAll(self):
        for comp in self.data:
            self.visit(comp)

    def visit(self, comp):
        self._start(comp)
        self.subsystem_exit_code = None
        if self.deviceType == 'iDRAC':
            for instance in self.data.get('Subsystem', {}):
                if (instance.get('Key') == comp):
                    self.subsystem_exit_code = instance.get('PrimaryStatus')
                    break
                else:
                    self.subsystem_exit_code = None
        if comp in self.entity.get_json_device() and comp not in self.data:
            self.exit_code = 0
            return self
        if (comp not in self.data):
            return self
        index = 0
        sorteddata = self._getsorted(self.data.get(comp), comp, self.deviceType)
        if self.deviceType == "EqualLogic":
            if comp == "Member":
                for instance in sorteddata:
                    if instance.get("ControllerMajorVersion", "") != "":
                        tempfwVersion = str(instance.get("ControllerMajorVersion", "")) + "." + str(instance.get("ControllerMinorVersion", "")) + "." + str(instance.get("ControllerMaintenanceVersion", ""))
                        instance.update({"ControllerMajorVersion": tempfwVersion})
                        
        for i in sorteddata:
            if (comp == 'Subsystem'):
                for instance in self.data.get('System'):
                    self.subsystem_exit_code = instance.get('PrimaryStatus', 'Unknown')
                    break
                if (i['Key'] in device_comp_attr_map.get(self.deviceType).get(comp)):
                    index = index + 1
                    self._process(comp, i, index)
            else:
                index = index + 1
                self._process(comp, i, index)
        if len(sorteddata) == 0 and self.subsystem_exit_code:
            nagios_exit_code = {"Healthy": 0, "Warning": 1, "Critical": 2, "Unknown": 3,"OK":0}
            self.exit_code = nagios_exit_code[self.subsystem_exit_code]
        if len(sorteddata) == 0 and 0 < len(self.entity.entityjson.get(comp)):
            if self.criticalinst > 0:
                self.exit_code = 2
            elif self.criticalinst == 0 and self.warninginst > 0:
                self.exit_code = 1
            elif self.criticalinst == 0 and self.warninginst == 0 and self.healthyinst > 0:
                self.exit_code = 0
            else:
                self.exit_code = 3
        self._end(comp)
        return self
    
    def _noprocess(self, input=-1, output=-1):
        pass

    def _getfiltered(self, obj, comp):
        filterstr = self.healthfilter
        temp1 = filterstr.split(',')
        templist = []
        comp_key_list = device_comp_attr_map.get(self.deviceType).get(comp).keys()
        for item in temp1:
            if item.find("==") != -1:
                excludeargeqllist = item.split('==')
                for elem in obj:
                    if comp != 'Subsystem':
                        for key, value in device_comp_attr_map.get(self.deviceType).get(comp).items():
                            if excludeargeqllist[0].strip() == value:
                                if elem.get(key) == excludeargeqllist[1].strip():
                                    templist.append(elem)
                    else:
                        if elem.get(excludeargeqllist[0].strip()) == excludeargeqllist[1].strip():
                            templist.append(elem)
            if item.find("<>") != -1:
                excludeargeqllist = item.split('<>')
                for elem in obj:
                    for key, value in device_comp_attr_map.get(self.deviceType).get(comp).items():
                        if excludeargeqllist[0].strip() == value:
                            if elem.get(key) != excludeargeqllist[1].strip():
                                templist.append(elem)

        try:
            for item in templist:
                obj.remove(item)
        except ValueError:
            write_log("The given item already deleted, or doesn't exist.", "error")
        except:
            write_log("any other error", "error")

    def _getsorted(self, obj, comp, deviceType):
        healthydata = []
        warningdata = []
        criticaldata = []
        unknowndata = []
        tempdata = []

        health_attribute = None
        for element in self.entity.ref.defs[comp].get('MainHealth', []):
            health_attribute = element
            break
        for i in obj:
            if ('Up' == i.get('LinkStatus') \
                        or (comp == "Volume" and deviceType == "Compellent" and 'OK' == i.get('Status')) \
                        or (comp == "PhysicalDisk" and deviceType == "EqualLogic" and i.get('Status') in \
                        ["online", "spare", "alt-sig", "replacement", "encrypted"]) \
                        or (comp == "Volume" and deviceType == "EqualLogic" and i.get('PrimaryStatus') in \
                        ["online", "offline", "available (no new connections)"]) \
                        or (comp == "StoragePool" and deviceType == "EqualLogic") \
                        or (comp == "System" and deviceType == "MDArray" and '0' == i.get('Status')) \
                        or (
                        comp != 'NIC' and ( 'OK' == i.get(health_attribute) or '3' == i.get(health_attribute)
                        or(deviceType in ["F10","NSeries"] and (i.get('OperStatus') in ['OK','Up'] or i.get('Status') == 'Up') ) ))):
                healthydata.append(i)

            elif ('Warning' == i.get('LinkStatus') \
                          or (comp == "Volume" and deviceType == "Compellent" and 'Warning' == i.get('Status')) \
                          or (comp == "PhysicalDisk" and deviceType == "EqualLogic" and i.get('Status') in \
                        ["offline", "history-of-failures", "unhealthy", "preempt-failed"]) \
                          or (comp == "System" and deviceType == "MDArray" and '1' == i.get('Status')) \
                          or(deviceType in ["F10","NSeries"] and (i.get('OperStatus') == 'Warning' ) )
                          or (
                        comp != 'NIC' and ('Warning' == i.get(health_attribute) or '4' == i.get(health_attribute)))):
                warningdata.append(i)

            elif ('Down' == i.get('LinkStatus') \
                          or (comp == "Volume" and deviceType == "Compellent" and 'Critical' == i.get('Status')) \
                          or (comp == "PhysicalDisk" and deviceType == "EqualLogic" and i.get('Status') in \
                        ["failed", "too-small", "unsupported-version", "notApproved"]) \
                          or (comp == "Volume" and deviceType == "EqualLogic" and i.get('PrimaryStatus') in \
                        ["offline (snap reserve met)", "offline (member down)", \
                         "offline (lost blocks)", "offline (thin max grow met)", "offline (nospace auto grow)", \
                         "offline (missing pages)", "unavailable due to SyncRep", "unavailable due to internal error"]) \
                          or (comp != 'NIC' and (
                            'Critical' == i.get(health_attribute) or '5' == i.get(health_attribute) or '6' == i.get(
                    health_attribute))
                              or (deviceType in ["F10","NSeries"] and (i.get('OperStatus') in ['Critical','Down'] or i.get('Status') == 'Down')))):
                criticaldata.append(i)

            elif (('Unknown' == i.get('PrimaryStatus') \
                           or 'Unknown' == i.get('OperStatus')
                            or 'Unknown' == i.get('Status')
                           or 'Not Available' == i.get('PrimaryStatus') \
                           or '1' == i.get('PrimaryStatus') \
                           or '2' == i.get('PrimaryStatus') \
                           or not i.get('PrimaryStatus'))):
                unknowndata.append(i)
            else:
                return obj
        if comp in ['NIC', 'FC','dellNetPort']:
            if healthydata:
                for info in healthydata:
                    tempdata.append(info)
            if warningdata:
                for info in warningdata:
                    tempdata.append(info)
            if criticaldata:
                for info in criticaldata:
                    tempdata.append(info)
        else:
            if criticaldata:
                for info in criticaldata:
                    tempdata.append(info)
            if warningdata:
                for info in warningdata:
                    tempdata.append(info)
            if healthydata:
                for info in healthydata:
                    tempdata.append(info)

        if unknowndata:
            for info in unknowndata:
                tempdata.append(info)

        self.totalinstance = len(tempdata)
        self.healthyinst = len(healthydata)
        self.warninginst = len(warningdata)
        self.criticalinst = len(criticaldata)
        self.unknowninst = len(unknowndata)

        if (nagios_properties.dell_device_services.get(deviceType).get(comp).get("excludeinstance", False)):
            try:
                if (comp in ['NIC', 'FC','PowerSupplyTray','FanTray'] and self.deviceType in ['F10','iDRAC']) or (comp == 'Port' and self.deviceType in ['NSeries','F10']):
                    self.get_network_statusInformation(tempdata, healthydata, criticaldata)
                else:
                    self.formatter.mystring = "Total Instances: " + str(len(tempdata)) \
                                              + ", Healthy Instances: " + str(len(healthydata)) \
                                              + ", Warning Instances: " + str(len(warningdata)) \
                                              + ", Critical Instances: " + str(len(criticaldata)) \
                                              + ", Unknown Instances: " + str(len(unknowndata)) + "<br>"

            except AttributeError:
                write_log("Component " + comp + " formatter is not required.", "info")
        try:
            healthfilter = self.healthfilter
            if healthfilter:
                self._getfiltered(tempdata, comp)
        except NameError:
            write_log("Component " + comp + " exit code is not required to be filtered", "info")
        return tempdata

    def get_network_statusInformation(self, tempdata, healthydata, criticaldata):
        self.formatter.mystring = "Total Instances: " + str(len(tempdata)) \
                                  + ", Connected Instances: " + str(len(healthydata)) \
                                  + ", Down Instances: " + str(len(criticaldata)) + "<br>"


class XMLFormatter:
    def __init__(self):
        self.mystring = ""

    def init(self, comp):
        self.mystring += '  <component name="' + comp + '">\n'

    def start(self, index):
        if index != -1:
            self.mystring += '    <instance index="' + str(index) + '">\n'
        else:
            self.mystring += '    <instance>\n'

    def append_nvpair(self, name, value):
        self.mystring += '      <attribute name="' + name + '">' + value + '</attribute>\n'
        self.comma = ", "

    def end(self, comp):
        self.mystring += "    </instance>\n"

    def finish(self):
        self.mystring += "  </component>"


class StringFormatter:
    def __init__(self, eol="\n", separator=", "):
        self.eol = eol
        self.separator = separator

    def init(self, comp):
        self.mystring = ""

    def start(self, index, comp, primaryStatusOnly):
        if (index != -1 and comp != 'Subsystem'):
            if (primaryStatusOnly != '1'):
                self.mystring += "#" + str(index) + " "
        self.comma = ""

    def append_nvpair(self, name, value):
        self.mystring += self.comma + name + " = " + value
        self.comma = self.separator

    def append_nvpair_line(self, name, value):
        self.mystring += self.comma + name + " = " + value
        self.comma = self.eol

    def end(self, comp):
        self.mystring += self.eol

    def finish(self):
        pass


class EntitySerializer(SDKVisitor):
    def __init__(self, entity, formatter, monitorfilter, healthfilter, deviceType, primaryStatusOnly, tempDict):
        super(EntitySerializer, self).__init__()
        self.formatter = formatter
        self.entity = entity
        self.healthfilter = healthfilter
        mfilter = MonitorScopeFilter_All
        mfilter.setdefaultMap(MonitorScope.MainHealth, "Unknown")
        self.data = self.entity.get_json_device(mfilter)
        self.deviceType = deviceType
        self.primaryStatusOnly = primaryStatusOnly
        self.monitorfilter = monitorfilter
        self.extraAttributeDict = tempDict

    def _start(self, comp):
        self.formatter.init(comp)
        if (self.data.get(comp) is not None):
            self.data = self._change_health_status(comp, self.entity.ref.defs, self.data)

    def _process(self, comp, obj, index=-1):
        device_overall_health_msg_dict = {
            "EqualLogic": {
                "Member": "Overall Member"},
            "Compellent": {
                "Controller": "Overall Controller",
                "System": "Overall Storage Center"
            },
            "MDArray": {
                "System": "Overall Storage Array"
            },
            "F10":{
                "System":"Overall Switch"
            },
            "NSeries": {
                "System": "Overall Switch"
            }
        }

        self.formatter.start(index, comp, self.primaryStatusOnly)
        defs = self.entity.ref.defs
        if comp == 'Subsystem':
            if (obj['Key'] in device_comp_attr_map.get(self.deviceType).get(comp)):
                self.formatter.append_nvpair_line(device_comp_attr_map.get(self.deviceType).get(comp).get(obj['Key']),
                                                  obj.get('PrimaryStatus', 'Not Available'))
            self.formatter.end(comp)

        else:
            for field in ["MainHealth", "Health", "Key", "OtherHealth", "BasicInventory", "Inventory", "ConfigState",
                          "Metrics"]:
                if field not in self.monitorfilter:
                    continue
                if field not in defs[comp]:
                    continue
                if not isinstance(defs[comp][field], list):
                    continue

                for field_name in defs[comp][field]:
                    if field_name in device_comp_attr_map.get(self.deviceType).get(comp):
                        if (self.primaryStatusOnly == '1'):
                            if (field == "MainHealth" or field == "Health"):
                                self.formatter.append_nvpair(device_overall_health_msg_dict[self.deviceType][comp],
                                                             obj.get(field_name, 'Not Available'))
                            else:
                                continue
                        else:
                            value = obj.get(field_name, 'Not Available')
                            self.formatter.append_nvpair(
                                device_comp_attr_map.get(self.deviceType).get(comp).get(field_name),
                                'Not Available' if value is None else value)

            if (self.extraAttributeDict):
                for k, v in self.extraAttributeDict.items():
                    self.formatter.append_nvpair(device_comp_attr_map.get(self.deviceType).get(comp).get(k), v)

            self.formatter.end(comp)

    def _change_status_mapping(self, obj):
        key = "PrimaryStatus"
        severity_map = {"1": "Unknown", "2": "Unknown", "3": "OK", "4": "Warning", "5": "Critical",
                        "6": "Critical"}
        for key1 in severity_map.keys():
            if key in obj:
                if obj["PrimaryStatus"] == key1:
                    obj["PrimaryStatus"] = severity_map[key1]
        return obj

    def _change_health_status(self, comp, defs, obj):
        for instance in obj.get(comp):
            for field in ['MainHealth', 'Health', 'Key']:
                if field not in self.monitorfilter:
                    continue
                if field not in defs[comp]:
                    continue
                if not isinstance(defs[comp][field], list):
                    continue
                for field_name in defs[comp][field]:
                    if field_name not in instance:
                        continue
                    if (instance[field_name] in ['Normal', 'Healthy']):
                        instance[field_name] = "OK"
        return obj

    def _noprocess(self, input=-1, output=-1):
        if (input > 0 and output == 0):
            self.formatter.mystring = "Everything is OK" + self.formatter.eol

    def _end(self, comp):
        self.formatter.finish()


class SDKHealthVisitor(SDKVisitor):
    health_states = {
        'Healthy':0,
        'Warning': 1,
        'Critical': 2,
        'Unknown': 3,
        'OK': 0,
        'critical': 2,
        'warning': 1
    }

    def _getMDExitCode(self, data):
        status_code = {"Healthy": 0, "Warning": 1, "Critical": 2, "Unknown": 3, "OK":0} 
        self.exit_code = status_code.get("Unknown")
        for item in data.get("System"):
            self.exit_code = status_code.get(item.get("Status"))
        return self.exit_code

    def _getEqualLogicExitCode(self):
        md_health = {
            "0": "Unknown",
            "1": "OK",
            "2": "warning",
            "3": "Critical"
        }
        eCode = None
        member_array = self.get("Member")
        for i in member_array.items:
            eCode = i.get("Status")
        return md_health.get(eCode)

    def _find_exit_code(self, obj):
        health_field = ['PrimaryStatus', 'LinkStatus', 'PortStatus']
        exit_code = None
        nic_health_states = {
            'Healthy': 0,
            'Warning': 1,
            'Critical': 2,
            'Unknown': 3,
            'Up': 0,
            'Down': 2

        }
        for health in obj:
            if health in health_field:
                return nic_health_states.get(obj[health])

    def _get_EQL_PhysicalDisk_Error_Code(self, obj, comp):
        pd_health = {
            "online": "Healthy",
            "spare": "Healthy",
            "failed": "Critical",
            "offline": "Warning",
            "alt-sig": "Healthy",
            "too-small": "Critical",
            "history-of-failures": "Warning",
            "unsupported-version": "Critical",
            "unhealthy": "Warning",
            "replacement": "Healthy",
            "encrypted": "Healthy",
            "notApproved": "Warning",
            "preempt-failed": "Critical"
        }
        for element in self.entity.ref.defs[comp]['MainHealth']:
            health_attr = element
        comp_health = obj[health_attr]
        if comp_health == "Not Available":
            obj['Status'] = 'Unknown'
        else:
            obj['Status'] = pd_health[obj[health_attr]]

    def _get_EQL_Volume_Error_Code(self, obj, comp):
        pd_health = {
            "online": "Healthy",
            "offline":"Healthy",
            "available (no new connections)":"Healthy",
            "offline (snap reserve met)":"Critical",
            "offline (member down)":"Critical",
            "offline (lost blocks)":"Critical",
            "offline (thin max grow met)":"Critical",
            "offline (nospace auto grow)":"Critical",
            "offline (missing pages)":"Critical",
            "unavailable due to SyncRep":"Critical",
            "unavailable due to internal error":"Critical"
        }
        for element in self.entity.ref.defs[comp]['MainHealth']:
            health_attr = element
        comp_health = obj[health_attr]
        if comp_health == "Not Available":
            obj['Status'] = 'Unknown'
        else:
            obj['Status'] = pd_health[obj[health_attr]]

    def _get_Network_Channel_Status(self, obj, comp,deviceType):
        data =[]
        if deviceType == 'iDRAC':
            data = self.entity.ref.defs[comp]['MainHealth']
        if deviceType in ['F10','NSeries']:
            data = self.entity.ref.defs[comp]['Health']
        for element in data:
            health_attr = element
        comp_health = obj[health_attr]
        if comp_health == "Up":
            self.exit_code = self.health_states["Healthy"]
            return self.exit_code
        if comp_health == "Down":
            if self.exit_code in [self.health_states["Healthy"]]:
                self.exit_code = self.health_states["Healthy"]
                return self.exit_code
            else:
                self.exit_code = self.health_states["Critical"]
        if comp_health == "Not Available":
            if self.exit_code in [self.health_states["Healthy"], self.health_states["Critical"]]:
                return self.exit_code
            else:
                self.exit_code == self.health_states["Unknown"]
        return self.exit_code

    health_attr = ['RollupStatus']

    def __init__(self, entity, healthfilter, deviceType, setservicestatus='0'):
        super(SDKHealthVisitor, self).__init__()
        self.deviceType = deviceType
        self.setservicestatus = setservicestatus
        if (self.deviceType in ['MDArray' ,'EqualLogic','F10','NSeries']):
            mfilter = MonitorScopeFilter(MonitorScope.Health)
        else:
            mfilter = MonitorScopeFilter(MonitorScope.MainHealth, MonitorScope.Key,MonitorScope.BasicInventory)
            mfilter.setdefaultMap(MonitorScope.MainHealth,"Unknown")
        
        # mfilter.unset(MonitorScope.Key)
        self.entity = entity
        self.data = self.entity.get_json_device(mfilter)
        self.healthfilter = healthfilter


    def _start(self, comp):
        if (self.data.get(comp) is not None):
            self.data = self._change_health_status(comp, self.entity.ref.defs, self.data)
        self.exit_code = self.health_states["Unknown"]

    def _process(self, comp, obj, index=-1):
        exit_code = None
        if (comp in ['NIC', 'FC','PowerSupplyTray','FanTray'] and self.deviceType in ['F10','iDRAC']) or (comp == 'Port' and self.deviceType in ['NSeries','F10']):
            self._get_Network_Channel_Status(obj, comp,self.deviceType)

        if self.setservicestatus:
            self.exit_code = int(self.setservicestatus)
            return exit_code

        if self.deviceType == "MDArray" and comp == 'System':
            exit_code = self._getMDExitCode(self.data)
            return exit_code

        if self.deviceType == "EqualLogic" and comp =='PhysicalDisk':
            self._get_EQL_PhysicalDisk_Error_Code(obj, comp)

        if self.deviceType == "EqualLogic" and comp =='Volume':
            self._get_EQL_Volume_Error_Code(obj, comp)

        if self.subsystem_exit_code != "Not Available" and self.subsystem_exit_code != None:
            self.exit_code = exit_code = self.health_states[self.subsystem_exit_code]
            return exit_code
        if self.exit_code == self.health_states["Critical"]:
            return self.exit_code
        comp_health = -1
        for health_field in obj:
            if health_field not in self.health_attr:
                comp_health = obj[health_field]
                if comp_health == "Not Available" or comp_health not in self.health_states:
                    comp_health = 'Unknown'
                    exit_code = self.health_states[comp_health]
                else:
                    comp_health = obj[health_field]
                    exit_code = self.health_states[comp_health]
                    break
        if exit_code == None or exit_code == self.health_states["Unknown"]:
            return exit_code
        if self.exit_code == self.health_states["Unknown"]:
            self.exit_code = exit_code
            return exit_code
        if self.exit_code == self.health_states["Healthy"]:
            if exit_code in [self.health_states["Warning"], self.health_states["Critical"]]:
                self.exit_code = exit_code
                return exit_code
        if self.exit_code == self.health_states["Warning"]:
            if exit_code in [self.health_states["Critical"]]:
                self.exit_code = exit_code
                return exit_code

    def _noprocess(self, input=-1, output=-1):
        if (input > 0 and output == 0):
            self.exit_code = self.health_states["Healthy"]

    def _end(self, comp):
        pass

    def _exit_code(self):
        return self.exit_code

    def _change_health_status(self, comp, defs, obj):
        for instance in obj.get(comp):
            for field in ['MainHealth', 'Health']:
                if field not in defs[comp]:
                    continue
                if not isinstance(defs[comp][field], list):
                    continue
                for field_name in defs[comp][field]:
                    if field_name not in instance:
                        continue
                    if (instance[field_name] in ['Normal', 'Healthy']):
                        instance[field_name] = "OK"
        return obj

