const std = @import("std");
const windows1252 = @import("windows1252.zig");

// TODO: Parts of this comment block may be more relevant to string/NameOrOrdinal parsing
//       than it is to the stuff in this file.
//
// ‰ representations for context:
// Win-1252   89
// UTF-8      E2 80 B0
// UTF-16     20 30
//
// With code page 65001:
//  ‰ RCDATA { "‰" L"‰" }
// File encoded as Windows-1252:
//  ‰ => <U+FFFD REPLACEMENT CHARACTER> as u16
//  "‰" => 0x3F ('?')
//  L"‰" => <U+FFFD REPLACEMENT CHARACTER> as u16
// File encoded as UTF-8:
//  ‰ => <U+2030 ‰> as u16
//  "‰" => 0x89 ('‰' encoded as Windows-1252)
//  L"‰" => <U+2030 ‰> as u16
//
// With code page 1252:
//  ‰ RCDATA { "‰" L"‰" }
// File encoded as Windows-1252:
//  ‰ => <U+2030 ‰> as u16
//  "‰" => 0x89 ('‰' encoded as Windows-1252)
//  L"‰" => <U+2030 ‰> as u16
// File encoded as UTF-8:
//  ‰ => 0xE2 as u16, 0x20AC as u16, 0xB0 as u16
//       ^ first byte of utf8 representation
//                    ^ second byte of UTF-8 representation (0x80), but interpretted as
//                      Windows-1252 ('€') and then converted to UTF-16 (<U+20AC>)
//                                   ^ third byte of utf8 representation
//  "‰" => 0xE2, 0x80, 0xB0 (the bytes of the UTF-8 representation)
//  L"‰" => 0xE2 as u16, 0x20AC as u16, 0xB0 as u16 (see '‰ =>' explanation)
//
// With code page 1252:
//  <0x90> RCDATA { "<0x90>" L"<0x90>" }
// File encoded as Windows-1252:
//  <0x90> => 0x90 as u16
//  "<0x90>" => 0x90
//  L"<0x90>" => 0x90 as u16
// File encoded as UTF-8:
//  <0x90> => 0xC2 as u16, 0x90 as u16
//  "<0x90>" => 0xC2, 0x90 (the bytes of the UTF-8 representation of <U+0090>)
//  L"<0x90>" => 0xC2 as u16, 0x90 as u16
//
// Within a raw data block, file encoded as Windows-1252 (Â is <0xC2>):
//  "Âa" L"Âa" "\xC2ad" L"\xC2AD"
// With code page 1252:
//  C2 61 C2 00 61 00 C2 61 64 AD C2
//  Â^ a^ Â~~~^ a~~~^ .^ a^ d^ ^~~~~\xC2AD
//              \xC2~`
// With code page 65001:
//  3F 61 FD FF 61 00 C2 61 64 AD C2
//  ^. a^ ^~~~. a~~~^ ^. a^ d^ ^~~~~\xC2AD
//    `.       `.       `~\xC2
//      `.       `.~<0xC2>a is not well-formed UTF-8 (0xC2 expects a continutation byte after it).
//        `.        Because 'a' is a valid first byte of a UTF-8 sequence, it is not included in the
//          `.      invalid sequence so only the <0xC2> gets converted to <U+FFFD>.
//            `~Same as ^ but converted to '?' instead.
//
// Within a raw data block, file encoded as Windows-1252 (ð is <0xF0>, € is <0x80>):
//  "ð€a" L"ð€a"
// With code page 1252:
//  F0 80 61 F0 00 AC 20 61 00
//  ð^ €^ a^ ð~~~^ €~~~^ a~~~^
// With code page 65001:
//  3F 61 FD FF 61 00
//  ^. a^ ^~~~. a~~~^
//    `.       `.
//      `.       `.~<0xF0><0x80> is not well-formed UTF-8, and <0x80> is not a valid first byte, so
//        `.        both bytes are considered an invalid sequence and get converted to '<U+FFFD>'
//          `~Same as ^ but converted to '?' instead.

