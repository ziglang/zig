const std = @import("std");

/// This function is specific to how the Win32 RC command line interprets
/// language IDs specified as integers.
/// - Always interpreted as hexadecimal, but explicit 0x prefix is also allowed
/// - Wraps on overflow of u16
/// - Stops parsing on any invalid hexadecimal digits
/// - Errors if a digit is not the first char
/// - `-` (negative) prefix is allowed
pub fn parseInt(str: []const u8) error{InvalidLanguageId}!u16 {
    var result: u16 = 0;
    const radix: u8 = 16;
    var buf = str;

    const Prefix = enum { none, minus };
    var prefix: Prefix = .none;
    switch (buf[0]) {
        '-' => {
            prefix = .minus;
            buf = buf[1..];
        },
        else => {},
    }

    if (buf.len > 2 and buf[0] == '0' and buf[1] == 'x') {
        buf = buf[2..];
    }

    for (buf, 0..) |c, i| {
        const digit = switch (c) {
            // On invalid digit for the radix, just stop parsing but don't fail
            'a'...'f', 'A'...'F', '0'...'9' => std.fmt.charToDigit(c, radix) catch break,
            else => {
                // First digit must be valid
                if (i == 0) {
                    return error.InvalidLanguageId;
                }
                break;
            },
        };

        if (result != 0) {
            result *%= radix;
        }
        result +%= digit;
    }

    switch (prefix) {
        .none => {},
        .minus => result = 0 -% result,
    }

    return result;
}

test parseInt {
    try std.testing.expectEqual(@as(u16, 0x16), try parseInt("16"));
    try std.testing.expectEqual(@as(u16, 0x1a), try parseInt("0x1A"));
    try std.testing.expectEqual(@as(u16, 0x1a), try parseInt("0x1Azzzz"));
    try std.testing.expectEqual(@as(u16, 0xffff), try parseInt("-1"));
    try std.testing.expectEqual(@as(u16, 0xffea), try parseInt("-0x16"));
    try std.testing.expectEqual(@as(u16, 0x0), try parseInt("0o100"));
    try std.testing.expectEqual(@as(u16, 0x1), try parseInt("10001"));
    try std.testing.expectError(error.InvalidLanguageId, parseInt("--1"));
    try std.testing.expectError(error.InvalidLanguageId, parseInt("0xha"));
    try std.testing.expectError(error.InvalidLanguageId, parseInt("¹"));
    try std.testing.expectError(error.InvalidLanguageId, parseInt("~1"));
}

/// This function is specific to how the Win32 RC command line interprets
/// language tags: invalid tags are rejected, but tags that don't have
/// a specific assigned ID but are otherwise valid enough will get
/// converted to an ID of LOCALE_CUSTOM_UNSPECIFIED.
pub fn tagToInt(tag: []const u8) error{InvalidLanguageTag}!u16 {
    const maybe_id = try tagToId(tag);
    if (maybe_id) |id| {
        return @intFromEnum(id);
    } else {
        return LOCALE_CUSTOM_UNSPECIFIED;
    }
}

pub fn tagToId(tag: []const u8) error{InvalidLanguageTag}!?LanguageId {
    const parsed = try parse(tag);
    // There are currently no language tags with assigned IDs that have
    // multiple suffixes, so we can skip the lookup.
    if (parsed.multiple_suffixes) return null;
    const longest_known_tag = comptime blk: {
        var len = 0;
        for (@typeInfo(LanguageId).@"enum".fields) |field| {
            if (field.name.len > len) len = field.name.len;
        }
        break :blk len;
    };
    // If the tag is longer than the longest tag that has an assigned ID,
    // then we can skip the lookup.
    if (tag.len > longest_known_tag) return null;
    var normalized_buf: [longest_known_tag]u8 = undefined;
    // To allow e.g. `de-de_phoneb` to get looked up as `de-de`, we need to
    // omit the suffix, but only if the tag contains a valid alternate sort order.
    const tag_to_normalize = if (parsed.isSuffixValidSortOrder()) tag[0 .. tag.len - (parsed.suffix.?.len + 1)] else tag;
    const normalized_tag = normalizeTag(tag_to_normalize, &normalized_buf);
    return std.meta.stringToEnum(LanguageId, normalized_tag) orelse {
        // special case for a tag that has been mapped to the same ID
        // twice.
        if (std.mem.eql(u8, "ff_latn_ng", normalized_tag)) {
            return LanguageId.ff_ng;
        }
        return null;
    };
}

test tagToId {
    try std.testing.expectEqual(LanguageId.ar_ae, (try tagToId("ar-ae")).?);
    try std.testing.expectEqual(LanguageId.ar_ae, (try tagToId("AR_AE")).?);
    try std.testing.expectEqual(LanguageId.ff_ng, (try tagToId("ff-ng")).?);
    // Special case
    try std.testing.expectEqual(LanguageId.ff_ng, (try tagToId("ff-Latn-NG")).?);
}

