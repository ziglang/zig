
from rpython.jit.codewriter import longlong
from rpython.jit.metainterp.support import adr2int, ptr2int
from rpython.jit.metainterp.history import getkind

from rpython.rlib.rarithmetic import r_longlong, r_ulonglong, r_uint
from rpython.rtyper.lltypesystem import lltype, rffi, llmemory

IS_32_BIT = r_ulonglong is not r_uint

kind2TYPE = {
    'i': lltype.Signed,
    'f': lltype.Float,
    'L': lltype.SignedLongLong,
    'S': lltype.SingleFloat,
    'v': lltype.Void,
    }

def cast_to_int(x):
    TP = lltype.typeOf(x)
    if isinstance(TP, lltype.Ptr):
        return ptr2int(x)
    if TP == llmemory.Address:
        return adr2int(x)
    if TP is lltype.SingleFloat:
        return longlong.singlefloat2int(x)
    return lltype.cast_primitive(lltype.Signed, x)

def cast_to_ptr(x):
    assert isinstance(lltype.typeOf(x), lltype.Ptr)
    return lltype.cast_opaque_ptr(llmemory.GCREF, x)

def cast_to_floatstorage(x):
    if isinstance(x, float):
        return longlong.getfloatstorage(x)      # common case
    if IS_32_BIT:
        assert longlong.supports_longlong
        if isinstance(x, r_longlong):
            return x
        if isinstance(x, r_ulonglong):
            return rffi.cast(lltype.SignedLongLong, x)
    raise TypeError(type(x))

def cast_result(TP, x):
    kind = getkind(TP)
    if kind == 'int':
        return cast_to_int(x)
    elif kind == 'ref':
        return cast_to_ptr(x)
    elif kind == 'float':
        return cast_to_floatstorage(x)
    else:
        assert kind == 'void'
        assert x is None
        return None

def cast_from_floatstorage(TYPE, x):
    assert isinstance(x, longlong.r_float_storage)
    if TYPE is lltype.Float:
        return longlong.getrealfloat(x)
    if longlong.is_longlong(TYPE):
        return rffi.cast(TYPE, x)
    raise TypeError(TYPE)

def cast_from_int(TYPE, x):
    if isinstance(TYPE, lltype.Ptr):
        if isinstance(x, (int, long, llmemory.AddressAsInt)):
            x = llmemory.cast_int_to_adr(x)
        try:   # pom pom pom
            return llmemory.cast_adr_to_ptr(x, TYPE)
        except Exception:
            # assume that we want a "C-style" cast, without typechecking the value
            return rffi.cast(TYPE, x)
    elif TYPE == llmemory.Address:
        if isinstance(x, (int, long, llmemory.AddressAsInt)):
            x = llmemory.cast_int_to_adr(x)
        assert lltype.typeOf(x) == llmemory.Address
        return x
    elif TYPE is lltype.SingleFloat:
        assert lltype.typeOf(x) is lltype.Signed
        return longlong.int2singlefloat(x)
    else:
        if lltype.typeOf(x) == llmemory.Address:
            x = adr2int(x)
        return lltype.cast_primitive(TYPE, x)

def cast_from_ptr(TYPE, x):
    if lltype.typeOf(x) == TYPE:
        return x
    return lltype.cast_opaque_ptr(TYPE, x)

def cast_arg(TP, x):
    kind = getkind(TP)
    if kind == 'int':
        return cast_from_int(TP, x)
    elif kind == 'ref':
        return cast_from_ptr(TP, x)
    else:
        assert kind == 'float'
        return cast_from_floatstorage(TP, x)

def cast_call_args(ARGS, args_i, args_r, args_f, args_in_order=None):
    argsiter_i = iter(args_i or [])
    argsiter_r = iter(args_r or [])
    argsiter_f = iter(args_f or [])
    if args_in_order is not None:
        orderiter = iter(args_in_order)
    args = []
    for TYPE in ARGS:
        if TYPE is lltype.Void:
            x = None
        else:
            if isinstance(TYPE, lltype.Ptr) and TYPE.TO._gckind == 'gc':
                if args_in_order is not None:
                    n = orderiter.next()
                    assert n == 'r'
                x = argsiter_r.next()
                x = cast_from_ptr(TYPE, x)
            elif TYPE is lltype.Float or longlong.is_longlong(TYPE):
                if args_in_order is not None:
                    n = orderiter.next()
                    assert n == 'f'
                x = argsiter_f.next()
                x = cast_from_floatstorage(TYPE, x)
            else:
                if args_in_order is not None:
                    n = orderiter.next()
                    assert n == 'i'
                x = argsiter_i.next()
                x = cast_from_int(TYPE, x)
        args.append(x)
    assert list(argsiter_i) == []
    assert list(argsiter_r) == []
    assert list(argsiter_f) == []
    return args

def cast_call_args_in_order(ARGS, args):
    call_args = []
    i = 0
    for ARG in ARGS:
        kind = getkind(ARG)
        if kind == 'int':
            n = cast_from_int(ARG, args[i])
            i += 1
        elif kind == 'ref':
            n = cast_from_ptr(ARG, args[i])
            i += 1
        elif kind == 'float':
            n = cast_from_floatstorage(ARG, args[i])
            i += 1
        elif kind == 'void':
            n = None
        else:
            raise AssertionError(kind)
        call_args.append(n)
    assert i == len(args)
    return call_args

def addr_add_bytes(addr, ofs):
    if (isinstance(ofs, int) and
            getattr(addr.adr.ptr._TYPE.TO, 'OF', None) == lltype.Char):
        return addr + ofs
    ptr = rffi.cast(rffi.CCHARP, addr.adr)
    ptr = lltype.direct_ptradd(ptr, ofs)
    return cast_to_int(ptr)
