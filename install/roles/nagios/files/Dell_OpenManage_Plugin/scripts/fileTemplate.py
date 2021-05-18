
#############################################################################################
#Title:filetemplate.py
#Version:3.0 
#Creation Date: 01-Apr-2018
#Description: filetemplate.py is madeup with customizable formate.
#Copyright (c) 2018 Dell Inc. or its subsidiaries. All rights reserved. Dell, EMC,
#             and other trademarks are trademarks of Dell Inc. or its subsidiaries.
#			  Other trademarks may be trademarks of their respective owners.
############################################################################################
dellcommand = "dellemc_check_script! --devicetype={device}! --componentname={comp}! --protocol={protocol}! --logPath={logPath}!"
dellemc_warranty_command = "dellemc_warranty_check_script! --devicetype={device}! --componentname={comp}! --protocol={protocol}! --logPath={logPath}! --warranty.warningDays={w_wDays}!  --warranty.criticalDays={w_cDays}!"
logFileFormat = "{}_{}.info"
status_message_format = "{}: No response from remote host {}"
protocol_string_wsman = "{protocol}! --http.user={user}! --http.password={password}! --http.timeout={timeout}! --http.port={port}! --http.retries={retries}"
protocol_string_snmp = "{protocol}! --snmp.version={version}! --snmp.community={community}! --snmp.timeout={timeout}! --snmp.port={port}! --snmp.retries={retries}"

host_group_def = """

define hostgroup{{
        hostgroup_name          {hostGroup}
        alias                   {alias}
        }}

"""

host = """
        #======================================================================================
        #         {host_title}
        #======================================================================================
        define host{{
            use                     {host_use}
            host_name               {host_name}
            alias                   {alias}
            address                 {address}
            display_name            {display_name}
            icon_image              {icon_image}
            hostgroups              {hostgroups}
            statusmap_image         {statusmap_image}
            action_url              {action_url}
            _serviceTag             {serviceTag}
            notes                   {protocol}

        }}

"""

service_commented = """
 # define service{{
 #           use                   {service_use}
 #           host_name             {host_name}
 #           service_description   {service_description}
 #           check_command         {check_command}
 #   }}

"""
trap_service = """
 define service{{
             use                   {service_use}
             host_name             {host_name}
             service_description   {service_description}
  }}
"""
xml_host = """
<host>
<host_use>{host_use}</host_use>
<host_name>{host_name}</host_name>
<device_type>{device_type}</device_type>
<alias>{alias}</alias>
<address>{address}</address>
<display_name>{display_name}</display_name>
<icon_image>{icon_image}</icon_image>
<hostgroups>{hostgroups}</hostgroups>
<statusmap_image>{statusmap_image}</statusmap_image>
<check_command_name></check_command_name>
<dell_comm_params></dell_comm_params>
<serviceTag>{serviceTag}</serviceTag>
<model>{model}</model>
<device_subtype>{device_subtype}</device_subtype>
<notes>{protocol}</notes>
<action_url>{action_url}</action_url>
</host>
"""

xml_service = """
<service id='{service_description}'>
<use>{service_use}</use>
<host_name>{host_name}</host_name>
<service_description>{service_description}</service_description>
<check_command>{check_command}</check_command>
</service>
"""

xml_host_group_def = """
<hostgroup>
<hostgroup_name>{hostGroup}</hostgroup_name>
<alias>{alias}</alias>
</hostgroup>
"""