test "exhaustive tagToId" {
    inline for (@typeInfo(LanguageId).Enum.fields) |field| {
        const id = tagToId(field.name) catch |err| {
            std.debug.print("tag: {s}\n", .{field.name});
            return err;
        };
        try std.testing.expectEqual(@field(LanguageId, field.name), id orelse {
            std.debug.print("tag: {s}, got null\n", .{field.name});
            return error.TestExpectedEqual;
        });
    }
    var buf: [32]u8 = undefined;
    inline for (valid_alternate_sorts) |parsed_sort| {
        var fbs = std.io.fixedBufferStream(&buf);
        const writer = fbs.writer();
        writer.writeAll(parsed_sort.language_code) catch unreachable;
        writer.writeAll("-") catch unreachable;
        writer.writeAll(parsed_sort.country_code.?) catch unreachable;
        writer.writeAll("-") catch unreachable;
        writer.writeAll(parsed_sort.suffix.?) catch unreachable;
        const expected_field_name = comptime field: {
            var name_buf: [5]u8 = undefined;
            @memcpy(name_buf[0..parsed_sort.language_code.len], parsed_sort.language_code);
            name_buf[2] = '_';
            @memcpy(name_buf[3..], parsed_sort.country_code.?);
            break :field name_buf;
        };
        const expected = @field(LanguageId, &expected_field_name);
        const id = tagToId(fbs.getWritten()) catch |err| {
            std.debug.print("tag: {s}\n", .{fbs.getWritten()});
            return err;
        };
        try std.testing.expectEqual(expected, id orelse {
            std.debug.print("tag: {s}, expected: {}, got null\n", .{ fbs.getWritten(), expected });
            return error.TestExpectedEqual;
        });
    }
}

fn normalizeTag(tag: []const u8, buf: []u8) []u8 {
    std.debug.assert(buf.len >= tag.len);
    for (tag, 0..) |c, i| {
        if (c == '-')
            buf[i] = '_'
        else
            buf[i] = std.ascii.toLower(c);
    }
    return buf[0..tag.len];
}

/// https://winprotocoldoc.blob.core.windows.net/productionwindowsarchives/MS-LCID/%5bMS-LCID%5d.pdf#%5B%7B%22num%22%3A72%2C%22gen%22%3A0%7D%2C%7B%22name%22%3A%22XYZ%22%7D%2C69%2C574%2C0%5D
/// "When an LCID is requested for a locale without a
/// permanent LCID assignment, nor a temporary
/// assignment as above, the protocol will respond
/// with LOCALE_CUSTOM_UNSPECIFIED for all such
/// locales. Because this single value is used for
/// numerous possible locale names, it is impossible to
/// round trip this locale, even temporarily.
/// Applications should discard this value as soon as
/// possible and never persist it. If the system is
/// forced to respond to a request for
/// LCID_CUSTOM_UNSPECIFIED, it will fall back to
/// the current user locale. This is often incorrect but
/// may prevent an application or component from
/// failing. As the meaning of this temporary LCID is
/// unstable, it should never be used for interchange
/// or persisted data. This is a 1-to-many relationship
/// that is very unstable."
pub const LOCALE_CUSTOM_UNSPECIFIED = 0x1000;

pub const LANG_ENGLISH = 0x09;
pub const SUBLANG_ENGLISH_US = 0x01;

/// https://learn.microsoft.com/en-us/windows/win32/intl/language-identifiers
pub fn MAKELANGID(primary: u10, sublang: u6) u16 {
    return (@as(u16, primary) << 10) | sublang;
}

/// Language tag format expressed as a regular expression (rough approximation):
///
/// [a-zA-Z]{1,3}([-_][a-zA-Z]{4})?([-_][a-zA-Z]{2})?([-_][a-zA-Z0-9]{1,8})?
///     lang    |     script      |      country    |       suffix
///
/// Notes:
/// - If lang code is 1 char, it seems to mean that everything afterwards uses suffix
///   parsing rules (e.g. `a-0` and `a-00000000` are allowed).
/// - There can also be any number of trailing suffix parts as long as they each
///   would be a valid suffix part, e.g. `en-us-blah-blah1-blah2-blah3` is allowed.
/// - When doing lookups, trailing suffix parts are taken into account, e.g.
///   `ca-es-valencia` is not considered equivalent to `ca-es-valencia-blah`.
/// - A suffix is only allowed if:
///   + Lang code is 1 char long, or
///   + A country code is present, or
///   + A script tag is not present and:
///      - the suffix is numeric-only and has a length of 3, or
///      - the lang is `qps` and the suffix is `ploca` or `plocm`
pub fn parse(lang_tag: []const u8) error{InvalidLanguageTag}!Parsed {
    var it = std.mem.splitAny(u8, lang_tag, "-_");
    const lang_code = it.first();
    const is_valid_lang_code = lang_code.len >= 1 and lang_code.len <= 3 and isAllAlphabetic(lang_code);
    if (!is_valid_lang_code) return error.InvalidLanguageTag;
    var parsed = Parsed{
        .language_code = lang_code,
    };
    // The second part could be a script tag, a country code, or a suffix
    if (it.next()) |part_str| {
        // The lang code being length 1 behaves strangely, so fully special case it.
        if (lang_code.len == 1) {
            // This is almost certainly not the 'right' way to do this, but I don't have a method
            // to determine how exactly these language tags are parsed, and it seems like
            // suffix parsing rules apply generally (digits allowed, length of 1 to 8).
            //
            // However, because we want to be able to lookup `x-iv-mathan` normally without
            // `multiple_suffixes` being set to true, we need to make sure to treat two-length
            // alphabetic parts as a country code.
            if (part_str.len == 2 and isAllAlphabetic(part_str)) {
                parsed.country_code = part_str;
            }
            // Everything else, though, we can just throw into the suffix as long as the normal
            // rules apply.
            else if (part_str.len > 0 and part_str.len <= 8 and isAllAlphanumeric(part_str)) {
                parsed.suffix = part_str;
            } else {
                return error.InvalidLanguageTag;
            }
        } else if (part_str.len == 4 and isAllAlphabetic(part_str)) {
            parsed.script_tag = part_str;
        } else if (part_str.len == 2 and isAllAlphabetic(part_str)) {
            parsed.country_code = part_str;
        }
        // Only a 3-len numeric suffix is allowed as the second part of a tag
        else if (part_str.len == 3 and isAllNumeric(part_str)) {
            parsed.suffix = part_str;
        }
        // Special case for qps-ploca and qps-plocm
        else if (std.ascii.eqlIgnoreCase(lang_code, "qps") and
            (std.ascii.eqlIgnoreCase(part_str, "ploca") or
            std.ascii.eqlIgnoreCase(part_str, "plocm")))
        {
            parsed.suffix = part_str;
        } else {
            return error.InvalidLanguageTag;
        }
    } else {
        // If there's no part besides a 1-len lang code, then it is malformed
        if (lang_code.len == 1) return error.InvalidLanguageTag;
        return parsed;
    }
    if (parsed.script_tag != null) {
        if (it.next()) |part_str| {
            if (part_str.len == 2 and isAllAlphabetic(part_str)) {
                parsed.country_code = part_str;
            } else {
                // Suffix is not allowed when a country code is not present.
                return error.InvalidLanguageTag;
            }
        } else {
            return parsed;
        }
    }
    // We've now parsed any potential script tag/country codes, so anything remaining
    // is a suffix
    while (it.next()) |part_str| {
        if (part_str.len == 0 or part_str.len > 8 or !isAllAlphanumeric(part_str)) {
            return error.InvalidLanguageTag;
        }
        if (parsed.suffix == null) {
            parsed.suffix = part_str;
        } else {
            // In theory we could return early here but we still want to validate
            // that each part is a valid suffix all the way to the end, e.g.
            // we should reject `en-us-suffix-a-b-c-!!!` because of the invalid `!!!`
            // suffix part.
            parsed.multiple_suffixes = true;
        }
    }
    return parsed;
}

