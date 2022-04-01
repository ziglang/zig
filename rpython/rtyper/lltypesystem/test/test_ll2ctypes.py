import py, pytest
import sys, struct
import ctypes
from rpython.rtyper.lltypesystem import lltype, rffi, llmemory
from rpython.rtyper.tool import rffi_platform
from rpython.rtyper.lltypesystem.ll2ctypes import lltype2ctypes, ctypes2lltype
from rpython.rtyper.lltypesystem.ll2ctypes import standard_c_lib
from rpython.rtyper.lltypesystem.ll2ctypes import uninitialized2ctypes
from rpython.rtyper.lltypesystem.ll2ctypes import ALLOCATED, force_cast
from rpython.rtyper.lltypesystem.ll2ctypes import cast_adr_to_int, get_ctypes_type
from rpython.rtyper.lltypesystem.ll2ctypes import _llgcopaque
from rpython.rtyper.annlowlevel import llhelper
from rpython.rlib import rposix
from rpython.rlib.rposix import UNDERSCORE_ON_WIN32
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator import cdir
from rpython.tool.udir import udir
from rpython.rtyper.test.test_llinterp import interpret
from rpython.annotator.annrpython import RPythonAnnotator
from rpython.rtyper.rtyper import RPythonTyper
from rpython.rlib.rarithmetic import r_uint, get_long_pattern, is_emulated_long
from rpython.rlib.rarithmetic import is_valid_int

if False:    # for now, please keep it False by default
    from rpython.rtyper.lltypesystem import ll2ctypes
    ll2ctypes.do_allocation_in_far_regions()

"""
Win64:
To decouple the cpython machine level long from the faked integer
of the target rpython, I replaced most 'lltype.Signed' by 'rffi.LONG'.
It would be nicer to replace all lltypes constants by rffi equivalents,
or better if we had a way to address the specific different types of
the current and the target system layout explicitly.
Let's think of that when we go further and make the target completely
independent and configurable.
Why most and not all replaced?
Tests with direct tests become cumbersome, instead of direct number
assignment rffi.setintfield(s, 'x', 123) must be used.
So in cases with number constants, where the size is not relevant,
I kept lltype.signed .
"""

