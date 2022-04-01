import re, random, py
from rpython.rlib.rsre import rsre_char, rsre_constants
from rpython.rlib.rsre.rpy import get_code, VERSION
from rpython.rlib.rsre.test.support import match, fullmatch, Position as P


def get_code_and_re(regexp):
    return get_code(regexp), re.compile(regexp)

def test_get_code_repetition():
    c1 = get_code(r"a+")
    c2 = get_code(r"a+")
    assert c1.pattern == c2.pattern


class TestMatch:

    def test_or(self):
        r = get_code(r"a|bc|def")
        assert match(r, "a")
        assert match(r, "bc")
        assert match(r, "def")
        assert not match(r, "ghij")

    def test_any(self):
        r = get_code(r"ab.cd")
        assert match(r, "abXcdef")
        assert not match(r, "ab\ncdef")
        assert not match(r, "abXcDef")

    def test_any_repetition(self):
        r = get_code(r"ab.*cd")
        assert match(r, "abXXXXcdef")
        assert match(r, "abcdef")
        assert not match(r, "abX\nXcdef")
        assert not match(r, "abXXXXcDef")

    def test_any_all(self):
        r = get_code(r"(?s)ab.cd")
        assert match(r, "abXcdef")
        assert match(r, "ab\ncdef")
        assert not match(r, "ab\ncDef")

    def test_any_all_repetition(self):
        r = get_code(r"(?s)ab.*cd")
        assert match(r, "abXXXXcdef")
        assert match(r, "abcdef")
        assert match(r, "abX\nXcdef")
        assert not match(r, "abX\nXcDef")

    def test_assert(self):
        r = get_code(r"abc(?=def)(.)")
        res = match(r, "abcdefghi")
        assert res is not None and res.get_mark(1) == P(4)
        assert not match(r, "abcdeFghi")

    def test_assert_not(self):
        r = get_code(r"abc(?!def)(.)")
        res = match(r, "abcdeFghi")
        assert res is not None and res.get_mark(1) == P(4)
        assert not match(r, "abcdefghi")

    def test_lookbehind(self):
        r = get_code(r"([a-z]*)(?<=de)")
        assert match(r, "ade")
        res = match(r, "adefg")
        assert res is not None and res.get_mark(1) == P(3)
        assert not match(r, "abc")
        assert not match(r, "X")
        assert not match(r, "eX")

    def test_negative_lookbehind(self):
        def found(s):
            res = match(r, s)
            assert res is not None
            return res.get_mark(1)
        r = get_code(r"([a-z]*)(?<!dd)")
        assert found("ade") == P(3)
        assert found("adefg") == P(5)
        assert found("abcdd") == P(4)
        assert found("abddd") == P(3)
        assert found("adddd") == P(2)
        assert found("ddddd") == P(1)
        assert found("abXde") == P(2)

    def test_at(self):
        r = get_code(r"abc$")
        assert match(r, "abc")
        assert not match(r, "abcd")
        assert not match(r, "ab")

    def test_repeated_set(self):
        r = get_code(r"[a0x]+f")
        assert match(r, "a0af")
        assert not match(r, "a0yaf")

    def test_category(self):
        r = get_code(r"[\sx]")
        assert match(r, "x")
        assert match(r, " ")
        assert not match(r, "n")

    def test_groupref(self):
        r = get_code(r"(xx+)\1+$")     # match non-prime numbers of x
        assert not match(r, "xx")
        assert not match(r, "xxx")
        assert     match(r, "xxxx")
        assert not match(r, "xxxxx")
        assert     match(r, "xxxxxx")
        assert not match(r, "xxxxxxx")
        assert     match(r, "xxxxxxxx")
        assert     match(r, "xxxxxxxxx")

    def test_groupref_ignore(self):
        r = get_code(r"(?i)(xx+)\1+$")     # match non-prime numbers of x
        assert not match(r, "xX")
        assert not match(r, "xxX")
        assert     match(r, "Xxxx")
        assert not match(r, "xxxXx")
        assert     match(r, "xXxxxx")
        assert not match(r, "xxxXxxx")
        assert     match(r, "xxxxxxXx")
        assert     match(r, "xxxXxxxxx")

    def test_groupref_exists(self):
        r = get_code(r"((a)|(b))c(?(2)d)$")
        assert not match(r, "ac")
        assert     match(r, "acd")
        assert     match(r, "bc")
        assert not match(r, "bcd")
        #
        r = get_code(r"((a)|(b))c(?(2)d|e)$")
        assert not match(r, "ac")
        assert     match(r, "acd")
        assert not match(r, "ace")
        assert not match(r, "bc")
        assert not match(r, "bcd")
        assert     match(r, "bce")

    def test_in_ignore(self):
        r = get_code(r"(?i)[a-f]")
        assert match(r, "b")
        assert match(r, "C")
        assert not match(r, "g")
        r = get_code(r"(?i)[a-f]+$")
        assert match(r, "bCdEf")
        assert not match(r, "g")
        assert not match(r, "aaagaaa")

    def test_not_literal(self):
        r = get_code(r"[^a]")
        assert match(r, "A")
        assert not match(r, "a")
        r = get_code(r"[^a]+$")
        assert match(r, "Bx123")
        assert not match(r, "--a--")

    def test_not_literal_ignore(self):
        r = get_code(r"(?i)[^a]")
        assert match(r, "G")
        assert not match(r, "a")
        assert not match(r, "A")
        r = get_code(r"(?i)[^a]+$")
        assert match(r, "Gx123")
        assert not match(r, "--A--")

    def test_repeated_single_character_pattern(self):
        r = get_code(r"foo(?:(?<=foo)x)+$")
        assert match(r, "foox")

    def test_flatten_marks(self):
        r = get_code(r"a(b)c((d)(e))+$")
        res = match(r, "abcdedede")
        assert res.flatten_marks() == map(P, [0, 9, 1, 2, 7, 9, 7, 8, 8, 9])
        assert res.flatten_marks() == map(P, [0, 9, 1, 2, 7, 9, 7, 8, 8, 9])

    def test_bug1(self):
        # REPEAT_ONE inside REPEAT
        r = get_code(r"(?:.+)?B")
        assert match(r, "AB") is not None
        r = get_code(r"(?:AA+?)+B")
        assert match(r, "AAAB") is not None
        r = get_code(r"(?:AA+)+?B")
        assert match(r, "AAAB") is not None
        r = get_code(r"(?:AA+?)+?B")
        assert match(r, "AAAB") is not None
        # REPEAT inside REPEAT
        r = get_code(r"(?:(?:xy)+)?B")
        assert match(r, "xyB") is not None
        r = get_code(r"(?:xy(?:xy)+?)+B")
        assert match(r, "xyxyxyB") is not None
        r = get_code(r"(?:xy(?:xy)+)+?B")
        assert match(r, "xyxyxyB") is not None
        r = get_code(r"(?:xy(?:xy)+?)+?B")
        assert match(r, "xyxyxyB") is not None

    def test_assert_group(self):
        r = get_code(r"abc(?=(..)f)(.)")
        res = match(r, "abcdefghi")
        assert res is not None
        assert res.span(2) == (P(3), P(4))
        assert res.span(1) == (P(3), P(5))

    def test_assert_not_group(self):
        r = get_code(r"abc(?!(de)f)(.)")
        res = match(r, "abcdeFghi")
        assert res is not None
        assert res.span(2) == (P(3), P(4))
        # this I definitely classify as Horrendously Implementation Dependent.
        # CPython answers (3, 5).
        assert res.span(1) == (-1, -1)

    def test_match_start(self):
        r = get_code(r"^ab")
        assert     match(r, "abc")
        assert not match(r, "xxxabc", start=3)
        assert not match(r, "xx\nabc", start=3)
        #
        r = get_code(r"(?m)^ab")
        assert     match(r, "abc")
        assert not match(r, "xxxabc", start=3)
        assert     match(r, "xx\nabc", start=3)

    def test_match_end(self):
        r = get_code("ab")
        assert     match(r, "abc")
        assert     match(r, "abc", end=333)
        assert     match(r, "abc", end=3)
        assert     match(r, "abc", end=2)
        assert not match(r, "abc", end=1)
        assert not match(r, "abc", end=0)
        assert not match(r, "abc", end=-1)

    def test_match_bug1(self):
        r = get_code(r'(x??)?$')
        assert match(r, "x")

    def test_match_bug2(self):
        r = get_code(r'(x??)??$')
        assert match(r, "x")

    def test_match_bug3(self):
        if VERSION == "2.7.5":
            py.test.skip("pattern fails to compile with exactly 2.7.5 "
                         "(works on 2.7.3 and on 2.7.trunk though)")
        r = get_code(r'([ax]*?x*)?$')
        assert match(r, "aaxaa")

    def test_bigcharset(self):
        for i in range(100):
            chars = [unichr(random.randrange(0x100, 0xD000))
                         for n in range(random.randrange(1, 25))]
            pattern = u'[%s]' % (u''.join(chars),)
            r = get_code(pattern)
            for c in chars:
                assert match(r, c)
            for i in range(200):
                c = unichr(random.randrange(0x0, 0xD000))
                res = match(r, c)
                if c in chars:
                    assert res is not None
                else:
                    assert res is None

    def test_simple_match_1(self):
        r = get_code(r"ab*bbbbbbbc")
        print r
        m = match(r, "abbbbbbbbbcdef")
        assert m
        assert m.match_end == P(11)

    def test_empty_maxuntil(self):
        r = get_code("\\{\\{((?:.*?)+)\\}\\}")
        m = match(r, "{{a}}{{b}}")
        assert m.group(1) == "a"

    def test_fullmatch_1(self):
        r = get_code(r"ab*c")
        assert not fullmatch(r, "abbbcdef")
        assert fullmatch(r, "abbbc")

    def test_fullmatch_2(self):
        r = get_code(r"a(b*?)")
        match = fullmatch(r, "abbb")
        assert match.group(1) == "bbb"
        assert not fullmatch(r, "abbbc")

    def test_fullmatch_3(self):
        r = get_code(r"a((bp)*?)c")
        match = fullmatch(r, "abpbpbpc")
        assert match.group(1) == "bpbpbp"

    def test_fullmatch_4(self):
        r = get_code(r"a((bp)*)c")
        match = fullmatch(r, "abpbpbpc")
        assert match.group(1) == "bpbpbp"

    def test_fullmatch_assertion(self):
        r = get_code(r"(?=a).b")
        assert fullmatch(r, "ab")
        r = get_code(r"(?!a)..")
        assert not fullmatch(r, "ab")

    def test_range_ignore(self):
        from rpython.rlib.unicodedata import unicodedb
        rsre_char.set_unicode_db(unicodedb)
        #
        r = get_code(u"[\U00010428-\U0001044f]", re.I)
        assert r.pattern.count(rsre_constants.OPCODE_RANGE) == 1
        if rsre_constants.V37:
            repl = rsre_constants.OPCODE37_RANGE_UNI_IGNORE
        else:
            repl = rsre_constants.OPCODE27_RANGE_IGNORE
        r.pattern[r.pattern.index(rsre_constants.OPCODE_RANGE)] = repl
        assert match(r, u"\U00010428")
