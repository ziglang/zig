"""
Implementation of interpreter-level 'sys' routines.
"""
import os
from pypy import pypydir

# ____________________________________________________________
#

class State:
    def __init__(self, space):
        self.space = space

        self.w_modules = space.newdict(module=True)
        self.w_warnoptions = space.newlist([])
        self.w_argv = space.newlist([])

        self.setinitialpath(space)

    def setinitialpath(self, space):
        from pypy.module.sys.initpath import compute_stdlib_path_sourcetree
        # This initial value for sys.prefix is normally overwritten
        # at runtime by initpath.py
        srcdir = os.path.dirname(pypydir)
        self.w_initial_prefix = space.newtext(srcdir)
        # Initialize the default path
        path = compute_stdlib_path_sourcetree(self, space.config.objspace.platlibdir, srcdir)
        self.w_path = space.newlist([space.newfilename(p) for p in path])

def get(space):
    return space.fromcache(State)

def pypy_getudir(space):
    """NOT_RPYTHON
    (should be removed from interpleveldefs before translation)"""
    from rpython.tool.udir import udir
    return space.newfilename(str(udir))
