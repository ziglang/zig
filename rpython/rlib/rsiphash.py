"""
This module implements siphash-2-4, the hashing algorithm for strings
and unicodes.  You can use it explicitly by calling siphash24() with
a byte string, or you can use enable_siphash24() to enable the use
of siphash-2-4 on all RPython strings and unicodes in your program
after translation.
"""
import sys, os, errno
from contextlib import contextmanager
from rpython.rlib import rarithmetic, rurandom
from rpython.rlib.objectmodel import not_rpython, always_inline
from rpython.rlib.objectmodel import we_are_translated, dont_inline
from rpython.rlib.objectmodel import keepalive_until_here
from rpython.rlib.objectmodel import specialize
from rpython.rlib import rgc, jit, rposix
from rpython.rlib.rarithmetic import r_uint64, r_uint32, r_uint
from rpython.rlib.rawstorage import misaligned_is_fine
from rpython.rlib.nonconst import NonConstant
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi, rstr
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.annlowlevel import llhelper


if sys.byteorder == 'little':
    def _le64toh(x):
        return x
    def _le32toh(x):
        return x
    BIG_ENDIAN = False
else:
    _le64toh = rarithmetic.byteswap
    _le32toh = rarithmetic.byteswap
    BIG_ENDIAN = True

def _decode64(s):
    return (r_uint64(ord(s[0])) |
            r_uint64(ord(s[1])) << 8 |
            r_uint64(ord(s[2])) << 16 |
            r_uint64(ord(s[3])) << 24 |
            r_uint64(ord(s[4])) << 32 |
            r_uint64(ord(s[5])) << 40 |
            r_uint64(ord(s[6])) << 48 |
            r_uint64(ord(s[7])) << 56)

class Seed:
    k0l = k1l = r_uint64(0)
seed = Seed()


def select_random_seed(s):
    """'s' is a string of length 16"""
    seed.k0l = _decode64(s)
    seed.k1l = _decode64(s[8:16])
    _update_prebuilt_hashes()


random_ctx = rurandom.init_urandom()
strtoul = rffi.llexternal("strtoul", [rffi.CCHARP, rffi.CCHARPP, rffi.INT],
                          rffi.ULONG, save_err=rffi.RFFI_SAVE_ERRNO)

env_var_name = "PYTHONHASHSEED"

def initialize_from_env():
    # This uses the same algorithms as CPython 3.5.  The environment
    # variable we read also defaults to "PYTHONHASHSEED".  If needed,
    # a different RPython interpreter can patch the value of the
    # global variable 'env_var_name', or just patch the whole
    # initialize_from_env() function.
    value = os.environ.get(env_var_name)
    if value and value != "random":
        with rffi.scoped_view_charp(value) as ptr:
            with lltype.scoped_alloc(rffi.CCHARPP.TO, 1) as endptr:
                endptr[0] = ptr
                seed = strtoul(ptr, endptr, 10)
                full = endptr[0][0] == '\x00'
        seed = lltype.cast_primitive(lltype.Unsigned, seed)
        if not full or seed > r_uint(4294967295) or (
            rposix.get_saved_errno() == errno.ERANGE and
            seed == lltype.cast_primitive(lltype.Unsigned,
                                          rffi.cast(rffi.ULONG, -1))):
            os.write(2,
                "%s must be \"random\" or an integer "
                "in range [0; 4294967295]\n" % (env_var_name,))
            os._exit(1)
        if not seed:
            # disable the randomized hash
            s = '\x00' * 16
        else:
            s = lcg_urandom(seed)
    else:
        try:
            s = rurandom.urandom(random_ctx, 16)
        except Exception as e:
            os.write(2,
                "%s: failed to get random numbers to initialize Python\n" %
                (str(e),))
            os._exit(1)
            raise   # makes the annotator happy
    select_random_seed(s)

def lcg_urandom(x):
    s = ''
    for index in range(16):
        x *= 214013
        x += 2531011
        s += chr((x >> 16) & 0xff)
    return s


_FUNC = lltype.Ptr(lltype.FuncType([], lltype.Void))

def enable_siphash24():
    """
    Enable the use of siphash-2-4 for all RPython strings and unicodes
    in the translated program.  You must call this function anywhere
    from your interpreter (from a place that is annotated).  Don't call
    more than once.
    """

