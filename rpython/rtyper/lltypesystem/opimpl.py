import random, sys
from rpython.flowspace.operation import op
from rpython.rlib import debug
from rpython.rlib.rarithmetic import is_valid_int
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.tool.sourcetools import func_with_new_name

# ____________________________________________________________
# Implementation of the 'canfold' operations


# implementations of ops from flow.operation
ops_returning_a_bool = {'gt': True, 'ge': True,
                        'lt': True, 'le': True,
                        'eq': True, 'ne': True,
                        'bool': True, 'is_true':True}

# global synonyms for some types
from rpython.rlib.rarithmetic import intmask
from rpython.rlib.rarithmetic import r_int, r_uint, r_longlong, r_ulonglong, r_longlonglong, r_ulonglonglong
from rpython.rtyper.lltypesystem.llmemory import AddressAsInt

if r_longlong is r_int:
    r_longlong_arg = (r_longlong, int, long)
    r_longlong_result = long # XXX was int
else:
    r_longlong_arg = r_longlong
    r_longlong_result = r_longlong


r_longlonglong_arg = r_longlonglong
r_longlonglong_result = r_longlonglong

argtype_by_name = {
    'int': (int, long),
    'float': float,
    'uint': r_uint,
    'llong': r_longlong_arg,
    'ullong': r_ulonglong,
    'lllong': r_longlonglong,
    'ulllong': r_ulonglonglong,
    }

def no_op(x):
    return x

def get_primitive_op_src(fullopname):
    assert '_' in fullopname, "%s: not a primitive op" % (fullopname,)
    typname, opname = fullopname.split('_', 1)
    if hasattr(op, opname):
        oper = getattr(op, opname)
    elif hasattr(op, opname + '_'):
        oper = getattr(op, opname + '_')   # or_, and_
    else:
        raise ValueError("%s: not a primitive op" % (fullopname,))
    func = oper.pyfunc

    if typname == 'char':
        # char_lt, char_eq, ...
        def op_function(x, y):
            if not isinstance(x, str) or len(x) != 1:
                raise TypeError("%r arg must be a char, got %r instead" % (
                    fullopname, type(x).__name__))
            if not isinstance(y, str) or len(y) != 1:
                raise TypeError("%r arg must be a char, got %r instead" % (
                    fullopname, type(y).__name__))
            return func(x, y)

    else:
        if typname == 'int' and opname not in ops_returning_a_bool:
            adjust_result = intmask
        else:
            adjust_result = no_op
        assert typname in argtype_by_name, "%s: not a primitive op" % (
            fullopname,)
        argtype = argtype_by_name[typname]

        if oper.arity == 1:
            def op_function(x):
                if not isinstance(x, argtype):
                    raise TypeError("%r arg must be %s, got %r instead" % (
                        fullopname, typname, type(x).__name__))
                return adjust_result(func(x))
        else:
            def op_function(x, y):
                if not isinstance(x, argtype):
                    raise TypeError("%r arg 1 must be %s, got %r instead"% (
                        fullopname, typname, type(x).__name__))
                if not isinstance(y, argtype):
                    raise TypeError("%r arg 2 must be %s, got %r instead"% (
                        fullopname, typname, type(y).__name__))
                return adjust_result(func(x, y))

    return func_with_new_name(op_function, 'op_' + fullopname)

def checkptr(ptr):
    if not isinstance(lltype.typeOf(ptr), lltype.Ptr):
        raise TypeError("arg must be a pointer, got %r instead" % (
            lltype.typeOf(ptr),))

def checkadr(adr):
    if lltype.typeOf(adr) is not llmemory.Address:
        raise TypeError("arg must be an address, got %r instead" % (
            lltype.typeOf(adr),))


def op_int_eq(x, y):
    if not isinstance(x, (int, long)):
        from rpython.rtyper.lltypesystem import llgroup
        assert isinstance(x, llgroup.CombinedSymbolic), (
            "'int_eq' arg 1 must be int-like, got %r instead" % (
                type(x).__name__,))
    if not isinstance(y, (int, long)):
        from rpython.rtyper.lltypesystem import llgroup
        assert isinstance(y, llgroup.CombinedSymbolic), (
            "'int_eq' arg 2 must be int-like, got %r instead" % (
                type(y).__name__,))
    return x == y

def op_ptr_eq(ptr1, ptr2):
    checkptr(ptr1)
    checkptr(ptr2)
    return ptr1 == ptr2

