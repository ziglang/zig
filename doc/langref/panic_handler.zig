pub fn main() void {
    @setRuntimeSafety(true);
    var x: u8 = 255;
    // Let's overflow this integer!
    x += 1;
}

pub const panic = std.debug.FullPanic(myPanic);

fn myPanic(msg: []const u8, first_trace_addr: ?usize) noreturn {
    _ = first_trace_addr;
    std.debug.print("Panic! {s}\n", .{msg});
    std.process.exit(1);
}

const std = @import("std");

// exe=fail
