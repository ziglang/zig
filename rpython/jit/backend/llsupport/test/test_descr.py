from rpython.rtyper.lltypesystem import lltype, rffi, rstr
from rpython.jit.backend.llsupport.descr import *
from rpython.jit.backend.llsupport import symbolic
from rpython.rlib.objectmodel import Symbolic
from rpython.rtyper.annlowlevel import llhelper
from rpython.jit.metainterp import history
from rpython.jit.codewriter import longlong
import sys, struct, py

def test_get_size_descr():
    c0 = GcCache(False)
    c1 = GcCache(True)
    T = lltype.GcStruct('T')
    S = lltype.GcStruct('S', ('x', lltype.Char),
                             ('y', lltype.Ptr(T)))
    descr_s = get_size_descr(c0, S)
    descr_t = get_size_descr(c0, T)
    assert descr_s.size == symbolic.get_size(S, False)
    assert descr_t.size == symbolic.get_size(T, False)
    assert descr_s.is_immutable() == False
    assert descr_t.is_immutable() == False
    assert descr_t.gc_fielddescrs == []
    assert len(descr_s.gc_fielddescrs) == 1
    assert descr_s == get_size_descr(c0, S)
    assert descr_s != get_size_descr(c1, S)
    #
    descr_s = get_size_descr(c1, S)
    assert isinstance(descr_s.size, Symbolic)
    assert descr_s.is_immutable() == False

    PARENT = lltype.Struct('P', ('x', lltype.Ptr(T)))
    STRUCT = lltype.GcStruct('S', ('parent', PARENT), ('y', lltype.Ptr(T)))
    descr_struct = get_size_descr(c0, STRUCT)
    assert len(descr_struct.gc_fielddescrs) == 2

def test_get_size_descr_immut():
    S = lltype.GcStruct('S', hints={'immutable': True})
    T = lltype.GcStruct('T', ('parent', S),
                        ('x', lltype.Char),
                        hints={'immutable': True})
    U = lltype.GcStruct('U', ('parent', T),
                        ('u', lltype.Ptr(T)),
                        ('v', lltype.Signed),
                        hints={'immutable': True})
    V = lltype.GcStruct('V', ('parent', U),
                        ('miss1', lltype.Void),
                        ('miss2', lltype.Void),
                        hints={'immutable': True})
    for STRUCT in [S, T, U, V]:
        for translated in [False, True]:
            c0 = GcCache(translated)
            descr_s = get_size_descr(c0, STRUCT)
            assert descr_s.is_immutable() == True

def test_get_field_descr():
    U = lltype.Struct('U')
    T = lltype.GcStruct('T')
    S = lltype.GcStruct('S', ('x', lltype.Char),
                             ('y', lltype.Ptr(T)),
                             ('z', lltype.Ptr(U)),
                             ('f', lltype.Float),
                             ('s', lltype.SingleFloat))
    #
    c0 = GcCache(False)
    c1 = GcCache(True)
    assert get_field_descr(c0, S, 'y') == get_field_descr(c0, S, 'y')
    assert get_field_descr(c0, S, 'y') != get_field_descr(c1, S, 'y')
    for tsc in [False, True]:
        c2 = GcCache(tsc)
        descr_x = get_field_descr(c2, S, 'x')
        descr_y = get_field_descr(c2, S, 'y')
        descr_z = get_field_descr(c2, S, 'z')
        descr_f = get_field_descr(c2, S, 'f')
        descr_s = get_field_descr(c2, S, 's')
        assert isinstance(descr_x, FieldDescr)
        assert descr_x.name == 'S.x'
        assert descr_y.name == 'S.y'
        assert descr_z.name == 'S.z'
        assert descr_f.name == 'S.f'
        assert descr_s.name == 'S.s'
        if not tsc:
            assert descr_x.offset < descr_y.offset < descr_z.offset
            assert descr_x.sort_key() < descr_y.sort_key() < descr_z.sort_key()
            assert descr_x.field_size == rffi.sizeof(lltype.Char)
            assert descr_y.field_size == rffi.sizeof(lltype.Ptr(T))
            assert descr_z.field_size == rffi.sizeof(lltype.Ptr(U))
            assert descr_f.field_size == rffi.sizeof(lltype.Float)
            assert descr_s.field_size == rffi.sizeof(lltype.SingleFloat)
        else:
            assert isinstance(descr_x.offset, Symbolic)
            assert isinstance(descr_y.offset, Symbolic)
            assert isinstance(descr_z.offset, Symbolic)
            assert isinstance(descr_f.offset, Symbolic)
            assert isinstance(descr_s.offset, Symbolic)
            assert isinstance(descr_x.field_size, Symbolic)
            assert isinstance(descr_y.field_size, Symbolic)
            assert isinstance(descr_z.field_size, Symbolic)
            assert isinstance(descr_f.field_size, Symbolic)
            assert isinstance(descr_s.field_size, Symbolic)
        assert descr_x.flag == FLAG_UNSIGNED
        assert descr_y.flag == FLAG_POINTER
        assert descr_z.flag == FLAG_UNSIGNED
        assert descr_f.flag == FLAG_FLOAT
        assert descr_s.flag == FLAG_UNSIGNED


