# -*- coding: utf-8 -*-

class AppTestBinascii(object):
    spaceconfig = dict(usemodules=['binascii'])

    def setup_class(cls):
        """Make binascii module available as self.binascii."""
        cls.w_binascii = cls.space.getbuiltinmodule('binascii')

    def test_a2b_uu(self):
        # obscure case, for compability with CPython
        assert self.binascii.a2b_uu(b"") == b"\x00" * 0x20
        #
        for input, expected in [
            (b"!,_", b"3"),
            (b" ", b""),
            (b"`", b""),
            (b"!", b"\x00"),
            (b"!6", b"X"),
            (b'"6', b"X\x00"),
            (b'"W', b"\xdc\x00"),
            (b'"WA', b"\xde\x10"),
            (b'"WAX', b"\xde\x1e"),
            (b'#WAX', b"\xde\x1e\x00"),
            (b'#WAXR', b"\xde\x1e2"),
            (b'$WAXR', b"\xde\x1e2\x00"),
            (b'$WAXR6', b"\xde\x1e2X"),
            (b'%WAXR6U', b"\xde\x1e2[P"),
            (b'&WAXR6UB', b"\xde\x1e2[X\x80"),
            (b"'WAXR6UBA3", b"\xde\x1e2[X\xa1L"),
            (b'(WAXR6UBA3#', b"\xde\x1e2[X\xa1L0"),
            (b')WAXR6UBA3#Q', b"\xde\x1e2[X\xa1L<@"),
            (b'*WAXR6UBA3#Q!5', b"\xde\x1e2[X\xa1L<AT"),
            (b'!,_', b'\x33'),
            (b'$  $" P  ', b'\x00\x01\x02\x03'),
            (b'$``$"`P``', b'\x00\x01\x02\x03'),
            ]:
            assert self.binascii.a2b_uu(input) == expected
            assert self.binascii.a2b_uu(input + b' ') == expected
            assert self.binascii.a2b_uu(input + b'  ') == expected
            assert self.binascii.a2b_uu(input + b'   ') == expected
            assert self.binascii.a2b_uu(input + b'    ') == expected
            assert self.binascii.a2b_uu(input + b'`') == expected
            assert self.binascii.a2b_uu(input + b'``') == expected
            assert self.binascii.a2b_uu(input + b'```') == expected
            assert self.binascii.a2b_uu(input + b'````') == expected
            assert self.binascii.a2b_uu(input + b'\n') == expected
            assert self.binascii.a2b_uu(input + b'\r\n') == expected
            assert self.binascii.a2b_uu(input + b'  \r\n') == expected
            assert self.binascii.a2b_uu(input + b'    \r\n') == expected
        #
        for bogus in [
            b"!w",
            b"! w",
            b"!  w",
            b"!   w",
            b"!    w",
            b"!     w",
            b"!      w",
            b"#a",
            b'"WAXR',
            ]:
            raises(self.binascii.Error, self.binascii.a2b_uu, bogus)
            raises(self.binascii.Error, self.binascii.a2b_uu, bogus + b' ')
            raises(self.binascii.Error, self.binascii.a2b_uu, bogus + b'  ')
            raises(self.binascii.Error, self.binascii.a2b_uu, bogus + b'   ')
            raises(self.binascii.Error, self.binascii.a2b_uu, bogus + b'    ')
            raises(self.binascii.Error, self.binascii.a2b_uu, bogus + b'\n')
            raises(self.binascii.Error, self.binascii.a2b_uu, bogus + b'\r\n')
            raises(self.binascii.Error, self.binascii.a2b_uu, bogus + b'  \r\n')
        #
        assert self.binascii.a2b_uu(u"!6") == b"X"
        raises(ValueError, self.binascii.a2b_uu, u"caf\xe9")

    def test_b2a_uu(self):
        for input, expected in [
            (b"", b" "),
            (b"\x00", b"!    "),
            (b"X", b"!6   "),
            (b"X\x00", b'"6   '),
            (b"\xdc\x00", b'"W   '),
            (b"\xde\x10", b'"WA  '),
            (b"\xde\x1e", b'"WAX '),
            (b"\xde\x1e\x00", b'#WAX '),
            (b"\xde\x1e2", b'#WAXR'),
            (b"\xde\x1e2\x00", b'$WAXR    '),
            (b"\xde\x1e2X", b'$WAXR6   '),
            (b"\xde\x1e2[P", b'%WAXR6U  '),
            (b"\xde\x1e2[X\x80", b'&WAXR6UB '),
            (b"\xde\x1e2[X\xa1L", b"'WAXR6UBA3   "),
            (b"\xde\x1e2[X\xa1L0", b'(WAXR6UBA3#  '),
            (b"\xde\x1e2[X\xa1L<@", b')WAXR6UBA3#Q '),
            (b"\xde\x1e2[X\xa1L<AT", b'*WAXR6UBA3#Q!5   '),
            ]:
            for backtick in [None, True, False]:
                if backtick is None:
                    assert self.binascii.b2a_uu(input) == expected + b'\n'
                else:
                    really_expected = expected.replace(b' ', b'`') if backtick else expected
                    assert self.binascii.b2a_uu(input, backtick=backtick) == really_expected + b'\n'

    def test_a2b_base64(self):
        for input, expected in [
            (b"", b""),
            (b"\n", b""),
            (b"Yg==\n", b"b"),
            (b"Y g = \n = \r", b"b"),     # random spaces
            (b"Y\x80g\xff=\xc4=", b"b"),  # random junk chars, >= 0x80
            (b"abcd", b"i\xb7\x1d"),
            (b"abcdef==", b"i\xb7\x1dy"),
            (b"abcdefg=", b"i\xb7\x1dy\xf8"),
            (b"abcdefgh", b"i\xb7\x1dy\xf8!"),
            (b"abcdef==FINISHED", b"i\xb7\x1dy"),
            (b"abcdef=   \n   =FINISHED", b"i\xb7\x1dy"),
            (b"abcdefg=FINISHED", b"i\xb7\x1dy\xf8"),
            (b"abcd=efgh", b"i\xb7\x1dy\xf8!"),
            (b"abcde=fgh", b"i\xb7\x1dy\xf8!"),
            (b"abcdef=gh", b"i\xb7\x1dy\xf8!"),
            ]:
            assert self.binascii.a2b_base64(input) == expected
        #
        for bogus in [
            b"abcde",
            b"abcde=",
            b"abcde==",
            b"abcde===",
            b"abcdef",
            b"abcdef=",
            b"abcdefg",
            ]:
            raises(self.binascii.Error, self.binascii.a2b_base64, bogus)
        #
        assert self.binascii.a2b_base64(u"Yg==\n") == b"b"
        raises(ValueError, self.binascii.a2b_base64, u"caf\xe9")

    def test_b2a_base64(self):
        for newline in (True, False, None):
            for input, expected in [
                (b"", b""),
                (b"b", b"Yg=="),
                (b"i\xb7\x1d", b"abcd"),
                (b"i\xb7\x1dy", b"abcdeQ=="),
                (b"i\xb7\x1dy\xf8", b"abcdefg="),
                (b"i\xb7\x1dy\xf8!", b"abcdefgh"),
                (b"i\xb7\x1d" * 345, b"abcd" * 345),
                ]:
                kwargs = {}
                if isinstance(newline, bool):
                    kwargs['newline'] = newline
                if newline is not False:
                    expected += b'\n'
                assert self.binascii.b2a_base64(input, **kwargs) == expected

    def test_a2b_qp(self):
        for input, expected in [
            # these are the tests from CPython 2.7
            (b"= ", b"= "),
            (b"==", b"="),
            (b"=AX", b"=AX"),
            (b"=00\r\n=00", b"\x00\r\n\x00"),
            # more tests follow
            (b"=", b""),
            (b"abc=", b"abc"),
            (b"ab=\ncd", b"abcd"),
            (b"ab=\r\ncd", b"abcd"),
            (''.join(["=%02x" % n for n in range(256)]).encode(),
                          bytes(range(256))),
            (''.join(["=%02X" % n for n in range(256)]).encode(),
                          bytes(range(256))),
            ]:
            assert self.binascii.a2b_qp(input) == expected
        #
        for input, expected in [
            (b"xyz", b"xyz"),
            (b"__", b"  "),
            (b"a_b", b"a b"),
            ]:
            assert self.binascii.a2b_qp(input, header=True) == expected
        #
        assert self.binascii.a2b_qp(u"a_b", header=True) == b"a b"
        raises(ValueError, self.binascii.a2b_qp, u"caf\xe9")

    def test_b2a_qp(self):
        for input, flags, expected in [
            # these are the tests from CPython 2.7
            (b"\xff\r\n\xff\n\xff", {}, b"=FF\r\n=FF\r\n=FF"),
            (b"0"*75+b"\xff\r\n\xff\r\n\xff",{},b"0"*75+b"=\r\n=FF\r\n=FF\r\n=FF"),
            (b'\0\n', {}, b'=00\n'),
            (b'\0\n', {'quotetabs': True}, b'=00\n'),
            (b'foo\tbar\t\n', {}, b'foo\tbar=09\n'),
            (b'foo\tbar\t\n', {'quotetabs': True}, b'foo=09bar=09\n'),
            (b'.', {}, b'=2E'),
            (b'.\n', {}, b'=2E\n'),
            (b'a.\n', {}, b'a.\n'),
            # more tests follow
            (b'_', {}, b'_'),
            (b'_', {'header': True}, b'=5F'),
            (b'.x', {}, b'.x'),
            (b'.\r\nn', {}, b'=2E\r\nn'),
            (b'\nn', {}, b'\nn'),
            (b'\r\nn', {}, b'\r\nn'),
            (b'\nn', {'istext': False}, b'=0An'),
            (b'\r\nn', {'istext': False}, b'=0D=0An'),
            (b' ', {}, b'=20'),
            (b'\t', {}, b'=09'),
            (b' x', {}, b' x'),
            (b'\tx', {}, b'\tx'),
            (b'\x16x', {}, b'=16x'),
            (b' x', {'quotetabs': True}, b'=20x'),
            (b'\tx', {'quotetabs': True}, b'=09x'),
            (b' \nn', {}, b'=20\nn'),
            (b'\t\nn', {}, b'=09\nn'),
            (b'x\nn', {}, b'x\nn'),
            (b' \r\nn', {}, b'=20\r\nn'),
            (b'\t\r\nn', {}, b'=09\r\nn'),
            (b'x\r\nn', {}, b'x\r\nn'),
            (b'x\nn', {'istext': False}, b'x=0An'),
            (b'   ', {}, b'  =20'),
            (b'   ', {'header': True}, b'__=20'),
            (b'   \nn', {}, b'  =20\nn'),
            (b'   \nn', {'header': True}, b'___\nn'),
            (b'   ', {}, b'  =20'),
            (b'\t\t\t', {'header': True}, b'\t\t=09'),
            (b'\t\t\t\nn', {}, b'\t\t=09\nn'),
            (b'\t\t\t\nn', {'header': True}, b'\t\t=09\nn'),
            ]:
            assert self.binascii.b2a_qp(input, **flags) == expected

    def test_a2b_hqx(self):
        for input, expected, done in [
            (b"", b"", 0),
            (b"AAAA", b"]u\xd7", 0),
            (b"A\nA\rAA", b"]u\xd7", 0),
            (b":", b"", 1),
            (b"A:", b"", 1),
            (b"AA:", b"]", 1),
            (b"AAA:", b"]u", 1),
            (b"AAAA:", b"]u\xd7", 1),
            (b"AAAA:foobarbaz", b"]u\xd7", 1),
            (b"41-CZ:", b"D\xe3\x19", 1),
            (b"41-CZl:", b"D\xe3\x19\xbb", 1),
            (b"41-CZlm:", b"D\xe3\x19\xbb\xbf", 1),
            (b"41-CZlm@:", b"D\xe3\x19\xbb\xbf\x16", 1),
            ]:
            assert self.binascii.a2b_hqx(input) == (expected, done)
        #
        for incomplete in [
            b"A",
            b"AA",
            b"AAA",
            b"12345",
            b"123456",
            b"1234560",
            ]:
            raises(self.binascii.Incomplete, self.binascii.a2b_hqx, incomplete)
        #
        for bogus in [
            b"\x00",
            b".",
            b"AAA AAAAAA:",
            ]:
            raises(self.binascii.Error, self.binascii.a2b_hqx, bogus)
        #
        assert self.binascii.a2b_hqx("AAA:") == (b"]u", 1)
        raises(ValueError, self.binascii.a2b_hqx, u"caf\xe9")

    def test_b2a_hqx(self):
        for input, expected in [
            (b"", b""),
            (b"A", b"33"),
            (b"AB", b"38)"),
            (b"ABC", b"38*$"),
            (b"ABCD", b"38*$4!"),
            (b"ABCDE", b"38*$4%8"),
            (b"ABCDEF", b"38*$4%9'"),
            (b"ABCDEFG", b"38*$4%9'4`"),
            (b"]u\xd7", b"AAAA"),
            ]:
            assert self.binascii.b2a_hqx(input) == expected

    def test_rledecode_hqx(self):
        for input, expected in [
            (b"", b""),
            (b"hello world", b"hello world"),
            (b"\x90\x00", b"\x90"),
            (b"a\x90\x05", b"a" * 5),
            (b"a\x90\xff", b"a" * 0xFF),
            (b"abc\x90\x01def", b"abcdef"),
            (b"abc\x90\x02def", b"abccdef"),
            (b"abc\x90\x03def", b"abcccdef"),
            (b"abc\x90\xa1def", b"ab" + b"c" * 0xA1 + b"def"),
            (b"abc\x90\x03\x90\x02def", b"abccccdef"),
            (b"abc\x90\x00\x90\x03def", b"abc\x90\x90\x90def"),
            (b"abc\x90\x03\x90\x00def", b"abccc\x90def"),
            ]:
            assert self.binascii.rledecode_hqx(input) == expected
        #
        for input in [
            b"\x90",
            b"a\x90",
            b"hello world\x90",
            ]:
            raises(self.binascii.Incomplete, self.binascii.rledecode_hqx,
                   input)
        #
        raises(self.binascii.Error, self.binascii.rledecode_hqx, b"\x90\x01")
        raises(self.binascii.Error, self.binascii.rledecode_hqx, b"\x90\x02")
        raises(self.binascii.Error, self.binascii.rledecode_hqx, b"\x90\xff")

    def test_rlecode_hqx(self):
        for input, expected in [
            (b"", b""),
            (b"hello world", b"hello world"),
            (b"helllo world", b"helllo world"),
            (b"hellllo world", b"hel\x90\x04o world"),
            (b"helllllo world", b"hel\x90\x05o world"),
            (b"aaa", b"aaa"),
            (b"aaaa", b"a\x90\x04"),
            (b"a" * 0xff, b"a\x90\xff"),
            (b"a" * 0x100, b"a\x90\xffa"),
            (b"a" * 0x101, b"a\x90\xffaa"),
            (b"a" * 0x102, b"a\x90\xffaaa"),      # see comments in the source
            (b"a" * 0x103, b"a\x90\xffa\x90\x04"),
            (b"a" * 0x1fe, b"a\x90\xffa\x90\xff"),
            (b"a" * 0x1ff, b"a\x90\xffa\x90\xffa"),
            (b"\x90", b"\x90\x00"),
            (b"\x90" * 2, b"\x90\x00" * 2),
            (b"\x90" * 3, b"\x90\x00" * 3),       # see comments in the source
            (b"\x90" * 345, b"\x90\x00" * 345),
            ]:
            assert self.binascii.rlecode_hqx(input) == expected

    def test_crc_hqx(self):
        for input, initial, expected in [
            (b"", 0, 0),
            (b'', 0x12345, 0x2345),
            (b"", 123, 123),
            (b"hello", 321, 28955),
            (b"world", 65535, 12911),
            (b"uh", 40102, 37544),
            (b'a', 10000, 14338),
            (b'b', 10000, 2145),
            (b'c', 10000, 6208),
            (b'd', 10000, 26791),
            (b'e', 10000, 30854),
            (b'f', 10000, 18661),
            (b'g', 10000, 22724),
            (b'h', 10000, 43307),
            (b'i', 10000, 47370),
            (b'j', 10000, 35177),
            (b'k', 10000, 39240),
            (b'l', 10000, 59823),
            (b'm', 10000, 63886),
            (b'n', 10000, 51693),
            (b'o', 10000, 55756),
            (b'p', 10000, 14866),
            (b'q', 10000, 10803),
            (b'r', 10000, 6736),
            (b's', 10000, 2673),
            (b't', 10000, 31382),
            (b'u', 10000, 27319),
            (b'v', 10000, 23252),
            (b'w', 10000, 19189),
            (b'x', 10000, 47898),
            (b'y', 10000, 43835),
            (b'z', 10000, 39768),
            (b'', -1, 65535)
            ]:
            assert self.binascii.crc_hqx(input, initial) == expected

    def test_crc_hqx_ovf_bug(self):
        import sys
        if sys.maxsize == 2 ** 32 - 1:
            big = 2 ** 32
        else:
            big = 2 ** 63
        assert self.binascii.crc_hqx(b'', big) == 0
        assert self.binascii.crc_hqx(b'', -big) == 0

    def test_crc32(self):
        for input, initial, expected in [
            (b"", 0, 0),
            (b"", 123, 123),
            (b"hello", 321, 3946819610),
            (b"world", -2147483648, 32803080),
            (b"world", 2147483647, 942244330),
            (b'a', 10000, 4110462464),
            (b'b', 10000, 1812594618),
            (b'c', 10000, 453955372),
            (b'd', 10000, 2238339727),
            (b'e', 10000, 4067256857),
            (b'f', 10000, 1801730979),
            (b'g', 10000, 476252981),
            (b'h', 10000, 2363233956),
            (b'i', 10000, 4225443378),
            (b'j', 10000, 1657960328),
            (b'k', 10000, 366298910),
            (b'l', 10000, 2343686845),
            (b'm', 10000, 4239843883),
            (b'n', 10000, 1707062161),
            (b'o', 10000, 314082055),
            (b'p', 10000, 2679148274),
            (b'q', 10000, 3904355940),
            (b'r', 10000, 1908338654),
            (b's', 10000, 112844616),
            (b't', 10000, 2564639467),
            (b'u', 10000, 4024072829),
            (b'v', 10000, 1993550791),
            (b'w', 10000, 30677841),
            (b'x', 10000, 2439710400),
            (b'y', 10000, 3865851478),
            (b'z', 10000, 2137352172),
            (b'foo', 99999999999999999999999999, 2362262480),
            (b'bar', -99999999999999999999999999, 2000545409),
            ]:
            assert self.binascii.crc32(input, initial) == expected

    def test_hexlify(self):
        for input, expected in [
            (b"", b""),
            (b"0", b"30"),
            (b"1", b"31"),
            (b"2", b"32"),
            (b"8", b"38"),
            (b"9", b"39"),
            (b"A", b"41"),
            (b"O", b"4f"),
            (b"\xde", b"de"),
            (b"ABC", b"414243"),
            (b"\x00\x00\x00\xff\x00\x00", b"000000ff0000"),
            (b"\x28\x9c\xc8\xc0\x3d\x8e", b"289cc8c03d8e"),
            ]:
            print(input, expected, self.binascii.hexlify(input))
            assert self.binascii.hexlify(input) == expected
            assert self.binascii.b2a_hex(input) == expected

    def test_hexlify_sep(self):
        res = self.binascii.hexlify(bytes([0x73,0x61,0x6e,0x74,0x61,0x20,0x63,0x6c,0x61,0x75,0x73]), '.')
        assert res == b"73.61.6e.74.61.20.63.6c.61.75.73"
        with raises(ValueError):
            self.binascii.hexlify(bytes([1, 2, 3]), b"abc")
        return
        assert self.binascii.hexlify(bytes([0x73,0x61,0x6e,0x74,0x61,0x20,0x63,0x6c,0x61,0x75,0x73]), '?', 4) == \
               b"73616e?74612063?6c617573"
        assert self.binascii.hexlify(bytes([0x73,0x61,0x6e,0x74,0x61,0x20,0x63,0x6c,0x61,0x75,0x73]), '?', -4) == \
               b"73616e74?6120636c?617573"
        with raises(ValueError) as excinfo:
            self.binascii.hexlify(bytes([1, 2, 3]), "ä")
        assert "ASCII" in str(excinfo.value)
        with raises(TypeError):
            self.binascii.hexlify(bytes(), None, 1)

    def test_unhexlify(self):
        for input, expected in [
            (b"", b""),
            (b"30", b"0"),
            (b"31", b"1"),
            (b"32", b"2"),
            (b"38", b"8"),
            (b"39", b"9"),
            (b"41", b"A"),
            (b"4F", b"O"),
            (b"4f", b"O"),
            (b"DE", b"\xde"),
            (b"De", b"\xde"),
            (b"dE", b"\xde"),
            (b"de", b"\xde"),
            (b"414243", b"ABC"),
            (b"000000FF0000", b"\x00\x00\x00\xff\x00\x00"),
            (b"289cc8C03d8e", b"\x28\x9c\xc8\xc0\x3d\x8e"),
            ]:
            assert self.binascii.unhexlify(input) == expected
            assert self.binascii.a2b_hex(input) == expected
            assert self.binascii.unhexlify(input.decode('ascii')) == expected
            assert self.binascii.a2b_hex(input.decode('ascii')) == expected
        raises(ValueError, self.binascii.a2b_hex, u"caf\xe9")

    def test_errors(self):
        binascii = self.binascii
        assert issubclass(binascii.Error, ValueError)
        raises(binascii.Error, binascii.a2b_hex, b'u')
        raises(binascii.Error, binascii.a2b_hex, b'bo')

    def test_deprecated(self):
        import warnings
        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter('always')
            self.binascii.b2a_hqx(b'abc')
        assert len(w) == 1

