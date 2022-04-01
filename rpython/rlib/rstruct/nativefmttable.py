"""
Native type codes.
The table 'native_fmttable' is also used by pypy.module.array.interp_array.
"""
import struct

from rpython.rlib import rutf8, longlong2float
from rpython.rlib.objectmodel import specialize
from rpython.rlib.rarithmetic import r_singlefloat, widen, intmask
from rpython.rlib.rstruct import standardfmttable as std
from rpython.rlib.rstruct.standardfmttable import native_is_bigendian
from rpython.rlib.rstruct.error import StructError
from rpython.rlib.rstruct.ieee import pack_float_to_buffer
from rpython.rlib.unroll import unrolling_iterable
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.tool import rffi_platform
from rpython.translator.tool.cbuild import ExternalCompilationInfo


native_fmttable = {
    'x': std.standard_fmttable['x'],
    'c': std.standard_fmttable['c'],
    's': std.standard_fmttable['s'],
    'p': std.standard_fmttable['p'],
    }

# ____________________________________________________________


def pack_double(fmtiter):
    doubleval = fmtiter.accept_float_arg()
    if std.pack_fastpath(rffi.DOUBLE)(fmtiter, doubleval):
        return
    # slow path
    value = longlong2float.float2longlong(doubleval)
    pack_float_to_buffer(fmtiter.wbuf, fmtiter.pos, value, 8, fmtiter.bigendian)
    fmtiter.advance(8)

def pack_float(fmtiter):
    doubleval = fmtiter.accept_float_arg()
    floatval = r_singlefloat(doubleval)
    if std.pack_fastpath(rffi.FLOAT)(fmtiter, floatval):
        return
    # slow path
    value = longlong2float.singlefloat2uint(floatval)
    value = widen(value)
    value = intmask(value)
    pack_float_to_buffer(fmtiter.wbuf, fmtiter.pos, value, 4, fmtiter.bigendian)
    fmtiter.advance(4)

# ____________________________________________________________
#
# Use rffi_platform to get the native sizes and alignments from the C compiler

def setup():
    INSPECT = {'b': 'signed char',
               'h': 'signed short',
               'i': 'signed int',
               'l': 'signed long',
               'q': 'signed long long',
               'n': 'ssize_t',
               'B': 'unsigned char',
               'H': 'unsigned short',
               'I': 'unsigned int',
               'L': 'unsigned long',
               'Q': 'unsigned long long',
               'N': 'size_t',
               'P': 'char *',
               'f': 'float',
               'd': 'double',
               '?': '_Bool',
               }

    pre_include_bits = ["""
        #include <sys/types.h>
        #ifdef _MSC_VER
        #define _Bool char
        #ifdef _WIN64
        typedef long long ssize_t;
        typedef unsigned long long size_t;
        #else
        typedef int ssize_t;
        typedef unsigned int size_t;
        #endif
        #endif"""]
    field_names = dict.fromkeys(INSPECT)
    for fmtchar, ctype in INSPECT.iteritems():
        field_name = ctype.replace(" ", "_").replace("*", "star")
        field_names[fmtchar] = field_name
        pre_include_bits.append("""
            struct about_%s {
                char pad;
                %s field;
            };
        """ % (field_name, ctype))

    class CConfig:
        _compilation_info_ = ExternalCompilationInfo(
            pre_include_bits = pre_include_bits
        )

    for fmtchar, ctype in INSPECT.items():
        setattr(CConfig, field_names[fmtchar], rffi_platform.Struct(
            "struct about_%s" % (field_names[fmtchar],),
            [('field', lltype.FixedSizeArray(rffi.CHAR, 1))]))

    cConfig = rffi_platform.configure(CConfig)

    for fmtchar, ctype in INSPECT.items():
        S = cConfig[field_names[fmtchar]]
        alignment = rffi.offsetof(S, 'c_field')
        size = rffi.sizeof(S.c_field)
        signed = 'a' <= fmtchar <= 'z'

        if fmtchar == 'f':
            pack = pack_float
            unpack = std.unpack_float
        elif fmtchar == 'd':
            pack = pack_double
            unpack = std.unpack_double
        elif fmtchar == '?':
            pack = std.pack_bool
            unpack = std.unpack_bool
        else:
            pack = std.make_int_packer(size, signed)
            unpack = std.make_int_unpacker(size, signed)

        native_fmttable[fmtchar] = {'size': size,
                                    'alignment': alignment,
                                    'pack': pack,
                                    'unpack': unpack}

setup()

sizeof_double = native_fmttable['d']['size']
sizeof_float  = native_fmttable['f']['size']

# Copy CPython's behavior of using short's size and alignment for half-floats.
native_fmttable['e'] = {'size': native_fmttable['h']['size'],
                        'alignment': native_fmttable['h']['alignment'],
                        'pack': std.pack_halffloat,
                        'unpack': std.unpack_halffloat,
                       }

# ____________________________________________________________
#
# A PyPy extension: accepts the 'u' format character in native mode,
# just like the array module does.  (This is actually used in the
# implementation of our interp-level array module.)

from rpython.rlib.rstruct import unichar

def pack_unichar(fmtiter):
    utf8, lgt = fmtiter.accept_unicode_arg()
    if lgt != 1:
        raise StructError("expected a unicode string of length 1")
    uchr = rutf8.codepoint_at_pos(utf8, 0)
    unichar.pack_codepoint(uchr, fmtiter.wbuf, fmtiter.pos)
    fmtiter.advance(unichar.UNICODE_SIZE)

@specialize.argtype(0)
def unpack_unichar(fmtiter):
    data = fmtiter.read(unichar.UNICODE_SIZE)
    fmtiter.append_utf8(unichar.unpack_codepoint(data))

native_fmttable['u'] = {'size': unichar.UNICODE_SIZE,
                        'alignment': unichar.UNICODE_SIZE,
                        'pack': pack_unichar,
                        'unpack': unpack_unichar,
                        }
