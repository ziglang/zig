from __future__ import with_statement
from rpython.rlib import rfloat
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator import cdir
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import jit, objectmodel
from rpython.rlib.rstring import StringBuilder
import py, sys

cdir = py.path.local(cdir)
include_dirs = [cdir]

# set the word endianness based on the host's endianness
# and the C double's endianness (which should be equal)
if hasattr(float, '__getformat__'):
    assert float.__getformat__('double') == 'IEEE, %s-endian' % sys.byteorder
if sys.byteorder == 'little':
    source_file = ['#define DOUBLE_IS_LITTLE_ENDIAN_IEEE754']
elif sys.byteorder == 'big':
    source_file = ['#define WORDS_BIGENDIAN',
                   '#define DOUBLE_IS_BIG_ENDIAN_IEEE754']
else:
    raise AssertionError(sys.byteorder)

source_file.append('#include "src/dtoa.c"')
source_file = '\n\n'.join(source_file)

# ____________________________________________________________

eci = ExternalCompilationInfo(
    include_dirs = [cdir],
    includes = ['src/dtoa.h'],
    libraries = [],
    separate_module_sources = [source_file],
    )

# dtoa.c is limited to 'int', so we refuse to pass it
# strings or integer arguments bigger than ~2GB
_INT_LIMIT = 0x7ffff000

dg_strtod = rffi.llexternal(
    '_PyPy_dg_strtod', [rffi.CONST_CCHARP, rffi.CCHARPP], rffi.DOUBLE,
    compilation_info=eci, sandboxsafe=True)

dg_dtoa = rffi.llexternal(
    '_PyPy_dg_dtoa', [rffi.DOUBLE, rffi.INT, rffi.INT,
                    rffi.INTP, rffi.INTP, rffi.CCHARPP], rffi.CCHARP,
    compilation_info=eci, sandboxsafe=True)

dg_freedtoa = rffi.llexternal(
    '_PyPy_dg_freedtoa', [rffi.CCHARP], lltype.Void,
    compilation_info=eci, sandboxsafe=True)

def strtod(input):
    if len(input) > _INT_LIMIT:
        raise MemoryError
    if objectmodel.revdb_flag_io_disabled():
        return _revdb_strtod(input)
    end_ptr = lltype.malloc(rffi.CCHARPP.TO, 1, flavor='raw')
    try:
        # note: don't use the class scoped_view_charp here, it
        # break some tests because this function is used by the GC
        ll_input, llobj, flag = rffi.get_nonmovingbuffer_ll_final_null(input)
        try:
            result = dg_strtod(rffi.cast(rffi.CONST_CCHARP, ll_input), end_ptr)

            endpos = (rffi.cast(lltype.Signed, end_ptr[0]) -
                      rffi.cast(lltype.Signed, ll_input))
        finally:
            rffi.free_nonmovingbuffer_ll(ll_input, llobj, flag)
    finally:
        lltype.free(end_ptr, flavor='raw')

    if endpos == 0 or endpos < len(input):
        raise ValueError("invalid input at position %d" % (endpos,))

    return result

lower_special_strings = ['inf', '+inf', '-inf', 'nan']
upper_special_strings = ['INF', '+INF', '-INF', 'NAN']

def format_nonfinite(digits, sign, flags, special_strings):
    "Format dtoa's output for nonfinite numbers"
    if digits[0] == 'i' or digits[0] == 'I':
        if sign == 1:
            return special_strings[2]
        elif flags & rfloat.DTSF_SIGN:
            return special_strings[1]
        else:
            return special_strings[0]
    elif digits[0] == 'n' or digits[0] == 'N':
        return special_strings[3]
    else:
        # shouldn't get here
        raise ValueError

