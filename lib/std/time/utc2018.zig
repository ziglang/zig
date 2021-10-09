//! This file contains:
//! 1. Epoch reference times in terms of their difference (in seconds, assuming no leap seconds) 
//!    from 1601-01-01T00:00:00 in 2018's UTC. Leap seconds are real, so the actual start
//!    of the Utc2018 Epoch is represented as "1601-01-01T00:00:27"
//!    Practically, this means that:
//!    On Windows: Zig can use FILETIME for accurate time
//!    Other Plaforms: If no leap seconds occur after 2018, Zig is able to use any measure of
//!    "UTC" (with epoch offset as listed below).
//! 2. Tables of past leap seconds
//! 3. Leap Second conversion functions

//! Jan 1 1601 is significant in that it's the beginning of the first 400-year Gregorian 
//! calendar cycle.
//! TAI uses SI seconds, and explicitly has no leap seconds.
//! Assume there are exactly 86,400 SI seconds in each day (even before TAI or UTC existed).
//! The Utc2018 epoch explictly has no leap seconds.
//! Some of the other epochs jump when a leap second occurs (eg. UTC)
//! Some of the other epochs no longer jump when a leap second occurs, 
//! but have a few embedded (forever constant) leap seconds.

//! For converting Utc2018 <==> UTC, make the following assumptions:
//! 1. Between 1601 and 1972, UTC wasn't defined, so assume UT1.
//! 2. At the beginning of 1972, UTC was synchronized to TAI - 10 seconds.
//! 3. Leap seconds between 1972 and 2017 brought UTC = TAI - 37 seconds.
//! 4. After 2018, there are no declared UTC leap seconds:
//!    * UTC = TAI - 37 seconds and there are exactly 86,400 seconds in each day.


/// Jan 01, 0001 AD
pub const clr     = -50491296000;
/// Utc2018 = TAI + utc2018.tai
pub const tai = -37;
/// Jan 01, 1601 AD
pub const windows = 0;
/// Nov 17, 1858 AD
pub const openvms = 8137756800;
/// Jan 01, 1900 AD
pub const zos     = 9435484800;
/// Dec 31, 1967 AD
pub const pickos  = 11581228800;
/// Jan 01, 1970 AD
pub const posix   = 11644473600; 
/// Jan 01, 1978 AD
pub const amiga   = 11896934400;
/// Jan 01, 1980 AD
pub const dos     = 11960006400;
/// Jan 06, 1980 AD
pub const gps     = 11960438400;
/// Jan 01, 2001 AD
pub const ios     = 12622780800;

pub const unix = posix;
pub const android = posix;
pub const os2 = dos;
pub const bios = dos;
pub const vfat = dos;
pub const ntfs = windows;
pub const ntp = zos;
pub const jbase = pickos;
pub const aros = amiga;
pub const morphos = amiga;
pub const brew = gps;
pub const atsc = gps;
pub const go = clr;

const UtcTimeConversionPoint = struct {
    str: []const u8,        // Stringified UTC time of leap second (ends in :60)
    str_after: []const u8,  // Stringified UTC time right after leap second (ends in T00:00:00)
    utc_fuzzy: u36,
    utc_2018: u36,
    offset: u8,
};

