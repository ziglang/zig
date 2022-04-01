from pypy.interpreter.error import OperationError
from pypy.interpreter.gateway import unwrap_spec
from pypy.interpreter.pyframe import PyFrame
from pypy.interpreter.pycode import PyCode
from pypy.interpreter.baseobjspace import W_Root
from rpython.rlib.rjitlog import rjitlog
from rpython.rlib import jit

class Cache:
    def __init__(self, space):
        self.w_JitlogError = space.new_exception_class("_jitlog.JitlogError")

def JitlogError(space, e):
    w_JitlogError = space.fromcache(Cache).w_JitlogError
    return OperationError(w_JitlogError, space.newtext(e.msg))

@unwrap_spec(fileno=int)
def enable(space, fileno):
    """ Enable PyPy's logging facility. """
    try:
        rjitlog.enable_jitlog(fileno)
    except rjitlog.JitlogError, e:
        raise JitlogError(space, e)

@jit.dont_look_inside
def disable(space):
    """ Disable PyPy's logging facility. """
    rjitlog.disable_jitlog()
