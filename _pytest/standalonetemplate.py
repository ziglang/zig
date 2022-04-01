#! /usr/bin/env python

# Hi There!
# You may be wondering what this giant blob of binary data here is, you might
# even be worried that we're up to something nefarious (good for you for being
# paranoid!). This is a base64 encoding of a zip file, this zip file contains
# a fully functional basic pytest script.
#
# Pytest is a thing that tests packages, pytest itself is a package that some-
# one might want to install, especially if they're looking to run tests inside
# some package they want to install. Pytest has a lot of code to collect and
# execute tests, and other such sort of "tribal knowledge" that has been en-
# coded in its code base. Because of this we basically include a basic copy
# of pytest inside this blob. We do this  because it let's you as a maintainer
# or application developer who wants people who don't deal with python much to
# easily run tests without installing the complete pytest package.
#
# If you're wondering how this is created: you can create it yourself if you
# have a complete pytest installation by using this command on the command-
# line: ``py.test --genscript=runtests.py``.

sources = """
@SOURCES@"""

import sys
import base64
import zlib

class DictImporter(object):
    def __init__(self, sources):
        self.sources = sources

    def find_module(self, fullname, path=None):
        if fullname == "argparse" and sys.version_info >= (2,7):
            # we were generated with <python2.7 (which pulls in argparse)
            # but we are running now on a stdlib which has it, so use that.
            return None
        if fullname in self.sources:
            return self
        if fullname + '.__init__' in self.sources:
            return self
        return None

    def load_module(self, fullname):
        # print "load_module:",  fullname
        from types import ModuleType
        try:
            s = self.sources[fullname]
            is_pkg = False
        except KeyError:
            s = self.sources[fullname + '.__init__']
            is_pkg = True

        co = compile(s, fullname, 'exec')
        module = sys.modules.setdefault(fullname, ModuleType(fullname))
        module.__file__ = "%s/%s" % (__file__, fullname)
        module.__loader__ = self
        if is_pkg:
            module.__path__ = [fullname]

        do_exec(co, module.__dict__) # noqa
        return sys.modules[fullname]

    def get_source(self, name):
        res = self.sources.get(name)
        if res is None:
            res = self.sources.get(name + '.__init__')
        return res

if __name__ == "__main__":
    try:
        import pkg_resources  # noqa
    except ImportError:
        sys.stderr.write("ERROR: setuptools not installed\n")
        sys.exit(2)
    if sys.version_info >= (3, 0):
        exec("def do_exec(co, loc): exec(co, loc)\n")
        import pickle
        sources = sources.encode("ascii") # ensure bytes
        sources = pickle.loads(zlib.decompress(base64.decodebytes(sources)))
    else:
        import cPickle as pickle
        exec("def do_exec(co, loc): exec co in loc\n")
        sources = pickle.loads(zlib.decompress(base64.decodestring(sources)))

    importer = DictImporter(sources)
    sys.meta_path.insert(0, importer)
    entry = "@ENTRY@"
    do_exec(entry, locals()) # noqa
