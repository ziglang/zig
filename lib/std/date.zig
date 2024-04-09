pub const gregorian = @import("./date/gregorian.zig");
pub const epoch = @import("./date/epoch.zig");

pub fn DatePosix(comptime Year: type) type {
    return gregorian.Date(Year, epoch.posix);
}

/// A Gregorian Date using days since `1970-01-01` for its epoch methods.
///
/// Supports dates between years -32_768 and 32_768.
pub const Date = DatePosix(i16);

test {
    _ = gregorian;
}
