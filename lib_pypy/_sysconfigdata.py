import _imp
import os
import sys
import struct
from shutil import which

so_ext = _imp.extension_suffixes()[0]

pydot = '%d.%d' % sys.version_info[:2]

build_time_vars = {
    'ABIFLAGS': '',
    # SOABI is PEP 3149 compliant, but CPython3 has so_ext.split('.')[1]
    # ("ABI tag"-"platform tag") where this is ABI tag only. Wheel 0.34.2
    # depends on this value, so don't make it CPython compliant without
    # checking wheel: it uses pep425tags.get_abi_tag with special handling
    # for CPython
    "SOABI": '-'.join(so_ext.split('.')[1].split('-')[:2]),
    "SO": so_ext,  # deprecated in Python 3, for backward compatibility
    'MULTIARCH': sys.implementation._multiarch,
    'CC': "cc -pthread",
    'CXX': "c++ -pthread",
    'OPT': "-DNDEBUG -O2",
    'CFLAGS': "-DNDEBUG -O2",
    'CCSHARED': "-fPIC",
    'LDFLAGS': "-Wl,-Bsymbolic-functions",
    'LDSHARED': "cc -pthread -shared -Wl,-Bsymbolic-functions",
    'EXT_SUFFIX': so_ext,
    'SHLIB_SUFFIX': ".so",
    'AR': "ar",
    'ARFLAGS': "rc",
    'EXE': "",
    'VERSION': pydot,
    'LDVERSION': pydot,
    'Py_DEBUG': 0,  # cpyext never uses this
    'Py_ENABLE_SHARED': 0,  # if 1, will add python so to link like -lpython3.7
    'SIZEOF_VOID_P': struct.calcsize("P"),
}

# LIBDIR should point to where the libpypy3.9-c.so file lives, on CPython
# it points to "mybase/lib". But that would require rethinking the PyPy
# packaging process which copies pypy3 and libpypy3.9-c.so to the
# "mybase/bin" directory. Only when making a portable build (the default
# for the linux buildbots) is there even a "mybase/lib" created, even so
# the mybase/bin layout is left untouched.
mybase = sys.base_prefix
if sys.platform == 'win32':
    build_time_vars['LDLIBRARY'] = 'libpypy3.9-c.dll'
    build_time_vars['INCLUDEPY'] = os.path.join(mybase, 'include')
    build_time_vars['LIBDIR'] = mybase
else:
    build_time_vars['LDLIBRARY'] = 'libpypy3.9-c.so'
    build_time_vars['INCLUDEPY'] = os.path.join(mybase, 'include', 'pypy' + pydot)
    build_time_vars['LIBDIR'] = os.path.join(mybase, 'bin')
    # try paths relative to sys.base_prefix first
    tzpaths = [
        os.path.join(mybase, 'share', 'zoneinfo'),
        os.path.join(mybase, 'lib', 'zoneinfo'),
        os.path.join(mybase, 'share', 'lib', 'zoneinfo'),
        os.path.join(mybase, '..', 'etc', 'zoneinfo'),
    ]
    # add absolute system paths if sys.base_prefix != "/usr"
    # (then we'd be adding duplicates)
    if mybase != '/usr':
        tzpaths.extend([
            '/usr/share/zoneinfo',
            '/usr/lib/zoneinfo',
            '/usr/share/lib/zoneinfo',
            '/etc/zoneinfo',
        ])
    build_time_vars['TZPATH'] = ':'.join(tzpaths)

if which("gcc"):
    build_time_vars.update({
        "CC": "gcc -pthread",
        "GNULD": "yes",
        "LDSHARED": "gcc -pthread -shared" + " " + build_time_vars["LDFLAGS"] ,
    })
    if which("g++"):
        build_time_vars["CXX"] = "g++ -pthread"

if sys.platform[:6] == "darwin":
    # Fix this if we ever get M1 support
    arch = 'x86_64'
    build_time_vars['CC'] += ' -arch %s' % (arch,)
    build_time_vars["LDFLAGS"] = "-undefined dynamic_lookup"
    build_time_vars["LDSHARED"] = build_time_vars['CC'] + " -shared " + build_time_vars["LDFLAGS"]
    build_time_vars['LDLIBRARY'] = 'libpypy3.9-c.dylib'
    # scikit-build checks this, it is left over from the NextStep rld linker
    build_time_vars['WITH_DYLD'] = 1
    if "CXX" in build_time_vars:
        build_time_vars['CXX'] += ' -arch %s' % (arch,)
    # This was added to solve problems that may have been
    # solved elsewhere. Can we remove it? See cibuildwheel PR 185 and
    # pypa/wheel. Need to check: interaction with build_cffi_imports.py
    #
    # In any case, keep this in sync with DARWIN_VERSION_MIN in
    # rpython/translator/platform/darwin.py and Lib/_osx_support.py
    build_time_vars['MACOSX_DEPLOYMENT_TARGET'] = '10.9'

