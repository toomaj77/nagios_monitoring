
#############################################################################################
#Title:dellemc_nagios_helper_tool.py
#Version:3.0 
#Creation Date: 01-Apr-2018 
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



