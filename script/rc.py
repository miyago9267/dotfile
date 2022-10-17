from fileinput import filename
import sys
import os
import re

class run:
    class java:
        def __init__(self, *args):
            self.args = args
            try:
                os.system('javac' + ' ' + ' '.join(self.args))
                if (os.path.isfile(filename())):
                    os.system('java')
            except:
                print('Error: java not found')

    class cpp:
        def __init__(self, *args):
            self.args = args

    def fileCheck(self, name):
        reg = r'([a-zA-Z0-9_]+).(java|cpp|py)'
        self.filename = re.search(reg, name, re.I).group(1)
        ext = re.search(reg, name, re.I).group(2)
        if ext == '':
            for file in os.listdir(os.getcwd()):
                if file.startswith(self.filename):
                    self.ext = re.search(reg, file, re.I).group(2)
                    return True
        elif os.path.exists(name + '.' + ext):
            return True
        else:
            print('Error: File not found')
            sys.exit()

    def __init__(self, *args):
        self.args = args
        self.fileName = self.args[0]
        if self.fileCheck(*args[0]):
            if self.ext == 'java':
                self.java(*args)
            elif self.ext == 'cpp':
                self.cpp(*args)

if __name__ == "__main__":
    run(*sys.argv)