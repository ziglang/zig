import os
from rpython.rlib.rsiphash import siphash24, _siphash24, choosen_seed
from rpython.rlib.rsiphash import initialize_from_env, enable_siphash24
from rpython.rlib.rsiphash import ll_hash_string_siphash24
from rpython.rlib.rsiphash import siphash24_with_key
from rpython.rlib.objectmodel import compute_hash
from rpython.rlib.rarithmetic import intmask
from rpython.rtyper.annlowlevel import llstr, llunicode
from rpython.rtyper.lltypesystem import llmemory, rffi
from rpython.translator.c.test.test_genc import compile


CASES = [
    (2323638336262702335 , ""),
    (5150479602681463644 , "h"),
    (1013213613370725794 , "he"),
    (7028032310911240238 , "hel"),
    (9535960132410784494 , "hell"),
    (3256502711089771242 , "hello"),
    (2389188832234450176 , "hello "),
    (13253855839845990393, "hello w"),
    (7850036019043917323 , "hello wo"),
    (14283308628425005953, "hello wor"),
    (9605549962279590084 , "hello worl"),
    (16371281469632894235, "hello world"),
    (7298637955795769949 , "hello world\x9a"),
    (13530878135053370821, "hello world\xf3\x80"),
    (1643533543579802994 , "\xffhel\x82lo world\xbc"),
    (14632093238728197380, "hexlylxox rewqw"),
    (3434253029196696424 , "hexlylxox rewqws"),
    (9855754545877066788 , "hexlylxox rewqwsv"),
    (5233065012564472454 , "hexlylxox rewqwkashdw89"),
    (16768585622569081808, "hexlylxox rewqwkeashdw89"),
    (17430482483431293463, "HEEExlylxox rewqwkashdw89"),
    (695783005783737705  , "hello woadwealidewd 3829ez 32ig dxwaebderld"),
]

def check(s):
    q = rffi.str2charp('?' + s)
    with choosen_seed(0x8a9f065a358479f4, 0x11cb1e9ee7f40e1f,
                      test_misaligned_path=True):
        x = siphash24(s)
        y = _siphash24(llmemory.cast_ptr_to_adr(rffi.ptradd(q, 1)), len(s))
        z = ll_hash_string_siphash24(llstr(s))
    rffi.free_charp(q)
    assert x == y
    assert z == intmask(x)
    return x

def test_siphash24():
    for expected, string in CASES:
        assert check(string) == expected

def test_siphash24_with_key():
    from rpython.rlib.rarithmetic import r_uint64
    assert siphash24_with_key(b"abcdef", r_uint64(1)) == r_uint64(7956077396882317016L)

def check_latin1(s, expected, test_prebuilt=False):
    with choosen_seed(0x8a9f065a358479f4, 0x11cb1e9ee7f40e1f,
                      test_misaligned_path=True, test_prebuilt=test_prebuilt):
        z = ll_hash_string_siphash24(llunicode(s))
    assert z == intmask(expected)

def test_siphash24_latin1_unicode():
    for expected, string in CASES:
        check_latin1(string.decode('latin1'), expected)

def test_siphash24_latin1_unicode_prebuilt():
    for expected, string in CASES:
        check_latin1(string.decode('latin1'), expected, test_prebuilt=True)

def test_fix_seed():
    old_val = os.environ.get('PYTHONHASHSEED', None)
    try:
        os.environ['PYTHONHASHSEED'] = '0'
        initialize_from_env()
        assert siphash24("foo") == 15988776847138518036
        # value checked with CPython 3.5 (turned positive by adding 2**64)

        os.environ['PYTHONHASHSEED'] = '4000000000'
        initialize_from_env()
        assert siphash24("foo") == 13829150778707464258
        # value checked with CPython 3.5 (turned positive by adding 2**64)

        for env in ['', 'random']:
            os.environ['PYTHONHASHSEED'] = env
            initialize_from_env()
            hash1 = siphash24("foo")
            initialize_from_env()
            hash2 = siphash24("foo")
            assert hash1 != hash2     # extremely unlikely
    finally:
        if old_val is None:
            del os.environ['PYTHONHASHSEED']
        else:
            os.environ['PYTHONHASHSEED'] = old_val

def test_translated():
    d1 = {"foo": 123}
    d2 = {u"foo": 456, u"\u1234\u5678": 789}
    class G:
        pass
    g = G()
    g.v1 = d1.copy()
    g.v2 = d2.copy()

    def fetch(n):
        if n == 0: return d1.get("foo", -1)
        if n == 1: return g.v1.get("foo", -1)
        if n == 2: return compute_hash("foo")
        if n == 3: return d2.get(u"foo", -1)
        if n == 4: return g.v2.get(u"foo", -1)
        if n == 5: return compute_hash(u"foo")
        if n == 6: return d2.get(u"\u1234\u5678", -1)
        if n == 7: return g.v2.get(u"\u1234\u5678", -1)
        if n == 8: return compute_hash(u"\u1234\u5678")
        assert 0

    def entrypoint(n):
        enable_siphash24()
        g.v1["bar"] = -2
        g.v2[u"bar"] = -2
        if n >= 0:    # get items one by one, because otherwise it may
                      # be the case that one line influences the next
            return str(fetch(n))
        else:
            # ...except in random mode, because we want all results
            # to be computed with the same seed
            return ' '.join([str(fetch(n)) for n in range(9)])

    fn = compile(entrypoint, [int])

    def getall():
        return [int(fn(i)) for i in range(9)]

    old_val = os.environ.get('PYTHONHASHSEED', None)
    try:
        os.environ['PYTHONHASHSEED'] = '0'
        s1 = getall()
        assert s1[:8] == [
            123, 123, intmask(15988776847138518036),
            456, 456, intmask(15988776847138518036),
            789, 789]
        assert s1[8] in [intmask(17593683438421985039),    # ucs2 mode little endian
                         intmask(94801584261658677),       # ucs4 mode little endian
                         intmask(3849431280840015342),]    # ucs4 mode big endian

        os.environ['PYTHONHASHSEED'] = '3987654321'
        s1 = getall()
        assert s1[:8] == [
            123, 123, intmask(5890804383681474441),
            456, 456, intmask(5890804383681474441),
            789, 789]
        assert s1[8] in [intmask(4192582507672183374),     # ucs2 mode little endian
                         intmask(7179255293164649778),     # ucs4 mode little endian
                         intmask(-3945781295304514711),]   # ucs4 mode big endian

        for env in ['', 'random']:
            os.environ['PYTHONHASHSEED'] = env
            s1 = map(int, fn(-1).split())
            s2 = map(int, fn(-1).split())
            assert s1[0:2]+s1[3:5]+s1[6:8] == [123, 123, 456, 456, 789, 789]
            assert s1[2] == s1[5]
            assert s2[0:2]+s2[3:5]+s2[6:8] == [123, 123, 456, 456, 789, 789]
            assert s2[2] == s2[5]
            #
            assert len(set([s1[2], s2[2], s1[8], s2[8]])) == 4

    finally:
        if old_val is None:
            del os.environ['PYTHONHASHSEED']
        else:
            os.environ['PYTHONHASHSEED'] = old_val
