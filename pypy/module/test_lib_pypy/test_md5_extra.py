"""A test script to compare MD5 implementations.

A note about performance: the pure Python MD5 takes roughly 160 sec. per
MB of data on a 233 MHz Intel Pentium CPU.
"""
import md5

from pypy.module.test_lib_pypy.support import import_lib_pypy


def compare_host(message, d2, d2h):
    """Compare results against the host Python's builtin md5.

    For equal digests this returns None, otherwise it returns a tuple of
    both digests.
    """
    # Use the host Python's standard library MD5 compiled C module.
    m1 = md5.md5()
    m1.update(message)
    d1 = m1.digest()
    d1h = m1.hexdigest()
    # Return None if equal or the different digests if not equal.
    return None if d1 == d2 and d1h == d2h else (d1, d2)


class TestMD5Update:

    spaceconfig = dict(usemodules=('struct',))

    def setup_class(cls):
        if cls.runappdirect:
            # XXX:
            import py
            py.test.skip('Unavailable under py3 runappdirect')

    def test_update(self):
        """Test updating cloned objects."""
        cases = (
            b"123",
            b"1234",
            b"12345",
            b"123456",
            b"1234567",
            b"12345678",
            b"123456789 123456789 123456789 ",
            b"123456789 123456789 ",
            b"123456789 123456789 1",
            b"123456789 123456789 12",
            b"123456789 123456789 123",
            b"123456789 123456789 1234",
            b"123456789 123456789 123456789 1",
            b"123456789 123456789 123456789 12",
            b"123456789 123456789 123456789 123",
            b"123456789 123456789 123456789 1234",
            b"123456789 123456789 123456789 12345",
            b"123456789 123456789 123456789 123456",
            b"123456789 123456789 123456789 1234567",
            b"123456789 123456789 123456789 12345678",
            )
        space = self.space
        w__md5 = import_lib_pypy(space, '_md5')

        # Load both with same prefix.
        prefix1 = 2**10 * b'a'

        # The host md5
        m1 = md5.md5()
        m1.update(prefix1)
        m1c = m1.copy()

        # The app-level _md5
        w_m2 = space.call_method(w__md5, 'md5')
        space.call_method(w_m2, 'update', space.newbytes(prefix1))
        w_m2c = space.call_method(w_m2, 'copy')

        # Update and compare...
        for message in cases:
            m1c.update(message)
            d1 = m1c.hexdigest()

            space.call_method(w_m2c, 'update', space.newbytes(message))
            w_d2 = space.call_method(w_m2c, 'hexdigest')
            d2 = space.text_w(w_d2)

            assert d1 == d2


class AppTestMD5Compare:
    """Compare pure Python MD5 against Python's std. lib. version."""

    spaceconfig = dict(usemodules=('struct',))

    def setup_class(cls):
        from pypy.interpreter import gateway
        space = cls.space
        cls.w__md5 = import_lib_pypy(space, '_md5')
        if cls.runappdirect:
            # XXX:
            import py
            py.test.skip('Unavailable under py3 runappdirect')
        else:
            compare_host.unwrap_spec = ['bytes', 'bytes', 'text']
            cls.w_compare_host = space.wrap(gateway.interp2app(compare_host))

    def w_compare(self, message):
        # Generate results against the app-level pure Python MD5 and
        # pass them off for comparison against the host Python's MD5
        m2 = self._md5.md5()
        m2.update(message)
        return self.compare_host(message, m2.digest(), m2.hexdigest())

    def w__format_hex(self, string):
        """Print a string's HEX code in groups of two digits."""
        d = map(None, string)
        d = map(ord, d)
        d = map(lambda x: "%02x" % x, d)
        return ' '.join(d)

    def w__format(self, string):
        """Print a string as-is in groups of two characters."""
        s = ''
        for i in range(0, len(string) - 1, 2):
            s = s + "%03s" % string[i:i + 2]
        return s[1:]

    def w_print_diff(self, message, d1, d2, expectedResult=None):
        """Print different outputs for same message."""
        print("Message: '%s'" % message)
        print("Message length: %d" % len(message))
        if expectedResult:
            print("%-48s (expected)" % self._format(expectedResult))
        print("%-48s (Std. lib. MD5)" % self._format_hex(d1))
        print("%-48s (Pure Python MD5)" % self._format_hex(d2))
        print()

    def test1(self):
        """Test cases with known digest result."""
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
            (b"1234567890"*8,
             "57edf4a22be3c955ac49da2e2107b67a"),
            )

        for message, expectedResult in cases:
            res = self.compare(message)
            if res is not None:
                d1, d2 = res
                self.print_diff(message, d1, d2, expectedResult)
            assert res is None

    def test2(self):
        """Test cases without known digest result."""
        cases = (
            b"123",
            b"1234",
            b"12345",
            b"123456",
            b"1234567",
            b"12345678",
            b"123456789 123456789 123456789 ",
            b"123456789 123456789 ",
            b"123456789 123456789 1",
            b"123456789 123456789 12",
            b"123456789 123456789 123",
            b"123456789 123456789 1234",
            b"123456789 123456789 123456789 1",
            b"123456789 123456789 123456789 12",
            b"123456789 123456789 123456789 123",
            b"123456789 123456789 123456789 1234",
            b"123456789 123456789 123456789 12345",
            b"123456789 123456789 123456789 123456",
            b"123456789 123456789 123456789 1234567",
            b"123456789 123456789 123456789 12345678",
            )

        for message in cases:
            res = self.compare(message)
            if res is not None:
                d1, d2 = res
                self.print_diff(message, d1, d2)
            assert res is None

    def test3(self):
        """Test cases with long messages (can take a while)."""
        cases = (
            2**10*b'a',
            2**10*b'abcd',
            #2**20*b'a',  # 1 MB, takes about 160 sec. on a 233 Mhz Pentium.
            )

        for message in cases:
            res = self.compare(message)
            if res is not None:
                d1, d2 = res
                self.print_diff(message, d1, d2)
            assert res is None

    def test4(self):
        """Test cases with increasingly growing message lengths."""
        i = 0
        while i < 2**5:
            message = i * b'a'
            res = self.compare(message)
            if res is not None:
                d1, d2 = res
                self.print_diff(message, d1, d2)
            assert res is None
            i += 1

    def test_attributes(self):
        _md5 = self._md5
        assert _md5.md5().digest_size == 16
        assert _md5.md5().digestsize == 16
        assert _md5.md5().block_size == 64
