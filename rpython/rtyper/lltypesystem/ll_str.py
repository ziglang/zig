from rpython.rtyper.lltypesystem.lltype import GcArray, Array, Char, malloc
from rpython.rlib.rarithmetic import r_uint, r_longlong, r_ulonglong
from rpython.rlib import jit

CHAR_ARRAY = GcArray(Char)

def ll_unsigned(i):
    if isinstance(i, r_longlong) or isinstance(i, r_ulonglong):
        return r_ulonglong(i)
    else:
        return r_uint(i)

@jit.elidable
def ll_int2dec(val):
    from rpython.rtyper.lltypesystem.rstr import mallocstr

    sign = int(val < 0)
    if sign:
        val = ll_unsigned(-val)
    else:
        val = ll_unsigned(val)
    len = 0
    i = val
    while i:
        len += 1
        i //= 10

    total_len = sign + len + int(val == 0)
    result = mallocstr(total_len)
    if sign:
        result.chars[0] = '-'
    elif val == 0:
        result.chars[0] = '0'

    j = 0
    while j < len:
        result.chars[total_len - j - 1] = chr(val % 10 + ord('0'))
        val //= 10
        j += 1
    return result

hex_chars = malloc(Array(Char), 16, immortal=True)

for i in range(16):
    hex_chars[i] = "%x" % i

@jit.elidable
def ll_int2hex(i, addPrefix):
    from rpython.rtyper.lltypesystem.rstr import mallocstr
    temp = malloc(CHAR_ARRAY, 20)
    len = 0
    sign = 0
    if i < 0:
        sign = 1
        i = ll_unsigned(-i)
    else:
        i = ll_unsigned(i)
    if i == 0:
        len = 1
        temp[0] = '0'
    else:
        while i:
            temp[len] = hex_chars[i & 0xf]
            i >>= 4
            len += 1
    len += sign
    if addPrefix:
        len += 2
    result = mallocstr(len)
    result.hash = 0
    j = 0
    if sign:
        result.chars[0] = '-'
        j = 1
    if addPrefix:
        result.chars[j] = '0'
        result.chars[j+1] = 'x'
        j += 2
    while j < len:
        result.chars[j] = temp[len-j-1]
        j += 1
    return result

@jit.elidable
def ll_int2oct(i, addPrefix):
    from rpython.rtyper.lltypesystem.rstr import mallocstr
    if i == 0:
        result = mallocstr(1)
        result.hash = 0
        result.chars[0] = '0'
        return result
    temp = malloc(CHAR_ARRAY, 25)
    len = 0
    sign = 0
    if i < 0:
        sign = 1
        i = ll_unsigned(-i)
    else:
        i = ll_unsigned(i)
    while i:
        temp[len] = hex_chars[i & 0x7]
        i >>= 3
        len += 1
    len += sign
    if addPrefix:
        len += 1
    result = mallocstr(len)
    result.hash = 0
    j = 0
    if sign:
        result.chars[0] = '-'
        j = 1
    if addPrefix:
        result.chars[j] = '0'
        j += 1
    while j < len:
        result.chars[j] = temp[len-j-1]
        j += 1
    return result
