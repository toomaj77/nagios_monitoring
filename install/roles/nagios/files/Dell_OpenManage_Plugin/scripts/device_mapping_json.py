
#############################################################################################
#Title:device_mapping_json.py
#Version:3.0 
#Creation Date: 01-Apr-2018
#Description: device_mapping_json.py, contains the attribute list for each component of the device.
#Copyright (c) 2018 Dell Inc. or its subsidiaries. All rights reserved. Dell, EMC,
#             and other trademarks are trademarks of Dell Inc. or its subsidiaries.
#			  Other trademarks may be trademarks of their respective owners.
############################################################################################
device_comp_attr_map = {
   "iDRAC":{
      "System":{
         "HostName":"Server Host FQDN",
         "Model":"Model",
         "SystemGeneration":"System Generation",
         "ServiceTag":"ServiceTag",
         "OSName":"OS Name",
         "OSVersion":"OS Version",
         "ChassisServiceTag":"Chassis ServiceTag",
         "LifecycleControllerVersion":"iDRAC Firmware Version",
         "NodeID":"Node Id",
         "iDRACURL":"iDRAC URL",
         "SystemLockDown":"System Configuration Lockdown Mode",
         "GroupStatus":"iDRAC GroupManager Status",
         "GroupName":"iDRAC Group Name",
         "VirtualAddressManagementApplication":"VMM URL"

      },
      "Subsystem":{
         "System":"Overall System",
         "PowerSupply":"Power Supply",
         "Storage":"Storage",
         "Memory":"Memory",
         "CPU":"CPU",
         "Sensors_Voltage":"Voltage",
         "Sensors_Temperature":"Temperature",
         "Sensors_Battery":"Battery",
         "Sensors_Fan":"Fan",
         "Sensors_Intrusion":"Intrusion",
         "Sensors_Amperage":"Amperage"
      },
      "PhysicalDisk":{
         "PrimaryStatus":"Status",
         "DeviceDescription":"FQDD",
         "RaidStatus":"State",
         "Revision":"Revision",
         "MediaType":"MediaType",
         "Model":"ProductID",
         "SerialNumber":"SerialNumber",
         "Size":"Size"
      },
      "VirtualDisk":{
         "PrimaryStatus":"Status",
         "FQDD":"FQDD",
         "RAIDStatus":"State",
         "RAIDTypes":"Layout",
         "MediaType":"MediaType",
         "ReadCachePolicy":"ReadCachePolicy",
         "Size":"Size",
         "StripeSize":"StripeSize",
         "WriteCachePolicy":"WriteCachePolicy"
      },
      "CPU":{
         "PrimaryStatus":"Status",
         "FQDD":"FQDD",
         "NumberOfProcessorCores":"CoreCount",
         "Model":"Model"
      },
      "Memory":{
         "PrimaryStatus":"Status",
         "FQDD":"FQDD",
         "PartNumber":"PartNumber",
         "Size":"Size",
         "MemoryType":"Type",
         "CurrentOperatingSpeed":"Speed",
         "memoryDeviceStateSettings":"State"
      },
      "Controller":{
         "PrimaryStatus":"Status",
         "FQDD":"FQDD",
         "CacheSize":"CacheSize",
         "ControllerFirmwareVersion":"FirmwareVersion",
         "ProductName":"Name"
      },
      "PowerSupply":{
         "PrimaryStatus":"Status",
         "FQDD":"FQDD",
         "Range1MaxInputPower":"InputWattage",
         "FirmwareVersion":"FirmwareVersion",
         "Redundancy":"Redundancy"
      },
      "NIC":{
         "LinkStatus":"ConnectionStatus",
         "FamilyVersion":"FirmwareVersion",
         "FQDD":"FQDD",
         "LinkSpeed":"LinkSpeed",
         "ProductName":"ProductName"
      },
      "Sensors_Temperature":{
         "Location":"Location",
         "State":"State",
         "PrimaryStatus":"Status"
      },
      "Sensors_Voltage":{
         "PrimaryStatus":"Status",
         "Location":"Location",
         "State":"State"
      },
      "Sensors_Fan":{
         "PrimaryStatus":"Status",
         "Location":"FQDD",
         "State":"State"
      },
      "Sensors_Battery":{
         "PrimaryStatus":"Status",
         "Location":"Location",
         "State":"State"
      },
      "Sensors_Amperage":{
         "PrimaryStatus":"Status",
         "Location":"Location",
         "State":"State"
      },
      "Sensors_Intrusion":{
         "PrimaryStatus":"Status",
         "Location":"Location",
         "State":"State"
      },
      "VFlash":{
         "PrimaryStatus":"Status",
         "DeviceDescription":"FQDD",
         "VFlashEnabledState":"vFalshEnabledState",
         "InitializedState":"InitializedState",
         "WriteProtected":"WriteProtected",
         "Capacity":"Size"
      },
      "FC":{
         "PortStatus":"ConnectionStatus",
         "FQDD":"FQDD",
         "FamilyVersion":"FirmwareVersion",
         "PortSpeed":"LinkSpeed",
         "DeviceName":"Name"
      }
   },
   "CMC":{
      "System":{
         "DNSCMCName":"Chassis Name",
         "Model":"Model Name",
         "ServiceTag":"Service Tag",
         "MgmtControllerFirmwareVersion":"CMC Firmware Version",
         "URLString":"CMC URL"
      },
      "Subsystem":{
          "CMC": "Overall Chassis"
      },
      "PowerSupply":{
         "HealthState":"Status",
         "DeviceID":"FQDD",
         "Name":"Name",
         "PartNumber":"PartNumber",
         "Slot":"Slot"
      },
      "Fan":{
         "HealthState":"Status",
         "DeviceID":"FQDD",
         "ElementName":"Name",
         "SlotNumber":"Slot"
      },
      "IOModule":{
         "PrimaryStatus":"Status",
         "DeviceID":"FQDD",
         "Model":"Name",
         "PartNumber":"PartNumber",
         "Name":"Slot",
         "IPv4Address":"IPv4Address",
         "LinkTechnologies":"FabricType",
         "IOMURL":"LaunchURL"
      },
      "KVM":{
         "HealthState":"Status",
         "Name":"Name"
      },
      "Enclosure":{
         "PrimaryStatus":"Status",
         "FQDD":"FQDD",
         "ServiceTag":"ServiceTag",
         "BayID":"BayID",
         "Connector":"Connector",
         "Version":"FirmwareVersion",
         "SlotCount":"SlotCount"
      },
      "Controller":{
         "PrimaryStatus":"Status",
         "FQDD":"FQDD",
         "ProductName":"Name",
         "CacheSizeInMB":"CacheSize",
         "ControllerFirmwareVersion":"FirmwareVersion",
         "DeviceCardSlotType":"SlotType",
         "SecurityStatus":"SecurityStatus",
         "PatrolReadState":"PatrolReadState"
      },
      "PhysicalDisk":{
         "PrimaryStatus":"Status",
         "FQDD":"FQDD",
         "Model":"Model",
         "PPID":"PartNumber",
         "Slot":"Slot",
         "Revision":"FirmwareVersion",
         "Capacity":"Capacity",
         "UsedSizeInBytes":"FreeSpace",
         "MediaType":"MediaType",
         "SecurityState":"SecurityState"
      },
      "VirtualDisk":{
         "PrimaryStatus":"Status",
         "FQDD":"FQDD",
         "Name":"Name",
         "Capacity":"Capacity",
         "MediaType":"MediaType",
         "StripeSize":"StripeSize",
         "ReadCachePolicy":"ReadPolicy",
         "WriteCachePolicy":"WritePolicy",
         "RAIDTypes":"RAIDTypes",
         "BusProtocol":"BusProtocol"
      },
      "PCIDevice":{
         "Description":"Name",
         "SlotFQDD":"FQDD",
         "Fabric":"Fabric",
         "PowerStateStatus":"PowerState",
         "AssignedBladeSlotFQDD":"AssignedSlot",
         "AssignedBladeFQDD":"AssignedBlade",
         "NumberDescription":"PCIeSlot"
      },
      "ComputeModule":{
         "PrimaryStatus":"Status",
         "SlotNumber":"SlotNumber",
         "HostName":"HostName",
         "Model":"Model",
         "ServiceTag":"ServiceTag",
         "IPv4Address":"iDRACIP"
      },
      "StorageModule":{
         "PrimaryStatus":"Status",
         "SlotNumber":"SlotNumber",
         "Model":"Model",
         "ServiceTag":"ServiceTag"
      }
   },
   "MDArray":{
      "System":{
         "Status":"Overall Storage Array",
         "ServiceTag":"ServiceTag",
         "ProductID":"ProductID",
         "WWID":"World-wide ID",
         "Name":"Storage Name"
      }
   },
   "EqualLogic":{
      "System":{
         "GroupName":"Group Name",
         "MemberCount":"Member Count",
         "VolumeCount":"Volume Count",
         "DeviceType":"Device Type",
         "GroupURL":"Group URL"
      },
      "Member":{
         "PrimaryStatus":"Overall Member",
         "Name":"Member Name",
         "ProductFamily":"Product Family",
         "Model":"Model Name",
         "ServiceTag":"ServiceTag",
         "ChassisType":"Chassis Type",
         "DiskCount":"Disk Count",
         "Capacity":"Capacity",
         "RaidStatus":"Raid Status",
         "ControllerMajorVersion":"Firmware Version",
         "RAIDPolicy":"RAID Policy",
          "GroupName":"Group Name",
          "GroupIP":"Group IP",
          "StoragePool":"Storage Pool"
      },
      "PhysicalDisk":{
         "Status":"Status",
         "Slot":"Slot",
         "FirmwareVersion":"FirmwareVersion",
         "Model":"Model",
         "SerialNumber":"SerialNumber",
         "TotalSize":"TotalSize"
      },
      "Volume":{
         "PrimaryStatus":"Status",
         "Name":"Name",
         "TotalSize":"TotalSize",
         "AssociatedPool":"Associated Pool"
      },
      "StoragePool":{
         "StorageName":"Name",
         "MemberCount":"MemberCount",
         "VolumeCount":"VolumeCount"
      },
      "Subsystem":{
         "PrimaryStatus":"Overall Member"
      }
   },
    "Compellent":{
      "System":{
         "Version":"FirmwareVersion",
         "URLString":"Compellent URL",
         "PrimaryControllerName":"Primary Controller Name",
         "PrimaryControllerModel":"Primary Controller Model",
         "PrimaryControllerIPAddress":"Primary Controller IP Address",
         "PrimaryControllerServiceTag": "Primary Controller ServiceTag",
         "SecondaryControllerName":"Secondary Controller Name",
         "SecondaryControllerModel":"Secondary Controller Model",
         "SecondaryControllerIPAddress":"Secondary Controller IP Address",
         "SecondaryControllerServiceTag":"Secondary Controller ServiceTag",
         "Name":"Storage Name",
         "PrimaryStatus":"Overall Storage Center" 

      },
      "Controller":{
         "ServiceTag":"ServiceTag",
         "Name":"Controller Name",
         "Model":"Model Name",
         "Leader":"Primary Controller",
         "Status":"Overall Controller",
         "URLString":"Compellent URL"
      },
      "Disk":{
         "Status":"Status",
         "Position":"Name",
         "Size":"TotalSize(GB)",
         "Enclosure":"DiskEnclosureNumber",
         "IoPortType":"BusType"
      },
      "Volume":{
         "Status":"Status",
         "Name":"VolumeName"
      }
   },
   "F10":{
          "System":{
              "ServiceTag":"ServiceTag",
              "Model":"Model",
              "NetwUSerialNo":"SerialNumber",
              "NetwUMACAddress":"MACAddress",
              "Location":"Location",
              "FirmwareVersion":"Firmware Version",
              "PrimaryStatus":"Overall Switch",
              "ipAdEntAddr":"ManagementIP",
              "Hostname":"Hostname"

          },
         "PowerSupply":{
            "Index":"Index",
             "OperStatus":"Status",
             "Description":"Description",
             "Source":"Source"

         },
         "Processor":{
             "Index":"Index",
             "Module":"ProcessorModule",
             "AvailableMemSize":"ProcessorMemSize"
         },
         "Flash":{
             "PartitionName":"Name",
             "PartitionSize":"Size",
             "PartitionMountPoint":"MountPoint"
         },
         "FanTray":{
             "OperStatus":"Status",
             "FanDeviceIndex":"TrayIndex",
             "Type":"Type",
             "PiecePartID":"PartNumber",
             "ServiceTag":"ServiceTag"
         },
        "Subsystem":{
         "PrimaryStatus":"Overall Switch"
        },
       "Port": {
           "Status": "Status",
           "Type": "Type",
           "SysIfName":"Name"

       },
      "Fan":{
          "Index":"Index",
          "Description":"Description",
          "OperStatus":"Status"
      },
      "PowerSupplyTray":{
          "OperStatus":"Status",
          "PowerDeviceIndex":"Index",
          "PowerDeviceType":"Type",
          "PiecePartID":"PartNumber",
          "PPIDRevision":"PPIDVersion",
          "ServiceTag":"ServiceTag"

      }


   },
   "NSeries":{
        "System":{
              "ServiceTag":"ServiceTag",
              "Model":"Model",
              "NetwUSerialNo":"SerialNumber",
              "NetwUMACAddress":"MACAddress",
              "Location":"Location",
              "FirmwareVersion":"Firmware Version",
              "PrimaryStatus":"Overall Switch",
              "ipAdEntAddr":"ManagementIP",
              "Hostname":"Hostname"

          },
        "PowerSupply":{
            "Index":"Index",
             "OperStatus":"Status",
             "Description":"Description",
             "Source":"Source"

         },
        "Processor":{
             "Index":"Index",
             "Module":"ProcessorModule",
             "AvailableMemSize":"ProcessorMemSize"
         },

        "Flash":{
             "PartitionName":"Name",
             "PartitionSize":"Size",
             "PartitionMountPoint":"MountPoint"
         },

        "FanTray":{
             "OperStatus":"Status",
             "FanDeviceIndex":"TrayIndex",
             "Type":"Type",
             "PiecePartID":"PartNumber",
             "ServiceTag":"ServiceTag"
        },

        "Subsystem":{
         "PrimaryStatus":"Overall Switch"
        },

        "Port": {
           "Status": "Status",
           "Type": "Type",
           "SysIfName":"Name"

        },

        "Fan":{
          "Index":"Index",
          "Description":"Description",
          "OperStatus":"Status"
        },

        "PowerSupplyTray":{
          "OperStatus":"Status",
          "PowerDeviceIndex":"Index",
          "PowerDeviceType":"Type",
          "PiecePartID":"PartNumber",
          "PPIDRevision":"PPIDVersion",
          "ServiceTag":"ServiceTag"

        }


   }
}