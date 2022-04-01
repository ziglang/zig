# -*- coding: iso-8859-1 -*-
"""
RPython implementation of MD5 checksums.

See also the pure Python implementation in lib_pypy/md5.py, which might
or might not be faster than this one on top of CPython.

This is an implementation of the MD5 hash function,
as specified by RFC 1321. It was implemented using Bruce Schneier's
excellent book "Applied Cryptography", 2nd ed., 1996.

This module tries to follow the API of the CPython md5 module.

Long history:

    By Dinu C. Gherman.  BEWARE: this comes with no guarantee whatsoever
    about fitness and/or other properties! Specifically, do not use this
    in any production code! License is Python License!  (Re-licensing
    under the MIT would be great, though)

    Special thanks to Aurelian Coman who fixed some nasty bugs!

    Modernised by J. Hallén and L. Creighton for Pypy.

    Converted to RPython by arigo.
"""

from rpython.rlib.rarithmetic import r_uint, r_ulonglong


if r_uint.BITS == 32:
    def _rotateLeft(x, n):
        "Rotate x (32 bit) left n bits circularly."
        return (x << n) | (x >> (32-n))

else:
    def _rotateLeft_emulator(x, n):
        x &= 0xFFFFFFFF
        return (x << n) | (x >> (32-n))

    # ----- start of custom code, think about something better... -----
    from rpython.rtyper.lltypesystem import lltype, rffi
    from rpython.translator.tool.cbuild import ExternalCompilationInfo
    eci = ExternalCompilationInfo(post_include_bits=["""
static unsigned long pypy__rotateLeft(unsigned long x, long n) {
    unsigned int x1 = x;    /* arithmetic directly on int */
    int n1 = n;
    return (x1 << n1) | (x1 >> (32-n1));
}
"""])
    _rotateLeft = rffi.llexternal(
        "pypy__rotateLeft", [lltype.Unsigned, lltype.Signed], lltype.Unsigned,
        _callable=_rotateLeft_emulator, compilation_info=eci,
        _nowrapper=True, elidable_function=True)
    # we expect the function _rotateLeft to be actually inlined


def _state2string(a, b, c, d):
    return ''.join([
        chr(a&0xFF), chr((a>>8)&0xFF), chr((a>>16)&0xFF), chr((a>>24)&0xFF),
        chr(b&0xFF), chr((b>>8)&0xFF), chr((b>>16)&0xFF), chr((b>>24)&0xFF),
        chr(c&0xFF), chr((c>>8)&0xFF), chr((c>>16)&0xFF), chr((c>>24)&0xFF),
        chr(d&0xFF), chr((d>>8)&0xFF), chr((d>>16)&0xFF), chr((d>>24)&0xFF),
        ])

def _state2hexstring(a, b, c, d):
    hx = '0123456789abcdef'
    return ''.join([
        hx[(a>>4)&0xF],  hx[a&0xF],       hx[(a>>12)&0xF], hx[(a>>8)&0xF],
        hx[(a>>20)&0xF], hx[(a>>16)&0xF], hx[(a>>28)&0xF], hx[(a>>24)&0xF],
        hx[(b>>4)&0xF],  hx[b&0xF],       hx[(b>>12)&0xF], hx[(b>>8)&0xF],
        hx[(b>>20)&0xF], hx[(b>>16)&0xF], hx[(b>>28)&0xF], hx[(b>>24)&0xF],
        hx[(c>>4)&0xF],  hx[c&0xF],       hx[(c>>12)&0xF], hx[(c>>8)&0xF],
        hx[(c>>20)&0xF], hx[(c>>16)&0xF], hx[(c>>28)&0xF], hx[(c>>24)&0xF],
        hx[(d>>4)&0xF],  hx[d&0xF],       hx[(d>>12)&0xF], hx[(d>>8)&0xF],
        hx[(d>>20)&0xF], hx[(d>>16)&0xF], hx[(d>>28)&0xF], hx[(d>>24)&0xF],
        ])

def _string2uintlist(s, start, count, result):
    """Build a list of count r_uint's by unpacking the string
    s[start:start+4*count] in little-endian order.
    """
    for i in range(count):
        p = start + i * 4
        x = r_uint(ord(s[p]))
        x |= r_uint(ord(s[p+1])) << 8
        x |= r_uint(ord(s[p+2])) << 16
        x |= r_uint(ord(s[p+3])) << 24
        result[i] = x


