const std = @import("std");
const io = std.io;
const builtin = @import("builtin");
const test_fn_list = builtin.test_functions;

pub fn main() void {
    const stderr = io.getStdErr() catch std.process.abort();

    var ok_count: usize = 0;
    var skip_count: usize = 0;
    for (test_fn_list) |test_fn, i| {
        stderr.write("test ") catch std.process.abort();
        stderr.write(test_fn.name) catch std.process.abort();

        if (test_fn.func()) |_| {
            ok_count += 1;
            stderr.write("...OK\n") catch std.process.abort();
        } else |err| switch (err) {
            error.SkipZigTest => {
                skip_count += 1;
                stderr.write("...SKIP\n") catch std.process.abort();
            },
            else => {
                stderr.write("error: ") catch std.process.abort();
                stderr.write(@errorName(err)) catch std.process.abort();
                std.process.abort();
            },
        }
    }
    if (ok_count == test_fn_list.len) {
        stderr.write("All tests passed.\n") catch std.process.abort();
    } else {
        stderr.write("Some tests skipped.\n") catch std.process.abort();
    }
}
