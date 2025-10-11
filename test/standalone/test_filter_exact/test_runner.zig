const builtin = @import("builtin");
const std = @import("std");

pub fn main() u8 {
    const stdout = std.fs.File.stdout();
    var buffer: [512]u8 = undefined;
    var stdout_writer = stdout.writer(&buffer);
    const writer = &stdout_writer.interface;

    var fail_count: usize = 0;

    for (builtin.test_functions) |test_fn| {
        writer.print("{s}\n", .{test_fn.name}) catch @panic("failed writing test name");
        test_fn.func() catch |err| {
            writer.print("err: {t}\n", .{err}) catch @panic("failed writing error name");
            fail_count += 1;
        };
    }

    writer.flush() catch @panic("failed flushing");

    if (fail_count > 0) {
        return 1;
    }

    return 0;
}
