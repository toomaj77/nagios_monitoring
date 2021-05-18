
######################################################################################
#Title:dellemc_check_warranty.py
#Version:3.0 
#Creation Date: 01-Apr-2018
#Description: dellemc_check_warranty.py is a plugin that contains Dell EMC device
#             warranty information and telling its current status.
#Copyright (c) 2018 Dell Inc. or its subsidiaries. All rights reserved. Dell, EMC,
#             and other trademarks are trademarks of Dell Inc. or its subsidiaries.
#			  Other trademarks may be trademarks of their respective owners.
#####################################################################################

import os
from dellemc_device_data_extractor import *
import nagios_properties
from log import NagiosLogger
import subprocess
nagios_properties.dir_path = os.path.dirname(os.path.realpath(__file__))
daysList = {}
criticalDays= None
warningDays= None
apiURL = None
warningDaysDefault = 70
criticalDaysDefault = 40
apiURLDefault = "https://api.dell.com/support/assetinfo/v4/getassetwarranty/"
serviceTag= None
jarFile = nagios_properties.dir_path + '/dell_OMC_Nagios_Warranty_v_3_0.jar'
readFilevalue=False
file_criticalDays=nagios_properties.RemainingDaysCritical
OK       = 0
WARNING  = 1
CRITICAL = 2
UNKNOWN  = 3


def call_zero_initialize_negative_value():
    global criticalDays, warningDays
    criticalDays = 0
    warningDays = 0
    
    
def call_morethanyear_value(stringValue):
       global criticalDays, warningDays 
       if (stringValue== "critical"):
         criticalDays=365
       elif(stringValue == "warning"):
         warningDays=365
         
def default_setting():
   global criticalDays, warningDays
   warningDays=warningDaysDefault
   criticalDays=criticalDaysDefault
         
         
def check_criticaldays_more_warningdays(re_criticalDays,  re_warningDays):
       global criticalDays, warningDays
       if (re_criticalDays > re_warningDays):
            warningDays = re_criticalDays
            
def readtheCfgFile(re_criticalDays = nagios_properties.RemainingDaysCritical, re_warningDays = nagios_properties.RemainingDaysWarning , readtheFile_userip = 0):
  global criticalDays, warningDays, apiURL
  apiURL = nagios_properties.WarrantyURL
  if (readtheFile_userip != 1):
      warningDays = re_warningDays
  if (readtheFile_userip != 2):
      criticalDays = re_criticalDays
  if (len(apiURL) == 0):
      apiURL = apiURLDefault
  if (warningDays == None and criticalDays == None and readtheFile_userip == 0):
         default_setting()  
  elif((warningDays < 0 and warningDays != None and readtheFile_userip == 0) or (criticalDays < 0 and criticalDays != None and readtheFile_userip == 0)):
         call_zero_initialize_negative_value()  
  else:
      if (warningDays > 365):
         call_morethanyear_value("warning")
      if (warningDays < 0  and readtheFile_userip == 2):
          warningDays = warningDaysDefault
      if (criticalDays < 0  and readtheFile_userip == 1):
          criticalDays = criticalDaysDefault 
      if (criticalDays > 365):
         call_morethanyear_value("critical")
      if (criticalDays == None and readtheFile_userip != 2):
         criticalDays=criticalDaysDefault 
      if (warningDays == None and readtheFile_userip != 1):
         warningDays=warningDaysDefault
 

def readUserinput_warranty(re_usr_ipCrit, re_usr_ipWarn):
   global readFilevalue, criticalDays, warningDays
   if (re_usr_ipCrit == "None"):
       criticalDays = None
   else:
       criticalDays = int(re_usr_ipCrit)
   if (re_usr_ipWarn == "None"):
       warningDays = None
   else:
       warningDays = int(re_usr_ipWarn)
   if (criticalDays == None and warningDays == None):
        readFilevalue=True
   elif ((criticalDays < 0 and criticalDays != None )or (warningDays < 0 and warningDays != None)):
         call_zero_initialize_negative_value()
   else:
        if (criticalDays > 365 and criticalDays != None): 
           call_morethanyear_value("citical")
        if (warningDays > 365 and warningDays != None):
            call_morethanyear_value("warning")
        if (criticalDays == None ):
            readtheCfgFile(re_warningDays=None, readtheFile_userip=1)
        if (warningDays == None):
            readtheCfgFile(re_criticalDays=None, readtheFile_userip=2)     
            
def get_serviceTag(device,address):
   comp = ["System"]
   device.get_partial_entityjson_str(*comp)
   dev = device.entityjson
   global deviceType
   serviceTag="NA"
   deviceType = get_device_type(dev)
   if deviceType in [ "Server","CMC","F10","NSeries"]:
      serviceTag=get_device_serviceTag(dev)

   elif deviceType == "EqualLogic":
       if (get_equallogic_device_type(dev) == "EqualLogic Member") :
           serviceTag = get_equallogic_member_svctag(dev)
       else :
           serviceTag = "NA"
   elif deviceType == "Compellent":
       if get_compellent_managementIp(dev) == address:
           serviceTag = "NA"
       else :
           isIpV6 = is_valid_ipv6_address(address)
           serviceTag = get_compellent_controller_svctag(dev,address,isIpV6)
           
   elif deviceType == "MDArray":
          serviceTag=get_device_serviceTag(dev)
          if  "SVC " in serviceTag:
            serviceTag = serviceTag.replace('SVC ', '')
   
   return serviceTag   

def check_warranty(re_usr_ipCrit, re_usr_ipWarn,device_obj,address):
      global apiURL
      readUserinput_warranty(re_usr_ipCrit, re_usr_ipWarn)
      if (readFilevalue == True):
           readtheCfgFile()
      else:
          apiURL = apiURLDefault      
      check_criticaldays_more_warningdays(criticalDays , warningDays)
      serviceTag=get_serviceTag(device_obj,address)
      cmd=subprocess.Popen(['java', '-jar', jarFile, serviceTag, apiURL, str(criticalDays), str(warningDays)], stdout=subprocess.PIPE)
      apiOutput=str(cmd.stdout.read())
      words=apiOutput.split("~~~")
      printmsg = words[1]
      tmpExitCode = words[0]
      splittmpExitCode = tmpExitCode.split("=")
      final_exit_code = splittmpExitCode[1]
      print (printmsg)
      exit(int(final_exit_code))
          