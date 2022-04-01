from pypy.interpreter.pyparser import parsestring
from pypy.interpreter.pyparser.error import SyntaxError
from pypy.interpreter.pyparser.parser import Terminal

import py, sys

class TestParsetring:
    def parse_and_compare(self, literal, value, encoding=None):
        space = self.space
        w_ret = parsestring.parsestr(space, encoding, literal)
        if isinstance(value, str):
            assert space.type(w_ret) == space.w_bytes
            assert space.bytes_w(w_ret) == value
        elif isinstance(value, unicode):
            assert space.type(w_ret) == space.w_unicode
            assert space.utf8_w(w_ret).decode('utf8') == value
        else:
            assert False

    def test_simple(self):
        space = self.space
        for s in ['hello world', 'hello\n world']:
            self.parse_and_compare('b' + repr(s), s)

        self.parse_and_compare("b'''hello\\x42 world'''", 'hello\x42 world')

        # octal
        self.parse_and_compare(r'b"\0"', chr(0))
        self.parse_and_compare(r'br"\0"', '\\0')
        self.parse_and_compare(r'rb"\0"', '\\0')
        self.parse_and_compare(r'b"\07"', chr(7))
        self.parse_and_compare(r'b"\123"', chr(0123))
        self.parse_and_compare(r'b"\400"', chr(0))
        self.parse_and_compare(r'b"\9"', '\\' + '9')
        self.parse_and_compare(r'b"\08"', chr(0) + '8')

        # hexadecimal
        self.parse_and_compare(r'b"\xfF"', chr(0xFF))
        self.parse_and_compare(r'b"\""', '"')
        self.parse_and_compare(r"b'\''", "'")
        for s in (r'b"\x"', r'b"\x7"', r'b"\x7g"'):
            space.raises_w(space.w_ValueError,
                           parsestring.parsestr, space, None, s)

        # only ASCII characters are allowed in bytes literals (but of course
        # you can use escapes to get the non-ASCII ones (note that in the
        # second case we use a raw string, the the parser actually sees the
        # chars '\' 'x' 'e' '9'
        excinfo = py.test.raises(SyntaxError,
                       parsestring.parsestr, space, None,
                       "b'     \xe9'", Terminal(None, -1, "b'     \xe9'", 5, 0))
        assert excinfo.value.offset == 8
        self.parse_and_compare(r"b'\xe9'", chr(0xE9))

    def test_unicode(self):
        for s in ['hello world', 'hello\n world']:
            self.parse_and_compare(repr(s), unicode(s))

        self.parse_and_compare("'''hello\\x42 world'''",
                               u'hello\x42 world')
        self.parse_and_compare("'''hello\\u0842 world'''",
                               u'hello\u0842 world')

        s = "u'\x81'"
        s = s.decode("koi8-u").encode("utf8")[1:]
        w_ret = parsestring.parsestr(self.space, 'koi8-u', s)
        ret = w_ret._utf8.decode('utf8')
        assert ret == eval("# -*- coding: koi8-u -*-\nu'\x81'")

    def test_unicode_pep414(self):
        space = self.space
        for s in [u'hello world', u'hello\n world']:
            self.parse_and_compare(repr(s), unicode(s))

        self.parse_and_compare("u'''hello\\x42 world'''",
                               u'hello\x42 world')
        self.parse_and_compare("u'''hello\\u0842 world'''",
                               u'hello\u0842 world')

        space.raises_w(space.w_ValueError,
                       parsestring.parsestr, space, None, "ur'foo'")

    def test_unicode_literals(self):
        space = self.space
        w_ret = parsestring.parsestr(space, None, repr("hello"))
        assert space.isinstance_w(w_ret, space.w_unicode)
        w_ret = parsestring.parsestr(space, None, "b'hi'")
        assert space.isinstance_w(w_ret, space.w_bytes)
        w_ret = parsestring.parsestr(space, None, "r'hi'")
        assert space.isinstance_w(w_ret, space.w_unicode)

    def test_raw_unicode_literals(self):
        space = self.space
        w_ret = parsestring.parsestr(space, None, "r'\u'")
        assert space.int_w(space.len(w_ret)) == 2

    def test_bytes(self):
        space = self.space
        b = "b'hello'"
        w_ret = parsestring.parsestr(space, None, b)
        assert space.unwrap(w_ret) == "hello"
        b = "b'''hello'''"
        w_ret = parsestring.parsestr(space, None, b)
        assert space.unwrap(w_ret) == "hello"

    def test_simple_enc_roundtrip(self):
        space = self.space
        s = "'\x81\\t'"
        s = s.decode("koi8-u").encode("utf8")
        w_ret = parsestring.parsestr(self.space, 'koi8-u', s)
        ret = space.unwrap(w_ret)
        assert ret == eval("# -*- coding: koi8-u -*-\nu'\x81\\t'")

    def test_multiline_unicode_strings_with_backslash(self):
        space = self.space
        s = '"""' + '\\' + '\n"""'
        w_ret = parsestring.parsestr(space, None, s)
        assert space.text_w(w_ret) == ''

    def test_bug1(self):
        space = self.space
        expected = ['x', ' ', chr(0xc3), chr(0xa9), ' ', '\n']
        input = ["'", 'x', ' ', chr(0xc3), chr(0xa9), ' ', chr(92), 'n', "'"]
        w_ret = parsestring.parsestr(space, 'utf8', ''.join(input))
        assert space.text_w(w_ret) == ''.join(expected)

    def test_wide_unicode_in_source(self):
        if sys.maxunicode == 65535:
            py.test.skip("requires a wide-unicode host")
        self.parse_and_compare('"\xf0\x9f\x92\x8b"',
                               unichr(0x1f48b),
                               encoding='utf-8')

    def test_decode_unicode_utf8(self):
        buf = parsestring.decode_unicode_utf8(self.space,
                                              'u"\xf0\x9f\x92\x8b"', 2, 6)
        assert buf == r"\U0001f48b"

    def test_parsestr_segfault(self):
        space = self.space
        space.raises_w(space.w_UnicodeDecodeError,
                       parsestring.parsestr, space, None, "r'\xc2'")