pub const Parsed = struct {
    language_code: []const u8,
    script_tag: ?[]const u8 = null,
    country_code: ?[]const u8 = null,
    /// Can be a sort order (e.g. phoneb) or something like valencia, 001, etc
    suffix: ?[]const u8 = null,
    /// There can be any number of suffixes, but we don't need to care what their
    /// values are, we just need to know if any exist so that e.g. `ca-es-valencia-blah`
    /// can be seen as different from `ca-es-valencia`. Storing this as a bool
    /// allows us to avoid needing either (a) dynamic allocation or (b) a limit to
    /// the number of suffixes allowed when parsing.
    multiple_suffixes: bool = false,

    pub fn isSuffixValidSortOrder(self: Parsed) bool {
        if (self.country_code == null) return false;
        if (self.suffix == null) return false;
        if (self.script_tag != null) return false;
        if (self.multiple_suffixes) return false;
        for (valid_alternate_sorts) |valid_sort| {
            if (std.ascii.eqlIgnoreCase(valid_sort.language_code, self.language_code) and
                std.ascii.eqlIgnoreCase(valid_sort.country_code.?, self.country_code.?) and
                std.ascii.eqlIgnoreCase(valid_sort.suffix.?, self.suffix.?))
            {
                return true;
            }
        }
        return false;
    }
};

/// https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-lcid/70feba9f-294e-491e-b6eb-56532684c37f
/// See the table following this text: "Alternate sorts can be selected by using one of the identifiers from the following table."
const valid_alternate_sorts = [_]Parsed{
    // Note: x-IV-mathan is omitted due to how lookups are implemented.
    //       This table is used to make e.g. `de-de_phoneb` get looked up
    //       as `de-de` (the suffix is omitted for the lookup), but x-iv-mathan
    //       instead needs to be looked up with the suffix included because
    //       `x-iv` is not a tag with an assigned ID.
    .{ .language_code = "de", .country_code = "de", .suffix = "phoneb" },
    .{ .language_code = "hu", .country_code = "hu", .suffix = "tchncl" },
    .{ .language_code = "ka", .country_code = "ge", .suffix = "modern" },
    .{ .language_code = "zh", .country_code = "cn", .suffix = "stroke" },
    .{ .language_code = "zh", .country_code = "sg", .suffix = "stroke" },
    .{ .language_code = "zh", .country_code = "mo", .suffix = "stroke" },
    .{ .language_code = "zh", .country_code = "tw", .suffix = "pronun" },
    .{ .language_code = "zh", .country_code = "tw", .suffix = "radstr" },
    .{ .language_code = "ja", .country_code = "jp", .suffix = "radstr" },
    .{ .language_code = "zh", .country_code = "hk", .suffix = "radstr" },
    .{ .language_code = "zh", .country_code = "mo", .suffix = "radstr" },
    .{ .language_code = "zh", .country_code = "cn", .suffix = "phoneb" },
    .{ .language_code = "zh", .country_code = "sg", .suffix = "phoneb" },
};

