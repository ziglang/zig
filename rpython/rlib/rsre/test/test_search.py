# encoding: utf-8
import re, py
from rpython.rlib.rsre.test.test_match import get_code, get_code_and_re
from rpython.rlib.rsre.test import support
from rpython.rlib.rsre import rsre_core, rsre_utf8, rsre_char

def setup_module(mod):
    from rpython.rlib.unicodedata import unicodedb
    rsre_char.set_unicode_db(unicodedb)


class BaseTestSearch:

    def test_code1(self):
        r_code1 = get_code(r'[abc][def][ghi]')
        res = self.search(r_code1, "fooahedixxx")
        assert res is None
        res = self.search(r_code1, "fooahcdixxx")
        assert res is not None
        P = self.P
        assert res.span() == (P(5), P(8))

    def test_code2(self):
        r_code2 = get_code(r'<item>\s*<title>(.*?)</title>')
        res = self.search(r_code2, "foo bar <item>  <title>abc</title>def")
        assert res is not None
        P = self.P
        assert res.span() == (P(8), P(34))

    def test_pure_literal(self):
        r_code3 = get_code(r'foobar')
        res = self.search(r_code3, "foo bar foobar baz")
        assert res is not None
        P = self.P
        assert res.span() == (P(8), P(14))

    def test_code3(self):
        r_code1 = get_code(r'<item>\s*<title>(.*?)</title>')
        res = self.match(r_code1, "<item>  <title>abc</title>def")
        assert res is not None

    def test_max_until_0_65535(self):
        r_code2 = get_code(r'<abc>(?:xy)*xy</abc>')
        #res = self.match(r_code2, '<abc></abc>def')
        #assert res is None
        #res = self.match(r_code2, '<abc>xy</abc>def')
        #assert res is not None
        res = self.match(r_code2, '<abc>xyxyxy</abc>def')
        assert res is not None
        res = self.match(r_code2, '<abc>' + 'xy'*1000 + '</abc>def')
        assert res is not None

    def test_max_until_3_5(self):
        r_code2, r = get_code_and_re(r'<abc>(?:xy){3,5}xy</abc>')
        for i in range(8):
            s = '<abc>' + 'xy'*i + '</abc>defdefdefdefdef'
            assert (r.match(s) is not None) is (3 <= i-1 <= 5)
            res = self.match(r_code2, s)
            assert (res is not None) is (3 <= i-1 <= 5)

    def test_min_until_0_65535(self):
        r_code2 = get_code(r'<abc>(?:xy)*?xy</abc>')
        res = self.match(r_code2, '<abc></abc>def')
        assert res is None
        res = self.match(r_code2, '<abc>xy</abc>def')
        assert res is not None
        res = self.match(r_code2, '<abc>xyxyxy</abc>def')
        assert res is not None
        res = self.match(r_code2, '<abc>' + 'xy'*1000 + '</abc>def')
        assert res is not None

    def test_min_until_3_5(self):
        r_code2, r = get_code_and_re(r'<abc>(?:xy){3,5}?xy</abc>')
        for i in range(8):
            s = '<abc>' + 'xy'*i + '</abc>defdefdefdefdef'
            assert (r.match(s) is not None) is (3 <= i-1 <= 5)
            res = self.match(r_code2, s)
            assert (res is not None) is (3 <= i-1 <= 5)

    def test_min_repeat_one(self):
        r_code3 = get_code(r'<abc>.{3,5}?y')
        for i in range(8):
            res = self.match(r_code3, '<abc>' + 'x'*i + 'y')
            assert (res is not None) is (3 <= i <= 5)

    def test_simple_group(self):
        r_code4 = get_code(r'<abc>(x.)</abc>')
        res = self.match(r_code4, '<abc>xa</abc>def')
        assert res is not None
        P = self.P
        assert res.get_mark(0) == P(5)
        assert res.get_mark(1) == P(7)

    def test_max_until_groups(self):
        r_code4 = get_code(r'<abc>(x.)*xy</abc>')
        res = self.match(r_code4, '<abc>xaxbxy</abc>def')
        assert res is not None
        P = self.P
        assert res.get_mark(0) == P(7)
        assert res.get_mark(1) == P(9)

    def test_group_branch(self):
        r_code5 = get_code(r'<abc>(ab|c)</abc>')
        res = self.match(r_code5, '<abc>ab</abc>def')
        P = self.P
        assert (res.get_mark(0), res.get_mark(1)) == (P(5), P(7))
        res = self.match(r_code5, '<abc>c</abc>def')
        assert (res.get_mark(0), res.get_mark(1)) == (P(5), P(6))
        res = self.match(r_code5, '<abc>de</abc>def')
        assert res is None

    def test_group_branch_max_until(self):
        r_code6 = get_code(r'<abc>(ab|c)*a</abc>')
        res = self.match(r_code6, '<abc>ccabcccaba</abc>def')
        P = self.P
        assert (res.get_mark(0), res.get_mark(1)) == (P(12), P(14))
        r_code7 = get_code(r'<abc>((ab)|(c))*a</abc>')
        res = self.match(r_code7, '<abc>ccabcccaba</abc>def')
        assert (res.get_mark(0), res.get_mark(1)) == (P(12), P(14))
        assert (res.get_mark(2), res.get_mark(3)) == (P(12), P(14))
        assert (res.get_mark(4), res.get_mark(5)) == (P(11), P(12))

    def test_group_7(self):
        r_code7, r7 = get_code_and_re(r'<abc>((a)?(b))*</abc>')
        m = r7.match('<abc>bbbabbbb</abc>')
        assert m.span(1) == (12, 13)
        assert m.span(3) == (12, 13)
        assert m.span(2) == (8, 9)
        res = self.match(r_code7, '<abc>bbbabbbb</abc>')
        P = self.P
        assert (res.get_mark(0), res.get_mark(1)) == (P(12), P(13))
        assert (res.get_mark(4), res.get_mark(5)) == (P(12), P(13))
        assert (res.get_mark(2), res.get_mark(3)) == (P(8), P(9))

    def test_group_branch_repeat_complex_case(self):
        r_code8, r8 = get_code_and_re(r'<abc>((a)|(b))*</abc>')
        m = r8.match('<abc>ab</abc>')
        assert m.span(1) == (6, 7)
        assert m.span(3) == (6, 7)
        assert m.span(2) == (5, 6)
        res = self.match(r_code8, '<abc>ab</abc>')
        P = self.P
        assert (res.get_mark(0), res.get_mark(1)) == (P(6), P(7))
        assert (res.get_mark(4), res.get_mark(5)) == (P(6), P(7))
        assert (res.get_mark(2), res.get_mark(3)) == (P(5), P(6))

    def test_minuntil_lastmark_restore(self):
        r_code9, r9 = get_code_and_re(r'(x|yz)+?(y)??c')
        m = r9.match('xyzxc')
        assert m.span(1) == (3, 4)
        assert m.span(2) == (-1, -1)
        res = self.match(r_code9, 'xyzxc')
        P = self.P
        assert (res.get_mark(0), res.get_mark(1)) == (P(3), P(4))
        assert (res.get_mark(2), res.get_mark(3)) == (-1, -1)

    def test_minuntil_bug(self):
        r_code9, r9 = get_code_and_re(r'((x|yz)+?(y)??c)*')
        m = r9.match('xycxyzxc')
        assert m.span(2) == (6, 7)
        #assert self.match.span(3) == (1, 2) --- bug of CPython
        res = self.match(r_code9, 'xycxyzxc')
        P = self.P
        assert (res.get_mark(2), res.get_mark(3)) == (P(6), P(7))
        assert (res.get_mark(4), res.get_mark(5)) == (P(1), P(2))

    def test_empty_maxuntil(self):
        r_code, r = get_code_and_re(r'(a?)+y')
        assert r.match('y')
        assert r.match('aaayaaay').span() == (0, 4)
        res = self.match(r_code, 'y')
        assert res
        res = self.match(r_code, 'aaayaaay')
        P = self.P
        assert res and res.span() == (P(0), P(4))
        #
        r_code, r = get_code_and_re(r'(a?){4,6}y')
        assert r.match('y')
        res = self.match(r_code, 'y')
        assert res
        #
        r_code, r = get_code_and_re(r'(a?)*y')
        assert r.match('y')
        res = self.match(r_code, 'y')
        assert res

    def test_empty_maxuntil_2(self):
        try:
            r_code, r = get_code_and_re(r'X(.*?)+X')
        except re.error as e:
            py.test.skip("older version of the stdlib: %s" % (e,))
        assert r.match('XfooXbarX').span() == (0, 5)
        assert r.match('XfooXbarX').span(1) == (4, 4)
        res = self.match(r_code, 'XfooXbarX')
        P = self.P
        assert res.span() == (P(0), P(5))
        assert res.span(1) == (P(4), P(4))

    def test_empty_minuntil(self):
        r_code, r = get_code_and_re(r'(a?)+?y')
        #assert not r.match('z') -- CPython bug (at least 2.5) eats all memory
        res = self.match(r_code, 'z')
        assert not res
        #
        r_code, r = get_code_and_re(r'(a?){4,6}?y')
        assert not r.match('z')
        res = self.match(r_code, 'z')
        assert not res
        #
        r_code, r = get_code_and_re(r'(a?)*?y')
        #assert not r.match('z') -- CPython bug (at least 2.5) eats all memory
        res = self.match(r_code, 'z')
        assert not res

    def test_empty_search(self):
        r_code, r = get_code_and_re(r'')
        for j in range(-2, 6):
            for i in range(-2, 6):
                match = r.search('abc', i, j)
                res = self.search(r_code, 'abc', i, j)
                jk = min(max(j, 0), 3)
                ik = min(max(i, 0), 3)
                if ik <= jk:
                    assert match is not None
                    assert match.span() == (ik, ik)
                    assert res is not None
                    assert res.match_start == self.P(ik)
                    assert res.match_end == self.P(ik)
                else:
                    assert match is None
                    assert res is None


