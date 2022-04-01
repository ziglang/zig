#encoding: utf-8
import pytest
import sys
from hypothesis import given, strategies, settings, example

from rpython.rlib import rutf8, runicode
from rpython.rlib.unicodedata import unicodedb_12_1_0


@given(strategies.characters(), strategies.booleans())
def test_unichr_as_utf8(c, allow_surrogates):
    i = ord(c)
    if not allow_surrogates and 0xD800 <= i <= 0xDFFF:
        with pytest.raises(rutf8.OutOfRange):
            rutf8.unichr_as_utf8(i, allow_surrogates)
    else:
        u = rutf8.unichr_as_utf8(i, allow_surrogates)
        assert u == c.encode('utf8')

@given(strategies.binary())
def test_check_ascii(s):
    raised = False
    try:
        s.decode('ascii')
    except UnicodeDecodeError as e:
        raised = True
    try:
        rutf8.check_ascii(s)
    except rutf8.CheckError:
        assert raised
    else:
        assert not raised

@given(strategies.binary(), strategies.booleans())
@example('\xf1\x80\x80\x80', False)
def test_check_utf8(s, allow_surrogates):
    _test_check_utf8(s, allow_surrogates)

@given(strategies.text(), strategies.booleans())
def test_check_utf8_valid(u, allow_surrogates):
    _test_check_utf8(u.encode('utf-8'), allow_surrogates)

@given(strategies.binary(), strategies.text(), strategies.binary())
def test_check_utf8_slice(a, b, c):
    start = len(a)
    b_utf8 = b.encode('utf-8')
    end = start + len(b_utf8)
    assert rutf8.check_utf8(a + b_utf8 + c, False, start, end) == len(b)

def _has_surrogates(s):
    for u in s.decode('utf8'):
        if 0xD800 <= ord(u) <= 0xDFFF:
            return True
    return False

def _test_check_utf8(s, allow_surrogates):
    try:
        u, _ = runicode.str_decode_utf_8(s, len(s), None, final=True,
                                         allow_surrogates=allow_surrogates)
        valid = True
    except UnicodeDecodeError as e:
        valid = False
    length = rutf8._check_utf8(s, allow_surrogates, 0, len(s))
    if length < 0:
        assert not valid
        assert ~(length) == e.start
    else:
        assert valid
        if sys.maxunicode == 0x10FFFF or not _has_surrogates(s):
            assert length == len(u)

@given(strategies.characters())
def test_next_pos(uni):
    skips = []
    for elem in uni:
        skips.append(len(elem.encode('utf8')))
    pos = 0
    i = 0
    utf8 = uni.encode('utf8')
    while pos < len(utf8):
        new_pos = rutf8.next_codepoint_pos(utf8, pos)
        assert new_pos - pos == skips[i]
        i += 1
        pos = new_pos

def test_check_newline_utf8():
    for i in xrange(sys.maxunicode):
        if runicode.unicodedb.islinebreak(i):
            assert rutf8.islinebreak(unichr(i).encode('utf8'), 0)
        else:
            assert not rutf8.islinebreak(unichr(i).encode('utf8'), 0)

def test_isspace_utf8():
    for i in xrange(sys.maxunicode):
        if runicode.unicodedb.isspace(i):
            assert rutf8.isspace(unichr(i).encode('utf8'), 0)
        else:
            assert not rutf8.isspace(unichr(i).encode('utf8'), 0)

@given(strategies.characters(), strategies.text())
def test_utf8_in_chars(ch, txt):
    response = rutf8.utf8_in_chars(ch.encode('utf8'), 0, txt.encode('utf8'))
    r = (ch in txt)
    assert r == response

@given(strategies.text(), strategies.integers(min_value=0),
                          strategies.integers(min_value=0))
def test_codepoints_in_utf8(u, start, len1):
    end = start + len1
    if end > len(u):
        extra = end - len(u)
    else:
        extra = 0
    count = rutf8.codepoints_in_utf8(u.encode('utf8'),
                                     len(u[:start].encode('utf8')),
                                     len(u[:end].encode('utf8')) + extra)
    assert count == len(u[start:end])

@given(strategies.text())
def test_utf8_index_storage(u):
    index = rutf8.create_utf8_index_storage(u.encode('utf8'), len(u))
    for i, item in enumerate(u):
        assert (rutf8.codepoint_at_index(u.encode('utf8'), index, i) ==
                ord(item))

@given(strategies.text())
@example(u'x' * 64 * 5)
@example(u'x' * (64 * 5 - 1))
def test_codepoint_position_at_index(u):
    index = rutf8.create_utf8_index_storage(u.encode('utf8'), len(u))
    for i in range(len(u) + 1):
        assert (rutf8.codepoint_position_at_index(u.encode('utf8'), index, i) ==
                len(u[:i].encode('utf8')))

