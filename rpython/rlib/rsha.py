# -*- coding: iso-8859-1 -*-

"""A sample implementation of SHA-1 in RPython.

   See also the pure Python implementation in lib_pypy/sha.py, which might
   or might not be faster than this one on top of CPython.

   Framework adapted from Dinu Gherman's MD5 implementation by
   J. Hallén and L. Creighton. SHA-1 implementation based directly on
   the text of the NIST standard FIPS PUB 180-1.

   Modernised by J. Hallén and L. Creighton for Pypy,
   converted to RPython by arigo.
"""

from rpython.rlib.rarithmetic import r_uint, r_ulonglong
from rpython.rlib.unroll import unrolling_iterable

# We reuse helpers from rmd5 too
from rpython.rlib.rmd5 import _rotateLeft


def _state2string(a, b, c, d, e):
    return ''.join([
        chr((a>>24)&0xFF), chr((a>>16)&0xFF), chr((a>>8)&0xFF), chr(a&0xFF),
        chr((b>>24)&0xFF), chr((b>>16)&0xFF), chr((b>>8)&0xFF), chr(b&0xFF),
        chr((c>>24)&0xFF), chr((c>>16)&0xFF), chr((c>>8)&0xFF), chr(c&0xFF),
        chr((d>>24)&0xFF), chr((d>>16)&0xFF), chr((d>>8)&0xFF), chr(d&0xFF),
        chr((e>>24)&0xFF), chr((e>>16)&0xFF), chr((e>>8)&0xFF), chr(e&0xFF),
        ])

def _state2hexstring(a, b, c, d, e):
    hx = '0123456789abcdef'
    return ''.join([
        hx[(a>>28)&0xF], hx[(a>>24)&0xF], hx[(a>>20)&0xF], hx[(a>>16)&0xF],
        hx[(a>>12)&0xF], hx[(a>>8)&0xF],  hx[(a>>4)&0xF],  hx[a&0xF],
        hx[(b>>28)&0xF], hx[(b>>24)&0xF], hx[(b>>20)&0xF], hx[(b>>16)&0xF],
        hx[(b>>12)&0xF], hx[(b>>8)&0xF],  hx[(b>>4)&0xF],  hx[b&0xF],
        hx[(c>>28)&0xF], hx[(c>>24)&0xF], hx[(c>>20)&0xF], hx[(c>>16)&0xF],
        hx[(c>>12)&0xF], hx[(c>>8)&0xF],  hx[(c>>4)&0xF],  hx[c&0xF],
        hx[(d>>28)&0xF], hx[(d>>24)&0xF], hx[(d>>20)&0xF], hx[(d>>16)&0xF],
        hx[(d>>12)&0xF], hx[(d>>8)&0xF],  hx[(d>>4)&0xF],  hx[d&0xF],
        hx[(e>>28)&0xF], hx[(e>>24)&0xF], hx[(e>>20)&0xF], hx[(e>>16)&0xF],
        hx[(e>>12)&0xF], hx[(e>>8)&0xF],  hx[(e>>4)&0xF],  hx[e&0xF],
        ])

def _string2uintlist(s, start, count, result):
    """Build a list of count r_uint's by unpacking the string
    s[start:start+4*count] in big-endian order.
    """
    for i in range(count):
        p = start + i * 4
        x = r_uint(ord(s[p+3]))
        x |= r_uint(ord(s[p+2])) << 8
        x |= r_uint(ord(s[p+1])) << 16
        x |= r_uint(ord(s[p])) << 24
        result[i] = x


# ======================================================================
# The SHA transformation functions
#
# ======================================================================

UNROLL_ALL = True    # this algorithm should be fastest & biggest


def f0_19(B, C, D):
    return (B & C) | ((~ B) & D)

def f20_39(B, C, D):
    return B ^ C ^ D

def f40_59(B, C, D):
    return (B & C) | (B & D) | (C & D)

def f60_79(B, C, D):
    return B ^ C ^ D


f = [f0_19, f20_39, f40_59, f60_79]

# Constants to be used
K = [
    0x5A827999L, # ( 0 <= t <= 19)
    0x6ED9EBA1L, # (20 <= t <= 39)
    0x8F1BBCDCL, # (40 <= t <= 59)
    0xCA62C1D6L  # (60 <= t <= 79)
    ]