class TestSearchCustom(BaseTestSearch):
    search = staticmethod(support.search)
    match = staticmethod(support.match)
    P = support.Position

class TestSearchStr(BaseTestSearch):
    search = staticmethod(rsre_core.search)
    match = staticmethod(rsre_core.match)
    P = staticmethod(lambda n: n)

class TestSearchUtf8(BaseTestSearch):
    search = staticmethod(rsre_utf8.utf8search)
    match = staticmethod(rsre_utf8.utf8match)
    P = staticmethod(lambda n: n)   # NB. only for plain ascii

    def test_groupref_unicode_bug(self):
        r = get_code(ur"(üü+)\1+$", re.UNICODE)     # match non-prime numbers of ü
        assert not self.match(r, u"üü".encode("utf-8"))
        assert not self.match(r, u"üüü".encode("utf-8"))
        assert     self.match(r, u"üüüü".encode("utf-8"))
        assert not self.match(r, u"üüüüü".encode("utf-8"))
        assert     self.match(r, u"üüüüüü".encode("utf-8"))
        assert not self.match(r, u"üüüüüüü".encode("utf-8"))
        assert     self.match(r, u"üüüüüüüü".encode("utf-8"))
        assert     self.match(r, u"üüüüüüüüü".encode("utf-8"))

    def test_literal_uni_ignore(self):
        r = get_code(u"(?i)\u0135")
        assert self.match(r, u'\u0134')
        assert self.match(r, u'\u0134'.lower())
        assert not self.match(r, "a")
        assert not self.match(r, "A")

    def test_literal_uni_ignore_repeat_one(self):
        r = get_code(u"(?i)ab*c")
        assert self.match(r, 'ac')
        assert self.match(r, 'abc')
        assert self.match(r, 'abbbbbc')
        assert not self.match(r, 'a')
        assert not self.match(r, 'axc')
        assert not self.match(r, 'c')

    def test_in_uni_ignore_repeat_one(self):
        r = get_code(u"(?i)[^ab]*$")
        assert self.match(r, u'zzstzc')
        assert self.match(r, u'c')
        assert self.match(r, u'üüü\u0134c')
        assert not self.match(r, 'cccca')
        assert not self.match(r, 'bc')
        assert not self.match(r, 'b')

