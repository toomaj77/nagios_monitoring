
#############################################################################################
#Title:dellemc_nagios_discovery_service_utility.py
#Version:3.0 
#Creation Date: 01-Apr-2018
#Description: dellemc_nagios_discovery_service_utility.py, used for dell emc device discovery.
#Copyright (c) 2018 Dell Inc. or its subsidiaries. All rights reserved. Dell, EMC,
#             and other trademarks are trademarks of Dell Inc. or its subsidiaries.
#			  Other trademarks may be trademarks of their respective owners.
############################################################################################
from dellemc_helper_utility import parse_argument,process_command
try:
    results = parse_argument()
    process_command(results)
except ImportError as details:
    print(details)