/// https://learn.microsoft.com/en-us/windows/win32/intl/code-page-identifiers
pub const CodePage = enum(u16) {
    // supported
    windows1252 = 1252, // windows-1252    ANSI Latin 1; Western European (Windows)
    utf8 = 65001, // utf-8    Unicode (UTF-8)

    // unsupported but valid
    ibm037 = 37, // IBM037    IBM EBCDIC US-Canada
    ibm437 = 437, // IBM437    OEM United States
    ibm500 = 500, // IBM500    IBM EBCDIC International
    asmo708 = 708, // ASMO-708    Arabic (ASMO 708)
    asmo449plus = 709, // Arabic (ASMO-449+, BCON V4)
    transparent_arabic = 710, // Arabic - Transparent Arabic
    dos720 = 720, // DOS-720    Arabic (Transparent ASMO); Arabic (DOS)
    ibm737 = 737, // ibm737    OEM Greek (formerly 437G); Greek (DOS)
    ibm775 = 775, // ibm775    OEM Baltic; Baltic (DOS)
    ibm850 = 850, // ibm850    OEM Multilingual Latin 1; Western European (DOS)
    ibm852 = 852, // ibm852    OEM Latin 2; Central European (DOS)
    ibm855 = 855, // IBM855    OEM Cyrillic (primarily Russian)
    ibm857 = 857, // ibm857    OEM Turkish; Turkish (DOS)
    ibm00858 = 858, // IBM00858    OEM Multilingual Latin 1 + Euro symbol
    ibm860 = 860, // IBM860    OEM Portuguese; Portuguese (DOS)
    ibm861 = 861, // ibm861    OEM Icelandic; Icelandic (DOS)
    dos862 = 862, // DOS-862    OEM Hebrew; Hebrew (DOS)
    ibm863 = 863, // IBM863    OEM French Canadian; French Canadian (DOS)
    ibm864 = 864, // IBM864    OEM Arabic; Arabic (864)
    ibm865 = 865, // IBM865    OEM Nordic; Nordic (DOS)
    cp866 = 866, // cp866    OEM Russian; Cyrillic (DOS)
    ibm869 = 869, // ibm869    OEM Modern Greek; Greek, Modern (DOS)
    ibm870 = 870, // IBM870    IBM EBCDIC Multilingual/ROECE (Latin 2); IBM EBCDIC Multilingual Latin 2
    windows874 = 874, // windows-874    Thai (Windows)
    cp875 = 875, // cp875    IBM EBCDIC Greek Modern
    shift_jis = 932, // shift_jis    ANSI/OEM Japanese; Japanese (Shift-JIS)
    gb2312 = 936, // gb2312    ANSI/OEM Simplified Chinese (PRC, Singapore); Chinese Simplified (GB2312)
    ks_c_5601_1987 = 949, // ks_c_5601-1987    ANSI/OEM Korean (Unified Hangul Code)
    big5 = 950, // big5    ANSI/OEM Traditional Chinese (Taiwan; Hong Kong SAR, PRC); Chinese Traditional (Big5)
    ibm1026 = 1026, // IBM1026    IBM EBCDIC Turkish (Latin 5)
    ibm01047 = 1047, // IBM01047    IBM EBCDIC Latin 1/Open System
    ibm01140 = 1140, // IBM01140    IBM EBCDIC US-Canada (037 + Euro symbol); IBM EBCDIC (US-Canada-Euro)
    ibm01141 = 1141, // IBM01141    IBM EBCDIC Germany (20273 + Euro symbol); IBM EBCDIC (Germany-Euro)
    ibm01142 = 1142, // IBM01142    IBM EBCDIC Denmark-Norway (20277 + Euro symbol); IBM EBCDIC (Denmark-Norway-Euro)
    ibm01143 = 1143, // IBM01143    IBM EBCDIC Finland-Sweden (20278 + Euro symbol); IBM EBCDIC (Finland-Sweden-Euro)
    ibm01144 = 1144, // IBM01144    IBM EBCDIC Italy (20280 + Euro symbol); IBM EBCDIC (Italy-Euro)
    ibm01145 = 1145, // IBM01145    IBM EBCDIC Latin America-Spain (20284 + Euro symbol); IBM EBCDIC (Spain-Euro)
    ibm01146 = 1146, // IBM01146    IBM EBCDIC United Kingdom (20285 + Euro symbol); IBM EBCDIC (UK-Euro)
    ibm01147 = 1147, // IBM01147    IBM EBCDIC France (20297 + Euro symbol); IBM EBCDIC (France-Euro)
    ibm01148 = 1148, // IBM01148    IBM EBCDIC International (500 + Euro symbol); IBM EBCDIC (International-Euro)
    ibm01149 = 1149, // IBM01149    IBM EBCDIC Icelandic (20871 + Euro symbol); IBM EBCDIC (Icelandic-Euro)
    utf16 = 1200, // utf-16    Unicode UTF-16, little endian byte order (BMP of ISO 10646); available only to managed applications
    utf16_fffe = 1201, // unicodeFFFE    Unicode UTF-16, big endian byte order; available only to managed applications
    windows1250 = 1250, // windows-1250    ANSI Central European; Central European (Windows)
    windows1251 = 1251, // windows-1251    ANSI Cyrillic; Cyrillic (Windows)
    windows1253 = 1253, // windows-1253    ANSI Greek; Greek (Windows)
    windows1254 = 1254, // windows-1254    ANSI Turkish; Turkish (Windows)
    windows1255 = 1255, // windows-1255    ANSI Hebrew; Hebrew (Windows)
    windows1256 = 1256, // windows-1256    ANSI Arabic; Arabic (Windows)
    windows1257 = 1257, // windows-1257    ANSI Baltic; Baltic (Windows)
    windows1258 = 1258, // windows-1258    ANSI/OEM Vietnamese; Vietnamese (Windows)
    johab = 1361, // Johab    Korean (Johab)
    macintosh = 10000, // macintosh    MAC Roman; Western European (Mac)
    x_mac_japanese = 10001, // x-mac-japanese    Japanese (Mac)
    x_mac_chinesetrad = 10002, // x-mac-chinesetrad    MAC Traditional Chinese (Big5); Chinese Traditional (Mac)
    x_mac_korean = 10003, // x-mac-korean    Korean (Mac)
    x_mac_arabic = 10004, // x-mac-arabic    Arabic (Mac)
    x_mac_hebrew = 10005, // x-mac-hebrew    Hebrew (Mac)
    x_mac_greek = 10006, // x-mac-greek    Greek (Mac)
    x_mac_cyrillic = 10007, // x-mac-cyrillic    Cyrillic (Mac)
    x_mac_chinesesimp = 10008, // x-mac-chinesesimp    MAC Simplified Chinese (GB 2312); Chinese Simplified (Mac)
    x_mac_romanian = 10010, // x-mac-romanian    Romanian (Mac)
    x_mac_ukranian = 10017, // x-mac-ukrainian    Ukrainian (Mac)
    x_mac_thai = 10021, // x-mac-thai    Thai (Mac)
    x_mac_ce = 10029, // x-mac-ce    MAC Latin 2; Central European (Mac)
    x_mac_icelandic = 10079, // x-mac-icelandic    Icelandic (Mac)
    x_mac_turkish = 10081, // x-mac-turkish    Turkish (Mac)
    x_mac_croatian = 10082, // x-mac-croatian    Croatian (Mac)
    utf32 = 12000, // utf-32    Unicode UTF-32, little endian byte order; available only to managed applications
    utf32_be = 12001, // utf-32BE    Unicode UTF-32, big endian byte order; available only to managed applications
    x_chinese_cns = 20000, // x-Chinese_CNS    CNS Taiwan; Chinese Traditional (CNS)
    x_cp20001 = 20001, // x-cp20001    TCA Taiwan
    x_chinese_eten = 20002, // x_Chinese-Eten    Eten Taiwan; Chinese Traditional (Eten)
    x_cp20003 = 20003, // x-cp20003    IBM5550 Taiwan
    x_cp20004 = 20004, // x-cp20004    TeleText Taiwan
    x_cp20005 = 20005, // x-cp20005    Wang Taiwan
    x_ia5 = 20105, // x-IA5    IA5 (IRV International Alphabet No. 5, 7-bit); Western European (IA5)
    x_ia5_german = 20106, // x-IA5-German    IA5 German (7-bit)
    x_ia5_swedish = 20107, // x-IA5-Swedish    IA5 Swedish (7-bit)
    x_ia5_norwegian = 20108, // x-IA5-Norwegian    IA5 Norwegian (7-bit)
    us_ascii = 20127, // us-ascii    US-ASCII (7-bit)
    x_cp20261 = 20261, // x-cp20261    T.61
    x_cp20269 = 20269, // x-cp20269    ISO 6937 Non-Spacing Accent
    ibm273 = 20273, // IBM273    IBM EBCDIC Germany
    ibm277 = 20277, // IBM277    IBM EBCDIC Denmark-Norway
    ibm278 = 20278, // IBM278    IBM EBCDIC Finland-Sweden
    ibm280 = 20280, // IBM280    IBM EBCDIC Italy
    ibm284 = 20284, // IBM284    IBM EBCDIC Latin America-Spain
    ibm285 = 20285, // IBM285    IBM EBCDIC United Kingdom
    ibm290 = 20290, // IBM290    IBM EBCDIC Japanese Katakana Extended
    ibm297 = 20297, // IBM297    IBM EBCDIC France
    ibm420 = 20420, // IBM420    IBM EBCDIC Arabic
    ibm423 = 20423, // IBM423    IBM EBCDIC Greek
    ibm424 = 20424, // IBM424    IBM EBCDIC Hebrew
    x_ebcdic_korean_extended = 20833, // x-EBCDIC-KoreanExtended    IBM EBCDIC Korean Extended
    ibm_thai = 20838, // IBM-Thai    IBM EBCDIC Thai
    koi8_r = 20866, // koi8-r    Russian (KOI8-R); Cyrillic (KOI8-R)
    ibm871 = 20871, // IBM871    IBM EBCDIC Icelandic
    ibm880 = 20880, // IBM880    IBM EBCDIC Cyrillic Russian
    ibm905 = 20905, // IBM905    IBM EBCDIC Turkish
    ibm00924 = 20924, // IBM00924    IBM EBCDIC Latin 1/Open System (1047 + Euro symbol)
    euc_jp_jis = 20932, // EUC-JP    Japanese (JIS 0208-1990 and 0212-1990)
    x_cp20936 = 20936, // x-cp20936    Simplified Chinese (GB2312); Chinese Simplified (GB2312-80)
    x_cp20949 = 20949, // x-cp20949    Korean Wansung
    cp1025 = 21025, // cp1025    IBM EBCDIC Cyrillic Serbian-Bulgarian
    // = 21027, // (deprecated)
    koi8_u = 21866, // koi8-u    Ukrainian (KOI8-U); Cyrillic (KOI8-U)
    iso8859_1 = 28591, // iso-8859-1    ISO 8859-1 Latin 1; Western European (ISO)
    iso8859_2 = 28592, // iso-8859-2    ISO 8859-2 Central European; Central European (ISO)
    iso8859_3 = 28593, // iso-8859-3    ISO 8859-3 Latin 3
    iso8859_4 = 28594, // iso-8859-4    ISO 8859-4 Baltic
    iso8859_5 = 28595, // iso-8859-5    ISO 8859-5 Cyrillic
    iso8859_6 = 28596, // iso-8859-6    ISO 8859-6 Arabic
    iso8859_7 = 28597, // iso-8859-7    ISO 8859-7 Greek
    iso8859_8 = 28598, // iso-8859-8    ISO 8859-8 Hebrew; Hebrew (ISO-Visual)
    iso8859_9 = 28599, // iso-8859-9    ISO 8859-9 Turkish
    iso8859_13 = 28603, // iso-8859-13    ISO 8859-13 Estonian
    iso8859_15 = 28605, // iso-8859-15    ISO 8859-15 Latin 9
    x_europa = 29001, // x-Europa    Europa 3
    is8859_8_i = 38598, // iso-8859-8-i    ISO 8859-8 Hebrew; Hebrew (ISO-Logical)
    iso2022_jp = 50220, // iso-2022-jp    ISO 2022 Japanese with no halfwidth Katakana; Japanese (JIS)
    cs_iso2022_jp = 50221, // csISO2022JP    ISO 2022 Japanese with halfwidth Katakana; Japanese (JIS-Allow 1 byte Kana)
    iso2022_jp_jis_x = 50222, // iso-2022-jp    ISO 2022 Japanese JIS X 0201-1989; Japanese (JIS-Allow 1 byte Kana - SO/SI)
    iso2022_kr = 50225, // iso-2022-kr    ISO 2022 Korean
    x_cp50227 = 50227, // x-cp50227    ISO 2022 Simplified Chinese; Chinese Simplified (ISO 2022)
    iso2022_chinesetrad = 50229, // ISO 2022 Traditional Chinese
    ebcdic_jp_katakana_extended = 50930, // EBCDIC Japanese (Katakana) Extended
    ebcdic_us_ca_jp = 50931, // EBCDIC US-Canada and Japanese
    ebcdic_kr_extended = 50933, // EBCDIC Korean Extended and Korean
    ebcdic_chinesesimp_extended = 50935, // EBCDIC Simplified Chinese Extended and Simplified Chinese
    ebcdic_chinesesimp = 50936, // EBCDIC Simplified Chinese
    ebcdic_us_ca_chinesetrad = 50937, // EBCDIC US-Canada and Traditional Chinese
    ebcdic_jp_latin_extended = 50939, // EBCDIC Japanese (Latin) Extended and Japanese
    euc_jp = 51932, // euc-jp    EUC Japanese
    euc_cn = 51936, // EUC-CN    EUC Simplified Chinese; Chinese Simplified (EUC)
    euc_kr = 51949, // euc-kr    EUC Korean
    euc_chinesetrad = 51950, // EUC Traditional Chinese
    hz_gb2312 = 52936, // hz-gb-2312    HZ-GB2312 Simplified Chinese; Chinese Simplified (HZ)
    gb18030 = 54936, // GB18030    Windows XP and later: GB18030 Simplified Chinese (4 byte); Chinese Simplified (GB18030)
    x_iscii_de = 57002, // x-iscii-de    ISCII Devanagari
    x_iscii_be = 57003, // x-iscii-be    ISCII Bangla
    x_iscii_ta = 57004, // x-iscii-ta    ISCII Tamil
    x_iscii_te = 57005, // x-iscii-te    ISCII Telugu
    x_iscii_as = 57006, // x-iscii-as    ISCII Assamese
    x_iscii_or = 57007, // x-iscii-or    ISCII Odia
    x_iscii_ka = 57008, // x-iscii-ka    ISCII Kannada
    x_iscii_ma = 57009, // x-iscii-ma    ISCII Malayalam
    x_iscii_gu = 57010, // x-iscii-gu    ISCII Gujarati
    x_iscii_pa = 57011, // x-iscii-pa    ISCII Punjabi
    utf7 = 65000, // utf-7    Unicode (UTF-7)

    pub fn codepointAt(code_page: CodePage, index: usize, bytes: []const u8) ?Codepoint {
        if (index >= bytes.len) return null;
        switch (code_page) {
            .windows1252 => {
                // All byte values have a representation, so just convert the byte
                return Codepoint{
                    .value = windows1252.toCodepoint(bytes[index]),
                    .byte_len = 1,
                };
            },
            .utf8 => {
                return Utf8.WellFormedDecoder.decode(bytes[index..]);
            },
            else => unreachable,
        }
    }

    pub fn isSupported(code_page: CodePage) bool {
        return switch (code_page) {
            .windows1252, .utf8 => true,
            else => false,
        };
    }

    pub fn getByIdentifier(identifier: u16) !CodePage {
        // There's probably a more efficient way to do this (e.g. ComptimeHashMap?) but
        // this should be fine, especially since this function likely won't be called much.
        inline for (@typeInfo(CodePage).Enum.fields) |enumField| {
            if (identifier == enumField.value) {
                return @field(CodePage, enumField.name);
            }
        }
        return error.InvalidCodePage;
    }

    pub fn getByIdentifierEnsureSupported(identifier: u16) !CodePage {
        const code_page = try getByIdentifier(identifier);
        switch (isSupported(code_page)) {
            true => return code_page,
            false => return error.UnsupportedCodePage,
        }
    }
};

