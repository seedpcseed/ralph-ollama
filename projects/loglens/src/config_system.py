import configparser
from pathlib import Path

class ConfigManager:
    def __init__(self):
        self.config = configparser.ConfigParser()
        
    def load(self, filepath):
        self.config.read(filepath)   # read the configuration from the specified INI file
        
    def get_setting(self, section, key):
        return self.config.get(section, key)   # fetch a setting from the configuration