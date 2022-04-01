from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rawstorage import (alloc_raw_storage, raw_storage_setitem,
                                     free_raw_storage, raw_storage_getitem)


class RawMemTests(object):
    def test_cast_void_ptr(self):
        TP = lltype.Array(lltype.Float, hints={"nolength": True})
        VOID_TP = lltype.Array(lltype.Void, hints={"nolength": True, "uncast_on_llgraph": True})
        class A(object):
            def __init__(self, x):
                self.storage = rffi.cast(lltype.Ptr(VOID_TP), x)

        def f(n):
            x = lltype.malloc(TP, n, flavor="raw", zero=True)
            a = A(x)
            s = 0.0
            rffi.cast(lltype.Ptr(TP), a.storage)[0] = 1.0
            s += rffi.cast(lltype.Ptr(TP), a.storage)[0]
            lltype.free(x, flavor="raw")
            return s
        self.interp_operations(f, [10])

    def test_fixed_size_malloc(self):
        TIMEVAL = lltype.Struct('dummy', ('tv_sec', rffi.LONG), ('tv_usec', rffi.LONG))
        def f():
            p = lltype.malloc(TIMEVAL, flavor='raw')
            lltype.free(p, flavor='raw')
            return 42
        res = self.interp_operations(f, [])
        assert res == 42
        self.check_operations_history({'call_i': 1,
                                       'call_n': 1,
                                       'guard_no_exception': 1,
                                       'finish': 1})

    def test_raw_storage_int(self):
        def f():
            p = alloc_raw_storage(15)
            raw_storage_setitem(p, 3, 24)
            res = raw_storage_getitem(lltype.Signed, p, 3)
            free_raw_storage(p)
            return res
        res = self.interp_operations(f, [])
        assert res == 24
        self.check_operations_history({'call_i': 1, 'guard_no_exception': 1,
                                       'call_n': 1,
                                       'raw_store': 1, 'raw_load_i': 1,
                                       'finish': 1})
        self.metainterp.staticdata.stats.check_resops({'finish': 1}, omit_finish=False)

    def test_raw_storage_float(self):
        def f():
            p = alloc_raw_storage(15)
            raw_storage_setitem(p, 4, 2.4e15)
            res = raw_storage_getitem(lltype.Float, p, 4)
            free_raw_storage(p)
            return res
        res = self.interp_operations(f, [])
        assert res == 2.4e15
        self.check_operations_history({'call_i': 1, 'guard_no_exception': 1,
                                       'call_n': 1,
                                       'raw_store': 1, 'raw_load_f': 1,
                                       'finish': 1})
        self.metainterp.staticdata.stats.check_resops({'finish': 1}, omit_finish=False)

    def test_raw_storage_byte(self):
        def f():
            p = alloc_raw_storage(15)
            raw_storage_setitem(p, 5, rffi.cast(rffi.UCHAR, 254))
            res = raw_storage_getitem(rffi.UCHAR, p, 5)
            free_raw_storage(p)
            return rffi.cast(lltype.Signed, res)
        res = self.interp_operations(f, [])
        assert res == 254
        self.check_operations_history({'call_n': 1, 'guard_no_exception': 1,
                                       'call_i': 1,
                                       'raw_store': 1, 'raw_load_i': 1,
                                       'finish': 1})
        self.metainterp.staticdata.stats.check_resops({'finish': 1}, omit_finish=False)

    def test_raw_storage_options(self):
        def f():
            p = alloc_raw_storage(15, track_allocation=False, zero=True)
            raw_storage_setitem(p, 3, 24)
            res = raw_storage_getitem(lltype.Signed, p, 3)
            free_raw_storage(p, track_allocation=False)
            return res
        res = self.interp_operations(f, [])
        assert res == 24
        self.check_operations_history({'call_n': 1, 'guard_no_exception': 1,
                                       'call_i': 1,
                                       'raw_store': 1, 'raw_load_i': 1,
                                       'finish': 1})
        self.metainterp.staticdata.stats.check_resops({'finish': 1}, omit_finish=False)

    def test_scoped_alloc_buffer(self):
        def f():
            with rffi.scoped_alloc_buffer(42) as p:
                p.raw[0] = 'X'
                s = p.str(1)
            return ord(s[0])

        res = self.interp_operations(f, [])
        assert res == ord('X')


class TestRawMem(RawMemTests, LLJitMixin):

    def test_getarraysubstruct(self):
        # NOTE: not for backend/*/test
        A2 = lltype.Array(('a', lltype.Signed), ('b', lltype.Signed),
                          hints={'nolength': True})
        p = lltype.malloc(A2, 10, flavor='raw', immortal=True, zero=True)
        p[2].b = 689
        def f(n, m):
            p[n].a = 55
            p[n].b = 44
            p[4].b = 66
            return p[m].b

        # run with 'disable_optimizations' to prevent an error
        # 'Symbolics cannot be compared!' in the optimizer for int_mul
        res = self.interp_operations(f, [7, 2], disable_optimizations=True)
        assert res == 689
        res = self.interp_operations(f, [7, 4], disable_optimizations=True)
        assert res == 66
        res = self.interp_operations(f, [2, 2], disable_optimizations=True)
        assert res == 44
