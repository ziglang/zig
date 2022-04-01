from rpython.rlib import rposix
from rpython.rlib.rarithmetic import intmask

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import unwrap_spec

from rpython.rlib import rlocale
from pypy.module.exceptions.interp_exceptions import _new_exception, W_Exception
from rpython.rtyper.lltypesystem import lltype, rffi

W_Error = _new_exception('Error', W_Exception, 'locale error')

import sys

def make_error(space, msg):
    return OperationError(space.gettypeobject(W_Error.typedef), space.newtext(msg))

def rewrap_error(space, e):
    return OperationError(space.gettypeobject(W_Error.typedef),
                          space.newtext(e.message))

@unwrap_spec(category=int)
def setlocale(space, category, w_locale=None):
    "(integer,string=None) -> string. Activates/queries locale processing."

    if space.is_none(w_locale):
        locale = None
    else:
        locale = space.text_w(w_locale)
    try:
        result = rlocale.setlocale(category, locale)
    except rlocale.LocaleError as e:
        raise rewrap_error(space, e)
    return space.newtext(result)

def _w_copy_grouping(space, text):
    groups = [ space.newint(ord(group)) for group in text ]
    if groups:
        groups.append(space.newint(0))
    return space.newlist(groups)

def charp2uni(space, s):
    "Convert a char* pointer to unicode according to the current locale"
    w_val = space.newbytes(rffi.charp2str(s))
    return space.call_function(space.w_unicode, w_val, space.newtext('utf-8'),
                               space.newtext('surrogateescape'))

def localeconv(space):
    "() -> dict. Returns numeric and monetary locale-specific parameters."
    lp = rlocale.localeconv()

    # Numeric information
    w_result = space.newdict()
    space.setitem(w_result, space.newtext("decimal_point"),
                  charp2uni(space, lp.c_decimal_point))
    space.setitem(w_result, space.newtext("thousands_sep"),
                  charp2uni(space, lp.c_thousands_sep))
    space.setitem(w_result, space.newtext("grouping"),
                  _w_copy_grouping(space, rffi.charp2str(lp.c_grouping)))
    space.setitem(w_result, space.newtext("int_curr_symbol"),
                  charp2uni(space, lp.c_int_curr_symbol))
    space.setitem(w_result, space.newtext("currency_symbol"),
                  charp2uni(space, lp.c_currency_symbol))
    space.setitem(w_result, space.newtext("mon_decimal_point"),
                  charp2uni(space, lp.c_mon_decimal_point))
    space.setitem(w_result, space.newtext("mon_thousands_sep"),
                  charp2uni(space, lp.c_mon_thousands_sep))
    space.setitem(w_result, space.newtext("mon_grouping"),
                  _w_copy_grouping(space, rffi.charp2str(lp.c_mon_grouping)))
    space.setitem(w_result, space.newtext("positive_sign"),
                  charp2uni(space, lp.c_positive_sign))
    space.setitem(w_result, space.newtext("negative_sign"),
                  charp2uni(space, lp.c_negative_sign))
    space.setitem(w_result, space.newtext("int_frac_digits"),
                  space.newint(lp.c_int_frac_digits))
    space.setitem(w_result, space.newtext("frac_digits"),
                  space.newint(lp.c_frac_digits))
    space.setitem(w_result, space.newtext("p_cs_precedes"),
                  space.newint(lp.c_p_cs_precedes))
    space.setitem(w_result, space.newtext("p_sep_by_space"),
                  space.newint(lp.c_p_sep_by_space))
    space.setitem(w_result, space.newtext("n_cs_precedes"),
                  space.newint(lp.c_n_cs_precedes))
    space.setitem(w_result, space.newtext("n_sep_by_space"),
                  space.newint(lp.c_n_sep_by_space))
    space.setitem(w_result, space.newtext("p_sign_posn"),
                  space.newint(lp.c_p_sign_posn))
    space.setitem(w_result, space.newtext("n_sign_posn"),
                  space.newint(lp.c_n_sign_posn))

    return w_result

_wcscoll = rlocale.external('wcscoll', [rffi.CWCHARP, rffi.CWCHARP], rffi.INT)


