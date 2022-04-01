
import py
import sys
from rpython.rtyper.lltypesystem.rffi import *
from rpython.rtyper.lltypesystem.rffi import _keeper_for_type # crap
from rpython.rlib.rposix import get_saved_errno, set_saved_errno
from rpython.translator.c.test.test_genc import compile as compile_c
from rpython.rtyper.lltypesystem.lltype import Signed, Ptr, Char, malloc
from rpython.rtyper.lltypesystem import lltype
from rpython.translator import cdir
from rpython.tool.udir import udir
from rpython.rtyper.test.test_llinterp import interpret
from rpython.annotator.annrpython import RPythonAnnotator
from rpython.rtyper.rtyper import RPythonTyper
from rpython.translator.backendopt.all import backend_optimizations
from rpython.translator.translator import graphof
from rpython.conftest import option
from rpython.flowspace.model import summary
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rlib.rarithmetic import r_singlefloat

class BaseTestRffi:
    def test_basic(self):
        c_source = py.code.Source("""
        int someexternalfunction(int x)
        {
            return (x + 3);
        }
        """)

        eci = ExternalCompilationInfo(separate_module_sources=[c_source])
        z = llexternal('someexternalfunction', [Signed], Signed,
                       compilation_info=eci)

        def f():
            return z(8)

        xf = self.compile(f, [])
        assert xf() == 8+3

    def test_no_float_to_int_conversion(self):
        c_source = py.code.Source("""
        int someexternalfunction(int x)
        {
            return (x + 3);
        }
        """)

        eci = ExternalCompilationInfo(separate_module_sources=[c_source])
        z = llexternal('someexternalfunction', [Signed], Signed,
                       compilation_info=eci)

        def f():
            return z(8.2)

        py.test.raises(TypeError, f)
        py.test.raises(TypeError, self.compile, f, [])

    def test_hashdefine(self):
        h_source = """
        #define X(i) (i+3)
        """

        h_file = udir.join("stuff.h")
        h_file.write(h_source)

        eci = ExternalCompilationInfo(includes=['stuff.h'],
                                      include_dirs=[udir])
        z = llexternal('X', [Signed], Signed, compilation_info=eci)
        py.test.raises(AssertionError, z, 8, 9)

        def f():
            return z(8)

        xf = self.compile(f, [])
        assert xf() == 8+3

    def test_string(self):
        eci = ExternalCompilationInfo(includes=['string.h'])
        z = llexternal('strlen', [CCHARP], Signed, compilation_info=eci)

        def f():
            s = str2charp("xxx")
            res = z(s)
            free_charp(s)
            return res

        xf = self.compile(f, [], backendopt=False)
        assert xf() == 3

    def test_unicode(self):
        eci = ExternalCompilationInfo(includes=['string.h'])
        z = llexternal('wcslen', [CWCHARP], Signed, compilation_info=eci)

        def f():
            s = unicode2wcharp(u"xxx\xe9")
            res = z(s)
            free_wcharp(s)
            return res

        xf = self.compile(f, [], backendopt=False)
        assert xf() == 4

    def test_charp2str_exact_result(self):
        from rpython.annotator.annrpython import RPythonAnnotator
        from rpython.rtyper.llannotation import SomePtr
        a = RPythonAnnotator()
        s = a.build_types(charpsize2str, [SomePtr(CCHARP), int])
        assert s.knowntype == str
        assert s.can_be_None is False
        assert s.no_nul is False
        #
        a = RPythonAnnotator()
        s = a.build_types(charp2str, [SomePtr(CCHARP)])
        assert s.knowntype == str
        assert s.can_be_None is False
        assert s.no_nul is True

    def test_string_reverse(self):
        c_source = py.code.Source("""
        #include <string.h>
        #include <src/mem.h>

        void f(char *target, char* arg)
        {
            strcpy(target, arg);
        }
        """)
        eci = ExternalCompilationInfo(separate_module_sources=[c_source],
                                     post_include_bits=['void f(char*,char*);'])
        z = llexternal('f', [CCHARP, CCHARP], lltype.Void, compilation_info=eci)

        def f():
            s = str2charp("xxx")
            l_res = lltype.malloc(CCHARP.TO, 10, flavor='raw')
            z(l_res, s)
            res = charp2str(l_res)
            lltype.free(l_res, flavor='raw')
            free_charp(s)
            return len(res)

        xf = self.compile(f, [], backendopt=False)
        assert xf() == 3

    def test_constcharp2str(self):
        c_source = py.code.Source("""
        const char *z(void)
        {
            return "hello world";
        }
        """)
        eci = ExternalCompilationInfo(separate_module_sources=[c_source],
                                     post_include_bits=['const char *z(void);'])
        z = llexternal('z', [], CONST_CCHARP, compilation_info=eci)

        def f():
            l_buf = lltype.malloc(CCHARP.TO, 5, flavor='raw')
            l_buf[0] = 'A'
            l_buf[1] = 'B'
            l_buf[2] = 'C'
            l_buf[3] = '\x00'
            l_buf[4] = 'E'
            l_constbuf = cast(CONST_CCHARP, l_buf)
            res = constcharp2str(l_constbuf)
            lltype.free(l_buf, flavor='raw')
            return len(res)

        assert f() == 3
        xf = self.compile(f, [], backendopt=False)
        assert xf() == 3

    def test_constcharpsize2str(self):
        def f():
            l_buf = lltype.malloc(CCHARP.TO, 5, flavor='raw')
            l_buf[0] = 'A'
            l_buf[1] = 'B'
            l_buf[2] = 'C'
            l_buf[3] = '\x00'
            l_buf[4] = 'E'
            l_constbuf = cast(CONST_CCHARP, l_buf)
            res = constcharpsize2str(l_constbuf, 5)
            lltype.free(l_buf, flavor='raw')
            return res

        assert f() == "ABC\x00E"
        xf = self.compile(f, [], backendopt=False)
        assert xf() == "ABC\x00E"

    def test_stringstar(self):
        c_source = """
        #include <string.h>

        int f(char *args[]) {
            char **p = args;
            int l = 0;
            while (*p) {
                l += strlen(*p);
                p++;
            }
            return (l);
        }
        """
        eci = ExternalCompilationInfo(separate_module_sources=[c_source])
        z = llexternal('f', [CCHARPP], Signed, compilation_info=eci)

        def f():
            l = ["xxx", "x", "xxxx"]
            ss = liststr2charpp(l)
            result = z(ss)
            free_charpp(ss)
            return result

        xf = self.compile(f, [], backendopt=False)
        assert xf() == 8

    def test_struct(self):
        h_source = """
        #ifndef _MY_SOURCE_H
        #define _MY_SOURCE_H
        struct xx {
           int one;
           char two;
           int three;
        };
        #endif
        """
        h_file = udir.join("structxx.h")
        h_file.write(h_source)

        c_source = """
        #include <structxx.h>

        int f(struct xx* z)
        {
          return (z->one + z->three);
        }
        """
        TP = CStructPtr('xx', ('one', INT), ('two', Char), ('three', INT))

        eci = ExternalCompilationInfo(
            includes=['structxx.h'],
            include_dirs=[udir],
            separate_module_sources=[c_source]
        )
        z = llexternal('f', [TP], INT, compilation_info=eci)

        def f():
            struct = lltype.malloc(TP.TO, flavor='raw')
            struct.c_one = cast(INT, 3)
            struct.c_two = '\x33'
            struct.c_three = cast(INT, 5)
            result = z(struct)
            lltype.free(struct, flavor='raw')
            return cast(SIGNED, result)

        fn = self.compile(f, [], backendopt=False)
        assert fn() == 8

    def test_externvar(self):
        import os
        if os.name == 'nt':
            # Windows CRT badly aborts when an invalid fd is used.
            bad_fd = 0
        else:
            bad_fd = 12312312

        def f():
            set_saved_errno(12)
            return get_saved_errno()

        def g():
            try:
                os.write(bad_fd, "xxx")
            except OSError:
                pass
            return get_saved_errno()

        fn = self.compile(f, [])
        assert fn() == 12
        gn = self.compile(g, [])
        import errno
        assert gn() == errno.EBADF


    def test_extra_include_dirs(self):
        udir.ensure("incl", dir=True)
        udir.join("incl", "incl.h").write("#define C 3")
        c_source = py.code.Source("""
        #include <incl.h>
        int fun ()
        {
            return (C);
        }
        """)
        eci = ExternalCompilationInfo(
            includes=['incl.h'],
            include_dirs=[str(udir.join('incl'))],
            separate_module_sources=[c_source]
        )
        z = llexternal('fun', [], Signed, compilation_info=eci)

        def f():
            return z()

        res = self.compile(f, [])
        assert res() == 3

    def test_compile_cast(self):
        def f(n):
            return cast(SIZE_T, n)

        f1 = self.compile(f, [int])
        res = f1(-1)
        assert res == r_size_t(-1)

    def test_opaque_type(self):
        h_source = py.code.Source("""
        #ifndef _OPAQUE_H
        #define _OPAQUE_H
        struct stuff {
           char data[38];
        };
        #endif /* _OPAQUE_H */
        """)

        c_source = py.code.Source("""
        #include "opaque.h"

        char get(struct stuff* x)
        {
           x->data[13] = 'a';
           return x->data[13];
        }
        """)


        # if it doesn't segfault, than we probably malloced it :-)
        h_file = udir.join("opaque.h")
        h_file.write(h_source)

        from rpython.rtyper.tool import rffi_platform
        eci = ExternalCompilationInfo(
            includes=['opaque.h'],
            include_dirs=[str(udir)],
            separate_module_sources=[c_source]
        )
        STUFFP = COpaquePtr('struct stuff', compilation_info=eci)

        ll_get = llexternal('get', [STUFFP], CHAR, compilation_info=eci)

        def f():
            ll_stuff = lltype.malloc(STUFFP.TO, flavor='raw')
            result = ll_get(ll_stuff)
            lltype.free(ll_stuff, flavor='raw')
            return result

        f1 = self.compile(f, [])
        assert f1() == 'a'

    def test_opaque_typedef(self):
        code = """
        #include <stddef.h>
        struct stuff;
        typedef struct stuff *stuff_ptr;
        static int get(stuff_ptr ptr) { return (ptr != NULL); }
        """

        eci = ExternalCompilationInfo(
            post_include_bits = [code]
        )

        STUFFP = COpaquePtr(typedef='stuff_ptr', compilation_info=eci)
        ll_get = llexternal('get', [STUFFP], lltype.Signed,
                            compilation_info=eci)

        def f():
            return ll_get(lltype.nullptr(STUFFP.TO))

        f1 = self.compile(f, [])
        assert f1() == 0

    def return_char(self, signed):
        ctype_pref = ["un", ""][signed]
        rffi_type = [UCHAR, SIGNEDCHAR][signed]
        h_source = py.code.Source("""
        %ssigned char returnchar(void)
        {
            return 42;
        }
        """ % (ctype_pref, ))
        h_file = udir.join("opaque2%s.h" % (ctype_pref, ))
        h_file.write(h_source)

        from rpython.rtyper.tool import rffi_platform
        eci = ExternalCompilationInfo(
            includes=[h_file.basename],
            include_dirs=[str(udir)]
        )
        ll_returnchar = llexternal('returnchar', [], rffi_type, compilation_info=eci)

        def f():
            result = ll_returnchar()
            return result

        f1 = self.compile(f, [])
        assert f1() == chr(42)

    def test_generate_return_char_tests(self):
        yield self.return_char, False
        yield self.return_char, True

    def test_prebuilt_constant(self):
        py.test.skip("Think how to do it sane")
        h_source = py.code.Source("""
        int x = 3;
        char** z = NULL;
        #endif
        """)
        h_include = udir.join('constants.h')
        h_include.write(h_source)

        eci = ExternalCompilationInfo(includes=['stdio.h',
                                                str(h_include.basename)],
                                      include_dirs=[str(udir)])

        get_x, set_x = CExternVariable(lltype.Signed, 'x', eci)
        get_z, set_z = CExternVariable(CCHARPP, 'z', eci)

        def f():
            one = get_x()
            set_x(13)
            return one + get_x()

        def g():
            l = liststr2charpp(["a", "b", "c"])
            try:
                set_z(l)
                return charp2str(get_z()[2])
            finally:
                free_charpp(l)

        fn = self.compile(f, [])
        assert fn() == 16
        gn = self.compile(g, [])
        assert gn() == "c"

    def eating_callback(self):
        h_source = py.code.Source("""
        #ifndef _CALLBACK_H
        #define _CALLBACK_H
        RPY_EXTERN Signed eating_callback(Signed arg, Signed(*call)(Signed));
        #endif /* _CALLBACK_H */
        """)

        h_include = udir.join('callback.h')
        h_include.write(h_source)

        c_source = py.code.Source("""
        #include "src/precommondefs.h"

        RPY_EXTERN Signed eating_callback(Signed arg, Signed(*call)(Signed))
        {
            Signed res = call(arg);
            if (res == -1)
              return -1;
            return res;
        }
        """)

        eci = ExternalCompilationInfo(includes=['callback.h'],
                                      include_dirs=[str(udir), cdir],
                                      separate_module_sources=[c_source])

        args = [SIGNED, CCallback([SIGNED], SIGNED)]
        eating_callback = llexternal('eating_callback', args, SIGNED,
                                     compilation_info=eci)

        return eating_callback

    def test_c_callback(self):
        eating_callback = self.eating_callback()
        def g(i):
            return i + 3

        def f():
            return eating_callback(3, g)

        fn = self.compile(f, [])
        assert fn() == 6
        assert eating_callback._ptr._obj._callbacks.callbacks == {g: True}

    def test_double_callback(self):
        eating_callback = self.eating_callback()

        def one(i):
            return i

        def two(i):
            return i + 2

        def f(i):
            if i > 3:
                return eating_callback(i, one)
            else:
                return eating_callback(i, two)

        fn = self.compile(f, [int])
        assert fn(4) == 4
        assert fn(1) == 3
        assert eating_callback._ptr._obj._callbacks.callbacks == {one: True,
                                                                  two: True}

    def test_exception_callback(self):
        eating_callback = self.eating_callback()

        def raising(i):
            if i > 3:
                raise ValueError
            else:
                return 3
        raising._errorcode_ = -1

        def f(i):
            return eating_callback(i, raising)

        fn = self.compile(f, [int])
        assert fn(13) == -1

    def test_callback_already_llptr(self):
        eating_callback = self.eating_callback()
        def g(i):
            return i + 3
        G = lltype.Ptr(lltype.FuncType([lltype.Signed], lltype.Signed))

        def f():
            return eating_callback(3, llhelper(G, g))

        fn = self.compile(f, [])
        assert fn() == 6

    def test_pass_opaque_pointer_via_callback(self):
        eating_callback = self.eating_callback()
        TP = lltype.Ptr(lltype.GcStruct('X', ('x', lltype.Signed)))
        struct = lltype.malloc(TP.TO) # gc structure
        struct.x = 8

        def g(i):
            return get_keepalive_object(i, TP).x

        pos = register_keepalive(struct)
        assert _keeper_for_type(TP).stuff_to_keepalive[pos] is struct
        del struct
        res = eating_callback(pos, g)
        unregister_keepalive(pos, TP)
        assert res == 8

    def test_nonmoving(self):
        d = 'non-moving data stuff'
        def f():
            with scoped_alloc_buffer(len(d)) as s:
                for i in range(len(d)):
                    s.raw[i] = d[i]
                return s.str(len(d)-1)
        assert f() == d[:-1]
        fn = self.compile(f, [], gcpolicy='ref')
        assert fn() == d[:-1]

    def test_nonmoving_unicode(self):
        d = u'non-moving data'
        def f():
            with scoped_alloc_unicodebuffer(len(d)) as s:
                for i in range(len(d)):
                    s.raw[i] = d[i]
                return s.str(len(d)-1).encode('ascii')
        assert f() == d[:-1]
        fn = self.compile(f, [], gcpolicy='ref')
        assert fn() == d[:-1]

    def test_nonmovingbuffer(self):
        d = 'some cool data that should not move'
        def f():
            buf, llobj, flag = get_nonmovingbuffer_ll(d)
            try:
                counter = 0
                for i in range(len(d)):
                    if buf[i] == d[i]:
                        counter += 1
                return counter
            finally:
                free_nonmovingbuffer_ll(buf, llobj, flag)
        assert f() == len(d)
        fn = self.compile(f, [], gcpolicy='ref')
        assert fn() == len(d)

    def test_nonmovingbuffer_semispace(self):
        d = 'cool data'
        def f():
            counter = 0
            for n in range(32):
                buf, llobj, flag = get_nonmovingbuffer_ll(d)
                try:
                    for i in range(len(d)):
                        if buf[i] == d[i]:
                            counter += 1
                finally:
                    free_nonmovingbuffer_ll(buf, llobj, flag)
            return counter
        fn = self.compile(f, [], gcpolicy='semispace')
        # The semispace gc uses raw_malloc for its internal data structs
        # but hopefully less than 30 times.  So we should get < 30 leaks
        # unless the get_nonmovingbuffer()/free_nonmovingbuffer() pair
        # leaks at each iteration.  This is what the following line checks.
        res = fn(expected_extra_mallocs=range(30))
        assert res == 32 * len(d)

    def test_nonmovingbuffer_incminimark(self):
        d = 'cool data'
        def f():
            counter = 0
            for n in range(32):
                buf, llobj, flag = get_nonmovingbuffer_ll(d)
                try:
                    for i in range(len(d)):
                        if buf[i] == d[i]:
                            counter += 1
                finally:
                    free_nonmovingbuffer_ll(buf, llobj, flag)
            return counter
        fn = self.compile(f, [], gcpolicy='incminimark')
        # The incminimark gc uses raw_malloc for its internal data structs
        # but hopefully less than 30 times.  So we should get < 30 leaks
        # unless the get_nonmovingbuffer()/free_nonmovingbuffer() pair
        # leaks at each iteration.  This is what the following line checks.
        res = fn(expected_extra_mallocs=range(30))
        assert res == 32 * len(d)

    def test_wcharp_to_utf8(self):
        wchar = lltype.malloc(CWCHARP.TO, 3, flavor='raw')
        wchar[0] = u'\u1234'
        wchar[1] = u'\x80'
        wchar[2] = u'a'
        assert wcharpsize2utf8(wchar, 3).decode("utf8") == u'\u1234\x80a'
        lltype.free(wchar, flavor='raw')

