# Tcl_Obj, conversions with Python objects

from .tklib_cffi import ffi as tkffi, lib as tklib
import binascii

class TypeCache(object):
    def __init__(self):
        self.OldBooleanType = tklib.Tcl_GetObjType(b"boolean")
        self.BooleanType = None
        self.ByteArrayType = tklib.Tcl_GetObjType(b"bytearray")
        self.DoubleType = tklib.Tcl_GetObjType(b"double")
        self.IntType = tklib.Tcl_GetObjType(b"int")
        self.WideIntType = tklib.Tcl_GetObjType(b"wideInt")
        self.BigNumType = None
        self.ListType = tklib.Tcl_GetObjType(b"list")
        self.ProcBodyType = tklib.Tcl_GetObjType(b"procbody")
        self.StringType = tklib.Tcl_GetObjType(b"string")

    def add_extra_types(self, app):
        # Some types are not registered in Tcl.
        result = app.call('expr', 'true')
        typePtr = AsObj(result).typePtr
        if tkffi.string(typePtr.name) == b"booleanString":
            self.BooleanType = typePtr

        result = app.call('expr', '2**63')
        typePtr = AsObj(result).typePtr
        if tkffi.string(typePtr.name) == b"bignum":
            self.BigNumType = typePtr


def FromTclString(s):
    try:
        return s.decode('utf-8')
    except UnicodeDecodeError:
        # Tcl encodes null character as \xc0\x80
        r = s.replace(b'\xc0\x80', b'\x00').decode('utf-8', 'surrogateescape')
        # now we need to deal with cesu-8
        result = []
        prevpos = 0
        while 1:
            pos = r.find("\udced", prevpos)
            if pos == -1:
                result.append(r[prevpos:])
                return "".join(result)

            assert pos + 6 <= len(r)
            result.append(r[prevpos:pos])
            # High surrogates U+d800 - U+dbff are encoded as
            # \xed\xa0\x80 - \xed\xaf\xbf.
            ch1 = ord(r[pos + 0])
            assert ch1 == 0xdced
            ch2 = ord(r[pos + 1])
            assert 0xdca0 <= ch2 <= 0xdcaf
            ch3 = ord(r[pos + 2])
            assert 0xdc80 <= ch3 <= 0xdcbf
            high = 0xd000 | ((ch2 & 0x3f) << 6) | (ch3 & 0x3f)
            # Low surrogates U+DC00 - U+DFFF are encoded as
            # \xed\xb0\x80 - \xed\xbf\xbf
            ch1 = ord(r[pos + 3])
            assert ch1 == 0xdced
            ch2 = ch5 = ord(r[pos + 4])
            assert 0xdcb0 <= ch2 <= 0xdcbf
            ch3 = ch6 = ord(r[pos + 5])
            assert 0xdc80 <= ch3 <= 0xdcbf
            low = 0xd000 | ((ch2 & 0x3f) << 6) | (ch3 & 0x3f)
            assert 0xd800 <= high <= 0xdbff # valid high surrogate
            # combine to chararcter
            res = chr((((high & 0x03ff) << 10) | (low & 0x03ff)) + 0x10000)
            result.append(res)
            prevpos = pos + 6
    return s


# Only when tklib.HAVE_WIDE_INT_TYPE.
def FromWideIntObj(app, value):
    wide = tkffi.new("Tcl_WideInt*")
    if tklib.Tcl_GetWideIntFromObj(app.interp, value, wide) != tklib.TCL_OK:
        app.raiseTclError()
    return wide[0]

# Only when tklib.HAVE_LIBTOMMATH!
def FromBignumObj(app, value):
    bigValue = tkffi.new("mp_int*")
    if tklib.Tcl_GetBignumFromObj(app.interp, value, bigValue) != tklib.TCL_OK:
        app.raiseTclError()
    try:
        numBytes = tklib.mp_unsigned_bin_size(bigValue)
        buf = tkffi.new("unsigned char[]", numBytes)
        bufSize_ptr = tkffi.new("unsigned long*", numBytes)
        if tklib.mp_to_unsigned_bin_n(
                bigValue, buf, bufSize_ptr) != tklib.MP_OKAY:
            raise MemoryError
        if bufSize_ptr[0] == 0:
            return 0
        bytes = tkffi.buffer(buf)[0:bufSize_ptr[0]]
        sign = -1 if bigValue.sign == tklib.MP_NEG else 1
        return int(sign * int(binascii.hexlify(bytes), 16))
    finally:
        tklib.mp_clear(bigValue)

def AsBignumObj(value):
    sign = -1 if value < 0 else 1
    hexstr = b'%x' % abs(value)
    bigValue = tkffi.new("mp_int*")
    tklib.mp_init(bigValue)
    try:
        if tklib.mp_read_radix(bigValue, hexstr, 16) != tklib.MP_OKAY:
            raise MemoryError
        bigValue.sign = tklib.MP_NEG if value < 0 else tklib.MP_ZPOS
        return tklib.Tcl_NewBignumObj(bigValue)
    finally:
        tklib.mp_clear(bigValue)


