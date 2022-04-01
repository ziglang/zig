"""Support functions for testing scripts in the Tools directory."""
import contextlib
import importlib
import os.path
import unittest
from test import support


if support.check_sanitizer(address=True, memory=True):
    # bpo-46633: Skip the test because it is too slow when Python is built
    # with ASAN/MSAN: between 5 and 20 minutes on GitHub Actions.
    raise unittest.SkipTest("test too slow on ASAN/MSAN build")


basepath = os.path.normpath(
        os.path.dirname(                 # <src/install dir>
            os.path.dirname(                # Lib
                os.path.dirname(                # test
                    os.path.dirname(__file__)))))    # test_tools

toolsdir = os.path.join(basepath, 'Tools')
scriptsdir = os.path.join(toolsdir, 'scripts')

def skip_if_missing(tool=None):
    if tool:
        tooldir = os.path.join(toolsdir, tool)
    else:
        tool = 'scripts'
        tooldir = scriptsdir
    if not os.path.isdir(tooldir):
        raise unittest.SkipTest(f'{tool} directory could not be found')

@contextlib.contextmanager
def imports_under_tool(name, *subdirs):
    tooldir = os.path.join(toolsdir, name, *subdirs)
    with support.DirsOnSysPath(tooldir) as cm:
        yield cm

def import_tool(toolname):
    with support.DirsOnSysPath(scriptsdir):
        return importlib.import_module(toolname)

def load_tests(*args):
    return support.load_package_tests(os.path.dirname(__file__), *args)
