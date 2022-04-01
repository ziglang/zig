import py
from _pytest.monkeypatch import monkeypatch
import sys
import ctypes, math
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.annlowlevel import llhelper
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.codewriter.longlong import is_longlong, is_64_bit
from rpython.rlib import jit
from rpython.rlib import jit_libffi
from rpython.rlib.jit_libffi import (types, CIF_DESCRIPTION, FFI_TYPE_PP,
                                     jit_ffi_call)
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.rarithmetic import intmask, r_longlong, r_singlefloat, r_uint
from rpython.rlib.longlong2float import float2longlong

def get_description(atypes, rtype):
    p = lltype.malloc(CIF_DESCRIPTION, len(atypes),
                      flavor='raw', immortal=True)
    p.abi = 1     # default
    p.nargs = len(atypes)
    p.rtype = rtype
    p.atypes = lltype.malloc(FFI_TYPE_PP.TO, len(atypes),
                             flavor='raw', immortal=True)
    for i in range(len(atypes)):
        p.atypes[i] = atypes[i]
    return p

class FakeFFI(object):
    """
    Context manager to monkey patch jit_libffi with our custom "libffi-like"
    function
    """
    
    def __init__(self, fake_call_impl_any):
        self.fake_call_impl_any = fake_call_impl_any
        self.monkey = monkeypatch()
        
    def __enter__(self, *args):
        self.monkey.setattr(jit_libffi, 'jit_ffi_call_impl_any', self.fake_call_impl_any)

    def __exit__(self, *args):
        self.monkey.undo()