class TestRffiInternals:
    def test_struct_create(self):
        X = CStruct('xx', ('one', INT))
        def f():
            p = make(X, c_one=cast(INT, 3))
            res = p.c_one
            lltype.free(p, flavor='raw')
            return cast(SIGNED, res)
        assert f() == 3
        assert interpret(f, []) == 3

    def test_structcopy(self):
        X2 = lltype.Struct('X2', ('x', SIGNED))
        X1 = lltype.Struct('X1', ('a', SIGNED), ('x2', X2), ('p', lltype.Ptr(X2)))
        def f():
            p2 = make(X2, x=123)
            p1 = make(X1, a=5, p=p2)
            p1.x2.x = 456
            p1bis = make(X1)
            p2bis = make(X2)
            structcopy(p1bis, p1)
            assert p1bis.a == 5
            assert p1bis.x2.x == 456
            assert p1bis.p == p2
            structcopy(p2bis, p2)
            res = p2bis.x
            lltype.free(p2bis, flavor='raw')
            lltype.free(p1bis, flavor='raw')
            lltype.free(p2, flavor='raw')
            lltype.free(p1, flavor='raw')
            return res
        assert f() == 123
        res = interpret(f, [])
        assert res == 123

    def test_make_annotation(self):
        X = CStruct('xx', ('one', INT))
        def f():
            p = make(X)
            try:
                q = make(X)
                lltype.free(q, flavor='raw')
            finally:
                lltype.free(p, flavor='raw')
            return 3
        assert interpret(f, []) == 3

    def test_implicit_cast(self):
        z = llexternal('z', [USHORT, ULONG, USHORT, DOUBLE], USHORT,
                       sandboxsafe=True)   # to allow the wrapper to be inlined

        def f(x, y, xx, yy):
            return z(x, y, xx, yy)

        a = RPythonAnnotator()
        r = a.build_types(f, [int, int, int, int])
        rtyper = RPythonTyper(a)
        rtyper.specialize()
        a.translator.rtyper = rtyper
        backend_optimizations(a.translator)
        if option.view:
            a.translator.view()
        graph = graphof(a.translator, f)
        s = summary(graph)
        # there should be not too many operations here by now
        expected = {'force_cast': 3, 'cast_int_to_float': 1, 'direct_call': 1}
        for k, v in expected.items():
            assert s[k] == v

    def test_stringpolicy1(self):
        eci = ExternalCompilationInfo(includes=['string.h'])
        strlen = llexternal('strlen', [CCHARP], SIZE_T, compilation_info=eci)
        def f():
            return cast(SIGNED, strlen("Xxx"))
        assert interpret(f, [], backendopt=True) == 3

    def test_stringpolicy3(self):
        eci = ExternalCompilationInfo(includes=['string.h'])
        strlen = llexternal('strlen', [CCHARP], INT, compilation_info=eci)
        def f():
            ll_str = str2charp("Xxx")
            res = strlen(ll_str)
            lltype.free(ll_str, flavor='raw')
            return res

        assert interpret(f, [], backendopt=True) == 3

    def test_stringpolicy_mixed(self):
        eci = ExternalCompilationInfo(includes=['string.h'])
        strlen = llexternal('strlen', [CCHARP], SIZE_T,
                            compilation_info=eci)
        def f():
            res1 = strlen("abcd")
            ll_str = str2charp("Xxx")
            res2 = strlen(ll_str)
            lltype.free(ll_str, flavor='raw')
            return cast(SIGNED, res1*10 + res2)

        assert interpret(f, [], backendopt=True) == 43

    def test_str2chararray(self):
        eci = ExternalCompilationInfo(includes=['string.h'])
        strlen = llexternal('strlen', [CCHARP], SIZE_T,
                            compilation_info=eci)
        def f():
            raw = str2charp("XxxZy")
            n = str2chararray("abcdef", raw, 4)
            assert raw[0] == 'a'
            assert raw[1] == 'b'
            assert raw[2] == 'c'
            assert raw[3] == 'd'
            assert raw[4] == 'y'
            lltype.free(raw, flavor='raw')
            return n

        assert interpret(f, []) == 4

    def test_external_callable(self):
        """ Try to call some llexternal function with llinterp
        """
        z = llexternal('z', [Signed], Signed, _callable=lambda x:x+1)

        def f():
            return z(2)

        res = interpret(f, [])
        assert res == 3

    def test_size_t_sign(self):
        assert r_size_t(-1) > 0

    def test_cast(self):
        res = cast(SIZE_T, -1)
        assert type(res) is r_size_t
        assert res == r_size_t(-1)
        #
        res = cast(lltype.Signed, 42.5)
        assert res == 42

        res = cast(lltype.SingleFloat, 12.3)
        assert res == r_singlefloat(12.3)
        res = cast(lltype.SingleFloat, res)
        assert res == r_singlefloat(12.3)

        res = cast(lltype.Float, r_singlefloat(12.))
        assert res == 12.

    def test_rffi_sizeof(self):
        try:
            import ctypes
        except ImportError:
            py.test.skip("Cannot test without ctypes")
        cache = {
            lltype.Signed:   ctypes.c_long,
            lltype.Unsigned: ctypes.c_ulong,
            lltype.UniChar:  ctypes.c_wchar,
            lltype.Char:     ctypes.c_ubyte,
        }
        if sys.platform == 'win32' and sys.maxint > 2**32:
            cache[lltype.Signed] = ctypes.c_longlong
            cache[lltype.Unsigned] = ctypes.c_ulonglong
        cache2 = {
            DOUBLE:     ctypes.c_double,
            FLOAT:      ctypes.c_float,
            SIGNEDCHAR: ctypes.c_byte,
            UCHAR:      ctypes.c_ubyte,
            SHORT:      ctypes.c_short,
            USHORT:     ctypes.c_ushort,
            INT:        ctypes.c_int,
            UINT:       ctypes.c_uint,
            LONG:       ctypes.c_long,
            ULONG:      ctypes.c_ulong,
            LONGLONG:   ctypes.c_longlong,
            ULONGLONG:  ctypes.c_ulonglong,
            SIZE_T:     ctypes.c_size_t,
        }

        for ll, ctp in cache.items():
            assert sizeof(ll) == ctypes.sizeof(ctp)
            assert sizeof(lltype.Typedef(ll, 'test')) == sizeof(ll)
        for ll, ctp in cache2.items():
            assert sizeof(ll) == ctypes.sizeof(ctp)
            assert sizeof(lltype.Typedef(ll, 'test')) == sizeof(ll)
        assert not size_and_sign(lltype.Signed)[1]
        assert size_and_sign(lltype.Char) == (1, True)
        assert size_and_sign(lltype.UniChar)[1]
        assert size_and_sign(UINT)[1]
        assert not size_and_sign(INT)[1]

    def test_rffi_offsetof(self):
        import struct
        from rpython.rtyper.tool import rffi_platform
        S = rffi_platform.getstruct("struct S",
                                      """
               struct S {
                   short a;
                   int b, c;
               };                     """,
                                      [("a", INT),
                                       ("b", INT),
                                       ("c", INT)])
        assert sizeof(S) == struct.calcsize("hii")
        assert offsetof(S, "c_a") == 0
        assert offsetof(S, "c_b") == struct.calcsize("hi") - struct.calcsize("i")
        assert offsetof(S, "c_c") == struct.calcsize("hii") - struct.calcsize("i")

