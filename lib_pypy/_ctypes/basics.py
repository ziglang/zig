import _rawffi
from _rawffi import alt as _ffi
from __pypy__ import newmemoryview
import sys

try:
    from __pypy__ import builtinify
except ImportError:
    builtinify = lambda f: f

try:
    from __pypy__.bufferable import bufferable
except ImportError:
    bufferable = object

keepalive_key = str # XXX fix this when provided with test

def ensure_objects(where):
    try:
        ensure = where._ensure_objects
    except AttributeError:
        return None
    return ensure()

def store_reference(where, base_key, target):
    if '_index' not in where.__dict__:
        # shortcut
        where._ensure_objects()[str(base_key)] = target
        return
    key = [base_key]
    while '_index' in where.__dict__:
        key.append(where.__dict__['_index'])
        where = where.__dict__['_base']
    real_key = ":".join([str(i) for i in key])
    where._ensure_objects()[real_key] = target

class ArgumentError(Exception):
    pass

class COMError(Exception):
    "Raised when a COM method call failed."
    def __init__(self, hresult, text, details):
        self.args = (hresult, text, details)
        self.hresult = hresult
        self.text = text
        self.details = details

class _CDataMeta(type):
    def _is_abstract(self):
        return getattr(self, '_type_', 'abstract') == 'abstract'

    def from_param(self, value):
        if isinstance(value, self):
            return value
        try:
            as_parameter = value._as_parameter_
        except AttributeError:
            raise TypeError("expected %s instance instead of %s" % (
                self.__name__, type(value).__name__))
        else:
            return self.from_param(as_parameter)

    def _build_ffiargtype(self):
        return _shape_to_ffi_type(self._ffiargshape_)

    def get_ffi_argtype(self):
        if self._ffiargtype:
            return self._ffiargtype
        self._ffiargtype = self._build_ffiargtype()
        return self._ffiargtype

    def _CData_output(self, resbuffer, base=None, index=-1):
        #assert isinstance(resbuffer, _rawffi.ArrayInstance)
        """Used when data exits ctypes and goes into user code.
        'resbuffer' is a _rawffi array of length 1 containing the value,
        and this returns a general Python object that corresponds.
        """
        res = bufferable.__new__(self)
        res.__class__ = self
        res.__dict__['_buffer'] = resbuffer
        if base is not None:
            res.__dict__['_base'] = base
            res.__dict__['_index'] = index
        return res

    def _CData_retval(self, resbuffer):
        return self._CData_output(resbuffer)

    def __mul__(self, other):
        from _ctypes.array import create_array_type
        return create_array_type(self, other)

    __rmul__ = __mul__

    def _is_pointer_like(self):
        return False

    def in_dll(self, dll, name):
        return self.from_address(dll.__pypy_dll__.getaddressindll(name))

    def from_buffer(self, obj, offset=0):
        if self._is_abstract():
            raise TypeError('abstract class')
        size = self._sizeofinstances()
        buf = memoryview(obj)
        if buf.nbytes < offset + size:
            raise ValueError(
                "Buffer size too small (%d instead of at least %d bytes)"
                % (buf.nbytes, offset + size))
        raw_addr = buf._pypy_raw_address() + offset
        result = self.from_address(raw_addr)
        objects = result._ensure_objects()
        if objects is not None:
            objects['ffffffff'] = obj
        else:   # case e.g. of a primitive type like c_int
            result._objects = obj
        return result

    def from_buffer_copy(self, obj, offset=0):
        if self._is_abstract():
            raise TypeError('abstract class')
        size = self._sizeofinstances()
        buf = memoryview(obj)
        if buf.nbytes < offset + size:
            raise ValueError(
                "Buffer size too small (%d instead of at least %d bytes)"
                % (buf.nbytes, offset + size))
        result = self._newowninstance_()
        dest = result._buffer.buffer
        try:
            raw_addr = buf._pypy_raw_address() + offset
        except ValueError:
            _rawffi.rawstring2charp(dest, buf, offset, size)
        else:
            from ctypes import memmove
            memmove(dest, raw_addr, size)
        return result

    def _newowninstance_(self):
        result = self.__new__(self)
        result._init_no_arg_()
        return result

    def _getformat(self):
        raise ValueError('cannot get format string for %r' % self)


class CArgObject(object):
    """ simple wrapper around buffer, just for the case of freeing
    it afterwards
    """
    def __init__(self, obj, buffer):
        self._obj = obj
        self._buffer = buffer

    def __del__(self):
        self._buffer.free()
        self._buffer = None

    def __repr__(self):
        return '<CArgObject %r>' % (self._obj,)

    def __eq__(self, other):
        return self._obj == other

    def __ne__(self, other):
        return self._obj != other

