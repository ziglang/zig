from rpython.rlib.rsre import rsre_char, rsre_core
from rpython.rlib.rsre.rsre_constants import SRE_FLAG_LOCALE, SRE_FLAG_UNICODE

def setup_module(mod):
    from rpython.rlib.unicodedata import unicodedb
    rsre_char.set_unicode_db(unicodedb)


def check_charset(pattern, idx, char):
    p = rsre_core.CompiledPattern(pattern, 0)
    return rsre_char.check_charset(Ctx(p), p, idx, char)


UPPER_PI = 0x3a0
LOWER_PI = 0x3c0
INDIAN_DIGIT = 0x966
ROMAN_NUMERAL = 0x2165
FULLWIDTH_DIGIT = 0xff10
CIRCLED_NUMBER = 0x32b4
DINGBAT_CIRCLED = 0x2781
EM_SPACE = 0x2001
LINE_SEP = 0x2028

# XXX very incomplete test

def test_getlower():
    assert rsre_char.getlower(ord('A'), 0) == ord('a')
    assert rsre_char.getlower(ord('2'), 0) == ord('2')
    assert rsre_char.getlower(10, 0) == 10
    assert rsre_char.getlower(UPPER_PI, 0) == UPPER_PI
    #
    assert rsre_char.getlower(ord('A'), SRE_FLAG_UNICODE) == ord('a')
    assert rsre_char.getlower(ord('2'), SRE_FLAG_UNICODE) == ord('2')
    assert rsre_char.getlower(10, SRE_FLAG_UNICODE) == 10
    assert rsre_char.getlower(UPPER_PI, SRE_FLAG_UNICODE) == LOWER_PI
    #
    # xxx the following cases are like CPython's.  They are obscure.
    # (iko) that's a nice way to say "broken"
    assert rsre_char.getlower(UPPER_PI, SRE_FLAG_LOCALE) == UPPER_PI
    assert rsre_char.getlower(UPPER_PI, SRE_FLAG_LOCALE | SRE_FLAG_UNICODE) \
                                                         == UPPER_PI

def test_getupper():
    assert rsre_char.getupper(ord('A'), 0) == ord('A')
    assert rsre_char.getupper(ord('b'), 0) == ord('B')
    assert rsre_char.getupper(10, 0) == 10
    assert rsre_char.getupper(LOWER_PI, 0) == LOWER_PI
    #
    assert rsre_char.getupper(ord('a'), SRE_FLAG_UNICODE) == ord('A')
    assert rsre_char.getupper(ord('2'), SRE_FLAG_UNICODE) == ord('2')
    assert rsre_char.getupper(10, SRE_FLAG_UNICODE) == 10
    assert rsre_char.getupper(LOWER_PI, SRE_FLAG_UNICODE) == UPPER_PI
    #
    assert rsre_char.getupper(LOWER_PI, SRE_FLAG_LOCALE) == LOWER_PI
    assert rsre_char.getupper(LOWER_PI, SRE_FLAG_LOCALE | SRE_FLAG_UNICODE) \
                                                         == LOWER_PI


def test_getupper_getlower_unicode_ascii_shortcut():
    from rpython.rlib.unicodedata import unicodedb
    try:
        rsre_char.set_unicode_db(None)
        for i in range(128):
            # works despite not having a unicode db
            rsre_char.getlower(i, SRE_FLAG_UNICODE)
            rsre_char.getupper(i, SRE_FLAG_UNICODE)
    finally:
        rsre_char.set_unicode_db(unicodedb)


def test_is_word():
    assert rsre_char.is_word(ord('A'))
    assert rsre_char.is_word(ord('_'))
    assert not rsre_char.is_word(UPPER_PI)
    assert not rsre_char.is_word(LOWER_PI)
    assert not rsre_char.is_word(ord(','))
    #
    assert rsre_char.is_uni_word(ord('A'))
    assert rsre_char.is_uni_word(ord('_'))
    assert rsre_char.is_uni_word(UPPER_PI)
    assert rsre_char.is_uni_word(LOWER_PI)
    assert not rsre_char.is_uni_word(ord(','))