def test_get_field_descr_sign():
    for RESTYPE, signed in [(rffi.SIGNEDCHAR, True), (rffi.UCHAR,  False),
                            (rffi.SHORT,      True), (rffi.USHORT, False),
                            (rffi.INT,        True), (rffi.UINT,   False),
                            (rffi.LONG,       True), (rffi.ULONG,  False)]:
        S = lltype.GcStruct('S', ('x', RESTYPE))
        for tsc in [False, True]:
            c2 = GcCache(tsc)
            descr_x = get_field_descr(c2, S, 'x')
            assert descr_x.flag == {False: FLAG_UNSIGNED,
                                    True:  FLAG_SIGNED  }[signed]

def test_get_field_descr_longlong():
    if sys.maxint > 2147483647:
        py.test.skip("long long: for 32-bit only")
    c0 = GcCache(False)
    S = lltype.GcStruct('S', ('y', lltype.UnsignedLongLong))
    descr = get_field_descr(c0, S, 'y')
    assert descr.flag == FLAG_FLOAT
    assert descr.field_size == 8


def test_get_array_descr():
    U = lltype.Struct('U')
    T = lltype.GcStruct('T')
    A1 = lltype.GcArray(lltype.Char)
    A2 = lltype.GcArray(lltype.Ptr(T))
    A3 = lltype.GcArray(lltype.Ptr(U))
    A4 = lltype.GcArray(lltype.Float)
    A5 = lltype.GcArray(lltype.Struct('x', ('v', lltype.Signed),
                                           ('k', lltype.Signed)))
    A6 = lltype.GcArray(lltype.SingleFloat)
    #
    c0 = GcCache(False)
    descr1 = get_array_descr(c0, A1)
    descr2 = get_array_descr(c0, A2)
    descr3 = get_array_descr(c0, A3)
    descr4 = get_array_descr(c0, A4)
    descr5 = get_array_descr(c0, A5)
    descr6 = get_array_descr(c0, A6)
    assert isinstance(descr1, ArrayDescr)
    assert descr1 == get_array_descr(c0, lltype.GcArray(lltype.Char))
    assert descr1.flag == FLAG_UNSIGNED
    assert descr2.flag == FLAG_POINTER
    assert descr3.flag == FLAG_UNSIGNED
    assert descr4.flag == FLAG_FLOAT
    assert descr5.flag == FLAG_STRUCT
    assert descr6.flag == FLAG_UNSIGNED
    #
    def get_alignment(code):
        # Retrieve default alignment for the compiler/platform
        return struct.calcsize(lltype.SignedFmt + code) - struct.calcsize(code)
    assert descr1.basesize == get_alignment('c')
    assert descr2.basesize == get_alignment('p')
    assert descr3.basesize == get_alignment('p')
    assert descr4.basesize == get_alignment('d')
    assert descr5.basesize == get_alignment('f')
    assert descr1.lendescr.offset == 0
    assert descr2.lendescr.offset == 0
    assert descr3.lendescr.offset == 0
    assert descr4.lendescr.offset == 0
    assert descr5.lendescr.offset == 0
    assert descr1.itemsize == rffi.sizeof(lltype.Char)
    assert descr2.itemsize == rffi.sizeof(lltype.Ptr(T))
    assert descr3.itemsize == rffi.sizeof(lltype.Ptr(U))
    assert descr4.itemsize == rffi.sizeof(lltype.Float)
    assert descr5.itemsize == rffi.sizeof(lltype.Signed) * 2
    assert descr6.itemsize == rffi.sizeof(lltype.SingleFloat)
    #
    CA = rffi.CArray(lltype.Signed)
    descr = get_array_descr(c0, CA)
    assert descr.flag == FLAG_SIGNED
    assert descr.basesize == 0
    assert descr.lendescr is None
    CA = rffi.CArray(lltype.Ptr(lltype.GcStruct('S')))
    descr = get_array_descr(c0, CA)
    assert descr.flag == FLAG_POINTER
    assert descr.basesize == 0
    assert descr.lendescr is None
    CA = rffi.CArray(lltype.Ptr(lltype.Struct('S')))
    descr = get_array_descr(c0, CA)
    assert descr.flag == FLAG_UNSIGNED
    assert descr.basesize == 0
    assert descr.lendescr is None
    CA = rffi.CArray(lltype.Float)
    descr = get_array_descr(c0, CA)
    assert descr.flag == FLAG_FLOAT
    assert descr.basesize == 0
    assert descr.lendescr is None
    CA = rffi.CArray(rffi.FLOAT)
    descr = get_array_descr(c0, CA)
    assert descr.flag == FLAG_UNSIGNED
    assert descr.basesize == 0
    assert descr.itemsize == rffi.sizeof(lltype.SingleFloat)
    assert descr.lendescr is None


