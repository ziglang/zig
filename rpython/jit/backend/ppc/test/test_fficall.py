import py
from rpython.jit.metainterp.test import test_fficall
from rpython.jit.backend.ppc.test.support import JitPPCMixin

class TestFfiCall(JitPPCMixin, test_fficall.FfiCallTests):
    # for the individual tests see
    # ====> ../../../metainterp/test/test_fficall.py

    def _add_libffi_types_to_ll2types_maybe(self):
        # this is needed by test_guard_not_forced_fails, because it produces a
        # loop which reads the value of types.* in a variable, then a guard
        # fail and we switch to blackhole: the problem is that at this point
        # the blackhole interp has a real integer, but it needs to convert it
        # back to a lltype pointer (which is handled by ll2ctypes, deeply in
        # the logic). The workaround is to teach ll2ctypes in advance which
        # are the addresses of the various types.* structures.
        # Try to comment this code out and run the test to see how it fails :)
        from rpython.rtyper.lltypesystem import rffi, lltype, ll2ctypes
        from rpython.rlib.jit_libffi import types
        for key, value in types.__dict__.iteritems():
            if isinstance(value, lltype._ptr):
                addr = rffi.cast(lltype.Signed, value)
                ll2ctypes._int2obj[addr] = value
