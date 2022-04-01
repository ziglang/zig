from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.jit.backend.llsupport.gcreftracer import GCREFTRACER, gcrefs_trace
from rpython.jit.backend.llsupport.gcreftracer import make_framework_tracer
from rpython.jit.backend.llsupport.gcreftracer import make_boehm_tracer


class FakeGC:
    def __init__(self):
        self.called = []
    def _trace_callback(self, callback, arg, addr):
        assert callback == "callback"
        assert arg == "arg"
        assert lltype.typeOf(addr) == llmemory.Address
        self.called.append(addr)


def test_gcreftracer():
    a = lltype.malloc(rffi.CArray(lltype.Signed), 3, flavor='raw')
    a[0] = 123
    a[1] = 456
    a[2] = 789
    tr = lltype.malloc(GCREFTRACER)
    tr.array_base_addr = base = rffi.cast(lltype.Signed, a)
    tr.array_length = 3
    gc = FakeGC()
    gcrefs_trace(gc, llmemory.cast_ptr_to_adr(tr), "callback", "arg")
    assert len(gc.called) == 3
    WORD = rffi.sizeof(lltype.Signed)
    for i in range(3):
        assert gc.called[i] == rffi.cast(llmemory.Address, base + i * WORD)
    lltype.free(a, flavor='raw')

def test_make_framework_tracer():
    a = lltype.malloc(rffi.CArray(lltype.Signed), 3, flavor='raw')
    base = rffi.cast(lltype.Signed, a)
    tr = make_framework_tracer(base, [123, 456, 789])
    assert a[0] == 123
    assert a[1] == 456
    assert a[2] == 789
    assert tr.array_base_addr == base
    assert tr.array_length == 3
    lltype.free(a, flavor='raw')

def test_make_boehm_tracer():
    a = lltype.malloc(rffi.CArray(lltype.Signed), 3, flavor='raw')
    base = rffi.cast(lltype.Signed, a)
    lst = [123, 456, 789]
    tr = make_boehm_tracer(base, lst)
    assert a[0] == 123
    assert a[1] == 456
    assert a[2] == 789
    assert tr is lst
    lltype.free(a, flavor='raw')
