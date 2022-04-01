"""
Provides internal 'locale' codecs (via POSIX wcstombs/mbrtowc) for use
by PyUnicode_Decode/EncodeFSDefault during interpreter bootstrap
"""
import os
import py
import sys
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib.rstring import StringBuilder, assert_str0
from rpython.rlib.runicode import (
    default_unicode_error_decode, default_unicode_error_encode)
from rpython.rlib.rutf8 import Utf8StringIterator, unichr_as_utf8
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rarithmetic import r_uint
from rpython.translator import cdir
from rpython.translator.tool.cbuild import ExternalCompilationInfo

cwd = py.path.local(__file__).dirpath()
eci = ExternalCompilationInfo(
    includes=[cwd.join('locale_codec.h')],
    include_dirs=[str(cwd), cdir],
    separate_module_files=[cwd.join('locale_codec.c')])

def llexternal(*args, **kwargs):
    kwargs.setdefault('compilation_info', eci)
    kwargs.setdefault('sandboxsafe', True)
    kwargs.setdefault('_nowrapper', True)
    return rffi.llexternal(*args, **kwargs)

# An actual wchar_t*, rffi.CWCHARP is an array of UniChar (possibly on a
# narrow build)
RAW_WCHARP = lltype.Ptr(lltype.Array(rffi.WCHAR_T, hints={'nolength': True}))
pypy_char2wchar = llexternal('pypy_char2wchar', [rffi.CCHARP, rffi.SIZE_TP],
                             RAW_WCHARP)
pypy_char2wchar_strict = llexternal('pypy_char2wchar_strict',
                                    [rffi.CCHARP, rffi.SIZE_TP], RAW_WCHARP)
pypy_char2wchar_free = llexternal('pypy_char2wchar_free', [RAW_WCHARP],
                                  lltype.Void)
pypy_wchar2char = llexternal('pypy_wchar2char', [RAW_WCHARP, rffi.SIZE_TP],
                             rffi.CCHARP)
pypy_wchar2char_strict = llexternal('pypy_wchar2char_strict',
                                    [RAW_WCHARP, rffi.SIZE_TP], rffi.CCHARP)
pypy_wchar2char_free = llexternal('pypy_wchar2char_free', [rffi.CCHARP],
                                  lltype.Void)

def utf8_encode_locale_strict(utf8, ulen):
    """Encode unicode via the locale codecs (POSIX wcstombs) with the
    strict handler.

    The errorhandler is never called
    """
    errorhandler = default_unicode_error_encode

    with lltype.scoped_alloc(rffi.SIZE_TP.TO, 1) as errorposp:
        with scoped_utf82rawwcharp(utf8, ulen) as ubuf:
            sbuf = pypy_wchar2char_strict(ubuf, errorposp)
        try:
            if not sbuf:
                errorpos = rffi.cast(lltype.Signed, errorposp[0])
                if errorpos == -1:
                    raise MemoryError
                errmsg = _errmsg("pypy_wchar2char")
                u = utf8.decode('utf-8')
                errorhandler('strict', 'filesystemencoding', errmsg, u,
                             errorpos, errorpos + 1)
            return rffi.charp2str(sbuf)
        finally:
            pypy_wchar2char_free(sbuf)


def utf8_encode_locale_surrogateescape(utf8, ulen):
    """Encode unicode via the locale codecs (POSIX wcstombs) with the
    surrogateescape handler.

    The errorhandler raises a UnicodeEncodeError
    """
    errorhandler = default_unicode_error_encode

    with lltype.scoped_alloc(rffi.SIZE_TP.TO, 1) as errorposp:
        with scoped_utf82rawwcharp(utf8, ulen) as ubuf:
            sbuf = pypy_wchar2char(ubuf, errorposp)
        try:
            if not sbuf:
                errorpos = rffi.cast(lltype.Signed, errorposp[0])
                if errorpos == -1:
                    raise MemoryError
                errmsg = _errmsg("pypy_wchar2char")
                u = utf8.decode('utf-8')
                errorhandler('strict', 'filesystemencoding', errmsg, u,
                             errorpos, errorpos + 1)
            return rffi.charp2str(sbuf)
        finally:
            pypy_wchar2char_free(sbuf)

def utf8_encode_locale(utf8, ulen, errors):
    if errors == 'strict':
        return utf8_encode_locale_strict(utf8, ulen)
    return utf8_encode_locale_surrogateescape(utf8, ulen)

