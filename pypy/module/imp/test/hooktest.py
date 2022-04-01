import sys, imp

__path__ = [ ]

class Loader(object):
    def __init__(self, file, filename, stuff):
        self.file = file
        self.filename = filename
        self.stuff = stuff

    def load_module(self, fullname):
        mod = imp.load_module(fullname, self.file, self.filename, self.stuff)
        if self.file:
            self.file.close()
        mod.__loader__ = self  # for introspection
        return mod

class Importer(object):
    def __init__(self, path):
        if path not in __path__:
            raise ImportError

    def find_module(self, fullname, path=None):
        if not fullname.startswith('hooktest'):
            return None

        _, mod_name = fullname.rsplit('.',1)
        found = imp.find_module(mod_name, path or __path__)

        return Loader(*found)
