"""Support for NetBSD."""

import os

from rpython.translator.platform import posix

def get_env(key, default):
    if key in os.environ:
        return os.environ[key]
    else:
        return default

def get_env_vector(key, default):
    string = get_env(key, default)
    # XXX: handle quotes
    return string.split()

class Netbsd(posix.BasePosix):
    name = "netbsd"

    link_flags = ['-pthread',
                  '-Wl,-R' + get_env("LOCALBASE", "/usr/pkg") + '/lib'
                 ] + get_env_vector('LDFLAGS', '')
    cflags = ['-O3', '-pthread', '-fomit-frame-pointer'
             ] + get_env_vector('CFLAGS', '')
    standalone_only = []
    shared_only = []
    so_ext = 'so'
    make_cmd = 'gmake'
    extra_libs = ('-lrt',)

    def __init__(self, cc=None):
        if cc is None:
            cc = get_env("CC", "gcc")
        super(Netbsd, self).__init__(cc)

    def _args_for_shared(self, args, **kwds):
        return ['-shared'] + args

    def _preprocess_include_dirs(self, include_dirs):
        res_incl_dirs = list(include_dirs)
        res_incl_dirs.append(os.path.join(get_env("LOCALBASE", "/usr/pkg"), "include"))
        return res_incl_dirs

    def _preprocess_library_dirs(self, library_dirs):
        res_lib_dirs = list(library_dirs)
        res_lib_dirs.append(os.path.join(get_env("LOCALBASE", "/usr/pkg"), "lib"))
        return res_lib_dirs

    def _include_dirs_for_libffi(self):
        return [os.path.join(get_env("LOCALBASE", "/usr/pkg"), "include")]

    def _library_dirs_for_libffi(self):
        return [os.path.join(get_env("LOCALBASE", "/usr/pkg"), "lib")]

class Netbsd_64(Netbsd):
    shared_only = ('-fPIC',)