class Entry(ExtRegistryEntry):
    _about_ = enable_siphash24

    def compute_result_annotation(self):
        translator = self.bookkeeper.annotator.translator
        # you should not call enable_siphash24() when translating with the
        # reverse-debugger, or with sandbox.
        assert not translator.config.translation.reverse_debugger
        assert not translator.config.translation.sandbox
        #
        if hasattr(translator, 'll_hash_string'):
            assert translator.ll_hash_string == ll_hash_string_siphash24
        else:
            translator.ll_hash_string = ll_hash_string_siphash24
        bk = self.bookkeeper
        s_callable = bk.immutablevalue(initialize_from_env)
        key = (enable_siphash24,)
        bk.emulate_pbc_call(key, s_callable, [])

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        translator = hop.rtyper.annotator.translator
        if translator.config.translation.reverse_debugger:
            return    # ignore and use the regular hash, with reverse-debugger
        bk = hop.rtyper.annotator.bookkeeper
        s_callable = bk.immutablevalue(initialize_from_env)
        r_callable = hop.rtyper.getrepr(s_callable)
        ll_init = r_callable.get_unique_llfn().value
        bk.annotator.translator._call_at_startup.append(ll_init)


@rgc.no_collect
def ll_hash_string_siphash24(ll_s):
    """Called indirectly from lltypesystem/rstr.py, by redirection from
    objectmodel.ll_string_hash().
    """
    from rpython.rlib.rarithmetic import intmask

    # This function is entirely @rgc.no_collect.
    length = len(ll_s.chars)
    if lltype.typeOf(ll_s).TO.chars.OF == lltype.Char:   # regular STR
        addr = rstr._get_raw_buf_string(rstr.STR, ll_s, 0)
    else:
        # NOTE: a latin-1 unicode string must have the same hash as the
        # corresponding byte string.  If the unicode is all within
        # 0-255, then we call _siphash24() with a special argument that
        # will make it load only one byte for every unicode char.
        # Note also that we give a
        # different hash result than CPython on ucs4 platforms, for
        # unicode strings where CPython uses 2 bytes per character.
        addr = rstr._get_raw_buf_unicode(rstr.UNICODE, ll_s, 0)
        SZ = rffi.sizeof(rstr.UNICODE.chars.OF)
        i = 0
        while i < length:
            if ord(ll_s.chars[i]) > 0xFF:
                length *= SZ
                break
            i += 1
        else:
            x = _siphash24(addr, length, SZ)
            keepalive_until_here(ll_s)
            return intmask(x)
    x = _siphash24(addr, length)
    keepalive_until_here(ll_s)
    return intmask(x)


@contextmanager
def choosen_seed(new_k0, new_k1, test_misaligned_path=False,
                 test_prebuilt=False):
    """For tests."""
    global misaligned_is_fine, seed
    old = seed, misaligned_is_fine
    seed = Seed()
    seed.k0l = r_uint64(new_k0)
    seed.k1l = r_uint64(new_k1)
    if test_prebuilt:
        _update_prebuilt_hashes()
    else:
        seed.bound_prebuilt_size = 0
    if test_misaligned_path:
        misaligned_is_fine = False
    yield
    seed, misaligned_is_fine = old

magic0 = r_uint64(0x736f6d6570736575)
magic1 = r_uint64(0x646f72616e646f6d)
magic2 = r_uint64(0x6c7967656e657261)
magic3 = r_uint64(0x7465646279746573)


@always_inline
def _rotate(x, b):
    return (x << b) | (x >> (64 - b))

@always_inline
def _half_round(a, b, c, d, s, t):
    a += b
    c += d
    b = _rotate(b, s) ^ a
    d = _rotate(d, t) ^ c
    a = _rotate(a, 32)
    return a, b, c, d

@always_inline
def _double_round(v0, v1, v2, v3):
    v0,v1,v2,v3 = _half_round(v0,v1,v2,v3,13,16)
    v2,v1,v0,v3 = _half_round(v2,v1,v0,v3,17,21)
    v0,v1,v2,v3 = _half_round(v0,v1,v2,v3,13,16)
    v2,v1,v0,v3 = _half_round(v2,v1,v0,v3,17,21)
    return v0, v1, v2, v3


