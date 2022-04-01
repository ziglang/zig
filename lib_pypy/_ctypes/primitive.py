from _rawffi import alt as _ffi
import _rawffi
import weakref
import sys

SIMPLE_TYPE_CHARS = "cbBhHiIlLdfguzZqQPXOv?"

from _ctypes.basics import (
    _CData, _CDataMeta, cdata_from_address, CArgObject, sizeof)
from _ctypes.builtin import ConvMode
from _ctypes.array import Array, byteorder
from _ctypes.pointer import _Pointer, as_ffi_pointer

class NULL(object):
    pass
NULL = NULL()

TP_TO_DEFAULT = {
        'c': 0,
        'u': 0,
        'b': 0,
        'B': 0,
        'h': 0,
        'H': 0,
        'i': 0,
        'I': 0,
        'l': 0,
        'L': 0,
        'q': 0,
        'Q': 0,
        'f': 0.0,
        'd': 0.0,
        'g': 0.0,
        'P': None,
        # not part of struct
        'O': NULL,
        'z': None,
        'Z': None,
        '?': False,
        'v': 0,
}

if sys.platform == 'win32':
    TP_TO_DEFAULT['X'] = NULL

DEFAULT_VALUE = object()

class GlobalPyobjContainer(object):
    def __init__(self):
        self.objs = []

    def add(self, obj):
        num = len(self.objs)
        self.objs.append(weakref.ref(obj))
        return num

    def get(self, num):
        return self.objs[num]()

pyobj_container = GlobalPyobjContainer()

def swap_bytes(value, sizeof, typeof, get_or_set):
    def swap_2():
        return ((value >> 8) & 0x00FF) | ((value << 8) & 0xFF00)

    def swap_4():
        return ((value & 0x000000FF) << 24) | \
               ((value & 0x0000FF00) << 8) | \
               ((value & 0x00FF0000) >> 8) | \
               ((value >> 24) & 0xFF)

    def swap_8():
        return ((value & 0x00000000000000FF) << 56) | \
               ((value & 0x000000000000FF00) << 40) | \
               ((value & 0x0000000000FF0000) << 24) | \
               ((value & 0x00000000FF000000) << 8) | \
               ((value & 0x000000FF00000000) >> 8) | \
               ((value & 0x0000FF0000000000) >> 24) | \
               ((value & 0x00FF000000000000) >> 40) | \
               ((value >> 56) & 0xFF)

    def swap_double_float(typ):
        from struct import pack, unpack
        if get_or_set == 'set':
            if sys.byteorder == 'little':
                st = pack(''.join(['>', typ]), value)
            else:
                st = pack(''.join(['<', typ]), value)
            return unpack(typ, st)[0]
        else:
            packed = pack(typ, value)
            if sys.byteorder == 'little':
                st = unpack(''.join(['>', typ]), packed)
            else:
                st = unpack(''.join(['<', typ]), packed)
            return st[0]

    if typeof in ('c_float', 'c_float_le', 'c_float_be'):
        return swap_double_float('f')
    elif typeof in ('c_double', 'c_double_le', 'c_double_be'):
        return swap_double_float('d')
    else:
        if sizeof == 2:
            return swap_2()
        elif sizeof == 4:
            return swap_4()
        elif sizeof == 8:
            return swap_8()

def generic_xxx_p_from_param(cls, value):
    if value is None:
        return cls(None)
    if isinstance(value, (str, bytes)):
        return cls(value)
    if isinstance(value, _SimpleCData) and \
           type(value)._type_ in 'zZP':
        return value
    return None # eventually raise

def from_param_char_p(cls, value):
    "used by c_char_p and c_wchar_p subclasses"
    res = generic_xxx_p_from_param(cls, value)
    if res is not None:
        return res
    if isinstance(value, (Array, _Pointer)):
        from ctypes import c_char, c_byte, c_wchar
        if type(value)._type_ in [c_char, c_byte, c_wchar]:
            return value

def from_param_void_p(cls, value):
    "used by c_void_p subclasses"
    from _ctypes.function import CFuncPtr
    res = generic_xxx_p_from_param(cls, value)
    if res is not None:
        return res
    if isinstance(value, Array):
        return value
    if isinstance(value, (_Pointer, CFuncPtr)):
        return cls.from_address(value._buffer.buffer)
    if isinstance(value, int):
        return cls(value)

FROM_PARAM_BY_TYPE = {
    'z': from_param_char_p,
    'Z': from_param_char_p,
    'P': from_param_void_p,
    }

CTYPES_TO_PEP3118_TABLE = {
    'i': {2: 'h', 4: 'i', 8: 'q'},
    'I': {2: 'H', 4: 'I', 8: 'Q'},
    'l': {4: 'l', 8: 'q'},
    'L': {4: 'L', 8: 'Q'},
    '?': {1: '?', 2: 'h', 4: 'l', 8: 'q'},
}

