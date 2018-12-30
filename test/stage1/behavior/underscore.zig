const std = @import("std");
const assert = std.debug.assert;

test "ignore lval with underscore" {
    _ = false;
}

test "ignore lval with underscore (for loop)" {
    for ([]void{}) |_, i| {
        for ([]void{}) |_, j| {
            break;
        }
        break;
    }
}

test "ignore lval with underscore (while loop)" {
    while (optionalReturnError()) |_| {
        while (optionalReturnError()) |_| {
            break;
        } else |_| {}
        break;
    } else |_| {}
}

fn optionalReturnError() !?u32 {
    return error.optionalReturnError;
}
