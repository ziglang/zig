import py, sys
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.annlowlevel import llstr
from rpython.flowspace.model import Variable, Constant, SpaceOperation
from rpython.jit.codewriter.support import decode_builtin_call, LLtypeHelpers

def newconst(x):
    return Constant(x, lltype.typeOf(x))

def voidconst(x):
    return Constant(x, lltype.Void)

# ____________________________________________________________

def test_decode_builtin_call_nomethod():
    def myfoobar(i, marker, c):
        assert marker == 'mymarker'
        return i * ord(c)
    myfoobar.oopspec = 'foobar(2, c, i)'
    TYPE = lltype.FuncType([lltype.Signed, lltype.Void, lltype.Char],
                           lltype.Signed)
    fnobj = lltype.functionptr(TYPE, 'foobar', _callable=myfoobar)
    vi = Variable('i')
    vi.concretetype = lltype.Signed
    vc = Variable('c')
    vc.concretetype = lltype.Char
    v_result = Variable('result')
    v_result.concretetype = lltype.Signed
    op = SpaceOperation('direct_call', [newconst(fnobj),
                                        vi,
                                        voidconst('mymarker'),
                                        vc],
                        v_result)
    oopspec, opargs = decode_builtin_call(op)
    assert oopspec == 'foobar'
    assert opargs == [newconst(2), vc, vi]
    #impl = runner.get_oopspec_impl('foobar', lltype.Signed)
    #assert impl(2, 'A', 5) == 5 * ord('A')

def test_decode_builtin_call_method():
    A = lltype.GcArray(lltype.Signed)
    def myfoobar(a, i, marker, c):
        assert marker == 'mymarker'
        return a[i] * ord(c)
    myfoobar.oopspec = 'spam.foobar(a, 2, c, i)'
    TYPE = lltype.FuncType([lltype.Ptr(A), lltype.Signed,
                            lltype.Void, lltype.Char],
                           lltype.Signed)
    fnobj = lltype.functionptr(TYPE, 'foobar', _callable=myfoobar)
    vi = Variable('i')
    vi.concretetype = lltype.Signed
    vc = Variable('c')
    vc.concretetype = lltype.Char
    v_result = Variable('result')
    v_result.concretetype = lltype.Signed
    myarray = lltype.malloc(A, 10)
    myarray[5] = 42
    op = SpaceOperation('direct_call', [newconst(fnobj),
                                        newconst(myarray),
                                        vi,
                                        voidconst('mymarker'),
                                        vc],
                        v_result)
    oopspec, opargs = decode_builtin_call(op)
    assert oopspec == 'spam.foobar'
    assert opargs == [newconst(myarray), newconst(2), vc, vi]
    #impl = runner.get_oopspec_impl('spam.foobar', lltype.Ptr(A))
    #assert impl(myarray, 2, 'A', 5) == 42 * ord('A')

def test_streq_slice_checknull():
    p1 = llstr("hello world")
    p2 = llstr("wor")
    func = LLtypeHelpers._ll_4_str_eq_slice_checknull.im_func
    assert func(p1, 6, 3, p2) == True
    assert func(p1, 6, 2, p2) == False
    assert func(p1, 5, 3, p2) == False
    assert func(p1, 2, 1, llstr(None)) == False

def test_streq_slice_nonnull():
    p1 = llstr("hello world")
    p2 = llstr("wor")
    func = LLtypeHelpers._ll_4_str_eq_slice_nonnull.im_func
    assert func(p1, 6, 3, p2) == True
    assert func(p1, 6, 2, p2) == False
    assert func(p1, 5, 3, p2) == False
    py.test.raises(AttributeError, func, p1, 2, 1, llstr(None))

def test_streq_slice_char():
    p1 = llstr("hello world")
    func = LLtypeHelpers._ll_4_str_eq_slice_char.im_func
    assert func(p1, 6, 3, "w") == False
    assert func(p1, 6, 0, "w") == False
    assert func(p1, 6, 1, "w") == True
    assert func(p1, 6, 1, "x") == False

def test_streq_nonnull():
    p1 = llstr("wor")
    p2 = llstr("wor")
    assert p1 != p2
    func = LLtypeHelpers._ll_2_str_eq_nonnull.im_func
    assert func(p1, p1) == True
    assert func(p1, p2) == True
    assert func(p1, llstr("wrl")) == False
    assert func(p1, llstr("world")) == False
    assert func(p1, llstr("w")) == False
    py.test.raises(AttributeError, func, p1, llstr(None))
    py.test.raises(AttributeError, func, llstr(None), p2)

def test_streq_nonnull_char():
    func = LLtypeHelpers._ll_2_str_eq_nonnull_char.im_func
    assert func(llstr("wor"), "x") == False
    assert func(llstr("w"), "x") == False
    assert func(llstr(""), "x") == False
    assert func(llstr("x"), "x") == True
    py.test.raises(AttributeError, func, llstr(None), "x")

def test_streq_checknull_char():
    func = LLtypeHelpers._ll_2_str_eq_checknull_char.im_func
    assert func(llstr("wor"), "x") == False
    assert func(llstr("w"), "x") == False
    assert func(llstr(""), "x") == False
    assert func(llstr("x"), "x") == True
    assert func(llstr(None), "x") == False

def test_streq_lengthok():
    p1 = llstr("wor")
    p2 = llstr("wor")
    assert p1 != p2
    func = LLtypeHelpers._ll_2_str_eq_lengthok.im_func
    assert func(p1, p1) == True
    assert func(p1, p2) == True
    assert func(p1, llstr("wrl")) == False
    py.test.raises(IndexError, func, p1, llstr("w"))
    py.test.raises(AttributeError, func, p1, llstr(None))
    py.test.raises(AttributeError, func, llstr(None), p2)

def test_int_abs():
    from rpython.jit.codewriter.support import _ll_1_int_abs
    assert _ll_1_int_abs(0) == 0
    assert _ll_1_int_abs(1) == 1
    assert _ll_1_int_abs(10) == 10
    assert _ll_1_int_abs(sys.maxint) == sys.maxint
    assert _ll_1_int_abs(-1) == 1
    assert _ll_1_int_abs(-10) == 10
    assert _ll_1_int_abs(-sys.maxint) == sys.maxint

def test_int_floordiv_mod():
    from rpython.rtyper.lltypesystem.lloperation import llop
    from rpython.jit.codewriter.support import _ll_2_int_floordiv, _ll_2_int_mod
    for x in range(-6, 7):
        for y in range(-3, 4):
            if y != 0:
                assert (_ll_2_int_floordiv(x, y) ==
                        llop.int_floordiv(lltype.Signed, x, y))
                assert (_ll_2_int_mod(x, y) ==
                        llop.int_mod(lltype.Signed, x, y))
