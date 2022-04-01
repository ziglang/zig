from _rawffi import alt as _ffi
import _rawffi

from _ctypes.basics import _CData, cdata_from_address, _CDataMeta, sizeof
from _ctypes.basics import keepalive_key, store_reference, ensure_objects
from _ctypes.basics import CArgObject, as_ffi_pointer
from _pypy_generic_alias import GenericAlias
import sys, __pypy__, struct

class ArrayMeta(_CDataMeta):
    def __new__(self, name, cls, typedict):
        res = type.__new__(self, name, cls, typedict)

        if cls == (_CData,): # this is the Array class defined below
            res._ffiarray = None
            return res
        if not hasattr(res, '_length_'):
            raise AttributeError(
                "class must define a '_length_' attribute, "
                "which must be a positive integer")
        if not isinstance(res._length_, int):
            raise TypeError("The '_length_' attribute must be an integer")
        if res._length_ < 0:
            raise ValueError("The '_length_' attribute must not be negative")
        ffiarray = res._ffiarray = _rawffi.Array(res._type_._ffishape_)
        subletter = getattr(res._type_, '_type_', None)
        if subletter == 'c':
            def getvalue(self):
                return _rawffi.charp2string(self._buffer.buffer,
                                            self._length_)
            def setvalue(self, val):
                # we don't want to have buffers here
                if len(val) > self._length_:
                    raise ValueError("%r too long" % (val,))
                if isinstance(val, str):
                    _rawffi.rawstring2charp(self._buffer.buffer, val)
                else:
                    for i in range(len(val)):
                        self[i] = val[i]
                if len(val) < self._length_:
                    self._buffer[len(val)] = b'\x00'
            res.value = property(getvalue, setvalue)

            def getraw(self):
                return _rawffi.charp2rawstring(self._buffer.buffer,
                                               self._length_)

            def setraw(self, buffer):
                if len(buffer) > self._length_:
                    raise ValueError("%r too long" % (buffer,))
                _rawffi.rawstring2charp(self._buffer.buffer, buffer)
            res.raw = property(getraw, setraw)
        elif subletter == 'u':
            def getvalue(self):
                return _rawffi.wcharp2unicode(self._buffer.buffer,
                                              self._length_)

            def setvalue(self, val):
                # we don't want to have buffers here
                if len(val) > self._length_:
                    raise ValueError("%r too long" % (val,))
                if isinstance(val, str):
                    target = self._buffer
                else:
                    target = self
                for i in range(len(val)):
                    target[i] = val[i]
                if len(val) < self._length_:
                    target[len(val)] = u'\x00'
            res.value = property(getvalue, setvalue)

        res._ffishape_ = (ffiarray, res._length_)
        res._fficompositesize_ = res._sizeofinstances()
        return res

    from_address = cdata_from_address

    def _sizeofinstances(self):
        if self._ffiarray is None:
            raise TypeError("abstract class")
        size, alignment = self._ffiarray.size_alignment(self._length_)
        return size

    def _alignmentofinstances(self):
        return self._type_._alignmentofinstances()

    def _CData_output(self, resarray, base=None, index=-1):
        from _rawffi.alt import types
        # If a char_p or unichar_p is received, skip the string interpretation
        try:
            deref = type(base)._deref_ffiargtype()
        except AttributeError:
            deref = None
        if deref != types.char_p and deref != types.unichar_p:
            # this seems to be a string if we're array of char, surprise!
            from ctypes import c_char, c_wchar
            if self._type_ is c_char:
                return _rawffi.charp2string(resarray.buffer, self._length_)
            if self._type_ is c_wchar:
                return _rawffi.wcharp2unicode(resarray.buffer, self._length_)
        res = self.__new__(self)
        ffiarray = self._ffiarray.fromaddress(resarray.buffer, self._length_)
        res._buffer = ffiarray
        if base is not None:
            res._base = base
            res._index = index
        return res

    def _CData_retval(self, resbuffer):
        raise NotImplementedError

    def from_param(self, value):
        # array accepts very strange parameters as part of structure
        # or function argument...
        from ctypes import c_char, c_wchar
        if isinstance(value, self):
            return value
        if hasattr(self, '_type_'):
            if issubclass(self._type_, c_char):
                if isinstance(value, bytes):
                    if len(value) > self._length_:
                        raise ValueError("Invalid length")
                    value = self(*value)
                elif not isinstance(value, self):
                    raise TypeError("expected bytes, %s found"
                                    % (value.__class__.__name__,))
            elif issubclass(self._type_, c_wchar):
                if isinstance(value, str):
                    if len(value) > self._length_:
                        raise ValueError("Invalid length")
                    value = self(*value)
                elif not isinstance(value, self):
                    raise TypeError("expected unicode string, %s found"
                                    % (value.__class__.__name__,))
        if isinstance(value, tuple):
            if len(value) > self._length_:
                raise RuntimeError("Invalid length")
            value = self(*value)
        return _CDataMeta.from_param(self, value)

    def _build_ffiargtype(self):
        return _ffi.types.Pointer(self._type_.get_ffi_argtype())

    def _deref_ffiargtype(self):
        return self._type_.get_ffi_argtype()

    def _getformat(self):
        shape = []
        tp = self
        while hasattr(tp, '_length_'):
            shape.append(tp._length_)
            tp = tp._type_
        return "(%s)%s" % (','.join([str(n) for n in shape]), tp._getformat())


