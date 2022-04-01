# -*- coding: utf-8 -*-

import py
import sys, random
import struct
from rpython.rlib import runicode

from hypothesis import given, settings, strategies


def test_unichr():
    assert runicode.UNICHR(0xffff) == u'\uffff'
    if runicode.MAXUNICODE > 0xffff:
        if sys.maxunicode < 0x10000:
            assert runicode.UNICHR(0x10000) == u'\ud800\udc00'
        else:
            assert runicode.UNICHR(0x10000) == u'\U00010000'
    else:
        py.test.raises(ValueError, runicode.UNICHR, 0x10000)
    py.test.raises(TypeError, runicode.UNICHR, 'abc')


def test_ord():
    assert runicode.ORD('a') == 97
    assert runicode.ORD(u'a') == 97
    assert runicode.ORD(u'\uffff') == 0xffff
    if runicode.MAXUNICODE > 0xffff:
        if sys.maxunicode < 0x10000:
            assert runicode.ORD(u'\ud800\udc00') == 0x10000
        else:
            assert runicode.ORD(u'\U00010000') == 0x10000
    else:
        py.test.raises(TypeError, runicode.ORD, u'\ud800\udc00')
    py.test.raises(TypeError, runicode.ORD, 'abc')


class UnicodeTests(object):
    def typeequals(self, x, y):
        assert x == y
        assert type(x) is type(y)

    def getdecoder(self, encoding, look_for_py3k=False):
        prefix = "py3k_" if look_for_py3k else ""
        return getattr(runicode, "%sstr_decode_%s" %
                                 (prefix, encoding.replace("-", "_")))

    def getencoder(self, encoding):
        return getattr(runicode,
                       "unicode_encode_%s" % encoding.replace("-", "_"))

    def checkdecode(self, s, encoding):
        decoder = self.getdecoder(encoding)
        try:
            if isinstance(s, str):
                trueresult = s.decode(encoding)
            else:
                trueresult = s
                s = s.encode(encoding)
        except LookupError as e:
            py.test.skip(e)
        result, consumed = decoder(s, len(s), 'strict', final=True)
        assert consumed == len(s)
        self.typeequals(trueresult, result)

    def checkencode(self, s, encoding):
        encoder = self.getencoder(encoding)
        try:
            if isinstance(s, unicode):
                trueresult = s.encode(encoding)
            else:
                trueresult = s
                s = s.decode(encoding)
        except LookupError as e:
            py.test.skip(e)
        result = encoder(s, len(s), 'strict')
        self.typeequals(trueresult, result)

    def checkencodeerror(self, s, encoding, start, stop):
        called = [False]
        def errorhandler(errors, enc, msg, t, startingpos,
                         endingpos):
            called[0] = True
            assert errors == "foo!"
            assert enc == encoding
            assert t is s
            assert start == startingpos
            assert stop == endingpos
            return u"42424242", None, stop
        encoder = self.getencoder(encoding)
        result = encoder(s, len(s), "foo!", errorhandler)
        assert called[0]
        assert "42424242" in result

        # ensure bytes results passthru
        def errorhandler_bytes(errors, enc, msg, t, startingpos,
                               endingpos):
            return None, '\xc3', endingpos
        result = encoder(s, len(s), "foo!", errorhandler_bytes)
        assert '\xc3' in result

    def checkdecodeerror(self, s, encoding, start, stop,
                         addstuff=True, msg=None,
                         expected_reported_encoding=None,
                         look_for_py3k=False):
        called = [0]
        def errorhandler(errors, enc, errmsg, t, startingpos,
                         endingpos):
            called[0] += 1
            if called[0] == 1:
                assert errors == "foo!"
                assert enc == (expected_reported_encoding or
                               encoding.replace('-', ''))
                assert t is s
                assert start == startingpos
                assert stop == endingpos
                if msg is not None:
                    assert errmsg == msg
                return u"42424242", stop
            return u"", endingpos
        decoder = self.getdecoder(encoding, look_for_py3k=look_for_py3k)
        if addstuff:
            s += "some rest in ascii"
        result, _ = decoder(s, len(s), "foo!", True, errorhandler)
        assert called[0] > 0
        assert "42424242" in result
        if addstuff:
            assert result.endswith(u"some rest in ascii")

    def test_charmap_encodeerror(self):
        def errorhandler(errors, enc, msg, t, startingpos,
                         endingpos):
            assert t[startingpos:endingpos] == u'\t\n  \r'
            return None, ' ', endingpos
        s = u'aa\t\n  \raa'
        mapping = {u'a': 'a'}
        r = runicode.unicode_encode_charmap(s, len(s), None, errorhandler,
                                            mapping=mapping)
        assert r == 'aa aa'


