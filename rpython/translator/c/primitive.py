import math
import sys

from rpython.rlib.objectmodel import Symbolic, ComputedIntSymbolic, CDefinedIntSymbolic
from rpython.rlib.rarithmetic import r_longlong, is_emulated_long
from rpython.rtyper.lltypesystem import rffi, llgroup
from rpython.rtyper.lltypesystem.llmemory import (Address, AddressOffset,
    ItemOffset, ArrayItemsOffset, FieldOffset, CompositeOffset,
    ArrayLengthOffset, GCHeaderOffset, GCREF, AddressAsInt)
from rpython.rtyper.lltypesystem.lltype import (Signed, SignedLongLong, Unsigned,
    UnsignedLongLong, Float, SingleFloat, LongFloat, Char, UniChar, Bool, Void,
    FixedSizeArray, Ptr, cast_opaque_ptr, typeOf, _uninitialized)
from rpython.rtyper.lltypesystem.llarena import RoundedUpForAllocation
from rpython.rtyper.tool.rffi_platform import memory_alignment
from rpython.translator.c.support import cdecl, barebonearray


SUPPORT_INT128 = hasattr(rffi, '__INT128_T')
MEMORY_ALIGNMENT = memory_alignment()

# ____________________________________________________________
#
# Primitives

# win64: we need different constants, since we emulate 64 bit long.
# this function simply replaces 'L' by 'LL' in a format string
if is_emulated_long:
    def lll(fmt):
        return fmt.replace('L', 'LL')
else:
    def lll(fmt):
        return fmt

def name_signed(value, db):
    if isinstance(value, Symbolic):
        if isinstance(value, FieldOffset):
            structnode = db.gettypedefnode(value.TYPE)
            if isinstance(value.TYPE, FixedSizeArray):
                assert value.fldname.startswith('item')
                repeat = value.fldname[4:]
                size = 'sizeof(%s)' % (cdecl(db.gettype(value.TYPE.OF), ''),)
                return '(%s * %s)' % (size, repeat)
            return 'offsetof(%s, %s)' % (
                cdecl(db.gettype(value.TYPE), ''),
                structnode.c_struct_field_name(value.fldname))
        elif isinstance(value, ItemOffset):
            if value.TYPE != Void and value.repeat != 0:
                size = 'sizeof(%s)' % (cdecl(db.gettype(value.TYPE), ''),)
                if value.repeat != 1:
                    size = '(%s * %s)' % (size, value.repeat)
                return size
            else:
                return '0'
        elif isinstance(value, ArrayItemsOffset):
            if (isinstance(value.TYPE, FixedSizeArray) or
                barebonearray(value.TYPE)):
                return '0'
            elif value.TYPE.OF != Void:
                return 'offsetof(%s, items)' % (
                    cdecl(db.gettype(value.TYPE), ''))
            else:
                return 'sizeof(%s)' % (cdecl(db.gettype(value.TYPE), ''),)
        elif isinstance(value, ArrayLengthOffset):
            return 'offsetof(%s, length)' % (
                cdecl(db.gettype(value.TYPE), ''))
        elif isinstance(value, CompositeOffset):
            names = [name_signed(item, db) for item in value.offsets]
            return '(%s)' % (' + '.join(names),)
        elif type(value) == AddressOffset:
            return '0'
        elif type(value) == GCHeaderOffset:
            return '0'
        elif type(value) == RoundedUpForAllocation:
            return ('(((%(x)s>=%(minsize)s?%(x)s:%(minsize)s) + %(align_m1)s)'
                    ' & ~%(align_m1)s)') % {
                'x': name_signed(value.basesize, db),
                'minsize': name_signed(value.minsize, db),
                'align_m1': MEMORY_ALIGNMENT-1
            }
        elif isinstance(value, CDefinedIntSymbolic):
            return str(value.expr)
        elif isinstance(value, ComputedIntSymbolic):
            value = value.compute_fn()
        elif isinstance(value, llgroup.CombinedSymbolic):
            name = name_small_integer(value.lowpart, db)
            assert (value.rest & value.MASK) == 0
            return lll('(%s+%dL)') % (name, value.rest)
        elif isinstance(value, AddressAsInt):
            return '((Signed)%s)' % name_address(value.adr, db)
        else:
            raise Exception("unimplemented symbolic %r" % value)
    if value is None or isinstance(value, _uninitialized):
        assert not db.completed
        return None
    if value == -sys.maxint-1:   # blame C
        return lll('(-%dL-1L)') % sys.maxint
    else:
        return lll('%dL') % value

def name_unsigned(value, db):
    assert value >= 0
    return lll('%dUL') % value

def name_unsignedlonglong(value, db):
    assert value >= 0
    return '%dULL' % value

def name_signedlonglong(value, db):
    maxlonglong = r_longlong.MASK>>1
    if value == -maxlonglong-1:    # blame C
        return '(-%dLL-1LL)' % maxlonglong
    else:
        return '%dLL' % value

def is_positive_nan(value):
    return math.copysign(1, value) > 0

def name_float(value, db):
    if math.isinf(value):
        if value > 0:
            return '(Py_HUGE_VAL)'
        else:
            return '(-Py_HUGE_VAL)'
    elif math.isnan(value):
        if is_positive_nan(value):
            return '(_PyPy_dg_stdnan(0))'
        else:
            return '(_PyPy_dg_stdnan(1))'
    else:
        x = repr(float(value))
        assert not x.startswith('n')
        return x
