
""" The rpython-level part of locale module
"""

import sys

from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rtyper.tool import rffi_platform as platform
from rpython.rtyper.extfunc import register_external

class LocaleError(Exception):
    def __init__(self, message):
        self.message = message

HAVE_LANGINFO = sys.platform != 'win32'
HAVE_LIBINTL  = sys.platform != 'win32'
libraries = []

if HAVE_LIBINTL:
    try:
        platform.verify_eci(ExternalCompilationInfo(includes=['libintl.h'],
                                                    libraries=['intl']))
        libraries.append('intl')
    except platform.CompilationError:
        try:
            platform.verify_eci(ExternalCompilationInfo(includes=['libintl.h']))
        except platform.CompilationError:
            HAVE_LIBINTL = False

class CConfig:
    includes = ['locale.h', 'limits.h', 'ctype.h', 'wchar.h']
    libraries = libraries

    if HAVE_LANGINFO:
        includes += ['langinfo.h']
    if HAVE_LIBINTL:
        includes += ['libintl.h']
    if sys.platform == 'win32':
        includes += ['windows.h']
    _compilation_info_ = ExternalCompilationInfo(
        includes=includes, libraries=libraries
    )
    HAVE_BIND_TEXTDOMAIN_CODESET = platform.Has('bind_textdomain_codeset')
    lconv = platform.Struct("struct lconv", [
            # Numeric (non-monetary) information.
            ("decimal_point", rffi.CCHARP),    # Decimal point character.
            ("thousands_sep", rffi.CCHARP),    # Thousands separator.

            ## Each element is the number of digits in each group;
            ## elements with higher indices are farther left.
            ## An element with value CHAR_MAX means that no further grouping is done.
            ## An element with value 0 means that the previous element is used
            ## for all groups farther left.  */
            ("grouping", rffi.CCHARP),

            ## Monetary information.

            ## First three chars are a currency symbol from ISO 4217.
            ## Fourth char is the separator.  Fifth char is '\0'.
            ("int_curr_symbol", rffi.CCHARP),
            ("currency_symbol", rffi.CCHARP),   # Local currency symbol.
            ("mon_decimal_point", rffi.CCHARP), # Decimal point character.
            ("mon_thousands_sep", rffi.CCHARP), # Thousands separator.
            ("mon_grouping", rffi.CCHARP),      # Like `grouping' element (above).
            ("positive_sign", rffi.CCHARP),     # Sign for positive values.
            ("negative_sign", rffi.CCHARP),     # Sign for negative values.
            ("int_frac_digits", rffi.UCHAR),    # Int'l fractional digits.

            ("frac_digits", rffi.UCHAR),        # Local fractional digits.
            ## 1 if currency_symbol precedes a positive value, 0 if succeeds.
            ("p_cs_precedes", rffi.UCHAR),
            ## 1 iff a space separates currency_symbol from a positive value.
            ("p_sep_by_space", rffi.UCHAR),
            ## 1 if currency_symbol precedes a negative value, 0 if succeeds.
            ("n_cs_precedes", rffi.UCHAR),
            ## 1 iff a space separates currency_symbol from a negative value.
            ("n_sep_by_space", rffi.UCHAR),

            ## Positive and negative sign positions:
            ## 0 Parentheses surround the quantity and currency_symbol.
            ## 1 The sign string precedes the quantity and currency_symbol.
            ## 2 The sign string follows the quantity and currency_symbol.
            ## 3 The sign string immediately precedes the currency_symbol.
            ## 4 The sign string immediately follows the currency_symbol.
            ("p_sign_posn", rffi.UCHAR),
            ("n_sign_posn", rffi.UCHAR),
            ])


constants = {}
constant_names = (
        'LC_CTYPE',
        'LC_NUMERIC',
        'LC_TIME',
        'LC_COLLATE',
        'LC_MONETARY',
        'LC_MESSAGES',
        'LC_ALL',
        'LC_PAPER',
        'LC_NAME',
        'LC_ADDRESS',
        'LC_TELEPHONE',
        'LC_MEASUREMENT',
        'LC_IDENTIFICATION',
        'LC_MIN',
        'LC_MAX',
        # from limits.h
        'CHAR_MAX',
        )

for name in constant_names:
    setattr(CConfig, name, platform.DefinedConstantInteger(name))

langinfo_names = []
if HAVE_LANGINFO:
    # some of these consts have an additional #ifdef directives
    # should we support them?
    langinfo_names.extend('RADIXCHAR THOUSEP CRNCYSTR D_T_FMT D_FMT T_FMT '
                        'AM_STR PM_STR CODESET T_FMT_AMPM ERA ERA_D_FMT '
                        'ERA_D_T_FMT ERA_T_FMT ALT_DIGITS YESEXPR NOEXPR '
                        '_DATE_FMT'.split())
    for i in range(1, 8):
        langinfo_names.append("DAY_%d" % i)
        langinfo_names.append("ABDAY_%d" % i)
    for i in range(1, 13):
        langinfo_names.append("MON_%d" % i)
        langinfo_names.append("ABMON_%d" % i)