def strcoll(space, w_s1, w_s2):
    "string,string -> int. Compares two strings according to the locale."

    s1, l1 = space.utf8_len_w(w_s1)
    s2, l2 = space.utf8_len_w(w_s2)
    if '\x00' in s1 or '\x00' in s2:
        raise oefmt(space.w_ValueError, "embedded null character")

    s1_c = rffi.utf82wcharp(s1, l1)
    s2_c = rffi.utf82wcharp(s2, l2)
    try:
        result = _wcscoll(s1_c, s2_c)
    finally:
        rffi.free_wcharp(s1_c)
        rffi.free_wcharp(s2_c)

    return space.newint(result)

_strxfrm = rlocale.external('strxfrm',
                    [rffi.CCHARP, rffi.CCHARP, rffi.SIZE_T], rffi.SIZE_T)

@unwrap_spec(s='text0')
def strxfrm(space, s):
    "string -> string. Returns a string that behaves for cmp locale-aware."
    n1 = len(s) + 1

    buf = lltype.malloc(rffi.CCHARP.TO, n1, flavor="raw", zero=True)
    s_c = rffi.str2charp(s)
    try:
        n2 = _strxfrm(buf, s_c, n1) + 1
    finally:
        rffi.free_charp(s_c)
    if n2 > n1:
        # more space needed
        lltype.free(buf, flavor="raw")
        buf = lltype.malloc(rffi.CCHARP.TO, intmask(n2),
                            flavor="raw", zero=True)
        s_c = rffi.str2charp(s)
        try:
            _strxfrm(buf, s_c, n2)
        finally:
            rffi.free_charp(s_c)

    val = rffi.charp2str(buf)
    lltype.free(buf, flavor="raw")

    return space.newtext(val)

if rlocale.HAVE_LANGINFO:

    @unwrap_spec(key=int)
    def nl_langinfo(space, key):
        """nl_langinfo(key) -> string
        Return the value for the locale information associated with key."""

        try:
            w_val = space.newbytes(rlocale.nl_langinfo(key))
        except ValueError:
            raise oefmt(space.w_ValueError, "unsupported langinfo constant")
        return space.call_function(space.w_unicode, w_val,
             space.newtext('utf-8'), space.newtext('surrogateescape'))

#___________________________________________________________________
# HAVE_LIBINTL dependence