unroll_f_K = unrolling_iterable(zip(f, map(r_uint, K)))
if UNROLL_ALL:
    unroll_range_20 = unrolling_iterable(range(20))

class RSHA(object):
    """RPython-level SHA object.
    """
    def __init__(self, initialdata=''):
        self._init()
        self.update(initialdata)


    def _init(self):
        "Initialisation."
        self.count = r_ulonglong(0)   # total number of bytes
        self.input = ""   # pending unprocessed data, < 64 bytes
        self.uintbuffer = [r_uint(0)] * 80

        # Initial 160 bit message digest (5 times 32 bit).
        self.H0 = r_uint(0x67452301L)
        self.H1 = r_uint(0xEFCDAB89L)
        self.H2 = r_uint(0x98BADCFEL)
        self.H3 = r_uint(0x10325476L)
        self.H4 = r_uint(0xC3D2E1F0L)

    def _transform(self, W):

        for t in range(16, 80):
            W[t] = _rotateLeft(
                W[t-3] ^ W[t-8] ^ W[t-14] ^ W[t-16], 1)

        A = self.H0
        B = self.H1
        C = self.H2
        D = self.H3
        E = self.H4

        """
        This loop is unrolled (via unroll_f_K) to gain some speed
        for t in range(0, 80):
            TEMP = _rotateLeft(A, 5) + f[t/20] + E + W[t] + K[t/20]
            E = D
            D = C
            C = _rotateLeft(B, 30) & 0xffffffffL
            B = A
            A = TEMP & 0xffffffffL
        """
        t0 = 0
        for f, K in unroll_f_K:
            if UNROLL_ALL:
                rng20 = unroll_range_20
            else:
                rng20 = range(20)
            for t in rng20:
                TEMP = _rotateLeft(A, 5) + f(B, C, D) + E + W[t0+t] + K
                E = D
                D = C
                C = _rotateLeft(B, 30)
                B = A
                A = TEMP
            t0 += 20

        self.H0 = self.H0 + A
        self.H1 = self.H1 + B
        self.H2 = self.H2 + C
        self.H3 = self.H3 + D
        self.H4 = self.H4 + E


    def _finalize(self, digestfunc):
        """Logic to add the final padding and extract the digest.
        """
        # Save the state before adding the padding
        count = self.count
        input = self.input
        H0 = self.H0
        H1 = self.H1
        H2 = self.H2
        H3 = self.H3
        H4 = self.H4

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
        W[14] = r_uint(length_in_bits >> 32)
        W[15] = r_uint(length_in_bits)
        self._transform(W)

        # Store state in digest.
        digest = digestfunc(self.H0, self.H1, self.H2, self.H3, self.H4)

        # Restore the saved state in case this instance is still used
        self.count = count
        self.input = input
        self.H0 = H0 
        self.H1 = H1 
        self.H2 = H2
        self.H3 = H3
        self.H4 = H4

        return digest


    # Down from here all methods follow the Python Standard Library
    # API of the sha module.

    def update(self, inBuf):
        """Add to the current message.

        Update the md5 object with the string arg. Repeated calls
        are equivalent to a single call with the concatenation of all
        the arguments, i.e. m.update(a); m.update(b) is equivalent
        to m.update(a+b).

        The hash is immediately calculated for all full blocks. The final
        calculation is made in digest(). It will calculate 1-2 blocks,
        depending on how much padding we have to add. This allows us to
        keep an intermediate value for the hash, so that we only need to
        make minimal recalculation if we call update() to add more data
        to the hashed string.
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
        clone = RSHA()
        clone._copyfrom(self)
        return clone

    def _copyfrom(self, other):
        """Copy all state from 'other' into 'self'.
        """
        self.count = other.count
        self.input = other.input
        self.H0 = other.H0
        self.H1 = other.H1
        self.H2 = other.H2
        self.H3 = other.H3
        self.H4 = other.H4

# synonyms to build new RSHA objects, for compatibility with the
# CPython sha module interface.
sha = RSHA
new = RSHA
blocksize = 1
digest_size = 20
digestsize = 20