def test_category():
    from rpython.rlib.rsre.rpy.sre_constants import CHCODES
    cat = rsre_char.category_dispatch
    #
    assert     cat(CHCODES["category_digit"], ord('1'))
    assert not cat(CHCODES["category_digit"], ord('a'))
    assert not cat(CHCODES["category_digit"], INDIAN_DIGIT)
    #
    assert not cat(CHCODES["category_not_digit"], ord('1'))
    assert     cat(CHCODES["category_not_digit"], ord('a'))
    assert     cat(CHCODES["category_not_digit"], INDIAN_DIGIT)
    #
    assert not cat(CHCODES["category_space"], ord('1'))
    assert not cat(CHCODES["category_space"], ord('a'))
    assert     cat(CHCODES["category_space"], ord(' '))
    assert     cat(CHCODES["category_space"], ord('\n'))
    assert     cat(CHCODES["category_space"], ord('\t'))
    assert     cat(CHCODES["category_space"], ord('\r'))
    assert     cat(CHCODES["category_space"], ord('\v'))
    assert     cat(CHCODES["category_space"], ord('\f'))
    assert not cat(CHCODES["category_space"], EM_SPACE)
    #
    assert     cat(CHCODES["category_not_space"], ord('1'))
    assert     cat(CHCODES["category_not_space"], ord('a'))
    assert not cat(CHCODES["category_not_space"], ord(' '))
    assert not cat(CHCODES["category_not_space"], ord('\n'))
    assert not cat(CHCODES["category_not_space"], ord('\t'))
    assert not cat(CHCODES["category_not_space"], ord('\r'))
    assert not cat(CHCODES["category_not_space"], ord('\v'))
    assert not cat(CHCODES["category_not_space"], ord('\f'))
    assert     cat(CHCODES["category_not_space"], EM_SPACE)
    #
    assert     cat(CHCODES["category_word"], ord('l'))
    assert     cat(CHCODES["category_word"], ord('4'))
    assert     cat(CHCODES["category_word"], ord('_'))
    assert not cat(CHCODES["category_word"], ord(' '))
    assert not cat(CHCODES["category_word"], ord('\n'))
    assert not cat(CHCODES["category_word"], LOWER_PI)
    #
    assert not cat(CHCODES["category_not_word"], ord('l'))
    assert not cat(CHCODES["category_not_word"], ord('4'))
    assert not cat(CHCODES["category_not_word"], ord('_'))
    assert     cat(CHCODES["category_not_word"], ord(' '))
    assert     cat(CHCODES["category_not_word"], ord('\n'))
    assert     cat(CHCODES["category_not_word"], LOWER_PI)
    #
    assert     cat(CHCODES["category_linebreak"], ord('\n'))
    assert not cat(CHCODES["category_linebreak"], ord(' '))
    assert not cat(CHCODES["category_linebreak"], ord('s'))
    assert not cat(CHCODES["category_linebreak"], ord('\r'))
    assert not cat(CHCODES["category_linebreak"], LINE_SEP)
    #
    assert     cat(CHCODES["category_uni_linebreak"], ord('\n'))
    assert not cat(CHCODES["category_uni_linebreak"], ord(' '))
    assert not cat(CHCODES["category_uni_linebreak"], ord('s'))
    assert     cat(CHCODES["category_uni_linebreak"], LINE_SEP)
    #
    assert not cat(CHCODES["category_not_linebreak"], ord('\n'))
    assert     cat(CHCODES["category_not_linebreak"], ord(' '))
    assert     cat(CHCODES["category_not_linebreak"], ord('s'))
    assert     cat(CHCODES["category_not_linebreak"], ord('\r'))
    assert     cat(CHCODES["category_not_linebreak"], LINE_SEP)
    #
    assert not cat(CHCODES["category_uni_not_linebreak"], ord('\n'))
    assert     cat(CHCODES["category_uni_not_linebreak"], ord(' '))
    assert     cat(CHCODES["category_uni_not_linebreak"], ord('s'))
    assert not cat(CHCODES["category_uni_not_linebreak"], LINE_SEP)
    #
    assert     cat(CHCODES["category_uni_digit"], INDIAN_DIGIT)
    assert     cat(CHCODES["category_uni_digit"], FULLWIDTH_DIGIT)
    assert not cat(CHCODES["category_uni_digit"], ROMAN_NUMERAL)
    assert not cat(CHCODES["category_uni_digit"], CIRCLED_NUMBER)
    assert not cat(CHCODES["category_uni_digit"], DINGBAT_CIRCLED)
    #
    assert not cat(CHCODES["category_uni_not_digit"], INDIAN_DIGIT)
    assert not cat(CHCODES["category_uni_not_digit"], FULLWIDTH_DIGIT)
    assert     cat(CHCODES["category_uni_not_digit"], ROMAN_NUMERAL)
    assert     cat(CHCODES["category_uni_not_digit"], CIRCLED_NUMBER)
    assert     cat(CHCODES["category_uni_not_digit"], DINGBAT_CIRCLED)


