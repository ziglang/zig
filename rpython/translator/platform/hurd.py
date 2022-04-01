"""Support for Hurd."""

import os
import platform
import sys
from rpython.translator.platform.posix import BasePosix

class BaseHurd(BasePosix):
    name = "hurd"

    link_flags = tuple(
                 ['-pthread',]
                 + os.environ.get('LDFLAGS', '').split())
    extra_libs = ('-lrt',)
    cflags = tuple(
             ['-O3', '-pthread', '-fomit-frame-pointer',
              '-Wall', '-Wno-unused', '-Wno-address']
             + os.environ.get('CFLAGS', '').split())
    standalone_only = ()
    shared_only = ('-fPIC',)
    so_ext = 'so'

    def _args_for_shared(self, args, **kwds):
        return ['-shared'] + args

    def _include_dirs_for_libffi(self):
        return self._pkg_config("libffi", "--cflags-only-I",
                                ['/usr/include/libffi'],
                                check_result_dir=True)

    def _library_dirs_for_libffi(self):
        return self._pkg_config("libffi", "--libs-only-L",
                                ['/usr/lib/libffi'],
                                check_result_dir=True)


class Hurd(BaseHurd):
    shared_only = () # it seems that on 32-bit GNU, compiling with -fPIC
                     # gives assembler that asmgcc is not happy about.

class HurdPIC(BaseHurd):
    pass