pub const Utf8 = struct {
    /// Implements decoding with rejection of ill-formed UTF-8 sequences based on section
    /// D92 of Chapter 3 of the Unicode standard (Table 3-7 specifically).
    ///
    /// Note: This does not match "U+FFFD Substitution of Maximal Subparts", but instead
    ///       matches the behavior of the Windows RC compiler.
    pub const WellFormedDecoder = struct {
        /// Like std.unicode.utf8ByteSequenceLength, but:
        /// - Rejects non-well-formed first bytes, i.e. C0-C1, F5-FF
        /// - Returns an optional value instead of an error union
        pub fn sequenceLength(first_byte: u8) ?u3 {
            return switch (first_byte) {
                0x00...0x7F => 1,
                0xC2...0xDF => 2,
                0xE0...0xEF => 3,
                0xF0...0xF4 => 4,
                else => null,
            };
        }

        fn isContinuationByte(byte: u8) bool {
            return switch (byte) {
                0x80...0xBF => true,
                else => false,
            };
        }

        pub fn decode(bytes: []const u8) Codepoint {
            std.debug.assert(bytes.len > 0);
            const first_byte = bytes[0];
            const expected_len = sequenceLength(first_byte) orelse {
                return .{ .value = Codepoint.invalid, .byte_len = 1 };
            };
            if (expected_len == 1) return .{ .value = first_byte, .byte_len = 1 };

            var value: u21 = first_byte & 0b00011111;
            var byte_index: u8 = 1;
            while (byte_index < @min(bytes.len, expected_len)) : (byte_index += 1) {
                const byte = bytes[byte_index];
                // See Table 3-7 of D92 in Chapter 3 of the Unicode Standard
                const valid: bool = switch (byte_index) {
                    1 => switch (first_byte) {
                        0xE0 => switch (byte) {
                            0xA0...0xBF => true,
                            else => false,
                        },
                        0xED => switch (byte) {
                            0x80...0x9F => true,
                            else => false,
                        },
                        0xF0 => switch (byte) {
                            0x90...0xBF => true,
                            else => false,
                        },
                        0xF4 => switch (byte) {
                            0x80...0x8F => true,
                            else => false,
                        },
                        else => switch (byte) {
                            0x80...0xBF => true,
                            else => false,
                        },
                    },
                    else => switch (byte) {
                        0x80...0xBF => true,
                        else => false,
                    },
                };

                if (!valid) {
                    var len = byte_index;
                    // Only include the byte in the invalid sequence if it's in the range
                    // of a continuation byte. All other values should not be included in the
                    // invalid sequence.
                    if (isContinuationByte(byte)) len += 1;
                    return .{ .value = Codepoint.invalid, .byte_len = len };
                }

                value <<= 6;
                value |= byte & 0b00111111;
            }
            if (byte_index != expected_len) {
                return .{ .value = Codepoint.invalid, .byte_len = byte_index };
            }
            return .{ .value = value, .byte_len = expected_len };
        }
    };
};