ARRAY_OF_CHAR = lltype.Array(CHAR, hints={'nolength': True})

def test_ptradd():
    data = "hello, world!"
    a = lltype.malloc(ARRAY_OF_CHAR, len(data), flavor='raw')
    for i in xrange(len(data)):
        a[i] = data[i]
    a2 = ptradd(a, 2)
    assert lltype.typeOf(a2) == lltype.typeOf(a) == lltype.Ptr(ARRAY_OF_CHAR)
    for i in xrange(len(data) - 2):
        assert a2[i] == a[i + 2]
    lltype.free(a, flavor='raw')

def test_ptradd_interpret():
    interpret(test_ptradd, [])

def test_voidptr():
    assert repr(VOIDP) == "<* Array of void {'nolength': True, 'render_as_void': True} >"

class TestCRffi(BaseTestRffi):
    def compile(self, func, args, **kwds):
        return compile_c(func, args, **kwds)

    def test_generate_return_char_tests(self):
        py.test.skip("GenC does not handle char return values correctly")

    def test__get_raw_address_buf_from_string(self):
        from rpython.rlib import rgc
        from rpython.rtyper.lltypesystem import rffi

        def check_content(strings, rawptrs):
            for i in range(len(strings)):
                p = rawptrs[i]
                expected = strings[i] + '\x00'
                for j in range(len(expected)):
                    assert p[j] == expected[j]

        def f(n):
            strings = ["foo%d" % i for i in range(n)]
            rawptrs = [rffi._get_raw_address_buf_from_string(s)
                       for s in strings]
            check_content(strings, rawptrs)
            rgc.collect(); rgc.collect(); rgc.collect()
            check_content(strings, rawptrs)
            for i in range(len(strings)):   # check that it still returns the
                                            # same raw ptrs
                p1 = rffi._get_raw_address_buf_from_string(strings[i])
                assert rawptrs[i] == p1
            del strings
            rgc.collect(); rgc.collect(); rgc.collect()
            return 42

        rffi._StrFinalizerQueue.print_debugging = True
        try:
            xf = self.compile(f, [int], gcpolicy="incminimark",
                              return_stderr=True)
        finally:
            rffi._StrFinalizerQueue.print_debugging = False

        os.environ['PYPYLOG'] = ':-'
        try:
            error = xf(10000)
        finally:
            del os.environ['PYPYLOG']

        import re
        r = re.compile(r"freeing str [[] [0-9a-fxA-FX]+ []]")
        matches = r.findall(error)
        assert len(matches) == 10000        # must be all 10000 strings,
        assert len(set(matches)) == 10000   # and no duplicates


