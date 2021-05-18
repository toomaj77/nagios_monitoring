
#############################################################################################
#Title:log.py
#Version:3.0 
#Creation Date: 01-Apr-2018
#Description: log.py, implementation of logging mechanisum.
#Copyright (c) 2018 Dell Inc. or its subsidiaries. All rights reserved. Dell, EMC,
#             and other trademarks are trademarks of Dell Inc. or its subsidiaries.
#			  Other trademarks may be trademarks of their respective owners.
############################################################################################
import logging
from logging import INFO
import sys
import datetime,time,nagios_properties,os,fileTemplate

class NagiosLogger(object):
    def __init__(self, name,file, format="%(asctime)s | %(levelname)s | %(message)s",level=INFO):

        self.format = format
        self.level = level
        self.name = name
        self.file = file


        self.file_formatter = logging.Formatter(self.format)
        self.file_handler    = logging.FileHandler(self.file)
        self.file_handler.setFormatter(self.file_formatter)
        self.logger = logging.getLogger(self.name)
        self.logger.addHandler(self.file_handler)



    def info(self, msg):
        self.logger.info(msg)

    def error(self, msg):
        self.logger.error(msg)

    def writeLog(self,string):
        if self.logger.level != 40:
            self.logger.info(string)
        else :
            self.logger.error(string)

    def setLevel(self,level):
            loglevel = getattr(logging, level.upper(), 10)
            self.logger.level=loglevel
            self.file_handler.setLevel(loglevel)

