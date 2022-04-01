
""" A distutils-patching tool that allows testing CPython extensions without
building pypy-c.

Run python <this file> setup.py build in your project directory

You can import resulting .so with py.py --allworkingmodules
"""

import sys, os
dn = os.path.dirname
rootdir = dn(dn(dn(dn(__file__))))
sys.path.insert(0, rootdir)
from rpython.tool.udir import udir
pypydir = os.path.join(rootdir, 'pypy')
f = open(os.path.join(str(udir), 'pyconfig.h'), "w")
f.write("\n")
f.close()
sys.path.insert(0, os.getcwd())
from distutils import sysconfig

from pypy.tool.pytest.objspace import gettestobjspace
from pypy.module.cpyext.api import build_bridge
from pypy.module.imp.importing import get_so_extension

usemodules = ['cpyext', 'thread']
if sys.platform == 'win32':
    usemodules.append('_winreg') # necessary in distutils
space = gettestobjspace(usemodules=usemodules)

inc_paths = str(udir)

def get_python_inc(plat_specific=0, prefix=None):
    if plat_specific:
        return str(udir)
    return os.path.join(os.path.dirname(__file__), 'include')

def patch_distutils():
    sysconfig.get_python_inc = get_python_inc
    sysconfig.get_config_vars()['SO'] = get_so_extension(space)

patch_distutils()

del sys.argv[0]
execfile(sys.argv[0], {'__file__': sys.argv[0], '__name__': '__main__'})