def op_ptr_ne(ptr1, ptr2):
    checkptr(ptr1)
    checkptr(ptr2)
    return ptr1 != ptr2

def op_ptr_nonzero(ptr1):
    checkptr(ptr1)
    return bool(ptr1)

def op_ptr_iszero(ptr1):
    checkptr(ptr1)
    return not bool(ptr1)

def op_getsubstruct(obj, field):
    checkptr(obj)
    # check the difference between op_getfield and op_getsubstruct:
    assert isinstance(getattr(lltype.typeOf(obj).TO, field),
                      lltype.ContainerType)
    return getattr(obj, field)

def op_getarraysubstruct(array, index):
    checkptr(array)
    result = array[index]
    return result
    # the diff between op_getarrayitem and op_getarraysubstruct
    # is the same as between op_getfield and op_getsubstruct

def op_getinteriorarraysize(obj, *offsets):
    checkptr(obj)
    ob = obj
    for o in offsets:
        if isinstance(o, str):
            ob = getattr(ob, o)
        else:
            ob = ob[o]
    return len(ob)

def op_getinteriorfield(obj, *offsets):
    checkptr(obj)
    ob = obj
    for o in offsets:
        innermostcontainer = ob
        if isinstance(o, str):
            ob = getattr(ob, o)
        else:
            ob = ob[o]
    # we can constant-fold this if the innermost structure from which we
    # read the final field is immutable.
    T = lltype.typeOf(innermostcontainer).TO
    if not T._immutable_field(offsets[-1]):
        raise TypeError("cannot fold getinteriorfield on mutable struct")
    assert not isinstance(ob, lltype._interior_ptr)
    return ob

def op_getarraysize(array):
    checkptr(array)
    return len(array)

def op_direct_fieldptr(obj, field):
    checkptr(obj)
    assert isinstance(field, str)
    return lltype.direct_fieldptr(obj, field)

def op_direct_arrayitems(obj):
    checkptr(obj)
    return lltype.direct_arrayitems(obj)

def op_direct_ptradd(obj, index):
    checkptr(obj)
    assert is_valid_int(index)
    if not obj:
        raise AssertionError("direct_ptradd on null pointer")
        ## assert isinstance(index, int)
        ## assert not (0 <= index < 4096)
        ## from rpython.rtyper.lltypesystem import rffi
        ## return rffi.cast(lltype.typeOf(obj), index)
    return lltype.direct_ptradd(obj, index)


def op_bool_not(b):
    assert type(b) is bool
    return not b

def op_int_add(x, y):
    if not isinstance(x, (int, long, llmemory.AddressOffset)):
        from rpython.rtyper.lltypesystem import llgroup
        assert isinstance(x, llgroup.CombinedSymbolic)
    assert isinstance(y, (int, long, llmemory.AddressOffset))
    return intmask(x + y)

def op_int_sub(x, y):
    if not is_valid_int(x):
        from rpython.rtyper.lltypesystem import llgroup
        assert isinstance(x, llgroup.CombinedSymbolic)
    assert is_valid_int(y)
    return intmask(x - y)

def op_int_ge(x, y):
    # special case for 'AddressOffset >= 0'
    assert isinstance(x, (int, long, llmemory.AddressOffset))
    assert is_valid_int(y)
    return x >= y

def op_int_lt(x, y):
    # special case for 'AddressOffset < 0'
    # hack for win64
    assert isinstance(x, (int, long, llmemory.AddressOffset))
    assert is_valid_int(y)
    return x < y

def op_int_between(a, b, c):
    assert lltype.typeOf(a) is lltype.Signed
    assert lltype.typeOf(b) is lltype.Signed
    assert lltype.typeOf(c) is lltype.Signed
    return a <= b < c

def op_int_force_ge_zero(a):
    assert lltype.typeOf(a) is lltype.Signed
    if a < 0:
        return 0
    return a

def op_int_and(x, y):
    if not is_valid_int(x):
        from rpython.rtyper.lltypesystem import llgroup
        assert isinstance(x, llgroup.CombinedSymbolic)
    assert is_valid_int(y)
    return x & y

def op_int_or(x, y):
    if not is_valid_int(x):
        from rpython.rtyper.lltypesystem import llgroup
        assert isinstance(x, llgroup.CombinedSymbolic)
    assert is_valid_int(y)
    return x | y

