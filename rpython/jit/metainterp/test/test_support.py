from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.jit.metainterp.support import adr2int, int2adr

def test_cast_adr_to_int_and_back():
    X = lltype.Struct('X', ('foo', lltype.Signed))
    x = lltype.malloc(X, immortal=True)
    x.foo = 42
    a = llmemory.cast_ptr_to_adr(x)
    i = adr2int(a)
    assert lltype.typeOf(i) is lltype.Signed
    a2 = int2adr(i)
    assert llmemory.cast_adr_to_ptr(a2, lltype.Ptr(X)) == x
    assert adr2int(llmemory.NULL) == 0
    assert int2adr(0) == llmemory.NULL
