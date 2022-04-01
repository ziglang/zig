import os
import unittest
from test import support

# skip tests if _ctypes was not built
ctypes = support.import_module('ctypes')
ctypes_symbols = dir(ctypes)

def need_symbol(name):
    return unittest.skipUnless(name in ctypes_symbols,
                               '{!r} is required'.format(name))

def load_tests(*args):
    return support.load_package_tests(os.path.dirname(__file__), *args)

def xfail(method):
    """
    Poor's man xfail: remove it when all the failures have been fixed
    """
    def new_method(self, *args, **kwds):
        try:
            method(self, *args, **kwds)
        except:
            pass
        else:
            self.assertTrue(False, "DID NOT RAISE")
    return new_method