class TestDecoding(UnicodeTests):
    # XXX test bom recognition in utf-16
    # XXX test proper error handling

    def test_all_ascii(self):
        for i in range(128):
            for encoding in "utf-8 latin-1 ascii".split():
                self.checkdecode(chr(i), encoding)

    def test_fast_str_decode_ascii(self):
        u = runicode.fast_str_decode_ascii("abc\x00\x7F")
        assert type(u) is unicode
        assert u == u"abc\x00\x7F"
        py.test.raises(ValueError, runicode.fast_str_decode_ascii, "ab\x80")

    def test_all_first_256(self):
        for i in range(256):
            for encoding in ("utf-7 utf-8 latin-1 utf-16 utf-16-be utf-16-le "
                             "utf-32 utf-32-be utf-32-le").split():
                self.checkdecode(unichr(i), encoding)

    def test_first_10000(self):
        for i in range(10000):
            for encoding in ("utf-7 utf-8 utf-16 utf-16-be utf-16-le "
                             "utf-32 utf-32-be utf-32-le").split():
                if encoding == 'utf-8' and 0xd800 <= i <= 0xdfff:
                    # Don't try to encode lone surrogates
                    continue
                self.checkdecode(unichr(i), encoding)

    def test_random(self):
        for i in range(10000):
            v = random.randrange(sys.maxunicode)
            if 0xd800 <= v <= 0xdfff:
                continue
            uni = unichr(v)
            if sys.version >= "2.7":
                self.checkdecode(uni, "utf-7")
            for encoding in ("utf-8 utf-16 utf-16-be utf-16-le "
                             "utf-32 utf-32-be utf-32-le").split():
                self.checkdecode(uni, encoding)

    # Same as above, but uses Hypothesis to generate non-surrogate unicode
    # characters.
    @settings(max_examples=10000)
    @given(strategies.characters(blacklist_categories=["Cs"]))
    def test_random_hypothesis(self, uni):
        if sys.version >= "2.7":
            self.checkdecode(uni, "utf-7")
        for encoding in ("utf-8 utf-16 utf-16-be utf-16-le "
                         "utf-32 utf-32-be utf-32-le").split():
            self.checkdecode(uni, encoding)

    def test_maxunicode(self):
        uni = unichr(sys.maxunicode)
        if sys.version >= "2.7":
            self.checkdecode(uni, "utf-7")
        for encoding in ("utf-8 utf-16 utf-16-be utf-16-le "
                         "utf-32 utf-32-be utf-32-le").split():
            self.checkdecode(uni, encoding)

    def test_ascii_error(self):
        self.checkdecodeerror("abc\xFF\xFF\xFFcde", "ascii", 3, 4)

    def test_decode_replace(self):
        decoder = self.getdecoder('utf-8')
        assert decoder('caf\xe9', 4, 'replace', True) == (u'caf\ufffd', 4)

    def test_utf16_errors(self):
        # trunkated BOM
        for s in ["\xff", "\xfe"]:
            self.checkdecodeerror(s, "utf-16", 0, len(s), addstuff=False)

        for s in [
                  # unexpected end of data ascii
                  "\xff\xfeF",
                  # unexpected end of data
                  '\xff\xfe\xc0\xdb\x00', '\xff\xfe\xc0\xdb', '\xff\xfe\xc0',
                  ]:
            self.checkdecodeerror(s, "utf-16", 2, len(s), addstuff=False)
        for s in [
                  # illegal surrogate
                  "\xff\xfe\xff\xdb\xff\xff",
                  ]:
            self.checkdecodeerror(s, "utf-16", 2, 4, addstuff=False)

    def test_utf16_errors_py3k(self):
        letter = sys.byteorder[0]
        self.checkdecodeerror("\xff", "utf-16", 0, 1, addstuff=False,
                              expected_reported_encoding='utf-16-%se' % letter,
                              look_for_py3k=True)
        self.checkdecodeerror("\xff", "utf-16-be", 0, 1, addstuff=False,
                              expected_reported_encoding='utf-16-be',
                              look_for_py3k=True)
        self.checkdecodeerror("\xff", "utf-16-le", 0, 1, addstuff=False,
                              expected_reported_encoding='utf-16-le',
                              look_for_py3k=True)
        self.checkdecodeerror("\xff", "utf-32", 0, 1, addstuff=False,
                              expected_reported_encoding='utf-32-%se' % letter,
                              look_for_py3k=True)
        self.checkdecodeerror("\xff", "utf-32-be", 0, 1, addstuff=False,
                              expected_reported_encoding='utf-32-be',
                              look_for_py3k=True)
        self.checkdecodeerror("\xff", "utf-32-le", 0, 1, addstuff=False,
                              expected_reported_encoding='utf-32-le',
                              look_for_py3k=True)

    def test_utf16_bugs(self):
        s = '\x80-\xe9\xdeL\xa3\x9b'
        py.test.raises(UnicodeDecodeError, runicode.str_decode_utf_16_le,
                       s, len(s), True)

    def test_utf16_surrogates(self):
        assert runicode.unicode_encode_utf_16_be(
            u"\ud800", 1, None) == '\xd8\x00'
        py.test.raises(UnicodeEncodeError, runicode.unicode_encode_utf_16_be,
                       u"\ud800", 1, None, allow_surrogates=False)
        def replace_with(ru, rs):
            def errorhandler(errors, enc, msg, u, startingpos, endingpos):
                if errors == 'strict':
                    raise UnicodeEncodeError(enc, u, startingpos,
                                             endingpos, msg)
                return ru, rs, endingpos
            return runicode.unicode_encode_utf_16_be(
                u"<\ud800>", 3, None,
                errorhandler, allow_surrogates=False)
        assert replace_with(u'rep', None) == '\x00<\x00r\x00e\x00p\x00>'
        assert replace_with(None, '\xca\xfe') == '\x00<\xca\xfe\x00>'

    @py.test.mark.parametrize('unich',[u"\ud800", u"\udc80"])
    def test_utf32_surrogates(self, unich):
        assert runicode.unicode_encode_utf_32_be(
            unich, 1, None) == struct.pack('>i', ord(unich))
        py.test.raises(UnicodeEncodeError, runicode.unicode_encode_utf_32_be,
                       unich, 1, None, allow_surrogates=False)
        def replace_with(ru, rs):
            def errorhandler(errors, enc, msg, u, startingpos, endingpos):
                if errors == 'strict':
                    raise UnicodeEncodeError(enc, u, startingpos,
                                             endingpos, msg)
                return ru, rs, endingpos
            return runicode.unicode_encode_utf_32_be(
                u"<%s>" % unich, 3, None,
                errorhandler, allow_surrogates=False)
        assert replace_with(u'rep', None) == u'<rep>'.encode('utf-32-be')
        assert replace_with(None, '\xca\xfe\xca\xfe') == '\x00\x00\x00<\xca\xfe\xca\xfe\x00\x00\x00>'
        #
        assert runicode.str_decode_utf_32_be(
            b"\x00\x00\xdc\x80", 4, None) == (u'\udc80', 4)
        py.test.raises(UnicodeDecodeError, runicode.py3k_str_decode_utf_32_be,
                       b"\x00\x00\xdc\x80", 4, None)

    def test_utf7_bugs(self):
        u = u'A\u2262\u0391.'
        assert runicode.unicode_encode_utf_7(u, len(u), None) == 'A+ImIDkQ.'

    def test_utf7_tofrom_utf8_bug(self):
        def _assert_decu7(input, expected):
            assert runicode.str_decode_utf_7(input, len(input), None) == (expected, len(input))

        _assert_decu7('+-', u'+')
        _assert_decu7('+-+-', u'++')
        _assert_decu7('+-+AOQ-', u'+\xe4')
        _assert_decu7('+AOQ-', u'\xe4')
        _assert_decu7('+AOQ-', u'\xe4')
        _assert_decu7('+AOQ- ', u'\xe4 ')
        _assert_decu7(' +AOQ-', u' \xe4')
        _assert_decu7(' +AOQ- ', u' \xe4 ')
        _assert_decu7('+AOQ-+AOQ-', u'\xe4\xe4')

        s_utf7 = 'Die M+AOQ-nner +AOQ-rgern sich!'
        s_utf8 = u'Die Männer ärgern sich!'
        s_utf8_esc = u'Die M\xe4nner \xe4rgern sich!'

        _assert_decu7(s_utf7, s_utf8_esc)
        _assert_decu7(s_utf7, s_utf8)

        assert runicode.unicode_encode_utf_7(s_utf8_esc, len(s_utf8_esc), None) == s_utf7
        assert runicode.unicode_encode_utf_7(s_utf8,     len(s_utf8_esc), None) == s_utf7

    def test_utf7_partial(self):
        s = u"a+-b".encode('utf-7')
        assert s == "a+--b"
        decode = self.getdecoder('utf-7')
        assert decode(s, 1, None) == (u'a', 1)
        assert decode(s, 2, None) == (u'a', 1)
        assert decode(s, 3, None) == (u'a+', 3)
        assert decode(s, 4, None) == (u'a+-', 4)
        assert decode(s, 5, None) == (u'a+-b', 5)

        assert decode((27 * u"\u3042" + "\n").encode('utf7')[:28], 28, None) == (u'', 0)
        assert decode('+MEI\n+MEIwQjBCMEIwQjBCMEIwQjBCMEIwQjBCMEIwQjBCMEIwQjBCMEIwQjBCMEIwQjBCME', 72, None) == (u'\u3042\n', 5)

    def test_utf7_surrogates(self):
        encode = self.getencoder('utf-7')
        u = u'\U000abcde'
        assert encode(u, len(u), None) == '+2m/c3g-'
        decode = self.getdecoder('utf-7')

        # Unpaired surrogates are passed through
        assert encode(u'\uD801', 1, None) == '+2AE-'
        assert encode(u'\uD801x', 2, None) == '+2AE-x'
        assert encode(u'\uDC01', 1, None) == '+3AE-'
        assert encode(u'\uDC01x', 2, None) == '+3AE-x'
        assert decode('+2AE-', 5, None) == (u'\uD801', 5)
        assert decode('+2AE-x', 6, None) == (u'\uD801x', 6)
        assert decode('+3AE-', 5, None) == (u'\uDC01', 5)
        assert decode('+3AE-x', 6, None) == (u'\uDC01x', 6)

        u = u'\uD801\U000abcde'
        assert encode(u, len(u), None) == '+2AHab9ze-'
        assert decode('+2AHab9ze-', 10, None) == (u'\uD801\U000abcde', 10)