if sys.platform == 'win32':
    langinfo_names.extend('LOCALE_USER_DEFAULT LOCALE_SISO639LANGNAME '
                      'LOCALE_SISO3166CTRYNAME LOCALE_IDEFAULTLANGUAGE '
                      ''.split())


for name in langinfo_names:
    setattr(CConfig, name, platform.DefinedConstantInteger(name))

class cConfig(object):
    pass

for k, v in platform.configure(CConfig).items():
    setattr(cConfig, k, v)

# needed to export the constants inside and outside. see __init__.py
for name in constant_names:
    value = getattr(cConfig, name)
    if value is not None:
        constants[name] = value

for name in langinfo_names:
    value = getattr(cConfig, name)
    if value is not None and sys.platform != 'win32':
        constants[name] = value

locals().update(constants)

HAVE_BIND_TEXTDOMAIN_CODESET = cConfig.HAVE_BIND_TEXTDOMAIN_CODESET

def external(name, args, result, calling_conv='c', **kwds):
    return rffi.llexternal(name, args, result,
                           compilation_info=CConfig._compilation_info_,
                           calling_conv=calling_conv,
                           sandboxsafe=True, **kwds)

_lconv = lltype.Ptr(cConfig.lconv)
localeconv = external('localeconv', [], _lconv)

def numeric_formatting():
    """Specialized function to get formatting for numbers"""
    return numeric_formatting_impl()

def numeric_formatting_impl():
    conv = localeconv()
    decimal_point = rffi.charp2str(conv.c_decimal_point)
    thousands_sep = rffi.charp2str(conv.c_thousands_sep)
    grouping = rffi.charp2str(conv.c_grouping)
    return decimal_point, thousands_sep, grouping

register_external(numeric_formatting, [], (str, str, str),
                  llimpl=numeric_formatting_impl,
                  sandboxsafe=True)


_setlocale = external('setlocale', [rffi.INT, rffi.CCHARP], rffi.CCHARP)

def setlocale(category, locale):
    if cConfig.LC_MAX is not None:
        if not cConfig.LC_MIN <= category <= cConfig.LC_MAX:
            raise LocaleError("invalid locale category")
    ll_result = _setlocale(rffi.cast(rffi.INT, category), locale)
    if not ll_result:
        raise LocaleError("unsupported locale setting")
    return rffi.charp2str(ll_result)

isalpha = external('isalpha', [rffi.INT], rffi.INT)
isupper = external('isupper', [rffi.INT], rffi.INT)
toupper = external('toupper', [rffi.INT], rffi.INT)
islower = external('islower', [rffi.INT], rffi.INT)
tolower = external('tolower', [rffi.INT], rffi.INT)
isalnum = external('isalnum', [rffi.INT], rffi.INT)

if HAVE_LANGINFO:
    _nl_langinfo = external('nl_langinfo', [rffi.INT], rffi.CCHARP)

    def nl_langinfo(key):
        if key in constants.values():
            return rffi.charp2str(_nl_langinfo(rffi.cast(rffi.INT, key)))
        raise ValueError

#___________________________________________________________________
# getdefaultlocale() implementation for Windows

if sys.platform == 'win32':
    from rpython.rlib import rwin32
    LCID = LCTYPE = rwin32.DWORD
    GetACP = external('GetACP',
                      [], rffi.INT,
                      calling_conv='win')
    GetLocaleInfo = external('GetLocaleInfoA',
                             [LCID, LCTYPE, rwin32.LPSTR, rffi.INT], rffi.INT,
                             calling_conv='win')

    def getdefaultlocale():
        encoding = "cp%d" % GetACP()

        BUFSIZE = 50
        buf_lang = lltype.malloc(rffi.CCHARP.TO, BUFSIZE, flavor='raw')
        buf_country = lltype.malloc(rffi.CCHARP.TO, BUFSIZE, flavor='raw')

        try:
            if (GetLocaleInfo(cConfig.LOCALE_USER_DEFAULT,
                              cConfig.LOCALE_SISO639LANGNAME,
                              buf_lang, BUFSIZE) and
                GetLocaleInfo(cConfig.LOCALE_USER_DEFAULT,
                              cConfig.LOCALE_SISO3166CTRYNAME,
                              buf_country, BUFSIZE)):
                lang = rffi.charp2str(buf_lang)
                country = rffi.charp2str(buf_country)
                language = "%s_%s" % (lang, country)

            # If we end up here, this windows version didn't know about
            # ISO639/ISO3166 names (it's probably Windows 95).  Return the
            # Windows language identifier instead (a hexadecimal number)
            elif GetLocaleInfo(cConfig.LOCALE_USER_DEFAULT,
                               cConfig.LOCALE_IDEFAULTLANGUAGE,
                               buf_lang, BUFSIZE):
                lang = rffi.charp2str(buf_lang)
                language = "0x%s" % (lang,)

            else:
                language = None
        finally:
            lltype.free(buf_lang, flavor='raw')
            lltype.free(buf_country, flavor='raw')

        return language, encoding
