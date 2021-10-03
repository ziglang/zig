//0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
//! This file contains:
//! 1. Epoch reference times in terms of their difference (in seconds, assuming no leap seconds) 
//!    from 1601-01-01T00:00:00 in 2018's UTC. Leap seconds are real, so the actual start
//!    of the Utc2018 Epoch is represented as "1601-01-01T00:00:27"
//!    Practically, this means that:
//!    On Windows: Zig can use FILETIME for accurate time
//!    Other Plaforms: If no leap seconds occur after 2018, Zig is able to use any measure of
//!    "UTC" (with epoch offset as listed below).
//! 2. Tables of past leap seconds
//! 3. A Windows "now()" implementation using consistent Utc2018 time
//! 4. A Posix "now()" implementation that tries to use CLOCK_TAI to give consistent Utc2018 time
//!    but has a fallback to assume CLOCK_REALTIME is in 2018's UTC.
//! 5. A Gregorian calendar implementation.
//! 6. Conversion functions

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
//!
//! Windows: FILETIME is stable and doesn't have leap seconds. It's now (as of June 2018 update) 
//! defined as Utc2018 and will stay that way. Windows has APIs to convert to UTC that takes 
//! into account leap seconds after 2018 and is kept up-to-date with Windows Update.
//! 
//! POSIX: If CLOCK_TAI appears configured, use that. Then use a compile-time constant (always 37)
//! to convert to Utc2018. However, CLOCK_TAI is often unconfigured (zero or 1 delta from
//! CLOCK_REALTIME). If unconfigured, (or unavailable), make the assumption that there are no
//! more UTC leap seconds after 2018.
//!                           !!!WARNING!!! 
//! If a leap second is announced (WHY?!), the above assumption MUST be revisited.
//! Non-Windows Zig code deployed into distributed systems that care about accurate 
//! timestamps (and doesn't configure CLOCK_TAI) needs to be updated and re-compiled after 
//! a leap second is declared.
//! Consider letting the International Telecommunications Union know exactly what you think 
//! of leap seconds. As of 2021, they are considering removing them going forward.

const std = @import("std.zig");
const math = std.math;
const builtin = std.builtin;
const target = builtin.target;
const assert = std.debug.assert;
const testing = std.testing;
const time = std.time;
const os = std.os;
const parseInt = std.fmt.parseInt;

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