def test_enforced_args():
    from rpython.annotator.model import s_None
    from rpython.rtyper.annlowlevel import MixLevelHelperAnnotator
    from rpython.translator.interactive import Translation
    def f1():
        str2charp("hello")
    def f2():
        str2charp("world")
    t = Translation(f1, [])
    t.rtype()
    mixann = MixLevelHelperAnnotator(t.context.rtyper)
    mixann.getgraph(f2, [], s_None)
    mixann.finish()

def test_force_cast_unichar():
    x = cast(lltype.UniChar, -1)
    assert isinstance(x, unicode)
    if sys.maxunicode == 65535:
        assert cast(LONG, x) == 65535
    else:
        assert cast(LONG, cast(INT, x)) == -1

def test_c_memcpy():
    p1 = str2charp("hello")
    p2 = str2charp("WORLD")
    c_memcpy(cast(VOIDP, p2), cast(VOIDP, p1), 3)
    assert charp2str(p1) == "hello"
    assert charp2str(p2) == "helLD"
    free_charp(p1)
    free_charp(p2)

def test_sign_when_casting_uint_to_larger_int():
    from rpython.rtyper.lltypesystem import rffi
    from rpython.rlib.rarithmetic import r_uint32, r_uint64
    #
    value = 0xAAAABBBB
    assert cast(lltype.SignedLongLong, r_uint32(value)) == value
    if hasattr(rffi, '__INT128_T'):
        value = 0xAAAABBBBCCCCDDDD
        assert cast(rffi.__INT128_T, r_uint64(value)) == value

def test_scoped_view_charp():
    s = 'bar'
    with scoped_view_charp(s) as buf:
        assert buf[0] == 'b'
        assert buf[1] == 'a'
        assert buf[2] == 'r'
        assert buf[3] == '\x00'

def test_scoped_nonmoving_unicodebuffer():
    s = u'bar'
    with scoped_nonmoving_unicodebuffer(s) as buf:
        assert buf[0] == u'b'
        assert buf[1] == u'a'
        assert buf[2] == u'r'
        with py.test.raises(IndexError):
            buf[3]

def test_wcharp2utf8n():
    w = 'hello\x00\x00\x00\x00'
    u, i = wcharp2utf8n(w, len(w))
    assert i == len('hello')