def op_int_xor(x, y):
    # used in computing hashes
    if isinstance(x, AddressAsInt): x = llmemory.cast_adr_to_int(x.adr)
    if isinstance(y, AddressAsInt): y = llmemory.cast_adr_to_int(y.adr)
    assert is_valid_int(x)
    assert is_valid_int(y)
    return x ^ y

def op_int_mul(x, y):
    assert isinstance(x, (int, long, llmemory.AddressOffset))
    assert isinstance(y, (int, long, llmemory.AddressOffset))
    return intmask(x * y)

def op_int_rshift(x, y):
    if not is_valid_int(x):
        from rpython.rtyper.lltypesystem import llgroup
        assert isinstance(x, llgroup.CombinedSymbolic)
    assert is_valid_int(y)
    return x >> y

def op_int_floordiv(x, y):
    # hack for win64
    assert isinstance(x, (int, long, llmemory.AddressOffset))
    assert isinstance(y, (int, long, llmemory.AddressOffset))
    r = x//y
    if x^y < 0 and x%y != 0:
        r += 1
    return r

def op_int_mod(x, y):
    assert isinstance(x, (int, long, llmemory.AddressOffset))
    assert isinstance(y, (int, long, llmemory.AddressOffset))
    r = x%y
    if x^y < 0 and x%y != 0:
        r -= y
    return r

def op_llong_floordiv(x, y):
    assert isinstance(x, r_longlong_arg)
    assert isinstance(y, r_longlong_arg)
    r = x//y
    if x^y < 0 and x%y != 0:
        r += 1
    return r

def op_llong_mod(x, y):
    assert isinstance(x, r_longlong_arg)
    assert isinstance(y, r_longlong_arg)
    r = x%y
    if x^y < 0 and x%y != 0:
        r -= y
    return r

def op_lllong_floordiv(x, y):
    assert isinstance(x, r_longlonglong_arg)
    assert isinstance(y, r_longlonglong_arg)
    r = x//y
    if x^y < 0 and x%y != 0:
        r += 1
    return r

def op_lllong_mod(x, y):
    assert isinstance(x, r_longlonglong_arg)
    assert isinstance(y, r_longlonglong_arg)
    r = x%y
    if x^y < 0 and x%y != 0:
        r -= y
    return r

def op_uint_lshift(x, y):
    assert isinstance(x, r_uint)
    assert is_valid_int(y)
    return r_uint(x << y)

def op_uint_rshift(x, y):
    assert isinstance(x, r_uint)
    assert is_valid_int(y)
    return r_uint(x >> y)

def op_llong_lshift(x, y):
    assert isinstance(x, r_longlong_arg)
    assert is_valid_int(y)
    return r_longlong_result(x << y)

def op_llong_rshift(x, y):
    assert isinstance(x, r_longlong_arg)
    assert is_valid_int(y)
    return r_longlong_result(x >> y)

def op_lllong_lshift(x, y):
    assert isinstance(x, r_longlonglong_arg)
    assert is_valid_int(y)
    return r_longlonglong_result(x << y)

def op_lllong_rshift(x, y):
    assert isinstance(x, r_longlonglong_arg)
    assert is_valid_int(y)
    return r_longlonglong_result(x >> y)

def op_ullong_lshift(x, y):
    assert isinstance(x, r_ulonglong)
    assert isinstance(y, int)
    return r_ulonglong(x << y)

def op_ullong_rshift(x, y):
    assert isinstance(x, r_ulonglong)
    assert is_valid_int(y)
    return r_ulonglong(x >> y)

def op_ulllong_lshift(x, y):
    assert isinstance(x, r_ulonglonglong)
    assert isinstance(y, int)
    return r_ulonglonglong(x << y)

def op_ulllong_rshift(x, y):
    assert isinstance(x, r_ulonglonglong)
    assert is_valid_int(y)
    return r_ulonglonglong(x >> y)

def op_same_as(x):
    return x

def op_cast_primitive(TYPE, value):
    assert isinstance(lltype.typeOf(value), lltype.Primitive)
    return lltype.cast_primitive(TYPE, value)
op_cast_primitive.need_result_type = True

def op_cast_int_to_float(i):
    # assert type(i) is int
    assert is_valid_int(i)
    return float(i)

def op_cast_uint_to_float(u):
    assert type(u) is r_uint
    return float(u)

def op_cast_longlong_to_float(i):
    assert isinstance(i, r_longlong_arg)
    # take first 31 bits
    li = float(int(i & r_longlong(0x7fffffff)))
    ui = float(int(i >> 31)) * float(0x80000000)
    return ui + li

