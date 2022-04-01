import pytest

import sys

class AppTestLocaleTrivia:
    spaceconfig = dict(usemodules=['_locale', 'unicodedata'])

    def setup_class(cls):
        if sys.platform != 'win32':
            cls.w_language_en = cls.space.wrap("C")
            cls.w_language_utf8 = cls.space.wrap("en_US.utf8")
            cls.w_language_pl = cls.space.wrap("pl_PL.utf8")
            cls.w_encoding_pl = cls.space.wrap("utf-8")
        else:
            cls.w_language_en = cls.space.wrap("English_US")
            cls.w_language_utf8 = cls.space.wrap("English_US.65001")
            cls.w_language_pl = cls.space.wrap("Polish_Poland.1257")
            cls.w_encoding_pl = cls.space.wrap("cp1257")
        import _locale
        # check whether used locales are installed, otherwise the tests will
        # fail
        current = _locale.setlocale(_locale.LC_ALL)
        cls.oldlocale = current
        try:
            try:
                # some systems are only UTF-8 oriented
                try:
                    _locale.setlocale(_locale.LC_ALL,
                                      cls.space.utf8_w(cls.w_language_en))
                except _locale.Error:
                    _locale.setlocale(_locale.LC_ALL,
                                      cls.space.utf8_w(cls.w_language_utf8))
                    cls.w_language_en = cls.w_language_utf8

                _locale.setlocale(_locale.LC_ALL,
                                  cls.space.utf8_w(cls.w_language_pl))
            except _locale.Error:
                pytest.skip("necessary locales not installed")

            # Windows forbids the UTF-8 character set since Windows XP.
            try:
                _locale.setlocale(_locale.LC_ALL,
                                  cls.space.utf8_w(cls.w_language_utf8))
            except _locale.Error:
                del cls.w_language_utf8
        finally:
            _locale.setlocale(_locale.LC_ALL, current)

    def teardown_class(cls):
        import _locale
        _locale.setlocale(_locale.LC_ALL, cls.oldlocale)



    def test_import(self):
        import _locale
        assert _locale

        import locale
        assert locale

    def test_constants(self):
        import sys

        _CONSTANTS = (
            'LC_CTYPE',
            'LC_NUMERIC',
            'LC_TIME',
            'LC_COLLATE',
            'LC_MONETARY',
            'LC_ALL',
            'CHAR_MAX',

            # These are optional
            #'LC_MESSAGES',
            #'LC_PAPER',
            #'LC_NAME',
            #'LC_ADDRESS',
            #'LC_TELEPHONE',
            #'LC_MEASUREMENT',
            #'LC_IDENTIFICATION',
        )

        import _locale

        for constant in _CONSTANTS:
            assert hasattr(_locale, constant)


        # HAVE_LANGINFO
        if sys.platform != 'win32':
            _LANGINFO_NAMES = ('RADIXCHAR THOUSEP CRNCYSTR D_T_FMT D_FMT '
                        'T_FMT AM_STR PM_STR CODESET T_FMT_AMPM ERA ERA_D_FMT '
                        'ERA_D_T_FMT ERA_T_FMT ALT_DIGITS YESEXPR NOEXPR '
                        '_DATE_FMT').split()
            for i in range(1, 8):
                _LANGINFO_NAMES.append("DAY_%d" % i)
                _LANGINFO_NAMES.append("ABDAY_%d" % i)
            for i in range(1, 13):
                _LANGINFO_NAMES.append("MON_%d" % i)
                _LANGINFO_NAMES.append("ABMON_%d" % i)

            for constant in _LANGINFO_NAMES:
                assert hasattr(_locale, constant)

    def test_setlocale(self):
        import _locale

        raises(TypeError, _locale.setlocale, "", self.language_en)
        raises(TypeError, _locale.setlocale, _locale.LC_ALL, 6)
        raises(_locale.Error, _locale.setlocale, 123456, self.language_en)

        assert _locale.setlocale(_locale.LC_ALL, None)
        assert _locale.setlocale(_locale.LC_ALL)

    def test_localeconv(self):
        import _locale

        lconv_c = {
            "currency_symbol": "",
            "decimal_point": ".",
            "frac_digits": _locale.CHAR_MAX,
            "grouping": [],
            "int_curr_symbol": "",
            "int_frac_digits": _locale.CHAR_MAX,
            "mon_decimal_point": "",
            "mon_grouping": [],
            "mon_thousands_sep": "",
            "n_cs_precedes": _locale.CHAR_MAX,
            "n_sep_by_space": _locale.CHAR_MAX,
            "n_sign_posn": _locale.CHAR_MAX,
            "negative_sign": "",
            "p_cs_precedes": _locale.CHAR_MAX,
            "p_sep_by_space": _locale.CHAR_MAX,
            "p_sign_posn": _locale.CHAR_MAX,
            "positive_sign": "",
            "thousands_sep": "" }

        _locale.setlocale(_locale.LC_ALL, "C")

        lconv = _locale.localeconv()
        for k, v in lconv_c.items():
            assert lconv[k] == v

    def test_strcoll(self):
        import _locale

        _locale.setlocale(_locale.LC_ALL, self.language_pl)
        assert _locale.strcoll("a", "b") < 0
        assert _locale.strcoll(
            "\N{LATIN SMALL LETTER A WITH OGONEK}",
            "b") < 0

        assert _locale.strcoll(
            "\N{LATIN SMALL LETTER C WITH ACUTE}",
            "b") > 0
        assert _locale.strcoll("c", "b") > 0

        assert _locale.strcoll("b", "b") == 0

        raises(TypeError, _locale.strcoll, 1, "b")
        raises(TypeError, _locale.strcoll, "b", 1)

    def test_strxfrm(self):
        # TODO more tests would be nice
        import _locale

        _locale.setlocale(_locale.LC_ALL, "C")
        a = "1234"
        b = _locale.strxfrm(a)
        assert a is not b
        assert a == b

        with raises(TypeError):
            _locale.strxfrm(1)
        with raises(ValueError):
            _locale.strxfrm("a\x00b")

        _locale.setlocale(_locale.LC_ALL, self.language_pl)
        a = "1234"
        b = _locale.strxfrm(a)
        assert a is not b

    def test_str_float(self):
        import _locale
        import locale

        _locale.setlocale(_locale.LC_ALL, self.language_en)
        assert locale.str(1.1) == '1.1'
        _locale.setlocale(_locale.LC_ALL, self.language_pl)
        assert locale.str(1.1) == '1,1'

    def test_text(self):
        import sys
        if sys.platform == 'win32':
            skip("No gettext on Windows")

        # TODO more tests would be nice
        import _locale

        assert _locale.gettext("1234") == "1234"
        assert _locale.dgettext(None, "1234") == "1234"
        assert _locale.dcgettext(None, "1234", _locale.LC_MESSAGES) == "1234"
        assert _locale.textdomain("1234") == "1234"

    def test_nl_langinfo(self):
        import sys
        if sys.platform == 'win32':
            skip("No langinfo on Windows")

        import _locale

        langinfo_consts = [
                            'ABDAY_1',
                            'ABDAY_2',
                            'ABDAY_3',
                            'ABDAY_4',
                            'ABDAY_5',
                            'ABDAY_6',
                            'ABDAY_7',
                            'ABMON_1',
                            'ABMON_10',
                            'ABMON_11',
                            'ABMON_12',
                            'ABMON_2',
                            'ABMON_3',
                            'ABMON_4',
                            'ABMON_5',
                            'ABMON_6',
                            'ABMON_7',
                            'ABMON_8',
                            'ABMON_9',
                            'CODESET',
                            'CRNCYSTR',
                            'DAY_1',
                            'DAY_2',
                            'DAY_3',
                            'DAY_4',
                            'DAY_5',
                            'DAY_6',
                            'DAY_7',
                            'D_FMT',
                            'D_T_FMT',
                            'MON_1',
                            'MON_10',
                            'MON_11',
                            'MON_12',
                            'MON_2',
                            'MON_3',
                            'MON_4',
                            'MON_5',
                            'MON_6',
                            'MON_7',
                            'MON_8',
                            'MON_9',
                            'NOEXPR',
                            'RADIXCHAR',
                            'THOUSEP',
                            'T_FMT',
                            'YESEXPR',
                            'AM_STR',
                            'PM_STR',
                            ]
        for constant in langinfo_consts:
            assert hasattr(_locale, constant)

        _locale.setlocale(_locale.LC_ALL, "C")
        assert _locale.nl_langinfo(_locale.ABDAY_1) == "Sun"
        assert _locale.nl_langinfo(_locale.ABMON_1) == "Jan"
        assert _locale.nl_langinfo(_locale.T_FMT) == "%H:%M:%S"
        assert _locale.nl_langinfo(_locale.YESEXPR) == '^[yY]'
        assert _locale.nl_langinfo(_locale.NOEXPR) == "^[nN]"
        assert _locale.nl_langinfo(_locale.THOUSEP) == ''

        raises(ValueError, _locale.nl_langinfo, 12345)
        raises(TypeError, _locale.nl_langinfo, None)

    def test_bindtextdomain(self):
        import sys
        if sys.platform == 'win32':
            skip("No textdomain on Windows")

        # TODO more tests would be nice
        import _locale

        raises(OSError, _locale.bindtextdomain, '', '')
        raises(OSError, _locale.bindtextdomain, '', '1')

    def test_bind_textdomain_codeset(self):
        import sys
        if sys.platform == 'win32':
            skip("No textdomain on Windows")

        import _locale

        assert _locale.bind_textdomain_codeset('/', None) is None
        assert _locale.bind_textdomain_codeset('/', 'UTF-8') == 'UTF-8'
        assert _locale.bind_textdomain_codeset('/', None) == 'UTF-8'

        assert _locale.bind_textdomain_codeset('', '') is None

    def test_getdefaultlocale(self):
        import sys
        if sys.platform != 'win32':
            skip("No _getdefaultlocale() to test")

        import _locale
        lang, encoding = _locale._getdefaultlocale()
        assert lang is None or isinstance(lang, str)
        assert encoding.startswith('cp')

    def test_lc_numeric_basic(self):
        import _locale, sys
        if sys.platform == 'win32':
            skip("No nl_langinfo to test")
        from _locale import (setlocale, nl_langinfo, Error, LC_NUMERIC,
                             LC_CTYPE, RADIXCHAR, THOUSEP, localeconv)
        # Test nl_langinfo against localeconv
        candidate_locales = ['es_UY', 'fr_FR', 'fi_FI', 'es_CO', 'pt_PT', 'it_IT',
            'et_EE', 'es_PY', 'no_NO', 'nl_NL', 'lv_LV', 'el_GR', 'be_BY', 'fr_BE',
            'ro_RO', 'ru_UA', 'ru_RU', 'es_VE', 'ca_ES', 'se_NO', 'es_EC', 'id_ID',
            'ka_GE', 'es_CL', 'wa_BE', 'hu_HU', 'lt_LT', 'sl_SI', 'hr_HR', 'es_AR',
            'es_ES', 'oc_FR', 'gl_ES', 'bg_BG', 'is_IS', 'mk_MK', 'de_AT', 'pt_BR',
            'da_DK', 'nn_NO', 'cs_CZ', 'de_LU', 'es_BO', 'sq_AL', 'sk_SK', 'fr_CH',
            'de_DE', 'sr_YU', 'br_FR', 'nl_BE', 'sv_FI', 'pl_PL', 'fr_CA', 'fo_FO',
            'bs_BA', 'fr_LU', 'kl_GL', 'fa_IR', 'de_BE', 'sv_SE', 'it_CH', 'uk_UA',
            'eu_ES', 'vi_VN', 'af_ZA', 'nb_NO', 'en_DK', 'tg_TJ', 'ps_AF', 'en_US',
            'fr_FR.ISO8859-1', 'fr_FR.UTF-8', 'fr_FR.ISO8859-15@euro',
            'ru_RU.KOI8-R', 'ko_KR.eucKR']

        tested = False
        for loc in candidate_locales:
            try:
                setlocale(LC_NUMERIC, loc)
                setlocale(LC_CTYPE, loc)
            except Error:
                continue
            for li, lc in ((RADIXCHAR, "decimal_point"),
                            (THOUSEP, "thousands_sep")):
                nl_radixchar = nl_langinfo(li)
                li_radixchar = localeconv()[lc]
                try:
                    set_locale = setlocale(LC_NUMERIC)
                except Error:
                    set_locale = "<not able to determine>"
                assert nl_radixchar == li_radixchar, ("nl_langinfo != localeconv "
                                "(set to %s, using %s)" % ( loc, set_locale))