def test_get_array_descr_sign():
    for RESTYPE, signed in [(rffi.SIGNEDCHAR, True), (rffi.UCHAR,  False),
                            (rffi.SHORT,      True), (rffi.USHORT, False),
                            (rffi.INT,        True), (rffi.UINT,   False),
                            (rffi.LONG,       True), (rffi.ULONG,  False)]:
        A = lltype.GcArray(RESTYPE)
        for tsc in [False, True]:
            c2 = GcCache(tsc)
            arraydescr = get_array_descr(c2, A)
            assert arraydescr.flag == {False: FLAG_UNSIGNED,
                                       True:  FLAG_SIGNED  }[signed]
        #
        RA = rffi.CArray(RESTYPE)
        for tsc in [False, True]:
            c2 = GcCache(tsc)
            arraydescr = get_array_descr(c2, RA)
            assert arraydescr.flag == {False: FLAG_UNSIGNED,
                                       True:  FLAG_SIGNED  }[signed]


def test_get_array_descr_str():
    c0 = GcCache(False)
    descr1 = get_array_descr(c0, rstr.STR)
    assert descr1.itemsize == rffi.sizeof(lltype.Char)
    assert descr1.flag == FLAG_UNSIGNED


def test_get_call_descr_not_translated():
    c0 = GcCache(False)
    descr1 = get_call_descr(c0, [lltype.Char, lltype.Signed], lltype.Char)
    assert descr1.get_result_size() == rffi.sizeof(lltype.Char)
    assert descr1.get_result_type() == history.INT
    assert descr1.arg_classes == "ii"
    #
    T = lltype.GcStruct('T')
    descr2 = get_call_descr(c0, [lltype.Ptr(T)], lltype.Ptr(T))
    assert descr2.get_result_size() == rffi.sizeof(lltype.Ptr(T))
    assert descr2.get_result_type() == history.REF
    assert descr2.arg_classes == "r"
    #
    U = lltype.GcStruct('U', ('x', lltype.Signed))
    assert descr2 == get_call_descr(c0, [lltype.Ptr(U)], lltype.Ptr(U))
    #
    V = lltype.Struct('V', ('x', lltype.Signed))
    assert (get_call_descr(c0, [], lltype.Ptr(V)).get_result_type() ==
            history.INT)
    #
    assert (get_call_descr(c0, [], lltype.Void).get_result_type() ==
            history.VOID)
    #
    descr4 = get_call_descr(c0, [lltype.Float, lltype.Float], lltype.Float)
    assert descr4.get_result_size() == rffi.sizeof(lltype.Float)
    assert descr4.get_result_type() == history.FLOAT
    assert descr4.arg_classes == "ff"
    #
    descr5 = get_call_descr(c0, [lltype.SingleFloat], lltype.SingleFloat)
    assert descr5.get_result_size() == rffi.sizeof(lltype.SingleFloat)
    assert descr5.get_result_type() == "S"
    assert descr5.arg_classes == "S"