def op_cast_ulonglong_to_float(i):
    assert isinstance(i, r_ulonglong)
    # take first 32 bits
    li = float(int(i & r_ulonglong(0xffffffff)))
    ui = float(int(i >> 32)) * float(0x100000000)
    return ui + li

def op_cast_int_to_char(b):
    #assert type(b) is int
    assert is_valid_int(b)
    return chr(b)

def op_cast_bool_to_int(b):
    assert type(b) is bool
    return int(b)

def op_cast_bool_to_uint(b):
    assert type(b) is bool
    return r_uint(int(b))

def op_cast_bool_to_float(b):
    assert type(b) is bool
    return float(b)

def op_cast_float_to_int(f):
    assert type(f) is float
    return intmask(int(f))

def op_cast_float_to_uint(f):
    assert type(f) is float
    return r_uint(long(f))

def op_cast_float_to_longlong(f):
    assert type(f) is float
    r = float(0x100000000)
    small = f / r
    high = int(small)
    truncated = int((small - high) * r)
    return r_longlong_result(high) * 0x100000000 + truncated

def op_cast_float_to_ulonglong(f):
    assert type(f) is float
    return r_ulonglong(long(f))

def op_cast_char_to_int(b):
    assert type(b) is str and len(b) == 1
    return ord(b)

def op_cast_unichar_to_int(b):
    assert type(b) is unicode and len(b) == 1
    return ord(b)

def op_cast_int_to_unichar(b):
    assert is_valid_int(b)
    return unichr(b)

def op_cast_int_to_uint(b):
    # assert type(b) is int
    assert is_valid_int(b)
    return r_uint(b)

def op_cast_uint_to_int(b):
    assert type(b) is r_uint
    return intmask(b)

def op_cast_int_to_longlong(b):
    assert is_valid_int(b)
    return r_longlong_result(b)

def op_truncate_longlong_to_int(b):
    assert isinstance(b, r_longlong_arg)
    return intmask(b)

def op_cast_pointer(RESTYPE, obj):
    checkptr(obj)
    return lltype.cast_pointer(RESTYPE, obj)
op_cast_pointer.need_result_type = True

def op_cast_adr_to_ptr(TYPE, adr):
    checkadr(adr)
    return llmemory.cast_adr_to_ptr(adr, TYPE)
op_cast_adr_to_ptr.need_result_type = True

def op_cast_int_to_adr(int):
    return llmemory.cast_int_to_adr(int)

def op_convert_float_bytes_to_longlong(a):
    from rpython.rlib.longlong2float import float2longlong
    return float2longlong(a)

def op_convert_longlong_bytes_to_float(a):
    from rpython.rlib.longlong2float import longlong2float
    return longlong2float(a)


def op_unichar_eq(x, y):
    assert isinstance(x, unicode) and len(x) == 1
    assert isinstance(y, unicode) and len(y) == 1
    return x == y

def op_unichar_ne(x, y):
    assert isinstance(x, unicode) and len(x) == 1
    assert isinstance(y, unicode) and len(y) == 1
    return x != y


def op_adr_lt(addr1, addr2):
    checkadr(addr1)
    checkadr(addr2)
    return addr1 < addr2

def op_adr_le(addr1, addr2):
    checkadr(addr1)
    checkadr(addr2)
    return addr1 <= addr2

def op_adr_eq(addr1, addr2):
    checkadr(addr1)
    checkadr(addr2)
    return addr1 == addr2

def op_adr_ne(addr1, addr2):
    checkadr(addr1)
    checkadr(addr2)
    return addr1 != addr2

def op_adr_gt(addr1, addr2):
    checkadr(addr1)
    checkadr(addr2)
    return addr1 > addr2

def op_adr_ge(addr1, addr2):
    checkadr(addr1)
    checkadr(addr2)
    return addr1 >= addr2

def op_adr_add(addr, offset):
    checkadr(addr)
    assert lltype.typeOf(offset) is lltype.Signed
    return addr + offset

def op_adr_sub(addr, offset):
    checkadr(addr)
    assert lltype.typeOf(offset) is lltype.Signed
    return addr - offset

def op_adr_delta(addr1, addr2):
    checkadr(addr1)
    checkadr(addr2)
    return addr1 - addr2

