
""" This test checks whether args wrapping behavior is correct
"""
import pytest
import sys

from ctypes import *

@pytest.mark.pypy_only
def test_wrap_args():
    from _ctypes import CFuncPtr

    def guess(value):
        _, cobj, ctype = CFuncPtr._conv_param(None, value)
        return ctype
        ## cobj = CFuncPtr._conv_param(None, value)
        ## return type(cobj)

    assert guess(13) == c_int
    assert guess(0) == c_int
    assert guess(b'xca') == c_char_p
    assert guess(None) == c_void_p
    assert guess(c_int(3)) == c_int
    assert guess(u'xca') == c_wchar_p

    class Stuff:
        pass
    s = Stuff()
    s._as_parameter_ = None

    assert guess(s) == c_void_p

def test_guess_unicode(dll):
    if not hasattr(sys, 'pypy_translation_info') and sys.platform != 'win32':
        pytest.skip("CPython segfaults: see http://bugs.python.org/issue5203")
    wcslen = dll.my_wcslen
    text = u"Some long unicode string"
    assert wcslen(text) == len(text)