class SimpleType(_CDataMeta):
    def __new__(self, name, bases, dct):
        try:
            tp = dct['_type_']
        except KeyError:
            for base in bases:
                if hasattr(base, '_type_'):
                    tp = base._type_
                    break
            else:
                raise AttributeError("cannot find _type_ attribute")
        if tp == 'abstract':
            tp = 'i'
        if (not isinstance(tp, str) or
            not len(tp) == 1 or
            tp not in SIMPLE_TYPE_CHARS):
            raise ValueError('%s is not a type character' % (tp))
        default = TP_TO_DEFAULT[tp]
        ffiarray = _rawffi.Array(tp)
        result = type.__new__(self, name, bases, dct)
        result._ffiargshape_ = tp
        result._ffishape_ = tp
        result._fficompositesize_ = None
        result._ffiarray = ffiarray
        if tp in CTYPES_TO_PEP3118_TABLE:
            pep_code = CTYPES_TO_PEP3118_TABLE[tp][_rawffi.sizeof(tp)]
        else:
            pep_code = tp
        result._format = byteorder[sys.byteorder] + pep_code
        if tp == 'z':
            # c_char_p
            def _getvalue(self):
                addr = self._buffer[0]
                if addr == 0:
                    return None
                else:
                    return _rawffi.charp2string(addr)

            def _setvalue(self, value):
                if isinstance(value, bytes):
                    #self._objects = value
                    array = _rawffi.Array('c')(len(value)+1, value)
                    self._objects = CArgObject(value, array)
                    value = array.buffer
                elif value is None:
                    value = 0
                self._buffer[0] = value
            result.value = property(_getvalue, _setvalue)
            result._ffiargtype = _ffi.types.Pointer(_ffi.types.char)

        elif tp == 'Z':
            # c_wchar_p
            def _getvalue(self):
                addr = self._buffer[0]
                if addr == 0:
                    return None
                else:
                    return _rawffi.wcharp2unicode(addr)

            def _setvalue(self, value):
                if isinstance(value, str):
                    #self._objects = value
                    array = _rawffi.Array('u')(len(value)+1, value)
                    self._objects = CArgObject(value, array)
                    value = array.buffer
                elif value is None:
                    value = 0
                self._buffer[0] = value
            result.value = property(_getvalue, _setvalue)
            result._ffiargtype = _ffi.types.Pointer(_ffi.types.unichar)

        elif tp == 'P':
            # c_void_p

            def _getvalue(self):
                addr = self._buffer[0]
                if addr == 0:
                    return None
                return addr

            def _setvalue(self, value):
                if isinstance(value, bytes):
                    array = _rawffi.Array('c')(len(value)+1, value)
                    self._objects = CArgObject(value, array)
                    value = array.buffer
                elif value is None:
                    value = 0
                self._buffer[0] = value
            result.value = property(_getvalue, _setvalue)

        elif tp == 'u':
            def _setvalue(self, val):
                if val:
                    self._buffer[0] = val
            def _getvalue(self):
                return self._buffer[0]
            result.value = property(_getvalue, _setvalue)

        elif tp == 'c':
            def _setvalue(self, val):
                if val:
                    self._buffer[0] = val
            def _getvalue(self):
                return self._buffer[0]
            result.value = property(_getvalue, _setvalue)

        elif tp == 'O':
            def _setvalue(self, val):
                num = pyobj_container.add(val)
                self._buffer[0] = num
            def _getvalue(self):
                return pyobj_container.get(self._buffer[0])
            result.value = property(_getvalue, _setvalue)

        elif tp == 'X':
            from ctypes import WinDLL
            # Use WinDLL("oleaut32") instead of windll.oleaut32
            # because the latter is a shared (cached) object; and
            # other code may set their own restypes. We need out own
            # restype here.
            oleaut32 = WinDLL("oleaut32")
            import ctypes
            SysAllocStringLen = oleaut32.SysAllocStringLen
            SysStringLen = oleaut32.SysStringLen
            SysFreeString = oleaut32.SysFreeString
            if ctypes.sizeof(ctypes.c_void_p) == 4:
                ptype = ctypes.c_int
            else:
                ptype = ctypes.c_longlong
            SysAllocStringLen.argtypes=[ptype, ctypes.c_uint]
            SysAllocStringLen.restype = ptype
            SysStringLen.argtypes=[ptype]
            SysStringLen.restype = ctypes.c_uint
            SysFreeString.argtypes=[ptype]
            def _getvalue(self):
                addr = self._buffer[0]
                if addr == 0:
                    return None
                else:
                    size = SysStringLen(addr)
                    return _rawffi.wcharp2rawunicode(addr, size)

            def _setvalue(self, value):
                if isinstance(value, (str, bytes)):
                    if isinstance(value, bytes):
                        value = value.decode(ConvMode.encoding,
                                             ConvMode.errors)
                    array = _rawffi.Array('u')(len(value)+1, value)
                    value = SysAllocStringLen(array.buffer, len(value))
                elif value is None:
                    value = 0
                if self._buffer[0]:
                    SysFreeString(self._buffer[0])
                self._buffer[0] = value
            result.value = property(_getvalue, _setvalue)

        elif tp == '?':  # regular bool
            def _getvalue(self):
                return bool(self._buffer[0])
            def _setvalue(self, value):
                self._buffer[0] = bool(value)
            result.value = property(_getvalue, _setvalue)

        elif tp == 'v': # VARIANT_BOOL type
            def _getvalue(self):
                return bool(self._buffer[0])
            def _setvalue(self, value):
                if value:
                    self._buffer[0] = -1 # VARIANT_TRUE
                else:
                    self._buffer[0] = 0  # VARIANT_FALSE
            result.value = property(_getvalue, _setvalue)

        # make pointer-types compatible with the _ffi fast path
        if result._is_pointer_like():
            def _as_ffi_pointer_(self, ffitype):
                return as_ffi_pointer(self, ffitype)
            result._as_ffi_pointer_ = _as_ffi_pointer_
        if name[-2:] != '_p' and name[-3:] not in ('_le', '_be') \
                and name not in ('c_wchar', '_SimpleCData', 'c_longdouble', 'c_bool', 'py_object'):
            if sys.byteorder == 'big':
                name += '_le'
                swapped = self.__new__(self, name, bases, dct)
                result.__ctype_le__ = swapped
                result.__ctype_be__ = result
                swapped.__ctype_be__ = result
                swapped.__ctype_le__ = swapped
                swapped._format = '<' + pep_code
            else:
                name += '_be'
                swapped = self.__new__(self, name, bases, dct)
                result.__ctype_be__ = swapped
                result.__ctype_le__ = result
                swapped.__ctype_le__ = result
                swapped.__ctype_be__ = swapped
                swapped._format = '>' + pep_code
            from _ctypes import sizeof
            def _getval(self):
                return swap_bytes(self._buffer[0], sizeof(self), name, 'get')
            def _setval(self, value):
                d = result()
                d.value = value
                self._buffer[0] = swap_bytes(d.value, sizeof(self), name, 'set')
            swapped.value = property(_getval, _setval)

        return result

    from_address = cdata_from_address

    def from_param(self, value):
        if isinstance(value, self):
            return value
        if self._type_ == 'abstract':
            raise TypeError('abstract class')
        from_param_f = FROM_PARAM_BY_TYPE.get(self._type_)
        if from_param_f:
            res = from_param_f(self, value)
            if res is not None:
                return res
        else:
            try:
                return self(value)
            except (TypeError, ValueError):
                pass

        return super(SimpleType, self).from_param(value)

    def _CData_output(self, resbuffer, base=None, index=-1):
        output = super(SimpleType, self)._CData_output(resbuffer, base, index)
        if self.__bases__[0] is _SimpleCData:
            return output.value
        return output

    def _sizeofinstances(self):
        return _rawffi.sizeof(self._type_)

    def _alignmentofinstances(self):
        return _rawffi.alignment(self._type_)

    def _is_pointer_like(self):
        return self._type_ in "sPzUZXO"

    def _getformat(self):
        return self._format