@rgc.no_collect
@specialize.arg(2)
def _siphash24(addr_in, size, SZ=1):
    """Takes an address pointer and a size.  Returns the hash as a r_uint64,
    which can then be casted to the expected type."""

    if size < seed.bound_prebuilt_size:
        if size <= 0:
            return seed.hash_empty
        else:
            if BIG_ENDIAN:
                index = SZ - 1
            else:
                index = 0
            t = rarithmetic.intmask(llop.raw_load(rffi.UCHAR, addr_in, index))
            return seed.hash_single[t]

    k0 = seed.k0l
    k1 = seed.k1l
    return _siphash24_with_key(addr_in, size, k0, k1, SZ)


@rgc.no_collect
@specialize.arg(4)
def _siphash24_with_key(addr_in, size, k0, k1, SZ=1):
    if BIG_ENDIAN:
        index = SZ - 1
    else:
        index = 0
    b = r_uint64(size) << 56
    v0 = k0 ^ magic0
    v1 = k1 ^ magic1
    v2 = k0 ^ magic2
    v3 = k1 ^ magic3

    direct = (SZ == 1) and (misaligned_is_fine or
                 (rffi.cast(lltype.Signed, addr_in) & 7) == 0)
    if direct:
        assert SZ == 1
        while size >= 8:
            mi = llop.raw_load(rffi.ULONGLONG, addr_in, index)
            mi = _le64toh(mi)
            size -= 8
            index += 8
            v3 ^= mi
            v0, v1, v2, v3 = _double_round(v0, v1, v2, v3)
            v0 ^= mi
    else:
        while size >= 8:
            mi = (
              r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index)) |
              r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 1*SZ)) << 8 |
              r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 2*SZ)) << 16 |
              r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 3*SZ)) << 24 |
              r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 4*SZ)) << 32 |
              r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 5*SZ)) << 40 |
              r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 6*SZ)) << 48 |
              r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 7*SZ)) << 56
            )
            size -= 8
            index += 8*SZ
            v3 ^= mi
            v0, v1, v2, v3 = _double_round(v0, v1, v2, v3)
            v0 ^= mi

    t = r_uint64(0)
    if size == 7:
        t = r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 6*SZ)) << 48
        size = 6
    if size == 6:
        t |= r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 5*SZ)) << 40
        size = 5
    if size == 5:
        t |= r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 4*SZ)) << 32
        size = 4
    if size == 4:
        if direct:
            v = _le32toh(r_uint32(llop.raw_load(rffi.UINT, addr_in, index)))
            t |= r_uint64(v)
            size = 0
        else:
            t |= r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 3*SZ))<< 24
            size = 3
    if size == 3:
        t |= r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 2*SZ)) << 16
        size = 2
    if size == 2:
        t |= r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index + 1*SZ)) << 8
        size = 1
    if size == 1:
        t |= r_uint64(llop.raw_load(rffi.UCHAR, addr_in, index))
        size = 0
    assert size == 0

    b |= t

    v3 ^= b
    v0, v1, v2, v3 = _double_round(v0, v1, v2, v3)
    v0 ^= b
    v2 ^= 0xff
    v0, v1, v2, v3 = _double_round(v0, v1, v2, v3)
    v0, v1, v2, v3 = _double_round(v0, v1, v2, v3)

    return (v0 ^ v1) ^ (v2 ^ v3)


@jit.dont_look_inside
def siphash24(s):
    """'s' is a normal string.  Returns its siphash-2-4 as a r_uint64.
    Don't forget to cast the result to a regular integer if needed,
    e.g. with rarithmetic.intmask().
    """
    with rffi.scoped_nonmovingbuffer(s) as p:
        return _siphash24(llmemory.cast_ptr_to_adr(p), len(s))

@jit.dont_look_inside
def siphash24_with_key(s, k0, k1=0):
    """'s' is a normal string.  k0 and k1 are the seed keys
    """
    with rffi.scoped_nonmovingbuffer(s) as p:
        return _siphash24_with_key(llmemory.cast_ptr_to_adr(p), len(s), k0, k1)

# Prebuilt hashes are precomputed here
def _update_prebuilt_hashes():
    seed.bound_prebuilt_size = 0
    with lltype.scoped_alloc(rffi.CCHARP.TO, 1) as p:
        addr = llmemory.cast_ptr_to_adr(p)
        seed.hash_single = [r_uint64(0)] * 256
        for i in range(256):
            p[0] = chr(i)
            seed.hash_single[i] = _siphash24(addr, 1)
        seed.hash_empty = _siphash24(addr, 0)
    seed.bound_prebuilt_size = 2
_update_prebuilt_hashes()