# ======================================================================
# The real MD5 meat...
#
#   Implemented after "Applied Cryptography", 2nd ed., 1996,
#   pp. 436-441 by Bruce Schneier.
# ======================================================================

# F, G, H and I are basic MD5 functions.

def F(x, y, z):
    return (x & y) | ((~x) & z)

def G(x, y, z):
    return (x & z) | (y & (~z))

def H(x, y, z):
    return x ^ y ^ z

def I(x, y, z):
    return y ^ (x | (~z))


def XX(func, a, b, c, d, x, s, ac):
    """Wrapper for call distribution to functions F, G, H and I.

    This replaces functions FF, GG, HH and II from "Appl. Crypto."
    Rotation is separate from addition to prevent recomputation
    (now summed-up in one function).
    """

    res = a + func(b, c, d)
    res = res + x 
    res = res + ac
    res = _rotateLeft(res, s)
    res = res + b

    return res
XX._annspecialcase_ = 'specialize:arg(0)'     # performance hint


class RMD5(object):
    """RPython-level MD5 object.
    """
    def __init__(self, initialdata='', usedforsecurity=True):
        self._init()
        self.update(initialdata)


    def _init(self):
        """Set this object to an initial empty state.
        """
        self.count = r_ulonglong(0)   # total number of bytes
        self.input = ""   # pending unprocessed data, < 64 bytes
        self.uintbuffer = [r_uint(0)] * 16

        # Load magic initialization constants.
        self.A = r_uint(0x67452301L)
        self.B = r_uint(0xefcdab89L)
        self.C = r_uint(0x98badcfeL)
        self.D = r_uint(0x10325476L)


    def _transform(self, inp):
        """Basic MD5 step transforming the digest based on the input.

        Note that if the Mysterious Constants are arranged backwards
        in little-endian order and decrypted with the DES they produce
        OCCULT MESSAGES!
        """
        # 'inp' is a list of 16 r_uint values.

        a, b, c, d = A, B, C, D = self.A, self.B, self.C, self.D

        # Round 1.

        S11, S12, S13, S14 = 7, 12, 17, 22

        a = XX(F, a, b, c, d, inp[ 0], S11, r_uint(0xD76AA478L)) # 1 
        d = XX(F, d, a, b, c, inp[ 1], S12, r_uint(0xE8C7B756L)) # 2 
        c = XX(F, c, d, a, b, inp[ 2], S13, r_uint(0x242070DBL)) # 3 
        b = XX(F, b, c, d, a, inp[ 3], S14, r_uint(0xC1BDCEEEL)) # 4 
        a = XX(F, a, b, c, d, inp[ 4], S11, r_uint(0xF57C0FAFL)) # 5 
        d = XX(F, d, a, b, c, inp[ 5], S12, r_uint(0x4787C62AL)) # 6 
        c = XX(F, c, d, a, b, inp[ 6], S13, r_uint(0xA8304613L)) # 7 
        b = XX(F, b, c, d, a, inp[ 7], S14, r_uint(0xFD469501L)) # 8 
        a = XX(F, a, b, c, d, inp[ 8], S11, r_uint(0x698098D8L)) # 9 
        d = XX(F, d, a, b, c, inp[ 9], S12, r_uint(0x8B44F7AFL)) # 10 
        c = XX(F, c, d, a, b, inp[10], S13, r_uint(0xFFFF5BB1L)) # 11 
        b = XX(F, b, c, d, a, inp[11], S14, r_uint(0x895CD7BEL)) # 12 
        a = XX(F, a, b, c, d, inp[12], S11, r_uint(0x6B901122L)) # 13 
        d = XX(F, d, a, b, c, inp[13], S12, r_uint(0xFD987193L)) # 14 
        c = XX(F, c, d, a, b, inp[14], S13, r_uint(0xA679438EL)) # 15 
        b = XX(F, b, c, d, a, inp[15], S14, r_uint(0x49B40821L)) # 16 

        # Round 2.

        S21, S22, S23, S24 = 5, 9, 14, 20

        a = XX(G, a, b, c, d, inp[ 1], S21, r_uint(0xF61E2562L)) # 17 
        d = XX(G, d, a, b, c, inp[ 6], S22, r_uint(0xC040B340L)) # 18 
        c = XX(G, c, d, a, b, inp[11], S23, r_uint(0x265E5A51L)) # 19 
        b = XX(G, b, c, d, a, inp[ 0], S24, r_uint(0xE9B6C7AAL)) # 20 
        a = XX(G, a, b, c, d, inp[ 5], S21, r_uint(0xD62F105DL)) # 21 
        d = XX(G, d, a, b, c, inp[10], S22, r_uint(0x02441453L)) # 22 
        c = XX(G, c, d, a, b, inp[15], S23, r_uint(0xD8A1E681L)) # 23 
        b = XX(G, b, c, d, a, inp[ 4], S24, r_uint(0xE7D3FBC8L)) # 24 
        a = XX(G, a, b, c, d, inp[ 9], S21, r_uint(0x21E1CDE6L)) # 25 
        d = XX(G, d, a, b, c, inp[14], S22, r_uint(0xC33707D6L)) # 26 
        c = XX(G, c, d, a, b, inp[ 3], S23, r_uint(0xF4D50D87L)) # 27 
        b = XX(G, b, c, d, a, inp[ 8], S24, r_uint(0x455A14EDL)) # 28 
        a = XX(G, a, b, c, d, inp[13], S21, r_uint(0xA9E3E905L)) # 29 
        d = XX(G, d, a, b, c, inp[ 2], S22, r_uint(0xFCEFA3F8L)) # 30 
        c = XX(G, c, d, a, b, inp[ 7], S23, r_uint(0x676F02D9L)) # 31 
        b = XX(G, b, c, d, a, inp[12], S24, r_uint(0x8D2A4C8AL)) # 32 

        # Round 3.

        S31, S32, S33, S34 = 4, 11, 16, 23

        a = XX(H, a, b, c, d, inp[ 5], S31, r_uint(0xFFFA3942L)) # 33 
        d = XX(H, d, a, b, c, inp[ 8], S32, r_uint(0x8771F681L)) # 34 
        c = XX(H, c, d, a, b, inp[11], S33, r_uint(0x6D9D6122L)) # 35 
        b = XX(H, b, c, d, a, inp[14], S34, r_uint(0xFDE5380CL)) # 36 
        a = XX(H, a, b, c, d, inp[ 1], S31, r_uint(0xA4BEEA44L)) # 37 
        d = XX(H, d, a, b, c, inp[ 4], S32, r_uint(0x4BDECFA9L)) # 38 
        c = XX(H, c, d, a, b, inp[ 7], S33, r_uint(0xF6BB4B60L)) # 39 
        b = XX(H, b, c, d, a, inp[10], S34, r_uint(0xBEBFBC70L)) # 40 
        a = XX(H, a, b, c, d, inp[13], S31, r_uint(0x289B7EC6L)) # 41 
        d = XX(H, d, a, b, c, inp[ 0], S32, r_uint(0xEAA127FAL)) # 42 
        c = XX(H, c, d, a, b, inp[ 3], S33, r_uint(0xD4EF3085L)) # 43 
        b = XX(H, b, c, d, a, inp[ 6], S34, r_uint(0x04881D05L)) # 44 
        a = XX(H, a, b, c, d, inp[ 9], S31, r_uint(0xD9D4D039L)) # 45 
        d = XX(H, d, a, b, c, inp[12], S32, r_uint(0xE6DB99E5L)) # 46 
        c = XX(H, c, d, a, b, inp[15], S33, r_uint(0x1FA27CF8L)) # 47 
        b = XX(H, b, c, d, a, inp[ 2], S34, r_uint(0xC4AC5665L)) # 48 

        # Round 4.

        S41, S42, S43, S44 = 6, 10, 15, 21

        a = XX(I, a, b, c, d, inp[ 0], S41, r_uint(0xF4292244L)) # 49 
        d = XX(I, d, a, b, c, inp[ 7], S42, r_uint(0x432AFF97L)) # 50 
        c = XX(I, c, d, a, b, inp[14], S43, r_uint(0xAB9423A7L)) # 51 
        b = XX(I, b, c, d, a, inp[ 5], S44, r_uint(0xFC93A039L)) # 52 
        a = XX(I, a, b, c, d, inp[12], S41, r_uint(0x655B59C3L)) # 53 
        d = XX(I, d, a, b, c, inp[ 3], S42, r_uint(0x8F0CCC92L)) # 54 
        c = XX(I, c, d, a, b, inp[10], S43, r_uint(0xFFEFF47DL)) # 55 
        b = XX(I, b, c, d, a, inp[ 1], S44, r_uint(0x85845DD1L)) # 56 
        a = XX(I, a, b, c, d, inp[ 8], S41, r_uint(0x6FA87E4FL)) # 57 
        d = XX(I, d, a, b, c, inp[15], S42, r_uint(0xFE2CE6E0L)) # 58 
        c = XX(I, c, d, a, b, inp[ 6], S43, r_uint(0xA3014314L)) # 59 
        b = XX(I, b, c, d, a, inp[13], S44, r_uint(0x4E0811A1L)) # 60 
        a = XX(I, a, b, c, d, inp[ 4], S41, r_uint(0xF7537E82L)) # 61 
        d = XX(I, d, a, b, c, inp[11], S42, r_uint(0xBD3AF235L)) # 62 
        c = XX(I, c, d, a, b, inp[ 2], S43, r_uint(0x2AD7D2BBL)) # 63 
        b = XX(I, b, c, d, a, inp[ 9], S44, r_uint(0xEB86D391L)) # 64 

        A += a
        B += b
        C += c
        D += d

        self.A, self.B, self.C, self.D = A, B, C, D


    def _finalize(self, digestfunc):
        """Logic to add the final padding and extract the digest.
        """
        # Save the state before adding the padding
        count = self.count
        input = self.input
        A = self.A
        B = self.B
        C = self.C
        D = self.D

        index = len(input)
        if index < 56:
            padLen = 56 - index
        else:
            padLen = 120 - index

        if padLen:
            self.update('\200' + '\000' * (padLen-1))

        # Append length (before padding).
        assert len(self.input) == 56
        W = self.uintbuffer
        _string2uintlist(self.input, 0, 14, W)
        length_in_bits = count << 3
        W[14] = r_uint(length_in_bits)
        W[15] = r_uint(length_in_bits >> 32)
        self._transform(W)

        # Store state in digest.
        digest = digestfunc(self.A, self.B, self.C, self.D)

        # Restore the saved state in case this instance is still used
        self.count = count
        self.input = input
        self.A = A 
        self.B = B
        self.C = C
        self.D = D

        return digest


    # Down from here all methods follow the Python Standard Library
    # API of the md5 module.

    def update(self, inBuf):
        """Add to the current message.

        Update the md5 object with the string arg. Repeated calls
        are equivalent to a single call with the concatenation of all
        the arguments, i.e. m.update(a); m.update(b) is equivalent
        to m.update(a+b).

        The hash is immediately calculated for all full blocks. The final
        calculation is made in digest(). This allows us to keep an
        intermediate value for the hash, so that we only need to make
        minimal recalculation if we call update() to add moredata to
        the hashed string.
        """

        leninBuf = len(inBuf)
        self.count += leninBuf
        index = len(self.input)
        partLen = 64 - index
        assert partLen > 0

        if leninBuf >= partLen:
            W = self.uintbuffer
            self.input = self.input + inBuf[:partLen]
            _string2uintlist(self.input, 0, 16, W)
            self._transform(W)
            i = partLen
            while i + 64 <= leninBuf:
                _string2uintlist(inBuf, i, 16, W)
                self._transform(W)
                i = i + 64
            else:
                self.input = inBuf[i:leninBuf]
        else:
            self.input = self.input + inBuf


    def digest(self):
        """Terminate the message-digest computation and return digest.

        Return the digest of the strings passed to the update()
        method so far. This is a 16-byte string which may contain
        non-ASCII characters, including null bytes.
        """
        return self._finalize(_state2string)


    def hexdigest(self):
        """Terminate and return digest in HEX form.

        Like digest() except the digest is returned as a string of
        length 32, containing only hexadecimal digits. This may be
        used to exchange the value safely in email or other non-
        binary environments.
        """
        return self._finalize(_state2hexstring)


    def copy(self):
        """Return a clone object.

        Return a copy ('clone') of the md5 object. This can be used
        to efficiently compute the digests of strings that share
        a common initial substring.
        """
        clone = RMD5()
        clone._copyfrom(self)
        return clone

    def _copyfrom(self, other):
        """Copy all state from 'other' into 'self'.
        """
        self.count = other.count
        self.input = other.input
        self.A = other.A
        self.B = other.B
        self.C = other.C
        self.D = other.D

# synonyms to build new RMD5 objects, for compatibility with the
# CPython md5 module interface.
md5 = RMD5
new = RMD5
digest_size = 16