test "Utf8.WellFormedDecoder" {
    const invalid_utf8 = "\xF0\x80";
    const decoded = Utf8.WellFormedDecoder.decode(invalid_utf8);
    try std.testing.expectEqual(Codepoint.invalid, decoded.value);
    try std.testing.expectEqual(@as(usize, 2), decoded.byte_len);
}

test "codepointAt invalid utf8" {
    {
        const invalid_utf8 = "\xf0\xf0\x80\x80\x80";
        try std.testing.expectEqual(Codepoint{
            .value = Codepoint.invalid,
            .byte_len = 1,
        }, CodePage.utf8.codepointAt(0, invalid_utf8).?);
        try std.testing.expectEqual(Codepoint{
            .value = Codepoint.invalid,
            .byte_len = 2,
        }, CodePage.utf8.codepointAt(1, invalid_utf8).?);
        try std.testing.expectEqual(Codepoint{
            .value = Codepoint.invalid,
            .byte_len = 1,
        }, CodePage.utf8.codepointAt(3, invalid_utf8).?);
        try std.testing.expectEqual(Codepoint{
            .value = Codepoint.invalid,
            .byte_len = 1,
        }, CodePage.utf8.codepointAt(4, invalid_utf8).?);
        try std.testing.expectEqual(@as(?Codepoint, null), CodePage.windows1252.codepointAt(5, invalid_utf8));
    }

    {
        const invalid_utf8 = "\xE1\xA0\xC0";
        try std.testing.expectEqual(Codepoint{
            .value = Codepoint.invalid,
            .byte_len = 2,
        }, CodePage.utf8.codepointAt(0, invalid_utf8).?);
        try std.testing.expectEqual(Codepoint{
            .value = Codepoint.invalid,
            .byte_len = 1,
        }, CodePage.utf8.codepointAt(2, invalid_utf8).?);
        try std.testing.expectEqual(@as(?Codepoint, null), CodePage.windows1252.codepointAt(3, invalid_utf8));
    }

    {
        const invalid_utf8 = "\xD2";
        try std.testing.expectEqual(Codepoint{
            .value = Codepoint.invalid,
            .byte_len = 1,
        }, CodePage.utf8.codepointAt(0, invalid_utf8).?);
        try std.testing.expectEqual(@as(?Codepoint, null), CodePage.windows1252.codepointAt(1, invalid_utf8));
    }

    {
        const invalid_utf8 = "\xE1\xA0";
        try std.testing.expectEqual(Codepoint{
            .value = Codepoint.invalid,
            .byte_len = 2,
        }, CodePage.utf8.codepointAt(0, invalid_utf8).?);
        try std.testing.expectEqual(@as(?Codepoint, null), CodePage.windows1252.codepointAt(2, invalid_utf8));
    }

    {
        const invalid_utf8 = "\xC5\xFF";
        try std.testing.expectEqual(Codepoint{
            .value = Codepoint.invalid,
            .byte_len = 1,
        }, CodePage.utf8.codepointAt(0, invalid_utf8).?);
        try std.testing.expectEqual(Codepoint{
            .value = Codepoint.invalid,
            .byte_len = 1,
        }, CodePage.utf8.codepointAt(1, invalid_utf8).?);
        try std.testing.expectEqual(@as(?Codepoint, null), CodePage.windows1252.codepointAt(2, invalid_utf8));
    }

    {
        // encoded high surrogate
        const invalid_utf8 = "\xED\xA0\xBD";
        try std.testing.expectEqual(Codepoint{
            .value = Codepoint.invalid,
            .byte_len = 2,
        }, CodePage.utf8.codepointAt(0, invalid_utf8).?);
        try std.testing.expectEqual(Codepoint{
            .value = Codepoint.invalid,
            .byte_len = 1,
        }, CodePage.utf8.codepointAt(2, invalid_utf8).?);
    }
}

