import py
import sys

class AppTestUnicodeData:
    spaceconfig = dict(usemodules=('unicodedata',))

    def test_hangul_syllables(self):
        import unicodedata
        # Test all leading, vowel and trailing jamo
        # but not every combination of them.
        for code, name in ((0xAC00, 'HANGUL SYLLABLE GA'),
                           (0xAE69, 'HANGUL SYLLABLE GGAEG'),
                           (0xB0D2, 'HANGUL SYLLABLE NYAGG'),
                           (0xB33B, 'HANGUL SYLLABLE DYAEGS'),
                           (0xB5A4, 'HANGUL SYLLABLE DDEON'),
                           (0xB80D, 'HANGUL SYLLABLE RENJ'),
                           (0xBA76, 'HANGUL SYLLABLE MYEONH'),
                           (0xBCDF, 'HANGUL SYLLABLE BYED'),
                           (0xBF48, 'HANGUL SYLLABLE BBOL'),
                           (0xC1B1, 'HANGUL SYLLABLE SWALG'),
                           (0xC41A, 'HANGUL SYLLABLE SSWAELM'),
                           (0xC683, 'HANGUL SYLLABLE OELB'),
                           (0xC8EC, 'HANGUL SYLLABLE JYOLS'),
                           (0xCB55, 'HANGUL SYLLABLE JJULT'),
                           (0xCDBE, 'HANGUL SYLLABLE CWEOLP'),
                           (0xD027, 'HANGUL SYLLABLE KWELH'),
                           (0xD290, 'HANGUL SYLLABLE TWIM'),
                           (0xD4F9, 'HANGUL SYLLABLE PYUB'),
                           (0xD762, 'HANGUL SYLLABLE HEUBS'),
                           (0xAE27, 'HANGUL SYLLABLE GYIS'),
                           (0xB090, 'HANGUL SYLLABLE GGISS'),
                           (0xB0AD, 'HANGUL SYLLABLE NANG'),
                           (0xB316, 'HANGUL SYLLABLE DAEJ'),
                           (0xB57F, 'HANGUL SYLLABLE DDYAC'),
                           (0xB7E8, 'HANGUL SYLLABLE RYAEK'),
                           (0xBA51, 'HANGUL SYLLABLE MEOT'),
                           (0xBCBA, 'HANGUL SYLLABLE BEP'),
                           (0xBF23, 'HANGUL SYLLABLE BBYEOH'),
                           (0xD7A3, 'HANGUL SYLLABLE HIH')):
            assert unicodedata.name(chr(code)) == name
            assert unicodedata.lookup(name) == chr(code)
        # Test outside the range
        raises(ValueError, unicodedata.name, chr(0xAC00 - 1))
        raises(ValueError, unicodedata.name, chr(0xD7A3 + 1))

    def test_cjk(self):
        import sys
        import unicodedata
        assert int(unicodedata.unidata_version.split(".")[0]) >= 8
        cases = [
            ('3400', '4DB5'),
            ('4E00', '9FFC'),
            ('20000', '2A6D6'),
            ('2A700', '2B734'),
            ('2B740', '2CEA1'),
            ('2CEB0', '2EBE0'),
        ]
        for first, last in cases:
            first = int(first, 16)
            last = int(last, 16)
            # Test at and inside the boundary
            for i in (first, first + 1, last - 1, last):
                charname = 'CJK UNIFIED IDEOGRAPH-%X'%i
                char = chr(i)
                assert unicodedata.name(char) == charname
                assert unicodedata.lookup(charname) == char
            # Test outside the boundary
            for i in first - 1, last + 1:
                charname = 'CJK UNIFIED IDEOGRAPH-%X'%i
                char = chr(i)
                try:
                    unicodedata.name(char)
                except ValueError as e:
                    assert str(e) == 'no such name'
                raises(KeyError, unicodedata.lookup, charname)

    def test_bug_1704793(self): # from CPython
        import unicodedata
        assert unicodedata.lookup("GOTHIC LETTER FAIHU") == '\U00010346'

    def test_normalize_bad_argcount(self):
        import unicodedata
        raises(TypeError, unicodedata.normalize, 'x')

    def test_normalize_nonunicode(self):
        import unicodedata
        exc_info = raises(TypeError, unicodedata.normalize, 'NFC', b'x')
        assert 'must be unicode, not' in str(exc_info.value)

    @py.test.mark.skipif("sys.maxunicode < 0x10ffff")
    def test_normalize_wide(self):
        import unicodedata
        assert unicodedata.normalize('NFC', '\U000110a5\U000110ba') == '\U000110ab'

    def test_is_normalized(self):
        import unicodedata
        assert unicodedata.is_normalized("NFC", '\U000110ab')
        assert not unicodedata.is_normalized("NFC", '\U000110a5\U000110ba')

    def test_linebreaks(self):
        linebreaks = (0x0a, 0x0b, 0x0c, 0x0d, 0x85,
                      0x1c, 0x1d, 0x1e, 0x2028, 0x2029)
        for i in linebreaks:
            for j in range(-2, 3):
                lines = (chr(i + j) + 'A').splitlines()
                if i + j in linebreaks:
                    assert len(lines) == 2
                else:
                    assert len(lines) == 1

    def test_mirrored(self):
        import unicodedata
        # For no reason, unicodedata.mirrored() returns an int, not a bool
        assert repr(unicodedata.mirrored(' ')) == '0'

    def test_bidirectional_not_one_character(self):
        import unicodedata
        exc_info = raises(TypeError, unicodedata.bidirectional, u'xx')
        assert str(exc_info.value) == 'need a single Unicode character as parameter'

    def test_aliases(self):
        import unicodedata
        aliases = [
            ('LATIN CAPITAL LETTER GHA', 0x01A2),
            ('LATIN SMALL LETTER GHA', 0x01A3),
            ('KANNADA LETTER LLLA', 0x0CDE),
            ('LAO LETTER FO FON', 0x0E9D),
            ('LAO LETTER FO FAY', 0x0E9F),
            ('LAO LETTER RO', 0x0EA3),
            ('LAO LETTER LO', 0x0EA5),
            ('TIBETAN MARK BKA- SHOG GI MGO RGYAN', 0x0FD0),
            ('YI SYLLABLE ITERATION MARK', 0xA015),
            ('PRESENTATION FORM FOR VERTICAL RIGHT WHITE LENTICULAR BRACKET', 0xFE18),
            ('BYZANTINE MUSICAL SYMBOL FTHORA SKLIRON CHROMA VASIS', 0x1D0C5)
        ]
        for alias, codepoint in aliases:
            name = unicodedata.name(chr(codepoint))
            assert name != alias
            assert unicodedata.lookup(alias) == unicodedata.lookup(name)
            raises(KeyError, unicodedata.ucd_3_2_0.lookup, alias)

    def test_named_sequences(self):
        import unicodedata
        sequences = [
            ('LATIN SMALL LETTER R WITH TILDE', '\u0072\u0303'),
            ('TAMIL SYLLABLE SAI', '\u0BB8\u0BC8'),
            ('TAMIL SYLLABLE MOO', '\u0BAE\u0BCB'),
            ('TAMIL SYLLABLE NNOO', '\u0BA3\u0BCB'),
            ('TAMIL CONSONANT KSS', '\u0B95\u0BCD\u0BB7\u0BCD'),
        ]
        for seqname, codepoints in sequences:
            assert unicodedata.lookup(seqname) == codepoints
            raises(SyntaxError, eval, r'"\N{%s}"' % seqname)

    def test_names_in_pua_range(self):
        # We are storing named seq in the PUA 15, but their names shouldn't leak
        import unicodedata
        for cp in range(0xf0000, 0xf0300, 7):
            exc = raises(ValueError, unicodedata.name, chr(cp))
            assert str(exc.value) == 'no such name'

    def test_east_asian_width_9_0_changes(self):
        import unicodedata
        assert unicodedata.ucd_3_2_0.east_asian_width('\u231a') == 'N'
        assert unicodedata.east_asian_width('\u231a') == 'W'

    def test_11_change(self):
        import unicodedata
        assert unicodedata.name(chr(0x1f9b9)) == "SUPERVILLAIN"

    def test_12_1_change(self):
        import unicodedata
        assert unicodedata.name(chr(0x32ff)) == 'SQUARE ERA NAME REIWA'

    def test_13_0_change(self):
        import unicodedata
        assert unicodedata.lookup('CIRCLED CC')
