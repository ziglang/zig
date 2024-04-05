pub const gregorian = @import("./date/gregorian.zig");
pub const epoch = @import("./date/epoch.zig");

pub const Date = gregorian.Date;
pub fn DatePosix(comptime Year: type) type {
    return gregorian.Date(Year, epoch.posix);
}

pub const Date16 = DatePosix(i16);
pub const Date32 = DatePosix(i32);
pub const Date64 = DatePosix(i64);

test {
    _ = gregorian;
}