def op_gc_writebarrier_before_copy(source, dest,
                                   source_start, dest_start, length):
    A = lltype.typeOf(source)
    assert A == lltype.typeOf(dest)
    if isinstance(A.TO, lltype.GcArray):
        if isinstance(A.TO.OF, lltype.Ptr):
            assert A.TO.OF.TO._gckind == 'gc'
        else:
            assert isinstance(A.TO.OF, lltype.Struct)
    else:
        assert isinstance(A.TO, lltype.GcStruct)
        assert A.TO._arrayfld is not None
    assert type(source_start) is int
    assert type(dest_start) is int
    assert type(length) is int
    return True

def op_gc_writebarrier_before_move(array):
    A = lltype.typeOf(array)
    if isinstance(A.TO, lltype.GcArray):
        if isinstance(A.TO.OF, lltype.Ptr):
            assert A.TO.OF.TO._gckind == 'gc'
        else:
            assert isinstance(A.TO.OF, lltype.Struct)
    else:
        assert isinstance(A.TO, lltype.GcStruct)
        assert A.TO._arrayfld is not None

def op_getfield(p, name):
    checkptr(p)
    TYPE = lltype.typeOf(p).TO
    if not TYPE._immutable_field(name):
        raise TypeError("cannot fold getfield on mutable struct")
    return getattr(p, name)

def op_getarrayitem(p, index):
    checkptr(p)
    ARRAY = lltype.typeOf(p).TO
    if not ARRAY._immutable_field(index):
        raise TypeError("cannot fold getarrayitem on mutable array")
    return p[index]

def _normalize(x):
    if not isinstance(x, str):
        TYPE = lltype.typeOf(x)
        if isinstance(TYPE, lltype.Ptr) and TYPE.TO._name == 'rpy_string':
            from rpython.rtyper.annlowlevel import hlstr
            return hlstr(x)
    return x

def op_debug_flush_log():
    debug.debug_flush_log()

def op_debug_print(*args):
    debug.debug_print(*map(_normalize, args))

def op_debug_start(category, timestamp):
    return debug.debug_start(_normalize(category), timestamp)

def op_debug_stop(category, timestamp):
    return debug.debug_stop(_normalize(category), timestamp)

def op_debug_offset():
    return debug.debug_offset()

def op_debug_flush():
    pass

def op_have_debug_prints():
    return debug.have_debug_prints()

def op_have_debug_prints_for(prefix):
    return True

def op_debug_nonnull_pointer(x):
    assert x

def op_gc_stack_bottom():
    pass       # see llinterp.py for docs

def op_jit_force_virtualizable(*args):
    pass

def op_jit_force_virtual(x):
    return x

def op_jit_is_virtual(x):
    return False

def op_jit_force_quasi_immutable(*args):
    pass

def op_jit_record_exact_class(x, y):
    pass

def op_jit_ffi_save_result(*args):
    pass

def op_jit_enter_portal_frame(x):
    pass

def op_jit_leave_portal_frame():
    pass

def op_get_group_member(TYPE, grpptr, memberoffset):
    from rpython.rtyper.lltypesystem import llgroup
    assert isinstance(memberoffset, llgroup.GroupMemberOffset)
    member = memberoffset._get_group_member(grpptr)
    return lltype.cast_pointer(TYPE, member)
op_get_group_member.need_result_type = True

def op_get_next_group_member(TYPE, grpptr, memberoffset, skipoffset):
    from rpython.rtyper.lltypesystem import llgroup
    assert isinstance(memberoffset, llgroup.GroupMemberOffset)
    member = memberoffset._get_next_group_member(grpptr, skipoffset)
    return lltype.cast_pointer(TYPE, member)
op_get_next_group_member.need_result_type = True

def op_is_group_member_nonzero(memberoffset):
    from rpython.rtyper.lltypesystem import llgroup
    if isinstance(memberoffset, llgroup.GroupMemberOffset):
        return memberoffset.index != 0
    else:
        assert is_valid_int(memberoffset)
        return memberoffset != 0

def op_extract_ushort(combinedoffset):
    from rpython.rtyper.lltypesystem import llgroup
    assert isinstance(combinedoffset, llgroup.CombinedSymbolic)
    return combinedoffset.lowpart

def op_combine_ushort(ushort, rest):
    from rpython.rtyper.lltypesystem import llgroup
    return llgroup.CombinedSymbolic(ushort, rest)

