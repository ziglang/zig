//! This file contains a Gregorian calendar implementation.

//! Jan 1 1601 is significant in that it's the beginning of the first 400-year Gregorian 
//! calendar cycle.
//! Assume there are exactly 86,400 SI seconds in each day (even before TAI or UTC existed).
//! This calendar uses the table of leap seconds to create UTC CalendarTime structures.

//! For converting Utc2018 <==> UTC, make the following assumptions:
//! 1. Between 1601 and 1972, UTC wasn't defined, so assume UT1.
//! 2. At the beginning of 1972, UTC was synchronized to TAI - 10 seconds.
//! 3. Leap seconds between 1972 and 2017 brought UTC = TAI - 37 seconds.
//! 4. After 2018, there are no declared UTC leap seconds:
//!    * UTC = TAI - 37 seconds and there are exactly 86,400 seconds in each day.

const std = @import("std.zig");
const math = std.math;
const builtin = std.builtin;
const target = builtin.target;
const assert = std.debug.assert;
const testing = std.testing;
const time = std.time;
const utc2018 = std.time.utc2018;
const os = std.os;
const parseInt = std.fmt.parseInt;

const stdTimeFromSeconds = time.stdTimeFromSeconds;
const convertUtcFuzzyToUtc2018 = utc2018.convertUtcFuzzyToUtc2018;
const convertUtc2018ToUtcFuzzy = utc2018.convertUtc2018ToUtcFuzzy;

const leap_seconds = utc2018.leap_seconds;

/// Calendar computed from Zig's std Utc2018 epoch using the Gregorian Calendar
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

pub fn calendarTimeFromStdTime(st: u96) CalendarTime {
    // Zig std Utc2018 is specified in 36.60 fixed-point format. Shift out the fractional part...
    var s = time.secondsPartOfStdTime(st);

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
        .nanosecond = time.nsPartOfStdTime(st),
        .day_of_week = @intCast(u3, day_of_week),
        .day_of_year = @intCast(u9, day_of_year),
    };
}

const years_per_gregorian = 400;
const years_per_century = 100;
const years_per_julian = 4;

pub fn stdTimeFromCalendarTime(ct: CalendarTime) !u96 {
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
    
    const utc_2018_seconds = stdTimeFromSeconds(convertUtcFuzzyToUtc2018(utc_fuzzy_seconds));

    const utc_2018_fractional_seconds = ((@as(u90, ct.nanosecond) << 60) / time.ns_per_s);
    return utc_2018_seconds + utc_2018_fractional_seconds; 
}

fn checkStdTimeSeconds(str: []const u8, s: u36) !void {
    const st = stdTimeFromSeconds(s);
    try testing.expect(calendarTimeFromStdTime(st).eql(try CalendarTime.fromStr(str)));
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

    try testing.expect(ct.eql(try CalendarTime.fromStr(str)));
}


test "Calendar from UTC Timestamps" {

    try checkStdTimeSeconds("1601-01-01T00:00:27", 0);
    try checkStdTimeSeconds("1601-01-01T00:00:28", 1);
    try checkStdTimeSeconds("1601-01-01T00:00:29", 2);
    try checkStdTimeSeconds("1969-12-31T23:59:59", utc2018.posix - 28);
    try checkStdTimeSeconds("1970-01-01T00:00:00", utc2018.posix - 27);
    try checkStdTimeSeconds("1970-01-01T00:00:27", utc2018.posix);

    try checkStdTimeSeconds("1980-01-06T00:00:18", utc2018.gps);


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