class FfiCallTests(object):

    def _run(self, atypes, rtype, avalues, rvalue,
             expected_call_release_gil_i=1,
             expected_call_release_gil_f=0,
             expected_call_release_gil_n=0,
             expected_call_may_force_f=0,
             supports_floats=True,
             supports_longlong=False,
             supports_singlefloats=False):

        cif_description = get_description(atypes, rtype)

        def verify(*args):
            for a, exp_a in zip(args, avalues):
                if (lltype.typeOf(exp_a) == rffi.ULONG and
                    lltype.typeOf(a) == lltype.Signed):
                    a = rffi.cast(rffi.ULONG, a)
                assert a == exp_a
            return rvalue
        FUNC = lltype.FuncType([lltype.typeOf(avalue) for avalue in avalues],
                               lltype.typeOf(rvalue))
        func = lltype.functionptr(FUNC, 'verify', _callable=verify)
        func_addr = rffi.cast(rffi.VOIDP, func)

        for i in range(len(avalues)):
            cif_description.exchange_args[i] = (i+1) * 16
        cif_description.exchange_result = (len(avalues)+1) * 16

        unroll_avalues = unrolling_iterable(avalues)
        BIG_ENDIAN = (sys.byteorder == 'big')

        def fake_call_impl_any(cif_description, func_addr, exchange_buffer):
            ofs = 16
            for avalue in unroll_avalues:
                TYPE = rffi.CArray(lltype.typeOf(avalue))
                data = rffi.ptradd(exchange_buffer, ofs)
                got = rffi.cast(lltype.Ptr(TYPE), data)[0]
                tp = lltype.typeOf(avalue)
                if tp is lltype.SingleFloat:
                    got = float(got)
                    avalue = float(avalue)
                elif (isinstance(tp, lltype.Number) and
                      rffi.sizeof(tp) < rffi.sizeof(lltype.Signed)):
                    got = intmask(got)
                    avalue = intmask(avalue)
                assert got == avalue
                ofs += 16
            write_to_ofs = 0
            if rvalue is not None:
                write_rvalue = rvalue
                if BIG_ENDIAN:
                    if (lltype.typeOf(write_rvalue) is rffi.SIGNEDCHAR or
                        lltype.typeOf(write_rvalue) is rffi.UCHAR):
                        # 'write_rvalue' is an int type smaller than Signed
                        write_to_ofs = rffi.sizeof(rffi.LONG) - 1
            else:
                write_rvalue = 12923  # ignored
            TYPE = rffi.CArray(lltype.typeOf(write_rvalue))
            data = rffi.ptradd(exchange_buffer, ofs)
            rffi.cast(lltype.Ptr(TYPE), data)[write_to_ofs] = write_rvalue

        def f(i):
            exbuf = lltype.malloc(rffi.CCHARP.TO, (len(avalues)+2) * 16,
                                  flavor='raw')

            targetptr = rffi.ptradd(exbuf, 16)
            for avalue in unroll_avalues:
                TYPE = rffi.CArray(lltype.typeOf(avalue))
                if i >= 9:    # a guard that can fail
                    pass
                rffi.cast(lltype.Ptr(TYPE), targetptr)[0] = avalue
                targetptr = rffi.ptradd(targetptr, 16)

            jit_ffi_call(cif_description, func_addr, exbuf)

            if rvalue is None:
                res = 654321
            else:
                TYPE = rffi.CArray(lltype.typeOf(rvalue))
                res = rffi.cast(lltype.Ptr(TYPE), targetptr)[0]
            lltype.free(exbuf, flavor='raw')
            if lltype.typeOf(res) is lltype.SingleFloat:
                res = float(res)
            return res

        def matching_result(res, rvalue):
            if rvalue is None:
                return res == 654321
            if isinstance(rvalue, r_singlefloat):
                rvalue = float(rvalue)
            if lltype.typeOf(rvalue) is rffi.ULONG:
                res = intmask(res)
                rvalue = intmask(rvalue)
            return res == rvalue

        with FakeFFI(fake_call_impl_any):
            res = f(-42)
            assert matching_result(res, rvalue)
            res = self.interp_operations(f, [-42],
                            supports_floats = supports_floats,
                          supports_longlong = supports_longlong,
                      supports_singlefloats = supports_singlefloats)
            if is_longlong(FUNC.RESULT):
                # longlongs are returned as floats, but that's just
                # an inconvenience of interp_operations().  Normally both
                # longlong and floats are passed around as longlongs.
                res = float2longlong(res)
            assert matching_result(res, rvalue)
            self.check_operations_history(call_may_force_i=0,
                            call_may_force_f=expected_call_may_force_f,
                                          call_may_force_n=0,
                            call_release_gil_i=expected_call_release_gil_i,
                            call_release_gil_f=expected_call_release_gil_f,
                            call_release_gil_n=expected_call_release_gil_n)

            ##################################################
            driver = jit.JitDriver(reds=['i'], greens=[])
            def main():
                i = 0
                while 1:
                    driver.jit_merge_point(i=i)
                    res = f(i)
                    i += 1
                    if i == 12:
                        return res
            self.meta_interp(main, [])


    def test_simple_call_int(self):
        self._run([types.signed] * 2, types.signed, [456, 789], -42)

    def test_many_arguments(self):
        for i in [0, 6, 20]:
            self._run([types.signed] * i, types.signed,
                      [-123456*j for j in range(i)],
                      -42434445)

    def test_simple_call_float(self, **kwds):
        kwds.setdefault('supports_floats', True)
        kwds['expected_call_release_gil_f'] = kwds.pop('expected_call_release_gil', 1)
        kwds['expected_call_release_gil_i'] = 0
        self._run([types.double] * 2, types.double, [45.6, 78.9], -4.2, **kwds)

    def test_simple_call_longlong(self, **kwds):
        kwds.setdefault('supports_longlong', True)
        if is_64_bit:
            kwds['expected_call_release_gil_i'] = kwds.pop('expected_call_release_gil', 1)
        else:
            kwds['expected_call_release_gil_f'] = kwds.pop('expected_call_release_gil', 1)
            kwds['expected_call_release_gil_i'] = 0
        maxint32 = 2147483647
        a = r_longlong(maxint32) + 1
        b = r_longlong(maxint32) + 2
        self._run([types.slonglong] * 2, types.slonglong, [a, b], a, **kwds)

    def test_simple_call_singlefloat_args(self, **kwds):
        kwds.setdefault('supports_singlefloats', True)
        kwds['expected_call_release_gil_f'] = kwds.pop('expected_call_release_gil', 1)
        kwds['expected_call_release_gil_i'] = 0
        self._run([types.float] * 2, types.double,
                  [r_singlefloat(10.5), r_singlefloat(31.5)],
                  -4.5, **kwds)

    def test_simple_call_singlefloat(self, **kwds):
        kwds.setdefault('supports_singlefloats', True)
        kwds['expected_call_release_gil_i'] = kwds.pop('expected_call_release_gil', 1)
        self._run([types.float] * 2, types.float,
                  [r_singlefloat(10.5), r_singlefloat(31.5)],
                  r_singlefloat(-4.5), **kwds)

    def test_simple_call_longdouble(self):
        # longdouble is not supported, so we expect NOT to generate a call_release_gil
        self._run([types.longdouble] * 2, types.longdouble, [12.3, 45.6], 78.9,
                  expected_call_release_gil_i=0, expected_call_release_gil_f=0,
            )

    def test_returns_none(self):
        self._run([types.signed] * 2, types.void, [456, 789], None,
                  expected_call_release_gil_i=0, expected_call_release_gil_n=1)

    def test_returns_signedchar(self):
        self._run([types.sint8], types.sint8,
                  [rffi.cast(rffi.SIGNEDCHAR, -28)],
                  rffi.cast(rffi.SIGNEDCHAR, -42))

    def test_handle_unsigned(self):
        self._run([types.ulong], types.ulong,
                  [rffi.cast(rffi.ULONG, r_uint(sys.maxint + 91348))],
                  rffi.cast(rffi.ULONG, r_uint(sys.maxint + 4242)))

    def test_handle_unsignedchar(self):
        self._run([types.uint8], types.uint8,
                  [rffi.cast(rffi.UCHAR, 191)],
                  rffi.cast(rffi.UCHAR, 180))

    def _add_libffi_types_to_ll2types_maybe(self):
        # not necessary on the llgraph backend, but needed for x86.
        # see rpython/jit/backend/x86/test/test_fficall.py
        pass

    def test_guard_not_forced_fails(self):
        self._add_libffi_types_to_ll2types_maybe()
        FUNC = lltype.FuncType([lltype.Signed], lltype.Signed)

        cif_description = get_description([types.slong], types.slong)
        cif_description.exchange_args[0] = 16
        cif_description.exchange_result = 32

        ARRAY = lltype.Ptr(rffi.CArray(lltype.Signed))

        @jit.dont_look_inside
        def fn(n):
            if n >= 50:
                exctx.m = exctx.topframeref().n # forces the frame
            return n*2

        # this function simulates what a real libffi_call does: reading from
        # the buffer, calling a function (which can potentially call callbacks
        # and force frames) and write back to the buffer
        def fake_call_impl_any(cif_description, func_addr, exchange_buffer):
            # read the args from the buffer
            data_in = rffi.ptradd(exchange_buffer, 16)
            n = rffi.cast(ARRAY, data_in)[0]
            #
            # logic of the function
            func_ptr = rffi.cast(lltype.Ptr(FUNC), func_addr)
            n = func_ptr(n)
            #
            # write the result to the buffer
            data_out = rffi.ptradd(exchange_buffer, 32)
            rffi.cast(ARRAY, data_out)[0] = n

        def do_call(n):
            func_ptr = llhelper(lltype.Ptr(FUNC), fn)
            exbuf = lltype.malloc(rffi.CCHARP.TO, 48, flavor='raw', zero=True)
            data_in = rffi.ptradd(exbuf, 16)
            rffi.cast(ARRAY, data_in)[0] = n
            jit_ffi_call(cif_description, func_ptr, exbuf)
            data_out = rffi.ptradd(exbuf, 32)
            res = rffi.cast(ARRAY, data_out)[0]
            lltype.free(exbuf, flavor='raw')
            return res

        #
        #
        class XY:
            pass
        class ExCtx:
            pass
        exctx = ExCtx()
        myjitdriver = jit.JitDriver(greens = [], reds = ['n'])
        def f():
            n = 0
            while n < 100:
                myjitdriver.jit_merge_point(n=n)
                xy = XY()
                xy.n = n
                exctx.topframeref = vref = jit.virtual_ref(xy)
                res = do_call(n) # this is equivalent of a cffi call which
                                 # sometimes forces a frame

                # when n==50, fn() will force the frame, so guard_not_forced
                # fails and we enter blackholing: this test makes sure that
                # the result of call_release_gil is kept alive before the
                # raw_store, and that the corresponding box is passed
                # in the fail_args. Before the fix, the result of
                # call_release_gil was simply lost and when guard_not_forced
                # failed, and the value of "res" was unpredictable.
                # See commit b84ff38f34bd and subsequents.
                assert res == n*2
                jit.virtual_ref_finish(vref, xy)
                exctx.topframeref = jit.vref_None
                n += 1
            return n

        with FakeFFI(fake_call_impl_any):
            assert f() == 100
            res = self.meta_interp(f, [])
            assert res == 100
        

