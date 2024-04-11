//! Proleptic (projected backwards) Gregorian calendar date and time.
//!
//! Introduced in 1582 as a revision of the Julian calendar.

/// A Gregorian calendar date with:
/// * A `year: YearT,` which may be unsigned and is relative to 0000-00-00.
/// * Conversion from and to an `EpochDays` type which is the number of days since `epoch`.
///   The conversion algorithm used is Euclidean Affine Functions by Neri and Schneider. [1]
///   It has been chosen for its speed.
/// * A carefully selected epoch `shift` which allows for fast unsigned arithmetic at the cost
///   of moving the supported range of `YearT`.
///
/// This implementation requires the `EpochDay` range cover all possible values of `YearT`.
/// Providing an invalid combination of `epoch` and `shift` will trigger a comptime assertion.
///
/// To solve for `shift`, see `solve_shift`.
///
/// [1] https://onlinelibrary.wiley.com/doi/epdf/10.1002/spe.3172
const std = @import("std");
const IntFittingRange = std.math.IntFittingRange;
const secs_per_day = std.time.s_per_day;
const expectEqual = std.testing.expectEqual;
const assert = std.debug.assert;

pub fn DateAdvanced(comptime YearT: type, epoch_: comptime_int, shift: comptime_int) type {
    // Zig's timestamp epoch is 1970-01-01. Ours is Mar 01, 0000 AD
    const epoch = epoch_ + 719_468;
    return struct {
        year: Year,
        month: MonthT,
        day: Day,

        pub const Year = YearT;
        pub const Month = MonthT;
        pub const Day = IntFittingRange(1, 31);

        pub const EpochDays = MakeEpochDays(Year);
        const UEpochDays = std.meta.Int(.unsigned, @typeInfo(EpochDays).Int.bits);
        const IEpochDays = std.meta.Int(.signed, @typeInfo(EpochDays).Int.bits);

        const K = epoch + era_days * shift;
        const L = era * shift;

        /// Minimum epoch day representable by `Year`
        const min_day = -K;
        /// Maximum epoch day representable by `Year`
        const max_day = (std.math.maxInt(EpochDays) - 3) / 4 - K;

        // Ensure `toEpochDays` won't cause overflow.
        // If you trigger these assertions, try choosing a different value of `shift`.
        comptime {
            std.debug.assert(-L < std.math.minInt(Year));
            std.debug.assert(max_day / days_in_year.numerator - L + 1 > std.math.maxInt(Year));
        }

        /// Calendar which starts at 0000-03-01 to obtain useful counting properties.
        /// See section 4 of paper.
        const Computational = struct {
            year: UEpochDays,
            month: UIntFitting(14),
            day: UIntFitting(30),

            fn toGregorian(self: Computational, N_Y: UIntFitting(365)) Self {
                const last_day_of_jan = 306;
                const J: UEpochDays = if (N_Y >= last_day_of_jan) 1 else 0;

                const month: MonthInt = if (J != 0) self.month - 12 else self.month;
                const year: EpochDays = @bitCast(self.year +% J -% L);

                return .{
                    .year = @intCast(year),
                    .month = @enumFromInt(month),
                    .day = @as(Day, self.day) + 1,
                };
            }

            fn fromGregorian(date: Self) Computational {
                const month: UIntFitting(14) = date.month.numeric();
                const Y_G: UEpochDays = @bitCast(@as(EpochDays, @intCast(date.year)));
                const J: UEpochDays = if (month <= 2) 1 else 0;

                return .{
                    .year = Y_G +% L -% J,
                    .month = if (J != 0) month + 12 else month,
                    .day = date.day - 1,
                };
            }
        };

        const Self = @This();

        pub fn fromEpoch(days: EpochDays) Self {
            // This function is Figure 12 of the paper.
            // Besides being ported from C++, the following has changed:
            // - Seperate Year and UEpochDays types
            // - Rewrite EAFs in terms of `a` and `b`
            // - Add EAF bounds assertions
            // - Use bounded int types provided in Section 10 instead of u32 and u64
            // - Add computational calendar struct type
            // - Add comments referencing some proofs
            assert(days > min_day);
            assert(days < max_day);
            const mod = std.math.comptimeMod;
            const div = std.math.comptimeDivFloor;

            const N = @as(UEpochDays, @bitCast(days)) +% K;

            const a1 = 4;
            const b1 = 3;
            const N_1 = a1 * N + b1;
            const C = N_1 / era_days;
            const N_C: UIntFitting(36_564) = div(mod(N_1, era_days), a1);

            const N_2 = a1 * @as(UIntFitting(146_099), N_C) + b1;
            // n % 1461 == 2939745 * n % 2^32 / 2939745,
            // for all n in [0, 28825529)
            assert(N_2 < 28_825_529);
            const a2 = 2_939_745;
            const b2 = 0;
            const P_2_max = 429493804755;
            const P_2 = a2 * @as(UIntFitting(P_2_max), N_2) + b2;
            const Z: UIntFitting(99) = div(P_2, (1 << 32));
            const N_Y: UIntFitting(365) = div(mod(P_2, (1 << 32)), a2 * a1);

            // (5 * n + 461) / 153 == (2141 * n + 197913) /2^16,
            // for all n in [0, 734)
            assert(N_Y < 734);
            const a3 = 2_141;
            const b3 = 197_913;
            const N_3 = a3 * @as(UIntFitting(979_378), N_Y) + b3;

            return (Computational{
                .year = 100 * C + Z,
                .month = div(N_3, 1 << 16),
                .day = div(mod(N_3, (1 << 16)), a3),
            }).toGregorian(N_Y);
        }

        pub fn toEpoch(self: Self) EpochDays {
            // This function is Figure 13 of the paper.
            const c = Computational.fromGregorian(self);
            const C = c.year / 100;

            const y_star = days_in_year.numerator * c.year / 4 - C + C / 4;
            const days_in_5mo = 31 + 30 + 31 + 30 + 31;
            const m_star = (days_in_5mo * @as(UEpochDays, c.month) - 457) / 5;
            const N = y_star + m_star + c.day;

            return @as(EpochDays, @intCast(N)) - K;
        }

        pub const MonthAdd = std.meta.Int(.signed, @typeInfo(IEpochDays).Int.bits - std.math.log2_int(u16, 12));

        pub fn add(self: Self, year: Year, month: MonthAdd, day: IEpochDays) Self {
            const m = month + self.month.numeric() - 1;
            const y = self.year + year + @divFloor(m, 12);

            const ym_epoch_day = Self{
                .year = @intCast(y),
                .month = @enumFromInt(std.math.comptimeMod(m, 12) + 1),
                .day = 1,
            };

            var epoch_days = ym_epoch_day.toEpoch();
            epoch_days += day + self.day - 1;

            return fromEpoch(epoch_days);
        }

        pub const Weekday = WeekdayT;
        pub fn weekday(self: Self) Weekday {
            // 1970-01-01 is a Thursday.
            const epoch_days = self.toEpoch() +% Weekday.thu.numeric();
            return @enumFromInt(std.math.comptimeMod(epoch_days, 7));
        }
    };
}