def array_get_slice_params(self, index):
    if hasattr(self, '_length_'):
        start, stop, step = index.indices(self._length_)
    else:
        step = index.step
        if step is None:
            step = 1
        start = index.start
        stop = index.stop
        if start is None:
            if step > 0:
                start = 0
            else:
                raise ValueError("slice start is required for step < 0")
        if stop is None:
            raise ValueError("slice stop is required")

    return start, stop, step

def array_slice_setitem(self, index, value):
    start, stop, step = self._get_slice_params(index)

    if ((step < 0 and stop >= start) or
        (step > 0 and start >= stop)):
        slicelength = 0
    elif step < 0:
        slicelength = (stop - start + 1) / step + 1
    else:
        slicelength = (stop - start - 1) / step + 1;

    if slicelength != len(value):
        raise ValueError("Can only assign slices of the same length")
    for i, j in enumerate(range(start, stop, step)):
        self[j] = value[i]

def array_slice_getitem(self, index):
    start, stop, step = self._get_slice_params(index)
    l = [self[i] for i in range(start, stop, step)]
    letter = getattr(self._type_, '_type_', None)
    if letter == 'c':
        return b"".join(l)
    if letter == 'u':
        return u"".join(l)
    return l

class Array(_CData, metaclass=ArrayMeta):
    _ffiargshape_ = 'P'

    def __init__(self, *args):
        if not hasattr(self, '_buffer'):
            self._buffer = self._ffiarray(self._length_, autofree=True)
        for i, arg in enumerate(args):
            self[i] = arg
    _init_no_arg_ = __init__

    def _fix_index(self, index):
        if index < 0:
            index += self._length_
        if 0 <= index < self._length_:
            return index
        else:
            raise IndexError

    _get_slice_params = array_get_slice_params
    _slice_getitem = array_slice_getitem
    _slice_setitem = array_slice_setitem

    def _subarray(self, index):
        """Return a _rawffi array of length 1 whose address is the same as
        the index'th item of self."""
        address = self._buffer.itemaddress(index)
        return self._ffiarray.fromaddress(address, 1)

    def __setitem__(self, index, value):
        if isinstance(index, slice):
            self._slice_setitem(index, value)
            return
        index = self._fix_index(index)
        cobj = self._type_.from_param(value)
        if ensure_objects(cobj) is not None:
            store_reference(self, index, cobj._objects)
        arg = cobj._get_buffer_value()
        if self._type_._fficompositesize_ is None:
            self._buffer[index] = arg
            # something more sophisticated, cannot set field directly
        else:
            from ctypes import memmove
            dest = self._buffer.itemaddress(index)
            memmove(dest, arg, self._type_._fficompositesize_)

    def __getitem__(self, index):
        if isinstance(index, slice):
            return self._slice_getitem(index)
        index = self._fix_index(index)
        return self._type_._CData_output(self._subarray(index), self, index)

    def __len__(self):
        return self._length_

    def _get_buffer_for_param(self):
        return CArgObject(self, self._buffer.byptr())

    def _get_buffer_value(self):
        return self._buffer.buffer

    def _to_ffi_param(self):
        return self._get_buffer_value()

    def _as_ffi_pointer_(self, ffitype):
        return as_ffi_pointer(self, ffitype)

    def __buffer__(self, flags):
        shape = []
        obj = self
        while 1:
            shape.append(obj._length_)
            try:
                obj[0]._length_
            except (AttributeError, IndexError):
                break
            obj = obj[0]

        fmt = obj._type_._getformat()
        itemsize = sizeof(obj._type_)
        return __pypy__.newmemoryview(memoryview(self._buffer), itemsize, fmt, shape)

    def __class_getitem__(self, item):
        return GenericAlias(self, item)

ARRAY_CACHE = {}

def create_array_type(base, length):
    if not hasattr(length, '__index__'):
        raise TypeError("Can't multiply a ctypes type by a non-int of type %s" % type(length).__name__)
    length = int(length)
    if length < 0:
        raise ValueError("Array length must be >= 0")
    if length * base._sizeofinstances() > sys.maxsize:
        raise OverflowError("array too large")
    key = (base, length)
    try:
        return ARRAY_CACHE[key]
    except KeyError:
        name = "%s_Array_%d" % (base.__name__, length)
        tpdict = dict(
            _length_ = length,
            _type_ = base
        )
        cls = ArrayMeta(name, (Array,), tpdict)
        ARRAY_CACHE[key] = cls
        return cls

byteorder = {'little': '<', 'big': '>'}
swappedorder = {'little': '>', 'big': '<'}

def get_format_str(typ):
    return typ._getformat()
