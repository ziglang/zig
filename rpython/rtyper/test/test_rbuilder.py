from __future__ import with_statement

import py

from rpython.rlib.rstring import StringBuilder, UnicodeBuilder
from rpython.rtyper.annlowlevel import llstr, hlstr, llunicode, hlunicode
from rpython.rtyper.lltypesystem import rffi
from rpython.rtyper.lltypesystem.rbuilder import StringBuilderRepr, UnicodeBuilderRepr
from rpython.rtyper.test.tool import BaseRtypingTest


class TestStringBuilderDirect(object):
    def test_nooveralloc(self):
        sb = StringBuilderRepr.ll_new(33)
        StringBuilderRepr.ll_append(sb, llstr("abc" * 11))
        assert StringBuilderRepr.ll_getlength(sb) == 33
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == "abc" * 11
        assert StringBuilderRepr.ll_getlength(sb) == 33

    def test_shrinking(self):
        sb = StringBuilderRepr.ll_new(100)
        StringBuilderRepr.ll_append(sb, llstr("abc" * 11))
        assert StringBuilderRepr.ll_getlength(sb) == 33
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == "abc" * 11
        assert StringBuilderRepr.ll_getlength(sb) == 33

    def test_simple(self):
        sb = StringBuilderRepr.ll_new(3)
        assert StringBuilderRepr.ll_getlength(sb) == 0
        StringBuilderRepr.ll_append_char(sb, 'x')
        assert StringBuilderRepr.ll_getlength(sb) == 1
        StringBuilderRepr.ll_append(sb, llstr("abc"))
        assert StringBuilderRepr.ll_getlength(sb) == 4
        StringBuilderRepr.ll_append_slice(sb, llstr("foobar"), 2, 5)
        assert StringBuilderRepr.ll_getlength(sb) == 7
        StringBuilderRepr.ll_append_multiple_char(sb, 'y', 3)
        assert StringBuilderRepr.ll_getlength(sb) == 10
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == "xabcobayyy"
        assert StringBuilderRepr.ll_getlength(sb) == 10

    def test_grow_when_append_char(self):
        sb = StringBuilderRepr.ll_new(33)
        StringBuilderRepr.ll_append(sb, llstr("abc" * 11))
        StringBuilderRepr.ll_append_char(sb, "d")
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == "abc" * 11 + "d"

    def test_grow_two_halves(self):
        sb = StringBuilderRepr.ll_new(32)
        StringBuilderRepr.ll_append(sb, llstr("abc" * 11))
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == "abc" * 11

    def test_grow_when_exactly_full(self):
        sb = StringBuilderRepr.ll_new(33)
        StringBuilderRepr.ll_append(sb, llstr("abc" * 11))
        StringBuilderRepr.ll_append(sb, llstr("def"))
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == "abc" * 11 + "def"

    def test_charp(self):
        sb = StringBuilderRepr.ll_new(32)
        with rffi.scoped_str2charp("hello world") as p:
            StringBuilderRepr.ll_append_charpsize(sb, p, 12)
        with rffi.scoped_str2charp("0123456789abcdefghijklmn") as p:
            StringBuilderRepr.ll_append_charpsize(sb, p, 24)
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == "hello world\x000123456789abcdefghijklmn"

    def test_unicode(self):
        sb = UnicodeBuilderRepr.ll_new(32)
        UnicodeBuilderRepr.ll_append_char(sb, u'x')
        UnicodeBuilderRepr.ll_append(sb, llunicode(u"abc"))
        UnicodeBuilderRepr.ll_append_slice(sb, llunicode(u"foobar"), 2, 5)
        UnicodeBuilderRepr.ll_append_multiple_char(sb, u'y', 30)
        u = UnicodeBuilderRepr.ll_build(sb)
        assert hlunicode(u) == u"xabcoba" + u"y" * 30

    def test_several_builds(self):
        sb = StringBuilderRepr.ll_new(32)
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == ""
        assert s == StringBuilderRepr.ll_build(sb)
        assert s == StringBuilderRepr.ll_build(sb)
        #
        sb = StringBuilderRepr.ll_new(32)
        StringBuilderRepr.ll_append(sb, llstr("abcdefgh" * 3))   # not full
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == "abcdefgh" * 3
        assert s == StringBuilderRepr.ll_build(sb)
        assert s == StringBuilderRepr.ll_build(sb)
        StringBuilderRepr.ll_append(sb, llstr("extra"))    # overflow
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == "abcdefgh" * 3 + "extra"
        assert s == StringBuilderRepr.ll_build(sb)
        assert s == StringBuilderRepr.ll_build(sb)

    def test_large_build(self):
        s1 = 'xyz' * 500
        s2 = 'XYZ' * 500
        #
        sb = StringBuilderRepr.ll_new(32)
        StringBuilderRepr.ll_append(sb, llstr(s1))
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == s1
        #
        sb = StringBuilderRepr.ll_new(32)
        StringBuilderRepr.ll_append(sb, llstr(s1))
        StringBuilderRepr.ll_append(sb, llstr(s2))
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == s1 + s2
        #
        sb = StringBuilderRepr.ll_new(32)
        StringBuilderRepr.ll_append(sb, llstr(s1))
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == s1
        StringBuilderRepr.ll_append(sb, llstr(s2))
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == s1 + s2
        #
        sb = StringBuilderRepr.ll_new(32)
        StringBuilderRepr.ll_append(sb, llstr(s1))
        StringBuilderRepr.ll_append_char(sb, '.')
        s = StringBuilderRepr.ll_build(sb)
        assert hlstr(s) == s1 + '.'
        #
        for start in [0, 1]:
            for stop in [len(s1), len(s1) - 1]:
                sb = StringBuilderRepr.ll_new(32)
                StringBuilderRepr.ll_append_slice(sb, llstr(s1), start, stop)
                s = StringBuilderRepr.ll_build(sb)
                assert hlstr(s) == s1[start:stop]