/// Epoch is days since 1970
pub fn Date(comptime Year: type, epoch: comptime_int) type {
    const shift = solveShift(Year, epoch) catch unreachable;
    return DateAdvanced(Year, epoch, shift);
}

fn testFromToEpoch(comptime T: type) !void {
    const d1 = T{ .year = 1970, .month = .jan, .day = 1 };
    const d2 = T{ .year = 1980, .month = .jan, .day = 1 };

    try expectEqual(3_652, d2.toEpoch() - d1.toEpoch());

    // We don't have time to test converting there and back again for every possible i64/u64.
    // The paper has already proven it and written tests for i32 and u32.
    // Instead let's cycle through the first and last 1 << 16 part of each range.
    const min_epoch_day = (T{ .year = std.math.minInt(T.Year), .month = .jan, .day = 1 }).toEpoch();
    const max_epoch_day = (T{ .year = std.math.maxInt(T.Year), .month = .dec, .day = 31 }).toEpoch();
    const diff = max_epoch_day - min_epoch_day;
    const range: usize = if (max_epoch_day - min_epoch_day > 1 << 16) 1 << 16 else @intCast(diff);
    for (0..range) |i| {
        const d3 = min_epoch_day + @as(T.EpochDays, @intCast(i));
        try expectEqual(d3, T.fromEpoch(d3).toEpoch());

        const d4 = max_epoch_day - @as(T.EpochDays, @intCast(i));
        try expectEqual(d4, T.fromEpoch(d4).toEpoch());
    }
}