test "codepointAt utf8 encoded" {
    const utf8_encoded = "²";

    // with code page utf8
    try std.testing.expectEqual(Codepoint{
        .value = '²',
        .byte_len = 2,
    }, CodePage.utf8.codepointAt(0, utf8_encoded).?);
    try std.testing.expectEqual(@as(?Codepoint, null), CodePage.utf8.codepointAt(2, utf8_encoded));

    // with code page windows1252
    try std.testing.expectEqual(Codepoint{
        .value = '\xC2',
        .byte_len = 1,
    }, CodePage.windows1252.codepointAt(0, utf8_encoded).?);
    try std.testing.expectEqual(Codepoint{
        .value = '\xB2',
        .byte_len = 1,
    }, CodePage.windows1252.codepointAt(1, utf8_encoded).?);
    try std.testing.expectEqual(@as(?Codepoint, null), CodePage.windows1252.codepointAt(2, utf8_encoded));
}

test "codepointAt windows1252 encoded" {
    const windows1252_encoded = "\xB2";

    // with code page utf8
    try std.testing.expectEqual(Codepoint{
        .value = Codepoint.invalid,
        .byte_len = 1,
    }, CodePage.utf8.codepointAt(0, windows1252_encoded).?);
    try std.testing.expectEqual(@as(?Codepoint, null), CodePage.utf8.codepointAt(2, windows1252_encoded));

    // with code page windows1252
    try std.testing.expectEqual(Codepoint{
        .value = '\xB2',
        .byte_len = 1,
    }, CodePage.windows1252.codepointAt(0, windows1252_encoded).?);
    try std.testing.expectEqual(@as(?Codepoint, null), CodePage.windows1252.codepointAt(1, windows1252_encoded));
}

pub const Codepoint = struct {
    value: u21,
    byte_len: usize,

    pub const invalid: u21 = std.math.maxInt(u21);
};
