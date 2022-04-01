from rpython.rtyper.lltypesystem import llmemory
from rpython.rlib.rarithmetic import r_uint, intmask

def adr2int(addr):
    """
    Cast an address to an int.

    Returns an AddressAsInt object which can be cast back to an address.
    """
    return llmemory.cast_adr_to_int(addr, "symbolic")

def int2adr(int):
    """
    Cast an int back to an address.

    Inverse of adr2int().
    """
    return llmemory.cast_int_to_adr(int)

def ptr2int(ptr):
    """
    Cast a pointer to int.

    Returns an AddressAsInt object.
    """
    addr = llmemory.cast_ptr_to_adr(ptr)
    return llmemory.cast_adr_to_int(addr, "symbolic")
ptr2int._annspecialcase_ = 'specialize:arglltype(0)'

def int_signext(value, numbytes):
    b8 = numbytes * 8
    a = r_uint(value)
    a += r_uint(1 << (b8 - 1))     # a += 128
    a &= r_uint((1 << b8) - 1)     # a &= 255
    a -= r_uint(1 << (b8 - 1))     # a -= 128
    return intmask(a)
