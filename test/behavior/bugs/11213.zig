const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

test {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const g: error{Test}!void = error.Test;

    var v: u32 = 0;
    hash(&v, g);
    try testing.expect(v == 1);
}

fn hash(v: *u32, key: anytype) void {
    const Key = @TypeOf(key);

    if (@typeInfo(Key) == .ErrorSet) {
        v.* += 1;
        return;
    }

    switch (@typeInfo(Key)) {
        .ErrorUnion => blk: {
            const payload = key catch |err| {
                hash(v, err);
                break :blk;
            };

            hash(v, payload);
        },

        else => unreachable,
    }
}