class Ctx:
    def __init__(self, pattern):
        self.pattern = pattern

def test_general_category():
    from rpython.rlib.unicodedata import unicodedb

    for cat, positive, negative in [('L', u'aZ\xe9', u'. ?'),
                                    ('P', u'.?', u'aZ\xe9 ')]:
        pat_pos = [70, ord(cat), 0]
        pat_neg = [70, ord(cat) | 0x80, 0]
        for c in positive:
            assert unicodedb.category(ord(c)).startswith(cat)
            assert check_charset(pat_pos, 0, ord(c))
            assert not check_charset(pat_neg, 0, ord(c))
        for c in negative:
            assert not unicodedb.category(ord(c)).startswith(cat)
            assert not check_charset(pat_pos, 0, ord(c))
            assert check_charset(pat_neg, 0, ord(c))

    def cat2num(cat):
        return ord(cat[0]) | (ord(cat[1]) << 8)

    for cat, positive, negative in [('Lu', u'A', u'z\xe9 '),
                                    ('Ll', u'z\xe9', u'A \n')]:
        pat_pos = [70, cat2num(cat), 0]
        pat_neg = [70, cat2num(cat) | 0x80, 0]
        for c in positive:
            assert unicodedb.category(ord(c)) == cat
            assert check_charset(pat_pos, 0, ord(c))
            assert not check_charset(pat_neg, 0, ord(c))
        for c in negative:
            assert unicodedb.category(ord(c)) != cat
            assert not check_charset(pat_pos, 0, ord(c))
            assert check_charset(pat_neg, 0, ord(c))

    # test for how the common 'L&' pattern might be compiled
    pat = [70, cat2num('Lu'), 70, cat2num('Ll'), 70, cat2num('Lt'), 0]
    assert check_charset(pat, 0, 65)    # Lu
    assert check_charset(pat, 0, 99)    # Lcheck_charset(pat, 0, 453)   # Lt
    assert not check_charset(pat, 0, 688)    # Lm
    assert not check_charset(pat, 0, 5870)   # Nl

def test_iscased():
    assert rsre_char.iscased_ascii(65)
    assert rsre_char.iscased_ascii(100)
    assert rsre_char.iscased_ascii(64) is False
    assert rsre_char.iscased_ascii(126) is False
    assert rsre_char.iscased_ascii(1260) is False
    assert rsre_char.iscased_ascii(12600) is False
    for i in range(65536):
        assert rsre_char.iscased_unicode(i) == (
            rsre_char.getlower_unicode(i) != i or
            rsre_char.getupper_unicode(i) != i)
