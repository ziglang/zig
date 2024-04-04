pub const gregorian = @import("./date/gregorian.zig");

pub fn Date(comptime Year: type) type {
    return gregorian.Date(Year, epoch.posix);
}

pub const Date16 = Date(i16);
pub const Date32 = Date(i32);
pub const Date64 = Date(i64);

test {
    _ = gregorian;
}

const epoch = @import("./date/epoch.zig");
