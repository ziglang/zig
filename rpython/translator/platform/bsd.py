
import os
from rpython.translator.platform import posix

class BSD(posix.BasePosix):
    DEFAULT_CC = 'clang'

    so_ext = 'so'
    make_cmd = 'gmake'

    standalone_only = []
    shared_only = []

    def _args_for_shared(self, args, **kwds):
        return ['-shared'] + args

    def _include_dirs_for_libffi(self):
        return [os.path.join(os.environ.get("LOCALBASE", "/usr/local"), "include")]

    def _library_dirs_for_libffi(self):
        return [os.path.join(os.environ.get("LOCALBASE", "/usr/local"), "lib")]

    def _preprocess_include_dirs(self, include_dirs):
        res_incl_dirs = list(include_dirs)
        res_incl_dirs.append(os.path.join(os.environ.get("LOCALBASE", "/usr/local"), "include"))
        return res_incl_dirs

    def _preprocess_library_dirs(self, library_dirs):
        res_lib_dirs = list(library_dirs)
        res_lib_dirs.append(os.path.join(os.environ.get("LOCALBASE", "/usr/local"), "lib"))
        return res_lib_dirs
