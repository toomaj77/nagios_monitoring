
#############################################################################################
#Title:ProtocolCreds.py
#Version:3.0 
#Creation Date: 01-Apr-2018
#Description: ProtocolCreds.py, configuring protocol credentials.
#Copyright (c) 2018 Dell Inc. or its subsidiaries. All rights reserved. Dell, EMC,
#             and other trademarks are trademarks of Dell Inc. or its subsidiaries.
#			  Other trademarks may be trademarks of their respective owners.
############################################################################################
class SNMPCreds:
    def __init__(self,version,commstring,port,retires,timeout):
        self.verion = version
        self.commstring = commstring
        self.port = port
        self.retries = retires
        self.timeout = timeout

    def get_version(self):
        return self.verion
    def get_snmpport(self):
        return self.port
    def get_snmpTimout(self):
        return self.timeout
    def get_snmpCommString(self):
        return self.commstring
    def get_snmpretries(self):
        return self.retries


class WSMANCreds:
    def __init__(self,  user,password,port,timeout,retires):
        self.port = port
        self.retries = retires
        self.timeout = timeout
        self.user = user
        self.password= password



    def get_wsmanport(self):
        return self.port

    def get_wsmanTimout(self):
        return self.timeout

    def get_wsmanuser(self):
        return self.user

    def get_wsmanpassword(self):
        return self.password

    def get_wsmanretries(self):
        return self.retries