class TestUTF8Decoding(UnicodeTests):
    def setup_method(self, meth):
        self.decoder = self.getdecoder('utf-8')

    def custom_replace(self, errors, encoding, msg, s, startingpos, endingpos):
        assert errors == 'custom'
        # returns FOO, but consumes only one character (not up to endingpos)
        FOO = u'\u1234'
        return FOO, startingpos + 1

    def to_bytestring(self, bytes):
        return ''.join(chr(int(c, 16)) for c in bytes.split())

    def test_single_chars_utf8(self):
        for s in ["\xd7\x90", "\xd6\x96", "\xeb\x96\x95", "\xf0\x90\x91\x93"]:
            self.checkdecode(s, "utf-8")

    def test_utf8_surrogate(self):
        # surrogates used to be allowed by python 2.x, and on narrow builds
        if runicode.MAXUNICODE < 65536:
            self.checkdecode(u"\ud800", "utf-8")
        else:
            py.test.raises(UnicodeDecodeError, self.checkdecode, u"\ud800", "utf-8")

    def test_invalid_start_byte(self):
        """
        Test that an 'invalid start byte' error is raised when the first byte
        is not in the ASCII range or is not a valid start byte of a 2-, 3-, or
        4-bytes sequence. The invalid start byte is replaced with a single
        U+FFFD when errors='replace'.
        E.g. <80> is a continuation byte and can appear only after a start byte.
        """
        FFFD = u'\ufffd'
        FOO = u'\u1234'
        for byte in '\x80\xA0\x9F\xBF\xC0\xC1\xF5\xFF':
            py.test.raises(UnicodeDecodeError, self.decoder, byte, 1, None, final=True)
            self.checkdecodeerror(byte, 'utf-8', 0, 1, addstuff=False,
                                  msg='invalid start byte')
            assert self.decoder(byte, 1, 'replace', final=True) == (FFFD, 1)
            assert (self.decoder('aaaa' + byte + 'bbbb', 9, 'replace',
                        final=True) ==
                        (u'aaaa'+ FFFD + u'bbbb', 9))
            assert self.decoder(byte, 1, 'ignore', final=True) == (u'', 1)
            assert (self.decoder('aaaa' + byte + 'bbbb', 9, 'ignore',
                        final=True) == (u'aaaabbbb', 9))
            assert self.decoder(byte, 1, 'custom', final=True,
                        errorhandler=self.custom_replace) == (FOO, 1)
            assert (self.decoder('aaaa' + byte + 'bbbb', 9, 'custom',
                        final=True, errorhandler=self.custom_replace) ==
                        (u'aaaa'+ FOO + u'bbbb', 9))

    def test_unexpected_end_of_data(self):
        """
        Test that an 'unexpected end of data' error is raised when the string
        ends after a start byte of a 2-, 3-, or 4-bytes sequence without having
        enough continuation bytes.  The incomplete sequence is replaced with a
        single U+FFFD when errors='replace'.
        E.g. in the sequence <F3 80 80>, F3 is the start byte of a 4-bytes
        sequence, but it's followed by only 2 valid continuation bytes and the
        last continuation bytes is missing.
        Note: the continuation bytes must be all valid, if one of them is
        invalid another error will be raised.
        """
        sequences = [
            'C2', 'DF',
            'E0 A0', 'E0 BF', 'E1 80', 'E1 BF', 'EC 80', 'EC BF',
            'ED 80', 'ED 9F', 'EE 80', 'EE BF', 'EF 80', 'EF BF',
            'F0 90', 'F0 BF', 'F0 90 80', 'F0 90 BF', 'F0 BF 80', 'F0 BF BF',
            'F1 80', 'F1 BF', 'F1 80 80', 'F1 80 BF', 'F1 BF 80', 'F1 BF BF',
            'F3 80', 'F3 BF', 'F3 80 80', 'F3 80 BF', 'F3 BF 80', 'F3 BF BF',
            'F4 80', 'F4 8F', 'F4 80 80', 'F4 80 BF', 'F4 8F 80', 'F4 8F BF'
        ]
        FFFD = u'\ufffd'
        FOO = u'\u1234'
        for seq in sequences:
            seq = self.to_bytestring(seq)
            py.test.raises(UnicodeDecodeError, self.decoder, seq, len(seq),
                   None, final=True)
            self.checkdecodeerror(seq, 'utf-8', 0, len(seq), addstuff=False,
                                  msg='unexpected end of data')
            assert self.decoder(seq, len(seq), 'replace', final=True
                                ) == (FFFD, len(seq))
            assert (self.decoder('aaaa' + seq + 'bbbb', len(seq) + 8,
                                 'replace', final=True) ==
                        (u'aaaa'+ FFFD + u'bbbb', len(seq) + 8))
            assert self.decoder(seq, len(seq), 'ignore', final=True
                                ) == (u'', len(seq))
            assert (self.decoder('aaaa' + seq + 'bbbb', len(seq) + 8, 'ignore',
                        final=True) == (u'aaaabbbb', len(seq) + 8))
            assert (self.decoder(seq, len(seq), 'custom', final=True,
                        errorhandler=self.custom_replace) ==
                        (FOO * len(seq), len(seq)))
            assert (self.decoder('aaaa' + seq + 'bbbb', len(seq) + 8, 'custom',
                        final=True, errorhandler=self.custom_replace) ==
                        (u'aaaa'+ FOO * len(seq) + u'bbbb', len(seq) + 8))

    def test_invalid_cb_for_2bytes_seq(self):
        """
        Test that an 'invalid continuation byte' error is raised when the
        continuation byte of a 2-bytes sequence is invalid.  The start byte
        is replaced by a single U+FFFD and the second byte is handled
        separately when errors='replace'.
        E.g. in the sequence <C2 41>, C2 is the start byte of a 2-bytes
        sequence, but 41 is not a valid continuation byte because it's the
        ASCII letter 'A'.
        """
        FFFD = u'\ufffd'
        FFFDx2 = FFFD * 2
        sequences = [
            ('C2 00', FFFD+u'\x00'), ('C2 7F', FFFD+u'\x7f'),
            ('C2 C0', FFFDx2), ('C2 FF', FFFDx2),
            ('DF 00', FFFD+u'\x00'), ('DF 7F', FFFD+u'\x7f'),
            ('DF C0', FFFDx2), ('DF FF', FFFDx2),
        ]
        for seq, res in sequences:
            seq = self.to_bytestring(seq)
            py.test.raises(UnicodeDecodeError, self.decoder, seq, len(seq),
                   None, final=True)
            self.checkdecodeerror(seq, 'utf-8', 0, 1, addstuff=False,
                                  msg='invalid continuation byte')
            assert self.decoder(seq, len(seq), 'replace', final=True
                                ) == (res, len(seq))
            assert (self.decoder('aaaa' + seq + 'bbbb', len(seq) + 8,
                                 'replace', final=True) ==
                        (u'aaaa' + res + u'bbbb', len(seq) + 8))
            res = res.replace(FFFD, u'')
            assert self.decoder(seq, len(seq), 'ignore', final=True
                                ) == (res, len(seq))
            assert (self.decoder('aaaa' + seq + 'bbbb', len(seq) + 8,
                                 'ignore', final=True) ==
                        (u'aaaa' + res + u'bbbb', len(seq) + 8))

    def test_invalid_cb_for_3bytes_seq(self):
        """
        Test that an 'invalid continuation byte' error is raised when the
        continuation byte(s) of a 3-bytes sequence are invalid.  When
        errors='replace', if the first continuation byte is valid, the first
        two bytes (start byte + 1st cb) are replaced by a single U+FFFD and the
        third byte is handled separately, otherwise only the start byte is
        replaced with a U+FFFD and the other continuation bytes are handled
        separately.
        E.g. in the sequence <E1 80 41>, E1 is the start byte of a 3-bytes
        sequence, 80 is a valid continuation byte, but 41 is not a valid cb
        because it's the ASCII letter 'A'.
        Note: when the start byte is E0 or ED, the valid ranges for the first
        continuation byte are limited to A0..BF and 80..9F respectively.
        However, when the start byte is ED, Python 2 considers all the bytes
        in range 80..BF valid.  This is fixed in Python 3.
        """
        FFFD = u'\ufffd'
        FFFDx2 = FFFD * 2
        sequences = [
            ('E0 00', FFFD+u'\x00'), ('E0 7F', FFFD+u'\x7f'), ('E0 80', FFFDx2),
            ('E0 9F', FFFDx2), ('E0 C0', FFFDx2), ('E0 FF', FFFDx2),
            ('E0 A0 00', FFFD+u'\x00'), ('E0 A0 7F', FFFD+u'\x7f'),
            ('E0 A0 C0', FFFDx2), ('E0 A0 FF', FFFDx2),
            ('E0 BF 00', FFFD+u'\x00'), ('E0 BF 7F', FFFD+u'\x7f'),
            ('E0 BF C0', FFFDx2), ('E0 BF FF', FFFDx2), ('E1 00', FFFD+u'\x00'),
            ('E1 7F', FFFD+u'\x7f'), ('E1 C0', FFFDx2), ('E1 FF', FFFDx2),
            ('E1 80 00', FFFD+u'\x00'), ('E1 80 7F', FFFD+u'\x7f'),
            ('E1 80 C0', FFFDx2), ('E1 80 FF', FFFDx2),
            ('E1 BF 00', FFFD+u'\x00'), ('E1 BF 7F', FFFD+u'\x7f'),
            ('E1 BF C0', FFFDx2), ('E1 BF FF', FFFDx2), ('EC 00', FFFD+u'\x00'),
            ('EC 7F', FFFD+u'\x7f'), ('EC C0', FFFDx2), ('EC FF', FFFDx2),
            ('EC 80 00', FFFD+u'\x00'), ('EC 80 7F', FFFD+u'\x7f'),
            ('EC 80 C0', FFFDx2), ('EC 80 FF', FFFDx2),
            ('EC BF 00', FFFD+u'\x00'), ('EC BF 7F', FFFD+u'\x7f'),
            ('EC BF C0', FFFDx2), ('EC BF FF', FFFDx2), ('ED 00', FFFD+u'\x00'),
            ('ED 7F', FFFD+u'\x7f'),
            # ('ED A0', FFFDx2), ('ED BF', FFFDx2), # see note ^
            ('ED C0', FFFDx2), ('ED FF', FFFDx2), ('ED 80 00', FFFD+u'\x00'),
            ('ED 80 7F', FFFD+u'\x7f'), ('ED 80 C0', FFFDx2),
            ('ED 80 FF', FFFDx2), ('ED 9F 00', FFFD+u'\x00'),
            ('ED 9F 7F', FFFD+u'\x7f'), ('ED 9F C0', FFFDx2),
            ('ED 9F FF', FFFDx2), ('EE 00', FFFD+u'\x00'),
            ('EE 7F', FFFD+u'\x7f'), ('EE C0', FFFDx2), ('EE FF', FFFDx2),
            ('EE 80 00', FFFD+u'\x00'), ('EE 80 7F', FFFD+u'\x7f'),
            ('EE 80 C0', FFFDx2), ('EE 80 FF', FFFDx2),
            ('EE BF 00', FFFD+u'\x00'), ('EE BF 7F', FFFD+u'\x7f'),
            ('EE BF C0', FFFDx2), ('EE BF FF', FFFDx2), ('EF 00', FFFD+u'\x00'),
            ('EF 7F', FFFD+u'\x7f'), ('EF C0', FFFDx2), ('EF FF', FFFDx2),
            ('EF 80 00', FFFD+u'\x00'), ('EF 80 7F', FFFD+u'\x7f'),
            ('EF 80 C0', FFFDx2), ('EF 80 FF', FFFDx2),
            ('EF BF 00', FFFD+u'\x00'), ('EF BF 7F', FFFD+u'\x7f'),
            ('EF BF C0', FFFDx2), ('EF BF FF', FFFDx2),
        ]
        for seq, res in sequences:
            seq = self.to_bytestring(seq)
            py.test.raises(UnicodeDecodeError, self.decoder, seq, len(seq),
                   None, final=True)
            self.checkdecodeerror(seq, 'utf-8', 0, len(seq)-1, addstuff=False,
                                  msg='invalid continuation byte')
            assert self.decoder(seq, len(seq), 'replace', final=True
                                ) == (res, len(seq))
            assert (self.decoder('aaaa' + seq + 'bbbb', len(seq) + 8,
                                 'replace', final=True) ==
                        (u'aaaa' + res + u'bbbb', len(seq) + 8))
            res = res.replace(FFFD, u'')
            assert self.decoder(seq, len(seq), 'ignore', final=True
                                ) == (res, len(seq))
            assert (self.decoder('aaaa' + seq + 'bbbb', len(seq) + 8, 'ignore',
                        final=True) == (u'aaaa' + res + u'bbbb', len(seq) + 8))

    def test_invalid_cb_for_4bytes_seq(self):
        """
        Test that an 'invalid continuation byte' error is raised when the
        continuation byte(s) of a 4-bytes sequence are invalid.  When
        errors='replace',the start byte and all the following valid
        continuation bytes are replaced with a single U+FFFD, and all the bytes
        starting from the first invalid continuation bytes (included) are
        handled separately.
        E.g. in the sequence <E1 80 41>, E1 is the start byte of a 3-bytes
        sequence, 80 is a valid continuation byte, but 41 is not a valid cb
        because it's the ASCII letter 'A'.
        Note: when the start byte is E0 or ED, the valid ranges for the first
        continuation byte are limited to A0..BF and 80..9F respectively.
        However, when the start byte is ED, Python 2 considers all the bytes
        in range 80..BF valid.  This is fixed in Python 3.
        """
        FFFD = u'\ufffd'
        FFFDx2 = FFFD * 2
        sequences = [
            ('F0 00', FFFD+u'\x00'), ('F0 7F', FFFD+u'\x7f'), ('F0 80', FFFDx2),
            ('F0 8F', FFFDx2), ('F0 C0', FFFDx2), ('F0 FF', FFFDx2),
            ('F0 90 00', FFFD+u'\x00'), ('F0 90 7F', FFFD+u'\x7f'),
            ('F0 90 C0', FFFDx2), ('F0 90 FF', FFFDx2),
            ('F0 BF 00', FFFD+u'\x00'), ('F0 BF 7F', FFFD+u'\x7f'),
            ('F0 BF C0', FFFDx2), ('F0 BF FF', FFFDx2),
            ('F0 90 80 00', FFFD+u'\x00'), ('F0 90 80 7F', FFFD+u'\x7f'),
            ('F0 90 80 C0', FFFDx2), ('F0 90 80 FF', FFFDx2),
            ('F0 90 BF 00', FFFD+u'\x00'), ('F0 90 BF 7F', FFFD+u'\x7f'),
            ('F0 90 BF C0', FFFDx2), ('F0 90 BF FF', FFFDx2),
            ('F0 BF 80 00', FFFD+u'\x00'), ('F0 BF 80 7F', FFFD+u'\x7f'),
            ('F0 BF 80 C0', FFFDx2), ('F0 BF 80 FF', FFFDx2),
            ('F0 BF BF 00', FFFD+u'\x00'), ('F0 BF BF 7F', FFFD+u'\x7f'),
            ('F0 BF BF C0', FFFDx2), ('F0 BF BF FF', FFFDx2),
            ('F1 00', FFFD+u'\x00'), ('F1 7F', FFFD+u'\x7f'), ('F1 C0', FFFDx2),
            ('F1 FF', FFFDx2), ('F1 80 00', FFFD+u'\x00'),
            ('F1 80 7F', FFFD+u'\x7f'), ('F1 80 C0', FFFDx2),
            ('F1 80 FF', FFFDx2), ('F1 BF 00', FFFD+u'\x00'),
            ('F1 BF 7F', FFFD+u'\x7f'), ('F1 BF C0', FFFDx2),
            ('F1 BF FF', FFFDx2), ('F1 80 80 00', FFFD+u'\x00'),
            ('F1 80 80 7F', FFFD+u'\x7f'), ('F1 80 80 C0', FFFDx2),
            ('F1 80 80 FF', FFFDx2), ('F1 80 BF 00', FFFD+u'\x00'),
            ('F1 80 BF 7F', FFFD+u'\x7f'), ('F1 80 BF C0', FFFDx2),
            ('F1 80 BF FF', FFFDx2), ('F1 BF 80 00', FFFD+u'\x00'),
            ('F1 BF 80 7F', FFFD+u'\x7f'), ('F1 BF 80 C0', FFFDx2),
            ('F1 BF 80 FF', FFFDx2), ('F1 BF BF 00', FFFD+u'\x00'),
            ('F1 BF BF 7F', FFFD+u'\x7f'), ('F1 BF BF C0', FFFDx2),
            ('F1 BF BF FF', FFFDx2), ('F3 00', FFFD+u'\x00'),
            ('F3 7F', FFFD+u'\x7f'), ('F3 C0', FFFDx2), ('F3 FF', FFFDx2),
            ('F3 80 00', FFFD+u'\x00'), ('F3 80 7F', FFFD+u'\x7f'),
            ('F3 80 C0', FFFDx2), ('F3 80 FF', FFFDx2),
            ('F3 BF 00', FFFD+u'\x00'), ('F3 BF 7F', FFFD+u'\x7f'),
            ('F3 BF C0', FFFDx2), ('F3 BF FF', FFFDx2),
            ('F3 80 80 00', FFFD+u'\x00'), ('F3 80 80 7F', FFFD+u'\x7f'),
            ('F3 80 80 C0', FFFDx2), ('F3 80 80 FF', FFFDx2),
            ('F3 80 BF 00', FFFD+u'\x00'), ('F3 80 BF 7F', FFFD+u'\x7f'),
            ('F3 80 BF C0', FFFDx2), ('F3 80 BF FF', FFFDx2),
            ('F3 BF 80 00', FFFD+u'\x00'), ('F3 BF 80 7F', FFFD+u'\x7f'),
            ('F3 BF 80 C0', FFFDx2), ('F3 BF 80 FF', FFFDx2),
            ('F3 BF BF 00', FFFD+u'\x00'), ('F3 BF BF 7F', FFFD+u'\x7f'),
            ('F3 BF BF C0', FFFDx2), ('F3 BF BF FF', FFFDx2),
            ('F4 00', FFFD+u'\x00'), ('F4 7F', FFFD+u'\x7f'), ('F4 90', FFFDx2),
            ('F4 BF', FFFDx2), ('F4 C0', FFFDx2), ('F4 FF', FFFDx2),
            ('F4 80 00', FFFD+u'\x00'), ('F4 80 7F', FFFD+u'\x7f'),
            ('F4 80 C0', FFFDx2), ('F4 80 FF', FFFDx2),
            ('F4 8F 00', FFFD+u'\x00'), ('F4 8F 7F', FFFD+u'\x7f'),
            ('F4 8F C0', FFFDx2), ('F4 8F FF', FFFDx2),
            ('F4 80 80 00', FFFD+u'\x00'), ('F4 80 80 7F', FFFD+u'\x7f'),
            ('F4 80 80 C0', FFFDx2), ('F4 80 80 FF', FFFDx2),
            ('F4 80 BF 00', FFFD+u'\x00'), ('F4 80 BF 7F', FFFD+u'\x7f'),
            ('F4 80 BF C0', FFFDx2), ('F4 80 BF FF', FFFDx2),
            ('F4 8F 80 00', FFFD+u'\x00'), ('F4 8F 80 7F', FFFD+u'\x7f'),
            ('F4 8F 80 C0', FFFDx2), ('F4 8F 80 FF', FFFDx2),
            ('F4 8F BF 00', FFFD+u'\x00'), ('F4 8F BF 7F', FFFD+u'\x7f'),
            ('F4 8F BF C0', FFFDx2), ('F4 8F BF FF', FFFDx2)
        ]
        for seq, res in sequences:
            seq = self.to_bytestring(seq)
            py.test.raises(UnicodeDecodeError, self.decoder, seq, len(seq),
                   None, final=True)
            self.checkdecodeerror(seq, 'utf-8', 0, len(seq)-1, addstuff=False,
                                  msg='invalid continuation byte')
            assert self.decoder(seq, len(seq), 'replace', final=True
                                ) == (res, len(seq))
            assert (self.decoder('aaaa' + seq + 'bbbb', len(seq) + 8,
                                 'replace', final=True) ==
                        (u'aaaa' + res + u'bbbb', len(seq) + 8))
            res = res.replace(FFFD, u'')
            assert self.decoder(seq, len(seq), 'ignore', final=True
                                ) == (res, len(seq))
            assert (self.decoder('aaaa' + seq + 'bbbb', len(seq) + 8, 'ignore',
                        final=True) == (u'aaaa' + res + u'bbbb', len(seq) + 8))

    def test_utf8_errors(self):
        # unexpected end of data
        for s in ['\xd7', '\xd6', '\xeb\x96', '\xf0\x90\x91', '\xc2', '\xdf']:
            self.checkdecodeerror(s, 'utf-8', 0, len(s), addstuff=False,
                                  msg='unexpected end of data')

        # invalid data 2 byte
        for s in ["\xd7\x50", "\xd6\x06", "\xd6\xD6"]:
            self.checkdecodeerror(s, "utf-8", 0, 1, addstuff=True,
                                  msg='invalid continuation byte')
        # invalid data 3 byte
        for s in ["\xeb\x56\x95", "\xeb\x06\x95", "\xeb\xD6\x95"]:
            self.checkdecodeerror(s, "utf-8", 0, 1, addstuff=True,
                                  msg='invalid continuation byte')
        for s in ["\xeb\x96\x55", "\xeb\x96\x05", "\xeb\x96\xD5"]:
            self.checkdecodeerror(s, "utf-8", 0, 2, addstuff=True,
                                  msg='invalid continuation byte')
        # invalid data 4 byte
        for s in ["\xf0\x50\x91\x93", "\xf0\x00\x91\x93", "\xf0\xd0\x91\x93"]:
            self.checkdecodeerror(s, "utf-8", 0, 1, addstuff=True,
                                  msg='invalid continuation byte')
        for s in ["\xf0\x90\x51\x93", "\xf0\x90\x01\x93", "\xf0\x90\xd1\x93"]:
            self.checkdecodeerror(s, "utf-8", 0, 2, addstuff=True,
                                  msg='invalid continuation byte')
        for s in ["\xf0\x90\x91\x53", "\xf0\x90\x91\x03", "\xf0\x90\x91\xd3"]:
            self.checkdecodeerror(s, "utf-8", 0, 3, addstuff=True,
                                  msg='invalid continuation byte')

    def test_issue8271(self):
        # From CPython
        # Issue #8271: during the decoding of an invalid UTF-8 byte sequence,
        # only the start byte and the continuation byte(s) are now considered
        # invalid, instead of the number of bytes specified by the start byte.
        # See http://www.unicode.org/versions/Unicode5.2.0/ch03.pdf (page 95,
        # table 3-8, Row 2) for more information about the algorithm used.
        FFFD = u'\ufffd'
        sequences = [
            # invalid start bytes
            ('\x80', FFFD), # continuation byte
            ('\x80\x80', FFFD*2), # 2 continuation bytes
            ('\xc0', FFFD),
            ('\xc0\xc0', FFFD*2),
            ('\xc1', FFFD),
            ('\xc1\xc0', FFFD*2),
            ('\xc0\xc1', FFFD*2),
            # with start byte of a 2-byte sequence
            ('\xc2', FFFD), # only the start byte
            ('\xc2\xc2', FFFD*2), # 2 start bytes
            ('\xc2\xc2\xc2', FFFD*3), # 2 start bytes
            ('\xc2\x41', FFFD+'A'), # invalid continuation byte
            # with start byte of a 3-byte sequence
            ('\xe1', FFFD), # only the start byte
            ('\xe1\xe1', FFFD*2), # 2 start bytes
            ('\xe1\xe1\xe1', FFFD*3), # 3 start bytes
            ('\xe1\xe1\xe1\xe1', FFFD*4), # 4 start bytes
            ('\xe1\x80', FFFD), # only 1 continuation byte
            ('\xe1\x41', FFFD+'A'), # invalid continuation byte
            ('\xe1\x41\x80', FFFD+'A'+FFFD), # invalid cb followed by valid cb
            ('\xe1\x41\x41', FFFD+'AA'), # 2 invalid continuation bytes
            ('\xe1\x80\x41', FFFD+'A'), # only 1 valid continuation byte
            ('\xe1\x80\xe1\x41', FFFD*2+'A'), # 1 valid and the other invalid
            ('\xe1\x41\xe1\x80', FFFD+'A'+FFFD), # 1 invalid and the other valid
            # with start byte of a 4-byte sequence
            ('\xf1', FFFD), # only the start byte
            ('\xf1\xf1', FFFD*2), # 2 start bytes
            ('\xf1\xf1\xf1', FFFD*3), # 3 start bytes
            ('\xf1\xf1\xf1\xf1', FFFD*4), # 4 start bytes
            ('\xf1\xf1\xf1\xf1\xf1', FFFD*5), # 5 start bytes
            ('\xf1\x80', FFFD), # only 1 continuation bytes
            ('\xf1\x80\x80', FFFD), # only 2 continuation bytes
            ('\xf1\x80\x41', FFFD+'A'), # 1 valid cb and 1 invalid
            ('\xf1\x80\x41\x41', FFFD+'AA'), # 1 valid cb and 1 invalid
            ('\xf1\x80\x80\x41', FFFD+'A'), # 2 valid cb and 1 invalid
            ('\xf1\x41\x80', FFFD+'A'+FFFD), # 1 invalid cv and 1 valid
            ('\xf1\x41\x80\x80', FFFD+'A'+FFFD*2), # 1 invalid cb and 2 invalid
            ('\xf1\x41\x80\x41', FFFD+'A'+FFFD+'A'), # 2 invalid cb and 1 invalid
            ('\xf1\x41\x41\x80', FFFD+'AA'+FFFD), # 1 valid cb and 1 invalid
            ('\xf1\x41\xf1\x80', FFFD+'A'+FFFD),
            ('\xf1\x41\x80\xf1', FFFD+'A'+FFFD*2),
            ('\xf1\xf1\x80\x41', FFFD*2+'A'),
            ('\xf1\x41\xf1\xf1', FFFD+'A'+FFFD*2),
            # with invalid start byte of a 4-byte sequence (rfc2279)
            ('\xf5', FFFD), # only the start byte
            ('\xf5\xf5', FFFD*2), # 2 start bytes
            ('\xf5\x80', FFFD*2), # only 1 continuation byte
            ('\xf5\x80\x80', FFFD*3), # only 2 continuation byte
            ('\xf5\x80\x80\x80', FFFD*4), # 3 continuation bytes
            ('\xf5\x80\x41', FFFD*2+'A'), #  1 valid cb and 1 invalid
            ('\xf5\x80\x41\xf5', FFFD*2+'A'+FFFD),
            ('\xf5\x41\x80\x80\x41', FFFD+'A'+FFFD*2+'A'),
            # with invalid start byte of a 5-byte sequence (rfc2279)
            ('\xf8', FFFD), # only the start byte
            ('\xf8\xf8', FFFD*2), # 2 start bytes
            ('\xf8\x80', FFFD*2), # only one continuation byte
            ('\xf8\x80\x41', FFFD*2 + 'A'), # 1 valid cb and 1 invalid
            ('\xf8\x80\x80\x80\x80', FFFD*5), # invalid 5 bytes seq with 5 bytes
            # with invalid start byte of a 6-byte sequence (rfc2279)
            ('\xfc', FFFD), # only the start byte
            ('\xfc\xfc', FFFD*2), # 2 start bytes
            ('\xfc\x80\x80', FFFD*3), # only 2 continuation bytes
            ('\xfc\x80\x80\x80\x80\x80', FFFD*6), # 6 continuation bytes
            # invalid start byte
            ('\xfe', FFFD),
            ('\xfe\x80\x80', FFFD*3),
            # other sequences
            ('\xf1\x80\x41\x42\x43', u'\ufffd\x41\x42\x43'),
            ('\xf1\x80\xff\x42\x43', u'\ufffd\ufffd\x42\x43'),
            ('\xf1\x80\xc2\x81\x43', u'\ufffd\x81\x43'),
            ('\x61\xF1\x80\x80\xE1\x80\xC2\x62\x80\x63\x80\xBF\x64',
             u'\x61\uFFFD\uFFFD\uFFFD\x62\uFFFD\x63\uFFFD\uFFFD\x64'),
        ]

        for n, (seq, res) in enumerate(sequences):
            decoder = self.getdecoder('utf-8')
            py.test.raises(UnicodeDecodeError, decoder, seq, len(seq), None, final=True)
            assert decoder(seq, len(seq), 'replace', final=True
                           ) == (res, len(seq))
            assert decoder(seq + 'b', len(seq) + 1, 'replace', final=True
                           ) == (res + u'b', len(seq) + 1)
            res = res.replace(FFFD, u'')
            assert decoder(seq, len(seq), 'ignore', final=True
                           ) == (res, len(seq))