// Table of all leap seconds. Useful for converting between "Fuzzy" UTC and Utc2018.
pub const leap_seconds = [_]UtcTimeConversionPoint{
    .{
        // First item isn't actually a leap second, just the start of the Utc2018 Epoch
        .str       = "1601-01-01T00:00:27", // January 1st 1601
        .str_after = "",                    // Not applicable
        .utc_fuzzy = 27,
        .utc_2018  = 0,
        .offset    = 27,
    },
    .{
        .str       = "1972-06-30T23:59:60", // June     30th 1972
        .str_after = "1972-07-01T00:00:00", // July      1st 1972
        .utc_fuzzy = 11644473600 + 78796800,
        .utc_2018  = 11644473600 + 78796800 - 27,
        .offset    = 26,
    },
    .{
        .str       = "1972-12-31T23:59:60", // December 31st 1972
        .str_after = "1973-01-01T00:00:00", // January   1st 1973
        .utc_fuzzy = 11644473600 + 94694400,
        .utc_2018  = 11644473600 + 94694400 - 26,
        .offset    = 25,
    },
    .{
        .str       = "1973-12-31T23:59:60", // December 31st 1973
        .str_after = "1974-01-01T00:00:00", // January   1st 1974
        .utc_fuzzy = 11644473600 + 126230400,
        .utc_2018  = 11644473600 + 126230400 - 25,
        .offset    = 24,
    },
    .{
        .str       = "1974-12-31T23:59:60", // December 31st 1974
        .str_after = "1975-01-01T00:00:00", // January   1st 1975
        .utc_fuzzy = 11644473600 + 157766400,
        .utc_2018  = 11644473600 + 157766400 - 24,
        .offset    = 23,
    },
    .{
        .str       = "1975-12-31T23:59:60", // December 31st 1975
        .str_after = "1976-01-01T00:00:00", // January   1st 1976
        .utc_fuzzy = 11644473600 + 189302400,
        .utc_2018  = 11644473600 + 189302400 - 23,
        .offset    = 22,
    },
    .{
        .str       = "1976-12-31T23:59:60", // December 31st 1976
        .str_after = "1977-01-01T00:00:00", // January   1st 1977
        .utc_fuzzy = 11644473600 + 220924800,
        .utc_2018  = 11644473600 + 220924800 - 22,
        .offset    = 21,
    },
    .{
        .str       = "1977-12-31T23:59:60", // December 31st 1977
        .str_after = "1978-01-01T00:00:00", // January   1st 1978
        .utc_fuzzy = 11644473600 + 252460800,
        .utc_2018  = 11644473600 + 252460800 - 21,
        .offset    = 20,
    },
    .{
        .str       = "1978-12-31T23:59:60", // December 31st 1978
        .str_after = "1979-01-01T00:00:00", // January   1st 1979
        .utc_fuzzy = 11644473600 + 283996800,
        .utc_2018  = 11644473600 + 283996800 - 20,
        .offset    = 19,
    },
    .{
        .str       = "1979-12-31T23:59:60", // December 31st 1979
        .str_after = "1980-01-01T00:00:00", // January   1st 1980
        .utc_fuzzy = 11644473600 + 315532800,
        .utc_2018  = 11644473600 + 315532800 - 19,
        .offset    = 18,
    },
    .{
        .str       = "1981-06-30T23:59:60", // June     30th 1981
        .str_after = "1981-07-01T00:00:00", // July      1st 1981
        .utc_fuzzy = 11644473600 + 362793600,
        .utc_2018  = 11644473600 + 362793600 - 18,
        .offset    = 17,
    },
    .{
        .str       = "1982-06-30T23:59:60", // June     30th 1982
        .str_after = "1982-07-01T00:00:00", // July      1st 1982
        .utc_fuzzy = 11644473600 + 394329600,
        .utc_2018  = 11644473600 + 394329600 - 17,
        .offset    = 16,
    },
    .{
        .str       = "1983-06-30T23:59:60", // June     30th 1983
        .str_after = "1983-07-01T00:00:00", // July      1st 1983
        .utc_fuzzy = 11644473600 + 425865600,
        .utc_2018  = 11644473600 + 425865600 - 16,
        .offset    = 15,
    },
    .{
        .str       = "1985-06-30T23:59:60", // June     30th 1985
        .str_after = "1985-07-01T00:00:00", // July      1st 1985
        .utc_fuzzy = 11644473600 + 489024000,
        .utc_2018  = 11644473600 + 489024000 - 15,
        .offset    = 14,
    },
    .{
        .str       = "1987-12-31T23:59:60", // December 31st 1987
        .str_after = "1988-01-01T00:00:00", // January   1st 1988
        .utc_fuzzy = 11644473600 + 567993600,
        .utc_2018  = 11644473600 + 567993600 - 14,
        .offset    = 13,
    },
    .{
        .str       = "1989-12-31T23:59:60", // December 31st 1989
        .str_after = "1990-01-01T00:00:00", // January   1st 1990
        .utc_fuzzy = 11644473600 + 631152000,
        .utc_2018  = 11644473600 + 631152000 - 13,
        .offset    = 12,
    },
    .{
        .str       = "1990-12-31T23:59:60", // December 31st 1990
        .str_after = "1991-01-01T00:00:00", // January   1st 1991
        .utc_fuzzy = 11644473600 + 662688000,
        .utc_2018  = 11644473600 + 662688000 - 12,
        .offset    = 11,
    },
    .{
        .str       = "1992-06-30T23:59:60", // June     30th 1992
        .str_after = "1992-07-01T00:00:00", // July      1st 1992
        .utc_fuzzy = 11644473600 + 709948800,
        .utc_2018  = 11644473600 + 709948800 - 11,
        .offset    = 10,
    },
    .{
        .str       = "1993-06-30T23:59:60", // June     30th 1993
        .str_after = "1993-07-01T00:00:00", // July      1st 1993
        .utc_fuzzy = 11644473600 + 741484800,
        .utc_2018  = 11644473600 + 741484800 - 10,
        .offset    = 9,
    },
    .{
        .str       = "1994-06-30T23:59:60", // June     30th 1994
        .str_after = "1994-07-01T00:00:00", // July      1st 1994
        .utc_fuzzy = 11644473600 + 773020800,
        .utc_2018  = 11644473600 + 773020800 - 9,
        .offset    = 8,
    },
    .{
        .str       = "1995-12-31T23:59:60", // December 31st 1995
        .str_after = "1996-01-01T00:00:00", // January   1st 1996
        .utc_fuzzy = 11644473600 + 820454400,
        .utc_2018  = 11644473600 + 820454400 - 8,
        .offset    = 7,
    },
    .{
        .str       = "1997-06-30T23:59:60", // June     30th 1997
        .str_after = "1997-07-01T00:00:00", // July      1st 1997
        .utc_fuzzy = 11644473600 + 867715200,
        .utc_2018  = 11644473600 + 867715200 - 7,
        .offset    = 6,
    },
    .{
        .str       = "1998-12-31T23:59:60", // December 31st 1998
        .str_after = "1999-01-01T00:00:00", // January   1st 1999
        .utc_fuzzy = 11644473600 + 915148800,
        .utc_2018  = 11644473600 + 915148800 - 6,
        .offset    = 5,
    },
    .{
        .str       = "2005-12-31T23:59:60", // December 31st 2005
        .str_after = "2006-01-01T00:00:00", // January   1st 2006
        .utc_fuzzy = 11644473600 + 1136073600,
        .utc_2018  = 11644473600 + 1136073600 - 5,
        .offset    = 4,
    },
    .{
        .str       = "2008-12-31T23:59:60", // December 31st 2008
        .str_after = "2009-01-01T00:00:00", // January   1st 2009
        .utc_fuzzy = 11644473600 + 1230768000,
        .utc_2018  = 11644473600 + 1230768000 - 4,
        .offset    = 3,
    },
    .{
        .str       = "2012-06-30T23:59:60", // June     30th 2012
        .str_after = "2012-07-01T00:00:00", // July      1st 2012
        .utc_fuzzy = 11644473600 + 1341100800,
        .utc_2018  = 11644473600 + 1341100800 - 3,
        .offset    = 2,
    },
    .{
        .str       = "2015-06-30T23:59:60", // June     30th 2015
        .str_after = "2015-07-01T00:00:00", // July      1st 2015
        .utc_fuzzy = 11644473600 + 1435708800,
        .utc_2018  = 11644473600 + 1435708800 - 2,
        .offset    = 1,
    },
    .{
        .str       = "2016-12-31T23:59:60", // December 31st 2016
        .str_after = "2017-01-01T00:00:00", // January   1st 2017
        .utc_fuzzy = 11644473600 + 1483228800,
        .utc_2018  = 11644473600 + 1483228800 - 1,
        .offset    = 0,
    },
};

