"""
This module defines the abstract base classes that support execution:
Code and Frame.
"""

from pypy.interpreter.baseobjspace import W_Root


class Code(W_Root):
    """A code is a compiled version of some source code.
    Abstract base class."""
    hidden_applevel = False
    _immutable_fields_ = ['co_name', 'fast_natural_arity', 'hidden_applevel']

    # n >= 0 : arity
    # FLATPYCALL = 0x100
    # n|FLATPYCALL: pycode flat case
    # FLATPYCALL<<x (x>=1): special cases
    # HOPELESS: hopeless
    FLATPYCALL = 0x100
    PASSTHROUGHARGS1 = 0x200
    HOPELESS = 0x400
    fast_natural_arity = HOPELESS

    def __init__(self, co_name):
        self.co_name = co_name

    def exec_code(self, space, w_globals, w_locals):
        "Implements the 'exec' statement."
        # this should be on PyCode?
        frame = space.createframe(self, w_globals, None)
        frame.setdictscope(w_locals)
        return frame.run()

    def signature(self):
        raise NotImplementedError

    def getvarnames(self):
        """List of names including the arguments, vararg and kwarg,
        and possibly more locals."""
        return self.signature().getallvarnames()

    def getdocstring(self, space):
        return space.w_None

    def funcrun(self, func, args):
        raise NotImplementedError("purely abstract")

    def funcrun_obj(self, func, w_obj, args):
        return self.funcrun(func, args.prepend(w_obj))
