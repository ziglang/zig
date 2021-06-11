const std = @import("std");
const expect = std.testing.expect;

test "ignore lval with underscore" {
    _ = false;
}

test "ignore lval with underscore (for loop)" {
    for ([_]void{}) |_, i| {
        for ([_]void{}) |_, j| {
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
