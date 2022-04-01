import sys
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.module._rawffi.alt.interp_ffitype import app_types, W_FFIType
from pypy.module._rawffi.alt.interp_struct import compute_size_and_alignement, W_Field
from pypy.module._rawffi.alt.test.test_funcptr import BaseAppTestFFI

class TestStruct(object):

    class FakeSpace(object):
        def interp_w(self, cls, obj):
            return obj

    def compute(self, ffitypes_w):
        fields_w = [W_Field('<dummy>', w_ffitype) for
                    w_ffitype in ffitypes_w]
        return compute_size_and_alignement(self.FakeSpace(), fields_w)

    def sizeof(self, ffitypes_w):
        size, aligned, fields_w = self.compute(ffitypes_w)
        return size

    def test_compute_size(self):
        T = app_types
        byte_size = app_types.sbyte.sizeof()
        long_size = app_types.slong.sizeof()
        llong_size = app_types.slonglong.sizeof()
        llong_align = app_types.slonglong.get_alignment()
        #
        assert llong_align >= 4
        assert self.sizeof([T.sbyte, T.slong]) == 2*long_size
        assert self.sizeof([T.sbyte, T.slonglong]) == llong_align + llong_size
        assert self.sizeof([T.sbyte, T.sbyte, T.slonglong]) == llong_align + llong_size
        assert self.sizeof([T.sbyte, T.sbyte, T.sbyte, T.slonglong]) == llong_align + llong_size
        assert self.sizeof([T.sbyte, T.sbyte, T.sbyte, T.sbyte, T.slonglong]) == llong_align + llong_size
        assert self.sizeof([T.slonglong, T.sbyte]) == llong_size + llong_align
        assert self.sizeof([T.slonglong, T.sbyte, T.sbyte]) == llong_size + llong_align
        assert self.sizeof([T.slonglong, T.sbyte, T.sbyte, T.sbyte]) == llong_size + llong_align
        assert self.sizeof([T.slonglong, T.sbyte, T.sbyte, T.sbyte, T.sbyte]) == llong_size + llong_align


