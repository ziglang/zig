from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import jit
from rpython.rlib.objectmodel import specialize, not_rpython

from pypy.interpreter.error import oefmt

from pypy.module._hpy_universal import llapi
from pypy.module._hpy_universal import handlemanager
from pypy.module._hpy_universal.bridge import BRIDGE, hpy_get_bridge


class State(object):
    @not_rpython
    def __init__(self, space):
        self.space = space
        uctx = lltype.malloc(llapi.HPyContext.TO, flavor='raw', immortal=True)
        dctx = lltype.malloc(llapi.HPyContext.TO, flavor='raw', immortal=True)
        self.u_handles = handlemanager.HandleManager(space, uctx)
        self.d_handles = handlemanager.DebugHandleManager(space, dctx, self.u_handles)

    @jit.dont_look_inside
    def setup(self, space):
        self.u_handles.setup_ctx()
        self.d_handles.setup_ctx()
        self.setup_bridge()

    @staticmethod
    def get(space):
        return space.fromcache(State)

    @specialize.arg(1)
    def get_handle_manager(self, debug):
        if debug:
            return self.d_handles
        return self.u_handles

    def setup_bridge(self):
        if self.space.config.translating:
            # after translation: call get_llhelper() to ensure that the
            # annotator sees the functions and generates the C source.
            #
            # The ptr[0] = ... is a work around to convince the translator NOT
            # to optimize away the call to get_llhelper(), else the helpers
            # are never seen and the C code is not generated.
            with lltype.scoped_alloc(rffi.CArray(rffi.VOIDP), 1) as ptr:
                for func in BRIDGE.all_functions:
                    ptr[0] = rffi.cast(rffi.VOIDP, func.get_llhelper(self.space))
        else:
            # before translation: put the ll2ctypes callbacks into the global
            # hpy_get_bridge(), so that they can be called from C
            bridge = hpy_get_bridge()
            for func in BRIDGE.all_functions:
                funcptr = rffi.cast(rffi.VOIDP, func.get_llhelper(self.space))
                fieldname = 'c_' + func.__name__
                setattr(bridge, fieldname, funcptr)

    def was_already_setup(self):
        return bool(self.u_handles.ctx)

    @not_rpython
    def reset(self):
        """
        Only for tests: reset all the C globals to match the current state.
        """
        self.setup_bridge()
        llapi.hpy_debug_set_ctx(self.d_handles.ctx)

    def set_exception(self, operror):
        self.clear_exception()
        ec = self.space.getexecutioncontext()
        ec.cpyext_operror = operror

    def clear_exception(self):
        """Clear the current exception state, and return the operror."""
        ec = self.space.getexecutioncontext()
        operror = ec.cpyext_operror
        ec.cpyext_operror = None
        return operror

    def get_exception(self):
        ec = self.space.getexecutioncontext()
        return ec.cpyext_operror

    def raise_current_exception(self):
        operror = self.clear_exception()
        if operror:
            raise operror
        else:
            raise oefmt(self.space.w_SystemError,
                        "Function returned an error result without setting an "
                        "exception")
