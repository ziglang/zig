"""
Logic to find sys.executable and the initial sys.path containing the stdlib
"""

import errno
import os
import stat
import sys

from rpython.rlib import rpath, rdynload
from rpython.rlib.rstring import assert_str0
from rpython.rlib.objectmodel import we_are_translated
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo

from pypy.interpreter.gateway import unwrap_spec
from pypy.module.sys.state import get as get_state
from pypy.module.sys.interp_encoding import _getfilesystemencoding

PLATFORM = sys.platform
_MACOSX = sys.platform == 'darwin'
_WIN32 = sys.platform == 'win32'


def _exists_and_is_executable(fn):
    # os.access checks using the user's real uid and gid.
    # Since pypy should not be run setuid/setgid, this
    # should be sufficient.
    return os.path.isfile(fn) and os.access(fn, os.X_OK)


def find_executable(executable):
    """
    Return the absolute path of the executable, by looking into PATH and
    the current directory.  If it cannot be found, return ''.
    """
    if (we_are_translated() and _WIN32 and
        not executable.lower().endswith('.exe')):
        executable += '.exe'
    if os.sep in executable or (_WIN32 and ':' in executable):
        # the path is already more than just an executable name
        pass
    else:
        path = os.environ.get('PATH')
        if path:
            for dir in path.split(os.pathsep):
                fn = os.path.join(dir, executable)
                if _exists_and_is_executable(fn):
                    executable = fn
                    break
    executable = rpath.rabspath(executable)

    # 'sys.executable' should not end up being an non-existing file;
    # just use '' in this case. (CPython issue #7774)
    return executable if _exists_and_is_executable(executable) else ''


def _readlink_maybe(filename):
    if not _WIN32:
        return os.readlink(filename)
    raise NotImplementedError


def resolvedirof(filename):
    filename = rpath.rabspath(filename)
    dirname = rpath.rabspath(os.path.join(filename, '..'))
    if os.path.islink(filename):
        try:
            link = _readlink_maybe(filename)
        except OSError:
            pass
        else:
            return resolvedirof(os.path.join(dirname, link))
    return dirname


def find_pyvenv_cfg(dirname):
    try:
        fd = os.open(os.path.join(dirname, 'pyvenv.cfg'), os.O_RDONLY, 0)
        try:
            content = os.read(fd, 16384)
        finally:
            os.close(fd)
    except OSError:
        return ''
    # painfully parse the file for a line 'home = PATH'
    for line in content.splitlines():
        line += '\x00'
        i = 0
        while line[i] == ' ':
            i += 1
        if (line[i] == 'h' and
            line[i+1] == 'o' and
            line[i+2] == 'm' and
            line[i+3] == 'e'):
            i += 4
            while line[i] == ' ':
                i += 1
            if line[i] == '=':
                line = line[i+1:]
                n = line.find('\x00')
                assert n >= 0
                line = line[:n]
                return assert_str0(line.strip())
    return ''


def find_stdlib(state, platlibdir, executable):
    """
    Find and compute the stdlib path, starting from the directory where
    ``executable`` is and going one level up until we find it.  Return a
    tuple (path, prefix), where ``prefix`` is the root directory which
    contains the stdlib.  If it cannot be found, return (None, None).

    On PyPy3, it will also look for 'pyvenv.cfg' either in the same or
    in the parent directory of 'executable', and search from the 'home'
    entry instead of from the path to 'executable'.
    """
    search = 'pypy3-c' if executable == '' else executable
    search_pyvenv_cfg = 2
    while True:
        dirname = resolvedirof(search)
        if dirname == search:
            return None, None  # not found :-(
        if search_pyvenv_cfg > 0:
            search_pyvenv_cfg -= 1
            home = find_pyvenv_cfg(dirname)
            if home:
                dirname = home
                search_pyvenv_cfg = 0
        newpath = compute_stdlib_path_maybe(state, platlibdir, dirname)
        if newpath is not None:
            return newpath, dirname
        search = dirname    # walk to the parent directory


def _checkdir(path):
    st = os.stat(path)
    if not stat.S_ISDIR(st[0]):
        raise OSError(errno.ENOTDIR, path)

def _checkfile(path, fname):
    pth = os.path.join(path, fname)
    if not os.path.isfile(pth):
        raise OSError(errno.EEXIST, pth)

def compute_stdlib_path_packaged(state, platlibdir, prefix):
    """
    Compute the paths for the stdlib rooted at ``prefix``. ``prefix``
    must at least contain a directory called ``lib/pypyX.Y``.
    If it cannot be found, it raises OSError. This version is called first, for
    packaged PyPy.
    """
    from pypy.module.sys.version import CPYTHON_VERSION
    lib_pyzip = os.path.join(prefix, 'python%d%d.zip' % CPYTHON_VERSION[:2])
    if os.path.isfile(lib_pyzip):
        python_std_lib = lib_pyzip
    else:
        if _WIN32:
            lib_python = os.path.join(prefix, 'Lib')
        else:
            dirname = 'pypy%d.%d' % CPYTHON_VERSION[:2]
            lib_python = os.path.join(prefix, platlibdir)
            lib_python = os.path.join(lib_python, dirname)
        python_std_lib = os.path.join(prefix, lib_python)
        # In a source checkout, the directory will exist but site.py will not
        # yet exist in it
        _checkfile(python_std_lib, 'site.py')
    return compute_lib_pypy_path(state, python_std_lib, prefix, use_lib_pypy=False)

