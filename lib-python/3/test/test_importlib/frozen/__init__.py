import os
import unittest
from test.support import load_package_tests, check_impl_detail

def load_tests(*args):
    return load_package_tests(os.path.dirname(__file__), *args)


if check_impl_detail(pypy=True):
    raise unittest.SkipTest("PyPy doesn't have frozen modules")