def test_get_call_descr_not_translated_longlong():
    if sys.maxint > 2147483647:
        py.test.skip("long long: for 32-bit only")
    c0 = GcCache(False)
    #
    descr5 = get_call_descr(c0, [lltype.SignedLongLong], lltype.Signed)
    assert descr5.get_result_size() == 4
    assert descr5.get_result_type() == history.INT
    assert descr5.arg_classes == "L"
    #
    descr6 = get_call_descr(c0, [lltype.Signed], lltype.SignedLongLong)
    assert descr6.get_result_size() == 8
    assert descr6.get_result_type() == "L"
    assert descr6.arg_classes == "i"

def test_get_call_descr_translated():
    c1 = GcCache(True)
    T = lltype.GcStruct('T')
    U = lltype.GcStruct('U', ('x', lltype.Signed))
    descr3 = get_call_descr(c1, [lltype.Ptr(T)], lltype.Ptr(U))
    assert isinstance(descr3.get_result_size(), Symbolic)
    assert descr3.get_result_type() == history.REF
    assert descr3.arg_classes == "r"
    #
    descr4 = get_call_descr(c1, [lltype.Float, lltype.Float], lltype.Float)
    assert isinstance(descr4.get_result_size(), Symbolic)
    assert descr4.get_result_type() == history.FLOAT
    assert descr4.arg_classes == "ff"
    #
    descr5 = get_call_descr(c1, [lltype.SingleFloat], lltype.SingleFloat)
    assert isinstance(descr5.get_result_size(), Symbolic)
    assert descr5.get_result_type() == "S"
    assert descr5.arg_classes == "S"

def test_call_descr_extra_info():
    c1 = GcCache(True)
    T = lltype.GcStruct('T')
    U = lltype.GcStruct('U', ('x', lltype.Signed))
    descr1 = get_call_descr(c1, [lltype.Ptr(T)], lltype.Ptr(U), "hello")
    extrainfo = descr1.get_extra_info()
    assert extrainfo == "hello"
    descr2 = get_call_descr(c1, [lltype.Ptr(T)], lltype.Ptr(U), "hello")
    assert descr1 is descr2
    descr3 = get_call_descr(c1, [lltype.Ptr(T)], lltype.Ptr(U))
    extrainfo = descr3.get_extra_info()
    assert extrainfo is None