def str_decode_locale_strict(s):
    """Decode strs via the locale codecs (POSIX mrbtowc) with the
    surrogateescape handler.

    The errorhandler is never called
    errors.
    """
    errorhandler = default_unicode_error_decode

    with lltype.scoped_alloc(rffi.SIZE_TP.TO, 1) as sizep:
        with rffi.scoped_str2charp(s) as sbuf:
            ubuf = pypy_char2wchar_strict(sbuf, sizep)
            try:
                if not ubuf:
                    errmsg = _errmsg("pypy_char2wchar_strict")
                    errorhandler('strict', 'filesystemencoding', errmsg, s, 0, 1)
                size = rffi.cast(lltype.Signed, sizep[0])
                return rawwcharp2utf8en(ubuf, size), size
            finally:
                pypy_char2wchar_free(ubuf)


def str_decode_locale_surrogateescape(s):
    """Decode strs via the locale codecs (POSIX mrbtowc) with the
    surrogateescape handler.

    The errorhandler is never called
    errors.
    """
    errorhandler = default_unicode_error_decode

    with lltype.scoped_alloc(rffi.SIZE_TP.TO, 1) as sizep:
        with rffi.scoped_str2charp(s) as sbuf:
            ubuf = pypy_char2wchar(sbuf, sizep)
            try:
                if not ubuf:
                    errmsg = _errmsg("pypy_char2wchar")
                    errorhandler('strict', 'filesystemencoding', errmsg, s, 0, 1)
                size = rffi.cast(lltype.Signed, sizep[0])
                return rawwcharp2utf8en(ubuf, size), size
            finally:
                pypy_char2wchar_free(ubuf)

def str_decode_locale(s, errors):
    if errors == 'strict':
        return str_decode_locale_strict(s)
    return str_decode_locale_surrogateescape(s)

def _errmsg(what):
    # I *think* that the functions in locale_codec.c don't set errno
    return "%s failed" % what


class scoped_utf82rawwcharp:
    def __init__(self, value, lgt):
        if value is not None:
            self.buf = utf82rawwcharp(value, lgt)
        else:
            self.buf = lltype.nullptr(RAW_WCHARP.TO)
    def __enter__(self):
        return self.buf
    def __exit__(self, *args):
        if self.buf:
            lltype.free(self.buf, flavor='raw')

def utf82rawwcharp(utf8, size):
    """utf8, lgt -> raw wchar_t*"""
    if _should_merge_surrogates():
        size = _utf82rawwcharp_loop(utf8, size, lltype.nullptr(RAW_WCHARP.TO))
    array = lltype.malloc(RAW_WCHARP.TO, size + 1, flavor='raw')
    array[size] = rffi.cast(rffi.WCHAR_T, u'\x00')
    _utf82rawwcharp_loop(utf8, size, array)
    return array
utf82rawwcharp._annenforceargs_ = [str, int]

def _utf82rawwcharp_loop(utf8, ulen, array):
    count = 0
    u_iter = Utf8StringIterator(utf8)
    for oc in u_iter:
        if (_should_merge_surrogates() and 0xD800 <= oc <= 0xDBFF):
            try:
                oc1 = u_iter.next()
                if 0xDC00 <= oc1 <= 0xDFFF:
                    if array:
                        merged = (((oc & 0x03FF) << 10) |
                              (oc1 & 0x03FF)) + 0x10000
                        array[count] = rffi.cast(rffi.WCHAR_T, merged)
                else:
                    if array:
                        array[count] = rffi.cast(rffi.WCHAR_T, oc)
                        count += 1
                        array[count] = rffi.cast(rffi.WCHAR_T, oc1)
            except StopIteration:
                if array:
                    array[count] = rffi.cast(rffi.WCHAR_T, oc)
                count += 1
                break
        else:
            if array:
                array[count] = rffi.cast(rffi.WCHAR_T, oc)
        count += 1
    return count
_utf82rawwcharp_loop._annenforceargs_ = [str, int, None]


def rawwcharp2utf8en(wcp, maxlen):
    b = StringBuilder(maxlen)
    i = 0
    while i < maxlen:
        v = r_uint(wcp[i])
        if v == 0:
            break
        b.append(unichr_as_utf8(v, True))
        i += 1
    return assert_str0(b.build())
rawwcharp2utf8en._annenforceargs_ = [None, int]


def _should_merge_surrogates():
    if we_are_translated():
        unichar_size = rffi.sizeof(lltype.UniChar)
    else:
        unichar_size = 2 if sys.maxunicode == 0xFFFF else 4
    return unichar_size == 2 and rffi.sizeof(rffi.WCHAR_T) == 4