@jit.dont_look_inside
def format_number(digits, buflen, sign, decpt, code, precision, flags, upper):
    # We got digits back, format them.  We may need to pad 'digits'
    # either on the left or right (or both) with extra zeros, so in
    # general the resulting string has the form
    #
    # [<sign>]<zeros><digits><zeros>[<exponent>]
    #
    # where either of the <zeros> pieces could be empty, and there's a
    # decimal point that could appear either in <digits> or in the
    # leading or trailing <zeros>.
    #
    # Imagine an infinite 'virtual' string vdigits, consisting of the
    # string 'digits' (starting at index 0) padded on both the left
    # and right with infinite strings of zeros.  We want to output a
    # slice
    #
    # vdigits[vdigits_start : vdigits_end]
    #
    # of this virtual string.  Thus if vdigits_start < 0 then we'll
    # end up producing some leading zeros; if vdigits_end > digits_len
    # there will be trailing zeros in the output.  The next section of
    # code determines whether to use an exponent or not, figures out
    # the position 'decpt' of the decimal point, and computes
    # 'vdigits_start' and 'vdigits_end'.
    builder = StringBuilder(20)

    use_exp = False
    vdigits_end = buflen
    if code == 'e':
        use_exp = True
        vdigits_end = precision
    elif code == 'f':
        vdigits_end = decpt + precision
    elif code == 'g':
        if decpt <= -4:
            use_exp = True
        elif decpt > precision:
            use_exp = True
        elif flags & rfloat.DTSF_ADD_DOT_0 and decpt == precision:
            use_exp = True
        if flags & rfloat.DTSF_ALT:
            vdigits_end = precision
    elif code == 'r':
        #  convert to exponential format at 1e16.  We used to convert
        #  at 1e17, but that gives odd-looking results for some values
        #  when a 16-digit 'shortest' repr is padded with bogus zeros.
        #  For example, repr(2e16+8) would give 20000000000000010.0;
        #  the true value is 20000000000000008.0.
        if decpt <= -4 or decpt > 16:
            use_exp = True
    else:
        raise ValueError

    # if using an exponent, reset decimal point position to 1 and
    # adjust exponent accordingly.
    if use_exp:
        exp = decpt - 1
        decpt = 1
    else:
        exp = 0

    # ensure vdigits_start < decpt <= vdigits_end, or vdigits_start <
    # decpt < vdigits_end if add_dot_0_if_integer and no exponent
    if decpt <= 0:
        vdigits_start = decpt-1
    else:
        vdigits_start = 0
    if vdigits_end <= decpt:
        if not use_exp and flags & rfloat.DTSF_ADD_DOT_0:
            vdigits_end = decpt + 1
        else:
            vdigits_end = decpt

    # double check inequalities
    assert vdigits_start <= 0
    assert 0 <= buflen <= vdigits_end
    # decimal point should be in (vdigits_start, vdigits_end]
    assert vdigits_start < decpt <= vdigits_end

    if sign == 1:
        builder.append('-')
    elif flags & rfloat.DTSF_SIGN:
        builder.append('+')

    # note that exactly one of the three 'if' conditions is true, so
    # we include exactly one decimal point
    # 1. Zero padding on left of digit string
    if decpt <= 0:
        builder.append_multiple_char('0', decpt - vdigits_start)
        builder.append('.')
        builder.append_multiple_char('0', 0 - decpt)
    else:
        builder.append_multiple_char('0', 0 - vdigits_start)

    # 2. Digits, with included decimal point
    if 0 < decpt <= buflen:
        builder.append(rffi.charpsize2str(digits, decpt - 0))
        builder.append('.')
        ptr = rffi.ptradd(digits, decpt)
        builder.append(rffi.charpsize2str(ptr, buflen - decpt))
    else:
        builder.append(rffi.charpsize2str(digits, buflen))

    # 3. And zeros on the right
    if buflen < decpt:
        builder.append_multiple_char('0', decpt - buflen)
        builder.append('.')
        builder.append_multiple_char('0', vdigits_end - decpt)
    else:
        builder.append_multiple_char('0', vdigits_end - buflen)

    s = builder.build()

    # Delete a trailing decimal pt unless using alternative formatting.
    if not flags & rfloat.DTSF_ALT:
        last = len(s) - 1
        if last >= 0 and s[last] == '.':
            s = s[:last]

    # Now that we've done zero padding, add an exponent if needed.
    if use_exp:
        if upper:
            e = 'E'
        else:
            e = 'e'

        if exp >= 0:
            exp_str = str(exp)
            if len(exp_str) < 2 and not (flags & rfloat.DTSF_CUT_EXP_0):
                s += e + '+0' + exp_str
            else:
                s += e + '+' + exp_str
        else:
            exp_str = str(-exp)
            if len(exp_str) < 2 and not (flags & rfloat.DTSF_CUT_EXP_0):
                s += e + '-0' + exp_str
            else:
                s += e + '-' + exp_str

    return s

def dtoa(value, code='r', mode=0, precision=0, flags=0,
         special_strings=lower_special_strings, upper=False):
    if precision > _INT_LIMIT:
        raise MemoryError
    if objectmodel.revdb_flag_io_disabled():
        return _revdb_dtoa(value)
    decpt_ptr = lltype.malloc(rffi.INTP.TO, 1, flavor='raw')
    try:
        sign_ptr = lltype.malloc(rffi.INTP.TO, 1, flavor='raw')
        try:
            end_ptr = lltype.malloc(rffi.CCHARPP.TO, 1, flavor='raw')
            try:
                digits = dg_dtoa(value, mode, precision,
                                     decpt_ptr, sign_ptr, end_ptr)
                if not digits:
                    # The only failure mode is no memory
                    raise MemoryError
                try:
                    buflen = (rffi.cast(lltype.Signed, end_ptr[0]) -
                              rffi.cast(lltype.Signed, digits))
                    sign = rffi.cast(lltype.Signed, sign_ptr[0])

                    # Handle nan and inf
                    if buflen and not digits[0].isdigit():
                        return format_nonfinite(digits, sign, flags,
                                                special_strings)

                    decpt = rffi.cast(lltype.Signed, decpt_ptr[0])

                    return format_number(digits, buflen, sign, decpt,
                                         code, precision, flags, upper)

                finally:
                    dg_freedtoa(digits)
            finally:
                lltype.free(end_ptr, flavor='raw')
        finally:
            lltype.free(sign_ptr, flavor='raw')
    finally:
        lltype.free(decpt_ptr, flavor='raw')

def dtoa_formatd(value, code, precision, flags):
    if code in 'EFG':
        code = code.lower()
        special_strings = upper_special_strings
        upper = True
    else:
        special_strings = lower_special_strings
        upper = False

    if code == 'e':
        mode = 2
        precision += 1
    elif code == 'f':
        mode = 3
    elif code == 'g':
        mode = 2
        # precision 0 makes no sense for 'g' format; interpret as 1
        if precision == 0:
            precision = 1
    elif code == 'r':
        # repr format
        mode = 0
        assert precision == 0
    else:
        raise ValueError('Invalid mode')

    return dtoa(value, code, mode=mode, precision=precision, flags=flags,
                special_strings=special_strings, upper=upper)

def _revdb_strtod(input):
    # moved in its own function for the import statement
    from rpython.rlib import revdb
    return revdb.emulate_strtod(input)

def _revdb_dtoa(value):
    # moved in its own function for the import statement
    from rpython.rlib import revdb
    return revdb.emulate_dtoa(value)
