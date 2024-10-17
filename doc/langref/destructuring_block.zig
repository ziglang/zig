const print = @import("std").debug.print;

pub fn main() void {
    const digits = [_]i8 { 3, 8, 9, 0, 7, 4, 1 };

    const min, const max = blk: {
        var min: i8 = 127;
        var max: i8 = -128;

        for (digits) |digit| {
            if (digit < min) min = digit;
            if (digit > max) max = digit;
        }

        break :blk .{ min, max };
    };

    print("min = {}", .{ min });
    print("max = {}", .{ max });
}

// exe=succeed
