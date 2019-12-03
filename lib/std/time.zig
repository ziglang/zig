const builtin = @import("builtin");
const std = @import("std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;
const math = std.math;

pub const epoch = @import("time/epoch.zig");
pub const timezone = @import("time/timezone.zig");
pub const Timezone = timezone.Timezone;

/// Spurious wakeups are possible and no precision of timing is guaranteed.
pub fn sleep(nanoseconds: u64) void {
    if (builtin.os == .windows) {
        const ns_per_ms = ns_per_s / ms_per_s;
        const big_ms_from_ns = nanoseconds / ns_per_ms;
        const ms = math.cast(os.windows.DWORD, big_ms_from_ns) catch math.maxInt(os.windows.DWORD);
        os.windows.kernel32.Sleep(ms);
        return;
    }
    const s = nanoseconds / ns_per_s;
    const ns = nanoseconds % ns_per_s;
    std.os.nanosleep(s, ns);
}

/// Get the posix timestamp, UTC, in seconds
/// TODO audit this function. is it possible to return an error?
pub fn timestamp() u64 {
    return @divFloor(milliTimestamp(), ms_per_s);
}

/// Get the posix timestamp, UTC, in milliseconds
/// TODO audit this function. is it possible to return an error?
pub fn milliTimestamp() u64 {
    if (builtin.os == .windows) {
        //FileTime has a granularity of 100 nanoseconds
        //  and uses the NTFS/Windows epoch
        var ft: os.windows.FILETIME = undefined;
        os.windows.kernel32.GetSystemTimeAsFileTime(&ft);
        const hns_per_ms = (ns_per_s / 100) / ms_per_s;
        const epoch_adj = epoch.windows * ms_per_s;

        const ft64 = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
        return @divFloor(ft64, hns_per_ms) - -epoch_adj;
    }
    if (builtin.os == .wasi and !builtin.link_libc) {
        var ns: os.wasi.timestamp_t = undefined;

        // TODO: Verify that precision is ignored
        const err = os.wasi.clock_time_get(os.wasi.CLOCK_REALTIME, 1, &ns);
        assert(err == os.wasi.ESUCCESS);

        const ns_per_ms = 1000;
        return @divFloor(ns, ns_per_ms);
    }
    if (comptime std.Target.current.isDarwin()) {
        var tv: os.darwin.timeval = undefined;
        var err = os.darwin.gettimeofday(&tv, null);
        assert(err == 0);
        const sec_ms = tv.tv_sec * ms_per_s;
        const usec_ms = @divFloor(tv.tv_usec, us_per_s / ms_per_s);
        return @intCast(u64, sec_ms + usec_ms);
    }
    var ts: os.timespec = undefined;
    //From what I can tell there's no reason clock_gettime
    //  should ever fail for us with CLOCK_REALTIME,
    //  seccomp aside.
    os.clock_gettime(os.CLOCK_REALTIME, &ts) catch unreachable;
    const sec_ms = @intCast(u64, ts.tv_sec) * ms_per_s;
    const nsec_ms = @divFloor(@intCast(u64, ts.tv_nsec), ns_per_s / ms_per_s);
    return sec_ms + nsec_ms;
}

/// Multiples of a base unit (nanoseconds)
pub const nanosecond = 1;
pub const microsecond = 1000 * nanosecond;
pub const millisecond = 1000 * microsecond;
pub const second = 1000 * millisecond;
pub const minute = 60 * second;
pub const hour = 60 * minute;

/// Divisions of a second
pub const ns_per_s = 1000000000;
pub const us_per_s = 1000000;
pub const ms_per_s = 1000;
pub const cs_per_s = 100;

/// Common time divisions
pub const s_per_min = 60;
pub const s_per_hour = s_per_min * 60;
pub const s_per_day = s_per_hour * 24;
pub const s_per_week = s_per_day * 7;
pub const ms_per_day = s_per_day * ms_per_s;
pub const ms_per_hour = s_per_hour * ms_per_s;
pub const ms_per_min = s_per_min * ms_per_s;

/// A monotonic high-performance timer.
/// Timer.start() must be called to initialize the struct, which captures
///   the counter frequency on windows and darwin, records the resolution,
///   and gives the user an opportunity to check for the existnece of
///   monotonic clocks without forcing them to check for error on each read.
/// .resolution is in nanoseconds on all platforms but .start_time's meaning
///   depends on the OS. On Windows and Darwin it is a hardware counter
///   value that requires calculation to convert to a meaninful unit.
pub const Timer = struct {
    ///if we used resolution's value when performing the
    ///  performance counter calc on windows/darwin, it would
    ///  be less precise
    frequency: switch (builtin.os) {
        .windows => u64,
        .macosx, .ios, .tvos, .watchos => os.darwin.mach_timebase_info_data,
        else => void,
    },
    resolution: u64,
    start_time: u64,

    const Error = error{TimerUnsupported};

    ///At some point we may change our minds on RAW, but for now we're
    ///  sticking with posix standard MONOTONIC. For more information, see:
    ///  https://github.com/ziglang/zig/pull/933
    const monotonic_clock_id = os.CLOCK_MONOTONIC;
    /// Initialize the timer structure.
    //This gives us an opportunity to grab the counter frequency in windows.
    //On Windows: QueryPerformanceCounter will succeed on anything >= XP/2000.
    //On Posix: CLOCK_MONOTONIC will only fail if the monotonic counter is not
    //  supported, or if the timespec pointer is out of bounds, which should be
    //  impossible here barring cosmic rays or other such occurrences of
    //  incredibly bad luck.
    //On Darwin: This cannot fail, as far as I am able to tell.
    pub fn start() Error!Timer {
        var self: Timer = undefined;

        if (builtin.os == .windows) {
            self.frequency = os.windows.QueryPerformanceFrequency();
            self.resolution = @divFloor(ns_per_s, self.frequency);
            self.start_time = os.windows.QueryPerformanceCounter();
        } else if (comptime std.Target.current.isDarwin()) {
            os.darwin.mach_timebase_info(&self.frequency);
            self.resolution = @divFloor(self.frequency.numer, self.frequency.denom);
            self.start_time = os.darwin.mach_absolute_time();
        } else {
            //On Linux, seccomp can do arbitrary things to our ability to call
            //  syscalls, including return any errno value it wants and
            //  inconsistently throwing errors. Since we can't account for
            //  abuses of seccomp in a reasonable way, we'll assume that if
            //  seccomp is going to block us it will at least do so consistently
            var ts: os.timespec = undefined;
            os.clock_getres(monotonic_clock_id, &ts) catch return error.TimerUnsupported;
            self.resolution = @intCast(u64, ts.tv_sec) * @as(u64, ns_per_s) + @intCast(u64, ts.tv_nsec);

            os.clock_gettime(monotonic_clock_id, &ts) catch return error.TimerUnsupported;
            self.start_time = @intCast(u64, ts.tv_sec) * @as(u64, ns_per_s) + @intCast(u64, ts.tv_nsec);
        }

        return self;
    }

    /// Reads the timer value since start or the last reset in nanoseconds
    pub fn read(self: *Timer) u64 {
        var clock = clockNative() - self.start_time;
        if (builtin.os == .windows) {
            return @divFloor(clock * ns_per_s, self.frequency);
        }
        if (comptime std.Target.current.isDarwin()) {
            return @divFloor(clock * self.frequency.numer, self.frequency.denom);
        }
        return clock;
    }

    /// Resets the timer value to 0/now.
    pub fn reset(self: *Timer) void {
        self.start_time = clockNative();
    }

    /// Returns the current value of the timer in nanoseconds, then resets it
    pub fn lap(self: *Timer) u64 {
        var now = clockNative();
        var lap_time = self.read();
        self.start_time = now;
        return lap_time;
    }

    fn clockNative() u64 {
        if (builtin.os == .windows) {
            return os.windows.QueryPerformanceCounter();
        }
        if (comptime std.Target.current.isDarwin()) {
            return os.darwin.mach_absolute_time();
        }
        var ts: os.timespec = undefined;
        os.clock_gettime(monotonic_clock_id, &ts) catch unreachable;
        return @intCast(u64, ts.tv_sec) * @as(u64, ns_per_s) + @intCast(u64, ts.tv_nsec);
    }
};

test "sleep" {
    sleep(1);
}

test "timestamp" {
    const ns_per_ms = (ns_per_s / ms_per_s);
    const margin = 50;

    const time_0 = milliTimestamp();
    sleep(ns_per_ms);
    const time_1 = milliTimestamp();
    const interval = time_1 - time_0;
    testing.expect(interval > 0 and interval < margin);
}

test "Timer" {
    const ns_per_ms = (ns_per_s / ms_per_s);
    const margin = ns_per_ms * 150;

    var timer = try Timer.start();
    sleep(10 * ns_per_ms);
    const time_0 = timer.read();
    testing.expect(time_0 > 0 and time_0 < margin);

    const time_1 = timer.lap();
    testing.expect(time_1 >= time_0);

    timer.reset();
    testing.expect(timer.read() < time_1);
}


pub const Weekday = enum(u4){
    Monday = 1,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,
    Sunday,
};

pub const Month = enum(u4) {
    January = 1,
    February,
    March,
    April,
    May,
    June,
    July,
    August,
    September,
    October,
    November,
    December
};


pub const MIN_YEAR: u16 = 1;
pub const MAX_YEAR: u16 = 9999;
pub const MAX_ORDINAL: u32 = 3652059;

// Number of days in each month not accounting for leap year
const DAYS_IN_MONTH = [12]u8{
    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
const DAYS_BEFORE_MONTH = [12]u16{
    0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334};

pub fn isLeapYear(year: u32) bool {
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
}

pub fn isLeapDay(year: u32, month: u32, day: u32) bool {
    return isLeapYear(year) and month == 2 and day == 29;
}

test "leapyear" {
    testing.expect(isLeapYear(2019) == false);
    testing.expect(isLeapYear(2018) == false);
    testing.expect(isLeapYear(2017) == false);
    testing.expect(isLeapYear(2016) == true);
    testing.expect(isLeapYear(2000) == true);
    testing.expect(isLeapYear(1900) == false);
}

// Number of days before Jan 1st of year
pub fn daysBeforeYear(year: u32) u32 {
    var y: u32 = year - 1;
    return y*365 + @divFloor(y, 4) - @divFloor(y, 100) + @divFloor(y, 400);
}

// Days before 1 Jan 1970
const utc_days = daysBeforeYear(1970) + 1;

test "daysBeforeYear" {
    testing.expect(daysBeforeYear(1996) == 728658);
    testing.expect(daysBeforeYear(2019) == 737059);
}

// Number of days in that month for the year
pub fn daysInMonth(year: u32, month: u32) u8 {
    assert(1 <= month and month <= 12);
    if (month == 2 and isLeapYear(year)) return 29;
    return DAYS_IN_MONTH[month-1];
}


test "daysInMonth" {
    testing.expect(daysInMonth(2019, 1) == 31);
    testing.expect(daysInMonth(2019, 2) == 28);
    testing.expect(daysInMonth(2016, 2) == 29);
}


// Number of days in year preceding the first day of month
pub fn daysBeforeMonth(year: u32, month: u32) u32 {
    assert(month >= 1 and month <= 12);
    var d = DAYS_BEFORE_MONTH[month-1];
    if (month > 2 and isLeapYear(year)) d += 1;
    return d;
}


// Return number of days since 01-Jan-0001
fn ymd2ord(year: u16, month: u8, day: u8) u32 {
    assert(month >= 1 and month <= 12);
    assert(day >= 1 and day <= daysInMonth(year, month));
    return daysBeforeYear(year) + daysBeforeMonth(year, month) + day;
}

test "ymd2ord" {
    testing.expect(ymd2ord(1970, 1, 1) == 719163);
    testing.expect(ymd2ord(28, 2, 29) == 9921);
    testing.expect(ymd2ord(2019, 11, 27) == 737390);
    testing.expect(ymd2ord(2019, 11, 28) == 737391);
}


test "days-before-year" {
    const DI400Y = daysBeforeYear(401); // Num of days in 400 years
    const DI100Y = daysBeforeYear(101); // Num of days in 100 years
    const DI4Y =   daysBeforeYear(5);   // Num of days in 4   years

    // A 4-year cycle has an extra leap day over what we'd get from pasting
    // together 4 single years.
    std.testing.expect(DI4Y == 4*365 + 1);

    // Similarly, a 400-year cycle has an extra leap day over what we'd get from
    // pasting together 4 100-year cycles.
    std.testing.expect(DI400Y == 4*DI100Y + 1);

    // OTOH, a 100-year cycle has one fewer leap day than we'd get from
    // pasting together 25 4-year cycles.
    std.testing.expect(DI100Y == 25*DI4Y - 1);
}


pub const Date = struct {
    year: u16,
    month: u4 = 1, // Month of year
    day: u8 = 1, // Day of month

    validated: u1 = @compileError("A Date must be created using Date.create"),

    // Create and validate the date
    pub fn create(year: u32, month: u32, day: u32) ! Date {
        if (year < MIN_YEAR or year > MAX_YEAR) return error.InvalidDate;
        if (month < 1 or month > 12) return error.InvalidDate;
        if (day < 1 or day > daysInMonth(year, month)) return error.InvalidDate;
        // Since we just validated the ranges we can now savely cast
        return Date{
            .year = @intCast(u16, year),
            .month = @intCast(u4, month),
            .day = @intCast(u8, day),
            .validated = 1,
        };
    }

    // Return a copy of the date
    pub fn copy(self: *const Date) !Date {
        return Date.create(self.year, self.month, self.day);
    }

    // Create a Date from the number of days since 01-Jan-0001
    pub fn fromOrdinal(ordinal: u32) Date {
        // n is a 1-based index, starting at 1-Jan-1.  The pattern of leap years
        // repeats exactly every 400 years.  The basic strategy is to find the
        // closest 400-year boundary at or before n, then work with the offset
        // from that boundary to n.  Life is much clearer if we subtract 1 from
        // n first -- then the values of n at 400-year boundaries are exactly
        // those divisible by DI400Y:
        //
        //     D  M   Y            n              n-1
        //     -- --- ----        ----------     ----------------
        //     31 Dec -400        -DI400Y        -DI400Y -1
        //      1 Jan -399        -DI400Y +1     -DI400Y       400-year boundary
        //     ...
        //     30 Dec  000        -1             -2
        //     31 Dec  000         0             -1
        //      1 Jan  001         1              0            400-year boundary
        //      2 Jan  001         2              1
        //      3 Jan  001         3              2
        //     ...
        //     31 Dec  400         DI400Y        DI400Y -1
        //      1 Jan  401         DI400Y +1     DI400Y        400-year boundary
        assert(ordinal >= 1 and ordinal <= MAX_ORDINAL);

        var n = ordinal-1;
        comptime const DI400Y = daysBeforeYear(401); // Num of days in 400 years
        comptime const DI100Y = daysBeforeYear(101); // Num of days in 100 years
        comptime const DI4Y =   daysBeforeYear(5);   // Num of days in 4   years
        const n400 = @divFloor(n, DI400Y);
        n = @mod(n, DI400Y);
        var year = n400 * 400 + 1; //  ..., -399, 1, 401, ...

        // Now n is the (non-negative) offset, in days, from January 1 of year, to
        // the desired date.  Now compute how many 100-year cycles precede n.
        // Note that it's possible for n100 to equal 4!  In that case 4 full
        // 100-year cycles precede the desired day, which implies the desired
        // day is December 31 at the end of a 400-year cycle.
        const n100 = @divFloor(n, DI100Y);
        n = @mod(n, DI100Y);

        // Now compute how many 4-year cycles precede it.
        const n4 = @divFloor(n, DI4Y);
        n = @mod(n, DI4Y);

        // And now how many single years.  Again n1 can be 4, and again meaning
        // that the desired day is December 31 at the end of the 4-year cycle.
        const n1 = @divFloor(n, 365);
        n = @mod(n, 365);

        year += n100 * 100 + n4 * 4 + n1;

        if (n1 == 4 or n100 == 4) {
            assert(n == 0);
            return Date.create(year-1, 12, 31) catch unreachable;
        }

        // Now the year is correct, and n is the offset from January 1.  We find
        // the month via an estimate that's either exact or one too large.
        var leapyear = (n1 == 3) and (n4 != 24 or n100 == 3);
        assert(leapyear == isLeapYear(year));
        var month = (n + 50) >> 5;
        if (month == 0) month = 12; // Loop around
        var preceding = daysBeforeMonth(year, month);

        if (preceding > n) { // estimate is too large
            month -= 1;
            if (month == 0) month = 12; // Loop around
            preceding -= daysInMonth(year, month);
        }
        n -= preceding;
        // assert(n > 0 and n < daysInMonth(year, month));

        // Now the year and month are correct, and n is the offset from the
        // start of that month:  we're done!
        return Date.create(year, month, n+1) catch unreachable;
    }

    // Return proleptic Gregorian ordinal for the year, month and day.
    // January 1 of year 1 is day 1.  Only the year, month and day values
    // contribute to the result.
    pub fn toOrdinal(self: *const Date) u32 {
        return ymd2ord(self.year, self.month, self.day);
    }

    // Returns todays date
    pub fn now() Date {
        return Datetime.now().date;
    }

    // Create a date from the number of seconds since 1 Jan 0001
    pub fn fromSeconds(seconds: f64) Date {
        return Datetime.fromSeconds(seconds).date;
    }

    // Return the number of seconds since 1 Jan 0001
    pub fn toSeconds(self: *const Date) f64 {
        const s: u64 = @intCast(u64, self.toOrdinal()-1) * s_per_day;
        return @intToFloat(f64, s);
    }

    // Create a date from a UTC timestamp in milliseconds
    pub fn fromTimestamp(t: u64) Date {
        const days = @divFloor(t, ms_per_day) + utc_days;
        assert(days <= MAX_ORDINAL);
        return Date.fromOrdinal(@intCast(u32, days));
    }

    // Create a UTC timestamp
    pub fn toTimestamp(self: *const Date) u64 {
        if (self.year < 1970) return 0;
        const days = daysBeforeYear(self.year) - utc_days + self.dayOfYear();
        return @intCast(u64, days) * ms_per_day;
    }

    // ------------------------------------------------------------------------
    // Comparisons
    // ------------------------------------------------------------------------
    pub fn eql(self: *const Date, other: *const Date) bool {
        return self.cmp(other) == 0;
    }

    pub fn cmp(self: *const Date, other: *const Date) i2 {
        if (self.year > other.year) return 1;
        if (self.year < other.year) return -1;
        if (self.month > other.month) return 1;
        if (self.month < other.month) return -1;
        if (self.day > other.day) return 1;
        if (self.day < other.day) return -1;
        return 0;
    }

    pub fn gt(self: *const Date, other: *const Date) bool {return self.cmp(other) > 0;}
    pub fn gte(self: *const Date, other: *const Date) bool {return self.cmp(other) >= 0;}
    pub fn lt(self: *const Date, other: *const Date) bool {return self.cmp(other) < 0;}
    pub fn lte(self: *const Date, other: *const Date) bool {return self.cmp(other) <= 0;}

    // ------------------------------------------------------------------------
    // Properties
    // ------------------------------------------------------------------------

    // Return day of year starting with 1
    pub fn dayOfYear(self: *const Date) u16 {
        var d = self.toOrdinal() - daysBeforeYear(self.year);
        assert(d >=1 and d <= 366);
        return @intCast(u16, d);
    }

    // Return day of week starting with Monday = 1 and Sunday = 7
    pub fn dayOfWeek(self: *const Date) u4 {
        const dow = self.toOrdinal() % @as(u4, 7);
        return @intCast(u4, if (dow == 0) 7 else dow);
    }

    // Return day of week starting with Monday = 0 and Sunday = 6
    pub fn weekday(self: *const Date) u4 {
        return @intCast(u4, (self.toOrdinal() + 6) % 7);
    }

    // Return whether the date is a weekend (Saturday or Sunday)
    pub fn isWeekend(self: *const Date) bool {
        return self.weekday() >= 5;
    }

    // Return the name of the day of the week, eg "Sunday"
    pub fn weekdayName(self: *const Date) []const u8 {
        return @tagName(@intToEnum(Weekday, self.dayOfWeek()));
    }

    // Return the name of the day of the month, eg "January"
    pub fn monthName(self: *const Date) []const u8 {
        assert(self.month >= 1 and self.month <= 12);
        return @tagName(@intToEnum(Month, self.month));
    }

    // ------------------------------------------------------------------------
    // Operations
    // ------------------------------------------------------------------------

    // Return a copy of the date shifted by the given number of days
    pub fn shiftDays(self: *const Date, days: i32) Date {
        return self.shift(Delta{.days=days});
    }

    // Return a copy of the date shifted by the given number of years
    pub fn shiftYears(self: *const Date, years: i16) Date {
        return self.shift(Delta{.years=years});
    }

    pub const Delta = struct {
        years: i16 = 0,
        days: i32 = 0,
    };

    // Return a copy of the date shifted in time by the delta
    pub fn shift(self: *const Date, delta: Delta) Date {
        if (delta.years == 0 and delta.days == 0) {
            return self.copy() catch unreachable;
        }

        // Shift year
        var year = self.year;
        if (delta.years < 0) {
            year -= @intCast(u16, -delta.years);
        } else {
            year += @intCast(u16, delta.years);
        }
        var ord = daysBeforeYear(year);
        var days = self.dayOfYear();
        const fromLeap = isLeapYear(self.year);
        const toLeap = isLeapYear(year);
        if (days == 59 and fromLeap and toLeap) {
            // No change before leap day
        } else if (days < 59) {
            // No change when jumping from leap day to leap day
        } else if (toLeap and !fromLeap) {
            // When jumping to a leap year to non-leap year
            // we have to add a leap day to the day of year
            days += 1;
        } else if (fromLeap and !toLeap) {
            // When jumping from leap year to non-leap year we have to undo
            // the leap day added to the day of yearear
            days -= 1;
        }
        ord += days;

        // Shift days
        if (delta.days < 0) {
            ord -= @intCast(u32, -delta.days);
        } else {
            ord += @intCast(u32, delta.days);
        }
        return Date.fromOrdinal(ord);
    }

};


test "date-now" {
    var date = Date.now();
}

test "date-compare" {
    var d1 = try Date.create(2019, 7, 3);
    var d2 = try Date.create(2019, 7, 3);
    var d3 = try Date.create(2019, 6, 3);
    var d4 = try Date.create(2020, 7, 3);
    assert(d1.eql(&d2));
    assert(d1.gt(&d3));
    assert(d3.lt(&d2));
    assert(d4.gt(&d2));
}

test "date-from-ordinal" {
    var date = Date.fromOrdinal(9921);
    testing.expect(date.year == 28);
    testing.expect(date.month == 2);
    testing.expect(date.day == 29);
    testing.expect(date.toOrdinal() == 9921);

    date = Date.fromOrdinal(737390);
    testing.expect(date.year == 2019);
    testing.expect(date.month == 11);
    testing.expect(date.day == 27);
    testing.expect(date.toOrdinal() == 737390);

    date = Date.fromOrdinal(719163);
    testing.expect(date.year == 1970);
    testing.expect(date.month == 1);
    testing.expect(date.day == 1);
    testing.expect(date.toOrdinal() == 719163);
}

test "date-from-seconds" {
    // Min check
    var min_date = try Date.create(1, 1, 1);
    var date = Date.fromSeconds(0);
    testing.expect(date.eql(&min_date));
    testing.expect(date.toSeconds() == 0);


    const t = 63710928000.000;
    date = Date.fromSeconds(t);
    testing.expect(date.year == 2019);
    testing.expect(date.month == 12);
    testing.expect(date.day == 3);
    testing.expect(date.toSeconds() == t);

    // Max check
    var max_date = try Date.create(9999, 12, 31);
    const tmax: f64 = @intToFloat(f64, MAX_ORDINAL-1) * s_per_day;
    date = Date.fromSeconds(tmax);
    testing.expect(date.eql(&max_date));
    testing.expect(date.toSeconds() == tmax);
}


test "date-day-of-year" {
    var date = try Date.create(1970, 1, 1);
    testing.expect(date.dayOfYear() == 1);
}

test "date-day-of-week" {
    var date = try Date.create(2019, 11, 27);
    testing.expect(date.weekday() == 2);
    testing.expect(date.dayOfWeek() == 3);
    testing.expectEqualSlices(u8, date.monthName(), "November");
    testing.expectEqualSlices(u8, date.weekdayName(), "Wednesday");
    testing.expect(!date.isWeekend());

    date = try Date.create(1776, 6, 4);
    testing.expect(date.weekday() == 1);
    testing.expect(date.dayOfWeek() == 2);
    testing.expectEqualSlices(u8, date.monthName(), "June");
    testing.expectEqualSlices(u8, date.weekdayName(), "Tuesday");
    testing.expect(!date.isWeekend());

    date = try Date.create(2019, 12, 1);
    testing.expectEqualSlices(u8, date.monthName(), "December");
    testing.expectEqualSlices(u8, date.weekdayName(), "Sunday");
    testing.expect(date.isWeekend());
}

test "date-shift-days" {
    var date = try Date.create(2019, 11, 27);
    var d = date.shiftDays(-2);
    testing.expect(d.day == 25);
    testing.expectEqualSlices(u8, d.weekdayName(), "Monday");

    // Ahead one week
    d = date.shiftDays(7);
    testing.expectEqualSlices(u8, d.weekdayName(), date.weekdayName());
    testing.expect(d.month == 12);
    testing.expectEqualSlices(u8, d.monthName(), "December");
    testing.expect(d.day == 4);

    d = date.shiftDays(0);
    testing.expect(date.eql(&d));

}

test "date-shift-years" {
    // Shift including a leap year
    var date = try Date.create(2019, 11, 27);
    var d = date.shiftYears(-4);
    testing.expect(d.year == 2015);
    testing.expect(d.month == 11);
    testing.expect(d.day == 27);

    d = date.shiftYears(15);
    testing.expect(d.year == 2034);
    testing.expect(d.month == 11);
    testing.expect(d.day == 27);

    // Shifting from leap day
    var leap_day = try Date.create(2020, 2, 29);
    d = leap_day.shiftYears(1);
    testing.expect(d.year == 2021);
    testing.expect(d.month == 2);
    testing.expect(d.day == 28);

    // Before leap day
    date = try Date.create(2020, 2, 2);
    d = date.shiftYears(1);
    testing.expect(d.year == 2021);
    testing.expect(d.month == 2);
    testing.expect(d.day == 2);

    // After leap day
    date = try Date.create(2020, 3, 1);
    d = date.shiftYears(1);
    testing.expect(d.year == 2021);
    testing.expect(d.month == 3);
    testing.expect(d.day == 1);

    // From leap day to leap day
    d = leap_day.shiftYears(4);
    testing.expect(d.year == 2024);
    testing.expect(d.month == 2);
    testing.expect(d.day == 29);

}


test "date-create" {
    testing.expectError(
        error.InvalidDate, Date.create(2019, 2, 29));

    var date = Date.fromTimestamp(1574908586928);
    testing.expect(date.year == 2019);
    testing.expect(date.month == 11);
    testing.expect(date.day == 28);
}

test "date-copy" {
    var d1 = try Date.create(2020, 1, 1);
    var d2 = try d1.copy();
    testing.expect(d1.eql(&d2));
}


pub const Time = struct {
    hour: u8 = 0, // 0 to 23
    minute: u8 = 0, // 0 to 59
    second: u8 = 0, // 0 to 59
    microsecond: u32 = 0, // 0 to 999999 TODO: Should this be u20?
    zone: *const Timezone = &timezone.UTC,

    validated: u1 = @compileError("A Time must be created using Time.create"),

    // ------------------------------------------------------------------------
    // Constructors
    // ------------------------------------------------------------------------
    pub fn now() Time {
        return Datetime.now().time;
    }

    // Create a Time struct and validate that all fields are in range
    pub fn create(h: u32, m: u32, s: u32, us: u32, zone: ?*const Timezone) !Time {
        if (h > 23 or m > 59 or s > 59 or us > 999999) {
            return error.InvalidTime;
        }
        return Time{
            .hour = @intCast(u8, h),
            .minute = @intCast(u8, m),
            .second = @intCast(u8, s),
            .microsecond = us,
            .zone = zone orelse &timezone.UTC,
            .validated = 1,
        };
    }

    // Create a copy of the Time
    pub fn copy(self: *const Time) !Time {
        return Time.create(self.hour, self.minute, self.second,
                           self.microsecond, self.zone);
    }

    // Create Time from a UTC Timestamp
    pub fn fromTimestamp(ts: u64) Time {
        var t = @intCast(u32, if (ts > ms_per_day)
            @mod(ts, ms_per_day) else ts);
        // t is now only the milliseconds part of the day
        const h = @divFloor(t, ms_per_hour);
        t -= h * ms_per_hour;
        const m = @divFloor(t, ms_per_min);
        t -= m * ms_per_min;
        const s = @divFloor(t, ms_per_s);
        const us = (t - s*ms_per_s) * 1000; // Convert to us
        return Time.create(h, m, s, us, &timezone.UTC) catch unreachable;
    }

    // Convert to a time in seconds relative to the UTC timezone
    // excluding the microsecond component
    pub fn totalSeconds(self: *const Time) i32 {
        return @intCast(i32, self.hour) * s_per_hour +
            (@intCast(i32, self.minute) - self.zone.offset) * s_per_min +
            @intCast(i32, self.second);
    }

    // Convert to a time in seconds relative to the UTC timezone
    // including the microsecond component
    pub fn toSeconds(self: *const Time) f64 {
        const s: f64 = @intToFloat(f64, self.totalSeconds());
        const us: f64 = @intToFloat(f32, self.microsecond) / us_per_s;
        return s + us;
    }

    // Convert to a timestamp in milliseconds from UTC
    // excluding the microsecond fraction
    pub fn toTimestamp(self: *const Time) i32 {
        return @intCast(i32, self.hour) * ms_per_hour +
               (@intCast(i32, self.minute) - self.zone.offset) * ms_per_min +
               @intCast(i32, self.second) * ms_per_s +
               @intCast(i32, @divFloor(self.microsecond, 1000));
    }

    // -----------------------------------------------------------------------
    // Comparisons
    // -----------------------------------------------------------------------
    pub fn eql(self: *const Time, other: *const Time) bool {
        return self.cmp(other) == 0;
    }

    pub fn cmp(self: *const Time, other: *const Time) i2 {
        var t1 = self.totalSeconds();
        var t2 = other.totalSeconds();
        if (t1 > t2) return 1;
        if (t1 < t2) return -1;
        if (self.microsecond > other.microsecond) return 1;
        if (self.microsecond < other.microsecond) return -1;
        return 0;
    }

    pub fn gt(self: *const Time, other: *const Time) bool {return self.cmp(other) > 0;}
    pub fn gte(self: *const Time, other: *const Time) bool {return self.cmp(other) >= 0;}
    pub fn lt(self: *const Time, other: *const Time) bool {return self.cmp(other) < 0;}
    pub fn lte(self: *const Time, other: *const Time) bool {return self.cmp(other) <= 0;}

    // -----------------------------------------------------------------------
    // Methods
    // -----------------------------------------------------------------------
    pub fn amOrPm(self: *const Time) []const u8 {
        return if (self.hour > 12) return "PM" else "AM";
    }
};

test "time-create" {
    var t = Time.fromTimestamp(1574908586928);
    testing.expect(t.hour == 2);
    testing.expect(t.minute == 36);
    testing.expect(t.second == 26);
    testing.expect(t.microsecond == 928000);
    t = Time.now();
}

test "time-copy" {
    var t1 = try Time.create(8, 30, 0, 0, null);
    var t2 = try t1.copy();
    testing.expect(t1.eql(&t2));
}

test "time-compare" {
    var t1 = try Time.create(8, 30, 0, 0, null);
    var t2 = try Time.create(9, 30, 0, 0, null);
    var t3 = try Time.create(8, 00, 0, 0, null);
    var t4 = try Time.create(9, 30, 17, 0, null);


    testing.expect(t1.lt(&t2));
    testing.expect(t1.gt(&t3));
    testing.expect(t2.lt(&t4));
    testing.expect(t2.lt(&t4));


    var t5 = try Time.create(3, 30, 0, 0, &timezone.America.New_York);
    testing.expect(t1.eql(&t5));

    var t6 = try Time.create(9, 30, 0, 0, &timezone.Europe.Zurich);
    testing.expect(t1.eql(&t5));
}


pub const Datetime = struct {
    date: Date,
    time: Time,

    // An absolute or relative delta
    // if years is defined a date is date
    // TODO: Validate years before allowing it to be created
    pub const Delta = struct {
        years: i16 = 0,
        days: i32 = 0,
        seconds: i64 = 0,
        microseconds: i32 = 0,
        relative_to: ?*Datetime = null,

        pub fn sub(self: *const Delta, other: *const Delta) Delta {
            return Delta{
                .years = self.years - other.years,
                .days = self.days - other.days,
                .seconds = self.seconds - other.seconds,
                .microseconds = self.microseconds - other.microseconds,
                .relative_to = self.relative_to,
            };
        }

        pub fn add(self: *const Delta, other: *const Delta) Delta {
            return Delta{
                .years = self.years + other.years,
                .days = self.days + other.days,
                .seconds = self.seconds + other.seconds,
                .microseconds = self.microseconds + other.microseconds,
                .relative_to = self.relative_to,
            };
        }

        // Total seconds in the duration ignoring the microseconds fraction
        pub fn totalSeconds(self: *const Delta) i64 {
            // Calculate the total number of days we're shifting
            var days = self.days;
            if (self.relative_to) |dt| {
                if (self.years != 0) {
                    const a = daysBeforeYear(dt.date.year);
                    // Must always subtract greater of the two
                    if (self.years > 0) {
                        const y = @intCast(u32, self.years);
                        const b = daysBeforeYear(dt.date.year + y);
                        days += @intCast(i32, b - a);
                    } else {
                        const y = @intCast(u32, -self.years);
                        assert(y < dt.date.year); // Does not work below year 1
                        const b = daysBeforeYear(dt.date.year - y);
                        days -= @intCast(i32, a - b);
                    }
                }
            } else {
                // Cannot use years without a relative to date
                // otherwise any leap days will screw up results
                assert(self.years == 0);
            }
            var s = self.seconds;
            var us = self.microseconds;
            if (us > us_per_s) {
                const ds = @divFloor(us, us_per_s);
                us -= ds * us_per_s;
                s += ds;
            } else if (us < -us_per_s) {
                const ds = @divFloor(us, -us_per_s);
                us += ds * us_per_s;
                s -= ds;
            }
            return (days * s_per_day + s);
        }
    };

    // ------------------------------------------------------------------------
    // Constructors
    // ------------------------------------------------------------------------
    pub fn now() Datetime {
        return Datetime.fromTimestamp(std.time.milliTimestamp());
    }

    pub fn create(year: u32, month: u32, day: u32, h: u32, m: u32,
            s: u32, us: u32, zone: ?*const Timezone) !Datetime {
        return Datetime{
            .date = try Date.create(year, month, day),
            .time = try Time.create(h, m, s, us, zone),
        };
    }

    // Return a copy
    pub fn copy(self: *const Datetime) !Datetime {
        return Datetime{
            .date = try self.date.copy(),
            .time = try self.time.copy()
        };
    }

    pub fn fromDate(year: u16, month: u8, day: u8) !Datetime {
        return Datetime{
            .date = try Date.create(year, month, day),
            .time = try Time.create(0, 0, 0, 0, &timezone.UTC),
        };
    }

    // From seconds since 1 Jan 0001
    pub fn fromSeconds(seconds: f64) Datetime {
        assert(seconds >= 0);

        // Convert to s and us
        var r = math.modf(seconds);
        var ts = @floatToInt(u64, r.ipart); // Seconds
        var us = @floatToInt(u32, math.round(r.fpart * 1e6)); // Us
        if (us >= us_per_s) {
            ts -= 1;
            us -= us_per_s;
        } else if (us < 0) {
            ts -= 1;
            us += us_per_s;
        }

        const days = @divFloor(ts, s_per_day);
        assert(days < MAX_ORDINAL);
        // Add min ordinal of 1
        var date = Date.fromOrdinal(@intCast(u32, days + 1));

        // t is now seconds lef
        ts -= days * s_per_day;
        var t = @intCast(u32, ts);
        const h = @divFloor(t, s_per_hour);
        t -= h * s_per_hour;
        const m = @divFloor(t, s_per_min);
        t -= m * s_per_min;
        const s = t;
        return Datetime{
            .date = date,
            .time = Time.create(h, m, s, us, &timezone.UTC)
                catch unreachable, // If this fails it's a bug
        };
    }

    // Seconds since 1 Jan 0001 including mircoseconds
    pub fn toSeconds(self: *const Datetime) f64 {
        return self.date.toSeconds() + self.time.toSeconds();
    }

    // From POSIX timestamp in milliseoncds since 1 Jan 1970
    pub fn fromTimestamp(ts: u64) Datetime {
        const d = @divFloor(ts, ms_per_day);
        const days = d + utc_days;
        assert(days <= MAX_ORDINAL);
        var date = Date.fromOrdinal(@intCast(u32, days));
        var t = Time.fromTimestamp(ts - d * ms_per_day);
        return Datetime{.date = date, .time = t};
    }

    // To a UTC POSIX timestamp
    pub fn toTimestamp(self: *const Datetime) u64 {
        const ts = self.time.toTimestamp();
        const ds = self.date.toTimestamp();
        if (ts >= 0) {
            return ds + @intCast(u64, ts);
        }
        const t = @intCast(u64, -ts);
        if (ds > t) {
            return ds - t;
        }
        return 0; // Less than 1 Jan 1970
    }

    // -----------------------------------------------------------------------
    // Comparisons
    // -----------------------------------------------------------------------
    pub fn eql(self: *const Datetime, other: *const Datetime) bool {
        return self.cmp(other) == 0;
    }

    pub fn cmp(self: *const Datetime, other: *const Datetime) i2 {
        var r = self.date.cmp(&other.date);
        if (r != 0) return r;
        r = self.time.cmp(&other.time);
        if (r != 0) return r;
        return 0;
    }

    pub fn gt(self: *const Datetime, other: *const Datetime) bool {return self.cmp(other) > 0;}
    pub fn gte(self: *const Datetime, other: *const Datetime) bool {return self.cmp(other) >= 0;}
    pub fn lt(self: *const Datetime, other: *const Datetime) bool {return self.cmp(other) < 0;}
    pub fn lte(self: *const Datetime, other: *const Datetime) bool {return self.cmp(other) <= 0;}

    // -----------------------------------------------------------------------
    // Methods
    // -----------------------------------------------------------------------

    // Return a Datetime.Delta relative to this date
    pub fn sub(self: *const Datetime, other: *const Datetime) Delta {
        var days = @intCast(i32, self.date.toOrdinal())
                   - @intCast(i32, other.date.toOrdinal());
        var seconds = self.time.totalSeconds() - other.time.totalSeconds();
        if (self.time.zone.offset != other.time.zone.offset) {
            const mins = (self.time.zone.offset - other.time.zone.offset);
            seconds += mins * s_per_min;
        }
        const us = @intCast(i32, self.time.microsecond)
                    - @intCast(i32, other.time.microsecond);
        return Delta{.days=days, .seconds=seconds, .microseconds=us};
    }

    // Create a Datetime shifted by the given number of years
    pub fn shiftYears(self: *const Datetime, years: i16) Datetime {
        return self.shift(Delta{.years=years});
    }

    // Create a Datetime shifted by the given number of days
    pub fn shiftDays(self: *const Datetime, days: i32) Datetime {
        return self.shift(Delta{.days=days});
    }

    // Create a Datetime shifted by the given number of hours
    pub fn shiftHours(self: *const Datetime, hours: i32) Datetime {
        return self.shift(Delta{.seconds=hours*s_per_hour});
    }

    // Create a Datetime shifted by the given number of minutes
    pub fn shiftMinutes(self: *const Datetime, minutes: i32) Datetime {
        return self.shift(Delta{.seconds=minutes*s_per_min});
    }

    // Convert to the given timeszone
    pub fn shiftTimezone(self: *const Datetime,
                         zone: *const timezone.Timezone) Datetime {
        var dt =
            if (self.time.zone.offset == zone.offset)
                (self.copy() catch unreachable)
            else
                self.shiftMinutes(zone.offset-self.time.zone.offset);
        dt.time.zone = zone;
        return dt;
    }

    // Create a Datetime shifted by the given number of seconds
    pub fn shiftSeconds(self: *const Datetime, seconds: i64) Datetime {
        return self.shift(Delta{.seconds=seconds});
    }

    // Create a Datetime shifted by the given Delta
    pub fn shift(self: *const Datetime, delta: Delta) Datetime {
        var days = delta.days;
        var s = delta.seconds + self.time.totalSeconds();

        // Rollover us to s
        var us = delta.microseconds + @intCast(i32, self.time.microsecond);
        if (us > us_per_s) {
            s += 1;
            us -= us_per_s;
        } else if (us < -us_per_s) {
            s -= 1;
            us += us_per_s;
        }
        assert(us >= 0 and us < us_per_s);
        const microseconds = @intCast(u32, us);

        // Rollover s to days
        if (s > s_per_day) {
            const d = @divFloor(s, s_per_day);
            days += @intCast(i32, d);
            s -= d * s_per_day;
        } else if (s < 0) {
            if (s < -s_per_day) { // Wrap multiple
                const d = @divFloor(s, -s_per_day);
                days -= @intCast(i32, d);
                s += d * s_per_day;
            }
            days -= 1;
            s = s_per_day + s;
        }
        assert(s >= 0 and s < s_per_day);

        var seconds = @intCast(u32, s);
        const h = @divFloor(seconds, s_per_hour);
        seconds -= h * s_per_hour;
        const m = @divFloor(seconds, s_per_min);
        seconds -= m * s_per_min;

        return Datetime{
            .date=self.date.shift(Date.Delta{.years=delta.years, .days=days}),
            .time=Time.create(h, m, seconds, microseconds, self.time.zone)
                catch unreachable // This is a bug
        };
    }

};


test "datetime-now" {
    var t = Datetime.now();
}

test "datetime-create-timestamp" {
    //var t = Datetime.now();
    const ts = 1574908586928;
    var t = Datetime.fromTimestamp(ts);
    testing.expect(t.date.year == 2019);
    testing.expect(t.date.month == 11);
    testing.expect(t.date.day == 28);
    testing.expect(t.time.hour == 2);
    testing.expect(t.time.minute == 36);
    testing.expect(t.time.second == 26);
    testing.expect(t.time.microsecond == 928000);
    testing.expectEqualSlices(u8, t.time.zone.name, "UTC");
    testing.expect(t.toTimestamp() == ts);
}

test "datetime-from-seconds" {
    const ts: f64 = 63710916533.835075;
    var t = Datetime.fromSeconds(ts);
    testing.expect(t.date.year == 2019);
    testing.expect(t.date.month == 12);
    testing.expect(t.date.day == 2);
    testing.expect(t.time.hour == 20);
    testing.expect(t.time.minute == 48);
    testing.expect(t.time.second == 53);
    testing.expect(t.time.microsecond == 835075);
    testing.expect(t.toSeconds() == ts);

}


test "datetime-shift-timezone" {
    const ts = 1574908586928;
    var t = Datetime.fromTimestamp(ts).shiftTimezone(
        &timezone.America.New_York);

    testing.expect(t.date.year == 2019);
    testing.expect(t.date.month == 11);
    testing.expect(t.date.day == 27);
    testing.expect(t.time.hour == 21);
    testing.expect(t.time.minute == 36);
    testing.expect(t.time.second == 26);
    testing.expect(t.time.microsecond == 928000);
    testing.expectEqualSlices(u8, t.time.zone.name, "America/New_York");
    testing.expect(t.toTimestamp() == ts);

}

test "datetime-shift" {
    var dt = try Datetime.create(2019, 12, 2, 11, 51, 13, 466545, null);

    testing.expect(dt.shiftYears(0).eql(&dt));
    testing.expect(dt.shiftDays(0).eql(&dt));
    testing.expect(dt.shiftHours(0).eql(&dt));

    var t = dt.shiftDays(7);
    testing.expect(t.date.year == 2019);
    testing.expect(t.date.month == 12);
    testing.expect(t.date.day == 9);
    testing.expect(t.time.eql(&dt.time));

    t = dt.shiftDays(-3);
    testing.expect(t.date.year == 2019);
    testing.expect(t.date.month == 11);
    testing.expect(t.date.day == 29);
    testing.expect(t.time.eql(&dt.time));

    t = dt.shiftHours(18);
    testing.expect(t.date.year == 2019);
    testing.expect(t.date.month == 12);
    testing.expect(t.date.day == 3);
    testing.expect(t.time.hour == 5);
    testing.expect(t.time.minute == 51);
    testing.expect(t.time.second == 13);
    testing.expect(t.time.microsecond == 466545);

    t = dt.shiftHours(-36);
    testing.expect(t.date.year == 2019);
    testing.expect(t.date.month == 11);
    testing.expect(t.date.day == 30);
    testing.expect(t.time.hour == 23);
    testing.expect(t.time.minute == 51);
    testing.expect(t.time.second == 13);
    testing.expect(t.time.microsecond == 466545);

    t = dt.shiftYears(1);
    testing.expect(t.date.year == 2020);
    testing.expect(t.date.month == 12);
    testing.expect(t.date.day == 2);
    testing.expect(t.time.eql(&dt.time));

    t = dt.shiftYears(-3);
    testing.expect(t.date.year == 2016);
    testing.expect(t.date.month == 12);
    testing.expect(t.date.day == 2);
    testing.expect(t.time.eql(&dt.time));

}

test "datetime-compare" {
    var dt1 = try Datetime.create(2019, 12, 2, 11, 51, 13, 466545, null);
    var dt2 = try Datetime.fromDate(2016, 12, 2);
    testing.expect(dt2.lt(&dt1));

    var dt3 = Datetime.now();
    testing.expect(dt3.gt(&dt2));

    var dt4 = try dt3.copy();
    testing.expect(dt3.eql(&dt4));

    var dt5 = dt1.shiftTimezone(&timezone.America.Louisville);
    testing.expect(dt5.eql(&dt1));
}

test "datetime-subtract" {
     var a = try Datetime.create(2019, 12, 2, 11, 51, 13, 466545, null);
     var b = try Datetime.create(2019, 12, 5, 11, 51, 13, 466545, null);
     var delta = a.sub(&b);
     testing.expect(delta.days == -3);
     testing.expect(delta.totalSeconds() == -3 * s_per_day);
     delta = b.sub(&a);
     testing.expect(delta.days == 3);
     testing.expect(delta.totalSeconds() == 3 * s_per_day);

     b = try Datetime.create(2019, 12, 2, 11, 0, 0, 466545, null);
     delta = a.sub(&b);
     testing.expect(delta.totalSeconds() == 13 + 51* s_per_min);
}