class TestStringBuilder(BaseRtypingTest):
    def test_simple(self):
        def func():
            s = StringBuilder()
            s.append("a")
            s.append("abc")
            s.append_slice("abc", 1, 2)
            s.append_multiple_char('d', 4)
            return s.build()
        res = self.ll_to_string(self.interpret(func, []))
        assert res == "aabcbdddd"

    def test_overallocation(self):
        def func():
            s = StringBuilder(34)
            s.append("abcd" * 5)
            s.append("defg" * 5)
            s.append("rty")
            return s.build()
        res = self.ll_to_string(self.interpret(func, []))
        assert res == "abcd" * 5 + "defg" * 5 + "rty"

    def test_unicode(self):
        def func():
            s = UnicodeBuilder(32)
            s.append(u'a')
            s.append(u'abc')
            s.append(u'abcdef')
            s.append_slice(u'abc', 1, 2)
            s.append_multiple_char(u'u', 40)
            return s.build()
        res = self.ll_to_unicode(self.interpret(func, []))
        assert res == u'aabcabcdefb' + u'u' * 40
        assert isinstance(res, unicode)

    def test_string_getlength(self):
        def func():
            s = StringBuilder()
            s.append("a")
            s.append("abc")
            return s.getlength()
        res = self.interpret(func, [])
        assert res == 4

    def test_unicode_getlength(self):
        def func():
            s = UnicodeBuilder()
            s.append(u"a")
            s.append(u"abc")
            return s.getlength()
        res = self.interpret(func, [])
        assert res == 4

    def test_append_charpsize(self):
        def func(l):
            s = StringBuilder()
            with rffi.scoped_str2charp("hello world") as x:
                s.append_charpsize(x, l)
            return s.build()
        res = self.ll_to_string(self.interpret(func, [5]))
        assert res == "hello"

    def test_builder_or_none(self):
        def g(s):
            if s:
                s.append("3")
            return bool(s)

        def func(i):
            if i:
                s = StringBuilder()
            else:
                s = None
            return g(s)
        res = self.interpret(func, [0])
        assert not res
        res = self.interpret(func, [1])
        assert res

    def test_unicode_builder_or_none(self):
        def g(s):
            if s:
                s.append(u"3")
            return bool(s)

        def func(i):
            if i:
                s = UnicodeBuilder()
            else:
                s = None
            return g(s)
        res = self.interpret(func, [0])
        assert not res
        res = self.interpret(func, [1])
        assert res

    def test_prebuilt_string_builder(self):
        s = StringBuilder(100)
        s.append("abc")
        
        def f():
            return len(s.build())

        res = self.interpret(f, [])
        assert res == 3

    def test_prebuilt_unicode_builder(self):
        s = UnicodeBuilder(100)
        s.append(u"abc")
        
        def f():
            return len(s.build())

        res = self.interpret(f, [])
        assert res == 3

    def test_string_builder_union(self):
        s = StringBuilder()

        def f(i):
            if i % 2:
                s2 = StringBuilder()
            else:
                s2 = s
            return s2.build()

        self.interpret(f, [3])