test "Date from and to epoch" {
    try testFromToEpoch(Date(i16, 0));
    try testFromToEpoch(Date(i32, 0));
    try testFromToEpoch(Date(i64, 0));

    try testFromToEpoch(Date(u16, 0));
    try testFromToEpoch(Date(u32, 0));
    try testFromToEpoch(Date(u64, 0));

    const epoch = std.date.epoch;

    try testFromToEpoch(Date(u16, epoch.windows));
    try testFromToEpoch(Date(u32, epoch.windows));
    try testFromToEpoch(Date(u64, epoch.windows));
}

test Date {
    const T = Date(i16, 0);
    const d1 = T{ .year = 1960, .month = .jan, .day = 1 };
    const epoch = T{ .year = 1970, .month = .jan, .day = 1 };

    try expectEqual(365, (T{ .year = 1971, .month = .jan, .day = 1 }).toEpoch());
    try expectEqual(epoch, T.fromEpoch(0));
    try expectEqual(3_653, epoch.toEpoch() - d1.toEpoch());

    // overflow
    // $ TZ=UTC0 date -d '1970-01-01 +1 year +13 months +32 days' --iso-8601=seconds
    try expectEqual(
        T{ .year = 1972, .month = .mar, .day = 4 },
        (T{ .year = 1970, .month = .jan, .day = 1 }).add(1, 13, 32),
    );
    // underflow
    // $ TZ=UTC0 date -d '1972-03-04 -10 year -13 months -32 days' --iso-8601=seconds
    try expectEqual(
        T{ .year = 1961, .month = .jan, .day = 3 },
        (T{ .year = 1972, .month = .mar, .day = 4 }).add(-10, -13, -32),
    );

    // $ date -d '1970-01-01'
    try expectEqual(.thu, epoch.weekday());
    try expectEqual(.thu, epoch.add(0, 0, 7).weekday());
    try expectEqual(.thu, epoch.add(0, 0, -7).weekday());
    // $ date -d '1980-01-01'
    try expectEqual(.tue, (T{ .year = 1980, .month = .jan, .day = 1 }).weekday());
    // $ date -d '1960-01-01'
    try expectEqual(.fri, d1.weekday());
}

const WeekdayInt = IntFittingRange(1, 7);
pub const WeekdayT = enum(WeekdayInt) {
    mon = 1,
    tue = 2,
    wed = 3,
    thu = 4,
    fri = 5,
    sat = 6,
    sun = 7,

    pub const Int = WeekdayInt;

    /// Convenient conversion to `WeekdayInt`. mon = 1, sun = 7
    pub fn numeric(self: @This()) Int {
        return @intFromEnum(self);
    }
};

const MonthInt = IntFittingRange(1, 12);
pub const MonthT = enum(MonthInt) {
    jan = 1,
    feb = 2,
    mar = 3,
    apr = 4,
    may = 5,
    jun = 6,
    jul = 7,
    aug = 8,
    sep = 9,
    oct = 10,
    nov = 11,
    dec = 12,

    pub const Int = MonthInt;
    pub const Days = IntFittingRange(28, 31);

    /// Convenient conversion to `MonthInt`. jan = 1, dec = 12
    pub fn numeric(self: @This()) Int {
        return @intFromEnum(self);
    }

    pub fn days(self: @This(), is_leap_year: bool) Days {
        const m: Days = @intCast(self.numeric());
        return if (m != 2)
            30 | (m ^ (m >> 3))
        else if (is_leap_year)
            29
        else
            28;
    }
};