class _SimpleCData(_CData, metaclass=SimpleType):
    _type_ = 'abstract'

    def __init__(self, value=DEFAULT_VALUE):
        if not hasattr(self, '_buffer'):
            self._buffer = self._ffiarray(1, autofree=True)
        if value is not DEFAULT_VALUE:
            self.value = value
    _init_no_arg_ = __init__

    def _ensure_objects(self):
        # No '_objects' is the common case for primitives.  Examples
        # where there is an _objects is if _type in 'zZP', or if
        # self comes from 'from_buffer(buf)'.  See module/test_lib_pypy/
        # ctypes_test/test_buffers.py: test_from_buffer_keepalive.
        return getattr(self, '_objects', None)

    def _getvalue(self):
        return self._buffer[0]

    def _setvalue(self, value):
        self._buffer[0] = value
    value = property(_getvalue, _setvalue)
    del _getvalue, _setvalue

    def __ctypes_from_outparam__(self):
        meta = type(type(self))
        if issubclass(meta, SimpleType) and meta != SimpleType:
            return self

        return self.value

    def __repr__(self):
        if type(self).__bases__[0] is _SimpleCData:
            return "%s(%r)" % (type(self).__name__, self.value)
        else:
            return "<%s object at 0x%x>" % (type(self).__name__,
                                            id(self))

    def __bool__(self):
        return self._buffer[0] not in (0, b'\x00')
