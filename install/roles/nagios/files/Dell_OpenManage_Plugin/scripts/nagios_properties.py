
#############################################################################################
#Title:nagios_properties.py
#Version:3.0 
#Creation Date: 01-Apr-2018
#Description: nagios_properties.py, configuration file.
#Copyright (c) 2018 Dell Inc. or its subsidiaries. All rights reserved. Dell, EMC,
#             and other trademarks are trademarks of Dell Inc. or its subsidiaries.
#			  Other trademarks may be trademarks of their respective owners.
############################################################################################
from collections import OrderedDict

dell_device_services = {
    "iDRAC": {
        "Trap": {
            "name": "Dell EMC Server Traps",
            "type": "basic",
            "protocol": [
                "WSMAN",
                "SNMP",
                "REDFISH"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "use": "Dell EMC Traps",
        },
        "System": {
            "name": "Dell EMC Server Information",
            "type": "basic",
            "protocol": [
                "WSMAN",
                "SNMP",
                "REDFISH"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "use": "Dell EMC Device Inventory Information",
            "setservicestatus": 0,
            "requiredAdditionalComponent": "iDRAC"
        },
        "Subsystem": {
            "name": "Dell EMC Server Overall Health Status",
            "type": "basic",
            "protocol": [
                "WSMAN",
                "SNMP",
                "REDFISH"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "use": "Dell EMC Device Health Status"
        },
        "PhysicalDisk": {
            "name": "Dell EMC Server Physical Disk Status",
            "type": "advanced",
            "protocol": [
                "WSMAN",
                "SNMP"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "Sensors_Battery": {
            "name": "Dell EMC Server Battery Status",
            "type": "advanced",
            "protocol": [
                "WSMAN",
                "SNMP"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "Sensors_Fan": {
            "name": "Dell EMC Server Fan Status",
            "type": "advanced",
            "protocol": [
                "WSMAN",
                "SNMP",
                "REDFISH"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "Sensors_Intrusion": {
            "name": "Dell EMC Server Intrusion Status",
            "type": "advanced",
            "protocol": [
                "WSMAN",
                "SNMP"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "VirtualDisk": {
            "name": "Dell EMC Server Virtual Disk Status",
            "type": "advanced",
            "protocol": [
                "WSMAN",
                "SNMP"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "NIC": {
            "name": "Dell EMC Server Network Device Status",
            "type": "advanced",
            "protocol": [
                "WSMAN",
                "SNMP",
                "REDFISH"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "ConnectionStatus==Up",
            "use": "Dell EMC Device Component Status"
        },
        "Sensors_Voltage": {
            "name": "Dell EMC Server Voltage Probe Status",
            "type": "advanced",
            "protocol": [
                "WSMAN",
                "SNMP",
                "REDFISH"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "Sensors_Amperage": {
            "name": "Dell EMC Server Amperage Probe Status",
            "type": "advanced",
            "protocol": [
                "WSMAN",
                "SNMP"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "Controller": {
            "name": "Dell EMC Server Controller Status",
            "type": "advanced",
            "protocol": [
                "WSMAN",
                "SNMP",
                "REDFISH"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "Sensors_Temperature": {
            "name": "Dell EMC Server Temperature Probe  Status",
            "type": "advanced",
            "model": [
                "PowerEdge",
                "Default"
            ],
            "protocol": [
                "WSMAN",
                "SNMP",
                "REDFISH"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "CPU": {
            "name": "Dell EMC Server CPU Status",
            "type": "advanced",
            "protocol": [
                "WSMAN",
                "SNMP",
                "REDFISH"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "PowerSupply": {
            "name": "Dell EMC Server Power Supply Status",
            "type": "advanced",
            "model": [
                "PowerEdge",
                "Default"
            ],
            "protocol": [
                "WSMAN",
                "SNMP",
                "REDFISH"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "Memory": {
            "name": "Dell EMC Server Memory Status",
            "type": "advanced",
            "protocol": [
                "WSMAN",
                "SNMP"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "VFlash": {
            "name": "Dell EMC Server SD Card Status",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "FC": {
            "name": "Dell EMC Server FC NIC Status",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "excludeinstance": "ConnectionStatus==Up",
            "use": "Dell EMC Device Component Status"
        },
        "warranty": {
            "name": "Dell EMC Server Warranty Information",
            "type": "advanced",
            "protocol": [
                "WSMAN",
                "SNMP",
                "REDFISH"
            ],
            "model": [
                "PowerEdge",
                "Default"
            ],
            "use": "Dell EMC Device Inventory Information",
        }
    },
    "CMC": {
        "Trap": {
            "name": "Dell EMC Chassis Traps",
            "type": "basic",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "M1000e",
                "VRTX",
                "FX2",
                "FX2s"
            ],
            "use": "Dell EMC Traps",
        },
        "System": {
            "name": "Dell EMC Chassis Information",
            "type": "basic",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "M1000e",
                "VRTX",
                "FX2",
                "FX2s"
            ],
            "use": "Dell EMC Device Inventory Information",
            "setservicestatus": 0
        },
        "Subsystem": {
            "name": "Dell EMC Chassis Overall Health Status",
            "type": "basic",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "M1000e",
                "VRTX",
                "FX2",
                "FX2s"
            ],
            "use": "Dell EMC Device Health Status"
        },
        "warranty": {
            "name": "Dell EMC Chassis Warranty Information",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "M1000e",
                "VRTX",
                "FX2",
                "FX2s"
            ],
            "use": "Dell EMC Device Inventory Information"
        },
        "Fan": {
            "name": "Dell EMC Chassis Fan Status",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "M1000e",
                "VRTX",
                "FX2",
                "FX2s"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "PowerSupply": {
            "name": "Dell EMC Chassis Power Supply Status",
            "type": "advanced",
            "model": [
                "M1000e",
                "VRTX",
                "FX2",
                "FX2s"
            ],
            "protocol": [
                "WSMAN"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "IOModule": {
            "name": "Dell EMC Chassis I/O Module Status",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "M1000e",
                "VRTX",
                "FX2",
                "FX2s"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "ComputeModule": {
            "name": "Dell EMC Chassis Server Slot Information",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "M1000e",
                "VRTX",
                "FX2",
                "FX2s"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "StorageModule": {
            "name": "Dell EMC Chassis Storage Slot Information",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "M1000e",
                "VRTX",
                "FX2",
                "FX2s"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "Enclosure": {
            "name": "Dell EMC Chassis Enclosure Status",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "VRTX"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "Controller": {
            "name": "Dell EMC Chassis Controller Status",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "VRTX"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "PhysicalDisk": {
            "name": "Dell EMC Chassis Physical Disk Status",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "VRTX"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "VirtualDisk": {
            "name": "Dell EMC Chassis Virtual Disk Status",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "VRTX"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        },
        "PCIDevice": {
            "name": "Dell EMC Chassis PCIe Devices Status",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "VRTX",
                "FX2",
                "FX2s"
            ],
            "use": "Dell EMC Device Component Status",
            "setservicestatus": 0
        },
        "KVM": {
            "name": "Dell EMC Chassis KVM Status",
            "type": "advanced",
            "protocol": [
                "WSMAN"
            ],
            "model": [
                "VRTX",
                "FX2",
                "FX2s",
                "M1000e"
            ],
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Component Status"
        }
    },
    "EqualLogic": {
        "Trap": {
            "name": "Dell EMC Storage PS-Series Member Traps",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Member",
            "use": "Dell EMC Traps",
        },
        "TrapG": {
            "name": "Dell EMC Storage PS-Series Group Traps",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Group",
            "use": "Dell EMC Traps",
        },
        "System": {
            "name": "Dell EMC Storage PS-Series Group Information",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Group",
            "use": "Dell EMC Device Inventory Information",
            "setservicestatus": 0
        },
        "Volume": {
            "name": "Dell EMC Storage PS-Series Group Volume Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Group",
            "excludeinstance": "Status==online,Status==offline,Status==available (no new connections)",
            "use": "Dell EMC Device Component Status"
        },
        "StoragePool": {
            "name": "Dell EMC Storage PS-Series Group Storage Pool Information ",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Group",
            "setservicestatus": "0",
            "use": "Dell EMC Device Component Status"
        },
        "PhysicalDisk": {
            "name": "Dell EMC Storage PS-Series Member Physical Disk Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Member",
            "excludeinstance": "Status==online,Status==spare,Status==alt-sig,Status==replacement,Status==encrypted",
            "use": "Dell EMC Device Component Status"
        },
        "warranty": {
            "name": "Dell EMC Storage PS-Series Member Warranty Information",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Member",
            "use": "Dell EMC Device Inventory Information"
        },
        "Member": {
            "name": "Dell EMC Storage PS-Series Member Information",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Member",
            "use": "Dell EMC Device Inventory Information",
            "setservicestatus": 0
        },
        "Subsystem": {
            "name": "Dell EMC Storage PS-Series Member Overall Health Status",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Member",
            "use": "Dell EMC Device Health Status"
        }
    },
    "MDArray": {
        "Trap": {
            "name": "Dell EMC Storage MD-Series Traps",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "model": [
                "Default"
            ],
            "use": "Dell EMC Traps",
        },
        "System": {
            "name": "Dell EMC Storage MD-Series Information",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "model": [
                "Default"
            ],
            "use": "Dell EMC Device Inventory Information",
            "setservicestatus": 0
        },
        "warranty": {
            "name": "Dell EMC Storage MD-Series Warranty Information",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": [
                "Default"
            ],
            "use": "Dell EMC Device Inventory Information"
        },
        "Subsystem": {
            "name": "Dell EMC Storage MD-Series Overall Health Status",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "model": [
                "Default"
            ],
            "use": "Dell EMC Device Health Status"
        }
    },
    "Compellent": {
        "Trap": {
            "name": "Dell EMC Storage SC-Series Management Traps",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "DeviceType":
                "Management",
            "use": "Dell EMC Traps",
        },
        "TrapG": {
            "name": "Dell EMC Storage SC-Series Controller Traps",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "DeviceType":
                "Controller",
            "use": "Dell EMC Traps",
        },
        "System": {
            "name": "Dell EMC Storage SC-Series Information",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Management",
            "use": "Dell EMC Device Inventory Information",
            "setservicestatus": 0
        },
        "Volume": {
            "name": "Dell EMC Storage SC-Series Volume Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Management",
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Inventory Information"
        },
        "Disk": {
            "name": "Dell EMC Storage SC-Series Physical Disk Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Management",
            "excludeinstance": "Status==OK",
            "use": "Dell EMC Device Inventory Information"
        },
        "Controller": {
            "name": "Dell EMC Storage SC-Series Controller Information",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Controller",
            "use": "Dell EMC Device Inventory Information",
            "setservicestatus": 0
        },
        "Subsystem_Mgmt": {
            "name": "Dell EMC Storage SC-Series Overall Health Status",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Management",
            "use": "Dell EMC Device Health Status"
        },
        "warranty": {
            "name": "Dell EMC Storage SC-Series Controller Warranty Information",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Controller",
            "use": "Dell EMC Device Inventory Information"
        },
        "Subsystem_Ctrl": {
            "name": "Dell EMC Storage SC-Series Controller Overall Health Status",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "DeviceType": "Controller",
            "use": "Dell EMC Device Health Status"
        }
    },
    "F10": {
        "Trap": {
            "name": "Dell EMC Network Switch Traps",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "model":["Default"],
            "use": "Dell EMC Traps",
        },
        "System": {
            "name": "Dell EMC Network Switch Information",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Inventory Information"
        },
        "Subsystem": {
            "name": "Dell EMC Network Switch Overall Health Status",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Inventory Information"
        },
        "PowerSupply": {
            "name": "Dell EMC Network Switch PowerSupply Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "excludeinstance": "Status==OK"
        },
        "PowerSupplyTray": {
            "name": "Dell EMC Network Switch PowerSupplyTray Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "excludeinstance": "Status==Up"
        },
        "FanTray": {
            "name": "Dell EMC Network Switch FanTray Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "excludeinstance": "Status==Up"

        },
        "Fan": {
            "name": "Dell EMC Network Switch Fan Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "excludeinstance": "Status==OK"

        },
        "Processor": {
            "name": "Dell EMC Network Switch Processor Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "setservicestatus": 0
        },
        "warranty": {
            "name": "Dell EMC Network Switch Warranty Information",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Inventory Information"
        },
        "Flash": {
            "name": "Dell EMC Network Switch vFlash Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "setservicestatus": 0

        },
        "Port": {
            "name": "Dell EMC Network Switch Physical Port Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "excludeinstance": "Status==Up"
        }
    },
    "NSeries": {
        "Trap": {
            "name": "Dell EMC Network Switch Traps",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "model":["Default"],
            "use": "Dell EMC Traps",
        },
        "System": {
            "name": "Dell EMC Network Switch Information",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Inventory Information"
        },
        "Subsystem": {
            "name": "Dell EMC Network Switch Overall Health Status",
            "type": "basic",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Inventory Information"
        },
        "PowerSupply": {
            "name": "Dell EMC Network Switch PowerSupply Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "excludeinstance": "Status==OK"
        },
        "PowerSupplyTray": {
            "name": "Dell EMC Network Switch PowerSupplyTray Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "excludeinstance": "Status==OK"
        },
        "FanTray": {
            "name": "Dell EMC Network Switch FanTray Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "excludeinstance": "Status==OK"

        },
        "Fan": {
            "name": "Dell EMC Network Switch Fan Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "excludeinstance": "Status==OK"

        },
        "Processor": {
            "name": "Dell EMC Network Switch Processor Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "setservicestatus": 0
        },
        "warranty": {
            "name": "Dell EMC Network Switch Warranty Information",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Inventory Information"
        },
        "Flash": {
            "name": "Dell EMC Network Switch vFlash Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "setservicestatus": 0

        },
        "Port": {
            "name": "Dell EMC Network Switch Physical Port Status",
            "type": "advanced",
            "protocol": [
                "SNMP"
            ],
            "model": ["Default"],
            "use": "Dell EMC Device Component Status",
            "excludeinstance": "Status==Up"
        }
    }

}

device_data = {
    "iDRAC":
        {
            "hostgroup": "Dell EMC Agent-free Servers",
            "hostgroupXC": "Dell EMC XC",
            "hostgroupVxRail": "Dell EMC VxRail",
            "image": "idrac.png",
            "host_use": "Dell EMC Agent-free Server",
            "model": ["PowerEdge"],
            "title": "Dell EMC Agent-free Server host definition",
            "titleXC": "Dell EMC XC host definition",
            "titleVxRail": "Dell EMC VxRail host definition"
        },
    "CMC":
        {
            "hostgroup": "Dell EMC Chassis",
            "image": "chassis.png",
            "model": ["M1000e", "VRTX", "FX2", "FX2s"],
            "host_use": "Dell EMC Chassis",
            "title": "Dell EMC Chassis host definition"
        },
    "EqualLogic":
        {
            "hostgroup": "Dell EMC Storage",
            "image": "equallogic.png",
            "host_use": "Dell EMC Storage",
            "title": "Dell EMC Storage PS-Series host definition"
        },
    "MDArray":
        {
            "hostgroup": "Dell EMC Storage",
            "image": "MdArray.png",
            "host_use": "Dell EMC Storage",
            "title": "Dell EMC Storage MD-Series host definition"
        },
    "Compellent":
        {
            "hostgroup": "Dell EMC Storage",
            "image": "compellent.png",
            "host_use": "Dell EMC Storage",
            "title": "Dell EMC Storage SC-Series host definition"
        },
    "F10":
        {
            "hostgroup": "Dell EMC Networking",
            "image": "f10.png",
            "host_use": "Dell EMC Networking",
            "title": "Dell EMC Networking Switch  host definition"
        },
    "NSeries":{

            "hostgroup": "Dell EMC Networking",
            "image": "f10.png",
            "host_use": "Dell EMC Networking",
            "title": "Dell EMC Networking Switch host definition"
    }
}

protocol_map = {
    "1": "SNMP",
    "2": "WSMAN",
    "3": "REDFISH"
}
nagios_health = {
    0: "OK",
    2: "CRITICAL",
    3: "UNKNOWN",
    1: "WARNING"
}
#################################variables###########################
command = ""
host = ""
allservice = ""
filePath = ""
outputFile = ""
protocol = ""
service_tag = ""
device_type = ""
logLoc = ""
protocol_string = ""
model = ""
hostuse = ""
hostgroup = ""
image = ""
action_url = ""
fileType = ""
splcase_device = ""
subnet = ""
dyanamic_hostgrp = ""
input_file = ""
creds = ""
pOption = ""
force_discover = ""
application_logger = None
force_discover = False
ipProvided = 0
ipProcessed = 0
ipUnsuccess = 0
ipFileExists = 0
nagios_type = 0

criticalDays = ""
warningDays = ""
dir_path = ""
default_process = 16.0
# Warranty Service - Number of days left for critical status should be initialized with integer and value 0<X>365 
RemainingDaysCritical = 10

# Warranty Service - Number of days left for warning status
# 'RemainingDaysWarning' should be greater than 'RemainingDaysCritical'. 
# 'RemainingDaysWarning' and 'RemainingDaysCritical' value should be between 0 to 365
RemainingDaysWarning = 30

# Number of discovery process to be forked 
# process.count="10"

# DellEMC Warranty API server URL
WarrantyURL = "https://api.dell.com/support/assetinfo/v4/getassetwarranty/"

mergeSingleInstanceSpec = {
    "iDRAC": {
        "System": {
            "iDRAC": ["GroupStatus", "GroupName"]
        }
    }
}

nagiosxi_location="/usr/local/nagios/libexec"