test "parse" {
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "en",
    }, try parse("en"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "en",
        .country_code = "us",
    }, try parse("en-us"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "en",
        .suffix = "123",
    }, try parse("en-123"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "en",
        .suffix = "123",
        .multiple_suffixes = true,
    }, try parse("en-123-blah"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "en",
        .country_code = "us",
        .suffix = "123",
        .multiple_suffixes = true,
    }, try parse("en-us_123-blah"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "eng",
        .script_tag = "Latn",
    }, try parse("eng-Latn"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "eng",
        .script_tag = "Latn",
    }, try parse("eng-Latn"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "ff",
        .script_tag = "Latn",
        .country_code = "NG",
    }, try parse("ff-Latn-NG"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "qps",
        .suffix = "Plocm",
    }, try parse("qps-Plocm"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "qps",
        .suffix = "ploca",
    }, try parse("qps-ploca"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "x",
        .country_code = "IV",
        .suffix = "mathan",
    }, try parse("x-IV-mathan"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "a",
        .suffix = "a",
    }, try parse("a-a"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "a",
        .suffix = "000",
    }, try parse("a-000"));
    try std.testing.expectEqualDeep(Parsed{
        .language_code = "a",
        .suffix = "00000000",
    }, try parse("a-00000000"));
    // suffix not allowed if script tag is present without country code
    try std.testing.expectError(error.InvalidLanguageTag, parse("eng-Latn-suffix"));
    // suffix must be 3 numeric digits if neither script tag nor country code is present
    try std.testing.expectError(error.InvalidLanguageTag, parse("eng-suffix"));
    try std.testing.expectError(error.InvalidLanguageTag, parse("en-plocm"));
    // 1-len lang code is not allowed if it's the only part
    try std.testing.expectError(error.InvalidLanguageTag, parse("e"));
}

fn isAllAlphabetic(str: []const u8) bool {
    for (str) |c| {
        if (!std.ascii.isAlphabetic(c)) return false;
    }
    return true;
}

fn isAllAlphanumeric(str: []const u8) bool {
    for (str) |c| {
        if (!std.ascii.isAlphanumeric(c)) return false;
    }
    return true;
}

fn isAllNumeric(str: []const u8) bool {
    for (str) |c| {
        if (!std.ascii.isDigit(c)) return false;
    }
    return true;
}