def test_get_call_descr_sign():
    for RESTYPE, signed in [(rffi.SIGNEDCHAR, True), (rffi.UCHAR,  False),
                            (rffi.SHORT,      True), (rffi.USHORT, False),
                            (rffi.INT,        True), (rffi.UINT,   False),
                            (rffi.LONG,       True), (rffi.ULONG,  False)]:
        for tsc in [False, True]:
            c2 = GcCache(tsc)
            descr1 = get_call_descr(c2, [], RESTYPE)
            assert descr1.is_result_signed() == signed


def test_repr_of_descr():
    def repr_of_descr(descr):
        s = descr.repr_of_descr()
        assert ',' not in s  # makes the life easier for pypy.tool.jitlogparser
        return s
    c0 = GcCache(False)
    T = lltype.GcStruct('T')
    S = lltype.GcStruct('S', ('x', lltype.Char),
                             ('y', lltype.Ptr(T)),
                             ('z', lltype.Ptr(T)))
    descr1 = get_size_descr(c0, S)
    s = symbolic.get_size(S, False)
    assert repr_of_descr(descr1) == '<SizeDescr %d>' % s
    #
    descr2 = get_field_descr(c0, S, 'y')
    o, _ = symbolic.get_field_token(S, 'y', False)
    assert repr_of_descr(descr2) == '<FieldP S.y %d>' % o
    #
    descr2i = get_field_descr(c0, S, 'x')
    o, _ = symbolic.get_field_token(S, 'x', False)
    assert repr_of_descr(descr2i) == '<FieldU S.x %d>' % o
    #
    descr3 = get_array_descr(c0, lltype.GcArray(lltype.Ptr(S)))
    o = symbolic.get_size(lltype.Ptr(S), False)
    assert repr_of_descr(descr3) == '<ArrayP %d>' % o
    #
    descr3i = get_array_descr(c0, lltype.GcArray(lltype.Char))
    assert repr_of_descr(descr3i) == '<ArrayU 1>'
    #
    descr4 = get_call_descr(c0, [lltype.Char, lltype.Ptr(S)], lltype.Ptr(S))
    assert repr_of_descr(descr4) == '<Callr %d ir>' % o
    #
    descr4i = get_call_descr(c0, [lltype.Char, lltype.Ptr(S)], lltype.Char)
    assert repr_of_descr(descr4i) == '<Calli 1 ir>'
    #
    descr4f = get_call_descr(c0, [lltype.Char, lltype.Ptr(S)], lltype.Float)
    assert repr_of_descr(descr4f) == '<Callf 8 ir>'
    #
    descr5f = get_call_descr(c0, [lltype.Char], lltype.SingleFloat)
    assert repr_of_descr(descr5f) == '<CallS 4 i>'

def test_call_stubs_1():
    c0 = GcCache(False)
    ARGS = [lltype.Char, lltype.Signed]
    RES = lltype.Char
    descr1 = get_call_descr(c0, ARGS, RES)
    def f(a, b):
        return 'c'

    fnptr = llhelper(lltype.Ptr(lltype.FuncType(ARGS, RES)), f)

    res = descr1.call_stub_i(rffi.cast(lltype.Signed, fnptr),
                             [1, 2], None, None)
    assert res == ord('c')

def test_call_stubs_2():
    c0 = GcCache(False)
    ARRAY = lltype.GcArray(lltype.Signed)
    ARGS = [lltype.Float, lltype.Ptr(ARRAY)]
    RES = lltype.Float

    def f2(a, b):
        return float(b[0]) + a

    fnptr = llhelper(lltype.Ptr(lltype.FuncType(ARGS, RES)), f2)
    descr2 = get_call_descr(c0, ARGS, RES)
    a = lltype.malloc(ARRAY, 3)
    opaquea = lltype.cast_opaque_ptr(llmemory.GCREF, a)
    a[0] = 1
    res = descr2.call_stub_f(rffi.cast(lltype.Signed, fnptr),
                             [], [opaquea], [longlong.getfloatstorage(3.5)])
    assert longlong.getrealfloat(res) == 4.5