test MonthT {
    try expectEqual(31, MonthT.jan.days(false));
    try expectEqual(29, MonthT.feb.days(true));
    try expectEqual(28, MonthT.feb.days(false));
    try expectEqual(31, MonthT.mar.days(false));
    try expectEqual(30, MonthT.apr.days(false));
    try expectEqual(31, MonthT.may.days(false));
    try expectEqual(30, MonthT.jun.days(false));
    try expectEqual(31, MonthT.jul.days(false));
    try expectEqual(31, MonthT.aug.days(false));
    try expectEqual(30, MonthT.sep.days(false));
    try expectEqual(31, MonthT.oct.days(false));
    try expectEqual(30, MonthT.nov.days(false));
    try expectEqual(31, MonthT.dec.days(false));
}

pub fn is_leap(year: anytype) bool {
    return if (@mod(year, 25) != 0)
        year & (4 - 1) == 0
    else
        year & (16 - 1) == 0;
}

test is_leap {
    try expectEqual(false, is_leap(2095));
    try expectEqual(true, is_leap(2096));
    try expectEqual(false, is_leap(2100));
    try expectEqual(true, is_leap(2400));
}

pub fn daysBetweenYears(from: usize, to: usize) usize {
    var res: usize = 0;
    var i: usize = from;
    while (i < to) : (i += 1) {
        res += if (is_leap(i)) 366 else 365;
    }
    return res;
}

test daysBetweenYears {
    try expectEqual(366, daysBetweenYears(2000, 2001));
    try expectEqual(146_097, daysBetweenYears(0, 400));
}

/// The Gregorian calendar repeats every 400 years.
const era = 400;
const era_days: comptime_int = daysBetweenYears(0, 400); // 146_097

/// Number of days between two consecutive March equinoxes
const days_in_year = struct {
    const actual = 365.2424;
    // .0001 days per year of error.
    const numerator = 1_461;
    const denominator = 4;
};

/// Int type to represent all possible days between minimum `Year` and maximum `Year`.
/// Rounded up to nearest power of 2 to meet unsigned division assertions.
fn MakeEpochDays(comptime Year: type) type {
    const year_range = (std.math.maxInt(Year) - std.math.minInt(Year)) * days_in_year.actual;
    const required_int_bits = @ceil(std.math.log2(year_range));
    const int_bits = std.math.ceilPowerOfTwoAssert(u16, @intFromFloat(required_int_bits));
    return std.meta.Int(.signed, int_bits);
}

fn UIntFitting(to: comptime_int) type {
    return IntFittingRange(0, to);
}

/// Finds minimum epoch shift that covers the range:
/// [std.math.minInt(YearT), std.math.maxInt(YearT)]
fn solveShift(comptime Year: type, epoch: comptime_int) !comptime_int {
    const shift = std.math.maxInt(Year) / era + 1;

    const L = era * shift;
    const K = epoch + era_days * shift;
    const EpochDays = MakeEpochDays(Year);
    const max_day = (std.math.maxInt(EpochDays) - 3) / 4 - K;

    if (@divFloor(max_day, days_in_year.numerator) - L + 1 <= std.math.maxInt(Year))
        return error.Constraint; // if you hit this write a system of equations solver here to prove
    // there are no possible values of `shift`

    return shift;
}

test solveShift {
    try expectEqual(82, try solveShift(i16, 719_468));
    try expectEqual(5_368_710, try solveShift(i32, 719_468));
    try expectEqual(23_058_430_092_136_940, try solveShift(i64, 719_468));
}
