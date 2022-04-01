import gc
import os
import py

from rpython.rlib.rarithmetic import r_singlefloat, r_longlong, r_ulonglong
from rpython.rlib.test.test_clibffi import BaseFfiTest, make_struct_ffitype_e
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper.lltypesystem.ll2ctypes import ALLOCATED
from rpython.rtyper.llinterp import LLException
from rpython.translator import cdir
from rpython.rlib.libffi import (CDLL, ArgChain, types,
                              IS_32_BIT, IS_WIN64, array_getitem, array_setitem)
from rpython.rlib.libffi import (struct_getfield_int, struct_setfield_int,
                              struct_getfield_longlong, struct_setfield_longlong,
                              struct_getfield_float, struct_setfield_float,
                              struct_getfield_singlefloat, struct_setfield_singlefloat)

class TestLibffiMisc(BaseFfiTest):

    CDLL = CDLL

    def test_argchain(self):
        chain = ArgChain()
        assert chain.numargs == 0
        chain2 = chain.arg(42)
        assert chain2 is chain
        assert chain.numargs == 1
        intarg = chain.first
        assert chain.last is intarg
        assert intarg.intval == 42
        chain.arg(123.45)
        assert chain.numargs == 2
        assert chain.first is intarg
        assert intarg.next is chain.last
        floatarg = intarg.next
        assert floatarg.floatval == 123.45

    def test_wrong_args(self):
        # so far the test passes but for the wrong reason :-), i.e. because
        # .arg() only supports integers and floats
        chain = ArgChain()
        x = lltype.malloc(lltype.GcStruct('xxx'))
        y = lltype.malloc(lltype.GcArray(rffi.SIGNED), 3)
        z = lltype.malloc(lltype.Array(rffi.SIGNED), 4, flavor='raw')
        py.test.raises(TypeError, "chain.arg(x)")
        py.test.raises(TypeError, "chain.arg(y)")
        py.test.raises(TypeError, "chain.arg(z)")
        lltype.free(z, flavor='raw')

    def test_library_open(self):
        lib = self.get_libc()
        del lib
        gc.collect()
        assert not ALLOCATED

    def test_library_get_func(self):
        lib = self.get_libc()
        ptr = lib.getpointer('fopen', [], types.void)
        py.test.raises(KeyError, lib.getpointer, 'xxxxxxxxxxxxxxx', [], types.void)
        del ptr
        del lib
        gc.collect()
        assert not ALLOCATED

    def test_struct_fields(self):
        longsize = 4 if IS_32_BIT or IS_WIN64 else 8
        POINT = lltype.Struct('POINT',
                              ('x', rffi.LONG),
                              ('y', rffi.SHORT),
                              ('z', rffi.VOIDP),
                              )
        y_ofs = longsize
        z_ofs = longsize*2
        p = lltype.malloc(POINT, flavor='raw')
        if IS_WIN64:
            p.x = rffi.cast(rffi.LONG, 42)
        else:
            p.x = 42
        p.y = rffi.cast(rffi.SHORT, -1)
        p.z = rffi.cast(rffi.VOIDP, 0x1234)
        addr = rffi.cast(rffi.VOIDP, p)
        assert struct_getfield_int(types.slong, addr, 0) == 42
        assert struct_getfield_int(types.sshort, addr, y_ofs) == -1
        assert struct_getfield_int(types.pointer, addr, z_ofs) == 0x1234
        #
        struct_setfield_int(types.slong, addr, 0, 43)
        struct_setfield_int(types.sshort, addr, y_ofs, 0x1234FFFE) # 0x1234 is masked out
        struct_setfield_int(types.pointer, addr, z_ofs, 0x4321)
        assert p.x == 43
        assert p.y == -2
        assert rffi.cast(rffi.LONG, p.z) == 0x4321
        #
        lltype.free(p, flavor='raw')

    def test_array_fields(self):
        POINT = lltype.Struct("POINT",
            ("x", lltype.Float),
            ("y", lltype.Float),
        )
        points = lltype.malloc(rffi.CArray(POINT), 2, flavor="raw")
        points[0].x = 1.0
        points[0].y = 2.0
        points[1].x = 3.0
        points[1].y = 4.0
        points = rffi.cast(rffi.CArrayPtr(lltype.Char), points)
        assert array_getitem(types.double, 16, points, 0, 0) == 1.0
        assert array_getitem(types.double, 16, points, 0, 8) == 2.0
        assert array_getitem(types.double, 16, points, 1, 0) == 3.0
        assert array_getitem(types.double, 16, points, 1, 8) == 4.0
        #
        array_setitem(types.double, 16, points, 0, 0, 10.0)
        array_setitem(types.double, 16, points, 0, 8, 20.0)
        array_setitem(types.double, 16, points, 1, 0, 30.0)
        array_setitem(types.double, 16, points, 1, 8, 40.0)
        #
        assert array_getitem(types.double, 16, points, 0, 0) == 10.0
        assert array_getitem(types.double, 16, points, 0, 8) == 20.0
        assert array_getitem(types.double, 16, points, 1, 0) == 30.0
        assert array_getitem(types.double, 16, points, 1, 8) == 40.0
        #
        lltype.free(points, flavor="raw")


    def test_struct_fields_longlong(self):
        POINT = lltype.Struct('POINT',
                              ('x', rffi.LONGLONG),
                              ('y', rffi.ULONGLONG)
                              )
        y_ofs = 8
        p = lltype.malloc(POINT, flavor='raw')
        p.x = r_longlong(123)
        p.y = r_ulonglong(456)
        addr = rffi.cast(rffi.VOIDP, p)
        assert struct_getfield_longlong(types.slonglong, addr, 0) == 123
        assert struct_getfield_longlong(types.ulonglong, addr, y_ofs) == 456
        #
        v = rffi.cast(lltype.SignedLongLong, r_ulonglong(9223372036854775808))
        struct_setfield_longlong(types.slonglong, addr, 0, v)
        struct_setfield_longlong(types.ulonglong, addr, y_ofs, r_longlong(-1))
        assert p.x == -9223372036854775808
        assert rffi.cast(lltype.UnsignedLongLong, p.y) == 18446744073709551615
        #
        lltype.free(p, flavor='raw')

    def test_struct_fields_float(self):
        POINT = lltype.Struct('POINT',
                              ('x', rffi.DOUBLE),
                              ('y', rffi.DOUBLE)
                              )
        y_ofs = 8
        p = lltype.malloc(POINT, flavor='raw')
        p.x = 123.4
        p.y = 567.8
        addr = rffi.cast(rffi.VOIDP, p)
        assert struct_getfield_float(types.double, addr, 0) == 123.4
        assert struct_getfield_float(types.double, addr, y_ofs) == 567.8
        #
        struct_setfield_float(types.double, addr, 0, 321.0)
        struct_setfield_float(types.double, addr, y_ofs, 876.5)
        assert p.x == 321.0
        assert p.y == 876.5
        #
        lltype.free(p, flavor='raw')

    def test_struct_fields_singlefloat(self):
        POINT = lltype.Struct('POINT',
                              ('x', rffi.FLOAT),
                              ('y', rffi.FLOAT)
                              )
        y_ofs = 4
        p = lltype.malloc(POINT, flavor='raw')
        p.x = r_singlefloat(123.4)
        p.y = r_singlefloat(567.8)
        addr = rffi.cast(rffi.VOIDP, p)
        assert struct_getfield_singlefloat(types.double, addr, 0) == r_singlefloat(123.4)
        assert struct_getfield_singlefloat(types.double, addr, y_ofs) == r_singlefloat(567.8)
        #
        struct_setfield_singlefloat(types.double, addr, 0, r_singlefloat(321.0))
        struct_setfield_singlefloat(types.double, addr, y_ofs, r_singlefloat(876.5))
        assert p.x == r_singlefloat(321.0)
        assert p.y == r_singlefloat(876.5)
        #
        lltype.free(p, flavor='raw')

    def test_windll(self):
        if os.name != 'nt':
            py.test.skip('Run only on windows')
        from rpython.rlib.libffi import WinDLL
        dll = WinDLL('Kernel32.dll')
        sleep = dll.getpointer('Sleep',[types.uint], types.void)
        chain = ArgChain()
        chain.arg(10)
        sleep.call(chain, lltype.Void, is_struct=False)