/// Derived from https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-lcid/70feba9f-294e-491e-b6eb-56532684c37f
/// - Protocol Revision: 15.0
/// - Language / Language ID / Language Tag table in Appendix A
/// - Removed all rows that have Language ID 0x1000 (LOCALE_CUSTOM_UNSPECIFIED)
/// - Normalized each language tag (lowercased, replaced all `-` with `_`)
/// - There is one special case where two tags are mapped to the same ID, the following
///   has been omitted and must be special cased during lookup to map to the ID ff_ng / 0x0467.
///     ff_latn_ng = 0x0467, // Fulah (Latin), Nigeria
/// - x_iv_mathan has been added which is not in the table but does appear in the Alternate sorts
///   table as 0x007F (LANG_INVARIANT).
pub const LanguageId = enum(u16) {
    // Language tag = Language ID, // Language, Location (or type)
    af = 0x0036, // Afrikaans
    af_za = 0x0436, // Afrikaans, South Africa
    sq = 0x001C, // Albanian
    sq_al = 0x041C, // Albanian, Albania
    gsw = 0x0084, // Alsatian
    gsw_fr = 0x0484, // Alsatian, France
    am = 0x005E, // Amharic
    am_et = 0x045E, // Amharic, Ethiopia
    ar = 0x0001, // Arabic
    ar_dz = 0x1401, // Arabic, Algeria
    ar_bh = 0x3C01, // Arabic, Bahrain
    ar_eg = 0x0c01, // Arabic, Egypt
    ar_iq = 0x0801, // Arabic, Iraq
    ar_jo = 0x2C01, // Arabic, Jordan
    ar_kw = 0x3401, // Arabic, Kuwait
    ar_lb = 0x3001, // Arabic, Lebanon
    ar_ly = 0x1001, // Arabic, Libya
    ar_ma = 0x1801, // Arabic, Morocco
    ar_om = 0x2001, // Arabic, Oman
    ar_qa = 0x4001, // Arabic, Qatar
    ar_sa = 0x0401, // Arabic, Saudi Arabia
    ar_sy = 0x2801, // Arabic, Syria
    ar_tn = 0x1C01, // Arabic, Tunisia
    ar_ae = 0x3801, // Arabic, U.A.E.
    ar_ye = 0x2401, // Arabic, Yemen
    hy = 0x002B, // Armenian
    hy_am = 0x042B, // Armenian, Armenia
    as = 0x004D, // Assamese
    as_in = 0x044D, // Assamese, India
    az_cyrl = 0x742C, // Azerbaijani (Cyrillic)
    az_cyrl_az = 0x082C, // Azerbaijani (Cyrillic), Azerbaijan
    az = 0x002C, // Azerbaijani (Latin)
    az_latn = 0x782C, // Azerbaijani (Latin)
    az_latn_az = 0x042C, // Azerbaijani (Latin), Azerbaijan
    bn = 0x0045, // Bangla
    bn_bd = 0x0845, // Bangla, Bangladesh
    bn_in = 0x0445, // Bangla, India
    ba = 0x006D, // Bashkir
    ba_ru = 0x046D, // Bashkir, Russia
    eu = 0x002D, // Basque
    eu_es = 0x042D, // Basque, Spain
    be = 0x0023, // Belarusian
    be_by = 0x0423, // Belarusian, Belarus
    bs_cyrl = 0x641A, // Bosnian (Cyrillic)
    bs_cyrl_ba = 0x201A, // Bosnian (Cyrillic), Bosnia and Herzegovina
    bs_latn = 0x681A, // Bosnian (Latin)
    bs = 0x781A, // Bosnian (Latin)
    bs_latn_ba = 0x141A, // Bosnian (Latin), Bosnia and Herzegovina
    br = 0x007E, // Breton
    br_fr = 0x047E, // Breton, France
    bg = 0x0002, // Bulgarian
    bg_bg = 0x0402, // Bulgarian, Bulgaria
    my = 0x0055, // Burmese
    my_mm = 0x0455, // Burmese, Myanmar
    ca = 0x0003, // Catalan
    ca_es = 0x0403, // Catalan, Spain
    tzm_arab_ma = 0x045F, // Central Atlas Tamazight (Arabic), Morocco
    ku = 0x0092, // Central Kurdish
    ku_arab = 0x7c92, // Central Kurdish
    ku_arab_iq = 0x0492, // Central Kurdish, Iraq
    chr = 0x005C, // Cherokee
    chr_cher = 0x7c5C, // Cherokee
    chr_cher_us = 0x045C, // Cherokee, United States
    zh_hans = 0x0004, // Chinese (Simplified)
    zh = 0x7804, // Chinese (Simplified)
    zh_cn = 0x0804, // Chinese (Simplified), People's Republic of China
    zh_sg = 0x1004, // Chinese (Simplified), Singapore
    zh_hant = 0x7C04, // Chinese (Traditional)
    zh_hk = 0x0C04, // Chinese (Traditional), Hong Kong S.A.R.
    zh_mo = 0x1404, // Chinese (Traditional), Macao S.A.R.
    zh_tw = 0x0404, // Chinese (Traditional), Taiwan
    co = 0x0083, // Corsican
    co_fr = 0x0483, // Corsican, France
    hr = 0x001A, // Croatian
    hr_hr = 0x041A, // Croatian, Croatia
    hr_ba = 0x101A, // Croatian (Latin), Bosnia and Herzegovina
    cs = 0x0005, // Czech
    cs_cz = 0x0405, // Czech, Czech Republic
    da = 0x0006, // Danish
    da_dk = 0x0406, // Danish, Denmark
    prs = 0x008C, // Dari
    prs_af = 0x048C, // Dari, Afghanistan
    dv = 0x0065, // Divehi
    dv_mv = 0x0465, // Divehi, Maldives
    nl = 0x0013, // Dutch
    nl_be = 0x0813, // Dutch, Belgium
    nl_nl = 0x0413, // Dutch, Netherlands
    dz_bt = 0x0C51, // Dzongkha, Bhutan
    en = 0x0009, // English
    en_au = 0x0C09, // English, Australia
    en_bz = 0x2809, // English, Belize
    en_ca = 0x1009, // English, Canada
    en_029 = 0x2409, // English, Caribbean
    en_hk = 0x3C09, // English, Hong Kong
    en_in = 0x4009, // English, India
    en_ie = 0x1809, // English, Ireland
    en_jm = 0x2009, // English, Jamaica
    en_my = 0x4409, // English, Malaysia
    en_nz = 0x1409, // English, New Zealand
    en_ph = 0x3409, // English, Republic of the Philippines
    en_sg = 0x4809, // English, Singapore
    en_za = 0x1C09, // English, South Africa
    en_tt = 0x2c09, // English, Trinidad and Tobago
    en_ae = 0x4C09, // English, United Arab Emirates
    en_gb = 0x0809, // English, United Kingdom
    en_us = 0x0409, // English, United States
    en_zw = 0x3009, // English, Zimbabwe
    et = 0x0025, // Estonian
    et_ee = 0x0425, // Estonian, Estonia
    fo = 0x0038, // Faroese
    fo_fo = 0x0438, // Faroese, Faroe Islands
    fil = 0x0064, // Filipino
    fil_ph = 0x0464, // Filipino, Philippines
    fi = 0x000B, // Finnish
    fi_fi = 0x040B, // Finnish, Finland
    fr = 0x000C, // French
    fr_be = 0x080C, // French, Belgium
    fr_cm = 0x2c0C, // French, Cameroon
    fr_ca = 0x0c0C, // French, Canada
    fr_029 = 0x1C0C, // French, Caribbean
    fr_cd = 0x240C, // French, Congo, DRC
    fr_ci = 0x300C, // French, Côte d'Ivoire
    fr_fr = 0x040C, // French, France
    fr_ht = 0x3c0C, // French, Haiti
    fr_lu = 0x140C, // French, Luxembourg
    fr_ml = 0x340C, // French, Mali
    fr_ma = 0x380C, // French, Morocco
    fr_mc = 0x180C, // French, Principality of Monaco
    fr_re = 0x200C, // French, Reunion
    fr_sn = 0x280C, // French, Senegal
    fr_ch = 0x100C, // French, Switzerland
    fy = 0x0062, // Frisian
    fy_nl = 0x0462, // Frisian, Netherlands
    ff = 0x0067, // Fulah
    ff_latn = 0x7C67, // Fulah (Latin)
    ff_ng = 0x0467, // Fulah, Nigeria
    ff_latn_sn = 0x0867, // Fulah, Senegal
    gl = 0x0056, // Galician
    gl_es = 0x0456, // Galician, Spain
    ka = 0x0037, // Georgian
    ka_ge = 0x0437, // Georgian, Georgia
    de = 0x0007, // German
    de_at = 0x0C07, // German, Austria
    de_de = 0x0407, // German, Germany
    de_li = 0x1407, // German, Liechtenstein
    de_lu = 0x1007, // German, Luxembourg
    de_ch = 0x0807, // German, Switzerland
    el = 0x0008, // Greek
    el_gr = 0x0408, // Greek, Greece
    kl = 0x006F, // Greenlandic
    kl_gl = 0x046F, // Greenlandic, Greenland
    gn = 0x0074, // Guarani
    gn_py = 0x0474, // Guarani, Paraguay
    gu = 0x0047, // Gujarati
    gu_in = 0x0447, // Gujarati, India
    ha = 0x0068, // Hausa (Latin)
    ha_latn = 0x7C68, // Hausa (Latin)
    ha_latn_ng = 0x0468, // Hausa (Latin), Nigeria
    haw = 0x0075, // Hawaiian
    haw_us = 0x0475, // Hawaiian, United States
    he = 0x000D, // Hebrew
    he_il = 0x040D, // Hebrew, Israel
    hi = 0x0039, // Hindi
    hi_in = 0x0439, // Hindi, India
    hu = 0x000E, // Hungarian
    hu_hu = 0x040E, // Hungarian, Hungary
    is = 0x000F, // Icelandic
    is_is = 0x040F, // Icelandic, Iceland
    ig = 0x0070, // Igbo
    ig_ng = 0x0470, // Igbo, Nigeria
    id = 0x0021, // Indonesian
    id_id = 0x0421, // Indonesian, Indonesia
    iu = 0x005D, // Inuktitut (Latin)
    iu_latn = 0x7C5D, // Inuktitut (Latin)
    iu_latn_ca = 0x085D, // Inuktitut (Latin), Canada
    iu_cans = 0x785D, // Inuktitut (Syllabics)
    iu_cans_ca = 0x045d, // Inuktitut (Syllabics), Canada
    ga = 0x003C, // Irish
    ga_ie = 0x083C, // Irish, Ireland
    it = 0x0010, // Italian
    it_it = 0x0410, // Italian, Italy
    it_ch = 0x0810, // Italian, Switzerland
    ja = 0x0011, // Japanese
    ja_jp = 0x0411, // Japanese, Japan
    kn = 0x004B, // Kannada
    kn_in = 0x044B, // Kannada, India
    kr_latn_ng = 0x0471, // Kanuri (Latin), Nigeria
    ks = 0x0060, // Kashmiri
    ks_arab = 0x0460, // Kashmiri, Perso-Arabic
    ks_deva_in = 0x0860, // Kashmiri (Devanagari), India
    kk = 0x003F, // Kazakh
    kk_kz = 0x043F, // Kazakh, Kazakhstan
    km = 0x0053, // Khmer
    km_kh = 0x0453, // Khmer, Cambodia
    quc = 0x0086, // K'iche
    quc_latn_gt = 0x0486, // K'iche, Guatemala
    rw = 0x0087, // Kinyarwanda
    rw_rw = 0x0487, // Kinyarwanda, Rwanda
    sw = 0x0041, // Kiswahili
    sw_ke = 0x0441, // Kiswahili, Kenya
    kok = 0x0057, // Konkani
    kok_in = 0x0457, // Konkani, India
    ko = 0x0012, // Korean
    ko_kr = 0x0412, // Korean, Korea
    ky = 0x0040, // Kyrgyz
    ky_kg = 0x0440, // Kyrgyz, Kyrgyzstan
    lo = 0x0054, // Lao
    lo_la = 0x0454, // Lao, Lao P.D.R.
    la_va = 0x0476, // Latin, Vatican City
    lv = 0x0026, // Latvian
    lv_lv = 0x0426, // Latvian, Latvia
    lt = 0x0027, // Lithuanian
    lt_lt = 0x0427, // Lithuanian, Lithuania
    dsb = 0x7C2E, // Lower Sorbian
    dsb_de = 0x082E, // Lower Sorbian, Germany
    lb = 0x006E, // Luxembourgish
    lb_lu = 0x046E, // Luxembourgish, Luxembourg
    mk = 0x002F, // Macedonian
    mk_mk = 0x042F, // Macedonian, North Macedonia
    ms = 0x003E, // Malay
    ms_bn = 0x083E, // Malay, Brunei Darussalam
    ms_my = 0x043E, // Malay, Malaysia
    ml = 0x004C, // Malayalam
    ml_in = 0x044C, // Malayalam, India
    mt = 0x003A, // Maltese
    mt_mt = 0x043A, // Maltese, Malta
    mi = 0x0081, // Maori
    mi_nz = 0x0481, // Maori, New Zealand
    arn = 0x007A, // Mapudungun
    arn_cl = 0x047A, // Mapudungun, Chile
    mr = 0x004E, // Marathi
    mr_in = 0x044E, // Marathi, India
    moh = 0x007C, // Mohawk
    moh_ca = 0x047C, // Mohawk, Canada
    mn = 0x0050, // Mongolian (Cyrillic)
    mn_cyrl = 0x7850, // Mongolian (Cyrillic)
    mn_mn = 0x0450, // Mongolian (Cyrillic), Mongolia
    mn_mong = 0x7C50, // Mongolian (Traditional Mongolian)
    mn_mong_cn = 0x0850, // Mongolian (Traditional Mongolian), People's Republic of China
    mn_mong_mn = 0x0C50, // Mongolian (Traditional Mongolian), Mongolia
    ne = 0x0061, // Nepali
    ne_in = 0x0861, // Nepali, India
    ne_np = 0x0461, // Nepali, Nepal
    no = 0x0014, // Norwegian (Bokmal)
    nb = 0x7C14, // Norwegian (Bokmal)
    nb_no = 0x0414, // Norwegian (Bokmal), Norway
    nn = 0x7814, // Norwegian (Nynorsk)
    nn_no = 0x0814, // Norwegian (Nynorsk), Norway
    oc = 0x0082, // Occitan
    oc_fr = 0x0482, // Occitan, France
    @"or" = 0x0048, // Odia
    or_in = 0x0448, // Odia, India
    om = 0x0072, // Oromo
    om_et = 0x0472, // Oromo, Ethiopia
    ps = 0x0063, // Pashto
    ps_af = 0x0463, // Pashto, Afghanistan
    fa = 0x0029, // Persian
    fa_ir = 0x0429, // Persian, Iran
    pl = 0x0015, // Polish
    pl_pl = 0x0415, // Polish, Poland
    pt = 0x0016, // Portuguese
    pt_br = 0x0416, // Portuguese, Brazil
    pt_pt = 0x0816, // Portuguese, Portugal
    qps_ploca = 0x05FE, // Pseudo Language, Pseudo locale for east Asian/complex script localization testing
    qps_ploc = 0x0501, // Pseudo Language, Pseudo locale used for localization testing
    qps_plocm = 0x09FF, // Pseudo Language, Pseudo locale used for localization testing of mirrored locales
    pa = 0x0046, // Punjabi
    pa_arab = 0x7C46, // Punjabi
    pa_in = 0x0446, // Punjabi, India
    pa_arab_pk = 0x0846, // Punjabi, Islamic Republic of Pakistan
    quz = 0x006B, // Quechua
    quz_bo = 0x046B, // Quechua, Bolivia
    quz_ec = 0x086B, // Quechua, Ecuador
    quz_pe = 0x0C6B, // Quechua, Peru
    ro = 0x0018, // Romanian
    ro_md = 0x0818, // Romanian, Moldova
    ro_ro = 0x0418, // Romanian, Romania
    rm = 0x0017, // Romansh
    rm_ch = 0x0417, // Romansh, Switzerland
    ru = 0x0019, // Russian
    ru_md = 0x0819, // Russian, Moldova
    ru_ru = 0x0419, // Russian, Russia
    sah = 0x0085, // Sakha
    sah_ru = 0x0485, // Sakha, Russia
    smn = 0x703B, // Sami (Inari)
    smn_fi = 0x243B, // Sami (Inari), Finland
    smj = 0x7C3B, // Sami (Lule)
    smj_no = 0x103B, // Sami (Lule), Norway
    smj_se = 0x143B, // Sami (Lule), Sweden
    se = 0x003B, // Sami (Northern)
    se_fi = 0x0C3B, // Sami (Northern), Finland
    se_no = 0x043B, // Sami (Northern), Norway
    se_se = 0x083B, // Sami (Northern), Sweden
    sms = 0x743B, // Sami (Skolt)
    sms_fi = 0x203B, // Sami (Skolt), Finland
    sma = 0x783B, // Sami (Southern)
    sma_no = 0x183B, // Sami (Southern), Norway
    sma_se = 0x1C3B, // Sami (Southern), Sweden
    sa = 0x004F, // Sanskrit
    sa_in = 0x044F, // Sanskrit, India
    gd = 0x0091, // Scottish Gaelic
    gd_gb = 0x0491, // Scottish Gaelic, United Kingdom
    sr_cyrl = 0x6C1A, // Serbian (Cyrillic)
    sr_cyrl_ba = 0x1C1A, // Serbian (Cyrillic), Bosnia and Herzegovina
    sr_cyrl_me = 0x301A, // Serbian (Cyrillic), Montenegro
    sr_cyrl_rs = 0x281A, // Serbian (Cyrillic), Serbia
    sr_cyrl_cs = 0x0C1A, // Serbian (Cyrillic), Serbia and Montenegro (Former)
    sr_latn = 0x701A, // Serbian (Latin)
    sr = 0x7C1A, // Serbian (Latin)
    sr_latn_ba = 0x181A, // Serbian (Latin), Bosnia and Herzegovina
    sr_latn_me = 0x2c1A, // Serbian (Latin), Montenegro
    sr_latn_rs = 0x241A, // Serbian (Latin), Serbia
    sr_latn_cs = 0x081A, // Serbian (Latin), Serbia and Montenegro (Former)
    nso = 0x006C, // Sesotho sa Leboa
    nso_za = 0x046C, // Sesotho sa Leboa, South Africa
    tn = 0x0032, // Setswana
    tn_bw = 0x0832, // Setswana, Botswana
    tn_za = 0x0432, // Setswana, South Africa
    sd = 0x0059, // Sindhi
    sd_arab = 0x7C59, // Sindhi
    sd_arab_pk = 0x0859, // Sindhi, Islamic Republic of Pakistan
    si = 0x005B, // Sinhala
    si_lk = 0x045B, // Sinhala, Sri Lanka
    sk = 0x001B, // Slovak
    sk_sk = 0x041B, // Slovak, Slovakia
    sl = 0x0024, // Slovenian
    sl_si = 0x0424, // Slovenian, Slovenia
    so = 0x0077, // Somali
    so_so = 0x0477, // Somali, Somalia
    st = 0x0030, // Sotho
    st_za = 0x0430, // Sotho, South Africa
    es = 0x000A, // Spanish
    es_ar = 0x2C0A, // Spanish, Argentina
    es_ve = 0x200A, // Spanish, Bolivarian Republic of Venezuela
    es_bo = 0x400A, // Spanish, Bolivia
    es_cl = 0x340A, // Spanish, Chile
    es_co = 0x240A, // Spanish, Colombia
    es_cr = 0x140A, // Spanish, Costa Rica
    es_cu = 0x5c0A, // Spanish, Cuba
    es_do = 0x1c0A, // Spanish, Dominican Republic
    es_ec = 0x300A, // Spanish, Ecuador
    es_sv = 0x440A, // Spanish, El Salvador
    es_gt = 0x100A, // Spanish, Guatemala
    es_hn = 0x480A, // Spanish, Honduras
    es_419 = 0x580A, // Spanish, Latin America
    es_mx = 0x080A, // Spanish, Mexico
    es_ni = 0x4C0A, // Spanish, Nicaragua
    es_pa = 0x180A, // Spanish, Panama
    es_py = 0x3C0A, // Spanish, Paraguay
    es_pe = 0x280A, // Spanish, Peru
    es_pr = 0x500A, // Spanish, Puerto Rico
    es_es_tradnl = 0x040A, // Spanish, Spain
    es_es = 0x0c0A, // Spanish, Spain
    es_us = 0x540A, // Spanish, United States
    es_uy = 0x380A, // Spanish, Uruguay
    sv = 0x001D, // Swedish
    sv_fi = 0x081D, // Swedish, Finland
    sv_se = 0x041D, // Swedish, Sweden
    syr = 0x005A, // Syriac
    syr_sy = 0x045A, // Syriac, Syria
    tg = 0x0028, // Tajik (Cyrillic)
    tg_cyrl = 0x7C28, // Tajik (Cyrillic)
    tg_cyrl_tj = 0x0428, // Tajik (Cyrillic), Tajikistan
    tzm = 0x005F, // Tamazight (Latin)
    tzm_latn = 0x7C5F, // Tamazight (Latin)
    tzm_latn_dz = 0x085F, // Tamazight (Latin), Algeria
    ta = 0x0049, // Tamil
    ta_in = 0x0449, // Tamil, India
    ta_lk = 0x0849, // Tamil, Sri Lanka
    tt = 0x0044, // Tatar
    tt_ru = 0x0444, // Tatar, Russia
    te = 0x004A, // Telugu
    te_in = 0x044A, // Telugu, India
    th = 0x001E, // Thai
    th_th = 0x041E, // Thai, Thailand
    bo = 0x0051, // Tibetan
    bo_cn = 0x0451, // Tibetan, People's Republic of China
    ti = 0x0073, // Tigrinya
    ti_er = 0x0873, // Tigrinya, Eritrea
    ti_et = 0x0473, // Tigrinya, Ethiopia
    ts = 0x0031, // Tsonga
    ts_za = 0x0431, // Tsonga, South Africa
    tr = 0x001F, // Turkish
    tr_tr = 0x041F, // Turkish, Turkey
    tk = 0x0042, // Turkmen
    tk_tm = 0x0442, // Turkmen, Turkmenistan
    uk = 0x0022, // Ukrainian
    uk_ua = 0x0422, // Ukrainian, Ukraine
    hsb = 0x002E, // Upper Sorbian
    hsb_de = 0x042E, // Upper Sorbian, Germany
    ur = 0x0020, // Urdu
    ur_in = 0x0820, // Urdu, India
    ur_pk = 0x0420, // Urdu, Islamic Republic of Pakistan
    ug = 0x0080, // Uyghur
    ug_cn = 0x0480, // Uyghur, People's Republic of China
    uz_cyrl = 0x7843, // Uzbek (Cyrillic)
    uz_cyrl_uz = 0x0843, // Uzbek (Cyrillic), Uzbekistan
    uz = 0x0043, // Uzbek (Latin)
    uz_latn = 0x7C43, // Uzbek (Latin)
    uz_latn_uz = 0x0443, // Uzbek (Latin), Uzbekistan
    ca_es_valencia = 0x0803, // Valencian, Spain
    ve = 0x0033, // Venda
    ve_za = 0x0433, // Venda, South Africa
    vi = 0x002A, // Vietnamese
    vi_vn = 0x042A, // Vietnamese, Vietnam
    cy = 0x0052, // Welsh
    cy_gb = 0x0452, // Welsh, United Kingdom
    wo = 0x0088, // Wolof
    wo_sn = 0x0488, // Wolof, Senegal
    xh = 0x0034, // Xhosa
    xh_za = 0x0434, // Xhosa, South Africa
    ii = 0x0078, // Yi
    ii_cn = 0x0478, // Yi, People's Republic of China
    yi_001 = 0x043D, // Yiddish, World
    yo = 0x006A, // Yoruba
    yo_ng = 0x046A, // Yoruba, Nigeria
    zu = 0x0035, // Zulu
    zu_za = 0x0435, // Zulu, South Africa

    /// Special case
    x_iv_mathan = 0x007F, // LANG_INVARIANT, "math alphanumeric sorting"
};