@given(strategies.text())
@example(u'x' * 64 * 5)
@example(u'x' * (64 * 5 - 1))
@example(u'ä' + u'x«' * 1000 + u'–' + u'y' * 100)
def test_codepoint_index_at_byte_position(u):
    b = u.encode('utf8')
    storage = rutf8.create_utf8_index_storage(b, len(u))
    for i in range(len(u) + 1):
        bytepos = len(u[:i].encode('utf8'))
        assert rutf8.codepoint_index_at_byte_position(
                       b, storage, bytepos, len(u)) == i

@given(strategies.text())
def test_codepoint_position_at_index_inverse(u):
    print u
    b = u.encode('utf8')
    storage = rutf8.create_utf8_index_storage(b, len(u))
    for i in range(len(u) + 1):
        bytepos = rutf8.codepoint_position_at_index(b, storage, i)
        assert rutf8.codepoint_index_at_byte_position(
                       b, storage, bytepos, len(u)) == i


repr_func = rutf8.make_utf8_escape_function(prefix='u', pass_printable=False,
                                            quotes=True)

@given(strategies.text())
def test_repr(u):
    assert repr(u) == repr_func(u.encode('utf8'))

@given(strategies.lists(strategies.characters()))
@example([u'\ud800', u'\udc00'])
def test_surrogate_in_utf8(unichars):
    uni = ''.join([u.encode('utf8') for u in unichars])
    result = rutf8.surrogate_in_utf8(uni) >= 0
    expected = any(uch for uch in unichars if u'\ud800' <= uch <= u'\udfff')
    assert result == expected


def test_utf8_string_builder():
    s = rutf8.Utf8StringBuilder()
    s.append("foo")
    s.append_char("x")
    assert s.getlength() == 4
    assert s.build() == "foox"
    s.append(u"\u1234".encode("utf8"))
    assert s.getlength() == 5
    assert s.build().decode("utf8") == u"foox\u1234"
    s.append("foo")
    s.append_char("x")
    assert s.getlength() == 9
    assert s.build().decode("utf8") == u"foox\u1234foox"

    s = rutf8.Utf8StringBuilder()
    s.append_code(0x1234)
    assert s.build().decode("utf8") == u"\u1234"
    assert s.getlength() == 1
    s.append_code(0xD800)
    assert s.getlength() == 2

    s = rutf8.Utf8StringBuilder()
    s.append_utf8("abc", 3)
    assert s.getlength() == 3
    assert s.build().decode("utf8") == u"abc"

    s.append_utf8(u"\u1234".encode("utf8"), 1)
    assert s.build().decode("utf8") == u"abc\u1234"
    assert s.getlength() == 4

    s.append_code(0xD800)
    assert s.getlength() == 5

    s.append_utf8_slice(u"äöüß".encode("utf-8"), 2, 6, 2)
    assert s.getlength() == 7
    assert s.build().decode("utf-8") == u"abc\u1234\ud800öü"

def test_utf8_string_builder_bad_code():
    s = rutf8.Utf8StringBuilder()
    with pytest.raises(rutf8.OutOfRange):
        s.append_code(0x110000)
    assert s.build() == ''
    assert s.getlength() == 0

@given(strategies.text())
def test_utf8_iterator(arg):
    u = rutf8.Utf8StringIterator(arg.encode('utf8'))
    l = []
    for c in u:
        l.append(unichr(c))
    assert list(arg) == l

@given(strategies.text())
def test_utf8_iterator_pos(arg):
    utf8s = arg.encode('utf8')
    u = rutf8.Utf8StringPosIterator(utf8s)
    l = []
    i = 0
    for c, pos in u:
        l.append(unichr(c))
        assert c == rutf8.codepoint_at_pos(utf8s, pos)
        assert pos == i
        i = rutf8.next_codepoint_pos(utf8s, i)
    assert list(arg) == l


@given(strategies.text(), strategies.integers(0xd800, 0xdfff))
def test_has_surrogates(arg, surrogate):
    b = (arg + unichr(surrogate) + arg).encode("utf-8")
    assert not rutf8.has_surrogates(arg.encode("utf-8"))
    assert rutf8.has_surrogates(unichr(surrogate).encode("utf-8"))
    assert rutf8.has_surrogates(b)

def test_has_surrogate_xed_no_surrogate():
    u = unichr(55217) + unichr(54990)
    b = u.encode("utf-8")
    assert b.startswith(b"\xed")
    assert not rutf8.has_surrogates(b)

printable_repr_func = rutf8.make_utf8_escape_function(pass_printable=True,
                                                      quotes=True,
                                                      unicodedb=unicodedb_12_1_0)

def test_printable_repr_func():
    s = u'\U0001f42a'.encode("utf-8")
    assert printable_repr_func(s) == "'" + s + "'"

