const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

var read_count: u64 = 0;

fn readOnce() anyerror!u64 {
    read_count += 1;
    return read_count;
}

const FormValue = union(enum) {
    Address: u64,
    Other: bool,
};

fn doThing(form_id: u64) anyerror!FormValue {
    return switch (form_id) {
        17 => FormValue{ .Address = try readOnce() },
        else => error.InvalidDebugInfo,
    };
}

test "switch prong returns error enum" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    switch (doThing(17) catch unreachable) {
        FormValue.Address => |payload| {
            try expect(payload == 1);
        },
        else => unreachable,
    }
    try expect(read_count == 1);
}
