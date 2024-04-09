pub const gregorian = @import("./date/gregorian.zig");
pub const epoch = @import("./date/epoch.zig");

/// A Gregorian Date using days since `1970-01-01` for its epoch methods.
///
/// Supports dates between years -32_768 and 32_768.
pub const Date = gregorian.Date(i16, epoch.posix);

test {
    _ = gregorian;
}