def test_call_stubs_single_float():
    from rpython.rlib.longlong2float import uint2singlefloat, singlefloat2uint
    from rpython.rlib.rarithmetic import r_singlefloat, intmask
    #
    c0 = GcCache(False)
    ARGS = [lltype.SingleFloat, lltype.SingleFloat, lltype.SingleFloat]
    RES = lltype.SingleFloat

    def f(a, b, c):
        a = float(a)
        b = float(b)
        c = float(c)
        x = a - (b / c)
        return r_singlefloat(x)

    fnptr = llhelper(lltype.Ptr(lltype.FuncType(ARGS, RES)), f)
    descr2 = get_call_descr(c0, ARGS, RES)
    a = intmask(singlefloat2uint(r_singlefloat(-10.0)))
    b = intmask(singlefloat2uint(r_singlefloat(3.0)))
    c = intmask(singlefloat2uint(r_singlefloat(2.0)))
    res = descr2.call_stub_i(rffi.cast(lltype.Signed, fnptr),
                             [a, b, c], [], [])
    assert float(uint2singlefloat(rffi.r_uint(res))) == -11.5

def test_field_arraylen_descr():
    c0 = GcCache(True)
    A1 = lltype.GcArray(lltype.Signed)
    fielddescr = get_field_arraylen_descr(c0, A1)
    assert isinstance(fielddescr, FieldDescr)
    ofs = fielddescr.offset
    assert repr(ofs) == '< ArrayLengthOffset <GcArray of Signed > >'
    #
    fielddescr = get_field_arraylen_descr(c0, rstr.STR)
    ofs = fielddescr.offset
    # order of attributes can change
    assert repr(ofs) in (
        "< <FieldOffset <GcStruct rpy_string { hash, chars }> 'chars'> "
        "+ < ArrayLengthOffset <Array of Char "
        "{'extra_item_after_alloc': 1, 'immutable': True} > > >",

        "< <FieldOffset <GcStruct rpy_string { hash, chars }> 'chars'> "
        "+ < ArrayLengthOffset <Array of Char "
        "{'immutable': True, 'extra_item_after_alloc': 1} > > >")
    # caching:
    assert fielddescr is get_field_arraylen_descr(c0, rstr.STR)

def test_bytearray_descr():
    c0 = GcCache(False)
    descr = get_array_descr(c0, rstr.STR)   # for bytearray
    # note that we get a basesize that has 1 extra byte for the final null char
    # (only for STR)
    assert descr.flag == FLAG_UNSIGNED
    assert descr.basesize == struct.calcsize("PP") + 1     # hash, length, extra
    assert descr.lendescr.offset == struct.calcsize("P")   # hash
    assert not descr.is_array_of_pointers()


def test_descr_integer_bounded():
    descr = FieldDescr('descr', 0, symbolic.SIZEOF_CHAR, FLAG_SIGNED)
    assert descr.is_integer_bounded()

    descr = FieldDescr('descr', 0, symbolic.WORD, FLAG_UNSIGNED)
    assert not descr.is_integer_bounded()

    descr = FieldDescr('descr', 0, symbolic.SIZEOF_FLOAT, FLAG_FLOAT)
    assert not descr.is_integer_bounded()


def test_descr_get_integer_bounds():
    descr = FieldDescr('decr', 0, 1, FLAG_UNSIGNED)
    assert descr.get_integer_min() == 0
    assert descr.get_integer_max() == 255

    descr = FieldDescr('descr', 0, 1, FLAG_SIGNED)
    assert descr.get_integer_min() == -128
    assert descr.get_integer_max() == 127


def test_size_descr_stack_overflow_bug():
    c0 = GcCache(False)
    S = lltype.GcForwardReference()
    P = lltype.Ptr(S)
    fields = [('x%d' % i, P) for i in range(1500)]
    S.become(lltype.GcStruct('S', *fields))
    get_size_descr(c0, S)
