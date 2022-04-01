"""
Tests for the md5 module implemented at interp-level in pypy/module/_md5.
"""

import py, sys


class AppTestMD5(object):
    spaceconfig = {
        'usemodules': ['_md5', 'binascii', 'time', 'struct'],
    }

    def setup_class(cls):
        """
        Create a space with the md5 module and import it for use by the
        tests.
        """
        cls.w_md5 = cls.space.appexec([], """():
            import _md5
            return _md5
        """)


    def test_name(self):
        """
        md5.name should be 'md5'.
        """
        assert self.md5.md5().name == 'md5'

    def test_digest_size(self):
        """
        md5.digest_size should be 16.
        """
        assert self.md5.md5().digest_size == 16

    def test_MD5Type(self):
        """
        Test the construction of an md5 object.
        """
        md5 = self.md5
        d = md5.md5()

    def test_md5object(self):
        """
        Feed example strings into a md5 object and check the digest and
        hexdigest.
        """
        md5 = self.md5
        import binascii
        cases = (
          (b"",
           "d41d8cd98f00b204e9800998ecf8427e"),
          (b"a",
           "0cc175b9c0f1b6a831c399e269772661"),
          (b"abc",
           "900150983cd24fb0d6963f7d28e17f72"),
          (b"message digest",
           "f96b697d7cb7938d525a2f31aaf161d0"),
          (b"abcdefghijklmnopqrstuvwxyz",
           "c3fcd3d76192e4007dfb496cca67e13b"),
          (b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
           "d174ab98d277d9f5a5611c2c9f419d9f"),
          (b"1234567890" * 8,
           "57edf4a22be3c955ac49da2e2107b67a"),
        )
        for input, expected in cases:
            d = md5.md5(input)
            assert d.hexdigest() == expected
            assert d.digest() == binascii.unhexlify(expected.encode('ascii'))

    def test_copy(self):
        """
        Test the copy() method.
        """
        md5 = self.md5
        d1 = md5.md5()
        d1.update(b"abcde")
        d2 = d1.copy()
        d2.update(b"fgh")
        d1.update(b"jkl")
        assert d1.hexdigest() == 'e570e7110ecef72fcb772a9c05d03373'
        assert d2.hexdigest() == 'e8dc4081b13434b45189a720b77b6818'

    def test_buffer(self):
        """
        Test passing a buffer object.
        """
        md5 = self.md5
        d1 = md5.md5(memoryview(b"abcde"))
        d1.update(memoryview(b"jkl"))
        assert d1.hexdigest() == 'e570e7110ecef72fcb772a9c05d03373'

    def test_unicode(self):
        """
        Test passing unicode strings.
        """
        md5 = self.md5
        raises(TypeError, md5.md5, "abcde")
        d1 = md5.md5()
        raises(TypeError, d1.update, "jkl")

    def test_repr(self):
        md5 = self.md5
        assert 'md5' in repr(md5.md5())