class TestFfiCall(FfiCallTests, LLJitMixin):
    def test_jit_ffi_vref(self):
        py.test.skip("unsupported so far")
        from rpython.rlib import clibffi
        from rpython.rlib.jit_libffi import jit_ffi_prep_cif, jit_ffi_call

        math_sin = intmask(ctypes.cast(ctypes.CDLL(None).sin,
                                       ctypes.c_void_p).value)
        math_sin = rffi.cast(rffi.VOIDP, math_sin)

        cd = lltype.malloc(CIF_DESCRIPTION, 1, flavor='raw')
        cd.abi = clibffi.FFI_DEFAULT_ABI
        cd.nargs = 1
        cd.rtype = clibffi.cast_type_to_ffitype(rffi.DOUBLE)
        atypes = lltype.malloc(clibffi.FFI_TYPE_PP.TO, 1, flavor='raw')
        atypes[0] = clibffi.cast_type_to_ffitype(rffi.DOUBLE)
        cd.atypes = atypes
        cd.exchange_size = 64    # 64 bytes of exchange data
        cd.exchange_result = 24
        cd.exchange_args[0] = 16

        def f():
            #
            jit_ffi_prep_cif(cd)
            #
            assert rffi.sizeof(rffi.DOUBLE) == 8
            exb = lltype.malloc(rffi.DOUBLEP.TO, 8, flavor='raw')
            exb[2] = 1.23
            jit_ffi_call(cd, math_sin, rffi.cast(rffi.CCHARP, exb))
            res = exb[3]
            lltype.free(exb, flavor='raw')
            #
            return res
            #
        res = self.interp_operations(f, [])
        lltype.free(cd, flavor='raw')
        assert res == math.sin(1.23)

        lltype.free(atypes, flavor='raw')

    def test_simple_call_float_unsupported(self):
        self.test_simple_call_float(supports_floats=False,
                                    expected_call_release_gil=0)

    def test_simple_call_longlong_unsupported(self):
        self.test_simple_call_longlong(supports_longlong=False,
                                       expected_call_release_gil=is_64_bit)

    def test_simple_call_singlefloat_unsupported(self):
        self.test_simple_call_singlefloat(supports_singlefloats=False,
                                          expected_call_release_gil=0)

    def test_calldescrof_dynamic_returning_none(self):
        from rpython.jit.backend.llgraph.runner import LLGraphCPU
        old = LLGraphCPU.calldescrof_dynamic
        try:
            LLGraphCPU.calldescrof_dynamic = lambda *args: None
            self.test_simple_call_float(expected_call_release_gil=0,
                                        expected_call_may_force_f=1)
        finally:
            LLGraphCPU.calldescrof_dynamic = old