def compute_stdlib_path_sourcetree(state, platlibdir, prefix):
    """
    Compute the paths for the stdlib rooted at ``prefix``. ``prefix``
    must at least contain a directory called ``lib-python/X.Y`` and
    another one called ``lib_pypy``. If they cannot be found, it raises
    OSError. This version is called if compute_stdlib_path_packaged fails.
    """
    from pypy.module.sys.version import CPYTHON_VERSION
    lib_pyzip = os.path.join(prefix, 'python%d%d.zip' % CPYTHON_VERSION[:2])
    if os.path.isfile(lib_pyzip):
        python_std_lib = lib_pyzip
    else:
        dirname = '%d' % CPYTHON_VERSION[0]
        lib_python = os.path.join(prefix, 'lib-python')
        python_std_lib = os.path.join(lib_python, dirname)
        _checkdir(python_std_lib)
    return compute_lib_pypy_path(state, python_std_lib, prefix)

def compute_lib_pypy_path(state, python_std_lib, prefix, use_lib_pypy=True):
    importlist = []

    if use_lib_pypy:
        lib_pypy = os.path.join(prefix, 'lib_pypy')
        _checkdir(lib_pypy)
        importlist.append(lib_pypy)
    importlist.append(python_std_lib)

    # List here the extra platform-specific paths.
    if _MACOSX:
        # Is this still desirable?
        platmac = os.path.join(python_std_lib, 'plat-mac')
        importlist.append(platmac)
        importlist.append(os.path.join(platmac, 'lib-scriptpackages'))

    return importlist


def compute_stdlib_path_maybe(state, platlibdir, prefix):
    """Return the stdlib path rooted at ``prefix``, or None if it cannot
    be found.
    """
    try:
        return compute_stdlib_path_packaged(state, platlibdir, prefix)
    except OSError:
        try:
            return compute_stdlib_path_sourcetree(state, platlibdir, prefix)
        except OSError:
            return None


@unwrap_spec(executable='fsencode')
def pypy_find_executable(space, executable):
    return space.newfilename(find_executable(executable))


@unwrap_spec(filename='fsencode')
def pypy_resolvedirof(space, filename):
    return space.newfilename(resolvedirof(filename))


@unwrap_spec(executable='fsencode')
def pypy_find_stdlib(space, executable):
    path, prefix = None, None
    if executable != '*':
        path, prefix = find_stdlib(get_state(space), space.config.objspace.platlibdir, executable)
    if path is None:
        if space.config.translation.shared:
            dynamic_location = pypy_init_home()
            if dynamic_location:
                dyn_path = rffi.charp2str(dynamic_location)
                pypy_init_free(dynamic_location)
                path, prefix = find_stdlib(get_state(space), space.config.objspace.platlibdir, dyn_path)
        if path is None:
            return space.w_None
    w_prefix = space.newfilename(prefix)
    space.setitem(space.sys.w_dict, space.newtext('prefix'), w_prefix)
    space.setitem(space.sys.w_dict, space.newtext('exec_prefix'), w_prefix)
    space.setitem(space.sys.w_dict, space.newtext('base_prefix'), w_prefix)
    space.setitem(space.sys.w_dict, space.newtext('base_exec_prefix'), w_prefix)
    return space.newlist([space.newfilename(p) for p in path])

def pypy_initfsencoding(space):
    space.sys.filesystemencoding = _getfilesystemencoding(space)


# ____________________________________________________________


if os.name == 'nt':

    _source_code = r"""
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0501
#endif
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

char *_pypy_init_home(void)
{
    HMODULE hModule = 0;
    DWORD res;
    char *p;

    GetModuleHandleEx(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                       GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                       (LPCTSTR)&_pypy_init_home, &hModule);

    if (hModule == 0 ) {
        fprintf(stderr, "PyPy initialization: GetModuleHandleEx() failed\n");
        return NULL;
    }
    p = malloc(_MAX_PATH);
    if (p == NULL)
        return NULL;
    res = GetModuleFileName(hModule, p, _MAX_PATH);
    if (res >= _MAX_PATH || res <= 0) {
        free(p);
        fprintf(stderr, "PyPy initialization: GetModuleFileName() failed\n");
        return NULL;
    }
    return p;
}
"""

else:

    _source_code = r"""
#include <dlfcn.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

char *_pypy_init_home(void)
{
    Dl_info info;
    dlerror();   /* reset */
    if (dladdr(&_pypy_init_home, &info) == 0) {
        fprintf(stderr, "PyPy initialization: dladdr() failed: %s\n",
                dlerror());
        return NULL;
    }
    char *p = realpath(info.dli_fname, NULL);
    if (p == NULL) {
        p = strdup(info.dli_fname);
    }
    return p;
}
"""

_source_code += """
inline
void _pypy_init_free(char *p)
{
    free(p);
}
"""

if we_are_translated():
   post_include_bits = []
else:
    # for tests 
    post_include_bits=['RPY_EXPORTED char *_pypy_init_home(void);',
                       'RPY_EXPORTED void _pypy_init_free(char*);',
                      ]

_eci = ExternalCompilationInfo(separate_module_sources=[_source_code],
                               post_include_bits=post_include_bits)
_eci = _eci.merge(rdynload.eci)

pypy_init_home = rffi.llexternal("_pypy_init_home", [], rffi.CCHARP,
                                 _nowrapper=True, compilation_info=_eci)
pypy_init_free = rffi.llexternal("_pypy_init_free", [rffi.CCHARP], lltype.Void,
                                 _nowrapper=True, compilation_info=_eci)