class _CData(bufferable, metaclass=_CDataMeta):
    """ The most basic object for all ctypes types
    """
    _objects = None
    _ffiargtype = None

    def __init__(self, *args, **kwds):
        raise TypeError("%s has no type" % (type(self),))
    _init_no_arg_ = __init__

    def _ensure_objects(self):
        if '_objects' not in self.__dict__:
            if '_index' in self.__dict__:
                return None
            self.__dict__['_objects'] = {}
        return self._objects

    def __ctypes_from_outparam__(self):
        return self

    def _get_buffer_for_param(self):
        return self

    def _get_buffer_value(self):
        return self._buffer[0]

    def _copy_to(self, addr):
        target = type(self).from_address(addr)._buffer
        target[0] = self._get_buffer_value()

    def _to_ffi_param(self):
        if self.__class__._is_pointer_like():
            return self._get_buffer_value()
        else:
            return self.value

    def __buffer__(self, flags):
        rawview = memoryview(self._buffer)
        fmt = type(self)._getformat()
        itemsize = sizeof(type(self))
        return newmemoryview(rawview, itemsize, fmt, ())

    def _get_b_base(self):
        try:
            return self._base
        except AttributeError:
            return None
    _b_base_ = property(_get_b_base)
    _b_needsfree_ = False

@builtinify
def sizeof(tp):
    if not isinstance(tp, _CDataMeta):
        if isinstance(tp, _CData):
            tp = type(tp)
        else:
            raise TypeError("ctypes type or instance expected, got %r" % (
                type(tp).__name__,))
    return tp._sizeofinstances()

@builtinify
def alignment(tp):
    if not isinstance(tp, _CDataMeta):
        if isinstance(tp, _CData):
            tp = type(tp)
        else:
            raise TypeError("ctypes type or instance expected, got %r" % (
                type(tp).__name__,))
    return tp._alignmentofinstances()

@builtinify
def byref(cdata, offset=0):
    from _ctypes.pointer import pointer
    ptr = pointer(cdata)
    if offset != 0:
        ptr._buffer[0] += offset
    return ptr

def cdata_from_address(self, address):
    # fix the address: turn it into as unsigned, in case it's a negative number
    address = address & (sys.maxsize * 2 + 1)
    instance = self.__new__(self)
    lgt = getattr(self, '_length_', 1)
    instance._buffer = self._ffiarray.fromaddress(address, lgt)
    return instance

@builtinify
def addressof(tp):
    return tp._buffer.buffer


# ----------------------------------------------------------------------

def is_struct_shape(shape):
    # see the corresponding code to set the shape in
    # _ctypes.structure._set_shape
    return (isinstance(shape, tuple) and
            len(shape) == 2 and
            isinstance(shape[0], _rawffi.Structure) and
            shape[1] == 1)

def _shape_to_ffi_type(shape):
    try:
        return _shape_to_ffi_type.typemap[shape]
    except KeyError:
        pass
    if is_struct_shape(shape):
        return shape[0].get_ffi_type()
    #
    assert False, 'unknown shape %s' % (shape,)


_shape_to_ffi_type.typemap =  {
    'c' : _ffi.types.char,
    'b' : _ffi.types.sbyte,
    'B' : _ffi.types.ubyte,
    'h' : _ffi.types.sshort,
    'u' : _ffi.types.unichar,
    'H' : _ffi.types.ushort,
    'i' : _ffi.types.sint,
    'I' : _ffi.types.uint,
    'l' : _ffi.types.slong,
    'L' : _ffi.types.ulong,
    'q' : _ffi.types.slonglong,
    'Q' : _ffi.types.ulonglong,
    'f' : _ffi.types.float,
    'd' : _ffi.types.double,
    's' : _ffi.types.void_p,
    'P' : _ffi.types.void_p,
    'z' : _ffi.types.void_p,
    'O' : _ffi.types.void_p,
    'Z' : _ffi.types.void_p,
    'X' : _ffi.types.void_p,
    'v' : _ffi.types.sshort,
    '?' : _ffi.types.ubyte,
    }


# called from primitive.py, pointer.py, array.py
def as_ffi_pointer(value, ffitype):
    my_ffitype = type(value).get_ffi_argtype()
    # for now, we always allow types.pointer, else a lot of tests
    # break. We need to rethink how pointers are represented, though
    if my_ffitype is not ffitype and ffitype is not _ffi.types.void_p:
        raise ArgumentError("expected %s instance, got %s" % (type(value),
                                                              ffitype))
    return value._get_buffer_value()