class AppTestStruct(BaseAppTestFFI):

    @classmethod
    def read_raw_mem(cls, addr, typename, length):
        import ctypes
        addr = ctypes.cast(addr, ctypes.c_void_p)
        c_type = getattr(ctypes, typename)
        array_type = ctypes.POINTER(c_type * length)
        ptr_array = ctypes.cast(addr, array_type)
        array = ptr_array[0]
        lst = [array[i] for i in range(length)]
        return lst

    def setup_class(cls):
        BaseAppTestFFI.setup_class.im_func(cls)

        from rpython.rlib import clibffi
        from rpython.rlib.rarithmetic import r_uint
        from rpython.rtyper.lltypesystem import lltype, rffi

        if cls.runappdirect:
            cls.w_read_raw_mem = cls.read_raw_mem
        else:
            @unwrap_spec(addr=r_uint, typename='text', length=int)
            def read_raw_mem_w(space, addr, typename, length):
                return space.wrap(cls.read_raw_mem(addr, typename, length))
            cls.w_read_raw_mem = cls.space.wrap(interp2app(read_raw_mem_w))
        #
        dummy_type = lltype.malloc(clibffi.FFI_TYPE_P.TO, flavor='raw')
        dummy_type.c_size = r_uint(123)
        dummy_type.c_alignment = rffi.cast(rffi.USHORT, 0)
        dummy_type.c_type = rffi.cast(rffi.USHORT, 0)
        cls.w_dummy_type = W_FFIType('dummy', dummy_type)
        cls.w_runappdirect = cls.space.wrap(cls.runappdirect)
        
    def test__StructDescr(self):
        from _rawffi.alt import _StructDescr, Field, types
        longsize = types.slong.sizeof()
        fields = [
            Field('x', types.slong),
            Field('y', types.slong),
            ]
        descr = _StructDescr('foo', fields)
        assert descr.ffitype.sizeof() == longsize*2
        assert descr.ffitype.name == 'struct foo'

    def test_alignment(self):
        from _rawffi.alt import _StructDescr, Field, types
        longsize = types.slong.sizeof()
        fields = [
            Field('x', types.sbyte),
            Field('y', types.slong),
            ]
        descr = _StructDescr('foo', fields)
        assert descr.ffitype.sizeof() == longsize*2
        assert fields[0].offset == 0
        assert fields[1].offset == longsize # aligned to WORD

    def test_missing_field(self):
        from _rawffi.alt import _StructDescr, Field, types
        longsize = types.slong.sizeof()
        fields = [
            Field('x', types.slong),
            Field('y', types.slong),
            ]
        descr = _StructDescr('foo', fields)
        struct = descr.allocate()
        raises(AttributeError, "struct.getfield('missing')")
        raises(AttributeError, "struct.setfield('missing', 42)")

    def test_unknown_type(self):
        if self.runappdirect:
            skip('cannot use self.dummy_type with -A')
        from _rawffi.alt import _StructDescr, Field
        fields = [
            Field('x', self.dummy_type),
            ]
        descr = _StructDescr('foo', fields)
        struct = descr.allocate()
        raises(TypeError, "struct.getfield('x')")
        raises(TypeError, "struct.setfield('x', 42)")

    def test_getfield_setfield(self):
        from _rawffi.alt import _StructDescr, Field, types
        longsize = types.slong.sizeof()
        fields = [
            Field('x', types.slong),
            Field('y', types.slong),
            ]
        descr = _StructDescr('foo', fields)
        struct = descr.allocate()
        struct.setfield('x', 42)
        struct.setfield('y', 43)
        assert struct.getfield('x') == 42
        assert struct.getfield('y') == 43
        mem = self.read_raw_mem(struct.getaddr(), 'c_long', 2)
        assert mem == [42, 43]

    def test_getfield_setfield_signed_types(self):
        import sys
        from _rawffi.alt import _StructDescr, Field, types
        if sys.platform == 'win32':
            maxlong = 2 ** 31 - 1
        else:
            maxlong = sys.maxsize
        fields = [
            Field('sbyte', types.sbyte),
            Field('sshort', types.sshort),
            Field('sint', types.sint),
            Field('slong', types.slong),
            ]
        descr = _StructDescr('foo', fields)
        struct = descr.allocate()
        struct.setfield('sbyte', 128)
        assert struct.getfield('sbyte') == -128
        struct.setfield('sshort', 32768)
        assert struct.getfield('sshort') == -32768
        struct.setfield('sint', 43)
        assert struct.getfield('sint') == 43
        struct.setfield('slong', maxlong + 1)
        assert struct.getfield('slong') == -maxlong - 1
        struct.setfield('slong', maxlong * 3)
        assert struct.getfield('slong') == maxlong - 2

    def test_getfield_setfield_unsigned_types(self):
        import sys
        from _rawffi.alt import _StructDescr, Field, types
        longsize = types.slong.sizeof()
        if sys.platform == 'win32':
            maxlong = 2 ** 31 - 1
        else:
            maxlong = sys.maxsize
        fields = [
            Field('ubyte', types.ubyte),
            Field('ushort', types.ushort),
            Field('uint', types.uint),
            Field('ulong', types.ulong),
            Field('char', types.char),
            Field('unichar', types.unichar),
            Field('ptr', types.void_p),
            ]
        descr = _StructDescr('foo', fields)
        struct = descr.allocate()
        struct.setfield('ubyte', -1)
        assert struct.getfield('ubyte') == 255
        struct.setfield('ushort', -1)
        assert struct.getfield('ushort') == 65535
        struct.setfield('uint', 43)
        assert struct.getfield('uint') == 43
        struct.setfield('ulong', -1)
        assert struct.getfield('ulong') == maxlong * 2 + 1
        struct.setfield('ulong', maxlong * 2 + 2)
        assert struct.getfield('ulong') == 0
        struct.setfield('char', b'a')
        assert struct.getfield('char') == b'a'
        struct.setfield('unichar', u'\u1234')
        assert struct.getfield('unichar') == u'\u1234'
        struct.setfield('ptr', -1)
        assert struct.getfield('ptr') == sys.maxsize * 2 + 1
    
    def test_getfield_setfield_longlong(self):
        import sys
        from _rawffi.alt import _StructDescr, Field, types
        fields = [
            Field('slonglong', types.slonglong),
            Field('ulonglong', types.ulonglong),
            ]
        descr = _StructDescr('foo', fields)
        struct = descr.allocate()
        struct.setfield('slonglong', 9223372036854775808)
        assert struct.getfield('slonglong') == -9223372036854775808
        struct.setfield('ulonglong', -1)
        assert struct.getfield('ulonglong') == 18446744073709551615        
        mem = self.read_raw_mem(struct.getaddr(), 'c_longlong', 2)
        assert mem == [-9223372036854775808, -1]

    def test_getfield_setfield_float(self):
        import sys
        from _rawffi.alt import _StructDescr, Field, types
        fields = [
            Field('x', types.double),
            ]
        descr = _StructDescr('foo', fields)
        struct = descr.allocate()
        struct.setfield('x', 123.4)
        assert struct.getfield('x') == 123.4
        mem = self.read_raw_mem(struct.getaddr(), 'c_double', 1)
        assert mem == [123.4]

    def test_getfield_setfield_singlefloat(self):
        import sys
        from _rawffi.alt import _StructDescr, Field, types
        fields = [
            Field('x', types.float),
            ]
        descr = _StructDescr('foo', fields)
        struct = descr.allocate()
        struct.setfield('x', 123.4) # this is a value which DOES loose
                                    # precision in a single float
        assert 0 < abs(struct.getfield('x') - 123.4) < 0.0001
        #
        struct.setfield('x', 123.5) # this is a value which does not loose
                                    # precision in a single float
        assert struct.getfield('x') == 123.5
        mem = self.read_raw_mem(struct.getaddr(), 'c_float', 1)
        assert mem == [123.5]

    def test_define_fields(self):
        from _rawffi.alt import _StructDescr, Field, types
        longsize = types.slong.sizeof()
        fields = [
            Field('x', types.slong),
            Field('y', types.slong),
            ]
        descr = _StructDescr('foo')
        assert descr.ffitype.name == 'struct foo'
        assert repr(descr.ffitype) == '<ffi type struct foo (incomplete)>'
        raises(ValueError, "descr.ffitype.sizeof()")
        raises(ValueError, "descr.allocate()")
        #
        descr.define_fields(fields)
        assert repr(descr.ffitype) == '<ffi type struct foo>'
        assert descr.ffitype.sizeof() == longsize*2
        raises(ValueError, "descr.define_fields(fields)")

    def test_pointer_to_incomplete_struct(self):
        from _rawffi.alt import _StructDescr, Field, types
        fields = [
            Field('x', types.slong),
            Field('y', types.slong),
            ]
        descr = _StructDescr('foo')
        foo_ffitype = descr.ffitype
        foo_p = types.Pointer(descr.ffitype)
        assert foo_p.deref_pointer() is foo_ffitype
        descr.define_fields(fields)
        assert descr.ffitype is foo_ffitype
        assert foo_p.deref_pointer() is foo_ffitype
        assert types.Pointer(descr.ffitype) is foo_p

    def test_nested_structure(self):
        from _rawffi.alt import _StructDescr, Field, types
        longsize = types.slong.sizeof()
        foo_fields = [
            Field('x', types.slong),
            Field('y', types.slong),
            ]
        foo_descr = _StructDescr('foo', foo_fields)
        #
        bar_fields = [
            Field('x', types.slong),
            Field('foo', foo_descr.ffitype),
            ]
        bar_descr = _StructDescr('bar', bar_fields)
        assert bar_descr.ffitype.sizeof() == longsize*3
        #
        struct = bar_descr.allocate()
        struct.setfield('x', 40)
        # reading a nested structure yields a reference to it
        struct_foo = struct.getfield('foo')
        struct_foo.setfield('x', 41)
        struct_foo.setfield('y', 42)
        mem = self.read_raw_mem(struct.getaddr(), 'c_long', 3)
        assert mem == [40, 41, 42]
        #
        struct_foo2 = foo_descr.allocate()
        struct_foo2.setfield('x', 141)
        struct_foo2.setfield('y', 142)
        # writing a nested structure copies its memory into the target
        struct.setfield('foo', struct_foo2)
        struct_foo2.setfield('x', 241)
        struct_foo2.setfield('y', 242)
        mem = self.read_raw_mem(struct.getaddr(), 'c_long', 3)
        assert mem == [40, 141, 142]
        mem = self.read_raw_mem(struct_foo2.getaddr(), 'c_long', 2)
        assert mem == [241, 242]



    def test_compute_shape(self):
        from _rawffi.alt import Structure, Field, types
        class Point(Structure):
            _fields_ = [
                Field('x', types.slong),
                Field('y', types.slong),
                ]

        longsize = types.slong.sizeof()
        assert isinstance(Point.x, Field)
        assert isinstance(Point.y, Field)
        assert Point.x.offset == 0
        assert Point.y.offset == longsize
        assert Point._struct_.ffitype.sizeof() == longsize*2
        assert Point._struct_.ffitype.name == 'struct Point'