/// Say you find a file with a UTC timestamp from the 1990's...
/// It's slightly unknown how many leap seconds are in this timestamp: It's "fuzzy" UTC.
/// This takes UtcFuzzy seconds since Jan 1 1601 and converts it using a best-effort algorithm 
/// into Utc2018 seconds (offsets it by the approx. number of leap seconds between then and 2018).
/// This has (at best) ~1 second of accuracy: There's no clear answer for how to convert timestamps
/// that occured right around a leap second. Did NTP adjust the time before or after the timestamp
/// was written to disk? Or did the computer even have NTP enabled?
/// Timestamps prior to UTC's creation (1972-01-01T00:00:00) are more ambiguous.
pub fn convertUtcFuzzyToUtc2018(st: u96) u96 {

    const fuzzy_sec = st >> 60;
    const fraction = @truncate(u60, st);

    // PERF: Start with largest timestamps first and work backwards.
    var i = leap_seconds.len - 1;
    while (true) : (i -= 1) {
        if (fuzzy_sec >= leap_seconds[i].utc_fuzzy)
            return ((fuzzy_sec - leap_seconds[i].offset) << 60) + fraction;
        if (i == 0)
            return 0;
    }
}

pub fn convertUtc2018ToUtcFuzzy(st: u96) u96 {

    const seconds = st >> 60;
    const fraction = @truncate(u60, st);

    // PERF: Start with largest timestamps first and work backwards.
    var i = leap_seconds.len - 1;
    while (true) : (i -= 1) {
        if (seconds >= leap_seconds[i].utc_2018)
            return ((seconds + leap_seconds[i].offset) << 60) + fraction;
        if (i == 0)
            return 0;
    }
}

