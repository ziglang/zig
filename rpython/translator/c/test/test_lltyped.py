import py, random
from rpython.rtyper.lltypesystem.lltype import *
from rpython.rtyper.lltypesystem import rffi
from rpython.translator.c.test.test_genc import compile
from rpython.tool.sourcetools import func_with_new_name


class TestLowLevelType(object):
    def getcompiled(self, func, argtypes):
        return compile(func, argtypes, backendopt=False)

    def test_simple(self):
        S = GcStruct("s", ('v', Signed))
        def llf():
            s = malloc(S)
            return s.v
        fn = self.getcompiled(llf, [])
        assert fn() == 0

    def test_simple2(self):
        S = Struct("s", ('v', Signed))
        S2 = GcStruct("s2", ('a',S), ('b',S))
        def llf():
            s = malloc(S2)
            s.a.v = 6
            s.b.v = 12
            return s.a.v + s.b.v
        fn = self.getcompiled(llf, [])
        assert fn() == 18

    def test_fixedsizearray(self):
        S = Struct("s", ('v', Signed))
        A7 = FixedSizeArray(Signed, 7)
        A3 = FixedSizeArray(S, 3)
        A42 = FixedSizeArray(A7, 6)
        BIG = GcStruct("big", ("a7", A7), ("a3", A3), ("a42", A42))
        def llf():
            big = malloc(BIG)
            a7 = big.a7
            a3 = big.a3
            a42 = big.a42
            a7[0] = -1
            a7.item6 = -2
            a3[0].v = -3
            a3[2].v = -4
            a42[0][0] = -5
            a42[5][6] = -6
            assert a7[0] == -1
            assert a7[6] == -2
            assert a3[0].v == -3
            assert a3.item2.v == -4
            assert a42[0][0] == -5
            assert a42[5][6] == -6
            return len(a42)*100 + len(a42[4])
        fn = self.getcompiled(llf, [])
        res = fn()
        assert fn() == 607

    def test_recursivearray(self):
        A = ForwardReference()
        A.become(FixedSizeArray(Struct("S", ('a', Ptr(A))), 5))
        TREE = Struct("TREE", ("root", A), ("other", A))
        tree = malloc(TREE, immortal=True)
        def llf():
            tree.root[0].a = tree.root
            tree.root[1].a = tree.other
            assert tree.root[0].a[0].a[0].a[0].a[0].a[1].a == tree.other
        fn = self.getcompiled(llf, [])
        fn()

    def test_prebuilt_array(self):
        A = FixedSizeArray(Signed, 5)
        a = malloc(A, immortal=True)
        a[0] = 8
        a[1] = 5
        a[2] = 12
        a[3] = 12
        a[4] = 15
        def llf():
            s = ''
            for i in range(5):
                s += chr(64+a[i])
            assert s == "HELLO"
        fn = self.getcompiled(llf, [])
        fn()

    def test_call_with_fixedsizearray(self):
        A = FixedSizeArray(Struct('s1', ('x', Signed)), 5)
        S = GcStruct('s', ('a', Ptr(A)))
        a = malloc(A, immortal=True)
        a[1].x = 123
        def g(x):
            return x[1].x
        def llf():
            s = malloc(S)
            s.a = a
            return g(s.a)
        fn = self.getcompiled(llf, [])
        res = fn()
        assert res == 123

    def test_more_prebuilt_arrays(self):
        A = FixedSizeArray(Struct('s1', ('x', Signed)), 5)
        S = Struct('s', ('a1', Ptr(A)), ('a2', A))
        s = malloc(S, zero=True, immortal=True)
        s.a1 = malloc(A, immortal=True)
        s.a1[2].x = 50
        s.a2[2].x = 60
        def llf(n):
            if n == 1:
                a = s.a1
            else:
                a = s.a2
            return a[2].x
        fn = self.getcompiled(llf, [int])
        res = fn(1)
        assert res == 50
        res = fn(2)
        assert res == 60

    def test_fnptr_with_fixedsizearray(self):
        A = ForwardReference()
        F = FuncType([Ptr(A)], Signed)
        A.become(FixedSizeArray(Struct('s1', ('f', Ptr(F)), ('n', Signed)), 5))
        a = malloc(A, immortal=True)
        a[3].n = 42
        def llf(n):
            if a[n].f:
                return a[n].f(a)
            else:
                return -1
        fn = self.getcompiled(llf, [int])
        res = fn(4)
        assert res == -1

    def test_direct_arrayitems(self):
        for a in [malloc(GcArray(Signed), 5),
                  malloc(FixedSizeArray(Signed, 5), immortal=True),
                  malloc(Array(Signed, hints={'nolength': True}), 5,
                         immortal=True),
                  ]:
            a[0] = 0
            a[1] = 10
            a[2] = 20
            a[3] = 30
            a[4] = 40
            b0 = direct_arrayitems(a)
            b1 = direct_ptradd(b0, 1)
            b2 = direct_ptradd(b1, 1)
            def llf(n):
                b0 = direct_arrayitems(a)
                b3 = direct_ptradd(direct_ptradd(b0, 5), -2)
                saved = a[n]
                a[n] = 1000
                try:
                    return b0[0] + b3[-2] + b2[1] + b1[3]
                finally:
                    a[n] = saved
            fn = self.getcompiled(llf, [int])
            res = fn(0)
            assert res == 1000 + 10 + 30 + 40
            res = fn(1)
            assert res == 0 + 1000 + 30 + 40
            res = fn(2)
            assert res == 0 + 10 + 30 + 40
            res = fn(3)
            assert res == 0 + 10 + 1000 + 40
            res = fn(4)
            assert res == 0 + 10 + 30 + 1000

    def test_structarray_add(self):
        from rpython.rtyper.lltypesystem import llmemory
        S = Struct("S", ("x", Signed))
        PS = Ptr(S)
        size = llmemory.sizeof(S)
        A = GcArray(S)
        itemoffset = llmemory.itemoffsetof(A, 0)
        def llf(n):
            a = malloc(A, 5)
            a[0].x = 1
            a[1].x = 2
            a[2].x = 3
            a[3].x = 42
            a[4].x = 4
            adr_s = llmemory.cast_ptr_to_adr(a)
            adr_s += itemoffset + size * n
            s = llmemory.cast_adr_to_ptr(adr_s, PS)
            return s.x
        fn = self.getcompiled(llf, [int])
        res = fn(3)
        assert res == 42

    def test_direct_fieldptr(self):
        S = GcStruct('S', ('x', Signed), ('y', Signed))
        def llf(n):
            s = malloc(S)
            a = direct_fieldptr(s, 'y')
            a[0] = n
            return s.y

        fn = self.getcompiled(llf, [int])
        res = fn(34)
        assert res == 34

    def test_prebuilt_subarrays(self):
        a1 = malloc(GcArray(Signed), 5, zero=True)
        a2 = malloc(FixedSizeArray(Signed, 5), immortal=True)
        s  = malloc(GcStruct('S', ('x', Signed), ('y', Signed)), zero=True)
        a1[3] = 7000
        a2[1] =  600
        s.x   =   50
        s.y   =    4
        p1 = direct_ptradd(direct_arrayitems(a1), 3)
        p2 = direct_ptradd(direct_arrayitems(a2), 1)
        p3 = direct_fieldptr(s, 'x')
        p4 = direct_fieldptr(s, 'y')
        def llf():
            a1[3] += 1000
            a2[1] +=  100
            s.x   +=   10
            s.y   +=    1
            return p1[0] + p2[0] + p3[0] + p4[0]

        fn = self.getcompiled(llf, [])
        res = fn()
        assert res == 8765

    def test_union(self):
        U = Struct('U', ('s', Signed), ('c', Char),
                   hints={'union': True})
        u = malloc(U, immortal=True)
        def llf(c):
            u.s = 0x10203040
            u.c = chr(c)
            return u.s

        fn = self.getcompiled(llf, [int])
        res = fn(0x33)
        assert res in [0x10203033, 0x33203040,
                       # big endian 64 bit machine
                       0x3300000010203040]

    def test_sizeof_void_array(self):
        from rpython.rtyper.lltypesystem import llmemory
        A = Array(Void)
        size1 = llmemory.sizeof(A, 1)
        size2 = llmemory.sizeof(A, 14)
        def f(x):
            if x:
                return size1
            else:
                return size2
        fn = self.getcompiled(f, [int])
        res1 = fn(1)
        res2 = fn(0)
        assert res1 == res2

    def test_cast_primitive(self):
        def f(x):
            x = cast_primitive(UnsignedLongLong, x)
            x <<= 60
            x /= 3
            x <<= 1
            x = cast_primitive(SignedLongLong, x)
            x >>= 32
            return cast_primitive(Signed, x)
        fn = self.getcompiled(f, [int])
        res = fn(14)
        assert res == -1789569707

    def test_prebuilt_integers(self):
        from rpython.rlib.unroll import unrolling_iterable
        from rpython.rtyper.lltypesystem import rffi
        class Prebuilt:
            pass
        p = Prebuilt()
        NUMBER_TYPES = rffi.NUMBER_TYPES
        names = unrolling_iterable([TYPE.__name__ for TYPE in NUMBER_TYPES])
        for name, TYPE in zip(names, NUMBER_TYPES):
            value = cast_primitive(TYPE, 1)
            setattr(p, name, value)

        def f(x):
            total = x
            for name in names:
                total += rffi.cast(Signed, getattr(p, name))
            return total

        fn = self.getcompiled(f, [int])
        res = fn(100)
        assert res == 100 + len(list(names))

    def test_force_cast(self):
        from rpython.rtyper.annlowlevel import llstr
        from rpython.rtyper.lltypesystem.rstr import STR
        from rpython.rtyper.lltypesystem import rffi, llmemory, lltype
        P = lltype.Ptr(lltype.FixedSizeArray(lltype.Char, 1))

        def f():
            a = llstr("xyz")
            b = (llmemory.cast_ptr_to_adr(a) + llmemory.offsetof(STR, 'chars')
                 + llmemory.itemoffsetof(STR.chars, 0))
            buf = rffi.cast(rffi.VOIDP, b)
            return buf[2]

        fn = self.getcompiled(f, [])
        res = fn()
        assert res == 'z'

    def test_array_nolength(self):
        A = Array(Signed, hints={'nolength': True})
        a1 = malloc(A, 3, immortal=True)
        a1[0] = 30
        a1[1] = 300
        a1[2] = 3000
        a1dummy = malloc(A, 2, immortal=True)

        def f(n):
            if n & 1:
                src = a1dummy
            else:
                src = a1
            a2 = malloc(A, n, flavor='raw')
            for i in range(n):
                a2[i] = src[i % 3] + i
            res = a2[n // 2]
            free(a2, flavor='raw')
            return res

        fn = self.getcompiled(f, [int])
        res = fn(100)
        assert res == 3050

    def test_gcarray_nolength(self):
        py.test.skip("GcArrays should never be 'nolength'")
        A = GcArray(Signed, hints={'nolength': True})
        a1 = malloc(A, 3, immortal=True)
        a1[0] = 30
        a1[1] = 300
        a1[2] = 3000
        a1dummy = malloc(A, 2, immortal=True)

        def f(n):
            if n & 1:
                src = a1dummy
            else:
                src = a1
            a2 = malloc(A, n)
            for i in range(n):
                a2[i] = src[i % 3] + i
            res = a2[n // 2]
            return res

        fn = self.getcompiled(f, [int])
        res = fn(100)
        assert res == 3050

    def test_structarray_nolength(self):
        S = Struct('S', ('x', Signed))
        A = Array(S, hints={'nolength': True})
        a1 = malloc(A, 3, immortal=True)
        a1[0].x = 30
        a1[1].x = 300
        a1[2].x = 3000
        a1dummy = malloc(A, 2, immortal=True)

        def f(n):
            if n & 1:
                src = a1dummy
            else:
                src = a1
            a2 = malloc(A, n, flavor='raw')
            for i in range(n):
                a2[i].x = src[i % 3].x + i
            res = a2[n // 2].x
            free(a2, flavor='raw')
            return res

        fn = self.getcompiled(f, [int])
        res = fn(100)
        assert res == 3050

    def test_zero_raw_malloc(self):
        S = Struct('S', ('x', Signed), ('y', Signed))
        def f(n):
            for i in range(n):
                p = malloc(S, flavor='raw', zero=True)
                if p.x != 0 or p.y != 0:
                    free(p, flavor='raw')
                    return -1
                p.x = i
                p.y = i
                free(p, flavor='raw')
            return 42

        fn = self.getcompiled(f, [int])
        res = fn(100)
        assert res == 42

    def test_zero_raw_malloc_varsize(self):
        # we don't support at the moment raw+zero mallocs with a length
        # field to initialize
        S = Struct('S', ('x', Signed), ('y', Array(Signed, hints={'nolength': True})))
        def f(n):
            for length in range(n-1, -1, -1):
                p = malloc(S, length, flavor='raw', zero=True)
                try:
                    if p.x != 0:
                        return -1
                    p.x = n
                    for j in range(length):
                        if p.y[j] != 0:
                            return -3
                        p.y[j] = n^j
                finally:
                    free(p, flavor='raw')
            return 42

        fn = self.getcompiled(f, [int])
        res = fn(100)
        assert res == 42

    def test_arithmetic_cornercases(self):
        import operator, sys
        from rpython.rlib.unroll import unrolling_iterable
        from rpython.rlib.rarithmetic import r_longlong, r_ulonglong

        class Undefined:
            def __eq__(self, other):
                return True
        undefined = Undefined()

        def getmin(cls):
            if cls is int:
                return -sys.maxint-1
            elif cls.SIGNED:
                return cls(-(cls.MASK>>1)-1)
            else:
                return cls(0)
        getmin._annspecialcase_ = 'specialize:memo'

        def getmax(cls):
            if cls is int:
                return sys.maxint
            elif cls.SIGNED:
                return cls(cls.MASK>>1)
            else:
                return cls(cls.MASK)
        getmax._annspecialcase_ = 'specialize:memo'
        maxlonglong = long(getmax(r_longlong))

        classes = unrolling_iterable([int, r_uint, r_longlong, r_ulonglong])
        operators = unrolling_iterable([operator.add,
                                        operator.sub,
                                        operator.mul,
                                        operator.floordiv,
                                        operator.mod,
                                        operator.lshift,
                                        operator.rshift])
        def f(n):
            result = ()
            for cls in classes:
                nn = cls(n)
                for OP in operators:
                    x = getmin(cls)
                    res1 = OP(x, nn)
                    result = result + (res1,)
                    x = getmax(cls)
                    res1 = OP(x, nn)
                    result = result + (res1,)
            return str(result)

        fn = self.getcompiled(f, [int])
        res = fn(1)
        print res
        assert eval(res) == (
            # int
            -sys.maxint, undefined,               # add
            undefined, sys.maxint-1,              # sub
            -sys.maxint-1, sys.maxint,            # mul
            -sys.maxint-1, sys.maxint,            # floordiv
            0, 0,                                 # mod
            0, -2,                                # lshift
            (-sys.maxint-1)//2, sys.maxint//2,    # rshift
            # r_uint
            1, 0,                                 # add
            sys.maxint*2+1, sys.maxint*2,         # sub
            0, sys.maxint*2+1,                    # mul
            0, sys.maxint*2+1,                    # floordiv
            0, 0,                                 # mod
            0, sys.maxint*2,                      # lshift
            0, sys.maxint,                        # rshift
            # r_longlong
            -maxlonglong, undefined,              # add
            undefined, maxlonglong-1,             # sub
            -maxlonglong-1, maxlonglong,          # mul
            -maxlonglong-1, maxlonglong,          # floordiv
            0, 0,                                 # mod
            0, -2,                                # lshift
            (-maxlonglong-1)//2, maxlonglong//2,  # rshift
            # r_ulonglong
            1, 0,                                 # add
            maxlonglong*2+1, maxlonglong*2,       # sub
            0, maxlonglong*2+1,                   # mul
            0, maxlonglong*2+1,                   # floordiv
            0, 0,                                 # mod
            0, maxlonglong*2,                     # lshift
            0, maxlonglong,                       # rshift
            )

        res = fn(5)
        print res
        assert eval(res) == (
            # int
            -sys.maxint+4, undefined,             # add
            undefined, sys.maxint-5,              # sub
            undefined, undefined,                 # mul
            (-sys.maxint-1)//5, sys.maxint//5,    # floordiv
            (-sys.maxint-1)%5, sys.maxint%5,      # mod
            0, -32,                               # lshift
            (-sys.maxint-1)//32, sys.maxint//32,  # rshift
            # r_uint
            5, 4,                                 # add
            sys.maxint*2-3, sys.maxint*2-4,       # sub
            0, sys.maxint*2-3,                    # mul
            0, (sys.maxint*2+1)//5,               # floordiv
            0, (sys.maxint*2+1)%5,                # mod
            0, sys.maxint*2-30,                   # lshift
            0, sys.maxint>>4,                     # rshift
            # r_longlong
            -maxlonglong+4, undefined,            # add
            undefined, maxlonglong-5,             # sub
            undefined, undefined,                 # mul
            (-maxlonglong-1)//5, maxlonglong//5,  # floordiv
            (-maxlonglong-1)%5, maxlonglong%5,    # mod
            0, -32,                               # lshift
            (-maxlonglong-1)//32, maxlonglong//32,# rshift
            # r_ulonglong
            5, 4,                                 # add
            maxlonglong*2-3, maxlonglong*2-4,     # sub
            0, maxlonglong*2-3,                   # mul
            0, (maxlonglong*2+1)//5,              # floordiv
            0, (maxlonglong*2+1)%5,               # mod
            0, maxlonglong*2-30,                  # lshift
            0, maxlonglong>>4,                    # rshift
            )

    def test_direct_ptradd_barebone(self):
        from rpython.rtyper.lltypesystem import rffi
        ARRAY_OF_CHAR = Array(Char, hints={'nolength': True})

        def llf():
            data = "hello, world!"
            a = malloc(ARRAY_OF_CHAR, len(data), flavor='raw')
            for i in xrange(len(data)):
                a[i] = data[i]
            a2 = rffi.ptradd(a, 2)
            assert typeOf(a2) == typeOf(a) == Ptr(ARRAY_OF_CHAR)
            for i in xrange(len(data) - 2):
                assert a2[i] == a[i + 2]
            free(a, flavor='raw')

        fn = self.getcompiled(llf, [])
        fn()

    def test_r_singlefloat(self):

        z = r_singlefloat(0.4)

        def g(n):
            if n > 0:
                return r_singlefloat(n * 0.1)
            else:
                return z

        def llf(n):
            return float(g(n))

        fn = self.getcompiled(llf, [int])
        res = fn(21)
        assert res != 2.1     # precision lost
        assert abs(res - 2.1) < 1E-6
        res = fn(-5)
        assert res != 0.4     # precision lost
        assert abs(res - 0.4) < 1E-6


    def test_array_of_array(self):
        C = FixedSizeArray(Signed, 7)
        B = Array(C)
        A = FixedSizeArray(C, 6)
        b = malloc(B, 5, immortal=True)
        b[3][4] = 999
        a = malloc(A, immortal=True)
        a[2][5] = 888000
        def llf():
            return b[3][4] + a[2][5]
        fn = self.getcompiled(llf, [])
        assert fn() == 888999

    def test_prebuilt_nolength_array(self):
        A = Array(Signed, hints={'nolength': True})
        a = malloc(A, 5, immortal=True)
        a[0] = 8
        a[1] = 5
        a[2] = 12
        a[3] = 12
        a[4] = 15
        def llf():
            s = ''
            for i in range(5):
                s += chr(64+a[i])
            assert s == "HELLO"
        fn = self.getcompiled(llf, [])
        fn()

    def test_prebuilt_nolength_char_array(self):
        for lastchar in ('\x00', 'X'):
            A = Array(Char, hints={'nolength': True})
            a = malloc(A, 6, immortal=True)
            a[0] = '8'
            a[1] = '5'
            a[2] = '?'
            a[3] = '!'
            a[4] = lastchar
            a[5] = '\x00'
            def llf():
                s = ''
                for i in range(5):
                    s += a[i]
                assert s == "85?!" + lastchar
            fn = self.getcompiled(llf, [])
            fn()

    def test_prebuilt_raw_arrays(self):
        from rpython.rtyper.lltypesystem import rffi, ll2ctypes
        #
        def make_test_function(cast, haslength, length):
            a = malloc(A, length, flavor='raw', immortal=True)
            # two cases: a zero-terminated array if length == 6 or 1030,
            # a non-zero-terminated array if length == 557 or 1031
            for i in range(length):
                a[i] = cast(256 - 5 + i)
            def llf():
                for i in range(length):
                    if a[i] != cast(256 - 5 + i):
                        return False
                if haslength and len(a) != length:
                    return False
                return True
            return func_with_new_name(llf, repr((A, haslength, length)))
        #
        testfns = []
        records = []
        for OF, cast in [(Void, lambda n: None),
                         (Char, lambda n: chr(n & 0xFF)),
                         (Signed, lambda n: n)]:
            for A, haslength in [(rffi.CArray(OF), False),
                                 (Array(OF), True)]:
                for length in [0, 6, 557, 1030, 1031]:
                    testfns.append(make_test_function(cast, haslength, length))
                    records.append((A, haslength, length))
        def llf():
            i = 0
            for fn in testfns:
                if not fn():
                    return i    # returns the index of the failing function
                i += 1
            return -42
        fn = self.getcompiled(llf, [])
        res = fn()
        assert res == -42, "failing function: %r" % (records[res],)

    def test_prebuilt_ll2ctypes_array(self):
        from rpython.rtyper.lltypesystem import rffi, ll2ctypes
        A = rffi.CArray(Char)
        a = malloc(A, 6, flavor='raw', immortal=True)
        a[0] = 'a'
        a[1] = 'b'
        a[2] = 'c'
        a[3] = 'd'
        a[4] = '\x00'
        a[5] = '\x00'
        # side effects when converting to c structure
        ll2ctypes.lltype2ctypes(a)
        def llf():
            s = ''
            for i in range(4):
                s += a[i]
            return 'abcd' == s

        fn = self.getcompiled(llf, [])
        assert fn()

    def test_ll2ctypes_array_from_c(self):
        from rpython.rtyper.lltypesystem import rffi, ll2ctypes
        A = rffi.CArray(Char)
        a = malloc(A, 6, flavor='raw', immortal=True)
        a[0] = 'a'
        a[1] = 'b'
        a[2] = 'c'
        a[3] = 'd'
        a[4] = '\x00'
        a[5] = '\x00'
        # side effects when converting to c structure
        c = ll2ctypes.lltype2ctypes(a)
        a = ll2ctypes.ctypes2lltype(Ptr(A), c)
        def llf():
            s = ''
            for i in range(4):
                s += a[i]
            return s == 'abcd'
        fn = self.getcompiled(llf, [])
        assert fn()

    def test_cast_to_void_array(self):
        from rpython.rtyper.lltypesystem import rffi
        def llf():
            TYPE = Ptr(rffi.CArray(Void))
            y = rffi.cast(TYPE, 0)
        fn = self.getcompiled(llf, [])
        fn()

    def test_llgroup(self):
        from rpython.rtyper.lltypesystem.test import test_llgroup
        f = test_llgroup.build_test()
        fn = self.getcompiled(f, [])
        res = fn()
        assert res == 42

    def test_llgroup_size_limit(self):
        yield self._test_size_limit, True
        yield self._test_size_limit, False

    def _test_size_limit(self, toobig):
        import sys
        from rpython.rtyper.lltypesystem import llgroup
        from rpython.rtyper.lltypesystem.lloperation import llop
        from rpython.translator.platform import CompilationError
        if toobig and sys.maxint > 2147483647:
            py.test.skip("not easy to test groups too big on 64-bit platforms")
        grp = llgroup.group("big")
        S1 = Struct('S1', ('x', Signed), ('y', Signed),
                          ('z', Signed), ('u', Signed),
                          ('x2', Signed), ('y2', Signed),
                          ('z2', Signed), ('u2', Signed),
                          ('x3', Signed), ('y3', Signed),
                          ('z3', Signed), ('u3', Signed),
                          ('x4', Signed), ('y4', Signed),
                          ('z4', Signed), ('u4', Signed))
        goffsets = []
        for i in range(4096 + toobig):
            ofs = grp.add_member(malloc(S1, immortal=True))
            goffsets.append(llgroup.CombinedSymbolic(ofs, 0))
        grpptr = grp._as_ptr()
        def f(n):
            o = llop.extract_ushort(llgroup.HALFWORD, goffsets[n])
            p = llop.get_group_member(Ptr(S1), grpptr, o)
            p.x = 5
            for i in range(len(goffsets)):
                if i != n:
                    o = llop.extract_ushort(llgroup.HALFWORD, goffsets[i])
                    q = llop.get_group_member(Ptr(S1), grpptr, o)
                    q.x = 666
            return p.x
        if toobig:
            py.test.raises(CompilationError, self.getcompiled, f, [int])
        else:
            fn = self.getcompiled(f, [int])
            res = fn(len(goffsets)-1)
            assert res == 5

    def test_round_up_for_allocation(self):
        import platform
        from rpython.rtyper.lltypesystem import llmemory, llarena
        S = Struct('S', ('x', Char), ('y', Char))
        M = Struct('M', ('x', Char), ('y', Signed))
        is_arm = platform.machine().startswith('arm')
        #
        def g():
            ssize = llarena.round_up_for_allocation(llmemory.sizeof(S))
            msize = llarena.round_up_for_allocation(llmemory.sizeof(M))
            smsize = llarena.round_up_for_allocation(llmemory.sizeof(S),
                                                     llmemory.sizeof(M))
            mssize = llarena.round_up_for_allocation(llmemory.sizeof(M),
                                                     llmemory.sizeof(S))
            return ssize, msize, smsize, mssize
        #
        glob_sizes = g()
        #
        def check((ssize, msize, smsize, mssize)):
            if is_arm:
                # ARM has stronger rules about aligned memory access
                # so according to the rules for round_up_for_allocation
                # we get two words here
                assert ssize == llmemory.sizeof(Signed) * 2
            else:
                assert ssize == llmemory.sizeof(Signed)
            assert msize == llmemory.sizeof(Signed) * 2
            assert smsize == msize
            assert mssize == msize
        #
        def f():
            check(glob_sizes)
            check(g())
            return 42
        #
        fn = self.getcompiled(f, [])
        res = fn()
        assert res == 42

    def test_llarena(self):
        from rpython.rtyper.lltypesystem import llmemory, llarena
        #
        def f():
            a = llarena.arena_malloc(800, False)
            llarena.arena_reset(a, 800, 2)
            llarena.arena_free(a)
        #
        fn = self.getcompiled(f, [])
        fn()

    def test_padding_in_prebuilt_struct(self):
        from rpython.rtyper.lltypesystem import rffi
        from rpython.rtyper.tool import rffi_platform
        eci = rffi_platform.eci_from_header("""
            typedef struct {
                char c1;        /* followed by one byte of padding */
                short s1;
                char c2;        /* followed by 3 bytes of padding */
                int i2;
                char c3;        /* followed by 3 or 7 bytes of padding */
                Signed l3;
                char c4;        /* followed by 3 or 7 bytes of padding */
                long l4;
                char c5;
            } foobar_t;
        """)
        class CConfig:
            _compilation_info_ = eci
            STRUCT = rffi_platform.Struct("foobar_t",
                                          [("c1", Signed),
                                           ("s1", Signed),
                                           ("l3", Signed),
                                           ("l4", Signed)])
        S = rffi_platform.configure(CConfig)['STRUCT']
        assert 'get_padding_drop' in S._hints
        assert 'eci' in S._hints
        s1 = malloc(S, immortal=True)
        s1.c_c1 = rffi.cast(S.c_c1, -12)
        s1.c_s1 = rffi.cast(S.c_s1, -7843)
        s1.c_l3 = -98765432
        s1.c_l4 = rffi.cast(S.c_l4, -91234567)
        s2 = malloc(S, immortal=True)
        s2.c_c1 = rffi.cast(S.c_c1, -123)
        s2.c_s1 = rffi.cast(S.c_s1, -789)
        s2.c_l3 = -9999999
        s2.c_l4 = rffi.cast(S.c_l4, -9111111)
        #
        def f(n):
            if n > 5:
                s = s1
            else:
                s = s2
            return s.c_l3
        #
        fn = self.getcompiled(f, [int])
        res = fn(10)
        assert res == -98765432
        res = fn(1)
        assert res == -9999999

    def test_render_immortal(self):
        A = FixedSizeArray(Signed, 1)
        a1 = malloc(A, flavor='raw')
        render_immortal(a1)
        a1[0] = 42
        def llf():
            a2 = malloc(A, flavor='raw')
            render_immortal(a2)
            a2[0] = 3
            return a1[0] + a2[0]
        fn = self.getcompiled(llf, [])
        assert fn() == 45

    def test_rstring_to_float(self):
        from rpython.rlib.rfloat import rstring_to_float
        def llf(i):
            s = ['42.3', '123.4'][i]
            return rstring_to_float(s)
        fn = self.getcompiled(llf, [int])
        assert fn(0) == 42.3

    def test_raw_array_field(self):
        from rpython.rtyper.lltypesystem import rffi
        S = Struct('S', ('array', rffi.CArray(Signed)))
        def llf(i):
            s = malloc(S, i, flavor='raw')
            s.array[i-2] = 42
            x = s.array[i-2]
            free(s, flavor='raw')
            return x
        fn = self.getcompiled(llf, [int])
        assert fn(5) == 42

    def test_raw_array_field_prebuilt(self):
        from rpython.rtyper.lltypesystem import rffi
        S = Struct('S', ('array', rffi.CArray(Signed)))
        s0 = malloc(S, 0, flavor='raw', immortal=True)
        s1 = malloc(S, 1, flavor='raw', immortal=True)
        s1.array[0] = 521
        s2 = malloc(S, 2, flavor='raw', immortal=True)
        s2.array[0] = 12
        s2.array[1] = 34
        def llf(i):
            if   i == 0: s = s0
            elif i == 1: s = s1
            else:        s = s2
            x = 10
            if i > 0:
                x += s.array[i-1]
            return x
        fn = self.getcompiled(llf, [int])
        assert fn(0) == 10
        assert fn(1) == 10 + 521
        assert fn(2) == 10 + 34

    def test_const_char_star(self):
        from rpython.translator.tool.cbuild import ExternalCompilationInfo

        eci = ExternalCompilationInfo(includes=["stdlib.h"])
        atoi = rffi.llexternal('atoi', [rffi.CONST_CCHARP], rffi.INT,
                               compilation_info=eci)

        def f(n):
            s = malloc(rffi.CCHARP.TO, 2, flavor='raw')
            s[0] = '9'
            s[1] = '\0'
            res = atoi(rffi.cast(rffi.CONST_CCHARP, s))
            free(s, flavor='raw')
            return res

        fn = self.getcompiled(f, [int])
        assert fn(0) == 9

    def test_call_null_funcptr(self):
        fnptr = nullptr(FuncType([], Void))
        def f(n):
            if n > 10:
                fnptr()    # never reached, or so we hope
            return n

        fn = self.getcompiled(f, [int])
        assert fn(6) == 6

    def test_likely_unlikely(self):
        from rpython.rlib.objectmodel import likely, unlikely

        def f(n):
            if unlikely(n > 50):
                return -10
            if likely(n > 5):
                return 42
            return 3

        fn = self.getcompiled(f, [int])
        assert fn(0) == 3
        assert fn(10) == 42
        assert fn(100) == -10

    def test_cast_to_bool_1(self):
        def f(n):
            return cast_primitive(Bool, n)

        fn = self.getcompiled(f, [int])
        assert fn(0) == False
        assert fn(1) == True
        assert fn(256) == True
        assert fn(-2**24) == True

    def test_cast_to_bool_1_longlong(self):
        def f(n):
            return cast_primitive(Bool, n)

        fn = self.getcompiled(f, [r_longlong])
        assert fn(r_longlong(0)) == False
        assert fn(r_longlong(1)) == True
        assert fn(r_longlong(256)) == True
        assert fn(r_longlong(2**32)) == True

    def test_cast_to_bool_2(self):
        def f(n):
            return rffi.cast(Bool, n)

        fn = self.getcompiled(f, [int])
        assert fn(0) == False
        assert fn(1) == True
        assert fn(256) == True
        assert fn(-2**24) == True

    def test_cast_to_bool_2_longlong(self):
        def f(n):
            return rffi.cast(Bool, n)

        fn = self.getcompiled(f, [r_longlong])
        assert fn(r_longlong(0)) == False
        assert fn(r_longlong(1)) == True
        assert fn(r_longlong(256)) == True
        assert fn(r_longlong(2**32)) == True

    def test_extra_item_after_alloc(self):
        from rpython.rlib import rgc
        from rpython.rtyper.lltypesystem import lltype
        from rpython.rtyper.lltypesystem import rstr
        # all STR objects should be allocated with enough space for one
        # extra char.  Check this for prebuilt strings, and for dynamically
        # allocated ones with the default GC for tests.  Use strings of 8,
        # 16 and 24 chars because if the extra char is missing, writing to it
        # is likely to cause corruption in nearby structures.
        sizes = [random.choice([8, 16, 24]) for i in range(100)]
        A = lltype.Struct('A', ('x', lltype.Signed))
        prebuilt = [(rstr.mallocstr(sz),
                     lltype.malloc(A, flavor='raw', immortal=True))
                        for sz in sizes]
        k = 0
        for i, (s, a) in enumerate(prebuilt):
            a.x = i
            for i in range(len(s.chars)):
                k += 1
                if k == 256:
                    k = 1
                s.chars[i] = chr(k)

        def check(lst):
            hashes = []
            for i, (s, a) in enumerate(lst):
                assert a.x == i
                rgc.ll_write_final_null_char(s)
            for i, (s, a) in enumerate(lst):
                assert a.x == i     # check it was not overwritten
        def f():
            check(prebuilt)
            lst1 = []
            for i, sz in enumerate(sizes):
                s = rstr.mallocstr(sz)
                a = lltype.malloc(A, flavor='raw')
                a.x = i
                lst1.append((s, a))
            check(lst1)
            for _, a in lst1:
                lltype.free(a, flavor='raw')
            return 42

        fn = self.getcompiled(f, [])
        assert fn() == 42