pub const UtcTimeConversionPoint = struct {
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




const Impl = switch (target.os.tag) {
    .windows => WindowsImpl,
    else => PosixImpl,
};

const PosixImpl = struct {

    // The CLOCK_ID to use in os.clock_gettime() to get Utc2018. 
    // Must be detected with detectClockId().
    var clock_id: i32 = math.maxInt(i32);
    
    // The offset (in seconds) to get Utc2018. Must be detected with detectClockId().
    var clock_offset: i8 = 0;

    fn detectClockId() !void {
        while (true) {
            var utc_ts: os.timespec = undefined;
            os.clock_gettime(os.CLOCK.REALTIME, &utc_ts) catch return error.UnsupportedClock;

            if (builtin.os.tag == .wasi) {
                clock_id = os.CLOCK.REALTIME;
                return;
            }
                
            var tai_ts: os.timespec = undefined;
            os.clock_gettime(os.CLOCK.TAI, &tai_ts) catch {
                // CLOCK.TAI unsupported, use CLOCK_REALTIME and assume no leap seconds
                clock_id = os.CLOCK.REALTIME;
                return;
            };

            var utc_ts2: os.timespec = undefined;
            try os.clock_gettime(os.CLOCK.REALTIME, &utc_ts2);
            if (utc_ts.tv_sec != utc_ts2.tv_sec) {
                // tv_sec rolled over between utc_ts and utc_ts2, try again.
                // Shouldn't happen a second time
                continue;
            }

            const offset = tai_ts.tv_sec - utc_ts.tv_sec;
            if (offset < 0) {
                // Offset doesn't make any sense: No possible way that Earth 
                // spun up that much.
                // CLOCK.TAI unsupported, use CLOCK_REALTIME and assume no leap seconds
                clock_id = os.CLOCK.REALTIME;
            } else if (offset <= 1) {
                // Assume the epoch of CLOCK_TAI is 2018's UTC (assuming no leap seconds).
                clock_id = os.CLOCK.TAI;
                clock_offset = 0;
            } else if (offset > 1000) {
                // CLOCK_TAI seems to be configured, but the offset doesn't make any sense: 
                // No possible way that Earth slowed down its spin that much.
                // CLOCK.TAI unsupported, use CLOCK_REALTIME and assume no leap seconds
                clock_id = os.CLOCK.REALTIME;
            } else {
                // CLOCK_TAI is configured, assume it's actually TAI.
                clock_id = os.CLOCK.TAI;

                // Use the constant offset between TAI and Utc2018.
                clock_offset = tai;
            }
        }
    }

    fn now() !u64 {
        if (clock_id == math.maxInt(i32)) {
            // Unknown clock_id, run the detection algorithm once
            try detectClockId();
        }
        
        var ts: os.timespec = undefined;
        os.clock_gettime(clock_id, &ts) catch return error.UnsupportedClock;

        // Convert to Utc2018 seconds
        ts.tv_sec += (posix + clock_offset);

        // Fixed-point math. Move to the left for 60 bits of fraction.  
        const utc2018_seconds_68_60 = @as(u128, ts.tv_sec) << 60;
        const utc2018_ns_68_60 = @as(u128, ts.tv_nsec) << 60;
        
        // Convert from 1ns units to seconds.
        // Fractional part remains in the 60 lowest bits.
        const st_68_60 = utc2018_seconds_68_60 + (utc2018_ns_68_60 / time.ns_per_s);

        // Truncate to a reasonable range and precision (remove 32 bits on both ends)
        return @truncate(u64, st_68_60 >> 32);
    }
};

const WindowsImpl = struct {
    fn now() !u64 {
        // FileTime has a granularity of 100ns and uses the NTFS/Windows epoch.
        // Matches Zig's Utc2018 epoch.
        // Explicitly doesn't have leap seconds (as of June 2018).
        var ft: os.windows.FILETIME = undefined;
        os.windows.kernel32.GetSystemTimePreciseAsFileTime(&ft);

        // Fixed-point math. Move to the left for 60 bits of fraction.  
        const ft_68_60 = @as(u128, ft) << 60;

        // Convert from 100ns units to seconds. 10_000_000 100ns units per second.
        // Fractional part remains in the 60 lowest bits.
        const st_68_60 = ft_68_60 / (time.ns_per_s / 100);

        // Truncate to a reasonable range and precision (remove 32 bits on both ends) 
        return @truncate(u64, st_68_60 >> 32);
    }
};

pub fn now() !u64 {
    return Impl.now();
}

pub fn stdTimeFromSeconds(s: u36) u64 {
    // Zig std time is fixed-point 36.28
    // The 28 bits of fraction are zero in this case
    return @as(u64, s) << 28;
}

pub fn secondsFromStdTime(st: u64) u36 {
    // Zig std time is fixed-point 36.28
    // Shift out the 28 bits of fraction
    return @truncate(u36, st >> 28);
}

/// Say you find a file with a UTC timestamp from the 1990's...
/// It's unknown how many leap seconds are in this timestamp: It's "fuzzy" UTC.
/// This takes UtcFuzzy seconds since Jan 1 1601 and converts it using a best-effort algorithm 
/// into Utc2018 seconds (offsets it by the approx. number of leap seconds between then and 2018).
/// This has (at best) ~1 second of accuracy: There's no clear answer for how to convert timestamps
/// that occured right around a leap second. Did NTP adjust the time before or after the timestamp
/// was written to disk? Or did the computer even have NTP enabled?
/// Timestamps prior to UTC's creation (1972-01-01T00:00:00) are even less accurate.
pub fn convertUtcFuzzyToUtc2018(fuzzy_sec: u64) u64 {

    // PERF: Start with largest timestamps first and work backwards.
    var i = leap_seconds.len - 1;
    while (true) {
        if (fuzzy_sec >= leap_seconds[i].utc_fuzzy)
            return fuzzy_sec - leap_seconds[i].offset;
        
        if (i == 0)
            return 0;
        
        i -= 1;
    }
}

pub fn convertUtc2018ToUtcFuzzy(s: u64) u64 {

    // PERF: Start with largest timestamps first and work backwards.
    var i = leap_seconds.len - 1;
    while (true) {
        if (s >= leap_seconds[i].utc_2018)
            return s + leap_seconds[i].offset;
        
        if (i == 0)
            return 0;
        
        i -= 1;
    }
}

/// Timestamp computed from Zig's std Utc2018 epoch using the Gregorian Calendar
pub const CalendarTime = struct {
    year: u12,        // 1601 - 3780
    month: u4,        // 1-12
    day: u5,          // 1-31
    hour: u5,         // 0-23
    minute: u6,       // 0-59
    second: u6,       // 0-60 (REMEMBER THE LEAP SECOND)
    nanosecond: u30,  // 0-999_999_999
    
    // These can be ignored when creating a CalendarTime from scratch
    day_of_week: u3 = 0,  // 0-6  (0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat)
    day_of_year: u9 = 0,  // 0-365 (days since Jan 1)

    /// Init using UTC Date and Time strings in ISO 8601. Eg:
    /// "2021-09-28"
    /// "2021-09-28T04:10:21Z"
    /// "2021-09-28T04:10:21.3Z"
    /// "2021-09-28T04:10:21.35634543Z"
    /// TODO: Support time zones
    /// Years 1601 - 3780 supported
    /// TODO: Should this support day_of_week? If so, use Zeller's Congruence
    /// TODO: Should this support day_of_year?
    pub fn fromStr(str: []const u8) !CalendarTime {
        const nanosecond: u30 = blk: {
            if (str.len < 21) break :blk 0;
            if (str[19] != '.') break :blk 0;

            var end: u32 = 20;
            if (!std.ascii.isDigit(str[end])) break :blk 0;

            while (end != str.len and std.ascii.isDigit(str[end])) {
                end += 1;
            }

            var denominator_digits = end - 19;
            if (denominator_digits > 9) {
                // Better than nanosecond resolution. 
                // TODO: Support digits past nanoseconds.
                break :blk try parseInt(u30, str[20..29], 10);
            }

            var fraction = try parseInt(u30, str[20..end], 10);
            while (denominator_digits < 9) {
                fraction *= 10;
                denominator_digits += 1;
            }
            break :blk fraction;
        };

        return CalendarTime {
            .year = try parseInt(u12, str[0..4], 10),
            .month = try parseInt(u4, str[5..7], 10),
            .day = try parseInt(u5, str[8..10], 10),
            .hour = if (str.len >= 12) try parseInt(u5, str[11..13], 10) else 0,
            .minute = if (str.len >= 15) try parseInt(u6, str[14..16], 10) else 0,
            .second = if (str.len >= 18) try parseInt(u6, str[17..19], 10) else 0,
            .nanosecond = nanosecond,
        };
    }

    fn eql(self: CalendarTime, other: CalendarTime) bool {
        return (self.year == other.year) and
               (self.month == other.month) and
               (self.day == other.day) and
               (self.hour == other.hour) and
               (self.minute == other.minute) and
               (self.second == other.second) and
               (self.nanosecond == other.nanosecond);
    }
};

const s_per_day = time.s_per_day;
const days_per_year = 365;
const days_per_leapyear = 366;

// There are 100-4+1=97 leap years every 400 years:
// * Leap year every year evenly divisible by 4, (+100)
// * except the years evenly divisible by 100 are not, (-4),
// * except the years evenly divisible by 400 actually are (+1)
const days_per_gregorian = (days_per_leapyear * 97) + (days_per_year * 303);

// There are 25-1=24 leap years in most centuries.
const days_per_normal_century = (days_per_leapyear * 24) + (days_per_year * 76);

// There in 1 leap year in most 4-years.
const days_per_normal_julian = days_per_leapyear + (days_per_year * 3);

const days_january = 31;
const days_leap_feb = 29;
const days_february = 28;

const days_march = 31;
const days_april = 30;
const days_may = 31;
const days_june = 30;
const days_july = 31;

const days_august = 31;
const days_september = 30;
const days_october = 31;
const days_november = 30;
const days_december = 31;

pub fn calendarTimeFromStdTime(st: u64) CalendarTime {
    // Zig std Utc2018 is specified in 36.28 fixed-point format. Shift out the fractional part...
    var s = @truncate(u36, st >> 28);

    // Convert it to "fuzzy" Utc
    // PERF: Start with largest timestamps first and work backwards.
    var i = leap_seconds.len - 1;
    var is_leap_second = false;
    while (i > 0) : (i -= 1) {
        // Is 's' the second before this leap second or later?
        const delta = @as(i37, s) - leap_seconds[i].utc_2018;
        if (delta >= 0) {
            if (delta == 0) {
                // 's' lands on a leap second.
                // TODO: @cold(true);

                // Pretend it's the second before for the purposes of calculating the date, then
                // use is_leap_second to add one to the 'second' field (to make it 60).
                is_leap_second = true;
                s -= 1;
            }
            break;
        }
    }
    const offset = leap_seconds[i].offset;

    // Drop to a u32 to save some time on all these division ops
    const days = @intCast(u32, (s + offset) / s_per_day);
    const second_of_day = @intCast(u32, (s + offset) % s_per_day);

    // A 'gregorian' is 400 years
    const gregorian = days / days_per_gregorian;
    const day_of_gregorian = days % days_per_gregorian;

    // day 0 of the gregorian is always a Monday.
    const day_of_week = (day_of_gregorian + 6) % 7;

    // a century is 100 years
    const century = day_of_gregorian / days_per_normal_century;
    const day_of_century = day_of_gregorian % days_per_normal_century;

    // a julian is 4 years
    const julian = day_of_century / days_per_normal_julian;
    const day_of_julian = day_of_century % days_per_normal_julian;

    // Single year
    var year_of_julian: u32 = undefined;
    var day_of_year: u32 = undefined;
    switch (day_of_julian / days_per_year)
    {
        0 => {
            year_of_julian = 0;
            day_of_year = day_of_julian;
        },
        1 => {
            year_of_julian = 1;
            day_of_year = day_of_julian - days_per_year;
        },
        2 => {
            year_of_julian = 2;
            day_of_year = day_of_julian - (2 * days_per_year);
        },
        3,4 => { // The last day of a leap year results in '4', but it's really still '3'
            year_of_julian = 3;
            day_of_year = day_of_julian - (3 * days_per_year);
        },
        else => unreachable,
    }

    var day_of_month = day_of_year;
    const month = blk: {
        if (day_of_month < days_january) {
            break :blk 1; // January
        } else {
            day_of_month -= days_january;

            const is_leap_year = (year_of_julian == 3) and ((julian != 24) or (century == 3));

            if (is_leap_year) {
                if (day_of_month < days_leap_feb) {
                    break :blk 2; // February
                }
                day_of_month -= days_leap_feb;
            } else {
                if (day_of_month < days_february) {
                    break :blk 2; // February
                }
                day_of_month -= days_february;
            }

            // March-July have the same days as August-December
            var month_base: u16 = undefined;
            if (day_of_month < days_march + days_april + days_may + days_june + days_july) {
                month_base = 3;
            } else {
                month_base = 8;
                day_of_month -= days_march + days_april + days_may + days_june + days_july;
            }

            // 31,30 month-pair pattern repeats
            const month_pair = day_of_month / (31 + 30);
            day_of_month %= (31 + 30);
            
            if (day_of_month < 31) {
                break :blk (month_base + (month_pair * 2));
            } else {
                day_of_month -= 31;
                break :blk (month_base + (month_pair * 2) + 1);
            }
        }
    };

    const hour_of_day = second_of_day / time.s_per_hour;
    const second_of_hour = second_of_day % time.s_per_hour;

    const minute_of_hour = second_of_hour / time.s_per_min;
    const second_of_minute = second_of_hour % time.s_per_min;

    const year = 1601 + (gregorian * 400) + (century * 100) + (julian * 4) + year_of_julian;

    if (month == 0) unreachable;
    if (month > 12) unreachable;

    return .{
        .year = @intCast(u12, year),
        .month = @intCast(u4, month),
        .day = @intCast(u5, day_of_month + 1), // +1 to move from 0-indexed to 1-indexed
        .hour = @intCast(u5, hour_of_day),
        .minute = @intCast(u6, minute_of_hour),
        .second = if (is_leap_second) 60 else @intCast(u6, second_of_minute),
        .nanosecond = nanosecondPartOfStdTime(st),
        .day_of_week = @intCast(u3, day_of_week),
        .day_of_year = @intCast(u9, day_of_year),
    };
}

const years_per_gregorian = 400;
const years_per_century = 100;
const years_per_julian = 4;

pub fn stdTimeFromCalendarTime(ct: CalendarTime) !u64 {
    if (ct.year < 1601 or ct.year >= 3780)
        return error.Format;
    if (ct.month < 1 or ct.month > 12)
        return error.Format;
    if (ct.day < 1 or ct.day > 31)
        return error.Format;
    if (ct.hour > 23 or ct.minute > 59 or ct.second > 60)
        return error.Format;
    if (ct.nanosecond > 999_999_999)
        return error.Format;

    const gregorian = ct.year / years_per_gregorian;
    const year_of_gregorian = ct.year % years_per_gregorian;

    const century = year_of_gregorian / years_per_century;
    const year_of_century = year_of_gregorian % years_per_century;

    const julian = year_of_century / years_per_julian;
    const year_of_julian = year_of_century % years_per_julian;

    var days = (gregorian * days_per_gregorian) +
               (century * days_per_normal_century) +
               (julian * days_per_normal_julian) +
               (year_of_julian * days_per_year);
    
    days += blk: {
        if (ct.month == 1) { // January
            break :blk ct.day - 1; // zero index the day
        } else {
            var day_of_year = ct.day - 1; // zero index the day
            day_of_year += days_january;

            if (ct.month == 2) { // February
                break :blk day_of_year;
            }

            const is_leap_year = (year_of_julian == 3) and ((julian != 24) or (century == 3));

            day_of_year += if (is_leap_year) days_leap_feb else days_february;

            // March-July have the same days as August-December
            var month_base = undefined;
            if (ct.month > 7) {
                day_of_year += days_march + days_april + days_may + days_june + days_july;
                month_base - 8;
            } else {
                month_base - 3;
            }

            const month_pair = month_base / 2;
            
            // 31,30 month-pair pattern repeats
            day_of_year += (31 + 30) * month_pair;

            if (month_base % 1 == 1) { // April, June, September, November
                day_of_year += 31;
            } else { // March, May, July, August, October, December
            }
            
            day_of_year += ct.day;
            break :blk day_of_year;
        }
    };

    const utc_fuzzy_seconds = (days * s_per_day) + 
                              (ct.hour * time.s_per_hour) +
                              (ct.min * time.s_per_min) +
                              ct.second;
    
    const utc_2018_seconds = convertUtcFuzzyToUtc2018(utc_fuzzy_seconds);

    const utc_2018_fractional_seconds = ((@as(u58, ct.nanosecond) << 28) / time.ns_per_s);
    return utc_2018_seconds + utc_2018_fractional_seconds; 
}

fn checkStdTimeSeconds(str: []const u8, s: u36) !void {
    const st = stdTimeFromSeconds(s);
    assert(calendarTimeFromStdTime(st).eql(try CalendarTime.fromStr(str)));
}

fn checkRoundTripCalendarTimeStringSeconds(s: u36) !void {
    const ct = calendarTimeFromStdTime(stdTimeFromSeconds(s));
    var buf: [30]u8 = undefined;
    var str = try std.fmt.bufPrint(buf[0..], "{}-{:02}-{:02}T{:02}:{:02}:{:02}", 
                                   .{ct.year, ct.month, ct.day, ct.hour, ct.minute, ct.second});

    // std.fmt.bufPrint doesn't (yet?) support leading zeros
    for (str) |*c| {
        if (c.* == ' ')
            c.* = '0';
    }

    assert(ct.eql(try CalendarTime.fromStr(str)));
}


test "Calendar from UTC Timestamps" {

    try checkStdTimeSeconds("1601-01-01T00:00:27", 0);
    try checkStdTimeSeconds("1601-01-01T00:00:28", 1);
    try checkStdTimeSeconds("1601-01-01T00:00:29", 2);
    try checkStdTimeSeconds("1969-12-31T23:59:59", posix - 28);
    try checkStdTimeSeconds("1970-01-01T00:00:00", posix - 27);
    try checkStdTimeSeconds("1970-01-01T00:00:27", posix);

    try checkStdTimeSeconds("1980-01-06T00:00:18", gps);


    try checkStdTimeSeconds("1972-06-30T23:59:59", leap_seconds[1].utc_2018 - 1);
    try checkStdTimeSeconds("1972-06-30T23:59:60", leap_seconds[1].utc_2018);
    try checkStdTimeSeconds("1972-07-01T00:00:00", leap_seconds[1].utc_2018 + 1);

    try checkStdTimeSeconds("1972-12-31T23:59:59", leap_seconds[2].utc_2018 - 1);
    try checkStdTimeSeconds("1973-01-01T00:00:00", leap_seconds[2].utc_2018 + 1);

    try checkRoundTripCalendarTimeStringSeconds(0);
    try checkRoundTripCalendarTimeStringSeconds(1);

    var i: u8 = 1; // The first item in the table isn't actually a leap second
    while (i < leap_seconds.len) : (i += 1) {
        try checkRoundTripCalendarTimeStringSeconds(leap_seconds[i].utc_2018 - 1);
        try checkRoundTripCalendarTimeStringSeconds(leap_seconds[i].utc_2018);
        try checkRoundTripCalendarTimeStringSeconds(leap_seconds[i].utc_2018 + 1);

        // The table has a stringified UTC for each leap second
        try checkStdTimeSeconds(leap_seconds[i].str, leap_seconds[i].utc_2018);

        // The table has a stringified UTC for the point after each leap second
        try checkStdTimeSeconds(leap_seconds[i].str_after, leap_seconds[i].utc_2018 + 1);

        var buf: [30]u8 = undefined;
        var str_before = buf[0..leap_seconds[i].str.len];
        std.mem.copy(u8, str_before, leap_seconds[i].str);
        str_before[17] = '5';
        str_before[18] = '9';
        try checkStdTimeSeconds(str_before, leap_seconds[i].utc_2018 - 1);
        str_before[17] = '5';
        str_before[18] = '8';
        try checkStdTimeSeconds(str_before, leap_seconds[i].utc_2018 - 2);
    }
}

pub fn nanosecondPartOfStdTime(st: u64) u30 {
    // Truncate to the fractional part in the lower 28 bits,
    // Add another 30 bits (u58) to work with.
    // Multiply by the number of ns_per_s.
    const s = @as(u58, @truncate(u28, st)) * time.ns_per_s;

    // Shift out the fractional part.
    return @truncate(u30, s >> 28);
}