def FromObj(app, value):
    """Convert a TclObj pointer into a Python object."""
    typeCache = app._typeCache
    if not value.typePtr:
        buf = tkffi.buffer(value.bytes, value.length)
        return FromTclString(buf[:])

    if value.typePtr in (typeCache.BooleanType, typeCache.OldBooleanType):
        value_ptr = tkffi.new("int*")
        if tklib.Tcl_GetBooleanFromObj(
                app.interp, value, value_ptr) == tklib.TCL_ERROR:
            app.raiseTclError()
        return bool(value_ptr[0])
    if value.typePtr == typeCache.ByteArrayType:
        size = tkffi.new('int*')
        data = tklib.Tcl_GetByteArrayFromObj(value, size)
        return tkffi.buffer(data, size[0])[:]
    if value.typePtr == typeCache.DoubleType:
        return value.internalRep.doubleValue
    if value.typePtr == typeCache.IntType:
        return value.internalRep.longValue
    if value.typePtr == typeCache.WideIntType:
        return FromWideIntObj(app, value)
    if value.typePtr == typeCache.BigNumType and tklib.HAVE_LIBTOMMATH:
        return FromBignumObj(app, value)
    if value.typePtr == typeCache.ListType:
        size = tkffi.new('int*')
        status = tklib.Tcl_ListObjLength(app.interp, value, size)
        if status == tklib.TCL_ERROR:
            app.raiseTclError()
        result = []
        tcl_elem = tkffi.new("Tcl_Obj**")
        for i in range(size[0]):
            status = tklib.Tcl_ListObjIndex(app.interp,
                                            value, i, tcl_elem)
            if status == tklib.TCL_ERROR:
                app.raiseTclError()
            result.append(FromObj(app, tcl_elem[0]))
        return tuple(result)
    if value.typePtr == typeCache.ProcBodyType:
        pass  # fall through and return tcl object.
    if value.typePtr == typeCache.StringType:
        buf = tklib.Tcl_GetUnicode(value)
        length = tklib.Tcl_GetCharLength(value)
        buf = tkffi.buffer(tkffi.cast("char*", buf), length*2)[:]
        return buf.decode('utf-16', 'surrogatepass')

    return Tcl_Obj(value)

def AsObj(value):
    if isinstance(value, bytes):
        return tklib.Tcl_NewByteArrayObj(value, len(value))
    if isinstance(value, bool):
        return tklib.Tcl_NewBooleanObj(value)
    if isinstance(value, int):
        try:
            return tklib.Tcl_NewLongObj(value)
        except OverflowError:
            if tklib.HAVE_WIDE_INT_TYPE:
                try:
                    tkffi.new("Tcl_WideInt[]", [value])
                except OverflowError:
                    pass
                else:
                    return tklib.Tcl_NewWideIntObj(value)
            if tklib.HAVE_LIBTOMMATH:
                return AsBignumObj(value)
    if isinstance(value, float):
        return tklib.Tcl_NewDoubleObj(value)
    if isinstance(value, (tuple, list)):
        argv = tkffi.new("Tcl_Obj*[]", len(value))
        for i in range(len(value)):
            argv[i] = AsObj(value[i])
        return tklib.Tcl_NewListObj(len(value), argv)
    if isinstance(value, str):
        encoded = value.encode('utf-16', 'surrogatepass')[2:]
        buf = tkffi.new("char[]", encoded)
        inbuf = tkffi.cast("Tcl_UniChar*", buf)
        return tklib.Tcl_NewUnicodeObj(inbuf, len(encoded)//2)
    if isinstance(value, Tcl_Obj):
        return value._value

    return AsObj(str(value))

class Tcl_Obj(object):
    def __new__(cls, value):
        self = object.__new__(cls)
        tklib.Tcl_IncrRefCount(value)
        self._value = value
        self._string = None
        return self

    def __del__(self):
        tklib.Tcl_DecrRefCount(self._value)

    def __str__(self):
        if self._string and isinstance(self._string, str):
            return self._string
        return tkffi.string(tklib.Tcl_GetString(self._value)).decode('utf-8')

    def __repr__(self):
        return "<%s object at 0x%x>" % (
            self.typename, int(tkffi.cast("intptr_t", self._value)))

    def __eq__(self, other):
        if not isinstance(other, Tcl_Obj):
            return NotImplemented
        return self._value == other._value

    @property
    def typename(self):
        return FromTclString(tkffi.string(self._value.typePtr.name))

    @property
    def string(self):
        "the string representation of this object, either as str or bytes"
        if self._string is None:
            length = tkffi.new("int*")
            s = tklib.Tcl_GetStringFromObj(self._value, length)
            value = tkffi.buffer(s, length[0])[:]
            value = value.decode('utf-8')
            self._string = value
        return self._string
