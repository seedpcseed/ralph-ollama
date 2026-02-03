import os

class FileEditor:
    def __init__(self, filepath):
        self.filepath = filepath
        
    def read_file(self):
        try:
            with open(self.filepath, 'r') as f:
                return f.read()
        except Exception as e:
            print('Failed to read the file:', e)
    
    def write_into_file(self, content):
        try:
            with open(self.filepath, 'w') as f:
                f.write(content)
        except Exception as e:
            print('Failed to write into the file:', e)
            
    def append_into_file(self, content):
        try:
            with open(self.filepath, 'a') as f:
                f.write('\n' + content)
        except Exception as e:
            print('Failed to append into the file:', e)