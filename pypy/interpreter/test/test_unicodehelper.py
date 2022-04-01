# encoding: utf-8
import pytest

from pypy.interpreter.unicodehelper import (
    utf8_encode_utf_8, decode_utf8sp, ErrorHandlerError
)

from pypy.interpreter.unicodehelper import str_decode_utf8, utf8_encode_latin_1
from pypy.interpreter.unicodehelper import utf8_encode_ascii, str_decode_ascii
from pypy.interpreter.unicodehelper import utf8_encode_latin_1, str_decode_unicode_escape
from pypy.interpreter.unicodehelper import str_decode_raw_unicode_escape
from pypy.interpreter import unicodehelper as uh
from pypy.module._codecs.interp_codecs import CodecState

class Hit(Exception):
    pass

class FakeSpace:
    def __getattr__(self, name):
        if name in ('w_UnicodeEncodeError', 'w_UnicodeDecodeError'):
            raise Hit
        raise AttributeError(name)


def test_encode_utf_8_combine_surrogates():
    """
    In the case of a surrogate pair, the error handler should
    called with a start and stop position of the full surrogate
    pair (new behavior in python3.6)
    """
    #               /--surrogate pair--\
    #    \udc80      \ud800      \udfff
    b = "\xed\xb2\x80\xed\xa0\x80\xed\xbf\xbf"

    calls = []

    def errorhandler(errors, encoding, msg, s, start, end):
        """
        This handler will be called twice, so asserting both times:

        1. the first time, 0xDC80 will be handled as a single surrogate,
           since it is a standalone character and an invalid surrogate.
        2. the second time, the characters will be 0xD800 and 0xDFFF, since
           that is a valid surrogate pair.
        """
        calls.append(s.decode("utf-8")[start:end])
        return 'abc', end, 'b', s

    res = utf8_encode_utf_8(
        b, 'strict',
        errorhandler=errorhandler,
        allow_surrogates=False
    )
    assert res == "abcabc"
    assert calls == [u'\udc80', u'\uD800\uDFFF']

def test_bad_error_handler():
    b = u"\udc80\ud800\udfff".encode("utf-8")
    def errorhandler(errors, encoding, msg, s, start, end):
        return '', start, 'b', s # returned index is too small

    pytest.raises(ErrorHandlerError, utf8_encode_utf_8, b, 'strict',
                  errorhandler=errorhandler, allow_surrogates=False)

def test_decode_utf8sp():
    space = FakeSpace()
    assert decode_utf8sp(space, "\xed\xa0\x80") == ("\xed\xa0\x80", 1, 3)
    assert decode_utf8sp(space, "\xed\xb0\x80") == ("\xed\xb0\x80", 1, 3)
    got = decode_utf8sp(space, "\xed\xa0\x80\xed\xb0\x80")
    assert map(ord, got[0].decode('utf8')) == [0xd800, 0xdc00]
    got = decode_utf8sp(space, "\xf0\x90\x80\x80")
    assert map(ord, got[0].decode('utf8')) == [0x10000]


def test_utf8_encode_latin1_ascii_prefix():
    utf8 = b'abcde\xc3\xa4g'
    b = utf8_encode_latin_1(utf8, None, None)
    assert b == b'abcde\xe4g'

def test_latin1_shortcut_bug(space):
    state = space.fromcache(CodecState)
    handler = state.encode_error_handler

    sin = u"a\xac\u1234\u20ac\u8000"
    assert utf8_encode_latin_1(sin.encode("utf-8"), "backslashreplace", handler) == sin.encode("latin-1", "backslashreplace")

def test_unicode_escape_incremental_bug():
    class FakeUnicodeDataHandler:
        def call(self, name):
            assert name == "QUESTION MARK"
            return ord("?")
    unicodedata_handler = FakeUnicodeDataHandler()
    input = u"äҰ𐀂?"
    data = b'\\xe4\\u04b0\\U00010002\\N{QUESTION MARK}'
    for i in range(1, len(data)):
        result1, _, lgt1, _ = str_decode_unicode_escape(data[:i], 'strict', False, None, unicodedata_handler)
        result2, _, lgt2, _ = str_decode_unicode_escape(data[lgt1:i] + data[i:], 'strict', True, None, unicodedata_handler)
        assert lgt1 + lgt2 == len(data)
        assert input == (result1 + result2).decode("utf-8")

def test_raw_unicode_escape_incremental_bug():
    input = u"xҰa𐀂"
    data = b'x\\u04b0a\\U00010002'
    for i in range(1, len(data)):
        result1, _, lgt1 = str_decode_raw_unicode_escape(data[:i], 'strict', False, None)
        result2, _, lgt2 = str_decode_raw_unicode_escape(data[lgt1:i] + data[i:], 'strict', True, None)
        assert lgt1 + lgt2 == len(data)
        assert input == (result1 + result2).decode("utf-8")

def test_raw_unicode_escape_backslash_without_escape():
    data = b'[:/?#[\\]@]\\'
    result, _, l = str_decode_raw_unicode_escape(data, 'strict', True, None)
    assert l == len(data)
    assert result == data