name_longfloat = name_float

def name_singlefloat(value, db):
    value = float(value)
    if math.isinf(value):
        if value > 0:
            return '((float)Py_HUGE_VAL)'
        else:
            return '((float)-Py_HUGE_VAL)'
    elif math.isnan(value):
        # XXX are these expressions ok?
        if is_positive_nan(value):
            return '((float)(_PyPy_dg_stdnan(0)))'
        else:
            return '((float)(_PyPy_dg_stdnan(1)))'
    else:
        return repr(value) + 'f'

def name_char(value, db):
    assert type(value) is str and len(value) == 1
    if ' ' <= value < '\x7f':
        return "'%s'" % (value.replace("\\", r"\\").replace("'", r"\'"),)
    else:
        return '((char)%d)' % ord(value)

def name_bool(value, db):
    return '%d' % value

def name_void(value, db):
    return '/* nothing */'

def name_unichar(value, db):
    assert type(value) is unicode and len(value) == 1
    return '((wchar_t)%d)' % ord(value)

def name_address(value, db):
    if value:
        return db.get(value.ref())
    else:
        return 'NULL'

def name_gcref(value, db):
    if value:
        obj = value._obj
        if isinstance(obj, int):
            # a tagged pointer
            return _name_tagged(obj, db)
        realobj = obj.container
        if isinstance(realobj, int):
            return _name_tagged(realobj, db)
        realvalue = cast_opaque_ptr(Ptr(typeOf(realobj)), value)
        return db.get(realvalue)
    else:
        return 'NULL'

def _name_tagged(obj, db):
    assert obj & 1 == 1
    return '((%s) %d)' % (cdecl("void*", ''), obj)

def name_small_integer(value, db):
    """Works for integers of size at most INT or UINT."""
    if isinstance(value, Symbolic):
        if isinstance(value, llgroup.GroupMemberOffset):
            groupnode = db.getcontainernode(value.grpptr._as_obj())
            return 'GROUP_MEMBER_OFFSET(%s, member%s)' % (
                cdecl(groupnode.implementationtypename, ''),
                value.index,
                )
        else:
            raise Exception("unimplemented symbolic %r" % value)
    return str(value)

# On 64 bit machines, SignedLongLong and Signed are the same, so the
# order matters, because we want the Signed implementation.
# (some entries collapse during dict creation)
PrimitiveName = {
    SignedLongLong:   name_signedlonglong,
    Signed:   name_signed,
    UnsignedLongLong: name_unsignedlonglong,
    Unsigned: name_unsigned,
    Float:    name_float,
    SingleFloat: name_singlefloat,
    LongFloat: name_longfloat,
    Char:     name_char,
    UniChar:  name_unichar,
    Bool:     name_bool,
    Void:     name_void,
    Address:  name_address,
    GCREF:    name_gcref,
    }

PrimitiveType = {
    SignedLongLong:   'long long @',
    Signed:   'Signed @',
    UnsignedLongLong: 'unsigned long long @',
    Unsigned: 'Unsigned @',
    Float:    'double @',
    SingleFloat: 'float @',
    LongFloat: 'long double @',
    Char:     'char @',
    UniChar:  'wchar_t @',
    Bool:     'bool_t @',
    Void:     'void @',
    Address:  'void* @',
    GCREF:    'void* @',
    }

def define_c_primitive(ll_type, c_name, suffix=''):
    if ll_type in PrimitiveName:
        return
    if suffix == '':
        PrimitiveName[ll_type] = name_small_integer
    else:
        name_str = '((%s) %%d%s)' % (c_name, suffix)
        PrimitiveName[ll_type] = lambda value, db: name_str % value
    PrimitiveType[ll_type] = '%s @' % c_name

def define_shifted_primitive(ll_type, signed):
    suffix = "LL" if signed else "ULL"
    c_name = "__int128_t" if signed else "__uint128_t"
    def convert(value, db):
        left_part = value >> 64
        right_part = value - (left_part << 64)
        if signed:
            assert -2**63 <= left_part < 2**63
        else:
            assert 0 <= left_part < 2**64
        assert 0 <= right_part < 2**64
        name_str = '((((%s) %d%s) << 64) | ((%s) %dULL))' % (c_name, left_part, suffix, c_name, right_part)
        return name_str
    PrimitiveName[ll_type] = convert
    PrimitiveType[ll_type] = '%s @' % c_name

define_c_primitive(rffi.SIGNEDCHAR, 'signed char')
define_c_primitive(rffi.UCHAR, 'unsigned char')
define_c_primitive(rffi.SHORT, 'short')
define_c_primitive(rffi.USHORT, 'unsigned short')
define_c_primitive(rffi.INT, 'int')
define_c_primitive(rffi.INT_real, 'int')
define_c_primitive(rffi.UINT, 'unsigned int')
define_c_primitive(rffi.LONG, 'long', 'L')
define_c_primitive(rffi.ULONG, 'unsigned long', 'UL')
define_c_primitive(rffi.LONGLONG, 'long long', 'LL')
define_c_primitive(rffi.ULONGLONG, 'unsigned long long', 'ULL')
if SUPPORT_INT128:
    define_shifted_primitive(rffi.__INT128_T, signed=True)
    define_shifted_primitive(rffi.__UINT128_T, signed=False)