class TestEncoding(UnicodeTests):
    def test_all_ascii(self):
        for i in range(128):
            if sys.version >= "2.7":
                self.checkencode(unichr(i), "utf-7")
            for encoding in "utf-8 latin-1 ascii".split():
                self.checkencode(unichr(i), encoding)

    def test_all_first_256(self):
        for i in range(256):
            if sys.version >= "2.7":
                self.checkencode(unichr(i), "utf-7")
            for encoding in ("utf-8 utf-16 utf-16-be utf-16-le "
                             "utf-32 utf-32-be utf-32-le").split():
                self.checkencode(unichr(i), encoding)

    def test_first_10000(self):
        for i in range(10000):
            if sys.version >= "2.7":
                self.checkencode(unichr(i), "utf-7")
            for encoding in ("utf-8 utf-16 utf-16-be utf-16-le "
                             "utf-32 utf-32-be utf-32-le").split():
                self.checkencode(unichr(i), encoding)

    def test_random(self):
        for i in range(10000):
            v = random.randrange(sys.maxunicode)
            if 0xd800 <= v <= 0xdfff:
                continue
            uni = unichr(v)
            if sys.version >= "2.7":
                self.checkencode(uni, "utf-7")
            for encoding in ("utf-8 utf-16 utf-16-be utf-16-le "
                             "utf-32 utf-32-be utf-32-le").split():
                self.checkencode(uni, encoding)

    def test_maxunicode(self):
        uni = unichr(sys.maxunicode)
        if sys.version >= "2.7":
            self.checkencode(uni, "utf-7")
        for encoding in ("utf-8 utf-16 utf-16-be utf-16-le "
                         "utf-32 utf-32-be utf-32-le").split():
            self.checkencode(uni, encoding)

    def test_empty(self):
        for encoding in ("utf-8 utf-16 utf-16-be utf-16-le "
                         "utf-32 utf-32-be utf-32-le").split():
            self.checkencode(u'', encoding)

    def test_single_chars_utf8(self):
        # check every number of bytes per char
        for s in ["\xd7\x90", "\xd6\x96", "\xeb\x96\x95", "\xf0\x90\x91\x93"]:
            self.checkencode(s, "utf-8")

    def test_utf8_surrogates(self):
        # make sure that the string itself is not marshalled
        u = u"\ud800"
        for i in range(4):
            u += u"\udc00"
        if runicode.MAXUNICODE < 65536:
            # Check replacing of two surrogates by single char while encoding
            self.checkencode(u, "utf-8")
        else:
            # This is not done in wide unicode builds
            py.test.raises(UnicodeEncodeError, self.checkencode, u, "utf-8")

    def test_ascii_error(self):
        self.checkencodeerror(u"abc\xFF\xFF\xFFcde", "ascii", 3, 6)

    def test_latin1_error(self):
        self.checkencodeerror(u"abc\uffff\uffff\uffffcde", "latin-1", 3, 6)

    def test_mbcs(self):
        if sys.platform != 'win32':
            py.test.skip("mbcs encoding is win32-specific")
        self.checkencode(u'encoding test', "mbcs")
        self.checkdecode('decoding test', "mbcs")
        # XXX test this on a non-western Windows installation
        self.checkencode(u"\N{GREEK CAPITAL LETTER PHI}", "mbcs") # a F
        self.checkencode(u"\N{GREEK CAPITAL LETTER PSI}", "mbcs") # a ?

    def test_mbcs_decode_force_ignore(self):
        if sys.platform != 'win32':
            py.test.skip("mbcs encoding is win32-specific")

        # XXX: requires a locale w/ a restrictive encoding to test
        from rpython.rlib.rlocale import getdefaultlocale
        if getdefaultlocale()[1] != 'cp932':
            py.test.skip("requires cp932 locale")

        s = '\xff\xf4\x8f\xbf\xbf'
        decoder = self.getdecoder('mbcs')
        assert decoder(s, len(s), 'strict') == (u'\U0010ffff', 5)
        py.test.raises(UnicodeEncodeError, decoder, s, len(s), 'strict',
                       force_ignore=False)

    def test_mbcs_encode_force_replace(self):
        if sys.platform != 'win32':
            py.test.skip("mbcs encoding is win32-specific")
        u = u'@test_2224_tmp-?L??\udc80'
        encoder = self.getencoder('mbcs')
        assert encoder(u, len(u), 'strict') == '@test_2224_tmp-?L???'
        py.test.raises(UnicodeEncodeError, encoder, u, len(u), 'strict',
                       force_replace=False)

    def test_encode_decimal(self):
        encoder = self.getencoder('decimal')
        assert encoder(u' 12, 34 ', 8, None) == ' 12, 34 '
        py.test.raises(UnicodeEncodeError, encoder, u' 12, \u1234 ', 7, None)
        assert encoder(u'u\u1234', 2, 'replace') == 'u?'

    def test_encode_utf8sp(self):
        # for the following test, go to lengths to avoid CPython's optimizer
        # and .pyc file storage, which collapse the two surrogates into one
        c = u"\udc00"
        for input, expected in [
                (u"", ""),
                (u"abc", "abc"),
                (u"\u1234", "\xe1\x88\xb4"),
                (u"\ud800", "\xed\xa0\x80"),
                (u"\udc00", "\xed\xb0\x80"),
                (u"\ud800" + c, "\xed\xa0\x80\xed\xb0\x80"),
            ]:
            got = runicode.unicode_encode_utf8sp(input, len(input))
            assert got == expected


