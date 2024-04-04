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

        const K = epoch + era_days * shift;
        const L = era * shift;
        /// Minimum epoch day representable by `Year`
        pub const min_day = -K;
        /// Maximum epoch day representable by `Year`
        pub const max_day = (std.math.maxInt(EpochDays) - 3) / 4 - K;

        // Ensure `toEpochDays` won't cause overflow.
        //
        // If you trigger these assertions, try choosing a different value of `shift`.
        comptime {
            std.debug.assert(-L < std.math.minInt(Year));
            std.debug.assert(max_day / days_in_year.numerator - L + 1 > std.math.maxInt(Year));
        }

        const Computational = struct {
            year: UEpochDays,
            month: UIntFitting(14),
            day: UIntFitting(30),

            fn toGregorian(self: Computational, N_Y: UIntFitting(365)) Self {
                const last_day_of_jan = 306;
                const J: UEpochDays = if (N_Y >= last_day_of_jan) 1 else 0;

                const month: MonthInt = if (J != 0) self.month - 12 else self.month;

                return .{
                    .year = @intCast(@as(EpochDays, @bitCast(self.year +% J -% L))),
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

        pub fn order(self: Self, other: Self) std.math.Order {
            return difference(self.year, other.year) orelse difference(self.month.numeric(), other.month.numeric()) orelse difference(self.day, other.day) orelse .eq;
        }

        pub fn fromEpoch(days: EpochDays) Self {
            // This function is Figure 12 of the paper.
            // Besides being ported from C++, the following has changed:
            // - Seperate Year and UEpochDays types
            // - Rewrite EAFs in terms of `a` and `b`
            // - Add EAF bounds assertions
            // - Use bounded int types provided in Section 10 instead of u32 and u64
            // - Add computational calendar struct type
            // - Add comments referencing some proofs
            //
            // While these changes should allow the reader to understand _how_ these functions
            // work, I recommend reading the paper to understand *why*.
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
    };
}

/// Epoch is days since 1970
pub fn Date(comptime Year: type, epoch: comptime_int) type {
    const shift = solve_shift(Year, epoch) catch unreachable;
    return DateAdvanced(Year, epoch, shift);
}

test Date {
    const T = Date(i16, 0);
    const d1 = T{ .year = 1970, .month = .jan, .day = 1 };
    const d2 = T{ .year = 1971, .month = .jan, .day = 1 };

    try expectEqual(d1.order(d2), .lt);
    try expectEqual(365, d2.toEpoch() - d1.toEpoch());
}

const MonthInt = IntFittingRange(1, 12);
const MonthT = enum(MonthInt) {
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
    pub fn numeric(self: MonthT) MonthInt {
        return @intFromEnum(self);
    }

    pub fn days(self: MonthT, is_leap_year: bool) Days {
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

fn days_between_years(from: usize, to: usize) usize {
    var res: usize = 0;
    var i: usize = from;
    while (i < to) : (i += 1) {
        res += if (is_leap(i)) 366 else 365;
    }
    return res;
}

test days_between_years {
    try expectEqual(366, days_between_years(2000, 2001));
    try expectEqual(146_097, days_between_years(0, 400));
}

/// Returns .gt, .lt, or null
fn difference(a: anytype, b: anytype) ?std.math.Order {
    const res = std.math.order(a, b);
    if (res != .eq) return res;
    return null;
}

/// The Gregorian calendar repeats every 400 years.
const era = 400;
const era_days: comptime_int = days_between_years(0, 400); // 146_097

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
fn solve_shift(comptime Year: type, epoch: comptime_int) !comptime_int {
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

test solve_shift {
    try expectEqual(82, try solve_shift(i16, 719_468));
    try expectEqual(5_368_710, try solve_shift(i32, 719_468));
    try expectEqual(23_058_430_092_136_940, try solve_shift(i64, 719_468));
}

const std = @import("std");
const IntFittingRange = std.math.IntFittingRange;
const secs_per_day = std.time.s_per_day;
const expectEqual = std.testing.expectEqual;
const assert = std.debug.assert;
