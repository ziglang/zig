# _tkinter package -- low-level interface to libtk and libtcl.
#
# This is an internal module, applications should "import Tkinter" instead.
#
# This version is based on cffi, and is a translation of _tkinter.c
# from CPython, version 2.7.4.

import os
import sys

class TclError(Exception):
    pass

from .tklib_cffi import ffi as tkffi, lib as tklib

from .app import TkApp
from .tclobj import Tcl_Obj

TK_VERSION = tkffi.string(tklib.get_tk_version()).decode('utf-8')
TCL_VERSION = tkffi.string(tklib.get_tcl_version()).decode('utf-8')

READABLE = tklib.TCL_READABLE
WRITABLE = tklib.TCL_WRITABLE
EXCEPTION = tklib.TCL_EXCEPTION
DONT_WAIT = tklib.TCL_DONT_WAIT

def create(screenName=None, baseName=None, className=None,
           interactive=False, wantobjects=False, wantTk=True,
           sync=False, use=None):
    return TkApp(screenName, className,
                 interactive, wantobjects, wantTk, sync, use)

def dooneevent(flags=0):
    return tklib.Tcl_DoOneEvent(flags)


def _flatten(item):
    def _flatten1(output, item, depth):
        if depth > 1000:
            raise ValueError("nesting too deep in _flatten")
        if not isinstance(item, (list, tuple)):
            raise TypeError("argument must be sequence")
        # copy items to output tuple
        for o in item:
            if isinstance(o, (list, tuple)):
                _flatten1(output, o, depth + 1)
            elif o is not None:
                output.append(o)

    result = []
    _flatten1(result, item, 0)
    return tuple(result)


tklib.Tcl_FindExecutable(os.fsencode(sys.executable))