def op_gc_gettypeptr_group(TYPE, obj, grpptr, skipoffset, vtableinfo):
    HDR            = vtableinfo[0]
    size_gc_header = vtableinfo[1]
    fieldname      = vtableinfo[2]
    objaddr = llmemory.cast_ptr_to_adr(obj)
    hdraddr = objaddr - size_gc_header
    hdr = llmemory.cast_adr_to_ptr(hdraddr, lltype.Ptr(HDR))
    typeid = getattr(hdr, fieldname)
    if lltype.typeOf(typeid) == lltype.Signed:
        typeid = op_extract_ushort(typeid)
    return op_get_next_group_member(TYPE, grpptr, typeid, skipoffset)
op_gc_gettypeptr_group.need_result_type = True

def op_get_member_index(memberoffset):
    raise NotImplementedError

def op_gc_writebarrier(addr):
    pass

def op_gc_bit(hdr, bitmask):
    if hdr.tid & bitmask:
        return random.randrange(1, sys.maxint)
    return 0

def op_shrink_array(array, smallersize):
    return False

def op_ll_read_timestamp():
    from rpython.rlib.rtimer import read_timestamp
    return read_timestamp()

def op_ll_get_timestamp_unit():
    from rpython.rlib.rtimer import get_timestamp_unit
    return get_timestamp_unit()

def op_debug_fatalerror(ll_msg):
    from rpython.rtyper.lltypesystem import lltype, rstr
    from rpython.rtyper.llinterp import LLFatalError
    assert lltype.typeOf(ll_msg) == lltype.Ptr(rstr.STR)
    msg = ''.join(ll_msg.chars)
    raise LLFatalError(msg)

def op_raw_store(p, ofs, newvalue):
    from rpython.rtyper.lltypesystem import rffi
    p = rffi.cast(llmemory.Address, p)
    TVAL = lltype.typeOf(newvalue)
    p = rffi.cast(rffi.CArrayPtr(TVAL), p + ofs)
    p[0] = newvalue

def op_gc_store(p, ofs, newvalue):
    from rpython.rtyper.lltypesystem import rffi
    if lltype.typeOf(p) is not llmemory.Address:
        p = llmemory.cast_ptr_to_adr(p)
    TVAL = lltype.typeOf(newvalue)
    p = llmemory.cast_adr_to_ptr(p + ofs, lltype.Ptr(lltype.FixedSizeArray(TVAL, 1)))
    p[0] = newvalue

def op_raw_load(TVAL, p, ofs):
    from rpython.rtyper.lltypesystem import rffi
    p = rffi.cast(llmemory.Address, p)
    p = rffi.cast(rffi.CArrayPtr(TVAL), p + ofs)
    return p[0]
op_raw_load.need_result_type = True

def op_gc_load_indexed(TVAL, p, index, scale, base_ofs):
    # 'base_ofs' should be a CompositeOffset(..., ArrayItemsOffset).
    # 'scale' should be a llmemory.sizeof().
    from rpython.rtyper.lltypesystem import rffi
    ofs = base_ofs + scale * index
    if isinstance(ofs, int):
        return op_raw_load(TVAL, p, ofs)
    p = rffi.cast(rffi.CArrayPtr(TVAL), llmemory.cast_ptr_to_adr(p) + ofs)
    return p[0]
op_gc_load_indexed.need_result_type = True

def op_gc_store_indexed(p, index, newvalue, scale, base_ofs):
    # 'base_ofs' should be a CompositeOffset(..., ArrayItemsOffset).
    # 'scale' should be a llmemory.sizeof().
    from rpython.rtyper.lltypesystem import rffi
    TVAL = lltype.typeOf(newvalue)
    ofs = base_ofs + scale * index
    if isinstance(ofs, int):
        return op_raw_store(p, ofs, newvalue)
    p = rffi.cast(rffi.CArrayPtr(TVAL), llmemory.cast_ptr_to_adr(p) + ofs)
    p[0] = newvalue

def op_likely(x):
    assert isinstance(x, bool)
    return x

def op_unlikely(x):
    assert isinstance(x, bool)
    return x

def op_gc_ignore_finalizer(obj):
    pass

def op_gc_move_out_of_nursery(obj):
    return obj

def op_gc_increase_root_stack_depth(new_depth):
    pass

def op_revdb_do_next_call():
    pass

# ____________________________________________________________

def get_op_impl(opname):
    # get the op_xxx() function from the globals above
    try:
        return globals()['op_' + opname]
    except KeyError:
        return get_primitive_op_src(opname)
