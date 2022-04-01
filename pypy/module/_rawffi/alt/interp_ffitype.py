from rpython.rlib import libffi, clibffi
from rpython.rlib.rarithmetic import intmask
from rpython.rlib import jit
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef, interp_attrproperty
from pypy.interpreter.gateway import interp2app
from pypy.interpreter.error import oefmt


class W_FFIType(W_Root):
    _immutable_fields_ = ['name', 'w_structdescr', 'w_pointer_to']

    def __init__(self, name, ffitype, w_structdescr=None, w_pointer_to=None):
        self.name = name
        self._ffitype = clibffi.FFI_TYPE_NULL
        self.w_structdescr = w_structdescr
        self.w_pointer_to = w_pointer_to
        self.set_ffitype(ffitype)

    @jit.elidable
    def get_ffitype(self):
        if not self._ffitype:
            raise ValueError("Operation not permitted on an incomplete type")
        return self._ffitype

    def set_ffitype(self, ffitype):
        if self._ffitype:
            raise ValueError("The _ffitype is already set")
        self._ffitype = ffitype
        if ffitype and self.is_struct():
            assert self.w_structdescr is not None

    def descr_deref_pointer(self, space):
        if self.w_pointer_to is None:
            return space.w_None
        return self.w_pointer_to

    def descr_sizeof(self, space):
        try:
            return space.newint(self.sizeof())
        except ValueError:
            raise oefmt(space.w_ValueError,
                        "Operation not permitted on an incomplete type")

    def sizeof(self):
        return intmask(self.get_ffitype().c_size)

    def get_alignment(self):
        return intmask(self.get_ffitype().c_alignment)

    def repr(self, space):
        return space.newtext(self.__repr__())

    def __repr__(self):
        name = self.name
        if not self._ffitype:
            name += ' (incomplete)'
        return "<ffi type %s>" % name

    def is_signed(self):
        return (self is app_types.slong or
                self is app_types.sint or
                self is app_types.sshort or
                self is app_types.sbyte or
                self is app_types.slonglong)

    def is_unsigned(self):
        return (self is app_types.ulong or
                self is app_types.uint or
                self is app_types.ushort or
                self is app_types.ubyte or
                self is app_types.ulonglong)

    def is_pointer(self):
        return self.get_ffitype() is libffi.types.pointer

    def is_char(self):
        return self is app_types.char

    def is_unichar(self):
        return self is app_types.unichar

    def is_longlong(self):
        return libffi.IS_32_BIT and (self is app_types.slonglong or
                                     self is app_types.ulonglong)

    def is_double(self):
        return self is app_types.double

    def is_singlefloat(self):
        return self is app_types.float

    def is_void(self):
        return self is app_types.void

    def is_struct(self):
        return libffi.types.is_struct(self.get_ffitype())

    def is_char_p(self):
        return self is app_types.char_p

    def is_unichar_p(self):
        return self is app_types.unichar_p


W_FFIType.typedef = TypeDef(
    'FFIType',
    name = interp_attrproperty('name', W_FFIType,
        wrapfn="newtext_or_none"),
    __repr__ = interp2app(W_FFIType.repr),
    deref_pointer = interp2app(W_FFIType.descr_deref_pointer),
    sizeof = interp2app(W_FFIType.descr_sizeof),
    )


def build_ffi_types():
    types = [
        # note: most of the type name directly come from the C equivalent,
        # with the exception of bytes: in C, ubyte and char are equivalent,
        # but for here the first expects a number while the second a 1-length
        # string
        W_FFIType('slong',     libffi.types.slong),
        W_FFIType('sint',      libffi.types.sint),
        W_FFIType('sshort',    libffi.types.sshort),
        W_FFIType('sbyte',     libffi.types.schar),
        W_FFIType('slonglong', libffi.types.slonglong),
        #
        W_FFIType('ulong',     libffi.types.ulong),
        W_FFIType('uint',      libffi.types.uint),
        W_FFIType('ushort',    libffi.types.ushort),
        W_FFIType('ubyte',     libffi.types.uchar),
        W_FFIType('ulonglong', libffi.types.ulonglong),
        #
        W_FFIType('char',      libffi.types.uchar),
        W_FFIType('unichar',   libffi.types.wchar_t),
        #
        W_FFIType('double',    libffi.types.double),
        W_FFIType('float',     libffi.types.float),
        W_FFIType('void',      libffi.types.void),
        W_FFIType('void_p',    libffi.types.pointer),
        #
        # missing types:

        ## 's' : ffi_type_pointer,
        ## 'z' : ffi_type_pointer,
        ## 'O' : ffi_type_pointer,
        ## 'Z' : ffi_type_pointer,

        ]
    d = dict([(t.name, t) for t in types])
    w_char = d['char']
    w_unichar = d['unichar']
    d['char_p'] = W_FFIType('char_p', libffi.types.pointer, w_pointer_to = w_char)
    d['unichar_p'] = W_FFIType('unichar_p', libffi.types.pointer, w_pointer_to = w_unichar)
    return d

class app_types:
    pass
app_types.__dict__ = build_ffi_types()


def descr_new_pointer(space, w_cls, w_pointer_to):
    try:
        return descr_new_pointer.cache[w_pointer_to]
    except KeyError:
        if w_pointer_to is app_types.char:
            w_result = app_types.char_p
        elif w_pointer_to is app_types.unichar:
            w_result = app_types.unichar_p
        else:
            w_pointer_to = space.interp_w(W_FFIType, w_pointer_to)
            name = '(pointer to %s)' % w_pointer_to.name
            w_result = W_FFIType(name, libffi.types.pointer, w_pointer_to=w_pointer_to)
        descr_new_pointer.cache[w_pointer_to] = w_result
        return w_result
descr_new_pointer.cache = {}


class W_types(W_Root):
    pass
W_types.typedef = TypeDef(
    'types',
    Pointer = interp2app(descr_new_pointer, as_classmethod=True),
    **app_types.__dict__)
