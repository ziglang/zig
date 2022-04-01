"""
Version numbers exposed by PyPy through the 'sys' module.
"""

# Push imports into the functions so this can be imported by python3
# to fish out CPYTHON_VERSION

import os

#XXX # the release serial 42 is not in range(16)
CPYTHON_VERSION            = (3, 9, 12, "final", 0)
#XXX # sync CPYTHON_VERSION with patchlevel.h, package.py
CPYTHON_API_VERSION        = 1013   #XXX # sync with include/modsupport.h

# make sure to keep PYPY_VERSION in sync with:
#    module/cpyext/include/patchlevel.h
#    doc/conf.py
PYPY_VERSION               = (7, 3, 9, "final", 0)


import pypy
pypydir = pypy.pypydir
pypyroot = os.path.dirname(pypydir)
del pypy
from rpython.tool.version import get_repo_version_info

import time as t
gmtime = t.gmtime()
date = t.strftime("%b %d %Y", gmtime)
time = t.strftime("%H:%M:%S", gmtime)
del t

# ____________________________________________________________

def get_api_version(space):
    return space.newint(CPYTHON_API_VERSION)

def get_version_info(space):
    from pypy.interpreter import gateway
    app = gateway.applevel('''
    "NOT_RPYTHON"
    from _structseq import structseqtype, structseqfield
    class version_info(metaclass=structseqtype):
        __module__ = 'sys'
        name = 'sys.version_info'

        major        = structseqfield(0, "Major release number")
        minor        = structseqfield(1, "Minor release number")
        micro        = structseqfield(2, "Patch release number")
        releaselevel = structseqfield(3,
                           "'alpha', 'beta', 'candidate', or 'release'")
        serial       = structseqfield(4, "Serial release number")
    ''')

    w_version_info = app.wget(space, "version_info")
    # run at translation time
    return space.call_function(w_version_info, space.wrap(CPYTHON_VERSION))

def _make_version_template(PYPY_VERSION=PYPY_VERSION):
    ver = "%d.%d.%d" % (PYPY_VERSION[0], PYPY_VERSION[1], PYPY_VERSION[2])
    if PYPY_VERSION[3] != "final":
        ver = ver + "-%s%d" %(PYPY_VERSION[3], PYPY_VERSION[4])
    template = "%d.%d.%d (%s, %s, %s)\n[PyPy %s with %%s]" % (
        CPYTHON_VERSION[0],
        CPYTHON_VERSION[1],
        CPYTHON_VERSION[2],
        get_repo_version_info(root=pypyroot)[1],
        date,
        time,
        ver)
    assert template.count('%') == 1     # only for the "%s" near the end
    return template

_VERSION_TEMPLATE = _make_version_template()

def get_version(space):
    from rpython.rlib import compilerinfo
    return space.newtext(_VERSION_TEMPLATE % compilerinfo.get_compiler_info())

def get_winver(space):
    return space.newtext("%d.%d" % (
        CPYTHON_VERSION[0],
        CPYTHON_VERSION[1]))

def get_hexversion(space):
    return space.newint(tuple2hex(CPYTHON_VERSION))

def get_pypy_version_info(space):
    from pypy.interpreter import gateway
    app = gateway.applevel('''
    "NOT_RPYTHON"
    from _structseq import structseqtype, structseqfield
    class pypy_version_info(metaclass=structseqtype):
        __module__ = 'sys'
        name = 'sys.pypy_version_info'

        major        = structseqfield(0, "Major release number")
        minor        = structseqfield(1, "Minor release number")
        micro        = structseqfield(2, "Patch release number")
        releaselevel = structseqfield(3,
                           "'alpha', 'beta', 'candidate', or 'release'")
        serial       = structseqfield(4, "Serial release number")
    ''')

    ver = PYPY_VERSION
    w_pypy_version_info = app.wget(space, "pypy_version_info")
    # run at translation time
    return space.call_function(w_pypy_version_info, space.wrap(ver))

def get_subversion_info(space):
    # run at translation time
    return space.wrap(('PyPy', '', ''))

def get_repo_info(space):
    info = get_repo_version_info(root=pypyroot)
    if info:
        repo_tag, repo_version = info
        return space.newtuple([space.newtext('PyPy'),
                               space.newtext(repo_tag),
                               space.newtext(repo_version)])
    else:
        return space.w_None

def tuple2hex(ver):
    d = {'alpha':     0xA,
         'beta':      0xB,
         'candidate': 0xC,
         'final':     0xF,
         }
    subver = ver[4]
    if not (0 <= subver <= 9):
        subver = 0
    return (ver[0] << 24   |
            ver[1] << 16   |
            ver[2] << 8    |
            d[ver[3]] << 4 |
            subver)
