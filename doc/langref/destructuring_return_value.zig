const print = @import("std").debug.print;

fn divmod(numerator: u32, denominator: u32) struct { u32, u32 } {
    return .{ numerator / denominator, numerator % denominator };
}

pub fn main() void {
    const div, const mod = divmod(10, 3);

    print("10 / 3 = {}\n", .{div});
    print("10 % 3 = {}\n", .{mod});
}

// exe=succeed