class TestLL2Ctypes(object):

    def setup_method(self, meth):
        ALLOCATED.clear()

    def test_primitive(self):
        assert lltype2ctypes(5) == 5
        assert lltype2ctypes('?') == ord('?')
        assert lltype2ctypes('\xE0') == 0xE0
        assert lltype2ctypes(unichr(1234)) == 1234
        assert ctypes2lltype(lltype.Signed, 5) == 5
        assert ctypes2lltype(lltype.Char, ord('a')) == 'a'
        assert ctypes2lltype(lltype.UniChar, ord(u'x')) == u'x'
        assert ctypes2lltype(lltype.Char, 0xFF) == '\xFF'
        assert lltype2ctypes(5.25) == 5.25
        assert ctypes2lltype(lltype.Float, 5.25) == 5.25
        assert lltype2ctypes(u'x') == ord(u'x')
        res = lltype2ctypes(rffi.r_singlefloat(-3.5))
        assert isinstance(res, ctypes.c_float)
        assert res.value == -3.5
        res = ctypes2lltype(lltype.SingleFloat, ctypes.c_float(-3.5))
        assert isinstance(res, rffi.r_singlefloat)
        assert float(res) == -3.5
        assert lltype2ctypes(rffi.r_ulong(-1)) == (1 << rffi.r_ulong.BITS) - 1
        res = ctypes2lltype(lltype.Unsigned, sys.maxint * 2 + 1)
        assert (res, type(res)) == (r_uint(-1), r_uint)
        assert ctypes2lltype(lltype.Bool, 0) is False
        assert ctypes2lltype(lltype.Bool, 1) is True

        res = lltype2ctypes(llmemory.sizeof(rffi.LONG))
        assert res == struct.calcsize("l")
        S = lltype.Struct('S', ('x', rffi.LONG), ('y', rffi.LONG))
        res = lltype2ctypes(llmemory.sizeof(S))
        assert res == struct.calcsize("ll")

        p = lltype.nullptr(S)
        cptr = lltype2ctypes(p)
        assert not cptr
        py.test.raises(ValueError, 'cptr.contents')   # NULL pointer access
        res = ctypes2lltype(lltype.Ptr(S), cptr)
        assert res == p
        assert not ALLOCATED     # detects memory leaks in the test

    def test_simple_struct(self):
        S = lltype.Struct('S', ('x', lltype.Signed), ('y', lltype.Signed))
        s = lltype.malloc(S, flavor='raw')
        rffi.setintfield(s, 'x', 123)
        sc = lltype2ctypes(s)
        assert isinstance(sc.contents, ctypes.Structure)
        assert sc.contents.x == 123
        sc.contents.x = 456
        assert s.x == 456
        s.x = 789
        assert sc.contents.x == 789
        s.y = 52
        assert sc.contents.y == 52
        lltype.free(s, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_get_pointer(self):
        # Equivalent of the C code::
        #     struct S1 { struct S2 *ptr; struct S2 buf; };
        #     struct S1 s1;
        #     s1.ptr = & s1.buf;
        S2 = lltype.Struct('S2', ('y', lltype.Signed))
        S1 = lltype.Struct('S',
                           ('sub', lltype.Struct('SUB',
                                                 ('ptr', lltype.Ptr(S2)))),
                           ('ptr', lltype.Ptr(S2)),
                           ('buf', S2), # Works when this field is first!
                           )
        s1 = lltype.malloc(S1, flavor='raw')
        s1.ptr = s1.buf
        s1.sub.ptr = s1.buf

        x = rffi.cast(rffi.CCHARP, s1)
        lltype.free(s1, flavor='raw')

    def test_struct_ptrs(self):
        S2 = lltype.Struct('S2', ('y', lltype.Signed))
        S1 = lltype.Struct('S', ('x', lltype.Signed), ('p', lltype.Ptr(S2)))
        s1 = lltype.malloc(S1, flavor='raw')
        s2a = lltype.malloc(S2, flavor='raw')
        s2b = lltype.malloc(S2, flavor='raw')
        s2a.y = ord('a')
        s2b.y = ord('b')
        sc1 = lltype2ctypes(s1)
        sc1.contents.x = 50
        assert s1.x == 50
        sc1.contents.p = lltype2ctypes(s2a)
        assert s1.p == s2a
        s1.p.y -= 32
        assert sc1.contents.p.contents.y == ord('A')
        s1.p = s2b
        sc1.contents.p.contents.y -= 32
        assert s2b.y == ord('B')
        lltype.free(s1, flavor='raw')
        lltype.free(s2a, flavor='raw')
        lltype.free(s2b, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_simple_array(self):
        A = lltype.Array(lltype.Signed)
        a = lltype.malloc(A, 10, flavor='raw')
        a[0] = 100
        a[1] = 101
        a[2] = 102
        ac = lltype2ctypes(a, normalize=False)
        assert isinstance(ac.contents, ctypes.Structure)
        assert ac.contents.length == 10
        if is_emulated_long:
            lentype = ctypes.c_longlong
        else:
            lentype = ctypes.c_long
        assert ac.contents._fields_[0] == ('length', lentype)
        assert ac.contents.items[1] == 101
        ac.contents.items[2] = 456
        assert a[2] == 456
        a[3] = 789
        assert ac.contents.items[3] == 789
        lltype.free(a, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_array_inside_struct(self):
        # like rstr.STR, but not Gc
        STR = lltype.Struct('STR', ('x', rffi.LONG), ('y', lltype.Array(lltype.Char)))
        a = lltype.malloc(STR, 3, flavor='raw')
        a.y[0] = 'x'
        a.y[1] = 'y'
        a.y[2] = 'z'
        # we need to pass normalize=False, otherwise 'ac' is returned of
        # a normalized standard type, which complains about IndexError
        # when doing 'ac.contents.y.items[2]'.
        ac = lltype2ctypes(a, normalize=False)
        assert ac.contents.y.length == 3
        assert ac.contents.y.items[2] == ord('z')
        lltype.free(a, flavor='raw')
        assert not ALLOCATED

    def test_array_nolength(self):
        A = lltype.Array(lltype.Signed, hints={'nolength': True})
        a = lltype.malloc(A, 10, flavor='raw')
        a[0] = 100
        a[1] = 101
        a[2] = 102
        ac = lltype2ctypes(a, normalize=False)
        assert isinstance(ac.contents, ctypes.Structure)
        assert ac.contents.items[1] == 101
        ac.contents.items[2] = 456
        assert a[2] == 456
        a[3] = 789
        assert ac.contents.items[3] == 789
        assert ctypes.sizeof(ac.contents) == 10 * rffi.sizeof(lltype.Signed)
        lltype.free(a, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_charp(self):
        s = rffi.str2charp("hello")
        sc = lltype2ctypes(s, normalize=False)
        assert sc.contents.items[0] == ord('h')
        assert sc.contents.items[1] == ord('e')
        assert sc.contents.items[2] == ord('l')
        assert sc.contents.items[3] == ord('l')
        assert sc.contents.items[4] == ord('o')
        assert sc.contents.items[5] == 0
        assert not hasattr(sc.contents, 'length')
        sc.contents.items[1] = ord('E')
        assert s[1] == 'E'
        s[0] = 'H'
        assert sc.contents.items[0] == ord('H')
        rffi.free_charp(s)
        assert not ALLOCATED     # detects memory leaks in the test

    def test_unicharp(self):
        SP = rffi.CArrayPtr(lltype.UniChar)
        s = lltype.malloc(SP.TO, 4, flavor='raw')
        s[0] = u'x'
        s[1] = u'y'
        s[2] = u'z'
        s[3] = u'\x00'
        sc = lltype2ctypes(s, normalize=False)
        assert sc.contents.items[0] == ord(u'x')
        assert sc.contents.items[1] == ord(u'y')
        assert sc.contents.items[2] == ord(u'z')
        assert not hasattr(sc.contents, 'length')
        lltype.free(s, flavor='raw')
        assert not ALLOCATED

    def test_strlen(self):
        eci = ExternalCompilationInfo(includes=['string.h'])
        strlen = rffi.llexternal('strlen', [rffi.CCHARP], rffi.SIZE_T,
                                 compilation_info=eci)
        s = rffi.str2charp("xxx")
        res = strlen(s)
        rffi.free_charp(s)
        assert res == 3     # actually r_size_t(3)
        s = rffi.str2charp("")
        res = strlen(s)
        rffi.free_charp(s)
        assert res == 0     # actually r_size_t(0)
        assert not ALLOCATED     # detects memory leaks in the test

    def test_func_not_in_clib(self):
        eci = ExternalCompilationInfo(libraries=['m'])
        foobar = rffi.llexternal('I_really_dont_exist', [], rffi.LONG)
        py.test.raises(NotImplementedError, foobar)

        foobar = rffi.llexternal('I_really_dont_exist', [], rffi.LONG,
                                 compilation_info=eci)    # math library
        py.test.raises(NotImplementedError, foobar)

        eci = ExternalCompilationInfo(libraries=['m', 'z'])
        foobar = rffi.llexternal('I_really_dont_exist', [], rffi.LONG,
                                 compilation_info=eci)  # math and zlib
        py.test.raises(NotImplementedError, foobar)

        eci = ExternalCompilationInfo(libraries=['I_really_dont_exist_either'])
        foobar = rffi.llexternal('I_really_dont_exist', [], rffi.LONG,
                                 compilation_info=eci)
        py.test.raises(NotImplementedError, foobar)
        assert not ALLOCATED     # detects memory leaks in the test

    def test_cstruct_to_ll(self):
        S = lltype.Struct('S', ('x', lltype.Signed), ('y', lltype.Signed))
        s = lltype.malloc(S, flavor='raw')
        s2 = lltype.malloc(S, flavor='raw')
        s.x = 123
        sc = lltype2ctypes(s)
        t = ctypes2lltype(lltype.Ptr(S), sc)
        assert lltype.typeOf(t) == lltype.Ptr(S)
        assert s == t
        assert not (s != t)
        assert t == s
        assert not (t != s)
        assert t != lltype.nullptr(S)
        assert not (t == lltype.nullptr(S))
        assert lltype.nullptr(S) != t
        assert not (lltype.nullptr(S) == t)
        assert t != s2
        assert not (t == s2)
        assert s2 != t
        assert not (s2 == t)
        assert t.x == 123
        t.x += 1
        assert s.x == 124
        s.x += 1
        assert t.x == 125
        lltype.free(s, flavor='raw')
        lltype.free(s2, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_carray_to_ll(self):
        A = lltype.Array(lltype.Signed, hints={'nolength': True})
        a = lltype.malloc(A, 10, flavor='raw')
        a2 = lltype.malloc(A, 10, flavor='raw')
        a[0] = 100
        a[1] = 101
        a[2] = 110
        ac = lltype2ctypes(a)
        b = ctypes2lltype(lltype.Ptr(A), ac)
        assert lltype.typeOf(b) == lltype.Ptr(A)
        assert b == a
        assert not (b != a)
        assert a == b
        assert not (a != b)
        assert b != lltype.nullptr(A)
        assert not (b == lltype.nullptr(A))
        assert lltype.nullptr(A) != b
        assert not (lltype.nullptr(A) == b)
        assert b != a2
        assert not (b == a2)
        assert a2 != b
        assert not (a2 == b)
        assert b[2] == 110
        b[2] *= 2
        assert a[2] == 220
        a[2] *= 3
        assert b[2] == 660
        lltype.free(a, flavor='raw')
        lltype.free(a2, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_strchr(self):
        eci = ExternalCompilationInfo(includes=['string.h'])
        strchr = rffi.llexternal('strchr', [rffi.CCHARP, rffi.INT],
                                 rffi.CCHARP, compilation_info=eci)
        s = rffi.str2charp("hello world")
        res = strchr(s, ord('r'))
        assert res[0] == 'r'
        assert res[1] == 'l'
        assert res[2] == 'd'
        assert res[3] == '\x00'
        # XXX maybe we should also allow res[-1], res[-2]...
        rffi.free_charp(s)
        assert not ALLOCATED     # detects memory leaks in the test

    def test_frexp(self):
        if sys.platform != 'win32':
            eci = ExternalCompilationInfo(includes=['math.h'],
                                          libraries=['m'])
        else:
            eci = ExternalCompilationInfo(includes=['math.h'])
        A = lltype.FixedSizeArray(rffi.INT, 1)
        frexp = rffi.llexternal('frexp', [rffi.DOUBLE, lltype.Ptr(A)],
                                rffi.DOUBLE, compilation_info=eci)
        p = lltype.malloc(A, flavor='raw')
        res = frexp(2.5, p)
        assert res == 0.625
        assert p[0] == 2
        lltype.free(p, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_rand(self):
        eci = ExternalCompilationInfo(includes=['stdlib.h'])
        rand = rffi.llexternal('rand', [], rffi.INT,
                               compilation_info=eci)
        srand = rffi.llexternal('srand', [rffi.UINT], lltype.Void,
                                compilation_info=eci)
        srand(rffi.r_uint(123))
        res1 = rand()
        res2 = rand()
        res3 = rand()
        srand(rffi.r_uint(123))
        res1b = rand()
        res2b = rand()
        res3b = rand()
        assert res1 == res1b
        assert res2 == res2b
        assert res3 == res3b
        assert not ALLOCATED     # detects memory leaks in the test

    def test_opaque_obj(self):
        if sys.platform == 'win32':
            py.test.skip("No gettimeofday on win32")
        eci = ExternalCompilationInfo(
            includes = ['sys/time.h', 'time.h']
        )
        TIMEVALP = rffi.COpaquePtr('struct timeval', compilation_info=eci)
        TIMEZONEP = rffi.COpaquePtr('struct timezone', compilation_info=eci)
        gettimeofday = rffi.llexternal('gettimeofday', [TIMEVALP, TIMEZONEP],
                                       rffi.INT, compilation_info=eci)
        ll_timevalp = lltype.malloc(TIMEVALP.TO, flavor='raw')
        ll_timezonep = lltype.malloc(TIMEZONEP.TO, flavor='raw')
        res = gettimeofday(ll_timevalp, ll_timezonep)
        assert res != -1
        lltype.free(ll_timezonep, flavor='raw')
        lltype.free(ll_timevalp, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_opaque_obj_2(self):
        FILEP = rffi.COpaquePtr('FILE')
        fopen = rffi.llexternal('fopen', [rffi.CCHARP, rffi.CCHARP], FILEP)
        fclose = rffi.llexternal('fclose', [FILEP], rffi.INT)
        tmppath = udir.join('test_ll2ctypes.test_opaque_obj_2')
        ll_file = fopen(str(tmppath), "w")
        assert ll_file
        fclose(ll_file)
        assert tmppath.check(file=1)
        assert not ALLOCATED     # detects memory leaks in the test

        assert rffi.cast(FILEP, -1) == rffi.cast(FILEP, -1)

    def test_simple_cast(self):
        assert rffi.cast(rffi.SIGNEDCHAR, 0x123456) == 0x56
        assert rffi.cast(rffi.SIGNEDCHAR, 0x123481) == -127
        assert rffi.cast(rffi.CHAR, 0x123456) == '\x56'
        assert rffi.cast(rffi.CHAR, 0x123481) == '\x81'
        assert rffi.cast(rffi.UCHAR, 0x123481) == 0x81
        assert not ALLOCATED     # detects memory leaks in the test

    def test_forced_ptr_cast(self):
        import array
        A = lltype.Array(lltype.Signed, hints={'nolength': True})
        B = lltype.Array(lltype.Char, hints={'nolength': True})
        a = lltype.malloc(A, 10, flavor='raw')
        for i in range(10):
            a[i] = i*i

        b = rffi.cast(lltype.Ptr(B), a)

        expected = ''
        for i in range(10):
            expected += get_long_pattern(i*i)

        for i in range(len(expected)):
            assert b[i] == expected[i]

        c = rffi.cast(rffi.VOIDP, a)
        addr = lltype2ctypes(c)
        #assert addr == ctypes.addressof(a._obj._ctypes_storage)
        d = ctypes2lltype(rffi.VOIDP, addr)
        assert lltype.typeOf(d) == rffi.VOIDP
        assert c == d
        e = rffi.cast(lltype.Ptr(A), d)
        for i in range(10):
            assert e[i] == i*i

        c = lltype.nullptr(rffi.VOIDP.TO)
        addr = rffi.cast(rffi.LONG, c)
        assert addr == 0

        lltype.free(a, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_adr_cast(self):
        from rpython.rtyper.annlowlevel import llstr
        from rpython.rtyper.lltypesystem.rstr import STR
        P = lltype.Ptr(lltype.FixedSizeArray(lltype.Char, 1))
        def f():
            a = llstr("xyz")
            b = (llmemory.cast_ptr_to_adr(a) + llmemory.offsetof(STR, 'chars')
                 + llmemory.itemoffsetof(STR.chars, 0))
            buf = rffi.cast(rffi.VOIDP, b)
            return buf[2]
        assert f() == 'z'
        res = interpret(f, [])
        assert res == 'z'

    def test_funcptr1(self):
        def dummy(n):
            return n+1

        FUNCTYPE = lltype.FuncType([lltype.Signed], lltype.Signed)
        cdummy = lltype2ctypes(llhelper(lltype.Ptr(FUNCTYPE), dummy))
        if not is_emulated_long:
            assert cdummy.argtypes == (ctypes.c_long,)
            assert cdummy.restype == ctypes.c_long
        else:
            # XXX maybe we skip this if it breaks on some platforms
            assert cdummy.argtypes == (ctypes.c_longlong,)
            assert cdummy.restype == ctypes.c_longlong
        res = cdummy(41)
        assert res == 42
        lldummy = ctypes2lltype(lltype.Ptr(FUNCTYPE), cdummy)
        assert lltype.typeOf(lldummy) == lltype.Ptr(FUNCTYPE)
        res = lldummy(41)
        assert res == 42
        assert not ALLOCATED     # detects memory leaks in the test

    def test_llhelper_error_value(self, monkeypatch):
        from rpython.rlib.objectmodel import llhelper_error_value
        class FooError(Exception):
            pass
        @llhelper_error_value(error_value=-7)
        def dummy(n):
            raise FooError(n + 2)

        FUNCTYPE = lltype.FuncType([lltype.Signed], lltype.Signed)
        cdummy = lltype2ctypes(llhelper(lltype.Ptr(FUNCTYPE), dummy))
        # here we pretend there is C in the middle
        lldummy = ctypes2lltype(lltype.Ptr(FUNCTYPE), cdummy,
                                force_real_ctypes_function=True)
        seen = []
        def custom_except_hook(*args):
            seen.append(args)
        monkeypatch.setattr(sys, 'excepthook', custom_except_hook)
        with pytest.raises(FooError) as exc:
            lldummy(41)
        assert exc.value.args == (41 + 2,)
        assert exc.value._ll2ctypes_c_result == -7
        assert not seen
        assert not ALLOCATED     # detects memory leaks in the test

    def test_funcptr2(self):
        FUNCTYPE = lltype.FuncType([rffi.CCHARP], rffi.LONG)
        cstrlen = standard_c_lib.strlen
        llstrlen = ctypes2lltype(lltype.Ptr(FUNCTYPE), cstrlen)
        assert lltype.typeOf(llstrlen) == lltype.Ptr(FUNCTYPE)
        p = rffi.str2charp("hi there")
        res = llstrlen(p)
        assert res == 8
        cstrlen2 = lltype2ctypes(llstrlen)
        cp = lltype2ctypes(p)
        assert cstrlen2.restype == ctypes.c_long
        res = cstrlen2(cp)
        assert res == 8
        rffi.free_charp(p)
        assert not ALLOCATED     # detects memory leaks in the test

    def test_funcptr_cast(self):
        eci = ExternalCompilationInfo(
            include_dirs = [cdir],
            separate_module_sources=["""
            #include "src/precommondefs.h"
            long mul(long x, long y) { return x*y; }
            RPY_EXPORTED long(*get_mul(long x)) () { return &mul; }
            """])
        get_mul = rffi.llexternal(
            'get_mul', [],
            lltype.Ptr(lltype.FuncType([lltype.Signed], lltype.Signed)),
            compilation_info=eci)
        # This call returns a pointer to a function taking one argument
        funcptr = get_mul()
        # cast it to the "real" function type
        FUNCTYPE2 = lltype.FuncType([lltype.Signed, lltype.Signed],
                                    lltype.Signed)
        cmul = rffi.cast(lltype.Ptr(FUNCTYPE2), funcptr)
        # and it can be called with the expected number of arguments
        res = cmul(41, 42)
        assert res == 41 * 42
        py.test.raises(TypeError, cmul, 41)
        py.test.raises(TypeError, cmul, 41, 42, 43)

    def test_qsort(self):
        CMPFUNC = lltype.FuncType([rffi.VOIDP, rffi.VOIDP], rffi.INT)
        qsort = rffi.llexternal('qsort', [rffi.VOIDP,
                                          rffi.SIZE_T,
                                          rffi.SIZE_T,
                                          lltype.Ptr(CMPFUNC)],
                                lltype.Void)

        lst = [23, 43, 24, 324, 242, 34, 78, 5, 3, 10]
        A = lltype.Array(lltype.Signed, hints={'nolength': True})
        a = lltype.malloc(A, 10, flavor='raw')
        for i in range(10):
            a[i] = lst[i]

        SIGNEDPTR = lltype.Ptr(lltype.FixedSizeArray(lltype.Signed, 1))

        def my_compar(p1, p2):
            p1 = rffi.cast(SIGNEDPTR, p1)
            p2 = rffi.cast(SIGNEDPTR, p2)
            print 'my_compar:', p1[0], p2[0]
            return rffi.cast(rffi.INT, cmp(p1[0], p2[0]))

        qsort(rffi.cast(rffi.VOIDP, a),
              rffi.cast(rffi.SIZE_T, 10),
              rffi.cast(rffi.SIZE_T, llmemory.sizeof(lltype.Signed)),
              llhelper(lltype.Ptr(CMPFUNC), my_compar))

        for i in range(10):
            print a[i],
        print
        lst.sort()
        for i in range(10):
            assert a[i] == lst[i]
        lltype.free(a, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    # def test_signal(self):...

    def test_uninitialized2ctypes(self):
        # for now, uninitialized fields are filled with 0xDD in the ctypes data
        def checkobj(o, size):
            p = ctypes.cast(ctypes.c_void_p(ctypes.addressof(o)),
                            ctypes.POINTER(ctypes.c_ubyte*size))
            for i in range(size):
                assert p.contents[i] == 0xDD

        def checkval(v, fmt):
            res = struct.pack(fmt, v)
            assert res == "\xDD" * len(res)

        checkval(uninitialized2ctypes(rffi.CHAR), 'B')
        checkval(uninitialized2ctypes(rffi.SHORT), 'h')
        if not is_emulated_long:
            checkval(uninitialized2ctypes(rffi.INT), 'i')
            checkval(uninitialized2ctypes(rffi.UINT), 'I')
        checkval(uninitialized2ctypes(rffi.LONGLONG), 'q')
        checkval(uninitialized2ctypes(rffi.DOUBLE), 'd')
        checkobj(uninitialized2ctypes(rffi.INTP),
                 ctypes.sizeof(ctypes.c_void_p))
        checkobj(uninitialized2ctypes(rffi.CCHARP),
                 ctypes.sizeof(ctypes.c_void_p))

        S = lltype.Struct('S', ('x', rffi.LONG), ('y', rffi.LONG))
        s = lltype.malloc(S, flavor='raw')
        sc = lltype2ctypes(s)
        checkval(sc.contents.x, 'l')
        checkval(sc.contents.y, 'l')
        lltype.free(s, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_substructures(self):
        S1  = lltype.Struct('S1', ('x', lltype.Signed))
        BIG = lltype.Struct('BIG', ('s1a', S1), ('s1b', S1))
        s = lltype.malloc(BIG, flavor='raw')
        s.s1a.x = 123
        s.s1b.x = 456
        sc = lltype2ctypes(s)
        assert sc.contents.s1a.x == 123
        assert sc.contents.s1b.x == 456
        sc.contents.s1a.x += 1
        sc.contents.s1b.x += 10
        assert s.s1a.x == 124
        assert s.s1b.x == 466
        s.s1a.x += 3
        s.s1b.x += 30
        assert sc.contents.s1a.x == 127
        assert sc.contents.s1b.x == 496
        lltype.free(s, flavor='raw')

        s = lltype.malloc(BIG, flavor='raw')
        s1ac = lltype2ctypes(s.s1a)
        s1ac.contents.x = 53
        sc = lltype2ctypes(s)
        assert sc.contents.s1a.x == 53
        sc.contents.s1a.x += 1
        assert s1ac.contents.x == 54
        assert s.s1a.x == 54
        s.s1a.x += 2
        assert s1ac.contents.x == 56
        assert sc.contents.s1a.x == 56
        sc.contents.s1a.x += 3
        assert s1ac.contents.x == 59
        assert s.s1a.x == 59

        t = ctypes2lltype(lltype.Ptr(BIG), sc)
        assert t == s
        assert t.s1a == s.s1a
        assert t.s1a.x == 59
        s.s1b.x = 8888
        assert t.s1b == s.s1b
        assert t.s1b.x == 8888
        t1 = ctypes2lltype(lltype.Ptr(S1), s1ac)
        assert t.s1a == t1
        assert t1.x == 59
        t1.x += 1
        assert sc.contents.s1a.x == 60
        lltype.free(s, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_recursive_struct(self):
        SX = lltype.ForwardReference()
        S1 = lltype.Struct('S1', ('p', lltype.Ptr(SX)), ('x', lltype.Signed))
        SX.become(S1)
        # a chained list
        s1 = lltype.malloc(S1, flavor='raw')
        s2 = lltype.malloc(S1, flavor='raw')
        s3 = lltype.malloc(S1, flavor='raw')
        s1.x = 111
        s2.x = 222
        s3.x = 333
        s1.p = s2
        s2.p = s3
        s3.p = lltype.nullptr(S1)
        sc1 = lltype2ctypes(s1)
        sc2 = sc1.contents.p
        sc3 = sc2.contents.p
        assert not sc3.contents.p
        assert sc1.contents.x == 111
        assert sc2.contents.x == 222
        assert sc3.contents.x == 333
        sc3.contents.x += 1
        assert s3.x == 334
        s3.x += 2
        assert sc3.contents.x == 336
        lltype.free(s1, flavor='raw')
        lltype.free(s2, flavor='raw')
        lltype.free(s3, flavor='raw')
        # a self-cycle
        s1 = lltype.malloc(S1, flavor='raw')
        s1.x = 12
        s1.p = s1
        sc1 = lltype2ctypes(s1)
        assert sc1.contents.x == 12
        assert (ctypes.addressof(sc1.contents.p.contents) ==
                ctypes.addressof(sc1.contents))
        s1.x *= 5
        assert sc1.contents.p.contents.p.contents.p.contents.x == 60
        lltype.free(s1, flavor='raw')
        # a longer cycle
        s1 = lltype.malloc(S1, flavor='raw')
        s2 = lltype.malloc(S1, flavor='raw')
        s1.x = 111
        s1.p = s2
        s2.x = 222
        s2.p = s1
        sc1 = lltype2ctypes(s1)
        assert sc1.contents.x == 111
        assert sc1.contents.p.contents.x == 222
        assert (ctypes.addressof(sc1.contents.p.contents) !=
                ctypes.addressof(sc1.contents))
        assert (ctypes.addressof(sc1.contents.p.contents.p.contents) ==
                ctypes.addressof(sc1.contents))
        lltype.free(s1, flavor='raw')
        lltype.free(s2, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_indirect_recursive_struct(self):
        S2Forward = lltype.ForwardReference()
        S1 = lltype.Struct('S1', ('p', lltype.Ptr(S2Forward)))
        A2 = lltype.Array(lltype.Ptr(S1), hints={'nolength': True})
        S2 = lltype.Struct('S2', ('a', lltype.Ptr(A2)))
        S2Forward.become(S2)
        s1 = lltype.malloc(S1, flavor='raw')
        a2 = lltype.malloc(A2, 10, flavor='raw')
        s2 = lltype.malloc(S2, flavor='raw')
        s2.a = a2
        a2[5] = s1
        s1.p = s2
        ac2 = lltype2ctypes(a2, normalize=False)
        sc1 = ac2.contents.items[5]
        sc2 = sc1.contents.p
        assert (ctypes.addressof(sc2.contents.a.contents) ==
                ctypes.addressof(ac2.contents))
        lltype.free(s1, flavor='raw')
        lltype.free(a2, flavor='raw')
        lltype.free(s2, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_arrayofstruct(self):
        S1 = lltype.Struct('S2', ('x', lltype.Signed))
        A = lltype.Array(S1, hints={'nolength': True})
        a = lltype.malloc(A, 5, flavor='raw')
        a[0].x = 100
        a[1].x = 101
        a[2].x = 102
        a[3].x = 103
        a[4].x = 104
        ac = lltype2ctypes(a, normalize=False)
        assert ac.contents.items[0].x == 100
        assert ac.contents.items[2].x == 102
        ac.contents.items[3].x += 500
        assert a[3].x == 603
        a[4].x += 600
        assert ac.contents.items[4].x == 704
        a1 = ctypes2lltype(lltype.Ptr(A), ac)
        assert a1 == a
        assert a1[2].x == 102
        aitem1 = ctypes2lltype(lltype.Ptr(S1),
                               ctypes.pointer(ac.contents.items[1]))
        assert aitem1.x == 101
        assert aitem1 == a1[1]
        lltype.free(a, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_get_errno(self):
        eci = ExternalCompilationInfo(includes=['string.h'])
        if sys.platform.startswith('win'):
            py.test.skip('writing to invalid fd on windows crashes the process')
            # Note that cpython before 2.7 installs an _invalid_parameter_handler,
            # which is why the test passes there, but this is no longer
            # accepted practice.
            import ctypes
            SEM_NOGPFAULTERRORBOX = 0x0002 # From MSDN
            old_err_mode = ctypes.windll.kernel32.GetErrorMode()
            new_err_mode = old_err_mode | SEM_NOGPFAULTERRORBOX
            ctypes.windll.kernel32.SetErrorMode(new_err_mode)
        os_write_no_errno = rffi.llexternal(UNDERSCORE_ON_WIN32 + 'write',
                                   [rffi.INT, rffi.CCHARP, rffi.SIZE_T],
                                   rffi.SIZE_T, save_err=rffi.RFFI_ERR_NONE)
        os_write = rffi.llexternal(UNDERSCORE_ON_WIN32 + 'write',
                                   [rffi.INT, rffi.CCHARP, rffi.SIZE_T],
                                   rffi.SIZE_T, save_err=rffi.RFFI_SAVE_ERRNO)
        buffer = lltype.malloc(rffi.CCHARP.TO, 5, flavor='raw')
        written = os_write(12312312, buffer, 5)
        if sys.platform.startswith('win'):
            ctypes.windll.kernel32.SetErrorMode(old_err_mode)
        assert rffi.cast(rffi.LONG, written) < 0
        # the next line is a different external function call
        # without RFFI_SAVE_ERRNO, to check that it doesn't reset errno
        buffer[0] = '\n'
        os_write_no_errno(2, buffer, 1)
        lltype.free(buffer, flavor='raw')
        err = rposix.get_saved_errno()
        import errno
        assert err == errno.EBADF
        assert not ALLOCATED     # detects memory leaks in the test

    def test_call_with_struct_argument(self):
        # XXX is there such a function in the standard C headers?
        from rpython.rlib import _rsocket_rffi
        buf = rffi.make(_rsocket_rffi.in_addr)
        rffi.cast(rffi.CCHARP, buf)[0] = '\x01'
        rffi.cast(rffi.CCHARP, buf)[1] = '\x02'
        rffi.cast(rffi.CCHARP, buf)[2] = '\x03'
        rffi.cast(rffi.CCHARP, buf)[3] = '\x04'
        p = _rsocket_rffi.inet_ntoa(buf)
        assert rffi.charp2str(p) == '1.2.3.4'
        lltype.free(buf, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_storage_stays_around(self):
        data = "hello, world!" * 100
        A = lltype.Array(rffi.CHAR, hints={'nolength': True})
        S = lltype.Struct('S', ('a', lltype.Ptr(A)))
        s = lltype.malloc(S, flavor='raw')
        lltype2ctypes(s)     # force it to escape
        s.a = lltype.malloc(A, len(data), flavor='raw')
        # the storage for the array should not be freed by lltype even
        # though the _ptr object appears to go away here
        for i in xrange(len(data)):
            s.a[i] = data[i]
        for i in xrange(len(data)):
            assert s.a[i] == data[i]
        lltype.free(s.a, flavor='raw')
        lltype.free(s, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_arrayoffloat(self):
        a = lltype.malloc(rffi.FLOATP.TO, 3, flavor='raw')
        a[0] = rffi.r_singlefloat(0.0)
        a[1] = rffi.r_singlefloat(1.1)
        a[2] = rffi.r_singlefloat(2.2)
        ac = lltype2ctypes(a, normalize=False)
        assert ac.contents.items[0] == 0.0
        assert abs(ac.contents.items[1] - 1.1) < 1E-6
        assert abs(ac.contents.items[2] - 2.2) < 1E-6
        b = ctypes2lltype(rffi.FLOATP, ac)
        assert isinstance(b[0], rffi.r_singlefloat)
        assert float(b[0]) == 0.0
        assert isinstance(b[1], rffi.r_singlefloat)
        assert abs(float(b[1]) - 1.1) < 1E-6
        assert isinstance(b[2], rffi.r_singlefloat)
        assert abs(float(b[2]) - 2.2) < 1E-6
        lltype.free(a, flavor='raw')

    def test_different_signatures(self):
        if sys.platform=='win32':
            py.test.skip("No fcntl on win32")
        fcntl_int = rffi.llexternal('fcntl', [rffi.INT, rffi.INT, rffi.INT],
                                    rffi.INT)
        fcntl_str = rffi.llexternal('fcntl', [rffi.INT, rffi.INT, rffi.CCHARP],
                                    rffi.INT)
        fcntl_int(12345, 1, 0)
        fcntl_str(12345, 3, "xxx")
        fcntl_int(12345, 1, 0)

    def test_llexternal_source(self):
        eci = ExternalCompilationInfo(
            include_dirs = [cdir],
            separate_module_sources = ["""
            #include "src/precommondefs.h"
            RPY_EXPORTED int fn() { return 42; }
            """],
        )
        fn = rffi.llexternal('fn', [], rffi.INT, compilation_info=eci)
        res = fn()
        assert res == 42

    def test_llexternal_macro(self):
        eci = ExternalCompilationInfo(
            post_include_bits = ["#define fn(x) (42 + x)"],
        )
        fn1 = rffi.llexternal('fn', [rffi.INT], rffi.INT,
                              compilation_info=eci, macro=True)
        fn2 = rffi.llexternal('fn2', [rffi.DOUBLE], rffi.DOUBLE,
                              compilation_info=eci, macro='fn')
        res = fn1(10)
        assert res == 52
        res = fn2(10.5)
        assert res == 52.5

    def test_prebuilt_constant(self):
        header = py.code.Source("""
        #ifndef _SOME_H
        #define _SOME_H

        #include <stdlib.h>

        static long x = 3;
        static int y = 5;
        char **z = NULL;

        #endif  /* _SOME_H */
        """)
        h_file = udir.join("some_h.h")
        h_file.write(header)

        eci = ExternalCompilationInfo(includes=['stdio.h', str(h_file.basename)],
                                      include_dirs=[str(udir)])

        get_x, set_x = rffi.CExternVariable(rffi.LONG, 'x', eci, c_type='long')
        get_y, set_y = rffi.CExternVariable(rffi.INT, 'y', eci, c_type='int')
        get_z, set_z = rffi.CExternVariable(rffi.CCHARPP, 'z', eci)

        def f():
            one = get_x()
            set_x(13)
            return one + get_x()

        def fy():
            one = rffi.cast(rffi.LONG, get_y())
            set_y(rffi.cast(rffi.INT, 13))
            return one + rffi.cast(rffi.LONG, get_y())

        def g():
            l = rffi.liststr2charpp(["a", "b", "c"])
            try:
                set_z(l)
                return rffi.charp2str(get_z()[2])
            finally:
                rffi.free_charpp(l)

        res = f()
        assert res == 16
        res = fy()
        assert res == 18
        res = g()
        assert res == "c"

    def test_c_callback(self):
        c_source = py.code.Source("""
        #include "src/precommondefs.h"

        RPY_EXPORTED
        int eating_callback(int arg, int(*call)(int))
        {
            return call(arg);
        }
        """)

        eci = ExternalCompilationInfo(include_dirs=[cdir],
                                      separate_module_sources=[c_source])

        args = [rffi.INT, rffi.CCallback([rffi.INT], rffi.INT)]
        eating_callback = rffi.llexternal('eating_callback', args, rffi.INT,
                                          compilation_info=eci)

        def g(i):
            return i + 3

        def f():
            return eating_callback(3, g)

        assert f() == 6

    def test_qsort_callback(self):
        TP = rffi.CArrayPtr(rffi.INT)
        a = lltype.malloc(TP.TO, 5, flavor='raw')
        a[0] = rffi.r_int(5)
        a[1] = rffi.r_int(3)
        a[2] = rffi.r_int(2)
        a[3] = rffi.r_int(1)
        a[4] = rffi.r_int(4)

        def compare(a, b):
            # do not use a,b directly! on a big endian machine
            # ((void*)ptr)[0] will return 0x0 if the 32 bit value
            # ptr points to is 0x1
            a = rffi.cast(rffi.INTP, a)
            b = rffi.cast(rffi.INTP, b)
            if a[0] > b[0]:
                return rffi.r_int(1)
            else:
                return rffi.r_int(-1)

        CALLBACK = rffi.CCallback([rffi.VOIDP, rffi.VOIDP], rffi.INT)
        qsort = rffi.llexternal('qsort', [rffi.VOIDP, rffi.SIZE_T,
                                          rffi.SIZE_T, CALLBACK], lltype.Void)

        qsort(rffi.cast(rffi.VOIDP, a), 5, rffi.sizeof(rffi.INT), compare)
        for i in range(5):
            assert a[i] == i + 1
        lltype.free(a, flavor='raw')

    def test_array_type_bug(self):
        A = lltype.Array(rffi.LONG)
        a1 = lltype.malloc(A, 0, flavor='raw')
        a2 = lltype.malloc(A, 0, flavor='raw')
        c1 = lltype2ctypes(a1)
        c2 = lltype2ctypes(a2)
        assert type(c1) is type(c2)
        lltype.free(a1, flavor='raw')
        lltype.free(a2, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_varsized_struct(self):
        S = lltype.Struct('S', ('x', lltype.Signed),
                               ('a', lltype.Array(lltype.Char)))
        s1 = lltype.malloc(S, 6, flavor='raw')
        s1.x = 5
        s1.a[2] = 'F'
        sc = lltype2ctypes(s1, normalize=False)
        assert isinstance(sc.contents, ctypes.Structure)
        assert sc.contents.x == 5
        assert sc.contents.a.length == 6
        assert sc.contents.a.items[2] == ord('F')
        sc.contents.a.items[3] = ord('P')
        assert s1.a[3] == 'P'
        s1.a[1] = 'y'
        assert sc.contents.a.items[1] == ord('y')
        # now go back to lltype...
        res = ctypes2lltype(lltype.Ptr(S), sc)
        assert res == s1
        assert res.x == 5
        assert len(res.a) == 6
        lltype.free(s1, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_with_explicit_length(self):
        A = lltype.Array(lltype.Signed)
        a1 = lltype.malloc(A, 5, flavor='raw')
        a1[0] = 42
        c1 = lltype2ctypes(a1, normalize=False)
        assert c1.contents.length == 5
        assert c1.contents.items[0] == 42
        res = ctypes2lltype(lltype.Ptr(A), c1)
        assert res == a1
        assert len(res) == 5
        assert res[0] == 42
        res[0] += 1
        assert c1.contents.items[0] == 43
        assert a1[0] == 43
        a1[0] += 2
        assert c1.contents.items[0] == 45
        assert a1[0] == 45
        c1.contents.items[0] += 3
        assert res[0] == 48
        assert a1[0] == 48
        lltype.free(a1, flavor='raw')
        assert not ALLOCATED     # detects memory leaks in the test

    def test_c_callback_with_void_arg_2(self):
        ftest = []
        def f(x):
            ftest.append(x)
        F = lltype.FuncType([lltype.Void], lltype.Void)
        fn = lltype.functionptr(F, 'askjh', _callable=f, _void0=-5)
        fn(-5)
        assert ftest == [-5]
        fn2 = lltype2ctypes(fn)
        fn2()
        assert ftest == [-5, -5]
        fn3 = ctypes2lltype(lltype.Ptr(F), fn2)
        fn3(-5)
        assert ftest == [-5, -5, -5]

    def test_c_callback_with_void_arg_3(self):
        from rpython.rtyper.lltypesystem.rstr import LLHelpers
        def f(i):
            x = 'X' * i
            return x[-2]
        a = RPythonAnnotator()
        r = a.build_types(f, [int])
        rtyper = RPythonTyper(a)
        rtyper.specialize()
        a.translator.rtyper = rtyper
        graph = a.translator.graphs[0]
        op = graph.startblock.operations[-1]
        assert op.opname == 'direct_call'
        assert op.args[0].value._obj._callable == LLHelpers.ll_stritem.im_func
        assert op.args[1].value == LLHelpers
        assert op.args[3].value == -2

    def test_recursive_struct_more(self):
        NODE = lltype.ForwardReference()
        NODE.become(lltype.Struct('NODE', ('value', rffi.LONG),
                                          ('next', lltype.Ptr(NODE))))
        CNODEPTR = get_ctypes_type(NODE)
        pc = CNODEPTR()
        pc.value = 42
        pc.next = ctypes.pointer(pc)
        p = ctypes2lltype(lltype.Ptr(NODE), ctypes.pointer(pc))
        assert p.value == 42
        assert p.next == p
        pc2 = lltype2ctypes(p)
        assert pc2.contents.value == 42
        assert pc2.contents.next.contents.value == 42

    def test_indirect_recursive_struct_more(self):
        NODE = lltype.ForwardReference()
        NODE2 = lltype.Struct('NODE2', ('ping', lltype.Ptr(NODE)))
        NODE.become(lltype.Struct('NODE', ('pong', NODE2)))

        # Building NODE2 first used to fail.
        get_ctypes_type(NODE2)

        CNODEPTR = get_ctypes_type(NODE)
        pc = CNODEPTR()
        pc.pong.ping = ctypes.pointer(pc)
        p = ctypes2lltype(lltype.Ptr(NODE), ctypes.pointer(pc))
        assert p.pong.ping == p

    def test_typedef(self):
        assert ctypes2lltype(lltype.Typedef(rffi.LONG, 'test'), 6) == 6
        assert ctypes2lltype(lltype.Typedef(lltype.Float, 'test2'), 3.4) == 3.4

        assert get_ctypes_type(rffi.LONG) == get_ctypes_type(
            lltype.Typedef(rffi.LONG, 'test3'))

    def test_cast_adr_to_int(self):
        class someaddr(object):
            def _cast_to_int(self):
                return sys.maxint/2 * 3

        res = cast_adr_to_int(someaddr())
        assert is_valid_int(res)
        assert res == -sys.maxint/2 - 3

    def test_cast_gcref_back_and_forth(self):
        NODE = lltype.GcStruct('NODE')
        node = lltype.malloc(NODE)
        ref = lltype.cast_opaque_ptr(llmemory.GCREF, node)
        back = rffi.cast(llmemory.GCREF, rffi.cast(lltype.Signed, ref))
        assert lltype.cast_opaque_ptr(lltype.Ptr(NODE), back) == node

    def test_gcref_forth_and_back(self):
        cp = ctypes.c_void_p(1234)
        v = ctypes2lltype(llmemory.GCREF, cp)
        assert lltype2ctypes(v).value == cp.value
        v1 = ctypes2lltype(llmemory.GCREF, cp)
        assert v == v1
        assert v
        v2 = ctypes2lltype(llmemory.GCREF, ctypes.c_void_p(1235))
        assert v2 != v

    def test_gcref_type(self):
        NODE = lltype.GcStruct('NODE')
        node = lltype.malloc(NODE)
        ref = lltype.cast_opaque_ptr(llmemory.GCREF, node)
        v = lltype2ctypes(ref)
        assert isinstance(v, ctypes.c_void_p)

    def test_gcref_null(self):
        ref = lltype.nullptr(llmemory.GCREF.TO)
        v = lltype2ctypes(ref)
        assert isinstance(v, ctypes.c_void_p)

    def test_cast_null_gcref(self):
        ref = lltype.nullptr(llmemory.GCREF.TO)
        value = rffi.cast(lltype.Signed, ref)
        assert value == 0

    def test_cast_null_fakeaddr(self):
        ref = llmemory.NULL
        value = rffi.cast(lltype.Signed, ref)
        assert value == 0

    def test_gcref_truth(self):
        p0 = ctypes.c_void_p(0)
        ref0 = ctypes2lltype(llmemory.GCREF, p0)
        assert not ref0

        p1234 = ctypes.c_void_p(1234)
        ref1234 = ctypes2lltype(llmemory.GCREF, p1234)
        assert p1234

    def test_gcref_casts(self):
        p0 = ctypes.c_void_p(0)
        ref0 = ctypes2lltype(llmemory.GCREF, p0)

        assert lltype.cast_ptr_to_int(ref0) == 0
        assert llmemory.cast_ptr_to_adr(ref0) == llmemory.NULL

        NODE = lltype.GcStruct('NODE')
        assert lltype.cast_opaque_ptr(lltype.Ptr(NODE), ref0) == lltype.nullptr(NODE)

        node = lltype.malloc(NODE)
        ref1 = lltype.cast_opaque_ptr(llmemory.GCREF, node)

        intval  = rffi.cast(lltype.Signed, node)
        intval1 = rffi.cast(lltype.Signed, ref1)

        assert intval == intval1

        ref2 = ctypes2lltype(llmemory.GCREF, intval1)

        assert lltype.cast_opaque_ptr(lltype.Ptr(NODE), ref2) == node

        #addr = llmemory.cast_ptr_to_adr(ref1)
        #assert llmemory.cast_adr_to_int(addr) == intval

        #assert lltype.cast_ptr_to_int(ref1) == intval

        x = rffi.cast(llmemory.GCREF, -17)
        assert lltype.cast_ptr_to_int(x) == -17

    def test_ptr_truth(self):
        abc = rffi.cast(lltype.Ptr(lltype.FuncType([], lltype.Void)), 0)
        assert not abc

    def test_mixed_gcref_comparison(self):
        NODE = lltype.GcStruct('NODE')
        node = lltype.malloc(NODE)
        ref1 = lltype.cast_opaque_ptr(llmemory.GCREF, node)
        ref2 = rffi.cast(llmemory.GCREF, 123)

        assert ref1 != ref2
        assert not (ref1 == ref2)

        assert ref2 != ref1
        assert not (ref2 == ref1)

        assert node._obj._storage is True

        # forced!
        rffi.cast(lltype.Signed, ref1)
        assert node._obj._storage not in (True, None)

        assert ref1 != ref2
        assert not (ref1 == ref2)

        assert ref2 != ref1
        assert not (ref2 == ref1)

    def test_gcref_comparisons_back_and_forth(self):
        NODE = lltype.GcStruct('NODE')
        node = lltype.malloc(NODE)
        ref1 = lltype.cast_opaque_ptr(llmemory.GCREF, node)
        numb = rffi.cast(lltype.Signed, ref1)
        ref2 = rffi.cast(llmemory.GCREF, numb)
        assert ref1 == ref2
        assert ref2 == ref1
        assert not (ref1 != ref2)
        assert not (ref2 != ref1)

    def test_convert_subarray(self):
        A = lltype.GcArray(lltype.Signed)
        a = lltype.malloc(A, 20)
        inside = lltype.direct_ptradd(lltype.direct_arrayitems(a), 3)

        lltype2ctypes(inside)

        start = rffi.cast(lltype.Signed, lltype.direct_arrayitems(a))
        inside_int = rffi.cast(lltype.Signed, inside)

        assert inside_int == start+rffi.sizeof(lltype.Signed)*3

    def test_gcref_comparisons_through_addresses(self):
        NODE = lltype.GcStruct('NODE')
        n0 = lltype.malloc(NODE)
        adr0 = llmemory.cast_ptr_to_adr(n0)

        n1 = lltype.malloc(NODE)
        i1 = rffi.cast(lltype.Signed, n1)
        ref1 = rffi.cast(llmemory.GCREF, i1)
        adr1 = llmemory.cast_ptr_to_adr(ref1)

        assert adr1 != adr0
        assert adr0 != adr1

        adr1_2 = llmemory.cast_ptr_to_adr(n1)

        #import pdb; pdb.set_trace()
        assert adr1_2 == adr1
        assert adr1 == adr1_2

    def test_object_subclass(self):
        from rpython.rtyper import rclass
        from rpython.rtyper.annlowlevel import cast_instance_to_base_ptr
        from rpython.rtyper.annlowlevel import cast_base_ptr_to_instance
        class S:
            pass
        def f(n):
            s = S()
            s.x = n
            ls = cast_instance_to_base_ptr(s)
            as_num = rffi.cast(lltype.Signed, ls)
            # --- around this point, only 'as_num' is passed
            t = rffi.cast(rclass.OBJECTPTR, as_num)
            u = cast_base_ptr_to_instance(S, t)
            return u.x
        res = interpret(f, [123])
        assert res == 123

    def test_object_subclass_2(self):
        from rpython.rtyper import rclass
        SCLASS = lltype.GcStruct('SCLASS',
                                 ('parent', rclass.OBJECT),
                                 ('n', lltype.Signed))
        sclass_vtable = lltype.malloc(rclass.OBJECT_VTABLE, zero=True,
                                      immortal=True)
        sclass_vtable.name = rclass.alloc_array_name('SClass')
        def f(n):
            rclass.declare_type_for_typeptr(sclass_vtable, SCLASS)
            s = lltype.malloc(SCLASS)
            s.parent.typeptr = sclass_vtable
            s.n = n
            as_num = rffi.cast(lltype.Signed, s)
            # --- around this point, only 'as_num' is passed
            t = rffi.cast(lltype.Ptr(SCLASS), as_num)
            return t.n
        res = interpret(f, [123])
        assert res == 123

    def test_object_subclass_3(self):
        from rpython.rtyper import rclass
        from rpython.rtyper.annlowlevel import cast_instance_to_base_ptr
        from rpython.rtyper.annlowlevel import cast_base_ptr_to_instance
        class S:
            pass
        def f(n):
            s = S()
            s.x = n
            ls = cast_instance_to_base_ptr(s)
            as_num = rffi.cast(lltype.Signed, ls)
            # --- around this point, only 'as_num' is passed
            r = rffi.cast(llmemory.GCREF, as_num)
            t = lltype.cast_opaque_ptr(rclass.OBJECTPTR, r)
            u = cast_base_ptr_to_instance(S, t)
            return u.x
        res = interpret(f, [123])
        assert res == 123

    def test_object_subclass_4(self):
        from rpython.rtyper import rclass
        SCLASS = lltype.GcStruct('SCLASS',
                                 ('parent', rclass.OBJECT),
                                 ('n', lltype.Signed))
        sclass_vtable = lltype.malloc(rclass.OBJECT_VTABLE, zero=True,
                                      immortal=True)
        sclass_vtable.name = rclass.alloc_array_name('SClass')
        def f(n):
            rclass.declare_type_for_typeptr(sclass_vtable, SCLASS)
            s = lltype.malloc(SCLASS)
            s.parent.typeptr = sclass_vtable
            s.n = n
            as_num = rffi.cast(lltype.Signed, s)
            # --- around this point, only 'as_num' is passed
            r = rffi.cast(llmemory.GCREF, as_num)
            t = lltype.cast_opaque_ptr(lltype.Ptr(SCLASS), r)
            return t.n
        res = interpret(f, [123])
        assert res == 123

    def test_object_subclass_5(self):
        from rpython.rtyper import rclass
        from rpython.rtyper.annlowlevel import cast_instance_to_base_ptr
        from rpython.rtyper.annlowlevel import cast_base_ptr_to_instance
        class S:
            x = 5      # entry in the vtable
        class T(S):
            x = 6
        def f():
            s = T()
            ls = cast_instance_to_base_ptr(s)
            as_num = rffi.cast(lltype.Signed, ls)
            # --- around this point, only 'as_num' is passed
            t = rffi.cast(rclass.OBJECTPTR, as_num)
            u = cast_base_ptr_to_instance(S, t)
            return u.x
        res = interpret(f, [])
        assert res == 6

    def test_force_to_int(self):
        S = lltype.Struct('S')
        p = lltype.malloc(S, flavor='raw')
        a = llmemory.cast_ptr_to_adr(p)
        i = llmemory.cast_adr_to_int(a, "forced")
        assert is_valid_int(i)
        assert i == llmemory.cast_adr_to_int(a, "forced")
        lltype.free(p, flavor='raw')

    def test_freelist(self):
        S = lltype.Struct('S', ('x', lltype.Signed), ('y', lltype.Signed))
        SP = lltype.Ptr(S)
        chunk = lltype.malloc(rffi.CArrayPtr(S).TO, 10, flavor='raw')
        assert lltype.typeOf(chunk) == rffi.CArrayPtr(S)
        free_list = lltype.nullptr(rffi.VOIDP.TO)
        # build list
        current = chunk
        for i in range(10):
            rffi.cast(rffi.VOIDPP, current)[0] = free_list
            free_list = rffi.cast(rffi.VOIDP, current)
            current = rffi.ptradd(current, 1)
        # get one
        p = free_list
        free_list = rffi.cast(rffi.VOIDPP, p)[0]
        rffi.cast(SP, p).x = 0
        # get two
        p = free_list
        free_list = rffi.cast(rffi.VOIDPP, p)[0]
        rffi.cast(SP, p).x = 0
        # get three
        p = free_list
        free_list = rffi.cast(rffi.VOIDPP, p)[0]
        rffi.cast(SP, p).x = 0
        lltype.free(chunk, flavor='raw')

    def test_opaque_tagged_pointers(self):
        from rpython.rtyper.annlowlevel import cast_base_ptr_to_instance
        from rpython.rtyper.annlowlevel import cast_instance_to_base_ptr
        from rpython.rtyper import rclass

        class Opaque(object):
            llopaque = True

            def hide(self):
                ptr = cast_instance_to_base_ptr(self)
                return lltype.cast_opaque_ptr(llmemory.GCREF, ptr)

            @staticmethod
            def show(gcref):
                ptr = lltype.cast_opaque_ptr(lltype.Ptr(rclass.OBJECT), gcref)
                return cast_base_ptr_to_instance(Opaque, ptr)

        opaque = Opaque()
        round = ctypes2lltype(llmemory.GCREF, lltype2ctypes(opaque.hide()))
        assert Opaque.show(round) is opaque

    def test_array_of_structs(self):
        A = lltype.GcArray(lltype.Struct('x', ('v', lltype.Signed)))
        a = lltype.malloc(A, 5)
        a2 = ctypes2lltype(lltype.Ptr(A), lltype2ctypes(a))
        assert a2._obj.getitem(0)._obj._parentstructure() is a2._obj

    def test_array_of_function_pointers(self):
        c_source = py.code.Source(r"""
        #include "src/precommondefs.h"
        #include <stdio.h>

        typedef int(*funcptr_t)(void);
        static int forty_two(void) { return 42; }
        static int forty_three(void) { return 43; }
        static funcptr_t testarray[2];
        RPY_EXPORTED void runtest(void cb(funcptr_t *)) { 
            testarray[0] = &forty_two;
            testarray[1] = &forty_three;
            fprintf(stderr, "&forty_two = %p\n", testarray[0]);
            fprintf(stderr, "&forty_three = %p\n", testarray[1]);
            cb(testarray);
            testarray[0] = 0;
            testarray[1] = 0;
        }
        """)
        eci = ExternalCompilationInfo(include_dirs=[cdir],
                                      separate_module_sources=[c_source])

        PtrF = lltype.Ptr(lltype.FuncType([], rffi.INT))
        ArrayPtrF = rffi.CArrayPtr(PtrF)
        CALLBACK = rffi.CCallback([ArrayPtrF], lltype.Void)

        runtest = rffi.llexternal('runtest', [CALLBACK], lltype.Void,
                                  compilation_info=eci)
        seen = []

        def callback(testarray):
            seen.append(testarray[0])   # read a PtrF out of testarray
            seen.append(testarray[1])

        runtest(callback)
        assert seen[0]() == 42
        assert seen[1]() == 43

    def test_keep_value_across_lltype_callable(self):
        PtrF = lltype.Ptr(lltype.FuncType([], lltype.Void))
        f = rffi.cast(PtrF, 42)
        assert lltype.typeOf(f) == PtrF
        assert rffi.cast(lltype.Signed, f) == 42

    def test_keep_value_across_rffi_llexternal(self):
        c_source = py.code.Source(r"""
            void ff1(void) { }
            void *get_ff1(void) { return &ff1; }
        """)
        eci = ExternalCompilationInfo(
            separate_module_sources=[c_source],
            post_include_bits = [
                "RPY_EXTERN void ff1(void); RPY_EXTERN void *get_ff1(void);"])
        PtrFF1 = lltype.Ptr(lltype.FuncType([], lltype.Void))
        f1 = rffi.llexternal('ff1', [], lltype.Void, compilation_info=eci,
                             _nowrapper=True)
        assert lltype.typeOf(f1) == PtrFF1
        getff1 = rffi.llexternal('get_ff1', [], PtrFF1, compilation_info=eci,
                                 _nowrapper=True)
        f2 = getff1()
        assert rffi.cast(lltype.Signed, f2) == rffi.cast(lltype.Signed, f1)
        #assert f2 == f1  -- fails, would be nice but oh well


class TestPlatform(object):
    def test_lib_on_libpaths(self):
        from rpython.translator.platform import platform

        tmpdir = udir.join('lib_on_libppaths')
        tmpdir.ensure(dir=1)
        c_file = tmpdir.join('c_file.c')
        c_file.write('''
        #include "src/precommondefs.h"
        RPY_EXPORTED int f(int a, int b) { return (a + b); }
        ''')
        eci = ExternalCompilationInfo(include_dirs=[cdir])
        so = platform.compile([c_file], eci, standalone=False)
        eci = ExternalCompilationInfo(
            libraries = ['c_file'],
            library_dirs = [str(so.dirpath())]
        )
        f = rffi.llexternal('f', [rffi.INT, rffi.INT], rffi.INT,
                            compilation_info=eci)
        assert f(3, 4) == 7

    def test_prefix(self):

        if not sys.platform.startswith('linux'):
            py.test.skip("Not supported")

        from rpython.translator.platform import platform

        tmpdir = udir.join('lib_on_libppaths_prefix')
        tmpdir.ensure(dir=1)
        c_file = tmpdir.join('c_file.c')
        c_file.write('''
        #include "src/precommondefs.h"
        RPY_EXPORTED int f(int a, int b) { return (a + b); }
        ''')
        eci = ExternalCompilationInfo(include_dirs=[cdir])
        so = platform.compile([c_file], eci, standalone=False)
        sopath = py.path.local(so)
        sopath.move(sopath.dirpath().join('libc_file.so'))
        eci = ExternalCompilationInfo(
            libraries = ['c_file'],
            library_dirs = [str(so.dirpath())]
        )
        f = rffi.llexternal('f', [rffi.INT, rffi.INT], rffi.INT,
                            compilation_info=eci)
        assert f(3, 4) == 7

    def test_llgcopaque_eq(self):
        assert _llgcopaque(1) != None
        assert _llgcopaque(0) == None

    def test_array_of_struct(self):
        A2 = lltype.Array(('a', lltype.Signed), ('b', lltype.Signed))
        a = lltype.malloc(A2, 10, flavor='raw')
        a[3].b = 42
        ac = lltype2ctypes(a[3])
        assert ac.contents.b == 42
        ac.contents.a = 17
        assert a[3].a == 17
        #lltype.free(a, flavor='raw')
        py.test.skip("free() not working correctly here...")

    def test_fixedsizedarray_to_ctypes(self):
        T = lltype.Ptr(rffi.CFixedArray(rffi.INT, 1))
        inst = lltype.malloc(T.TO, flavor='raw')
        inst[0] = rffi.cast(rffi.INT, 42)
        assert inst[0] == 42
        cinst = lltype2ctypes(inst)
        assert rffi.cast(lltype.Signed, inst[0]) == 42
        assert cinst.contents.item0 == 42
        lltype.free(inst, flavor='raw')

    def test_fixedsizedarray_to_ctypes(self):
        T = lltype.Ptr(rffi.CFixedArray(rffi.CHAR, 123))
        inst = lltype.malloc(T.TO, flavor='raw', zero=True)
        cinst = lltype2ctypes(inst)
        assert cinst.contents.item0 == 0
        lltype.free(inst, flavor='raw')
