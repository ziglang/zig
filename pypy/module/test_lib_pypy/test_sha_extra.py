"""Testing sha module (NIST's Secure Hash Algorithm)

use the three examples from Federal Information Processing Standards
Publication 180-1, Secure Hash Standard,  1995 April 17
http://www.itl.nist.gov/div897/pubs/fip180-1.htm
"""
from pypy.module.test_lib_pypy.support import import_lib_pypy


class AppTestSHA:
    spaceconfig = dict(usemodules=('struct',))

    def setup_class(cls):
        cls.w__sha = import_lib_pypy(cls.space, '_sha1')

    def w_check(self, data, digest):
        computed = self._sha.sha1(data).hexdigest()
        assert computed == digest

    def test_case_1(self):
        self.check(b"abc",
                   "a9993e364706816aba3e25717850c26c9cd0d89d")

    def test_case_2(self):
        self.check(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                   "84983e441c3bd26ebaae4aa1f95129e5e54670f1")

    def disabled_too_slow_test_case_3(self):
        self.check(b"a" * 1000000,
                   "34aa973cd4c4daa4f61eeb2bdbad27316534016f")

    def test_attributes(self):
        _sha = self._sha
        assert _sha.digest_size == 20
        assert _sha.digestsize == 20
        assert _sha.blocksize == 1
        assert _sha.sha1().digest_size == 20
        assert _sha.sha1().digestsize == 20
        assert _sha.sha1().block_size == 64

        assert _sha.sha().name == 'sha'
        assert _sha.sha1().name == 'sha1'


class AppTestSHA256:
    spaceconfig = dict(usemodules=('struct',))

    def setup_class(cls):
        cls.w__sha256 = import_lib_pypy(cls.space, '_sha256')

    def test_attributes(self):
        _sha256 = self._sha256
        assert _sha256.sha224().name == 'sha224'
        assert _sha256.sha256().name == 'sha256'


class AppTestSHA512:
    spaceconfig = dict(usemodules=('struct',))

    def setup_class(cls):
        cls.w__sha512 = import_lib_pypy(cls.space, '_sha512')

    def test_attributes(self):
        _sha512 = self._sha512
        assert _sha512.sha384().name == 'sha384'
        assert _sha512.sha512().name == 'sha512'