class TestTranslation(object):
    def setup_class(cls):
        if runicode.MAXUNICODE != sys.maxunicode:
            py.test.skip("these tests cannot run on the llinterp")

    def test_utf8(self):
        from rpython.rtyper.test.test_llinterp import interpret
        def f(x):

            s1 = "".join(["\xd7\x90\xd6\x96\xeb\x96\x95\xf0\x90\x91\x93"] * x)
            u, consumed = runicode.str_decode_utf_8(s1, len(s1), 'strict',
                                                    allow_surrogates=True)
            s2 = runicode.unicode_encode_utf_8(u, len(u), 'strict',
                                                    allow_surrogates=True)
            u3, consumed3 = runicode.str_decode_utf_8(s1, len(s1), 'strict',
                                                    allow_surrogates=False)
            s3 = runicode.unicode_encode_utf_8(u3, len(u3), 'strict',
                                                    allow_surrogates=False)
            return s1 == s2 == s3
        res = interpret(f, [2])
        assert res

    def test_surrogates(self):
        if runicode.MAXUNICODE < 65536:
            py.test.skip("Narrow unicode build")
        from rpython.rtyper.test.test_llinterp import interpret
        def f(x):
            u = runicode.UNICHR(x)
            t = runicode.ORD(u)
            return t

        res = interpret(f, [0x10140])
        assert res == 0x10140

    def test_encode_surrogate_pair(self):
        u = runicode.UNICHR(0xD800) + runicode.UNICHR(0xDC00)
        if runicode.MAXUNICODE < 65536:
            # Narrow unicode build, consider utf16 surrogate pairs
            assert runicode.unicode_encode_unicode_escape(
                u, len(u), True) == r'\U00010000'
            assert runicode.unicode_encode_raw_unicode_escape(
                u, len(u), True) == r'\U00010000'
        else:
            # Wide unicode build, don't merge utf16 surrogate pairs
            assert runicode.unicode_encode_unicode_escape(
                u, len(u), True) == r'\ud800\udc00'
            assert runicode.unicode_encode_raw_unicode_escape(
                u, len(u), True) == r'\ud800\udc00'

    def test_encode_surrogate_pair_utf8(self):
        u = runicode.UNICHR(0xD800) + runicode.UNICHR(0xDC00)
        if runicode.MAXUNICODE < 65536:
            # Narrow unicode build, consider utf16 surrogate pairs
            assert runicode.unicode_encode_utf_8(
                u, len(u), True, allow_surrogates=True) == '\xf0\x90\x80\x80'
            assert runicode.unicode_encode_utf_8(
                u, len(u), True, allow_surrogates=False) == '\xf0\x90\x80\x80'
        else:
            # Wide unicode build, merge utf16 surrogate pairs only when allowed
            assert runicode.unicode_encode_utf_8(
                u, len(u), True, allow_surrogates=True) == '\xf0\x90\x80\x80'
            # Surrogates not merged, encoding fails.
            py.test.raises(
                UnicodeEncodeError, runicode.unicode_encode_utf_8,
                u, len(u), True, allow_surrogates=False)
