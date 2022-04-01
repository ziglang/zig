import sys, os, py
from rpython.rlib.rsre.test.test_match import get_code
from rpython.rlib.rsre import rsre_re as re


class TestRe:

    def test_search_star_plus(self):
        assert re.search('x*', 'axx').span(0) == (0, 0)
        assert re.search('x*', 'axx').span() == (0, 0)
        assert re.search('x+', 'axx').span(0) == (1, 3)
        assert re.search('x+', 'axx').span() == (1, 3)
        assert re.search('x', 'aaa') == None
        assert re.match('a*', 'xxx').span(0) == (0, 0)
        assert re.match('a*', 'xxx').span() == (0, 0)
        assert re.match('x*', 'xxxa').span(0) == (0, 3)
        assert re.match('x*', 'xxxa').span() == (0, 3)
        assert re.match('a+', 'xxx') == None

    def bump_num(self, matchobj):
        int_value = int(matchobj.group(0))
        return str(int_value + 1)

    def test_basic_re_sub(self):
        assert re.sub("(?i)b+", "x", "bbbb BBBB") == 'x x'
        assert re.sub(r'\d+', self.bump_num, '08.2 -2 23x99y') == (
                         '9.3 -3 24x100y')
        assert re.sub(r'\d+', self.bump_num, '08.2 -2 23x99y', 3) == (
                         '9.3 -3 23x99y')

        assert re.sub('.', lambda m: r"\n", 'x') == '\\n'
        assert re.sub('.', r"\n", 'x') == '\n'

        s = r"\1\1"
        assert re.sub('(.)', s, 'x') == 'xx'
        assert re.sub('(.)', re.escape(s), 'x') == s
        assert re.sub('(.)', lambda m: s, 'x') == s

        assert re.sub('(?P<a>x)', '\g<a>\g<a>', 'xx') == 'xxxx'
        assert re.sub('(?P<a>x)', '\g<a>\g<1>', 'xx') == 'xxxx'
        assert re.sub('(?P<unk>x)', '\g<unk>\g<unk>', 'xx') == 'xxxx'
        assert re.sub('(?P<unk>x)', '\g<1>\g<1>', 'xx') == 'xxxx'

        assert re.sub('a',r'\t\n\v\r\f\a\b\B\Z\a\A\w\W\s\S\d\D','a') == (
                         '\t\n\v\r\f\a\b\\B\\Z\a\\A\\w\\W\\s\\S\\d\\D')
        assert re.sub('a', '\t\n\v\r\f\a', 'a') == '\t\n\v\r\f\a'
        assert re.sub('a', '\t\n\v\r\f\a', 'a') == (
                         (chr(9)+chr(10)+chr(11)+chr(13)+chr(12)+chr(7)))

        assert re.sub('^\s*', 'X', 'test') == 'Xtest'

    def test_bug_449964(self):
        # fails for group followed by other escape
        assert re.sub(r'(?P<unk>x)', '\g<1>\g<1>\\b', 'xx') == (
                         'xx\bxx\b')

    def test_bug_449000(self):
        # Test for sub() on escaped characters
        assert re.sub(r'\r\n', r'\n', 'abc\r\ndef\r\n') == (
                         'abc\ndef\n')
        assert re.sub('\r\n', r'\n', 'abc\r\ndef\r\n') == (
                         'abc\ndef\n')
        assert re.sub(r'\r\n', '\n', 'abc\r\ndef\r\n') == (
                         'abc\ndef\n')
        assert re.sub('\r\n', '\n', 'abc\r\ndef\r\n') == (
                         'abc\ndef\n')

    def test_bug_1140(self):
        # re.sub(x, y, u'') should return u'', not '', and
        # re.sub(x, y, '') should return '', not u''.
        # Also:
        # re.sub(x, y, unicode(x)) should return unicode(y), and
        # re.sub(x, y, str(x)) should return
        #     str(y) if isinstance(y, str) else unicode(y).
        for x in 'x', u'x':
            for y in 'y', u'y':
                z = re.sub(x, y, u'')
                assert z == u''
                assert type(z) == unicode
                #
                z = re.sub(x, y, '')
                assert z == ''
                assert type(z) == str
                #
                z = re.sub(x, y, unicode(x))
                assert z == y
                assert type(z) == unicode
                #
                z = re.sub(x, y, str(x))
                assert z == y
                assert type(z) == type(y)

    def test_sub_template_numeric_escape(self):
        # bug 776311 and friends
        assert re.sub('x', r'\0', 'x') == '\0'
        assert re.sub('x', r'\000', 'x') == '\000'
        assert re.sub('x', r'\001', 'x') == '\001'
        assert re.sub('x', r'\008', 'x') == '\0' + '8'
        assert re.sub('x', r'\009', 'x') == '\0' + '9'
        assert re.sub('x', r'\111', 'x') == '\111'
        assert re.sub('x', r'\117', 'x') == '\117'

        assert re.sub('x', r'\1111', 'x') == '\1111'
        assert re.sub('x', r'\1111', 'x') == '\111' + '1'

        assert re.sub('x', r'\00', 'x') == '\x00'
        assert re.sub('x', r'\07', 'x') == '\x07'
        assert re.sub('x', r'\08', 'x') == '\0' + '8'
        assert re.sub('x', r'\09', 'x') == '\0' + '9'
        assert re.sub('x', r'\0a', 'x') == '\0' + 'a'

        assert re.sub('x', r'\400', 'x') == '\0'
        assert re.sub('x', r'\777', 'x') == '\377'

        py.test.raises(re.error, re.sub, 'x', r'\1', 'x')
        py.test.raises(re.error, re.sub, 'x', r'\8', 'x')
        py.test.raises(re.error, re.sub, 'x', r'\9', 'x')
        py.test.raises(re.error, re.sub, 'x', r'\11', 'x')
        py.test.raises(re.error, re.sub, 'x', r'\18', 'x')
        py.test.raises(re.error, re.sub, 'x', r'\1a', 'x')
        py.test.raises(re.error, re.sub, 'x', r'\90', 'x')
        py.test.raises(re.error, re.sub, 'x', r'\99', 'x')
        py.test.raises(re.error, re.sub, 'x', r'\118', 'x') # r'\11' + '8'
        py.test.raises(re.error, re.sub, 'x', r'\11a', 'x')
        py.test.raises(re.error, re.sub, 'x', r'\181', 'x') # r'\18' + '1'
        py.test.raises(re.error, re.sub, 'x', r'\800', 'x') # r'\80' + '0'

        # in python2.3 (etc), these loop endlessly in sre_parser.py
        assert re.sub('(((((((((((x)))))))))))', r'\11', 'x') == 'x'
        assert re.sub('((((((((((y))))))))))(.)', r'\118', 'xyz') == (
                         'xz8')
        assert re.sub('((((((((((y))))))))))(.)', r'\11a', 'xyz') == (
                         'xza')

    def test_qualified_re_sub(self):
        assert re.sub('a', 'b', 'aaaaa') == 'bbbbb'
        assert re.sub('a', 'b', 'aaaaa', 1) == 'baaaa'

    def test_bug_114660(self):
        assert re.sub(r'(\S)\s+(\S)', r'\1 \2', 'hello  there') == (
                         'hello there')

    def test_bug_462270(self):
        # Test for empty sub() behaviour, see SF bug #462270
        assert re.sub('x*', '-', 'abxd') == '-a-b-d-'
        assert re.sub('x+', '-', 'abxd') == 'ab-d'

    def test_symbolic_refs(self):
        py.test.raises(re.error, re.sub, '(?P<a>x)', '\g<a', 'xx')
        py.test.raises(re.error, re.sub, '(?P<a>x)', '\g<', 'xx')
        py.test.raises(re.error, re.sub, '(?P<a>x)', '\g', 'xx')
        py.test.raises(re.error, re.sub, '(?P<a>x)', '\g<a a>', 'xx')
        py.test.raises(re.error, re.sub, '(?P<a>x)', '\g<1a1>', 'xx')
        py.test.raises(IndexError, re.sub, '(?P<a>x)', '\g<ab>', 'xx')
        py.test.raises(re.error, re.sub, '(?P<a>x)|(?P<b>y)', '\g<b>', 'xx')
        py.test.raises(re.error, re.sub, '(?P<a>x)|(?P<b>y)', '\\2', 'xx')
        py.test.raises(re.error, re.sub, '(?P<a>x)', '\g<-1>', 'xx')

    def test_re_subn(self):
        assert re.subn("(?i)b+", "x", "bbbb BBBB") == ('x x', 2)
        assert re.subn("b+", "x", "bbbb BBBB") == ('x BBBB', 1)
        assert re.subn("b+", "x", "xyz") == ('xyz', 0)
        assert re.subn("b*", "x", "xyz") == ('xxxyxzx', 4)
        assert re.subn("b*", "x", "xyz", 2) == ('xxxyz', 2)

    def test_re_split(self):
        assert re.split(":", ":a:b::c") == ['', 'a', 'b', '', 'c']
        assert re.split(":*", ":a:b::c") == ['', 'a', 'b', 'c']
        assert re.split("(:*)", ":a:b::c") == (
                         ['', ':', 'a', ':', 'b', '::', 'c'])
        assert re.split("(?::*)", ":a:b::c") == ['', 'a', 'b', 'c']
        assert re.split("(:)*", ":a:b::c") == (
                         ['', ':', 'a', ':', 'b', ':', 'c'])
        assert re.split("([b:]+)", ":a:b::c") == (
                         ['', ':', 'a', ':b::', 'c'])
        assert re.split("(b)|(:+)", ":a:b::c") == (
                         ['', None, ':', 'a', None, ':', '', 'b', None, '',
                          None, '::', 'c'])
        assert re.split("(?:b)|(?::+)", ":a:b::c") == (
                         ['', 'a', '', '', 'c'])

    def test_qualified_re_split(self):
        assert re.split(":", ":a:b::c", 2) == ['', 'a', 'b::c']
        assert re.split(':', 'a:b:c:d', 2) == ['a', 'b', 'c:d']
        assert re.split("(:)", ":a:b::c", 2) == (
                         ['', ':', 'a', ':', 'b::c'])
        assert re.split("(:*)", ":a:b::c", 2) == (
                         ['', ':', 'a', ':', 'b::c'])

    def test_re_findall(self):
        assert re.findall(":+", "abc") == []
        assert re.findall(":+", "a:b::c:::d") == [":", "::", ":::"]
        assert re.findall("(:+)", "a:b::c:::d") == [":", "::", ":::"]

    def test_re_findall_2(self):
        py.test.skip("findall() returning groups is not RPython")
        assert re.findall("(:)(:*)", "a:b::c:::d") == [(":", ""),
                                                               (":", ":"),
                                                               (":", "::")]

    def test_bug_117612(self):
        py.test.skip("findall() returning groups is not RPython")
        assert re.findall(r"(a|(b))", "aba") == (
                         [("a", ""),("b", "b"),("a", "")])

    def test_re_match(self):
        assert re.match('a', 'a').groups() == ()
        assert re.match('(a)', 'a').groups() == ('a',)
        assert re.match(r'(a)', 'a').group(0) == 'a'
        assert re.match(r'(a)', 'a').group(1) == 'a'
        #assert re.match(r'(a)', 'a').group(1, 1) == ('a', 'a')

        pat = re.compile('((a)|(b))(c)?')
        assert pat.match('a').groups() == ('a', 'a', None, None)
        assert pat.match('b').groups() == ('b', None, 'b', None)
        assert pat.match('ac').groups() == ('a', 'a', None, 'c')
        assert pat.match('bc').groups() == ('b', None, 'b', 'c')
        assert pat.match('bc').groups("") == ('b', "", 'b', 'c')

        # A single group
        m = re.match('(a)', 'a')
        assert m.group(0) == 'a'
        assert m.group(0) == 'a'
        assert m.group(1) == 'a'
        #assert m.group(1, 1) == ('a', 'a')

        pat = re.compile('(?:(?P<a1>a)|(?P<b2>b))(?P<c3>c)?')
        #assert pat.match('a').group(1, 2, 3) == ('a', None, None)
        #assert pat.match('b').group('a1', 'b2', 'c3') == (
        #                 (None, 'b', None))
        #assert pat.match('ac').group(1, 'b2', 3) == ('a', None, 'c')

    def test_bug_923(self):
        # Issue923: grouping inside optional lookahead problem
        assert re.match(r'a(?=(b))?', "ab").groups() == ("b",)
        assert re.match(r'(a(?=(b))?)', "ab").groups() == ('a', 'b')
        assert re.match(r'(a)(?=(b))?', "ab").groups() == ('a', 'b')
        assert re.match(r'(?P<g1>a)(?=(?P<g2>b))?', "ab").groupdict() == {'g1': 'a', 'g2': 'b'}

    def test_re_groupref_exists(self):
        assert re.match('^(\()?([^()]+)(?(1)\))$', '(a)').groups() == (
                         ('(', 'a'))
        assert re.match('^(\()?([^()]+)(?(1)\))$', 'a').groups() == (
                         (None, 'a'))
        assert re.match('^(\()?([^()]+)(?(1)\))$', 'a)') == None
        assert re.match('^(\()?([^()]+)(?(1)\))$', '(a') == None
        assert re.match('^(?:(a)|c)((?(1)b|d))$', 'ab').groups() == (
                         ('a', 'b'))
        assert re.match('^(?:(a)|c)((?(1)b|d))$', 'cd').groups() == (
                         (None, 'd'))
        assert re.match('^(?:(a)|c)((?(1)|d))$', 'cd').groups() == (
                         (None, 'd'))
        assert re.match('^(?:(a)|c)((?(1)|d))$', 'a').groups() == (
                         ('a', ''))

        # Tests for bug #1177831: exercise groups other than the first group
        p = re.compile('(?P<g1>a)(?P<g2>b)?((?(g2)c|d))')
        assert p.match('abc').groups() == (
                         ('a', 'b', 'c'))
        assert p.match('ad').groups() == (
                         ('a', None, 'd'))
        assert p.match('abd') == None
        assert p.match('ac') == None


    def test_re_groupref(self):
        assert re.match(r'^(\|)?([^()]+)\1$', '|a|').groups() == (
                         ('|', 'a'))
        assert re.match(r'^(\|)?([^()]+)\1?$', 'a').groups() == (
                         (None, 'a'))
        assert re.match(r'^(\|)?([^()]+)\1$', 'a|') == None
        assert re.match(r'^(\|)?([^()]+)\1$', '|a') == None
        assert re.match(r'^(?:(a)|c)(\1)$', 'aa').groups() == (
                         ('a', 'a'))
        assert re.match(r'^(?:(a)|c)(\1)?$', 'c').groups() == (
                         (None, None))

    def test_groupdict(self):
        assert re.match('(?P<first>first) (?P<second>second)',
                                  'first second').groupdict() == (
                         {'first':'first', 'second':'second'})

    def test_expand(self):
        assert (re.match("(?P<first>first) (?P<second>second)",
                                  "first second")
                                  .expand(r"\2 \1 \g<second> \g<first>")) == (
                         "second first second first")

    def test_repeat_minmax(self):
        assert re.match("^(\w){1}$", "abc") == None
        assert re.match("^(\w){1}?$", "abc") == None
        assert re.match("^(\w){1,2}$", "abc") == None
        assert re.match("^(\w){1,2}?$", "abc") == None

        assert re.match("^(\w){3}$", "abc").group(1) == "c"
        assert re.match("^(\w){1,3}$", "abc").group(1) == "c"
        assert re.match("^(\w){1,4}$", "abc").group(1) == "c"
        assert re.match("^(\w){3,4}?$", "abc").group(1) == "c"
        assert re.match("^(\w){3}?$", "abc").group(1) == "c"
        assert re.match("^(\w){1,3}?$", "abc").group(1) == "c"
        assert re.match("^(\w){1,4}?$", "abc").group(1) == "c"
        assert re.match("^(\w){3,4}?$", "abc").group(1) == "c"

        assert re.match("^x{1}$", "xxx") == None
        assert re.match("^x{1}?$", "xxx") == None
        assert re.match("^x{1,2}$", "xxx") == None
        assert re.match("^x{1,2}?$", "xxx") == None

        assert re.match("^x{3}$", "xxx") != None
        assert re.match("^x{1,3}$", "xxx") != None
        assert re.match("^x{1,4}$", "xxx") != None
        assert re.match("^x{3,4}?$", "xxx") != None
        assert re.match("^x{3}?$", "xxx") != None
        assert re.match("^x{1,3}?$", "xxx") != None
        assert re.match("^x{1,4}?$", "xxx") != None
        assert re.match("^x{3,4}?$", "xxx") != None

        assert re.match("^x{}$", "xxx") == None
        assert re.match("^x{}$", "x{}") != None

    def test_getattr(self):
        assert re.match("(a)", "a").pos == 0
        assert re.match("(a)", "a").endpos == 1
        assert re.match("(a)", "a").string == "a"
        assert re.match("(a)", "a").regs == ((0, 1), (0, 1))
        assert re.match("(a)", "a").re != None

    def test_special_escapes(self):
        assert re.search(r"\b(b.)\b",
                                   "abcd abc bcd bx").group(1) == "bx"
        assert re.search(r"\B(b.)\B",
                                   "abc bcd bc abxd").group(1) == "bx"
        assert re.search(r"\b(b.)\b",
                                   "abcd abc bcd bx", re.LOCALE).group(1) == "bx"
        assert re.search(r"\B(b.)\B",
                                   "abc bcd bc abxd", re.LOCALE).group(1) == "bx"
        assert re.search(r"\b(b.)\b",
                                   "abcd abc bcd bx", re.UNICODE).group(1) == "bx"
        assert re.search(r"\B(b.)\B",
                                   "abc bcd bc abxd", re.UNICODE).group(1) == "bx"
        assert re.search(r"^abc$", "\nabc\n", re.M).group(0) == "abc"
        assert re.search(r"^\Aabc\Z$", "abc", re.M).group(0) == "abc"
        assert re.search(r"^\Aabc\Z$", "\nabc\n", re.M) == None
        assert re.search(r"\b(b.)\b",
                                   u"abcd abc bcd bx").group(1) == "bx"
        assert re.search(r"\B(b.)\B",
                                   u"abc bcd bc abxd").group(1) == "bx"
        assert re.search(r"^abc$", u"\nabc\n", re.M).group(0) == "abc"
        assert re.search(r"^\Aabc\Z$", u"abc", re.M).group(0) == "abc"
        assert re.search(r"^\Aabc\Z$", u"\nabc\n", re.M) == None
        assert re.search(r"\d\D\w\W\s\S",
                                   "1aa! a").group(0) == "1aa! a"
        assert re.search(r"\d\D\w\W\s\S",
                                   "1aa! a", re.LOCALE).group(0) == "1aa! a"
        assert re.search(r"\d\D\w\W\s\S",
                                   "1aa! a", re.UNICODE).group(0) == "1aa! a"

    def test_ignore_case(self):
        assert re.match("abc", "ABC", re.I).group(0) == "ABC"
        assert re.match("abc", u"ABC", re.I).group(0) == "ABC"

    def test_bigcharset(self):
        assert re.match(u"([\u2222\u2223])",
                                  u"\u2222").group(1) == u"\u2222"
        assert re.match(u"([\u2222\u2223])",
                                  u"\u2222", re.UNICODE).group(1) == u"\u2222"

    def test_anyall(self):
        assert re.match("a.b", "a\nb", re.DOTALL).group(0) == (
                         "a\nb")
        assert re.match("a.*b", "a\n\nb", re.DOTALL).group(0) == (
                         "a\n\nb")

    def test_non_consuming(self):
        assert re.match("(a(?=\s[^a]))", "a b").group(1) == "a"
        assert re.match("(a(?=\s[^a]*))", "a b").group(1) == "a"
        assert re.match("(a(?=\s[abc]))", "a b").group(1) == "a"
        assert re.match("(a(?=\s[abc]*))", "a bc").group(1) == "a"
        assert re.match(r"(a)(?=\s\1)", "a a").group(1) == "a"
        assert re.match(r"(a)(?=\s\1*)", "a aa").group(1) == "a"
        assert re.match(r"(a)(?=\s(abc|a))", "a a").group(1) == "a"

        assert re.match(r"(a(?!\s[^a]))", "a a").group(1) == "a"
        assert re.match(r"(a(?!\s[abc]))", "a d").group(1) == "a"
        assert re.match(r"(a)(?!\s\1)", "a b").group(1) == "a"
        assert re.match(r"(a)(?!\s(abc|a))", "a b").group(1) == "a"

    def test_ignore_case(self):
        assert re.match(r"(a\s[^a])", "a b", re.I).group(1) == "a b"
        assert re.match(r"(a\s[^a]*)", "a bb", re.I).group(1) == "a bb"
        assert re.match(r"(a\s[abc])", "a b", re.I).group(1) == "a b"
        assert re.match(r"(a\s[abc]*)", "a bb", re.I).group(1) == "a bb"
        assert re.match(r"((a)\s\2)", "a a", re.I).group(1) == "a a"
        assert re.match(r"((a)\s\2*)", "a aa", re.I).group(1) == "a aa"
        assert re.match(r"((a)\s(abc|a))", "a a", re.I).group(1) == "a a"
        assert re.match(r"((a)\s(abc|a)*)", "a aa", re.I).group(1) == "a aa"

    def test_category(self):
        assert re.match(r"(\s)", " ").group(1) == " "

    def test_getlower(self):
        import _sre
        assert _sre.getlower(ord('A'), 0) == ord('a')
        assert _sre.getlower(ord('A'), re.LOCALE) == ord('a')
        assert _sre.getlower(ord('A'), re.UNICODE) == ord('a')

        assert re.match("abc", "ABC", re.I).group(0) == "ABC"
        assert re.match("abc", u"ABC", re.I).group(0) == "ABC"

    def test_not_literal(self):
        assert re.search("\s([^a])", " b").group(1) == "b"
        assert re.search("\s([^a]*)", " bb").group(1) == "bb"

    def test_search_coverage(self):
        assert re.search("\s(b)", " b").group(1) == "b"
        assert re.search("a\s", "a ").group(0) == "a "

    def test_re_escape(self):
        p=""
        for i in range(0, 256):
            p = p + chr(i)
            assert re.match(re.escape(chr(i)), chr(i)) is not None
            assert re.match(re.escape(chr(i)), chr(i)).span() == (0,1)

        pat=re.compile(re.escape(p))
        assert pat.match(p) is not None
        assert pat.match(p).span() == (0,256)

    def test_constants(self):
        assert re.I == re.IGNORECASE
        assert re.L == re.LOCALE
        assert re.M == re.MULTILINE
        assert re.S == re.DOTALL
        assert re.X == re.VERBOSE

    def test_flags(self):
        for flag in [re.I, re.M, re.X, re.S, re.L]:
            assert re.compile('^pattern$', flag) != None

    def test_sre_character_literals(self):
        for i in [0, 8, 16, 32, 64, 127, 128, 255]:
            assert re.match(r"\%03o" % i, chr(i)) != None
            assert re.match(r"\%03o0" % i, chr(i)+"0") != None
            assert re.match(r"\%03o8" % i, chr(i)+"8") != None
            assert re.match(r"\x%02x" % i, chr(i)) != None
            assert re.match(r"\x%02x0" % i, chr(i)+"0") != None
            assert re.match(r"\x%02xz" % i, chr(i)+"z") != None
        py.test.raises(re.error, re.match, "\911", "")

    def test_sre_character_class_literals(self):
        for i in [0, 8, 16, 32, 64, 127, 128, 255]:
            assert re.match(r"[\%03o]" % i, chr(i)) != None
            assert re.match(r"[\%03o0]" % i, chr(i)) != None
            assert re.match(r"[\%03o8]" % i, chr(i)) != None
            assert re.match(r"[\x%02x]" % i, chr(i)) != None
            assert re.match(r"[\x%02x0]" % i, chr(i)) != None
            assert re.match(r"[\x%02xz]" % i, chr(i)) != None
        py.test.raises(re.error, re.match, "[\911]", "")

    def test_bug_113254(self):
        assert re.match(r'(a)|(b)', 'b').start(1) == -1
        assert re.match(r'(a)|(b)', 'b').end(1) == -1
        assert re.match(r'(a)|(b)', 'b').span(1) == (-1, -1)

    def test_bug_527371(self):
        # bug described in patches 527371/672491
        assert re.match(r'(a)?a','a').lastindex == None
        assert re.match(r'(a)(b)?b','ab').lastindex == 1
        assert re.match(r'(?P<a>a)(?P<b>b)?b','ab').lastgroup == 'a'
        assert re.match("(?P<a>a(b))", "ab").lastgroup == 'a'
        assert re.match("((a))", "a").lastindex == 1

    def test_bug_545855(self):
        # bug 545855 -- This pattern failed to cause a compile error as it
        # should, instead provoking a TypeError.
        py.test.raises(re.error, re.compile, 'foo[a-')

    def test_bug_418626(self):
        # bugs 418626 at al. -- Testing Greg Chapman's addition of op code
        # SRE_OP_MIN_REPEAT_ONE for eliminating recursion on simple uses of
        # pattern '*?' on a long string.
        assert re.match('.*?c', 10000*'ab'+'cd').end(0) == 20001
        assert re.match('.*?cd', 5000*'ab'+'c'+5000*'ab'+'cde').end(0) == (
                         20003)
        assert re.match('.*?cd', 20000*'abc'+'de').end(0) == 60001
        # non-simple '*?' still used to hit the recursion limit, before the
        # non-recursive scheme was implemented.
        assert re.search('(a|b)*?c', 10000*'ab'+'cd').end(0) == 20001

    def test_bug_612074(self):
        pat=u"["+re.escape(u"\u2039")+u"]"
        assert re.compile(pat) and 1 == 1

    def test_stack_overflow(self):
        # nasty cases that used to overflow the straightforward recursive
        # implementation of repeated groups.
        assert re.match('(x)*', 50000*'x').group(1) == 'x'
        assert re.match('(x)*y', 50000*'x'+'y').group(1) == 'x'
        assert re.match('(x)*?y', 50000*'x'+'y').group(1) == 'x'

    def test_scanner(self):
        def s_ident(scanner, token): return token
        def s_operator(scanner, token): return "op%s" % token
        def s_float(scanner, token): return float(token)
        def s_int(scanner, token): return int(token)

        scanner = re.Scanner([
            (r"[a-zA-Z_]\w*", s_ident),
            (r"\d+\.\d*", s_float),
            (r"\d+", s_int),
            (r"=|\+|-|\*|/", s_operator),
            (r"\s+", None),
            ])

        assert scanner.scanner.scanner("").pattern != None

        assert scanner.scan("sum = 3*foo + 312.50 + bar") == (
                         (['sum', 'op=', 3, 'op*', 'foo', 'op+', 312.5,
                           'op+', 'bar'], ''))

    def test_bug_448951(self):
        # bug 448951 (similar to 429357, but with single char match)
        # (Also test greedy matches.)
        for op in '','?','*':
            assert re.match(r'((.%s):)?z'%op, 'z').groups() == (
                             (None, None))
            assert re.match(r'((.%s):)?z'%op, 'a:z').groups() == (
                             ('a:', 'a'))

    def test_bug_725106(self):
        # capturing groups in alternatives in repeats
        assert re.match('^((a)|b)*', 'abc').groups() == (
                         ('b', 'a'))
        assert re.match('^(([ab])|c)*', 'abc').groups() == (
                         ('c', 'b'))
        assert re.match('^((d)|[ab])*', 'abc').groups() == (
                         ('b', None))
        assert re.match('^((a)c|[ab])*', 'abc').groups() == (
                         ('b', None))
        assert re.match('^((a)|b)*?c', 'abc').groups() == (
                         ('b', 'a'))
        assert re.match('^(([ab])|c)*?d', 'abcd').groups() == (
                         ('c', 'b'))
        assert re.match('^((d)|[ab])*?c', 'abc').groups() == (
                         ('b', None))
        assert re.match('^((a)c|[ab])*?c', 'abc').groups() == (
                         ('b', None))

    def test_bug_725149(self):
        # mark_stack_base restoring before restoring marks
        assert re.match('(a)(?:(?=(b)*)c)*', 'abb').groups() == (
                         ('a', None))
        assert re.match('(a)((?!(b)*))*', 'abb').groups() == (
                         ('a', None, None))

    def test_bug_764548(self):
        # bug 764548, re.compile() barfs on str/unicode subclasses
        try:
            unicode
        except NameError:
            return  # no problem if we have no unicode
        class my_unicode(unicode): pass
        pat = re.compile(my_unicode("abc"))
        assert pat.match("xyz") == None

    def test_finditer(self):
        iter = re.finditer(r":+", "a:b::c:::d")
        assert [item.group(0) for item in iter] == (
                         [":", "::", ":::"])

    def test_bug_926075(self):
        try:
            unicode
        except NameError:
            return # no problem if we have no unicode
        assert (re.compile('bug_926075') is not
                     re.compile(eval("u'bug_926075'")))

    def test_bug_931848(self):
        try:
            unicode
        except NameError:
            pass
        pattern = eval('u"[\u002E\u3002\uFF0E\uFF61]"')
        assert re.compile(pattern).split("a.b.c") == (
                         ['a','b','c'])

    def test_bug_581080(self):
        iter = re.finditer(r"\s", "a b")
        assert iter.next().span() == (1,2)
        py.test.raises(StopIteration, iter.next)

        if 0:    # XXX
            scanner = re.compile(r"\s").scanner("a b")
            assert scanner.search().span() == (1, 2)
            assert scanner.search() == None

    def test_bug_817234(self):
        iter = re.finditer(r".*", "asdf")
        assert iter.next().span() == (0, 4)
        assert iter.next().span() == (4, 4)
        py.test.raises(StopIteration, iter.next)

    def test_empty_array(self):
        # SF buf 1647541
        import array
        for typecode in 'cbBuhHiIlLfd':
            a = array.array(typecode)
            assert re.compile("bla").match(a) == None
            assert re.compile("").match(a).groups() == ()

    def test_inline_flags(self):
        # Bug #1700
        upper_char = unichr(0x1ea0) # Latin Capital Letter A with Dot Bellow
        lower_char = unichr(0x1ea1) # Latin Small Letter A with Dot Bellow

        p = re.compile(upper_char, re.I | re.U)
        q = p.match(lower_char)
        assert q != None

        p = re.compile(lower_char, re.I | re.U)
        q = p.match(upper_char)
        assert q != None

        p = re.compile('(?i)' + upper_char, re.U)
        q = p.match(lower_char)
        assert q != None

        p = re.compile('(?i)' + lower_char, re.U)
        q = p.match(upper_char)
        assert q != None

        p = re.compile('(?iu)' + upper_char)
        q = p.match(lower_char)
        assert q != None

        p = re.compile('(?iu)' + lower_char)
        q = p.match(upper_char)
        assert q != None
