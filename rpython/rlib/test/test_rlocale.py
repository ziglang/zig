
# -*- coding: utf-8 -*-

import py, sys
import locale as cpython_locale
from rpython.rlib.rlocale import setlocale, LC_ALL, LocaleError, isupper, \
     islower, isalpha, tolower, isalnum, numeric_formatting, external
from rpython.rtyper.lltypesystem import rffi

class TestLocale(object):
    def setup_class(cls):
        try:
            cls.oldlocale = setlocale(LC_ALL, "pl_PL.utf8")
        except LocaleError:
            py.test.skip("polish locale unsupported")

    def teardown_class(cls):
        if hasattr(cls, "oldlocale"):
            setlocale(LC_ALL, cls.oldlocale)

    def test_setlocale_worked(self):
        assert u"Ą".isupper()
        py.test.raises(LocaleError, setlocale, LC_ALL, "bla bla bla")
        py.test.raises(LocaleError, setlocale, 1234455, None)

    def test_lower_upper(self):
        assert isupper(ord("A"))
        assert islower(ord("a"))
        assert not isalpha(ord(" "))
        assert isalnum(ord("1"))
        assert tolower(ord("A")) == ord("a")

def test_numeric_formatting():
    dec, th, grouping = numeric_formatting()
    assert isinstance(dec, str)
    assert isinstance(th, str)
    assert isinstance(grouping, str)

def test_libintl():
    if sys.platform != "darwin" and not sys.platform.startswith("linux"):
        py.test.skip("there is (maybe) no libintl here")
    _gettext = external('gettext', [rffi.CCHARP], rffi.CCHARP)
    p = rffi.str2charp("1234")
    res = _gettext(p)
    assert res == p
    assert rffi.charp2str(res) == "1234"
    rffi.free_charp(p)