class TestLibffiCall(BaseFfiTest):
    """
    Test various kind of calls through libffi.

    The peculiarity of these tests is that they are run both directly (going
    really through libffi) and by jit/metainterp/test/test_fficall.py, which
    tests the call when JITted.

    If you need to test a behaviour than it's not affected by JITing (e.g.,
    typechecking), you should put your test in TestLibffiMisc.
    """

    CDLL = CDLL

    @classmethod
    def setup_class(cls):
        from rpython.tool.udir import udir
        from rpython.translator.tool.cbuild import ExternalCompilationInfo
        from rpython.translator.platform import platform

        BaseFfiTest.setup_class()
        # prepare C code as an example, so we can load it and call
        # it via rlib.libffi
        c_file = udir.ensure("test_libffi", dir=1).join("foolib.c")
        # automatically collect the C source from the docstrings of the tests
        snippets = []
        for name in dir(cls):
            if name.startswith('test_'):
                meth = getattr(cls, name)
                # the heuristic to determine it it's really C code could be
                # improved: so far we just check that there is a '{' :-)
                if meth.__doc__ is not None and '{' in meth.__doc__:
                    snippets.append(meth.__doc__)
        #
        INCLUDE = '#include "src/precommondefs.h"\n'
        c_file.write(INCLUDE + str(py.code.Source('\n'.join(snippets))))
        eci = ExternalCompilationInfo(include_dirs=[cdir])
        cls.libfoo_name = str(platform.compile([c_file], eci, 'x',
                                               standalone=False))
        cls.dll = cls.CDLL(cls.libfoo_name)

    def teardown_class(cls):
        if cls.dll:
            cls.dll.__del__()
            # Why doesn't this call cls.dll.__del__() ?
            #del cls.dll

    def get_libfoo(self):
        return self.dll    

    def call(self, funcspec, args, RESULT, is_struct=False, jitif=[]):
        """
        Call the specified function after constructing and ArgChain with the
        arguments in ``args``.

        The function is specified with ``funcspec``, which is a tuple of the
        form (lib, name, argtypes, restype).

        This method is overridden by metainterp/test/test_fficall.py in
        order to do the call in a loop and JIT it. The optional arguments are
        used only by that overridden method.

        """
        lib, name, argtypes, restype = funcspec
        func = lib.getpointer(name, argtypes, restype)
        chain = ArgChain()
        for arg in args:
            if isinstance(arg, tuple):
                methname, arg = arg
                meth = getattr(chain, methname)
                meth(arg)
            else:
                chain.arg(arg)
        return func.call(chain, RESULT, is_struct=is_struct)

    # ------------------------------------------------------------------------

    def test_very_simple(self):
        """
            RPY_EXPORTED
            int diff_xy(int x, Signed y)
            {
                return x - y;
            }
        """
        libfoo = self.get_libfoo()
        func = (libfoo, 'diff_xy', [types.sint, types.signed], types.sint)
        res = self.call(func, [50, 8], rffi.INT)
        assert res == 42

    def test_simple(self):
        """
            RPY_EXPORTED
            int sum_xy(int x, double y)
            {
                return (x + (int)y);
            }
        """
        libfoo = self.get_libfoo()
        func = (libfoo, 'sum_xy', [types.sint, types.double], types.sint)
        res = self.call(func, [38, 4.2], rffi.INT, jitif=["floats"])
        assert res == 42

    def test_float_result(self):
        libm = self.get_libm()
        func = (libm, 'pow', [types.double, types.double], types.double)
        res = self.call(func, [2.0, 3.0], rffi.DOUBLE, jitif=["floats"])
        assert res == 8.0

    def test_cast_result(self):
        """
            RPY_EXPORTED
            unsigned char cast_to_uchar_and_ovf(int x)
            {
                return 200+(unsigned char)x;
            }
        """
        libfoo = self.get_libfoo()
        func = (libfoo, 'cast_to_uchar_and_ovf', [types.sint], types.uchar)
        res = self.call(func, [0], rffi.UCHAR)
        assert res == 200

    def test_cast_argument(self):
        """
            RPY_EXPORTED
            int many_args(char a, int b)
            {
                return a+b;
            }
        """
        libfoo = self.get_libfoo()
        func = (libfoo, 'many_args', [types.uchar, types.sint], types.sint)
        res = self.call(func, [chr(20), 22], rffi.INT)
        assert res == 42

    def test_char_args(self):
        """
        RPY_EXPORTED
        char sum_args(char a, char b) {
            return a + b;
        }
        """
        libfoo = self.get_libfoo()
        func = (libfoo, 'sum_args', [types.schar, types.schar], types.schar)
        res = self.call(func, [123, 43], rffi.CHAR)
        assert res == chr(166)

    def test_unsigned_short_args(self):
        """
            RPY_EXPORTED
            unsigned short sum_xy_us(unsigned short x, unsigned short y)
            {
                return x+y;
            }
        """
        libfoo = self.get_libfoo()
        func = (libfoo, 'sum_xy_us', [types.ushort, types.ushort], types.ushort)
        res = self.call(func, [32000, 8000], rffi.USHORT)
        assert res == 40000


    def test_pointer_as_argument(self):
        """#include <stdlib.h>
            RPY_EXPORTED
            Signed inc(Signed* x)
            {
                Signed oldval;
                if (x == NULL)
                    return -1;
                oldval = *x;
                *x = oldval+1;
                return oldval;
            }
        """
        libfoo = self.get_libfoo()
        func = (libfoo, 'inc', [types.pointer], types.signed)
        null = lltype.nullptr(rffi.SIGNEDP.TO)
        res = self.call(func, [null], rffi.SIGNED)
        assert res == -1
        #
        ptr_result = lltype.malloc(rffi.SIGNEDP.TO, 1, flavor='raw')
        ptr_result[0] = 41
        res = self.call(func, [ptr_result], rffi.SIGNED)
        if self.__class__ is TestLibffiCall:
            # the function was called only once
            assert res == 41
            assert ptr_result[0] == 42
            lltype.free(ptr_result, flavor='raw')
            # the test does not make sense when run with the JIT through
            # meta_interp, because the __del__ are not properly called (hence
            # we "leak" memory)
            del libfoo
            gc.collect()
            assert not ALLOCATED
        else:
            # the function as been called 9 times
            assert res == 50
            assert ptr_result[0] == 51
            lltype.free(ptr_result, flavor='raw')

    def test_return_pointer(self):
        """
            struct pair {
                Signed a;
                Signed b;
            };

            struct pair my_static_pair = {10, 20};

            RPY_EXPORTED
            Signed* get_pointer_to_b()
            {
                return &my_static_pair.b;
            }
        """
        libfoo = self.get_libfoo()
        func = (libfoo, 'get_pointer_to_b', [], types.pointer)
        res = self.call(func, [], rffi.SIGNEDP)
        assert res[0] == 20

    def test_void_result(self):
        """
            int dummy;
            RPY_EXPORTED
            void set_dummy(int val) { dummy = val; }
            RPY_EXPORTED
            int get_dummy() { return dummy; }
        """
        libfoo = self.get_libfoo()
        set_dummy = (libfoo, 'set_dummy', [types.sint], types.void)
        get_dummy = (libfoo, 'get_dummy', [], types.sint)
        #
        initval = self.call(get_dummy, [], rffi.INT)
        #
        res = self.call(set_dummy, [initval+1], lltype.Void)
        assert res is None
        #
        res = self.call(get_dummy, [], rffi.INT)
        assert res == initval+1

    def test_single_float_args(self):
        """
            RPY_EXPORTED
            float sum_xy_float(float x, float y)
            {
                return x+y;
            }
        """
        from ctypes import c_float # this is used only to compute the expected result
        libfoo = self.get_libfoo()
        func = (libfoo, 'sum_xy_float', [types.float, types.float], types.float)
        x = r_singlefloat(12.34)
        y = r_singlefloat(56.78)
        res = self.call(func, [x, y], rffi.FLOAT, jitif=["singlefloats"])
        expected = c_float(c_float(12.34).value + c_float(56.78).value).value
        assert float(res) == expected

    def test_slonglong_args(self):
        """
            RPY_EXPORTED
            long long sum_xy_longlong(long long x, long long y)
            {
                return x+y;
            }
        """
        maxint32 = 2147483647 # we cannot really go above maxint on 64 bits
                              # (and we would not test anything, as there long
                              # is the same as long long)
        libfoo = self.get_libfoo()
        func = (libfoo, 'sum_xy_longlong', [types.slonglong, types.slonglong],
                types.slonglong)
        if IS_32_BIT:
            x = r_longlong(maxint32+1)
            y = r_longlong(maxint32+2)
        else:
            x = maxint32+1
            y = maxint32+2
        res = self.call(func, [x, y], rffi.LONGLONG, jitif=["longlong"])
        expected = maxint32*2 + 3
        assert res == expected

    def test_ulonglong_args(self):
        """
            RPY_EXPORTED
            unsigned long long sum_xy_ulonglong(unsigned long long x,
                                                unsigned long long y)
            {
                return x+y;
            }
        """
        maxint64 = 9223372036854775807 # maxint64+1 does not fit into a
                                       # longlong, but it does into a
                                       # ulonglong
        libfoo = self.get_libfoo()
        func = (libfoo, 'sum_xy_ulonglong', [types.ulonglong, types.ulonglong],
                types.ulonglong)
        x = r_ulonglong(maxint64+1)
        y = r_ulonglong(2)
        res = self.call(func, [x, y], rffi.ULONGLONG, jitif=["longlong"])
        expected = maxint64 + 3
        assert res == expected

    def test_wrong_number_of_arguments(self):
        from rpython.rtyper.llinterp import LLException
        libfoo = self.get_libfoo()
        func = (libfoo, 'sum_xy', [types.sint, types.double], types.sint)

        glob = globals()
        loc = locals()
        def my_raises(s):
            try:
                exec(s, glob, loc)
            except TypeError:
                pass
            except LLException as e:
                if str(e) != "<LLException 'TypeError'>":
                    raise
            else:
                assert False, 'Did not raise'

        my_raises("self.call(func, [38], rffi.SIGNED)") # one less
        my_raises("self.call(func, [38, 12.3, 42], rffi.SIGNED)") # one more


    def test_byval_argument(self):
        """
            struct Point {
                Signed x;
                Signed y;
            };

            RPY_EXPORTED
            Signed sum_point(struct Point p) {
                return p.x + p.y;
            }
        """
        libfoo = CDLL(self.libfoo_name)
        ffi_point_struct = make_struct_ffitype_e(0, 0, [types.signed, types.signed])
        ffi_point = ffi_point_struct.ffistruct
        sum_point = (libfoo, 'sum_point', [ffi_point], types.signed)
        #
        ARRAY = rffi.CArray(rffi.SIGNED)
        buf = lltype.malloc(ARRAY, 2, flavor='raw')
        buf[0] = 30
        buf[1] = 12
        adr = rffi.cast(rffi.VOIDP, buf)
        res = self.call(sum_point, [('arg_raw', adr)], rffi.SIGNED,
                        jitif=["byval"])
        assert res == 42
        # check that we still have the ownership on the buffer
        assert buf[0] == 30
        assert buf[1] == 12
        lltype.free(buf, flavor='raw')
        lltype.free(ffi_point_struct, flavor='raw')

    def test_byval_result(self):
        """
            RPY_EXPORTED
            struct Point make_point(Signed x, Signed y) {
                struct Point p;
                p.x = x;
                p.y = y;
                return p;
            }
        """
        libfoo = CDLL(self.libfoo_name)
        ffi_point_struct = make_struct_ffitype_e(rffi.sizeof(rffi.SIGNED)*2, 0, [types.signed, types.signed])
        ffi_point = ffi_point_struct.ffistruct

        libfoo = CDLL(self.libfoo_name)
        make_point = (libfoo, 'make_point', [types.signed, types.signed], ffi_point)
        #
        PTR = lltype.Ptr(rffi.CArray(rffi.SIGNED))
        p = self.call(make_point, [12, 34], PTR, is_struct=True,
                      jitif=["byval"])
        assert p[0] == 12
        assert p[1] == 34
        lltype.free(p, flavor='raw')
        lltype.free(ffi_point_struct, flavor='raw')

    if os.name == 'nt':
        def test_stdcall_simple(self):
            """
            RPY_EXPORTED
            int __stdcall std_diff_xy(int x, Signed y)
            {
                return x - y;
            }
            """
            libfoo = self.get_libfoo()
            # __stdcall without a DEF file decorates the name with the number of bytes
            # that the callee will remove from the call stack
            # identical to __fastcall for amd64
            if IS_32_BIT:
                f_name = '_std_diff_xy@8'
            else:
                f_name = 'std_diff_xy'
            func = (libfoo, f_name, [types.sint, types.signed], types.sint)
            try:
                res = self.call(func, [50, 8], rffi.INT)
            except ValueError as e:
                assert e.message == 'Procedure called with not enough ' + \
                     'arguments (8 bytes missing) or wrong calling convention'
                assert IS_32_BIT
            except LLException as e:
                #jitted code raises this
                assert str(e) == "<LLException 'StackCheckError'>"
                assert IS_32_BIT
            else:
                if IS_32_BIT:
                    assert 0, 'wrong calling convention should have raised'
                else:
                    assert res == 42

        def test_by_ordinal(self):
            """
            RPY_EXPORTED
            int AAA_first_ordinal_function()
            {
                return 42;
            }
            """
            libfoo = self.get_libfoo()
            f_by_name = libfoo.getpointer('AAA_first_ordinal_function' ,[],
                                          types.sint)
            f_by_ordinal = libfoo.getpointer_by_ordinal(1 ,[], types.sint)
            print dir(f_by_name)
            assert f_by_name.funcsym == f_by_ordinal.funcsym
            chain = ArgChain()
            assert 42 == f_by_ordinal.call(chain, rffi.INT, is_struct=False)

        def test_by_ordinal2(self):
            """
            RPY_EXPORTED
            int __stdcall BBB_second_ordinal_function()
            {
                return 24;
            }
            """
            from rpython.rlib.libffi import WinDLL
            dll = WinDLL(self.libfoo_name)
            # __stdcall without a DEF file decorates the name with the number of bytes
            # that the callee will remove from the call stack
            # identical to __fastcall for amd64
            if IS_32_BIT:
                f_name = '_BBB_second_ordinal_function@0'
            else:
                f_name = 'BBB_second_ordinal_function'
            f_by_name = dll.getpointer(f_name, [], types.sint)
            f_by_ordinal = dll.getpointer_by_ordinal(2 ,[], types.sint)
            print dir(f_by_name)
            assert f_by_name.funcsym == f_by_ordinal.funcsym
            chain = ArgChain()
            assert 24 == f_by_ordinal.call(chain, rffi.INT, is_struct=False)


        
