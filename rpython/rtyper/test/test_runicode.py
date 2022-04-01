# -*- encoding: utf-8 -*-

from rpython.rtyper.lltypesystem.lltype import malloc
from rpython.rtyper.lltypesystem.rstr import LLHelpers, UNICODE
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.test.test_rstr import AbstractTestRstr
import py

# ====> test_rstr.py

class TestRUnicode(AbstractTestRstr, BaseRtypingTest):
    const = unicode
    constchar = unichr

    def test_unicode_explicit_conv(self):
        def f(x):
            return unicode(x)

        for v in ['x', u'x']:
            res = self.interpret(f, [v])
            assert self.ll_to_unicode(res) == v

        def f(x):
            if x > 1:
                y = const('yxx')
            else:
                y = const('xx')
            return unicode(y)

        const = str
        assert self.ll_to_unicode(self.interpret(f, [1])) == f(1)

        def f(x):
            if x > 1:
                y = const('yxx')
            else:
                y = const('xx')
            return unicode(y)

        # a copy, because llinterp caches functions

        const = unicode
        assert self.ll_to_unicode(self.interpret(f, [1])) == f(1)

    def test_str_unicode_const(self):
        def f():
            return str(u'xxx')

        assert self.ll_to_string(self.interpret(f, [])) == 'xxx'

    def test_unicode_of_unicode(self):
        def f(x):
            return len(unicode(unichr(x) * 3))
        assert self.interpret(f, [ord('a')]) == 3
        assert self.interpret(f, [128]) == 3
        assert self.interpret(f, [1000]) == 3

    def test_unicode_of_unichar(self):
        def f(x):
            return len(unicode(unichr(x)))
        assert self.interpret(f, [ord('a')]) == 1
        assert self.interpret(f, [128]) == 1
        assert self.interpret(f, [1000]) == 1

    def test_conversion_errors(self):
        py.test.skip("do we want this test to pass?")
        def f(x):
            if x:
                string = '\x80\x81'
                uni = u'\x80\x81'
            else:
                string = '\x82\x83'
                uni = u'\x83\x84\x84'
            try:
                str(uni)
            except UnicodeEncodeError:
                pass
            else:
                return -1
            try:
                unicode(string)
            except UnicodeDecodeError:
                return len(string) + len(uni)
            else:
                return -2
        assert f(True) == 4
        assert f(False) == 5
        res = self.interpret(f, [True])
        assert res == 4


    def test_str_unicode_nonconst(self):
        def f(x):
            y = u'xxx' + unichr(x)
            return str(y)

        assert self.ll_to_string(self.interpret(f, [38])) == f(38)
        self.interpret_raises(UnicodeEncodeError, f, [1234])

    def test_unicode_encode(self):
        def f(n):
            x = u'xxx' + unichr(n)
            y = u'àèì' + unichr(n)
            z = u'美' + unichr(n)
            return x.encode('ascii') + y.encode('latin-1') + z.encode('utf-8')

        assert self.ll_to_string(self.interpret(f, [38])) == f(38)

        def g(n):
            x = u'\ud800' + unichr(n)
            return x.encode('utf-8')

        # used to raise in RPython, but not when run as plain Python,
        # which just makes code very hard to test.  Nowadays, .encode()
        # and .decode() accept surrogates like in Python 2.7.  Use
        # functions from the rlib.runicode module if you need stricter
        # behavior.
        #self.interpret_raises(UnicodeEncodeError, g, [38])
        assert self.ll_to_string(self.interpret(g, [38])) == g(38)

    def test_utf_8_encoding_annotation(self):
        from rpython.rlib.runicode import unicode_encode_utf_8
        def errorhandler(errors, encoding, msg, u,
                         startingpos, endingpos):
            raise UnicodeEncodeError(encoding, u, startingpos, endingpos, msg)
        def f(n):
            x = u'àèì' + unichr(n)
            if x:
                y = u'ìòé'
            else:
                y = u'òìàà'
            # the annotation of y is SomeUnicodeString(can_be_None=False)
            y = unicode_encode_utf_8(y, len(y), 'strict', errorhandler)
            return x.encode('utf-8') + y

        assert self.ll_to_string(self.interpret(f, [38])) == f(38)

    def test_unicode_encode_error(self):
        def f(x, which):
            if which:
                y = u'xxx'
                try:
                    x = (y + unichr(x)).encode('ascii')
                    return len(x)
                except UnicodeEncodeError:
                    return -1
            else:
                y = u'xxx'
                try:
                    x = (y + unichr(x)).encode('latin-1')
                    return len(x)
                except UnicodeEncodeError:
                    return -1

        assert self.interpret(f, [38, True]) == f(38, True)
        assert self.interpret(f, [138, True]) == f(138, True)
        assert self.interpret(f, [38, False]) == f(38, False)
        assert self.interpret(f, [138, False]) == f(138, False)
        assert self.interpret(f, [300, False]) == f(300, False)

    def test_unicode_decode(self):
        strings = ['xxx', u'àèì'.encode('latin-1'), u'美'.encode('utf-8')]
        def f(n):
            x = strings[n]
            y = strings[n+1]
            z = strings[n+2]
            return x.decode('ascii') + y.decode('latin-1') + z.decode('utf-8')

        assert self.ll_to_string(self.interpret(f, [0])) == f(0)

    def test_unicode_decode_final(self):
        strings = ['\xc3', '']
        def f(n):
            try:
                strings[n].decode('utf-8')
            except UnicodeDecodeError:
                return True
            return False

        assert f(0)
        assert self.interpret(f, [0])

    def test_utf_8_decoding_annotation(self):
        from rpython.rlib.runicode import str_decode_utf_8
        def errorhandler(errors, encoding, msg, s,
                         startingpos, endingpos):
            raise UnicodeDecodeError(encoding, s, startingpos, endingpos, msg)

        strings = [u'àèì'.encode('utf-8'), u'ìòéà'.encode('utf-8')]
        def f(n):
            x = strings[n]
            if n:
                errors = 'strict'
            else:
                errors = 'foo'
            # the annotation of y is SomeUnicodeString(can_be_None=False)
            y, _ = str_decode_utf_8(x, len(x), errors, errorhandler=errorhandler)
            return x.decode('utf-8') + y

        assert self.ll_to_string(self.interpret(f, [1])) == f(1)

    def test_unicode_decode_error(self):
        def f(x):
            y = 'xxx'
            try:
                x = (y + chr(x)).decode('ascii')
                return len(x)
            except UnicodeDecodeError:
                return -1

        assert self.interpret(f, [38]) == f(38)
        assert self.interpret(f, [138]) == f(138)


    def test_unichar_const(self):
        def fn(c):
            return c
        assert self.interpret(fn, [u'\u03b1']) == u'\u03b1'

    def test_unichar_eq(self):
        def fn(c1, c2):
            return c1 == c2
        assert self.interpret(fn, [u'\u03b1', u'\u03b1']) == True
        assert self.interpret(fn, [u'\u03b1', u'\u03b2']) == False

    def test_unichar_ord(self):
        def fn(c):
            return ord(c)
        assert self.interpret(fn, [u'\u03b1']) == ord(u'\u03b1')

    def test_unichar_hash(self):
        def fn(c):
            d = {c: 42}
            return d[c]
        assert self.interpret(fn, [u'\u03b1']) == 42

    def test_strformat_unicode_arg(self):
        const = self.const
        def percentS(s, i):
            s = [s, None][i]
            return const("before %s after") % (s,)
        #
        res = self.interpret(percentS, [const(u'à'), 0])
        assert self.ll_to_string(res) == const(u'before à after')
        #
        res = self.interpret(percentS, [const(u'à'), 1])
        assert self.ll_to_string(res) == const(u'before None after')
        #

    def test_strformat_unicode_and_str(self):
        # test that we correctly specialize ll_constant when we pass both a
        # string and an unicode to it
        const = self.const
        def percentS(ch):
            x = "%s" % (ch + "bc")
            y = u"%s" % (unichr(ord(ch)) + u"bc")
            return len(x) + len(y)
        #
        res = self.interpret(percentS, ["a"])
        assert res == 6

    def unsupported(self):
        py.test.skip("not supported")

    test_char_isxxx = unsupported
    test_isdigit = unsupported
    test_str_isalpha = unsupported
    test_str_isalnum = unsupported
    test_upper = unsupported
    test_lower = unsupported
    test_splitlines = unsupported
    test_int = unsupported
    test_int_valueerror = unsupported
    test_float = unsupported
    test_hlstr = unsupported
    test_strip_multiple_chars = unsupported

    def test_hash_via_type(self):
        from rpython.rlib.objectmodel import compute_hash

        def f(n):
            s = malloc(UNICODE, n)
            s.hash = 0
            for i in range(n):
                s.chars[i] = unichr(ord('A') + i)
            return s.gethash() - compute_hash(u'ABCDE')

        res = self.interpret(f, [5])
        assert res == 0

    def test_unicode_char_comparison(self):
        const = u'abcdef'
        def f(n):
            return const[n] >= u'c'

        res = self.interpret(f, [1])
        assert res == False
        res = self.interpret(f, [2])
        assert res == True

    def test_strip_no_arg(self):

        def f():
            return u'abcdef'.strip()

        e = py.test.raises(Exception, self.interpret, f, [])
        assert "unicode.strip() with no arg is not RPython" in str(e.value)