if rlocale.HAVE_LIBINTL:
    _gettext = rlocale.external('gettext', [rffi.CCHARP], rffi.CCHARP)

    @unwrap_spec(msg='text')
    def gettext(space, msg):
        """gettext(msg) -> string
        Return translation of msg."""
        msg_c = rffi.str2charp(msg)
        try:
            return space.newtext(rffi.charp2str(_gettext(msg_c)))
        finally:
            rffi.free_charp(msg_c)

    _dgettext = rlocale.external('dgettext', [rffi.CCHARP, rffi.CCHARP], rffi.CCHARP)

    @unwrap_spec(msg='text')
    def dgettext(space, w_domain, msg):
        """dgettext(domain, msg) -> string
        Return translation of msg in domain."""
        if space.is_w(w_domain, space.w_None):
            domain = None
            msg_c = rffi.str2charp(msg)
            try:
                result = _dgettext(domain, msg_c)
                # note that 'result' may be the same pointer as 'msg_c',
                # so it must be converted to an RPython string *before*
                # we free msg_c.
                result = rffi.charp2str(result)
            finally:
                rffi.free_charp(msg_c)
        else:
            domain = space.text_w(w_domain)
            domain_c = rffi.str2charp(domain)
            msg_c = rffi.str2charp(msg)
            try:
                result = _dgettext(domain_c, msg_c)
                # note that 'result' may be the same pointer as 'msg_c',
                # so it must be converted to an RPython string *before*
                # we free msg_c.
                result = rffi.charp2str(result)
            finally:
                rffi.free_charp(domain_c)
                rffi.free_charp(msg_c)

        return space.newtext(result)

    _dcgettext = rlocale.external('dcgettext', [rffi.CCHARP, rffi.CCHARP, rffi.INT],
                                                                rffi.CCHARP)

    @unwrap_spec(msg='text', category=int)
    def dcgettext(space, w_domain, msg, category):
        """dcgettext(domain, msg, category) -> string
        Return translation of msg in domain and category."""

        if space.is_w(w_domain, space.w_None):
            domain = None
            msg_c = rffi.str2charp(msg)
            try:
                result = _dcgettext(domain, msg_c, rffi.cast(rffi.INT, category))
                # note that 'result' may be the same pointer as 'msg_c',
                # so it must be converted to an RPython string *before*
                # we free msg_c.
                result = rffi.charp2str(result)
            finally:
                rffi.free_charp(msg_c)
        else:
            domain = space.text_w(w_domain)
            domain_c = rffi.str2charp(domain)
            msg_c = rffi.str2charp(msg)
            try:
                result = _dcgettext(domain_c, msg_c,
                                    rffi.cast(rffi.INT, category))
                # note that 'result' may be the same pointer as 'msg_c',
                # so it must be converted to an RPython string *before*
                # we free msg_c.
                result = rffi.charp2str(result)
            finally:
                rffi.free_charp(domain_c)
                rffi.free_charp(msg_c)

        return space.newtext(result)


    _textdomain = rlocale.external('textdomain', [rffi.CCHARP], rffi.CCHARP)

    def textdomain(space, w_domain):
        """textdomain(domain) -> string
        Set the C library's textdomain to domain, returning the new domain."""

        if space.is_w(w_domain, space.w_None):
            domain = None
            result = _textdomain(domain)
            result = rffi.charp2str(result)
        else:
            domain = space.text_w(w_domain)
            domain_c = rffi.str2charp(domain)
            try:
                result = _textdomain(domain_c)
                # note that 'result' may be the same pointer as 'domain_c'
                # (maybe?) so it must be converted to an RPython string
                # *before* we free domain_c.
                result = rffi.charp2str(result)
            finally:
                rffi.free_charp(domain_c)

        return space.newtext(result)

    _bindtextdomain = rlocale.external('bindtextdomain', [rffi.CCHARP, rffi.CCHARP],
                                                                rffi.CCHARP,
                                       save_err=rffi.RFFI_SAVE_ERRNO)

    @unwrap_spec(domain='text')
    def bindtextdomain(space, domain, w_dir):
        """bindtextdomain(domain, dir) -> string
        Bind the C library's domain to dir."""

        if space.is_w(w_dir, space.w_None):
            dir = None
            domain_c = rffi.str2charp(domain)
            try:
                dirname = _bindtextdomain(domain_c, dir)
            finally:
                rffi.free_charp(domain_c)
        else:
            dir = space.text_w(w_dir)
            domain_c = rffi.str2charp(domain)
            dir_c = rffi.str2charp(dir)
            try:
                dirname = _bindtextdomain(domain_c, dir_c)
            finally:
                rffi.free_charp(domain_c)
                rffi.free_charp(dir_c)

        if not dirname:
            errno = rposix.get_saved_errno()
            raise OperationError(space.w_OSError, space.newint(errno))
        return space.newtext(rffi.charp2str(dirname))

    _bind_textdomain_codeset = rlocale.external('bind_textdomain_codeset',
                                    [rffi.CCHARP, rffi.CCHARP], rffi.CCHARP)

    if rlocale.HAVE_BIND_TEXTDOMAIN_CODESET:
        @unwrap_spec(domain='text')
        def bind_textdomain_codeset(space, domain, w_codeset):
            """bind_textdomain_codeset(domain, codeset) -> string
            Bind the C library's domain to codeset."""

            if space.is_w(w_codeset, space.w_None):
                codeset = None
                domain_c = rffi.str2charp(domain)
                try:
                    result = _bind_textdomain_codeset(domain_c, codeset)
                finally:
                    rffi.free_charp(domain_c)
            else:
                codeset = space.text_w(w_codeset)
                domain_c = rffi.str2charp(domain)
                codeset_c = rffi.str2charp(codeset)
                try:
                    result = _bind_textdomain_codeset(domain_c, codeset_c)
                finally:
                    rffi.free_charp(domain_c)
                    rffi.free_charp(codeset_c)

            if not result:
                return space.w_None
            else:
                return space.newtext(rffi.charp2str(result))

if sys.platform == 'win32':
    def getdefaultlocale(space):
        language, encoding = rlocale.getdefaultlocale()
        return space.newtuple([space.newtext(language), space.newtext(encoding)])
